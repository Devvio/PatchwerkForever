"""Proof step: Mulgore's slopes as a picture, with Thunder Bluff marked."""
import sys, time
sys.path.insert(0, ".")
from casc import Storage
from terrain import Region, WDT, CELL, write_png

WALK, CLIFF = 45.0, 55.0     # degrees: walkable below, a cliff above, unsure between
t = time.time()
store = Storage(r"G:/Games/World of Warcraft", "wowf")
reg = Region(store, WDT["kalimdor"], 29, 32, 34, 37)
print("tiles read in %.1fs; missing %s; encrypted chunks %d" % (time.time() - t, reg.missing, store.encrypted))

hmin = min(h for row in reg.corner for h in row if h == h)
hmax = max(h for row in reg.corner for h in row if h == h)
print("cells %d x %d, heights %.0f .. %.0f yd" % (cols := reg.cols, reg.rows, hmin, hmax) if False else "cells %d x %d, heights %.0f .. %.0f yd" % (reg.cols, reg.rows, hmin, hmax))

counts = {"walk": 0, "unsure": 0, "cliff": 0, "none": 0}
rows = []
for r in range(reg.rows):
    out = bytearray()
    for c in range(reg.cols):
        s = reg.slope(r, c)
        if s is None or reg.hole[r][c]:
            counts["none"] += 1
            out += bytes((20, 20, 60))
        else:
            shade = int(70 + 150 * (reg.middle[r][c] - hmin) / max(1.0, hmax - hmin))
            if s < WALK:
                counts["walk"] += 1
                out += bytes((shade // 3, shade, shade // 3))
            elif s < CLIFF:
                counts["unsure"] += 1
                out += bytes((230, 200, 40))
            else:
                counts["cliff"] += 1
                out += bytes((220, 40, 40))
    rows.append(out)
print(counts)

def mark(world_x, world_y, colour, size=3):
    c, r = reg.cell_of(world_x, world_y)
    c, r = int(c), int(r)
    for rr in range(r - size, r + size + 1):
        for cc in range(c - size, c + size + 1):
            if 0 <= rr < reg.rows and 0 <= cc < reg.cols and (rr in (r - size, r + size) or cc in (c - size, c + size)):
                rows[rr][cc * 3: cc * 3 + 3] = bytes(colour)
    return c, r

# the inn, from the hearthstone place Patchwerk kept (Route's yards -> world, by Kalimdor's map bounds)
LEFT, TOP = 17066.6, 12799.9
inn = (TOP - 14099.17, LEFT - 17027.17)
print("inn world", inn, "cell", mark(inn[0], inn[1], (255, 255, 255)))
write_png("mulgore-slopes.png", reg.cols, reg.rows, [bytes(r) for r in rows])

# a close-up of Thunder Bluff, 4 px a cell
c0, r0 = reg.cell_of(inn[0], inn[1])
c0, r0, half, zoom = int(c0), int(r0), 110, 4
big = []
for r in range(r0 - half, r0 + half):
    line = bytearray()
    for c in range(c0 - half, c0 + half):
        px = bytes(rows[r][c * 3: c * 3 + 3]) if 0 <= r < reg.rows and 0 <= c < reg.cols else b"\0\0\0"
        line += px * zoom
    big.extend([bytes(line)] * zoom)
write_png("thunderbluff-slopes.png", 2 * half * zoom, 2 * half * zoom, big)
print("pictures written in %.1fs" % (time.time() - t))
