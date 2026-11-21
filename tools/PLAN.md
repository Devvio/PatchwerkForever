# Our own route planner: plan

Goal: a route planner for WoW Forever that is ours end to end: map data made from the
game's own files by our tools, a planner written by us, shipped as its own addon. No
MelloUI code or data in it.

**Where it stands (2026-11-18):** Thread (Routes) 1.1.0 is live on CurseForge, out of beta since 1.0.0.
This file is the planner's plan, the log of its early versions (to Routes 0.12.0) and of the checks
against other addons' updates. The quest tracker's plan is `PLAN-tracker.md`; what came later is in
`ROADMAP.md`, `POLISH.md`, `TRACKING-BLUEPRINT.md` and each addon's CHANGELOG.

**Two tracks under one parent (2026-11-12, later the same day; the user's design and names):**
Patchwerk Forever is the parent (the base). **Stitch** is for third-party addons: fixes and
additions sewn onto Console Port and MelloUI. **Thread** is first-party: tools made by us. The user
chose Thread as the tools' name in place of Wayfarer, the tools under the parent (they need the
base), the sparkle split from the route planner, and MelloUI Route's additions under Stitch.
- Folders: `PatchwerkForever_Stitch_ConsolePort`, `_Stitch_MelloUI`, `_Stitch_MelloUIRoute` (each
  2.0.0); `PatchwerkForever_Thread_Routes` with `_Kalimdor`, `_EasternKingdoms`, `_ZephrasIsle`
  (0.11.0; `/thread`, `/pft`; saved `PatchwerkForever_Thread_RoutesDB`; map data global
  `PatchwerkForever_Thread_RoutesData`; bindings `PATCHWERKFOREVER_THREAD_GO/_STOP`);
  `PatchwerkForever_Thread_Sparkle` (0.11.0; `/sparkle`, `/pfs`; saved
  `PatchwerkForever_Thread_SparkleDB`; binding `PATCHWERKFOREVER_SPARKLE_IGNORE`).
- The base's new `Tools.lua` is what Wayfarer's Core.lua and Settings.lua were, made general:
  `PatchwerkForever:Tool(addon, ns, spec)` gives a tool `ns.Print/Try/On/Get/Set/OnSetting/RGB/
  OpenSettings`, and at login the base makes the tool's pages from `ns.settings` as sub-pages of
  its own (Thread: Routes, Thread: Trail, Thread: Sparkle, Sparkle: Names, five Sparkle kinds,
  Sparkle: Behind My Character). Each tool lists `Link.lua` first; every later file starts with
  `if not ns.linked then return end`.
- The sparkle reads the route planner's `nodeKinds` when that tool is installed, else goes by the
  game's cursor alone.
- Tools: `build.py` takes away a folder in the game that it built and the repository no longer
  has; `build_check.py` tries the build tool on a scratch copy; `release.py` has six projects
  (patchwerk, consoleport, melloui, melloroute, routes, sparkle); `art.py` draws six icons;
  `media.py` writes each picture to the tool that uses it; `carry_tracks.py` splits the old
  saved file into the two tools' (game closed) and renames bindings.
- Passes: luacheck on all nine folders, `lua_patchwerk.py`, `lua_shell.py` (the base with both
  tools: 72 settings, 10 sub-pages), `lua_trips.py`, `lua_journeys.py`, `build_check.py`,
  `release.py`. Built into the game the same day, with the game closed: nine folders written,
  the seven old ones taken away; `carry_tracks.py` carried the user's saved data over (9 route
  settings, 22 herb and ore spots, 11 sparkle settings; the old saved file is left).
- Icons: the user made six pictures from the prompts in `art/PROMPTS.md` (written to match the
  art of the first listing); they are `art/<folder>/icon.png` and replace the drawn icons.
- Confirmed in-game (2026-11-12, after a full start): all the addons load, with
  their icons and settings pages. So Forever's addon list does show
  `## IconTexture`, and sub-pages of several addons under one parent page work. Not heard one
  by one: `/thread config` and `/sparkle config` opening their own page, a route and a sparkle
  in play under the new names, each Console Port fix.
- Two things from a look at it in the game (2026-11-12): the Stitch options were not found where they were, a
  section of the parent's first page, so each Stitch now has a sub-page of its own ("Stitch: Console Port");
  and a screenshot of the addon list showed the three map data folders standing outside the Patchwerk
  Forever group with their titles cut off. Forever's addon list goes by a `## Group:` line in the TOC (set by
  the client from names and dependencies when absent; read in Blizzard's AddonList.lua): every TOC now says
  `## Group: PatchwerkForever`, and the map data titles are "Thread (Routes) map: Kalimdor" and so on.
  Both built into the game; neither seen there yet.
- Checked against the addons updated on 2026-11-12 (asked for): MelloUI 2.1.44 to 2.1.48 and RestedXP Guides
  v4.11.36; Console Port (3.3.13) and EllesmereUI (9.8.4) had not changed. MelloUI's Route files, its game menu
  button and its guide hookup are untouched (diffed tag to tag in a blobless clone, data files never fetched).
  One thing mattered: since 2.1.46 MelloUI keeps a profile for each character and a profile carries which
  modules are on, so the trim's account-wide "seen" list would have left another character untrimmed. It is
  kept for each profile now (`seenIn`), checked by pretend logins in `lua_patchwerk.py`; not tried in the game
  (the user does not run MelloUI). RestedXP still sets `RXPG_ARROW.element` with zone, x, y, wx, wy, instance.
  Also in the repository now: the CurseForge uploader (`upload.py`, `upload_check.py`, `curseforge.json`, the
  CI workflow), and Patchwerk's flavour text at the top of each README.
