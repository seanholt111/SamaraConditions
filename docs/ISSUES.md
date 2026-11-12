# Sámara Conditions v1 — issues

Written before the app code, from the locked spec (`docs/source/design-spec-v1.md`, Pepper, 12 Nov 2026) and Sean's brief. Section numbers below are the new spec: §4 data states, §6 rejected, §7 equations.

Each item has the behaviour, the screen states it covers, one check, and any open question. Design questions are listed at the bottom for Pepper. They are not guessed into extra UI. Logic with a spec answer is implemented as written.

The word "safe" is not used anywhere. Wave and shore numbers are a model. Flags and signs on the beach beat the app.

## 1. Today chart

**Behaviour.** One stacked chart: a Clouds/Rain sky band (rain bars only when rain > 0), a W4 tide band (reef line at 3 ft), and an H2 heat plot (palette C). The hour axis starts at sunrise and runs to 9p. Sun is a cased solid white line, shade a cased dashed white line, with dots at now. The now line stops 7 pt above the axis. Readout is a solid swatch plus the sun temperature and a dashed swatch plus the shade temperature, with no words. Dragging the chart shows the values at that time.

**States.** Loading shows the empty named tracks and no chart. Fresh, stale, offline, and an IMN alert draw this chart. Error draws no chart.

**Check.** With the 11 Nov fixture and now at 5:00p Costa Rica, the readout is 27.9° and 26.6°.

## 2. Activity chips and the low-tide toggle

**Behaviour.** Chips are Beach, Soccer sun, Soccer shade, Pool, Jungle. Selected fill `#1C2430`, edge `#3A424C`. The S2 ribbon sits on the time axis. A window shorter than 3 hours gets one 17 pt range label. A longer window gets the start and the end in 22 pt. Empty is "No window" on Today. "Low tide only" shows only while Beach is selected. On, the ribbon is the beach heat window intersected with the tide lean. No reason line and no low-tide marker.

**States.** The chips stay visible in loading, fresh, stale, offline, and the alert. They hide on the error screen, which has nothing to switch.

**Check.** 11 Nov, Beach: ribbon 5:50–7:30a. Beach with low tide on: "No window". Soccer sun: 5:50–6:40a. Soccer shade, Pool, and Jungle: 5:50a to 4:45p.

**Open (layout, not a new control).** The 3 hour split between one label and two is the cutoff that matches the locked renders (1h40 gets one label, the full day gets two). Pepper can move it.

## 3. Week

**Behaviour.** Four equal tabs, Heat, Rain, Cloud, Sea, 15 px semibold, 34 pt tall. Seven rows, today on top. Days 4–7 are muted. Heat draws beach-sun zone colours, the S2 ribbon for the selected chip, and "no window" in lowercase when a day has none. The low-tide toggle is on the Heat tab only, and only for Beach. Rain and Cloud are hourly bars from zero in a 24 pt strip, with no bottom swatch key. Rain height caps at 1 mm/hr and prints the value on the bar when it is over 1. The rain label is the whole-day total ("X.X mm" or "dry") plus "· X.X after dark" when at least 40% falls outside 6a–5p. Cloud height is total cloud percent. The cloud label is the daylight mean, rounded to the nearest percent. Sea is shore energy, 0–210 kJ, strip 38 pt, with the offshore dotted line, the calm line at the week's threshold, and the calm ribbon. No calm window says "no calm".

**States.** Same freshness rules as Today. A missing today is an empty row; the other days stay.

**Check.** 11 Nov cloud daylight mean is 33%. Rain label is "0.7 mm · 0.6 after dark". Sea calm ribbon on Wednesday is 7:30a–12:40p when the threshold is 28.5 kJ.

**Open for Pepper.** See questions 1 and 2 below. Week Heat zone colours stay on sun WBGT, which is what §8.4 says the tab currently shows. The ribbon follows the chip, because the chips and the low-tide toggle are on the locked Heat render.

## 4. Data states

**Behaviour.** Amber `#F98C0A` is only for stale data and official notices (the heat palette also uses that hex for the 40 min/hr swatch; that swatch stays).

- Loading, first launch only: empty tracks and "Getting today's conditions…". No spinner.
- Fresh: muted line under the date chip, "as of 5:02a".
- Stale, file older than 30 h: that line turns amber, "as of yesterday 5:02a · may be out of date". At exactly 30 h the line is still fresh.
- One feed older than 30 h while the file itself is fresh: only that block's header turns amber and gains "· as of yesterday 5:02a". Sky and Heat follow the forecast feed. Tide follows the tide feed. The "Waves" word follows the marine feed.
- Offline: full-width strip directly under the date chip, track `#161C25`, text `#9A9EA6`, slashed-wifi glyph, exact pattern "Offline · showing 5:02a data". Drawn from the cache. If the cache has no today, today is empty and the other days stay.
- Error, no cache: one centred line, "Couldn't load conditions. Pull to retry."
- IMN alert A: full-width banner above the chart, "⚠ IMN: <official title> · official notice", with a leading amber bar. Tap opens the official text. Hidden when there is no alert. Alert B is not built.

