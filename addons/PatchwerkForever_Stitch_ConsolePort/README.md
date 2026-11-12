# Patchwerk Forever: Stitch (Console Port)

Fixes for **Console Port** on **World of Warcraft: Forever**. Console Port's support for Forever is new; this fixes what it doesn't handle yet.

**It needs two addons:** [Console Port](https://github.com/seblindfors/ConsolePort) itself, and **Patchwerk Forever**, the base that holds the settings page and the saved data. (Until Patchwerk Forever 1.0.1 these fixes were inside that addon; your settings carry over.)

Nothing in Console Port's own files is changed: the fixes hook it while the game runs, so its updates don't undo them.

## What it fixes

- **Open Game Menu works.** On Forever the game menu button only switched the gamepad cursor on and off. This turns off the game's automatic gamepad cursor (`GamePadCursorAutoEnable`), which is what gets in the way; your old value is put back if you turn the fix off.
- **Forever's own gamepad buttons no longer override yours.** Switch to Cursor, the radial menu, ping and the targeting modifiers are cleared from any button you bind in Console Port, and can be bound from Console Port's binding list instead.
- **Extra Action Button can be bound** (Forever has the button but no binding for it).
- **Item menu equips into the right slot**: robes, held off-hand items, bows, guns, wands, thrown weapons and relics.
- **Interact works from a ring** ("Interact (tap)").
- **Target Friendly / Target Hostile** hold buttons no longer raise a blocked-action error.
- **The game's bag bar and micro menu come back** when Console Port's toolbar isn't using their buttons (Console Port hides them for good on Forever). Has its own switch.
- Smaller repairs: tooltips for the game's action buttons under the interface cursor, the key ring slot on characters without one, an error when dragging the on-screen keyboard, and switching between gamepad and mouse-and-keyboard interface mid-session.

## Settings and commands

The page **Stitch: Console Port**, under **Options → AddOns → Patchwerk Forever** (`/patchwerk config` opens the page above it). Nothing is added to Console Port's own settings.

`/patchwerk consoleport` prints gamepad binding diagnostics.

## Fixes are meant to be temporary

When Console Port fixes one of these itself, the matching fix is removed here in the next update. If you notice one that a Console Port update has made unnecessary, please report it. If something misbehaves, the chat line it prints is what to report.

## Credits

Not affiliated with Console Port, which is by Sebastian Lindfors. This addon is under the MIT License.
