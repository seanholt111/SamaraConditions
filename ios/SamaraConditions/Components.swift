import SamaraCore
import SwiftUI

struct ActivityChips: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActivityKind.allCases, id: \.self) { kind in
                    Button {
                        model.activity = kind
                        if kind != .beach { model.lowTideOnly = false }
                    } label: {
                        Text(kind.title)
                            .font(SamaraFont.chip())
                            .multilineTextAlignment(.center)
                            .foregroundStyle(model.activity == kind ? Palette.text : Palette.muted)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                Capsule().fill(model.activity == kind ? Palette.chipFill : Color.clear)
                            )
                            .overlay(
                                Capsule().stroke(model.activity == kind ? Palette.chipEdge : Palette.chipEdge.opacity(0.7), lineWidth: 1)
                            )
                    }
                    .accessibilityIdentifier("chip-\(kind.rawValue)")
                }
            }
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
            .tint(Palette.cloud)
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
                    Text("Stop")
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

func hatch(in rect: CGRect, context: GraphicsContext, gap: CGFloat) {
    var x = rect.minX - rect.height
    while x < rect.maxX {
        var path = Path()
        path.move(to: CGPoint(x: x, y: rect.maxY))
        path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
        context.stroke(path, with: .color(Palette.hatchLine), lineWidth: 1)
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

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                if spans.isEmpty {
                    Text(emptyText)
                        .font(.system(size: largeSize, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityIdentifier("no-window")
                } else {
                    ForEach(Array(spans.enumerated()), id: \.offset) { _, span in
                        ribbon(span, width: width)
                    }
                }
            }
        }
        .frame(height: height)
    }

    private func ribbon(_ span: TimeSpan, width: CGFloat) -> some View {
        let x0 = axis.x(span.start, width: width)
        let x1 = axis.x(span.end, width: width)
        let short = alwaysRange || span.duration < 3 * 3600 || (x1 - x0) < 130
        let label = shortRange(span)
        let needed = CGFloat(label.count) * labelSize * 0.62 + 14
        let pill = short ? min(width - 4, max(x1 - x0, needed)) : max(8, x1 - x0)
        var origin = (x0 + x1) / 2 - pill / 2
        origin = min(max(2, origin), max(2, width - pill - 2))
        return ZStack {
            if short {
                Text(label)
                    .font(.system(size: labelSize, weight: .heavy))
                    .foregroundStyle(ink)
                    .lineLimit(1)
            } else {
                HStack {
                    Text(CostaRica.clock(span.start))
                    Spacer(minLength: 4)
                    Text(CostaRica.clock(span.end))
                }
                .font(.system(size: largeSize, weight: .bold))
                .foregroundStyle(ink)
                .padding(.horizontal, 8)
            }
        }
        .frame(width: pill, height: height - 4)
        .background(fill, in: RoundedRectangle(cornerRadius: min(6, height / 2), style: .continuous))
        .position(x: origin + pill / 2, y: height / 2)
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

func casedLine(_ path: Path, context: GraphicsContext, dashed: Bool) {
    let dash: [CGFloat] = dashed ? [5, 4] : []
    context.stroke(path, with: .color(Palette.night.opacity(0.9)), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: dash))
    context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, dash: dash))
}
