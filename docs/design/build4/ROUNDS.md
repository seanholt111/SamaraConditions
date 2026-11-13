# Build-4 UX: nine self-graded rounds (12 Nov 2026, PT)
Sean, 12:50pm PT: "I'd like to see her UX changes go through a few rounds of self grading then I'll approve." This is design only, and nothing has gone to the coder. The data is the real fixture (Wed 11 – Tue 17 Nov 2026). Frames are 402 pt, matching Sean's phone, and collisions were also checked at 393 and 375 pt. Ground truth is Sean's build-3 shots in `design/inbox/` and rc3 `repo/screenshots/`.
Added scope during the work: Week Cloud and Rain screen use ("Screen space usage seems under optimized here. Same for rain."), the same check on Week Heat and Sea, and moving between days inside Day view (Week row tap → Day is locked, per Sean at 12:53pm).

| Round | Grade | Weakest point | What changed |
|---|---|---|---|
| 1 | **C+** | The tide header readout overlaps by **215 pt** (header 367 pt + readout 195 pt in 354 pt), so the proposal as written can't be built | Drew the 5 proposals as written. Week Rain/Cloud/Heat/Sea moved to day-name-above rows with full-width strips. Day nav A was chevrons plus swipe |
| 2 | **B** | The time pill sits under the readout row for every drag from 6:00a to 1:50p (10 pt overlap) | Whole-line header swap with band names kept. Shorter tide header (309 pt). Sunset label moved to the top of the Heat panel with a hairline through all bands. Real sun data after dark (no fake cliff). Cloud runs to 9p dimmed. Date strip plus Day \| Week. "Temperature" row. Week row ›. (Also broke locked S2 on Week Heat/Sea, reverted in round 3) |
| 3 | **B+** | Beach evening windows run into full dark ("From 5:00p" against a 5:17p sunset). That's a rule question for Sean | Time pill moved into the readout row. min/hr added to the drag readout (no colour-only). Tide header lane reserved (contrast 1.0 → 12:1). S2 pills restored on Week. Date strip says "Today" with 44 pt hit areas. One-line i-sheet note |
| 4 | **B+** | At large text (xxLarge and up) the one-line readouts overflow: 282 pt × 1.29 = 364 pt in 343 pt | Checked the morning drag (9a), °C and the Soccer sun dark window. Zone swatch before "20 min/hr". More room on Week Heat |
| 5 | **B+** | The two-line wrap squeezes the tide water to about 44 pt and the cloud bars to about 30 pt | Readouts wrap at large text. Stale tide shows an amber name and keeps values. Option B drawn (sun windows end at sunset + 30) |
| 6 | **A−** | Dark-hour Beach windows need Sean's call. Low tide only on Wed gives "From 8:05p", 2 h 48 after sunset | Bands grow one line at large text. Low-tide toggle tinted muted, not green. Low-tide edges rounded to 5 min |
| 7 | **B** | The calm stretches are white bars, the same white as the Beach window ribbon, so white means two things on one screen | Sean 1:08pm: the W4 tide band is replaced by the G2 shore-energy plot (same 0–210 kJ scale as Week). The drag readouts are pills riding the line in each band's lane, plus dots on the cloud bar, rain bar and Sea curve. Options B (big values beside dots: covers data, clips at the edge) and C (one card on top: your eye leaves your finger, and it covers the day strip) were cut. The tide line variant was cut (two scales in one band) |
| 8 | **B+** | The now line and sunset hairline cut through the Sea header text at rest, and the lagoon tide pill shares lagoon with calm | Lagoon calm bars. "Sea (model) · …" header with ViewThatFits. The line always runs through a pill body. Pills stack at large text and the band grows. Chips fit 375 pt (they were 1 pt over). Labels at 11 pt. Full sweep clean |
| 9 | **A−** | Heat is the one reading not on the line: it stays in the top row, on purpose, as the at-rest "now" reading | The now line, tracer and sunset line skip every label lane. The tide pill is outlined. "model" is pure white (4.1 → 5.1:1). Final frames: rest, 9a, 3p, 7p, plus 375 pt (`r9/w375/`), 393 pt (`r9/w393/`) and xxxLarge |

