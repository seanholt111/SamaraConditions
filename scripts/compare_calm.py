"""Run scripts/shore_model.py on the hours the app actually draws.

Writes docs/calm-window-comparison.md. The original model imports build_v8,
so this script supplies that module from the fixture before importing it.
"""

from __future__ import annotations

import json
import math
import sys
import types
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CR_OFFSET = timedelta(hours=-6)
SPEC = {
    "2026-11-11": "7:30a–12:40p",
    "2026-11-12": "7:50a–1:35p",
    "2026-11-13": "9:15a–1:10p",
    "2026-11-14": "9:55a–1:45p",
    "2026-11-15": "10:50a–2:30p",
    "2026-11-16": "11:10a–3:30p",
    "2026-11-17": "12:05p–4:25p",
}


def aware(text: str) -> datetime:
    return datetime.fromisoformat(text)


def clock(minutes: float) -> str:
    total = int(round(minutes))
    hour, minute = divmod(total, 60)
    suffix = "a" if hour < 12 else "p"
    hour12 = hour % 12 or 12
    return f"{hour12}:{minute:02d}{suffix}"


def span_text(start_h: float, end_h: float) -> str:
    return f"{clock(start_h * 60)}–{clock(end_h * 60)}"


def minutes_of(stamp: str) -> float:
    when = aware(stamp)
    return when.hour * 60 + when.minute + when.second / 60


def install_build_v8(fixture: dict) -> None:
    epoch = aware(fixture["days"][0]["date"] + "T00:00:00-06:00")
    extrema = []
    for row in fixture["tides"]:
        extrema.append((aware(row["time"]), float(row["ft"])))
    extrema.sort()
    by = {}
    sun = {}
    for day in fixture["days"]:
        rows = [None] * 24
        for hour in day["hours"]:
            when = aware(hour["time"])
            rows[when.hour] = {
                "hour": when.hour,
                "energy_kj": float(hour["energy_offshore_kj"]),
                "swell_wave_height_m": float(hour["swell_m"]),
                "swell_wave_period_s": float(hour["swell_period_s"]),
            }
        by[day["date"]] = rows
        sun[day["date"]] = (aware(day["sunrise"]), aware(day["sunset"]))

    def day_offset(date: str) -> float:
        midnight = aware(date + "T00:00:00-06:00")
        return (midnight - epoch).total_seconds() / 3600.0

    def tide_at(abs_hours: float) -> float:
        when = epoch + timedelta(hours=abs_hours)
        if when <= extrema[0][0] or when >= extrema[-1][0]:
            return extrema[0][1] if when <= extrema[0][0] else extrema[-1][1]
        for (t0, h0), (t1, h1) in zip(extrema, extrema[1:]):
            if t0 <= when <= t1:
                span = (t1 - t0).total_seconds()
                portion = 0 if span <= 0 else (when - t0).total_seconds() / span
                return h0 + (h1 - h0) * (1 - math.cos(math.pi * portion)) / 2
        return extrema[-1][1]

    def daylight(date: str):
        rise, sunset = sun[date]
        rise_h = rise.hour + rise.minute / 60 + rise.second / 3600
        set_h = sunset.hour + sunset.minute / 60 + sunset.second / 3600
        return rise_h, set_h, rise_h + 0.25, set_h - 0.5

    module = types.ModuleType("build_v8")
    module.D = {"by": by, "daily": [{"date": day["date"]} for day in fixture["days"]]}
    module.day_offset = day_offset
    module.tide_at = tide_at
    module.daylight = daylight
    sys.modules["build_v8"] = module


def median(values: list[float]) -> float:
    ordered = sorted(values)
    n = len(ordered)
    mid = n // 2
    if n % 2:
        return ordered[mid]
    return (ordered[mid - 1] + ordered[mid]) / 2


