"""Draw the pictures Sparkle (Thread)'s effects and Routes (Thread)'s dotted trail are made of.

    python media.py

Writes plain white shapes with soft edges (the game tints them) as 32-bit TGA files into the Media
folder of the addon that uses each (the dot into Routes, the rest into Sparkle), and a PNG copy of each into world/media_preview/ to look at here. Every shape is worked
out from a formula in this file: none is copied from anywhere.

    star      a four-pointed twinkle
    glow      a soft round light
    ring      a thin circle
    beam      a pillar of light, bright at its foot
    arcs      three arcs of a circle (turned, they swirl)
    bracket   one corner of a frame (the other three are this one mirrored)
    dot       a small soft dot, for the dotted trail
    glint     a fine twinkle with hair-thin rays
    mote      a soft speck of light
    streak    a speed line, faint at its inner end and bright toward its outer (Plainsrunning)
    vignette  a frame darkening toward the edges, clear in the middle (Plainsrunning)
    wisp      a soft thread of air, even along its length, for the wind gusts (Plainsrunning)
    speck     a soft speck of dust (Plainsrunning)
    seed      a grass seed: a soft head trailing a fine tail (Plainsrunning)
    warp      a thin ring, for the warp rings (Plainsrunning)
    edgeglow  a glow hugging the edges of the screen, clear in the middle (Plainsrunning)
    leaf      a leaf, pointed at both ends, with a fainter midrib (Sparkle's Falling Leaves)
    ember     a rising spark: a bright head trailing a short tail below it (Sparkle's Embers)
    coin      a coin face on, with a rim and a highlight (Sparkle's Coin Glints; turned by narrowing it)
    rays      twelve soft rays round a middle (Sparkle's Sun Rays)
"""
import math
import os
import struct

from terrain import write_png

ADDONS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "addons"))


PLAINS = ("streak", "vignette", "wisp", "speck", "seed", "warp", "edgeglow")


def out(name):
    """Where a picture goes: the Media folder of the addon that uses it."""
    addon = ("PatchwerkForever_Thread_Routes" if name == "dot"
             else "PatchwerkForever_Thread_Plainsrunning" if name in PLAINS
             else "PatchwerkForever_Thread_Sparkle")
    return os.path.join(ADDONS, addon, "Media")


PREVIEW = "world/media_preview"


def clamp(v):
    return 0.0 if v < 0 else 1.0 if v > 1 else v


def star(x, y):
    ax, ay = abs(x), abs(y)
    spikes = clamp(1.0 - (math.sqrt(ax) + math.sqrt(ay)) ** 2) ** 1.6       # the four long points
    r = math.hypot(x, y)
    core = math.exp(-(r / 0.16) ** 2)                                        # a bright middle
    halo = 0.25 * math.exp(-(r / 0.45) ** 2)
    return clamp(spikes + core + halo) * clamp((1.0 - r) * 6)


def glow(x, y):
    r = math.hypot(x, y)
    return math.exp(-(r / 0.42) ** 2) * clamp((1.0 - r) * 5)


def ring(x, y):
    r = math.hypot(x, y)
    return math.exp(-((r - 0.82) / 0.05) ** 2)


def beam(x, y):
    """x across (-1..1), y from the foot (-1) to the top (1)."""
    up = (y + 1) / 2.0
    across = math.exp(-(x / (0.42 - 0.22 * up)) ** 2)                        # narrower toward the top
    return across * (1.0 - up) ** 1.3 * clamp(up * 12) * clamp((1 - abs(x)) * 6)


def arcs(x, y):
    r = math.hypot(x, y)
    band = math.exp(-((r - 0.78) / 0.07) ** 2)
    a = math.degrees(math.atan2(y, x)) % 120.0                               # three arcs
    head = clamp((a - 5) / 12.0) * clamp((85 - a) / 55.0)                    # sharp at one end, fading at the other
    return band * head


