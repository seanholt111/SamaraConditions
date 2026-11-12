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
        let after = try date("2026-12-27T12:00:00-06:00")
        XCTAssertFalse(HeatScale.acclimating(after))
    }

    private func date(_ text: String) throws -> Date {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        return try XCTUnwrap(parser.date(from: text))
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
