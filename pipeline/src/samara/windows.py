"""Activity windows, beach lean, calm windows. Spec §7.2, §7.3, §7.6."""

from __future__ import annotations

import math
from datetime import datetime, timedelta

CUT_MOD = 27.9
CUT_HARD = 25.7
FIVE = 5


def daylight(sunrise: datetime, sunset: datetime) -> tuple[datetime, datetime]:
    return sunrise + timedelta(minutes=15), sunset - timedelta(minutes=30)


def _ceil5(minutes: float) -> int:
    return int(math.ceil(minutes / FIVE - 1e-8)) * FIVE


def _floor5(minutes: float) -> int:
    return int(math.floor(minutes / FIVE + 1e-8)) * FIVE


def _minutes(day: datetime, when: datetime) -> float:
    return (when - day).total_seconds() / 60.0


def _at(day: datetime, minutes: float) -> datetime:
    return day + timedelta(minutes=minutes)


def intervals_below(points: list[tuple[datetime, float]], cut: float) -> list[tuple[datetime, datetime]]:
    """Where the piecewise-linear series is strictly below `cut`."""
    if len(points) < 2:
        return []
    spans: list[tuple[datetime, datetime]] = []
    current: datetime | None = points[0][0] if points[0][1] < cut else None
    for (t0, v0), (t1, v1) in zip(points, points[1:]):
        below0, below1 = v0 < cut, v1 < cut
        if below0 == below1:
            continue
        if v1 == v0:
            continue
        frac = min(1.0, max(0.0, (cut - v0) / (v1 - v0)))
        cross = t0 + (t1 - t0) * frac
        if below1:
            current = cross
        elif current is not None:
            spans.append((current, cross))
            current = None
    if current is not None:
        spans.append((current, points[-1][0]))
    return spans


def clip_round(
    spans: list[tuple[datetime, datetime]],
    start: datetime,
    end: datetime,
    day: datetime,
    minimum_minutes: float = 5,
) -> list[tuple[datetime, datetime]]:
    """Clip to [start, end], round inward to 5 minutes, drop short pieces."""
    kept: list[tuple[datetime, datetime]] = []
    for a, b in spans:
        lo = max(a, start)
        hi = min(b, end)
        if hi <= lo:
            continue
        sm = _ceil5(_minutes(day, lo))
        em = _floor5(_minutes(day, hi))
        if em - sm < minimum_minutes - 1e-6:
            continue
        kept.append((_at(day, sm), _at(day, em)))
    return kept


def heat_windows(
    hours: list[tuple[datetime, float]],
    cut: float,
    sunrise: datetime,
    sunset: datetime,
) -> list[tuple[datetime, datetime]]:
    day = sunrise.replace(hour=0, minute=0, second=0, microsecond=0)
    lo, hi = daylight(sunrise, sunset)
    return clip_round(intervals_below(hours, cut), lo, hi, day)


def pool_window(sunrise: datetime, sunset: datetime) -> list[tuple[datetime, datetime]]:
    day = sunrise.replace(hour=0, minute=0, second=0, microsecond=0)
    lo, hi = daylight(sunrise, sunset)
    return clip_round([(lo, hi)], lo, hi, day)


def intersect(
    left: list[tuple[datetime, datetime]],
    right: list[tuple[datetime, datetime]],
    day: datetime,
    minimum_minutes: float = 5,
) -> list[tuple[datetime, datetime]]:
    pieces: list[tuple[datetime, datetime]] = []
    for a, b in left:
        for c, d in right:
            lo, hi = max(a, c), min(b, d)
            if hi > lo:
                pieces.append((lo, hi))
    if not pieces:
        return []
    return clip_round(pieces, pieces[0][0] - timedelta(days=1), pieces[-1][1] + timedelta(days=1), day, minimum_minutes)


def lean_spans(
    lows: list[datetime],
    hourly_energy: list[tuple[datetime, float]],
    q3: float,
    sunrise: datetime,
    sunset: datetime,
) -> list[tuple[datetime, datetime]]:
    """[low − 2 h, low + 1 h], drop a span whose hourly offshore energy exceeds Q3, clip to daylight."""
    lo, hi = daylight(sunrise, sunset)
    day = sunrise.replace(hour=0, minute=0, second=0, microsecond=0)
    raw: list[tuple[datetime, datetime]] = []
    for low in lows:
        a, b = low - timedelta(hours=2), low + timedelta(hours=1)
        inside = [e for t, e in hourly_energy if a <= t <= b]
        if any(e > q3 for e in inside):
            continue
        raw.append((a, b))
    return clip_round(raw, lo, hi, day)


def calm_windows(
    samples: list[tuple[datetime, float]],
    threshold: float,
    sunrise: datetime,
    sunset: datetime,
) -> list[tuple[datetime, datetime]]:
    """samples are on a 5-minute grid. Keep runs of at least 15 minutes inside daylight."""
    lo, hi = daylight(sunrise, sunset)
    day = sunrise.replace(hour=0, minute=0, second=0, microsecond=0)
    inside = [(t, v) for t, v in samples if lo <= t <= hi]
    if not inside:
        return []
    spans: list[tuple[datetime, datetime]] = []
    current: datetime | None = None
    prev: datetime | None = None
    for t, v in inside:
        ok = v < threshold
        if ok and current is None:
            current = t
        if not ok and current is not None and prev is not None:
            spans.append((current, prev))
            current = None
        prev = t
    if current is not None and prev is not None:
        spans.append((current, prev))
    return [(a, b) for a, b in spans if (b - a) >= timedelta(minutes=15)]
