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

## If a result drifts

- **Too detailed to read small:** add "flat, bold emblem, no small details inside the emblem".
- **Wrong colours:** name them again at the start: "olive-green, plum-purple, rust-orange, glowing teal-cyan, violet background".
- **It wrote letters:** add "absolutely no writing or runes".
- **The patch became a shield or a badge:** add "a soft, floppy, torn piece of hide, not metal, not a shield".
- **The whole family should match:** make all six in one sitting with the same reference picture, and keep the first good one as the reference for the rest.
