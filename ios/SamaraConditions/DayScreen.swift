import SamaraCore
import SwiftUI

struct DayScreen: View {
    @EnvironmentObject private var model: AppModel
    let day: DayConditions
    let file: ConditionsFile
    let extrema: [TideExtremum]

    private var axis: PlotAxis {
        PlotAxis(start: CareDay.start(on: day.sunrise), end: CareDay.end(on: day.sunrise))
    }
    private var scale: TemperatureScale { model.useFahrenheit ? .fahrenheit : .celsius }
    private var shown: Date { model.scrub ?? model.now }
    private var dragging: Bool { model.scrub != nil }
    private var sunsetHour: Double { CareDay.hour(day.sunset) }
    private var sun: [Double] { ActivityWindows.hourly(day.hours) { $0.wbgtSunC } }
    private var shade: [Double] { ActivityWindows.hourly(day.hours) { $0.wbgtShadeC } }
    private var sea: [SeaSample] {
        SeaSeries.points(hours: day.hours, extrema: extrema, day: day.sunrise)
    }
    private var calm: [HourSpan] {
        SeaSeries.calm(samples: sea, threshold: file.week.calmThresholdKj)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            readout
            chart
            SlimTimeRow(runs: play.runs, axis: axis, day: day.sunrise, minutes: play.minutesKey)
            if let note = play.darkNote {
                Text(note).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
            }
            if let note = play.uvNote {
                Text(note).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
            }
            MinutesKey(showStop: play.runs.contains { $0.verdict == .avoid })
        }
        .accessibilityElement(children: .combine)
        .safeAreaInset(edge: .bottom, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                ActivityChips()
                LowTideToggle()
            }
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.night)
        }
    }

    private var play: ActivityPlan { model.activityPlan(model.activity, day: day, file: file) }

    private var windowSpans: [TimeSpan] {
        let lows = extrema.filter { !$0.isHigh && CostaRica.isSameDay($0.time, day.sunrise) }.map { CareDay.hour($0.time) }
        return ActivityWindows.spans(
            sun: sun, shade: shade, activity: model.activity, sunsetHour: sunsetHour,
            lowTide: model.lowTideOnly,
            lowHours: lows,
            offshore: ActivityWindows.hourly(day.hours) { $0.energyOffshoreKj },
            upperQuartile: file.week.energyQ3Kj
        ).map { TimeSpan(start: CareDay.date(hour: $0.start, on: day.sunrise), end: CareDay.date(hour: $0.end, on: day.sunrise)) }
    }

    private var axisTicks: some View {
        GeometryReader { geo in
            ForEach([6, 9, 12, 15, 18, 21], id: \.self) { hour in
                let label = hour == 12 ? "12p" : (hour < 12 ? "\(hour)a" : "\(hour - 12)p")
                let x = geo.size.width * CGFloat(hour - 6) / 15
                Text(label)
                    .font(.system(size: 11 * model.typeScale, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .position(x: hour == 6 ? 10 : (hour == 21 ? geo.size.width - 10 : x), y: 8)
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }

    private var readout: some View {
        let stack = dragging && model.typeScale > 1.2
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                readoutTemps
                if dragging && !stack { readoutUnit }
                Spacer(minLength: 4)
                if dragging { readoutTime }
            }
            if stack { readoutUnit }
        }
        .foregroundStyle(Palette.text)
    }

    private var readoutTemps: some View {
        let sunC = ActivityWindows.interpolate(sun, CareDay.hour(model.viewingToday ? shown : maxSunHour))
        let shadeC = ActivityWindows.interpolate(shade, CareDay.hour(model.viewingToday ? shown : maxShadeHour))
        let oneValue = scale.whole(sunC) == scale.whole(shadeC)
        return HStack(spacing: 8) {
            if !model.viewingToday && !dragging {
                Text("high").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.muted)
            }
            if oneValue {
                Capsule().fill(.white).frame(width: 16, height: 3)
                Text(scale.whole(shadeC))
                    .font(.system(size: 22 * model.typeScale, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                Text("sun = shade")
                    .font(.system(size: 13 * model.typeScale, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityIdentifier("sun-shade-equal")
            } else {
                Capsule().fill(.white).frame(width: 16, height: 3)
                Text(scale.whole(sunC))
                    .font(.system(size: 22 * model.typeScale, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityIdentifier("sun-temp")
                Capsule().stroke(style: StrokeStyle(lineWidth: 2, dash: [3, 2])).frame(width: 16, height: 3)
                Text(scale.whole(shadeC))
                    .font(.system(size: 22 * model.typeScale, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityIdentifier("shade-temp")
            }
        }
    }

    private var readoutUnit: some View {
        HStack(spacing: 6) {
            zoneSwatch
            Text(zoneLabel)
                .font(.system(size: 13 * model.typeScale, weight: .semibold))
                .lineLimit(1)
                .fixedSize()
        }
    }

    private var readoutTime: some View {
        Text(WindowWords.clock(CareDay.hour(shown)))
            .font(.system(size: 15 * model.typeScale, weight: .bold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(Palette.night)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white, in: RoundedRectangle(cornerRadius: 6))
            .accessibilityIdentifier("drag-time")
    }

    private var maxSunHour: Date {
        day.hours.max { $0.wbgtSunC < $1.wbgtSunC }?.time ?? day.sunrise
    }
    private var maxShadeHour: Date {
        day.hours.max { $0.wbgtShadeC < $1.wbgtShadeC }?.time ?? day.sunrise
    }
    private var zoneLabel: String {
        let value = ActivityWindows.interpolate(model.activity.heatUsesShade ? shade : sun, CareDay.hour(shown))
        switch HeatScale.minutes(wbgt: value, on: day.sunrise) {
        case .stop: return "Avoid"
        case .minutes(let n): return "\(n) min/hr"
        }
    }
    private var zoneSwatch: some View {
        let value = ActivityWindows.interpolate(model.activity.heatUsesShade ? shade : sun, CareDay.hour(shown))
        let zone = HeatScale.minutes(wbgt: value, on: day.sunrise)
        return RoundedRectangle(cornerRadius: 2).fill(Palette.zone(zone)).frame(width: 10, height: 10)
    }

    private var chart: some View {
        VStack(spacing: 6) {
            sky
            seaBand
            heat
        }
        .overlay {
            GeometryReader { geo in
                Color.clear.contentShape(Rectangle()).gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        model.scrub = CareDay.snap(axis.date(atX: value.location.x, width: geo.size.width), on: day.sunrise)
                    }.onEnded { _ in
                        if !launchedScrub { model.scrub = nil }
                    }
                )
            }
        }
    }

    private var launchedScrub: Bool {
        ProcessInfo.processInfo.arguments.contains("-scrub")
    }

    private var sky: some View {
        ZStack(alignment: .topLeading) {
            Palette.track
            Canvas { context, size in
                nightGround(context, size, topInset: 0)
                for hour in day.hours {
                    let h = CareDay.hour(hour.time)
                    guard h >= 6 && h < 21 else { continue }
                    let x = axis.x(hour.time, width: size.width)
                    let next = axis.x(hour.time.addingTimeInterval(3600), width: size.width)
                    let width = max(1, next - x)
                    let dim = h + 0.5 >= sunsetHour
                    let cloudH = size.height * CGFloat(min(100, hour.cloudPct) / 100) * 0.72
                    let cloudRect = CGRect(x: x, y: size.height - cloudH - 4, width: width, height: cloudH)
                    context.fill(Path(cloudRect), with: .color(dim ? Palette.cloudNight : Palette.cloud.opacity(0.9)))
                    if hour.precipMm > 0 {
                        let rainH = size.height * CGFloat(min(1, hour.precipMm)) * 0.72
                        context.fill(Path(CGRect(x: x, y: size.height - rainH - 4, width: width, height: rainH)), with: .color(Palette.mid))
                    }
                }
                sunsetLine(context, size, from: 22)
                dragOrNow(context, size, from: 22)
                if dragging { skyMarkers(context, size) }
            }
            header("Clouds", color: Palette.cloud, second: "Rain", secondColor: Palette.mid, stale: model.feedIsStale(file.feeds.forecast, file: file), staleName: "Clouds")
            if dragging { skyPills }
        }
        .frame(height: 78)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityIdentifier("sky-band")
    }

    private var seaBand: some View {
        let lines = SeaWords.header(calm: calm, wave: day.waveWord)
        let tideStale = model.feedIsStale(file.feeds.tides, file: file)
        return VStack(spacing: 0) {
        ZStack(alignment: .topLeading) {
            Palette.track
            Canvas { context, size in
                let plotTop: CGFloat = 22
                nightGround(context, size, topInset: plotTop)
                guard sea.count > 1 else { return }
                func y(_ energy: Double) -> CGFloat {
                    let plot = size.height - plotTop - 8
                    return size.height - 4 - CGFloat(min(210, max(0, energy)) / 210) * plot
                }
                var shore = Path()
                var off = Path()
                for (index, sample) in sea.enumerated() {
                    let x = axis.x(CareDay.date(hour: sample.hour, on: day.sunrise), width: size.width)
                    let s = CGPoint(x: x, y: y(sample.shore))
                    let o = CGPoint(x: x, y: y(sample.offshore))
                    if index == 0 { shore.move(to: s); off.move(to: o) }
                    else { shore.addLine(to: s); off.addLine(to: o) }
                }
                var fill = shore
                fill.addLine(to: CGPoint(x: axis.x(axis.end, width: size.width), y: size.height))
                fill.addLine(to: CGPoint(x: axis.x(axis.start, width: size.width), y: size.height))
                fill.closeSubpath()
                context.fill(fill, with: .color(Palette.ocean))
                context.stroke(shore, with: .color(.white), lineWidth: 1.3)
                context.stroke(off, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                var calmLine = Path()
                let cy = y(file.week.calmThresholdKj)
                calmLine.move(to: CGPoint(x: 4, y: cy))
                calmLine.addLine(to: CGPoint(x: size.width - 4, y: cy))
                context.stroke(calmLine, with: .color(Palette.lagoon), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                if !dragging, let longest = calm.max(by: { $0.end - $0.start < $1.end - $1.start }) {
                    let mid = (longest.start + longest.end) / 2
                    let x = axis.x(CareDay.date(hour: mid, on: day.sunrise), width: size.width)
                    context.draw(Text("calm line").font(.system(size: 11, weight: .semibold)).foregroundColor(Palette.lagoon), at: CGPoint(x: x, y: cy - 8))
                }
                let afternoon = sea.filter { $0.hour >= 13 && $0.hour <= 16.5 }
                if !dragging, let best = afternoon.max(by: { ($0.offshore - $0.shore) < ($1.offshore - $1.shore) }) {
                    let gap = y(best.shore) - y(best.offshore)
                    if gap > 16 {
                        let x = axis.x(CareDay.date(hour: best.hour, on: day.sunrise), width: size.width)
                        context.draw(Text("offshore").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.82)), at: CGPoint(x: x, y: y(best.offshore) + 10))
                    }
                }
                sunsetLine(context, size, from: plotTop)
                dragOrNow(context, size, from: plotTop)
                if dragging, let sample = sea.min(by: { abs($0.hour - CareDay.hour(shown)) < abs($1.hour - CareDay.hour(shown)) }) {
                    let x = axis.x(shown, width: size.width)
                    dot(context, x, y: y(sample.shore))
                }
            }
            if tideStale && !dragging {
                Text(Freshness.blockHeader(name: "Tide", asOf: file.feeds.tides.asOf, now: model.now))
                    .font(SamaraFont.band()).foregroundStyle(Palette.amber).padding(8)
                    .accessibilityIdentifier("tide-header")
            } else if !dragging {
                ViewThatFits(in: .horizontal) {
                    Text(lines.full).lineLimit(1)
                    Text(lines.withoutWave).lineLimit(1)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.lagoon)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .accessibilityIdentifier("tide-header")
            }
            if dragging { seaPills }
        }
        .frame(height: 86 + (model.typeScale > 1.2 && dragging ? 22 * model.typeScale : 0))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        calmBars
            .frame(height: 10)
        }
        .accessibilityIdentifier("sea-band")
    }

    private var calmBars: some View {
        GeometryReader { geo in
            ForEach(Array(calm.enumerated()), id: \.offset) { _, span in
                let x0 = axis.x(CareDay.date(hour: span.start, on: day.sunrise), width: geo.size.width)
                let x1 = axis.x(CareDay.date(hour: span.end, on: day.sunrise), width: geo.size.width)
                RoundedRectangle(cornerRadius: 2).fill(Palette.lagoon)
                    .frame(width: max(4, x1 - x0), height: 4)
                    .position(x: (x0 + x1) / 2, y: 5)
            }
        }
    }

    private var heat: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in
                drawHeat(context, size)
                drawAvoid(context, size)
                sunsetLine(context, size, from: 16)
                let labelX = min(size.width - 40, axis.x(day.sunset, width: size.width) + 34)
                context.draw(
                    Text("sunset \(WindowWords.clock(sunsetHour))").font(.system(size: 11, weight: .medium)).foregroundColor(Palette.muted),
                    at: CGPoint(x: labelX, y: 10)
                )
                let limit = ActivityWindows.sunCutoff(sunsetHour: sunsetHour)
                if model.activity == .beach || model.activity == .soccerSun {
                    let x = axis.x(CareDay.date(hour: limit, on: day.sunrise), width: size.width)
                    var tick = Path()
                    tick.move(to: CGPoint(x: x, y: size.height - 28))
                    tick.addLine(to: CGPoint(x: x, y: size.height - 7))
                    context.stroke(tick, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1, dash: [1, 2]))
                }
                if let now = nowInstant, !dragging {
                    let x = axis.x(now, width: size.width)
                    var nowLine = Path()
                    nowLine.move(to: CGPoint(x: x, y: 32))
                    nowLine.addLine(to: CGPoint(x: x, y: size.height - 7))
                    context.stroke(nowLine, with: .color(.white.opacity(0.55)), lineWidth: 1)
                    dot(context, x, y: heatY(ActivityWindows.interpolate(sun, CareDay.hour(now)), size))
                    dot(context, x, y: heatY(ActivityWindows.interpolate(shade, CareDay.hour(now)), size))
                }
                let place = labelHour(width: size.width)
                let sunX = axis.x(CareDay.date(hour: place, on: day.sunrise), width: size.width)
                let span = labelPeak(at: place, width: size.width, plot: size.width)
                context.draw(Text("Sun").font(.system(size: 13, weight: .bold)).foregroundColor(.white), at: CGPoint(x: sunX, y: heatY(span.sun, size) - 12))
                context.draw(Text("Shade").font(.system(size: 13, weight: .bold)).foregroundColor(.white), at: CGPoint(x: sunX, y: heatY(span.shade, size) + 14))
                if dragging {
                    let x = axis.x(shown, width: size.width)
                    var line = Path()
                    line.move(to: CGPoint(x: x, y: 32))
                    line.addLine(to: CGPoint(x: x, y: size.height - 7))
                    context.stroke(line, with: .color(.white.opacity(0.8)), lineWidth: 1)
                    dot(context, x, y: heatY(ActivityWindows.interpolate(sun, CareDay.hour(shown)), size))
                    dot(context, x, y: heatY(ActivityWindows.interpolate(shade, CareDay.hour(shown)), size))
                }
            }
            Text("Heat").font(SamaraFont.band()).foregroundStyle(Palette.muted).padding(8)
        }
        .frame(maxHeight: .infinity)
        .frame(minHeight: 88)
        .accessibilityIdentifier("heat-plot")
    }

    private var nowInstant: Date? {
        guard model.viewingToday, CostaRica.isSameDay(model.now, day.sunrise) else { return nil }
        let hour = CareDay.hour(model.now)
        guard hour >= CareDay.startHour && hour <= CareDay.endHour else { return nil }
        return model.now
    }

    private func dragOrNow(_ context: GraphicsContext, _ size: CGSize, from: CGFloat) {
        let when: Date?
        if dragging { when = shown } else { when = nowInstant }
        guard let when else { return }
        guard when >= axis.start && when <= axis.end else { return }
        let x = axis.x(when, width: size.width)
        var line = Path()
        line.move(to: CGPoint(x: x, y: from))
        line.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(line, with: .color(.white.opacity(dragging ? 0.8 : 0.55)), lineWidth: 1)
    }

    private func drawAvoid(_ context: GraphicsContext, _ size: CGSize) {
        for run in play.runs where run.verdict == .avoid {
            let x0 = axis.x(CareDay.date(hour: run.start, on: day.sunrise), width: size.width)
            let x1 = axis.x(CareDay.date(hour: run.end, on: day.sunrise), width: size.width)
            context.fill(Path(CGRect(x: x0, y: 0, width: max(1, x1 - x0), height: size.height)), with: .color(.black.opacity(0.42)))
            context.draw(
                Text("Avoid").font(.system(size: 13, weight: .bold)).foregroundColor(.white),
                at: CGPoint(x: (x0 + x1) / 2, y: 26)
            )
        }
    }

    private func drawHeat(_ context: GraphicsContext, _ size: CGSize) {
        func y(_ value: Double) -> CGFloat { heatY(value, size) }
        struct Sample { var x: CGFloat; var sun: Double; var shade: Double; var sunZone: HeatMinutes; var shadeZone: HeatMinutes }
        var samples: [Sample] = []
        var cursor = axis.start
        while cursor <= axis.end {
            let sunV = ActivityWindows.interpolate(sun, CareDay.hour(cursor))
            let shadeV = ActivityWindows.interpolate(shade, CareDay.hour(cursor))
            let bin = hourBin(day.hours, at: min(cursor.addingTimeInterval(1), axis.end))
            let sunZone: HeatMinutes = (bin?.wbgtSunC).map { HeatScale.isStopHour(wbgt: $0, on: day.sunrise) } == true ? .stop : HeatScale.minutes(wbgt: sunV, on: day.sunrise)
            let shadeZone: HeatMinutes = (bin?.wbgtShadeC).map { HeatScale.isStopHour(wbgt: $0, on: day.sunrise) } == true ? .stop : HeatScale.minutes(wbgt: shadeV, on: day.sunrise)
            samples.append(Sample(x: axis.x(cursor, width: size.width), sun: sunV, shade: shadeV, sunZone: sunZone, shadeZone: shadeZone))
            cursor = cursor.addingTimeInterval(5 * 60)
        }
        func paint(_ zone: HeatMinutes, _ path: Path) {
            if zone == .stop {
                context.fill(path, with: .color(Palette.hatch))
                hatch(in: path.boundingRect, context: context, gap: 5, clip: path)
            } else {
                context.fill(path, with: .color(Palette.zone(zone)))
            }
        }
        func runs(_ key: KeyPath<Sample, HeatMinutes>) -> [Range<Int>] {
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
        for run in runs(\.shadeZone) {
            let slice = Array(samples[run])
            guard let first = slice.first, let last = slice.last else { continue }
            var path = Path()
            path.move(to: CGPoint(x: first.x, y: size.height))
            slice.forEach { path.addLine(to: CGPoint(x: $0.x, y: y($0.shade))) }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
            paint(first.shadeZone, path)
        }
        for run in runs(\.sunZone) {
            let slice = Array(samples[run])
            guard slice.count > 1, let first = slice.first else { continue }
            var path = Path()
            path.move(to: CGPoint(x: first.x, y: y(first.shade)))
            slice.forEach { path.addLine(to: CGPoint(x: $0.x, y: y(max($0.sun, $0.shade)))) }
            slice.reversed().forEach { path.addLine(to: CGPoint(x: $0.x, y: y(min($0.sun, $0.shade)))) }
            path.closeSubpath()
            paint(first.sunZone, path)
        }
        var sunPath = Path(); var shadePath = Path(); var started = false
        var walk = axis.start
        while walk <= axis.end {
            let x = axis.x(walk, width: size.width)
            if started {
                sunPath.addLine(to: CGPoint(x: x, y: y(ActivityWindows.interpolate(sun, CareDay.hour(walk)))))
                shadePath.addLine(to: CGPoint(x: x, y: y(ActivityWindows.interpolate(shade, CareDay.hour(walk)))))
            } else {
                sunPath.move(to: CGPoint(x: x, y: y(ActivityWindows.interpolate(sun, CareDay.hour(walk)))))
                shadePath.move(to: CGPoint(x: x, y: y(ActivityWindows.interpolate(shade, CareDay.hour(walk)))))
                started = true
            }
            walk = walk.addingTimeInterval(10 * 60)
        }
        casedLine(shadePath, context: context, dashed: true)
        casedLine(sunPath, context: context, dashed: false)
    }

    private func labelHour(width: CGFloat) -> Double {
        let anchor = 13.5
        let anchorX = (anchor - 6) / 15 * Double(width)
        let probe = dragging ? CareDay.hour(shown) : (nowInstant.map { CareDay.hour($0) } ?? -100)
        let probeX = (probe - 6) / 15 * Double(width)
        return abs(probeX - anchorX) < 24 ? 10.5 : anchor
    }

    private func labelPeak(at hour: Double, width: CGFloat, plot: CGFloat) -> (sun: Double, shade: Double) {
        let half = 24.0
        let left = max(6, hour - half / Double(plot) * 15)
        let right = min(21, hour + half / Double(plot) * 15)
        var peak = -100.0
        var low = 100.0
        var cursor = left
        while cursor <= right {
            peak = max(peak, ActivityWindows.interpolate(sun, cursor))
            low = min(low, ActivityWindows.interpolate(shade, cursor))
            cursor += 0.05
        }
        return (peak, low)
    }

    private func heatY(_ value: Double, _ size: CGSize) -> CGFloat {
        let fraction = (value - 22) / (34 - 22)
        return size.height - CGFloat(min(1, max(0, fraction))) * (size.height - 18) - 4
    }

    private func nightGround(_ context: GraphicsContext, _ size: CGSize, topInset: CGFloat) {
        let x = axis.x(day.sunset, width: size.width)
        context.fill(Path(CGRect(x: x, y: topInset, width: max(0, size.width - x), height: size.height - topInset)), with: .color(Palette.nightSky))
    }

    private func sunsetLine(_ context: GraphicsContext, _ size: CGSize, from: CGFloat) {
        let x = axis.x(day.sunset, width: size.width)
        var path = Path()
        path.move(to: CGPoint(x: x, y: from))
        path.addLine(to: CGPoint(x: x, y: size.height))
        context.stroke(path, with: .color(Palette.muted.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
    }

    private func header(_ title: String, color: Color, second: String? = nil, secondColor: Color = .clear, stale: Bool, staleName: String) -> some View {
        Group {
            if !dragging {
                HStack(spacing: 8) {
                    if stale {
                        Text(Freshness.blockHeader(name: staleName, asOf: file.feeds.forecast.asOf, now: model.now))
                            .foregroundStyle(Palette.amber)
                    } else {
                        Text(title).foregroundStyle(color)
                        if let second { Text(second).foregroundStyle(secondColor) }
                    }
                }
                .font(SamaraFont.band())
                .padding(8)
            }
        }
    }

    private var skyPills: some View {
        GeometryReader { geo in
            let hour = Int(CareDay.hour(shown))
            let cloud = day.hours.first { CostaRica.calendar.component(.hour, from: $0.time) == hour }
            let cloudText = cloud.map { "\(Int($0.cloudPct.rounded()))%" } ?? "—"
            let rainText = cloud.map { $0.precipMm == 0 ? "dry" : String(format: "%.1f mm", $0.precipMm) } ?? "—"
            pillRow(geo: geo, items: [("Cloud", cloudText, false), ("Rain", rainText, false)], fills: [Palette.cloud, Palette.mid], y: 12)
        }
    }

    private var seaPills: some View {
        GeometryReader { geo in
            let hour = CareDay.hour(shown)
            let sample = sea.min { abs($0.hour - hour) < abs($1.hour - hour) }
            let word = sample.map { SeaWords.word(shore: $0.shore, offshore: $0.offshore, threshold: file.week.calmThresholdKj, upperQuartile: file.week.energyQ3Kj) } ?? "—"
            let kj = sample.map { "\(word.capitalized) \(Int($0.shore.rounded())) kJ" } ?? "—"
            let tide = TideMath.height(at: shown, extrema: extrema)
            let next = TideMath.height(at: shown.addingTimeInterval(60), extrema: extrema)
            let phrase = TideWords.phrase(feet: tide, direction: TideWords.direction(feet: tide, nextFeet: next))
            pillRow(geo: geo, items: [("", kj, true), ("Tide", phrase, false)], fills: [Palette.ocean, Palette.night], y: 12, tideOutline: true)
        }
    }

    private func pillRow(geo: GeometryProxy, items: [(String, String, Bool)], fills: [Color], y: CGFloat, tideOutline: Bool = false) -> some View {
        let widths = items.map { item -> Double in
            var w = 14.0 * model.typeScale
            if !item.0.isEmpty { w += Double(item.0.count) * 7.2 * model.typeScale + 4 }
            w += Double(item.1.count) * 7.6 * model.typeScale
            if item.2 { w += 36 * model.typeScale }
            return w
        }
        let line = Double(axis.x(shown, width: geo.size.width))
        let spans = PillLayout.place(line: line, widths: widths, bandWidth: Double(geo.size.width))
        let stack = model.typeScale > 1.2 && widths.reduce(0, +) + 4 > Double(geo.size.width) - 12
        return ZStack {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let span = stack ? PillLayout.place(line: line, widths: [widths[index]], bandWidth: Double(geo.size.width))[0] : spans[index]
                let rowY = y + (stack ? CGFloat(index) * 20 * model.typeScale : 0)
                HStack(spacing: 4) {
                    if !item.0.isEmpty { Text(item.0).font(.system(size: 12 * model.typeScale, weight: .semibold)) }
                    Text(item.1).font(.system(size: 13 * model.typeScale, weight: .bold)).monospacedDigit()
                    if item.2 { Text("model").font(.system(size: 11 * model.typeScale, weight: .semibold)) }
                }
                .foregroundStyle(index == 1 && tideOutline ? Palette.lagoon : (fills[index] == Palette.ocean ? Color.white : Palette.night))
                .padding(.horizontal, 7)
                .frame(height: 18 * model.typeScale)
                .background(tideOutline && index == 1 ? Palette.night : fills[index], in: Capsule())
                .overlay(Capsule().stroke(tideOutline && index == 1 ? Palette.lagoon : Palette.night, lineWidth: 1.3))
                .position(x: (span.start + span.end) / 2, y: rowY)
            }
        }
    }

    private func skyMarkers(_ context: GraphicsContext, _ size: CGSize) {
        let hour = Int(CareDay.hour(shown))
        guard let point = day.hours.first(where: { CostaRica.calendar.component(.hour, from: $0.time) == hour }) else { return }
        let x = axis.x(shown, width: size.width)
        let cloudH = size.height * CGFloat(min(100, point.cloudPct) / 100) * 0.72
        let cloudDot = CGRect(x: x - 1.75, y: size.height - cloudH - 4 - 1.75, width: 3.5, height: 3.5)
        context.fill(Path(ellipseIn: cloudDot), with: .color(.white))
        if point.precipMm > 0 {
            let rainH = size.height * CGFloat(min(1, point.precipMm)) * 0.72
            let rainDot = CGRect(x: x - 1.75, y: size.height - rainH - 4 - 1.75, width: 3.5, height: 3.5)
            context.fill(Path(ellipseIn: rainDot.insetBy(dx: -1, dy: -1)), with: .color(.white))
            context.fill(Path(ellipseIn: rainDot), with: .color(Palette.mid))
        }
    }

    private func dot(_ context: GraphicsContext, _ x: CGFloat, y: CGFloat) {
        let rect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
        context.fill(Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)), with: .color(Palette.night))
        context.fill(Path(ellipseIn: rect), with: .color(.white))
    }
}
