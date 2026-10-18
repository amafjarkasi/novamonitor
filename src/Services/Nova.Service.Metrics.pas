unit Nova.Service.Metrics;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows,
  SysUtils,
  Classes,
  SyncObjs,
  Generics.Collections,
  Nova.Types;

type
  TMetricsService = class;

  /// <summary>
  /// Background worker thread for polling system metrics asynchronously
  /// </summary>
  TMetricsWorkerThread = class(TThread)
  private
    FService: TMetricsService;
    FIntervalMs: Cardinal;
    FOnUpdate: TMetricsUpdateEvent;
    FOnProcessUpdate: TProcessListUpdateEvent;
    FStopEvent: TEvent;
    FLastProcessCount: Integer;
    FLastThreadCount: Integer;
    FCurMetrics: TSystemMetrics;
    FCurProcesses: TProcessList;

    procedure DoSyncMetrics;
    procedure DoSyncProcesses;
  protected
    procedure Execute; override;
  public
    constructor Create(const AService: TMetricsService; const AIntervalMs: Cardinal;
      const AOnUpdate: TMetricsUpdateEvent; const AOnProcessUpdate: TProcessListUpdateEvent);
    destructor Destroy; override;
    /// <summary>
    /// Interrupts the inter-poll wait so the thread terminates promptly
    /// </summary>
    procedure StopPolling;
    property IntervalMs: Cardinal read FIntervalMs write FIntervalMs;
  end;

  TProcessMeta = record
    ImagePath: string;
    UserName: string;
    Architecture: string;
  end;

  /// <summary>
  /// Thread-safe Windows System Metrics gathering service
  /// </summary>
  TMetricsService = class(TInterfacedObject, IMetricsService)
  private
    FWorker: TMetricsWorkerThread;
    FIntervalMs: Cardinal;
    FLock: TCriticalSection;
    FPrevIdleTime: Int64;
    FPrevKernelTime: Int64;
    FPrevUserTime: Int64;
    FHasPrevCpuTime: Boolean;
    // Network interface byte counters for throughput calculation
    FPrevNetInBytes: UInt64;
    FPrevNetOutBytes: UInt64;
    FPrevNetTick: UInt64;
    FHasPrevNetSample: Boolean;
    // Per-PID CPU and Disk I/O sampling from the previous scan
    FPrevProcTimes: TDictionary<Cardinal, Int64>;
    FCurProcTimes: TDictionary<Cardinal, Int64>;
    FPrevProcIo: TDictionary<Cardinal, Int64>;
    FCurProcIo: TDictionary<Cardinal, Int64>;
    FProcMetaCache: TDictionary<Cardinal, TProcessMeta>;
    FHasPrevProcSample: Boolean;
    FPrevProcTotalTime: Int64;
    FPrevProcIoTick: UInt64;

    function CalculateCpuUsage: Single;
  public
    constructor Create;
    destructor Destroy; override;

    procedure StartMonitoring(const AIntervalMs: Cardinal;
      const OnUpdate: TMetricsUpdateEvent;
      const OnProcessUpdate: TProcessListUpdateEvent);
    procedure StopMonitoring;
    function IsMonitoring: Boolean;
    procedure SetInterval(const AIntervalMs: Cardinal);
    function GetInterval: Cardinal;
    function CollectSnapshot: TSystemMetrics;
    function CollectProcesses: TProcessList;
    function CollectNetworkConnections: TNetworkConnectionList;
    function CollectServices: TServiceList;
    function TerminateProcessById(const AProcessId: Cardinal): Boolean;
    function SetProcessPriorityById(const AProcessId: Cardinal; const APriorityClass: Cardinal): Boolean;
    function SuspendResumeProcessById(const AProcessId: Cardinal; const ASuspend: Boolean): Boolean;
    function ControlWindowsService(const AServiceName: string; const AAction: Integer): Boolean;
    function GetProcessModules(const AProcessId: Cardinal): TStringList;
  end;

implementation

{ TMetricsWorkerThread }

constructor TMetricsWorkerThread.Create(const AService: TMetricsService;
  const AIntervalMs: Cardinal; const AOnUpdate: TMetricsUpdateEvent;
  const AOnProcessUpdate: TProcessListUpdateEvent);
begin
  inherited Create(True); // Create suspended to avoid race condition
  FreeOnTerminate := False;
  FService := AService;
  FIntervalMs := AIntervalMs;
  FOnUpdate := AOnUpdate;
  FOnProcessUpdate := AOnProcessUpdate;
  FStopEvent := TEvent.Create(nil, True, False, '');
  FLastProcessCount := 0;
  FLastThreadCount := 0;
  Start; // Safely start execution
end;

destructor TMetricsWorkerThread.Destroy;
begin
  FStopEvent.Free;
  inherited Destroy;
end;

procedure TMetricsWorkerThread.StopPolling;
begin
  if Assigned(FStopEvent) then
    FStopEvent.SetEvent;
end;

procedure TMetricsWorkerThread.DoSyncMetrics;
begin
  if not Terminated and Assigned(FOnUpdate) then
    FOnUpdate(FCurMetrics);
end;

procedure TMetricsWorkerThread.DoSyncProcesses;
begin
  if not Terminated and Assigned(FOnProcessUpdate) then
    FOnProcessUpdate(FCurProcesses)
  else
    FCurProcesses.Free;
end;

procedure TMetricsWorkerThread.Execute;
var
  Counter, I, TotalThreads: Integer;
begin
  Counter := 0;
  while not Terminated do
  begin
    try
      FCurMetrics := FService.CollectSnapshot;
      // The snapshot zeroes the count on every tick; keep the last real value
      // so the UI does not flicker to "0 active processes" between process scans
      FCurMetrics.ActiveProcessCount := FLastProcessCount;
      FCurMetrics.ThreadCount := FLastThreadCount;

      if (Counter mod 3 = 0) and Assigned(FOnProcessUpdate) then
      begin
        FCurProcesses := FService.CollectProcesses;
        FLastProcessCount := FCurProcesses.Count;
        TotalThreads := 0;
        for I := 0 to FCurProcesses.Count - 1 do
          Inc(TotalThreads, FCurProcesses[I].ThreadCount);
        FLastThreadCount := TotalThreads;
        FCurMetrics.ActiveProcessCount := FLastProcessCount;
        FCurMetrics.ThreadCount := FLastThreadCount;
        Synchronize(DoSyncProcesses);
      end;

      if Assigned(FOnUpdate) then
        Synchronize(DoSyncMetrics);
    except
      // Suppress transient thread exceptions
    end;

    Inc(Counter);
    // Event wait instead of Sleep: StopMonitoring interrupts immediately
    if FStopEvent.WaitFor(FIntervalMs) = wrSignaled then
      Break;
  end;
end;

{ TMetricsService }

