import SamaraCore
import SwiftUI

enum SeriesKind { case sun, shade }

func sample(_ hours: [HourPoint], at date: Date, _ pick: (HourPoint) -> Double) -> Double {
    guard let first = hours.first else { return 0 }
    if date <= first.time { return pick(first) }
    if let last = hours.last, date >= last.time { return pick(last) }
    for pair in zip(hours, hours.dropFirst()) {
        if date >= pair.0.time && date <= pair.1.time {
            let span = pair.1.time.timeIntervalSince(pair.0.time)
            let fraction = span > 0 ? date.timeIntervalSince(pair.0.time) / span : 0
            return pick(pair.0) + (pick(pair.1) - pick(pair.0)) * fraction
        }
    }
    return pick(first)
}

func hourBin(_ hours: [HourPoint], at date: Date) -> HourPoint? {
    hours.first { date >= $0.time && date < $0.time.addingTimeInterval(3600) }
}

struct TodayChart: View {
    let day: DayConditions
    let extrema: [TideExtremum]
    let activity: ActivityKind
    let lowTideOnly: Bool
    let now: Date
    var forecastStale: Bool
    var tideStale: Bool
    var marineStale: Bool
    var forecastAsOf: Date
    var tideAsOf: Date
    var marineAsOf: Date
    var staleNow: Date
    @Binding var scrub: Date?

    private var axis: PlotAxis {
        PlotAxis(start: day.sunrise, end: day.sunset)
    }

    private var shown: Date { scrub ?? now }

    var body: some View {
        VStack(spacing: 6) {
            readout
            sky
            tide
            heat
            hourLabels
            WindowRibbon(
                spans: day.spans(for: activity, lowTideOnly: lowTideOnly),
                axis: axis,
                emptyText: "No window"
            )
        }
    }

