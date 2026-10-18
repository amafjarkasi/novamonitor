unit Nova.View.Main;

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
  Dialogs,
  StdCtrls,
  ExtCtrls,
  ComCtrls,
  Menus,
  Clipbrd,
  {$IFDEF FPC}
  ShellApi,
  {$ELSE}
  Winapi.ShellApi,
  {$ENDIF}
  Nova.Types,
  Nova.Utils,
  Nova.ViewModel.Main;

type
  TMainForm = class(TForm)
    pnlSidebar: TPanel;
    pnlHeader: TPanel;
    pnlContent: TPanel;
    pnlFooter: TPanel;
    pnlBrand: TPanel;
    lblBrandTitle: TLabel;
    lblBrandSubtitle: TLabel;
    
    // Navigation Buttons
    btnNavDashboard: TButton;
    btnNavProcesses: TButton;
    btnNavExport: TButton;
    btnNavThemeToggle: TButton;
    pnlNavBottom: TPanel;
    chkTray: TCheckBox;
    lblStatusIndicator: TLabel;

    // Header Controls
    lblPageTitle: TLabel;
    pnlHeaderActions: TPanel;
    edtSearch: TEdit;
    btnToggleMonitor: TButton;
    btnExportSnapshot: TButton;

    // Metrics Card Container
    pnlMetricsGrid: TPanel;
    pbCardCpu: TPaintBox;
    pbCardRam: TPaintBox;
    pbCardDisk: TPaintBox;
    pbCardUptime: TPaintBox;

    // Process Table Container
    pnlProcessSection: TPanel;
    pnlTableToolbar: TPanel;
    lblTableTitle: TLabel;
    lblProcessCount: TLabel;
    lvProcesses: TListView;

    // Status Footer
    lblFooterStatus: TLabel;
    lblFooterTime: TLabel;
    SaveDialog: TSaveDialog;

    // Form lifecycle events
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    // Navigation handlers
    procedure btnNavDashboardClick(Sender: TObject);
    procedure btnNavProcessesClick(Sender: TObject);
    procedure btnNavThemeToggleClick(Sender: TObject);
    procedure btnToggleMonitorClick(Sender: TObject);
    procedure btnExportSnapshotClick(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);

    // Custom drawing handlers
    procedure pbCardCpuPaint(Sender: TObject);
    procedure pbCardRamPaint(Sender: TObject);
    procedure pbCardDiskPaint(Sender: TObject);
    procedure pbCardUptimePaint(Sender: TObject);

    // Process list custom drawing (wired in .lfm/.dfm)
    procedure lvProcessesCustomDrawItem(Sender: TCustomListView;
      Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
    procedure lvProcessesCustomDrawSubItem(Sender: TCustomListView;
      Item: TListItem; SubItem: Integer; State: TCustomDrawState;
      var DefaultDraw: Boolean);
  private
    FViewModel: TMainViewModel;
    FColors: TThemeColors;
    FInitialized: Boolean;
    FTrayIcon: TTrayIcon;
    FActiveView: TAppView;
    FContextMenu: TPopupMenu;

    btnPinWindow: TButton;
    btnFilterAll: TButton;
    btnFilterMem: TButton;
    btnFilterCpu: TButton;
    btnFilterCrit: TButton;
    btnEndTask: TButton;

    function GetSelectedProcess: TProcessItem;
    procedure SetupContextMenu;
    procedure SetupTableToolbarActions;
    procedure UpdateFilterChipStyles;
    procedure TerminateSelectedProcess;

    procedure btnPinWindowClick(Sender: TObject);
    procedure btnFilterAllClick(Sender: TObject);
    procedure btnFilterMemClick(Sender: TObject);
    procedure btnFilterCpuClick(Sender: TObject);
    procedure btnFilterCritClick(Sender: TObject);
    procedure btnEndTaskClick(Sender: TObject);
    procedure mnuEndTaskClick(Sender: TObject);

    procedure mnuCopyNameClick(Sender: TObject);
    procedure mnuCopyPidClick(Sender: TObject);
    procedure mnuCopyDetailsClick(Sender: TObject);

    procedure OnMetricsUpdated(const AMetrics: TSystemMetrics);
    procedure OnProcessesUpdated(const AProcesses: TProcessList);
    procedure OnStatusMessage(const AMessage: string; const AIsError: Boolean);
    procedure OnThemeChanged(const ATheme: TAppTheme);

    procedure AppMinimize(Sender: TObject);
    procedure TrayIconClick(Sender: TObject);

    procedure ApplyTheme(const AColors: TThemeColors);
    procedure SwitchView(const AView: TAppView);
    procedure RefreshProcessList(const AProcesses: TProcessList);
    procedure StretchLastColumn;
    procedure UpdateSortIndicators;
    procedure lvProcessesData(Sender: TObject; Item: TListItem);
    {$IFDEF FPC}
    procedure lvProcessesColumnClick(Sender: TObject; Column: TListColumn);
    {$ELSE}
    procedure lvProcessesColumnClick(Sender: TObject; Column: TListColumn;
      var CanClick: Boolean);
    {$ENDIF}
    procedure DrawMetricCard(const APaintBox: TPaintBox; const ATitle: string;
      const APrimaryVal: string; const ASecondaryVal: string;
      const APercent: Single; const ABarColor: TColor;
      const AHistory: TSingleDynArray = nil);
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$IFNDEF FPC}
  {$R *.dfm}
{$ELSE}
  {$R *.lfm}
{$ENDIF}


