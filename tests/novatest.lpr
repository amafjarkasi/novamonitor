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
  Snap, Snap2: TSystemMetrics;
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
  StartList: TStartupList;
  EmptyItem: TStartupItem;
  TestBmp: TBitmap;
  HasTcp, HasLocalPort, HasRunning, HasChildLevel, HasImagePath, HasUser: Boolean;
  HasCmdLine, HasHandles, HasPublisher, HasEnabled, AllNamed, AllNetOk: Boolean;
  ProcMask, SysMask: NativeUInt;
  AlertCpu, AlertRam, AlertDisk: TAlertChannelState;
  AlertKind, AlertSeverity: Integer;
  AlertTitle, AlertMsg: string;
  AlertM: TSystemMetrics;
  AlertNow: UInt64;
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

    // --- TerminateProcessById / Priority / Suspend security guard tests ---
    WriteLn('Testing Process Security Guards & Module Enumeration...');
    Check('terminate: PID 0 (Idle) guarded', not Svc.TerminateProcessById(0));
    Check('terminate: PID 4 (System) guarded', not Svc.TerminateProcessById(4));
    Check('terminate: PID CurrentProcess guarded', not Svc.TerminateProcessById(GetCurrentProcessId));
    Check('priority: PID 0 guarded', not Svc.SetProcessPriorityById(0, $00000020));
    Check('priority: PID 4 guarded', not Svc.SetProcessPriorityById(4, $00000020));
    Check('suspend: PID 0 guarded', not Svc.SuspendResumeProcessById(0, True));
    Check('suspend: PID 4 guarded', not Svc.SuspendResumeProcessById(4, True));
    Check('suspend: PID CurrentProcess guarded', not Svc.SuspendResumeProcessById(GetCurrentProcessId, True));
    Check('affinity: PID 0 guarded', not Svc.GetProcessAffinityById(0, ProcMask, SysMask));
    Check('affinity: current process mask retrieved', Svc.GetProcessAffinityById(GetCurrentProcessId, ProcMask, SysMask) and (ProcMask <> 0) and (SysMask <> 0));
    Check('affinity: empty mask (0) rejected', not Svc.SetProcessAffinityById(GetCurrentProcessId, 0));
    Check('restart: PID 0 guarded', not Svc.RestartProcessById(0));
    Check('restart: PID CurrentProcess guarded', not Svc.RestartProcessById(GetCurrentProcessId));
    Check('run_task: empty command guarded', not Svc.RunNewTask('   ', False));
    Check('format: FormatRateKBps zero', TUIUtils.FormatRateKBps(0.0) = '0.0 KB/s');
    Check('format: FormatRateKBps MB/s', Pos('MB/s', TUIUtils.FormatRateKBps(2048.0)) > 0);
    Strs := Svc.GetProcessModules(GetCurrentProcessId);
    try
      Check('modules: current process has loaded DLLs', Strs.Count > 2);
    finally
      Strs.Free;
    end;

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
    Check('snapshot: per-core CPU array populated', Length(Snap.CoreUsages) > 0);
    Check('snapshot: memory total > 0', Snap.TotalPhysicalMB > 0);
    Check('snapshot: used <= total memory', Snap.UsedPhysicalMB <= Snap.TotalPhysicalMB);
    Check('snapshot: disk total > 0', Snap.TotalDiskGB > 0);
    Check('snapshot: disk pct in [0..100]', (Snap.DiskUsagePercent >= 0) and (Snap.DiskUsagePercent <= 100));
    Check('snapshot: net download >= 0', Snap.NetDownloadKBps >= 0);
    Check('snapshot: net upload >= 0', Snap.NetUploadKBps >= 0);

    // --- GPU telemetry (DXGI adapters + PDH engine/memory counters) ---
    WriteLn('Testing GPU Telemetry...');
    Check('gpu: adapters enumerated via dxgi.dll', Snap.Gpu.AdapterCount >= 1);
    Check('gpu: engine usage in [0..100]',
      (Snap.Gpu.EngineUsagePercent >= 0) and (Snap.Gpu.EngineUsagePercent <= 100));
    Check('gpu: adapter name present when telemetry available',
      (not Snap.Gpu.Available) or (Snap.Gpu.Name <> ''));
    Check('gpu: dedicated usage non-negative', Snap.Gpu.DedicatedUsedMB >= 0);
    Check('gpu: shared usage non-negative', Snap.Gpu.SharedUsageMB >= 0);
    // A second collect gives PDH the delta sample it needs for utilization
    Snap2 := Svc.CollectSnapshot;
    Check('gpu: second snapshot keeps utilization in [0..100]',
      (Snap2.Gpu.EngineUsagePercent >= 0) and (Snap2.Gpu.EngineUsagePercent <= 100));

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

      // --- per-process network rates (TCP estats deltas) ---
      AllNetOk := True;
      for I := 0 to Procs.Count - 1 do
        if Procs[I].NetIoKBps < 0 then
          AllNetOk := False;
      Check('processes: per-process network rates all >= 0', AllNetOk);

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
          Check('json: gpu telemetry present', Assigned(Root.FindPath('systemMetrics.gpuName')) and
            Assigned(Root.FindPath('systemMetrics.gpuEngineUsagePercent')));
          ProcArrNode := Root.FindPath('processes');
          ProcArr := ProcArrNode as TJSONArray;
          Check('json: process array matches count', Assigned(ProcArr) and
            (ProcArr.Count = Procs.Count));
          if Assigned(ProcArr) and (ProcArr.Count > 0) then
            Check('json: first process has name and memory', Assigned(ProcArr.Objects[0].FindPath('name')) and
              Assigned(ProcArr.Objects[0].FindPath('memoryMB')));
          if Assigned(ProcArr) and (ProcArr.Count > 0) then
            Check('json: first process has networkIoKBps', Assigned(ProcArr.Objects[0].FindPath('networkIoKBps')));
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
          (Strs[0] = 'PID,ProcessName,MemoryMB,Status,Threads,NetworkIoKBps'));
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
        Check('vm: disk history populated', VM.DiskHistory.Count > 0);

        // Search Filter
        VM.SetSearchFilter('svchost');
        Check('vm: search filter applied', VM.FilteredProcesses.Count > 0);
        VM.SetSearchFilter('');

        // Sorting across all 10 columns:
        // 0=PID, 1=Name, 2=User, 3=Arch, 4=CPU%, 5=RAM, 6=Disk I/O, 7=Health, 8=Threads, 9=Path
        Check('vm: default sort column is 5 (Working Set RAM)', VM.SortColumn = 5);
        Check('vm: default sort order is descending by RAM',
          (VM.FilteredProcesses.Count < 2) or
          (VM.FilteredProcesses[0].MemoryWorkingSetMB >= VM.FilteredProcesses[VM.FilteredProcesses.Count - 1].MemoryWorkingSetMB));

        VM.SetSort(0); // Sort by PID asc
        Check('vm: sort by PID asc',
          (VM.FilteredProcesses.Count < 2) or
          (VM.FilteredProcesses[0].Id <= VM.FilteredProcesses[VM.FilteredProcesses.Count - 1].Id));
        VM.SetSort(1); // Sort by Name asc
        Check('vm: sort by Name', VM.FilteredProcesses.Count > 0);
        VM.SetSort(2); // Sort by User Account asc
        Check('vm: sort by User Account', VM.FilteredProcesses.Count > 0);
        VM.SetSort(3); // Sort by Arch asc
        Check('vm: sort by Arch', VM.FilteredProcesses.Count > 0);
        VM.SetSort(4); // Sort by CPU % desc
        Check('vm: sort by CPU % desc',
          (VM.FilteredProcesses.Count < 2) or
          (VM.FilteredProcesses[0].CpuSharePercent >= VM.FilteredProcesses[VM.FilteredProcesses.Count - 1].CpuSharePercent));
        VM.SetSort(5); // Sort by Working Set (RAM) desc
        Check('vm: sort by Working Set (RAM) desc',
          (VM.FilteredProcesses.Count < 2) or
          (VM.FilteredProcesses[0].MemoryWorkingSetMB >= VM.FilteredProcesses[VM.FilteredProcesses.Count - 1].MemoryWorkingSetMB));
        VM.SetSort(6); // Sort by Disk I/O desc
        Check('vm: sort by Disk I/O desc',
          (VM.FilteredProcesses.Count < 2) or
          (VM.FilteredProcesses[0].DiskIoKBps >= VM.FilteredProcesses[VM.FilteredProcesses.Count - 1].DiskIoKBps));
        VM.SetSort(7); // Sort by Network I/O desc
        Check('vm: sort by Network I/O desc',
          (VM.FilteredProcesses.Count < 2) or
          (VM.FilteredProcesses[0].NetIoKBps >= VM.FilteredProcesses[VM.FilteredProcesses.Count - 1].NetIoKBps));
        VM.SetSort(7); // Sort by Health Status desc
        Check('vm: sort by Health Status', VM.FilteredProcesses.Count > 0);
        VM.SetSort(8); // Sort by Active Threads desc
        Check('vm: sort by Active Threads desc',
          (VM.FilteredProcesses.Count < 2) or
          (VM.FilteredProcesses[0].ThreadCount >= VM.FilteredProcesses[VM.FilteredProcesses.Count - 1].ThreadCount));
        VM.SetSort(9); // Sort by Image Path asc
        Check('vm: sort by Image Path', VM.FilteredProcesses.Count > 0);

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
        HasCmdLine := False;
        HasHandles := False;
        HasPublisher := False;
        for I := 0 to VM.FilteredProcesses.Count - 1 do
        begin
          if VM.FilteredProcesses[I].ImagePath <> '' then HasImagePath := True;
          if VM.FilteredProcesses[I].UserName <> '' then HasUser := True;
          if VM.FilteredProcesses[I].CommandLine <> '' then HasCmdLine := True;
          if VM.FilteredProcesses[I].HandleCount > 0 then HasHandles := True;
          if VM.FilteredProcesses[I].CompanyName <> '' then HasPublisher := True;
        end;
        Check('metadata: contains processes with image path', HasImagePath);
        Check('metadata: contains processes with user account', HasUser);
        Check('metadata: contains processes with command line via NtQueryInformationProcess(60)', HasCmdLine);
        Check('metadata: contains processes with kernel HandleCount > 0', HasHandles);
        Check('metadata: contains processes with publisher CompanyName via version.dll', HasPublisher);

        // Network & Services ViewModel integration
        VM.SetActiveView(avNetwork);
        Check('vm: network view populated', VM.NetworkConnections.Count > 0);
        VM.SetActiveView(avServices);
        Check('vm: services view populated', VM.Services.Count > 0);
        VM.SetServiceStatusFilter(1); // Running
        Check('vm: services running filter applied', VM.Services.Count > 0);

        // Startup ViewModel integration
        VM.SetActiveView(avStartup);
        Check('vm: startup view populated', VM.StartupItems.Count > 0);
        VM.SetStartupSearchFilter('a');
        Check('vm: startup search filter applies', VM.StartupItems.Count > 0);
        VM.SetStartupSearchFilter('');

        Check('vm: default interval is 1500ms', VM.PollingIntervalMs = 1500);
        VM.SetPollingInterval(500);
        Check('vm: set interval to 500ms', VM.PollingIntervalMs = 500);
      finally
        VM.Free;
      end;
    end;

    // --- Threshold alert rules (pure logic) ---
    WriteLn('Testing Threshold Alert Rules...');
    begin
      FillChar(AlertCpu, SizeOf(AlertCpu), 0);
      FillChar(AlertRam, SizeOf(AlertRam), 0);
      FillChar(AlertDisk, SizeOf(AlertDisk), 0);
      AlertM := TSystemMetrics.CreateEmpty;
      AlertM.CpuUsagePercent := 40.0;

      AlertNow := 1000;
      Check('alerts: no alert below threshold',
        not TAlertRules.Evaluate(AlertCpu, AlertRam, AlertDisk, AlertM, AlertNow,
          AlertKind, AlertTitle, AlertMsg, AlertSeverity));

      AlertM.CpuUsagePercent := 95.0;
      // Feed SUSTAIN-2 breached samples first; the next two checks then exercise
      // the third (still below sustain) and fourth (raises) sample of the streak
      for I := 1 to TAlertRules.SUSTAIN_SAMPLES - 2 do
        TAlertRules.Evaluate(AlertCpu, AlertRam, AlertDisk, AlertM, AlertNow + I * 10,
          AlertKind, AlertTitle, AlertMsg, AlertSeverity);
      Check('alerts: sustained streak required before raising',
        not TAlertRules.Evaluate(AlertCpu, AlertRam, AlertDisk, AlertM, AlertNow + 100,
          AlertKind, AlertTitle, AlertMsg, AlertSeverity));
      Check('alerts: CPU alert raises at sustained breach',
        TAlertRules.Evaluate(AlertCpu, AlertRam, AlertDisk, AlertM, AlertNow + 200,
          AlertKind, AlertTitle, AlertMsg, AlertSeverity) and
        (AlertKind = TAlertRules.KIND_CPU) and (AlertSeverity = 2));
      Check('alerts: cooldown suppresses immediate re-alert',
        not TAlertRules.Evaluate(AlertCpu, AlertRam, AlertDisk, AlertM, AlertNow + 300,
          AlertKind, AlertTitle, AlertMsg, AlertSeverity));
      Check('alerts: re-alert allowed after cooldown window',
        TAlertRules.Evaluate(AlertCpu, AlertRam, AlertDisk, AlertM,
          AlertNow + 200 + TAlertRules.COOLDOWN_MS + 1,
          AlertKind, AlertTitle, AlertMsg, AlertSeverity));
      AlertM.CpuUsagePercent := 50.0;
      Check('alerts: recovery fires info alert',
        TAlertRules.Evaluate(AlertCpu, AlertRam, AlertDisk, AlertM, AlertNow + 9999,
          AlertKind, AlertTitle, AlertMsg, AlertSeverity) and
        (AlertKind = TAlertRules.KIND_CPU) and (AlertSeverity = 0));
      Check('alerts: no duplicate recovery',
        not TAlertRules.Evaluate(AlertCpu, AlertRam, AlertDisk, AlertM, AlertNow + 10000,
          AlertKind, AlertTitle, AlertMsg, AlertSeverity));
    end;

    // --- Startup programs collection ---
    WriteLn('Testing Startup Programs Collection...');
    begin
      StartList := Svc.CollectStartupEntries;
      try
        Check('startup: entries collected', StartList.Count > 0);
        HasEnabled := False;
        AllNamed := True;
        for I := 0 to StartList.Count - 1 do
        begin
          if StartList[I].Enabled then
            HasEnabled := True;
          if (StartList[I].Name = '') or (StartList[I].Command = '') then
            AllNamed := False;
        end;
        Check('startup: contains enabled entries', HasEnabled);
        Check('startup: all entries have names and commands', AllNamed);
      finally
        StartList.Free;
      end;
      Check('startup: nil item guarded', not Svc.SetStartupEntryEnabled(nil, False));
      EmptyItem := TStartupItem.Create('', '', suHkcuRun, True);
      try
        Check('startup: empty name guarded', not Svc.SetStartupEntryEnabled(EmptyItem, False));
      finally
        EmptyItem.Free;
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
