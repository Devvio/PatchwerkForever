# Patchwerk Forever: Routes (Thread)

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

## Where it takes you

With nothing else to do, you only have to pick a destination:

- **Your map pin.** Put a pin on the world map and the route appears. A pin always comes first. A pin that is already on the map is picked up when you log in or reload, not after other loading screens.
- **A quest you track.** With no pin, it routes to the quest the game's own arrow is on, or failing that the nearest quest in your tracker. It moves on to the next objective, and to whoever takes the quest in once it is done.
- **Your RestedXP guide.** With no pin, it routes to the guide's current step and moves on with it (more below). Nothing of RestedXP's is changed.
- **A spot you type.** `/thread to 45.2 61.8` routes to that place on the map you are on.
- **Your corpse.** While you are a ghost, the route leads to your corpse before anything else (more below).

When a guide and a quest both lead somewhere, the guide goes first; the setting **Route Priority** turns that round.

## The main track, and a path you choose

What the route follows by itself is the main track: your guide when one is running, else your tracked quests (the settings say which first). Now and then you want to go somewhere else for a while.

- **A quest you click in Tracker (Thread)** becomes the route, even while a guide is running. Its walking is drawn in a color of its own, so you can tell a side path from the main track.
- **The way back is drawn too**: fainter, on from the quest to the step your guide is waiting at.
- **Click it again**, or hand the quest in, and the main track is followed once more.
- **A second guide's list** can be chosen the same way: the Dungeon Journal's quests (with its Stitch), clicked in the tracker, are followed stop after stop until the list is done or you go back. Its next stops are drawn in the selected color too.
- **A gathering run** is a side path of the same kind, and so is **a flight point search** (`/thread discover`). There is one at a time: choosing a quest ends a run or a search, and starting one lets the quest go (unless it cannot start) and ends the other.
- A map pin of your own still comes before all of these. Only the way to your corpse comes before a pin.
- **When a quest you select cannot be followed**, the chat says why, once: it has no location on the map, it is on a continent the route cannot reach from here, or your map pin comes first.
- **Globe (Thread) draws the route on its globe**: the trail, the boats, zeppelins and tram, the lifts, and the recorded herb and ore nodes, as on the world map.
- **Tracker (Thread) marks what the route follows**: Routes tells it, so the mark is right for a map pin, for a quest ahead of the guide, and after Stop Routing (with a Patchwerk Forever that passes it on).

## Focus: you choose what the route follows

By itself the route follows the main track. A **focus** is your standing choice of something else, kept for each character until you change it:

| Focus | The route follows |
|---|---|
| **Auto** | the main track: your guide or your tracked quests, by Route Priority |
| **RestedXP** | your RestedXP guide only |
| **Dungeon Journal** | the Dungeon Journal's quests only (with its Stitch) |
| **Quests** | your tracked quests only: the quest arrow's, or the nearest |
| **My Route** | your own list of stops, in your order (below) |

Only what is running is offered. The way to your corpse, a gathering run or flight point search, your map pin and a quest or list you select still come first. You chose the focus yourself, so **Follow Guide** and **Follow Tracked Quests** being disabled do not hold it back.

- **When the focus has nowhere to send you** (the journal's list is done, nothing is tracked, My Route is empty), the route follows Auto instead and says so once in chat.
- **A change of focus is said on screen**: "Following: Dungeon Journal", above the words of the step it leads to.
- **Where to change it:** the button at the top right of the world map, `/thread focus`, the key bindings, and Tracker (Thread)'s focus bar.

## My Route on the world map

My Route is a list of stops you put in your own order: quests in your log, Dungeon Journal quests not yet taken, and map spots. It is kept for each character, by Patchwerk Forever; Tracker (Thread) has its editor. A quest to turn in waits while another stop's objective or pickup is clearly nearer.

- **Numbered marks.** While My Route is your focus or the list you selected, its stops are marked on the world map, 1, 2, 3, in the list's order (only those on the map shown).
- **Right-click a mark** for **Go Here First**, **Move Earlier**, **Move Later** and **Remove**. A left-click goes there first.
- **The focus button's menu** has **Edit My Route** (opens Tracker (Thread)'s editor beside the map) and **Add Map Pin To My Route**.

## The quest log

On the world map's quest log, each quest has a small **+** beside its title: click it to add the quest to My Route. A quest already in My Route shows a check mark instead; click it to take the quest out. The quest's right-click menu has **Add To My Route** or **Remove From My Route** as well. Nothing of the quest log itself is changed.

## Flight points you know

A route only flies between flight points your character has discovered (the setting **Known Flight Points Only**, on by default).

- **Open the flight map at any flight master** and what it shows is remembered: which points you can fly to, and which you cannot. Do this once on each continent; the chat confirms it ("Flight map read: 14 flight points known on this continent.").
- **A point you discover later** is added as you find it.
- **Until then, routes on that continent go on foot.** You are told once.
- **When your guide says "fly" to a point you do not have**, the route does not lead you to the flight master. It goes by another way to where the guide sends you next, and says so.
- `/thread flights` shows what is known and where that comes from.

### Finding the flight points you lack

