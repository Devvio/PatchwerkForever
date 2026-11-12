# Patchwerk Forever

**Every monster needs a table to be stitched on.**

Patchwerk has a laboratory now. One slab, one lantern, one very large needle case, and shelves that go all the way up.

Patchwerk Forever is the slab. By itself it does nothing at all, which Patchwerk finds restful. Everything else gets laid out on it: the settings, the saved bits, the labels on the jars.

There are two drawers. **Stitch** is for other people's addons: what broke gets sewn shut, and what was missing gets sewn on. **Thread** is for the things Patchwerk made himself, out of whole cloth and spare parts.

Take only the pieces you want. Patchwerk does not judge an unfinished monster.

Patchwerk wants more drawers! Patchwerk wants more thread!

*One slab. Many questionable procedures.*

---

*Named for Naxxramas's stitched-together abomination: a patchwork, for Forever.*

The **base** of the Patchwerk Forever addons for **World of Warcraft: Forever**. It holds what they share: one home for their settings, their saved data, the `/patchwerk` command and their art. **By itself it does nothing.** What it does comes as addons of their own, on two tracks, and you install only the ones you want:

## Stitch: sewn onto other people's addons

Fixes and additions for addons you already use. Each needs this base and the addon it is for.

| Addon | For | What it does |
|---|---|---|
| **Patchwerk Forever: Stitch (Console Port)** | Console Port (gamepad) | The game menu button, Forever's own gamepad bindings, the item menu, interact from rings, the bag bar and micro menu, smaller repairs. |
| **Patchwerk Forever: Stitch (MelloUI Route)** | MelloUI's route planner | Roads ready at login, roads before shortcuts, blocked spots, hearthstone and teleport suggestions, the next guide steps, a quest run. |
| **Patchwerk Forever: Stitch (MelloUI)** | MelloUI | Keeps its game menu button and EllesmereUI's apart; can trim MelloUI to its Route and Quest Tracker. |

Nothing in those addons' own files is changed: a Stitch hooks its addon while the game runs, so that addon's updates don't undo it. **A fix is meant to be temporary.** When the addon fixes the issue itself, the fix is removed here in the next update. If you notice one that has become unnecessary, please report it.

## Thread: our own tools

Tools made here, needing nothing but this base.

| Addon | What it does |
|---|---|
| **Patchwerk Forever: Thread (Routes)** | A route planner with its own map data: the way to your map pin, tracked quest or RestedXP step, over ground, by flight path, boat and zeppelin. Remembers herb and ore spots. |
| **Patchwerk Forever: Thread (Sparkle)** | A sparkle and a name on the herb, vein, chest or quest object you are coming up to. |

## Settings

Everything is under **Options → AddOns → Patchwerk Forever**, or `/patchwerk config`. Beneath that page, each Stitch you have installed has a page of its own (**Stitch: Console Port**), and each Thread tool has its pages beside them (**Thread: Routes**); what is not installed is not listed. Nothing is added to the settings of the addons a Stitch works with.

## If you had Patchwerk Forever 1.x

Until 1.0.1 the Console Port and MelloUI fixes were all inside this one addon. From 2.0.0 they are the Stitch addons above. **Install the ones you want**; your settings, blocked spots and everything else saved come back as they were, because they are still kept by this base.

The base tells you once, in chat, when Console Port or MelloUI is running and the Stitch for it is not installed. One you have installed but unticked in the addon list is taken as switched off on purpose and is not mentioned. The setting **Tell Me About Missing Parts** turns the telling off.

## Commands

| Command | Does |
|---|---|
| `/patchwerk` | lists what is installed, with versions, and the fixes that are active |
| `/patchwerk config` | opens the settings |
| `/patchwerk set <name> on/off` | changes a Stitch setting; `/patchwerk set` lists them |
| `/patchwerk <fix> ...` | a fix's own commands, listed in its addon's description |

The Thread tools have commands of their own (`/thread`, `/sparkle`).

**Reporting a problem:** if something misbehaves, the chat line it prints ("… failed and was skipped", "a problem in …") is what to report.

## For addon authors

A Stitch joins the base in its first file and then uses the base's settings, saved data and fix list through its own table:

```lua
local addonName, ns = ...
if not PatchwerkForever:Link(addonName, ns, 1) then return end
ns:AddSetting({ key = 'myFix', default = true, section = 'My Addon', name = 'My Fix', desc = '...' })
ns:OnSetting('myFix', function(value) ... end)
ns:RegisterFix('myfix', { name = 'My fix', addon = 'TheAddonItFixes' })
```

A Thread tool joins with `PatchwerkForever:Tool(addonName, ns, { saved = 'MyToolDB', name = 'Mine', page = 'Thread: Mine' })` and lists its settings in `ns.settings`; the base makes its pages and gives it `ns.Get`, `ns.Set`, `ns.On`, `ns.Print`. Either way the TOC needs `## Dependencies: PatchwerkForever`. `Icon(addon)` gives the picture a family addon shows in the addon list.

## Credits

Patchwerk Forever is not affiliated with the addons its Stitches work with. It is under the MIT License.
