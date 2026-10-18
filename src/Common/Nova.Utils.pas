unit Nova.Utils;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Windows,
  SysUtils,
  Classes,
  Types,
  Graphics,
  Controls,
  Nova.Types;

type
  /// <summary>
  /// Palette definitions for modern UI styling
  /// </summary>
  TThemeColors = record
    Background: TColor;
    Surface: TColor;
    SurfaceCard: TColor;
    Border: TColor;
    TextPrimary: TColor;
    TextSecondary: TColor;
    Accent: TColor;
    AccentHover: TColor;
    Success: TColor;
    Warning: TColor;
    Danger: TColor;
    SidebarBg: TColor;
    SidebarActive: TColor;
    SidebarText: TColor;
  end;

  /// <summary>
  /// Helper functions for UI formatting and drawing
  /// </summary>
  TUIUtils = class
  public
    class function GetThemeColors(const ATheme: TAppTheme): TThemeColors; static;
    class function FormatBytes(const ABytes: UInt64): string; static;
    class function FormatMegabytes(const AMB: Single): string; static;
    class function FormatDuration(const ASeconds: UInt64): string; static;
    class function FormatPercent(const AValue: Single): string; static;
    class function StatusToString(const AStatus: TItemStatus): string; static;
    class function StatusToColor(const AStatus: TItemStatus; const AColors: TThemeColors): TColor; static;
    
    /// <summary>
    /// Draw a modern rounded card panel on a TCanvas
    /// </summary>
    class procedure DrawCard(const ACanvas: TCanvas; const ARect: TRect;
      const ABgColor, ABorderColor: TColor; const ARadius: Integer = 8); static;

    /// <summary>
    /// Draw a modern status pill/badge
    /// </summary>
    class procedure DrawBadge(const ACanvas: TCanvas; const ARect: TRect;
      const AText: string; const ABadgeColor, ATextColor: TColor); static;

    /// <summary>
    /// Draw a sleek horizontal progress bar
    /// </summary>
    class procedure DrawProgressBar(const ACanvas: TCanvas; const ARect: TRect;
      const APercent: Single; const ABgColor, ABarColor: TColor); static;

    /// <summary>
    /// Linearly blend two TColors by ratio [0..1]
    /// </summary>
    class function BlendColor(const C1, C2: TColor; const ARatio: Single): TColor; static;

    /// <summary>
    /// Render a real-time sparkline graph with gradient area fill and indicator dot
    /// </summary>
    class procedure DrawSparkline(const ACanvas: TCanvas; const ARect: TRect;
      const AValues: array of Single; const ALineColor, AFillColor: TColor); static;
  end;

implementation

{ TUIUtils }

class function TUIUtils.GetThemeColors(const ATheme: TAppTheme): TThemeColors;
begin
  if ATheme = atDark then
  begin
    // Sleek modern dark palette (Slate / Zinc style)
    Result.Background    := $1C1917;
    Result.Surface       := $242220;
    Result.SurfaceCard   := $2D2A27;
    Result.Border        := $3D3834;
    Result.TextPrimary   := $F5F5F4;
    Result.TextSecondary := $A8A29E;
    Result.Accent        := $E07A3B;
    Result.AccentHover   := $F09252;
    Result.Success       := $50C878;
    Result.Warning       := $3BB4F5;
    Result.Danger        := $4754F4;
    Result.SidebarBg     := $181615;
    Result.SidebarActive := $2E2926;
    Result.SidebarText   := $D6D3D1;
  end
  else
  begin
    // Clean modern light palette
    Result.Background    := $F8FAFC;
    Result.Surface       := $FFFFFF;
    Result.SurfaceCard   := $FFFFFF;
    Result.Border        := $E2E8F0;
    Result.TextPrimary   := $0F172A;
    Result.TextSecondary := $64748B;
    Result.Accent        := $D96E25;
    Result.AccentHover   := $E5843E;
    Result.Success       := $229B48;
    Result.Warning       := $1587D9;
    Result.Danger        := $2D3BDC;
    Result.SidebarBg     := $0F172A;
    Result.SidebarActive := $1E293B;
    Result.SidebarText   := $F1F5F9;
  end;
