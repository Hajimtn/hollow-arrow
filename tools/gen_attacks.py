"""Sprites for the boss attack kit (falling/rising strikes, projectiles, the ice shield family). Runs last, own palettes."""
import math
import random
from pix import *

OLN = C('120e1a')


def icicle_fall():
    cv = Cv(12, 30); P = tri('bfe4ff')
    cv.poly([(1, 0), (11, 0), (6, 29)], P[1])
    cv.poly([(1, 0), (6, 0), (6, 29)], P[2]); cv.poly([(6, 0), (11, 0), (6, 29)], P[0])
    cv.line(4, 2, 6, 18, C('ffffff'))
    cv.outline(OLN); return cv


def ice_spike():
    cv = Cv(14, 30); P = tri('9fd8ff')
    cv.poly([(7, 0), (13, 29), (1, 29)], P[1]); cv.poly([(7, 0), (1, 29), (7, 29)], P[2]); cv.poly([(7, 0), (13, 29), (10, 29)], P[0])
    cv.line(6, 6, 5, 24, C('ffffff'))
    cv.outline(OLN); return cv


def arrow_drop():
    cv = Cv(8, 26)
    cv.rect(3, 4, 2, 20, C('c8b48a')); cv.rect(3, 4, 1, 20, C('e8dcb8'))
    cv.poly([(1, 24), (7, 24), (4, 29)], C('d8e0ea')); cv.px(3, 26, C('ffffff'))
    cv.poly([(0, 0), (3, 0), (3, 6)], C('7a9a70')); cv.poly([(5, 0), (8, 0), (5, 6)], C('7a9a70'))
    cv.outline(OLN); return cv


def fire_drop():
    cv = Cv(16, 26)
    cv.poly([(8, 0), (14, 8), (12, 14), (8, 16), (4, 14), (2, 8)], C('c0401e'))
    cv.blob(8, 18, 6, 6, tri('ef6a2a')); cv.blob(8, 19, 3.5, 4, tri('ffc060'))
    cv.px(8, 22, C('ffe9a0'))
    cv.outline(OLN); return cv


def orb_fire():
    cv = Cv(14, 14)
    cv.blob(7, 7, 6, 6, tri('ef6a2a')); cv.blob(7, 7, 3.5, 3.5, tri('ffc060')); cv.px(7, 7, C('fff4c0'))
    for (x, y) in ((3, 2), (10, 1), (12, 5)):
        cv.px(x, y, C('ff9a3a'))
    cv.outline(OLN); return cv


def wisp():
    cv = Cv(14, 16)
    cv.blob(7, 8, 5.5, 6.5, (C('1a1424'), C('2a1e3a'), C('4a3a66')))
    cv.poly([(3, 12), (11, 12), (7, 16)], C('2a1e3a'))
    cv.px(5, 7, C('ff5030')); cv.px(9, 7, C('ff5030')); cv.px(5, 8, C('ff9a60')); cv.px(9, 8, C('ff9a60'))
    cv.outline(C('6a5a90')); return cv


def claw():
    cv = Cv(18, 26); P = (C('1a1030'), C('3a2266'), C('6a4aa8'))
    for k, x in enumerate((3, 7, 11, 15)):
        h = 22 - abs(k - 1.5) * 3
        cv.poly([(x - 2, 25), (x + 2, 25), (x + (k - 1.5), 25 - h)], P[1])
        cv.line(x, 24, x + (k - 1.5), 25 - h, P[2])
    cv.rect(2, 22, 15, 3, P[0])
    cv.outline(OLN); return cv


def bone_hand():
    cv = Cv(16, 28); B = tri('d8ccb0')
    cv.rect(6, 12, 4, 16, B[1]); cv.rect(6, 12, 1, 16, B[2])
    for k, x in enumerate((2, 5, 8, 11)):
        cv.line(x + 1, 12, x, 2 + (k % 2) * 2, B[1]); cv.line(x + 2, 12, x + 1, 2 + (k % 2) * 2, B[0])
    cv.blob(8, 14, 5.5, 3.5, B)
    cv.outline(OLN); return cv


