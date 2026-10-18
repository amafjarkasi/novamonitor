object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'NovaMonitor - Professional System Telemetry Dashboard'
  ClientHeight = 800
  ClientWidth = 1400
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnShow = FormShow
  OnDestroy = FormDestroy
  OnResize = FormResize
  TextHeight = 15
  object pnlSidebar: TPanel
    Left = 0
    Top = 0
    Width = 220
    Height = 768
    Align = alLeft
    BevelOuter = bvNone
    TabOrder = 0
    object pnlBrand: TPanel
      Left = 0
      Top = 0
      Width = 220
      Height = 72
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object lblBrandTitle: TLabel
        Left = 20
        Top = 18
        Width = 135
        Height = 21
        Caption = 'NOVA MONITOR'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWhite
        Font.Height = -16
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object lblBrandSubtitle: TLabel
        Left = 20
        Top = 42
        Width = 129
        Height = 13
        Caption = 'SYSTEM TELEMETRY SUITE'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGray
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
    end
    object btnNavDashboard: TButton
      AlignWithMargins = True
      Left = 12
      Top = 84
      Width = 196
      Height = 38
      Margins.Left = 12
      Margins.Top = 12
      Margins.Right = 12
      Margins.Bottom = 4
      Align = alTop
      Caption = '  Dashboard'
      TabOrder = 1
      OnClick = btnNavDashboardClick
    end
    object btnNavProcesses: TButton
      AlignWithMargins = True
      Left = 12
      Top = 130
      Width = 196
      Height = 38
      Margins.Left = 12
      Margins.Top = 4
      Margins.Right = 12
      Margins.Bottom = 4
      Align = alTop
      Caption = '  Process Inspector'
      TabOrder = 2
      OnClick = btnNavProcessesClick
    end
    object btnNavExport: TButton
      AlignWithMargins = True
      Left = 12
      Top = 176
      Width = 196
      Height = 38
      Margins.Left = 12
      Margins.Top = 4
      Margins.Right = 12
      Margins.Bottom = 4
      Align = alTop
      Caption = '  Export Reports'
      TabOrder = 3
      OnClick = btnExportSnapshotClick
    end
    object btnNavThemeToggle: TButton
      AlignWithMargins = True
      Left = 12
      Top = 222
      Width = 196
      Height = 38
      Margins.Left = 12
      Margins.Top = 4
      Margins.Right = 12
      Margins.Bottom = 4
      Align = alTop
      Caption = '  Theme: Dark'
      TabOrder = 4
      OnClick = btnNavThemeToggleClick
    end
    object pnlNavBottom: TPanel
      Left = 0
      Top = 624
      Width = 220
      Height = 64
      Align = alBottom
      BevelOuter = bvNone
      TabOrder = 5
      object chkTray: TCheckBox
        Left = 20
        Top = 6
        Width = 180
        Height = 23
        Caption = 'Minimize to tray'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWhite
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        TabOrder = 0
      end
      object lblStatusIndicator: TLabel
        Left = 20
        Top = 36
        Width = 79
        Height = 15
        Caption = 'Status: Active'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGreen
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
    end
  end
  object pnlHeader: TPanel
    Left = 220
    Top = 0
    Width = 1180
    Height = 64
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    object lblPageTitle: TLabel
      Left = 24
      Top = 20
      Width = 193
      Height = 25
      Caption = 'System Performance'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -19
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object pnlHeaderActions: TPanel
      Left = 580
      Top = 0
      Width = 600
      Height = 64
      Align = alRight
      BevelOuter = bvNone
      TabOrder = 0
      object edtSearch: TEdit
        Left = 16
        Top = 18
        Width = 190
        Height = 28
        AutoSize = False
        Color = clWhite
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentColor = False
        ParentFont = False
        TabOrder = 0
        TextHint = 'Search processes...'
        OnChange = edtSearchChange
      end
      object btnToggleMonitor: TButton
        Left = 224
        Top = 18
        Width = 100
        Height = 28
        Caption = 'Pause'
        TabOrder = 1
        OnClick = btnToggleMonitorClick
      end
      object btnExportSnapshot: TButton
        Left = 332
        Top = 18
        Width = 96
        Height = 28
        Caption = 'Export...'
        TabOrder = 2
        OnClick = btnExportSnapshotClick
      end
    end
  end
  object pnlContent: TPanel
    Left = 220
    Top = 64
    Width = 1180
    Height = 704
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object pnlMetricsGrid: TPanel
      Left = 0
      Top = 0
      Width = 1180
      Height = 130
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object pbCardCpu: TPaintBox
        Left = 16
        Top = 8
        Width = 200
        Height = 114
        OnPaint = pbCardCpuPaint
      end
      object pbCardRam: TPaintBox
        Left = 232
        Top = 8
        Width = 200
        Height = 114
        OnPaint = pbCardRamPaint
      end
      object pbCardDisk: TPaintBox
        Left = 448
        Top = 8
        Width = 200
        Height = 114
        OnPaint = pbCardDiskPaint
      end
      object pbCardUptime: TPaintBox
        Left = 664
        Top = 8
        Width = 200
        Height = 114
        OnPaint = pbCardUptimePaint
      end
    end
    object pnlProcessSection: TPanel
      AlignWithMargins = True
      Left = 16
      Top = 138
      Width = 868
      Height = 478
      Margins.Left = 16
      Margins.Top = 8
      Margins.Right = 16
      Margins.Bottom = 8
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 1
      object pnlTableToolbar: TPanel
        Left = 0
        Top = 0
        Width = 868
        Height = 40
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object lblTableTitle: TLabel
          Left = 16
          Top = 10
          Width = 85
          Height = 17
          Caption = 'Active Tasks'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          Layout = tlCenter
        end
        object lblProcessCount: TLabel
          AlignWithMargins = True
          Left = 746
          Top = 10
          Width = 114
          Height = 27
          Margins.Right = 8
          Align = alRight
          Alignment = taRightJustify
          Caption = '0 processes active'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGray
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          Layout = tlCenter
        end
      end
      object lvProcesses: TListView
        Left = 0
        Top = 40
        Width = 868
        Height = 438
        Align = alClient
        BorderStyle = bsNone
        Columns = <
          item
            Caption = 'PID'
            Width = 80
          end
          item
            Caption = 'Process Name'
            Width = 230
          end
          item
            Alignment = taRightJustify
            Caption = 'CPU %'
            Width = 70
          end
          item
            Caption = 'Working Set (RAM)'
            Width = 170
          end
          item
            Caption = 'Health Status'
            Width = 150
          end
          item
            Caption = 'Active Threads'
            Width = 120
          end>
        DoubleBuffered = True
        GridLines = True
        ReadOnly = True
        RowSelect = True
        TabOrder = 1
        ViewStyle = vsReport
        OnCustomDrawItem = lvProcessesCustomDrawItem
        OnCustomDrawSubItem = lvProcessesCustomDrawSubItem
      end
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 768
    Width = 1400
    Height = 32
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 3
    object lblFooterStatus: TLabel
      Left = 16
      Top = 8
      Width = 34
      Height = 15
      Caption = 'Ready'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object lblFooterTime: TLabel
      AlignWithMargins = True
      Left = 1018
      Top = 8
      Width = 86
      Height = 21
      Margins.Right = 16
      Align = alRight
      Alignment = taRightJustify
      Caption = 'Updated: --:--:--'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGray
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
    end
  end
  object SaveDialog: TSaveDialog
    DefaultExt = 'json'
    Left = 32
    Top = 320
  end
end
