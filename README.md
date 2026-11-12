# Patchwerk Forever

The Patchwerk Forever addons for **World of Warcraft: Forever**, and the tools that build them, in one repository.

## The addons

One parent and two tracks. Each addon is its own download (a CurseForge project of its own), so people install only what they use.

- **Patchwerk Forever** is the parent: the base every other addon here needs. It holds the settings home, the saved data of the Stitches, `/patchwerk` and the API the others join. It does nothing by itself.
- **Stitch** is what is sewn onto other people's addons: fixes and additions for third-party addons. A Stitch needs the base and the addon it is for.
- **Thread** is our own tools: first-party, needing nothing but the base.

| Folder | What it is | Needs |
|---|---|---|
| `addons/PatchwerkForever` | **Patchwerk Forever**, the base. | nothing |
| `addons/PatchwerkForever_Stitch_ConsolePort` | **Stitch (Console Port)**: fixes for Console Port on Forever. | the base, Console Port |
| `addons/PatchwerkForever_Stitch_MelloUIRoute` | **Stitch (MelloUI Route)**: additions to MelloUI's route planner. | the base, MelloUI |
| `addons/PatchwerkForever_Stitch_MelloUI` | **Stitch (MelloUI)**: the game menu button fix and the trim to Route and the Quest Tracker. | the base, MelloUI |
| `addons/PatchwerkForever_Thread_Routes` | **Thread (Routes)**: a route planner with its own map data, and herb and ore spots. | the base |
| `addons/PatchwerkForever_Thread_Routes_Kalimdor`, `_EasternKingdoms`, `_ZephrasIsle` | Routes' map data, one folder a continent, loaded on demand. Written by `tools/pack.py`; not edited by hand. They ship in Routes' zip. | Thread (Routes) |
| `addons/PatchwerkForever_Thread_Sparkle` | **Thread (Sparkle)**: a sparkle and a name on things you can use. | the base |

Each addon has its own README, changelog and licence in its folder.

### How an addon joins the base

Its TOC says `## Dependencies: PatchwerkForever` and lists `Link.lua` first. Every file after that begins by checking `ns.linked`, so without a base new enough the addon does nothing rather than fail.

- **A Stitch** calls `PatchwerkForever:Link(addonName, ns, 1)`. That puts the base's functions on its own table: `ns:AddSetting`, `ns:GetSetting`, `ns:OnSetting`, `ns:GetSaved`, `ns:WhenLoaded`, `ns:RegisterFix`, `ns:Print`, `ns:Icon`. Its settings are tick boxes and sliders in a section of the base's own page, and its saved data stays in the base's `PatchwerkForeverDB`, so a Stitch can be added or removed without losing anything. `Link.lua` is the same file in every Stitch.
- **A Thread tool** calls `PatchwerkForever:Tool(addonName, ns, { name, colour, saved, page, slash })`. It gets `ns.Print`, `ns.Try`, `ns.On`, `ns.Get`, `ns.Set`, `ns.OnSetting`, `ns.RGB`, `ns.OpenSettings`, lists its settings in `ns.settings` (tick boxes, sliders, lists, colours, buttons, headings, on named pages), and the base makes those pages under its own. A tool has a saved variable of its own. The base's `Tools.lua` describes all of it.

To add one: a new folder under `addons/` named for its track (`PatchwerkForever_Stitch_<Addon>` or `PatchwerkForever_Thread_<Tool>`) with a TOC, `Link.lua`, a README, a CHANGELOG, a LICENSE; an entry in `PROJECTS` in `tools/release.py`; an icon in `tools/art.py` (or your own in `art/`); and, for a Stitch, a line in the base's `P.Family` if players should be told when it is missing.

## Other folders

| Folder | What it is |
|---|---|
| `tools` | Python tools: reading the game's files, building Routes' map data, testing the Lua outside the game, drawing the art, building the addons into the game, building the uploads. `tools/PLAN.md` is the plan and the log of what was built and what was tried in the game. |
| `art` | Your own pictures, used in place of the drawn icons or beside them. See `art/README.md`. |
| `release` | The upload for each project (zip, CurseForge texts, logo). Written by the tools; git does not keep it. |

## How the game sees the addons

The repository is kept outside the game's folder. The game loads addons from `_forever_\Interface\AddOns`, and `tools/build.py` writes them there from `addons/`:

| Command (in `tools`) | Does |
|---|---|
| `python build.py` | builds every addon into the game's AddOns folder (`patchwerk`, `consoleport`, `melloui`, `melloroute`, `routes` or `sparkle` for one) |
| `python build.py watch` | keeps running, and builds again whenever a source file or a picture in `art/` is saved |
| `python build.py check` | says what a build would change, and writes nothing |

