"""Boss art taken from the third-party boss packs in assets_src/bosspacks (see README credits).
Runs AFTER gen_pack on purpose: these sprites keep their own colours (no 14-colour lock) so bosses stand out from the world.
  golem.png       Mecha-stone Golem, 100x100 cells, rows 0-7 kept in place (row = animation, see warden.gd)
  golem_fist.png  its detachable arm, trimmed, used as the phase-3 projectile"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'assets_src', 'bosspacks')
GOLEM = os.path.join(SRC, 'Mecha-stone_Golem_0.1', 'Mecha-stone Golem 0.1')


def half_sheet(sheet, cw, ch, nw, nh):
    """Downscale every cell separately so frames never bleed into each other; alpha is snapped to 0/255 to keep hard pixel edges."""
    cols, rows = sheet.width // cw, sheet.height // ch
    out = Image.new('RGBA', (cols * nw, rows * nh), (0, 0, 0, 0))
    for r in range(rows):
        for c in range(cols):
            cell = sheet.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            if cell.getbbox() is None:
                continue
            small = cell.resize((nw, nh), Image.BOX)
            px = small.load()
            for y in range(nh):
                for x in range(nw):
                    p = px[x, y]
                    px[x, y] = (p[0], p[1], p[2], 255 if p[3] >= 128 else 0)
            out.paste(small, (c * nw, r * nh))
    return out


# ArcherHero -> hunter.png: 64x64 cells, 8 columns; (file, source y in px, frames, first source column) per row
HUNTER_ROWS = [
    ('Idle and running', 0, 2, 0), ('Idle and running', 64, 8, 0),          # 0 idle, 1 run
    ('Normal Attack', 0, 8, 0), ('Normal Attack', 64, 3, 0),                # 2 draw the bow, 3 release
    ('Low attack', 384, 6, 0),                                              # 4 kneeling aim loop
    ('Dash', 64, 7, 0), ('Dash', 192, 3, 0),                                # 5 dash, 6 dash loop
    ('Jumping', 0, 8, 0), ('Jumping', 64, 2, 0),                            # 7-8 airborne, cloak flapping
    ('death', 64, 8, 0), ('death', 128, 2, 0),                              # 9-10 death
    ('High Attack', 64, 8, 0), ('High Attack', 128, 5, 0),                  # 11 aim skywards, 12 release (arrow rain, storm)
    ('Low attack', 192, 8, 0), ('Low attack', 256, 7, 0),                   # 13 kneel and draw, 14 release (skid shots)
]


def build_hunter(out):
    d = os.path.join(SRC, 'ArcherHero', 'Final')
    cache = {}
    sheet = Image.new('RGBA', (8 * 64, len(HUNTER_ROWS) * 64), (0, 0, 0, 0))
    for r, (name, y, n, c0) in enumerate(HUNTER_ROWS):
        im = cache.setdefault(name, Image.open(os.path.join(d, name + '.png')).convert('RGBA'))
        for c in range(n):
            sheet.paste(im.crop(((c0 + c) * 64, y, (c0 + c + 1) * 64, y + 64)), (c * 64, r * 64))
    sheet.save(os.path.join(out, 'bosses', 'hunter.png'))


def build_wizard(out):
    """Evil Wizard 2 (CC0): 250x250 cells halved to 125x125 (staff gem stays readable), one row per animation, 8 columns"""
    d = os.path.join(SRC, 'EVil_Wizard_2', 'EVil Wizard 2', 'Sprites')
    rows = ['Idle', 'Run', 'Attack1', 'Attack2', 'Take hit', 'Death']
    sheet = Image.new('RGBA', (8 * 125, len(rows) * 125), (0, 0, 0, 0))
    for r, name in enumerate(rows):
        im = Image.open(os.path.join(d, name + '.png')).convert('RGBA')
        strip = half_sheet(im, 250, 250, 125, 125)
        sheet.paste(strip, (0, r * 125))
    sheet.save(os.path.join(out, 'bosses', 'wizard.png'))


def scale15(im):
    """1.5x for pixel art: 3x nearest, then a 2x box downsample; alpha snapped so the silhouette stays hard-edged"""
    up = im.resize((im.width * 3, im.height * 3), Image.NEAREST)
    small = up.resize((im.width * 3 // 2, im.height * 3 // 2), Image.BOX)
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255 if a >= 128 else 0)
    return small


def build_final(out):
    """the Ashen Regent's three forms from 'Golems and elementals' (batareya): 64x96 static sprites, drawn at 1.5x"""
    d = os.path.join(SRC, 'batareya')
    for i, n in ((1, 15), (2, 13), (3, 29)):
        im = Image.open(os.path.join(d, '%d.png' % n)).convert('RGBA')
        scale15(im).save(os.path.join(out, 'bosses', 'final_%d.png' % i))


