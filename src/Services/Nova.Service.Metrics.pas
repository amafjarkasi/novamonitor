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
  {$IFDEF FPC}
  Registry,
  {$ELSE}
  Winapi.Registry,
  {$ENDIF}
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
    CommandLine: string;
    Description: string;
    CompanyName: string;
    FileVersion: string;
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
    FPrevCoreIdle: array of Int64;
    FPrevCoreTotal: array of Int64;
    FHasPrevCoreSample: Boolean;
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

    // Per-PID TCP byte counters (GetPerTcpConnectionEStats) for per-process network rates
    FPrevProcNet: TDictionary<Cardinal, Int64>;
    FCurProcNet: TDictionary<Cardinal, Int64>;
    FHasPrevProcNetSample: Boolean;
    // GPU telemetry: PDH query with engine-utilization and process-memory counters,
    // plus a one-time DXGI adapter enumeration cache
    FGpuPdhQuery: THandle;
    FGpuEngCounter: THandle;
    FGpuLocalCounter: THandle;
    FGpuNonLocalCounter: THandle;
    FGpuPdhState: Integer; // 0 = not attempted, 1 = ready, 2 = unavailable
    FGpuAdapterName: string;
    FGpuDedicatedTotalMB: UInt64;
    FGpuAdapterCount: Integer;
    FGpuAdapterDone: Boolean;

    function CalculateCpuUsage: Single;
    function CalculateCoreUsages: TSingleDynArray;
    procedure EnsureGpuTelemetry;
    procedure CloseGpuTelemetry;
    procedure CollectGpuInfo(var AGpu: TGpuInfo);
    procedure CollectTcpEstatsBytes(const AMap: TDictionary<Cardinal, Int64>);
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
    function GetProcessAffinityById(const AProcessId: Cardinal; out AProcessMask, ASystemMask: NativeUInt): Boolean;
    function SetProcessAffinityById(const AProcessId: Cardinal; const AProcessMask: NativeUInt): Boolean;
    function RunNewTask(const ACommand: string; const ARunAsAdmin: Boolean): Boolean;
    function RestartProcessById(const AProcessId: Cardinal): Boolean;
    function ControlWindowsService(const AServiceName: string; const AAction: Integer): Boolean;
    function GetProcessModules(const AProcessId: Cardinal): TStringList;
    function CollectStartupEntries: TStartupList;
    function SetStartupEntryEnabled(const AItem: TStartupItem; const AEnable: Boolean): Boolean;
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
  FHasPrevCoreSample := False;
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
  FPrevProcNet := TDictionary<Cardinal, Int64>.Create;
  FCurProcNet := TDictionary<Cardinal, Int64>.Create;
  FHasPrevProcNetSample := False;
  FProcMetaCache := TDictionary<Cardinal, TProcessMeta>.Create;
  FHasPrevProcSample := False;
  FPrevProcTotalTime := 0;
  FPrevProcIoTick := 0;
  FGpuPdhQuery := 0;
  FGpuEngCounter := 0;
  FGpuLocalCounter := 0;
  FGpuNonLocalCounter := 0;
  FGpuPdhState := 0;
  FGpuDedicatedTotalMB := 0;
  FGpuAdapterCount := 0;
  FGpuAdapterDone := False;
  FIntervalMs := 1500;
end;

destructor TMetricsService.Destroy;
begin
  StopMonitoring;
  {$IFDEF MSWINDOWS}
  CloseGpuTelemetry;
  {$ENDIF}
  FProcMetaCache.Free;
  FCurProcIo.Free;
  FPrevProcIo.Free;
  FCurProcNet.Free;
  FPrevProcNet.Free;
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
    HandleCount: DWORD;
  end;

  TNtProcessorPerfInfo = record
    IdleTime: Int64;
    KernelTime: Int64;
    UserTime: Int64;
    DpcTime: Int64;
    InterruptTime: Int64;
    InterruptCount: DWORD;
    Reserved: DWORD;
  end;

  TNtUnicodeString = record
    Length: Word;
    MaximumLength: Word;
    {$IFDEF CPU64}
    Pad: DWORD;
    {$ENDIF}
    Buffer: PWideChar;
  end;
  PNtUnicodeString = ^TNtUnicodeString;

  TLangAndCodePage = packed record
    wLanguage: Word;
    wCodePage: Word;
  end;
  PLangAndCodePage = ^TLangAndCodePage;

  TShellExecuteInfoW = record
    cbSize: DWORD;
    fMask: ULONG;
    Wnd: HWND;
    lpVerb: PWideChar;
    lpFile: PWideChar;
    lpParameters: PWideChar;
    lpDirectory: PWideChar;
    nShow: Integer;
    hInstApp: HINST;
    lpIDList: Pointer;
    lpClass: PWideChar;
    hkeyClass: HKEY;
    dwHotKey: DWORD;
    hIconOrMonitor: THandle;
    hProcess: THandle;
  end;

  // PDH formatted counter value (union of long / large / double after CStatus)
  TPdhFmtCounterValue = record
    CStatus: LongInt;
    case Integer of
      0: (LongValue: LongInt);
      1: (LargeValue: Int64);
      2: (DoubleValue: Double);
  end;

  TPdhFmtCounterValueItemW = record
    SzValue: PWideChar;
    FmtValue: TPdhFmtCounterValue;
  end;
  PPdhFmtCounterValueItemW = ^TPdhFmtCounterValueItemW;

  TPdhItemArray = array[0..0] of TPdhFmtCounterValueItemW;
  PPdhItemArray = ^TPdhItemArray;

  // DXGI adapter description (mirrors DXGI_ADAPTER_DESC); loaded via vtable
  // calls so no DirectX headers or import libraries are required
  TDXGIAdapterDesc = record
    Description: array[0..127] of WideChar;
    VendorId: DWORD;
    DeviceId: DWORD;
    SubSysId: DWORD;
    Revision: DWORD;
    DedicatedVideoMemory: NativeUInt;
    DedicatedSystemMemory: NativeUInt;
    SharedSystemMemory: NativeUInt;
    Reserved: NativeUInt;
  end;

  TDxgiAdapterVtable = record
    QueryInterface: Pointer;
    AddRef: Pointer;
    Release: function(self: Pointer): Cardinal; stdcall;
    SetPrivateData: Pointer;
    SetPrivateDataInterface: Pointer;
    GetPrivateData: Pointer;
    GetParent: Pointer;
    EnumOutputs: Pointer;
    GetDesc: function(self: Pointer; out ADesc: TDXGIAdapterDesc): HResult; stdcall;
    CheckInterfaceSupport: Pointer;
  end;
  PDxgiAdapterVtable = ^TDxgiAdapterVtable;

  TDxgiAdapterObj = record
    Vtbl: PDxgiAdapterVtable;
  end;
  PDxgiAdapterObj = ^TDxgiAdapterObj;

  // IDXGIFactory: IUnknown(3) + IDXGIObject(4), then EnumAdapters at slot 7
  TDxgiFactoryVtable = record
    QueryInterface: Pointer;
    AddRef: Pointer;
    Release: function(self: Pointer): Cardinal; stdcall;
    SetPrivateData: Pointer;
    SetPrivateDataInterface: Pointer;
    GetPrivateData: Pointer;
    GetParent: Pointer;
    EnumAdapters: function(self: Pointer; Adapter: DWORD; out pAdapter: PDxgiAdapterObj): HResult; stdcall;
    MakeWindowAssociation: Pointer;
    GetWindowAssociation: Pointer;
    CreateSwapChain: Pointer;
  end;
  PDxgiFactoryVtable = ^TDxgiFactoryVtable;

  TDxgiFactoryObj = record
    Vtbl: PDxgiFactoryVtable;
  end;
  PDxgiFactoryObj = ^TDxgiFactoryObj;

  TCreateDxgiFactory1 = function(const riid: TGUID; out ppFactory: Pointer): HResult; stdcall;

