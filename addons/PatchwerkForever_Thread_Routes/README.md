# Patchwerk Forever: Thread (Routes)

A route planner for **World of Warcraft: Forever**. It finds the way to where you are going and draws it on the world map and the minimap: over the ground, through tunnels, over bridges, up lifts, by flight path, and by boat and zeppelin to the other continent.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the settings pages, and nothing else: its map data was worked out from the game's own files, and nothing is taken from another addon.

**This is a beta.** It has been played on a Horde character in Kalimdor. Routes in the Eastern Kingdoms and for Alliance characters pass the same checks outside the game but have had little play. Please report what goes wrong.

## Where it takes you

With nothing else to do, you only have to pick a destination:

- **Your map pin.** Put a pin on the world map and the route appears. A pin always comes first.
- **A quest you track.** With no pin, it routes to the quest the game's own arrow is on, or failing that the nearest quest in your tracker. It moves on to the next objective, and to whoever takes the quest in once it is done.
- **Your RestedXP guide.** With no pin, it routes to the guide's current step and moves on with it. Nothing of RestedXP's is changed.
- **A spot you type.** `/thread to 45.2 61.8` routes to that place on the map you are on.

When a guide and a quest both lead somewhere, the guide goes first; a setting turns that round.

## What a route knows

- **The ground.** Slopes too steep to walk are avoided. Shallow water is waded, deep water is swum only when that is clearly quicker, and a route with a long swim says so.
- **Tunnels, bridges and gates** found in the game's buildings, the lifts of Thunder Bluff, and a few safe drops.
- **Flight paths.** It flies when that is quicker than walking, using only your faction's flight points and, unless you say otherwise, only the ones your character has found.
- **Boats and zeppelins.** It takes one where that is quicker, and to reach another continent: the trail leads to the dock or the tower, shows the course across, and carries on from where you land. Only the ones your side can use. How long you wait for one is not known, so the time given allows for half its round trip.
- **A wrong turn.** Stray from the trail and a new route is found from where you are.

The chat says how long the route takes and which flights it uses.

## Herb and ore spots

Each spot where you pick a herb or mine a vein is remembered for all your characters and shown on the minimap and on zone maps, with the icon of what you got there. They show where things grow, not whether one is there now.

## Settings

**Options → AddOns → Patchwerk Forever → Thread: Routes**, or `/thread config`. The trail's colours, thickness and style (solid, dashes, dots, flowing) are on **Thread: Trail**.

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
| `/thread nodes` / `nodes forget` | counts the herb and ore spots; forgets the ones within 15 yards |

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
