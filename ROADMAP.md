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
