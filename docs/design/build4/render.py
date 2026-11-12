#!/usr/bin/env python3
"""Build-4 UX rounds: iPhone 402x874 pt sketch frames from real fixture data (Nov 11-17 2026).
usage: python3 render.py <round 1|2|3>   -> rN/frames/*.png + rN/sheet.png
"""
import sys, math, os
from PIL import Image, ImageDraw, ImageFont
import data4 as D

R = int(sys.argv[1]) if len(sys.argv) > 1 else 1
OUT = f'/workspace/cr-conditions-app/design/build4-rounds/r{R}' + ('' if int(os.environ.get('PTW', 402)) == 402 else f"/w{os.environ['PTW']}")
os.makedirs(OUT + '/frames', exist_ok=True)
S = 2                      # px per pt
W, H = int(os.environ.get('PTW', 402)), 874   # iPhone 16/17 Pro (402) by default; PTW=375/393 for width checks
M = 16; CW = W - 2*M
INTER = '/usr/share/fonts/truetype/sand-box/google/Inter/Inter-VariableFont_opsz,wght.ttf'
BG=(10,14,20); TRACK=(22,28,37); TEXT=(242,242,240); MUTED=(154,158,166); WHITE=(255,255,255)
AMBER=(249,140,10); C50=(246,215,70); C40=(249,140,10); C30=(212,72,66); C20=(162,51,122)
HATCH=(18,8,20); HATCHL=(245,198,224); LAGOON=(142,230,238); MID=(63,169,220); OCEAN=(47,102,224); DEEP=(36,80,200)
CLOUD=(201,206,214); CHIPF=(28,36,48); CHIPE=(58,66,76); NIGHTSKY=(14,18,26)
_fc = {}
def font(sz, wt=500):
    k = (sz, wt)
    if k not in _fc:
        f = ImageFont.truetype(INTER, int(sz*S)); f.set_variation_by_axes([min(32, max(14, sz)), wt]); _fc[k] = f
    return _fc[k]
def tw(t, sz, wt=500): return font(sz, wt).getlength(t) / S   # text width in pt
ISSUES = []   # collision log per frame

class Frame:
    def __init__(s, name, title):
        s.name, s.title = name, title
        s.im = Image.new('RGB', (W*S, H*S), BG); s.d = ImageDraw.Draw(s.im, 'RGBA')
    def rect(s, x0, y0, x1, y1, fill=None, outline=None, r=0, w=1):
        box = [x0*S, y0*S, x1*S, y1*S]
        if r: s.d.rounded_rectangle(box, r*S, fill=fill, outline=outline, width=int(w*S))
        else: s.d.rectangle(box, fill=fill, outline=outline, width=int(w*S))
    def text(s, x, y, t, sz=13, wt=500, fill=TEXT, anchor='la'):
        s.d.text((x*S, y*S), t, font=font(sz, wt), fill=fill, anchor=anchor)
        w = tw(t, sz, wt)
        x0 = x - (w if anchor[0] == 'r' else w/2 if anchor[0] == 'm' else 0)
        return (x0, x0 + w)
    def line(s, pts, fill=WHITE, w=1, dash=None):
        P = [(x*S, y*S) for x, y in pts]
        if not dash: s.d.line(P, fill=fill, width=max(1, int(w*S)), joint='curve'); return
        on, off = dash; acc = 0; draw = True
        for (x0, y0), (x1, y1) in zip(P, P[1:]):
            L = math.hypot(x1-x0, y1-y0); t = 0
            while t < L:
                seg = (on if draw else off)*S - acc; step = min(seg, L - t)
                if draw:
                    a = t/L; b = (t+step)/L
                    s.d.line([(x0+(x1-x0)*a, y0+(y1-y0)*a), (x0+(x1-x0)*b, y0+(y1-y0)*b)], fill=fill, width=max(1, int(w*S)))
                t += step; acc += step
                if acc >= (on if draw else off)*S - 1e-6: acc = 0; draw = not draw
    def poly(s, pts, fill): s.d.polygon([(x*S, y*S) for x, y in pts], fill=fill)
    def dot(s, x, y, r=4, fill=WHITE, edge=BG):
        s.d.ellipse([(x-r)*S, (y-r)*S, (x+r)*S, (y+r)*S], fill=fill, outline=edge, width=int(1.5*S))
    def save(s):
        s.im.save(f'{OUT}/frames/{s.name}.png'); return s

# ---------------- shared chrome ----------------
def X(h): return M + (h - D.T0) / (D.T1 - D.T0) * CW
def chrome(f, week=False, date='11 NOV', asof='as of 5:02a', day_idx=0):
    f.text(48, 30, '9:41', 16, 600, WHITE, 'mm')
    f.rect(W-72, 25, W-50, 35, outline=WHITE, r=3, w=1); f.rect(W-70, 27, W-54, 33, fill=WHITE, r=2)
    lbl = ('Today', 'Week') if R == 1 else ('Day', 'Week')
    f.rect(M, 66, 178, 106, fill=(22,27,35), r=20)
    sel = 1 if week else 0
    f.rect(M+4 + sel*79, 70, M+4 + sel*79 + 75, 102, fill=(40,46,56), r=16)
    for i, t in enumerate(lbl): f.text(M+4 + i*79 + 37.5, 86, t, 17, 600 if i == sel else 500, TEXT if i == sel else MUTED, 'mm')
    f.d.ellipse([(W-32-18)*S, (86-18)*S, (W-32+18)*S, (86+18)*S], outline=(80,86,96), width=int(1*S))
    f.text(W-32, 86, 'i', 18, 700, TEXT, 'mm')
    if week or R == 1:
        w = tw(date, 13, 600) + 20
        f.rect(M, 116, M + w, 140, fill=(28,34,44), r=6); f.text(M + 10, 128, date, 13, 600, MUTED, 'lm')
        if R == 1 and not week:   # R1 day nav: chevrons beside the date chip (+ swipe)
            f.text(M + w + 14, 128, '‹', 20, 500, MUTED, 'mm'); f.text(M + w + 34, 128, '›', 20, 500, TEXT, 'mm')
        f.text(M, 158, asof, 13, 500, MUTED, 'lm')
    else:
        date_strip(f, day_idx)
        f.text(M, 158, asof if day_idx == 0 else asof + ' · forecast', 13, 500, MUTED, 'lm')

def date_strip(f, sel):
    # R2+: 7 equal day cells replacing the date chip; today = "Today"; days 4-7 muted text
    n = 7; gap = 4; cw = (CW - gap*(n-1)) / n
    for i in range(n):
        dy = D.day(i); x0 = M + i*(cw+gap)
        if i == sel: f.rect(x0, 112, x0+cw, 144, fill=CHIPF, outline=CHIPE, r=8, w=1)
        col = TEXT if i < 3 else MUTED
        top = 'Today' if (i == 0 and R >= 3) else dy['wd']
        f.text(x0+cw/2, 122, top, 11, 600 if i == sel else 500, col if i != sel else WHITE, 'mm')
        f.text(x0+cw/2, 136, dy['date'][-2:], 12, 700 if i == sel else 500, col if i != sel else WHITE, 'mm')

# ---------------- Today ----------------
SKY = (212, 284); TIDE = (292, 378); HEAT = (388, 606); AX = 616
WMIN, WMAX = 23.0, 33.0
def hy(w): return HEAT[1] - (w - WMIN) / (WMAX - WMIN) * (HEAT[1] - HEAT[0] - 22)
ZC = {50: C50, 40: C40, 30: C30, 20: C20}
UNIT = 'F'
DT = 1.0; WRAP = False
def T(c, unit=None):
    unit = unit or UNIT
    return f"{round(D.F(c)) if unit == 'F' else round(c)}°"

