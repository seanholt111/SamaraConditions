"""MODEL, not measured: wave energy reaching Sámara beach = over-reef transmission + gap/channel leak.
E_shore(t) = E_off(t) * min(1, Kt(t)^2 + G)
  Kt: van der Meer et al. 2005 / Briganti et al. 2003 (B/Hs > 12) and d'Angremond et al. 1996 (B/Hs < 8),
      linear blend 8–12; limits 0.05 <= Kt <= 0.93 - 0.006 B/Hs (B/Hs>=8) or 0.075–0.8 (d'Angremond).
      Rc = freeboard = reef crest - water level (m; negative = submerged); xi = tan(a)/sqrt(2*pi*Hs/(g*T^2)).
  G : tide-independent energy fraction through reef gaps + Isla Chora channel = Kd^2 (diffraction, CEM II-7).
GUESSES: crest elevation Z_CREST_FT, crest width B_M, front slope COT_A, gap Kd. Period: model mean period used as Tp."""
import math
import build_v8 as b
FT, g = 0.3048, 9.81
P = dict(Z_CREST_FT=1.0, B_M=30.0, COT_A=3.0, KD=0.30)

def lerp_off(date, t):
    by = b.D["by"][date]; u = t - 0.5; h0 = max(0, min(23, int(u // 1))); h1 = min(23, h0 + 1); f = max(0, min(1, u - h0))
    v = lambda k: (1 - f) * float(by[h0][k]) + f * float(by[h1][k])
    return v("energy_kj"), v("swell_wave_height_m"), v("swell_wave_period_s")
def tide(date, t): return b.tide_at(b.day_offset(date) + t)

def kt(Hs, T, Rc, B, cot):
    s = 2 * math.pi * Hs / (g * T * T); xi = (1 / cot) / math.sqrt(s); r = B / Hs
    k_da = max(0.075, min(0.80, -0.4 * Rc / Hs + 0.64 * r ** -0.31 * (1 - math.exp(-0.5 * xi))))
    k_br = max(0.05, min(0.93 - 0.006 * r, -0.35 * Rc / Hs + 0.51 * r ** -0.65 * (1 - math.exp(-0.41 * xi))))
    if r <= 8: return k_da
    if r >= 12: return k_br
    w = (r - 8) / 4; return (1 - w) * k_da + w * k_br

def parts(date, t, p=None):
    p = p or P; E, H, T = lerp_off(date, t)
    Rc = (p["Z_CREST_FT"] - tide(date, t)) * FT
    K = kt(H, T, Rc, p["B_M"], p["COT_A"]); G = p["KD"] ** 2
    over, gap = E * K * K, E * G
    return E, min(E, over + gap), over, gap, K

def e_shore(date, t, p=None): return parts(date, t, p)[1]

def threshold(p=None):
    """shore energy at the 3 ft tide line under week-median offshore conditions (daylight 6a–9p pool)"""
    import statistics as st
    rows = [r for d in b.D["daily"] for r in b.D["by"][d["date"]] if 6 <= int(r["hour"]) <= 21]
    E = st.median(float(r["energy_kj"]) for r in rows); H = st.median(float(r["swell_wave_height_m"]) for r in rows)
    T = st.median(float(r["swell_wave_period_s"]) for r in rows); p = p or P
    K = kt(H, T, (p["Z_CREST_FT"] - 3.0) * FT, p["B_M"], p["COT_A"])
    return E * min(1, K * K + p["KD"] ** 2), (E, H, T, K)

def calm(date, p=None, thr=None):
    thr = thr if thr is not None else threshold(p)[0]
    rise, aset, lo, hi = b.daylight(date); m0, m1 = math.ceil(lo * 12), math.floor(hi * 12); out = []; cur = None
    for m in range(m0, m1 + 1):
        ok = e_shore(date, m / 12 + 1e-6, p) < thr
        if ok and cur is None: cur = m / 12
        if not ok and cur is not None: out.append((cur, (m - 1) / 12)); cur = None
    if cur is not None: out.append((cur, m1 / 12))
    return [(a, z) for a, z in out if z - a >= 0.25]