end;

class function TUIUtils.FormatBytes(const ABytes: UInt64): string;
const
  KB: UInt64 = 1024;
  MB: UInt64 = 1024 * 1024;
  GB: UInt64 = 1024 * 1024 * 1024;
  TB: UInt64 = 1024 * 1024 * 1024 * 1024;
begin
  if ABytes >= TB then
    Result := Format('%.2f TB', [ABytes / TB])
  else if ABytes >= GB then
    Result := Format('%.2f GB', [ABytes / GB])
  else if ABytes >= MB then
    Result := Format('%.2f MB', [ABytes / MB])
  else if ABytes >= KB then
    Result := Format('%.2f KB', [ABytes / KB])
  else
    Result := Format('%d B', [ABytes]);
end;

class function TUIUtils.FormatMegabytes(const AMB: Single): string;
begin
  if AMB >= 1024.0 then
    Result := Format('%.2f GB', [AMB / 1024.0])
  else
    Result := Format('%.1f MB', [AMB]);
end;

class function TUIUtils.FormatDuration(const ASeconds: UInt64): string;
var
  Days, Hours, Minutes, Secs: UInt64;
begin
  Days    := ASeconds div 86400;
  Hours   := (ASeconds mod 86400) div 3600;
  Minutes := (ASeconds mod 3600) div 60;
  Secs    := ASeconds mod 60;

  if Days > 0 then
    Result := Format('%dd %02dh %02dm', [Days, Hours, Minutes])
  else if Hours > 0 then
    Result := Format('%02dh %02dm %02ds', [Hours, Minutes, Secs])
  else
    Result := Format('%02dm %02ds', [Minutes, Secs]);
end;

class function TUIUtils.FormatPercent(const AValue: Single): string;
begin
  Result := Format('%.1f%%', [AValue]);
end;

class function TUIUtils.StatusToString(const AStatus: TItemStatus): string;
begin
  case AStatus of
    isNormal:   Result := 'Optimal';
    isWarning:  Result := 'Elevated';
    isCritical: Result := 'Critical';
    isIdle:     Result := 'Idle';
  end;
end;

class function TUIUtils.StatusToColor(const AStatus: TItemStatus; const AColors: TThemeColors): TColor;
begin
  case AStatus of
    isNormal:   Result := AColors.Success;
    isWarning:  Result := AColors.Warning;
    isCritical: Result := AColors.Danger;
    isIdle:     Result := AColors.TextSecondary;
  end;
end;

type
  GpStatus = Integer;
  GpGraphics = Pointer;
  GpPen = Pointer;
  GpBrush = Pointer;
  GpPath = Pointer;
  GpUnit = Integer;
  GpWrapMode = Integer;
  GpFillMode = Integer;
  GpSmoothingMode = Integer;

  TGdiplusStartupInput = record
    GdiplusVersion: UInt32;
    DebugEventCallback: Pointer;
    SuppressBackgroundThread: BOOL;
    SuppressExternalCodecs: BOOL;
  end;
  PGdiplusStartupInput = ^TGdiplusStartupInput;