def today(name, title, di=0, act='Beach', drag=None, now=12.78, unit='F', clip_sun=False, stale_tide=False, dt=1.0, low=False, ro='pill', tideline=False):
    global UNIT, DT, WRAP, SKY, TIDE, HEAT, LANE, XSKY, XSEA; UNIT = unit; DT = dt; WRAP = (dt > 1.0 and drag is not None)
    SKY, TIDE, HEAT = (212, 284), (292, 378), (388, 606); LANE, XSKY, XSEA = 22, 0, 0
    if R >= 7 and WRAP:   # R7+: lanes scale with text; a band whose pills can't fit one row stacks them and grows one pill row
        LANE = 4 + 18*DT; st = pill_stack(DT)
        XSKY = 20*DT if st[0] else 0; XSEA = 20*DT if st[1] else 0
        g1 = LANE - 22 + XSKY; g2 = LANE - 22 + XSEA
        SKY = (212, 284 + g1); TIDE = (292 + g1, 378 + g1 + g2); HEAT = (388 + g1 + g2, 606)
    elif WRAP and R >= 6:   # R6: bands grow by one text line each; heat plot gives the space back
        g = 16*DT; SKY = (212, 284 + g); TIDE = (292 + g, 378 + 2*g); HEAT = (388 + 2*g, 606)
    f = Frame(name, title); dy = D.day(di); ss = dy['sunset']; f.stale_tide = stale_tide
    chrome(f, day_idx=di)
    # readout row (heat): values at drag or now
    tref = drag if drag is not None else (now if di == 0 else None)
    if tref is not None:
        su, sh = D.interp(dy['sun'], tref), D.interp(dy['shade'], tref)
    else:
        su, sh = max(dy['sun']), max(dy['shade'])
    after_dark = tref is not None and (tref > ss if R == 1 else T(su) == T(sh))
    x = M
    if R >= 2 and di != 0 and drag is None:
        x = f.text(x, 191, 'high', 15, 500, MUTED, 'lm')[1] + 8
    f.line([(x, 191), (x+12, 191)], WHITE, 3); x += 18
    if after_dark and R >= 2:
        x = f.text(x, 191, T(sh), 24, 500, TEXT, 'lm')[1] + 8
        x = f.text(x, 192, 'sun and shade equal' if R == 2 else 'sun = shade', 13, 500, MUTED, 'lm')[1]
    else:
        x = f.text(x, 191, T(su), 24*min(DT, 1.15), 500, TEXT, 'lm')[1] + 14
        f.line([(x, 191), (x+12, 191)], WHITE, 2, dash=(2, 1.5)); x += 18
        x = f.text(x, 191, T(sh), 24*min(DT, 1.15), 500, TEXT, 'lm')[1]
    if R >= 3 and drag is not None:
        k_ = D.ACT[act][0]
        if k_:
            z_ = D.zone(D.interp(dy[k_], drag)); zt = 'Stop' if z_ == 'stop' else f'{z_} min/hr'
            if R >= 4:
                f.rect(x + 10, 186, x + 20, 196, fill=ZC[z_] if z_ != 'stop' else HATCH, outline=None if z_ != 'stop' else HATCHL, r=2); x += 14
            ex = f.text(x + 10, 192, zt, 13*DT, 600, MUTED, 'lm')[1]
            lab_ = D.fmtt(drag); lw_ = tw(lab_, 15, 700) + 14
            if ex + 6 > M + CW - lw_: ISSUES.append(f'{name}: readout row too wide ({ex:.0f} vs pill at {M+CW-lw_:.0f})')
    # ---- sky band
    f.rect(M, SKY[0], M+CW, SKY[1], fill=TRACK, r=12)
    xs = X(ss)
    if R >= 1:
        f.rect(xs, SKY[0], M+CW, SKY[1], fill=NIGHTSKY if R >= 2 else BG, r=0)
        f.rect(M+CW-12, SKY[0], M+CW, SKY[1], fill=NIGHTSKY if R >= 2 else BG, r=0)
    top = (SKY[0] + LANE + 2 + XSKY) if R >= 7 else (SKY[0] + 24 + (16*DT if WRAP else 0)); bot = SKY[1] - 2
    f.sky_geom = (top, bot)
    for h in range(6, 21):
        x0, x1 = X(h) + 0.5, X(h+1) - 0.5
        if R >= 2 or h < ss:
            xe = min(x1, X(ss)) if (h < ss < h+1 and R == 1) else x1
            c = dy['cloud'][h] / 100
            f.rect(x0, bot - c*(bot-top), xe, bot, fill=CLOUD if h + 0.5 < ss else (112, 117, 126))
        r = dy['rain'][h]
        if r > 0:
            f.rect(x0, bot - min(1, r)*(bot-top), x1, bot, fill=MID)
    # round the right corners back
    if R >= 7: ty, tide_head = sea_band(f, dy, di, tideline)
    else: ty, tide_head = old_tide(f, dy, di)
    # ---- heat
    f.text(M+10, HEAT[0]+8, 'Heat', 12, 600, MUTED, 'lm')
    grid = [D.T0 + k/12 for k in range(181)]
    for t0_, t1_ in zip(grid, grid[1:]):
        tm = (t0_ + t1_) / 2; su_ = D.interp(dy['sun'], tm); sh_ = D.interp(dy['shade'], tm)
        if tm > ss and R == 1: su_ = sh_
        x0_, x1_ = X(t0_), X(t1_) + 0.3
        f.rect(x0_, hy(sh_), x1_, HEAT[1], fill=ZC[D.zone(sh_)] if D.zone(sh_) != 'stop' else HATCH)
        if su_ > sh_ + 0.05:
            z = D.zone(su_)
            f.rect(x0_, hy(su_), x1_, hy(sh_), fill=ZC[z] if z != 'stop' else HATCH)
    sunL = [(X(t), hy(D.interp(dy['sun'], t) if (t <= ss or R >= 2) else D.interp(dy['shade'], t))) for t in grid]
    shL = [(X(t), hy(D.interp(dy['shade'], t))) for t in grid]
    f.line(sunL, BG, 3.2); f.line(sunL, WHITE, 1.6)
    f.line(shL, BG, 3.2); f.line(shL, WHITE, 1.6, dash=(4, 3))
    lx = 13.5
    f.text(X(lx), hy(D.interp(dy['sun'], lx)) - 12, 'Sun', 13, 700, WHITE, 'mm')
    f.text(X(lx), hy(D.interp(dy['shade'], lx)) + 14, 'Shade', 13, 700, WHITE, 'mm')
    # dark hours + sunset mark
    if R == 1:
        f.line([(xs, AX - 12), (xs, HEAT[1])], MUTED, 1)
    else:
        for (a, b) in (SKY, TIDE, (HEAT[0], HEAT[1])):
            lane_ = (LANE if R >= 9 and a in (SKY[0], TIDE[0]) else 0)   # R9: sunset hairline skips header lanes (it cut "Waves normal")
            f.line([(xs, a + lane_), (xs, b)], (154,158,166,150), 1, dash=(2, 2))
    # axis
    for h, lab in [(6, '6a'), (9, '9a'), (12, '12p'), (15, '3p'), (18, '6p'), (21, '9p')]:
        anc = 'la' if h == 6 else 'ra' if h == 21 else 'ma'
        f.text(X(h), AX, lab, 11, 500, MUTED, anc)
    if R == 1:
        sx = f.text(xs, AX, f"sunset {D.fmtt(ss)}", 11, 500, MUTED, 'ma')
    else:
        f.text(xs + 5, HEAT[0] + 8, f"sunset {D.fmtt(ss)}", 11, 500, MUTED, 'lm'); sx = (-99, -98)
    # collision: sunset label vs 6p tick
    six = (X(18) - tw('6p', 11)/2, X(18) + tw('6p', 11)/2)
    if not (sx[1] + 3 < six[0] or sx[0] > six[1] + 3):
        ISSUES.append(f'{name}: "sunset {D.fmtt(ss)}" axis label collides with 6p tick')
        if R >= 2:
            pass
    # now line
    if di == 0 and drag is None:
        if R >= 9:   # R9: the now line skips the text lanes so it never cuts through a header
            for y0_, y1_ in ((SKY[0] + LANE, SKY[1]), (TIDE[0] + LANE, HEAT[0] + 14), (HEAT[0] + 16, AX - 7)):
                f.line([(X(now), y0_), (X(now), y1_)], (255,255,255,140), 1)
        else: f.line([(X(now), SKY[0]), (X(now), AX - 7)], (255,255,255,140), 1)
        f.dot(X(now), hy(D.interp(dy['sun'], now)), 4); f.dot(X(now), hy(D.interp(dy['shade'], now)), 4)
    # ---- header readouts / tracer
    sky_left = [('Clouds', CLOUD), ('Rain', MID)]
    if drag is None:
        x = M + 8
        for t_, c_ in sky_left: x = f.text(x, SKY[0]+12, t_, 12, 600, c_, 'lm')[1] + 6
        if getattr(f, 'stale_tide', False):
            fit_text(f, M+8, TIDE[0]+12, 'Tide · as of yesterday 5:02a · may be out of date', 12, 600, AMBER, CW-16, name, 'stale tide header')
        else:
            fit_text(f, M+8, TIDE[0]+12, tide_head, 12, 600, LAGOON, CW-16, name, 'tide header')
    else:
        if R >= 7: tracer7(f, dy, drag, ty, name, ro, act)
        else: tracer(f, dy, drag, tide_head, ty, name)
    # ---- window ribbon
    wins = D.act_windows(dy, act)
    if low:
        from datetime import datetime as _dt
        lows = [(t.hour + t.minute/60) for t, ft in D.EXT if t.date().isoformat() == dy['date'] and any(e['type'] == 'low' and e['time'][:16] == t.isoformat()[:16] for e in D.D['tides'])]
        eo = [h['energy_offshore_kj'] for h in dy['raw']['hours']]
        lean = []
        for tl in lows:
            a, b = max(D.T0, tl - 2), min(D.T1, tl + 1)
            if b > a and not any(eo[h] > D.D['week']['energy_q3_kj'] for h in range(int(a), int(math.ceil(b)))): lean.append((a, b))
        wins = [(math.ceil(round(max(a, c)*12, 6))/12, math.floor(round(min(b, d)*12, 6))/12) for a, b in wins for c, d in lean if min(b, d) - max(a, c) >= 5/60]
        wins = [(a, D.T1 if b >= D.T1 - 5/60 else b) for a, b in wins]
        ISSUES.append(f'{name}: low tides {[D.fmtt(x) for x in lows]} lean {[D.rng(a,b) for a,b in lean]} -> {[D.label(w) for w in wins] or "No window"}')
    if clip_sun and D.ACT[act][0] == 'sun':
        lim = math.floor((ss + 0.5) * 12) / 12
        wins = [(a, min(b, lim)) for a, b in wins if a < lim - 5/60]
        f.line([(X(lim), HEAT[1] - 30), (X(lim), AX - 7)], (255,255,255,120), 1, dash=(1, 2))
    ribbon(f, wins, AX + 16)
    # key
    ky = 680; x = M
    for z in (50, 40, 30, 20):
        f.rect(x, ky - 6, x + 12, ky + 6, fill=ZC[z], r=2); x = f.text(x + 18, ky, str(z), 13, 500, TEXT, 'lm')[1] + 16
    f.text(M+CW, ky, 'outside min/hr', 12, 500, MUTED, 'rm')
    chips(f, act, 694)
    if act == 'Beach':
        f.text(M, 760, 'Low tide only', 16, 500, TEXT, 'lm')
        f.rect(M+CW-52, 746, M+CW, 774, fill=(MUTED if R >= 6 else (52,199,89)) if low else (60,64,72), r=14)
        kx = M+CW-26 if low else M+CW-50
        f.d.ellipse([kx*S, 748*S, (kx+24)*S, 772*S], fill=WHITE)
    if R == 1:
        pass  # link row removed (proposal)
    f.rect(W/2-67, 860, W/2+67, 865, fill=WHITE, r=3)
    return f.save()

