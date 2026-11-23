"""Globe (Thread)'s own pictures of the world, in the look of the world map on parchment, made from the
game's terrain (GLOBE-BLUEPRINT.md, milestone G2: the tools and one test picture).

    python globe_art.py world       the whole world (G3): one picture, 2048 x 1024, longitude across and latitude
                                    down, written as 8 pieces of 512 (Art/world_<row>_<column>.blp) with Art.lua
    python globe_art.py zones       the zones (G4): Zones.lua (each zone's outline, and which zone each 33-yard chunk
                                    is in, for pointing at one) and Art/line.blp, the line an outline is drawn with
    python globe_art.py test        a preview only: 8 x 8 terrain tiles of Kalimdor round the Crossroads and the
                                    coast at Ratchet, 512 x 512 (about 8 yards a pixel), world/globe_test_kalimdor.png

What it reads (the game's own files, through casc.py; the cells through world.py's store):
    world/map_<id>.bin     what each 4.17-yard cell is (walk, steep, wade, swim, none) and its height
    each terrain tile      the area of each of its 16 x 16 chunks (33 yards), from the chunk's header
    AreaTable              each area's parent, so the Crossroads count as the Barrens

What it draws, in this order:
    land                   each zone a tint of its own from a palette like the world map's (ochres, olives,
                           greens), shaded by the hills (light from the north-west)
    sea and lakes          a pale grey-green, darker near the shore, with three ripple lines along the coast
    coastline              in ink
    zone borders           thin, in a lighter ink
    paper                  the hand-made paper's stains and grain (a soft grain of our own while there is none)
The hand-made pieces (art/PROMPTS.md) are read from art/PatchwerkForever_Thread_Globe/globe/: paper.png is laid
over everything; compass.png, serpent.png, ship.png and the rest of the ink drawings become pictures of their
own on the open sea (Art/decor_<name>.blp), their ink a little faded and a pale wash under their bodies; ring.png,
cut from its magenta, becomes the ring and stand round the ball (Art/ring.blp). A border.png (a ring alone, with
no stand) is used in ring.png's place when it is there.
A drawing may have variations: where the same kind stands twice on the globe (two serpents, two ships), the
second looks for <kind>2.png, the third for <kind>3.png, and uses <kind>.png while there is none. Every second
one of a kind faces the other way (the addon turns it; no second picture is written for that). A kind with no
picture at all (the kraken, the whale, the wind) is left off the globe.
Words are never drawn: the addon writes the names in the game's own font.

What it writes:
    addons/PatchwerkForever_Thread_Globe/Art/<name>.blp   the picture (BLP, DXT1, with mipmaps)
    addons/PatchwerkForever_Thread_Globe/Art.lua          where each picture lies (its map, its tiles)
    world/globe_<name>.png                                the same picture, to look at
"""
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from blp import write_blp
from casc import Storage
from db2 import Table
from terrain import _chunks, tiles_of
from world import NONE, WALK, STEEP, WADE, SWIM, load, map_files

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = r"G:/Games/World of Warcraft"
ADDON = os.path.join(HERE, "..", "addons", "PatchwerkForever_Thread_Globe")
WORLD = os.path.join(HERE, "world")
AREA_TABLE = 1353545          # AreaTable.db2
PARENT = 3                    # its parent area's column (the Crossroads, 380, under the Barrens, 17)

# the look
LAND = [(205, 178, 112), (176, 170, 102), (160, 166, 98), (198, 162, 104), (184, 150, 96), (168, 154, 92),
        (190, 182, 120), (154, 150, 90), (200, 168, 120), (178, 160, 110)]
SEA = np.array((160, 176, 164), dtype=np.float32)
SEA_DEEP = np.array((128, 148, 140), dtype=np.float32)
INK = np.array((62, 46, 32), dtype=np.float32)
BORDER = np.array((104, 76, 50), dtype=np.float32)


def chunk_areas(store, wdt_fdid, tiles_wanted):
    """{(tx, ty): 16 x 16 array of area ids} for the tiles asked for (from each chunk's header)."""
    files = tiles_of(store, wdt_fdid)
    out = {}
    for key in tiles_wanted:
        if key not in files:
            continue
        data = store.read_fdid(files[key])
        grid = np.zeros((16, 16), dtype=np.uint32)
        for tag, at, _size in _chunks(data):
            if tag == b"MCNK":
                ix, iy = struct.unpack_from("<2I", data, at + 4)
                grid[iy % 16, ix % 16] = struct.unpack_from("<I", data, at + 52)[0]
        out[key] = grid
    return out


def area_parents(store):
    table = Table(store.read_fdid(AREA_TABLE))
    return {rid: fields[PARENT] for rid, fields in table.rows()}


def zone_of(area, parents):
    """An area's zone: its last ancestor under the continent (an area with no parent is a zone)."""
    seen = 0
    while parents.get(area, 0) and seen < 8:
        area, seen = parents[area], seen + 1
    return area


def cells_region(world, columns, rows):
    """The cells and heights of tiles columns[0]..columns[1]-1 by rows[0]..rows[1]-1, as two arrays."""
    w, h = columns[1] - columns[0], rows[1] - rows[0]
    kinds = np.full((h * 128, w * 128), NONE, dtype=np.uint8)
    heights = np.zeros((h * 128, w * 128), dtype=np.float32)
    for (tx, ty), (cells, hs) in world["tiles"].items():
        if columns[0] <= tx < columns[1] and rows[0] <= ty < rows[1]:
            x0, y0 = (tx - columns[0]) * 128, (ty - rows[0]) * 128
            kinds[y0:y0 + 128, x0:x0 + 128] = np.frombuffer(cells, dtype=np.uint8).reshape(128, 128)
            heights[y0:y0 + 128, x0:x0 + 128] = np.array(hs, dtype=np.float32).reshape(128, 128) / 10
    return kinds, heights


