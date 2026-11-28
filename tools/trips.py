"""Test trips over a map's coarse graph, drawn on its picture, and a picture of what connects to what.

    python trips.py 1        (Kalimdor)      python trips.py 0        (Eastern Kingdoms)
    python trips.py 1 horde                  the same trips with that side's flight paths as well
    python trips.py 1 roads                  the trips on foot twice: as before (white) and keeping to the roads
                                             (the search option `roads`: cyan, where it differs), the roads in yellow;
                                             world/trips_<id>_roads.png

Writes world/trips_<id>.png (the routes found, in white, on the ground picture) and
world/islands_<id>.png (each stretch of ground that is connected, in a colour of its own:
where two colours meet across a road, a bridge, tunnel or lift is missing from the data).

The graph with the links of links.py is used when it is there (world/nav_<id>_linked.bin); a link
taken is drawn in pink. A route that is mostly swimming is marked DOUBTFUL.

Place coordinates are approximate world coordinates (X north, Y west), snapped to the nearest
walkable cell.
"""
import sys
import time

import os

import math

import flights as flight_data
from nav import Ground, Coarse, route, cells_of, cell_of, world_of, nearest_passable, swimming, flown, BLOCK, FACTOR, SPEED
from terrain import CELL
from world import SWIM
from world import load, picture_rows
from terrain import write_png

PLACES = {
    1: {
        "Thunder Bluff (foot of the lift)": (-1380, 177),
        "Thunder Bluff (inn, on the bluff)": (-1299, 39),
        "Bloodhoof Village": (-2330, -380),
        "Camp Narache": (-2917, -257),
        "Crossroads": (-442, -2598),
        "Ratchet": (-956, -3754),
        "Razor Hill": (300, -4720),
        "Orgrimmar (front gate)": (1380, -4370),
        "Camp Taurajo": (-2380, -1940),
        "Gadgetzan": (-7140, -3790),
        "Astranaar": (2730, -430),
        "Auberdine": (6400, 500),
        "Everlook": (6720, -4670),
        "Feathermoon (Feralas mainland)": (-4400, 200),
    },
    0: {
        "Goldshire": (-9460, 60),
        "Stormwind (front gate)": (-9050, 430),
        "Sentinel Hill": (-10630, 1050),
        "Lakeshire": (-9230, -2200),
        "Darkshire": (-10560, -1160),
        "Booty Bay": (-14400, 500),
        "Kharanos": (-5600, -480),
        "Ironforge (front gate)": (-5040, -810),
        "Thelsamar": (-5350, -2950),
        "Menethil Harbor": (-3760, -760),
        "Southshore": (-840, -530),
        "Tarren Mill": (-10, -940),
        "Brill": (2250, 320),
        "Undercity (ruins)": (1880, 240),
        "Light's Hope Chapel": (2280, -5300),
    },
}
TRIPS = {
    1: [("Thunder Bluff (inn, on the bluff)", "Bloodhoof Village"),
        ("Thunder Bluff (foot of the lift)", "Bloodhoof Village"),
        ("Bloodhoof Village", "Camp Narache"),
        ("Bloodhoof Village", "Camp Taurajo"),
        ("Camp Taurajo", "Crossroads"),
        ("Crossroads", "Ratchet"),
        ("Crossroads", "Orgrimmar (front gate)"),
        ("Razor Hill", "Orgrimmar (front gate)"),
        ("Crossroads", "Astranaar"),
        ("Astranaar", "Auberdine"),
        ("Crossroads", "Gadgetzan"),
        ("Astranaar", "Everlook"),
        ("Camp Taurajo", "Feathermoon (Feralas mainland)"),
        ("Auberdine", "Gadgetzan")],
    0: [("Goldshire", "Stormwind (front gate)"),
        ("Goldshire", "Sentinel Hill"),
        ("Goldshire", "Lakeshire"),
        ("Goldshire", "Darkshire"),
        ("Darkshire", "Booty Bay"),
        ("Kharanos", "Ironforge (front gate)"),
        ("Kharanos", "Thelsamar"),
        ("Thelsamar", "Menethil Harbor"),
        ("Menethil Harbor", "Southshore"),
        ("Southshore", "Tarren Mill"),
        ("Tarren Mill", "Brill"),
        ("Brill", "Undercity (ruins)"),
        ("Brill", "Light's Hope Chapel"),
        ("Goldshire", "Kharanos"),
        ("Booty Bay", "Light's Hope Chapel")],
}
ISLAND_COLOURS = [(60, 170, 70), (230, 150, 40), (70, 130, 230), (200, 70, 200), (230, 220, 60), (60, 200, 200),
                  (230, 90, 90), (150, 110, 60), (170, 170, 250), (250, 170, 200)]


