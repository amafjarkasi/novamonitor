unit Nova.Utils;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
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

class procedure TUIUtils.DrawCard(const ACanvas: TCanvas; const ARect: TRect;
  const ABgColor, ABorderColor: TColor; const ARadius: Integer);
begin
  // Never assume canvas state from the previous draw call: text drawing leaves
  // Brush.Style = bsClear and badges/bars leave Pen.Style = psClear behind.
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
begin
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ABadgeColor;
  ACanvas.Pen.Style   := psClear;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, 6, 6);

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
  BarR: TRect;
  ClampedPct: Single;
begin
  ClampedPct := APercent;
  if ClampedPct < 0 then ClampedPct := 0;
  if ClampedPct > 100 then ClampedPct := 100;

  // Background track
  ACanvas.Brush.Style := bsSolid;
  ACanvas.Brush.Color := ABgColor;
  ACanvas.Pen.Style := psClear;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, 4, 4);

  // Active progress fill
  FillWidth := Round((ARect.Right - ARect.Left) * (ClampedPct / 100.0));
  if FillWidth > 2 then
  begin
    BarR := Rect(ARect.Left, ARect.Top, ARect.Left + FillWidth, ARect.Bottom);
    ACanvas.Brush.Style := bsSolid;
    ACanvas.Brush.Color := ABarColor;
    ACanvas.RoundRect(BarR.Left, BarR.Top, BarR.Right, BarR.Bottom, 4, 4);
  end;
end;

end.
