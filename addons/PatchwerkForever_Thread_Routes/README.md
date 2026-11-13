# Patchwerk Forever: Thread (Routes)

**Follow the thread. It knows the way. Patchwerk checked. Twice.**

This one Patchwerk did not fix. This one Patchwerk *made*. Every hill, every tunnel, every bridge, worked out from the game's own files and wound onto one long spool.

Put a pin on the map, or track a quest, and the thread unrolls to it: over the ground, round the lake, up the lift, along the flight path, across the sea by boat or zeppelin. Take a wrong turn and it finds you again.

It also remembers where the herbs and the ore were. Patchwerk forgets many things. The thread does not.

No other addon's parts were used. Patchwerk is very proud. Patchwerk made a whole thing.

Patchwerk wants more maps! Patchwerk wants longer thread!

*Home-made. Hand-wound. Only slightly lost.*

---

A route planner for **World of Warcraft: Forever**. It finds the way to where you are going and draws it on the world map and the minimap: over the ground, through tunnels, over bridges, up lifts, by flight path, and by boat and zeppelin to the other continent.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the settings pages, and nothing else: its map data was worked out from the game's own files, and nothing is taken from another addon.

**This is a beta.** It has been played on a Horde character in Kalimdor. Routes in the Eastern Kingdoms and for Alliance characters pass the same checks outside the game but have had little play. Please report what goes wrong.

## Where it takes you

With nothing else to do, you only have to pick a destination:

- **Your map pin.** Put a pin on the world map and the route appears. A pin always comes first.
- **A quest you track.** With no pin, it routes to the quest the game's own arrow is on, or failing that the nearest quest in your tracker. It moves on to the next objective, and to whoever takes the quest in once it is done.
- **Your RestedXP guide.** With no pin, it routes to the guide's current step and moves on with it (more below). Nothing of RestedXP's is changed.
- **A spot you type.** `/thread to 45.2 61.8` routes to that place on the map you are on.

When a guide and a quest both lead somewhere, the guide goes first; a setting turns that round.

## The main track, and a path you choose

What the route follows by itself is the main track: your guide when one is running, else your tracked quests (the settings say which first). Now and then you want to go somewhere else for a while.

- **A quest you click in Thread (Tracker)** becomes the route, even while a guide is running. Its walking is drawn in a colour of its own, so you can tell a side path from the main track.
- **The way back is drawn too**: fainter, on from the quest to the step your guide is waiting at.
- **Click it again**, or hand the quest in, and the main track is followed once more.
- **A second guide's list** can be chosen the same way: the Dungeon Journal's quests (with its Stitch), clicked in the tracker, are followed stop after stop until the list is done or you go back.
- **A gathering run** is a side path of the same kind. There is one at a time: choosing a quest ends a run, and starting a run lets the quest go.
- A map pin of your own still comes before everything.

## Following a RestedXP guide

The guide is read as it runs: the step you are on, what it asks for, and the steps after it.

- **The guide's travel is followed.** When a step has you fly, the route leads on foot to the flight master the guide names and leaves the flying to the guide, instead of planning another way.
- **Steps with no place are said, not routed.** "Use your hearthstone" or "train your skills" has nowhere to go to: its words appear on screen, and no quest is followed in its stead.
- **The next step is ready.** The way from each step to the next is found ahead of time, so the trail changes the moment a step is done, with no pause.
- **The steps after are drawn.** A fainter trail runs on through the next few steps, on the world map and the minimap, so you can see where the guide is heading. A flight the guide has you take is a straight line in the flights' colour.

Settings: **Use Guide Travel Steps** and **Upcoming Steps Shown** (none to five; two to begin with).

This reads RestedXP's own lists of steps while the game runs. If a RestedXP update moves them, the route falls back to the spot RestedXP's arrow points at, as before.

## The step, said on screen

When the route gets a new destination, a few words appear in the upper middle of the screen: what you are going to do (the guide's own words for its step, a quest's name, "to your map pin"), and under them, smaller, the route: how long it takes, how far it is on foot, what it flies or rides. They fade in, stay a few seconds and fade out. Nothing is said when the way is only found again after a wrong turn.

Where the words stand, how large they are and how long they stay are on the page **Routes: Step Text**, with a button to try it. `/thread step` says the last one again.