const
  // Sort markers as byte/char constants: LCL strings are UTF-8, Delphi's are
  // UTF-16, and literal #$xx sequences stay correct in both encodings
  {$IFDEF FPC}
  AscArrow  = #$E2#$96#$B2; // U+25B2
  DescArrow = #$E2#$96#$BC; // U+25BC
  {$ELSE}
  AscArrow  = #$25B2;
  DescArrow = #$25BC;
  {$ENDIF}
  BaseColumnCaptions: array[0..5] of string =
    ('PID', 'Process Name', 'CPU %', 'Working Set (RAM)', 'Health Status',
     'Active Threads');

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  DoubleBuffered := True;
  pnlSidebar.DoubleBuffered := True;
  pnlHeader.DoubleBuffered := True;
  pnlContent.DoubleBuffered := True;
  pnlProcessSection.DoubleBuffered := True;
  pnlMetricsGrid.DoubleBuffered := True;

  KeyPreview := True;
  OnKeyDown := FormKeyDown;

  Font.Name := 'Segoe UI';
  Font.Size := 9;
  FInitialized := False;
  FActiveView := avDashboard;

  FViewModel := TMainViewModel.Create;
  FViewModel.OnMetricsUpdated   := OnMetricsUpdated;
  FViewModel.OnProcessesUpdated := OnProcessesUpdated;
  FViewModel.OnStatusMessage    := OnStatusMessage;
  FViewModel.OnThemeChanged     := OnThemeChanged;

  {$IFDEF FPC}
  lvProcesses.ColumnClick := True; // LCL gates header clicks on this flag
  {$ENDIF}
  lvProcesses.OnColumnClick := lvProcessesColumnClick;

  // Owner-data (virtual) list: rows are served from the ViewModel on demand.
  lvProcesses.OwnerData := True;
  lvProcesses.OnData := lvProcessesData;

  // Configure Header Pin Window (Always on Top) toggle button
  pnlHeaderActions.Width := 520;
  btnPinWindow := TButton.Create(Self);
  btnPinWindow.Parent := pnlHeaderActions;
  btnPinWindow.SetBounds(222, 18, 54, 28);
  btnPinWindow.Caption := 'Pin';
  btnPinWindow.Hint := 'Toggle Always on Top (Ctrl+P)';
  btnPinWindow.ShowHint := True;
  btnPinWindow.OnClick := btnPinWindowClick;

  btnToggleMonitor.Left := 282;
  btnExportSnapshot.Left := 386;

  SetupContextMenu;
  SetupTableToolbarActions;

  // Minimize-to-tray: the checkbox gates the behavior chosen at minimize time
  FTrayIcon := TTrayIcon.Create(Self);
  if Assigned(Application.Icon) and (not Application.Icon.Empty) then
    FTrayIcon.Icon.Assign(Application.Icon);
  FTrayIcon.Hint := 'NovaMonitor';
  FTrayIcon.OnClick := TrayIconClick;
  Application.OnMinimize := AppMinimize;

  FColors := FViewModel.ThemeColors;
  ApplyTheme(FColors);
  UpdateSortIndicators;
  UpdateFilterChipStyles;
end;

