"""Terrain heights of a map out of the game's files, and how steep each cell is.

A map (world/maps/<name>) is 64 x 64 tiles of 533.33 yards; a tile is 16 x 16
chunks, a chunk 8 x 8 cells of 4.1667 yards with a height at every corner and
one in the middle of every cell. Tile (tx, ty): tx counts east, ty south.

World coordinates as the game has them: X grows north, Y grows west.
    world Y of a tile's west edge  = (32 - tx) * 533.33
    world X of a tile's north edge = (32 - ty) * 533.33
"""
import math
import struct
import zlib

TILE = 1600.0 / 3.0          # yards
CELL = TILE / 128.0          # 4.1667 yards
WDT = {"kalimdor": 782779, "azeroth": 775971}


def _chunks(data, start=0, end=None):
    pos, end = start, len(data) if end is None else end
    while pos + 8 <= end:
        tag = data[pos:pos + 4][::-1]
        size = struct.unpack_from("<I", data, pos + 4)[0]
        yield tag, pos + 8, size
        pos += 8 + size


def tiles_of(store, wdt_fdid):
    """{(tx, ty): FileDataID of the tile's terrain file}"""
    wdt = store.read_fdid(wdt_fdid)
    out = {}
    for tag, at, size in _chunks(wdt):
        if tag == b"MAID":
            per = size // 4096
            for ty in range(64):
                for tx in range(64):
                    fdid = struct.unpack_from("<I", wdt, at + (ty * 64 + tx) * per)[0]
                    if fdid:
                        out[(tx, ty)] = fdid
    return out


class Region:
    """Heights over a rectangle of tiles: corner heights and cell-middle heights."""

    def __init__(self, store, wdt_fdid, tx0, ty0, tx1, ty1):
        self.tx0, self.ty0 = tx0, ty0
        self.cols = (tx1 - tx0 + 1) * 128          # cells east-west
        self.rows = (ty1 - ty0 + 1) * 128          # cells north-south
        nan = float("nan")
        self.corner = [[nan] * (self.cols + 1) for _ in range(self.rows + 1)]
        self.middle = [[nan] * self.cols for _ in range(self.rows)]
        self.hole = [[False] * self.cols for _ in range(self.rows)]
        self.missing = []
        tiles = tiles_of(store, wdt_fdid)
        for ty in range(ty0, ty1 + 1):
            for tx in range(tx0, tx1 + 1):
                fdid = tiles.get((tx, ty))
                data = fdid and store.read_fdid(fdid)
                if not data:
                    self.missing.append((tx, ty))
                    continue
                self._tile(data, (tx - tx0) * 128, (ty - ty0) * 128)

    def _tile(self, data, col0, row0):
        for tag, at, size in _chunks(data):
            if tag != b"MCNK":
                continue
            flags, ix, iy = struct.unpack_from("<3I", data, at)
            base = struct.unpack_from("<f", data, at + 0x70)[0]       # the chunk's own height
            holes_low = struct.unpack_from("<H", data, at + 0x3C)[0]
            holes_high = data[at + 0x14: at + 0x1C] if flags & 0x10000 else None
            c0, r0 = col0 + ix * 8, row0 + iy * 8
            for sub, sat, ssize in _chunks(data, at + 128, at + size):
                if sub == b"MCVT":
                    h = struct.unpack_from("<145f", data, sat)
                    k = 0
                    for i in range(17):                 # 9 corners, 8 middles, 9 corners, ...
                        if i % 2 == 0:
                            row = self.corner[r0 + i // 2]
                            for j in range(9):
                                row[c0 + j] = base + h[k]
                                k += 1
                        else:
                            row = self.middle[r0 + i // 2]
                            for j in range(8):
                                row[c0 + j] = base + h[k]
                                k += 1
                    break
            for i in range(8):
                for j in range(8):
                    if holes_high is not None:
                        holed = (holes_high[i] >> j) & 1
                    else:
                        holed = (holes_low >> ((i // 2) * 4 + j // 2)) & 1
                    if holed:
                        self.hole[r0 + i][c0 + j] = True

    # ---- places ---------------------------------------------------------
    def cell_of(self, world_x, world_y):
        """(column, row) of the cell at a world place; fractions kept."""
        west = (32 - self.tx0) * TILE
        north = (32 - self.ty0) * TILE
        return (west - world_y) / CELL, (north - world_x) / CELL

    def slope(self, r, c):
        """The steepest of the cell's four faces, in degrees (None: no ground)."""
        m = self.middle[r][c]
        a, b = self.corner[r][c], self.corner[r][c + 1]
        d, e = self.corner[r + 1][c], self.corner[r + 1][c + 1]
        if m != m or a != a or b != b or d != d or e != e:
            return None
        half = CELL / 2.0
        worst = 0.0
        # each face: two corners a cell apart and the middle; its gradient
        for p, q in ((a, b), (b, e), (e, d), (d, a)):
            along = (q - p) / CELL
            across = (m - (p + q) / 2.0) / half
            g = math.hypot(along, across)
            if g > worst:
                worst = g
        return math.degrees(math.atan(worst))


def write_png(path, width, height, rgb_rows):
    """rgb_rows: `height` bytes objects of width * 3."""
    def chunk(tag, body):
        return struct.pack(">I", len(body)) + tag + body + struct.pack(">I", zlib.crc32(tag + body) & 0xFFFFFFFF)
    raw = b"".join(b"\0" + row for row in rgb_rows)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 6)))
        f.write(chunk(b"IEND", b""))
