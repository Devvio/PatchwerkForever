# Icon prompts

Prompts for an image generator, one for each addon's icon, in the style of the art made for the first Patchwerk Forever listing (the stitched ogre's head, the cog on a patch of hide, the workshop banner).

## The style, in words

- **Painting:** hand-painted, stylised fantasy game art. Chunky, faceted shapes; thick, visible, square-edged brushstrokes; a bold dark outline round everything; hard highlights along the edges.
- **Colours:** sickly olive-green hide, plum-purple hide, grey stone-like hide, rust-orange leather stitches, bone-white, and one accent that glows: teal-cyan. A teal rim light on the edges of the main object.
- **Background:** deep violet-purple, painterly, darker toward the corners.
- **The icon's own pattern** (from the cog icon): a ragged square patch of hide, pinned at its four corners by big cross-stitches, with one large glowing teal emblem set into its middle.

## How the family is told apart

| Track | The patch | The corner stitches |
|---|---|---|
| The parent | olive-green hide | rust-orange leather |
| Stitch (for other people's addons) | two hides sewn together down the middle, olive-green and plum-purple, with a seam of copper stitches | rust-orange leather |
| Thread (our own tools) | warm tan parchment-leather, like an old map | glowing teal thread |

Only the emblem in the middle changes within a track.

## Using them

1. Give the generator the prompt, and attach `02-addon-icon.png` (the cog icon) as a style reference if it takes one. That does more for matching the style than any wording.
2. Ask for a square picture, 1024 x 1024.
3. Look at it small before keeping it: the game shows it at about 32 to 64 pixels. If the emblem does not read at that size, ask again for a "bolder, simpler emblem".
4. Save it as `art/<addon folder>/icon.png`. The next `python build.py` makes it the addon's icon; `python art.py` makes the CurseForge logo from it.

## The prompts

### Patchwerk Forever (the parent): `art/PatchwerkForever/icon.png`

The cog icon made for the first listing already is this one. To make it again:

```text
Hand-painted stylised fantasy game icon. A ragged square patch of thick olive-green hide, its edges torn and slightly curled, a few small holes in it, pinned at each of its four corners by a big chunky cross-stitch of rust-orange leather cord. Set into the middle of the patch, a large glowing teal-cyan cog wheel, like an inlaid gem with fine cracks and a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Console Port (Stitch): `art/PatchwerkForever_Stitch_ConsolePort/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch made of two thick hides sewn together down the middle, olive-green on the left and plum-purple on the right, joined by a vertical seam of chunky copper stitches; edges torn and slightly curled; pinned at each of its four corners by a big cross-stitch of rust-orange leather cord. Set into the middle, across the seam, a large glowing teal-cyan game controller: a simple gamepad silhouette with two grips, a plus-shaped directional pad and two round buttons, like an inlaid gem with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### MelloUI (Stitch): `art/PatchwerkForever_Stitch_MelloUI/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch made of two thick hides sewn together down the middle, olive-green on the left and plum-purple on the right, joined by a vertical seam of chunky copper stitches; edges torn and slightly curled; pinned at each of its four corners by a big cross-stitch of rust-orange leather cord. Set into the middle, across the seam, a large glowing teal-cyan emblem of a game menu: a rounded window frame holding three thick horizontal bars stacked one above the other, like an inlaid gem with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### MelloUI Route (Stitch): `art/PatchwerkForever_Stitch_MelloUIRoute/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch made of two thick hides sewn together down the middle, olive-green on the left and plum-purple on the right, joined by a vertical seam of chunky copper stitches; edges torn and slightly curled; pinned at each of its four corners by a big cross-stitch of rust-orange leather cord. Set into the middle, across the seam, a large glowing teal-cyan signpost: one upright post with two arrow-shaped boards pointing opposite ways, like an inlaid gem with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Routes (Thread): `art/PatchwerkForever_Thread_Routes/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch of warm tan parchment-leather, like a scrap of an old map, its edges torn and slightly curled, pinned at each of its four corners by a big cross-stitch of glowing teal-cyan thread. Across the middle of the patch, a large glowing teal-cyan trail: a winding dotted line that starts at a small round dot in the lower left and ends at a bold X in the upper right, stitched into the leather with a soft glow. A bone sewing needle trailing a loop of glowing teal thread is tucked through one edge. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Sparkle (Thread): `art/PatchwerkForever_Thread_Sparkle/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch of warm tan parchment-leather, its edges torn and slightly curled, pinned at each of its four corners by a big cross-stitch of glowing teal-cyan thread. Set into the middle of the patch, a large glowing teal-cyan four-pointed sparkle, a twinkling star with long thin points, with two much smaller sparkles beside it, like inlaid gems with a bright inner glow and a few tiny motes of light drifting off them. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Tracker (Thread): `art/PatchwerkForever_Thread_Tracker/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch of warm tan parchment-leather, its edges torn and slightly curled, pinned at each of its four corners by a big cross-stitch of glowing teal-cyan thread. Set into the middle of the patch, a large glowing teal-cyan checklist: three thick horizontal bars stacked one above the other, each with a small mark at its left end, the top two marks bold ticks and the bottom one an empty ring, like inlaid gems with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Dungeon Journal (Stitch): `art/PatchwerkForever_Stitch_DungeonJournal/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch made of two thick hides sewn together down the middle, olive-green on the left and plum-purple on the right, joined by a vertical seam of chunky copper stitches; edges torn and slightly curled; pinned at each of its four corners by a big cross-stitch of rust-orange leather cord. Set into the middle, across the seam, a large glowing teal-cyan open book seen from the front, its two pages fanned, and rising out of the pages a short dotted trail that bends once and ends in a bold exclamation mark, like inlaid gems with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Immersive Plainsrunning (Thread): `art/PatchwerkForever_Thread_Plainsrunning/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch of warm tan parchment-leather, its edges torn and slightly curled, pinned at each of its four corners by a big cross-stitch of glowing teal-cyan thread. Set into the middle of the patch, a large glowing teal-cyan cloven hoofprint, two bold rounded halves, leaning forward as if mid-stride, with three long speed streaks trailing behind it to the left and two short gusts of wind curling past it, like inlaid gems with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Globe (Thread): `art/PatchwerkForever_Thread_Globe/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch of warm tan parchment-leather, like a scrap of an old map, its edges torn and slightly curled, pinned at each of its four corners by a big cross-stitch of glowing teal-cyan thread. Set into the middle of the patch, a large glowing teal-cyan desk globe on a small round stand: a round ball crossed by a few bold curved lines of latitude and longitude, tilted a little on its axis, held in a half ring, like inlaid gems with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

## If a result drifts

- **Too detailed to read small:** add "flat, bold emblem, no small details inside the emblem".
- **Wrong colours:** name them again at the start: "olive-green, plum-purple, rust-orange, glowing teal-cyan, violet background".
- **It wrote letters:** add "absolutely no writing or runes".
- **The patch became a shield or a badge:** add "a soft, floppy, torn piece of hide, not metal, not a shield".
- **The whole family should match:** make them all in one sitting with the same reference picture, and keep the first good one as the reference for the rest.

---

# Globe (Thread): the globe's own art

Not icons: the pieces the globe's world picture is made of, laid over the land and sea that `tools/globe_art.py` draws from the game's terrain. The look is the **world map on parchment**, not the icons' look: an old hand-drawn map, warm parchment, sepia and dark-brown ink. Until a piece is there, the tool draws a plain stand-in.

Save each as `art/PatchwerkForever_Thread_Globe/globe/<name>.png`, then run `python globe_art.py world` in `tools/`. They go in the `globe` folder, not beside the icon: a PNG beside the icon is made into a picture in the addon as it is, and these are only what the tool works from.

## How each is used

- **Ink pieces** (the compass rose, the serpent, the ship, the Maelstrom) become pictures of their own on the open sea: the darker the drawing, the more ink shows, and **white is clear**. So they must be dark ink on **pure white**, with no paper colour, shading or vignette of their own. The tool fades the ink a little and lays a pale wash under the drawing's body by itself: what the outlines close in, and where the hatching is dense. So keep the outlines closed, and keep stray marks away from the drawing.
- **Variations** of an ink piece: where the same kind stands twice on the globe, the second is drawn from `<kind>2.png` and the third from `<kind>3.png`. See Variations below.
- **The paper** is laid over the whole world as its grain and stains: mostly its light and dark, with a little of its colour. It should **tile**: its left edge continuing into its right and its top into its bottom (the tool blends the edges to hide what join is left).
- **The ring and stand** sit round the ball in the window, on **flat magenta (#FF00FF)**, which the tool cuts away. The tool finds the ring's hole and makes it a true circle.
- **A ring border** with no stand can take the ring and stand's place: saved as `border.png`, the tool uses it before `ring.png`, and the globe lays itself out by it (with no stand under it, the ball sits in the middle of the window). Take `border.png` away again and the stand is back.

## The prompts

### Paper: `art/PatchwerkForever_Thread_Globe/globe/paper.png`

```text
Seamless tileable texture of old parchment paper, seen flat from straight above, filling the whole frame. Warm cream and pale tan, with soft uneven blotches, faint stains, fine fibres and grain, very subtle darker mottling. Even lighting, no shadows, no vignette, no edges, no folds, no creases, no writing, no drawings. The left edge continues seamlessly into the right edge and the top into the bottom. Square 1:1, 2048 x 2048 if possible.
```

### Compass rose: `art/PatchwerkForever_Thread_Globe/globe/compass.png`

```text
An ornate compass rose drawn in dark brown ink, in the style of an old hand-drawn fantasy world map: a sixteen-point star with long thin points, fine hatched shading on one side of each point, a thin double ring round it with small tick marks, and a fleur-de-lis on the north point. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no shadow, no border. Centred, filling most of a square 1:1 frame.
```

### Sea serpent: `art/PatchwerkForever_Thread_Globe/globe/serpent.png`

```text
A sea serpent rising out of waves, drawn in dark brown ink in the style of the sea monsters on old hand-drawn maps: three coils of its long scaled body arching above stylised curling waves, a finned head with an open toothy mouth, fine hatching for shading. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no shadow, no border. Seen from the side, centred, square 1:1.
```

### The Maelstrom: `art/PatchwerkForever_Thread_Globe/globe/maelstrom.png` (optional)

The tool draws a plain ink whirlpool itself, in the middle of the Great Sea. A picture saved under this name is used in its place.

```text
A great ocean whirlpool seen from straight above, drawn in dark brown ink in the style of an old hand-drawn sea chart: long curling arms of water winding in to a small dark eye at the centre, heavy pen strokes with finer broken strokes and flecks of foam between them, short curling waves flung off round its rim. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no ships, no shadow, no border. Round, centred, filling most of a square 1:1 frame.
```

### Ship: `art/PatchwerkForever_Thread_Globe/globe/ship.png`

```text
A small three-masted sailing ship on stylised curling waves, drawn in dark brown ink in the style of the ships on old hand-drawn maps: full billowing sails, a pennant on the main mast, fine hatching for shading. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no shadow, no border. Seen from the side, centred, square 1:1.
```

### Variations

So that no two drawings on the globe are the same. Save each under the name given and run `python globe_art.py world`; a drawing that is not there is left off, or, for the second of a kind, the first is used in its place.

- Give the image tool the **first drawing as a reference** (`serpent.png`, `ship.png`), so the ink's colour, the line weight and the richness of the hatching match. Each prompt says so in words too.
- Draw each **facing the same way as the first** (head or bow to the right). The addon turns every second one of a kind to face the other way.
- The same rules as every ink piece: dark ink on pure white, outlines closed.

| File | What it is | Where on the globe |
|---|---|---|
| `serpent2.png` | The second sea serpent (there is one now, close to the first: this prompt gives another pose) | The far sea, north |
| `ship2.png` | The second ship | Between the Maelstrom and the Eastern Kingdoms |
| `ship3.png` | A third ship, only once drawn | East of the Eastern Kingdoms, south |
| `kraken.png` | Only once drawn | The far sea, south-west |
| `whale.png` | Only once drawn | North-west of Kalimdor |
| `wind.png` | A wind's head blowing, only once drawn | The far north-east |

#### Second sea serpent: `art/PatchwerkForever_Thread_Globe/globe/serpent2.png`

```text
A sea serpent diving back into the sea, drawn in dark brown ink in the style of the sea monsters on old hand-drawn maps, by the same hand as the reference drawing: its long scaled body in one high loop above stylised curling waves, the fanned tail lashing up behind at the left, the finned head plunging down toward the water at the right with its jaws closed, a spray of foam where it goes under, fine hatching for shading. The same warm dark-brown ink, the same line weight and the same richness of hatching as the reference. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no shadow, no border. Seen from the side, centred, square 1:1.
```

#### Second ship: `art/PatchwerkForever_Thread_Globe/globe/ship2.png`

```text
A single-masted trading cog on stylised curling waves, drawn in dark brown ink in the style of the ships on old hand-drawn maps, by the same hand as the reference drawing: a round clinker-built hull with a high castle at the stern and a small one at the bow, one great square sail full of wind with a simple cross of stitching on it, a long forked pennant streaming from the masthead, a steering oar at the stern, fine hatching for shading. Sailing to the right. The same warm dark-brown ink, the same line weight and the same richness of hatching as the reference. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no shadow, no border. Seen from the side, centred, square 1:1.
```

#### Third ship: `art/PatchwerkForever_Thread_Globe/globe/ship3.png`

```text
A long war galley under oars on stylised curling waves, drawn in dark brown ink in the style of the ships on old hand-drawn maps, by the same hand as the reference drawing: a low slender hull with a ram at the bow, a single row of oars all swept back together, one striped lateen sail on a slanting yard, a small awning at the stern, fine hatching for shading. Moving to the right. The same warm dark-brown ink, the same line weight and the same richness of hatching as the reference. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no shadow, no border. Seen from the side, centred, square 1:1.
```

#### Kraken: `art/PatchwerkForever_Thread_Globe/globe/kraken.png`

```text
A kraken rising out of the sea, drawn in dark brown ink in the style of the sea monsters on old hand-drawn maps, by the same hand as the reference drawing: the great domed head and one round staring eye breaking the surface among stylised curling waves, eight long tentacles curling up out of the water round it, their undersides lined with suckers, two of them coiled into spirals at the tips, fine hatching for shading. The same warm dark-brown ink, the same line weight and the same richness of hatching as the reference. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no ships, no shadow, no border. Centred, filling most of a square 1:1 frame.
```

#### Whale: `art/PatchwerkForever_Thread_Globe/globe/whale.png`

```text
A spouting whale as drawn on old sea charts, in dark brown ink, by the same hand as the reference drawing: a great blunt-headed whale half out of stylised curling waves, a small fierce eye, a wide mouth with a row of teeth, two curling jets of water rising from its head and falling to either side, its forked tail raised out of the water behind at the left, fine hatching for shading. Facing right. The same warm dark-brown ink, the same line weight and the same richness of hatching as the reference. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no ships, no shadow, no border. Seen from the side, centred, square 1:1.
```

#### Wind: `art/PatchwerkForever_Thread_Globe/globe/wind.png`

```text
A wind's head as drawn in the corners of old maps, in dark brown ink, by the same hand as the reference drawing: the face of a full-cheeked old man with wild curling hair and beard, coming out of a bank of rolling cloud at the left, cheeks puffed and lips pursed, blowing a long widening stream of wind to the right drawn as a fan of fine curved lines with small curls at their ends, fine hatching for shading. The same warm dark-brown ink, the same line weight and the same richness of hatching as the reference. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no shadow, no border. Seen from the side, centred, square 1:1.
```

### Brass ring and stand: `art/PatchwerkForever_Thread_Globe/globe/ring.png`

```text
The brass meridian ring and wooden stand of an antique desk globe, but with no globe in it: a thick polished brass ring standing upright, engraved with fine degree markings, held at its top and bottom by small brass pins, on a carved dark wooden stand with a round base below it. Seen straight from the front. The inside of the ring is completely empty and filled with flat magenta (#FF00FF), and so is the whole background. The ring is a perfect circle centred left to right, its centre a little above the middle of the picture; its inner edge is about 70 percent of the picture's width across. Warm lamplight from the upper left, hand-painted fantasy game art. Square 1:1, 2048 x 2048 if possible. No text, no shadow on the background.
```

### Ring border, in place of the ring and stand: `art/PatchwerkForever_Thread_Globe/globe/border.png`

A heavy golden ring round the world, in the manner of the ring the world sits in on the game's logo, with no stand. It is a ring of our own in that manner, not a copy of the logo's: the addon ships only pictures of our own. Nothing of the logo's lettering, and no globe in it.

```text
A heavy ornate ring of antique gold, seen straight from the front, with nothing inside it: a thick round frame for a globe, in the manner of the great golden ring that circles the world in a classic fantasy game logo. A broad bevelled band of hammered, weathered gold with a raised rounded rim along its outer edge and a narrower raised rim along its inner edge, and between them a recessed channel of darker bronze set with large round domed studs evenly spaced all the way round. Fine engraved knotwork between the studs, small nicks and worn edges, the gold deep and warm with bright highlights at the upper left and rich brown shadow at the lower right, a thin dark line where the inner rim meets the hole. Hand-painted fantasy game art, rich and saturated, crisp edges. The inside of the ring is completely empty and filled with flat magenta (#FF00FF), and so is the whole background. The ring is a perfect circle, centred in the picture left to right and top to bottom; its inner edge is about 72 percent of the picture's width across and its outer edge about 94 percent. Square 1:1, 2048 x 2048 if possible. No globe, no map, no letters, no gems, no stand, no base, no chains, no shadow on the background.
```

If the tool gets it wrong: the hole must be clear magenta at the middle of the picture, and the band must be closed all the way round (a gap lets the magenta inside join the magenta outside, which is fine, but a band that fades out is not).
