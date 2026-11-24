# Patchwerk Forever: Tracker (Thread)

**Patchwerk had a list. Patchwerk lost the list. Patchwerk made a list that cannot be lost.**

Patchwerk is given many jobs. Fetch the heads. Find the pools. Bring back the hooves. By the third job Patchwerk has forgotten the first, and by the fifth he is fairly sure he was a tailor.

So Patchwerk sewed the jobs to the side of the screen. Every quest you track, and under each one what it still wants of you, the near ones on top. Done things go quiet. Things ready to hand in say so. The clever book that tells Patchwerk where to go next is sewn on too, and so are the flowers.

The game's own list is asked, politely, to stand in the corner and be invisible. It is not thrown out. Patchwerk knows what it is to be thrown out.

Patchwerk wants more jobs! Patchwerk wants them written down!

*One list. Hand-stitched. Mostly in order.*

---

A quest tracker for **World of Warcraft: Forever**: your quests by zone with how far each is, the steps of the guide you run, buttons for quest items, tracked recipes, a collect list and a gathering list, in a list of our own that you can move, resize and color.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the settings pages, and nothing else. It works with no other addon installed; RestedXP Guides and Routes (Thread) each add a section when they are there, and Globe (Thread) can keep the list beside its window.

One piece is marked experimental and starts disabled: dungeon objectives, which depend on what Forever's dungeons report.

## What it lists

- **The quests you track**, under the zone each belongs to. The zone you are in comes first, and within a zone the nearest quest. Two quests about as near as each other keep their rows until one is clearly nearer (about 15 yards or 15 percent), so the distances shown can be a little out of order for a moment; the quest item buttons hold their order the same way. Other orders are a setting: one list nearest first, ready ones first, **Shortest Trip** (a short path through them, the nearest first and then each next nearest the one before, worked out again when a quest comes, goes or is done), **Party's Quests First** (the quests someone in your party is also on, under a heading of their own, then the rest; each group by zone), or as the game has them.
- **For each quest**: its level in the game's color for its difficulty, its kind (elite, dungeon, daily, group), how many yards away it is, and its objectives. A count goes from red to green as it fills. A timed quest shows the time left.
- **Quests ready to hand in** leave the list for a short group at its foot (at its top with the ready-first order), each saying where to take it. The game's own watch list is not changed.
- **Who in your party has a quest**, under it. For party members who run this tracker too, how far along they are.
- **A share mark** on a quest that someone in your party is not on and that the game lets you share: three small dots at the right of its name. Point at it to see who is not on the quest; click it to share the quest with your party. The game does not say who has done a quest before, so a member who has already turned it in is named too. Not in a raid.
- **Your guide's steps**, when a guide addon runs (RestedXP): the step you are on with its lines, the next few steps dimmed under it, one line each, and in the heading the guide's name, "step 34 of 120" and a thin bar.
- **Focus buttons** along its top: one small button for each route you can follow (Auto, RestedXP, the Dungeon Journal list, Quests, My Route), only for what is installed and running. The one in use is lit and named beside them; click another to follow it, or right-click the row for a menu. Routes (Thread) follows the focus. It is kept for each character.
- **My Route**: your own stops in your own order (see below), above your quests.
- **A second list beside your guide**, with Patchwerk Forever: Dungeon Journal (Stitch): the quests of the dungeons you track in the Dungeon Journal, in a section of their own. Click it to route along it; click again to go back to your guide.
- **Recipes you track** in a profession window, with what each needs and how much you have.
- **Collect**: items you are collecting, each against a number you set, such as "Linen Cloth 14/20" (see below).
- **Gathering**, with Routes (Thread) installed: the nearest herb and ore nodes you have gathered from before.
- **A dungeon's stages**, where the game runs a place in stages. Untried; off until you enable it.

## Clicks

Point at a row or a heading and a tooltip says what a click on it does.

