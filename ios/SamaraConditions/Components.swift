import SamaraCore
import SwiftUI

struct ActivityChips: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.typeScale > 1.2 {
            ChipFlow(spacing: 8, lineSpacing: 8) {
                ForEach(ActivityKind.allCases, id: \.self) { kind in
                    chip(kind, scale: 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            GeometryReader { geo in
                let scale = fittedScale(geo.size.width)
                HStack(spacing: max(4, 8 * scale)) {
                    ForEach(ActivityKind.allCases, id: \.self) { kind in
                        chip(kind, scale: scale)
                    }
                }
            }
            .frame(height: 48)
        }
    }

    /// Shrinks the row until every name fits, and never goes under a 4 pt gap.
    private func fittedScale(_ width: CGFloat) -> CGFloat {
        var scale: CGFloat = 1
        for _ in 0..<14 {
            let gap = max(4, 8 * scale)
            let sum = ActivityKind.allCases.reduce(CGFloat(0)) { $0 + measured($1.title, scale) }
            if sum + gap * CGFloat(ActivityKind.allCases.count - 1) <= width - 2 { return scale }
            scale *= 0.94
        }
        return scale
    }

    private func measured(_ title: String, _ scale: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 13 * model.typeScale * scale, weight: .semibold)
        let widest = title.split(separator: "\n", omittingEmptySubsequences: false).map {
            (String($0) as NSString).size(withAttributes: [.font: font]).width
        }.max() ?? 0
        return ceil(widest) + max(16, 24 * scale) + 4
    }

    private func chip(_ kind: ActivityKind, scale: CGFloat) -> some View {
        Button {
            if model.activity != kind { model.setActivity(kind) }
            if kind != .beach { model.lowTideOnly = false }
        } label: {
                VStack(spacing: 0) {
                    Text(kind.title)
                    if let hours = okHours(kind) {
                        Text(hours).font(.system(size: 11 * model.typeScale * scale, weight: .bold))
                    }
                }
                    .font(.system(size: 13 * model.typeScale * scale, weight: .semibold))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                .foregroundStyle(model.activity == kind ? Palette.text : Palette.muted)
                .padding(.horizontal, max(8, 12 * scale))
                .padding(.vertical, 7)
                .background(Capsule().fill(model.activity == kind ? Palette.chipFill : Color.clear))
                .overlay(Capsule().stroke(model.activity == kind ? Palette.chipEdge : Palette.chipEdge.opacity(0.7), lineWidth: 1))
        }
        .fixedSize()
        .accessibilityIdentifier("chip-\(kind.rawValue)")
    }

    private func okHours(_ kind: ActivityKind) -> String? {
        guard let file = model.file, let day = model.today(file) else { return nil }
        return model.activityPlan(kind, day: day, file: file).okHoursText
    }
}

/// Puts chips on the next line when the row is narrower than their text.
private struct ChipFlow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit = proposal.width ?? .greatestFiniteMagnitude
        var x: CGFloat = 0
        var y: CGFloat = 0
        var row: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > limit {
                y += row + lineSpacing
                x = 0
                row = 0
            }
            row = max(row, size.height)
            x += size.width + spacing
        }
        return CGSize(width: proposal.width ?? x, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var row: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += row + lineSpacing
                x = bounds.minX
                row = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            row = max(row, size.height)
            x += size.width + spacing
        }
    }
}

struct LowTideToggle: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.activity == .beach {
            Toggle(isOn: $model.lowTideOnly) {
                Text("Low tide only")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.text)
            }
            .tint(Palette.muted)
            .accessibilityIdentifier("low-tide-toggle")
        }
    }
}

struct MinutesKey: View {
    var showStop: Bool

    var body: some View {
        HStack(spacing: 12) {
            key(Palette.c50, "50")
            key(Palette.c40, "40")
            key(Palette.c30, "30")
            key(Palette.c20, "20")
            if showStop {
                HStack(spacing: 6) {
                    HatchSwatch()
                    Text("Avoid")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                }
            }
            Spacer()
            Text("outside min/hr")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.muted)
        }
    }

    private func key(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 14)
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.text)
        }
    }
}

struct HatchSwatch: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Palette.hatch))
            hatch(in: rect, context: context, gap: 4)
        }
        .frame(width: 18, height: 14)
        .overlay(RoundedRectangle(cornerRadius: 2).stroke(Palette.hatchLine, lineWidth: 1))
    }
}

