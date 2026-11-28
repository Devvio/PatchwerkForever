"""Walls and floors: what a building does to the ground under it.

world.py knows the terrain only. To the planner a town is then open ground, and a route runs straight
through its houses; and a city that is one great model (its streets are the model's floor, the terrain
far below it flat and empty) is an open plain. This lays the building models on the ground's cells.

    python walls.py 1                                     a whole map
    python walls.py 1 graph                               only world/nav_1_linked.bin again (after roads.py)
    python walls.py 1 check                               only the splits: ways the one-yard grid has that the cells cut
                                                          (world/splits_1.txt; nothing else written)
    python walls.py 1 1300 2000 -4800 -4100 look.png      only this part (world X from, to; world Y from, to),
                                                          and a picture of it; nothing is written

For every structure (links.py's: the models whose boxes touch), on its one-yard grid:

  * a walk is made from the open ground round it: over the terrain, where no wall, post or low roof
    stands between knee and head and no floor lies just over it; onto the model's floors where one
    meets the ground; and over the floors, up their stairs and ramps (links.py's CLIMB). It starts
    as well from all ground that lies against terrain that is no way (a cliff, water's edge, a hole):
    ground the terrain itself shuts in, a bluff's top reached only by a lift, is ground as before
    (not in a city's box, where the terrain is not the land's own);
  * a yard of passable terrain the walk does not reach is shut: a wall stands on it, or it lies inside
    walls with no door. Under a city no terrain the model covers is ground. A city is a model larger
    than links.py's BIG whose streets are its own floor, the terrain under them left flat and empty:
    a good part of the dry terrain under it is dead flat (no land the game's makers shaped is), and
    a good part of its floor is walked well above that terrain. Orgrimmar and Stormwind are, and
    Razorfen, Stratholme's and Dire Maul's grounds; Darnassus, Ironforge and Timbermaw Hold are not;
  * a yard the walk reaches over a floor is floor: ground where the terrain under it is no way or is
    not reached (a city's streets), and ground over water (a pier, a bridge's deck).

Then, by the ground cell (four yards by four):

  * a cell is a way where its largest open piece is half of it or more. Small pieces cut off by a wall
    are not counted, so a doorway or a gate leaves its cell whole and a wall through the middle shuts it;
  * where a wall runs along the edge between two open cells and nothing leads across, the one with
    more open ground becomes wall (a narrow way keeps its cells, the wide place beside it loses a strip);
  * a small patch left with no way out becomes wall too, so that nothing is ever routed into it;
  * the ground at the two ends of every link (links.py: a bridge's, a tunnel's, a lift's) is left as
    it is, so a railing never shuts a bridge and a tunnel too narrow for a cell keeps its mouths.
    Not under a city: the terrain it covers is wall there too.

A cell whose ground is a floor is given the floor's height (a flight master in a city is then on the
ground, not a tower's height above the terrain under the city).

A wall is written as ground too steep to walk (STEEP) and a floor as ground (WALK): the planner and
the packed data need nothing new. One layer only: where two floors lie one over the other (a walkway
over a street, a street over a cave), the cell is the wider one's, the one with more floor at its
height round the cell; and of two cells side by side whose floors are too far apart in height to be
joined, the narrower one's becomes wall. So a street runs on under a walkway, and the walkway is cut.

Reads world/map_<id>.bin (the terrain, left as it is) and world/links_<id>.bin (links.py); writes
world/walls_<id>.bin (the cells changed, which world.load lays on the terrain for every other tool),
world/walls_<id>.txt (what was done, to read), and world/nav_<id>_linked.bin again: the graph of the
ground with its walls and floors, and the links.

Scenery models (M2: a tent, a cart, a fence, a wagon, a rock; not a post, a lamp or a tree's trunk, narrower than
SCENERY) are laid on after the buildings: their collision triangles steeper than a floor (sides, not tops) and
starting within FOOT of the model's foot, of models no taller than TALL (not trees or spires), on the
one-yard grid, each with the heights it holds at each yard; a yard of terrain where one stands between knee and head is shut, as a building's wall shuts it, and a floor
so blocked is taken away. They are not walked onto: a scenery model's top is never ground (an M2 bridge's deck is
not read as one; such a bridge is still missing, as before).
"""
import array
import collections
import os
import pickle
import sys
import time
import zlib

from casc import Storage
from links import BIG, CLIMB, FINE, FLOOR, HEAD, KNEE, ONTO, TOUCH, chains, ground_height, height, shapes
from nav import Coarse, Ground, _F, world_of
from terrain import CELL, TILE
from wmo import placements, scenery_placements, scenery_shape, turned
from world import NONE, STEEP, SWIM, WADE, WALK, map_files

MARGIN = 3                # ground cells round a structure's boxes that the walk starts from
ENOUGH = FINE * FINE // 2  # a ground cell is a way where its largest open piece has this many yards
SLIVER = 4                # an open piece of a cell this small at most, cut off from the largest, is not counted
NARROW = 3                # yards: a cell less than half open is still a way where its open piece, this large at least,
                          # leads through it (see decide)
GAP = 2.5                 # yards of height with no floor in them, in and round a cell: two floors, not one
STEP = 6.5                # yards: two cells side by side whose floors differ by more are not joined
REACH = 2                 # ground cells round two cells side by side in which a way between them at yard level is looked for
POCKET = 150              # ground cells: a patch left with no way out is wall if it is no larger (50 yards square)
SCENERY = 2.5             # yards: a scenery model whose collision is this wide or wider is laid on the ground (a post,
                          # a lamp or a tree's trunk is not: it shuts too little of a cell to matter)
TALL = 20.0               # yards: a scenery model whose collision is taller is left out (a tree, a rock spire: their
                          # feet are real, but at four-yard cells the gaps between trunks close and a forest floor
                          # falls into shut pockets; Kalimdor went from 92,000 wall cells to 246,000)