constructor TMetricsService.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FWorker := nil;
  FHasPrevCpuTime := False;
  FPrevIdleTime := 0;
  FPrevKernelTime := 0;
  FPrevUserTime := 0;
  FPrevNetInBytes := 0;
  FPrevNetOutBytes := 0;
  FPrevNetTick := 0;
  FHasPrevNetSample := False;
  FPrevProcTimes := TDictionary<Cardinal, Int64>.Create;
  FCurProcTimes := TDictionary<Cardinal, Int64>.Create;
  FPrevProcIo := TDictionary<Cardinal, Int64>.Create;
  FCurProcIo := TDictionary<Cardinal, Int64>.Create;
  FProcMetaCache := TDictionary<Cardinal, TProcessMeta>.Create;
  FHasPrevProcSample := False;
  FPrevProcTotalTime := 0;
  FPrevProcIoTick := 0;
  FIntervalMs := 1500;
end;

destructor TMetricsService.Destroy;
begin
  StopMonitoring;
  FProcMetaCache.Free;
  FCurProcIo.Free;
  FPrevProcIo.Free;
  FCurProcTimes.Free;
  FPrevProcTimes.Free;
  FLock.Free;
  inherited Destroy;
end;

{$IFDEF MSWINDOWS}
type
  TWinMemoryStatusEx = record
    dwLength: DWORD;
    dwMemoryLoad: DWORD;
    ullTotalPhys: UInt64;
    ullAvailPhys: UInt64;
    ullTotalPageFile: UInt64;
    ullAvailPageFile: UInt64;
    ullTotalVirtual: UInt64;
    ullAvailVirtual: UInt64;
    ullAvailExtendedVirtual: UInt64;
  end;

  TWinProcessMemoryCounters = record
    cb: DWORD;
    PageFaultCount: DWORD;
    PeakWorkingSetSize: NativeUInt;
    WorkingSetSize: NativeUInt;
    QuotaPeakPagedPoolUsage: NativeUInt;
    QuotaPagedPoolUsage: NativeUInt;
    QuotaPeakNonPagedPoolUsage: NativeUInt;
    QuotaNonPagedPoolUsage: NativeUInt;
    PagefileUsage: NativeUInt;
    PeakPagefileUsage: NativeUInt;
  end;
  PWinProcessMemoryCounters = ^TWinProcessMemoryCounters;

  // Mirror of PROCESSENTRY32 (ANSI). Declared here because neither FPC's
  // Windows unit nor Delphi's Winapi.Windows exposes Toolhelp32
  TWinProcessEntry32 = record
    dwSize: DWORD;
    cntUsage: DWORD;
    th32ProcessID: DWORD;
    th32DefaultHeapID: ULONG_PTR;
    th32ModuleID: DWORD;
    cntThreads: DWORD;
    th32ParentProcessID: DWORD;
    pcPriClassBase: LONG;
    dwFlags: DWORD;
    szExeFile: array[0..259] of AnsiChar;
  end;

  // Network API types (iphlpapi.dll)
  TMibTcpRowOwnerPid = packed record
    dwState: DWORD;
    dwLocalAddr: DWORD;
    dwLocalPort: DWORD;
    dwRemoteAddr: DWORD;
    dwRemotePort: DWORD;
    dwOwningPid: DWORD;
  end;

  TMibTcpTableOwnerPid = packed record
    dwNumEntries: DWORD;
    table: array[0..0] of TMibTcpRowOwnerPid;
  end;
  PMibTcpTableOwnerPid = ^TMibTcpTableOwnerPid;

  TMibUdpRowOwnerPid = packed record
    dwLocalAddr: DWORD;
    dwLocalPort: DWORD;
    dwOwningPid: DWORD;
  end;

  TMibUdpTableOwnerPid = packed record
    dwNumEntries: DWORD;
    table: array[0..0] of TMibUdpRowOwnerPid;
  end;
  PMibUdpTableOwnerPid = ^TMibUdpTableOwnerPid;

  TMibIfRow = packed record
    wszName: array[0..255] of WideChar;
    dwIndex: DWORD;
    dwType: DWORD;
    dwMtu: DWORD;
    dwSpeed: DWORD;
    dwPhysAddrLen: DWORD;
    bPhysAddr: array[0..7] of Byte;
    dwAdminStatus: DWORD;
    dwOperStatus: DWORD;
    dwLastChange: DWORD;
    dwInOctets: DWORD;
    dwInUcastPkts: DWORD;
    dwInNUcastPkts: DWORD;
    dwInDiscards: DWORD;
    dwInErrors: DWORD;
    dwInUnknownProtos: DWORD;
    dwOutOctets: DWORD;
    dwOutUcastPkts: DWORD;
    dwOutNUcastPkts: DWORD;
    dwOutDiscards: DWORD;
    dwOutErrors: DWORD;
    dwOutQLen: DWORD;
    dwDescrLen: DWORD;
    bDescr: array[0..255] of Byte;
  end;

  TMibIfTable = packed record
    dwNumEntries: DWORD;
    table: array[0..0] of TMibIfRow;
  end;
  PMibIfTable = ^TMibIfTable;

  TWinIoCounters = record
    ReadOperationCount: UInt64;
    WriteOperationCount: UInt64;
    OtherOperationCount: UInt64;
    ReadTransferCount: UInt64;
    WriteTransferCount: UInt64;
    OtherTransferCount: UInt64;
  end;

  // Service Control Manager types (advapi32.dll)
  TServiceStatus = record
    dwServiceType: DWORD;
    dwCurrentState: DWORD;
    dwControlsAccepted: DWORD;
    dwWin32ExitCode: DWORD;
    dwServiceSpecificExitCode: DWORD;
    dwCheckPoint: DWORD;
    dwWaitHint: DWORD;
  end;

  TServiceStatusProcess = record
    dwServiceType: DWORD;
    dwCurrentState: DWORD;
    dwControlsAccepted: DWORD;
    dwWin32ExitCode: DWORD;
    dwServiceSpecificExitCode: DWORD;
    dwCheckPoint: DWORD;
    dwWaitHint: DWORD;
    dwProcessId: DWORD;
    dwServiceFlags: DWORD;
  end;

  TEnumServiceStatusProcessW = record
    lpServiceName: PWideChar;
    lpDisplayName: PWideChar;
    ServiceStatusProcess: TServiceStatusProcess;
  end;
  PEnumServiceStatusProcessW = ^TEnumServiceStatusProcessW;

  // NT Kernel SystemProcessInformation (SystemInformationClass = 5)
  TNtSystemProcessInfo = record
    NextEntryOffset: DWORD;
    NumberOfThreads: DWORD;
    WorkingSetPrivateSize: Int64;
    HardFaultCount: DWORD;
    NumberOfThreadsHighWatermark: DWORD;
    CycleTime: UInt64;
    CreateTime: Int64;
    UserTime: Int64;
    KernelTime: Int64;
    ImageNameLength: Word;
    ImageNameMaxLength: Word;
    {$IFDEF CPU64}
    ImageNamePad: DWORD;
    {$ENDIF}
    ImageNameBuffer: PWideChar;
    BasePriority: LongInt;
    UniqueProcessId: NativeUInt;
    InheritedFromUniqueProcessId: NativeUInt;
    HandleCount: DWORD;
    SessionId: DWORD;
    UniqueProcessKey: NativeUInt;
    PeakVirtualSize: NativeUInt;
    VirtualSize: NativeUInt;
    PageFaultCount: DWORD;
    PeakWorkingSetSize: NativeUInt;
    WorkingSetSize: NativeUInt;
    QuotaPeakPagedPoolUsage: NativeUInt;
    QuotaPagedPoolUsage: NativeUInt;
    QuotaPeakNonPagedPoolUsage: NativeUInt;
    QuotaNonPagedPoolUsage: NativeUInt;
    PagefileUsage: NativeUInt;
    PeakPagefileUsage: NativeUInt;
    PrivatePageCount: NativeUInt;
    ReadOperationCount: Int64;
    WriteOperationCount: Int64;
    OtherOperationCount: Int64;
    ReadTransferCount: Int64;
    WriteTransferCount: Int64;
    OtherTransferCount: Int64;
  end;
  PNtSystemProcessInfo = ^TNtSystemProcessInfo;

  TKernelProcStat = record
    WorkingSetMB: Single;
    TotalTime: Int64;
    IoBytes: Int64;
    BasePriority: LongInt;
    SessionId: DWORD;
  end;

