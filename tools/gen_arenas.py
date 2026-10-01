"""Boss lairs: each arena (and the path leading to it) gets its own biome so it matches the boss that lives there.
Runs AFTER gen_pack / gen_boss_pack on purpose: these tiles and props keep their own palettes (no 14-colour lock).

  courtyard  Stone Warden   rune sanctum   grey-green flagstones, cyan rune inlays
  crystal    Mirror Knight  frozen vault    blue ice, snow, frozen waterfall
  burrow     Burrower       execution dunes sand, ash, bone, gallows
  colossus   Colossus       foundry         black basalt, lava veins, riveted iron
  sky        Sky Hunter     aerie           pale mossy stone, cliff rock, grass
  twins      Twin Sentinels observatory     violet stone, star dust, gold ring

Every tileset has 14 tiles: 0-2 floor, 3 alt floor (':'), 4 wall top, 5 wall face, 6 void, 7 rune ring ('_'), 8 accent (','),
9 rubble (';'), 10 dark floor, 11 crater, 12 phase-2 floor, 13 phase-3 floor (the boss swaps random floor tiles to these)."""
import math
import os
import random
from PIL import Image
from pix import *
import gen_decor as gd

OLN = C('120e1a')


# ------------------------------------------------------------------ tiles
class Pal:
    def __init__(self, floor, alt, seam, spec_d, spec_l, wall, wall_top, accent, rune, void):
        self.f, self.a, self.s = tri(floor), tri(alt), tri(seam)
        self.sd, self.sl = C(spec_d), C(spec_l)
        self.w, self.wt, self.ac, self.rune, self.void = tri(wall), tri(wall_top), tri(accent), tri(rune), C(void)


PALS = {
    'courtyard': Pal('4f5d58', '48554f', '2f3a37', '3a4642', '6a7c74', '5b655f', '222a29', '5c7a4c', '5fe0e0', '0d1414'),
    'crystal': Pal('3a6ba6', '33619b', '244b7c', '2e5a92', 'a8d8ff', '3f78b5', '16264a', 'dff0ff', 'e8faff', '08122a'),
    'burrow': Pal('3d3852', '363150', '24202f', '2e2942', '7a72a0', '4c4260', '15121c', 'a8a0c8', 'a8d8ff', '08060c'),
    'colossus': Pal('3b3339', '332b31', '1f191e', '241d22', '5a4c54', '46383a', '150f12', 'ef6a2a', 'ffb040', '080506'),
    'sky': Pal('9aa693', '8e9c88', '6e7a6a', '7a8a72', 'c2ceb8', '6c7870', '283029', '6f8f5a', 'f7efdf', '101812'),
    'final': Pal('2a2638', '242032', '161220', '1e1a2a', '5a4f78', '4a3f58', '100c18', 'e8b840', 'e8b840', '06040a'),
    'twins': Pal('4b4066', '43385d', '2e2545', '352c52', 'a89ad0', '5c4b86', '191330', 'e8b050', 'e8b050', '0a0716'),
}


def speck(t, pal, seed, dens=0.09):
    t.noise(0, 0, 16, 16, [pal.sd, pal.sl], dens, seed=seed)


def floor_tile(name, i, p):
    t = Cv(16, 16)
    pal = p.a if i == 1 else p.f
    t.rect(0, 0, 16, 16, pal[1])
    if name == 'crystal':
        speck(t, p, 20 + i, 0.06)
        for k, (x0, y0) in enumerate(((2, 13), (8, 15), (-3, 9))):
            if (k + i) % 2 == 0:
                t.line(x0, y0, x0 + 7, y0 - 7, p.sl)
        t.rect(0, 0, 16, 1, mix(pal[1], p.sl, 0.25)); t.rect(0, 0, 1, 16, mix(pal[1], p.sl, 0.25))
        if i == 2:
            t.line(4, 3, 9, 7, p.sd); t.line(9, 7, 8, 12, p.sd)
    elif name == 'colossus':
        speck(t, p, 50 + i, 0.10)
        t.rect(0, 15, 16, 1, pal[0]); t.rect(15, 0, 1, 16, pal[0])
        r = random.Random(60 + i)
        # irregular slab seams, a couple of them dull red (cooling lava)
        x = r.randint(4, 11)
        for y in range(16):
            if y % 3 == 0:
                x = max(2, min(13, x + r.randint(-1, 1)))
            t.px(x, y, pal[0])
        if i == 2:
            for y in range(16):
                if y % 2 == 0:
                    t.px(x, y, C('6a2a26'))
    else:  # flag stones: courtyard, sky, twins
        speck(t, p, 10 + i, 0.09)
        t.rect(0, 15, 16, 1, pal[0]); t.rect(15, 0, 1, 16, pal[0])
        t.px(1, 1, pal[2]); t.px(2, 1, pal[2])
        if i == 2:
            t.rect(0, 7, 16, 1, pal[0]); t.rect(7, 0, 1, 8, pal[0])
        if name == 'courtyard' and i != 1:
            t.noise(0, 0, 16, 16, [p.ac[1]], 0.03, seed=70 + i)
        if name == 'twins':
            t.noise(0, 0, 16, 16, [C('f7efdf'), C('a89ad0')], 0.015, seed=80 + i)
    return t


def alt_floor(name, p):
    """tile 3 (':'): cracked / tufted variant"""
    t = floor_tile(name, 0, p)
    if name == 'sky':          # grass tuft patch
        for (x, y) in ((3, 12), (8, 9), (12, 13), (6, 5)):
            for k in range(3):
                t.px(x + k - 1, y - k % 2 - 1, p.ac[1]); t.px(x + k - 1, y, p.ac[0])
            t.px(x, y - 3, p.ac[2])
    elif name == 'colossus':   # lava crack, glowing
        for a, b in (((1, 3), (6, 7)), ((6, 7), (10, 6)), ((10, 6), (14, 11)), ((6, 7), (7, 13))):
            t.line(a[0], a[1], b[0], b[1], C('c0401e'))
        for a, b in (((6, 7), (7, 13)), ((10, 6), (14, 11))):
            t.line(a[0] + 0, a[1], b[0], b[1], C('ff8a30'))
        t.px(6, 7, C('ffe08a'))
    elif name == 'crystal':    # whitened cracks
        for a, b in (((2, 3), (7, 8)), ((7, 8), (6, 13)), ((7, 8), (13, 10))):
            t.line(a[0], a[1], b[0], b[1], C('f2fbff'))
    elif name == 'burrow':     # dry cracked sand
        for a, b in (((3, 2), (8, 7)), ((8, 7), (6, 13)), ((8, 7), (14, 9))):
            t.line(a[0], a[1], b[0], b[1], p.sd)
    else:
        for a, b in (((3, 2), (7, 7)), ((7, 7), (6, 12)), ((7, 7), (13, 9))):
            t.line(a[0], a[1], b[0], b[1], p.f[0])
        if name == 'courtyard':
            t.noise(0, 0, 16, 16, [p.ac[1], p.ac[2]], 0.06, seed=91)
    return t


