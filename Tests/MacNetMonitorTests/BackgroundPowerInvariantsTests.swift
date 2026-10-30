import XCTest
@testable import MacNetMonitor

final class BackgroundPowerInvariantsTests: XCTestCase {
    
    // Seam 1: In the background (window/popover closed), cadence must be strictly throttled to at least 2.0s
    func testBackgroundCadenceIsThrottled() {
        // Normal power, background
        let intervalBackground = MonitoringCadencePolicy.interval(
            isWindowVisible: false,
            isLowPowerMode: false,
            isScreenAsleep: false
        )
        // Background must never poll faster than 2.0s
        XCTAssertGreaterThanOrEqual(intervalBackground, 2.0)
        
        // Low power mode, background
        let intervalBackgroundLowPower = MonitoringCadencePolicy.interval(
            isWindowVisible: false,
            isLowPowerMode: true,
            isScreenAsleep: false
        )
        XCTAssertGreaterThanOrEqual(intervalBackgroundLowPower, 5.0)
    }
    
    // Seam 2: When screen is asleep or Mac is locked, all background work MUST halt (0.0s)
    func testScreenSleepHaltsAllPolling() {
        let sleepInterval = MonitoringCadencePolicy.interval(
            isWindowVisible: false,
            isLowPowerMode: false,
            isScreenAsleep: true
        )
        XCTAssertEqual(sleepInterval, 0.0, "Timer must be completely cancelled when display is asleep")
    }

    // Seam 3: Title updates in the background must be strictly deduplicated
    func testStatusItemTitleSuppressesRedundantRedraws() {
        XCTAssertFalse(MonitoringCadencePolicy.shouldUpdateTitle(current: " ↓1.0 MB/s ↑20 KB/s", new: " ↓1.0 MB/s ↑20 KB/s"))
        XCTAssertTrue(MonitoringCadencePolicy.shouldUpdateTitle(current: " ↓1.0 MB/s ↑20 KB/s", new: " ↓1.2 MB/s ↑20 KB/s"))
    }
}
