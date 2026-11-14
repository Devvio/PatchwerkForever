"""Compile every Lua file of an addon with a real Lua 5.1 parser (LuaJIT via lupa).

    python luacheck.py <addon folder>

The folder is a path, or the bare name of one under ../addons (python luacheck.py PatchwerkForever).
A folder that is not there, or has no Lua file in it, is an error: nothing compiled proves nothing.
"""
import os, sys
import lupa.luajit21 as lj

ADDONS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "addons")

def main(folder):
    if not os.path.isdir(folder) and os.path.isdir(os.path.join(ADDONS, folder)):
        folder = os.path.join(ADDONS, folder)
    name = os.path.basename(os.path.abspath(folder))
    if not os.path.isdir(folder):
        print("%s: no such folder" % folder)
        return 1
    rt = lj.LuaRuntime(unpack_returned_tuples=True)
    load = rt.eval("function(src, name) local f, err = loadstring(src, name); return f ~= nil, err end")
    bad = seen = 0
    for root, _dirs, files in os.walk(folder):
        for f in sorted(files):
            if f.endswith(".lua"):
                seen += 1
                path = os.path.join(root, f)
                src = open(path, encoding="utf-8").read()
                if src.startswith("﻿"):
                    src = src[1:]
                ok, err = load(src, "@" + os.path.relpath(path, folder))
                if not ok:
                    bad += 1
                    print("SYNTAX ERROR", err)
    if not seen:
        print("%s: no Lua file found" % name)
        return 1
    print("%s: %d file(s) compiled, %d with syntax errors" % (name, seen, bad))
    return bad

if __name__ == "__main__":
    sys.exit(1 if main(sys.argv[1]) else 0)
