from pix import *

OL = C('120e1a')
OUTLINE_ON = True


def _ol(cv):
    if OUTLINE_ON:
        cv.outline(OL)
GLOW = tri('ffb040')
G_STONE = tri('7c7a84')
G_DARK = tri('4c4a58')


def weak_glow(f):
    cv = Cv(24, 24)
    r = [6, 8, 7][f]
    for rr, a in ((r + 3, 60), (r + 1, 110)):
        for y in range(24):
            for x in range(24):
                if (x - 11.5) ** 2 + (y - 11.5) ** 2 <= rr * rr and cv.get(x, y)[3] == 0:
                    cv.px(x, y, (255, 190, 80, a))
    cv.blob(12, 12, r - 2, r - 2, tri('ffe070'))
    cv.blob(12, 12, 2.5, 2.5, tri('ffffff'))
    return cv


# ---------------------------------------------------------------- warden
def warden(state, outline=True):
    cv = Cv(80, 72)
    body = tri('86828e') if state != 'tele' else tri('9a8a90')
    dark = tri('54505e')
    # shadow
    for y in range(72):
        for x in range(80):
            if ((x - 40) / 30) ** 2 + ((y - 62) / 6) ** 2 <= 1:
                cv.px(x, y, (10, 6, 20, 90))
    # legs / feet
    cv.blob(28, 58, 9, 6, dark); cv.blob(54, 58, 9, 6, dark)
    # back arm (behind body, left)
    cv.blob(14, 40, 9, 12, dark)
    # torso
    cv.blob(38, 36, 24, 22, body)
    cv.blob(38, 42, 20, 14, tri('6e6a78'))
    # back armour plates on left side
    if state == 'stun':
        for k, (px, py) in enumerate(((8, 20), (6, 32), (8, 44))):
            cv.srect(px - 4, py, 10, 9, dark)
        cv.blob(22, 36, 7, 15, tri('ffb040'))
        cv.blob(22, 36, 4, 10, tri('ffe070'))
    else:
        for k, (px, py) in enumerate(((14, 18), (12, 30), (14, 42))):
            cv.srect(px, py, 12, 10, tri('6a6674'))
            cv.rect(px + 3, py + 4, 6, 1, dark[0])
    # shoulders
    cv.blob(30, 20, 11, 9, body); cv.blob(56, 24, 12, 10, body)
    # front arm & fist
    cv.blob(66, 44, 8, 11, body); cv.blob(68, 54, 7, 6, tri('9a96a4'))
    # head
    cv.blob(56, 16, 11, 10, tri('92909c'))
    cv.rect(54, 9, 9, 3, dark[0])                    # brow
    if state == 'tele':
        eye, eye2 = tri('ffffff'), tri('ffb040')
    elif state == 'stun':
        eye, eye2 = tri('3a3844'), tri('3a3844')
    else:
        eye, eye2 = tri('ff9a30'), tri('c86a20')
    cv.rect(58, 13, 4, 3, eye[1]); cv.rect(65, 13, 3, 3, eye2[1])
    cv.px(59, 13, eye[2]); cv.px(66, 13, eye[2])
    # mouth grille
    for x in range(58, 68, 2):
        cv.rect(x, 20, 1, 3, dark[0])
    # cracks / moss
    cv.line(36, 26, 40, 34, dark[0]); cv.line(40, 34, 36, 42, dark[0]); cv.line(40, 34, 48, 36, dark[0])
    if state == 'tele':
        for (a, b, c, d) in ((36, 26, 40, 34), (40, 34, 36, 42), (40, 34, 48, 36)):
            cv.line(a + 1, b, c + 1, d, C('ffb040'))
        cv.rect(28, 30, 3, 3, C('ff7a20')); cv.rect(48, 44, 3, 3, C('ff7a20'))
    cv.noise(10, 8, 60, 50, [C('5a7a3a'), C('4a6a30')], 0.03, seed=9)
    if outline:
        _ol(cv)
    return cv


# ---------------------------------------------------------------- warden evolutions (same skeleton, more brutal)
def _spike(cv, pts, base, tip):
    cv.poly(pts, base)
    # light edge on the tip side
    cv.line(pts[0][0], pts[0][1], pts[1][0], pts[1][1], tip)