const
  // Local declarations shadow Windows-unit constants where present
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
  PROCESS_SET_INFORMATION = $0200;
  PROCESS_SUSPEND_RESUME = $0800;
  PROCESS_QUERY_INFORMATION = $0400;
  PROCESS_VM_READ = $0010;
  TH32CS_SNAPPROCESS = $2;
  SystemProcessInformation = 5;
  STATUS_INFO_LENGTH_MISMATCH = LongInt($C0000004);

  TCP_TABLE_OWNER_PID_ALL = 5;
  UDP_TABLE_OWNER_PID = 1;
  AF_INET = 2;
  MIB_IF_TYPE_LOOPBACK = 24;

  SC_MANAGER_CONNECT = $0001;
  SC_MANAGER_ENUMERATE_SERVICE = $0004;
  SC_ENUM_PROCESS_INFO = 0;
  SERVICE_START = $0010;
  SERVICE_STOP = $0020;
  SERVICE_QUERY_STATUS = $0004;
  SERVICE_CONTROL_STOP = $00000001;
  SERVICE_WIN32 = $00000030;
  SERVICE_STATE_ALL = $00000003;

  SERVICE_STOPPED          = $00000001;
  SERVICE_START_PENDING    = $00000002;
  SERVICE_STOP_PENDING     = $00000003;
  SERVICE_RUNNING          = $00000004;
  SERVICE_CONTINUE_PENDING = $00000005;
  SERVICE_PAUSE_PENDING    = $00000006;
  SERVICE_PAUSED           = $00000007;

function GlobalMemoryStatusEx(var lpBuffer: TWinMemoryStatusEx): BOOL; stdcall; external 'kernel32.dll';
function GetSystemTimes(lpIdleTime, lpKernelTime, lpUserTime: PFileTime): BOOL; stdcall; external 'kernel32.dll';
function GetProcessMemoryInfo(hProcess: THandle; ppsmemCounters: PWinProcessMemoryCounters; cb: DWORD): BOOL; stdcall; external 'psapi.dll';
function EnumProcessModules(hProcess: THandle; lphModule: PHandle; cb: DWORD; var lpcbNeeded: DWORD): BOOL; stdcall; external 'psapi.dll' name 'EnumProcessModules';
function GetModuleFileNameExW(hProcess: THandle; hModule: THandle; lpFilename: PWideChar; nSize: DWORD): DWORD; stdcall; external 'psapi.dll' name 'GetModuleFileNameExW';
function CreateToolhelp32Snapshot(dwFlags: DWORD; th32ProcessID: DWORD): THandle; stdcall; external 'kernel32.dll';
function Process32First(hSnapshot: THandle; var lpEntry: TWinProcessEntry32): BOOL; stdcall; external 'kernel32.dll';
function Process32Next(hSnapshot: THandle; var lpEntry: TWinProcessEntry32): BOOL; stdcall; external 'kernel32.dll';
function QueryFullProcessImageNameW(hProcess: THandle; dwFlags: DWORD; lpExeName: PWideChar; var lpdwSize: DWORD): BOOL; stdcall; external 'kernel32.dll' name 'QueryFullProcessImageNameW';
function IsWow64Process(hProcess: THandle; var Wow64Process: BOOL): BOOL; stdcall; external 'kernel32.dll' name 'IsWow64Process';
function GetProcessIoCounters(hProcess: THandle; var lpIoCounters: TWinIoCounters): BOOL; stdcall; external 'kernel32.dll' name 'GetProcessIoCounters';
function GetPriorityClass(hProcess: THandle): DWORD; stdcall; external 'kernel32.dll' name 'GetPriorityClass';
function SetPriorityClass(hProcess: THandle; dwPriorityClass: DWORD): BOOL; stdcall; external 'kernel32.dll' name 'SetPriorityClass';
function NtQuerySystemInformation(SystemInformationClass: DWORD; SystemInformation: Pointer; SystemInformationLength: DWORD; var ReturnLength: DWORD): LongInt; stdcall; external 'ntdll.dll' name 'NtQuerySystemInformation';
function NtSuspendProcess(ProcessHandle: THandle): LongInt; stdcall; external 'ntdll.dll' name 'NtSuspendProcess';
function NtResumeProcess(ProcessHandle: THandle): LongInt; stdcall; external 'ntdll.dll' name 'NtResumeProcess';

function OpenProcessToken(ProcessHandle: THandle; DesiredAccess: DWORD; var TokenHandle: THandle): BOOL; stdcall; external 'advapi32.dll' name 'OpenProcessToken';
function GetTokenInformation(TokenHandle: THandle; TokenInformationClass: DWORD; TokenInformation: Pointer; TokenInformationLength: DWORD; var ReturnLength: DWORD): BOOL; stdcall; external 'advapi32.dll' name 'GetTokenInformation';
function LookupAccountSidW(lpSystemName: PWideChar; Sid: Pointer; Name: PWideChar; var cchName: DWORD; ReferencedDomainName: PWideChar; var cchReferencedDomainName: DWORD; var peUse: DWORD): BOOL; stdcall; external 'advapi32.dll' name 'LookupAccountSidW';

function OpenSCManagerW(lpMachineName, lpDatabaseName: PWideChar; dwDesiredAccess: DWORD): THandle; stdcall; external 'advapi32.dll' name 'OpenSCManagerW';
function OpenServiceW(hSCManager: THandle; lpServiceName: PWideChar; dwDesiredAccess: DWORD): THandle; stdcall; external 'advapi32.dll' name 'OpenServiceW';
function StartServiceW(hService: THandle; dwNumServiceArgs: DWORD; lpServiceArgVectors: Pointer): BOOL; stdcall; external 'advapi32.dll' name 'StartServiceW';
function ControlService(hService: THandle; dwControl: DWORD; var lpServiceStatus: TServiceStatus): BOOL; stdcall; external 'advapi32.dll' name 'ControlService';
function EnumServicesStatusExW(hSCManager: THandle; InfoLevel, dwServiceType, dwServiceState: DWORD; lpServices: Pointer; cbBufSize: DWORD; var pcbBytesNeeded, lpServicesReturned, lpResumeHandle: DWORD; pszGroupName: PWideChar): BOOL; stdcall; external 'advapi32.dll' name 'EnumServicesStatusExW';
function CloseServiceHandle(hSCObject: THandle): BOOL; stdcall; external 'advapi32.dll' name 'CloseServiceHandle';

