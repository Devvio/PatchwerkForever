# Patchwerk Forever: Thread (Globe)

**Patchwerk was told the world is round. Patchwerk checked.**

---

The world of **World of Warcraft: Forever** on a globe you can spin and zoom, painted like the world map on parchment. **A prototype**, to find out whether the game lets an addon draw it and how smoothly.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the options pages, and nothing else.

## How it is drawn

An addon cannot make a 3D shape, but it can move the four corners of a picture anywhere on the screen. The globe is a ball of small pictures, stretched between where their corners are seen as the globe turns.

The world on it is painted by this addon's own tools from the game's terrain: each zone in a tint of its own, gentle hills, an inked coastline with ripple lines out to sea, zone borders, and old paper over everything, in one picture of the whole sphere. As you zoom in, each continent in finer detail fades in over it (about 8 yards a pixel), and closer still the minimap's pictures of the ground; those are the game's own, asked of it by number. **Map Style** can show only the minimap's pictures instead. Pieces on the far side are hidden; each is shaded by how it faces a light.

The game's continents are separate maps with no sea between them, so where each sits on the globe is chosen: Kalimdor to the west, the Eastern Kingdoms to the east, Zephra's Isle in the southern sea between them. The seas are named as on the game's world map.

## Using it

- `/globe` opens or closes it; `/globe me` opens it turned to where you are.
- Drag to turn it; it carries on a little after you let go. The mouse wheel zooms toward the pointer, and a double-click zooms in on a spot.
- **Where I Am** glides it to your place, an arrow turned the way you face.
- The continents' names show when the whole globe is in view, and the zones' names as you zoom in (**Show Names**).
- Zoomed in, the minimap's pictures of the ground fade in over the parchment, in their true colours.
- The numbers under it say how many pieces are drawn and how long that takes. `/globe stats` says them in chat.
- Options: **Options → AddOns → Patchwerk Forever → Thread: Globe**, or `/globe config`.

## Credits

The code and pictures are under the MIT License. English only. The minimap pictures are the game's own, shown by the game from its files.