const
  // Local declarations shadow Windows-unit constants where present
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
  PROCESS_SET_INFORMATION = $0200;
  PROCESS_SUSPEND_RESUME = $0800;
  PROCESS_QUERY_INFORMATION = $0400;
  PROCESS_VM_READ = $0010;
  TH32CS_SNAPPROCESS = $2;
  SystemProcessInformation = 5;
  SystemProcessorPerformanceInformation = 8;
  ProcessCommandLineInformation = 60;
  STATUS_INFO_LENGTH_MISMATCH = LongInt($C0000004);
  STATUS_BUFFER_TOO_SMALL = LongInt($C0000023);
  STATUS_BUFFER_OVERFLOW = LongInt($80000005);

  GR_GDIOBJECTS = 0;
  GR_USEROBJECTS = 1;

  // PDH formats / status
  PDH_FMT_DOUBLE = $00000200;
  PDH_MORE_DATA = DWORD($800007D2);
  PDH_ERROR_SUCCESS = 0;

  // TCP extended estats: TcpConnectionEstatsData rod layout is four ULONG64s
  TcpConnectionEstatsData = 1;
  TcpEstatsRodBytes = 32;

  // Startup enumeration roots (relative paths under the respective hives)
  RunKeyPath = 'Software\Microsoft\Windows\CurrentVersion\Run';
  RunKeyPathWow64 = 'Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run';
  StartupApprovedRun = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';
  StartupApprovedStartup = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Startup';

  CSIDL_STARTUP = $0007;
  CSIDL_COMMON_STARTUP = $0018;

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
function GetProcessAffinityMask(hProcess: THandle; var lpProcessAffinityMask, lpSystemAffinityMask: NativeUInt): BOOL; stdcall; external 'kernel32.dll' name 'GetProcessAffinityMask';
function SetProcessAffinityMask(hProcess: THandle; dwProcessAffinityMask: NativeUInt): BOOL; stdcall; external 'kernel32.dll' name 'SetProcessAffinityMask';
function GetGuiResources(hProcess: THandle; uiFlags: DWORD): DWORD; stdcall; external 'user32.dll' name 'GetGuiResources';
function GetFileVersionInfoSizeW(lptstrFilename: PWideChar; var lpdwHandle: DWORD): DWORD; stdcall; external 'version.dll' name 'GetFileVersionInfoSizeW';
function GetFileVersionInfoW(lptstrFilename: PWideChar; dwHandle, dwLen: DWORD; lpData: Pointer): BOOL; stdcall; external 'version.dll' name 'GetFileVersionInfoW';
function VerQueryValueW(pBlock: Pointer; lpSubBlock: PWideChar; var lplpBuffer: Pointer; var puLen: UINT): BOOL; stdcall; external 'version.dll' name 'VerQueryValueW';
function ShellExecuteExW(var lpExecInfo: TShellExecuteInfoW): BOOL; stdcall; external 'shell32.dll' name 'ShellExecuteExW';
function NtQuerySystemInformation(SystemInformationClass: DWORD; SystemInformation: Pointer; SystemInformationLength: DWORD; var ReturnLength: DWORD): LongInt; stdcall; external 'ntdll.dll' name 'NtQuerySystemInformation';
function NtQueryInformationProcess(ProcessHandle: THandle; ProcessInformationClass: DWORD; ProcessInformation: Pointer; ProcessInformationLength: DWORD; var ReturnLength: DWORD): LongInt; stdcall; external 'ntdll.dll' name 'NtQueryInformationProcess';
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
function GetPerTcpConnectionEStats(Row: Pointer; EstatsType: Integer; Rw: PByte; RwLength: DWORD; RwOffset: DWORD; Rod: PByte; RodLength: DWORD; RodOffset: DWORD; RodData: PByte; RodDataLength: DWORD; RodDataOffset: DWORD): DWORD; stdcall; external 'iphlpapi.dll' name 'GetPerTcpConnectionEStats';