var
  hGdiplus: HMODULE = 0;
  GdiplusToken: ULONG_PTR = 0;
  GdiplusInitialized: Boolean = False;

  GdiplusStartup: function(out token: ULONG_PTR; input: PGdiplusStartupInput; output: Pointer): GpStatus; stdcall;
  GdiplusShutdown: procedure(token: ULONG_PTR); stdcall;
  GdipCreateFromHDC: function(hdc: HDC; out graphics: GpGraphics): GpStatus; stdcall;
  GdipDeleteGraphics: function(graphics: GpGraphics): GpStatus; stdcall;
  GdipSetSmoothingMode: function(graphics: GpGraphics; mode: GpSmoothingMode): GpStatus; stdcall;
  GdipCreatePen1: function(color: DWORD; width: Single; unit_: GpUnit; out pen: GpPen): GpStatus; stdcall;
  GdipDeletePen: function(pen: GpPen): GpStatus; stdcall;
  GdipCreateSolidFill: function(color: DWORD; out brush: GpBrush): GpStatus; stdcall;
  GdipCreateLineBrushI: function(point1, point2: PPoint; color1, color2: DWORD; wrapMode: GpWrapMode; out lineGradient: GpBrush): GpStatus; stdcall;
  GdipDeleteBrush: function(brush: GpBrush): GpStatus; stdcall;
  GdipFillPolygonI: function(graphics: GpGraphics; brush: GpBrush; points: PPoint; count: Integer; fillMode: GpFillMode): GpStatus; stdcall;
  GdipDrawLinesI: function(graphics: GpGraphics; pen: GpPen; points: PPoint; count: Integer): GpStatus; stdcall;
  GdipFillEllipseI: function(graphics: GpGraphics; brush: GpBrush; x, y, width, height: Integer): GpStatus; stdcall;
  GdipDrawEllipseI: function(graphics: GpGraphics; pen: GpPen; x, y, width, height: Integer): GpStatus; stdcall;
  GdipCreatePath: function(fillMode: GpFillMode; out path: GpPath): GpStatus; stdcall;
  GdipDeletePath: function(path: GpPath): GpStatus; stdcall;
  GdipAddPathArcI: function(path: GpPath; x, y, width, height: Integer; startAngle, sweepAngle: Single): GpStatus; stdcall;
  GdipAddPathLineI: function(path: GpPath; x1, y1, x2, y2: Integer): GpStatus; stdcall;
  GdipClosePathFigure: function(path: GpPath): GpStatus; stdcall;
  GdipFillPath: function(graphics: GpGraphics; brush: GpBrush; path: GpPath): GpStatus; stdcall;
  GdipDrawPath: function(graphics: GpGraphics; pen: GpPen; path: GpPath): GpStatus; stdcall;

function EnsureGDIPlus: Boolean;
var
  Input: TGdiplusStartupInput;
begin
  if GdiplusInitialized then
    Exit(True);

  hGdiplus := LoadLibrary('gdiplus.dll');
  if hGdiplus = 0 then
    Exit(False);

  @GdiplusStartup := GetProcAddress(hGdiplus, 'GdiplusStartup');
  @GdiplusShutdown := GetProcAddress(hGdiplus, 'GdiplusShutdown');
  @GdipCreateFromHDC := GetProcAddress(hGdiplus, 'GdipCreateFromHDC');
  @GdipDeleteGraphics := GetProcAddress(hGdiplus, 'GdipDeleteGraphics');
  @GdipSetSmoothingMode := GetProcAddress(hGdiplus, 'GdipSetSmoothingMode');
  @GdipCreatePen1 := GetProcAddress(hGdiplus, 'GdipCreatePen1');
  @GdipDeletePen := GetProcAddress(hGdiplus, 'GdipDeletePen');
  @GdipCreateSolidFill := GetProcAddress(hGdiplus, 'GdipCreateSolidFill');
  @GdipCreateLineBrushI := GetProcAddress(hGdiplus, 'GdipCreateLineBrushI');
  @GdipDeleteBrush := GetProcAddress(hGdiplus, 'GdipDeleteBrush');
  @GdipFillPolygonI := GetProcAddress(hGdiplus, 'GdipFillPolygonI');
  @GdipDrawLinesI := GetProcAddress(hGdiplus, 'GdipDrawLinesI');
  @GdipFillEllipseI := GetProcAddress(hGdiplus, 'GdipFillEllipseI');
  @GdipDrawEllipseI := GetProcAddress(hGdiplus, 'GdipDrawEllipseI');
  @GdipCreatePath := GetProcAddress(hGdiplus, 'GdipCreatePath');
  @GdipDeletePath := GetProcAddress(hGdiplus, 'GdipDeletePath');
  @GdipAddPathArcI := GetProcAddress(hGdiplus, 'GdipAddPathArcI');
  @GdipAddPathLineI := GetProcAddress(hGdiplus, 'GdipAddPathLineI');
  @GdipClosePathFigure := GetProcAddress(hGdiplus, 'GdipClosePathFigure');
  @GdipFillPath := GetProcAddress(hGdiplus, 'GdipFillPath');
  @GdipDrawPath := GetProcAddress(hGdiplus, 'GdipDrawPath');

  if Assigned(GdiplusStartup) and Assigned(GdipCreateFromHDC) then
  begin
    FillChar(Input, SizeOf(Input), 0);
    Input.GdiplusVersion := 1;
    if GdiplusStartup(GdiplusToken, @Input, nil) = 0 then
      GdiplusInitialized := True;
  end;

  Result := GdiplusInitialized;
