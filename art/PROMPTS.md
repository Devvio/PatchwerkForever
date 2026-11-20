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

### Stitch (Console Port): `art/PatchwerkForever_Stitch_ConsolePort/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch made of two thick hides sewn together down the middle, olive-green on the left and plum-purple on the right, joined by a vertical seam of chunky copper stitches; edges torn and slightly curled; pinned at each of its four corners by a big cross-stitch of rust-orange leather cord. Set into the middle, across the seam, a large glowing teal-cyan game controller: a simple gamepad silhouette with two grips, a plus-shaped directional pad and two round buttons, like an inlaid gem with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Stitch (MelloUI): `art/PatchwerkForever_Stitch_MelloUI/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch made of two thick hides sewn together down the middle, olive-green on the left and plum-purple on the right, joined by a vertical seam of chunky copper stitches; edges torn and slightly curled; pinned at each of its four corners by a big cross-stitch of rust-orange leather cord. Set into the middle, across the seam, a large glowing teal-cyan emblem of a game menu: a rounded window frame holding three thick horizontal bars stacked one above the other, like an inlaid gem with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Stitch (MelloUI Route): `art/PatchwerkForever_Stitch_MelloUIRoute/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch made of two thick hides sewn together down the middle, olive-green on the left and plum-purple on the right, joined by a vertical seam of chunky copper stitches; edges torn and slightly curled; pinned at each of its four corners by a big cross-stitch of rust-orange leather cord. Set into the middle, across the seam, a large glowing teal-cyan signpost: one upright post with two arrow-shaped boards pointing opposite ways, like an inlaid gem with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Thread (Routes): `art/PatchwerkForever_Thread_Routes/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch of warm tan parchment-leather, like a scrap of an old map, its edges torn and slightly curled, pinned at each of its four corners by a big cross-stitch of glowing teal-cyan thread. Across the middle of the patch, a large glowing teal-cyan trail: a winding dotted line that starts at a small round dot in the lower left and ends at a bold X in the upper right, stitched into the leather with a soft glow. A bone sewing needle trailing a loop of glowing teal thread is tucked through one edge. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Thread (Sparkle): `art/PatchwerkForever_Thread_Sparkle/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch of warm tan parchment-leather, its edges torn and slightly curled, pinned at each of its four corners by a big cross-stitch of glowing teal-cyan thread. Set into the middle of the patch, a large glowing teal-cyan four-pointed sparkle, a twinkling star with long thin points, with two much smaller sparkles beside it, like inlaid gems with a bright inner glow and a few tiny motes of light drifting off them. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Thread (Tracker): `art/PatchwerkForever_Thread_Tracker/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch of warm tan parchment-leather, its edges torn and slightly curled, pinned at each of its four corners by a big cross-stitch of glowing teal-cyan thread. Set into the middle of the patch, a large glowing teal-cyan checklist: three thick horizontal bars stacked one above the other, each with a small mark at its left end, the top two marks bold ticks and the bottom one an empty ring, like inlaid gems with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Stitch (Dungeon Journal): `art/PatchwerkForever_Stitch_DungeonJournal/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch made of two thick hides sewn together down the middle, olive-green on the left and plum-purple on the right, joined by a vertical seam of chunky copper stitches; edges torn and slightly curled; pinned at each of its four corners by a big cross-stitch of rust-orange leather cord. Set into the middle, across the seam, a large glowing teal-cyan open book seen from the front, its two pages fanned, and rising out of the pages a short dotted trail that bends once and ends in a bold exclamation mark, like inlaid gems with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

### Thread (Immersive Plainsrunning): `art/PatchwerkForever_Thread_Plainsrunning/icon.png`

```text
Hand-painted stylised fantasy game icon. A ragged square patch of warm tan parchment-leather, its edges torn and slightly curled, pinned at each of its four corners by a big cross-stitch of glowing teal-cyan thread. Set into the middle of the patch, a large glowing teal-cyan cloven hoofprint, two bold rounded halves, leaning forward as if mid-stride, with three long speed streaks trailing behind it to the left and two short gusts of wind curling past it, like inlaid gems with a soft inner glow. Chunky faceted shapes, thick visible square brushstrokes, bold dark outline, hard edge highlights, teal rim light on the patch. Deep violet-purple painterly background, darker at the corners. Square 1:1, one centred object filling most of the frame, bold and simple enough to read at tiny size. No text, no letters, no border, no watermark.
```