def wall_top(name, p):
    t = Cv(16, 16)
    W = p.wt
    t.rect(0, 0, 16, 16, W[1])
    t.noise(0, 0, 16, 16, [W[0], W[2]], 0.12, seed=5)
    t.rect(0, 0, 16, 1, W[2]); t.rect(0, 8, 16, 1, W[0]); t.rect(8, 0, 1, 8, W[0]); t.rect(4, 8, 1, 8, W[0])
    if name == 'crystal':
        t.rect(0, 0, 16, 3, C('dbeeff')); t.noise(0, 0, 16, 4, [C('ffffff'), C('9cc8f0')], 0.3, seed=6)   # snow cap
    if name == 'sky':
        for x in range(0, 16, 2):
            t.px(x, 0, p.ac[1]); t.px(x + (x % 3), 1, p.ac[0])
    if name == 'courtyard':
        t.noise(0, 0, 16, 5, [p.ac[0], p.ac[1]], 0.25, seed=7)
    return t


def wall_face(name, p):
    t = Cv(16, 16)
    W = p.w
    t.rect(0, 0, 16, 16, W[1])
    if name == 'crystal':                          # ice blocks
        for y in (0, 8):
            for x0 in ((0, 8) if y == 0 else (4, 12)):
                t.rect(x0, y, 8 if x0 in (0, 8) else 8, 8, W[1])
        t.rect(0, 7, 16, 1, W[0]); t.rect(0, 15, 16, 1, W[0])
        t.rect(3, 0, 1, 8, W[0]); t.rect(11, 8, 1, 8, W[0]); t.rect(11, 0, 1, 1, W[0])
        t.rect(0, 0, 16, 1, p.ac[1])
        for (x, y) in ((2, 2), (3, 3), (9, 10), (10, 11), (6, 5), (13, 4)):
            t.px(x, y, p.ac[1])
        t.rect(0, 14, 16, 2, W[0])
    elif name == 'burrow':                         # crypt bricks with bone inlays
        t.rect(0, 0, 16, 2, W[2])
        for y in (5, 10, 15):
            t.rect(0, y, 16, 1, W[0])
        for (y0, off) in ((2, 4), (6, 10), (11, 4)):
            t.rect(off, y0, 1, 3 if y0 != 6 else 4, W[0])
        for (x, y) in ((2, 3), (11, 8), (6, 12), (13, 3)):
            t.px(x, y, C('d8ccb0')); t.px(x + 1, y, C('b8a888'))
        t.rect(0, 14, 16, 2, W[0])
    elif name == 'colossus':                       # riveted iron plates with heat glow at the foot
        t.rect(0, 0, 16, 2, W[2])
        t.rect(0, 7, 16, 1, W[0]); t.rect(0, 15, 16, 1, W[0]); t.rect(7, 0, 1, 16, W[0])
        for (x, y) in ((2, 2), (12, 2), (2, 10), (12, 10), (4, 4), (10, 12)):
            t.px(x, y, W[2])
        t.noise(0, 2, 16, 12, [W[0]], 0.10, seed=8)
        t.rect(0, 13, 16, 3, C('5a2a22')); t.rect(0, 14, 16, 1, C('c0501e')); t.rect(0, 15, 16, 1, C('ff8a30'))
    elif name == 'sky':                            # cliff rock strata
        r = random.Random(9)
        for y in (3, 7, 11, 14):
            t.rect(0, y, 16, 1, W[0] if y != 7 else W[2])
        for x in (r.randint(1, 5), r.randint(6, 10), r.randint(11, 14)):
            t.rect(x, r.randint(0, 7), 1, r.randint(3, 6), W[0])
        t.noise(0, 0, 16, 16, [W[0], W[2]], 0.10, seed=10)
        t.rect(0, 0, 16, 2, p.ac[1]); t.noise(0, 1, 16, 3, [p.ac[0], p.ac[2]], 0.3, seed=11)
    elif name == 'twins':                          # violet brick with a gold band
        t.rect(0, 0, 16, 2, W[2])
        for y in (5, 10, 15):
            t.rect(0, y, 16, 1, W[0])
        for (y0, off) in ((2, 4), (6, 10), (11, 4)):
            t.rect(off, y0, 1, 3 if y0 != 6 else 4, W[0])
        t.rect(0, 12, 16, 1, p.ac[0]); t.px(4, 12, p.ac[2]); t.px(12, 12, p.ac[2])
        t.rect(0, 14, 16, 2, W[0])
    else:                                          # courtyard: mossy bricks
        t.rect(0, 0, 16, 2, W[2])
        for y in (5, 10, 15):
            t.rect(0, y, 16, 1, W[0])
        for (y0, off) in ((2, 4), (6, 10), (11, 4)):
            t.rect(off, y0, 1, 3 if y0 != 6 else 4, W[0])
        t.noise(0, 2, 16, 12, [W[0], W[2]], 0.08, seed=6)
        for x in (2, 9, 13):
            t.line(x, 2, x, 5 + x % 4, p.ac[1]); t.px(x, 6 + x % 4, p.ac[0])
        t.rect(0, 14, 16, 2, W[0])
    return t


def rune_tile(name, p):
    t = floor_tile(name, 0, p)
    R = p.rune
    for a in range(0, 360, 6):
        x = 8 + 5.5 * math.cos(math.radians(a)); y = 8 + 5.5 * math.sin(math.radians(a))
        t.px(x, y, R[2])
    for a in range(0, 360, 60):
        x = 8 + 3 * math.cos(math.radians(a)); y = 8 + 3 * math.sin(math.radians(a))
        t.px(x, y, R[1])
    t.px(8, 8, R[2]); t.px(7, 8, R[1]); t.px(9, 8, R[1]); t.px(8, 7, R[1]); t.px(8, 9, R[1])
    return t


