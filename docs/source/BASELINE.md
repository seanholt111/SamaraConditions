# Sámara family conditions app: current interface baseline (v18, updated v19, v20, v25, v29, 11 Nov 2026, design only)

Build: `build_v18.py` (stacks on v8 → v9 → v11 → v12 → v13 → v14 → v15 → v16 → v17 patches).
Renders: `iter18/*.png`. Sheet: `iter18/baseline-v18.png`.

## Locked decisions
| # | Decision | Value / rule | Source version | Sean's words |
|---|---|---|---|---|
| 1 | Heat palette C | night bg #0A0E14 · 50 #F6D746 · 40 #F98C0A · 30 #D44842 · 20 #A2337A · Stop = hatch #120814 with #F5C6E0 lines/edge | v9 C, locked v11 | "I actually like baseline best" (5:13pm); "Yeah go ahead" (5:14pm) |
| 2 | Heat legend | 50/40/30/20 min/hr, unit "outside min/hr"; Stop hatched at ≥ 32.3 °C (shown only where Stop occurs) | v8/v12 | — |
| 3 | Heat plot H2 | Shade zone colour fills under the dashed shade line; sun zone colour fills the gap between shade and sun lines (solid); 5-min interpolated zones; Stop hour-binned. "Sun"/"Shade" region labels at 1:30p | v14 H2 | "I like H2" (8:16pm) |
| 4 | Lines | Sun = white solid, cased; shade = white dashed, cased; dots at now | v11 | — |
| 5 | Readout | mini solid-line swatch + sun °, mini dashed swatch + shade ° (no words) | v14 | — |
| 6 | Water band W4 | Tide water-level curve, vertical depth gradient lagoon #8EE6EE → mid #3FA9DC → ocean #2F66E0 (→ #2450C8), white crest line, dashed reef line at 3 ft labelled "reef"; header "Tide · Reef shelters <times> · Waves normal/…" | v13 W4 | "I like w4 - the reef line is intuitive once you know what you're looking at" (7:43pm) |
| 7 | Rain | #3FA9DC (W4 mid stop) bars in the sky band over grey cloud bars; label "Clouds Rain" | v14 | "Rain should use the same blue color too" (7:43pm) |
| 8 | Window mark S2 | Solid white ribbon (6 pt, rounded) on the time axis across each window; big times inside the window (22 pt; short windows: one 17 pt range label) | v16 S2 | "Try a few styles of window" (8:17pm) → my pick |
| 9 | Now line | Stops 7 pt above the axis so it never touches the ribbon | v17 | — |
| 10 | Hour pin stripes | **None** | v18 (this round) | Sean's 8:21pm ask was tested in v17. The baseline brief (8:56pm) excludes them |
| 11 | Low tide | Beach-only toggle "Low tide only". On = ribbon/times narrow to heat ∩ Costa tide lean; empty → "No window" in the time slot. **No reason label, no ▲ marker** | v15 | "the low tide marker is dumb" (8:16pm) |
| 12 | Banned | White outline boxes; dimming outside hours; grey/slate data bands next to the vivid map | v8 feedback, v13 lesson | "nonsensical"; "dim effect isn't super clear" (4:28pm); "terrible… Way too bland" (6:40pm) |
| 13 | Band labels | Every band names itself: "Clouds", "Rain", "Tide", "Heat" | v12 | "I don't know what I'm looking at" (5:56pm) |
| 14 | Chips | Beach · Soccer sun · Soccer shade · Pool · Jungle. Selected = #1C2430 fill, #3A424C edge (same on Today and Week) | v8, unified v18 | — |
| 15 | Window rules | Beach: sun WBGT < 27.9. Soccer sun: sun < 25.7. Soccer shade and Jungle: shade < 27.9. Pool: daylight only. All windows clipped to sunrise + 15 min → sunset − 30 min and rounded inward to 5 min | v8 | — |
| 16 | Week tabs | **Heat · Rain · Cloud · Sea** (4 equal tabs, 15 px/600, 34 pt). Waves + Tide merged into Sea (row 19). Overview, Clock deleted; Rows renamed Heat | v23 | "Waves and tide feel quite interrelated, I wonder if they should be combined" (10:40pm) |
| 17 | Week Heat tab (was Rows) | Beach sun zones per day + S2 ribbon under the bar + range label; chips use the Today style | v18 | — |
| 18 | Rain + Cloud pages (LOCKED v23) | **v20 bar charts, not colour strips.** Hourly bars from a zero baseline in the 24 pt strip: Rain #3FA9DC height = mm capped at 1 mm/hr, values >1 printed on the bar; Cloud #C9CED6 height = total cloud %. No bottom swatch key: one muted right-aligned line above the stack ("full bar = 1 mm/hr" / "full bar = 100% cloud") + faint top hairline per strip. Labels: Rain = whole-day total + "X after dark" when ≥40% falls off-axis; Cloud = daylight mean %. Sea page = see AUDIT-v23+ | v23 | "I like rain and clouds best from round 1, though their scale at the bottom is silly. But bar charts are more dramatic for those than color code" (10:40pm) |
| 19 | Sea page (LOCKED iter29 G2) | Waves + Tide on one page, 7-day stack, y = **energy at the shore** (MODEL, `shore_model.py`). Strip 38 pt on track #161C25, y 0–210 kJ (muted right-aligned head line "full height = 210 kJ"). Fill #2F66E0 = E_shore, white 1.3 pt top line; offshore energy = white dotted line (1 pt, 70% opacity, dash 2 2); calm threshold = lagoon #8EE6EE dashed line (1.2 pt, dash 4 3) at 28.5 kJ. Calm = E_shore < 28.5 kJ (E_shore at a 3 ft tide under week-median offshore Hs 0.82 m / T 10.4 s / E 157.0 kJ), 5-min grid, daylight-clipped, ≥15 min. White 15 pt ribbon (rx 4) under the strip with times inside (11.5 px/800, #0A0E14); no window → muted "no calm". Footer: "fill = energy at the shore · dotted = offshore · dashes = calm line" / "model, not measured · reef size and gaps guessed". Supersedes v25 E1 (crest thickness + tide<3 ft rule) and reef_model.py. Open: Friday big-swell flag; label the Kt ceiling | v29 G2 | "I like g2 of round 3. Let's lock that in." (11:13pm) |
