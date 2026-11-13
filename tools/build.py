"""Build the addons into the game's AddOns folder.

    python build.py                  build every addon into the game
    python build.py routes           only that one (patchwerk, consoleport, melloui, melloroute, routes, sparkle, tracker)
    python build.py watch            keep running: build again whenever a source file is saved
    python build.py check            say what a build would change, and write nothing

    --to <folder>                    build somewhere else than the game's AddOns folder
    --take-over                      allow replacing a folder there that this tool did not build
    --now                            write even though the game is running and the build needs it restarted

While the game is running, a build that adds or takes away a file or changes a TOC writes nothing:
the game only takes those in when it starts, and a /reload in between would load the new Lua against
the old list of files. It says what is waiting; close the game and build again. A build that only
changes Lua the game already knows is written, and /reload takes it in.

The source is the repository's addons/ folder. For each addon folder the build writes, file for
file, what ships (the same files release.py zips), and takes away what is there and no longer
ships. Development-only files stay behind. Each TOC gets a line

    ## X-Build: <commit>             with a + when the files differ from that commit

so the game's folder says what it was built from. Only files that changed are written. Before each
build, your own pictures in art/ are made into the game's format (art.py).

A folder in the game that this tool built and that the repository no longer has (an addon renamed
or dropped) is taken away, so the game does not load the old addon beside the new one.

It refuses to write
    a folder whose Lua does not parse, or whose TOC lists a file that is not there
        (the last good build stays in the game);
    over a folder it did not build (no X-Build line in its TOC), unless told --take-over;
    over a junction while the game runs (a junction is taken away, never followed).

Where the game is: GAME below, or the environment variable PATCHWERK_ADDONS.
"""
import os
import stat
import subprocess
import sys
import time

import art
from release import ADDONS, BUILD, PROJECTS, commit, contents, toc

GAME = os.environ.get("PATCHWERK_ADDONS") or r"G:/Games/World of Warcraft/_forever_/Interface/AddOns"
RESTART = (".toc", ".xml", ".tga")          # a change to one of these wants the game started again
POLL = 0.7                                  # seconds between looks, when watching
SETTLE = 0.4                                # seconds the files must stay as they are before a build

_lua = None
GUARD = True                                # mind a running game (not when building somewhere else: --to)


def parses(name, data):
    """None when the Lua parses, else what is wrong with it."""
    global _lua
    if _lua is None:
        import lupa.luajit21 as lj
        rt = lj.LuaRuntime(unpack_returned_tuples=True)
        _lua = rt.eval("function(src, name) local f, err = loadstring(src, name); return f ~= nil, err end")
    try:
        src = data.decode("utf-8")
    except UnicodeDecodeError as e:
        return "%s: not UTF-8 (%s)" % (name, e)
    if src.startswith("\ufeff"):
        src = src[1:]
    ok, err = _lua(src, "@" + name)
    return None if ok else str(err)


def is_link(path):
    """Whether a path is a junction or a symbolic link, not a folder of its own."""
    try:
        return bool(os.lstat(path).st_file_attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT)
    except OSError:
        return False


def game_running():
    if os.environ.get("PATCHWERK_GAME_RUNNING"):                # (for build_check.py: "1" yes, "0" no)
        return os.environ["PATCHWERK_GAME_RUNNING"] == "1"
    try:
        out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Wow*", "/FO", "CSV", "/NH"],
                             capture_output=True, text=True).stdout
    except OSError:
        return False
    return any(line.lower().startswith('"wow') for line in out.splitlines())


def there(target):
    """The files of a built folder, as {path from the folder: full path}. Links inside are not followed."""
    out = {}
    stack = [target]
    while stack:
        folder = stack.pop()
        for entry in os.scandir(folder):
            if is_link(entry.path):
                raise RuntimeError("%s is a link inside a built folder; take it away by hand" % entry.path)
            if entry.is_dir(follow_symlinks=False):
                stack.append(entry.path)
            else:
                out[os.path.relpath(entry.path, target).replace("\\", "/")] = entry.path
    return out


def plain_toc(data):
    return BUILD.sub(b"", data)