end;

function ColorToARGB(const AColor: TColor; const AAlpha: Byte = 255): DWORD;
var
  RGB: Longint;
begin
  RGB := ColorToRGB(AColor);
  Result := (DWORD(AAlpha) shl 24) or
            (DWORD(RGB and $FF) shl 16) or
            (DWORD(RGB and $FF00)) or
            (DWORD((RGB shr 16) and $FF));
end;

procedure AddRoundRectToPath(APath: GpPath; const R: TRect; const ARadius: Integer);
var
  D: Integer;
begin
  D := ARadius * 2;
  if D > (R.Right - R.Left) then D := R.Right - R.Left;
  if D > (R.Bottom - R.Top) then D := R.Bottom - R.Top;
  if D <= 0 then
  begin
    GdipAddPathLineI(APath, R.Left, R.Top, R.Right, R.Top);
    GdipAddPathLineI(APath, R.Right, R.Top, R.Right, R.Bottom);
    GdipAddPathLineI(APath, R.Right, R.Bottom, R.Left, R.Bottom);
    GdipAddPathLineI(APath, R.Left, R.Bottom, R.Left, R.Top);
    GdipClosePathFigure(APath);
    Exit;
  end;

  GdipAddPathArcI(APath, R.Left, R.Top, D, D, 180, 90);
  GdipAddPathArcI(APath, R.Right - D, R.Top, D, D, 270, 90);
  GdipAddPathArcI(APath, R.Right - D, R.Bottom - D, D, D, 0, 90);
  GdipAddPathArcI(APath, R.Left, R.Bottom - D, D, D, 90, 90);
  GdipClosePathFigure(APath);
end;

class procedure TUIUtils.DrawCard(const ACanvas: TCanvas; const ARect: TRect;
  const ABgColor, ABorderColor: TColor; const ARadius: Integer);
var
  G: GpGraphics;
  Path: GpPath;
  Brush: GpBrush;
  Pen: GpPen;
  W, H: Integer;
  R: TRect;
begin
  W := ARect.Right - ARect.Left;
  H := ARect.Bottom - ARect.Top;
  if (W <= 0) or (H <= 0) then Exit;

  if EnsureGDIPlus and (GdipCreateFromHDC(ACanvas.Handle, G) = 0) then
  begin
    try
      GdipSetSmoothingMode(G, 2); // SmoothingModeAntiAlias

      R := Rect(ARect.Left, ARect.Top, ARect.Right - 1, ARect.Bottom - 1);
      if GdipCreatePath(0, Path) = 0 then
      begin
        try
          AddRoundRectToPath(Path, R, ARadius);

          // Fill Card Surface
          if GdipCreateSolidFill(ColorToARGB(ABgColor, 255), Brush) = 0 then
          begin
            GdipFillPath(G, Brush, Path);
            GdipDeleteBrush(Brush);
          end;

          // Stroke Card Border with smooth anti-aliasing
          if GdipCreatePen1(ColorToARGB(ABorderColor, 255), 1.0, 2, Pen) = 0 then
          begin
            GdipDrawPath(G, Pen, Path);
            GdipDeletePen(Pen);
          end;
        finally
          GdipDeletePath(Path);
        end;
      end;
    finally
      GdipDeleteGraphics(G);
    end;
    Exit;
  end;

  // Fallback to standard GDI
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ABgColor;
  ACanvas.Pen.Style   := psSolid;
  ACanvas.Pen.Color   := ABorderColor;
  ACanvas.Pen.Width   := 1;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, ARadius, ARadius);
