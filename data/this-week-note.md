# This week in Sámara — Wed 11 Nov through Tue 17 Nov 2026

Research / design file for Pepper. Written 2026-11-11 (America/Los_Angeles). **This is a live model-analysis + forecast snapshot, not climatology and not a 2026/27 typical.** Design only; no build, nothing to Sean.

All clock times below are **America/Costa_Rica (UTC−6)** unless labeled PT.

## Fetch time and cutoff

- **Fetched:** 2026-11-11, **3:00:01 PM PT** (America/Los_Angeles, UTC−8) / **5:00:01 PM** America/Costa_Rica.
- **Cutoff hour:** **17:00 CR on 11 Nov.** An hour is labeled *past* if its start is strictly before 17:00 today (hours 00–16 have finished). The 17:00 hour had only just begun at fetch, so **17:00 today through 23:00 on 17 Nov is forecast.**
- Counts: **17 past hours, 151 forecast hours** (168 total). 11 Nov is mixed; 12–17 Nov are all forecast.
- `data_kind` on every hourly and daily row spells this out. Past hours are Open-Meteo **best-match model analysis** (forecast/marine API elapsed hours), not a Sámara station observation.

## Deliverables

| File | What it is |
|---|---|
| `/workspace/family-environment/2026-11-11/this-week-hourly-nov11.csv` | 24 rows, hours 0–23 on **11 Nov only**. Energy, cloud, rain, WBGT inputs and Liljegren sun/shade, `data_kind`, fetch/cutoff stamps. |
| `/workspace/family-environment/2026-11-11/this-week-daily.csv` | 7 rows, 11–17 Nov. Daily 6a–9p energy median, 24h mean cloud, 24h precip sum, daily max WBGT sun/shade and the hour they occur, sunrise/sunset, week quartiles as columns. |
| `/workspace/family-environment/2026-11-11/this-week-energy-quartiles.csv` | One row: week Q1 / median / Q3 and n. |
| `/workspace/family-environment/2026-11-11/this-week-tides.csv` | 27 predicted Puntarenas hi/lo extrema on 11–17 Nov, ft and m, chart datum. |
| `/workspace/family-environment/2026-11-11/this-week-note.md` | This note. |
| `/workspace/family-environment/2026-11-11/this-week-sources/` | Raw JSON, costaricawaves HTML, script, exact URLs, all-days hourly CSV, sha256. |

Verified: 24 hourly rows, 7 daily rows, no empty/NaN cells, no silent fills. Week quartiles recomputed from `this-week-sources/hourly-all-days.csv` and match. All requested fields were sourced; nothing was left out.

Regenerate: `/workspace/.venvs/heatclock-wbgt/bin/python3 /workspace/family-environment/2026-11-11/this-week-sources/build_this_week.py` (re-fetches; numbers will move).

## Week energy quartiles (below / typical / above for *this* forecast week)

6:00–21:00 inclusive, 11–17 Nov, `numpy.percentile(..., method="linear")`, same window and method as the locked cards. Unrounded kJ in the pool; display to 1 decimal.

**Q1 = 126.1 kJ · median = 157.0 kJ · Q3 = 197.0 kJ · n = 112** (7 × 16 hours, complete).

These quartiles mix 11 Nov's remaining daylight (partly already observed in the model) with five and a half days of forecast. They will change if the model updates. They are for this coming week only, not the December fixture-week climatology (that file's median was 86 kJ, n=5 years) and not the locked October 11–17 *forecast* week (median 358 kJ).

## Headline numbers

