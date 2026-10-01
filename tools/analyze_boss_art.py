"""Measures where each boss pack's 'glowing part' is in every animation frame, so the game's weak-point hit circle
can follow the artwork exactly (a weak point must only be armed while the artwork shows it open).
Writes data/boss_anchors.json:  {asset: {anim: [{"bbox":[x0,y0,x1,y1], "pts":[[x,y],...], "n":pixels}, ...]}}
Coordinates are frame-local pixels, origin top-left of the frame."""
import json
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'assets_src', 'bosspacks')

GOLEM = os.path.join(SRC, 'Mecha-stone_Golem_0.1', 'Mecha-stone Golem 0.1', 'PNG sheet', 'Character_sheet.png')
FROST = os.path.join(SRC, 'Frost_Guardian_FREE_v1.0', 'Frost_Guardian_FREE_v1.0', 'frost_guardian_free_192x128_SpriteSheet.png')
DEMON = os.path.join(SRC, 'boss_demon_slime_FREE_v1.0', 'boss_demon_slime_FREE_v1.0', 'spritesheets', 'demon_slime_FREE_v1.0_288x160_spritesheet.png')
WIZ = os.path.join(SRC, 'EVil_Wizard_2', 'EVil Wizard 2', 'Sprites')
EXE = os.path.join(SRC, 'Undead_executioner', 'Undead executioner puppet', 'png')

# colour keys: predicate on (r, g, b) that picks the "part that must glow / be open"
KEYS = {
    'golem': lambda r, g, b: b > 170 and g > 140 and r < 130,                      # cyan crystal
    'frost': lambda r, g, b: r > 70 and g < 70 and b < 90 and r > g + 25,            # brown chest socket
    'demon': lambda r, g, b: r > 235 and g > 170 and b < 110,                        # yellow flame orbs
    'wizard': lambda r, g, b: r > 190 and g < 110 and b < 140 and r > b + 60,        # red staff gem / eyes
    'exec': lambda r, g, b: 95 < r < 115 and 50 < g < 65 and 40 < b < 60,            # the two ember eyes
}

# (asset, anim, sheet, cell w, cell h, row, first col, frame count)
GRID = {
    'golem': (GOLEM, 100, 100, {'idle': (0, 0, 4), 'charge': (1, 0, 8), 'arm_shot': (2, 0, 9), 'curl': (3, 0, 8),
                                'arm_throw': (4, 0, 7), 'hurt': (5, 0, 7), 'slam': (6, 0, 10), 'death': (7, 0, 10),
                                'death2': (8, 0, 4)}),
    'frost': (FROST, 192, 128, {'idle': (0, 0, 6), 'walk': (1, 0, 10), 'punch': (2, 0, 14), 'hurt': (3, 0, 7),
                               'death': (4, 0, 16)}),
    'demon': (DEMON, 288, 160, {'idle': (0, 0, 6), 'walk': (1, 0, 12), 'cleave': (2, 0, 15), 'hurt': (3, 0, 5),
                               'death': (4, 0, 22)}),
}


def frames(path, cw, ch, row, col0, n):
    sh = Image.open(path).convert('RGBA')
    return [sh.crop(((col0 + i) * cw, row * ch, (col0 + i + 1) * cw, (row + 1) * ch)) for i in range(n)]


def measure(im, pred):
    px = im.load()
    pts = [(x, y) for y in range(im.height) for x in range(im.width) if px[x, y][3] > 200 and pred(*px[x, y][:3])]
    return pts


def clusters(pts, gap=6, min_n=3):
    """split points into blobs (flame orbs come in pairs)"""
    out = []
    for p in sorted(pts):
        for c in out:
            if any(abs(p[0] - q[0]) <= gap and abs(p[1] - q[1]) <= gap for q in c[-30:]):
                c.append(p)
                break
        else:
            out.append([p])
    return [c for c in out if len(c) >= min_n]


