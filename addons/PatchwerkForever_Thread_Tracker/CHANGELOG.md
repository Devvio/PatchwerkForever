# Patchwerk Forever: Thread (Tracker)

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
- Left-click chooses a quest: a side path that Thread (Routes) follows before your guide, until you click it again or hand it in. Shift-click reads it; right-click opens a menu to share, stop tracking or abandon.
- A quest glows for a moment when its progress changes.
- Who in your party has a quest, and how far along they are when they run this tracker too.
- New setting, off by default: Auto-Track Nearest Quest.

### Item buttons
- A strip of buttons beside the tracker for the items your quests give you to use, the nearest quest's first, then the items your guide's step wants.
- A key or gamepad binding: use the nearest quest's item.
- Nothing of the strip is changed during a fight.

### More sections
- Recipes you track, with what each needs and what you have.
- Gathering, with Thread (Routes) 0.14.0: the nearest herb and ore spots you know, each a click from being led to.
- A dungeon's stages, where the game runs a place in stages. Untried, and off until ticked.

### Its options pages
- Five pages (Thread: Tracker, Tracker: Quests, Tracker: Guide, Tracker: More, Tracker: Appearance), each opening with a line from Patchwerk, their settings grouped under headings and named in standard terms (Font Size, Scale, Background Opacity, Fade In Combat).

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