def warden_form(form, state):
    """form 2 = spiked, cracked and glowing; form 3 = horned, molten. state: idle / tele / open (f2) / stun (f3)."""
    cv = Cv(96, 88)
    base = warden('tele' if state == 'tele' else 'idle', outline=False)
    if form == 2 and state == 'open':
        base = warden('idle', outline=False)
    if form == 3 and state == 'stun':
        base = warden('stun', outline=False)
    cv.paste(base, 10, 8)
    ST = tri('6c6878'); DK = tri('3e3a4a')
    HOT = tri('ff9a30'); WH = tri('ffe9a0')
    # ---- shared: shoulder spikes
    tall = 1.0 if form == 2 else 1.6
    for (cx, cy, dx) in ((40, 26, -1), (66, 30, 1)):
        _spike(cv, [(cx - 6, cy + 4), (cx - 8 * tall * 0.6, cy - 16 * tall), (cx + 2, cy)], ST[1], ST[2])
        _spike(cv, [(cx + 2, cy), (cx + 4 * tall, cy - 20 * tall), (cx + 10, cy + 2)], ST[1], ST[2])
    # ---- back spikes (skip when the back is opened on f3 stun so the core reads)
    if not (form == 3 and state == 'stun'):
        for (y, ln) in ((30, 16), (44, 20), (58, 14)):
            _spike(cv, [(26, y - 5), (26 - ln * (1.0 if form == 2 else 1.4), y), (26, y + 5)], DK[1], ST[1])
    # ---- glowing cracks
    hot_c = HOT[1] if form == 2 else WH[1]
    for seg in (((44, 36), (50, 44)), ((50, 44), (46, 54)), ((50, 44), (60, 46)), ((36, 34), (32, 42))):
        cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], hot_c)
    if form == 3:
        for seg in (((40, 30), (46, 40)), ((56, 38), (64, 44)), ((30, 50), (40, 56)), ((66, 60), (72, 66))):
            cv.line(seg[0][0], seg[0][1], seg[1][0], seg[1][1], HOT[2])
        cv.blob(78, 66, 6, 6, tri('ff6a20'))          # molten fist
        cv.blob(78, 66, 3, 3, tri('ffe070'))
        # horns
        cv.poly([(56, 24), (52, 10), (44, 2), (46, 12), (50, 20), (66, 26)], tri('8a5a3a')[1])
        cv.poly([(72, 22), (78, 10), (90, 4), (86, 14), (82, 20), (76, 28)], tri('8a5a3a')[1])
        cv.line(52, 10, 44, 2, tri('c8985a')[1]); cv.line(78, 10, 90, 4, tri('c8985a')[1])
        # burning eyes + maw
        cv.rect(66, 22, 5, 3, WH[1]); cv.rect(74, 22, 4, 3, WH[1])
        cv.rect(66, 26, 12, 2, HOT[1])
    else:
        cv.rect(66, 22, 5, 3, HOT[2]); cv.rect(74, 22, 4, 3, HOT[1])
    # ---- state details
    if state == 'open' and form == 2:
        cv.blob(48, 50, 13, 12, DK)
        cv.blob(48, 50, 10, 9, tri('ff8a20'))
        cv.blob(48, 50, 6, 6, tri('ffe070'))
        cv.blob(48, 50, 2.5, 2.5, tri('ffffff'))
        for (a, b, c, d) in ((36, 44, 30, 40), (60, 44, 66, 40), (48, 62, 48, 68)):
            cv.line(a, b, c, d, HOT[2])
    if state == 'stun' and form == 3:
        cv.blob(30, 46, 11, 14, DK)
        cv.blob(30, 46, 8, 11, tri('ffb040'))
        cv.blob(30, 46, 5, 7, tri('ffe9a0'))
        cv.blob(30, 46, 2, 3, tri('ffffff'))
        for (a, b, c, d) in ((22, 34, 16, 26), (20, 46, 10, 46), (22, 58, 16, 66)):
            cv.line(a, b, c, d, HOT[2])
    if state == 'tele':
        for (x, y) in ((44, 40), (58, 50), (36, 56)):
            cv.rect(x, y, 3, 3, C('ffffff'))
    _ol(cv)
    return cv


