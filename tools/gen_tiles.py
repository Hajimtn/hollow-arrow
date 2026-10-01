from pix import *

# name: (floor, floor_alt, wall_face, wall_top, accent)
THEMES = {
    'hub':      ('4d5561', '444b57', '6b6470', '2a2a36', '7a9a6a'),
    'forest':   ('3f5a3a', '374f34', '55604e', '1c2a22', '6a8a3a'),
    'courtyard': ('6a6258', '5f574f', '857a6c', '2d2a2c', '9a6a3a'),
    'crystal':  ('3a4666', '333e5c', '5a6a9a', '161a30', '7ad0ff'),
    'burrow':   ('7a5c3c', '6e5236', '8f6a44', '2c1e16', 'c49a5a'),
    'colossus': ('4a4448', '423c40', '6e5a52', '1e1a1c', 'c8703a'),
    'sky':      ('8a92a2', '7c8496', 'aab2c2', '3a4258', 'e8f0ff'),
    'twins':    ('4e4462', '463c5a', '6e6088', '1c1830', 'e0a850'),
    'final':    ('2c2838', '262232', '4a3f58', '100c18', 'e8b840'),
}


def make_tiles(name):
    f, fa, wf, wt, ac = THEMES[name]
    F, FA, WF, WT, AC = tri(f), tri(fa), tri(wf), tri(wt), tri(ac)
    cv = Cv(16 * 12, 16)

    def tile(i):
        t = Cv(16, 16)
        return t, i * 16

    # 0-2 floor variants
    for i in range(3):
        t = Cv(16, 16)
        pal = F if i != 1 else FA
        t.rect(0, 0, 16, 16, pal[1])
        t.noise(0, 0, 16, 16, [pal[0], pal[2]], 0.10, seed=10 + i)
        # stone slab seams
        t.rect(0, 15, 16, 1, pal[0]); t.rect(15, 0, 1, 16, pal[0])
        if i == 2:
            t.rect(0, 7, 16, 1, pal[0])
            t.rect(7, 0, 1, 8, pal[0])
        cv.paste(t, i * 16, 0)
    # 3 cracked floor
    t = Cv(16, 16); t.rect(0, 0, 16, 16, F[1]); t.noise(0, 0, 16, 16, [F[0], F[2]], 0.1, seed=4)
    t.rect(0, 15, 16, 1, F[0]); t.rect(15, 0, 1, 16, F[0])
    for a, b in (((3, 2), (7, 7)), ((7, 7), (6, 12)), ((7, 7), (13, 9))):
        t.line(a[0], a[1], b[0], b[1], F[0])
    cv.paste(t, 3 * 16, 0)
    # 4 wall top
    t = Cv(16, 16); t.rect(0, 0, 16, 16, WT[1]); t.noise(0, 0, 16, 16, [WT[0], WT[2]], 0.12, seed=5)
    t.rect(0, 0, 16, 1, WT[2]); t.rect(0, 8, 16, 1, WT[0]); t.rect(8, 0, 1, 8, WT[0]); t.rect(4, 8, 1, 8, WT[0])
    cv.paste(t, 4 * 16, 0)
    # 5 wall face (bricks)
    t = Cv(16, 16); t.rect(0, 0, 16, 16, WF[1])
    t.rect(0, 0, 16, 2, WF[2])
    for y in (5, 10, 15):
        t.rect(0, y, 16, 1, WF[0])
    for (y0, off) in ((2, 4), (6, 10), (11, 4)):
        t.rect(off, y0, 1, 3 if y0 != 6 else 4, WF[0])
    t.rect(0, 14, 16, 2, WF[0])
    t.noise(0, 2, 16, 12, [WF[0], WF[2]], 0.08, seed=6)
    if name == 'crystal':
        for k in range(-16, 16, 6):
            t.line(k, 15, k + 12, 1, AC[1]); t.line(k + 1, 15, k + 13, 1, AC[2])
        t.rect(0, 0, 16, 1, AC[2])
    cv.paste(t, 5 * 16, 0)
    # 6 void
    t = Cv(16, 16); t.rect(0, 0, 16, 16, mix(WT[0], (0, 0, 0, 255), 0.4))
    cv.paste(t, 6 * 16, 0)
    # 7 rune floor (glowing ring)
    t = Cv(16, 16); t.rect(0, 0, 16, 16, F[1]); t.noise(0, 0, 16, 16, [F[0], F[2]], 0.1, seed=7)
    for a in range(0, 360, 6):
        x = 8 + 5.5 * math.cos(math.radians(a)); y = 8 + 5.5 * math.sin(math.radians(a))
        t.px(x, y, AC[2])
    t.px(8, 8, AC[2]); t.px(7, 8, AC[1]); t.px(9, 8, AC[1]); t.px(8, 7, AC[1]); t.px(8, 9, AC[1])
    cv.paste(t, 7 * 16, 0)
    # 8 accent floor (moss / sand / frost)
    t = Cv(16, 16); t.rect(0, 0, 16, 16, mix(F[1], AC[1], 0.35)); t.noise(0, 0, 16, 16, [AC[0], AC[2], F[0]], 0.14, seed=8)
    cv.paste(t, 8 * 16, 0)
    # 9 rubble floor
    t = Cv(16, 16); t.rect(0, 0, 16, 16, F[1]); t.noise(0, 0, 16, 16, [F[0]], 0.1, seed=9)
    for (x, y, r) in ((3, 4, 2), (10, 3, 1.5), (7, 10, 2.2), (13, 12, 1.5)):
        t.blob(x, y, r, r, F if (x + y) % 2 else FA)
    cv.paste(t, 9 * 16, 0)
    # 10 dark floor (scorched)
    t = Cv(16, 16); t.rect(0, 0, 16, 16, mix(F[1], (0, 0, 0, 255), 0.35)); t.noise(0, 0, 16, 16, [F[0]], 0.12, seed=11)
    t.rect(0, 15, 16, 1, F[0]); t.rect(15, 0, 1, 16, F[0])
    cv.paste(t, 10 * 16, 0)
    # 11 crater (colossus / burrower damage)
    t = Cv(16, 16); t.rect(0, 0, 16, 16, F[1]); t.noise(0, 0, 16, 16, [F[0], F[2]], 0.1, seed=12)
    t.blob(8, 8, 6.5, 5.5, (F[2], F[0], mix(F[0], (0, 0, 0, 255), .3)), light=(0.5, 0.7))
    cv.paste(t, 11 * 16, 0)
    return cv


def gen(out):
    for n in THEMES:
        make_tiles(n).save(f'{out}/environment/tiles_{n}.png')