    private var readout: some View {
        let sun = sample(day.hours, at: shown, \.wbgtSunC)
        let shade = sample(day.hours, at: shown, \.wbgtShadeC)
        return HStack(spacing: 8) {
            Capsule().fill(.white).frame(width: 16, height: 3)
            Text(tempText(sun)).font(SamaraFont.readout()).foregroundStyle(Palette.text)
                .accessibilityIdentifier("sun-temp")
            Capsule().stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 2])).frame(width: 16, height: 3)
                .foregroundStyle(.white)
            Text(tempText(shade)).font(SamaraFont.readout()).foregroundStyle(Palette.text)
                .accessibilityIdentifier("shade-temp")
            Spacer()
        }
    }

    private var sky: some View {
        ZStack(alignment: .topLeading) {
            Palette.track
            Canvas { context, size in
                let hours = day.hours.filter {
                    $0.time < axis.end && $0.time.addingTimeInterval(3600) > axis.start
                }
                for hour in hours {
                    let visibleStart = max(hour.time, axis.start)
                    let visibleEnd = min(hour.time.addingTimeInterval(3600), axis.end)
                    let x = axis.x(visibleStart, width: size.width)
                    let next = axis.x(visibleEnd, width: size.width)
                    let width = max(1, next - x)
                    let cloudH = size.height * CGFloat(min(100, hour.cloudPct) / 100) * 0.86
                    let cloudRect = CGRect(x: x, y: size.height - cloudH - 4, width: width, height: cloudH)
                    context.fill(Path(cloudRect), with: .color(Palette.cloud.opacity(0.9)))
                    if hour.precipMm > 0 {
                        let rainH = size.height * CGFloat(min(1, hour.precipMm)) * 0.86
                        let rainRect = CGRect(x: x, y: size.height - rainH - 4, width: width, height: rainH)
                        context.fill(Path(rainRect), with: .color(Palette.mid))
                    }
                }
            }
            HStack(spacing: 8) {
                if forecastStale {
                    Text(Freshness.blockHeader(name: "Clouds", asOf: forecastAsOf, now: staleNow))
                        .foregroundStyle(Palette.amber)
                } else {
                    Text("Clouds").foregroundStyle(Palette.cloud)
                    Text("Rain").foregroundStyle(Palette.mid)
                }
            }
            .font(SamaraFont.band())
            .padding(8)
        }
        .frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("sky-band")
    }

    private var tide: some View {
        let headline = WindowText.tideHeader(calm: day.calmWindows, wave: day.waveWord)
        let maxTide = daylightMaxTide()
        let tideScale: CGFloat = (86 - 8) / 10
        return ZStack(alignment: .topLeading) {
            Palette.track
            Canvas { context, size in
                var crest = Path()
                let steps = 80
                var points: [CGPoint] = []
                for step in 0...steps {
                    let fraction = Double(step) / Double(steps)
                    let when = axis.start.addingTimeInterval(axis.end.timeIntervalSince(axis.start) * fraction)
                    let feet = TideMath.height(at: when, extrema: extrema) ?? 0
                    let y = tideY(feet, maxFeet: maxTide, scale: tideScale)
                    points.append(CGPoint(x: CGFloat(fraction) * size.width, y: y))
                }
                guard let first = points.first, let last = points.last else { return }
                crest.move(to: first)
                points.dropFirst().forEach { crest.addLine(to: $0) }
                var fill = crest
                fill.addLine(to: CGPoint(x: last.x, y: size.height))
                fill.addLine(to: CGPoint(x: first.x, y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .linearGradient(
                    Gradient(colors: [Palette.lagoon, Palette.mid, Palette.ocean, Palette.deep]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                context.stroke(crest, with: .color(.white), lineWidth: 1.4)
                let reefY = tideY(3, maxFeet: maxTide, scale: tideScale)
                var reef = Path()
                reef.move(to: CGPoint(x: 0, y: reefY))
                reef.addLine(to: CGPoint(x: size.width, y: reefY))
                context.stroke(reef, with: .color(.white.opacity(0.85)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                context.draw(Text("reef").font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.8)), at: CGPoint(x: size.width * 0.72, y: reefY - 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    if tideStale {
                        Text(Freshness.blockHeader(name: "Tide", asOf: tideAsOf, now: staleNow))
                            .foregroundStyle(Palette.amber)
                            .accessibilityIdentifier("tide-stale")
                    } else {
                        Text(headline)
                            .foregroundStyle(marineStale ? Palette.amber : Palette.lagoon)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .accessibilityIdentifier("tide-header")
                    }
                }
                .font(SamaraFont.band())
            }
            .padding(8)
        }
        .frame(height: tideTrackHeight(maxFeet: maxTide, scale: tideScale))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("tide-band")
    }

    private var heat: some View {
        Canvas { context, size in
            let minV = 22.0
            let maxV = 34.0
            func y(_ value: Double) -> CGFloat {
                let fraction = (value - minV) / (maxV - minV)
                return size.height - CGFloat(min(1, max(0, fraction))) * size.height
            }
            struct HeatSample {
                var x: CGFloat
                var sun: Double
                var shade: Double
                var sunZone: HeatMinutes
                var shadeZone: HeatMinutes
            }
            var samples: [HeatSample] = []
            let step = 5.0 * 60
            var cursor = axis.start
            while cursor <= axis.end {
                let sun = sample(day.hours, at: cursor, \.wbgtSunC)
                let shade = sample(day.hours, at: cursor, \.wbgtShadeC)
                let bin = hourBin(day.hours, at: min(cursor.addingTimeInterval(1), axis.end))
                let sunZone = (bin?.wbgtSunC).map { HeatScale.isStopHour(wbgt: $0, on: day.sunrise) } == true
                    ? HeatMinutes.stop
                    : HeatScale.minutes(wbgt: sun, on: day.sunrise)
                let shadeZone = (bin?.wbgtShadeC).map { HeatScale.isStopHour(wbgt: $0, on: day.sunrise) } == true
                    ? HeatMinutes.stop
                    : HeatScale.minutes(wbgt: shade, on: day.sunrise)
                samples.append(HeatSample(x: axis.x(cursor, width: size.width), sun: sun, shade: shade, sunZone: sunZone, shadeZone: shadeZone))
                cursor = cursor.addingTimeInterval(step)
            }
            func paint(_ zone: HeatMinutes, _ path: Path) {
                if zone == .stop {
                    context.fill(path, with: .color(Palette.hatch))
                    hatch(in: path.boundingRect, context: context, gap: 5)
                } else {
                    context.fill(path, with: .color(Palette.zone(zone)))
                }
            }
            func runs(of key: KeyPath<HeatSample, HeatMinutes>) -> [Range<Int>] {
                var result: [Range<Int>] = []
                var start = 0
                for index in samples.indices.dropFirst() {
                    if samples[index][keyPath: key] != samples[start][keyPath: key] {
                        result.append(start..<index)
                        start = index - 1
                    }
                }
                if !samples.isEmpty { result.append(start..<samples.count) }
                return result
            }
            for run in runs(of: \.shadeZone) {
                let slice = Array(samples[run])
                guard let first = slice.first, let last = slice.last else { continue }
                var path = Path()
                path.move(to: CGPoint(x: first.x, y: size.height))
                slice.forEach { path.addLine(to: CGPoint(x: $0.x, y: y($0.shade))) }
                path.addLine(to: CGPoint(x: last.x, y: size.height))
                path.closeSubpath()
                paint(first.shadeZone, path)
            }
            for run in runs(of: \.sunZone) {
                let slice = Array(samples[run])
                guard slice.count > 1, let first = slice.first else { continue }
                var path = Path()
                path.move(to: CGPoint(x: first.x, y: y(first.shade)))
                slice.forEach { path.addLine(to: CGPoint(x: $0.x, y: y(max($0.sun, $0.shade)))) }
                slice.reversed().forEach { path.addLine(to: CGPoint(x: $0.x, y: y(min($0.sun, $0.shade)))) }
                path.closeSubpath()
                paint(first.sunZone, path)
            }
            var sunPath = Path()
            var shadePath = Path()
            var started = false
            var walk = axis.start
            while walk <= axis.end {
                let x = axis.x(walk, width: size.width)
                let sunY = y(sample(day.hours, at: walk, \.wbgtSunC))
                let shadeY = y(sample(day.hours, at: walk, \.wbgtShadeC))
                if started {
                    sunPath.addLine(to: CGPoint(x: x, y: sunY))
                    shadePath.addLine(to: CGPoint(x: x, y: shadeY))
                } else {
                    sunPath.move(to: CGPoint(x: x, y: sunY))
                    shadePath.move(to: CGPoint(x: x, y: shadeY))
                    started = true
                }
                walk = walk.addingTimeInterval(10 * 60)
            }
            casedLine(shadePath, context: context, dashed: true)
            casedLine(sunPath, context: context, dashed: false)
            if shown >= axis.start && shown <= axis.end {
                let x = axis.x(shown, width: size.width)
                var nowLine = Path()
                nowLine.move(to: CGPoint(x: x, y: 6))
                nowLine.addLine(to: CGPoint(x: x, y: size.height - 7))
                context.stroke(nowLine, with: .color(Palette.muted.opacity(0.9)), lineWidth: 1)
                let sunDot = CGPoint(x: x, y: y(sample(day.hours, at: shown, \.wbgtSunC)))
                let shadeDot = CGPoint(x: x, y: y(sample(day.hours, at: shown, \.wbgtShadeC)))
                for dot in [sunDot, shadeDot] {
                    let rect = CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)), with: .color(Palette.night))
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
            if let labelTime = CostaRica.calendar.date(bySettingHour: 13, minute: 30, second: 0, of: day.sunrise) {
                let x = axis.x(labelTime, width: size.width)
                context.draw(Text("Sun").font(.system(size: 13, weight: .bold)).foregroundColor(.white), at: CGPoint(x: x, y: y(sample(day.hours, at: labelTime, \.wbgtSunC)) - 12))
                context.draw(Text("Shade").font(.system(size: 13, weight: .bold)).foregroundColor(.white), at: CGPoint(x: x, y: y(sample(day.hours, at: labelTime, \.wbgtShadeC)) + 14))
            }
        }
        .frame(minHeight: 230)
        .overlay(alignment: .topLeading) {
            Text("Heat")
                .font(SamaraFont.band())
                .foregroundStyle(forecastStale ? Palette.amber : Palette.muted)
                .padding(8)
        }
        .overlay {
            GeometryReader { geo in
                Color.clear.contentShape(Rectangle()).gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        scrub = axis.date(atX: value.location.x, width: geo.size.width)
                    }.onEnded { _ in scrub = nil }
                )
            }
        }
        .accessibilityIdentifier("heat-plot")
    }

    private func daylightMaxTide() -> Double {
        var peak = 0.0
        let steps = 80
        for step in 0...steps {
            let fraction = Double(step) / Double(steps)
            let when = axis.start.addingTimeInterval(axis.end.timeIntervalSince(axis.start) * fraction)
            peak = max(peak, TideMath.height(at: when, extrema: extrema) ?? 0)
        }
        return peak
    }

    private var hourLabels: some View {
        GeometryReader { geo in
            let ticks = daylightTicks(sunrise: day.sunrise, sunset: day.sunset)
            ZStack(alignment: .leading) {
                ForEach(Array(ticks.enumerated()), id: \.offset) { _, time in
                    let raw = axis.x(time, width: geo.size.width)
                    let x = min(max(raw, 18), max(18, geo.size.width - 20))
                    Text(axisTick(time))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .position(x: x, y: 8)
                }
            }
        }
        .frame(height: 16)
    }
}

private func tideY(_ feet: Double, maxFeet: Double, scale: CGFloat) -> CGFloat {
    let oldY = 86 - 4 - CGFloat(feet) * scale
    let oldPeak = 86 - 4 - CGFloat(maxFeet) * scale
    return oldY + max(0, 16 - oldPeak)
}

private func tideTrackHeight(maxFeet: Double, scale: CGFloat) -> CGFloat {
    let oldPeak = 86 - 4 - CGFloat(maxFeet) * scale
    return 86 + max(0, 16 - oldPeak)
}

private func calmPhrase(_ spans: [TimeSpan]) -> String {
    spans.isEmpty ? "no calm" : spans.map(WindowText.range).joined(separator: " · ")
}

private func daylightTicks(sunrise: Date, sunset: Date) -> [Date] {
    var ticks = [sunrise]
    for hour in [9, 12, 15] {
        guard let time = CostaRica.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: sunrise) else { continue }
        if time > sunrise.addingTimeInterval(45 * 60) && time < sunset.addingTimeInterval(-45 * 60) {
            ticks.append(time)
        }
    }
    ticks.append(sunset)
    return ticks
}