// PDH counter queries for GPU engine utilization and GPU process memory.
// PdhAddEnglishCounterW accepts English counter paths on localized Windows.
function PdhOpenQueryW(szDataSource: PWideChar; dwUserData: DWORD; var phQuery: THandle): DWORD; stdcall; external 'pdh.dll' name 'PdhOpenQueryW';
function PdhAddEnglishCounterW(hQuery: THandle; szFullCounterPath: PWideChar; dwUserData: DWORD; var phCounter: THandle): DWORD; stdcall; external 'pdh.dll' name 'PdhAddEnglishCounterW';
function PdhCollectQueryData(hQuery: THandle): DWORD; stdcall; external 'pdh.dll' name 'PdhCollectQueryData';
function PdhGetFormattedCounterArrayW(hCounter: THandle; dwFormat: DWORD; var lpdwBufferSize: DWORD; var lpdwItemCount: DWORD; ItemBuffer: Pointer): DWORD; stdcall; external 'pdh.dll' name 'PdhGetFormattedCounterArrayW';
procedure PdhCloseQuery(hQuery: THandle); stdcall; external 'pdh.dll' name 'PdhCloseQuery';

function SHGetFolderPathW(hwndOwner: HWND; nFolder: Integer; hToken: THandle; dwFlags: DWORD; pszPath: PWideChar): HResult; stdcall; external 'shell32.dll' name 'SHGetFolderPathW';

function FileTimeToLargeInt(const FT: TFileTime): Int64;
begin
  Result := (Int64(FT.dwHighDateTime) shl 32) or FT.dwLowDateTime;
end;

function SumPdhCounterArray(const ACounter: THandle): Double;
var
  BufSize, ItemCount: DWORD;
  Buf: Pointer;
  Items: PPdhItemArray;
  I: Integer;
begin
  Result := 0.0;
  if ACounter = 0 then Exit;
  BufSize := 0;
  ItemCount := 0;
  if PdhGetFormattedCounterArrayW(ACounter, PDH_FMT_DOUBLE, BufSize, ItemCount, nil) = PDH_MORE_DATA then
  begin
    GetMem(Buf, BufSize);
    try
      if PdhGetFormattedCounterArrayW(ACounter, PDH_FMT_DOUBLE, BufSize, ItemCount, Buf) = PDH_ERROR_SUCCESS then
      begin
        Items := PPdhItemArray(Buf);
        for I := 0 to Integer(ItemCount) - 1 do
          if Items^[I].FmtValue.CStatus = 0 then
            Result := Result + Items^[I].FmtValue.DoubleValue;
      end;
    finally
      FreeMem(Buf);
    end;
  end;
end;

procedure EnumerateDxgiAdapters(out AName: string; out ADedicatedTotalMB: UInt64; out ACount: Integer);
const
  IID_IDXGIFactory1: TGUID = '{770AAE78-F26F-4DBA-A829-253C83D1B387}';
var
  Lib: THandle;
  CreateFn: TCreateDxgiFactory1;
  Factory: Pointer;
  Adapter: PDxgiAdapterObj;
  Desc: TDXGIAdapterDesc;
  Idx: DWORD;
  BestMB, MB: UInt64;
begin
  AName := '';
  ADedicatedTotalMB := 0;
  ACount := 0;
  Lib := Windows.LoadLibrary('dxgi.dll');
  if Lib = 0 then Exit;
  try
    @CreateFn := Windows.GetProcAddress(Lib, 'CreateDXGIFactory1');
    if not Assigned(CreateFn) then Exit;
    if CreateFn(IID_IDXGIFactory1, Factory) <> 0 then Exit;
    try
      BestMB := 0;
      Idx := 0;
      while PDxgiFactoryObj(Factory)^.Vtbl^.EnumAdapters(Factory, Idx, Adapter) = 0 do
      begin
        Inc(ACount);
        if PDxgiAdapterObj(Adapter)^.Vtbl^.GetDesc(Adapter, Desc) = 0 then
        begin
          MB := Desc.DedicatedVideoMemory;
          if MB > BestMB then
          begin
            BestMB := MB;
            AName := Trim(WideCharToString(@Desc.Description[0]));
            ADedicatedTotalMB := BestMB;
          end;
        end;
        PDxgiAdapterObj(Adapter)^.Vtbl^.Release(Adapter);
        Inc(Idx);
      end;
    finally
      PDxgiFactoryObj(Factory)^.Vtbl^.Release(Factory);
    end;
  finally
    Windows.FreeLibrary(Lib);
  end;
end;

function ExpandEnvStr(const S: string): string;
var
  WS: WideString;
  Buf: array[0..1023] of WideChar;
begin
  Result := S;
  if Pos('%', S) = 0 then Exit;
  WS := WideString(S);
  FillChar(Buf, SizeOf(Buf), 0);
  if Windows.ExpandEnvironmentStringsW(PWideChar(WS), @Buf[0], 1024) > 0 then
    Result := WideCharToString(@Buf[0]);
end;

// Reads the Explorer StartupApproved toggle for one autostart value.
// Result: 1 = enabled, 0 = disabled, -1 = no record (enabled by default).
function ReadStartupApproved(const ARoot: HKEY; const ASubKey, AValueName: string): Integer;
var
  Reg: TRegistry;
  Buf: array[0..11] of Byte;