# ---------------- R7+: Sea (G2 shore energy) band on Day + tracer pills ----------------
EMAX = 210.0                      # same y scale as Week Sea G2 (full height = 210 kJ)
def sea_word(es, eo):
    """calm = at-shore energy under the 28.5 kJ calm line (same rule as the calm stretches);
    otherwise the offshore energy against the week quartiles (same words as the Week/day word)."""
    if es < D.THR: return 'calm'
    return 'big' if eo > D.D['week']['energy_q3_kj'] else 'normal'

def sea_at(di, t):
    pts = D.sea(di, t, t + 1e-9)
    return (pts[0][1], pts[0][2]) if pts else (None, None)

def sea_head(dy, di):
    calm = D.calm(di)
    calm_txt = ('Calm ' + ', '.join(D.label(w).replace('From', 'from').replace('Until', 'until') for w in calm)) if calm else 'No calm'
    if R < 8: return f"Sea · {calm_txt} · Waves {dy['wave']}"
    full = f"Sea (model) · {calm_txt} · Waves {dy['wave']}"   # R8: wave word labelled model; ViewThatFits drops the day word if it can't fit
    return full if tw(full, 12, 600) <= cw_head() else f"Sea (model) · {calm_txt}"

def cw_head(): return CW - 16

def sea_band(f, dy, di, tideline=False):
    """G2 on the Day band: fill = energy at the shore (#2F66E0, white 1.3 top line), dotted = offshore,
    lagoon dashes = 28.5 kJ calm line, y 0-210 kJ exactly like Week Sea; white calm bars under the band."""
    from PIL import ImageChops
    ss = dy['sunset']; y0 = TIDE[0] + LANE + XSEA; y1 = TIDE[1] - 1
    f.rect(M, TIDE[0], M+CW, TIDE[1], fill=TRACK, r=12)
    xs = X(ss)
    f.rect(xs, TIDE[0], M+CW-12, TIDE[1], fill=NIGHTSKY)                       # night ground, same as the sky band
    f.rect(M+CW-12, TIDE[0]+12, M+CW, TIDE[1]-12, fill=NIGHTSKY)
    f.d.pieslice([(M+CW-24)*S, TIDE[0]*S, (M+CW)*S, (TIDE[0]+24)*S], 270, 360, fill=NIGHTSKY)
    f.d.pieslice([(M+CW-24)*S, (TIDE[1]-24)*S, (M+CW)*S, TIDE[1]*S], 0, 90, fill=NIGHTSKY)
    pts = D.sea(di)
    def yy(e): return y1 - min(e, EMAX) / EMAX * (y1 - y0)
    poly = [(X(t), yy(es)) for t, es, eo in pts]
    lay = Image.new('RGBA', (W*S, H*S), (0,0,0,0)); ImageDraw.Draw(lay).polygon([(x*S, y*S) for x, y in poly + [(poly[-1][0], TIDE[1]), (poly[0][0], TIDE[1])]], fill=OCEAN + (255,))
    rm = Image.new('L', (W*S, H*S), 0); ImageDraw.Draw(rm).rounded_rectangle([M*S, TIDE[0]*S, (M+CW)*S, TIDE[1]*S], 12*S, fill=255)
    f.im.paste(lay, (0, 0), ImageChops.multiply(lay.split()[3], rm))
    f.line(poly, WHITE, 1.3)
    f.line([(X(t), yy(eo)) for t, es, eo in pts], (255,255,255,178), 1, dash=(2, 2))
    f.line([(M+4, yy(D.THR)), (M+CW-4, yy(D.THR))], LAGOON, 1.2, dash=(4, 3))
    if tideline:   # r7 variant: thin tide height line on its own 0-10 ft scale
        tl = [(X(t), y1 - (D.tide_ft(dy['date'], t)[0] + 0.5) / 10.5 * (y1 - y0)) for t, _, _ in pts]
        f.line(tl, (142,230,238,200), 1.2)
        f.text(X(6.4), tl[5][1] - 8, 'tide ft', 10, 600, LAGOON, 'lm')
    # direct labels (like W4's "reef"): "calm line" over the dashes inside the longest calm stretch, "offshore" under the dots
    calm = D.calm(di)
    if calm:
        a, b = max(calm, key=lambda w: w[1] - w[0]); cx = X((a + b) / 2)
        f.text(cx, yy(D.THR) - 7, 'calm line', 10 if R < 8 else 11, 600, LAGOON, 'mm')
    best = max((p for p in pts if 13.0 <= p[0] <= 16.5), key=lambda p: yy(p[1]) - yy(p[2]))
    if yy(best[1]) - yy(best[2]) > 16:
        f.text(X(best[0]), yy(best[2]) + 8, 'offshore', 10 if R < 8 else 11, 600, (255,255,255,210), 'mm')
    # calm stretches: white 4 pt bars in the gap under the band (G2's white calm ribbon, minus the times; the header carries them)
    for a, b in calm:
        f.rect(X(a), TIDE[1] + 3, X(b), TIDE[1] + 7, fill=WHITE if R < 8 else LAGOON, r=2)   # R8: lagoon, white = activity window
    lookup = {round(t*12): es for t, es, eo in pts}
    def ty(t): return yy(lookup[round(t*12)])
    return ty, sea_head(dy, di)

