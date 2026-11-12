import Foundation

public struct ConditionsFile: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var generatedAt: Date
    public var timezone: String
    public var feeds: Feeds
    public var week: WeekStats
    public var alerts: [OfficialAlert]
    public var tides: [TidePoint]
    public var days: [DayConditions]

    public static func decode(_ data: Data) throws -> ConditionsFile {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom(decodeDate)
        return try decoder.decode(ConditionsFile.self, from: data)
    }

    public func day(on date: Date) -> DayConditions? {
        let key = isoDay(date)
        return days.first { $0.date == key }
    }

    public func extrema() -> [TideExtremum] {
        tides.map { TideExtremum(time: $0.time, feet: $0.ft, isHigh: $0.type == "high") }
    }
}

public struct Feeds: Codable, Equatable, Sendable {
    public var forecast: FeedStamp
    public var marine: FeedStamp
    public var imn: FeedStamp
    public var tides: FeedStamp
}

public struct FeedStamp: Codable, Equatable, Sendable {
    public var asOf: Date
    public var ok: Bool
    public var source: String
}

public struct WeekStats: Codable, Equatable, Sendable {
    public var start: String
    public var end: String
    public var energyQ1Kj: Double
    public var energyMedianKj: Double
    public var energyQ3Kj: Double
    public var energyN: Int
    public var calmThresholdKj: Double
    public var hsMedianM: Double
    public var periodMedianS: Double
    public var ktAt3Ft: Double
}

public struct OfficialAlert: Codable, Equatable, Sendable, Identifiable {
    public var title: String
    public var summary: String
    public var url: String
    public var expires: String?
    public var id: String { title }

    public init(title: String, summary: String, url: String, expires: String?) {
        self.title = title
        self.summary = summary
        self.url = url
        self.expires = expires
    }
}

public struct TidePoint: Codable, Equatable, Sendable {
    public var time: Date
    public var type: String
    public var ft: Double
}

public struct TimeSpan: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

public struct Windows: Codable, Equatable, Sendable {
    public var beach: [TimeSpan]
    public var soccerSun: [TimeSpan]
    public var soccerShade: [TimeSpan]
    public var pool: [TimeSpan]
    public var jungle: [TimeSpan]
    public var beachLow: [TimeSpan]
}

public struct SeaPoint: Codable, Equatable, Sendable {
    public var time: Date
    public var energyOffshoreKj: Double
    public var energyShoreKj: Double
}

public struct HourPoint: Codable, Equatable, Sendable {
    public var time: Date
    public var tempC: Double
    public var rhPct: Double
    public var windMs: Double
    public var shortwaveWm2: Double
    public var pressureHpa: Double
    public var cloudPct: Double
    public var precipMm: Double
    public var uv: Double?
    public var wbgtSunC: Double
    public var wbgtShadeC: Double
    public var swellM: Double
    public var swellPeriodS: Double
    public var energyOffshoreKj: Double
    public var energyShoreKj: Double?
}

public struct DayConditions: Codable, Equatable, Sendable, Identifiable {
    public var date: String
    public var weekday: String
    public var sunrise: Date
    public var sunset: Date
    public var dataKind: String
    public var precipMm: Double
    public var precipOffAxisMm: Double
    public var cloudDaylightMeanPct: Int
    public var energyMedianKj: Double?
    public var waveWord: String
    public var reefShelters: [TimeSpan]
    public var tideExtrema: [TidePoint]
    public var windows: Windows
    public var calmWindows: [TimeSpan]
    public var sea: [SeaPoint]
    public var hours: [HourPoint]
    public var id: String { date }

    public func spans(for activity: ActivityKind, lowTideOnly: Bool) -> [TimeSpan] {
        switch activity {
        case .beach: return lowTideOnly ? windows.beachLow : windows.beach
        case .soccerSun: return windows.soccerSun
        case .soccerShade: return windows.soccerShade
        case .pool: return windows.pool
        case .jungle: return windows.jungle
        }
    }
}

public enum ActivityKind: String, CaseIterable, Sendable {
    case beach, soccerSun, soccerShade, pool, jungle

    public var title: String {
        switch self {
        case .beach: return "Beach"
        case .soccerSun: return "Soccer\nsun"
        case .soccerShade: return "Soccer\nshade"
        case .pool: return "Pool"
        case .jungle: return "Jungle"
        }
    }
}

public struct TideBundleFile: Codable, Sendable {
    public var hilo: [Row]
    public struct Row: Codable, Sendable {
        public var t: String
        public var ft: Double
        public var type: String
    }

    public func extrema() -> [TideExtremum] {
        let formatter = DateFormatter()
        formatter.calendar = CostaRica.calendar
        formatter.timeZone = CostaRica.zone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return hilo.compactMap { row in
            guard let time = formatter.date(from: row.t) else { return nil }
            return TideExtremum(time: time, feet: row.ft, isHigh: row.type == "H")
        }
    }
}

public enum ConditionsCache {
    public static func fileURL(in directory: URL) -> URL {
        directory.appendingPathComponent("conditions.json")
    }

    public static func load(from directory: URL) -> Data? {
        let url = fileURL(in: directory)
        return try? Data(contentsOf: url)
    }

    public static func save(_ data: Data, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(in: directory), options: .atomic)
    }
}

private func decodeDate(_ decoder: Decoder) throws -> Date {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    let parser = ISO8601DateFormatter()
    parser.formatOptions = [.withInternetDateTime]
    if let date = parser.date(from: text) { return date }
    parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = parser.date(from: text) { return date }
    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date \(text)")
}

private func isoDay(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = CostaRica.calendar
    formatter.timeZone = CostaRica.zone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
