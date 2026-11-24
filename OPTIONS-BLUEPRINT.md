# Blueprint: Patchwerk's own options window

Asked for on 2026-11-23, after each tool's pages were folded under their own entry in the game's options list (base 2.9.1). The ask was to investigate a custom, themed options panel. Your answers to the decisions (2026-11-24) are at the end, and the text below follows them.

**Built on 2026-11-24, all five milestones, at your word ("continue until the testing after milestone 5")**, as base 2.10.0 (`Options.lua`, `Window.lua`), with Console Port (Stitch) 2.3.0 (`Options.lua`: Console Port's cursor told of the window), Sparkle 1.5.1, Routes 1.4.1 and Immersive Plainsrunning 1.3.1 (each knows the window as it knew the game's options window) and Dungeon Journal (Stitch) 1.2.2 (one chat line). Every check outside the game passes, and the window has a check of its own in `tools/lua_sparkle.py`. **Tried in the game by you on 2026-11-24 ("the window works"), then committed and uploaded at your word.** What was built differs from the text below in three places:

- **The page left in the game's options does not open the window by itself** when it is shown: it shows the banner, a line and a button, **Open Patchwerk Forever Options**. Opening by itself would have taken the player out of the game's options every time they opened them while it was the page last shown, with no way back to another addon's options.
- **Milestone 5 did not wait for milestone 3 in the game**, as you asked for everything up to the testing. So the gamepad check below came first; you found the window working before it went to CurseForge.
- **The art is a stand-in** (`tools/options_art.py`: a light parchment and a dark leather, from noise). Your pictures go in `art/PatchwerkForever/parchment.png` and `leather.png`; the prompts are at the end of `art/PROMPTS.md`. On the light parchment the window's words are dark ink and rust red, not the cream and gold of the game's dark pages.

### To try in the game

1. `/patchwerk config`: the window opens; drag its title band; Escape closes it; it opens again where it was, at the page last shown.
2. The left column: each part folds open to its pages; the search finds "rumble" and its controls work from the results.
3. Every kind of control on Sparkle: Appearance: tick box, slider (drag it and use its step buttons), dropdown, color swatch (Cancel puts it back), buttons; Show off greys out that kind's rows.
4. **With a gamepad, no Console Port:** does the game's cursor come up in the window, move from control to control, step a slider with A on its step buttons, open a dropdown and pick from it, and does the page scroll as the cursor goes down it?
5. **With Console Port:** the same with its cursor (`/patchwerk consoleport` lists "Options window" among the fixes that took hold).
6. A fight closes the window; Options > AddOns > Patchwerk Forever shows the one page and its button.
7. The Sparkle preview and the Routes step text sample stand beside the window while you change their settings.


## Where things stand

- **The options are the game's own panel** (Options → AddOns → Patchwerk Forever). The base registers every page with the game's `Settings` API:
  - the front page is drawn by us (`Front.lua`, a canvas page: the banner, the parts and their buttons);
  - every other page is a list of the game's own rows (tick box, slider, dropdown, color swatch, button), plus three rows of ours from `Look.xml`: the intro (picture, name, Patchwerk's line), the stitched heading, and the list with buttons (2.9.0).
- **Since 2.9.1** a tool's further pages fold under its first page, so the list on the left is short until opened.
- **One source of truth.** Each tool lists its settings in `ns.settings` (format at the top of `Tools.lua`): the kind of control follows from the entry (`default`, `choices`, `colour`, `button`, `header`, `list`), with `page`, `parent` (greyed out with a tick box), `percent` and `voice`. A Stitch adds its settings with `AddSetting`. The base builds the pages from those lists, so no tool knows how they are drawn.
- **Size.** About 250 settings across the six Threads (Sparkle alone makes about 110 rows, because each kind of sparkle has its own look), plus the Stitches' pages and the base's.

What the game's panel gives us for nothing, and a window of our own would have to make or give up:

