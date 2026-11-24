# Patchwerk Forever: Sparkle (Thread)

**Ooh. Shiny.**

Patchwerk walks past herbs. Patchwerk walks past ore. Patchwerk once walked past a whole chest. One eye is not what it was, and the other is newer and still settling in.

So Patchwerk sewed a little light onto things. Come up to an herb, a vein, a chest or a quest object and it sparkles, with its name written over it. Sixteen kinds of sparkle: loud ones, quiet ones, ones that barely whisper, and some with leaves in.

Every kind of thing gets a color of its own. Patchwerk chose green for herbs. Patchwerk is told that is traditional.

Patchwerk wants more shiny! Patchwerk wants ALL the shiny!

*Decorative stitching. Purely cosmetic. Mostly.*

---

A sparkle on things you can use, for **World of Warcraft: Forever**. As you come up to an herb, a vein, a chest or a quest object, a light effect and its name appear over it. A corpse with loot for you, or one you can skin, sparkles too, and so does the waypoint you are following.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the options, and nothing else.

It follows the object the game's own interact key would use: one at a time, the one in front of you. With keyboard and mouse the game only picks one while its **Enable Interact Key** option is on, so Sparkle turns that on for you (**Sparkle With Keyboard And Mouse**, below). Nothing is read off the minimap and nothing is searched for: the game says what the object is.

## What you can change

- **Sixteen effects**: Star, Soft Glow, Pulsing Ring, Light Beam, Swirl, Brackets, five subtle ones (Glints, Fireflies, Faint Shimmer, Ground Ripple, Wisp), four themed ones (Falling Leaves, Embers, Coin Glints, Sun Rays), or the name alone.
- **Each kind of object has its own look**: herbs, ore, chests, quest objects, quest corpses, corpses with loot, skinnable corpses, other objects and the waypoint each have a Show tick box (corpses have theirs on the first page), an effect, color, size, brightness, height, speed and alert sound, with a Preview Sparkle button and **Use This Look For All**. While the options are open, the preview follows the settings as you change them, beside the options window when there is room. **Preview All Types** shows every kind side by side.
- **Apply Subtle Preset** gives every kind a subtle effect at once, and **Apply Themed Preset** the one drawn for it (leaves on herbs, embers on ore, coins on chests), keeping your colors and sizes.
- **Sparkle Distance** and **Brighter When Near**: see below.
- **Fade While Gathering**: the sparkle fades while you gather from, open or loot the object.
- **Mailboxes, doors, anvils and the like** sparkle too with **Include All Interactable Objects** (off by default).
- **Corpses**: with loot for you, and skinnable ones for a character who has Skinning. Each can be turned off. See below.
- **Herbs and ore you cannot gather** can be shown, dimmed or hidden. See below.
- **The name**: size, font, outline, color and position (below the nameplate, or above the game's own icon), with a Preview Name button.
- **Hiding**: in combat, in dungeons and raids, or on objects and corpses you choose to ignore.
- **Behind your character** (optional): the sparkle fades where it would be drawn over your character. An addon cannot draw behind your character, so this stands in for it. **Preview Area** shows the area as an oval while you set it, and a second height is used while you are mounted.
- **Alerts**: an Alert Sound for each kind (None to begin with), and Rumble On Gamepad on **Sparkle: Alerts**. Once for each object; the same one again only after half a minute.

## From further away

**Sparkle Distance** (Game Default, 15, 20, 30 or 40 yards) raises how far away the game picks an object for the interact key, and so how far away a sparkle can show. It only ever raises the game's own setting (`SoftTargetInteractRange`), never lowers it, and puts it back when you disable it or log out. You still walk up to an object to use it, and the game may cap the distance.

**Brighter When Near** (on) makes a sparkle fainter and a little smaller at the far edge of that distance, and full up close. The game does not tell an addon where an herb or a vein is, so the distance comes from **Patchwerk Forever: Routes (Thread)**, which remembers where you stood each time you gathered one: without Routes, or for a node it has not seen, herbs and ore sparkle at full brightness. For the waypoint the game gives the distance.

## The waypoint

The **Waypoint** kind hangs a light beam on the game's own waypoint marker. Besides the object in front of you, that marker is the one place in the world whose spot on screen the game tells an addon.

With **Patchwerk Forever: Routes (Thread)** and its **Mark The Way Ahead** (on to begin with), the marker stands on the route's trail a little way ahead of you and moves on as you walk, so the beam follows the path you are on, round walls and through gates, with where the route leads and how far under it ("Peacebloom (120 yd)"). Your map pin and tracked quest are lent for it and given back afterwards (see Routes' README). Without Routes the beam stands over the quest you track or your map pin.