## What a route knows

- **The ground.** Slopes too steep to walk are avoided. Shallow water is waded, deep water is swum only when that is clearly quicker, and a route with a long swim says so.
- **Tunnels, bridges and gates** found in the game's buildings, the lifts of Thunder Bluff, and a few safe drops.
- **Flight paths.** It flies when that is quicker than walking, using only your faction's flight points and, unless you say otherwise, only the ones your character has found.
- **Boats and zeppelins.** It takes one where that is quicker, and to reach another continent: the trail leads to the dock or the tower, shows the course across, and carries on from where you land. Only the ones your side can use. How long you wait for one is not known, so the time given allows for half its round trip.
- **A wrong turn.** Stray from the trail and a new route is found from where you are.

The chat says how long the route takes and which flights it uses.

## Herb and ore spots

Each spot where you pick a herb or mine a vein is remembered for all your characters and shown on the minimap and on zone maps, with the icon of what you got there. They show where things grow, not whether one is there now.

### Gathering runs

`/thread gather` leads you to the nearest spot you have gathered at before, and on reaching it goes on to the next, until `/thread gather stop`. Spots you have been to in the last five minutes are left out, so a run does not turn back on itself.

- `/thread gather round` keeps to the spots near where you began, and ends when you have been round them.
- `/thread gather Peacebloom` goes only to spots of that one thing. `/thread gather list` shows what is near.
- Only what your character can gather is gone to. While a run is on, your guide and your quests are not followed; a pin of your own still comes first.
- With **Thread (Tracker)** installed, its Gathering section lists the nearest spots and starts a run on a click.

The only spots known are the ones you have gathered from yourself: the game's files do not say where herbs and ore grow.

## Settings

**Options → AddOns → Patchwerk Forever → Thread: Routes**, or `/thread config`. The trail's colours, thickness and style (solid, dashes, dots, flowing) are on **Routes: Trail**; the words on screen are on **Routes: Step Text**.

## Commands

| Command | Does |
|---|---|
| `/thread` | lists the commands (`/pft` is the same) |
| `/thread go` | routes to your map pin, or with none to your guide step or tracked quest |
| `/thread to 45.2 61.8` | routes to that spot on the map you are on |
| `/thread stop` | stops routing |
| `/thread config` | opens the settings |
| `/thread where` | says where the planner thinks you are |
| `/thread quest` | says where the game puts your tracked quests, and which one is followed |
| `/thread step` | says the current step on screen again |
| `/thread nodes` / `nodes forget` | counts the herb and ore spots; forgets the ones within 15 yards |
| `/thread gather` / `gather round` / `gather <name>` / `gather list` / `gather stop` | a gathering run to the nearest spot and on; a round near here; one kind only; what is near; end it |

Two actions can be bound to a key or a gamepad button (Options → Keybindings → AddOns, or Console Port's binding list): route now, and stop routing.

## What it does not do yet

- **Docks and towers.** The trail ends on the ground beside a dock or a zeppelin tower, and a straight line stands in for the walk along the dock or the climb.
- **Boats that may not run.** The boat and zeppelin lines come from the game's files, which do not say which of them are in service. If the trail leads you to one that never comes, switch off Use Boats And Zeppelins and please report it.
- **Portals, the Deeprun Tram and hearthstones** are not used.
- **Inside buildings.** A place on an upper floor or inside a city's buildings (Booty Bay, parts of the capitals) is routed to the nearest ground outside.
- **Some lifts and flight masters.** The Great Lift and the Undercity's lifts are not known. Flights are not started or ended at Ironforge or the Undercity.
- **Locked doors** count as open.
- **Flight times** are estimates.
- **English only.**

## Its parts

The download holds four folders. All four go in `Interface\AddOns`:

- `PatchwerkForever_Thread_Routes`: the tool.
- `PatchwerkForever_Thread_Routes_Kalimdor`, `_EasternKingdoms`, `_ZephrasIsle`: the map data, about 4 MB in all. Each is loaded only when you are on that continent.

The sparkle on things you can use, once part of this addon, is now **Patchwerk Forever: Thread (Sparkle)**.

## Credits

Not affiliated with RestedXP. The code and pictures are under the MIT License. The map data was worked out from World of Warcraft's game files, which belong to Blizzard Entertainment.
