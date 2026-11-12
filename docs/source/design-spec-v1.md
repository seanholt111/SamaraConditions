> Design only. No app code yet. Decisions locked by Sean on 11 Nov 2026 (PT). Data states locked 12 Nov 2026, 8:02am PT. Fixture week: Wed 11 – Tue 17 Nov 2026 (real data). Stay: 5 Dec 2026 – 1 Jun 2027. Every wave/shore number is a **model, not a measurement**. Never label anything "safe".
> Box record: /workspace/cr-family-environment-2026-11-11/ (`REQUIREMENTS.md`, `concepts/cycle5-week/iter29/BASELINE.md`, `shore_model.py`, `AUDIT-v29.md`).

# 1. App structure
- Two top tabs: **Today** and **Week**.
- Week has 4 equal tabs: **Heat · Rain · Cloud · Sea** (15 px / 600 weight, 34 pt tall).
- **Deleted:** Overview (days × metrics grid) and the Heat Clock.
- "Rows" renamed **Heat** (not "Heat index": the data is WBGT).
- Waves + Tide merged into **Sea**.
- Each Week page answers one question for one parameter. No cross-metric verdict screen.
- Days 4–7 of Week are drawn muted ("less sure after ~3 days").
- Method, caveats, evidence grades live on a Sources sheet; on-screen only short chips.

# 2. Global visual system (locked)
- **Heat palette C** (v9 C, locked 5:13pm; matplotlib inferno-like, cool → hot):
	- Night background `#0A0E14`
	- 50 min/hr `#F6D746` (coolest)
	- 40 min/hr `#F98C0A`
	- 30 min/hr `#D44842`
	- 20 min/hr `#A2337A` (hottest zone)
	- Stop (≥ 32.3 °C WBGT) = hatch `#120814` with `#F5C6E0` lines/edge; never drawn as zone 4
- Water colours (W4): lagoon `#8EE6EE` → mid `#3FA9DC` → ocean `#2F66E0` (→ `#2450C8`). Blue = water only.
- Rain `#3FA9DC` (same as W4 mid). Cloud `#C9CED6`. Track `#161C25`. Text `#F2F2F0`, muted `#9A9EA6`, white `#FFFFFF`.
- **Window mark S2** (v16, locked 8:55pm): solid white rounded ribbon on the time axis across each window, big times inside (22 pt; short windows one 17 pt range label). Replaces the v9 white cap bracket.
- Now line stops 7 pt above the axis so it never touches the ribbon.
- Every band names itself ("Clouds", "Rain", "Tide", "Heat").
- Chips: Beach · Soccer sun · Soccer shade · Pool · Jungle. Selected = `#1C2430` fill, `#3A424C` edge (same on Today and Week).

# 3. Today screen
- One stacked chart: Clouds/Rain sky band (always shown; rain bars only when > 0), Tide band, Heat plot.
- **Heat plot H2** (locked 8:16pm): shade-zone colour fills under the dashed shade line; sun-zone colour fills the gap between shade and sun lines. 5-min interpolated zones; Stop hour-binned. "Sun"/"Shade" region labels at 1:30p.
- Lines: sun = white solid, cased; shade = white dashed, cased; dots at now.
- Readout: mini solid-line swatch + sun °, mini dashed swatch + shade ° (no words). Drag bar shows values at any time.
- **Water band W4** (locked 7:43pm): tide water-level curve with vertical depth gradient lagoon → mid → ocean, white crest line, dashed reef line at 3 ft labelled "reef". Header "Tide · Reef shelters <times> · Waves normal/…".
- Rain bars `#3FA9DC` over grey cloud bars, label "Clouds Rain". Rain framed as relief.
- Hour axis starts at sunrise (5:35a on 11 Nov), not 6a.
- **Activity chips at the bottom** + a readable minutes key (50 / 40 / 30 / 20 min/hr; Stop only where it occurs). Unit "outside min/hr".
- **Beach "Low tide only" toggle**: shown only when Beach is selected. On = ribbon/times narrow to heat ∩ tide lean; empty → "No window". No reason label, **no ▲ low-tide marker**.

<image source="file-upload://4165a137-453f-81ca-b92d-00b20e535779" />
*Today · Beach (iter18)*
<image source="file-upload://4165a137-453f-81bb-b90b-00b29704d248" />
*Today · Beach with Low tide only (iter18)*