PILL_H = 18
def pill_items(dy, di, t, unit=None):
    h = int(t); c = dy['cloud'][h]; r = dy['rain'][h]
    v = D.tide_ft(dy['date'], t)[0]; v2 = D.tide_ft(dy['date'], t + 1/60)[0]
    es, eo = sea_at(di, t)
    if v is None or v2 is None: tide = '—'
    else:
        rate = (v2 - v) * 60; tide = f"{v:.1f} ft " + ('turning' if abs(rate) < 0.1 else ('↑' if rate > 0 else '↓'))
    sky = [('Cloud', f'{round(c)}%', '', CLOUD, BG), ('Rain', 'dry' if r == 0 else f'{r:.1f} mm', '', MID, BG)]
    sea = [('', f'{sea_word(es, eo).capitalize()} {round(es)} kJ' if es is not None else '—', 'model', OCEAN, WHITE), ('Tide', tide, '', LAGOON, BG)]
    return sky, sea, es

def pill_w(item, dt=1.0):
    n, v, sfx, _, _ = item; w = 14*dt
    if n: w += tw(n, 12*dt, 600) + 4*dt
    w += tw(v, 13*dt, 700)
    if sfx: w += 4*dt + tw(sfx, 11*dt, 600)
    return w

def place(x, items, cw, dt=1.0, gap=4):
    """centre the pill group on the tracer, clamp 6 pt inside the band. Returns [(x0, x1)] per pill."""
    ws = [pill_w(i, dt) for i in items]; tot = sum(ws) + gap*(len(ws)-1)
    g0 = min(max(x - tot/2, M + 6), M + cw - 6 - tot); out = []; xx = g0
    for w in ws: out.append((xx, xx + w)); xx += w + gap
    if R >= 8 and len(out) > 1:   # R8: the line passes through a pill body (>= 10 pt in), never the gap between pills
        lo, hi = M + 6, M + cw - 6 - tot; ideal = min(max(x - tot/2, lo), hi); best = None; off = 0
        for w in ws:
            a_, b_ = max(x - off - w + 10, lo), min(x - off - 10, hi)
            if a_ <= b_:
                g = min(max(ideal, a_), b_)
                if best is None or abs(g - ideal) < abs(best - ideal): best = g
            off += w + gap
        if best is not None:
            out = []; xx = best
            for w in ws: out.append((xx, xx + w)); xx += w + gap
    return out, tot

def pill_stack(dt):
    """does each band need two pill rows at this text scale on the narrowest phone (375 pt)?"""
    cw = 375 - 2*M; need = [False, False]
    for di in range(7):
        dy = D.day(di)
        for k in range(181):
            sky, sea, _ = pill_items(dy, di, D.T0 + k/12)
            for j, items in enumerate((sky, sea)):
                if place(0, items, cw, dt)[1] > cw - 12: need[j] = True
    return need

def draw_pills(f, x, items, yc, dt, stacked):
    rows = [[i] for i in items] if stacked else [items]
    for k, row in enumerate(rows):
        spans, _ = place(x, row, CW, dt)
        y = yc + k*20*dt
        for (x0, x1), (n, v, sfx, fill, tc) in zip(spans, row):
            ncol = tc
            if R >= 9 and fill == LAGOON:   # R9: tide pill is outlined (lagoon = calm marks); value white, name lagoon
                f.rect(x0, y - PILL_H*dt/2, x1, y + PILL_H*dt/2, fill=(16, 22, 30), outline=LAGOON, r=PILL_H*dt/2, w=1.3); tc = WHITE; ncol = LAGOON
            else:
                f.rect(x0, y - PILL_H*dt/2, x1, y + PILL_H*dt/2, fill=fill, outline=BG, r=PILL_H*dt/2, w=1.5)
            xx = x0 + 7*dt
            if n: xx = f.text(xx, y, n, 12*dt, 600, ncol, 'lm')[1] + 4*dt
            xx = f.text(xx, y, v, 13*dt, 700, tc, 'lm')[1]
            if sfx: f.text(xx + 4*dt, y, sfx, 11*dt, 600, tc if (tc == BG or R >= 9) else (220, 230, 255), 'lm')   # R9: pure white (5.1:1; tint was 4.1:1)

def tracer7(f, dy, t, ty, name, ro, act):
    di = [D.day(i)['date'] for i in range(7)].index(dy['date'])
    x = X(t); sky, sea, es = pill_items(dy, di, t)
    top, bot = f.sky_geom; h = int(t); c = dy['cloud'][h] / 100; r = dy['rain'][h]
    cy_ = bot - c*(bot - top); ry_ = bot - min(1, r)*(bot - top)
    lab = D.fmtt(t)
    if ro == 'card':
        f.line([(x, SKY[0]), (x, AX - 7)], (255,255,255,205), 1)
        f.rect(M, 54, M+CW, 206, fill=(28, 34, 44), outline=CHIPE, r=14, w=1)
        f.text(M+14, 74, lab, 20, 700, WHITE, 'lm')
        rows_ = [('Cloud', f"{sky[0][1]}", CLOUD), ('Rain', sky[1][1], MID), ('Sea', sea[0][1] + ' (model)', LAGOON), ('Tide', sea[1][1], LAGOON)]
        for k, (n, v, col) in enumerate(rows_):
            yy_ = 104 + k*25
            f.text(M+14, yy_, n, 13, 600, col, 'lm'); f.text(M+74, yy_, v, 16, 700, WHITE, 'lm')
        f.text(M+CW-14, 74, 'heat readout below', 11, 500, MUTED, 'rm')
    else:
        if R >= 9 and ro == 'pill':   # R9: the tracer skips the Heat label lane too (it cut through "sunset 5:17p" on evening drags)
            for y0_, y1_ in ((SKY[0] + LANE, SKY[1]), (TIDE[0] + LANE, HEAT[0] + 1), (HEAT[0] + 16, AX - 7)):
                f.line([(x, y0_), (x, y1_)], (255,255,255,205), 1)
        else: f.line([(x, SKY[0] + (LANE if ro == 'pill' else 0)), (x, AX - 7)], (255,255,255,205), 1)
        lw = tw(lab, 15*DT, 700) + 14
        f.rect(M+CW - lw, 179, M+CW, 203 + (4 if DT > 1 else 0), fill=WHITE, r=6)
        f.text(M+CW - lw/2, 191 + (2 if DT > 1 else 0), lab, 15*DT, 700, BG, 'mm')
    if ro == 'pill':
        draw_pills(f, x, sky, SKY[0] + LANE/2, DT, XSKY > 0)
        draw_pills(f, x, sea, TIDE[0] + LANE/2, DT, XSEA > 0)
        # stem: short white tick from the pill row down to the plot so the pill reads as attached to the line
        for ytop in (SKY[0] + LANE/2 + PILL_H*DT/2 + (XSKY), TIDE[0] + LANE/2 + PILL_H*DT/2 + (XSEA)):
            f.line([(x, ytop), (x, ytop + 3)], WHITE, 1.5)
    if ro == 'dots':
        f.line([(x, SKY[0]), (x, SKY[0] + 1)], WHITE, 1)
        side = 1 if x < M + CW*0.55 else -1; anc = 'lm' if side > 0 else 'rm'
        for (txt, yv) in ((f"{sky[0][1]} cloud · rain {sky[1][1]}", cy_), (f"{sea[0][1]} (model) · tide {sea[1][1]}", ty(t))):
            tx = x + side*9
            for dx_ in (-1.2, 0, 1.2):
                for dy__ in (-1.2, 0, 1.2): f.text(tx + dx_, yv - 12 + dy__, txt, 15, 700, BG, anc)
            f.text(tx, yv - 12, txt, 15, 700, WHITE, anc)
    # marker dots where the tracer crosses each mark
    f.dot(x, cy_, 3.5)
    if r > 0: f.dot(x, ry_, 3.5, fill=MID, edge=WHITE)
    f.dot(x, ty(t), 4)
    su, sh = D.interp(dy['sun'], t), D.interp(dy['shade'], t)
    dark = T(su) == T(sh)
    f.dot(x, hy(sh if dark else su), 4)
    if not dark: f.dot(x, hy(sh), 4)