def rock():
    cv = Cv(12, 12)
    cv.blob(6, 6, 5, 4.5, tri('8a8494'))
    cv.px(4, 5, C('c8c4d0')); cv.px(8, 8, C('4a4658'))
    _ol(cv)
    return cv


# ---------------------------------------------------------------- mirror knight (top-down, faces right)
def knight(shield=True):
    cv = Cv(56, 56)
    A = tri('9aa6c8'); CR = tri('7ad0ff'); CAPE = tri('4a3a7a')
    # cape (behind)
    cv.poly([(4, 16), (24, 12), (24, 44), (4, 40), (8, 28)], CAPE[1])
    cv.poly([(4, 16), (24, 12), (24, 22), (8, 24)], CAPE[2]); cv.line(6, 40, 24, 44, CAPE[0])
    # back crystal (weak spot housing)
    cv.blob(9, 28, 5, 6, CR); cv.blob(9, 28, 2.5, 3, tri('ffffff'))
    # pauldrons
    cv.blob(26, 14, 9, 7, A); cv.blob(26, 42, 9, 7, A)
    # torso
    cv.blob(26, 28, 11, 12, A)
    # helm
    cv.blob(28, 28, 8, 8, tri('b8c4e0'))
    cv.rect(31, 26, 6, 1, OL); cv.rect(31, 30, 6, 1, OL)
    cv.rect(22, 27, 8, 2, C('e8464a'))  # plume
    # arm + sword hand
    cv.blob(40, 40, 5, 4, A)
    # shield (front / right), crystalline
    if shield:
      cv.poly([(38, 6), (48, 12), (52, 28), (48, 44), (38, 50), (42, 28)], CR[1])
      cv.poly([(38, 6), (48, 12), (46, 28), (42, 28)], CR[2])
      cv.poly([(38, 50), (48, 44), (46, 28), (42, 28)], CR[0])
      cv.line(46, 14, 44, 24, C('f4ffff')); cv.line(48, 34, 46, 40, C('c8f0ff'))
    _ol(cv)
    return cv


def knight_sword():
    cv = Cv(40, 9)
    cv.rect(0, 3, 6, 3, tri('6a3a2a')[1]); cv.rect(5, 1, 2, 7, GLOW[0])
    cv.rect(7, 3, 30, 3, C('dfe8f8')); cv.rect(7, 5, 30, 1, C('98a8c8')); cv.poly([(37, 3), (40, 4.5), (37, 6)], C('dfe8f8'))
    _ol(cv); return cv


# ---------------------------------------------------------------- burrower
def burrower(open_):
    cv = Cv(88, 72)
    B = tri('8a6a4a'); D = tri('5a4230')
    for y in range(72):
        for x in range(88):
            if ((x - 44) / 36) ** 2 + ((y - 62) / 7) ** 2 <= 1:
                cv.px(x, y, (10, 6, 20, 90))
    # body segments behind (left)
    for (x, r) in ((10, 9), (22, 12), (34, 15)):
        cv.blob(x, 44, r, r * .9, tri('7a5a3c'))
        cv.line(x + 3, 44 - r * .9, x + 3, 44 + r * .9, D[0])
    # head
    cv.blob(52, 40, 28, 24, B)
    for (x, y) in ((40, 22), (52, 18), (64, 22), (34, 34), (70, 32)):
        cv.blob(x, y, 5, 4, tri('a58060'))
    # mandibles
    cv.poly([(66, 14), (84, 24), (70, 30)], tri('d8ccb0')[1]); cv.poly([(66, 66), (84, 56), (70, 50)], tri('d8ccb0')[1])
    cv.poly([(66, 14), (84, 24), (80, 22)], C('f4ecd8')); cv.poly([(66, 66), (84, 56), (80, 58)], C('f4ecd8'))
    # maw
    if open_:
        cv.blob(66, 40, 11, 14, tri('2a0a14')); cv.blob(66, 40, 8, 10, tri('7a1a2a')); cv.blob(66, 40, 4, 5, tri('c83a4a'))
        for k in range(10):
            a = math.radians(k * 36)
            cv.px(66 + 10 * math.cos(a), 40 + 13 * math.sin(a), C('f4ecd8')); cv.px(66 + 9 * math.cos(a), 40 + 12 * math.sin(a), C('f4ecd8'))
    else:
        cv.blob(66, 40, 10, 13, D)
        cv.line(58, 40, 74, 40, D[0])
        cv.poly([(60, 32), (72, 32), (66, 40)], tri('a58060')[1]); cv.poly([(60, 48), (72, 48), (66, 40)], tri('a58060')[1])
    # eyes
    cv.rect(50, 30, 3, 3, C('ffd070')); cv.rect(50, 48, 3, 3, C('ffd070'))
    _ol(cv)
    return cv


