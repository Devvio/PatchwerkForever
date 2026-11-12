"""Run the addon's journeys (Lua: walks joined by boats and zeppelins) and compare them with a plain reckoning here.

    python lua_journeys.py

For each test journey the addon's answer (Journey.lua, on the packed data of all three maps) is set against
every chain of up to two rides worked out one by one with the Python prototype's routes: no ordering, no
giving up early. The two must agree on the cost and on the rides taken.
"""
import itertools
import os
import sys
import time

import crossings as crossing_data
import flights as flight_data
from nav import Ground, Coarse, route, cell_of, nearest_passable
from pack import ADDONS, NAMES

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

MAIN = os.path.join(ADDONS, "PatchwerkForever_Thread_Routes")
MAPS = (0, 1, 2991)
# side, from (map, world x, world y), to, what it is
JOURNEYS = [
    ("horde", (1, -442, -2598), (0, 2250, 310), "Crossroads to Brill"),
    ("horde", (1, -442, -2598), (0, -12350, 170), "Crossroads to Grom'gol"),
    ("horde", (1, 1430, -4420), (0, -14300, 500), "Orgrimmar to Booty Bay"),
    ("horde", (0, 2250, 310), (0, -12350, 170), "Brill to Grom'gol"),
    ("horde", (1, -2330, -380), (2991, 1848, 569), "Bloodhoof Village to Zephras Isle"),
    ("horde", (0, -20, -900), (1, -950, -3700), "Tarren Mill to Ratchet"),
    ("horde", (1, -7140, -3790), (0, -6630, -2180), "Gadgetzan to Kargath"),
    ("horde", (1, -442, -2598), (1, -7140, -3790), "Crossroads to Gadgetzan (one map)"),
    ("alliance", (1, 8640, 840), (0, -5600, -480), "Rut'theran Village to Kharanos"),
    ("alliance", (0, -9460, 60), (1, -3700, -4400), "Goldshire to Theramore"),
    ("alliance", (1, 6440, 480), (0, -9460, 60), "Auberdine to Goldshire"),
    ("alliance", (1, -4400, 3300), (1, -4500, -780), "Feathermoon to Thalanaar"),
    ("alliance", (0, -850, -520), (1, 2740, -380), "Southshore to Astranaar"),
    ("alliance", (0, -9460, 60), (2991, 1900, 900), "Goldshire to Zephras Isle (no way for the Alliance)"),
]


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    for m in MAPS:
        folder = os.path.join(ADDONS, "PatchwerkForever_Thread_Routes_" + NAMES[m])
        for line in open(os.path.join(folder, "PatchwerkForever_Thread_Routes_%s.toc" % NAMES[m]), encoding="utf-8"):
            if line.strip().endswith(".lua"):
                with open(os.path.join(folder, line.strip()), encoding="ascii") as f:
                    lua.execute(f.read())
    ns = lua.table()
    load = lua.eval("function(code, name, ns) return assert(loadstring(code, name))(name, ns) end")
    for name in ("Planner.lua", "Crossings.lua", "Journey.lua"):
        with open(os.path.join(MAIN, name), encoding="utf-8") as f:
            load(f.read(), "PatchwerkForever_Thread_Routes", ns)
    return lua, ns


def main():
    lua, ns = runtime()
    P = ns.Planner
    flights = flight_data.load()
    found = crossing_data.load()
    grounds = {m: Ground("world/map_%d.bin" % m) for m in MAPS}
    coarses = {}
    for side in ("horde", "alliance"):
        for m in MAPS:
            c = Coarse.open("world/nav_%d_linked.bin" % m)
            c.add_flights(grounds[m], flights, side)
            coarses[(side, m)] = c
    walks = {}

    def walk(side, m, a, b):
        if a == b:
            return 0.0
        key = (side, m, a, b)
        if key not in walks:
            got = route(grounds[m], coarses[(side, m)], a, b)
            walks[key] = got["cost"] if got else None
        return walks[key]

    differ, worst = 0, 0.0
    for side, start, goal, what in JOURNEYS:
        a = (start[0], nearest_passable(grounds[start[0]], *cell_of(start[1], start[2])))
        b = (goal[0], nearest_passable(grounds[goal[0]], *cell_of(goal[1], goal[2])))
        # the plain reckoning: every chain of none, one or two rides
        rides = []
        for t in found:
            if side in t["sides"]:
                for (i, j), ride in t["rides"].items():
                    s, e = t["stops"][i], t["stops"][j]
                    cost = round(t["wait"]) + round(ride["seconds"]) + round(s["board"]) + round(e["board"])
                    rides.append((t["id"], s, e, cost))
        best = None
        chains = [()] + [(r,) for r in rides] + [c for c in itertools.permutations(rides, 2) if c[0][0] != c[1][0]]
        for chain in chains:
            at, total, ok = a, 0.0, True
            for _id, s, e, cost in chain:
                if s["map"] != at[0]:
                    ok = False
                    break
                w = walk(side, at[0], at[1], tuple(s["cell"]))
                if w is None:
                    ok = False
                    break
                total += w + cost
                at = (e["map"], tuple(e["cell"]))
            if not ok or at[0] != b[0]:
                continue
            w = walk(side, at[0], at[1], b[1])
            if w is None:
                continue
            total += w
            if best is None or total < best[0]:
                best = (total, [r[0] for r in chain])
        # the addon's
        letter = side[0].upper()
        opts = lua.table_from({"rides": ns.Crossings, "side": letter,
                               "walk": lua.eval("function(side) return function() return { side = side } end end")(letter)})
        started = time.perf_counter()
        got = P.Journey(lua.table_from({"map": a[0], "x": a[1][0], "y": a[1][1]}),
                        lua.table_from({"map": b[0], "x": b[1][0], "y": b[1][1]}), opts)
        took = time.perf_counter() - started
        if not best or not got:
            same = (not best) == (not got)
            differ += not same
            print("  %s (%s): %s" % (what, side, "no way, both" if same else "DIFFERENT: here %s, the addon %s" % (best, bool(got))))
            continue
        line = P.JourneyLine(got)
        taken = [leg.crossing.id for leg in got.legs.values() if leg.kind == "ride"]
        off = abs(got.cost - best[0]) / best[0] * 100
        worst = max(worst, off)
        bad = "" if (taken == best[1] and off < 1.0) else "   DIFFERENT: here %.0f s by %s" % (best[0], best[1])
        differ += bool(bad)
        said = "; ".join("%s %s > %s" % (r.kind, r["from"], r.to) for r in line.rides.values()) or "no ride"
        flown = "; ".join("fly " + " > ".join(f.values()) for f in line.flown.values())
        parts = ", ".join("map %d: %d points" % (p.map, len(p.points)) for p in line.parts.values())
        print("  %s (%s): %.1f min; %s%s; walks %.0f yd; %s; %.0f ms%s" % (
            what, side, line.seconds / 60.0, said, ("; " + flown) if flown else "", line.yards, parts, took * 1000, bad))
    print("largest difference in cost %.2f%%; journeys that differ: %d; routes worked out here: %d" % (worst, differ, len(walks)))
    return differ


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
