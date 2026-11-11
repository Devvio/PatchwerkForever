"""Extract whole maps: what every 4.17-yard cell of ground is, and how high.

    python world.py 0 1 2991

For each map id: world/map_<id>.bin (the cells, for the later tools) and
world/map_<id>.png (a picture at a quarter of the resolution, for review).

A cell is one of:
    NONE     no ground (off the map, or a hole in the terrain: a cave mouth, a building's floor)
    WALK     ground a character can walk
    STEEP    steeper than a character can climb
    WADE     walkable ground under shallow water
    SWIM     water deep enough to swim in

The .bin is a zlib-packed pickle: {"tiles": {(tx, ty): (cells, heights)}, ...},
cells 16384 bytes a tile (128 rows of 128, north to south, west to east),
heights the same cells' ground height in tenths of a yard (array 'h').
"""
import array
import math
import os
import pickle
import struct
import sys
import time
import zlib

from casc import Storage
from db2 import Table, find_column
from terrain import TILE, CELL, _chunks, tiles_of, write_png

NONE, WALK, STEEP, WADE, SWIM = 0, 1, 2, 3, 4
MAX_SLOPE = 50.0          # degrees a character can still walk up
SWIM_DEPTH = 1.5          # yards of water before a character swims
MAP_TABLE = 1349477       # Map.db2

_TAN = math.tan(math.radians(MAX_SLOPE))


def map_files(store):
    """{map id: FileDataID of its world file}, from the game's own map table."""
    table = Table(store.read_fdid(MAP_TABLE))
    column = find_column(table, {0: 775971, 1: 782779})
    assert column, "the map table's world file column was not found"
    return {map_id: fields[column[0]] for map_id, fields in table.rows() if fields[column[0]]}