def mound(f):
    cv = Cv(40, 24)
    B = tri('7a5c3c')
    cv.blob(20, 14, 16 - f, 8 - f * .5, B)
    for (x, y) in ((12, 6 - f), (24, 4), (18, 3 + f)):
        cv.blob(x, y, 2, 2, tri('a58060'))
    _ol(cv)
    return cv


def crack():
    cv = Cv(56, 28)
    c = C('241612')
    cx, cy = 28, 14
    for a in range(0, 360, 40):
        ln = 20 if a % 80 == 0 else 12
        x = cx + ln * math.cos(math.radians(a)); y = cy + ln * .5 * math.sin(math.radians(a))
        cv.line(cx, cy, x, y, c)
        cv.line(cx + 1, cy, x + 1, y, mix(c, (90, 60, 40, 255), .3))
    return cv


# ---------------------------------------------------------------- colossus
def colossus(open_):
    cv = Cv(144, 112)
    S = tri('766c74'); D = tri('4a4250'); L = tri('9a8e94')
    for y in range(112):
        for x in range(144):
            if ((x - 72) / 60) ** 2 + ((y - 100) / 9) ** 2 <= 1:
                cv.px(x, y, (10, 6, 20, 90))
    # legs/base hunched
    cv.blob(40, 88, 20, 14, D); cv.blob(104, 88, 20, 14, D)
    # torso
    cv.blob(72, 58, 42, 38, S)
    cv.blob(72, 66, 34, 28, tri('685e68'))
    # shoulders
    cv.blob(28, 40, 20, 18, S); cv.blob(116, 40, 20, 18, S)
    cv.blob(28, 38, 12, 10, L); cv.blob(116, 38, 12, 10, L)
    # head
    hy = 22 if not open_ else 34
    cv.blob(72, hy, 17, 15, tri('807682'))
    cv.rect(62, hy - 4, 20, 4, D[0])
    ec = tri('ffb040') if open_ else tri('ff5a3a')
    cv.rect(64, hy - 1, 5, 3, ec[1]); cv.rect(75, hy - 1, 5, 3, ec[1])
    if open_:
        cv.rect(64, hy - 1, 5, 3, C('3a2a30')); cv.rect(75, hy - 1, 5, 3, C('3a2a30'))
    for x in range(64, 82, 3):
        cv.rect(x, hy + 7, 1, 4, D[0])
    # chest plate / core
    if open_:
        cv.blob(72, 62, 20, 20, D)
        cv.blob(72, 62, 14, 14, tri('ff9a30'))
        cv.blob(72, 62, 8, 8, tri('ffe070'))
        cv.blob(72, 62, 3, 3, tri('ffffff'))
        for (x0, y0, x1, y1) in ((52, 50, 44, 40), (92, 50, 100, 40), (72, 82, 72, 92)):
            cv.line(x0, y0, x1, y1, C('ff9a30'))
    else:
        cv.blob(72, 62, 20, 20, tri('8a8090'))
        cv.rect(60, 60, 24, 4, D[0])
        cv.rect(70, 50, 4, 24, D[0])
        cv.blob(72, 62, 5, 5, tri('c8a040'))
        cv.rect(71, 62, 2, 4, OL)
    # chain manacles at wrists
    for (x, y) in ((14, 62), (130, 62), (20, 90)):
        cv.blob(x, y, 6, 6, tri('5a5a68')); cv.blob(x, y, 3, 3, tri('120e1a'))
    cv.noise(10, 10, 124, 90, [C('5a7a3a'), C('4a3a30')], 0.02, seed=3)
    _ol(cv)
    return cv


