"""Assemble conditions.json. The phone only draws."""

from __future__ import annotations

import csv
import json
import math
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import jsonschema
import numpy as np

from samara.energy import energy_kj
from samara.shore import calm_threshold, energy_shore
from samara.tides import Extremum, height_at, reef_shelters
from samara.wbgt import sun_and_shade
from samara.windows import calm_windows, heat_windows, intersect, lean_spans, pool_window

CR = ZoneInfo("America/Costa_Rica")
ROOT = Path(__file__).resolve().parents[3]
SCHEMA_PATH = Path(__file__).resolve().parents[2] / "schema" / "conditions.schema.json"

PINNED_WEEK = {
    "energy_q1_kj": 126.1,
    "energy_median_kj": 157.0,
    "energy_q3_kj": 197.0,
    "energy_n": 112,
    "calm_threshold_kj": 28.5,
    "hs_median_m": 0.82,
    "period_median_s": 10.4,
    "kt_at_3ft": 0.302,
}

WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def aware(dt: datetime) -> datetime:
    if dt.tzinfo is None:
        return dt.replace(tzinfo=CR)
    return dt.astimezone(CR)


def stamp(dt: datetime) -> str:
    return aware(dt).isoformat(timespec="seconds")


def parse_stamp(value: str) -> datetime:
    return aware(datetime.fromisoformat(value))


def day_start(dt: datetime) -> datetime:
    local = aware(dt)
    return local.replace(hour=0, minute=0, second=0, microsecond=0)


def load_schema() -> dict:
    return json.loads(SCHEMA_PATH.read_text())


def validate(document: dict) -> list[str]:
    errors: list[str] = []
    try:
        jsonschema.validate(document, load_schema())
    except jsonschema.ValidationError as exc:
        errors.append(exc.message)
        return errors
    if len(document["days"]) != 7:
        errors.append(f"expected 7 days, got {len(document['days'])}")
    for day in document["days"]:
        if len(day["hours"]) != 24:
            errors.append(f"{day['date']} has {len(day['hours'])} hours")
        for hour in day["hours"]:
            if not (10 <= hour["wbgt_sun_c"] <= 45 and 10 <= hour["wbgt_shade_c"] <= 45):
                errors.append(f"wbgt out of range at {hour['time']}")
            shore = hour["energy_shore_kj"]
            if hour["energy_offshore_kj"] < 0 or (shore is not None and shore < 0):
                errors.append(f"negative energy at {hour['time']}")
            if not (0 <= hour["cloud_pct"] <= 100):
                errors.append(f"cloud out of range at {hour['time']}")
        if not day["tide_extrema"]:
            errors.append(f"{day['date']} has no tide extrema")
    return errors


def quartiles(values: list[float]) -> tuple[float, float, float]:
    q1, med, q3 = np.percentile(np.asarray(values, dtype=float), [25, 50, 75], method="linear")
    return round(float(q1), 1), round(float(med), 1), round(float(q3), 1)


def median(values: list[float]) -> float:
    return float(np.percentile(np.asarray(values, dtype=float), 50, method="linear"))


def wave_word(day_median: float, q1: float, q3: float) -> str:
    if day_median < q1:
        return "calm"
    if day_median <= q3:
        return "normal"
    return "big"


def _lerp(by_hour: dict[int, dict], t_hours: float, key: str) -> float:
    """Hourly series interpolated at the midpoint, matching shore_model.lerp_off."""
    u = t_hours - 0.5
    h0 = max(0, min(23, int(math.floor(u))))
    h1 = min(23, h0 + 1)
    frac = max(0.0, min(1.0, u - h0))
    return (1 - frac) * float(by_hour[h0][key]) + frac * float(by_hour[h1][key])


def _iso_pair(spans: list[tuple[datetime, datetime]]) -> list[dict]:
    return [{"start": stamp(a), "end": stamp(b)} for a, b in spans]


