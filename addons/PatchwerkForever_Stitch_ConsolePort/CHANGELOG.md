# Patchwerk Forever: Console Port (Stitch)

## 2.2.1

- **Now named Patchwerk Forever: Console Port (Stitch)**: the name comes first and what kind of addon it is after it, in brackets (it was Stitch (Console Port)). The options page is named the same way.

## 2.2.0

- **Open Game Menu Directly says so** when it turns off the game's automatic gamepad cursor, and when it puts it back. It stays on by default.
- **The binding-change lines** (Report Binding Changes) are said through Patchwerk, as "Patchwerk Console Port: ...", like every other line of this addon, instead of through Console Port's own log.
- **`/patchwerk consoleport` lists which fixes took hold and which did not** (not needed here, or Console Port has changed), and `/patchwerk` shows how many are applied.
- With a Patchwerk Forever too old for it, it now names itself and the version it needs.

## 2.1.0

- **Keep The Menu Ring** (on at first): since Console Port 3.3.14 its large game menu ring opens only while its Game Menu setting is on and the game's own gamepad interface is off, so a ring bound to a button stopped opening. It opens from its binding again, as up to 3.3.13. Console Port's game menu itself is left as Console Port has it. Turn it off to have Console Port's own behaviour.
- **The menu ring has its buttons again.** Console Port 3.3.14 closes the ring while setting it up when it starts out shut, with a call (RunAttribute) that Forever's frames lack outside the secure environment; the setup failed there ("attempt to call a nil value", Ring.lua:209) before adding the buttons, so the ring opened empty. The ring is given that call, done through its own secure Execute, and a setup that failed is finished. This part is always on.
- `/patchwerk consoleport` says whether the menu ring opens and what it holds.

## 2.0.1

- Its options page opens with its picture and a line from Patchwerk, on Patchwerk Forever 2.2.0. Nothing changes in what it does.

## 2.0.0

First release as an addon of its own. Until Patchwerk Forever 1.0.1, the Console Port fixes were part of that addon; its history up to then is in Patchwerk Forever's changelog.

- Needs **Patchwerk Forever 2.0.0** or later (the base), which holds the settings page and the saved data.
- Nothing changed in what it does. Your settings and saved data from 1.x are used as they are.
- An icon in the game's addon list.
