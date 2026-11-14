# Polish blueprint

Written 2026-11-14, asked for as "blueprint some polish". It follows `V1.md` and `ROADMAP.md`.
**Nothing here is built.** It is a plan to pick from.

## What this is

A list of the rough edges in what already exists, with the change for each. It holds no new
features: those stay in `ROADMAP.md`, and anything that turned out to be a feature in disguise
was taken out (see [What was left out](#what-was-left-out)).

How it was made:

- Eleven read-throughs of the whole family, each from one angle: the Tracker on screen, the
  Tracker in use, what Routes draws, what Routes says, Sparkle, the base and its options pages,
  the Stitches, wording, the gamepad player and first login, smoothness, and documents.
- A twelfth pass looked for what the eleven had missed: files nobody reported on, the places
  where two addons meet, and things that only show over a whole play session (the GA findings).
- Every report was then checked against the code, and against the Forever client's own UI
  source, by a second reader told to doubt it. 145 were reported. 133 stand after checking,
  many of them corrected or cut down; 25 findings or parts of findings were dropped as wrong,
  already handled, or new features.
- The survivors overlap a good deal. Merged, they come to the 89 items below.

Each item ends with the findings it comes from (TL-2, RT-3 and so on). The full text of each,
with file, line, the code as it stands and the exact change, is in `tools/POLISH-findings.md`.

How to read the tables:

- **Size**: S is under an hour, M a few hours. Nothing here is larger.
- **Game** is marked where the roughness was read from the code and needs a look in the running
  game, before the change (is it really there?) or after it (does it look right?).
- Nothing in this file was tried in the game. The audit only read.

## What is already sound

Worth saying, because the audit looked for these and found nothing to do:

- The Tracker gathers its events and draws at most ten times a second; its frames and lines are
  reused; the item buttons are never touched in combat.
- Route searches run a little each frame and never stall the game; the planner gives way inside
  its own loops.
- Sparkle draws only when the game says something changed, and animates only while a sparkle is
  shown.
- Every slash command and every setting name a README quotes exists in the code. Every TOC has
  the right interface number, group and icon.
- Labels are in Title Case and American spelling almost everywhere; the exceptions are listed
  in pass D.

## The passes

Each pass is a unit that can be built, checked here and then played. They are in the order I
would build them: what you meet every session first, documents last.

### A. What you meet every session

| # | What is rough now | The change | Size | Game | From |
|---|---|---|---|---|---|
| A1 | **Step text repeats, or is missing.** The same guide step fades in again each time RestedXP's arrow moves between spots of one step, and again each time you wander 40 yards from a step you had reached. Yet a new step at the spot you are standing on is not shown at all. | Remember the step last shown (its guide, number and words) and show the text only when that changes, wherever the step is. `/thread step` and the Go binding still show it on request. | M | yes | RT-3, SM-4, RO-5 |
| A2 | **A route that cannot be made says nothing, and is searched for again every 10 seconds.** For a guide step, quest or node with no route, the step text appears with an empty line under it. A gathering run waits on such a node for good. `/thread go` in an area without map data prints nothing at all. | Show "No route found" under the step text. Wait longer between tries (20 seconds, doubling to 2 minutes; at once when you change map or move 300 yards). A gathering run moves on to the next node. The Go command always says why. | M | yes | SM-1, RO-4, RT-8 |
| A3 | **Stop Routing leaves the fainter trail** of upcoming steps on the world map and minimap. | Clear it when the route is stopped. One line. | S | | RO-1 |
| A4 | **"Routing stopped." whatever was stopped.** After stopping a pin or a gathering run the guide takes over half a second later, so the line reads as if it did not work. | Say what was stopped: "Gathering stopped.", "Routing to your map pin stopped.", and for a guide or quest: "Routing stopped. It resumes when the guide step or quest objective changes, or with /thread go." | S | | RT-2 |
| A5 | **On a flight the trail points back** at the flight master you left, for the whole flight. | While on a flight path, draw one straight piece from you to where you land, then the walk on. | S | yes | RO-2 |
| A6 | **A map pin you reached or stopped is routed to again** after the next loading screen, and nothing else is followed until the pin is removed. | Pick an existing pin up only at login and reload. A pin placed at any other time is still caught as now. | S | yes | RT-4 |
| A7 | **A moved tracker can grow from its middle or upward**, so the first heading jumps as lines come and go; and **the Scale slider moves it** across the screen. | Always save a top corner (left or right, whichever half of the screen it is in), in screen units. Place it again when Scale changes. A place saved by an earlier version is converted once. | M | yes | TL-2, TI-1, SM-3 |
| A8 | **Past Max Height the list is cut with no sign of more**, it scrolls only with the mouse wheel, and Route To Next Quest can select a quest that is out of view. | Scroll the selected quest into view when you step to it. Fade the top and bottom edges where there is more. Add Scroll Tracker Up and Scroll Tracker Down bindings. | M | yes | TL-1, TI-3, GP-3 |
| A9 | **A click that skips a guide step says nothing**, and the undo is only a typed command. `/tracker back` can also rewind to a step number from long ago or from another guide. | Print "Skipped step 34. Type /tracker back to undo." Add an Undo Skipped Guide Step binding. Forget the undo when the guide changes. | S | | TI-2, TI-8, TI-11, GP-1 |
| A10 | **Quests and item buttons swap rows** each time two distances cross, which also changes the order Route To Next Quest steps through and which item the binding uses. | Sort by a distance that only moves on a clear change (about 15 percent); the distance shown stays live. | S | yes | TL-4, SM-5 |
| A11 | **With no RestedXP guide loaded, the Dungeon Journal list becomes the main route by itself**, ahead of your tracked quests, though every tooltip and README says it is followed only when you select it. | Let a guide reader say it is a side list. The Dungeon Journal's is one unless Dungeon Journal Before RestedXP is enabled. | M | | ST-1 |
| A12 | **In an instance, both trackers are shown with the default settings.** Keep Default Tracker In Instances is on and Hide In Instances is off, so every dungeon, raid and battleground has two quest lists. | Ours steps aside in an instance while the default tracker is kept there. This reverses a choice you made earlier, so it needs your yes: see [Yours to decide](#yours-to-decide). | S | yes | GA-1 |

### B. Gamepad reach

| # | What is rough now | The change | Size | Game | From |
|---|---|---|---|---|---|
| B1 | **The family's key bindings have no heading.** On this client the Key Bindings page draws a binding header as a blank gap, so Stop Routing, Collapse / Expand Tracker and the rest sit unnamed among every other addon's bindings. | Give every binding of the family a section of its own, "Patchwerk Forever" (the game allows a plain name as the category). Saved bindings are kept. The READMEs that say "under AddOns" change with it. | S | yes | GP-2, DL-7 |
| B2 | **A gathering run and "show the step text again" cannot be bound.** A run starts only from a slash command or a mouse click on the Tracker. | Two Routes bindings: one that starts a gathering run and, pressed again, stops it; and Show Step Text Again. | S | | RT-1, GP-4, RO-6 |
| B3 | **No binding opens the options.** | Add Open Options to the base. Every part's page is one Open button away from there. | S | | BO-4 |
| B4 | **Use Nearest Quest Item does nothing, silently**, when no quest has an item, and also whenever Show Quest Item Bar is unticked. | Keep the binding working with the bar hidden. With nothing to use, show "No quest item to use." in the game's red error text. | S | | TI-9, GP-9 |
| B5 | **An ignore in Sparkle cannot be taken back from a gamepad**, `/sparkle undo` removes the wrong object once you have walked past another, and while sparkles are hidden the binding ignores an object from minutes ago. | Make the binding a toggle on the targeted object. Make undo remove the last ignore. Use a remembered object only for 20 seconds after it was targeted. | S | | SP-3, SP-4, GP-6 |
| B6 | **A key bound to a part that did not load gives a Lua error**, and the line that says why names the folder ("PatchwerkForever_Thread_Tracker needs a newer...") and no version. | Guard each binding. Print the addon's title and the base version it needs. | S | | GP-12, DL-1 |
| B7 | **Fade When Not Hovered ignores your own actions**: with no mouse to hover, the tracker stays dim while you step through it with the bindings. | Wake it on Route To Next / Previous Quest, Collapse / Expand, a gathering click and Reset Position. | S | | TL-9 |
| B8 | **Tooltips say "the key binding" without naming it.** | Name it: "Use Nearest Quest Item", "Ignore Targeted Object", and the option meant by "that option". | S | | WS-5 |
| B9 | **The five MelloUI Route actions have no Bindings.xml**; they can be bound only in Console Port's list. | Add one. *Not something you can try: you do not run MelloUI.* | S | | ST-10 |

### C. Options pages

| # | What is rough now | The change | Size | Game | From |
|---|---|---|---|---|---|
| C1 | **Front page rows cut off nearly every line.** A row has about 210 pixels for a line of 43 to 71 letters. | Let the line use the full row and wrap to two lines; rows go from 48 to 60 high. With all seven parts the page still fits. | S | yes | BO-1 |
| C2 | **Patchwerk's line on the banner can run over the candles** in the picture. | Narrow it from 36 to 26 percent of the banner. | S | yes | BO-2 |
| C3 | **The reset row says "Defaults" on its heading and its button**, beside the game's own Defaults button on the same page. | Button text "Reset", as the game pairs it. The confirm box also says that positions and saved data are not changed. | S | | BO-3 |
| C4 | **The front page's tick boxes are silent**, show the description without the name, and only the small box takes a click. | The game's own tick sound, a tooltip with name and description as on every other page, and the label as part of the target. | S | | BO-5 |
| C5 | **Percent sliders show a bare number** ("100" for Brightness beside "110" for Size). | A "percent" mark on a setting, shown as "100%": fifteen sliders in Sparkle, three in the Tracker, one in Routes. | S | | SP-8 |
| C6 | **Settings stay live when the tick box they depend on is off.** Sparkle's Behind My Character page opens as five sliders that do nothing; its name settings and the Tracker's guide settings and item bar Position are the same. | Make them children of their tick box (Show Object Name, Fade Behind Character, Show Guide Steps, Show Quest Item Bar), so they indent and grey out. | S | | SP-5, GA-6 |
| C7 | **Sparkle's preview does not follow the settings**: you drag a slider, then press Preview again, seven rows down. The preview also lays the name out differently from a real sparkle, ignores Vertical Offset, and is drawn across the option rows. Sparkle: Names has no preview. | The preview follows the settings while the options are open. It is laid out as a real sparkle is and placed beside the options window when there is room. A Preview Name button on the Names page. | M | yes | SP-1, SP-2 |
| C8 | **Step Text sliders show nothing until Preview is pressed again**, and the sample may sit behind the options window. | The sample follows the sliders, and is drawn above the window. | S | yes | RO-7 |
| C9 | **Sparkle's fade-area oval is gone in ten seconds**, while your character is still hidden by the options window. | Keep it for ten seconds after your last change and ten seconds after you close the options. | S | yes | SP-9 |
| C10 | **Headings that do not match what is under them**: the Tracker's "Fading" holds Hide In Instances, its "Size" appears twice; Routes has a "Line Style" heading over a "Line Style" setting; "Sparkle: Looks" sits beside "Tracker: Appearance". | "Visibility"; "Scale And Font"; "Line"; and one word for both look pages (see [Yours to decide](#yours-to-decide)). | S | | WS-12 |
| C11 | **Dropdown choices are in sentence case** ("Soft glow", "By zone (current zone first)") where everything else is Title Case. | Title Case. Only the words shown change; what is saved stays. | S | | WS-8 |
| C12 | **Nothing at first login says where the options are**, and the "two trackers" line sends you to a slash command. | One line, once per account: "Options are under Options > AddOns > Patchwerk Forever." An entry in the minimap's addon list. The two-trackers line names the tick box. | S | yes | GP-5 |
| C13 | **In combat the options do not open, and you are not told why** (one path says "could not be opened here", the front page's Open button says nothing). | "Options cannot be opened in combat." on every path. | S | | BO-7, GP-11, WS-9 |
| C14 | **A disabled part is "Installed, not switched on."** and nothing says where to enable it. | "Disabled in the addon list." on the front page, "installed but disabled" in the `/patchwerk` listing. | S | | BO-10 |

### D. Words

| # | What is rough now | The change | Size | Game | From |
|---|---|---|---|---|---|
| D1 | **Chat prefixes take three forms.** The base's lines read "Patchwerk Console Port is running...", as if that were an addon's name; three Stitches have no colon; the Dungeon Journal's tag is uncolored. | One form: colored tag, colon, a sentence with a capital. "Patchwerk: ..." for the base, "Patchwerk Console Port: ..." for a Stitch. | S | | GP-8, BO-8, WS-4 |
| D2 | **The four command helps are laid out four ways.** `/patchwerk`'s help leaves out `set`, says "settings" where the tools say "options", and answers a wrong value with "Give on or off." | One layout: a heading, one command to a line, everyday ones first, `config` last. "Options" everywhere. A usage line for a wrong value. | S | | GP-11, BO-9, WS-9 |
| D3 | **`/sparkle` alone prints raw game variables** ("Interact 3, InteractRange 10, ...") and does not always say why an object does not sparkle. | `/sparkle` lists the commands, as `/thread` and `/tracker` do. `/sparkle status` gives one plain sentence with the reason. `/sparkle debug` keeps the raw values for reports. | S | | WS-1, SP-7 |
| D4 | **Sentences that read wrong**: "...(inside a building, on a boat, or on one?)."; the gathering lines ("then the next at each"); a map-data failure reported by folder name and a raw code; "To the spot you gave"; the preview's "This is another thing"; "Ignore list cleared (0 object(s))." | Rewritten, each in place. The preview shows a name as a real sparkle would ("Peacebloom", "Copper Vein", "Mailbox"). | S | | RT-7, WS-2, WS-11, RO-10, SP-11 |
| D5 | **One thing, two names.** "Auto-Track Nearest Quest" tracks nothing (it moves the quest arrow). "Follow RestedXP Guide" follows any guide. "Priority" does not say what always comes first. "Print Route In Chat" promises more than it does. "Upcoming Steps" and "Upcoming Steps Shown". "Hide Default Quest Tracker" and "Keep Default Tracker In Instances". "learned" and "discovered". "Test" and "Show" on preview buttons. | One name each: Quest Arrow On Nearest Quest, Follow Guide, Route Priority (with what always comes first in its tooltip), and so on down the list. | S | | WS-7, WS-6, RT-6 |
| D6 | **British spellings in game text**: "colours" (a voice line), "grey", "levelling", "a herb", and "size and colour" in a TOC note. Routes' TOC note says "spots" where everything else says "nodes". | American spelling; "nodes". | S | | WS-10, DL-5 |
| D7 | **`/thread quest` names the wrong thing as followed** when a pin, a gathering run or a selected list is steering, and prints continents as bare numbers. | Report in the order Routes really decides, and name the continents. | S | | RT-5, WS-6 |
| D8 | **Flight points.** The notice tells you to open the flight map, and nothing confirms it was read. `/thread flights` says "0 known, 0 not" before the map data is loaded, and contradicts itself with the setting off. A point discovered before any route was planned is not remembered. | "Flight map read: 14 flight points known on this continent.", once per continent. Load the map data before answering. Remember a discovery whenever it happens. | S | | RT-9, RT-11 |
| D9 | **The Dungeon Journal Stitch has one line for six different reasons its list is empty**, `/patchwerk dj off` starts routing, and the binding's name hides that a second press stops. | Say which reason. Read `on`, `off` and `status`. Name the binding as a toggle. Say how many stops and where the first is. | S | | ST-3, ST-7 |
| D10 | **Stitch wording against the rule**: "switched off", "unticked", Patchwerk's voice in a confirm box (MelloUI); "Dungeon Journal Before RestedXP". | Enable and disable throughout; a plain confirm box. This is ROADMAP A5 with the lines named. *The MelloUI half is not something you can try.* | S | | ST-8 |
| D11 | **Routes names a zeppelin or boat stop "a landing"**: the route summary reads "zeppelin Thunder Bluff > a landing" on both Horde lines to Zephras Isle, and "a landing near Gadgetzan" elsewhere. | Name an unnamed stop by its continent ("Zephras Isle") or "near Gadgetzan", in the tool that makes the data, and make the data again. A small table takes the real names once you have seen them in the game. | S | | GA-2 |

### E. Tracker details

| # | What is rough now | The change | Size | Game | From |
|---|---|---|---|---|---|
| E1 | **Upcoming guide steps wrap onto two or three lines each**, so three upcoming steps can take more room than the step you are on. | One line each, cut with an ellipsis, as the code's own comment intended. | S | yes | TL-3 |
| E2 | **A timed quest flashes every second** for as long as its timer runs, and keeps a faded tracker awake. | The clock line no longer counts as progress. | S | | TL-5, SM-2 |
| E3 | **Sort Order "Completed first" puts completed quests last** while Group Completed Quests is on, which is the default. | With both set, the Ready To Turn In group goes to the top. | S | | TL-6 |
| E4 | **Hovering a row gives no hint of what a click will do.** Nothing says a click on the current guide step skips it, or that a heading folds. | A small tooltip of hint lines on rows and headings ("Click to route to this quest.", "Right-click for more options."). | M | yes | TI-5 |
| E5 | **Unlocking with nothing tracked shows nothing to drag.** The bar names only `/tracker lock`, and the fades dim it while you drag. | Show an empty frame while unlocked. Right-click the bar to lock. Full brightness while unlocked. | S | | TL-8, TI-6, GP-7 |
| E6 | **Auto-Track Nearest Quest stops working** once the game has put the arrow on a newly accepted quest by itself, and after every reload. | Count an arrow the game placed on accept as the option's own to move, and remember it across a reload. | M | | TI-4 |
| E7 | **A selected quest that you untrack in the quest log stays selected**: Routes keeps leading to a quest the tracker no longer lists. | Clear the selection when its quest leaves the watch list, and say "Back to your main route." | S | | TI-7 |
| E8 | **The default tracker may show for half a second** after each loading screen, beside ours. | Hide it at once on entering the world, then again after the usual delay. | S | yes | TI-10 |
| E9 | **The quest item bar can sit off the screen** (tracker at the left edge with the bar on its left). | Move the bar to the other side when there is no room. | S | | TL-10 |
| E10 | **Item buttons have no hover or pressed look**, and the count stays 11 points at every Button Size. | The game's own highlight and pressed textures; the count scales with the button. | S | yes | TL-11 |
| E11 | **A wrapped objective falls back under its dash**, and the timer and party notes wear a dash as if they were objectives. | Draw the dash apart from the text, as the default tracker does; no dash on notes. | M | yes | TL-7 |
| E12 | **The heading's stitched underline stops up to 11 pixels short** of the right edge, and the guide's progress bar has nothing behind it. | Spread the stitches to the edge; a faint track behind the bar. | S | yes | TL-12 |
| E13 | **If the quest list ever failed to draw, the default tracker would stay hidden** with nothing in its place. No such failure is known; this is insurance. | Show the default tracker while ours cannot draw, and say so once. | S | | SM-7 |
| E14 | **Going back to the main route removes the game's quest arrow** instead of putting it back where it was before you selected a quest. With no guide running, the route then leads to the nearest tracked quest, not the one it led to before. | Remember the arrow when you select, and put it back when you un-select (not after a turn-in, and not over an arrow you moved meanwhile). | S | | GA-7 |
| E15 | **The marker bar that "shows what is being followed" is worked out without asking Routes.** The guide step wears it while the trail leads to a map pin, to a quest (Priority set to quests), or nowhere (after Stop Routing). | Routes reports what it follows through the base; the Tracker marks that. A click is then also answered on the next frame, not up to half a second later. | M | | GA-9 |

### F. Routes details

| # | What is rough now | The change | Size | Game | From |
|---|---|---|---|---|---|
| F1 | **The minimap trail is cut to a circle on a square minimap**, though the node icons already follow the square. | Clip to the square when the minimap says it is one. Depends on EllesmereUI reporting its shape; one `/dump` in the game tells. | S | yes | RO-3 |
| F2 | **A selected guide's next steps are drawn in the main route's color**, not the Selected Route Color. | Carry the selection through to the look-ahead trail. | S | yes | RO-8 |
| F3 | **Dotted and dashed trails merge** into a solid line at the wider line widths. | Space them in proportion to the width. | S | yes | RO-9 |
| F4 | **The minimap trail and node icons are redrawn 20 times a second** whether or not anything moved, and step behind a rotating minimap. | Redraw when something changed, and every frame while the minimap turns. Only seen with Rotate Minimap on. | M | yes | RO-11, SM-10 |
| F5 | **Searches for upcoming steps take the same share of each frame as your own route**, in combat too. | A smaller share for the ones that can wait, halved in combat. Worth measuring first. | S | yes | SM-6 |
| F6 | **Gathering runs and the selected quest.** `/thread gather` keeps the selected quest marked, where a click in the Tracker lets it go. Go during a run leaves a destination that never follows the guide. A run that cannot start still drops the selected quest. | Start every run the same way. Go ends the run first. Put the selection back when a run did not start. | S | | RT-10, BO-11 |
| F7 | **While a new destination is being searched for, the old trail stays up in the new destination's color**: select a quest and the trail to your guide step turns the Selected Route Color until the search ends. | Color a trail by the route it belongs to, and draw it fainter while it is being replaced. Same lines as F2. | S | yes | GA-8 |
| F8 | **Selecting a quest can leave the route unchanged, and nothing says so**: a quest with no place on the map, or one selected while a map pin is active. The Tracker marks it and prints "Routing to: ..." all the same. | Routes says why, once: "...has no location on the map, so it cannot be routed to. Your main route continues." or "Your map pin comes first...". | S | | GA-3 |
| F9 | **A character with no gathering profession still gets the Gathering list and runs** to nodes it cannot gather (nodes are shared across your characters). The test Routes uses may not exist on this client at all, in which case every character counts as having both professions. | Ask for professions the way the game's own profession window does. One `/dump IsPlayerSpell` in the game tells how much this matters. | S | yes | GA-4 |

### G. Sparkle details

| # | What is rough now | The change | Size | Game | From |
|---|---|---|---|---|---|
| G1 | **"Above the icon" puts the name at the nameplate's middle**, under or across the game's icon. | Anchor it above the icon when the icon is shown. EllesmereUI may move that frame. | S | yes | SP-10 |
| G2 | **The two game settings Sparkle turns on are put back only when you untick Enable Sparkles**, not when you disable or remove the addon. If the game turns one off, sparkles stop without a word. | Put them back at logout and on again at login. Say once when one had to be turned back on. | S | yes | SP-6 |
| G3 | **Clear Ignore List empties the whole list on one click**, with no question and no way back. | Ask first, from the button; the typed `/sparkle clear` stays immediate. | S | | GA-5 |

### H. Stitches

*None of the Dungeon Journal Stitch has been tried with the real journal yet. H8 and half of
D10 are for MelloUI, which you do not run.*

| # | What is rough now | The change | Size | Game | From |
|---|---|---|---|---|---|
| H1 | **Dungeon Journal, skipped stops.** `/tracker back` answers "could not go back". A click on the next stop can bring a third one forward. Skip every stop and the list is gone until a reload. | Back also takes back a jump; the stop you clicked is the one that leads; the binding brings skipped stops back. | S | | ST-2 |
| H2 | **The journal's own map point is always added as an extra stop.** It can double a listed quest, cannot be skipped, and pushes the numbering past the total ("2, 3, 4" under "Step 1 of 3"). | Fold it into the matching stop when there is one within 15 yards; otherwise let it be skipped; count it. | M | yes | ST-4 |
| H3 | **The first stop is picked afresh by straight-line distance on every read**, so two stops about as near as each other can flip, each flip a new trail and step text. | Keep the stop that leads unless another is clearly nearer (the Tracker's own 0.85 rule). | S | yes | ST-5 |
| H4 | **The Stitch says it needs the journal, but its TOC makes it optional**: without the journal it loads, shows two settings that do nothing, and the addon list shows nothing missing. | Make it a dependency, as in the other Stitches, unless the journal loads on demand (to be read from its TOC first). | S | | DL-6 |
| H5 | **Console Port: Open Game Menu Directly changes a game setting at first login without saying so.** | Say it when it happens, and when it is put back. | S | | ST-6 |
| H6 | **Console Port: binding-change messages go out through Console Port's own logger**, unlike every other line. | Send them through the base, with the same prefix. | S | yes | ST-9 |
| H7 | **Fix status lines have five shapes** under the heading "Active fixes:", which also lists fixes that are off. Nothing shows which Console Port fixes attached and which gave up. | One vocabulary (on, off, waiting). `/patchwerk consoleport` lists the fixes applied and not applied. | M | | ST-11 |
| H8 | **MelloUI Route: Keep To City Streets is on by default and deletes learned points from MelloUI Route's saved paths at login.** | See [Yours to decide](#yours-to-decide). | S | | ST-12 |

### I. Under the hood

| # | What is rough now | The change | Size | Game | From |
|---|---|---|---|---|---|
| I1 | **An error is reported once per label, and many handlers share a label**: after the first message, a different error in another file under the same event is never shown. | Report once per label and message, at most three per label. | S | | SM-9 |

### J. Documents and listings

| # | What is rough now | The change | Size | Game | From |
|---|---|---|---|---|---|
| J1 | **The base's addon-list note and README describe the family without the Tracker and the Dungeon Journal Stitch.** | Add them, word the note so it cannot go stale, and have the release tool check that every part is named in the base README. | S | | DL-2, BO-6, WS-3, GP-10 |
| J2 | **The Tracker README says "Version 1.0"** (it is 1.1), files the no-mouse bindings under "Item buttons", never names Collapse / Expand Tracker, and opens its list with the Dungeon Journal. | Drop the number, add a "Key bindings" section with all the names, list what every player sees first. | S | | DL-3, TI-12 |
| J3 | **The Routes changelog is out of order** (0.14, 0.16, 0.15, 0.13...) and has no title line. | Put it in order; have the release tool check the title and the first entry. | S | | DL-4 |
| J4 | **READMEs describe bindings instead of naming them**, write the options path two ways, list a trail style that does not exist ("flowing"), and say map data loads only for the continent you are on (the first route loads all three). | Names as the game shows them, one path, the real styles, the true loading. | S | | DL-7, SM-8 |
| J5 | **Pieces not yet tried in the game read as finished** on the listings: the Dungeon Journal Stitch, party progress between two trackers, reading the flight map. | One sentence each, removed once it has been played. Only matters if uploaded first. | S | | DL-8 |
| J6 | **READMEs ask for reports and never say where to send them.** | One line in each, naming the place (see [Yours to decide](#yours-to-decide)). | S | | DL-9 |
| J7 | **The repository's own docs** list build names, tags and folders from before the Tracker and the Dungeon Journal Stitch. | Bring them up to date. Reaches no player. | S | | DL-10 |

## Yours to decide

These came up in the audit and are choices, not fixes. My pick is first in each.

1. **A Skip Guide Step binding** (GP-1). One checker kept it (a gamepad has no other way but a
   cursor click); another cut it as a feature you were offered earlier and did not pick.
   *Leave it out;* A9 adds only the undo. Say if you want it.
2. **"Route To Pin, Guide Step Or Quest" as a binding name.** *Rename it "Start Routing"*, to
   pair with "Stop Routing", once B1 gives the bindings a section of their own. The long name
   is accurate, which is the case for keeping it.
3. **Routes' chat lines begin "Thread:"** while the Tracker's begin "Tracker:" and Sparkle's
   "Sparkle:", and all three are Thread tools. *Change it to "Routes:"*; the `/thread` command
   stays.
4. **Keep To City Streets (MelloUI Route) on by default.** It is the one default in the family
   that deletes another addon's saved data for good, against the opt-in rule. Turning it off
   by default silently changes behavior for anyone who left it alone. *Make it opt-in and say
   so in the changelog.*
5. **Open Game Menu Directly (Console Port) on by default.** It changes a game setting by
   itself. It is also the Stitch's headline fix and is put back when disabled. *Keep it on and
   make it say so* (H5).
6. **The Dungeon Journal Stitch is numbered 1.0.0 and has never met the real journal.** *Play
   it before uploading*, or upload it as 0.9.0, which the release tool marks as a beta.
7. **`V1.md` and `ROADMAP.md` carry your first name and quote your messages.** That is fine
   for a private repository. *Take them out before it goes to GitHub.* The author line in the
   TOC files is a separate choice and yours.
8. **Where reports go** (J6). *A comment on the addon's CurseForge page* until the repository
   is public; its issues page after.
9. **"Not sewn on."** on the front page for a part that is not installed. The front page is
   one of the places Patchwerk's voice is allowed. *Keep it there*, and use plain words in the
   chat listing.
10. **"Sparkle: Looks" beside "Tracker: Appearance".** *Call both "Appearance"*; the checker
    offered "Sparkle: Effects".
11. **Hint tooltips on every tracker row** (E4) may feel busy with a mouse. *Build it and
    look*; it is easy to limit to guide steps and headings.
12. **Where the step text sits.** One reader thought its default lands on the game's own quest
    progress messages. That depends on your UI scale and could not be settled from the code.
    If you have seen them overlap, say so and it becomes an item.
13. **Two trackers in every instance** (A12; **yes on 2026-11-14, built**). When the tracker was planned you chose that
    hiding it in dungeons starts off, and the default tracker is kept in instances because
    ours cannot yet be trusted with dungeon objectives. Together those show two quest lists.
    *Let ours step aside in an instance while the default one is kept there*; unticking Keep
    Default Tracker In Instances brings ours back. The other way is to leave both and say so
    in the tooltip.

## What was left out

Reported, checked and dropped. The reasons in full are at the end of each section of
`tools/POLISH-findings.md`.

- **New features in disguise**: position sliders for the tracker; a command and binding to
  turn sparkles on and off; a list on the front page of parts the base turned away; a setting
  to remove a map pin on arrival.
- **Wrong as proposed**: a tooltip sentence about the game's Defaults button (it also offers
  All Settings); dropping the Dungeon Journal's chat tag; showing gamepad glyphs in the
  binding-change lines (24-pixel pictures in a chat line, and the raw key name is what a
  report needs); greying out Routes' Step Text sliders with Show Step Text (they still apply
  to the text shown on request).
- **Could not be confirmed**: the step text's default position (item 12 above); a fixed
  drawing order between the bright and faint trails; holding back a new destination while on
  a flight; any visible effect of the Tracker and Routes each working out where a quest is.
- **Not visible to a player**: a selected guide list being read about ten times a second
  (already ROADMAP T8, "only if it shows in play").
- **Release decisions, not polish**: raising the base's API number for Routes 0.16.0 (the
  need is soft and already handled).

## When it is built

- Passes A to D are where most of what you would notice is; E to G are finer.
- All of it is 89 items: 76 small and 13 medium. 33 want a look in the game.
- It would land as base 2.5.0, Tracker 1.2.0, Routes 0.17.0, Sparkle 1.1.0 and a small bump
  for each Stitch touched. A11, C5 and E15 add to what the base offers the parts, in a way an
  older part or base simply ignores, so the API number need not rise.
- The uncommitted Routes 0.16.0 (flight points you know) is the starting point: the line
  numbers in the findings include it.
- The items marked **Game** are the ones to look at first when playing a pass.

## Built so far

### Pass A, 2026-11-14: A1 to A12

Built as base 2.5.0, Routes 0.17.0, Tracker 1.2.0 and Stitch (Dungeon Journal) 1.0.1. Every
check passes (`lua_shell.py`, `lua_tracker.py`, `lua_patchwerk.py`, `lua_trips.py`,
`lua_journeys.py`, `build_check.py`), and each change has a check step that fails when the
change is taken out. **None of it has been tried in the game.** A12 was built after a yes
to decision 13.

What was settled while building, where the findings left a choice:

- **A1**: a step counts as the one last shown while its guide, number and on-foot flag match
  and none of its lines is new, with digits ignored. So a count going up ("3/10") or a line
  being completed does not show it again. This rests on RestedXP writing live counts into its
  lines, which is to be seen in the game.
- **A2**: the wait is 20, 40, 80, then 120 seconds; a search on a flight path is never taken
  as final. The note also goes on screen when the first whole search to find no way comes
  only later (after a landing, after a wrong turn). A gathering run prints no chat line per
  node, and nodes with no way are tried again in the next run.
- **A7**: a place saved by 1.1.0 is put back as it was and converted the first time the
  tracker can be measured.
- **A8**: the edge fades are 14 pixels of black at 75 percent, not tied to Background Opacity.
  A scroll asked for while the tracker is not drawn is dropped.
- **A9**: on a list whose step number does not move (the Dungeon Journal's), the chat line
  has no number and promises no undo ("Step skipped."). The undo itself still fails there
  until H1 (ST-2) is built; when it is, `ns.GuideBack`'s "Back to step N." needs the same
  read-again as `Go()` in the Tracker's `Guide.lua`, and the STAYS stand-in in
  `tools/lua_tracker.py` and one assertion in `tools/lua_patchwerk.py` change with it.
- **A10**: the threshold is 15 yards or 15 percent (SM-5), not 25 yards (TL-4).
- **A11**: Auto-Track Nearest Quest now leaves the arrow alone for any selection, a list
  included, and its tooltip says so.
- **A12**: ours hides in an instance while Hide Default Quest Tracker and Keep Default
  Tracker In Instances are both enabled (the defaults), or with Hide In Instances. With Hide
  Default Quest Tracker disabled both are shown there, as everywhere. RestedXP's window comes
  back whenever ours is hidden there. Show Dungeon Objectives (Experimental) is therefore seen
  only with Keep Default Tracker In Instances disabled, and its tooltip says so. When E5
  (TL-8, not hiding while unlocked) is built, it applies to `ns.AsideInInstance` too.
- `tools/luacheck.py` compiled nothing when given a bare folder name from `tools/` and still
  reported 0 errors. It now finds the folder under `addons/` and fails when no Lua file is found.

To look at in the game first: the step text through a kill step with several spots (A1);
"No route found" at a place past a lift, and how long one failed search takes (A2); the
trail during a flight, on both maps (A5); dragging the tracker and moving Scale, and a
position saved by 1.1.0 (A7); the darkened edges and the two scroll bindings on a gamepad
(A8); the chat line after a click that skips a RestedXP step (A9: it reads "Step skipped."
without a number if RestedXP moves its step a moment late); two quests in one camp (A10);
the Dungeon Journal list with no guide loaded (A11); a dungeon or battleground with the
default settings: one list, the default tracker's, and where it stands under EllesmereUI (A12).
