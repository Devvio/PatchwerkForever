# Patchwerk Forever: Wayfarer

A route planner for **World of Warcraft: Forever**. It finds the way to where you are going and draws it on the world map and the minimap: over the ground, through tunnels, over bridges, up lifts and by flight path.

It works on its own. It needs no other addon, Patchwerk Forever included, and takes nothing from one: its map data was worked out from the game's own files.

**This is a beta.** It has been played on a Horde character in Kalimdor. Routes in the Eastern Kingdoms and for Alliance characters pass the same checks outside the game but have had little play. Please report what goes wrong.

## Where it takes you

With nothing else to do, you only have to pick a destination:

- **Your map pin.** Put a pin on the world map and the route appears. A pin always comes first.
- **A quest you track.** With no pin, it routes to the quest the game's own arrow is on, or failing that the nearest quest in your tracker. It moves on to the next objective, and to whoever takes the quest in once it is done.
- **Your RestedXP guide.** With no pin, it routes to the guide's current step and moves on with it. Nothing of RestedXP's is changed.
- **A spot you type.** `/wayfarer to 45.2 61.8` routes to that place on the map you are on.

When a guide and a quest both lead somewhere, the guide goes first; a setting turns that round.

## What a route knows

- **The ground.** Slopes too steep to walk are avoided. Shallow water is waded, deep water is swum only when that is clearly quicker, and a route with a long swim says so.
- **Tunnels, bridges and gates** found in the game's buildings, the lifts of Thunder Bluff, and a few safe drops.
- **Flight paths.** It flies when that is quicker than walking, using only your faction's flight points and, unless you say otherwise, only the ones your character has found.
- **A wrong turn.** Stray from the trail and a new route is found from where you are.

The chat says how long the route takes and which flights it uses.

## Herb and ore spots

Each spot where you pick a herb or mine a vein is remembered for all your characters and shown on the minimap and on zone maps, with the icon of what you got there. They show where things grow, not whether one is there now.

## A sparkle on things you can use

As you come up to a herb, a vein, a chest or a quest object, a light effect and its name appear over it. It follows the thing the game's own interact key would use, so it works best with that key or a gamepad.

- **Twelve effects**: star, soft glow, pulsing ring, light beam, swirl, brackets, five subtle ones (glints, fireflies, faint shimmer, ground ripple, wisp), or the name alone.
- **Each kind of thing has its own look**: effect, colour, size, brightness, height and speed, with a Test button.
- **The name**: size, font, outline, colour and place.
- **Hiding**: in combat, in dungeons and raids, or on things you choose to ignore.
- **Behind your character** (optional): the sparkle fades where it would be drawn over your character.

While the sparkle is ticked, two of the game's own settings are switched on (`SoftTargetNameplateInteract` and `SoftTargetIconGameObject`), because without them there is nothing to hang the sparkle on. Unticking it puts them back as they were.

## Settings

**Options → AddOns → Patchwerk Forever: Wayfarer**, or `/wayfarer config`. The trail's colours, thickness and style (solid, dashes, dots, flowing) are there too.

## Commands

| Command | Does |
|---|---|
| `/wayfarer` | lists the commands (`/pfw` is the same) |
| `/wayfarer go` | routes to your map pin, or with none to your guide step or tracked quest |
| `/wayfarer to 45.2 61.8` | routes to that spot on the map you are on |
| `/wayfarer stop` | stops routing |
| `/wayfarer config` | opens the settings |
| `/wayfarer where` | says where the planner thinks you are |
| `/wayfarer quest` | says where the game puts your tracked quests, and which one is followed |
| `/wayfarer nodes` / `nodes forget` | counts the herb and ore spots; forgets the ones within 15 yards |
| `/wayfarer sparkle` | says what the game is pointing at, and why it does or does not sparkle |
| `/wayfarer ignore` / `undo` / `list` / `clear` | things that never sparkle |

Three actions can be bound to a key or a gamepad button (Options → Keybindings → AddOns, or Console Port's binding list): route now, stop routing, and never sparkle on this thing again.

## What it does not do yet

- **Other continents.** A destination on another continent gets no route. For a quest, it routes to the game's own next stop on the way when there is one.
- **Inside buildings.** A place on an upper floor or inside a city's buildings (Booty Bay, parts of the capitals) is routed to the nearest ground outside.
- **Some lifts and flight masters.** The Great Lift and the Undercity's lifts are not known. Flights are not started or ended at Ironforge or the Undercity.
- **Locked doors** count as open.
- **Flight times** are estimates.
- **English only.**

## Its parts

The download holds four folders. All four go in `Interface\AddOns`:

- `PatchwerkForever_Wayfarer`: the addon.
- `PatchwerkForever_Wayfarer_Kalimdor`, `_EasternKingdoms`, `_ZephrasIsle`: the map data, about 4 MB in all. Each is loaded only when you are on that continent.

## Credits

Part of the Patchwerk Forever family. It does not need Patchwerk Forever, and Patchwerk Forever does not need it. Not affiliated with RestedXP. The code and pictures are under the MIT License. The map data was worked out from World of Warcraft's game files, which belong to Blizzard Entertainment.