def gen(out):
    sheet = Image.open(os.path.join(GOLEM, 'PNG sheet', 'Character_sheet.png')).convert('RGBA')
    sheet.crop((0, 0, 1000, 800)).save(os.path.join(out, 'bosses', 'golem.png'))
    laser = Image.open(os.path.join(GOLEM, 'weapon PNG', 'Laser_sheet.png')).convert('RGBA')
    strip = Image.new('RGBA', (64 * 7, 64), (0, 0, 0, 0))            # the golem's crystal charging: 7 growing orb frames
    for r in range(7):
        row = laser.crop((0, r * 100, 120, r * 100 + 100))
        bb = row.getbbox()
        if bb:
            cx, cy = (bb[0] + bb[2]) // 2, (bb[1] + bb[3]) // 2
            strip.alpha_composite(row.crop((cx - 32, cy - 32, cx + 32, cy + 32)), (r * 64, 0))
    strip.save(os.path.join(out, 'bosses', 'laser_charge.png'))
    fist = Image.open(os.path.join(GOLEM, 'weapon PNG', 'arm_projectile.png')).convert('RGBA')
    fist.crop(fist.getbbox()).save(os.path.join(out, 'bosses', 'golem_fist.png'))
    # Frost Guardian: 192x128 cells -> halved (box filter) so its 79x92 body sits at the golem's scale: 96x64 cells, 16 cols x 5 rows
    fr = Image.open(os.path.join(SRC, 'Frost_Guardian_FREE_v1.0', 'Frost_Guardian_FREE_v1.0', 'frost_guardian_free_192x128_SpriteSheet.png')).convert('RGBA')
    half_sheet(fr, 192, 128, 96, 64).save(os.path.join(out, 'bosses', 'frost.png'))
    # Undead Executioner: stack every strip into one 10-col sheet of 100x100 cells (row order below is what burrower.gd indexes)
    ex_dir = os.path.join(SRC, 'Undead_executioner', 'Undead executioner puppet', 'png')
    rows = []
    for name, cols in (('idle', 5), ('idle2', 4), ('attacking', 6), ('skill1', 6), ('summon', 4), ('death', 10)):
        im = Image.open(os.path.join(ex_dir, name + '.png')).convert('RGBA')
        for r in range(im.height // 100):
            rows.append([im.crop((c * 100, r * 100, c * 100 + 100, r * 100 + 100)) for c in range(cols)])
    sheet_r = Image.new('RGBA', (1000, 100 * len(rows)), (0, 0, 0, 0))
    for r, cells in enumerate(rows):
        for c, cell in enumerate(cells):
            sheet_r.paste(cell, (c * 100, r * 100))
    sheet_r.save(os.path.join(out, 'bosses', 'reaper.png'))
    # Demon Slime: 288x160 cells trimmed to the body (60..230 x 30..160) -> 170x130 cells, 22 cols x 5 rows
    dm = Image.open(os.path.join(SRC, 'boss_demon_slime_FREE_v1.0', 'boss_demon_slime_FREE_v1.0', 'spritesheets', 'demon_slime_FREE_v1.0_288x160_spritesheet.png')).convert('RGBA')
    dsheet = Image.new('RGBA', (22 * 170, 5 * 130), (0, 0, 0, 0))
    for r in range(5):
        for c in range(22):
            cell = dm.crop((c * 288 + 60, r * 160 + 30, c * 288 + 230, r * 160 + 160))
            dsheet.paste(cell, (c * 170, r * 130))
    dsheet.save(os.path.join(out, 'bosses', 'demon.png'))
    # the demon's cleaver (lying on its own in the last death frames) becomes the Colossus's slam "fist"
    cell = dm.crop((13 * 288, 4 * 160, 14 * 288, 5 * 160))
    cl = cell.crop((181, 127, 228, 155))
    cl.save(os.path.join(out, 'bosses', 'cleaver.png'))
    cl.rotate(-65, expand=True).save(os.path.join(out, 'bosses', 'cleaver_down.png'))     # blade into the floor
    cl.rotate(115, expand=True).save(os.path.join(out, 'bosses', 'cleaver_up.png'))       # raised over the target
    build_hunter(out)
    build_wizard(out)
    build_final(out)
    print('  boss pack: golem, golem_fist, frost, reaper (%d rows), demon, cleaver, hunter, wizard, final' % len(rows))
