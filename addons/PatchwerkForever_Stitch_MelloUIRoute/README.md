# Patchwerk Forever: MelloUI Route (Stitch)

**The map said walk. The cliff said otherwise.**

Patchwerk likes MelloUI's Route. Good roads. Honest roads. But it once walked Patchwerk straight off the edge of Thunder Bluff, and Patchwerk is mostly stitches down that side now.

So Patchwerk sewed on a few extras. Roads come before shortcuts through lakes. A spot you cannot pass gets marked, for every character you own. The hearthstone is suggested when it is plainly quicker. The next guide steps, and a run through your tracked quests, are drawn on ahead.

MelloUI's own road data is not in here. Not copied, not even read. Patchwerk sews on. Patchwerk does not take.

Patchwerk wants more roads! Patchwerk wants fewer cliffs!

*Unofficial surgery. Officially questionable directions.*

---

Additions to the route planner of **MelloUI** on **World of Warcraft: Forever**.

**It needs two addons:** [MelloUI](https://github.com/MelloCro/MelloUI) itself, and **Patchwerk Forever**, the base that holds the settings page and the saved data. (Until Patchwerk Forever 1.0.1 these additions were inside that addon; your settings, blocked spots and learned landing places carry over.)

Nothing in MelloUI's own files is changed, and its road data is not included, read or copied.

(For a route planner that needs no MelloUI at all, see **Patchwerk Forever: Routes (Thread)**.)

## What it adds

- **First route sooner.** The road data loads behind the loading screen and the road map is built straight after login.
- **Prefer roads, avoid swimming.** Shortcuts across open ground and through water must be clearly shorter to win.
- **Learn only real paths.** Route no longer learns a path while you drop off a ledge, swim, fly or run as a ghost.
- **Keep to city streets** (off until you enable it). Nothing is learned inside the capitals, and what was learned there is forgotten at login, so MelloUI's own walked streets and lifts are used. *This removes those points from the paths Route saved for you.*
- **Blocked spots.** When you can't follow the trail, the stretch ahead is marked blocked for all your characters. You can also mark one by hand, undo the last, and ask what the trail ahead is made of (`/patchwerk route why`).
- **Hearthstone and teleport suggestions.** Landing places are learned as you use them; when one would get you to the destination clearly sooner, you are told and given a button.
- **Next guide steps.** With RestedXP Guides, the world map and the minimap show a fainter trail on through the next few steps.
- **Quest run.** Routes through your tracked quests in a short order, with the later stops shown on the world map and the minimap too.

Not possible from outside MelloUI: closing MelloUI's own shipped roads at a blocked spot (you are told when a route still crosses one), and choosing routes by mount speed.

## Settings and bindings

The page **MelloUI Route (Stitch)**, in **Patchwerk Forever's options window** (`/patchwerk config`).

Bind these under **Options → Keybindings**, in the **Patchwerk Forever** section, or in Console Port's binding list: **Route: Mark Trail Ahead Blocked**, **Route: Undo Blocked Spot**, **Route: Quest Run**, **Route: Next Quest Run Stop** and **Route: Use Suggested Shortcut**. In a macro: `/click PatchwerkRouteQuestRun` (and `PatchwerkRouteNextStop`, `PatchwerkRouteBlock`, `PatchwerkRouteUnblock`, `PatchwerkRouteTravel`).

## Commands

| Command | Does |
|---|---|
| `/patchwerk route` | Route options and state |
| `/patchwerk route set <name> on/off` | changes a Route option |
| `/patchwerk route run` / `next` / `stop` | quest run |
| `/patchwerk route block` / `unblock` / `blocks clear` | blocked spots |
| `/patchwerk route why` | what the trail ahead is made of |
| `/patchwerk route forget [yards]` | forgets the paths you taught Route around you, at the next login |
| `/patchwerk route shortcut` | looks for a hearthstone or teleport shortcut now |

## Credits

Not affiliated with MelloUI, which is by MelloCro. This addon is under the MIT License.

**Reporting a problem:** please leave a comment on the addon's CurseForge page, with the chat line it printed if there is one.
