import Foundation

public enum MonitoringCadencePolicy: Sendable {
    /// Returns polling interval in seconds.
    /// If screen is asleep -> 0.0 (indicates timer paused completely).
    /// If low power mode is active:
    ///   - window open: 3.0s
    ///   - window closed: 5.0s
    /// Normal mode:
    ///   - window open: 1.0s
    ///   - window closed: 2.0s
    public static func interval(
        isWindowVisible: Bool,
        isLowPowerMode: Bool,
        isScreenAsleep: Bool
    ) -> Double {
        if isScreenAsleep {
            return 0.0
        }

        if isLowPowerMode {
            return isWindowVisible ? 3.0 : 5.0
        } else {
            return isWindowVisible ? 1.0 : 2.0
        }
    }

    /// Resolves actual window visibility from multiple AppKit state signals
    public static func resolveWindowVisibility(
        isKeyOrVisible: Bool,
        isOccluded: Bool,
        isMiniaturized: Bool
    ) -> Bool {
        guard isKeyOrVisible else { return false }
        if isMiniaturized { return false }
        if isOccluded { return false }
        return true
    }

    /// Avoids triggering AppKit redrawing when the title string hasn't changed.
    public static func shouldUpdateTitle(current: String?, new: String) -> Bool {
        return current != new
    }
}
