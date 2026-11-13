import Foundation

/// Care hours, windows, units, and tracer pills for the approved build-4 UX.
public enum CareDay {
    public static let startHour = 6.0
    public static let endHour = 21.0

    public static func hour(_ date: Date) -> Double {
        let parts = CostaRica.calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3600
    }

    public static func date(hour: Double, on day: Date) -> Date {
        CostaRica.startOfDay(day).addingTimeInterval(hour * 3600)
    }

    public static func start(on day: Date) -> Date { date(hour: startHour, on: day) }
    public static func end(on day: Date) -> Date { date(hour: endHour, on: day) }

    /// 5-minute snap, clamped to 6:00a–9:00p.
    public static func snap(_ date: Date, on day: Date) -> Date {
        var hour = self.hour(date)
        hour = (hour * 12).rounded() / 12
        hour = min(endHour, max(startHour, hour))
        return self.date(hour: hour, on: day)
    }
}

public enum TemperatureScale: String, Equatable, Sendable {
    case fahrenheit
    case celsius

    public static func fahrenheit(fromCelsius celsius: Double) -> Double {
        celsius * 9 / 5 + 32
    }

    /// Whole degrees, with a degree sign. Sources thresholds use `threshold`.
    public func whole(_ celsius: Double) -> String {
        let value = self == .fahrenheit ? TemperatureScale.fahrenheit(fromCelsius: celsius) : celsius
        return "\(Int(value.rounded()))°"
    }

    public func threshold(_ celsius: Double) -> String {
        if self == .fahrenheit {
            return String(format: "%.1f °F", TemperatureScale.fahrenheit(fromCelsius: celsius))
        }
        return String(format: "%.1f °C", celsius)
    }
}

public enum WindowWords {
    public static func label(start: Double, end: Double, lowercase: Bool = false) -> String {
        let text: String
        if start == CareDay.startHour && end == CareDay.endHour {
            text = "All day"
        } else if start == CareDay.startHour {
            text = "Until " + clock(end)
        } else if end == CareDay.endHour {
            text = "From " + clock(start)
        } else {
            text = range(start, end)
        }
        return lowercase ? text.lowercased() : text
    }

    public static func clock(_ hour: Double) -> String {
        let minutes = Int((hour * 60).rounded())
        let h = minutes / 60
        let m = minutes % 60
        let suffix = h < 12 ? "a" : "p"
        let hour12 = h % 12 == 0 ? 12 : h % 12
        return String(format: "%d:%02d%@", hour12, m, suffix)
    }

    public static func range(_ start: Double, _ end: Double) -> String {
        var left = clock(start)
        let right = clock(end)
        if left.last == right.last { left.removeLast() }
        return "\(left)–\(right)"
    }
}

public struct HourSpan: Equatable, Sendable {
    public var start: Double
    public var end: Double
    public init(start: Double, end: Double) {
        self.start = start
        self.end = end
    }
}

public struct PlayRun: Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var verdict: HeatVerdict
    public init(start: Double, end: Double, verdict: HeatVerdict) {
        self.start = start
        self.end = end
        self.verdict = verdict
    }
}

public struct ActivityPlan: Equatable, Sendable {
    public var runs: [PlayRun]
    public var darkNote: String?
    public var uvNote: String?
    public var minutesKey: String
    public var okHoursText: String
    public init(runs: [PlayRun], darkNote: String?, uvNote: String?, minutesKey: String, okHoursText: String) {
        self.runs = runs
        self.darkNote = darkNote
        self.uvNote = uvNote
        self.minutesKey = minutesKey
        self.okHoursText = okHoursText
    }
}

public enum ActivityWindows {
    /// 1-minute samples over 6a–9p, rounded inward to 5 minutes. Edges within 5 minutes of 6a or 9p snap to that edge.
    public static func below(series: [Double], cut: Double) -> [HourSpan] {
        let minutes = stride(from: CareDay.startHour, through: CareDay.endHour, by: 1.0 / 60)
        var raw: [(Double, Double)] = []
        var open: Double?
        var previous = CareDay.startHour
        for hour in minutes {
            let under = interpolate(series, hour) < cut
            if under && open == nil { open = hour }
            if !under, let began = open {
                raw.append((began, previous))
                open = nil
            }
            previous = hour
        }
        if let began = open { raw.append((began, CareDay.endHour)) }
        return snap(raw)
    }