end;

class procedure TUIUtils.DrawBadge(const ACanvas: TCanvas; const ARect: TRect;
  const AText: string; const ABadgeColor, ATextColor: TColor);
var
  TextX, TextY: Integer;
  G: GpGraphics;
  Path: GpPath;
  Brush: GpBrush;
  R: TRect;
begin
  if EnsureGDIPlus and (GdipCreateFromHDC(ACanvas.Handle, G) = 0) then
  begin
    try
      GdipSetSmoothingMode(G, 2); // SmoothingModeAntiAlias
      R := Rect(ARect.Left, ARect.Top, ARect.Right - 1, ARect.Bottom - 1);
      if GdipCreatePath(0, Path) = 0 then
      begin
        try
          AddRoundRectToPath(Path, R, 5);
          if GdipCreateSolidFill(ColorToARGB(ABadgeColor, 255), Brush) = 0 then
          begin
            GdipFillPath(G, Brush, Path);
            GdipDeleteBrush(Brush);
          end;
        finally
          GdipDeletePath(Path);
        end;
      end;
    finally
      GdipDeleteGraphics(G);
    end;
  end
  else
  begin
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Brush.Color := ABadgeColor;
    ACanvas.Pen.Style   := psClear;
    ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, 6, 6);
  end;

  ACanvas.Font.Color := ATextColor;
  ACanvas.Font.Size  := 8;
  ACanvas.Font.Style := [fsBold];
  ACanvas.Brush.Style := bsClear;

  TextX := ARect.Left + ((ARect.Right - ARect.Left) - ACanvas.TextWidth(AText)) div 2;
  TextY := ARect.Top + ((ARect.Bottom - ARect.Top) - ACanvas.TextHeight(AText)) div 2;
  ACanvas.TextOut(TextX, TextY, AText);
end;

class procedure TUIUtils.DrawProgressBar(const ACanvas: TCanvas; const ARect: TRect;
  const APercent: Single; const ABgColor, ABarColor: TColor);
var
  FillWidth: Integer;
  ClampedPct: Single;
  G: GpGraphics;
  Path: GpPath;
  Brush: GpBrush;
  TrackR, BarR: TRect;
begin
  ClampedPct := APercent;
  if ClampedPct < 0.0 then ClampedPct := 0.0;
  if ClampedPct > 100.0 then ClampedPct := 100.0;

  FillWidth := Round((ARect.Right - ARect.Left) * (ClampedPct / 100.0));

  if EnsureGDIPlus and (GdipCreateFromHDC(ACanvas.Handle, G) = 0) then
  begin
    try
      GdipSetSmoothingMode(G, 2); // SmoothingModeAntiAlias

      // Background Track
      TrackR := Rect(ARect.Left, ARect.Top, ARect.Right - 1, ARect.Bottom - 1);
      if GdipCreatePath(0, Path) = 0 then
      begin
        try
          AddRoundRectToPath(Path, TrackR, 4);
          if GdipCreateSolidFill(ColorToARGB(ABgColor, 255), Brush) = 0 then
          begin
            GdipFillPath(G, Brush, Path);
            GdipDeleteBrush(Brush);
          end;
        finally
          GdipDeletePath(Path);
        end;
      end;

      // Active Bar Fill (Anti-Aliased Capsule)
      if FillWidth >= 3 then
      begin
        BarR := Rect(ARect.Left, ARect.Top, ARect.Left + FillWidth - 1, ARect.Bottom - 1);
        if GdipCreatePath(0, Path) = 0 then
        begin
          try
            AddRoundRectToPath(Path, BarR, 4);
            if GdipCreateSolidFill(ColorToARGB(ABarColor, 255), Brush) = 0 then
            begin
              GdipFillPath(G, Brush, Path);
              GdipDeleteBrush(Brush);
            end;
          finally
            GdipDeletePath(Path);
          end;
        end;
      end;
    finally
      GdipDeleteGraphics(G);
    end;
    Exit;
  end;

  // Fallback to standard GDI
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ABgColor;
  ACanvas.Pen.Style := psClear;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, 4, 4);

  if FillWidth > 2 then
  begin
    BarR := Rect(ARect.Left, ARect.Top, ARect.Left + FillWidth, ARect.Bottom);
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Brush.Color := ABarColor;
    ACanvas.RoundRect(BarR.Left, BarR.Top, BarR.Right, BarR.Bottom, 4, 4);
  end;