| Comes with the game's panel | In our own window |
|---|---|
| Gamepad navigation, with the game's own gamepad cursor, and Console Port's cursor | to be checked and tuned (see Gamepad) |
| Search across all options (the box at the top of the panel) | our own search, or none |
| Scrolling, row layout, tooltips, greying out with a parent | ours to make |
| Dropdowns, sliders with steppers, the color picker | the same widgets can be used inside our window |
| Opening to a page from code (`Settings.OpenToCategory`) | ours |
| Closed in combat, Escape closes it, sound on open | ours |

## What the window would be

**One window of the family's own**, opened by `/patchwerk config`, the **Open Options** key binding and Patchwerk Forever in the minimap's addon list. It is themed in parchment and leather like the front page, and everything in it comes from the same settings lists. No tool changes. It is the only place to change Patchwerk's options (D1): from milestone 5 the game's options list keeps a single Patchwerk Forever page, with a button that opens the window.

```
┌──────────────────────────────────────────────────────────────────┐
│  [banner: Patchwerk at his bench]   Patchwerk Forever        [×] │
├───────────────────┬──────────────────────────────────────────────┤
│ 🔍 Search         │  [icon] Sparkle: Appearance                  │
│                   │  "Every shiny thing gets a sparkle..."        │
│ ▸ Patchwerk       │  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│ ▾ Sparkle         │  Herbs                                       │
│     Names         │   [x] Show                                   │
│   > Appearance    │   Effect          [ Soft Glow        ▾]      │
│     Alerts        │   Color           [■]                         │
│     Loot Wisps    │   Size            ◂ ───●──── ▸  100%          │
│ ▸ Routes          │   Alert Sound     [ None             ▾]      │
│ ▸ Tracker         │   [ Use This Look For All ]                  │
│ ▸ Globe           │  Ore                                         │
│ ▸ Console Port    │   ...                                        │
├───────────────────┴──────────────────────────────────────────────┤
│  [ Reset To Defaults ]                                [ Close ]  │
└──────────────────────────────────────────────────────────────────┘
```