begin
  Result := -1;
  Reg := TRegistry.Create(KEY_READ or KEY_WOW64_64KEY);
  try
    Reg.RootKey := ARoot;
    if Reg.OpenKeyReadOnly(ASubKey) and (Reg.GetDataSize(AValueName) >= 1) then
    begin
      FillChar(Buf, SizeOf(Buf), 0);
      Reg.ReadBinaryData(AValueName, Buf, SizeOf(Buf));
      if (Buf[0] and 1) = 0 then
        Result := 1   // 0x02... = enabled
      else
        Result := 0;  // 0x03... = disabled
    end;
  finally
    Reg.Free;
  end;
end;

function GetStartupFolderPath(const ACsidl: Integer): string;
var
  Buf: array[0..1023] of WideChar;
begin
  Result := '';
  FillChar(Buf, SizeOf(Buf), 0);
  if SHGetFolderPathW(0, ACsidl, 0, 0, @Buf[0]) = 0 then
    Result := WideCharToString(@Buf[0]);
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

function GetProcessCommandLine(const AProcessHandle: THandle): string;
var
  RetLen, BufSize: DWORD;
  Status: LongInt;
  Buf: Pointer;
  UStr: PNtUnicodeString;
  WS: WideString;
begin
  Result := '';
  RetLen := 0;
  BufSize := 2048;
  GetMem(Buf, BufSize);
  try
    Status := NtQueryInformationProcess(AProcessHandle, ProcessCommandLineInformation, Buf, BufSize, RetLen);
    if ((Status = STATUS_INFO_LENGTH_MISMATCH) or (Status = STATUS_BUFFER_TOO_SMALL) or (Status = STATUS_BUFFER_OVERFLOW)) and
       (RetLen > BufSize) and (RetLen < 65536) then
    begin
      FreeMem(Buf);
      BufSize := RetLen + 64;
      GetMem(Buf, BufSize);
      Status := NtQueryInformationProcess(AProcessHandle, ProcessCommandLineInformation, Buf, BufSize, RetLen);
    end;
    if Status = 0 then
    begin
      UStr := PNtUnicodeString(Buf);
      if (UStr^.Length > 0) and Assigned(UStr^.Buffer) then
      begin
        SetString(WS, UStr^.Buffer, UStr^.Length div SizeOf(WideChar));
        Result := Trim(string(WS));
      end;
    end;
  finally
    FreeMem(Buf);
  end;
end;

procedure GetExecutableVersionMeta(const AImagePath: string; out ADesc, ACompany, AVersion: string);
var
  Dummy, VerSize: DWORD;
  VerBuf, ValPtr: Pointer;
  ValLen: UINT;
  WPath, SubBlock: WideString;
  Trans: PLangAndCodePage;
  LangHex: string;