    public static func pool() -> [HourSpan] {
        [HourSpan(start: CareDay.startHour, end: CareDay.endHour)]
    }

    /// Sunset + 30 minutes, rounded down to 5 minutes.
    public static func sunCutoff(sunsetHour: Double) -> Double {
        floor((sunsetHour + 0.5) * 12) / 12
    }

    public static func applyingSunCutoff(_ spans: [HourSpan], sunsetHour: Double) -> [HourSpan] {
        let limit = sunCutoff(sunsetHour: sunsetHour)
        return spans.compactMap { span in
            guard span.start < limit - 5.0 / 60 else { return nil }
            return HourSpan(start: span.start, end: min(span.end, limit))
        }
    }

    public static func spans(
        sun: [Double],
        shade: [Double],
        activity: ActivityKind,
        sunsetHour: Double,
        lowTide: Bool = false,
        lowHours: [Double] = [],
        offshore: [Double] = [],
        upperQuartile: Double = .greatestFiniteMagnitude
    ) -> [HourSpan] {
        let base: [HourSpan]
        switch activity {
        case .pool:
            base = pool()
        case .beach:
            base = below(series: sun, cut: 27.9)
        case .soccerSun:
            base = below(series: sun, cut: 25.7)
        case .soccerShade, .jungle:
            base = below(series: shade, cut: 27.9)
        }
        let combined: [HourSpan]
        if activity == .beach && lowTide {
            combined = intersect(base, lowTideLeans(lowHours: lowHours, offshore: offshore, upperQuartile: upperQuartile))
        } else {
            combined = base
        }
        if activity == .beach || activity == .soccerSun {
            return applyingSunCutoff(combined, sunsetHour: sunsetHour)
        }
        return combined
    }

    /// Chad v1.1 over 6a–9p. Heat is not clipped at sunrise or sunset.
    public static func plan(
        hours: [HourPoint],
        activity: ActivityKind,
        sunsetHour: Double,
        rulesDay: Date,
        lowTide: Bool = false,
        lowHours: [Double] = [],
        offshore: [Double] = [],
        upperQuartile: Double = .greatestFiniteMagnitude
    ) -> ActivityPlan {
        let sun = hourly(hours) { $0.wbgtSunC }
        let shade = hourly(hours) { $0.wbgtShadeC }
        let solar = hourly(hours) { $0.shortwaveWm2 }
        let leans = lowTide && activity == .beach
            ? lowTideLeans(lowHours: lowHours, offshore: offshore, upperQuartile: upperQuartile)
            : []
        var samples: [(Double, HeatVerdict)] = []
        var cursor = CareDay.startHour
        while cursor <= CareDay.endHour + 1e-6 {
            let hour = min(CareDay.endHour, cursor)
            let darkSun = interpolate(solar, hour) <= 0
            let wbgt = interpolate(darkSun || activity.heatUsesShade ? shade : sun, hour)
            var verdict: HeatVerdict
            if activity == .pool {
                verdict = wbgt >= 32.3 ? .calmPlay : .ok(play: 50, rest: 10)
            } else {
                verdict = HeatScale.verdict(wbgt: wbgt, on: rulesDay)
            }
            if activity == .beach && lowTide && !leans.contains(where: { hour >= $0.start && hour < $0.end }) {
                verdict = .avoid
            }
            samples.append((hour, verdict))
            cursor += 1.0 / 60
        }
        var runs = snapped(samples)
        if activity == .beach && lowTide && leans.isEmpty { runs = [PlayRun(start: CareDay.startHour, end: CareDay.endHour, verdict: .avoid)] }
        let key = runs.max { $0.verdict.rank < $1.verdict.rank }?.verdict.keyLine ?? "50/10"
        return ActivityPlan(
            runs: runs,
            darkNote: darkNote(activity, sunsetHour: sunsetHour),
            uvNote: uvNote(hours),
            minutesKey: key,
            okHoursText: okText(runs, activity: activity, sunsetHour: sunsetHour)
        )
    }

