"""Offshore swell energy. Same formula as docs/source/scripts/fetch_cr_swell.py."""

from __future__ import annotations

import math

RHO = 1025.0
G = 9.81


def energy_kj(height_m: float | None, period_s: float | None) -> float | None:
    """kJ per metre of crest over one wavelength. None if an input is missing."""
    if height_m is None or period_s is None:
        return None
    if height_m < 0 or period_s <= 0:
        return None
    return RHO * G * G * height_m * height_m * period_s * period_s / (16 * math.pi) / 1000.0
