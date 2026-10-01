from pix import *
from PIL import Image

G = {}


def add(ch, rows):
    G[ch] = rows


def glyphs(spec):
    for ch, txt in spec.items():
        rows = txt.split('/')
        assert len(rows) == 7 and all(len(r) == 5 for r in rows), ch
        G[ch] = rows


glyphs({
    'A': '.###./#...#/#...#/#####/#...#/#...#/#...#',
    'B': '####./#...#/#...#/####./#...#/#...#/####.',
    'C': '.####/#..../#..../#..../#..../#..../.####',
    'D': '####./#...#/#...#/#...#/#...#/#...#/####.',
    'E': '#####/#..../#..../####./#..../#..../#####',
    'F': '#####/#..../#..../####./#..../#..../#....',
    'G': '.####/#..../#..../#.###/#...#/#...#/.####',
    'H': '#...#/#...#/#...#/#####/#...#/#...#/#...#',
    'I': '#####/..#../..#../..#../..#../..#../#####',
    'J': '..###/...#./...#./...#./...#./#..#./.##..',
    'K': '#...#/#..#./#.#../##.../#.#../#..#./#...#',
    'L': '#..../#..../#..../#..../#..../#..../#####',
    'M': '#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#',
    'N': '#...#/##..#/#.#.#/#..##/#...#/#...#/#...#',
    'O': '.###./#...#/#...#/#...#/#...#/#...#/.###.',
    'P': '####./#...#/#...#/####./#..../#..../#....',
    'Q': '.###./#...#/#...#/#...#/#.#.#/#..#./.##.#',
    'R': '####./#...#/#...#/####./#.#../#..#./#...#',
    'S': '.####/#..../#..../.###./....#/....#/####.',
    'T': '#####/..#../..#../..#../..#../..#../..#..',
    'U': '#...#/#...#/#...#/#...#/#...#/#...#/.###.',
    'V': '#...#/#...#/#...#/#...#/#...#/.#.#./..#..',
    'W': '#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#',
    'X': '#...#/#...#/.#.#./..#../.#.#./#...#/#...#',
    'Y': '#...#/#...#/.#.#./..#../..#../..#../..#..',
    'Z': '#####/....#/...#./..#../.#.../#..../#####',
    '0': '.###./#...#/#..##/#.#.#/##..#/#...#/.###.',
    '1': '..#../.##../..#../..#../..#../..#../.###.',
    '2': '.###./#...#/....#/...#./..#../.#.../#####',
    '3': '####./....#/....#/.###./....#/....#/####.',
    '4': '...#./..##./.#.#./#..#./#####/...#./...#.',
    '5': '#####/#..../####./....#/....#/#...#/.###.',
    '6': '.###./#..../#..../####./#...#/#...#/.###.',
    '7': '#####/....#/...#./..#../.#.../.#.../.#...',
    '8': '.###./#...#/#...#/.###./#...#/#...#/.###.',
    '9': '.###./#...#/#...#/.####/....#/....#/.###.',
    '.': '...../...../...../...../...../...../..#..',
    ',': '...../...../...../...../...../..#../.#...',
    ':': '...../..#../...../...../..#../...../.....',
    ';': '...../..#../...../...../..#../..#../.#...',
    '!': '..#../..#../..#../..#../..#../...../..#..',
    '?': '.###./#...#/....#/...#./..#../...../..#..',
    '-': '...../...../...../#####/...../...../.....',
    "'": '..#../..#../...../...../...../...../.....',
    '"': '.#.#./.#.#./...../...../...../...../.....',
    '/': '....#/....#/...#./..#../.#.../#..../#....',
    '+': '...../..#../..#../#####/..#../..#../.....',
    '>': '#..../.#.../..#../...#./..#../.#.../#....',
    '<': '....#/...#./..#../.#.../..#../...#./....#',
    '=': '...../...../#####/...../#####/...../.....',
    '_': '...../...../...../...../...../...../#####',
    '(': '..#../.#.../#..../#..../#..../.#.../..#..',
    ')': '..#../...#./....#/....#/....#/...#./..#..',
    '*': '...../#.#.#/.###./#####/.###./#.#.#/.....',
    ' ': '...../...../...../...../...../...../.....',
    '%': '##..#/##.#./...#./..#../.#.../#.##./#.##.',
})