**States.** This item is the states.

**Check.** Swift tests cover the 30 h boundary, the yesterday wording, and opening a cache while offline. UI tests cover one launch per state.

## 5. Sources

**Behaviour.** The info button and the Sources row open one sheet. It states the method, the caveats, and the attributions. Open-Meteo is credited CC BY 4.0. NOAA is credited. Forecast, model, and prediction are named separately. The sheet says the shore numbers are a model, names the four guesses, and says flags and signs win. It says to avoid the Río Sámara mouth at the east end.

**States.** The sheet can open on top of fresh, stale, and offline. It does not change the data state.

**Check.** The sheet contains "Open-Meteo" and "NOAA" and does not contain the word "safe".

## 6. Bottom row

**Behaviour.** The locked Today renders and the states sketch show a bottom row: Heat, Tide, Rain, Sources. Heat, Tide, and Rain scroll to that band. Sources opens the sheet.

**States.** Hidden on error. Visible otherwise.

**Check.** The four labels are on the Today screen in the fresh screenshot.

**Open for Pepper.** Question 3. This row is in the renders and was not in the rejected list, so it is built.

## 7. Server file

**Behaviour.** `conditions.json` has `schema_version`, `generated_at`, and per-feed `as_of`. The phone draws. The server computes WBGT (Liljegren, sun and shade), activity windows, the beach lean, offshore energy, week quartiles, shore energy, the calm threshold, calm windows, the reef-shelter times, and the wave word. A bad fetch or a failed validation does not replace a good file. A failed feed keeps the previous `as_of`. The job runs at 10:17 and 11:17 UTC (04:17 and 05:17 Costa Rica) and on workflow_dispatch, and it commits a heartbeat.

**States.** Not a screen. The file's age drives fresh and stale.

**Check.** Pytest: published quartiles 126.1 / 157.0 / 197.0 kJ (n = 112); calm threshold 28.5 kJ from the published medians 157.0 kJ, 0.82 m, 10.4 s; Wednesday calm window within ±5 min of 7:30a–12:40p; NOAA hi/lo within 1 min and 0.01 ft of `this-week-tides.csv`.

**Data gap, not a design question.** The bundle's hourly file is 11 Nov only. `this-week-note.md` points at `hourly-all-days.csv`, which was not in the bundle, and the live model has already moved, so Thu–Tue calm windows cannot be recomputed from the frozen inputs. Wednesday is recomputed from the hourly CSV and matches. The fixture pins the published quartiles and the 28.5 kJ threshold. Hours on 12–17 Nov in the screenshot fixture come from an Open-Meteo snapshot taken 12 Nov 2026 so the week charts have real bars; they are not the 11 Nov 3pm snapshot.

## 8. Tides

**Behaviour.** NOAA CO-OPS 9684403, datum MLLW, time zone lst, predictions. The app bundles hourly values and hi/lo for 1 Dec 2026–30 Jun 2027. The phone interpolates with the cosine in §7.3. The morning file also carries today ±7 days. costaricawaves.com and Open-Meteo sea level are not used.

**States.** Tide still draws offline during the stay, from the bundle.

**Check.** Swift: cosine height and Costa Rica formatting. Pytest: the November NOAA fixture against the CSV.

## 9. Heat minutes and the first three weeks

**Behaviour.** Zones follow §7.1. From 5 Dec through 26 Dec inclusive, the minutes step one zone stricter (40 / 30 / 20 / Stop / Stop). The window cutoffs in §7.2 do not change. Stop is a hatch, hour by hour, and is not drawn as a fifth colour. The key shows 50, 40, 30, 20, and shows Stop only when a stop hour is on screen.

**States.** The key is on Today and on Week Heat.

**Check.** Swift: 24.0 °C is 50 min/hr on 11 Nov and 40 min/hr on 5 Dec. 32.3 °C is Stop.

## 10. Wave word

**Behaviour.** The tide header ends with "Waves calm", "Waves normal", or "Waves big". The day's 6a–9p median offshore energy is compared with the week quartiles: below Q1 is calm, through Q3 is normal, above Q3 is big. 11 Nov median 130.7 is normal.

**States.** The word is part of the tide header, and it is the piece that turns amber when only the marine feed is stale.

**Check.** Fixture Wednesday wave word is "normal".

**Open for Pepper.** Question 4. The plan's words were calm / typical / big. The locked header says "Waves normal", so the middle word is "normal".

## 11. What is not built

Everything in spec §6: Heat Clock, Overview, a verdict headline, colour-class rain and cloud strips, the 0.2 / 0.5 / 1+ ladder, hour pin stripes, white outline boxes, dimming outside the window, a low-tide marker, safe-green, the word "safe", the v9 cap bracket, Sea E1, `reef_model.py`, Sea G3, and IMN alert B.

Also not built, because they are still open in §8: a Friday big-swell flag, a Kt-ceiling caption, a field measurement, a separate shade colouring for Week Heat, and a real in-water pool rule. Pool stays daylight only.

