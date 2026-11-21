# Patchwerk Forever: Thread (Routes)

## 1.3.0

Works with Patchwerk Forever 2.6.0 or later, as before; what is new here needs 2.8.0. The three map data addons are 1.3.0 too (the data itself is unchanged).

- **The Deeprun Tram.** For the Alliance, routes between Stormwind and Ironforge take the tram where that is quicker: "Take the tram from Stormwind to Ironforge". Its two doors are read from the game's files; the ride (about a minute), the wait (about half a minute) and the walk through each city are estimates. Use Boats And Zeppelins turns it off with them.
- **The Great Lift and the lift of Freewind Post.** Routes between the Barrens and Thousand Needles go down the Great Lift instead of round through Dustwallow Marsh (Crossroads to Gadgetzan: about 20 minutes, was 24), and Freewind Post, which no route reached, is reached by its lift. Where each lift stands is read from the game's files; the half minute allowed for the wait and the ride is an estimate. This is in the Kalimdor map data.
- For addon authors: the trail, the boats, zeppelins and tram, the lifts, and the recorded herb and ore nodes are offered through the base's `PatchwerkForever.Trails`, so a tool with a map of its own can draw them as Routes draws them on the world map.

## 1.2.0

Polish. Needs Patchwerk Forever 2.6.0 or later, as before; the three map data addons are 1.2.0 too.

- **The way there, in words, for My Route**: once a route is found, Thread (Tracker) is told where to fly from and to, what boat or zeppelin to take, and how long it takes in all, and shows it at the top of My Route.
### Key bindings
- The bindings have a section of their own, **Patchwerk Forever**, on the Key Bindings page, shared with the family's other addons. Keys you had bound are kept.
- **Route To Pin, Guide Step Or Quest** is now called **Start Routing**.
- New: **Show Step Text Again**, and **Toggle Gathering Run** (starts a run to the nearest herb or ore node; pressed again, ends it).
- With a Patchwerk Forever too old for this addon, a bound key does nothing instead of giving a Lua error, and the chat line names the addon, its version and the Patchwerk Forever version it needs.

### What is followed
- **Thread (Tracker) marks what the route really follows**: Routes now tells it (with a Patchwerk Forever that passes it on), so the mark is right for a map pin, for a quest followed ahead of the guide, and after Stop Routing.
- Selecting a quest that has no location on the map, or one on a continent the route cannot reach from here, says so once in chat; your main route goes on. Selecting one while your map pin or coordinates stand says that those come first.
- **Start Routing** during a gathering run ends the run first.
- A gathering run that cannot start keeps the quest you had selected.
- A character with no gathering profession gets no gathering runs and no Gathering list: what you can gather is now asked the way the game's own profession book asks. Where the book lists no professions at all, both kinds of node are offered, as before.
- `/thread quest` reports what is followed in the order the route decides it (a gathering run, your pin or coordinates, a selection, the focus, then Route Priority), and names continents instead of numbering them.

