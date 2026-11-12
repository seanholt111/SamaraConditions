import Foundation

public enum CostaRica {
    public static let zone = TimeZone(identifier: "America/Costa_Rica")!

    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    /// "5:02a", "12:26p". No leading zero on the hour.
    public static func clock(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let hour12 = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d%@", hour12, minute, hour < 12 ? "a" : "p")
    }

    /// "11 NOV"
    public static func dayChip(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = zone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date).uppercased()
    }

    /// "11–17 NOV"
    public static func rangeChip(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = zone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d"
        let month = DateFormatter()
        month.calendar = calendar
        month.timeZone = zone
        month.locale = Locale(identifier: "en_US_POSIX")
        month.dateFormat = "MMM"
        return "\(formatter.string(from: start))–\(formatter.string(from: end)) \(month.string(from: end).uppercased())"
    }

    public static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func dayOffset(_ days: Int, from date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: startOfDay(date)) ?? date
    }

    public static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    public static func calendarDays(from earlier: Date, to later: Date) -> Int {
        let start = calendar.startOfDay(for: earlier)
        let end = calendar.startOfDay(for: later)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

public struct AsOfLine: Equatable, Sendable {
    public var text: String
    public var stale: Bool
}

public enum Freshness {
    public static let threshold: TimeInterval = 30 * 60 * 60

    public static func isStale(asOf: Date, now: Date, threshold: TimeInterval = Freshness.threshold) -> Bool {
        now.timeIntervalSince(asOf) > threshold
    }

    /// Fresh: "as of 5:02a". Stale: "as of yesterday 5:02a · may be out of date".
    public static func line(asOf: Date, now: Date) -> AsOfLine {
        let clock = CostaRica.clock(asOf)
        let stale = isStale(asOf: asOf, now: now)
        if !stale {
            return AsOfLine(text: "as of \(clock)", stale: false)
        }
        let days = CostaRica.calendarDays(from: asOf, to: now)
        let when = days == 1 ? "yesterday \(clock)" : "\(CostaRica.dayChip(asOf)) \(clock)"
        return AsOfLine(text: "as of \(when) · may be out of date", stale: true)
    }

    public static func offlineStrip(asOf: Date) -> String {
        "Offline · showing \(CostaRica.clock(asOf)) data"
    }

    /// Header used when only this block's feed is stale.
    public static func blockHeader(name: String, asOf: Date, now: Date) -> String {
        let clock = CostaRica.clock(asOf)
        let days = CostaRica.calendarDays(from: asOf, to: now)
        let when = days == 1 ? "yesterday \(clock)" : "\(CostaRica.clock(asOf))"
        if days == 1 {
            return "\(name) · as of yesterday \(clock)"
        }
        return "\(name) · as of \(when)"
    }
}
