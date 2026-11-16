import Foundation

public enum HeatVerdict: Equatable, Sendable {
    case ok(play: Int, rest: Int)
    case capped(play: Int, rest: Int, outing: String)
    case avoid
    case calmPlay

    public var isOk: Bool {
        if case .ok = self { return true }
        return false
    }

    public var isLimited: Bool {
        switch self {
        case .capped, .calmPlay: return true
        default: return false
        }
    }

    /// Higher means stricter, for the single minutes key.
    public var rank: Int {
        switch self {
        case .calmPlay: return 50
        case .capped(let play, _, _): return play == 20 ? 40 : 30
        case .ok(let play, _): return play == 40 ? 20 : 10
        case .avoid: return 0
        }
    }

    public var keyLine: String {
        switch self {
        case .ok(let play, let rest), .capped(let play, let rest, _):
            let pair = "\(play)/\(rest)"
            if case .capped(_, _, let outing) = self { return "\(pair) · \(outing)" }
            return pair
        case .avoid: return "Avoid"
        case .calmPlay: return "Calm play only"
        }
    }
}

public enum HeatMinutes: Equatable, Sendable {
    case minutes(Int)
    case stop

    public var label: String {
        switch self {
        case .minutes(let value): return "\(value)"
        case .stop: return "Stop"
        }
    }
}

public enum HeatScale {
    /// 5 Dec through 25 Dec inclusive. 26 Dec is the first acclimatized day.
    public static func acclimating(_ day: Date) -> Bool {
        let parts = CostaRica.calendar.dateComponents([.month, .day], from: day)
        guard parts.month == 12, let dayNumber = parts.day else { return false }
        return (5...25).contains(dayNumber)
    }

    /// Chad v1.1. One step hotter on 5–25 Dec. Pool calm play does not use this.
    public static func verdict(wbgt: Double, on day: Date) -> HeatVerdict {
        let zone: Int
        if wbgt < 25.7 { zone = 1 }
        else if wbgt < 27.9 { zone = 2 }
        else if wbgt < 30.1 { zone = 3 }
        else if wbgt < 32.3 { zone = 4 }
        else { zone = 5 }
        let shifted = acclimating(day) ? min(5, zone + 1) : zone
        switch shifted {
        case 1: return .ok(play: 50, rest: 10)
        case 2: return .ok(play: 40, rest: 20)
        case 3: return .capped(play: 30, rest: 30, outing: "<2 h")
        case 4: return .capped(play: 20, rest: 40, outing: "≤1 h")
        default: return .avoid
        }
    }

    public static func minutes(wbgt: Double, on day: Date) -> HeatMinutes {
        let raw: HeatMinutes
        if wbgt < 25.7 { raw = .minutes(50) }
        else if wbgt < 27.9 { raw = .minutes(40) }
        else if wbgt < 30.1 { raw = .minutes(30) }
        else if wbgt < 32.3 { raw = .minutes(20) }
        else { raw = .stop }
        guard acclimating(day) else { return raw }
        switch raw {
        case .minutes(50): return .minutes(40)
        case .minutes(40): return .minutes(30)
        case .minutes(30): return .minutes(20)
        case .minutes, .stop: return .stop
        }
    }

    public static func isStopHour(wbgt: Double, on day: Date) -> Bool {
        if case .stop = minutes(wbgt: wbgt, on: day) { return true }
        return false
    }
}
