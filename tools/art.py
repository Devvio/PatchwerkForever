"""The addons' art: the icon each shows in the game's addon list, and the logo CurseForge asks for.

    python art.py              draw every icon, take in your own pictures, write the files
    python art.py <folder>     only that addon's (PatchwerkForever_Stitch_ConsolePort, ...)

For each addon this writes
    addons/<folder>/Media/icon.tga       64 x 64, the game's format; the TOC's IconTexture line names it
    release/<folder>/logo.png            512 x 512, for the CurseForge project
and one sheet of all of them to look at: release/art-preview.png.

The icons are a family: a sewn-on patch with gold stitching, the cloth a colour of its own for each
addon and an emblem in the middle (a stitched seam for the base, a gamepad, menu bars, a winding
road, a compass star, a twinkle, a ticked list). Every one is worked out from the formulas in this file; nothing is copied.

Your own art. Put a PNG in the repository's art folder and it is used in place of the drawn one:
    art/<folder>/icon.png        the icon (any square size; made 64 x 64 for the game)
    art/<folder>/logo.png        the CurseForge logo (else it is made from the icon)
    art/<folder>/<name>.png      any other picture: becomes addons/<folder>/Media/<name>.tga
build.py takes these in on every build (take_in below), so saving a PNG is enough. PNGs must be
8 or 16 bits a channel and not interlaced. Pictures for the game are made a power of two on each
side, which the game wants.
"""
import json
import math
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, ".."))
ADDONS = os.path.join(REPO, "addons")
ART = os.path.join(REPO, "art")
RELEASE = os.path.join(REPO, "release")
ICON = 64                    # the icon's side in the game
LOGO = 512                   # the logo's side
GOLD = (214, 163, 91)        # Patchwerk's gold, the stitching
CREAM = (244, 226, 184)      # the emblems
RIM = (20, 15, 12)
# Pictures in an addon's art folder, under listing/, that are also made into a picture the addon
# shows in the game: { addon: { path under art/<addon>/: (width, height) in the game } }. The game
# wants each side a power of two; the addon draws it at whatever shape it likes.
ALSO_SHIPPED = {"PatchwerkForever": {"listing/banner.png": (1024, 512)}}


# ----------------------------------------------------------------------------------------------
# Shapes: each gives the distance from a point to its edge, below zero inside. x right, y up, -1..1.
# ----------------------------------------------------------------------------------------------
def box(x, y, cx, cy, hx, hy, r):
    """A rounded box: centre, half sizes, corner radius."""
    qx, qy = abs(x - cx) - hx + r, abs(y - cy) - hy + r
    return math.hypot(max(qx, 0.0), max(qy, 0.0)) + min(max(qx, qy), 0.0) - r


def circle(x, y, cx, cy, r):
    return math.hypot(x - cx, y - cy) - r


