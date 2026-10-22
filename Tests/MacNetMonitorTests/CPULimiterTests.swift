import XCTest
@testable import MacNetMonitor

final class CPULimiterTests: XCTestCase {
    
    // Test 1: Explicit CPU Limiter / Energy Saver mode persists and takes precedence
    func testCPULimiterPrecedence() {
        // When cpuLimiterEnabled is ON, cadence must always be throttled (at least 3.0s or 5.0s)
        let intervalActiveWindow = MonitoringCadencePolicy.interval(
            isWindowVisible: true,
            isLowPowerMode: false,
            isScreenAsleep: false,
            isCPULimiterEnabled: true
        )
        XCTAssertGreaterThanOrEqual(intervalActiveWindow, 3.0)
        
        let intervalBackground = MonitoringCadencePolicy.interval(
            isWindowVisible: false,
            isLowPowerMode: false,
            isScreenAsleep: false,
            isCPULimiterEnabled: true
        )
        XCTAssertGreaterThanOrEqual(intervalBackground, 5.0)
    }

    // Test 2: Window closure and reopening must maintain correct visibility calculation
    func testWindowVisibilityStateResolution() {
        // Closed window must resolve to isVisible = false
        XCTAssertFalse(MonitoringCadencePolicy.resolveWindowVisibility(isKeyOrVisible: false, isOccluded: false, isMiniaturized: false))
        
        // Fully occluded window must resolve to isVisible = false
        XCTAssertFalse(MonitoringCadencePolicy.resolveWindowVisibility(isKeyOrVisible: true, isOccluded: true, isMiniaturized: false))
        
        // Miniaturized window must resolve to isVisible = false
        XCTAssertFalse(MonitoringCadencePolicy.resolveWindowVisibility(isKeyOrVisible: true, isOccluded: false, isMiniaturized: true))
        
        // Open, visible, non-occluded window must resolve to isVisible = true
        XCTAssertTrue(MonitoringCadencePolicy.resolveWindowVisibility(isKeyOrVisible: true, isOccluded: false, isMiniaturized: false))
    }
}
