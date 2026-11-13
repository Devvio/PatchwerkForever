# Patchwerk Forever: Thread (Tracker)

**Patchwerk had a list. Patchwerk lost the list. Patchwerk made a list that cannot be lost.**

Patchwerk is given many jobs. Fetch the heads. Find the pools. Bring back the hooves. By the third job Patchwerk has forgotten the first, and by the fifth he is fairly sure he was a tailor.

So Patchwerk sewed the jobs to the side of the screen. Every quest you track, and under each one what it still wants of you, the near ones on top. Done things go quiet. Things ready to hand in say so. The clever book that tells Patchwerk where to go next is sewn on too, and so are the flowers.

The game's own list is asked, politely, to stand in the corner and be invisible. It is not thrown out. Patchwerk knows what it is to be thrown out.

Patchwerk wants more jobs! Patchwerk wants them written down!

*One list. Hand-stitched. Mostly in order.*

---

A quest tracker for **World of Warcraft: Forever**: your quests by zone with how far each is, the steps of the guide you run, buttons for quest items, tracked recipes and a gathering list, in a list of our own that you can move, size and colour.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the settings pages, and nothing else. It works with no other addon installed; RestedXP Guides and Thread (Routes) each add a section when they are there.

**This is a beta, 0.9: everything meant for 1.0 is in it, and little of it has been played yet.** What has been seen working in the game is the plain list of quests. The rest runs against a stand-in for the game and is waiting to be tried. The dungeon stages are marked untried in the settings and start switched off.

## What it lists

- **Your guide's steps**, when a guide addon runs (RestedXP): the step you are on with its lines, the next few steps dimmed under it, and in the heading the guide's name, "step 34 of 120" and a thin bar.
- **The quests you track**, under the zone each belongs to. The zone you are in comes first, and within a zone the nearest quest. Other orders are a setting: one list nearest first, ready ones first, or as the game has them.
- **For each quest**: its level in the game's colour for its difficulty, its kind (elite, dungeon, daily, group), how many yards away it is, and its objectives. A count goes from red to green as it fills. A timed quest shows the time left.
- **Quests ready to hand in** leave the list for a short group at its foot, each saying where to take it. The game's own watch list is not changed.
- **Who in your party has a quest**, under it. For party members who run this tracker too, how far along they are.
- **Recipes you track** in a profession window, with what each needs and how much you have.
- **Gathering**, with Thread (Routes) installed: the nearest herb and ore spots you have gathered from before.
- **A dungeon's stages**, where the game runs a place in stages. Untried; off until you tick it.

## Clicks

| On | Click | Does |
|---|---|---|
| a quest | left | chooses it: a side path off the main track (your guide, or your nearest quest). Thread (Routes) goes there first, even while a guide runs, and the game's arrow is put on it. A second click goes back to the main track |
| a quest | shift-left | opens it to read |
| a quest | right | a menu: follow, read, share with the party, stop tracking, abandon (the game asks first) |
| the guide's step | left | skips it; right: skip, or back one step |
| a later guide step | left | goes to that step |
| a recipe | left | opens it; right: stop tracking |
| a gathering spot | left | leads you to the nearest of that kind and on to the next at each; a second click stops |
| a heading | left | folds its section |

A bar beside a block shows what is being followed: your guide's step, the quest you chose, or the gathering run.

Skipping a guide step is done by the guide addon itself, as a click in its own window does. `/tracker back` takes the last one back.

## Item buttons

A quest that gives you an item to use gets a button in a strip beside the tracker, the nearest quest's item first. The items your guide's step wants used (a hearthstone) follow them.

- **A key or gamepad button** can be bound to "Use Nearest Quest Item" (Key Bindings, under AddOns). It only ever uses a quest's item, never the guide's.
- **In a fight the strip does not change.** The game does not let an addon show, hide or move such buttons then. What changed meanwhile is applied when the fight is over, so the binding uses the item that was nearest when the fight began.

## Stepping back

Three switches, all off to begin with: dim in a fight, dim unless the mouse is over it (it wakes for a few seconds when something changes), and hide in dungeons and raids.

## What it does by itself, and what it leaves alone

- **Nothing is moved for you** unless you tick it. "Auto-Track Nearest Quest" puts the game's arrow on the nearest tracked quest when no guide runs and you have chosen none; it starts unticked.
- **RestedXP's own window** stays as it is unless you tick "Hide RestedXP Window". Then it is made invisible while the tracker lists the guide. RestedXP's settings are not changed, and its arrow and item buttons stay.
- **Party progress** is told between trackers only: the quest's number and a percentage, to your party, when it changes. Untick "Share Progress With Party" and nothing is sent.
- **A guide's words** are shown from the guide addon's own tables as the game runs. None are kept.

## The game's own tracker

While this one is shown, the game's tracker is made invisible and lets clicks through, so you do not see every quest twice. It is not removed or hidden, which is what makes other things go wrong. Unticking **Hide Default Quest Tracker**, or `/tracker off`, brings it back as it was.

- **In dungeons, raids and battlegrounds** the game's tracker is let back, because it shows things there that this one may not. A setting changes that.
- **EllesmereUI's quest tracker**, if you run it, is a third. You are told once; untick one of the two in the addon list.

## Using it

- **Fold it** by clicking a heading, with `/tracker fold`, or with a key or gamepad button you bind.
- **Move it** with `/tracker move` (or the button in the settings): drag it by the bar along its top, then `/tracker lock`.
- **Past a height you set**, the list scrolls with the mouse wheel. While everything fits, the wheel is left to the camera.
- Clicks between the lines pass through to the world.

## Settings

**Options, AddOns, Patchwerk Forever**, or `/tracker config`:

| Page | Holds |
|---|---|
| Thread: Tracker | on or off, the game's tracker, width, the tallest it grows, its place, stepping back |
| Tracker: Quests | the order, the ready group, levels, kinds, distance, progress colours, the flash, the party, following the nearest |
| Tracker: Guide | the guide's steps, how many after, skipping by a click, the step's items, RestedXP's window |
| Tracker: More | item buttons, recipes, the gathering list, a dungeon's stages |
| Tracker: Appearance | size, the size of the writing, the background, the colours |

## Commands

| Command | Does |
|---|---|
| `/tracker` | lists the commands (`/pftr` is the same) |
| `/tracker on` / `off` | shows it, or goes back to the game's own |
| `/tracker move` / `lock` / `reset` | drag it somewhere; fix it there; put it back under the minimap |
| `/tracker fold` | folds it up, or opens it again |
| `/tracker back` | takes back the last guide step skipped by a click |
| `/tracker config` | opens the settings |

## Credits

The code and pictures are under the MIT License. English only. RestedXP Guides is read as it runs; none of its code or guide text is in this addon.
