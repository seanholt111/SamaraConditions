import SamaraCore
import SwiftUI

enum Palette {
    static let night = Color(red: 0.039, green: 0.055, blue: 0.078)
    static let track = Color(red: 0.086, green: 0.110, blue: 0.145)
    static let text = Color(red: 0.949, green: 0.949, blue: 0.941)
    static let muted = Color(red: 0.604, green: 0.620, blue: 0.651)
    static let amber = Color(red: 0.976, green: 0.549, blue: 0.039)
    static let c50 = Color(red: 0.965, green: 0.843, blue: 0.275)
    static let c40 = Color(red: 0.976, green: 0.549, blue: 0.039)
    static let c30 = Color(red: 0.831, green: 0.282, blue: 0.259)
    static let c20 = Color(red: 0.635, green: 0.200, blue: 0.478)
    static let hatch = Color(red: 0.071, green: 0.031, blue: 0.078)
    static let hatchLine = Color(red: 0.961, green: 0.776, blue: 0.878)
    static let lagoon = Color(red: 0.557, green: 0.902, blue: 0.933)
    static let mid = Color(red: 0.247, green: 0.663, blue: 0.863)
    static let ocean = Color(red: 0.184, green: 0.400, blue: 0.878)
    static let deep = Color(red: 0.141, green: 0.314, blue: 0.784)
    static let cloud = Color(red: 0.788, green: 0.808, blue: 0.839)
    static let chipFill = Color(red: 0.110, green: 0.141, blue: 0.188)
    static let chipEdge = Color(red: 0.227, green: 0.259, blue: 0.298)
    static let line = Color.white

    static func zone(_ minutes: HeatMinutes) -> Color {
        switch minutes {
        case .minutes(50): return c50
        case .minutes(40): return c40
        case .minutes(30): return c30
        case .minutes(20): return c20
        case .stop: return hatch
        default: return c20
        }
    }
}

enum SamaraFont {
    static func chip() -> Font { .system(size: 13, weight: .semibold) }
    static func tab() -> Font { .system(size: 15, weight: .semibold) }
    static func readout() -> Font { .system(size: 22, weight: .medium) }
    static func band() -> Font { .system(size: 12, weight: .semibold) }
    static func window(_ large: Bool) -> Font { .system(size: large ? 22 : 17, weight: .bold) }
}

func tempText(_ value: Double) -> String {
    String(format: "%.1f°", value)
}

func axisTick(_ date: Date) -> String {
    let parts = CostaRica.calendar.dateComponents([.hour, .minute], from: date)
    let hour = parts.hour ?? 0
    let minute = parts.minute ?? 0
    let hour12 = hour % 12 == 0 ? 12 : hour % 12
    let suffix = hour < 12 ? "a" : "p"
    if minute == 0 { return "\(hour12)\(suffix)" }
    return String(format: "%d:%02d%@", hour12, minute, suffix)
}

func shortRange(_ span: TimeSpan) -> String {
    let start = CostaRica.clock(span.start)
    let end = CostaRica.clock(span.end)
    if start.suffix(1) == end.suffix(1) {
        return "\(start.dropLast())–\(end)"
    }
    return "\(start)–\(end)"
}
