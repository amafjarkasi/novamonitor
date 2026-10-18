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
    FCpuHistory: THistoryBuffer;
    FRamHistory: THistoryBuffer;
    FFilterMode: TProcessFilterMode;
    FTreeViewEnabled: Boolean;
    FActiveView: TAppView;

    FNetworkConnections: TNetworkConnectionList;
    FFilteredNetwork: TNetworkConnectionList;
    FNetworkSearchFilter: string;

    FServices: TServiceList;
    FFilteredServices: TServiceList;
    FServiceSearchFilter: string;
    FServiceStatusFilter: Integer;

    FOnMetricsUpdated: TMetricsUpdateEvent;
    FOnProcessesUpdated: TProcessListUpdateEvent;
    FOnNetworkUpdated: TNetworkListUpdateEvent;
    FOnServicesUpdated: TServiceListUpdateEvent;
    FOnStatusMessage: TStatusMessageEvent;
    FOnThemeChanged: TThemeChangedEvent;

    // Column sort state: 0 = PID, 1 = Name, 2 = CPU, 3 = Memory, 4 = Status, 5 = Threads
    FSortColumn: Integer;
    FSortAscending: Boolean;

    procedure HandleMetricsUpdate(const AMetrics: TSystemMetrics);
    procedure HandleProcessesUpdate(const AProcesses: TProcessList);
    procedure BuildTree(const ASource, ATarget: TProcessList);
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
    procedure ToggleTreeView;
    procedure SetActiveView(const AView: TAppView);
    procedure SetSearchFilter(const AFilter: string);
    procedure SetFilterMode(const AMode: TProcessFilterMode);
    procedure SetSort(const AColumn: Integer);
    function KillProcess(const AProcessId: Cardinal): Boolean;
    function ExportReport(const AFilePath: string): Boolean;

    procedure RefreshNetworkConnections;
    procedure SetNetworkSearchFilter(const AFilter: string);

    procedure RefreshServices;
    procedure SetServiceSearchFilter(const AFilter: string);
    procedure SetServiceStatusFilter(const AFilter: Integer);

    property LatestMetrics: TSystemMetrics read FLatestMetrics;
    property FilteredProcesses: TProcessList read FFilteredProcesses;
    property NetworkConnections: TNetworkConnectionList read FFilteredNetwork;
    property Services: TServiceList read FFilteredServices;
    property CurrentTheme: TAppTheme read FCurrentTheme;
    property ThemeColors: TThemeColors read FThemeColors;
    property IsMonitoring: Boolean read GetIsMonitoring;
    property IsTreeView: Boolean read FTreeViewEnabled;
    property ActiveView: TAppView read FActiveView;
    property SortColumn: Integer read FSortColumn;
    property SortAscending: Boolean read FSortAscending;
    property FilterMode: TProcessFilterMode read FFilterMode;
    property CpuHistory: THistoryBuffer read FCpuHistory;
    property RamHistory: THistoryBuffer read FRamHistory;

    property OnMetricsUpdated: TMetricsUpdateEvent read FOnMetricsUpdated write FOnMetricsUpdated;
    property OnProcessesUpdated: TProcessListUpdateEvent read FOnProcessesUpdated write FOnProcessesUpdated;
    property OnNetworkUpdated: TNetworkListUpdateEvent read FOnNetworkUpdated write FOnNetworkUpdated;
    property OnServicesUpdated: TServiceListUpdateEvent read FOnServicesUpdated write FOnServicesUpdated;
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
  FNetworkConnections := TNetworkConnectionList.Create(True);
  FFilteredNetwork := TNetworkConnectionList.Create(False);
  FServices := TServiceList.Create(True);
  FFilteredServices := TServiceList.Create(False);
  FSearchFilter := '';
  FNetworkSearchFilter := '';
  FServiceSearchFilter := '';
  FServiceStatusFilter := 0;
  FFilterMode := fmAll;
  FTreeViewEnabled := False;
  FActiveView := avDashboard;
  FCpuHistory.Clear;
  FRamHistory.Clear;
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
  FFilteredServices.Free;
  FServices.Free;
  FFilteredNetwork.Free;
  FNetworkConnections.Free;
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
  FCpuHistory.Add(FLatestMetrics.CpuUsagePercent);
  FRamHistory.Add(FLatestMetrics.MemoryLoadPercent);

  FProcesses.Free;
  FProcesses := FMetricsService.CollectProcesses;
  ApplyFilter;

  RefreshNetworkConnections;
  RefreshServices;

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

procedure TMainViewModel.ToggleTreeView;
begin
  FTreeViewEnabled := not FTreeViewEnabled;
  ApplyFilter;
  if Assigned(FOnProcessesUpdated) then
    FOnProcessesUpdated(FFilteredProcesses);
