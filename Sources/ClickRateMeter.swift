import Foundation

/// Counts posted clicks over the trailing second, using a monotonic clock.
struct ClickRateMeter {
    private var firstClick: TimeInterval?
    private var timestamps: [TimeInterval] = []

    mutating func record(at time: TimeInterval) {
        if firstClick == nil { firstClick = time }
        timestamps.append(time)
        trim(at: time)
    }

    mutating func rate(at time: TimeInterval) -> Double {
        trim(at: time)
        guard let firstClick = firstClick, time > firstClick else { return 0 }
        let elapsed = time - firstClick
        if elapsed < 1 {
            // The first click starts the clock; it is not an elapsed interval.
            return Double(max(0, timestamps.count - 1)) / elapsed
        }
        return Double(timestamps.count)
    }

    private mutating func trim(at time: TimeInterval) {
        timestamps.removeAll { $0 <= time - 1 }
    }
}
