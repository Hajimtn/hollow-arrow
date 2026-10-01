from pix import *

OL = C('120e1a')
CLOAK = tri('8fa8bf')
SCARF = tri('e0703a')
SKIN = tri('e8c39e')
BOOT = tri('4a3328')
WOOD = tri('9a6a34')


def player(d, pose, i):
    cv = Cv(24, 24)
    cx = 12
    bob = 0
    lphase = 0
    if pose == 'idle':
        bob = i % 2
    elif pose == 'run':
        bob = [0, -1, 0, -1][i]
        lphase = [0, 1, 0, -1][i]
    top = 5 + bob  # head centre y ~ top+4
    # --- legs
    ly = 19
    if d == 'side':
        lo = {0: (0, 0), 1: (2, -2), -1: (-2, 2)}[lphase] if pose == 'run' else (0, 0)
        cv.rect(cx - 2 + lo[0], ly, 2, 3, BOOT[1]); cv.rect(cx + lo[1], ly, 2, 3, BOOT[0])
        if pose == 'run' and lphase != 0:
            cv.px(cx - 2 + lo[0], ly + 2, None)
    else:
        l1 = -1 if (pose == 'run' and lphase == 1) else 0
        l2 = -1 if (pose == 'run' and lphase == -1) else 0
        cv.rect(cx - 3, ly + l1, 2, 3 - l1, BOOT[1]); cv.rect(cx + 1, ly + l2, 2, 3 - l2, BOOT[1])
    # --- cloak body
    by = 12 + bob
    cv.poly([(cx - 4, by), (cx + 4, by), (cx + 5.5, by + 8), (cx - 5.5, by + 8)], CLOAK[1])
    cv.rect(cx - 5, by + 6, 10, 2, CLOAK[0])
    cv.rect(cx - 4, by, 2, 6, CLOAK[2])
    if d == 'up':
        # quiver + bow on back
        cv.rect(cx + 1, by - 1, 3, 8, WOOD[0]); cv.px(cx + 2, by - 2, C('d8d0c0')); cv.px(cx + 3, by - 2, C('d8d0c0'))
        cv.line(cx - 4, by - 1, cx - 4, by + 7, WOOD[1])
    elif d == 'side':
        cv.rect(cx - 5, by + 1, 3, 6, WOOD[0]); cv.px(cx - 4, by, C('d8d0c0'))
    # --- head / hood
    cv.blob(cx, top + 4, 4.5, 4.5, CLOAK)
    if d == 'down':
        cv.rect(cx - 2, top + 4, 4, 3, C('231a2a'))
        cv.px(cx - 2 + 0, top + 5, C('ffe9a8')); cv.px(cx + 1, top + 5, C('ffe9a8'))
    elif d == 'side':
        cv.rect(cx, top + 4, 3, 3, C('231a2a'))
        cv.px(cx + 1, top + 5, C('ffe9a8'))
    else:
        cv.rect(cx - 1, top + 1, 2, 2, CLOAK[2])
    # scarf
    cv.rect(cx - 3, by - 1, 6, 2, SCARF[1]); cv.rect(cx - 3, by, 6, 1, SCARF[0])
    if d == 'side':
        tail = -1 if pose != 'run' else -2 - (i % 2)
        cv.rect(cx - 5 + tail + 1, by - 1, 3, 1, SCARF[1]); cv.px(cx - 6 + tail, by, SCARF[0])
    # --- bow / arms
    if pose == 'shoot':
        if d == 'side':
            cv.line(cx + 6, by - 1, cx + 6, by + 8, WOOD[1]); cv.px(cx + 5, by, WOOD[1]); cv.px(cx + 5, by + 7, WOOD[1])
            cv.rect(cx + 2, by + 3, 4, 2, SKIN[1])
            cv.line(cx + 5, by, cx + 5, by + 7, C('e8e0d0'))
        elif d == 'down':
            cv.line(cx - 7, by + 4, cx + 7, by + 4, WOOD[1]); cv.px(cx - 7, by + 3, WOOD[1]); cv.px(cx + 7, by + 3, WOOD[1])
            cv.rect(cx - 1, by + 3, 2, 3, SKIN[1])
        else:
            cv.line(cx - 7, by - 1, cx + 7, by - 1, WOOD[1]); cv.rect(cx - 1, by - 3, 2, 3, SKIN[1])
    elif pose == 'recall':
        # raised open hand with glow
        hx = cx + (6 if d != 'side' else 5)
        cv.rect(hx - 1, by - 5, 3, 4, SKIN[1]); cv.rect(hx, by - 3, 1, 5, CLOAK[1])
        for gx, gy in ((hx - 2, by - 7), (hx + 2, by - 7), (hx, by - 8)):
            cv.px(gx, gy, C('ffd070'))
    else:
        # relaxed arm
        cv.rect(cx + 4, by + 2, 2, 5, CLOAK[0]); cv.px(cx + 4, by + 7, SKIN[1])
    cv.outline(OL)
    return cv


