# Patchwerk Forever: Sparkle (Thread)

## 1.5.0

A sparkle on the waypoint you follow, sparkles from further away, alerts, and more for the loot wisps. Needs Patchwerk Forever 2.9.0 for the two lists on the options pages; with an older base everything else works and the lists are left out.

### Sparkles
- **The waypoint.** A new kind, **Waypoint**: a light beam on the game's own waypoint marker. With Patchwerk Forever: Routes (Thread) and its Mark The Way Ahead, that marker stands on the route's trail a little way ahead of you, so the beam follows the path you are on, with where it leads and how far under it ("Peacebloom (120 yd)"). Without Routes it stands over the quest you track or your map pin. It is drawn only where the game draws its own marker: not while the place is off screen, and not while the game has no valid place on screen for it (it no longer stays stuck on screen).
- **Sparkle Distance** (Game Default, 15, 20, 30 or 40 yards): how far away the game picks an object for the interact key, and so how far away a sparkle can show. It only ever raises the game's own setting (`SoftTargetInteractRange`) and puts it back when disabled or at logout, as with the other game settings.
- **Brighter When Near** (on): a sparkle is fainter and a little smaller at the far edge of the reach and full up close. For herbs and ore the distance comes from the nodes Patchwerk Forever: Routes (Thread) remembers; for the waypoint, from the game.
- **Quest Corpses**: a corpse with loot for you that belongs to one of your quests has a look of its own (a ring in amber), so the boar whose pelt you need stands out.
- **A Show tick box for each kind** on Sparkle: Appearance: turn chests or other objects off entirely. (Corpses keep theirs on the first page.)
- **Fade While Gathering** (on): the sparkle and name fade while you gather from, open or loot the object.
- **Four themed effects**: Falling Leaves, Embers, Coin Glints and Sun Rays, and **Apply Themed Preset**, which gives each kind the one drawn for it.
- **Use This Look For All** under each kind, and **Preview All Types** at the top of the page, every kind side by side.
- **Character Height On Mount** (Behind My Character): the fade area while mounted.

### Alerts
- **Alert Sound** for each kind (None to begin with): a sound of the game's own when that kind of sparkle appears, once for each object, again only after half a minute. Preview Sparkle plays it.
- **Sparkle: Alerts**, a new page: **Rumble On Gamepad** (off), **Rumble For** (Types With An Alert Sound, or Every Sparkle), **Rumble Strength**, and **Preview Rumble**. Only while a gamepad is in use.

### Loot wisps
- **Color Mode: By Item Quality**: the item's quality color, and quest items in the Quest Objects color.
- **Celebrate Rare Loot** (on): a Rare item or better flies with a bigger wisp, and the bag flares as it lands.
- **Coins Fly To Your Bag** (on): looted money flies to your backpack as a small gold wisp.
- **Quest Items Fly To The Tracker** (on): a quest item flies to its quest in Tracker (Thread)'s list, or to the game's tracker, and the line lights up as its count goes up.

### What you passed
- **Sparkle: Passed**, a new page. Chests, herbs and ore that sparkled and that you walked away from are remembered with where you were (**Remember What I Pass**, on), listed nearest first with **Add To Route** (puts it on My Route) and **Forget**. `/sparkle passed` lists them; `/sparkle passed route` puts the nearest chest on My Route.
- **Share Herb And Ore Spots With Routes** (on): the herbs and ore you pass show on Routes (Thread)'s maps with the ones you gathered, and a gathering run can go to them. Needs Routes (Thread) 1.4.0.

### The ignore list
- **Sparkle: Ignore List**, a new page: every ignored object with a **Remove** button, a page at a time. **Clear Ignore List** moved there.

### For bug reports
- `/sparkle debug` also prints the tooltip of the object you point at, line by line, with the color of each line that is not white or gold, and whether the game ties it to one of your quests. `/sparkle status` has a line for the waypoint.

## 1.4.0

- **Corpses sparkle.** A dead creature the game's interact key points at sparkles when it has loot for you, and with a look of its own when it can be skinned and your character has Skinning. Two new options, both on to begin with: **Sparkle On Corpses With Loot** and **Sparkle On Skinnable Corpses**. Each kind has its own effect, color, size, brightness, height and speed on **Sparkle: Appearance**, with a Preview Sparkle button. A living creature or a player never sparkles. Hide In Combat, Hide In Instances and the ignore list apply to corpses too, and a loot wisp that leaves from a sparkling corpse takes that kind's color. Whether a corpse can be skinned is read from the game's cursor and the corpse's tooltip.
- **Herbs And Ore I Cannot Gather**: Show (the default, as before), Dim (a much fainter sparkle and name) or Hide, for an herb when your character does not have Herbalism and for ore when it does not have Mining. Until the game has said what your professions are, everything shows. Skill level is not looked at.
- `/sparkle status` names a corpse and says why it does not sparkle (no loot for you, no Skinning, its option disabled), and says when an herb or ore is dimmed or hidden. `/sparkle debug` lists the professions the game reports.
- **Apply Subtle Preset** sets the two new kinds as well: a faint shimmer on corpses with loot, glints on skinnable corpses.

## 1.3.1

- **Now named Patchwerk Forever: Sparkle (Thread)**: the name comes first and what kind of addon it is after it, in brackets (it was Thread (Sparkle)). The options page is named the same way.

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

First release as an addon of its own. Until now the sparkle was part of the route planner (then called Wayfarer, now *Patchwerk Forever: Routes (Thread)*).

- Needs the **Patchwerk Forever** base (a small addon). Its settings are under Options → AddOns → Patchwerk Forever, on **Sparkle (Thread)** and the Sparkle pages beneath it.
- **The command is `/sparkle`** (or `/pfs`): `/sparkle`, `/sparkle ignore`, `undo`, `list`, `clear`, `config`.
- What it does is unchanged: twelve effects, a look for each kind of thing, the name over the thing, hiding in combat and in dungeons, things you ignore, fading behind your character.
- The route planner is no longer needed. With it installed, herbs and veins are still known by the names of the spots you have gathered.
- Settings and the ignore list saved under the old addon are not read; the key binding needs setting again.
