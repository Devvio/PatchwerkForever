# Globe (Thread): blueprint

The world of WoW Forever on a globe in the look of the world map on parchment, that you can spin, and zoom from the whole world down to a continent, a zone and the ground, with your place, your route and your pins on it. Written 2026-11-19 after the prototype (Globe (Thread) 0.0.1). The road from here to standing in for the world map was added 2026-11-21: see The road to parity.

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

### Made by our tools from the game's own data (as Routes (Thread)'s map data is)

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
- **Routes on top**, with Routes (Thread):
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

**G3. The world level** (built 2026-11-20: `python globe_art.py world`, 8 pictures of 512 from a 2048 x 1024 world, the layout in `Art.lua`; the hand-made pieces were laid in 2026-11-20 from `art/PatchwerkForever_Thread_Globe/globe/`: the paper over the world and the detail alike, sampled by latitude and longitude so both show the same stains; the compass rose, serpents and ships as pictures of their own on the sphere (`Art/decor_<name>.blp`, kind `decor`), so they stay sharp; the ring and stand cut from its magenta (`Art/ring.blp`, `ns.RING`), drawn round the ball, with the widest zoom now showing the whole desk globe, the ball lifted above the middle to make room for the stand. About 11 MB of pictures in all. Not yet tried in the game.)
- **Build:** the whole-sphere parchment picture, with the continents laid out, the sea and the decorations.
- **Done when:** the globe looks like one painted world, with no seams.

**G4. Continent and zone levels** (begun 2026-11-20: each continent in detail at 8 yards a pixel, 39 pictures of 512 for 8 x 8 terrain tiles each, fading in over the world picture; about 8 MB of pictures in all so far; tried in the game the same day: much better detail. Zones built the same day: `python globe_art.py zones` writes `Zones.lua` (52 zones, their outlines traced from the detail pictures' land, about 7,700 points, and which zone each 33-yard chunk is in) and `Art/line.blp`; the zone under the pointer is outlined and named, a click fits it, a right-click steps back out. Not yet tried in the game. The same day, a corner of land seen out at sea off Azshara was traced to the terrain (a rim of flat dry ground at height nought along three ocean tiles' edges) and is left out of the land (`without_slivers`); 38 detail pictures now.)
- **Build:** the finer pieces, the zone fills and borders, zone pointing, highlighting and click to fit.
- **Done when:** you can zoom from the world into any zone, and its border and name show.

G5 to G7 as first planned (the ground level, Routes on the globe, settling in) are now part of the road to parity below.

## The road to parity (written 2026-11-21)

**The target:** the globe can do everything you do on the game's world map, and shows everything our own addons put on that map. When it can, an option gives it the map key, and that version is 1.0, the first one that goes out. Until then it is built into your game only: no CurseForge project, no packaged release.

### What parity means

The list is taken from the world map's own code on Forever (`Blizzard_WorldMap.lua`, `AddStandardDataProviders` and `AddOverlayFrames`, in the `forever` branch of the interface source) and from what our addons add to the map today. Each row says where it lands.

**Getting around the map**

| The world map | On the globe | Milestone |
|---|---|---|
| World, continent and zone views; click a zone to open it; right-click to step out | One world you zoom through; click fits a zone; right-click steps out | G4, built |
| The row of places along the top (world, continent, zone) with their lists | A Go To list: continents, then their zones; picking one turns and fits the globe | G6 |
| A small window or the whole screen | A window you size by its corner, and full screen; both remembered | G6 |
| The map key; the gamepad | A key binding and gamepad controls for every action, from G6 on; the map key itself by option | G6, G14 |
| The zone's name; the name of the place under the pointer | The zone's name (built); the smaller place's name under it | G4, G9 |
| The zone's level range; your coordinates and the pointer's | The same, in the window's edge | G9 |
| Floors of a dungeon, a city's own map, a cave's | That place's flat map in the globe's window, with the same marks. (Forever has maps of its own only for the cities and the battlegrounds: no dungeons, caves or floors) | G12 |
| Which marks show (the tracking menu) | A Show menu with the same choices, plus ours | G11 |
| The quest log at its side | Tracker (Thread)'s list beside the globe | G8 |

**Marks the game draws**

| The world map | On the globe | Milestone |
|---|---|---|
| You | The arrow, turned to your facing | G1, built |
| Flight points | The same marks; known and unknown told apart | G7 |
| The map pin, the thing you are tracking, a link to a place in chat | Ctrl-click sets the pin as on the map; Shift-click links it; a link in chat turns the globe | G7, G14 |
| Quest areas, quest marks, quests on offer, hand-ins | The same, with Tracker (Thread)'s focus picked out | G8 |
| Towns, landmarks, dungeon and raid entrances, graveyards | The same icons, named, thinned out by zoom | G9 |
| Party and raid members; your corpse | The same | G9 |
| Fog of war | Fog over the land where you have not been (blank paper until 1.1.0) | G10 |
| Rare creatures, treasures, events | The same marks | G11 |
| The rest of the game's list (battlefield flags, vehicles, scenarios, dig sites, world quests, invasions and so on) | Each gone through in the audit below: drawn, or struck off with the reason | G14 |

**Marks our addons draw on the map**

