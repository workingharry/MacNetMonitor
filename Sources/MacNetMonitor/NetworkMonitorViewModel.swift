import AppKit
import Combine
import Foundation
import Network

@MainActor
public final class NetworkMonitorViewModel: ObservableObject {
    @Published public var currentDownloadSpeed: Double = 0.0 // bytes/sec
    @Published public var currentUploadSpeed: Double = 0.0   // bytes/sec
    @Published public var sessionDownloadedBytes: UInt64 = 0
    @Published public var sessionUploadedBytes: UInt64 = 0
    @Published public var selectedInterface: String = "All"
    @Published public var interfaceList: [InterfaceStats] = []
    @Published public var processList: [ProcessTrafficStats] = []
    @Published public var history: [HistoricalPoint] = []
    @Published public var isConnectedToInternet: Bool = true
    @Published public var connectionType: String = "Wi-Fi / LAN"

    // Power management state
    public var isWindowVisible: Bool = true {
        didSet {
            if !isWindowVisible {
                previousProcessCounters.removeAll()
            }
            reconfigureTimer()
        }
    }
    public var isScreenAsleep: Bool = false {
        didSet { reconfigureTimer() }
    }
    public var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled {
        didSet { reconfigureTimer() }
    }

    private let trafficService = NetworkTrafficService()
    private let processService = ProcessTrafficService()
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "com.macnetmonitor.pathmonitor")
    private var timer: AnyCancellable?
    private var currentInterval: Double = 1.0
    private var previousCounters: [String: RawInterfaceCounters] = [:]
    private var sessionBaselineCounters: [String: (ibytes: UInt64, obytes: UInt64)] = [:]
    private var previousProcessCounters: [String: RawProcessCounters] = [:]
    private let maxHistoryPoints = 60 // Keep 60 seconds of history

    public init() {
        setupPathMonitor()
        setupPowerStateObservers()
        startMonitoring()
    }

    private func setupPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isConnectedToInternet = (path.status == .satisfied)
                if path.usesInterfaceType(.wifi) {
                    self.connectionType = "Wi-Fi"
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = "Cellular"
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = "Ethernet"
                } else {
                    self.connectionType = "Other Network"
                }
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    private func setupPowerStateObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isScreenAsleep = true
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isScreenAsleep = false
                self?.tick()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopMonitoring()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                self?.startMonitoring()
                self?.tick()
            }
        }
    }

    public func reconfigureTimer() {
        let interval = MonitoringCadencePolicy.interval(
            isWindowVisible: isWindowVisible,
            isLowPowerMode: isLowPowerMode,
            isScreenAsleep: isScreenAsleep
        )

        if interval <= 0.0 {
            timer?.cancel()
            timer = nil
            currentInterval = 0.0
            return
        }

        if timer != nil && abs(currentInterval - interval) < 0.1 {
            return
        }

        currentInterval = interval
        timer?.cancel()
        timer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    public func startMonitoring() {
        previousCounters = trafficService.readCurrentCounters()
        for (name, snap) in previousCounters {
            sessionBaselineCounters[name] = (ibytes: snap.ibytes, obytes: snap.obytes)
        }
        reconfigureTimer()
    }

    public func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }

    public func resetSessionStats() {
        let current = trafficService.readCurrentCounters()
        sessionBaselineCounters.removeAll()
        for (name, snap) in current {
            sessionBaselineCounters[name] = (ibytes: snap.ibytes, obytes: snap.obytes)
        }
        sessionDownloadedBytes = 0
        sessionUploadedBytes = 0
        history.removeAll()
    }

    private func tick() {
        let currentCounters = trafficService.readCurrentCounters()
        var updatedStats: [InterfaceStats] = []
        updatedStats.reserveCapacity(currentCounters.count)

        var totalDownloadSpeed: Double = 0.0
        var totalUploadSpeed: Double = 0.0
        var totalSessionDown: UInt64 = 0
        var totalSessionUp: UInt64 = 0

        for (name, curr) in currentCounters {
            if sessionBaselineCounters[name] == nil {
                sessionBaselineCounters[name] = (ibytes: curr.ibytes, obytes: curr.obytes)
            }

            var downSpeed: Double = 0.0
            var upSpeed: Double = 0.0

            if let prev = previousCounters[name] {
                let timeDelta = curr.timestamp - prev.timestamp
                if timeDelta > 0.05 {
                    let rxDelta = curr.ibytes >= prev.ibytes ? curr.ibytes - prev.ibytes : 0
                    let txDelta = curr.obytes >= prev.obytes ? curr.obytes - prev.obytes : 0
                    downSpeed = Double(rxDelta) / timeDelta
                    upSpeed = Double(txDelta) / timeDelta
                }
            }

            let base = sessionBaselineCounters[name] ?? (ibytes: curr.ibytes, obytes: curr.obytes)
            let sessionDown = curr.ibytes >= base.ibytes ? curr.ibytes - base.ibytes : 0
            let sessionUp = curr.obytes >= base.obytes ? curr.obytes - base.obytes : 0

            let stat = InterfaceStats(
                name: name,
                displayName: NetworkTrafficService.friendlyName(for: name),
                rxBytesTotal: curr.ibytes,
                txBytesTotal: curr.obytes,
                downloadSpeed: downSpeed,
                uploadSpeed: upSpeed,
                isActive: downSpeed > 0 || upSpeed > 0
            )

            if isWindowVisible {
                if curr.ibytes > 0 || curr.obytes > 0 || downSpeed > 0 || upSpeed > 0 {
                    updatedStats.append(stat)
                }
            }

            if selectedInterface == "All" {
                if name == "en0" || name.hasPrefix("utun") || name == "en1" {
                    totalDownloadSpeed += downSpeed
                    totalUploadSpeed += upSpeed
                    totalSessionDown += sessionDown
                    totalSessionUp += sessionUp
                }
            } else if selectedInterface == name {
                totalDownloadSpeed = downSpeed
                totalUploadSpeed = upSpeed
                totalSessionDown = sessionDown
                totalSessionUp = sessionUp
            }
        }

        if isWindowVisible {
            updatedStats.sort {
                if $0.isActive != $1.isActive {
                    return $0.isActive && !$1.isActive
                }
                return $0.downloadSpeed > $1.downloadSpeed
            }
            self.interfaceList = updatedStats

            // Fetch per-process telemetry only when window is open to avoid background battery drain
            updateProcessStats()

            let point = HistoricalPoint(
                timestamp: Date(),
                downloadSpeed: totalDownloadSpeed,
                uploadSpeed: totalUploadSpeed
            )
            history.append(point)
            if history.count > maxHistoryPoints {
                history.removeFirst(history.count - maxHistoryPoints)
            }
        }

        self.currentDownloadSpeed = totalDownloadSpeed
        self.currentUploadSpeed = totalUploadSpeed
        self.sessionDownloadedBytes = totalSessionDown
        self.sessionUploadedBytes = totalSessionUp

        previousCounters = currentCounters
    }

    private func updateProcessStats() {
        let currentProcessCounters = processService.fetchCurrentProcessCounters()
        var updatedProcesses: [ProcessTrafficStats] = []
        updatedProcesses.reserveCapacity(currentProcessCounters.count)

        for (name, curr) in currentProcessCounters {
            var downSpeed: Double = 0.0
            var upSpeed: Double = 0.0

            if let prev = previousProcessCounters[name] {
                let timeDelta = curr.timestamp - prev.timestamp
                if timeDelta > 0.05 && timeDelta < 5.0 {
                    let rxDelta = curr.bytesIn >= prev.bytesIn ? curr.bytesIn - prev.bytesIn : 0
                    let txDelta = curr.bytesOut >= prev.bytesOut ? curr.bytesOut - prev.bytesOut : 0
                    downSpeed = Double(rxDelta) / timeDelta
                    upSpeed = Double(txDelta) / timeDelta
                }
            }

            let stat = ProcessTrafficStats(
                name: name,
                rxBytesTotal: curr.bytesIn,
                txBytesTotal: curr.bytesOut,
                downloadSpeed: downSpeed,
                uploadSpeed: upSpeed,
                isActive: downSpeed > 0 || upSpeed > 0
            )
            updatedProcesses.append(stat)
        }

        updatedProcesses.sort {
            if $0.isActive != $1.isActive {
                return $0.isActive && !$1.isActive
            }
            let sum0 = $0.downloadSpeed + $0.uploadSpeed
            let sum1 = $1.downloadSpeed + $1.uploadSpeed
            if sum0 != sum1 {
                return sum0 > sum1
            }
            return ($0.rxBytesTotal + $0.txBytesTotal) > ($1.rxBytesTotal + $1.txBytesTotal)
        }

        self.processList = updatedProcesses
        self.previousProcessCounters = currentProcessCounters
    }
}
