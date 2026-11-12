"""Build the upload for one of the addons.

    python release.py wayfarer      Patchwerk Forever: Wayfarer (four folders: the addon and its map data)
    python release.py patchwerk     Patchwerk Forever
    python release.py               both

Checks the addon's folders, then writes into its release folder in the repository
(release/<main folder>, which git does not keep):

    <main folder>-<version>.zip    the folders, as they go into Interface/AddOns
    CurseForge-description.md      the addon's README.md
    CurseForge-changelog.md        the addon's CHANGELOG.md

The version is the one in the main folder's TOC; every other folder of the addon must carry the same.
Nothing is uploaded: that is done by hand on CurseForge.
"""
import os
import re
import shutil
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
# the repository's addons/ folder; the game's Interface/AddOns holds junctions to the folders in it
REPO = os.path.normpath(os.path.join(HERE, ".."))
ADDONS = os.path.join(REPO, "addons")
OUT = os.path.join(REPO, "release", "%s")
KEEP = (".lua", ".toc", ".xml", ".tga", ".md")            # and the file called LICENSE
TEXT = (".lua", ".toc", ".xml", ".md")
# words that must not be in anything shipped: names an addon used to have, and private ones (an
# account's folder, a character) listed one a line in private_words.txt, a file git does not keep
PRIVATE = ("gmail",)
if os.path.exists(os.path.join(HERE, "private_words.txt")):
    with open(os.path.join(HERE, "private_words.txt"), encoding="utf-8") as _f:
        PRIVATE += tuple(line.strip().lower() for line in _f if line.strip())
PROJECTS = {
    "wayfarer": {
        "main": "PatchwerkForever_Wayfarer",
        "more": ["PatchwerkForever_Wayfarer_Kalimdor", "PatchwerkForever_Wayfarer_EasternKingdoms",
                 "PatchwerkForever_Wayfarer_ZephrasIsle"],
        "stale": PRIVATE + ("wayfinder", "pathfinder"),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE", "Bindings.xml"),
    },
    "patchwerk": {
        "main": "PatchwerkForever",
        "more": [],
        "stale": PRIVATE + ("wayfinder",),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE"),
    },
}


