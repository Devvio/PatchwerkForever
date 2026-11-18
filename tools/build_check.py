"""Try build.py and art.py's taking-in of pictures on a scratch copy, with a scratch folder for the game.

    python build_check.py

Copies addons/ and the three tools into a temporary folder, makes it a git repository of its own, and
builds into a pretend AddOns folder beside it: a junction where a folder should be, a second build
with nothing to do, a changed file, a file that stops shipping, broken Lua, a TOC naming a missing
file, somebody else's folder, an addon the repository no longer has, a picture of your own, release.py's
changelog and family checks, and watching for a save. Nothing of the real game folder is touched.
"""
import filecmp
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REAL = os.path.normpath(os.path.join(HERE, ".."))
SCRATCH = os.path.join(tempfile.gettempdir(), "patchwerk-build-check")
REPO = os.path.join(SCRATCH, "repo")
GAME = os.path.join(SCRATCH, "game")
TOOLS = os.path.join(REPO, "tools")
ROUTES = "PatchwerkForever_Thread_Routes"
MAIN = os.path.join(REPO, "addons", ROUTES)
LINK = 0x400                                    # the mark of a junction


def clear(path):
    """Take a scratch folder away: junctions first so nothing is followed, read-only files forced."""
    if not os.path.isdir(path):
        return
    for name in os.listdir(path):
        full = os.path.join(path, name)
        if os.path.isdir(full) and (os.lstat(full).st_file_attributes & LINK):
            os.rmdir(full)

    def force(func, target, _exc):
        os.chmod(target, 0o666)
        func(target)
    shutil.rmtree(path, onerror=force)


def git(*args):
    subprocess.run(["git", "-C", REPO, "-c", "user.name=check", "-c", "user.email=check@example.invalid",
                    "-c", "core.autocrlf=false"] + list(args), check=True, capture_output=True)


def run(*args, expect=0, running=None):
    # running: None for no game to mind; True or False to have the build mind one that is, or is not, running
    env = dict(os.environ)
    env.pop("PATCHWERK_GUARD", None)
    env.pop("PATCHWERK_GAME_RUNNING", None)
    if running is not None:
        env["PATCHWERK_GUARD"], env["PATCHWERK_GAME_RUNNING"] = "on", "1" if running else "0"
    r = subprocess.run([sys.executable, "build.py", "--to", GAME] + list(args), cwd=TOOLS, capture_output=True, text=True, env=env)
    print(">>> build.py " + " ".join(args))
    for line in r.stdout.rstrip().splitlines():
        if not line.startswith("  + "):
            print("    " + line)
    assert not r.stderr.strip(), r.stderr
    assert r.returncode == expect, (r.returncode, expect)
    return r.stdout


def game(*parts):
    return os.path.join(GAME, *parts)


def build_line(folder):
    toc = open(game(folder, folder + ".toc"), encoding="utf-8").read()
    line = [l for l in toc.splitlines() if "X-Build" in l]
    assert len(line) == 1, line
    return line[0]


