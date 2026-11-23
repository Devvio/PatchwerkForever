"""Route planning over the extracted ground: the offline prototype.

The ground is a grid of 4.17-yard cells (world.py). Searching it cell by cell
is fine for a few hundred yards and hopeless across a continent, so the grid is
cut into blocks of BLOCK x BLOCK cells and a coarse graph is built over them:

  * a *gate* wherever two neighbouring blocks touch along passable cells (a
    long open border gets several), as a node on each side;
  * inside each block, the cost of the cheapest walk between each pair of its
    gates, found once, here.

A route is then: from the start to its block's gates (a search inside one
block), across the coarse graph (A*), and from the goal's block's gates to the
goal. The cells in between are worked out block by block only when wanted (to
draw it).

Costs are seconds at running speed. A character runs as fast uphill as on the
flat, so slope does not cost; water does.

Global cell coordinates: gx counts east, gy south, from the map's north-west
corner; a tile is 128 cells, a block BLOCK.
    gx = (32 * TILE - world_y) / CELL      gy = (32 * TILE - world_x) / CELL
"""
import heapq
import math
import os
import pickle
import time
import zlib
from collections import defaultdict

from terrain import TILE, CELL
from world import NONE, WALK, STEEP, WADE, SWIM, load

BLOCK = 32                      # cells: 133 yards
SPEED = 7.0                     # yards a second, running
STEP = CELL / SPEED             # seconds a cell
SQ2 = math.sqrt(2.0)
FACTOR = {WALK: 1.0, WADE: 1.25, SWIM: 3.0}     # swimming is 1.5 times slower, and priced at twice that: a route
                                                # swims a river, and goes a long way round before it swims a coast
AIR_SPEED = 32.0                # yards a second on a flight (flights.py)
BOARD, LAND = 15.0, 3.0         # seconds to talk to a flight master and take off; to land and dismount
INDOORS = 25.0                  # a flight point this far above or below our ground stands in a building
CLIMB_RUN = 4.0                 # yards walked for each yard climbed up a tower to a flight master (a guess)
DOUBT_YARDS = 300.0             # a route that swims more than this, or
DOUBT_SHARE = 0.25              # this share of its length, is reported as doubtful
GATE_EVERY = 16                 # cells of open border a gate
WATER_REACH = 2                 # blocks of open water kept beyond the last land

_F = [0.0] * 256
for _k, _v in FACTOR.items():
    _F[_k] = _v
_NEIGHBOURS = ((1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0),
               (1, 1, SQ2), (1, -1, SQ2), (-1, 1, SQ2), (-1, -1, SQ2))


def cell_of(world_x, world_y):
    return (32 * TILE - world_y) / CELL, (32 * TILE - world_x) / CELL


def world_of(gx, gy):
    return 32 * TILE - gy * CELL, 32 * TILE - gx * CELL


class Ground:
    """The cells of a map, a tile at a time."""

    def __init__(self, path, walls=True):
        # (walls: with the buildings' walls laid on the terrain, where walls.py has found them)
        info = load(path, walls)
        self.map = info["map"]
        self.tiles = {key: cells for key, (cells, _heights) in info["tiles"].items()}
        self.heights = {key: heights for key, (_cells, heights) in info["tiles"].items()}

    def kind(self, gx, gy):
        cells = self.tiles.get((gx >> 7, gy >> 7))
        return cells[(gy & 127) * 128 + (gx & 127)] if cells else NONE

    def block(self, bx, by):
        """The block's 32 rows of 32 cells, or None off the map."""
        cells = self.tiles.get((bx >> 2, by >> 2))
        if not cells:
            return None
        r0, c0 = (by & 3) * BLOCK, (bx & 3) * BLOCK
        return [cells[(r0 + r) * 128 + c0: (r0 + r) * 128 + c0 + BLOCK] for r in range(BLOCK)]


def _spread(rows, r0, c0, limit=None, targets=None):
    """Cheapest cost from (r0, c0) to every cell of a block it can reach; with `targets`, stops once all are found.

    Returns (cost list of BLOCK*BLOCK, parent list)."""
    n = BLOCK
    inf = float("inf")
    cost = [inf] * (n * n)
    parent = [-1] * (n * n)
    start = r0 * n + c0
    cost[start] = 0.0
    heap = [(0.0, start)]
    left = set(targets) if targets else None
    F = _F
    while heap:
        d, at = heapq.heappop(heap)
        if d > cost[at]:
            continue
        if left is not None:
            left.discard(at)
            if not left:
                break
        r, c = divmod(at, n)
        here = F[rows[r][c]]
        for dr, dc, length in _NEIGHBOURS:
            rr, cc = r + dr, c + dc
            if rr < 0 or cc < 0 or rr >= n or cc >= n:
                continue
            f = F[rows[rr][cc]]
            if not f:
                continue
            if dr and dc and not (F[rows[r][cc]] and F[rows[rr][c]]):
                continue                                    # no cutting a blocked corner
            nd = d + STEP * length * (here + f) / 2.0
            to = rr * n + cc
            if nd < cost[to]:
                cost[to] = nd
                parent[to] = at
                heapq.heappush(heap, (nd, to))
    return cost, parent