### The trail
- **On a square minimap** the trail reaches into the corners, as the node icons already did.
- The upcoming steps of a list you selected (the Dungeon Journal's) are drawn in the Selected Route Color, like the step you are on.
- While the way to a new destination is being searched for, the trail before it stays in its own color, fainter, instead of taking on the new one's color.
- Dotted and dashed lines no longer run together into a solid line at wider line widths: the spacing grows with the width.
- The minimap trail and node icons are drawn again when something has changed rather than twenty times a second, and every frame while the minimap turns (Rotate Minimap), so they no longer step behind it.
- Searches for the upcoming steps take a smaller share of each frame than your own route, and both take half in combat.

### Words
- Chat lines begin **Routes:** instead of Thread: (the command stays `/thread`).
- **Follow RestedXP Guide** is now **Follow Guide**, and **Priority** is **Route Priority**, whose tooltip says what always comes before it; its choices read **Guide First** and **Tracked Quest First**. **Quest Selection**'s choices are in Title Case. The **Line Style** heading is now **Line**. **Animation Speed** shows a percent sign (with a Patchwerk Forever that shows one).
- The **Print Route In Chat** tooltip says what is printed.
- **Preview Step Text**: while the options are open, the sample follows the Step Text sliders as you move them, and is drawn above the options window.
- Opening the flight map on a continent for the first time is confirmed: "Flight map read: 14 flight points known on this continent." A flight point you find says "Flight point discovered".
- `/thread flights` loads the map data first (it answered "0 known, 0 not" before any route had loaded it), says when a map has no flight points, and when Use Flight Paths is disabled. A flight point found before any route was planned is now remembered.
- **Boat and zeppelin stops are named**: "zeppelin Thunder Bluff > Zephras Isle" and "boat near Gadgetzan > Powderfuse Port", instead of "a landing".
- `/thread to` shows the coordinates on screen ("To 45.2, 61.8"); `/thread where` names the continent.
- Reworded: standing where the planner knows no ground, a route that cannot be found, map data that could not be loaded (now by its title, with the game's own reason), and the gathering run lines.
- The addon list note says "nodes", as the options do. The map data addons are titled **Thread (Routes) Map: ...**.

## 1.1.0

Needs Patchwerk Forever with API 5 (the focus and My Route).

### Focus: you choose what the route follows
- **A focus** is your standing choice of what the route follows by itself: **Auto** (your guide or your tracked quests, by the Priority setting, as before), **RestedXP**, **Dungeon Journal**, **Quests** (tracked quests only) or **My Route**. Kept for each character.
- What comes first, highest first: a gathering run, your map pin or `/thread to` spot, a quest or list you selected, the focus, then Auto.
- A focus you chose is followed even with Follow RestedXP Guide or Follow Tracked Quests switched off.
- When the focus has nowhere to send you, the route follows Auto and says so once in chat, until the focus changes or has somewhere to go again.
- A change of focus is said on screen: "Following: Dungeon Journal".
- New: `/thread focus` (which focus is in use, and which can be chosen) and `/thread focus auto | rxp | dj | quests | route`.
- New key bindings: **Next Focus**, and **Focus: Auto**, **Focus: RestedXP**, **Focus: Dungeon Journal**, **Focus: Quests**, **Focus: My Route** (also in Console Port's binding list).
- The route changes the moment the focus, your selection or My Route changes, instead of at the next half-second check.

### On the world map
- **A focus button** at the map's top right: the focuses to choose from (the one in use checked), **Edit My Route** (with Thread (Tracker)) and **Add Map Pin To My Route**. New setting: **Focus Button On The World Map**.
- **My Route's stops are numbered on the map** while My Route is your focus or selected. Right-click a mark for Go Here First, Move Earlier, Move Later and Remove; a left-click goes there first. New setting: **Show My Route On The World Map**.

### The quest log
- **A + beside each quest** in the world map's quest log adds it to My Route (a check mark takes it out again), and the quest's right-click menu has **Add To My Route** / **Remove From My Route**.

### Fixed
- Starting a gathering run with `/thread gather` now ends a quest or list you had selected, as starting one from Thread (Tracker) does.

## 1.0.0

The first full release. Everything in 0.17.0 has been played and works; nothing else has changed. The three map data addons are 1.0.0 too.

## 0.17.0 (beta)

Polish: the things you meet every session.

### Step text
- **The step text is shown once per step**: not again when RestedXP's arrow moves to another spot of the same step, and not again when you are led back to a place you had already reached.
- A new guide step at the spot you are standing on now shows its step text.
- **When no route can be found, the step text says "No route found"** under the step, even with Show Route Summary disabled. `/thread step` repeats it until a route is found.

### When no route can be found
- The search is made again after 20 seconds and then less often (every two minutes at most), and at once when you change continent or move 300 yards, instead of every 10 seconds.
- A gathering run moves on to the next node when no route to a node can be found, without a chat line for each. Those nodes are tried again when you start a new run.
- A route search that fails with an error is reported once instead of on every retry.
- `/thread go` and the Route To Pin, Guide Step Or Quest key binding now always say why when there is no map data for the area.

### Stopping, flights and pins
- **Stopping says what was stopped**: a gathering run, the route to your map pin, the route to your coordinates, or the route to a guide step or quest (which resumes when the step or objective changes, or with `/thread go`).
- Stop Routing also clears the fainter trail of upcoming steps on the world map and the minimap.
- On a flight path the trail runs from you to where you land instead of back to the flight master you left.
- A map pin that is already on the map is picked up only when you log in or reload, not after every loading screen.
- With Patchwerk Forever 2.5.0, the Dungeon Journal list is routed along only once you select it.

## 0.16.0 (beta)

### Flight points you know
- **Your flight points are read from the flight map** whenever you open it at a flight master, and remembered for that character. This is now the main source; the game's world map is used only until you have opened a flight map on that continent, and is no longer trusted once it is caught saying you have a point you do not.
- **A flight point is also learned the moment you discover it** (the game's "new flight path discovered" message).
- **With nothing known yet on a continent, routes there go on foot** instead of using every flight point of your faction. You are told once, with what to do: open the flight map at a flight master.
- **A guide step that says "fly" to a point you do not have** no longer leads you to the flight master. The route goes by another way to where the guide sends you after the flight, and says so on screen.
- `/thread flights` lists the flight points you know and do not know on your continent, and where that knowledge comes from.
- Needs **Patchwerk Forever 2.4.1** or later for the guide part.

## 0.15.0 (beta)

- **A second guide's list can be selected as a side route**, as a quest can: the route follows it step after step in the selected-route colour, with its next steps drawn fainter, until it has no more or you go back to your main guide. This is what leads you through the Dungeon Journal's quests (with Patchwerk Forever: Stitch (Dungeon Journal)).
- Needs **Patchwerk Forever 2.4.0** or later.

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
