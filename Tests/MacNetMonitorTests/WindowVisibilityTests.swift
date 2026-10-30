import XCTest
@testable import MacNetMonitor

final class WindowVisibilityTests: XCTestCase {
    
    // Window closure, occlusion, and reopening must maintain correct visibility calculation
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