def build_day(
    hours: list[dict],
    extrema: list[Extremum],
    q1: float,
    q3: float,
    threshold: float,
) -> dict:
    hours = sorted(hours, key=lambda h: h["time"])
    sunrise = hours[0]["sunrise"]
    sunset = hours[0]["sunset"]
    by_hour = {h["time"].hour: h for h in hours}
    day = day_start(hours[0]["time"])

    def at_hour_float(t_hours: float) -> datetime:
        return day + timedelta(hours=t_hours)

    samples: list[tuple[datetime, float, float]] = []
    # Chart series and the calm grid share the model. Calm uses the daylight 5-min grid.
    lo = sunrise + timedelta(minutes=15)
    hi = sunset - timedelta(minutes=30)
    m0 = math.ceil(_hours_since(day, lo) * 12 - 1e-9)
    m1 = math.floor(_hours_since(day, hi) * 12 + 1e-9)
    calm_samples: list[tuple[datetime, float]] = []
    for m in range(m0, m1 + 1):
        t_hours = m / 12
        when = at_hour_float(t_hours + 1e-6 / 3600)
        e_off = _lerp(by_hour, t_hours + 1e-6, "energy_offshore_kj")
        hs = _lerp(by_hour, t_hours + 1e-6, "swell_m")
        period = _lerp(by_hour, t_hours + 1e-6, "swell_period_s")
        tide = height_at(at_hour_float(t_hours), extrema)
        if tide is None:
            continue
        e_sh = energy_shore(e_off, hs, period, tide)
        calm_samples.append((at_hour_float(t_hours), e_sh))

    sea: list[dict] = []
    for minute in range(6 * 60, 17 * 60 + 1, 5):
        t_hours = minute / 60
        when = at_hour_float(t_hours)
        e_off = _lerp(by_hour, t_hours, "energy_offshore_kj")
        hs = _lerp(by_hour, t_hours, "swell_m")
        period = _lerp(by_hour, t_hours, "swell_period_s")
        tide = height_at(when, extrema)
        if tide is None:
            continue
        sea.append({
            "time": stamp(when),
            "energy_offshore_kj": round(e_off, 2),
            "energy_shore_kj": round(energy_shore(e_off, hs, period, tide), 2),
        })
        samples.append((when, e_off, energy_shore(e_off, hs, period, tide)))

    sun_pts = [(h["time"], h["wbgt_sun_c"]) for h in hours]
    shade_pts = [(h["time"], h["wbgt_shade_c"]) for h in hours]
    beach = heat_windows(sun_pts, 27.9, sunrise, sunset)
    soccer_sun = heat_windows(sun_pts, 25.7, sunrise, sunset)
    soccer_shade = heat_windows(shade_pts, 27.9, sunrise, sunset)
    jungle = heat_windows(shade_pts, 27.9, sunrise, sunset)
    pool = pool_window(sunrise, sunset)
    energy_pts = [(h["time"], h["energy_offshore_kj"]) for h in hours]
    lows = [e.time for e in extrema if e.kind == "L"]
    lean = lean_spans(lows, energy_pts, q3, sunrise, sunset)
    beach_low = intersect(beach, lean, day)

    daylight_hours = [
        h for h in hours
        if _midpoint_in(h["time"], sunrise, sunset)
    ]
    axis_hours = [h for h in hours if 6 <= h["time"].hour < 17]
    precip_total = sum(h["precip_mm"] for h in hours)
    precip_off = precip_total - sum(h["precip_mm"] for h in axis_hours)
    cloud_mean = (
        sum(h["cloud_pct"] for h in daylight_hours) / len(daylight_hours)
        if daylight_hours else 0
    )
    daylight_energy = [h["energy_offshore_kj"] for h in hours if 6 <= h["time"].hour <= 21]
    shelters = reef_shelters(extrema, sunrise, sunset)
    out_hours = []
    for h in hours:
        tide = height_at(h["time"], extrema)
        e_sh = None
        if tide is not None:
            e_sh = energy_shore(h["energy_offshore_kj"], h["swell_m"], h["swell_period_s"], tide)
        out_hours.append({
            "time": stamp(h["time"]),
            "temp_c": round(h["temp_c"], 1),
            "rh_pct": round(h["rh_pct"], 0),
            "wind_ms": round(h["wind_ms"], 2),
            "shortwave_wm2": round(h["shortwave_wm2"], 1),
            "pressure_hpa": round(h["pressure_hpa"], 1),
            "cloud_pct": round(h["cloud_pct"], 0),
            "precip_mm": round(h["precip_mm"], 2),
            "uv": None if h.get("uv") is None else round(h["uv"], 2),
            "wbgt_sun_c": round(h["wbgt_sun_c"], 2),
            "wbgt_shade_c": round(h["wbgt_shade_c"], 2),
            "swell_m": round(h["swell_m"], 3),
            "swell_period_s": round(h["swell_period_s"], 2),
            "energy_offshore_kj": round(h["energy_offshore_kj"], 1),
            "energy_shore_kj": None if e_sh is None else round(e_sh, 2),
        })
    return {
        "date": day.date().isoformat(),
        "weekday": WEEKDAYS[day.weekday()],
        "sunrise": stamp(sunrise),
        "sunset": stamp(sunset),
        "data_kind": hours[0].get("data_kind", "forecast"),
        "precip_mm": round(precip_total, 1),
        "precip_off_axis_mm": round(precip_off, 1),
        "cloud_daylight_mean_pct": round(cloud_mean),
        "energy_median_kj": round(median(daylight_energy), 1) if daylight_energy else None,
        "wave_word": wave_word(median(daylight_energy), q1, q3) if daylight_energy else "normal",
        "reef_shelters": _iso_pair(shelters),
        "tide_extrema": [
            {"time": stamp(e.time), "type": "high" if e.kind == "H" else "low", "ft": round(e.feet, 2)}
            for e in sorted(extrema, key=lambda e: e.time)
            if day_start(e.time) == day or (e.time >= day - timedelta(hours=6) and e.time < day + timedelta(days=1, hours=6))
        ],
        "windows": {
            "beach": _iso_pair(beach),
            "soccer_sun": _iso_pair(soccer_sun),
            "soccer_shade": _iso_pair(soccer_shade),
            "pool": _iso_pair(pool),
            "jungle": _iso_pair(jungle),
            "beach_low": _iso_pair(beach_low),
        },
        "calm_windows": _iso_pair(calm_windows(calm_samples, threshold, sunrise, sunset)),
        "sea": sea,
        "hours": out_hours,
    }