## If a result drifts

- **Too detailed to read small:** add "flat, bold emblem, no small details inside the emblem".
- **Wrong colours:** name them again at the start: "olive-green, plum-purple, rust-orange, glowing teal-cyan, violet background".
- **It wrote letters:** add "absolutely no writing or runes".
- **The patch became a shield or a badge:** add "a soft, floppy, torn piece of hide, not metal, not a shield".
- **The whole family should match:** make them all in one sitting with the same reference picture, and keep the first good one as the reference for the rest.

---

# Thread (Globe): the globe's own art

Not icons: the pieces the globe's world picture is made of, laid over the land and sea that `tools/globe_art.py` draws from the game's terrain. The look is the **world map on parchment**, not the icons' look: an old hand-drawn map, warm parchment, sepia and dark-brown ink. Until a piece is there, the tool draws a plain stand-in.

Save each as `art/PatchwerkForever_Thread_Globe/<name>.png`, then run `python globe_art.py world` in `tools/`.

## How each is used

- **Ink pieces** (the compass rose, the serpent, the ship) are laid on the sea by **multiplying**: white disappears, the ink stays. So they must be dark ink on **pure white**, with no paper colour, shading or vignette of their own.
- **The paper** is laid over the whole world as its grain and stains. It must **tile**: its left edge must continue into its right and its top into its bottom.
- **The ring and stand** sit round the ball in the window, on **flat magenta (#FF00FF)**, which the tool cuts away.

## The prompts

### Paper: `art/PatchwerkForever_Thread_Globe/paper.png`

```text
Seamless tileable texture of old parchment paper, seen flat from straight above, filling the whole frame. Warm cream and pale tan, with soft uneven blotches, faint stains, fine fibres and grain, very subtle darker mottling. Even lighting, no shadows, no vignette, no edges, no folds, no creases, no writing, no drawings. The left edge continues seamlessly into the right edge and the top into the bottom. Square 1:1, 2048 x 2048 if possible.
```

### Compass rose: `art/PatchwerkForever_Thread_Globe/compass.png`

```text
An ornate compass rose drawn in dark brown ink, in the style of an old hand-drawn fantasy world map: a sixteen-point star with long thin points, fine hatched shading on one side of each point, a thin double ring round it with small tick marks, and a fleur-de-lis on the north point. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no shadow, no border. Centred, filling most of a square 1:1 frame.
```

### Sea serpent: `art/PatchwerkForever_Thread_Globe/serpent.png`

```text
A sea serpent rising out of waves, drawn in dark brown ink in the style of the sea monsters on old hand-drawn maps: three coils of its long scaled body arching above stylised curling waves, a finned head with an open toothy mouth, fine hatching for shading. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no shadow, no border. Seen from the side, centred, square 1:1.
```

### Ship: `art/PatchwerkForever_Thread_Globe/ship.png`

```text
A small three-masted sailing ship on stylised curling waves, drawn in dark brown ink in the style of the ships on old hand-drawn maps: full billowing sails, a pennant on the main mast, fine hatching for shading. Pen-and-ink line art only, on a pure white background. No paper texture, no colour, no letters, no shadow, no border. Seen from the side, centred, square 1:1.
```

### Brass ring and stand: `art/PatchwerkForever_Thread_Globe/ring.png`

```text
The brass meridian ring and wooden stand of an antique desk globe, but with no globe in it: a thick polished brass ring standing upright, engraved with fine degree markings, held at its top and bottom by small brass pins, on a carved dark wooden stand with a round base below it. Seen straight from the front. The inside of the ring is completely empty and filled with flat magenta (#FF00FF), and so is the whole background. The ring is a perfect circle centred left to right, its centre a little above the middle of the picture; its inner edge is about 70 percent of the picture's width across. Warm lamplight from the upper left, hand-painted fantasy game art. Square 1:1, 2048 x 2048 if possible. No text, no shadow on the background.
```
