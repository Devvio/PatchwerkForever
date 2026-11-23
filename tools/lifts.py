"""Lifts whose towers stand in the game's files: where each is, and the ground at its two ends.

    python lifts.py             prints what it found
    python lifts.py write       and writes the lines into hand_links.txt, in a part of its own; then:
                                python links.py 1, python pack.py 1

The platform of a lift is something the server moves, so no file says "a lift runs here". But some lifts
ride in a tower that is a building model, and the model has a deck at the top and one at the bottom. For
each model named in TOWERS, every place it stands on a map the planner has is taken to be a lift: its two
largest flat floors are its decks, and each end of the link is the walkable ground nearest a deck, at
about the deck's height. The ride's time is not in the files: RIDE is a guess, to be put right from the
game (mark both ends with the macro in marks.py: the gap between the two marks is the wait and the ride).

Not found this way: lifts with no tower of their own (Thunder Bluff's, told by marks made in the game),
and lifts inside a city, whose floors the planner does not know (the Undercity's).
"""
import collections
import math
import os
import sys

from casc import Storage
from nav import Ground, CELL, cell_of, world_of, _F
from links import height
from marks import MARKER as MARKS
from wmo import placements, placing, model
from world import map_files

HERE = os.path.dirname(os.path.abspath(__file__))
MARKER = "# --- lifts found from their towers (written by lifts.py; the lines down to the next marker are replaced) ---"
MAPS = (0, 1, 2991)
# building models that are a lift's tower: {the model's file: what the lift is called where no name is told}
TOWERS = {112647: "lift"}
# the names of those found, by the placement's own number on the map
NAMES = {283429: "the Great Lift", 399190: "Freewind Post"}
RIDE = 30.0                   # seconds for the wait and the ride: a guess
FLAT = 0.9                    # a floor's triangles point this much upward, at least
BAND = 4.0                    # floors within this many yards of height are one deck
RISE = 15.0                   # yards between a lift's decks, at least
STEP = 6.0                    # the ground at an end is within this many yards of its deck's height
REACH = 15                    # ground cells (62 yards) from a deck's middle searched for that ground
HALF = 32 * 1600 / 3.0        # placement yards to world yards: world x = HALF - z, world y = HALF - x


def decks(store, piece):
    """The model's two largest flat floors, as it stands: [(height, square yards, world x, world y)], the higher first."""
    to = placing(store, piece)
    if not to:
        return None
    bands = collections.defaultdict(lambda: [0.0, 0.0, 0.0, 0.0])
    for verts, tris in model(store, piece[0])[1]:
        pts = [to(*v) for v in verts]                      # (x east, z south, y up)
        for i, j, k in tris:
            a, b, c = pts[i], pts[j], pts[k]
            e1 = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
            e2 = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
            n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
            size = math.sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2])
            if size < 1e-9 or abs(n[2]) / size < FLAT:
                continue
            area = size / 2
            up = (a[2] + b[2] + c[2]) / 3
            band = bands[round(up / BAND)]
            band[0] += area
            band[1] += up * area
            band[2] += (HALF - (a[1] + b[1] + c[1]) / 3) * area
            band[3] += (HALF - (a[0] + b[0] + c[0]) / 3) * area
    floors = sorted(bands.values(), key=lambda f: -f[0])[:2]
    if len(floors) < 2:
        return None
    return sorted(((f[1] / f[0], f[0], f[2] / f[0], f[3] / f[0]) for f in floors), reverse=True)


def end(ground, deck):
    """The walkable cell nearest the deck's middle, at about its height: (cell, height, yards off) or None."""
    up, _area, x, y = deck
    gx, gy = (int(v) for v in cell_of(x, y))
    best = None
    for dy in range(-REACH, REACH + 1):
        for dx in range(-REACH, REACH + 1):
            cell = (gx + dx, gy + dy)
            if ground.kind(*cell) != 1:
                continue
            h = height(ground, *cell)
            if abs(h - up) > STEP:
                continue
            d = math.hypot(dx, dy)
            if best is None or d < best[0]:
                best = (d, cell, h)
    return best and (best[1], best[2], best[0] * CELL)


def find(store, grounds):
    """(the lines for hand_links.txt, what to say about each tower)."""
    lines, said = [], []
    files = map_files(store)
    for m in sorted(grounds):
        for uid, piece in sorted(placements(store, files[m]).items()):
            if piece[0] not in TOWERS:
                continue
            name = "%s, %s" % (TOWERS[piece[0]], NAMES.get(uid, "tower %d" % uid))
            both = decks(store, piece)
            if not both or both[0][0] - both[1][0] < RISE:
                said.append("map %d, %s: left out, its two decks were not found" % (m, name))
                continue
            ends = [end(grounds[m], deck) for deck in both]
            if not ends[0] or not ends[1]:
                said.append("map %d, %s: left out, no walkable ground at the height of its %s deck (%.0f) within %.0f yards" % (
                    m, name, "upper" if not ends[0] else "lower", both[0 if not ends[0] else 1][0], REACH * CELL))
                continue
            (top, top_h, top_off), (low, low_h, low_off) = ends
            ax, ay = world_of(top[0] + 0.5, top[1] + 0.5)
            bx, by = world_of(low[0] + 0.5, low[1] + 0.5)
            said.append("map %d, %s: decks at height %.0f and %.0f; the ground %.0f yd from the upper, %.0f yd from the lower" % (
                m, name, both[0][0], both[1][0], top_off, low_off))
            lines.append("%d   %.1f %.1f   %.1f %.1f   %.0f   %s (%.0f yd up or down; the time is a guess)" % (
                m, ax, ay, bx, by, RIDE, name, top_h - low_h))
    return lines, said


def write(lines, path=os.path.join(HERE, "hand_links.txt")):
    """Put the lines in this tool's own part of the file, before the part marks.py writes."""
    with open(path, encoding="utf-8") as f:
        text = f.read()
    assert MARKS in text, "hand_links.txt has lost the marker of marks.py"
    head, tail = text.split(MARKS)
    head = head.split(MARKER)[0].rstrip("\n")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(head + "\n\n" + MARKER + "\n" + "\n".join(lines) + "\n\n" + MARKS + tail)


def main():
    store = Storage(r"G:/Games/World of Warcraft", "wowf")
    grounds = {m: Ground("world/map_%d.bin" % m, walls=False) for m in MAPS if os.path.exists("world/map_%d.bin" % m)}
    lines, said = find(store, grounds)
    print("\n".join(said + [""] + lines))
    if sys.argv[1:] == ["write"]:
        write(lines)
        print("%d link(s) written to hand_links.txt" % len(lines))


if __name__ == "__main__":
    main()
