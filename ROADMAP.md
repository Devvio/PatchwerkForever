# Roadmap: improvements and new features

Written 2026-11-13, at Tyrone's request ("lets go live then build an improvement and new feature
list"). It follows `V1.md`. Going live: Tracker 1.0.0, Sparkle 1.0.0, Routes 0.14.0 (beta), the base
2.3.0, the Stitches 2.0.1.

Everything here is a proposal for him to pick from and reorder. Sizes are rough: **S** an evening,
**M** a few sessions, **L** open-ended. "Needs" says what has to be found out or supplied first.

## 1. Improvements to what is live

### Thread (Tracker) 1.0

| # | Improvement | Size | Needs |
|---|---|---|---|
| T1 | Show what the default tracker shows and ours hides (quest pop-ups, anything Forever adds) | M | a week of play to see what is missed |
| T2 | Dungeon objectives: make it real or remove the option | S to M | a dungeon run with the option on |
| T3 | Tooltip on a quest: description, rewards, who gives the turn-in | S | - |
| T4 | Filter: current zone only; collapse a single zone | S | - |
| T5 | Quest item bar: fades and moves with the tracker; horizontal layout | S | - |
| T6 | Party progress between two trackers, seen working | S | a second player running it |
| T7 | Its own icon in the family's style | - | his art (prompt in `art/PROMPTS.md`) |
| T8 | Redraw only what changed, not the whole list each second | M | only if it shows in play |

### Thread (Routes), to its 1.0

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

### Thread (Sparkle) 1.0

| # | Improvement | Size | Needs |
|---|---|---|---|
| S1 | The ignore list in the options, with a remove button for each entry | S | - |
| S2 | A switch for each object type (herbs on, chests off) | S | - |

### All of them

| # | Improvement | Size | Needs |
|---|---|---|---|
| A1 | READMEs' prose in standard wording, as the in-game text now is | S | - |
| A2 | Listing pictures: addon list, tracker, options front page, a route | - | his screenshots |
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
| N11 | **Tracked achievements** in the tracker | Tracker | S | he said no once; listed in case |

## 3. A suggested order

1. **Go live**, then a week of play. T1 and T2 come out of that week.
2. **N1, the Dungeon Journal Stitch**: he has asked for it twice, and the data it needs is already
   in the journal.
3. **Routes to 1.0**: R1, R2, R3, R5, R6, with R4 as play allows.
4. **Small polish in one pass**: T3, T4, T5, S1, S2, A1, A5.
5. **The larger new things, his pick**: N5 (places you know) and N3 (quest run) build on what Routes
   already does; N2 changes what a route can be.

## Built since this was written

- **N1, 2026-11-13: Patchwerk Forever: Stitch (Dungeon Journal) 1.0.0**, with base 2.4.0, Routes 0.15.0
  and Tracker 1.1.0. Passes the checks against a stand-in journal; not yet tried in the game with the
  real one. What was settled: the journal's list is a second guide beside RestedXP and is followed
  only while selected (a setting makes it the main route); nothing was sent to its author yet.
- **2026-11-13: Routes 0.16.0, flight points you know.** Asked for as "detecting if i have a flight path or
  not, if not, route by foot". Known points are read from the flight map at a flight master and
  remembered (`Flights.lua`); with nothing known, routes go on foot; a guide's "fly" step to a point
  you lack routes on to its next step by another way. Not yet tried in the game: what Forever's
  flight map reports for points you do not have is what it stands on.
- **2026-11-14: polish pass A** (`POLISH.md`, A1 to A12): base 2.5.0, Routes 0.17.0, Tracker 1.2.0,
  Stitch (Dungeon Journal) 1.0.1. The step text once per step, "No route found" and a slower retry,
  what Stop says, the trail on a flight, the tracker keeping its top corner, scrolling a long list
  without a mouse, the skip said in chat with an undo binding, rows that hold their order, and the
  Dungeon Journal list as a side list, and one quest list in instances (ours hides while the default
  tracker is kept there). Passes the checks; not yet tried in the game.
