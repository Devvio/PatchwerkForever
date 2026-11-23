"""Find the ways the terrain does not show: tunnels, bridges, gatehouses.

The terrain files list every building model standing on the map (a bridge, a
tunnel piece, a gatehouse, a whole city). For each structure (models whose
boxes touch are one: a long tunnel is several pieces end to end):

  * the ground in and beside its boxes falls into separate patches (a tunnel
    has one at each mouth);
  * the models' own collision shapes are read, and their floors laid on a grid
    of one-yard cells, with their walls and low ceilings as obstacles;
  * a link is made between two patches only where a character can walk from
    one onto the floors, over them, and off onto the other, and only where the
    way round over the ground is missing or much longer.

So a link is a walk over real floors, with its real length. Nothing is guessed
from a box.

    python links.py 0                              a whole map
    python links.py 0 -6300 -3500 -4500 -1500      only structures in this part (world X from, to; world Y from, to)

reads world/nav_<id>.bin (the terrain only, left as it is), writes world/links_<id>.txt
(every link, to read and check), world/links_<id>.bin (the links, for walls.py) and
world/nav_<id>_linked.bin (the terrain's graph with the links). walls.py comes after: it lays the
buildings' walls on the ground and writes nav_<id>_linked.bin again, with the walls and these links.

Not found here: lifts and boats (they are not building models), bridges that
are small scenery models rather than building models, and doors: a walk through
a gate that the game keeps locked is still a link.

Ways the files do not describe are added by hand in hand_links.txt (a lift: where
it is boarded, where it is left, and how long the ride takes).
"""
import heapq
import math
import os
import pickle
import sys
import time

from casc import Storage
from nav import Ground, Coarse, BLOCK, _F, world_of, cell_of, nearest_passable, route
from terrain import CELL, TILE
from wmo import placements, model, placing
from world import map_files

FINE = 4                  # floor cells a ground cell, each way: about a yard
F = CELL / FINE
MIN_PATCH = 4             # ground cells at a structure before they count as a patch (17 yards square in all)
MARGIN = 3                # ground cells round a model's box
TOUCH = 6.0               # yards: boxes this near each other are pieces of one structure
BIG = 450.0               # yards: a box larger than this (a city) is not chained with others
FLOOR = math.cos(math.radians(50.0))      # a triangle less steep than 50 degrees is floor
CLIMB = 1.4               # yards a character steps up or down from one floor cell to the next
ONTO = 1.0                # yards between a floor and the ground under or over it where one is stepped onto from the other
KNEE, HEAD = 0.6, 1.9     # an obstacle between these heights above the feet stops a character
MAX_YARDS = 1500.0        # the longest link
SHORTCUT = 3.0            # a link is made where the way round is this many times longer, and
SAVING = 250.0            # at least this many yards longer (or there is no way round)
PRICE = 1.1               # a link's seconds: its length over the floors at running speed, times this
SQ2 = math.sqrt(2.0)
_AROUND = ((1, 0, 1.0), (-1, 0, 1.0), (0, 1, 1.0), (0, -1, 1.0), (1, 1, SQ2), (1, -1, SQ2), (-1, 1, SQ2), (-1, -1, SQ2))