struct WeekBars: View {
    let days: [(offset: Int, day: DayConditions?)]
    var rain: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Text(rain ? "full bar = 1 mm/hr" : "full bar = 100% cloud")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.muted)
            ForEach(days, id: \.offset) { item in
                row(item.offset, item.day)
            }
            axis
        }
    }

    private func row(_ offset: Int, _ day: DayConditions?) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.map { "\($0.weekday) \(String($0.date.suffix(2)))" } ?? "—")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Text(label(day))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
                    .frame(width: 118, alignment: .leading)
            }
            .frame(width: 124, alignment: .leading)
            .opacity(offset >= 3 ? 0.5 : 1)
            strip(day).opacity(offset >= 3 ? 0.45 : 1)
        }
    }

    private func label(_ day: DayConditions?) -> String {
        guard let day else { return " " }
        if rain {
            if day.precipMm <= 0 { return "dry" }
            let base = String(format: "%.1f mm", day.precipMm)
            if day.precipMm > 0, day.precipOffAxisMm / day.precipMm >= 0.4 {
                return base + String(format: " · %.1f after dark", day.precipOffAxisMm)
            }
            return base
        }
        return "\(day.cloudDaylightMeanPct)%"
    }

    private func strip(_ day: DayConditions?) -> some View {
        Canvas { context, size in
            let track = CGRect(x: 0, y: 4, width: size.width, height: 24)
            context.fill(Path(roundedRect: track, cornerRadius: 4), with: .color(Palette.track))
            var hair = Path()
            hair.move(to: CGPoint(x: 0, y: 4))
            hair.addLine(to: CGPoint(x: size.width, y: 4))
            context.stroke(hair, with: .color(.white.opacity(0.12)), lineWidth: 1)
            guard let day else { return }
            let start = CostaRica.calendar.date(bySettingHour: 6, minute: 0, second: 0, of: day.sunrise) ?? day.sunrise
            let end = CostaRica.calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day.sunrise) ?? day.sunset
            let axis = PlotAxis(start: start, end: end)
            for hour in day.hours where hour.time >= start && hour.time < end {
                let x = axis.x(hour.time, width: size.width)
                let next = axis.x(hour.time.addingTimeInterval(3600), width: size.width)
                let width = max(1, next - x - 1)
                let fraction: CGFloat = rain ? CGFloat(min(1, hour.precipMm)) : CGFloat(min(100, hour.cloudPct) / 100)
                let height = max(0, (track.height - 2) * fraction)
                let rect = CGRect(x: x, y: track.maxY - height - 1, width: width, height: height)
                context.fill(Path(rect), with: .color(rain ? Palette.mid : Palette.cloud))
                if rain, hour.precipMm > 1 {
                    context.draw(
                        Text(String(format: "%.1f", hour.precipMm)).font(.system(size: 9, weight: .bold)).foregroundColor(.white),
                        at: CGPoint(x: rect.midX, y: max(8, rect.minY - 6))
                    )
                }
            }
        }
        .frame(height: 36)
    }

    private var axis: some View {
        HStack {
            Color.clear.frame(width: 132)
            HStack {
                ForEach(["6a", "9a", "12p", "3p", "5p"], id: \.self) { tick in
                    Text(tick).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
                    if tick != "5p" { Spacer() }
                }
            }
        }
    }
}