end;

class function TUIUtils.BlendColor(const C1, C2: TColor; const ARatio: Single): TColor;
var
  RGB1, RGB2: Longint;
  R1, G1, B1, R2, G2, B2: Byte;
  R, G, B: Byte;
  ClampedRatio: Single;
begin
  ClampedRatio := ARatio;
  if ClampedRatio < 0.0 then ClampedRatio := 0.0;
  if ClampedRatio > 1.0 then ClampedRatio := 1.0;

  RGB1 := ColorToRGB(C1);
  RGB2 := ColorToRGB(C2);

  R1 := RGB1 and $FF;
  G1 := (RGB1 shr 8) and $FF;
  B1 := (RGB1 shr 16) and $FF;

  R2 := RGB2 and $FF;
  G2 := (RGB2 shr 8) and $FF;
  B2 := (RGB2 shr 16) and $FF;

  R := Round(R1 * (1.0 - ClampedRatio) + R2 * ClampedRatio);
  G := Round(G1 * (1.0 - ClampedRatio) + G2 * ClampedRatio);
  B := Round(B1 * (1.0 - ClampedRatio) + B2 * ClampedRatio);

  Result := (B shl 16) or (G shl 8) or R;
end;

class procedure TUIUtils.DrawSparkline(const ACanvas: TCanvas; const ARect: TRect;
  const AValues: array of Single; const ALineColor, AFillColor: TColor);
var
  N, I: Integer;
  W, H: Integer;
  MaxVal, MinVal: Single;
  Pts: array of TPoint;
  PolyPts: array of TPoint;
  X, Y: Integer;
  Normalized: Single;
  G: GpGraphics;
  Pen: GpPen;
  GradBrush: GpBrush;
  DotBrush: GpBrush;
  P1, P2: TPoint;
  LastX, LastY: Integer;
