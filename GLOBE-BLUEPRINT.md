# Thread (Globe): blueprint

The world of WoW Forever on a globe in the look of the world map on parchment, that you can spin, and zoom from the whole world down to a continent, a zone and the ground, with your place, your route and your pins on it. Written 2026-11-19 after the prototype (Thread (Globe) 0.0.1, uncommitted).

## Where the prototype got us

**Proven in the game:**
- **Bent pictures:** an addon can draw a sphere out of bent pictures (`Texture:SetVertexOffset`, four corners each), and the game shows its own pictures by number. That includes the minimap pictures and the world map's parchment pictures.
- **Speed:** about 300 pieces redraw in 1.8 to 2.1 ms at 100 to 120 fps. The drawing is cheap; there is room for several times more pieces.
- **Placement:** your place, worked out from `UnitPosition`, lands on the right spot of both kinds of picture. Where I Am glides there, and drag and zoom work.

**What the screenshots show is wrong:**
1. **The game's continent maps are rectangles of painted sea.** Each continent map brings a large rectangle of its own blue-grey sea, with its own sea names, compass rose and sea serpent. On a globe they read as two posters glued on a ball:
   - the seas repeat ("The Great Sea" twice)
   - the two rectangles do not meet (the gap down the middle)
   - their sea is not the colour of the globe's sea (the tan bands above and below)
2. **No continuous world.** Nothing joins the continents; the world between them is empty.
3. **Zephra's Isle** has no continent map, so it shows as minimap pictures on a black square.
4. **The edge of the ball.** Pieces that cross the globe's edge fold over and show as black slivers (right side, bottom).
5. **Lighting.** The side light darkens the parchment unevenly; an old globe looks better evenly lit, with a soft darkening toward its edge.

**The conclusion:** the game's own pictures cannot make one seamless world, so the globe needs **pictures of our own**. The game's pictures stay useful for the closest zoom levels.

## The idea: one world, drawn in levels

Like Google Earth, the globe is drawn from the coarsest pictures that look sharp at the current zoom. Finer ones fade in as you zoom.

| Level | Seen at | Drawn from | Ours or the game's |
|---|---|---|---|
| **World** | the whole globe | one parchment picture of the whole sphere: sea, continents, coasts | **ours** |
| **Continent** | a continent fills the window | finer pieces of the same picture, cut in a quadtree (each piece split in four as you zoom) | **ours** |
| **Zone** | a zone fills the window | finer still: zone borders inked, land shaded by height | **ours** |
| **Ground** | a few hundred yards across | the minimap pictures in true colour, as the minimap shows them | **the game's**, by number |

Words are never baked into pictures: **labels** (continents, seas, zones, cities) are the game's own font, placed on the globe and faded in and out by zoom. So they stay sharp at every size and take no picture space.

A **zone** is something you can point at and click:
- pointing at it outlines it
- clicking zooms the globe to fit it
- its name comes from the game (`C_Map.GetAreaInfo`, `C_Map.GetMapInfo`)

"Combining maps and map types" happens in the levels: one picture of the world at every zoom, rather than the game's separate world, continent and zone maps stacked on each other.

## The custom graphics

### Made by our tools from the game's own data (as Thread (Routes)' map data is)

`casc.py`, `terrain.py` and `world.py` already read every continent's terrain, heights and water. A new `tools/globe_art.py` would turn that into the parchment world:

- **Land and sea:** from the terrain cells (walkable, steep, wade, swim) and the water levels, as Routes already has them.
- **Coastlines in ink**, with the ripple lines that run along the coast on the game's map: rings drawn off a distance-to-coast field.
- **Relief:** gentle hill shading from the heights, so mountains read as on a painted map.
- **Zone borders:** every terrain chunk names its zone (the area number in its header). Borders are drawn where neighbouring chunks differ, and each zone gets a fill from a palette like the game's map (greens, ochres, tans).
- **Zone outlines** for pointing and highlighting, kept as data (lists of points), not pictures.
- **The world sphere's layout:** where each continent sits, and the open sea between them. The sea gets a parchment grain and a faint wave hatching, and the empty ocean gets decorations (below).

### Made by hand or with an image tool (as the icons were)

These are things a program draws poorly:
- the **paper texture** (grain and stains), laid over everything
- a **compass rose**, **sea serpents** and **ships** for the open sea, placed once each
- the **brass meridian ring and stand** of a desk globe, round the ball

`art/PROMPTS.md` gets the prompts. The tools composite them into the picture.

### What ships

**Pictures** in WoW's own compressed format (BLP, DXT), which needs a small writer of our own (`tools/blp.py`). Uncompressed TGA would be about eight times larger.

**Pieces**, with a rough size:

| Piece | Holds | Size |
|---|---|---|
| World | about 2048 x 1024 | about 1 MB |
| Continent | finer pieces, about 10 yards a pixel at the finest | about 4 to 5 MB each |
| Zone outlines and labels | numbers only | small |

Each continent's pieces sit in a load-on-demand addon, as Routes' map data does, so nothing large loads until you zoom there.

No picture of the game's is copied into the addon. The ground level asks the game for its minimap pictures by number, as now.

## The renderer

What changes in `Globe.lua`:

