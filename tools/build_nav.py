"""Build the coarse graph of each extracted map's terrain: python build_nav.py 1 0 2991

(The terrain alone, for links.py to look for links on. walls.py builds the graph that is used: the ground
with the buildings' walls, and the links.)"""
import sys, time
from nav import Ground, Coarse

for arg in sys.argv[1:]:
    started = time.time()
    ground = Ground("world/map_%s.bin" % arg, walls=False)
    coarse = Coarse.build(ground)
    coarse.save("world/nav_%s.bin" % arg)
    _, sizes = coarse.islands()
    print("map %s: %s; %d islands, the largest %s; built in %.0fs" % (arg, coarse.stats(), len(sizes), sizes[:5], time.time() - started), flush=True)