procedure TMainForm.SetupTableToolbarActions;
begin
  btnFilterAll := TButton.Create(Self);
  btnFilterAll.Parent := pnlTableToolbar;
  btnFilterAll.SetBounds(210, 7, 46, 26);
  btnFilterAll.Caption := '[All]';
  btnFilterAll.Hint := 'Show all active processes (Ctrl+1)';
  btnFilterAll.ShowHint := True;
  btnFilterAll.OnClick := btnFilterAllClick;

  btnFilterMem := TButton.Create(Self);
  btnFilterMem.Parent := pnlTableToolbar;
  btnFilterMem.SetBounds(260, 7, 142, 26);
  btnFilterMem.Caption := 'Heavy RAM (>400MB)';
  btnFilterMem.Hint := 'Filter processes consuming >400MB RAM (Ctrl+2)';
  btnFilterMem.ShowHint := True;
  btnFilterMem.OnClick := btnFilterMemClick;

  btnFilterCpu := TButton.Create(Self);
  btnFilterCpu.Parent := pnlTableToolbar;
  btnFilterCpu.SetBounds(406, 7, 116, 26);
  btnFilterCpu.Caption := 'Active CPU (>2%)';
  btnFilterCpu.Hint := 'Filter processes actively using >2% CPU (Ctrl+3)';
  btnFilterCpu.ShowHint := True;
  btnFilterCpu.OnClick := btnFilterCpuClick;

  btnFilterCrit := TButton.Create(Self);
  btnFilterCrit.Parent := pnlTableToolbar;
  btnFilterCrit.SetBounds(526, 7, 65, 26);
  btnFilterCrit.Caption := 'Alerts';
  btnFilterCrit.Hint := 'Filter processes in Warning or Critical state (Ctrl+4)';
  btnFilterCrit.ShowHint := True;
  btnFilterCrit.OnClick := btnFilterCritClick;

  btnEndTask := TButton.Create(Self);
  btnEndTask.Parent := pnlTableToolbar;
  btnEndTask.SetBounds(595, 7, 85, 26);
  btnEndTask.Caption := 'End Task';
  btnEndTask.Hint := 'Terminate selected process (Del)';
  btnEndTask.ShowHint := True;
  btnEndTask.OnClick := btnEndTaskClick;
end;

procedure TMainForm.UpdateFilterChipStyles;
begin
  if not Assigned(btnFilterAll) then Exit;
  case FViewModel.FilterMode of
    fmAll:
      begin
        btnFilterAll.Caption := '[All]';
        btnFilterMem.Caption := 'Heavy RAM (>400MB)';
        btnFilterCpu.Caption := 'Active CPU (>2%)';
        btnFilterCrit.Caption := 'Alerts';
      end;
    fmHeavyMemory:
      begin
        btnFilterAll.Caption := 'All';
        btnFilterMem.Caption := '[Heavy RAM (>400MB)]';
        btnFilterCpu.Caption := 'Active CPU (>2%)';
        btnFilterCrit.Caption := 'Alerts';
      end;
    fmActiveCpu:
      begin
        btnFilterAll.Caption := 'All';
        btnFilterMem.Caption := 'Heavy RAM (>400MB)';
        btnFilterCpu.Caption := '[Active CPU (>2%)]';
        btnFilterCrit.Caption := 'Alerts';
      end;
    fmCriticalOnly:
      begin
        btnFilterAll.Caption := 'All';
        btnFilterMem.Caption := 'Heavy RAM (>400MB)';
        btnFilterCpu.Caption := 'Active CPU (>2%)';
        btnFilterCrit.Caption := '[Alerts]';
      end;
  end;
end;

procedure TMainForm.btnFilterAllClick(Sender: TObject);
begin
  FViewModel.SetFilterMode(fmAll);
  UpdateFilterChipStyles;
  lblFooterStatus.Caption := 'Showing all active processes';
  lblFooterStatus.Font.Color := FColors.TextSecondary;
end;

procedure TMainForm.btnFilterMemClick(Sender: TObject);
begin
  FViewModel.SetFilterMode(fmHeavyMemory);
  UpdateFilterChipStyles;
  lblFooterStatus.Caption := 'Filtered: Heavy Memory Working Set (>400 MB)';
  lblFooterStatus.Font.Color := FColors.Accent;
end;

procedure TMainForm.btnFilterCpuClick(Sender: TObject);
begin
  FViewModel.SetFilterMode(fmActiveCpu);
  UpdateFilterChipStyles;
  lblFooterStatus.Caption := 'Filtered: Active CPU Consumption (>2%)';
  lblFooterStatus.Font.Color := FColors.Accent;
end;

