#if os(macOS)
import XCTest
@testable import XrayClient

/// "0 KB/s" next to a bar that is visibly moving is worse than no number at
/// all, so the rate is computed from what actually arrived between two moments
/// rather than from the total divided by anything.
final class TransferRateTests: XCTestCase {

    func testFirstSampleHasNoRateYet() {
        var rate = TransferRate()
        XCTAssertNil(rate.record(received: 0, at: 0))
    }

    func testRateIsBytesGainedOverTimeElapsed() {
        var rate = TransferRate()
        _ = rate.record(received: 0, at: 0)
        XCTAssertEqual(rate.record(received: 2_000_000, at: 2) ?? -1, 1_000_000, accuracy: 1)
    }

    func testRateSmoothsAcrossSamplesRatherThanJumping() {
        var rate = TransferRate()
        _ = rate.record(received: 0, at: 0)
        _ = rate.record(received: 1_000_000, at: 1)
        // A sudden stall must not read as zero on the strength of one sample.
        guard let stalled = rate.record(received: 1_000_000, at: 2) else {
            return XCTFail("a stalled transfer still has a rate to report")
        }
        XCTAssertGreaterThan(stalled, 0)
        XCTAssertLessThan(stalled, 1_000_000)
    }

    func testSamplesTakenTooCloseTogetherAreIgnored() {
        var rate = TransferRate()
        _ = rate.record(received: 0, at: 0)
        let first = rate.record(received: 1_000_000, at: 1)
        // URLSession fires several times per millisecond; dividing by that
        // interval produces a rate in the gigabytes.
        XCTAssertEqual(rate.record(received: 1_000_400, at: 1.001), first,
                       "a sample inside the sampling window keeps the last rate")
    }

    func testTimeRemainingUsesTheCurrentRate() {
        var rate = TransferRate()
        _ = rate.record(received: 0, at: 0)
        _ = rate.record(received: 1_000_000, at: 1)
        XCTAssertEqual(rate.secondsRemaining(received: 1_000_000, total: 3_000_000) ?? 0,
                       2, accuracy: 0.1)
    }

    func testNoTimeRemainingWithoutATotal() {
        var rate = TransferRate()
        _ = rate.record(received: 0, at: 0)
        _ = rate.record(received: 1_000_000, at: 1)
        XCTAssertNil(rate.secondsRemaining(received: 1_000_000, total: 0))
    }
}
#endif
