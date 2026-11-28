"""Roads: where the terrain is painted with a road.

    python roads.py 1                 a whole map: world/roads_1.bin, world/roads_1.png, world/roads_1.txt
    python roads.py 1 survey          also world/roads_1_textures.txt: every texture with how much of it is painted
                                      in long thin strips, to find road textures that the lists below miss

The terrain's texture files (each tile's _tex0 file) list the textures a tile is painted with (MDID: their file
numbers; this client keeps no names for them) and, a chunk at a time, up to four layers, each a texture and an
alpha map of 64 x 64 (MCLY, MCAL: the layers over the first are blended on in turn). A ground cell's share of a
texture is worked out from the layers' alpha averaged over the cell (an 8 x 8 square of the alpha map).

There are no names to go by, so the road textures were found by looking (2026-11-28): a picture of where each
texture is painted, over each zone, beside a picture of the texture itself.

  * ROAD: textures that are only ever roads, paths and paved town squares (cobbles, flagstones, packed dirt
    painted in long thin strips). A cell is road where its share of these is over HALF, in a patch of at least
    PATCH cells (the little loose patches some zones scatter beside a road are left out).
  * STRIP: dirt, gravel and sand that a zone paints its roads with but also lays in patches and along shores
    (Mulgore's road is the same dirt as its bare ground). Only long thin strips count: what is left of the
    texture's painting when everything WIDE cells wide or more is taken away (an opening), in pieces at least
    LONG cells across, sparse and not branching like a tree (a road, not lace or gullies), and not mostly beside
    water (a shore or a bank). Two gravels (186805, 186985) were left out after a look: their strips are the
    ragged edges of rock and scree.

Then a cell is road if either says so. world.load also counts as road every floor a building lays on the
ground (walls.py: a city's streets, a bridge's deck, a pier), and nav.Ground keeps a road mark only on ground
that can be walked or waded.

The output, world/roads_<id>.bin, is a zlib-packed pickle: {"map": id, "tiles": {(tx, ty): 16384 bytes, 1 a road}}.
"""
import collections
import os
import pickle
import struct
import sys
import time
import zlib

from casc import Storage
from terrain import _chunks, write_png
from world import NONE, STEEP, SWIM, WADE, WALK, load, map_files

# textures that are only roads (file numbers; see the words above)
ROAD = {
    186802, 186918, 186962, 186975, 187035, 187066, 187074, 187100, 188478, 188508, 188542, 188572, 188584, 188598,
    188610, 188665, 188727, 188763, 188796, 188818, 188854, 188911, 188964, 188982, 189026, 189030, 304640,
}
# dirt, gravel and sand that roads are painted with in some zones, and patches and shores in others
STRIP = {
    186779, 186865, 186901, 186922, 187115, 188653, 188699, 188814, 188820, 188843, 188856, 188938, 188946, 189000,
    189004, 189016,
}
HALF = 115                # of 255: a cell's share of a texture for it to count as painted with it
PATCH = 40                # cells: a patch of a road texture smaller than this is not a road
WIDE = 3                  # a blob 2 * WIDE + 1 cells wide (29 yards) or wider is not a road
LONG = 40                 # cells (167 yards): a strip at least this long across
SPARSE = 0.06             # a strip's cells at most this share of the square its length spans, and
BRANCHY = 7.0             # its cells at most this many times its length across (more: gullies branching like a tree)
SHORE = 0.4               # a strip with more than this share of its cells within NEAR cells of water is a shore
NEAR = 2


def _alpha(data, at, flags):
    """A layer's 64 x 64 alpha map (bytes), plain or packed in runs."""
    if not flags & 0x200:
        return data[at:at + 4096]
    out = bytearray()
    while len(out) < 4096:
        b = data[at]
        at += 1
        n = b & 0x7F
        if b & 0x80:
            out += bytes((data[at],)) * n
            at += 1
        else:
            out += data[at:at + n]
            at += n
    return bytes(out[:4096])


def _means(alpha):
    """A 64 x 64 alpha map averaged over each of the chunk's 8 x 8 cells: 64 shares of 0 to 1, row by row."""
    out = []
    for cr in range(8):
        for cc in range(8):
            total = 0
            for r in range(cr * 8, cr * 8 + 8):
                total += sum(alpha[r * 64 + cc * 8: r * 64 + cc * 8 + 8])
            out.append(total / (64 * 255.0))
    return out


