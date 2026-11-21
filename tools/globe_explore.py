"""The land you have not discovered, as paper to lay over it (GLOBE-BLUEPRINT.md, G10).

    python globe_explore.py     writes Art/Covers/cover_<map>.blp, Covers.lua and world/look_covers_<id>.png

The game's world map leaves a place blank until you have been there: each zone's map is a plain picture
with pieces laid over it (WorldMapOverlay), one for each place or few places, and the game tells an addon
which pieces of a zone's map you have (C_MapExplorationInfo.GetExploredMapTextures: each by where it lies
on the map's picture). The globe has no such pieces: its land is our own picture. So this works out, for
every piece of every zone's map, which of our 33-yard terrain chunks it stands for, and makes a soft
paper-coloured picture of just those chunks. The globe lays that over the land until the game says you
have the piece.

Which chunks a piece stands for:
    1. those whose own area (or an area above it) is one the piece is for;
    2. of the rest of the zone's chunks, those inside the piece's hit rectangle on the map (the smallest
       such piece, where several overlap);
    3. of what is left, those nearest a piece's rectangle.
So every chunk of a zone with pieces belongs to one, and a zone you have never entered is wholly paper.
A zone whose map has no pieces (a city) is never covered.

Each zone's pictures share one file (cells side by side): one for the whole zone at half the detail, drawn
while you have none of it and the globe is far out, and one for each piece. A picture's colour is the
paper's everywhere; only how much of it shows differs, down to nothing over water, so the coast stays.

Read from the game (numbers only): WorldMapOverlay, UiMapXMapArt, UiMapAssignment, AreaTable.
"""
import collections
import os
import struct

import numpy as np
from PIL import Image

from blp import write_blp
from casc import Storage
from db2 import Table
from globe_art import ADDON, WORLD, area_parents, continent_areas, continent_base

MAPS = (0, 1, 2991)
OVERLAYS, MAP_ART, ASSIGNED = 1134579, 1957217, 1957219
LAYER = (1002.0, 668.0)       # a zone map's picture, in its own pixels (what a piece's place is counted in)
PAPER = (214, 196, 152)       # the colour of blank paper
PAD = 3                       # chunks kept clear round a picture's own, for its soft edge
GUTTER = 2                    # pixels between two pictures in a file
SIDES = (64, 128, 256, 512, 1024)


def floats(values):
    return [struct.unpack("<f", struct.pack("<I", v))[0] for v in values]


def tables(store):
    """(pieces by map art, the zone map of each art, each zone map's continent, area and rectangle)."""
    pieces = collections.defaultdict(list)
    for rid, f in Table(store.read_fdid(OVERLAYS)).rows():
        areas = [a for a in f[12] if a]
        if areas and f[2] > 0 and f[3] > 0:
            pieces[f[1]].append({"id": rid, "at": (f[4], f[5]), "size": (f[2], f[3]),
                                 "hit": (f[8], f[6], f[9], f[7]), "areas": areas})      # hit: left, top, right, bottom
    art = Table(store.read_fdid(MAP_ART))
    owner = art.relations()
    art_map = {f[1]: owner[rid] for rid, f in art.rows() if rid in owner}
    zones = {}
    for _rid, f in Table(store.read_fdid(ASSIGNED)).rows():
        x0, y0, _z0, x1, y1, _z1 = floats(f[2])
        if f[7] and x1 > x0 and y1 > y0:
            zones[f[4]] = {"map": f[6], "area": f[7], "x": (x0, x1), "y": (y0, y1)}
    return pieces, art_map, zones


def soften(mask):
    """A mask grown by a chunk and blurred, so two pictures side by side leave no seam between them."""
    m = mask.astype(np.float32)
    g = m.copy()
    g[1:] = np.maximum(g[1:], m[:-1])
    g[:-1] = np.maximum(g[:-1], m[1:])
    g[:, 1:] = np.maximum(g[:, 1:], m[:, :-1])
    g[:, :-1] = np.maximum(g[:, :-1], m[:, 1:])
    for _ in range(2):
        p = np.pad(g, 1, mode="edge")
        g = (p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:] + 4 * g) / 8
    return g


