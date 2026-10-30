import XCTest
@testable import MacNetMonitor

final class ProcessTrafficServiceTests: XCTestCase {
    
    func testProcessNameCleaning() {
        XCTAssertEqual(ProcessTrafficService.cleanProcessName("Google Chrome.2068"), "Google Chrome")
        XCTAssertEqual(ProcessTrafficService.cleanProcessName("Google Chrome H.2077"), "Google Chrome")
        XCTAssertEqual(ProcessTrafficService.cleanProcessName("Antigravity.43367"), "Antigravity")
        XCTAssertEqual(ProcessTrafficService.cleanProcessName("Antigravity Hel.43372"), "Antigravity")
        XCTAssertEqual(ProcessTrafficService.cleanProcessName("Surfshark. Wire.47083"), "Surfshark VPN")
        XCTAssertEqual(ProcessTrafficService.cleanProcessName("mDNSResponder.478"), "macOS System (mDNSResponder)")
        XCTAssertEqual(ProcessTrafficService.cleanProcessName("custom_worker.123"), "custom_worker")
    }

    func testParseNettopOutputAggregatesHelpers() {
        let sampleCSV = """
        time,,interface,state,bytes_in,bytes_out,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch,
        11:15:08.177585,Google Chrome.2068,,,1000,2000,0,0,0,,,,,,,,,,,,
        11:15:08.177586,Google Chrome H.2077,,,5000,3000,0,0,0,,,,,,,,,,,,
        11:15:08.177593,Antigravity.43367,,,4000,1000,0,0,0,,,,,,,,,,,,
        11:15:08.177594,Antigravity Hel.43372,,,6000,2000,0,0,0,,,,,,,,,,,,
        """
        
        let parsed = ProcessTrafficService.parseNettopOutput(sampleCSV, timestamp: 100.0)
        
        // Google Chrome and its helper must be combined
        XCTAssertEqual(parsed["Google Chrome"]?.bytesIn, 6000)
        XCTAssertEqual(parsed["Google Chrome"]?.bytesOut, 5000)
        
        // Antigravity and its helper must be combined
        XCTAssertEqual(parsed["Antigravity"]?.bytesIn, 10000)
        XCTAssertEqual(parsed["Antigravity"]?.bytesOut, 3000)
    }

    func testZeroTrafficProcessesAreExcluded() {
        let sampleCSV = """
        time,,interface,state,bytes_in,bytes_out,rx_dupe,rx_ooo,re-tx,rtt_avg,rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch,
        11:15:08.177585,EmptyProcess.123,,,0,0,0,0,0,,,,,,,,,,,,
        """
        let parsed = ProcessTrafficService.parseNettopOutput(sampleCSV)
        XCTAssertNil(parsed["EmptyProcess"])
    }
}