def tile_shares(data, wanted, survey=None):
    """{texture: bytearray of 16384 shares (0 to 255)} for the textures in `wanted` painted on this tile.
    survey: a Counter, given every texture's cells painted over HALF (all textures, not only those wanted)."""
    mdid = ()
    for tag, at, size in _chunks(data):
        if tag == b"MDID":
            mdid = struct.unpack_from("<%dI" % (size // 4), data, at)
            break
    out = {}
    n = 0
    for tag, at, size in _chunks(data):
        if tag != b"MCNK":
            continue
        cy, cx = divmod(n, 16)
        n += 1
        layers, mcal = [], None
        for sub, sat, ssize in _chunks(data, at, at + size):
            if sub == b"MCLY":
                layers = [struct.unpack_from("<4I", data, sat + 16 * k) for k in range(ssize // 16)]
            elif sub == b"MCAL":
                mcal = sat
        textures = [mdid[l[0]] if l[0] < len(mdid) else None for l in layers]
        if not layers or (survey is None and not any(t in wanted for t in textures)):
            continue
        # each layer over the first is blended on in turn: a layer's share is its alpha times what the layers
        # above it leave
        alphas = [None]
        for tex, flags, off, _effect in layers[1:]:
            alphas.append(_means(_alpha(data, mcal + off, flags)) if flags & 0x100 and mcal is not None else [0.0] * 64)
        left = [1.0] * 64
        shares = [None] * len(layers)
        for k in range(len(layers) - 1, 0, -1):
            a = alphas[k]
            shares[k] = [a[i] * left[i] for i in range(64)]
            left = [left[i] * (1.0 - a[i]) for i in range(64)]
        shares[0] = left
        for k, tex in enumerate(textures):
            if tex is None:
                continue
            if survey is not None:
                survey[tex] += sum(1 for v in shares[k] if v * 255 > HALF)
            if tex not in wanted:
                continue
            got = out.get(tex)
            if got is None:
                got = out[tex] = bytearray(16384)
            s = shares[k]
            for i in range(64):
                v = int(s[i] * 255 + 0.5)
                if v:
                    at_cell = (cy * 8 + i // 8) * 128 + cx * 8 + i % 8
                    got[at_cell] = min(255, got[at_cell] + v)
    return out


# ---- shapes on the whole map, a row of cells a Python integer (a bit a cell, the lowest bit the west edge) -----
def _rows(tiles, texture, x0, y0, width, height):
    rows = [0] * height
    for (tx, ty), shares in tiles.items():
        got = shares.get(texture)
        if got is None:
            continue
        for r in range(128):
            bits = 0
            line = got[r * 128: r * 128 + 128]
            for c in range(128):
                if line[c] > HALF:
                    bits |= 1 << c
            if bits:
                rows[(ty - y0) * 128 + r] |= bits << ((tx - x0) * 128)
    return rows


def _erode(rows, r, full):
    across = []
    for m in rows:
        a = m
        for d in range(1, r + 1):
            a &= (m << d) & (m >> d)
        across.append(a & full)
    n = len(across)
    out = []
    for i in range(n):
        a = across[i]
        for d in range(1, r + 1):
            a &= (across[i - d] if i - d >= 0 else 0) & (across[i + d] if i + d < n else 0)
        out.append(a)
    return out


def _dilate(rows, r, full):
    across = []
    for m in rows:
        a = m
        for d in range(1, r + 1):
            a |= (m << d) | (m >> d)
        across.append(a & full)
    n = len(across)
    out = []
    for i in range(n):
        a = across[i]
        for d in range(1, r + 1):
            if i - d >= 0:
                a |= across[i - d]
            if i + d < n:
                a |= across[i + d]
        out.append(a)
    return out


def _cells(rows, x0, y0):
    """The cells (global gx, gy) of set bits."""
    out = set()
    for i, m in enumerate(rows):
        while m:
            low = m & -m
            out.add((x0 * 128 + low.bit_length() - 1, y0 * 128 + i))
            m ^= low
    return out


def _pieces(cells):
    """Groups of cells that touch (eight ways)."""
    left, out = set(cells), []
    while left:
        start = left.pop()
        piece, stack = [start], [start]
        while stack:
            x, y = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q in left:
                        left.discard(q)
                        piece.append(q)
                        stack.append(q)
        out.append(piece)
    return out


def find(store, map_id, survey=None):
    """{(tx, ty): bytearray of 16384 road marks}, and what was found (lines to read)."""
    wdt = store.read_fdid(map_files(store)[map_id])
    texfiles = {}
    for tag, at, size in _chunks(wdt):
        if tag == b"MAID":
            for i in range(4096):
                e = struct.unpack_from("<8I", wdt, at + i * 32)
                if e[0] and e[3]:
                    texfiles[(i % 64, i // 64)] = e[3]
    wanted = ROAD | STRIP
    tiles = {}
    for key, fdid in sorted(texfiles.items()):
        data = store.read_fdid(fdid)
        if data:
            shares = tile_shares(data, wanted, survey)
            if shares:
                tiles[key] = shares
    lines = ["map %d: %d tiles painted, %d of them with a road texture or a road's dirt" % (map_id, len(texfiles), len(tiles))]
    marks = {}
    if not tiles:
        return marks, lines
    x0, y0 = min(k[0] for k in tiles), min(k[1] for k in tiles)
    x1, y1 = max(k[0] for k in tiles), max(k[1] for k in tiles)
    width, height = (x1 - x0 + 1) * 128, (y1 - y0 + 1) * 128
    full = (1 << width) - 1
    terrain = load("world/map_%d.bin" % map_id, walls=False)["tiles"]

    def kind(gx, gy):
        t = terrain.get((gx >> 7, gy >> 7))
        return t[0][(gy & 127) * 128 + (gx & 127)] if t else NONE

    def wet(gx, gy):
        for dx in range(-NEAR, NEAR + 1):
            for dy in range(-NEAR, NEAR + 1):
                if kind(gx + dx, gy + dy) in (WADE, SWIM):
                    return True
        return False

    def mark(cells):
        for gx, gy in cells:
            got = marks.get((gx >> 7, gy >> 7))
            if got is None:
                got = marks[(gx >> 7, gy >> 7)] = bytearray(16384)
            got[(gy & 127) * 128 + (gx & 127)] = 1

    road_cells = set()
    for tex in sorted(ROAD):
        road_cells |= _cells(_rows(tiles, tex, x0, y0, width, height), x0, y0)
    kept = [p for p in _pieces(road_cells) if len(p) >= PATCH]
    mark(c for p in kept for c in p)
    lines.append("road textures: %d cells, %d in %d patches of %d or more kept" % (
        len(road_cells), sum(len(p) for p in kept), len(kept), PATCH))
    for tex in sorted(STRIP):
        rows = _rows(tiles, tex, x0, y0, width, height)
        if not any(rows):
            continue
        wide = _dilate(_erode(rows, WIDE, full), WIDE + 1, full)
        thin = [m & ~w for m, w in zip(rows, wide)]
        got, shores, scattered = [], 0, 0
        for piece in _pieces(_cells(thin, x0, y0)):
            if len(piece) < LONG:
                continue
            xs = [c[0] for c in piece]
            ys = [c[1] for c in piece]
            span = max(max(xs) - min(xs), max(ys) - min(ys)) + 1
            if span < LONG or len(piece) > SPARSE * span * span or len(piece) > BRANCHY * span:
                scattered += 1
                continue
            if sum(1 for c in piece if wet(*c)) > SHORE * len(piece):
                shores += 1
                continue
            got.append(piece)
        mark(c for p in got for c in p)
        lines.append("texture %d: %d strips kept (%d cells); %d shores and %d lace or blobs left out" % (
            tex, len(got), sum(len(p) for p in got), shores, scattered))
    lines.append("road cells in all: %d" % sum(sum(m) for m in marks.values()))
    return marks, lines


def picture(map_id, marks, path):
    """The roads in yellow over the ground, at half the resolution (a pixel is road if any of its four cells is)."""
    info = load("world/map_%d.bin" % map_id)
    tiles = info["tiles"]
    xs, ys = [k[0] for k in tiles], [k[1] for k in tiles]
    x0, y0 = min(xs), min(ys)
    per = 64
    width, height = (max(xs) - x0 + 1) * per, (max(ys) - y0 + 1) * per
    rows = [bytearray(b"\x0a\x0a\x14" * width) for _ in range(height)]
    colours = {WALK: (70, 90, 60), STEEP: (110, 60, 50), WADE: (60, 100, 130), SWIM: (30, 60, 110)}
    for (tx, ty), (cells, _h) in tiles.items():
        got = marks.get((tx, ty))
        px, py = (tx - x0) * per, (ty - y0) * per
        for r in range(per):
            row = rows[py + r]
            for c in range(per):
                i = (2 * r) * 128 + 2 * c
                colour = colours.get(cells[i], (10, 10, 20))
                if got and (got[i] or got[i + 1] or got[i + 128] or got[i + 129]):
                    colour = (255, 215, 40)
                row[(px + c) * 3: (px + c) * 3 + 3] = bytes(colour)
    write_png(path, width, height, [bytes(r) for r in rows])


def main(map_id, survey=False):
    started = time.time()
    store = Storage(r"G:/Games/World of Warcraft", "wowf")
    counts = collections.Counter() if survey else None
    marks, lines = find(store, map_id, counts)
    with open("world/roads_%d.bin" % map_id, "wb") as f:
        f.write(zlib.compress(pickle.dumps({"map": map_id, "tiles": {k: bytes(v) for k, v in marks.items()}}, protocol=4), 6))
    picture(map_id, marks, "world/roads_%d.png" % map_id)
    with open("world/roads_%d.txt" % map_id, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    if survey:
        with open("world/roads_%d_textures.txt" % map_id, "w", encoding="utf-8") as f:
            for tex, n in counts.most_common():
                f.write("%d %d cells%s\n" % (tex, n, " ROAD" if tex in ROAD else " STRIP" if tex in STRIP else ""))
    print("\n".join(lines))
    print("%.0fs" % (time.time() - started))


if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    main(int(sys.argv[1]), len(sys.argv) > 2 and sys.argv[2] == "survey")
