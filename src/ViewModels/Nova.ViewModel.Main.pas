unit Nova.ViewModel.Main;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  SysUtils,
  Classes,
  Generics.Collections,
  Nova.Types,
  Nova.Utils,
  Nova.Service.Metrics,
  Nova.Service.Exporter;

type
  /// <summary>
  /// Main ViewModel encapsulating UI state, filtered lists, and commands
  /// </summary>
  TMainViewModel = class
  private
    FMetricsService: IMetricsService;
    FExportService: IExportService;
    FLatestMetrics: TSystemMetrics;
    FProcesses: TProcessList;
    FFilteredProcesses: TProcessList;
    FSearchFilter: string;
    FCurrentTheme: TAppTheme;
    FThemeColors: TThemeColors;

    FOnMetricsUpdated: TMetricsUpdateEvent;
    FOnProcessesUpdated: TProcessListUpdateEvent;
    FOnStatusMessage: TStatusMessageEvent;
    FOnThemeChanged: TThemeChangedEvent;

    // Column sort state: 0 = PID, 1 = Name, 2 = CPU, 3 = Memory, 4 = Status, 5 = Threads
    FSortColumn: Integer;
    FSortAscending: Boolean;

    procedure HandleMetricsUpdate(const AMetrics: TSystemMetrics);
    procedure HandleProcessesUpdate(const AProcesses: TProcessList);
    procedure ApplyFilter;
    function CompareItems(const A, B: TProcessItem): Integer;
    procedure SortFiltered;
    procedure QuickSort(var AItems: array of TProcessItem; ALo, AHi: Integer);
    function GetIsMonitoring: Boolean;
  public
    constructor Create(const AMetricsService: IMetricsService = nil;
      const AExportService: IExportService = nil);
    destructor Destroy; override;

    procedure Initialize;
    procedure ToggleMonitoring;
    procedure ToggleTheme;
    procedure SetSearchFilter(const AFilter: string);
    procedure SetSort(const AColumn: Integer);
    function ExportReport(const AFilePath: string): Boolean;

    property LatestMetrics: TSystemMetrics read FLatestMetrics;
    property FilteredProcesses: TProcessList read FFilteredProcesses;
    property CurrentTheme: TAppTheme read FCurrentTheme;
    property ThemeColors: TThemeColors read FThemeColors;
    property IsMonitoring: Boolean read GetIsMonitoring;
    property SortColumn: Integer read FSortColumn;
    property SortAscending: Boolean read FSortAscending;

    property OnMetricsUpdated: TMetricsUpdateEvent read FOnMetricsUpdated write FOnMetricsUpdated;
    property OnProcessesUpdated: TProcessListUpdateEvent read FOnProcessesUpdated write FOnProcessesUpdated;
    property OnStatusMessage: TStatusMessageEvent read FOnStatusMessage write FOnStatusMessage;
    property OnThemeChanged: TThemeChangedEvent read FOnThemeChanged write FOnThemeChanged;
  end;

implementation

{ TMainViewModel }

constructor TMainViewModel.Create(const AMetricsService: IMetricsService;
  const AExportService: IExportService);
begin
  inherited Create;
  if Assigned(AMetricsService) then
    FMetricsService := AMetricsService
  else
    FMetricsService := TMetricsService.Create;

  if Assigned(AExportService) then
    FExportService := AExportService
  else
    FExportService := TExportService.Create;

  FProcesses := TProcessList.Create(True);
  FFilteredProcesses := TProcessList.Create(False); // Borrowed references
  FSearchFilter := '';
  FCurrentTheme := atDark;
  FThemeColors := TUIUtils.GetThemeColors(FCurrentTheme);
  FLatestMetrics := TSystemMetrics.CreateEmpty;
  FSortColumn := 3; // Memory, descending: largest consumers first on startup
  FSortAscending := False;
end;

destructor TMainViewModel.Destroy;
begin
  if Assigned(FMetricsService) then
    FMetricsService.StopMonitoring;
  FFilteredProcesses.Free;
  FProcesses.Free;
  inherited Destroy;
end;

function TMainViewModel.GetIsMonitoring: Boolean;
begin
  if Assigned(FMetricsService) then
    Result := FMetricsService.IsMonitoring
  else
    Result := False;
end;

procedure TMainViewModel.Initialize;
begin
  FLatestMetrics := FMetricsService.CollectSnapshot;
  FProcesses.Free;
  FProcesses := FMetricsService.CollectProcesses;
  ApplyFilter;

  // Start continuous async background polling at 1500ms intervals
  FMetricsService.StartMonitoring(
    1500,
    HandleMetricsUpdate,
    HandleProcessesUpdate
  );

  if Assigned(FOnStatusMessage) then
    FOnStatusMessage('Telemetry monitor active (async worker polling at 1.5s)', False);
end;

procedure TMainViewModel.ToggleMonitoring;
begin
  if FMetricsService.IsMonitoring then
  begin
    FMetricsService.StopMonitoring;
    if Assigned(FOnStatusMessage) then
      FOnStatusMessage('Monitoring paused by user', False);
  end
  else
  begin
    FMetricsService.StartMonitoring(
      1500,
      HandleMetricsUpdate,
      HandleProcessesUpdate
    );
    if Assigned(FOnStatusMessage) then
      FOnStatusMessage('Monitoring resumed', False);
  end;
end;

procedure TMainViewModel.ToggleTheme;
begin
  if FCurrentTheme = atDark then
    FCurrentTheme := atLight
  else
    FCurrentTheme := atDark;

  FThemeColors := TUIUtils.GetThemeColors(FCurrentTheme);

  if Assigned(FOnThemeChanged) then
    FOnThemeChanged(FCurrentTheme);
