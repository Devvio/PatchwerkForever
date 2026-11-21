# Patchwerk Forever

## 2.8.0

- **The family's addons are named the other way round**: the name first and the kind after it, in brackets. Patchwerk Forever: Routes (Thread), Patchwerk Forever: Console Port (Stitch), and so on; they were Thread (Routes), Stitch (Console Port). Their options pages are named the same way, and the list of the family on the first page too.
- **A new tool, Patchwerk Forever: Globe (Thread)**: the world on a parchment globe you can spin and zoom, with everything the world map shows on it. It is an addon of its own, listed with the others.
- For addon authors: `PatchwerkForever.Trails` passes a route planner's drawing to tools that do not know it. Routes (Thread) offers its own there (`Offer`); a tool that draws a map of its own, as Globe (Thread) does, asks `Has`, `List()` (the trail being followed and the ones after it, in pieces with their colours), `Crossings()` (the boats and zeppelins, with their stops and the way they go), `Lifts()` (where the lifts it knows stand), `NodesAround(map, x, y, reach, fn)` (the recorded herb and ore nodes near a place) and `OnChange`.

## 2.7.1

- **My Route puts a hand-in off for nearer work.** When the stop you are on is a finished quest to turn in, and another quest's objective or a quest to pick up further down the list is clearly nearer (15 yards, or 15 percent when that is more), the route goes there first and comes back for the hand-in. A hand-in you click or choose with Go Here First is not put off.

## 2.7.0

- For addon authors: `Following:SetTravel(words)` (the way there, in words, kept as `info.travel` until the destination changes), `Guides.ZoneName(uiMap)` and `Guides.QuestZone(id)`; My Route's stops carry their `zone`, and a part's `Kind` can give one as the fifth answer of `Place`.
- **Key bindings have a heading.** Every binding of the family is now in one section of its own, **Patchwerk Forever**, under Options → Keybindings, instead of unnamed among every other addon's. Your saved bindings are kept.
- **Open Options**, a new key binding, and Patchwerk Forever in the minimap's addon list both open the options. The first login says once where the options are.
- In combat, every way of opening the options says "Options cannot be opened in combat." instead of a vague line or nothing.
- **The front page**: each part's line uses the whole row and wraps to two lines instead of being cut off; Patchwerk's line on the picture stays clear of the candles; the tick box makes the game's sound, and its tooltip shows the name above the description like the other pages, with the label part of what takes the click. A part you have disabled reads "Disabled in the addon list."
- **The Reset To Defaults button** reads "Reset", and its question says that positions and saved data are not changed.
- **Chat lines** read "Patchwerk: ..." for the base and "Patchwerk Console Port: ..." for a Stitch. `/patchwerk` lists its commands one to a line, says "options" where it said "settings", answers a wrong value with a usage line, and lists each fix as on, off or waiting. A disabled part is "installed but disabled".
- An error in a Thread tool is said once for each different error, up to three under one label, instead of once a label, so a second problem is not hidden behind the first.
- **Percent sliders** show "100%" where a tool marks a setting as a percentage.
- For addon authors: `PatchwerkForever.Following` (`Set`, `Get`, `OnChange`): the route planner says there what it leads to, and another tool can mark it. A setting may carry `percent = true`. The base defines `BINDING_CATEGORY_PatchwerkForever`, the category every part's Bindings.xml uses. The API number stays 5: an older part simply does not use these.

## 2.6.0

- **Focus**: what the route follows, chosen by you and kept for each character: Auto (your guide and quests, as before), RestedXP, the Dungeon Journal, Quests or My Route. Routes (Thread) follows it and Tracker (Thread) shows its buttons; a quest you click and your map pin still come first.
- **My Route**: your own list of stops for each character, followed in your order: quests in your log, Dungeon Journal quests not yet picked up, and map spots. A quest handed in or abandoned leaves it by itself; a journal quest you pick up becomes a quest in your log.
- For addon authors (API 5): `PatchwerkForever.Focus` (`Get`, `Set`, `Available`, `Name`, `Next`, `OnChange`); `PatchwerkForever.MyRoute` (`Entries`, `Add`, `Has`, `Remove`, `Move`, `Order`, `Clear`, `OnChange`, and `Kind` for a part that knows where quests are picked up), which is also the guide reader `route`; `Choice:OnChange`; `Guides.QuestPlace(id)` and `Guides.ShortOrder(list, where)`; a reader's optional `Running` function, for whether it can be chosen as a focus with nothing to say yet.

## 2.5.0

- **Side lists.** A list that a part marks as a side list, such as the Dungeon Journal quests, is still listed but is no longer followed as the main route by itself. It is followed once you select it.
- For addon authors: a reader's `Side` function. `Guides:Read(count)` passes a side list over; `Guides:Read(count, id)` and `Guides:ReadAll(count)` give it, marked `side = true`. An older part ignores it, so the API number stays 4.

## 2.4.1

- The RestedXP reader also gives where a "fly" step flies to, so Routes (Thread) can tell whether you have that flight point.

## 2.4.0