begin
  ADesc := '';
  ACompany := '';
  AVersion := '';
  if (AImagePath = '') or (Pos(':', AImagePath) = 0) or (not FileExists(AImagePath)) then
    Exit;

  WPath := WideString(AImagePath);
  Dummy := 0;
  VerSize := GetFileVersionInfoSizeW(PWideChar(WPath), Dummy);
  if (VerSize = 0) or (VerSize > 262144) then Exit;

  GetMem(VerBuf, VerSize);
  try
    if GetFileVersionInfoW(PWideChar(WPath), 0, VerSize, VerBuf) then
    begin
      LangHex := '040904B0';
      ValPtr := nil;
      ValLen := 0;
      SubBlock := '\VarFileInfo\Translation';
      if VerQueryValueW(VerBuf, PWideChar(SubBlock), ValPtr, ValLen) and
         Assigned(ValPtr) and (ValLen >= SizeOf(TLangAndCodePage)) then
      begin
        Trans := PLangAndCodePage(ValPtr);
        LangHex := IntToHex(Trans^.wLanguage, 4) + IntToHex(Trans^.wCodePage, 4);
      end;

      SubBlock := WideString('\StringFileInfo\' + LangHex + '\FileDescription');
      if VerQueryValueW(VerBuf, PWideChar(SubBlock), ValPtr, ValLen) and Assigned(ValPtr) and (ValLen > 0) then
        ADesc := Trim(WideCharToString(PWideChar(ValPtr)));

      SubBlock := WideString('\StringFileInfo\' + LangHex + '\CompanyName');
      if VerQueryValueW(VerBuf, PWideChar(SubBlock), ValPtr, ValLen) and Assigned(ValPtr) and (ValLen > 0) then
        ACompany := Trim(WideCharToString(PWideChar(ValPtr)));

      SubBlock := WideString('\StringFileInfo\' + LangHex + '\FileVersion');
      if VerQueryValueW(VerBuf, PWideChar(SubBlock), ValPtr, ValLen) and Assigned(ValPtr) and (ValLen > 0) then
        AVersion := Trim(WideCharToString(PWideChar(ValPtr)));
    end;
  finally
    FreeMem(VerBuf);
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
          Stat.HandleCount := Cur^.HandleCount;
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

function TMetricsService.CalculateCoreUsages: TSingleDynArray;
{$IFDEF MSWINDOWS}
var
  CoreBuf: array[0..127] of TNtProcessorPerfInfo;
  RetLen: DWORD;
  CoreCount, I: Integer;
  TotalNow, IdleNow, TotalDiff, IdleDiff: Int64;
  Pct: Single;
begin
  Result := nil;
  RetLen := 0;
  if NtQuerySystemInformation(SystemProcessorPerformanceInformation, @CoreBuf[0], SizeOf(CoreBuf), RetLen) = 0 then
  begin
    CoreCount := RetLen div SizeOf(TNtProcessorPerfInfo);
    if (CoreCount <= 0) or (CoreCount > 128) then Exit;
    SetLength(Result, CoreCount);

    if (not FHasPrevCoreSample) or (Length(FPrevCoreIdle) <> CoreCount) then
    begin
      SetLength(FPrevCoreIdle, CoreCount);
      SetLength(FPrevCoreTotal, CoreCount);
      for I := 0 to CoreCount - 1 do
      begin
        FPrevCoreIdle[I] := CoreBuf[I].IdleTime;
        FPrevCoreTotal[I] := CoreBuf[I].KernelTime + CoreBuf[I].UserTime;
        Result[I] := 0.0;
      end;
      FHasPrevCoreSample := True;
    end
    else
    begin
      for I := 0 to CoreCount - 1 do
      begin
        IdleNow := CoreBuf[I].IdleTime;
        TotalNow := CoreBuf[I].KernelTime + CoreBuf[I].UserTime;
        TotalDiff := TotalNow - FPrevCoreTotal[I];
        IdleDiff := IdleNow - FPrevCoreIdle[I];
        Pct := 0.0;
        if TotalDiff > 0 then
        begin
          Pct := ((TotalDiff - IdleDiff) * 100.0) / TotalDiff;
          if Pct < 0.0 then Pct := 0.0;
          if Pct > 100.0 then Pct := 100.0;
        end;
        Result[I] := Pct;
        FPrevCoreIdle[I] := IdleNow;
        FPrevCoreTotal[I] := TotalNow;
      end;
    end;
  end;
end;
{$ELSE}
begin
  SetLength(Result, 4);
  Result[0] := 12.0;
  Result[1] := 8.0;
  Result[2] := 15.0;
  Result[3] := 10.0;
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
    Result.CoreUsages := CalculateCoreUsages;

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
    CollectGpuInfo(Result.Gpu);
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
  Result.Gpu.Name := 'Virtual WARP Adapter';
  Result.Gpu.EngineUsagePercent := 12.0;
  Result.Gpu.DedicatedTotalMB := 512;
  Result.Gpu.DedicatedUsedMB := 128;
  Result.Gpu.SharedUsageMB := 64;
  Result.Gpu.AdapterCount := 1;
  Result.Gpu.Available := True;
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
  NetNow, PrevNet: Int64;
  CurIoTick, IoElapsedMs: UInt64;
  PrioClass, HandlesCnt, GdiCnt, UserCnt: DWORD;
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
          HandlesCnt := 0;
          GdiCnt := 0;
          UserCnt := 0;
          BasePrio := Entry.pcPriClassBase;

          if KernelStats.TryGetValue(ProcId, KStat) then
          begin
            MemMB := KStat.WorkingSetMB;
            ProcTotal := KStat.TotalTime;
            ProcIoBytes := KStat.IoBytes;
            BasePrio := KStat.BasePriority;
            HandlesCnt := KStat.HandleCount;
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
            GdiCnt := GetGuiResources(ProcHandle, GR_GDIOBJECTS);
            UserCnt := GetGuiResources(ProcHandle, GR_USEROBJECTS);

            if not FProcMetaCache.TryGetValue(ProcId, Meta) then
            begin
              Meta.ImagePath := '';
              Meta.UserName := '';
              Meta.Architecture := '64-bit';
              Meta.CommandLine := '';
              Meta.Description := '';
              Meta.CompanyName := '';
              Meta.FileVersion := '';

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
              Meta.CommandLine := GetProcessCommandLine(ProcHandle);
              if Meta.ImagePath <> '' then
                GetExecutableVersionMeta(Meta.ImagePath, Meta.Description, Meta.CompanyName, Meta.FileVersion)
              else
                Meta.ImagePath := ProcName;
              if Meta.CommandLine = '' then
                Meta.CommandLine := Meta.ImagePath;
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
              Meta.CompanyName := 'Microsoft Corporation';
              Meta.FileVersion := 'OS Kernel';
              if ProcId = 4 then
              begin
                Meta.ImagePath := 'ntoskrnl.exe';
                Meta.Description := 'NT Kernel & System';
              end
              else if Pos('.', ProcName) = 0 then
              begin
                Meta.ImagePath := '[System Kernel]';
                Meta.Description := 'Protected System Process';
              end
              else
              begin
                Meta.ImagePath := ProcName;
                Meta.Description := 'Protected Windows Service / Process';
              end;
              Meta.CommandLine := Meta.ImagePath;
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
            Meta.Description);

          Item.ParentId := Entry.th32ParentProcessID;
          Item.ImagePath := Meta.ImagePath;
          Item.UserName := Meta.UserName;
          Item.Architecture := Meta.Architecture;
          Item.CommandLine := Meta.CommandLine;
          Item.CompanyName := Meta.CompanyName;
          Item.FileVersion := Meta.FileVersion;
          Item.HandleCount := HandlesCnt;
          Item.GdiObjects := GdiCnt;
          Item.UserObjects := UserCnt;
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

    // Per-process network rates: cumulative TCP estats byte counters per PID,
    // differentiated against the previous scan over the same elapsed window
    FCurProcNet.Clear;
    CollectTcpEstatsBytes(FCurProcNet);
    for Idx := 0 to Result.Count - 1 do
    begin
      Item := Result[Idx];
      if FHasPrevProcNetSample and (IoElapsedMs > 0) and
         FCurProcNet.TryGetValue(Item.Id, NetNow) and
         FPrevProcNet.TryGetValue(Item.Id, PrevNet) and (NetNow > PrevNet) then
        Item.NetIoKBps := ((NetNow - PrevNet) / 1024.0) * (1000.0 / IoElapsedMs);
    end;
    FPrevProcNet.Free;
    FPrevProcNet := FCurProcNet;
    FCurProcNet := TDictionary<Cardinal, Int64>.Create;
    FHasPrevProcNetSample := True;

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

function TMetricsService.GetProcessAffinityById(const AProcessId: Cardinal; out AProcessMask, ASystemMask: NativeUInt): Boolean;
{$IFDEF MSWINDOWS}
var
  HProc: THandle;
begin
  Result := False;
  AProcessMask := 0;
  ASystemMask := 0;
  if AProcessId <= 4 then Exit;
  HProc := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, AProcessId);
  if HProc <> 0 then
  begin
    try
      Result := GetProcessAffinityMask(HProc, AProcessMask, ASystemMask);
    finally
      CloseHandle(HProc);
    end;
  end;
end;
{$ELSE}
begin
  AProcessMask := $F;
  ASystemMask := $F;
  Result := True;
end;
{$ENDIF}

function TMetricsService.SetProcessAffinityById(const AProcessId: Cardinal; const AProcessMask: NativeUInt): Boolean;
{$IFDEF MSWINDOWS}
var
  HProc: THandle;
begin
  Result := False;
  if (AProcessId <= 4) or (AProcessMask = 0) then Exit;
  HProc := OpenProcess(PROCESS_SET_INFORMATION, False, AProcessId);
  if HProc <> 0 then
  begin
    try
      Result := SetProcessAffinityMask(HProc, AProcessMask);
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

function TMetricsService.RunNewTask(const ACommand: string; const ARunAsAdmin: Boolean): Boolean;
{$IFDEF MSWINDOWS}
var
  ExecInfo: TShellExecuteInfoW;
  CmdTrim, FilePart, ParamPart: string;
  WVerb, WFile, WParams: WideString;
  SpacePos: Integer;
begin
  Result := False;
  CmdTrim := Trim(ACommand);
  if CmdTrim = '' then Exit;

  if (Length(CmdTrim) > 1) and (CmdTrim[1] = '"') then
  begin
    Delete(CmdTrim, 1, 1);
    SpacePos := Pos('"', CmdTrim);
    if SpacePos > 0 then
    begin
      FilePart := Copy(CmdTrim, 1, SpacePos - 1);
      ParamPart := Trim(Copy(CmdTrim, SpacePos + 1, MaxInt));
    end
    else
    begin
      FilePart := CmdTrim;
      ParamPart := '';
    end;
  end
  else if FileExists(CmdTrim) then
  begin
    FilePart := CmdTrim;
    ParamPart := '';
  end
  else
  begin
    SpacePos := Pos(' ', CmdTrim);
    if SpacePos > 0 then
    begin
      FilePart := Copy(CmdTrim, 1, SpacePos - 1);
      ParamPart := Trim(Copy(CmdTrim, SpacePos + 1, MaxInt));
    end
    else
    begin
      FilePart := CmdTrim;
      ParamPart := '';
    end;
  end;

  FillChar(ExecInfo, SizeOf(ExecInfo), 0);
  ExecInfo.cbSize := SizeOf(ExecInfo);
  ExecInfo.nShow := SW_SHOWNORMAL;
  if ARunAsAdmin then
    WVerb := 'runas'
  else
    WVerb := 'open';
  WFile := WideString(FilePart);
  WParams := WideString(ParamPart);
  ExecInfo.lpVerb := PWideChar(WVerb);
  ExecInfo.lpFile := PWideChar(WFile);
  if ParamPart <> '' then
    ExecInfo.lpParameters := PWideChar(WParams);

  Result := ShellExecuteExW(ExecInfo);
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function TMetricsService.RestartProcessById(const AProcessId: Cardinal): Boolean;
{$IFDEF MSWINDOWS}
var
  Meta: TProcessMeta;
  LaunchTarget: string;
  HProc: THandle;
  PathBuf: WideString;
  PathLen: DWORD;
begin
  Result := False;
  if (AProcessId <= 4) or (AProcessId = GetCurrentProcessId) then Exit;

  LaunchTarget := '';
  FLock.Enter;
  try
    if FProcMetaCache.TryGetValue(AProcessId, Meta) then
      LaunchTarget := Meta.ImagePath;
  finally
    FLock.Leave;
  end;

  if (LaunchTarget = '') or (Pos(':', LaunchTarget) = 0) then
  begin
    HProc := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, AProcessId);
    if HProc <> 0 then
    begin
      try
        PathLen := 512;
        SetLength(PathBuf, PathLen);
        if QueryFullProcessImageNameW(HProc, 0, PWideChar(PathBuf), PathLen) then
        begin
          SetLength(PathBuf, PathLen);
          LaunchTarget := string(PathBuf);
        end;
      finally
        CloseHandle(HProc);
      end;
    end;
  end;

  if (LaunchTarget = '') or (not FileExists(LaunchTarget)) then Exit;
  if TerminateProcessById(AProcessId) then
  begin
    Sleep(120);
    Result := RunNewTask('"' + LaunchTarget + '"', False);
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

