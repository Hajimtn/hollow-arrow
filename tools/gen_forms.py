"""Evolved boss forms (phase 2 / phase 3). Each is the phase-1 sprite plus extra armour so the silhouette is recognisably the same creature."""
import gen_bosses as gb
from pix import *

OL = gb.OL


def base(fn, *a, **k):
    gb.OUTLINE_ON = False
    try:
        return fn(*a, **k)
    finally:
        gb.OUTLINE_ON = True


def canvas_with(base_cv, w, h, ox, oy):
    cv = Cv(w, h)
    cv.paste(base_cv, ox, oy)
    return cv


def tint(cv, col, t):
    for y in range(cv.h):
        for x in range(cv.w):
            c = cv.p[x, y]
            if c[3] > 0:
                cv.p[x, y] = mix(c, col, t)[:3] + (c[3],)


def shard(cv, pts, pal):
    cv.poly(pts, pal[1])
    cv.line(pts[0][0], pts[0][1], pts[1][0], pts[1][1], pal[2])


# ---------------------------------------------------------------- KNIGHT
def knight_form(form):
    CR = tri('7ad0ff'); PU = tri('a878ff')
    pal = CR if form == 2 else PU
    cv = canvas_with(base(gb.knight, form == 2), 72, 72, 8, 8)
    if form == 3:
        tint(cv, (70, 40, 120, 255), 0.22)
    # pauldron crystals
    k = 1.0 if form == 2 else 1.5
    for sgn, cy in ((-1, 22), (1, 50)):
        shard(cv, [(28, cy), (24 - 2 * k, cy + sgn * 18 * k), (36, cy + sgn * 3)], pal)
        shard(cv, [(36, cy + sgn * 3), (40, cy + sgn * 20 * k), (44, cy)], pal)
    # cape crystals
    for (y, ln) in ((28, 14), (36, 18), (44, 14)):
        shard(cv, [(14, y - 3), (14 - ln * (1 if form == 2 else 1.4), y), (14, y + 4)], pal)
    if form == 2:
        # bigger, spikier shield
        for (y0, dy) in ((14, -8), (26, -4), (46, 4), (58, 8)):
            shard(cv, [(56, y0), (68, y0 + dy), (58, y0 + 6)], CR)
        for seg in (((52, 30), (58, 42)), ((30, 34), (36, 46)), ((44, 24), (48, 16))):
            cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], C('e8ffff'))
    else:
        # swept-back horns and a floating prism halo
        shard(cv, [(40, 28), (26, 12), (14, 2), (26, 18), (34, 32)], PU)
        shard(cv, [(40, 44), (26, 60), (14, 70), (26, 54), (34, 40)], PU)
        for a in range(0, 360, 60):
            x = 36 + 31 * math.cos(math.radians(a + 20)); y = 36 + 31 * math.sin(math.radians(a + 20))
            cv.poly([(x, y - 4), (x + 3, y), (x, y + 4), (x - 3, y)], PU[2])
        cv.rect(46, 33, 8, 2, C('ff5a6a'))                     # visor
        cv.blob(17, 36, 6, 7, tri('ffffff'))                  # back core socket
        cv.blob(17, 36, 3, 4, tri('c8f0ff'))
        for seg in (((34, 30), (30, 40)), ((44, 44), (50, 52)), ((24, 24), (30, 30))):
            cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], C('e8ffff'))
    cv.outline(OL)
    return cv


def mirror_plate():
    """one orbiting prism plate (faces +x)"""
    cv = Cv(12, 30)
    P = tri('b898ff')
    cv.poly([(2, 2), (10, 6), (10, 24), (2, 28), (5, 15)], P[1])
    cv.poly([(2, 2), (10, 6), (8, 15), (5, 15)], P[2])
    cv.line(9, 8, 9, 22, C('f4ecff'))
    cv.outline(OL)
    return cv


