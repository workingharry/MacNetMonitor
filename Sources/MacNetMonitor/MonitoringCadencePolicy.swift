import Foundation

public enum MonitoringCadencePolicy: Sendable {
    /// Returns polling interval in seconds.
    /// If screen is asleep -> 0.0 (indicates timer paused completely).
    /// If window is visible:
    ///   - normal power: 1.0s
    ///   - low power mode: 3.0s
    /// If window is hidden / closed:
    ///   - normal power: 2.0s
    ///   - low power mode: 5.0s
    public static func interval(isWindowVisible: Bool, isLowPowerMode: Bool, isScreenAsleep: Bool) -> Double {
        if isScreenAsleep {
            return 0.0
        }

        if isLowPowerMode {
            return isWindowVisible ? 3.0 : 5.0
        } else {
            return isWindowVisible ? 1.0 : 2.0
        }
    }

    /// Avoids triggering AppKit redrawing when the title string hasn't changed.
    public static func shouldUpdateTitle(current: String?, new: String) -> Bool {
        return current != new
    }
}
