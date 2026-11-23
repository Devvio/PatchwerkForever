"""Check the smoothing of the route line (Planner.lua: P.Line), here, on the packed map data.

    python lua_smooth.py            every test trip of trips.py on maps 0 and 1, on foot and with each side's flights
    python lua_smooth.py 1 horde    one map, one side (or no side: on foot)

For each trip the line is made twice: as the search walked it (P.smooth = false) and smoothed. The smoothed
line fails the check if
  - a point every quarter cell along one of its walked stretches is on a cell that is no way, or on deep
    water with none of the unsmoothed path's swimming within NEAR cells;
  - its first or last point moved, or a link's or a flight's points changed;
  - its yards, swum, seconds or flights differ from the unsmoothed line's;
  - it swims more than the unsmoothed path did.
Reported, before and after: the number of points, the length of the walked stretches, and the turning (the
sum of the angles between one walked stretch and the next; and the sharpest of them, and how many are 30
degrees or more), and the slowest P.Line.

The ground is read with the Python prototype's own reader (nav.Ground), not through the Lua being checked.
"""
import math
import sys
import time

from nav import Ground, cell_of, nearest_passable, FACTOR
from terrain import CELL
from trips import PLACES, TRIPS
from world import SWIM
from lua_trips import planner

NEAR = 8            # cells: deep water this near to where the unsmoothed path swam is not "new" swimming
QUARTER = 0.25
MOST = 300          # points a line should stay under, about


def points_of(line):
    return [(p[1], p[2], p[3]) for p in line.points.values()]


