# MacNetMonitor 🚀

A high-performance native macOS internet and network usage monitoring application built in Swift and SwiftUI.

## ✨ Features

- **Direct BSD Kernel Telemetry (`NET_RT_IFLIST2`)**: Reads 64-bit monotonically increasing byte counters directly from the XNU kernel with zero daemon overhead or root privileges.
- **Real-Time Bandwidth Speedometer**: Live download and upload speeds (B/s, KB/s, MB/s, GB/s) calculated per second.
- **Interactive Apple Charts**: 60-second real-time historical bandwidth graph with separate download and upload streams and smooth gradient fills.
- **Session Data Tracker**: Tracks total data transferred (Downloaded & Uploaded) in the current session with a one-click session reset.
- **Per-Application & Process Breakdown**: Live breakdown of network consumption per running app (e.g., Google Chrome, Antigravity, Safari, Surfshark VPN, macOS System Services) with automatic helper process grouping and zero-overhead telemetry.
- **Dynamic View Toggle**: Switch effortlessly between the **Apps / Programs** breakdown and the hardware/virtual **Interfaces** breakdown.
- **Multi-Interface Breakdown**: Inspects all active physical and virtual interfaces (`en0`, `en1`, `utun` VPNs, AirDrop `awdl0`, etc.) with lifetime total byte counts and current status.
- **Dynamic Menu Bar Item**: Shows live download/upload throughput right on your macOS menu bar with click-to-toggle window behavior.
- **Robust & Resilient**: Implements dynamic buffer headroom with `ENOMEM` retries, unaligned byte loading, and sleep/wake protection.

---

## 🛠️ Requirements & Build Instructions

- macOS 13.0 (Ventura) or newer
- Swift 5.9+ / Xcode command line tools

### Build and Run

1. Open a terminal in the project directory:
   ```bash
   cd "MacNetMonitor"
   ```

2. Run tests:
   ```bash
   swift test
   ```

3. Launch the App:
   ```bash
   open MacNetMonitor.app
   ```
   Or run directly via command line:
   ```bash
   ./MacNetMonitor.app/Contents/MacOS/MacNetMonitor
   ```

---

## 📐 Architecture

- `NetworkTrafficService.swift`: Safe C-interop layer that reads 64-bit kernel counters via `sysctl NET_RT_IFLIST2`.
- `ProcessTrafficService.swift`: Non-root zero-overhead per-process socket statistics parser using native macOS `nettop`, with intelligent helper aggregation.
- `ProcessTrafficStats.swift`: Data models and attribution types for per-application telemetry.
- `NetworkMonitorViewModel.swift`: `@MainActor` observable view model with adaptive cadence, window-visibility gating, throughput calculations, session tracking, and `NWPathMonitor` connectivity status.
- `ContentView.swift`: SwiftUI user interface with Apple Charts, speed cards, and interface table.
- `TrafficFormatter.swift`: Formatting utilities for byte values and transfer rates.
- `MacNetMonitor.swift`: App entry point configuring the macOS menu bar status item and main application window.
