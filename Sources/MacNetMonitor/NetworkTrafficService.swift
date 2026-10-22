import Darwin
import Foundation

public struct RawInterfaceCounters: Sendable {
    public let name: String
    public let ibytes: UInt64
    public let obytes: UInt64
    public let timestamp: CFAbsoluteTime
}

public final class NetworkTrafficService: @unchecked Sendable {
    private var buffer = [UInt8]()

    public init() {}

    /// Reads 64-bit network traffic counters for all active interfaces via sysctl NET_RT_IFLIST2
    /// Incorporates Gemini review recommendations: ENOMEM retry, buffer padding, unaligned safety,
    /// and IFF_UP / IFF_LOOPBACK validation.
    public func readCurrentCounters() -> [String: RawInterfaceCounters] {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len = 0

        // 1. Query required buffer size
        guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0, len > 0 else {
            return [:]
        }

        // Add 20% headroom to accommodate routing table changes between calls
        len = (len * 12) / 10

        if buffer.count < len {
            buffer = [UInt8](repeating: 0, count: len)
        }

        var actualLen = len
        var retryCount = 0
        var success = false

        while retryCount < 3 {
            actualLen = buffer.count
            if sysctl(&mib, UInt32(mib.count), &buffer, &actualLen, nil, 0) == 0 {
                success = true
                break
            } else if errno == ENOMEM {
                // Buffer grew, re-query and retry
                var newLen = 0
                _ = sysctl(&mib, UInt32(mib.count), nil, &newLen, nil, 0)
                len = max(newLen * 12 / 10, buffer.count * 2)
                buffer = [UInt8](repeating: 0, count: len)
                retryCount += 1
            } else {
                break
            }
        }

        guard success else { return [:] }

        let now = CFAbsoluteTimeGetCurrent()
        var results: [String: RawInterfaceCounters] = [:]

        buffer.withUnsafeBytes { rawBuf in
            var offset = 0
            let totalLen = actualLen
            let minHeaderSize = MemoryLayout<if_msghdr2>.size

            while offset + minHeaderSize <= totalLen {
                let msg = rawBuf.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                let msgLen = Int(msg.ifm_msglen)
                if msgLen <= 0 { break }

                let flags = Int32(msg.ifm_flags)
                let isUp = (flags & IFF_UP) != 0
                let isLoopback = (flags & IFF_LOOPBACK) != 0

                if msg.ifm_type == RTM_IFINFO2 && isUp && !isLoopback {
                    var ifname = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                    if_indextoname(UInt32(msg.ifm_index), &ifname)
                    let name = String(cString: ifname)

                    if !name.isEmpty {
                        results[name] = RawInterfaceCounters(
                            name: name,
                            ibytes: msg.ifm_data.ifi_ibytes,
                            obytes: msg.ifm_data.ifi_obytes,
                            timestamp: now
                        )
                    }
                }
                offset += msgLen
            }
        }

        return results
    }

    /// User-friendly label for interface
    public static func friendlyName(for interface: String) -> String {
        switch interface {
        case "en0":
            return "Wi-Fi / Ethernet (en0)"
        case "en1":
            return "Ethernet / Thunderbolt (en1)"
        case "awdl0":
            return "Apple Wireless Direct (AirDrop)"
        case "llw0":
            return "Low Latency WLAN"
        case let name where name.hasPrefix("utun"):
            return "VPN / Tunnel (\(name))"
        case let name where name.hasPrefix("bridge"):
            return "Thunderbolt Bridge (\(name))"
        case let name where name.hasPrefix("anpi"):
            return "Internal Interconnect (\(name))"
        default:
            return interface
        }
    }
}