**Final grade (after round 9): A−** (the round-6 A− covered the old package; rounds 7–9 re-graded it with Sean's 1:08pm asks). After round 6: A−. Earlier note: To reach A, it needs Sean's call on dark-hour windows and a check on a real device in SF Pro. The sketches use Inter, which is about 3–5% wider, so the real widths should come in under what I measured.

## Week screen-use findings (Sean, 12:51pm)
| Page | rc3 waste (measured on the rc3 screenshots) | Final |
|---|---|---|
| Rain | day-label column 35% of width; bars in about 60%; rows about 28 pt strips; bottom about 33% empty; axis stops at 5p | name and total on one line above; strips 370 pt (92% of the screen) × about 54 pt; 7 rows fill 244–830 pt; 6a–9p, 15 hourly bars |
| Cloud | the same as Rain (Sean's own Cloud screenshot path wasn't on the box; I used rc3 `week-cloud.png`) | the same as Rain; night bars dimmed; "% = daylight average" |
| Heat | 70 pt label column (19%); bottom about 23% empty | name above, bar 370 pt, rows fill 226–690, S2 pills unchanged |
| Sea | 70 pt label column (19%); bottom about 15% empty; axis to 5p | name above, strips 22% wider, rows fill 244–778; G2 content unchanged (layout-only change to a locked page; needs Sean's ok) |

## Day navigation (only how to move inside Day view)
- **A. Swipe / chevrons (round 1): cut.** A horizontal drag on the chart is the tracer scrub. A swipe zone anywhere else is invisible, and the chevrons are 20 pt targets.
- **B. 7-cell date strip (rounds 2–3): picked.** The strip replaces the date chip, one tap reaches any day, and it shows where you are in the week. The top toggle becomes **Day | Week**. The tab no longer means only today, and Sean calls it "Day view". This renames the locked "Today" tab, so it needs his ok.

## Rounds 7–9 (Sean 1:08pm PT: readouts for rain and tide; tide graphic → Week wave-energy plot)
Rounds 4–6 polished the old package and missed both asks. Rounds 7–9 address only those two.
- **Readout options (round 7, drag 3:05p):**
	- **A, pills on the line: picked.** The value sits where your finger is, in a lane with no data under it.
	- **B, big values beside dots: cut.** They cover the cloud bars and the Sea fill, and at 3p the Sea value clipped off the left edge.
	- **C, one card over the top: cut.** It pulls your eye away from your finger (Tog), covers the day strip, and separates each value from its curve.
- **Tide height:** kept as a readout only. A thin tide line was drawn in round 7 and cut: two scales in one band, and it crossed the offshore line. The energy dips mark the low tides.
- **Sweep:** every day × every 5 min × 402/393/375 pt × text ×1.0/1.29/1.53. No pill leaves its band, and the line never falls in a gap or is detached from its pills. The rest header falls back for Wed (393, 375) and Thu (375). Logs: `r7/`–`r9/issues.txt`.
- **Cold auditor (separate pass, screenshot + CHECKLIST only, round 9):**
	- A-CONTRAST passes: pill text 5.1–13.5:1, labels about 12:1 on track.
	- V-PAD passes: pill padding 7 pt, 6 pt to band edges.
	- No line crosses text.
	- A-COLOR-NOT-ALONE passes: every pill carries words.
	- V-DISC is a partial fail: Heat still reads in the top row, not on the line.
	- A-ORDER: the eye lands on the heat plot first, then the pills while dragging.

## Reread trail
| Round | File § | Quote | Effect |
|---|---|---|---|
| 1 | apple-hig-phone-visuals/sections/14-hig-charts-p2.md | "consider expanding the hit target to include the entire plot area, letting people scrub across the area to reveal various values" | changed: swipe-for-days cut |
| 1 | tog-first-principles/sections/10-discoverability.md | "Any attempt to hide complexity will serve to increase it" | changed: a visible day control is required |
| 2 | tog-first-principles/sections/14-fitts-s-law.md | "Use large objects for important functions (Big buttons are faster)." | changed: chevrons → 7 equal cells |
| 2 | vitsoe-rams-ten-principles/sections/10-…md | "Less, but better" | changed: one cloud rule (to 9p) instead of a sunset exception |
| 3 | 14-hig-charts-p2.md | "Avoid relying solely on color to differentiate between different pieces of data or communicate essential information in a chart." | changed: min/hr text in the drag readout |
| 3 | 14-hig-charts-p2.md | "spelling out "60 minutes" or "60 meters" is clearer than using the abbreviation "60m."" | changed: VoiceOver spells out units, with no arrows |
| 3 | live HIG Segmented controls (fetched 12 Nov 2026) | "Use a segmented control to provide closely related choices that affect an object, state, or view." | kept: °F \| °C segmented |
| 3 | tog-first-principles/sections/08-consistency.md | "Where it makes sense to standardize their location, do so." | kept: the same row grammar on all four Week pages |
| 7 | apple-hig-phone-visuals/sections/14-hig-charts-p2.md | "they can drag a vertical indicator through the line graph, revealing the value at the selected time" | changed: values ride the line (pills), not a header swap |
| 7 | apple-hig-phone-visuals/sections/15-hig-charting-data.md | "Maintain continuity among multiple charts that use the same data." | changed: Day Sea uses G2 exactly, same 0–210 kJ scale as Week |
| 7 | tog-first-principles/sections/10-discoverability.md | "By forcing the user to move the mouse away from their current center of interest … they lose a primary cue" | cut: option C (card at the top) |
| 8 | apple-hig-phone-visuals/sections/06-hig-color-p1.md | "Avoid using the same color to mean different things." | changed: calm bars lagoon (white = window); r9 tide pill outlined |
| 9 | apple-hig-phone-visuals/sections/14-hig-charts-p2.md | "don't require interaction to reveal critical information" | kept: calm times in the at-rest Sea header; tide ft only on drag (low tides = energy dips) |
Ideas cut for lack of source support: a new colour for night hours; dimming data after sunset (the muted look already means "less sure" for days 4–7).
Phone-legible sheets: `rN/sheet-phone.png` for rounds 1–9, plus `r4/`, `r6/`, `r7/` and `r9/sheet-phone-2.png`. The r7 sheet 2 shows the cut options.
Process note: no separate subagent was available, so the cold-auditor pass was a separate pass with no history, reading only the screenshot and CHECKLIST.md.