procedure TMetricsService.EnsureGpuTelemetry;
{$IFDEF MSWINDOWS}
var
  PathEng, PathLocal, PathNonLocal: WideString;
  Name: string;
  TotalMB: UInt64;
  Count: Integer;
begin
  if not FGpuAdapterDone then
  begin
    FGpuAdapterDone := True;
    EnumerateDxgiAdapters(Name, TotalMB, Count);
    FGpuAdapterName := Name;
    FGpuDedicatedTotalMB := TotalMB div (1024 * 1024);
    FGpuAdapterCount := Count;
  end;

  if FGpuPdhState = 0 then
  begin
    FGpuPdhState := 2;
    if PdhOpenQueryW(nil, 0, FGpuPdhQuery) = PDH_ERROR_SUCCESS then
    begin
      PathEng := '\GPU Engine(*)\Utilization Percentage';
      PathLocal := '\GPU Process Memory(*)\Local Usage';
      PathNonLocal := '\GPU Process Memory(*)\Non Local Usage';
      if (PdhAddEnglishCounterW(FGpuPdhQuery, PWideChar(PathEng), 0, FGpuEngCounter) = PDH_ERROR_SUCCESS) and
         (PdhAddEnglishCounterW(FGpuPdhQuery, PWideChar(PathLocal), 0, FGpuLocalCounter) = PDH_ERROR_SUCCESS) and
         (PdhAddEnglishCounterW(FGpuPdhQuery, PWideChar(PathNonLocal), 0, FGpuNonLocalCounter) = PDH_ERROR_SUCCESS) then
        FGpuPdhState := 1
      else
      begin
        PdhCloseQuery(FGpuPdhQuery);
        FGpuPdhQuery := 0;
        FGpuEngCounter := 0;
        FGpuLocalCounter := 0;
        FGpuNonLocalCounter := 0;
      end;
    end;
  end;
