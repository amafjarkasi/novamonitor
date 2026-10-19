unit Nova.Types;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  SysUtils,
  Classes,
  Generics.Collections;

type
  /// <summary>
  /// Visual theme mode for the application
  /// </summary>
  TAppTheme = (atDark, atLight);

  /// <summary>
  /// Status of monitored system services or processes
  /// </summary>
  TItemStatus = (isNormal, isWarning, isCritical, isIdle);

  /// <summary>
  /// Active content view in the main form
  /// </summary>
  TAppView = (avDashboard, avInspector, avNetwork, avServices, avStartup);

  /// <summary>
  /// Quick filter modes for process list view
  /// </summary>
  TProcessFilterMode = (fmAll, fmHeavyMemory, fmActiveCpu, fmCriticalOnly);

  TSingleDynArray = array of Single;

  /// <summary>
  /// Fixed-capacity ring buffer for rolling metric sparklines
  /// </summary>
  THistoryBuffer = record
  public const
    CAPACITY = 30;
  private
    FValues: array[0..CAPACITY - 1] of Single;
    FCount: Integer;
    FHead: Integer;
  public
    procedure Clear;
    procedure Add(const AValue: Single);
    function Count: Integer;
    function ToArray: TSingleDynArray;
  end;

  /// <summary>
  /// GPU telemetry snapshot from DXGI adapter enumeration and PDH engine counters
  /// </summary>
  TGpuInfo = record
    Name: string;
    EngineUsagePercent: Single;
    DedicatedTotalMB: UInt64;
    DedicatedUsedMB: UInt64;
    SharedUsageMB: UInt64;
    AdapterCount: Integer;
    Available: Boolean;
    class function CreateEmpty: TGpuInfo; static;
  end;

  /// <summary>
  /// System metrics snapshot record
  /// </summary>
  TSystemMetrics = record
    CpuUsagePercent: Single;
    CoreUsages: TSingleDynArray;
    MemoryLoadPercent: Cardinal;
    TotalPhysicalMB: UInt64;
    AvailablePhysicalMB: UInt64;
    UsedPhysicalMB: UInt64;
    TotalDiskGB: Single;
    FreeDiskGB: Single;
    UsedDiskGB: Single;
    DiskUsagePercent: Single;
    NetDownloadKBps: Single;
    NetUploadKBps: Single;
    UptimeSeconds: UInt64;
    ActiveProcessCount: Integer;
    ThreadCount: Integer;
    Gpu: TGpuInfo;
    Timestamp: TDateTime;
    class function CreateEmpty: TSystemMetrics; static;
  end;

  /// <summary>
  /// Represents a single process or workload item in the telemetry view
  /// </summary>
  TProcessItem = class
  private
    FId: Cardinal;
    FParentId: Cardinal;
    FName: string;
    FMemoryWorkingSetMB: Single;
    FCpuSharePercent: Single;
    FDiskIoKBps: Single;
    FNetIoKBps: Single;
    FStatus: TItemStatus;
    FThreadCount: Integer;
    FHandleCount: Cardinal;
    FGdiObjects: Cardinal;
    FUserObjects: Cardinal;
    FDescription: string;
    FCompanyName: string;
    FFileVersion: string;
    FCommandLine: string;
    FImagePath: string;
    FUserName: string;
    FArchitecture: string;
    FPriorityText: string;
    FTreeLevel: Integer;
  public
    constructor Create(const AId: Cardinal; const AName: string;
      const AMemoryMB: Single; const ACpuShare: Single;
      const AStatus: TItemStatus; const AThreads: Integer;
      const ADesc: string = ''; const AParentId: Cardinal = 0;
      const APath: string = ''; const AUser: string = '';
      const AArch: string = 'x64');

    property Id: Cardinal read FId write FId;
    property ParentId: Cardinal read FParentId write FParentId;
    property Name: string read FName write FName;
    property MemoryWorkingSetMB: Single read FMemoryWorkingSetMB write FMemoryWorkingSetMB;
    property CpuSharePercent: Single read FCpuSharePercent write FCpuSharePercent;
    property DiskIoKBps: Single read FDiskIoKBps write FDiskIoKBps;
    property NetIoKBps: Single read FNetIoKBps write FNetIoKBps;
    property Status: TItemStatus read FStatus write FStatus;
    property ThreadCount: Integer read FThreadCount write FThreadCount;
    property HandleCount: Cardinal read FHandleCount write FHandleCount;
    property GdiObjects: Cardinal read FGdiObjects write FGdiObjects;
    property UserObjects: Cardinal read FUserObjects write FUserObjects;
    property Description: string read FDescription write FDescription;
    property CompanyName: string read FCompanyName write FCompanyName;
    property FileVersion: string read FFileVersion write FFileVersion;
    property CommandLine: string read FCommandLine write FCommandLine;
    property ImagePath: string read FImagePath write FImagePath;
    property UserName: string read FUserName write FUserName;
    property Architecture: string read FArchitecture write FArchitecture;
    property PriorityText: string read FPriorityText write FPriorityText;
    property TreeLevel: Integer read FTreeLevel write FTreeLevel;
  end;

  TProcessList = TObjectList<TProcessItem>;

  /// <summary>
  /// Active network socket connection mapped to process
  /// </summary>
  TNetworkConnectionItem = class
  private
    FProcessId: Cardinal;
    FProcessName: string;
    FProtocol: string;
    FLocalAddress: string;
    FLocalPort: Word;
    FRemoteAddress: string;
    FRemotePort: Word;
    FState: string;
  public
    constructor Create(const APid: Cardinal; const AProcName, AProto,
      ALocalAddr: string; const ALocalPort: Word;
      const ARemoteAddr: string; const ARemotePort: Word;
      const AState: string);

    property ProcessId: Cardinal read FProcessId write FProcessId;
    property ProcessName: string read FProcessName write FProcessName;
    property Protocol: string read FProtocol write FProtocol;
    property LocalAddress: string read FLocalAddress write FLocalAddress;
    property LocalPort: Word read FLocalPort write FLocalPort;
    property RemoteAddress: string read FRemoteAddress write FRemoteAddress;
    property RemotePort: Word read FRemotePort write FRemotePort;
    property State: string read FState write FState;
  end;

  TNetworkConnectionList = TObjectList<TNetworkConnectionItem>;

  /// <summary>
  /// Windows system service representation
  /// </summary>
  TServiceItem = class
  private
    FServiceName: string;
    FDisplayName: string;
    FProcessId: Cardinal;
    FCurrentState: Cardinal;
    FStateString: string;
    FServiceType: Cardinal;
  public
    constructor Create(const AName, ADisplay: string;
      const APid, AState, AType: Cardinal; const AStateStr: string);

    property ServiceName: string read FServiceName write FServiceName;
    property DisplayName: string read FDisplayName write FDisplayName;
    property ProcessId: Cardinal read FProcessId write FProcessId;
    property CurrentState: Cardinal read FCurrentState write FCurrentState;
    property StateString: string read FStateString write FStateString;
    property ServiceType: Cardinal read FServiceType write FServiceType;
  end;

  TServiceList = TObjectList<TServiceItem>;

  /// <summary>
  /// Source location of an autostart entry
  /// </summary>
  TStartupSourceKind = (
    suHkcuRun,          // HKCU\Software\Microsoft\Windows\CurrentVersion\Run
    suHklmRun,          // HKLM\Software\Microsoft\Windows\CurrentVersion\Run
    suHklmRunWow64,     // HKLM\Wow6432Node\...\Run (32-bit view)
    suUserStartupFolder,     // %APPDATA%\...\Start Menu\Programs\Startup
    suCommonStartupFolder);  // %ProgramData%\...\Start Menu\Programs\Startup

  /// <summary>
  /// A startup (autostart) program entry from the registry or a Startup folder
  /// </summary>
  TStartupItem = class
  private
    FName: string;
    FCommand: string;
    FSource: TStartupSourceKind;
    FEnabled: Boolean;
  public
    constructor Create(const AName, ACommand: string; const ASource: TStartupSourceKind;
      const AEnabled: Boolean);

    function SourceToString: string;

    property Name: string read FName write FName;
    property Command: string read FCommand write FCommand;
    property Source: TStartupSourceKind read FSource write FSource;
    property Enabled: Boolean read FEnabled write FEnabled;
  end;

  TStartupList = TObjectList<TStartupItem>;

  /// <summary>
  /// Method callback event signatures for decoupled view-model communication
  /// Compatible with both Embarcadero Delphi and Free Pascal
  /// </summary>
  TMetricsUpdateEvent = procedure(const AMetrics: TSystemMetrics) of object;
  TProcessListUpdateEvent = procedure(const AProcesses: TProcessList) of object;
  TNetworkListUpdateEvent = procedure(const AConnections: TNetworkConnectionList) of object;
  TServiceListUpdateEvent = procedure(const AServices: TServiceList) of object;
  TStartupListUpdateEvent = procedure(const AItems: TStartupList) of object;
  TStatusMessageEvent = procedure(const AMessage: string; const AIsError: Boolean) of object;
  TThemeChangedEvent = procedure(const ATheme: TAppTheme) of object;

  /// <summary>
  /// Resource threshold alert notification (severity: 0 = info/recovery, 1 = warning, 2 = danger)
  /// </summary>
  TAlertEvent = procedure(const ATitle, AMessage: string; const ASeverity: Integer) of object;

  /// <summary>
  /// Rolling evaluation state for one alert channel (CPU / RAM / disk)
  /// </summary>
  TAlertChannelState = record
    Streak: Integer;
    LastRaiseMs: UInt64;
    Active: Boolean;
  end;

  /// <summary>
  /// Pure threshold-alert rule engine: sustained-breach detection with cooldown
  /// and recovery notifications. Kept free of UI and timers so the rule logic
  /// is directly unit-testable.
  /// </summary>
  TAlertRules = class
  public const
    CPU_THRESHOLD_PERCENT = 85.0;
    RAM_THRESHOLD_PERCENT = 90.0;
    DISK_THRESHOLD_PERCENT = 95.0;
    SUSTAIN_SAMPLES = 4;
    COOLDOWN_MS = 300000;      // re-alert at most every 5 minutes
    RECOVERY_HYSTERESIS = 5.0; // must drop this far below the threshold to recover
    KIND_CPU = 0;
    KIND_RAM = 1;
    KIND_DISK = 2;
  public
    /// <summary>
    /// Advances the state with one metrics sample; returns True (and fills the
    /// notification fields) when an alert or recovery should be raised now.
    /// Priority: sustained danger breaches first, then pending recoveries.
    /// </summary>
    class function Evaluate(var ACpu, ARam, ADisk: TAlertChannelState;
      const AMetrics: TSystemMetrics; const ANowMs: UInt64;
      out AKind: Integer; out ATitle, AMessage: string;
      out ASeverity: Integer): Boolean; static;
    class function RamUsagePercent(const AMetrics: TSystemMetrics): Single; static;
  end;

  /// <summary>
  /// Service contract for gathering system metrics asynchronously
  /// </summary>
  IMetricsService = interface
    ['{6E7E37C4-13B2-4A99-97FA-B955CA78E101}']
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

  /// <summary>
  /// Service contract for exporting system telemetry data
  /// </summary>
  IExportService = interface
    ['{8A3B22C9-43D1-4688-9102-ED4C86134D52}']
    function ExportToJson(const AMetrics: TSystemMetrics;
      const AProcesses: TProcessList; const AFilePath: string): Boolean;
    function ExportToCsv(const AProcesses: TProcessList;
      const AFilePath: string): Boolean;
  end;