def accent_tile(name, p):
    t = floor_tile(name, 0, p)
    if name == 'crystal':          # snow drift
        t.rect(0, 0, 16, 16, mix(p.f[1], C('eaf6ff'), 0.7)); t.noise(0, 0, 16, 16, [C('ffffff'), C('b8d8f0')], 0.18, seed=12)
    elif name == 'burrow':         # ash and bone flecks
        t.rect(0, 0, 16, 16, mix(p.f[1], C('5a534c'), 0.55)); t.noise(0, 0, 16, 16, [C('8a8378'), C('d8ccb0'), p.sd], 0.14, seed=12)
    elif name == 'colossus':       # ash
        t.noise(0, 0, 16, 16, [C('5a4c54'), C('7a6a70')], 0.2, seed=12)
    elif name == 'sky':            # weeds
        t.rect(0, 0, 16, 16, mix(p.f[1], p.ac[1], 0.35)); t.noise(0, 0, 16, 16, [p.ac[0], p.ac[2], p.f[0]], 0.14, seed=12)
    elif name == 'twins':          # star dust
        t.noise(0, 0, 16, 16, [C('f7efdf'), C('e8b050'), C('a89ad0')], 0.07, seed=12)
    else:
        t.rect(0, 0, 16, 16, mix(p.f[1], p.ac[1], 0.4)); t.noise(0, 0, 16, 16, [p.ac[0], p.ac[2], p.f[0]], 0.14, seed=12)
    return t


def rubble_tile(name, p):
    t = floor_tile(name, 0, p)
    for (x, y, r) in ((3, 4, 2), (10, 3, 1.5), (7, 10, 2.2), (13, 12, 1.5)):
        pal = p.f if (x + y) % 2 else p.a
        if name == 'burrow':
            t.blob(x, y, r, r * 0.8, tri('d8ccb0'))       # skull-white pebbles
        elif name == 'crystal':
            t.blob(x, y, r, r * 0.8, tri('bfe4ff'))       # ice shards
        else:
            t.blob(x, y, r, r, pal)
    return t


def dark_tile(name, p):
    t = floor_tile(name, 0, p)
    t.rect(0, 0, 16, 16, mix(p.f[1], (0, 0, 0, 255), 0.35)); t.noise(0, 0, 16, 16, [p.f[0]], 0.12, seed=11)
    t.rect(0, 15, 16, 1, p.f[0]); t.rect(15, 0, 1, 16, p.f[0])
    return t


def crater_tile(name, p):
    t = floor_tile(name, 0, p)
    t.blob(8, 8, 6.5, 5.5, (p.f[2], p.f[0], mix(p.f[0], (0, 0, 0, 255), .3)), light=(0.5, 0.7))
    return t


def phase_tile(name, p, which):
    """which 2 / 3: the floor as the fight escalates"""
    t = floor_tile(name, 0, p)
    r = random.Random(100 + which)
    if name == 'courtyard':
        col = C('5fe0e0') if which == 2 else C('ef8d35')
        hi = C('c8ffff') if which == 2 else C('ffe08a')
        pts = [(1, 4), (5, 7), (9, 6), (13, 10), (10, 14)] if which == 2 else [(2, 2), (6, 6), (9, 11), (14, 12), (6, 6), (11, 3)]
        for a, b in zip(pts, pts[1:]):
            t.line(a[0], a[1], b[0], b[1], col)
        t.px(pts[2][0], pts[2][1], hi)
        if which == 3:
            t.rect(0, 0, 16, 16, mix(t.get(0, 0), C('3a2a26'), 0.25)) if False else None
    elif name == 'crystal':
        if which == 2:                          # thicker frost
            t.noise(0, 0, 16, 16, [C('ffffff'), C('dff0ff')], 0.16, seed=21)
            t.rect(0, 0, 16, 2, C('eaf6ff'))
        else:                                   # mirror shards: dark fractures with bright edges
            for a, b in (((0, 3), (7, 8)), ((7, 8), (12, 2)), ((7, 8), (10, 15)), ((7, 8), (2, 14))):
                t.line(a[0], a[1], b[0], b[1], C('1a3a70')); t.line(a[0] + 1, a[1], b[0] + 1, b[1], C('f2fbff'))
    elif name == 'burrow':
        col = C('6ab0ff') if which == 2 else C('ef6a2a')
        for a, b in (((1, 2), (6, 6)), ((6, 6), (9, 12)), ((6, 6), (14, 5)), ((9, 12), (15, 15))):
            t.line(a[0], a[1], b[0], b[1], col)
        if which == 3:
            t.px(6, 6, C('ffe08a')); t.px(9, 12, C('ffb040'))
    elif name == 'colossus':
        for a, b in (((0, 5), (5, 8)), ((5, 8), (9, 4)), ((9, 4), (15, 7)), ((5, 8), (7, 15))):
            t.line(a[0], a[1], b[0], b[1], C('e0501e') if which == 2 else C('ff8a30'))
            t.line(a[0], a[1] + 1, b[0], b[1] + 1, C('8a2a1e') if which == 2 else C('e0501e'))
        if which == 3:
            t.rect(5, 7, 3, 3, C('ffe08a'))
    elif name == 'sky':
        if which == 2:                          # rain-dark, puddle shine
            t.rect(0, 0, 16, 16, mix(t.get(1, 1), C('5a6c78'), 0.55)); t.noise(0, 0, 16, 16, [C('8aa0b0')], 0.08, seed=22)
            t.blob(8, 9, 4.5, 2.5, tri('6a8aa0'))
        else:                                   # lightning scar
            t.rect(0, 0, 16, 16, mix(t.get(1, 1), C('2a2a30'), 0.5))
            pts = [(8, 0), (6, 4), (9, 7), (7, 11), (8, 15)]
            for a, b in zip(pts, pts[1:]):
                t.line(a[0], a[1], b[0], b[1], C('ffe870'))
    elif name == 'twins':
        if which == 2:
            t.rect(0, 0, 16, 16, mix(t.get(1, 1), C('241c3a'), 0.45)); t.noise(0, 0, 16, 16, [C('a89ad0')], 0.03, seed=23)
        else:
            t.rect(0, 0, 16, 16, mix(t.get(1, 1), C('0a0716'), 0.75))
            t.line(0, 12, 15, 3, C('6a1e2a'))
    return t