begin
  N := Length(AValues);
  if N < 2 then Exit;
  W := ARect.Right - ARect.Left;
  H := ARect.Bottom - ARect.Top;
  if (W <= 4) or (H <= 4) then Exit;

  MaxVal := 20.0; // Dynamic scaling with 20% floor so low usage shows peaks
  MinVal := 0.0;
  for I := 0 to N - 1 do
  begin
    if AValues[I] > MaxVal then
      MaxVal := AValues[I];
  end;
  if MaxVal > 100.0 then MaxVal := 100.0;
  if MaxVal <= MinVal then MaxVal := MinVal + 1.0;

  SetLength(Pts, N);
  for I := 0 to N - 1 do
  begin
    X := ARect.Left + Round(I * (W - 1) / (N - 1));
    Normalized := (AValues[I] - MinVal) / (MaxVal - MinVal);
    if Normalized < 0.0 then Normalized := 0.0;
    if Normalized > 1.0 then Normalized := 1.0;
    // Y inverted: 0 at bottom, 1.0 at top
    Y := ARect.Bottom - 2 - Round(Normalized * (H - 6));
    Pts[I] := Point(X, Y);
  end;

  // Polygon points for area fill underneath the curve
  SetLength(PolyPts, N + 2);
  for I := 0 to N - 1 do
    PolyPts[I] := Pts[I];
  PolyPts[N] := Point(Pts[N - 1].X, ARect.Bottom);
  PolyPts[N + 1] := Point(Pts[0].X, ARect.Bottom);

  if EnsureGDIPlus and (GdipCreateFromHDC(ACanvas.Handle, G) = 0) then
  begin
    try
      GdipSetSmoothingMode(G, 2); // SmoothingModeAntiAlias

      // 1. Smooth Linear Gradient Area Fill (fading from 45% alpha at top to 0% at bottom)
      P1 := Point(0, ARect.Top);
      P2 := Point(0, ARect.Bottom);
      if GdipCreateLineBrushI(@P1, @P2, ColorToARGB(ALineColor, 115), ColorToARGB(ALineColor, 0), 0, GradBrush) = 0 then
      begin
        GdipFillPolygonI(G, GradBrush, @PolyPts[0], Length(PolyPts), 0);
        GdipDeleteBrush(GradBrush);
      end;

      // 2. Anti-Aliased Sparkline Curve Stroke (Crisp 2.0px stroke)
      if GdipCreatePen1(ColorToARGB(ALineColor, 255), 2.0, 2, Pen) = 0 then
      begin
        GdipDrawLinesI(G, Pen, @Pts[0], N);
        GdipDeletePen(Pen);
      end;

      // 3. Glowing Indicator Dot on newest sample
      LastX := Pts[N - 1].X;
      LastY := Pts[N - 1].Y;

      // Outer glow halo (radius 5)
      if GdipCreateSolidFill(ColorToARGB(ALineColor, 75), DotBrush) = 0 then
      begin
        GdipFillEllipseI(G, DotBrush, LastX - 5, LastY - 5, 10, 10);
        GdipDeleteBrush(DotBrush);
      end;

      // Inner solid dot (radius 3)
      if GdipCreateSolidFill(ColorToARGB(ALineColor, 255), DotBrush) = 0 then
      begin
        GdipFillEllipseI(G, DotBrush, LastX - 3, LastY - 3, 6, 6);
        GdipDeleteBrush(DotBrush);
      end;

      // Center white pinpoint (radius 1.5)
      if GdipCreateSolidFill(ColorToARGB(clWhite, 255), DotBrush) = 0 then
      begin
        GdipFillEllipseI(G, DotBrush, LastX - 1, LastY - 1, 3, 3);
        GdipDeleteBrush(DotBrush);
      end;
    finally
      GdipDeleteGraphics(G);
    end;
    Exit;
  end;

  // Fallback to standard GDI
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := AFillColor;
  ACanvas.Pen.Style := psClear;
  ACanvas.Polygon(PolyPts);

  // Draw sparkline curve
  ACanvas.Pen.Style := psSolid;
  ACanvas.Pen.Color := ALineColor;
  ACanvas.Pen.Width := 2;
  ACanvas.Polyline(Pts);

  // Draw current indicator dot on the newest sample
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ALineColor;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Pen.Color := clWhite;
  ACanvas.Pen.Width := 1;
  ACanvas.Ellipse(Pts[N - 1].X - 2, Pts[N - 1].Y - 2, Pts[N - 1].X + 3, Pts[N - 1].Y + 3);

  // Restore canvas properties
  ACanvas.Pen.Width := 1;
  ACanvas.Pen.Style := psSolid;
  ACanvas.Brush.Style := bsClear;
end;

initialization

finalization
  if GdiplusInitialized and Assigned(GdiplusShutdown) then
  begin
    GdiplusShutdown(GdiplusToken);
    GdiplusInitialized := False;
  end;
  if hGdiplus <> 0 then
  begin
    FreeLibrary(hGdiplus);
    hGdiplus := 0;
  end;

end.
