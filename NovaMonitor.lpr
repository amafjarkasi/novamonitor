program NovaMonitor;

{$mode delphi}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, // Must be the first unit in the uses clause for LCL widgetset initialization
  Forms,
  SysUtils,
  Classes,
  Nova.Types in 'src/Common/Nova.Types.pas',
  Nova.Utils in 'src/Common/Nova.Utils.pas',
  Nova.Service.Metrics in 'src/Services/Nova.Service.Metrics.pas',
  Nova.Service.Exporter in 'src/Services/Nova.Service.Exporter.pas',
  Nova.ViewModel.Main in 'src/ViewModels/Nova.ViewModel.Main.pas',
  Nova.View.Main in 'src/Views/Nova.View.Main.pas';

{$R *.res}

procedure LogCrash(const S: string);
var
  F: TextFile;
  LogPath: string;
begin
  try
    LogPath := ExtractFilePath(ParamStr(0)) + 'nova_error.log';
    AssignFile(F, LogPath);
    if FileExists(LogPath) then
      Append(F)
    else
      Rewrite(F);
    WriteLn(F, FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' - ' + S);
    CloseFile(F);
  except
  end;
end;

type
  TAppHelper = class
    class procedure HandleAppException(Sender: TObject; E: Exception);
  end;

class procedure TAppHelper.HandleAppException(Sender: TObject; E: Exception);
begin
  LogCrash('UNHANDLED EXCEPTION: ' + E.ClassName + ': ' + E.Message);
  Application.ShowException(E);
end;

begin
  try
    Application.OnException := TAppHelper.HandleAppException;
    RequireDerivedFormResource := True;
    Application.Scaled := True;
    Application.Initialize;
    Application.Title := 'NovaMonitor';
    Application.CreateForm(TMainForm, MainForm);
    MainForm.Show;
    Application.Run;
  except
    on E: Exception do
      LogCrash('TOP-LEVEL FATAL: ' + E.ClassName + ': ' + E.Message);
  end;
end.