QUAD = {  # element: (floor, cracks, awake floor, awake cracks)
    'fire': ('3a2226', 'c0401e', '5c2e26', 'ff9a3a'),
    'ice': ('223a5c', '6ab0ff', '345a88', 'b8e0ff'),
    'earth': ('4a3a2c', '8a6a3a', '5c4a34', 'e8c060'),
    'storm': ('2e2648', '9b8cff', '463a72', 'e8e0ff'),
}


def quad_tile(element, awake, seed):
    base, crack, abase, acrack = QUAD[element]
    t = Cv(16, 16)
    B = tri(abase if awake else base)
    t.rect(0, 0, 16, 16, B[1])
    t.noise(0, 0, 16, 16, [B[0], B[2]], 0.10, seed=seed)
    t.rect(0, 15, 16, 1, B[0]); t.rect(15, 0, 1, 16, B[0])
    col = C(acrack if awake else crack)
    if element == 'fire':
        pts = [(0, 9), (4, 6), (8, 8), (12, 4), (15, 6)]
    elif element == 'ice':
        pts = [(2, 0), (5, 5), (9, 7), (12, 12), (14, 15)]
    elif element == 'earth':
        pts = [(1, 3), (5, 4), (8, 9), (12, 10), (15, 14)]
    else:
        pts = [(8, 0), (6, 5), (10, 8), (7, 12), (9, 15)]
    for a, b2 in zip(pts, pts[1:]):
        t.line(a[0], a[1], b2[0], b2[1], col)
        if awake:
            t.line(a[0], a[1] + 1, b2[0], b2[1] + 1, mix(col, B[1], 0.5))
    return t


def make_tiles(name):
    p = PALS[name]
    cv = Cv(16 * 14, 16)
    tiles = [floor_tile(name, 0, p), floor_tile(name, 1, p), floor_tile(name, 2, p), alt_floor(name, p),
             wall_top(name, p), wall_face(name, p), None, rune_tile(name, p), accent_tile(name, p), rubble_tile(name, p),
             dark_tile(name, p), crater_tile(name, p), phase_tile(name, p, 2), phase_tile(name, p, 3)]
    if name == 'final':                     # 12-15 quadrant floors, 16-19 the same, awake (telegraph of the lair's hazard)
        tiles = tiles[:12]
        for k, el in enumerate(('fire', 'ice', 'earth', 'storm')):
            tiles.append(quad_tile(el, False, 200 + k))
        for k, el in enumerate(('fire', 'ice', 'earth', 'storm')):
            tiles.append(quad_tile(el, True, 210 + k))
        cv = Cv(16 * 20, 16)
    for i, t in enumerate(tiles):
        if t is None:
            t = Cv(16, 16)
            t.rect(0, 0, 16, 16, p.void)
        cv.paste(t, i * 16, 0)
    return cv


# ------------------------------------------------------------------ props
def shadow(cv, cx, cy, rx, ry, a=90):
    gd.shadow(cv, cx, cy, rx, ry, a)


def load(E, name):
    return Image.open(E + name + '.png').convert('RGBA')


def rune_pillar(E, src, dst):
    """the pack pillar with cyan rune glyphs carved into the shaft"""
    im = load(E, src)
    cv = Cv(im.width, im.height)
    cv.im = im
    cv.p = im.load()
    bb = im.getbbox()
    cx = (bb[0] + bb[2]) // 2
    R = tri('5fe0e0')
    for y in range(bb[1] + 7, bb[3] - 9, 6):
        for dx, dy in ((0, 0), (-1, 1), (1, 1), (0, 2), (-2, 0), (2, 0)):
            if cv.get(cx + dx, y + dy)[3] > 200:
                cv.px(cx + dx, y + dy, R[2] if (dx, dy) == (0, 0) else R[1])
    cv.save(E + dst + '.png')


def banner_c(main, trim, emblem='disc'):
    cv = Cv(16, 36)
    B = tri(main)
    cv.rect(2, 2, 12, 2, gd.WOOD[0]); cv.rect(3, 4, 10, 26, B[1]); cv.rect(3, 4, 2, 26, B[2])
    cv.poly([(3, 30), (13, 30), (13, 34), (8, 31), (3, 34)], B[1])
    T = C(trim)
    if emblem == 'star':
        cv.rect(7, 10, 2, 9, T); cv.rect(4, 13, 8, 2, T); cv.px(5, 11, T); cv.px(10, 11, T); cv.px(5, 17, T); cv.px(10, 17, T)
    else:
        cv.rect(6, 10, 4, 4, T); cv.rect(7, 14, 2, 6, T)
    cv.outline(OLN); return cv


def crystal_p(kind, base, shine):
    cv = Cv(24, 32); shadow(cv, 12, 28, 8, 2)
    P = tri(base)
    if kind == 'single':
        cv.poly([(12, 2), (18, 10), (16, 28), (8, 28), (6, 10)], P[1])
        cv.poly([(12, 2), (6, 10), (8, 28), (12, 28)], P[2])
        cv.poly([(12, 2), (18, 10), (16, 28), (13, 28)], P[0])
        cv.line(12, 6, 10, 22, C(shine))
    else:
        for (x, h, w) in ((6, 16, 4), (12, 24, 5), (18, 14, 4)):
            cv.poly([(x, 28 - h), (x + w, 28 - h + 5), (x + w - 1, 28), (x - w + 1, 28), (x - w, 28 - h + 5)], P[1])
            cv.poly([(x, 28 - h), (x - w, 28 - h + 5), (x - w + 1, 28), (x, 28)], P[2])
    cv.outline(OLN); return cv


def ice_block():
    cv = Cv(16, 30); P = tri('9fd8ff')
    cv.poly([(2, 12), (8, 2), (14, 12), (14, 26), (2, 26)], P[1])
    cv.poly([(8, 2), (2, 12), (2, 26), (8, 26)], P[2])
    cv.poly([(8, 2), (14, 12), (14, 26), (10, 26)], P[0])
    cv.line(6, 8, 4, 22, C('ffffff')); cv.line(11, 12, 11, 20, C('e0f6ff'))
    cv.rect(1, 26, 14, 3, tri('3a5a90')[1]); cv.rect(1, 28, 14, 1, tri('3a5a90')[0])
    cv.outline(OLN); return cv


