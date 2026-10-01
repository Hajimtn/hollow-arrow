"""Integrates the 'Forest of Dreams' pack (yanin, itch.io; own licence: commercial use + edits OK, no redistribution of the
pack itself). Runs LAST in gen_all:
  1. every generated sprite is colour-locked to the pack's 14-colour palette so the whole game shares one look,
  2. tiles, player, trees, pillars, bushes, pebbles and torches are rebuilt from cropped/tinted pack pixels.
Only these derived crops end up in assets/; the original archives stay in assets_src/ (ignored by Godot and the export)."""
import glob
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'assets_src', 'full')

PALETTE = [(0xc3, 0xbf, 0xad), (0xaa, 0x9a, 0x92), (0x82, 0x75, 0x72), (0xb2, 0x49, 0x49), (0xdb, 0x4f, 0x3a),
           (0xef, 0x8d, 0x35), (0x3d, 0x56, 0x41), (0x60, 0x7b, 0x66), (0x24, 0x20, 0x20), (0x71, 0x66, 0x7f),
           (0x52, 0x46, 0x66), (0x3d, 0x4b, 0x56), (0x60, 0x7b, 0x74), (0xf7, 0xef, 0xdf)]

_cache = {}


def nearest(rgb):
    if rgb in _cache:
        return _cache[rgb]
    best = min(PALETTE, key=lambda p: (p[0] - rgb[0]) ** 2 * 0.30 + (p[1] - rgb[1]) ** 2 * 0.59 + (p[2] - rgb[2]) ** 2 * 0.11)
    _cache[rgb] = best
    return best


def lock(im):
    im = im.convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            if a < 255:                       # soft ground shadows stay soft, but in the palette's darkest colour
                px[x, y] = (0x24, 0x20, 0x20, a)
                continue
            n = nearest((r, g, b))
            px[x, y] = n + (255,)
    return im


def sheet_crop(sheet, x0, y0, x1, y1, trim=True):
    im = sheet.crop((x0 * 16, y0 * 16, (x1 + 1) * 16, (y1 + 1) * 16))
    if trim:
        bb = im.getbbox()
        if bb:
            im = im.crop(bb)
    return im


def tint(im, target, t):
    im = im.convert('RGBA')
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r + (target[0] - r) * t), int(g + (target[1] - g) * t), int(b + (target[2] - b) * t), a)
    return im


def darken(im, t):
    return tint(im, (0x14, 0x10, 0x18), t)


# name: (kind, tint colour, strength, darken)
THEMES = {
    'hub': ('stone', None, 0, 0.0),
    'forest': ('grass', None, 0, 0.0),
    'courtyard': ('stone', (0xef, 0x8d, 0x35), 0.10, 0.0),
    'crystal': ('stone', (0x60, 0x7b, 0x74), 0.55, 0.0),
    'burrow': ('stone', (0xef, 0x8d, 0x35), 0.16, 0.0),
    'colossus': ('stone', (0xb2, 0x49, 0x49), 0.22, 0.25),
    'sky': ('stone', (0xf7, 0xef, 0xdf), 0.35, 0.0),
    'twins': ('stone', (0x71, 0x66, 0x7f), 0.55, 0.05),
    'final': ('stone', (0x52, 0x46, 0x66), 0.65, 0.30),
}