end;

procedure TMainViewModel.SetActiveView(const AView: TAppView);
begin
  if FActiveView <> AView then
  begin
    FActiveView := AView;
    case FActiveView of
      avNetwork: RefreshNetworkConnections;
      avServices: RefreshServices;
    end;
  end;
end;

procedure TMainViewModel.SetSearchFilter(const AFilter: string);
begin
  FSearchFilter := LowerCase(Trim(AFilter));
  ApplyFilter;
  if Assigned(FOnProcessesUpdated) then
    FOnProcessesUpdated(FFilteredProcesses);
end;

procedure TMainViewModel.SetFilterMode(const AMode: TProcessFilterMode);
begin
  if FFilterMode <> AMode then
  begin
    FFilterMode := AMode;
    ApplyFilter;
    if Assigned(FOnProcessesUpdated) then
      FOnProcessesUpdated(FFilteredProcesses);
  end;
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

procedure TMainViewModel.BuildTree(const ASource, ATarget: TProcessList);
var
  PidMap: TDictionary<Cardinal, TProcessItem>;
  ChildrenMap: TDictionary<Cardinal, TList<TProcessItem>>;
  Roots: TList<TProcessItem>;
  I: Integer;
  Item: TProcessItem;
  ChildList: TList<TProcessItem>;

  procedure AddBranch(ANode: TProcessItem; ALevel: Integer);
  var
    K: Integer;
    Children: TList<TProcessItem>;
  begin
    ANode.TreeLevel := ALevel;
    ATarget.Add(ANode);
    if (ALevel < 32) and ChildrenMap.TryGetValue(ANode.Id, Children) then
    begin
      for K := 0 to Children.Count - 1 do
        AddBranch(Children[K], ALevel + 1);
    end;
  end;

begin
  PidMap := TDictionary<Cardinal, TProcessItem>.Create;
  ChildrenMap := TDictionary<Cardinal, TList<TProcessItem>>.Create;
  Roots := TList<TProcessItem>.Create;
  try
    for I := 0 to ASource.Count - 1 do
    begin
      Item := ASource[I];
      PidMap.AddOrSetValue(Item.Id, Item);
      if not ChildrenMap.TryGetValue(Item.ParentId, ChildList) then
      begin
        ChildList := TList<TProcessItem>.Create;
        ChildrenMap.Add(Item.ParentId, ChildList);
      end;
      ChildList.Add(Item);
    end;

    for I := 0 to ASource.Count - 1 do
    begin
      Item := ASource[I];
      if (Item.ParentId = 0) or (Item.ParentId = Item.Id) or (not PidMap.ContainsKey(Item.ParentId)) then
        Roots.Add(Item);
    end;

    for I := 0 to Roots.Count - 1 do
      AddBranch(Roots[I], 0);
  finally
    for ChildList in ChildrenMap.Values do
      ChildList.Free;
    ChildrenMap.Free;
    Roots.Free;
    PidMap.Free;
  end;
end;

procedure TMainViewModel.ApplyFilter;
var
  I: Integer;
  Item: TProcessItem;
  SourceList: TProcessList;
begin
  FFilteredProcesses.Clear;

  if FTreeViewEnabled then
  begin
    SourceList := TProcessList.Create(False);
    try
      BuildTree(FProcesses, SourceList);
      for I := 0 to SourceList.Count - 1 do
      begin
        Item := SourceList[I];

        // Resource consumer filter mode
        case FFilterMode of
          fmHeavyMemory:
            if Item.MemoryWorkingSetMB < 400.0 then
              Continue;
          fmActiveCpu:
            if Item.CpuSharePercent < 2.0 then
              Continue;
          fmCriticalOnly:
            if not (Item.Status in [isCritical, isWarning]) then
              Continue;
        end;

        // Extended multi-field search filter (PID, Name, User, Path, Arch)
        if (FSearchFilter = '') or
           (Pos(FSearchFilter, LowerCase(Item.Name)) > 0) or
           (Pos(FSearchFilter, IntToStr(Item.Id)) > 0) or
           (Pos(FSearchFilter, LowerCase(Item.UserName)) > 0) or
           (Pos(FSearchFilter, LowerCase(Item.ImagePath)) > 0) or
           (Pos(FSearchFilter, LowerCase(Item.Architecture)) > 0) then
        begin
          FFilteredProcesses.Add(Item);
        end;
      end;
    finally
      SourceList.Free;
    end;
  end
  else
  begin
    for I := 0 to FProcesses.Count - 1 do
    begin
      Item := FProcesses[I];
      Item.TreeLevel := 0;

      // Resource consumer filter mode
      case FFilterMode of
        fmHeavyMemory:
          if Item.MemoryWorkingSetMB < 400.0 then
            Continue;
        fmActiveCpu:
          if Item.CpuSharePercent < 2.0 then
            Continue;
        fmCriticalOnly:
          if not (Item.Status in [isCritical, isWarning]) then
            Continue;
      end;

      // Extended multi-field search filter (PID, Name, User, Path, Arch)
      if (FSearchFilter = '') or
         (Pos(FSearchFilter, LowerCase(Item.Name)) > 0) or
         (Pos(FSearchFilter, IntToStr(Item.Id)) > 0) or
         (Pos(FSearchFilter, LowerCase(Item.UserName)) > 0) or
         (Pos(FSearchFilter, LowerCase(Item.ImagePath)) > 0) or
         (Pos(FSearchFilter, LowerCase(Item.Architecture)) > 0) then
      begin
        FFilteredProcesses.Add(Item);
      end;
    end;
    SortFiltered;
  end;
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
  FCpuHistory.Add(AMetrics.CpuUsagePercent);
  FRamHistory.Add(AMetrics.MemoryLoadPercent);
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

