# Patchwerk Forever: Stitch (MelloUI)

**Two buttons in one spot. Patchwerk knows about too many parts in one place.**

MelloUI and EllesmereUI each put a button on the game menu. Same place. One on top of the other, like a bad graft. Patchwerk moved one down a little. Both lived.

There is also a pair of scissors. Ask, and Patchwerk trims MelloUI down to its Route and its Quest Tracker, for people who only wanted those two limbs. Patchwerk does not cut unless asked. Patchwerk learned that one the hard way.

Patchwerk wants neat rows! Patchwerk wants sharper scissors!

*A small procedure. The patient barely noticed.*

---

Two things for **MelloUI** on **World of Warcraft: Forever**, for people who run it beside another interface addon.

**It needs two addons:** [MelloUI](https://github.com/MelloCro/MelloUI) itself, and **Patchwerk Forever**, the base that holds the settings page and the saved data. (Until Patchwerk Forever 1.0.1 these were inside that addon; your settings carry over.)

Nothing in MelloUI's own files is changed.

## What it does

- **MelloUI and EllesmereUI game menu buttons** no longer sit on top of each other. Only matters when you run both.
- **MelloUI trimmed to Route and the Quest Tracker** (optional, **off until you ask**): the **Only Route And The Quest Tracker** setting, or `/patchwerk mello on`, switches every other MelloUI module off and unticks MelloUI's other addons, for using its Route beside another interface addon. It does this once for each character's MelloUI profile (MelloUI keeps one a character since 2.1.46): anything you switch back on in MelloUI afterwards stays on. Turning the setting off does not switch anything back on; use `/mello` and the addon list for that.

## Settings and commands

The page **Stitch: MelloUI**, under **Options → AddOns → Patchwerk Forever** (`/patchwerk config` opens the page above it).

| Command | Does |
|---|---|
| `/patchwerk mello` | lists which MelloUI modules are running |
| `/patchwerk mello on` / `off` | MelloUI trimmed to Route and the Quest Tracker |

For additions to MelloUI's route planner itself, see **Patchwerk Forever: Stitch (MelloUI Route)**.

## Credits

Not affiliated with MelloUI, which is by MelloCro, or with EllesmereUI. This addon is under the MIT License.
