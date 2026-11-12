"""Keyless fetches: Open-Meteo forecast, Open-Meteo marine, IMN, NOAA tides."""

from __future__ import annotations

import json
import urllib.request
from datetime import datetime, timedelta

from samara.imn import RSS_URL, alerts_from_rss

UA = "SamaraConditions/1.0 (private family app; samara-conditions)"
FORECAST_LAT, FORECAST_LON = 9.876977, -85.51575
MARINE_LAT, MARINE_LON = 9.875, -85.54166
NOAA = "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter"


def _get(url: str, timeout: int = 45) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json, application/xml, */*"})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.read()


def fetch_forecast(start: str, end: str) -> dict:
    url = (
        "https://api.open-meteo.com/v1/forecast?"
        f"latitude={FORECAST_LAT}&longitude={FORECAST_LON}"
        "&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,shortwave_radiation,"
        "surface_pressure,cloud_cover,precipitation,uv_index"
        "&daily=sunrise,sunset&wind_speed_unit=ms&timezone=America%2FCosta_Rica"
        f"&start_date={start}&end_date={end}"
    )
    payload = json.loads(_get(url))
    payload["_url"] = url
    return payload


def fetch_marine(start: str, end: str) -> dict:
    url = (
        "https://marine-api.open-meteo.com/v1/marine?"
        f"latitude={MARINE_LAT}&longitude={MARINE_LON}"
        "&hourly=swell_wave_height,swell_wave_period"
        "&timezone=America%2FCosta_Rica"
        f"&start_date={start}&end_date={end}&cell_selection=sea"
    )
    payload = json.loads(_get(url))
    payload["_url"] = url
    return payload


def fetch_imn(now: datetime) -> tuple[list[dict], str]:
    rss = _get(RSS_URL)
    cache: dict[str, bytes | None] = {}

    def lookup(url: str) -> bytes | None:
        if url not in cache:
            try:
                cache[url] = _get(url, timeout=20)
            except Exception:
                cache[url] = None
        return cache[url]

    return alerts_from_rss(rss, lookup, now), RSS_URL


def fetch_noaa(begin: datetime, end: datetime, interval: str) -> list[dict]:
    url = (
        f"{NOAA}?product=predictions&application=SamaraConditions&station=9684403"
        f"&datum=MLLW&time_zone=lst&units=english&format=json&interval={interval}"
        f"&begin_date={begin:%Y%m%d}&end_date={end:%Y%m%d}"
    )
    payload = json.loads(_get(url))
    if "predictions" not in payload:
        raise RuntimeError(f"NOAA returned no predictions: {payload.get('error', payload)[:200]}")
    return payload["predictions"]


def fetch_noaa_window(day: datetime) -> tuple[list[dict], list[dict]]:
    """Hi/lo and hourly predictions for day−7 through day+7."""
    begin = day - timedelta(days=7)
    end = day + timedelta(days=7)
    return fetch_noaa(begin, end, "hilo"), fetch_noaa(begin, end, "h")
