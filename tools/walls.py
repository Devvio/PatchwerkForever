"""Walls and floors: what a building does to the ground under it.

world.py knows the terrain only. To the planner a town is then open ground, and a route runs straight
through its houses; and a city that is one great model (its streets are the model's floor, the terrain
far below it flat and empty) is an open plain. This lays the building models on the ground's cells.

    python walls.py 1                                     a whole map
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

Not seen here: small scenery models (a tent, a cart, a tree: they are not building models).
"""
import array
import collections
import os
import pickle
import sys
import time
import zlib

from casc import Storage
from links import BIG, CLIMB, FINE, HEAD, KNEE, ONTO, TOUCH, chains, ground_height, height, shapes
from nav import Coarse, Ground, _F, world_of
from terrain import CELL, TILE
from wmo import placements
from world import NONE, STEEP, SWIM, WADE, WALK, map_files

MARGIN = 3                # ground cells round a structure's boxes that the walk starts from
ENOUGH = FINE * FINE // 2  # a ground cell is a way where its largest open piece has this many yards
SLIVER = 4                # an open piece of a cell this small at most, cut off from the largest, is not counted
GAP = 2.5                 # yards of height with no floor in them, in and round a cell: two floors, not one
STEP = 6.5                # yards: two cells side by side whose floors differ by more are not joined
POCKET = 150              # ground cells: a patch left with no way out is wall if it is no larger (50 yards square)
KEEP = 3                  # ground cells round a link's end that are never wall
ABOVE = 6.0               # yards over dry terrain: floor walked this high is a city's street, and a great model
CITY = 0.3                # with this share of its floor walked so high is a city, where
FLAT = 0.3                # this share of the dry terrain cells under its floor is dead flat (placeholder terrain)
ALL = (1 << FINE * FINE) - 1
F = CELL / FINE
SQ2 = 2.0 ** 0.5
_AROUND = ((1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0), (1, 1, SQ2), (1, -1, SQ2), (-1, 1, SQ2), (-1, -1, SQ2))
_parts = {}


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
        best, start = None, 0
        for n in range(1, len(near) + 1):
            if n == len(near) or near[n] - near[n - 1] > GAP:
                low, high = near[start], near[n - 1]
                if any(low <= h <= high for h in mine) and (best is None or n - start > best[0]):
                    best = (n - start, low, high)
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

    def apart(a, b):
        """Of two cells whose ground is floor alone, the floors too far apart in height to be joined: the one
        with less of its floor round it (the narrower way)."""
        if on_floor_only(a) and on_floor_only(b) and abs(level[a] - level[b]) > STEP:
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
            loser = lower or (cell if mine[1] >= theirs[1] else other)
            if loser in keep:
                loser = other if loser == cell else cell
            if loser in keep:
                continue
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


def find(store, ground, models, keep, window=None, report=None):
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
    walls, floors, heights = decide(ground, shut, over, keep, buried)
    closed = pockets(ground, walls, floors, keep)
    heights = {cell: h for cell, h in heights.items() if cell not in walls and (cell in floors or _F[ground.kind(*cell)])}
    return shut, over, walls, floors, heights, closed, count


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


def main(map_id, window=None, look=None):
    started = time.time()
    store = Storage(r"G:/Games/World of Warcraft", "wowf")
    ground = Ground("world/map_%d.bin" % map_id, walls=False)
    models = placements(store, map_files(store)[map_id])
    links = link_ends(map_id)
    keep = kept(links)

    def report(n, of):
        print("   structure %d of %d, %.0fs" % (n, of, time.time() - started), flush=True)

    shut, over, walls, floors, heights, closed, count = find(store, ground, models, keep, window, None if window else report)
    kinds = collections.Counter(walls.values())
    lines = ["map %d: %d building models, %d structures read (%d models, %d triangles; %d models left out, their placing "
             "failed its check)" % (map_id, len(models), count["structures"], count["models"], count["triangles"], count["unplaced"]),
             "ground cells with something shut in them: %d; with floor walked over them: %d" % (len(shut), len(over)),
             "made wall: %d cells (shut %d, a wall along the edge %d, in a patch with no way out %d, in %d patches)" % (
                 len(walls), kinds["shut"], kinds["edge"], kinds["pocket"], len(closed)),
             "made ground (floor where the terrain is no way, or over water): %d cells; cells in all whose ground is a "
             "floor, and have its height: %d" % (len(floors), len(heights)),
             "left as they are round the ends of %d links: %d cells" % (len(links), len(keep))] + count["great"]
    if window:
        print("\n".join(lines))
        if look:
            picture(look, ground, shut, over, walls, floors, window)
        return
    save(map_id, ground, walls, floors, heights)
    before = Coarse.open("world/nav_%d.bin" % map_id).islands()[1]
    walled = Ground("world/map_%d.bin" % map_id)
    coarse = Coarse.build(walled)
    plain = coarse.islands()[1]
    missed = 0
    for a, b, seconds, oneway in links:
        if _F[walled.kind(*a)] and _F[walled.kind(*b)]:
            coarse.add_link(walled, a, b, seconds, oneway)
        else:
            missed += 1
            lines.append("LINK NOT MADE (an end is wall): world (%.0f, %.0f) to (%.0f, %.0f)" % (world_of(*a) + world_of(*b)))
    after = coarse.islands()[1]
    coarse.save("world/nav_%d_linked.bin" % map_id)
    lines += ["links laid on the ground with its walls: %d of %d" % (len(links) - missed, len(links)),
              "largest stretches of the terrain alone:   %s" % before[:8],
              "largest stretches with the walls:         %s" % plain[:8],
              "largest stretches with walls and links:   %s" % after[:8], ""]
    for patch in sorted(closed, key=len, reverse=True)[:40]:
        x, y = world_of(*patch[len(patch) // 2])
        lines.append("a patch with no way out, %d cells, at world (%.0f, %.0f)" % (len(patch), x, y))
    with open("world/walls_%d.txt" % map_id, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines[:10]))
    print("%.0fs" % (time.time() - started))


if __name__ == "__main__":
    args = sys.argv[1:]
    main(int(args[0]), [float(a) for a in args[1:5]] if len(args) >= 5 else None, args[5] if len(args) >= 6 else None)
