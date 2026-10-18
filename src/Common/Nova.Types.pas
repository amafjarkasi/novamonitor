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
  TAppView = (avDashboard, avInspector);

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
    FName: string;
    FMemoryWorkingSetMB: Single;
    FCpuSharePercent: Single;
    FStatus: TItemStatus;
    FThreadCount: Integer;
    FDescription: string;
  public
    constructor Create(const AId: Cardinal; const AName: string;
      const AMemoryMB: Single; const ACpuShare: Single;
      const AStatus: TItemStatus; const AThreads: Integer;
      const ADesc: string = '');

    property Id: Cardinal read FId write FId;
    property Name: string read FName write FName;
    property MemoryWorkingSetMB: Single read FMemoryWorkingSetMB write FMemoryWorkingSetMB;
    property CpuSharePercent: Single read FCpuSharePercent write FCpuSharePercent;
    property Status: TItemStatus read FStatus write FStatus;
    property ThreadCount: Integer read FThreadCount write FThreadCount;
    property Description: string read FDescription write FDescription;
  end;

  TProcessList = TObjectList<TProcessItem>;

  /// <summary>
  /// Method callback event signatures for decoupled view-model communication
  /// Compatible with both Embarcadero Delphi and Free Pascal
  /// </summary>
  TMetricsUpdateEvent = procedure(const AMetrics: TSystemMetrics) of object;
  TProcessListUpdateEvent = procedure(const AProcesses: TProcessList) of object;
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
    function CollectSnapshot: TSystemMetrics;
    function CollectProcesses: TProcessList;
    function TerminateProcessById(const AProcessId: Cardinal): Boolean;
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
  const ADesc: string);
begin
  inherited Create;
  FId := AId;
  FName := AName;
  FMemoryWorkingSetMB := AMemoryMB;
  FCpuSharePercent := ACpuShare;
  FStatus := AStatus;
  FThreadCount := AThreads;
  FDescription := ADesc;
end;

end.
