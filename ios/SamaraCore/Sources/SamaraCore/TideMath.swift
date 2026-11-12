import Foundation

public struct TideExtremum: Equatable, Sendable {
    public var time: Date
    public var feet: Double
    public var isHigh: Bool

    public init(time: Date, feet: Double, isHigh: Bool) {
        self.time = time
        self.feet = feet
        self.isHigh = isHigh
    }
}

public enum TideMath {
    /// Cosine between the surrounding extrema. Nil outside the first and last.
    public static func height(at when: Date, extrema: [TideExtremum]) -> Double? {
        let ordered = extrema.sorted { $0.time < $1.time }
        guard ordered.count >= 2, when >= ordered[0].time, when <= ordered[ordered.count - 1].time else {
            return nil
        }
        for index in 0..<(ordered.count - 1) {
            let left = ordered[index]
            let right = ordered[index + 1]
            if when >= left.time && when <= right.time {
                let span = right.time.timeIntervalSince(left.time)
                if span <= 0 { return left.feet }
                let portion = when.timeIntervalSince(left.time) / span
                return left.feet + (right.feet - left.feet) * (1 - cos(Double.pi * portion)) / 2
            }
        }
        return nil
    }

    public static func roundMinute(_ date: Date) -> Date {
        let raw = date.timeIntervalSince1970
        let floored = floor(raw / 60) * 60
        if raw - floored >= 30 {
            return Date(timeIntervalSince1970: floored + 60)
        }
        return Date(timeIntervalSince1970: floored)
    }

    /// Daytime spans under 3 ft. Endpoints are the crossings, rounded to the minute.
    public static func reefShelters(
        extrema: [TideExtremum],
        sunrise: Date,
        sunset: Date,
        level: Double = 3
    ) -> [(Date, Date)] {
        below(extrema: extrema, level: level).filter { $0.1 > sunrise && $0.0 < sunset }
    }

    public static func below(extrema: [TideExtremum], level: Double = 3) -> [(Date, Date)] {
        let ordered = extrema.sorted { $0.time < $1.time }
        guard ordered.count >= 2 else { return [] }
        var spans: [(Date, Date)] = []
        var start: Date? = ordered[0].feet < level ? ordered[0].time : nil
        for index in 0..<(ordered.count - 1) {
            let left = ordered[index]
            let right = ordered[index + 1]
            guard let cross = crossing(left.time, left.feet, right.time, right.feet, level) else { continue }
            if right.feet < left.feet {
                start = cross
            } else {
                let began = start ?? left.time
                if cross > began { spans.append((began, cross)) }
                start = nil
            }
        }
        if let start, let last = ordered.last, last.time > start {
            spans.append((start, last.time))
        }
        return spans.map { (roundMinute($0.0), roundMinute($0.1)) }.filter { $0.1 > $0.0 }
    }

    private static func crossing(_ t0: Date, _ h0: Double, _ t1: Date, _ h1: Double, _ level: Double) -> Date? {
        if h0 == h1 || (h0 - level) * (h1 - level) > 0 { return nil }
        let target = (level - h0) / (h1 - h0)
        let cosv = 1 - 2 * target
        if cosv < -1 || cosv > 1 { return nil }
        let portion = acos(cosv) / Double.pi
        return t0.addingTimeInterval(t1.timeIntervalSince(t0) * portion)
    }
}