def build_folder(folder, mark, game, write, take_over):
    """Bring one folder in the game up to date. Returns (ok, lines to say, wants a restart)."""
    want = contents(folder, mark)
    says, problems = [], []
    target = os.path.join(game, folder)

    listed = toc(folder)[1]
    for name in listed:
        if name not in want:
            problems.append("its TOC lists %s, which is not there" % name)

    link = is_link(target)
    have = {}
    if link:
        if GUARD and game_running():
            problems.append("it is a junction in the game's folder and the game is running: close the game first")
    elif os.path.isdir(target):
        have = there(target)
        tocs = [p for n, p in have.items() if n.lower().endswith(".toc")]
        ours = any(BUILD.search(open(p, "rb").read()) for p in tocs)
        if have and not ours and not take_over:
            problems.append("the folder in the game was not built by this tool (run with --take-over to replace it)")

    old = {}
    for name, path in have.items():
        if name in want:
            with open(path, "rb") as f:
                old[name] = f.read()
    changed = sorted(n for n in want if old.get(n) != want[n])
    gone = sorted(n for n in have if n not in want)

    for name in changed:
        if name.endswith(".lua"):
            wrong = parses(folder + "/" + name, want[name])
            if wrong:
                problems.append("syntax error: " + wrong)

    if problems:
        return False, ["%s NOT BUILT:" % folder] + ["  " + p for p in problems], False

    restart = False
    for name in changed:
        new = name not in old
        if name.lower().endswith(RESTART):
            if not (name.lower().endswith(".toc") and not new and plain_toc(old[name]) == plain_toc(want[name])):
                restart = True
        elif new:
            restart = True
    if link:
        says.append("  the junction is replaced by a built folder")

    if write:
        if link:
            os.rmdir(target)                    # takes the junction away; what it pointed at is not touched
        for name in changed:
            path = os.path.join(target, name)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path + ".new~", "wb") as f:
                f.write(want[name])
            os.replace(path + ".new~", path)
        for name in gone:
            os.remove(have[name])
        if gone:                                # folders left empty
            for root, dirs, names in os.walk(target, topdown=False):
                if root != target and not os.listdir(root):
                    os.rmdir(root)

    if not changed and not gone and not link:
        return True, [], False
    verb = "" if write else "would be "
    says.insert(0, "%s: %d file(s) %swritten, %d %staken away (%d ship, build %s)" % (
        folder, len(changed), verb, len(gone), verb, len(want), mark))
    few = changed if len(changed) <= 12 else changed[:11] + ["... and %d more" % (len(changed) - 11)]
    says += ["  + " + n for n in few] + ["  - " + n for n in gone]
    return True, says, restart


def retired(game):
    """Folders in the game that this tool built and the repository no longer has: an addon renamed or dropped.

    Left there, the game would load the old addon beside the new one. Only a folder whose name begins
    PatchwerkForever and whose TOC carries the build line is taken for ours; a junction never is."""
    ours = {f for p in PROJECTS.values() for f in [p["main"]] + p["more"]}
    out = []
    for name in sorted(os.listdir(game)):
        path = os.path.join(game, name)
        if name in ours or not name.startswith("PatchwerkForever") or is_link(path) or not os.path.isdir(path):
            continue
        toc_path = os.path.join(path, name + ".toc")
        if os.path.isfile(toc_path):
            with open(toc_path, "rb") as f:
                if BUILD.search(f.read()):
                    out.append(name)
    return out