- **More than one guide at a time.** The guides service can hold a levelling guide and a second list beside it (the Dungeon Journal's quests, through its new Stitch). The first is the main route; another is followed while you select it.
- Knows about **Patchwerk Forever: Dungeon Journal (Stitch)**, and tells you once if DungeonJournal is running without it.
- For addon authors: `Guides:Read(count, id)`, `Guides:ReadAll(count)`, a reader's `Leads`, and `Choice:Set('guide', id)`. The base's API number is now 4.

## 2.3.0

- **Reset To Defaults.** Each Thread tool has a button at the foot of its first options page that puts all of its options back to their defaults, after asking. Positions and saved data are not changed.

## 2.2.0

- **A gathering service**: Routes (Thread) offers its remembered herb and ore spots through the base, and the tracker lists them and starts a round, without either tool knowing the other.
- The guides service also gives every step after the one you are on (`after`), the items a step wants used (`items`), and can have the guide move to another step when the player clicks one (`Guides:Go`), by the guide addon's own means.
- **A choice**: a quest picked in one tool (a click in the tracker) is kept by the base and followed in another (the route planner) as a side path off the main track, until it is cleared or the quest leaves the log (`PatchwerkForever.Choice`). One side path at a time: choosing a quest ends a gathering run, and a run clears the choice.
- **The options pages are dressed.** Patchwerk Forever's first page is drawn: the picture of Patchwerk at his bench, a line in his voice, every part that is installed with its picture, version and a button to its page, the parts you are missing, and the base's own switch. Every other page opens with its name, its picture and a line from Patchwerk, and its sections have stitched headings.
- Setting names and tooltips across the family use the words the game and other addons use (Font Size, Scale, Opacity, Show, Hide, Enable), in Title Case like the game's own options. Patchwerk's voice is kept to the line at the top of each page.
- A client that will not take these pieces gets the plain pages as before.
- The base's API number is now 3.

## 2.1.0

- **A guides service.** The base now reads the guide you are running (RestedXP, for a start) for any of the Thread tools that want it: the step you are on, its lines, where it sends you, and the steps after it. Routes (Thread) uses it from 0.13.0, where it had a reader of its own. Nothing of the guide addon is changed, and with none running the service says nothing.
- For addon authors: `PatchwerkForever.Guides:Read(count)`, and `Guides:Register(id, reader)` for another guide addon. The base's API number is now 2.

## 2.0.0

Patchwerk Forever is now a base with separate addons on two tracks, so you install only what you use: **Stitch**, what is sewn onto other people's addons, and **Thread**, our own tools.

- **The fixes moved out, to Stitch.** The Console Port fixes, the MelloUI Route additions and the MelloUI tweaks are addons of their own: *Patchwerk Forever: Console Port (Stitch)*, *Patchwerk Forever: MelloUI Route (Stitch)* and *Patchwerk Forever: MelloUI (Stitch)*. Each needs this base. **If you had 1.x, install the parts you want**; nothing else changes in what they do.
- **Your settings and saved data carry over**: they are still kept by the base (blocked spots, learned landing places, cleared bindings, every setting).
- The base tells you once, in chat, when Console Port or MelloUI is running and the part for it is not installed. New setting: **Tell Me About Missing Parts**.
- **Thread: our own tools join the base too.** *Patchwerk Forever: Routes (Thread)*, the route planner, and *Patchwerk Forever: Sparkle (Thread)* keep their settings on pages of their own under Patchwerk Forever's.
- `/patchwerk` now lists what is installed, with versions, before the active fixes.
- The settings page is made at login and is always there, with a page beneath it for each Stitch installed (Console Port (Stitch), ...) and the Thread tools' pages beside them.
- An icon in the game's addon list, for the base and for each part.
- For addon authors: the base's API is the global `PatchwerkForever`: `Link` for a Stitch, `Tool` for a tool (see the README).
- Removed: the one-time carrying over of settings from before 1.0.0.

The parts that were in 1.x, for reference, are described below as they were.

## 1.0.1

Checked against MelloUI 2.1.44 (Console Port is still 3.3.13).

- MelloUI 2.1.41 to 2.1.44 changed nothing that Patchwerk's Route additions build on; they work as before.
- **Next guide steps** now follows MelloUI's new Addons page: a guide addon switched off there (Use with MelloUI) no longer has its next steps drawn.

## 1.0.0

First public release, for World of Warcraft: Forever 1.60.1. Made against Console Port 3.3.13 and MelloUI 2.1.40.

### Settings
- Patchwerk Forever has its own page in the game's options (Options → AddOns, or `/patchwerk config`). Nothing is added to Console Port's or MelloUI's settings.

### Console Port
- Open Game Menu opens the game menu instead of toggling the gamepad cursor.
- Forever's native gamepad bindings are cleared from buttons bound in Console Port, and are bindable from its binding list.
- Extra Action Button is bindable.
- Item menu equips robes, held off-hand items and ranged weapons into the right slot.
- Interact works from rings as "Interact (tap)".
- Target Friendly / Target Hostile no longer raise a blocked-action error.
- The game's bag bar and micro menu are put back when Console Port's toolbar doesn't use them.
- Repairs for action button tooltips under the interface cursor, the key ring slot, the on-screen keyboard and interface-style switches.

### MelloUI Route
- Road data preloaded and the road map built at login.
- Prefer Roads, Avoid Swimming, Learn Only Real Paths, Keep To City Streets.
- Blocked spots: learned automatically, marked by hand, shared across characters.
- Hearthstone and teleport suggestions.
- A trail through the next guide steps on the world map and the minimap.
- Quest run through tracked quests.

### Other
- MelloUI's and EllesmereUI's game menu buttons no longer overlap.
- Optional: MelloUI trimmed to Route and the Quest Tracker (`/patchwerk mello on`). It trims once; what you switch back on in MelloUI stays on.