def toc(folder):
    """The TOC of an addon folder: its fields, and the files it lists."""
    fields, files = {}, []
    with open(os.path.join(ADDONS, folder, folder + ".toc"), encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            m = re.match(r"##\s*([^:]+):\s*(.*)", line)
            if m:
                fields[m.group(1)] = m.group(2)
            elif line and not line.startswith("#"):
                files.append(line.replace("\\", "/"))
    return fields, files


def shipped(folder, quiet=False):
    """Every file of a folder that goes into the upload, as paths from the folder."""
    out = []
    for root, _, names in os.walk(os.path.join(ADDONS, folder)):
        for name in names:
            if name.lower().endswith(KEEP) or name == "LICENSE":
                out.append(os.path.relpath(os.path.join(root, name), os.path.join(ADDONS, folder)).replace("\\", "/"))
            elif not quiet:
                print("  left out: %s/%s" % (folder, name))
    return sorted(out)


def _git(*args):
    return subprocess.run(("git", "-C", REPO) + args, capture_output=True, text=True, check=True).stdout.strip()


def commit(folders):
    """The last commit that changed the folders, short; with a + when they differ from it. None without git.

    Not simply the newest commit: one that only touched the tools must not change what an addon says it is."""
    try:
        paths = ["addons/" + f for f in folders]
        mark = _git("log", "-1", "--format=%h", "--", *paths) or _git("rev-parse", "--short", "HEAD")
        if _git("status", "--porcelain", "--", *paths):
            mark += "+"
        return mark
    except (OSError, subprocess.CalledProcessError):
        return None


BUILD = re.compile(rb"^##\s*X-Build:.*$", re.M)


def stamped(data, mark):
    """A TOC's bytes with the line  ## X-Build: <mark>  after its version."""
    if not mark:
        return data
    end = b"\r\n" if b"\r\n" in data else b"\n"
    line = b"## X-Build: " + mark.encode("ascii")
    if BUILD.search(data):
        return BUILD.sub(lambda m: line + (b"\r" if m.group(0).endswith(b"\r") else b""), data)
    m = re.search(rb"^##\s*Version:[^\n]*\n", data, re.M)
    at = m.end() if m else 0
    return data[:at] + line + end + data[at:]


def contents(folder, mark):
    """What ships of a folder, as {path from the folder: bytes}: its files, the TOC stamped with the build."""
    out = {}
    for name in shipped(folder, quiet=True):
        with open(os.path.join(ADDONS, folder, name), "rb") as f:
            data = f.read()
        out[name] = stamped(data, mark) if name == folder + ".toc" else data
    return out


def build(key):
    project = PROJECTS[key]
    main, folders = project["main"], [project["main"]] + project["more"]
    problems = []
    version = toc(main)[0].get("Version")
    plan = []
    for folder in folders:
        fields, listed = toc(folder)
        files = shipped(folder)
        if fields.get("Version") != version:
            problems.append("%s is version %s, the main folder %s" % (folder, fields.get("Version"), version))
        if fields.get("Interface") != toc(main)[0].get("Interface"):
            problems.append("%s is for another interface number" % folder)
        for name in listed:
            if name not in files:
                problems.append("%s lists %s, which is not there" % (folder, name))
        for name in files:
            if name.endswith(".lua") and name not in listed:
                problems.append("%s has %s, which its TOC does not list" % (folder, name))
            if name.lower().endswith(TEXT) or name == "LICENSE":
                text = open(os.path.join(ADDONS, folder, name), encoding="utf-8").read().lower()
                for word in project["stale"]:
                    if word in text:
                        problems.append("%s/%s still says \"%s\"" % (folder, name, word))
        if folder != main and fields.get("LoadOnDemand") != "1":
            problems.append("%s is not load-on-demand" % folder)
        plan.append((folder, files))
    for name in project["needs"]:
        if name not in plan[0][1]:
            problems.append("%s has no %s" % (main, name))
    if ("## %s" % version) not in open(os.path.join(ADDONS, main, "CHANGELOG.md"), encoding="utf-8").read():
        problems.append("CHANGELOG.md has no entry for %s" % version)
    if problems:
        print("%s NOT BUILT:" % main)
        for p in problems:
            print("  " + p)
        return False

    # the same bytes build.py puts in the game: the files, each TOC stamped with the commit
    mark = commit(folders)
    if mark is None:
        print("  no git here: the TOCs carry no build line")
    elif mark.endswith("+"):
        print("  WARNING: built from files that are not committed (build %s)" % mark)
    out = OUT % main
    os.makedirs(out, exist_ok=True)
    path = os.path.join(out, "%s-%s.zip" % (main, version))
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for folder, files in plan:
            data = contents(folder, mark)
            assert sorted(data) == files, folder
            for name in files:
                z.writestr(folder + "/" + name, data[name])
    shutil.copyfile(os.path.join(ADDONS, main, "README.md"), os.path.join(out, "CurseForge-description.md"))
    shutil.copyfile(os.path.join(ADDONS, main, "CHANGELOG.md"), os.path.join(out, "CurseForge-changelog.md"))

    # read it back: every file whole, and the folders at the top
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None, "the zip does not read back"
        names = z.namelist()
        tops = sorted({n.split("/")[0] for n in names})
        assert tops == sorted(folders), tops
        raw = sum(i.file_size for i in z.infolist())
    print("%s %s: %d files in %d folder(s), %.1f MB unpacked, %.2f MB zipped" % (
        main, version, len(names), len(tops), raw / 1e6, os.path.getsize(path) / 1e6))
    print("  " + os.path.normpath(path))
    return True


def main():
    keys = sys.argv[1:] or sorted(PROJECTS)
    for key in keys:
        if key not in PROJECTS:
            sys.exit("no such addon: %s (there are: %s)" % (key, ", ".join(sorted(PROJECTS))))
    if not all([build(key) for key in keys]):
        sys.exit(1)


if __name__ == "__main__":
    main()