def fist(kind):
    cv = Cv(48, 48)
    S = tri('8a7e88'); D = tri('4a4250')
    if kind == 'up':
        cv.blob(24, 26, 16, 16, S)
        for k in range(4):
            cv.blob(12 + k * 8, 10, 5, 7, tri('9a8e98'))
        cv.blob(10, 30, 6, 7, tri('9a8e98'))
        cv.rect(14, 38, 20, 8, D[1]); cv.rect(14, 42, 20, 4, D[0])
    else:
        cv.blob(24, 26, 20, 16, S)
        for k in range(4):
            cv.blob(9 + k * 10, 14, 6, 6, tri('9a8e98'))
        cv.rect(8, 36, 32, 8, D[0])
    _ol(cv)
    return cv


# ---------------------------------------------------------------- sky hunter (faces right, top-down)
def hunter(wing):
    cv = Cv(120, 80)
    F = tri('c8d4e8'); Dk = tri('4a5a8a'); R = tri('e0603a')
    up = wing == 0
    # wings
    top_tip = (48, 4) if up else (56, 14)
    bot_tip = (48, 76) if up else (56, 66)
    cv.poly([(56, 34), (76, 30), top_tip, (28, 12)], Dk[1])
    cv.poly([(56, 46), (76, 50), bot_tip, (28, 68)], Dk[1])
    for k in range(5):
        t = k / 4
        cv.line(56 - t * 24 + 10, 34 - t * 4, top_tip[0] - 22 + k * 5, top_tip[1] + 6, F[1])
        cv.line(56 - t * 24 + 10, 46 + t * 4, bot_tip[0] - 22 + k * 5, bot_tip[1] - 6, F[1])
    cv.poly([(56, 34), (72, 32), top_tip, (40, 16)], F[1]); cv.poly([(56, 46), (72, 48), bot_tip, (40, 64)], F[1])
    cv.line(top_tip[0], top_tip[1], 70, 32, Dk[0]); cv.line(bot_tip[0], bot_tip[1], 70, 48, Dk[0])
    # tail
    cv.poly([(28, 34), (4, 26), (8, 40), (4, 54), (28, 46)], R[1])
    cv.line(8, 40, 26, 40, R[0]); cv.line(6, 30, 26, 37, R[0]); cv.line(6, 50, 26, 43, R[0])
    # body
    cv.blob(50, 40, 24, 10, tri('d8e0f0'))
    cv.blob(50, 44, 20, 5, F)
    # head + beak
    cv.blob(78, 40, 9, 8, tri('e8ecf8'))
    cv.poly([(84, 35), (100, 40), (84, 45)], tri('f0b040')[1]); cv.line(84, 40, 98, 40, tri('f0b040')[0])
    cv.rect(79, 36, 3, 3, C('ff3a3a')); cv.px(80, 36, C('ffffff'))
    cv.rect(72, 30, 3, 6, R[1]); cv.rect(75, 32, 3, 4, R[1])   # crest
    _ol(cv)
    return cv


def hunter_ground():
    cv = Cv(88, 60)
    F = tri('c8d4e8'); Dk = tri('4a5a8a'); R = tri('e0603a')
    for y in range(60):
        for x in range(88):
            if ((x - 44) / 34) ** 2 + ((y - 52) / 6) ** 2 <= 1:
                cv.px(x, y, (10, 6, 20, 90))
    cv.poly([(12, 30), (20, 12), (46, 6), (60, 24), (46, 46), (20, 46)], Dk[1])   # folded wings
    cv.poly([(16, 30), (24, 16), (44, 12), (54, 26), (44, 40), (24, 42)], F[1])
    for k in range(4):
        cv.line(22 + k * 8, 16 + k, 24 + k * 6, 40, Dk[0])
    cv.poly([(14, 30), (0, 24), (2, 36), (0, 46), (14, 40)], R[1])
    cv.blob(46, 28, 12, 10, tri('d8e0f0'))
    cv.blob(64, 26, 9, 8, tri('e8ecf8'))
    cv.poly([(70, 21), (84, 27), (70, 31)], tri('f0b040')[1])
    cv.px(65, 24, C('ffe070')); cv.px(66, 24, C('ffe070')); cv.px(65, 25, C('120e1a')); cv.px(66, 25, C('120e1a'))
    cv.rect(58, 18, 3, 5, R[1])
    _ol(cv)
    return cv


