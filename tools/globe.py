"""The minimap image tiles of each continent, for Thread (Globe).

    python globe.py                 writes addons/PatchwerkForever_Thread_Globe/Tiles.lua

Each continent's world file (WDT) lists, for each of its 64 x 64 terrain tiles, the FileDataID of
that tile's minimap picture (the top-down image the minimap shows, 256 x 256). Only those numbers
are written: the addon asks the game for the pictures by number, so none of the game's art is in
the addon.

A tile's place: column tx (east is more), row ty (south is more); world Y = 17066.67 - tx * 533.33,
world X = 17066.67 - ty * 533.33 at its north-west corner (as Thread (Routes)' planner counts cells).
"""
import os
import struct

from casc import Storage
from world import map_files

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "addons", "PatchwerkForever_Thread_Globe", "Tiles.lua")
GAME = r"G:/Games/World of Warcraft"
CONTINENTS = ((1, "Kalimdor"), (0, "Eastern Kingdoms"), (2991, "Zephra's Isle"))


def chunks(data):
    at = 0
    while at + 8 <= len(data):
        tag = data[at:at + 4][::-1]
        size = struct.unpack_from("<I", data, at + 4)[0]
        yield tag, at + 8, size
        at += 8 + size


def minimap_tiles(store, wdt_fdid):
    """{(tx, ty): FileDataID of the tile's minimap picture}"""
    wdt = store.read_fdid(wdt_fdid)
    out = {}
    for tag, at, size in chunks(wdt):
        if tag == b"MAID":
            per = size // 4096
            for ty in range(64):
                for tx in range(64):
                    # (eight numbers a tile; the minimap picture is the last)
                    fdid = struct.unpack_from("<I", wdt, at + (ty * 64 + tx) * per + per - 4)[0]
                    if fdid:
                        out[(tx, ty)] = fdid
    return out


def main():
    store = Storage(GAME, "wowf")
    files = map_files(store)
    lines = ["-- Thread (Globe): the minimap picture of each terrain tile, by continent. Written by",
             "-- tools/globe.py from the game's own world files; only the pictures' numbers are here.",
             "local _, ns = ...", "", "ns.TILES = {"]
    for map_id, name in CONTINENTS:
        if map_id not in files:
            print("%s (%d): no world file" % (name, map_id))
            continue
        tiles = minimap_tiles(store, files[map_id])
        if not tiles:
            print("%s (%d): no minimap pictures" % (name, map_id))
            continue
        xs = [t[0] for t in tiles]
        ys = [t[1] for t in tiles]
        print("%s (%d): %d tiles, columns %d-%d, rows %d-%d" % (name, map_id, len(tiles), min(xs), max(xs), min(ys), max(ys)))
        lines.append("\t{ map = %d, name = %s, columns = { %d, %d }, rows = { %d, %d }, tiles = {"
                     % (map_id, repr(name).replace("\\'", "'") if "'" not in name else '"%s"' % name,
                        min(xs), max(xs), min(ys), max(ys)))
        row = []
        for (tx, ty) in sorted(tiles, key=lambda t: (t[1], t[0])):
            row.append("[%d]=%d" % (ty * 64 + tx, tiles[(tx, ty)]))
            if len(row) == 8:
                lines.append("\t\t" + ", ".join(row) + ",")
                row = []
        if row:
            lines.append("\t\t" + ", ".join(row) + ",")
        lines.append("\t} },")
    lines.append("}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("written", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
