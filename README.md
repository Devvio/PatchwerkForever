# Patchwerk Forever

The Patchwerk Forever addons for **World of Warcraft: Forever**, and the tools that build them, in one repository.

| Folder | What it is |
|---|---|
| `addons/PatchwerkForever` | **Patchwerk Forever**: fixes and additions for Console Port and MelloUI's Route, made from outside those addons. |
| `addons/PatchwerkForever_Wayfarer` | **Patchwerk Forever: Wayfarer**: a route planner with its own map data, herb and ore spots, and a sparkle on things you can use. |
| `addons/PatchwerkForever_Wayfarer_Kalimdor`, `_EasternKingdoms`, `_ZephrasIsle` | Wayfarer's map data, one folder a continent, loaded on demand. Written by `tools/pack.py`; not edited by hand. |
| `tools` | Python tools: reading the game's files, building Wayfarer's map data, testing its Lua outside the game, building the uploads. `tools/PLAN.md` is the plan and the log of what was built and what was tried in the game. |

Each addon has its own README, changelog and licence in its folder.

## How the game sees the addons

The game loads addons from `_forever_\Interface\AddOns`. Each of the five addon folders there is a directory junction to its folder under `addons/` here, so the game runs exactly what is in the repository and nothing is copied back and forth.

To set that up on another machine, with the game closed, run this once for each of the five folders in a command prompt:

```
mklink /J "<game>\_forever_\Interface\AddOns\PatchwerkForever" "<repository>\addons\PatchwerkForever"
```

`tools` is at present a junction the other way: the files are in `G:\Games\World of Warcraft\PatchwerkForever-tools` and `tools` here points at them. Git stores them as ordinary files.

## Working on it

The tools need Python 3 and the package `lupa` (a Lua 5.1 interpreter). Run them from the `tools` folder.

| Command | Does |
|---|---|
| `python luacheck.py <addon folder>` | checks that every Lua file of an addon parses |
| `python lua_shell.py` | runs the whole of Wayfarer through a pretend play session against a stand-in for the game |
| `python lua_trips.py 1 horde` | checks Wayfarer's route planner against the prototype, trip by trip (`0 alliance` for the Eastern Kingdoms) |
| `python pack.py 0 1 2991` | writes Wayfarer's map data folders from what the tools read out of the game |
| `python media.py` | draws Wayfarer's pictures |
| `python release.py [wayfarer|patchwerk]` | checks an addon and builds its upload zip, description and changelog |

Passing these says the code runs; only playing says it works. `tools/PLAN.md` records which is which.

## Releasing

1. Add an entry to the addon's `CHANGELOG.md` and raise the version in its TOC (for Wayfarer: in all four TOCs and in `tools/pack.py`).
2. `python release.py`. The zips and the CurseForge texts are written to `PatchwerkForever-release` and `PatchwerkForever_Wayfarer-release` beside this repository.
3. Upload by hand on CurseForge, then tag the commit (`patchwerk-forever-1.0.1`, `wayfarer-0.9.0`).

## Rules these addons keep

- No other addon's files are edited; what is changed in another addon is changed while the game runs.
- MelloUI's road and route data is never copied, read or parsed.
- Wayfarer's map data comes only from the game's own files.
- Anything that switches off part of another addon is something the player asks for, never a default.
