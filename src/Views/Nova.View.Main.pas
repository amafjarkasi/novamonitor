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

    lblTray: TLabel;
    imgHeaderLogo: TImage;
    cmbInterval: TComboBox;
    btnPinWindow: TButton;
    btnFilterAll: TButton;
    btnFilterMem: TButton;
    btnFilterCpu: TButton;
    btnFilterCrit: TButton;
    btnEndTask: TButton;
    btnToggleTree: TButton;
    btnNavNetwork: TButton;
    btnNavServices: TButton;

    // Network view controls
    pnlNetworkSection: TPanel;
    pnlNetworkToolbar: TPanel;
    lblNetworkTitle: TLabel;
    lblNetworkCount: TLabel;
    edtNetworkSearch: TEdit;
    btnRefreshNetwork: TButton;
    lvNetwork: TListView;

    // Services view controls
    pnlServicesSection: TPanel;
    pnlServicesToolbar: TPanel;
    lblServicesTitle: TLabel;
    lblServicesCount: TLabel;
    edtServiceSearch: TEdit;
    btnRefreshServices: TButton;
    btnSvcFilterAll: TButton;
    btnSvcFilterRunning: TButton;
    btnSvcFilterStopped: TButton;
    lvServices: TListView;

    function GetSelectedProcess: TProcessItem;
    procedure SetupContextMenu;
    procedure SetupTableToolbarActions;
    procedure SetupProcessColumns;
    procedure SetupNetworkSection;
    procedure SetupServicesSection;
    procedure UpdateFilterChipStyles;
    procedure UpdateServiceFilterStyles;
    procedure TerminateSelectedProcess;

    procedure btnPinWindowClick(Sender: TObject);
    procedure btnFilterAllClick(Sender: TObject);
    procedure btnFilterMemClick(Sender: TObject);
    procedure btnFilterCpuClick(Sender: TObject);
    procedure btnFilterCritClick(Sender: TObject);
    procedure btnEndTaskClick(Sender: TObject);
    procedure btnToggleTreeClick(Sender: TObject);
    procedure btnNavNetworkClick(Sender: TObject);
    procedure btnNavServicesClick(Sender: TObject);
    procedure mnuEndTaskClick(Sender: TObject);

    procedure mnuCopyNameClick(Sender: TObject);
    procedure mnuCopyPidClick(Sender: TObject);
    procedure mnuCopyDetailsClick(Sender: TObject);
    procedure mnuCopyPathClick(Sender: TObject);
    procedure mnuCopyUserClick(Sender: TObject);
    procedure mnuOpenFileLocationClick(Sender: TObject);

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
  BaseColumnCaptions: array[0..8] of string =
    ('PID', 'Process Name', 'User Account', 'Arch', 'CPU %', 'Working Set (RAM)', 'Health Status',
     'Active Threads', 'Image Path');

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

  edtSearch.AutoSize := False;
  edtSearch.SetBounds(16, 18, 190, 28);

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
end;

procedure TMainForm.SetupProcessColumns;
var
  Col: TListColumn;
begin
  lvProcesses.Columns.Clear;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'PID';
  Col.Width := 75;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Process Name';
  Col.Width := 210;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'User Account';
  Col.Width := 150;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Arch';
  Col.Width := 65;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'CPU %';
  Col.Width := 70;
  Col.Alignment := taRightJustify;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Working Set (RAM)';
  Col.Width := 130;
  Col.Alignment := taRightJustify;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Health Status';
  Col.Width := 110;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Active Threads';
  Col.Width := 90;
  Col.Alignment := taRightJustify;

  Col := lvProcesses.Columns.Add;
  Col.Caption := 'Image Path';
  Col.Width := 260;
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

  edtNetworkSearch := TEdit.Create(Self);
  edtNetworkSearch.Parent := pnlNetworkToolbar;
  edtNetworkSearch.SetBounds(230, 7, 200, 26);
  edtNetworkSearch.TextHint := 'Search IP, port, process...';
  edtNetworkSearch.OnChange := edtNetworkSearchChange;

  btnRefreshNetwork := TButton.Create(Self);
  btnRefreshNetwork.Parent := pnlNetworkToolbar;
  btnRefreshNetwork.SetBounds(440, 7, 75, 26);
  btnRefreshNetwork.Caption := 'Refresh';
  btnRefreshNetwork.OnClick := btnRefreshNetworkClick;

  lblNetworkCount := TLabel.Create(Self);
  lblNetworkCount.Parent := pnlNetworkToolbar;
  lblNetworkCount.SetBounds(530, 12, 180, 20);
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

  edtServiceSearch := TEdit.Create(Self);
  edtServiceSearch.Parent := pnlServicesToolbar;
  edtServiceSearch.SetBounds(385, 7, 180, 26);
  edtServiceSearch.TextHint := 'Search services...';
  edtServiceSearch.OnChange := edtServiceSearchChange;

  btnRefreshServices := TButton.Create(Self);
  btnRefreshServices.Parent := pnlServicesToolbar;
  btnRefreshServices.SetBounds(575, 7, 75, 26);
  btnRefreshServices.Caption := 'Refresh';
  btnRefreshServices.OnClick := btnRefreshServicesClick;

  lblServicesCount := TLabel.Create(Self);
  lblServicesCount.Parent := pnlServicesToolbar;
  lblServicesCount.SetBounds(660, 12, 160, 20);
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
  Item.Caption := 'Copy Image Path';
  Item.OnClick := mnuCopyPathClick;
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
    Clipboard.AsText := Format('%d,%s,%s,%s,%.2f,%s,%d',
      [Proc.Id, Proc.Name, Proc.UserName, Proc.Architecture, Proc.MemoryWorkingSetMB, TUIUtils.StatusToString(Proc.Status), Proc.ThreadCount]);
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
    SparkR := Rect(R.Right - 85, R.Top + 12, R.Right - 14, R.Bottom - 26);
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
  // SubItem comes 1-based from the Win32 notification: 6 = "Health Status"
  // (0 = PID caption, 1 = name, 2 = user, 3 = arch, 4 = CPU, 5 = RAM, 6 = status)
  if SubItem = 6 then
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
    M.DiskUsagePercent, BarColor, nil);
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