procedure TMainForm.btnFilterCritClick(Sender: TObject);
begin
  FViewModel.SetFilterMode(fmCriticalOnly);
  UpdateFilterChipStyles;
  lblFooterStatus.Caption := 'Filtered: Warning and Critical Health State';
  lblFooterStatus.Font.Color := FColors.Warning;
end;

procedure TMainForm.btnEndTaskClick(Sender: TObject);
begin
  TerminateSelectedProcess;
end;

procedure TMainForm.mnuEndTaskClick(Sender: TObject);
begin
  TerminateSelectedProcess;
end;

procedure TMainForm.btnPinWindowClick(Sender: TObject);
begin
  if FormStyle = fsStayOnTop then
  begin
    FormStyle := fsNormal;
    btnPinWindow.Caption := 'Pin';
    lblFooterStatus.Caption := 'Window unpinned (Normal mode)';
  end
  else
  begin
    FormStyle := fsStayOnTop;
    btnPinWindow.Caption := 'Pinned';
    lblFooterStatus.Caption := 'Window pinned (Always on Top)';
  end;
  lblFooterStatus.Font.Color := FColors.Accent;
end;

procedure TMainForm.TerminateSelectedProcess;
var
  Item: TProcessItem;
begin
  Item := GetSelectedProcess;
  if Item = nil then
  begin
    lblFooterStatus.Caption := 'Select a process from the list first to end task';
    lblFooterStatus.Font.Color := FColors.Warning;
    Exit;
  end;

  if (Item.Id <= 4) or (Item.Id = GetCurrentProcessId) then
  begin
    MessageDlg('Protected Process',
      Format('Process "%s" (PID: %d) is protected and cannot be terminated.',
        [Item.Name, Item.Id]),
      mtWarning, [mbOK], 0);
    Exit;
  end;

  if MessageDlg('End Task Confirmation',
    Format('Are you sure you want to terminate "%s" (PID: %d)?'#13#10#13#10 +
           'Terminating an active task may cause unsaved application data to be lost.',
           [Item.Name, Item.Id]),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    if not FViewModel.KillProcess(Item.Id) then
    begin
      MessageDlg('Access Denied',
        Format('Failed to terminate "%s" (PID: %d).'#13#10 +
               'Administrative privileges may be required to end this process.',
               [Item.Name, Item.Id]),
        mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.SetupContextMenu;
var
  Item: TMenuItem;
begin
  FContextMenu := TPopupMenu.Create(Self);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Copy Process Name';
  Item.OnClick := mnuCopyNameClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Copy Process ID (PID)';
  Item.OnClick := mnuCopyPidClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Copy Details (CSV)';
  Item.OnClick := mnuCopyDetailsClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := '-';
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'End Task' + #9 + 'Del';
  Item.OnClick := mnuEndTaskClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := '-';
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Pause / Resume Monitoring';
  Item.OnClick := btnToggleMonitorClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Export Report (JSON/CSV)...';
  Item.OnClick := btnExportSnapshotClick;
  FContextMenu.Items.Add(Item);

  lvProcesses.PopupMenu := FContextMenu;
end;

function TMainForm.GetSelectedProcess: TProcessItem;
begin
  Result := nil;
  if Assigned(lvProcesses.Selected) and
     (lvProcesses.Selected.Index >= 0) and
     (lvProcesses.Selected.Index < FViewModel.FilteredProcesses.Count) then
  begin
    Result := FViewModel.FilteredProcesses[lvProcesses.Selected.Index];
  end;
end;

procedure TMainForm.mnuCopyNameClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Assigned(Proc) then
  begin
    Clipboard.AsText := Proc.Name;
    lblFooterStatus.Caption := Format('Copied to clipboard: %s', [Proc.Name]);
  end;
end;

procedure TMainForm.mnuCopyPidClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Assigned(Proc) then
  begin
    Clipboard.AsText := IntToStr(Proc.Id);
    lblFooterStatus.Caption := Format('Copied PID to clipboard: %d', [Proc.Id]);
  end;
end;

procedure TMainForm.mnuCopyDetailsClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Assigned(Proc) then
  begin
    Clipboard.AsText := Format('%d,%s,%.2f,%s,%d',
      [Proc.Id, Proc.Name, Proc.MemoryWorkingSetMB, TUIUtils.StatusToString(Proc.Status), Proc.ThreadCount]);
    lblFooterStatus.Caption := Format('Copied record for: %s (PID %d)', [Proc.Name, Proc.Id]);
  end;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_DELETE then
  begin
    TerminateSelectedProcess;
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Word('F')) then
  begin
    edtSearch.SetFocus;
    edtSearch.SelectAll;
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Word('T')) then
  begin
    btnNavThemeToggleClick(nil);
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Word('E')) then
  begin
    btnExportSnapshotClick(nil);
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Word('P')) then
  begin
    btnPinWindowClick(nil);
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Word('1')) then
  begin
    btnFilterAllClick(nil);
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Word('2')) then
  begin
    btnFilterMemClick(nil);
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Word('3')) then
  begin
    btnFilterCpuClick(nil);
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Word('4')) then
  begin
    btnFilterCritClick(nil);
    Key := 0;
  end
  else if (Key = VK_ESCAPE) and edtSearch.Focused then
  begin
    if edtSearch.Text <> '' then
      edtSearch.Text := ''
    else
      lvProcesses.SetFocus;
    Key := 0;
  end;
