"""Boats and zeppelins, from the game's own tables.

    python crossings.py         writes world/crossings.bin and prints what it found
    python crossings.py names   names the stops of world/crossings.bin again (from world/flights.bin and
                                NAMES below), without reading the game; then: python pack.py crossings

A boat or a zeppelin follows a line kept in TaxiPathNode like a flight's, round and round. The points
where it stops are flagged (2) and say how long it waits. A line can change map on the way: that is the
crossing to another continent.

What the tables do not say, and is guessed here:
  how fast it goes       SPEED yards a second
  when it comes          taken as half its round trip, the wait on average
  which side may use it  the side of the flight point nearest each stop
  what a stop is called  the town of the flight point nearest it ("Ratchet"), "near" a town a little
                         further off ("near Gadgetzan"), or else the continent ("Zephras Isle"); a name
                         seen in the game goes in NAMES and comes first
  where you board        the nearest walkable ground to the stop (a dock and a tower are buildings, which
                         the planner does not walk on), with the walk along the dock or the climb up the
                         tower allowed for
  whether it runs        the tables hold lines the game no longer uses; the ones left out are in LEFT_OUT

world/crossings.bin (a pickle): [{"id", "kind", "sides", "wait",
    "stops": [{"map", "x", "y", "z", "name", "cell", "board"}],
    "rides": {(from stop, to stop): {"seconds", "line": [(map, x, y), ...]}}}]
"""
import math
import os
import pickle
import struct
import sys

from nav import BLOCK, CELL, CLIMB_RUN, SPEED as RUN, Coarse, Ground, _spread, cell_of
from world import WALK

POINTS = 1000437                 # TaxiPathNode
SPEED = 30.0                     # yards a second, a guess
LOADING = 15.0                   # seconds for the loading screen between continents
REACH = 60                       # cells searched for ground to board from: 250 yards
TOWER = 12.0                     # a stop this far above the ground is up a tower
NEAR, NAMED = 1500.0, 700.0      # yards to a flight point for its side to count, and for its name
BESIDE = 300.0                   # flight points this much further than the nearest count with it (one a side)
JUMP = 1000.0                    # yards between two points of a line that it does not sail: it is moved
# lines left out: 295 is the old Menethil to Auberdine line (11167 runs there now, by way of Southshore),
# 436 is Naxxramas, 312 and 314 the flights into Alterac Valley
LEFT_OUT = {295, 436, 312, 314}
MAPS = (0, 1, 2991)
MAP_NAMES = {0: "Eastern Kingdoms", 1: "Kalimdor", 2991: "Zephras Isle"}
# stops named by hand, once their real names have been seen in the game: {(line id, stop index): "name"}
NAMES = {}


def _f(v):
    return struct.unpack("<f", struct.pack("<I", v & 0xffffffff))[0]


def lines(store):
    """Every line that stops at least twice: {id: [(map, x, y, z, stops here, seconds it waits)]}."""
    from db2 import Table
    points = {}
    for _rid, f in Table(store.read_fdid(POINTS)).rows():
        x, y, z = (_f(v) for v in f[0])
        points.setdefault(f[2], []).append((f[3], f[4], x, y, z, bool(f[5] & 2), f[6]))
    out = {}
    for pid, line in points.items():
        line.sort()
        if pid not in LEFT_OUT and sum(1 for p in line if p[5]) >= 2:
            out[pid] = [p[1:] for p in line]
    return out


def nearest_walk(ground, gx, gy, part, reach=REACH):
    """The walkable cell to board from: on the largest joined-up part of the map there is within reach (so
    not a beach under a cliff when the town above is in reach), and the nearest such."""
    gx, gy = int(gx), int(gy)
    best = None
    for dx in range(-reach, reach + 1):
        for dy in range(-reach, reach + 1):
            d = dx * dx + dy * dy
            if d <= reach * reach and ground.kind(gx + dx, gy + dy) == WALK:
                rank = part(gx + dx, gy + dy)
                if rank is not None and (best is None or (rank, d) < best[:2]):
                    best = (rank, d, gx + dx, gy + dy)
    return best and (best[2], best[3])


