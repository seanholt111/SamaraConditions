import SwiftUI

struct SourcesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    block("What this is", """
                    A model for one family's week in Sámara. It is not a measurement and it is not a decision about the water. Flags and signs on the beach beat the app. Stay away from the Río Sámara mouth at the east end of the beach.
                    """)
                    block("Heat", """
                    WBGT is computed with Liljegren's 2008 model from the Open-Meteo forecast for a grid cell near Sámara (9.877, −85.516), not from a thermometer on the sand. Sun uses the forecast shortwave and the 10 m wind. Shade sets the sun to zero and uses the 2 m wind. Open-Meteo's wet-bulb temperature is not used. The minutes (50, 40, 30, 20 per hour outside) are effort bands. Stop is at 32.3 °C WBGT. From 5 December through 26 December the minutes step one band stricter. These bands are not a line that says whether to go out.
                    """)
                    block("Windows", """
                    Beach is sun WBGT under 27.9 °C. Soccer in the sun is under 25.7 °C. Soccer in the shade and jungle are shade WBGT under 27.9 °C. Pool is daylight only, from 15 minutes after sunrise to 30 minutes before sunset. No source covers time in the water. Low tide only keeps the part of the beach window that sits in the two hours before a low and the hour after, and drops that span when the offshore energy in it is above this week's upper quartile.
                    """)
                    block("Waves and the shore", """
                    Swell is the Open-Meteo marine model at 9.875, −85.542. Offshore energy is a model: ρ g² H² T² / 16π, in kilojoules. Energy at the shore is another model, transmission over a reef plus a gap. The reef numbers are guesses: crest 1.0 ft, width 30 m, front slope cot α = 3, gap coefficient 0.30. The calm line is that shore model at a 3 ft tide under this week's median swell. Flat tops at high tide are the formula's ceiling. Forecast, not a buoy.
                    """)
                    block("Rain, cloud, and the week", """
                    Rain and cloud are the Open-Meteo forecast model. Days 4–7 are drawn muted because a forecast is less sure after about three days. A morning run builds one file. The time under the date is when that file was made.
                    """)
                    block("Tides", """
                    Predicted astronomical tide from NOAA CO-OPS station 9684403, Puntarenas, datum MLLW. There is no Sámara gauge. Times are Costa Rica time, UTC−6, with no daylight saving.
                    """)
                    block("Official notices", """
                    IMN alerts are shown with their title and text. The app does not rewrite them into advice.
                    """)
                    block("Credit", """
                    Weather and wave data from Open-Meteo.com, CC BY 4.0. Tide predictions from NOAA, public domain. WBGT code includes software produced by UChicago Argonne, LLC under Contract No. DE-AC02-06CH11357 with the Department of Energy.
                    """)
                }
                .padding(20)
            }
            .background(Palette.night)
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("sources-sheet")
    }

    private func block(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.text)
            Text(body)
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
