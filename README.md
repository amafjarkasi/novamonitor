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

- **Asynchronous Telemetry Polling**: Dedicated background worker thread (`TMetricsWorkerThread`) continuously gathers kernel/user CPU times, memory load, disk capacity, and active process metrics with zero GUI stutter or message loop blockage.
- **High-Performance Virtual Process Inspector**:
  - Employs a virtual `TListView` (`OwnerData = True`) capable of displaying 350+ processes with instant virtual painting and near-zero memory footprint (~15 ms scan cost).
  - Live per-process CPU % share calculation and memory working set metrics.
  - Interactive multi-column sorting (PID, Name, CPU %, RAM, Health Status, Threads) with persistent direction indicators.
  - Sub-millisecond instant search filter with real-time text matching.
- **Fluent & Modern UI Aesthetics**:
  - Custom GDI double-buffered canvas rendering (`TUIUtils.DrawCard`, `TUIUtils.DrawProgressBar`) for clean rounded metric cards and progress tracks.
  - One-click **Dark / Light Theme** toggle with immediate visual palette switching.
  - Per-Monitor v2 High-DPI awareness for crisp vector and font scaling at 100%, 125%, 150%, and 200% scaling.
- **System Tray Integration**:
  - Optional minimize-to-system-tray behavior (`TTrayIcon`) with single-click restore.
- **Comprehensive Data Export**:
  - One-click snapshot reporting to structured **JSON** and tabular **CSV** formats.
- **Bulletproof Memory & Concurrency Safety**:
  - Atomic process list pointer swaps to eliminate race conditions during background worker scans.
  - Boundary-checked QuickSort partitioning with duplicate-key protection.
  - Nil-safe Win32 custom-draw message filtering and full exception trapping.

---

## 🏗 Architecture & Code Structure

The project follows the **Model-View-ViewModel (MVVM)** pattern, cleanly separating the Windows telemetry engine, data serializers, state managers, and presentation layers:

```
peaceful-meitner/
├── src/
│   ├── Common/
│   │   ├── Nova.Types.pas              # Domain models (TSystemMetrics, TProcessItem) and service contracts
│   │   └── Nova.Utils.pas              # Dark/Light palettes, formatters, and GDI canvas card drawing
│   ├── Services/
│   │   ├── Nova.Service.Metrics.pas    # Thread-safe Windows API polling and process enumeration
│   │   └── Nova.Service.Exporter.pas   # Structured JSON and CSV telemetry serialization
│   ├── ViewModels/
│   │   └── Nova.ViewModel.Main.pas     # MVVM presentation state, filtering, sorting, and command logic
│   └── Views/
│       ├── Nova.View.Main.pas          # Visual form implementation, event handlers, and owner-draw logic
│       ├── Nova.View.Main.dfm          # Embarcadero Delphi VCL form definition
│       └── Nova.View.Main.lfm          # Lazarus LCL form definition
├── tests/
│   ├── novatest.lpi                    # Automated test runner project configuration
│   └── novatest.lpr                    # Comprehensive unit tests for metrics, processes, sorting, and export
├── resources/
│   ├── logo.svg                        # Vector banner and logo
│   ├── app.ico                         # Windows application icon
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

NovaMonitor includes an automated test suite verifying all telemetry calculations, sorting behaviors, and report serializers:

```cmd
# Run test suite
tests\lib\novatest.exe
```

### Verified Test Cases:
- `PASS: snapshot: CPU in [0..100]`
- `PASS: snapshot: memory total > 0`
- `PASS: snapshot: used <= total memory`
- `PASS: snapshot: disk total > 0`
- `PASS: snapshot: disk pct in [0..100]`
- `PASS: processes: count > 10`
- `PASS: processes: sorted by memory desc (~15 ms scan average)`
- `PASS: processes: non-zero CPU shares after repeated scans`
- `PASS: export: JSON succeeds and validates schema`
- `PASS: export: CSV succeeds with matching process count`
- `PASS: vm: initialized metrics and processes`
- `PASS: vm: search filter and multi-column sorting (PID, Name, CPU, RAM)`

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
2. **Virtual List Controls**: Rather than instantiating thousands of visual `TListItem` controls, the list uses virtual owner-data streaming to maintain zero allocation overhead during live updates.
3. **Atomic Swaps**: Process telemetry lists swap references atomically before freeing superseded datasets, guaranteeing that visual draw cycles never encounter invalid pointers.
4. **Clean Abstraction**: Form units contain zero telemetry collection logic, binding exclusively through events and ViewModel interfaces.

---

## 📝 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
