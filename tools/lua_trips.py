"""Run the addon's planner (Lua) on the packed map data, here, and compare it with the Python prototype.

    python lua_trips.py 1 horde        python lua_trips.py 0 alliance        python lua_trips.py 1
    python lua_trips.py 1 horde roads  with the search option `roads` (keep to the roads), in both planners
    python lua_trips.py 1 penalty      with a penalty (3 times the cost of entering a gate within PENALTY_YARDS
                                       of a spot on each map), in both planners; both words may be given

The same test trips as trips.py. For each: the Lua planner's cost against the prototype's, and whether
they fly the same flights. The Lua runs in a real Lua 5.1 (the game's version) through lupa.
"""
import os
import sys
import time

import flights as flight_data
from nav import Ground, Coarse, route, cell_of, nearest_passable, flown, cells_of, swimming
from pack import ADDONS, NAMES
from trips import PLACES, TRIPS, seconds_of

try:
    from lupa.lua51 import LuaRuntime
    LUA = "Lua 5.1"
except ImportError:                                     # no plain 5.1 in this lupa: LuaJIT speaks the same language
    from lupa import LuaRuntime
    LUA = "LuaJIT"


def planner(map_id):
    lua = LuaRuntime(unpack_returned_tuples=True)
    folder = os.path.join(ADDONS, "PatchwerkForever_Thread_Routes_" + NAMES[map_id])
    started = time.perf_counter()
    for line in open(os.path.join(folder, "PatchwerkForever_Thread_Routes_%s.toc" % NAMES[map_id]), encoding="utf-8"):
        line = line.strip()
        if line.endswith(".lua"):
            with open(os.path.join(folder, line), encoding="ascii") as f:
                lua.execute(f.read())
    loaded = time.perf_counter() - started
    with open(os.path.join(ADDONS, "PatchwerkForever_Thread_Routes", "Planner.lua"), encoding="utf-8") as f:
        ns = lua.table()
        lua.eval("function(code, name, ns) return assert(loadstring(code, name))(name, ns) end")(f.read(), "PatchwerkForever_Thread_Routes", ns)
    return lua, ns.Planner, loaded


# the penalty's spot on each map (world x, y): between Crossroads and Ratchet; on the road from Kharanos to Ironforge
PENALTY_AT = {1: (-700.0, -3150.0), 0: (-5300.0, -650.0), 2991: (0.0, 0.0)}
PENALTY_YARDS, PENALTY = 400.0, 3.0


def main(map_id, side=None, roads=False, penalty=False):
    lua, P, loaded = planner(map_id)
    print("%s; the map's data read in %.2f s; memory after reading: %.1f MB" % (LUA, loaded, lua.eval("collectgarbage('count')") / 1024))
    ground = Ground("world/map_%d.bin" % map_id)
    coarse = Coarse.open("world/nav_%d_linked.bin" % map_id)
    flights = None
    if side:
        flights = flight_data.load()
        coarse.add_flights(ground, flights, side)
    opts = lua.table_from({"side": side[0].upper()}) if side else lua.table()
    pfun = None
    if roads:
        opts.roads = True
        print("with roads: the data %s them" % ("has" if P.HasRoads(map_id) else "DOES NOT HAVE"))
    if penalty:
        px, py = PENALTY_AT[map_id]

        def pfun(x, y):
            return PENALTY if (x - px) ** 2 + (y - py) ** 2 < PENALTY_YARDS ** 2 else 1.0
        opts.penalty = lua.eval("function(px, py, r, m) return function(map, x, y) "
                                "if (x - px) ^ 2 + (y - py) ^ 2 < r ^ 2 then return m end return 1 end end")(
            px, py, PENALTY_YARDS, PENALTY)
    worst, slowest, differ = 0.0, 0.0, 0
    for a, b in TRIPS[map_id]:
        ca = nearest_passable(ground, *cell_of(*PLACES[map_id][a]))
        cb = nearest_passable(ground, *cell_of(*PLACES[map_id][b]))
        want = route(ground, coarse, ca, cb, roads=roads, penalty=pfun)
        started = time.perf_counter()
        got = P.Route(map_id, ca[0], ca[1], cb[0], cb[1], opts)
        took = time.perf_counter() - started
        slowest = max(slowest, took)
        if not want or not got:
            same = (not want) == (not got)
            differ += not same
            print("  %s -> %s: %s" % (a, b, "no way, both" if same else "DIFFERENT: prototype %s, Lua %s" % (bool(want), bool(got))))
            continue
        started = time.perf_counter()
        line = P.Line(map_id, ca[0], ca[1], cb[0], cb[1], got)
        drew = time.perf_counter() - started
        slowest = max(slowest, took + drew)
        off = max(abs(got.cost - want["cost"]) / want["cost"], abs(got.real - want["real"]) / want["real"]) * 100
        worst = max(worst, off)
        mine = [list(f.values()) for f in line.flown.values()]
        theirs = flown(coarse, want)
        path = cells_of(ground, coarse, ca, cb, want, roads)
        swum = swimming(ground, path)[0]
        flies = "" if not mine else "; flies " + "; ".join(" > ".join(P.PointName(map_id, i).split(",")[0] for i in f) for f in mine)
        bad = "" if mine == theirs else "   DIFFERENT FLIGHTS: prototype %s" % theirs
        differ += bool(bad) or off > 1.0
        weighed = "" if abs(got.cost - got.real) < 0.05 else " (weighed at %.1f)" % got.cost
        print("  %s -> %s: Lua %.1f s%s, prototype %.1f s (%.2f%% apart); %.1f min, walks %.0f yd%s; %d gates, %d points to draw; search %.0f ms, line %.0f ms%s" % (
            a, b, got.real, weighed, want["real"], off, line.seconds / 60.0, line.yards, flies, got.expanded, len(line.points), took * 1000, drew * 1000, bad))
        if abs(line.seconds - seconds_of(want, swum)) > 0.02 * seconds_of(want, swum) + 5 and not mine:
            print("      time differs: Lua %.0f s, prototype %.0f s" % (line.seconds, seconds_of(want, swum)))
    print("largest difference in cost %.2f%%; slowest trip %.0f ms; trips that differ: %d; memory now %.1f MB" % (
        worst, slowest * 1000, differ, lua.eval("collectgarbage('count')") / 1024))


if __name__ == "__main__":
    words = sys.argv[2:]
    sides = [w for w in words if w in ("horde", "alliance")]
    main(int(sys.argv[1]), sides[0] if sides else None, "roads" in words, "penalty" in words)