def cells_walked(points):
    """The cells of the unsmoothed line's walked stretches, one after another."""
    cells = []
    for a, b in zip(points, points[1:]):
        if b[2] != "walk":
            continue
        dx, dy = b[0] - a[0], b[1] - a[1]
        steps = max(abs(dx), abs(dy))
        assert steps and (dx == 0 or dy == 0 or abs(dx) == abs(dy)), "the unsmoothed line is not on the grid: %s %s" % (a, b)
        for k in range(steps + 1):
            cells.append((a[0] + dx // steps * k, a[1] + dy // steps * k))
    return cells


def samples(points):
    """A place every quarter cell along each walked stretch: (x, y, the length it stands for)."""
    for a, b in zip(points, points[1:]):
        if b[2] != "walk":
            continue
        length = math.dist(a[:2], b[:2])
        n = max(1, math.ceil(length / QUARTER))
        for k in range(n + 1):
            yield a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n, length / (n + 1)


def measure(points):
    """Walked length in yards; total turning, sharpest turn (degrees); turns of 30 degrees or more."""
    length, turning, sharpest, sharp = 0.0, 0.0, 0.0, 0
    for i in range(1, len(points)):
        a, b = points[i - 1], points[i]
        if b[2] != "walk":
            continue
        length += math.dist(a[:2], b[:2]) * CELL
        if i + 1 < len(points) and points[i + 1][2] == "walk":
            c = points[i + 1]
            ux, uy, vx, vy = b[0] - a[0], b[1] - a[1], c[0] - b[0], c[1] - b[1]
            turn = abs(math.degrees(math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)))
            turning += turn
            sharpest = max(sharpest, turn)
            sharp += turn >= 30 - 1e-6
    return length, turning, sharpest, sharp


def ends_of(points):
    """What smoothing must leave alone: the first and last points, and each link or flight with the point before it."""
    kept = [points[0], points[-1]]
    for a, b in zip(points, points[1:]):
        if b[2] != "walk":
            kept += [a[:2], b]
    return kept


def check(ground, before, after):
    """The complaints about a smoothed line (none: good), the farthest a swum sample is from the path's
    swimming (cells), and the yards swum before and after."""
    wrong = []
    if ends_of(before) != ends_of(after):
        wrong.append("an end, a link or a flight moved")
    path = cells_walked(before)
    wet = {cell for cell in path if ground.kind(*cell) == SWIM}
    # (and where the unsmoothed line itself touches deep water: a step from one cell of a bridge's deck to the next
    # across their corner clips the water beside the bridge, which is no new swimming in the smoothed line)
    wet |= {(math.floor(x + 0.5), math.floor(y + 0.5)) for x, y, _length in samples(before)
            if ground.kind(math.floor(x + 0.5), math.floor(y + 0.5)) == SWIM}
    swum_before = sum(length for x, y, length in samples(before) if ground.kind(math.floor(x + 0.5), math.floor(y + 0.5)) == SWIM)
    how_far, swum_after, off, new = {}, 0.0, 0, 0
    farthest = 0.0
    for x, y, length in samples(after):
        cell = (math.floor(x + 0.5), math.floor(y + 0.5))
        kind = ground.kind(*cell)
        if kind not in FACTOR:
            off += 1
            if off <= 3:
                wrong.append("off the ground at cell (%.2f, %.2f)" % (x, y))
        elif kind == SWIM:
            swum_after += length
            if cell not in how_far:
                best = 99.0
                for r in range(0, 33):
                    if r > best:
                        break
                    for dx in range(-r, r + 1):
                        for dy in ((-r, r) if abs(dx) < r else range(-r, r + 1)):
                            if (cell[0] + dx, cell[1] + dy) in wet:
                                best = min(best, math.hypot(dx, dy))
                how_far[cell] = best
            farthest = max(farthest, how_far[cell])
            if how_far[cell] > NEAR:
                new += 1
                if new <= 3:
                    wrong.append("deep water at cell (%.2f, %.2f), %s from where the path swam" % (
                        x, y, "over 32 cells" if how_far[cell] > 32 else "%.1f cells" % how_far[cell]))
    if off > 3:
        wrong.append("... off the ground at %d places in all" % off)
    if new > 3:
        wrong.append("... new deep water at %d places in all" % new)
    if swum_after > swum_before * 1.02 + 2:
        wrong.append("swims more: %.0f yd, the unsmoothed path %.0f yd" % (swum_after * CELL, swum_before * CELL))
    return wrong, farthest, swum_before * CELL, swum_after * CELL


def run(map_id, sides, total):
    lua, P, _ = planner(map_id)
    ground = Ground("world/map_%d.bin" % map_id)
    for side in sides:
        print("\nmap %d, %s" % (map_id, "with %s flights" % side if side else "on foot"))
        opts = lua.table_from({"side": side[0].upper()}) if side else lua.table()
        for a, b in TRIPS[map_id]:
            ca = nearest_passable(ground, *cell_of(*PLACES[map_id][a]))
            cb = nearest_passable(ground, *cell_of(*PLACES[map_id][b]))
            found = P.Route(map_id, ca[0], ca[1], cb[0], cb[1], opts)
            if not found:
                print("  %s -> %s: no way" % (a, b))
                continue
            P.smooth = False
            started = time.perf_counter()
            plain = P.Line(map_id, ca[0], ca[1], cb[0], cb[1], found)
            plain_ms = (time.perf_counter() - started) * 1000
            P.smooth = True
            started = time.perf_counter()
            smooth = P.Line(map_id, ca[0], ca[1], cb[0], cb[1], found)
            smooth_ms = (time.perf_counter() - started) * 1000
            before, after = points_of(plain), points_of(smooth)
            wrong, farthest, swum_before, swum_after = check(ground, before, after)
            for key in ("yards", "swum", "seconds"):
                if plain[key] != smooth[key]:
                    wrong.append("%s changed: %r, was %r" % (key, smooth[key], plain[key]))
            if [list(f.values()) for f in plain.flown.values()] != [list(f.values()) for f in smooth.flown.values()]:
                wrong.append("the flights changed")
            m0, m1 = measure(before), measure(after)
            print("  %s -> %s: points %d > %d; walked line %.0f > %.0f yd; turning %.0f > %.0f deg, sharpest %.0f > %.0f, "
                  "turns of 30+ %d > %d; swims %.0f > %.0f yd%s; line %.0f > %.0f ms" % (
                      a, b, len(before), len(after), m0[0], m1[0], m0[1], m1[1], m0[2], m1[2], m0[3], m1[3],
                      swum_before, swum_after, " (at most %.1f cells from the path's)" % farthest if farthest else "",
                      plain_ms, smooth_ms))
            for text in wrong:
                print("      WRONG: " + text)
            total["trips"] += 1
            total["bad"] += bool(wrong)
            total["points"][0] += len(before); total["points"][1] += len(after)
            total["yards"][0] += m0[0]; total["yards"][1] += m1[0]
            total["turning"][0] += m0[1]; total["turning"][1] += m1[1]
            total["sharp"][0] += m0[3]; total["sharp"][1] += m1[3]
            total["sharpest"] = [max(total["sharpest"][0], m0[2]), max(total["sharpest"][1], m1[2])]
            total["most"] = [max(total["most"][0], len(before)), max(total["most"][1], len(after))]
            total["slowest"] = [max(total["slowest"][0], plain_ms), max(total["slowest"][1], smooth_ms)]
            total["farthest"] = max(total["farthest"], farthest)


def main(argv):
    total = {"trips": 0, "bad": 0, "points": [0, 0], "yards": [0.0, 0.0], "turning": [0.0, 0.0], "sharp": [0, 0],
             "sharpest": [0.0, 0.0], "most": [0, 0], "slowest": [0.0, 0.0], "farthest": 0.0}
    if argv:
        run(int(argv[0]), [argv[1] if len(argv) > 1 else None], total)
    else:
        for map_id in (1, 0):
            run(map_id, [None, "horde", "alliance"], total)
    print("\n%d trips, before > after smoothing:" % total["trips"])
    print("  points            %d > %d   (the most in one line: %d > %d%s)" % (
        total["points"][0], total["points"][1], total["most"][0], total["most"][1],
        "" if total["most"][1] <= MOST else ", OVER %d" % MOST))
    print("  walked line       %.0f > %.0f yd" % tuple(total["yards"]))
    print("  turning           %.0f > %.0f degrees" % tuple(total["turning"]))
    print("  turns of 30+ deg  %d > %d   (the sharpest: %.0f > %.0f)" % (
        total["sharp"][0], total["sharp"][1], total["sharpest"][0], total["sharpest"][1]))
    print("  slowest P.Line    %.0f > %.0f ms" % tuple(total["slowest"]))
    print("  deep water in a smoothed line is at most %.1f cells from where the path swam (allowed: %d)" % (total["farthest"], NEAR))
    print("smoothed lines that fail the check: %d" % total["bad"])
    return 1 if total["bad"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