function TMainViewModel.KillProcess(const AProcessId: Cardinal): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Assigned(FMetricsService) then
  begin
    Result := FMetricsService.TerminateProcessById(AProcessId);
    if Result then
    begin
      for I := FProcesses.Count - 1 downto 0 do
        if FProcesses[I].Id = AProcessId then
        begin
          FProcesses.Delete(I);
          Break;
        end;
      ApplyFilter;
      if Assigned(FOnProcessesUpdated) then
        FOnProcessesUpdated(FFilteredProcesses);
      if Assigned(FOnStatusMessage) then
        FOnStatusMessage(Format('Process %d terminated.', [AProcessId]), False);
    end
    else
    begin
      if Assigned(FOnStatusMessage) then
        FOnStatusMessage(Format('Failed to terminate process %d (Access Denied or System Protected).', [AProcessId]), True);
    end;
  end;
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

procedure TMainViewModel.RefreshNetworkConnections;
begin
  FNetworkConnections.Free;
  FNetworkConnections := FMetricsService.CollectNetworkConnections;
  SetNetworkSearchFilter(FNetworkSearchFilter);
end;

procedure TMainViewModel.SetNetworkSearchFilter(const AFilter: string);
var
  I: Integer;
  Item: TNetworkConnectionItem;
  S: string;
begin
  FNetworkSearchFilter := LowerCase(Trim(AFilter));
  FFilteredNetwork.Clear;
  for I := 0 to FNetworkConnections.Count - 1 do
  begin
    Item := FNetworkConnections[I];
    if (FNetworkSearchFilter = '') then
      FFilteredNetwork.Add(Item)
    else
    begin
      S := Format('%d %s %s %s %s %s', [Item.ProcessId, LowerCase(Item.ProcessName),
        LowerCase(Item.Protocol), LowerCase(Item.LocalAddress),
        LowerCase(Item.RemoteAddress), LowerCase(Item.State)]);
      if Pos(FNetworkSearchFilter, S) > 0 then
        FFilteredNetwork.Add(Item);
    end;
  end;
  if Assigned(FOnNetworkUpdated) then
    FOnNetworkUpdated(FFilteredNetwork);
end;

procedure TMainViewModel.RefreshServices;
begin
  FServices.Free;
  FServices := FMetricsService.CollectServices;
  SetServiceSearchFilter(FServiceSearchFilter);
end;

procedure TMainViewModel.SetServiceStatusFilter(const AFilter: Integer);
begin
  FServiceStatusFilter := AFilter;
  SetServiceSearchFilter(FServiceSearchFilter);
end;

procedure TMainViewModel.SetServiceSearchFilter(const AFilter: string);
var
  I: Integer;
  Item: TServiceItem;
  MatchesStatus: Boolean;
  S: string;
begin
  FServiceSearchFilter := LowerCase(Trim(AFilter));
  FFilteredServices.Clear;
  for I := 0 to FServices.Count - 1 do
  begin
    Item := FServices[I];
    case FServiceStatusFilter of
      1: MatchesStatus := SameText(Item.StateString, 'Running');
      2: MatchesStatus := SameText(Item.StateString, 'Stopped');
    else
      MatchesStatus := True;
    end;

    if not MatchesStatus then
      Continue;

    if (FServiceSearchFilter = '') then
      FFilteredServices.Add(Item)
    else
    begin
      S := Format('%s %s %s %d', [LowerCase(Item.ServiceName),
        LowerCase(Item.DisplayName), LowerCase(Item.StateString), Item.ProcessId]);
      if Pos(FServiceSearchFilter, S) > 0 then
        FFilteredServices.Add(Item);
    end;
  end;
  if Assigned(FOnServicesUpdated) then
    FOnServicesUpdated(FFilteredServices);
end;

end.
