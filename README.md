# Patchwerk Forever

The Patchwerk Forever addons for **World of Warcraft: Forever**, and the tools that build them, in one repository.

| Folder | What it is |
|---|---|
| `addons/PatchwerkForever` | **Patchwerk Forever**: fixes and additions for Console Port and MelloUI's Route, made from outside those addons. |
| `addons/PatchwerkForever_Wayfarer` | **Patchwerk Forever: Wayfarer**: a route planner with its own map data, herb and ore spots, and a sparkle on things you can use. |
| `addons/PatchwerkForever_Wayfarer_Kalimdor`, `_EasternKingdoms`, `_ZephrasIsle` | Wayfarer's map data, one folder a continent, loaded on demand. Written by `tools/pack.py`; not edited by hand. |
| `tools` | Python tools: reading the game's files, building Wayfarer's map data, testing its Lua outside the game, building the addons into the game, building the uploads. `tools/PLAN.md` is the plan and the log of what was built and what was tried in the game. |

Each addon has its own README, changelog and licence in its folder.

## How the game sees the addons

The repository is kept outside the game's folder. The game loads addons from `_forever_\Interface\AddOns`, and `tools/build.py` writes them there from `addons/`:

| Command (in `tools`) | Does |
|---|---|
| `python build.py` | builds both addons into the game's AddOns folder (`wayfarer` or `patchwerk` for one) |
| `python build.py watch` | keeps running, and builds again whenever a source file is saved |
| `python build.py check` | says what a build would change, and writes nothing |

A build writes, file for file, what ships (the same files the upload holds) and takes away what no longer ships; notes, scratch files and anything else that is not Lua, TOC, XML, a picture, Markdown or the licence stays behind. Only changed files are written. Each TOC gets a line `## X-Build: <commit>`, with a `+` when the files differ from that commit, so the game's folder says what it was built from.

It will not write a folder whose Lua does not parse or whose TOC lists a missing file (the last good build stays in the game), and it will not replace a folder it did not build unless told `--take-over`. After a build it says whether `/reload` is enough or the game must be started again.

Where the game is: `GAME` at the top of `build.py`, or the environment variable `PATCHWERK_ADDONS`. An edit reaches the game only through a build; edit in `addons/`, never in the game's folder, where the next build would overwrite it.

## Working on it

The tools need Python 3 and the package `lupa` (a Lua 5.1 interpreter). Run them from the `tools` folder.

| Command | Does |
|---|---|
| `python luacheck.py <addon folder>` | checks that every Lua file of an addon parses |
| `python lua_shell.py` | runs the whole of Wayfarer through a pretend play session against a stand-in for the game |
| `python lua_trips.py 1 horde` | checks Wayfarer's route planner against the prototype, trip by trip (`0 alliance` for the Eastern Kingdoms) |
| `python lua_journeys.py` | checks Wayfarer's journeys by boat and zeppelin against a brute-force reckoning |
| `python crossings.py` | reads the boats and zeppelins out of the game's files |
| `python pack.py` | writes Wayfarer's map data folders, and its boats and zeppelins, from what the tools read out of the game |
| `python media.py` | draws Wayfarer's pictures |
| `python build.py` | builds the addons into the game (see above) |
| `python release.py [wayfarer|patchwerk]` | checks an addon and builds its upload zip, description and changelog |

Passing these says the code runs; only playing says it works. `tools/PLAN.md` records which is which.

## Releasing

1. Add an entry to the addon's `CHANGELOG.md` and raise the version in its TOC (for Wayfarer: in all four TOCs and in `tools/pack.py`).
2. Commit, then `python release.py`. The zips and the CurseForge texts are written to `release/PatchwerkForever` and `release/PatchwerkForever_Wayfarer` here, which git does not keep. The zip holds the same bytes a build puts in the game, build line included; it warns when built from files that are not committed.
3. Upload by hand on CurseForge, then tag the commit (`patchwerk-forever-1.0.1`, `wayfarer-0.9.0`).

## Rules these addons keep

- No other addon's files are edited; what is changed in another addon is changed while the game runs.
- MelloUI's road and route data is never copied, read or parsed.
- Wayfarer's map data comes only from the game's own files.
- Anything that switches off part of another addon is something the player asks for, never a default.
