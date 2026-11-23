# Patchwerk Forever: Tracker (Thread)

## 1.6.0

A collect list, and the quests your party shares. Works with Patchwerk Forever 2.6.0.

### With Routes (Thread)'s Mark The Way Ahead
- The quest the game's arrow is on, and your map pin (Add Map Pin To My Route), are read from Patchwerk Forever 2.9.0 when it has them, so they stay yours while Routes has lent the game's waypoint to mark the way ahead.

### With Sparkle (Thread)
- A quest item you loot flies into its quest's line in the tracker with Sparkle (Thread) 1.5.0 (its **Quest Items Fly To The Tracker**), and the line lights up as its count goes up.

### Collect
- **A new section, Collect**: any item against a number you set, such as "Linen Cloth 14/20". The count goes from red to green as it fills, as a quest's counts do; a row whose number is met is shown as complete and stays until you remove it. The list is kept for each character.
- **Add an item by dropping it**: while you hold an item from your bags, the Collect heading is shown, even with nothing listed. Click the heading or a row with the item, or drag it there: the item goes back where it was and a small box asks how many. Enter or Okay adds it, Escape cancels. An item already listed gets the new number. It works in combat.
- **Add what a recipe lacks**: a tracked recipe's right-click menu has Collect What Is Missing, which adds each reagent you have too few of with the number the recipe needs. An item already listed keeps the higher number.
- **Clicks**: with Routes (Thread), a click on a herb or an ore with a node near you starts a gathering run for it, and a second click stops it. Right-click a row for Change Count and Remove, the heading for Remove Completed and Clear. There is no command for adding.
- New options on Tracker: More: **Show Collect List** (enabled) and **Count Items In The Bank** (enabled).

