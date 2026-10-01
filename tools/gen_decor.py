from pix import *

OL = C('120e1a')
STONE = tri('8a8a96')
STONE_D = tri('5e5e6c')
MOSS = tri('5a7a3a')
WOOD = tri('7a5230')
LEAF = tri('3f7a3a')
BONE = tri('d8d0b8')
GOLD = tri('e0b040')
RUST = tri('8a4a2a')


def shadow(cv, cx, cy, rx, ry, a=90):
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            nx = (x + .5 - cx) / rx; ny = (y + .5 - cy) / ry
            if nx * nx + ny * ny <= 1 and cv.get(x, y)[3] == 0:
                cv.px(x, y, (10, 6, 20, a))


def tree(seed, dead=False):
    cv = Cv(40, 56)
    shadow(cv, 20, 52, 12, 3)
    cv.rect(17, 34, 6, 18, WOOD[1]); cv.rect(17, 34, 2, 18, WOOD[2]); cv.rect(22, 34, 1, 18, WOOD[0])
    cv.rect(14, 49, 4, 3, WOOD[1]); cv.rect(22, 49, 4, 3, WOOD[1])
    if dead:
        for (x0, y0, x1, y1) in ((20, 36, 8, 18), (20, 34, 32, 12), (20, 26, 14, 8), (24, 22, 30, 24), (12, 22, 6, 24)):
            cv.line(x0, y0, x1, y1, WOOD[1]); cv.line(x0 + 1, y0, x1 + 1, y1, WOOD[0])
        cv.outline(OL); return cv
    r = random.Random(seed)
    for (x, y, rx, ry) in ((20, 20, 15, 13), (11, 27, 9, 8), (30, 27, 9, 8), (20, 10, 10, 8), (20, 30, 12, 7)):
        cv.blob(x, y, rx, ry, LEAF if r.random() < .7 else MOSS)
    cv.noise(3, 3, 34, 36, [LEAF[2], LEAF[0]], 0.12, seed=seed)
    cv.outline(OL)
    return cv


def bush():
    cv = Cv(18, 12); shadow(cv, 9, 10, 8, 2)
    cv.blob(6, 6, 5, 4.5, LEAF); cv.blob(12, 6, 5, 4.5, MOSS); cv.blob(9, 4, 5, 4, LEAF)
    cv.outline(OL); return cv


def statue(kind):
    cv = Cv(24, 40); shadow(cv, 12, 37, 9, 2)
    cv.srect(5, 32, 14, 5, STONE_D)
    if kind == 'knight':
        cv.srect(8, 14, 8, 18, STONE); cv.blob(12, 10, 4, 4.5, STONE)
        cv.rect(10, 9, 4, 1, STONE[0])
        cv.rect(11, 2, 2, 5, STONE[2])  # crest
        cv.srect(4, 16, 5, 10, STONE_D)  # shield
        cv.rect(17, 8, 2, 22, STONE[2]); cv.rect(16, 15, 4, 1, STONE[0])  # sword
        cv.rect(13, 16, 4, 3, STONE[1])
    elif kind == 'hood':
        cv.poly([(12, 8), (19, 32), (5, 32)], STONE[1]); cv.rect(9, 20, 3, 12, STONE[2])
        cv.blob(12, 9, 4.5, 5, STONE); cv.rect(10, 9, 4, 3, STONE[0])
        cv.rect(15, 20, 2, 5, STONE[0])
    else:  # broken
        cv.srect(8, 22, 8, 10, STONE); cv.poly([(8, 22), (16, 22), (14, 18), (10, 19)], STONE[1])
        cv.blob(19, 34, 3, 2, STONE_D); cv.blob(4, 35, 2, 1.5, STONE_D)
    for (x, y) in ((8, 30), (14, 26), (10, 18)):
        cv.px(x, y, MOSS[1]); cv.px(x + 1, y, MOSS[1]); cv.px(x, y + 1, MOSS[0])
    cv.outline(OL); return cv


