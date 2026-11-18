# Patchwerk Forever: Thread (Tracker)

**Patchwerk had a list. Patchwerk lost the list. Patchwerk made a list that cannot be lost.**

Patchwerk is given many jobs. Fetch the heads. Find the pools. Bring back the hooves. By the third job Patchwerk has forgotten the first, and by the fifth he is fairly sure he was a tailor.

So Patchwerk sewed the jobs to the side of the screen. Every quest you track, and under each one what it still wants of you, the near ones on top. Done things go quiet. Things ready to hand in say so. The clever book that tells Patchwerk where to go next is sewn on too, and so are the flowers.

The game's own list is asked, politely, to stand in the corner and be invisible. It is not thrown out. Patchwerk knows what it is to be thrown out.

Patchwerk wants more jobs! Patchwerk wants them written down!

*One list. Hand-stitched. Mostly in order.*

---

A quest tracker for **World of Warcraft: Forever**: your quests by zone with how far each is, the steps of the guide you run, buttons for quest items, tracked recipes and a gathering list, in a list of our own that you can move, resize and color.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the settings pages, and nothing else. It works with no other addon installed; RestedXP Guides and Thread (Routes) each add a section when they are there.

One piece is marked experimental and starts disabled: dungeon objectives, which depend on what Forever's dungeons report.

## What it lists

- **The quests you track**, under the zone each belongs to. The zone you are in comes first, and within a zone the nearest quest. Two quests about as near as each other keep their rows until one is clearly nearer (about 15 yards or 15 percent), so the distances shown can be a little out of order for a moment; the quest item buttons hold their order the same way. Other orders are a setting: one list nearest first, ready ones first, **Shortest Trip** (a short path through them, the nearest first and then each next nearest the one before, worked out again when a quest comes, goes or is done), or as the game has them.
- **For each quest**: its level in the game's color for its difficulty, its kind (elite, dungeon, daily, group), how many yards away it is, and its objectives. A count goes from red to green as it fills. A timed quest shows the time left.
- **Quests ready to hand in** leave the list for a short group at its foot (at its top with the ready-first order), each saying where to take it. The game's own watch list is not changed.
- **Who in your party has a quest**, under it. For party members who run this tracker too, how far along they are.
- **Your guide's steps**, when a guide addon runs (RestedXP): the step you are on with its lines, the next few steps dimmed under it, one line each, and in the heading the guide's name, "step 34 of 120" and a thin bar.
- **Focus buttons** along its top: one small button for each route you can follow (Auto, RestedXP, the Dungeon Journal list, Quests, My Route), only for what is installed and running. The one in use is lit and named beside them; click another to follow it, or right-click the row for a menu. Thread (Routes) follows the focus. It is kept for each character.
- **My Route**: your own stops in your own order (see below), above your quests.
- **A second list beside your guide**, with Patchwerk Forever: Stitch (Dungeon Journal): the quests of the dungeons you track in the Dungeon Journal, in a section of their own. Click it to route along it; click again to go back to your guide.
- **Recipes you track** in a profession window, with what each needs and how much you have.
- **Gathering**, with Thread (Routes) installed: the nearest herb and ore nodes you have gathered from before.
- **A dungeon's stages**, where the game runs a place in stages. Untried; off until you enable it.

## Clicks

Point at a row or a heading and a tooltip says what a click on it does.