end;

procedure TMainForm.AppMinimize(Sender: TObject);
begin
  if chkTray.Checked then
  begin
    FTrayIcon.Visible := True;
    Hide;
  end;
end;

procedure TMainForm.TrayIconClick(Sender: TObject);
begin
  Show;
  WindowState := wsNormal;
  FTrayIcon.Visible := False;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  if not FInitialized then
  begin
    FInitialized := True;
    FViewModel.Initialize;
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FViewModel.Free;
end;

procedure TMainForm.FormResize(Sender: TObject);
var
  CardWidth, CardHeight: Integer;
  AvailableWidth: Integer;
  Spacing: Integer;
begin
  Spacing := 12;
  AvailableWidth := pnlMetricsGrid.ClientWidth - (Spacing * 5);
  CardWidth := AvailableWidth div 4;
  if CardWidth < 120 then CardWidth := 120;
  CardHeight := pnlMetricsGrid.ClientHeight - 16;
  if CardHeight < 40 then CardHeight := 100;

  pbCardCpu.SetBounds(Spacing, 8, CardWidth, CardHeight);
  pbCardRam.SetBounds(Spacing * 2 + CardWidth, 8, CardWidth, CardHeight);
  pbCardDisk.SetBounds(Spacing * 3 + CardWidth * 2, 8, CardWidth, CardHeight);
  pbCardUptime.SetBounds(Spacing * 4 + CardWidth * 3, 8, CardWidth, CardHeight);

  StretchLastColumn;
end;

procedure TMainForm.StretchLastColumn;
var
  I, Used, W: Integer;
begin
  if lvProcesses.Columns.Count < 2 then Exit;
  Used := 0;
  for I := 0 to lvProcesses.Columns.Count - 2 do
    Used := Used + lvProcesses.Columns[I].Width;
  W := lvProcesses.ClientWidth - Used; // ClientWidth already excludes a visible scrollbar
  if W < 80 then W := 80;
  if lvProcesses.Columns[lvProcesses.Columns.Count - 1].Width <> W then
    lvProcesses.Columns[lvProcesses.Columns.Count - 1].Width := W;
end;

procedure TMainForm.ApplyTheme(const AColors: TThemeColors);
begin
  Color := AColors.Background;
  pnlSidebar.Color := AColors.SidebarBg;
  pnlBrand.Color := AColors.SidebarBg;
  pnlNavBottom.Color := AColors.SidebarBg;
  lblBrandTitle.Font.Color := AColors.SidebarText;
  lblBrandSubtitle.Font.Color := AColors.TextSecondary;
  lblStatusIndicator.Font.Color := AColors.Success;

  pnlHeader.Color := AColors.Surface;
  lblPageTitle.Font.Color := AColors.TextPrimary;
  pnlHeaderActions.Color := AColors.Surface;

  pnlContent.Color := AColors.Background;
  pnlMetricsGrid.Color := AColors.Background;

  pnlProcessSection.Color := AColors.Surface;
  pnlTableToolbar.Color := AColors.Surface;
  lblTableTitle.Font.Color := AColors.TextPrimary;
  lblProcessCount.Font.Color := AColors.TextSecondary;

  lvProcesses.Color := AColors.Surface;
  lvProcesses.Font.Color := AColors.TextPrimary;

  chkTray.Font.Color := AColors.TextSecondary;

  pnlFooter.Color := AColors.Surface;
  lblFooterStatus.Font.Color := AColors.TextSecondary;
  lblFooterTime.Font.Color := AColors.TextSecondary;

  edtSearch.Color := AColors.SurfaceCard;
  edtSearch.Font.Color := AColors.TextPrimary;

  // Preserve nav button highlight across theme changes
  if FActiveView = avDashboard then
  begin
    btnNavDashboard.Font.Color := AColors.Accent;
    btnNavProcesses.Font.Color := AColors.SidebarText;
  end
  else
  begin
    btnNavDashboard.Font.Color := AColors.SidebarText;
    btnNavProcesses.Font.Color := AColors.Accent;
  end;

  pbCardCpu.Invalidate;
  pbCardRam.Invalidate;
  pbCardDisk.Invalidate;
  pbCardUptime.Invalidate;
  lvProcesses.Invalidate;