def stone_spike():
    cv = Cv(18, 30); S = tri('8a94a0')
    cv.poly([(9, 0), (16, 8), (14, 29), (4, 29), (2, 8)], S[1])
    cv.poly([(9, 0), (2, 8), (4, 29), (9, 29)], S[2]); cv.poly([(9, 0), (16, 8), (14, 29), (12, 29)], S[0])
    cv.line(9, 6, 8, 24, C('5fe0e0'))
    cv.outline(OLN); return cv


def flame_col():
    cv = Cv(20, 40)
    for (x, hw, col) in ((10, 8, 'c0401e'), (10, 6, 'ef6a2a'), (10, 3.5, 'ffc060')):
        cv.poly([(10 - hw, 39), (10 + hw, 39), (10 + hw * 0.6, 20), (10, 2), (10 - hw * 0.6, 20)], C(col))
    cv.outline(OLN); return cv


def ice_shard():
    cv = Cv(12, 12); P = tri('cfeaff')
    cv.poly([(1, 6), (6, 1), (11, 6), (6, 11)], P[1]); cv.poly([(1, 6), (6, 1), (6, 6)], P[2]); cv.px(6, 6, C('ffffff'))
    cv.outline(OLN); return cv


def ice_shield(size):
    """kite-shaped ice shield seen edge-on from above the way the old bar was: tall, translucent, cracked, with a frosted rim
    and a raised central ridge. size 1 = guardian, 2 = carapace (bigger, spiked)."""
    h = 54 if size == 1 else 66
    w = 18 if size == 1 else 22
    cv = Cv(w, h)
    cx = w // 2
    pts = [(cx, 0), (w - 2, 8), (w - 1, h // 2), (w - 3, h - 10), (cx, h - 1), (2, h - 10), (0, h // 2), (1, 8)]
    body = (150, 214, 255, 190)
    rim = (232, 248, 255, 255)
    deep = (86, 150, 214, 220)
    cv.poly(pts, body)
    # gradient bands + inner facets
    for y in range(h):
        for x in range(w):
            p = cv.p[x, y]
            if p[3] == 0:
                continue
            k = (x - 1) / max(1, w - 2)
            if k > 0.62:
                cv.p[x, y] = deep
            elif k < 0.28:
                cv.p[x, y] = (200, 236, 255, 205)
    # central ridge and facets
    cv.line(cx, 3, cx, h - 4, rim)
    cv.line(cx - 1, 6, cx - 3, h // 2, (230, 246, 255, 230)); cv.line(cx + 1, 6, cx + 3, h // 2, (110, 170, 226, 230))
    # frosted rim
    src = cv.im.copy(); sp = src.load()
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] > 0:
                edge = any(sp[xx, yy][3] == 0 for xx, yy in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)) if 0 <= xx < w and 0 <= yy < h)
                if edge or x in (0, w - 1) or y in (0, h - 1):
                    cv.p[x, y] = rim
    # cracks
    r = random.Random(5 + size)
    for (x0, y0) in ((cx - 4, 14), (cx + 3, h // 2 + 4)):
        x, y = x0, y0
        for _ in range(5):
            nx, ny = x + r.randint(-1, 2), y + r.randint(2, 4)
            cv.line(x, y, nx, ny, (255, 255, 255, 255))
            x, y = nx, ny
    # frost sparkles
    for _ in range(6 + 3 * size):
        x, y = r.randint(2, w - 3), r.randint(4, h - 5)
        if cv.p[x, y][3] > 0:
            cv.p[x, y] = (255, 255, 255, 255)
    if size == 2:                                    # carapace: spikes along both edges
        for y in range(10, h - 8, 12):
            cv.poly([(0, y), (-0, y + 5), (0, y + 2)], rim)
            cv.px(w - 1, y, rim); cv.px(w - 2, y + 1, rim)
    cv.outline(C('2a4a7a'))
    return cv


def ice_slab():
    """a wall segment the guardian raises: thick frosted pillar of ice, 16 wide, 44 tall"""
    cv = Cv(18, 46)
    P = tri('9fd8ff')
    cv.poly([(2, 8), (9, 0), (16, 8), (16, 42), (2, 42)], P[1])
    cv.poly([(9, 0), (2, 8), (2, 42), (9, 42)], P[2]); cv.poly([(9, 0), (16, 8), (16, 42), (12, 42)], P[0])
    cv.line(6, 8, 6, 36, C('ffffff')); cv.line(12, 12, 12, 30, C('e0f6ff'))
    for (x, y) in ((4, 14), (10, 20), (13, 34), (5, 30)):
        cv.px(x, y, C('ffffff'))
    cv.rect(0, 42, 18, 3, tri('3a5a90')[1]); cv.rect(0, 44, 18, 1, tri('3a5a90')[0])
    cv.outline(OLN); return cv


def mirror_plate():
    """orbiting prism plate: a thin, lozenge of faceted ice-glass"""
    cv = Cv(12, 30); P = tri('cfeaff')
    cv.poly([(6, 0), (11, 8), (11, 22), (6, 29), (1, 22), (1, 8)], P[1])
    cv.poly([(6, 0), (1, 8), (1, 22), (6, 29)], P[2]); cv.poly([(6, 0), (11, 8), (11, 22), (6, 29)], P[0])
    cv.line(6, 3, 6, 26, C('ffffff')); cv.line(3, 10, 3, 20, C('e8f8ff'))
    for (x, y) in ((4, 7), (8, 15), (3, 24)):
        cv.px(x, y, C('ffffff'))
    cv.outline(C('2a4a7a')); return cv


def arrow_shot():
    cv = Cv(18, 7)
    cv.rect(3, 3, 12, 1, C('c8b48a')); cv.rect(3, 2, 12, 1, C('e8dcb8'))
    cv.poly([(15, 0), (18, 3), (15, 6)], C('d8e0ea')); cv.px(16, 3, C('ffffff'))
    cv.poly([(0, 0), (4, 3), (0, 6)], C('7a9a70')); cv.px(2, 3, C('a8c890'))
    cv.outline(OLN); return cv


def bolt():
    cv = Cv(14, 44)
    pts = [(7, 0), (10, 8), (5, 14), (10, 22), (4, 30), (8, 43)]
    for a, b in zip(pts, pts[1:]):
        cv.line(a[0], a[1], b[0], b[1], C('fff6a0')); cv.line(a[0] + 1, a[1], b[0] + 1, b[1], C('ffe040'))
    cv.outline(C('c08a20')); return cv


def scythe_drop():
    cv = Cv(28, 52)
    cv.line(20, 0, 20, 46, C('4a3a34')); cv.line(21, 0, 21, 46, C('2a1e1a'))
    cv.poly([(20, 6), (1, 14), (3, 30), (9, 20), (20, 16)], C('c3bfad'))
    cv.poly([(20, 6), (1, 14), (8, 14), (20, 11)], C('f7efdf'))
    cv.line(4, 28, 9, 19, C('8a8378'))
    cv.outline(OLN); return cv


def disc_drop(warm):
    cv = Cv(30, 30)
    if warm:
        cv.blob(15, 15, 13, 13, tri('ef8d35')); cv.blob(15, 15, 8, 8, tri('ffc060')); cv.px(15, 15, C('fff4c0'))
        for a in range(0, 360, 45):
            cv.px(15 + 14 * math.cos(math.radians(a)), 15 + 14 * math.sin(math.radians(a)), C('ffe08a'))
    else:
        cv.blob(15, 15, 13, 13, tri('8a80e0')); cv.blob(19, 13, 9, 10, (C('241c5a'), C('241c5a'), C('241c5a')))
        cv.px(8, 10, C('e8d8ff')); cv.px(10, 20, C('e8d8ff'))
    cv.outline(OLN); return cv


def gen(out):
    E = out + '/bosses/'
    for name, fn in (('icicle_fall', icicle_fall), ('ice_spike', ice_spike), ('arrow_drop', arrow_drop), ('fire_drop', fire_drop),
                     ('orb_fire', orb_fire), ('wisp', wisp), ('claw', claw), ('bone_hand', bone_hand), ('stone_spike', stone_spike),
                     ('flame_col', flame_col), ('arrow_shot', arrow_shot), ('sun_big', lambda: disc_drop(True)), ('moon_big', lambda: disc_drop(False)), ('scythe_drop', scythe_drop), ('bolt', bolt), ('ice_shard', ice_shard), ('ice_slab', ice_slab), ('mirror_plate', mirror_plate)):
        fn().save(E + name + '.png')
    ice_shield(1).save(E + 'ice_shield.png')
    ice_shield(2).save(E + 'ice_shield2.png')
    print('  attack kit sprites')