def skeleton():
    cv = Cv(72, 34); shadow(cv, 36, 28, 30, 4)
    cv.line(8, 22, 60, 22, BONE[1]); cv.line(8, 23, 60, 23, BONE[0])
    for i, x in enumerate(range(20, 50, 5)):
        h = 12 - abs(i - 3) * 1.2
        cv.line(x, 22, x - 4, 22 - h, BONE[2]); cv.line(x + 1, 22, x - 3, 22 - h, BONE[1])
        cv.line(x, 23, x - 4, 23 + h * 0.4, BONE[0])
    cv.blob(63, 20, 6, 5, BONE); cv.rect(61, 19, 2, 2, OL); cv.rect(65, 19, 2, 2, OL); cv.rect(66, 23, 5, 3, BONE[1])
    cv.rect(58, 14, 2, 4, BONE[1]); cv.rect(66, 14, 2, 4, BONE[1])
    cv.outline(OL); return cv


def sword_grave():
    cv = Cv(14, 22); shadow(cv, 7, 20, 5, 1.5)
    cv.rect(6, 4, 2, 14, STONE[2]); cv.rect(7, 4, 1, 14, STONE[1])
    cv.rect(3, 7, 8, 2, RUST[1]); cv.rect(6, 1, 2, 3, WOOD[1])
    cv.blob(7, 19, 4, 1.5, STONE_D)
    cv.outline(OL); return cv


def pillar(broken=False, cracked=False):
    cv = Cv(24, 44); shadow(cv, 12, 40, 9, 3)
    h = 34 if not broken else 16
    top = 40 - h
    cv.srect(4, 36, 16, 5, STONE_D)
    cv.srect(6, top, 12, h - 2, STONE)
    for y in range(top + 3, 36, 6):
        cv.rect(6, y, 12, 1, STONE[0])
    if not broken:
        cv.srect(3, top - 3, 18, 5, STONE_D)
    else:
        cv.poly([(6, top), (10, top - 3), (13, top), (18, top - 2), (18, top + 2), (6, top + 2)], STONE[1])
        cv.blob(20, 40, 3, 2, STONE_D)
    if cracked:
        cv.line(12, top + 3, 9, top + 14, STONE[0]); cv.line(9, top + 14, 13, top + 22, STONE[0])
        cv.px(12, top + 3, C('ff9a3a')); cv.px(9, top + 14, C('ff9a3a'))
    cv.noise(6, top, 12, h, [MOSS[1]], 0.04, seed=3)
    cv.outline(OL); return cv


def rubble():
    cv = Cv(22, 12); shadow(cv, 11, 9, 9, 2)
    for (x, y, r, k) in ((6, 7, 4, 0), (13, 8, 3.5, 1), (10, 5, 3, 0), (17, 8, 2.5, 1), (3, 9, 2, 1)):
        cv.blob(x, y, r, r * .8, STONE if k == 0 else STONE_D)
    cv.outline(OL); return cv


def fallen_column():
    cv = Cv(48, 20); shadow(cv, 24, 16, 20, 3)
    cv.srect(4, 4, 38, 11, STONE)
    for x in (10, 20, 30):
        cv.rect(x, 4, 1, 11, STONE[0])
    cv.blob(42, 10, 3, 5.5, STONE_D)
    cv.noise(4, 4, 38, 11, [MOSS[1]], 0.06, seed=2)
    cv.outline(OL); return cv


def altar():
    cv = Cv(56, 36); shadow(cv, 28, 32, 24, 3)
    cv.srect(4, 20, 48, 12, STONE_D); cv.srect(8, 10, 40, 12, STONE)
    cv.rect(24, 12, 8, 8, C('ffd070')); cv.rect(25, 13, 6, 6, C('d08a30'))
    cv.line(28, 12, 28, 19, C('ffe9a8')); cv.line(25, 15, 31, 15, C('ffe9a8'))
    cv.outline(OL); return cv


def fountain():
    cv = Cv(56, 44); shadow(cv, 28, 40, 24, 3)
    cv.blob(28, 30, 24, 9, STONE_D); cv.blob(28, 28, 20, 7, tri('2a2c3c'))
    cv.blob(28, 26, 6, 3, STONE)
    cv.rect(25, 8, 6, 18, STONE[1]); cv.rect(25, 8, 2, 18, STONE[2]); cv.blob(28, 8, 5, 3, STONE)
    cv.noise(6, 20, 44, 16, [MOSS[1]], 0.05, seed=4)
    cv.outline(OL); return cv


