"""Pack the maps for the game: the data addons of Patchwerk Forever: Thread (Routes).

    python pack.py              packs maps 0, 1 and 2991, and the boats and zeppelins
    python pack.py crossings    only the boats and zeppelins (Crossings.lua, in the addon's own folder)

For each map, a folder beside the addon (loaded only when the character is on that map):

    PatchwerkForever_Thread_Routes_<Name>/Cells<n>.lua    what each ground cell is, a tile a string
    PatchwerkForever_Thread_Routes_<Name>/Graph<n>.lua    each block's gates and the walks between them, a block a string
    PatchwerkForever_Thread_Routes_<Name>/Extra.lua       the links (tunnels, bridges, lifts) and the flight paths

Everything large is text of 64 different characters ('>' to '}', a number 0 to 63 each), inside Lua
long brackets [=[ ... ]=], which the game reads fast and keeps as it is until a search needs it.

A tile's cells: runs of one kind (0 no way, 1 walk, 2 wade, 3 swim), row after row.
    one character  kind + 4 * length            for a run of 1 to 15
    three          kind, then length - 1 in two characters (low six bits first)   for a run up to 4096

A block's graph:
    1 character    how many gates
    2 a gate       row + 32 * column + 1024 * kind (low six bits first)
    2 characters   how many walks
    4 a walk       gate, gate, seconds * 20 in two characters

A gate on a block's edge joins the gate on the cell across the edge; that is not stored.
"""
import math
import os
import sys

import flights as flight_data
from nav import (Ground, Coarse, BLOCK, STEP, _F, _spread, flight_spot, cell_of,
                 BOARD, LAND, AIR_SPEED, SPEED, FACTOR)
from terrain import CELL, TILE
from world import NONE, WALK, STEEP, WADE, SWIM

# the repository's addons/ folder; the game's Interface/AddOns holds junctions to the folders in it
ADDONS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "addons"))
NAMES = {0: "EasternKingdoms", 1: "Kalimdor", 2991: "ZephrasIsle"}
TITLES = {0: "Eastern Kingdoms", 1: "Kalimdor", 2991: "Zephras Isle"}
KIND = {NONE: 0, STEEP: 0, WALK: 1, WADE: 2, SWIM: 3}
TICK = 0.05                      # seconds a unit of a walk's cost
FILE_BYTES = 1500000             # about this much a file


def c1(v):
    return chr(62 + v)


def c2(v):
    return chr(62 + (v & 63)) + chr(62 + (v >> 6))


def pack_cells(cells):
    """A tile's 16384 cells as runs."""
    kinds = bytes(KIND[k] for k in cells)
    out, i, n = [], 0, len(kinds)
    while i < n:
        k = kinds[i]
        j = i + 1
        while j < n and kinds[j] == k and j - i < 4096:
            j += 1
        length = j - i
        out.append(c1(k + 4 * length) if length <= 15 else c1(k) + c2(length - 1))
        i = j
    return "".join(out)


