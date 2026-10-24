import XCTest
@testable import MacNetMonitor

final class BackgroundPowerInvariantsTests: XCTestCase {
    
    // Seam 1: In the background (window/popover closed), memory & disk write frequency must be strictly bounded
    func testBackgroundCadenceIsThrottled() {
        // Normal power, background
        let intervalBackground = MonitoringCadencePolicy.interval(
            isWindowVisible: false,
            isLowPowerMode: false,
            isScreenAsleep: false,
            isCPULimiterEnabled: false
        )
        // Background must never poll faster than 2.0s
        XCTAssertGreaterThanOrEqual(intervalBackground, 2.0)
        
        // With CPU saver on
        let intervalBackgroundSaver = MonitoringCadencePolicy.interval(
            isWindowVisible: false,
            isLowPowerMode: false,
            isScreenAsleep: false,
            isCPULimiterEnabled: true
        )
        XCTAssertGreaterThanOrEqual(intervalBackgroundSaver, 5.0)
    }
    
    // Seam 2: When screen is asleep or Mac is locked, all background work MUST halt (0.0s)
    func testScreenSleepHaltsAllPolling() {
        let sleepInterval = MonitoringCadencePolicy.interval(
            isWindowVisible: false,
            isLowPowerMode: false,
            isScreenAsleep: true,
            isCPULimiterEnabled: false
        )
        XCTAssertEqual(sleepInterval, 0.0, "Timer must be completely cancelled when display is asleep")
    }

    // Seam 3: Title updates in the background must be strictly deduplicated
    func testStatusItemTitleSuppressesRedundantRedraws() {
        XCTAssertFalse(MonitoringCadencePolicy.shouldUpdateTitle(current: " ↓1.0 MB/s ↑20 KB/s", new: " ↓1.0 MB/s ↑20 KB/s"))
        XCTAssertTrue(MonitoringCadencePolicy.shouldUpdateTitle(current: " ↓1.0 MB/s ↑20 KB/s", new: " ↓1.2 MB/s ↑20 KB/s"))
    }
}