struct WeekSea: View {
    let days: [(offset: Int, day: DayConditions?)]
    let threshold: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("full height = 210 kJ")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.muted)
            ForEach(days, id: \.offset) { item in
                seaRow(item.offset, item.day)
            }
            HStack {
                Color.clear.frame(width: 58)
                HStack {
                    ForEach(["6a", "9a", "12p", "3p", "5p"], id: \.self) { tick in
                        Text(tick).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
                        if tick != "5p" { Spacer() }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("fill = energy at the shore · dotted = offshore · dashes = calm line")
                Text("model, not measured · reef size and gaps guessed")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private func seaRow(_ offset: Int, _ day: DayConditions?) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(day.map { "\($0.weekday) \(String($0.date.suffix(2)))" } ?? "—")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.text)
                .frame(width: 52, alignment: .leading)
                .padding(.top, 10)
                .opacity(offset >= 3 ? 0.5 : 1)
            VStack(spacing: 3) {
                Canvas { context, size in
                    let rect = CGRect(origin: .zero, size: size)
                    context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Palette.track))
                    guard let day, !day.sea.isEmpty else { return }
                    let axis = PlotAxis(start: day.sea.first!.time, end: day.sea.last!.time)
                    func y(_ value: Double) -> CGFloat {
                        size.height - CGFloat(min(210, max(0, value)) / 210) * (size.height - 2) - 1
                    }
                    var fill = Path()
                    var shore = Path()
                    var off = Path()
                    for (index, point) in day.sea.enumerated() {
                        let x = axis.x(point.time, width: size.width)
                        let shorePoint = CGPoint(x: x, y: y(point.energyShoreKj))
                        let offPoint = CGPoint(x: x, y: y(point.energyOffshoreKj))
                        if index == 0 {
                            fill.move(to: CGPoint(x: x, y: size.height))
                            fill.addLine(to: shorePoint)
                            shore.move(to: shorePoint)
                            off.move(to: offPoint)
                        } else {
                            fill.addLine(to: shorePoint)
                            shore.addLine(to: shorePoint)
                            off.addLine(to: offPoint)
                        }
                    }
                    if let last = day.sea.last {
                        fill.addLine(to: CGPoint(x: axis.x(last.time, width: size.width), y: size.height))
                        fill.closeSubpath()
                    }
                    context.fill(fill, with: .color(Palette.ocean))
                    context.stroke(shore, with: .color(.white), lineWidth: 1.3)
                    context.stroke(off, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    var calm = Path()
                    let calmY = y(threshold)
                    calm.move(to: CGPoint(x: 0, y: calmY))
                    calm.addLine(to: CGPoint(x: size.width, y: calmY))
                    context.stroke(calm, with: .color(Palette.lagoon), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                }
                .frame(height: 38)
                .opacity(offset >= 3 ? 0.45 : 1)
                if let day {
                    WindowRibbon(
                        spans: day.calmWindows,
                        axis: PlotAxis(start: day.sea.first?.time ?? day.sunrise, end: day.sea.last?.time ?? day.sunset),
                        emptyText: "no calm",
                        height: 16,
                        fill: .white,
                        ink: Palette.night,
                        labelSize: 11,
                        largeSize: 11,
                        alwaysRange: true
                    )
                }
            }
        }
    }
}