end;

procedure TMainForm.OnMetricsUpdated(const AMetrics: TSystemMetrics);
begin
  pbCardCpu.Invalidate;
  pbCardRam.Invalidate;
  pbCardDisk.Invalidate;
  pbCardUptime.Invalidate;

  lblFooterTime.Caption := 'Updated: ' + FormatDateTime('hh:nn:ss', AMetrics.Timestamp);
end;

procedure TMainForm.OnProcessesUpdated(const AProcesses: TProcessList);
begin
  RefreshProcessList(AProcesses);
end;

procedure TMainForm.OnStatusMessage(const AMessage: string; const AIsError: Boolean);
begin
  lblFooterStatus.Caption := AMessage;
  if AIsError then
    lblFooterStatus.Font.Color := FColors.Danger
  else
    lblFooterStatus.Font.Color := FColors.TextSecondary;
end;

procedure TMainForm.OnThemeChanged(const ATheme: TAppTheme);
begin
  FColors := FViewModel.ThemeColors;
  ApplyTheme(FColors);
  if ATheme = atDark then
    btnNavThemeToggle.Caption := 'Theme: Dark'
  else
    btnNavThemeToggle.Caption := 'Theme: Light';
end;

procedure TMainForm.RefreshProcessList(const AProcesses: TProcessList);
begin
  lvProcesses.Items.BeginUpdate;
  try
    // Virtual mode: only the row count changes; visible rows are fetched
    // through lvProcessesData during paint
    lvProcesses.Items.Count := AProcesses.Count;
    lblProcessCount.Caption := Format('%d processes active', [AProcesses.Count]);
    StretchLastColumn;
  finally
    lvProcesses.Items.EndUpdate;
  end;
end;

procedure TMainForm.lvProcessesData(Sender: TObject; Item: TListItem);
var
  ProcItem: TProcessItem;
begin
  if Item = nil then Exit;
  if (Item.Index < 0) or (Item.Index >= FViewModel.FilteredProcesses.Count) then Exit;
  ProcItem := FViewModel.FilteredProcesses[Item.Index];
  Item.Caption := IntToStr(ProcItem.Id);
  Item.SubItems.Clear;
  Item.SubItems.Add(ProcItem.Name);
  Item.SubItems.Add(TUIUtils.FormatPercent(ProcItem.CpuSharePercent));
  Item.SubItems.Add(TUIUtils.FormatMegabytes(ProcItem.MemoryWorkingSetMB));
  Item.SubItems.Add(TUIUtils.StatusToString(ProcItem.Status));
  Item.SubItems.Add(IntToStr(ProcItem.ThreadCount));
end;

procedure TMainForm.DrawMetricCard(const APaintBox: TPaintBox; const ATitle: string;
  const APrimaryVal: string; const ASecondaryVal: string;
  const APercent: Single; const ABarColor: TColor;
  const AHistory: TSingleDynArray);
var
  C: TCanvas;
  R, BarR, SparkR: TRect;
  Y: Integer;
const
  PadX = 14;
  LineGap = 6;