def _hours_since(day: datetime, when: datetime) -> float:
    return (when - day).total_seconds() / 3600.0


def _midpoint_in(hour_start: datetime, sunrise: datetime, sunset: datetime) -> bool:
    mid = hour_start + timedelta(minutes=30)
    return sunrise <= mid < sunset


def assemble(
    days: list[list[dict]],
    all_extrema: list[Extremum],
    alerts: list[dict],
    feeds: dict,
    generated_at: datetime,
    pinned_week: dict | None = None,
) -> dict:
    pool_e: list[float] = []
    pool_h: list[float] = []
    pool_t: list[float] = []
    for hours in days:
        for h in hours:
            if 6 <= h["time"].hour <= 21:
                pool_e.append(h["energy_offshore_kj"])
                pool_h.append(h["swell_m"])
                pool_t.append(h["swell_period_s"])
    if pinned_week is None:
        q1, med, q3 = quartiles(pool_e)
        hs_med = round(median(pool_h), 2)
        t_med = round(median(pool_t), 1)
        thr, kt = calm_threshold(med, hs_med, t_med)
        week = {
            "energy_q1_kj": q1,
            "energy_median_kj": med,
            "energy_q3_kj": q3,
            "energy_n": len(pool_e),
            "calm_threshold_kj": round(thr, 1),
            "hs_median_m": hs_med,
            "period_median_s": t_med,
            "kt_at_3ft": round(kt, 3),
        }
    else:
        week = dict(pinned_week)
    built = []
    for hours in days:
        day = day_start(hours[0]["time"])
        nearby = [e for e in all_extrema if day - timedelta(days=1) <= e.time <= day + timedelta(days=2)]
        built.append(build_day(hours, nearby, week["energy_q1_kj"], week["energy_q3_kj"], week["calm_threshold_kj"]))
    # Tide block on each day: the day's own extrema, not the neighbours used for interpolation.
    for day_doc, hours in zip(built, days):
        day = day_start(hours[0]["time"])
        own = [e for e in all_extrema if day_start(e.time) == day]
        day_doc["tide_extrema"] = [
            {"time": stamp(e.time), "type": "high" if e.kind == "H" else "low", "ft": round(e.feet, 2)}
            for e in own
        ]
        # Reef text needs the neighbours. Recompute shelters with nearby extrema.
        nearby = [e for e in all_extrema if day - timedelta(days=1) <= e.time <= day + timedelta(days=2)]
        sunrise = parse_stamp(day_doc["sunrise"])
        sunset = parse_stamp(day_doc["sunset"])
        day_doc["reef_shelters"] = _iso_pair(reef_shelters(nearby, sunrise, sunset))
    return {
        "schema_version": 1,
        "generated_at": stamp(generated_at),
        "timezone": "America/Costa_Rica",
        "location": {
            "name": "Sámara",
            "region": "Guanacaste",
            "forecast_lat": 9.876977,
            "forecast_lon": -85.51575,
            "marine_lat": 9.875,
            "marine_lon": -85.54166,
        },
        "feeds": feeds,
        "week": {
            "start": built[0]["date"],
            "end": built[-1]["date"],
            **week,
        },
        "alerts": alerts,
        "tides": [
            {"time": stamp(e.time), "type": "high" if e.kind == "H" else "low", "ft": round(e.feet, 2)}
            for e in sorted(all_extrema, key=lambda e: e.time)
        ],
        "days": built,
    }