def _water(data, at):
    """Water surface height per cell of a tile, from its MH2O chunk: {(row, col): height}."""
    out = {}
    for chunk in range(256):
        inst_off, layers, _attr = struct.unpack_from("<III", data, at + chunk * 12)
        if not layers:
            continue
        cy, cx = divmod(chunk, 16)
        for k in range(layers):
            (_type, lvf, low, high, x0, y0, w, h, exists_off, vertex_off) = struct.unpack_from(
                "<HHffBBBBII", data, at + inst_off + k * 24)
            if w == 0 or h == 0 or w > 8 or h > 8:
                continue
            heights = None
            if vertex_off and lvf in (0, 1, 3):
                n = (w + 1) * (h + 1)
                vals = struct.unpack_from("<%df" % n, data, at + vertex_off)
                if all(low - 2.0 <= v <= high + 2.0 for v in vals):
                    heights = vals
            for i in range(h):
                for j in range(w):
                    if exists_off:
                        bit = i * w + j
                        if not (data[at + exists_off + bit // 8] >> (bit % 8)) & 1:
                            continue
                    if heights:
                        s = (heights[i * (w + 1) + j] + heights[i * (w + 1) + j + 1]
                             + heights[(i + 1) * (w + 1) + j] + heights[(i + 1) * (w + 1) + j + 1]) / 4.0
                    else:
                        s = high
                    key = (cy * 8 + y0 + i, cx * 8 + x0 + j)
                    if key not in out or s > out[key]:
                        out[key] = s
    return out


def tile_cells(data):
    """(cells, heights) of one terrain file: 16384 bytes, and an array of tenths of a yard."""
    nan = float("nan")
    corner = [[nan] * 129 for _ in range(129)]
    middle = [[nan] * 128 for _ in range(128)]
    holes = set()
    water = {}
    for tag, at, size in _chunks(data):
        if tag == b"MH2O":
            try:
                water = _water(data, at)
            except (struct.error, IndexError):
                water = {}
        elif tag == b"MCNK":
            flags, ix, iy = struct.unpack_from("<3I", data, at)
            base = struct.unpack_from("<f", data, at + 0x70)[0]
            holes_low = struct.unpack_from("<H", data, at + 0x3C)[0]
            holes_high = data[at + 0x14: at + 0x1C] if flags & 0x10000 else None
            c0, r0 = ix * 8, iy * 8
            for sub, sat, _ssize in _chunks(data, at + 128, at + size):
                if sub == b"MCVT":
                    h = struct.unpack_from("<145f", data, sat)
                    k = 0
                    for i in range(17):
                        if i % 2 == 0:
                            row = corner[r0 + i // 2]
                            for j in range(9):
                                row[c0 + j] = base + h[k]
                                k += 1
                        else:
                            row = middle[r0 + i // 2]
                            for j in range(8):
                                row[c0 + j] = base + h[k]
                                k += 1
                    break
            if holes_high is not None:
                for i in range(8):
                    if holes_high[i]:
                        for j in range(8):
                            if (holes_high[i] >> j) & 1:
                                holes.add((r0 + i, c0 + j))
            elif holes_low:
                for i in range(8):
                    for j in range(8):
                        if (holes_low >> ((i // 2) * 4 + j // 2)) & 1:
                            holes.add((r0 + i, c0 + j))
    cells = bytearray(16384)
    heights = array.array("h", bytes(32768))
    half = CELL / 2.0
    for r in range(128):
        top, bottom, mid = corner[r], corner[r + 1], middle[r]
        for c in range(128):
            m = mid[c]
            if m != m:
                continue
            a, b, d, e = top[c], top[c + 1], bottom[c], bottom[c + 1]
            if a != a or b != b or d != d or e != e:
                continue
            idx = r * 128 + c
            heights[idx] = max(-32000, min(32000, int(round(m * 10))))
            if (r, c) in holes:
                continue
            surface = water.get((r, c))
            if surface is not None and surface - m >= SWIM_DEPTH:
                cells[idx] = SWIM
                continue
            worst = 0.0
            for p, q in ((a, b), (b, e), (e, d), (d, a)):
                g = math.hypot((q - p) / CELL, (m - (p + q) / 2.0) / half)
                if g > worst:
                    worst = g
            if worst >= _TAN:
                cells[idx] = STEEP
            elif surface is not None and surface > m:
                cells[idx] = WADE
            else:
                cells[idx] = WALK
    return bytes(cells), heights


def extract(store, map_id, wdt_fdid, out_dir):
    started = time.time()
    tiles = tiles_of(store, wdt_fdid)
    done, failed = {}, []
    for (tx, ty), fdid in sorted(tiles.items()):
        data = store.read_fdid(fdid)
        if not data:
            failed.append((tx, ty))
            continue
        try:
            done[(tx, ty)] = tile_cells(data)
        except (struct.error, IndexError) as err:
            failed.append((tx, ty, str(err)))
    info = {"map": map_id, "cell": CELL, "tile": TILE, "tiles": done}
    with open(os.path.join(out_dir, "map_%d.bin" % map_id), "wb") as f:
        f.write(zlib.compress(pickle.dumps(info, protocol=4), 6))
    counts = [0] * 5
    for cells, _ in done.values():
        for k in range(5):
            counts[k] += cells.count(k)
    picture(done, os.path.join(out_dir, "map_%d.png" % map_id))
    print("map %d: %d tiles in %.0fs; failed %s" % (map_id, len(done), time.time() - started, failed or "none"))
    total = max(1, sum(counts))
    print("   none %.1f%%  walk %.1f%%  steep %.1f%%  wade %.1f%%  swim %.1f%%" % tuple(100.0 * c / total for c in counts))
    return done


def load(path):
    with open(path, "rb") as f:
        return pickle.loads(zlib.decompress(f.read()))


_COLOURS = {NONE: (10, 10, 20), STEEP: (205, 45, 45), WADE: (90, 170, 215), SWIM: (30, 80, 170)}


def picture(tiles, path, block=4):
    """A quarter-resolution picture: each pixel the commonest kind of its 4 x 4 cells (steep wins at 3 or more)."""
    if not tiles:
        return
    rows, _x0, _y0, _per = picture_rows(tiles, block)
    write_png(path, len(rows[0]) // 3, len(rows), [bytes(r) for r in rows])


def picture_rows(tiles, block=4):
    """The picture's rows to draw on: (rows of bytearray, first tile x, first tile y, pixels a tile)."""
    xs = [k[0] for k in tiles]
    ys = [k[1] for k in tiles]
    x0, y0 = min(xs), min(ys)
    per = 128 // block
    width, height = (max(xs) - x0 + 1) * per, (max(ys) - y0 + 1) * per
    lows = [min(h) for _, h in tiles.values()]
    highs = [max(h) for _, h in tiles.values()]
    low, span = min(lows), max(1, max(highs) - min(lows))
    rows = [bytearray(bytes(_COLOURS[NONE]) * width) for _ in range(height)]
    for (tx, ty), (cells, heights) in tiles.items():
        px, py = (tx - x0) * per, (ty - y0) * per
        for br in range(per):
            row = rows[py + br]
            for bc in range(per):
                kinds = [0] * 5
                total = 0
                for r in range(br * block, br * block + block):
                    base = r * 128 + bc * block
                    for c in range(block):
                        kinds[cells[base + c]] += 1
                        total += heights[base + c]
                if kinds[STEEP] >= 3:
                    colour = _COLOURS[STEEP]
                else:
                    kind = max(range(5), key=kinds.__getitem__)
                    if kind == WALK:
                        shade = 60 + int(150 * (total / (block * block) - low) / span)
                        colour = (shade // 3, shade, shade // 3)
                    else:
                        colour = _COLOURS[kind]
                at = (px + bc) * 3
                row[at: at + 3] = bytes(colour)
    return rows, x0, y0, per


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.join(here, "world")
    os.makedirs(out_dir, exist_ok=True)
    store = Storage(r"G:/Games/World of Warcraft", "wowf")
    files = map_files(store)
    for arg in sys.argv[1:]:
        map_id = int(arg)
        if map_id not in files:
            print("map %d: not in the map table (or encrypted)" % map_id)
            continue
        extract(store, map_id, files[map_id], out_dir)
    print("encrypted chunks skipped:", store.encrypted)
