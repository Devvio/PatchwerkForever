# Patchwerk Forever: Thread (Sparkle)

## 1.1.0

- **Loot wisps.** When an item goes into your bags, a small wisp of light flies from where it came from to that bag's button, with the item's icon riding along, and the bag glows as it lands. It leaves from the loot window, or from the herb, vein, chest or quest object the sparkle was on, and it takes the colour of that thing's sparkle.
- Only what you loot, gather or pick up is carried; items bought, taken from the mail or the bank, traded or given as a quest reward are not, unless **Show For** is set to Every item. Without a bag bar (Console Port and other interfaces that hide it) the wisp flies to your open bags, or to the lower right corner.
- A new page, **Sparkle: Loot Wisps**: Show Loot Wisps, Show For, Carry Item Icon, Hide In Combat, Size, Speed, Color Mode and Wisp Color, with a **Preview Wisp** button. `/sparkle wisp` sends one to your backpack and says whether they are shown.

## 1.0.0

The first full release. Everything in 0.12.0 has been played and works.

- **Reset To Defaults** at the foot of its first options page (with Patchwerk Forever 2.3.0).

## 0.12.0 (beta)

- **One page for the looks.** The five pages for how each kind of thing sparkles (herbs, ore, chests, quest objects, other things) are one page now, **Sparkle: Looks**, with a heading for each kind. Your settings are kept.
- Its pages open with its picture and a line from Patchwerk, and its settings are renamed in standard terms (Enable Sparkles, Font Size, Color Mode, Hide In Instances), and chat messages, command help and the key binding are reworded to match; nothing changes in what they do.

## 0.11.0 (beta)

First release as an addon of its own. Until now the sparkle was part of the route planner (then called Wayfarer, now *Patchwerk Forever: Thread (Routes)*).

- Needs the **Patchwerk Forever** base (a small addon). Its settings are under Options → AddOns → Patchwerk Forever, on **Thread: Sparkle** and the Sparkle pages beneath it.
- **The command is `/sparkle`** (or `/pfs`): `/sparkle`, `/sparkle ignore`, `undo`, `list`, `clear`, `config`.
- What it does is unchanged: twelve effects, a look for each kind of thing, the name over the thing, hiding in combat and in dungeons, things you ignore, fading behind your character.
- The route planner is no longer needed. With it installed, herbs and veins are still known by the names of the spots you have gathered.
- Settings and the ignore list saved under the old addon are not read; the key binding needs setting again.