def pack(cells):
    """Lay the cells (each a 2-D array) in the smallest file they fit: (width, height, [(x, y)])."""
    order = sorted(range(len(cells)), key=lambda i: -cells[i].shape[0])
    best = None
    for side in SIDES:
        if max(c.shape[1] for c in cells) + GUTTER > side:
            continue
        x = y = shelf = 0
        at = [None] * len(cells)
        for i in order:
            h, w = cells[i].shape
            if x + w + GUTTER > side:
                x, y, shelf = 0, y + shelf + GUTTER, 0
            at[i] = (x, y)
            x, shelf = x + w + GUTTER, max(shelf, h)
        used = y + shelf
        height = next((s for s in (16, 32) + SIDES if s >= used), None)
        if height and (best is None or side * height < best[0] * best[1]):
            best = (side, height, at)
    assert best, "a zone's pictures do not fit a file"
    return best


def zone_pieces(zone, pieces, area, water, parents):
    """For one zone map: which of its chunks each piece stands for. Returns (the chunks' box: row0, row1,
    column0, column1; a grid over the box: the piece's index + 1 for each chunk of the zone, 0 elsewhere)."""
    tile = 1600 / 3
    edge = 32 * tile
    chunk = tile / 16
    # (the zone's rectangle in chunks: columns from world y, rows from world x)
    c0, c1 = int((edge - zone["y"][1]) / chunk), int(np.ceil((edge - zone["y"][0]) / chunk))
    r0, r1 = int((edge - zone["x"][1]) / chunk), int(np.ceil((edge - zone["x"][0]) / chunk))
    c0, r0, c1, r1 = max(0, c0), max(0, r0), min(1024, c1), min(1024, r1)
    sub = area[r0:r1, c0:c1]
    wanted = {a: i for i, p in enumerate(pieces) for a in p["areas"]}

    def above(a):
        """(is the area in this zone, the piece its ancestry names or None)"""
        named, seen = None, 0
        while a and seen < 12:
            if named is None and a in wanted:
                named = wanted[a]
            if a == zone["area"]:
                return True, named
            a, seen = parents.get(a, 0), seen + 1
        return False, None

    mine = np.zeros(sub.shape, bool)
    owner = np.full(sub.shape, -1, np.int32)
    for a in np.unique(sub):
        inside, named = above(int(a))
        if inside:
            here = sub == a
            mine |= here
            if named is not None:
                owner[here] = named
    if not mine.any():
        return None
    # the rest by where they lie on the zone's map (pixels of its picture)
    rows, cols = np.nonzero(mine & (owner < 0))
    if len(rows):
        wy = edge - (cols + c0 + 0.5) * chunk
        wx = edge - (rows + r0 + 0.5) * chunk
        px = (zone["y"][1] - wy) / (zone["y"][1] - zone["y"][0]) * LAYER[0]
        py = (zone["x"][1] - wx) / (zone["x"][1] - zone["x"][0]) * LAYER[1]
        best = np.full(len(rows), -1, np.int32)
        size = np.full(len(rows), np.inf)
        near = np.full(len(rows), np.inf)
        nearest = np.zeros(len(rows), np.int32)
        for i, p in enumerate(pieces):
            left, top, right, bottom = p["hit"]
            if right <= left or bottom <= top:              # (no hit rectangle of its own: the picture's)
                left, top = p["at"]
                right, bottom = left + p["size"][0], top + p["size"][1]
            inside = (px >= left) & (px <= right) & (py >= top) & (py <= bottom)
            a = (right - left) * (bottom - top)
            take = inside & (a < size)
            best[take], size[take] = i, a
            d = np.hypot(px - (left + right) / 2, py - (top + bottom) / 2)
            closer = d < near
            near[closer], nearest[closer] = d[closer], i
        owner[rows, cols] = np.where(best >= 0, best, nearest)
    grid = np.where(mine, owner + 1, 0)
    return (r0, r1, c0, c1), grid