def feather():
    cv = Cv(14, 8)
    cv.poly([(0, 4), (10, 0), (14, 4), (10, 8)], tri('e0603a')[1])
    cv.line(1, 4, 13, 4, C('ffe8c8')); cv.px(12, 4, C('ffffff'))
    _ol(cv); return cv


# ---------------------------------------------------------------- sentinels
def sentinel(kind, open_):
    cv = Cv(56, 64)
    P = tri('ffb040') if kind == 'sun' else tri('9a7aff')
    S = tri('8a8296') if kind == 'sun' else tri('6e6a92')
    Dk = tri('4c4658') if kind == 'sun' else tri('3e3a5c')
    for y in range(64):
        for x in range(56):
            if ((x - 28) / 18) ** 2 + ((y - 58) / 4) ** 2 <= 1:
                cv.px(x, y, (10, 6, 20, 90))
    off = 7 if open_ else 0
    # rear column
    cv.srect(20, 6, 16, 44, Dk)
    # eye / core
    cv.blob(28, 28, 8, 10, tri('1a1220'))
    cv.blob(28, 28, 6 if open_ else 3, 8 if open_ else 4, P if open_ else tri('5a4a60'))
    if open_:
        cv.blob(28, 28, 3, 4, tri('ffffff'))
    # shell plates (two halves)
    cv.poly([(24 - off, 4), (10 - off, 16), (8 - off, 40), (24 - off, 52), (26 - off, 30)], S[1])
    cv.poly([(24 - off, 4), (10 - off, 16), (12 - off, 22), (26 - off, 20)], S[2])
    cv.poly([(32 + off, 4), (46 + off, 16), (48 + off, 40), (32 + off, 52), (30 + off, 30)], S[1])
    cv.poly([(32 + off, 4), (46 + off, 16), (44 + off, 22), (30 + off, 20)], S[2])
    cv.line(24 - off, 8, 24 - off, 48, S[0]); cv.line(32 + off, 8, 32 + off, 48, S[0])
    # crest gem
    cv.blob(28, 6, 4, 4, P)
    # base ring
    cv.blob(28, 54, 14, 5, Dk)
    for k in range(4):
        cv.px(18 + k * 7, 54, P[2])
    _ol(cv)
    return cv


def orb(kind):
    cv = Cv(10, 10)
    P = tri('ffb040') if kind == 'sun' else tri('9a7aff')
    if kind == 'red':
        P = tri('ff5a4a')
    cv.blob(5, 5, 4, 4, P); cv.blob(5, 5, 2, 2, tri('ffffff'))
    _ol(cv); return cv