def make_tiles(sheet, bld, name):
    kind, tcol, ts, dk = THEMES[name]
    T = lambda cx, cy: sheet.crop((cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16)).convert('RGBA')
    stone = [T(6, 1), T(7, 1), T(7, 2)]
    grass = [T(6, 4), T(7, 4), T(6, 5)]
    floors = grass if kind == 'grass' else stone
    tiles = list(floors)
    tiles.append(T(5, 6) if kind == 'grass' else T(6, 8))                # 3 cracked / flowers
    top = Image.new('RGBA', (16, 16), (0x24, 0x20, 0x20, 255))          # 4 wall top
    tp = top.load()
    for (x, y) in ((2, 3), (7, 5), (11, 2), (4, 10), (12, 12), (9, 8), (1, 14), (14, 7)):
        tp[x, y] = (0x3d, 0x4b, 0x56, 255)
    for x in range(16):
        tp[x, 0] = (0x3d, 0x4b, 0x56, 255)
    tiles.append(top)
    tiles.append(bld.crop((16, 9 * 16, 32, 10 * 16)).convert('RGBA'))    # 5 wall face: brick
    tiles.append(Image.new('RGBA', (16, 16), (0x1a, 0x16, 0x18, 255)))   # 6 void
    rune = stone[0].copy()                                               # 7 rune floor
    rp = rune.load()
    import math
    for a in range(0, 360, 5):
        x = int(8 + 5.5 * math.cos(math.radians(a)))
        y = int(8 + 5.5 * math.sin(math.radians(a)))
        rp[x, y] = (0xef, 0x8d, 0x35, 255)
    rp[8, 8] = (0xf7, 0xef, 0xdf, 255)
    tiles.append(rune)
    tiles.append(stone[1].copy() if kind == 'grass' else grass[0].copy())  # 8 accent
    tiles.append(T(7, 8) if kind != 'grass' else T(3, 4))                # 9 rubble / moss
    tiles.append(darken(stone[0] if kind != 'grass' else grass[0], 0.35))  # 10 dark
    crater = stone[0].copy()                                             # 11 crater
    cp = crater.load()
    for y in range(16):
        for x in range(16):
            if ((x - 8) / 6.5) ** 2 + ((y - 8) / 5.0) ** 2 <= 1:
                cp[x, y] = (0x3d, 0x4b, 0x56, 255) if ((x - 8) / 6.5) ** 2 + ((y - 8) / 5.0) ** 2 > 0.5 else (0x24, 0x20, 0x20, 255)
    tiles.append(crater)
    out = Image.new('RGBA', (16 * 12, 16), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        if tcol is not None and i not in (7,):
            t = tint(t, tcol, ts)
        if dk:
            t = darken(t, dk)
        if i in (0, 1, 2, 3, 8, 9):
            t = darken(t, 0.30)       # keep the floor calm so sprites and telegraphs stand out against it
        out.paste(t, (i * 16, 0))
    return out


def make_player(hero):
    """Rebuild the 10x4 player sheet (24x24 frames) from the pack's hero frames."""
    def cell(cx, cy, flip=False):
        c = hero.crop((cx * 16, cy * 16, cx * 16 + 16, cy * 16 + 16)).convert('RGBA')
        if flip:
            c = c.transpose(Image.FLIP_LEFT_RIGHT)
        return c
    out = Image.new('RGBA', (24 * 10, 24 * 4), (0, 0, 0, 0))

    def put(idx, img):
        col, row = idx % 10, idx // 10
        out.alpha_composite(img, (col * 24 + 4, row * 24 + 6))

    for d, (g, flip) in enumerate(((0, False), (6, False), (12, True))):
        base = d * 10
        put(base + 0, cell(g + 0, 0, flip)); put(base + 1, cell(g + 1, 0, flip))
        for i in range(4):
            put(base + 2 + i, cell(g + i, 1, flip))
        put(base + 6, cell(g + 3, 2, flip))          # shoot: arm out
        put(base + 7, cell(g + 0, 6, flip))          # recall: hands up
        put(base + 8, cell(2, 4)); put(base + 9, cell(3, 4))   # dodge roll (a tucked ball)
    for i, (cx, cy) in enumerate(((0, 3), (8, 8), (9, 8), (10, 8))):
        put(30 + i, cell(cx, cy))
    return rim_light(out)


def rim_light(im):
    """the hero is dark purple; a 1 px light rim keeps it readable on dark arenas"""
    src = im.copy()
    sp, dp = src.load(), im.load()
    for y in range(im.height):
        for x in range(im.width):
            if sp[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < im.width and 0 <= yy < im.height and sp[xx, yy][3] > 200:
                        dp[x, y] = (0xc3, 0xbf, 0xad, 255)
                        break
    return im


def gen(out):
    sheet = Image.open(os.path.join(SRC, 'ground_tiles_02.png')).convert('RGBA')
    bld = Image.open(os.path.join(SRC, 'building_tiles_02.png')).convert('RGBA')
    flora = Image.open(os.path.join(SRC, 'flora_02.png')).convert('RGBA')
    rocks = Image.open(os.path.join(SRC, 'rocks_02.png')).convert('RGBA')
    props = Image.open(os.path.join(SRC, 'props_02.png')).convert('RGBA')
    hero = Image.open(os.path.join(SRC, 'hero_02.png')).convert('RGBA')

    # 1) colour-lock everything we drew ourselves (not the UI, which keeps its own look)
    for sub in ('bosses', 'environment', 'player', 'vfx', 'ui'):
        for f in glob.glob(os.path.join(out, sub, '*.png')):
            if os.path.basename(f).startswith('font_'):
                continue        # bitmap fonts stay white; the colour comes from the labels
            lock(Image.open(f)).save(f)

    # 2) pack-derived art
    env = os.path.join(out, 'environment')
    for name in THEMES:
        make_tiles(sheet, bld, name).save(os.path.join(env, f'tiles_{name}.png'))
    make_player(hero).save(os.path.join(out, 'player', 'player.png'))

    def save(im, name):
        im.save(os.path.join(env, name + '.png'))

    save(sheet_crop(flora, 2, 2, 3, 3), 'tree_a')
    save(sheet_crop(flora, 4, 5, 6, 7), 'tree_b')
    save(sheet_crop(flora, 6, 2, 7, 3), 'tree_dead')
    save(sheet_crop(flora, 4, 0, 4, 0), 'bush')
    save(sheet_crop(rocks, 0, 0, 1, 0), 'rubble')
    save(sheet_crop(props, 12, 1, 12, 3), 'pillar')
    save(sheet_crop(props, 11, 2, 11, 3), 'pillar_broken')
    cracked = sheet_crop(props, 12, 1, 12, 3).convert('RGBA')
    cp = cracked.load()
    for (x, y) in ((8, 6), (7, 8), (8, 10), (9, 12), (8, 14), (7, 16), (8, 18)):
        if x < cracked.width and y < cracked.height:
            cp[x, y] = (0x24, 0x20, 0x20, 255)
    cp[8, 12] = (0xef, 0x8d, 0x35, 255)
    save(cracked, 'pillar_cracked')
    # braziers: three flame frames (20 px wide cells so Gfx.strip works unchanged)
    frames = []
    for i in range(3):
        fr = bld.crop((i * 16, 11 * 16, i * 16 + 16, 12 * 16)).convert('RGBA')
        c = Image.new('RGBA', (20, 22), (0, 0, 0, 0))
        c.alpha_composite(fr, (2, 6))
        frames.append(c)
    sheetb = Image.new('RGBA', (60, 22), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheetb.alpha_composite(fr, (i * 20, 0))
    save(sheetb, 'brazier')
    print('  pack: tiles x%d, player, decor' % len(THEMES))