def roll(i):
    cv = Cv(24, 24)
    cv.blob(12, 15, 6.5, 6, CLOAK)
    if i == 0:
        cv.line(7, 11, 16, 19, CLOAK[0]); cv.px(17, 12, SCARF[1]); cv.px(18, 12, SCARF[1]); cv.px(16, 12, SCARF[0])
        cv.rect(8, 18, 3, 2, BOOT[1])
    else:
        cv.line(16, 11, 8, 19, CLOAK[0]); cv.px(6, 17, SCARF[1]); cv.px(7, 17, SCARF[1]); cv.px(7, 16, SCARF[0])
        cv.rect(14, 10, 3, 2, BOOT[1])
    cv.outline(OL)
    return cv


def death(i):
    cv = Cv(24, 24)
    if i == 0:
        f = player('down', 'idle', 0).flash(t=0.85)
        return f
    if i == 1:
        cv.poly([(6, 12), (14, 8), (19, 20), (9, 22)], CLOAK[1])
        cv.blob(16, 9, 4, 4, CLOAK); cv.rect(15, 9, 2, 2, C('231a2a'))
        cv.rect(4, 20, 4, 2, BOOT[1])
        cv.rect(7, 11, 5, 2, SCARF[1])
    else:
        cv.poly([(3, 16), (17, 15), (18, 22), (3, 22)], CLOAK[1])
        cv.rect(3, 20, 15, 2, CLOAK[0])
        cv.blob(19, 19, 3.5, 3.5, CLOAK); cv.px(19, 19, C('ffe9a8') if i == 2 else C('231a2a'))
        cv.rect(0, 19, 3, 3, BOOT[1])
        cv.rect(8, 14, 5, 2, SCARF[1])
        if i == 3:
            cv.line(11, 12, 11, 15, C('d8d0c0'))
    cv.outline(OL)
    if i == 3:
        for y in range(24):
            for x in range(24):
                c = cv.p[x, y]
                if c[3] > 0:
                    cv.p[x, y] = mix(c, (20, 16, 30, 255), 0.35)
    return cv


def arrow_img():
    cv = Cv(16, 5)
    cv.rect(2, 2, 11, 1, C('b98a4a'))
    cv.rect(2, 3, 11, 1, C('7a5628'))
    cv.px(0, 0, C('d94a4a')); cv.px(1, 1, C('d94a4a')); cv.px(0, 4, C('d94a4a')); cv.px(1, 3, C('d94a4a'))
    cv.px(1, 0, C('a02a2a')); cv.px(2, 1, C('a02a2a'))
    cv.poly([(12, 0), (16, 2.5), (12, 5)], C('e8ecf4'))
    cv.px(12, 2, C('8a95a8')); cv.px(13, 2, C('c9d0dc'))
    return cv


def gen(out):
    frames = []
    for d in ('down', 'up', 'side'):
        row = []
        for i in range(2): row.append(player(d, 'idle', i))
        for i in range(4): row.append(player(d, 'run', i))
        row.append(player(d, 'shoot', 0))
        row.append(player(d, 'recall', 0))
        row.append(roll(0)); row.append(roll(1))
        frames += row
    frames += [death(i) for i in range(4)] + [Cv(24, 24) for _ in range(6)]
    sheet(frames, out + '/player/player.png', cols=10)
    arrow_img().save(out + '/player/arrow.png')
