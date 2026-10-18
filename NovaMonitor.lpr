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

procedure LogMsg(const S: string);
var
  F: TextFile;
  LogPath: string;
begin
  try
    LogPath := ExtractFilePath(ParamStr(0)) + 'nova_run.log';
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
  LogMsg('UNHANDLED EXCEPTION in Application: ' + E.ClassName + ': ' + E.Message);
end;

begin
  try
    LogMsg('Application starting...');
    Application.OnException := TAppHelper.HandleAppException;
    RequireDerivedFormResource := True;
    Application.Scaled := True;
    Application.Initialize;
    LogMsg('Application.Initialize completed');
    Application.Title := 'NovaMonitor';
    LogMsg('Creating MainForm...');
    Application.CreateForm(TMainForm, MainForm);
    LogMsg('MainForm created. MainForm.Handle = ' + IntToStr(Int64(MainForm.Handle)));
    MainForm.Show;
    LogMsg('MainForm.Show called. Visible = ' + BoolToStr(MainForm.Visible, True));
    Application.Run;
    LogMsg('Application.Run exited normally');
  except
    on E: Exception do
      LogMsg('TOP-LEVEL EXCEPTION: ' + E.ClassName + ': ' + E.Message);
  end;
end.
