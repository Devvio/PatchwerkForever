# Blueprint: route focus and your own quest routes

Asked for on 2026-11-18: buttons to focus the route on one source (RestedXP, the Dungeon Journal, questing), then routes of your own made by selecting quests and stacking them in order, reordered by drag and drop, on the map and the journal too.

Built on 2026-11-18 (all five milestones; base 2.6.0, Routes 1.1.0, Tracker 1.3.0, Stitch (Dungeon Journal) 1.1.0), passing the checks outside the game; not yet tried in the game. Your answers to the ten decisions are at the end; the text below follows them.

## Where things stood before it was built

- **What the route follows** is decided every half second in Routes' `Sources.lua` (`Look()` → `Target()`), highest first:
  1. a gathering run;
  2. your map pin or `/thread to` spot;
  3. a side list you picked (the Dungeon Journal list);
  4. a quest you clicked in the tracker;
  5. the main track: your guide and your tracked quests, in the order the **Priority** setting gives.
- **A pick is one slot, and it is forgotten.** The base's `Choice` holds one side path at a time (a quest or a list), sends no events (Routes and the tracker check it), and is lost on `/reload`.
- **Guides** are readers registered with the base (`rxp`, `fdj`). Each gives steps with a place, the steps after, and can be moved on. The Dungeon Journal list is a side list unless set to lead.
- **The tracker** has sections (guide, second lists, quests by zone, recipes, gathering). A click on a quest picks it, a right-click opens a menu (Route, Details, Share, Untrack, Abandon), a click on a side list picks the list. Its only drag is moving the window.
- **The world map** gets the trail and the steps ahead from Routes, drawn only: no buttons, no clicks. Nothing of ours touches the game's quest log.
- **Forever's world map** is the modern one: overlay buttons at its corners and the quest log as a side panel (`QuestLogOwnerMixin`). Whether that panel is switched on depends on a game rule (`QuestLogPanelDisabled`), to be checked in the game.
- Related ideas already on the roadmap: **N3** a quest run (the best order through your tracked quests), **N8** a saved farm route.

## The two features

### A. Focus: you choose what the route follows

A **focus** is a standing choice of where the route comes from. It stays until you change it, unlike a click on a quest, which is a one-off.

| Focus | The route follows |
|---|---|
| **Auto** | as today: your guide or your quests, by **Priority** |
| **RestedXP** | the RestedXP guide only (any guide reader that leads, later) |
| **Dungeon Journal** | the journal list only |
| **Quests** | your tracked quests only, nearest or the quest arrow, as set |
| **My Route** | your own route (feature B) |

Shown only for what is installed and running: no RestedXP, no RestedXP button.

**What still comes first.** A gathering run, a map pin and a quest you click still win over the focus, as they win over the main track today (**Q3**). When the focus has nowhere to send you (the journal list is done, no quests tracked), the route falls back to Auto and says so once (**Q2**).

**Where you switch it:**
- **Tracker:** a slim bar under its title with one small icon button per focus (RestedXP's, the journal's, a quest mark, a route mark, and Auto). The one in use is lit, with its name in the tooltip. Right-click on the bar gives the same list as a menu.
- **World map:** one focus button at the map's top right, beside the game's tracking buttons, opening the same list.
- **Keys and gamepad:** "Next Focus" (cycles through the ones available) and one binding for each focus, in the key bindings and Console Port's list.
- **Chat:** `/thread focus auto | rxp | dj | quests | route`; `/thread focus` alone says which is in use.
- **On screen:** a change of focus is said in the step text ("Following: Dungeon Journal").

**Saved** for each character (**Q1**), so a `/reload` keeps it.

### B. My Route: quests you stack in your own order

A list of stops you build yourself, followed in your order.

**What can go in it** (**Q6**):
- **Quests in your log.** The stop is where the game marks it: its next objective while you work on it, then whoever takes it in once it is done (the game moves that mark, as for a quest you click today).
- **Journal quests you have not picked up.** The stop is where the journal says it starts. Once taken, it becomes a quest in your log as above.
- **A map spot**, from your map pin ("Add Map Pin To My Route").

**What happens as you play:**
- A quest handed in leaves the route by itself.
- A quest abandoned leaves it too (**Q5**).
- When the route is empty, the focus says so and falls back as in A.

**Adding to it:**
- **Tracker:** "Add To My Route" in a quest's right-click menu, and on the journal list's stops. "Add All Tracked Quests" on the My Route heading's menu.
- **Quest log on the world map:** a small "+" beside each quest, or the same menu item if the game lets its menu be added to (to check in the game).
- **Dungeon Journal:** from our tracker's journal list (above). A button inside the journal's own window only if it offers a safe place to hook one; its files are never changed.
- **Gamepad:** the same menu items, and a binding "Add Quest To My Route" for the quest under the arrow.

