"""Thread (Globe)'s own pictures of the world, in the look of the world map on parchment, made from the
game's terrain (GLOBE-BLUEPRINT.md, milestone G2: the tools and one test picture).

    python globe_art.py world       the whole world (G3): one picture, 2048 x 1024, longitude across and latitude
                                    down, written as 8 pieces of 512 (Art/world_<row>_<column>.blp) with Art.lua
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
    paper                  a soft grain over everything
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
from PIL import Image

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
ART_IN = os.path.join(HERE, "..", "art", "PatchwerkForever_Thread_Globe")
# the hand-made ink pieces on the open sea: (file, latitude, longitude, size in pixels)
DECOR = [("compass.png", 0.62, 0.0, 150), ("serpent.png", -0.30, 2.45, 170), ("ship.png", -0.40, -2.35, 140),
         ("serpent.png", 0.35, 3.05, 150), ("ship.png", -0.15, 0.55, 110)]


def continent_base(store, map_id, parents):
    """Each 33-yard chunk of a continent (1024 x 1024 for its 64 x 64 tiles): how wet, how high, its zone,
    whether there is terrain. Kept in world/globe_base_<id>.npz (reading every tile takes a while)."""
    path = os.path.join(WORLD, "globe_base_%d.npz" % map_id)
    if os.path.exists(path):
        return dict(np.load(path))
    world = load(os.path.join(WORLD, "map_%d.bin" % map_id))
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


def lay(picture, path, lat, lon, size):
    """An ink piece (dark on white) multiplied onto the world picture, its middle at lat, lon."""
    ink = Image.open(path).convert("L").resize((size, size), Image.LANCZOS)
    g = np.asarray(ink, dtype=np.float32) / 255
    h, w = picture.shape[:2]
    cx = int((lon + np.pi) / (2 * np.pi) * w)
    cy = int((np.pi / 2 - lat) / np.pi * h)
    x0, y0 = cx - size // 2, cy - size // 2
    for dy in range(size):
        y = y0 + dy
        if 0 <= y < h:
            xs = (x0 + np.arange(size)) % w
            picture[y, xs] *= g[dy][:, None]


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
        gyr, gxr = np.gradient(base["height"], 33.33)
        relief = np.clip(1 + 0.45 * (-gxr * 0.7 + gyr * 0.7) / np.sqrt(1 + gxr * gxr + gyr * gyr), 0.78, 1.18)
        land[sel] = base["water"][chy[sel], chx[sel]] < 0.5
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
    # the hand-made pieces, where they are made yet
    for name, dlat, dlon, size in DECOR:
        path = os.path.join(ART_IN, name)
        if os.path.exists(path):
            lay(picture, path, dlat, dlon, size)
    # the paper: the hand-made one tiled over the world, else a plain grain
    paper = os.path.join(ART_IN, "paper.png")
    if os.path.exists(paper):
        p = np.asarray(Image.open(paper).convert("L").resize((1024, 1024), Image.LANCZOS), dtype=np.float32)
        p = np.tile(p / p.mean(), (H // 1024 + 1, W // 1024 + 1))[:H, :W]
        picture = picture * (0.75 + 0.25 * p[..., None])
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


def style(land, zone, hgt, spacing, ripples, seed):
    """A region in the parchment look, as RGB bytes: land (bool), zone (ids), hgt (yards) a pixel apart by
    `spacing` yards; ripple lines `ripples` pixels out from the coast."""
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
    rng = np.random.default_rng(seed)
    grain = soft(rng.random(land.shape, dtype=np.float32), 1.2)
    picture *= (0.93 + 0.10 * grain)[..., None]
    del grain
    blotch = soft(rng.random(land.shape, dtype=np.float32), 18)
    picture *= (0.92 + 0.16 * blotch)[..., None]
    return np.clip(picture, 0, 255).astype(np.uint8)


def continent_detail(map_id, base, art_dir, written):
    """A continent painted whole at PER pixels a tile (so no seams), cut in BLOCK x BLOCK-tile pictures; those
    with no land within a tile of them are left out (the world picture's sea shows there)."""
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
    world = load(os.path.join(WORLD, "map_%d.bin" % map_id))
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
    del world
    rgb = style(land, zone, hgt, 1600 / 3 / PER, (3, 6, 9), seed=map_id + 11)
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


def world():
    store = Storage(GAME, "wowf")
    rgba, layout, sea = world_picture(store)
    art_dir = os.path.join(ADDON, "Art")
    os.makedirs(art_dir, exist_ok=True)
    pieces, written = [], set()
    parents = area_parents(store)
    details = []
    for map_id in PLACE:
        details += continent_detail(map_id, continent_base(store, map_id, parents), art_dir, written)
    for j in range(WORLD_H // PIECE):
        for i in range(WORLD_W // PIECE):
            name = "world_%d_%d" % (j, i)
            write_blp(os.path.join(art_dir, name + ".blp"), rgba[j * PIECE:(j + 1) * PIECE, i * PIECE:(i + 1) * PIECE])
            written.add(name + ".blp")
            lon0 = -np.pi + i * PIECE / WORLD_W * 2 * np.pi
            lat0 = np.pi / 2 - j * PIECE / WORLD_H * np.pi
            pieces.append((name, lon0, lon0 + PIECE / WORLD_W * 2 * np.pi, lat0, lat0 - PIECE / WORLD_H * np.pi))
    for old in os.listdir(art_dir):                          # (pictures no longer made)
        if old.endswith(".blp") and old not in written:
            os.remove(os.path.join(art_dir, old))
    Image.fromarray(rgba[..., :3]).resize((1024, 512), Image.LANCZOS).save(os.path.join(WORLD, "globe_world.png"))
    lines = ["-- Thread (Globe): its own pictures of the world, and how the world is laid on the globe. Written by",
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
    lines.append("}")
    with open(os.path.join(ADDON, "Art.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("written %d world and %d detail pictures, Art.lua, world/globe_world.png; sea %s"
          % (len(pieces), len(details), tuple(round(float(c), 3) for c in sea)))


def test():
    store = Storage(GAME, "wowf")
    map_id, columns, rows, size, name = 1, (33, 41), (30, 38), 512, "test_kalimdor"
    world = load(os.path.join(WORLD, "map_%d.bin" % map_id))
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
    else:
        print(__doc__)