| On | Click | Does |
|---|---|---|
| a quest | left | chooses it: a side path off the main track (your guide, or your nearest quest). Thread (Routes) goes there first, even while a guide runs, and the game's arrow is put on it. A second click goes back to the main track and puts the arrow back where it was |
| a quest | shift-left | opens it to read |
| a quest | right | a menu: follow, read, add to or remove from My Route, share with the party, stop tracking, abandon (the game asks first) |
| a focus button | left | follows that route; right: the same choices as a menu |
| a My Route stop | left | goes there first; right: Go Here First, Move Up, Move Down, Move To Top, Quest Details, Remove; drag: moves it |
| the My Route heading | right | Edit My Route, Order For Me, Add All Tracked Quests, Add Map Pin, Clear |
| the guide's step | left | skips it; right: skip, or back one step |
| a later guide step | left | goes to that step |
| a recipe | left | opens it; right: stop tracking |
| a gathering row | left | leads you to the nearest node of that kind, and on reaching it to the next; a second click stops |
| a heading | left | folds its section |
| a Dungeon Journal stop | right | adds its quest to My Route (with the list's own entries) |

A bar beside a block shows what is being followed: your guide's step, the quest you chose, a stop of My Route, or the gathering run. With Thread (Routes) installed it marks what Routes really leads you to, so after Stop Routing, or while it leads to your map pin, nothing is marked.

A quest you chose and then stop tracking, here or in the quest log, is let go, and the route goes back to your main track.

Skipping a guide step is done by the guide addon itself, as a click in its own window does. A chat line says which step was skipped and how to undo it. `/tracker back`, or the Undo Skipped Guide Step key binding, takes the last one back; if the guide has moved on since, the line says from which step. Once another guide is loaded there is nothing to undo. On a list whose step number does not move when you skip (the Dungeon Journal's counts the quests turned in), the line says only that the step was skipped.

## My Route

A list of stops you build yourself, followed in your order: quests in your log, Dungeon Journal quests you have not picked up yet, and your map pin. A quest handed in or abandoned leaves it by itself. It is kept for each character.

- **Adding**: Add To My Route in a quest's right-click menu, or on a stop of the Dungeon Journal list; Add All Tracked Quests and Add Map Pin on the My Route heading's right-click menu; or the Add Quest To My Route key binding, for the quest under the quest arrow.
- **At the top**, the stop it goes to next and its zone, and while My Route is followed, the way there as Thread (Routes) finds it ("Fly from Crossroads to Thunder Bluff (3 min in all)").
- **Each stop** shows its number, its name, what to do there (Accept, In progress, Turn in, Go to, No place known) and how far it is. Click it to go there first; right-click it for Go Here First, Move Up, Move Down, Move To Top, Quest Details and Remove.
- **Drag and drop**: drag a stop to another place. A ghost of the row follows the pointer and a gold line shows where it will land. Let go away from the list, or press Escape, to cancel.
- **Order For Me** puts the stops in a short order: nearest first, then each next stop nearest the one before.
- **The My Route window** (Edit My Route on the heading's menu, `/tracker route`, or the Open My Route key binding): numbered rows with a grip, the name, the zone and the distance, a cross to remove a stop, and Order For Me, Add Tracked Quests, Clear and Close. Drag rows to reorder them; click one to select it. Escape closes it, and it opens where you last left it. Another addon can open it beside the world map.
- **Following it**: click the My Route focus button, or click a stop. Route To Next Quest and Route To Previous Quest then walk its stops.
- **Without a mouse**: the menus' Move entries, and the Move My Route Stop Up and Move My Route Stop Down key bindings, which move the stop you last clicked or selected.

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

A tracker dimmed by Fade When Not Hovered wakes for a few seconds when one of these is pressed.

## Stepping back

Three switches, all off to begin with: dim in a fight, dim unless the mouse is over it (it wakes for a few seconds when something changes), and hide in dungeons and raids even when the game's tracker is not kept there.

## What it does by itself, and what it leaves alone

- **Nothing is moved for you** unless you enable it. "Quest Arrow On Nearest Quest" puts the game's arrow on the nearest tracked quest when no guide runs and you have chosen neither a quest nor a list to route along; it starts disabled. An arrow the game puts on a quest you have just accepted is moved on by it too.
- **RestedXP's own window** stays as it is unless you enable "Hide RestedXP Window". Then it is made invisible while the tracker lists the guide. RestedXP's settings are not changed, and its arrow and item buttons stay.
- **Party progress** is told between trackers only: the quest's number and a percentage, to your party, when it changes. Disable "Share Progress With Party" and nothing is sent.
- **A guide's words** are shown from the guide addon's own tables as the game runs. None are kept.

## The game's own tracker

While this one is shown, the game's tracker is made invisible and lets clicks through, so you do not see every quest twice. It is not removed or hidden, which is what makes other things go wrong. Disabling **Hide Default Tracker**, or `/tracker off`, brings it back as it was.

- **In dungeons, raids and battlegrounds** the game's tracker is let back, because it shows things there that this one may not, and this one steps aside so there is one list. Disable **Keep Default Tracker In Instances** to have this one there instead. With **Hide Default Tracker** disabled, both are shown there as everywhere.
- **If the quest list could not be shown** (an error), the game's tracker is let back until it can, and a chat line says so once.
- **EllesmereUI's quest tracker**, if you run it, is a third. You are told once; disable one of the two in the addon list.

## Using it

- **Fold it** by clicking a heading, with `/tracker fold`, or with the Collapse / Expand Tracker key binding.
- **Move it** with `/tracker move` (or Unlock Position in the options): drag it by the bar along its top, then right-click the bar (or `/tracker lock`). While it is unlocked it is shown at full brightness, even with nothing to list. Its top corner stays where you leave it: the list grows downward from there, and changing Scale does not move it.
- **Past a height you set**, the list scrolls with the mouse wheel or the Scroll Tracker Up and Scroll Tracker Down key bindings, and its top or bottom edge darkens while there is more of the list past it. While everything fits, the wheel is left to the camera.
- Clicks between the lines pass through to the world.

## Settings

**Options > AddOns > Patchwerk Forever**, or `/tracker config`:

| Page | Holds |
|---|---|
| Thread: Tracker | on or off, the game's tracker, width, the tallest it grows, its place, visibility (fading, instances) |
| Tracker: Quests | the order, the ready group, levels, kinds, distance, progress colors, the flash, the party, the quest arrow on the nearest quest |
| Tracker: Guide | the guide's steps, how many after, skipping by a click, the step's items, RestedXP's window; the focus buttons; My Route |
| Tracker: More | item buttons, recipes, the gathering list, a dungeon's stages |
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