def extrema_from_noaa(rows: list[dict]) -> list[Extremum]:
    out = []
    for row in rows:
        kind = row.get("type") or row.get("kind")
        if kind in ("high", "low"):
            kind = "H" if kind == "high" else "L"
        when = datetime.strptime(row["t"], "%Y-%m-%d %H:%M").replace(tzinfo=CR)
        out.append(Extremum(when, float(row.get("ft", row.get("v"))), kind))
    return out


def load_bundled_tides(path: Path) -> list[Extremum]:
    payload = json.loads(path.read_text())
    return extrema_from_noaa(payload["hilo"])


def hours_from_open_meteo(forecast: dict, marine: dict, data_kind: str) -> dict[str, list[dict]]:
    fh = forecast["hourly"]
    mh = marine["hourly"]
    marine_by_time = {
        t: (mh["swell_wave_height"][i], mh["swell_wave_period"][i])
        for i, t in enumerate(mh["time"])
    }
    sun = {d: s for d, s in zip(forecast["daily"]["time"], forecast["daily"]["sunrise"])}
    moon = {d: s for d, s in zip(forecast["daily"]["time"], forecast["daily"]["sunset"])}
    by_day: dict[str, list[dict]] = {}
    for i, raw in enumerate(fh["time"]):
        when = datetime.fromisoformat(raw).replace(tzinfo=CR)
        date = when.date().isoformat()
        swell = marine_by_time.get(raw)
        if swell is None or swell[0] is None or swell[1] is None:
            continue
        hs, period = float(swell[0]), float(swell[1])
        solar = fh["shortwave_radiation"][i] or 0.0
        temp = fh["temperature_2m"][i]
        rh = fh["relative_humidity_2m"][i]
        wind = fh["wind_speed_10m"][i]
        pres = fh["surface_pressure"][i]
        if None in (temp, rh, wind, pres):
            continue
        wb_sun, wb_shade, _ = sun_and_shade(when.year, when.month, when.day, when.hour, solar, pres, temp, rh, wind)
        energy = energy_kj(hs, period)
        by_day.setdefault(date, []).append({
            "time": when,
            "sunrise": datetime.fromisoformat(sun[date]).replace(tzinfo=CR),
            "sunset": datetime.fromisoformat(moon[date]).replace(tzinfo=CR),
            "temp_c": float(temp),
            "rh_pct": float(rh),
            "wind_ms": float(wind),
            "shortwave_wm2": float(solar),
            "pressure_hpa": float(pres),
            "cloud_pct": float(fh["cloud_cover"][i] or 0),
            "precip_mm": float(fh["precipitation"][i] or 0),
            "uv": None if fh["uv_index"][i] is None else float(fh["uv_index"][i]),
            "swell_m": hs,
            "swell_period_s": period,
            "energy_offshore_kj": float(energy),
            "wbgt_sun_c": wb_sun,
            "wbgt_shade_c": wb_shade,
            "data_kind": data_kind,
        })
    return by_day