def shrink(a, n):
    """Each n x n block averaged."""
    h, w = a.shape
    return a.reshape(h // n, n, w // n, n).mean(axis=(1, 3))


def grown(mask, times):
    """The mask grown by one pixel each time (to its eight neighbours)."""
    out = mask.copy()
    for _ in range(times):
        g = out.copy()
        g[1:] |= out[:-1]
        g[:-1] |= out[1:]
        g[:, 1:] |= out[:, :-1]
        g[:, :-1] |= out[:, 1:]
        out = g
    return out


def distance(mask, most):
    """For each pixel off the mask, how many steps (up to most) to reach it; 0 on it."""
    d = np.full(mask.shape, most + 1, dtype=np.int32)
    d[mask] = 0
    reach = mask.copy()
    for step in range(1, most + 1):
        reach = grown(reach, 1)
        d[(d > step) & reach] = step
    return d


def soft(a, radius):
    img = Image.fromarray(np.clip(a * 255, 0, 255).astype(np.uint8))
    from PIL import ImageFilter
    return np.asarray(img.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255


ZONE_SOFT = 2.2               # how far a zone's edge is smoothed (pixels of the detail pictures: about half a chunk)


def smooth_zones(zone):
    """The zones a pixel, their edges smoothed. The game says which zone a place is in by the 33-yard chunk, so
    an edge between two zones is a staircase of chunk corners: each zone is blurred a little and a pixel goes to
    the zone that is strongest there, which turns a staircase into a slanting line and rounds a corner. The
    painted borders and the outlines (Zones.lua) are both made from this, so they lie on one another."""
    out = zone.copy()
    best = np.zeros(zone.shape, np.float32)
    pad = int(ZONE_SOFT * 4) + 2
    for z in np.unique(zone):
        mask = zone == z
        y0, y1, x0, x1 = box(mask, pad, mask.shape)
        strength = soft(mask[y0:y1, x0:x1].astype(np.float32), ZONE_SOFT)
        there = best[y0:y1, x0:x1]
        win = strength > there
        out[y0:y1, x0:x1][win] = z
        there[win] = strength[win]
    return out


def paint(kinds, heights, zones, size):
    """The picture (size x size x 4) of a square region: kinds and heights in cells, zones in cells."""
    n = kinds.shape[0] // size
    water = (kinds == WADE) | (kinds == SWIM) | (kinds == NONE)
    wet = shrink(water.astype(np.float32), n) > 0.5
    land = ~wet
    hgt = shrink(heights, n)
    # zones, one a pixel (the commonest is near enough: take the middle cell's)
    zone = zones[n // 2::n, n // 2::n]
    # land: the zone's tint, shaded by the hills (light from the north-west)
    tint = np.zeros((size, size, 3), dtype=np.float32)
    for z in np.unique(zone):
        tint[zone == z] = LAND[int(z) * 7 % len(LAND)]
    gy, gx = np.gradient(hgt, n * 4.17)
    shade = np.clip(1 + 0.45 * (-gx * 0.7 + gy * 0.7) / np.sqrt(1 + gx * gx + gy * gy), 0.78, 1.18)
    picture = tint * shade[..., None]
    # sea and lakes: darker near the shore, ripple lines along the coast
    d = distance(land, 14)
    near = np.clip(1 - d / 14.0, 0, 1)[..., None]
    sea = SEA * (1 - near * 0.0) + (SEA_DEEP - SEA) * (1 - near) * 0.6
    picture = np.where(wet[..., None], sea, picture)
    for k, strength in ((3, 0.35), (6, 0.22), (9, 0.12)):
        line = soft((wet & (d == k)).astype(np.float32), 0.6)[..., None]
        picture = picture * (1 - line * strength) + INK * line * strength
    # the coastline in ink: land next to water
    coast = land & grown(wet, 1)
    coast = soft(coast.astype(np.float32), 0.5)[..., None]
    picture = picture * (1 - coast * 0.85) + INK * coast * 0.85
    # zone borders: land where the zone changes to a neighbour
    edge = np.zeros_like(land)
    edge[:, 1:] |= zone[:, 1:] != zone[:, :-1]
    edge[1:, :] |= zone[1:, :] != zone[:-1, :]
    edge &= land
    edge = soft(grown(edge, 1).astype(np.float32), 0.7)[..., None]
    picture = picture * (1 - edge * 0.7) + BORDER * edge * 0.7
    # paper: a soft grain over everything
    rng = np.random.default_rng(7)
    grain = soft(rng.random((size, size)).astype(np.float32), 1.2)
    blotch = soft(rng.random((size, size)).astype(np.float32), 18)
    picture = picture * (0.93 + 0.10 * grain[..., None]) * (0.92 + 0.16 * blotch[..., None])
    out = np.zeros((size, size, 4), dtype=np.uint8)
    out[..., :3] = np.clip(picture, 0, 255).astype(np.uint8)
    out[..., 3] = 255
    return out


# ------------------------------------------------------------------ the whole world (milestone G3)
TILE = 1600 / 3
RW = 19000                    # yards of the world to a radian of the globe (Globe.lua takes it from Art.lua)
PLACE = {1: (0.05, -1.05), 0: (0.10, 1.05), 2991: (-0.75, 0.0)}     # each continent's middle: latitude, longitude
WORLD_W, WORLD_H, PIECE = 2048, 1024, 512
# the hand-made pieces (art/PROMPTS.md): in a folder of their own, which the build does not make into pictures
ART_IN = os.path.join(HERE, "..", "art", "PatchwerkForever_Thread_Globe", "globe")
# the ink pieces on the open sea, each a picture of its own on the globe (so it stays sharp as you zoom in):
# (kind, latitude, longitude, how far across in radians). The second of a kind is drawn from <kind>2.png where
# there is one, the third from <kind>3.png (art/PROMPTS.md has a prompt for each), and every second one faces
# the other way.
DECOR = [("compass", 0.62, 0.0, 0.46), ("serpent", -0.30, 2.45, 0.52), ("ship", -0.40, -2.35, 0.43),
         ("serpent", 0.35, 3.05, 0.46), ("ship", -0.15, 0.55, 0.34),
         # the Maelstrom, in the middle of the Great Sea between Kalimdor and the Eastern Kingdoms
         ("maelstrom", 0.05, 0.0, 0.40),
         # on the globe only once their pictures are made
         ("ship", -0.55, 1.90, 0.32), ("kraken", -0.70, -2.85, 0.46), ("whale", 0.62, -2.00, 0.40),
         ("wind", 0.95, 2.20, 0.44)]
INK_SHOWS = 0.80              # how much of the darkest ink shows (1: solid): a little faded, as old ink is
WASH_SHOWS = 0.34             # how much of the pale wash under a drawing's body shows
WASH = (236, 226, 200)        # the wash's colour: bare paper
PAPER = 1.3                   # how strongly the paper's stains and grain show (1: as in its picture)
PAPER_COLOUR = 0.25           # how much of the paper's own colour shows in its stains (0: only light and dark)
PAPER_FINE = 8                # the paper laid again this many times smaller on the detail pictures, for its grain
RING_SIDE = 1024              # the ring and stand's picture, in pixels


def continent_base(store, map_id, parents):
    """Each 33-yard chunk of a continent (1024 x 1024 for its 64 x 64 tiles): how wet, how high, its zone,
    whether there is terrain. Kept in world/globe_base_<id>.npz (reading every tile takes a while)."""
    path = os.path.join(WORLD, "globe_base_%d.npz" % map_id)
    if os.path.exists(path):
        return dict(np.load(path))
    world = load(os.path.join(WORLD, "map_%d.bin" % map_id), walls=False)       # (the terrain alone: the globe paints land, not buildings)
    water = np.ones((1024, 1024), np.float32)
    height = np.zeros((1024, 1024), np.float32)
    have = np.zeros((1024, 1024), bool)
    zone = np.zeros((1024, 1024), np.uint32)
    for (tx, ty), (cells, hs) in world["tiles"].items():
        k = np.frombuffer(cells, dtype=np.uint8).reshape(128, 128)
        h = np.array(hs, dtype=np.float32).reshape(128, 128) / 10
        wet = ((k == WADE) | (k == SWIM) | (k == NONE)).astype(np.float32)
        water[ty * 16:(ty + 1) * 16, tx * 16:(tx + 1) * 16] = shrink(wet, 8)
        height[ty * 16:(ty + 1) * 16, tx * 16:(tx + 1) * 16] = shrink(h, 8)
        have[ty * 16:(ty + 1) * 16, tx * 16:(tx + 1) * 16] = True
    areas = chunk_areas(store, map_files(store)[map_id], list(world["tiles"]))
    known = {}
    for (tx, ty), grid in areas.items():
        for a in np.unique(grid):
            if int(a) not in known:
                known[int(a)] = zone_of(int(a), parents)
        z = np.vectorize(lambda a: known[int(a)])(grid).astype(np.uint32)
        zone[ty * 16:(ty + 1) * 16, tx * 16:(tx + 1) * 16] = z
    np.savez_compressed(path, water=water, height=height, have=have, zone=zone)
    return {"water": water, "height": height, "have": have, "zone": zone}


def continent_areas(store, map_id):
    """Each 33-yard chunk's own area (the smaller place it is in: a town, a camp, a pass), before it is rolled
    up to its zone: 1024 x 1024. Kept in world/globe_areas_<id>.npz."""
    path = os.path.join(WORLD, "globe_areas_%d.npz" % map_id)
    if os.path.exists(path):
        return np.load(path)["area"]
    world = load(os.path.join(WORLD, "map_%d.bin" % map_id), walls=False)       # (the terrain alone: the globe paints land, not buildings)
    area = np.zeros((1024, 1024), np.uint32)
    for (tx, ty), grid in chunk_areas(store, map_files(store)[map_id], list(world["tiles"])).items():
        area[ty * 16:(ty + 1) * 16, tx * 16:(tx + 1) * 16] = grid
    np.savez_compressed(path, area=area)
    return area


def runs_of(row):
    """A row as runs: 'count,value,count,value,...', the last run left out when it is of 0."""
    change = np.flatnonzero(np.diff(row)) + 1
    starts = np.concatenate(([0], change))
    ends = np.concatenate((change, [len(row)]))
    runs = [(int(e - s), int(row[s])) for s, e in zip(starts, ends)]
    if runs[-1][1] == 0:
        runs.pop()
    return ",".join("%d,%d" % r for r in runs)


def main_land(have, least=12):
    """have (chunks) with clusters of fewer than `least` terrain tiles left out (stray islands far off, such as a
    test island in a continent's corner)."""
    tiles = have[::16, ::16].copy()
    keep = np.zeros_like(tiles)
    seen = np.zeros_like(tiles)
    for ty, tx in zip(*np.nonzero(tiles)):
        if seen[ty, tx]:
            continue
        group, todo = [], [(ty, tx)]
        seen[ty, tx] = True
        while todo:
            y, x = todo.pop()
            group.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < 64 and 0 <= nx < 64 and tiles[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    todo.append((ny, nx))
        if len(group) >= least:
            for y, x in group:
                keep[y, x] = True
    return have & np.kron(keep, np.ones((16, 16), dtype=bool))


STEP = ((1, 0), (0, 1), (-1, 0), (0, -1))     # east, south, west, north (rows count downward)


def rings_of(mask):
    """The outlines of a mask: closed rings of corner points (x, y), going round with the mask on the right
    (clockwise as seen), so a ring round land has a positive area and one round a hole in it a negative one.
    Pixels touching only at a corner are kept apart."""
    m = np.pad(mask, 1)
    inside = m[1:-1, 1:-1]
    ways = {}
    for other, dx, dy, d in ((m[:-2, 1:-1], 0, 0, 0), (m[1:-1, 2:], 1, 0, 1), (m[2:, 1:-1], 1, 1, 2), (m[1:-1, :-2], 0, 1, 3)):
        ys, xs = np.nonzero(inside & ~other)             # (an edge of the mask: it starts at this corner, going d)
        for y, x in zip(ys.tolist(), xs.tolist()):
            ways.setdefault((x + dx, y + dy), []).append(d)
    rings = []
    while ways:
        start = at = next(iter(ways))
        ring, d = [], None
        while True:
            here = ways[at]
            go = (d + 1) % 4 if d is not None and (d + 1) % 4 in here else here[0]     # (a right turn where it can)
            here.remove(go)
            if not here:
                del ways[at]
            if go != d:
                ring.append(at)
            d = go
            at = (at[0] + STEP[go][0], at[1] + STEP[go][1])
            if at == start:
                break
        rings.append(ring)
    return rings


def area_of(ring):
    p = np.asarray(ring, dtype=np.float64)
    q = np.roll(p, -1, axis=0)
    return float((p[:, 0] * q[:, 1] - q[:, 0] * p[:, 1]).sum()) / 2


def without_slivers(land, hgt, width, length, what=""):
    """land without its slivers: pieces of land on their own that are long (over `length` pixels), thin (under
    `width` on average) and dead flat at a height of nought. The game's terrain has one: a rim of flat dry ground
    along the edges of three ocean tiles off Azshara, which would be painted as a corner of land out at sea."""
    from PIL import ImageDraw
    out = land.copy()
    for ring in rings_of(land):
        a = area_of(ring)
        p = np.asarray(ring)
        half_round = float(np.abs(np.roll(p, -1, axis=0) - p).sum()) / 2
        if a > 0 and half_round > length and a / half_round < width:
            x0, y0, x1, y1 = p[:, 0].min(), p[:, 1].min(), p[:, 0].max(), p[:, 1].max()
            # (drawn at twice the size, so each pixel's middle is asked about, not its corner)
            img = Image.new("L", (int(x1 - x0) * 2 + 1, int(y1 - y0) * 2 + 1), 0)
            ImageDraw.Draw(img).polygon([(int(x - x0) * 2, int(y - y0) * 2) for x, y in ring], fill=255)
            inside = np.asarray(img)[1::2, 1::2] > 0
            if np.abs(hgt[y0:y1, x0:x1][inside]).max() > 0.01:
                continue
            out[y0:y1, x0:x1] &= ~inside
            print("  a sliver left out%s: %d pixels, columns %d to %d, rows %d to %d" % (what, int(a), x0, x1, y0, y1))
    return out


def dry_chunks(base):
    """Which 33-yard chunks of a continent are land: of its main land, more dry than wet, and no sliver."""
    return without_slivers(main_land(base["have"]) & (base["water"] < 0.5), base["height"], 1.5, 15, " (chunks)")


def basis(lat, lon):
    cl, sl, co, so = np.cos(lat), np.sin(lat), np.cos(lon), np.sin(lon)
    return np.array([cl * co, cl * so, sl]), np.array([-so, co, 0.0]), np.array([-sl * co, -sl * so, cl])


def grown_wrap(mask, times):
    """grown(), wrapping round left to right (the world picture goes all the way round)."""
    out = mask.copy()
    for _ in range(times):
        g = out | np.roll(out, 1, axis=1) | np.roll(out, -1, axis=1)
        g[1:] |= out[:-1]
        g[:-1] |= out[1:]
        out = g
    return out


def distance_wrap(mask, most):
    d = np.full(mask.shape, most + 1, dtype=np.int32)
    d[mask] = 0
    reach = mask.copy()
    for step in range(1, most + 1):
        reach = grown_wrap(reach, 1)
        d[(d > step) & reach] = step
    return d


def paper_tile(size=1024):
    """The hand-made paper as a square that repeats without a seam, each colour over its own mean (so 1 changes
    nothing); None while there is no paper. Its edges are blended into each other to hide the join."""
    path = os.path.join(ART_IN, "paper.png")
    if not os.path.exists(path):
        return None
    p = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    band = p.shape[1] // 16
    t = (np.arange(band) / band)[None, :, None]
    p = np.concatenate([p[:, :band] * t + p[:, -band:] * (1 - t), p[:, band:-band]], axis=1)
    band = p.shape[0] // 16
    t = (np.arange(band) / band)[:, None, None]
    p = np.concatenate([p[:band] * t + p[-band:] * (1 - t), p[band:-band]], axis=0)
    img = Image.fromarray(np.clip(p, 0, 255).astype(np.uint8)).resize((size, size), Image.LANCZOS)
    p = np.asarray(img, dtype=np.float32)
    # (mostly its light and dark, with a little of its colour: all of the colour turns the sea from blue to
    # mustard and back)
    light = (p.mean(axis=2) / p.mean())[..., None]
    return light + PAPER_COLOUR * (p / p.reshape(-1, 3).mean(axis=0) - light)


def paper_at(tile, lat, lon, times=1):
    """The paper at places on the globe (arrays of latitude and longitude): it goes twice round the equator and
    once from pole to pole, as in the world picture, so every picture of a place shows the same stains there."""
    n = tile.shape[0]
    u = ((lon + np.pi) / (2 * np.pi) * 2 * n * times - 0.5) % n
    v = ((np.pi / 2 - lat) / np.pi * n * times - 0.5) % n
    u0, v0 = np.floor(u).astype(np.int64), np.floor(v).astype(np.int64)
    fu, fv = (u - u0)[..., None], (v - v0)[..., None]
    u0, v0, u1, v1 = u0 % n, v0 % n, (u0 + 1) % n, (v0 + 1) % n
    return (tile[v0, u0] * (1 - fu) + tile[v0, u1] * fu) * (1 - fv) + (tile[v1, u0] * (1 - fu) + tile[v1, u1] * fu) * fv


def detail_paper(tile, shape, tx0, ty0, place):
    """What the paper multiplies each pixel of a continent's detail by: the world's stains, and the paper again
    much smaller for its grain. place: the continent's (latitude, longitude, middle column, middle row)."""
    plat, plon, cx, cy = place
    C, E, N = basis(plat, plon)
    out = np.empty(shape + (3,), np.float32)
    xs = (tx0 + (np.arange(shape[1]) + 0.5) / PER - cx) * TILE          # yards east of the continent's middle
    for y0 in range(0, shape[0], 256):
        ys = (cy - ty0 - (np.arange(y0, min(y0 + 256, shape[0])) + 0.5) / PER) * TILE     # yards north
        e, n = np.meshgrid(xs, ys)
        d = np.hypot(e, n) + 1e-9
        sr = np.sin(d / RW) / d
        P = np.cos(d / RW)[..., None] * C + (sr * e)[..., None] * E + (sr * n)[..., None] * N
        lat, lon = np.arcsin(np.clip(P[..., 2], -1, 1)), np.arctan2(P[..., 1], P[..., 0])
        out[y0:y0 + 256] = (1 + PAPER * (paper_at(tile, lat, lon) - 1)) * (1 + 0.6 * (paper_at(tile, lat, lon, PAPER_FINE) - 1))
    return out


def maelstrom_drawing(size=960):
    """The Maelstrom in ink, drawn here until there is a hand-made maelstrom.png: a whirlpool of spiral arms
    winding in to a dark eye, heavy strokes with finer broken ones between them. Dark ink on white."""
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    u, v = (x - size / 2) / (size / 2), (size / 2 - y) / (size / 2)
    th = np.arctan2(v, u)
    r = np.hypot(u, v) * (1 + 0.035 * np.sin(3 * th + 0.7) + 0.02 * np.sin(7 * th + 2.1)) + 1e-6     # (not quite round, as drawn by hand)
    twist = 2.3                                           # how tightly the arms wind
    phase = th + twist * np.log(r)                        # the same all along an arm
    soft = 1.6 / (size / 2)                               # an edge's softness: about a pixel and a half

    def strokes(n, offset, width):
        """Ink for n arms, each `width` across (in parts of the half picture, by the distance from the middle)."""
        at = (phase * n / (2 * np.pi) + offset) % 1.0
        off = np.minimum(at, 1 - at) * (2 * np.pi / n) * r / np.sqrt(1 + twist * twist)
        return np.clip((width / 2 - off) / soft, 0, 1)

    swell = np.clip(np.sin(np.pi * np.clip((r - 0.07) / 0.88, 0, 1)), 0, 1) ** 0.75      # strokes thin toward the eye and the rim
    along = np.log(r)                                                         # how far along an arm
    ink = strokes(5, 0.0, 0.070 * swell * (0.75 + 0.25 * np.sin(5 * along + 2 * th)))
    ink = np.maximum(ink, strokes(5, 0.5, 0.026 * swell) * (np.sin(11 * along + 1.0) > -0.55))
    ink = np.maximum(ink, strokes(10, 0.25, 0.012 * swell) * (np.sin(23 * along + 3 * th) > 0.15) * (r > 0.22))
    # foam flung off the rim: short strokes that carry the arms on, further and further apart
    ink = np.maximum(ink, strokes(15, 0.1, 0.012) * (np.sin(40 * along + 5 * th) > 0.55) * (r > 0.80) * (r < 0.99))
    # the eye: dark, with a pale ring round it
    ink = np.where(r < 0.085, 0.0, ink)
    ink = np.maximum(ink, np.clip((0.050 - r) / soft, 0, 1))
    ink = np.maximum(ink, np.clip((0.006 - np.abs(r - 0.078)) / soft, 0, 1))
    ink = ink * np.clip((0.995 - r) / 0.02, 0, 1)
    colour = np.array([52, 36, 22], np.float32)
    rgb = 255 - ink[..., None] * (255 - colour)
    return Image.fromarray(rgb.astype(np.uint8), "RGB")


# ink pieces drawn here where no hand-made picture of that name is in art/
DRAWN = {"maelstrom": maelstrom_drawing}


def blurred(mask, radius):
    """A mask (0 to 1) softened."""
    im = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32) / 255


def body_of(ink):
    """Where a drawing's body is, from where its ink is (0 to 1): what its outlines close in, as far as that is
    near ink (the gap under a serpent's arch is closed in too, and is not its body), and wherever the ink is
    dense (hatching, scales, the arms of the whirlpool). Soft at its edge."""
    lines = ink > 0.3
    # (outlines drawn by hand have small gaps: thickened a little before the outside is flooded from a corner)
    thick = Image.fromarray((lines * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    padded = Image.new("L", (thick.width + 2, thick.height + 2), 0)
    padded.paste(thick, (1, 1))
    ImageDraw.floodfill(padded, (0, 0), 128)
    inside = np.asarray(padded)[1:-1, 1:-1] != 128
    near = blurred(lines, 9) > 0.07
    dense = np.clip((blurred(lines, 7) - 0.16) / 0.22, 0, 1)
    return blurred(np.maximum(inside & near, dense), 2.5)


def decor_sources():
    """Each ink piece of DECOR that has a picture to be made from: (kind, the picture's name, turned the other
    way, latitude, longitude, size). The n-th of a kind is made from <kind><n>.png; the second, while it has none,
    from <kind>.png (or the drawing made here); every second one of a kind is turned."""
    out, count = [], {}
    for kind, dlat, dlon, size in DECOR:
        n = count[kind] = count.get(kind, 0) + 1
        source = None
        if n > 1 and os.path.exists(os.path.join(ART_IN, "%s%d.png" % (kind, n))):
            source = "%s%d" % (kind, n)
        elif n <= 2 and (os.path.exists(os.path.join(ART_IN, kind + ".png")) or kind in DRAWN):
            source = kind                                    # (a third of a kind only with a drawing of its own)
        if source:
            out.append((kind, source, n % 2 == 0, dlat, dlon, size))
    return out


def decor_pictures(art_dir, written):
    """The hand-made ink pieces as pictures of their own: the ink's colour, showing as much as the drawing is
    dark there, a little faded; under the drawing's body a pale wash, so the sea's mottling does not show
    through it as through glass; clear everywhere else. Returns decor_sources()."""
    sources = decor_sources()
    looks = []
    for name in sorted({s[1] for s in sources}):
        path = os.path.join(ART_IN, name + ".png")
        drawing = Image.open(path).convert("RGB") if os.path.exists(path) else DRAWN[name]()
        a = np.asarray(drawing.resize((480, 480), Image.LANCZOS), dtype=np.float32)
        light = a.mean(axis=2)
        darkest = light < np.percentile(light, 5)
        ink, floor = a[darkest].mean(axis=0), float(light[darkest].mean())
        dark = np.clip((246 - light) / (246 - floor), 0, 1)
        show = dark ** 0.85 * INK_SHOWS
        wash = body_of(dark) * WASH_SHOWS
        # (the ink over the wash, as one picture)
        alpha = show + wash * (1 - show)
        colour = (ink[None, None, :] * show[..., None] + np.array(WASH, np.float32)[None, None, :] * (wash * (1 - show))[..., None]) \
            / np.maximum(alpha, 1e-4)[..., None]
        rgba = np.zeros((512, 512, 4), np.uint8)             # (a clear margin, so nothing smears at the edges)
        rgba[..., :3] = ink.astype(np.uint8)
        rgba[16:496, 16:496, :3] = np.clip(colour, 0, 255).astype(np.uint8)
        rgba[16:496, 16:496, 3] = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
        write_blp(os.path.join(art_dir, "decor_%s.blp" % name), rgba)
        written.add("decor_%s.blp" % name)
        looks.append(rgba)
    if looks:
        # (how they look on the sea, for a look before the game: world/look_decor.png)
        sheet = Image.new("RGBA", (512 * len(looks), 512), (140, 159, 149, 255))
        for i, rgba in enumerate(looks):
            sheet.alpha_composite(Image.fromarray(rgba), (i * 512, 0))
        sheet.convert("RGB").save(os.path.join(WORLD, "look_decor.png"))
    return sources


def ring_picture(art_dir, written):
    """The brass ring and stand, cut from its flat magenta, its hole made a true circle and put in the middle
    across. Returns where it is in the picture, in parts of its side: the hole's middle (down), the hole's
    radius, and the top and bottom of what is drawn; None while there is no ring. A border.png (a ring alone,
    with no stand: art/PROMPTS.md) is used before ring.png; the globe lays itself out by what the picture holds."""
    path = os.path.join(ART_IN, "border.png")
    if not os.path.exists(path):
        path = os.path.join(ART_IN, "ring.png")
    if not os.path.exists(path):
        return None
    r = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    magenta = np.minimum(r[..., 0], r[..., 2]) - r[..., 1]
    alpha = 1 - np.clip((magenta - 40) / 100, 0, 1)
    # (the soft edge takes its colour from the brass and wood beside it, not from the magenta)
    solid = (alpha > 0.999).astype(np.float32)
    near = np.maximum(soft(solid, 3), 1e-3)
    beside = np.stack([soft(r[..., c] / 255 * solid, 3) / near for c in range(3)], axis=-1) * 255
    rgb = np.where(solid[..., None] > 0, r, np.clip(beside, 0, 255))
    H, W = alpha.shape
    clear = alpha < 0.5

    def run(line, at):
        a = b = at
        while a > 0 and line[a - 1]:
            a -= 1
        while b < len(line) - 1 and line[b + 1]:
            b += 1
        return a, b

    xl, xr = run(clear[int(H * 0.36)], W // 2)
    yt, yb = run(clear[:, (xl + xr) // 2], int(H * 0.36))
    xl, xr = run(clear[(yt + yb) // 2], (xl + xr) // 2)
    squeeze = (yb - yt) / (xr - xl)                          # (the hole is drawn a little wider than tall)
    rgba = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(rgba, "RGBA").resize((int(round(W * squeeze)), H), Image.LANCZOS)
    square = Image.new("RGBA", (H, H), (0, 0, 0, 0))
    square.paste(img, (int(round(H / 2 - (xl + xr + 1) / 2 * squeeze)), 0))
    square = square.resize((RING_SIDE, RING_SIDE), Image.LANCZOS)
    out = np.asarray(square).copy()
    out[..., :3][out[..., 3] == 0] = (60, 40, 20)           # (clear pixels in a brown, not black, for the edges)
    write_blp(os.path.join(art_dir, "ring.blp"), out)
    written.add("ring.blp")
    rows = np.nonzero((out[..., 3] > 128).any(axis=1))[0]
    square.save(os.path.join(WORLD, "globe_ring.png"))
    return ((yt + yb + 1) / 2 / H, (yb - yt + 1) / 2 / H, rows.min() / RING_SIDE, (rows.max() + 1) / RING_SIDE)


def world_picture(store):
    """The whole world, as one picture: longitude across (-pi to pi), latitude down (north to south)."""
    from globe import minimap_tiles
    parents = area_parents(store)
    files = map_files(store)
    H, W = WORLD_H, WORLD_W
    lon = -np.pi + (np.arange(W) + 0.5) / W * 2 * np.pi
    lat = np.pi / 2 - (np.arange(H) + 0.5) / H * np.pi
    LON, LAT = np.meshgrid(lon, lat)
    P = np.stack([np.cos(LAT) * np.cos(LON), np.cos(LAT) * np.sin(LON), np.sin(LAT)], axis=-1)    # (H, W, 3)
    land = np.zeros((H, W), bool)
    zone = np.zeros((H, W), np.uint32)
    shade = np.ones((H, W), np.float32)
    layout = []
    for map_id, (plat, plon) in PLACE.items():
        base = continent_base(store, map_id, parents)
        mm = minimap_tiles(store, files[map_id])
        cx = sum(t[0] for t in mm) / len(mm) + 0.5           # (as Globe.lua lays it: round its tiles' middle)
        cy = sum(t[1] for t in mm) / len(mm) + 0.5
        layout.append((map_id, plat, plon, cx, cy))
        C, E, N = basis(plat, plon)
        rho = np.arccos(np.clip(P @ C, -1, 1))
        e, n = P @ E, P @ N
        hyp = np.sqrt(e * e + n * n) + 1e-12
        gx = cx + rho * RW * e / hyp / TILE
        gy = cy - rho * RW * n / hyp / TILE
        chx, chy = np.floor(gx * 16).astype(np.int64), np.floor(gy * 16).astype(np.int64)
        ok = (rho < 1.7) & (chx >= 0) & (chx < 1024) & (chy >= 0) & (chy < 1024)
        sel = ok.copy()
        sel[ok] = main_land(base["have"])[chy[ok], chx[ok]]
        dry = dry_chunks(base)
        gyr, gxr = np.gradient(base["height"], 33.33)
        relief = np.clip(1 + 0.45 * (-gxr * 0.7 + gyr * 0.7) / np.sqrt(1 + gxr * gxr + gyr * gyr), 0.78, 1.18)
        land[sel] = dry[chy[sel], chx[sel]]
        zone[sel] = base["zone"][chy[sel], chx[sel]]
        shade[sel] = relief[chy[sel], chx[sel]]
        print("  %d: %d pixels of terrain" % (map_id, int(sel.sum())))
    wet = ~land
    tint = np.zeros((H, W, 3), np.float32)
    for z in np.unique(zone[land]):
        tint[land & (zone == z)] = LAND[int(z) * 7 % len(LAND)]
    picture = tint * shade[..., None]
    d = distance_wrap(land, 14)
    near = np.clip(1 - d / 14.0, 0, 1)[..., None]
    sea = SEA + (SEA_DEEP - SEA) * (1 - near) * 0.6
    picture = np.where(wet[..., None], sea, picture)
    for k, strength in ((2, 0.35), (4, 0.22), (6, 0.12)):
        line = soft((wet & (d == k)).astype(np.float32), 0.6)[..., None]
        picture = picture * (1 - line * strength) + INK * line * strength
    coast = soft((land & grown_wrap(wet, 1)).astype(np.float32), 0.5)[..., None]
    picture = picture * (1 - coast * 0.85) + INK * coast * 0.85
    edge = np.zeros_like(land)
    edge[:, 1:] |= zone[:, 1:] != zone[:, :-1]
    edge[1:, :] |= zone[1:, :] != zone[:-1, :]
    edge &= land
    edge = soft(edge.astype(np.float32), 0.6)[..., None]
    picture = picture * (1 - edge * 0.6) + BORDER * edge * 0.6
    # the paper: the hand-made one twice round the world, else a plain grain
    tile = paper_tile(H)
    if tile is not None:
        picture = picture * (1 + PAPER * (np.tile(tile, (1, W // H, 1)) - 1))
    else:
        rng = np.random.default_rng(7)
        grain = soft(rng.random((H, W)).astype(np.float32), 1.2)
        blotch = soft(rng.random((H, W)).astype(np.float32), 24)
        picture = picture * (0.93 + 0.10 * grain[..., None]) * (0.92 + 0.16 * blotch[..., None])
    rgba = np.zeros((H, W, 4), np.uint8)
    rgba[..., :3] = np.clip(picture, 0, 255).astype(np.uint8)
    rgba[..., 3] = 255
    sea_now = rgba[..., :3][wet & (d > 13)].reshape(-1, 3).mean(axis=0) / 255
    return rgba, layout, sea_now


# ------------------------------------------------------------------ each continent in detail (milestone G4)
PER = 64                      # pixels a terrain tile in the detail pictures (8.3 yards a pixel)
BLOCK = 8                     # terrain tiles a detail picture covers, each way (8 x 64 = 512 pixels)


def style(land, zone, hgt, spacing, ripples, seed, paper=None):
    """A region in the parchment look, as RGB bytes: land (bool), zone (ids), hgt (yards) a pixel apart by
    `spacing` yards; ripple lines `ripples` pixels out from the coast; paper: what the hand-made paper
    multiplies each pixel by (without it, a plain grain)."""
    wet = ~land
    picture = np.zeros(land.shape + (3,), np.float32)
    for z in np.unique(zone[land]):
        picture[land & (zone == z)] = LAND[int(z) * 7 % len(LAND)]
    gy, gx = np.gradient(hgt, spacing)
    shade = np.clip(1 + 0.45 * (-gx * 0.7 + gy * 0.7) / np.sqrt(1 + gx * gx + gy * gy), 0.78, 1.18).astype(np.float32)
    del gx, gy
    picture *= shade[..., None]
    del shade
    most = ripples[-1] + 5
    d = distance(land, most)
    near = np.clip(1 - d / float(most), 0, 1)[..., None]
    sea = SEA + (SEA_DEEP - SEA) * (1 - near) * 0.6
    picture[wet] = sea[wet]
    del sea, near
    for k, strength in zip(ripples, (0.35, 0.22, 0.12)):
        line = soft((wet & (d == k)).astype(np.float32), 0.6)[..., None]
        picture *= 1 - line * strength
        picture += INK * line * strength
    coast = soft((land & grown(wet, 1)).astype(np.float32), 0.5)[..., None]
    picture *= 1 - coast * 0.85
    picture += INK * coast * 0.85
    edge = np.zeros_like(land)
    edge[:, 1:] |= zone[:, 1:] != zone[:, :-1]
    edge[1:, :] |= zone[1:, :] != zone[:-1, :]
    edge &= land
    edge = soft(grown(edge, 1).astype(np.float32), 0.7)[..., None]
    picture *= 1 - edge * 0.7
    picture += BORDER * edge * 0.7
    del edge
    if paper is not None:
        picture *= paper
        return np.clip(picture, 0, 255).astype(np.uint8)
    rng = np.random.default_rng(seed)
    grain = soft(rng.random(land.shape, dtype=np.float32), 1.2)
    picture *= (0.93 + 0.10 * grain)[..., None]
    del grain
    blotch = soft(rng.random(land.shape, dtype=np.float32), 18)
    picture *= (0.92 + 0.16 * blotch)[..., None]
    return np.clip(picture, 0, 255).astype(np.uint8)


def continent_cells(map_id, base):
    """A continent at PER pixels a tile, over the blocks of tiles its main land lies in: land (bool), heights
    (yards), the zone of each pixel, which tiles have land, and (tx0, ty0, bx0, bx1, by0, by1): its first tile
    and its blocks."""
    keep = main_land(base["have"])[::16, ::16]
    ys, xs = np.nonzero(keep)
    bx0, bx1 = xs.min() // BLOCK, xs.max() // BLOCK + 1
    by0, by1 = ys.min() // BLOCK, ys.max() // BLOCK + 1
    tx0, ty0 = bx0 * BLOCK, by0 * BLOCK
    H, W = (by1 - by0) * BLOCK * PER, (bx1 - bx0) * BLOCK * PER
    land = np.zeros((H, W), bool)
    hgt = np.zeros((H, W), np.float32)
    zone = np.zeros((H, W), np.uint32)
    has = np.zeros((64, 64), bool)
    world = load(os.path.join(WORLD, "map_%d.bin" % map_id), walls=False)       # (the terrain alone: the globe paints land, not buildings)
    n = 128 // PER
    for (tx, ty), (cells, hs) in world["tiles"].items():
        if not keep[ty, tx]:
            continue
        k = np.frombuffer(cells, dtype=np.uint8).reshape(128, 128)
        dry = ~((k == WADE) | (k == SWIM) | (k == NONE))
        y0, x0 = (ty - ty0) * PER, (tx - tx0) * PER
        tile_land = shrink(dry.astype(np.float32), n) > 0.5
        land[y0:y0 + PER, x0:x0 + PER] = tile_land
        hgt[y0:y0 + PER, x0:x0 + PER] = shrink(np.array(hs, dtype=np.float32).reshape(128, 128) / 10, n)
        zone[y0:y0 + PER, x0:x0 + PER] = np.kron(base["zone"][ty * 16:(ty + 1) * 16, tx * 16:(tx + 1) * 16],
                                                 np.ones((PER // 16, PER // 16), dtype=np.uint32))
        has[ty, tx] = tile_land.any()
    zone = smooth_zones(zone)
    land = without_slivers(land, hgt, 5, 60)
    th, tw = land.shape[0] // PER, land.shape[1] // PER
    has = np.zeros((64, 64), bool)                           # (which tiles have land, the slivers gone)
    has[ty0:ty0 + th, tx0:tx0 + tw] = land.reshape(th, PER, tw, PER).any(axis=(1, 3))
    return land, hgt, zone, has, (tx0, ty0, bx0, bx1, by0, by1)


def continent_detail(map_id, base, art_dir, written, place=None, tile=None):
    """A continent painted whole at PER pixels a tile (so no seams), cut in BLOCK x BLOCK-tile pictures; those
    with no land within a tile of them are left out (the world picture's sea shows there)."""
    land, hgt, zone, has, (tx0, ty0, bx0, bx1, by0, by1) = continent_cells(map_id, base)
    H, W = land.shape
    paper = detail_paper(tile, land.shape, tx0, ty0, place) if tile is not None else None
    rgb = style(land, zone, hgt, 1600 / 3 / PER, (3, 6, 9), seed=map_id + 11, paper=paper)
    del paper
    del land, hgt, zone
    near = grown(has, 1)
    pieces = []
    for by in range(by0, by1):
        for bx in range(bx0, bx1):
            if not near[by * BLOCK:(by + 1) * BLOCK, bx * BLOCK:(bx + 1) * BLOCK].any():
                continue
            y, x = (by - by0) * BLOCK * PER, (bx - bx0) * BLOCK * PER
            rgba = np.full((BLOCK * PER, BLOCK * PER, 4), 255, np.uint8)
            rgba[..., :3] = rgb[y:y + BLOCK * PER, x:x + BLOCK * PER]
            name = "%d_%d_%d" % (map_id, bx, by)
            write_blp(os.path.join(art_dir, name + ".blp"), rgba)
            written.add(name + ".blp")
            pieces.append((name, map_id, bx * BLOCK, (bx + 1) * BLOCK, by * BLOCK, (by + 1) * BLOCK))
    Image.fromarray(rgb).resize((W // 8, H // 8), Image.LANCZOS).save(os.path.join(WORLD, "globe_detail_%d.png" % map_id))
    print("  %d: %d detail pictures (%d x %d pixels painted)" % (map_id, len(pieces), W, H))
    return pieces


# ------------------------------------------------------------------ the zones (milestone G4)
NAME = 1                      # AreaTable's column of the name shown (the Barrens: "The Barrens")
ZONE_LEAST = 100              # a zone has at least this much land (33-yard chunks): less is a sea, or a scrap
RING_LEAST = 150              # an island smaller than this (pixels of the detail pictures) gets no outline
RING_WITHIN = 0.3             # an outline keeps to within this of the rounded one (pixels: about 3 yards)
RING_ROUND = 1.6              # how far an outline's corners are rounded (pixels along it: about 13 yards)
FINE = 4                      # an outline's points are written this many to a pixel, so a curve stays one
THIN = 0.08                   # a ring less round than this (a circle is 1) is a sliver, and left out
NEAR_LAND = 5                 # water this near a zone's land (chunks) counts as the zone when pointing at it
def rounded(ring):
    """The ring as a smooth line: its points taken every half pixel along it, each then the weighted middle of
    those near it along the ring. A staircase of pixel or chunk corners becomes a slant, a corner a curve; a
    long straight side stays where it is."""
    p = np.asarray(ring, dtype=np.float64)
    q = np.vstack([p, p[:1]])
    along = np.concatenate([[0.0], np.cumsum(np.hypot(*np.diff(q, axis=0).T))])
    total = float(along[-1])
    n = int(total / 0.5)
    sigma = RING_ROUND / 0.5
    half = int(sigma * 3) + 1
    if n <= 2 * half:
        return p
    at = np.arange(n) * total / n
    weights = np.exp(-0.5 * (np.arange(-half, half + 1) / sigma) ** 2)
    weights /= weights.sum()
    out = []
    for column in (0, 1):
        v = np.interp(at, along, q[:, column])
        out.append(np.convolve(np.concatenate([v[-half:], v, v[:half]]), weights, mode="valid"))
    return np.column_stack(out)


def simplified(ring, within):
    """The ring with the points left out that lie within `within` of the line between those kept."""
    p = np.asarray(ring, dtype=np.float64)
    n = len(p)
    far = int(np.argmax(((p - p[0]) ** 2).sum(axis=1)))
    keep = np.zeros(n, bool)
    keep[0] = keep[far] = True
    todo = [(0, far), (far, n)]                              # (n: back at the first point)
    while todo:
        a, b = todo.pop()
        if b - a < 2:
            continue
        A, B = p[a], p[b % n]
        between = p[a + 1:b] - A
        along = B - A
        length = float(np.hypot(along[0], along[1]))
        off = np.hypot(between[:, 0], between[:, 1]) if length == 0 else \
            np.abs(along[0] * between[:, 1] - along[1] * between[:, 0]) / length
        i = int(np.argmax(off))
        if off[i] > within:
            keep[a + 1 + i] = True
            todo += [(a, a + 1 + i), (a + 1 + i, b)]
    return p[keep]


def filled(mask):
    """The mask with its holes filled (the water wholly inside the land)."""
    from PIL import ImageDraw
    img = Image.fromarray(np.pad(mask, 1).astype(np.uint8) * 255)
    ImageDraw.floodfill(img, (0, 0), 128)
    return (np.asarray(img) != 128)[1:-1, 1:-1]


def box(mask, pad, most):
    ys, xs = np.nonzero(mask)
    return (max(0, ys.min() - pad), min(most[0], ys.max() + 1 + pad), max(0, xs.min() - pad), min(most[1], xs.max() + 1 + pad))


def line_picture(art_dir):
    """The line a zone is outlined with: across it, clear, dark ink, a pale gold middle, dark ink, clear."""
    n = 16
    t = np.abs(np.arange(n) + 0.5 - n / 2) / (n / 2)         # 0 in the middle, 1 at the sides
    alpha = np.clip((1.0 - t) / 0.4, 0, 1)
    gold = np.clip((0.5 - t) / 0.22, 0, 1)[:, None]
    rgb = np.array((255, 232, 160)) * gold + np.array((52, 34, 18)) * (1 - gold)
    rgba = np.zeros((n, n, 4), np.uint8)
    rgba[..., :3] = rgb[:, None, :].astype(np.uint8)
    rgba[..., 3] = (alpha * alpha * (3 - 2 * alpha) * 255).astype(np.uint8)[:, None]
    write_blp(os.path.join(art_dir, "line.blp"), rgba)


def lua_text(text):
    return "'" + text.replace("\\", "\\\\").replace("'", "\\'") + "'"


def zones():
    """Zones.lua: each continent's zones (those with land enough), their outlines for the globe to draw and,
    by 33-yard chunk, which zone is where, for pointing at one."""
    from db2 import texts
    from PIL import ImageDraw
    store = Storage(GAME, "wowf")
    parents = area_parents(store)
    names = texts(Table(store.read_fdid(AREA_TABLE)), NAME)
    lines = ["-- Globe (Thread): the zones of each continent, to point at, outline and zoom to. Written by",
             "-- tools/globe_art.py (python globe_art.py zones), from the area of each terrain chunk.",
             "local _, ns = ...", "",
             "-- By continent (the game's map number):",
             "--   per     an outline's units to a terrain tile",
             "--   middle  the middle of the continent's land (column, row, in tiles); reach: how far its land goes",
             "--           from there (tiles)",
             "--   zones   each: id (the game's area), name (in English: the game's own is shown where it gives one),",
             "--           rings (each an outline, 'x,y,x,y,...', the largest first)",
             "--   land    the terrain tiles with land on them (row * 64 + column, 'n,n,...'): the ground is drawn on",
             "--           these, and fades out to sea over the tiles round them",
             "--   row0    the row (in chunks, 16 to a tile) that rows begins at",
             "--   rows    each row of chunks from column 0 on, as runs 'count,zone,count,zone,...': zone counts into",
             "--           zones, 0 is none (the open sea, or land of no zone)",
             "--   areas   the same rows, with the smaller place each chunk is in (a town, a camp, a pass) as the",
             "--           game's area: 'count,area,count,area,...', 0 where the chunk is of its zone and no more",
             "-- ns.AREAS: those areas' names in English (the game's own is shown where it gives one).",
             "ns.ZONES = {"]
    area_names = {}
    points = 0
    for map_id in PLACE:
        base = continent_base(store, map_id, parents)
        keep = main_land(base["have"])
        dry = dry_chunks(base)
        zone_c = np.where(keep, base["zone"], 0)
        ids = [int(z) for z in np.unique(zone_c) if z and int((dry & (zone_c == z)).sum()) >= ZONE_LEAST]
        land, _hgt, zone, has, (tx0, ty0, _bx0, _bx1, _by0, _by1) = continent_cells(map_id, base)
        ys, xs = np.nonzero(dry)
        mx, my = (xs.min() + xs.max() + 1) / 32, (ys.min() + ys.max() + 1) / 32
        reach = float(np.hypot((xs + 0.5) / 16 - mx, (ys + 0.5) / 16 - my).max())
        lines.append("\t[%d] = { per = %d, middle = { %.3f, %.3f }, reach = %.3f, zones = {" % (map_id, PER * FINE, mx, my, reach))
        hit = np.zeros((1024, 1024), np.uint8)
        preview = Image.open(os.path.join(WORLD, "globe_detail_%d.png" % map_id)).convert("RGB")
        draw = ImageDraw.Draw(preview)
        for index, z in enumerate(ids, 1):
            mine = land & (zone == z)
            y0, y1, x0, x1 = box(mine, 6, mine.shape)
            # (tidied first: a spike or a notch a pixel wide is no part of an outline)
            tidy = soft(mine[y0:y1, x0:x1].astype(np.float32), 1.0) > 0.5
            rings = [r for r in rings_of(tidy) if area_of(r) >= RING_LEAST]
            rings.sort(key=area_of, reverse=True)
            texts_out = []
            for ring in rings:
                p = simplified(rounded(ring), RING_WITHIN)
                if len(p) < 4:
                    continue
                # (a sliver, such as a strip of flat terrain left out at sea, is no island: far more edge than land)
                edge = float(np.hypot(*(np.roll(p, -1, axis=0) - p).T).sum())
                if texts_out and 4 * np.pi * area_of(p) < THIN * edge * edge:
                    continue
                p = p + (x0 + tx0 * PER, y0 + ty0 * PER)
                points += len(p)
                texts_out.append(",".join("%d,%d" % (x, y) for x, y in np.rint(p * FINE).astype(int)))
                draw.line([((x - tx0 * PER) / 8, (y - ty0 * PER) / 8) for x, y in np.vstack([p, p[:1]])], fill=(200, 30, 30))
            lines.append("\t\t{ id = %d, name = %s, rings = {" % (z, lua_text(names.get(z) or "Zone %d" % z)))
            lines += ["\t\t\t'%s'," % t for t in texts_out]
            lines.append("\t\t} },")
            # pointing: the zone's chunks on its land, on the water inside it and a little off its shores
            mine_c = dry & (zone_c == z)
            cy0, cy1, cx0, cx1 = box(mine_c, NEAR_LAND + 1, mine_c.shape)
            near = grown(filled(mine_c[cy0:cy1, cx0:cx1]), NEAR_LAND)
            part = hit[cy0:cy1, cx0:cx1]
            part[near & (zone_c[cy0:cy1, cx0:cx1] == z)] = index
            print("    %5d %-24s %d rings, %d points" % (z, names.get(z), len(texts_out), sum(t.count(",") + 1 for t in texts_out) // 2))
        rows = np.nonzero(hit.any(axis=1))[0]
        landed = ["%d" % (ty * 64 + tx) for ty, tx in zip(*np.nonzero(has))]
        lines.append("\t}, land = '%s'," % ",".join(landed))
        lines.append("\trow0 = %d, rows = {" % rows.min())
        for y in range(rows.min(), rows.max() + 1):
            lines.append("		'%s'," % runs_of(hit[y]))
        # the smaller places: a chunk's own area where it is not its zone's, inside what a zone is pointed at by
        own = continent_areas(store, map_id)
        small = np.where((hit > 0) & (own != base["zone"]) & (own != 0), own, 0)
        for a in np.unique(small):
            if a:
                area_names[int(a)] = names.get(int(a)) or ""
        lines.append("	}, areas = {")
        for y in range(rows.min(), rows.max() + 1):
            lines.append("		'%s'," % runs_of(small[y]))
        lines.append("	} },")
        print("  %d: %d smaller places" % (map_id, len(np.unique(small)) - 1))
        preview.save(os.path.join(WORLD, "globe_zones_%d.png" % map_id))
        print("  %d: %d zones, %d tiles with land" % (map_id, len(ids), len(landed)))
    lines.append("}")
    lines.append("ns.AREAS = {")
    for a in sorted(area_names):
        if area_names[a]:
            lines.append("	[%d] = %s," % (a, lua_text(area_names[a])))
    lines.append("}")
    path = os.path.join(ADDON, "Zones.lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    art_dir = os.path.join(ADDON, "Art")
    line_picture(art_dir)
    print("written Zones.lua (%d outline points, %d KB), Art/line.blp, world/globe_zones_<map>.png"
          % (points, os.path.getsize(path) // 1024))


def world():
    store = Storage(GAME, "wowf")
    rgba, layout, sea = world_picture(store)
    art_dir = os.path.join(ADDON, "Art")
    os.makedirs(art_dir, exist_ok=True)
    pieces, written = [], set()
    parents = area_parents(store)
    details = []
    tile = paper_tile(WORLD_H)
    places = {m: (plat, plon, cx, cy) for m, plat, plon, cx, cy in layout}
    for map_id in PLACE:
        details += continent_detail(map_id, continent_base(store, map_id, parents), art_dir, written, places[map_id], tile)
    inked = decor_pictures(art_dir, written)
    ring = ring_picture(art_dir, written)
    for j in range(WORLD_H // PIECE):
        for i in range(WORLD_W // PIECE):
            name = "world_%d_%d" % (j, i)
            write_blp(os.path.join(art_dir, name + ".blp"), rgba[j * PIECE:(j + 1) * PIECE, i * PIECE:(i + 1) * PIECE])
            written.add(name + ".blp")
            lon0 = -np.pi + i * PIECE / WORLD_W * 2 * np.pi
            lat0 = np.pi / 2 - j * PIECE / WORLD_H * np.pi
            pieces.append((name, lon0, lon0 + PIECE / WORLD_W * 2 * np.pi, lat0, lat0 - PIECE / WORLD_H * np.pi))
    line_picture(art_dir)
    written.add("line.blp")
    for old in os.listdir(art_dir):                          # (pictures no longer made)
        if old.endswith(".blp") and old not in written:
            os.remove(os.path.join(art_dir, old))
    Image.fromarray(rgba[..., :3]).resize((1024, 512), Image.LANCZOS).save(os.path.join(WORLD, "globe_world.png"))
    lines = ["-- Globe (Thread): its own pictures of the world, and how the world is laid on the globe. Written by",
             "-- tools/globe_art.py (python globe_art.py world).",
             "local ADDON, ns = ...", "",
             "-- rw: yards of the world to a radian of the globe; sea: its colour; each continent's middle on the",
             "-- globe (latitude, longitude, radians) and in its own terrain tiles (column, row)",
             "ns.LAYOUT = { rw = %d, sea = { %.3f, %.3f, %.3f }, continents = {" % (RW, sea[0], sea[1], sea[2])]
    for map_id, plat, plon, cx, cy in layout:
        lines.append("\t[%d] = { lat = %.4f, lon = %.4f, cx = %.6f, cy = %.6f }," % (map_id, plat, plon, cx, cy))
    lines += ["} }", "",
              "-- the whole world in pieces: each a picture, and the longitudes and latitudes it covers (west to east,",
              "-- north to south)",
              "ns.ART = {"]
    for name, l0, l1, a0, a1 in pieces:
        lines.append("\t{ file = 'Interface\\\\AddOns\\\\' .. ADDON .. '\\\\Art\\\\%s', kind = 'world', lon = { %.6f, %.6f }, lat = { %.6f, %.6f } },"
                     % (name, l0, l1, a0, a1))
    lines.append("")
    lines.append("\t-- each continent in detail (8 yards a pixel): a picture, its map and the terrain tiles it covers")
    for name, map_id, c0, c1, r0, r1 in details:
        lines.append("\t{ file = 'Interface\\\\AddOns\\\\' .. ADDON .. '\\\\Art\\\\%s', kind = 'detail', map = %d, columns = { %d, %d }, rows = { %d, %d } },"
                     % (name, map_id, c0, c1, r0, r1))
    if inked:
        lines.append("")
        lines.append("\t-- the hand-made ink pieces on the open sea: a picture, its middle (latitude, longitude), how far")
        lines.append("\t-- across it is (radians); flip: turned to face the other way")
        for _kind, source, flip, dlat, dlon, size in inked:
            lines.append("\t{ file = 'Interface\\\\AddOns\\\\' .. ADDON .. '\\\\Art\\\\decor_%s', kind = 'decor', lat = %.4f, lon = %.4f, size = %.4f%s },"
                         % (source, dlat, dlon, size, ", flip = true" if flip else ""))
    lines.append("}")
    if ring:
        lines += ["",
                  "-- the brass ring round the ball, and its stand where the picture has one: in parts of the picture's side, the middle of its hole (across",
                  "-- and down), the hole's radius, and the top and bottom of what is drawn",
                  "ns.RING = { file = 'Interface\\\\AddOns\\\\' .. ADDON .. '\\\\Art\\\\ring', cx = 0.5, cy = %.4f, inner = %.4f, top = %.4f, bottom = %.4f }" % ring]
    with open(os.path.join(ADDON, "Art.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("written %d world and %d detail pictures, Art.lua, world/globe_world.png; sea %s"
          % (len(pieces), len(details), tuple(round(float(c), 3) for c in sea)))
    print("hand-made: paper %s, ink pieces %s, ring %s"
          % ("laid in" if tile is not None else "not there",
             ", ".join(s[1] + (" (turned)" if s[2] else "") for s in inked) or "none", "made" if ring else "not there"))


def test():
    store = Storage(GAME, "wowf")
    map_id, columns, rows, size, name = 1, (33, 41), (30, 38), 512, "test_kalimdor"
    world = load(os.path.join(WORLD, "map_%d.bin" % map_id), walls=False)       # (the terrain alone: the globe paints land, not buildings)
    kinds, heights = cells_region(world, columns, rows)
    wanted = [(tx, ty) for tx in range(*columns) for ty in range(*rows)]
    areas = chunk_areas(store, map_files(store)[map_id], wanted)
    parents = area_parents(store)
    zones = np.zeros(kinds.shape, dtype=np.uint32)
    for (tx, ty), grid in areas.items():
        z = np.vectorize(lambda a: zone_of(int(a), parents))(grid).astype(np.uint32)
        x0, y0 = (tx - columns[0]) * 128, (ty - rows[0]) * 128
        zones[y0:y0 + 128, x0:x0 + 128] = np.kron(z, np.ones((8, 8), dtype=np.uint32))
    print("zones in it:", sorted(set(np.unique(zones).tolist()) - {0}))
    rgba = paint(kinds, heights, zones, size)
    Image.fromarray(rgba[..., :3]).save(os.path.join(WORLD, "globe_%s.png" % name))
    print("written world/globe_%s.png (a preview; the globe's pictures come from: python globe_art.py world)" % name)


if __name__ == "__main__":
    if sys.argv[1:] == ["test"]:
        test()
    elif sys.argv[1:] == ["world"]:
        world()
    elif sys.argv[1:] == ["zones"]:
        zones()
    else:
        print(__doc__)
