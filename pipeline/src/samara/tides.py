"""Cosine tide interpolation and the reef-shelter span. Spec §7.3."""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timedelta


@dataclass(frozen=True)
class Extremum:
    time: datetime
    feet: float
    kind: str  # "H" or "L"


def height_at(when: datetime, extrema: list[Extremum]) -> float | None:
    """Cosine between the surrounding extrema. None if the time is outside them."""
    if len(extrema) < 2:
        return None
    ordered = sorted(extrema, key=lambda e: e.time)
    if when < ordered[0].time or when > ordered[-1].time:
        return None
    for left, right in zip(ordered, ordered[1:]):
        if left.time <= when <= right.time:
            span = (right.time - left.time).total_seconds()
            if span <= 0:
                return left.feet
            p = (when - left.time).total_seconds() / span
            return left.feet + (right.feet - left.feet) * (1 - math.cos(math.pi * p)) / 2
    return None


def _cross(t0: datetime, h0: float, t1: datetime, h1: float, level: float) -> datetime | None:
    if h0 == h1:
        return None
    if (h0 - level) * (h1 - level) > 0:
        return None
    target = (level - h0) / (h1 - h0)
    cosv = 1 - 2 * target
    if cosv < -1 or cosv > 1:
        return None
    p = math.acos(cosv) / math.pi
    return t0 + (t1 - t0) * p


def round_minute(when: datetime) -> datetime:
    """Nearest minute. A half minute rounds up."""
    trimmed = when.replace(second=0, microsecond=0)
    if when.second > 30 or (when.second == 30 and when.microsecond >= 0 and when.second == 30):
        return trimmed + timedelta(minutes=1)
    if when.second > 30:
        return trimmed + timedelta(minutes=1)
    return trimmed


def below_level(extrema: list[Extremum], level: float = 3.0) -> list[tuple[datetime, datetime]]:
    """Spans where the cosine tide is below `level`, ends rounded to the minute."""
    ordered = sorted(extrema, key=lambda e: e.time)
    if len(ordered) < 2:
        return []
    spans: list[tuple[datetime, datetime]] = []
    start: datetime | None = None
    if ordered[0].feet < level:
        start = ordered[0].time
    for left, right in zip(ordered, ordered[1:]):
        cross = _cross(left.time, left.feet, right.time, right.feet, level)
        going_down = right.feet < left.feet
        if cross is None:
            continue
        if going_down:
            start = cross
        else:
            if start is None:
                start = left.time
            spans.append((start, cross))
            start = None
    if start is not None:
        spans.append((start, ordered[-1].time))
    return [(round_minute(a), round_minute(b)) for a, b in spans if b > a]


def reef_shelters(
    extrema: list[Extremum],
    sunrise: datetime,
    sunset: datetime,
    level: float = 3.0,
) -> list[tuple[datetime, datetime]]:
    """Daytime spans under the reef line. Endpoints stay at the real crossings."""
    return [span for span in below_level(extrema, level) if span[1] > sunrise and span[0] < sunset]