1. **Today (Wed 11 Nov) is already on the quieter side of this week, and energy is falling.** 6a–9p median **130.7 kJ**. At 3:00pm (past, last completed afternoon hour) energy was **126.3 kJ** — almost exactly this week's Q1. Evening forecast continues down to ~111 kJ by 9:00pm. Thursday is the quietest day in the run (**87.7 kJ** daily median). Friday–Sunday jump to **203 / 197 / 191 kJ**, then Monday–Tuesday ease to 153 / 138. Friday onward is forecast and should be trusted less.
2. **Today's low tide is early and very low.** Puntarenas predicted: low **9:56 AM at 0.20 ft**, high **4:12 PM at 8.31 ft**, morning high 3:41 AM at 9.09 ft, night low 10:04 PM at 1.09 ft. Today's range **8.89 ft** is the week's largest. Later in the week the lows get less low (Tuesday morning low 2.39 ft) as the range shrinks toward ~5 ft.
3. **Heat peaks mid-morning to noon.** Today's max WBGT: **sun 31.8 °C at 10:00**, **shade 27.3 °C at 11:00** (Liljegren, Chad's pywbgt path). Using Chad's ACSM 2023 Table 7 Region 3 bins (rounded to 0.1 °C; these are effort bands, **not** safe/unsafe lines): today's sun peak is *Peak heat*, shade peak is *Hot*. Forecast daily sun maxima stay in the 30.8–32.4 °C range; Saturday 10:00 (32.4) and Monday 10:00 (32.3) sit on the Peak / Extreme edge of that table. Shade stays in the mid-to-high 26s / low 27s. Model estimates for a grid cell, not a beach reading.
4. **Today and Thursday look relatively dry and clearer; the weekend forecast adds rain and cloud.** 11–12 Nov: 0.7 mm each, mean total cloud 25% and 19%. Then 1.9, **5.2, 2.2, 4.4, 5.4 mm** (Fri–Tue). Saturday's mean total cloud is 80%. Rain after about three days is the weaker part of the forecast.
5. **Sunrise / sunset** this week: **5:35–5:37 AM / 5:16–5:17 PM**. Today: 5:35 AM and 5:17 PM (sunset falls just after the 17:00 cutoff, so that stamp is forecast).

## Sources

### Swell energy — Open-Meteo Marine

Request: https://marine-api.open-meteo.com/v1/marine?latitude=9.8826&longitude=-85.5257&hourly=swell_wave_height,swell_wave_period,swell_wave_direction,wave_height,wave_period&timezone=America%2FCosta_Rica&start_date=2026-11-11&end_date=2026-11-17&cell_selection=sea

Returned cell: **9.875, −85.54166** (same sea cell as the October cards). Units: height m, period s (mean period, not peak). The JSON does not name the wave model.

Formula, identical to `/workspace/family-wx/fetch_cr_swell.py` lines 31–35 and 75:

```
energy_kj = rho * g² * H² * T² / (16π) / 1000
rho = 1025, g = 9.81
H = swell_wave_height (m), T = swell_wave_period (s)
```

Typicals and quartiles use the unrounded value; the hourly/daily CSVs round energy to 1 decimal.

### Cloud, rain, WBGT inputs, sunrise/sunset — Open-Meteo forecast API

Request: https://api.open-meteo.com/v1/forecast?latitude=9.8826&longitude=-85.5257&hourly=temperature_2m,relative_humidity_2m,dew_point_2m,wind_speed_10m,shortwave_radiation,direct_radiation,diffuse_radiation,surface_pressure,cloud_cover_low,cloud_cover,precipitation&daily=sunrise,sunset&wind_speed_unit=ms&timezone=America%2FCosta_Rica&start_date=2026-11-11&end_date=2026-11-17

Returned cell: **9.876977, −85.51575**, elevation **19 m** (closer to Sámara than the ERA5 climatology cell at 10.0, −85.5). Wind requested in **m/s**. Radiation is the Open-Meteo hourly shortwave field (preceding-hour mean, same field Chad used). Daily `sunrise` / `sunset` are local ISO stamps.

### WBGT sun / shade — computed, Chad's Liljegren path

Code: `/workspace/visual-lab/2026-11-11/work/compute.py`, run in `/workspace/.venvs/heatclock-wbgt` with `pywbgt.liljegrenWBGT` (Argonne / Liljegren 2008). **Computed for all 168 hours.**