# ---------------------------------------------------------------- final boss
def regent(open_):
    cv = Cv(88, 96)
    R = tri('3a2a52'); Gd = tri('e0b040'); M = tri('e8e0d0')
    for y in range(96):
        for x in range(88):
            if ((x - 44) / 30) ** 2 + ((y - 90) / 5) ** 2 <= 1:
                cv.px(x, y, (10, 6, 20, 90))
    # robe
    cv.poly([(44, 30), (66, 40), (76, 80), (60, 88), (44, 82), (28, 88), (12, 80), (22, 40)], R[1])
    cv.poly([(44, 30), (22, 40), (12, 80), (28, 88), (36, 60)], R[2])
    cv.poly([(44, 30), (66, 40), (76, 80), (60, 88), (52, 60)], R[0])
    for x in range(20, 70, 8):
        cv.line(x, 66, x + (x - 44) // 6, 86, R[0])
    cv.line(14, 80, 28, 88, Gd[1]); cv.line(60, 88, 74, 80, Gd[1])
    # shoulders / arms
    cv.blob(24, 40, 10, 8, tri('54426e')); cv.blob(64, 40, 10, 8, tri('54426e'))
    cv.rect(18, 36, 12, 2, Gd[1]); cv.rect(58, 36, 12, 2, Gd[1])
    # hands
    cv.blob(10, 56, 5, 5, tri('d8c8b0')); cv.blob(78, 56, 5, 5, tri('d8c8b0'))
    # chest core socket
    cv.blob(44, 52, 11, 11, tri('241a34'))
    ring = Gd
    for a in range(0, 360, 10):
        cv.px(44 + 11 * math.cos(math.radians(a)), 52 + 11 * math.sin(math.radians(a)), ring[1])
    if open_:
        cv.blob(44, 52, 8, 8, tri('ff5a3a')); cv.blob(44, 52, 5, 5, tri('ffb040')); cv.blob(44, 52, 2, 2, tri('ffffff'))
    else:
        cv.blob(44, 52, 8, 8, tri('54426e'))
        cv.rect(36, 51, 16, 2, Gd[0]); cv.rect(43, 44, 2, 16, Gd[0])
    # head with mask
    cv.blob(44, 22, 11, 12, M)
    cv.rect(37, 20, 5, 3, C('120e1a')); cv.rect(47, 20, 5, 3, C('120e1a'))
    cv.px(39, 21, C('ff5a3a')); cv.px(49, 21, C('ff5a3a'))
    cv.line(44, 26, 44, 33, C('a89880')); cv.line(40, 30, 48, 30, C('a89880'))
    cv.line(46, 12, 42, 22, C('a89880'))       # crack
    # crown
    cv.rect(32, 10, 24, 5, Gd[1]); cv.rect(32, 10, 24, 1, Gd[2]); cv.rect(32, 14, 24, 1, Gd[0])
    for (x, h) in ((32, 9), (38, 12), (44, 15), (50, 12), (56, 9)):
        cv.poly([(x - 3, 11), (x, 11 - h), (x + 3, 11)], Gd[1])
        cv.px(x, 11 - h, Gd[2])
    cv.blob(44, 12, 2, 2, tri('ff5a3a'))
    _ol(cv)
    return cv


def shard():
    cv = Cv(12, 12)
    P = tri('ffb040')
    cv.poly([(6, 0), (11, 6), (6, 12), (1, 6)], P[1]); cv.poly([(6, 0), (1, 6), (6, 6)], P[2]); cv.poly([(6, 12), (11, 6), (6, 6)], P[0])
    cv.px(6, 6, C('ffffff'))
    _ol(cv); return cv


def gen(out):
    B = out + '/bosses/'
    sheet([weak_glow(i) for i in range(3)], B + 'weak_glow.png')
    for s in ('idle', 'tele', 'stun'):
        warden(s).save(B + f'warden_{s}.png')
    for st in ('idle', 'tele', 'open'):
        warden_form(2, st).save(B + f'warden2_{st}.png')
    for st in ('idle', 'tele', 'stun'):
        warden_form(3, st).save(B + f'warden3_{st}.png')
    rock().save(B + 'rock.png')
    knight().save(B + 'knight.png'); knight_sword().save(B + 'knight_sword.png')
    burrower(True).save(B + 'burrower_open.png'); burrower(False).save(B + 'burrower_closed.png')
    sheet([mound(i) for i in range(3)], B + 'mound.png'); crack().save(B + 'crack.png')
    colossus(False).save(B + 'colossus_closed.png'); colossus(True).save(B + 'colossus_open.png')
    fist('up').save(B + 'fist_up.png'); fist('down').save(B + 'fist_down.png')
    sheet([hunter(0), hunter(1)], B + 'hunter_fly.png'); hunter_ground().save(B + 'hunter_ground.png'); feather().save(B + 'feather.png')
    for k in ('sun', 'moon'):
        sentinel(k, False).save(B + f'sentinel_{k}_closed.png'); sentinel(k, True).save(B + f'sentinel_{k}_open.png')
        orb(k).save(B + f'orb_{k}.png')
    orb('red').save(B + 'orb_red.png')
    regent(False).save(B + 'regent_closed.png'); regent(True).save(B + 'regent_open.png'); shard().save(B + 'shard.png')