end;

procedure TMainViewModel.SetSearchFilter(const AFilter: string);
begin
  FSearchFilter := LowerCase(Trim(AFilter));
  ApplyFilter;
  if Assigned(FOnProcessesUpdated) then
    FOnProcessesUpdated(FFilteredProcesses);
end;

procedure TMainViewModel.SetSort(const AColumn: Integer);
begin
  if AColumn = FSortColumn then
    FSortAscending := not FSortAscending
  else
  begin
    FSortColumn := AColumn;
    // Numeric columns read naturally descending, text columns ascending
    FSortAscending := not (AColumn in [2, 3, 5]);
  end;
  ApplyFilter;
  if Assigned(FOnProcessesUpdated) then
    FOnProcessesUpdated(FFilteredProcesses);
end;

procedure TMainViewModel.ApplyFilter;
var
  I: Integer;
  Item: TProcessItem;
begin
  FFilteredProcesses.Clear;
  for I := 0 to FProcesses.Count - 1 do
  begin
    Item := FProcesses[I];
    if (FSearchFilter = '') or
       (Pos(FSearchFilter, LowerCase(Item.Name)) > 0) or
       (Pos(FSearchFilter, IntToStr(Item.Id)) > 0) then
    begin
      FFilteredProcesses.Add(Item);
    end;
  end;
  SortFiltered;
end;

function TMainViewModel.CompareItems(const A, B: TProcessItem): Integer;
begin
  Result := 0;
  case FSortColumn of
    0: begin
         if A.Id > B.Id then Result := 1
         else if A.Id < B.Id then Result := -1;
       end;
    1: Result := CompareText(A.Name, B.Name);
    2: begin
         if A.CpuSharePercent > B.CpuSharePercent then Result := 1
         else if A.CpuSharePercent < B.CpuSharePercent then Result := -1;
       end;
    3: begin
         if A.MemoryWorkingSetMB > B.MemoryWorkingSetMB then Result := 1
         else if A.MemoryWorkingSetMB < B.MemoryWorkingSetMB then Result := -1;
       end;
    4: Result := Ord(A.Status) - Ord(B.Status);
    5: begin
         if A.ThreadCount > B.ThreadCount then Result := 1
         else if A.ThreadCount < B.ThreadCount then Result := -1;
       end;
  end;
  if Result = 0 then
    Result := CompareText(A.Name, B.Name); // stable tiebreak
end;

procedure TMainViewModel.QuickSort(var AItems: array of TProcessItem; ALo, AHi: Integer);
var
  I, J: Integer;
  Pivot, Tmp: TProcessItem;
begin
  if ALo >= AHi then Exit;
  I := ALo;
  J := AHi;
  Pivot := AItems[(ALo + AHi) div 2];
  repeat
    if FSortAscending then
    begin
      while (I <= AHi) and (CompareItems(AItems[I], Pivot) < 0) do
        Inc(I);
      while (J >= ALo) and (CompareItems(AItems[J], Pivot) > 0) do
        Dec(J);
    end
    else
    begin
      while (I <= AHi) and (CompareItems(AItems[I], Pivot) > 0) do
        Inc(I);
      while (J >= ALo) and (CompareItems(AItems[J], Pivot) < 0) do
        Dec(J);
    end;
    if I <= J then
    begin
      Tmp := AItems[I];
      AItems[I] := AItems[J];
      AItems[J] := Tmp;
      Inc(I);
      Dec(J);
    end;
  until I > J;
  if ALo < J then QuickSort(AItems, ALo, J);
  if I < AHi then QuickSort(AItems, I, AHi);
end;

procedure TMainViewModel.SortFiltered;
var
  Items: array of TProcessItem;
  I: Integer;
begin
  if FSortColumn < 0 then Exit;
  if FFilteredProcesses.Count < 2 then Exit;

  SetLength(Items, FFilteredProcesses.Count);
  for I := 0 to High(Items) do
    Items[I] := FFilteredProcesses[I];
  QuickSort(Items, 0, High(Items));

  FFilteredProcesses.Clear;
  for I := 0 to High(Items) do
    FFilteredProcesses.Add(Items[I]);
end;

procedure TMainViewModel.HandleMetricsUpdate(const AMetrics: TSystemMetrics);
begin
  FLatestMetrics := AMetrics;
  if Assigned(FOnMetricsUpdated) then
    FOnMetricsUpdated(FLatestMetrics);
end;

procedure TMainViewModel.HandleProcessesUpdate(const AProcesses: TProcessList);
var
  OldProcesses: TProcessList;
begin
  OldProcesses := FProcesses;
  FProcesses := AProcesses;
  ApplyFilter;
  OldProcesses.Free;

  if Assigned(FOnProcessesUpdated) then
    FOnProcessesUpdated(FFilteredProcesses);
end;

function TMainViewModel.ExportReport(const AFilePath: string): Boolean;
var
  Ext: string;
begin
  Result := False;
  Ext := LowerCase(ExtractFileExt(AFilePath));

  try
    if Ext = '.csv' then
      Result := FExportService.ExportToCsv(FProcesses, AFilePath)
    else
      Result := FExportService.ExportToJson(FLatestMetrics, FProcesses, AFilePath);

    if Result and Assigned(FOnStatusMessage) then
      FOnStatusMessage(Format('Export completed: %s', [ExtractFileName(AFilePath)]), False);
  except
    on E: Exception do
    begin
      if Assigned(FOnStatusMessage) then
        FOnStatusMessage(Format('Export failed: %s', [E.Message]), True);
    end;
  end;
end;

end.