| Addon | On the map today | Milestone |
|---|---|---|
| Routes (Thread) | The trail in its own colours (walking, tunnel, bridge, lift, drop, flight); boats and zeppelins; My Route's numbered stops with their menu; the focus button; Add Map Pin To My Route; recorded herb and ore nodes | G7 |
| MelloUI Route (Stitch) | The numbered stops of a trip (guide steps ahead, a quest run) | Struck off 2026-11-21: nothing new is built on MelloUI |
| Tracker (Thread) | Its list and My Route's editor, opened beside the map | G8 |
| Dungeon Journal (Stitch) | Its quest list, led by Routes and listed by Tracker | G8 |
| Immersive Plainsrunning | Counts the map as an open window (the interface comes back) | G6 |

**Other addons' pins** (quest helpers, guides, rare finders): shown through the shared pin library they register with (HereBeDragons), G13. An addon that draws on the game's map by a provider of its own (as HandyNotes does) is not seen.

### The milestones from here

Each one is built, checked offline (`tools/lua_globe.py`), then tried in the game, as before. **Keys and gamepad come with each milestone:** nothing new is mouse-only. Each milestone is a version: G5 is 0.1, G6 is 0.2, and so on up to G13 at 0.9; G14 is 1.0. (G10 to G14 were built in one run on 2026-11-21 and are 0.10.0 together. 1.0.0 is the same code once it has been played with: the release tool holds the globe back below 1.0.)

**G4, to finish.** The zones and the hand-made art are in the game but not yet looked at. Fix what the look shows (where the ink pieces sit, the paper, the outline, the smaller opening view), then commit.

**G5. The ground level** (0.1; built 2026-11-21, not yet tried in the game: the minimap's pictures were already fading in between 4 and 7 times the picture's size. What was jarring was their square tiles: every tile with a picture was drawn, sea and all, ending in hard edges against the parchment. Now `Zones.lua` lists the tiles with land (`land`, written by `python globe_art.py zones`: 1,146 of 1,796); each corner between tiles is worth 1 where a tile round it has land, and a tile shows as much as its corners say. So 1,496 tiles are drawn, 344 of them fading out to sea, and the open sea stays parchment. A piece can fade only straight across or down, so a tile fading toward a corner is cut smaller. Zoomed in, the tiles are found by their place round the middle of the picture, not by going through all of them.)
- **Build:** the minimap pictures in true colour, fading in under the parchment at the closest zoom.
- **Done when:** the step from our zone picture to the ground is not jarring.

**G6. The window and the controls** (0.2; built 2026-11-21, not yet tried in the game: the window sized by its corner, Full Screen, Go To, Escape, 12 key bindings (`Bindings.xml`), and the gamepad in `Pad.lua`: a frame over the window takes the sticks and six buttons while the globe is open and you are out of combat, and passes every other button on; the bindings are also listed with Console Port's own. To look at in the game: whether the frame gets the sticks at all with Console Port running, whether a passed-on button still does its binding, and full screen's frame rate.)
- **Build:**
  - the window sized by its corner, with a full-screen button; its size and place remembered. The picture's size stops being a fixed 600 points everywhere in `Globe.lua`.
  - a Go To list (continents, then their zones), and Escape closes the window
  - key bindings: turn, zoom in and out, Where I Am, step out, open and close
  - the gamepad (Console Port): a stick turns the globe, the triggers zoom, the middle of the picture is the pointer (the zone there is outlined and named), one button fits it and one steps out
  - Immersive Plainsrunning counts the globe as an open window
  - the release check leaves Globe (Thread) out until 1.0 (today it fails because the base README does not list it)
- **Done when:** everything G1 to G5 can do with the mouse can be done with keys and with a gamepad, at any window size, and full screen holds its frame rate.

