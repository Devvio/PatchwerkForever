"""Stand-in pictures for the options window (base 2.10.0) until the drawn ones are there.

    python options_art.py          write them (only where no drawn picture has been taken in)

The window (addons/PatchwerkForever/Window.lua) is dressed with two pictures:
    Media/parchment.tga    the page, behind everything
    Media/leather.tga      the left column, behind the parts
The drawn ones are yours (OPTIONS-BLUEPRINT.md, D8): save art/PatchwerkForever/parchment.png and
art/PatchwerkForever/leather.png and art.py (run by build.py) makes them the game's pictures in
place of these. These are worked out here, from noise and a few formulas, nothing copied: a warm
cream sheet with soft blotches and a darker rim, and a brown hide with a fine grain and creases.
"""
import math
import os
import random
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import art  # noqa: E402

MEDIA = os.path.join(art.ADDONS, "PatchwerkForever", "Media")
SIDE = 256


def noise(seed, cells):
    """Smooth value noise that wraps at the edges, 0..1, cells across."""
    rnd = random.Random(seed)
    grid = [[rnd.random() for _ in range(cells)] for _ in range(cells)]

    def at(x, y):
        gx, gy = x * cells, y * cells
        x0, y0 = int(gx) % cells, int(gy) % cells
        x1, y1 = (x0 + 1) % cells, (y0 + 1) % cells
        fx, fy = gx - int(gx), gy - int(gy)
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        top = grid[y0][x0] * (1 - sx) + grid[y0][x1] * sx
        bottom = grid[y1][x0] * (1 - sx) + grid[y1][x1] * sx
        return top * (1 - sy) + bottom * sy
    return at


def layered(seed, octaves):
    layers = [noise(seed + i, 4 * 2 ** i) for i in range(octaves)]

    def at(x, y):
        total, weight, w = 0.0, 0.0, 1.0
        for layer in layers:
            total += layer(x, y) * w
            weight += w
            w *= 0.5
        return total / weight
    return at


def clamp(v):
    return max(0, min(255, int(round(v))))


def parchment():
    blotch, fibre = layered(11, 5), noise(29, 64)
    rows = []
    for j in range(SIDE):
        row = []
        for i in range(SIDE):
            x, y = i / SIDE, j / SIDE
            b = blotch(x, y)
            f = fibre(x, y * 0.25)
            # (a darker rim, so the page reads as a sheet)
            edge = min(x, 1 - x, y, 1 - y)
            rim = max(0.0, 0.12 - edge) / 0.12
            shade = 0.86 + 0.16 * (b - 0.5) + 0.04 * (f - 0.5) - 0.18 * rim * rim
            row.append((clamp(232 * shade), clamp(206 * shade), clamp(158 * shade), 255))
        rows.append(row)
    return rows


def leather():
    grain, crease, pore = layered(41, 5), noise(57, 6), noise(73, 96)
    rows = []
    for j in range(SIDE):
        row = []
        for i in range(SIDE):
            x, y = i / SIDE, j / SIDE
            g = grain(x, y)
            c = abs(crease(x, y) - 0.5) * 2              # (thin dark lines where the noise crosses its middle)
            p = pore(x, y)
            shade = 0.80 + 0.30 * (g - 0.5) - 0.10 * max(0.0, 0.04 - c) / 0.04 - 0.05 * (p > 0.80)
            row.append((clamp(92 * shade), clamp(58 * shade), clamp(34 * shade), 255))
        rows.append(row)
    return rows


def main():
    for name, make in (("parchment", parchment), ("leather", leather)):
        if os.path.exists(os.path.join(art.ART, "PatchwerkForever", name + ".png")):
            print("%s: your drawn picture is used (art/PatchwerkForever/%s.png)" % (name, name))
            continue
        path = os.path.join(MEDIA, name + ".tga")
        wrote = art._write(path, art.tga_bytes(make()))
        print("%s: %s" % (name, "written" if wrote else "unchanged"), path)
        preview = os.path.join(art.RELEASE, "options-%s.png" % name)
        art._write(preview, art.png_bytes(make()))


if __name__ == "__main__":
    main()
