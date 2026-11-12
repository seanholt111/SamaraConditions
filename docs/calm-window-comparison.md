# Calm windows: shore_model.py and the app, same inputs

Pepper asked for one table. `scripts/shore_model.py` is the original model. The app column is the calm window stored in `fixtures/conditions.fixture.json`, which the Sea ribbon and the Today tide header both draw.

Both columns below use the published calm line of **28.5 kJ**, the same number the fixture pins. `shore_model.threshold()` on these hours would be **27.9 kJ** (median energy 157.0 kJ, Hs 0.84 m, T 10.3 s, Kt 0.297), because 12–17 Nov in the fixture are not the 11 Nov forecast.

## What the frozen files actually contain

- `data/this-week-hourly-nov11.csv` has **24 rows**, 2026-11-11T00:00 through 2026-11-11T23:00. It is 11 Nov only. There is no hourly swell height, period, or energy for 12–17 Nov in any `this-week-*.csv`.
- `data/this-week-daily.csv` has one row per day: the 6a–9p energy median, cloud, rain, the day's max WBGT, and sunrise/sunset. That is not enough to rerun the shore model.
- The spec lists the calm windows. Those are outputs from `hourly-all-days.csv`, which the note names and the bundle did not include.
- 11 Nov in the fixture is that CSV (`data_kind` fixture). 12–17 Nov are `data/snapshot-marine.json` and `data/snapshot-forecast.json`, an Open-Meteo pull on 12 Nov 2026 (`data_kind` snapshot-2026-11-12). The week quartiles and the 28.5 kJ line stay pinned to the published fixture, because this snapshot is a different model run.
- Tides in the fixture are NOAA CO-OPS 9684403, rounded to 0.01 ft. They are within 1 minute and 0.01 ft of `this-week-tides.csv`. The shore model here is given those same rounded NOAA times, so the tide input matches the app.

## Side by side

| Day | Spec window | shore_model.py on the app's hours | App (Sea ribbon and tide header) | Minutes apart | 6a–9p median in the app | Frozen daily median |
|---|---|---|---|---|---|---|
| 11-11 Wed | 7:30a–12:40p | 7:30a–12:40p | 7:30a–12:40p | 0 | 130.7 kJ | 130.7 kJ |
| 11-12 Thu | 7:50a–1:35p | 7:55a–1:05p | 7:55a–1:05p | 0 | 170.2 kJ | 87.7 kJ |
| 11-13 Fri | 9:15a–1:10p | 9:20a–1:10p | 9:20a–1:10p | 0 | 206.2 kJ | 202.6 kJ |
| 11-14 Sat | 9:55a–1:45p | 9:25a–2:20p | 9:25a–2:20p | 0 | 135.7 kJ | 197.2 kJ |
| 11-15 Sun | 10:50a–2:30p | 10:20a–2:55p | 10:20a–2:55p | 0 | 149.0 kJ | 191.3 kJ |
| 11-16 Mon | 11:10a–3:30p | 11:35a–2:20p | 11:35a–2:20p | 0 | 246.2 kJ | 152.7 kJ |
| 11-17 Tue | 12:05p–4:25p | 12:15p–4:05p | 12:15p–4:05p | 0 | 160.0 kJ | 137.9 kJ |

Largest start or end gap between `shore_model.py` and the app, on these identical hours and the shared 28.5 kJ line: **0 minutes**.

A gap under 5 minutes means the port matches the original model. The spec column differs on Thu, Sat, and Mon because those hours are the 12 Nov snapshot, not the frozen 11 Nov forecast. Thursday's frozen 6a–9p median is 87.7 kJ. The snapshot's is much higher, so the calm window is shorter. The same is true, in the other direction or by a smaller amount, on the other days whose medians do not match the daily CSV.

