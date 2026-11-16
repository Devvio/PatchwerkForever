"""Build the upload for the addons. Each is a CurseForge project of its own.

    python release.py patchwerk     Patchwerk Forever, the base
    python release.py consoleport   Patchwerk Forever: Stitch (Console Port)
    python release.py melloui       Patchwerk Forever: Stitch (MelloUI)
    python release.py melloroute    Patchwerk Forever: Stitch (MelloUI Route)
    python release.py routes        Patchwerk Forever: Thread (Routes) (four folders: the tool and its map data)
    python release.py sparkle       Patchwerk Forever: Thread (Sparkle)
    python release.py tracker       Patchwerk Forever: Thread (Tracker)
    python release.py races         Patchwerk Forever: Thread (Races)
    python release.py dungeonjournal   Patchwerk Forever: Stitch (Dungeon Journal)
    python release.py               all of them

Checks the addon's folders, then writes into its release folder in the repository
(release/<main folder>, which git does not keep):

    <main folder>-<version>.zip    the folders, as they go into Interface/AddOns
    CurseForge-description.md      the addon's README.md
    CurseForge-description.html    the same as HTML, which CurseForge shows as written (cf_html.py)
    CurseForge-changelog.md        the addon's CHANGELOG.md
    CurseForge-summary.txt         the one-line summary
    CurseForge-notes.txt           what to set on the project: what it requires, its logo
    logo.png                       the project's picture (made by art.py)
    listing/                       pictures for the listing (screenshots, a banner), from art/<folder>/listing/

When all of them are built it also writes release/UPLOAD.md: what to upload, in which order, and what
to set on each project.

The version is the one in the main folder's TOC; every other folder of the addon must carry the same.
Nothing is uploaded: that is done by hand on CurseForge.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile

import cf_html

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
# main: the folder the project is named for.  more: its other folders (load on demand).
# requires: addons of ours it cannot run without (its TOC must say so; CurseForge must be told).
# with: other people's addons it is for.  summary: CurseForge's one line, 250 characters at most.
PROJECTS = {
    "patchwerk": {
        "main": "PatchwerkForever",
        "more": [],
        "requires": [],
        "stale": PRIVATE + ("wayfinder", "wayfarer"),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE", "Media/icon.tga"),
        "summary": "The base of the Patchwerk Forever addons for WoW Forever: one settings home, saved data and "
                   "/patchwerk for all of them. It does nothing by itself; add Stitch (fixes for other addons) "
                   "and Thread (our own tools).",
    },
    "consoleport": {
        "main": "PatchwerkForever_Stitch_ConsolePort",
        "more": [],
        "requires": ["PatchwerkForever"],
        "with": "Console Port",
        "stale": PRIVATE + ("wayfinder", "wayfarer"),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE", "Media/icon.tga", "Link.lua"),
        "summary": "Fixes for Console Port on WoW Forever: the game menu button, Forever's own gamepad bindings, "
                   "the item menu, interact from rings, the bag bar and micro menu. Needs Patchwerk Forever.",
    },
    "melloui": {
        "main": "PatchwerkForever_Stitch_MelloUI",
        "more": [],
        "requires": ["PatchwerkForever"],
        "with": "MelloUI",
        "stale": PRIVATE + ("wayfinder", "wayfarer"),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE", "Media/icon.tga", "Link.lua"),
        "summary": "For MelloUI on WoW Forever: keeps its game menu button and EllesmereUI's apart, and can trim "
                   "MelloUI to its Route and Quest Tracker. Needs Patchwerk Forever.",
    },
    "melloroute": {
        "main": "PatchwerkForever_Stitch_MelloUIRoute",
        "more": [],
        "requires": ["PatchwerkForever"],
        "with": "MelloUI",
        "stale": PRIVATE + ("wayfinder", "wayfarer"),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE", "Media/icon.tga", "Link.lua"),
        "summary": "Additions to MelloUI's Route on WoW Forever: roads ready at login, roads before shortcuts, "
                   "blocked spots, hearthstone and teleport suggestions, next guide steps, a quest run. "
                   "Needs Patchwerk Forever.",
    },
    "dungeonjournal": {
        "main": "PatchwerkForever_Stitch_DungeonJournal",
        "more": [],
        "requires": ["PatchwerkForever"],
        "with": "DungeonJournal",
        "stale": PRIVATE + ("wayfinder", "wayfarer"),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE", "Bindings.xml", "Media/icon.tga", "Link.lua"),
        "summary": "For DungeonJournal on WoW Forever: the quests of the dungeons you track become a list to route "
                   "through, from one quest giver to the next. Needs Patchwerk Forever.",
    },
    "routes": {
        "main": "PatchwerkForever_Thread_Routes",
        "more": ["PatchwerkForever_Thread_Routes_Kalimdor", "PatchwerkForever_Thread_Routes_EasternKingdoms",
                 "PatchwerkForever_Thread_Routes_ZephrasIsle"],
        "requires": ["PatchwerkForever"],
        "stale": PRIVATE + ("wayfinder", "pathfinder", "wayfarer"),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE", "Bindings.xml", "Media/icon.tga", "Link.lua"),
        "summary": "A route planner for WoW Forever: finds the way to your map pin, tracked quest or RestedXP step "
                   "over ground, by flight path, boat and zeppelin, and remembers herb and ore spots. "
                   "Needs Patchwerk Forever.",
    },
    "tracker": {
        "main": "PatchwerkForever_Thread_Tracker",
        "more": [],
        "requires": ["PatchwerkForever"],
        "stale": PRIVATE + ("wayfinder", "pathfinder", "wayfarer"),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE", "Bindings.xml", "Media/icon.tga", "Link.lua"),
        "summary": "A quest tracker for WoW Forever: your quests by zone with distances, your guide's steps, "
                   "quest item buttons, recipes and a gathering list. Needs Patchwerk Forever.",
    },
    "races": {
        "main": "PatchwerkForever_Thread_Races",
        "more": [],
        "requires": ["PatchwerkForever"],
        "stale": PRIVATE + ("wayfinder", "pathfinder", "wayfarer"),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE", "Bindings.xml", "Media/icon.tga", "Link.lua"),
        "summary": "Race courses of your own on WoW Forever: place checkpoints as you ride, then race them against "
                   "the clock with a marker on each checkpoint, split times and your best run. Share them with "
                   "your party. Needs Patchwerk Forever.",
    },
    "sparkle": {
        "main": "PatchwerkForever_Thread_Sparkle",
        "more": [],
        "requires": ["PatchwerkForever"],
        "stale": PRIVATE + ("wayfinder", "pathfinder", "wayfarer"),
        "needs": ("README.md", "CHANGELOG.md", "LICENSE", "Bindings.xml", "Media/icon.tga", "Link.lua"),
        "summary": "A sparkle and a name on the herb, vein, chest or quest object you are coming up to on WoW "
                   "Forever: twelve effects, a look for each kind of thing. Needs Patchwerk Forever.",
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


def curse_id(folder):
    """A project's number on CurseForge, from tools/curseforge.json, when it has been filled in.
    Only a project's main folder has one."""
    path = os.environ.get("CF_CONFIG") or os.path.join(HERE, "curseforge.json")
    try:
        with open(path, encoding="utf-8") as f:
            projects = json.load(f).get("projects", {})
    except (OSError, ValueError):
        return None
    for key, project in PROJECTS.items():
        if project["main"] == folder:
            number = projects.get(key, {}).get("id")
            return number if isinstance(number, int) and number > 0 else None
    return None