end;
{$ELSE}
begin
  FGpuPdhState := 2;
end;
{$ENDIF}

procedure TMetricsService.CloseGpuTelemetry;
{$IFDEF MSWINDOWS}
begin
  if FGpuPdhQuery <> 0 then
    PdhCloseQuery(FGpuPdhQuery);
  FGpuPdhQuery := 0;
  FGpuEngCounter := 0;
  FGpuLocalCounter := 0;
  FGpuNonLocalCounter := 0;
  FGpuPdhState := 0;
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TMetricsService.CollectGpuInfo(var AGpu: TGpuInfo);
{$IFDEF MSWINDOWS}
var
  EngPct, LocalBytes, NonLocalBytes: Double;
begin
  AGpu := TGpuInfo.CreateEmpty;
  EnsureGpuTelemetry;

  AGpu.Name := FGpuAdapterName;
  AGpu.DedicatedTotalMB := FGpuDedicatedTotalMB;
  AGpu.AdapterCount := FGpuAdapterCount;
  if FGpuAdapterCount > 0 then
    AGpu.Available := True;

  if FGpuPdhState = 1 then
  begin
    if PdhCollectQueryData(FGpuPdhQuery) = PDH_ERROR_SUCCESS then
    begin
      AGpu.Available := True;
      EngPct := SumPdhCounterArray(FGpuEngCounter);
      if EngPct < 0.0 then EngPct := 0.0;
      if EngPct > 100.0 then EngPct := 100.0;
      AGpu.EngineUsagePercent := EngPct;

      LocalBytes := SumPdhCounterArray(FGpuLocalCounter);
      NonLocalBytes := SumPdhCounterArray(FGpuNonLocalCounter);
      if LocalBytes >= 0.0 then
        AGpu.DedicatedUsedMB := Trunc(LocalBytes / (1024.0 * 1024.0));
      if NonLocalBytes >= 0.0 then
        AGpu.SharedUsageMB := Trunc(NonLocalBytes / (1024.0 * 1024.0));
    end;
  end;
end;
{$ELSE}
begin
  AGpu := TGpuInfo.CreateEmpty;
  AGpu.Name := 'Virtual WARP Adapter';
  AGpu.EngineUsagePercent := 12.0;
  AGpu.DedicatedTotalMB := 512;
  AGpu.DedicatedUsedMB := 128;
  AGpu.SharedUsageMB := 64;
  AGpu.AdapterCount := 1;
  AGpu.Available := True;
end;
{$ENDIF}

procedure TMetricsService.CollectTcpEstatsBytes(const AMap: TDictionary<Cardinal, Int64>);
{$IFDEF MSWINDOWS}
var
  TcpSize: DWORD;
  TcpBuf: Pointer;
  TcpTable: PMibTcpTableOwnerPid;
  I: Integer;
  Pid: Cardinal;
  RwBuf: Byte;
  RodBuf: array[0..TcpEstatsRodBytes - 1] of Byte;
  Total, Prev: Int64;
begin
  AMap.Clear;
  TcpSize := 0;
  GetExtendedTcpTable(nil, @TcpSize, True, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0);
  if TcpSize = 0 then Exit;
  GetMem(TcpBuf, TcpSize);
  try
    if GetExtendedTcpTable(TcpBuf, @TcpSize, True, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0) = 0 then
    begin
      TcpTable := PMibTcpTableOwnerPid(TcpBuf);
      for I := 0 to Integer(TcpTable^.dwNumEntries) - 1 do
      begin
        Pid := TcpTable^.table[I].dwOwningPid;
        if (Pid = 0) or (Pid = 4) then Continue;

        RwBuf := 0;
        FillChar(RodBuf, SizeOf(RodBuf), 0);
        // The first five DWORDs of the owner-pid row mirror MIB_TCPROW exactly
        if GetPerTcpConnectionEStats(@TcpTable^.table[I], TcpConnectionEstatsData,
             @RwBuf, 1, 0, nil, 0, 0, @RodBuf[0], TcpEstatsRodBytes, 0) = 0 then
        begin
          // Rod: ULONG64 DataBytesOut, DataSegsOut, DataBytesIn, DataSegsIn
          Total := PInt64(@RodBuf[0])^ + PInt64(@RodBuf[16])^;
          if AMap.TryGetValue(Pid, Prev) then
            AMap.AddOrSetValue(Pid, Prev + Total)
          else
            AMap.Add(Pid, Total);
        end;
      end;
    end;
  finally
    FreeMem(TcpBuf);
  end;
end;
{$ELSE}
begin
  AMap.Clear;
end;
{$ENDIF}