def build(keys, game, write=True, take_over=False, quiet_when_same=False, now=False):
    """Build the addons named. Returns whether every folder is as it should be."""
    if not os.path.isdir(game):
        print("there is no folder %s" % game)
        return False
    good, restart, said = True, False, False
    if write:                                   # your own PNGs in art/, made into the game's pictures
        for path in art.take_in():
            said = True
    if write and not now and GUARD and game_running():
        # The game only takes in a new file, a file's going, or a changed TOC when it starts. Written
        # while it runs, a /reload would load the new Lua against the old list of files: half an addon.
        # So with the game running, a build that needs a restart writes nothing at all.
        waits = []
        for key in keys:
            project = PROJECTS[key]
            folders = [project["main"]] + project["more"]
            mark = commit(folders) or "unversioned"
            for folder in folders:
                try:
                    ok, says, again = build_folder(folder, mark, game, False, take_over)
                except (OSError, RuntimeError):
                    ok, says, again = False, [], False
                if ok and again:
                    waits.append(folder)
        waits += retired(game)
        if waits:
            print("NOT WRITTEN: the game is running, and this build adds or takes away files or changes a TOC")
            print("  (%s)." % ", ".join(waits))
            print("  The game only takes those in when it starts, and a /reload in between would load half of it.")
            print("  Close the game and build again. (--now writes it anyway.)")
            sys.stdout.flush()
            return True
    for key in keys:
        project = PROJECTS[key]
        folders = [project["main"]] + project["more"]
        mark = commit(folders) or "unversioned"     # always a line: it is how the build knows its own folders
        for folder in folders:
            try:
                ok, says, again = build_folder(folder, mark, game, write, take_over)
            except (OSError, RuntimeError) as e:
                ok, says, again = False, ["%s NOT BUILT: %s" % (folder, e)], False
            good = good and ok
            restart = restart or again
            for line in says:
                print(line)
                said = True
    for folder in retired(game):
        print("%s: an addon this repository no longer has%s" % (folder, " (taken away)" if write else " (would be taken away)"))
        said = restart = True
        if write:
            for path in there(os.path.join(game, folder)).values():
                os.remove(path)
            for root, _, _ in os.walk(os.path.join(game, folder), topdown=False):
                os.rmdir(root)
    if not said:
        if not quiet_when_same:
            print("nothing to do: %s is up to date" % os.path.normpath(game))
    elif good and write:
        print("in the game: %s" % ("start the game again (a new file, a TOC, a picture or bindings changed)"
                                   if restart else "/reload is enough"))
    sys.stdout.flush()
    return good


def snapshot(keys):
    """What the source looks like now: every file's time and size, your own art included."""
    out = {}
    for key in keys:
        for folder in [PROJECTS[key]["main"]] + PROJECTS[key]["more"]:
            for root, _, names in list(os.walk(os.path.join(ADDONS, folder))) + list(os.walk(os.path.join(art.ART, folder))):
                for name in names:
                    path = os.path.join(root, name)
                    try:
                        s = os.stat(path)
                    except OSError:
                        continue
                    out[path] = (s.st_mtime_ns, s.st_size)
    return out


def watch(keys, game, take_over, now=False):
    print("watching %s (Ctrl+C stops)" % os.path.normpath(ADDONS))
    build(keys, game, take_over=take_over, now=now)
    seen = snapshot(keys)
    try:
        while True:
            time.sleep(POLL)
            now = snapshot(keys)
            if now == seen:
                continue
            while True:                         # wait for the saving to finish
                time.sleep(SETTLE)
                later = snapshot(keys)
                if later == now:
                    break
                now = later
            seen = now
            print(time.strftime("%H:%M:%S"))
            build(keys, game, take_over=take_over, quiet_when_same=True, now=now)
    except KeyboardInterrupt:
        print("stopped")


def main():
    args = sys.argv[1:]
    game, take_over, mode, keys, now = GAME, False, "build", [], False
    while args:
        a = args.pop(0)
        if a == "--to":
            if not args:
                sys.exit("--to needs a folder")
            game = args.pop(0)
            globals()["GUARD"] = os.environ.get("PATCHWERK_GUARD") == "on"      # (on: for build_check.py)
        elif a == "--take-over":
            take_over = True
        elif a == "--now":
            now = True
        elif a in ("watch", "check"):
            mode = a
        elif a in PROJECTS:
            keys.append(a)
        else:
            sys.exit("not understood: %s (addons: %s; also watch, check, --to <folder>, --take-over)"
                     % (a, ", ".join(sorted(PROJECTS))))
    keys = keys or sorted(PROJECTS)
    if mode == "watch":
        watch(keys, game, take_over, now)
    elif not build(keys, game, write=(mode == "build"), take_over=take_over, now=now):
        sys.exit(1)


if __name__ == "__main__":
    main()