def main():
    store = Storage(r"G:/Games/World of Warcraft", "wowf")
    parents = area_parents(store)
    pieces, art_map, zones = tables(store)
    out_dir = os.path.join(ADDON, "Art", "Covers")
    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        os.remove(os.path.join(out_dir, old))
    lua = ["-- Thread (Globe): the paper laid over land you have not discovered. Written by tools/globe_explore.py",
           "-- (python globe_explore.py), from the game's own list of the pieces of each zone's map.",
           "local _, ns = ...", "",
           "-- By the game's number for a zone map's picture (C_Map.GetMapArtID):",
           "--   ui, map     the zone's map, and its continent's map number",
           "--   file, w, h  the file its pictures share, and its size (pixels)",
           "--   whole       the picture of the whole zone: { x, y, w, h (in the file), column, row, columns, rows",
           "--               (the chunks it lies over: 16 to a terrain tile) }",
           "--   pieces      by where a piece lies on the zone's map (x * 4096 + y): the same eight figures",
           "ns.COVERS = {"]
    total, files, made = 0, 0, 0
    looks = {}
    for art in sorted(pieces, key=lambda a: art_map.get(a, 0)):
        ui = art_map.get(art)
        zone = zones.get(ui)
        if not zone or zone["map"] not in MAPS:
            continue
        m = zone["map"]
        base = continent_base(store, m, parents)
        area = continent_areas(store, m)
        found = zone_pieces(zone, pieces[art], area, base["water"], parents)
        if not found:
            print("map %d (art %d): no chunk of ours is in this zone, left out" % (ui, art))
            continue
        (r0, r1, c0, c1), grid = found
        land = np.clip((1 - base["water"][r0:r1, c0:c1]) * 1.5, 0, 1)
        cells, where, keys = [], [], []

        def cell(mask, half=False):
            rows, cols = np.nonzero(mask)
            a0, a1 = max(0, rows.min() - PAD), min(mask.shape[0], rows.max() + 1 + PAD)
            b0, b1 = max(0, cols.min() - PAD), min(mask.shape[1], cols.max() + 1 + PAD)
            if half:                                        # (an even number of chunks each way)
                a1 += (a1 - a0) % 2
                b1 += (b1 - b0) % 2
                a1, b1 = min(a1, mask.shape[0] - (mask.shape[0] - a0) % 2), min(b1, mask.shape[1] - (mask.shape[1] - b0) % 2)
            show = soften(mask[a0:a1, b0:b1]) * land[a0:a1, b0:b1]
            if half:
                h, w = show.shape
                show = show.reshape(h // 2, 2, w // 2, 2).mean(axis=(1, 3))
            # (a clear edge all round, so a picture stretched over its chunks ends in nothing)
            show[0], show[-1], show[:, 0], show[:, -1] = 0, 0, 0, 0
            cells.append(show)
            where.append((b0 + c0, a0 + r0, b1 - b0, a1 - a0))

        cell(grid > 0, half=True)
        keys.append(None)
        for i, p in enumerate(pieces[art]):
            if (grid == i + 1).any():
                cell(grid == i + 1)
                keys.append(p["at"][0] * 4096 + p["at"][1])
        if len(cells) < 2:
            continue
        w, h, at = pack(cells)
        rgba = np.zeros((h, w, 4), np.uint8)
        rgba[..., 0], rgba[..., 1], rgba[..., 2] = PAPER
        for show, (x, y) in zip(cells, at):
            rgba[y:y + show.shape[0], x:x + show.shape[1], 3] = np.clip(show * 255, 0, 255).astype(np.uint8)
        name = "cover_%d" % ui
        total += write_blp(os.path.join(out_dir, name + ".blp"), rgba)
        files, made = files + 1, made + len(cells) - 1

        def eight(i):
            return "{ %d, %d, %d, %d, %d, %d, %d, %d }" % ((at[i][0], at[i][1], cells[i].shape[1], cells[i].shape[0]) + where[i])

        lua.append("\t[%d] = { ui = %d, map = %d, file = 'Covers\\\\%s', w = %d, h = %d, whole = %s, pieces = {" % (
            art, ui, m, name, w, h, eight(0)))
        row = []
        for i in range(1, len(cells)):
            row.append("[%d] = %s," % (keys[i], eight(i)))
            if len(row) == 3 or i == len(cells) - 1:
                lua.append("\t\t" + " ".join(row))
                row = []
        lua.append("\t} },")
        look = looks.setdefault(m, np.zeros((1024, 1024, 3), np.uint8))
        colours = np.random.default_rng(ui).integers(60, 255, (len(pieces[art]) + 1, 3))
        colours[0] = 0
        patch = look[r0:r1, c0:c1]
        patch[grid > 0] = colours[grid[grid > 0]]
        print("map %d (art %d): %d pieces of %d have chunks; file %d x %d" % (ui, art, len(cells) - 1, len(pieces[art]), w, h))
    lua.append("}")
    with open(os.path.join(ADDON, "Covers.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lua) + "\n")
    for m, look in looks.items():
        Image.fromarray(look).save(os.path.join(WORLD, "look_covers_%d.png" % m))
    print("written %d files (%d pieces, %.1f MB), Covers.lua, world/look_covers_<map>.png" % (files, made, total / 1e6))


if __name__ == "__main__":
    main()
