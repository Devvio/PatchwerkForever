"""Flight paths, from the game's own tables.

    python flights.py           writes world/flights.bin and prints what it found

TaxiNodes     where each flight point is, which side uses it, its name
TaxiPath      which flight points are joined directly (one row each way)
TaxiPathNode  the line each of those flights follows, point by point

A flight's time is not in the tables. It is taken as the length of its line at
SPEED yards a second, the speed flight mounts fly at; a real flight is a few
percent longer (it follows a curve through the points). To be checked in-game.

world/flights.bin (a pickle): {"nodes": {id: {"name", "x", "y", "z", "map", "sides"}},
                               "paths": {(from id, to id): {"yards", "seconds", "line": [(x, y), ...]}}}
"""
import math
import pickle
import struct
import sys

from casc import Storage
from db2 import Table, texts

NODES, PATHS, POINTS = 1068100, 1067802, 1000437     # TaxiNodes, TaxiPath, TaxiPathNode
SPEED = 32.0                                          # yards a second


def _f(v):
    return struct.unpack("<f", struct.pack("<I", v & 0xffffffff))[0]


def read(store):
    table = Table(store.read_fdid(NODES))
    names = texts(table, 0)
    nodes = {}
    for record_id, f in table.rows():
        name = names.get(record_id, "")
        horde_mount, alliance_mount = f[14]
        # a flight point a character can learn has a bit number of its own; the rest are quest rides,
        # boats, test rows and rows kept from older versions
        if not f[7] or name.startswith(("zzOLD", "Quest Path", "Transport", "Generic")):
            continue
        sides = set()
        if horde_mount:
            sides.add("horde")
        if alliance_mount:
            sides.add("alliance")
        if not sides:
            continue
        x, y, z = (_f(v) for v in f[1])
        nodes[record_id] = {"name": name, "x": x, "y": y, "z": z, "map": f[5], "sides": sides}
    points = {}
    for _record_id, f in Table(store.read_fdid(POINTS)).rows():
        x, y, z = (_f(v) for v in f[0])
        points.setdefault(f[2], []).append((f[3], f[4], x, y, z))
    paths = {}
    for record_id, f in Table(store.read_fdid(PATHS)).rows():
        a, b = f[1], f[2]
        if a not in nodes or b not in nodes or a == b or not (nodes[a]["sides"] & nodes[b]["sides"]):
            continue
        line = sorted(points.get(record_id, ()))
        if len(line) < 2 or any(p[1] != nodes[a]["map"] for p in line):
            continue                                   # a flight that leaves the continent is not followed
        yards = sum(math.dist(p[2:5], q[2:5]) for p, q in zip(line, line[1:]))
        paths[(a, b)] = {"yards": yards, "seconds": yards / SPEED, "line": [(p[2], p[3]) for p in line]}
    return {"nodes": nodes, "paths": paths}


def load(path="world/flights.bin"):
    with open(path, "rb") as f:
        return pickle.load(f)


if __name__ == "__main__":
    store = Storage(r"G:/Games/World of Warcraft", "wowf")
    data = read(store)
    with open("world/flights.bin", "wb") as f:
        pickle.dump(data, f, protocol=4)
    nodes, paths = data["nodes"], data["paths"]
    for side in ("alliance", "horde"):
        mine = {i for i, n in nodes.items() if side in n["sides"]}
        print("%s: %d flight points, %d direct flights" % (side, len(mine), sum(1 for (a, b) in paths if a in mine and b in mine)))
    lonely = [n["name"] for i, n in nodes.items() if not any(i in key for key in paths)]
    print("flight points with no flight in the tables:", lonely or "none")
    print("some flights (yards, time at %.0f yd/s):" % SPEED)
    by_name = {}
    for i, n in nodes.items():
        by_name.setdefault(n["name"].split(",")[0], []).append(i)
    for a, b in (("Stormwind", "Ironforge"), ("Stormwind", "Sentinel Hill"), ("Orgrimmar", "Crossroads"),
                 ("Orgrimmar", "Thunder Bluff"), ("Thunder Bluff", "Crossroads"), ("Undercity", "Tarren Mill"),
                 ("Ironforge", "Menethil Harbor"), ("Auberdine", "Rut'theran Village")):
        for i in by_name.get(a, ()):
            for j in by_name.get(b, ()):
                p = paths.get((i, j))
                if p:
                    print("   %-14s -> %-20s %6.0f yd  %d:%02d" % (a, b, p["yards"], p["seconds"] // 60, p["seconds"] % 60))