- Checked against the addons updated by 2026-11-14 (asked for): MelloUI 2.1.48 to 2.1.51,
  EllesmereUI 9.8.4 to 9.8.5, DungeonJournal 2.0.4 to 2.0.5; Console Port (3.3.13) and RestedXP Guides
  (v4.11.36) had not changed. Nothing of ours needed a change. MelloUI: every one of the 68 names the two
  Stitches lean on is still defined, and no line defining one was taken away or changed (tag to tag in a
  blobless clone, data files never fetched); Route.lua gained `M.Taxis` and `Beacon.Area` only, no module was
  added (its new gamepad support, 2.1.49, is core code, not a module the trim would meet), and the game menu
  entry is still `MelloUIGameMenuEntry`. DungeonJournal: all eight names the reader reads are there with the
  same shapes; its 2.0.5 fix (profession quests only for characters with the profession) sits inside
  `QuestMatchesFaction`, which the reader already asks, so the list follows it. EllesmereUI has no old copy
  to compare with: only the names we use were looked for (`EllesmereUI_GameMenuButton`,
  `EllesmereUI_UnlockMenuButton`, the folder `EllesmereUIQuestTracker`), and they are there. None of this was
  tried in the game.
  Asked the same day whether the addons have since done what the Stitches do: no. Console Port has no release
  after 3.3.13 (30 Oct), and the two changes on its main branch since are a ring skin lookup and the MoP
  spellbook flyout. MelloUI's Route.lua gained only `M.Taxis`, `M:DistanceLineText` and `Beacon.Area` between
  2.1.40 and 2.1.51, so none of the Route additions is native; its game menu entry is still placed under
  Options or the Shop with no regard for EllesmereUI's two buttons, and EllesmereUI's code does not name
  MelloUI. Nearest to an overlap: MelloUI's Nearest Quest First and Nearest Turn In (2.1.50) beside our quest
  run.
