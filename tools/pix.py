"""Tiny pixel-art painting toolkit used to generate every sprite in the game."""
import math
import random
from PIL import Image

OUT = None  # set by gen_all


def C(h, a=255):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def tri(hexc):
    """dark / base / light ramp from one base colour (cool shadows, warm lights)."""
    b = C(hexc)
    dark = mix(b, (10, 8, 30, 255), 0.45)
    light = mix(b, (255, 240, 200, 255), 0.35)
    return (dark, b, light)


class Cv:
    def __init__(s, w, h):
        s.w, s.h = w, h
        s.im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
        s.p = s.im.load()

    # --- primitives -------------------------------------------------
    def px(s, x, y, c):
        x = int(x); y = int(y)
        if 0 <= x < s.w and 0 <= y < s.h and c is not None:
            s.p[x, y] = c

    def get(s, x, y):
        if 0 <= x < s.w and 0 <= y < s.h:
            return s.p[x, y]
        return (0, 0, 0, 0)

    def rect(s, x, y, w, h, c):
        for j in range(int(h)):
            for i in range(int(w)):
                s.px(x + i, y + j, c)

    def srect(s, x, y, w, h, pal):
        """rect with simple bevel shading: light top/left, dark bottom/right."""
        d, b, l = pal
        s.rect(x, y, w, h, b)
        s.rect(x, y, w, 1, l)
        s.rect(x, y, 1, h, l)
        s.rect(x, y + h - 1, w, 1, d)
        s.rect(x + w - 1, y, 1, h, d)

    def line(s, x0, y0, x1, y1, c):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            s.px(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy; x0 += sx
            if e2 <= dx:
                err += dx; y0 += sy

    def blob(s, cx, cy, rx, ry, pal, light=(-0.5, -0.7)):
        d, b, l = pal
        ln = math.hypot(*light)
        lx, ly = light[0] / ln, light[1] / ln
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                nx = (x + .5 - cx) / rx
                ny = (y + .5 - cy) / ry
                dd = nx * nx + ny * ny
                if dd <= 1:
                    nz = math.sqrt(max(0, 1 - dd))
                    lit = -(nx * lx + ny * ly) * 0.9 + nz * 0.55
                    if lit > 0.80:
                        s.px(x, y, l)
                    elif lit > 0.05:
                        s.px(x, y, b)
                    else:
                        s.px(x, y, d)

    def poly(s, pts, c):
        # scanline fill
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            xs = []
            n = len(pts)
            for i in range(n):
                x0, y0 = pts[i]; x1, y1 = pts[(i + 1) % n]
                if (y0 <= y + .5 < y1) or (y1 <= y + .5 < y0):
                    xs.append(x0 + (y + .5 - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(round(xs[i])), int(round(xs[i + 1]))):
                    s.px(x, y, c)

    def outline(s, col, diag=False):
        src = s.im.copy(); sp = src.load()
        for y in range(s.h):
            for x in range(s.w):
                if sp[x, y][3] == 0:
                    nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
                    if diag:
                        nb += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
                    for dx, dy in nb:
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < s.w and 0 <= yy < s.h and sp[xx, yy][3] > 200:
                            s.p[x, y] = col
                            break

    def noise(s, x, y, w, h, cols, density, seed=1):
        r = random.Random(seed)
        for j in range(h):
            for i in range(w):
                if r.random() < density and s.get(x + i, y + j)[3] > 0:
                    s.px(x + i, y + j, r.choice(cols))

    def paste(s, o, x, y, flip=False):
        im = o.im.transpose(Image.FLIP_LEFT_RIGHT) if flip else o.im
        tmp = Image.new('RGBA', (s.w, s.h), (0, 0, 0, 0))
        tmp.paste(im, (int(x), int(y)))
        s.im.alpha_composite(tmp)
        s.p = s.im.load()

    def flipped(s):
        n = Cv(s.w, s.h)
        n.im = s.im.transpose(Image.FLIP_LEFT_RIGHT)
        n.p = n.im.load()
        return n

    def flash(s, col=(255, 255, 255, 255), t=0.7):
        n = Cv(s.w, s.h)
        for y in range(s.h):
            for x in range(s.w):
                c = s.p[x, y]
                if c[3] > 0:
                    n.p[x, y] = mix(c, col, t)[:3] + (c[3],)
        return n

    def save(s, path):
        s.im.save(path)


def sheet(frames, path, cols=None):
    """pack same-size frames into a grid, return (cols, rows)"""
    n = len(frames)
    cols = cols or n
    rows = (n + cols - 1) // cols
    w, h = frames[0].w, frames[0].h
    im = Image.new('RGBA', (w * cols, h * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        im.paste(f.im, ((i % cols) * w, (i // cols) * h))
    im.save(path)
    return cols, rows