def crystal(kind):
    cv = Cv(24, 32); shadow(cv, 12, 28, 8, 2)
    P = tri('6ab8f0')
    if kind == 'single':
        cv.poly([(12, 2), (18, 10), (16, 28), (8, 28), (6, 10)], P[1])
        cv.poly([(12, 2), (6, 10), (8, 28), (12, 28)], P[2])
        cv.poly([(12, 2), (18, 10), (16, 28), (13, 28)], P[0])
        cv.line(12, 6, 10, 22, C('e0f8ff'))
    else:
        for (x, h, w) in ((6, 16, 4), (12, 24, 5), (18, 14, 4)):
            cv.poly([(x, 28 - h), (x + w, 28 - h + 5), (x + w - 1, 28), (x - w + 1, 28), (x - w, 28 - h + 5)], P[1])
            cv.poly([(x, 28 - h), (x - w, 28 - h + 5), (x - w + 1, 28), (x, 28)], P[2])
    cv.outline(OL); return cv


def crystal_block():
    """solid reflective block for arenas (16x16 footprint, 26 tall)"""
    cv = Cv(16, 30); P = tri('7ac8ff')
    cv.poly([(2, 12), (8, 2), (14, 12), (14, 26), (2, 26)], P[1])
    cv.poly([(8, 2), (2, 12), (2, 26), (8, 26)], P[2])
    cv.poly([(8, 2), (14, 12), (14, 26), (10, 26)], P[0])
    cv.line(6, 8, 4, 22, C('f0ffff')); cv.line(11, 12, 11, 20, C('c8f0ff'))
    cv.rect(1, 26, 14, 3, tri('3a4a70')[1]); cv.rect(1, 28, 14, 1, tri('3a4a70')[0])
    cv.outline(OL); return cv


def stalagmite():
    cv = Cv(18, 26); shadow(cv, 9, 23, 7, 2)
    T = tri('8a6a48')
    cv.poly([(9, 1), (15, 22), (3, 22)], T[1]); cv.poly([(9, 1), (3, 22), (8, 22)], T[2]); cv.poly([(9, 1), (15, 22), (12, 22)], T[0])
    cv.outline(OL); return cv


def mushrooms():
    cv = Cv(16, 12); shadow(cv, 8, 10, 6, 1.5)
    for (x, y, r) in ((4, 7, 3.5), (10, 5, 4), (13, 8, 2.5)):
        cv.rect(x - 1, y, 2, 4, BONE[1]); cv.blob(x, y, r, r * .7, tri('c04a6a'))
        cv.px(x, y - 1, C('ffe8f0'))
    cv.outline(OL); return cv


def bones():
    cv = Cv(16, 10); shadow(cv, 8, 8, 6, 1.5)
    cv.line(2, 6, 12, 3, BONE[1]); cv.line(3, 7, 13, 5, BONE[0]); cv.blob(4, 4, 2.5, 2.2, BONE); cv.px(3, 4, OL); cv.px(5, 4, OL)
    cv.outline(OL); return cv


def flowers():
    cv = Cv(14, 10)
    for (x, y, c) in ((3, 6, 'e8d060'), (8, 4, 'e06a8a'), (11, 7, 'b0a0f0'), (6, 8, 'f0f0f0')):
        cv.px(x, y, C(c)); cv.px(x, y + 1, LEAF[1]); cv.px(x, y + 2, LEAF[0])
    return cv


def banner():
    cv = Cv(16, 36)
    cv.rect(2, 2, 12, 2, WOOD[0]); cv.rect(3, 4, 10, 26, tri('8a2a3a')[1]); cv.rect(3, 4, 2, 26, tri('8a2a3a')[2])
    cv.poly([(3, 30), (13, 30), (13, 34), (8, 31), (3, 34)], tri('8a2a3a')[1])
    cv.rect(6, 10, 4, 4, GOLD[1]); cv.rect(7, 14, 2, 6, GOLD[1])
    cv.outline(OL); return cv


def brazier(f):
    cv = Cv(20, 34); shadow(cv, 10, 31, 8, 2)
    cv.srect(7, 20, 6, 10, STONE_D); cv.srect(3, 26, 14, 4, STONE); cv.blob(10, 19, 8, 3.5, STONE)
    fl = [(10, 6), (10, 4), (10, 7)][f]
    cv.blob(10, 15, 5, 5, tri('e8642a')); cv.poly([(5, 15), (10, 15 - (9 + f)), (15, 15)], C('f08a30'))
    cv.blob(10, 15, 3, 4, tri('ffd070')); cv.px(10, 9 - f, C('ffe9a0'))
    cv.outline(OL); return cv