**G7. Travel and your route** (0.3; built 2026-11-21, not yet tried in the game. The marks layer is `Marks.lua` (sources that list marks and lines when asked; crowding by rank; tooltips; a click; Next Mark by key or gamepad), and its pictures are our own (`Media/mark_*.tga`, drawn by `tools/globe_marks.py`). The interface for our other addons is a service of the base, `PatchwerkForever.Trails` (base 2.8.0): Routes (Thread) 1.3.0 offers its trail, crossings and nodes there (`Share.lua`), and `Travel.lua` draws them, with flight points from `C_TaxiMap.GetTaxiNodesForMap` on each continent's map. The pin does what the game's does: Ctrl-click sets it, a click on it tracks it or stops, a Ctrl-click on it clears it, a Shift-click links it. **Not built:** the numbered stops of a MelloUI Route (Stitch) trip; that Stitch publishes nothing another addon can read, so it needs a small change there first. To look at in the game: whether `GetTaxiNodesForMap` answers for a continent's map, whether the pin can be set on a zone's map from here, the marks' look and size, and the frame rate with a long trail.)
- **Build:**
  - **the marks layer**, which every later milestone uses: a mark is a place on the sphere, an icon, a tooltip and what a click does. Marks behind the ball are hidden; crowded ones are thinned by rank as you zoom out; lines share the outline's drawing.
  - **a small interface for our other addons** (through the base addon's link, as they reach each other now) to add marks and lines, so Routes draws on the globe as it draws on the map
  - flight points (known and unknown), boats and zeppelins across the sea
  - Routes' trail in its settings' colours and styles, a flight as an arc over the ball
  - My Route's numbered stops with their menu (Go Here First, Move Earlier, Move Later, Remove); the focus menu; Add Map Pin To My Route; a trip's numbered stops (MelloUI Route (Stitch))
  - recorded herb and ore nodes
  - the map pin: Ctrl-click sets it, as on the game's map; a click on it clears it; Shift-click links it in chat; the thing you are tracking is marked
- **Keys and gamepad:** a button drops the pin at the middle of the picture; marks near the middle can be stepped through and picked.
- **Done when:** with a destination set, the globe shows the whole way there at any zoom, and you can set, move and clear the pin without the game's map.

**G8. Quests** (0.4; built 2026-11-21, not yet tried in the game: `Quests.lua`. Each quest's place comes from the base's `Guides.QuestPlace`; the game's area shape is not drawn (it belongs to the game's own map frame), so the quest the route follows has a soft ring 90 yards across instead. Quests on offer come from `C_QuestLine.GetAvailableQuestLines` for the zone at the middle. A click on a quest sets the base's `Choice`, as a click in Tracker (Thread) does; it does not open the quest's details in the game's log. The Route button holds the focus list, Add Map Pin To My Route, Edit My Route and Tracker Beside The Globe; Tracker (Thread) 1.5.0 has `PatchwerkForever_Thread_Tracker_Dock` for that. To look at in the game: whether `C_QuestLine` gives offers on Forever, how the tracker's list sits beside the window and over full screen, and whether the ring reads as the place to be.)
- **Build:**
  - each quest's place: a numbered mark as on the map, and its area (see the unknowns: the game's own area shape may not be drawable off its map; then a soft ring round the place)
  - quests on offer and hand-ins
  - Tracker's focus picked out; a click on a quest's mark does what it does on the map (focus, track, open its details in the game's quest log)
  - Tracker (Thread)'s list docked beside the globe, with My Route's editor; a click on a quest in the list turns the globe to it
  - Dungeon Journal (Stitch)'s list shows the same way
- **Done when:** "where do I go for this quest" is answered on the globe alone.

**G9. Places, people and words** (0.5; built 2026-11-21, not yet tried in the game: `Places.lua`. Towns and landmarks from `C_AreaPoiInfo` and entrances from `C_EncounterJournal.GetDungeonEntrancesForMap`, for the zone at the middle, with the game's icons by name or by their place on its sheet of place icons. While dead, the corpse (`C_DeathInfo`) and the spirit healer; the game's own map marks no other graveyards outside battlegrounds, so neither does the globe. Party and raid members from `UnitPosition`, each value passed through `issecretvalue` first. Each terrain chunk's own area is now in `Zones.lua` (`areas`, and `ns.AREAS` with 831 English names for where the game gives none), so the smaller place is named under the zone. A zone's levels come from `C_Map.GetMapLevels` of the game's map found at the pointer, and are kept only when that map's name is the zone's. Coordinates are on the zone's map, else the continent's. To look at in the game: which of these functions Forever has (each is asked for with care, and a missing one shows nothing), the game's icons' size beside ours, and members' places in a fight.)
- **Build:**
  - towns, landmarks, dungeon and raid entrances and graveyards, with the game's icons and names, thinned by zoom
  - party and raid members, and your corpse
  - the smaller place's name under the pointer (each terrain chunk's own area, which `globe_art.py` already reads before rolling it up to its zone)
  - the zone's level range by its name; your coordinates and the pointer's
- **Done when:** the globe reads as a plain map: you can find a town, an entrance, your friends and your body on it.