def _octile(r0, c0, r1, c1):
    dr, dc = abs(r1 - r0), abs(c1 - c0)
    return (max(dr, dc) + (SQ2 - 1.0) * min(dr, dc)) * STEP


class Coarse:
    """The coarse graph of a map."""

    def __init__(self):
        self.nodes = []                      # (bx, by, r, c): a gate's cell
        self.edges = []                      # per node: {other node: seconds}
        self.of_block = defaultdict(list)    # (bx, by) -> its gates

    def _node(self, bx, by, r, c):
        key = (bx, by, r, c)
        i = self._index.get(key)
        if i is None:
            i = len(self.nodes)
            self._index[key] = i
            self.nodes.append(key)
            self.edges.append({})
            self.of_block[(bx, by)].append(i)
        return i

    def _link(self, a, b, cost):
        if a != b and cost < self.edges[a].get(b, float("inf")):
            self.edges[a][b] = cost
            self.edges[b][a] = cost

    @classmethod
    def build(cls, ground, tiles=None, report=None):
        """tiles: (tx0, ty0, tx1, ty1) to build a part only."""
        self = cls()
        self._index = {}
        blocks, land = {}, set()
        for (tx, ty) in ground.tiles:
            if tiles and not (tiles[0] <= tx <= tiles[2] and tiles[1] <= ty <= tiles[3]):
                continue
            for by in range(ty * 4, ty * 4 + 4):
                for bx in range(tx * 4, tx * 4 + 4):
                    rows = ground.block(bx, by)
                    kinds = set(b"".join(rows))
                    if kinds & {WALK, WADE, SWIM}:
                        blocks[(bx, by)] = rows
                        if kinds & {WALK, WADE}:
                            land.add((bx, by))
        # open water far from any land is left out: nobody swims the ocean
        keep = set(land)
        edge = set(land)
        for _ in range(WATER_REACH):
            grown = set()
            for (bx, by) in edge:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        k = (bx + dx, by + dy)
                        if k in blocks and k not in keep:
                            grown.add(k)
            keep |= grown
            edge = grown
        self.blocks = len(keep)
        F = _F
        # gates
        for (bx, by) in keep:
            rows = blocks[(bx, by)]
            for other, mine, theirs in (((bx + 1, by), lambda i: (i, BLOCK - 1), lambda i: (i, 0)),
                                        ((bx, by + 1), lambda i: (BLOCK - 1, i), lambda i: (0, i))):
                if other not in keep:
                    continue
                orows = blocks[other]
                i = 0
                while i < BLOCK:
                    r, c = mine(i)
                    rr, cc = theirs(i)
                    if not (F[rows[r][c]] and F[orows[rr][cc]]):
                        i += 1
                        continue
                    j = i
                    while j + 1 < BLOCK:
                        r2, c2 = mine(j + 1)
                        rr2, cc2 = theirs(j + 1)
                        if not (F[rows[r2][c2]] and F[orows[rr2][cc2]]):
                            break
                        j += 1
                    length = j - i + 1
                    count = max(1, int(round(length / float(GATE_EVERY))))
                    for k in range(count):
                        at = i + (length * (2 * k + 1)) // (2 * count)
                        r, c = mine(at)
                        rr, cc = theirs(at)
                        a = self._node(bx, by, r, c)
                        b = self._node(other[0], other[1], rr, cc)
                        self._link(a, b, STEP * (F[rows[r][c]] + F[orows[rr][cc]]) / 2.0)
                    i = j + 1
        # inside each block: gate to gate
        done = 0
        for key, ids in self.of_block.items():
            rows = blocks[key]
            if len(ids) < 2:
                continue
            kinds = set(b"".join(rows))
            table = {}
            if len(kinds) == 1:                              # all one kind: straight across
                f = F[next(iter(kinds))]
                for x in range(len(ids)):
                    _, _, r0, c0 = self.nodes[ids[x]]
                    for y in range(x + 1, len(ids)):
                        _, _, r1, c1 = self.nodes[ids[y]]
                        table[(x, y)] = _octile(r0, c0, r1, c1) * f
            else:
                cells = [self.nodes[i][2] * BLOCK + self.nodes[i][3] for i in ids]
                for x in range(len(ids) - 1):
                    cost, _ = _spread(rows, self.nodes[ids[x]][2], self.nodes[ids[x]][3], targets=cells[x + 1:])
                    for y in range(x + 1, len(ids)):
                        if cost[cells[y]] < float("inf"):
                            table[(x, y)] = cost[cells[y]]
            get = lambda x, y: table.get((x, y) if x < y else (y, x))
            for (x, y), d in table.items():
                # a link that two shorter ones replace as well is left out
                redundant = False
                for m in range(len(ids)):
                    if m != x and m != y:
                        d1, d2 = get(x, m), get(m, y)
                        if d1 is not None and d2 is not None and d1 < d and d2 < d and d1 + d2 <= d * 1.01:
                            redundant = True
                            break
                if not redundant:
                    self._link(ids[x], ids[y], d)
            done += 1
            if report and done % 2000 == 0:
                report(done, len(self.of_block))
        del self._index
        return self

    def gate_at(self, ground, cell):
        """A gate at this cell (a new one, joined to its block's other gates, if there is none)."""
        if not hasattr(self, "_index"):
            self._index = {node: i for i, node in enumerate(self.nodes) if i not in getattr(self, "air", ())}
        gx, gy = cell
        block = (gx // BLOCK, gy // BLOCK)
        r, c = gy % BLOCK, gx % BLOCK
        known = (block[0], block[1], r, c) in self._index
        others = list(self.of_block.get(block, ()))
        i = self._node(block[0], block[1], r, c)
        if not known:
            spread, _ = _spread(ground.block(*block), r, c)
            for other in others:
                d = spread[self.nodes[other][2] * BLOCK + self.nodes[other][3]]
                if d < float("inf"):
                    self._link(i, other, d)
        return i

    def add_link(self, ground, a, b, cost, oneway=False):
        """A way the terrain does not show (a tunnel, a bridge, a lift) between two cells, as two new gates.

        oneway: only from a to b (a drop that can be jumped down and not climbed)."""
        ends = [self.gate_at(ground, a), self.gate_at(ground, b)]
        if oneway:
            if cost < self.edges[ends[0]].get(ends[1], float("inf")):
                self.edges[ends[0]][ends[1]] = cost
        else:
            self._link(ends[0], ends[1], cost)
        return ends

    def add_flights(self, ground, flights, side, known=None):
        """The flight points of one side ("alliance", "horde") on this map, and the flights between them.

        known: the flight points the character has (ids), or None for all. Each point becomes two nodes: one on
        the ground beside the flight master, one in the air above. Boarding and landing join the two, flights
        join the air nodes, so a flight through several points pays for boarding once.
        A flight master on a tower (well above our ground) is joined to the ground below with a guessed climb.
        One far below our ground is inside a mountain or under a city: it is flown through, but not walked to.
        Returns the points this was done for: [(name, what)]."""
        self.air, self.air_cells, left = {}, [], []
        nodes = {i: n for i, n in flights["nodes"].items()
                 if n["map"] == ground.map and side in n["sides"] and (known is None or i in known)}
        of = {}
        for i, n in sorted(nodes.items()):
            at, cell, why, climb, note = flight_spot(ground, n)
            if note:
                left.append((n["name"], note))
            air = len(self.nodes)
            self.nodes.append((at[0] // BLOCK, at[1] // BLOCK, at[1] % BLOCK, at[0] % BLOCK))
            self.edges.append({})
            self.air[air] = i
            of[i] = air
            if why:
                left.append((n["name"], why))
                continue
            gate = self.gate_at(ground, cell)
            self.edges[gate][air] = BOARD + climb
            self.edges[air][gate] = LAND + climb
            self.air_cells.append(cell)
        for (a, b), path in flights["paths"].items():
            if a in of and b in of:
                self.edges[of[a]][of[b]] = path["seconds"]
        return left

    # ---- files ----------------------------------------------------------
    def save(self, path):
        with open(path, "wb") as f:
            f.write(zlib.compress(pickle.dumps({"nodes": self.nodes, "edges": self.edges, "blocks": self.blocks}, protocol=4), 6))

    @classmethod
    def open(cls, path):
        with open(path, "rb") as f:
            data = pickle.loads(zlib.decompress(f.read()))
        self = cls()
        self.nodes, self.edges, self.blocks = data["nodes"], data["edges"], data["blocks"]
        for i, (bx, by, _r, _c) in enumerate(self.nodes):
            self.of_block[(bx, by)].append(i)
        return self

    def stats(self):
        links = sum(len(e) for e in self.edges) // 2
        return "%d blocks, %d gates, %d links" % (self.blocks, len(self.nodes), links)

    def islands(self):
        """Which gates can reach which: {node: island number}, islands numbered biggest first."""
        seen, groups = {}, []
        for start in range(len(self.nodes)):
            if start in seen:
                continue
            group, stack = [start], [start]
            seen[start] = len(groups)
            while stack:
                at = stack.pop()
                for other in self.edges[at]:
                    if other not in seen:
                        seen[other] = len(groups)
                        group.append(other)
                        stack.append(other)
            groups.append(group)
        order = sorted(range(len(groups)), key=lambda g: -len(groups[g]))
        rank = {g: n for n, g in enumerate(order)}
        return {node: rank[g] for node, g in seen.items()}, [len(groups[g]) for g in order]


def flight_spot(ground, n):
    """Where a flight point stands on our ground: (its cell, the walkable cell beside it or None, why not, the
    seconds allowed for climbing a tower to it, a note)."""
    gx, gy = (int(v) for v in cell_of(n["x"], n["y"]))
    cell = nearest_passable(ground, gx, gy, reach=8)
    why, climb, note = None, 0.0, None
    if not cell:
        why = "flown through only: no walkable ground within 35 yards"
    else:
        heights = ground.heights[(cell[0] >> 7, cell[1] >> 7)]
        off = n["z"] - heights[(cell[1] & 127) * 128 + (cell[0] & 127)] / 10.0
        if off < -INDOORS:
            why = "flown through only: it is %.0f yards below our ground, inside something" % -off
            cell = None
        elif off > INDOORS:
            climb = off * CLIMB_RUN / SPEED
            note = "on a tower %.0f yards up: %.0f s allowed for the climb, a guess" % (off, climb)
    return cell or (gx, gy), cell, why, climb, note


def nearest_passable(ground, gx, gy, reach=40):
    gx, gy = int(gx), int(gy)
    if _F[ground.kind(gx, gy)]:
        return gx, gy
    for radius in range(1, reach + 1):
        best = None
        for dx in range(-radius, radius + 1):
            for dy in (-radius, radius):
                for x, y in ((gx + dx, gy + dy), (gx + dy, gy + dx)):
                    if _F[ground.kind(x, y)]:
                        d = (x - gx) ** 2 + (y - gy) ** 2
                        if best is None or d < best[0]:
                            best = (d, x, y)
        if best:
            return best[1], best[2]
    return None


def route(ground, coarse, start, goal):
    """start, goal: global cells. Returns {"cost", "gates", "expanded", "seconds"} or None when there is no way."""
    began = time.perf_counter()
    sx, sy = start
    gx, gy = goal
    sblock, gblock = (sx // BLOCK, sy // BLOCK), (gx // BLOCK, gy // BLOCK)
    srows, grows = ground.block(*sblock), ground.block(*gblock)
    scost, _ = _spread(srows, sy % BLOCK, sx % BLOCK)
    gcost, _ = _spread(grows, gy % BLOCK, gx % BLOCK)
    nodes, edges = coarse.nodes, coarse.edges
    goal_leg = {}
    for i in coarse.of_block.get(gblock, ()):
        d = gcost[nodes[i][2] * BLOCK + nodes[i][3]]
        if d < float("inf"):
            goal_leg[i] = d
    best_direct = scost[(gy % BLOCK) * BLOCK + gx % BLOCK] if sblock == gblock else float("inf")

    # the least a route can still cost from a gate: on foot straight to the goal, or, with flights, flying
    # straight there and then walking from the flight point nearest the goal
    air = getattr(coarse, "air_cells", None)
    last_walk = min(math.hypot(x - gx, y - gy) for x, y in air) * STEP if air else 0.0
    fly = CELL / AIR_SPEED

    def guess(i):
        bx, by, r, c = nodes[i]
        d = math.hypot(bx * BLOCK + c - gx, by * BLOCK + r - gy)
        return min(d * STEP, max(last_walk, d * fly)) if air else d * STEP

    dist, parent, heap = {}, {}, []
    for i in coarse.of_block.get(sblock, ()):
        d = scost[nodes[i][2] * BLOCK + nodes[i][3]]
        if d < float("inf"):
            dist[i] = d
            parent[i] = -1
            heapq.heappush(heap, (d + guess(i), d, i))
    expanded, best, best_node = 0, best_direct, None
    while heap:
        f, d, at = heapq.heappop(heap)
        if d > dist[at]:
            continue
        if f >= best:
            break
        expanded += 1
        if at in goal_leg and d + goal_leg[at] < best:
            best, best_node = d + goal_leg[at], at
        for other, cost in edges[at].items():
            nd = d + cost
            if nd < dist.get(other, float("inf")):
                dist[other] = nd
                parent[other] = at
                heapq.heappush(heap, (nd + guess(other), nd, other))
    if best == float("inf"):
        return None
    gates = []
    at = best_node
    while at is not None and at != -1:
        gates.append(at)
        at = parent[at]
    gates.reverse()
    return {"cost": best, "gates": gates, "expanded": expanded, "seconds": time.perf_counter() - began}


def cells_of(ground, coarse, start, goal, found):
    """The route cell by cell: [(gx, gy), ...]."""
    def inside(block, a, b):
        rows = ground.block(*block)
        target = b[1] * BLOCK + b[0]
        _, parent = _spread(rows, a[1], a[0], targets=[target])
        out, at = [], target
        while at != -1:
            out.append((block[0] * BLOCK + at % BLOCK, block[1] * BLOCK + at // BLOCK))
            at = parent[at]
        out.reverse()
        return out

    points = [start]
    for i in found["gates"]:
        bx, by, r, c = coarse.nodes[i]
        points.append((bx * BLOCK + c, by * BLOCK + r))
    points.append(goal)
    out = [start]
    for a, b in zip(points, points[1:]):
        ablock, bblock = (a[0] // BLOCK, a[1] // BLOCK), (b[0] // BLOCK, b[1] // BLOCK)
        if ablock == bblock:
            walk = inside(ablock, (a[0] % BLOCK, a[1] % BLOCK), (b[0] % BLOCK, b[1] % BLOCK))
            out.extend(walk[1:] if len(walk) > 1 or a == b else [b])     # no walk between them: a link
        else:
            out.append(b)
    return out


def flown(coarse, found):
    """The flights a route takes: [[flight point id, id, ...], ...], one list a flight (boarding to landing)."""
    air = getattr(coarse, "air", {})
    out, now = [], None
    for i in found["gates"]:
        if i in air:
            if now is None:
                now = []
                out.append(now)
            now.append(air[i])
        else:
            now = None
    return [f for f in out if len(f) > 1]


def swimming(ground, cells):
    """How much of a route (its cells) is swum: (yards swum, yards in all, doubtful or not).

    A link the terrain does not show (a tunnel) is a jump between two cells; its length counts as walked."""
    swum = total = 0.0
    for (ax, ay), (bx, by) in zip(cells, cells[1:]):
        length = math.hypot(bx - ax, by - ay) * CELL
        total += length
        if ground.kind(ax, ay) == SWIM and ground.kind(bx, by) == SWIM:
            swum += length
    return swum, total, swum > DOUBT_YARDS or (total > 0 and swum / total > DOUBT_SHARE)


def exact(ground, start, goal, margin=200):
    """The cheapest route cell by cell over the whole grid (slow): the yardstick. Returns (cost, cells) or None."""
    sx, sy = start
    gx, gy = goal
    x0, x1 = min(sx, gx) - margin, max(sx, gx) + margin
    y0, y1 = min(sy, gy) - margin, max(sy, gy) + margin
    kind, F = ground.kind, _F
    dist, parent = {start: 0.0}, {start: None}
    heap = [(math.hypot(gx - sx, gy - sy) * STEP, 0.0, start)]
    while heap:
        _, d, at = heapq.heappop(heap)
        if at == goal:
            cells = []
            while at:
                cells.append(at)
                at = parent[at]
            return d, cells[::-1]
        if d > dist[at]:
            continue
        x, y = at
        here = F[kind(x, y)]
        for dy, dx, length in _NEIGHBOURS:
            nx, ny = x + dx, y + dy
            if nx < x0 or nx > x1 or ny < y0 or ny > y1:
                continue
            f = F[kind(nx, ny)]
            if not f or (dx and dy and not (F[kind(nx, y)] and F[kind(x, ny)])):
                continue
            nd = d + STEP * length * (here + f) / 2.0
            if nd < dist.get((nx, ny), float("inf")):
                dist[(nx, ny)] = nd
                parent[(nx, ny)] = at
                heapq.heappush(heap, (nd + math.hypot(gx - nx, gy - ny) * STEP, nd, (nx, ny)))
    return None
