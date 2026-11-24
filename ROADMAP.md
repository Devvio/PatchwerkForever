# Roadmap: improvements and new features

Written 2026-11-13, asked for as a list of improvements and new features to build once the addons
went live. It follows `V1.md`. Live then: Tracker 1.0.0, Sparkle 1.0.0, Routes 0.14.0 (beta), the base
2.3.0, the Stitches 2.0.1. What has been built since is at the end.

Everything here is a proposal to pick from and reorder. Sizes are rough: **S** an evening,
**M** a few sessions, **L** open-ended. "Needs" says what has to be found out or supplied first.

## 1. Improvements to what is live

### Tracker (Thread) 1.0

| # | Improvement | Size | Needs |
|---|---|---|---|
| T1 | Show what the default tracker shows and ours hides (quest pop-ups, anything Forever adds) | M | a week of play to see what is missed |
| T2 | Dungeon objectives: make it real or remove the option | S to M | a dungeon run with the option on |
| T3 | Tooltip on a quest: description, rewards, who gives the turn-in | S | - |
| T4 | Filter: current zone only; collapse a single zone | S | - |
| T5 | Quest item bar: fades and moves with the tracker; horizontal layout | S | - |
| T6 | Party progress between two trackers, seen working | S | a second player running it |
| T7 | Its own icon in the family's style (done 2026-11-17, the user's own picture) | - | - |
| T8 | Redraw only what changed, not the whole list each second | M | only if it shows in play |

### Routes (Thread), to its 1.0

| # | Improvement | Size | Needs |
|---|---|---|---|
| R1 | Docks and zeppelin towers: route onto them, not to the ground beside | M | - |
| R2 | Lifts: the Great Lift, the Undercity; flights at Ironforge and the Undercity | M | marking each lift in the game, as Thunder Bluff's were |
| R3 | Check every boat and zeppelin line runs on Forever; remove the dead ones | S | riding or asking about each |
| R4 | The Eastern Kingdoms and an Alliance character played | - | play, or a tester |
| R5 | Travel time shown includes lift rides and swims | S | - |
| R6 | A written procedure to rebuild the map data after a game patch | S | - |
| R7 | Places inside buildings and on upper floors (Booty Bay, the capitals) | L | - |
| R8 | Locked doors no longer count as open | S | a list of them |
| R9 | Flight times measured as you fly, in place of estimates | S | - |
| R10 | Travel speed follows your mount | S | - |

### Sparkle (Thread) 1.0

| # | Improvement | Size | Needs |
|---|---|---|---|
| S1 | The ignore list in the options, with a remove button for each entry | S | - |
| S2 | A switch for each object type (herbs on, chests off) | S | - |

### All of them

| # | Improvement | Size | Needs |
|---|---|---|---|
| A1 | READMEs' prose in standard wording, as the in-game text now is | S | - |
| A2 | Listing pictures: addon list, tracker, options front page, a route | - | screenshots from the game |
| A3 | A run with nothing else installed (no EllesmereUI, Console Port, RestedXP) | S | a clean addon folder for an evening |
| A4 | Strings gathered in one table per addon, so other languages can be added | M | only if translations are wanted |
| A5 | The Stitches' settings read through for standard wording | S | - |

## 2. New features

| # | Feature | Where | Size | Needs |
|---|---|---|---|---|
| N1 (built 2026-11-13, see below) | **Routing from the Dungeon Journal**: its to-do list and map pointing read as it runs; Routes leads to each quest giver and the tracker lists them | a new Stitch | M | see `tools/PLAN-tracker.md`: the shape of two of its functions, a rule for when RestedXP and the journal both lead, a note to its author |
| N2 | **Hearthstone and teleports as route options**: the planner may say "hearth, then walk" when that is faster | Routes | M | cooldowns and bind location, which the game gives |
| N3 | **A quest run**: the best order through all tracked quests, shown as one trip | Routes, with a tracker section | M | - |
| N4 | **Mark a stretch as blocked**: a binding that closes the trail ahead so the route goes round | Routes | S | - |
| N5 | **Places you know**: remember the vendors, repairers, trainers, innkeepers, mailboxes and flight masters you use, and route to the nearest of a kind (a binding: "nearest repair") | Routes, with a tracker section | M | nothing from outside: learned as you play, like the gathering nodes |
| N6 | **An on-screen direction arrow** of our own, for when no other addon draws one | Routes | M | - |
| N7 | **Readers for other guide addons** | the base | S each | the guide addon installed, and its licence read |
| N8 | **Gathering: node types on the map filter, and a farm route you save** (a loop you name and run again) | Routes | M | - |
| N9 | **Gamepad rumble or a sound when a node or quest object comes into range** | Sparkle | S | whether Forever lets an addon rumble a gamepad |
| N10 | **Auto-track by zone**: quests of the zone you enter are tracked, others untracked (off by default; it changes your watch list) | Tracker | S | - |
| N11 | **Tracked achievements** in the tracker | Tracker | S | turned down once; listed in case |