function GetExtendedTcpTable(pTcpTable: Pointer; pdwSize: PDWORD; bOrder: BOOL; ulAf: ULONG; TableClass: Integer; Reserved: ULONG): DWORD; stdcall; external 'iphlpapi.dll' name 'GetExtendedTcpTable';
function GetExtendedUdpTable(pUdpTable: Pointer; pdwSize: PDWORD; bOrder: BOOL; ulAf: ULONG; TableClass: Integer; Reserved: ULONG): DWORD; stdcall; external 'iphlpapi.dll' name 'GetExtendedUdpTable';
function GetIfTable(pIfTable: Pointer; var pdwSize: ULONG; bOrder: BOOL): DWORD; stdcall; external 'iphlpapi.dll' name 'GetIfTable';

function FileTimeToLargeInt(const FT: TFileTime): Int64;
begin
  Result := (Int64(FT.dwHighDateTime) shl 32) or FT.dwLowDateTime;
end;

function PriorityClassToStr(const APrio: DWORD; const ABasePrio: LongInt): string;
begin
  case APrio of
    $00000040: Result := 'Idle';
    $00004000: Result := 'Below Normal';
    $00000020: Result := 'Normal';
    $00008000: Result := 'Above Normal';
    $00000080: Result := 'High';
    $00000100: Result := 'Realtime';
  else
    if ABasePrio >= 13 then Result := 'High'
    else if ABasePrio <= 4 then Result := 'Idle'
    else Result := 'Normal';
  end;
end;

procedure CollectKernelProcStats(const AMap: TDictionary<Cardinal, TKernelProcStat>);
var
  BufSize, RetLen: DWORD;
  Buf: Pointer;
  Status: LongInt;
  Cur: PNtSystemProcessInfo;
  Stat: TKernelProcStat;
begin
  AMap.Clear;
  BufSize := 512 * 1024;
  RetLen := 0;
  GetMem(Buf, BufSize);
  try
    Status := NtQuerySystemInformation(SystemProcessInformation, Buf, BufSize, RetLen);
    if (Status = STATUS_INFO_LENGTH_MISMATCH) and (RetLen > BufSize) then
    begin
      FreeMem(Buf);
      BufSize := RetLen + 65536;
      GetMem(Buf, BufSize);
      Status := NtQuerySystemInformation(SystemProcessInformation, Buf, BufSize, RetLen);
    end;
    if Status = 0 then
    begin
      Cur := PNtSystemProcessInfo(Buf);
      while Assigned(Cur) do
      begin
        if Cur^.UniqueProcessId > 0 then
        begin
          Stat.WorkingSetMB := Cur^.WorkingSetSize / (1024.0 * 1024.0);
          Stat.TotalTime := Cur^.KernelTime + Cur^.UserTime;
          Stat.IoBytes := Cur^.ReadTransferCount + Cur^.WriteTransferCount;
          Stat.BasePriority := Cur^.BasePriority;
          Stat.SessionId := Cur^.SessionId;
          AMap.AddOrSetValue(Cardinal(Cur^.UniqueProcessId), Stat);
        end;
        if Cur^.NextEntryOffset = 0 then Break;
        Cur := PNtSystemProcessInfo(PByte(Cur) + Cur^.NextEntryOffset);
      end;
    end;
  finally
    FreeMem(Buf);
  end;
end;

function GetProcessOwner(const AProcessHandle: THandle): string;
var
  HToken: THandle;
  TokSize: DWORD;
  TokUser: Pointer;
  NameLen, DomLen: DWORD;
  SidUse: DWORD;
  NameBuf, DomBuf: array[0..255] of WideChar;
begin
  Result := '';
  if OpenProcessToken(AProcessHandle, TOKEN_QUERY, HToken) then
  begin
    try
      TokSize := 0;
      GetTokenInformation(HToken, 1 { TokenUser }, nil, 0, TokSize);
      if TokSize > 0 then
      begin
        GetMem(TokUser, TokSize);
        try
          if GetTokenInformation(HToken, 1 { TokenUser }, TokUser, TokSize, TokSize) then
          begin
            NameLen := 256;
            DomLen := 256;
            SidUse := 0;
            if LookupAccountSidW(nil, PPointer(TokUser)^, @NameBuf[0], NameLen, @DomBuf[0], DomLen, SidUse) then
            begin
              if DomLen > 0 then
                Result := WideCharToString(DomBuf) + '\' + WideCharToString(NameBuf)
              else
                Result := WideCharToString(NameBuf);
            end;
          end;
        finally
          FreeMem(TokUser);
        end;
      end;
    finally
      CloseHandle(HToken);
    end;
  end;
end;
{$ENDIF}

function TMetricsService.CalculateCpuUsage: Single;
{$IFDEF MSWINDOWS}
var
  IdleTime, KernelTime, UserTime: TFileTime;
  Idle, Kernel, User: Int64;
  TotalDiff, IdleDiff: Int64;
begin
  Result := 0.0;
  if GetSystemTimes(@IdleTime, @KernelTime, @UserTime) then
  begin
    Idle := FileTimeToLargeInt(IdleTime);
    Kernel := FileTimeToLargeInt(KernelTime);
    User := FileTimeToLargeInt(UserTime);

    if FHasPrevCpuTime then
    begin
      TotalDiff := (Kernel - FPrevKernelTime) + (User - FPrevUserTime);
      IdleDiff := Idle - FPrevIdleTime;

      if TotalDiff > 0 then
      begin
        Result := ((TotalDiff - IdleDiff) * 100.0) / TotalDiff;
        if Result < 0.0 then Result := 0.0;
        if Result > 100.0 then Result := 100.0;
      end;
    end
    else
    begin
      // First sample only establishes the baseline; 0 is honest until a
      // real delta exists on the next tick
      FHasPrevCpuTime := True;
      Result := 0.0;
    end;

    FPrevIdleTime := Idle;
    FPrevKernelTime := Kernel;
    FPrevUserTime := User;
  end;
end;
{$ELSE}
begin
  Result := 15.0;
end;
{$ENDIF}

function TMetricsService.CollectSnapshot: TSystemMetrics;
{$IFDEF MSWINDOWS}
var
  MemStatus: TWinMemoryStatusEx;
  FreeBytesAvailable, TotalNumberOfBytes, TotalNumberOfFreeBytes: Int64;
  RootPath: string;
  IfSize: ULONG;
  IfBuf: Pointer;
  IfTable: PMibIfTable;
  I: Integer;
  TotalIn, TotalOut, CurTick, ElapsedMs: UInt64;
