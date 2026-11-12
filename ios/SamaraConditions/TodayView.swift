import SamaraCore
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let file = model.file, let alert = file.alerts.first {
                        IMNBanner(alert: alert) { model.selectedAlert = alert }
                    }
                    if let file = model.file, let day = model.today(file) {
                        TodayChart(
                            day: day,
                            extrema: model.extrema(for: file),
                            activity: model.activity,
                            lowTideOnly: model.lowTideOnly,
                            now: model.now,
                            forecastStale: model.feedIsStale(file.feeds.forecast, file: file),
                            tideStale: model.feedIsStale(file.feeds.tides, file: file),
                            marineStale: model.feedIsStale(file.feeds.marine, file: file),
                            forecastAsOf: file.feeds.forecast.asOf,
                            tideAsOf: file.feeds.tides.asOf,
                            marineAsOf: file.feeds.marine.asOf,
                            staleNow: model.now,
                            scrub: $model.scrub
                        )
                        MinutesKey(showStop: day.hours.contains { HeatScale.isStopHour(wbgt: $0.wbgtSunC, on: day.sunrise) })
                    }
                    ActivityChips()
                    LowTideToggle()
                    HStack(spacing: 18) {
                        link("Heat", "heat", proxy)
                        link("Tide", "tide", proxy)
                        link("Rain", "sky", proxy)
                        Button("Sources") { model.showSources = true }
                            .accessibilityIdentifier("sources-link")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func link(_ title: String, _ id: String, _ proxy: ScrollViewProxy) -> some View {
        Button(title) {
            withAnimation { proxy.scrollTo(id, anchor: .top) }
        }
    }
}
