import XCTest
@testable import MacNetMonitor

final class MacNetMonitorTests: XCTestCase {
    func testFriendlyName() {
        XCTAssertEqual(NetworkTrafficService.friendlyName(for: "en0"), "Wi-Fi / Ethernet (en0)")
        XCTAssertEqual(NetworkTrafficService.friendlyName(for: "utun3"), "VPN / Tunnel (utun3)")
        XCTAssertEqual(NetworkTrafficService.friendlyName(for: "custom0"), "custom0")
    }

    func testNetworkTrafficServiceReadsCounters() {
        let service = NetworkTrafficService()
        let counters = service.readCurrentCounters()
        XCTAssertFalse(counters.isEmpty, "Should find at least one active network interface")
        
        // Loopback must be filtered out
        XCTAssertNil(counters["lo0"], "lo0 should be excluded")
    }

    func testFormatSpeed() {
        XCTAssertEqual(TrafficFormatter.formatSpeed(500), "500.0 B/s")
        XCTAssertEqual(TrafficFormatter.formatSpeed(1024), "1.0 KB/s")
        XCTAssertEqual(TrafficFormatter.formatSpeed(1024 * 1024 * 2.5), "2.50 MB/s")
    }

    func testFormatBytes() {
        XCTAssertEqual(TrafficFormatter.formatBytes(500), "500 B")
        XCTAssertEqual(TrafficFormatter.formatBytes(1024 * 1024), "1.00 MB")
        XCTAssertEqual(TrafficFormatter.formatBytes(1024 * 1024 * 1024 * 3), "3.00 GB")
    }
}
