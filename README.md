<p align="center">
  <img src="resources/logo.svg" alt="NovaMonitor Logo" width="100%" />
</p>

<p align="center">
  <a href="#-key-features"><img src="https://img.shields.io/badge/Architecture-MVVM%20%7C%20Clean-6366f1?style=for-the-badge" alt="Architecture" /></a>
  <a href="#-building--running"><img src="https://img.shields.io/badge/Compiler-Delphi%20%7C%20Free%20Pascal%203.2.2-38bdf8?style=for-the-badge" alt="Compiler" /></a>
  <a href="#-automated-testing"><img src="https://img.shields.io/badge/Tests-100%25%20Passing-34d399?style=for-the-badge" alt="Tests" /></a>
  <a href="#-high-dpi--styling"><img src="https://img.shields.io/badge/Display-Per--Monitor%20v2%20High--DPI-f59e0b?style=for-the-badge" alt="High-DPI" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-f43f5e?style=for-the-badge" alt="License" /></a>
</p>

<p align="center">
  <strong>NovaMonitor</strong> is a high-performance desktop telemetry and process inspection dashboard engineered in modern <strong>Object Pascal</strong>. Designed with clean MVVM architecture, it offers dual-target compatibility for both <strong>Embarcadero Delphi</strong> (VCL) and <strong>Lazarus / Free Pascal</strong> (LCL), delivering native, responsive system performance monitoring without external proprietary runtime dependencies.
</p>

---

## 📸 Key Features

- **Asynchronous Telemetry Polling & Dynamic Interval Control**:
  - Dedicated background worker thread (`TMetricsWorkerThread`) continuously gathers kernel/user CPU times, memory load, disk capacity, network adapter throughput, and active process metrics with zero GUI stutter or message loop blockage.
  - Live **Polling Interval Selector** (`0.5s Fast`, `1.0s`, `1.5s Normal`, `2.5s`, `5.0s Eco`) dynamically adjusts the worker thread sleep cadence in real time.
- **Process Inspector Detail Modal (`Enter` / Double-Click / `Inspect...`)**:
  - Deep-dive diagnostic modal displaying complete process execution metadata (PID, Parent PID, Priority Class, User Account, Architecture, Health Status, CPU %, Working Set RAM, Disk I/O Rate, Active Threads, and Executable Path).
  - Automatically correlates and lists **Active TCP/UDP Network Endpoints** bound to that PID, **Hosted Windows Services** running inside that PID, and all **Loaded Modules / DLLs** enumerated via `EnumProcessModules` and `GetModuleFileNameExW` (`psapi.dll`), with one-click **Copy Full Report**.
- **Process Priority & Suspend/Resume Manager**:
  - Right-click any process to adjust its live Windows scheduling priority (**Set Priority**: `Realtime`, `High`, `Above Normal`, `Normal`, `Below Normal`, `Idle (Low)`) via `SetPriorityClass` (`kernel32.dll`).
  - Instantly **Suspend Process** or **Resume Process** execution threads using native `NtSuspendProcess` and `NtResumeProcess` (`ntdll.dll`) APIs, protected by safety guards on kernel processes (`PID <= 4`) and `NovaMonitor.exe`.
- **Live Per-Process Disk I/O & Protected Kernel Telemetry**:
  - Tracks per-process `ReadTransferCount + WriteTransferCount` deltas across polling ticks via `NtQuerySystemInformation(SystemProcessInformation)` (`ntdll.dll`) and `GetProcessIoCounters` (`kernel32.dll`), displaying live **`Disk I/O`** rates (`KB/s` / `MB/s`) in a sortable column.
  - Queries kernel process records directly via `NtQuerySystemInformation` so protected system processes (`System`, `Registry`, `Memory Compression`, `MsMpEng.exe`, `csrss.exe`) report accurate Working Set RAM, CPU %, Disk I/O, and `NT AUTHORITY\SYSTEM` ownership without requiring elevation.
- **Hierarchical Process Tree View**:
  - Automatically reconstructs process parentage from `ParentProcessID` (`th32ParentProcessID`) to display parent and child subprocesses grouped hierarchically.
  - Clean virtual indentation rendering (`StringOfChar(' ', Level * 3) + '└─ '`) with instant toggle between **Tree View** and **Flat View** via the table toolbar button.
- **Process Security Owner, Executable Path & Architecture**:
  - Queries full executable disk path (`QueryFullProcessImageNameW`), binary architecture (`x64` vs `x86` via `IsWow64Process`), and Windows security account user/domain (`NT AUTHORITY\SYSTEM`, `DOMAIN\User`) via `OpenProcessToken` and `LookupAccountSidW`.
  - Intelligent PID-based metadata cache (`FProcMetaCache`) ensuring zero performance degradation (~15 ms total scan time across 340+ processes).
  - Context menu actions: "Copy Image Path", "Copy User Account", and **Open File Location** (instantly opens Windows File Explorer with the selected executable highlighted).