def with_project_id(data, number):
    """A TOC's bytes with the line  ## X-Curse-Project-ID: <number>, by which CurseForge's own app
    knows an installed addon. It goes after the build line, else after the version."""
    end = b"\r\n" if b"\r\n" in data else b"\n"
    line = b"## X-Curse-Project-ID: " + str(number).encode("ascii") + end
    if re.search(rb"^##\s*X-Curse-Project-ID:", data, re.M):
        return data
    m = re.search(rb"^##\s*X-Build:[^\n]*\n", data, re.M) or re.search(rb"^##\s*Version:[^\n]*\n", data, re.M)
    at = m.end() if m else 0
    return data[:at] + line + data[at:]


def contents(folder, mark):
    """What ships of a folder, as {path from the folder: bytes}: its files, the TOC stamped with the build
    and, once the project has one, its number on CurseForge."""
    out = {}
    for name in shipped(folder, quiet=True):
        with open(os.path.join(ADDONS, folder, name), "rb") as f:
            data = f.read()
        if name == folder + ".toc":
            data = stamped(data, mark)
            number = curse_id(folder)
            if number:
                data = with_project_id(data, number)
        out[name] = data
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
            if (name.lower().endswith(TEXT) or name == "LICENSE") and name != "CHANGELOG.md":   # (it may say what it was called)
                text = open(os.path.join(ADDONS, folder, name), encoding="utf-8").read().lower()
                for word in project["stale"]:
                    if word in text:
                        problems.append("%s/%s still says \"%s\"" % (folder, name, word))
        if fields.get("Group") != "PatchwerkForever":
            problems.append("%s has no '## Group: PatchwerkForever' line (the game's addon list would show it apart)" % folder)
        if folder != main and fields.get("LoadOnDemand") != "1":
            problems.append("%s is not load-on-demand" % folder)
        # the picture in the game's addon list: a file of this addon's, or of one it cannot run without
        icon = re.match(r"Interface\\AddOns\\([^\\]+)\\(.+)$", fields.get("IconTexture", ""))
        deps = [d.strip() for d in fields.get("Dependencies", "").split(",") if d.strip()]
        if not icon:
            problems.append("%s has no IconTexture line" % folder)
        elif icon.group(1) != folder and icon.group(1) not in deps:
            problems.append("%s takes its icon from %s, which it does not require" % (folder, icon.group(1)))
        elif not os.path.exists(os.path.join(ADDONS, icon.group(1), icon.group(2).replace("\\", os.sep) + ".tga")):
            problems.append("%s names an icon that is not there: %s" % (folder, fields["IconTexture"]))
        if folder == main:
            for need in project["requires"]:
                if need not in deps:
                    problems.append("%s does not say it requires %s" % (folder, need))
            if project["requires"] and (not listed or listed[0] != "Link.lua"):
                problems.append("%s must list Link.lua first" % folder)
        plan.append((folder, files))
    for name in project["needs"]:
        if name not in plan[0][1]:
            problems.append("%s has no %s" % (main, name))
    if len(project["summary"]) > 250:
        problems.append("the summary is %d characters; CurseForge takes 250" % len(project["summary"]))
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
    with open(os.path.join(ADDONS, main, "README.md"), encoding="utf-8") as f:
        page = cf_html.to_html(f.read())
    with open(os.path.join(out, "CurseForge-description.html"), "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    shutil.copyfile(os.path.join(ADDONS, main, "CHANGELOG.md"), os.path.join(out, "CurseForge-changelog.md"))
    with open(os.path.join(out, "CurseForge-summary.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write(project["summary"] + "\n")
    title = toc(main)[0].get("Title", main)
    notes = ["%s %s" % (title, version), "",
             "File to upload:  %s-%s.zip" % (main, version),
             "Description:     CurseForge-description.html (as HTML: put in as Markdown, CurseForge runs",
             "                 the paragraphs together; CurseForge-description.md is the same text)",
             "Changelog:       CurseForge-changelog.md (the entry for %s)" % version,
             "Summary:         CurseForge-summary.txt",
             "Project picture: logo.png" + ("" if os.path.exists(os.path.join(out, "logo.png"))
                                            else "  (NOT THERE YET: run python art.py)"),
             "Game version:    World of Warcraft: Forever (interface %s)" % toc(main)[0].get("Interface"), ""]
    if project["requires"]:
        notes.append("Relations, on the file: Required Dependency -> " + ", ".join(
            toc(need)[0].get("Title", need) for need in project["requires"]))
    else:
        notes.append("Relations: none. It needs no other addon.")
    if project.get("with"):
        notes.append("It is for %s, which people install themselves; mark that as a Required Dependency too if "
                     "its project is on CurseForge, else leave it to the description." % project["with"])
    pictures = listing(main, out)
    if pictures:
        notes.append("Pictures for the listing, in listing/: " + ", ".join(pictures))
    with open(os.path.join(out, "CurseForge-notes.txt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(notes) + "\n")

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


def listing(main, out):
    """Copies a project's listing pictures (screenshots, a banner) from art/<folder>/listing/ to its
    release folder. Returns their names."""
    src = os.path.join(REPO, "art", main, "listing")
    dst = os.path.join(out, "listing")
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    if not os.path.isdir(src):
        return []
    shutil.copytree(src, dst)
    return sorted(os.listdir(dst))


# the tag a project's release commit gets, and whether its CurseForge project is there already
TAGS = {"patchwerk": "patchwerk-forever", "consoleport": "stitch-consoleport", "melloui": "stitch-melloui",
        "melloroute": "stitch-melloroute", "routes": "thread-routes", "sparkle": "thread-sparkle",
        "tracker": "thread-tracker", "dungeonjournal": "stitch-dungeonjournal", "races": "thread-races"}
EXISTS = {"patchwerk"}
ORDER = ["consoleport", "melloui", "melloroute", "dungeonjournal", "routes", "sparkle", "tracker", "races", "patchwerk"]


def checklist():
    """release/UPLOAD.md: every project, in the order to upload them, with what to set on each."""
    lines = ["# Upload checklist", "",
             "Made by `python release.py`. One section a CurseForge project, in the order to upload them.", "",
             "**The order matters.** Patchwerk Forever 2.0.0 does nothing by itself, and people who have 1.x get it as",
             "an update. Have the Stitch and Thread projects up (and approved) first, so that when the base's update",
             "tells them which addon to get, it is there to be found. Every project but the base names",
             "**Patchwerk Forever** as a required dependency.", "",
             "By hand, or with `python upload.py <project>` once the project is made on CurseForge and its id and slug",
             "are in `tools/curseforge.json` (the repository's README says how). The tool sends the zip, the changelog",
             "entry, the release type, the game version and the dependency; the name, summary, description, logo,",
             "category and pictures are set on CurseForge by hand.", ""]
    for n, key in enumerate(ORDER, 1):
        project = PROJECTS[key]
        main = project["main"]
        fields = toc(main)[0]
        version = fields.get("Version")
        out = OUT % main
        pictures = sorted(os.listdir(os.path.join(out, "listing"))) if os.path.isdir(os.path.join(out, "listing")) else []
        mark = commit([main] + project["more"])
        lines += ["## %d. %s %s" % (n, fields.get("Title", main), version), "",
                  "- **Project:** %s" % ("the one that is there (it becomes the base)" if key in EXISTS
                                         else "new; name it exactly as above"),
                  "- **Folder here:** `release/%s/`" % main,
                  "- **File:** `%s-%s.zip`, built from commit `%s`%s" % (
                      main, version, mark, "  **(NOT COMMITTED: commit and run release.py again)**" if (mark or "+").endswith("+") else ""),
                  "- **Release type:** %s" % ("Beta" if version.startswith("0.") else "Release"),
                  "- **Game version:** World of Warcraft: Forever (interface %s)" % fields.get("Interface"),
                  "- **Summary:** %s" % project["summary"],
                  "- **Description:** `CurseForge-description.html`.  **Changelog:** the entry for %s in `CurseForge-changelog.md`" % version,
                  "- **Category:** %s.  **Licence:** MIT" % fields.get("X-Category", "Miscellaneous"),
                  "- **Logo:** `logo.png`" + ("" if os.path.exists(os.path.join(out, "logo.png")) else "  (NOT THERE: run python art.py)"),
                  "- **Pictures:** %s" % (", ".join("`listing/%s`" % p for p in pictures) if pictures else "none yet"),
                  "- **Required dependency:** %s" % (", ".join(toc(r)[0].get("Title", r) for r in project["requires"]) or "none"
                                                      ) + ("; and %s, if its project is on CurseForge" % project["with"] if project.get("with") else ""),
                  "- **Folders in the zip:** %s" % ", ".join("`%s`" % f for f in [main] + project["more"]),
                  "- **Afterwards, tag the commit:** `git tag %s-%s %s`" % (TAGS[key], version, (mark or "").rstrip("+")), ""]
    with open(os.path.join(REPO, "release", "UPLOAD.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("the checklist: " + os.path.join(REPO, "release", "UPLOAD.md"))


def main():
    keys = sys.argv[1:] or sorted(PROJECTS)
    for key in keys:
        if key not in PROJECTS:
            sys.exit("no such addon: %s (there are: %s)" % (key, ", ".join(sorted(PROJECTS))))
    if not all([build(key) for key in keys]):
        sys.exit(1)
    if sorted(keys) == sorted(PROJECTS):
        checklist()


if __name__ == "__main__":
    main()