def sweep7(dts=(1.0, 1.29, 1.53)):
    """geometry sweep: every day x every 5 min x 3 phone widths x text scales. Returns issues + widest pill groups."""
    out = []; widest = {}
    for wpt in (402, 393, 375):
        cw = wpt - 2*M
        for dt in dts:
            st = pill_stack(dt) if dt > 1 else [False, False]
            for di in range(7):
                dy = D.day(di)
                for k in range(181):
                    t = D.T0 + k/12; x = M + (t - D.T0) / (D.T1 - D.T0) * cw
                    sky, sea, _ = pill_items(dy, di, t)
                    for j, items in enumerate((sky, sea)):
                        rows = [[i] for i in items] if st[j] else [items]
                        for row in rows:
                            spans, tot = place(x, row, cw, dt)
                            key = (wpt, dt, 'sky' if j == 0 else 'sea'); widest[key] = max(widest.get(key, 0), tot)
                            if spans[0][0] < M + 6 - 1e-6 or spans[-1][1] > M + cw - 6 + 1e-6:
                                out.append(f'{wpt}pt x{dt} {dy["wd"]} {D.fmtt(t)} {key[2]} pill group {tot:.0f}pt leaves the band')
                            # tracer must touch the group (inside it, or within 8 pt of an end at the clamped edges)
                            if not (spans[0][0] - 8 <= x <= spans[-1][1] + 8):
                                out.append(f'{wpt}pt x{dt} {dy["wd"]} {D.fmtt(t)} {key[2]} pills detached from tracer')
                            elif R >= 8 and len(row) > 1 and not any(u + 8 <= x <= v - 8 for u, v in spans) and spans[0][0] - 8 <= x <= spans[-1][1] + 8 and M + 14 < x < M + cw - 14:
                                out.append(f'{wpt}pt x{dt} {dy["wd"]} {D.fmtt(t)} {key[2]} line in the gap between pills')
    return out, widest


def old_tide(f, dy, di):
    f.rect(M, TIDE[0], M+CW, TIDE[1], fill=TRACK, r=12)
    tt = [D.T0 + k/12 for k in range(181)]
    ft = [D.tide_ft(dy['date'], t)[0] for t in tt]
    tb = TIDE[1]; tt0 = TIDE[0] + (6 if R < 3 else 22) + (16*DT if WRAP else 0)   # R3: header lane reserved, water never under the text
    def ty(v): return tb - (v + 0.5) / 10.5 * (tb - tt0)
    pts = [(X(t), ty(v)) for t, v in zip(tt, ft) if v is not None]
    # gradient water
    water = Image.new('RGBA', (W*S, H*S), (0,0,0,0)); wd = ImageDraw.Draw(water)
    for yy in range(int(tt0*S), int(tb*S)):
        p = (yy/S - tt0) / (tb - tt0)
        c = tuple(int(LAGOON[k]*(1-p) + OCEAN[k]*p) if p < .6 else int(MID[k]*0 + OCEAN[k]*(1-(p-.6)/.4) + DEEP[k]*((p-.6)/.4)) for k in range(3))
        wd.line([(M*S, yy), ((M+CW)*S, yy)], fill=c + (255,))
    mask = Image.new('L', (W*S, H*S), 0); md = ImageDraw.Draw(mask)
    md.polygon([(x*S, y*S) for x, y in pts] + [((M+CW)*S, tb*S), (M*S, tb*S)], fill=255)
    rm = Image.new('L', (W*S, H*S), 0); ImageDraw.Draw(rm).rounded_rectangle([M*S, TIDE[0]*S, (M+CW)*S, TIDE[1]*S], 12*S, fill=255)
    from PIL import ImageChops
    f.im.paste(water, (0, 0), ImageChops.multiply(mask, rm))
    f.line(pts, WHITE, 1.3)
    f.line([(M+4, ty(3)), (M+CW-4, ty(3))], (255,255,255,170), 1, dash=(3, 3))
    f.text(M + CW*(0.72 if R < 3 else 0.6), ty(3) - 8, 'reef', 11, 500, (255,255,255,200), 'mm')
    calm = D.calm(di)
    if R == 1:
        tide_head = 'Tide · Calm at shore ' + ' & '.join(D.rng(a, b) if not (b == D.T1) else 'from ' + D.fmtt(a) for a, b in calm) + f" · Waves {dy['wave']}"
    else:
        tide_head = 'Tide · ' + ('Calm ' + ', '.join(D.label(w).replace('From', 'from').replace('Until', 'until') for w in calm) if calm else 'No calm') + f" · Waves {dy['wave']}"
    return ty, tide_head

def fit_text(f, x, y, t, sz, wt, col, maxw, name, what):
    w = tw(t, sz, wt)
    if w > maxw:
        sc = maxw / w
        ISSUES.append(f'{name}: {what} {w:.0f}pt > {maxw:.0f}pt; needs scale {sc:.2f}' + (' (below 0.65 floor → truncates)' if sc < 0.65 else ''))
        sz = max(sz*0.65, sz*sc)
    return f.text(x, y, t, sz, wt, col, 'lm')

def readouts(dy, t, unit='F'):
    h = int(t); ss = dy['sunset']
    c = dy['cloud'][h]; r = dy['rain'][h]
    v, dv, p = D.tide_ft(dy['date'], t); v2 = D.tide_ft(dy['date'], t + 1/60)[0]
    rate = (v2 - v) * 60
    direction = '↑' if rate > 0 else '↓'
    turning = abs(rate) < 0.1
    rain = 'dry' if r == 0 else f'{r:.1f} mm/hr'
    return dict(cloud=None if (t > ss and R == 1) else f'{round(c)}%', rain=rain, ft=v, dirn=direction, turning=turning,
                wave=dy['wave'], sun=D.interp(dy['sun'], t), shade=D.interp(dy['shade'], t),
                dark=(t > ss) if R == 1 else (T(D.interp(dy['sun'], t)) == T(D.interp(dy['shade'], t))))

