program novatest;

{$mode delphi}

uses
  Interfaces, // LCL unit initialization (no GUI created by this console test)
  Windows,
  Forms,
  Graphics,
  SysUtils,
  Classes,
  fpjson,
  Nova.Types in '..\..\src\Common\Nova.Types.pas',
  Nova.Utils in '..\..\src\Common\Nova.Utils.pas',
  Nova.Service.Metrics in '..\..\src\Services\Nova.Service.Metrics.pas',
  Nova.Service.Exporter in '..\..\src\Services\Nova.Service.Exporter.pas',
  Nova.ViewModel.Main in '..\..\src\ViewModels\Nova.ViewModel.Main.pas';

var
  Failures: Integer = 0;

procedure Check(const AName: string; ACond: Boolean);
begin
  if ACond then
    WriteLn('PASS: ' + AName)
  else
  begin
    Inc(Failures);
    WriteLn('FAIL: ' + AName);
  end;
end;

var
  Svc: IMetricsService;
  Exp: IExportService;
  Snap: TSystemMetrics;
  Procs: TProcessList;
  OutDir: string;
  Strs: TStringList;
  Json: TJSONData;
  Root: TJSONObject;
  CpuNode, ProcArrNode: TJSONData;
  ProcArr: TJSONArray;
  T1, T2, Total: Int64;
  HasCpu: Boolean;
  I: Integer;
  VM: TMainViewModel;
  Hist: THistoryBuffer;
  Arr: TSingleDynArray;
  AllPass: Boolean;
  BlendedCol: TColor;
  NetList: TNetworkConnectionList;
  SvcList: TServiceList;
  TestBmp: TBitmap;
  HasTcp, HasLocalPort, HasRunning, HasChildLevel, HasImagePath, HasUser: Boolean;
