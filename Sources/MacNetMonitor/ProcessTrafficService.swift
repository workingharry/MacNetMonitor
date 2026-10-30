import Foundation

public struct RawProcessCounters: Sendable {
    public let name: String
    public let bytesIn: UInt64
    public let bytesOut: UInt64
    public let timestamp: CFAbsoluteTime
}

public final class ProcessTrafficService: @unchecked Sendable {
    public init() {}

    /// Parses raw nettop CSV output into aggregated process traffic counters
    public static func parseNettopOutput(_ csv: String, timestamp: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()) -> [String: RawProcessCounters] {
        var rawItems: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        let lines = csv.components(separatedBy: "\n")
        
        for line in lines.dropFirst() {
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count >= 6 else { continue }
            let rawProcess = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !rawProcess.isEmpty else { continue }
            
            let bytesIn = UInt64(parts[4]) ?? 0
            let bytesOut = UInt64(parts[5]) ?? 0
            guard bytesIn > 0 || bytesOut > 0 else { continue }
            
            let cleanedName = cleanProcessName(rawProcess)
            let current = rawItems[cleanedName] ?? (0, 0)
            rawItems[cleanedName] = (current.bytesIn + bytesIn, current.bytesOut + bytesOut)
        }
        
        var results: [String: RawProcessCounters] = [:]
        for (name, counts) in rawItems {
            results[name] = RawProcessCounters(
                name: name,
                bytesIn: counts.bytesIn,
                bytesOut: counts.bytesOut,
                timestamp: timestamp
            )
        }
        return results
    }

    /// Normalizes system process names to recognizable user-facing labels
    public static func cleanProcessName(_ raw: String) -> String {
        var name = raw
        if let dotIndex = name.lastIndex(of: ".") {
            let suffix = name[name.index(after: dotIndex)...]
            if Int(suffix) != nil {
                name = String(name[..<dotIndex])
            }
        }
        
        if name.hasPrefix("Google Chrome") {
            return "Google Chrome"
        } else if name.hasPrefix("Antigravity") {
            return "Antigravity"
        } else if name.hasPrefix("Surfshark") {
            return "Surfshark VPN"
        } else if name.hasPrefix("TradingView") {
            return "TradingView"
        } else if ["apsd", "syspolicyd", "mDNSResponder", "trustd", "symptomsd", "identityservice", "sharingd", "cloudd", "netbiosd", "airportd", "wifip2pd", "rapportd"].contains(name) {
            return "macOS System (\(name))"
        }
        return name
    }

    /// Fetches live per-process socket statistics via macOS built-in nettop
    public func fetchCurrentProcessCounters() -> [String: RawProcessCounters] {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-n", "-P", "-L", "1", "-x"]
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return Self.parseNettopOutput(output)
            }
        } catch {
            return [:]
        }
        return [:]
    }
}