## 3. A suggested order

1. **Go live**, then a week of play. T1 and T2 come out of that week.
2. **N1, the Dungeon Journal Stitch**: asked for twice, and the data it needs is already in the
   journal.
3. **Routes to 1.0**: R1, R2, R3, R5, R6, with R4 as play allows.
4. **Small polish in one pass**: T3, T4, T5, S1, S2, A1, A5.
5. **The larger new things, to pick from**: N5 (places you know) and N3 (quest run) build on what Routes
   already does; N2 changes what a route can be.

## Built since this was written

- **N1, 2026-11-13: Patchwerk Forever: Dungeon Journal (Stitch) 1.0.0**, with base 2.4.0, Routes 0.15.0
  and Tracker 1.1.0. Passes the checks against a stand-in journal; not yet tried in the game with the
  real one. What was settled: the journal's list is a second guide beside RestedXP and is followed
  only while selected (a setting makes it the main route); nothing was sent to its author yet.
- **2026-11-13: Routes 0.16.0, flight points you know.** Asked for: route on foot where the character
  does not have the flight path. Known points are read from the flight map at a flight master and
  remembered (`Flights.lua`); with nothing known, routes go on foot; a guide's "fly" step to a point
  you lack routes on to its next step by another way. Not yet tried in the game: what Forever's
  flight map reports for points you do not have is what it stands on.
- **2026-11-14: polish pass A** (`POLISH.md`, A1 to A12): base 2.5.0, Routes 0.17.0, Tracker 1.2.0,
  Dungeon Journal (Stitch) 1.0.1. The step text once per step, "No route found" and a slower retry,
  what Stop says, the trail on a flight, the tracker keeping its top corner, scrolling a long list
  without a mouse, the skip said in chat with an undo binding, rows that hold their order, and the
  Dungeon Journal list as a side list, and one quest list in instances (ours hides while the default
  tracker is kept there). Passes the checks; not yet tried in the game.
- **2026-11-16: Sparkle 1.1.0, loot wisps, and Races (Thread) 0.1.0 (beta), a new tool.** Asked for: a
  wisp that floats loot into the bag, and race courses of your own with markers on the ground. A wisp
  flies from the loot window or the sparkled object to the bag the item went into (`Wisp.lua`). Races:
  courses made by placing checkpoints as you ride, raced against the clock with splits and a best run,
  shared with the party. An addon cannot draw in the world, so the ring is drawn on the game's waypoint
  marker for the tracked pin (`C_Navigation.GetFrame()`, seen to exist on Forever by `/dump`), one
  checkpoint at a time. Both pass `tools/lua_races.py`; neither has been tried in the game. To look at
  first: where the ring sits against the game's marker (Vertical Offset), how near the game lets you get
  before its marker goes, and whether `ITEM_PUSH` fires for gathering on Forever.