# 4. Data states (locked Nov 12, 8:02am PT)
- Applies to the Today screen (and the same rules on Week). Amber `#F98C0A` is reserved for stale data and official notices. Never use the word "safe".
- **Loading** (first launch only): empty named tracks plus "Getting today's conditions…". No spinner.
- **Fresh**: a muted "as of 5:02a" under the date chip.
- **Stale** (data over 30 h): that line in amber `#F98C0A`, "as of yesterday 5:02a · may be out of date". If only some blocks are stale, only that block's header turns amber.
- **Offline**: a full-width muted strip just under the date chip, track `#161C25` with muted `#9A9EA6` text and a slashed-wifi glyph: "Offline · showing 5:02a data". Drawn from cache. If the cache doesn't cover today, today shows empty and the other days stay.
- **Error** (no cache): one centred line, "Couldn't load conditions. Pull to retry."
- **IMN alert A** (locked): a full-width banner above the chart, "⚠ IMN: <official title> · official notice", with a leading amber bar. Tapping through opens the official text. Hidden when there is no alert.

![Today · data states (v2)](/workspace/cr-conditions-app/design/states-sketch-v2.png)
*Today · data states (v2)*

# 5. Week pages
## Heat
- 7 day rows, today on top, shared daylight-clipped hour axis (sunrise → sunset), Beach sun zones per day, S2 ribbon under the bar + range label; chips use the Today style. Days with no window say "no window".
<image source="file-upload://4165a137-453f-8152-9bbf-00b299cf9ebc" />
*Week · Heat*

## Rain and Cloud (v20 bar charts, locked 10:40pm)
- Hourly bars from a zero baseline in a 24 pt strip.
- Rain: `#3FA9DC`, height = mm/hr capped at 1 mm/hr; values > 1 printed on the bar. Label = whole-day total ("X.X mm" or "dry") + "· X.X after dark" when ≥ 40% falls off-axis.
- Cloud: `#C9CED6`, height = total cloud %. Label = daylight mean %.
- No bottom swatch key. One muted right-aligned line above the stack: "full bar = 1 mm/hr" / "full bar = 100% cloud", plus a faint top hairline per strip.
<image source="file-upload://4165a137-453f-81dd-a161-00b26fbccd5f" />
*Week · Rain*
<image source="file-upload://4165a137-453f-81a8-a774-00b27d796ea2" />
*Week · Cloud*

## Sea (iter29 option G2, locked 11:13pm)
- 7-day stack, y = **energy reaching the shore** (shore model §7). Strip 38 pt on track `#161C25`, y 0–210 kJ; muted right-aligned head line "full height = 210 kJ".
- Fill ocean `#2F66E0` = E_shore, white 1.3 pt top line.
- Offshore energy = white dotted line (1 pt, 70% opacity, dash 2 2).
- **Calm threshold line** = lagoon `#8EE6EE` dashed (1.2 pt, dash 4 3) at 28.5 kJ.
- Calm ribbon: white 15 pt (rx 4) under the strip with times inside (11.5 px / 800, `#0A0E14`). No window → muted "no calm".
- Axis labels 6a · 9a · 12p · 3p · 5p.
- Footer (2 lines): "fill = energy at the shore · dotted = offshore · dashes = calm line" / "model, not measured · reef size and gaps guessed".
- Fixture calm windows (11–17 Nov): Wed 7:30a–12:40p · Thu 7:50a–1:35p · Fri 9:15a–1:10p · Sat 9:55a–1:45p · Sun 10:50a–2:30p · Mon 11:10a–3:30p · Tue 12:05p–4:25p.
<image source="file-upload://4165a137-453f-8138-a89a-00b28e8af3ca" />
*Week · Sea — LOCKED G2 (iter29)*

# 6. Rejected / superseded (do not build)
- Heat Clock; Overview grid; single verdict headline.
- Colour-class strips for Rain/Cloud; bottom swatch-ladder scale ("0.2 / 0.5 / 1+").
- Hour pin stripes; white outline boxes; dimming outside the window; grey/slate data bands; ▲ low-tide marker and reason line; safe-green; the word "safe".
- v9 white cap bracket (replaced by S2 ribbon).
- Sea v25 E1 (crest thickness = offshore energy, calm = tide < 3 ft AND 3-h rolling energy < Q3) and `reef_model.py` (H_in = min(H_off, 0.40·h)) — superseded by the shore model.
- Sea G3 two-tone (pale below calm) — my pick, Sean chose G2.
- IMN alert B (slim amber line under the date chip) — rejected 12 Nov 2026, 8:02am PT; A (banner above the chart) is locked.

