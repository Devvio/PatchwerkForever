# Patchwerk Forever: Thread (Sparkle)

**Ooh. Shiny.**

Patchwerk walks past herbs. Patchwerk walks past ore. Patchwerk once walked past a whole chest. One eye is not what it was, and the other is newer and still settling in.

So Patchwerk sewed a little light onto things. Come up to an herb, a vein, a chest or a quest object and it sparkles, with its name written over it. Twelve kinds of sparkle: loud ones, quiet ones, ones that barely whisper.

Every kind of thing gets a color of its own. Patchwerk chose green for herbs. Patchwerk is told that is traditional.

Patchwerk wants more shiny! Patchwerk wants ALL the shiny!

*Decorative stitching. Purely cosmetic. Mostly.*

---

A sparkle on things you can use, for **World of Warcraft: Forever**. As you come up to an herb, a vein, a chest or a quest object, a light effect and its name appear over it.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the options pages, and nothing else.

It follows the object the game's own interact key would use, so it works best with that key or a gamepad. Nothing is read off the minimap and nothing is searched for: the game says what the object is.

## What you can change

- **Twelve effects**: Star, Soft Glow, Pulsing Ring, Light Beam, Swirl, Brackets, five subtle ones (Glints, Fireflies, Faint Shimmer, Ground Ripple, Wisp), or the name alone.
- **Each kind of object has its own look**: herbs, ore, chests, quest objects and other objects each have an effect, color, size, brightness, height and speed, with a Preview Sparkle button. While the options are open, the preview follows the settings as you change them, beside the options window when there is room.
- **Apply Subtle Preset** gives every kind a subtle effect at once, keeping your colors and sizes.
- **Mailboxes, doors, anvils and the like** sparkle too with **Include All Interactable Objects** (off by default).
- **The name**: size, font, outline, color and position (below the nameplate, or above the game's own icon), with a Preview Name button.
- **Hiding**: in combat, in dungeons and raids, or on objects you choose to ignore.
- **Behind your character** (optional): the sparkle fades where it would be drawn over your character. An addon cannot draw behind your character, so this stands in for it. **Preview Area** shows the area as an oval while you set it.

## Loot wisps

When an item goes into your bags, a small wisp of light carries it there: it leaves the loot window, or the herb, vein, chest or quest object the sparkle was on, flies in a curve to that bag's button with the item's icon riding along, and the bag glows as it lands. It is the color of that object's sparkle (green from an herb, orange from ore), or one color of your choosing.

Only what you loot, gather or pick up is carried, not what you buy, take from the mail or the bank, trade for or are given for a quest, unless you set **Show For** to Every Item. Without a bag bar the wisp flies to your open bags, or to the lower right corner. Options on **Sparkle: Loot Wisps**; `/sparkle wisp` sends one to your backpack.

## The game's own settings

While **Enable Sparkles** is on, two of the game's own settings are turned on (`SoftTargetNameplateInteract` and `SoftTargetIconGameObject`), because without them there is nothing to hang the sparkle on. Disabling it puts them back as they were, and so does every logout or reload, so disabling or removing the addon leaves the game as it was; the next login turns them on again. If the game turns one off by itself, Sparkle turns it back on once and says so in chat.

With **Patchwerk Forever: Thread (Routes)** installed too, an herb or a vein is known by name from the nodes you have gathered, as well as by the game's cursor.

## Options

**Options → AddOns → Patchwerk Forever → Thread: Sparkle**, or `/sparkle config`. The name has the page **Sparkle: Names**; how each kind of object sparkles is on **Sparkle: Appearance**, a heading for each kind; **Sparkle: Behind My Character** has the fading; and **Sparkle: Loot Wisps** has the wisps.

## Commands

| Command | Does |
|---|---|
| `/sparkle` | lists the commands (`/pfs` is the same) |
| `/sparkle status` | says what the game is pointing at, and why it does or does not sparkle |
| `/sparkle ignore` | never sparkle again on the object you are pointing at |
| `/sparkle undo` / `list` / `clear` | takes the last ignore back; lists the objects ignored; forgets them all |
| `/sparkle wisp` | sends a loot wisp to your backpack, and says whether they are shown |
| `/sparkle debug` | lists the game settings Sparkle reads, for a bug report |
| `/sparkle config` | opens the options |

Bind this under Options → Keybindings → Patchwerk Forever, or in Console Port's binding list: **Ignore / Unignore Sparkle Object**. It ignores the object you are pointing at; pressed again on the same object, it takes the ignore back. The **Clear Ignore List** button asks before it empties the list.

Something wrong? Report it as a comment on the addon's CurseForge page.

## Credits

The code and pictures are under the MIT License. English only.