    private static func snapped(_ samples: [(Double, HeatVerdict)]) -> [PlayRun] {
        var raw: [PlayRun] = []
        var open = samples.first
        var previous = samples.first?.0 ?? CareDay.startHour
        for sample in samples.dropFirst() {
            if sample.1 != open?.1, let began = open {
                raw.append(PlayRun(start: began.0, end: previous, verdict: began.1))
                open = sample
            }
            previous = sample.0
        }
        if let began = open { raw.append(PlayRun(start: began.0, end: CareDay.endHour, verdict: began.1)) }
        let rounded = raw.compactMap { run -> PlayRun? in
            var start = (run.start * 12).rounded() / 12
            var end = (run.end * 12).rounded() / 12
            start = min(CareDay.endHour, max(CareDay.startHour, start))
            end = min(CareDay.endHour, max(CareDay.startHour, end))
            guard end - start >= 5.0 / 60 - 1e-6 else { return nil }
            return PlayRun(start: start, end: end, verdict: run.verdict)
        }
        var merged: [PlayRun] = []
        for run in rounded {
            if let last = merged.last, last.verdict == run.verdict, abs(last.end - run.start) < 1e-6 {
                merged[merged.count - 1].end = run.end
            } else {
                merged.append(run)
            }
        }
        return merged
    }

    private static func darkNote(_ activity: ActivityKind, sunsetHour: Double) -> String? {
        let clock = WindowWords.clock(sunsetHour)
        switch activity {
        case .beach: return "Dark from \(clock) · no ocean after dark"
        case .jungle: return "Dark from \(clock) · trails: daylight only"
        case .soccerSun, .soccerShade, .pool: return nil
        }
    }

    private static func uvNote(_ hours: [HourPoint]) -> String? {
        let hot = hours.filter { ($0.uv ?? 0) >= 8 && (6..<21).contains(CostaRica.calendar.component(.hour, from: $0.time)) }
        guard let peak = hot.max(by: { ($0.uv ?? 0) < ($1.uv ?? 0) }), let uv = peak.uv else { return nil }
        let when = WindowWords.clock(CareDay.hour(peak.time))
        let index = Int(uv.rounded())
        if uv >= 11 { return "UV \(index) at \(when) · Shirt, hat, sunscreen · Midday: shade or fully covered" }
        return "UV \(index) at \(when) · Shirt, hat, sunscreen"
    }

    private static func okText(_ runs: [PlayRun], activity: ActivityKind, sunsetHour: Double) -> String {
        let limit = activity == .jungle ? sunsetHour : CareDay.endHour
        let hours = runs.filter { $0.verdict.isOk }.reduce(0.0) { sum, run in
            sum + max(0, min(run.end, limit) - run.start)
        }
        let full = activity == .jungle ? max(0, sunsetHour - CareDay.startHour) : 15.0
        if hours >= full - 0.15 { return "All day" }
        let halves = Int((hours * 2).rounded())
        let whole = halves / 2
        if halves % 2 == 1 { return whole == 0 ? "✓ ½ h" : "✓ \(whole)½ h" }
        return "✓ \(whole) h"
    }

    public static func interpolate(_ series: [Double], _ hour: Double) -> Double {
        guard !series.isEmpty else { return 0 }
        let index = Int(floor(hour))
        if index >= series.count - 1 { return series[series.count - 1] }
        if index < 0 { return series[0] }
        let fraction = hour - Double(index)
        return series[index] * (1 - fraction) + series[index + 1] * fraction
    }

    public static func hourly(_ hours: [HourPoint], _ pick: (HourPoint) -> Double) -> [Double] {
        var values = Array(repeating: Double.nan, count: 24)
        for point in hours {
            let index = CostaRica.calendar.component(.hour, from: point.time)
            if (0..<24).contains(index) { values[index] = pick(point) }
        }
        let known = values.indices.filter { !values[$0].isNaN }
        guard let first = known.first else { return Array(repeating: 0, count: 24) }
        for index in values.indices where values[index].isNaN {
            let previous = known.last(where: { $0 < index }) ?? first
            let next = known.first(where: { $0 > index }) ?? previous
            values[index] = values[previous].isNaN ? values[next] : values[previous]
        }
        return values
    }

