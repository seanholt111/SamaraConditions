import SamaraCore
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let file = model.file, let alert = file.alerts.first {
                IMNBanner(alert: alert) { model.selectedAlert = alert }
            }
            if let file = model.file, let day = model.today(file) {
                DayScreen(day: day, file: file, extrema: model.extrema(for: file))
            }
        }
    }
}