### Party
- **A share mark** (three small dots at the right of a quest's name) on a quest that someone in your party is not on and that can be shared. Point at it to see who is not on the quest; click it to share the quest. No mark when you are alone, in a raid, when everyone is on the quest or when it cannot be shared. A member who has already turned the quest in is named too: the game does not say. New option on Tracker: Quests: **Show Share Mark** (enabled).
- **Sort Order has a new choice, Party's Quests First**: the quests someone in your party is also on come first, under a heading of their own, in the order By Zone would list them, then the rest by zone. Outside a party it is the same as By Zone. It is not the default.
- **New key binding, Share Quest With Party**: shares the quest under the quest arrow (picked as Add Quest To My Route picks its quest), and says in chat that it did or why it could not.
- Nothing new is sent to your party's trackers for any of this.

### Instances
- **The tracker is shown in dungeons, raids and battlegrounds**, as it is everywhere. Until now it stepped aside there for the game's own tracker. **Keep Default Tracker In Instances** is now disabled by default; enable it to have the game's tracker there in place of this one, as before. If you had changed that option yourself, your choice is kept.

## 1.5.0

- **Now named Patchwerk Forever: Tracker (Thread)**: the name comes first and what kind of addon it is after it, in brackets (it was Thread (Tracker)). The options page is named the same way.
- For addon authors: `PatchwerkForever_Thread_Tracker_Dock(frame)` puts the list beside another window while that window is open (to its right where the screen has room, else inside its right edge, and above it), and `PatchwerkForever_Thread_Tracker_Dock(nil)` puts it back where the player keeps it. Its saved place is not changed. Globe (Thread), new beside this, uses it to keep the list beside the globe.

## 1.4.0

Polish: the finer details. Works with Patchwerk Forever 2.6.0; the percent signs and the marker that follows Routes (Thread) need the newer base (and Routes) released beside this.

- **My Route says where it goes next**: at its top, the next stop, its zone, and while My Route is followed, the way there as Routes (Thread) finds it, such as "Fly from Crossroads to Thunder Bluff (3 min in all)". Each stop also shows its zone beside what to do there.
### Hints and the marker
- **Hovering a row or a heading shows what a click does**: "Click to route to this quest.", "Click to skip this step.", "Click to collapse." and so on, with "Right-click for more options." where there is a menu. An upcoming guide step's tooltip also shows its full text.
- **The bar beside a block marks what Routes (Thread) really follows.** After Stop Routing, or while Routes leads to your map pin, nothing is marked; with Routes leading to a quest, that quest is. Without Routes it works as before.

### Key bindings
- **The key bindings have a section of their own**, Patchwerk Forever, in the Key Bindings options. Bindings you already set are kept. A key bound while the Tracker is not running (its base too old) does nothing instead of giving an error.
- **Use Nearest Quest Item works with the item bar hidden**, and with nothing to use it says "No quest item to use." in the game's red error text.
- Collapse / Expand Tracker, a gathering click, Reset Position and a focus changed by a key now wake a tracker faded by Fade When Not Hovered, as Route To Next Quest already did.

### The list
- **Upcoming guide steps take one line each**, cut short, so they no longer take more room than the step you are on.
- **A timed quest no longer flashes every second** for as long as its timer runs, and no longer keeps a faded tracker awake.
- **Sort Order Completed First, Then By Zone** now puts the Ready To Turn In group at the top while Group Completed Quests is enabled (the default).
- Objectives that wrap now start their second line under their words, not under the dash; the time left and the party line have no dash.
- The heading's stitched underline reaches the right edge, and the guide's progress bar has a faint track behind it.

### The quest arrow
- **Going back to your main route puts the game's quest arrow back** where it was before you chose a quest, unless you moved it since.
- **Quest Arrow On Nearest Quest** (was Auto-Track Nearest Quest) keeps working after the game puts its arrow on a quest you accept, after a reload, and when you enable it with an arrow already placed.
- A quest you chose and then stop tracking in the quest log is let go: "Back to your main route."

### Moving it, and the quest item bar
- **Unlocked with nothing to list, the tracker is still shown**, saying "No tracked quests.", so there is a bar to drag. While unlocked it is never faded or hidden, and a right-click on the bar locks it.
- The quest item bar moves to the other side of the tracker when there is no room on the screen.
- Item buttons light up when pointed at and look pressed when clicked, and their count grows with Button Size.

### The game's tracker
- After a loading screen the game's tracker is made invisible at once, not half a second later.
- If the quest list ever cannot be shown, the game's tracker is shown instead, and a chat line says so once.

### Options and words
- Headings: Fading is now **Visibility**; Appearance's Size is now **Scale And Font**, and Background Opacity moved to the end of Colors.
- Faded Opacity, Scale and Background Opacity show a percent sign.
- The guide settings are grayed out while Show Guide Steps is disabled, and the item bar's Position while Show Quest Item Bar is.
- Choices in Title Case ("By Zone (Current Zone First)", "Left", "Right"); "Hide Default Quest Tracker" is now **Hide Default Tracker**, "Upcoming Steps" is **Upcoming Steps Shown**, and "Ready to Turn In" is **Ready To Turn In**. Saved settings are kept.
- On the Dungeon Journal list, `/tracker back` and Undo Skipped Guide Step now take back the last skip or jump and say "Skip taken back.", since that list's step number does not move.
- With a Patchwerk Forever too old for it, the line that says so names the addon, its version and the base version it needs (2.6.0).
- Route To Next Quest's chat line reads as Routes (Thread)'s does: Routing to quest "Raptor Thieves". American spelling throughout.

## 1.3.0

Choose what the route follows, and build your own route. **Needs Patchwerk Forever 2.6.0 or later.**

### Focus
- **Focus buttons** at the top of the tracker: one small button for each route you can follow (Auto, RestedXP, the Dungeon Journal list, Quests, My Route), only for what is installed and running. The one in use is lit and named beside them. Click one to follow it; right-click the row for the same choices as a menu. The focus is kept for each character. Choosing one lets go of a list you selected in the tracker; a quest you clicked still comes first. New setting: Show Focus Buttons (on by default).
- With a guide or your quests as the focus, the bar beside the list marks what is followed, and Auto-Track Nearest Quest leaves the quest arrow alone while a guide or My Route is the focus.

### My Route
- **A My Route section** above your quests: your own stops in your own order, each numbered, with what to do there (Accept, In progress, Turn in, Go to, No place known) and how far it is. Shown while it has stops, or while My Route is the focus. New setting: Show My Route (on by default).
- **Adding:** Add To My Route (and Remove From My Route) in a quest's right-click menu and on the Dungeon Journal list's stops; Add All Tracked Quests and Add Map Pin on the My Route heading's right-click menu; and a new key binding, Add Quest To My Route, for the quest under the quest arrow.
- **Click a stop** to go there first. **Right-click a stop** for Go Here First, Move Up, Move Down, Move To Top, Quest Details and Remove.
- **Drag and drop:** drag a stop to another place. A ghost of the row follows the pointer and a gold line shows where it will land. Let go away from the list, or press Escape, to cancel.
- **Without a mouse:** the menus' Move entries, and two new key bindings, Move My Route Stop Up and Move My Route Stop Down, which move the stop you last clicked.
- **The My Route window:** numbered rows with a grip, name, zone and distance, a cross to remove a stop, and Order For Me, Add Tracked Quests, Clear and Close. Drag rows to reorder them. Open it from the heading's menu, with `/tracker route` or the new Open My Route key binding. Escape closes it, and it remembers where you put it.
- **Order For Me** puts the stops in a short order: nearest first, then each next stop nearest the one before.
- **Route To Next Quest and Route To Previous Quest walk My Route** while it is the focus or the list you selected. With My Route empty, they walk your quests as before.
- Clear asks first.
- My Route is listed once, in its own section, and not again among the guides.

### Quests
- **New sort order: Shortest Trip.** Your tracked quests in a short path, the nearest first, then each next quest nearest to the one before. It is worked out again when a quest is added, removed or completed, so rows do not swap as you walk. Route To Next Quest and Route To Previous Quest follow it.

## 1.2.0

Polish: the things you meet every session.

### Position and long lists
- **A moved tracker keeps its top corner** where you put it and grows downward from there, and the Scale slider no longer moves it. A position saved by an earlier version is converted the first time the tracker is shown.
- **New key bindings: Scroll Tracker Up and Scroll Tracker Down**, for a list longer than Max Height.
- In a list longer than Max Height, Route To Next Quest and Route To Previous Quest scroll the quest they select into view, and going back to your main route scrolls the list to the top.
- The top or bottom edge of the tracker darkens while there is more of the list past it.
- Route To Next Quest, Route To Previous Quest and the two scroll bindings show a tracker faded by Fade When Not Hovered for a few seconds.
- Quests and quest item buttons no longer swap places each time two distances cross. The order changes only when one is clearly nearer (about 15 yards or 15 percent); the distance shown stays live.

### Guide steps
- **A click that skips a guide step now says so in chat**, with how to undo it. Jumping to a later step and going back a step are said too.
- **New key binding: Undo Skipped Guide Step**, which does what `/tracker back` does.
- `/tracker back` no longer goes back to a step skipped in a guide that has since been replaced, and when the guide has moved on it says which step it went back from.
- On the Dungeon Journal list, a click that skips a stop, goes back or brings a later stop forward is said in chat without a step number, since that list's number does not move.

### In instances
- **One quest list in dungeons, raids and battlegrounds.** While the default tracker is kept there (Keep Default Tracker In Instances, enabled by default), this tracker now hides, so quests are not listed twice. Disable that setting to have this tracker there instead. Use Nearest Quest Item keeps working.

### The Dungeon Journal list
- With Patchwerk Forever 2.5.0, a Dungeon Journal list shown without a guide is a side list: a click selects it instead of skipping a stop.
- Auto-Track Nearest Quest no longer moves the quest arrow while a list is the selected route, and it now works while the Dungeon Journal list is shown but not selected. Its tooltip says so.

## 1.1.0

- **A section for each guide.** With a second guide running beside your levelling guide (the Dungeon Journal's quests, through its Stitch), each has its own section. Click the second one's step to route along its list; click again to go back to your main guide. Its right-click menu skips a step or goes back one.
- "Hide RestedXP Window" now applies only while RestedXP's own guide is listed.
- Needs **Patchwerk Forever 2.4.0** or later.

## 1.0.0

The first full release. Everything in 0.9.0 has been played and works.

- **Route To Next Quest** and **Route To Previous Quest**: two key or gamepad bindings (and `/tracker next`, `/tracker previous`) that step through the quests in the order they are listed, so a quest can be chosen without a mouse. One step past either end returns to your main route.
- **Reset To Defaults** at the foot of its first options page (with Patchwerk Forever 2.3.0).
- Dungeon objectives stay experimental and off by default.

## 0.9.0 (beta)

Everything meant for 1.0, to be tried. **Needs Patchwerk Forever 2.2.0 or later.**

### Your guide
- With a guide addon running (RestedXP), a section above your quests: the step you are on, the steps after it dimmed, the guide's name, "step 34 of 120" and a thin bar.
- A click on the step skips it; a click on a later step goes to it; `/tracker back` takes the last one back. The guide addon moves itself, as on a click in its own window.
- RestedXP's own window can be made invisible while the tracker lists the guide (a setting, off to begin with).

### Quests
- Listed by zone, the zone you are in first, the nearest quest first. Other orders are a setting.
- Each shows how far it is, its kind (elite, dungeon, daily, group) and, when timed, the time left. Counts go from red to green.
- Quests ready to hand in gather in a short group at the foot.
- Left-click chooses a quest: a side path that Routes (Thread) follows before your guide, until you click it again or hand it in. Shift-click reads it; right-click opens a menu to share, stop tracking or abandon.
- A quest glows for a moment when its progress changes.
- Who in your party has a quest, and how far along they are when they run this tracker too.
- New setting, off by default: Auto-Track Nearest Quest.

### Item buttons
- A strip of buttons beside the tracker for the items your quests give you to use, the nearest quest's first, then the items your guide's step wants.
- A key or gamepad binding: use the nearest quest's item.
- Nothing of the strip is changed during a fight.

### More sections
- Recipes you track, with what each needs and what you have.
- Gathering, with Routes (Thread) 0.14.0: the nearest herb and ore spots you know, each a click from being led to.
- A dungeon's stages, where the game runs a place in stages. Untried, and off until ticked.

### Its options pages
- Five pages (Tracker (Thread), Tracker: Quests, Tracker: Guide, Tracker: More, Tracker: Appearance), each opening with a line from Patchwerk, their settings grouped under headings and named in standard terms (Font Size, Scale, Background Opacity, Fade In Combat).

### Stepping back
- Three settings, off to begin with: dim in a fight, dim unless the mouse is over it, hide in dungeons and raids.

## 0.1.0 (beta)

The first of it: a quest tracker of our own.

- The quests you track, each with its level, its objectives and how far each has got; a quest that is ready says where to hand it in.
- Fold it, move it, set its width and how tall it grows; past that it scrolls with the mouse wheel.
- Its size, the size of its writing, its background and its colours.
- The game's own tracker is kept quiet while this one is shown, and let back in dungeons, raids and battlegrounds.
- Needs the **Patchwerk Forever** base, 2.1.0 or later.
- Not in it yet: clicking a quest, sorting and filters, quest item buttons, tracked recipes, the steps of a guide.
