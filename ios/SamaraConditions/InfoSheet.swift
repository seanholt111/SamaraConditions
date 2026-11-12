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

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
