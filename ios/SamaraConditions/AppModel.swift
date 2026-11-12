import Foundation
import SamaraCore

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case loaded(ConditionsFile)
        case failed
    }

    enum Section: String { case today, week }
    enum WeekTab: String, CaseIterable { case heat, rain, cloud, sea }

    @Published var phase: Phase = .loading
    @Published var offline = false
    @Published var activity: ActivityKind = .beach
    @Published var lowTideOnly = false
    @Published var section: Section = .today
    @Published var weekTab: WeekTab = .heat
    @Published var showSources = false
    @Published var selectedAlert: OfficialAlert?
    @Published var scrub: Date?
    @Published var now = Date()

    let pagesURL = URL(string: "https://seanholt111.github.io/SamaraConditions/conditions.json")!
    private let cacheDirectory: URL
    private var uiTesting = false
    private var bundled: [TideExtremum] = []

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        cacheDirectory = base.appendingPathComponent("SamaraConditions", isDirectory: true)
        applyLaunchArguments()
    }

    var file: ConditionsFile? {
        if case .loaded(let file) = phase { return file }
        return nil
    }

    func boot() async {
        if uiTesting { return }
        if let cached = ConditionsCache.load(from: cacheDirectory),
           let file = try? ConditionsFile.decode(cached) {
            phase = .loaded(file)
        } else {
            phase = .loading
        }
        await refresh()
    }

    func refresh() async {
        if uiTesting { return }
        do {
            var request = URLRequest(url: pagesURL, timeoutInterval: 20)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let decoded = try ConditionsFile.decode(data)
            try ConditionsCache.save(data, to: cacheDirectory)
            phase = .loaded(decoded)
            offline = false
        } catch {
            offline = true
            if file == nil {
                phase = .failed
            }
        }
    }

    func extrema(for file: ConditionsFile) -> [TideExtremum] {
        let fromFile = file.extrema()
        if fromFile.count >= 4 { return fromFile }
        if bundled.isEmpty { bundled = loadBundledTides() }
        return bundled.isEmpty ? fromFile : bundled
    }

    func today(_ file: ConditionsFile) -> DayConditions? {
        file.day(on: now) ?? file.days.first
    }

    func orderedDays(_ file: ConditionsFile) -> [(offset: Int, day: DayConditions?)] {
        (0..<7).map { offset in
            let date = CostaRica.dayOffset(offset, from: now)
            return (offset, file.day(on: date))
        }
    }

    func fileIsStale(_ file: ConditionsFile) -> Bool {
        Freshness.isStale(asOf: file.generatedAt, now: now)
    }

    func feedIsStale(_ stamp: FeedStamp, file: ConditionsFile) -> Bool {
        !fileIsStale(file) && Freshness.isStale(asOf: stamp.asOf, now: now)
    }

    private func applyLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? {
            guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else { return nil }
            return args[index + 1]
        }
        if let raw = value("-now"), let date = ISO8601DateFormatter.internet.date(from: raw) {
            now = date
        }
        if let raw = value("-activity") {
            switch raw {
            case "soccer-sun": activity = .soccerSun
            case "soccer-shade": activity = .soccerShade
            case "pool": activity = .pool
            case "jungle": activity = .jungle
            default: activity = .beach
            }
        }
        if value("-low-tide") == "1" { lowTideOnly = true }
        if let raw = value("-tab"), let section = Section(rawValue: raw) { self.section = section }
        if let raw = value("-week"), let tab = WeekTab(rawValue: raw) { weekTab = tab }
        if value("-show-sources") == "1" { showSources = true }
        let state = value("-ui-state")
        let useFixture = args.contains("-use-fixture") || state != nil
        guard useFixture, let url = Bundle.main.url(forResource: "conditions.fixture", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              var decoded = try? ConditionsFile.decode(data) else { return }
        uiTesting = true
        switch state ?? "fresh" {
        case "loading":
            phase = .loading
        case "error":
            phase = .failed
        case "stale":
            let old = clockOnPreviousDay(decoded.generatedAt, before: now)
            decoded.generatedAt = old
            decoded.feeds.forecast.asOf = old
            decoded.feeds.marine.asOf = old
            decoded.feeds.imn.asOf = old
            decoded.feeds.tides.asOf = old
            phase = .loaded(decoded)
        case "stale-tide":
            decoded.feeds.tides.asOf = clockOnPreviousDay(decoded.feeds.tides.asOf, before: now)
            phase = .loaded(decoded)
        case "offline":
            offline = true
            phase = .loaded(decoded)
        case "imn":
            decoded.alerts = [OfficialAlert(
                title: "EXAMPLE High surf, Puntarenas",
                summary: "Example official notice for the layout. A real alert uses the IMN title and text, unchanged.",
                url: "https://www.imn.ac.cr/",
                expires: nil
            )]
            phase = .loaded(decoded)
        default:
            phase = .loaded(decoded)
        }
    }

    private func clockOnPreviousDay(_ time: Date, before now: Date) -> Date {
        let calendar = CostaRica.calendar
        let parts = calendar.dateComponents([.hour, .minute], from: time)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: CostaRica.startOfDay(now)) ?? now
        return calendar.date(bySettingHour: parts.hour ?? 5, minute: parts.minute ?? 2, second: 0, of: yesterday) ?? yesterday
    }

    private func loadBundledTides() -> [TideExtremum] {
        guard let url = Bundle.main.url(forResource: "tides-puntarenas-2026-2027", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bundle = try? JSONDecoder().decode(TideBundleFile.self, from: data) else { return [] }
        return bundle.extrema()
    }
}

private extension ISO8601DateFormatter {
    static let internet: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