begin
  Result := TSystemMetrics.CreateEmpty;
  FreeBytesAvailable := 0;
  TotalNumberOfBytes := 0;
  TotalNumberOfFreeBytes := 0;

  FLock.Enter;
  try
    Result.CpuUsagePercent := CalculateCpuUsage;

    MemStatus.dwLength := SizeOf(MemStatus);
    if GlobalMemoryStatusEx(MemStatus) then
    begin
      Result.MemoryLoadPercent := MemStatus.dwMemoryLoad;
      Result.TotalPhysicalMB := MemStatus.ullTotalPhys div (1024 * 1024);
      Result.AvailablePhysicalMB := MemStatus.ullAvailPhys div (1024 * 1024);
      Result.UsedPhysicalMB := Result.TotalPhysicalMB - Result.AvailablePhysicalMB;
    end;

    RootPath := ExtractFileDrive(GetEnvironmentVariable('SystemRoot')) + '\';
    if RootPath = '\' then RootPath := 'C:\';

    if GetDiskFreeSpaceEx(PChar(RootPath), FreeBytesAvailable, TotalNumberOfBytes, @TotalNumberOfFreeBytes) then
    begin
      Result.TotalDiskGB := TotalNumberOfBytes / (1024.0 * 1024.0 * 1024.0);
      Result.FreeDiskGB := FreeBytesAvailable / (1024.0 * 1024.0 * 1024.0);
      Result.UsedDiskGB := Result.TotalDiskGB - Result.FreeDiskGB;
      if Result.TotalDiskGB > 0 then
        Result.DiskUsagePercent := (Result.UsedDiskGB / Result.TotalDiskGB) * 100.0
      else
        Result.DiskUsagePercent := 0.0;
    end;

    // Network interface throughput (KB/s Down & Up)
    IfSize := 0;
    GetIfTable(nil, IfSize, False);
    if IfSize > 0 then
    begin
      GetMem(IfBuf, IfSize);
      try
        if GetIfTable(IfBuf, IfSize, False) = 0 then
        begin
          IfTable := PMibIfTable(IfBuf);
          TotalIn := 0;
          TotalOut := 0;
          for I := 0 to Integer(IfTable^.dwNumEntries) - 1 do
          begin
            if IfTable^.table[I].dwType <> MIB_IF_TYPE_LOOPBACK then
            begin
              TotalIn := TotalIn + IfTable^.table[I].dwInOctets;
              TotalOut := TotalOut + IfTable^.table[I].dwOutOctets;
            end;
          end;
          CurTick := GetTickCount64;
          if FHasPrevNetSample and (CurTick > FPrevNetTick) then
          begin
            ElapsedMs := CurTick - FPrevNetTick;
            if TotalIn >= FPrevNetInBytes then
              Result.NetDownloadKBps := ((TotalIn - FPrevNetInBytes) / 1024.0) * (1000.0 / ElapsedMs);
            if TotalOut >= FPrevNetOutBytes then
              Result.NetUploadKBps := ((TotalOut - FPrevNetOutBytes) / 1024.0) * (1000.0 / ElapsedMs);
          end;
          FPrevNetInBytes := TotalIn;
          FPrevNetOutBytes := TotalOut;
          FPrevNetTick := CurTick;
          FHasPrevNetSample := True;
        end;
      finally
        FreeMem(IfBuf);
      end;
    end;

    Result.UptimeSeconds := GetTickCount64 div 1000;
    Result.Timestamp := Now;
  finally
    FLock.Leave;
  end;
end;
{$ELSE}
begin
  Result := TSystemMetrics.CreateEmpty;
  Result.CpuUsagePercent := 12.0;
  Result.MemoryLoadPercent := 40;
  Result.TotalPhysicalMB := 16384;
  Result.UsedPhysicalMB := 6553;
  Result.AvailablePhysicalMB := 9831;
  Result.TotalDiskGB := 512.0;
  Result.UsedDiskGB := 180.0;
  Result.FreeDiskGB := 332.0;
  Result.DiskUsagePercent := 35.1;
  Result.UptimeSeconds := 3600;
  Result.Timestamp := Now;
end;
{$ENDIF}

function TMetricsService.CollectProcesses: TProcessList;
{$IFDEF MSWINDOWS}
var
  Snap: THandle;
  Entry: TWinProcessEntry32;
  ProcHandle: THandle;
  MemCounters: TWinProcessMemoryCounters;
  IoCounters: TWinIoCounters;
  SysIdle, SysKernel, SysUser: TFileTime;
  CreationT, ExitT, ProcKernelT, ProcUserT: TFileTime;
  Item: TProcessItem;
  MemMB, CpuPct, IoKBps: Single;
  Status: TItemStatus;
  Idx: Integer;
  ProcId: Cardinal;
  ProcTotal, TotalNow, TotalDelta, PrevProc: Int64;
  ProcIoBytes, PrevIo: Int64;
  CurIoTick, IoElapsedMs: UInt64;
  PrioClass: DWORD;
  BasePrio: LongInt;
  Meta: TProcessMeta;
  PathBuf: WideString;
  PathLen: DWORD;
  IsWow64: BOOL;
  KernelStats: TDictionary<Cardinal, TKernelProcStat>;
  KStat: TKernelProcStat;
  ProcName: string;
