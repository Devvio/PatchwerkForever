# Your own art

The addons' icons are drawn by `tools/art.py`. A PNG put here is used in place of the drawn one, or added beside it.

| File | Becomes |
|---|---|
| `art/<addon folder>/icon.png` | the addon's icon in the game's addon list (`addons/<addon folder>/Media/icon.tga`, 64 x 64) |
| `art/<addon folder>/logo.png` | the CurseForge project's picture (`release/<addon folder>/logo.png`, 512 x 512). Without one, the icon is used. |
| `art/<addon folder>/<name>.png` | any other picture for that addon: `addons/<addon folder>/Media/<name>.tga` |
| `art/<addon folder>/listing/*` | pictures for the CurseForge listing (screenshots, a banner): copied as they are to `release/<addon folder>/listing/` by `python release.py`. They do not go into the addon. |

The addon folders are `PatchwerkForever`, `PatchwerkForever_Stitch_ConsolePort`, `PatchwerkForever_Stitch_MelloUI`, `PatchwerkForever_Stitch_MelloUIRoute`, `PatchwerkForever_Thread_Routes` and `PatchwerkForever_Thread_Sparkle`.

## What to save

- PNG, 8 or 16 bits a channel, not interlaced. Transparency is kept.
- An icon should be square; 256 x 256 or larger scales down well. It is made 64 x 64.
- Other pictures are made a power of two on each side (64, 128, 256, ...), which the game wants. Draw them at such a size to keep them sharp.

## When it is taken in

- `python build.py` (and `python build.py watch`) converts every PNG here before each build, so saving the file is enough to see it in the game. A new picture needs the game started again; a changed one too.
- `python art.py` redraws the icons that have no PNG here, writes the CurseForge logos, and makes `release/art-preview.png`, a sheet of every icon at three sizes.

To go back to a drawn icon, delete your `icon.png` and run `python art.py`.

In Lua, a picture is `Interface\AddOns\<addon folder>\Media\<name>` (no extension). A part of Patchwerk Forever can ask the base for any family addon's icon: `ns:Icon('PatchwerkForever_Stitch_ConsolePort')`, or `ns:IconText(addon, 14)` for a piece of text that shows it in a chat line.

## Pictures the addon shows in the game too

A picture under `listing/` is for the CurseForge page and does not ship. One that the addon also
shows in the game is named in `tools/art.py` (`ALSO_SHIPPED`), with the size it is made at:
`art/PatchwerkForever/listing/banner.png` becomes `addons/PatchwerkForever/Media/banner.tga`
(1024 by 512), the picture across the top of Patchwerk Forever's first options page.