class Labels:
    """Which connected stretch each cell belongs to (its island's rank, -1 for none)."""

    def __init__(self, ground, coarse):
        self.ground, self.coarse = ground, coarse
        self.island, self.sizes = coarse.islands()
        self._blocks = {}

    def _block(self, key):
        labels = self._blocks.get(key)
        if labels is not None:
            return labels
        rows = self.ground.block(*key)
        n = BLOCK
        labels = [-1] * (n * n)
        if rows:
            gates = {self.coarse.nodes[i][2] * n + self.coarse.nodes[i][3]: self.island[i]
                     for i in self.coarse.of_block.get(key, ())}
            seen = [False] * (n * n)
            for start in range(n * n):
                if seen[start] or not _F[rows[start // n][start % n]]:
                    continue
                group, stack, rank = [start], [start], -1
                seen[start] = True
                while stack:
                    at = stack.pop()
                    if at in gates and (rank < 0 or gates[at] < rank):
                        rank = gates[at]
                    r, c = divmod(at, n)
                    for dr in (-1, 0, 1):
                        for dc in (-1, 0, 1):
                            rr, cc = r + dr, c + dc
                            if not (dr or dc) or rr < 0 or cc < 0 or rr >= n or cc >= n:
                                continue
                            to = rr * n + cc
                            if seen[to] or not _F[rows[rr][cc]]:
                                continue
                            if dr and dc and not (_F[rows[r][cc]] and _F[rows[rr][c]]):
                                continue
                            seen[to] = True
                            group.append(to)
                            stack.append(to)
                for at in group:
                    labels[at] = rank
        self._blocks[key] = labels
        return labels

    def of(self, gx, gy):
        if gx < 0 or gy < 0:
            return -1
        return self._block((gx // BLOCK, gy // BLOCK))[(gy % BLOCK) * BLOCK + gx % BLOCK]


def height(ground, gx, gy):
    h = ground.heights.get((gx >> 7, gy >> 7))
    return h[(gy & 127) * 128 + (gx & 127)] / 10.0 if h else 0.0


def ground_height(ground, u, v):
    """The ground's height at a floor cell, between the ground cells' middles."""
    cx, cy = (u + 0.5) / FINE - 0.5, (v + 0.5) / FINE - 0.5
    x0, y0 = int(math.floor(cx)), int(math.floor(cy))
    fx, fy = cx - x0, cy - y0
    top = height(ground, x0, y0) * (1 - fx) + height(ground, x0 + 1, y0) * fx
    bottom = height(ground, x0, y0 + 1) * (1 - fx) + height(ground, x0 + 1, y0 + 1) * fx
    return top * (1 - fy) + bottom * fy


def chains(models):
    """Models grouped into structures: boxes that touch are one. A city-sized box stands alone."""
    items = [m for _uid, m in sorted(models.items())]
    parent = list(range(len(items)))

    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    small = [i for i, m in enumerate(items) if max(m[3] - m[1], m[4] - m[2]) <= BIG]
    small.sort(key=lambda i: items[i][1])
    for n, i in enumerate(small):
        _, x0, z0, x1, z1, y0, y1 = items[i][:7]
        for j in small[n + 1:]:
            _, ox0, oz0, ox1, oz1, oy0, oy1 = items[j][:7]
            if ox0 > x1 + TOUCH:
                break
            if oz0 <= z1 + TOUCH and oz1 >= z0 - TOUCH and oy0 <= y1 + TOUCH and oy1 >= y0 - TOUCH:
                parent[root(i)] = root(j)
    groups = {}
    for i in range(len(items)):
        groups.setdefault(root(i), []).append(items[i])
    return list(groups.values())


def patches_of(ground, pieces):
    """The separate patches of walkable ground in and beside a structure's boxes: lists of ground cells."""
    cells = set()
    for piece in pieces:
        x0, z0, x1, z1 = piece[1:5]
        for gy in range(int(z0 / CELL) - MARGIN, int(z1 / CELL) + MARGIN + 1):
            for gx in range(int(x0 / CELL) - MARGIN, int(x1 / CELL) + MARGIN + 1):
                if _F[ground.kind(gx, gy)]:
                    cells.add((gx, gy))
    patches = []
    while cells:
        start = cells.pop()
        patch, stack = [start], [start]
        while stack:
            x, y = stack.pop()
            for dx, dy, _ in _AROUND:
                to = (x + dx, y + dy)
                if to in cells and not (dx and dy and not (_F[ground.kind(x + dx, y)] and _F[ground.kind(x, y + dy)])):
                    cells.discard(to)
                    patch.append(to)
                    stack.append(to)
        if len(patch) >= MIN_PATCH:
            patches.append(patch)
    return patches


def shapes(store, pieces, count):
    """A structure's floors and obstacles on the floor grid.

    floors: {cell key: [height, ...]}; obstacles: {cell key: [low, high, low, high, ...]}; key = u << 16 | v."""
    floors, obstacles = {}, {}
    for piece in pieces:
        to = placing(store, piece)
        if not to:
            count["unplaced"] += 1
            continue
        count["models"] += 1
        for verts, tris in model(store, piece[0])[1]:
            pts = []
            for lx, ly, lz in verts:
                x, z, y = to(lx, ly, lz)
                pts.append((x / F, z / F, y))
            count["triangles"] += len(tris)
            for i, j, k in tris:
                a, b, c = pts[i], pts[j], pts[k]
                e1u, e1v, e1z = (b[0] - a[0]) * F, (b[1] - a[1]) * F, b[2] - a[2]
                e2u, e2v, e2z = (c[0] - a[0]) * F, (c[1] - a[1]) * F, c[2] - a[2]
                nx, ny, nz = e1v * e2z - e1z * e2v, e1z * e2u - e1u * e2z, e1u * e2v - e1v * e2u
                size = math.sqrt(nx * nx + ny * ny + nz * nz)
                if size < 1e-9:
                    continue
                up = -nz / size                        # the grid is a mirror image of the world: the sign turns
                if up >= FLOOR:
                    _fill(a, b, c, floors, None, 0.0)
                    continue
                low, high = min(a[2], b[2], c[2]), max(a[2], b[2], c[2])
                u0, u1 = int(min(a[0], b[0], c[0])), int(max(a[0], b[0], c[0]))
                v0, v1 = int(min(a[1], b[1], c[1])), int(max(a[1], b[1], c[1]))
                if u1 - u0 <= 1 and v1 - v0 <= 1:       # a small piece of wall: the cells it touches
                    for u in range(u0, u1 + 1):
                        for v in range(v0, v1 + 1):
                            zs = obstacles.get((u << 16) | v)
                            if zs is None:
                                obstacles[(u << 16) | v] = [low, high]
                            else:
                                zs.append(low)
                                zs.append(high)
                    continue
                mine = {}
                spread = 0.0
                if abs(nz) > 1e-6:
                    spread = min(high - low, (abs(nx) + abs(ny)) / abs(nz) * F * 0.5)
                _fill(a, b, c, None, mine, spread)
                for p, q in ((a, b), (b, c), (c, a)):   # along its edges, so a wall seen edge-on is not missed
                    steps = int(max(abs(q[0] - p[0]), abs(q[1] - p[1])) * 2) + 1
                    for s in range(steps + 1):
                        t = s / steps
                        key = (int(p[0] + (q[0] - p[0]) * t) << 16) | int(p[1] + (q[1] - p[1]) * t)
                        z = p[2] + (q[2] - p[2]) * t
                        r = mine.get(key)
                        if r is None:
                            mine[key] = [z, z]
                        elif z < r[0]:
                            r[0] = z
                        elif z > r[1]:
                            r[1] = z
                for key, (z0, z1) in mine.items():
                    zs = obstacles.get(key)
                    if zs is None:
                        obstacles[key] = [max(low, z0), min(high, z1)]
                    else:
                        zs.append(max(low, z0))
                        zs.append(min(high, z1))
    # floors: one height where several triangles overlap, and none where an obstacle stands
    out = {}
    for key, hs in floors.items():
        hs.sort()
        merged = [hs[0]]
        for h in hs[1:]:
            if h - merged[-1] < 0.6:
                merged[-1] = h
            else:
                merged.append(h)
        zs = obstacles.get(key)
        if zs:
            merged = [h for h in merged if not _stopped(zs, h)]
        if merged:
            out[key] = merged
    return out, obstacles


def _stopped(zs, h):
    for n in range(0, len(zs), 2):
        if zs[n + 1] > h + KNEE and zs[n] < h + HEAD:
            return True
    return False


def _fill(a, b, c, floors, ranges, spread):
    """The floor cells whose middles a triangle covers: their heights into `floors`, or their height ranges into `ranges`."""
    v_low, v_high = min(a[1], b[1], c[1]), max(a[1], b[1], c[1])
    row, last = int(math.ceil(v_low - 0.5)), int(math.floor(v_high - 0.5))
    edges = ((a, b), (b, c), (c, a))
    while row <= last:
        y = row + 0.5
        hit = []
        for p, q in edges:
            if (p[1] <= y < q[1]) or (q[1] <= y < p[1]):
                t = (y - p[1]) / (q[1] - p[1])
                hit.append((p[0] + t * (q[0] - p[0]), p[2] + t * (q[2] - p[2])))
        if len(hit) == 2:
            (xa, za), (xb, zb) = hit if hit[0][0] <= hit[1][0] else (hit[1], hit[0])
            col, end = int(math.ceil(xa - 0.5)), int(math.floor(xb - 0.5))
            span = xb - xa
            while col <= end:
                z = za + (zb - za) * ((col + 0.5 - xa) / span) if span > 1e-9 else za
                key = (col << 16) | row
                if floors is not None:
                    hs = floors.get(key)
                    if hs is None:
                        floors[key] = [z]
                    else:
                        hs.append(z)
                else:
                    ranges[key] = [z - spread, z + spread]
                col += 1
        row += 1


def through(ground, floors, obstacles, owner):
    """Walks over a structure's floors between patches of ground: {(patch, patch): (yards, ground cell, ground cell)}.

    Every floor cell is given the patch of ground nearest to it over the floors; where the floors of two
    patches meet, there is a walk from one patch to the other."""
    dist, label, source, heap = {}, {}, {}, []
    for key, hs in floors.items():
        u, v = key >> 16, key & 65535
        for i, h in enumerate(hs):
            best = None
            for du, dv, run in ((0, 0, 0.5),) + _AROUND:
                uu, vv = u + du, v + dv
                cell = (uu // FINE, vv // FINE)
                patch = owner.get(cell)
                if patch is None:
                    continue
                th = ground_height(ground, uu, vv)
                if abs(th - h) > (ONTO if not (du or dv) else CLIMB * run):
                    continue
                zs = obstacles.get((uu << 16) | vv)
                if zs and _stopped(zs, th):
                    continue
                if best is None or run < best[0]:
                    best = (run, patch, cell)
            if best:
                node = (key, i)
                dist[node], label[node], source[node] = best[0] * F, best[1], best[2]
                heap.append((dist[node], node))
    heapq.heapify(heap)
    done, meets = set(), {}
    while heap:
        d, node = heapq.heappop(heap)
        if d > dist[node] or node in done:
            continue
        done.add(node)
        key, i = node
        u, v = key >> 16, key & 65535
        h = floors[key][i]
        mine = label[node]
        for du, dv, run in _AROUND:
            okey = ((u + du) << 16) | (v + dv)
            hs = floors.get(okey)
            if not hs:
                continue
            for j, oh in enumerate(hs):
                if abs(oh - h) > CLIMB * run:
                    continue
                other = (okey, j)
                nd = d + run * F
                if other in done:
                    theirs = label[other]
                    if theirs != mine:
                        total = nd + dist[other]
                        pair = (mine, theirs) if mine < theirs else (theirs, mine)
                        if pair not in meets or total < meets[pair][0]:
                            ends = (source[node], source[other]) if mine < theirs else (source[other], source[node])
                            meets[pair] = (total, ends[0], ends[1])
                elif nd < dist.get(other, 1e30) and nd <= MAX_YARDS:
                    dist[other], label[other], source[other] = nd, mine, source[node]
                    heapq.heappush(heap, (nd, other))
    return meets


def find(store, ground, coarse, models, window=None, report=None):
    labels = Labels(ground, coarse)
    sizes = labels.sizes
    found = []
    count = {"structures": 0, "read": 0, "models": 0, "unplaced": 0, "triangles": 0}
    groups = chains(models)
    for n, pieces in enumerate(groups):
        if window:
            inside = False
            for piece in pieces:
                wx, wy = 32 * TILE - (piece[2] + piece[4]) / 2.0, 32 * TILE - (piece[1] + piece[3]) / 2.0
                if window[0] <= wx <= window[1] and window[2] <= wy <= window[3]:
                    inside = True
                    break
            if not inside:
                continue
        count["structures"] += 1
        owner, named = {}, []
        for patch in patches_of(ground, pieces):
            rank = -1
            for cell in patch[::max(1, len(patch) // 40)]:
                rank = labels.of(*cell)
                if rank >= 0:
                    break
            # a patch too small to have a gate (rank -1: a yard between two tunnels, a walled court) counts as
            # well: a walk may go tunnel, yard, tunnel
            for cell in patch:
                owner[cell] = len(named)
            named.append(rank)
        if len(named) < 2:
            continue
        count["read"] += 1
        if report:
            report(n, len(groups), pieces)
        floors, obstacles = shapes(store, pieces, count)
        for (pa, pb), (yards, a, b) in through(ground, floors, obstacles, owner).items():
            entry = {"model": pieces[0][0], "pieces": len(pieces), "a": a, "b": b, "yards": yards,
                     "rise": abs(height(ground, *a) - height(ground, *b)),
                     "islands": (named[pa], named[pb]), "why": "", "round": None}
            way = route(ground, coarse, a, b)
            if way:
                entry["round"] = way["cost"] * 7.0
                if entry["round"] < max(SHORTCUT * yards, yards + SAVING):
                    entry["why"] = "joined on the ground already"
            found.append(entry)
    # two links with both ends at nearly the same spots: the shorter kept
    found.sort(key=lambda f: f["yards"])
    kept = []
    for f in found:
        if f["why"]:
            continue
        for k in kept:
            if math.hypot(k["a"][0] - f["a"][0], k["a"][1] - f["a"][1]) * CELL < 60 \
                    and math.hypot(k["b"][0] - f["b"][0], k["b"][1] - f["b"][1]) * CELL < 60:
                break
            if math.hypot(k["a"][0] - f["b"][0], k["a"][1] - f["b"][1]) * CELL < 60 \
                    and math.hypot(k["b"][0] - f["a"][0], k["b"][1] - f["a"][1]) * CELL < 60:
                break
        else:
            kept.append(f)
    return found, kept, count


def hand_links(ground, map_id, lines, path=None):
    """The links written by hand in hand_links.txt for this map: [(name, cell, cell, seconds, one way or not)]."""
    out = []
    path = path or os.path.join(os.path.dirname(os.path.abspath(__file__)), "hand_links.txt")
    if not os.path.exists(path):
        return out
    with open(path, encoding="utf-8") as f:
        for line in f:
            part = line.split("#")[0].split()
            if len(part) < 6 or int(part[0]) != map_id:
                continue
            ax, ay, bx, by, seconds = (float(v) for v in part[1:6])
            oneway = len(part) > 6 and part[6] == "oneway"
            name = " ".join(part[7 if oneway else 6:]) or "by hand"
            a = nearest_passable(ground, *cell_of(ax, ay), reach=6)
            b = nearest_passable(ground, *cell_of(bx, by), reach=6)
            if a and b:
                out.append((name, a, b, seconds, oneway))
                lines.append("hand %5.0f s: world (%.0f, %.0f) %s (%.0f, %.0f); %s" % (
                    seconds, ax, ay, "-->" if oneway else "<->", bx, by, name))
            else:
                lines.append("hand, NOT MADE (no walkable ground within 25 yards of an end): %s" % name)
    return out


def main(map_id, window=None):
    started = time.time()
    store = Storage(r"G:/Games/World of Warcraft", "wowf")
    ground = Ground("world/map_%d.bin" % map_id, walls=False)
    coarse = Coarse.open("world/nav_%d.bin" % map_id)
    models = placements(store, map_files(store)[map_id])
    found, kept, count = find(store, ground, coarse, models, window)
    before = coarse.islands()[1]
    lines = ["map %d: %d building models in %d structures; %d structures stand on two or more patches of ground and were read "
             "(%d models, %d triangles; %d models left out, their placing failed its check); %d walks over floors found; %d links made" % (
                 map_id, len(models), count["structures"], count["read"], count["models"], count["triangles"],
                 count["unplaced"], len(found), len(kept)), ""]
    for f in sorted(kept, key=lambda f: -f["yards"]):
        ax, ay = world_of(*f["a"])
        bx, by = world_of(*f["b"])
        coarse.add_link(ground, f["a"], f["b"], f["yards"] / 7.0 * PRICE)
        around = "no way round" if f["round"] is None else "way round %.0f yd" % f["round"]
        names = ["a pocket" if i < 0 else "stretch %d" % i for i in f["islands"]]
        joins = "within %s" % names[0] if names[0] == names[1] and f["islands"][0] >= 0 else "joins %s and %s" % tuple(names)
        if f["rise"] > 0.7 * f["yards"]:
            joins += "; STEEP, check"
        lines.append("link %5.0f yd, rise %3.0f yd, %3d piece(s), model %d: world (%.0f, %.0f) <-> (%.0f, %.0f); %s; %s" % (
            f["yards"], f["rise"], f["pieces"], f["model"], ax, ay, bx, by, around, joins))
    made = [(f["a"], f["b"], f["yards"] / 7.0 * PRICE, False) for f in kept]
    for name, a, b, seconds, oneway in hand_links(ground, map_id, lines):
        coarse.add_link(ground, a, b, seconds, oneway)
        made.append((a, b, seconds, oneway))
    after = coarse.islands()[1]
    lines += ["", "walks not made into links (the ground joins the two ends already): %d" % sum(1 for f in found if f["why"]),
              "largest stretches before: %s" % before[:8],
              "largest stretches after:  %s" % after[:8]]
    suffix = "_part" if window else ""
    with open("world/links_%d%s.txt" % (map_id, suffix), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    if not window:
        coarse.save("world/nav_%d_linked.bin" % map_id)
        with open("world/links_%d.bin" % map_id, "wb") as f:
            pickle.dump(made, f, protocol=4)
    print("\n".join(lines))
    print("%.0fs" % (time.time() - started))


if __name__ == "__main__":
    main(int(sys.argv[1]), [float(a) for a in sys.argv[2:6]] if len(sys.argv) >= 6 else None)
