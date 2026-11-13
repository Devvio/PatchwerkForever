## 0.14.0 (beta)

### The main track, and a path you choose
- Your guide (or, with none, your tracked quests) is the main track. **A quest you click in Thread (Tracker) is a side path that comes first**: the route goes to it even while a guide is running.
- The side path's walking is drawn in a colour of its own (new setting: Selected Route Color), and the way on from the quest back to your guide's step is drawn fainter.
- Clicking the quest again, or handing it in, gives the main track back. A gathering run is a side path too, in the same colour; there is one side path at a time.

### Its options pages
- The pages are now **Thread: Routes**, **Routes: Trail** and **Routes: Step Text**, each opening with a line from Patchwerk, with headings for their sections (with Patchwerk Forever 2.2.0). Settings are renamed in standard terms (Line Style, Animation Speed, Walking Color, Font Size), and chat messages, command help and key bindings are reworded to match; nothing changes in what they do.

### Gathering runs
- `/thread gather` leads to the nearest herb or ore spot you have gathered at before, and on reaching it goes on to the next, leaving out the ones you have just been to, until `/thread gather stop`.
- `/thread gather round` keeps to the spots near where you began; `/thread gather <name>` goes only to spots of one thing; `/thread gather list` shows what is near.
- Only spots your character can gather are gone to. While a run is on, your guide and quests are not followed; a pin of your own still comes first.
- The spots show where things grow, not whether one is there now.
- With Thread (Tracker) installed, the runs are listed and started from its Gathering section.

## 0.13.0 (beta)

- The guide is now read by the Patchwerk Forever base (its new guides service), which other tools can use too. **Needs Patchwerk Forever 2.1.0 or later.** Nothing changes in how a guide is followed.

## 0.12.0 (beta)

### RestedXP guides, read ahead
- The guide is now read as it runs, not only the spot its arrow points at: the step you are on, what it asks for, and the steps after it.
- **The guide's travel is followed.** A step that has you fly is gone to on foot, to the flight master the guide names. A step with no place (use your hearthstone, train your skills) is said on screen instead of routed, and no quest is followed in its stead.
- **The next step is ready.** The way from each step to the next is found ahead of time, so the trail changes the moment a step is done.
- **The steps after are drawn**: a fainter trail on through the next few steps, on the world map and the minimap.
- New settings: Follow The Guide's Travel, and Guide Steps Shown Ahead (none to five).
- Fixed: while RestedXP hid its arrow (a step with no place), the route could still lead to the spot the arrow last pointed at.

### The step, said on screen
- When the route gets a new destination, a few words fade in on the upper middle of the screen: the step (the guide's own words, a quest's name, "to your map pin") and, under them, the route. Not when the way is only found again after a wrong turn.
- A new page of settings, **Thread: Step Text**: on or off, the route line, size, how long it stays, where it stands, and a button to try it.
- `/thread step` says the last one again.

## 0.11.0 (beta)

A new name and a new home. This addon was "Wayfarer" until now.

- **It is now Patchwerk Forever: Thread (Routes)**, one of Patchwerk Forever's own tools, and **needs the Patchwerk Forever base** (a small addon). Its settings are under Options → AddOns → Patchwerk Forever, on the pages **Thread: Routes** and **Thread: Trail**.
- **The command is `/thread`** (or `/pft`).
- **The sparkle moved out** to an addon of its own, *Patchwerk Forever: Thread (Sparkle)*, for people who want it without the map data, or the routes without it. Install it to keep the sparkle.
- The folders and the saved data have new names. Settings and herb and ore spots saved under the old name are not read; the key bindings need setting again.
- A new icon in the game's addon list.

## 0.10.0 (beta)

### Boats and zeppelins
- Routes now take boats and zeppelins: to reach another continent, and on one continent where that is quicker (the zeppelin between the Undercity and Grom'gol, the boat to Teldrassil, the Feathermoon ferry).
- The trail leads to the dock or the tower, shows the course across, and carries on from where you land. The other continent's map shows the part of the route over there.
- Map pins, tracked quests and RestedXP steps on another continent are all followed.
- New settings: Use Boats And Zeppelins, and a colour for their course.
- The lines and their stops come from the game's files. How long you wait for one, and whether every line is in service, are not in the files: the times are estimates.

## 0.9.0 (beta)

First public release, for World of Warcraft: Forever 1.60.1.

### Routes
- Routes on the world map and the minimap, over the ground, through tunnels and gates, over bridges, up the lifts of Thunder Bluff and by flight path.
- Destinations: your map pin, a quest you track, the current step of your RestedXP guide, or a spot typed with `/thread to`.
- A new route when you stray from the trail.
- The trail's colours, thickness and style (solid, dashes, dots, flowing) can be set.

### Herb and ore spots
- Spots where you gather are remembered for all your characters and shown on the minimap and zone maps.

### Sparkle
- A light effect and a name over the herb, vein, chest or quest object the game's interact key would use.
- Twelve effects, five of them subtle; each kind of thing has its own look.
- Optional: hidden in combat, in dungeons and raids, on things you ignore, and faded where it would cover your character.

### Known limits
- No routes between continents; places inside buildings are routed to the nearest ground outside.
- The Great Lift and the Undercity's lifts are not known.
- Played so far on a Horde character in Kalimdor; the Eastern Kingdoms and Alliance routes have had little play.