# 7. Equations for programming
WBGT, week quartiles and shore energy are computed server-side into `conditions.json` each morning; the app only draws.
## 7.1 Heat zones (WBGT, °C, Liljegren sun/shade)
```
zone(w) = 50 min/hr   if w < 25.7
          40 min/hr   if 25.7 ≤ w < 27.9
          30 min/hr   if 27.9 ≤ w < 30.1      (outing < 2 h)
          20 min/hr   if 30.1 ≤ w < 32.3      (≤ 1 h)
          Stop        if w ≥ 32.3
First 3 weeks (5–26 Dec): date-aware swap to next zone's minutes (40 / 30 / 20·≤1 h / Stop / Stop).
```
WBGT: pywbgt.liljegrenWBGT (Liljegren 2008). Inputs: 2 m T, RH, 10 m wind (m/s), shortwave (W/m²), surface pressure. Sun: solar = shortwave, zspeed 10 m. Shade: solar = 0, 2 m wind, zspeed 2 m. Lat/lon 9.88, −85.53. Do not use Open-Meteo wet_bulb_temperature_2m.

## 7.2 Activity windows
```
CUT_MOD = 27.9   CUT_HARD = 25.7
Beach        : sun WBGT   < CUT_MOD
Soccer sun   : sun WBGT   < CUT_HARD   (one zone stricter)
Soccer shade : shade WBGT < CUT_MOD
Jungle       : shade WBGT < CUT_MOD
Pool         : daylight only (no heat cutoff; no source covers time in water)
crossing times = linear interpolation between hourly values
daylight      = [sunrise + 15 min, sunset − 30 min]
window        = clip(raw, daylight), start rounded UP, end DOWN to 5 min; drop if < 5 min
```
## 7.3 Beach "Low tide only"
```
lean(day)  = for each Low tide t_L: [t_L − 2 h, t_L + 1 h]
             reject span if any hourly OFFSHORE energy inside it > week Q3 (fixture Q3 = 197.0 kJ)
             clip to daylight
beach_low  = heat_window(Beach) ∩ lean   (keep pieces ≥ 5 min; else "No window")
tide(t)    = cosine interpolation between extrema: h0 + (h1−h0)·(1 − cos(π·p))/2
```
## 7.4 Offshore wave energy (per hour)
```
E_off [kJ] = ρ · g² · H² · T² / (16π) / 1000      ρ = 1025, g = 9.81
H = swell_wave_height (m), T = swell_wave_period (s, Open-Meteo mean period)
Hourly values linearly interpolated at hour midpoints (u = t − 0.5).
Week quartiles: 6:00–21:00 inclusive, 7 days (n = 112), numpy.percentile linear.
Fixture: Q1 126.1 · median 157.0 · Q3 197.0 kJ.
```
## 7.5 Shore energy model (Sea page) — MODEL
```
Rc  = (Z_crest − tide) × 0.3048                 freeboard, m (negative = reef submerged)
ξ   = tan α / sqrt(2π·Hs / (g·T²))              Iribarren; tan α = 1/COT_A
r   = B / Hs

d'Angremond (r ≤ 8):
  Kt_dA = clamp(−0.40·Rc/Hs + 0.64·r^−0.31·(1 − e^(−0.50ξ)), 0.075, 0.80)
Briganti / van der Meer (r ≥ 12):
  Kt_Br = clamp(−0.35·Rc/Hs + 0.51·r^−0.65·(1 − e^(−0.41ξ)), 0.05, 0.93 − 0.006·r)
8 < r < 12: w = (r − 8)/4;  Kt = (1 − w)·Kt_dA + w·Kt_Br

Gap/channel leak (tide-independent): G = Kd²   (Kd = 0.30 → 9% of energy)

E_shore(t) = E_off(t) · min(1, Kt(t)² + Kd²)
```
## 7.6 Calm threshold and calm windows
```
Pool: all hours 6:00–21:00 across the 7 days.
E_med, Hs_med, T_med = medians of the pool   (fixture 157.0 kJ, 0.82 m, 10.4 s)
Kt_3ft = Kt(Hs_med, T_med, Rc = (Z_crest − 3.0 ft)·0.3048)   (fixture 0.302)
THR    = E_med · min(1, Kt_3ft² + Kd²)       (fixture 28.5 kJ)
calm   = E_shore(t) < THR, evaluated on a 5-min grid inside daylight
         [sunrise + 15 min, sunset − 30 min]; keep runs ≥ 15 min
```
No rolling median in the locked model (the 3-h rolling median belonged to superseded E1). The chart and the calm ribbon use the same number, so they always agree.

