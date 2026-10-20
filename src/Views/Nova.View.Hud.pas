unit Nova.View.Hud;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  SysUtils,
  Classes,
  // Windows must precede Types: its RECT type must not shadow Types.Rect()
  Windows,
  Types,
  Graphics,
  Controls,
  Forms,
  StdCtrls,
  ExtCtrls,
  Menus,
  Nova.Types,
  Nova.Utils,
  Nova.ViewModel.Main;

type
  /// <summary>
  /// Compact borderless always-on-top telemetry overlay (Ctrl+M): live
  /// CPU / RAM / Disk I/O / Network sparklines driven from the shared
  /// ViewModel while the main window stays hidden. Entirely code-built
  /// (no .lfm/.dfm resource) so it stays identical across both IDE targets.
  /// </summary>
  THudMonitorForm = class(TForm)
  private
    FViewModel: TMainViewModel;
    FColors: TThemeColors;
    FOnRequestRestore: TNotifyEvent;
    FUpdateTimer: TTimer;
    FHeaderPanel: TPanel;
    FBodyPanel: TPanel;
    FLblTitle: TLabel;
    FBtnClose: TButton;
    FHudMenu: TPopupMenu;
    FPbCpu: TPaintBox;
    FPbRam: TPaintBox;
    FPbDisk: TPaintBox;
    FPbNet: TPaintBox;
    FCpuHistory: THistoryBuffer;
    FRamHistory: THistoryBuffer;
    FDiskHistory: THistoryBuffer;
    FNetHistory: THistoryBuffer;
    FLastCpu: Single;
    FLastRam: Single;
    FLastDiskKBps: Single;
    FLastNetDown: Single;
    FLastNetUp: Single;

    procedure HandleTimer(Sender: TObject);
    procedure HandleDragStart(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HandleHudKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleCloseClick(Sender: TObject);
    procedure HandleRestoreClick(Sender: TObject);
    procedure HandleExitClick(Sender: TObject);
    procedure PaintCpuRow(Sender: TObject);
    procedure PaintRamRow(Sender: TObject);
    procedure PaintDiskRow(Sender: TObject);
    procedure PaintNetRow(Sender: TObject);
    procedure DrawHudRow(const APaintBox: TPaintBox; const ATitle, AValue: string;
      const APercent: Single; const AHistory: TSingleDynArray; const ABarColor: TColor);
    procedure RequestRestore;
  public
    constructor Create(AOwner: TComponent; AViewModel: TMainViewModel); reintroduce;
    procedure SetTheme(const AColors: TThemeColors);
    procedure PullLatestMetrics;
    property OnRequestRestore: TNotifyEvent read FOnRequestRestore write FOnRequestRestore;
  end;

implementation

const
  // UTF-8 byte sequences (FPC/LCL) vs UTF-16 char codes (Delphi)
  {$IFDEF FPC}
  HudDownArrow = #$E2#$86#$93; // U+2193
  HudUpArrow   = #$E2#$86#$91; // U+2191
  HudCloseGlyph = #$E2#$9C#$95; // U+2715
  {$ELSE}
  HudDownArrow = #$2193;
  HudUpArrow   = #$2191;
  HudCloseGlyph = #$2715;
  {$ENDIF}

{ THudMonitorForm }

constructor THudMonitorForm.Create(AOwner: TComponent; AViewModel: TMainViewModel);
var
  RestoreItem, ExitItem, SepItem: TMenuItem;
begin
  inherited CreateNew(AOwner);
  FViewModel := AViewModel;
  FOnRequestRestore := nil;
  FCpuHistory.Clear;
  FRamHistory.Clear;
  FDiskHistory.Clear;
  FNetHistory.Clear;
  FLastCpu := 0.0;
  FLastRam := 0.0;
  FLastDiskKBps := 0.0;
  FLastNetDown := 0.0;
  FLastNetUp := 0.0;

  Name := 'HudMonitorForm';
  Caption := 'NovaMonitor HUD';
  BorderStyle := bsNone;
  FormStyle := fsStayOnTop;
  Position := poScreenCenter;
  ClientWidth := 340;
  ClientHeight := 220;
  Constraints.MaxWidth := 340;
  Constraints.MinWidth := 340;
  Constraints.MaxHeight := 220;
  Constraints.MinHeight := 220;
  Font.Name := 'Segoe UI';
  Font.Size := 9;
  KeyPreview := True;
  OnKeyDown := HandleHudKeyDown;
  OnMouseDown := HandleDragStart;
  DoubleBuffered := True;

  FHeaderPanel := TPanel.Create(Self);
  FHeaderPanel.Parent := Self;
  FHeaderPanel.Align := alTop;
  FHeaderPanel.Height := 30;
  FHeaderPanel.BevelOuter := bvNone;
  FHeaderPanel.OnMouseDown := HandleDragStart;

  FLblTitle := TLabel.Create(Self);
  FLblTitle.Parent := FHeaderPanel;
  FLblTitle.SetBounds(12, 7, 220, 18);
  FLblTitle.Caption := 'NOVA MONITOR  ·  COMPACT HUD';
  FLblTitle.Font.Name := 'Segoe UI';
  FLblTitle.Font.Size := 9;
  FLblTitle.Font.Style := [fsBold];
  FLblTitle.OnMouseDown := HandleDragStart;

  FBtnClose := TButton.Create(Self);
  FBtnClose.Parent := FHeaderPanel;
  FBtnClose.SetBounds(304, 4, 28, 22);
  FBtnClose.Caption := HudCloseGlyph;
  FBtnClose.Hint := 'Restore the full NovaMonitor window (Ctrl+M)';
  FBtnClose.ShowHint := True;
  FBtnClose.OnClick := HandleCloseClick;

  FBodyPanel := TPanel.Create(Self);
  FBodyPanel.Parent := Self;
  FBodyPanel.Align := alClient;
  FBodyPanel.BevelOuter := bvNone;
  FBodyPanel.OnMouseDown := HandleDragStart;

  FPbCpu := TPaintBox.Create(Self);
  FPbCpu.Parent := FBodyPanel;
  FPbCpu.SetBounds(10, 6, 320, 42);
  FPbCpu.OnPaint := PaintCpuRow;
  FPbCpu.OnMouseDown := HandleDragStart;
  FPbCpu.PopupMenu := nil;

  FPbRam := TPaintBox.Create(Self);
  FPbRam.Parent := FBodyPanel;
  FPbRam.SetBounds(10, 52, 320, 42);
  FPbRam.OnPaint := PaintRamRow;
  FPbRam.OnMouseDown := HandleDragStart;

  FPbDisk := TPaintBox.Create(Self);
  FPbDisk.Parent := FBodyPanel;
  FPbDisk.SetBounds(10, 98, 320, 42);
  FPbDisk.OnPaint := PaintDiskRow;
  FPbDisk.OnMouseDown := HandleDragStart;

  FPbNet := TPaintBox.Create(Self);
  FPbNet.Parent := FBodyPanel;
  FPbNet.SetBounds(10, 144, 320, 42);
  FPbNet.OnPaint := PaintNetRow;
  FPbNet.OnMouseDown := HandleDragStart;

  FHudMenu := TPopupMenu.Create(Self);
  RestoreItem := TMenuItem.Create(FHudMenu);
  RestoreItem.Caption := 'Restore NovaMonitor' + #9 + 'Ctrl+M';
  RestoreItem.OnClick := HandleRestoreClick;
  FHudMenu.Items.Add(RestoreItem);

  SepItem := TMenuItem.Create(FHudMenu);
  SepItem.Caption := '-';
  FHudMenu.Items.Add(SepItem);

  ExitItem := TMenuItem.Create(FHudMenu);
  ExitItem.Caption := 'Exit NovaMonitor';
  ExitItem.OnClick := HandleExitClick;
  FHudMenu.Items.Add(ExitItem);

  PopupMenu := FHudMenu;
  FPbCpu.PopupMenu := FHudMenu;
  FPbRam.PopupMenu := FHudMenu;
  FPbDisk.PopupMenu := FHudMenu;
  FPbNet.PopupMenu := FHudMenu;

  FUpdateTimer := TTimer.Create(Self);
  FUpdateTimer.Interval := 1200;
  FUpdateTimer.OnTimer := HandleTimer;
  FUpdateTimer.Enabled := True;
end;

procedure THudMonitorForm.HandleTimer(Sender: TObject);
begin
  if not Visible then Exit;
  PullLatestMetrics;
end;

procedure THudMonitorForm.HandleDragStart(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  // Classic borderless-drag: hand the click to the non-client caption area
  if Button = mbLeft then
  begin
    ReleaseCapture;
    SendMessage(Handle, WM_NCLBUTTONDOWN, HTCAPTION, 0);
  end;
end;

procedure THudMonitorForm.HandleHudKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if ((ssCtrl in Shift) and (Key = Word('M'))) or (Key = VK_ESCAPE) then
  begin
    RequestRestore;
    Key := 0;
  end;
end;

procedure THudMonitorForm.HandleCloseClick(Sender: TObject);
begin
  RequestRestore;
end;

procedure THudMonitorForm.HandleRestoreClick(Sender: TObject);
begin
  RequestRestore;
end;

procedure THudMonitorForm.HandleExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure THudMonitorForm.RequestRestore;
begin
  if Assigned(FOnRequestRestore) then
    FOnRequestRestore(Self);
end;

procedure THudMonitorForm.SetTheme(const AColors: TThemeColors);
begin
  FColors := AColors;
  Color := AColors.Background;
  FHeaderPanel.Color := AColors.Surface;
  FBodyPanel.Color := AColors.Background;
  FLblTitle.Font.Color := AColors.Accent;
  FPbCpu.Invalidate;
  FPbRam.Invalidate;
  FPbDisk.Invalidate;
  FPbNet.Invalidate;
end;

procedure THudMonitorForm.PullLatestMetrics;
var
  M: TSystemMetrics;
  RamPct, NetSum: Single;
begin
  if FViewModel = nil then Exit;
  M := FViewModel.LatestMetrics;

  FLastCpu := M.CpuUsagePercent;
  FCpuHistory.Add(FLastCpu);

  if M.TotalPhysicalMB > 0 then
    RamPct := (M.UsedPhysicalMB * 100.0) / M.TotalPhysicalMB
  else
    RamPct := Single(M.MemoryLoadPercent);
  FLastRam := RamPct;
  FRamHistory.Add(RamPct);

  FLastDiskKBps := FViewModel.GetAggregateDiskIoKBps;
  FDiskHistory.Add(FLastDiskKBps);

  FLastNetDown := M.NetDownloadKBps;
  FLastNetUp := M.NetUploadKBps;
  NetSum := FLastNetDown + FLastNetUp;
  FNetHistory.Add(NetSum);

  FPbCpu.Invalidate;
  FPbRam.Invalidate;
  FPbDisk.Invalidate;
  FPbNet.Invalidate;
end;

procedure THudMonitorForm.DrawHudRow(const APaintBox: TPaintBox;
  const ATitle, AValue: string; const APercent: Single;
  const AHistory: TSingleDynArray; const ABarColor: TColor);
var
  C: TCanvas;
  R, SparkR, BarR: TRect;
  MaxTextWidth: Integer;
  ValueTxt: string;

  // Ellipsize against the current font so text never enters the sparkline
  function FitText(const S: string; const MaxW: Integer): string;
  begin
    Result := S;
    if (MaxW <= 0) or (C.TextWidth(Result) <= MaxW) then Exit;
    while (Length(Result) > 1) and (C.TextWidth(Result + '…') > MaxW) do
      Delete(Result, Length(Result), 1);
    Result := Result + '…';
  end;

begin
  C := APaintBox.Canvas;
  R := Rect(0, 0, APaintBox.Width, APaintBox.Height);
  TUIUtils.DrawCard(C, R, FColors.SurfaceCard, FColors.Border, 6);

  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';
  C.Font.Size := 8;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextSecondary;
  // Text column must stop before the sparkline zone (Right - 150)
  MaxTextWidth := (R.Right - 158) - (R.Left + 10);
  C.TextOut(R.Left + 10, R.Top + 3, FitText(ATitle, MaxTextWidth));

  C.Font.Size := 14;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  while (C.Font.Size > 11) and (C.TextWidth(AValue) > MaxTextWidth) do
    C.Font.Size := C.Font.Size - 1;
  ValueTxt := FitText(AValue, MaxTextWidth);
  C.TextOut(R.Left + 10, R.Top + 16, ValueTxt);

  if Length(AHistory) >= 2 then
  begin
    SparkR := Rect(R.Right - 150, R.Top + 5, R.Right - 8, R.Bottom - 5);
    TUIUtils.DrawSparkline(C, SparkR, AHistory, ABarColor,
      TUIUtils.BlendColor(FColors.SurfaceCard, ABarColor, 0.22));
  end;

  if APercent >= 0 then
  begin
    BarR := Rect(R.Left + 10, R.Bottom - 5, R.Right - 160, R.Bottom - 2);
    if BarR.Right > BarR.Left then
      TUIUtils.DrawProgressBar(C, BarR, APercent, FColors.Border, ABarColor);
  end;
end;

procedure THudMonitorForm.PaintCpuRow(Sender: TObject);
var
  BarColor: TColor;
begin
  if FLastCpu > 80.0 then
    BarColor := FColors.Danger
  else if FLastCpu > 50.0 then
    BarColor := FColors.Warning
  else
    BarColor := FColors.Accent;
  DrawHudRow(FPbCpu, 'CPU', TUIUtils.FormatPercent(FLastCpu), FLastCpu,
    FCpuHistory.ToArray, BarColor);
end;

procedure THudMonitorForm.PaintRamRow(Sender: TObject);
var
  BarColor: TColor;
begin
  if FLastRam >= 85.0 then
    BarColor := FColors.Danger
  else if FLastRam >= 70.0 then
    BarColor := FColors.Warning
  else
    BarColor := FColors.Accent;
  DrawHudRow(FPbRam, 'MEMORY', Format('%.1f%%', [FLastRam]), FLastRam,
    FRamHistory.ToArray, BarColor);
end;

procedure THudMonitorForm.PaintDiskRow(Sender: TObject);
begin
  DrawHudRow(FPbDisk, 'DISK I/O', TUIUtils.FormatRateKBps(FLastDiskKBps), -1.0,
    FDiskHistory.ToArray, FColors.Warning);
end;

procedure THudMonitorForm.PaintNetRow(Sender: TObject);
begin
  DrawHudRow(FPbNet, 'NETWORK',
    Format('%s %s   %s %s', [HudDownArrow, TUIUtils.FormatRateKBps(FLastNetDown),
      HudUpArrow, TUIUtils.FormatRateKBps(FLastNetUp)]),
    -1.0, FNetHistory.ToArray, FColors.Success);
end;

end.
