import SamaraCore
import SwiftUI

struct WeekPages: View {
    @EnvironmentObject private var model: AppModel
    let file: ConditionsFile
    let days: [(offset: Int, day: DayConditions?)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            headline
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
            axis
            if model.weekTab == .sea {
                VStack(alignment: .leading, spacing: 2) {
                    Text("fill = energy at the shore · dotted = offshore · dashes = calm line")
                    Text("model, not measured · reef size and gaps guessed")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.muted)
            }
            if model.weekTab == .heat {
                MinutesKey(showStop: days.contains { item in
                    guard let day = item.day else { return false }
                    return day.hours.contains {
                        let value = model.activity.heatUsesShade ? $0.wbgtShadeC : $0.wbgtSunC
                        return HeatScale.isStopHour(wbgt: value, on: day.sunrise)
                    }
                })
                ActivityChips()
                LowTideToggle()
            }
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
        HStack(spacing: 0) {
            ForEach(["6a", "9a", "12p", "3p", "6p", "9p"], id: \.self) { tick in
                Text(tick)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: tick == "6a" ? .leading : (tick == "9p" ? .trailing : .center))
            }
        }
        .accessibilityHidden(true)
    }

    private func row(_ offset: Int, _ day: DayConditions?) -> some View {
        let muted = offset >= 3
        return VStack(alignment: .leading, spacing: 3) {
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
            strip(offset, day).frame(height: model.weekTab == .heat ? 46 : 54).opacity(muted ? 0.45 : 1)
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
            let spans = care(day)
            if spans.isEmpty { return "no window" }
            return spans.map { WindowWords.label(start: CareDay.hour($0.start), end: CareDay.hour($0.end)) }.joined(separator: "  ")
        case .sea:
            let calm = SeaSeries.calm(samples: SeaSeries.points(hours: day.hours, extrema: model.extrema(for: file), day: day.sunrise), threshold: file.week.calmThresholdKj)
            if calm.isEmpty { return "no calm" }
            return calm.map { WindowWords.label(start: $0.start, end: $0.end) }.joined(separator: ", ")
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
                sea(context, size, day: day, axis: axis)
            }
            let x = axis.x(day.sunset, width: size.width)
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(Palette.muted.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        }
    }

    private func bars(_ context: GraphicsContext, _ size: CGSize, day: DayConditions, axis: PlotAxis, rain: Bool, muted: Bool) {
        let sunset = CareDay.hour(day.sunset)
        for hour in day.hours {
            let h = CareDay.hour(hour.time)
            guard h >= 6 && h < 21 else { continue }
            let x = axis.x(hour.time, width: size.width)
            let next = axis.x(hour.time.addingTimeInterval(3600), width: size.width)
            let fraction: CGFloat = rain ? CGFloat(min(1, hour.precipMm)) : CGFloat(min(100, hour.cloudPct) / 100)
            let height = max(0, (size.height - 4) * fraction)
            let rect = CGRect(x: x, y: size.height - height, width: max(1, next - x - 1), height: height)
            var color = rain ? Palette.mid : Palette.cloud
            if !rain && h + 0.5 >= sunset { color = Color(red: 90/255, green: 94/255, blue: 102/255) }
            if muted { color = color.opacity(0.55) }
            context.fill(Path(rect), with: .color(color))
        }
    }

    private func heat(_ context: GraphicsContext, _ size: CGSize, day: DayConditions, axis: PlotAxis, muted: Bool) {
        let shade = model.activity.heatUsesShade
        let series = ActivityWindows.hourly(day.hours) { shade ? $0.wbgtShadeC : $0.wbgtSunC }
        var cursor = axis.start
        while cursor < axis.end {
            let next = min(axis.end, cursor.addingTimeInterval(5 * 60))
            let value = ActivityWindows.interpolate(series, CareDay.hour(cursor))
            let zone = HeatScale.minutes(wbgt: value, on: day.sunrise)
            let x0 = axis.x(cursor, width: size.width)
            let x1 = axis.x(next, width: size.width)
            let rect = CGRect(x: x0, y: 0, width: max(1, x1 - x0), height: 16)
            context.fill(Path(rect), with: .color(muted ? Palette.zone(zone).opacity(0.45) : Palette.zone(zone)))
            if zone == .stop { hatch(in: rect, context: context, gap: 4) }
            cursor = next
        }
        for span in care(day) {
            let x0 = axis.x(span.start, width: size.width)
            let x1 = axis.x(span.end, width: size.width)
            let label = WindowWords.label(start: CareDay.hour(span.start), end: CareDay.hour(span.end))
            let rect = CGRect(x: x0, y: 20, width: max(36, x1 - x0), height: 22)
            context.fill(Path(roundedRect: rect, cornerRadius: 6), with: .color(muted ? Color(white: 0.75) : .white))
            context.draw(Text(label).font(.system(size: 13, weight: .bold)).foregroundColor(muted ? Palette.muted : Palette.night), at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }

    private func sea(_ context: GraphicsContext, _ size: CGSize, day: DayConditions, axis: PlotAxis) {
        let samples = SeaSeries.points(hours: day.hours, extrema: model.extrema(for: file), day: day.sunrise)
        func y(_ energy: Double) -> CGFloat {
            size.height - 8 - CGFloat(min(210, max(0, energy)) / 210) * (size.height - 12)
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
            fill.addLine(to: CGPoint(x: axis.x(CareDay.date(hour: last.hour, on: day.sunrise), width: size.width), y: size.height))
            fill.addLine(to: CGPoint(x: axis.x(CareDay.date(hour: first.hour, on: day.sunrise), width: size.width), y: size.height))
            fill.closeSubpath()
        }
        context.fill(fill, with: .color(Palette.ocean))
        context.stroke(shore, with: .color(.white), lineWidth: 1.2)
        context.stroke(off, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        var calmLine = Path()
        let cy = y(file.week.calmThresholdKj)
        calmLine.move(to: CGPoint(x: 0, y: cy))
        calmLine.addLine(to: CGPoint(x: size.width, y: cy))
        context.stroke(calmLine, with: .color(Palette.lagoon), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
    }

    private func care(_ day: DayConditions) -> [TimeSpan] {
        ActivityWindows.spans(
            sun: ActivityWindows.hourly(day.hours) { $0.wbgtSunC },
            shade: ActivityWindows.hourly(day.hours) { $0.wbgtShadeC },
            activity: model.activity,
            sunsetHour: CareDay.hour(day.sunset),
            lowTide: model.lowTideOnly && model.activity == .beach
        ).map { TimeSpan(start: CareDay.date(hour: $0.start, on: day.sunrise), end: CareDay.date(hour: $0.end, on: day.sunrise)) }
    }
}
