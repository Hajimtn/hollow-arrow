"""Frames drawn for this game because the packs have none: floating elemental fists for the final boss (the pack has a single static pose
per elemental), a fire-breath cone for the Demon. Runs last, own palettes."""
import math
import random
from pix import *

OLN = C('120e1a')


def _fist_base(cv, pal, spike, cx, cy, open_hand):
    """a knuckled fist (or open palm) centred on (cx, cy), facing up: pal = (dark, base, light)"""
    d, b, l = pal
    if not open_hand:
        cv.blob(cx, cy + 2, 9, 8, pal)                       # the mass of the fist
        for k, x in enumerate((-6, -2, 2, 6)):               # four knuckles along the top
            cv.blob(cx + x, cy - 6, 3.2, 3.4, pal)
        cv.blob(cx - 10, cy + 1, 3.6, 5, pal)                # thumb
        cv.rect(cx - 7, cy - 2, 14, 1, d)                    # finger seam
        for x in (-6, -2, 2, 6):
            cv.px(cx + x, cy - 8, l)
    else:
        cv.blob(cx, cy + 5, 8.5, 7, pal)                     # palm
        for k, (x, h) in enumerate(((-7, 9), (-2.5, 12), (2.5, 12), (7, 9))):
            cv.rect(cx + x - 1.5, cy - 4 - h, 3, h + 3, b)
            cv.rect(cx + x - 1.5, cy - 4 - h, 1, h + 3, l)
            cv.rect(cx + x + 1, cy - 4 - h, 1, h + 3, d)
        cv.blob(cx - 10, cy + 3, 3.2, 5, pal)
    if spike:
        for x in (-6, -2, 2, 6):
            cv.poly([(cx + x - 1, cy - 8), (cx + x + 1, cy - 8), (cx + x, cy - 12)], spike)


def fist(form, open_hand):
    cv = Cv(34, 34)
    cx, cy = 17, 19
    if form == 1:                         # stone-fire: bronze plates, molten seams
        pal = tri('b07a3a')
        _fist_base(cv, pal, tri('e8a860')[2], cx, cy, open_hand)
        for (x, y) in ((cx - 4, cy + 2), (cx + 3, cy + 5), (cx, cy + 8), (cx + 5, cy - 1)):
            cv.px(x, y, C('ffd070')); cv.px(x + 1, y, C('ef6a2a'))
        cv.rect(cx - 6, cy - 3, 12, 1, C('ef6a2a'))
    elif form == 2:                       # tide: water and foam
        pal = tri('3a90e0')
        _fist_base(cv, pal, None, cx, cy, open_hand)
        for (x, y) in ((cx - 5, cy - 4), (cx + 2, cy), (cx - 2, cy + 6), (cx + 6, cy + 4)):
            cv.px(x, y, C('e8faff')); cv.px(x + 1, y + 1, C('a8e0ff'))
        cv.line(cx - 6, cy + 9, cx + 6, cy + 9, C('c8f0ff'))
    else:                                 # void-flame: violet crystal, flame licking up
        pal = tri('7a3ac0')
        _fist_base(cv, pal, tri('c86aff')[2], cx, cy, open_hand)
        for (x, y) in ((cx - 4, cy - 2), (cx + 4, cy + 3), (cx, cy + 7)):
            cv.px(x, y, C('ffffff')); cv.px(x, y + 1, C('e8b0ff'))
        for x in (-5, 0, 5):
            cv.poly([(cx + x - 2, cy - 9), (cx + x + 2, cy - 9), (cx + x, cy - 15)], C('ef6a2a'))
            cv.poly([(cx + x - 1, cy - 9), (cx + x + 1, cy - 9), (cx + x, cy - 12)], C('ffd070'))
    cv.outline(OLN)
    return cv


def breath_cone(f):
    """the Demon's fire breath, 4 frames of a cone widening to the right (48x36 cells); the game rotates it"""
    cv = Cv(64, 40)
    r = random.Random(30 + f)
    length = 22 + f * 12
    for x in range(length):
        k = x / 64.0
        half = 2 + k * 16 + math.sin(x * 0.4 + f) * 1.5
        for y in range(int(20 - half), int(20 + half) + 1):
            t = abs(y - 20) / max(half, 1.0)
            u = x / length
            if t < 0.35 and u < 0.85:
                col = C('fff4c0')
            elif t < 0.65:
                col = C('ffc060')
            elif t < 0.9:
                col = C('ef6a2a')
            else:
                col = C('c0401e')
            if r.random() < 0.9:
                cv.px(x, y, col)
    for _ in range(12):
        cv.px(r.randint(6, length), r.randint(4, 36), C('ffd070'))
    return cv


def _lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def frost_extra(out):
    """Frost Guardian frames the pack lacks. The armoured roar pose (arms raised) is recoloured to the plain ice body, giving a
    'raise' pose; moving its fists together over the head gives a 'clap'. Appended as row 5 of frost.png (cells 0-2 raise, 3-5 clap)."""
    from PIL import Image
    path = out + '/bosses/frost.png'
    sh = Image.open(path).convert('RGBA')
    if sh.height >= 64 * 6:
        sh = sh.crop((0, 0, sh.width, 64 * 5))
    raise_f, clap_f = [], []
    for idx in (68, 69, 70):
        c, r = idx % 16, idx // 16
        fr = sh.crop((c * 96, r * 64, c * 96 + 96, r * 64 + 64))
        px = fr.load()
        for y in range(64):
            for x in range(96):
                rr, gg, bb, a = px[x, y]
                if a < 128:
                    continue
                if rr > bb + 15 and rr > 90:
                    continue                                    # bracers and boots stay brown
                lum = (rr + gg + bb) / 3.0
                t = max(0.0, min(1.0, (lum - 25.0) / 130.0)) ** 0.8
                px[x, y] = _lerp((14, 34, 92), (104, 162, 226), t) + (255,)
        raise_f.append(fr)
        cl = Image.new('RGBA', (96, 64), (0, 0, 0, 0))
        cl.alpha_composite(fr)
        bbx = fr.getbbox()
        cx = (bbx[0] + bbx[2]) // 2
        cp = cl.load()
        moved = []
        for y in range(bbx[1], bbx[1] + 20):                    # the two raised fists sit in the top corners
            for x in range(bbx[0], bbx[2]):
                if cp[x, y][3] > 128 and abs(x - cx) > 11:
                    moved.append((x, y, cp[x, y]))
        for x, y, col in moved:
            cp[x, y] = (0, 0, 0, 0)
        for x, y, col in moved:
            nx = x + (7 if x < cx else -7)
            ny = y + 3
            if 0 <= nx < 96 and 0 <= ny < 64:
                cp[nx, ny] = col
        clap_f.append(cl)
    row = Image.new('RGBA', (96 * 16, 64), (0, 0, 0, 0))
    for i, f in enumerate(raise_f + clap_f):
        row.paste(f, (i * 96, 0))
    full = Image.new('RGBA', (sh.width, 64 * 6), (0, 0, 0, 0))
    full.paste(sh, (0, 0))
    full.paste(row, (0, 64 * 5))
    full.save(path)


def gen(out):
    B = out + '/bosses/'
    for form in (1, 2, 3):
        fist(form, False).save(B + 'final_fist_%d.png' % form)
        fist(form, True).save(B + 'final_palm_%d.png' % form)
    sheet([breath_cone(i) for i in range(4)], B + 'fire_breath.png')
    frost_extra(out)
    print('  drawn frames: 3 fists + 3 palms, fire breath, frost raise/clap')
