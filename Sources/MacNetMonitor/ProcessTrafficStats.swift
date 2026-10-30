import Foundation

public struct ProcessTrafficStats: Identifiable, Sendable {
    public var id: String { name }
    public let name: String
    public let rxBytesTotal: UInt64
    public let txBytesTotal: UInt64
    public let downloadSpeed: Double // bytes per second
    public let uploadSpeed: Double   // bytes per second
    public let isActive: Bool

    public init(
        name: String,
        rxBytesTotal: UInt64,
        txBytesTotal: UInt64,
        downloadSpeed: Double,
        uploadSpeed: Double,
        isActive: Bool
    ) {
        self.name = name
        self.rxBytesTotal = rxBytesTotal
        self.txBytesTotal = txBytesTotal
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.isActive = isActive
    }
}