begin
  Result := TProcessList.Create(True);

  FLock.Enter;
  try
    FCurProcTimes.Clear;
    FCurProcIo.Clear;
    GetSystemTimes(@SysIdle, @SysKernel, @SysUser);
    TotalNow := FileTimeToLargeInt(SysKernel) + FileTimeToLargeInt(SysUser);
    CurIoTick := GetTickCount64;
    if FHasPrevProcSample and (CurIoTick > FPrevProcIoTick) then
      IoElapsedMs := CurIoTick - FPrevProcIoTick
    else
      IoElapsedMs := 0;

    KernelStats := TDictionary<Cardinal, TKernelProcStat>.Create;
    try
      CollectKernelProcStats(KernelStats);

      Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
      if Snap = INVALID_HANDLE_VALUE then
        Exit;

      try
        FillChar(Entry, SizeOf(Entry), 0);
        Entry.dwSize := SizeOf(Entry);

        if Process32First(Snap, Entry) then
        repeat
          if Entry.th32ProcessID = 0 then Continue; // System Idle Process

          ProcId := Entry.th32ProcessID;
          ProcName := StrPas(Entry.szExeFile);
          MemMB := 0.0;
          ProcTotal := 0;
          ProcIoBytes := 0;
          PrioClass := 0;
          BasePrio := Entry.pcPriClassBase;

          if KernelStats.TryGetValue(ProcId, KStat) then
          begin
            MemMB := KStat.WorkingSetMB;
            ProcTotal := KStat.TotalTime;
            ProcIoBytes := KStat.IoBytes;
            BasePrio := KStat.BasePriority;
          end;

          ProcHandle := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, ProcId);
          if ProcHandle <> 0 then
          try
            MemCounters.cb := SizeOf(MemCounters);
            if GetProcessMemoryInfo(ProcHandle, @MemCounters, MemCounters.cb) then
              if MemCounters.WorkingSetSize > 0 then
                MemMB := MemCounters.WorkingSetSize / (1024.0 * 1024.0);
            // Kernel+user CPU time totals; sampled against the previous scan
            if GetProcessTimes(ProcHandle, CreationT, ExitT, ProcKernelT, ProcUserT) then
              ProcTotal := FileTimeToLargeInt(ProcKernelT) + FileTimeToLargeInt(ProcUserT);
            if GetProcessIoCounters(ProcHandle, IoCounters) then
              ProcIoBytes := Int64(IoCounters.ReadTransferCount + IoCounters.WriteTransferCount);
            PrioClass := GetPriorityClass(ProcHandle);

            if not FProcMetaCache.TryGetValue(ProcId, Meta) then
            begin
              Meta.ImagePath := '';
              Meta.UserName := '';
              Meta.Architecture := '64-bit';

              PathLen := 512;
              SetLength(PathBuf, PathLen);
              if QueryFullProcessImageNameW(ProcHandle, 0, PWideChar(PathBuf), PathLen) then
              begin
                SetLength(PathBuf, PathLen);
                Meta.ImagePath := PathBuf;
              end;

              IsWow64 := False;
              if IsWow64Process(ProcHandle, IsWow64) then
              begin
                if IsWow64 then Meta.Architecture := '32-bit' else Meta.Architecture := '64-bit';
              end;

              Meta.UserName := GetProcessOwner(ProcHandle);
              if Meta.UserName = '' then
                Meta.UserName := 'NT AUTHORITY\SYSTEM';
              if Meta.ImagePath = '' then
                Meta.ImagePath := ProcName;
              FProcMetaCache.AddOrSetValue(ProcId, Meta);
            end;
          finally
            CloseHandle(ProcHandle);
          end
          else
          begin
            if not FProcMetaCache.TryGetValue(ProcId, Meta) then
            begin
              Meta.UserName := 'NT AUTHORITY\SYSTEM';
              Meta.Architecture := '64-bit';
              if ProcId = 4 then
                Meta.ImagePath := 'ntoskrnl.exe'
              else if Pos('.', ProcName) = 0 then
                Meta.ImagePath := '[System Kernel]'
              else
                Meta.ImagePath := ProcName;
              FProcMetaCache.AddOrSetValue(ProcId, Meta);
            end;
          end;
          FCurProcTimes.AddOrSetValue(ProcId, ProcTotal);
          FCurProcIo.AddOrSetValue(ProcId, ProcIoBytes);

          CpuPct := 0.0;
          if FHasPrevProcSample and FPrevProcTimes.TryGetValue(ProcId, PrevProc) then
          begin
            TotalDelta := TotalNow - FPrevProcTotalTime;
            if (TotalDelta > 0) and (ProcTotal > PrevProc) then
            begin
              CpuPct := ((ProcTotal - PrevProc) * 100.0) / TotalDelta;
              if CpuPct < 0.0 then CpuPct := 0.0;
              if CpuPct > 100.0 then CpuPct := 100.0;
            end;
          end;

          IoKBps := 0.0;
          if FHasPrevProcSample and (IoElapsedMs > 0) and FPrevProcIo.TryGetValue(ProcId, PrevIo) then
          begin
            if ProcIoBytes > PrevIo then
              IoKBps := ((ProcIoBytes - PrevIo) / 1024.0) * (1000.0 / IoElapsedMs);
          end;

          // Health from CPU share and working set
          if MemMB >= 1024.0 then
            Status := isCritical
          else if (MemMB >= 400.0) or (CpuPct >= 10.0) then
            Status := isWarning
          else if (MemMB < 1.0) and (CpuPct < 0.1) then
            Status := isIdle
          else
            Status := isNormal;

          Item := TProcessItem.Create(
            ProcId,
            ProcName,
            MemMB,
            CpuPct,
            Status,
            Entry.cntThreads,
            '');

          Item.ParentId := Entry.th32ParentProcessID;
          Item.ImagePath := Meta.ImagePath;
          Item.UserName := Meta.UserName;
          Item.Architecture := Meta.Architecture;
          Item.DiskIoKBps := IoKBps;
          Item.PriorityText := PriorityClassToStr(PrioClass, BasePrio);

        // Keep largest memory consumers first; sorted insertion instead of a
        // comparer callback (FPC 3.2 stable has no anonymous methods)
        Idx := Result.Count;
        while (Idx > 0) and (Result[Idx - 1].MemoryWorkingSetMB < MemMB) do
          Dec(Idx);
        Result.Insert(Idx, Item);
      until not Process32Next(Snap, Entry);
      finally
        CloseHandle(Snap);
      end;
    finally
      KernelStats.Free;
    end;

    // This scan becomes the baseline for the next one; free the replaced
    // dictionary so each cycle does not orphan one TDictionary instance
    FPrevProcTimes.Free;
    FPrevProcTimes := FCurProcTimes;
    FCurProcTimes := TDictionary<Cardinal, Int64>.Create;
    FPrevProcIo.Free;
    FPrevProcIo := FCurProcIo;
    FCurProcIo := TDictionary<Cardinal, Int64>.Create;
    FHasPrevProcSample := True;
    FPrevProcTotalTime := TotalNow;
    FPrevProcIoTick := CurIoTick;
  finally
    FLock.Leave;
  end;
end;
{$ELSE}
begin
  // Non-Windows fallback: sample workload list
  Result := TProcessList.Create(True);
  Result.Add(TProcessItem.Create(3812, 'NovaMonitor', 34.2, 0.8, isNormal, 6, 'Nova Telemetry Engine'));
  Result.Add(TProcessItem.Create(7890, 'code', 480.2, 3.2, isWarning, 42, 'Editor Workspace Host'));
  Result.Add(TProcessItem.Create(8204, 'chrome', 784.0, 4.8, isWarning, 56, 'Browser Main Process'));
end;
{$ENDIF}

procedure TMetricsService.StartMonitoring(const AIntervalMs: Cardinal;
  const OnUpdate: TMetricsUpdateEvent;
  const OnProcessUpdate: TProcessListUpdateEvent);
begin
  if IsMonitoring then Exit;
  FIntervalMs := AIntervalMs;
  FWorker := TMetricsWorkerThread.Create(Self, AIntervalMs, OnUpdate, OnProcessUpdate);
end;

procedure TMetricsService.StopMonitoring;
begin
  if Assigned(FWorker) then
  begin
    FWorker.Terminate;
    FWorker.StopPolling;
    FWorker.WaitFor;
    FWorker.Free;
    FWorker := nil;
  end;
end;

function TMetricsService.IsMonitoring: Boolean;
begin
  Result := Assigned(FWorker);
end;

procedure TMetricsService.SetInterval(const AIntervalMs: Cardinal);
begin
  FIntervalMs := AIntervalMs;
  if Assigned(FWorker) then
    FWorker.IntervalMs := AIntervalMs;
end;

function TMetricsService.GetInterval: Cardinal;
begin
  Result := FIntervalMs;
end;

function TMetricsService.TerminateProcessById(const AProcessId: Cardinal): Boolean;
var
  HProc: THandle;
begin
  Result := False;
  // Guard system critical processes (PID 0 = Idle, PID 4 = System) and current process
  if (AProcessId <= 4) or (AProcessId = GetCurrentProcessId) then
    Exit;

  HProc := OpenProcess(PROCESS_TERMINATE, False, AProcessId);
  if HProc <> 0 then
  begin
    try
      Result := Windows.TerminateProcess(HProc, 1);
    finally
      CloseHandle(HProc);
    end;
  end;
