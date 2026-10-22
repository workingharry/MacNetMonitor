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
    @Published public var history: [HistoricalPoint] = []
    @Published public var isConnectedToInternet: Bool = true
    @Published public var connectionType: String = "Wi-Fi / LAN"

    // Persistent CPU Limiter & Energy Saver Mode
    @Published public var isCPULimiterEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isCPULimiterEnabled, forKey: "isCPULimiterEnabled")
            reconfigureTimer()
        }
    }

    // Power management state
    public var isWindowVisible: Bool = true {
        didSet { reconfigureTimer() }
    }
    public var isScreenAsleep: Bool = false {
        didSet { reconfigureTimer() }
    }
    public var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled {
        didSet { reconfigureTimer() }
    }

    private let trafficService = NetworkTrafficService()
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "com.macnetmonitor.pathmonitor")
    private var timer: AnyCancellable?
    private var currentInterval: Double = 1.0
    private var previousCounters: [String: RawInterfaceCounters] = [:]
    private var sessionBaselineCounters: [String: (ibytes: UInt64, obytes: UInt64)] = [:]
    private let maxHistoryPoints = 60 // Keep 60 seconds of history

    public init() {
        // Load persisted CPU limiter setting
        self.isCPULimiterEnabled = UserDefaults.standard.bool(forKey: "isCPULimiterEnabled")

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
        // Observe Low Power Mode
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            }
        }

        // Observe Display Sleep & Wake
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

        // Observe System Sleep & Wake
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
            isScreenAsleep: isScreenAsleep,
            isCPULimiterEnabled: isCPULimiterEnabled
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

            if curr.ibytes > 0 || curr.obytes > 0 || downSpeed > 0 || upSpeed > 0 {
                updatedStats.append(stat)
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

        updatedStats.sort {
            if $0.isActive != $1.isActive {
                return $0.isActive && !$1.isActive
            }
            return $0.downloadSpeed > $1.downloadSpeed
        }

        self.interfaceList = updatedStats
        self.currentDownloadSpeed = totalDownloadSpeed
        self.currentUploadSpeed = totalUploadSpeed
        self.sessionDownloadedBytes = totalSessionDown
        self.sessionUploadedBytes = totalSessionUp

        // Only record detailed history graph if window is visible (saves memory/churn)
        if isWindowVisible {
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

        previousCounters = currentCounters
    }
}