    private static func snap(_ raw: [(Double, Double)]) -> [HourSpan] {
        raw.compactMap { start, end in
            var a = ceil((start * 12 * 1_000_000).rounded() / 1_000_000) / 12
            var b = floor((end * 12 * 1_000_000).rounded() / 1_000_000) / 12
            if a <= CareDay.startHour + 5.0 / 60 { a = CareDay.startHour }
            if b >= CareDay.endHour - 5.0 / 60 { b = CareDay.endHour }
            guard b - a >= 5.0 / 60 - 1e-6 else { return nil }
            return HourSpan(start: a, end: b)
        }
    }

    private static func lowTideLeans(lowHours: [Double], offshore: [Double], upperQuartile: Double) -> [HourSpan] {
        lowHours.compactMap { low in
            let start = max(CareDay.startHour, low - 2)
            let end = min(CareDay.endHour, low + 1)
            guard end > start else { return nil }
            let from = Int(start)
            let to = Int(ceil(end - 1e-6))
            if (from..<max(from, to)).contains(where: { index in
                index >= 0 && index < offshore.count && offshore[index] > upperQuartile
            }) {
                return nil
            }
            return HourSpan(start: start, end: end)
        }
    }

    private static func intersect(_ left: [HourSpan], _ right: [HourSpan]) -> [HourSpan] {
        var pieces: [(Double, Double)] = []
        for a in left {
            for b in right {
                let start = max(a.start, b.start)
                let end = min(a.end, b.end)
                if end - start >= 5.0 / 60 { pieces.append((start, end)) }
            }
        }
        return snap(pieces)
    }
}

public enum SeaWords {
    public static func word(shore: Double, offshore: Double, threshold: Double, upperQuartile: Double) -> String {
        if shore < threshold { return "calm" }
        return offshore > upperQuartile ? "big" : "normal"
    }

    public static func header(calm: [HourSpan], wave: String) -> (full: String, withoutWave: String) {
        let calmText: String
        if calm.isEmpty {
            calmText = "No calm"
        } else {
            let parts = calm.map { span in
                WindowWords.label(start: span.start, end: span.end)
                    .replacingOccurrences(of: "From", with: "from")
                    .replacingOccurrences(of: "Until", with: "until")
            }
            calmText = "Calm " + parts.joined(separator: ", ")
        }
        let body = "Sea (model) · \(calmText)"
        return (body + " · Waves \(wave)", body)
    }
}

public enum TideWords {
    public enum Direction: Equatable, Sendable { case rising, falling, turning, missing }

    public static func direction(feet: Double?, nextFeet: Double?) -> Direction {
        guard let feet, let nextFeet else { return .missing }
        let perHour = (nextFeet - feet) * 60
        if abs(perHour) < 0.1 { return .turning }
        return perHour > 0 ? .rising : .falling
    }

    public static func phrase(feet: Double?, direction: Direction) -> String {
        guard let feet, direction != .missing else { return "—" }
        let height = String(format: "%.1f ft", feet)
        switch direction {
        case .rising: return height + " ↑"
        case .falling: return height + " ↓"
        case .turning: return height + " turning"
        case .missing: return "—"
        }
    }
}

public struct PillSpan: Equatable, Sendable {
    public var start: Double
    public var end: Double
}

public enum PillLayout {
    /// Centre the pills on the line, keep them 6 pt inside the band, and keep the line out of a gap.
    public static func place(line: Double, widths: [Double], bandWidth: Double, gap: Double = 4, margin: Double = 6) -> [PillSpan] {
        guard !widths.isEmpty else { return [] }
        let total = widths.reduce(0, +) + gap * Double(widths.count - 1)
        let lower = margin
        let upper = bandWidth - margin - total
        let ideal = min(max(line - total / 2, lower), max(lower, upper))
        var best: Double?
        var offset = 0.0
        for width in widths {
            let low = max(line - offset - width + 10, lower)
            let high = min(line - offset - 10, max(lower, upper))
            if low <= high {
                let candidate = min(max(ideal, low), high)
                if best == nil || abs(candidate - ideal) < abs((best ?? candidate) - ideal) {
                    best = candidate
                }
            }
            offset += width + gap
        }
        let origin = best ?? ideal
        var spans: [PillSpan] = []
        var x = origin
        for width in widths {
            spans.append(PillSpan(start: x, end: x + width))
            x += width + gap
        }
        return spans
    }

