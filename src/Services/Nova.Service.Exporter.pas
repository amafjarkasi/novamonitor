unit Nova.Service.Exporter;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  SysUtils,
  Classes,
  {$IFDEF FPC}fpjson,{$ENDIF}
  Nova.Types,
  Nova.Utils;

type
  /// <summary>
  /// Service responsible for serializing telemetry to JSON and CSV
  /// </summary>
  TExportService = class(TInterfacedObject, IExportService)
  public
    function ExportToJson(const AMetrics: TSystemMetrics;
      const AProcesses: TProcessList; const AFilePath: string): Boolean;
    function ExportToCsv(const AProcesses: TProcessList;
      const AFilePath: string): Boolean;
  end;

implementation

{ TExportService }

{$IFDEF FPC}
// FPC 3.2.2 rejects explicit Single-to-Double typecasts; an identity function
// with a Double parameter lets the compiler widen implicitly.
function Sg(const V: Single): Double;
begin
  Result := V;
end;
{$ENDIF}

{$IFNDEF FPC}
// Delphi fallback: manual JSON construction with locale-safe number formatting

function EscapeJson(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #8:   Result := Result + '\b';
      #9:   Result := Result + '\t';
      #10:  Result := Result + '\n';
      #12:  Result := Result + '\f';
      #13:  Result := Result + '\r';
    else
      if (Ord(C) < 32) then
        Result := Result + '\u' + IntToHex(Ord(C), 4)
      else
        Result := Result + C;
    end;
  end;
end;

function NumFmt(const AFmt: string; const AArgs: array of const): string;
begin
  Result := StringReplace(Format(AFmt, AArgs), ',', '.', [rfReplaceAll]);
end;
{$ENDIF}

function TExportService.ExportToJson(const AMetrics: TSystemMetrics;
  const AProcesses: TProcessList; const AFilePath: string): Boolean;
{$IFDEF FPC}
var
  Root, MetricsObj, ProcObj: TJSONObject;
  ProcArr: TJSONArray;
  I: Integer;
  Item: TProcessItem;
  JsonText: string;
  SavedSep: Char;
begin
  Result := False;
  // fpjson formats floats with the locale decimal separator; JSON requires '.'
  SavedSep := FormatSettings.DecimalSeparator;
  try
    FormatSettings.DecimalSeparator := '.';

    Root := TJSONObject.Create;
    try
      Root.Add('generator', 'NovaMonitor Telemetry Suite');
      Root.Add('timestamp', FormatDateTime(
        'yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', AMetrics.Timestamp));

      MetricsObj := TJSONObject.Create;
      MetricsObj.Add('cpuUsagePercent',     Sg(AMetrics.CpuUsagePercent));
      MetricsObj.Add('memoryLoadPercent',   Integer(AMetrics.MemoryLoadPercent));
      MetricsObj.Add('totalPhysicalMB',     Int64(AMetrics.TotalPhysicalMB));
      MetricsObj.Add('usedPhysicalMB',      Int64(AMetrics.UsedPhysicalMB));
      MetricsObj.Add('availablePhysicalMB', Int64(AMetrics.AvailablePhysicalMB));
      MetricsObj.Add('totalDiskGB',         Sg(AMetrics.TotalDiskGB));
      MetricsObj.Add('usedDiskGB',          Sg(AMetrics.UsedDiskGB));
      MetricsObj.Add('freeDiskGB',          Sg(AMetrics.FreeDiskGB));
      MetricsObj.Add('diskUsagePercent',    Sg(AMetrics.DiskUsagePercent));
      MetricsObj.Add('netDownloadKBps',     Sg(AMetrics.NetDownloadKBps));
      MetricsObj.Add('netUploadKBps',       Sg(AMetrics.NetUploadKBps));
      MetricsObj.Add('uptimeSeconds',       Int64(AMetrics.UptimeSeconds));
      MetricsObj.Add('gpuName',             AMetrics.Gpu.Name);
      MetricsObj.Add('gpuEngineUsagePercent', Sg(AMetrics.Gpu.EngineUsagePercent));
      MetricsObj.Add('gpuDedicatedTotalMB', Int64(AMetrics.Gpu.DedicatedTotalMB));
      MetricsObj.Add('gpuDedicatedUsedMB',  Int64(AMetrics.Gpu.DedicatedUsedMB));
      MetricsObj.Add('gpuSharedUsageMB',    Int64(AMetrics.Gpu.SharedUsageMB));
      MetricsObj.Add('gpuAvailable',        AMetrics.Gpu.Available);
      Root.Add('systemMetrics', MetricsObj);

      ProcArr := TJSONArray.Create;
      if Assigned(AProcesses) then
        for I := 0 to AProcesses.Count - 1 do
        begin
          Item := AProcesses[I];
          ProcObj := TJSONObject.Create;
          ProcObj.Add('id',       Integer(Item.Id));
          ProcObj.Add('name',     Item.Name);
          ProcObj.Add('memoryMB', Sg(Item.MemoryWorkingSetMB));
          ProcObj.Add('status',   TUIUtils.StatusToString(Item.Status));
          ProcObj.Add('threads',  Item.ThreadCount);
          ProcObj.Add('networkIoKBps', Sg(Item.NetIoKBps));
          ProcArr.Add(ProcObj);
        end;
      Root.Add('processes', ProcArr);

      JsonText := Root.FormatJSON;
      with TStringList.Create do
        try
          Text := JsonText;
          SaveToFile(AFilePath);
        finally
          Free;
        end;
      Result := True;
    finally
      Root.Free;
    end;
  finally
    FormatSettings.DecimalSeparator := SavedSep;
  end;
end;
{$ELSE}
var
  Lines: TStringList;
  I: Integer;
  Item: TProcessItem;
  Sep: string;
  GpuAvail: string;
begin
  Result := False;
  Lines := TStringList.Create;
  try
    if AMetrics.Gpu.Available then
      GpuAvail := 'true'
    else
      GpuAvail := 'false';
    Lines.Add('{');
    Lines.Add('  "generator": "NovaMonitor Telemetry Suite",');
    Lines.Add(Format('  "timestamp": "%s",', [FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz"Z"', AMetrics.Timestamp)]));
    Lines.Add('  "systemMetrics": {');
    Lines.Add(NumFmt('    "cpuUsagePercent": %.2f,', [AMetrics.CpuUsagePercent]));
    Lines.Add(Format('    "memoryLoadPercent": %d,', [AMetrics.MemoryLoadPercent]));
    Lines.Add(Format('    "totalPhysicalMB": %d,', [AMetrics.TotalPhysicalMB]));
    Lines.Add(Format('    "usedPhysicalMB": %d,', [AMetrics.UsedPhysicalMB]));
    Lines.Add(Format('    "availablePhysicalMB": %d,', [AMetrics.AvailablePhysicalMB]));
    Lines.Add(NumFmt('    "totalDiskGB": %.2f,', [AMetrics.TotalDiskGB]));
    Lines.Add(NumFmt('    "usedDiskGB": %.2f,', [AMetrics.UsedDiskGB]));
    Lines.Add(NumFmt('    "freeDiskGB": %.2f,', [AMetrics.FreeDiskGB]));
    Lines.Add(NumFmt('    "diskUsagePercent": %.2f,', [AMetrics.DiskUsagePercent]));
    Lines.Add(NumFmt('    "netDownloadKBps": %.2f,', [AMetrics.NetDownloadKBps]));
    Lines.Add(NumFmt('    "netUploadKBps": %.2f,', [AMetrics.NetUploadKBps]));
    Lines.Add(Format('    "uptimeSeconds": %d,', [AMetrics.UptimeSeconds]));
    Lines.Add(Format('    "gpuName": "%s",', [EscapeJson(AMetrics.Gpu.Name)]));
    Lines.Add(NumFmt('    "gpuEngineUsagePercent": %.2f,', [AMetrics.Gpu.EngineUsagePercent]));
    Lines.Add(Format('    "gpuDedicatedTotalMB": %d,', [AMetrics.Gpu.DedicatedTotalMB]));
    Lines.Add(Format('    "gpuDedicatedUsedMB": %d,', [AMetrics.Gpu.DedicatedUsedMB]));
    Lines.Add(Format('    "gpuSharedUsageMB": %d,', [AMetrics.Gpu.SharedUsageMB]));
    Lines.Add(Format('    "gpuAvailable": %s', [GpuAvail]));
    Lines.Add('  },');
    Lines.Add('  "processes": [');

    if Assigned(AProcesses) then
    begin
      for I := 0 to AProcesses.Count - 1 do
      begin
        Item := AProcesses[I];
        if I = AProcesses.Count - 1 then
          Sep := ''
        else
          Sep := ',';

        Lines.Add('    {');
        Lines.Add(Format('      "id": %d,', [Item.Id]));
        Lines.Add(Format('      "name": "%s",', [EscapeJson(Item.Name)]));
        Lines.Add(NumFmt('      "memoryMB": %.2f,', [Item.MemoryWorkingSetMB]));
        Lines.Add(Format('      "status": "%s",', [TUIUtils.StatusToString(Item.Status)]));
        Lines.Add(NumFmt('      "networkIoKBps": %.2f,', [Item.NetIoKBps]));
        Lines.Add(Format('      "threads": %d', [Item.ThreadCount]));
        Lines.Add('    }' + Sep);
      end;
    end;

    Lines.Add('  ]');
    Lines.Add('}');

    Lines.SaveToFile(AFilePath);
    Result := True;
  finally
    Lines.Free;
  end;
end;
{$ENDIF}

function TExportService.ExportToCsv(const AProcesses: TProcessList;
  const AFilePath: string): Boolean;
var
  Lines: TStringList;
  I: Integer;
  Item: TProcessItem;
begin
  Result := False;
  Lines := TStringList.Create;
  try
    Lines.Add('PID,ProcessName,MemoryMB,Status,Threads,NetworkIoKBps');
    if Assigned(AProcesses) then
    begin
      for I := 0 to AProcesses.Count - 1 do
      begin
        Item := AProcesses[I];
        Lines.Add(Format('%d,"%s",%.2f,"%s",%d,%.2f', [
          Item.Id,
          StringReplace(Item.Name, '"', '""', [rfReplaceAll]),
          Item.MemoryWorkingSetMB,
          TUIUtils.StatusToString(Item.Status),
          Item.ThreadCount,
          Item.NetIoKBps
        ]));
      end;
    end;

    Lines.SaveToFile(AFilePath);
    Result := True;
  finally
    Lines.Free;
  end;
end;

end.