end;

function TMetricsService.SetProcessPriorityById(const AProcessId: Cardinal; const APriorityClass: Cardinal): Boolean;
{$IFDEF MSWINDOWS}
var
  HProc: THandle;
begin
  Result := False;
  if AProcessId <= 4 then Exit;
  HProc := OpenProcess(PROCESS_SET_INFORMATION, False, AProcessId);
  if HProc <> 0 then
  begin
    try
      Result := SetPriorityClass(HProc, APriorityClass);
    finally
      CloseHandle(HProc);
    end;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function TMetricsService.SuspendResumeProcessById(const AProcessId: Cardinal; const ASuspend: Boolean): Boolean;
{$IFDEF MSWINDOWS}
var
  HProc: THandle;
begin
  Result := False;
  if (AProcessId <= 4) or (AProcessId = GetCurrentProcessId) then Exit;
  HProc := OpenProcess(PROCESS_SUSPEND_RESUME, False, AProcessId);
  if HProc <> 0 then
  begin
    try
      if ASuspend then
        Result := (NtSuspendProcess(HProc) = 0)
      else
        Result := (NtResumeProcess(HProc) = 0);
    finally
      CloseHandle(HProc);
    end;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function TMetricsService.ControlWindowsService(const AServiceName: string; const AAction: Integer): Boolean;
{$IFDEF MSWINDOWS}
var
  HSCM, HSvc: THandle;
  SvcStatus: TServiceStatus;
  WName: WideString;
begin
  Result := False;
  if AServiceName = '' then Exit;
  HSCM := OpenSCManagerW(nil, nil, SC_MANAGER_CONNECT);
  if HSCM = 0 then Exit;
  try
    WName := WideString(AServiceName);
    HSvc := OpenServiceW(HSCM, PWideChar(WName), SERVICE_START or SERVICE_STOP or SERVICE_QUERY_STATUS);
    if HSvc <> 0 then
    begin
      try
        FillChar(SvcStatus, SizeOf(SvcStatus), 0);
        case AAction of
          0: Result := StartServiceW(HSvc, 0, nil);
          1: Result := ControlService(HSvc, SERVICE_CONTROL_STOP, SvcStatus);
          2: begin
               ControlService(HSvc, SERVICE_CONTROL_STOP, SvcStatus);
               Sleep(250);
               Result := StartServiceW(HSvc, 0, nil);
             end;
        end;
      finally
        CloseServiceHandle(HSvc);
      end;
    end;
  finally
    CloseServiceHandle(HSCM);
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function TMetricsService.GetProcessModules(const AProcessId: Cardinal): TStringList;
{$IFDEF MSWINDOWS}
var
  HProc: THandle;
  Mods: array[0..511] of THandle;
  Needed, Count, I, Len: DWORD;
  ModPath: array[0..511] of WideChar;
  S: string;
begin
  Result := TStringList.Create;
  if AProcessId <= 4 then
  begin
    Result.Add('ntoskrnl.exe (Windows NT Kernel System Process)');
    Exit;
  end;

  HProc := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, AProcessId);
  if HProc = 0 then
    HProc := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, AProcessId);

  if HProc <> 0 then
  begin
    try
      Needed := 0;
      if EnumProcessModules(HProc, @Mods[0], SizeOf(Mods), Needed) and (Needed > 0) then
      begin
        Count := Needed div SizeOf(THandle);
        if Count > 512 then Count := 512;
        for I := 0 to Integer(Count) - 1 do
        begin
          FillChar(ModPath, SizeOf(ModPath), 0);
          if GetModuleFileNameExW(HProc, Mods[I], @ModPath[0], 511) > 0 then
          begin
            S := WideCharToString(ModPath);
            if S <> '' then
              Result.Add(Format('[0x%p]  %s  —  %s', [Pointer(Mods[I]), ExtractFileName(S), S]));
          end;
        end;
      end;

      if Result.Count = 0 then
      begin
        Len := 511;
        FillChar(ModPath, SizeOf(ModPath), 0);
        if QueryFullProcessImageNameW(HProc, 0, @ModPath[0], Len) then
        begin
          S := WideCharToString(ModPath);
          Result.Add(Format('%s  —  %s (Protected module list)', [ExtractFileName(S), S]));
        end;
      end;
    finally
      CloseHandle(HProc);
    end;
  end;

  if Result.Count = 0 then
    Result.Add('Access restricted by Windows Protected Process Light (PPL) security.');
end;
{$ELSE}
begin
  Result := TStringList.Create;
end;
{$ENDIF}

function TMetricsService.CollectNetworkConnections: TNetworkConnectionList;
{$IFDEF MSWINDOWS}
var
  TcpSize, UdpSize: DWORD;
  TcpBuf, UdpBuf: Pointer;
  TcpTable: PMibTcpTableOwnerPid;
  UdpTable: PMibUdpTableOwnerPid;
  I: Integer;
  Pid: Cardinal;
  PName, LocalIp, RemoteIp, StateStr: string;
  LocalPort, RemotePort: Word;
  Snap: THandle;
  Entry: TWinProcessEntry32;
  ProcNames: TDictionary<Cardinal, string>;