## Pepper, 12 Nov 2026, on rc1

1. Week Heat bars follow the chip. Soccer shade and Jungle use shade WBGT. Beach, Soccer sun, and Pool use sun WBGT.
2. Rain labels stay with the spec. The v20 "most 5p" line is retired.
3. The bottom row stays.
4. Wave words are calm / normal / big. Never "safe".
5. The low-tide switch stays grey or white, not green.
6. Under 3 hours, one range label. A longer Today window uses the two end times. Sea always uses one range.
7. Today’s bands run from sunrise to sunset. The first hour label is sunrise.
8. Week Heat is continuous colour runs. No hour seams.
9. The tide header is “Tide · Calm at shore <that day’s Sea window> · Waves …”, the same window as the Sea ribbon.

## Post-v1, Pepper, not in this build

Logged after she signed off rc3. Do not build these in v1.

1. Tide headroom. Keep at least 16 pt of empty track above the crest on high-tide days. On the rc3 Today screen the crest still comes close to the right end of the header.
2. Week Heat ribbon. Use a slimmer ribbon when a window is 8 hours or longer.

## Phone, build 3, 12 Nov 2026, as of 10:53a

Evidence is `docs/screenshots/phone-b3/samara-phone-bug-hatch.png`. Sean, live data, Soccer sun. The file is `data/fixture-live-2026-11-12.json`.

### A. Stop hatch escapes the heat curve

**What happened.** The pink Stop hatch is drawn as diagonal strokes across the axis-aligned bounding rectangle of the stop band. The fill of that band already follows the curve between the shade line and the sun line. The strokes do not. Each line runs the full height of the rectangle and starts a full height to the left of it, so the hatch climbs above the Sun line, with a slanted top, and hangs in the hours before the stop run. On 12 Nov the sun hours that reach Stop (32.3 °C) are 9a, 10a, and 1p. Shade does not reach Stop.

**Fix.** Clip the hatch strokes to the same path that is filled. The hours stay the hours whose WBGT is Stop. Do not change the band geometry.

**Check.** Live fixture, Today, Soccer sun and Beach. The hatch stays inside the painted band.

### B. Export log

**Behaviour.** A rotating log in Application Support, about 1 MB, keeping the current file and one previous file. It records the version and build, launches, each fetch (URL, HTTP status, bytes, generated_at, schema_version, and decode errors verbatim), whether the screen used the cache or a fresh file, the data state (fresh, stale, offline, error), chip changes, and caught errors. No personal data.

The existing i sheet gains one plain text row at the bottom, "Export log". It opens the iOS share sheet with the .txt file.

**Check.** The row is on the i sheet. A unit test rotates the file and keeps two copies.

## Build 4 UX, approved by Sean 12 Nov 2026, 1:40pm PT

Sean said "Nice, send it." `docs/design/build4/` is the graded spec. His calls override anything the spec still marks open:

1. On Day, the shore-energy plot replaces the tide band. Tide height is a readout only. There is no tide line.
2. The heat readout stays in the top row. There is no heat pill on the line.
3. Option B: Beach, Low-tide Beach and Soccer sun end at sunset plus 30 minutes, rounded down to 5 minutes, with a dotted tick at that cutoff. Soccer shade, Jungle and Pool run to 9p.
4. The top toggle says Day, not Today. The first date cell still says Today.
5. Week Sea uses the same full-width rows as the other Week pages. The shore-energy drawing itself is unchanged.

The morning file must carry shore and offshore energy every 5 minutes from 6:00a through 9:00p. The job runs `python -m samara live`, which builds that file.

**Care hours.** Day and Week use 6:00a–9:00p. Ticks are 6a, 9a, 12p, 3p, 6p, 9p. A dashed sunset hairline crosses Clouds, Sea and Heat, with "sunset 5:17p" at the top of Heat. After sunset the ground is `#0E121A`. Cloud bars after sunset are `#70757E`. Rain, heat and sea run to 9p. The Stop hatch stays clipped to the band under the Sun line.

**Windows.** Computed over 6:00a–9:00p, then option B, then the Low-tide toggle. Wording: "All day", "Until …", "From …", a range, or "No window". Week uses the same words in lowercase. The Sea header uses them too: "Sea (model) · Calm … · Waves …".

**Temperature.** The i sheet order is Sources & method, Temperature °F | °C, Export log. Default is °F. Colours, windows, feet and millimetres stay in their own units. Whole degrees on screen. Sources thresholds keep one decimal.

**Tracer.** Dragging the chart snaps to 5 minutes. A white line runs through the three plots and skips the header lanes. Cloud, rain, sea and tide readouts are pills in those lanes. The time sits in the top readout row.

**Day and Week.** A 7-day strip picks the day. A Week row opens that day. The Heat / Tide / Rain / Sources row is gone. Chips, and the Low-tide toggle on Beach, are the bottom of the screen.

**Check.** SamaraCore tests cover the Wednesday labels, option B, °F not moving a window, pill placement on the 402/393/375 sweep, and calm through 9p. Screenshots match the round-9 list.