def tracer(f, dy, t, tide_head, ty, name):
    ro = readouts(dy, t); x = X(t)
    # line through all three bands, stops 7 pt above axis
    top = SKY[0] - (0 if R == 1 else 0)
    f.line([(x, top), (x, AX - 7)], (255,255,255,205), 1)
    # time label on top
    lab = D.fmtt(t)
    if R == 1:
        f.text(min(max(x, M + tw(lab,13,600)/2), M+CW - tw(lab,13,600)/2), SKY[0] - 8, lab, 13, 600, WHITE, 'mb')
    tide_ro = (f"{ro['ft']:.1f} ft " + ('· turning' if ro['turning'] else ro['dirn']))
    if R == 1:
        # proposal: header left text stays, right side swaps to readout
        xl = M + 8
        for t_, c_ in [('Clouds', CLOUD), ('Rain', MID)]: xl = f.text(xl, SKY[0]+12, t_, 12, 600, c_, 'lm')[1] + 6
        sky_ro = ' '.join(v for v in [ro['cloud'], ro['rain']] if v)
        xr = f.text(M+CW-8, SKY[0]+12, sky_ro, 13, 600, WHITE, 'rm')
        if xr[0] < xl: ISSUES.append(f'{name}: sky readout overlaps header')
        tl = f.text(M+8, TIDE[0]+12, tide_head, 12, 600, LAGOON, 'lm')
        tr_txt = tide_ro + f" · waves {ro['wave']} (model)"
        tr = f.text(M+CW-8, TIDE[0]+30, tr_txt, 13, 600, WHITE, 'rm') if False else None
        # place on header line as specced → measure overlap
        need = tw(tide_head, 12, 600) + 8 + tw(tr_txt, 13, 600)
        ISSUES.append(f'{name}: tide header {tw(tide_head,12,600):.0f}pt + readout {tw(tr_txt,13,600):.0f}pt = {need:.0f}pt in {CW-16}pt → overlap {need-(CW-16):.0f}pt')
        f.rect(M+CW-8-tw(tr_txt,13,600)-4, TIDE[0]+4, M+CW-4, TIDE[0]+21, fill=(10,14,20,170), r=4)
        f.text(M+CW-8, TIDE[0]+12, tr_txt, 13, 600, WHITE, 'rm')
        # heat readout already in top row; dots
    else:
        # R2+: whole header line swaps: band name kept as first word, readout follows (left aligned)
        a12, a13 = 12*DT, 13*DT; l2 = 16*DT if WRAP else 0
        tcol = AMBER if getattr(f, 'stale_tide', False) else LAGOON
        xl = M + 8
        xl = f.text(xl, SKY[0]+12, 'Clouds', a12, 600, CLOUD, 'lm')[1] + 5
        xl = f.text(xl, SKY[0]+12, ro['cloud'] if ro['cloud'] else '—', a13, 700, WHITE, 'lm')[1] + 12
        if WRAP: xl = M + 8
        xl = f.text(xl, SKY[0]+12+l2, 'Rain', a12, 600, MID, 'lm')[1] + 5
        xl = f.text(xl, SKY[0]+12+l2, ro['rain'], a13, 700, WHITE, 'lm')[1]
        tl = M + 8
        tl = f.text(tl, TIDE[0]+12, 'Tide', a12, 600, tcol, 'lm')[1] + 5
        tl = f.text(tl, TIDE[0]+12, tide_ro, a13, 700, WHITE, 'lm')[1] + 12
        if WRAP: tl = M + 8
        tl = f.text(tl, TIDE[0]+12+l2, 'Waves', a12, 600, LAGOON, 'lm')[1] + 5
        tl = f.text(tl, TIDE[0]+12+l2, ro['wave'], a13, 700, WHITE, 'lm')[1] + 5
        tl = f.text(tl, TIDE[0]+12+l2, '(model)', a12, 500, LAGOON, 'lm')[1]
        for nm, endx in (('sky', xl), ('tide', tl)):
            for wpt in (402, 393, 375):
                if endx - M > (wpt - 2*M) - 16: ISSUES.append(f'{name}: {nm} readout {endx-M:.0f}pt too wide at {wpt}pt screen')
        # time label: R2 floats over line top (in gap above sky band); R3 in readout row right
        if R == 2:
            bad = []
            for k in range(181):
                tt_ = D.T0 + k/12; lab_ = D.fmtt(tt_); lw_ = tw(lab_, 13, 700) + 12
                cx_ = min(max(X(tt_), M + lw_/2), M+CW - lw_/2)
                if cx_ - lw_/2 < M + 170: bad.append(lab_)
            if bad: ISSUES.append(f'{name}: time pill sits under the 24pt readout row (pill y193–210 vs row y179–203) from {bad[0]} to {bad[-1]}')
            lw = tw(lab, 13, 700) + 12; cx = min(max(x, M + lw/2), M+CW - lw/2)
            f.rect(cx - lw/2, SKY[0] - 19, cx + lw/2, SKY[0] - 2, fill=WHITE, r=5)
            f.text(cx, SKY[0] - 10.5, lab, 13, 700, BG, 'mm')
        else:
            lw = tw(lab, 15*DT, 700) + 14
            f.rect(M+CW - lw, 179, M+CW, 203 + (4 if DT > 1 else 0), fill=WHITE, r=6)
            f.text(M+CW - lw/2, 191 + (2 if DT > 1 else 0), lab, 15*DT, 700, BG, 'mm')
    # dots
    f.dot(x, ty(ro['ft']), 4)
    su = ro['shade'] if ro['dark'] else ro['sun']
    f.dot(x, hy(su), 4)
    if not ro['dark']: f.dot(x, hy(ro['shade']), 4)

def ribbon(f, wins, y, h=24, big=22):
    if not wins:
        f.text(M, y + h/2, 'No window', 15, 600, MUTED, 'lm'); return
    for w in wins:
        lab = D.label(w); x0, x1 = X(w[0]), X(w[1])
        need = tw(lab, big, 700) + 16
        if x1 - x0 >= need:
            f.rect(x0, y, x1, y + h, fill=WHITE, r=6); f.text((x0+x1)/2, y + h/2 + 0.5, lab, big, 700, BG, 'mm')
        else:
            # thin ribbon on the axis + label pill clamped inside screen
            f.rect(x0, y, x1, y + 4, fill=WHITE, r=2)
            cx = min(max((x0+x1)/2, M + need/2), M+CW - need/2)
            if R >= 2:
                f.rect(cx - need/2, y + 6, cx + need/2, y + h + 2, fill=WHITE, r=6); f.text(cx, y + h/2 + 4, lab, big*0.82, 700, BG, 'mm')
            else:
                f.rect(cx - need/2, y + 2, cx + need/2, y + h, fill=WHITE, r=6); f.text(cx, y + h/2 + 1, lab, big*0.8, 700, BG, 'mm')

def chips(f, act, y):
    names = ['Beach', 'Soccer sun', 'Soccer shade', 'Pool', 'Jungle']
    widths = [62, 80, 80, 54, 68]
    if R >= 8 and CW < sum(widths) + 4*4: widths = [w_ * (CW - 16) / sum(widths) for w_ in widths]   # R8: 375 pt fix (chips summed 344 pt in 343)
    gap = (CW - sum(widths)) / 4; x = M
    for n, w in zip(names, widths):
        sel = n == act
        f.rect(x, y, x+w, y+40, fill=CHIPF if sel else None, outline=CHIPE, r=20, w=1)
        parts = n.split(' ')
        if len(parts) == 2:
            f.text(x+w/2, y+13, parts[0], 13, 600, TEXT, 'mm'); f.text(x+w/2, y+28, parts[1], 13, 600, TEXT, 'mm')
        else: f.text(x+w/2, y+20, n, 13, 600, TEXT, 'mm')
        x += w + gap

# ---------------- Week ----------------
TABS = ['Heat', 'Rain', 'Cloud', 'Sea']
def week_head(f, tab):
    chrome(f, week=True, date='11–17 NOV')
    f.rect(M, 178, M+CW, 214, fill=(22,27,35), r=12)
    tw_ = CW / 4
    for i, t in enumerate(TABS):
        if t == tab: f.rect(M + i*tw_ + 3, 181, M + (i+1)*tw_ - 3, 211, fill=(40,46,56), r=10)
        f.text(M + i*tw_ + tw_/2, 196, t, 15, 600, TEXT if t == tab else MUTED, 'mm')

def row_geom(top, bottom, n=7):
    return [(top + i*(bottom-top)/n, top + (i+1)*(bottom-top)/n) for i in range(n)]

def week_axis(f, y, ss=None):
    for h, lab in [(6, '6a'), (9, '9a'), (12, '12p'), (15, '3p'), (18, '6p'), (21, '9p')]:
        anc = 'la' if h == 6 else 'ra' if h == 21 else 'ma'
        f.text(X(h), y, lab, 11, 500, MUTED, anc)

def day_label(f, i, y, value, vcol=None):
    dy = D.day(i); muted = i >= 3
    lab = f"{dy['wd']} {int(dy['date'][-2:])}"
    f.text(M, y, lab, 14, 600, MUTED if muted else TEXT, 'lm')
    xr = M + CW - (14 if R >= 2 else 0)
    if value: f.text(xr, y, value, 13, 500 if R == 1 else 600, vcol or (MUTED if muted else TEXT), 'rm')
    if R >= 2: f.text(M + CW, y, '›', 17, 500, (154,158,166,170), 'rm')

def strip_night(f, i, y0, y1):
    ss = D.day(i)['sunset']
    if R == 1: f.rect(X(ss), y0, M+CW, y1, fill=BG)
    else: f.line([(X(ss), y0), (X(ss), y1)], (154,158,166,140), 1, dash=(2, 2))

def week_rain(name, title):
    f = Frame(name, title); week_head(f, 'Rain')
    f.text(M+CW, 232, 'full bar = 1 mm/hr', 12, 500, MUTED, 'rm')
    rows = row_geom(244, 830 if R >= 2 else 822)
    for i, (a, b) in enumerate(rows):
        dy = D.day(i); r = dy['rain']; tot = sum(r); outside = tot - sum(r[6:21])
        val = 'dry' if tot < 0.05 else f'{tot:.1f} mm'
        if tot > 0 and outside / tot >= 0.4: val += f' · {outside:.1f} overnight'
        lh = 18; sy0 = a + lh + 2; sy1 = b - 10
        day_label(f, i, a + lh/2, val)
        f.rect(M, sy0, M+CW, sy1, fill=TRACK, r=4)
        strip_night(f, i, sy0, sy1)
        f.line([(M, sy0), (M+CW, sy0)], (255,255,255,30), 1)
        for h in range(6, 21):
            v = r[h]
            if v <= 0: continue
            x0, x1 = X(h) + 1, X(h+1) - 1; hh = min(1, v) * (sy1 - sy0)
            col = MID if i < 3 else (40, 100, 135)
            f.rect(x0, sy1 - hh, x1, sy1, fill=col)
            if v > 1: f.text((x0+x1)/2, sy1 - hh + 7, f'{v:.1f}', 9, 700, WHITE, 'mm')
    week_axis(f, rows[-1][1] + 2)
    return f.save()