# ---------------------------------------------------------------- BURROWER
def burrower_form(form, open_):
    cv = canvas_with(base(gb.burrower, open_), 104, 88, 8, 8)
    BONE = tri('d8ccb0'); HOT = tri('ff9a30'); WH = tri('ffe9a0'); DK = tri('4a3424')
    k = 1.0 if form == 2 else 1.5
    for x in (46, 58, 70, 82):
        shard(cv, [(x - 5, 32), (x, 32 - 18 * k), (x + 5, 32)], BONE)
    for (x, y) in ((18, 54), (30, 52), (44, 48)):
        shard(cv, [(x - 4, y), (x, y - 14 * k), (x + 4, y)], BONE)
    for (x, y) in ((18, 54), (30, 52), (44, 48)):                 # underside spikes mirror the top
        shard(cv, [(x - 4, 88 - y), (x, 88 - y + 12 * k), (x + 4, 88 - y)], DK)
    # dorsal crest = the phase-2 weak point housing
    crest = HOT if form == 2 else WH
    cv.poly([(54, 32), (57, 8 - (6 if form == 3 else 0)), (66, 5 - (6 if form == 3 else 0)), (70, 32)], HOT[1])
    cv.poly([(57, 8), (66, 5), (64, 30), (58, 30)], crest[2])
    cv.line(62, 10, 62, 28, C('ffffff'))
    for seg in (((40, 40), (34, 52)), ((60, 48), (70, 58)), ((48, 30), (44, 40))):
        cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], HOT[1])
    if form == 3:
        shard(cv, [(78, 28), (96, 8), (102, 2), (92, 16), (84, 34)], tri('8a5a3a'))
        shard(cv, [(78, 60), (96, 80), (102, 86), (92, 72), (84, 54)], tri('8a5a3a'))
        cv.rect(62, 40, 4, 3, C('ff3a3a')); cv.rect(62, 58, 4, 3, C('ff3a3a'))
        for seg in (((30, 44), (22, 52)), ((72, 36), (80, 44)), ((50, 62), (56, 70))):
            cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], WH[1])
        if open_:
            for a in range(0, 360, 30):
                cv.px(74 + 15 * math.cos(math.radians(a)), 48 + 18 * math.sin(math.radians(a)), C('ffe070'))
            cv.blob(74, 48, 5, 6, tri('ffb040')); cv.blob(74, 48, 2.5, 3, tri('ffffff'))
    cv.outline(OL)
    return cv


# ---------------------------------------------------------------- COLOSSUS
def colossus_form(form, open_):
    cv = canvas_with(base(gb.colossus, open_ and form == 3), 176, 140, 16, 14)
    ST = tri('6c6878'); DK = tri('3e3a4a'); HOT = tri('ff9a30'); WH = tri('ffe9a0'); GEM = tri('ff8a20')
    k = 1.0 if form == 2 else 1.5
    # shoulder spikes
    for cx in (40, 136):
        for dx, h in ((-8, 22), (2, 30), (12, 22)):
            shard(cv, [(cx + dx - 5, 58), (cx + dx, 58 - h * k), (cx + dx + 5, 58)], ST)
    # head crown of spikes
    for dx, h in ((-14, 10), (-6, 16), (2, 20), (10, 16), (18, 10)):
        shard(cv, [(88 + dx - 3, 34), (88 + dx, 34 - h * k), (88 + dx + 3, 34)], DK)
    # cracks
    hot = HOT[1] if form == 2 else WH[1]
    for seg in (((70, 60), (62, 80)), ((62, 80), (72, 96)), ((106, 62), (114, 84)), ((88, 96), (92, 110)), ((50, 70), (42, 86))):
        cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], hot)
    if form == 2:
        # shoulder gems (the phase-2 weak points) - big orange crystals
        for gx in (36, 140):
            cv.poly([(gx - 8, 62), (gx - 5, 44), (gx, 38), (gx + 5, 44), (gx + 8, 62)], GEM[1])
            cv.poly([(gx - 5, 44), (gx, 38), (gx + 1, 60), (gx - 6, 60)], GEM[2])
            cv.line(gx - 1, 42, gx - 2, 58, C('ffffff'))
        # snapped chain stubs at the wrists
        for (x, y) in ((30, 76), (146, 76), (36, 104)):
            cv.rect(x - 3, y - 2, 6, 4, C('7a7a88')); cv.rect(x - 1, y - 1, 2, 2, C('120e1a'))
    else:
        # molten: lava veins, horns and burning eyes
        for seg in (((76, 50), (70, 66)), ((100, 50), (108, 68)), ((60, 96), (70, 108)), ((116, 96), (108, 110)), ((30, 86), (40, 96))):
            cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], HOT[2])
        shard(cv, [(74, 40), (58, 22), (46, 8), (60, 30), (78, 48)], tri('8a5a3a'))
        shard(cv, [(102, 40), (118, 22), (130, 8), (116, 30), (98, 48)], tri('8a5a3a'))
        cv.rect(78, 50, 7, 4, C('ffe9a0')); cv.rect(92, 50, 7, 4, C('ffe9a0'))
        cv.blob(30, 92, 9, 9, tri('ff6a20')); cv.blob(30, 92, 4, 4, tri('ffe070'))
        cv.blob(146, 92, 9, 9, tri('ff6a20')); cv.blob(146, 92, 4, 4, tri('ffe070'))
    cv.outline(OL)
    return cv