function TMetricsService.CollectStartupEntries: TStartupList;
{$IFDEF MSWINDOWS}
var
  Reg: TRegistry;

  procedure EnumRunKey(const ARoot: HKEY; const AKeyPath: string; const AKind: TStartupSourceKind);
  var
    Names: TStringList;
    I: Integer;
    Cmd: string;
    Approved, ApprovedOther: Integer;
    OtherRoot: HKEY;
    Enabled: Boolean;
  begin
    Reg.RootKey := ARoot;
    if not Reg.OpenKeyReadOnly(AKeyPath) then Exit;
    Names := TStringList.Create;
    try
      Reg.GetValueNames(Names);
      for I := 0 to Names.Count - 1 do
      begin
        if not (Reg.GetDataType(Names[I]) in [rdString, rdExpandString]) then Continue;
        Cmd := ExpandEnvStr(Trim(Reg.ReadString(Names[I])));
        if Cmd = '' then Continue;

        if ARoot = HKEY_CURRENT_USER then
          OtherRoot := HKEY_LOCAL_MACHINE
        else
          OtherRoot := HKEY_CURRENT_USER;
        Approved := ReadStartupApproved(ARoot, StartupApprovedRun, Names[I]);
        ApprovedOther := ReadStartupApproved(OtherRoot, StartupApprovedRun, Names[I]);
        // Missing record (-1) means enabled; an explicit disabled flag (0) wins
        Enabled := (Approved <> 0) and (ApprovedOther <> 0);

        Result.Add(TStartupItem.Create(Names[I], Cmd, AKind, Enabled));
      end;
    finally
      Names.Free;
    end;
  end;

  procedure EnumStartupFolder(const ACsidl: Integer; const AKind: TStartupSourceKind);
  var
    Folder: string;
    Sr: TSearchRec;
    Approved: Integer;
    ApprovedRoot: HKEY;
    Enabled: Boolean;
  begin
    Folder := GetStartupFolderPath(ACsidl);
    if Folder = '' then Exit;
    if Folder[Length(Folder)] <> '\' then Folder := Folder + '\';
    if SysUtils.FindFirst(Folder + '*.*', faAnyFile - faDirectory, Sr) = 0 then
    try
      repeat
        if (Sr.Name = '.') or (Sr.Name = '..') then Continue;
        if AKind = suCommonStartupFolder then
          ApprovedRoot := HKEY_LOCAL_MACHINE
        else
          ApprovedRoot := HKEY_CURRENT_USER;
        Approved := ReadStartupApproved(ApprovedRoot, StartupApprovedStartup, Sr.Name);
        Enabled := Approved <> 0;
        Result.Add(TStartupItem.Create(Sr.Name, Folder + Sr.Name, AKind, Enabled));
      until SysUtils.FindNext(Sr) <> 0;
    finally
      SysUtils.FindClose(Sr);
    end;
  end;

begin
  Result := TStartupList.Create(True);
  Reg := TRegistry.Create(KEY_READ or KEY_WOW64_64KEY);
  try
    EnumRunKey(HKEY_CURRENT_USER, RunKeyPath, suHkcuRun);
    EnumRunKey(HKEY_LOCAL_MACHINE, RunKeyPath, suHklmRun);
    EnumRunKey(HKEY_LOCAL_MACHINE, RunKeyPathWow64, suHklmRunWow64);
  finally
    Reg.Free;
  end;
  EnumStartupFolder(CSIDL_STARTUP, suUserStartupFolder);
  EnumStartupFolder(CSIDL_COMMON_STARTUP, suCommonStartupFolder);
end;
{$ELSE}
begin
  Result := TStartupList.Create(True);
  Result.Add(TStartupItem.Create('NovaAgent', 'C:\NovaAgent\novaagent.exe /bg', suHkcuRun, True));
  Result.Add(TStartupItem.Create('OneSync', 'C:\Program Files\OneSync\onesync.exe', suHklmRun, False));
end;
{$ENDIF}

function TMetricsService.SetStartupEntryEnabled(const AItem: TStartupItem; const AEnable: Boolean): Boolean;
{$IFDEF MSWINDOWS}
var
  Reg: TRegistry;
  Root: HKEY;
  SubKey, ValueName: string;
  Buf: array[0..11] of Byte;
begin
  Result := False;
  if (AItem = nil) or (AItem.Name = '') then Exit;

  case AItem.Source of
    suHkcuRun:           begin Root := HKEY_CURRENT_USER;  SubKey := StartupApprovedRun;      ValueName := AItem.Name; end;
    suHklmRun,
    suHklmRunWow64:      begin Root := HKEY_LOCAL_MACHINE; SubKey := StartupApprovedRun;      ValueName := AItem.Name; end;
    suUserStartupFolder: begin Root := HKEY_CURRENT_USER;  SubKey := StartupApprovedStartup; ValueName := AItem.Name; end;
    suCommonStartupFolder: begin Root := HKEY_LOCAL_MACHINE; SubKey := StartupApprovedStartup; ValueName := AItem.Name; end;
  else
    Exit;
  end;

  // Explorer StartupApproved toggle: 12 bytes = flag DWORD + FILETIME stamp.
  // 0x02 = enabled, 0x03 = disabled (low bit marks the disabled state).
  FillChar(Buf, SizeOf(Buf), 0);
  if AEnable then
    Buf[0] := $02
  else
    Buf[0] := $03;

  Reg := TRegistry.Create(KEY_WRITE or KEY_WOW64_64KEY);
  try
    Reg.RootKey := Root;
    if Reg.OpenKey(SubKey, True) then
    begin
      // FPC's TRegistry.WriteBinaryData is a procedure; Delphi's returns
      // Boolean, but calling it as a statement is valid in both compilers
      Reg.WriteBinaryData(ValueName, Buf, SizeOf(Buf));
      Result := True;
      AItem.Enabled := AEnable;
    end;
  finally
    Reg.Free;
  end;
end;
{$ELSE}
begin
  Result := False;
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