begin
  Result := TNetworkConnectionList.Create(True);
  ProcNames := TDictionary<Cardinal, string>.Create;
  try
    // Build quick PID -> Name map
    Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if Snap <> INVALID_HANDLE_VALUE then
    begin
      try
        FillChar(Entry, SizeOf(Entry), 0);
        Entry.dwSize := SizeOf(Entry);
        if Process32First(Snap, Entry) then
        repeat
          ProcNames.AddOrSetValue(Entry.th32ProcessID, StrPas(Entry.szExeFile));
        until not Process32Next(Snap, Entry);
      finally
        CloseHandle(Snap);
      end;
    end;

    // 1. TCP Connections
    TcpSize := 0;
    GetExtendedTcpTable(nil, @TcpSize, True, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0);
    if TcpSize > 0 then
    begin
      GetMem(TcpBuf, TcpSize);
      try
        if GetExtendedTcpTable(TcpBuf, @TcpSize, True, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0) = 0 then
        begin
          TcpTable := PMibTcpTableOwnerPid(TcpBuf);
          for I := 0 to Integer(TcpTable^.dwNumEntries) - 1 do
          begin
            Pid := TcpTable^.table[I].dwOwningPid;
            if not ProcNames.TryGetValue(Pid, PName) then
              PName := Format('PID %d', [Pid]);

            LocalIp := Format('%d.%d.%d.%d', [
              TcpTable^.table[I].dwLocalAddr and $FF,
              (TcpTable^.table[I].dwLocalAddr shr 8) and $FF,
              (TcpTable^.table[I].dwLocalAddr shr 16) and $FF,
              (TcpTable^.table[I].dwLocalAddr shr 24) and $FF]);
            LocalPort := ((TcpTable^.table[I].dwLocalPort and $FF) shl 8) or
                         ((TcpTable^.table[I].dwLocalPort shr 8) and $FF);

            RemoteIp := Format('%d.%d.%d.%d', [
              TcpTable^.table[I].dwRemoteAddr and $FF,
              (TcpTable^.table[I].dwRemoteAddr shr 8) and $FF,
              (TcpTable^.table[I].dwRemoteAddr shr 16) and $FF,
              (TcpTable^.table[I].dwRemoteAddr shr 24) and $FF]);
            RemotePort := ((TcpTable^.table[I].dwRemotePort and $FF) shl 8) or
                          ((TcpTable^.table[I].dwRemotePort shr 8) and $FF);

            case TcpTable^.table[I].dwState of
              1: StateStr := 'CLOSED';
              2: StateStr := 'LISTENING';
              3: StateStr := 'SYN_SENT';
              4: StateStr := 'SYN_RCVD';
              5: StateStr := 'ESTABLISHED';
              6: StateStr := 'FIN_WAIT1';
              7: StateStr := 'FIN_WAIT2';
              8: StateStr := 'CLOSE_WAIT';
              9: StateStr := 'CLOSING';
              10: StateStr := 'LAST_ACK';
              11: StateStr := 'TIME_WAIT';
              12: StateStr := 'DELETE_TCB';
            else
              StateStr := 'UNKNOWN';
            end;

            Result.Add(TNetworkConnectionItem.Create(
              Pid, PName, 'TCP', LocalIp, LocalPort, RemoteIp, RemotePort, StateStr
            ));
          end;
        end;
      finally
        FreeMem(TcpBuf);
      end;
    end;

    // 2. UDP Endpoints
    UdpSize := 0;
    GetExtendedUdpTable(nil, @UdpSize, True, AF_INET, UDP_TABLE_OWNER_PID, 0);
    if UdpSize > 0 then
    begin
      GetMem(UdpBuf, UdpSize);
      try
        if GetExtendedUdpTable(UdpBuf, @UdpSize, True, AF_INET, UDP_TABLE_OWNER_PID, 0) = 0 then
        begin
          UdpTable := PMibUdpTableOwnerPid(UdpBuf);
          for I := 0 to Integer(UdpTable^.dwNumEntries) - 1 do
          begin
            Pid := UdpTable^.table[I].dwOwningPid;
            if not ProcNames.TryGetValue(Pid, PName) then
              PName := Format('PID %d', [Pid]);

            LocalIp := Format('%d.%d.%d.%d', [
              UdpTable^.table[I].dwLocalAddr and $FF,
              (UdpTable^.table[I].dwLocalAddr shr 8) and $FF,
              (UdpTable^.table[I].dwLocalAddr shr 16) and $FF,
              (UdpTable^.table[I].dwLocalAddr shr 24) and $FF]);
            LocalPort := ((UdpTable^.table[I].dwLocalPort and $FF) shl 8) or
                         ((UdpTable^.table[I].dwLocalPort shr 8) and $FF);

            Result.Add(TNetworkConnectionItem.Create(
              Pid, PName, 'UDP', LocalIp, LocalPort, '*.*.*.*', 0, 'LISTENING'
            ));
          end;
        end;
      finally
        FreeMem(UdpBuf);
      end;
    end;

  finally
    ProcNames.Free;
  end;
end;
{$ELSE}
begin
  Result := TNetworkConnectionList.Create(True);
  Result.Add(TNetworkConnectionItem.Create(1024, 'system', 'TCP', '127.0.0.1', 8080, '0.0.0.0', 0, 'LISTENING'));
  Result.Add(TNetworkConnectionItem.Create(3812, 'NovaMonitor', 'TCP', '192.168.1.100', 54321, '142.250.190.46', 443, 'ESTABLISHED'));
end;
{$ENDIF}

function TMetricsService.CollectServices: TServiceList;
{$IFDEF MSWINDOWS}
var
  HSCM: THandle;
  BytesNeeded, ServicesReturned, ResumeHandle: DWORD;
  Buffer: Pointer;
  StatProcess: PEnumServiceStatusProcessW;
  I: Integer;
  ServiceName, DisplayName, StateStr: string;
  Pid, CurState, SvcType: Cardinal;
begin
  Result := TServiceList.Create(True);
  HSCM := OpenSCManagerW(nil, nil, SC_MANAGER_ENUMERATE_SERVICE);
  if HSCM = 0 then Exit;

  try
    BytesNeeded := 0;
    ServicesReturned := 0;
    ResumeHandle := 0;

    EnumServicesStatusExW(
      HSCM,
      SC_ENUM_PROCESS_INFO,
      SERVICE_WIN32,
      SERVICE_STATE_ALL,
      nil,
      0,
      BytesNeeded,
      ServicesReturned,
      ResumeHandle,
      nil
    );

    if BytesNeeded > 0 then
    begin
      GetMem(Buffer, BytesNeeded);
      try
        ResumeHandle := 0;
        if EnumServicesStatusExW(
          HSCM,
          SC_ENUM_PROCESS_INFO,
          SERVICE_WIN32,
          SERVICE_STATE_ALL,
          Buffer,
          BytesNeeded,
          BytesNeeded,
          ServicesReturned,
          ResumeHandle,
          nil
        ) then
        begin
          for I := 0 to Integer(ServicesReturned) - 1 do
          begin
            StatProcess := PEnumServiceStatusProcessW(PByte(Buffer) + I * SizeOf(TEnumServiceStatusProcessW));
            ServiceName := WideCharToString(StatProcess^.lpServiceName);
            DisplayName := WideCharToString(StatProcess^.lpDisplayName);
            Pid := StatProcess^.ServiceStatusProcess.dwProcessId;
            CurState := StatProcess^.ServiceStatusProcess.dwCurrentState;
            SvcType := StatProcess^.ServiceStatusProcess.dwServiceType;

            case CurState of
              SERVICE_STOPPED: StateStr := 'Stopped';
              SERVICE_START_PENDING: StateStr := 'Starting';
              SERVICE_STOP_PENDING: StateStr := 'Stopping';
              SERVICE_RUNNING: StateStr := 'Running';
              SERVICE_CONTINUE_PENDING: StateStr := 'Resuming';
              SERVICE_PAUSE_PENDING: StateStr := 'Pausing';
              SERVICE_PAUSED: StateStr := 'Paused';
            else
              StateStr := 'Unknown';
            end;

            Result.Add(TServiceItem.Create(
              ServiceName, DisplayName, Pid, CurState, SvcType, StateStr
            ));
          end;
        end;
      finally
        FreeMem(Buffer);
      end;
    end;

  finally
    CloseServiceHandle(HSCM);
  end;
end;
{$ELSE}
begin
  Result := TServiceList.Create(True);
  Result.Add(TServiceItem.Create('WinDefend', 'Microsoft Defender Antivirus Service', 2140, 4, $20, 'Running'));
  Result.Add(TServiceItem.Create('wuauserv', 'Windows Update', 3110, 4, $20, 'Running'));
  Result.Add(TServiceItem.Create('Spooler', 'Print Spooler', 0, 1, $10, 'Stopped'));
end;
{$ENDIF}

end.