- **The quadtree.** Each frame, walk down from the world level and stop at the piece whose texels on screen are about pixel-sized. A piece is drawn only if it faces you and is in the window, keeping the count at about 300 to 600. Pictures are loaded on first sight and let go (`SetTexture(nil)`) when long out of sight.
- **Crossfades.** A finer level fades in over the coarser one as you zoom (both drawn for a moment), so there is no pop.
- **The globe's edge.** A piece that crosses the edge is cut into four until its pieces are wholly in front or behind. No more folded slivers.
- **The look:**
  - even lighting, with a soft darkening toward the edge (a vignette picture over the ball)
  - a thin rim of air
  - the brass ring and stand of a desk globe
- **Zoom:**
  - toward the pointer, smoothed, as Google Earth does
  - double-click zooms in on a spot
  - a drag carries on a little after you let go
- **Labels:** each a `FontString` at a point on the sphere, shown only while that point faces you. Sized and faded by zoom: continents and seas far out, zones nearer, towns closest.
- **Your place:** an arrow turned to your facing (`GetPlayerFacing`).
- **Routes on top**, with Thread (Routes):
  - the trail drawn on the globe in short straight segments
  - flight paths as arcs
  - boats across the sea
  - your map pin
  - a click to set a pin

## Milestones

Each one is built, checked offline (`tools/lua_globe.py`), then tried in the game.

**G1. The renderer core, still on the game's pictures** (built 2026-11-19; tried in the game: smooth, edge clean, about 7 ms per drawing before anchoring pieces once, much better after)
- **Build:** the quadtree, crossfades, cutting pieces at the edge, zoom toward the pointer, the drag that carries on, labels from the game's zone list, the arrow.
- **Done when:** no slivers at the edge, labels follow the globe, and zooming in and out is smooth.

**G2. The art tools** (built 2026-11-19: `tools/blp.py`, `tools/globe_art.py test`, `Art/test_kalimdor.blp`; tried in the game the same day: our BLP loads and reads well)
- **Build:** `globe_art.py` and `blp.py`.
  - from the game's files: land, sea, coast, heights, zone of each chunk
  - one test piece of Kalimdor, written as BLP
- **Done when:** that piece shows in the game, sharp, and its coast meets the minimap pictures under it.

**G3. The world level** (built 2026-11-20: `python globe_art.py world`, 8 pictures of 512 from a 2048 x 1024 world, the layout in `Art.lua`; the hand-made pieces are laid in once they are in `art/PatchwerkForever_Thread_Globe/`)
- **Build:** the whole-sphere parchment picture, with the continents laid out, the sea and the decorations.
- **Done when:** the globe looks like one painted world, with no seams.

**G4. Continent and zone levels** (begun 2026-11-20: each continent in detail at 8 yards a pixel, 39 pictures of 512 for 8 x 8 terrain tiles each, fading in over the world picture; about 8 MB of pictures in all so far; tried in the game the same day: much better detail; zone pointing and highlighting still to do)
- **Build:** the finer pieces, the zone fills and borders, zone pointing, highlighting and click to fit.
- **Done when:** you can zoom from the world into any zone, and its border and name show.

**G5. The ground level**
- **Build:** the minimap pictures in true colour, fading in at the closest zoom.
- **Done when:** the step from our zone picture to the ground is not jarring.

**G6. Routes on the globe**
- **Build:** your place, the trail, flights, boats, the pin, click to pin.

**G7. Settling in**
- **Build:**
  - where it opens: its own window, and a button on the world map that swaps its top level for the globe
  - a key binding and gamepad controls (Console Port)
  - the options page
  - the README
  - a CurseForge project (which you make)

## Decisions taken (2026-11-19)

1. **Art source:** tools + hand-made. Land, coasts, relief and zone borders are made by our tools from the game's terrain. The paper grain, compass rose, sea serpents, ships and the brass ring are made by hand or with an image tool and laid over it.
2. **Image libraries:** install Pillow and numpy, for the tools only.
3. **Where it opens:** both. Its own window (`/globe`, a key binding), and a button on the world map that swaps its top level (Azeroth) for the globe.
4. **Layout:** the game's. Kalimdor west, the Eastern Kingdoms east, Zephra's Isle in the southern sea between them. The rest is open sea with decorations, and no invented land.
5. **Ground level:** the minimap pictures **in true colour**, as the minimap shows them: no greying, no tint. They fade in under the parchment at the closest zoom.
6. **Size:** about 10 MB is fine: the world picture about 1 MB, each continent's detail about 4 to 5 MB, loading only when you zoom there.
7. **Frame:** a desk globe, with a brass meridian ring and a stand round the ball. Both are hand-made art.

## Unknowns to try first (cheap, before the art)

- **BLP:** a BLP written by our own `blp.py` loads in the game (DXT1 and DXT5).
- **Zone numbers:** the zone number in each terrain chunk matches `C_Map.GetAreaInfo` names on Forever.
- **Fades:** `SetGradient` alpha on bent pictures (it worked for the parchment edges).
- **Masks:** whether masks follow bent pictures. Probably not; the plan does not need them.
- **Memory and speed:** with about 600 pieces and some 100 pictures loaded.

## Rules this keeps

- No picture of the game's in the addon; the game's pictures by number only.
- Our code and pictures under the MIT License.
- Plain, standard words in the game.
- Nothing from other addons (Curator's technique was studied; none of its code is used).
