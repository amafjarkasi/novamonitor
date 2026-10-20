$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class CardCap {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static IntPtr Largest(uint targetPid) {
    IntPtr best = IntPtr.Zero; long bestArea = -1;
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == targetPid && IsWindowVisible(h)) {
        RECT r; GetWindowRect(h, out r);
        long a = (long)(r.Right - r.Left) * (r.Bottom - r.Top);
        if (a > bestArea) { bestArea = a; best = h; }
      }
      return true;
    }, IntPtr.Zero);
    return best;
  }
}
"@
Start-Sleep -Milliseconds 200

$exe = "C:\Users\jbdt\Documents\antigravity\peaceful-meitner\bin\x86_64-win64\NovaMonitor.exe"
$dir  = "C:\Users\jbdt\Documents\antigravity\peaceful-meitner\bin\x86_64-win64"
$proc = Start-Process -FilePath $exe -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds 13
$main = [CardCap]::Largest($proc.Id)
[CardCap]::SetForegroundWindow($main) | Out-Null
Start-Sleep -Milliseconds 700
$r = New-Object CardCap+RECT
[CardCap]::GetWindowRect($main, [ref]$r) | Out-Null
$w = ([int]$r.Right) - ([int]$r.Left); $ht = ([int]$r.Bottom) - ([int]$r.Top)
Write-Host "capture ${w}x${ht}"
$bmp = New-Object System.Drawing.Bitmap($w, $ht)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
$g.Dispose(); $bmp.Save("$dir\shot_cards_v2.png", [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
$null = $proc.CloseMainWindow()
Start-Sleep -Seconds 4
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; Write-Host "FORCE-KILLED" } else { Write-Host "exited ok" }
