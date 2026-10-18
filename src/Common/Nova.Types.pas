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
  TAppView = (avDashboard, avInspector, avNetwork, avServices);

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
  /// System metrics snapshot record
  /// </summary>
  TSystemMetrics = record
    CpuUsagePercent: Single;
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
    FStatus: TItemStatus;
    FThreadCount: Integer;
    FDescription: string;
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
    property Status: TItemStatus read FStatus write FStatus;
    property ThreadCount: Integer read FThreadCount write FThreadCount;
    property Description: string read FDescription write FDescription;
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
  /// Method callback event signatures for decoupled view-model communication
  /// Compatible with both Embarcadero Delphi and Free Pascal
  /// </summary>
  TMetricsUpdateEvent = procedure(const AMetrics: TSystemMetrics) of object;
  TProcessListUpdateEvent = procedure(const AProcesses: TProcessList) of object;
  TNetworkListUpdateEvent = procedure(const AConnections: TNetworkConnectionList) of object;
  TServiceListUpdateEvent = procedure(const AServices: TServiceList) of object;
  TStatusMessageEvent = procedure(const AMessage: string; const AIsError: Boolean) of object;
  TThemeChangedEvent = procedure(const ATheme: TAppTheme) of object;

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
    function ControlWindowsService(const AServiceName: string; const AAction: Integer): Boolean;
    function GetProcessModules(const AProcessId: Cardinal): TStringList;
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
  Result.Timestamp := Now;
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

end.