It is drawn only where the game draws its own marker: not while the place is off screen (the game's arrow at the edge shows the way), and not while the game has no valid place on screen for it.

## Corpses

A dead creature the game's interact key points at sparkles when it has loot for you (**Sparkle On Corpses With Loot**), and with a look of its own when it can be skinned (**Sparkle On Skinnable Corpses**, only for a character who has Skinning). One with loot that the game ties to one of your quests is a **Quest Corpse**, with a look of its own again (its Show tick box is on Sparkle: Appearance). Both are on by default, and each kind has its own effect and color on **Sparkle: Appearance**. A living creature or a player never sparkles. Hiding in combat and in instances applies to corpses as to objects, and so does the ignore list: ignoring one corpse ignores every corpse of that name.

Sparkle follows what the game's interact key points at, so a corpse the game does not pick does not sparkle. The game has no function that says a corpse can be skinned, so that is read from the cursor the game would show over it and from its tooltip.

## Herbs and ore you cannot gather

**Herbs And Ore I Cannot Gather** sets what happens to an herb when your character does not have Herbalism, and to ore when it does not have Mining: **Show** (the default, as before), **Dim** (a much fainter sparkle and name) or **Hide**. Just after login, until the game has said what your professions are, everything shows.

Skill level is not looked at: a node that needs more skill than you have sparkles like any other, because the game does not tell an addon that plainly. `/sparkle status` says when an object is dimmed or hidden for this reason.

## Loot wisps

When an item goes into your bags, a small wisp of light carries it there: it leaves the loot window, or the herb, vein, chest, quest object or corpse the sparkle was on, flies in a curve to that bag's button with the item's icon riding along, and the bag glows as it lands. When it leaves from where the sparkle was, it is the color of that sparkle (green from an herb, orange from ore), or one color of your choosing.

Only what you loot, gather or pick up is carried, not what you buy, take from the mail or the bank, trade for or are given for a quest, unless you set **Show For** to Every Item. Without a bag bar the wisp flies to your open bags, or to the lower right corner. Options on **Sparkle: Loot Wisps**; `/sparkle wisp` sends one to your backpack.

**Color Mode** can also be **By Item Quality** (quest items in the Quest Objects color). A Rare item or better flies with a bigger wisp and the bag flares (**Celebrate Rare Loot**); looted money flies to the backpack as a gold wisp (**Coins Fly To Your Bag**); and a quest item flies to its quest in the tracker, Tracker (Thread)'s or the game's, where the line lights up as its count goes up (**Quest Items Fly To The Tracker**).

## What you passed

A chest, an herb or a vein that sparkled and that you walked away from without opening or gathering it is remembered, with where you were as you passed (**Remember What I Pass**, on; nothing leaves your computer). **Sparkle: Passed** lists them nearest first, each with **Add To Route**, which puts it on My Route for Routes (Thread) to lead you along, and **Forget**. `/sparkle passed` lists them in chat, and `/sparkle passed route` puts the nearest chest on My Route. Gathering or opening one later takes it off.

With **Share Herb And Ore Spots With Routes** (on), the herbs and ore you pass show on Routes (Thread)'s maps with the ones you gathered, and a gathering run can go to them. The spot is where you stood, a few yards from the node.

## The game's own settings

While **Enable Sparkles** is on, two of the game's own settings are turned on (`SoftTargetNameplateInteract` and `SoftTargetIconGameObject`), because without them there is nothing to hang the sparkle on. Disabling it puts them back as they were, and so does every logout or reload, so disabling or removing the addon leaves the game as it was; the next login turns them on again. If the game turns one off by itself, Sparkle turns it back on once and says so in chat.

**Sparkle With Keyboard And Mouse** (on to begin with) keeps a third the same way: the game's **Enable Interact Key** (Options → Controls, `SoftTargetInteract`). Without it the game picks an object only for a gamepad, so with keyboard and mouse nothing would sparkle. You do not need to bind the interact key. Gamepad play is not changed, and disabling the option puts the game's setting back.

With **Patchwerk Forever: Routes (Thread)** installed too, an herb or a vein is known by name from the nodes you have gathered, as well as by the game's cursor.

## Options

**Sparkle (Thread)** in Patchwerk Forever's options window, `/sparkle config`; its further pages fold under it. The name has the page **Sparkle: Names**; how each kind of object sparkles is on **Sparkle: Appearance**, a heading for each kind; **Sparkle: Behind My Character** has the fading; **Sparkle: Alerts** the rumble; **Sparkle: Ignore List** the ignored objects, each with a Remove button; **Sparkle: Passed** what you passed; and **Sparkle: Loot Wisps** has the wisps. The two lists need Patchwerk Forever 2.9.0.

## Commands

| Command | Does |
|---|---|
| `/sparkle` | lists the commands (`/pfs` is the same) |
| `/sparkle status` | says what object or corpse the game is pointing at, and why it does or does not sparkle (or is dimmed) |
| `/sparkle ignore` | never sparkle again on the object or corpse you are pointing at |
| `/sparkle undo` / `list` / `clear` | takes the last ignore back; lists the objects ignored; forgets them all |
| `/sparkle wisp` | sends a loot wisp to your backpack, and says whether they are shown |
| `/sparkle passed` / `passed route` / `passed clear` | lists what you passed, nearest first; puts the nearest chest on My Route; forgets them all |
| `/sparkle debug` | lists the game settings and professions Sparkle reads, and what the tooltip of the object you point at says, for a bug report |
| `/sparkle config` | opens the options |

Bind this under Options → Keybindings → Patchwerk Forever, or in Console Port's binding list: **Ignore / Unignore Sparkle Object**. It ignores the object you are pointing at; pressed again on the same object, it takes the ignore back. The ignore list is on **Sparkle: Ignore List**, each object with a Remove button; **Clear Ignore List** there asks before it empties the list.

Something wrong? Report it as a comment on the addon's CurseForge page.

## Credits

The code and pictures are under the MIT License. English only.