def week_cloud(name, title):
    f = Frame(name, title); week_head(f, 'Cloud')
    f.text(M+CW, 232, 'full bar = 100% cloud' + (' · % = daylight average' if R >= 3 else ''), 12, 500, MUTED, 'rm')
    rows = row_geom(244, 830 if R >= 2 else 822)
    for i, (a, b) in enumerate(rows):
        dy = D.day(i); ss = dy['sunset']
        lh = 18; sy0 = a + lh + 2; sy1 = b - 10
        day_label(f, i, a + lh/2, f"{dy['cloudmean']}%")
        f.rect(M, sy0, M+CW, sy1, fill=TRACK, r=4)
        strip_night(f, i, sy0, sy1)
        f.line([(M, sy0), (M+CW, sy0)], (255,255,255,30), 1)
        for h in range(6, 21):
            if h >= ss and R == 1: continue
            x0, x1 = X(h) + 1, X(h+1) - 1
            if h < ss < h + 1 and R == 1: x1 = X(ss) - 1
            c = dy['cloud'][h] / 100
            col = CLOUD if i < 3 else (110, 114, 122)
            if h + 0.5 >= ss: col = (90, 94, 102) if i < 3 else (60, 64, 70)
            f.rect(x0, sy1 - c*(sy1-sy0), x1, sy1, fill=col)
    week_axis(f, rows[-1][1] + 2)
    return f.save()

def week_heat(name, title, act='Beach'):
    f = Frame(name, title); week_head(f, 'Heat')
    rows = row_geom(226 if R < 4 else 222, 664 if R < 3 else (690 if R < 4 else 704))
    for i, (a, b) in enumerate(rows):
        dy = D.day(i); ss = dy['sunset']; muted = i >= 3
        wins = D.act_windows(dy, act)
        lh = 18; by0 = a + lh + 2; by1 = by0 + (18 if R < 3 else 16)
        labs = '  '.join(D.label(w).lower() if R >= 2 else '' for w in wins) if wins else 'no window'
        day_label(f, i, a + lh/2, labs if R == 2 else (None if wins else 'no window'))
        key = 'sun' if act in ('Beach', 'Soccer sun', 'Pool') else 'shade'
        for k in range(180):
            t = D.T0 + (k + .5)/12; v = D.interp(dy[key] if t <= ss else dy['shade'], t)
            z = D.zone(v); col = ZC[z] if z != 'stop' else HATCH
            if muted: col = tuple(int(c*0.45 + BG[j]*0.55) for j, c in enumerate(col))
            f.rect(X(D.T0 + k/12), by0, X(D.T0 + (k+1)/12) + .4, by1, fill=col)
            if z == 'stop':
                xx = X(D.T0 + k/12)
                f.line([(xx, by1), (xx + 6, by0)], HATCHL, .8)
        strip_night(f, i, by0 - 2, by1 + 2)
        # S2 ribbon
        for w in wins:
            x0, x1 = X(w[0]), X(w[1]); lab = D.label(w); need = tw(lab, 17, 700) + 12
            if R != 2:
                bx0 = min(x0, M + CW - need); bx1 = max(x1, bx0 + need)
                f.rect(bx0, by1 + 4, bx1, by1 + 26, fill=WHITE if not muted else (200,200,200), r=6); f.text(bx0 + 6, by1 + 15, lab, 17, 700, BG, 'lm')
            else:
                f.rect(x0, by1 + 3, x1, by1 + 8, fill=WHITE if not muted else (170,170,170), r=2)
    week_axis(f, rows[-1][1] - (8 if R == 2 else 4) + (8 if R >= 3 else 0))
    ky = 690 if R < 3 else (722 if R < 4 else 734); x = M
    for z in (50, 40, 30, 20):
        f.rect(x, ky - 6, x + 12, ky + 6, fill=ZC[z], r=2); x = f.text(x + 18, ky, str(z), 13, 500, TEXT, 'lm')[1] + 16
    f.text(M+CW, ky, 'outside min/hr', 12, 500, MUTED, 'rm')
    oy = 0 if R < 3 else (30 if R < 4 else 42)
    chips(f, act, 706 + oy)
    f.text(M, 772 + oy, 'Low tide only', 16, 500, TEXT, 'lm')
    f.rect(M+CW-52, 758+oy, M+CW, 786+oy, fill=(60,64,72), r=14); f.d.ellipse([(M+CW-50)*S, (760+oy)*S, (M+CW-26)*S, (784+oy)*S], fill=WHITE)
    return f.save()

def week_sea(name, title):
    f = Frame(name, title); week_head(f, 'Sea')
    f.text(M+CW, 232, 'full height = 210 kJ', 12, 500, MUTED, 'rm')
    rows = row_geom(244, 790 if R < 3 else 778)
    for i, (a, b) in enumerate(rows):
        dy = D.day(i); muted = i >= 3
        calm = D.calm(i)
        lh = 18; sy0 = a + lh + 2; sy1 = b - 22
        val = '  '.join(D.label(w).lower() for w in calm) if calm else 'no calm'
        day_label(f, i, a + lh/2, None if R != 2 else ('calm ' + val if calm else val))
        f.rect(M, sy0, M+CW, sy1, fill=TRACK, r=4)
        pts = D.sea(i)
        def yy(e): return sy1 - min(e, 210) / 210 * (sy1 - sy0)
        poly = [(X(t), yy(es)) for t, es, eo in pts]
        fill = OCEAN if not muted else (28, 60, 130)
        f.poly(poly + [(poly[-1][0], sy1), (poly[0][0], sy1)], fill)
        f.line(poly, WHITE if not muted else (150,150,150), 1.3)
        f.line([(X(t), yy(eo)) for t, es, eo in pts], (255,255,255,150), 1, dash=(2, 2))
        f.line([(M, yy(D.THR)), (M+CW, yy(D.THR))], LAGOON, 1.2, dash=(4, 3))
        strip_night(f, i, sy0, sy1)
        for w in calm:
            x0, x1 = X(w[0]), X(w[1])
            if R != 2:
                lab = D.label(w); need = tw(lab, 11.5, 800) + 12
                cx = min(max((x0+x1)/2, M+need/2), M+CW-need/2)
                f.rect(min(x0, cx-need/2), sy1 + 4, max(x1, cx+need/2), sy1 + 19, fill=WHITE, r=4)
                f.text(cx, sy1 + 11.5, lab, 11.5, 800, BG, 'mm')
            else:
                f.rect(x0, sy1 + 3, x1, sy1 + 8, fill=WHITE if not muted else (170,170,170), r=2)
    week_axis(f, rows[-1][1] - 12 + (12 if R >= 3 else 0))
    f.text(M, 800, 'fill = energy at the shore · dotted = offshore · dashes = calm line', 11, 500, MUTED, 'lm')
    f.text(M, 816, 'model, not measured · reef size and gaps guessed', 11, 500, MUTED, 'lm')
    return f.save()