A build writes, file for file, what ships (the same files the upload holds) and takes away what no longer ships; notes, scratch files and anything else that is not Lua, TOC, XML, a picture, Markdown or the licence stays behind. Only changed files are written. Each TOC gets a line `## X-Build: <commit>`, the last commit that changed that addon, with a `+` when the files differ from it, so the game's folder says what it was built from.

A folder in the game that a build made and that the repository no longer has (an addon renamed or dropped) is taken away, so the game does not load the old addon beside the new one.

It will not write a folder whose Lua does not parse or whose TOC lists a missing file (the last good build stays in the game), and it will not replace a folder it did not build unless told `--take-over`. After a build it says whether `/reload` is enough or the game must be started again.

Where the game is: `GAME` at the top of `build.py`, or the environment variable `PATCHWERK_ADDONS`. An edit reaches the game only through a build; edit in `addons/`, never in the game's folder, where the next build would overwrite it.

## Art

Every addon has an icon for the game's addon list (`Media/icon.tga`, named by the `## IconTexture` line of its TOC) and a logo for its CurseForge project (`release/<folder>/logo.png`). `python art.py` draws them as a family: a sewn-on patch with gold stitching, the cloth a colour of its own and an emblem for each addon. It also writes `release/art-preview.png`, a sheet of all of them.

A PNG of your own in `art/<addon folder>/` replaces the drawn icon or logo, or adds another picture to that addon; the build converts it to the game's format. `art/README.md` has the names and sizes.

## Working on it

The tools need Python 3 and the package `lupa` (a Lua 5.1 interpreter). Run them from the `tools` folder.

| Command | Does |
|---|---|
| `python luacheck.py <addon folder>` | checks that every Lua file of an addon parses |
| `python lua_patchwerk.py` | runs the base and the Stitches through pretend logins: a Stitch's settings, saved data and load order; what someone who had 1.x is told; a Stitch with no base |
| `python lua_shell.py` | runs the base with both Thread tools through a pretend play session against a stand-in for the game |
| `python lua_trips.py 1 horde` | checks Routes' planner against the prototype, trip by trip (`0 alliance` for the Eastern Kingdoms) |
| `python lua_journeys.py` | checks Routes' journeys by boat and zeppelin against a brute-force reckoning |
| `python build_check.py` | tries the build tool on a scratch copy: junctions, changed and removed files, broken Lua, retired folders, your own art, watching |
| `python crossings.py` | reads the boats and zeppelins out of the game's files |
| `python pack.py` | writes Routes' map data folders, and its boats and zeppelins, from what the tools read out of the game |
| `python media.py` | draws the pictures Sparkle's effects and Routes' dotted trail are made of |
| `python art.py` | draws the icons and logos, and takes in your own from `art/` |
| `python build.py` | builds the addons into the game (see above) |
| `python release.py [project]` | checks a project and builds its upload: zip, description, changelog, summary, notes on what to set on CurseForge |

Passing these says the code runs; only playing says it works. `tools/PLAN.md` records which is which. The fixes inside the Stitches cannot be run outside the game at all: they need the addons they are for.

## Releasing

1. Add an entry to the addon's `CHANGELOG.md` and raise the version in its TOC (for Routes: in all four TOCs and in `tools/pack.py`). Every addon has a version of its own; raise only what changed. A change to the base's API that an addon needs means raising `api` in that addon's `Link.lua` and `P.API` in the base.
2. Commit, then `python release.py`. Each project's upload is written to `release/<its folder>` here. The zip holds the same bytes a build puts in the game, build line included; it warns when built from files that are not committed.
3. Upload by hand on CurseForge. `CurseForge-notes.txt` in each release folder says what to set; every project but the base must name **Patchwerk Forever** as a required dependency.
4. Tag the commit: `patchwerk-forever-2.0.0`, `stitch-consoleport-2.0.0`, `stitch-melloui-2.0.0`, `stitch-melloroute-2.0.0`, `thread-routes-0.11.0`, `thread-sparkle-0.11.0`.

## Rules these addons keep

- No other addon's files are edited; what is changed in another addon is changed while the game runs.
- MelloUI's road and route data is never copied, read or parsed.
- Routes' map data comes only from the game's own files.
- Anything that switches off part of another addon is something the player asks for, never a default.
- Every setting is under Patchwerk Forever's own page, never in another addon's settings.