struct WeekHeat: View {
    let days: [(offset: Int, day: DayConditions?)]
    let activity: ActivityKind
    let lowTideOnly: Bool

    var body: some View {
        VStack(spacing: 8) {
            ForEach(days, id: \.offset) { item in
                heatRow(item.offset, item.day)
            }
        }
    }

    private func heatRow(_ offset: Int, _ day: DayConditions?) -> some View {
        return HStack(alignment: .center, spacing: 8) {
            Text(day.map { "\($0.weekday) \(String($0.date.suffix(2)))" } ?? "—")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.text)
                .opacity(offset >= 3 ? 0.45 : 1)
                .frame(width: 58, alignment: .leading)
            VStack(spacing: 3) {
                Canvas { context, size in
                    guard let day else { return }
                    let axis = PlotAxis(start: day.sunrise, end: day.sunset)
                    let shade = activity.heatUsesShade
                    var runs: [(start: Date, end: Date, zone: HeatMinutes)] = []
                    let step = 5.0 * 60
                    var cursor = day.sunrise
                    while cursor < day.sunset {
                        let next = min(day.sunset, cursor.addingTimeInterval(step))
                        let bin = hourBin(day.hours, at: cursor.addingTimeInterval(1))
                        let value = shade ? (bin?.wbgtShadeC ?? 25) : (bin?.wbgtSunC ?? 25)
                        let zone = HeatScale.minutes(wbgt: value, on: day.sunrise)
                        if let last = runs.last, last.zone == zone, last.end == cursor {
                            runs[runs.count - 1].end = next
                        } else {
                            runs.append((cursor, next, zone))
                        }
                        cursor = next
                    }
                    for run in runs {
                        let x0 = axis.x(run.start, width: size.width)
                        let x1 = axis.x(run.end, width: size.width)
                        let rect = CGRect(x: x0, y: 0, width: max(1, x1 - x0 + 0.6), height: size.height)
                        if run.zone == .stop {
                            context.fill(Path(rect), with: .color(Palette.hatch))
                            hatch(in: rect, context: context, gap: 4)
                        } else {
                            context.fill(Path(rect), with: .color(Palette.zone(run.zone)))
                        }
                    }
                }
                .frame(height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                .opacity(offset >= 3 ? 0.45 : 1)
                if let day {
                    WindowRibbon(
                        spans: day.spans(for: activity, lowTideOnly: lowTideOnly),
                        axis: PlotAxis(start: day.sunrise, end: day.sunset),
                        emptyText: "no window",
                        height: 22
                    )
                }
            }
        }
    }
}