**G10. Unexplored land** (0.6; built 2026-11-21 in 0.10.0, not yet tried in the game: `Explore.lua`, with `Covers.lua` and `Art/Covers/` written by `tools/globe_explore.py`. The game says what is discovered by picture: `C_MapExplorationInfo.GetExploredMapTextures` lists the pieces of a zone's map you have, each by where it lies on that map. The tool works out which of our 33-yard terrain chunks each piece of each zone's map stands for (by the piece's areas, then its rectangle on the map, then the nearest piece) and makes a soft patch of paper of that shape: 44 zones, one file each, 2.3 MB. The globe lays the patches of the pieces you have not found over its own land, on a layer of their own, so nothing is masked or cut. A piece you find fades away over 1.6 seconds; a zone with nothing found is one patch while zoomed out. A zone whose picture on this client is not the one the patches were made from (`C_Map.GetMapArtID`) is left uncovered rather than covered wrongly. To look at in the game: that the paper matches the map's paper, that on a real character the right land is clear, and the edge between a found piece and one not found.)
- **Build:** land you have not discovered left as blank paper, filling in as you explore, with an option to show everything.
- **Done when:** a new character's globe is mostly blank paper with coasts, and walking into a new place fills it in without reopening the window.
- This is the least certain milestone (two unknowns below: how the game tells us, and how to blank part of a bent picture).

**G11. Rares, treasures and the Show menu** (0.7; built 2026-11-21 in 0.10.0, not yet tried in the game: `Rares.lua` draws the game's vignettes (`C_VignetteInfo`: what the minimap marks near you) with the game's icon by name, grey when dead. `Show.lua` is the Show menu: checkboxes over the same settings as the options page, behind a button and a key (Show Menu). To look at in the game: whether Forever has any vignettes at all.)
- **Build:** the game's marks for rare creatures, treasures and events; a Show menu choosing which kinds of mark are drawn (the game's choices, plus the trail, My Route, nodes and other addons' pins).
- **Done when:** every kind of mark can be turned off and on, and the choice is remembered.

**G12. Indoors** (0.8; built 2026-11-21 in 0.10.0, not yet tried in the game: `Flat.lua`. Forever has no maps of dungeons or caves and no floors. The only maps of their own that the globe did not already draw are the six cities (1453 to 1458) and the three battlegrounds (1459 to 1461), so there is no floor list and an entrance's mark opens nothing. A city's or battleground's map is the game's pictures by number (`C_Map.GetMapArtLayerTextures`), flat in the globe's picture. The marks layer lays its marks through the map's rectangle in the world, so every kind of mark shows on a city's map. A battleground is no part of the globe's world: there you, your group, its places, flags and vehicles are put on the map itself (`ns.FlatPoints`). It opens where you are in one (the City Maps setting), from Go To, or by a click on a city that fills the picture; a right-click, Step Out, zooming out or the Globe button goes back to the globe at that place. With keys, Next Mark moves the cross from mark to mark. To look at in the game: a city's map against the marks on it, and a battleground.)
- **Build:**
  - a flat view in the same window, for places with a map of their own (a dungeon's floors, a cave, a city's map): the game's picture by number, the same marks layer, a floor list
  - going in switches to it when you are inside one; stepping out returns to the globe at the entrance
  - an entrance's mark on the globe opens its flat map
- **Done when:** you never need the game's map to see where you are indoors.

**G13. Other addons' pins** (0.9; built 2026-11-21 in 0.10.0, not yet tried in the game: `Pins.lua`. Of the addons installed here, RareScanner and RXPGuides bring HereBeDragons-Pins-2.0 through LibStub, and Questie keeps a copy to itself (`QuestieLoader:ImportModule('HBDPins')`). Both are followed with `hooksecurefunc` on the library's four world-map calls; nothing inside it is touched, and a newer copy that replaces the calls is followed again. A pin is drawn with its own frame's picture, colour and size. Its tooltip is its own OnEnter, moved to the pointer; a click is its own OnClick. To look at in the game: each of those three addons' pins, tooltips and clicks, which were made for the game's map and may not all work off it.)
- **Build:** pins that addons register through HereBeDragons show on the globe (and on the flat view), with their own tooltips and clicks where the library gives them; a Show menu entry for them.
- **Done when:** the pin addons you run show the same pins on the globe as on the game's map.

**G14. Parity, the map key and 1.0** (built 2026-11-21 in 0.10.0, not yet tried in the game, except what is listed as left. The audit is the section below. The map key is `MapKey.lua`: a binding of ours laid over the keys of the game's Toggle World Map (`SetOverrideBindingClick`, outside combat), a World Map button on the globe and a Globe button on the game's map, and `OpenWorldMap` followed so that a map link or "show on map" turns the globe. The options page is in groups. **Struck off:** detail pictures in load-on-demand addons (see the decisions of the run to parity). **Left for after the test:** the base README's list, the CurseForge project, the version 1.0.0 and the release. To look at in the game: the key with Console Port's own bindings, whether closing the game's map from the hook is clean, and where the Globe button sits on the game's map.)
- **Build:**
  - **the audit:** every entry of the world map's list on Forever checked off against the tables above, drawn or struck off with the reason
  - **the map key:** an option, off by default, that makes the map key open the globe; a button on each takes you to the other; the game's "show on map" and links in chat turn the globe when the option is on
  - each continent's detail pictures in a load-on-demand addon of its own, as Routes' map data is
  - the options page, the icon, the README, the base README's list
  - the CurseForge project (which you make), and the release
- **Done when:** you can play a week with the option on and never open the game's map for want of something.

### The audit (G14, 2026-11-21)

Every entry of the world map's own list (`WorldMapMixin:AddStandardDataProviders` and `AddOverlayFrames` in `Blizzard_WorldMap.lua`, the `forever` branch) against the globe. It was done from the game's code and the globe's, not by play: Forever's client carries the code of the game's other versions, so that an entry is in the list does not say Forever's world has anything for it.

**What the map draws**

| The world map's entry | On the globe |
|---|---|
| MapExploration | Drawn: fog over what is not discovered (G10) |
| MapHighlight, AreaLabel | Drawn: the zone under the pointer outlined; its name, its levels, the smaller place (G4, G9) |
| GroupMembers | Drawn (G9) |
| Quest, QuestOffer | Drawn (G8) |
| QuestBlob | Another way: a soft ring round the place. The game's area shape is a frame of its own that belongs to the game's map |
| DeathMap | Drawn: your corpse and the spirit healer (G9) |
| FlightPoint | Drawn (G7) |
| WaypointLocation, SuperTrackWaypoint | Drawn: the map pin, tracked or not (G7) |
| AreaPOI, DungeonEntrance | Drawn (G9) |
| AreaPOIEvent | Drawn, added with the audit: an event's places are listed with the others (`C_AreaPoiInfo.GetEventsForMap`) |
| Vignette | Drawn (G11) |
| Gossip | Drawn, added with the audit: the flag a city guard's directions put on the map (`C_GossipInfo.GetPoiForUiMapID`) |
| BattlefieldFlag, Vehicle | Drawn, added with the audit, on a battleground's flat map (`C_PvP.GetBattlefieldFlagPosition`, `GetBattlefieldVehicles`) |
| MapLink | Not needed: a mark on one map that opens another. The globe is one world |
| SelectableGraveyard | Not drawn: choosing where to rise from a battleground's map. Its graveyards show as places; the choosing is not built |
| EncounterJournal | Struck off: boss marks on a dungeon's map, and Forever has no dungeon maps |
| EventOverlay, BonusObjective, Scenario, ContentTracking, Invasion, PetTamer, DigSite, GarrisonPlot, DelveEntrance, Banner, ContributionCollector, QuestSession, DragonridingRace, NeighborhoodMap, FogOfWar, WorldQuest | Struck off: each belongs to a part of the game's other versions (pet battles, archaeology, garrisons, invasions, world quests, delves, housing and so on) that Forever's world does not have, as far as its maps and our play show. Should one ever show on the game's map here, it is a mark to add |
| PlunderstormCircle, WoWLabsArea, Debug | Struck off: other games' rules, and the game masters' client |

**What sits over the map**

| The world map's frame | On the globe |
|---|---|
| The row of places (NavBar) | Go To (G6) |
| The tracking options button | The Show menu (G11) |
| The map pin button | Ctrl-click, or Set Or Clear The Map Pin At The Middle by key or gamepad (G7) |
| The coordinates panel | Coordinates at the lower edge (G9) |
| The side panel toggle (the quest log) | Tracker (Thread)'s list beside the globe (G8) |
| The floor list | Struck off: Forever has no floors |
| The bounty board, the action button, the zone timer, the threat frame, the activity tracker | Struck off: parts of the game's other versions |

**What a click does that the globe does not:** a click on a quest's mark does not open that quest in the game's quest log (it sets what the route follows, as a click in Tracker (Thread) does).

### Not needed for parity

Left out on purpose; each can be asked for later.
- Race courses' checkpoints on the globe (Races (Thread) puts nothing on the world map today).
- Relief you can tilt, a night side, or anything else a real globe program has and the world map has not. (Cloud shadows, candlelight and the turning Maelstrom came in with 0.10.0, when light and movement were asked for.)
- Land the game does not have.

## Decisions taken (2026-11-19)

1. **Art source:** tools + hand-made. Land, coasts, relief and zone borders are made by our tools from the game's terrain. The paper grain, compass rose, sea serpents, ships and the brass ring are made by hand or with an image tool and laid over it.
2. **Image libraries:** install Pillow and numpy, for the tools only.
3. **Where it opens:** both. Its own window (`/globe`, a key binding), and a button on the world map that swaps its top level (Azeroth) for the globe.
4. **Layout:** the game's. Kalimdor west, the Eastern Kingdoms east, Zephra's Isle in the southern sea between them. The rest is open sea with decorations, and no invented land.
5. **Ground level:** the minimap pictures **in true colour**, as the minimap shows them: no greying, no tint. They fade in under the parchment at the closest zoom.
6. **Size:** about 10 MB is fine: the world picture about 1 MB, each continent's detail about 4 to 5 MB, loading only when you zoom there.
7. **Frame:** a desk globe, with a brass meridian ring and a stand round the ball. Both are hand-made art.

## Decisions taken (2026-11-21, the parity interview)

1. **Parity with:** the game's world map, plus what our own addons put on it.
2. **Its place beside the map:** its own window and a button on the world map while it grows. At parity, an option gives it the map key, with the game's map one click away. (This widens decision 3 of 2026-11-19.)
3. **Marks needed for parity:** all of them: quests, travel, people, places, unexplored land, rares and treasures, other addons' pins, the map pin and links in chat.
4. **Indoors:** the place's own flat map inside the globe's window, with the same marks; a step out returns to the globe.
5. **The side panel:** Tracker (Thread)'s list beside the globe. No quest log of the globe's own; details open in the game's.
6. **Other addons' pins:** through the shared pin library (HereBeDragons). The game's map is not mirrored pin by pin, and there is no separate pin interface for other authors.
7. **Order:** travel and your route first after the ground level.
8. **Window:** sized by its corner, with full screen.
9. **Size:** about 15 MB, with each continent's detail loaded on demand. (This replaces the 10 MB of decision 6 of 2026-11-19.)
10. **First release:** only at parity, as 1.0. Nothing goes out before.
11. **Keys and gamepad:** with each milestone, not in one pass at the end.

## Decisions taken (2026-11-21, the run to parity)

Taken while building G10 to G14 in one run, at "finish off the remaining work before the next test … everything else up to" setting the CurseForge project up, with "any immersion like visual effects we could apply to the map view".

1. **One version for the run:** 0.10.0. The version 1.0.0, the base README's list, the CurseForge project and the release wait for the test.
2. **Detail pictures stay in the addon.** They were to go into a load-on-demand addon for each continent, as Routes' map data is. That data is Lua tables, which cost memory once loaded; a picture is read from its file when a piece first shows it, so the pictures of a continent you do not look at are not loaded wherever their files lie. A split would move files and gain nothing. The addon is 14.4 MB, under the 15 MB agreed.
3. **A MelloUI Route (Stitch) trip's stops are struck off.** Nothing new is built on MelloUI.
4. **Indoors is the cities and the battlegrounds.** Forever has no other maps of places.
5. **Light and movement** (asked for as immersion): candlelight that follows the game clock, a shine on the ball, the Maelstrom turning, cloud shadows, the opening, a ring from your place, the map's sounds. Each has a setting and is on as it comes. All are our own pictures (`tools/globe_fx.py`) or the game's sounds by name.
6. **The Map Key Opens The Globe is off as it comes**, as decided in the interview. Everything else new is on.

## Unknowns to try first (cheap, before the art)

- **BLP:** a BLP written by our own `blp.py` loads in the game (DXT1 and DXT5).
- **Zone numbers:** the zone number in each terrain chunk matches `C_Map.GetAreaInfo` names on Forever.
- **Fades:** `SetGradient` alpha on bent pictures (it worked for the parchment edges).
- **Masks:** whether masks follow bent pictures. Probably not; the plan does not need them.
- **Memory and speed:** with about 600 pieces and some 100 pictures loaded.

## Unknowns on the road to parity (to try before the milestone that needs them)

None of these has been tried on Forever. The function names are where to look first, not promises that they exist here.

- **From a map's percent to a place on the globe (G7).** Almost every mark comes as a map and a percent across it (flight points, quest marks, icons, other addons' pins). Routes already turns these into world yards; the globe needs the same for every zone map. Try `C_Map.GetWorldPosFromMapPos` against Routes' own figures.
- **Resizing (G6).** Full screen is about four times the picture: how many pieces, and how many milliseconds.
- **The game's quest areas (G8).** The map draws them with a frame type of its own. Try whether one can sit anywhere but on a flat map; if not, the globe shows a place and a ring.
- **Quests on offer (G8).** What Forever's map shows for them, and from which function.
- **Others' positions (G9).** `UnitPosition` for party and raid members outdoors, and whether it comes back secret in a fight (secret values exist on Forever: anything read must go through `issecretvalue` first). Built so that a secret or missing place shows no mark; still to be seen in a fight.
- **G6 to G9 in the game.** All four were built in one run on 2026-11-21 and checked only offline (`tools/lua_globe.py`). Each milestone's note above lists what to look at first.
- **G10 to G14 in the game.** The same: built in one run on 2026-11-21 (0.10.0), checked only offline. What was found out for each unknown below is in its milestone's note; whether it holds in the game is still to be seen.

## Added after the first look (2026-11-21, 0.5.1)

- **The Deeprun Tram.** Routes (Thread) knew only the boats and zeppelins of the game's taxi table. The tram runs through a map of its own (369), entered at a door in each city, and each door is one of the game's area triggers: 2173 in Stormwind, 2175 in Ironforge, their places read from the game's `AreaTrigger` table by `tools/crossings.py` (`BY_HAND`; which trigger leads where is told by hand, since only the server knows). It is a crossing of kind `tram` in `Crossings.lua`, for the Alliance, so the planner takes it ("Take the tram from Stormwind to Ironforge") and the globe marks both stations with a dashed line between. Guessed: a minute's ride, half a minute's wait, and the walk through each city from the nearest ground the planner knows. **Others like it** go in the same list once we know which they are: the game's files do not say where a door leads, so each needs naming (and, for a lift, marking in the game with `tools/marks.py`).
- **Lifts.** Asked for as "others like the tram". A lift's platform is moved by the server, so no file says a lift runs somewhere; but the Great Lift and the lift of Freewind Post ride in a tower that is a building model (file 112647, placed twice on Kalimdor), with a deck at the top and one at the bottom. `tools/lifts.py` finds each placing of a model named in its `TOWERS`, takes the two largest flat floors as the decks and the walkable ground nearest each as the ends, and writes the lines into a part of its own in `tools/hand_links.txt` (`python lifts.py write`, then `links.py 1`, `pack.py 1`). The 30 seconds for wait and ride are a guess. With them Freewind Post is reached at all (it was not), and Crossroads to Gadgetzan is 20.0 minutes, was 24.5. For showing, `pack.py crossings` lists every lift of `hand_links.txt` in `Crossings.lua` (`ns.Lifts`: these two by name, Thunder Bluff's four with none), Routes offers them through the base's new `Trails:Lifts()`, and the globe marks them (`mark_lift`) from the zoom flight points show at. The Undercity's lifts are still unknown: they lead to floors inside the city, which the planner does not have.
- **The Maelstrom.** An ink whirlpool at the middle of the Great Sea (latitude 0.05, longitude 0, 0.40 across), one more ink piece of the world (`Art/decor_maelstrom.blp`). `tools/globe_art.py` draws it itself (`maelstrom_drawing`); a hand-made `art/PatchwerkForever_Thread_Globe/globe/maelstrom.png` is used in its place when there is one (the prompt is in `art/PROMPTS.md`). Its name is under it, and The Great Sea's name moved south.
- **What is explored (G10).** How the game says a place is discovered (`C_MapExplorationInfo`: by picture, or by area at a position), and whether that can be matched to our terrain chunks' areas. *Found:* by picture, and each picture's areas and rectangle are in the game's tables, so it can be matched.
- **Blanking land on a bent picture (G10).** Masks probably do not follow bent pictures. Two ways to try: plain paper pieces laid over blocks of unexplored chunks (cheap, blocky edges), or one small see-through picture per place (smooth, several MB). *Taken:* the second, 2.3 MB.
- **Rares and treasures (G11).** Whether Forever shows any on its map, and `C_VignetteInfo` for their places. *Found:* the functions are there; whether the world has any is for the game to show.
- **Flat maps by number (G12).** `C_Map.GetMapArtLayerTextures` for a dungeon's or city's pictures, drawn in our window. *Found:* cities and battlegrounds only.
- **The pin library (G13).** Which pin addons exist on Forever and whether they use HereBeDragons; whether its add and remove calls can be followed without touching its insides; what of a pin (icon, tooltip, click) can be shown in a second place. *Found:* RareScanner, RXPGuides and Questie (a copy of its own) use it; its calls can be followed; a pin's picture, tooltip and click are its frame's own.
- **The map key (G14).** Giving the key to the globe without the game's "action blocked" errors (a binding of our own set over the key, outside a fight), and following the game's own "show on map" calls. *Built that way; untried.*
- **Memory (G14).** With 15 MB of pictures and detail loaded on demand. *Decided:* no split (decision 2 of the run to parity); the game's memory figure for the addon is still to be read.

