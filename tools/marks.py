"""Turn spots marked in-game into hand-made links (lifts).

In game, a macro stores where the character stands in Patchwerk Forever's saved data:

    /run local x,y,z,m=UnitPosition("player");local d=PatchwerkForeverDB;d.marks=d.marks or{};tinsert(d.marks,{x,y,z,m,GetTime()});print("Mark "..#d.marks,x,y,z,m)

For each lift: press it on the ground just before stepping on, ride, and press it again on the
ground just after stepping off. Marks pair up in the order made (1 with 2, 3 with 4, ...).
Then /reload (or log out) so the game writes the file, and here:

    python marks.py                 reads the saved file, checks each mark against our ground, and
                                    writes the pairs into hand_links.txt
    python links.py 1               (and 0) adds them to the graph

Each mark is checked: it must stand on walkable ground in our data, at about the height the game
gave. A mark that fails is reported and its pair is left out.

WoW Forever gives no height (it prints 0), and a lift's upper landing can be a wooden platform
standing out over the lower ground, so both marks of a lift can fall on the same ground in our
data. Then say which marks were made at the top and which at the bottom, in the order made:

    python marks.py TBBT            mark 1 top, 2 bottom, 3 bottom, 4 top

and the top end is moved to the nearest walkable ground at least 15 yards higher (where the
platform meets the cliff top); how far it was moved is reported.

A safe drop (a place to jump or slide down, not to climb) is marked with D: marks made one after
the other going down, two or more, become one-way links from each to the next:

    python marks.py TBBTBTTBDDD     marks 9, 10 and 11: a drop from 9 to 10 and on from 10 to 11
"""
import math
import os
import sys

from lupa import LuaRuntime

from nav import Ground, _F, cell_of, world_of
from links import height
from terrain import CELL

# Patchwerk Forever's saved data: the newest one of the accounts on this install
import glob
_FOUND = glob.glob(r"G:/Games/World of Warcraft/_forever_/WTF/Account/*/SavedVariables/PatchwerkForever.lua")
SAVED = max(_FOUND, key=os.path.getmtime) if _FOUND else ""
HERE = os.path.dirname(os.path.abspath(__file__))
MARKER = "# --- from marks made in-game (written by marks.py; anything below this line is replaced) ---"
NEAR = 2                  # ground cells round a mark that are looked at (8 yards)
RISE = 15.0               # yards between a lift's ends, at least
REACH = 15                # ground cells (62 yards) an end may be moved to find its level


def level(ground, cell, other_height, up):
    """The walkable cell nearest to `cell` that is at least RISE above (or below) the other end: (cell, height, yards moved)."""
    best = None
    for dy in range(-REACH, REACH + 1):
        for dx in range(-REACH, REACH + 1):
            to = (cell[0] + dx, cell[1] + dy)
            if not _F[ground.kind(*to)]:
                continue
            h = height(ground, *to)
            if (h - other_height if up else other_height - h) < RISE:
                continue
            d = math.hypot(dx, dy)
            if best is None or d < best[0]:
                best = (d, to, h)
    return best and (best[1], best[2], best[0] * CELL)