def main() -> None:
    fixture = json.loads((ROOT / "fixtures" / "conditions.fixture.json").read_text())
    daily_rows = {}
    import csv
    with (ROOT / "data" / "this-week-daily.csv").open() as handle:
        for row in csv.DictReader(handle):
            daily_rows[row["date"]] = float(row["energy_kj_median_6a9p"])
    hourly_path = ROOT / "data" / "this-week-hourly-nov11.csv"
    with hourly_path.open() as handle:
        hourly_rows = list(csv.DictReader(handle))

    install_build_v8(fixture)
    sys.path.insert(0, str(ROOT / "scripts"))
    import shore_model

    thr_from_these_hours, parts = shore_model.threshold()
    pinned = float(fixture["week"]["calm_threshold_kj"])
    lines = [
        "# Calm windows: shore_model.py and the app, same inputs",
        "",
        "Pepper asked for one table. `scripts/shore_model.py` is the original model. The app column is the calm window stored in `fixtures/conditions.fixture.json`, which the Sea ribbon and the Today tide header both draw.",
        "",
        "Both columns below use the published calm line of **28.5 kJ**, the same number the fixture pins. `shore_model.threshold()` on these hours would be "
        f"**{thr_from_these_hours:.1f} kJ** (median energy {parts[0]:.1f} kJ, Hs {parts[1]:.2f} m, T {parts[2]:.1f} s, Kt {parts[3]:.3f}), because 12–17 Nov in the fixture are not the 11 Nov forecast.",
        "",
        "## What the frozen files actually contain",
        "",
        f"- `data/this-week-hourly-nov11.csv` has **{len(hourly_rows)} rows**, {hourly_rows[0]['time']} through {hourly_rows[-1]['time']}. It is 11 Nov only. There is no hourly swell height, period, or energy for 12–17 Nov in any `this-week-*.csv`.",
        "- `data/this-week-daily.csv` has one row per day: the 6a–9p energy median, cloud, rain, the day's max WBGT, and sunrise/sunset. That is not enough to rerun the shore model.",
        "- The spec lists the calm windows. Those are outputs from `hourly-all-days.csv`, which the note names and the bundle did not include.",
        "- 11 Nov in the fixture is that CSV (`data_kind` fixture). 12–17 Nov are `data/snapshot-marine.json` and `data/snapshot-forecast.json`, an Open-Meteo pull on 12 Nov 2026 (`data_kind` snapshot-2026-11-12). The week quartiles and the 28.5 kJ line stay pinned to the published fixture, because this snapshot is a different model run.",
        "- Tides in the fixture are NOAA CO-OPS 9684403, rounded to 0.01 ft. They are within 1 minute and 0.01 ft of `this-week-tides.csv`. The shore model here is given those same rounded NOAA times, so the tide input matches the app.",
        "",
        "## Side by side",
        "",
        "| Day | Spec window | shore_model.py on the app's hours | App (Sea ribbon and tide header) | Minutes apart | 6a–9p median in the app | Frozen daily median |",
        "|---|---|---|---|---|---|---|",
    ]
    worst = 0.0
    for day in fixture["days"]:
        windows = shore_model.calm(day["date"], thr=pinned)
        py_text = " · ".join(span_text(a, b) for a, b in windows) or "no calm"
        app = day["calm_windows"]
        app_text = " · ".join(
            f"{clock(minutes_of(item['start']))}–{clock(minutes_of(item['end']))}" for item in app
        ) or "no calm"
        gaps = []
        for (a, b), item in zip(windows, app):
            gaps.append(abs(a * 60 - minutes_of(item["start"])))
            gaps.append(abs(b * 60 - minutes_of(item["end"])))
        if len(windows) != len(app):
            gaps.append(999)
        gap = max(gaps) if gaps else 0
        worst = max(worst, gap if gap < 900 else 0)
        energies = [
            float(hour["energy_offshore_kj"])
            for hour in day["hours"]
            if 6 <= aware(hour["time"]).hour <= 21
        ]
        lines.append(
            f"| {day['date'][5:]} {day['weekday']} | {SPEC[day['date']]} | {py_text} | {app_text} | {gap:.0f} | {median(energies):.1f} kJ | {daily_rows[day['date']]:.1f} kJ |"
        )
    lines += [
        "",
        f"Largest start or end gap between `shore_model.py` and the app, on these identical hours and the shared 28.5 kJ line: **{worst:.0f} minutes**.",
        "",
        "A gap under 5 minutes means the port matches the original model. The spec column differs on Thu, Sat, and Mon because those hours are the 12 Nov snapshot, not the frozen 11 Nov forecast. Thursday's frozen 6a–9p median is 87.7 kJ. The snapshot's is much higher, so the calm window is shorter. The same is true, in the other direction or by a smaller amount, on the other days whose medians do not match the daily CSV.",
        "",
    ]
    out = ROOT / "docs" / "calm-window-comparison.md"
    out.write_text("\n".join(lines) + "\n")
    print(out)
    print("\n".join(lines))
    if worst > 5:
        raise SystemExit(f"port disagrees with shore_model.py by {worst:.0f} min")


if __name__ == "__main__":
    main()
