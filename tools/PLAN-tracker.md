# Thread (Tracker): plan

A quest tracker of our own for World of Warcraft: Forever, as a Thread tool. It shows the quests
you track with their objectives, and the steps of the guide you are running. Guide addons are read
through modules: RestedXP first, others later.

Asked for by Tyrone on 2026-11-12 ("plan to build our own custom quest tracker, later we can add
additional addon modules for other guide addons"). Nothing of it is built yet.

## Decided

Tyrone's choices, from the interview of 2026-11-12:

| Question | Choice |
|---|---|
| What the first version holds, beyond quests and the guide section | all four offered: quest item buttons, click actions and a menu, sorting / grouping / filters, tracked recipes |
| Where the guide readers live | in the base, shared: one "guides" service that Routes and the tracker both ask |
| How it sits with the game's and EllesmereUI's tracker | it replaces the game's while it is on (made invisible and click-through, never removed), with a switch; if EllesmereUI's tracker runs too, it says so once |
| Look | quiet, with Patchwerk accents: flat, the game's fonts, gold section headers with a thin stitched underline, guide steps in the teal of the icons; size, width, colours and place adjustable |

Mine, open to change:

- **Name:** Patchwerk Forever: Thread (Tracker). Folder `PatchwerkForever_Thread_Tracker`, saved data
  `PatchwerkForever_Thread_TrackerDB`, command `/tracker` (and `/pftr`).
- **Version:** 0.1.0, a beta, when the first milestone that is usable is done.
- **It needs only the base.** With Thread (Routes) installed too, clicking a quest routes to it, but
  through the game (the quest becomes the one the game's arrow is on, which Routes already follows),
  not through a link between the two addons.

## Rules that apply

- No other addon's files are edited, and none of another addon's code or art is copied. EllesmereUI
  has no licence file (all rights reserved by default); RestedXP is CC BY-NC-SA; MelloUI's code is MIT
  and its route data is all rights reserved. We look at how the *game* is asked, and write our own.
- A guide addon is read as it runs. Its guide text is shown from its own tables at that moment and is
  never stored in ours.
- Anything that changes the game's own state for the player (the watch list, for automatic tracking by
  zone) is off until asked for.
- Every setting is under Patchwerk Forever's own page.
- A Thread tool depends on no third-party addon: with no guide addon installed the guide section is
  simply absent.

## What the game offers (checked 2026-11-12)

Seen in use by a Forever-only tracker already running on this client, so they exist here:

- The watch list: `C_QuestLog.GetNumQuestWatches`, `GetQuestIDForQuestWatchIndex`, `AddQuestWatch`,
  `RemoveQuestWatch`, `GetQuestWatchType`.
- A quest: `C_QuestLog.GetInfo` (by log index: title, level, header, frequency),
  `GetLogIndexForQuestID`, `GetTitleForQuestID`, `GetQuestObjectives` (text, done, numbers),
  `IsComplete`, `IsFailed`, `IsQuestTrivial`, `GetQuestDifficultyLevel`, `GetQuestTimers`,
  `GetTimeAllowed`, `GetNextWaypointText`, `GetQuestLogCompletionText`, `GetQuestLink`.
- Acting on one: `C_SuperTrack.SetSuperTrackedQuestID`, `C_QuestLog.SetSelectedQuest`,
  `SetAbandonQuest` / `AbandonQuest`, `IsPushableQuest`.
- A quest's usable item: `GetQuestLogSpecialItemInfo`, `GetQuestLogSpecialItemCooldown`. Using it
  takes a secure button.
- Recipes: `C_TradeSkillUI.GetRecipesTracked`.
- Events: `QUEST_LOG_UPDATE`, `QUEST_WATCH_LIST_CHANGED`, `QUEST_WATCH_UPDATE`, `QUEST_ACCEPTED`,
  `QUEST_REMOVED`, `SUPER_TRACKING_CHANGED`, `TRACKED_RECIPE_UPDATE`, `ZONE_CHANGED_NEW_AREA`,
  `PLAYER_REGEN_DISABLED` / `ENABLED`, `BAG_UPDATE_COOLDOWN`.
- The game's own tracker is `ObjectiveTrackerFrame`.

Not yet checked, to be looked up in the Forever interface source (see the forever-ui-source note) as
each milestone needs it: the fields `GetQuestObjectives` returns here, the context-menu function
(`MenuUtil` or the older drop-down), how tracked recipes give their reagents, and what else the
game's tracker shows that ours would hide (see Risks).

## Shape

### The guides service, in the base

Both Thread (Routes) and the tracker need to know what the guide says. Today Routes has its own
reader (`Guide.lua`). It moves to the base and becomes a service with one reader per guide addon.

```
PatchwerkForever.Guides:Register(id, reader)     a reader: { name = 'RestedXP', Read = function(count) ... end }
PatchwerkForever.Guides:Read(count)              what the first reader with a guide running says, or nil
```

What a reader gives (what Routes' reader gives today, and more for the tracker):

| Field | Meaning |
|---|---|
| `source`, `guide` | which reader, and the guide's own name |
| `index`, `total` | the step you are on, and how many there are |
| `kind` | what the step asks for: fly, hearth, turnin, accept, complete, place, text ... |
| `lines` | the step's lines, each `{ text, done, kind }` (today: the texts only) |
| `map`, `x`, `y` | where it sends you now |
| `key` | changes when the step or its place does |
| `ahead` | the steps after it, each with the same fields |

- Files: `PatchwerkForever/Guides.lua` (the service) and `PatchwerkForever/Guides/RestedXP.lua` (the
  reader, moved from Routes and extended). A reader does nothing unless its guide addon is running.
- The base's API number goes from 1 to 2 and its version to 2.1.0. Routes asks the service instead of
  its own file and needs API 2.
- **Adding a guide addon later** is one file in `Guides/` and one line in the base's TOC. For each
  candidate the first job is the same as it was for RestedXP: find where it keeps its steps while
  it runs, and read its licence.

### The tracker

One movable frame with a scrolling list, built from sections, each a list of blocks, each a list
of lines. Lines are pooled, so a redraw makes nothing new.

| File | Does |
|---|---|
| `Link.lua`, `Core.lua` | joins the base as a tool; settings; `/tracker` |
| `Frame.lua` | the frame, its place (dragged while unlocked, or by settings), scrolling, collapsing, the layout of sections, blocks and lines |
| `Quests.lua` | the list of tracked quests from the game: objectives, progress, done, failed, timers; grouping and sorting |
| `Guide.lua` | the guide section, from the base's guides service |
| `Actions.lua` | what a click does, and the right-click menu |
| `Items.lua` | the quest item buttons (secure) |
| `Recipes.lua` | tracked recipes |
| `Quiet.lua` | makes the game's own tracker invisible while ours is on, and puts it back |
| `Look.lua` | fonts, colours, the stitched underline |

### Quest item buttons, and combat

A button that uses an item must be "secure", and a secure button cannot be made, shown, hidden or
moved while you are in combat. Rows in a list move whenever a quest above them changes. So:

- The buttons are made ahead of time, out of combat, and are not attached to the rows. They stand
  in a short strip beside the tracker, in the order of their quests.
- What changes in combat (a quest done, an item gone) is applied to the strip when combat ends.
- A later milestone can look at putting each button on its quest's row, if a safe way is found.

## Milestones (as first planned; the order to version 1 is under "Version 1" at the end)

Each ends the same way: the checks pass here, it is built into the game, Tyrone tries it, and it is
committed when he says so. What "passes here" cannot show is listed with each.

| # | What | Done when | Only the game can show |
|---|---|---|---|
| 0 | **Guides service in the base.** Reader moved out of Routes, extended; Routes uses the service. *Built 2026-11-12: base 2.1.0 (API 2), Routes 0.13.0; passes here; see the note under the table.* | `lua_shell.py` passes unchanged in what it checks; `lua_patchwerk.py` has the service | nothing new: Routes behaves as in 0.12.0 |
| 1 | *(Built 2026-11-13, passes here; see the note under the table.)* **The tracker's frame and the quests.** Tracked quests with objectives and progress, done and failed states, level colours, live updates, collapsing, moving it, settings pages; the game's tracker made quiet; the note about EllesmereUI's. | a new `lua_tracker.py` plays a session against a stand-in quest log | that the game's tracker goes quiet and comes back cleanly; how it looks |
| 2 | **The guide section.** The step you are on with its lines ticked as done, the next steps dimmed, the guide's name and step number. | stand-in guide in `lua_tracker.py` | RestedXP's real wording and colours in the list |
| 3 | **Clicks and the menu.** Click: make it the game's arrow (and so route to it). Right-click: open in the quest log, share, stop tracking, abandon. | stand-in | the menu function Forever has; that abandon asks first, as the game does |
| 4 | **Sorting, grouping, filters.** By zone, by level, by distance; only this zone's; automatic tracking by zone (off until asked for, and it never untracks what you tracked by hand). | stand-in | zone names as the quest log gives them here |
| 5 | **Quest item buttons.** The strip beside the tracker; cooldowns; nothing touched in combat. | the stand-in fails any step that touches a secure button "in combat" | that using an item works, and nothing is blocked in a real fight |
| 6 | **Tracked recipes.** | stand-in | what Forever gives for a recipe's reagents |
| 7 | **Release.** Icon (a prompt in the family's pattern, in `art/PROMPTS.md`), README with Patchwerk's words, changelog, `release.py` and `curseforge.json` entries, version 0.1.0. | `release.py tracker` | - |

Milestones 0 to 2 give something worth using: your quests and your guide's steps in one list.

**Milestone 1, as built (2026-11-13).** `PatchwerkForever_Thread_Tracker` 0.1.0: `Link.lua`, `Core.lua` (15 settings on two pages, `/tracker`, a binding to fold it), `Frame.lua` (sections of blocks of lines, all kept and used again; `ns.AddSection` for the guide section to come; scrolling by moving the content inside a clipping frame; a drag bar while unlocked), `Quests.lua` (the watch list read, and the Quests section), `Quiet.lua` (the game's tracker: alpha 0 and the mouse off on its unprotected pieces, redone half a second after the game changes its list, nothing in a fight, undone when asked). The stitches under a heading are small plain textures, so no art was needed. `lua_tracker.py` with `trackerstub.lua` plays it. Different from the plan: blocks do not take the mouse yet (milestone 3 will make them buttons); grouping by zone is left to milestone 4. Confirmed in the game by Tyrone on 2026-11-13: the tracker lists his quests ("Yes, it lists them"). Not heard one by one, and still unknown: whether quietening the game's tracker this way holds (does the game put its alpha back? do its pieces answer `IsMouseEnabled`?), where the default place lands beside EllesmereUI's layout, how the writing wraps, and whether a quest item button left unseen on the game's tracker gets in the way.

**Milestone 0, as built (2026-11-12).** `PatchwerkForever/Guides.lua` is the service (`Register`, `Read`, `Words`, `WorldOf`, `Here`, `AWAY`) and `PatchwerkForever/Guides/RestedXP.lua` the reader, which now also gives each line's `done` and `kind`, the guide's name, and how many steps there are. Routes' own `Guide.lua` is gone; `Sources.lua` and `Ahead.lua` ask `ns.Base.Guides`. `lua_patchwerk.py` checks the service (readers in turn, a failing one skipped and said once, RestedXP's stand-in read with its done lines, a hidden arrow, a step with nowhere to go, the fallback to the arrow alone); `lua_shell.py` passes unchanged on it. Built into the game with the game closed and confirmed there by Tyrone on 2026-11-13: Routes follows his guide as before.

## Risks, and what is not known

- **What the game's tracker shows that ours does not.** In a dungeon, a scenario or a timed event the
  game's tracker shows things that are not quests. Made quiet, those would be hidden too. Plan: the
  game's tracker is let back whenever you are in an instance, and a setting does the same anywhere.
  What else it shows on Forever has to be seen in play.
- **Secure buttons** (milestone 5) are where an addon most easily causes "action blocked" errors.
  It gets the strictest stand-in and the most play before release.
- **EllesmereUI's tracker and ours both on.** Two trackers, and both quieten the game's. Ours only
  says so; which to untick is the player's choice.
- **RestedXP's internals.** The reader depends on names in RestedXP's code. It falls back to the
  arrow's spot for routing; for the tracker the fallback is no guide section.
- **Taint.** Our frame is our own and touches the game's tracker only to change how visible it is.
  That is the gentlest way known, but it is to be watched for.
- **Time.** This is the largest single thing in the repository after the route planner. The
  milestones are ordered so it can stop being worked on after any of them and still be whole.

## Later, not in this plan

- More guide readers. None of the other guide addons is installed here, so each needs installing
  and reading first.
- Achievements, bonus objectives and whatever else Forever's tracker lists.
- Item buttons on the quest's own row.
- Party progress, quest sounds.

## Version 1

What the tracker must be to be called 1.0, from an interview with Tyrone on 2026-11-13 (four rounds).
Milestones 0 and 1 are done and are not repeated here.

### What he chose

| About | His choice |
|---|---|
| The guide section | the steps after the current one, dimmed; the guide's name and "step 34 of 120" with a thin bar; clicking a step skips it in RestedXP. A line of a step goes as soon as it is done (he did not pick "stays, ticked"). |
| A left-click on a quest | routes to it: it becomes the one the game's arrow is on, which Thread (Routes) follows. Shift-click opens it in the quest log. The rest is in a right-click menu. |
| The order of quests | by zone under headings, the zone you are in first, its quests nearest first. The other orders stay as a setting. |
| Quest items | a strip of buttons beside the tracker, in the order of their quests. |
| Bound to a button | use the item of the nearest quest. (Folding is bound already. He did not pick next/previous quest or skipping a step.) |
| By itself | follow the nearest quest; and finished quests leave the list for a short "ready to hand in" group. (He did not pick tracking by zone.) |
| On each quest | its distance; its kind (elite, group, dungeon, daily, timed, with the time left); an objective's count coloured from red to green as it fills; the party's progress. |
| When something changes | a flash on the line. No sound, no words on screen. |
| Stepping back | three switches, all off to begin with: fade in a fight, fade unless the mouse is over it, hide in dungeons and raids. |
| Also listed | the items the guide's step wants used, in the item strip; a dungeon's stages and timers; and one he added himself, gathering (below). Not achievements. |
| RestedXP's own window | hidden while the tracker shows the guide, the gentle way, with a switch. RestedXP's settings are not changed. |
| Before it is called 1.0 | every feature seen working by him; a week of play as his only tracker, a dungeon included, with no errors; and it works with nothing else installed (no EllesmereUI, Console Port, RestedXP or Thread (Routes)). |

**Gathering**, in his words "gathering professions - find and route to nearest", then asked about:

- It finds the nearest remembered spot of anything you can gather; the nearest of a kind you pick; and
  a round through several spots of the zone you are in.
- On reaching a spot the route moves on to the next by itself, leaving out spots visited in the last
  few minutes, until it is stopped.
- It is a section in the tracker listing the nearest few spots, each clickable. (He did not ask for a
  binding or a command for it.)
- The only spots known are the ones Thread (Routes) has remembered from his own gathering. The game's
  files do not say where herbs and ore spawn, and he was told so.

### How I read three of the answers

- **"Stop tracking finished quests"** as I worded it: a quest that is ready is taken out of the list
  into a short "ready to hand in" group. It is a matter of where it is shown. The game's own watch
  list is not changed.
- **"Follow the nearest quest"** puts the game's arrow on the nearest tracked quest when no guide is
  running and nothing was chosen. Thread (Routes) already follows the nearest tracked quest in that
  case without moving the game's arrow. The tracker will mark the quest that is being followed either
  way, and moving the game's arrow as well is the switch.
- **Stepping back:** he ticked all four, "always fully shown" among them, and then said all three are
  switches that start off.

### What may not be possible as asked

- **The party's progress.** The game tells an addon whether a party member is on a quest, not how far
  they have got. So: who in the party has the quest, for everyone; and how far along they are only
  for party members who also run this tracker, sent between the two addons. The second part may fall
  out of version 1.
- **A dungeon's stages and timers.** What the game's tracker shows in an instance has to be found by
  being in one and reading the Forever interface source. Until it is done the game's tracker is let
  back in instances, as now.
- **Skipping a guide step** means calling RestedXP's own function for it, as its window does on a
  click. That function has to be found and may change with RestedXP. It is the one place the tracker
  acts on another addon, and it does so only on a click.
- **Gathering needs Thread (Routes)**, which remembers the spots and finds the ways. Without it there
  is no gathering section. The finding and the round belong in Routes (a new kind of destination,
  beside the pin, the guide and the quest); Routes offers them through the base, as the guides service
  is offered, and the tracker only lists and starts them.
- **Which spots a character can gather** needs the game to say which gathering professions the
  character has. To be checked on Forever.

### The order to version 1

Each ends as before: the checks pass here, it is built into the game, Tyrone tries it, it is committed
when he says so.

| # | What | Needs finding out first |
|---|---|---|
| 2 | **The guide section.** The step you are on; the steps after, dimmed; the guide's name, the step's number and a thin bar. RestedXP's own window hidden, with a switch. | how RestedXP's window can be made unseen without its settings |
| 3 | **Clicks.** Left: route to it. Shift-left: open in the quest log. Right: a menu (open, share, stop tracking, abandon). Click a guide step: skip it. | Forever's menu function; RestedXP's skip |
| 4 | **Order and detail.** By zone, yours first, nearest first; the other orders; the "ready to hand in" group; distance; the kind of quest and a timed quest's time; progress colours. The quest being followed is marked. | where a quest's place comes from without Routes; the fields for a quest's kind |
| 5 | **The item strip.** Quest items beside the tracker; the guide step's items in it too; a binding for the nearest quest's item; nothing touched in a fight. | how a binding clicks a secure button here; RestedXP's list of a step's items |
| 6 | **Tracked recipes.** | what Forever gives for a recipe's reagents |
| 7 | **By itself, and stepping back.** Follow the nearest quest; a flash on a line that changes; the three fades. Who in the party has a quest. | whether the game says who is on a quest |
| 8 | **Gathering.** In Routes: nearest spot, nearest of a kind, a round, moving on by itself, offered through the base. In the tracker: the section. | which gathering professions a character has |
| 9 | **A dungeon's stages and timers.** | all of it, in play |
| 10 | **Version 1.** Its own icon in the family's style; party progress between two trackers if it is to be in; then the three things he asked of 1.0. | - |

After 4 it is a better tracker than the one it replaces for everyday questing; 5 is the riskiest;
8 and 9 are the largest and could each be left to a 1.1 if the week of play is wanted sooner. That is
his to decide when they come up.
