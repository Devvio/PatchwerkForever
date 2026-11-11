"""Build the coarse graph of each extracted map: python build_nav.py 1 0 2991"""
import sys, time
from nav import Ground, Coarse

for arg in sys.argv[1:]:
    started = time.time()
    ground = Ground("world/map_%s.bin" % arg)
    coarse = Coarse.build(ground)
    coarse.save("world/nav_%s.bin" % arg)
    _, sizes = coarse.islands()
    print("map %s: %s; %d islands, the largest %s; built in %.0fs" % (arg, coarse.stats(), len(sizes), sizes[:5], time.time() - started), flush=True)
