program NovaMonitor;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  Vcl.Forms,
  Nova.Types in 'src\Common\Nova.Types.pas',
  Nova.Utils in 'src\Common\Nova.Utils.pas',
  Nova.Service.Metrics in 'src\Services\Nova.Service.Metrics.pas',
  Nova.Service.Exporter in 'src\Services\Nova.Service.Exporter.pas',
  Nova.ViewModel.Main in 'src\ViewModels\Nova.ViewModel.Main.pas',
  Nova.View.Main in 'src\Views\Nova.View.Main.pas' {MainForm};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'NovaMonitor';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