def main():
    sys.path.insert(0, HERE)
    import art

    clear(SCRATCH)
    os.makedirs(GAME)
    shutil.copytree(os.path.join(REAL, "addons"), os.path.join(REPO, "addons"))
    os.makedirs(TOOLS)
    for name in ("build.py", "release.py", "art.py", "cf_html.py"):
        shutil.copy(os.path.join(HERE, name), os.path.join(TOOLS, name))
    git("init", "-q")
    git("add", "-A")
    git("commit", "-q", "-m", "scratch")
    folders = sorted(os.listdir(os.path.join(REPO, "addons")))

    print("a junction where a folder should be: taken away, what it pointed at left alone")
    old = os.path.join(SCRATCH, "oldhome")
    os.makedirs(old)
    open(os.path.join(old, "keep.txt"), "w").write("still here")
    subprocess.run(["cmd", "/c", "mklink", "/J", game("PatchwerkForever"), old], check=True, capture_output=True)
    out = run("check")
    assert "would be written" in out and "junction" in out
    assert os.path.exists(game("PatchwerkForever", "keep.txt")), "check must write nothing"
    out = run()
    assert "start the game again" in out
    assert open(os.path.join(old, "keep.txt")).read() == "still here", "the junction's target was touched"
    assert not (os.lstat(game("PatchwerkForever")).st_file_attributes & LINK)
    assert not os.path.exists(game("PatchwerkForever", "keep.txt"))
    assert sorted(os.listdir(GAME)) == folders
    for folder in folders:
        line = build_line(folder)
        assert not line.endswith("+") and "unversioned" not in line, line

    print("again: nothing to do")
    assert "nothing to do" in run()

    print("an addon the repository no longer has: this tool's folder is taken away, anyone else's is left")
    shutil.copytree(game("PatchwerkForever_Thread_Sparkle"), game("PatchwerkForever_Wayfarer"))
    os.rename(game("PatchwerkForever_Wayfarer", "PatchwerkForever_Thread_Sparkle.toc"),
              game("PatchwerkForever_Wayfarer", "PatchwerkForever_Wayfarer.toc"))
    os.makedirs(game("PatchwerkForever_Theirs"))
    open(game("PatchwerkForever_Theirs", "PatchwerkForever_Theirs.toc"), "w").write("## Title: someone else's\n")
    os.makedirs(game("SomethingElse"))
    out = run("check")
    assert "PatchwerkForever_Wayfarer: an addon this repository no longer has (would be taken away)" in out
    assert os.path.isdir(game("PatchwerkForever_Wayfarer"))
    out = run()
    assert "PatchwerkForever_Wayfarer: an addon this repository no longer has (taken away)" in out
    assert "start the game again" in out
    assert not os.path.exists(game("PatchwerkForever_Wayfarer"))
    assert os.path.isdir(game("PatchwerkForever_Theirs")) and os.path.isdir(game("SomethingElse"))
    shutil.rmtree(game("PatchwerkForever_Theirs"))
    os.rmdir(game("SomethingElse"))

    print("a Lua file changes: written, /reload is enough, and the build line says the files differ")
    with open(os.path.join(MAIN, "Trail.lua"), "a", encoding="utf-8") as f:
        f.write("\n-- a change\n")
    out = run()
    assert "Trail.lua" in out and "/reload is enough" in out, out
    assert build_line(ROUTES).endswith("+")
    assert not build_line("PatchwerkForever").endswith("+"), "another addon's build line changed"

    print("the game running: Lua it already knows is written; a new file, or one going, waits for the game to close")
    with open(os.path.join(MAIN, "Trail.lua"), "a", encoding="utf-8") as f:
        f.write("\n-- another change\n")
    out = run(running=True)
    assert "Trail.lua" in out and "/reload is enough" in out and "NOT WRITTEN" not in out, out
    open(os.path.join(MAIN, "New.lua"), "w").write("-- new\n")
    toc = os.path.join(MAIN, ROUTES + ".toc")
    kept = open(toc, "rb").read()
    open(toc, "ab").write(b"New.lua\n")
    with open(os.path.join(MAIN, "Trail.lua"), "a", encoding="utf-8") as f:
        f.write("\n-- and one more\n")
    before = open(game(ROUTES, "Trail.lua"), "rb").read()
    out = run(running=True)
    assert "NOT WRITTEN" in out and ROUTES in out, out
    assert not os.path.exists(game(ROUTES, "New.lua")), "a new file was written with the game running"
    assert open(game(ROUTES, "Trail.lua"), "rb").read() == before, "half of a build was written with the game running"
    out = run("--now", running=True)
    assert os.path.exists(game(ROUTES, "New.lua")) and "start the game again" in out
    os.remove(os.path.join(MAIN, "New.lua"))
    open(toc, "wb").write(kept)
    out = run(running=False)                    # the game closed: written as ever
    assert not os.path.exists(game(ROUTES, "New.lua")) and "start the game again" in out, out

    print("a development-only file is left out; a file that stops shipping is taken away")
    open(os.path.join(MAIN, "notes.tmp"), "w").write("scratch")
    os.remove(os.path.join(MAIN, "Media", "dot.tga"))
    out = run()
    assert "1 taken away" in out and "Media/dot.tga" in out
    assert not os.path.exists(game(ROUTES, "notes.tmp"))
    assert not os.path.exists(game(ROUTES, "Media", "dot.tga"))

    print("broken Lua: not built, the last good build stays")
    good = open(game(ROUTES, "Route.lua"), "rb").read()
    source = open(os.path.join(MAIN, "Route.lua"), "rb").read()
    with open(os.path.join(MAIN, "Route.lua"), "ab") as f:
        f.write(b"\nlocal function (\n")
    out = run(expect=1)
    assert "NOT BUILT" in out and "syntax error" in out
    assert open(game(ROUTES, "Route.lua"), "rb").read() == good
    open(os.path.join(MAIN, "Route.lua"), "wb").write(source)

    print("the TOC lists a file that is not there")
    os.rename(os.path.join(MAIN, "Nodes.lua"), os.path.join(MAIN, "Nodes.away"))
    out = run(expect=1)
    assert "lists Nodes.lua" in out
    os.rename(os.path.join(MAIN, "Nodes.away"), os.path.join(MAIN, "Nodes.lua"))
    run()

    print("a folder this tool did not build is not replaced without --take-over")
    shutil.rmtree(game("PatchwerkForever"))
    os.makedirs(game("PatchwerkForever"))
    open(game("PatchwerkForever", "PatchwerkForever.toc"), "w").write("## Title: someone else's\n")
    open(game("PatchwerkForever", "Theirs.lua"), "w").write("-- theirs\n")
    out = run("patchwerk", expect=1)
    assert "was not built by this tool" in out
    assert os.path.exists(game("PatchwerkForever", "Theirs.lua"))
    run("patchwerk", "--take-over")
    assert not os.path.exists(game("PatchwerkForever", "Theirs.lua"))

    print("a picture of your own in art/: the icon made 64 x 64, another picture a power of two each side")
    os.makedirs(os.path.join(REPO, "art", "PatchwerkForever"))
    big = [[(200, 40, 40, 255) if (i // 25 + j // 25) % 2 else (0, 0, 0, 0) for i in range(200)] for j in range(200)]
    open(os.path.join(REPO, "art", "PatchwerkForever", "icon.png"), "wb").write(art.png_bytes(big))
    wide = [[(10, 200, 90, 128)] * 100 for _ in range(30)]
    open(os.path.join(REPO, "art", "PatchwerkForever", "banner.png"), "wb").write(art.png_bytes(wide))
    out = run("patchwerk")
    assert "icon.png (200 x 200) -> Media/icon.tga (64 x 64)" in out and "Media/banner.tga (128 x 32)" in out, out
    tga = open(game("PatchwerkForever", "Media", "icon.tga"), "rb").read()
    assert len(tga) == 18 + 64 * 64 * 4 and tga[12:16] == bytes((64, 0, 64, 0))
    assert os.path.getsize(game("PatchwerkForever", "Media", "banner.tga")) == 18 + 128 * 32 * 4
    assert art.read_png(os.path.join(REPO, "art", "PatchwerkForever", "icon.png")) == big, "a PNG does not read back"
    assert "nothing to do" in run("patchwerk")

    print("what is in the game is byte for byte what ships, but for the build line")
    run()
    for folder in folders:
        for root, _, names in os.walk(game(folder)):
            for name in names:
                a = os.path.join(root, name)
                b = os.path.join(REPO, "addons", os.path.relpath(a, GAME))
                if name.endswith(".toc"):
                    lines = [l for l in open(a, "rb").read().splitlines() if b"X-Build" not in l]
                    assert lines == open(b, "rb").read().splitlines(), a
                else:
                    assert filecmp.cmp(a, b, shallow=False), a

    print("release.py: a changelog's title and first entry, and every part named in the base's README")

    def release(*keys, expect=0):
        r = subprocess.run([sys.executable, "release.py"] + list(keys), cwd=TOOLS, capture_output=True, text=True)
        print(">>> release.py " + " ".join(keys))
        for line in (r.stdout + r.stderr).rstrip().splitlines():
            if "NOT BUILT" in line or "WARNING" in line or "CHANGELOG" in line or "README" in line:
                print("    " + line)
        assert (r.returncode == 0) == (expect == 0), (r.returncode, expect, r.stdout + r.stderr)
        return r.stdout + r.stderr

    journal = "PatchwerkForever_Stitch_DungeonJournal"
    log = os.path.join(REPO, "addons", journal, "CHANGELOG.md")
    readme = os.path.join(REPO, "addons", "PatchwerkForever", "README.md")
    kept_log, kept_readme = open(log, "rb").read(), open(readme, "rb").read()
    out = release("dungeonjournal")
    assert "CHANGELOG.md" not in out and "does not name" not in out, out
    title, rest = kept_log.split(b"\n", 1)
    open(log, "wb").write(b"# Dungeon Journal\n" + rest)
    assert "does not begin with the title line" in release("dungeonjournal", expect=1)
    open(log, "wb").write(title + b"\n\n## 9.9.9\n\n- Not this one.\n" + rest)
    assert "first entry is 9.9.9" in release("dungeonjournal", expect=1)
    open(log, "wb").write(kept_log)
    open(readme, "wb").write(kept_readme.replace(b"Stitch (Dungeon Journal)", b"Stitch (the journal)"))
    out = release("dungeonjournal")
    assert "WARNING" in out and "does not name %s" % journal in out, out
    out = release("patchwerk", expect=1)
    assert "NOT BUILT" in out and "does not name %s" % journal in out, out
    open(readme, "wb").write(kept_readme)

    print("watching: a save arrives by itself, a broken save is kept out")
    src = os.path.join(MAIN, "Minimap.lua")
    dst = game(ROUTES, "Minimap.lua")
    log = open(os.path.join(SCRATCH, "watch.log"), "w")
    p = subprocess.Popen([sys.executable, "-u", "build.py", "watch", "--to", GAME], cwd=TOOLS, stdout=log,
                         stderr=subprocess.STDOUT)
    try:
        time.sleep(2.5)
        with open(src, "ab") as f:
            f.write(b"\n-- saved while watching\n")
        t0 = time.time()
        while time.time() - t0 < 8 and open(dst, "rb").read() != open(src, "rb").read():
            time.sleep(0.1)
        took = time.time() - t0
        assert open(dst, "rb").read() == open(src, "rb").read(), "the save did not arrive"
        good = open(dst, "rb").read()
        with open(src, "ab") as f:
            f.write(b"\nif then\n")
        time.sleep(3)
        assert open(dst, "rb").read() == good, "a broken save reached the game"
    finally:
        p.terminate()
        p.wait()
        log.close()
    print("    arrived after %.1f s" % took)

    clear(SCRATCH)
    print("all build checks passed")


if __name__ == "__main__":
    main()