- **Live Network Sockets Tab (TCP/UDP) & Bandwidth Throughput**:
  - Dedicated sidebar navigation tab monitoring active system connections using direct Win32 IP Helper API bindings (`GetExtendedTcpTable`, `GetExtendedUdpTable`, and `GetIfTable` in `iphlpapi.dll`).
  - Displays live adapter download/upload throughput (**`Net: ↓ KB/s  ↑ KB/s`**) in both the Network toolbar and status footer.
  - Displays Local Address:Port, Remote Endpoint:Port, Protocol (TCP/UDP), Connection State (`LISTEN`, `ESTABLISHED`, `TIME_WAIT`, `CLOSE_WAIT`), and owning Process Name & PID with full column sorting and instant search filtering.
- **Interactive Windows Services Tab (`Start` / `Stop` / `Restart`)**:
  - Dedicated sidebar navigation tab enumerating installed and active Win32 system services via Service Control Manager APIs (`EnumServicesStatusExW` in `advapi32.dll`).
  - Interactive **`Start`**, **`Stop`**, and **`Restart`** toolbar buttons and right-click context menu powered by `OpenServiceW`, `StartServiceW`, and `ControlService` (`advapi32.dll`).
  - Correlates Service Name, Display Name, State (`Running`, `Stopped`, `Paused`), owning PID, and Service Type with quick-filter chips (`[All]`, `[Running]`, `[Stopped]`), column sorting, and real-time search.
- **Hardware-Accelerated GDI+ Anti-Aliased Cards & Rolling Sparklines**:
  - Live 30-sample ring buffers (`THistoryBuffer`) dynamically track CPU utilization, RAM memory pressure, System Storage usage, and System Uptime vitality trends.
  - Hardware-accelerated **GDI+ (`gdiplus.dll`)** anti-aliased rendering (`SmoothingModeAntiAlias`) for smooth rounded cards, progress bars, translucent gradient sparkline fills, and dual-tone storage capacity bars.
  - Native Win32 `LVS_EX_DOUBLEBUFFER` extended listview style and `DwmSetWindowAttribute` (`dwmapi.dll`) immersive dark/light title bar integration eliminate polling flicker.
- **Instant Process Termination ("End Task")**:
  - Safely terminate selected processes via the toolbar **End Task** button, context menu, or <kbd>Del</kbd> key, with built-in security guards preventing termination of critical system processes.
- **Top Resource Consumer Quick-Filter Chips**:
  - One-click filter chips to instantly isolate workload bottlenecks:
    - `[All]`: View all active processes (<kbd>Ctrl</kbd>+<kbd>1</kbd>).
    - `[Heavy RAM (>400MB)]`: Filter memory-intensive workloads (<kbd>Ctrl</kbd>+<kbd>2</kbd>).
    - `[Active CPU (>2%)]`: Pinpoint CPU-active threads (<kbd>Ctrl</kbd>+<kbd>3</kbd>).
    - `[Alerts]`: Isolate processes currently in Warning or Critical health states (<kbd>Ctrl</kbd>+<kbd>4</kbd>).
- **"Always on Top" Window Pinning**:
  - Quick-toggle **Pin** button in the header actions (<kbd>Ctrl</kbd>+<kbd>P</kbd>) to keep NovaMonitor floating above full-screen IDEs and games while diagnosing performance spikes.
- **High-Performance Virtual Process Inspector**:
  - Employs a virtual `TListView` (`OwnerData = True`) capable of displaying 350+ processes with flicker-free virtual painting and near-zero memory footprint.
  - Interactive 10-column sorting (`PID`, `Process Name`, `User Account`, `Arch`, `CPU %`, `Working Set (RAM)`, `Disk I/O`, `Health Status`, `Active Threads`, `Image Path`) with persistent sort direction indicators (`▲`/`▼`).
- **Desktop Ergonomics & Keyboard Accelerators**:
  - <kbd>Enter</kbd> or **Double-Click** on a process row to open the **Process Inspector Detail Modal**.
  - <kbd>Ctrl</kbd>+<kbd>F</kbd> to instantly focus and select search filter; <kbd>Esc</kbd> to clear search.
  - <kbd>Ctrl</kbd>+<kbd>P</kbd> to toggle Always on Top window pinning.
  - <kbd>Ctrl</kbd>+<kbd>1</kbd>..<kbd>4</kbd> to switch quick-filter chips.
  - <kbd>Del</kbd> to end selected task.
  - <kbd>Ctrl</kbd>+<kbd>T</kbd> to toggle Dark/Light theme.
  - <kbd>Ctrl</kbd>+<kbd>E</kbd> to trigger telemetry export.
- **System Tray Integration & Data Export**:
  - Optional minimize-to-system-tray behavior (`TTrayIcon`) with single-click restore.
  - One-click snapshot reporting to structured **JSON** and tabular **CSV** formats.

---

## 🏗 Architecture & Code Structure

The project follows the **Model-View-ViewModel (MVVM)** pattern, cleanly separating the Windows telemetry engine, data serializers, state managers, and presentation layers:

```
peaceful-meitner/
├── src/
│   ├── Common/
│   │   ├── Nova.Types.pas              # Domain models (TSystemMetrics, TProcessItem) and service contracts
│   │   └── Nova.Utils.pas              # Dark/Light palettes, rate formatters, and GDI+ anti-aliased rendering
│   ├── Services/
│   │   ├── Nova.Service.Metrics.pas    # Thread-safe Win32/NTAPI polling, process/service control, and module inspection
│   │   └── Nova.Service.Exporter.pas   # Structured JSON and CSV telemetry serialization
│   ├── ViewModels/
│   │   └── Nova.ViewModel.Main.pas     # MVVM presentation state, 10-column sorting, filtering, and command logic
│   └── Views/
│       ├── Nova.View.Main.pas          # Visual form implementation, Process Inspector modal, and custom draw logic
│       ├── Nova.View.Main.dfm          # Embarcadero Delphi VCL form definition
│       └── Nova.View.Main.lfm          # Lazarus LCL form definition
├── tests/
│   ├── novatest.lpi                    # Automated test runner project configuration
│   └── novatest.lpr                    # Comprehensive unit tests for metrics, processes, sorting, guards, and export
├── resources/
│   ├── logo.svg                        # Vector banner and logo
│   ├── header_logo_32.png              # Transparent RGBA header emblem
│   ├── app.ico                         # Multi-resolution Windows application icon (16px-256px)
│   └── app.manifest                    # Windows Per-Monitor v2 High-DPI manifest
├── NovaMonitor.dpr                     # Delphi main application entrypoint
├── NovaMonitor.dproj                   # Delphi MSBuild project file
├── NovaMonitor.lpi                     # Lazarus project configuration
├── NovaMonitor.lpr                     # Lazarus main application entrypoint
├── NovaMonitor.rc                      # Windows resource script
└── README.md                           # Documentation
```

---

## 🧪 Automated Testing

NovaMonitor includes a 74-assertion automated test suite verifying all telemetry calculations, security guards, GDI+ rendering, sorting behaviors, and report serializers:

```cmd
# Build and run test suite
lazbuild -B tests\novatest.lpi
tests\lib\novatest.exe
```

### Verified Test Cases:
- `PASS: history: initial count is 0 and empty ToArray`
- `PASS: history: circular buffer capped at 30 and maintains chronological order`
- `PASS: ui: BlendColor mid-point calculation`
- `PASS: gdi+: DrawCard, DrawProgressBar, DrawBadge, and DrawSparkline execute cleanly`
- `PASS: terminate / priority / suspend: PID 0 (Idle), PID 4 (System), and CurrentProcess security guards`
- `PASS: format: FormatRateKBps zero and MB/s scaling`
- `PASS: modules: current process loaded DLL enumeration`
- `PASS: interval: dynamic polling interval control (1500ms -> 500ms -> 2500ms)`
- `PASS: snapshot: CPU in [0..100], memory total > 0, disk pct in [0..100], net download/upload >= 0`
- `PASS: processes: count > 10, sorted by memory desc (~15 ms scan average), non-zero CPU shares`
- `PASS: export: JSON and CSV succeed and validate schema`
- `PASS: vm: initialized metrics, processes, and CPU/RAM/Disk history buffers`
- `PASS: vm: 10-column sorting (PID, Name, User, Arch, CPU %, RAM, Disk I/O, Health Status, Threads, Image Path)`
- `PASS: vm: quick-filter modes (fmHeavyMemory, fmActiveCpu, fmCriticalOnly, fmAll)`
- `PASS: network & services: live collection, status filtering, and hierarchical process tree view`

---

## 🚀 Building & Running

### Option 1: Lazarus / Free Pascal 3.2.2 (CLI & IDE)

NovaMonitor is configured for automated building via `lazbuild`:

```cmd
# Rebuild binary from command line
lazbuild -B NovaMonitor.lpi

# Launch executable
.\bin\x86_64-win64\NovaMonitor.exe
```

Or open `NovaMonitor.lpi` directly inside the Lazarus IDE.

### Option 2: Embarcadero Delphi (RAD Studio / Community Edition)

1. Open `NovaMonitor.dproj` in RAD Studio / Delphi.
2. Select target platform (**Win64** or **Win32**).
3. Build via MSBuild:
```cmd
msbuild NovaMonitor.dproj /t:Build /p:Configuration=Release /p:Platform=Win64
```
4. Press **F9** to compile and run.

---

## 💡 Modern Object Pascal Best Practices Demonstrated

1. **Thread Synchronization**: Worker threads poll metrics asynchronously and dispatch updates to the main GUI thread using thread-safe synchronization queues.
2. **Virtual List Controls**: Rather than instantiating thousands of visual `TListItem` controls, the list uses virtual owner-data streaming with native `LVS_EX_DOUBLEBUFFER` to maintain zero allocation overhead and zero flicker during live updates.
3. **Atomic Swaps**: Process telemetry lists swap references atomically before freeing superseded datasets, guaranteeing that visual draw cycles never encounter invalid pointers.
4. **Clean Abstraction**: Form units contain zero telemetry collection logic, binding exclusively through events and ViewModel interfaces.

---

## 📝 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
