"""Routes on foot before and after a change of the map data: every flight point and test place to its nearest hubs.

    python sweep.py <old folder> [map ...]       the old folder holds map_<id>.bin, walls_<id>.bin, nav_<id>_linked.bin

For each map: each flight point (both sides) and each test place of trips.py, to the HUBS nearest it (the other
points and places within REACH yards, by straight line), routed on foot on the old data and on world/'s. Lists every
route that got more than 10% and 30 s longer, every one that was found before and is not now (a split), and every
one that got that much shorter (a way found again). Writes world/sweep_<id>.txt.
"""
import math
import os
import sys

import flights as flight_data
from nav import Ground, Coarse, route, cell_of, nearest_passable, world_of, _F
from trips import PLACES

HUBS, REACH = 6, 3000.0
GRID = 700.0                     # yards between sample spots over the whole map, and
CITY_GRID = 120.0                # within the cities (world X from, to, Y from, to)
CITIES = {0: [("Stormwind", -9000, -8300, 300, 1300), ("Ironforge", -5100, -4550, -1300, -700),
              ("Undercity", 1450, 1900, -50, 500), ("Booty Bay", -14550, -14150, 250, 650)],
          1: [("Orgrimmar", 1300, 2100, -4900, -4000), ("Thunder Bluff", -1500, -900, -300, 400),
              ("Darnassus", 9500, 10200, 1800, 2700)],
          2991: []}


def places_of(map_id, flights, ground):
    out = [(name, x, y) for name, (x, y) in PLACES.get(map_id, {}).items()]
    for i, n in flights["nodes"].items():
        if n["map"] == map_id:
            out.append(("fp " + n["name"].split(",")[0], n["x"], n["y"]))
    xs = [32 * 533.333 - (ty + 1) * 533.333 for (tx, ty) in ground.tiles] + [32 * 533.333 - ty * 533.333 for (tx, ty) in ground.tiles]
    ys = [32 * 533.333 - (tx + 1) * 533.333 for (tx, ty) in ground.tiles] + [32 * 533.333 - tx * 533.333 for (tx, ty) in ground.tiles]
    x = min(xs)
    while x < max(xs):
        y = min(ys)
        while y < max(ys):
            cell = nearest_passable(ground, *cell_of(x, y), reach=3)
            if cell:
                out.append(("grid (%.0f, %.0f)" % (x, y), x, y))
            y += GRID
        x += GRID
    for name, x0, x1, y0, y1 in CITIES.get(map_id, ()):
        x = x0
        while x <= x1:
            y = y0
            while y <= y1:
                if nearest_passable(ground, *cell_of(x, y), reach=2):
                    out.append(("%s (%.0f, %.0f)" % (name, x, y), x, y))
                y += CITY_GRID
            x += CITY_GRID
    return out


def main(old, map_id):
    flights = flight_data.load()
    sets = [(Ground(os.path.join(old, "map_%d.bin" % map_id)), Coarse.open(os.path.join(old, "nav_%d_linked.bin" % map_id))),
            (Ground("world/map_%d.bin" % map_id), Coarse.open("world/nav_%d_linked.bin" % map_id))]
    spots = places_of(map_id, flights, sets[1][0])
    pairs = set()
    for i, (a, ax, ay) in enumerate(spots):
        near = sorted((math.hypot(ax - bx, ay - by), j) for j, (b, bx, by) in enumerate(spots) if j != i)
        for d, j in near[:HUBS]:
            if d <= REACH:
                pairs.add((min(i, j), max(i, j)))
    worse, lost, better, same = [], [], [], 0
    for i, j in sorted(pairs):
        costs, ends = [], None
        for g, c in sets:
            s = nearest_passable(g, *cell_of(*spots[i][1:]), reach=12)
            t = nearest_passable(g, *cell_of(*spots[j][1:]), reach=12)
            if ends and all(_F[g.kind(*e)] for e in ends):
                s, t = ends                  # (the old data's cells, where they are still a way: a spot that snaps to
            ends = (s, t) if s and t else None   # another cell is not a change of the way)
            f = s and t and route(g, c, s, t)
            costs.append(f["cost"] if f else None)
        name = "%s -> %s" % (spots[i][0], spots[j][0])
        a, b = costs
        if a is not None and b is None:
            lost.append(name)
        elif a is not None and b > a * 1.1 and b > a + 30:
            worse.append((b - a, "%s: %.0f s -> %.0f s" % (name, a, b)))
        elif a is not None and b is not None and b < a / 1.1 and b < a - 30:
            better.append((a - b, "%s: %.0f s -> %.0f s" % (name, a, b)))
        elif a is None and b is not None:
            better.append((0, "%s: no way -> %.0f s" % (name, b)))
        else:
            same += 1
    lines = ["map %d: %d routes; within 10%% or 30 s: %d; longer: %d; lost: %d; shorter: %d" % (
        map_id, len(pairs), same, len(worse), len(lost), len(better))]
    lines += ["  LONGER " + t for _, t in sorted(worse, reverse=True)]
    lines += ["  LOST   " + t for t in lost]
    lines += ["  shorter " + t for _, t in sorted(better, reverse=True)]
    with open("world/sweep_%d.txt" % map_id, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))


if __name__ == "__main__":
    for arg in sys.argv[2:] or ["0", "1", "2991"]:
        main(sys.argv[1], int(arg))
