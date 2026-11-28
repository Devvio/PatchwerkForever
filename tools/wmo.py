"""Building models (WMO): where they stand, and their collision shapes.

A terrain file lists each building model standing on it (MODF): which model,
where, turned how, and its bounding box. The model's root file lists its group
files, and each group holds vertices and triangles, with a flag per triangle
that says whether a character collides with it. (The newer models, this
game's own cities among them, keep the flags in MPY2, four bytes a triangle,
and may count their vertices in MOVX, four bytes each.)

Coordinates here are *placement yards*: x east, z south, both from the map's
north-west corner, and y up. A ground cell (gx, gy) is (x / CELL, z / CELL).

The placing was checked against the game's own data: a model's box, turned and
moved this way, gives exactly the box its placement states.
"""
import math
import struct

from terrain import _chunks

_models = {}


def placements(store, wdt_fdid):
    """Every building model on the map: {unique id: (file, x0, z0, x1, z1, y0, y1, position, turn, scale)}."""
    wdt = store.read_fdid(wdt_fdid)
    out = {}
    for tag, at, size in _chunks(wdt):
        if tag != b"MAID":
            continue
        for i in range(4096):
            root, obj0 = struct.unpack_from("<II", wdt, at + i * 32)
            data = root and obj0 and store.read_fdid(obj0)
            if not data:
                continue
            for tag2, at2, size2 in _chunks(data):
                if tag2 == b"MODF":
                    for k in range(size2 // 64):
                        e = struct.unpack_from("<II3f3f3f3f4H", data, at2 + k * 64)
                        out[e[1]] = (e[0], e[8], e[10], e[11], e[13], e[9], e[12], e[2:5], e[5:8], (e[17] or 1024) / 1024.0)
    return out


def model(store, fdid):
    """(the model's own box, its groups); a group is (vertices, triangles a character collides with)."""
    if fdid in _models:
        return _models[fdid]
    box, groups = None, []
    root = store.read_fdid(fdid)
    if root:
        count, files = 0, ()
        for tag, at, size in _chunks(root):
            if tag == b"MOHD":
                head = struct.unpack_from("<7I4sI6f", root, at)
                count, box = head[1], head[9:15]
            elif tag == b"GFID":
                files = struct.unpack_from("<%dI" % (size // 4), root, at)
        for group in files[:count]:
            data = group and store.read_fdid(group)
            if not data:
                continue
            for tag, at, size in _chunks(data):
                if tag != b"MOGP":
                    continue
                part = {}
                for sub, sat, ssize in _chunks(data, at + 68, at + size):
                    part.setdefault(sub, (sat, ssize))
                flag_tag, flag_step = (b"MOPY", 2) if b"MOPY" in part else (b"MPY2", 4)
                index_tag, index_kind, index_step = (b"MOVI", "H", 2) if b"MOVI" in part else (b"MOVX", "I", 4)
                if b"MOVT" not in part or index_tag not in part or flag_tag not in part:
                    continue
                vat, vsize = part[b"MOVT"]
                verts = [struct.unpack_from("<3f", data, vat + 12 * i) for i in range(vsize // 12)]
                iat, isize = part[index_tag]
                index = struct.unpack_from("<%d%s" % (isize // index_step, index_kind), data, iat)
                pat, psize = part[flag_tag]
                tris = []
                for t in range(min(psize // flag_step, len(index) // 3)):
                    flags = data[pat + flag_step * t]
                    if (flags & 0x08) or ((flags & 0x20) and not (flags & 0x04)):      # collides
                        i, j, k = index[3 * t], index[3 * t + 1], index[3 * t + 2]
                        if i < len(verts) and j < len(verts) and k < len(verts):
                            tris.append((i, j, k))
                if tris:
                    groups.append((verts, tris))
    _models[fdid] = (box, groups)
    return _models[fdid]


def placing(store, piece):
    """A function taking a model's own point to placement yards (x, z, y up); None if the result fails its check.

    A model is turned about its own x axis (turn[2]), then its y axis (turn[0]), then the vertical (turn[1], and
    half a turn more), scaled and moved to its position. Most buildings are only turned about the vertical."""
    fdid, x0, z0, x1, z1, y0, y1, pos, turn, scale = piece
    a, b, c = math.radians(turn[1] + 180.0), math.radians(turn[0]), math.radians(turn[2])
    ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    # Rz(a) . Ry(b) . Rx(c), times the scale
    r00, r01, r02 = ca * cb * scale, (ca * sb * sc - sa * cc) * scale, (ca * sb * cc + sa * sc) * scale
    r10, r11, r12 = sa * cb * scale, (sa * sb * sc + ca * cc) * scale, (sa * sb * cc - ca * sc) * scale
    r20, r21, r22 = -sb * scale, cb * sc * scale, cb * cc * scale
    px, py, pz = pos

    def to(lx, ly, lz):
        return (px - (r10 * lx + r11 * ly + r12 * lz),
                pz - (r00 * lx + r01 * ly + r02 * lz),
                py + r20 * lx + r21 * ly + r22 * lz)

    box = model(store, fdid)[0] if fdid is not None else None
    if box:                                    # the check: the model's box, placed, is the box the placement states
        xs, zs, ys = [], [], []
        for lx in (box[0], box[3]):
            for ly in (box[1], box[4]):
                for lz in (box[2], box[5]):
                    x, z, y = to(lx, ly, lz)
                    xs.append(x)
                    zs.append(z)
                    ys.append(y)
        if max(abs(min(xs) - x0), abs(max(xs) - x1), abs(min(zs) - z0), abs(max(zs) - z1),
               abs(min(ys) - y0), abs(max(ys) - y1)) > 1.5:
            return None
    return to


# ---- scenery models (M2): a tent, a cart, a fence, a rock ---------------------------------------------------------
# A terrain file's object part lists them too (MDDF, 36 bytes each: the model's file, an id, its position, turn and
# scale as a building's, and flags; flag 0x40: the first field is a file number). Their collision is a few triangles
# kept apart from what is drawn (in the model's MD20 header: collision triangles at 0xD8, vertices at 0xE0).
_scenery = {}


def scenery_placements(store, wdt_fdid):
    """Every scenery model on the map: [(file, position, turn, scale)] (one standing over two tiles is listed by both:
    kept once, by its id)."""
    wdt = store.read_fdid(wdt_fdid)
    out = {}
    for tag, at, size in _chunks(wdt):
        if tag != b"MAID":
            continue
        for i in range(4096):
            root, obj0 = struct.unpack_from("<II", wdt, at + i * 32)
            data = root and obj0 and store.read_fdid(obj0)
            if not data:
                continue
            for tag2, at2, size2 in _chunks(data):
                if tag2 == b"MDDF":
                    for k in range(size2 // 36):
                        e = struct.unpack_from("<II3f3fHH", data, at2 + 36 * k)
                        if e[9] & 0x40:
                            out[e[1]] = (e[0], e[2:5], e[5:8], (e[8] or 1024) / 1024.0)
    return [out[k] for k in sorted(out)]


def scenery_shape(store, fdid):
    """A scenery model's collision: (vertices, triangles), both empty for one with none."""
    if fdid in _scenery:
        return _scenery[fdid]
    verts, tris = [], []
    data = store.read_fdid(fdid)
    md = None
    if data and data[:4] == b"MD21":
        for tag, at, size in _chunks(data):
            if tag == b"12DM":                         # (the chunk "MD21": _chunks turns the tag round)
                md = data[at:at + size]
                break
    elif data and data[:4] == b"MD20":
        md = data
    if md and len(md) >= 0xF0:
        ni, oi = struct.unpack_from("<II", md, 0xD8)
        nv, ov = struct.unpack_from("<II", md, 0xE0)
        if ni and nv and oi + 2 * ni <= len(md) and ov + 12 * nv <= len(md):
            verts = [struct.unpack_from("<3f", md, ov + 12 * j) for j in range(nv)]
            index = struct.unpack_from("<%dH" % ni, md, oi)
            tris = [(index[3 * t], index[3 * t + 1], index[3 * t + 2]) for t in range(ni // 3)
                    if max(index[3 * t], index[3 * t + 1], index[3 * t + 2]) < nv]
    _scenery[fdid] = (verts, tris)
    return _scenery[fdid]


def turned(pos, turn, scale):
    """The function placing() makes, for a model with no box to check it by (a scenery model)."""
    return placing(None, (None, 0, 0, 0, 0, 0, 0, pos, turn, scale))