    public static func lineSitsInGap(line: Double, spans: [PillSpan]) -> Bool {
        guard spans.count > 1 else { return false }
        let inside = spans.contains { line >= $0.start + 8 && line <= $0.end - 8 }
        let inGroup = line >= spans[0].start - 8 && line <= spans[spans.count - 1].end + 8
        let nearEdge = line < 14 || line > (spans.last?.end ?? 0) + 14
        return inGroup && !inside && !nearEdge
    }
}

public enum ShoreEnergy {
    public static func shore(offshore: Double, heightMetres: Double, period: Double, tideFeet: Double) -> Double {
        let freeboard = (1.0 - tideFeet) * 0.3048
        let fraction = min(1, transmission(heightMetres, period, freeboard))
        return offshore * fraction
    }

    private static func transmission(_ hs: Double, _ period: Double, _ freeboard: Double) -> Double {
        if hs <= 0 || period <= 0 { return 0.8 * 0.8 + 0.09 }
        let steep = 2 * Double.pi * hs / (9.81 * period * period)
        let xi = (1 / 3.0) / sqrt(steep)
        let r = 30.0 / hs
        let kDA = clamp(-0.40 * freeboard / hs + 0.64 * pow(r, -0.31) * (1 - exp(-0.50 * xi)), 0.075, 0.80)
        let kBR = clamp(-0.35 * freeboard / hs + 0.51 * pow(r, -0.65) * (1 - exp(-0.41 * xi)), 0.05, 0.93 - 0.006 * r)
        let kt: Double
        if r <= 8 { kt = kDA }
        else if r >= 12 { kt = kBR }
        else { let w = (r - 8) / 4; kt = (1 - w) * kDA + w * kBR }
        return kt * kt + 0.30 * 0.30
    }

    private static func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, value))
    }
}

public struct SeaSample: Equatable, Sendable {
    public var hour: Double
    public var shore: Double
    public var offshore: Double
}

public enum SeaSeries {
    public static func points(hours: [HourPoint], extrema: [TideExtremum], day: Date) -> [SeaSample] {
        let offshore = ActivityWindows.hourly(hours) { $0.energyOffshoreKj }
        let height = ActivityWindows.hourly(hours) { $0.swellM }
        let period = ActivityWindows.hourly(hours) { $0.swellPeriodS }
        var samples: [SeaSample] = []
        var step = 0
        while true {
            let hour = CareDay.startHour + Double(step) / 12
            if hour > CareDay.endHour + 1e-6 { break }
            let when = CareDay.date(hour: hour, on: day)
            guard let tide = TideMath.height(at: when, extrema: extrema) else { step += 1; continue }
            let e = lerp(offshore, hour)
            let hs = lerp(height, hour)
            let p = lerp(period, hour)
            samples.append(SeaSample(hour: hour, shore: ShoreEnergy.shore(offshore: e, heightMetres: hs, period: p, tideFeet: tide), offshore: e))
            step += 1
        }
        return samples
    }

    public static func calm(samples: [SeaSample], threshold: Double) -> [HourSpan] {
        var runs: [(Double, Double)] = []
        var open: Double?
        var previous = CareDay.startHour
        for sample in samples {
            if sample.shore < threshold && open == nil { open = sample.hour }
            if sample.shore >= threshold, let began = open {
                runs.append((began, previous))
                open = nil
            }
            previous = sample.hour
        }
        if let began = open, let last = samples.last { runs.append((began, last.hour)) }
        return runs.compactMap { start, end in
            guard end - start >= 15.0 / 60 - 1e-6 else { return nil }
            return HourSpan(start: start, end: end)
        }
    }

    /// Match the pipeline: interpolate the hourly series at t − 0.5 h.
    private static func lerp(_ series: [Double], _ hour: Double) -> Double {
        let shifted = hour - 0.5
        return ActivityWindows.interpolate(series, max(0, shifted))
    }
}