def make_font(scale, name, out):
    chars = list(G.keys())
    cw, ch = 6 * scale, 8 * scale
    cols = 16
    rows = (len(chars) + cols - 1) // cols
    im = Image.new('RGBA', (cols * cw, rows * ch), (0, 0, 0, 0))
    lines = []
    for i, c in enumerate(chars):
        gx, gy = (i % cols) * cw, (i // cols) * ch
        for y, r in enumerate(G[c]):
            for x, v in enumerate(r):
                if v == '#':
                    for dy in range(scale):
                        for dx in range(scale):
                            im.putpixel((gx + x * scale + dx, gy + y * scale + dy), (255, 255, 255, 255))
        lines.append(f'char id={ord(c)} x={gx} y={gy} width={5 * scale} height={7 * scale} xoffset=0 yoffset=0 xadvance={6 * scale} page=0 chnl=15')
        # lowercase alias
        if c.isalpha():
            lines.append(f'char id={ord(c.lower())} x={gx} y={gy} width={5 * scale} height={7 * scale} xoffset=0 yoffset=0 xadvance={6 * scale} page=0 chnl=15')
    im.save(f'{out}/ui/{name}.png')
    hdr = [f'info face="{name}" size={8 * scale} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=0 padding=0,0,0,0 spacing=0,0',
           f'common lineHeight={9 * scale} base={7 * scale} scaleW={im.width} scaleH={im.height} pages=1 packed=0',
           f'page id=0 file="{name}.png"', f'chars count={len(lines)}']
    open(f'{out}/ui/{name}.fnt', 'w').write('\n'.join(hdr + lines) + '\n')


def text_img(txt, scale, col, shadow=None):
    w = len(txt) * 6 * scale
    im = Image.new('RGBA', (w + 2 * scale, 9 * scale), (0, 0, 0, 0))
    for i, c in enumerate(txt):
        for y, r in enumerate(G[c]):
            for x, v in enumerate(r):
                if v == '#':
                    for dy in range(scale):
                        for dx in range(scale):
                            px, py = i * 6 * scale + x * scale + dx, y * scale + dy
                            if shadow:
                                im.putpixel((px + scale, py + scale), shadow)
    for i, c in enumerate(txt):
        for y, r in enumerate(G[c]):
            for x, v in enumerate(r):
                if v == '#':
                    for dy in range(scale):
                        for dx in range(scale):
                            im.putpixel((i * 6 * scale + x * scale + dx, y * scale + dy), col[min(len(col) - 1, y // 3)] if isinstance(col, list) else col)
    return im


def title_bg():
    W, H = 480, 270
    cv = Cv(W, H)
    r = random.Random(4)
    # sky bands (dithered)
    top, bot = (14, 10, 34), (92, 42, 74)
    for y in range(H):
        t = y / (H * 0.75)
        t = min(1, t)
        base = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(W):
            d = ((x + y) % 2) * 4 if (int(t * 12) % 2) else 0
            cv.px(x, y, tuple(min(255, c + d) for c in base) + (255,))
    for _ in range(90):
        x, y = r.randrange(W), r.randrange(0, 130)
        cv.px(x, y, C('f0e8ff') if r.random() < .3 else C('a898c8'))
    # moon
    cv.blob(360, 70, 34, 34, (C('b8a8c8'), C('f0e8dc'), C('ffffff')))
    for (x, y, rr) in ((350, 62, 5), (372, 80, 4), (362, 52, 3)):
        cv.blob(x, y, rr, rr, (C('d0c4d0'), C('c8bcc8'), C('d8ccd8')), light=(0.5, 0.7))
    # mountains
    def ridge(base, amp, col, seed, step=18):
        rr = random.Random(seed)
        pts = [(0, H)]
        y = base
        for x in range(0, W + step, step):
            y = base + rr.randint(-amp, amp)
            pts.append((x, y))
        pts.append((W, H))
        cv.poly(pts, col)
    ridge(150, 30, C('3a2a5a'), 1); ridge(178, 20, C('2a1e46'), 2, 14)
    # ruined temple on the ridge
    tx, ty = 214, 162
    T = C('1a1230')
    cv.rect(tx, ty + 18, 116, 30, T)
    for i in range(6):
        h = 46 if i not in (2, 4) else 30 + (i * 7 % 11)
        cv.rect(tx + 6 + i * 20, ty - h + 18, 8, h, T)
        cv.rect(tx + 3 + i * 20, ty - h + 15, 14, 4, T)
    cv.poly([(tx - 2, ty - 22), (tx + 58, ty - 50), (tx + 118, ty - 22)], T)
    cv.rect(tx + 40, ty - 34, 6, 20, T)
    for (x, y) in ((tx + 30, ty + 10), (tx + 62, ty + 12), (tx + 90, ty + 10)):
        cv.rect(x, y, 4, 8, C('ffb040')); cv.px(x + 1, y + 1, C('fff0a0'))
    ridge(214, 14, C('160e2a'), 3, 12)
    # foreground cliff with archer
    cv.poly([(0, 270), (0, 214), (60, 208), (120, 226), (170, 250), (200, 270)], C('0c0818'))
    cv.poly([(280, 270), (330, 240), (400, 222), (480, 216), (480, 270)], C('0c0818'))
    for x in (30, 60, 150):
        cv.rect(x, 200 + (x % 7), 2, 14, C('0c0818'))
        cv.blob(x + 1, 198, 6, 8, (C('0c0818'), C('0c0818'), C('160e2a')))
    # archer silhouette
    ax, ay = 388, 216
    cv.poly([(ax - 5, ay), (ax + 5, ay), (ax + 4, ay - 16), (ax - 4, ay - 16)], C('0c0818'))
    cv.blob(ax, ay - 20, 5, 5, (C('0c0818'), C('0c0818'), C('0c0818')))
    cv.line(ax + 8, ay - 26, ax + 8, ay - 6, C('0c0818')); cv.line(ax + 2, ay - 14, ax + 8, ay - 14, C('0c0818'))
    cv.line(ax - 6, ay - 16, ax - 12, ay - 12, C('e0703a')); cv.line(ax - 12, ay - 12, ax - 18, ay - 14, C('e0703a'))
    # vignette
    for y in range(H):
        for x in range(W):
            d = max(abs(x - W / 2) / (W / 2), abs(y - H / 2) / (H / 2))
            if d > 0.75:
                c = cv.p[x, y]
                k = min(.5, (d - .75) * 2)
                cv.p[x, y] = mix(c, (0, 0, 0, 255), k)
    return cv


def crosshair():
    # the OS cursor is drawn in screen pixels (not scaled with the game), so it must be big and bold
    cv = Cv(33, 33)
    G = C('ffd45a'); W = C('ffffff')
    for i in range(3, 12):            # four arms, 3px thick
        for t in (-1, 0, 1):
            cv.px(16 + t, i, G); cv.px(16 + t, 32 - i, G)
            cv.px(i, 16 + t, G); cv.px(32 - i, 16 + t, G)
    for a in range(0, 360, 6):        # thin ring
        import math as _m
        cv.px(16 + 9.5 * _m.cos(_m.radians(a)), 16 + 9.5 * _m.sin(_m.radians(a)), C('ffe9a8'))
    cv.rect(15, 15, 3, 3, W)          # centre dot
    cv.outline(C('120e1a'), diag=True)
    return cv


def gen(out):
    make_font(1, 'font_small', out)
    make_font(2, 'font_big', out)
    title_bg().save(out + '/ui/title_bg.png')
    crosshair().save(out + '/ui/crosshair.png')
    lg = text_img('HOLLOW ARROW', 6, [(255, 232, 160, 255), (240, 176, 64, 255), (200, 110, 50, 255)], (30, 10, 20, 255))
    lg.save(out + '/ui/logo.png')
    # arrow icon glyph for menus
    ic = Cv(9, 9)
    for i in range(5):
        ic.line(0, 4 - i, 0 + 4 - i + 0, 4 - i, C('ffe8a0')) if False else None
    ic.poly([(1, 1), (8, 4.5), (1, 8)], C('ffd070'))
    ic.save(out + '/ui/cursor_arrow.png')
    icon(out)


def icon(out):
    cv = Cv(32, 32)
    cv.rect(0, 0, 32, 32, C('1a1230'))
    cv.blob(16, 16, 15, 15, (C('22183c'), C('2e2250'), C('3c2e66')))
    # moon
    cv.blob(22, 10, 5, 5, (C('b8a8c8'), C('f0e8dc'), C('ffffff')))
    # arrow (diagonal)
    for i in range(20):
        cv.px(6 + i, 26 - i, C('c98a4a')); cv.px(7 + i, 26 - i, C('7a5628'))
    cv.poly([(24, 4), (29, 3), (28, 8)], C('e8ecf4'))
    cv.line(25, 5, 28, 4, C('8a95a8'))
    cv.line(6, 26, 4, 24, C('d94a4a')); cv.line(7, 27, 5, 25, C('d94a4a')); cv.line(6, 26, 4, 28, C('a02a2a'))
    cv.outline(C('0a0614'))
    cv.im.resize((128, 128), Image.NEAREST).save(out + '/ui/icon.png')