**Ordering it:**
- **Drag and drop**, in the tracker's My Route section and in the editor (below). Each row has a grip; while you drag, a ghost row follows the pointer and a gold line shows where it will land. Dropped, the route redraws at once.
- **Without a mouse:** Move Up, Move Down, Move To Top and Remove in each row's menu, and bindings to move the selected row. Console Port's cursor cannot drag, so these are the gamepad's way.
- **"Order For Me"**: puts the stops in a short order, nearest first and each next nearest the one before (the journal list's ordering).
- **The same for your tracked quests** (**Q10**, roadmap N3's quest run): a new choice in the tracker's quest order, **Shortest Trip**, lists your tracked quests in that order, and Route To Next/Previous Quest walk them in it.

**The editor:** a small window in the tracker's look, opened from the My Route heading, the world map button or `/thread route`. It has numbered rows with grip, name, zone and distance, a remove cross, and Order For Me, Clear and Close at the foot. It opens beside the world map when called from there (**Q7**).

**On the world map:**
- Numbered marks (1, 2, 3, ...) on your route's stops, joined by the trail.
- Right-click a mark for Go Here First, Move Earlier, Move Later and Remove.
- Dragging the marks themselves is left for later.

**Saved** for each character (**Q4**).

## How it fits the code

- **Base (Patchwerk Forever)**, API 5:
  - `Focus`: Get, Set, Available, and an `OnChange` callback list; saved in `PatchwerkForeverDB`, one for each character.
  - `Choice` gains callbacks too, so the route and the tracker change the moment you click, not on the next half-second check.
  - **My Route as a guide reader** (`route`) in the base, with its list in `PatchwerkForeverDB`. Being a reader, it gets everything guides already have for free: the steps-ahead trail, the step text, a tracker section, Next and Previous. Its `Go` moves through the list; `Add`, `Move`, `Remove` and `Order` change it.
- **Routes:**
  - `Target()` gains the focus step: gathering, pin, Choice, **focus**, then Auto as today.
  - The **Priority** setting stays, for Auto.
  - It listens to Focus and Choice changes instead of only checking.
  - The world map layer draws numbered marks for My Route and takes their right-clicks.
- **Tracker:**
  - The focus bar.
  - The My Route section, with dragging, its rows and the editor window.
  - The menu items.
  - Route To Next/Previous Quest walk My Route while it is the focus (**Q8**).
- **Stitch (Dungeon Journal):** its stops can be added to My Route (a start spot for a quest not yet taken).
- **The world map and quest log** are touched only from outside:
  - our own buttons, parented to the map's frames, never added with the map's `AddOverlayFrame`. The map refreshes those through secure code, and an addon's frame there risks the game's "action blocked" errors.
  - the quest log reached through hooks after it draws.

## Things to watch

- **Gamepad:** drag and drop is mouse only. Every action has a menu item and a binding.
- **Combat:** nothing here is a secure frame, so it all works in a fight. The tracker's quest item buttons stay apart, as now.
- **Forever's quest log** may be the side panel or a window of its own, depending on the game rule above. The "+" goes wherever it is.
- **The journal's window** has no place made for other addons. If there is no safe hook, adding is done from our list only.
- **Stale entries:** a journal quest whose start the journal no longer knows, or a quest from the other faction, is shown greyed with a reason, never routed.

## In what order to build it

| Step | What | Shows you |
|---|---|---|
| **M1** | Focus: base service, Routes precedence, tracker bar, map button, bindings, `/thread focus` | switching between RestedXP, the journal and quests with one click |
| **M2** | My Route: list, reader, "Add To My Route" in the tracker menu, its tracker section, Move Up/Down | your own order, followed |
| **M3** | Drag and drop in the tracker section, the editor window with Order For Me, and Shortest Trip for tracked quests | reordering by hand, and a short order made for you |
| **M4** | World map: numbered marks and their right-click menu | the route on the map |
| **M5** | Quest log "+", and adding from the journal list | adding without opening the tracker |

Each step comes with its checks in `tools/lua_tracker.py` and `tools/lua_shell.py` against the stand-ins, and is tried in the game before the next one.

## Your decisions (2026-11-18)

| | Question | Answer |
|---|---|---|
| **Q1** | Focus kept across `/reload` and logins? | **Kept, for each character** |
| **Q2** | Focus with nowhere to send you | **Fall back to Auto**, said once |
| **Q3** | Map pin and a clicked quest before the focus? | **Yes, as today** |
| **Q4** | My Route for each character or shared? | **Each character** |
| **Q5** | A quest abandoned | **Dropped from My Route** |
| **Q6** | What goes in My Route | **Quests in your log, journal quests not taken, map spots** |
| **Q7** | Where the editor lives | **A window of its own**, beside the map when opened from there |
| **Q8** | Next/Previous with My Route as the focus | **Walk My Route** |
| **Q9** | The name | **My Route** |
| **Q10** | Order For Me for tracked quests too | **Yes, with My Route** (Shortest Trip, in M3) |