implementation

{ THistoryBuffer }

procedure THistoryBuffer.Clear;
begin
  FCount := 0;
  FHead := 0;
  FillChar(FValues, SizeOf(FValues), 0);
end;

procedure THistoryBuffer.Add(const AValue: Single);
begin
  FValues[FHead] := AValue;
  FHead := (FHead + 1) mod CAPACITY;
  if FCount < CAPACITY then
    Inc(FCount);
end;

function THistoryBuffer.Count: Integer;
begin
  Result := FCount;
end;

function THistoryBuffer.ToArray: TSingleDynArray;
var
  I, StartIdx: Integer;
begin
  SetLength(Result, FCount);
  if FCount < CAPACITY then
    StartIdx := 0
  else
    StartIdx := FHead;

  for I := 0 to FCount - 1 do
    Result[I] := FValues[(StartIdx + I) mod CAPACITY];
end;

{ TSystemMetrics }

class function TSystemMetrics.CreateEmpty: TSystemMetrics;
begin
  Result := Default(TSystemMetrics);
  Result.Gpu := TGpuInfo.CreateEmpty;
  Result.Timestamp := Now;
end;

{ TGpuInfo }

class function TGpuInfo.CreateEmpty: TGpuInfo;
begin
  Result := Default(TGpuInfo);
  Result.Name := 'No GPU telemetry';
  Result.EngineUsagePercent := 0.0;
  Result.DedicatedTotalMB := 0;
  Result.DedicatedUsedMB := 0;
  Result.SharedUsageMB := 0;
  Result.AdapterCount := 0;
  Result.Available := False;