FOOT = 4.0                # yards: of a scenery model only what starts this low over its lowest point is laid (a tree's
                          # trunk and roots, not its canopy, which met sloping ground in rings)
KEEP = 3                  # ground cells round a link's end that are never wall
ABOVE = 6.0               # yards over dry terrain: floor walked this high is a city's street, and a great model
CITY = 0.3                # with this share of its floor walked so high is a city, where
FLAT = 0.3                # this share of the dry terrain cells under its floor is dead flat (placeholder terrain)
ALL = (1 << FINE * FINE) - 1
F = CELL / FINE
SQ2 = 2.0 ** 0.5
_AROUND = ((1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0), (1, 1, SQ2), (1, -1, SQ2), (-1, 1, SQ2), (-1, -1, SQ2))
_parts = {}
EDGES = {}                # (for looking: each cell walled by the edge rule, and the pair that did it)


def stopped(zs, h):
    for n in range(0, len(zs), 2):
        if zs[n + 1] > h + KNEE and zs[n] < h + HEAD:
            return True
    return False


def walk(ground, pieces, floors, obstacles, shut, over, city=None, buried=None):
    """The walk over one structure from the open ground round it. Into shut ({ground cell: a bit a yard}):
    the yards of passable terrain it does not reach; into over ({ground cell: for each of its 16 yards, the
    heights of the floors it reaches there, or None}). city: a city's own (floors, obstacles), where the
    structure is one: no terrain they cover is ground, and the ground cells so covered go into buried."""
    u0 = (int(min(p[1] for p in pieces) / CELL) - MARGIN) * FINE
    v0 = (int(min(p[2] for p in pieces) / CELL) - MARGIN) * FINE
    u1 = (int(max(p[3] for p in pieces) / CELL) + MARGIN + 1) * FINE
    v1 = (int(max(p[4] for p in pieces) / CELL) + MARGIN + 1) * FINE
    u0, v0 = max(0, u0), max(0, v0)
    w, h = u1 - u0, v1 - v0
    # the terrain a yard: 0 no way, 1 can be stood on, 2 reached; and its height
    state = bytearray(w * h)
    high = array.array("f", bytes(4 * w * h))
    for v in range(v0, v1):
        row = (v - v0) * w
        gy = v // FINE
        for u in range(u0, u1):
            if not _F[ground.kind(u // FINE, gy)]:
                continue
            th = ground_height(ground, u, v)
            at = row + u - u0
            high[at] = th
            key = (u << 16) | v
            zs = obstacles.get(key)
            hs = floors.get(key)
            if city:                                    # (nothing the city covers is ground)
                czs, chs = city[1].get(key), city[0].get(key)
                if (czs and max(czs) > th + KNEE) or (chs and max(chs) > th + ONTO):
                    buried[(u // FINE, gy)] = buried.get((u // FINE, gy), 0) + 1
                    continue
            if zs and stopped(zs, th):
                continue
            if hs:
                for fh in hs:
                    if th < fh <= th + HEAD:            # (a floor just over it: that is stood on, not this)
                        break
                else:
                    state[at] = 1
            else:
                state[at] = 1
    # from the terrain along the edge, and from the terrain against terrain that is no way (what the land shuts
    # in is none of the models' doing). A node is a yard of terrain (level 0) or of floor (its place in the list + 1)
    reached = set()
    queue = collections.deque()
    # (not under a city: the terrain in its box is not the land's own, and would lead onto its roofs)
    for gy in range(v0 // FINE, v1 // FINE) if not city else ():
        for gx in range(u0 // FINE, u1 // FINE):
            if _F[ground.kind(gx, gy)]:
                continue
            # (the yards of the passable cells beside this one, along the side they share)
            for ox, oy in ((gx - 1, gy), (gx + 1, gy), (gx, gy - 1), (gx, gy + 1)):
                if not _F[ground.kind(ox, oy)] or ox * FINE < u0 or oy * FINE < v0 or ox * FINE >= u1 or oy * FINE >= v1:
                    continue
                for i in range(FINE):
                    if ox != gx:
                        u, v = (ox * FINE + FINE - 1 if ox < gx else ox * FINE), oy * FINE + i
                    else:
                        u, v = ox * FINE + i, (oy * FINE + FINE - 1 if oy < gy else oy * FINE)
                    at = (v - v0) * w + u - u0
                    if state[at] == 1:
                        state[at] = 2
                        queue.append((at, 0))
    for u in range(w):
        for at in (u, (h - 1) * w + u):
            if state[at] == 1:
                state[at] = 2
                queue.append((at, 0))
    for v in range(h):
        for at in (v * w, v * w + w - 1):
            if state[at] == 1:
                state[at] = 2
                queue.append((at, 0))
    while queue:
        at, level = queue.popleft()
        v, u = divmod(at, w)
        key = ((u + u0) << 16) | (v + v0)
        if level:
            here = floors[key][level - 1]
            if state[at] == 1 and abs(high[at] - here) <= ONTO:      # (off the floor onto the terrain it lies on)
                state[at] = 2
                queue.append((at, 0))
        else:
            here = high[at]
            hs = floors.get(key)
            if hs:
                for i, fh in enumerate(hs):
                    if abs(fh - here) <= ONTO and (at, i + 1) not in reached:
                        reached.add((at, i + 1))
                        queue.append((at, i + 1))
        for du, dv, run in _AROUND:
            uu, vv = u + du, v + dv
            if uu < 0 or vv < 0 or uu >= w or vv >= h:
                continue
            to = vv * w + uu
            if state[to] == 1 and (not level or abs(high[to] - here) <= ONTO * run):
                state[to] = 2
                queue.append((to, 0))
            hs = floors.get(((uu + u0) << 16) | (vv + v0))
            if hs:
                reach = (CLIMB if level else ONTO) * run
                for i, fh in enumerate(hs):
                    if abs(fh - here) <= reach and (to, i + 1) not in reached:
                        reached.add((to, i + 1))
                        queue.append((to, i + 1))
    for at in range(w * h):
        if state[at] == 2:
            continue
        v, u = divmod(at, w)
        u, v = u + u0, v + v0
        if _F[ground.kind(u // FINE, v // FINE)]:
            cell = (u // FINE, v // FINE)
            shut[cell] = shut.get(cell, 0) | 1 << ((v % FINE) * FINE + u % FINE)
    for at, level in reached:
        v, u = divmod(at, w)
        u, v = u + u0, v + v0
        fh = floors[(u << 16) | v][level - 1]
        heights = over.get((u // FINE, v // FINE))
        if heights is None:
            heights = over[(u // FINE, v // FINE)] = [None] * (FINE * FINE)
        i = (v % FINE) * FINE + u % FINE
        if heights[i] is None:
            heights[i] = [fh]
        else:
            heights[i].append(fh)
    return len(reached)


def raised(ground, pieces, floors, obstacles):
    """Whether a great model is a city with ground of its own: (yes or no, the share of its floor over dry
    terrain that the walk reaches more than ABOVE yards over that terrain, the share of the dry terrain cells
    under its floor that are dead flat). Timbermaw Hold is as large, but its tunnels run under the terrain;
    Darnassus has high walks, but stands on land that was shaped."""
    dry = (WALK, STEEP)
    under = set(((key >> 16) // FINE, (key & 65535) // FINE) for key in floors)
    under = [cell for cell in under if ground.kind(*cell) in dry]
    flat = sum(1 for gx, gy in under if all(height(ground, gx + dx, gy + dy) == height(ground, gx, gy)
                                            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))))
    level = flat / len(under) if under else 0.0
    if level < FLAT:
        return False, 0.0, level
    over = {}
    walk(ground, pieces, floors, obstacles, {}, over)
    high = 0
    for (gx, gy), heights in over.items():
        if ground.kind(gx, gy) in dry:
            for i, hs in enumerate(heights):
                if hs and max(hs) > ground_height(ground, gx * FINE + i % FINE, gy * FINE + i // FINE) + ABOVE:
                    high += 1
    total = sum(1 for key in floors if ground.kind((key >> 16) // FINE, (key & 65535) // FINE) in dry)
    share = high / total if total else 0.0
    return share >= CITY, share, level


def parts(mask):
    """Of a ground cell's yards, those shut given: (the largest open piece as bits, its size). An open piece of
    SLIVER yards at most, cut off from the largest, is not counted as open at all."""
    found = _parts.get(mask)
    if found:
        return found
    seen, best, size = 0, 0, 0
    for start in range(FINE * FINE):
        bit = 1 << start
        if mask & bit or seen & bit:
            continue
        piece, stack = bit, [start]
        while stack:
            at = stack.pop()
            r, c = divmod(at, FINE)
            for rr, cc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
                if 0 <= rr < FINE and 0 <= cc < FINE:
                    to = 1 << (rr * FINE + cc)
                    if not (mask & to or piece & to):
                        piece |= to
                        stack.append(rr * FINE + cc)
        seen |= piece
        n = bin(piece).count("1")
        if n > size:
            if size > SLIVER:
                best, size = 0, -1                          # (two pieces of some size: a wall cuts the cell)
                break
            best, size = piece, n
        elif n > SLIVER:
            best, size = 0, -1
            break
    _parts[mask] = (best, max(size, 0))
    return _parts[mask]


def crosses(a, b, across):
    """Whether the open pieces of two ground cells side by side meet: b is right of a, or under it."""
    for i in range(FINE):
        if across:
            if a >> (i * FINE + FINE - 1) & 1 and b >> (i * FINE) & 1:
                return True
        elif a >> ((FINE - 1) * FINE + i) & 1 and b >> i & 1:
            return True
    return False


def decide(ground, shut, over, keep, buried):
    """What each ground cell touched becomes: (walls: {cell: why}, floors: the cells made ground, heights:
    {cell: its floor's height} for every cell left a way whose ground is a floor)."""
    floor_bits, level, weight = {}, {}, {}
    for cell, heights in over.items():
        # the floors in and round the cell, by height: each run of heights with no gap in it is one floor (a
        # ramp is one, a walkway over a street two). The cell's is the one with the most yards of it round here.
        mine = sorted(h for hs in heights if hs for h in hs)
        near = []
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for hs in over.get((cell[0] + dx, cell[1] + dy)) or ():
                    if hs:
                        near.extend(hs)
        near.sort()
        # (first by how many of the cell's own yards are on it, then by how many round it: a cell full of a floor of
        # its own beside a larger one at another height keeps its own, and so stays ground; 2026-11-28)
        best, start, rank = None, 0, None
        for n in range(1, len(near) + 1):
            if n == len(near) or near[n] - near[n - 1] > GAP:
                low, high = near[start], near[n - 1]
                own_yards = sum(1 for hs in heights if hs and any(low <= h <= high for h in hs))
                if own_yards and (rank is None or (own_yards, n - start) > rank):
                    best, rank = (n - start, low, high), (own_yards, n - start)
                start = n
        bits, own = 0, []
        for i, hs in enumerate(heights):
            for h in hs or ():
                if best[1] <= h <= best[2]:
                    bits |= 1 << i
                    own.append(h)
        own.sort()
        floor_bits[cell], level[cell], weight[cell] = bits, own[len(own) // 2], best[0]

    def mask(cell):
        # (the yards not open: neither terrain the walk reached nor floor)
        if _F[ground.kind(*cell)]:
            return shut.get(cell, 0) & ~floor_bits.get(cell, 0)
        return ALL & ~floor_bits.get(cell, 0)

    def on_floor_only(cell):
        return cell in level and (not _F[ground.kind(*cell)] or shut.get(cell, 0) == ALL)

    def holds(cell, h):
        return any(abs(x - h) <= GAP for hs in over.get(cell) or () if hs for x in hs)

    def apart(a, b):
        """Of two cells whose ground is floor alone, the floors too far apart in height to be joined: the one
        with less of its floor round it (the narrower way)."""
        if on_floor_only(a) and on_floor_only(b) and abs(level[a] - level[b]) > STEP \
                and not holds(a, level[b]) and not holds(b, level[a]):
            # (not where either holds floor at the other's height too: they meet there, and only the height each was
            # given differs; a passage under an arch was cut so, 2026-11-28)
            return a if (weight[a], -level[a]) < (weight[b], -level[b]) else b
        return None

    walls, floors = {}, set()
    for cell in set(shut) | set(over):
        kind = ground.kind(*cell)
        on_floor = parts(ALL & ~floor_bits.get(cell, 0))[1] >= ENOUGH
        if not _F[kind] or kind in (WADE, SWIM):
            if on_floor:
                floors.add(cell)                            # (a floor over no ground, or over water)
                continue
            if not _F[kind]:
                continue
        # (a cell at a link's end is left as it is: a railing does not shut a bridge's mouth, and the yard
        # between two tunnels stays one. Not under a city: its terrain is not opened again)
        if parts(mask(cell))[1] < ENOUGH and (cell not in keep or buried.get(cell, 0) > ENOUGH):
            walls[cell] = "shut"

    def way(cell):
        return cell in floors or (cell not in walls and _F[ground.kind(*cell)])

    # a narrow way: a cell with less than half of it open (a passage, a stair or a deck two or three yards wide
    # crossing it) is a way after all where its one open piece, NARROW yards or more, meets the open ground of cells
    # on two sides of it that face away from each other, yard to yard; again and again, so a passage may run on over
    # several cells. A wall through the middle of a cell (two pieces) still shuts it. (The cave on Zephras Isle at
    # (4073, 2190), and others found by `splits`, 2026-11-28.)
    narrow = {}
    for cell in set(shut) | set(over):
        kind = ground.kind(*cell)
        if way(cell) or (_F[kind] and walls.get(cell) != "shut") or cell in keep:
            continue
        bits, size = parts(mask(cell))
        if size >= NARROW:
            narrow[cell] = bits
    ring = ((1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1))
    last = FINE - 1

    def meets(a, b, dx, dy):
        """whether open yards a (a cell's) and b (the cell dx, dy from it) touch"""
        if dx and dy:
            ca, cb = (last if dx > 0 else 0), (0 if dx > 0 else last)
            ra, rb = (last if dy > 0 else 0), (0 if dy > 0 else last)
            return bool(a >> (ra * FINE + ca) & 1 and b >> (rb * FINE + cb) & 1)
        for i in range(FINE):
            if dx:
                ya, yb = i * FINE + (last if dx > 0 else 0), i * FINE + (0 if dx > 0 else last)
            else:
                ya, yb = (last if dy > 0 else 0) * FINE + i, (0 if dy > 0 else last) * FINE + i
            if a >> ya & 1 and b >> yb & 1:
                return True
        return False

    opened, changed = set(), True
    while changed:
        changed = False
        for cell, bits in narrow.items():
            if cell in opened:
                continue
            sides = []
            for k, (dx, dy) in enumerate(ring):
                other = (cell[0] + dx, cell[1] + dy)
                if other in opened:
                    theirs = narrow[other]
                elif way(other):
                    theirs = parts(mask(other))[0] if (other in shut or other in over) else ALL
                else:
                    continue
                if meets(bits, theirs, dx, dy):
                    sides.append(k)
            if any(min((p - q) % 8, (q - p) % 8) >= 3 for p in sides for q in sides):
                opened.add(cell)
                changed = True
    for cell in opened:
        if _F[ground.kind(*cell)]:
            del walls[cell]
        else:
            floors.add(cell)

    def linked(a, b):
        """Whether the open pieces of two cells side by side meet by a short way through the cells round them, yard by
        yard, within REACH cells of them: a narrow bridge or street running slantwise, its railings on the cells'
        edges, meets its next cell only through the ones beside both. (Without this, Stormwind's slanting canal bridges were walled, 2026-11-28.)"""
        x0, y0 = min(a[0], b[0]) - REACH, min(a[1], b[1]) - REACH
        x1, y1 = max(a[0], b[0]) + REACH, max(a[1], b[1]) + REACH
        open_ = set()
        for cx in range(x0, x1 + 1):
            for cy in range(y0, y1 + 1):
                if not way((cx, cy)):
                    continue
                shut_ = mask((cx, cy))
                for i in range(FINE * FINE):
                    if not shut_ >> i & 1:
                        open_.add(((cx - x0) * FINE + i % FINE, (cy - y0) * FINE + i // FINE))

        def yards(cell):
            shut_ = mask(cell)
            return {((cell[0] - x0) * FINE + i % FINE, (cell[1] - y0) * FINE + i // FINE)
                    for i in range(FINE * FINE) if not shut_ >> i & 1}
        goal = yards(b)
        if not goal:
            return False
        seen = yards(a)
        stack = list(seen)
        while stack:
            u, v = stack.pop()
            if (u, v) in goal:
                return True
            for q in ((u + 1, v), (u - 1, v), (u, v + 1), (u, v - 1)):
                if q in open_ and q not in seen:
                    seen.add(q)
                    stack.append(q)
        return False

    # a wall along the edge between two open cells, with nothing leading across: the one with more open ground
    # becomes wall (so a narrow way keeps its cells)
    for cell in sorted(set(shut) | set(over)):
        if not way(cell):
            continue
        gx, gy = cell
        for other, across, first in (((gx + 1, gy), True, True), ((gx, gy + 1), False, True),
                                     ((gx - 1, gy), True, False), ((gx, gy - 1), False, False)):
            if not way(other) or not way(cell):
                continue
            if not first and (other in shut or other in over):
                continue                                    # (that pair is looked at from the other cell)
            mine, theirs = parts(mask(cell)), parts(mask(other))
            lower = apart(cell, other)
            if not lower and (crosses(mine[0], theirs[0], across) if first else crosses(theirs[0], mine[0], across)):
                continue
            if not lower and linked(cell, other):
                continue
            loser = lower or (cell if mine[1] >= theirs[1] else other)
            if loser in keep:
                loser = other if loser == cell else cell
            if loser in keep:
                continue
            EDGES[loser] = (cell, other, lower)
            if loser in floors:
                floors.discard(loser)
            else:
                walls[loser] = "edge"
    heights = {cell: level[cell] for cell in level if cell in floors or on_floor_only(cell)}
    return walls, floors, heights


def pockets(ground, walls, floors, keep):
    """Patches of ground beside the walls with no way out, POCKET cells at most: the cells of each."""
    def way(cell):
        return cell in floors or (cell not in walls and _F[ground.kind(*cell)])

    large, found = set(), []
    starts = set()
    for wx, wy in list(walls) + list(floors):
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                starts.add((wx + dx, wy + dy))
    for start in sorted(starts):
        if start in large or not way(start):
            continue
        patch, stack, big = {start}, [start], False
        while stack and not big:
            x, y = stack.pop()
            for ex in (-1, 0, 1):
                for ey in (-1, 0, 1):
                    to = (x + ex, y + ey)
                    if to in patch or not way(to):
                        continue
                    if ex and ey and not (way((x + ex, y)) and way((x, y + ey))):
                        continue
                    if to in large or len(patch) >= POCKET:
                        big = True
                        break
                    patch.add(to)
                    stack.append(to)
                if big:
                    break
        if big or patch & keep:
            large |= patch
        else:
            found.append(sorted(patch))
            for cell in patch:
                if cell in floors:
                    floors.discard(cell)
                else:
                    walls[cell] = "pocket"
    return found


def link_ends(map_id):
    path = "world/links_%d.bin" % map_id
    if not os.path.exists(path):
        return []
    with open(path, "rb") as f:
        return pickle.load(f)


def kept(links):
    keep = set()
    for a, b, _seconds, _oneway in links:
        for x, y in (a, b):
            for dx in range(-KEEP, KEEP + 1):
                for dy in range(-KEEP, KEEP + 1):
                    keep.add((x + dx, y + dy))
    return keep


def scenery(store, ground, places, shut, over, window=None):
    """Scenery models' collision laid on the one-yard grid (see the words at the head): into shut, the yards of
    passable terrain they block; from over, the floor heights they block. Returns (models laid, yards shut)."""
    laid, blocked = 0, 0
    for fdid, pos, turn, scale in places:
        if window:                                  # (pos: x, y up, z in placement yards; the window: world X, Y)
            wx, wy = 32 * TILE - pos[2], 32 * TILE - pos[0]
            if not (window[0] <= wx <= window[1] and window[2] <= wy <= window[3]):
                continue
        verts, tris = scenery_shape(store, fdid)
        if not tris:
            continue
        xs, ys = [v[0] for v in verts], [v[1] for v in verts]
        if max(max(xs) - min(xs), max(ys) - min(ys)) * scale < SCENERY:
            continue
        if (max(v[2] for v in verts) - min(v[2] for v in verts)) * scale > TALL:
            continue
        to = turned(pos, turn, scale)
        pts = [(x / F, z / F, y) for x, z, y in (to(*v) for v in verts)]
        base = min(p[2] for p in pts) + FOOT
        spans = {}                                  # yard -> [low, high, low, high, ...]: what the model holds there
        for i, j, k in tris:
            a, b, c = pts[i], pts[j], pts[k]
            # a side steeper than a floor stops a character; a top (a deck, a cart's bed, a flat rock) does not, and is
            # not walked onto either: so a scenery bridge or dock never cuts the bank it stands on
            e1u, e1v, e1z = (b[0] - a[0]) * F, (b[1] - a[1]) * F, b[2] - a[2]
            e2u, e2v, e2z = (c[0] - a[0]) * F, (c[1] - a[1]) * F, c[2] - a[2]
            nx, ny, nz = e1v * e2z - e1z * e2v, e1z * e2u - e1u * e2z, e1u * e2v - e1v * e2u
            size = (nx * nx + ny * ny + nz * nz) ** 0.5
            if size < 1e-9 or abs(nz) / size >= FLOOR or min(a[2], b[2], c[2]) > base:
                continue
            # the heights the triangle holds at each yard it touches: along its edges (a wall seen edge-on covers no
            # yard's middle), and at the yards whose middles it covers, with what it climbs within a yard (so a canopy
            # rising from a trunk blocks only where it is between knee and head, not all its span over its footprint)
            here = {}

            def hold(key, low, high):
                got = here.get(key)
                if got is None:
                    here[key] = [low, high]
                else:
                    if low < got[0]:
                        got[0] = low
                    if high > got[1]:
                        got[1] = high

            for p, q in ((a, b), (b, c), (c, a)):
                steps = int(max(abs(q[0] - p[0]), abs(q[1] - p[1])) * 2) + 1
                for s in range(steps + 1):
                    f = s / steps
                    z = p[2] + (q[2] - p[2]) * f
                    hold((int(p[0] + (q[0] - p[0]) * f), int(p[1] + (q[1] - p[1]) * f)), z, z)
            area = (b[0] - a[0]) * (c[1] - a[1]) - (c[0] - a[0]) * (b[1] - a[1])
            if abs(area) > 1e-6:
                spread = min(max(a[2], b[2], c[2]) - min(a[2], b[2], c[2]), (abs(nx) + abs(ny)) / abs(nz) * F * 0.5)                     if abs(nz) > 1e-6 else 0.0
                for u in range(int(min(a[0], b[0], c[0])), int(max(a[0], b[0], c[0])) + 1):
                    for v in range(int(min(a[1], b[1], c[1])), int(max(a[1], b[1], c[1])) + 1):
                        x, y = u + 0.5, v + 0.5
                        w1 = ((b[0] - x) * (c[1] - y) - (c[0] - x) * (b[1] - y)) / area
                        w2 = ((c[0] - x) * (a[1] - y) - (a[0] - x) * (c[1] - y)) / area
                        if w1 >= 0 and w2 >= 0 and w1 + w2 <= 1:
                            z = w1 * a[2] + w2 * b[2] + (1 - w1 - w2) * c[2]
                            hold((u, v), z - spread, z + spread)
            for key, (low, high) in here.items():
                got = spans.get(key)
                if got is None:
                    spans[key] = [low, high]
                else:
                    got.append(low)
                    got.append(high)
        laid += 1
        for (u, v), zs in spans.items():
            if u < 0 or v < 0:
                continue
            cell = (u // FINE, v // FINE)
            i = (v % FINE) * FINE + u % FINE
            if _F[ground.kind(*cell)] and stopped(zs, ground_height(ground, u, v)):
                if not shut.get(cell, 0) >> i & 1:
                    blocked += 1
                shut[cell] = shut.get(cell, 0) | 1 << i
            heights = over.get(cell)
            if heights and heights[i]:
                left = [h for h in heights[i] if not stopped(zs, h)]
                heights[i] = left or None
                if not any(heights):
                    del over[cell]
    return laid, blocked


def find(store, ground, models, keep, window=None, report=None, places=()):
    shut, over, buried = {}, {}, {}
    count = {"structures": 0, "models": 0, "unplaced": 0, "triangles": 0, "floor": 0, "great": []}
    groups = chains(models)
    for n, pieces in enumerate(groups):
        if window:
            for piece in pieces:
                x0, x1, y0, y1 = 32 * TILE - piece[4], 32 * TILE - piece[2], 32 * TILE - piece[3], 32 * TILE - piece[1]
                if x0 <= window[1] and x1 >= window[0] and y0 <= window[3] and y1 >= window[2]:
                    break
            else:
                continue
        count["structures"] += 1
        floors, obstacles = shapes(store, pieces, count)
        city = great = None
        if floors and any(max(p[3] - p[1], p[4] - p[2]) > BIG for p in pieces):
            great = raised(ground, pieces, floors, obstacles)
            p = pieces[0]
            count["great"].append("a great model, %d, at world (%.0f, %.0f): %.0f%% of the terrain under it dead flat, "
                                  "%.0f%% of its floor walked high: %s" % (
                                      p[0], 32 * TILE - (p[2] + p[4]) / 2, 32 * TILE - (p[1] + p[3]) / 2, great[2] * 100,
                                      great[1] * 100, "A CITY" if great[0] else "not a city"))
        if great and great[0]:
            # (a city stands alone in links.py; here the models at it are walked with it, so that a gatehouse
            # or a bridge that is a model of its own still leads onto the city's floor)
            city = (floors, obstacles)
            x0, z0, x1, z1 = pieces[0][1:5]
            near = [m for m in models.values() if m is not pieces[0] and max(m[3] - m[1], m[4] - m[2]) <= BIG
                    and m[1] <= x1 + TOUCH and m[3] >= x0 - TOUCH and m[2] <= z1 + TOUCH and m[4] >= z0 - TOUCH]
            if near:
                more, stops = shapes(store, near, count)
                obstacles = dict(obstacles)
                for key, zs in stops.items():
                    obstacles[key] = obstacles.get(key, []) + zs
                both = {}
                for key in set(floors) | set(more):
                    zs = obstacles.get(key)
                    hs = sorted(h for h in floors.get(key, []) + more.get(key, []) if not (zs and stopped(zs, h)))
                    if hs:
                        both[key] = hs
                floors, pieces = both, pieces + near
        count["floor"] += walk(ground, pieces, floors, obstacles, shut, over, city, buried)
        if report and n % 25 == 0:
            report(n, len(groups))
    count["scenery"] = scenery(store, ground, places, shut, over, window)
    walls, floors, heights = decide(ground, shut, over, keep, buried)
    closed = pockets(ground, walls, floors, keep)
    heights = {cell: h for cell, h in heights.items() if cell not in walls and (cell in floors or _F[ground.kind(*cell)])}
    return shut, over, walls, floors, heights, closed, count



def splits(ground, shut, over, walls, floors, ring=2, least=2, want_both=False):
    """Where the cells lose a way the one-yard grid has: for each patch of cells a structure touches (and a ring of
    cells round it), the yards open on the grid (terrain the walk reached, any floor) in pieces that touch each other,
    against the cells left a way in pieces that touch each other (eight ways, no corner cut, as the planner walks).
    A piece of yards whose cells fall into two or more pieces of cells (each of `least` cells or more) is a split: a
    bridge, a gate, a dock or a walkway the cells have cut. Yards are joined as the walk joins them (a step of CLIMB at
    most), so a roof or a wall's top is not joined to the street beside it. Returns [(a cell of the smaller piece,
    sizes of the pieces)], the largest first. (Pieces joined by a way round outside the ring count as split.)"""
    touched = set(shut) | set(over)

    def way(cell):
        return cell in floors or (cell not in walls and _F[ground.kind(*cell)])

    def yards_open(cell):
        """{yard: [heights]}: the terrain the walk reached, at its height, and the floors on it"""
        out = {}
        passable = _F[ground.kind(*cell)]
        hs = over.get(cell) if cell in touched else None
        s = (shut.get(cell, 0) if cell in touched else 0) if passable else ALL
        for i in range(FINE * FINE):
            got = list(hs[i]) if hs and hs[i] else []
            if not (s >> i & 1):
                got.append(ground_height(ground, cell[0] * FINE + i % FINE, cell[1] * FINE + i // FINE))
            if got:
                out[i] = got
        return out

    found, done = [], set()
    for start in touched:
        if start in done:
            continue
        area, stack = {start}, [start]                       # a patch of touched cells
        while stack:
            x, y = stack.pop()
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q in touched and q not in area:
                        area.add(q)
                        stack.append(q)
        done |= area
        region = set(area)
        for x, y in area:
            for dx in range(-ring, ring + 1):
                for dy in range(-ring, ring + 1):
                    region.add((x + dx, y + dy))
        # pieces of cells
        piece_of, sizes = {}, []
        for cell in region:
            if cell in piece_of or not way(cell):
                continue
            n = len(sizes)
            piece_of[cell] = n
            stack, size = [cell], 0
            while stack:
                x, y = stack.pop()
                size += 1
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        q = (x + dx, y + dy)
                        if (dx or dy) and q in region and q not in piece_of and way(q) and \
                                (not (dx and dy) or (way((x + dx, y)) and way((x, y + dy)))):
                            piece_of[q] = n
                            stack.append(q)
            sizes.append(size)
        if len(sizes) < 2:
            continue
        # pieces of yards, and the pieces of cells each meets (a cell counts where it holds four of its yards)
        open_ = {}                                  # yard -> (its cell, the heights one can stand at there)
        for cell in region:
            for i, hs in yards_open(cell).items():
                open_[(cell[0] * FINE + i % FINE, cell[1] * FINE + i // FINE)] = (cell, hs)
        seen = set()
        for y0, (_c, hs0) in open_.items():
            for k0 in range(len(hs0)):
                if (y0, k0) in seen:
                    continue
                seen.add((y0, k0))
                stack, count = [(y0, k0)], collections.Counter()
                while stack:
                    (u, v), k = stack.pop()
                    cell, hs = open_[(u, v)]
                    count[cell] += 1
                    h = hs[k]
                    for q in ((u + 1, v), (u - 1, v), (u, v + 1), (u, v - 1)):
                        got = open_.get(q)
                        if got:
                            for kk, hh in enumerate(got[1]):
                                if abs(hh - h) <= CLIMB and (q, kk) not in seen:
                                    seen.add((q, kk))
                                    stack.append((q, kk))
                met = {}
                for cell, n in count.items():
                    if n >= 4 and cell in piece_of:
                        met.setdefault(piece_of[cell], cell)
                big = [(sizes[p], cell) for p, cell in met.items() if sizes[p] >= least]
                if len(big) >= 2:
                    big.sort(reverse=True)
                    found.append((big[-1][1], [s for s, _ in big], big[0][1]))
    found.sort(key=lambda f: -f[1][-1])
    return [(small, sizes) for small, sizes, _large in found] if not want_both else found


def save(map_id, ground, walls, floors, heights):
    """The cells changed, by terrain tile: (the cell's place in the tile, its kind now, its height now in tenths
    of a yard or None for the terrain's own)."""
    tiles = {}
    for cell in set(walls) | floors | set(heights):
        gx, gy = cell
        kind = STEEP if cell in walls else WALK if cell in floors else ground.kind(gx, gy)
        h = heights.get(cell)
        tiles.setdefault((gx >> 7, gy >> 7), []).append(
            ((gy & 127) * 128 + (gx & 127), kind, None if h is None else max(-32000, min(32000, int(round(h * 10))))))
    with open("world/walls_%d.bin" % map_id, "wb") as f:
        f.write(zlib.compress(pickle.dumps({"map": map_id, "tiles": {k: sorted(v) for k, v in tiles.items()}}, protocol=4), 6))


def picture(path, ground, shut, over, walls, floors, window):
    from PIL import Image
    gx0, gx1 = int((32 * TILE - window[3]) / CELL), int((32 * TILE - window[2]) / CELL) + 1
    gy0, gy1 = int((32 * TILE - window[1]) / CELL), int((32 * TILE - window[0]) / CELL) + 1
    px = 2 * FINE
    img = Image.new("RGB", ((gx1 - gx0) * px, (gy1 - gy0) * px))
    at = img.load()
    colours = {WALK: (120, 120, 110), WADE: (70, 110, 150), SWIM: (40, 70, 120), STEEP: (60, 50, 44), NONE: (20, 20, 24)}
    why = {"shut": (150, 50, 45), "edge": (190, 120, 40), "pocket": (110, 60, 120)}
    for gy in range(gy0, gy1):
        for gx in range(gx0, gx1):
            cell = (gx, gy)
            passable = _F[ground.kind(gx, gy)]
            base = why.get(walls.get(cell)) or ((150, 160, 120) if cell in floors else colours[ground.kind(gx, gy)])
            floor = sum(1 << i for i, hs in enumerate(over.get(cell) or ()) if hs)
            mask = (shut.get(cell, 0) if passable else ALL) & ~floor
            if floor and cell not in walls and shut.get(cell, 0) == ALL:
                base = (150, 160, 120)                      # (a floor over terrain that is no ground)
            for i in range(FINE * FINE):
                c = base
                if mask >> i & 1 and (passable or cell in floors or over.get(cell)):
                    c = (25, 25, 25)
                for j in range(4):
                    at[(gx - gx0) * px + (i % FINE) * 2 + j % 2, (gy - gy0) * px + (i // FINE) * 2 + j // 2] = c
    img.save(path)
    print("saved", path, img.size)


def graph(map_id, links=None):
    """world/nav_<id>_linked.bin made again: the graph of the ground with its walls and floors (walls_<id>.bin), the
    links laid on it, and the costs with roads (roads.py's marks; Coarse.add_roads). Returns lines to read."""
    started = time.time()
    links = link_ends(map_id) if links is None else links
    before = Coarse.open("world/nav_%d.bin" % map_id).islands()[1]
    walled = Ground("world/map_%d.bin" % map_id)
    coarse = Coarse.build(walled)
    plain = coarse.islands()[1]
    missed, lines = 0, []
    for a, b, seconds, oneway in links:
        if _F[walled.kind(*a)] and _F[walled.kind(*b)]:
            coarse.add_link(walled, a, b, seconds, oneway)
        else:
            missed += 1
            lines.append("LINK NOT MADE (an end is wall): world (%.0f, %.0f) to (%.0f, %.0f)" % (world_of(*a) + world_of(*b)))
    after = coarse.islands()[1]
    added = coarse.add_roads(walled) if walled.roads else 0
    coarse.save("world/nav_%d_linked.bin" % map_id)
    road_cells = sum(sum(m) for m in walled.roads.values())
    lines += ["links laid on the ground with its walls: %d of %d" % (len(links) - missed, len(links)),
              "largest stretches of the terrain alone:   %s" % before[:8],
              "largest stretches with the walls:         %s" % plain[:8],
              "largest stretches with walls and links:   %s" % after[:8],
              "roads: %d cells marked on ground that can be walked (roads.py, and the floors); %d walks added that are "
              "the cheapest with roads; graph made in %.0fs" % (road_cells, added, time.time() - started), ""]
    return lines


def split_lines(ground, shut, over, walls, floors, most=60):
    found = splits(ground, shut, over, walls, floors)
    lines = ["ways the one-yard grid has and the cells cut (splits): %d; the largest:" % len(found)]
    for cell, sizes in found[:most]:
        lines.append("  split at world (%.0f, %.0f): pieces of %s cells" % (world_of(cell[0] + 0.5, cell[1] + 0.5) + (sizes,)))
    return lines


def check(map_id):
    """walls.py's verdict made again (nothing written but world/splits_<id>.txt): the splits only."""
    store = Storage(r"G:/Games/World of Warcraft", "wowf")
    ground = Ground("world/map_%d.bin" % map_id, walls=False)
    models = placements(store, map_files(store)[map_id])
    places = scenery_placements(store, map_files(store)[map_id])
    shut, over, walls, floors, heights, closed, count = find(store, ground, models, kept(link_ends(map_id)), None, None, places)
    lines = split_lines(ground, shut, over, walls, floors, most=400)
    with open("world/splits_%d.txt" % map_id, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines[:25]))


def main(map_id, window=None, look=None):
    started = time.time()
    store = Storage(r"G:/Games/World of Warcraft", "wowf")
    ground = Ground("world/map_%d.bin" % map_id, walls=False)
    models = placements(store, map_files(store)[map_id])
    places = scenery_placements(store, map_files(store)[map_id])
    links = link_ends(map_id)
    keep = kept(links)

    def report(n, of):
        print("   structure %d of %d, %.0fs" % (n, of, time.time() - started), flush=True)

    shut, over, walls, floors, heights, closed, count = find(store, ground, models, keep, window, None if window else report,
                                                             places)
    kinds = collections.Counter(walls.values())
    lines = ["map %d: %d building models, %d structures read (%d models, %d triangles; %d models left out, their placing "
             "failed its check)" % (map_id, len(models), count["structures"], count["models"], count["triangles"], count["unplaced"]),
             "ground cells with something shut in them: %d; with floor walked over them: %d" % (len(shut), len(over)),
             "made wall: %d cells (shut %d, a wall along the edge %d, in a patch with no way out %d, in %d patches)" % (
                 len(walls), kinds["shut"], kinds["edge"], kinds["pocket"], len(closed)),
             "made ground (floor where the terrain is no way, or over water): %d cells; cells in all whose ground is a "
             "floor, and have its height: %d" % (len(floors), len(heights)),
             "left as they are round the ends of %d links: %d cells" % (len(links), len(keep)),
             "scenery models laid on the ground: %d of %d (the rest have no collision or are narrower than %.1f yards); "
             "yards of terrain they shut: %d" % (count["scenery"][0], len(places), SCENERY, count["scenery"][1])] + count["great"]
    if window:
        print("\n".join(lines))
        if look:
            picture(look, ground, shut, over, walls, floors, window)
        return
    save(map_id, ground, walls, floors, heights)
    lines += split_lines(ground, shut, over, walls, floors)
    lines += graph(map_id, links)
    for patch in sorted(closed, key=len, reverse=True)[:40]:
        x, y = world_of(*patch[len(patch) // 2])
        lines.append("a patch with no way out, %d cells, at world (%.0f, %.0f)" % (len(patch), x, y))
    with open("world/walls_%d.txt" % map_id, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines[:10]))
    print("%.0fs" % (time.time() - started))


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) == 2 and args[1] == "check":                 # only the splits (see splits): world/splits_<id>.txt
        check(int(args[0]))
        raise SystemExit
    if len(args) == 2 and args[1] == "graph":                 # only the graph again (after roads.py, say)
        print("\n".join(graph(int(args[0]))))
        raise SystemExit
    main(int(args[0]), [float(a) for a in args[1:5]] if len(args) >= 5 else None, args[5] if len(args) >= 6 else None)
