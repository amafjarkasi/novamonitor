$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public class WinCap2 {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern IntPtr GetFocus();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static void List(uint targetPid) {
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == targetPid && IsWindowVisible(h)) {
        RECT r; GetWindowRect(h, out r);
        Console.WriteLine("  win 0x" + h.ToString("X") + ": " + (r.Right - r.Left) + "x" + (r.Bottom - r.Top));
      }
      return true;
    }, IntPtr.Zero);
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

$exe = "C:\Users\jbdt\Documents\antigravity\peaceful-meitner\bin\x86_64-win64\NovaMonitor.exe"
$dir  = "C:\Users\jbdt\Documents\antigravity\peaceful-meitner\bin\x86_64-win64"
$proc = Start-Process -FilePath $exe -WorkingDirectory $dir -PassThru
Start-Sleep -Seconds 11
$main = [WinCap2]::Largest($proc.Id)
Write-Host "main = 0x$($main.ToString('X'))"
[WinCap2]::SetForegroundWindow($main) | Out-Null
Start-Sleep -Milliseconds 800
Write-Host "focus check: GetFocus works per-thread only; sending keys now"

# Control test: Ctrl+T (existing theme toggle) — title bar color flips
[System.Windows.Forms.SendKeys]::SendWait('^t')
Start-Sleep -Milliseconds 900
Write-Host "after ctrl+t (existing shortcut): "
[WinCap2]::List($proc.Id)

# Now Ctrl+M (HUD)
[WinCap2]::SetForegroundWindow($main) | Out-Null
Start-Sleep -Milliseconds 800
[System.Windows.Forms.SendKeys]::SendWait('^m')
Start-Sleep -Seconds 3
Write-Host "after ctrl+m (HUD): "
[WinCap2]::List($proc.Id)

$null = $proc.CloseMainWindow()
Start-Sleep -Seconds 3
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; Write-Host "FORCE-KILLED" } else { Write-Host "exited ok" }