## 7.7 Parameters
- Z_crest (reef crest elevation) = 1.0 ft, Puntarenas chart datum (~MLLW) — **GUESS**, tested 0–1.5 ft
- B (crest width) = 30 m — **GUESS**, tested 10–60 m
- COT_A (front slope cot α) = 3 — **GUESS**, tested 2–5
- Kd (gap + Isla Chora channel) = 0.30 — **GUESS** inside sourced 0.1–0.5
- Period: model mean period used as Tp (Tp ≈ 1.2× Tm, so ξ slightly understated) — assumption
- Kt formula and limits as published (rubble-mound breakwaters; applying to a rock reef is an assumption)
- Not modelled: shoaling, refraction, bay friction, set-up, wind sea
- Ceiling: at high tide Kt ≈ 0.72 (Kt² ≈ 0.52) → flat tops in the chart are the formula's ceiling, not clipping

## 7.8 Sensitivity (11 cases)
- Roughest 3 days always Fri, Sat, Sun (Fri first in 9/11); Thu always calmest.
- Base calm minutes: Wed 310 · Thu 345 · Fri 235 · Sat 230 · Sun 220 · Mon 260 · Tue 260.
- Kd matters most: Kd 0.5 → Fri/Sat/Sun 180/145/155 min (THR 53.6 kJ); Kd 0.1 → 255/245/245 (THR 15.9 kJ).
- Crest/width/slope move THR (23.0–43.5 kJ) but windows only ±10–20 min, except B = 60 m on Thu (515 min).

## 7.9 Sources
- Briganti, van der Meer, Buccino & Calabrese (2003), Coastal Structures 2003; van der Meer et al. (2005), Coastal Engineering 52:915–929, doi:10.1016/j.coastaleng.2005.09.005 (B/Hi > 12 refit, limits 0.05 / −0.006 B/Hi + 0.93, 8–12 interpolation). Cross-checked against Deltares coastal-structures toolbox `briganti2003`.
- d'Angremond, van der Meer & de Jong (1996), ICCE (B/Hs < 10 formula, limits 0.075–0.80), restated in J. Mar. Sci. Eng. 10:1986 (2022), doi:10.3390/jmse10121986.
- USACE Coastal Engineering Manual EM 1110-2-1100 Part II-7 (diffraction, Kd ≈ 0.5 on the lee line from the tip); Johnson (1951) "Generalized wave diffraction diagrams", ICCE. Lee Kd typically 0.1–0.5.
- Heat minutes: Chad's /workspace/health/samara-heat-minutes.md (TB MED 507 Table 3–2, ACSM 2023 Table 7; kids' cells extrapolated).
- Energy formula: tide-energy.md (Costa's fetcher constant).

# 8. Open questions
1. **Friday:** the old rule closed Fri; the shore model gives Fri 9:15a–1:10p (3h55). Closing it via Kd needs 0.5–0.6 (0.6 → 0 min), above the sourced range = tuning. Honest alternative: a separate offshore "big swell" flag. **Decision pending (Sean). No big-swell flag yet.**
2. Label the Kt ceiling ("max over reef ≈ half") so flat high-tide tops don't read as a rendering clip.
3. Field-measure on arrival: reef crest height and inside wave size, to replace the four guesses.
4. Shade view for Week Heat for Soccer shade / Jungle (Heat tab currently shows Beach sun zones).
5. Real Pool rule (no heat source covers time in water).

# 9. Data sources (Costa's fixture)
- Swell height/period/energy: Open-Meteo marine (cell 9.875, −85.54166); hourly, 168 h.
- Weather (T, RH, wind, radiation, pressure, cloud, precip, sunrise/sunset): Open-Meteo forecast, cell 9.876977, −85.51575, 19 m.
- Tides: [NOAA CO-OPS 9684403 Puntarenas](https://tidesandcurrents.noaa.gov/stationhome.html?id=9684403) (predictions, MLLW, lst). Replaces the costaricawaves.com scrape; terms risk is resolved. Do not use Open-Meteo sea_level_height_msl.
- Computed into `conditions.json` (server-side, each morning): WBGT, week quartiles and shore energy. The app only draws.
- Files: /workspace/family-environment/2026-11-11/ (this-week-*.csv, this-week-note.md, this-week-sources/, tide-energy.md, reef-threshold.md).
- Labelling: past model analysis vs forecast; WBGT is a grid-cell estimate, not a beach reading; flags and signs beat the app; avoid the Río Sámara mouth (east end).
