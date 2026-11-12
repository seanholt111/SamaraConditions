import SamaraCore
import SwiftUI

struct WeekView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            tabs
            if let file = model.file, let alert = file.alerts.first {
                IMNBanner(alert: alert) { model.selectedAlert = alert }
            }
            ScrollView {
                if let file = model.file {
                    let rows = model.orderedDays(file)
                    WeekPages(file: file, days: rows)
                }
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(AppModel.WeekTab.allCases, id: \.self) { tab in
                Button {
                    model.weekTab = tab
                } label: {
                    Text(title(tab))
                        .font(SamaraFont.tab())
                        .foregroundStyle(model.weekTab == tab ? Palette.text : Palette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(model.weekTab == tab ? Palette.chipFill : Color.clear, in: Capsule())
                }
                .accessibilityIdentifier("week-\(tab.rawValue)")
            }
        }
        .padding(3)
        .background(Palette.track, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func title(_ tab: AppModel.WeekTab) -> String {
        switch tab {
        case .heat: return "Heat"
        case .rain: return "Rain"
        case .cloud: return "Cloud"
        case .sea: return "Sea"
        }
    }
}
