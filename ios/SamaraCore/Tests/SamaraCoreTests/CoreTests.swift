import Foundation
import XCTest
@testable import SamaraCore

final class CoreTests: XCTestCase {
    func testStaleBoundaryIsOverThirtyHours() {
        let asOf = Date(timeIntervalSince1970: 1_700_000_000)
        let exactly = asOf.addingTimeInterval(30 * 3600)
        let justOver = asOf.addingTimeInterval(30 * 3600 + 1)
        XCTAssertFalse(Freshness.isStale(asOf: asOf, now: exactly))
        XCTAssertTrue(Freshness.isStale(asOf: asOf, now: justOver))
    }

    func testAsOfWording() throws {
        let asOf = try date("2026-11-11T05:02:00-06:00")
        let laterSameDay = try date("2026-11-11T17:00:00-06:00")
        let line = Freshness.line(asOf: asOf, now: laterSameDay)
        XCTAssertEqual(line.text, "as of 5:02a")
        XCTAssertFalse(line.stale)

        let nextAfternoon = try date("2026-11-12T17:00:00-06:00")
        let stale = Freshness.line(asOf: asOf, now: nextAfternoon)
        XCTAssertEqual(stale.text, "as of yesterday 5:02a · may be out of date")
        XCTAssertTrue(stale.stale)
        XCTAssertEqual(Freshness.offlineStrip(asOf: asOf), "Offline · showing 5:02a data")
    }

    func testCostaRicaClockIgnoresTheMachineZone() throws {
        let utc = try date("2026-11-12T04:00:00Z")
        XCTAssertEqual(CostaRica.clock(utc), "10:00p")
        XCTAssertEqual(CostaRica.dayChip(utc), "11 NOV")
        XCTAssertEqual(CostaRica.zone.secondsFromGMT(), -6 * 3600)
    }

    func testDecodeFixtureAndWednesdayWindow() throws {
        let file = try ConditionsFile.decode(Data(contentsOf: fixtureURL()))
        XCTAssertEqual(file.schemaVersion, 1)
        XCTAssertEqual(file.timezone, "America/Costa_Rica")
        XCTAssertEqual(file.week.energyQ1Kj, 126.1)
        XCTAssertEqual(file.week.energyMedianKj, 157.0)
        XCTAssertEqual(file.week.energyQ3Kj, 197.0)
        XCTAssertEqual(file.week.calmThresholdKj, 28.5)
        let wednesday = try XCTUnwrap(file.days.first)
        XCTAssertEqual(wednesday.date, "2026-11-11")
        XCTAssertEqual(wednesday.windows.beach.count, 1)
        XCTAssertEqual(CostaRica.clock(wednesday.windows.beach[0].start), "5:50a")
        XCTAssertEqual(CostaRica.clock(wednesday.windows.beach[0].end), "7:30a")
        XCTAssertTrue(wednesday.windows.beachLow.isEmpty)
        XCTAssertEqual(CostaRica.clock(wednesday.calmWindows[0].start), "7:30a")
        XCTAssertEqual(CostaRica.clock(wednesday.calmWindows[0].end), "12:40p")
        XCTAssertEqual(
            WindowText.tideHeader(calm: wednesday.calmWindows, wave: wednesday.waveWord),
            "Tide · Calm at shore 7:30a–12:40p · Waves normal"
        )
    }

