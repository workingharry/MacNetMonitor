import XCTest
@testable import MacNetMonitor

final class PowerOptimizationTests: XCTestCase {
    
    // TDD Seam 1: Cadence determines timer frequency based on power state & visibility
    func testMonitoringCadencePolicy() {
        // When window is open and normal power: fast cadence (1.0s)
        XCTAssertEqual(
            MonitoringCadencePolicy.interval(isWindowVisible: true, isLowPowerMode: false, isScreenAsleep: false),
            1.0
        )
        
        // When window is closed and normal power: background cadence (2.0s)
        XCTAssertEqual(
            MonitoringCadencePolicy.interval(isWindowVisible: false, isLowPowerMode: false, isScreenAsleep: false),
            2.0
        )
        
        // When low power mode is active: slower cadence (3.0s window open, 5.0s window closed)
        XCTAssertEqual(
            MonitoringCadencePolicy.interval(isWindowVisible: true, isLowPowerMode: true, isScreenAsleep: false),
            3.0
        )
        XCTAssertEqual(
            MonitoringCadencePolicy.interval(isWindowVisible: false, isLowPowerMode: true, isScreenAsleep: false),
            5.0
        )
        
        // When screen is asleep: paused or ultra-slow cadence (0.0 means pause timer entirely)
        XCTAssertEqual(
            MonitoringCadencePolicy.interval(isWindowVisible: false, isLowPowerMode: false, isScreenAsleep: true),
            0.0
        )
    }

    // TDD Seam 2: Status Item title deduplication check
    func testStatusItemTitleDeduplication() {
        let currentTitle = " ↓0.0 B/s ↑0.0 B/s"
        let sameTitle = " ↓0.0 B/s ↑0.0 B/s"
        let newTitle = " ↓1.2 MB/s ↑45.0 KB/s"
        
        XCTAssertFalse(MonitoringCadencePolicy.shouldUpdateTitle(current: currentTitle, new: sameTitle))
        XCTAssertTrue(MonitoringCadencePolicy.shouldUpdateTitle(current: currentTitle, new: newTitle))
    }
}
