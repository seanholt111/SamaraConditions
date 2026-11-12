"""Costa Rica hourly swell fetcher (Open-Meteo Marine, free, no key).

Primary field: swell_wave_height (m) = primary swell, what surf forecasts quote.
Also stored: swell_wave_period (s), swell_wave_direction (deg from).
Fallback only if swell is missing: wave_height (significant, wind sea + swell).

Wave energy (2026-10-11): energy_kj = rho*g^2*H^2*T^2/(16*pi) / 1000, i.e. wave energy per metre of
crest over one wavelength (E = rho*g*H^2/8 J/m^2 times deep-water L = g*T^2/(2*pi)). rho=1025.
This reproduces Surf-Forecast's kJ (their 1.6 m @ 18 s = 1501 kJ; formula gives ~1630; 1.1 m @ 15 s
566 vs ~534). Open-Meteo's swell period is a MEAN period (shorter than the peak period surf sites
quote), so our kJ usually reads lower than Surf-Forecast's; compare days with each other, not sites.

Wind (2026-10-11): Open-Meteo forecast wind_speed_10m / wind_direction_10m / gusts at the beach
point, stored under "wind": [{time, kmh, mph, dir_deg, gust_kmh}].

Usage: python fetch_cr_swell.py 2026-10-11 [--out swell.json]
Output JSON: {source, field, units, cell, hourly: [{time, m, ft, period_s, dir_deg, energy_kj}], wind: [...]}
"""
from __future__ import annotations

import argparse
import json
import urllib.request
from datetime import datetime
from pathlib import Path

FT_PER_M = 3.28084
RHO, G = 1025.0, 9.81


def energy_kj(h, t):
    if h is None or t is None:
        return None
    import math
    return RHO * G * G * h * h * t * t / (16 * math.pi) / 1000.0

UA = 'Mozilla/5.0 (FamilyWx/1.0 cr-swell)'


def fetch_wind(ds, lat, lon):
    url = ('https://api.open-meteo.com/v1/forecast?'
           f'latitude={lat}&longitude={lon}&hourly=wind_speed_10m,wind_direction_10m,wind_gusts_10m'
           f'&timezone=America%2FCosta_Rica&start_date={ds[0]}&end_date={ds[-1]}')
    try:
        req = urllib.request.Request(url, headers={'User-Agent': UA})
        with urllib.request.urlopen(req, timeout=45) as r:
            h = json.loads(r.read().decode())['hourly']
    except Exception as e:  # wind is optional; card shows no chip
        print('wind fetch failed:', e)
        return []
    return [{'time': t, 'kmh': k, 'mph': None if k is None else round(k * 0.621371, 1),
             'dir_deg': d, 'gust_kmh': g}
            for t, k, d, g in zip(h['time'], h['wind_speed_10m'], h['wind_direction_10m'], h['wind_gusts_10m'])]


def fetch(dates, lat=9.8826, lon=-85.5257, out=None):
    ds = sorted(dates)
    url = ('https://marine-api.open-meteo.com/v1/marine?'
           f'latitude={lat}&longitude={lon}'
           '&hourly=swell_wave_height,swell_wave_period,swell_wave_direction,wave_height,wave_period'
           f'&timezone=America%2FCosta_Rica&start_date={ds[0]}&end_date={ds[-1]}&cell_selection=sea')
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=45) as r:
        d = json.loads(r.read().decode())
    h = d['hourly']
    sw = h.get('swell_wave_height') or []
    use_swell = any(v is not None for v in sw)
    hk, pk, dk = (('swell_wave_height', 'swell_wave_period', 'swell_wave_direction') if use_swell
                  else ('wave_height', 'wave_period', None))
    rows = []
    for i, t in enumerate(h['time']):
        v = h[hk][i]
        rows.append({'time': t, 'm': v, 'ft': None if v is None else round(v * FT_PER_M, 1),
                     'period_s': h[pk][i], 'dir_deg': h[dk][i] if dk else None,
                     'energy_kj': None if energy_kj(v, h[pk][i]) is None else round(energy_kj(v, h[pk][i]))})
    res = {'source': 'Open-Meteo Marine', 'field': hk, 'label': 'Swell' if use_swell else 'Waves (sig.)',
           'units': 'm (ft derived)', 'cell': [d.get('latitude'), d.get('longitude')], 'url': url,
           'fetched': datetime.now().isoformat(timespec='seconds'), 'hourly': rows,
           'energy_method': 'rho*g^2*H^2*T^2/(16*pi), kJ per m crest per wavelength (Surf-Forecast-style)',
           'wind': fetch_wind(ds, lat, lon)}
    if out:
        Path(out).parent.mkdir(parents=True, exist_ok=True)
        Path(out).write_text(json.dumps(res, indent=2))
        print(f'wrote {out} ({hk}, {len(rows)} h)')
    return res


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('dates', nargs='+')
    p.add_argument('--lat', type=float, default=9.8826)
    p.add_argument('--lon', type=float, default=-85.5257)
    p.add_argument('--out', default=None)
    a = p.parse_args()
    r = fetch(a.dates, a.lat, a.lon, a.out)
    for x in r['hourly']:
        print(x)