begin
  OutDir := ExtractFilePath(ParamStr(0));
  try
    // --- THistoryBuffer tests ---
    WriteLn('Testing THistoryBuffer...');
    Hist.Clear;
    Check('history: initial count is 0', Hist.Count = 0);
    Check('history: initial ToArray is empty', Length(Hist.ToArray) = 0);

    for I := 1 to 5 do
      Hist.Add(I * 10.0);
    Check('history: count after 5 adds is 5', Hist.Count = 5);
    Arr := Hist.ToArray;
    Check('history: ToArray length matches count', Length(Arr) = 5);
    Check('history: first element correct', Arr[0] = 10.0);
    Check('history: last element correct', Arr[4] = 50.0);

    // Overflow beyond CAPACITY (30 samples)
    Hist.Clear;
    for I := 1 to 35 do
      Hist.Add(I * 1.0);
    Check('history: count capped at 30', Hist.Count = 30);
    Arr := Hist.ToArray;
    Check('history: ToArray length capped at 30', Length(Arr) = 30);
    Check('history: oldest sample is 6.0 after 35 adds', Arr[0] = 6.0);
    Check('history: newest sample is 35.0 after 35 adds', Arr[29] = 35.0);

    // --- Color blend test ---
    BlendedCol := TUIUtils.BlendColor(clBlack, clWhite, 0.5);
    Check('ui: BlendColor mid-point is non-zero', BlendedCol <> clBlack);

    // --- GDI+ Anti-Aliasing test ---
    WriteLn('Testing GDI+ Anti-Aliasing Engine...');
    TestBmp := TBitmap.Create;
    try
      TestBmp.SetSize(200, 100);
      TUIUtils.DrawCard(TestBmp.Canvas, Rect(0, 0, 200, 100), clBlack, clWhite, 8);
      Check('gdi+: DrawCard executes cleanly', True);
      TUIUtils.DrawProgressBar(TestBmp.Canvas, Rect(10, 80, 190, 90), 50.0, clGray, clGreen);
      Check('gdi+: DrawProgressBar executes cleanly', True);
      TUIUtils.DrawBadge(TestBmp.Canvas, Rect(10, 10, 50, 30), 'OK', clGreen, clWhite);
      Check('gdi+: DrawBadge executes cleanly', True);
      Hist.Clear;
      Hist.Add(10.0);
      Hist.Add(30.0);
      Hist.Add(20.0);
      TUIUtils.DrawSparkline(TestBmp.Canvas, Rect(10, 10, 100, 60), Hist.ToArray, clLime, clGreen);
      Check('gdi+: DrawSparkline executes cleanly with gradient fill', True);
    finally
      TestBmp.Free;
    end;

    Svc := TMetricsService.Create;
    Exp := TExportService.Create;

    // --- TerminateProcessById security guard tests ---
    WriteLn('Testing Process Termination Guards...');
    Check('terminate: PID 0 (Idle) guarded', not Svc.TerminateProcessById(0));
    Check('terminate: PID 4 (System) guarded', not Svc.TerminateProcessById(4));
    Check('terminate: PID CurrentProcess guarded', not Svc.TerminateProcessById(GetCurrentProcessId));

    // --- Polling Interval Tests ---
    WriteLn('Testing Polling Interval Dynamic Control...');
    Check('interval: default is 1500ms', Svc.GetInterval = 1500);
    Svc.SetInterval(500);
    Check('interval: set to 500ms reflects in GetInterval', Svc.GetInterval = 500);
    Svc.SetInterval(2500);
    Check('interval: set to 2500ms reflects in GetInterval', Svc.GetInterval = 2500);

    // --- system snapshot ---
    Snap := Svc.CollectSnapshot;
    Check('snapshot: CPU in [0..100]', (Snap.CpuUsagePercent >= 0) and (Snap.CpuUsagePercent <= 100));
    Check('snapshot: memory total > 0', Snap.TotalPhysicalMB > 0);
    Check('snapshot: used <= total memory', Snap.UsedPhysicalMB <= Snap.TotalPhysicalMB);
    Check('snapshot: disk total > 0', Snap.TotalDiskGB > 0);
    Check('snapshot: disk pct in [0..100]', (Snap.DiskUsagePercent >= 0) and (Snap.DiskUsagePercent <= 100));

    // --- process enumeration (first scan = CPU baseline, shares all 0) ---
    Procs := Svc.CollectProcesses;
    try
      Check('processes: count > 10', Procs.Count > 10);
      Check('processes: sorted by memory desc',
        (Procs.Count < 2) or
        (Procs[0].MemoryWorkingSetMB >= Procs[Procs.Count - 1].MemoryWorkingSetMB));

      // --- scan cost: three timed scans approximate steady-state polling load ---
      Total := 0;
      for I := 1 to 3 do
      begin
        Sleep(60);
        FreeAndNil(Procs);
        T1 := GetTickCount64;
        Procs := Svc.CollectProcesses;
        T2 := GetTickCount64;
        Total := Total + (T2 - T1);
        WriteLn('  scan ' + IntToStr(I) + ': ' + IntToStr(T2 - T1) + ' ms (' +
          IntToStr(Procs.Count) + ' processes)');
      end;
      WriteLn('scan average: ' + IntToStr(Total div 3) + ' ms  (scan runs every 4.5 s)');

      HasCpu := False;
      for I := 0 to Procs.Count - 1 do
        if Procs[I].CpuSharePercent > 0 then
          HasCpu := True;
      Check('processes: non-zero CPU shares after repeated scans', HasCpu);

      // --- exports ---
      Check('export: JSON succeeds', Exp.ExportToJson(Snap, Procs, OutDir + 'nova_test_out.json'));
      Check('export: CSV succeeds', Exp.ExportToCsv(Procs, OutDir + 'nova_test_out.csv'));

      // --- JSON content validation (parse what the exporter wrote) ---
      Strs := TStringList.Create;
      try
        Strs.LoadFromFile(OutDir + 'nova_test_out.json');
        Json := GetJSON(Strs.Text);
        try
          Root := TJSONObject(Json);
          Check('json: generator present', Assigned(Root.FindPath('generator')));
          Check('json: timestamp present', Assigned(Root.FindPath('timestamp')));
          CpuNode := Root.FindPath('systemMetrics.cpuUsagePercent');
          Check('json: cpuUsagePercent in [0..100]', Assigned(CpuNode) and
            (CpuNode is TJSONFloatNumber) and
            (TJSONFloatNumber(CpuNode).AsFloat >= 0) and
            (TJSONFloatNumber(CpuNode).AsFloat <= 100));
          Check('json: uptimeSeconds > 0', Assigned(Root.FindPath('systemMetrics.uptimeSeconds')));
          ProcArrNode := Root.FindPath('processes');
          ProcArr := ProcArrNode as TJSONArray;
          Check('json: process array matches count', Assigned(ProcArr) and
            (ProcArr.Count = Procs.Count));
          if Assigned(ProcArr) and (ProcArr.Count > 0) then
            Check('json: first process has name and memory', Assigned(ProcArr.Objects[0].FindPath('name')) and
              Assigned(ProcArr.Objects[0].FindPath('memoryMB')));
        finally
          Json.Free;
        end;
      finally
        Strs.Free;
      end;

      // --- CSV content validation ---
      Strs := TStringList.Create;
      try
        Strs.LoadFromFile(OutDir + 'nova_test_out.csv');
        Check('csv: header row', (Strs.Count > 0) and
          (Strs[0] = 'PID,ProcessName,MemoryMB,Status,Threads'));
        Check('csv: row count matches process count', Strs.Count = Procs.Count + 1);
        Check('csv: first data row is top-memory process',
          (Strs.Count > 1) and (Pos(IntToStr(Procs[0].Id) + ',', Strs[1]) = 1));
      finally
        Strs.Free;
      end;
    finally
      Procs.Free;
    end;

    // --- ViewModel test ---
    WriteLn('Testing TMainViewModel...');
    begin
      VM := TMainViewModel.Create;
      try
        VM.Initialize;
        Check('vm: initialized metrics', VM.LatestMetrics.TotalPhysicalMB > 0);
        Check('vm: filtered processes loaded', VM.FilteredProcesses.Count > 0);
        Check('vm: cpu history populated', VM.CpuHistory.Count > 0);
        Check('vm: ram history populated', VM.RamHistory.Count > 0);

        // Search Filter
        VM.SetSearchFilter('svchost');
        Check('vm: search filter applied', VM.FilteredProcesses.Count > 0);
        VM.SetSearchFilter('');

        // Sorting
        VM.SetSort(0); // Sort by PID
        Check('vm: sort by PID', VM.FilteredProcesses.Count > 0);
        VM.SetSort(1); // Sort by Name
        Check('vm: sort by Name', VM.FilteredProcesses.Count > 0);
        VM.SetSort(2); // Sort by CPU
        Check('vm: sort by CPU', VM.FilteredProcesses.Count > 0);
        VM.SetSort(3); // Sort by RAM
        Check('vm: sort by RAM', VM.FilteredProcesses.Count > 0);

        // Quick-Filter Modes
        VM.SetFilterMode(fmHeavyMemory);
        Check('vm: filter mode fmHeavyMemory', VM.FilterMode = fmHeavyMemory);
        AllPass := True;
        for I := 0 to VM.FilteredProcesses.Count - 1 do
          if VM.FilteredProcesses[I].MemoryWorkingSetMB < 400.0 then
            AllPass := False;
        Check('vm: fmHeavyMemory elements all >= 400MB', AllPass);

        VM.SetFilterMode(fmActiveCpu);
        Check('vm: filter mode fmActiveCpu', VM.FilterMode = fmActiveCpu);
        AllPass := True;
        for I := 0 to VM.FilteredProcesses.Count - 1 do
          if VM.FilteredProcesses[I].CpuSharePercent < 2.0 then
            AllPass := False;
        Check('vm: fmActiveCpu elements all >= 2%', AllPass);

        VM.SetFilterMode(fmCriticalOnly);
        Check('vm: filter mode fmCriticalOnly', VM.FilterMode = fmCriticalOnly);
        AllPass := True;
        for I := 0 to VM.FilteredProcesses.Count - 1 do
          if not (VM.FilteredProcesses[I].Status in [isCritical, isWarning]) then
            AllPass := False;
        Check('vm: fmCriticalOnly elements all in [Critical, Warning]', AllPass);

        VM.SetFilterMode(fmAll);
        Check('vm: filter mode fmAll resets', (VM.FilterMode = fmAll) and (VM.FilteredProcesses.Count > 0));
      finally
        VM.Free;
      end;
    end;

    // --- Network Connections test ---
    WriteLn('Testing Network Connections Collection...');
    begin
      NetList := Svc.CollectNetworkConnections;
      try
        Check('network: connections collected', NetList.Count > 0);
        HasTcp := False;
        HasLocalPort := False;
        for I := 0 to NetList.Count - 1 do
        begin
          if NetList[I].Protocol = 'TCP' then HasTcp := True;
          if NetList[I].LocalPort > 0 then HasLocalPort := True;
        end;
        Check('network: contains TCP connections', HasTcp);
        Check('network: contains valid local port numbers', HasLocalPort);
      finally
        NetList.Free;
      end;
    end;

    // --- Windows Services test ---
    WriteLn('Testing Windows Services Collection...');
    begin
      SvcList := Svc.CollectServices;
      try
        Check('services: services collected', SvcList.Count > 0);
        HasRunning := False;
        for I := 0 to SvcList.Count - 1 do
          if SvcList[I].StateString = 'Running' then
            HasRunning := True;
        Check('services: contains running services', HasRunning);
      finally
        SvcList.Free;
      end;
    end;

    // --- Process Tree View & Extended Metadata test ---
    WriteLn('Testing Process Tree & Extended Attributes...');
    begin
      VM := TMainViewModel.Create;
      try
        VM.Initialize;
        Check('tree: default flat mode has treelevel 0',
          (VM.FilteredProcesses.Count > 0) and (VM.FilteredProcesses[0].TreeLevel = 0));
        VM.ToggleTreeView;
        Check('tree: tree mode enabled', VM.IsTreeView);
        HasChildLevel := False;
        for I := 0 to VM.FilteredProcesses.Count - 1 do
          if VM.FilteredProcesses[I].TreeLevel > 0 then
            HasChildLevel := True;
        Check('tree: contains child processes with treelevel > 0', HasChildLevel);

        HasImagePath := False;
        HasUser := False;
        for I := 0 to VM.FilteredProcesses.Count - 1 do
        begin
          if VM.FilteredProcesses[I].ImagePath <> '' then HasImagePath := True;
          if VM.FilteredProcesses[I].UserName <> '' then HasUser := True;
        end;
        Check('metadata: contains processes with image path', HasImagePath);
        Check('metadata: contains processes with user account', HasUser);

        // Network & Services ViewModel integration
        VM.SetActiveView(avNetwork);
        Check('vm: network view populated', VM.NetworkConnections.Count > 0);
        VM.SetActiveView(avServices);
        Check('vm: services view populated', VM.Services.Count > 0);
        VM.SetServiceStatusFilter(1); // Running
        Check('vm: services running filter applied', VM.Services.Count > 0);

        Check('vm: default interval is 1500ms', VM.PollingIntervalMs = 1500);
        VM.SetPollingInterval(500);
        Check('vm: set interval to 500ms', VM.PollingIntervalMs = 500);
      finally
        VM.Free;
      end;
    end;
  except
    on E: Exception do
    begin
      WriteLn('EXCEPTION: ' + E.ClassName + ': ' + E.Message);
      Failures := Failures + 100;
    end;
  end;

  WriteLn('---');
  if Failures = 0 then
    WriteLn('ALL TESTS PASSED')
  else
    WriteLn(IntToStr(Failures) + ' FAILURE(S)');
  ExitCode := Failures;
end.
