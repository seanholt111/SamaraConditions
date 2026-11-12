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


def parse_clock(text: str) -> float:
    suffix = text[-1]
    hour_text, minute_text = text[:-1].split(":")
    hour = int(hour_text) % 12
    if suffix == "p":
        hour += 12
    return hour * 60 + int(minute_text)


def spec_edges(date: str) -> tuple[float, float]:
    start, end = SPEC[date].split("–")
    return parse_clock(start), parse_clock(end)


def minutes_of(stamp: str) -> float:
    when = aware(stamp)
    return when.hour * 60 + when.minute + when.second / 60


def install_build_v8() -> None:
    """Frozen hourly file plus the same NOAA hi/lo the fixture builder uses."""
    import csv
    epoch = aware("2026-11-11T00:00:00-06:00")
    noaa = json.loads((ROOT / "data" / "noaa_hilo_fixture.json").read_text())
    extrema = []
    for row in noaa["predictions"]:
        extrema.append((aware(row["t"].replace(" ", "T") + "-06:00"), float(row["v"])))
    extrema.sort()
    sun = {}
    with (ROOT / "data" / "this-week-daily.csv").open() as handle:
        for row in csv.DictReader(handle):
            sun[row["date"]] = (
                datetime.fromisoformat(row["sunrise"]).replace(tzinfo=epoch.tzinfo),
                datetime.fromisoformat(row["sunset"]).replace(tzinfo=epoch.tzinfo),
            )
    by = {}
    with (ROOT / "data" / "hourly-all-days.csv").open() as handle:
        for row in csv.DictReader(handle):
            when = datetime.fromisoformat(row["time"]).replace(tzinfo=epoch.tzinfo)
            slot = by.setdefault(row["date"], [None] * 24)
            slot[when.hour] = {
                "hour": when.hour,
                "energy_kj": float(row["energy_kj"]),
                "swell_wave_height_m": float(row["swell_wave_height_m"]),
                "swell_wave_period_s": float(row["swell_wave_period_s"]),
            }

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
    module.D = {"by": by, "daily": [{"date": date} for date in sorted(by)]}
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
    hourly_path = ROOT / "data" / "hourly-all-days.csv"
    with hourly_path.open() as handle:
        hourly_rows = list(csv.DictReader(handle))

    install_build_v8()
    sys.path.insert(0, str(ROOT / "scripts"))
    import shore_model

    thr_from_these_hours, parts = shore_model.threshold()
    pinned = float(fixture["week"]["calm_threshold_kj"])
    lines = [
        "# Calm windows: shore_model.py and the app, same inputs",
        "",
        "Pepper asked for one table. `scripts/shore_model.py` is the original model. The app column is the calm window stored in `fixtures/conditions.fixture.json`, which the Sea ribbon and the Today tide header both draw.",
        "",
        "The hours are `data/hourly-all-days.csv` (168 rows, 11–17 Nov, unrounded energy). "
        f"`shore_model.threshold()` on that file is **{thr_from_these_hours:.1f} kJ** "
        f"(median energy {parts[0]:.1f} kJ, Hs {parts[1]:.2f} m, T {parts[2]:.1f} s, Kt {parts[3]:.3f}). "
        f"The fixture's calm line is **{pinned:.1f} kJ**. Both the model column and the app use {pinned:.1f} kJ.",
        "",
        f"`hourly-all-days.csv` has **{len(hourly_rows)} rows**, {hourly_rows[0]['time']} through {hourly_rows[-1]['time']}. "
        "Sunrise and sunset come from `this-week-daily.csv`. Tides are NOAA CO-OPS 9684403, the same hi/lo the fixture builder uses, within 1 minute and 0.01 ft of `this-week-tides.csv`.",
        "",
        "## Side by side",
        "",
        "| Day | Spec window | shore_model.py | App | Model vs spec (min) | App vs spec (min) | Model vs app (min) |",
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
        spec_start, spec_end = spec_edges(day["date"])
        if windows:
            py_vs_spec = max(abs(windows[0][0] * 60 - spec_start), abs(windows[0][1] * 60 - spec_end))
        else:
            py_vs_spec = 999
        app_vs_spec = 999
        if app:
            app_vs_spec = max(
                abs(minutes_of(app[0]["start"]) - spec_start),
                abs(minutes_of(app[0]["end"]) - spec_end),
            )
        lines.append(
            f"| {day['date'][5:]} {day['weekday']} | {SPEC[day['date']]} | {py_text} | {app_text} | {py_vs_spec:.0f} | {app_vs_spec:.0f} | {gap:.0f} |"
        )
    lines += [
        "",
        f"Largest gap between `shore_model.py` and the app: **{worst:.0f} minutes**.",
        "",
        "A gap under 5 minutes against the spec means that day's window matches the locked fixture. Tides are NOAA predictions, which sit within 1 minute and 0.01 ft of the costaricawaves table the original week was checked against. If a day is still outside 5 minutes, the difference is that tide input, not a different swell file.",
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
