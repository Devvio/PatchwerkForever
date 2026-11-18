# Patchwerk Forever: Thread (Sparkle)

## 1.3.0

- **Sparkles with keyboard and mouse.** The game picks an object to interact with only for a gamepad unless its **Enable Interact Key** option (Options → Controls) is on, so with keyboard and mouse nothing sparkled. The new **Sparkle With Keyboard And Mouse** option, on to begin with, turns it on while sparkles are enabled and puts it back when you disable either or log out, as with the other two game settings. Gamepad play is not changed. `/sparkle status` names the option when the game's setting is off.

## 1.2.0

- A key bound while this addon is not running (its base too old) does nothing instead of giving an error.
- **The key binding is now a toggle**, **Ignore / Unignore Sparkle Object**: pressed again on the same object, it takes the ignore back. `/sparkle undo` now takes back the last object you ignored, even after you have walked on. An object counts as targeted for 20 seconds after the game lets go of it, and no longer from minutes ago, or from before sparkles were hidden. Your binding is kept.
- **Key bindings** are in a section of their own, **Patchwerk Forever**, with the rest of the family's.
- **Clear Ignore List asks first.** `/sparkle clear` still clears at once. "Ignore list cleared (0 object(s))." is now "The ignore list is already empty." or "3 objects removed from the ignore list."
- **The preview follows the settings** while the options are open, is laid out as a real sparkle is (Vertical Offset, Position and Offset show in it), and stands beside the options window when there is room. It shows a real object's name ("Peacebloom", "Copper Vein", "Mailbox"). **Sparkle: Names** has a **Preview Name** button.
- **Preview Area** keeps the oval for ten seconds after your last change, and for ten seconds after you close the options, so you can compare it with your character.
- **Above Icon** now puts the name above the game's own icon, not across it.
- **The game's two settings** are put back at every logout as well, so disabling or removing the addon leaves the game as it was; the next login turns them on again. If the game turns one off by itself, Sparkle turns it back on once and says so.
- **`/sparkle` lists the commands.** `/sparkle status` says in one sentence whether the targeted object sparkles and why not; `/sparkle debug` has the game settings for a bug report.
- **Sparkle: Looks is now Sparkle: Appearance**, as the Tracker's page is named. Your settings are kept.
- The name settings are grayed out while **Show Object Name** is off, and the fade settings while **Fade Behind Character** is off. Brightness, Animation Speed, the fade sliders and the wisp's Speed show a percent sign. List choices are in Title Case ("Soft Glow", "Single Color", "Every Item").

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