def read_marks(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    with open(path, encoding="utf-8", errors="replace") as f:
        lua.execute(f.read())
    db = lua.globals().PatchwerkForeverDB
    marks = db and db.marks
    out = []
    if marks:
        for i in range(1, len(marks) + 1):
            m = marks[i]
            out.append(tuple(float(m[k] or 0) for k in range(1, 6)))
    return out


def place(ground, x, y, z):
    """The walkable ground cell a mark stands on: (cell, its height, how far from the mark's height), or None."""
    gx, gy = (int(v) for v in cell_of(x, y))
    best = None
    for dy in range(-NEAR, NEAR + 1):
        for dx in range(-NEAR, NEAR + 1):
            cell = (gx + dx, gy + dy)
            if not _F[ground.kind(*cell)]:
                continue
            h = height(ground, *cell)
            off = abs(h - z) if abs(z) > 0.01 else 0.0          # some clients give no height
            score = off + 0.5 * math.hypot(dx, dy)
            if best is None or score < best[0]:
                best = (score, cell, h, off)
    return best and best[1:]


def main(saved=SAVED, out=os.path.join(HERE, "hand_links.txt"), levels=""):
    marks = read_marks(saved)
    print("%d marks in %s" % (len(marks), saved))
    if not marks:
        print("none to use: press the macro in game, then /reload")
        return
    grounds, placed = {}, []
    for n, (x, y, z, m, t) in enumerate(marks, 1):
        m = int(m)
        if m not in grounds:
            path = os.path.join(HERE, "world", "map_%d.bin" % m)
            grounds[m] = Ground(path) if os.path.exists(path) else None
        got = grounds[m] and place(grounds[m], x, y, z)
        if not got:
            print("  mark %d: world (%.1f, %.1f) height %.1f on map %d: %s" % (
                n, x, y, z, m, "no walkable ground within 8 yards in our data" if grounds[m] else "that map is not extracted"))
            placed.append(None)
            continue
        cell, h, off = got
        note = "" if off <= 6 else "   CHECK: our ground there is %.0f yd from the game's height" % off
        print("  mark %d: world (%.1f, %.1f) height %.1f, map %d -> our ground at height %.1f%s" % (n, x, y, z, m, h, note))
        placed.append((m, cell, h, t, off))
    lines = [MARKER]
    levels = levels.upper()
    pairs, drops, k = [], [], 0
    while k < len(placed):
        if levels[k: k + 1] == "D":
            while k + 1 < len(placed) and levels[k + 1: k + 2] == "D":
                drops.append(k)
                k += 1
            k += 1
        else:
            if k + 1 < len(placed):
                pairs.append(k)
            else:
                print("  mark %d has no partner" % (k + 1))
            k += 2
    for k in drops:
        a, b = placed[k], placed[k + 1]
        name = "drop, marks %d to %d" % (k + 1, k + 2)
        if not a or not b or a[0] != b[0]:
            print("  %s: left out, an end could not be placed" % name)
            continue
        apart = math.hypot(a[1][0] - b[1][0], a[1][1] - b[1][1]) * CELL
        fall = a[2] - b[2]
        if fall < 5 or apart > 150:
            print("  %s: left out: it goes %.0f yd down and %.0f yd along in our data" % (name, fall, apart))
            continue
        gap = b[3] - a[3]
        seconds = gap if 2 <= gap <= 30 else math.hypot(apart, fall) / 7.0     # else as far as it is, at a run
        ax, ay = world_of(a[1][0] + 0.5, a[1][1] + 0.5)
        bx, by = world_of(b[1][0] + 0.5, b[1][1] + 0.5)
        print("  %s: %.0f yd down, %.0f yd along, %.0f s, one way" % (name, fall, apart, seconds))
        lines.append("%d   %.1f %.1f   %.1f %.1f   %.0f   oneway   %s (%.0f yd down)" % (a[0], ax, ay, bx, by, seconds, name, fall))
    for k in pairs:
        a, b = placed[k], placed[k + 1]
        name = "lift, marks %d and %d" % (k + 1, k + 2)
        if not a or not b:
            print("  %s: left out, an end could not be placed" % name)
            continue
        if a[0] != b[0]:
            print("  %s: left out, the ends are on different maps" % name)
            continue
        if a[4] > 6 or b[4] > 6:
            print("  %s: left out, an end is not at the game's height in our data" % name)
            continue
        apart = math.hypot(a[1][0] - b[1][0], a[1][1] - b[1][1]) * CELL
        hint = levels[k: k + 2].upper()
        if abs(a[2] - b[2]) < RISE and hint in ("TB", "BT"):
            # both marks fell on the same ground: the top end goes to the nearest ground at its level
            top, low = (a, b) if hint == "TB" else (b, a)
            moved = level(grounds[a[0]], top[1], low[2], True)
            if moved:
                raised = (top[0], moved[0], moved[1], top[3], top[4])
                a, b = (raised, low) if hint == "TB" else (low, raised)
                name += " (top end moved %.0f yd to the nearest ground at height %.0f)" % (moved[2], moved[1])
        apart = math.hypot(a[1][0] - b[1][0], a[1][1] - b[1][1]) * CELL
        rise = abs(a[2] - b[2])
        ride = abs(b[3] - a[3])
        seconds = ride if 3 <= ride <= 180 else 30.0          # the gap between the two presses: wait and ride
        ax, ay = world_of(a[1][0] + 0.5, a[1][1] + 0.5)
        bx, by = world_of(b[1][0] + 0.5, b[1][1] + 0.5)
        if apart > 150:
            print("  %s: left out, the ends are %.0f yd apart on the map (a lift's are a few yards)" % (name, apart))
            continue
        if rise < RISE:
            print("  %s: left out, both ends are at the same height in our data (%.0f yd apart). "
                  "Say which is the top: python marks.py TB..." % (name, rise))
            continue
        warn = ""
        print("  %s: %.0f yd up or down, %.0f yd apart on the map, %.0f s%s" % (name, rise, apart, seconds, warn))
        lines.append("%d   %.1f %.1f   %.1f %.1f   %.0f   %s" % (a[0], ax, ay, bx, by, seconds, name))
    with open(out, encoding="utf-8") as f:
        kept = f.read().split(MARKER)[0].rstrip("\n")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(kept + "\n\n" + "\n".join(lines) + "\n")
    print("%d link(s) written to %s" % (len(lines) - 1, out))


if __name__ == "__main__":
    args = sys.argv[1:]
    given = [a for a in args if a and not set(a.upper()) - set("TBD-")]
    files = [a for a in args if a not in given]
    main(*(files[:2] + [SAVED, os.path.join(HERE, "hand_links.txt")][len(files[:2]):]), levels=given[0] if given else "")