def seconds_of(found, swum):
    """A route's real time: its seconds (its cost without the roads' preference or a penalty), less what swimming is
    priced above its real slowness (1.5 times)."""
    return found.get("real", found["cost"]) - swum * (FACTOR[SWIM] - 1.5) / SPEED


def main(map_id, side=None):
    if side == "roads":
        return with_roads(map_id)
    ground = Ground("world/map_%d.bin" % map_id)
    linked = "world/nav_%d_linked.bin" % map_id
    coarse = Coarse.open(linked if os.path.exists(linked) else "world/nav_%d.bin" % map_id)
    air = flights = None
    if side:
        flights = flight_data.load()
        air = Coarse.open(linked if os.path.exists(linked) else "world/nav_%d.bin" % map_id)
        left = air.add_flights(ground, flights, side)
        print("%s flight points on this map: %d, of which %d can be walked to" % (side, len(air.air), len(air.air_cells)))
        for name, why in left:
            print("   %s: %s" % (name, why))
    print("map %d: %s%s" % (map_id, coarse.stats(), " (with links)" if os.path.exists(linked) else " (ground only)"))
    island, sizes = coarse.islands()
    print("connected stretches: %d; the ten largest hold %s gates" % (len(sizes), sizes[:10]))

    tiles = load("world/map_%d.bin" % map_id)["tiles"]
    rows, x0, y0, per = picture_rows(tiles)
    scale = 128 // per

    def pixel(gx, gy):
        return int(gx) // scale - x0 * per, int(gy) // scale - y0 * per

    def dot(gx, gy, colour, size=1):
        px, py = pixel(gx, gy)
        for y in range(py - size, py + size + 1):
            for x in range(px - size, px + size + 1):
                if 0 <= y < len(rows) and 0 <= x < len(rows[0]) // 3:
                    rows[y][x * 3: x * 3 + 3] = bytes(colour)

    cells, where = {}, {}
    for name, (wx, wy) in PLACES[map_id].items():
        cell = nearest_passable(ground, *cell_of(wx, wy))
        cells[name] = cell
        if cell:
            gates = coarse.of_block.get((cell[0] // BLOCK, cell[1] // BLOCK), [])
            where[name] = min((island[g] for g in gates), default=None)
    print("\nplaces, and the connected stretch each stands on (0 is the largest):")
    for name in PLACES[map_id]:
        print("  %-36s %s" % (name, "no walkable ground near" if not cells[name] else "stretch %s" % where[name]))

    print("\ntrips:")
    total_ms, found_count = 0.0, 0
    for a, b in TRIPS[map_id]:
        if not (cells[a] and cells[b]):
            print("  %s -> %s: a place has no ground" % (a, b))
            continue
        found = route(ground, coarse, cells[a], cells[b])
        best = air and route(ground, air, cells[a], cells[b])
        if best and flown(air, best) and (not found or best["cost"] < found["cost"] - 1):
            path = cells_of(ground, air, cells[a], cells[b], best)
            swum, yards, _ = swimming(ground, path)
            legs, in_air, air_yards = [], 0.0, 0.0
            for hops in flown(air, best):
                for p, q in zip(hops, hops[1:]):
                    in_air += flights["paths"][(p, q)]["seconds"]
                    air_yards += math.dist((flights["nodes"][p]["x"], flights["nodes"][p]["y"]),
                                           (flights["nodes"][q]["x"], flights["nodes"][q]["y"]))
                    line = [cell_of(x, y) for x, y in flights["paths"][(p, q)]["line"]]
                    for (x0_, y0_), (x1_, y1_) in zip(line, line[1:]):
                        steps = int(max(abs(x1_ - x0_), abs(y1_ - y0_)) / 4) + 1
                        for k in range(steps + 1):
                            dot(x0_ + (x1_ - x0_) * k / steps, y0_ + (y1_ - y0_) * k / steps, (90, 230, 255), 0)
                legs.append(" > ".join(flights["nodes"][i]["name"].split(",")[0] for i in hops))
            on_foot = "no way on foot" if not found else "on foot %.1f min" % (seconds_of(found, swimming(ground, cells_of(ground, coarse, cells[a], cells[b], found))[0]) / 60.0)
            print("  %s -> %s: %.1f min with flights (%s): walks %.0f yd, flies %s (%d:%02d in the air); %d gates searched, %.0f ms" % (
                a, b, seconds_of(best, swum) / 60.0, on_foot, max(0.0, yards - air_yards), "; then ".join(legs),
                in_air // 60, in_air % 60, best["expanded"], best["seconds"] * 1000))
            total_ms += best["seconds"] * 1000
            found_count += 1
            for gx, gy in path:
                dot(gx, gy, (255, 255, 255), 0)
            continue
        if not found:
            print("  %s -> %s: NO WAY (stretches %s and %s)" % (a, b, where[a], where[b]))
            continue
        total_ms += found["seconds"] * 1000
        found_count += 1
        path = cells_of(ground, coarse, cells[a], cells[b], found)
        swum, yards, doubtful = swimming(ground, path)
        jumps = [(p, q) for p, q in zip(path, path[1:]) if abs(p[0] - q[0]) > 1 or abs(p[1] - q[1]) > 1]
        print("  %s -> %s: %.0f yd, %.1f min%s%s, %d gates searched, %.0f ms%s" % (
            a, b, yards, seconds_of(found, swum) / 60.0,
            ", %d link(s)" % len(jumps) if jumps else "", ", swims %.0f yd" % swum if swum >= 1 else "",
            found["expanded"], found["seconds"] * 1000, "   DOUBTFUL: a long swim" if doubtful else ""))
        if doubtful:                                    # where the long swims are, to look at
            run = []
            for cell in path + [None]:
                if cell and ground.kind(*cell) == SWIM:
                    run.append(cell)
                    continue
                if len(run) * CELL >= 100:
                    print("      swims about %.0f yd from world (%.0f, %.0f) to (%.0f, %.0f)" % (
                        (len(run) * CELL,) + world_of(*run[0]) + world_of(*run[-1])))
                run = []
        for gx, gy in path:
            dot(gx, gy, (255, 255, 255), 0)
        for p, q in jumps:
            steps = max(abs(p[0] - q[0]), abs(p[1] - q[1]))
            for k in range(steps + 1):
                dot(p[0] + (q[0] - p[0]) * k / steps, p[1] + (q[1] - p[1]) * k / steps, (255, 90, 200), 1)
    if found_count:
        print("average search: %.0f ms (Python)" % (total_ms / found_count))
    for name, cell in cells.items():
        if cell:
            dot(cell[0], cell[1], (255, 235, 60), 3)
            dot(cell[0], cell[1], (0, 0, 0), 1)
    write_png("world/trips_%d%s.png" % (map_id, "_" + side if side else ""), len(rows[0]) // 3, len(rows), [bytes(r) for r in rows])
    if side:
        return

    # what connects to what: each block in the colour of its stretch
    rows2, _, _, _ = picture_rows(tiles)
    blocks_px = BLOCK // scale
    for (bx, by), gates in coarse.of_block.items():
        rank = min(island[g] for g in gates)
        if rank >= len(ISLAND_COLOURS) or sizes[rank] < 40:
            continue
        colour = ISLAND_COLOURS[rank]
        px0, py0 = bx * blocks_px - x0 * per, by * blocks_px - y0 * per
        for y in range(py0, py0 + blocks_px):
            for x in range(px0, px0 + blocks_px):
                if 0 <= y < len(rows2) and 0 <= x < len(rows2[0]) // 3:
                    r, g, b = rows2[y][x * 3: x * 3 + 3]
                    if (r, g, b) not in ((205, 45, 45), (30, 80, 170), (10, 10, 20)):       # keep cliffs, sea, void
                        rows2[y][x * 3: x * 3 + 3] = bytes(colour)
    write_png("world/islands_%d.png" % map_id, len(rows2[0]) // 3, len(rows2), [bytes(r) for r in rows2])


def with_roads(map_id):
    """The trips on foot as before and keeping to the roads, side by side in one picture."""
    ground = Ground("world/map_%d.bin" % map_id)
    coarse = Coarse.open("world/nav_%d_linked.bin" % map_id)
    tiles = load("world/map_%d.bin" % map_id)["tiles"]
    rows, x0, y0, per = picture_rows(tiles)
    scale = 128 // per

    def dot(gx, gy, colour, size=0):
        px, py = int(gx) // scale - x0 * per, int(gy) // scale - y0 * per
        for y in range(py - size, py + size + 1):
            for x in range(px - size, px + size + 1):
                if 0 <= y < len(rows) and 0 <= x < len(rows[0]) // 3:
                    rows[y][x * 3: x * 3 + 3] = bytes(colour)

    for (tx, ty), marks in ground.roads.items():
        for i in range(0, 16384):
            if marks[i]:
                dot(tx * 128 + i % 128, ty * 128 + i // 128, (150, 130, 30))
    print("trips on foot: as before | keeping to the roads (minutes, yards; then how much of the way is on a road)")
    for a, b in TRIPS[map_id]:
        ca = nearest_passable(ground, *cell_of(*PLACES[map_id][a]))
        cb = nearest_passable(ground, *cell_of(*PLACES[map_id][b]))
        plain = route(ground, coarse, ca, cb)
        kept = route(ground, coarse, ca, cb, roads=True)
        if not (plain and kept):
            print("  %s -> %s: no way" % (a, b))
            continue
        out = []
        for found, roads, colour in ((plain, False, (255, 255, 255)), (kept, True, (60, 230, 255))):
            path = cells_of(ground, coarse, ca, cb, found, roads)
            swum, yards, _ = swimming(ground, path)
            on = sum(math.hypot(q[0] - p[0], q[1] - p[1]) * CELL for p, q in zip(path, path[1:])
                     if ground.road(*p) and ground.road(*q))
            out.append("%.1f min, %.0f yd, %.0f%% on a road" % (seconds_of(found, swum) / 60.0, yards, 100.0 * on / max(1.0, yards)))
            for gx, gy in path:
                dot(gx, gy, colour)
        print("  %s -> %s: %s | %s" % (a, b, out[0], out[1]))
    for a in PLACES[map_id]:
        cell = nearest_passable(ground, *cell_of(*PLACES[map_id][a]))
        if cell:
            dot(cell[0], cell[1], (255, 235, 60), 3)
            dot(cell[0], cell[1], (0, 0, 0), 1)
    write_png("world/trips_%d_roads.png" % map_id, len(rows[0]) // 3, len(rows), [bytes(r) for r in rows])


if __name__ == "__main__":
    main(int(sys.argv[1]), sys.argv[2] if len(sys.argv) > 2 else None)