# ---------------- i sheet ----------------
def isheet(name, title, unit='F'):
    f = Frame(name, title)
    base = today('_bg', '', act='Beach', unit=unit).im
    f.im.paste(base); f.rect(0, 0, W, H, fill=(0,0,0,140))
    top = 470 if R >= 2 else 430
    f.rect(0, top, W, H + 20, fill=(28, 30, 36), r=16)
    f.rect(W/2-18, top+6, W/2+18, top+11, fill=(90,94,100), r=3)
    f.text(M+4, top + 34, 'Sámara Conditions', 17, 700, TEXT, 'lm')
    f.text(M+CW-4, top + 34, 'Done', 17, 600, MID if R == 1 else TEXT, 'rm')
    rows = [('Sources & method', '›'), ('Units' if R == 1 else 'Temperature', 'SEG'), ('Export log', '›')]
    y = top + 62
    f.rect(M, y, M+CW, y + 3*48, fill=(40, 43, 50), r=12)
    for k, (lab, kind) in enumerate(rows):
        cy = y + 24 + k*48
        f.text(M+16, cy, lab, 17, 500, TEXT, 'lm')
        if kind == '›': f.text(M+CW-14, cy, '›', 20, 500, MUTED, 'rm')
        else:
            sw = 104; sx = M+CW-12-sw
            f.rect(sx, cy-15, sx+sw, cy+15, fill=(58, 61, 68), r=8)
            selx = sx + 2 if unit == 'F' else sx + sw/2
            f.rect(selx, cy-13, selx + sw/2 - 2, cy+13, fill=(99, 102, 110), r=7)
            f.text(sx + sw/4, cy, '°F', 15, 600, TEXT, 'mm'); f.text(sx + 3*sw/4, cy, '°C', 15, 600, TEXT, 'mm')
        if k < 2: f.line([(M+16, cy+24), (M+CW, cy+24)], (70, 73, 80), .6)
    if R == 2:
        f.text(M+8, y + 3*48 + 18, 'Temperature changes the numbers only. Heat colours and', 12, 500, MUTED, 'lm')
        f.text(M+8, y + 3*48 + 34, 'windows stay the same. Tide stays in feet, rain in mm.', 12, 500, MUTED, 'lm')
    if R >= 3:
        f.text(M+8, y + 3*48 + 18, 'Numbers only. Colours, windows, tide ft and rain mm stay.', 12, 500, MUTED, 'lm')
    return f.save()

# ---------------- run ----------------
if R < 7:
    frames = []
    frames.append(today('01-today-rest', 'Today at rest · Beach · now 12:47p'))
    frames.append(today('02-drag-3p', 'Dragging · 3:05p', drag=15 + 5/60))
    frames.append(today('03-drag-7p', 'Dragging · 7:00p (after dark)', drag=19.0))
    frames.append(today('04-jungle-allday', 'Jungle · "All day"', act='Jungle'))
    if R >= 2:
        frames.append(today('05-day-fri', 'Day view · Fri 13 (from Week row tap)', di=2, act='Beach'))
    frames.append(week_heat('06-week-heat', 'Week · Heat (Beach)'))
    frames.append(week_rain('07-week-rain', 'Week · Rain'))
    frames.append(week_cloud('08-week-cloud', 'Week · Cloud'))
    frames.append(week_sea('09-week-sea', 'Week · Sea (layout only)'))
    frames.append(isheet('10-isheet', 'i sheet', unit='C' if R >= 4 else 'F'))
    if R >= 4:
        frames.append(today('11-drag-9a', 'Dragging · 9:00a (morning case)', drag=9.0))
        frames.append(today('12-drag-3p-C', 'Dragging · 3:05p · °C', drag=15 + 5/60, unit='C'))
        frames.append(today('13-soccer-sun', 'Soccer sun · dark-hour window', act='Soccer sun'))
    if R >= 5:
        frames.append(today('16-dyntype-xxl', 'Dynamic Type xxLarge (×1.29) · drag 3:05p', drag=15 + 5/60, dt=1.29))
        frames.append(today('14-beach-clipB', 'Option B · sun windows end sunset+30', clip_sun=True))
        pass
    if R >= 6:
        frames.append(today('17-lowtide-nowindow', 'Beach · Low tide only · lands at 8:05p in the dark', low=True))
    if R >= 5:
        frames.append(today('15-stale-tide-drag', 'Stale tide block · dragging 3:05p', drag=15 + 5/60, stale_tide=True))

else:
    frames = []
    frames.append(today('01-day-rest', 'Day at rest · Beach · now 12:47p'))
    frames.append(today('02-drag-9a', 'Drag 9:00a', drag=9.0))
    frames.append(today('03-drag-3p', 'Drag 3:05p', drag=15 + 5/60))
    frames.append(today('04-drag-7p', 'Drag 7:00p (after dark)', drag=19.0))
    if R == 7:
        frames.append(today('05-optB-dots', 'Option B · dots + big values · 3:05p', drag=15 + 5/60, ro='dots'))
        frames.append(today('06-optC-card', 'Option C · one stacked card · 3:05p', drag=15 + 5/60, ro='card'))
        frames.append(today('07-rest-tideline', 'Variant · thin tide line kept', tideline=True))
    if R >= 8:
        frames.append(today('05-fri-drag-11a', 'Fri 13 · big swell, calm at shore · drag 11:00a', di=2, drag=11.0))
        frames.append(today('06-xxl-drag-3p', 'xxLarge text (×1.29) · drag 3:05p', drag=15 + 5/60, dt=1.29))
        frames.append(today('07-lowtide', 'Beach · Low tide only', low=True))
        frames.append(today('08-drag-3p-C', 'Drag 3:05p · °C', drag=15 + 5/60, unit='C'))
    if R >= 9:
        frames.append(today('09-xxxl-drag-9a', 'xxxLarge text (×1.53) · drag 9:00a', drag=9.0, dt=1.53))
        frames.append(isheet('10-isheet', 'i sheet (°F)', unit='F'))
        frames.append(today('11-jungle-allday', 'Jungle · "All day"', act='Jungle'))
        frames.append(today('12-day-fri', 'Fri 13 (Week row tap)', di=2))
        frames.append(today('13-soccer-sun', 'Soccer sun · dark-hour window', act='Soccer sun'))
        frames.append(today('14-beach-clipB', 'Option B · sun windows end sunset+30', clip_sun=True))
        frames.append(week_heat('15-week-heat', 'Week · Heat (Beach)'))
        frames.append(week_rain('16-week-rain', 'Week · Rain'))
        frames.append(week_cloud('17-week-cloud', 'Week · Cloud'))
        frames.append(week_sea('18-week-sea', 'Week · Sea (layout only)'))
    frames.append(today('_bg', ''))
    iss, widest = sweep7()
    ISSUES.extend(iss[:40] + ([f'... {len(iss)-40} more'] if len(iss) > 40 else []))
    for k_, v_ in sorted(widest.items()): ISSUES.append(f'widest pill group {k_}: {v_:.0f}pt (band {k_[0]-2*M-12}pt usable)')
    for di_ in range(7):
        h_ = sea_head(D.day(di_), di_); w_ = tw(h_, 12, 600)
        full_ = h_ if R < 8 else h_.replace(' · Waves ' + D.day(di_)['wave'], '') + ' · Waves ' + D.day(di_)['wave']
        for wpt_ in (402, 393, 375):
            fw_ = tw(full_, 12, 600); us_ = wpt_ - 2*M - 16
            if fw_ > us_: ISSUES.append(f'rest header {D.day(di_)["wd"]} @{wpt_}: "{full_}" {fw_:.0f}pt > {us_}pt' + (' -> ViewThatFits drops the day word' if R >= 8 else ' OVER'))
os.remove(f'{OUT}/frames/_bg.png')

def sheet(frames, path, title):
    sc = 0.5; fw, fh = int(W*S*sc), int(H*S*sc); cols = 5
    rows_ = math.ceil(len(frames) / cols); pad = 24; th = 34
    sh = Image.new('RGB', (cols*(fw+pad)+pad, 70 + rows_*(fh+th+pad)), (232, 232, 228))
    d = ImageDraw.Draw(sh)
    d.text((pad, 20), title, font=ImageFont.truetype(INTER, 26), fill=(20,20,20))
    for k, fr in enumerate(frames):
        cx = pad + (k % cols)*(fw+pad); cy = 70 + (k // cols)*(fh+th+pad)
        d.text((cx, cy+6), fr.title, font=ImageFont.truetype(INTER, 17), fill=(30,30,30))
        sh.paste(fr.im.resize((fw, fh), Image.LANCZOS), (cx, cy+th))
    sh.save(path)
sheet(frames, f'{OUT}/sheet.png', f'Sámara build-4 UX · round {R} · real fixture Wed 11–Tue 17 Nov 2026 · 402 pt frames')
open(f'{OUT}/issues.txt', 'w').write('\n'.join(ISSUES) + '\n')
print('\n'.join(ISSUES))
