$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
public class WinCap {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }

  [StructLayout(LayoutKind.Sequential)]
  public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit)]
  public struct INPUTUNION { [FieldOffset(0)] public KEYBDINPUT ki; }
  [StructLayout(LayoutKind.Sequential)]
  public struct INPUT { public uint type; public INPUTUNION U; }

  [DllImport("user32.dll", SetLastError=true)]
  public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

  // Ctrl down, key down, key up, Ctrl up — identical to a physical chord
  public static void SendCtrlChord(ushort keyVk) {
    var inp = new INPUT[4];
    inp[0].type = 1; inp[0].U.ki.wVk = 0x11;
    inp[1].type = 1; inp[1].U.ki.wVk = keyVk;
    inp[2].type = 1; inp[2].U.ki.wVk = keyVk; inp[2].U.ki.dwFlags = 2;
    inp[3].type = 1; inp[3].U.ki.wVk = 0x11; inp[3].U.ki.dwFlags = 2;
    SendInput((uint)inp.Length, inp, Marshal.SizeOf(typeof(INPUT)));
  }

  public static List<IntPtr> ByPid(uint targetPid) {
    var res = new List<IntPtr>();
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == targetPid && IsWindowVisible(h)) {
        RECT r; GetWindowRect(h, out r);
        if ((r.Right - r.Left) > 0 && (r.Bottom - r.Top) > 0) res.Add(h);
      }
      return true;
    }, IntPtr.Zero);
    return res;
  }
  public static IntPtr Largest(uint targetPid) {
    IntPtr best = IntPtr.Zero; long bestArea = -1;
    foreach (var h in ByPid(targetPid)) {
      RECT r; GetWindowRect(h, out r);
      long a = (long)(r.Right - r.Left) * (r.Bottom - r.Top);
      if (a > bestArea) { bestArea = a; best = h; }
    }
    return best;
  }
}
"@
Start-Sleep -Milliseconds 200

function Take-Shot([IntPtr]$h, [string]$path) {
  [WinCap]::SetForegroundWindow($h) | Out-Null
  Start-Sleep -Milliseconds 500
  $r = New-Object WinCap+RECT
  [WinCap]::GetWindowRect($h, [ref]$r) | Out-Null
  $w = $r.Right - $r.Left; $ht = $r.Bottom - $r.Top
  Write-Host "capture $path rect=$($r.Left),$($r.Top) ${w}x${ht}"
  $bmp = New-Object System.Drawing.Bitmap($w, $ht)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size($w, $ht)))
  $g.Dispose(); $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

$exe = "C:\Users\jbdt\Documents\antigravity\peaceful-meitner\bin\x86_64-win64\NovaMonitor.exe"
$dir  = "C:\Users\jbdt\Documents\antigravity\peaceful-meitner\bin\x86_64-win64"
$proc = Start-Process -FilePath $exe -WorkingDirectory $dir -PassThru
$targetPid = $proc.Id
Write-Host "launched pid=$targetPid"
Start-Sleep -Seconds 12

# 1. main window
$main = [WinCap]::Largest($targetPid)
if ($main -eq [IntPtr]::Zero) { Write-Host "MAIN WINDOW NOT FOUND"; exit 1 }
Take-Shot $main "$dir\shot1_main.png"

function Click-TitleBar([IntPtr]$h) {
  # Real input is exempt from foreground-lock: click the window title bar
  $r = New-Object WinCap+RECT
  $null = [WinCap]::GetWindowRect($h, [ref]$r)
  $cx = ([int]$r.Left) + 200
  $cy = ([int]$r.Top) + 15
  $pt = New-Object System.Drawing.Point -ArgumentList $cx, $cy
  [System.Windows.Forms.Cursor]::Position = $pt
  Start-Sleep -Milliseconds 350
  [WinCap]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  [WinCap]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 600
}

# 2. Ctrl+M -> HUD (verified focus via real click + primer + chord)
Click-TitleBar $main
$fg = [WinCap]::GetForegroundWindow()
Write-Host ("foreground after click: 0x" + $fg.ToString('X') + " (main=0x" + $main.ToString('X') + ")")
[System.Windows.Forms.SendKeys]::SendWait('^t')
Start-Sleep -Milliseconds 900
[System.Windows.Forms.SendKeys]::SendWait('^m')
Start-Sleep -Seconds 4
$wins = [WinCap]::ByPid($targetPid)
Write-Host ("visible windows after ctrl+m: " + $wins.Count)
$hud = [IntPtr]::Zero
foreach ($w in $wins) {
  $r = New-Object WinCap+RECT
  [WinCap]::GetWindowRect($w, [ref]$r) | Out-Null
  Write-Host ("  win ${w}: " + ($r.Right - $r.Left) + "x" + ($r.Bottom - $r.Top))
  if (($r.Right - $r.Left) -le 400) { $hud = $w }
}
if ($hud -ne [IntPtr]::Zero) { Take-Shot $hud "$dir\shot2_hud.png" } else { Write-Host "HUD NOT FOUND" }

# 3. Ctrl+M again -> restore main
$hudFocused = $false
foreach ($w in $wins) {
  $r = New-Object WinCap+RECT
  [WinCap]::GetWindowRect($w, [ref]$r) | Out-Null
  if (($r.Right - $r.Left) -le 400) { Click-TitleBar $w; $hudFocused = $true }
}
if ($hudFocused) {
  [System.Windows.Forms.SendKeys]::SendWait('^m')
  Start-Sleep -Seconds 2
}
$main2 = [WinCap]::Largest($targetPid)
if ($main2 -ne [IntPtr]::Zero) { Take-Shot $main2 "$dir\shot3_restored.png" }

# 4. right-click first data row -> context menu
[WinCap]::SetForegroundWindow($main2) | Out-Null
Start-Sleep -Milliseconds 600
$r2 = New-Object WinCap+RECT
[WinCap]::GetWindowRect($main2, [ref]$r2) | Out-Null
$sx = $r2.Left + 8 + 500
$sy = $r2.Top + 39 + 262
[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($sx, $sy)
Start-Sleep -Milliseconds 300
[WinCap]::mouse_event(0x0008, 0, 0, 0, [UIntPtr]::Zero)
[WinCap]::mouse_event(0x0010, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 800
$bmp2 = New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width, [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
$g2 = [System.Drawing.Graphics]::FromImage($bmp2)
$g2.CopyFromScreen(0, 0, 0, 0, $bmp2.Size)
$g2.Dispose(); $bmp2.Save("$dir\shot4_contextmenu.png", [System.Drawing.Imaging.ImageFormat]::Png); $bmp2.Dispose()
[System.Windows.Forms.SendKeys]::SendWait('{ESC}')
Start-Sleep -Milliseconds 400

# 5. graceful close
$null = $proc.CloseMainWindow()
Start-Sleep -Seconds 4
if ($proc.HasExited) { Write-Host ("EXITED code=" + $proc.ExitCode) } else { Write-Host "STILL RUNNING - killing"; Stop-Process -Id $targetPid -Force }