def bracket(x, y):
    """The top-left corner: a bar along the top and one down the left."""
    u, v = (x + 1) / 2.0, (1 - y) / 2.0                                       # 0..1 from the top-left
    thick, long_ = 0.20, 0.85
    def bar(along, across):
        return clamp((thick - across) * 14) * clamp((long_ - along) * 10) * clamp(across * 30 + 1)
    return clamp(max(bar(u, v), bar(v, u)))


def dot(x, y):
    r = math.hypot(x, y)
    return clamp((0.78 - r) * 7)


def glint(x, y):
    """A fine twinkle: four hair-thin rays and a pinpoint middle (the subtle effects)."""
    ax, ay = abs(x), abs(y)
    def ray(along, across):
        return math.exp(-(across / 0.035) ** 2) * clamp(1.0 - along / 0.95) ** 2.2
    r = math.hypot(x, y)
    core = math.exp(-(r / 0.10) ** 2)
    return clamp(max(ray(ax, ay), ray(ay, ax)) + core) * clamp((1.0 - r) * 6)


def mote(x, y):
    """A speck of light, soft all the way out (a firefly, a wisp)."""
    r = math.hypot(x, y)
    return math.exp(-(r / 0.5) ** 2) * clamp((1.0 - r) * 4)


def streak(x, y):
    """x along the line (-1 its inner end, 1 its outer), y across. Drawn on a Line, stretched along it."""
    along = (x + 1) / 2.0
    across = math.exp(-(y / 0.32) ** 2) * clamp((1 - abs(y)) * 4)
    return across * along ** 1.6 * clamp((1.0 - x) * 10)


def vignette(x, y):
    """Clear in the middle, darker toward the edges and darkest in the corners (stretched over the screen)."""
    r = math.hypot(x, y)
    return clamp((r - 0.45) / 0.95) ** 1.5


def wisp(x, y):
    """x along (-1..1), y across: even along its length, soft across and at both ends (a Line, stretched)."""
    across = math.exp(-(y / 0.36) ** 2) * clamp((1 - abs(y)) * 4)
    return across * clamp((1 - abs(x)) * 8)


def speck(x, y):
    r = math.hypot(x, y)
    return math.exp(-(r / 0.4) ** 2) * clamp((1.0 - r) * 4)


def seed(x, y):
    """Pointing right (+x): a soft head, and a fine tail behind it fading to nothing."""
    head = math.exp(-(((x - 0.5) / 0.32) ** 2 + (y / 0.55) ** 2))
    tail = math.exp(-(y / 0.13) ** 2) * clamp((x + 0.95) / 1.2) ** 1.5 * clamp((0.6 - x) * 6)
    return clamp(head + 0.8 * tail) * clamp((1 - abs(x)) * 10) * clamp((1 - abs(y)) * 6)


def warp(x, y):
    r = math.hypot(x, y)
    return math.exp(-((r - 0.9) / 0.035) ** 2) + 0.15 * math.exp(-((r - 0.84) / 0.06) ** 2) * clamp((1 - r) * 20)


def edgeglow(x, y):
    """Hugs the edges: a rounded square's distance (so the sides glow too, not only the corners)."""
    d = (abs(x) ** 4 + abs(y) ** 4) ** 0.25
    return clamp((d - 0.55) / 0.5) ** 1.7


def leaf(x, y):
    """Lying corner to corner, pointed at both ends, with a fainter line down its middle."""
    c = math.sqrt(0.5)
    u, v = (x * c + y * c) / 0.95, (-x * c + y * c)
    if abs(u) >= 1:
        return 0.0
    half = 0.36 * (1 - u * u) ** 0.9
    body = clamp((half - abs(v)) / 0.06)
    rib = 1 - 0.35 * math.exp(-(v / 0.025) ** 2) * clamp((0.9 - abs(u)) * 5)
    return body * rib