- **Left:** the parts, each with its icon, folding open to its pages, as in the game's list since 2.9.1. The front page's content (what is sewn on, missing parts, the base's switches) is the first entry.
- **Right:** the page. The intro and stitched headings already drawn by `Look.lua` move over as they are; then one row a setting, scrolling.
- **Bottom:** Reset To Defaults for the part shown (asks first, as now), and Close.
- **Movable**, its place and size kept. Escape closes it. It follows the interface scale.
- **A live preview stays possible:** Sparkle's preview stands beside the options window when there is room. It then has to know our window as well as the game's.

### The rows

Built from each entry of `ns.settings`, as `Tools.lua` builds the game's rows now:

| Entry | Row |
|---|---|
| `default` true/false | tick box with its name; tooltip from `desc` |
| `default` a number | slider with steppers and its value at the right (`percent`: "100%") |
| `choices` | dropdown |
| `colour` | color swatch opening the game's color picker |
| `button` | a button |
| `header` | the stitched heading (Look.lua) |
| `list` | the list with buttons, a page at a time (Look.lua, 2.9.0) |
| `parent` | greyed out while that tick box is off |

**Values** go through the tool's own `Get`/`Set`, as the game's rows do now. Until milestone 5 the game's pages are still there and read the same values, so a change in one shows in the other.

### Gamepad

This is the part that decides whether the window is worth it.

- **Forever's own gamepad cursor** moves between buttons on screen by itself. The game's options rows are tuned for it (`SmartNavigation_*` calls in `Blizzard_SettingControls.lua`: where the cursor sits on a row, which parts it skips). A window of ours made from the game's standard buttons, tick boxes and sliders is likely to be reachable. Where the cursor lands, and whether a slider moves with the stick, has to be checked in the game.
- **Console Port's cursor** also finds standard buttons on any frame that is shown. Console Port (Stitch) can tell it about our window if it needs to: a few lines in the Stitch, not in the base.
- **Plan for it:** milestone 3 is only this, tried with a pad, with and without Console Port. There is no fallback: the game's pages go in milestone 5, so the window must work well with a pad before that. Milestone 5 waits until it does.

### Art

- **Our own art only.** No game art is copied (the family's rule), so the dressing has to be drawn, the way the family's icons are: a parchment page, a leather or canvas left column, a stitched border and the banner already in `Media/banner.tga`.
- **How it gets in:** made as PNGs in `art/PatchwerkForever/options/`, turned into the game's pictures by `art.py`, kept small (the base's zip is 1.4 MB now).
- **The game's own widgets** (buttons, sliders, dropdowns) keep their look on the parchment. Redrawing them would mean making each control from scratch (D3).

### Combat

The game's panel won't open in combat; ours follows the same rule. It closes when combat starts and says so once ("Options cannot be opened in combat."). Some settings touch frames the game protects (Tracker's Hide Default Tracker, Console Port's bindings), and changing those in combat would fail anyway.

## Milestones

1. **The window.** Frame, title, left column of parts and pages, the page area with intros and headings, scrolling, opened by `/patchwerk window` only. Rows are names only. Checked in the test harness: every part and page is listed, and every entry of every tool has a row.
2. **The controls.** Every kind of row from the table, `parent` greying, Reset To Defaults, the lists. Values kept in step with the game's pages. Checks: a click changes the setting and the game's row reads it, reset, greying, the two lists.
3. **Gamepad.** Forever's gamepad cursor and Console Port's, tried in the game. Fix where the cursor lands, skip what it should not stop on, and check that sliders move with the stick. Console Port (Stitch) gets its few lines if needed.
4. **Dressing and comfort.** The art, search across all parts (names and descriptions), remembering the last page, sounds on open and close, size and place kept.
5. **The switch.** Only once milestone 3 has passed in the game. `/patchwerk config`, Open Options and the minimap entry open our window (D2). The game's per-tool and Stitch pages are no longer registered. The game's list keeps one page, Patchwerk Forever, with a button that opens the window. Saved values carry over unchanged, since they live in each tool's saved data. READMEs and changelogs, and the base goes to 2.10.0. The tools' API is unchanged: they declare their settings as before.

Rough size: 1,200 to 1,800 lines of Lua in the base, in new files (`Window.lua`, `Rows.lua`, `Window.xml`), plus the art. Each milestone fits one session; milestone 3 needs you at the game with a pad.

## Risks

- **Gamepad.** As above. With no fallback, milestone 3 has to pass before the switch. Mitigation: it comes before the art, so little is spent before we know.
- **The game's options search** no longer finds Patchwerk's settings after the switch. Mitigation: our own search (D6) arrives in milestone 4, before the switch.
- **Players used to the old pages** find one Patchwerk page in the game's list that opens the window, and the changelog says where everything went.
- **Taint.** The window is our own frame and touches nothing of the game's panel. The color picker and dropdown menus are the game's and are made to be used by addons. Nothing protected is changed in combat.
- **Which dropdown the client has.** Forever's shared templates include the modern dropdown (`WowStyle1DropdownTemplate` with `MenuUtil`) and the old `UIDropDownMenu`. Which one behaves well with the gamepad cursor is checked in milestone 2.
- **Upkeep.** A new kind of setting has to be made twice: once for the game's page, once for ours. The table of kinds is short and changes rarely (the last was `list` in 2.9.0).

## Your answers (2026-11-24)

- **D1. Only our window.** The game's per-tool and Stitch pages are removed; the game's list keeps one Patchwerk Forever page that opens the window.
  - **With no fallback for pads:** the window must pass the gamepad check (milestone 3) before the switch.
  - **The game's pages stay until milestone 5,** so options can still be changed while the window is built and tried.
- **D2. Our window opens by default** from `/patchwerk config`, the Open Options key binding and the minimap's addon list.
- **D3. The game's own widgets on our parchment.**
- **D4. Parchment and leather,** like the front page and the Globe.
- **D5. A folding list of parts and pages** down the left.
- **D6. Search, yes,** in milestone 4: setting names and descriptions across all parts; picking a result opens its page. It replaces the game's options search for our settings.
- **D7. All parts,** the Stitches included.
- **D8. You draw the main pieces** (parchment page, left column, frame) as PNGs. The tools make the stitches and borders and turn everything into the game's pictures.
