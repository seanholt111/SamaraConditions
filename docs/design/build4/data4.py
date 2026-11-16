"""Real fixture data for build-4 rounds (conditions.fixture.json, Nov 11-17 2026)."""
import json, math
from datetime import datetime
FIX = '/workspace/cr-conditions-app/repo/fixtures/conditions.fixture.json'
D = json.load(open(FIX))
T0, T1 = 6.0, 21.0  # care hours
CUT_MOD, CUT_HARD = 27.9, 25.7

def hh(iso):
    t = datetime.fromisoformat(iso); return t.hour + t.minute/60

def day(i):
    d = D['days'][i]
    hrs = d['hours']
    return dict(raw=d, date=d['date'], wd=d['weekday'], sunrise=hh(d['sunrise']), sunset=hh(d['sunset']),
        sun=[h['wbgt_sun_c'] for h in hrs], shade=[h['wbgt_shade_c'] for h in hrs],
        cloud=[h['cloud_pct'] for h in hrs], rain=[h['precip_mm'] for h in hrs],
        temp=[h['temp_c'] for h in hrs], wave=d['wave_word'],
        calm=[(hh(c['start']), hh(c['end'])) for c in d['calm_windows']],
        sea=[(hh(s['time']), s['energy_shore_kj'], s['energy_offshore_kj']) for s in d['sea']],
        precip=d['precip_mm'], off=d.get('precip_off_axis_mm'), cloudmean=d['cloud_daylight_mean_pct'])

EXT = [(datetime.fromisoformat(t['time']), t['ft']) for t in D['tides']]
def tide_ft(date, h):
    """cosine interpolation between extrema (spec 7.3)."""
    y, m, dd = map(int, date.split('-'))
    from datetime import timedelta
    t = datetime.fromisoformat(f"{date}T00:00:00-06:00") + timedelta(hours=h)
    for (a, ha), (b, hb) in zip(EXT, EXT[1:]):
        if a <= t <= b:
            p = (t - a).total_seconds() / (b - a).total_seconds()
            return ha + (hb - ha) * (1 - math.cos(math.pi * p)) / 2, (hb - ha), p
    return None, 0, 0

def interp(series, h):
    i = int(math.floor(h)); f = h - i
    if i >= 23: return series[23]
    return series[i] * (1 - f) + series[i + 1] * f

def windows(series, cut):
    """5-min grid inside 6a-9p, value<cut, start up / end down to 5 min, drop <5 min."""
    grid = [T0 + k/12 for k in range(int((T1-T0)*12)+1)]
    # crossing-precise via 1-min sampling then round
    mins = [T0 + k/60 for k in range(int((T1-T0)*60)+1)]
    ok = [interp(series, x) < cut for x in mins]
    out = []; s = None
    for x, o in zip(mins, ok):
        if o and s is None: s = x
        if not o and s is not None: out.append((s, x - 1/60)); s = None
    if s is not None: out.append((s, T1))
    res = []
    for a, b in out:
        a = math.ceil(round(a*12, 6)) / 12; b = math.floor(round(b*12, 6)) / 12
        if a <= T0 + 5/60: a = T0
        if b >= T1 - 5/60: b = T1
        if b - a >= 5/60: res.append((a, b))
    return res

ACT = {'Beach': ('sun', CUT_MOD), 'Soccer sun': ('sun', CUT_HARD), 'Soccer shade': ('shade', CUT_MOD),
       'Pool': (None, None), 'Jungle': ('shade', CUT_MOD)}
def act_windows(dy, act):
    k, c = ACT[act]
    if k is None: return [(T0, T1)]
    return windows(dy[k], c)

def fmt(h, suffix=True):
    m = int(round(h*60)); H, M = divmod(m, 60)
    ap = 'a' if H < 12 else 'p'; H12 = H % 12 or 12
    return f"{H12}:{M:02d}{ap}" if M else f"{H12}{ap}"
def fmtt(h):
    m = int(round(h*60)); H, M = divmod(m, 60)
    ap = 'a' if H < 12 else 'p'; H12 = H % 12 or 12
    return f"{H12}:{M:02d}{ap}"
def rng(a, b):
    sa, sb = fmtt(a), fmtt(b)
    if sa[-1] == sb[-1]: sa = sa[:-1]
    return f"{sa}–{sb}"
def label(w):
    a, b = w
    if a == T0 and b == T1: return 'All day'
    if a == T0: return 'Until ' + fmtt(b)
    if b == T1: return 'From ' + fmtt(a)
    return rng(a, b)

def zone(w):
    if w < 25.7: return 50
    if w < 27.9: return 40
    if w < 30.1: return 30
    if w < 32.3: return 20
    return 'stop'
def F(c): return c*9/5+32

if __name__ == '__main__':
    for i in range(7):
        dy = day(i)
        print(dy['wd'], dy['date'], 'sunset', fmtt(dy['sunset']), 'sun max', max(dy['sun']), 'shade max', max(dy['shade']))
        for a in ACT:
            print('   ', a, [label(w) for w in act_windows(dy, a)])
        print('   sun 15-21', dy['sun'][15:22], 'shade', dy['shade'][15:22])

import sys as _s; _s.path.insert(0, '/workspace/cr-conditions-app/repo/pipeline/src')
from samara.shore import energy_shore
THR = D['week']['calm_threshold_kj']
def _mid(series, t):
    u = t - 0.5
    return interp(series, max(0, u))
def sea(i, t0=T0, t1=T1):
    d = D['days'][i]; hrs = d['hours']
    eo = [h['energy_offshore_kj'] for h in hrs]; hs = [h['swell_m'] for h in hrs]; tp = [h['swell_period_s'] for h in hrs]
    pts = []
    for k in range(int((t1 - t0) * 12) + 1):
        t = t0 + k / 12
        e = _mid(eo, t); H = _mid(hs, t); P = _mid(tp, t); ft = tide_ft(d['date'], t)[0]
        if ft is None: continue
        pts.append((t, energy_shore(e, H, P, ft), e))
    return pts
def calm(i, t0=T0, t1=T1):
    pts = sea(i, t0, t1); runs = []; s = None
    for t, es, _ in pts:
        if es < THR and s is None: s = t
        if es >= THR and s is not None: runs.append((s, t - 1/12)); s = None
    if s is not None: runs.append((s, pts[-1][0]))
    return [(a, b) for a, b in runs if b - a >= 15/60 - 1e-9]
