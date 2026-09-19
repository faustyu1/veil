#if os(macOS)
import Foundation

/// Turns a series of "bytes so far" readings into a transfer rate.
///
/// `URLSession` reports progress many times a second, and dividing a few
/// kilobytes by a millisecond gives a number in the gigabytes that flickers
/// too fast to read. Readings are therefore only taken every so often, and the
/// result is smoothed so a momentary stall reads as slowing down rather than
/// as zero.
struct TransferRate {

    /// The shortest gap between two readings that counts.
    var window: TimeInterval = 0.25
    /// How much of the newest reading goes into the number on screen.
    var responsiveness: Double = 0.4

    private var lastBytes: Int64?
    private var lastTime: TimeInterval = 0
    private var smoothed: Double?

    /// Bytes per second, or nil until there are two readings to compare.
    var current: Double? { smoothed }

    /// Takes a reading and returns the rate to show.
    @discardableResult
    mutating func record(received: Int64, at time: TimeInterval) -> Double? {
        guard let previous = lastBytes else {
            lastBytes = received
            lastTime = time
            return nil
        }
        let elapsed = time - lastTime
        guard elapsed >= window else { return smoothed }

        let instant = max(0, Double(received - previous)) / elapsed
        smoothed = smoothed.map { responsiveness * instant + (1 - responsiveness) * $0 }
            ?? instant
        lastBytes = received
        lastTime = time
        return smoothed
    }

    /// How long the rest should take at the current rate, when both the rate
    /// and the total are known.
    func secondsRemaining(received: Int64, total: Int64) -> TimeInterval? {
        guard total > 0, let rate = smoothed, rate > 0 else { return nil }
        let remaining = Double(max(0, total - received))
        return remaining / rate
    }
}
#endif
