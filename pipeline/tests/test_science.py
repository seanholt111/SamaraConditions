"""The locked numbers, recomputed from the frozen files."""

from __future__ import annotations

import csv
import json
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

from samara.build import PINNED_WEEK, ROOT, build_day, hours_from_csv, median, quartiles
from samara.energy import energy_kj
from samara.shore import calm_threshold
from samara.tides import Extremum, reef_shelters
from samara.wbgt import sun_and_shade
from samara.windows import calm_windows

CR = ZoneInfo("America/Costa_Rica")
DATA = ROOT / "data"


def _dt(text: str) -> datetime:
    return datetime.fromisoformat(text).replace(tzinfo=CR)


def _extrema() -> list[Extremum]:
    payload = json.loads((DATA / "noaa_hilo_fixture.json").read_text())
    out = []
    for row in payload["predictions"]:
        out.append(Extremum(_dt(row["t"].replace(" ", "T")), float(row["v"]), row["type"]))
    return out


def _csv_rows():
    return list(csv.DictReader((DATA / "this-week-hourly-nov11.csv").open()))


def _nov11_hours():
    return hours_from_csv(
        DATA / "this-week-hourly-nov11.csv",
        _dt("2026-11-11T05:35:00"),
        _dt("2026-11-11T17:17:00"),
    )


def test_published_quartiles_are_the_locked_fixture():
    rows = list(csv.DictReader((DATA / "this-week-energy-quartiles.csv").open()))
    row = rows[0]
    assert float(row["q1_kJ"]) == 126.1
    assert float(row["median_kJ"]) == 157.0
    assert float(row["q3_kJ"]) == 197.0
    assert int(row["n"]) == 112


def test_threshold_from_published_medians_is_28_5():
    thr, kt = calm_threshold(157.0, 0.82, 10.4)
    assert round(thr, 1) == 28.5
    assert abs(kt - 0.302) < 0.002


def test_energy_formula_matches_nov11_csv():
    worst = 0.0
    for row in _csv_rows():
        got = energy_kj(float(row["swell_wave_height_m"]), float(row["swell_wave_period_s"]))
        worst = max(worst, abs(got - float(row["swell_energy_kJ"])))
    assert worst < 0.06


def test_liljegren_matches_nov11_csv_within_a_tenth():
    worst = 0.0
    for row in _csv_rows():
        when = _dt(row["time"])
        sun, shade, _ = sun_and_shade(
            when.year, when.month, when.day, when.hour,
            float(row["shortwave_wm2"]), float(row["surface_pressure_hpa"]),
            float(row["temp_c"]), float(row["rh_pct"]), float(row["wind_speed_10m_ms"]),
        )
        worst = max(worst, abs(sun - float(row["wbgt_sun_c"])), abs(shade - float(row["wbgt_shade_c"])))
    assert worst < 0.1


def test_noaa_extrema_match_the_tide_csv():
    csv_rows = list(csv.DictReader((DATA / "this-week-tides.csv").open()))
    noaa = _extrema()
    assert len(csv_rows) == len(noaa) == 27
    for row, ext in zip(csv_rows, noaa):
        csv_time = _dt(row["time"])
        assert abs((ext.time - csv_time).total_seconds()) <= 60
        assert abs(ext.feet - float(row["ft"])) <= 0.01
        assert ext.kind[0] == row["type"][0]


def test_wednesday_windows_and_reef():
    hours = _nov11_hours()
    sun = [(h["time"], h["wbgt_sun_c"]) for h in hours]
    shade = [(h["time"], h["wbgt_shade_c"]) for h in hours]
    sunrise, sunset = hours[0]["sunrise"], hours[0]["sunset"]
    shelters = reef_shelters(_extrema(), sunrise, sunset)
    assert shelters, "expected a daytime reef span"
    start, end = shelters[0]
    assert abs((start - _dt("2026-11-11T07:34:00")).total_seconds()) <= 60
    assert abs((end - _dt("2026-11-11T12:26:00")).total_seconds()) <= 60


def test_wednesday_calm_window_is_7_30_to_12_40():
    hours = _nov11_hours()
    day = build_day(hours, _extrema(), PINNED_WEEK["energy_q1_kj"], PINNED_WEEK["energy_q3_kj"], PINNED_WEEK["calm_threshold_kj"])
    windows = day["calm_windows"]
    assert windows, "expected a calm window"
    start = datetime.fromisoformat(windows[0]["start"])
    end = datetime.fromisoformat(windows[0]["end"])
    assert abs((start - _dt("2026-11-11T07:30:00")).total_seconds()) <= 5 * 60
    assert abs((end - _dt("2026-11-11T12:40:00")).total_seconds()) <= 5 * 60
    last_sea = datetime.fromisoformat(day["sea"][-1]["time"])
    assert last_sea.hour == 21 and last_sea.minute == 0
    assert day["wave_word"] == "normal"
    assert day["cloud_daylight_mean_pct"] == 33
    assert day["precip_mm"] == 0.7
    assert day["precip_off_axis_mm"] == 0.6
    assert "windows" not in day


def test_quartile_method_on_the_nov11_daylight_pool():
    values = [
        float(row["swell_energy_kJ"])
        for row in _csv_rows()
        if 6 <= int(row["hour"]) <= 21
    ]
    assert len(values) == 16
    q1, med, q3 = quartiles(values)
    assert med == round(median(values), 1)
    assert q1 <= med <= q3
