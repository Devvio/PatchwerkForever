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
| **Patchwerk Forever: Console Port (Stitch)** | Console Port (gamepad) | The game menu button, Forever's own gamepad bindings, the item menu, interact from rings, the bag bar and micro menu, smaller repairs. |
| **Patchwerk Forever: MelloUI Route (Stitch)** | MelloUI's route planner | Roads ready at login, roads before shortcuts, blocked spots, hearthstone and teleport suggestions, the next guide steps, a quest run. |
| **Patchwerk Forever: Dungeon Journal (Stitch)** | DungeonJournal | The quests of the dungeons you track in the journal become a list to route through, from one quest giver to the next. |
| **Patchwerk Forever: MelloUI (Stitch)** | MelloUI | Keeps its game menu button and EllesmereUI's apart; can trim MelloUI to its Route and Quest Tracker. |

Nothing in those addons' own files is changed: a Stitch hooks its addon while the game runs, so that addon's updates don't undo it. **A fix is meant to be temporary.** When the addon fixes the issue itself, the fix is removed here in the next update. If you notice one that has become unnecessary, please report it.

## Thread: our own tools

Tools made here, needing nothing but this base.

| Addon | What it does |
|---|---|
| **Patchwerk Forever: Routes (Thread)** | A route planner with its own map data: the way to your map pin, tracked quest or RestedXP step, over ground, by flight path, boat and zeppelin. Remembers herb and ore spots. |
| **Patchwerk Forever: Sparkle (Thread)** | A sparkle and a name on the herb, vein, chest or quest object you are coming up to. |
| **Patchwerk Forever: Tracker (Thread)** | A quest tracker: your quests by zone with distances, your guide's steps, quest item buttons, recipes and a gathering list, the focus buttons and My Route. |
| **Patchwerk Forever: Immersive Plainsrunning (Thread)** | For Tauren: as Plainsrunning stacks up, the interface fades away and speed effects rush past; it all comes back when the run ends, a fight starts or you open a window. |
| **Patchwerk Forever: Races (Thread)** | Race courses of your own: checkpoints placed as you ride, a marker on the next one, split times and best runs, courses shared with your party. A beta. |
| **Patchwerk Forever: Globe (Thread)** | The world on a parchment globe you can spin and zoom, with everything the world map shows on it: your route, quests, places, your group, unexplored land and other addons' pins. It can take the map key. |

## Settings

Everything is under **Options → AddOns → Patchwerk Forever**, or `/patchwerk config`, the **Open Options** key binding, or Patchwerk Forever in the minimap's addon list. The first login says once where the options are. Beneath that page, each Stitch you have installed has a page of its own (**Console Port (Stitch)**), and each Thread tool has its pages beside them (**Routes (Thread)**); what is not installed is not listed. Nothing is added to the settings of the addons a Stitch works with.

The first page is Patchwerk's own: his picture, what he has to say, and everything that is sewn on, each part with its version and a button that opens its page. A part that is for an addon you run and is not installed is listed there too, greyed, with whether it is not installed or disabled in the addon list. The base's one switch, **Notify About Missing Addons**, is at its foot. Every other page opens with its name and a line from Patchwerk, and each Thread tool's first page ends with **Reset To Defaults**.

## If you had Patchwerk Forever 1.x

Until 1.0.1 the Console Port and MelloUI fixes were all inside this one addon. From 2.0.0 they are the Stitch addons above. **Install the ones you want**; your settings, blocked spots and everything else saved come back as they were, because they are still kept by this base.

The base tells you once, in chat, when Console Port, MelloUI or DungeonJournal is running and the Stitch for it is not installed. One you have installed but disabled in the addon list is taken as disabled on purpose and is not mentioned. The setting **Notify About Missing Addons** turns the telling off.

## Commands

| Command | Does |
|---|---|
| `/patchwerk` | lists what is installed, with versions, the fixes and whether each is on, and the commands |
| `/patchwerk config` | opens the options |
| `/patchwerk set <name> on/off` | changes a Stitch option; `/patchwerk set` lists them |
| `/patchwerk <fix> ...` | a fix's own commands, listed in its addon's description |

The Thread tools have commands of their own (`/thread`, `/sparkle`, `/tracker`, `/plains`, `/race`).

**Key bindings:** every binding of the family is in one section of its own, **Patchwerk Forever**, under **Options → Keybindings** (or in Console Port's binding list). The base adds one: **Open Options**.

**Reporting a problem:** please leave a comment on the addon's CurseForge page. If something misbehaves, the chat line it prints ("… failed and was skipped", "A problem in …") is what to report.

## For addon authors

A Stitch joins the base in its first file and then uses the base's settings, saved data and fix list through its own table:

```lua
local addonName, ns = ...
if not PatchwerkForever:Link(addonName, ns, 1) then return end
ns:AddSetting({ key = 'myFix', default = true, section = 'My Addon', name = 'My Fix', desc = '...' })
ns:OnSetting('myFix', function(value) ... end)
ns:RegisterFix('myfix', { name = 'My fix', addon = 'TheAddonItFixes' })
```

A Thread tool joins with `PatchwerkForever:Tool(addonName, ns, { saved = 'MyToolDB', name = 'Mine', page = 'Mine (Thread)' })` and lists its settings in `ns.settings`; the base makes its pages and gives it `ns.Get`, `ns.Set`, `ns.On`, `ns.Print`. Either way the TOC needs `## Dependencies: PatchwerkForever`. A tool that wants to know what the player's guide says asks `PatchwerkForever.Guides:Read(count)`: the step, its lines, where it sends you, and the steps after it. RestedXP is read for a start; a reader for another guide addon is registered with `Guides:Register`. A reader with a `Side` function that returns true is a side list: `Guides:Read(count)` passes it over, `Guides:ReadAll(count)` still lists it, and it is followed only once the player selects it. `Guides:Go(info, index)` has the guide move to another step, by the guide addon's own means, and is only for a player's click. `PatchwerkForever.Gather` passes gathering between tools that do not know each other: Routes (Thread) offers its remembered herb and ore spots there (`Offer`), and a tool that lists them asks `Has`, `Near(count)`, `Start(mode, name)`, `Stop` and `State`. `PatchwerkForever.Choice` keeps the one side path the player chose off the main track (`Set('quest', id)`, `Get`, `Is`, `Clear`, `OnChange`): the tracker sets it on a click and the route planner goes there first. `PatchwerkForever.Following` holds what the route planner leads to now (`Set`, `Get`, `OnChange`), so another tool can mark it. `PatchwerkForever.Focus` keeps, for each character, what the route follows by itself (`Get`, `Set`, `Available`, `Next`, `OnChange`), and `PatchwerkForever.MyRoute` the player's own list of stops (`Entries`, `Add`, `Remove`, `Move`, `Order`, `Clear`, `OnChange`); My Route is also the guide reader `route`. `PatchwerkForever.Trails` passes the route planner's drawing to a tool with a map of its own: Routes (Thread) offers its trail, the boats and zeppelins and its recorded nodes there (`Offer`), and the other tool asks `Has`, `List`, `Crossings`, `NodesAround` and `OnChange`. `Icon(addon)` gives the picture a family addon shows in the addon list.

## Credits

Patchwerk Forever is not affiliated with the addons its Stitches work with. It is under the MIT License.