def parts(ground, coarse):
    """For a cell: which joined-up part of the map it can be walked to from (0 the largest), or None."""
    island, _sizes = coarse.islands()
    blocks = {}

    def part(x, y):
        block = (x // BLOCK, y // BLOCK)
        ranks = blocks.get(block)
        if ranks is None:
            ranks = blocks[block] = [None] * (BLOCK * BLOCK)
            rows = ground.block(*block)
            if rows is not None:
                for g in coarse.of_block.get(block, ()):
                    rank = island.get(g)
                    spread, _ = _spread(rows, coarse.nodes[g][2], coarse.nodes[g][3])
                    for i, d in enumerate(spread):
                        if d < float("inf") and (ranks[i] is None or rank < ranks[i]):
                            ranks[i] = rank
        return ranks[(y % BLOCK) * BLOCK + x % BLOCK]
    return part


def stop_name(pid, index, s, flights):
    """What a stop is called in the route summary (see the top of this file)."""
    if (pid, index) in NAMES:
        return NAMES[(pid, index)]
    near = sorted((math.hypot(n["x"] - s["x"], n["y"] - s["y"]), n["name"])
                  for n in flights["nodes"].values() if n["map"] == s["map"])
    if near and near[0][0] <= NAMED:
        return near[0][1].split(",")[0]
    if near and near[0][0] <= NEAR:
        return "near " + near[0][1].split(",")[0]
    return MAP_NAMES.get(s["map"], "a landing")


def build(all_lines, grounds, coarses, flights):
    out, notes = [], []
    part = {m: parts(grounds[m], coarses[m]) for m in grounds}
    for pid, line in sorted(all_lines.items()):
        at = [i for i, p in enumerate(line) if p[4]]
        # a line that begins and ends at the same stop names it twice
        stops, seen = [], {}
        for i in at:
            m, x, y, z = line[i][:4]
            key = (m, round(x / 20), round(y / 20))
            if key not in seen:
                seen[key] = len(stops)
                stops.append({"map": m, "x": x, "y": y, "z": z, "at": [i], "delay": line[i][5]})
            else:
                stops[seen[key]]["at"].append(i)
        if len(stops) < 2:
            continue
        sides, usable = None, True
        for index, s in enumerate(stops):
            ground = grounds.get(s["map"])
            if not ground:
                usable = False
                notes.append("line %d left out: a stop is on map %d, which the planner does not have" % (pid, s["map"]))
                break
            gx, gy = cell_of(s["x"], s["y"])
            cell = nearest_walk(ground, gx, gy, part[s["map"]])
            if not cell:
                usable = False
                notes.append("line %d left out: no ground within %d yards of its stop at (%.0f, %.0f) on map %d" % (
                    pid, REACH * CELL, s["x"], s["y"], s["map"]))
                break
            heights = ground.heights[(cell[0] >> 7, cell[1] >> 7)]
            up = s["z"] - heights[(cell[1] & 127) * 128 + (cell[0] & 127)] / 10.0
            walk = math.hypot(cell[0] - gx, cell[1] - gy) * CELL
            s["cell"] = cell
            s["board"] = walk / RUN + (up * CLIMB_RUN / RUN if up > TOWER else 0.0)
            s["up"], s["walk"] = up, walk
            near = sorted((math.hypot(n["x"] - s["x"], n["y"] - s["y"]), n["name"], n["sides"])
                          for n in flights["nodes"].values() if n["map"] == s["map"])
            if near and near[0][0] <= NEAR:
                here = set()
                for d, _name, theirs in near:
                    if d <= near[0][0] + BESIDE:
                        here |= theirs
                sides = here if sides is None else sides & here
            s["name"] = stop_name(pid, index, s, flights)
        if not usable:
            continue
        if sides is None:
            sides = {"alliance", "horde"}
        if not sides:
            notes.append("line %d left out: its stops are on different sides' land" % pid)
            continue
        # the round trip: yards between points on the same map, and the waits
        n = len(line)

        def hop(i):
            a, b = line[i], line[(i + 1) % n]
            far = math.dist(a[1:4], b[1:4])
            return far / SPEED if a[0] == b[0] and far <= JUMP else LOADING

        period = sum(hop(i) for i in range(n)) + sum(s["delay"] for s in stops)
        rides = {}
        for a, sa in enumerate(stops):
            for b, sb in enumerate(stops):
                if a == b:
                    continue
                best = None
                for i in sa["at"]:
                    # along the line from this stop until the other comes up
                    seconds, k, pts = 0.0, i, [line[i][:3]]
                    while True:
                        seconds += hop(k)
                        k = (k + 1) % n
                        pts.append(line[k][:3])
                        if k in sb["at"]:
                            break
                        if line[k][4]:
                            seconds += line[k][5]          # a stop on the way: it waits there
                        if k == i:
                            seconds = None
                            break
                    if seconds is not None and (best is None or seconds < best[0]):
                        best = (seconds, pts)
                if best:
                    rides[(a, b)] = {"seconds": best[0], "line": best[1]}
        out.append({"id": pid, "kind": "zeppelin" if max(s["z"] for s in stops) > 20 else "boat",
                    "sides": sides, "wait": period / 2.0, "period": period,
                    "stops": [{k: s[k] for k in ("map", "x", "y", "z", "name", "cell", "board", "up", "walk")} for s in stops],
                    "rides": rides})
    return out, notes


def load(path="world/crossings.bin"):
    with open(path, "rb") as f:
        return pickle.load(f)


def rename():
    """The stops of world/crossings.bin named again, as build() names them, without the game's files."""
    import flights as flight_data
    found, flights = load(), flight_data.load()
    for t in found:
        for index, s in enumerate(t["stops"]):
            was, s["name"] = s["name"], stop_name(t["id"], index, s, flights)
            print("line %5d stop %d: %-28s%s" % (t["id"], index, s["name"], "" if was == s["name"] else "  (was %s)" % was))
    with open("world/crossings.bin", "wb") as f:
        pickle.dump(found, f, protocol=4)


def main():
    if sys.argv[1:] == ["names"]:
        return rename()
    from casc import Storage
    import flights as flight_data
    store = Storage(r"G:/Games/World of Warcraft", "wowf")
    grounds = {m: Ground("world/map_%d.bin" % m) for m in MAPS if os.path.exists("world/map_%d.bin" % m)}
    coarses = {m: Coarse.open("world/nav_%d_linked.bin" % m) for m in grounds}
    found, notes = build(lines(store), grounds, coarses, flight_data.load())
    with open("world/crossings.bin", "wb") as f:
        pickle.dump(found, f, protocol=4)
    for t in found:
        print("line %5d  %-8s %-15s round trip %3.0f s (wait %3.0f s)" % (
            t["id"], t["kind"], "+".join(sorted(t["sides"])), t["period"], t["wait"]))
        for i, s in enumerate(t["stops"]):
            print("      stop %d: map %4d (%6.0f, %6.0f, %4.0f) %-28s board from %3.0f yd off, %3.0f yd %s: %3.0f s" % (
                i, s["map"], s["x"], s["y"], s["z"], s["name"], s["walk"], abs(s["up"]), "up" if s["up"] > 0 else "down", s["board"]))
        for (a, b), ride in sorted(t["rides"].items()):
            print("      ride %d to %d: %3.0f s, %d points" % (a, b, ride["seconds"], len(ride["line"])))
    for note in notes:
        print(note)


if __name__ == "__main__":
    main()