## Added after 0.10.0 was built (2026-11-21, 0.11.0)

Asked for before the test of 0.10.0: prompts for variations of the drawings, the drawings "a little opaque" (asked which way: both a wash under them and the ink a little faded), and an aging effect.

- **Variations of the ink drawings.** Where the same kind of drawing stands twice on the globe, the second is made from `<kind>2.png` when there is one and the third from `<kind>3.png` (`decor_sources` in `tools/globe_art.py`); without one, the second uses the first's picture. Every second one of a kind faces the other way: `flip = true` in `Art.lua`, and the addon mirrors the picture, so no second file is written for that. The second serpent is the hand-made `serpent2.png`. Places are kept on the sea for a third ship, a kraken, a whale and a wind, each on the globe only once its picture is made. The prompts are in `art/PROMPTS.md`, under Variations.
- **The drawings' wash and fade.** An ink piece was the ink alone, clear everywhere else, so the sea's mottling showed through a serpent's body. Now the tool works out the drawing's body (what its outlines close in, as far as that is near ink, and wherever the ink is dense) and lays a pale wash of bare paper under it (`WASH_SHOWS` 0.34), and the darkest ink shows at 0.80, was 0.92 (`INK_SHOWS`). `tools/world/look_decor.png` shows them on the sea's colour.
- **Aged paper.** Two pictures of our own from `tools/globe_fx.py`, on two layers of the globe over the map, the ink and the blank paper (`Effects.lua`; the setting Aged Paper, on as it comes). `age.blp` is the whole sphere at once, 512 x 256, made on the sphere itself: yellowed varnish, grime at the poles, 13 water stains with broken tide lines, 16 clusters of foxing, and paler rubbed patches, most along the equator. `wear.blp` is a square of 256 that repeats, laid twelve times round: hairline cracks, specks, and at its edge the seam between two strips of paper, set half a strip along so that no seam runs down the middle of a continent. The stains fade out between 3.5 and 6 times the picture's size, the small things between 1.8 and 3.6 (their pixels would show). Cost: with the whole globe in view, about 260 pieces more (193 before). `tools/world/look_age.png` shows both. To look at in the game: how strong it is over land and sea, whether the cracks' repeating is seen, and the drawing time in the numbers under the globe.
- **Size:** 15.0 MB with these. Each new variation drawing adds about 0.35 MB. The 15 MB agreed was reached; the user, asked, said "it may grow" (2026-11-21), so there is no fixed limit now: say what a thing adds when it is large.
- **A ring border in place of the stand** (asked for 2026-11-21, as the ring the world sits in on the game's logo): a prompt in `art/PROMPTS.md` for a golden ring of our own in that manner, saved as `border.png`. `ring_picture` in `tools/globe_art.py` uses it before `ring.png`, and the globe's layout follows the picture (`ns.RING`), so nothing else changes. Not made yet.
- **The family's names turned round** (2026-11-21): the name first, the kind after it in brackets, "Patchwerk Forever: Globe (Thread)". Titles, options pages, READMEs, changelogs, tools and these notes all say it that way now; folders, commands and saved data are unchanged.

## 1.0.0, made ready for release (2026-11-21)

Asked "prepare for release to curseforge", the user said the Globe is part of it, as 1.0.0. So:

- The TOC says 1.0.0 and no longer "Not released yet"; the changelog's 1.0.0 entry describes the whole addon, since it is what CurseForge shows for the first file. `tools/release.py` no longer holds it back (`"held"` is gone), so the base's README must name it, and does.
- Now named in public: the base's README and 2.8.0 entry, Routes' and Tracker's READMEs and pending entries, the repository's README.
- **Icon and logo:** the prototype's blue ball is replaced by a patch of the family's kind, a globe on its stand (`globe` in `tools/art.py`). A prompt for a painted one is in `art/PROMPTS.md`; an `art/PatchwerkForever_Thread_Globe/icon.png` takes its place.
- **The CurseForge project is the user's to make.** Its fields are in `release/NEW-PROJECTS.md`. Once its id and slug are in `tools/curseforge.json`, `python upload.py globe` sends the file.
- **Not there yet:** pictures for the listing (screenshots are taken in the game), and `border.png`, so the stand is still what is drawn.

## 1.1.0 (2026-11-22)

- **The ring**: `border.png` (a brass ring with the four compass points, no stand) took `ring.png`'s
  place. `tools/globe_art.py` cuts it as before and the globe lays itself out from `ns.RING`; the
  suite works out what to expect from those numbers, with or without a stand. Where this document
  speaks of the ring and stand, the stand is now only there when the picture has one.
- **Zones colored by level** (`Wash.lua`): the whole-zone paper patch of the Covers, tinted by the rule
  the hover text uses, in a layer of its own over the map and the blank paper and under the wear, the
  marks and the names. Levels are asked a few zones at a time while the globe is open. Zones with no
  cover patch (the cities, a few small areas) get no wash. Off by default.
- **Guild members and friends** (`Social.lua`): a source of marks, one a zone with a count, from
  `C_Club` (the guild) and `C_FriendList`. Both off by default.
- Checked offline only.

### Borders and blank paper, smoothed (2026-11-22)

The game knows a place's zone, and its piece of a zone's map, only by the 33-yard chunk, so every edge taken
from it is a staircase. Three things were stepped and are now smooth, all in the tools:

- `globe_art.py`: `smooth_zones` blurs each zone a little and gives a pixel to the strongest (`ZONE_SOFT`),
  before the borders are painted and the outlines traced. An outline is then rounded along its length
  (`rounded`, `RING_ROUND`) and written four points to a pixel (`FINE`; `per` in Zones.lua is 256).
- `globe_explore.py`: a piece's paper has two pixels a chunk (`FINE`), its edges rounded the same way
  (`rounded`, `EDGE`), reaching a little past its edge so two leave no seam (`GROW`, `FADE`), and the
  coast is the detail pictures' own land (`fine_land`). The whole zone's sheet has a pixel a chunk.
  Art/Covers went from 2.3 MB to 7.5 MB. Nothing in the addon's Lua changed for any of this.

### Fog for blank paper, and cheaper drawing (2026-11-22)

Asked for by the user the same day: "adjust the Paper for the fog of war to look like fog instead of
paper", and "frame drops while interacting".

**The fog** (`globe_explore.py`, `Explore.lua`; the setting is now **Fog Of War**, its key still
`globeExplore`).

- One field of billows is made for each continent (`mist`: three sizes of blurred noise, `BILLOWS`, lit
  a little from one side, `RELIEF`; pale blue-grey, `FOG_LIGHT` to `FOG_DEEP`), so the fog runs on
  unbroken from piece to piece and zone to zone. A piece's picture is its part of that: whole over the
  piece, thinning out to mist for a few chunks past its edge (`MIST`, further where the fog is thick),
  and thinning over the water at the shore (`SHORE`).
- A pixel a chunk again (`FINE = 1`): fog has no edge to keep sharp. Art/Covers is 5.3 MB.
- A zone's file now holds three kinds of cell: `whole` (the fog over the whole zone), `shape` (the
  zone's flat shape in paper's colour, which only the level wash uses: `Wash.lua` tints it), and the
  pieces.