def pack_map(map_id, flights):
    ground = Ground("world/map_%d.bin" % map_id)
    coarse = Coarse.open("world/nav_%d_linked.bin" % map_id)
    nodes, edges = coarse.nodes, coarse.edges
    place = {}                                         # node -> (block key, index in its block)
    graph, far, odd = {}, [], 0
    for (bx, by), ids in coarse.of_block.items():
        for n, i in enumerate(ids):
            place[i] = (by * 256 + bx, n)
    for (bx, by), ids in coarse.of_block.items():
        assert len(ids) < 64
        text = [c1(len(ids))]
        for i in ids:
            _, _, r, c = nodes[i]
            text.append(c2(r + 32 * c + 1024 * KIND[ground.kind(bx * BLOCK + c, by * BLOCK + r)]))
        walks = []
        for n, i in enumerate(ids):
            for j, cost in edges[i].items():
                ob = nodes[j][:2]
                back = edges[j].get(i)
                if back is None or abs(back - cost) > 0.01:
                    # one way only (a drop): kept with the links, wherever its ends are
                    far.append((place[i][0], place[i][1], place[j][0], place[j][1], cost, 1))
                    continue
                if ob == (bx, by):
                    if i < j:
                        walks.append(c1(n) + c1(place[j][1]) + c2(min(4095, int(round(cost / TICK)))))
                    continue
                # the gate on the cell across the block's edge: found again in the game, not stored
                ax, ay = bx * BLOCK + nodes[i][3], by * BLOCK + nodes[i][2]
                ox, oy = ob[0] * BLOCK + nodes[j][3], ob[1] * BLOCK + nodes[j][2]
                across = abs(ax - ox) + abs(ay - oy) == 1
                plain = STEP * (_F[ground.kind(ax, ay)] + _F[ground.kind(ox, oy)]) / 2.0
                if across and abs(cost - plain) < 0.01:
                    continue
                if across:
                    odd += 1
                if i < j:
                    far.append((place[i][0], place[i][1], place[j][0], place[j][1], cost, 0))
        text.append(c2(len(walks)))
        text.extend(walks)
        graph[by * 256 + bx] = "".join(text)
    tiles = {}
    wanted = {(bx >> 2, by >> 2) for (bx, by) in coarse.of_block}
    for (tx, ty), cells in ground.tiles.items():
        if (tx, ty) in wanted:
            tiles[ty * 64 + tx] = pack_cells(cells)

    # flight points: where each stands, and the walk from there to its block's gates
    points, paths = [], []
    here = {i: n for i, n in flights["nodes"].items() if n["map"] == map_id}
    for i, n in sorted(here.items()):
        at, cell, why, climb, _note = flight_spot(ground, n)
        legs = []
        if cell:
            block = (cell[0] // BLOCK, cell[1] // BLOCK)
            spread, _ = _spread(ground.block(*block), cell[1] % BLOCK, cell[0] % BLOCK)
            for k, g in enumerate(coarse.of_block.get(block, ())):
                d = spread[nodes[g][2] * BLOCK + nodes[g][3]]
                if d < float("inf"):
                    legs.append((k, d))
        sides = ("A" if "alliance" in n["sides"] else "") + ("H" if "horde" in n["sides"] else "")
        points.append((i, n["name"], at[0], at[1], sides, bool(cell and legs), climb, legs))
    for (a, b), path in sorted(flights["paths"].items()):
        if a in here and b in here:
            paths.append((a, b, path["seconds"]))

    folder = os.path.join(ADDONS, "PatchwerkForever_Thread_Routes_" + NAMES[map_id])
    os.makedirs(folder, exist_ok=True)
    for name in os.listdir(folder):
        if name.endswith((".lua", ".toc")):
            os.remove(os.path.join(folder, name))
    head = ("-- Made by pack.py from the game's own files. Do not edit: run pack.py again.\n"
            "PatchwerkForever_Thread_RoutesData = PatchwerkForever_Thread_RoutesData or {}\n"
            "local M = PatchwerkForever_Thread_RoutesData[%d] or { cells = {}, graph = {} }\n"
            "PatchwerkForever_Thread_RoutesData[%d] = M\n" % (map_id, map_id))
    files, total = [], 0

    def write(name, body):
        nonlocal total
        with open(os.path.join(folder, name), "w", encoding="ascii", newline="\n") as f:
            f.write(head + body)
        files.append(name)
        total += len(head) + len(body)

    for kind, table in (("Cells", tiles), ("Graph", graph)):
        part, size, count = [], 0, 0
        for key in sorted(table):
            line = "t[%d]=[=[%s]=]\n" % (key, table[key])
            assert "]=]" not in table[key] and "=" not in table[key]
            part.append(line)
            size += len(line)
            if size >= FILE_BYTES:
                count += 1
                write("%s%d.lua" % (kind, count), "local t = M.%s\n" % kind.lower() + "".join(part))
                part, size = [], 0
        if part:
            count += 1
            write("%s%d.lua" % (kind, count), "local t = M.%s\n" % kind.lower() + "".join(part))

    extra = ["M.cell, M.tile, M.speed, M.tick = %r, %r, %r, %r\n" % (CELL, TILE, SPEED, TICK),
             "M.factor = { %r, %r, %r }\n" % (FACTOR[WALK], FACTOR[WADE], FACTOR[SWIM]),
             "M.air = { speed = %r, board = %r, land = %r }\n" % (AIR_SPEED, BOARD, LAND),
             "-- ways the ground does not show: { block, gate, block, gate, seconds }, with a 1 after them for\n"
             "-- one that only goes from the first to the second (a drop)\n", "M.links = {\n"]
    for a, an, b, bn, cost, oneway in far:
        extra.append("{%d,%d,%d,%d,%.2f%s},\n" % (a, an, b, bn, cost, ",1" if oneway else ""))
    extra.append("}\n-- flight points: { id, name, cell x, cell y, sides, walked to or not, seconds to climb to it, "
                 "{ gate, seconds, gate, seconds, ... } }\nM.points = {\n")
    for i, name, gx, gy, sides, walk, climb, legs in points:
        extra.append("{%d,%s,%d,%d,\"%s\",%s,%.1f,{%s}},\n" % (
            i, '"%s"' % name.replace('"', "'"), gx, gy, sides, "true" if walk else "false", climb,
            ",".join("%d,%.2f" % leg for leg in legs)))
    extra.append("}\n-- flights: { from, to, seconds }\nM.flights = {\n")
    for a, b, seconds in paths:
        extra.append("{%d,%d,%.1f},\n" % (a, b, seconds))
    extra.append("}\n")
    write("Extra.lua", "".join(extra))

    with open(os.path.join(folder, "PatchwerkForever_Thread_Routes_%s.toc" % NAMES[map_id]), "w", encoding="utf-8", newline="\n") as f:
        f.write("## Interface: 16001\n## Title: Thread (Routes) map: %s\n"
                "## Notes: Map data for Patchwerk Forever: Thread (Routes). Loaded by it when needed.\n"
                "## Author: Tyrone\n## Version: 0.14.0\n"
                # (the game's addon list shows it under the parent; without this line it stood apart)
                "## Group: PatchwerkForever\n"
                "## IconTexture: Interface\\AddOns\\PatchwerkForever_Thread_Routes\\Media\\icon\n"
                "## X-License: MIT (code); map data made from the game's own files\n"
                "## Dependencies: PatchwerkForever_Thread_Routes\n## LoadOnDemand: 1\n\n%s\n"
                % (TITLES[map_id], "\n".join(files)))
    print("map %d -> %s: %d tiles, %d blocks, %d links, %d flight points, %d flights; %d files, %.1f MB%s" % (
        map_id, os.path.basename(folder), len(tiles), len(graph), len(far), len(points), len(paths), len(files),
        total / 1e6, "; %d links between cells side by side" % odd if odd else ""))


def pack_crossings():
    """The boats and zeppelins (crossings.py) as a file of the addon itself: Crossings.lua."""
    import crossings
    found = crossings.load()
    out = ["-- Made by pack.py from the game's own files (the tools' crossings.py). Do not edit: run pack.py again.\n",
           "-- Boats and zeppelins. Each: id, kind, sides (A, H), wait (seconds, on average, before one comes),\n",
           "--   stops = { { map, name, world x, world y, cell x, cell y, seconds to board } },\n",
           "--   rides = { { from stop, to stop, seconds, { map, world x, world y, ... } } }\n",
           "-- In a ride's line a map of -1 is a jump: the next point is not sailed to.\n",
           "local ADDON, ns = ...\nns.Crossings = {\n"]
    for t in found:
        sides = ("A" if "alliance" in t["sides"] else "") + ("H" if "horde" in t["sides"] else "")
        out.append('{ id = %d, kind = "%s", sides = "%s", wait = %.0f,\n\tstops = {\n' % (t["id"], t["kind"], sides, t["wait"]))
        for st in t["stops"]:
            out.append('\t\t{ %d, "%s", %.1f, %.1f, %d, %d, %.0f },\n' % (
                st["map"], st["name"].replace('"', "'"), st["x"], st["y"], st["cell"][0], st["cell"][1], st["board"]))
        out.append("\t},\n\trides = {\n")
        for (a, b), ride in sorted(t["rides"].items()):
            flat, last = [], None
            for m, x, y in ride["line"]:
                if last and last[0] == m and math.hypot(last[1] - x, last[2] - y) > crossings.JUMP:
                    flat.append("-1,0,0")
                flat.append("%d,%.0f,%.0f" % (m, x, y))
                last = (m, x, y)
            out.append("\t\t{ %d, %d, %.0f, { %s } },\n" % (a + 1, b + 1, ride["seconds"], ", ".join(flat)))
        out.append("\t},\n},\n")
    out.append("}\n")
    path = os.path.join(ADDONS, "PatchwerkForever_Thread_Routes", "Crossings.lua")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(out))
    print("crossings -> Crossings.lua: %d lines, %d rides, %.1f KB" % (
        len(found), sum(len(t["rides"]) for t in found), os.path.getsize(path) / 1e3))


if __name__ == "__main__":
    flights = flight_data.load()
    for arg in (sys.argv[1:] or ["0", "1", "2991", "crossings"]):
        if arg == "crossings":
            pack_crossings()
        else:
            pack_map(int(arg), flights)