# ---------------------------------------------------------------- SKY HUNTER
def hunter_fly_form(form, wing):
    cv = canvas_with(base(gb.hunter, wing), 144, 96, 12, 8)
    E = tri('ffe94a') if form == 2 else tri('ff5a3a')
    B = tri('5a78c8') if form == 2 else tri('3a2a4a')
    if form == 3:
        tint(cv, (60, 30, 80, 255), 0.25)
    up = wing == 0
    # spiked wing tips
    for (x, y, dx, dy) in ((62, 12 if up else 22, -14, -10), (62, 84 if up else 74, -14, 10), (44, 16 if up else 26, -18, -6), (44, 80 if up else 70, -18, 6)):
        shard(cv, [(x, y), (x + dx, y + dy), (x + 8, y + (2 if dy < 0 else -2))], tri('d8ccb0') if form == 3 else B)
    # lightning bolts along the wings
    pts_top = [(66, 34), (60, 26), (64, 24), (56, 14)]
    pts_bot = [(66, 62), (60, 70), (64, 72), (56, 82)]
    for pts in (pts_top, pts_bot):
        for a, b in zip(pts, pts[1:]):
            cv.line(a[0], a[1], b[0], b[1], E[1])
    # head crest
    if form == 2:
        for (x, h) in ((86, 12), (92, 18), (98, 12)):
            shard(cv, [(x - 3, 34), (x, 34 - h), (x + 3, 34)], E)
    else:
        shard(cv, [(84, 38), (74, 18), (60, 6), (76, 24), (94, 40)], tri('ff6a30'))
        shard(cv, [(84, 58), (74, 78), (60, 90), (76, 72), (94, 56)], tri('8a5a3a'))
        cv.rect(92, 44, 4, 3, C('ffe070'))
    cv.outline(OL)
    return cv


def hunter_ground_form(form):
    cv = canvas_with(base(gb.hunter_ground), 104, 72, 8, 6)
    if form == 3:
        tint(cv, (60, 30, 80, 255), 0.25)
    E = tri('ffe94a') if form == 2 else tri('ff5a3a')
    # spines on the folded wings
    for x in (34, 44, 54, 64):
        shard(cv, [(x - 4, 22), (x, 6 if form == 2 else 0), (x + 4, 22)], tri('b0b8d8') if form == 2 else tri('8a5a3a'))
    if form == 2:
        # the back gem: the phase-2 weak point
        cv.poly([(16, 40), (20, 26), (26, 22), (32, 30), (30, 42)], tri('3a78ff')[1])
        cv.poly([(20, 26), (26, 22), (25, 38), (19, 38)], tri('a8d0ff')[1])
        cv.line(24, 27, 23, 37, C('ffffff'))
        for seg in (((14, 32), (6, 26)), ((34, 34), (42, 30))):
            cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], E[1])
    else:
        shard(cv, [(70, 20), (66, 4), (56, -2), (62, 12), (74, 26)], tri('8a5a3a'))
        cv.blob(72, 32, 5, 5, tri('ffb040')); cv.rect(70, 30, 3, 3, C('ffffff'))
        for seg in (((40, 30), (50, 40)), ((52, 34), (62, 42)), ((30, 36), (38, 44))):
            cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], E[1])
    cv.outline(OL)
    return cv


# ---------------------------------------------------------------- TWINS
def twin_form(kind, open_):
    """phase-2 (evolved) sentinel: same idol wearing a spiked halo and a crown."""
    cv = canvas_with(base(gb.sentinel, kind, open_), 76, 84, 10, 12)
    P = tri('ffb040') if kind == 'sun' else tri('9a7aff')
    S = tri('8a8296') if kind == 'sun' else tri('6e6a92')
    D = tri('3e3a4a')
    # halo of spikes behind/around the shell
    for a in range(-80, 260, 30):
        ca = math.radians(a)
        x0, y0 = 38 + 22 * math.cos(ca), 40 + 26 * math.sin(ca)
        x1, y1 = 38 + 36 * math.cos(ca), 40 + 40 * math.sin(ca)
        xm, ym = 38 + 22 * math.cos(ca + 0.22), 40 + 26 * math.sin(ca + 0.22)
        cv.poly([(x0, y0), (x1, y1), (xm, ym)], D[1] if a % 60 else P[1])
    # crown gems
    for (x, h) in ((28, 10), (38, 16), (48, 10)):
        shard(cv, [(x - 3, 12), (x, 12 - h), (x + 3, 12)], P)
    # hot cracks
    for seg in (((26, 30), (30, 42)), ((50, 34), (46, 48)), ((30, 56), (38, 64))):
        cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], P[2])
    cv.outline(OL)
    return cv


