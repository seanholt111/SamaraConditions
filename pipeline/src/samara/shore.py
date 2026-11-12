"""Shore energy model. Port of docs/source/scripts/shore_model.py, spec §7.5–7.6.

MODEL, not a measurement. The four reef numbers are guesses.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

FT = 0.3048
G = 9.81


@dataclass(frozen=True)
class Reef:
    z_crest_ft: float = 1.0
    b_m: float = 30.0
    cot_a: float = 3.0
    kd: float = 0.30


DEFAULT = Reef()


def transmission(hs_m: float, period_s: float, freeboard_m: float, reef: Reef = DEFAULT) -> float:
    """Kt. d'Angremond below r = 8, Briganti / van der Meer above r = 12, blend between."""
    if hs_m <= 0 or period_s <= 0:
        return 0.8
    steep = 2 * math.pi * hs_m / (G * period_s * period_s)
    xi = (1 / reef.cot_a) / math.sqrt(steep)
    r = reef.b_m / hs_m
    k_da = _clamp(
        -0.40 * freeboard_m / hs_m + 0.64 * r ** -0.31 * (1 - math.exp(-0.50 * xi)),
        0.075,
        0.80,
    )
    k_br = _clamp(
        -0.35 * freeboard_m / hs_m + 0.51 * r ** -0.65 * (1 - math.exp(-0.41 * xi)),
        0.05,
        0.93 - 0.006 * r,
    )
    if r <= 8:
        return k_da
    if r >= 12:
        return k_br
    w = (r - 8) / 4
    return (1 - w) * k_da + w * k_br


def shore_fraction(hs_m: float, period_s: float, freeboard_m: float, reef: Reef = DEFAULT) -> tuple[float, float]:
    """Return (Kt, min(1, Kt^2 + Kd^2))."""
    kt = transmission(hs_m, period_s, freeboard_m, reef)
    return kt, min(1.0, kt * kt + reef.kd * reef.kd)


def energy_shore(e_off: float, hs_m: float, period_s: float, tide_ft: float, reef: Reef = DEFAULT) -> float:
    freeboard = (reef.z_crest_ft - tide_ft) * FT
    _, frac = shore_fraction(hs_m, period_s, freeboard, reef)
    return e_off * frac


def calm_threshold(e_med: float, hs_med: float, t_med: float, reef: Reef = DEFAULT) -> tuple[float, float]:
    """Shore energy at a 3 ft tide under the week-median offshore conditions.

    Returns (threshold kJ, Kt).
    """
    freeboard = (reef.z_crest_ft - 3.0) * FT
    kt, frac = shore_fraction(hs_med, t_med, freeboard, reef)
    return e_med * frac, kt


def _clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))
