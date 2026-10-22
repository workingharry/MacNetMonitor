import Foundation

public struct InterfaceStats: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let displayName: String
    public let rxBytesTotal: UInt64
    public let txBytesTotal: UInt64
    public let downloadSpeed: Double // bytes per second
    public let uploadSpeed: Double   // bytes per second
    public let isActive: Bool

    public init(
        name: String,
        displayName: String,
        rxBytesTotal: UInt64,
        txBytesTotal: UInt64,
        downloadSpeed: Double,
        uploadSpeed: Double,
        isActive: Bool
    ) {
        self.name = name
        self.displayName = displayName
        self.rxBytesTotal = rxBytesTotal
        self.txBytesTotal = txBytesTotal
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.isActive = isActive
    }
}

public struct HistoricalPoint: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let downloadSpeed: Double
    public let uploadSpeed: Double
}