- Checked against the addons updated by 2026-11-15: MelloUI 2.1.51 to 2.1.52, EllesmereUI 9.8.5 to 9.8.6,
  DungeonJournal 2.0.5 to 2.0.7; Console Port 3.3.13 and RestedXP v4.11.36 unchanged. Nothing of ours needed a
  change. MelloUI 2.1.52 takes its quests from the player's Questie and ships no quest data of its own: Route.lua
  lost `Needed.*`, `Beacon.GameElsewhere` and `M:ItemFirst` (none of them ours to use); `M:ObjectivePlaces` and
  `MelloUI:QuestTurnIn` keep their shapes but answer nil without Questie, and the quest run then falls back to
  `C_QuestLog.GetNextWaypoint` as before. (`MelloUI:QuestTurnIn` lives in MelloUI_QuestList, which the trim
  unticks, so with the trim on the quest run always uses the game's waypoints for turn-ins; that was so before.)
  New modules QuestMoments and MaxDps: the trim switches them off once, as any module an update adds. The game
  menu entry now makes room for Polestar's button only, still not EllesmereUI's, so our fix stays. Changelog has
  no Route entry beyond dropping the First: loot line. All 68 MelloUI names still defined. DungeonJournal: the
  eight names are there (`FDJ.QuestMatchesFaction` still exported). EllesmereUI: both menu button names and
  `EllesmereUIQuestTracker` there. None of this was tried in the game.
- Checked against the addons updated by 2026-11-17 (asked for): Console Port 3.3.13 to
  3.3.14 (its first release since 30 Oct), MelloUI 2.1.52 to 2.1.58, EllesmereUI 9.8.6 to 9.8.8, DungeonJournal
  2.0.7 to 2.0.9; RestedXP v4.11.36 unchanged. Nothing of ours needed a change. Console Port: of the 31 files
  changed none holds the bindings, `db.Radial` or the CPAPI calls the Stitch makes (`GetBindingAction`,
  `SetBinding`, `GetInventorySlotInfo`, `LinkEnv`, `Log`). New on Forever: it watches
  INPUT_DEVICE_INTERFACE_TRANSITION (`CPAPI.IsNativeNavigationActive`, `OnNativeNavigationChanged`), and its game
  menu ring and mouse handling now default on but stand aside while the game's own gamepad interface is up.
  Only the mouse and the menu ring listen to that event, so ConsolePort_World's loot window and aura rows are
  still set up once, and InputStyle.lua stays. Its game menu default does not touch the Open Game Menu
  Directly fix (that one is about the escape chain and GamePadCursorAutoEnable). Group loot rolls in the quick
  menu now show on Forever too (`IsRetailVersion` in place of `IsModernVersion`). MelloUI: every name the two
  Stitches lean on is still defined (`M.Ground.SEG`, `OPENB`, `grids`, `SWIM_REAL`, `M.ClipToCircle` among
  them), and no line defining one was taken away in Route.lua, Core.lua or Config.lua (blobless clone, data
  files never fetched). Its game menu entry still makes room for Polestar's button only, so our EllesmereUI
  fix stays. New modules RolePicker, QuestTrackerPad and the Oldschool kit: the trim switches them off once.
  MelloUI 2.1.55 added its own "Controller Forever" support with a Bindings.xml of its own. DungeonJournal:
  the eight names the reader reads are there with the same shapes (`FDJ.TurnInSpotFor`,
  `FDJ.QuestMatchesFaction`, `trackedDungeons` on the character's saved table). EllesmereUI: both menu button
  names and `EllesmereUIQuestTracker` there. None of this was tried in the game.
- Thread (Routes) 0.12.0: RestedXP read ahead, and the step said on screen (asked for 2026-11-12: route by
  the upcoming RestedXP steps, and a floating text that describes the step when the route changes; of the
  interview all four read-ahead parts were taken, the step then the route for the words, upper middle and
  configurable, every new destination).
  - `Guide.lua` reads RestedXP as it runs: `RXP.currentGuide.steps`, `RXPCData.currentStep`, each step's
    elements (`tag`, `text`, `completed`, `skip`, and for a place `zone/x/y` or `wx/wy/instance`), and the
    arrow's element only while the arrow is shown (hidden, it keeps its last spot: that was a fault before).
    With none of that to be found it falls back to the arrow's spot. RestedXP is CC BY-NC-SA: read, never copied.
  - `Route.lua`: the search is a function of its own (`Search`), with a queue behind the main search for ways
    that can wait (`ns.SearchLater`); `dest.walkOnly` for a fly step; a fresh destination is described once its
    route is known. `Ahead.lua`: the ways between the next steps, drawn fainter (`ns.ahead.legs`), the first
    handed over as the route when a step is done where it was (`Ahead.Take`). `Float.lua`: the words on screen.
  - Passes the pretend session with a stand-in guide (a route to the step, two ways found ahead, the handover
    with no search, a fly step walked to, a hearthstone step said and not routed, two steps at one place, the
    words going out and coming back).
  - Confirmed in-game (2026-11-12, after a full start, with a guide running): the step's words appear
    on screen and the fainter trail runs on ahead. So RestedXP's `RXP` table and its
    steps are there as read. Not heard one by one: the handover with no pause when a step is done, a fly
    step walked to, a hearthstone step said and not routed, and whether the size and place of the words suit.
Below, read Wayfarer, `PatchwerkForever_Wayfarer` and `/wayfarer` as Thread (Routes) and its names;
the log keeps the names things had when it was written.

**Name (2026-11-12): "Patchwerk Forever: Wayfarer".** It was "Wayfinder Forever" until then; CurseForge
already has an addon of that name, so it was renamed for the upload. Folders
`PatchwerkForever_Wayfarer` and `_Kalimdor`, `_EasternKingdoms`, `_ZephrasIsle`; saved data
`PatchwerkForever_WayfarerDB`; commands `/wayfarer` and `/pfw`. Below, the log keeps the old name
where it was written before the change: read Wayfinder, `WayfinderForever` and `/wayfinder` as the
new ones. A copy from just before the rename is in `backup/wayfinder-before-rename/`.

**Where it all is (moved 2026-11-12, as asked):** the repository is
`G:\Dev\patchwerk-forever` (addons/, tools/, release/), out of the game's folder. The game's
`Interface\AddOns` no longer holds junctions: `python build.py` writes the addons there from
`addons/`, file for file, with a line `## X-Build: <commit>` in each TOC; `python build.py watch`
does it on every save. Edit in the repository, build, then /reload (or start the game again when
the build says so). The tools find `addons/` from where they are; only the game's own path
(`G:/Games/World of Warcraft`) is written into them. The build tool passed its tries on a scratch
copy and built the real folders; the game has NOT been started on the built folders yet.

**Patchwerk Forever split into a base and parts (2026-11-12, as asked; the user's choices: one
part per addon it fixes, separate CurseForge projects, Wayfarer standalone but sharing the look,
icons drawn by the tools and replaceable):** `PatchwerkForever` 2.0.0 is the base (Core.lua,
Settings.lua: the global `PatchwerkForever`, the settings page made at login, `/patchwerk`, saved
data still all in `PatchwerkForeverDB`). The fixes moved, unchanged but for their first lines, to
`PatchwerkForever_ConsolePort`, `PatchwerkForever_MelloUIRoute` and `PatchwerkForever_MelloUI`
(each 2.0.0; `Link.lua` first, `## Dependencies: PatchwerkForever` and the addon it is for). The
base tells someone once when Console Port or MelloUI runs and its part is not installed. The
one-time carry-over of settings from before 1.0.0 is gone. Wayfarer is 0.10.1: only its icon
changed. Art: `python art.py` draws an icon family (64 x 64 `Media/icon.tga` per addon, 512 x 512
`release/<folder>/logo.png`, `release/art-preview.png`); a PNG in `art/<folder>/` replaces or adds
a picture and is converted on every build. `python release.py` now builds five projects, each with
a summary and notes on what to set on CurseForge. `python lua_patchwerk.py` plays logins of the
base with and without parts. Passes here; built into the game. Confirmed in-game
(2026-11-12, after a full start): the base and the Console Port part load from the built folders
with the settings intact. Not heard one by one: whether the addon list shows
the icons, and each Console Port fix in play. The
fixes inside the Console Port and MelloUI parts cannot be run outside the game. Not known until
tried: whether Forever's addon list shows `## IconTexture`, and that the Console Port part behaves
as before now that it is an addon of its own (the user runs Console Port but not MelloUI, so the
two MelloUI parts go untried here).

**Release (prepared 2026-11-12, not yet uploaded):** version 0.9.0, a beta: only a Horde character
in Kalimdor has been played. MIT for the code and pictures; README.md, CHANGELOG.md and LICENSE in
the main folder. `python release.py` checks the four folders (versions agree, every listed file is
there, no old name left) and writes `release/PatchwerkForever_Wayfarer/` in the repository:
the zip of all four folders, the description (the README) and the changelog; the short summary is
there too. Uploaded by hand (now also by `upload.py`). After a change: CHANGELOG.md, the version in the four TOCs and in
`pack.py`, then `release.py`. `python carry_saved.py` carried the settings and herb spots over from
the old name's saved file (done, with the game closed). Confirmed in-game (2026-11-12):
the renamed addon loads with the settings and herb spots intact.

Decided with the user (2026-11-11):
- First usable version covers **ground and flight paths**; buildings, bridges and lifts come later.
- It is **its own addon**, separate from Patchwerk Forever.
- A Lua interpreter (LuaJIT via the Python package `lupa`) is installed so code is run here before it is tried in-game.

## What is proven (tools in this folder)

- `casc.py` reads any file out of the install's storage for the `wowf` product. Root v2, 2.4 M files.
- `terrain.py` reads a map's tiles and gives heights and slopes per 4.17-yard cell. `mulgore.py` draws them.
- Terrain is not encrypted. Kalimdor has 988 tiles (16.2 M cells), Eastern Kingdoms 736 (12.1 M).
- Measured: extraction about 43 s + 32 s; walkability as run-length text about 3.9 MB + 2.9 MB.
- Also present and readable: water (MH2O), object placements (MDDF/MODF), texture lists (MDID),
  and the tables TaxiNodes, TaxiPath, TaxiPathNode, Map, UiMap, UiMapAssignment (WDC5 format).
- `luacheck.py` compiles an addon's Lua with a real parser.

## Milestones

Each ends with something that can be checked here, before anything goes in-game.

### 1. World extractor — done 2026-11-11
- `db2.py` reads the game's tables (WDC5, numbers only). `world.py` finds every map's world file in
  `Map.db2` and extracts whole maps: `python world.py 0 1 2991`.
- Per cell: NONE, WALK, STEEP (over 50 degrees), WADE (shallow water), SWIM (1.5 yards deep or more),
  plus the ground height. Output in `world/`: `map_<id>.bin` for the later tools, `map_<id>.png` to look at.
- Extracted: Eastern Kingdoms (map 0, 736 tiles, 25 s), Kalimdor (map 1, 988 tiles, 35 s), and the new
  zone on map 2991 (72 tiles, an island; MelloUI calls it Zephras Isle). No tile failed.
- 73 of the table's 81 maps are readable; 8 are encrypted (unreleased content) and skipped.
  Maps 3065 and 3104 are blank flat placeholders. Map 3021 (60 tiles) is real terrain of an unknown zone.
- Continent map bounds turned out not to be needed: in-game the addon can ask the game for world
  coordinates directly (`C_Map.GetWorldPosFromMapPos`, and back with `GetMapPosFromWorldPos`), so the
  data is keyed by map id and world coordinates. `UiMapAssignment` is not parsed.
- Not yet judged: whether 50 degrees is the right limit everywhere, and beaches where the sea has no
  water data (map 2991's surroundings are holes, not sea). The planner's test trips in milestone 2 will show.

### 2. Planner prototype, offline — done 2026-11-11
- `nav.py`: the grid is cut into blocks of 32 x 32 cells (133 yards). A *gate* is made wherever two
  blocks touch along passable cells (one per 16 cells of open border), and inside each block the
  cheapest walk between each pair of its gates is worked out once. A route is: start to its block's
  gates, A* over the gates, gates to the goal. `build_nav.py` builds it, `trips.py` runs test trips
  and draws them (`world/trips_<id>.png`) and what connects to what (`world/islands_<id>.png`).
- Sizes: Kalimdor 92,869 gates and 222,020 links (built in 93 s); Eastern Kingdoms 70,024 and
  168,929 (74 s); the island 1,865 and 4,341. With a gate per 32 cells instead: about 17% fewer gates
  and 35% fewer links, routes 2.6% longer than exact instead of 2.1%.
- Quality: six trips checked against an exact cell-by-cell search were 0.6 to 4.0% longer (2.1% average).
- Speed (in Python): 4 to 110 ms a search; the longest (Booty Bay to Light's Hope) looked at 29,653 gates.
- Costs: seconds at running speed; wading 1.25x, swimming 1.6x (3x since 5a); open water more than
  2 blocks from land is left out.

What the test trips showed:
- **Where a tunnel, bridge or lift is the only way, the ground is cut off.** Dun Morogh (tunnels to
  Loch Modan and Elwynn's tram), Winterspring (Timbermaw Hold), Searing Gorge, the top of Thunder Bluff
  (lifts) and others are separate stretches. `islands_0.png` shows them in colours.
- **Worse than "no way": the planner then swims round the coast.** Thelsamar to Menethil Harbor came
  out as 48 minutes, Booty Bay to Light's Hope as 71, most of it in the sea, because the Dun Algaz
  tunnels and the Thandol Span are missing. A confident, wrong route.
- So two things move up before a first usable version: the key links (tunnels, bridges, lifts),
  and a limit on swimming (a much higher price, and a route that is mostly swimming is reported as
  doubtful rather than drawn as normal).

For the addon (milestone 4):
- Loading 93,000 gates as Lua tables would cost tens of MB. The data has to be packed strings,
  decoded a tile at a time as a search reaches it.
- A straightening pass over the fine grid would remove most of the 2% and the slightly zig-zag look.

### 3. Flight paths — done 2026-11-11
- `flights.py` reads the game's TaxiNodes (101 rows), TaxiPath (328) and TaxiPathNode (10,965 points) and
  writes `world/flights.bin`. The tables are classic Azeroth plus Forever's own zones (Riverglades,
  Tidegear Coast, Mount Hyjal). A real flight point is a row with a bit number of its own and a mount;
  its side comes from which mount it has. Alliance: 37 points, 140 direct flights. Horde: 35 and 148.
  Three new points (Tidegear Coast, both Powderfuse Ports) have no flights in the tables.
- `db2.texts()` reads a table's text column (names).
- A flight's time is not in the tables: it is the length of its line at 32 yards a second. Against
  remembered classic times that is within about 10% (Orgrimmar to Crossroads 1:43). Not timed in-game.
- `nav.Coarse.add_flights(ground, flights, side, known)`: each flight point is a node on the ground
  beside the flight master and a node in the air; boarding (15 s) and landing (3 s) join them and
  flights join the air nodes, so a flight through several points pays for boarding once. The search's
  guide then allows for flying speed; checked against a much weaker guide on 29 trips: same answers.
- `python trips.py 1 horde` (or `0 alliance`, ...) runs the test trips with flights and draws them
  (`world/trips_<id>_<side>.png`, flights in light blue). Examples: Crossroads to Gadgetzan 4.9 min
  (23 on foot), Booty Bay to Light's Hope 14 min (61 on foot), Thelsamar to Menethil 3 min (12 on foot).
  Searches 7 to 69 ms in Python.
- Flight masters not on our ground:
  - on a tower (Thunder Bluff 49 yd up, Orgrimmar 64, Stormwind 31, Booty Bay 34 to 37): joined to the
    ground below with a guessed climb of 4 yards walked a yard climbed. Approximate.
  - inside something (Ironforge, the Undercity): flown through, never boarded or left there. So a Horde
    route in Tirisfal walks to the Sepulcher instead of using the Undercity. Needs "floors as places".
- For the addon: `C_TaxiMap.GetTaxiNodesForMap(uiMapID)` exists on Forever and its `nodeID` is the
  table's id; each node it returns has `isUndiscovered` and `faction`, so which points the character
  knows should be available anywhere, not only at a flight master. To be tried in-game in milestone 4.

### 4. The addon, first version — built 2026-11-11; tried in-game the same day and reported working
Working name **Wayfinder Forever** (folder `WayfinderForever`, `/wayfinder`, saved data `WayfinderForeverDB`).

Done and checked here:
- `pack.py` writes the map data as three more addons, loaded only when the character is on that map:
  `WayfinderForever_Kalimdor` (2.2 MB), `_EasternKingdoms` (1.7 MB), `_ZephrasIsle` (62 KB). Cells are
  runs of a kind a tile; each block's gates and walks are a string; links and flights are small tables.
  Everything large is text of 64 characters in Lua long brackets. The format is in pack.py's heading.
  A map's data reads in 0.02 s and takes 3 to 5 MB in memory.
- `Planner.lua` uses no game function. `python lua_trips.py 1 horde` (and the other five runs) runs it
  in a real Lua 5.1 on the packed data against the Python prototype: on all 87 trip runs the cost is
  within 0.04% and the flights are the same. Slowest search 374 ms (Booty Bay to Light's Hope on foot);
  in the game a search gives way every 4 ms. Decoded blocks are dropped after each search.
- The game side: `Core.lua` (settings, `/wayfinder go | to x y | stop | config | where`, two bindable
  actions in Bindings.xml), `Route.lua` (the map pin as destination, searching a little each frame,
  following the trail, a new route after a wrong turn, arriving), `WorldMap.lua` and `Minimap.lua`
  (the trail: gold walking, pink tunnel/bridge/lift, light blue flight), `Settings.lua` (its own page).
- `python lua_shell.py` runs all of it against a stand-in for the game (`wowstub.lua`) through a
  whole session. It proves the addon's own code runs; it cannot prove the game answers like the stand-in.

Decided by the user 2026-11-11: **MelloUI is disabled from here on**; Wayfinder is the routing system.
So Wayfinder stands alone (it never used MelloUI), and what MelloUI's Route was used for has to come
from Wayfinder: destinations from the tracked quest and RestedXP steps first, then milestone 6.
Gone with MelloUI and not replaced: RestedXP steps shown in the quest tracker (a MelloUI feature).
Patchwerk Forever's MelloUI fixes switch themselves off without MelloUI; they stay for other users.

Reported in-game:
- 2026-11-11: with MelloUI and Wayfinder both running, the minimap turned black under EllesmereUI's
  minimap. Cause not found by reading either addon. Our minimap layer was a child of the minimap;
  it is now a frame of its own laid over it, and that was confirmed to cure it. The cause itself
  was never found: do not hang frames on the minimap in this setup.

- 2026-11-11: on first load the minimap trail jumped about for a few seconds; reported as the map
  bouncing, then settling (the minimap itself, most likely EllesmereUI setting its size and zoom). The
  trail now waits after a login or reload until the minimap has kept one size, place and zoom for a
  second (eight at most). Not yet confirmed in-game.

- 2026-11-11, after MelloUI was switched off: the minimap follows the mouse until clicked, and
  EllesmereUI's minimap background grows upward. Not explained. Checked: Wayfinder only reads from
  the minimap (size, place, strata, alpha) and lays a mouse-disabled frame over it; nothing in
  EllesmereUI's minimap module looks for such frames; its saved minimap position is intact (centre
  820, 383, size 280); only its unlock mode makes frames follow the cursor. Tried in the game: it still
  happens with "Trail On The Minimap" off, so the trail is not the cause.
  Found by the user: the addon **Lueur** (herb and ore icons on the minimap). To read the minimap's dots
  it moves the minimap under the mouse and sweeps over it (`Minimap:AdjustPointsOffset`,
  `UpdateMouseoverAtPoint`); its own settings say "each scan hides the minimap for a moment". That
  is the scanning, the bounce and the sticking to the cursor. Nothing to do with Wayfinder,
  EllesmereUI or MelloUI. Two guesses of mine were wrong along the way (EllesmereUI settling at
  login; MapUtils, which also sweeps the minimap but was not the cause). The hold-until-steady guard
  in Minimap.lua came from the first guess; it is harmless and stays.

- 2026-11-11: reported that navigation did not update unless MelloUI was enabled. Cause: MelloUI's Route was what
  laid the game's map pin on each RestedXP guide step, and Wayfinder only followed the pin. Fix:
  `Sources.lua`. With no pin, the route goes to the place RestedXP's arrow points at
  (`RXPG_ARROW.element`: `zone`, `x`, `y` as a place on a zone's map, turned into world coordinates by
  the game; else `wx`, `wy`, `instance`, RestedXP's own, x west and y north) and moves on with the
  guide. A pin or `/wayfinder to` comes first. A step you stop is left until the guide moves on; a step
  you reach is not routed to again unless you walk 40 yards away with it still open. Setting "Follow My
  RestedXP Guide". Passes the stand-in session; not yet confirmed in-game. Needs a full game restart
  (a new file in the TOC).
- Guide following confirmed in-game (2026-11-11, MelloUI off).
- Herb and ore spots (asked for 2026-11-11): built as `Nodes.lua`; confirmed in-game that a gathered spot shows on the minimap. A spot is
  remembered when a cast aimed at something that is not a creature (UNIT_SPELLCAST_SENT gives its
  name) is followed within 12 s by loot holding a herb or an ore (item class 7, subclass 9 or 7; not
  from a creature where the game says). Kept in `WayfinderForeverDB.nodes` and `.nodeKinds` for all
  characters. Shown with the item's icon on the minimap and on a zone's world map. Settings: Remember
  Herb And Ore Spots, and one each for the two maps. `/wayfinder nodes`, `/wayfinder nodes forget`.
  It shows where things grow, not whether one is up: the tracking dots cannot be read without moving
  the minimap about (what Lueur did). Forever does name the node in the cast event and uses those class
  numbers (it works). Not yet heard about: ore icons, the zone map, `/wayfinder nodes forget`.
- `ns.MinimapView(frame, above)` and `ns.WorldMapView()` share the placing maths with other layers.

- Sparkle on things nearby (asked for 2026-11-11, like Lueur's): built as `Sparkle.lua`, not yet
  tried in-game. The game picks one "soft interact" target and gives it a nameplate; a turning star
  (the game's own `Interface\Cooldown\star4`, no art of Lueur's) is hung on it when it is a herb, a
  vein, a chest or a quest object, coloured by kind. The kind comes from the cursor the game would show
  (`SetUnitCursorTexture` on a hidden texture, matched against `GetFileIDFromPath` of the cursor files)
  and from the names of gathered spots. While its setting is on it sets the game's
  `SoftTargetNameplateInteract` and `SoftTargetIconGameObject` to 1, keeps what they were in
  `WayfinderForeverDB.sparkleWas` and puts them back when unticked. `/wayfinder sparkle` says what the
  game points at and why it does or does not sparkle. Unknown until tried: whether those two settings
  are enough for a nameplate on Forever, whether the cursors can be told apart, the size and place of
  the star, and how it sits with EllesmereUI's nameplates.
- Sparkle, first try in-game (2026-11-11): the game's herb icon showed but no star. Likely cause: on
  Forever the cursor comes back as an atlas (a named piece of a shared picture), so matching file
  numbers recognised nothing and the thing was taken as a plain "other" and hidden. Now the kind is
  read from words in the atlas's name (or a file's path), and a thing whose kind the game does not
  tell sparkles anyway. Also added, as asked: the thing's name written over it ("Name Over The
  Thing"). Not yet confirmed in-game.
- Sparkle, second try (2026-11-11): `/wayfinder sparkle` said the game pointed at nothing. Cause: a
  thing in the world does not "exist" for `UnitExists` on this client even while the game points at
  it; `UnitIsGameObject("softinteract")` is the call that says so. Fixed, and the nameplate is now
  also looked for among the nameplates on screen (`UnitIsUnit(token, "softinteract")`) when asking by
  "softinteract" gives nothing. The command now also says what was last pointed at, since typing on
  a keyboard can make the game let go (its SoftTargetInteract is 1: gamepad only). The stand-in now
  behaves like Forever here, so the first version would have failed its test. Confirmed in-game: a herb sparkles and
  shows its name. Not yet heard about: veins, chests, quest objects, the colours, the star's size.
- Customising (asked for 2026-11-11, by interview): built, passes the stand-in session, not yet tried
  in-game. Chosen: the sparkle, the name and the trail; each kind of thing its own look; hide in
  combat and in instances as options, and an ignore list; everything on the options page with the
  game's colour picker and a Test button.
  - `ns.settings` in Core.lua now holds tick boxes, sliders, pick lists, colours ("ffRRGGBB", as the
    game's colour swatch keeps them), buttons and headings, each with the sub-page it is on.
    Settings.lua builds the pages from it: 60 settings on a first page and seven sub-pages.
  - Sparkle.lua: six effects (star, soft glow, pulsing ring, light beam, swirl, brackets) and "none",
    drawn from the addon's own pictures in `Media/` (made by `python media.py`; previews in
    `world/media_preview/`). Each of herb, ore, chest, quest object and other has its own effect,
    colour, size, brightness, height and speed. Hide In Combat, Hide In Dungeons And Raids. Ignore:
    `/wayfinder ignore` (and `undo`, `list`, `clear`), a bindable action, a Forget button.
  - The name: size, font (the game's, Friz Quadrata, Arial Narrow, Morpheus, Skurri; a font the client
    lacks falls back to the game's), outline, the kind's colour or one fixed colour, above or below.
  - Trail.lua: the trail's three colours, its thickness on each map, solid, dashes or dots, and a
    pattern that flows toward the destination; used by WorldMap.lua and Minimap.lua.
  - Confirmed in-game (2026-11-11, after a full restart): the new options pages open and
    work. Not yet heard about, one by one: each effect's look in the world, the name's fonts, the
    trail styles, the cost of a flowing trail on the open world map (redrawn about 30 times a
    second), the ignore list and its bound key.
- Sparkle "behind the character" (asked for 2026-11-11): the sparkle in the world with depth. Not
  possible: an addon draws on top of the finished 3D picture, and the game's own outline is already at
  its highest on the user's client (`graphicsOutlineMode` 2). Built the stand-in that was agreed: the
  whole mark fades as it comes over an oval where the character is taken to stand (Sparkle.lua,
  `Body`, `Covered`, `Tuck`). The oval is worked out from the camera's distance (`GetCameraZoom`),
  hanging under the middle of the screen. New page "Sparkle: Behind My Character" (off by default):
  the tick box, Brightness Left, Character Size, Character Width, Across, Up, and a Show button that
  draws the oval for ten seconds. 66 settings, 8 sub-pages, 7 buttons now. Passes the stand-in
  session; not tried in-game. Unknown until tried:
  - whether `GetCameraZoom` is on Forever (it is not in the interface source, which never calls it);
    without it 15 yards is assumed and `/wayfinder sparkle` says so;
  - whether the game tells where a mark hung on a nameplate is (`GetCenter` is documented as secret
    "when anchoring secret"); if not, the mark stays bright and `/wayfinder sparkle` says so;
  - whether the oval sits on the character with the user's camera (ConsolePort may keep it off-centre).
  It assumes the thing is on the far side of the character and cannot cut to the character's shape.
  Confirmed in-game (2026-11-12): the sparkle fades over the character. So the game does
  tell where a mark hung on a herb's nameplate is. Not yet heard: whether the oval follows the zoom
  (that is, whether `GetCameraZoom` is there), and which slider values were settled on.
- Destinations from a tracked quest (asked for 2026-11-12): built in Sources.lua, which now chooses
  between two sources when there is no pin: the RestedXP guide and a tracked quest.
  - Which quest: the one the game's arrow is on (`C_SuperTrack.GetSuperTrackedQuestID`), else (setting
    "Which Quest") the nearest in the tracker; the one being followed is kept so two do not take turns.
  - Where it is: asked the way the game's own world map asks, `GetQuestUiMapID(id, true)` then the
    quest's mark in `C_QuestLog.GetQuestsOnMap(uiMap)`. The Forever interface source uses both
    (QuestMapFrame.lua, QuestDataProvider.lua), which is why they are trusted to be there. A quest
    on another continent is passed over unless the game gives a next stop on this one
    (`C_QuestLog.GetNextWaypoint`), which is then routed to.
  - Settings: Follow My Tracked Quest (on), Which Quest, and which of guide and quest goes first
    (guide by default: the game puts its arrow on every quest you accept, which would keep taking
    over from a guide). A reached quest place is left alone until you are 120 yards off or its mark
    moves; one you stopped, until its mark moves. `/wayfinder quest` says what the game reports.
  - Passes the stand-in session; not tried in-game. Unknown until tried: whether Forever's quests
    have marks on the map at all, and whether the game's arrow is on a quest by itself there.
- Subtle sparkles (asked for 2026-11-12, subtle and immersive): five more effects in the list,
  Subtle: glints, fireflies, faint shimmer, ground ripple, wisp. Two new pictures from media.py
  (glint.tga, mote.tga). An Apply button on the first page gives every kind one of them, changing
  only the effect. Every mark, and its name, now comes in over a third of a second instead of
  popping. 69 settings, 8 sub-pages, 8 buttons now. Passes the stand-in session. New picture files
  need a full restart of the game.
- Confirmed in-game (2026-11-12, after a full restart): the quest route and the subtle
  sparkles both work. So Forever's quests do have marks on the map. Not yet heard, one by one: which
  subtle effects were kept, a quest on the other continent, guide and quest together, the nearest-quest
  choice with nothing under the game's arrow.
- Boats and zeppelins, and with them routes to another continent (asked for 2026-11-12; version
  0.10.0): built, passes the checks here. Confirmed in-game (2026-11-12, after a full
  start): both addons load through the junctions into the repository, and a pin on the other
  continent gets a route. Not yet heard: an actual ride (boarding, the loading screen, the trail
  picking up after landing), whether the waits and boarding spots are right, and which of the
  lines new to Forever really run.
  - Where they are: in the game's own TaxiPathNode table, like flights. A line that stops (flag 2,
    with the seconds it waits) is a boat or zeppelin; a line may change map on the way.
    `python crossings.py` reads them into `world/crossings.bin`: 12 lines, 28 rides. Classic ones:
    Ratchet to Booty Bay, Orgrimmar to Undercity, Orgrimmar to Grom'gol, Undercity to Grom'gol,
    Menethil to Theramore, Rut'theran to Auberdine, the Feathermoon ferry. New to Forever: Menethil
    to Southshore to Auberdine (11167), Auberdine to Stormwind (11616), a boat from near Gadgetzan
    to "Powderfuse Port" (11391), zeppelins to Zephras Isle from near the Undercity (11398) and from
    Thunder Bluff (11457). Left out: 295 (the old Menethil to Auberdine line), 436, 312, 314.
  - Guessed, since the tables do not say: speed 30 yd/s; the wait (half the round trip); which side
    may ride (the sides of the flight points nearest each stop); where you board (the nearest
    walkable ground joined to the largest part of the map, within 250 yards, with the walk along
    the dock or the climb up the tower allowed for); and whether a line runs at all.
  - `Journey.lua` (game-free, like the planner): walks found by the planner joined by up to two
    rides, every chain listed with the least it could cost and worked out in that order.
    `python lua_journeys.py` sets it against a brute-force reckoning with the Python prototype on
    14 journeys: same rides, costs within 0.02%. `python pack.py crossings` writes `Crossings.lua`
    into the addon's own folder.
  - In the addon: `ns.route.parts[map]` holds the part of a journey on another map; the other
    continent's world map draws it, and after the loading screen it becomes the part followed
    without a new search. 'ride' and 'gap' join 'walk', 'link' and 'fly' as ways a point is
    reached. Settings: Use Boats And Zeppelins, Colour: Boats And Zeppelins (71 settings now).
  - Known weak spots: the Stormwind harbour and Booty Bay stops sit by city floors the planner does
    not walk on, so a route from them may not be found (Auberdine to Goldshire goes by Menethil);
    the Alliance has no line to Zephras Isle in the tables; a line the server does not run would
    send you to an empty dock.
- Smoothing the trail: done by a separate session on 2026-11-11 in `P.Line` (`Planner.lua`), checked
  again here. The line is straightened where a straight walk stays on the ground, and its corners
  rounded. `python lua_smooth.py` over 87 trips: points 9531 to 3427 (most in one line 958 to 290),
  turning 452,925 to 42,710 degrees, turns of 30 degrees or more 9222 to 231, no smoothed line off
  the ground; costs and flights unchanged (`lua_trips.py` differs on 0 trips). Slowest line 394 ms
  (was 277), spread over frames in the game. Not yet tried in-game.

Not done yet:
- In-game so far: the first try worked (no detail given on which parts were looked at). Not yet
  heard about: the minimap trail turning with the character, a wrong turn, arriving, the settings page,
  the bindings, a route through a lift or a tunnel.
- The time left shown on screen. (Destinations from RestedXP steps and from a tracked quest, the
  straightening pass, and routes across continents by boat and zeppelin: done, see above.)
- Flight points known: taken from `C_TaxiMap.GetTaxiNodesForMap` on the continent's map (1414, 1415).
  If the game returns nothing there, all of the side's points are used and it says so once.
- Memory during a search right across a continent on foot is tens of MB for a moment.
- Done when: a few routes have been walked in-game.

### 5. Structures and special links (the hard part)
Milestone 2 showed the key links are needed for the first version, not after it.

#### 5a. Tunnels, bridges, gates; swimming — done 2026-11-11
- Guessing from bounding boxes was tried first and dropped: it missed long tunnels (several models
  end to end) and made links up 40-yard cliffs.
- What works: `wmo.py` reads the building models' own collision triangles (root file -> group files ->
  vertices, triangles, a collide flag each) and places them. The placing is checked against the game:
  a model's box, turned (about its x, then y, then the vertical plus half a turn), scaled and moved,
  gives the box its placement states, for every model but 24.
- `links.py`: models whose boxes touch are one structure. Its floors (triangles under 50 degrees) go
  on a one-yard grid, walls and low ceilings stop a character, and a link is made only where there is
  a walk from one patch of ground over the floors to another, and the way round is missing or more
  than 3 times (and 250 yards) longer. A link's length is the real walk. `python links.py 0` takes
  about 100 s; it writes `world/links_<id>.txt` (every link) and `world/nav_<id>_linked.bin`.
  The ground-only graph `nav_<id>.bin` is left as it is, so links.py can be run again.
- Found: 64 links in Eastern Kingdoms, 80 in Kalimdor. Among them both Dun Morogh gate passes, the four
  Dun Algaz tunnels, the Thandol Span, Coldridge Pass, Timbermaw Hold (Felwood, Winterspring), the
  Talondeep Path. Dun Morogh and Winterspring are no longer cut off.
- Test trips after: every Eastern Kingdoms test town is on one stretch. Thelsamar to Menethil Harbor
  12 min through 4 links (was a 46 min swim). Booty Bay to Light's Hope 61 min (was 71, mostly sea).
- Swimming costs 3 times walking (was 1.6). `nav.swimming()` measures a route's swim; over 300 yards
  or a quarter of the route is reported as DOUBTFUL, with where the swims are.
- `hand_links.txt`: links told by hand (a lift: both ends and the ride's seconds). Empty so far.
- Lifts are in no file we can read: the game's own object table (GameObjects.db2) holds only signs and
  the like, its transport table is empty, and the terrain shows 15 look-alike cliff spots round
  Thunder Bluff. So they are marked in-game: a macro stores the character's position in
  `PatchwerkForeverDB.marks`, and `marks.py` reads the saved file, checks each mark against our ground
  and height, and writes the pairs into `hand_links.txt`.
- Done for Thunder Bluff's two western lifts (marks made in the game, 2026-11-11). Two things learned:
  WoW Forever's UnitPosition gives no height (0), and a lift's upper landing is a wooden platform
  standing out over the lower ground, so both marks of a lift fall on the same ground in our data.
  `python marks.py TBBT` says which marks are tops; the top end is then moved to the nearest ground
  at least 15 yards higher (18 and 25 yards away here). The inn on the bluff to Bloodhoof Village now
  routes: 1469 yd through one lift. The lift's seconds are the gap between the two presses (35, 45).
- The two eastern lifts were added later the same day (marks 5 to 8, `python marks.py TBBTBTTB`).
  Marks 6 and 7 are the tops (worked out from the walk between them, then confirmed).
  From the inn, Crossroads now routes by
  an eastern lift and Bloodhoof Village by a western one.
- One-way links (2026-11-11): a safe drop off Thunder Bluff's south-west rise, marks 9 to 11, in two
  steps (48 yd then 78 yd down in our data; reported safe in the game: it is steep ground and probably a
  slide). `python marks.py TBBTBTTBDDD`: D marks made going down become links from each to the next
  only. `hand_links.txt` lines take `oneway` after the seconds; `Coarse.add_link(..., oneway=True)`;
  pack.py writes a 1 after such a link and Planner.lua then joins it one way. Checked in both
  planners: taken going down (inn to Bloodhoof Village 209 s, was 250 s by lift), never going up.
- After new marks: `python marks.py <a letter a mark>`, `python links.py 1`, `python pack.py 1`, then
  `/reload` in the game.

Still wrong or missing after 5a:
- **Lifts**: the Undercity's (floors the planner does not know), any other Thunder Bluff lifts.
  They need marking in-game (see marks.py), or learning in-game (5b). The Great Lift and Freewind
  Post's lift were found from their tower's model on 2026-11-21 (lifts.py): Crossroads to Gadgetzan
  is 20.0 min by the lift, was 24.5 round through Dustwallow; their 30 s is a guess, not timed.
- trips.py shows a trip's minutes from its length; a lift's ride time is in the route's cost but not
  in the minutes shown.
- **Places that are floor, not ground**: Booty Bay, and the insides of Stormwind, Ironforge, the
  Undercity. A place there snaps to the nearest ground (for Booty Bay: the sea bed under the docks).
  The floor grid of links.py is the start of an answer: keep the floors as places, not only as links.
- **Doors**: a gate the game keeps locked is still a link (Stonewrought Pass, Loch Modan to Searing Gorge).
- 19 short links are marked "STEEP, check" in the links files: stairs or ramps as steep as the walk
  allows. Likely real (Jintha'Alor's terraces come out as a chain), not checked in-game.
- Bridges that are scenery models (M2), not building models, are not read.
- In the addon a link needs its swim length kept beside its cost, so the time shown is the real time.

#### Later
  b. Learn from where the player walks, checked against our height data so a fall is never learned as a path.
     Lifts are the first use.
  c. Floors as places (see above).
- Boats and zeppelins: from the game's transport tables if readable, else a hand-made table.
- Roads: recognise road textures in the terrain files and make them cheaper, so routes prefer them.

### 6. Carry over what Patchwerk Forever adds to MelloUI's Route
These get simpler and better once the planner is ours:
- Blocked spots that really close a stretch (today MelloUI's own roads can't be closed).
- Mount-aware route choice (not possible from outside MelloUI).
- Hearthstone and teleports as real route options, not just a suggestion.
- Quest run and the next-guide-steps trail.

## Risks and open questions

- **Structures.** Until milestone 5, routes in cities and across bridges will be wrong or missing.
  The first version should say so rather than draw a confident line through a wall.
- **In-game performance.** Lua is slow and memory matters. The coarse graph is the answer; its block
  size needs measuring in milestone 2.
- **New zones.** Forever has maps beyond the two classic continents. Whether their files are
  encrypted is unknown until milestone 1 (some files in the install are).
- **Patches.** A patch that changes the world means re-running the extractor and re-releasing data.
- **Publishing.** The map data is derived from Blizzard's game files. Fine for personal use;
  shipping it publicly is the user's call (other addons do ship client-derived data).
- **Testing.** Everything up to milestone 4 can be verified here. In-game behaviour (drawing, waypoints,
  combat restrictions) cannot.

## Order and size

Milestones 1 to 4 are the first usable version: roughly one working session each, 4 being the largest.
Milestone 5 is open-ended and can be done a piece at a time after people are using the planner.
