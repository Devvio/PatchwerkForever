# Patchwerk Forever: Thread (Globe)

**Patchwerk was told the world is round. Patchwerk checked.**

---

The world of **World of Warcraft: Forever** on a globe you can spin and zoom, painted like the world map on parchment, with your route, your quests, flight points, boats, towns and your group on it. **Still being built**: it is to stand in for the world map once it can do everything that map does, and that version will be 1.0.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the options pages. With **Thread (Routes)** it shows your route, the boats and zeppelins and the recorded nodes; with **Thread (Tracker)** that addon's list sits beside the globe. Neither is needed.

## How it is drawn

An addon cannot make a 3D shape, but it can move the four corners of a picture anywhere on the screen. The globe is a ball of small pictures, stretched between where their corners are seen as the globe turns.

The world on it is painted by this addon's own tools from the game's terrain: each zone in a tint of its own, gentle hills, an inked coastline with ripple lines out to sea, zone borders, and old paper over everything, in one picture of the whole sphere. On the open sea, a compass rose, sea serpents and ships in ink. Round the ball, the brass ring and wooden stand of a desk globe. As you zoom in, each continent in finer detail fades in over it (about 8 yards a pixel), and closer still the minimap's pictures of the ground; those are the game's own, asked of it by number. **Map Style** can show only the minimap's pictures instead. Pieces on the far side are hidden; each is shaded by how it faces a light.

The game's continents are separate maps with no sea between them, so where each sits on the globe is chosen: Kalimdor to the west, the Eastern Kingdoms to the east, Zephra's Isle in the southern sea between them. The seas are named as on the game's world map.

## Using it

- `/globe` opens or closes it; `/globe me` opens it turned to where you are; `/globe full` fills the screen with it, or goes back to a window.
- Drag the window's corner to size it. **Full Screen** fills the screen. Escape closes it.
- Drag to turn it; it carries on a little after you let go. The mouse wheel zooms toward the pointer, and a double-click zooms in on a spot.
- **Go To** lists the continents and their zones; picking one turns and fits the globe.
- Zoomed right out, the whole desk globe is in view, on its stand. Zooming in, the ball grows to fill the window and the ring and stand slide out of it.
- **Where I Am** glides it to your place, an arrow turned the way you face.
- The continents' names show when the whole globe is in view, and the zones' names as you zoom in (**Show Names**).
- Point at a zone and it is outlined, its name and levels at the top; zoomed in, the smaller place under the pointer is named under it. Click a zone and the globe turns and zooms to fit it. A right-click steps back out: to the whole continent, then the whole globe.
- Your coordinates, and those of the place under the pointer, are at the lower edge of the picture (**Show Coordinates**).
- Zoomed in, the minimap's pictures of the ground fade in over the parchment, in their true colours. They are drawn where there is land and fade out to the parchment sea a little way off the coast.
- The numbers under it say how many pieces are drawn and how long that takes. `/globe stats` says them in chat.
- Options: **Options → AddOns → Patchwerk Forever → Thread: Globe**, or `/globe config`.

## What is marked

Point at a mark for its name and what a click does. Marks on the far side of the globe are hidden, and where they crowd as you zoom out the more important one is kept. Each kind has a setting of its own.

- **Your route** (with Thread (Routes)): the trail it leads you along, in its own colours. A flight is a dashed arc, a boat or zeppelin a dashed line across the sea. My Route's stops are numbered; click one for Go Here First, Move Earlier, Move Later and Remove From My Route.
- **Your quests**: a numbered mark where each quest's next objective is, a question mark where it is handed in. Click one and the route goes there first; click it again to go back to your main route. Quests on offer in the zone at the middle show an exclamation mark, and the steps of the guide you run are numbered.
- **The map pin**: Ctrl-click sets it, as on the game's map. A click on it tracks it or stops tracking it, a Ctrl-click on it clears it, a Shift-click links it in chat.
- **Flight points** of your side (grey where not yet discovered), **boats and zeppelins** with what they go to and the wait, and the **herb and ore nodes** Thread (Routes) has recorded.
- **Places**: towns, landmarks, and dungeon and raid entrances as you zoom in to a zone; while you are dead, your corpse and the spirit healer.
- **Your group**: the members of your party or raid, each in the colour of their class.

The **Route** button lists what the route can follow, adds the map pin to My Route, opens My Route's editor, and keeps Thread (Tracker)'s list beside the globe while it is open. A quest clicked in that list turns the globe to it.

## Keys and gamepad

Everything the mouse does has a key binding, under **Options → Keybindings → Patchwerk Forever**: open or close, Where I Am, Full Screen Or Window, Go To, Fit The Zone At The Middle, Step Out, turning, zooming, Set Or Clear The Map Pin At The Middle, Next Mark and Route Menu. With keys the middle of the picture is the pointer: a cross marks it, and the zone and the mark there are named.

A gamepad turns the globe while it is open and you are not in combat: the left stick turns it, the right stick or the triggers zoom, and the four face buttons fit the zone at the middle (or press the mark there), step out (and close the window from the whole globe), go to the next mark, and set or clear the map pin. Every other button does what it is bound to. **Gamepad Turns The Globe** turns this off. With Console Port, the globe's bindings are also listed among its own.

## Credits

The code and pictures are under the MIT License. English only. The minimap pictures are the game's own, shown by the game from its files.
