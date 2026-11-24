# Patchwerk Forever: Dungeon Journal (Stitch)

## 1.2.2

- The line that says Route Dungeon Journal Quests is disabled points to `/patchwerk config`, where Patchwerk Forever 2.10.0 keeps the options.

## 1.2.1

- **Now named Patchwerk Forever: Dungeon Journal (Stitch)**: the name comes first and what kind of addon it is after it, in brackets (it was Stitch (Dungeon Journal)). The options page is named the same way.

## 1.2.0

- A journal quest in My Route shows its zone.
- **Skips can be taken back.** `/tracker back` and Previous Step in the tracker take back the last skip, or the last stop you brought to the front. The first skip of a session says how. When every stop is skipped, the key binding (or `/patchwerk dj`) brings them all back.
- **The stop you click leads.** A click on the stop shown next skips the one you are on and leads to the one you clicked, not to a third that happens to be nearer.
- **The lead does not flip.** The stop that leads keeps the lead unless another is clearly nearer, so two stops about as near as each other no longer take turns as you walk, each turn a new trail.
- **The journal's map arrow on a listed stop is that stop**, not a second one beside it: it keeps the stop's own words and can be skipped. An arrow elsewhere can be skipped too now, and no step is numbered past the total.
- **It says why the list is empty**: no dungeon tracked, every quest turned in, the rest of the work inside the dungeon (with the counts), the setting disabled, the journal not running, or its data not found.
- `/patchwerk dj` takes `on`, `off` and `status`; alone it still starts or stops. Starting says how many stops there are and which is first. The binding is now called **Toggle Dungeon Journal Route** (your saved key is kept) and is under **Patchwerk Forever** in Key Bindings.
- **Dungeon Journal Before RestedXP** is now called **Dungeon Journal First** (it is saved as before). Its chat lines carry a colored tag of their own.
- DungeonJournal is now a required dependency, as the description always said: without it this addon does not load, and the addon list shows what is missing.
- With a Patchwerk Forever too old for it, it now names itself and the version it needs (2.4.0 or later).

## 1.1.0

- **The journal's quests can go in My Route** (with Patchwerk Forever 2.6.0): a quest not yet picked up is routed to where the journal says it starts, or to the quest that must be done first; once you take it, it is a quest in your log.
- **The Dungeon Journal can be your focus**, chosen in Tracker (Thread) or Routes (Thread), while the journal is running and Route Dungeon Journal Quests is enabled.

## 1.0.2

- **No more trips to a hand-in before the quest is done.** The Dungeon Journal points its own map arrow at a quest's hand-in as soon as the quest is in your log, and the list followed that arrow first. An arrow to a hand-in is now followed only once that quest is finished (seen with the Wailing Caverns quests). Its other points, and the list's own stops, are as before.

## 1.0.1

- With no RestedXP guide loaded, the Dungeon Journal list no longer becomes the main route by itself. It is followed only while you select it, unless Dungeon Journal Before RestedXP is enabled. Needs **Patchwerk Forever 2.5.0**; with an older one it behaves as before.

## 1.0.0

The first release.

- The quests of the dungeons you track in DungeonJournal become a list to route through: where to accept each, and where to turn it in once it is done.
- Tracker (Thread) lists it beside your levelling guide; click it and Routes (Thread) leads you from one stop to the next, nearest first.
- A quest that needs another done first sends you to that one. A spot you point the journal's own map arrow at comes first.
- A binding and `/patchwerk dj` start and stop it without a mouse.
- A setting makes it the main route ahead of RestedXP, for a session of dungeon quests.
- Needs **Patchwerk Forever 2.4.0** or later and **DungeonJournal**. Nothing of DungeonJournal is changed or copied.
