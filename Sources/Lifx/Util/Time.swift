import Foundation

/// Parse a LIFX timestamp, which is expressed in nanoseconds since epoch
func dateFromTimestamp(_ ts: UInt64) -> Date {
    return Date(timeIntervalSince1970: TimeInterval(ts) / TimeInterval(10^9))
}

/// Generate a LIFX timestamp, which is expressed in nanoseconds since epoch
func timestampFromDate(_ date: Date) -> UInt64 {
    return UInt64(date.timeIntervalSince1970 * TimeInterval(10^9))
}

/// Parse a LIFX duration, which is expressed in milliseconds
func timeIntervalFromDuration(_ duration: UInt32) -> TimeInterval {
    return TimeInterval(duration) / TimeInterval(1000)
}

/// Generate a LIFX duration, which is expressed in milliseconds
func durationFromTimeInterval(_ interval: TimeInterval) -> UInt32 {
    return UInt32(interval * TimeInterval(1000))
}
