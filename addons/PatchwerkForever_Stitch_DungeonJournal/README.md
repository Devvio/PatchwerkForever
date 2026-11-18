# Patchwerk Forever: Stitch (Dungeon Journal)

**The big book has a list. Patchwerk has legs. Together: jobs get done.**

There is a book that knows every job in every dungeon. Who gives it. Where they stand. Very clever book. But the book does not walk. The book sits there, being right about everything, while Patchwerk goes the wrong way round a mountain.

So Patchwerk tied a thread from the book to his boots. Now the book says "the man with the job is over there" and the boots go over there. Then the next man. Then the next. Shortest way first, because Patchwerk's feet are large and get tired.

Patchwerk did not tear out any pages. Patchwerk only reads over the book's shoulder.

Patchwerk wants all the jobs! Patchwerk wants them in a sensible order!

*One thread, book to boots. No pages harmed.*

---

For **DungeonJournal** (ForeverDungeonJournal) on **World of Warcraft: Forever**: the quests of the dungeons you track in the journal become a list you can route through, from one quest giver to the next.

**It needs two addons:** DungeonJournal itself, and **Patchwerk Forever** (2.4.0 or later), the base. It is worth little alone: **Thread (Routes)** is what leads you there, and **Thread (Tracker)** is what lists the stops.

Nothing in DungeonJournal's own files is changed, and none of its data is in this addon. Its places are read from it while it runs.

## What it does

- **Track a dungeon in the journal** as you always do. Its quests become stops: where to **accept** each one, and where to **turn it in** once it is complete.
- **Thread (Tracker) lists the stops** in a section of their own, beside your leveling guide: the stop you are on, and the next few.
- **Click that section** and **Thread (Routes)** leads you along the list in its selected-route color, nearest stop first, moving on as you accept or turn in each quest. Click it again to go back to your guide. The stop that leads keeps the lead until another is clearly nearer.
- **A quest that needs another done first** sends you to that one.
- **A quest you hold and have not finished** has no stop: its work is inside the dungeon.
- **Point the journal's own map arrow at something** and that spot comes first; on a listed stop, it is that stop. An arrow to where a quest is turned in counts only once that quest is complete.
- **Skip a stop** from the right-click menu in the tracker, or click the stop shown next to go there instead; skips last until you log out or reload. **Previous Step** or `/tracker back` takes the last one back, and when every stop is skipped the key binding brings them all back.
- **Make the journal your focus** with the Dungeon Journal button above Thread (Tracker) or on the world map, and the route follows the list until you choose another focus.
- **Put its quests in My Route**: right-click a stop in the tracker and choose **Add To My Route**. A quest you have not picked up yet is routed to where it starts; once you take it, it is a quest in your log like any other. Quests of the other faction are never routed to.

## Settings and commands

The page **Stitch: Dungeon Journal**, under **Options → AddOns → Patchwerk Forever**.

| Setting | Does |
|---|---|
| Route Dungeon Journal Quests | offers the list at all |
| Dungeon Journal First | makes the list your main route whenever it has somewhere to send you; off by default, so your guide stays the main route |

| Command or binding | Does |
|---|---|
| `/patchwerk dj` | routes through the list, or goes back to your main route; when the list is empty, says why |
| `/patchwerk dj on` / `off` / `status` | only starts, only stops, or says how many stops there are |
| **Toggle Dungeon Journal Route** (Options → Keybindings, in the **Patchwerk Forever** section, or Console Port's binding list) | the same as `/patchwerk dj`, for a key or gamepad button |

## What it does not do

- It does not know where a quest is done inside a dungeon, or lead you to a dungeon's entrance.
- A quest whose place the journal does not have is left out of the list.
- It reads names inside DungeonJournal that its author may change. If an update of the journal breaks it, the list is simply absent until this addon catches up; nothing else is affected.

## Credits

DungeonJournal is by Exehn. This addon contains none of it. The code and pictures here are under the MIT License. English only.

**Reporting a problem:** please leave a comment on the addon's CurseForge page, with the chat line it printed if there is one.