end;

{ TProcessItem }

constructor TProcessItem.Create(const AId: Cardinal; const AName: string;
  const AMemoryMB: Single; const ACpuShare: Single;
  const AStatus: TItemStatus; const AThreads: Integer;
  const ADesc: string; const AParentId: Cardinal;
  const APath: string; const AUser: string;
  const AArch: string);
begin
  inherited Create;
  FId := AId;
  FName := AName;
  FMemoryWorkingSetMB := AMemoryMB;
  FCpuSharePercent := ACpuShare;
  FDiskIoKBps := 0.0;
  FNetIoKBps := 0.0;
  FStatus := AStatus;
  FThreadCount := AThreads;
  FDescription := ADesc;
  FParentId := AParentId;
  FImagePath := APath;
  FUserName := AUser;
  FArchitecture := AArch;
  FPriorityText := 'Normal';
  FTreeLevel := 0;
end;

{ TNetworkConnectionItem }

constructor TNetworkConnectionItem.Create(const APid: Cardinal;
  const AProcName, AProto, ALocalAddr: string; const ALocalPort: Word;
  const ARemoteAddr: string; const ARemotePort: Word;
  const AState: string);
begin
  inherited Create;
  FProcessId := APid;
  FProcessName := AProcName;
  FProtocol := AProto;
  FLocalAddress := ALocalAddr;
  FLocalPort := ALocalPort;
  FRemoteAddress := ARemoteAddr;
  FRemotePort := ARemotePort;
  FState := AState;
