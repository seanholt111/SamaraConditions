> Build-4 UX, final after 9 self-graded rounds (round 9, grade A−). **Not approved yet:** this waits on Sean (12:50pm PT, Nov 12 2026: "I'd like to see her UX changes go through a few rounds of self grading then I'll approve."). Rounds 7–9 answer his 1:08pm PT ask: "On the slider on today - where are the readouts for each of the different parameters like rain and todes? Also realizing the tides graphic should be upgraded to our new wave energy plot from the week view". **On Day, the W4 tide band is replaced by the G2 shore-energy plot, pending Sean's approval** (W4 was locked; Sean asked for the swap, but the drawn result still needs his yes). It replaces the five design-spec-v1 items "Care hours 6a–9p", "Window label wording", "Units °F/°C", "Bottom link row removed" and "Tracer across all bands", and adds the Week row layout, Day navigation and the Day Sea band. Locks untouched: palette C, H2, S2, data states, Sea G2 content (now also used on Day). Never "safe". Wave words and wave numbers are always labelled model.
> Sketches: `final-sheet.png` (build 3 vs final, round-9 frames). Builders: `render.py 9` (+ `PTW=375`/`PTW=393` for width checks), `phone_sheets.py`, `final_sheet.py`. Sizes are pt at a 402 pt screen and must also fit 393 and 375 pt (worst cases below). Data rules are in `render.py` / `data4.py`.

# Care hours 6a–9p
- Day and Week share one fixed axis, 6:00a–9:00p, every day. Ticks: 6a 9a 12p 3p 6p 9p (11/500 muted). The first is leading-aligned and the last trailing-aligned.
- **Sunset mark:** a 1 pt dashed hairline (`#9A9EA6` at 60%, dash 2 2) at sunset through the Clouds, Sea and Heat bands. It starts below the Clouds and Sea header lanes, because in round 8 it cut through "Waves normal". The label "sunset 5:17p" (11/500 muted) sits 5 pt right of the line at the top of the Heat panel, never on the axis, where it hit the 6p tick. If sunrise is after 6a, mark it the same way.
- **After sunset:** the sky band ground goes from track `#161C25` to `#0E121A`. There's no other night colour, and no dimming, because muted already means "less sure" for days 4–7.
- **Every band runs to 9p:**
	- Heat uses the real sun and shade WBGT series. Don't force sun = shade at sunset, because that draws a fake cliff. The data meets by itself within about 40 min.
	- Rain, the Day Sea band and the Week Sea strip run to 9p too.
	- **Cloud also runs to 9p**, with bars after sunset in `#70757E`. This replaces "cloud stops at sunset".
