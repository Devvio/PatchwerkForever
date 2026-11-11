"""Compile every Lua file of an addon with a real Lua 5.1 parser (LuaJIT via lupa), and list its files' globals.

    python luacheck.py <addon folder>
"""
import os, sys
import lupa.luajit21 as lj

def main(folder):
    rt = lj.LuaRuntime(unpack_returned_tuples=True)
    load = rt.eval("function(src, name) local f, err = loadstring(src, name); return f ~= nil, err end")
    bad = 0
    for root, _dirs, files in os.walk(folder):
        for f in sorted(files):
            if f.endswith(".lua"):
                path = os.path.join(root, f)
                src = open(path, encoding="utf-8").read()
                if src.startswith("\ufeff"):
                    src = src[1:]
                ok, err = load(src, "@" + os.path.relpath(path, folder))
                if not ok:
                    bad += 1
                    print("SYNTAX ERROR", err)
    print("%s: %d file(s) with syntax errors" % (os.path.basename(folder.rstrip("/\\")), bad))
    return bad

if __name__ == "__main__":
    sys.exit(1 if main(sys.argv[1]) else 0)
