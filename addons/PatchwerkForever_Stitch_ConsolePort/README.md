# Patchwerk Forever: Stitch (Console Port)

**Why buy a new controller when this one only twitches a little?**

Patchwerk found a gamepad. Very good gamepad. Then Forever happened to it. The menu button stopped opening the menu, and the other buttons started doing things nobody asked for.

So Patchwerk opened it up. The game menu opens again. Forever's own buttons have stopped arguing with yours. Robes go on the body and bows go in the hand, as nature intended. The bag bar is back from wherever Console Port buried it.

Nothing inside Console Port was touched. Patchwerk only sews on the outside. Mostly on the outside.

Patchwerk wants more buttons! Patchwerk has thumbs for at least six!

*Unofficial surgery. Officially questionable results.*

---

Fixes for **Console Port** on **World of Warcraft: Forever**. Console Port's support for Forever is new; this fixes what it doesn't handle yet.

**It needs two addons:** [Console Port](https://github.com/seblindfors/ConsolePort) itself, and **Patchwerk Forever**, the base that holds the settings page and the saved data. (Until Patchwerk Forever 1.0.1 these fixes were inside that addon; your settings carry over.)

Nothing in Console Port's own files is changed: the fixes hook it while the game runs, so its updates don't undo them.

## What it fixes

- **Open Game Menu works.** On Forever the game menu button only switched the gamepad cursor on and off. This turns off the game's automatic gamepad cursor (`GamePadCursorAutoEnable`), which is what gets in the way, and says so in chat; your old value is put back (and said) if you disable the option.
- **Forever's own gamepad buttons no longer override yours.** Switch to Cursor, the radial menu, ping and the targeting modifiers are cleared from any button you bind in Console Port, and can be bound from Console Port's binding list instead.
- **Extra Action Button can be bound** (Forever has the button but no binding for it).
- **Item menu equips into the right slot**: robes, held off-hand items, bows, guns, wands, thrown weapons and relics.
- **Interact works from a ring** ("Interact (tap)").
- **Target Friendly / Target Hostile** hold buttons no longer raise a blocked-action error.
- **Console Port's menu ring works again**: since Console Port 3.3.14 it stayed shut while Console Port's Game Menu setting was off or the game's own gamepad interface was on (Keep The Menu Ring, its own switch), and opened without its buttons, because its setup calls a function Forever lacks.
- **The game's bag bar and micro menu come back** when Console Port's toolbar isn't using their buttons (Console Port hides them for good on Forever). Has its own switch.
- Smaller repairs: tooltips for the game's action buttons under the interface cursor, the key ring slot on characters without one, an error when dragging the on-screen keyboard, and switching between gamepad and mouse-and-keyboard interface mid-session.

## Settings and commands

The page **Stitch: Console Port**, under **Options → AddOns → Patchwerk Forever** (`/patchwerk config` opens the page above it). Nothing is added to Console Port's own settings.

`/patchwerk consoleport` lists which fixes took hold and which did not, and prints gamepad binding diagnostics. With **Report Binding Changes** on, each binding this addon clears, restores or replaces is said in chat.

## Fixes are meant to be temporary

When Console Port fixes one of these itself, the matching fix is removed here in the next update. If you notice one that a Console Port update has made unnecessary, please report it. If something misbehaves, the chat line it prints is what to report.

**Reporting a problem:** please leave a comment on the addon's CurseForge page.

## Credits

Not affiliated with Console Port, which is by Sebastian Lindfors. This addon is under the MIT License.