begin
  C := APaintBox.Canvas;
  R := Rect(0, 0, APaintBox.Width, APaintBox.Height);

  TUIUtils.DrawCard(C, R, FColors.SurfaceCard, FColors.Border, 8);

  // Stack title/value/secondary from measured text heights so the spacing
  // stays even regardless of font metrics or DPI; bar pinned to the bottom
  C.Brush.Style := bsClear;
  C.Font.Name := 'Segoe UI';

  Y := R.Top + 10;
  C.Font.Size := 9;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextSecondary;
  C.TextOut(R.Left + PadX, Y, ATitle);
  Inc(Y, C.TextHeight(ATitle) + LineGap);

  C.Font.Size := 15;
  C.Font.Style := [fsBold];
  C.Font.Color := FColors.TextPrimary;
  C.TextOut(R.Left + PadX, Y, APrimaryVal);
  Inc(Y, C.TextHeight(APrimaryVal) + LineGap);

  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  C.TextOut(R.Left + PadX, Y, ASecondaryVal);

  // Render rolling sparkline in the upper-right quadrant if history exists
  if Length(AHistory) >= 2 then
  begin
    SparkR := Rect(R.Right - 70, R.Top + 14, R.Right - 12, R.Bottom - 26);
    TUIUtils.DrawSparkline(C, SparkR, AHistory, ABarColor,
      TUIUtils.BlendColor(FColors.SurfaceCard, ABarColor, 0.22));
  end;

  if APercent >= 0 then
  begin
    BarR := Rect(R.Left + PadX, R.Bottom - 16, R.Right - PadX, R.Bottom - 10);
    TUIUtils.DrawProgressBar(C, BarR, APercent, FColors.Border, ABarColor);
  end;
end;

procedure TMainForm.lvProcessesCustomDrawItem(Sender: TCustomListView;
  Item: TListItem; State: TCustomDrawState; var DefaultDraw: Boolean);
begin
  if Item = nil then Exit;
  // Row caption (PID column): reset the font so status styling cannot bleed
  Sender.Canvas.Font.Color := FColors.TextPrimary;
  Sender.Canvas.Font.Style := [];
end;

procedure TMainForm.lvProcessesCustomDrawSubItem(Sender: TCustomListView;
  Item: TListItem; SubItem: Integer; State: TCustomDrawState;
  var DefaultDraw: Boolean);
var
  ProcItem: TProcessItem;
begin
  if (Item = nil) or (Item.Index < 0) or (Item.Index >= FViewModel.FilteredProcesses.Count) then Exit;
  // SubItem comes 1-based from the Win32 notification: 4 = "Health Status"
  // (0 = PID caption, 1 = name, 2 = CPU, 3 = working set)
  if SubItem = 4 then
  begin
    ProcItem := FViewModel.FilteredProcesses[Item.Index];
    Sender.Canvas.Font.Color := TUIUtils.StatusToColor(ProcItem.Status, FColors);
    Sender.Canvas.Font.Style := [fsBold];
  end
  else
  begin
    Sender.Canvas.Font.Color := FColors.TextPrimary;
    Sender.Canvas.Font.Style := [];
  end;
end;

procedure TMainForm.pbCardCpuPaint(Sender: TObject);
var
  M: TSystemMetrics;
  BarColor: TColor;
begin
  M := FViewModel.LatestMetrics;
  if M.CpuUsagePercent > 80.0 then
    BarColor := FColors.Danger
  else if M.CpuUsagePercent > 50.0 then
    BarColor := FColors.Warning
  else
    BarColor := FColors.Accent;

  DrawMetricCard(pbCardCpu, 'CPU UTILIZATION',
    TUIUtils.FormatPercent(M.CpuUsagePercent),
    'Across logical cores',
    M.CpuUsagePercent, BarColor, FViewModel.CpuHistory.ToArray);
end;

procedure TMainForm.pbCardRamPaint(Sender: TObject);
var
  M: TSystemMetrics;
begin
  M := FViewModel.LatestMetrics;
  DrawMetricCard(pbCardRam, 'MEMORY LOAD',
    Format('%d%% (%s)', [M.MemoryLoadPercent, TUIUtils.FormatMegabytes(M.UsedPhysicalMB)]),
    Format('%s free / %s total', [TUIUtils.FormatMegabytes(M.AvailablePhysicalMB), TUIUtils.FormatMegabytes(M.TotalPhysicalMB)]),
    M.MemoryLoadPercent, FColors.Accent, FViewModel.RamHistory.ToArray);
end;

procedure TMainForm.pbCardDiskPaint(Sender: TObject);
var
  M: TSystemMetrics;
begin
  M := FViewModel.LatestMetrics;
  DrawMetricCard(pbCardDisk, 'SYSTEM STORAGE',
    Format('%.1f%% Used', [M.DiskUsagePercent]),
    Format('%.1f GB Free of %.1f GB', [M.FreeDiskGB, M.TotalDiskGB]),
    M.DiskUsagePercent, FColors.Success, nil);
end;

