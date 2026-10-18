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
  LCLType,
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
    FServiceContextMenu: TPopupMenu;

    lblTray: TLabel;
    imgHeaderLogo: TImage;
    pnlSearchBox: TPanel;
    cmbInterval: TComboBox;
    btnPinWindow: TButton;
    btnFilterAll: TButton;
    btnFilterMem: TButton;
    btnFilterCpu: TButton;
    btnFilterCrit: TButton;
    btnEndTask: TButton;
    btnToggleTree: TButton;
    btnInspectProc: TButton;
    btnRunTask: TButton;
    btnNavNetwork: TButton;
    btnNavServices: TButton;

    // Network view controls
    pnlNetworkSection: TPanel;
    pnlNetworkToolbar: TPanel;
    lblNetworkTitle: TLabel;
    lblNetworkCount: TLabel;
    pnlNetSearchBox: TPanel;
    edtNetworkSearch: TEdit;
    btnRefreshNetwork: TButton;
    lvNetwork: TListView;

    // Services view controls
    pnlServicesSection: TPanel;
    pnlServicesToolbar: TPanel;
    lblServicesTitle: TLabel;
    lblServicesCount: TLabel;
    pnlSvcSearchBox: TPanel;
    edtServiceSearch: TEdit;
    btnRefreshServices: TButton;
    btnSvcFilterAll: TButton;
    btnSvcFilterRunning: TButton;
    btnSvcFilterStopped: TButton;
    btnSvcStart: TButton;
    btnSvcStop: TButton;
    btnSvcRestart: TButton;
    lvServices: TListView;

    function GetSelectedProcess: TProcessItem;
    function GetSelectedService: TServiceItem;
    procedure SetupContextMenu;
    procedure SetupTableToolbarActions;
    procedure SetupProcessColumns;
    procedure SetupNetworkSection;
    procedure SetupServicesSection;
    procedure UpdateFilterChipStyles;
    procedure UpdateServiceFilterStyles;
    procedure TerminateSelectedProcess;
    procedure ShowProcessDetailsDialog;
    procedure ShowAffinityDialog;
    procedure ShowRunTaskDialog;
    procedure ShowCpuCoresDialog;

    procedure btnPinWindowClick(Sender: TObject);
    procedure btnFilterAllClick(Sender: TObject);
    procedure btnFilterMemClick(Sender: TObject);
    procedure btnFilterCpuClick(Sender: TObject);
    procedure btnFilterCritClick(Sender: TObject);
    procedure btnEndTaskClick(Sender: TObject);
    procedure btnToggleTreeClick(Sender: TObject);
    procedure btnInspectProcClick(Sender: TObject);
    procedure btnRunTaskClick(Sender: TObject);
    procedure pbCardCpuClick(Sender: TObject);
    procedure lvProcessesDblClick(Sender: TObject);
    procedure btnNavNetworkClick(Sender: TObject);
    procedure btnNavServicesClick(Sender: TObject);
    procedure mnuEndTaskClick(Sender: TObject);
    procedure mnuInspectClick(Sender: TObject);
    procedure mnuSetPriorityClick(Sender: TObject);
    procedure mnuSetAffinityClick(Sender: TObject);
    procedure mnuSuspendProcessClick(Sender: TObject);
    procedure mnuResumeProcessClick(Sender: TObject);
    procedure mnuRestartProcessClick(Sender: TObject);
    procedure mnuRunNewTaskClick(Sender: TObject);

    procedure mnuCopyNameClick(Sender: TObject);
    procedure mnuCopyPidClick(Sender: TObject);
    procedure mnuCopyDetailsClick(Sender: TObject);
    procedure mnuCopyPathClick(Sender: TObject);
    procedure mnuCopyCommandLineClick(Sender: TObject);
    procedure mnuCopyUserClick(Sender: TObject);
    procedure mnuOpenFileLocationClick(Sender: TObject);

    procedure btnSvcStartClick(Sender: TObject);
    procedure btnSvcStopClick(Sender: TObject);
    procedure btnSvcRestartClick(Sender: TObject);

    procedure OnMetricsUpdated(const AMetrics: TSystemMetrics);
    procedure OnProcessesUpdated(const AProcesses: TProcessList);
    procedure OnNetworkUpdated(const ANetwork: TNetworkConnectionList);
    procedure OnServicesUpdated(const AServices: TServiceList);
    procedure OnStatusMessage(const AMessage: string; const AIsError: Boolean);
    procedure OnThemeChanged(const ATheme: TAppTheme);

    procedure lvNetworkData(Sender: TObject; Item: TListItem);
    procedure lvServicesData(Sender: TObject; Item: TListItem);
    procedure edtNetworkSearchChange(Sender: TObject);
    procedure btnRefreshNetworkClick(Sender: TObject);
    procedure edtServiceSearchChange(Sender: TObject);
    procedure btnRefreshServicesClick(Sender: TObject);
    procedure btnSvcFilterAllClick(Sender: TObject);
    procedure btnSvcFilterRunningClick(Sender: TObject);
    procedure btnSvcFilterStoppedClick(Sender: TObject);
    procedure cmbIntervalChange(Sender: TObject);
    procedure cmbIntervalDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure SyncComboBoxHeight;
    procedure SearchBoxPaint(Sender: TObject);
    procedure SearchBoxClick(Sender: TObject);
    procedure SearchEditFocusChange(Sender: TObject);
    procedure lblTrayClick(Sender: TObject);
    procedure LoadHeaderLogo;
    procedure UpdateTitleBarTheme(const ADark: Boolean);

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
    procedure lvNetworkColumnClick(Sender: TObject; Column: TListColumn);
    procedure lvServicesColumnClick(Sender: TObject; Column: TListColumn);
    {$ELSE}
    procedure lvProcessesColumnClick(Sender: TObject; Column: TListColumn;
      var CanClick: Boolean);
    procedure lvNetworkColumnClick(Sender: TObject; Column: TListColumn;
      var CanClick: Boolean);
    procedure lvServicesColumnClick(Sender: TObject; Column: TListColumn;
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
  BaseColumnCaptions: array[0..9] of string =
    ('PID', 'Process Name', 'User Account', 'Arch', 'CPU %', 'Working Set (RAM)',
     'Disk I/O', 'Health Status', 'Active Threads', 'Image Path');
  BaseNetCaptions: array[0..5] of string =
    ('PID', 'Process Name', 'Protocol', 'Local Address:Port', 'Remote Address:Port', 'State');
  BaseSvcCaptions: array[0..4] of string =
    ('Service Name', 'Display Name', 'Status', 'PID', 'Type');

{ TMainForm }

procedure TMainForm.FormCreate(Sender: TObject);
begin
  DoubleBuffered := True;
  pnlSidebar.DoubleBuffered := True;
  pnlHeader.DoubleBuffered := True;
  pnlContent.DoubleBuffered := True;
  pnlProcessSection.DoubleBuffered := True;
  pnlMetricsGrid.DoubleBuffered := True;
  lvProcesses.DoubleBuffered := True;

  KeyPreview := True;
  OnKeyDown := FormKeyDown;

  Font.Name := 'Segoe UI';
  Font.Size := 9;
  ClientWidth := 1400;
  ClientHeight := 800;
  Constraints.MinWidth := 1120;
  Constraints.MinHeight := 680;
  FInitialized := False;
  FActiveView := avDashboard;

  FViewModel := TMainViewModel.Create;
  FViewModel.OnMetricsUpdated   := OnMetricsUpdated;
  FViewModel.OnProcessesUpdated := OnProcessesUpdated;
  FViewModel.OnNetworkUpdated   := OnNetworkUpdated;
  FViewModel.OnServicesUpdated  := OnServicesUpdated;
  FViewModel.OnStatusMessage    := OnStatusMessage;
  FViewModel.OnThemeChanged     := OnThemeChanged;

  {$IFDEF FPC}
  lvProcesses.ColumnClick := True; // LCL gates header clicks on this flag
  {$ENDIF}
  lvProcesses.OnColumnClick := lvProcessesColumnClick;
  lvProcesses.OnDblClick := lvProcessesDblClick;

  // Owner-data (virtual) list: rows are served from the ViewModel on demand.
  lvProcesses.OwnerData := True;
  lvProcesses.OnData := lvProcessesData;

  // Header Logo & Page Title
  imgHeaderLogo := TImage.Create(Self);
  imgHeaderLogo.Parent := pnlHeader;
  imgHeaderLogo.SetBounds(22, 16, 32, 32);
  imgHeaderLogo.Stretch := True;
  imgHeaderLogo.Proportional := True;
  imgHeaderLogo.Transparent := True;
  LoadHeaderLogo;
  lblPageTitle.SetBounds(62, 18, 260, 28);

  // Configure Header Actions (Search, Polling Interval, Pin, Pause/Resume, Export)
  pnlHeaderActions.Width := 600;

  // Wrap edtSearch in a 28px custom-bordered panel so text and placeholder
  // are vertically centered (6px top/bottom pad) with 10px left margin space
  pnlSearchBox := TPanel.Create(Self);
  pnlSearchBox.Parent := pnlHeaderActions;
  pnlSearchBox.BevelOuter := bvNone;
  pnlSearchBox.DoubleBuffered := True;
  pnlSearchBox.SetBounds(16, 18, 190, 28);
  pnlSearchBox.Cursor := crIBeam;
  pnlSearchBox.OnPaint := SearchBoxPaint;
  pnlSearchBox.OnClick := SearchBoxClick;

  edtSearch.Parent := pnlSearchBox;
  edtSearch.BorderStyle := bsNone;
  edtSearch.AutoSize := False;
  edtSearch.Font.Name := 'Segoe UI';
  edtSearch.Font.Size := 9;
  edtSearch.SetBounds(10, 6, 172, 16);
  edtSearch.OnEnter := SearchEditFocusChange;
  edtSearch.OnExit := SearchEditFocusChange;

  cmbInterval := TComboBox.Create(Self);
  cmbInterval.Parent := pnlHeaderActions;
  cmbInterval.Style := csOwnerDrawFixed;
  cmbInterval.AutoSize := False;
  cmbInterval.ItemHeight := 22;
  cmbInterval.Font.Name := 'Segoe UI';
  cmbInterval.Font.Size := 9;
  cmbInterval.SetBounds(214, 18, 110, 28);
  cmbInterval.Items.Add('0.5s (Fast)');
  cmbInterval.Items.Add('1.0s');
  cmbInterval.Items.Add('1.5s (Normal)');
  cmbInterval.Items.Add('2.5s');
  cmbInterval.Items.Add('5.0s (Eco)');
  cmbInterval.ItemIndex := 2;
  cmbInterval.OnChange := cmbIntervalChange;
  cmbInterval.OnDrawItem := cmbIntervalDrawItem;
  cmbInterval.Hint := 'Telemetry Polling Interval';
  cmbInterval.ShowHint := True;

  btnPinWindow := TButton.Create(Self);
  btnPinWindow.Parent := pnlHeaderActions;
  btnPinWindow.SetBounds(332, 18, 54, 28);
  btnPinWindow.Caption := 'Pin';
  btnPinWindow.Hint := 'Toggle Always on Top (Ctrl+P)';
  btnPinWindow.ShowHint := True;
  btnPinWindow.OnClick := btnPinWindowClick;

  btnToggleMonitor.SetBounds(394, 18, 88, 28);
  btnExportSnapshot.SetBounds(490, 18, 94, 28);

  // Minimize-to-tray: decoupling caption to TLabel eliminates Win32 UXTheme dark-panel text bug
  chkTray.Caption := '';
  chkTray.SetBounds(20, 8, 20, 20);

  lblTray := TLabel.Create(Self);
  lblTray.Parent := pnlNavBottom;
  lblTray.SetBounds(44, 9, 150, 18);
  lblTray.Caption := 'Minimize to tray';
  lblTray.Font.Name := 'Segoe UI';
  lblTray.Font.Size := 9;
  lblTray.Font.Style := [fsBold];
  lblTray.Cursor := crHandPoint;
  lblTray.OnClick := lblTrayClick;

  // Sidebar navigation: Network and Services tabs
  btnNavNetwork := TButton.Create(Self);
  btnNavNetwork.Parent := pnlSidebar;
  btnNavNetwork.SetBounds(12, 168, 196, 38);
  btnNavNetwork.Align := alTop;
  btnNavNetwork.BorderSpacing.Left := 12;
  btnNavNetwork.BorderSpacing.Top := 4;
  btnNavNetwork.BorderSpacing.Right := 12;
  btnNavNetwork.BorderSpacing.Bottom := 4;
  btnNavNetwork.Caption := '  Network Sockets';
  btnNavNetwork.OnClick := btnNavNetworkClick;

  btnNavServices := TButton.Create(Self);
  btnNavServices.Parent := pnlSidebar;
  btnNavServices.SetBounds(12, 210, 196, 38);
  btnNavServices.Align := alTop;
  btnNavServices.BorderSpacing.Left := 12;
  btnNavServices.BorderSpacing.Top := 4;
  btnNavServices.BorderSpacing.Right := 12;
  btnNavServices.BorderSpacing.Bottom := 4;
  btnNavServices.Caption := '  Windows Services';
  btnNavServices.OnClick := btnNavServicesClick;

  btnNavExport.Top := 260;
  btnNavThemeToggle.Top := 310;

  SetupProcessColumns;
  SetupContextMenu;
  SetupTableToolbarActions;
  SetupNetworkSection;
  SetupServicesSection;

  pbCardCpu.Cursor := crHandPoint;
  pbCardCpu.Hint := 'Click to inspect per-logical-core CPU utilization breakdown';
  pbCardCpu.ShowHint := True;
  pbCardCpu.OnClick := pbCardCpuClick;

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
  UpdateServiceFilterStyles;
end;

procedure TMainForm.SetupTableToolbarActions;
begin
  lblTableTitle.Caption := 'Active Tasks';
  lblTableTitle.SetBounds(16, 10, 100, 20);

  btnFilterAll := TButton.Create(Self);
  btnFilterAll.Parent := pnlTableToolbar;
  btnFilterAll.SetBounds(135, 7, 46, 26);
  btnFilterAll.Caption := '[All]';
  btnFilterAll.Hint := 'Show all active processes (Ctrl+1)';
  btnFilterAll.ShowHint := True;
  btnFilterAll.OnClick := btnFilterAllClick;

  btnFilterMem := TButton.Create(Self);
  btnFilterMem.Parent := pnlTableToolbar;
  btnFilterMem.SetBounds(187, 7, 142, 26);
  btnFilterMem.Caption := 'Heavy RAM (>400MB)';
  btnFilterMem.Hint := 'Filter processes consuming >400MB RAM (Ctrl+2)';
  btnFilterMem.ShowHint := True;
  btnFilterMem.OnClick := btnFilterMemClick;

  btnFilterCpu := TButton.Create(Self);
  btnFilterCpu.Parent := pnlTableToolbar;
  btnFilterCpu.SetBounds(335, 7, 118, 26);
  btnFilterCpu.Caption := 'Active CPU (>2%)';
  btnFilterCpu.Hint := 'Filter processes actively using >2% CPU (Ctrl+3)';
  btnFilterCpu.ShowHint := True;
  btnFilterCpu.OnClick := btnFilterCpuClick;

  btnFilterCrit := TButton.Create(Self);
  btnFilterCrit.Parent := pnlTableToolbar;
  btnFilterCrit.SetBounds(459, 7, 68, 26);
  btnFilterCrit.Caption := 'Alerts';
  btnFilterCrit.Hint := 'Filter processes in Warning or Critical state (Ctrl+4)';
  btnFilterCrit.ShowHint := True;
  btnFilterCrit.OnClick := btnFilterCritClick;

  btnEndTask := TButton.Create(Self);
  btnEndTask.Parent := pnlTableToolbar;
  btnEndTask.SetBounds(533, 7, 85, 26);
  btnEndTask.Caption := 'End Task';
  btnEndTask.Hint := 'Terminate selected process (Del)';
  btnEndTask.ShowHint := True;
  btnEndTask.OnClick := btnEndTaskClick;

  btnToggleTree := TButton.Create(Self);
  btnToggleTree.Parent := pnlTableToolbar;
  btnToggleTree.SetBounds(624, 7, 85, 26);
  btnToggleTree.Caption := 'Tree View';
  btnToggleTree.Hint := 'Toggle Hierarchical Tree / Flat View';
  btnToggleTree.ShowHint := True;
  btnToggleTree.OnClick := btnToggleTreeClick;

  btnInspectProc := TButton.Create(Self);
  btnInspectProc.Parent := pnlTableToolbar;
  btnInspectProc.SetBounds(715, 7, 78, 26);
  btnInspectProc.Caption := 'Inspect...';
  btnInspectProc.Hint := 'Inspect selected process details, modules, and sockets (Enter)';
  btnInspectProc.ShowHint := True;
  btnInspectProc.OnClick := btnInspectProcClick;

  btnRunTask := TButton.Create(Self);
  btnRunTask.Parent := pnlTableToolbar;
  btnRunTask.SetBounds(799, 7, 86, 26);
  btnRunTask.Caption := 'Run Task...';
  btnRunTask.Hint := 'Create and launch a new task or command (Ctrl+N)';
  btnRunTask.ShowHint := True;
  btnRunTask.OnClick := btnRunTaskClick;
end;

procedure TMainForm.SetupProcessColumns;
var
  Col: TListColumn;
begin
  lvProcesses.Columns.Clear;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'PID';
  Col.Width := 70;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Process Name';
  Col.Width := 195;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'User Account';
  Col.Width := 140;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Arch';
  Col.Width := 55;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'CPU %';
  Col.Width := 68;
  Col.Alignment := taRightJustify;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Working Set (RAM)';
  Col.Width := 125;
  Col.Alignment := taRightJustify;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Disk I/O';
  Col.Width := 85;
  Col.Alignment := taRightJustify;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Health Status';
  Col.Width := 100;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Active Threads';
  Col.Width := 85;
  Col.Alignment := taRightJustify;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Image Path';
  Col.Width := 250;
end;

procedure TMainForm.SetupNetworkSection;
var
  Col: TListColumn;
begin
  pnlNetworkSection := TPanel.Create(Self);
  pnlNetworkSection.Parent := pnlContent;
  pnlNetworkSection.Align := alClient;
  pnlNetworkSection.BevelOuter := bvNone;
  pnlNetworkSection.Visible := False;

  pnlNetworkToolbar := TPanel.Create(Self);
  pnlNetworkToolbar.Parent := pnlNetworkSection;
  pnlNetworkToolbar.Align := alTop;
  pnlNetworkToolbar.Height := 40;
  pnlNetworkToolbar.BevelOuter := bvNone;

  lblNetworkTitle := TLabel.Create(Self);
  lblNetworkTitle.Parent := pnlNetworkToolbar;
  lblNetworkTitle.SetBounds(16, 10, 200, 20);
  lblNetworkTitle.Caption := 'Active TCP/UDP Sockets';
  lblNetworkTitle.Font.Style := [fsBold];

  pnlNetSearchBox := TPanel.Create(Self);
  pnlNetSearchBox.Parent := pnlNetworkToolbar;
  pnlNetSearchBox.BevelOuter := bvNone;
  pnlNetSearchBox.DoubleBuffered := True;
  pnlNetSearchBox.SetBounds(230, 7, 200, 26);
  pnlNetSearchBox.Cursor := crIBeam;
  pnlNetSearchBox.OnPaint := SearchBoxPaint;
  pnlNetSearchBox.OnClick := SearchBoxClick;

  edtNetworkSearch := TEdit.Create(Self);
  edtNetworkSearch.Parent := pnlNetSearchBox;
  edtNetworkSearch.BorderStyle := bsNone;
  edtNetworkSearch.AutoSize := False;
  edtNetworkSearch.Font.Name := 'Segoe UI';
  edtNetworkSearch.Font.Size := 9;
  edtNetworkSearch.SetBounds(10, 5, 182, 16);
  edtNetworkSearch.TextHint := 'Search IP, port, process...';
  edtNetworkSearch.OnChange := edtNetworkSearchChange;
  edtNetworkSearch.OnEnter := SearchEditFocusChange;
  edtNetworkSearch.OnExit := SearchEditFocusChange;

  btnRefreshNetwork := TButton.Create(Self);
  btnRefreshNetwork.Parent := pnlNetworkToolbar;
  btnRefreshNetwork.SetBounds(440, 7, 75, 26);
  btnRefreshNetwork.Caption := 'Refresh';
  btnRefreshNetwork.OnClick := btnRefreshNetworkClick;

  lblNetworkCount := TLabel.Create(Self);
  lblNetworkCount.Parent := pnlNetworkToolbar;
  lblNetworkCount.SetBounds(530, 12, 380, 20);
  lblNetworkCount.Caption := '0 connections';

  lvNetwork := TListView.Create(Self);
  lvNetwork.Parent := pnlNetworkSection;
  lvNetwork.Align := alClient;
  lvNetwork.DoubleBuffered := True;
  lvNetwork.ViewStyle := vsReport;
  lvNetwork.GridLines := True;
  lvNetwork.RowSelect := True;
  lvNetwork.ReadOnly := True;
  lvNetwork.OwnerData := True;
  lvNetwork.BorderStyle := bsNone;
  lvNetwork.OnData := lvNetworkData;
  {$IFDEF FPC}
  lvNetwork.ColumnClick := True;
  {$ENDIF}
  lvNetwork.OnColumnClick := lvNetworkColumnClick;

  Col := lvNetwork.Columns.Add;
  Col.Caption := 'PID';
  Col.Width := 70;

  Col := lvNetwork.Columns.Add;
  Col.Caption := 'Process Name';
  Col.Width := 160;

  Col := lvNetwork.Columns.Add;
  Col.Caption := 'Protocol';
  Col.Width := 65;

  Col := lvNetwork.Columns.Add;
  Col.Caption := 'Local Address:Port';
  Col.Width := 180;

  Col := lvNetwork.Columns.Add;
  Col.Caption := 'Remote Address:Port';
  Col.Width := 180;

  Col := lvNetwork.Columns.Add;
  Col.Caption := 'State';
  Col.Width := 120;
end;

procedure TMainForm.SetupServicesSection;
var
  Col: TListColumn;
  SvcMenuItem: TMenuItem;
begin
  pnlServicesSection := TPanel.Create(Self);
  pnlServicesSection.Parent := pnlContent;
  pnlServicesSection.Align := alClient;
  pnlServicesSection.BevelOuter := bvNone;
  pnlServicesSection.Visible := False;

  pnlServicesToolbar := TPanel.Create(Self);
  pnlServicesToolbar.Parent := pnlServicesSection;
  pnlServicesToolbar.Align := alTop;
  pnlServicesToolbar.Height := 40;
  pnlServicesToolbar.BevelOuter := bvNone;

  lblServicesTitle := TLabel.Create(Self);
  lblServicesTitle.Parent := pnlServicesToolbar;
  lblServicesTitle.SetBounds(16, 10, 150, 20);
  lblServicesTitle.Caption := 'Windows Services';
  lblServicesTitle.Font.Style := [fsBold];

  btnSvcFilterAll := TButton.Create(Self);
  btnSvcFilterAll.Parent := pnlServicesToolbar;
  btnSvcFilterAll.SetBounds(175, 7, 50, 26);
  btnSvcFilterAll.Caption := '[All]';
  btnSvcFilterAll.OnClick := btnSvcFilterAllClick;

  btnSvcFilterRunning := TButton.Create(Self);
  btnSvcFilterRunning.Parent := pnlServicesToolbar;
  btnSvcFilterRunning.SetBounds(229, 7, 70, 26);
  btnSvcFilterRunning.Caption := 'Running';
  btnSvcFilterRunning.OnClick := btnSvcFilterRunningClick;

  btnSvcFilterStopped := TButton.Create(Self);
  btnSvcFilterStopped.Parent := pnlServicesToolbar;
  btnSvcFilterStopped.SetBounds(303, 7, 70, 26);
  btnSvcFilterStopped.Caption := 'Stopped';
  btnSvcFilterStopped.OnClick := btnSvcFilterStoppedClick;

  pnlSvcSearchBox := TPanel.Create(Self);
  pnlSvcSearchBox.Parent := pnlServicesToolbar;
  pnlSvcSearchBox.BevelOuter := bvNone;
  pnlSvcSearchBox.DoubleBuffered := True;
  pnlSvcSearchBox.SetBounds(385, 7, 180, 26);
  pnlSvcSearchBox.Cursor := crIBeam;
  pnlSvcSearchBox.OnPaint := SearchBoxPaint;
  pnlSvcSearchBox.OnClick := SearchBoxClick;

  edtServiceSearch := TEdit.Create(Self);
  edtServiceSearch.Parent := pnlSvcSearchBox;
  edtServiceSearch.BorderStyle := bsNone;
  edtServiceSearch.AutoSize := False;
  edtServiceSearch.Font.Name := 'Segoe UI';
  edtServiceSearch.Font.Size := 9;
  edtServiceSearch.SetBounds(10, 5, 162, 16);
  edtServiceSearch.TextHint := 'Search services...';
  edtServiceSearch.OnChange := edtServiceSearchChange;
  edtServiceSearch.OnEnter := SearchEditFocusChange;
  edtServiceSearch.OnExit := SearchEditFocusChange;

  btnRefreshServices := TButton.Create(Self);
  btnRefreshServices.Parent := pnlServicesToolbar;
  btnRefreshServices.SetBounds(575, 7, 75, 26);
  btnRefreshServices.Caption := 'Refresh';
  btnRefreshServices.OnClick := btnRefreshServicesClick;

  btnSvcStart := TButton.Create(Self);
  btnSvcStart.Parent := pnlServicesToolbar;
  btnSvcStart.SetBounds(658, 7, 62, 26);
  btnSvcStart.Caption := 'Start';
  btnSvcStart.Hint := 'Start selected Windows service';
  btnSvcStart.ShowHint := True;
  btnSvcStart.OnClick := btnSvcStartClick;

  btnSvcStop := TButton.Create(Self);
  btnSvcStop.Parent := pnlServicesToolbar;
  btnSvcStop.SetBounds(724, 7, 62, 26);
  btnSvcStop.Caption := 'Stop';
  btnSvcStop.Hint := 'Stop selected Windows service';
  btnSvcStop.ShowHint := True;
  btnSvcStop.OnClick := btnSvcStopClick;

  btnSvcRestart := TButton.Create(Self);
  btnSvcRestart.Parent := pnlServicesToolbar;
  btnSvcRestart.SetBounds(790, 7, 68, 26);
  btnSvcRestart.Caption := 'Restart';
  btnSvcRestart.Hint := 'Restart selected Windows service';
  btnSvcRestart.ShowHint := True;
  btnSvcRestart.OnClick := btnSvcRestartClick;

  lblServicesCount := TLabel.Create(Self);
  lblServicesCount.Parent := pnlServicesToolbar;
  lblServicesCount.SetBounds(868, 12, 160, 20);
  lblServicesCount.Caption := '0 services';

  lvServices := TListView.Create(Self);
  lvServices.Parent := pnlServicesSection;
  lvServices.Align := alClient;
  lvServices.DoubleBuffered := True;
  lvServices.ViewStyle := vsReport;
  lvServices.GridLines := True;
  lvServices.RowSelect := True;
  lvServices.ReadOnly := True;
  lvServices.OwnerData := True;
  lvServices.BorderStyle := bsNone;
  lvServices.OnData := lvServicesData;
  {$IFDEF FPC}
  lvServices.ColumnClick := True;
  {$ENDIF}
  lvServices.OnColumnClick := lvServicesColumnClick;

  FServiceContextMenu := TPopupMenu.Create(Self);
  SvcMenuItem := TMenuItem.Create(FServiceContextMenu);
  SvcMenuItem.Caption := 'Start Service';
  SvcMenuItem.OnClick := btnSvcStartClick;
  FServiceContextMenu.Items.Add(SvcMenuItem);

  SvcMenuItem := TMenuItem.Create(FServiceContextMenu);
  SvcMenuItem.Caption := 'Stop Service';
  SvcMenuItem.OnClick := btnSvcStopClick;
  FServiceContextMenu.Items.Add(SvcMenuItem);

  SvcMenuItem := TMenuItem.Create(FServiceContextMenu);
  SvcMenuItem.Caption := 'Restart Service';
  SvcMenuItem.OnClick := btnSvcRestartClick;
  FServiceContextMenu.Items.Add(SvcMenuItem);

  SvcMenuItem := TMenuItem.Create(FServiceContextMenu);
  SvcMenuItem.Caption := '-';
  FServiceContextMenu.Items.Add(SvcMenuItem);

  SvcMenuItem := TMenuItem.Create(FServiceContextMenu);
  SvcMenuItem.Caption := 'Refresh Services';
  SvcMenuItem.OnClick := btnRefreshServicesClick;
  FServiceContextMenu.Items.Add(SvcMenuItem);

  lvServices.PopupMenu := FServiceContextMenu;

  Col := lvServices.Columns.Add;
  Col.Caption := 'Service Name';
  Col.Width := 180;

  Col := lvServices.Columns.Add;
  Col.Caption := 'Display Name';
  Col.Width := 270;

  Col := lvServices.Columns.Add;
  Col.Caption := 'Status';
  Col.Width := 90;

  Col := lvServices.Columns.Add;
  Col.Caption := 'PID';
  Col.Width := 70;
  Col.Alignment := taRightJustify;

  Col := lvServices.Columns.Add;
  Col.Caption := 'Type';
  Col.Width := 100;
end;

procedure TMainForm.UpdateServiceFilterStyles;
begin
  if btnSvcFilterAll = nil then Exit;
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
  Item, SubMenu, PrioItem: TMenuItem;
begin
  FContextMenu := TPopupMenu.Create(Self);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Inspect Process Details...' + #9 + 'Enter';
  Item.Default := True;
  Item.OnClick := mnuInspectClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := '-';
  FContextMenu.Items.Add(Item);

  SubMenu := TMenuItem.Create(FContextMenu);
  SubMenu.Caption := 'Set Priority';
  FContextMenu.Items.Add(SubMenu);

  PrioItem := TMenuItem.Create(FContextMenu);
  PrioItem.Caption := 'Realtime';
  PrioItem.Tag := $00000100;
  PrioItem.OnClick := mnuSetPriorityClick;
  SubMenu.Add(PrioItem);

  PrioItem := TMenuItem.Create(FContextMenu);
  PrioItem.Caption := 'High';
  PrioItem.Tag := $00000080;
  PrioItem.OnClick := mnuSetPriorityClick;
  SubMenu.Add(PrioItem);

  PrioItem := TMenuItem.Create(FContextMenu);
  PrioItem.Caption := 'Above Normal';
  PrioItem.Tag := $00008000;
  PrioItem.OnClick := mnuSetPriorityClick;
  SubMenu.Add(PrioItem);

  PrioItem := TMenuItem.Create(FContextMenu);
  PrioItem.Caption := 'Normal';
  PrioItem.Tag := $00000020;
  PrioItem.OnClick := mnuSetPriorityClick;
  SubMenu.Add(PrioItem);

  PrioItem := TMenuItem.Create(FContextMenu);
  PrioItem.Caption := 'Below Normal';
  PrioItem.Tag := $00004000;
  PrioItem.OnClick := mnuSetPriorityClick;
  SubMenu.Add(PrioItem);

  PrioItem := TMenuItem.Create(FContextMenu);
  PrioItem.Caption := 'Idle (Low)';
  PrioItem.Tag := $00000040;
  PrioItem.OnClick := mnuSetPriorityClick;
  SubMenu.Add(PrioItem);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Set CPU Affinity...';
  Item.OnClick := mnuSetAffinityClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Suspend Process';
  Item.OnClick := mnuSuspendProcessClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Resume Process';
  Item.OnClick := mnuResumeProcessClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Restart Process';
  Item.OnClick := mnuRestartProcessClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := '-';
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Copy Process Name';
  Item.OnClick := mnuCopyNameClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Copy Process ID (PID)';
  Item.OnClick := mnuCopyPidClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Copy Image Path';
  Item.OnClick := mnuCopyPathClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Copy Command Line';
  Item.OnClick := mnuCopyCommandLineClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Copy User Account';
  Item.OnClick := mnuCopyUserClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Copy Details (CSV)';
  Item.OnClick := mnuCopyDetailsClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Open File Location';
  Item.OnClick := mnuOpenFileLocationClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := '-';
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'End Task' + #9 + 'Del';
  Item.OnClick := mnuEndTaskClick;
  FContextMenu.Items.Add(Item);

  Item := TMenuItem.Create(FContextMenu);
  Item.Caption := 'Run New Task...' + #9 + 'Ctrl+N';
  Item.OnClick := mnuRunNewTaskClick;
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

function TMainForm.GetSelectedService: TServiceItem;
begin
  Result := nil;
  if Assigned(lvServices) and Assigned(lvServices.Selected) and
     (lvServices.Selected.Index >= 0) and
     (lvServices.Selected.Index < FViewModel.Services.Count) then
  begin
    Result := FViewModel.Services[lvServices.Selected.Index];
  end;
end;

procedure TMainForm.btnInspectProcClick(Sender: TObject);
begin
  ShowProcessDetailsDialog;
end;

procedure TMainForm.btnRunTaskClick(Sender: TObject);
begin
  ShowRunTaskDialog;
end;

procedure TMainForm.pbCardCpuClick(Sender: TObject);
begin
  ShowCpuCoresDialog;
end;

procedure TMainForm.lvProcessesDblClick(Sender: TObject);
begin
  ShowProcessDetailsDialog;
end;

procedure TMainForm.mnuInspectClick(Sender: TObject);
begin
  ShowProcessDetailsDialog;
end;

procedure TMainForm.mnuSetPriorityClick(Sender: TObject);
var
  Proc: TProcessItem;
  Mnu: TMenuItem;
begin
  if not (Sender is TMenuItem) then Exit;
  Mnu := TMenuItem(Sender);
  Proc := GetSelectedProcess;
  if Proc = nil then
  begin
    lblFooterStatus.Caption := 'Select a process first to change its priority class';
    lblFooterStatus.Font.Color := FColors.Warning;
    Exit;
  end;
  FViewModel.SetProcessPriority(Proc.Id, Cardinal(Mnu.Tag), Mnu.Caption);
end;

procedure TMainForm.mnuSetAffinityClick(Sender: TObject);
begin
  ShowAffinityDialog;
end;

procedure TMainForm.mnuSuspendProcessClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Proc = nil then Exit;
  if (Proc.Id <= 4) or (Proc.Id = GetCurrentProcessId) then
  begin
    MessageDlg('Protected Process',
      Format('Process "%s" (PID: %d) cannot be suspended.', [Proc.Name, Proc.Id]),
      mtWarning, [mbOK], 0);
    Exit;
  end;
  FViewModel.SuspendResumeProcess(Proc.Id, True);
end;

procedure TMainForm.mnuResumeProcessClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Proc = nil then Exit;
  FViewModel.SuspendResumeProcess(Proc.Id, False);
end;

procedure TMainForm.mnuRestartProcessClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Proc = nil then
  begin
    lblFooterStatus.Caption := 'Select a process first to restart';
    lblFooterStatus.Font.Color := FColors.Warning;
    Exit;
  end;
  if (Proc.Id <= 4) or (Proc.Id = GetCurrentProcessId) then
  begin
    MessageDlg('Protected Process',
      Format('Process "%s" (PID: %d) cannot be restarted.', [Proc.Name, Proc.Id]),
      mtWarning, [mbOK], 0);
    Exit;
  end;
  if MessageDlg('Restart Process Confirmation',
    Format('Are you sure you want to terminate and relaunch "%s" (PID: %d)?', [Proc.Name, Proc.Id]),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FViewModel.RestartProcess(Proc.Id);
  end;
end;

procedure TMainForm.mnuRunNewTaskClick(Sender: TObject);
begin
  ShowRunTaskDialog;
end;

procedure TMainForm.btnSvcStartClick(Sender: TObject);
var
  Svc: TServiceItem;
begin
  Svc := GetSelectedService;
  if Svc = nil then
  begin
    lblFooterStatus.Caption := 'Select a service from the table first';
    lblFooterStatus.Font.Color := FColors.Warning;
    Exit;
  end;
  FViewModel.ControlServiceByName(Svc.ServiceName, 0);
end;

procedure TMainForm.btnSvcStopClick(Sender: TObject);
var
  Svc: TServiceItem;
begin
  Svc := GetSelectedService;
  if Svc = nil then
  begin
    lblFooterStatus.Caption := 'Select a service from the table first';
    lblFooterStatus.Font.Color := FColors.Warning;
    Exit;
  end;
  if MessageDlg('Stop Windows Service',
    Format('Are you sure you want to stop service "%s" (%s)?', [Svc.DisplayName, Svc.ServiceName]),
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FViewModel.ControlServiceByName(Svc.ServiceName, 1);
  end;
end;

procedure TMainForm.btnSvcRestartClick(Sender: TObject);
var
  Svc: TServiceItem;
begin
  Svc := GetSelectedService;
  if Svc = nil then
  begin
    lblFooterStatus.Caption := 'Select a service from the table first';
    lblFooterStatus.Font.Color := FColors.Warning;
    Exit;
  end;
  FViewModel.ControlServiceByName(Svc.ServiceName, 2);
end;

procedure TMainForm.ShowProcessDetailsDialog;
var
  Proc: TProcessItem;
  Dlg: TForm;
  PnlTop, PnlBottom: TPanel;
  LblTitle, LblSub: TLabel;
  MemoReport: TMemo;
  BtnCopy, BtnClose: TButton;
  Modules: TStringList;
  Report: TStringList;
  I, NetMatches, SvcMatches: Integer;
  NetItem: TNetworkConnectionItem;
  SvcItem: TServiceItem;
  HandleNote, GdiNote, UserNote: string;
begin
  Proc := GetSelectedProcess;
  if Proc = nil then
  begin
    lblFooterStatus.Caption := 'Select a process first to inspect details';
    lblFooterStatus.Font.Color := FColors.Warning;
    Exit;
  end;

  Report := TStringList.Create;
  Modules := FViewModel.GetProcessModules(Proc.Id);
  try
    if Proc.HandleCount > 5000 then
      HandleNote := '  [! High Handle Count — Potential Handle Leak]'
    else
      HandleNote := '';
    if Proc.GdiObjects > 2000 then
      GdiNote := '  [! High GDI Count — Potential GDI Leak]'
    else
      GdiNote := '';
    if Proc.UserObjects > 2000 then
      UserNote := '  [! High USER Count — Potential USER Leak]'
    else
      UserNote := '';

    Report.Add('====================================================================');
    Report.Add(Format('  PROCESS TELEMETRY & EXECUTION METADATA — %s (PID %d)', [Proc.Name, Proc.Id]));
    Report.Add('====================================================================');
    Report.Add(Format('  Process Name       : %s', [Proc.Name]));
    if Proc.Description <> '' then
      Report.Add(Format('  File Description   : %s', [Proc.Description]));
    if Proc.CompanyName <> '' then
      Report.Add(Format('  Digital Publisher  : %s', [Proc.CompanyName]));
    if Proc.FileVersion <> '' then
      Report.Add(Format('  File Version       : %s', [Proc.FileVersion]));
    Report.Add(Format('  Process ID (PID)   : %d', [Proc.Id]));
    Report.Add(Format('  Parent PID         : %d', [Proc.ParentId]));
    Report.Add(Format('  User Account       : %s', [Proc.UserName]));
    Report.Add(Format('  Architecture       : %s', [Proc.Architecture]));
    Report.Add(Format('  Priority Class     : %s', [Proc.PriorityText]));
    Report.Add(Format('  Health Status      : %s', [TUIUtils.StatusToString(Proc.Status)]));
    Report.Add(Format('  CPU Utilization    : %s', [TUIUtils.FormatPercent(Proc.CpuSharePercent)]));
    Report.Add(Format('  Working Set (RAM)  : %s', [TUIUtils.FormatMegabytes(Proc.MemoryWorkingSetMB)]));
    Report.Add(Format('  Disk I/O Rate      : %s', [TUIUtils.FormatRateKBps(Proc.DiskIoKBps)]));
    Report.Add(Format('  Active Threads     : %d', [Proc.ThreadCount]));
    Report.Add(Format('  Kernel Handles     : %d%s', [Proc.HandleCount, HandleNote]));
    Report.Add(Format('  GDI Objects        : %d%s', [Proc.GdiObjects, GdiNote]));
    Report.Add(Format('  USER Objects       : %d%s', [Proc.UserObjects, UserNote]));
    if Proc.ImagePath <> '' then
      Report.Add(Format('  Executable Path    : %s', [Proc.ImagePath]))
    else
      Report.Add('  Executable Path    : [Kernel / Protected System Image]');
    if Proc.CommandLine <> '' then
      Report.Add(Format('  Command Line       : %s', [Proc.CommandLine]))
    else
      Report.Add('  Command Line       : [Restricted / Empty]');
    Report.Add('');

    Report.Add('====================================================================');
    Report.Add('  ACTIVE TCP/UDP NETWORK ENDPOINTS FOR THIS PID');
    Report.Add('====================================================================');
    NetMatches := 0;
    for I := 0 to FViewModel.NetworkConnections.Count - 1 do
    begin
      NetItem := FViewModel.NetworkConnections[I];
      if NetItem.ProcessId = Proc.Id then
      begin
        Inc(NetMatches);
        if NetItem.RemotePort > 0 then
          Report.Add(Format('  [%s] %s:%d -> %s:%d (%s)',
            [NetItem.Protocol, NetItem.LocalAddress, NetItem.LocalPort,
             NetItem.RemoteAddress, NetItem.RemotePort, NetItem.State]))
        else
          Report.Add(Format('  [%s] %s:%d (%s)',
            [NetItem.Protocol, NetItem.LocalAddress, NetItem.LocalPort, NetItem.State]));
      end;
    end;
    if NetMatches = 0 then
      Report.Add('  No active TCP/UDP sockets bound to this PID.');
    Report.Add('');

    Report.Add('====================================================================');
    Report.Add('  HOSTED WINDOWS SERVICES FOR THIS PID');
    Report.Add('====================================================================');
    SvcMatches := 0;
    for I := 0 to FViewModel.Services.Count - 1 do
    begin
      SvcItem := FViewModel.Services[I];
      if SvcItem.ProcessId = Proc.Id then
      begin
        Inc(SvcMatches);
        Report.Add(Format('  • %s (%s) — [%s]',
          [SvcItem.ServiceName, SvcItem.DisplayName, SvcItem.StateString]));
      end;
    end;
    if SvcMatches = 0 then
      Report.Add('  No Windows services hosted in this process.');
    Report.Add('');

    Report.Add('====================================================================');
    Report.Add(Format('  LOADED MODULES / DLLS (%d loaded)', [Modules.Count]));
    Report.Add('====================================================================');
    if Modules.Count > 0 then
    begin
      for I := 0 to Modules.Count - 1 do
        Report.Add(Format('  [%3d] %s', [I + 1, Modules[I]]));
    end
    else
      Report.Add('  [Module enumeration restricted by OS protection or kernel process]');

    Dlg := TForm.CreateNew(Self);
    try
      Dlg.Caption := Format('Process Inspector — %s (PID %d)', [Proc.Name, Proc.Id]);
      Dlg.Position := poMainFormCenter;
      Dlg.Width := 740;
      Dlg.Height := 560;
      Dlg.Color := FColors.Background;
      Dlg.Font.Name := 'Segoe UI';
      Dlg.Font.Size := 9;

      PnlTop := TPanel.Create(Dlg);
      PnlTop.Parent := Dlg;
      PnlTop.Align := alTop;
      PnlTop.Height := 58;
      PnlTop.BevelOuter := bvNone;
      PnlTop.Color := FColors.Surface;

      LblTitle := TLabel.Create(Dlg);
      LblTitle.Parent := PnlTop;
      LblTitle.SetBounds(16, 10, 680, 22);
      LblTitle.Caption := Format('%s  (PID: %d  ·  %s  ·  Priority: %s)',
        [Proc.Name, Proc.Id, Proc.Architecture, Proc.PriorityText]);
      LblTitle.Font.Size := 11;
      LblTitle.Font.Style := [fsBold];
      LblTitle.Font.Color := FColors.TextPrimary;

      LblSub := TLabel.Create(Dlg);
      LblSub.Parent := PnlTop;
      LblSub.SetBounds(16, 34, 680, 18);
      LblSub.Caption := Format('CPU: %s   |   RAM: %s   |   Handles: %d   |   GDI/USER: %d/%d   |   User: %s',
        [TUIUtils.FormatPercent(Proc.CpuSharePercent),
         TUIUtils.FormatMegabytes(Proc.MemoryWorkingSetMB),
         Proc.HandleCount, Proc.GdiObjects, Proc.UserObjects, Proc.UserName]);
      LblSub.Font.Size := 9;
      LblSub.Font.Color := FColors.Accent;

      PnlBottom := TPanel.Create(Dlg);
      PnlBottom.Parent := Dlg;
      PnlBottom.Align := alBottom;
      PnlBottom.Height := 44;
      PnlBottom.BevelOuter := bvNone;
      PnlBottom.Color := FColors.Surface;

      BtnCopy := TButton.Create(Dlg);
      BtnCopy.Parent := PnlBottom;
      BtnCopy.SetBounds(16, 8, 150, 28);
      BtnCopy.Caption := 'Copy Full Report';
      BtnCopy.ModalResult := mrYes;

      BtnClose := TButton.Create(Dlg);
      BtnClose.Parent := PnlBottom;
      BtnClose.SetBounds(634, 8, 90, 28);
      BtnClose.Anchors := [akTop, akRight];
      BtnClose.Caption := 'Close';
      BtnClose.Cancel := True;
      BtnClose.Default := True;
      BtnClose.ModalResult := mrOk;

      MemoReport := TMemo.Create(Dlg);
      MemoReport.Parent := Dlg;
      MemoReport.Align := alClient;
      MemoReport.BorderSpacing.Around := 12;
      MemoReport.ReadOnly := True;
      MemoReport.ScrollBars := ssBoth;
      MemoReport.WordWrap := False;
      MemoReport.Color := FColors.SurfaceCard;
      MemoReport.Font.Name := 'Consolas';
      MemoReport.Font.Size := 9;
      MemoReport.Font.Color := FColors.TextPrimary;
      MemoReport.Lines.Assign(Report);

      if Dlg.ShowModal = mrYes then
      begin
        Clipboard.AsText := Report.Text;
        lblFooterStatus.Caption := Format('Copied full diagnostic report for %s (PID %d)', [Proc.Name, Proc.Id]);
      end;
    finally
      Dlg.Free;
    end;
  finally
    Modules.Free;
    Report.Free;
  end;
end;

procedure TMainForm.ShowAffinityDialog;
var
  Proc: TProcessItem;
  ProcMask, SysMask, NewMask, BitMask: NativeUInt;
  Dlg: TForm;
  PnlTop, PnlBody, PnlBottom: TPanel;
  LblTitle, LblSub: TLabel;
  ChkBoxes: array[0..63] of TCheckBox;
  I, CoreCount, ColIdx, RowIdx, RowsNeeded: Integer;
  BtnApply, BtnCancel: TButton;
begin
  Proc := GetSelectedProcess;
  if Proc = nil then
  begin
    lblFooterStatus.Caption := 'Select a process first to configure CPU core affinity';
    lblFooterStatus.Font.Color := FColors.Warning;
    Exit;
  end;

  if not FViewModel.GetProcessAffinity(Proc.Id, ProcMask, SysMask) then
  begin
    MessageDlg('Access Denied',
      Format('Unable to query CPU affinity mask for "%s" (PID %d).'#13#10 +
             'Protected system processes or elevated processes require Administrator privileges.',
             [Proc.Name, Proc.Id]),
      mtWarning, [mbOK], 0);
    Exit;
  end;

  CoreCount := 0;
  for I := 0 to (SizeOf(NativeUInt) * 8) - 1 do
  begin
    BitMask := NativeUInt(1) shl I;
    if (SysMask and BitMask) <> 0 then
      CoreCount := I + 1;
  end;
  if CoreCount < 1 then CoreCount := 1;
  if CoreCount > 64 then CoreCount := 64;
  RowsNeeded := (CoreCount + 3) div 4;

  Dlg := TForm.CreateNew(Self);
  try
    Dlg.Caption := Format('Processor Affinity — %s (PID %d)', [Proc.Name, Proc.Id]);
    Dlg.Position := poMainFormCenter;
    Dlg.BorderStyle := bsDialog;
    Dlg.Width := 480;
    Dlg.Height := 148 + (RowsNeeded * 30);
    Dlg.Color := FColors.Background;
    Dlg.Font.Name := 'Segoe UI';
    Dlg.Font.Size := 9;

    PnlTop := TPanel.Create(Dlg);
    PnlTop.Parent := Dlg;
    PnlTop.Align := alTop;
    PnlTop.Height := 54;
    PnlTop.BevelOuter := bvNone;
    PnlTop.Color := FColors.Surface;

    LblTitle := TLabel.Create(Dlg);
    LblTitle.Parent := PnlTop;
    LblTitle.SetBounds(16, 8, 440, 20);
    LblTitle.Caption := Format('Logical Processor Affinity — %s (PID %d)', [Proc.Name, Proc.Id]);
    LblTitle.Font.Size := 10;
    LblTitle.Font.Style := [fsBold];
    LblTitle.Font.Color := FColors.TextPrimary;

    LblSub := TLabel.Create(Dlg);
    LblSub.Parent := PnlTop;
    LblSub.SetBounds(16, 30, 440, 18);
    LblSub.Caption := Format('Select which logical CPUs "%s" is permitted to execute on (Current Mask: 0x%x)', [Proc.Name, ProcMask]);
    LblSub.Font.Size := 8;
    LblSub.Font.Color := FColors.TextSecondary;

    PnlBottom := TPanel.Create(Dlg);
    PnlBottom.Parent := Dlg;
    PnlBottom.Align := alBottom;
    PnlBottom.Height := 44;
    PnlBottom.BevelOuter := bvNone;
    PnlBottom.Color := FColors.Surface;

    BtnApply := TButton.Create(Dlg);
    BtnApply.Parent := PnlBottom;
    BtnApply.SetBounds(256, 8, 104, 28);
    BtnApply.Caption := 'Apply Affinity';
    BtnApply.Default := True;
    BtnApply.ModalResult := mrOk;

    BtnCancel := TButton.Create(Dlg);
    BtnCancel.Parent := PnlBottom;
    BtnCancel.SetBounds(368, 8, 88, 28);
    BtnCancel.Caption := 'Cancel';
    BtnCancel.Cancel := True;
    BtnCancel.ModalResult := mrCancel;

    PnlBody := TPanel.Create(Dlg);
    PnlBody.Parent := Dlg;
    PnlBody.Align := alClient;
    PnlBody.BevelOuter := bvNone;
    PnlBody.Color := FColors.Background;

    for I := 0 to 63 do
      ChkBoxes[I] := nil;

    for I := 0 to CoreCount - 1 do
    begin
      ColIdx := I mod 4;
      RowIdx := I div 4;
      BitMask := NativeUInt(1) shl I;
      ChkBoxes[I] := TCheckBox.Create(Dlg);
      ChkBoxes[I].Parent := PnlBody;
      ChkBoxes[I].SetBounds(20 + (ColIdx * 110), 14 + (RowIdx * 28), 100, 22);
      ChkBoxes[I].Caption := Format('CPU %d', [I]);
      ChkBoxes[I].Enabled := (SysMask and BitMask) <> 0;
      ChkBoxes[I].Checked := (ProcMask and BitMask) <> 0;
      ChkBoxes[I].Font.Color := FColors.TextPrimary;
    end;

    if Dlg.ShowModal = mrOk then
    begin
      NewMask := 0;
      for I := 0 to CoreCount - 1 do
      begin
        if Assigned(ChkBoxes[I]) and ChkBoxes[I].Checked then
          NewMask := NewMask or (NativeUInt(1) shl I);
      end;
      if NewMask = 0 then
      begin
        MessageDlg('Invalid Affinity Mask',
          'A process must be allowed to execute on at least one logical processor.',
          mtWarning, [mbOK], 0);
        Exit;
      end;
      FViewModel.SetProcessAffinity(Proc.Id, NewMask);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.ShowRunTaskDialog;
var
  Dlg: TForm;
  PnlTop, PnlBody, PnlBottom: TPanel;
  LblTitle, LblSub, LblOpen: TLabel;
  EdtCmd: TEdit;
  ChkAdmin: TCheckBox;
  BtnRun, BtnCancel: TButton;
  CmdText: string;
begin
  Dlg := TForm.CreateNew(Self);
  try
    Dlg.Caption := 'Create New Task';
    Dlg.Position := poMainFormCenter;
    Dlg.BorderStyle := bsDialog;
    Dlg.Width := 460;
    Dlg.Height := 210;
    Dlg.Color := FColors.Background;
    Dlg.Font.Name := 'Segoe UI';
    Dlg.Font.Size := 9;

    PnlTop := TPanel.Create(Dlg);
    PnlTop.Parent := Dlg;
    PnlTop.Align := alTop;
    PnlTop.Height := 52;
    PnlTop.BevelOuter := bvNone;
    PnlTop.Color := FColors.Surface;

    LblTitle := TLabel.Create(Dlg);
    LblTitle.Parent := PnlTop;
    LblTitle.SetBounds(16, 8, 420, 20);
    LblTitle.Caption := 'Run New Task';
    LblTitle.Font.Size := 10;
    LblTitle.Font.Style := [fsBold];
    LblTitle.Font.Color := FColors.TextPrimary;

    LblSub := TLabel.Create(Dlg);
    LblSub.Parent := PnlTop;
    LblSub.SetBounds(16, 28, 420, 18);
    LblSub.Caption := 'Type the name of a program, folder, document, or command with arguments.';
    LblSub.Font.Size := 8;
    LblSub.Font.Color := FColors.TextSecondary;

    PnlBottom := TPanel.Create(Dlg);
    PnlBottom.Parent := Dlg;
    PnlBottom.Align := alBottom;
    PnlBottom.Height := 44;
    PnlBottom.BevelOuter := bvNone;
    PnlBottom.Color := FColors.Surface;

    BtnRun := TButton.Create(Dlg);
    BtnRun.Parent := PnlBottom;
    BtnRun.SetBounds(252, 8, 90, 28);
    BtnRun.Caption := 'Run Task';
    BtnRun.Default := True;
    BtnRun.ModalResult := mrOk;

    BtnCancel := TButton.Create(Dlg);
    BtnCancel.Parent := PnlBottom;
    BtnCancel.SetBounds(350, 8, 88, 28);
    BtnCancel.Caption := 'Cancel';
    BtnCancel.Cancel := True;
    BtnCancel.ModalResult := mrCancel;

    PnlBody := TPanel.Create(Dlg);
    PnlBody.Parent := Dlg;
    PnlBody.Align := alClient;
    PnlBody.BevelOuter := bvNone;
    PnlBody.Color := FColors.Background;

    LblOpen := TLabel.Create(Dlg);
    LblOpen.Parent := PnlBody;
    LblOpen.SetBounds(16, 18, 48, 20);
    LblOpen.Caption := 'Open:';
    LblOpen.Font.Style := [fsBold];
    LblOpen.Font.Color := FColors.TextPrimary;

    EdtCmd := TEdit.Create(Dlg);
    EdtCmd.Parent := PnlBody;
    EdtCmd.SetBounds(68, 15, 368, 24);
    EdtCmd.Color := FColors.SurfaceCard;
    EdtCmd.Font.Color := FColors.TextPrimary;
    EdtCmd.TextHint := 'e.g. cmd.exe, powershell.exe -NoLogo, notepad.exe...';

    ChkAdmin := TCheckBox.Create(Dlg);
    ChkAdmin.Parent := PnlBody;
    ChkAdmin.SetBounds(68, 48, 368, 22);
    ChkAdmin.Caption := 'Create this task with administrative privileges (UAC Elevation)';
    ChkAdmin.Font.Color := FColors.TextSecondary;

    if Dlg.ShowModal = mrOk then
    begin
      CmdText := Trim(EdtCmd.Text);
      if CmdText <> '' then
        FViewModel.RunNewTask(CmdText, ChkAdmin.Checked);
    end;
  finally
    Dlg.Free;
  end;
end;

procedure TMainForm.ShowCpuCoresDialog;
var
  M: TSystemMetrics;
  Dlg: TForm;
  PnlTop, PnlBottom: TPanel;
  LblTitle, LblSub: TLabel;
  MemoCores: TMemo;
  BtnCopy, BtnClose: TButton;
  Report: TStringList;
  I, FilledBars, EmptyBars: Integer;
  CorePct: Single;
  BarStr: string;
begin
  M := FViewModel.LatestMetrics;
  Report := TStringList.Create;
  try
    Report.Add('====================================================================');
    Report.Add(Format('  LOGICAL PROCESSOR UTILIZATION BREAKDOWN (%d Logical Cores)', [Length(M.CoreUsages)]));
    Report.Add('====================================================================');
    Report.Add(Format('  Aggregate Package CPU Load : %s', [TUIUtils.FormatPercent(M.CpuUsagePercent)]));
    Report.Add(Format('  Active Processes / Threads : %d processes  |  %d threads', [M.ActiveProcessCount, M.ThreadCount]));
    Report.Add('--------------------------------------------------------------------');
    if Length(M.CoreUsages) > 0 then
    begin
      for I := 0 to High(M.CoreUsages) do
      begin
        CorePct := M.CoreUsages[I];
        FilledBars := Round((CorePct / 100.0) * 28);
        if FilledBars < 0 then FilledBars := 0;
        if FilledBars > 28 then FilledBars := 28;
        EmptyBars := 28 - FilledBars;
        BarStr := StringOfChar('#', FilledBars) + StringOfChar('.', EmptyBars);
        Report.Add(Format('  CPU Core #%2d  [%s]  %6.1f%%', [I, BarStr, CorePct]));
      end;
    end
    else
      Report.Add('  [Per-core performance telemetry initializing...]');
    Report.Add('====================================================================');

    Dlg := TForm.CreateNew(Self);
    try
      Dlg.Caption := 'Per-Core CPU Utilization Breakdown';
      Dlg.Position := poMainFormCenter;
      Dlg.Width := 600;
      Dlg.Height := 460;
      Dlg.Color := FColors.Background;
      Dlg.Font.Name := 'Segoe UI';
      Dlg.Font.Size := 9;

      PnlTop := TPanel.Create(Dlg);
      PnlTop.Parent := Dlg;
      PnlTop.Align := alTop;
      PnlTop.Height := 56;
      PnlTop.BevelOuter := bvNone;
      PnlTop.Color := FColors.Surface;

      LblTitle := TLabel.Create(Dlg);
      LblTitle.Parent := PnlTop;
      LblTitle.SetBounds(16, 8, 550, 22);
      LblTitle.Caption := Format('Logical Processor Telemetry (%d Cores)', [Length(M.CoreUsages)]);
      LblTitle.Font.Size := 11;
      LblTitle.Font.Style := [fsBold];
      LblTitle.Font.Color := FColors.TextPrimary;

      LblSub := TLabel.Create(Dlg);
      LblSub.Parent := PnlTop;
      LblSub.SetBounds(16, 32, 550, 18);
      LblSub.Caption := Format('Total CPU Load: %s   |   SystemProcessorPerformanceInformation (ntdll.dll)',
        [TUIUtils.FormatPercent(M.CpuUsagePercent)]);
      LblSub.Font.Size := 9;
      LblSub.Font.Color := FColors.Accent;

      PnlBottom := TPanel.Create(Dlg);
      PnlBottom.Parent := Dlg;
      PnlBottom.Align := alBottom;
      PnlBottom.Height := 44;
      PnlBottom.BevelOuter := bvNone;
      PnlBottom.Color := FColors.Surface;

      BtnCopy := TButton.Create(Dlg);
      BtnCopy.Parent := PnlBottom;
      BtnCopy.SetBounds(16, 8, 140, 28);
      BtnCopy.Caption := 'Copy Snapshot';
      BtnCopy.ModalResult := mrYes;

      BtnClose := TButton.Create(Dlg);
      BtnClose.Parent := PnlBottom;
      BtnClose.SetBounds(490, 8, 90, 28);
      BtnClose.Anchors := [akTop, akRight];
      BtnClose.Caption := 'Close';
      BtnClose.Cancel := True;
      BtnClose.Default := True;
      BtnClose.ModalResult := mrOk;

      MemoCores := TMemo.Create(Dlg);
      MemoCores.Parent := Dlg;
      MemoCores.Align := alClient;
      MemoCores.BorderSpacing.Around := 12;
      MemoCores.ReadOnly := True;
      MemoCores.ScrollBars := ssVertical;
      MemoCores.WordWrap := False;
      MemoCores.Color := FColors.SurfaceCard;
      MemoCores.Font.Name := 'Consolas';
      MemoCores.Font.Size := 9;
      MemoCores.Font.Color := FColors.TextPrimary;
      MemoCores.Lines.Assign(Report);

      if Dlg.ShowModal = mrYes then
      begin
        Clipboard.AsText := Report.Text;
        lblFooterStatus.Caption := 'Copied per-core CPU telemetry snapshot to clipboard';
      end;
    finally
      Dlg.Free;
    end;
  finally
    Report.Free;
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

procedure TMainForm.mnuCopyPathClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Assigned(Proc) and (Proc.ImagePath <> '') then
  begin
    Clipboard.AsText := Proc.ImagePath;
    lblFooterStatus.Caption := Format('Copied path to clipboard: %s', [Proc.ImagePath]);
  end;
end;

procedure TMainForm.mnuCopyCommandLineClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Assigned(Proc) then
  begin
    if Proc.CommandLine <> '' then
    begin
      Clipboard.AsText := Proc.CommandLine;
      lblFooterStatus.Caption := Format('Copied command line to clipboard: %s', [Proc.CommandLine]);
    end
    else if Proc.ImagePath <> '' then
    begin
      Clipboard.AsText := Proc.ImagePath;
      lblFooterStatus.Caption := Format('Copied executable path to clipboard: %s', [Proc.ImagePath]);
    end;
  end;
end;

procedure TMainForm.mnuCopyUserClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Assigned(Proc) and (Proc.UserName <> '') then
  begin
    Clipboard.AsText := Proc.UserName;
    lblFooterStatus.Caption := Format('Copied user account to clipboard: %s', [Proc.UserName]);
  end;
end;

procedure TMainForm.mnuOpenFileLocationClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Assigned(Proc) and (Proc.ImagePath <> '') then
  begin
    ShellExecute(0, 'open', 'explorer.exe', PChar('/select,"' + Proc.ImagePath + '"'), nil, SW_SHOWNORMAL);
    lblFooterStatus.Caption := Format('Opened file location: %s', [Proc.ImagePath]);
  end;
end;

procedure TMainForm.mnuCopyDetailsClick(Sender: TObject);
var
  Proc: TProcessItem;
begin
  Proc := GetSelectedProcess;
  if Assigned(Proc) then
  begin
    Clipboard.AsText := Format('%d,%s,%s,%s,%.2f,%.1f,%s,%d',
      [Proc.Id, Proc.Name, Proc.UserName, Proc.Architecture, Proc.MemoryWorkingSetMB,
       Proc.DiskIoKBps, TUIUtils.StatusToString(Proc.Status), Proc.ThreadCount]);
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
  else if (Key = VK_RETURN) and lvProcesses.Focused then
  begin
    ShowProcessDetailsDialog;
    Key := 0;
  end
  else if (ssCtrl in Shift) and (Key = Word('N')) then
  begin
    ShowRunTaskDialog;
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
const
  LVM_SETEXTENDEDLISTVIEWSTYLE = $1036;
  LVS_EX_DOUBLEBUFFER = $00010000;
begin
  {$IFDEF MSWINDOWS}
  // Native Win32 Double-Buffering: eliminates all listview background-erase flashing
  if lvProcesses.HandleAllocated then
    SendMessage(lvProcesses.Handle, LVM_SETEXTENDEDLISTVIEWSTYLE, LVS_EX_DOUBLEBUFFER, LVS_EX_DOUBLEBUFFER);
  if Assigned(lvNetwork) and lvNetwork.HandleAllocated then
    SendMessage(lvNetwork.Handle, LVM_SETEXTENDEDLISTVIEWSTYLE, LVS_EX_DOUBLEBUFFER, LVS_EX_DOUBLEBUFFER);
  if Assigned(lvServices) and lvServices.HandleAllocated then
    SendMessage(lvServices.Handle, LVM_SETEXTENDEDLISTVIEWSTYLE, LVS_EX_DOUBLEBUFFER, LVS_EX_DOUBLEBUFFER);

  UpdateTitleBarTheme(FViewModel.CurrentTheme = atDark);
  SyncComboBoxHeight;
  {$ENDIF}

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

  SyncComboBoxHeight;
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

  chkTray.Color := AColors.SidebarBg;
  if Assigned(lblTray) then
  begin
    lblTray.Font.Color := AColors.SidebarText;
    lblTray.Font.Style := [fsBold];
  end;

  pnlFooter.Color := AColors.Surface;
  lblFooterStatus.Font.Color := AColors.TextSecondary;
  lblFooterTime.Font.Color := AColors.TextSecondary;

  if Assigned(pnlSearchBox) then
  begin
    pnlSearchBox.Color := AColors.SurfaceCard;
    pnlSearchBox.Invalidate;
  end;
  edtSearch.Color := AColors.SurfaceCard;
  edtSearch.Font.Color := AColors.TextPrimary;

  if Assigned(cmbInterval) then
  begin
    cmbInterval.Color := AColors.SurfaceCard;
    cmbInterval.Font.Color := AColors.TextPrimary;
    SyncComboBoxHeight;
    cmbInterval.Invalidate;
  end;

  if Assigned(pnlNetworkSection) then
  begin
    pnlNetworkSection.Color := AColors.Surface;
    pnlNetworkToolbar.Color := AColors.Surface;
    lblNetworkTitle.Font.Color := AColors.TextPrimary;
    lblNetworkCount.Font.Color := AColors.TextSecondary;
    if Assigned(pnlNetSearchBox) then
    begin
      pnlNetSearchBox.Color := AColors.SurfaceCard;
      pnlNetSearchBox.Invalidate;
    end;
    edtNetworkSearch.Color := AColors.SurfaceCard;
    edtNetworkSearch.Font.Color := AColors.TextPrimary;
    lvNetwork.Color := AColors.Surface;
    lvNetwork.Font.Color := AColors.TextPrimary;
  end;

  if Assigned(pnlServicesSection) then
  begin
    pnlServicesSection.Color := AColors.Surface;
    pnlServicesToolbar.Color := AColors.Surface;
    lblServicesTitle.Font.Color := AColors.TextPrimary;
    lblServicesCount.Font.Color := AColors.TextSecondary;
    if Assigned(pnlSvcSearchBox) then
    begin
      pnlSvcSearchBox.Color := AColors.SurfaceCard;
      pnlSvcSearchBox.Invalidate;
    end;
    edtServiceSearch.Color := AColors.SurfaceCard;
    edtServiceSearch.Font.Color := AColors.TextPrimary;
    lvServices.Color := AColors.Surface;
    lvServices.Font.Color := AColors.TextPrimary;
  end;

  // Preserve nav button highlight across theme changes
  btnNavDashboard.Font.Color := AColors.SidebarText;
  btnNavProcesses.Font.Color := AColors.SidebarText;
  if Assigned(btnNavNetwork) then btnNavNetwork.Font.Color := AColors.SidebarText;
  if Assigned(btnNavServices) then btnNavServices.Font.Color := AColors.SidebarText;

  case FActiveView of
    avDashboard: btnNavDashboard.Font.Color := AColors.Accent;
    avInspector: btnNavProcesses.Font.Color := AColors.Accent;
    avNetwork: if Assigned(btnNavNetwork) then btnNavNetwork.Font.Color := AColors.Accent;
    avServices: if Assigned(btnNavServices) then btnNavServices.Font.Color := AColors.Accent;
  end;

  pbCardCpu.Invalidate;
  pbCardRam.Invalidate;
  pbCardDisk.Invalidate;
  pbCardUptime.Invalidate;
  lvProcesses.Invalidate;
  if Assigned(lvNetwork) then lvNetwork.Invalidate;
  if Assigned(lvServices) then lvServices.Invalidate;
end;

procedure TMainForm.OnMetricsUpdated(const AMetrics: TSystemMetrics);
begin
  pbCardCpu.Invalidate;
  pbCardRam.Invalidate;
  pbCardDisk.Invalidate;
  pbCardUptime.Invalidate;

  lblFooterTime.Caption := Format('Net: ↓ %s  ↑ %s   |   Updated: %s',
    [TUIUtils.FormatRateKBps(AMetrics.NetDownloadKBps),
     TUIUtils.FormatRateKBps(AMetrics.NetUploadKBps),
     FormatDateTime('hh:nn:ss', AMetrics.Timestamp)]);

  if Assigned(lblNetworkCount) and Assigned(lvNetwork) then
    lblNetworkCount.Caption := Format('%d connections   ·   ↓ %s   ↑ %s',
      [lvNetwork.Items.Count,
       TUIUtils.FormatRateKBps(AMetrics.NetDownloadKBps),
       TUIUtils.FormatRateKBps(AMetrics.NetUploadKBps)]);
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
  UpdateTitleBarTheme(ATheme = atDark);
  if ATheme = atDark then
    btnNavThemeToggle.Caption := 'Theme: Dark'
  else
    btnNavThemeToggle.Caption := 'Theme: Light';
end;

procedure TMainForm.RefreshProcessList(const AProcesses: TProcessList);
var
  CountChanged: Boolean;
begin
  CountChanged := (lvProcesses.Items.Count <> AProcesses.Count);
  if CountChanged then
  begin
    lvProcesses.Items.Count := AProcesses.Count;
    lblProcessCount.Caption := Format('%d processes active', [AProcesses.Count]);
    StretchLastColumn;
  end;
  // Repaint visible rows smoothly via native double-buffering without background erase flash
  lvProcesses.Invalidate;
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
  if FViewModel.IsTreeView and (ProcItem.TreeLevel > 0) then
    Item.SubItems.Add(StringOfChar(' ', ProcItem.TreeLevel * 3) + '└─ ' + ProcItem.Name)
  else
    Item.SubItems.Add(ProcItem.Name);
  Item.SubItems.Add(ProcItem.UserName);
  Item.SubItems.Add(ProcItem.Architecture);
  Item.SubItems.Add(TUIUtils.FormatPercent(ProcItem.CpuSharePercent));
  Item.SubItems.Add(TUIUtils.FormatMegabytes(ProcItem.MemoryWorkingSetMB));
  Item.SubItems.Add(TUIUtils.FormatRateKBps(ProcItem.DiskIoKBps));
  Item.SubItems.Add(TUIUtils.StatusToString(ProcItem.Status));
  Item.SubItems.Add(IntToStr(ProcItem.ThreadCount));
  Item.SubItems.Add(ProcItem.ImagePath);
end;

procedure TMainForm.DrawMetricCard(const APaintBox: TPaintBox; const ATitle: string;
  const APrimaryVal: string; const ASecondaryVal: string;
  const APercent: Single; const ABarColor: TColor;
  const AHistory: TSingleDynArray);
var
  C: TCanvas;
  R, BarR, SparkR: TRect;
  Y, MaxPrimaryWidth: Integer;
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
  if Length(AHistory) >= 2 then
  begin
    MaxPrimaryWidth := (R.Right - 92) - (R.Left + PadX);
    while (C.Font.Size > 11) and (C.TextWidth(APrimaryVal) > MaxPrimaryWidth) do
      C.Font.Size := C.Font.Size - 1;
  end;
  C.TextOut(R.Left + PadX, Y, APrimaryVal);
  Inc(Y, C.TextHeight(APrimaryVal) + LineGap);

  C.Font.Size := 8;
  C.Font.Style := [];
  C.Font.Color := FColors.TextSecondary;
  C.TextOut(R.Left + PadX, Y, ASecondaryVal);

  // Render rolling sparkline in the upper-right quadrant if history exists
  if Length(AHistory) >= 2 then
  begin
    SparkR := Rect(R.Right - 82, R.Top + 12, R.Right - 14, R.Bottom - 26);
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
  // SubItem comes 1-based from the Win32 notification: 7 = "Health Status"
  // (0 = PID caption, 1 = name, 2 = user, 3 = arch, 4 = CPU, 5 = RAM, 6 = Disk I/O, 7 = status)
  if SubItem = 7 then
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
  SubCaption: string;
begin
  M := FViewModel.LatestMetrics;
  if M.CpuUsagePercent > 80.0 then
    BarColor := FColors.Danger
  else if M.CpuUsagePercent > 50.0 then
    BarColor := FColors.Warning
  else
    BarColor := FColors.Accent;

  if Length(M.CoreUsages) > 0 then
    SubCaption := Format('Across %d logical cores · Click for cores', [Length(M.CoreUsages)])
  else
    SubCaption := 'Across logical cores';

  DrawMetricCard(pbCardCpu, 'CPU UTILIZATION',
    TUIUtils.FormatPercent(M.CpuUsagePercent),
    SubCaption,
    M.CpuUsagePercent, BarColor, FViewModel.CpuHistory.ToArray);
end;

procedure TMainForm.pbCardRamPaint(Sender: TObject);
var
  M: TSystemMetrics;
  RamPct: Single;
  BarColor: TColor;
begin
  M := FViewModel.LatestMetrics;
  if M.TotalPhysicalMB > 0 then
    RamPct := (M.UsedPhysicalMB * 100.0) / M.TotalPhysicalMB
  else
    RamPct := Single(M.MemoryLoadPercent);

  // Dynamic status color matching memory pressure
  if RamPct >= 85.0 then
    BarColor := FColors.Danger
  else if RamPct >= 70.0 then
    BarColor := FColors.Warning
  else
    BarColor := FColors.Accent;

  DrawMetricCard(pbCardRam, 'MEMORY LOAD',
    Format('%.1f%% (%s)', [RamPct, TUIUtils.FormatMegabytes(M.UsedPhysicalMB)]),
    Format('%s free of %s', [TUIUtils.FormatMegabytes(M.AvailablePhysicalMB), TUIUtils.FormatMegabytes(M.TotalPhysicalMB)]),
    RamPct, BarColor, FViewModel.RamHistory.ToArray);
end;

procedure TMainForm.pbCardDiskPaint(Sender: TObject);
var
  M: TSystemMetrics;
  BarColor: TColor;
begin
  M := FViewModel.LatestMetrics;
  if M.DiskUsagePercent >= 90.0 then
    BarColor := FColors.Danger
  else if M.DiskUsagePercent >= 75.0 then
    BarColor := FColors.Warning
  else
    BarColor := FColors.Accent;

  DrawMetricCard(pbCardDisk, 'SYSTEM STORAGE',
    Format('%.1f GB Free', [M.FreeDiskGB]),
    Format('%.1f GB Used (%.0f%%) · %.1f GB Total', [M.UsedDiskGB, M.DiskUsagePercent, M.TotalDiskGB]),
    M.DiskUsagePercent, BarColor);
end;

procedure TMainForm.pbCardUptimePaint(Sender: TObject);
var
  M: TSystemMetrics;
begin
  M := FViewModel.LatestMetrics;
  DrawMetricCard(pbCardUptime, 'SYSTEM UPTIME',
    TUIUtils.FormatDuration(M.UptimeSeconds),
    Format('%d active | %d threads', [M.ActiveProcessCount, M.ThreadCount]),
    100.0, FColors.Success, FViewModel.VitalityHistory.ToArray);
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
    if (not FViewModel.IsTreeView) and (I = FViewModel.SortColumn) then
    begin
      if FViewModel.SortAscending then
        lvProcesses.Columns[I].Caption := BaseColumnCaptions[I] + ' ' + AscArrow
      else
        lvProcesses.Columns[I].Caption := BaseColumnCaptions[I] + ' ' + DescArrow;
    end
    else
      lvProcesses.Columns[I].Caption := BaseColumnCaptions[I];
  end;

  if Assigned(lvNetwork) then
  begin
    for I := 0 to lvNetwork.Columns.Count - 1 do
    begin
      if I > High(BaseNetCaptions) then Break;
      if I = FViewModel.NetSortColumn then
      begin
        if FViewModel.NetSortAscending then
          lvNetwork.Columns[I].Caption := BaseNetCaptions[I] + ' ' + AscArrow
        else
          lvNetwork.Columns[I].Caption := BaseNetCaptions[I] + ' ' + DescArrow;
      end
      else
        lvNetwork.Columns[I].Caption := BaseNetCaptions[I];
    end;
  end;

  if Assigned(lvServices) then
  begin
    for I := 0 to lvServices.Columns.Count - 1 do
    begin
      if I > High(BaseSvcCaptions) then Break;
      if I = FViewModel.SvcSortColumn then
      begin
        if FViewModel.SvcSortAscending then
          lvServices.Columns[I].Caption := BaseSvcCaptions[I] + ' ' + AscArrow
        else
          lvServices.Columns[I].Caption := BaseSvcCaptions[I] + ' ' + DescArrow;
      end
      else
        lvServices.Columns[I].Caption := BaseSvcCaptions[I];
    end;
  end;
end;

{$IFDEF FPC}
procedure TMainForm.lvProcessesColumnClick(Sender: TObject; Column: TListColumn);
begin
  // SetSort re-filters and fires OnProcessesUpdated, which refreshes the list
  FViewModel.SetSort(Column.Index);
  if Assigned(btnToggleTree) then
  begin
    if FViewModel.IsTreeView then
      btnToggleTree.Caption := 'Flat View'
    else
      btnToggleTree.Caption := 'Tree View';
  end;
  UpdateSortIndicators;
end;

procedure TMainForm.lvNetworkColumnClick(Sender: TObject; Column: TListColumn);
begin
  FViewModel.SetNetworkSort(Column.Index);
  UpdateSortIndicators;
end;

procedure TMainForm.lvServicesColumnClick(Sender: TObject; Column: TListColumn);
begin
  FViewModel.SetServiceSort(Column.Index);
  UpdateSortIndicators;
end;
{$ELSE}
procedure TMainForm.lvProcessesColumnClick(Sender: TObject; Column: TListColumn;
  var CanClick: Boolean);
begin
  FViewModel.SetSort(Column.Index);
  if Assigned(btnToggleTree) then
  begin
    if FViewModel.IsTreeView then
      btnToggleTree.Caption := 'Flat View'
    else
      btnToggleTree.Caption := 'Tree View';
  end;
  UpdateSortIndicators;
end;

procedure TMainForm.lvNetworkColumnClick(Sender: TObject; Column: TListColumn;
  var CanClick: Boolean);
begin
  FViewModel.SetNetworkSort(Column.Index);
  UpdateSortIndicators;
end;

procedure TMainForm.lvServicesColumnClick(Sender: TObject; Column: TListColumn;
  var CanClick: Boolean);
begin
  FViewModel.SetServiceSort(Column.Index);
  UpdateSortIndicators;
end;
{$ENDIF}

procedure TMainForm.SwitchView(const AView: TAppView);
begin
  FActiveView := AView;
  pnlMetricsGrid.Visible := (AView = avDashboard);
  pnlProcessSection.Visible := (AView in [avDashboard, avInspector]);
  pnlNetworkSection.Visible := (AView = avNetwork);
  pnlServicesSection.Visible := (AView = avServices);

  case AView of
    avDashboard:
    begin
      lblPageTitle.Caption := 'System Performance';
      lblFooterStatus.Caption := 'Dashboard view';
    end;
    avInspector:
    begin
      lblPageTitle.Caption := 'Process Inspector';
      lblFooterStatus.Caption := 'Inspector view - type to filter processes';
      edtSearch.SetFocus;
    end;
    avNetwork:
    begin
      lblPageTitle.Caption := 'Network Sockets';
      lblFooterStatus.Caption := 'Network view - live TCP/UDP endpoints';
      edtNetworkSearch.SetFocus;
    end;
    avServices:
    begin
      lblPageTitle.Caption := 'Windows Services';
      lblFooterStatus.Caption := 'Services view - Win32 system services';
      edtServiceSearch.SetFocus;
    end;
  end;
  lblFooterStatus.Font.Color := FColors.TextSecondary;

  // Highlight the active nav button
  btnNavDashboard.Font.Color := FColors.SidebarText;
  btnNavProcesses.Font.Color := FColors.SidebarText;
  if Assigned(btnNavNetwork) then btnNavNetwork.Font.Color := FColors.SidebarText;
  if Assigned(btnNavServices) then btnNavServices.Font.Color := FColors.SidebarText;

  case AView of
    avDashboard: btnNavDashboard.Font.Color := FColors.Accent;
    avInspector: btnNavProcesses.Font.Color := FColors.Accent;
    avNetwork: if Assigned(btnNavNetwork) then btnNavNetwork.Font.Color := FColors.Accent;
    avServices: if Assigned(btnNavServices) then btnNavServices.Font.Color := FColors.Accent;
  end;

  FViewModel.SetActiveView(AView);
end;

procedure TMainForm.btnNavDashboardClick(Sender: TObject);
begin
  SwitchView(avDashboard);
end;

procedure TMainForm.btnNavProcessesClick(Sender: TObject);
begin
  SwitchView(avInspector);
end;

procedure TMainForm.btnNavNetworkClick(Sender: TObject);
begin
  SwitchView(avNetwork);
end;

procedure TMainForm.btnNavServicesClick(Sender: TObject);
begin
  SwitchView(avServices);
end;

procedure TMainForm.btnToggleTreeClick(Sender: TObject);
begin
  FViewModel.ToggleTreeView;
  if FViewModel.IsTreeView then
    btnToggleTree.Caption := 'Flat View'
  else
    btnToggleTree.Caption := 'Tree View';
  UpdateSortIndicators;
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

procedure TMainForm.OnNetworkUpdated(const ANetwork: TNetworkConnectionList);
begin
  if not Assigned(lvNetwork) then Exit;
  lvNetwork.Items.BeginUpdate;
  try
    lvNetwork.Items.Count := ANetwork.Count;
    lblNetworkCount.Caption := Format('%d connections', [ANetwork.Count]);
  finally
    lvNetwork.Items.EndUpdate;
  end;
end;

procedure TMainForm.OnServicesUpdated(const AServices: TServiceList);
begin
  if not Assigned(lvServices) then Exit;
  lvServices.Items.BeginUpdate;
  try
    lvServices.Items.Count := AServices.Count;
    lblServicesCount.Caption := Format('%d services', [AServices.Count]);
  finally
    lvServices.Items.EndUpdate;
  end;
end;

procedure TMainForm.lvNetworkData(Sender: TObject; Item: TListItem);
var
  NetItem: TNetworkConnectionItem;
begin
  if Item = nil then Exit;
  if (Item.Index < 0) or (Item.Index >= FViewModel.NetworkConnections.Count) then Exit;
  NetItem := FViewModel.NetworkConnections[Item.Index];
  Item.Caption := IntToStr(NetItem.ProcessId);
  Item.SubItems.Clear;
  Item.SubItems.Add(NetItem.ProcessName);
  Item.SubItems.Add(NetItem.Protocol);
  Item.SubItems.Add(Format('%s:%d', [NetItem.LocalAddress, NetItem.LocalPort]));
  if NetItem.RemotePort > 0 then
    Item.SubItems.Add(Format('%s:%d', [NetItem.RemoteAddress, NetItem.RemotePort]))
  else
    Item.SubItems.Add(NetItem.RemoteAddress);
  Item.SubItems.Add(NetItem.State);
end;

procedure TMainForm.lvServicesData(Sender: TObject; Item: TListItem);
var
  SvcItem: TServiceItem;
begin
  if Item = nil then Exit;
  if (Item.Index < 0) or (Item.Index >= FViewModel.Services.Count) then Exit;
  SvcItem := FViewModel.Services[Item.Index];
  Item.Caption := SvcItem.ServiceName;
  Item.SubItems.Clear;
  Item.SubItems.Add(SvcItem.DisplayName);
  Item.SubItems.Add(SvcItem.StateString);
  if SvcItem.ProcessId > 0 then
    Item.SubItems.Add(IntToStr(SvcItem.ProcessId))
  else
    Item.SubItems.Add('-');
  Item.SubItems.Add(Format('0x%x', [SvcItem.ServiceType]));
end;

procedure TMainForm.edtNetworkSearchChange(Sender: TObject);
begin
  FViewModel.SetNetworkSearchFilter(edtNetworkSearch.Text);
end;

procedure TMainForm.btnRefreshNetworkClick(Sender: TObject);
begin
  FViewModel.RefreshNetworkConnections;
end;

procedure TMainForm.edtServiceSearchChange(Sender: TObject);
begin
  FViewModel.SetServiceSearchFilter(edtServiceSearch.Text);
end;

procedure TMainForm.btnRefreshServicesClick(Sender: TObject);
begin
  FViewModel.RefreshServices;
end;

procedure TMainForm.btnSvcFilterAllClick(Sender: TObject);
begin
  btnSvcFilterAll.Caption := '[All]';
  btnSvcFilterRunning.Caption := 'Running';
  btnSvcFilterStopped.Caption := 'Stopped';
  FViewModel.SetServiceStatusFilter(0);
end;

procedure TMainForm.btnSvcFilterRunningClick(Sender: TObject);
begin
  btnSvcFilterAll.Caption := 'All';
  btnSvcFilterRunning.Caption := '[Running]';
  btnSvcFilterStopped.Caption := 'Stopped';
  FViewModel.SetServiceStatusFilter(1);
end;

procedure TMainForm.btnSvcFilterStoppedClick(Sender: TObject);
begin
  btnSvcFilterAll.Caption := 'All';
  btnSvcFilterRunning.Caption := 'Running';
  btnSvcFilterStopped.Caption := '[Stopped]';
  FViewModel.SetServiceStatusFilter(2);
end;

procedure TMainForm.cmbIntervalChange(Sender: TObject);
var
  IntervalMs: Cardinal;
begin
  case cmbInterval.ItemIndex of
    0: IntervalMs := 500;
    1: IntervalMs := 1000;
    2: IntervalMs := 1500;
    3: IntervalMs := 2500;
    4: IntervalMs := 5000;
  else
    IntervalMs := 1500;
  end;
  FViewModel.SetPollingInterval(IntervalMs);
end;

procedure TMainForm.cmbIntervalDrawItem(Control: TWinControl; Index: Integer;
  ARect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  Txt: string;
  TextY: Integer;
begin
  if not Assigned(cmbInterval) then Exit;
  C := cmbInterval.Canvas;
  if (odSelected in State) and not (odComboBoxEdit in State) then
  begin
    C.Brush.Color := TUIUtils.BlendColor(FColors.SurfaceCard, FColors.Accent, 0.28);
    C.Font.Color := FColors.TextPrimary;
  end
  else
  begin
    C.Brush.Color := FColors.SurfaceCard;
    C.Font.Color := FColors.TextPrimary;
  end;
  C.FillRect(ARect);

  if (Index >= 0) and (Index < cmbInterval.Items.Count) then
  begin
    Txt := cmbInterval.Items[Index];
    C.Font.Name := 'Segoe UI';
    C.Font.Size := 9;
    C.Brush.Style := bsClear;
    TextY := ARect.Top + ((ARect.Bottom - ARect.Top) - C.TextHeight(Txt)) div 2;
    C.TextOut(ARect.Left + 6, TextY, Txt);
  end;
end;

procedure TMainForm.SyncComboBoxHeight;
{$IFDEF MSWINDOWS}
const
  CB_SETITEMHEIGHT = $0151;
var
  CmbRect, BtnRect: Windows.TRect;
  TargetH, ActualH, InnerH: Integer;
begin
  if not Assigned(cmbInterval) or not cmbInterval.HandleAllocated then Exit;

  TargetH := 28;
  if Assigned(btnPinWindow) and btnPinWindow.HandleAllocated then
  begin
    if Windows.GetWindowRect(btnPinWindow.Handle, BtnRect) then
      if (BtnRect.Bottom - BtnRect.Top) > 20 then
        TargetH := BtnRect.Bottom - BtnRect.Top;
  end;

  InnerH := TargetH - 6;
  cmbInterval.ItemHeight := InnerH;
  Windows.SendMessage(cmbInterval.Handle, CB_SETITEMHEIGHT, WPARAM(-1), LPARAM(InnerH));
  Windows.SendMessage(cmbInterval.Handle, CB_SETITEMHEIGHT, WPARAM(0), LPARAM(InnerH));

  if Windows.GetWindowRect(cmbInterval.Handle, CmbRect) then
  begin
    ActualH := CmbRect.Bottom - CmbRect.Top;
    if (ActualH > 0) and (ActualH <> TargetH) then
    begin
      InnerH := InnerH + (TargetH - ActualH);
      if InnerH >= 14 then
      begin
        cmbInterval.ItemHeight := InnerH;
        Windows.SendMessage(cmbInterval.Handle, CB_SETITEMHEIGHT, WPARAM(-1), LPARAM(InnerH));
        Windows.SendMessage(cmbInterval.Handle, CB_SETITEMHEIGHT, WPARAM(0), LPARAM(InnerH));
      end;
    end;
  end;

  Windows.SetWindowPos(cmbInterval.Handle, 0, 214, 18, 110, TargetH,
    SWP_NOZORDER or SWP_NOACTIVATE);
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TMainForm.SearchBoxPaint(Sender: TObject);
var
  Pnl: TPanel;
  C: TCanvas;
  R: TRect;
  IsActive: Boolean;
begin
  if not (Sender is TPanel) then Exit;
  Pnl := TPanel(Sender);
  C := Pnl.Canvas;
  R := Rect(0, 0, Pnl.Width, Pnl.Height);

  IsActive := ((Pnl = pnlSearchBox) and Assigned(edtSearch) and edtSearch.Focused) or
              ((Pnl = pnlNetSearchBox) and Assigned(edtNetworkSearch) and edtNetworkSearch.Focused) or
              ((Pnl = pnlSvcSearchBox) and Assigned(edtServiceSearch) and edtServiceSearch.Focused);

  C.Brush.Style := bsSolid;
  C.Brush.Color := FColors.SurfaceCard;
  C.Pen.Style := psSolid;
  C.Pen.Width := 1;
  if IsActive then
    C.Pen.Color := FColors.Accent
  else
    C.Pen.Color := FColors.Border;
  C.Rectangle(R.Left, R.Top, R.Right, R.Bottom);
end;

procedure TMainForm.SearchBoxClick(Sender: TObject);
begin
  if (Sender = pnlSearchBox) and Assigned(edtSearch) then
    edtSearch.SetFocus
  else if (Sender = pnlNetSearchBox) and Assigned(edtNetworkSearch) then
    edtNetworkSearch.SetFocus
  else if (Sender = pnlSvcSearchBox) and Assigned(edtServiceSearch) then
    edtServiceSearch.SetFocus;
end;

procedure TMainForm.SearchEditFocusChange(Sender: TObject);
begin
  if (Sender = edtSearch) and Assigned(pnlSearchBox) then
    pnlSearchBox.Invalidate
  else if (Sender = edtNetworkSearch) and Assigned(pnlNetSearchBox) then
    pnlNetSearchBox.Invalidate
  else if (Sender = edtServiceSearch) and Assigned(pnlSvcSearchBox) then
    pnlSvcSearchBox.Invalidate;
end;

procedure TMainForm.lblTrayClick(Sender: TObject);
begin
  chkTray.Checked := not chkTray.Checked;
end;

procedure TMainForm.LoadHeaderLogo;
var
  AppDir, LogoPath: string;
begin
  AppDir := ExtractFilePath(ParamStr(0));
  LogoPath := AppDir + 'resources' + PathDelim + 'header_logo_32.png';
  if not FileExists(LogoPath) then
    LogoPath := AppDir + 'resources' + PathDelim + 'header_logo_cropped.png';
  if not FileExists(LogoPath) then
    LogoPath := AppDir + '..' + PathDelim + '..' + PathDelim + 'resources' + PathDelim + 'header_logo_32.png';
  if FileExists(LogoPath) then
  begin
    try
      imgHeaderLogo.Picture.LoadFromFile(LogoPath);
    except
    end;
  end;
end;

procedure TMainForm.UpdateTitleBarTheme(const ADark: Boolean);
{$IFDEF MSWINDOWS}
type
  TDwmSetWindowAttribute = function(hwnd: HWND; dwAttribute: DWORD; pvAttribute: Pointer; cbAttribute: DWORD): HRESULT; stdcall;
const
  DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
  DWMWA_USE_IMMERSIVE_DARK_MODE_OLD = 19;
var
  DwmHandle: HMODULE;
  DwmSetWindowAttr: TDwmSetWindowAttribute;
  DarkModeVal: BOOL;
begin
  if not HandleAllocated then Exit;
  DwmHandle := GetModuleHandle('dwmapi.dll');
  if DwmHandle = 0 then
    DwmHandle := LoadLibrary('dwmapi.dll');
  if DwmHandle <> 0 then
  begin
    @DwmSetWindowAttr := GetProcAddress(DwmHandle, 'DwmSetWindowAttribute');
    if Assigned(DwmSetWindowAttr) then
    begin
      DarkModeVal := ADark;
      if DwmSetWindowAttr(Handle, DWMWA_USE_IMMERSIVE_DARK_MODE, @DarkModeVal, SizeOf(DarkModeVal)) <> 0 then
        DwmSetWindowAttr(Handle, DWMWA_USE_IMMERSIVE_DARK_MODE_OLD, @DarkModeVal, SizeOf(DarkModeVal));
    end;
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}

end.