def ember(x, y):
    """Rising: the bright head at the top, a short tail fading below it."""
    head = math.exp(-((x / 0.3) ** 2 + ((y - 0.45) / 0.2) ** 2))
    tail = math.exp(-(x / (0.06 + 0.1 * clamp((y + 0.9) / 1.35))) ** 2) * clamp((y + 0.9) / 1.35) ** 1.6 * clamp((0.5 - y) * 4)
    return clamp(head + 0.7 * tail) * clamp((1 - abs(x)) * 6) * clamp((1 - abs(y)) * 8)


def coin(x, y):
    r = math.hypot(x, y)
    body = clamp((0.86 - r) / 0.05)
    rim = math.exp(-((r - 0.74) / 0.05) ** 2)
    shine = math.exp(-(((x + 0.3) / 0.28) ** 2 + ((y - 0.3) / 0.28) ** 2))
    return clamp(body * 0.62 + 0.3 * rim + 0.35 * shine * body)


def rays(x, y):
    r = math.hypot(x, y)
    a = math.atan2(y, x)
    ray = (0.5 + 0.5 * math.cos(12 * a)) ** 6
    return ray * math.exp(-(r / 0.62) ** 2) * clamp((1 - r) * 4) * clamp(r / 0.12)


SHAPES = {"star": (star, 128, 128), "glow": (glow, 128, 128), "ring": (ring, 128, 128), "beam": (beam, 64, 256),
          "arcs": (arcs, 128, 128), "bracket": (bracket, 64, 64), "dot": (dot, 32, 32),
          "glint": (glint, 64, 64), "mote": (mote, 32, 32),
          "streak": (streak, 256, 32), "vignette": (vignette, 128, 128),
          "wisp": (wisp, 128, 16), "speck": (speck, 32, 32), "seed": (seed, 64, 32), "warp": (warp, 256, 256),
          "edgeglow": (edgeglow, 128, 128),
          "leaf": (leaf, 64, 64), "ember": (ember, 32, 64), "coin": (coin, 64, 64), "rays": (rays, 128, 128)}


def draw(shape, width, height):
    """Rows from the top, each a list of alpha 0..255."""
    rows = []
    for j in range(height):
        y = 1.0 - (j + 0.5) / height * 2.0
        row = []
        for i in range(width):
            x = (i + 0.5) / width * 2.0 - 1.0
            # four samples a pixel, for smooth edges
            total = 0.0
            for dx in (-0.25, 0.25):
                for dy in (-0.25, 0.25):
                    total += shape(x + dx * 2.0 / width, y + dy * 2.0 / height)
            row.append(int(round(clamp(total / 4.0) * 255)))
        rows.append(row)
    return rows


def write_tga(path, rows):
    height, width = len(rows), len(rows[0])
    # uncompressed true colour, 32 bits, rows from the bottom up (the usual way), 8 bits of alpha
    head = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    with open(path, "wb") as f:
        f.write(head)
        for row in reversed(rows):
            f.write(b"".join(bytes((255, 255, 255, a)) for a in row))


def main(only=None):
    """Draws every picture, or only those named on the command line (python media.py leaf ember)."""
    os.makedirs(PREVIEW, exist_ok=True)
    for name, (shape, width, height) in SHAPES.items():
        if only and name not in only:
            continue
        rows = draw(shape, width, height)
        os.makedirs(out(name), exist_ok=True)
        write_tga(os.path.join(out(name), name + ".tga"), rows)
        # the preview: the shape in white on dark grey
        write_png(os.path.join(PREVIEW, name + ".png"), width, height,
                  [bytes(b for a in row for b in (40 + a * 215 // 255,) * 3) for row in rows])
        lit = sum(1 for row in rows for a in row if a > 8)
        print("%-8s %3d x %3d, %2d%% of it lit, brightest %d" % (name, width, height, 100 * lit // (width * height), max(max(r) for r in rows)))


if __name__ == "__main__":
    import sys
    main(sys.argv[1:] or None)