procedure TMainForm.pbCardUptimePaint(Sender: TObject);
var
  M: TSystemMetrics;
begin
  M := FViewModel.LatestMetrics;
  DrawMetricCard(pbCardUptime, 'SYSTEM UPTIME',
    TUIUtils.FormatDuration(M.UptimeSeconds),
    Format('%d active processes', [M.ActiveProcessCount]),
    -1, FColors.Accent, nil);
end;

procedure TMainForm.btnToggleMonitorClick(Sender: TObject);
begin
  FViewModel.ToggleMonitoring;
  if FViewModel.IsMonitoring then
  begin
    btnToggleMonitor.Caption := 'Pause';
    lblStatusIndicator.Caption := 'Status: Active';
    lblStatusIndicator.Font.Color := FColors.Success;
  end
  else
  begin
    btnToggleMonitor.Caption := 'Resume';
    lblStatusIndicator.Caption := 'Status: Paused';
    lblStatusIndicator.Font.Color := FColors.Warning;
  end;
end;

procedure TMainForm.UpdateSortIndicators;
var
  I: Integer;
begin
  for I := 0 to lvProcesses.Columns.Count - 1 do
  begin
    if I > High(BaseColumnCaptions) then Break;
    if I = FViewModel.SortColumn then
    begin
      if FViewModel.SortAscending then
        lvProcesses.Columns[I].Caption := BaseColumnCaptions[I] + ' ' + AscArrow
      else
        lvProcesses.Columns[I].Caption := BaseColumnCaptions[I] + ' ' + DescArrow;
    end
    else
      lvProcesses.Columns[I].Caption := BaseColumnCaptions[I];
  end;
end;

{$IFDEF FPC}
procedure TMainForm.lvProcessesColumnClick(Sender: TObject; Column: TListColumn);
begin
  // SetSort re-filters and fires OnProcessesUpdated, which refreshes the list
  FViewModel.SetSort(Column.Index);
  UpdateSortIndicators;
end;
{$ELSE}
procedure TMainForm.lvProcessesColumnClick(Sender: TObject; Column: TListColumn;
  var CanClick: Boolean);
begin
  FViewModel.SetSort(Column.Index);
  UpdateSortIndicators;
end;
{$ENDIF}

procedure TMainForm.SwitchView(const AView: TAppView);
var
  IsDash: Boolean;
begin
  FActiveView := AView;
  IsDash := (AView = avDashboard);

  pnlMetricsGrid.Visible := IsDash;

  if IsDash then
  begin
    lblPageTitle.Caption := 'System Performance';
    lblFooterStatus.Caption := 'Dashboard view';
  end
  else
  begin
    lblPageTitle.Caption := 'Process Inspector';
    lblFooterStatus.Caption := 'Inspector view - type to filter processes';
    edtSearch.SetFocus;
  end;
  lblFooterStatus.Font.Color := FColors.TextSecondary;

  // Highlight the active nav button
  if IsDash then
  begin
    btnNavDashboard.Font.Color := FColors.Accent;
    btnNavProcesses.Font.Color := FColors.SidebarText;
  end
  else
  begin
    btnNavDashboard.Font.Color := FColors.SidebarText;
    btnNavProcesses.Font.Color := FColors.Accent;
  end;
end;

procedure TMainForm.btnNavDashboardClick(Sender: TObject);
begin
  SwitchView(avDashboard);
end;

procedure TMainForm.btnNavProcessesClick(Sender: TObject);
begin
  SwitchView(avInspector);
end;

procedure TMainForm.btnNavThemeToggleClick(Sender: TObject);
begin
  FViewModel.ToggleTheme;
end;

procedure TMainForm.edtSearchChange(Sender: TObject);
begin
  FViewModel.SetSearchFilter(edtSearch.Text);
end;

procedure TMainForm.btnExportSnapshotClick(Sender: TObject);
begin
  SaveDialog.Filter := 'JSON Snapshot (*.json)|*.json|CSV Spreadsheet (*.csv)|*.csv';
  SaveDialog.FileName := Format('NovaTelemetry_%s.json', [FormatDateTime('yyyymmdd_hhnnss', Now)]);
  if SaveDialog.Execute then
  begin
    FViewModel.ExportReport(SaveDialog.FileName);
    lblPageTitle.Caption := 'Export Complete';
    lblFooterStatus.Caption := Format('Saved: %s', [SaveDialog.FileName]);
    lblFooterStatus.Font.Color := FColors.Success;
  end;
end;

end.
