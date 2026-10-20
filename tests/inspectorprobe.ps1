$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public class InspCap {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static List<IntPtr> RealWindows(uint targetPid, IntPtr skip) {
    var res = new List<IntPtr>();
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == targetPid && IsWindowVisible(h) && h != skip) {
        RECT r; GetWindowRect(h, out r);
        if ((r.Right - r.Left) > 100 && (r.Bottom - r.Top) > 100) res.Add(h);
      }
      return true;
    }, IntPtr.Zero);
    return res;
  }
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

function Click-At([IntPtr]$h, [int]$cx, [int]$cy, [uint32]$button) {
  $r = New-Object InspCap+RECT
  $null = [InspCap]::GetWindowRect($h, [ref]$r)
  $sx = ([int]$r.Left) + 8 + $cx
  $sy = ([int]$r.Top) + 39 + $cy
  $pt = New-Object System.Drawing.Point -ArgumentList $sx, $sy
  [System.Windows.Forms.Cursor]::Position = $pt
  Start-Sleep -Milliseconds 350
  [InspCap]::mouse_event($button, 0, 0, 0, [UIntPtr]::Zero)
  [InspCap]::mouse_event($button * 2, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 600
}

function Take-Shot([IntPtr]$h, [string]$path) {
  [InspCap]::SetForegroundWindow($h) | Out-Null
  Start-Sleep -Milliseconds 600
  $r = New-Object InspCap+RECT
  [InspCap]::GetWindowRect($h, [ref]$r) | Out-Null
  $w = ([int]$r.Right) - ([int]$r.Left); $ht = ([int]$r.Bottom) - ([int]$r.Top)
  Write-Host "capture $path ${w}x${ht}"
  $bmp = New-Object System.Drawing.Bitmap($w, $ht)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
  $g.Dispose(); $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

$exe = "C:\Users\jbdt\Documents\antigravity\peaceful-meitner\bin\x86_64-win64\NovaMonitor.exe"
$dir  = "C:\Users\jbdt\Documents\antigravity\peaceful-meitner\bin\x86_64-win64"
$proc = Start-Process -FilePath $exe -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds 12
$main = [InspCap]::Largest($proc.Id)
Write-Host ("main=0x" + $main.ToString('X'))
Click-At $main 200 (-24) 2   # title-bar focus click (left)

# Left-click selects the row (works without activation); the toolbar
# Inspect... button needs no keyboard focus, so this path is immune to the
# foreground-lock that blocks synthetic keystrokes.
$dlg = [IntPtr]::Zero
for ($try = 1; $try -le 8 -and $dlg -eq [IntPtr]::Zero; $try++) {
  $r = New-Object InspCap+RECT
  $null = [InspCap]::GetWindowRect($main, [ref]$r)
  $rowPt = New-Object System.Drawing.Point -ArgumentList (([int]$r.Left) + 508), (([int]$r.Top) + 309)
  [System.Windows.Forms.Cursor]::Position = $rowPt
  Start-Sleep -Milliseconds 150
  [InspCap]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
  [InspCap]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 120
  $btnPt = New-Object System.Drawing.Point -ArgumentList (([int]$r.Left) + 982), (([int]$r.Top) + 253)
  [System.Windows.Forms.Cursor]::Position = $btnPt
  Start-Sleep -Milliseconds 120
  [InspCap]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
  [InspCap]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 500
  if ($try -eq 1) { Take-Shot $main "$dir\shotB_row_button.png" }
  $others = [InspCap]::RealWindows($proc.Id, $main)
  if ($others.Count -gt 0) { $dlg = $others[0] }
  Write-Host ("try " + $try + ": others=" + $others.Count)
  Start-Sleep -Milliseconds 700
}

if ($dlg -ne [IntPtr]::Zero) {
  Take-Shot $dlg "$dir\shot5_inspector_summary.png"
  [InspCap]::SetForegroundWindow($dlg) | Out-Null
  Start-Sleep -Milliseconds 900
  [System.Windows.Forms.SendKeys]::SendWait('^{TAB}')
  Start-Sleep -Seconds 5
  Take-Shot $dlg "$dir\shot6_inspector_threads.png"
  [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
  Start-Sleep -Milliseconds 800
} else {
  Write-Host "DIALOG NOT FOUND after retries"
}

Start-Sleep -Seconds 1
$null = $proc.CloseMainWindow()
Start-Sleep -Seconds 4
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; Write-Host "FORCE-KILLED" } else { Write-Host "exited ok" }
