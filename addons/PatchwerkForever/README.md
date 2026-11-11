# Patchwerk Forever

*Named for Naxxramas's stitched-together abomination: a patchwork of fixes, for Forever.*

Fixes and additions for other addons on **World of Warcraft: Forever**. Patchwerk changes nothing in those addons' own files: it hooks them while the game runs, so their updates don't undo it. Each part only runs when the addon it is for is loaded.

**It requires none of them.** Install it with whichever of Console Port and MelloUI you use; the parts for an addon you don't have simply stay off, and their settings don't appear. EllesmereUI and RestedXP Guides are only needed for the one feature each that mentions them.

**Reporting a problem:** if something misbehaves, the chat line it prints ("… failed and was skipped") is what to report.

**Fixes are meant to be temporary.** When Console Port, MelloUI or another addon fixes one of these issues itself, the matching fix is removed from Patchwerk Forever in its next update, so you always get the original addon's own solution. If you notice a fix here that an addon update has made unnecessary, please report it.

Type `/patchwerk` to list what is active.

**Settings** are on Patchwerk Forever's own page: **Options → AddOns → Patchwerk Forever**, or `/patchwerk config`. Nothing is added to the settings of the addons it works with. The page only lists the sections for the addons you have loaded.

## For Console Port (gamepad)

Console Port's support for Forever is new. Patchwerk fixes what it doesn't handle yet:

- **Open Game Menu works.** On Forever the game menu button only switched the gamepad cursor on and off. Patchwerk turns off the game's automatic gamepad cursor (`GamePadCursorAutoEnable`), which is what gets in the way; your old value is put back if you turn the fix off.
- **Forever's own gamepad buttons no longer override yours.** Switch to Cursor, the radial menu, ping and the targeting modifiers are cleared from any button you bind in Console Port, and can be bound from Console Port's binding list instead.
- **Extra Action Button can be bound** (Forever has the button but no binding for it).
- **Item menu equips into the right slot**: robes, held off-hand items, bows, guns, wands, thrown weapons and relics.
- **Interact works from a ring** ("Interact (tap)").
- **Target Friendly / Target Hostile** hold buttons no longer raise a blocked-action error.
- **The game's bag bar and micro menu come back** when Console Port's toolbar isn't using their buttons (Console Port hides them for good on Forever). Has its own switch.
- Smaller repairs: tooltips for the game's action buttons under the interface cursor, the key ring slot on characters without one, an error when dragging the on-screen keyboard, and switching between gamepad and mouse-and-keyboard interface mid-session.

Settings: the **Console Port on Forever** section of the settings page. `/patchwerk consoleport` prints diagnostics.

## For MelloUI's Route

Additions to MelloUI's route planner. MelloUI's road data is not included, read or copied.

(For a route planner that needs no MelloUI at all, see its sister addon, **Patchwerk Forever: Wayfarer**.)

- **First route sooner.** The road data loads behind the loading screen and the road map is built straight after login.
- **Prefer roads, avoid swimming.** Shortcuts across open ground and through water must be clearly shorter to win.
- **Learn only real paths.** Route no longer learns a path while you drop off a ledge, swim, fly or run as a ghost.
- **Keep to city streets.** Nothing is learned inside the capitals, and what was learned there is forgotten at login, so MelloUI's own walked streets and lifts are used. *This removes those points from the paths Route saved for you.*
- **Blocked spots.** When you can't follow the trail, the stretch ahead is marked blocked for all your characters. You can also mark one by hand, undo the last, and ask what the trail ahead is made of (`/patchwerk route why`).
- **Hearthstone and teleport suggestions.** Landing places are learned as you use them; when one would get you to the destination clearly sooner, you are told and given a button.
- **Next guide steps.** With RestedXP Guides, the world map and the minimap show a fainter trail on through the next few steps.
- **Quest run.** Routes through your tracked quests in a short order, with the later stops shown on the world map and the minimap too.

Settings: the **MelloUI Route** section of the settings page. The actions can be bound in Console Port or used in macros (`/click PatchwerkRouteQuestRun`, `PatchwerkRouteNextStop`, `PatchwerkRouteBlock`, `PatchwerkRouteUnblock`, `PatchwerkRouteTravel`).

Not possible from outside MelloUI: closing MelloUI's own shipped roads at a blocked spot (Patchwerk tells you when a route still crosses one), and choosing routes by mount speed.

## Other

- **MelloUI and EllesmereUI game menu buttons** no longer sit on top of each other.
- **MelloUI trimmed to Route and the Quest Tracker** (optional, off by default): the **Only Route And The Quest Tracker** setting, or `/patchwerk mello on`, switches every other MelloUI module off and unticks MelloUI's other addons, for using Route beside another interface addon. It does this once: anything you switch back on in MelloUI afterwards stays on. `/patchwerk mello` lists what is running.

## Commands

| Command | Does |
|---|---|
| `/patchwerk` | lists the active fixes |
| `/patchwerk config` | opens the settings page |
| `/patchwerk set <name> on/off` | changes any setting; `/patchwerk set` lists them |
| `/patchwerk consoleport` | gamepad binding diagnostics |
| `/patchwerk route` | Route settings and state |
| `/patchwerk route set <name> on/off` | changes a Route setting |
| `/patchwerk route run` / `next` / `stop` | quest run |
| `/patchwerk route block` / `unblock` / `blocks clear` | blocked spots |
| `/patchwerk route why` | what the trail ahead is made of |
| `/patchwerk route forget [yards]` | forgets the paths you taught Route around you, at the next login |
| `/patchwerk route shortcut` | looks for a hearthstone or teleport shortcut now |
| `/patchwerk mello [on/off]` | MelloUI trimmed to Route and the Quest Tracker |

## Credits

Patchwerk is not affiliated with the addons it works with. [Console Port](https://github.com/seblindfors/ConsolePort) is by Sebastian Lindfors, [MelloUI](https://github.com/MelloCro/MelloUI) by MelloCro. Patchwerk is under the MIT License.