def waterfall(f):
    cv = Cv(24, 56); W = tri('6ab0d8')
    cv.rect(2, 0, 20, 46, W[1])
    for x in range(2, 22, 3):
        off = (f * 2 + x) % 9
        cv.line(x, off, x, off + 10, W[2]); cv.line(x + 1, off + 20, x + 1, off + 28, W[0])
    cv.rect(2, 0, 2, 46, W[0]); cv.rect(20, 0, 2, 46, W[0])
    cv.blob(12, 48, 12, 5, tri('d8f0ff'))
    for (x, y) in ((4, 44), (12, 42), (19, 45)):
        cv.px(x + (f % 2), y - f % 3, C('ffffff'))
    return cv


def checkpoint(f):
    cv = Cv(40, 22)
    G = tri('ffb050')
    a = 0.6 + 0.2 * f
    for ang in range(0, 360, 4):
        x = 20 + 16 * math.cos(math.radians(ang)); y = 11 + 7 * math.sin(math.radians(ang))
        cv.px(x, y, G[2] if (ang // 20 + f) % 3 else G[1])
    for ang in range(0, 360, 8):
        x = 20 + 9 * math.cos(math.radians(ang + f * 20)); y = 11 + 4 * math.sin(math.radians(ang + f * 20))
        cv.px(x, y, G[1])
    cv.px(20, 11, G[2]); cv.px(19, 11, G[1]); cv.px(21, 11, G[1])
    return cv


def portal(f):
    cv = Cv(36, 40)
    P = tri('8a60ff')
    cv.blob(18, 22, 13, 17, tri('2a1a5a')); cv.blob(18, 22, 9, 13, tri('5a3ad0'))
    for k in range(10):
        a = math.radians(k * 36 + f * 18)
        cv.px(18 + 8 * math.cos(a), 22 + 12 * math.sin(a), C('e0d0ff'))
        cv.px(18 + 5 * math.cos(a + 1), 22 + 8 * math.sin(a + 1), C('a888ff'))
    cv.blob(18, 22, 3, 5, tri('ffffff'))
    cv.outline(OL); return cv


def gate(kind, size='small'):
    """stone archway; kind = locked/open. small 56x60, big 72x76."""
    w, h = (56, 60) if size == 'small' else (80, 84)
    cv = Cv(w, h)
    sw = 10 if size == 'small' else 14
    cv.srect(0, 8, sw, h - 8, STONE_D); cv.srect(w - sw, 8, sw, h - 8, STONE_D)
    cv.srect(0, 0, w, 14 if size == 'small' else 18, STONE)
    for x in range(4, w - 4, 8):
        cv.rect(x, 2, 1, 10, STONE[0])
    cv.rect(w // 2 - 3, 2, 6, 8, GOLD[1] if kind == 'open' else RUST[0]); cv.rect(w // 2 - 1, 3, 2, 6, C('120e1a'))
    inner = (sw, 14 if size == 'small' else 18, w - 2 * sw, h - (14 if size == 'small' else 18))
    if kind == 'open':
        cv.rect(*inner, C('08060e'))
        for y in range(inner[1], h, 3):
            cv.rect(inner[0], y, inner[2], 1, C('0c0a14'))
        cv.rect(inner[0], h - 2, inner[2], 2, C('1a1524'))
    else:
        cv.rect(*inner, C('1a1620'))
        for x in range(inner[0] + 2, inner[0] + inner[2] - 1, 5):
            cv.rect(x, inner[1], 2, inner[3], RUST[1]); cv.rect(x, inner[1], 1, inner[3], RUST[2])
        for y in (inner[1] + 6, inner[1] + inner[3] - 10):
            cv.rect(inner[0], y, inner[2], 2, RUST[0])
        cv.rect(w // 2 - 4, inner[1] + inner[3] // 2 - 4, 8, 8, GOLD[0]); cv.rect(w // 2 - 3, inner[1] + inner[3] // 2 - 3, 6, 6, GOLD[1])
        cv.px(w // 2, inner[1] + inner[3] // 2, OL); cv.rect(w // 2, inner[1] + inner[3] // 2, 1, 2, OL)
    cv.noise(0, 0, w, h, [MOSS[1]], 0.03, seed=7)
    cv.outline(OL); return cv


def switch(on):
    cv = Cv(20, 16)
    cv.blob(10, 9, 9, 5.5, STONE_D)
    P = tri('ffb050') if on else tri('6a5a70')
    cv.blob(10, 8, 6, 3.5, tri('2a2430') if not on else P)
    for a in range(0, 360, 45):
        cv.px(10 + 4 * math.cos(math.radians(a)), 8 + 2 * math.sin(math.radians(a)), P[2])
    cv.outline(OL); return cv


def pylon(on):
    cv = Cv(28, 52); shadow(cv, 14, 48, 11, 3)
    cv.srect(6, 12, 16, 34, STONE_D); cv.srect(3, 42, 22, 6, STONE); cv.srect(4, 8, 20, 6, STONE)
    P = tri('ffb050') if on else tri('6a5a70')
    cv.rect(11, 16, 6, 20, C('1a1620'))
    cv.rect(12, 18, 4, 16, P[1] if on else P[0]); cv.rect(13, 18, 2, 16, P[2] if on else P[1])
    cv.rect(9, 38, 10, 2, P[1])
    cv.outline(OL); return cv


def chain_link(i):
    cv = Cv(8, 8)
    c = tri('7a7a88')
    if i == 0:
        cv.rect(1, 2, 6, 4, c[1]); cv.rect(2, 3, 4, 2, C('120e1a')); cv.line(1, 2, 6, 2, c[2])
    else:
        cv.rect(2, 1, 4, 6, c[0]); cv.rect(3, 2, 2, 4, C('120e1a')); cv.line(2, 1, 2, 6, c[1])
    return cv


def rune_light(on):
    cv = Cv(10, 10)
    c = tri('ffb050')
    cv.blob(5, 5, 3.5, 3.5, c if on else tri('4a4058'))
    cv.outline(OL); return cv


def throne():
    cv = Cv(48, 60); shadow(cv, 24, 56, 20, 3)
    cv.srect(6, 44, 36, 12, STONE_D); cv.srect(10, 20, 28, 26, STONE)
    cv.srect(6, 4, 10, 36, STONE_D); cv.srect(32, 4, 10, 36, STONE_D)
    cv.poly([(6, 4), (11, -0), (16, 4)], STONE[1]); cv.poly([(32, 4), (37, 0), (42, 4)], STONE[1])
    cv.rect(14, 24, 20, 6, tri('6a2a3a')[1])
    cv.outline(OL); return cv


def gen(out):
    E = out + '/environment/'
    tree(1).save(E + 'tree_a.png'); tree(5).save(E + 'tree_b.png'); tree(2, True).save(E + 'tree_dead.png')
    bush().save(E + 'bush.png')
    statue('knight').save(E + 'statue_knight.png'); statue('hood').save(E + 'statue_hood.png'); statue('broken').save(E + 'statue_broken.png')
    skeleton().save(E + 'skeleton.png'); sword_grave().save(E + 'sword_grave.png')
    pillar().save(E + 'pillar.png'); pillar(True).save(E + 'pillar_broken.png'); pillar(False, True).save(E + 'pillar_cracked.png')
    rubble().save(E + 'rubble.png'); fallen_column().save(E + 'fallen_column.png')
    altar().save(E + 'altar.png'); fountain().save(E + 'fountain.png')
    crystal('single').save(E + 'crystal_a.png'); crystal('cluster').save(E + 'crystal_b.png'); crystal_block().save(E + 'crystal_block.png')
    stalagmite().save(E + 'stalagmite.png'); mushrooms().save(E + 'mushrooms.png'); bones().save(E + 'bones.png')
    flowers().save(E + 'flowers.png'); banner().save(E + 'banner.png'); throne().save(E + 'throne.png')
    sheet([brazier(i) for i in range(3)], E + 'brazier.png')
    sheet([waterfall(i) for i in range(4)], E + 'waterfall.png')
    sheet([checkpoint(i) for i in range(3)], E + 'checkpoint.png')
    sheet([portal(i) for i in range(4)], E + 'portal.png')
    gate('locked').save(E + 'gate_locked.png'); gate('open').save(E + 'gate_open.png')
    gate('locked', 'big').save(E + 'gate_final_locked.png'); gate('open', 'big').save(E + 'gate_final_open.png')
    switch(False).save(E + 'switch_off.png'); switch(True).save(E + 'switch_on.png')
    pylon(False).save(E + 'pylon_off.png'); pylon(True).save(E + 'pylon_on.png')
    chain_link(0).save(E + 'chain_a.png'); chain_link(1).save(E + 'chain_b.png')
    rune_light(False).save(E + 'rune_off.png'); rune_light(True).save(E + 'rune_on.png')