| On | Click | Does |
|---|---|---|
| a quest | left | chooses it: a side path off the main track (your guide, or your nearest quest). Routes (Thread) goes there first, even while a guide runs, and the game's arrow is put on it. A second click goes back to the main track and puts the arrow back where it was |
| a quest | shift-left | opens it to read |
| a quest | right | a menu: follow, read, add to or remove from My Route, share with the party, stop tracking, abandon (the game asks first) |
| a quest's share mark | left | shares the quest with your party |
| a focus button | left | follows that route; right: the same choices as a menu |
| a My Route stop | left | goes there first; right: Go Here First, Move Up, Move Down, Move To Top, Quest Details, Remove; drag: moves it |
| the My Route heading | right | Edit My Route, Order For Me, Add All Tracked Quests, Add Map Pin, Clear |
| the guide's step | left | skips it; right: skip, or back one step |
| a later guide step | left | goes to that step |
| a recipe | left | opens it; right: Open Recipe, Collect What Is Missing, Untrack Recipe |
| a Collect row | left | with Routes (Thread), for a herb or an ore with a node near you: leads you to the nearest node of that kind, and on reaching it to the next; a second click stops. For anything else, nothing; right: Change Count, Remove |
| the Collect heading, or a Collect row | left, holding an item | puts the item back where it was and asks how many to collect |
| the Collect heading | right | Remove Completed, Clear (asks first) |
| a gathering row | left | leads you to the nearest node of that kind, and on reaching it to the next; a second click stops |
| a heading | left | folds its section |
| a Dungeon Journal stop | right | adds its quest to My Route (with the list's own entries) |

A bar beside a block shows what is being followed: your guide's step, the quest you chose, a stop of My Route, or the gathering run. With Routes (Thread) installed it marks what Routes really leads you to, so after Stop Routing, or while it leads to your map pin, nothing is marked.

A quest you chose and then stop tracking, here or in the quest log, is let go, and the route goes back to your main track.

Skipping a guide step is done by the guide addon itself, as a click in its own window does. A chat line says which step was skipped and how to undo it. `/tracker back`, or the Undo Skipped Guide Step key binding, takes the last one back; if the guide has moved on since, the line says from which step. Once another guide is loaded there is nothing to undo. On a list whose step number does not move when you skip (the Dungeon Journal's counts the quests turned in), the line says only that the step was skipped.

## My Route

A list of stops you build yourself, followed in your order: quests in your log, Dungeon Journal quests you have not picked up yet, and your map pin. A quest handed in or abandoned leaves it by itself. It is kept for each character.

A hand-in can wait: when the stop you are on is a quest to turn in and another quest's objective, or a quest to pick up, further down the list is clearly nearer, that goes first. The hand-in follows when that is done or once it is the nearer of the two. A hand-in you click yourself is not put off.

- **Adding**: Add To My Route in a quest's right-click menu, or on a stop of the Dungeon Journal list; Add All Tracked Quests and Add Map Pin on the My Route heading's right-click menu; or the Add Quest To My Route key binding, for the quest under the quest arrow.
- **At the top**, the stop it goes to next and its zone, and while My Route is followed, the way there as Routes (Thread) finds it ("Fly from Crossroads to Thunder Bluff (3 min in all)").
- **Each stop** shows its number, its name, what to do there (Accept, In progress, Turn in, Go to, No place known) and how far it is. Click it to go there first; right-click it for Go Here First, Move Up, Move Down, Move To Top, Quest Details and Remove.
- **Drag and drop**: drag a stop to another place. A ghost of the row follows the pointer and a gold line shows where it will land. Let go away from the list, or press Escape, to cancel.
- **Order For Me** puts the stops in a short order: nearest first, then each next stop nearest the one before.
- **The My Route window** (Edit My Route on the heading's menu, `/tracker route`, or the Open My Route key binding): numbered rows with a grip, the name, the zone and the distance, a cross to remove a stop, and Order For Me, Add Tracked Quests, Clear and Close. Drag rows to reorder them; click one to select it. Escape closes it, and it opens where you last left it. Another addon can open it beside the world map.
- **Following it**: click the My Route focus button, or click a stop. Route To Next Quest and Route To Previous Quest then walk its stops.
- **Without a mouse**: the menus' Move entries, and the Move My Route Stop Up and Move My Route Stop Down key bindings, which move the stop you last clicked or selected.

## Collect

A list of items to gather up, each against a number you set: cloth for First Aid, a reputation's hand-ins, materials for crafting. It is kept for each character.

- **Each row** shows the item's name and, at its right, how many you have of how many you want. The count goes from red to green as it fills, as a quest's counts do. A row whose number is met is shown as complete and stays until you remove it.
- **The bank counts** unless you disable Count Items In The Bank.
- **Adding by dropping**: pick an item up from your bags. While you hold it the Collect heading is shown, even with nothing listed. Click the heading (or a row) with the item, or drag the item there and let go: the item goes back where it was, and a small box asks how many. Enter or Okay adds the row; Escape or Cancel does not. An item already listed gets the new number. This works in combat.
- **Adding from a recipe**: right-click a tracked recipe and choose Collect What Is Missing. Each reagent the recipe's row shows too few of is added with the number the recipe needs. An item already listed keeps the higher number.
- **There is no command for adding.**
- **Gathering it**: with Routes (Thread) installed, a click on a herb or an ore starts a gathering run for it, as a click in the Gathering section does, and a second click stops it. Only for a kind with a node near you that you have gathered from before; the node is matched by name (Peacebloom, or Copper Ore at a Copper Vein).
- **Removing**: right-click a row for Change Count and Remove; right-click the heading for Remove Completed and Clear.
- Disable **Show Collect List** to hide the section; the heading then no longer appears when you pick an item up.

## Item buttons

A quest that gives you an item to use gets a button in a strip beside the tracker, the nearest quest's item first. The items your guide's step wants used (a hearthstone) follow them. The strip goes on the side you choose, or on the other side when the screen has no room there.

- **Use Nearest Quest Item** (a key binding) uses the first quest's item, with the strip shown or hidden. It only ever uses a quest's item, never the guide's. With no quest item to use, the game's red error text says so.
- **In a fight the strip does not change.** The game does not let an addon show, hide or move such buttons then. What changed meanwhile is applied when the fight is over, so the binding uses the item that was nearest when the fight began.

## Key bindings

Under **Options > Keybindings**, in the **Patchwerk Forever** section, or in Console Port's binding list:

| Binding | Does |
|---|---|
| Collapse / Expand Tracker | folds every section, or opens them all again |
| Scroll Tracker Up, Scroll Tracker Down | scroll a list longer than Max Height |
| Route To Next Quest, Route To Previous Quest | choose the next or previous quest in the order listed, as a click would; one step past either end returns to your main route. The quest chosen is scrolled into view. While My Route is the focus or the list you selected, they walk its stops |
| Use Nearest Quest Item | uses the nearest quest's item (see Item buttons) |
| Undo Skipped Guide Step | does what `/tracker back` does |
| Add Quest To My Route | adds the quest under the quest arrow |
| Move My Route Stop Up, Move My Route Stop Down | move the stop of My Route you last clicked or selected |
| Open My Route | opens or closes the My Route window |
| Share Quest With Party | shares the quest under the quest arrow with your party; with no arrow, the quest you chose in the tracker. A chat line says so, or says why not (no quest selected, not in a party, a quest that cannot be shared) |

A tracker dimmed by Fade When Not Hovered wakes for a few seconds when one of these is pressed.

## Stepping back

Three switches, all off to begin with: dim in a fight, dim unless the mouse is over it (it wakes for a few seconds when something changes), and hide in dungeons, raids and battlegrounds (**Hide In Instances**).

## What it does by itself, and what it leaves alone

- **Nothing is moved for you** unless you enable it. "Quest Arrow On Nearest Quest" puts the game's arrow on the nearest tracked quest when no guide runs and you have chosen neither a quest nor a list to route along; it starts disabled. An arrow the game puts on a quest you have just accepted is moved on by it too.
- **RestedXP's own window** stays as it is unless you enable "Hide RestedXP Window". Then it is made invisible while the tracker lists the guide. RestedXP's settings are not changed, and its arrow and item buttons stay.
- **Party progress** is told between trackers only: the quest's number and a percentage, to your party, when it changes. Disable "Share Progress With Party" and nothing is sent. The share mark and the Party's Quests First order send nothing: they read what the game says about your party.
- **A quest is shared** only when you click its share mark, choose Share Quest in its menu, or press the Share Quest With Party key.
- **A guide's words** are shown from the guide addon's own tables as the game runs. None are kept.

## The game's own tracker

While this one is shown, the game's tracker is made invisible and lets clicks through, so you do not see every quest twice. It is not removed or hidden, which is what makes other things go wrong. Disabling **Hide Default Tracker**, or `/tracker off`, brings it back as it was.

- **In dungeons, raids and battlegrounds** this tracker is shown as it is everywhere, and the game's stays hidden. The game's tracker shows things there that this one may not (a dungeon's stages, timers, scores): enable **Keep Default Tracker In Instances** to have it there instead, and this one steps aside so there is one list. With **Hide Default Tracker** disabled, both are shown there as everywhere.
- **If the quest list could not be shown** (an error), the game's tracker is let back until it can, and a chat line says so once.
- **EllesmereUI's quest tracker**, if you run it, is a third. You are told once; disable one of the two in the addon list.

## Using it

- **Fold it** by clicking a heading, with `/tracker fold`, or with the Collapse / Expand Tracker key binding.
- **Move it** with `/tracker move` (or Unlock Position in the options): drag it by the bar along its top, then right-click the bar (or `/tracker lock`). While it is unlocked it is shown at full brightness, even with nothing to list. Its top corner stays where you leave it: the list grows downward from there, and changing Scale does not move it.
- **Past a height you set**, the list scrolls with the mouse wheel or the Scroll Tracker Up and Scroll Tracker Down key bindings, and its top or bottom edge darkens while there is more of the list past it. While everything fits, the wheel is left to the camera.
- Clicks between the lines pass through to the world.

## Settings

**Tracker (Thread)** in Patchwerk Forever's options window, `/tracker config`:

| Page | Holds |
|---|---|
| Tracker (Thread) | on or off, the game's tracker, width, the tallest it grows, its place, visibility (fading, instances) |
| Tracker: Quests | the order (Party's Quests First among them), the ready group, levels, kinds, distance, progress colors, the flash, the party and the share mark, the quest arrow on the nearest quest |
| Tracker: Guide | the guide's steps, how many after, skipping by a click, the step's items, RestedXP's window; the focus buttons; My Route |
| Tracker: More | item buttons, recipes, the collect list and whether the bank counts, the gathering list, a dungeon's stages |
| Tracker: Appearance | scale, font size, the colors, the background |

## Commands

| Command | Does |
|---|---|
| `/tracker` | lists the commands (`/pftr` is the same) |
| `/tracker on` / `off` | shows it, or goes back to the game's own |
| `/tracker move` / `lock` / `reset` | drag it somewhere; fix it there; put it back under the minimap |
| `/tracker fold` | folds it up, or opens it again |
| `/tracker next` / `previous` | routes to the next or previous quest in the list |
| `/tracker back` | takes back the last guide step skipped by a click |
| `/tracker route` | opens or closes the My Route window |
| `/tracker config` | opens the options |

Something wrong? Report it as a comment on the addon's CurseForge page.

## Credits

The code and pictures are under the MIT License. English only. RestedXP Guides is read as it runs; none of its code or guide text is in this addon.