def stroke(x, y, ax, ay, bx, by, r):
    """A line from a to b with round ends, r thick each side."""
    px, py, dx, dy = x - ax, y - ay, bx - ax, by - ay
    t = max(0.0, min(1.0, (px * dx + py * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - dx * t, py - dy * t) - r


def patch(x, y):
    return box(x, y, 0, 0, 0.90, 0.90, 0.28)


def stitches(x, y):
    """The dashes sewn round the patch. The patch is the same in every corner, so one eighth is worked out."""
    x, y = abs(x), abs(y)
    if y > x:
        x, y = y, x
    d = stroke(x, y, 0.71, -0.07, 0.71, 0.07, 0.03)
    d = min(d, stroke(x, y, 0.71, 0.19, 0.71, 0.33, 0.03))
    d = min(d, stroke(x, y, 0.71, 0.45, 0.70, 0.57, 0.03))
    return min(d, stroke(x, y, 0.66, 0.66, 0.66, 0.66001, 0.036))     # a knot in the corner


# ---- the emblems: (distance to the emblem, distance to what is cut out of it) -----------------------
def seam(x, y):
    """The base: a scar sewn shut with three cross stitches."""
    d = stroke(x, y, -0.40, -0.40, 0.40, 0.40, 0.045)
    for t in (-0.25, 0.0, 0.25):
        d = min(d, stroke(x, y, t - 0.17, t + 0.17, t + 0.17, t - 0.17, 0.045))
    return d, 1.0


def book(x, y):
    """Dungeon Journal: an open book, two pages with lines of writing cut out."""
    d = min(box(x, y, -0.26, 0.0, 0.22, 0.34, 0.05), box(x, y, 0.26, 0.0, 0.22, 0.34, 0.05))
    cut = 1.0
    for side in (-0.26, 0.26):
        for row in (0.18, 0.02, -0.14):
            cut = min(cut, box(x, y, side, row, 0.13, 0.03, 0.02))
    return d, cut


def gamepad(x, y):
    """Console Port: a controller, with its cross and two buttons cut out."""
    d = box(x, y, 0, 0.07, 0.50, 0.22, 0.20)
    d = min(d, stroke(x, y, -0.36, 0.02, -0.44, -0.26, 0.14), stroke(x, y, 0.36, 0.02, 0.44, -0.26, 0.14))
    cut = min(box(x, y, -0.24, 0.08, 0.125, 0.04, 0.02), box(x, y, -0.24, 0.08, 0.04, 0.125, 0.02))
    cut = min(cut, circle(x, y, 0.17, 0.02, 0.06), circle(x, y, 0.31, 0.14, 0.06))
    return d, cut


def bars(x, y):
    """MelloUI: the buttons of a menu."""
    d = min(box(x, y, 0, 0.30, 0.42, 0.095, 0.095), box(x, y, 0, 0.0, 0.42, 0.095, 0.095),
            box(x, y, 0, -0.30, 0.42, 0.095, 0.095))
    return d, 1.0


def _bend(cx, cy, r, a0, a1, n=10):
    return [(cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


# a road that doubles back twice: along the bottom, round to the right, back across the middle,
# round to the left, and along the top
_ROAD = [(-0.30, -0.36)] + _bend(0.20, -0.18, 0.18, -90, 90) + _bend(-0.20, 0.18, 0.18, 270, 90) + [(0.14, 0.36)]


def road(x, y):
    """MelloUI Route: a winding road from a dot to a ringed place."""
    d = 9.0
    for (ax, ay), (bx, by) in zip(_ROAD, _ROAD[1:]):
        d = min(d, stroke(x, y, ax, ay, bx, by, 0.05))
    d = min(d, circle(x, y, -0.40, -0.36, 0.09), circle(x, y, 0.30, 0.36, 0.15))
    return d, circle(x, y, 0.30, 0.36, 0.07)


def compass(x, y):
    """Thread (Routes): a four-pointed compass star."""
    s = 0.56
    ax, ay = abs(x) / s, abs(y) / s
    d = ((math.sqrt(ax) + math.sqrt(ay)) ** 2 - 1.0) * s * 0.42          # close to a distance near the edge
    return min(d, circle(x, y, 0, 0, 0.13)), circle(x, y, 0, 0, 0.055)


def _glint(x, y, cx, cy, s):
    ax, ay = abs(x - cx) / s, abs(y - cy) / s
    return ((math.sqrt(ax) + math.sqrt(ay)) ** 2 - 1.0) * s * 0.42


def glints(x, y):
    """Thread (Sparkle): a twinkle with two smaller ones beside it."""
    d = min(_glint(x, y, -0.08, -0.06, 0.46), circle(x, y, -0.08, -0.06, 0.09))
    d = min(d, _glint(x, y, 0.36, 0.30, 0.22), _glint(x, y, 0.30, -0.36, 0.15))
    return d, 1.0


def checklist(x, y):
    """Thread (Tracker): a list of three things, the first two ticked."""
    d, cut = 9.0, 1.0
    for row, ticked in ((0.32, True), (0.0, True), (-0.32, False)):
        d = min(d, box(x, y, 0.12, row, 0.30, 0.06, 0.06))
        if ticked:
            d = min(d, stroke(x, y, -0.42, row, -0.35, row - 0.08, 0.04), stroke(x, y, -0.35, row - 0.08, -0.24, row + 0.09, 0.04))
        else:
            d = min(d, abs(circle(x, y, -0.33, row, 0.075)) - 0.03)
    return d, cut


def _side(x, y, ax, ay, bx, by):
    """How far a point is outside the line from a to b (on its right, going from a to b)."""
    dx, dy = bx - ax, by - ay
    n = math.hypot(dx, dy)
    return ((x - ax) * dy - (y - ay) * dx) / n


def flag(x, y):
    """Thread (Races): a pennant on a pole, for a checkpoint."""
    pole = box(x, y, -0.30, -0.01, 0.045, 0.47, 0.02)
    # the pennant: a triangle from the top of the pole, pointing right (corners taken anticlockwise)
    a, b, c = (-0.27, 0.46), (-0.27, 0.02), (0.42, 0.24)
    tri = max(_side(x, y, *a, *b), _side(x, y, *b, *c), _side(x, y, *c, *a))
    return min(pole, tri), 1.0


def speed(x, y):
    """Thread (Plainsrunning): speed lines streaming behind a double chevron, pointing ahead."""
    d = min(stroke(x, y, -0.50, 0.26, -0.12, 0.26, 0.045),
            stroke(x, y, -0.58, 0.0, -0.18, 0.0, 0.045),
            stroke(x, y, -0.50, -0.26, -0.12, -0.26, 0.045))
    for at in (0.0, 0.26):
        d = min(d, stroke(x, y, at, 0.32, at + 0.22, 0.0, 0.06), stroke(x, y, at + 0.22, 0.0, at, -0.32, 0.06))
    return d, 1.0


# folder: (the cloth's colour at the top, at the bottom, the emblem)
ICONS = {
    "PatchwerkForever":              ((92, 66, 50), (52, 36, 28), seam),
    "PatchwerkForever_Stitch_ConsolePort":  ((54, 78, 110), (28, 40, 62), gamepad),
    "PatchwerkForever_Stitch_MelloUI":      ((52, 96, 78), (26, 52, 44), bars),
    "PatchwerkForever_Stitch_MelloUIRoute": ((84, 68, 128), (44, 34, 74), road),
    "PatchwerkForever_Stitch_DungeonJournal": ((118, 62, 54), (62, 30, 26), book),
    "PatchwerkForever_Thread_Routes":     ((42, 100, 118), (20, 54, 68), compass),
    "PatchwerkForever_Thread_Sparkle":    ((122, 58, 96), (66, 28, 54), glints),
    "PatchwerkForever_Thread_Tracker":    ((150, 108, 62), (92, 60, 32), checklist),
    "PatchwerkForever_Thread_Races":      ((40, 112, 72), (20, 60, 38), flag),
    "PatchwerkForever_Thread_Plainsrunning": ((140, 112, 46), (80, 60, 22), speed),
}


def _cover(d, soft):
    """How much of a sample a shape covers, from its distance."""
    return 0.0 if d >= soft else 1.0 if d <= -soft else 0.5 - d / (2.0 * soft)


def _over(dst, colour, a):
    """Lay a colour over a sample (r, g, b, alpha), straight alpha."""
    if a <= 0.0:
        return dst
    r, g, b, da = dst
    out = a + da * (1.0 - a)
    return ((colour[0] * a + r * da * (1.0 - a)) / out, (colour[1] * a + g * da * (1.0 - a)) / out,
            (colour[2] * a + b * da * (1.0 - a)) / out, out)


def draw(folder, size=LOGO):
    """The drawn icon as rows from the top, each a list of (r, g, b, a) 0..255."""
    top, bottom, emblem = ICONS[folder]
    soft = 1.5 / size                           # an edge is about a pixel and a half wide
    rows = []
    for j in range(size):
        row = []
        for i in range(size):
            acc = [0.0, 0.0, 0.0, 0.0]
            for sx in (0.25, 0.75):
                for sy in (0.25, 0.75):
                    x = (i + sx) / size * 2.0 - 1.0
                    y = 1.0 - (j + sy) / size * 2.0
                    p = patch(x, y)
                    if p >= soft:
                        continue
                    t = (1.0 - y) / 2.0
                    # the cloth: lighter at the top, a little light across the upper left, a weave
                    weave = 1.0 + 0.035 * math.sin(x * 46.0) * math.sin(y * 46.0)
                    glow = 1.0 + 0.16 * max(0.0, 1.0 - math.hypot(x + 0.45, y - 0.5) / 1.3)
                    cloth = tuple(min(255.0, (top[k] + (bottom[k] - top[k]) * t) * weave * glow) for k in range(3))
                    s = (cloth[0], cloth[1], cloth[2], _cover(p, soft))
                    s = _over(s, RIM, _cover(-p - 0.055, soft) * s[3])                      # the dark edge
                    s = _over(s, (0, 0, 0), 0.45 * _cover(stitches(x - 0.012, y + 0.016), soft) * s[3])
                    s = _over(s, GOLD, _cover(stitches(x, y), soft) * s[3])
                    d, cut = emblem(x - 0.014, y + 0.02)
                    s = _over(s, (0, 0, 0), 0.5 * _cover(max(d, -cut), soft * 2.0) * s[3])  # its shadow
                    d, cut = emblem(x, y)
                    s = _over(s, CREAM, _cover(max(d, -cut), soft) * s[3])
                    acc[0] += s[0] * s[3]
                    acc[1] += s[1] * s[3]
                    acc[2] += s[2] * s[3]
                    acc[3] += s[3]
            a = acc[3] / 4.0
            if a <= 0.0:
                row.append((0, 0, 0, 0))
            else:
                row.append((int(round(acc[0] / acc[3])), int(round(acc[1] / acc[3])),
                            int(round(acc[2] / acc[3])), int(round(a * 255))))
        rows.append(row)
    return rows


# ----------------------------------------------------------------------------------------------
# Pictures in and out
# ----------------------------------------------------------------------------------------------
def resize(rows, width, height):
    """The picture at another size: each new pixel is the average of the old ones under it."""
    oh, ow = len(rows), len(rows[0])
    if (ow, oh) == (width, height):
        return rows
    out = []
    for j in range(height):
        y0, y1 = j * oh / height, (j + 1) * oh / height
        row = []
        for i in range(width):
            x0, x1 = i * ow / width, (i + 1) * ow / width
            r = g = b = a = area = 0.0
            for yy in range(int(y0), min(oh, int(math.ceil(y1)))):
                wy = min(y1, yy + 1) - max(y0, yy)
                for xx in range(int(x0), min(ow, int(math.ceil(x1)))):
                    w = wy * (min(x1, xx + 1) - max(x0, xx))
                    pr, pg, pb, pa = rows[yy][xx]
                    r += pr * pa * w
                    g += pg * pa * w
                    b += pb * pa * w
                    a += pa * w
                    area += w
            if a <= 0.0:
                row.append((0, 0, 0, 0))
            else:
                row.append((int(round(r / a)), int(round(g / a)), int(round(b / a)), int(round(a / area))))
        out.append(row)
    return out


def tga_bytes(rows):
    """32-bit uncompressed TGA, rows from the bottom up, blue first: what the game reads."""
    height, width = len(rows), len(rows[0])
    head = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 8)
    return head + b"".join(bytes((b, g, r, a)) for row in reversed(rows) for (r, g, b, a) in row)


def png_bytes(rows):
    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    height, width = len(rows), len(rows[0])
    raw = b"".join(b"\0" + bytes(v for px in row for v in px) for row in rows)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def read_png(path):
    """A PNG as rows of (r, g, b, a). 8 or 16 bits a channel, any colour type, not interlaced."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("%s is not a PNG" % path)
    at, idat, palette, trans = 8, [], None, None
    while at < len(data):
        n, tag = struct.unpack(">I4s", data[at:at + 8])
        body = data[at + 8:at + 8 + n]
        at += 12 + n
        if tag == b"IHDR":
            width, height, depth, kind, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif tag == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif tag == b"tRNS":
            trans = body
        elif tag == b"IDAT":
            idat.append(body)
    if interlace:
        raise ValueError("%s is interlaced: save it without interlacing" % path)
    if depth not in (8, 16) and not (kind == 3 and depth == 8):
        raise ValueError("%s has %d bits a channel: save it with 8" % (path, depth))
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[kind]
    bpp = channels * depth // 8
    stride = width * bpp
    raw = zlib.decompress(b"".join(idat))
    rows, prev, pos = [], bytearray(stride), 0
    for _ in range(height):
        f = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
        step = depth // 8
        px = [line[i] for i in range(0, stride, step)]          # (16 bits: the high byte)
        row = []
        for i in range(0, len(px), channels):
            if kind == 0:
                row.append((px[i], px[i], px[i], 255))
            elif kind == 2:
                row.append((px[i], px[i + 1], px[i + 2], 255))
            elif kind == 3:
                r, g, b = palette[px[i]]
                row.append((r, g, b, trans[px[i]] if trans and px[i] < len(trans) else 255))
            elif kind == 4:
                row.append((px[i], px[i], px[i], px[i + 1]))
            else:
                row.append((px[i], px[i + 1], px[i + 2], px[i + 3]))
        rows.append(row)
    return rows


def _write(path, data):
    """Write only what changed. Returns whether it did."""
    if os.path.exists(path):
        with open(path, "rb") as f:
            if f.read() == data:
                return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)
    return True


def _power_of_two(n):
    return max(4, min(1024, 2 ** int(round(math.log(max(n, 1), 2)))))


def folders():
    return sorted(f for f in os.listdir(ADDONS) if os.path.isdir(os.path.join(ADDONS, f)))


def take_in(only=None, say=print):
    """Your own PNGs in art/<folder>/ made into the game's pictures. Returns what was written."""
    wrote = []
    if not os.path.isdir(ART):
        return wrote
    for folder in sorted(os.listdir(ART)):
        src = os.path.join(ART, folder)
        if not os.path.isdir(src) or (only and folder != only):
            continue
        if not os.path.isdir(os.path.join(ADDONS, folder)):
            say("  art/%s: there is no addon of that name" % folder)
            continue
        names = [(name, None) for name in sorted(os.listdir(src))]
        # (pictures made for the listing that the addon shows in the game too, at a size given here)
        names += [(name, size) for name, size in sorted(ALSO_SHIPPED.get(folder, {}).items())
                  if os.path.exists(os.path.join(src, name))]
        for name, size in names:
            stem, ext = os.path.splitext(os.path.basename(name))
            if ext.lower() != ".png" or stem == "logo":
                continue
            # (reading a large PNG takes seconds: one that has not changed since it was last made into
            # the game's picture is left alone)
            out = os.path.join(ADDONS, folder, "Media", stem + ".tga")
            stat = os.stat(os.path.join(src, name))
            stamp = [stat.st_mtime_ns, stat.st_size] + list(size or ())
            key = folder + "/" + name
            if os.path.exists(out) and _taken().get(key) == stamp:
                continue
            try:
                rows = read_png(os.path.join(src, name))
            except (ValueError, KeyError, zlib.error, struct.error, IndexError) as e:
                say("  art/%s/%s could not be read: %s" % (folder, name, e))
                continue
            h, w = len(rows), len(rows[0])
            tw, th = size or ((ICON, ICON) if stem == "icon" else (_power_of_two(w), _power_of_two(h)))
            if _write(out, tga_bytes(resize(rows, tw, th))):
                wrote.append(out)
                say("  art/%s/%s (%d x %d) -> Media/%s.tga (%d x %d)" % (folder, name, w, h, stem, tw, th))
            _taken()[key] = stamp
            _taken(save=True)
    return wrote


_TAKEN = None


def _taken(save=False):
    """Which of your PNGs have been made into the game's pictures, and as they were then (their time
    and size): art/.taken.json, a file of this machine's that git does not keep."""
    global _TAKEN
    path = os.path.join(ART, ".taken.json")
    if _TAKEN is None:
        try:
            with open(path, encoding="utf-8") as f:
                _TAKEN = json.load(f)
        except (OSError, ValueError):
            _TAKEN = {}
    if save:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(_TAKEN, f, indent=1, sort_keys=True)
    return _TAKEN


def sheet(icons):
    """Every icon side by side at three sizes on the game's dark grey, to look at."""
    names = [f for f in ICONS if f in icons]
    cell, pad, sizes = 160, 16, (128, 64, 32)
    width = pad + len(names) * (cell + pad)
    height = pad + sum(s + pad for s in sizes)
    back = (30, 30, 34, 255)
    rows = [[back] * width for _ in range(height)]
    for n, folder in enumerate(names):
        top = pad
        for s in sizes:
            small = resize(icons[folder], s, s)
            left = pad + n * (cell + pad) + (cell - s) // 2
            for j in range(s):
                for i in range(s):
                    r, g, b, a = small[j][i]
                    k = a / 255.0
                    rows[top + j][left + i] = (int(r * k + back[0] * (1 - k)), int(g * k + back[1] * (1 - k)),
                                              int(b * k + back[2] * (1 - k)), 255)
            top += s + pad
    return rows


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    if only and only not in ICONS and not os.path.isdir(os.path.join(ART, only)):
        sys.exit("no such addon: %s (there are: %s)" % (only, ", ".join(ICONS)))
    icons = {}
    for folder in ICONS:
        if only and folder != only:
            continue
        own = os.path.join(ART, folder, "icon.png")
        if os.path.exists(own):
            master = read_png(own)
            print("%s: your art/%s/icon.png" % (folder, folder))
        else:
            master = draw(folder)
            wrote = _write(os.path.join(ADDONS, folder, "Media", "icon.tga"), tga_bytes(resize(master, ICON, ICON)))
            print("%s: drawn%s" % (folder, "" if wrote else " (as it was)"))
        icons[folder] = master
        own = os.path.join(ART, folder, "logo.png")
        logo = read_png(own) if os.path.exists(own) else master
        _write(os.path.join(RELEASE, folder, "logo.png"), png_bytes(resize(logo, LOGO, LOGO)))
    take_in(only)
    if not only:
        _write(os.path.join(RELEASE, "art-preview.png"), png_bytes(sheet(icons)))
        print("to look at: " + os.path.join(RELEASE, "art-preview.png"))


if __name__ == "__main__":
    main()