- A zone of which nothing is discovered is under its one sheet at every zoom (it gave way to its pieces
  close in, which showed the mist of each piece's edge as seams within a zone). That is one picture a
  zone for most of a new character's world.
- The fog of an undiscovered piece reaches a few chunks into a discovered neighbour, as mist.

**The drawing** (`Globe.lua`, `Effects.lua`, `Explore.lua`). Measured first, in the offline stand-in with
a sampling hook: three quarters of the time went to deciding what is seen and how finely to cut it
(`Visit` and what it calls), and the aged paper, the wear and the cloud shadows tripled the number of
pieces zoomed out. What was done:

- Each layer is cut only as finely as it needs (`CURVES`: the soft overlays, the fog and the wash bend
  with far fewer pieces than the map).
- A piece keeps how far it reaches (`reach`, `chord`), so one wholly behind the globe or out of the
  window is passed over with its whole tree at once; a zone's fog likewise (`G.InView`).
- A corner is worked out once a drawing and shared by the pieces that meet at it (`Corner`); the eye's
  basis is nine numbers, not a table (`Look`); no tables are made while drawing.
- The cloud shadows are walked only while they are drawn (`state.clouds`).
- Pieces that hold no texture any more are forgotten now and then (`Thin`, in `Tidy`).

In the stand-in: the whole globe 857 pieces to 509 and about 9.4 ms a drawing to 5.5; a continent 1,578
to 836 and 12.5 ms to about 5.5; a zone 6.5 ms to about 3.3; closer in 3.8 ms to 1.0. Not measured in
the game.

### Thin fog, and the painted map as the fog of war close in (2026-11-22)

The user, on seeing the fog in the game: it "still doesnt look great. set the opacity of the fog down to
maybe 30%", and "I want the custom map to also be part of the fog of war, but only at close zoom where
the globe transitions to the ground maps". Read as: zoomed in, undiscovered land keeps the painted map
where discovered land shows the minimap's pictures.

- **Fog Opacity** (`globeFog`, a slider under Fog Of War, 10% to 100%, 30% as it comes): the alpha the
  fog's patches are drawn with (`Explore.lua`). The pictures are as they were.
- **The ground kept off undiscovered land.** A ground picture is the game's own file, so it cannot be cut
  to a piece's shape; it can only be shown more or less, evenly between corners (`Fade`, as a tile at
  the coast already fades out to sea). So `globe_explore.py` writes, in Covers.lua (`ns.COVER_POINTS`),
  whose piece the land is at each corner of a quarter of a terrain tile (`POINTS = 4`; the owner most of
  the 16 chunks round the corner have). `Explore.lua` gives each ground picture a `Fade` that is 1 at a
  discovered corner (or no piece's) and 0 at an undiscovered one, and a `Cut` that says of each piece of
  the picture: none of it shows (left out, no texture), cut it smaller (until it lies between four
  corners), or cut it smaller while large (it fades toward one corner). `Globe.lua` asks `pic.Cut` once
  a piece (`p.cut`) and has `G.Forget(pic)` to cut a picture afresh when what is discovered changes.
  The edge of the ground is so a soft one about 133 yards wide, near the fog's own mist.
- Only pictures for which something changed are touched (`pic.veil`, a bit a corner), and never within
  a drawing (from the 'frame' hook). Parchment style only; with Fog Of War off the ground is as before.
- A piece discovered while you look: its fog fades over 1.6 s, its ground comes in at once.

## Rules this keeps

- No picture of the game's in the addon; the game's pictures by number only.
- Our code and pictures under the MIT License.
- Plain, standard words in the game.
- Nothing from other addons (Curator's technique was studied; none of its code is used).