end;

{ TServiceItem }

constructor TServiceItem.Create(const AName, ADisplay: string;
  const APid, AState, AType: Cardinal; const AStateStr: string);
begin
  inherited Create;
  FServiceName := AName;
  FDisplayName := ADisplay;
  FProcessId := APid;
  FCurrentState := AState;
  FServiceType := AType;
  FStateString := AStateStr;
end;

{ TStartupItem }

constructor TStartupItem.Create(const AName, ACommand: string;
  const ASource: TStartupSourceKind; const AEnabled: Boolean);
begin
  inherited Create;
  FName := AName;
  FCommand := ACommand;
  FSource := ASource;
  FEnabled := AEnabled;
end;

function TStartupItem.SourceToString: string;
begin
  case FSource of
    suHkcuRun:          Result := 'HKCU Run';
    suHklmRun:          Result := 'HKLM Run';
    suHklmRunWow64:     Result := 'HKLM Run (32-bit)';
    suUserStartupFolder:    Result := 'Startup (User)';
    suCommonStartupFolder:  Result := 'Startup (All Users)';
  else
    Result := 'Unknown';
  end;
end;

{ TAlertRules }

class function TAlertRules.RamUsagePercent(const AMetrics: TSystemMetrics): Single;
begin
  if AMetrics.TotalPhysicalMB > 0 then
    Result := (AMetrics.UsedPhysicalMB * 100.0) / AMetrics.TotalPhysicalMB
  else
    Result := Single(AMetrics.MemoryLoadPercent);
end;