def eclipse(open_):
    """phase-3 fusion: sun-half and moon-half welded together inside a burning corona."""
    cv = Cv(112, 112)
    cx, cy = 56, 56
    SUN = tri('ffb040'); MOON = tri('9a7aff')
    # corona rays alternate amber / violet
    for i in range(16):
        a0 = math.radians(i * 22.5 - 6); a1 = math.radians(i * 22.5 + 6)
        ln = 54 if i % 2 == 0 else 44
        col = SUN if (i % 4 < 2) else MOON
        cv.poly([(cx + 26 * math.cos(a0), cy + 26 * math.sin(a0)), (cx + ln * math.cos((a0 + a1) / 2), cy + ln * math.sin((a0 + a1) / 2)), (cx + 26 * math.cos(a1), cy + 26 * math.sin(a1))], col[1])
    cv.blob(cx, cy, 32, 32, tri('120e22'))
    # fused idol: left half sun shell, right half moon shell
    sun = base(gb.sentinel, 'sun', open_)
    moon = base(gb.sentinel, 'moon', open_)
    fused = Cv(56, 64)
    fused.paste(sun, 0, 0)
    right = moon.im.crop((28, 0, 56, 64))
    tmp = Cv(56, 64)
    tmp.im.paste(right, (28, 0)); tmp.p = tmp.im.load()
    # clear the right half of the sun, then lay the moon half down
    for y in range(64):
        for x in range(28, 56):
            fused.p[x, y] = (0, 0, 0, 0)
    fused.im.alpha_composite(tmp.im)
    fused.p = fused.im.load()
    cv.paste(fused, cx - 28, cy - 32 + 4)
    if open_:
        cv.blob(cx, cy + 2, 6, 8, tri('ffffff'))
    # brow crown
    for (x, h, c) in ((44, 10, SUN), (56, 16, MOON), (68, 10, SUN)):
        shard(cv, [(x - 3, 30), (x, 30 - h), (x + 3, 30)], c)
    cv.outline(OL)
    return cv


# ---------------------------------------------------------------- REGENT
def regent_form(form, open_):
    cv = canvas_with(base(gb.regent, open_), 120, 124, 16, 14)
    CY = tri('7ad0ff') if form == 2 else tri('ff5a3a')
    GD = tri('e0b040'); DK = tri('2a1e3c')
    k = 1.0 if form == 2 else 1.4
    # wings of shards fanned behind the shoulders
    for side in (-1, 1):
        for i, (dx, dy, ln) in enumerate(((10, 30, 30), (16, 40, 36), (20, 52, 30), (22, 64, 22))):
            x0 = 60 + side * dx
            y0 = 30 + dy
            shard(cv, [(x0, y0 - 5), (x0 + side * ln * k, y0 - 12 * k), (x0 + side * 4, y0 + 5)], CY if form == 2 else DK)
    # pauldron spikes
    for cx in (40, 80):
        shard(cv, [(cx - 6, 54), (cx - 2, 34 - 6 * k), (cx + 6, 54)], GD)
    # taller crown
    for (x, h) in ((48, 14), (60, 22), (72, 14)):
        shard(cv, [(x - 3, 26), (x, 26 - h * k), (x + 3, 26)], GD)
    if form == 3:
        # horns, burning mask, larger core glow
        shard(cv, [(46, 30), (34, 12), (24, 2), (36, 18), (50, 36)], tri('8a5a3a'))
        shard(cv, [(74, 30), (86, 12), (96, 2), (84, 18), (70, 36)], tri('8a5a3a'))
        cv.rect(49, 36, 5, 3, C('ffe070')); cv.rect(65, 36, 5, 3, C('ffe070'))
        for seg in (((50, 60), (44, 74)), ((70, 60), (78, 76)), ((60, 86), (60, 100))):
            cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], tri('ff9a30')[2])
    else:
        for seg in (((52, 62), (46, 74)), ((68, 62), (74, 74))):
            cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], C('e8ffff'))
    cv.outline(OL)
    return cv


def gen(out):
    B = out + '/bosses/'
    knight_form(2).save(B + 'knight2.png')
    knight_form(3).save(B + 'knight3.png')
    mirror_plate().save(B + 'mirror_plate.png')
    for f in (2, 3):
        regent_form(f, False).save(B + f'regent{f}_closed.png')
        regent_form(f, True).save(B + f'regent{f}_open.png')
    for k in ('sun', 'moon'):
        twin_form(k, False).save(B + f'sentinel_{k}2_closed.png')
        twin_form(k, True).save(B + f'sentinel_{k}2_open.png')
    eclipse(False).save(B + 'eclipse_closed.png')
    eclipse(True).save(B + 'eclipse_open.png')
    for f in (2, 3):
        sheet([hunter_fly_form(f, 0), hunter_fly_form(f, 1)], B + f'hunter{f}_fly.png')
        hunter_ground_form(f).save(B + f'hunter{f}_ground.png')
    colossus_form(2, False).save(B + 'colossus2_closed.png')
    colossus_form(3, False).save(B + 'colossus3_closed.png')
    colossus_form(3, True).save(B + 'colossus3_open.png')
    burrower_form(2, False).save(B + 'burrower2_closed.png')
    burrower_form(3, False).save(B + 'burrower3_closed.png')
    burrower_form(3, True).save(B + 'burrower3_open.png')
