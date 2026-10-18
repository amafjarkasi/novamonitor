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
  end;

  /// <summary>
  /// Thread-safe Windows System Metrics gathering service
  /// </summary>
  TMetricsService = class(TInterfacedObject, IMetricsService)
  private
    FWorker: TMetricsWorkerThread;
    FLock: TCriticalSection;
    FPrevIdleTime: Int64;
    FPrevKernelTime: Int64;
    FPrevUserTime: Int64;
    FHasPrevCpuTime: Boolean;
    // Per-PID CPU sampling: kernel+user time totals from the previous scan
    FPrevProcTimes: TDictionary<Cardinal, Int64>;
    FCurProcTimes: TDictionary<Cardinal, Int64>;
    FHasPrevProcSample: Boolean;
    FPrevProcTotalTime: Int64;

    function CalculateCpuUsage: Single;
  public
    constructor Create;
    destructor Destroy; override;

    procedure StartMonitoring(const AIntervalMs: Cardinal;
      const OnUpdate: TMetricsUpdateEvent;
      const OnProcessUpdate: TProcessListUpdateEvent);
    procedure StopMonitoring;
    function IsMonitoring: Boolean;
    function CollectSnapshot: TSystemMetrics;
    function CollectProcesses: TProcessList;
    function TerminateProcessById(const AProcessId: Cardinal): Boolean;
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
  Counter: Integer;
begin
  Counter := 0;
  while not Terminated do
  begin
    try
      FCurMetrics := FService.CollectSnapshot;
      // The snapshot zeroes the count on every tick; keep the last real value
      // so the UI does not flicker to "0 active processes" between process scans
      FCurMetrics.ActiveProcessCount := FLastProcessCount;

      if (Counter mod 3 = 0) and Assigned(FOnProcessUpdate) then
      begin
        FCurProcesses := FService.CollectProcesses;
        FLastProcessCount := FCurProcesses.Count;
        FCurMetrics.ActiveProcessCount := FLastProcessCount;
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
  FPrevProcTimes := TDictionary<Cardinal, Int64>.Create;
  FCurProcTimes := TDictionary<Cardinal, Int64>.Create;
  FHasPrevProcSample := False;
  FPrevProcTotalTime := 0;
end;

destructor TMetricsService.Destroy;
begin
  StopMonitoring;
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

const
  // Local declarations shadow Windows-unit constants where present;
  // older FPC/Delphi Windows units may lack them
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
  TH32CS_SNAPPROCESS = $2;

function GlobalMemoryStatusEx(var lpBuffer: TWinMemoryStatusEx): BOOL; stdcall; external 'kernel32.dll';
function GetSystemTimes(lpIdleTime, lpKernelTime, lpUserTime: PFileTime): BOOL; stdcall; external 'kernel32.dll';
function GetProcessMemoryInfo(hProcess: THandle; ppsmemCounters: PWinProcessMemoryCounters; cb: DWORD): BOOL; stdcall; external 'psapi.dll';
function CreateToolhelp32Snapshot(dwFlags: DWORD; th32ProcessID: DWORD): THandle; stdcall; external 'kernel32.dll';
function Process32First(hSnapshot: THandle; var lpEntry: TWinProcessEntry32): BOOL; stdcall; external 'kernel32.dll';
function Process32Next(hSnapshot: THandle; var lpEntry: TWinProcessEntry32): BOOL; stdcall; external 'kernel32.dll';

function FileTimeToLargeInt(const FT: TFileTime): Int64;
begin
  Result := (Int64(FT.dwHighDateTime) shl 32) or FT.dwLowDateTime;
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
  SysIdle, SysKernel, SysUser: TFileTime;
  CreationT, ExitT, ProcKernelT, ProcUserT: TFileTime;
  Item: TProcessItem;
  MemMB: Single;
  Status: TItemStatus;
  Idx: Integer;
  ProcId: Cardinal;
  ProcTotal, TotalNow, TotalDelta, PrevProc: Int64;
  CpuPct: Single;
begin
  Result := TProcessList.Create(True);

  FLock.Enter;
  try
    FCurProcTimes.Clear;
    GetSystemTimes(@SysIdle, @SysKernel, @SysUser);
    TotalNow := FileTimeToLargeInt(SysKernel) + FileTimeToLargeInt(SysUser);

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
        MemMB := 0.0;
        ProcTotal := 0;
        ProcHandle := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, ProcId);
        if ProcHandle <> 0 then
        try
          MemCounters.cb := SizeOf(MemCounters);
          if GetProcessMemoryInfo(ProcHandle, @MemCounters, MemCounters.cb) then
            MemMB := MemCounters.WorkingSetSize / (1024.0 * 1024.0);
          // Kernel+user CPU time totals; sampled against the previous scan
          if GetProcessTimes(ProcHandle, CreationT, ExitT, ProcKernelT, ProcUserT) then
            ProcTotal := FileTimeToLargeInt(ProcKernelT) + FileTimeToLargeInt(ProcUserT);
        finally
          CloseHandle(ProcHandle);
        end;
        FCurProcTimes.AddOrSetValue(ProcId, ProcTotal);

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
          StrPas(Entry.szExeFile),
          MemMB,
          CpuPct,
          Status,
          Entry.cntThreads,
          '');

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

    // This scan becomes the baseline for the next one; free the replaced
    // dictionary so each cycle does not orphan one TDictionary instance
    FPrevProcTimes.Free;
    FPrevProcTimes := FCurProcTimes;
    FCurProcTimes := TDictionary<Cardinal, Int64>.Create;
    FHasPrevProcSample := True;
    FPrevProcTotalTime := TotalNow;
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

end.
