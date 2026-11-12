"""Liljegren 2008 WBGT via the vendored Argonne C code. See NOTICE.

Sun: solar = shortwave, wind at 10 m. Shade: solar = 0, the 2 m wind from the sun run.
Lat/lon 9.88, −85.53. gmt = −6. Do not use Open-Meteo's wet bulb.
"""

from __future__ import annotations

import ctypes
import subprocess
import sys
from pathlib import Path

LAT = 9.88
LON = -85.53
GMT = -6
AVG_MIN = 60

_ROOT = Path(__file__).resolve().parents[2]
_SRC = _ROOT / "vendor" / "liljegren" / "wbgt.c"
_CACHE = _ROOT / ".cache"
_LIB: ctypes.CDLL | None = None


def _library() -> ctypes.CDLL:
    global _LIB
    if _LIB is not None:
        return _LIB
    _CACHE.mkdir(parents=True, exist_ok=True)
    lib_path = _CACHE / ("libwbgt.dylib" if sys.platform == "darwin" else "libwbgt.so")
    if not lib_path.exists() or _SRC.stat().st_mtime > lib_path.stat().st_mtime:
        cc = "cc"
        subprocess.check_call(
            [cc, "-shared", "-fPIC", "-O2", "-o", str(lib_path), str(_SRC), "-lm"],
            cwd=str(_SRC.parent),
        )
    lib = ctypes.CDLL(str(lib_path))
    lib.calc_wbgt.argtypes = [
        ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
        ctypes.c_int, ctypes.c_int,
        ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double,
        ctypes.c_double, ctypes.c_double, ctypes.c_double, ctypes.c_double,
        ctypes.c_double, ctypes.c_int,
        ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double), ctypes.POINTER(ctypes.c_double),
        ctypes.POINTER(ctypes.c_double),
    ]
    lib.calc_wbgt.restype = ctypes.c_int
    _LIB = lib
    return lib


def liljegren(
    year: int, month: int, day: int, hour: int,
    solar: float, pressure_hpa: float, temp_c: float, rh_pct: float,
    wind_ms: float, zspeed_m: float,
) -> tuple[float, float]:
    """Return (Twbg °C, estimated wind m/s at the reference height)."""
    est = ctypes.c_double()
    tg = ctypes.c_double()
    tn = ctypes.c_double()
    tpsy = ctypes.c_double()
    tw = ctypes.c_double()
    status = _library().calc_wbgt(
        year, month, day, hour, 0, GMT, AVG_MIN,
        LAT, LON, float(solar), float(pressure_hpa), float(temp_c), float(rh_pct),
        float(wind_ms), float(zspeed_m), 0.0, 0,
        ctypes.byref(est), ctypes.byref(tg), ctypes.byref(tn), ctypes.byref(tpsy), ctypes.byref(tw),
    )
    if status != 0 or tw.value < -100:
        raise RuntimeError(f"Liljegren did not converge at {year}-{month:02d}-{day:02d} {hour:02d}h")
    return tw.value, est.value


def sun_and_shade(
    year: int, month: int, day: int, hour: int,
    solar: float, pressure_hpa: float, temp_c: float, rh_pct: float, wind_10m: float,
) -> tuple[float, float, float]:
    """Return (wbgt sun, wbgt shade, 2 m wind)."""
    sun, wind2 = liljegren(year, month, day, hour, solar, pressure_hpa, temp_c, rh_pct, wind_10m, 10.0)
    shade, _ = liljegren(year, month, day, hour, 0.0, pressure_hpa, temp_c, rh_pct, wind2, 2.0)
    return sun, shade, wind2