- **2026-11-16: Plainsrunning (Thread) 0.1.0 (beta), a new tool.** Asked for: the interface fading
  slowly as Plainsrunning reaches 30 stacks, then speed streaks across the screen. The buff is spell
  1299038 (seen in the game, and in Forever's hotfix cache as an aura of increased speed, "Movement speed
  increased by $w1%"); the racial passive is 1259918 and shares the name, so it is never matched. The
  interface is faded through UIParent's alpha (allowed in a fight; nothing hidden or moved) and comes
  back for a fight, a window, typing, standing still, death or a flight. Streaks are Lines on WorldFrame.
  Passes `tools/lua_plainsrunning.py`; not yet tried in the game. To look at first: that every window
  of Forever brings the interface back (the list is `WINDOWS` in `Run.lua`), how fast 30 stacks is
  (the streaks take 1.6 times running speed as their pace), and where the streaks' centre sits.
- **2026-11-16: Plainsrunning (Thread) 0.2.0 (beta).** Asked for: more effects to choose from, then
  chosen in an interview: four more effects (Wind Gusts, Dust And Seeds, Warp Rings, Edge Glow), each its
  own tick box, additive, all off by default; Keep While Faded for the minimap, unit frames and chat, each
  optional and off; the camera easing back 3 yards at full speed, on by default; run records per
  character, told only when beaten. Not picked: a speed readout, a wind sound. The kept parts use
  SetIgnoreParentAlpha (in Forever's API docs), never on a protected frame in a fight; the camera uses
  CameraZoomOut/In and reads GetCameraZoom a second later to take back only what it moved. Passes
  `tools/lua_plainsrunning.py`; not yet tried in the game. To look at first: whether the game lets
  PlayerFrame and TargetFrame ignore the parent alpha (and whether MelloUI's or Console Port's own unit
  frames need adding to the lists in `Run.lua`), whether CameraZoomIn works in a fight without a blocked
  action, how the new effects look over bright grass (they add light), and the hoofbeat pace of Edge
  Glow.
- **2026-11-17: out of beta.** Routes 1.0.0 and Immersive Plainsrunning (Thread) 1.0.0, then 1.1.0
  (Tauren only, safe with the game's secret values); Races stays 0.1.0 (beta). Icons of the user's own for
  the Tracker, the Dungeon Journal Stitch and Immersive Plainsrunning; their CurseForge projects made.
- **2026-11-18: Console Port (Stitch) 2.1.0, Dungeon Journal (Stitch) 1.0.2, Immersive Plainsrunning
  1.2.0**, then **focus and My Route** (`TRACKING-BLUEPRINT.md`): base 2.6.0, Routes 1.1.0, Tracker
  1.3.0, Dungeon Journal (Stitch) 1.1.0. Choose what the route follows, and stack quests into a route of
  your own. Passes the checks; not yet tried in the game.
- **2026-11-18: polish pass B to J and an unslop pass, by addon** (`POLISH.md`). Details in each
  addon's CHANGELOG.
- **2026-11-19 to 2026-11-21: Globe (Thread)**, a new addon (`GLOBE-BLUEPRINT.md`): the world on a parchment
  globe. Prototype 0.0.1 with its own pictures, zones and hand-made art. Its road to parity with the
  world map (G5 to G14, 1.0 and its first release at parity) is in the blueprint. G5 to G9 (0.5.0: the
  ground, the window and controls, travel and your route, quests, places and people) were built on
  2026-11-21 and checked offline; none of G6 to G9 has been tried in the game yet. For them the base
  gained its Trails service (2.8.0), Routes (Thread) offers its drawing there (1.3.0), and Thread
  (Tracker) can sit beside another window (1.5.0). After a first look at 0.5.0 came the Deeprun Tram and
  the lifts (in the planner too) and the Maelstrom (0.5.1). G10 to G14 were then built in one run as
  0.10.0: unexplored land left blank, rares and treasures, the Show menu, other addons' pins, city and
  battleground maps, the map key by option with a button on each map to the other, and light and
  movement (candlelight, the Maelstrom turning, cloud shadows). Checked offline; none of it tried in
  the game yet. Left: the test, then 1.0.0, the base README's list, the CurseForge project and the
  release.
- **2026-11-21: Globe 0.11.0 and the family's names turned round.** Aged paper on the globe, the ink
  drawings with a wash and a little faded, variation drawings and their prompts, a prompt for a ring
  border in place of the stand. And every addon's display name now has its name first and its kind
  after it, in brackets: "Patchwerk Forever: Routes (Thread)", "Patchwerk Forever: Console Port
  (Stitch)" (they were "Thread (Routes)", "Stitch (Console Port)"); options pages the same. Folders,
  commands and saved data are as they were. The seven addons with nothing else waiting got a patch
  version for it. Not released: the CurseForge projects' own names are changed on the site, by hand.
- **2026-11-21: made ready for release, the Globe as 1.0.0.** The Globe is no longer held back: version
  1.0.0, named in the base's README and in Routes' and Tracker's, an icon and logo of the family's kind.
  Every project's zip is built and the uploads tried dry. Left to the user: the Globe's CurseForge
  project (`release/NEW-PROJECTS.md`), the projects' new names on the site, and the word to upload.
- **2026-11-22: two new features for each Thread tool**, asked for as proposals and then all built in
  one run after an interview (quiet features on, what changes something you already see off). Checked
  offline; none of it tried in the game yet.
  - **Routes 1.4.0**: the way back to your corpse while you are a ghost (on foot, before everything;
    the planner is not told a ghost walks on water), and `/thread discover`, a search for the flight
    points you lack.
  - **Sparkle 1.4.0**: corpses with loot and skinnable corpses as two new kinds, and Herbs And Ore I
    Cannot Gather (Show, Dim, Hide). Whether the interact key points at corpses on Forever is the
    first thing to see.
  - **Tracker 1.6.0**: a Collect section (an item against a number; added by dropping the item on it
    or from a recipe's Collect What Is Missing, no command), a share mark on quests a party member
    lacks, and the order Party's Quests First.
  - **Immersive Plainsrunning 1.3.0**: Mounts, Travel Forms and Flight Paths as three more sources
    for every race (each off; the name stays), and Wind Shows The Way with Routes. The list of forms
    and spells is taken from classic and is to be checked.
  - **Races 0.2.0 (beta)**: course rules (On Foot or Anything Goes, a best run for each) and racing
    together (an invitation, a shared start, gaps at each checkpoint, placings). Needs a second player.
  - **Globe 1.1.0**: zones colored by level as a wash with a key, guild members and friends as one
    mark a zone, and the new ring (`border.png`: a ring with the four compass points, no stand).
  - The base is unchanged (2.8.0). Its `Following.lua` comment does not yet list the two kinds Routes
    now tells it, `corpse` and `discover`; to be added with the base's next change.
- **2026-11-22: three things the user saw in the game**, put right the same day, in the versions above
  (none of them uploaded yet). Checked offline; not tried in the game.
  - **Routes: the trail went through buildings in cities.** The planner knew the terrain only, and this
    client's Orgrimmar and Stormwind are one model each whose streets lie well above flat, empty
    terrain (and `wmo.py` could not read them: their triangle flags are in a newer chunk). New
    `tools/walls.py` lays the building models on the ground as walls and floors (`tools/PLAN.md`,
    "Walls and floors"); the three map data addons carry the new ground, with no change to their format
    or to the Lua planner. Not known: small scenery, a second floor over the first, levels reached only
    by a lift.
  - **Globe: the outline under the pointer and the undiscovered land.** Zone edges are smoothed before
    the outline is drawn, at four points a pixel; the blank paper over undiscovered land is cut at two
    pixels a chunk, rounded, and follows the coast (`GLOBE-BLUEPRINT.md`). Pictures and data only.
  - **Tracker: shown in dungeons and raids.** Hide In Dungeons And Raids is off to begin with.
- **2026-11-22: the Globe's fog of war, and cheaper drawing** (Globe 1.1.0, not uploaded). Checked
  offline; not tried in the game.
  - Only the zones the character had entered were covered: the game gives no list at all for the
    others. No list now means nothing discovered, once the game has given a list for any zone.
  - The cover is fog, not blank paper, thinning to mist at its edges; the setting is **Fog Of War**.
  - About half the work for each drawing while the globe is turned or zoomed (`GLOBE-BLUEPRINT.md`,
    "Fog for blank paper, and cheaper drawing").
  - After the user's look in the game: the fog is thin (**Fog Opacity**, 30%), and zoomed in to the
    ground the minimap's pictures come in only over discovered land, the painted map staying over the
    rest (`GLOBE-BLUEPRINT.md`, "Thin fog, and the painted map as the fog of war close in").
- **2026-11-23: Sparkle 1.5.0, from the proposals of the same day** (the debug probe, the eight quick
  wins and the five larger features), with base 2.9.0 and small parts in Routes 1.4.0 and Tracker 1.6.0
  (none of them uploaded). Checked offline; none of it tried in the game yet.
  - **The probe**: `/sparkle debug` prints the pointed object's tooltip, line by line with colors, and
    whether the game ties it to a quest. One evening with it at an herb above your skill, a quest object,
    a corpse, your fishing bobber and a quest giver says what Sparkle could read next (node skill, quest
    progress, the bobber, quest givers: still proposals).
  - **Sparkles**: a Show tick box for each kind (ROADMAP S2); Sparkle Distance (the game's reach,
    `SoftTargetInteractRange`, only raised, put back as the other game settings are) and Brighter When
    Near (the distance from Routes' remembered spots); Fade While Gathering; Quest Corpses
    (`UnitIsRelatedToActiveQuest`); four themed effects drawn by `media.py` and a Themed Preset; Use
    This Look For All and Preview All Types; a fade-area height for when mounted.
  - **The waypoint**: a kind of its own, a light beam on the game's waypoint marker
    (`C_Navigation.GetFrame`, as Races uses it) with the quest's name and distance, brighter as you
    come nearer. A destination the game draws no marker for has none.
  - **Alerts**: an Alert Sound for each kind (the game's own sounds) and Rumble On Gamepad
    (`C_GamePad.SetVibration`, in Forever's API docs) (ROADMAP N9).
  - **Wisps**: By Item Quality, Celebrate Rare Loot, Coins Fly To Your Bag, Quest Items Fly To The
    Tracker (Tracker gained `PatchwerkForever_Thread_Tracker_QuestBlock`).
  - **Passed**: chests, herbs and ore you walked away from, listed with Add To Route (My Route) and
    Forget; herbs and ore handed to Routes through the base's new `Gather:Note`.
  - **The ignore list on its own page** with a Remove button for each (ROADMAP S1), on the base's new
    list row (`Look.xml`, `PatchwerkForeverListTemplate`; API 6).
  - **Then, the same day, the waypoint reworked** after the user's first look: the beam stayed stuck on
    screen where the game had no valid place for its marker (it now asks `HasValidScreenPosition` and
    `GetTargetState`, as the game's own marker does), and it was to follow the route. Routes 1.4.0's
    **Mark The Way Ahead** moves the game's pin along its trail, about 40 yards ahead of you; the base's
    new `Marker.lua` lends the pin and tracked quest and gives them back, and Routes, Tracker, Globe and
    Sparkle read your own pin and quest from it. To look at first: whether moving the pin every 10 yards
    is smooth in the game, and whether tracking the pin keeps the quest you track or clears it.
  - To look at first in the game: whether a gamepad rumbles (and with Console Port), how far the game
    lets Sparkle Distance reach, the list rows on the options pages, the waypoint beam's height on the
    game's marker, and whether `GetLootSlotInfo`'s icon matches `ITEM_PUSH`'s.
- **2026-11-24: Patchwerk Forever's own options window** (base 2.10.0, OPTIONS-BLUEPRINT.md, all five
  milestones; the user found it working in the game the same day, and it was committed and uploaded). First, the same evening before: base 2.9.1
  folded each tool's further pages under its first in the game's options list (never released; part
  of 2.10.0). Then the window, from the user's answers: only our window (the game's options keep one
  page with a button), the game's own controls on a parchment page and a leather column, a folding
  list of parts and pages, a search across every part, the Stitches included, the art drawn by the user
  (stand-ins from `tools/options_art.py` until then). Built from one book of parts, pages and rows
  (`Options.lua`) that is read from what each part already declares, so no tool changed how it lists
  its settings; `Window.lua` draws it. With it: Console Port (Stitch) 2.3.0 tells Console Port's cursor
  about the window; Sparkle 1.5.1, Routes 1.4.1 and Immersive Plainsrunning 1.3.1 know it as they knew
  the game's options window; Dungeon Journal (Stitch) 1.2.2 rewords one line. The test stand-in now
  lists the book as the game's pages used to be listed (`STUB.FromBook`), so each addon's option checks
  stand as they were. Still open: the user's own parchment and leather pictures in place of the stand-ins.