class function TAlertRules.Evaluate(var ACpu, ARam, ADisk: TAlertChannelState;
  const AMetrics: TSystemMetrics; const ANowMs: UInt64;
  out AKind: Integer; out ATitle, AMessage: string;
  out ASeverity: Integer): Boolean;

  function Sustained(var AState: TAlertChannelState; const ABreached: Boolean): Boolean;
  begin
    if ABreached then
    begin
      if AState.Streak < High(Integer) then
        Inc(AState.Streak);
      Result := AState.Streak >= SUSTAIN_SAMPLES;
    end
    else
    begin
      AState.Streak := 0;
      Result := False;
    end;
  end;

  function CooldownOk(const AState: TAlertChannelState): Boolean;
  begin
    if AState.LastRaiseMs = 0 then
      Result := True
    else if ANowMs >= AState.LastRaiseMs then
      Result := (ANowMs - AState.LastRaiseMs) >= COOLDOWN_MS
    else
      Result := True; // tick counter wrapped: treat as fully elapsed
  end;

  procedure RaiseAlert(var AState: TAlertChannelState; const AKindVal: Integer;
    const AWhat, ANowTxt: string);
  begin
    AState.LastRaiseMs := ANowMs;
    AState.Active := True;
    AKind := AKindVal;
    ASeverity := 2;
    ATitle := 'Resource Alert: ' + AWhat;
    AMessage := ANowTxt;
    Result := True;
  end;

begin
  Result := False;
  AKind := -1;
  ASeverity := 0;
  ATitle := '';
  AMessage := '';

  // 1. Sustained danger breaches (CPU > RAM > disk priority)
  if Sustained(ACpu, AMetrics.CpuUsagePercent >= CPU_THRESHOLD_PERCENT) and
     CooldownOk(ACpu) then
  begin
    RaiseAlert(ACpu, KIND_CPU, 'CPU',
      Format('CPU utilization has been at %.0f%% or higher for %d consecutive samples.',
        [AMetrics.CpuUsagePercent, SUSTAIN_SAMPLES]));
    Exit;
  end;

  if Sustained(ARam, RamUsagePercent(AMetrics) >= RAM_THRESHOLD_PERCENT) and
     CooldownOk(ARam) then
  begin
    RaiseAlert(ARam, KIND_RAM, 'Memory',
      Format('Memory load is at %.0f%% (%s used).', [RamUsagePercent(AMetrics),
        Format('%.1f GB', [AMetrics.UsedPhysicalMB / 1024.0])]));
    Exit;
  end;

  if Sustained(ADisk, AMetrics.DiskUsagePercent >= DISK_THRESHOLD_PERCENT) and
     CooldownOk(ADisk) then
  begin
    RaiseAlert(ADisk, KIND_DISK, 'Storage',
      Format('System disk is %.1f%% full (%.1f GB free).', [AMetrics.DiskUsagePercent,
        AMetrics.FreeDiskGB]));
    Exit;
  end;

  // 2. Recoveries: an active alert whose metric dropped clear of the threshold
  if ACpu.Active and (AMetrics.CpuUsagePercent <= CPU_THRESHOLD_PERCENT - RECOVERY_HYSTERESIS) then
  begin
    ACpu.Active := False;
    AKind := KIND_CPU;
    ASeverity := 0;
    ATitle := 'Recovered: CPU';
    AMessage := Format('CPU utilization is back to %.0f%%.', [AMetrics.CpuUsagePercent]);
    Result := True;
  end
  else if ARam.Active and (RamUsagePercent(AMetrics) <= RAM_THRESHOLD_PERCENT - RECOVERY_HYSTERESIS) then
  begin
    ARam.Active := False;
    AKind := KIND_RAM;
    ASeverity := 0;
    ATitle := 'Recovered: Memory';
    AMessage := Format('Memory load is back to %.0f%%.', [RamUsagePercent(AMetrics)]);
    Result := True;
  end
  else if ADisk.Active and (AMetrics.DiskUsagePercent <= DISK_THRESHOLD_PERCENT - RECOVERY_HYSTERESIS) then
  begin
    ADisk.Active := False;
    AKind := KIND_DISK;
    ASeverity := 0;
    ATitle := 'Recovered: Storage';
    AMessage := Format('System disk usage is back to %.1f%%.', [AMetrics.DiskUsagePercent]);
    Result := True;
  end;
end;

end.
