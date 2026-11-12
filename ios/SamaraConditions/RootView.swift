import SamaraCore
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Palette.night.ignoresSafeArea()
            VStack(spacing: 10) {
                header
                dateRow
                statusBlock
                content
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .sheet(isPresented: $model.showSources) {
            if ProcessInfo.processInfo.arguments.contains("-open-sources") {
                SourcesSheet()
            } else {
                InfoSheet()
            }
        }
        .dynamicTypeSize(model.typeScale > 1.2 ? .xxxLarge : .large)
        .sheet(item: $model.selectedAlert) { alert in
            AlertSheet(alert: alert)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                sectionButton("Day", .today)
                sectionButton("Week", .week)
            }
            .padding(3)
            .background(Palette.track, in: Capsule())
            Spacer()
            Button { model.showSources = true } label: {
                Text("i")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Palette.text)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Palette.chipEdge, lineWidth: 1))
            }
            .accessibilityIdentifier("sources-button")
            .accessibilityLabel("Sources")
        }
    }

    private func sectionButton(_ title: String, _ section: AppModel.Section) -> some View {
        Button { model.section = section } label: {
            Text(title)
                .font(.system(size: 16 * model.typeScale, weight: .semibold))
                .foregroundStyle(model.section == section ? Palette.text : Palette.muted)
                .frame(width: 78, height: 34)
                .background(model.section == section ? Palette.chipFill : Color.clear, in: Capsule())
        }
        .accessibilityIdentifier("section-\(section.rawValue)")
    }

    private var dateRow: some View {
        Group {
            if model.section == .today, let file = model.file {
                HStack(spacing: 4) {
                    ForEach(0..<7, id: \.self) { offset in
                        let date = CostaRica.dayOffset(offset, from: model.now)
                        let selected = model.dayOffset == offset
                        Button {
                            model.dayOffset = offset
                        } label: {
                            VStack(spacing: 1) {
                                Text(offset == 0 ? "Today" : weekday(date))
                                    .font(.system(size: 11 * model.typeScale, weight: selected ? .bold : .medium))
                                Text(dayNumber(date))
                                    .font(.system(size: 12 * model.typeScale, weight: selected ? .bold : .medium))
                            }
                            .foregroundStyle(offset >= 3 ? Palette.muted : Palette.text)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(selected ? Palette.chipFill : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? Palette.chipEdge : Color.clear, lineWidth: 1))
                        }
                        .accessibilityIdentifier("day-\(offset)")
                    }
                }
            } else {
                HStack {
                    Text(dateChip)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Palette.track, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .accessibilityIdentifier("date-chip")
                    Spacer()
                }
            }
        }
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = CostaRica.calendar
        formatter.timeZone = CostaRica.zone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        String(CostaRica.calendar.component(.day, from: date))
    }

    private var dateChip: String {
        if model.section == .week, let file = model.file, let first = file.days.first, let last = file.days.last {
            return CostaRica.rangeChip(from: first.sunrise, to: last.sunrise)
        }
        return ""
    }

    @ViewBuilder
    private var statusBlock: some View {
        if case .loading = model.phase {
            HStack {
                Text("Getting today's conditions…")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.muted)
                Spacer()
            }
            .accessibilityIdentifier("loading-line")
        } else if case .failed = model.phase {
            EmptyView()
        } else if let file = model.file {
            if model.offline {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                    Text(Freshness.offlineStrip(asOf: file.generatedAt))
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Palette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Palette.track, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityIdentifier("offline-strip")
            } else {
                let line = Freshness.line(asOf: file.generatedAt, now: model.now)
                HStack {
                    Text(line.text + (model.viewingToday ? "" : " · forecast"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(line.stale ? Palette.amber : Palette.muted)
                    Spacer()
                }
                .accessibilityIdentifier("asof-line")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            loadingTracks
        case .failed:
            VStack {
                Spacer()
                Text("Couldn't load conditions. Pull to retry.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Palette.text)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("error-line")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .refreshable { await model.refresh() }
        case .loaded:
            Group {
                if model.section == .today {
                    TodayView()
                } else {
                    WeekView()
                }
            }
            .refreshable { await model.refresh() }
        }
    }

    private var loadingTracks: some View {
        VStack(spacing: 8) {
            emptyTrack("Clouds", height: 72)
            emptyTrack("Tide", height: 78)
            emptyTrack("Heat", height: 220)
            Spacer(minLength: 0)
            chips
        }
    }

    private func emptyTrack(_ name: String, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.track)
            Text(name).font(SamaraFont.band()).foregroundStyle(Palette.muted).padding(10)
        }
        .frame(height: height)
    }

    private var chips: some View {
        ActivityChips()
    }
}

struct AlertSheet: View {
    let alert: OfficialAlert
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Official notice")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.amber)
                    Text(alert.summary.isEmpty ? alert.title : alert.summary)
                        .font(.system(size: 17))
                        .foregroundStyle(Palette.text)
                    if let url = URL(string: alert.url), !alert.url.isEmpty {
                        Link("Open the IMN notice", destination: url)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(Palette.night)
            .navigationTitle(alert.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
