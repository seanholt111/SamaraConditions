import SamaraCore
import SwiftUI

struct InfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @State private var shareURL: ShareItem?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Sámara Conditions")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .padding(.bottom, 16)
                VStack(spacing: 0) {
                    NavigationLink {
                        HeatRulesView()
                    } label: {
                        HStack {
                            Text("Heat rules").font(.system(size: 17)).foregroundStyle(Palette.text)
                            Spacer()
                            Text("›").font(.system(size: 20)).foregroundStyle(Palette.muted)
                        }
                        .frame(height: 48)
                        .padding(.horizontal, 16)
                    }
                    .accessibilityIdentifier("Heat rules")
                    Divider().overlay(Palette.chipEdge)
                    NavigationLink {
                        SourcesSheet()
                    } label: {
                        HStack {
                            Text("Sources & method").font(.system(size: 17)).foregroundStyle(Palette.text)
                            Spacer()
                            Text("›").font(.system(size: 20)).foregroundStyle(Palette.muted)
                        }
                        .frame(height: 48)
                        .padding(.horizontal, 16)
                    }
                    .accessibilityIdentifier("Sources & method")
                    Divider().overlay(Palette.chipEdge)
                    HStack {
                        Text("Temperature")
                            .font(.system(size: 17))
                            .foregroundStyle(Palette.text)
                        Spacer()
                        Picker("Temperature", selection: Binding(
                            get: { model.useFahrenheit },
                            set: { model.setFahrenheit($0) }
                        )) {
                            Text("°F").tag(true)
                            Text("°C").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 104)
                        .accessibilityIdentifier("temperature-unit")
                    }
                    .frame(height: 48)
                    .padding(.horizontal, 16)
                    Divider().overlay(Palette.chipEdge)
                    row("Export log", identifier: "export-log") {
                        if let url = try? model.prepareLogExport() {
                            shareURL = ShareItem(url: url)
                        }
                    }
                }
                .background(Palette.chipFill, in: RoundedRectangle(cornerRadius: 12))
                Text("Numbers only. Colours, windows, tide ft and rain mm stay.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 12)
                Spacer()
            }
            .padding(20)
            .background(Palette.night)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
        .sheet(item: $shareURL) { item in ActivityShare(url: item.url) }
        .accessibilityIdentifier("info-sheet")
    }

    private func row(_ title: String, identifier: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 17)).foregroundStyle(Palette.text)
                Spacer()
                Text("›").font(.system(size: 20)).foregroundStyle(Palette.muted)
            }
            .frame(height: 48)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? title)
        .accessibilityLabel(title)
    }
}

struct HeatRulesView: View {
    @EnvironmentObject private var model: AppModel

    private var fahrenheit: Bool { model.useFahrenheit }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Heat rules")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text(fahrenheit
                     ? "WBGT ranges in °F. Columns are From Dec 26, then Dec 5–25."
                     : "WBGT ranges in °C. Columns are From Dec 26, then Dec 5–25.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.muted)
                rule("<25.7 °C", "<78.3 °F", "OK · 50/10", "OK · 40/20")
                rule("25.7–27.8 °C", "78.3–82.0 °F", "OK · 40/20", "OK with cap · 30/30, outing <2 h")
                rule("27.9–30.0 °C", "82.2–86.0 °F", "OK with cap · 30/30, outing <2 h", "OK with cap · 20/40, ≤1 h")
                rule("30.1–32.2 °C", "86.2–90.0 °F", "OK with cap · 20/40, ≤1 h", "Avoid")
                rule("32.3+ °C", "90.1+ °F", "Avoid", "Avoid")
                Text("Each hour gets a heat zone from the estimated wet-bulb globe temperature (WBGT), a heat measure that combines air temperature, humidity, sun and wind, read for full sun or shade depending on the activity. Cooler zones mean play as usual. Hotter zones still allow play, but with a cap: a set number of minutes of running-around play per hour, with the rest of the hour spent resting in shade with a drink, and shorter total outings. The hottest hours mean skip strenuous play. For the first three weeks (Dec 5–25), while bodies adjust to the heat, each zone counts as one step hotter. After sunset the sun line equals the shade line. UV is separate: from about 10 am to 4 pm when UV is high, wear a shirt, hat and sunscreen. Any sign of heat illness ends play right away, whatever the clock says. The kids' limits are adapted from adult and teen guidance because there's no official schedule for young children.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.text)
                Text("Light play. Wading, sandcastles and calm pool time do not use the minutes cap. Races, tag and other active games do. The December shift applies only to those active games.")
                Text("Kids. Shorter bouts, about 15 and 13 minutes, and a drink in the shade every 20 minutes.")
                Text("Dark. Ocean entry and jungle trails end at sunset. Soccer is on a lit field and the pool is lit, so both run to 9 p.m.")
                Text("UV. At UV 8 or more: shirt, hat, sunscreen. At UV 11 or more, midday means shade or fully covered. UV never closes a window.")
                Text("Sources. ACSM 2023 Table 7 · TB MED 507 (2022) · AAP 2011 · EPA UV Index.")
                Text("Heat numbers are model estimates for the area, not beach readings.")
            }
            .font(.system(size: 15))
            .foregroundStyle(Palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(Palette.night)
        .accessibilityIdentifier("heat-rules")
    }

    private func rule(_ celsius: String, _ fahrenheitText: String, _ later: String, _ early: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fahrenheit ? fahrenheitText : celsius).font(.system(size: 15, weight: .semibold))
            Text("From Dec 26: \(later)")
            Text("Dec 5–25: \(early)").foregroundStyle(Palette.muted)
        }
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