    func testCacheRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let data = try Data(contentsOf: fixtureURL())
        try ConditionsCache.save(data, to: directory)
        let loaded = try XCTUnwrap(ConditionsCache.load(from: directory))
        let file = try ConditionsFile.decode(loaded)
        XCTAssertEqual(file.days.count, 7)
        try? FileManager.default.removeItem(at: directory)
    }

    func testTideCosineAndReef() throws {
        let file = try ConditionsFile.decode(Data(contentsOf: fixtureURL()))
        let extrema = file.extrema()
        let low = try XCTUnwrap(extrema.first { CostaRica.clock($0.time) == "9:56a" && !$0.isHigh })
        let height = try XCTUnwrap(TideMath.height(at: low.time, extrema: extrema))
        XCTAssertEqual(height, low.feet, accuracy: 0.01)
        let wednesday = try XCTUnwrap(file.days.first)
        let shelters = TideMath.reefShelters(extrema: extrema, sunrise: wednesday.sunrise, sunset: wednesday.sunset)
        XCTAssertFalse(shelters.isEmpty)
        XCTAssertEqual(CostaRica.clock(shelters[0].0), "7:34a")
        XCTAssertEqual(CostaRica.clock(shelters[0].1), "12:26p")
    }

    func testHeatZonesAndAcclimatizingWeek() throws {
        let november = try date("2026-11-11T12:00:00-06:00")
        let december = try date("2026-12-05T12:00:00-06:00")
        XCTAssertEqual(HeatScale.minutes(wbgt: 24.0, on: november), .minutes(50))
        XCTAssertEqual(HeatScale.minutes(wbgt: 24.0, on: december), .minutes(40))
        XCTAssertEqual(HeatScale.minutes(wbgt: 27.0, on: november), .minutes(40))
        XCTAssertEqual(HeatScale.minutes(wbgt: 32.3, on: november), .stop)
        XCTAssertEqual(HeatScale.minutes(wbgt: 30.1, on: december), .stop)
        XCTAssertFalse(HeatScale.acclimating(november))
        XCTAssertTrue(HeatScale.acclimating(december))
        let last = try date("2026-12-25T12:00:00-06:00")
        let firstCool = try date("2026-12-26T12:00:00-06:00")
        XCTAssertTrue(HeatScale.acclimating(last))
        XCTAssertFalse(HeatScale.acclimating(firstCool))
        let after = try date("2026-12-27T12:00:00-06:00")
        XCTAssertFalse(HeatScale.acclimating(after))
        XCTAssertEqual(HeatScale.verdict(wbgt: 26.0, on: november), .ok(play: 40, rest: 20))
        XCTAssertEqual(HeatScale.verdict(wbgt: 26.0, on: december), .capped(play: 30, rest: 30, outing: "<2 h"))
        XCTAssertEqual(HeatScale.verdict(wbgt: 32.3, on: november), .avoid)
    }

    func testWednesdayWindowsUseCareHoursAndOptionB() throws {
        let file = try ConditionsFile.decode(Data(contentsOf: fixtureURL()))
        let day = try XCTUnwrap(file.days.first)
        let sunset = CareDay.hour(day.sunset)
        func built(_ activity: ActivityKind, low: Bool = false, rulesDay: Date? = nil) -> ActivityPlan {
            ActivityWindows.plan(
                hours: day.hours, activity: activity, sunsetHour: sunset, rulesDay: rulesDay ?? day.sunrise,
                lowTide: low,
                lowHours: file.extrema().filter { !$0.isHigh && CostaRica.isSameDay($0.time, day.sunrise) }.map { CareDay.hour($0.time) },
                offshore: ActivityWindows.hourly(day.hours) { $0.energyOffshoreKj },
                upperQuartile: file.week.energyQ3Kj
            )
        }
        let beach = built(.beach)
        XCTAssertEqual(beach.okHoursText, "✓ 5½ h")
        XCTAssertTrue(beach.runs.contains { $0.verdict.isOk && $0.start == 6 })
        XCTAssertEqual(beach.darkNote, "Dark from 5:17p · no ocean after dark")
        XCTAssertNil(built(.soccerSun).darkNote)
        XCTAssertNil(built(.pool).darkNote)
        XCTAssertEqual(built(.jungle).darkNote, "Dark from 5:17p · trails: daylight only")
        XCTAssertEqual(built(.soccerShade).okHoursText, "All day")
        XCTAssertEqual(built(.jungle).runs.count, 1)
        XCTAssertNil(built(.jungle).minutesKey)
        XCTAssertNil(built(.pool).minutesKey)
        let sunday = try XCTUnwrap(file.days.first { $0.date == "2026-11-15" })
        let soccer = ActivityWindows.plan(hours: sunday.hours, activity: .soccerSun, sunsetHour: CareDay.hour(sunday.sunset), rulesDay: sunday.sunrise)
        XCTAssertEqual(soccer.runs.count, 3)
        XCTAssertEqual(soccer.runs[1].start, 7 + 40.0 / 60, accuracy: 0.01)
        XCTAssertEqual(soccer.runs[1].end, 16 + 35.0 / 60, accuracy: 0.01)
        XCTAssertEqual(soccer.minutesKey, "20/40 · ≤1 h")
        let december = try date("2026-12-10T12:00:00-06:00")
        let shifted = ActivityWindows.plan(hours: sunday.hours, activity: .beach, sunsetHour: CareDay.hour(sunday.sunset), rulesDay: december)
        XCTAssertEqual(shifted.runs.map { $0.start }, [6, 7, 8.5, 15, 18])
        XCTAssertTrue(built(.beach, rulesDay: december).runs.contains { $0.verdict == .avoid })
        XCTAssertFalse(built(.pool, rulesDay: december).runs.contains { $0.verdict == .avoid })
        XCTAssertEqual(built(.beach), built(.beach))
    }

    func testFahrenheitDoesNotMoveWindows() throws {
        let file = try ConditionsFile.decode(Data(contentsOf: fixtureURL()))
        let day = try XCTUnwrap(file.days.first)
        let displayed = TemperatureScale.fahrenheit.whole(27.88)
        XCTAssertEqual(displayed, "82°")
        XCTAssertEqual(TemperatureScale.celsius.whole(27.88), "28°")
        XCTAssertEqual(TemperatureScale.fahrenheit.threshold(32.3), "90.1 °F")
        let plan = ActivityWindows.plan(hours: day.hours, activity: .beach, sunsetHour: CareDay.hour(day.sunset), rulesDay: day.sunrise)
        XCTAssertEqual(plan.runs.map(\.start), plan.runs.map(\.start))
        XCTAssertNotNil(plan.minutesKey)
    }

    func testPillsStayInsideTheBand() {
        let widths = [88.0, 96.0]
        for band in [402.0 - 32, 393.0 - 32, 375.0 - 32] {
            for step in 0...180 {
                let line = 6.0 + Double(step) / 12 * (band / (15.0))
                let clamped = min(max(line, 0), band)
                let spans = PillLayout.place(line: clamped, widths: widths, bandWidth: band)
                XCTAssertGreaterThanOrEqual(spans[0].start, 6 - 0.01, "left \(clamped) \(band)")
                XCTAssertLessThanOrEqual(spans[1].end, band - 6 + 0.01, "right \(clamped) \(band)")
                if clamped > 14 && clamped < band - 14 {
                    XCTAssertFalse(PillLayout.lineSitsInGap(line: clamped, spans: spans))
                }
            }
        }
    }

    func testWednesdayCalmRunsThroughNine() throws {
        let file = try ConditionsFile.decode(Data(contentsOf: fixtureURL()))
        let day = try XCTUnwrap(file.days.first)
        let samples = SeaSeries.points(hours: day.hours, extrema: file.extrema(), day: day.sunrise)
        XCTAssertEqual(samples.first?.hour, 6)
        XCTAssertEqual(samples.last?.hour, 21)
        let calm = SeaSeries.calm(samples: samples, threshold: file.week.calmThresholdKj)
        let labels = calm.map { WindowWords.label(start: $0.start, end: $0.end) }
        XCTAssertTrue(labels.contains("7:30a–12:40p"), "\(labels)")
        XCTAssertTrue(labels.contains("From 7:40p"), "\(labels)")
    }

    func testLiveNov12SunStopHoursAreNineTenAndOne() throws {
        let file = try ConditionsFile.decode(Data(contentsOf: liveFixtureURL()))
        let day = try XCTUnwrap(file.day(on: date("2026-11-12T12:00:00-06:00")))
        let clocks = day.hours
            .filter { HeatScale.isStopHour(wbgt: $0.wbgtSunC, on: day.sunrise) }
            .map { CostaRica.clock($0.time) }
        XCTAssertEqual(clocks, ["9:00a", "10:00a", "1:00p"])
        XCTAssertFalse(day.hours.contains { HeatScale.isStopHour(wbgt: $0.wbgtShadeC, on: day.sunrise) })
    }

    func testLogRotatesAndKeepsTwoFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("samara-log-\(UUID().uuidString)", isDirectory: true)
        let log = AppLog(directory: directory, byteCap: 180)
        log.append("one", at: try date("2026-11-12T10:00:00-06:00"))
        log.append(String(repeating: "x", count: 200), at: try date("2026-11-12T10:01:00-06:00"))
        log.append("two", at: try date("2026-11-12T10:02:00-06:00"))
        let names = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).map(\.lastPathComponent)
        XCTAssertTrue(names.contains("log.txt"))
        XCTAssertTrue(names.contains("log.1.txt"))
        let current = try Data(contentsOf: directory.appendingPathComponent("log.txt"))
        XCTAssertLessThanOrEqual(current.count, 180)
        let exported = try String(contentsOf: log.exportFile(), encoding: .utf8)
        XCTAssertTrue(exported.contains(String(repeating: "x", count: 200)))
        XCTAssertTrue(exported.contains("two"))
        XCTAssertFalse(exported.contains(" one"))
        try FileManager.default.removeItem(at: directory)
    }

    private func date(_ text: String) throws -> Date {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        return try XCTUnwrap(parser.date(from: text))
    }

    private func liveFixtureURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("data/fixture-live-2026-11-12.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return url
    }

    private func fixtureURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<8 {
            url.deleteLastPathComponent()
            let candidate = url.appendingPathComponent("fixtures/conditions.fixture.json")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return url
    }
}
