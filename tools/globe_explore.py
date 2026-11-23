"""The land you have not discovered, as fog to lay over it (GLOBE-BLUEPRINT.md, G10).

    python globe_explore.py     writes Art/Covers/cover_<map>.blp, Covers.lua and world/look_covers_<id>.png

The game's world map leaves a place blank until you have been there: each zone's map is a plain picture
with pieces laid over it (WorldMapOverlay), one for each place or few places, and the game tells an addon
which pieces of a zone's map you have (C_MapExplorationInfo.GetExploredMapTextures: each by where it lies
on the map's picture). The globe has no such pieces: its land is our own picture. So this works out, for
every piece of every zone's map, which of our 33-yard terrain chunks it stands for, and makes a picture
of fog over just those chunks. The globe lays that over the land until the game says you have the piece.

The fog is one field of billows over the whole continent (mist), so it runs on unbroken from piece to
piece and zone to zone; a picture is its part of that, whole over the piece and thinning out to mist
for a few chunks past its edge (it was blank paper with a clean edge until 2026-11-22; the user asked
for fog). A picture has FINE pixels a chunk. The game knows a place's piece only by the chunk, so the
edge between two pieces is a staircase of chunk corners: it is rounded first. The coast is taken from
the land of the detail pictures, and the fog thins out over the water there, so the coast stays.

Which chunks a piece stands for:
    1. those whose own area (or an area above it) is one the piece is for;
    2. of the rest of the zone's chunks, those inside the piece's hit rectangle on the map (the smallest
       such piece, where several overlap);
    3. of what is left, those nearest a piece's rectangle.
So every chunk of a zone with pieces belongs to one, and a zone you have never entered is wholly fog.
A zone whose map has no pieces (a city) is never covered.

Each zone's pictures share one file (cells side by side): the fog over the whole zone, drawn while you
have none of it; the zone's flat shape in one colour, paper's (the level wash tints it, Wash.lua); and
the fog over each piece.

Zoomed in to the ground, the globe keeps its painted map over land you have not discovered, where it
would show the minimap's pictures. For that Covers.lua also says whose piece the land is at each
corner of a quarter of a terrain tile (POINTS to a tile; `points`): a ground picture can only fade
evenly between such corners, and a quarter tile (133 yards) is about as wide as the fog's own mist.

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
from globe_art import ADDON, PER, WORLD, area_parents, continent_areas, continent_base, continent_cells, soft

MAPS = (0, 1, 2991)
OVERLAYS, MAP_ART, ASSIGNED = 1134579, 1957217, 1957219
LAYER = (1002.0, 668.0)       # a zone map's picture, in its own pixels (what a piece's place is counted in)
PAPER = (214, 196, 152)       # the colour of blank paper (the flat shape of a zone, which the level wash tints)
FOG_LIGHT = (236, 238, 241)   # the fog: the tops of its billows,
FOG_DEEP = (178, 185, 196)    # and the hollows between them
BILLOWS = ((15, 1.0), (7, 0.55), (3.2, 0.28))     # the fog's billows: (how wide, chunks; how strong)
RELIEF = 0.8                  # how strongly a billow is lit from the upper left
MIST = 2.4                    # past a piece's edge (and GROW, as the paper was) the fog thins out to mist over
                              # about twice this (chunks), further where a billow is thick, sooner where thin
SHORE = 0.5                   # at the shore it thins out over the water, as unevenly
FINE = 1                      # pixels a chunk in a picture (33 yards a pixel: fog is soft, and wants no more)
EDGE = 0.55                   # how far an edge between two pieces is rounded (chunks; a zone's is in globe_art.py)
GROW = 0.6                    # a piece's paper reaches this far past its edge (chunks), so two leave no seam
FADE = 0.4                    # and fades to nothing over about three times this (chunks)
PAD = 6                       # chunks kept clear round a picture's own, for the mist at its edge
GUTTER = 2                    # pixels between two pictures in a file
POINTS = 4                    # to a terrain tile's side: the corners at which the ground is told whose piece it is
SIDES = (64, 128, 256, 512, 1024, 2048)


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


def rounded(grid):
    """A zone's pieces (the piece's index + 1 a chunk, 0 outside the zone) at FINE pixels a chunk, the
    staircases of chunk corners rounded: the zone's own edge first, then within it each pixel goes to the
    piece that is strongest there once each is blurred a little."""
    fine = np.kron(grid, np.ones((FINE, FINE), grid.dtype))
    inside = soft((fine > 0).astype(np.float32), EDGE * FINE) > 0.5
    out = np.zeros(fine.shape, grid.dtype)
    best = np.zeros(fine.shape, np.float32)
    for i in np.unique(grid):
        if i:
            strength = soft((fine == i).astype(np.float32), EDGE * FINE)
            win = strength > best
            out[win], best[win] = i, strength[win]
    out[~inside] = 0
    return out


def paper(mask):
    """How much of the paper shows over a piece (FINE pixels a chunk): all of it over the piece and to GROW
    chunks past its edge, so two pieces side by side leave no seam between them, then fading to nothing."""
    grown = soft(mask.astype(np.float32), GROW * FINE) > 0.16           # (0.16: one blur's width past the edge)
    return soft(grown.astype(np.float32), FADE * FINE)


def blur(a, sigma):
    """A Gaussian blur of a square array of any values (soft() keeps eight bits only), wrapping round."""
    fy = np.fft.fftfreq(a.shape[0])[:, None]
    fx = np.fft.rfftfreq(a.shape[1])[None, :]
    return np.fft.irfft2(np.fft.rfft2(a) * np.exp(-2 * (np.pi * sigma) ** 2 * (fx * fx + fy * fy)), s=a.shape).astype(np.float32)


def mist(map_id):
    """The fog over a whole continent, FINE pixels a chunk, so that it runs on unbroken from one piece to the
    next and from zone to zone: (its colour a pixel, 0 to 255; how thick it is there, 0 to 1, for its edges)."""
    side = 1024 * FINE
    rng = np.random.default_rng(7700 + map_id)
    n = np.zeros((side, side), np.float32)
    for wide, strong in BILLOWS:
        layer = blur(rng.random((side, side), dtype=np.float32), wide * FINE / 2.5)
        n += strong * (layer - layer.mean()) / layer.std()
    n /= n.std()
    thick = 0.5 + 0.5 * np.tanh(n * 0.9)
    # (lit from the upper left: a billow's near side bright, its far side in its own shade)
    lit = thick - np.roll(np.roll(thick, -FINE, 0), -FINE, 1)
    value = np.clip(0.52 + (thick - 0.5) * 0.5 - lit * RELIEF, 0, 1)
    value = value * value * (3 - 2 * value)
    colour = np.zeros((side, side, 3), np.float32)
    for k in range(3):
        colour[..., k] = FOG_DEEP[k] + (FOG_LIGHT[k] - FOG_DEEP[k]) * value
    return colour.astype(np.uint8), thick


def step(a, low, high):
    t = np.clip((a - low) / (high - low), 0, 1)
    return t * t * (3 - 2 * t)


def fog(mask, thick, land):
    """How much of the fog shows over a piece (FINE pixels a chunk): all of it over the piece and to GROW chunks
    past its edge (two pieces side by side leave no seam, whatever the billows), then thinning out to mist,
    the thick of a billow reaching further than the thin. Over the water it thins out at the shore, so the
    coast stays."""
    grown = soft(mask.astype(np.float32), GROW * FINE) > 0.16
    # (1 over the piece and to its grown edge, falling away outside it)
    near = np.clip(soft(grown.astype(np.float32), MIST * FINE) * 2, 0, 1)
    show = step(near * (0.55 + 0.9 * thick), 0.1, 0.55)
    return show * step(soft(land, 0.8 * FINE) + SHORE * (thick - 0.5), 0.08, 0.7)


def fine_land(map_id, base):
    """How dry a continent is, FINE pixels a chunk (0 to 1): the land of the detail pictures where they have
    any (so the paper ends at the painted shore), the chunks' own elsewhere; softened by a pixel."""
    out = np.kron(np.clip((1 - base["water"]) * 1.5, 0, 1), np.ones((FINE, FINE), np.float32))
    land, _heights, _zone, has, (tx0, ty0, _bx0, _bx1, _by0, _by1) = continent_cells(map_id, base)
    n = PER // 16 // FINE
    h, w = land.shape
    dry = land.astype(np.float32).reshape(h // n, n, w // n, n).mean(axis=(1, 3))
    side = 16 * FINE                                        # (a terrain tile, in these pixels)
    for ty, tx in zip(*np.nonzero(has)):
        y, x = (ty - ty0) * side, (tx - tx0) * side
        out[ty * side:(ty + 1) * side, tx * side:(tx + 1) * side] = dry[y:y + side, x:x + side]
    return np.clip(soft(out, 0.6) * 1.5, 0, 1)


def points(owner):
    """Whose piece the land is at each corner of a quarter tile: of the chunks round the corner (as many
    each way as lie between two corners), the owner most of them have. owner: a continent's chunks, 0 none."""
    per = 16 // POINTS
    half = per // 2
    across = 64 * POINTS + 1
    padded = np.pad(owner, half)
    stack = np.stack([padded[dy::per, dx::per][:across, :across] for dy in range(per) for dx in range(per)])
    counts = np.stack([(stack == one).sum(axis=0) for one in stack])
    return np.take_along_axis(stack, counts.argmax(axis=0)[None], 0)[0]


def runs(row):
    """A row as 'count,value,count,value,...' from its first column to its last value that is not 0."""
    filled = np.nonzero(row)[0]
    if not len(filled):
        return ""
    row = row[:filled[-1] + 1]
    starts = np.concatenate(([0], np.nonzero(np.diff(row))[0] + 1, [len(row)]))
    return ",".join("%d,%d" % (b - a, row[a]) for a, b in zip(starts[:-1], starts[1:]))


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
    lua = ["-- Globe (Thread): the fog laid over land you have not discovered. Written by tools/globe_explore.py",
           "-- (python globe_explore.py), from the game's own list of the pieces of each zone's map.",
           "local _, ns = ...", "",
           "-- By the game's number for a zone map's picture (C_Map.GetMapArtID):",
           "--   ui, map     the zone's map, and its continent's map number",
           "--   file, w, h  the file its pictures share, and its size (pixels)",
           "--   whole       the fog over the whole zone: { x, y, w, h (in the file), column, row, columns, rows",
           "--               (the chunks it lies over: 16 to a terrain tile) }",
           "--   shape       the zone's flat shape in one colour, smaller (the level wash tints it): the same eight figures",
           "--   pieces      by where a piece lies on the zone's map (x * 4096 + y): the same eight figures",
           "ns.COVERS = {"]
    total, files, made = 0, 0, 0
    looks, lands, mists = {}, {}, {}
    owned, owners = {}, {}        # by continent: the piece each chunk is of (a count into owners, 0 none)
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
        # (room all round the zone's own rectangle, for the paper's soft edge)
        room = (min(PAD, r0), min(PAD, 1024 - r1), min(PAD, c0), min(PAD, 1024 - c1))
        grid = np.pad(grid, (room[:2], room[2:]))
        r0, r1, c0, c1 = r0 - room[0], r1 + room[1], c0 - room[2], c1 + room[3]
        fine = rounded(grid)
        if m not in lands:
            lands[m] = fine_land(m, base)
            mists[m] = mist(m)
        here = (slice(r0 * FINE, r1 * FINE), slice(c0 * FINE, c1 * FINE))
        land, colour, thick = lands[m][here], mists[m][0][here], mists[m][1][here]
        cells, tones, where, keys = [], [], [], []

        def cell(mask, shape=False):
            # (cut on whole chunks: a picture's place on the globe is counted in them)
            rows, cols = np.nonzero(mask)
            a0, a1 = max(0, rows.min() // FINE - PAD), min(grid.shape[0], rows.max() // FINE + 1 + PAD)
            b0, b1 = max(0, cols.min() // FINE - PAD), min(grid.shape[1], cols.max() // FINE + 1 + PAD)
            cut = (slice(a0 * FINE, a1 * FINE), slice(b0 * FINE, b1 * FINE))
            if shape:                                       # (the zone's flat shape, a pixel a chunk, in paper's colour)
                show = paper(mask[cut]) * land[cut]
                h, w = show.shape
                show = show.reshape(h // FINE, FINE, w // FINE, FINE).mean(axis=(1, 3))
                tone = np.zeros(show.shape + (3,), np.uint8)
                tone[...] = PAPER
            else:
                show = fog(mask[cut], thick[cut], land[cut])
                tone = colour[cut]
            # (a clear edge all round, so a picture stretched over its chunks ends in nothing)
            show[0], show[-1], show[:, 0], show[:, -1] = 0, 0, 0, 0
            cells.append(show)
            tones.append(tone)
            where.append((b0 + c0, a0 + r0, b1 - b0, a1 - a0))

        cell(fine > 0)
        keys.append(None)
        cell(fine > 0, shape=True)
        keys.append(None)
        mine = []
        for i, p in enumerate(pieces[art]):
            if (fine == i + 1).any():
                cell(fine == i + 1)
                keys.append(p["at"][0] * 4096 + p["at"][1])
                mine.append((i, keys[-1]))
        if len(cells) < 3:
            continue
        whose, named = owned.setdefault(m, np.zeros((1024, 1024), np.int32)), owners.setdefault(m, [])
        for i, key in mine:
            named.append((art, key))
            whose[r0:r1, c0:c1][grid == i + 1] = len(named)
        w, h, at = pack(cells)
        rgba = np.zeros((h, w, 4), np.uint8)
        rgba[..., :3] = np.array(FOG_LIGHT) // 2 + np.array(FOG_DEEP) // 2
        for show, tone, (x, y) in zip(cells, tones, at):
            rgba[y:y + show.shape[0], x:x + show.shape[1], :3] = tone
            rgba[y:y + show.shape[0], x:x + show.shape[1], 3] = np.clip(show * 255, 0, 255).astype(np.uint8)
        name = "cover_%d" % ui
        total += write_blp(os.path.join(out_dir, name + ".blp"), rgba)
        files, made = files + 1, made + len(cells) - 2

        def eight(i):
            return "{ %d, %d, %d, %d, %d, %d, %d, %d }" % ((at[i][0], at[i][1], cells[i].shape[1], cells[i].shape[0]) + where[i])

        lua.append("\t[%d] = { ui = %d, map = %d, file = 'Covers\\\\%s', w = %d, h = %d, whole = %s, shape = %s, pieces = {" % (
            art, ui, m, name, w, h, eight(0), eight(1)))
        row = []
        for i in range(2, len(cells)):
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
        print("map %d (art %d): %d pieces of %d have chunks; file %d x %d" % (ui, art, len(cells) - 2, len(pieces[art]), w, h))
    lua.append("}")
    lua += ["",
            "-- By continent (the game's map number), whose piece the land is at each corner of a quarter of a",
            "-- terrain tile (the ground is not drawn over land you have not discovered):",
            "--   per     such corners to a tile's side",
            "--   owners  the pieces, as picture, piece, picture, piece, ... (the keys of ns.COVERS and of its pieces)",
            "--   row0    the row of corners that rows begins at (0 is the continent's upper edge)",
            "--   rows    each row of corners from column 0 on, as runs 'count,owner,count,owner,...': owner counts",
            "--           into owners (its pair), 0 is no piece",
            "ns.COVER_POINTS = {"]
    for m in sorted(owned):
        at = points(owned[m])
        filled = np.nonzero(at.any(axis=1))[0]
        lua.append("\t[%d] = { per = %d, row0 = %d, owners = {" % (m, POINTS, filled[0]))
        for i in range(0, len(owners[m]), 10):
            lua.append("\t\t" + " ".join("%d, %d," % pair for pair in owners[m][i:i + 10]))
        lua.append("\t}, rows = {")
        for j in range(filled[0], filled[-1] + 1):
            lua.append("\t\t'%s'," % runs(at[j]))
        lua.append("\t} },")
    lua.append("}")
    with open(os.path.join(ADDON, "Covers.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lua) + "\n")
    for m, look in looks.items():
        Image.fromarray(look).save(os.path.join(WORLD, "look_covers_%d.png" % m))
    print("written %d files (%d pieces, %.1f MB), Covers.lua, world/look_covers_<map>.png" % (files, made, total / 1e6))


if __name__ == "__main__":
    main()
