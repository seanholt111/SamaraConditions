import Foundation

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
    /// 5 Dec through 26 Dec, the first three weeks of the stay.
    public static func acclimating(_ day: Date) -> Bool {
        let parts = CostaRica.calendar.dateComponents([.month, .day], from: day)
        guard parts.month == 12, let dayNumber = parts.day else { return false }
        return (5...26).contains(dayNumber)
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