def hours_from_csv(path: Path, sunrise: datetime, sunset: datetime) -> list[dict]:
    rows = list(csv.DictReader(path.open()))
    hours = []
    for row in rows:
        when = datetime.fromisoformat(row["time"]).replace(tzinfo=CR)
        hours.append({
            "time": when,
            "sunrise": sunrise,
            "sunset": sunset,
            "temp_c": float(row["temp_c"]),
            "rh_pct": float(row["rh_pct"]),
            "wind_ms": float(row["wind_speed_10m_ms"]),
            "shortwave_wm2": float(row["shortwave_wm2"]),
            "pressure_hpa": float(row["surface_pressure_hpa"]),
            "cloud_pct": float(row["total_cloud_pct"]),
            "precip_mm": float(row["precip_mm"]),
            "uv": None,
            "swell_m": float(row["swell_wave_height_m"]),
            "swell_period_s": float(row["swell_wave_period_s"]),
            "energy_offshore_kj": float(row["swell_energy_kJ"]),
            "wbgt_sun_c": float(row["wbgt_sun_c"]),
            "wbgt_shade_c": float(row["wbgt_shade_c"]),
            "data_kind": "fixture",
        })
    return hours


def build_fixture(generated_at: datetime | None = None) -> dict:
    """11 Nov hours from the frozen CSV. 12–17 Nov from the committed Open-Meteo snapshot.

    Week quartiles and the calm threshold stay pinned to the published fixture,
    because the snapshot is not the 11 Nov 15:00 PT model run (that hourly file
    was not in the bundle).
    """
    forecast = json.loads((ROOT / "data" / "snapshot-forecast.json").read_text())
    marine = json.loads((ROOT / "data" / "snapshot-marine.json").read_text())
    by_day = hours_from_open_meteo(forecast, marine, "snapshot-2026-11-12")
    nov11 = hours_from_csv(
        ROOT / "data" / "this-week-hourly-nov11.csv",
        datetime.fromisoformat(forecast["daily"]["sunrise"][0]).replace(tzinfo=CR),
        datetime.fromisoformat(forecast["daily"]["sunset"][0]).replace(tzinfo=CR),
    )
    by_day["2026-11-11"] = nov11
    order = sorted(by_day)
    days = [by_day[d] for d in order if d >= "2026-11-11" and d <= "2026-11-17"]
    noaa = json.loads((ROOT / "data" / "noaa_hilo_fixture.json").read_text())
    extrema = extrema_from_noaa([
        {"t": row["t"], "ft": float(row["v"]), "type": row["type"]}
        for row in noaa["predictions"]
    ])
    as_of = generated_at or datetime(2026, 11, 11, 5, 2, tzinfo=CR)
    feeds = {
        "forecast": {"as_of": stamp(as_of), "ok": True, "source": "Open-Meteo Forecast"},
        "marine": {"as_of": stamp(as_of), "ok": True, "source": "Open-Meteo Marine"},
        "imn": {"as_of": stamp(as_of), "ok": True, "source": "IMN CAP RSS"},
        "tides": {"as_of": stamp(as_of), "ok": True, "source": "NOAA CO-OPS 9684403"},
    }
    return assemble(days, extrema, [], feeds, as_of, pinned_week=PINNED_WEEK)