func hatch(in rect: CGRect, context: GraphicsContext, gap: CGFloat, clip: Path? = nil) {
    var draw = context
    draw.clip(to: clip ?? Path(rect))
    var x = rect.minX - rect.height
    while x < rect.maxX {
        var path = Path()
        path.move(to: CGPoint(x: x, y: rect.maxY))
        path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
        draw.stroke(path, with: .color(Palette.hatchLine), lineWidth: 1)
        x += gap
    }
}

struct IMNBanner: View {
    let alert: OfficialAlert
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle().fill(Palette.amber).frame(width: 5)
                Text("⚠ IMN: \(alert.title) · official notice")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.amber)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                Spacer(minLength: 0)
            }
            .background(Palette.track)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityIdentifier("imn-banner")
    }
}

struct WindowRibbon: View {
    var spans: [TimeSpan]
    var axis: PlotAxis
    var emptyText: String
    var height: CGFloat = 26
    var fill: Color = .white
    var ink: Color = Palette.night
    var labelSize: CGFloat = 17
    var largeSize: CGFloat = 22
    var alwaysRange: Bool = false
    var words: ((TimeSpan) -> String)? = nil

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                if spans.isEmpty {
                    Text(emptyText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .accessibilityIdentifier("no-window")
                } else {
                    ForEach(Array(spans.enumerated()), id: \.offset) { _, span in
                        ribbon(span, width: width)
                    }
                }
            }
        }
        .frame(height: spans.isEmpty ? 22 : height)
    }

    private func ribbon(_ span: TimeSpan, width: CGFloat) -> some View {
        let x0 = axis.x(span.start, width: width)
        let x1 = axis.x(span.end, width: width)
        let label = words?(span) ?? shortRange(span)
        let coversDay = words != nil && (label == "All day" || label == "all day")
        let short = !coversDay && (alwaysRange || span.duration < 3 * 3600 || (x1 - x0) < 130 || words != nil)
        let needed = CGFloat(label.count) * labelSize * 0.62 + 14
        let bar = coversDay ? width : max(8, x1 - x0)
        let barX = coversDay ? 0 : x0
        let pill = coversDay ? width - 4 : min(width - 4, max(x1 - x0, needed))
        var origin = (x0 + x1) / 2 - pill / 2
        origin = min(max(2, origin), max(2, width - pill - 2))
        let textSize: CGFloat = coversDay || !short ? largeSize : 18
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(fill)
                .frame(width: bar, height: 6)
                .offset(x: barX, y: 0)
            Text(label)
                .font(.system(size: textSize, weight: .bold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .frame(width: pill, height: height - 10)
                .background(fill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .offset(x: coversDay ? 2 : origin, y: 8)
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }
}

struct PlotAxis {
    var start: Date
    var end: Date

    func x(_ date: Date, width: CGFloat) -> CGFloat {
        let span = end.timeIntervalSince(start)
        guard span > 0 else { return 0 }
        let fraction = date.timeIntervalSince(start) / span
        return CGFloat(min(1, max(0, fraction))) * width
    }

    func date(atX x: CGFloat, width: CGFloat) -> Date {
        guard width > 0 else { return start }
        let fraction = min(1, max(0, Double(x / width)))
        return start.addingTimeInterval(end.timeIntervalSince(start) * fraction)
    }
}

struct SlimTimeRow: View {
    var runs: [PlayRun]
    var axis: PlotAxis
    var day: Date
    var minutes: String

    private let ink = Color(red: 0.949, green: 0.949, blue: 0.941)
    private let grey = Color(red: 0.804, green: 0.820, blue: 0.843)
    private let faint = Color(red: 0.376, green: 0.400, blue: 0.435)

    var body: some View {
        GeometryReader { geo in
            let marks = laidOut(width: geo.size.width)
            let minutesWidth = CGFloat(minutes.count) * 5.6 + 24
            let right = marks.filter { !$0.faint }.map { $0.x + CGFloat($0.text.count) * 3.3 }.max() ?? 0
            let stacked = right + 8 + minutesWidth > geo.size.width
            VStack(alignment: .trailing, spacing: 1) {
                ZStack(alignment: .topLeading) {
                    Canvas { context, size in
                        drawRuns(context, size)
                    }
                    ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                        Text(mark.text)
                            .font(.system(size: mark.faint ? 10 : 11, weight: mark.faint ? .medium : .semibold))
                            .foregroundStyle(mark.faint ? faint : ink)
                            .fixedSize()
                            .position(x: mark.x, y: 20)
                    }
                    if !stacked {
                        key.position(x: geo.size.width - minutesWidth / 2, y: 20)
                    }
                }
                .frame(height: 32)
                if stacked { key }
            }
        }
        .frame(height: 48)
        .accessibilityIdentifier("slim-row")
    }

    private var key: some View {
        HStack(spacing: 5) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(grey).frame(width: 3.5, height: 3.5)
                }
            }
            Text(minutes)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(grey)
                .lineLimit(1)
        }
    }

    private struct Mark {
        var text: String
        var x: CGFloat
        var faint: Bool
    }

    private func x(_ hour: Double, _ width: CGFloat) -> CGFloat {
        axis.x(CareDay.date(hour: hour, on: day), width: width)
    }

    private func drawRuns(_ context: GraphicsContext, _ size: CGSize) {
        for run in runs {
            let x0 = x(run.start, size.width)
            let x1 = x(run.end, size.width)
            guard x1 - x0 > 0.5 else { continue }
            if run.verdict.isOk {
                context.fill(Path(CGRect(x: x0, y: 0, width: x1 - x0, height: 3)), with: .color(.white))
            } else if run.verdict.isLimited {
                var step = CGFloat(3.2)
                let span = x1 - x0
                let count = max(1, Int(((span - 1.6) / step).rounded()))
                if count > 1 { step = (span - 1.6) / CGFloat(count - 1) }
                for index in 0..<count {
                    let origin = x0 + CGFloat(index) * step
                    context.fill(Path(ellipseIn: CGRect(x: origin, y: 0.7, width: 1.6, height: 1.6)), with: .color(grey))
                }
            }
        }
    }

    private func laidOut(width: CGFloat) -> [Mark] {
        var ranged = Set<Int>()
        for (index, run) in runs.enumerated() {
            let pixels = x(run.end, width) - x(run.start, width)
            if run.verdict == .avoid || (run.verdict.isLimited && pixels < 78) {
                ranged.insert(index)
            }
        }
        var raw: [(hour: Double, text: String)] = []
        for (index, run) in runs.enumerated() {
            if ranged.contains(index) {
                raw.append(((run.start + run.end) / 2, WindowWords.range(run.start, run.end)))
                continue
            }
            if run.start > CareDay.startHour + 0.02, index == 0 || !ranged.contains(index - 1) {
                raw.append((run.start, WindowWords.clock(run.start)))
            }
        }
        for index in raw.indices where index + 1 < raw.count {
            let next = raw[index + 1].text
            if let last = raw[index].text.last, last == next.last, last == "a" || last == "p", !raw[index].text.contains("–") {
                raw[index].text.removeLast()
            }
        }
        func halfWidth(_ text: String, faint: Bool) -> CGFloat {
            CGFloat(text.count) * (faint ? 2.7 : 3.4)
        }
        var kept: [Mark] = []
        for item in raw.sorted(by: { $0.hour < $1.hour }) {
            let mark = Mark(text: item.text, x: x(item.hour, width), faint: false)
            if let last = kept.last {
                let gap = (mark.x - halfWidth(mark.text, faint: false)) - (last.x + halfWidth(last.text, faint: false))
                if gap < 6 {
                    if mark.text.contains("–"), !last.text.contains("–") { kept[kept.count - 1] = mark }
                    continue
                }
            }
            kept.append(mark)
        }
        let minutesWidth = CGFloat(minutes.count) * 5.6 + 24
        let right = kept.map { $0.x + halfWidth($0.text, faint: false) }.max() ?? 0
        let minutesBlock = right + 8 + minutesWidth <= width
        for hour in [6.0, 12.0, 21.0] {
            let text = hour == 12 ? "12p" : (hour == 6 ? "6a" : "9p")
            let half = halfWidth(text, faint: true)
            var center = x(hour, width)
            if hour == 6 { center = half }
            if hour == 21 { center = width - half }
            if minutesBlock && center + halfWidth(text, faint: true) > width - minutesWidth - 6 { continue }
            let blocked = kept.contains {
                abs($0.x - center) < halfWidth(text, faint: true) + halfWidth($0.text, faint: $0.faint) + 6
            }
            if !blocked { kept.append(Mark(text: text, x: center, faint: true)) }
        }
        return kept
    }
}

func casedLine(_ path: Path, context: GraphicsContext, dashed: Bool) {
    let dash: [CGFloat] = dashed ? [5, 4] : []
    context.stroke(path, with: .color(Palette.night.opacity(0.9)), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: dash))
    context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, dash: dash))
}