- Inputs: 2 m temperature, relative humidity, 10 m wind (m/s), shortwave radiation (W/m²), surface pressure (hPa). Dewpoint is computed from T and RH with MetPy, as in Chad's script (the API dewpoint is stored only in the all-days source file as a cross-check).
- Sun run: solar = shortwave, zspeed = 10 m. Shade run: solar = 0 W/m², speed = the 2 m wind from the sun run, zspeed = 2 m.
- Solar-position lat/lon in the Liljegren call: **9.88, −85.53**, same as Chad (not the ERA5 cell).
- Hourly and daily CSVs also keep the inputs (`temp_c`, `rh_pct`, `dewpoint_c`, `wind_speed_10m_ms`, `wind2m_ms`, `shortwave_wm2`, `surface_pressure_hpa`).

Open-Meteo's `wet_bulb_temperature_2m` is a psychrometric wet bulb and was **not** used.

### Tides — costaricawaves.com Puntarenas table

Request: https://www.costaricawaves.com/tides/november2026/

Parsed with the same regex as `/workspace/family-wx/fetch_cr_tides.py`. **27 extrema** on 11–17 Nov (14 Nov has three rows in this file because the following low falls at **00:06 on 15 Nov**, and is listed on that date). Station: Puntarenas, used for Sámara by tidetime.org / costaricawaves with no offset. Times CST (= America/Costa_Rica). Heights **ft**, metres derived (`ft / 3.28084`). Datum: **chart datum (~MLLW)**. These are predicted hi/lo, not observed water level, and not a Sámara gauge.

**Terms risk:** the current primary fetcher scrapes HTML. No clear licence or official-agency attribution was found on the page (see `/workspace/family-environment/2026-11-11/costa-domain-audit.md` §7). Fine for this design snapshot; not something to productize without a permitted source (IMN/SINAMOT is the longer-term candidate, after checking datum and station).

**Open-Meteo `sea_level_height_msl` was not used and must not be plotted as these extrema.** It is a model series on a mean-sea-level datum, not chart datum, and cannot share the tide-height axis.

Raw HTML: `this-week-sources/crwaves-november2026.html`.

## What was computed vs missing

| Field | Status |
|---|---|
| Swell energy kJ, height, period | Computed, all 168 hours |
| Week Q1 / median / Q3 and daily 6a–9p medians | Computed, n=112 complete |
| Low and total cloud %, hourly precip; daily mean cloud and precip sum | Present, all hours |
| WBGT sun and shade, plus inputs | Computed, all 168 hours |
| Daily max WBGT and hour | Computed, all 7 days |
| Puntarenas tide extrema | 27 rows, 11–17 Nov |
| Sunrise / sunset | Present, all 7 days |
| Nothing requested was omitted | — |

## Caveats

- **Forecast skill drops after about three days.** Thursday is still near-term; Friday–Tuesday swell, rain, and weekend cloud should be treated as a sketch and refreshed. This snapshot will go stale.
- **Offshore / grid wave model, not the Sámara reef or shorebreak.** Same limit as the October cards. No rip, flag, or “safe to swim” information is in these files. **No kJ safety thresholds exist.** The 0–800 axis is display only.
- **Our kJ usually reads lower than Surf-Forecast.** Open-Meteo’s swell period is a mean period. One 11 Oct comparison: 343 vs 566 kJ at 3pm (~40% lower). That is one day, not a calibration. Compare our days with each other, not with SF.
- **WBGT is a model estimate for a grid cell, not a beach thermometer.** Sand, water glare, a palapa, or a still courtyard can move the real value. The model's person is a standard globe and wick, not a child at play. ACSM bins, if used, are adult-athlete effort bands (grade WEAK for a family); they are not safe/unsafe lines.
- **Tide is a Puntarenas prediction** on chart datum, not a measured Sámara water level.
- Open-Meteo data are **CC BY**, free for **non-commercial** use. Credit Open-Meteo and the underlying model providers.