def write_document(path: Path, document: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n")


def _feed(name: str, as_of: datetime, ok: bool, source: str) -> dict:
    return {"as_of": stamp(as_of), "ok": ok, "source": source}


def build_live(now: datetime | None = None, previous: dict | None = None) -> dict:
    from samara.fetch import fetch_forecast, fetch_imn, fetch_marine, fetch_noaa_window

    now = aware(now or datetime.now(CR))
    start = day_start(now)
    end = start + timedelta(days=6)
    problems: list[str] = []
    forecast = marine = None
    alerts: list[dict] = []
    try:
        forecast = fetch_forecast(start.date().isoformat(), end.date().isoformat())
    except Exception as exc:
        problems.append(f"forecast: {exc}")
    try:
        marine = fetch_marine(start.date().isoformat(), end.date().isoformat())
    except Exception as exc:
        problems.append(f"marine: {exc}")
    try:
        alerts, _ = fetch_imn(now)
        imn_ok = True
    except Exception as exc:
        problems.append(f"imn: {exc}")
        imn_ok = False
        if previous:
            alerts = previous.get("alerts") or []
    try:
        hilo, _hourly = fetch_noaa_window(start)
        extrema = extrema_from_noaa([
            {"t": row["t"], "v": row["v"], "type": row["type"]} for row in hilo
        ])
        tides_ok = True
    except Exception as exc:
        problems.append(f"tides: {exc}")
        tides_ok = False
        extrema = []
        if previous:
            extrema = _extrema_from_document(previous)

    old_as_of = {}
    if previous:
        for name, feed in previous["feeds"].items():
            old_as_of[name] = feed["as_of"]

    if forecast is None or marine is None:
        if previous is None:
            raise RuntimeError("fetch failed and there is no previous file: " + "; ".join(problems))
        # Keep the last good hours for a failed feed by refusing a partial weather rebuild
        # when either science feed is missing. Mark that feed's as_of by returning the
        # previous document with ok flags updated below.
        document = json.loads(json.dumps(previous))
        # The file itself stays at its old generated_at. Only a feed that
        # actually returned new data gets a new as_of.
        if forecast is None:
            document["feeds"]["forecast"]["ok"] = False
        if marine is None:
            document["feeds"]["marine"]["ok"] = False
        if not imn_ok:
            document["feeds"]["imn"]["ok"] = False
        else:
            document["feeds"]["imn"] = _feed("imn", now, True, "IMN CAP RSS")
            document["alerts"] = alerts
        if not tides_ok:
            document["feeds"]["tides"]["ok"] = False
        return document

    by_day = hours_from_open_meteo(forecast, marine, "forecast")
    days = [by_day[d] for d in sorted(by_day)]
    if len(days) != 7 or any(len(d) != 24 for d in days):
        if previous is None:
            raise RuntimeError("forecast did not return 7 complete days")
        document = json.loads(json.dumps(previous))
        document["feeds"]["forecast"]["ok"] = False
        return document
    as_of_forecast = now
    as_of_marine = now
    feeds = {
        "forecast": _feed("forecast", as_of_forecast, True, "Open-Meteo Forecast"),
        "marine": _feed("marine", as_of_marine, True, "Open-Meteo Marine"),
        "imn": _feed("imn", now if imn_ok else parse_stamp(old_as_of.get("imn", stamp(now))), imn_ok, "IMN CAP RSS"),
        "tides": _feed("tides", now if tides_ok else parse_stamp(old_as_of.get("tides", stamp(now))), tides_ok, "NOAA CO-OPS 9684403"),
    }
    if not imn_ok and previous:
        feeds["imn"]["as_of"] = previous["feeds"]["imn"]["as_of"]
    if not tides_ok and previous:
        feeds["tides"]["as_of"] = previous["feeds"]["tides"]["as_of"]
    return assemble(days, extrema, alerts, feeds, now, pinned_week=None)


def _extrema_from_document(document: dict) -> list[Extremum]:
    rows = []
    for day in document["days"]:
        for ext in day["tide_extrema"]:
            when = parse_stamp(ext["time"])
            rows.append(Extremum(when, float(ext["ft"]), "H" if ext["type"] == "high" else "L"))
    return rows


def publish(candidate: dict, previous_path: Path | None) -> tuple[dict, bool]:
    """Return (document to keep, replaced?). Never replaces a valid file with an invalid one."""
    previous = None
    if previous_path and previous_path.exists():
        previous = json.loads(previous_path.read_text())
    errors = validate(candidate)
    if not errors:
        return candidate, True
    if previous and not validate(previous):
        return previous, False
    raise RuntimeError("validation failed and there is no previous file: " + "; ".join(errors))