`/thread discover` leads you to the nearest flight point of your faction that your character has not discovered. When that one is discovered, the route goes on to the next nearest, until none is left on the continent or `/thread discover stop`. The step text says "Discover the flight point at Ratchet", and when the last one is found the chat says that all flight points on this continent are known.

- **Open the flight map at a flight master first.** Until one has been opened on the continent, a flight point you have not discovered cannot be told from one that was never read, so the search does not start and says so.
- **The way there is found as any other.** It may fly between flight points you already have.
- **At the flight point** the search waits until the game says the point is discovered, then goes on. A point is left out for the rest of the search, and named when it ends, when no route to it is found (the flight masters inside Ironforge and the Undercity are among these: the planner does not know the cities' floors), or when you walk away from it without discovering it.
- **It is a side path**, like a gathering run: one at a time, your guide and quests are not followed meanwhile, a pin of your own still comes first, and **Start Routing** ends it.
- The **Toggle Flight Point Search** key starts a search and, pressed again, ends it.

## The way back to your corpse

When you have died and released, the route leads to your corpse. It comes before everything else, your map pin included, and the step text says "To your corpse". The setting is **Route To My Corpse**, on to begin with.

- **Nothing is lost.** A gathering run, a flight point search, a quest you selected, your focus and your map pin all wait, and are followed again as they were once you are alive. A pin you place while dead waits too, and the chat says so.
- **On foot only.** A ghost takes no flight, boat, zeppelin or tram, so a corpse on another continent is not routed to.
- **Not across water.** A ghost walks on water, but the route does not know it: what water costs is part of the map data itself. The trail is the way a living character would walk, and cutting straight across a lake may be shorter. The time shown is a living character's too.
- **A corpse with no place on the map** (it lies in an instance, or the game does not say) is not routed to. The chat says why once for each death, except on a battleground or in an arena, and your other routes go on.
- **Stop Routing** stops the way to the corpse and leaves nothing routed while you are a ghost; **Start Routing** leads to the corpse again. Reaching the corpse does the same until you are alive.

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

A step is said once. It is not said again when RestedXP's arrow only moves to another spot of the same step, or when you are led back to a place you had already reached. Where no route can be found, the smaller line says **No route found**.

Where the words stand, how large they are and how long they stay are on the page **Routes: Step Text**, with a button to try it. `/thread step` says the last one again.

## What a route knows

- **The ground.** Slopes too steep to walk are avoided. Shallow water is waded, deep water is swum only when that is clearly quicker, and a route with a long swim says so.
- **Buildings and cities.** A route goes round the game's buildings and through their gates and doorways. In a city built as one piece (Orgrimmar, Stormwind) it follows the streets, ramps and bridges. Piers and docks are walked.
- **Tunnels, bridges and gates** found in the game's buildings, the lifts of Thunder Bluff, the Great Lift and the lift of Freewind Post, and a few safe drops.
- **Flight paths.** It flies when that is quicker than walking, using only your faction's flight points and, unless you say otherwise, only the ones your character has found.
- **Boats and zeppelins.** It takes one where that is quicker, and to reach another continent: the trail leads to the dock or the tower, shows the course across, and carries on from where you land. Only the ones your side can use. How long you wait for one is not known, so the time given allows for half its round trip.
- **The Deeprun Tram.** For the Alliance, a route between Stormwind and Ironforge takes the tram where that is quicker: "Take the tram from Stormwind to Ironforge". In Stormwind the trail leads through the city to the station. At Ironforge it ends outside the city, since the planner does not know Ironforge's floors; the walk to the station there and the ride are counted in the time. It is part of Use Boats And Zeppelins.
- **A wrong turn.** Stray from the trail and a new route is found from where you are.
- **On a flight path** the trail runs from you to where you land, and on from there.
- **A new destination.** Until its way is found, the trail before it stays, fainter, in its own color.
- **No route.** When no way can be found, the step text says so. The search is made again after 20 seconds, then less and less often (every two minutes at most), and at once when you have moved 300 yards or changed continent. A gathering run goes on to the next spot instead.

The chat says how long the route takes and which flights it uses.

## The way ahead, in the world

**Mark The Way Ahead** (on Routes: Trail, on to begin with) puts the game's own waypoint marker, and its arrow at the edge of the screen, on the trail about 40 yards ahead of you, and moves it on as you walk: the way round walls and through gates shows in the world. Near the end it stands on the destination, and where the trail takes a flight, a boat or a zeppelin it stands where that leaves. An addon cannot draw in the world, and the game's marker is the one thing there that it can move.

For that, your map pin and the quest you track are lent (through Patchwerk Forever 2.9.0). The route still goes where they say, and they are given back when the route ends, when you disable the setting, and at logout. A pin you set or a quest you choose meanwhile is yours, and is routed to. **Patchwerk Forever: Sparkle (Thread)** lights the marker up with its Waypoint sparkle.

## Herb and ore spots

Each spot where you pick a herb or mine a vein is remembered for all your characters and shown on the minimap and on zone maps, with the icon of what you got there. They show where things grow, not whether one is there now.

### Gathering runs

`/thread gather` leads you to the nearest spot you have gathered at before, and on reaching it goes on to the next, until `/thread gather stop`. Spots you have been to in the last five minutes are left out, so a run does not turn back on itself.

- `/thread gather round` keeps to the spots near where you began, and ends when you have been round them.
- `/thread gather Peacebloom` goes only to spots of that one thing. `/thread gather list` shows what is near.
- Only what your character can gather is gone to, as the game's profession book says; a character with no gathering profession gets no runs. While a run is on, your guide and your quests are not followed; a pin of your own still comes first, and **Start Routing** ends the run.
- With **Tracker (Thread)** installed, its Gathering section lists the nearest spots and starts a run on a click. The **Toggle Gathering Run** key starts one and, pressed again, ends it.

The only spots known are the ones you have gathered from yourself: the game's files do not say where herbs and ore grow. With **Patchwerk Forever: Sparkle (Thread)** 1.5.0 and Patchwerk Forever 2.9.0, the herbs and ore you walked past without gathering are added too, with the game's plain herb or ore icon until you gather there yourself.

## Settings

**Routes (Thread)** in Patchwerk Forever's options window, `/thread config`. The trail's colors, width and style (solid, dashed or dotted, animated if you like) are on **Routes: Trail**; the words on screen are on **Routes: Step Text**, whose sample follows the sliders while you move them.

Under **Destinations**: **Route To Map Pin**, **Route To My Corpse**, **Follow Guide**, **Follow Tracked Quests** and **Route Priority** (what always comes first is in its tooltip). Under **Focus And My Route**: **Focus Button On The World Map** and **Show My Route On The World Map** (both on to begin with).

## Commands

| Command | Does |
|---|---|
| `/thread` | lists the commands (`/pft` is the same) |
| `/thread go` | routes to your map pin, or with none to your guide step or tracked quest; as a ghost, to your corpse |
| `/thread to 45.2 61.8` | routes to that spot on the map you are on |
| `/thread stop` | stops routing, and says what was stopped; a route to a guide step or a quest resumes when the step or objective changes, or with `/thread go` |
| `/thread config` | opens the options |
| `/thread where` | says where the planner thinks you are |
| `/thread quest` | says where the game puts your tracked quests, and what is followed, in the order the route decides it |
| `/thread focus` | says which focus is in use, and which can be chosen |
| `/thread focus auto` / `rxp` / `dj` / `quests` / `route` | follows Auto, RestedXP, the Dungeon Journal, your tracked quests only, or My Route |
| `/thread step` | says the current step on screen again |
| `/thread flights` | lists the flight points you know on this continent, and how that is known |
| `/thread nodes` / `nodes forget` | counts the herb and ore spots; forgets the ones within 15 yards |
| `/thread gather` / `gather round` / `gather <name>` / `gather list` / `gather stop` | a gathering run to the nearest spot and on; a round near here; one kind only; what is near; end it |
| `/thread discover` / `discover stop` | a search for the flight points you lack: to the nearest one and on to the next; end it |

## Key bindings

Bind these under Options → Keybindings → Patchwerk Forever, or in Console Port's binding list: **Start Routing** (`/thread go`), **Stop Routing**, **Show Step Text Again**, **Toggle Gathering Run**, **Toggle Flight Point Search**, **Next Focus** (goes round the focuses that can be chosen), and one for each focus: **Focus: Auto**, **Focus: RestedXP**, **Focus: Dungeon Journal**, **Focus: Quests** and **Focus: My Route**.

## What it does not do yet

- **Zeppelin towers.** The trail ends at the foot of a zeppelin tower; the climb is counted in the time.
- **Boats that may not run.** The boat and zeppelin lines come from the game's files, which do not say which of them are in service. If the trail leads you to one that never comes, disable Use Boats And Zeppelins and report it.
- **Portals and hearthstones** are not used.
- **A ghost's short cuts.** The way to your corpse does not cross water as a ghost can, and its time is a living character's.
- **Inside buildings.** A place inside a small building, or on a level reached only by a lift the planner does not know, is routed to the nearest ground outside. Where one floor lies over another, only the wider one is known.
- **Small scenery.** Tents, carts, trees and the like are not known, and a route may cross them.
- **Some lifts and flight masters.** The Undercity's lifts are not known: they lead to floors inside the city, which the planner does not know. Flights are not started or ended at Ironforge or the Undercity.
- **Locked doors** count as open.
- **Flight times** are estimates.
- **English only.**

## Its parts

The download holds four folders. All four go in `Interface\AddOns`:

- `PatchwerkForever_Thread_Routes`: the tool.
- `PatchwerkForever_Thread_Routes_Kalimdor`, `_EasternKingdoms`, `_ZephrasIsle`: the map data, about 4 MB in all. Each is loaded the first time a route needs it; with boats and zeppelins on, the first route loads all three.

The sparkle on things you can use, once part of this addon, is now **Patchwerk Forever: Sparkle (Thread)**.

Something wrong? Report it as a comment on the addon's CurseForge page.

## Credits

Not affiliated with RestedXP. The code and pictures are under the MIT License. The map data was worked out from World of Warcraft's game files, which belong to Blizzard Entertainment.
