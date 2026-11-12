# Calm windows: shore_model.py and the app, same inputs

Pepper asked for one table. `scripts/shore_model.py` is the original model. The app column is the calm window stored in `fixtures/conditions.fixture.json`, which the Sea ribbon and the Today tide header both draw.

The hours are `data/hourly-all-days.csv` (168 rows, 11–17 Nov, unrounded energy). `shore_model.threshold()` on that file is **28.5 kJ** (median energy 157.0 kJ, Hs 0.82 m, T 10.4 s, Kt 0.302). The fixture's calm line is **28.5 kJ**. Both the model column and the app use 28.5 kJ.

`hourly-all-days.csv` has **168 rows**, 2026-11-11T00:00 through 2026-11-17T23:00. Sunrise and sunset come from `this-week-daily.csv`. Tides are NOAA CO-OPS 9684403, the same hi/lo the fixture builder uses, within 1 minute and 0.01 ft of `this-week-tides.csv`.

## Side by side

| Day | Spec window | shore_model.py | App | Model vs spec (min) | App vs spec (min) | Model vs app (min) |
|---|---|---|---|---|---|---|
| 11-11 Wed | 7:30a–12:40p | 7:30a–12:40p | 7:30a–12:40p | 0 | 0 | 0 |
| 11-12 Thu | 7:50a–1:35p | 7:50a–1:35p | 7:50a–1:35p | 0 | 0 | 0 |
| 11-13 Fri | 9:15a–1:10p | 9:15a–1:10p | 9:15a–1:10p | 0 | 0 | 0 |
| 11-14 Sat | 9:55a–1:45p | 9:55a–1:45p | 9:55a–1:45p | 0 | 0 | 0 |
| 11-15 Sun | 10:50a–2:30p | 10:50a–2:30p | 10:50a–2:30p | 0 | 0 | 0 |
| 11-16 Mon | 11:10a–3:30p | 11:10a–3:30p | 11:10a–3:30p | 0 | 0 | 0 |
| 11-17 Tue | 12:05p–4:25p | 12:05p–4:25p | 12:05p–4:25p | 0 | 0 | 0 |

Largest gap between `shore_model.py` and the app: **0 minutes**. Every day matches the spec to the minute. The app, the original model, and the locked windows are the same on these frozen hours.

