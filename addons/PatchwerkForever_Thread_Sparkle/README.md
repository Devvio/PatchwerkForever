# Patchwerk Forever: Thread (Sparkle)

**Ooh. Shiny.**

Patchwerk walks past herbs. Patchwerk walks past ore. Patchwerk once walked past a whole chest. One eye is not what it was, and the other is newer and still settling in.

So Patchwerk sewed a little light onto things. Come up to a herb, a vein, a chest or a quest object and it sparkles, with its name written over it. Twelve kinds of sparkle: loud ones, quiet ones, ones that barely whisper.

Every kind of thing gets a colour of its own. Patchwerk chose green for herbs. Patchwerk is told that is traditional.

Patchwerk wants more shiny! Patchwerk wants ALL the shiny!

*Decorative stitching. Purely cosmetic. Mostly.*

---

A sparkle on things you can use, for **World of Warcraft: Forever**. As you come up to a herb, a vein, a chest or a quest object, a light effect and its name appear over it.

One of Patchwerk Forever's own tools (the **Thread** track). **It needs Patchwerk Forever**, the small base addon that holds the settings pages, and nothing else.

It follows the thing the game's own interact key would use, so it works best with that key or a gamepad. Nothing is read off the minimap and nothing is searched for: the game says what the thing is.

## What you can change

- **Twelve effects**: star, soft glow, pulsing ring, light beam, swirl, brackets, five subtle ones (glints, fireflies, faint shimmer, ground ripple, wisp), or the name alone.
- **Each kind of thing has its own look**: herbs, ore, chests, quest objects and other things each have an effect, colour, size, brightness, height and speed, with a Test button.
- **The name**: size, font, outline, colour and place.
- **Hiding**: in combat, in dungeons and raids, or on things you choose to ignore.
- **Behind your character** (optional): the sparkle fades where it would be drawn over your character. An addon cannot draw behind your character, so this stands in for it.

## Loot wisps

When an item goes into your bags, a small wisp of light carries it there: it leaves the loot window, or the herb, vein, chest or quest object the sparkle was on, flies in a curve to that bag's button with the item's icon riding along, and the bag glows as it lands. It is the colour of that thing's sparkle (green from a herb, orange from ore), or one colour of your choosing.

Only what you loot, gather or pick up is carried, not what you buy, take from the mail or the bank, trade for or are given for a quest, unless you set **Show For** to Every item. Without a bag bar the wisp flies to your open bags, or to the lower right corner. Settings on **Sparkle: Loot Wisps**; `/sparkle wisp` sends one to your backpack.

While the sparkle is ticked, two of the game's own settings are switched on (`SoftTargetNameplateInteract` and `SoftTargetIconGameObject`), because without them there is nothing to hang the sparkle on. Unticking it puts them back as they were.

With **Patchwerk Forever: Thread (Routes)** installed too, a herb or a vein is known by name from the spots you have gathered, as well as by the game's cursor.

## Settings

**Options → AddOns → Patchwerk Forever → Thread: Sparkle**, or `/sparkle config`. The name has the page **Sparkle: Names**; how each kind of thing sparkles is on **Sparkle: Looks**, a heading for each kind; **Sparkle: Behind My Character** has the fading; and **Sparkle: Loot Wisps** has the wisps.

## Commands

| Command | Does |
|---|---|
| `/sparkle` | says what the game is pointing at, and why it does or does not sparkle (`/pfs` is the same) |
| `/sparkle ignore` | never sparkle again on the thing you are pointing at |
| `/sparkle undo` / `list` / `clear` | takes the last ignore back; lists the things ignored; forgets them all |
| `/sparkle wisp` | sends a loot wisp to your backpack, and says whether they are shown |
| `/sparkle config` | opens the settings |
| `/sparkle help` | lists the commands |

One action can be bound to a key or a gamepad button (Options → Keybindings → AddOns, or Console Port's binding list): never sparkle on this thing again.

## Credits

The code and pictures are under the MIT License. English only.