- The Stop hatch is clipped to the area between the shade and sun lines. It never draws above the Sun line (Sean's build-3 bug, `design/inbox/sean-hatch-bug.png`).
- All windows, including Sea calm, are computed over 6:00–21:00 and may run after dark. **Open for Sean:** Beach evening windows mostly sit in the dark (fixture Wed "From 5:00p" against a 5:17p sunset). Option: end Beach and Soccer windows at sunset + 30 min.
- **Server:** `conditions.json` must carry sea points (E_shore and E_off, 5-min) to 21:00; the fixture stops at 17:00. Sea calm then gains evening windows (fixture Wed "From 7:40p", Thu "From 7:50p").

# Window label wording
- Applied to the final window, after the Low-tide toggle. Snap an edge to 6:00a or 9:00p when it falls within 5 min of it.
- 6a–9p → a full-width S2 ribbon reading "All day" (22 pt).
- A window starting at 6a reads "Until 7:30a". One ending at 9p reads "From 5:00p". Anything else shows its range. No window reads "No window".
- Each window follows the rule separately. Week Heat pills use the same words (17 pt, S2 unchanged).
- **Sea header at rest** (Day, round 8+) uses the same words: "Sea (model) · Calm 7:30a–12:40p, from 7:40p · Waves normal". It's built with ViewThatFits: if the full line doesn't fit, drop " · Waves normal", and never scale. Fixture: the full line is 354 pt and fits 354 pt at 402 (Wed). The day word drops for Wed at 393 and 375, and for Thu at 375. With no calm it reads "Sea (model) · No calm · Waves big". The word "Calm" replaces "Calm at shore", and Sources explains "at shore".
- Fixture results (6a–9p): Soccer shade, Jungle and Pool are "All day" all week. Beach is "Until 7:15–7:55a" plus "From 3:30–5:00p". Soccer sun is "Until 6:30–7:00a" plus "From 5:20–8:10p".

# Temperature °F | °C (was "Units")
- **i sheet, in order:** Sources & method › / **Temperature** [°F | °C] / Export log ›. Rows are 48 pt. The segmented control is system style, 104 pt wide.
- One muted 12 pt line under the group: "Numbers only. Colours, windows, tide ft and rain mm stay."
- Default °F, stored locally, applied live.
- **Converts:** every displayed temperature, meaning the readout row (sun, shade, single value), Week values, Sources thresholds (Stop ≥ 32.3 °C / 90.1 °F, with 1 decimal there only) and any air temperature. Elsewhere, show whole degrees.
- **Doesn't convert:** tide stays in ft, because Sean asked about temperature only, NOAA ft is the source, and the reef line is "3 ft". Rain stays in mm, per the locked v20 "full bar = 1 mm/hr".
- Bands, colours, hatch, the min/hr key and all window logic stay in °C.

# Bottom link row removed
- Delete Heat / Tide / Rain / Sources. Sources moves to the i sheet as its first row.
- The bottom element is the chips, plus the Low-tide toggle when Beach is selected. The freed space stays empty; don't fill it.

# Sea band on Day: G2 shore energy replaces W4 tide (rounds 7–9, **pending Sean**)
- **Why:** Sean, 1:08pm: "the tides graphic should be upgraded to our new wave energy plot from the week view". HIG charts: "Maintain continuity among multiple charts that use the same data." It is the same model, the same code and the same scale as Week Sea G2.
- **Band:** the old tide slot, y 292–378 at 402 pt. The top 22 pt is a header lane, and the plot is the 64 pt below it, on track `#161C25`. After sunset, the ground is `#0E121A`, the same as the sky band.
- **Plot (G2 exactly):**
	- The y scale is fixed at 0–210 kJ, the same as Week, so a Day and its Week row look identical.
	- The fill is ocean `#2F66E0` = E_shore, with a white 1.3 pt top line.
	- Offshore energy is a white dotted line (1 pt, 70%, dash 2 2).
	- The calm line is lagoon `#8EE6EE` dashed (1.2 pt, dash 4 3) at 28.5 kJ.
	- The model is `samara/shore.py` (shore energy = E_off × min(1, Kt² + Kd²), Kd 0.30, so a 9% gap leak; Kt is van der Meer/Briganti over the reef). It uses 5-min points from 6a to 9p, with calm < 28.5 kJ and ≥ 15 min.
- **Direct labels**, like W4's "reef" (11/600):
	- "calm line" (lagoon) sits just above the dashes, centred in the longest calm stretch, where the fill is under the line.
	- "offshore" (white 82%) sits under the dotted line where the gap between offshore and shore is widest, between 1p and 4:30p. It's drawn only when the gap is over 16 pt.
- **Calm stretches:** 4 pt lagoon bars in the 10 pt gap under the band, across each calm window, with the times in the header. G2 on Week uses white ribbons, but on Day white already means the activity window (S2), so here they are lagoon, the same colour as the calm line and the word "Calm". Week Sea keeps its white ribbons.
- **Tide height:** a readout only (the Tide pill while dragging). There's no line.
	- A tide line needs a second scale (ft) in a kJ band. Drawn in round 7, it crossed the offshore line and the fill.
	- Low tide is already visible: the reef shelters most at low tide, so the energy dips **are** the low tides (Wed low 9:56a sits inside calm 7:30a–12:40p).
	- Beach's "Low tide only" toggle still filters windows by the tide lean.
	- No ▲ low-tide marker ("the low tide marker is dumb").
- **Sea word, per instant:** **calm** if E_shore < 28.5 kJ, the same rule as the calm stretches. Otherwise **big** if E_off > week Q3 (197 kJ), else **normal**, the same quartile rule as the day word. A big-swell day can read "Calm 18 kJ" at 11a, because the reef shelters the shore (Fri 13).
- **Server:** sea points (E_shore, E_off, 5-min) must reach 21:00. The fixture stops at 17:00, and the sketches compute 17–21h from the hourly fields with the same model.

# Tracer across all bands (round 9)
- **Gesture:** touch anywhere in the chart stack (Clouds + Sea + Heat) and drag. The hit area is the whole stack (HIG). It snaps to 5 min and clamps to 6:00a–9:00p. Release returns everything to rest. It works the same on every day.
- **Line:** a 1 pt white line at 80%, in three segments that skip the text lanes: the sky plot, the Sea plot, and the Heat plot from 16 pt below its top, down to 7 pt above the axis. It never crosses a label ("sunset 5:17p" was cut on evening drags in round 8). A 1.5 pt white stem (3 pt) joins each pill to its plot.
- **Readout pills** (Sean: "where are the readouts … like rain and tides?"). They replace the round-2–6 header-line swap. While dragging, each band's at-rest header hides, and its readout appears as pills in that band's header lane, centred on the line.
	- **Clouds band:** `Cloud 73%` (fill `#C9CED6`, text `#0A0E14`) + `Rain dry` / `Rain 0.4 mm` (fill `#3FA9DC`, text `#0A0E14`). Rain is the hour's forecast mm, not a chance.
	- **Sea band:** `Normal 76 kJ model` (fill ocean `#2F66E0`, white 13/700, "model" white 11/600) + `Tide 7.7 ft ↑` (outlined: fill `#10161E`, 1.3 pt lagoon edge, "Tide" lagoon, value white). Use ↓ when falling and "turning" when the rate is under 0.1 ft/hr. The tide pill is outlined because a lagoon fill means calm.
	- Pills are 18 pt high, fully rounded, with 7 pt inner padding, a 4 pt gap and a 1.5 pt night edge. Names are 12/600 and values 13/700.
	- **Placement:** centre the group on the line, clamp it 6 pt inside the band, then slide it so the line runs through a pill body at least 10 pt from its ends, never through the gap.
	- **Contrast:** 13.5:1 (lagoon text on night), 12.2:1 (cloud), 7.3:1 (rain), 5.1:1 (white on ocean).
	- **Heat:** stays in the big readout row at the top (`— 88°  ┄ 81°  ■ 20 min/hr`, with the time pill at the right). That row is also the at-rest "now" reading, and Sean found it. This is the one reading not on the line (round-9 weakest point, open below).
	- **Dots** (4 pt, night edge) where the line crosses: the cloud bar top (3.5 pt), the rain bar top (rain blue, white edge, only if raining), the Sea fill top, and the Sun and Shade lines (one dot when they are equal).
	- **Nothing covers data.** Pills live only in the header lanes, where no data is drawn.
	- **Sweep (every day × every 5 min × 402/393/375 pt × text ×1.0/1.29/1.53):** no pill leaves its band, the line is never in a gap, and the line always touches its pills. The widest groups at ×1.0 are Sea 266 pt and Sky 180 pt, against 331 pt usable at 375.
- **Large text:** pills scale with Dynamic Type, and the lane height is 4 + 18 × scale. If a band's pill group can't fit one row at 375 pt for that text size (Sea from ×1.29), its pills stack in two rows and the band grows one row (20 pt × scale). The Heat plot gives the height back, and the Sea plot keeps its height.
- **Stale data while dragging:** a stale weather or tide value keeps its pill, but the pill's name turns amber `#F98C0A` (with a 1.3 pt amber edge on the outlined tide pill). A missing value shows "—".
- **Time:** a white pill at the right end of the readout row (15/700 night text, rx 6), for example "3:05p".
- **Now line at rest** uses the same three segments, so it never cuts the header text (it crossed "12:40p" in rounds 3–8).
- **VoiceOver:**
	- The chart stack is one adjustable element. Its label is "Conditions, 6 AM to 9 PM, Wednesday November 11. Beach window until 7:30 AM and from 5 PM. Calm sea at the shore 7:30 AM to 12:40 PM and from 7:40 PM, model estimate."
	- Swipe up or down steps hourly, 6 AM to 9 PM. Each step reads, for example: "3 PM. Clouds 73 percent, no rain. Sea normal, 76 kilojoules at the shore, model estimate. Tide 7.7 feet, rising. Heat in sun 88 degrees, in shade 81 degrees. Beach, 20 minutes per hour outside."
	- Units are spelled out, there are no arrows or parentheses, and the temperature follows °F/°C.

# Day navigation (new; Week row → Day is locked)
- **Top toggle:** **Day | Week**, replacing "Today | Week", because the tab can now show any day (Sean: "Day view"). Needs Sean's ok because it renames a locked tab.
- **Date strip:** replaces the "11 NOV" chip. It's 7 equal cells across the content width, each with the weekday (11/500) over the date (12/500).
	- The selected cell gets chip fill `#1C2430` with a `#3A424C` edge and 600–700 weight.
	- The first cell reads "Today".
	- Days 4–7 use muted text.
	- Cells are drawn 32 pt tall with a 44 pt hit height.
- **Week row tap:** any row on any Week page opens Day on that date. The row is the target. A muted › at the right end of the row's label line shows it's tappable.
- **Swipe:** none. A horizontal drag on the chart is the tracer.
- **A day other than today:** the line under the strip reads "as of 5:02a · forecast". At rest, the readout row shows "high 89°  80°" (the day's max sun and shade), with no now line and no now dots. The Low-tide toggle and the chips keep their state.

# Week pages: full-screen rows (Sean 12:51pm: "Screen space usage seems under optimized here. Same for rain.")
- **One row grammar on all four pages:**
	- An 18 pt label line: day "Wed 11" (14/600) at the left, value (13/600) right-aligned, muted › at the far right.
	- Then the strip at the full content width (370 pt at 402).
	- Rows divide the free height equally down to the axis, which uses the 6a–9p ticks once under the last row.
	- Today's row is bright, and days 4–7 are muted as before.
	- A dashed sunset hairline runs in each strip.
- **Rain:** rows fill 244–830 pt, with strips about 54 pt tall (min 36).
	- 15 hourly bars, 6a–9p.
	- Keep the v20 bar style, the "full bar = 1 mm/hr" head line, values above 1 mm printed on the bar, and the top hairline.
	- Value is the whole-day total ("0.7 mm" or "dry"), plus "· 1.0 overnight" when at least 40% falls outside 6a–9p. That replaces "after dark", since rain to 9p is now drawn. Fixture: only Sun 15 shows it.
- **Cloud:** the same rows. Bars run to 9p, dimmed after sunset. The value is the daylight average %, and the head line reads "full bar = 100% cloud · % = daylight average".
- **Heat:** rows fill 226–690. The bar is 16 pt, with S2 pills unchanged under it. "no window" moves into the label line. Then the key, chips and Low-tide toggle.
- **Sea:** rows fill 244–778. Strip and calm pill are unchanged (G2). The axis runs 6a–9p, and the two-line footer is unchanged. Layout-only change to a locked page: **needs Sean's ok**.

# Added in rounds 4–6
- **Readout zone swatch:** while dragging, a 10 pt swatch in the zone colour sits before "20 min/hr" (hatch for Stop).
- ~~Large text: header readouts wrap~~ superseded in round 7 by the pills (see Tracer › Large text).
- **Stale while dragging:** see Tracer › Stale data (the pill names turn amber, and the values stay).
- **Low-tide toggle tint:** muted `#9A9EA6`, never system green.
- **Low-tide window:** the lean is computed over 6a–9p, and its edges round to 5 min like every other window.
- **Open for Sean: dark-hour windows.**
	- **A:** all windows run to 9p, as now. Wed Beach "From 5:00p", Beach + Low tide "From 8:05p", Soccer sun "From 8:05p".
	- **B (my pick):** sun activities (Beach, Low-tide Beach, Soccer sun) end at sunset + 30 min, rounded down to 5 min. Wed Beach becomes "5:00–5:45p", and Low tide becomes "No window". Soccer shade, Jungle and Pool still run to 9p. A small dotted tick marks the cutoff.

# Screenshots to send me before this reaches a phone
1. Day at rest, Beach (Sea plot, lagoon calm bars, header).
2. Drag at 9a: pills clamped at the left.
3. Drag at 3p.
4. Drag at 7p: after dark, the line skips "sunset 5:17p".
4b. Fri 13 drag at 11a: "Calm 18 kJ" on a "Waves big" day.
5. Jungle "All day".
6. Fri via a Week row tap.
7. Week Rain, Cloud, Heat and Sea.
8. The i sheet with °C selected.
9. One frame at Dynamic Type xxxLarge while dragging (Sea pills on two rows).
10. Beach + Low tide only.

# Open for Sean (carried)
1. **Day Sea band (new, rounds 7–9):** approve G2 on Day in place of locked W4, with tide height as a readout only (no tide line).
2. **Dark-hour windows A/B** (see "Added in rounds 4–6"). My pick is B: sun activities end at sunset + 30.
3. **Today → Day rename** of the locked top toggle.
4. **Week Sea layout** (full-width rows; G2 content unchanged).
5. **Heat readout placement:** keep heat in the top row (my pick), or also give Heat a pill on the line for one grammar.