def frozen_fall():
    cv = Cv(48, 64)
    cols = [C('cfeaff'), C('9fd0f4'), C('7ab4e6'), C('e8f6ff')]
    r = random.Random(3)
    cv.rect(0, 0, 48, 10, tri('2c4a7a')[1]); cv.noise(0, 0, 48, 10, [tri('2c4a7a')[0], tri('2c4a7a')[2]], 0.25, seed=2)
    x = 3
    while x < 45:
        w = r.randint(3, 6)
        h = r.randint(46, 58)
        col = r.choice(cols)
        cv.rect(x, 8, w, h - 8, col)
        cv.rect(x, 8, 1, h - 8, C('ffffff')); cv.rect(x + w - 1, 8, 1, h - 8, C('6aa0d8'))
        cv.poly([(x, h), (x + w, h), (x + w // 2, h + r.randint(4, 8))], col)
        x += w + 1
    cv.blob(24, 61, 22, 3.5, tri('e8f6ff'))
    cv.outline(OLN); return cv


def icicles():
    cv = Cv(34, 16); r = random.Random(4)
    cv.rect(0, 0, 34, 2, tri('2c4a7a')[1])
    for x in range(2, 32, 5):
        h = r.randint(6, 14)
        cv.poly([(x, 2), (x + 4, 2), (x + 2, 2 + h)], C('cfeaff')); cv.line(x + 1, 2, x + 2, 1 + h, C('ffffff'))
    return cv


def snow_drift():
    cv = Cv(28, 10)
    S = tri('e8f4ff')
    cv.blob(9, 6, 8, 3.5, S); cv.blob(18, 6, 9, 4, S); cv.blob(14, 4, 7, 3, S)
    cv.noise(0, 0, 28, 10, [C('ffffff'), C('b8d8f0')], 0.1, seed=5)
    return cv


def gallows():
    cv = Cv(40, 68); shadow(cv, 20, 64, 15, 3)
    W = tri('6a4a30')
    cv.srect(4, 60, 14, 5, tri('5a5060'))
    cv.rect(8, 8, 5, 54, W[1]); cv.rect(8, 8, 2, 54, W[2]); cv.rect(12, 8, 1, 54, W[0])
    cv.rect(8, 6, 28, 5, W[1]); cv.rect(8, 6, 28, 1, W[2]); cv.rect(8, 10, 28, 1, W[0])
    cv.line(13, 26, 22, 11, W[0]); cv.line(14, 26, 23, 11, W[1])
    R = tri('c8b48a')
    cv.line(30, 11, 30, 26, R[1]); cv.line(31, 11, 31, 26, R[0])
    cv.blob(30, 30, 3.5, 4, tri('8a7a60')); cv.blob(30, 30, 2, 2.5, (OLN, OLN, OLN))
    cv.outline(OLN); return cv


def chop_block():
    cv = Cv(24, 22); shadow(cv, 12, 19, 9, 2)
    W = tri('6a4a30')
    cv.rect(5, 9, 14, 9, W[1]); cv.blob(12, 9, 7, 3, W); cv.rect(5, 9, 2, 9, W[2]); cv.rect(17, 9, 2, 9, W[0])
    cv.line(9, 8, 8, 0, C('8a6a44')); cv.line(10, 8, 9, 0, C('6a4a30'))
    cv.poly([(4, 1), (12, 1), (11, 7), (5, 7)], C('b0b0bc')); cv.line(4, 1, 5, 7, C('e8e8f0'))
    cv.outline(OLN); return cv


def hang_cage():
    cv = Cv(18, 42); shadow(cv, 9, 39, 6, 1.5)
    W = tri('5a4a3a'); I = tri('6a6270')
    cv.rect(8, 0, 2, 8, I[1])
    cv.blob(9, 22, 7, 12, (C('20181c'), C('20181c'), C('20181c')))
    for x in (3, 6, 9, 12, 15):
        cv.rect(x, 12, 1, 20, I[1])
    for y in (12, 20, 28):
        cv.rect(2, y, 14, 1, I[2] if y == 12 else I[0])
    cv.blob(9, 26, 3, 2.5, tri('d8ccb0')); cv.px(8, 26, OLN); cv.px(10, 26, OLN)
    cv.rect(8, 33, 2, 6, W[1])
    cv.outline(OLN); return cv


def rib_cage():
    cv = Cv(52, 32); shadow(cv, 26, 28, 22, 3)
    B = tri('d8ccb0')
    cv.line(4, 24, 48, 24, B[1]); cv.line(4, 25, 48, 25, B[0])
    for i, x in enumerate(range(10, 44, 6)):
        h = 20 - abs(i - 2.5) * 2.5
        for k in range(5):
            cv.px(x + k * 0.6, 24 - h * math.sin(k * 0.35 + 0.15) * 1.05, B[2])
            cv.px(x + k * 0.6 + 1, 24 - h * math.sin(k * 0.35 + 0.15) * 1.05, B[1])
        cv.line(x, 24, x + 1, 22, B[1])
        cv.line(x + 4, 24 - h + 2, x + 5, 24, B[0])
    cv.blob(48, 22, 4, 3.5, B); cv.px(47, 21, OLN); cv.px(50, 21, OLN)
    cv.outline(OLN); return cv


def skull_pile():
    cv = Cv(20, 14); shadow(cv, 10, 12, 8, 1.5)
    B = tri('d8ccb0')
    for (x, y, r) in ((5, 8, 3.5), (12, 9, 3.5), (9, 4, 3.5)):
        cv.blob(x, y, r, r, B); cv.px(x - 1, y - 0.5, OLN); cv.px(x + 1, y - 0.5, OLN); cv.px(x, y + 1, OLN)
    cv.outline(OLN); return cv


def bone_spike():
    cv = Cv(18, 32); shadow(cv, 9, 29, 7, 2)
    B = tri('d8ccb0')
    cv.poly([(10, 1), (16, 27), (3, 27)], B[1]); cv.poly([(10, 1), (3, 27), (8, 27)], B[2]); cv.poly([(10, 1), (16, 27), (13, 27)], B[0])
    cv.line(9, 6, 7, 20, B[2])
    cv.blob(9, 27, 7, 2.5, tri('6a5a48'))
    cv.outline(OLN); return cv


def lava_vent(f):
    cv = Cv(24, 22)
    I = tri('4a3c40')
    cv.srect(0, 4, 24, 16, I)
    glow = [C('c0401e'), C('ef6a2a'), C('ff9a3a')][f]
    hot = [C('ef6a2a'), C('ffb040'), C('ffe08a')][f]
    for x in range(3, 22, 5):
        cv.rect(x, 7, 3, 10, C('1a1010')); cv.rect(x, 9 + (f % 2), 3, 6, glow); cv.rect(x + 1, 11, 1, 3, hot)
    for x in (4, 12, 19):
        cv.px(x + (f % 2), 2 - (f % 3), C('ffb040', 150)); cv.px(x + 1, 0 + f % 2, C('ffb040', 90))
    cv.outline(OLN); return cv


def basalt_col():
    cv = Cv(22, 44); shadow(cv, 11, 40, 8, 2.5)
    B = tri('4a3c44')
    cv.srect(3, 34, 16, 6, tri('3a2e36'))
    cv.srect(5, 10, 12, 26, B)
    cv.poly([(5, 10), (9, 4), (12, 8), (17, 3), (17, 10)], B[1])
    for y in range(14, 34, 6):
        cv.rect(5, y, 12, 1, B[0])
    cv.line(9, 12, 8, 22, C('e0501e')); cv.line(8, 22, 12, 32, C('c0401e')); cv.px(9, 12, C('ffe08a'))
    cv.outline(OLN); return cv


def anvil():
    cv = Cv(32, 24); shadow(cv, 16, 21, 12, 2)
    I = tri('5a5060')
    cv.srect(8, 14, 16, 6, tri('3a3038'))
    cv.poly([(4, 6), (28, 6), (26, 11), (20, 13), (12, 13), (6, 11)], I[1])
    cv.rect(4, 6, 24, 1, I[2]); cv.poly([(28, 6), (31, 7), (28, 9)], I[1])
    cv.rect(12, 4, 8, 2, C('c0501e')); cv.px(15, 3, C('ffb040'))
    cv.outline(OLN); return cv


def hang_chain():
    cv = Cv(8, 48); c = tri('7a7a88')
    for y in range(0, 46, 6):
        cv.rect(2, y, 4, 4, c[1]); cv.rect(3, y + 1, 2, 2, OLN); cv.rect(3, y + 4, 2, 2, c[0])
    return cv


def pylon_iron(on):
    cv = Cv(28, 52); shadow(cv, 14, 48, 11, 3)
    I = tri('4a3f44')
    cv.srect(6, 12, 16, 34, tri('3a3036')); cv.srect(3, 42, 22, 6, I); cv.srect(4, 8, 20, 6, I)
    P = tri('ff9a3a') if on else tri('6a3a34')
    cv.rect(11, 16, 6, 20, C('1a1216'))
    cv.rect(12, 18, 4, 16, P[1]); cv.rect(13, 18, 2, 16, P[2] if on else P[1])
    cv.rect(9, 38, 10, 2, P[1])
    for (x, y) in ((8, 14), (18, 14), (8, 40), (18, 40)):
        cv.px(x, y, I[2])
    cv.outline(OLN); return cv


def watchtower():
    cv = Cv(60, 96); shadow(cv, 30, 92, 26, 4)
    S = tri('8a94a0'); D = tri('5e6874')
    cv.srect(10, 30, 34, 60, S)
    for y in range(36, 88, 8):
        cv.rect(10, y, 34, 1, D[0])
        for x in range(14 + ((y // 8) % 2) * 6, 44, 12):
            cv.rect(x, y, 1, 8, D[0])
    for x, h in ((10, 8), (18, 4), (28, 9), (37, 3)):        # ruined crenellations
        cv.srect(x, 30 - h, 7, h + 2, S)
    cv.poly([(24, 44), (32, 44), (32, 60), (24, 60)], C('141a20')); cv.rect(24, 44, 8, 1, S[2])
    cv.srect(4, 84, 46, 8, D)
    cv.blob(50, 88, 4, 3, D); cv.blob(6, 90, 3, 2, D)
    for (x, y) in ((12, 34), (13, 35), (42, 46), (41, 47), (16, 70), (17, 71), (38, 76)):
        cv.px(x, y, C('6f8f5a')); cv.px(x + 1, y, C('5a7a4a'))
    for k in range(6):
        cv.line(14 + k * 2, 30, 13 + k * 2, 38 + k, C('4f7a44'))
    cv.outline(OLN); return cv


def grass_tuft():
    cv = Cv(14, 12)
    G = tri('6f9a5a')
    for k, x in enumerate((3, 5, 7, 9, 11)):
        h = 6 + (k % 3) * 2
        cv.line(x, 11, x + (k - 2), 11 - h, G[1]); cv.line(x + 1, 11, x + 1 + (k - 2), 11 - h, G[2] if k % 2 else G[0])
    return cv


def wind_banner():
    cv = Cv(24, 44)
    W = tri('6a4a30'); B = tri('7a9a70')
    cv.rect(3, 2, 2, 40, W[1]); cv.rect(3, 2, 1, 40, W[2]); cv.blob(4, 2, 2, 2, tri('e0b040'))
    cv.poly([(5, 6), (21, 9), (17, 13), (22, 18), (5, 22)], B[1])
    cv.poly([(5, 6), (21, 9), (5, 12)], B[2]); cv.line(7, 15, 17, 15, B[0])
    cv.blob(4, 42, 5, 1.5, tri('5a5060'))
    cv.outline(OLN); return cv


def feather_pile():
    cv = Cv(18, 10)
    for (x, y, a) in ((4, 6, -0.4), (9, 4, 0.2), (13, 7, 0.5)):
        for k in range(8):
            cv.px(x + k * math.cos(a), y + k * math.sin(a) * 0.6, C('f0f4e8'))
            if k % 2:
                cv.px(x + k * math.cos(a), y + k * math.sin(a) * 0.6 + 1, C('8fb090'))
    return cv


def obelisk():
    cv = Cv(20, 52); shadow(cv, 10, 48, 8, 2.5)
    V = tri('6a58a0')
    cv.srect(3, 40, 14, 8, tri('4a3e70'))
    cv.poly([(10, 2), (16, 12), (15, 40), (5, 40), (4, 12)], V[1])
    cv.poly([(10, 2), (4, 12), (5, 40), (10, 40)], V[2]); cv.poly([(10, 2), (16, 12), (15, 40), (12, 40)], V[0])
    G = C('ffd070')
    cv.rect(9, 14, 2, 9, G); cv.rect(6, 17, 8, 2, G); cv.px(7, 15, G); cv.px(12, 15, G); cv.px(7, 21, G); cv.px(12, 21, G)
    cv.outline(OLN); return cv


def disc(kind):
    """floor emblem: the sun (warm, rays) or the moon (cold, crescent), squashed to the arena's 3/4 view"""
    cv = Cv(84, 60)
    cx, cy, rx, ry = 42, 30, 34, 24
    warm = kind == 'sun'
    fill = (239, 141, 53, 70) if warm else (110, 100, 220, 70)
    ring = (232, 176, 80, 200) if warm else (155, 140, 255, 200)
    for y in range(60):
        for x in range(84):
            nx, ny = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            d = nx * nx + ny * ny
            if d <= 1:
                cv.p[x, y] = fill
                if d > 0.86:
                    cv.p[x, y] = ring
    if warm:
        for a in range(0, 360, 30):
            ax, ay = math.cos(math.radians(a)), math.sin(math.radians(a))
            for k in range(3, 9):
                cv.px(cx + ax * (rx * 0.5 + k * 1.6 * 1.0), cy + ay * (ry * 0.5 + k * 1.1), (255, 224, 138, 200))
        cv.blob(cx, cy, 8, 6, tri('ffb040'))
    else:
        for y in range(60):
            for x in range(84):
                nx, ny = (x + .5 - (cx + 7)) / (rx * 0.62), (y + .5 - (cy - 2)) / (ry * 0.62)
                if nx * nx + ny * ny <= 1 and cv.p[x, y][3] > 0:
                    cv.p[x, y] = (40, 30, 90, 90)
        for (x, y) in ((cx - 14, cy - 6), (cx - 10, cy + 8), (cx - 20, cy + 2)):
            cv.px(x, y, (232, 216, 255, 220))
    return cv


def rune_circle():
    cv = Cv(100, 68)
    cx, cy = 50, 34
    for rx, ry, a in ((44, 30, 210), (36, 24, 150), (24, 16, 210)):
        for ang in range(0, 360, 2):
            x = cx + rx * math.cos(math.radians(ang)); y = cy + ry * math.sin(math.radians(ang))
            cv.px(x, y, (95, 224, 224, a))
    for ang in range(0, 360, 30):
        for rr in (0.55, 0.62, 0.69, 0.76, 0.83):
            x = cx + 44 * rr * math.cos(math.radians(ang)); y = cy + 30 * rr * math.sin(math.radians(ang))
            cv.px(x, y, (140, 240, 240, 220))
    for ang in range(15, 360, 30):
        x = cx + 30 * math.cos(math.radians(ang)); y = cy + 20 * math.sin(math.radians(ang))
        cv.rect(x - 1, y - 1, 3, 3, (95, 224, 224, 230))
    cv.px(cx, cy, (200, 255, 255, 255)); cv.rect(cx - 2, cy, 5, 1, (95, 224, 224, 220)); cv.rect(cx, cy - 2, 1, 5, (95, 224, 224, 220))
    return cv


def vines():
    cv = Cv(16, 34); r = random.Random(7)
    G = tri('4f7a44')
    for x in (3, 7, 11):
        h = r.randint(14, 30)
        cv.line(x, 0, x + r.randint(-1, 1), h, G[0])
        for y in range(4, h, 5):
            cv.px(x - 1, y, G[1]); cv.px(x + 1, y + 1, G[2]); cv.px(x - 2, y + 1, G[1])
    return cv


def lantern(on):
    """an iron lantern on a short post: the crypt's light puzzle. off = cold glass, on = flame and a warm halo"""
    cv = Cv(18, 40); shadow(cv, 9, 37, 7, 2)
    I = tri('5a5468')
    cv.srect(7, 22, 4, 15, tri('3a3448'))
    cv.srect(3, 34, 12, 4, I)
    cv.poly([(9, 2), (15, 8), (3, 8)], I[1]); cv.rect(8, 0, 2, 3, I[2])
    cv.srect(3, 8, 12, 15, I)
    glass = (C('ffd070'), C('ffb040'), C('fff0b0')) if on else (C('222a3a'), C('2c3448'), C('3c4860'))
    cv.rect(5, 10, 8, 11, glass[1]); cv.rect(5, 10, 8, 2, glass[2]) if on else cv.rect(5, 10, 8, 2, glass[0])
    if on:
        cv.blob(9, 16, 3, 4.5, tri('fff0b0')); cv.px(9, 13, C('ffffff'))
    else:
        cv.px(6, 12, C('5a6c8c')); cv.px(11, 18, C('4a5c7c'))
    cv.outline(OLN); return cv


def tombstone():
    cv = Cv(18, 28); shadow(cv, 9, 25, 7, 2)
    S = tri('7a7890')
    cv.srect(3, 24, 12, 3, tri('4a4860'))
    cv.poly([(4, 24), (4, 8), (9, 2), (14, 8), (14, 24)], S[1])
    cv.poly([(4, 24), (4, 8), (9, 2), (9, 24)], S[2]); cv.poly([(9, 2), (14, 8), (14, 24), (12, 24)], S[0])
    cv.rect(8, 8, 2, 8, S[0]); cv.rect(6, 10, 6, 2, S[0])
    cv.noise(4, 4, 10, 20, [C('5a7a6a')], 0.06, seed=3)
    cv.outline(OLN); return cv


def coffin():
    cv = Cv(46, 30); shadow(cv, 23, 27, 20, 3)
    W = tri('5a4a5a')
    cv.poly([(8, 6), (38, 6), (44, 16), (38, 25), (8, 25), (2, 16)], W[1])
    cv.poly([(8, 6), (38, 6), (34, 10), (12, 10)], W[2]); cv.poly([(2, 16), (8, 25), (38, 25), (44, 16), (40, 18), (6, 18)], W[0])
    cv.rect(21, 12, 4, 10, C('a8a0c8')); cv.rect(17, 15, 12, 3, C('a8a0c8'))
    cv.outline(OLN); return cv


def shade_pool(f):
    """the reaper's shade under the floor: a slow violet swirl of mist"""
    cv = Cv(40, 24)
    for k in range(5):
        r = 16 - k * 3
        col = [C('1a1424', 190), C('2a1e3a', 190), C('4a3a66', 200), C('6a5a90', 210), C('a8a0c8', 230)][k]
        for a in range(0, 360, 6):
            x = 20 + r * math.cos(math.radians(a + f * 12 + k * 40)) * 1.15
            y = 14 + r * math.sin(math.radians(a + f * 12 + k * 40)) * 0.55
            if (a // 6 + f + k) % 4 != 0:
                cv.px(x, y, col)
    cv.px(20, 14, C('ffffff')); cv.px(19, 14, C('a8a0c8')); cv.px(21, 14, C('a8a0c8'))
    return cv


def shrine(element, on):
    """an elemental shrine (28x46): a plinth carrying the element's emblem, cold when off and blazing when lit"""
    cv = Cv(28, 46); shadow(cv, 14, 43, 11, 3)
    S = tri('6a6478')
    cv.srect(3, 36, 22, 7, tri('4a4458')); cv.srect(6, 26, 16, 11, S)
    cols = {'fire': ('ef6a2a', 'ffd070'), 'water': ('4aa8ff', 'e8faff'), 'earth': ('c09a4a', 'ffe08a'), 'storm': ('9b8cff', 'ffffff')}
    main, hi = cols[element]
    M = tri(main) if on else tri('3a3a4a')
    if element == 'fire':
        cv.blob(14, 22, 8, 4, tri('3a3a4a')); 
        if on:
            cv.poly([(14, 3), (21, 14), (18, 22), (10, 22), (7, 14)], C('c0401e')); cv.poly([(14, 8), (18, 15), (14, 21), (10, 15)], C(main)); cv.poly([(14, 13), (16, 18), (14, 21), (12, 18)], C(hi))
        else:
            cv.blob(14, 20, 5, 3, tri('2a2430'))
    elif element == 'water':
        cv.blob(14, 22, 9, 4, tri('3a4a6a'))
        if on:
            cv.blob(14, 20, 8, 3, tri(main)); cv.rect(12, 6, 4, 14, C(main)); cv.rect(13, 6, 2, 14, C(hi)); cv.blob(14, 6, 5, 3, tri(main))
        else:
            cv.blob(14, 20, 6, 2.5, tri('2a3a55'))
    elif element == 'earth':
        cv.poly([(14, 4), (21, 14), (19, 24), (9, 24), (7, 14)], M[1]); cv.poly([(14, 4), (7, 14), (9, 24), (14, 24)], M[2])
        g = C(hi) if on else C('4a4a5a')
        cv.rect(13, 10, 2, 9, g); cv.rect(10, 13, 8, 2, g)
    else:
        cv.srect(11, 8, 6, 18, tri('5a5468'))
        if on:
            cv.blob(14, 6, 5, 5, tri(main)); cv.px(14, 6, C(hi))
            for (x, y) in ((6, 4), (22, 5), (8, 12), (20, 13), (4, 9), (24, 9)):
                cv.line(14, 6, x, y, C(hi))
        else:
            cv.blob(14, 6, 4, 4, tri('3a3a4a'))
    cv.outline(OLN); return cv


def brazier_cool(E):
    im = load(E, 'brazier')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and r > b + 20:
                px[x, y] = (b, g, r, a)
    im.save(E + 'brazier_cool.png')


def gen(out):
    E = out + '/environment/'
    for name in PALS:
        make_tiles(name).save(f'{E}tiles_{name}.png')
    # warden
    for src, dst in (('pillar', 'pillar_rune'), ('pillar_cracked', 'pillar_rune_cracked'), ('pillar_broken', 'pillar_rune_broken')):
        rune_pillar(E, src, dst)
    rune_circle().save(E + 'rune_circle.png'); vines().save(E + 'vines.png')
    banner_c('3f6f70', '9ff0f0').save(E + 'banner_teal.png')
    # knight
    ice_block().save(E + 'crystal_block_ice.png')
    crystal_p('single', '9fd8ff', 'ffffff').save(E + 'ice_spire_a.png'); crystal_p('cluster', '8fc8f4', 'ffffff').save(E + 'ice_spire_b.png')
    frozen_fall().save(E + 'frozen_fall.png'); icicles().save(E + 'icicles.png'); snow_drift().save(E + 'snow_drift.png')
    banner_c('5a86c0', 'e8f6ff').save(E + 'banner_ice.png')
    # burrower
    gallows().save(E + 'gallows.png'); chop_block().save(E + 'chop_block.png'); hang_cage().save(E + 'hang_cage.png')
    rib_cage().save(E + 'rib_cage.png'); skull_pile().save(E + 'skull_pile.png'); bone_spike().save(E + 'bone_spike.png')
    banner_c('3a3438', 'ef6a2a').save(E + 'banner_ash.png')
    # colossus
    sheet([lava_vent(i) for i in range(3)], E + 'lava_vent.png')
    basalt_col().save(E + 'basalt_col.png'); anvil().save(E + 'anvil.png'); hang_chain().save(E + 'hang_chain.png')
    pylon_iron(False).save(E + 'pylon_iron_off.png'); pylon_iron(True).save(E + 'pylon_iron_on.png')
    banner_c('7a2a26', 'ffb040').save(E + 'banner_lava.png')
    # hunter
    watchtower().save(E + 'watchtower.png'); grass_tuft().save(E + 'grass_tuft.png'); wind_banner().save(E + 'wind_banner.png')
    feather_pile().save(E + 'feather_pile.png')
    banner_c('7a9a70', 'f7efdf').save(E + 'banner_wind.png')
    # twins
    obelisk().save(E + 'obelisk.png'); disc('sun').save(E + 'sun_disc.png'); disc('moon').save(E + 'moon_disc.png')
    brazier_cool(E)
    for el in ('fire', 'water', 'earth', 'storm'):
        shrine(el, False).save(E + 'shrine_%s_off.png' % el); shrine(el, True).save(E + 'shrine_%s_on.png' % el)
    lantern(False).save(E + 'lantern_off.png'); lantern(True).save(E + 'lantern_on.png')
    tombstone().save(E + 'tombstone.png'); coffin().save(E + 'coffin.png')
    sheet([shade_pool(i) for i in range(3)], E.replace('environment', 'bosses') + 'shade_pool.png')
    banner_c('4b3a80', 'e8b050', 'star').save(E + 'banner_violet.png')
    print('  arenas: 6 tilesets (14 tiles), props, banners')
