import SamaraCore
import SwiftUI

struct WeekPages: View {
    @EnvironmentObject private var model: AppModel
    let file: ConditionsFile
    let days: [(offset: Int, day: DayConditions?)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headline
            ScrollView {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    ForEach(days, id: \.offset) { item in
                        Button {
                            model.dayOffset = item.offset
                            model.section = .today
                        } label: {
                            row(item.offset, item.day)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("week-row-\(item.offset)")
                    }
                    if model.weekTab == .heat {
                        axis
                        MinutesKey(showStop: days.contains { item in
                            guard let day = item.day else { return false }
                            return model.activityPlan(model.activity, day: day, file: file).runs.contains { $0.verdict == .avoid }
                        })
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        switch model.weekTab {
        case .sea:
            VStack(alignment: .leading, spacing: 2) {
                axis
                Text("fill = energy at the shore · dotted = offshore ·")
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("dashes = calm line")
                Text("model, not measured · reef size and gaps guessed")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.muted)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.night)
        case .heat:
            VStack(alignment: .leading, spacing: 8) {
                ActivityChips()
                LowTideToggle()
            }
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.night)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1)
            }
        case .rain, .cloud:
            axis
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.night)
        }
    }

    /// Sea is 74 pt: label 18, strip 40, ribbon overhang 8, gap 8. Heat is 72 pt.
    private var rowSpacing: CGFloat {
        switch model.weekTab {
        case .sea: return 8
        case .heat: return 11
        case .rain, .cloud: return 6
        }
    }

    private var headline: some View {
        Text(head)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette.muted)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var head: String {
        switch model.weekTab {
        case .rain: return "full bar = 1 mm/hr"
        case .cloud: return "full bar = 100% cloud · % = daylight average"
        case .sea: return "full height = 210 kJ"
        case .heat: return ""
        }
    }

    private var axis: some View {
        GeometryReader { geo in
            ForEach([6, 9, 12, 15, 18, 21], id: \.self) { hour in
                let label = hour == 12 ? "12p" : (hour < 12 ? "\(hour)a" : "\(hour - 12)p")
                let x = geo.size.width * CGFloat(hour - 6) / 15
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .position(x: hour == 6 ? 8 : (hour == 21 ? geo.size.width - 8 : x), y: 8)
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }

    private func row(_ offset: Int, _ day: DayConditions?) -> some View {
        let muted = offset >= 3
        return VStack(alignment: .leading, spacing: model.weekTab == .rain || model.weekTab == .cloud ? 3 : 0) {
            HStack(spacing: 6) {
                Text(day.map { "\($0.weekday) \(String($0.date.suffix(2)))" } ?? "—")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(muted ? Palette.muted : Palette.text)
                Spacer(minLength: 4)
                Text(value(offset, day))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(muted ? Palette.muted : Palette.text)
                    .lineLimit(1)
                Text("›").font(.system(size: 17, weight: .medium)).foregroundStyle(Palette.muted)
            }
            .frame(height: 18)
            strip(offset, day).frame(height: stripHeight)
            if model.weekTab == .heat, let day {
                let plan = model.activityPlan(model.activity, day: day, file: file)
                let axis = PlotAxis(start: CareDay.start(on: day.sunrise), end: CareDay.end(on: day.sunrise))
                SlimTimeRow(runs: plan.runs, axis: axis, day: day.sunrise, minutes: plan.minutesKey)
                    .padding(.top, 4)
            }
        }
    }

    /// Sea canvas is the 40 pt strip plus the 8 pt ribbon overhang. Heat is bar 16, gap 3, pill 24.
    private var stripHeight: CGFloat {
        switch model.weekTab {
        case .sea: return 48
        case .heat: return 16
        case .rain, .cloud: return 54
        }
    }

    private func value(_ offset: Int, _ day: DayConditions?) -> String {
        guard let day else { return "" }
        switch model.weekTab {
        case .rain:
            let hours = day.hours
            let total = hours.reduce(0) { $0 + $1.precipMm }
            if total < 0.05 { return "dry" }
            let outside = hours.reduce(0.0) { sum, hour in
                let h = CareDay.hour(hour.time)
                return sum + (h < 6 || h >= 21 ? hour.precipMm : 0)
            }
            let base = String(format: "%.1f mm", total)
            if outside / total >= 0.4 { return base + String(format: " · %.1f overnight", outside) }
            return base
        case .cloud:
            return "\(day.cloudDaylightMeanPct)%"
        case .heat:
            return ""
        case .sea:
            return ""
        }
    }

    private func strip(_ offset: Int, _ day: DayConditions?) -> some View {
        Canvas { context, size in
            guard let day else { return }
            let axis = PlotAxis(start: CareDay.start(on: day.sunrise), end: CareDay.end(on: day.sunrise))
            let muted = offset >= 3
            switch model.weekTab {
            case .rain, .cloud:
                bars(context, size, day: day, axis: axis, rain: model.weekTab == .rain, muted: muted)
            case .heat:
                heat(context, size, day: day, axis: axis, muted: muted)
            case .sea:
                sea(context, size, day: day, axis: axis, muted: muted)
            }
            if model.weekTab != .heat {
                let x = axis.x(day.sunset, width: size.width)
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: model.weekTab == .sea ? 33 : size.height))
                context.stroke(line, with: .color(Palette.muted.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
    }

    private func bars(_ context: GraphicsContext, _ size: CGSize, day: DayConditions, axis: PlotAxis, rain: Bool, muted: Bool) {
        let track = CGRect(x: 0, y: 2, width: size.width, height: size.height - 4)
        context.fill(Path(roundedRect: track, cornerRadius: 4), with: .color(Palette.track))
        var hair = Path()
        hair.move(to: CGPoint(x: 0, y: 2))
        hair.addLine(to: CGPoint(x: size.width, y: 2))
        context.stroke(hair, with: .color(.white.opacity(0.12)), lineWidth: 1)
        let sunset = CareDay.hour(day.sunset)
        for hour in day.hours {
            let h = CareDay.hour(hour.time)
            guard h >= 6 && h < 21 else { continue }
            let x = axis.x(hour.time, width: size.width)
            let next = axis.x(hour.time.addingTimeInterval(3600), width: size.width)
            let fraction: CGFloat = rain ? CGFloat(min(1, hour.precipMm)) : CGFloat(min(100, hour.cloudPct) / 100)
            let height = max(0, (size.height - 8) * fraction)
            let rect = CGRect(x: x, y: size.height - 4 - height, width: max(1, next - x - 1), height: height)
            var color = rain ? Palette.mid : Palette.cloud
            if !rain && h + 0.5 >= sunset { color = Color(red: 90/255, green: 94/255, blue: 102/255) }
            if muted { color = color.opacity(0.55) }
            context.fill(Path(rect), with: .color(color))
            if rain, hour.precipMm > 1 {
                context.draw(Text(String(format: "%.1f", hour.precipMm)).font(.system(size: 9, weight: .bold)).foregroundColor(.white), at: CGPoint(x: rect.midX, y: max(10, rect.minY - 7)))
            }
        }
    }

    private func heat(_ context: GraphicsContext, _ size: CGSize, day: DayConditions, axis: PlotAxis, muted: Bool) {
        let shade = model.activity.heatUsesShade
        let series = ActivityWindows.hourly(day.hours) { shade ? $0.wbgtShadeC : $0.wbgtSunC }
        var runs: [(start: Date, end: Date, zone: HeatMinutes)] = []
        var cursor = axis.start
        while cursor < axis.end {
            let next = min(axis.end, cursor.addingTimeInterval(5 * 60))
            let zone = HeatScale.minutes(wbgt: ActivityWindows.interpolate(series, CareDay.hour(cursor)), on: day.sunrise)
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
            let rect = CGRect(x: x0, y: 0, width: max(1, x1 - x0 + 0.5), height: 16)
            if run.zone == .stop {
                context.fill(Path(rect), with: .color(muted ? Palette.hatch.opacity(0.45) : Palette.hatch))
                hatch(in: rect, context: context, gap: 4)
            } else {
                context.fill(Path(rect), with: .color(muted ? Palette.zone(run.zone).opacity(0.45) : Palette.zone(run.zone)))
            }
        }
        let sunsetX = axis.x(day.sunset, width: size.width)
        var hair = Path()
        hair.move(to: CGPoint(x: sunsetX, y: -2))
        hair.addLine(to: CGPoint(x: sunsetX, y: 18))
        context.stroke(hair, with: .color(Palette.muted.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        let plan = model.activityPlan(model.activity, day: day, file: file)
        for run in plan.runs where run.verdict == .avoid {
            let x0 = axis.x(CareDay.date(hour: run.start, on: day.sunrise), width: size.width)
            let x1 = axis.x(CareDay.date(hour: run.end, on: day.sunrise), width: size.width)
            let rect = CGRect(x: x0, y: 0, width: max(1, x1 - x0), height: 16)
            context.fill(Path(rect), with: .color(.black.opacity(0.28)))
            hatch(in: rect, context: context, gap: 4)
        }
    }

    private func sea(_ context: GraphicsContext, _ size: CGSize, day: DayConditions, axis: PlotAxis, muted: Bool) {
        let samples = SeaSeries.points(hours: day.hours, extrema: model.extrema(for: file), day: day.sunrise)
        let plot: CGFloat = 40
        func y(_ energy: Double) -> CGFloat {
            let fraction = CGFloat(min(210, max(0, energy)) / 210)
            return plot - 8 - fraction * (plot - 12)
        }
        var shore = Path()
        var off = Path()
        for (index, sample) in samples.enumerated() {
            let x = axis.x(CareDay.date(hour: sample.hour, on: day.sunrise), width: size.width)
            let s = CGPoint(x: x, y: y(sample.shore))
            let o = CGPoint(x: x, y: y(sample.offshore))
            if index == 0 { shore.move(to: s); off.move(to: o) } else { shore.addLine(to: s); off.addLine(to: o) }
        }
        var fill = shore
        if let last = samples.last, let first = samples.first {
            fill.addLine(to: CGPoint(x: axis.x(CareDay.date(hour: last.hour, on: day.sunrise), width: size.width), y: plot))
            fill.addLine(to: CGPoint(x: axis.x(CareDay.date(hour: first.hour, on: day.sunrise), width: size.width), y: plot))
            fill.closeSubpath()
        }
        context.fill(fill, with: .color(muted ? Palette.ocean.opacity(0.45) : Palette.ocean))
        context.stroke(shore, with: .color(.white), lineWidth: 1.2)
        context.stroke(off, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        var calmLine = Path()
        let cy = y(file.week.calmThresholdKj)
        calmLine.move(to: CGPoint(x: 0, y: cy))
        calmLine.addLine(to: CGPoint(x: size.width, y: cy))
        context.stroke(calmLine, with: .color(Palette.lagoon), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        let calm = SeaSeries.calm(samples: samples, threshold: file.week.calmThresholdKj)
        for span in calm {
            let label = WindowWords.label(start: span.start, end: span.end)
            let text = context.resolve(Text(label).font(.system(size: 11.5, weight: .heavy)).foregroundColor(Palette.night))
            let textWidth = text.measure(in: CGSize(width: 400, height: 30)).width + 12
            let x0 = axis.x(CareDay.date(hour: span.start, on: day.sunrise), width: size.width)
            let x1 = axis.x(CareDay.date(hour: span.end, on: day.sunrise), width: size.width)
            let pill = min(size.width, max(max(8, x1 - x0), textWidth))
            let origin = min(max(0, x0), max(0, size.width - pill))
            let rect = CGRect(x: origin, y: plot - 7, width: pill, height: 15)
            context.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(.white))
            context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }

}