def strip_frames(path, cw, ch):
    sh = Image.open(path).convert('RGBA')
    return [sh.crop((i * cw, 0, (i + 1) * cw, ch)) for i in range(sh.width // cw)]


def main():
    data = {}
    for key, (path, cw, ch, anims) in GRID.items():
        data[key] = {}
        for name, (row, c0, n) in anims.items():
            rec = []
            for im in frames(path, cw, ch, row, c0, n):
                bb = im.getbbox()
                pts = measure(im, KEYS[key])
                cl = clusters(pts)
                rec.append({'bbox': list(bb) if bb else None, 'n': len(pts),
                            'pts': [[round(sum(p[0] for p in c) / len(c), 1), round(sum(p[1] for p in c) / len(c), 1)] for c in cl]})
            data[key][name] = rec
    data['wizard'] = {}
    for name, fn in (('idle', 'Idle'), ('run', 'Run'), ('attack1', 'Attack1'), ('attack2', 'Attack2'), ('hurt', 'Take hit'), ('death', 'Death')):
        rec = []
        for im in strip_frames(os.path.join(WIZ, fn + '.png'), 250, 250):
            bb = im.getbbox()
            cl = clusters(measure(im, KEYS['wizard']))
            rec.append({'bbox': list(bb) if bb else None, 'n': sum(len(c) for c in cl),
                        'pts': [[round(sum(p[0] for p in c) / len(c), 1), round(sum(p[1] for p in c) / len(c), 1)] for c in cl]})
        data['wizard'][name] = rec
    data['exec'] = {}
    for name, fn in (('idle', 'idle'), ('idle2', 'idle2'), ('attack', 'attacking'), ('skill', 'skill1'), ('summon', 'summon'), ('death', 'death')):
        rec = []
        for im in strip_frames(os.path.join(EXE, fn + '.png'), 100, 100):
            bb = im.getbbox()
            cl = clusters(measure(im, KEYS["exec"]), 12, 2)
            rec.append({'bbox': list(bb) if bb else None, 'n': sum(len(c) for c in cl),
                        'pts': [[round(sum(p[0] for p in c) / len(c), 1), round(sum(p[1] for p in c) / len(c), 1)] for c in cl]})
        data['exec'][name] = rec
    os.makedirs(os.path.join(HERE, '..', 'data'), exist_ok=True)
    json.dump(data, open(os.path.join(HERE, '..', 'data', 'boss_anchors.json'), 'w'))
    for k, anims in data.items():
        print('==', k)
        for a, rec in anims.items():
            print('  %-10s' % a, ' '.join('%d:%s' % (i, ','.join('(%d,%d)' % tuple(p) for p in f['pts']) or '-') for i, f in enumerate(rec)))


def orb_track(data):
    """the two flame orbs of the demon (the clusters above y=92), per frame, relative to the 170x130 trimmed cell centre"""
    def per(anim):
        out = []
        for f in data['demon'][anim]:
            orbs = sorted([p for p in f['pts'] if p[1] < 92 and 60 < p[0] < 230])
            if len(orbs) < 2:
                out.append(None)
                continue
            l, r = orbs[0], orbs[-1]
            out.append([(l[0] - 145.0, l[1] - 95.0), (r[0] - 145.0, r[1] - 95.0)])
        return out
    return per('idle'), per('cleave')


def hunter_track(row=4, n=6):
    """head (the black face) and quiver (brown) of the archer per frame of a hunter.png row, relative to the 64x64 cell centre"""
    im = Image.open(os.path.join(HERE, '..', 'assets', 'bosses', 'hunter.png')).convert('RGBA')
    heads, quivers = [], []
    for c in range(n):
        cell = im.crop((c * 64, row * 64, c * 64 + 64, row * 64 + 64))
        px = cell.load()
        hd = [(x, y) for y in range(64) for x in range(64) if px[x, y][3] > 200 and px[x, y][0] < 10 and px[x, y][1] < 10 and px[x, y][2] < 10]
        if not hd:
            heads.append((0.0, -6.0))
            quivers.append((-6.0, -6.0))
            continue
        hx = sum(p[0] for p in hd) / len(hd)
        hy = sum(p[1] for p in hd) / len(hd)
        q = [(x, y) for y in range(64) for x in range(64) if px[x, y][3] > 200 and px[x, y][0] > 60 and px[x, y][0] > px[x, y][1] + 15
             and px[x, y][2] < 70 and hy - 9 < y < hy + 5 and x < hx - 2]
        heads.append((hx - 32.0, hy - 32.0))
        quivers.append(((sum(p[0] for p in q) / len(q) - 32.0, sum(p[1] for p in q) / len(q) - 32.0) if q else (hx - 38.0, hy - 32.0)))
    return heads, quivers


def write_gd(data):
    idle, cleave = orb_track(data)
    heads, quivers = hunter_track()
    v2 = lambda a: ',\n\t'.join('Vector2(%.1f, %.1f)' % p for p in a)
    def fmt(track):
        rows = []
        for e in track:
            if e is None:
                rows.append('[Vector2.ZERO, Vector2.ZERO]')
            else:
                rows.append('[Vector2(%.1f, %.1f), Vector2(%.1f, %.1f)]' % (e[0][0], e[0][1], e[1][0], e[1][1]))
        return ',\n\t'.join(rows)
    txt = '''class_name BossAnchors
## GENERATED by tools/analyze_boss_art.py - do not edit. Weak-point positions measured on the boss sprite sheets.
## Demon Slime flame orbs, per frame, relative to the centre of its 170x130 trimmed cell (the sheet faces LEFT).
const DEMON_ORBS_IDLE := [
\t%s
]
const DEMON_ORBS_CLEAVE := [
\t%s
]
## Archer (hunter.png row 4, the kneeling aim loop): the black hooded face and the brown quiver, relative to the 64x64 cell centre
## (the sheet faces RIGHT).
const HUNTER_KNEEL_HEAD := [
\t%s
]
const HUNTER_KNEEL_QUIVER := [
\t%s
]
''' % (fmt(idle), fmt(cleave), v2(heads), v2(quivers))
    open(os.path.join(HERE, '..', 'scripts', 'bosses', 'boss_anchors.gd'), 'w').write(txt)


if __name__ == '__main__':
    main()
    write_gd(json.load(open(os.path.join(HERE, '..', 'data', 'boss_anchors.json'))))
