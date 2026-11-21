# Polish audit: the checked findings

The detail behind `POLISH.md` (repository root). Written 2026-11-14 by an audit that only read:
one reader for each angle below reported what looked rough, and a second reader, told to doubt
it, checked every report against the code and against the Forever client's own UI source
(`forever-src` in the notes). What survived is here, as checked; what was dropped is listed
with the reason. When written nothing in it was built; pass A (2026-11-14) and passes B to J
(2026-11-18) were built from it since, as `POLISH.md` records, so the code no longer reads as quoted.

Each finding: where it is, **Now** (the code or text as it stood on 2026-11-13, uncommitted
Routes 0.16.0 included), **Change** (what to do), **Checked** (what the second reader
confirmed or corrected). Line numbers are from that day and will drift.
Size: S under an hour, M a few hours, L a day or more.

## TL: The Tracker on screen

### TL-1. Past Max Height the list is cut with no sign of more, and a gamepad cannot reach the rest

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 383 (PatchwerkForever_Thread_Tracker; gamepad; size M; impact high; needs a look in the game)

**Now:** `local tall = math.min(total, ns.Get('height') or 450)` (383), `body:EnableMouseWheel(total > tall)` (391), and the only scrolling is `body:SetScript('OnMouseWheel', function(_, delta)` / `scroll = scroll - delta * WHEEL` (127-128). body clips its children (125), so a longer list is cut at the bottom edge with nothing to show there is more. ns.Cycle (Actions.lua:59-89, the Route To Next Quest / Route To Previous Quest bindings) can choose a quest below the cut: its marker bar is drawn out of sight and the only feedback is the chat line 'Routing to: ...'.

**Change:** (1) Scroll the chosen quest into view, only when the player stepped to it. In Frame.lua add `local reveal = false` and `function ns.Reveal() reveal = true end`; call ns.Reveal() in ns.Cycle before its final ns.Refresh() (Actions.lua:88). In Render's block loop remember the top (y before the block) and bottom (y + h) of the first block whose data has `mark`. After `tall` is known (line 383) and before the clamp on line 384: if reveal and a marked block was drawn and total > tall, then `scroll = math.min(top - PAD, math.max(scroll, bottom + PAD - tall))`; clear reveal either way. The list then never scrolls by itself (not when Auto-Track Nearest Quest moves the mark), and stepping past the last quest scrolls back up to the guide step, which takes the mark. No new binding. (2) Show that there is more. In Make() add `shade = CreateFrame('Frame', nil, frame)`, SetAllPoints(frame), frame level content:GetFrameLevel() + 10, mouse left off. Give it two textures 14 high across the top and bottom edges: `SetColorTexture(0, 0, 0, 1)`, then for the bottom one `SetGradient('VERTICAL', CreateColor(0, 0, 0, 0.75), CreateColor(0, 0, 0, 0))` and the colors swapped for the top one. In Render show the top one while scroll > 0 and the bottom one while scroll < total - tall. tools/trackerstub.lua needs SetGradient and CreateColor stand-ins; add a step to tools/lua_tracker.py after line 338: with Max Height 150, ns.Cycle(1) repeated to the last quest leaves that block inside the frame.

**Checked:** Quotes and lines confirmed. Nothing in Frame.lua or Actions.lua moves `scroll` except the mouse wheel; ns.Cycle only sets the Choice, the arrow, a chat line and ns.Refresh(). SetGradient('VERTICAL', CreateColor(...), CreateColor(...)) is used by this client at Blizzard_NamePlates/Blizzard_NamePlates.lua:657. Changed from the reader: scroll-into-view is tied to a flag set by ns.Cycle instead of 'the marked key changed', so the list cannot jump under the mouse when the mark moves by itself; inGame set to true because the look of the edge fades has to be seen. Not in ROADMAP.md or V1.md (T4 there is a zone filter).

### TL-2. A moved tracker keeps whatever anchor the game picks, and Scale shifts its position

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 149 (PatchwerkForever_Thread_Tracker; layout; size M; impact high; needs a look in the game)

**Now:** OnDragStop saves the raw anchor: `local point, _, relative, x, y = frame:GetPoint(1)` / `if point then Saved().place = { point, relative, x, y } end` (149-150). Place() puts it back unchanged, `frame:SetPoint(place[1], UIParent, place[2] or place[1], place[3] or 0, place[4] or 0)` (109), or uses `frame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -40, -260)` (111). Render then calls `frame:SetScale((ns.Get('scale') or 100) / 100)` (385) and never places it again. (1) After a drag the game re-anchors a frame to the screen region its centre is in (RIGHT for a tall tracker on the right-hand side, a BOTTOM corner lower down); the tracker's height changes with every objective, so it then grows from its middle or upward and the top heading moves. (2) SetPoint offsets are in the frame's own scaled units, so the Scale slider moves the tracker: -40, -260 is -64, -416 on screen at 160% and -24, -156 at 60%.

**Change:** Always store a top corner in UIParent units. In OnDragStop: `local s = frame:GetScale()`; `local top = frame:GetTop() * s - UIParent:GetHeight()`. If the frame's centre ((GetLeft() + GetRight()) / 2 * s) is in the right half of UIParent:GetWidth(), save { 'TOPRIGHT', 'TOPRIGHT', frame:GetRight() * s - UIParent:GetWidth(), top, 1 }, else { 'TOPLEFT', 'TOPLEFT', frame:GetLeft() * s, top, 1 }; the fifth field marks the new form. In Place() divide both offsets by frame:GetScale() when place[5] is set, and for the default too (-40 / s, -260 / s). In Render call SetScale before SetSize and call Place() whenever the scale differs from the one last applied. An old four-field place is applied as today; convert it at the end of the first Render in which frame:GetLeft() returns a number (the frame has no size until Render has run, so it cannot be read back in Make()). Update the header comment (line 27), the 'moving it' step of tools/lua_tracker.py (line 350 expects ["TOPLEFT", "TOPLEFT", 300, -200]) and give tools/trackerstub.lua's frames GetScale and a GetTop/GetLeft that follow the last SetPoint.

**Checked:** Quotes confirmed at Frame.lua:105-113, 147-152 and 385. Place() is called only from Make() and ns.ResetPlace(), so nothing corrects the position after a Scale change; the scale arithmetic is right. The re-anchoring after StopMovingOrSizing is engine behaviour, not visible in the Lua source (the repo's own stand-in models it at trackerstub.lua:112-115), so it has to be seen in the game. The default position is not affected by (1), only by (2). Added to the proposal: when the old saved form can be converted. The item bar (Items.lua:173-176) already converts with the same scale factor, so it keeps working.

### TL-3. Upcoming guide steps wrap onto several lines each

`addons/PatchwerkForever_Thread_Tracker/Guide.lua` line 149 (PatchwerkForever_Thread_Tracker; layout; size S; impact medium; needs a look in the game)

**Now:** `title = ('%d. %s'):format(index, First(step.lines) or '...'),` for each dimmed step after the current one. The comment on First() (line 55) says `-- The first words of a step, for a step listed on one line.`, but every block title is made by Writing() with `fs:SetWordWrap(true)` (Frame.lua:91) and Fill() only sets `block.title:SetWidth(math.max(40, width - noteWide))` (Frame.lua:239). The reader passes RestedXP's whole line (PatchwerkForever/Guides/RestedXP.lua:76), so a line longer than about 40 letters at the default width takes two or three rows, and the three default upcoming steps (up to eight) can take more room than the step you are on.

**Change:** Give a block a `oneLine` field (add it to the header comment of Frame.lua, lines 13-18). In Fill(), after the title's font is set (line 234), call `block.title:SetWordWrap(not data.oneLine)`; set it both ways because blocks are reused. In Guide.lua set `oneLine = true` on the 'after' blocks (line 148). With a width set and wrapping off the game cuts the text with an ellipsis, as it already does for section headings (Frame.lua:329-330). Zone headings and quest titles stay as they are.

**Checked:** Quotes confirmed. Head titles turn wrapping off (Frame.lua:329) but block titles never do, and Tall() adds the wrapped height, so the rows really grow. The cut text has no tooltip to read it in full, so whether one line or the full text reads better is his call in the game; the code's own comment says one line was meant. Not a new feature and not in ROADMAP.md.

### TL-4. Quests and item buttons swap places as distances cross

`addons/PatchwerkForever_Thread_Tracker/Quests.lua` line 183 (PatchwerkForever_Thread_Tracker; smoothness; size S; impact medium; needs a look in the game)

**Now:** `local function Nearer(a, b)` / `if a.yards and b.yards then` / `if a.yards ~= b.yards then return a.yards < b.yards end`, run on the live distance at every drawing; with Show Distance on (the default) the section is redrawn each second: `if ns.Get('distance') and #data.quests > 0 then tick = true end` (208). Two quests whose marks are close together (the usual case: two quests in one camp) change order each time you cross the line halfway between them, so rows jump and the order Route To Next Quest steps through changes. Items.lua:117-124 sorts the item bar with the same test, so out of combat the buttons swap and Use Nearest Quest Item changes its item.

**Change:** In Places.lua add `function ns.SortYards(id, live)` with a table `kept`: when live is nil, clear kept[id] and return nil; when kept[id] is nil or math.abs(live - kept[id]) > math.max(25, 0.15 * kept[id]), set kept[id] = live; return kept[id]. Clear kept[id] on QUEST_REMOVED only (not in Forget(), which runs on every QUEST_LOG_UPDATE). In ReadQuests (Quests.lua:107) add `sortYards = ns.SortYards(id, yards)` beside `yards`, and in Wanted() (Items.lua:113) the same for each item; compare `sortYards` in Nearer (Quests.lua:184-187) and in the item sort (Items.lua:118-121). The note on the right keeps the live `yards`. The key is worked out once per quest before sorting, so table.sort stays safe. Add a step to tools/lua_tracker.py: two quests 10 yards apart in distance do not swap when the player moves 10 yards, and do after 40.

**Checked:** Quotes confirmed; 'zone' (the default order) sorts each zone with Nearer at line 247, 'near' at 211, the ready group at 254. Places are cached 5 seconds but the player's position is live, so the order really is re-decided every second. The reader's 'each time you move a few yards' overstates it: a swap happens when the two distances cross, which is frequent only when the marks are close together. Trade-off to know: the shown distances can be up to about 25 yards out of order for a moment. Actions.lua:20 (`NEARER = 0.85`) already does the same kind of holding for the arrow. Proposal made concrete (where the key is computed).

### TL-5. A timed quest flashes every second and keeps a faded tracker awake

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 363 (PatchwerkForever_Thread_Tracker; smoothness; size S; impact medium)

**Now:** `if seen[key] and seen[key] ~= words and not each.small then` / `changed = now` / `if ns.Get('flash') then block.glowAt = now end`. Words() (282-288) joins every line's text, and a timed quest carries `lines[#lines + 1] = { text = 'Time left: ' .. Clock(quest.left), r = 1, g = quest.left < 60 and 0.3 or 0.8, b = 0.3 }` (Quests.lua:172), which changes each second while the section asks for a redraw each second (`if quest.left then tick = true end`, Quests.lua:205). So with Flash On Progress on (the default) the quest's glow restarts every second for as long as the timer runs, and with Fade When Not Hovered on the tracker never fades. The dungeon stage's `'Time left: ' .. Clock(duration - elapsed)` line (Dungeon.lua:45) does the same.

**Change:** Mark lines whose words change by themselves: add `live = true` to the timer line in Quests.lua:172 and in Dungeon.lua:45. In Words() (Frame.lua:284-286) skip lines with `line.live`. Add `live` to the block description in Frame.lua's header comment. Add a step to tools/lua_tracker.py next to the flash step (line 503), using the existing `STUB.thieves.timed`: a timed quest does not glow when a second passes, and still glows when an objective count changes.

**Checked:** Confirmed by reading: `changed` and `glowAt` are set only at Frame.lua:364-365, from a comparison that includes the clock text. C_QuestLog.GetTimeAllowed exists on this client (Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua:372), so `quest.left` is filled for timed quests. The existing check at lua_tracker.py:488-490 ticks the clock but never looks at the glow, which is why this passes today. Timed quests are uncommon, but when one is tracked the glow pulses for the whole timer.

### TL-6. "Completed first" sort order puts completed quests last while Group Completed Quests is on (the default)

`addons/PatchwerkForever_Thread_Tracker/Quests.lua` line 206 (PatchwerkForever_Thread_Tracker; edge-case; size S; impact low)

**Now:** `if quest.done and apart then ready[#ready + 1] = quest else open[#open + 1] = quest end`. With Group Completed Quests ticked, as it starts, no completed quest is left in `open`, so the `if order == 'ready' then` loop (233-240), which looks for `quest.done` in `open`, finds none. Choosing Sort Order `{ 'ready', 'Completed first, then by zone' }` (Core.lua:54) leaves the completed quests at the bottom, under 'Ready to Turn In' (253-257).

**Change:** When order == 'ready' and `apart` is on, write the ready group first: before the zone loop (line 241), if #ready > 0, sort `ready` with Nearer, add ZoneHeading('Ready to Turn In') and BlockOf(quest, true) for each, and skip the group at the foot (line 253) in that case. BlockOf fills ns.questOrder as it is called, so Route To Next Quest follows the new order by itself. Change the Group Completed Quests tooltip (Core.lua:57) to: 'Move quests that are ready to turn in to a separate group at the bottom of the list, or at the top when Sort Order is Completed first. Your tracked quests are not changed.' Add the case to the orders step in tools/lua_tracker.py (line 469 tests 'ready' only with readyGroup off).

**Checked:** Confirmed by tracing: with readyGroup true the 'ready' order differs from 'zone' only in always writing zone headings (line 248). The check script covers 'ready' only with the grouping off, so this combination was never played. Not a default setting, hence low.

### TL-7. Wrapped objectives fall back under the dash, and timer and party notes wear a dash too

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 254 (PatchwerkForever_Thread_Tracker; visuals; size M; impact low; needs a look in the game)

**Now:** `fs:SetWidth(width - INDENT)` / `fs:SetText('- ' .. tostring(line.text))` (253-254). The dash is part of the text, so the second row of a long objective, or of a guide step's line, starts under the dash and not under the words. Every line gets it, so notes read as objectives: "- Time left: 4:32" (Quests.lua:172) and "- With Thrag 60%, Mokra" (Quests.lua:176, Party.lua:59).

**Change:** Draw the dash as its own FontString per line slot (block.dashes[i], same font and color as the line, at INDENT, shown and hidden with it), as the default tracker does with line.Dash (Blizzard_ObjectiveTracker/Blizzard_ObjectiveTrackerBlock.lua:167-180). Put the text at INDENT + dashWide, where dashWide = math.ceil(dash:GetStringWidth()) + 3 (fall back to size * 0.5 + 3 when the game returns 0), and give it width - INDENT - dashWide. Add `plain = true` to the timer line (Quests.lua:172, Dungeon.lua:45) and the party line (Quests.lua:176); for those hide the dash and keep the same text indent. In ns.Shown() (Frame.lua:410-411) write '- ' before the text only when that line's dash is shown, and change the expectations in tools/lua_tracker.py that read "  - Time left" (lines 487-492, 1026-1029) and "  - With Thrag" (902-930); tools/trackerstub.lua needs GetStringWidth on its writing.

**Checked:** Quotes confirmed; the default tracker's separate Dash is in this client's source at the lines given. Guide step lines (RestedXP's long sentences) are where the wrap shows most. Impact lowered from medium: it is an alignment refinement a player is unlikely to name. The check script's line 495-497 also reads `line.text == "- 10/12 Raptor Head"` from the font string directly and must change with it.

### TL-8. Unlocking with nothing tracked shows nothing to drag; the bar is dimmed by the fades and tells you to type a command

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 378 (PatchwerkForever_Thread_Tracker; edge-case; size M; impact low)

**Now:** `if usedHeads == 0 then` / `frame:Hide()` / `return After(false)` (378-380). With no tracked quests and no guide (or in an instance with Hide In Instances, line 302) the frame and its drag bar are hidden, yet ns.Unlock still prints `'Unlocked. Drag the bar above the tracker to move it, then /tracker lock.'` (437). The bar reads `handle.words:SetText('Drag to move   /tracker lock')` (144) and has no click of its own. The bar sits above the frame (135-136), outside `frame:IsMouseOver()` (470), so with Fade When Not Hovered or Fade In Combat on the tracker and its bar are at Faded Opacity while you drag.

**Change:** While `unlocked`: (a) do not hide: skip the Hide In Instances part of the test on line 302, and when usedHeads == 0 show the frame `width` wide and 60 tall with one centered line in Header Color, 'No tracked quests.' (the words Actions.lua:68 already prints), then run the same tail as today (scale, background, handle, After(true)); hide that line whenever there is something to list or the tracker is locked. (b) At the top of Bright() add `if unlocked then return 1 end`. (c) Change the bar's text to 'Drag to move. Right-click to lock.', add `handle:RegisterForClicks('RightButtonUp')` and an OnClick that calls ns.Unlock(false). Change the chat line to 'Unlocked. Drag the bar above the tracker to move it. Right-click the bar to lock it.' The Unlock Position button and /tracker lock keep working. Update the assertion at tools/lua_tracker.py:346 only if the first words change (they do not).

**Checked:** Quotes confirmed. The handle is a child of the frame, so hiding the frame hides it, and ns.Unlock (429-439) calls Render without checking that anything is shown. Merged in from the reader's fade finding: the 'dim while unlocked' part, which belongs with the unlocked state. Size raised from S: three small changes plus the stand-in checks. Locking stays reachable from a gamepad through the Unlock Position button in the options.

### TL-9. Fade When Not Hovered ignores your own actions

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 471 (PatchwerkForever_Thread_Tracker; feedback; size S; impact low)

**Now:** `if not over and GetTime() - changed > AWAKE then return low end`, and `changed` is set in one place only, `changed = now` (364), when a block's words differ. Route To Next Quest, Route To Previous Quest and Collapse / Expand Tracker change the marker bar or the folding but no words (`mark` is not part of Words(), 282-288), so on a gamepad, with no mouse to hover, the tracker stays at Faded Opacity while you step through it.

**Change:** In Frame.lua add `function ns.Wake() changed = GetTime() end`. Call it from ns.Cycle and ns.Follow (Actions.lua:53 and 88, before ns.Refresh()), from ns.Fold and ns.ResetPlace (Frame.lua), and from Start in Gather.lua (line 24). Fade In Combat stays as it is. Add a step to the fades part of tools/lua_tracker.py (after line 1072): with fadeIdle on and the tracker dimmed, ns.Cycle(1) brings it to full brightness, and it dims again after AWAKE seconds.

**Checked:** Confirmed: `changed` has a single assignment, and neither ns.Cycle, ns.Follow nor ns.Fold changes any block's words. Fade When Not Hovered is off by default (Core.lua:40), so impact stays low; for this gamepad player it is the one fade where it would show. The 'dim while unlocked' half of the reader's finding was moved to the unlock finding.

### TL-10. The quest item bar can sit off the screen

`addons/PatchwerkForever_Thread_Tracker/Items.lua` line 174 (PatchwerkForever_Thread_Tracker; edge-case; size S; impact low)

**Now:** `x = ns.Get('itemSide') == 'right' and (right * scale + GAP) or (left * scale - GAP - size)`. The side is taken as set, with no look at the room there. At the default place the tracker's right edge is 40 from the screen edge, so Position 'Right of the tracker' with Button Size 38 or more hangs the buttons over the edge (x + size = width - 36 + 38). With the tracker dragged to the left edge and Position 'Left of the tracker' (the default), x is negative and the whole bar is off screen.

**Change:** After working out x for the chosen side (line 174), test it against the screen: if x < 0 or x + size > UIParent:GetWidth(), work out the other side's x (right * scale + GAP, or left * scale - GAP - size) and use it when that one fits; keep the chosen side when neither fits. This is inside Layout(), which returns early in combat (157-160), so nothing secure moves in a fight, and x is part of the signature (178) so the bar is laid out again. Add a sentence to the Position tooltip (Core.lua:103): 'Which side of the tracker the item bar is on. The bar moves to the other side when there is no room.'

**Checked:** Quote and arithmetic confirmed. The buttons are parented to UIParent and placed against it (Items.lua:61, 192) with no clamping, and the tracker itself is clamped to the screen (Frame.lua:118), so a tracker at the left edge leaves the default-side bar at x = -GAP - size. Different from ROADMAP T5 (bar fades and follows the tracker; horizontal layout). The player can already fix it with the Position setting, hence low.

### TL-11. Item buttons have no hover or pressed look, and the count does not follow Button Size

`addons/PatchwerkForever_Thread_Tracker/Items.lua` line 69 (PatchwerkForever_Thread_Tracker; visuals; size S; impact low; needs a look in the game)

**Now:** `local function Dress(b)` (69-90) makes a black back, the icon, a count with `ns.Font(b.count, 11)` (78) and a cooldown. It sets no highlight and no pushed texture, so pointing at a button or pressing it changes nothing but the tooltip. The count stays 11 points while Button Size goes from 20 to 56 (Core.lua:100).

**Change:** In Dress(), which runs once at load: `b:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square', 'ADD')` and `b:SetPushedTexture('Interface\\Buttons\\UI-Quickslot-Depress')`. In Layout(), next to `b:SetSize(size, size)` (line 190), also call `ns.Font(b.count, math.max(9, math.floor(size * 0.34 + 0.5)))`, which gives 11 at the default 32.

**Checked:** Confirmed: Dress() sets neither texture. Both texture paths are used by this client (Blizzard_Collections/Shared/Blizzard_CollectionTemplates.xml:173 and 179; SetHighlightTexture with 'ADD' in Blizzard_ActionBar/Shared/VehicleLeaveButton.lua:46). Dress() runs at load and Layout() never in combat, so no secure frame is touched in a fight. The binding presses the unseen ninth button, so the pressed look only shows for mouse or cursor clicks.

### TL-12. Heading underline stops short of the right edge, and the guide's progress bar has no track

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 182 (PatchwerkForever_Thread_Tracker; visuals; size S; impact low; needs a look in the game)

**Now:** `local n = math.floor((width + STITCH_GAP) / (STITCH + STITCH_GAP))` lays stitches at a fixed 12-pixel pitch from the left (`s:SetPoint('TOPLEFT', head, 'BOTTOMLEFT', (i - 1) * (STITCH + STITCH_GAP), 0)`, 192). At the default width (inner 244) that is 20 stitches ending at 235, 9 pixels short of the right-aligned note above them; the shortfall is up to 11 pixels and changes with Width. The guide's bar is one texture, `head.bar:SetSize(inner * part, 2)` (339), with nothing behind it, so early in a guide it reads as a short stray line under the stitches and not as progress.

**Change:** In Stitch(), spread the gap so the last stitch ends at the edge: `local gap = n > 1 and (width - n * STITCH) / (n - 1) or 0`, and place stitch i at math.floor((i - 1) * (STITCH + gap) + 0.5). For the bar, add head.track in Head(): a texture in the 'BORDER' layer, Guide Color at 0.25 alpha, `inner` wide and 2 high, at the same anchor as head.bar ('TOPLEFT', head, 'BOTTOMLEFT', 0, -4), shown and hidden together with head.bar (lines 335-346).

**Checked:** Arithmetic confirmed: (244 + 5) / 12 gives 20 stitches, the last ending at 19 * 12 + 7 = 235. head.bar is the only texture on that row. Added rounding of the stitch positions so the spread gap does not blur them. The weakest of the set: purely a matter of look, to be judged in the game.

## TI: The Tracker in use

### TI-1. A moved tracker can grow upward or from its middle instead of downward

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 149 (PatchwerkForever_Thread_Tracker; smoothness; size S; impact medium; needs a look in the game)

**Now:** local point, _, relative, x, y = frame:GetPoint(1)
if point then Saved().place = { point, relative, x, y } end

**Change:** Why: after a drag the client re-anchors the frame to the nearest of nine screen points and that anchor is saved as it comes. With 'RIGHT', 'CENTER' or a 'BOTTOM...' anchor, every frame:SetSize(width, tall) in Render (line 386) moves the top edge, so the first heading jumps whenever a line comes or goes. A tall tracker dragged anywhere on the right edge has its center in the middle third of the screen, so 'RIGHT' is the likely result.
Change: add a local function Pin() in Frame.lua: local s = frame:GetScale(); local left, right, top = frame:GetLeft(), frame:GetRight(), frame:GetTop(); if not (left and right and top) then return false end; local pw, ph = UIParent:GetWidth() / s, UIParent:GetHeight() / s; if (left + right) / 2 > pw / 2 then Saved().place = { 'TOPRIGHT', 'TOPRIGHT', right - pw, top - ph } else Saved().place = { 'TOPLEFT', 'TOPLEFT', left, top - ph } end; Place(); return true. Call Pin() in OnDragStop in place of the two quoted lines. For places saved earlier: in Render, after frame:Show(), when Saved().place exists and place[1] is neither 'TOPLEFT' nor 'TOPRIGHT', call Pin() once (try again on the next draw if it returns false). Place() already accepts this four-value form, and it is the same form as the default ('TOPRIGHT', 'TOPRIGHT', -40, -260).

**Checked:** Quote exact (lines 149-150). Default place is TOPRIGHT (line 111) and Render resizes the frame on every draw (line 386), so the claim follows once the anchor is not a top one. The re-anchoring after StartMoving/StopMovingOrSizing is client behavior that the UI source does not show, hence inGame. Proposal corrected: the reader's { 'TOPRIGHT', 'BOTTOMLEFT', right, top } would make the frame jump when Scale is changed, because SetPoint offsets are in the frame's own scaled units; anchoring to the same top corner of UIParent keeps the offsets small, as the default does.

### TI-2. A click that skips a guide step says nothing, and nothing on screen tells how to undo it

`addons/PatchwerkForever_Thread_Tracker/Guide.lua` line 30 (PatchwerkForever_Thread_Tracker; feedback; size S; impact medium)

**Now:** if ns.Base.Guides:Go(info, index) then
	before = { source = info.source, index = from }
else
	ns.Print(('%s could not jump to that step.'):format(info.reader or 'The guide'))
end

**Change:** Why: only the failure prints. "Click To Skip Steps" is on by default (Core.lua line 88), the whole current step is the click target, and one stray click (mouse or ConsolePort cursor) moves RestedXP on. The undo is named only in that option's tooltip and in /tracker help.
Change: in Go(), on success, after setting `before`, print one line. When index == from + 1: ns.Print(('Skipped step %d. Type /tracker back to undo.'):format(from)). When index < from: ns.Print(('Back to step %d.'):format(index)). Otherwise: ns.Print(('Jumped to step %d. Type /tracker back to return to step %d.'):format(index, from)). ns.GuideBack calls Guides:Go directly and already prints, so it needs no change. If the undo binding (separate finding) is added, name it in the first line instead of the slash command.

**Checked:** Quote exact (lines 30-34). Impact lowered from high: the skip is not wholly silent, since the step block changes and flashes (Frame.lua 363-365), and the undo is also reachable by right-click > Previous Step (Guide.lua line 116); what is missing is any word of what happened and how to take it back. Both readers' Go (RestedXP.lua 175, Stitch_DungeonJournal Reader.lua 232) return true or false, so the lines hold for side lists too. Other tracker actions from bindings already print (Actions.lua 82, 86), so a chat line fits.

### TI-3. Route To Next/Previous Quest does not scroll the chosen quest into view or wake a faded tracker

`addons/PatchwerkForever_Thread_Tracker/Actions.lua` line 84 (PatchwerkForever_Thread_Tracker; gamepad; size M; impact medium)

**Now:** Choice:Set('quest', order[to])
PutArrow(order[to])
ns.Print('Routing to: ' .. tostring(Ask(C_QuestLog.GetTitleForQuestID, order[to]) or order[to]))

**Change:** Why: the list scrolls only from the mouse wheel (Frame.lua 127-130), so on a gamepad a quest below Max Height is chosen off screen. With Fade When Not Hovered on, the tracker also stays dim: `changed` is set only when a block's words change (Frame.lua 363-364), and the marker bar is not part of the words.
Change: add ns.Reveal(sectionId, key) in Frame.lua: store reveal = sectionId .. '\n' .. tostring(key), set changed = GetTime(), set dirty = true. In Render's block loop, when the block's key string (already built at line 360) equals `reveal`, remember its top (y before the block) and bottom (y + h). Just before `scroll = math.max(0, math.min(scroll, total - tall))` (line 384): if a block was found, lower `scroll` to top - PAD when top - PAD < scroll, or raise it to bottom + PAD - tall when bottom + PAD > scroll + tall; then set reveal = nil whether or not it was found (a folded section stays folded). Call ns.Reveal('quests', order[to]) from ns.Cycle after Choice:Set; in the 'Back to your main route.' branch set the scroll to 0 and wake the same way (a small ns.Reveal() with no key that does only that). Have ns.Fold() set changed = GetTime() too, so the binding wakes a faded tracker.

**Checked:** Quote exact (lines 84-86). Confirmed: `scroll` is written only in the OnMouseWheel script and the clamp; `changed` only at Frame.lua 364; Words() (282-288) leaves out the mark. Not in ROADMAP.md or V1.md (T11 was the bindings themselves, built). Uses nothing from the game beyond GetTime. The fade part only shows with Fade When Not Hovered on (off by default); the scroll part shows whenever the list is taller than Max Height.

### TI-4. Auto-Track Nearest Quest stops working once the game puts the arrow on a quest by itself

`addons/PatchwerkForever_Thread_Tracker/Actions.lua` line 213 (PatchwerkForever_Thread_Tracker; edge-case; size M; impact medium)

**Now:** if not (ns.Get('on') and ns.Get('followNearest')) then
	auto = nil
	return
end
local now = Followed()
if now and now ~= auto then return end              -- a quest you chose: left alone

**Change:** Why: any arrow this file did not place counts as the player's choice. But the game places the arrow itself on an accepted quest whenever nothing is super-tracked. So (1) ticking the option while an arrow is already on a quest changes nothing; (2) turn in the followed quest and accept the next one before the 2-second ticker runs (a quest chain at one NPC), and the arrow stays on that quest until it is turned in; (3) after /reload `auto` is nil, so the option's own arrow becomes a 'chosen' one.
Change in Actions.lua: replace the bare assignments to `auto` with a small setter that also writes ns.Saved().auto. (a) ns.On('QUEST_ACCEPTED', function(id) C_Timer.After(0, function() if ns.Get('on') and ns.Get('followNearest') and Followed() == id and not ns.Base.Choice:Is('quest', id) then set auto to id end end) end), so an arrow the game placed on accept stays the option's to move. (b) ns.OnSetting(function(key, value) if key == 'followNearest' and value then: if Followed() is set and is not the quest in Choice, set auto to it; then ns.Try('following the nearest quest', Look) at once instead of waiting for the ticker). (c) at PLAYER_LOGIN, set auto = ns.Saved().auto when Followed() equals it. A quest chosen in the tracker (ns.Follow and ns.Cycle already clear auto) or clicked on the map afterwards is still left alone. Leave the arrow where it is when the option is unticked.

**Checked:** Quote exact (lines 208-213). Confirmed in the client source: Blizzard_FrameXMLUtil/Mainline/Blizzard_QuestSuperTracking.lua 78-85 calls QuestUtil.CheckAutoSuperTrackQuest on QUEST_ACCEPTED, and QuestUtils.lua 428-444 sets the arrow when C_SuperTrack.IsSuperTrackingAnything() is false; the file loads here (TOC line 48, `[AllowLoadGameType mainline]`, and this client is a mainline-family type per the camelot overrides in the same TOC). QUEST_ACCEPTED carries questId first. The option stays opt-in (default false). Does not touch a player running a guide: Look() returns at line 215 while one leads, so for this player it matters only between guides. Cut the reader's 'clear the arrow on untick' part (see dropped).

### TI-5. Hovering a row or heading gives no hint of what a click will do

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 221 (PatchwerkForever_Thread_Tracker; discoverability; size M; impact medium)

**Now:** block:SetScript('OnEnter', function(self)
	if self.data and self.data.click then self.over:Show() end
end)

**Change:** Why: a faint highlight only. Nothing on the tracker says that a left click on the current guide step skips it, that a quest click routes, that shift-click opens details or that right-click opens a menu. Headings (Head(), lines 160-178) fold on a click and have no hover cue at all.
Change: let a block carry tip = { 'line', ... }. In the block's OnEnter, when data.tip is set: GameTooltip:SetOwner(self, 'ANCHOR_NONE'); GameTooltip:ClearAllPoints(); GameTooltip:SetPoint('TOPRIGHT', self, 'TOPLEFT', -8, 0); GameTooltip:SetText(data.title, 1, 1, 1); each tip line with AddLine(line, 0.7, 0.7, 0.7, true); Show. Hide it in OnLeave. Set tips where blocks are built. Quest (Quests.lua BlockOf): 'Click to route to this quest.' or, when it is the chosen one, 'Click to stop routing to this quest.'; 'Shift-click for quest details.'; 'Right-click for more options.'. Current step of the main guide (Guide.lua, only when Click To Skip Steps is on): 'Click to skip this step.', 'Right-click for more options.'. Upcoming step: 'Click to jump to this step.'. Side list step: 'Click to route along this list.' or 'Click to stop routing along this list.', 'Right-click for more options.'. Gathering rows (Gather.lua): 'Click to route to the nearest node.' or, while it is the run, 'Click to stop.'. Recipes: 'Click to open this recipe.', 'Right-click for more options.'. Give Head() the same OnEnter/OnLeave with 'Click to collapse.' or 'Click to expand.' by Saved().folded[self.id]. Hint lines only: the quest description and rewards of ROADMAP T3 go above them in the same tooltip when that is built.

**Checked:** Quote exact (lines 221-223); Head() has no OnEnter. Click behaviors checked against Actions.lua 170-189, Guide.lua 111-154, Gather.lua 14-45 and Recipes.lua 73-85, and the proposed lines match them. Overlaps ROADMAP T3 (tooltip on a quest: description, rewards) only in that both use a tooltip on a quest row; the hint lines and the tooltips on guide steps, headings, gathering and recipe rows are not listed there. Added ClearAllPoints before SetPoint. Whether a tooltip on every row feels too busy for a mouse player is worth one look in the game.

### TI-6. Unlock Position shows no drag bar when the list is empty, and the bar names only a slash command for locking

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 378 (PatchwerkForever_Thread_Tracker; edge-case; size S; impact low)

**Now:** if usedHeads == 0 then
	frame:Hide()
	return After(false)
end

Line 144: handle.words:SetText('Drag to move   /tracker lock')
Line 437: ns.Print(unlocked and 'Unlocked. Drag the bar above the tracker to move it, then /tracker lock.' or 'Locked.')

**Change:** Why: the drag bar is a child of the tracker frame (line 134). With nothing to list (no tracked quests, no guide, no recipes, no gathering), or in an instance with Hide In Instances on (line 302), the frame is hidden, so Unlock prints its line and there is nothing to drag.
Change: (a) In Render, while `unlocked` is true: do not take the Hide In Instances part of the early return at line 302 (keep the `not ns.Get('on')` part), and when usedHeads == 0 do not hide: set total and tall to 60, use math.max(40, ns.Get('back') or 25) / 100 for the background, and fall through to the SetSize/handle/Show lines. In Bright(), return 1 while unlocked. (b) Let the bar lock on a right-click: handle:RegisterForClicks('RightButtonUp') and handle:SetScript('OnClick', function() ns.Unlock(false) end). (c) Bar text: 'Drag to move. Right-click to lock.'. Chat line at 437: 'Unlocked. Drag the bar above the tracker to move it. Right-click the bar to lock it.'. Unlock Position tooltip (Core.lua line 34): 'Show a drag bar above the tracker so you can move it. Right-click the bar, or click this button again, to lock it in place.'. README line 81 to match.

**Checked:** Quotes exact (lines 378-381, 144, 437). Title corrected: locking does not need a slash command, because the Unlock Position button toggles (Core.lua line 33 calls ns.Unlock() with no argument); the bar and the chat line, though, name only /tracker lock. Impact lowered to low: the empty case needs a character with nothing tracked and no guide, and Hide In Instances is off by default. The handle is a plain Button, not a secure one, so the click script is safe at any time.

### TI-7. A chosen quest untracked from the quest log stays chosen, with nothing marked in the tracker

`addons/PatchwerkForever_Thread_Tracker/Actions.lua` line 126 (PatchwerkForever_Thread_Tracker; edge-case; size S; impact low)

**Now:** if ns.Base.Choice:Is('quest', id) then ns.Base.Choice:Clear() end

**Change:** Why: this line is inside the tracker's own Untrack() (right-click > Untrack Quest), the only place a choice is cleared on untracking. The base's Choice stands while the quest is in the log (Choice.lua Stands()), so untracking the chosen quest in the quest log or on the map leaves Routes (Thread) leading to a quest the tracker no longer lists; no row carries the marker (the guide step is unmarked because Choice:Get() is still set).
Change: in Actions.lua add ns.On('QUEST_WATCH_LIST_CHANGED', function(id, added) if added == false and id and ns.Base.Choice:Is('quest', id) then ns.Base.Choice:Clear() ns.Print('Back to your main route.') ns.Refresh() end end). Nothing else is needed: the game clears its own arrow in the same case, and the tracker's own Untrack() clears the choice before it removes the watch, so it does not print twice.

**Checked:** Quote exact (line 126). Confirmed: Choice.lua 30-38 keeps a quest choice while it has a log index; Routes follows it regardless of the watch list (Thread_Routes/Sources.lua 264-275); Guide.lua 140 unmarks the guide step while any choice stands. On this client QUEST_WATCH_LIST_CHANGED carries (questID, added), both nilable (QuestLogDocumentation.lua 1406-1415), and the game clears its arrow at Blizzard_QuestSuperTracking.lua 87-91. Today's way out is Route To Next Quest or clicking another quest twice. The chat line reuses the wording at Actions.lua 82.

### TI-8. Undoing a skipped guide step cannot be bound

`addons/PatchwerkForever_Thread_Tracker/Core.lua` line 173 (PatchwerkForever_Thread_Tracker; gamepad; size S; impact low)

**Now:** elseif word == 'back' then
	ns.Try('back', ns.GuideBack)

**Change:** Why: Bindings.xml holds only PATCHWERKFOREVER_TRACKER_FOLD, _NEXT, _PREV and the item click. ns.GuideBack is reached only by typed text, the hard thing on a gamepad, and the family rule is that every action is bindable.
Change: add to Bindings.xml <Binding name="PATCHWERKFOREVER_TRACKER_BACK" category="ADDONS">PatchwerkForever_Thread_Tracker_Back()</Binding>. In Core.lua: BINDING_NAME_PATCHWERKFOREVER_TRACKER_BACK = 'Undo Skipped Guide Step' and function PatchwerkForever_Thread_Tracker_Back() ns.Try('back', ns.GuideBack) end. Extend the Click To Skip Steps tooltip (Core.lua line 89) to: 'Click the current step to skip it, or an upcoming step to jump to it. /tracker back, or the Undo Skipped Guide Step key binding, undoes the last skip.'. Add the binding to the README (next to the Route To Next Quest bullet) and a CHANGELOG line.

**Checked:** Quote exact (lines 173-174); Bindings.xml read in full. Cut down to the undo: the reader's second binding, Skip Guide Step, is a new binding he was offered and did not pick (tools/PLAN-tracker.md line 187), so it is a feature, not polish. Impact lowered to low: the same undo is already reachable with the mouse by right-click > Previous Step (Guide.lua line 116). Binding label reworded to read as plain Title Case.

### TI-9. "Use Nearest Quest Item" does nothing and says nothing when no quest has an item

`addons/PatchwerkForever_Thread_Tracker/Items.lua` line 203 (PatchwerkForever_Thread_Tracker; feedback; size S; impact low)

**Now:** local first = list[1] and list[1].quest and list[1] or nil
nearest.item = first and first.id or nil
nearest:SetAttribute('type', first and 'item' or nil)
nearest:SetAttribute('item', first and ('item:' .. first.id) or nil)

**Change:** Why: with no usable quest item (or the tracker or the item bar disabled) the bound button has no type, so a press is swallowed with no sign of why.
Change: after `nearest` is made (line 96) add an ordinary post-click script, set once at load: nearest:SetScript('PostClick', function(self, _, down) if down then return end if not self.item then UIErrorsFrame:AddMessage('No quest item to use.', 1.0, 0.1, 0.1, 1.0) end end). The `down` test is needed because the button is registered for both AnyUp and AnyDown (line 62) and the script runs on both edges. The message goes to the red error text in the middle of the screen, not to chat, so repeated presses do not fill the chat.

**Checked:** Quote exact (lines 203-206). Confirmed nearest.item is nil whenever Wanted() gives no quest item, including with `on` or `items` off (line 103). PostClick is a free script on SecureActionButtonTemplate and changes no attribute, so the no-secure-frames-in-combat rule holds. SecureActionButton_OnClick acts on one edge only (Blizzard_FrameXML/SecureTemplates.lua 802-814). UIErrorsFrame:AddMessage(text, r, g, b, a) is used this way in the client source (e.g. Bindings_Mists.xml 1408).

### TI-10. The default tracker (and a hidden RestedXP window) may show for half a second after each loading screen

`addons/PatchwerkForever_Thread_Tracker/Quiet.lua` line 123 (PatchwerkForever_Thread_Tracker; smoothness; size S; impact low; needs a look in the game)

**Now:** for _, event in ipairs({ 'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA', 'QUEST_WATCH_LIST_CHANGED', 'QUEST_LOG_UPDATE',
	'QUEST_ACCEPTED', 'QUEST_REMOVED', 'PLAYER_REGEN_ENABLED' }) do
	ns.Try('listening for ' .. event, ns.On, event, Soon)
end

Line 27: local SOON = 0.5              -- seconds after the game changes its list before the pieces are gone over again

**Change:** Why: Soon() waits 0.5 seconds before Apply(), and nothing quietens the default tracker earlier. After login, /reload, or leaving an instance (where it was let back), both trackers can be on screen until the timer fires, while ours is drawn within a tenth of a second.
Change: take 'PLAYER_ENTERING_WORLD' out of the list and register it, and PLAYER_LOGIN, with a handler that first runs ns.Try('quietening', Apply) at once and then calls Soon(). Apply() already refuses in combat and only sets alpha and mouse on unprotected pieces; the delayed pass stays for the pieces the game lays out afterwards. Leave the other events on Soon.

**Checked:** Quote exact (lines 123-126, 27). Confirmed nothing applies earlier: the only other callers of Apply are the settings watcher (127-131) and the 3-second ticker, which itself goes through Soon. Whether the half second is hidden by the loading screen can only be seen in the game, so this stays a likely, not a certain, flicker. The proposal uses no new API and keeps the combat guard.

### TI-11. /tracker back can rewind to a step number from long ago, or from another guide

`addons/PatchwerkForever_Thread_Tracker/Guide.lua` line 40 (PatchwerkForever_Thread_Tracker; edge-case; size S; impact low)

**Now:** local info = before and ns.Base.Guides:Read(0, before.source)
if not info then
	ns.Print('No skipped step to undo.')
	return
end
local index = before.index

Line 31: before = { source = info.source, index = from }

**Change:** Why: `before` is cleared only by a /tracker back that finds a guide (line 46). Skip step 34 by a click, play on to step 80 or let RestedXP load its next guide, and /tracker back calls SetStep(34) there and prints 'Back to step 34.'.
Change: store the guide's name and the target with it at line 31: before = { source = info.source, index = from, guide = info.guide, to = index }. In ns.GuideBack, when info.guide ~= before.guide, set before = nil and print 'No skipped step to undo.'. When it does go back and info.index ~= before.to, say how far: ('Back to step %d (from step %d).'):format(index, info.index). This matters more once the undo has a key binding.

**Checked:** Quote exact (lines 40-45, 31). Confirmed `before` is a file local with no other writer. Both readers give info.guide (PatchwerkForever/Guides/RestedXP.lua 138-140; Stitch_DungeonJournal/Reader.lua 210). The player has to type the command without a recent skip for this to bite, so impact stays low.

### TI-12. README still says Version 1.0, and files the no-mouse routing bindings under Item buttons

`addons/PatchwerkForever_Thread_Tracker/README.md` line 21 (PatchwerkForever_Thread_Tracker; docs; size S; impact low)

**Now:** Version 1.0. One piece is marked experimental and starts switched off: dungeon objectives, which depend on what Forever's dungeons report.

Line 56 (under '## Item buttons'): - **Without a mouse**: bind "Route To Next Quest" and "Route To Previous Quest" (Key Bindings, under AddOns) to step through the list; one step past either end returns to your main route.

**Change:** Drop the number from line 21 so it cannot go stale again: 'One piece is marked experimental and starts switched off: dungeon objectives, which depend on what Forever's dungeons report.' (no other addon's README states its version). Move the 'Without a mouse' bullet from '## Item buttons' to directly under the Clicks table, before the line 'A bar beside a block shows what is being followed'. The CurseForge description is a copy of the README made by tools/release.py, so it is corrected when the next release is built.

**Checked:** Quotes exact (lines 21 and 56). The TOC says '## Version: 1.1.0' and CHANGELOG.md has a 1.1.0 entry. release/ is build output (in .gitignore); tools/release.py line 314 copies README.md to CurseForge-description.md, so no hand edit there. Not the same as ROADMAP A1 (READMEs' prose in standard wording).

### TI: dropped

- **Skip Guide Step binding and /tracker skip (part of 'Undoing a guide skip (and skipping) cannot be bound'):** A new binding and command for an action he was offered in the interview and did not pick (tools/PLAN-tracker.md line 187: 'He did not pick next/previous quest or skipping a step'), so it is a feature, not polish. The undo binding from the same finding was kept.
- **Clear the arrow when Auto-Track Nearest Quest is unticked (part of the Auto-Track finding):** Not clearly roughness: the game normally keeps an arrow on a quest, and with the kept fix the option also takes over arrows the game placed on accept, so clearing on untick would remove an arrow the option did not place. Leaving the arrow where it is surprises no one. The rest of the finding was kept.

## RO: What Routes draws

### RO-1. Stop Routing leaves the fainter upcoming-steps trail on both maps

`addons/PatchwerkForever_Thread_Routes/Sources.lua` line 365 (PatchwerkForever_Thread_Routes; edge-case; size S; impact medium)

**Now:** `if not skip.reached then return end`

**Change:** Change the line to `if not skip.reached then ns.Ahead.Set({}) return end`. Leave the reached case (lines 366-367) as it is: there the next leg is still wanted for the hand-over in Ahead.Take. Ahead.Set returns early when the chain key is unchanged (Ahead.lua:48), so calling it on every half-second look costs nothing. The only trade-off: the leg found ahead of time is thrown away, so when the guide moves on after a stop the next route is searched afresh instead of handed over.

**Checked:** Quote and line exact. Traced: ns.Stop(true) clears ns.dest and ns.route only (Route.lua:423-430); Look() then builds skip with reached=false and returns at 365 before any Ahead.Set, so ns.ahead keeps its legs. WorldMap.lua:76 and Minimap.lua:113 draw on `route or ahead`, and Minimap.lua:194 keeps its ticker for `ns.ahead ~= nil`. Applies to a guide's next steps and to the way back from a selected quest alike. Not in ROADMAP.md or V1.md.

### RO-2. On a flight the trail runs back to where you took off

`addons/PatchwerkForever_Thread_Routes/Route.lua` line 339 (PatchwerkForever_Thread_Routes; edge-case; size S; impact medium; needs a look in the game)

**Now:** `if UnitOnTaxi and UnitOnTaxi('player') then return end`

**Change:** In Follow(), before that return, when ns.route is on the character's map: scan route.points from route.at + 1 for the first point whose third field is 'fly', and take j as the last point of that run of 'fly' points. If found and route.at ~= j - 1, set route.at = j - 1 and call Changed(): both maps then draw one straight piece in the Flight Color from you to where you land, then the walk on (the first drawn piece is colored by points[at + 1][3]). The scan is idempotent on later ticks, and after landing NearestOnTrail picks the next walk piece as today. Do not limit the scan to 3 points as first proposed: a route planned just after take-off (a guide's fly step completing in the air) starts with several walk points back to the flight master. When no 'fly' point lies ahead, set route.loose = true while on the taxi (clear it, with Changed(), on the first tick off it), and in the Run() of WorldMap.lua and Minimap.lua keep the loop start at trail.at but skip the join to the character while trail.loose is set (WorldMap.lua:126 `if i == at and px then`, Minimap.lua:154 `if i == at then return 0, 0 end`).

**Checked:** Quote exact. Follow() returns before route.at is moved or a new route is asked for, for the whole flight; NearestOnTrail also skips 'fly' pieces (Route.lua:317). Both maps join the character to points[at + 1], which is the flight master just left (P.Line puts the 'fly' point straight after it, Planner.lua:750). UnitOnTaxi is in the client's UnitDocumentation. Same stale line for a guide-directed flight whose next step is planned in the air. Needs one flight in game to see; how RestedXP completes a fly step could not be read here.

### RO-3. Minimap trail is cut to a circle on a square minimap

`addons/PatchwerkForever_Thread_Routes/Minimap.lua` line 172 (PatchwerkForever_Thread_Routes; visuals; size S; impact medium; needs a look in the game)

**Now:** `local cx, cy, ex, ey = InCircle(ax, ay, bx, by, edge)` (with `local edge = radius * 0.96` on line 117)

**Change:** In Trail() read the shape once per draw exactly as Nodes.lua:181 does: `local square = GetMinimapShape and GetMinimapShape() == 'SQUARE'`. When square, clip each piece to the box from -edge to edge (same edge as today) instead of InCircle. Move the box clip of WorldMap.lua:43-62 into Trail.lua (it loads before both maps in the TOC) as ns.ClipBox(ax, ay, bx, by, x0, y0, x1, y1), with the four tests `edge(-dx, ax - x0) and edge(dx, x1 - ax) and edge(-dy, ay - y0) and edge(dy, y1 - ay)`; WorldMap.lua calls it with 0, 0, 1, 1 and Minimap.lua with -edge, -edge, edge, edge. Update the header comment on Minimap.lua:3-4 ('cut off at its round edge'). First check in game that `/dump GetMinimapShape and GetMinimapShape()` prints SQUARE with EllesmereUI: if it prints nil, neither this nor the existing test in Nodes.lua can tell, and the fix does nothing.

**Checked:** Quote exact; the trail is always clipped by InCircle while Nodes.lua:181-193 already keeps node icons in the corners of a square minimap. GetMinimapShape is not in the client source (a convention set by minimap addons) and the Minimap has SetMaskTexture but no getter, so there is no other way to read the shape; the test is guarded and already used by this addon. tools/wowstub.lua:63 stubs SQUARE; tools/PLAN.md:262 records the EllesmereUI minimap at size 280. Impact lowered from high: whether EllesmereUI sets the global could not be confirmed without opening its files.

### RO-4. A route that cannot be made says nothing for a guide step, quest or gathering node

`addons/PatchwerkForever_Thread_Routes/Route.lua` line 288 (PatchwerkForever_Thread_Routes; feedback; size S; impact medium)

**Now:** `Fail(announce, why)` and, on line 206, `return nil, 'you are not standing on ground the planner knows (inside a building, on a boat, or on one?).'`

**Change:** 1. Pass the reason to the step text: `local function Fresh(dest, route, why)` hands it to `ns.FloatRoute(dest, route, why)`, and the job calls `Fresh(dest, route, why)` (line 294). In Float.lua, FloatRoute calls `ns.FloatStep(lines, route and ns.Summary(route) or (why and 'No route found') or nil, (not route and why) and true or nil)`; FloatStep keeps the flag in `last` (so FloatAgain repeats it) and Show() takes it: when set, show the small line even with Show Route Summary off and color it 1, 0.5, 0.45, otherwise set it back to 0.62, 0.85, 1. Leave the line empty when why is nil (no position, or missing map data, which is already said once in chat). 2. Reword line 206 to 'No route from here: you are not on ground the planner knows (inside a building, or on a boat or zeppelin).' Do not add a chat line per destination: guide steps are kept out of chat on purpose (Route.lua:334), and in a cave every new step would print one.

**Checked:** Quotes exact. Sources.lua:390 and Gather.lua:93 set the destination with announce = false, so Fail() prints nothing; Float.lua:106 then shows the step words with an empty second line, and Route.lua:342 retries every 10 seconds, also silently. Fresh() fires once per destination (dest.fresh), so the notice would show once and the retries stay quiet. The reader's part 2 (a chat line once per destination) was cut as chat spam against the addon's own rule for guide steps.

### RO-5. A new guide step at the spot you are standing on is not shown

`addons/PatchwerkForever_Thread_Routes/Sources.lua` line 367 (PatchwerkForever_Thread_Routes; feedback; size S; impact low)

**Now:** `if not px or pmap ~= map or Apart(px, py, x, y) < BACK[source] then return end`

**Change:** Use the local `said` (line 319) as 'the key of the guide step last shown'. Set `said = guide.key` after ns.SetDestination when `guide` is set (line 390), beside line 375, and in ns.GoToSource after its SetDestination when source == 'rxp' (line 409). Turn line 367 into a block that, before returning, does `if guide and said ~= guide.key then said = guide.key; ns.FloatStep(guide.words) end`. The key changes with the step number (Guides/RestedXP.lua:92-95), so the same step is not repeated on arrival. Optional: on line 376 the route line is ns.Summary of the route as first planned (route.seconds and route.yards are never reduced), so pass nil there if stale numbers under a new step are unwanted.

**Checked:** Quote exact. After arriving, Follow() calls ns.Stop(false), Look() sets skip.reached = true, and a next step within SAME = 5 yards returns here with no words; yet lines 374-377 show the new words when the step changes before arrival, and a step more than 5 yards away is shown through SetDestination. Confirmed by trace; the proposal's `said` is already used the same way at line 354. Impact lowered to low: you are at the NPC and the tracker's guide section shows the step; the roughness is that it is shown in one case and not the other.

### RO-6. Show Step Text Again can only be typed

`addons/PatchwerkForever_Thread_Routes/Bindings.xml` line 5 (PatchwerkForever_Thread_Routes; gamepad; size S; impact low)

**Now:** `<Binding name="PATCHWERKFOREVER_THREAD_STOP" category="ADDONS">` is the second and last binding; Core.lua:146-147 has `elseif word == 'step' then` / `ns.Try('step', ns.FloatAgain)` with no binding.

**Change:** Add a third binding `<Binding name="PATCHWERKFOREVER_THREAD_STEP" category="ADDONS">PatchwerkForever_Thread_Routes_Step()</Binding>`. In Core.lua beside lines 159-162 add `BINDING_NAME_PATCHWERKFOREVER_THREAD_STEP = 'Show Step Text Again'` and `function PatchwerkForever_Thread_Routes_Step() ns.Try('step', ns.FloatAgain) end`. Change README.md:121 ('Two actions can be bound ... route now, and stop routing') to three, and add a CHANGELOG line.

**Checked:** Quotes exact; Bindings.xml holds only GO and STOP, and README.md:121 says two actions. The family rule is that every action is bindable, and the step text fades after Duration (default 5 s). Not in ROADMAP.md or V1.md. Impact lowered to low: the tracker's guide section also shows the step.

### RO-7. Step Text sliders show nothing until Preview is pressed again

`addons/PatchwerkForever_Thread_Routes/Core.lua` line 95 (PatchwerkForever_Thread_Routes; feedback; size S; impact low; needs a look in the game)

**Now:** `{ page = 'Routes: Step Text', button = 'Show', name = 'Preview Step Text', click = function() ns.FloatTest() end,`

**Change:** In Float.lua add an ns.OnSetting watcher: for floatSize, floatDown, floatAcross, floatRoute and floatHold call ns.FloatTest(true). Give Show() a `steady` flag passed from FloatTest: when the frame is already shown, set `shown.at = GetTime() - IN` instead of `GetTime()` and skip `frame:SetAlpha(0)`, so the sample stays put while a slider is moved instead of fading in on every step. Also check in game that the sample is visible over the options panel at all: both are frame strata HIGH and the panel is toplevel, 920 x 724 and centered, so at an 18 percent Vertical Position it can sit behind the panel; if it does, have Show() set `frame:SetFrameStrata(sample and 'FULLSCREEN_DIALOG' or 'HIGH')` for the sample only. Reset To Defaults goes through the same watcher, so a sample will show after a reset that changed one of these: acceptable.

**Checked:** Quote exact; it is the last row of the page. Float.lua has no ns.OnSetting; the font size is read only in Show() (Float.lua:70), position is read each frame only while the frame is up. env.Set calls watchers with (key, value) on every slider step (base Tools.lua:124-130). Added by the check: SettingsPanel is frameStrata HIGH and toplevel in Blizzard_SettingsPanel.xml:4-5, the same strata as Float.lua:31, so the existing Preview may be hidden behind the panel at some UI scales; FULLSCREEN_DIALOG is a strata this client uses. That part needs a look in game.

### RO-8. A selected guide's next steps are drawn in the main route's color

`addons/PatchwerkForever_Thread_Routes/WorldMap.lua` line 143 (PatchwerkForever_Thread_Routes; consistency; size S; impact low; needs a look in the game)

**Now:** `r, g, b = ns.TrailColour(points[i + 1][3], follow and ns.dest and ns.dest.chosen)` (the same call is on Minimap.lua:174)

**Change:** In Ahead.lua keep a local `chosen`: `function Ahead.Set(chain, isChosen)` stores it before the key test and adds it to the key, and Publish() writes `ns.ahead = { legs = legs, chosen = chosen }`. In Sources.lua call `LookAhead(dest, picked == 'guide')` at lines 384 and 391 and pass the flag on to both ns.Ahead.Set calls inside LookAhead; LookBack stays as it is, since the way back is the main route. In Run() of both maps work out `local chosen` once: `follow and ns.dest and ns.dest.chosen` for the current route, `ns.ahead and ns.ahead.chosen` for a leg ahead, and pass it to ns.TrailColour; pass it too to the end dot on WorldMap.lua:157 (`ns.TrailColour('walk')`).

**Checked:** Quote exact. With a second guide's list selected, Target() returns picked = 'guide', so dest.chosen is true (Sources.lua:389) and the current route uses Selected Route Color, but its next steps go through LookAhead and are drawn with follow = false, so in Walking Color, the same look as the main guide's steps. Only this half of the reader's finding is kept; the draw-order half is dropped (see dropped). Only seen with the Dungeon Journal list selected.

### RO-9. Dotted and dashed trails merge at wide line widths

`addons/PatchwerkForever_Thread_Routes/Trail.lua` line 34 (PatchwerkForever_Thread_Routes; visuals; size S; impact low; needs a look in the game)

**Now:** `gap = (small and 7 or 9) * per` (and line 32: `dash, gap = (small and 6 or 10) * per, (small and 5 or 7) * per`)

**Change:** Give ns.TrailPen a third argument, the line width in screen pixels: `local grow = math.max(1, (width or 0) / (small and 2.5 or 3))` and multiply dash and gap by grow. Callers: WorldMap.lua:94 `ns.TrailPen(1 / scale, false, ns.Get('trailThickMap') or 3)` and Minimap.lua:120 `ns.TrailPen(1, true, full)`. At the default widths (3 and 2.5) grow is 1 and nothing changes; wider lines get spacing in proportion.

**Checked:** Quotes exact. Dots are sized thick * 2.2 (WorldMap.lua:117, Minimap.lua:147) and tools/media.py:84-86 draws the disc solid to 64 percent and faded out at 78 percent of the texture, so with a 9 px spacing the dots touch from about World Map Line Width 5.5 (slider max 8) and with 7 px from about Minimap Line Width 4.5 (max 6). Only with Line Style set to Dotted or Dashed (default is Solid) and a widened line, hence low.

### RO-10. "To the spot you gave" on screen for /thread to

`addons/PatchwerkForever_Thread_Routes/Float.lua` line 96 (PatchwerkForever_Thread_Routes; wording; size S; impact low)

**Now:** `local OWN = { pin = { 'To your map pin' }, spot = { 'To the spot you gave' } }`

**Change:** Show the coordinates themselves: in ns.GoToMapSpot (Route.lua:454) call `ns.SetDestination(map, x, y, false, true, nil, { lines = { ('To %.1f, %.1f'):format(xPercent, yPercent) } })`, and change the fallback OWN.spot to 'To your coordinates'.

**Checked:** Quote exact. The rest of the in-game text says 'coordinates' (Core.lua:105, Sources.lua:449, Route.lua:450). SetDestination copies `more` onto the destination and Float.lua:101 is the only reader of dest.lines for a destination with no source, so the change is safe. Low: /thread to is typed, which this gamepad player rarely does.

### RO-11. Minimap trail steps 20 times a second while the minimap turns every frame

`addons/PatchwerkForever_Thread_Routes/Minimap.lua` line 196 (PatchwerkForever_Thread_Routes; smoothness; size S; impact low; needs a look in the game)

**Now:** `ticker = C_Timer.NewTicker(EVERY, function() ns.Try('the minimap trail', Draw) end)` with `local EVERY = 0.05        -- seconds between redraws` (line 13)

**Change:** Replace the ticker with an OnUpdate on a frame of its own (CreateFrame('Frame'), shown and hidden by Watch()). Each frame read ns.Place() and, when GetCVar('rotateMinimap') == '1', GetPlayerFacing(); call Draw at once when position or facing differ from the last draw, otherwise only once EVERY seconds have passed, as today. Do not skip draws on a wider 'nothing changed' test as first proposed: the layer is a child of UIParent, not of the minimap (top of the file), and is only hidden when Draw runs and ns.MinimapView finds the minimap hidden or faded, so a skipped draw would leave the trail floating. To keep per-frame draws light, have ns.MinimapView anchor the layer once and call SetFrameStrata/SetFrameLevel only when they differ from the minimap's. Nodes.lua:214 (MINI_EVERY) can be driven the same way.

**Checked:** Quotes exact; every tick hides and re-places all lines and re-anchors the layer (Minimap.lua:54-58, 80-84). The visible part is with Rotate Minimap on: a turn of half a circle a second moves the rim of a 280 px minimap about 22 px between draws; without rotation the step is under a pixel except at close zoom. The cost claim is weak (160 lines 20 times a second is cheap), so the proposal is cut to the smoothness part and the size to S. Whether this player rotates the minimap is not known.

### RO: dropped

- **Step text default position lands on the game's own messages:** The quote is right (Core.lua:91, default 18) and UIErrorsFrame is at TOP y=-122, 60 high, on this client, but the overlap only holds for a 768-high UIParent. Vertical Position is a percent while the game's frames sit at fixed offsets: at the smaller UI scales EllesmereUI users run (UIParent 1080 to 1440 high) today's 18 percent starts below UIErrorsFrame, and the proposed 7 percent (76 to 100 px, text running to about 140 to 165) would land on it. No single percent clears it at all scales, 7 percent also sits near UIWidgetTopCenterContainerFrame (TOP y=-15), and the position was seen in play. Cannot be confirmed without the player's UI scale, and the proposed default could make it worse.
- **Fainter trails have no fixed order against the current route (draw-order half of the finding):** All lines and dots are in OVERLAY with no sublevel (WorldMap.lua:36, 111; Minimap.lua:127, 141), but the pools always hand the lowest-numbered, earliest-made lines to the current route, so the order is the same on every draw in practice; the client source does not say how regions in one sublevel are ordered, so 'no fixed order' cannot be confirmed. Which of a thin faint line and the bright line should lie on top where they retrace each other is taste, not roughness. The color half of the same finding is kept.

## RT: What Routes says, and how its state moves

### RT-1. Gathering runs and "show the step again" have no binding

`addons/PatchwerkForever_Thread_Routes/Bindings.xml` line 5 (PatchwerkForever_Thread_Routes; gamepad; size S; impact medium)

**Now:** <Binding name="PATCHWERKFOREVER_THREAD_STOP" category="ADDONS">
		PatchwerkForever_Thread_Routes_Stop()
	</Binding>
</Bindings>

**Change:** Add two bindings in the same form after the Stop binding: PATCHWERKFOREVER_THREAD_GATHER calling PatchwerkForever_Thread_Routes_Gather(), and PATCHWERKFOREVER_THREAD_STEP calling PatchwerkForever_Thread_Routes_Step(). In Core.lua after line 162 add: BINDING_NAME_PATCHWERKFOREVER_THREAD_GATHER = 'Toggle Gathering Run' with `function PatchwerkForever_Thread_Routes_Gather() ns.Try('gather', ns.GatherSay, ns.GatherActive() and 'stop' or '') end`; BINDING_NAME_PATCHWERKFOREVER_THREAD_STEP = 'Show Step Text Again' with `function PatchwerkForever_Thread_Routes_Step() ns.Try('step', ns.FloatAgain) end`. Change README.md line 121 ("Two actions can be bound ... route now, and stop routing") to name all four.

**Checked:** Confirmed: Bindings.xml has only GO and STOP. A run can be started only by /thread gather (Core.lua:150) or a mouse click in the tracker's Gathering section (the tracker's Bindings.xml has Fold, Next, Previous and the item button, nothing for gathering). The step text is recalled only by /thread step (Core.lua:146). ns.GatherSay, ns.GatherActive, ns.FloatAgain and ns.Try(label, fn, ...) all exist with these signatures. Not listed in ROADMAP.md or V1.md; V1's own bar says it must be drivable from a gamepad. No game API needed beyond the existing binding globals.

### RT-2. Stop says "Routing stopped." whatever was stopped, then the main route starts again half a second later

`addons/PatchwerkForever_Thread_Routes/Route.lua` line 429 (PatchwerkForever_Thread_Routes; feedback; size S; impact medium)

**Now:** if announce then ns.Print(had and 'Routing stopped.' or 'No active route.') end

**Change:** In ns.Stop, when announce is true, choose the line from `had`: nil -> 'No active route.' (unchanged); had.source == 'gather' -> 'Gathering stopped.' (the same words Gather.lua:161 uses); had.pin -> 'Routing to your map pin stopped.'; no source and no pin (/thread to) -> 'Routing to your coordinates stopped.'; otherwise ('rxp' or 'quest') -> 'Routing stopped. It resumes when the guide step or quest objective changes, or with /thread go.' Behavior stays as it is. Bring the help line at Core.lua:106 ('/thread stop: stop routing (resumes when the guide step or quest objective changes)') in step: the resume note applies only to guide and quest routes.

**Checked:** Confirmed by tracing. Sources.lua Look() (lines 331-338) sets `skip` only when the stopped destination had a source, so after Stop on a pin or a /thread to spot the next look (0.5 s) calls Target() and routes to the guide or quest. For a gathering run, Gather.lua Watch (lines 128-133) ends the run silently and Look() then does the same. For a guide or quest stop, `skip` with reached = false holds until the place changes, and ns.GoToSource clears it, so the proposed resume wording is accurate. ns.Stop(true) is called only from the slash command and the Stop binding.

### RT-3. Step text is shown again each time you wander away from a step you already reached

`addons/PatchwerkForever_Thread_Routes/Sources.lua` line 367 (PatchwerkForever_Thread_Routes; smoothness; size S; impact medium; needs a look in the game)

**Now:** if not px or pmap ~= map or Apart(px, py, x, y) < BACK[source] then return end
		end
		skip = nil

**Change:** When the place being set is the one `skip` held as reached, set it without the on-screen text. (1) At line 336 keep the step in the skip record: add `step = was.step`. (2) Declare `local again` before the `if skip then` block (line 363) and, just before `skip = nil` (line 369), set `again = skip.reached and skip.source == source and skip.map == map and Apart(skip.x, skip.y, x, y) <= SAME and skip.step == (guide and guide.index or nil)`. (3) Before the SetDestination at line 390: `if again then more = more or {}; more.fresh = false end`. SetDestination copies `more` over its own `fresh = true` (Route.lua:399-402), so Fresh() (Route.lua:183-188) stays quiet; the trail still comes back, and /thread step still shows the last text. The step comparison keeps a new guide step at the same spot from being silenced.

**Checked:** Confirmed in code: arriving (Route.lua:332-333) leaves a reached `skip`; once you are 40 yards (guide) or 120 yards (quest) away, line 369 clears it and line 390 sets the same place again with fresh = true, so Float shows the same words and a new summary. Float.lua:9 states nothing is said when the way is only found again. Corrected the proposal: as written it would also silence a different guide step that shares the spot, so the step index is now compared. Cut the reader's note about RestedXP completing its own waypoint: it could not be read and is not part of this fix. How often it shows in play needs a look in the game.

### RT-4. A map pin you already reached or stopped is routed to again after a loading screen

`addons/PatchwerkForever_Thread_Routes/Route.lua` line 489 (PatchwerkForever_Thread_Routes; edge-case; size S; impact medium; needs a look in the game)

**Now:** ns.On('PLAYER_ENTERING_WORLD', function()
	if not ns.dest then PinChanged(false) end
end)

**Change:** Pick the pin up only at login and reload: `ns.On('PLAYER_ENTERING_WORLD', function(isInitialLogin, isReloadingUi) if (isInitialLogin or isReloadingUi) and not ns.dest then PinChanged(false) end end)`. A pin placed at any other time is still caught by USER_WAYPOINT_UPDATED (line 488), and a destination already set survives a loading screen, so nothing else depends on this handler.

**Checked:** Confirmed: arrival and Stop only call ns.Stop (lines 333, 423-430) and never touch the pin; ns.dest is nil while you stand at a reached step or the guide step has no place (Sources.lua:348-353, e.g. a hearthstone step). A loading screen then makes PinChanged route to the old pin with 'To your map pin', and Look() (Sources.lua:327) follows nothing else until the pin is gone. The base's ns.On passes the event payload without the event name (PatchwerkForever/Tools.lua:149-155), and SystemDocumentation.lua:134-142 lists isInitialLogin and isReloadingUi for this client. The game's Lua clears a pin only on a click (WaypointLocationDataProvider.lua:86, Blizzard_WorldMap.lua:764, QuestMapFrame.lua:2437); whether the client itself removes a pin on arrival cannot be read from the source, so the reached half needs a look in the game, while the stopped half holds either way. Cut the reader's 'Remove Map Pin On Arrival' setting: that is a new feature.

### RT-5. /thread quest names the wrong thing as followed when a pin, a gathering run or a selected guide is steering

`addons/PatchwerkForever_Thread_Routes/Sources.lua` line 446 (PatchwerkForever_Thread_Routes; feedback; size S; impact low)

**Now:** elseif source == 'rxp' then
		ns.Print('Following: your RestedXP guide (it has priority; change this in the options).')
	elseif ns.dest and not ns.dest.source then
		ns.Print('Following: your map pin or coordinates (always first).')

**Change:** Reorder the closing block of ns.QuestSay (lines 442-452) to the order Look() uses. 1) `ns.GatherActive and ns.GatherActive()` -> 'Following: your gathering run. /thread gather stop ends it.' 2) `ns.dest and not ns.dest.source` -> 'Following: your map pin or coordinates (always first).' 3) Only then `local source, map, _, _, picked = Target()`. For 'rxp' print 'Following: your ' .. (guide.reader or 'guide') .. ' guide', add ' (selected by you)' when picked == 'guide', and add ' (it has priority; change this in the options)' only when it is not picked and ns.Get('sourceFirst') == 'rxp'. 4) When Target() gives a source but no map, add ' The current step has no location.'; when it gives a map but ns.dest is nil, add ' Not routing now: stopped, or already there.' Also replace the bare continent numbers at lines 422-423, 431 and 436 ('Continent: %s', 'on continent %d') with names from a small table { [0] = 'Eastern Kingdoms', [1] = 'Kalimdor', [2991] = 'Zephras Isle' }, falling back to 'map ' .. number.

**Checked:** Confirmed: Target() (lines 238-290) never looks at ns.dest or the gathering run, so with a pin placed or a run on, this command still reports the guide. A guide list chosen in the tracker returns 'rxp' with 'guide' as fifth value (line 258) and is reported as the RestedXP guide with priority. The priority clause is also printed when sourceFirst is 'quest' and the guide is only the fallback. guide.reader exists (PatchwerkForever/Guides.lua:80). The repository spells the third map 'Zephras Isle' (data TOC title, tools/pack.py), not "Zephra's Isle" as the reader wrote. Impact lowered: it is a diagnostic slash command.

### RT-6. "Print Route In Chat" promises more than it does, and "Priority" does not say what always comes first

`addons/PatchwerkForever_Thread_Routes/Core.lua` line 39 (PatchwerkForever_Thread_Routes; wording; size S; impact low)

**Now:** { key = 'notify', default = true, name = 'Print Route In Chat',
		desc = 'Print the time, distance and flights of each new route in chat.' },

**Change:** Text only. (1) notify desc -> 'Print the time, distance and flights in chat when you route to a map pin or coordinates or use /thread go, and a line when you arrive or discover a flight point. Routes followed from your guide or quests are shown on screen instead.' (2) sourceFirst (lines 28-30): name 'Priority' -> 'Route Priority'; desc -> 'Which to follow when both your guide and a tracked quest have a destination. The other is used when the first has none you can reach. A map pin, a quest or guide you selected in the tracker, and a gathering run always come before both.'

**Checked:** Confirmed: the route line is printed only where announce is true (Route.lua:292, 413): a pin, /thread go, /thread to, a changed travel option. Routes set by Look() and by a gathering run pass announce = false (Sources.lua:390, Gather.lua:93). The same setting gates 'You have arrived.' (Route.lua:335), 'Routing to quest' (Sources.lua:405) and the flight point line (Flights.lua:188). 'none on this continent' is out of date: Target() accepts another continent when ns.CanCross allows it (Sources.lua:281). Order of pin, run, selection and main route checked against Look().

### RT-7. Several chat lines read wrong: a garbled failure reason, an ambiguous one, a raw load reason, and the gathering-run lines

`addons/PatchwerkForever_Thread_Routes/Route.lua` line 206 (PatchwerkForever_Thread_Routes; wording; size S; impact low)

**Now:** return nil, 'you are not standing on ground the planner knows (inside a building, on a boat, or on one?).'

**Change:** Reword in place; nothing else changes. Route.lua:206 -> 'You are not standing on ground the planner knows. Are you inside a building, or on a boat or lift?' Route.lua:230 ('No route found. The location may be unreachable by something the planner does not know: a lift, a boat or a locked gate.') -> 'No route found. The location may only be reachable by a lift, boat or portal the planner does not know.' Route.lua:63-64: print `_G['ADDON_' .. tostring(reason)] or tostring(reason or ok)` in place of the raw token, and end with 'It is a separate addon: check it is installed and enabled in the AddOns list.' Gather.lua:164-165 -> 'Gathering run started near here: nearest node first, then the next. /thread gather stop ends it.' (round) and 'Gathering run started: nearest node first, then the next. /thread gather stop ends it.'; Gather.lua:182 -> 'Gathering run started: nearest %s first, then the next. /thread gather stop ends it.' Gather.lua:87-88: when state.going is nil (the run never began) print 'No herb or ore nodes recorded nearby, or all were visited in the last 5 minutes.' (or 'No %s nodes ...'), without 'Gathering stopped.'; otherwise 'All nearby nodes were visited in the last 5 minutes. Gathering stopped.'

**Checked:** All quoted lines confirmed at the lines given. `_G["ADDON_" .. reason]` is how this client's own code shows the reason (Blizzard_SharedXML/AddOnUtil.lua:6, Blizzard_AddOnList/AddonList.lua:409). Two corrections to the reader: Route.lua:230 is ambiguous, not inverted, and since the README says locked doors count as open, 'locked gate' is dropped from the new text; and for Gather.lua:87 a first pick can also fail because every node was visited in the last 5 minutes (the `visited` table outlives a run), so 'none recorded within 3000 yards' would be wrong there.

### RT-8. The Go command in an area without map data prints nothing, and a route that cannot be found shows the step with no reason

`addons/PatchwerkForever_Thread_Routes/Route.lua` line 273 (PatchwerkForever_Thread_Routes; feedback; size S; impact low)

**Now:** if not Data(map) or (map ~= dest.map and not Data(dest.map)) then
		Fresh(dest)
		return Fail(false)
	end

**Change:** (1) In chat, when asked: give Data (lines 53-66) an optional second parameter `say`. Where it now calls Once(key, text), do `if say then told[key] = true; ns.Print(text) else Once(key, text) end`. In ns.Plan line 273 call Data(map, announce) and Data(dest.map, announce). Unannounced plans keep the once-a-session behavior; /thread go and the Go binding always get the reason. (2) On screen: in the job (lines 285-294) call `Fresh(dest, route, why)`, let Fresh pass `why` to ns.FloatRoute(dest, route, why), and at Float.lua:106 use `route and ns.Summary(route) or (why and not (UnitOnTaxi and UnitOnTaxi('player')) and 'No route found') or nil` as the smaller line. Only a failed Search passes a reason, so steps shown in a dungeon (no map data) stay as they are.

**Checked:** Confirmed: the reason for missing map data is printed by Once() once a session (lines 46-51, 57, 63), and the first automatic plan after entering such an area uses it up, so /thread go there prints nothing; for a quest it prints 'Routing to quest "X":' (Sources.lua:406) with nothing after the colon. Routes from Look() are planned with announce = false, so Fail(false, why) at line 288 says nothing and the step text appears without a trail; Follow retries every 10 seconds (line 342). Corrected the reader's mechanism for (1): returning the text from Data and passing it to Fail would print it twice the first time. Added the taxi guard so a step that arrives mid-flight does not read 'No route found'. UnitOnTaxi exists on this client. Impact lowered: both cases are uncommon.

### RT-9. No confirmation after the flight map is read, although the one-time notice tells you to open it

`addons/PatchwerkForever_Thread_Routes/Flights.lua` line 158 (PatchwerkForever_Thread_Routes; feedback; size S; impact low)

**Now:** mine.seen[map] = true

**Change:** In AtFlightMaster, take `local first = not mine.seen[map]` before line 158. Right after line 158 (before the loop at 164 that can return), when `first`, count the entries of `listed` that are true and print once: ('Flight map read: %d flight points known on this continent.'):format(n). Do not gate it on Print Route In Chat: the notice it answers (Route.lua:82) is not gated either, and mine.seen is saved per character, so it prints once per continent per character. Also change line 188 from 'Flight point learned: %s.' to 'Flight point discovered: %s.'

**Checked:** Confirmed: AtFlightMaster prints nothing; the only flight line is line 188, `if ns.Get('notify') then ns.Print(('Flight point learned: %s.'):format(tostring(best[2]))) end`. Route.lua:82 tells the player to open the flight map once on each continent, and afterwards only the route changes silently through Changed(). 'discovered' is the word in the setting tooltip (Core.lua:35) and README line 49; 'learned' appears in no other player-facing text of this addon. Impact lowered from medium: it is one line, once per continent.

### RT-10. A gathering run started with /thread gather keeps the selected quest; the Go command during a run leaves a frozen guide destination

`addons/PatchwerkForever_Thread_Routes/Gather.lua` line 163 (PatchwerkForever_Thread_Routes; edge-case; size S; impact low)

**Now:** if Start(rest == 'round' and 'round' or 'any') then

**Change:** (a) In ns.GatherSay start through the base service, as the tracker does: replace the two local Start(...) calls (lines 163 and 181) with ns.Base.Gather:Start(mode, name), which clears the selected quest or guide first (PatchwerkForever/Gather.lua:50-53) and returns the same true or false. (b) In ns.GoToSource (Sources.lua:395-411), right after `if not source then return false end`, add `if ns.GatherActive and ns.GatherActive() then ns.Base.Gather:Stop(); ns.Print('Gathering stopped.') end`, so Go with no pin ends the run before it routes to the guide or quest, and a run is left alone when there is nothing to route to.

**Checked:** Confirmed: the local Start (Gather.lua:106-117) does not clear the base's Choice, so the tracker's ns.Marked (Tracker/Actions.lua:96-98) keeps marking the selected quest during the run, and when the run ends Target() routes to that quest; README line 44 says starting a run lets the quest go. For (b): ns.Go with no pin calls GoToSource, which sets a guide destination while the run is still on; Look() returns at Sources.lua:322 for the whole run, so that destination never follows the guide, and on arrival Gather's Watch (lines 124-138) starts the run again. Moved the reader's fix from ns.Go into GoToSource so a run is not ended when there is no guide step or quest to go to.

### RT-11. /thread flights reports "0 known, 0 not" before the map data is loaded and where there are no flight points, and contradicts itself with the setting off

`addons/PatchwerkForever_Thread_Routes/Flights.lua` line 217 (PatchwerkForever_Thread_Routes; edge-case; size S; impact low)

**Now:** ns.Print(('Flight points on this continent: %d known, %d not.'):format(#have, #lack))

**Change:** Export Route.lua's local Data as ns.Data. At the top of ns.FlightsSay (after the position check) call ns.Data(map); if #Points(map) == 0 afterwards, print 'No flight points on this map.' and return. Call ns.Data(map) at the top of Found() (line 172) too, so a flight point discovered before any route was planned is still remembered. When ns.Get('knownOnly') is false, drop '; until then routes go on foot' from line 223, and when ns.Get('flights') is false print 'Use Flight Paths is disabled: routes do not fly.'

**Checked:** Confirmed: Points(map) (lines 59-63) reads the continent's data addon, which is LoadOnDemand (all three data TOCs) and loaded only by Route.lua's Data() when a route is planned. Zephras Isle's Extra.lua has an empty M.points, so there the command prints the zero line and then 'Open a flight map at any flight master'. In Found(), P.CellOf returns nil with the data not loaded (Planner.lua:246-248), so the discovery is silently dropped. With Known Flight Points Only off, line 216 says every flight point is used and line 223 can still say routes go on foot. All of it is rare for a player whose guide plans a route at login, hence low.

### RT: dropped

- **A new destination can be set and planned while you are on a flight path:** Not confirmed as roughness. The main scenario (a guide's fly step planned back to the flight master from mid-air) rests on how RestedXP completes that step, which the reader says could not be read. The part the code does confirm, a reached quest or guide place routed to again once you are 40 or 120 yards away, is the same event as the 'step text shown again' finding, and that fix already removes what the player would see. The proposed `if not dest and UnitOnTaxi(...)` guard would also hold back destinations that are really new until landing, which changes behavior more than it polishes. Flying within 12 yards of a pin to get a false 'You have arrived.' is too unlikely to list.

## SP: Sparkle

### SP-1. The preview does not follow the settings as they change

`addons/PatchwerkForever_Thread_Sparkle/Sparkle.lua` line 736 (PatchwerkForever_Thread_Sparkle; feedback; size M; impact medium)

**Now:** if key:find('^sparkle') or key:find('^look%.') or key:find('^name') then Refresh() end  -- (inside ns.OnSetting, lines 734-737). Refresh() only redraws the live mark on a real object. The preview mark is dressed once in ns.SparkleTest (line 534: `local look = Look(kind)` / `Dress(test, look)`), keeps that look table, and is hidden by `C_Timer.After(TEST_SECONDS, ...)` with TEST_SECONDS = 6. Dragging Size, Brightness, Color or Animation Speed changes nothing on screen until Preview Sparkle is pressed again. Sparkle: Names (Core.lua:44-65) has no preview button at all.

**Change:** Do this together with the placement fix (the next finding), or the mark will pop up over the rows being dragged. (1) ns.SparkleTest(kind, keep): before overwriting, `local same = keep and test:IsShown() and test.kind == kind`; call Arrive(test) only when not same; set `test.kind = kind`. Replace the C_Timer with `test.hideAt = GetTime() + TEST_SECONDS` and, in NewMark's OnUpdate, `if self.hideAt and GetTime() >= self.hideAt then self.hideAt = nil; self:Hide(); return end`, so a slider drag does not queue one timer per step. (2) In the OnSetting handler, only when `SettingsPanel and SettingsPanel:IsShown()`: `local kind = key:match('^look%.(%a+)%.')`; names = `key == 'sparkleName' or key:find('^name')`. Collect kinds in a table and act on the next frame (C_Timer.After(0, ...)): one kind changed -> ns.SparkleTest(kind, true); only a name setting changed -> ns.SparkleTest(test and test.kind or 'herb', true); more than one kind in the same frame (Reset To Defaults, Apply Subtle Preset) -> only re-dress a preview that is already showing. (3) Add a button row to Sparkle: Names: button = 'Test', name = 'Preview Name', click = ns.SparkleTest('herb'), desc = 'Preview the name on a sparkle for a few seconds.' (4) Preview Sparkle tooltip (Core.lua:87): 'Preview this sparkle for a few seconds. The preview also follows the settings as you change them.'

**Checked:** Confirmed: the test mark's look is captured at press time and the OnSetting handler only calls Refresh(), which touches the live mark. The game's slider control writes the setting on every step (forever-src Blizzard_Settings_Shared/Blizzard_SettingControls.lua, SettingsSliderControlMixin:OnSliderValueChanged), and the base passes that to ns.Set and the watchers (PatchwerkForever/Tools.lua:124-130), so the hook point works. SettingsPanel and C_Timer.After exist on this client. The reader's quote was the handler folded onto one line; corrected to the real line. Impact lowered from high to medium: it is felt only while setting up looks, though strongly there (30 look settings, the button seven rows down). Added the Names preview button as the simple part.

### SP-2. The preview lays the name and height out differently from a real sparkle, and is drawn across the option rows

`addons/PatchwerkForever_Thread_Sparkle/Sparkle.lua` line 542 (PatchwerkForever_Thread_Sparkle; layout; size M; impact medium; needs a look in the game)

**Now:** test:SetFrameStrata('DIALOG') (line 540) / test:SetPoint('CENTER', UIParent, 'CENTER', 0, 120) (line 542) / Write(test, test, 'This is ' .. (KIND_NAMES[kind] or kind), look) (line 543). A real sparkle is placed with `live:SetPoint('CENTER', plate, 'CENTER', 0, look.height)` and `Write(live, plate, name, look)` (lines 514-515). The preview never uses look.height and hangs the name on the sparkle's own middle: with the defaults (Vertical Offset -40, Position Below, Offset 14) the real name's top is 26 above the sparkle's middle, the preview's 14 below it, and the Vertical Offset slider shows nothing in the preview.

**Change:** (1) Give the preview a stand-in for the nameplate: a 1 x 1 frame `stand` on UIParent; `test:SetPoint('CENTER', stand, 'CENTER', 0, look.height)` and `Write(test, stand, ...)`, so Vertical Offset, Position and Offset show as they will in the world. (2) Place `stand` clear of the options panel when there is room: if SettingsPanel is shown and the gap between its right edge and UIParent's right edge (GetRight() times GetEffectiveScale() for each, compared in the same units) is at least look.size + 60, put `stand` in the middle of that gap at the panel's vertical middle; otherwise keep today's place (UIParent CENTER, 0, 120). Do not add a dark backing: beside the panel the preview is seen over the world, as a real sparkle is. (3) Tooltip (Core.lua:87): drop 'in the middle of the screen'. (4) Check once in the game whether the preview is the same size as a real sparkle: the real mark is parented to the nameplate and inherits its scale, the preview UIParent's. If they differ, keep `live:GetEffectiveScale()` from the last real sparkle and apply the ratio with test:SetScale().

**Checked:** Confirmed in code: the preview ignores look.height and anchors the name to the mark, the real one to the nameplate; the 26-above against 14-below arithmetic is right. The options panel is 920 x 724, anchored CENTER, strata HIGH, parented to the top-level parent (forever-src Blizzard_SettingsPanel.xml:4-8, Blizzard_SettingsPanel.lua:62), and it has no drag script, so a DIALOG mark at centre +120 does sit over the rows; how bad that looks needs the game. Cut from the reader's proposal: the dark backing and 'Preview' caption (new chrome, and it would make the preview less like the real thing). The gap beside the panel is about 220 wide on a 16:9 screen, enough for sizes up to about 160; larger sizes fall back to today's place.

### SP-3. Undo does not undo the last ignore, and from a gamepad an ignore cannot be taken back

`addons/PatchwerkForever_Thread_Sparkle/Sparkle.lua` line 626 (PatchwerkForever_Thread_Sparkle; gamepad; size S; impact medium)

**Now:** if last and last.name and IgnoreList()[last.name] then  -- ns.IgnoreUndo removes the object targeted last, not the one ignored last. Help says '  /sparkle undo: undo the last ignore;  /sparkle list: show the ignore list;  /sparkle clear: clear it' (Core.lua:117) and the ignore line ends '" added to the ignore list. /sparkle undo to revert.' (Sparkle.lua:621). Ignore a mailbox, walk on to an herb, type /sparkle undo: 'The last targeted object is not on the ignore list. /sparkle list shows the list.' The only binding is BINDING_NAME_PATCHWERKFOREVER_SPARKLE_IGNORE = 'Ignore Targeted Object' (Core.lua:149).

**Change:** (1) Keep the name of the most recent ignore in a file local (`undo = last.name` in ns.IgnoreThis). ns.IgnoreUndo removes `undo` when it is set and still on the list, then clears it; otherwise it falls back to last.name as today. (2) Make the existing binding a toggle, keeping its internal name so saved bindings survive: PatchwerkForever_Thread_Sparkle_Ignore() calls a new ns.IgnoreToggle, which removes last.name and prints '"%s" removed from the ignore list.' when it is on the list, and otherwise calls ns.IgnoreThis. Rename it 'Ignore / Stop Ignoring Targeted Object' (the tracker has 'Collapse / Expand Tracker'). /sparkle ignore stays add-only. (3) Ignore line: '"%s" added to the ignore list. Press the binding again or type /sparkle undo to remove it.' (4) Bring the Clear Ignore List tooltip (Core.lua:41) and README.md lines 45 and 49 in line with it.

**Checked:** Confirmed: after the ignore, Update() rebuilds `last` for whatever is targeted next, so undo looks at the wrong object and the help text and README ('takes the last ignore back') are wrong. Bindings.xml holds only the one binding, so Clear Ignore List (which drops everything) is the only way back without a keyboard. This is not ROADMAP S1 (the list in the options with remove buttons); S1 would add a second way back, but the undo fix and the wrong help line stand on their own. Best done after the stale-target finding below, since the toggle acts on `last`.

### SP-4. While sparkles are hidden the last-targeted record goes stale, so the Ignore binding and /sparkle act on the wrong object

`addons/PatchwerkForever_Thread_Sparkle/Sparkle.lua` line 498 (PatchwerkForever_Thread_Sparkle; edge-case; size S; impact low)

**Now:** if Barred() or not IsThing(UNIT) then return Hide() end  -- comes before `last = { name = name, kind = kind, ... time = GetTime() }` (lines 504-505). While Barred() is true (Hide In Combat in combat, Hide In Instances in an instance, Enable Sparkles off) `last` is not updated, yet ns.IgnoreThis does `IgnoreList()[last.name] = true` (line 620) and /sparkle prints `Told('Targeted', last)` (line 708). `last` also never expires: the binding pressed with nothing targeted ignores an object from minutes ago, and 'Targeted %d s ago' (line 712) counts from last.time, the last update while it was targeted, not from when the target was lost.

**Change:** In Update(): `if not IsThing(UNIT) then if last and not last.lost then last.lost = GetTime() end; return Hide() end`. Then `local barred = Barred()`, build `last` as today with `shown = not barred and wanted and plate ~= nil` and a new field `barred = barred`, then `if barred or not wanted or not plate then return Hide() end`. In ns.IgnoreThis (and the undo fallback) call Refresh() first, then use `last` only when `IsThing(UNIT)` or `last.lost and GetTime() - last.lost <= 20` (a named constant; long enough to open chat and type the command); otherwise print the existing 'No object targeted. Walk up to one first.' In ns.SparkleSay use `GetTime() - (last.lost or last.time)` for 'Targeted %d s ago'.

**Checked:** Confirmed by tracing Update(), IgnoreThis and SparkleSay: with Hide In Instances on, the binding ignores whatever was last seen outside, and /sparkle can print the old object as 'Targeted ... it sparkles' right after 'Sparkles are currently hidden'. Keeping `last` after the target drops is deliberate (comment at lines 493-494: typing can clear the target), so the 20-second window keeps that and only stops very old records. Extra work while barred is small: Kind() and Plate() run only when a game object is actually targeted. Impact lowered to low: it needs Hide In Combat or Hide In Instances (both off by default) or a press with nothing targeted, and the chat line names what was ignored. Note the ignore is by name, so a wrong ignore silences every object of that name.

### SP-5. Name and fade settings stay active when their master tick box is off

`addons/PatchwerkForever_Thread_Sparkle/Core.lua` line 47 (PatchwerkForever_Thread_Sparkle; consistency; size S; impact low)

**Now:** { page = 'Sparkle: Names', key = 'nameSize', default = 13, min = 8, max = 32, step = 1, name = 'Font Size',  -- none of the seven settings under Show Object Name (lines 47-65) has a parent. On Sparkle: Behind My Character the five sliders under Fade Behind Character have none either, e.g. `add({ key = 'sparkleBehindLeft', default = 0, min = 0, max = 80, step = 5, name = 'Minimum Opacity',` (line 96). The first page does it: `parent = 'sparkle'` (lines 32-36). Fade Behind Character is off by default, so its page opens as five live sliders that do nothing.

**Change:** Add `parent = 'sparkleName'` to nameSize, nameFont, nameOutline, nameColour, nameFixed, namePlace and nameOffset (Core.lua:47-65) and `parent = 'sparkleBehind'` to sparkleBehindLeft, sparkleBehindSize, sparkleBehindWide, sparkleBehindAcross and sparkleBehindUp (Core.lua:96-105). No base change is needed: PatchwerkForever/Tools.lua:260-264 already calls SetParentInitializer for any control with a parent. Leave the Preview Area button as it is (buttons take no parent).

**Checked:** Confirmed: both master tick boxes are defined before their children on the same page, which is what Tools.lua needs (it looks the parent up in tool.controls). On this client a child row is indented, set in the small font and greyed for sliders, lists and color rows (forever-src Blizzard_SettingControls.lua:243-244, 309-319, 356-359, 927-934); the color swatch greys only its label (SetButtonState is empty, line 1166). Disabled rows are also skipped by the client's own gamepad navigation (DisplayEnabled calls SmartNavigation_MarkFrameIgnored). Impact lowered to low: seen only on two options pages.

### SP-6. The two game settings are not put back on logout, and nothing is said if the game turns one off

`addons/PatchwerkForever_Thread_Sparkle/Sparkle.lua` line 731 (PatchwerkForever_Thread_Sparkle; edge-case; size S; impact low; needs a look in the game)

**Now:** ns.On('PLAYER_LOGIN', function()
	Needs(ns.Get('sparkle'))
end)  -- and `if key == 'sparkle' then Needs(value) end` (line 735) are the only two calls of Needs. There is no PLAYER_LOGOUT handler, so the kept originals (db.sparkleWas) go back only when Enable Sparkles is unticked: disabling or removing the addon leaves SoftTargetNameplateInteract and SoftTargetIconGameObject on, though V1.md S4 reads 'restored when it is disabled or removed'. The game also writes one of them itself: its Interact Key Icons option does SetCVar("SoftTargetIconGameObject", "0") for two of its three choices (forever-src Blizzard_SettingsDefinitions_Frame/Accessibility.lua:191-207). After that, sparkles stop without a word until the next login.

**Change:** (1) Add `ns.On('PLAYER_LOGOUT', function() Needs(false) end)`: the originals go back into the game's saved settings whenever you leave or reload, and the existing PLAYER_LOGIN handler turns them on again. Confirm once in the game that a SetCVar made at PLAYER_LOGOUT is saved (log out, disable the addon, log in, /dump GetCVar('SoftTargetNameplateInteract')). (2) In Update(), when the object is wanted but `plate` is nil, out of combat, check the two names in NEEDS; if GetCVar(name) is not nil and not '1', call Needs(true) and print, at most once per name per session: 'Turned the game setting <name> back on; sparkles need it. Disable Enable Sparkles to stop this.' Never retry in the same session (a flag per name), so a setting the game holds down cannot be fought. (3) README.md line 31: add that the two settings are also put back when you log out.

**Checked:** Confirmed: Needs has two callers and no logout path, so the README and tooltip ('restored when you disable this') are true but V1.md's 'or removed' is not. The Accessibility.lua lines are as quoted. Also confirmed that this client's own gamepad interface sets temporary values (C_CVar.SetTempCVar("SoftTargetNameplateInteract", 0), Blizzard_Gamepad/Core.lua:2-23); how SetCVar behaves against a temporary value is not known from the source, which is why step 2 is limited to one try per session and out of combat. Turning the settings back on stays inside what Enable Sparkles already says it does. PLAYER_LOGOUT is a documented event here. Impact lowered to low: a player who keeps the addon and leaves the game's icon option alone never sees it.

### SP-7. /sparkle prints raw game variables and does not always say why an object does not sparkle

`addons/PatchwerkForever_Thread_Sparkle/Sparkle.lua` line 682 (PatchwerkForever_Thread_Sparkle; feedback; size S; impact low)

**Now:** ns.Print('Soft-target settings: ' .. table.concat(parts, ', ') .. '.')  -- six variables, printed as 'Interact <n>, InteractRange <n>, InteractArc <n>, NameplateInteract <n>, IconGameObject <n>, IconInteract <n>' -- then ('%s: %s; cursor: %s; type: %s%s; nameplate: %s; it %s.') ending `was.ignored and 'is on your ignore list' or was.shown and 'sparkles' or 'does not sparkle'` (lines 687-690). Help and README promise 'why it does or does not sparkle', but for a mailbox with Include All Interactable Objects off the line ends 'it does not sparkle.' with no reason; a missing nameplate is 'nameplate: NO'; the cursor is an atlas name or 'nil'.

**Change:** Do this after the stale-target finding (it gives `last.barred`). Default /sparkle prints one plain line: '<name> (<Herb|Ore|Chest|Quest Object|Other Object>): sparkling.' or '<name> (<type>): not sparkling: <reason>.', with the first reason that applies: Barred()'s text; 'it is on the ignore list'; 'Include All Interactable Objects is disabled' (kind 'other', known, sparkleAll off); 'the game gave it no nameplate', followed, when a variable in NEEDS is not '1', by ' (the game setting <name> is off; disable and enable Enable Sparkles to turn it back on)'. With nothing targeted: 'No object is targeted right now.' and, when there is a recent one, 'Last targeted <n> s ago: ' plus the same line. Only when the keyboard flag of SoftTargetInteract is not set (tonumber(GetCVar('SoftTargetInteract')) is 0 or 1), add: 'With keyboard and mouse the game only targets objects when "' .. (ENABLE_INTERACT_TEXT or 'Enable Interact Key') .. '" is on in its Controls options.' Keep the Fade Behind Character lines. Move the 'Soft-target settings' line, the cursor name and '(guessed)' to a new `/sparkle debug`, listed last in Help() and in the README's command table.

**Checked:** Confirmed: the reason is missing for the Include All case and the default output is a debugging line, against the plain-sentence rule for chat. The game's own setting is as the reader says (forever-src Blizzard_SettingsDefinitions_Frame/Controls.lua:72-85, label ENABLE_INTERACT_TEXT). Corrected the keyboard hint: the values are 0 None, 1 Gamepad, 2 Kbm, 3 Any (SoftTargetConstantsDocumentation.lua:13-16), so the reader's `~= 3` would also fire for 2, where the keyboard does target. Impact lowered to low: a command typed now and then, rarely by a gamepad player.

### SP-8. Percent sliders show a bare number

`addons/PatchwerkForever_Thread_Sparkle/Core.lua` line 80 (PatchwerkForever_Thread_Sparkle; consistency; size S; impact low)

**Now:** add({ key = 'look.' .. k .. '.bright', default = 100, min = 20, max = 100, step = 5, name = 'Brightness',
		desc = 'Brightness of the sparkle, in percent.' })  -- the base labels every slider with `options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)` (addons/PatchwerkForever/Tools.lua:249), so Brightness reads '100' beside Size '110' and Vertical Offset '-40', which are not percentages. The same goes for Animation Speed (line 84) and, on Behind My Character, Minimum Opacity, Character Height, Character Width, Horizontal Offset and Vertical Offset (lines 96-105): fifteen sliders whose unit is only in the tooltip.

**Change:** Let a setting say `percent = true` (add it to the list of entry fields in the comment at Tools.lua:32-46). At Tools.lua:249 pass a formatter when it is set: `options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, def.percent and function(value) return ('%d%%'):format(math.floor(value + 0.5)) end or nil)`. Add `percent = true` to the look.*.bright and look.*.speed definitions and the five Behind My Character sliders. Drop ', in percent' only where nothing follows it (Brightness, Animation Speed, Minimum Opacity, Character Height); keep 'in percent of its height / of screen width / of screen height', which say what the percentage is of. The same flag fits the tracker's Faded Opacity, Scale and Background Opacity (PatchwerkForever_Thread_Tracker/Core.lua:42, 119, 123) and Routes' Animation Speed (PatchwerkForever_Thread_Routes/Core.lua:63).

**Checked:** Confirmed: this client's SetLabelFormatter takes a function as its second argument and uses the plain value when it is nil (forever-src Blizzard_Settings_Shared/Blizzard_Settings.lua:302-307, Blizzard_SharedXML/Shared/Slider/MinimalSlider.lua:18-30), and the game itself passes FormatPercentage this way (Blizzard_SettingsDefinitions_Frame/Combat.lua:165). An older base ignores the flag and shows the number as today. Corrected the proposal so tooltips keep 'in percent of ...' where it carries meaning, and added rounding.

### SP-9. The fade area preview is gone in ten seconds while the character is still behind the options panel

`addons/PatchwerkForever_Thread_Sparkle/Sparkle.lua` line 590 (PatchwerkForever_Thread_Sparkle; feedback; size S; impact low; needs a look in the game)

**Now:** C_Timer.After(TEST_SECONDS + 4, function()
		if mine == wheres then where:Hide() end
	end)  -- the oval is centered on the screen (`local cx = w / 2 + w * (ns.Get('sparkleBehindAcross') or 0) / 100`, line 304), where the 920 x 724 options panel sits, so the character it 'should surround' (Core.lua:107) is hidden by the panel while the sliders are in reach, and the oval is gone ten seconds after the button is pressed. Its caption is 'Your character is taken to be here' (line 568); when the camera distance is not available and 15 yards is assumed, only /sparkle says so (line 695).

**Change:** The oval already follows the sliders while it is shown (PlaceWhere runs every frame), so only its lifetime needs work. Drop the C_Timer. ns.SparkleBehindShow sets `where.hideAt = GetTime() + 10`. In the OnSetting handler, when one of the five sparkleBehind sliders changes and `where` is shown, set hideAt again (extend only; do not show it, so Reset To Defaults does not pop it up). In the `where` OnUpdate: `local open = SettingsPanel and SettingsPanel:IsShown(); if self.open and not open then self.hideAt = GetTime() + 10 end; self.open = open; if GetTime() >= self.hideAt then self:Hide() end`, so closing the options gives a fresh ten seconds to compare with the character. Captions: 'Fade Area'; when `select(2, Zoom())` is false, 'Fade Area (camera distance not available: 15 yards assumed)'; too close: 'Camera too close: no fading'. Tooltip (Core.lua:107): 'Show the fade area as an oval. It stays for ten seconds after your last change and for ten seconds after you close the options, so you can compare it with your character.'

**Checked:** Confirmed the timer and the centering. Corrected the reader's title: the oval is strata DIALOG and is drawn over the panel; it is the character that the panel hides (the panel is CENTER-anchored and has no drag script on this client). Cut two parts: showing the oval on every slider change (not needed, it already follows live, and Reset To Defaults would pop it up) and keeping it for as long as the options are open (it would hang over every other options page). GetCameraZoom is not in this client's source, as the code's own comment says, so the '15 yards assumed' caption may be the usual case here. Size lowered to S, about fifteen lines.

### SP-10. 'Above the icon' puts the name at the nameplate's middle, not above the icon

`addons/PatchwerkForever_Thread_Sparkle/Sparkle.lua` line 425 (PatchwerkForever_Thread_Sparkle; layout; size S; impact low; needs a look in the game)

**Now:** if ns.Get('namePlace') == 'above' then
		fs:SetPoint('BOTTOM', anchor, 'CENTER', 0, far)
	else
		fs:SetPoint('TOP', anchor, 'CENTER', 0, -far)
	end  -- with the choices { 'below', 'Below the icon' }, { 'above', 'Above the icon' } and Offset 'Distance between the name and the icon.' (Core.lua:61-65). The anchor is the nameplate's center. The game's icon is a 24 x 24 frame whose bottom edge is 8 below the nameplate's top edge (forever-src Blizzard_NamePlates/Blizzard_NamePlates.xml:261-265), so with the default Offset 14, 'Above the icon' starts the name 14 above the plate's middle, under or across the icon.

**Change:** In Write(), for 'above': `local frame = anchor.UnitFrame; local soft = frame and frame.SoftTargetFrame; local art = soft and soft.Icon`; when `art and art:IsVisible()`, anchor with `fs:SetPoint('BOTTOM', soft, 'TOP', 0, far)`; otherwise keep today's anchor (the preview, and nameplates without that frame or with it hidden). Leave 'below' as it is. Offset tooltip (Core.lua:65): 'Distance of the name from the nameplate (below) or from the icon (above).' Look at both positions once in the game with EllesmereUI on, since it may hide or move the game's nameplate frame; if the icon is never visible there, only the tooltip wording changes.

**Checked:** Confirmed the code and the game's layout: UnitFrame is SetAllPoints on the nameplate (Blizzard_NamePlateBase.lua:20) and SoftTargetFrame is anchored BOTTOM to its TOP at y -8; nothing else in the game's nameplate code moves or resizes it. Corrected the proposal: the frame itself is always shown, it is its Icon texture that is shown and hidden (Blizzard_NamePlates.lua:188-210), so the check must be on .Icon. Only reads the game's frame; nothing of it is changed. Whether the overlap is visible depends on the nameplate height in use, so it needs the game.

### SP-11. A few in-game lines are not in plain American wording, and the README leaves two options out

`addons/PatchwerkForever_Thread_Sparkle/Sparkle.lua` line 32 (PatchwerkForever_Thread_Sparkle; wording; size S; impact low)

**Now:** local KIND_NAMES = { herb = 'a herb', ore = 'ore', loot = 'a chest', quest = 'a quest object', other = 'another thing' }  -- the preview's name reads 'This is a herb' or 'This is another thing' (line 543). 'Nothing has been targeted since you logged in or reloaded. Walk up to a herb, an ore node or a chest, then try again.' (line 714). ('Ignore list cleared (%d object(s)).') (line 650), printed with 0 as well. Clear Ignore List tooltip: 'To ignore one, point at it and type /sparkle ignore, or use the key binding.' (Core.lua:41), though nothing is pointed: the game targets the object as you walk up. Help() (Core.lua:113-119) lists neither '/sparkle help' nor '/pfs'. README.md 'What you can change' (lines 25-29) names neither Include All Interactable Objects nor Apply Subtle Preset.

**Change:** Preview names as a real object would read, without 'This is ': herb 'Peacebloom', ore 'Copper Vein', loot 'Battered Chest', quest 'Quest Object', other 'Mailbox' (also a fairer test of Font Size). Line 714: 'Walk up to an herb, an ore node or a chest, then try again.' Line 650: when the list is empty print 'The ignore list is already empty.'; otherwise '%d object removed from the ignore list.' for one and '%d objects removed from the ignore list.' for more. Core.lua:41: 'Ignored objects never sparkle. To ignore one, walk up to it and use the key binding or type /sparkle ignore. This button clears the whole list.' Help(): first line 'Sparkle commands (/sparkle or /pfs):'. README 'What you can change': add a line for mailboxes, doors and anvils (Include All Interactable Objects, off by default) and one for the subtle preset.

**Checked:** Every quote checked against the files and found exact. KIND_NAMES is used only for the preview's name (line 543). The README's own prose ('a herb', 'thing') is left alone here: that is ROADMAP A1. The two missing README options are a doc that does not match the code, not wording.

### SP: dropped

- **No command or binding turns sparkles on and off:** A new feature, not polish: it adds a new command (/sparkle on, off, toggle) and a new binding where nothing existing is rough. The facts are right (the slash handler and Bindings.xml have neither, and /tracker on, off exists), but the tracker has no enable binding either, Enable Sparkles is a setting and settings belong on the options page, and Hide In Combat and Hide In Instances already cover the cases where a quick switch would be wanted. Each toggle would also flip two of the game's own settings.

## BO: The base and the options pages

### BO-1. Front page rows cut off every line from Patchwerk

`addons/PatchwerkForever/Front.lua` line 75 (PatchwerkForever; layout; size S; impact medium; needs a look in the game)

**Now:** row.Says = ns.Writing(row, 11, true);
row.Says:SetPoint('TOPLEFT', row, 'TOPLEFT', 46, -24)
row.Says:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -70, -24)
row.Says:SetWordWrap(false)

(line 22: local ROW = 48; line 140: local half = math.floor(( width - 12 ) / 2); rows are two to a line.) At the default options window the page is 665 wide, so a row is 326 and the line gets 210 px at 11 pt. The seven X-Patchwerk-Voice lines are 43 to 71 characters and the missing-part sentence is about 55 to 70, so nearly every row ends in an ellipsis and nothing shows the rest.

**Change:** In Row(): anchor row.Open at ('TOPRIGHT', row, 'TOPRIGHT', -6, -4) instead of ('RIGHT', row, 'RIGHT', -6, 0), so it sits beside the name. Anchor row.Says at y -29 on both points and change its right inset from -70 to -6 (the full row, about 274 px). Call row.Says:SetWordWrap(true) and, guarded as in Look.lua:110, if row.Says.SetMaxLines then row.Says:SetMaxLines(2) end. Leave row.Name's right inset at -70 so it clears the button. Raise ROW (line 22) from 48 to 60. With all seven parts the page then ends at about 540 of the canvas's 601 px (banner 221 + 40 + 4 x 60 + 10 + 28), so nothing overflows. Look at it in game at the player's window size.

**Checked:** Quote matches lines 75-78. Canvas width confirmed from Blizzard_SettingsPanel.xml (920 wide, list 199 at x 18, 16 gap, right inset 22 = 665; height 724 - 76 - 47 = 601) and DisplayLayout sets the canvas frame to all points of SettingsCanvas. Only seven addons join as parts (seven Link.lua files; the map data folders do not), so the height sum holds. SetMaxLines and SetWordWrap exist on this client. Truncation itself is only certain in game.

### BO-2. Patchwerk's line on the banner runs over the candles

`addons/PatchwerkForever/Front.lua` line 121 (PatchwerkForever; visuals; size S; impact medium; needs a look in the game)

**Now:** frame.Voice:SetWidth(math.max(120, width * 0.36))

(line 213: frame.Voice:SetPoint('TOPLEFT', frame.Version, 'BOTTOMLEFT', 0, -12); line 215: frame.Voice:SetWidth(230).) The line starts about 23 px from the left and about 115 px down, so on a 665 px page it may reach 262 px, 39% of the banner's width. In the banner the two candles stand from 30% to 40% across and from 43% to about 80% down, so cream text (ns.CREAM) ends over the flames and wax with only a 1 px shadow behind it.

**Change:** Change the factor on line 121 from 0.36 to 0.26 (about 173 px on a 665 px page, ending at about 29.5%, left of the candles) and the starting width on line 215 from 230 to 170. The longest saying then wraps to four or five lines and ends at about 185 of the banner's 221 px. Confirm in game; if a line still touches the art, lower the factor rather than moving the text.

**Checked:** Quote matches. Viewed art/PatchwerkForever/listing/banner.png: candles at x 30-40%, y 43-80%; plain dark wall to about 30% at candle height and to about 24% at table height. The shipped Media/banner.tga is that picture at 1024x512 (tools/art.py:43), stretched back to 3:1 by SetHeight(width / BANNER), so the proportions hold. Whether a given saying actually reaches the candles depends on where it wraps: needs a look in game.

### BO-3. Reset To Defaults row says 'Defaults' on heading and button

`addons/PatchwerkForever/Tools.lua` line 314 (PatchwerkForever; wording; size S; impact low)

**Now:** ns.PlaceHeader(tool.first, 'Defaults')
Place(tool.first, CreateSettingsButtonInitializer('Reset To Defaults', 'Defaults', function() AskReset(tool) end,
	'Reset every option of this addon, on all of its pages, to its default. Positions and saved data are not changed.', true))

and the confirm box (line 288): text = 'Reset all %s options to their defaults?',

So each tool's first page ends: heading 'Defaults', label 'Reset To Defaults', button 'Defaults'. The game's own button at the top right of the same page is also labelled with SETTINGS_DEFAULTS and does something else (its dialog offers every setting in the game, or this page).

**Change:** Change the button text (second argument on line 314) from 'Defaults' to 'Reset', as the game pairs label and button (Blizzard_SettingsDefinitions_Frame/Social.lua:281: CreateSettingsButtonInitializer(RESET_CHAT_POSITION, RESET, ...)) and as the tracker's own 'Reset Position' / 'Reset' row does. Keep the heading 'Defaults', the label 'Reset To Defaults' and the tooltip. Change the dialog text on line 288 to 'Reset all %s options, on all of its pages, to their defaults?\n\nPositions and saved data are not changed.' Update the checks: tools/lua_shell.py:763 (the sorted list becomes Apply, Clear, Reset, Reset, Show, Show, Test x5) and :773, :778 (b.text == "Reset"); tools/lua_tracker.py:234 (becomes ["Reset", "Reset", "Unlock"]) and :409, :413, which must now find the button by b.name == "Reset To Defaults" because the tracker's Reset Position button has the same text.

**Checked:** Quotes match lines 313-315 and 288. The game's header button and its GAME_SETTINGS_APPLY_DEFAULTS dialog confirmed (Blizzard_SettingsPanel.lua:78-80, Blizzard_Dialogs.lua:2-17: All Settings / These Settings). Dropped the proposed tooltip sentence 'The Defaults button at the top of a page resets only that page': that button also offers All Settings, so the sentence would be wrong. The stub's buttons carry a name (tools/wowstub.lua:339), so the tracker check can select by name. Impact lowered from medium: a wording nit at the foot of three pages.

### BO-4. No binding opens Patchwerk Forever's options

`addons/PatchwerkForever/Core.lua` line 397 (PatchwerkForever; gamepad; size S; impact low)

**Now:** SLASH_PATCHWERK1 = '/patchwerk';
SlashCmdList.PATCHWERK = function(msg)
	local word, args = (msg or ''):trim():match('^(%S*)%s*(.-)$');
	word = word:lower();
	if ( word == 'config' or word == 'settings' or word == 'options' ) then
		if not P:OpenSettings() then

The base's folder has no Bindings.xml (Routes, Tracker, Sparkle and the Dungeon Journal Stitch each have one). On a gamepad the front page is reached by typing the command or by walking Game Menu > Options > AddOns > Patchwerk Forever.

**Change:** Add addons/PatchwerkForever/Bindings.xml in the form the parts use (not listed in the TOC, as theirs are not):
<Bindings>
	<Binding name="PATCHWERKFOREVER_OPTIONS" header="PATCHWERKFOREVER" category="ADDONS">
		PatchwerkForever_OpenOptions()
	</Binding>
</Bindings>
In Core.lua add BINDING_HEADER_PATCHWERKFOREVER = 'Patchwerk Forever', BINDING_NAME_PATCHWERKFOREVER_OPTIONS = 'Open Options', and a global function PatchwerkForever_OpenOptions() holding what the 'config' branch does today (P:OpenSettings(), and the same chat line when it returns false); have the slash branch call it. The front page's Open buttons then reach every part's page from the one binding. Add "Bindings.xml" to the base's "needs" tuple in tools/release.py:60, a line to the README's Commands section, and a check in tools/lua_patchwerk.py that calling the function opens the page.

**Checked:** Confirmed: no Bindings.xml in addons/PatchwerkForever; the four existing ones use exactly this form with category="ADDONS". Not in ROADMAP.md or V1.md. Title corrected: the page is also reachable with a gamepad through the game's options, as Front.lua's own header says, so it is not slash-only. Impact lowered from medium for that reason; it stays because the family's rule is that every action is bindable. In combat the binding does what the command does (prints a line; see the combat finding).

### BO-5. Front page tick box is silent and its tooltip is unlike the other pages'

`addons/PatchwerkForever/Front.lua` line 96 (PatchwerkForever; consistency; size S; impact low)

**Now:** check:SetScript('OnClick', function(self)
	P:SetSetting(self.key, self:GetChecked() and true or false)
end)
check:SetScript('OnEnter', function(self)
	local tip = rawget(_G, 'GameTooltip');
	if not ( self.desc and type(tip) == 'table' and tip.SetOwner ) then return end;
	tip:SetOwner(self, 'ANCHOR_RIGHT')
	tip:SetText(self.desc, 1, 1, 1, 1, true)
	tip:Show()
end)

The click makes no sound and the tooltip is the description alone, in white. On every other page the game plays a sound on a tick and shows the option's name in white above its description in the normal color. Only the 26 px box reacts to the mouse; its label (a font string on the page, line 94) does not.

**Change:** OnClick: after SetSetting, play the game's sound, guarded because the checks' stand-in game has neither global and tools/lua_patchwerk.py:215 runs this script: local play, kit = rawget(_G, 'PlaySound'), rawget(_G, 'SOUNDKIT'); if ( play and kit ) then play(self:GetChecked() and kit.IG_MAINMENU_OPTION_CHECKBOX_ON or kit.IG_MAINMENU_OPTION_CHECKBOX_OFF) end. In Refresh, beside line 172, also store check.name = ns.Sentence(def.name or def.key). In OnEnter, when GameTooltip_SetTitle and GameTooltip_AddNormalLine exist, replace the SetText line with GameTooltip_SetTitle(tip, self.name) and GameTooltip_AddNormalLine(tip, self.desc, true); otherwise keep SetText. After check.Label:SetText on line 176 add: if ( check.SetHitRectInsets and check.Label.GetStringWidth ) then check:SetHitRectInsets(0, -( check.Label:GetStringWidth() + 4 ), 0, 0) end, so the label is part of the target.

**Checked:** Quote matches lines 96-105. Confirmed on this client: UICheckButtonTemplate has no click script (CheckButtonTemplates.xml:50-64); the settings tick box plays IG_MAINMENU_OPTION_CHECKBOX_ON/OFF (Blizzard_SettingControls.lua:656-662); Settings.InitTooltip adds a highlight name line then a normal line (Blizzard_Settings.lua:289-298); GameTooltip_SetTitle, GameTooltip_AddNormalLine, SetHitRectInsets and both sound constants exist. Dropped the sound on the Open buttons: the game's own settings buttons are silent (SettingsButtonControlMixin:Init sets OnClick to the bare callback), so that part was not a consistency fix. Added the guards the checks need.

### BO-6. Addon list note and README leave out Tracker and the Dungeon Journal Stitch

`addons/PatchwerkForever/PatchwerkForever.toc` line 3 (PatchwerkForever; docs; size S; impact low)

**Now:** \## Notes: The base of the Patchwerk Forever addons: their shared settings pages, saved data and /patchwerk. It does nothing by itself; add Stitch (fixes for Console Port and MelloUI) and Thread (our own tools: Routes, Sparkle).

The same gaps are in addons/PatchwerkForever/README.md: the Thread table (lines 40-43) has rows for Routes and Sparkle only; line 55 reads 'The base tells you once, in chat, when Console Port or MelloUI is running and the Stitch for it is not installed.' although P.Family (Core.lua:40-45) also covers ForeverDungeonJournal; line 66 reads 'The Thread tools have commands of their own (`/thread`, `/sparkle`).'

**Change:** TOC line 3: '... It does nothing by itself; add Stitch (fixes and additions for Console Port, MelloUI and DungeonJournal) and Thread (our own tools: Routes, Tracker, Sparkle).' README: add a Thread table row '| **Patchwerk Forever: Tracker (Thread)** | A quest tracker: your quests by zone with distances, your guide's steps, quest item buttons, tracked recipes and a gathering list. |'; line 55 to 'when Console Port, MelloUI or DungeonJournal is running'; line 66 to '(`/thread`, `/tracker`, `/sparkle`)'. release/PatchwerkForever/CurseForge-description.md is a copy of the README made by tools/release.py (line 314) and carries the same lines (43, 55, 66): make it again with the release tool before the first upload.

**Checked:** All four quotes confirmed at the lines given. /tracker exists (PatchwerkForever_Thread_Tracker/Core.lua:154). 'DungeonJournal' is how the family's own docs name that addon (the Stitch's TOC notes and README, base README line 31). Not the same as ROADMAP A1, which is about the READMEs' wording, not missing parts. The TOC note shows in the game's addon list tooltip; nothing is uploaded yet, so the listing copy can be fixed before anyone sees it.

### BO-7. In combat, opening the options fails with a vague line, or silently

`addons/PatchwerkForever/Core.lua` line 403 (PatchwerkForever; feedback; size S; impact low)

**Now:** P:Print('The settings page could not be opened here. /patchwerk set lists the settings.')

Printed whenever ns.OpenSettings returns false, which once the page exists means combat (Settings.lua:135: if not ( category and Settings and Settings.OpenToCategory ) or InCombatLockdown() then). The front page's Open button has the same guard and says nothing (Front.lua:59: if not ( category and Settings and Settings.OpenToCategory ) or InCombatLockdown() then return end;). The tools word the same case differently: 'Options are under Options > AddOns > Patchwerk Forever > Tracker (Thread).' (PatchwerkForever_Thread_Tracker/Core.lua:177).

**Change:** Core.lua:403: print, when InCombatLockdown(), 'The options cannot be opened from a command in combat. They are under Options > AddOns > Patchwerk Forever.'; otherwise the tools' form, 'Options are under Options > AddOns > Patchwerk Forever.' In Front.lua's Open() split the guard: if InCombatLockdown() then P:Print('This button does not work in combat. Select the page in the list on the left.') return end, then the existing category test. Keep both combat guards. Avoid the words 'could not' and 'failed' in the new lines: the checks treat those as errors (tools/lua_patchwerk.py:166).

**Checked:** All three quotes confirmed (Core.lua:403, Settings.lua:135, Front.lua:59) and the tools' line at Tracker Core.lua:177, Routes Core.lua:134, Sparkle Core.lua:139. No check asserts the old text. The three tools print their generic line in combat too; giving them the same combat sentence would complete the consistency but is optional.

### BO-8. Base chat lines have no separator after 'Patchwerk'

`addons/PatchwerkForever/Core.lua` line 72 (PatchwerkForever; consistency; size S; impact low)

**Now:** function P:Print(...)
	print(GOLD .. 'Patchwerk|r', ...)
end

So the missing-addon notice (line 316) reads 'Patchwerk Console Port is running. The fixes and additions for it are a separate addon: ...', as if an addon called Patchwerk Console Port were running, and line 403 reads 'Patchwerk The settings page could not be opened here.' The tools print 'Tracker: ...' (Tools.lua:68: local prefix = ('|c%s%s|r: '):format(spec.colour or 'ffd6a35b', spec.name or name);).

**Change:** Line 73: print(GOLD .. 'Patchwerk|r:', ...). Reword the base lines written to lean on the bare name: Core.lua:362 'settings (/patchwerk set <name> on|off):' to 'Options (/patchwerk set <name> on|off):'; Front.lua:237 'Its front page could not be drawn (' to 'The front page could not be drawn ('. Update the one check that matches the prefix exactly: tools/lua_patchwerk.py:290 to "Patchwerk: made-up command: hello there". The seven parts' Link.lua files print the prefix by hand ('|cffd6a35bPatchwerk|r %s needs a newer Patchwerk Forever (the base addon). It is not running.' with the folder name): give those the colon too and, while there, name the part by its title, e.g. (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, 'Title')) or addonName. The Stitches pass a colored name of their own after the prefix ('Console Port', 'Route', 'MelloUI') and will read 'Patchwerk: Console Port ...'; two of their lines start lower case for the old reason and want a capital: PatchwerkForever_Stitch_MelloUIRoute/Controls.lua:34 'the trail ahead of you:' and :116 'settings (/patchwerk config, or /patchwerk route set <name> on|off):'.

**Checked:** Quotes confirmed (Core.lua:72-74, 316, 362, 403; Front.lua:237; Tools.lua:68; MelloUIRoute Controls.lua:34 and 116). P.Print is shared with every Stitch, so the colon changes their lines as well: that is intended here but should be looked at once in chat. Only one check matches the prefix exactly (lua_patchwerk.py:290); the too-old-base check at :352 matches a phrase that stays. Took in the one sound part of the dropped 'newer base' finding: the folder name in the parts' own line. This player has both Stitches for what they run, so they see these lines rarely.

### BO-9. /patchwerk's help omits 'set' and answers a wrong value tersely

`addons/PatchwerkForever/Core.lua` line 423 (PatchwerkForever; discoverability; size S; impact low)

**Now:** print('  /patchwerk config opens the settings. /patchwerk <id> for a fix\'s own commands.')

and, for a wrong value (line 375):
return P:Print(type(def.default) == 'number' and 'Give a number.' or 'Give on or off.');

'/patchwerk set' is in the README's command table but not in this help; the help says 'settings' where the tools say 'options'; the tools list commands one to a line ('Quest tracker commands:' then '  /tracker config: open the options') and answer a wrong value with a usage line ('Usage: /thread to 45.2 61.8').

**Change:** Replace line 423 with the tools' layout:
P:Print('Commands:')
print('  /patchwerk config: open the options')
print('  /patchwerk set <name> on|off: change a Stitch option;  /patchwerk set: list them')
and, only when #P.Fixes > 0, print('  /patchwerk <id>: a fix\'s own commands (the id in parentheses above)'). Change line 375 to return P:Print(('Usage: /patchwerk set %s %s'):format(def.key, type(def.default) == 'number' and '<number>' or 'on|off')).

**Checked:** Both quotes confirmed; the tools' forms confirmed at Tracker Core.lua:144-150 and Routes Core.lua:130. No check asserts either old line. Wording corrected to American 'parentheses' (the fix list prints the id in round brackets), and the usage line now names the option that was typed.

### BO-10. A disabled part is described in non-standard words

`addons/PatchwerkForever/Front.lua` line 132 (PatchwerkForever; wording; size S; impact low)

**Now:** says = ( ns.IsInstalled(part.addon) and 'Installed, not switched on.' or 'Not sewn on.' )
	.. ' It is for ' .. part.what .. ', which is running.' };

and in the /patchwerk listing (Core.lua:391-392):
print(('  |cff808080%s (for %s): %s|r'):format(part.name, part.what,
	IsInstalled(part.addon) and 'installed, not switched on' or 'not installed'))

The family's standard word is Enable / disabled, and neither line says where to change it.

**Change:** Core.lua:392 (a chat line, so standard words apply): 'installed but disabled' in place of 'installed, not switched on'. Front.lua:132: 'Disabled in the addon list.' in place of 'Installed, not switched on.' and 'Not installed.' in place of 'Not sewn on.'; keep the tail ' It is for <addon>, which is running.' Update the checks: tools/lua_patchwerk.py:210 (to "Not installed. It is for Console Port, which is running.") and :241 (to "installed but disabled").

**Checked:** Both quotes confirmed, and the two check lines. The front page is one of the places Patchwerk's voice is allowed, so 'Not sewn on.' is not a rule break and may stay if preferred; the firm part is the chat listing and saying where a disabled part is enabled. Shown only when an addon the part is for is running and the part is not: this player would see it only with a Stitch disabled. The longer text fits only once the rows wrap (first finding).

### BO-11. A gathering run that cannot start still drops the selected quest

`addons/PatchwerkForever/Gather.lua` line 50 (PatchwerkForever; edge-case; size S; impact low)

**Now:** function Gather:Start(mode, name)
	if ( provider and P.Choice ) then P.Choice:Clear() end;      -- (one side path at a time: Choice.lua)
	return Ask('Start', mode, name);
end

Routes' Start returns false when there is nothing to go to (PatchwerkForever_Thread_Routes/Gather.lua:86-90 prints 'No unvisited herb or ore node recorded nearby. Gathering stopped.' and sets state = nil; line 116: return state ~= nil). The quest selected in the tracker is already cleared by then, so the route falls back to the guide with no run in its place.

**Change:** Put the choice back when the run did not start:
function Gather:Start(mode, name)
	local had = provider and P.Choice and P.Choice:Get();
	if had then P.Choice:Clear() end;
	local started = Ask('Start', mode, name);
	if ( had and not started ) then P.Choice:Set(had.kind, had.id) end;
	return started;
end
Add a case to gathering() in tools/lua_tracker.py: select a quest, click a gathering row whose provider Start returns false, the quest is still selected.

**Checked:** Quote matches lines 50-53; Routes' Go and Start confirmed. It can happen in play: the tracker lists the nearest node of each type without leaving out ones visited in the last 300 seconds, and 'Farm Nearby Nodes' looks within 1200 yards while the list reaches 3000. Traced the fix: Choice:Set only stops a run when Gather:State() is non-nil, which it is not after a failed start; Routes compares the choice once per pass, so a clear and restore in one call is not seen; the tracker's own Start (Tracker/Gather.lua:20-22) then keeps its arrow because the choice is still there. The existing check that a successful start clears the choice (lua_tracker.py:989) still holds.

### BO: dropped

- **A part that needs a newer base is shown nowhere:** The title's claim is not true: every part prints its own line at each load when the base refuses it (all seven Link.lua files, e.g. PatchwerkForever_Thread_Tracker/Link.lua:20). The proposed list in the base cannot help the case described, because the base that refuses is the old one and would not have the new code; and the proposal's last step, dropping the parts' own line, would remove the only sign on any base older than the change. What is left is a new list, a new row state and a new listing line for a mismatch that cannot happen with this player's build (all addons are written together) and that nothing uploaded can yet cause. Its one sound polish point, that the line names the folder instead of the addon's title, is folded into the chat prefix finding.
- **Sound on the front page's Open buttons (part of the front page controls finding):** Cut from the kept finding: the game's own settings buttons make no sound on click on this client (SettingsButtonControlMixin:Init sets OnClick to the bare callback, Blizzard_SettingControls.lua:979), so adding one would not make the page more consistent with the others.
- **Tooltip sentence about the game's Defaults button (part of the Reset To Defaults finding):** Cut from the kept finding: 'The Defaults button at the top of a page resets only that page' is not accurate. That button opens GAME_SETTINGS_APPLY_DEFAULTS, which offers All Settings (every setting in the game) as well as These Settings (Blizzard_Dialogs.lua:2-17).

## ST: The Stitches

### ST-1. With no RestedXP guide running, the Dungeon Journal list becomes the main route by itself

`addons/PatchwerkForever_Stitch_DungeonJournal/Reader.lua` line 260 (PatchwerkForever_Stitch_DungeonJournal; edge-case; size M; impact medium)

**Now:** `Leads = function() return ns:GetSetting('djLeads') and true or false end,` is all the reader says about its place (Guides:Register, lines 256-261). The djLeads tooltip (line 54) ends: "When disabled, your guide stays the main route and the list is followed only while you select it." and the djList tooltip (line 46) says Routes "leads you along it once you select it". But the base's Guides:Read (addons/PatchwerkForever/Guides.lua:99-102) is `for _, id in ipairs(Order()) do local info = Ask(id, count); if info then return info end; end`: the first reader with something to say. With RestedXP absent or with no guide loaded (its reader returns nil, Guides/RestedXP.lua:114-118), that is the journal list: Routes' GuideTarget (Thread_Routes/Sources.lua:80) follows it unasked, ahead of tracked quests ('rxp' and sourceFirst = 'rxp' are the defaults, Thread_Routes/Core.lua:17 and :28); the tracker treats it as the main guide (`local main = n == 1`, Thread_Tracker/Guide.lua:91), so a left-click skips the stop for the session instead of selecting the list; and the binding prints 'Dungeon Journal: back to your main route.' (Reader.lua:273) while the route stays on the list.

**Change:** Make it a side list unless the setting says otherwise. (1) addons/PatchwerkForever/Guides.lua: a reader may carry `Side` (a function, asked with pcall as Leads is). In Ask(), after line 80, set info.side = true when it returns true. In Guides:Read with no source (lines 99-102) return the first info that is not side; leave ReadAll (106-113) as it is, so the tracker still lists it. Add Side to the header comment (lines 20-23). (2) Reader.lua:260: add `Side = function() return not ns:GetSetting('djLeads') end,`. (3) Thread_Tracker/Guide.lua:91: `local main = n == 1 and not info.side`. (4) Thread_Tracker/Actions.lua:215: `if ns.Base.Guides:Read(0) or ns.Base.Choice:Get() then return end`, so Follow The Nearest Quest does not move the quest arrow while the list is the chosen route. Read(count, id), Choice's Stands (Choice.lua:32) and Routes' chosen-guide path (Sources.lua:252-253) go by source and need no change; Routes' LookBack (Sources.lua:308) then rightly finds no main guide. An older base or tracker ignores the new field and behaves as today. If the base is not to change, the minimum is wording: add "With no guide running, the list is your main route." to the djLeads tooltip and the README, and have PatchwerkForever_Stitch_DungeonJournal_Route() print "Dungeon Journal is already your main route (no guide is running)." when Guides:Read(0) itself has source 'fdj'.

**Checked:** Confirmed by trace through Guides.lua, Guides/RestedXP.lua, Thread_Routes/Sources.lua:79-87 and 278-281, Thread_Tracker/Guide.lua:91-121 and Reader.lua:269-283. The three READMEs (Stitch line 26-27, Tracker line 25, Routes line 43) and tools/PLAN-tracker.md:460-463 all describe a side list followed only while selected. Not in ROADMAP.md or V1.md. Impact lowered from high: the player this is built for runs RestedXP, so it shows only while RestedXP has no guide loaded; for anyone without RestedXP it is the standing state. Added step (4), which the reader missed: after the change Guides:Read(0) is nil beside a chosen list.

### ST-2. Skipped stops: /tracker back fails, a click on the next stop can bring a third one forward, and skipping everything empties the list until a reload

`addons/PatchwerkForever_Stitch_DungeonJournal/Reader.lua` line 246 (PatchwerkForever_Stitch_DungeonJournal; edge-case; size S; impact medium)

**Now:** `elseif ( offset < 0 ) then` / `local quest = table.remove(skipOrder);` takes the last skip back; an offset of 0 falls through to `return false` (line 253). /tracker back calls Guides:Go(info, before.index) with the step number from before the skip (Thread_Tracker/Guide.lua:45-47), and this reader's step number does not move on a skip (`local index = math.min(math.max(total, 1), done + 1);`, line 208), so the offset is 0 and the player reads "Dungeon Journal could not go back." although the tracker's tooltip says "/tracker back undoes the last skip." (Thread_Tracker/Core.lua:89). Skips are final for the session (`skipped[quest] = true;`, line 237): skip every stop and Read returns nil, the section vanishes, /tracker back says "No skipped step to undo." and the binding says "Track a dungeon in the journal first, or every quest is done." A click on the first upcoming stop arrives as offset 1 (Guide.lua:146-151), so it removes the stop you were on, and the order is then rebuilt from where you stand (InOrder), so a different stop than the one clicked can lead.

**Change:** All in Go (Reader.lua:232-254) and the binding function; do it together with the map-point finding, which touches the same branch. (1) Line 246: `elseif ( offset <= 0 ) then`; in that branch, when skipOrder is empty and `pinned` is set, clear `pinned` and return true, so /tracker back also takes back a jump. (2) In the offset == 1 branch, after line 239, add `pinned = last.order[2] or nil`, so the stop shown as next (the one clicked) is the one that leads; and in InOrder, when `pinned` is set but no stop in the list carries it, set `pinned = nil` so a pin does not outlive its stop. (3) In PatchwerkForever_Stitch_DungeonJournal_Route(), when Guides:Read(0, SOURCE) is nil and next(skipped) ~= nil: wipe(skipped); wipe(skipOrder); pinned = nil; read again; if there is now a list print "Skipped stops are back on the list." and carry on to Choice:Set. (4) The first time a stop is skipped in a session print "Stop skipped until you reload. Previous Step in the tracker menu, or /tracker back, brings it back." (5) README line 31: add that Previous Step or /tracker back takes the last skip back.

**Checked:** Quote and line confirmed. Traced Thread_Tracker/Guide.lua Go and GuideBack against Reader.lua Go: offset is 0 on /tracker back; Previous Step in the menu (offset -1) does work. Confirmed that with every stop skipped Read returns nil, so GuideBack never reaches Go. Added the pin in step (2): the reader's one-time chat line alone left the wrong stop leading after a click on the first upcoming stop. wipe is already used in this family (Stitch_ConsolePort/Bindings.lua:67). Not in ROADMAP.md or V1.md.

### ST-3. One chat line and one status for six different reasons the list is empty

`addons/PatchwerkForever_Stitch_DungeonJournal/Reader.lua` line 276 (PatchwerkForever_Stitch_DungeonJournal; feedback; size S; impact medium)

**Now:** `if not Guides:Read(0, SOURCE) then` / `ns:Print(Journal() and 'Dungeon Journal: nothing to route to. Track a dungeon in the journal first, or every quest is done.'` / `or 'Dungeon Journal is not running.')`. Read returns nil (lines 190-207) when Route Dungeon Journal Quests is disabled, when no dungeon is tracked, when every quest is turned in, when the remaining quests are in the quest log unfinished (StopFor, line 116: the usual state just before entering the dungeon), when every remaining stop was skipped, and when the journal's tables changed shape; all six get the first line. 'Dungeon Journal is not running.' and the status `if not Journal() then return 'waiting: Dungeon Journal is not loaded' end;` (line 290) are also what the player gets when the journal is loaded but ForeverDungeonJournal_NS.DB is not a table (Journal(), lines 68-72).

**Change:** Add a local Why(), called only by the binding and by status() (not on the twice-a-second read). In order: not Journal() and C_AddOns.IsAddOnLoaded('ForeverDungeonJournal') -> "Dungeon Journal is running, but its quest data was not found. This addon may need an update."; not Journal() -> "Dungeon Journal is not running."; setting off -> "Route Dungeon Journal Quests is disabled (Options > AddOns > Patchwerk Forever > Dungeon Journal (Stitch))."; then from Stops(journal): #names == 0 -> "No dungeon is tracked in the Dungeon Journal."; total == 0 -> "The tracked dungeons have no quests for your faction."; done == total -> "Every quest of your tracked dungeons is turned in."; otherwise "Nothing to route to right now: %d of %d turned in, %d in your quest log to finish in the dungeon, %d skipped." Stops() already returns total, done and names; have it return two more counters: in the `elseif not skipped[quest.id]` branch count a quest with no stop that is Held, and add an else branch counting the skipped. status(): 'off' with the setting off, 'waiting: Dungeon Journal is not loaded' when it is not running, 'on: %d stops' (or 'on, and being followed: %d stops') with a list, and 'on: ' followed by Why() without one.

**Checked:** Quote confirmed (lines 276-278 and 290). Each of the six nil paths traced in Read, Stops and StopFor. C_AddOns.IsAddOnLoaded exists on this client (Blizzard_AddOnList/AddonList.lua:871, AddOnsDocumentation.lua:322). The reader's extra part, a note on the settings page when the journal is absent, is cut: see dropped. Same function as the '/patchwerk dj' finding and the wording finding; do the three in one pass.

### ST-4. The journal's own map point is always added as an extra stop: it can double a listed quest, cannot be skipped, and pushes the numbering past the total

`addons/PatchwerkForever_Stitch_DungeonJournal/Reader.lua` line 196 (PatchwerkForever_Stitch_DungeonJournal; edge-case; size M; impact medium; needs a look in the game)

**Now:** `local spot = Ask(journal.WaypointArrowTarget);` / `local place = Place(spot);` / `if place then` ... `table.insert(stops, 1, { kind = 'place', map = place.map, x = place.x, y = place.y,` / `lines = { { text = ( spot.turnIn and 'Turn in: ' or 'Go to: ' ) .. words, done = false, kind = 'place' } } });` with no check against the stops already in the list. Go refuses it: `if not quest then return false end;                   -- (the journal's own map point: cleared in the journal)` (line 236), so Skip Step in the tracker prints "Dungeon Journal could not jump to that step." (Thread_Tracker/Guide.lua:33). The inserted stop also shifts every later line by one while `total = math.max(total, index)` (line 211) is unchanged: with three quests and none turned in, the upcoming lines are numbered 2, 3, 4 under "Step 1 of 3".

**Change:** In Read (lines 196-202): (1) before inserting, look through `stops` for one with stop.map == place.map and (stop.x - place.x)^2 + (stop.y - place.y)^2 <= 225 (15 yards). If there is one, move it to the front (table.remove, then table.insert(stops, 1, stop)) and insert nothing: its own words and quest are kept, it can be skipped, and accepting or turning in clears it as usual. (2) Otherwise insert as today, but let it be skipped for the session without telling the journal: build a key for the spot (map and rounded x, y) and keep it in `last.arrow`; in Go's offset == 1 branch, where line 236 returns false today, set a local `arrowSkipped = last.arrow` and return true; in Read do not insert while the spot's key equals arrowSkipped (pointing the journal's arrow elsewhere gives a new key); Previous Step clears arrowSkipped when no quest skip is left to take back. (3) When the extra stop is inserted, use math.max(total, index + #stops - 1) for info.total so no line is numbered past it.

**Checked:** Quote, the refusal in Go and the tracker's message confirmed. Numbering traced: ahead steps are `index + i - 1` (line 221) and the tracker shows 3 upcoming steps by default (Thread_Tracker/Core.lua:84). Whether the real journal keeps its arrow on a quest after it is accepted cannot be told from the repository (PLAN-tracker.md:466-468: not yet tried with the real journal), hence inGame. Size raised from S to M: three changes that interlock with the skip finding, plus the stand-in-journal checks. Not in ROADMAP.md or V1.md.

### ST-5. The first stop is re-picked by straight-line distance on every read

`addons/PatchwerkForever_Stitch_DungeonJournal/Reader.lua` line 173 (PatchwerkForever_Stitch_DungeonJournal; smoothness; size S; impact medium; needs a look in the game)

**Now:** `while ( #left > 0 ) do` / `local best, far;` / `for i, stop in ipairs(left) do` / `local d = math.huge;` / `if ( at.x and stop.map == at.map ) then` / `d = ( stop.x - at.x ) ^ 2 + ( stop.y - at.y ) ^ 2;`. The whole order is rebuilt from where the character stands each time the list is read (Routes looks twice a second, Thread_Routes/Sources.lua:30 `EVERY = 0.5`; the tracker once a second, Thread_Tracker/Guide.lua:172), and only a stop the player clicked (`pinned`, lines 170-172) is held in front. When two stops are about as near as each other, the first one flips as the path bends; its place differs by more than Routes' 5 yards (`SAME = 5`), so Routes sets a new destination, plans a new trail and floats the new step's words.

**Change:** In InOrder (lines 161-187), after the pinned stop is looked for and when none was taken: let keep = last.order[1] or last.order[2] (order[1] is false while the journal's own map point leads). If a stop in `left` carries that quest and is on the character's continent (stop.map == here, with px known), take it first unless another stop on this continent is clearly nearer: its squared distance to the character is under 0.72 times the kept stop's (0.85 squared, the factor Tracker (Thread) already uses for the same purpose: Thread_Tracker/Actions.lua:20 `NEARER = 0.85`). Later stops still sort nearest-next from it. A plain keep-while-it-stands is not enough here: the list is read all the time, also while it is not followed, so a stop picked far away an hour ago would stay first.

**Checked:** Mechanism confirmed in code: InOrder has no memory of the last first stop, and Routes' Look (Sources.lua:371-391) sets a new destination when the place moves more than 5 yards. Routes' own precedent quoted by the reader is real (Sources.lua:199). How often it flips in play is not known (the Stitch has not been run with the real journal), hence inGame. Proposal changed from an unconditional keep to the tracker's 0.85 rule, for the reason given in the proposal. Not in ROADMAP.md or V1.md.

### ST-6. Open Game Menu Directly changes a game setting at first login without saying so

`addons/PatchwerkForever_Stitch_ConsolePort/GameMenu.lua` line 27 (PatchwerkForever_Stitch_ConsolePort; feedback; size S; impact low)

**Now:** `if ( GetCVar(CVAR) ~= '0' ) then` / `SetCVar(CVAR, 0)` / `end` runs at PLAYER_LOGIN (lines 36-40) with the setting on by default (`def.default, def.section = true, SECTION;`, Database.lua:175). CVAR is 'GamePadCursorAutoEnable'. Nothing is printed, and nothing is printed when the old value is put back either (`SetCVar(CVAR, saved.autoEnable)`, line 31). Report Binding Changes covers bindings only ("Print a chat message when native bindings are cleared, restored or replaced.", Database.lua:167). The tooltip's note and the README do say what it does.

**Change:** Say it when it happens. Inside the block on lines 27-29 add env:Print('|cff69ccf0Console Port|r', "Open Game Menu Directly disabled the game's automatic gamepad cursor. Disable that option to restore it."). In the `elseif ( saved.autoEnable ~= nil )` branch (lines 30-32) add env:Print('|cff69ccf0Console Port|r', "The game's automatic gamepad cursor is restored."). The file's local Print is declared on line 52, below this function, so call env:Print directly or move that local above line 17. The first line then appears once at the first login, and again only if the game setting was turned back on in between. Whether the family's opt-in rule should go further (default off) is the owner's call: it would leave the Stitch's headline fix off on a new install, so this only makes the change visible.

**Checked:** Quote and default confirmed. Kind changed from defaults to feedback, since the proposal keeps the default. Message moved from the branch that records the old value to the SetCVar call itself, so it is said every time the value is really changed and never otherwise. Found the scoping trap with the local Print. Not in ROADMAP.md or V1.md.

### ST-7. /patchwerk dj ignores what follows it, and the binding's name hides that it also stops

`addons/PatchwerkForever_Stitch_DungeonJournal/Reader.lua` line 294 (PatchwerkForever_Stitch_DungeonJournal; discoverability; size S; impact low)

**Now:** `command = function() PatchwerkForever_Stitch_DungeonJournal_Route() end;` takes no argument, though the base passes one (`return fix.command(args)`, PatchwerkForever/Core.lua:411), so `/patchwerk dj off` or `/patchwerk dj status` typed while nothing is followed starts routing. The MelloUI Stitch's command does read `on` and `off` (Stitch_MelloUI/RouteOnly.lua:259-262). The binding is named `BINDING_NAME_PATCHWERKFOREVER_DUNGEONJOURNAL_ROUTE = 'Route Through Dungeon Journal Quests';` (line 267) though a second press stops. The start line is `ns:Print('Dungeon Journal: routing through the quests of your tracked dungeons.')` (line 282): neither how many stops nor where the first is.

**Change:** command = function(args): lower-case and trim; '' toggles as today; 'on' or 'start' only starts; 'off' or 'stop' only stops ("Dungeon Journal is not being followed." when it was not); 'status' prints the status line; anything else prints "Usage: /patchwerk dj [on | off | status]". Rename the binding's label to 'Toggle Dungeon Journal Route' (the binding id stays, so saved bindings are kept; the family's other toggle reads 'Collapse / Expand Tracker'). Start line, from the info that Guides:Read(0, SOURCE) on line 276 already returns: one stop -> "Routing to 1 stop: %s.", more -> "Routing through %d stops. First: %s." with #last.order and info.lines[1].text. Update the README table (lines 42-45) to match.

**Checked:** All three quotes confirmed; the base does pass args (Core.lua:399-411). `last.order` is filled by the Read on line 276, so the count is at hand. Small and in the same function as the empty-list finding; a typed sub-command is in line with the MelloUI Stitch's own, so not a new feature. Not in ROADMAP.md or V1.md.

### ST-8. In-game words that break the wording rule: British spelling, unstandard verbs, Patchwerk's voice in a dialog

`addons/PatchwerkForever_Stitch_DungeonJournal/Reader.lua` line 54 (PatchwerkForever_Stitch_DungeonJournal; wording; size S; impact low)

**Now:** Dungeon Journal: the tooltip reads "ahead of your levelling guide" (line 54); the label is `name    = 'Dungeon Journal Before RestedXP';` (line 53) though it applies to whichever guide leads; its chat lines carry the name as plain text (`ns:Print('Dungeon Journal: back to your main route.')`, line 273) where the other three Stitches pass a colored tag (`ns:Print('|cff9b8cffMelloUI|r', ...)`, `env:Print('|cff69ccf0Console Port|r', ...)`, `ns:Print('|cff9b8cffRoute|r', ...)`). MelloUI (addons/PatchwerkForever_Stitch_MelloUI/RouteOnly.lua): tooltip "Switches every other MelloUI module off and unticks MelloUI's other addons" (line 59); chat 'Switched off:' (214), 'Switched on:' (218), 'Unticked in the addon list from the next login:' (222), 'Trimming is off. Nothing was switched back on: use /mello and the addon list.' (278); the dialog 'Patchwerk switched MelloUI down to Route and the Quest Tracker. Reload to finish?' (191) is in Patchwerk's third-person voice; the fix is listed as 'MelloUI Route and guides only' (254) while its setting is 'Only Route And The Quest Tracker' (58).

**Change:** Reader.lua:54 "leveling". Label 'Dungeon Journal First' (Routes' Priority choices read 'RestedXP guide first' and 'Tracked quest first', Thread_Routes/Core.lua:29); keep the tooltip's "your guide". Chat lines with a tag of its own color, not the base's gold d6a35b that the 'Patchwerk' prefix already uses: ns:Print('|cff7fd4a0Dungeon Journal|r', 'Back to your main route.') and the same for lines 277-282. RouteOnly.lua: tooltip "Disables every other MelloUI module and MelloUI's other addons, ..." and "anything you enable again in MelloUI afterwards stays enabled"; note (line 60) and lines 274 and 278 with enable and disable in place of switch; chat 'Disabled:', 'Enabled:', 'Disabled in the AddOns list from the next login:'; dialog 'MelloUI was trimmed to Route and the Quest Tracker. Reload the UI to finish?'; fix name 'MelloUI: only Route and the Quest Tracker'. Match the settings tables of the two READMEs (Dungeon Journal README line 40) to the new label.

**Checked:** Every quoted string and line confirmed. This is the concrete content of ROADMAP.md item A5 ("The Stitches' settings read through for standard wording", listed as an improvement, not yet done), kept because it names the actual lines. The MelloUI half is not seen by the player this is built for, who does not run MelloUI. The reader's proposed tag color was the base's own gold (PatchwerkForever/Core.lua:35) and would have run into the prefix; changed.

### ST-9. Binding-change messages go out through Console Port's own logger, not Patchwerk's

`addons/PatchwerkForever_Stitch_ConsolePort/Database.lua` line 114 (PatchwerkForever_Stitch_ConsolePort; consistency; size S; impact low; needs a look in the game)

**Now:** `function env:Notify(...)` / `if self:GetSetting('foreverNotify') then` / `CPAPI.Log(...)` / `end` / `end`. The three lines sent this way ('Cleared native gamepad bindings that blocked Console Port: %s' and 'Restored native gamepad bindings: %s', Conflicts.lua:90 and :87; 'Replaced on the same button: %s', Bindings.lua:66) are printed by a function of Console Port's, while everything else this addon prints goes through `env:Print('|cff69ccf0Console Port|r', ...)` (GameMenu.lua:53) with the Patchwerk prefix. The README (line 42) tells the player "the chat line it prints is what to report".

**Change:** Replace the body: `function env:Notify(fmt, ...) if self:GetSetting('foreverNotify') then self:Print('|cff69ccf0Console Port|r', fmt:format(...)) end end`. All three callers already pass a format string and one string. This also removes the dependence on CPAPI.Log existing and on its taking a format.

**Checked:** Code confirmed: these three lines are the only ones that do not go through the base's Print. How Console Port's logger dresses a line could not be read (its files are outside the two folders), hence inGame; the inconsistency itself follows from the code. The reader's second part (GetBindingText for the button names) is cut: see dropped. Not in ROADMAP.md or V1.md.

### ST-10. The five MelloUI Route actions have no Bindings.xml: bindable only through Console Port's list or a /click macro

`addons/PatchwerkForever_Stitch_MelloUIRoute/Controls.lua` line 86 (PatchwerkForever_Stitch_MelloUIRoute; gamepad; size S; impact low)

**Now:** `-- Console Port's binding list, when Console Port is here. (Its` / `-- LinkEnv hands back its database; the table given is not kept.)`. The buttons PatchwerkRouteBlock, PatchwerkRouteQuestRun, PatchwerkRouteNextStop, PatchwerkRouteUnblock and PatchwerkRouteTravel are made (lines 78-84, and Travel.lua:165) and then only added to Console Port's own tables (`Bindings.Custom[action.id] = binding;` ... `tinsert(Bindings.Special, { binding = binding, name = action.name, desc = action.desc })`, lines 97-100). The folder has no Bindings.xml, and the README (line 42) says: "The actions can be bound in Console Port, when you have it, or used in macros".

**Change:** Add addons/PatchwerkForever_Stitch_MelloUIRoute/Bindings.xml with five entries of the form `<Binding name="CLICK PatchwerkRouteQuestRun:LeftButton" category="ADDONS"/>`, the first with header="PATCHWERKFOREVER_MELLOUIROUTE" (Thread_Tracker/Bindings.xml line 11 is the precedent for a CLICK binding, named in Thread_Tracker/Core.lua:188). In Controls.lua set BINDING_HEADER_PATCHWERKFOREVER_MELLOUIROUTE = 'Patchwerk Forever: MelloUI Route (Stitch)' and, in the loop over `actions`, `_G['BINDING_NAME_CLICK ' .. action.button .. ':LeftButton'] = action.name` for each. Leave the Console Port registration as it is. Add "Bindings.xml" to the melloroute `needs` tuple in tools/release.py (line 91), and reword README line 42 to name Key Bindings, under AddOns, first.

**Checked:** Confirmed: no Bindings.xml in the folder; release.py line 91 is the melloroute tuple and lacks it while the Dungeon Journal, Routes, Tracker and Sparkle tuples have it. It breaks the family's own rule that every action is bindable through Bindings.xml. Impact stays low: the player this is built for does not run MelloUI, and with Console Port the actions are already in its list. Not in ROADMAP.md or V1.md (N4 there is a Routes feature, not this).

### ST-11. The Console Port fix's status line reads oddly, repeats the base's hint, and nothing shows which fixes attached

`addons/PatchwerkForever_Stitch_ConsolePort/GameMenu.lua` line 93 (PatchwerkForever_Stitch_ConsolePort; feedback; size M; impact low)

**Now:** `return ('game menu opens directly %s; /patchwerk config for settings, /patchwerk consoleport for diagnostics')` / `:format(env:GetSetting('foreverDirectGameMenu') and 'on' or 'off');` which reads "game menu opens directly on" and repeats the hint the base prints as its last line (PatchwerkForever/Core.lua:423). The Stitches' status lines have five shapes under the heading `P:Print('Active fixes:')` (Core.lua:416), which also lists ones that are off or waiting: 'on' / 'off' (Stitch_MelloUI/RouteOnly.lua:257), 'waiting: EllesmereUI is not loaded' (GameMenuButtons.lua:43), '%d blocked spots; /patchwerk route for settings and commands' (Stitch_MelloUIRoute/Controls.lua:199), 'on, and being followed' (Stitch_DungeonJournal/Reader.lua:292) and the one above. The other Console Port fixes attach or give up silently (ItemMenu.lua:41 `if not ( ItemMenu and ItemMenu.AddEquipCommands and ItemMenu.GetEquipCommand ) then return end;`, Interact.lua:18, Targeting.lua:29, KeyRing.lua:12, the three `if not` shims in Compat.lua), while the README (line 42) asks the player to report a fix "that a Console Port update has made unnecessary".

**Change:** (1) Wording, under an hour: one vocabulary for every status function (on, off, waiting: <addon> is not loaded, each optionally followed by ': ' and a count), no command hints in them (GameMenu.lua:93, Controls.lua:199 becomes 'on: %d blocked spots'), and the base heading 'Fixes:' in place of 'Active fixes:'. (2) In Database.lua add `env.Applied = {}`. Each fix file sets one flag where it attaches: Bindings.lua inside the `if` on line 44 ('Extra Action Button'), ItemMenu.lua after line 41 ('Item menu equip slots'), Interact.lua after line 18 ('Interact (tap)'), Targeting.lua inside the `if` on line 29 ('Target Friendly / Target Hostile'), KeyRing.lua after line 12 ('Key ring slot'), each of the three blocks in Compat.lua, and BlizzardBars.lua when RestoreMicroMenu or RestoreBagsBar returns true. PrintDiagnostics (GameMenu.lua:63) prints first 'Fixes applied: ...' and 'Not applied (not needed, or Console Port has changed): ...' from a fixed list of those names. The status becomes ('on: %d of %d fixes applied').

**Checked:** Every quoted line confirmed. Impact lowered from medium: it is seen only by typing /patchwerk or /patchwerk consoleport. Proposal simplified from a per-fix text state to one flag per file; step (1) can ship alone. The reader's part about registering a fix at Database.lua's two early exits is cut: see dropped. Not in ROADMAP.md or V1.md.

### ST-12. Keep To City Streets is on by default and deletes points from MelloUI Route's saved paths at login

`addons/PatchwerkForever_Stitch_MelloUIRoute/Shared.lua` line 53 (PatchwerkForever_Stitch_MelloUIRoute; defaults; size S; impact low)

**Now:** `{	key  = 'cityStreets';` / `name = 'Keep To City Streets';` / `desc = "In the capitals Route uses only MelloUI's own walked streets, with their lifts and trams: nothing is learned from you there, and what was is forgotten at login.";` gets `def.default = true;` from the loop (lines 81-83). At the first login after installing, AtLoginCities (Ground.lua:288-300) runs ForgetCities(), which removes every learned point inside the six capitals from MelloUIRouteSaved.routes.graphs (Learned:Forget, Ground.lua:201-228): another addon's saved data, and it cannot be put back. The README says so in italics (line 30) and a chat line reports the count afterwards, but the player is not asked; the MelloUI trim was made opt-in for the same reason (Stitch_MelloUI/RouteOnly.lua:37-39: "which no one should get by installing this one").

**Change:** Give the entry `default = false` in Shared.lua (the loop on line 81 only fills in a default that is nil) and change the README bullet to "Keep to city streets (off until you enable it)". Nothing else changes: with the setting off, AtLoginCities() returns before forgetting anything (Ground.lua:290) and Tick() no longer holds learning in cities (Ground.lua:124-132). Say in the CHANGELOG that anyone who never touched the setting must enable it once to keep the behavior; no data is touched by the change itself.

**Checked:** Confirmed: default, the deletion path and both guards. It is the one default in the four Stitches that changes another addon's saved data for good, against the family's opt-in rule. The owner's call all the same: the setting exists because learned paths led routes off Thunder Bluff, and flipping the default silently turns it off for existing installs that left it alone. Not seen by the player this is built for, who does not run MelloUI. Not in ROADMAP.md or V1.md.

### ST: dropped

- **Show the button as the game names it (GetBindingText) in the three binding-change lines (part of the Notify finding):** On this client the KEY_PAD strings are 24-pixel atlas glyphs (Blizzard_SharedXML/SharedConstants.lua:55-58), oversized in a chat line and not the icons a Console Port player knows; and the README says the line is what to report, where the raw key name (PAD1) is the more useful form. The rest of that finding is kept.
- **Register a 'not running' fix at Database.lua's two early exits (part of the Console Port status finding):** Cannot happen on a working install: the TOC requires ConsolePort (line 11, `## Dependencies: PatchwerkForever, ConsolePort`), and Enum.BindingContext.GamepadModeInGameCore exists on this client (Blizzard_APIDocumentationGenerated/KeyBindingsDocumentation.lua:201). The rest of that finding is kept.
- **A note on the Dungeon Journal settings when the journal is absent (part of the empty-list finding):** Could not be confirmed from the two folders: the note would be decided as Reader.lua runs, and whether ForeverDungeonJournal loads on demand (which would make the note wrong at login) cannot be read without opening its files. The rest of that finding is kept.

## WS: Wording, across everything

### WS-1. Bare /sparkle prints a raw game-setting dump instead of the command list

`addons/PatchwerkForever_Thread_Sparkle/Core.lua` line 128 (PatchwerkForever_Thread_Sparkle; wording; size S; impact medium)

**Now:** Core.lua:128 `if word == '' or word == 'say' or word == 'sparkle' then` / `ns.Try('sparkle', ns.SparkleSay)`. SparkleSay opens with Sparkle.lua:682 `ns.Print('Soft-target settings: ' .. table.concat(parts, ', ') .. '.')` ("Interact 3, InteractRange 10, InteractArc 2, NameplateInteract 1, IconGameObject 1, IconInteract 1") and Sparkle.lua:687-689 `'%s: %s; cursor: %s; type: %s%s; nameplate: %s; it %s.'` with `was.plate and 'yes' or 'NO'`. The TOC Notes (line 3) end "Type /sparkle."; /thread and /tracker with no argument both fall through to Help().

**Change:** Core.lua:128 -> `if word == 'status' or word == 'say' or word == 'sparkle' then` so a bare /sparkle falls through to Help() (keep 'say' and 'sparkle': tools/lua_shell.py:86-87 drives the diagnostic as "/sparkle sparkle"). Core.lua:115 -> `ns.Print('  /sparkle status: show the targeted object and why it does or does not sparkle')`. In Sparkle.lua move the CVar block (lines 677-682) to the end of SparkleSay and word it `'Game interact settings (for bug reports): ' .. table.concat(parts, ', ') .. '.'`; line 687 -> `'%s: %s; type: %s%s; nameplate: %s; it %s (cursor: %s).'` with the arguments reordered and `'NO'` -> `'no'` (the cursor name is what explains a guessed type, so keep it, last). README.md:43 -> `/sparkle` lists the commands (`/pfs` is the same); add a row for `/sparkle status`; remove the `/sparkle help` row (line 47).

**Checked:** Confirmed every quote. Unknown words already reach Help(), so only the empty command changes. The cursor value is an atlas name such as Cursor_Crosshair_GatherHerbs_64, not a number as the reader said, and is useful in a report, so the proposal keeps it instead of dropping it. No test asserts the diagnostic text.

### WS-2. Chat and on-screen sentences that are garbled or hard to parse

`addons/PatchwerkForever_Thread_Routes/Route.lua` line 206 (PatchwerkForever_Thread_Routes; wording; size S; impact medium)

**Now:** Route.lua:206 `return nil, 'you are not standing on ground the planner knows (inside a building, on a boat, or on one?).'` (printed by Fail() after /thread go, the Go binding or a new pin; every other reason starts with a capital). Routes Gather.lua:164 `'Farming nearby nodes: routing to the next one at each. /thread gather stop to end.'`, :165 `'Routing to the nearest node, then the next at each. /thread gather stop to end.'`, :182 `'Routing to the nearest %s, then the next at each. /thread gather stop to end.'`. Stitch_DungeonJournal Reader.lua:277 `'Dungeon Journal: nothing to route to. Track a dungeon in the journal first, or every quest is done.'`. Sparkle.lua:568 `self.text:SetText('Your character is taken to be here')`; Sparkle.lua:543 `Write(test, test, 'This is ' .. (KIND_NAMES[kind] or kind), look)` with :32 `other = 'another thing'`.

**Change:** Route.lua:206 -> 'No route from here: you are not standing on ground the route planner knows. You may be inside a building, or on a boat or lift.' Gather.lua:164 -> 'Farming nearby nodes. Each time you reach one, the route moves on to the next. Type /thread gather stop to end.'; :165 -> 'Routing to the nearest node. Each time you reach one, the route moves on to the next. Type /thread gather stop to end.'; :182 -> 'Routing to the nearest %s. Each time you reach one, the route moves on to the next. Type /thread gather stop to end.' Reader.lua:276-278: test the setting first, `if not ns:GetSetting('djList') then` print 'Route Dungeon Journal Quests is disabled in the options.'; otherwise 'Nothing to route to: no dungeon you track in the Dungeon Journal has a quest to accept or turn in right now.' Sparkle.lua:568 -> 'Fade area: it should surround your character'. Sparkle.lua:32 -> `KIND_NAMES = { herb = 'Peacebloom', ore = 'Copper Vein', loot = 'Battered Chest', quest = 'Quest Object', other = 'Mailbox' }` and :543 -> `Write(test, test, KIND_NAMES[kind] or kind, look)`, so the preview shows a name as the real sparkle does. Tests to update: tools/lua_patchwerk.py:651 ("nothing to route to"), tools/lua_shell.py:994 ("This is another thing").

**Checked:** All quotes confirmed at the lines given. Added one thing the reader missed: Read() in Reader.lua:190 returns nil when Route Dungeon Journal Quests is off, so the binding then says "Track a dungeon in the journal first", which is wrong; a quest you hold and have not finished also gives no stop, so "every quest is done" is not accurate either.

### WS-3. The base's addon-list note and READMEs describe the family without the Tracker and the Dungeon Journal Stitch

`addons/PatchwerkForever/PatchwerkForever.toc` line 3 (PatchwerkForever; docs; size S; impact medium)

**Now:** PatchwerkForever.toc:3 `## Notes: ... It does nothing by itself; add Stitch (fixes for Console Port and MelloUI) and Thread (our own tools: Routes, Sparkle).` addons/PatchwerkForever/README.md:40-43: the "Thread: our own tools" table has rows for Routes (Thread) and Sparkle (Thread) only. README.md:55 "The base tells you once, in chat, when Console Port or MelloUI is running and the Stitch for it is not installed." (Core.lua:44 P.Family also lists Dungeon Journal). README.md:66 "The Thread tools have commands of their own (`/thread`, `/sparkle`)." addons/PatchwerkForever_Thread_Tracker/README.md:21 "Version 1.0." and the repository README.md:23 "... recipes, gathering. 1.0." while the Tracker's TOC says `## Version: 1.1.0`.

**Change:** toc:3 -> `... add Stitch (fixes for Console Port, Dungeon Journal and MelloUI) and Thread (our own tools: Routes, Tracker, Sparkle).` Base README.md, after line 42, add `| **Patchwerk Forever: Tracker (Thread)** | A quest tracker: your quests by zone with distances, your guide's steps, quest item buttons, tracked recipes and a gathering list. |`. README.md:55 -> "when Console Port, MelloUI or DungeonJournal is running". README.md:66 -> "(`/thread`, `/tracker`, `/sparkle`)". Tracker README.md:21 -> "Version 1.1."; repository README.md:23 -> "1.1."

**Checked:** Confirmed each line. The base README's Stitch table already has the Dungeon Journal row; only the TOC note, the Thread table, line 55 and line 66 lag. Added the Tracker README's own "Version 1.0." (line 21), which the reader did not list. Not the same as ROADMAP A1, which is about the READMEs' prose style, not missing addons.

### WS-4. Base and Stitch chat lines have no colon after "Patchwerk", and the "needs a newer base" line names the addon by its folder

`addons/PatchwerkForever/Core.lua` line 73 (PatchwerkForever (base, Stitches, all seven Link.lua); consistency; size S; impact low)

**Now:** Core.lua:73 `print(GOLD .. 'Patchwerk|r', ...)`: lines read "Patchwerk Console Port is running. The fixes..." (Core.lua:316), "Patchwerk Its front page could not be drawn" (Front.lua:237), "Patchwerk A part failed while loading:" (Core.lua:288), while the tools print "Tracker: ..." (Tools.lua:68 `('|c%s%s|r: ')`). Stitch tags follow with no colon: Stitch_ConsolePort GameMenu.lua:53 `env:Print('|cff69ccf0Console Port|r', ...)`; Stitch_DungeonJournal Reader.lua:273/277/282 write the tag inline and uncolored: `ns:Print('Dungeon Journal: back to your main route.')`. Link.lua (Thread_Tracker:20, Thread_Routes:18, Thread_Sparkle:18): `print('|cffd6a35bPatchwerk|r ' .. ADDON .. ' needs a newer Patchwerk Forever (the base addon). It is not running.')`; the four Stitch Link.lua:16 the same with `:format(addonName)`, giving "Patchwerk PatchwerkForever_Thread_Tracker needs a newer Patchwerk Forever (the base addon). It is not running."

**Change:** 1) Core.lua:73 -> `print(GOLD .. 'Patchwerk:|r', ...)`; Front.lua:237 'Its front page could not be drawn' -> 'The front page could not be drawn'. 2) GameMenu.lua:53 -> `'|cff69ccf0Console Port:|r'` (same one-character edit in Stitch_MelloUI RouteOnly.lua:118 and Stitch_MelloUIRoute Shared.lua:116 and :135). 3) Reader.lua: add `local function Print(...) ns:Print('|cff69ccf0Dungeon Journal:|r', ...) end` and use it at 273/277/282 with the inline prefix removed and a capital first letter. 4) In all seven Link.lua: `local ok, title = pcall(C_AddOns.GetAddOnMetadata, addonName, 'Title')` (ADDON in the Thread files), `title = (ok and type(title) == 'string' and title or addonName):gsub('^Patchwerk Forever:%s*', '')`, then `print(('|cffd6a35bPatchwerk:|r %s needs a newer Patchwerk Forever (the base addon) and is not running. Update Patchwerk Forever.'):format(title))`. Tests to update: tools/lua_patchwerk.py:290 ("Patchwerk made-up command: hello there"), :646 and :651 if the Dungeon Journal lines are capitalized; :352 still passes because the phrase "needs a newer Patchwerk Forever" is kept.

**Checked:** Quotes confirmed; print() joins its arguments with a space, so the result is certain without the game (inGame set to false, impact lowered to low). C_AddOns.GetAddOnMetadata is in this client's AddOnsDocumentation.lua and is what the base's Meta() calls. Cut two parts of the original: renaming Routes' prefix from "Thread" (it matches its /thread command, as Tracker and Sparkle match theirs), and moving Console Port notices off CPAPI.Log (a deliberate use of Console Port's own log that cannot be judged outside the game). The Link.lua finding is merged in here. The line only appears when an addon is newer than the base, since the game will not load a part with no base at all.

### WS-5. Tooltips point at a binding or another option without naming it

`addons/PatchwerkForever_Thread_Tracker/Core.lua` line 99 (PatchwerkForever_Thread_Tracker (and Sparkle); gamepad; size S; impact low)

**Now:** Tracker Core.lua:99 `'...nearest quest first. You can bind a key to the first button. The bar does not update during combat.'`; Core.lua:114 `'...Not yet tested in a dungeon; the default tracker is still shown in instances unless you disable that option.'` (the option meant is Keep Default Tracker In Instances, on another page); Sparkle Core.lua:41 `'Ignored objects never sparkle. To ignore one, point at it and type /sparkle ignore, or use the key binding. This button clears the whole list.'` (the binding is 'Ignore Targeted Object', Core.lua:149, and the chat lines say "targeted": Sparkle.lua:617 'No object targeted. Walk up to one first.').

**Change:** Tracker Core.lua:99 -> '...nearest quest first. Bind "Use Nearest Quest Item" to a key or gamepad button to use the first one. The bar does not update during combat.' Core.lua:114 -> '...Not yet tested in a dungeon; the default tracker is still shown in instances unless you disable Keep Default Tracker In Instances.' Sparkle Core.lua:41 -> 'Ignored objects never sparkle. To ignore one, walk up to it and use the "Ignore Targeted Object" binding, or type /sparkle ignore. This button clears the whole list.'

**Checked:** All three tooltips and both binding names confirmed (Tracker Core.lua:188 'Use Nearest Quest Item', Sparkle Core.lua:149). Text-only change; no test asserts these descriptions.

### WS-6. /thread quest says "your RestedXP guide (it has priority...)" whichever guide is followed and whatever the priority is

`addons/PatchwerkForever_Thread_Routes/Sources.lua` line 447 (PatchwerkForever_Thread_Routes; edge-case; size S; impact low)

**Now:** Sources.lua:446-447 `elseif source == 'rxp' then` / `ns.Print('Following: your RestedXP guide (it has priority; change this in the options).')`. Target() also returns 'rxp' for a Dungeon Journal list you selected (Sources.lua:258 `return 'rxp', guide.map, guide.x, guide.y, 'guide'`) and for the guide reached as the fallback when Priority is 'Tracked quest first'. Core.lua:17 `name = 'Follow RestedXP Guide'` gates any guide reader (SETTING.rxp); Core.lua:29 `choices = { { 'rxp', 'RestedXP guide first' }, { 'quest', 'Tracked quest first' } }`. The Tracker calls the same thing `'Show Guide Steps'` (its Core.lua:82).

**Change:** Sources.lua:442 `local source = Target()` -> `local source, _, _, _, picked = Target()`. Lines 446-447 -> `local reader = guide and guide.reader or 'guide addon'` then: when `picked == 'guide'` print `('Following: the %s list you selected.'):format(reader)`; otherwise print `('Following: your guide (%s).%s'):format(reader, ns.Get('sourceFirst') == 'rxp' and ' Guides have priority over tracked quests; change Priority in the options.' or '')`. Routes Core.lua:17 -> `name = 'Follow Guide'`, desc 'With no map pin, route to the current step of your guide addon (RestedXP) and continue to the next as you progress.'; Core.lua:29 -> `{ 'rxp', 'Guide First' }, { 'quest', 'Tracked Quest First' }`. Tests to update: tools/lua_shell.py:446 ("your RestedXP guide (it has priority") and :759 ("Follow RestedXP Guide").

**Checked:** Confirmed: guide.reader is set by the base (Guides.lua:80) to 'RestedXP' or 'Dungeon Journal', and the module-level `guide` is filled by Target() before the line prints. The stored values ('rxp', 'quest') do not change. Dropped the reader's rename of the Stitch's 'Dungeon Journal Before RestedXP': RestedXP is the only other reader today, so that label is accurate.

### WS-7. One thing, two names: small mismatches between labels, chat lines and addons

`addons/PatchwerkForever_Thread_Tracker/Core.lua` line 77 (PatchwerkForever_Thread_Tracker (and Routes, Sparkle); consistency; size S; impact low)

**Now:** (a) Tracker Core.lua:77 `name = 'Auto-Track Nearest Quest'` with desc '...automatically put the quest arrow on your nearest tracked quest.'; the code (Actions.lua:36-38, 207-224) only calls C_SuperTrack.SetSuperTrackedQuestID and never changes what is tracked; Routes calls it the quest arrow (Core.lua:26). (b) Tracker Actions.lua:86 `ns.Print('Routing to: ' .. tostring(...))` vs Routes Sources.lua:406 `'Routing to quest "%s":'`. (c) Tracker Core.lua:84 `name = 'Upcoming Steps'` vs its own :110 `name = 'Nodes Shown'` and Routes Core.lua:21 `name = 'Upcoming Steps Shown'`. (d) Routes Flights.lua:188 `'Flight point learned: %s.'` vs Core.lua:35 "flight points this character has discovered" (the game's own message is ERR_NEWTAXIPATH, which Flights.lua:194 listens for). (e) Routes Float.lua:96 `spot = { 'To the spot you gave' }` vs Sources.lua:449 `'Following: your map pin or coordinates (always first).'`. (f) Sparkle Core.lua:86 `button = 'Test', name = 'Preview Sparkle'` vs Core.lua:106 `button = 'Show', name = 'Preview Area'` and Routes Core.lua:95 `button = 'Show', name = 'Preview Step Text'`. (g) Tracker Core.lua:23 `name = 'Hide Default Quest Tracker'` vs :25 `name = 'Keep Default Tracker In Instances'`.

**Change:** (a) Core.lua:77 -> `name = 'Quest Arrow On Nearest Quest'`, description kept; update the Tracker README.md:66, which quotes the old label, and the stale comment at Actions.lua:12. (b) Actions.lua:86 -> `ns.Print(('Routing to quest "%s".'):format(tostring(Ask(C_QuestLog.GetTitleForQuestID, order[to]) or order[to])))`. (c) Tracker Core.lua:84 -> 'Upcoming Steps Shown'. (d) Flights.lua:188 -> 'Flight point discovered: %s.' (tools/lua_shell.py:262 asserts the old text). (e) Float.lua:96 -> `spot = { 'To your coordinates' }`. (f) Sparkle Core.lua:86 -> `button = 'Show'` (tools/lua_shell.py:763 expects five "Test"; Sparkle README.md:26 says "with a Test button"). (g) Core.lua:23 -> 'Hide Default Tracker' (tools/lua_tracker.py:243 and Tracker README.md:73 quote the old label).

**Checked:** Each pair confirmed in the code. The "Auto-Track Nearest Quest" finding is merged in here as (a); the README line is 66, not 64 as reported, and no test asserts that label. ROADMAP N10 (Auto-track by zone) is a different, planned feature that does change the watch list, which is why the present label misleads. Dropped the reader's item on the base's Reset To Defaults button: "Defaults" is the game's own word for that button (SETTINGS_DEFAULTS, Blizzard_SettingsPanel.lua:78).

### WS-8. Dropdown choices are in sentence case, against Title Case everywhere else

`addons/PatchwerkForever_Thread_Sparkle/Core.lua` line 14 (PatchwerkForever_Thread_Sparkle (and Routes, Tracker, Stitch_ConsolePort); consistency; size S; impact low)

**Now:** Sparkle Core.lua:14-18 `'Soft glow'`, `'Pulsing ring'`, `'Light beam'`, `'Subtle: glints'`, `'Subtle: fireflies'`, `'Subtle: faint shimmer'`, `'Subtle: ground ripple'`, `'Subtle: wisp'`, `'None (name only)'`; :57 `'By object type'`, `'Single color'`; :62 `'Below the icon'`, `'Above the icon'`. Routes Core.lua:26 `'Quest arrow, else nearest tracked'`, `'Quest arrow only'`. Tracker Core.lua:53-54 `'By zone (current zone first)'`, `'By distance'`, `'Completed first, then by zone'`, `'Default order'`; :102 `'Left of the tracker'`, `'Right of the tracker'`. Lowercase "to"/"map" where the family writes 'Route To Next Quest' and 'Reset To Defaults': Stitch_ConsolePort Database.lua:37 `'Switch to Cursor'`, :146 `'Clear Switch to Cursor'`; Tracker Quests.lua:255 `ZoneHeading('Ready to Turn In')`; tools/pack.py:189 `## Title: Routes (Thread) map: %s`.

**Change:** Sparkle: 'Soft Glow', 'Pulsing Ring', 'Light Beam', 'Subtle: Glints', 'Subtle: Fireflies', 'Subtle: Faint Shimmer', 'Subtle: Ground Ripple', 'Subtle: Wisp', 'None (Name Only)'; 'By Object Type', 'Single Color' (and the :60 desc '...when Color Mode is set to Single Color.'); 'Below Icon', 'Above Icon'. Routes: 'Quest Arrow, Then Nearest Tracked', 'Quest Arrow Only'. Tracker: 'By Zone (Current Zone First)', 'By Distance', 'Completed First, Then By Zone', 'Default Order'; 'Left', 'Right'. Second tier, same pass: Database.lua 'Switch To Cursor' and 'Clear Switch To Cursor'; Quests.lua:255 'Ready To Turn In' (tools/lua_tracker.py:221, :448, :465, :468 assert the old heading); pack.py:189 'Routes (Thread) Map: %s' and the Title line of the three generated data TOCs. Only display strings change; the stored values ('glow', 'zone', 'left') stay.

**Checked:** All quotes confirmed. Look.lua:20 states the rule ("Setting names are in Title Case, as the game's own options are") and ns.Sentence only touches setting names, not choices, so the choices are simply unconverted. Left out the reader's Interact.lua:35 '%s (tap)': it is a name shown inside Console Port's own lists, whose convention cannot be checked here. The Console Port labels overlap ROADMAP A5 (Stitch settings wording).

### WS-9. /patchwerk chat lines: "settings" where the tools say "options", "switched on", "Its parts", "Give on or off."

`addons/PatchwerkForever/Core.lua` line 403 (PatchwerkForever; wording; size S; impact low)

**Now:** Core.lua:403 `P:Print('The settings page could not be opened here. /patchwerk set lists the settings.')` (also what /patchwerk config prints in combat: Settings.lua:135 returns false under InCombatLockdown()); :423 `'  /patchwerk config opens the settings. /patchwerk <id> for a fix\'s own commands.'`; :362 `P:Print('settings (/patchwerk set <name> on|off):')`; :375 `'Give a number.'` / `'Give on or off.'`; :381 `'%s%sPatchwerk Forever|r %s. Its parts:'`; :387 `'  none. This is the base: the Stitch and Thread addons are downloads of their own.'`; :392 `'installed, not switched on'`; Front.lua:132 `'Installed, not switched on.'`; Settings.lua:145 `'The settings page could not be made (...). /patchwerk set lists the settings.'`. Stitch_ConsolePort GameMenu.lua:93 status `'game menu opens directly %s; /patchwerk config for settings, /patchwerk consoleport for diagnostics'`. The tools say options: Tools.lua:279 `'Options reset to defaults.'`, Routes Core.lua:110 `'  /thread config: open the options'`.

**Change:** Core.lua:403 -> `P:Print(InCombatLockdown() and 'Options cannot be opened in combat. /patchwerk set lists them in chat.' or 'The options could not be opened. /patchwerk set lists them in chat.')`; :423 -> '  /patchwerk config opens the options. /patchwerk <id> runs a fix\'s own command.'; :362 -> 'Options (/patchwerk set <name> on|off):'; :375 -> 'Usage: /patchwerk set <name> <number>' and 'Usage: /patchwerk set <name> on|off'; :381 -> '%s%sPatchwerk Forever|r %s. Installed addons:'; :387 -> '  None. Patchwerk Forever is the base; the Stitch and Thread addons are installed separately.'; :392 -> 'installed, not enabled'; Front.lua:132 -> 'Installed, not enabled.'; Settings.lua:145 -> 'The options pages could not be created (...). /patchwerk set lists the options in chat.'; GameMenu.lua:93 -> `('Open Game Menu Directly is %s; /patchwerk consoleport prints diagnostics')` (the listing's closing line already says how to open the options). Tests to update: tools/lua_patchwerk.py:223 ("Its parts:", "none. This is the base") and :241 ("installed, not switched on").

**Checked:** Two findings merged (settings/options and the /patchwerk listing); every quote confirmed. Added the separate in-combat sentence, since "could not be opened here" is all a player in combat is told. Dropped the rename of the fix name 'Dungeon Journal quests as a route': the other fixes are named in the same descriptive style ('Console Port on Forever', 'MelloUI Route additions').

### WS-10. British spellings and "a herb" in player-visible text

`addons/PatchwerkForever_Thread_Tracker/Core.lua` line 117 (PatchwerkForever_Thread_Tracker (and Sparkle, Stitch_DungeonJournal); wording; size S; impact low)

**Now:** Tracker Core.lua:117 `voice = 'Patchwerk picked the colours himself. You can pick again.'`; Core.lua:127 `'Color quest names by difficulty (grey, green, yellow, orange, red). When disabled, all names use the color below.'`; PatchwerkForever_Thread_Tracker.toc:3 `...in a list you can move, size and colour. Needs Patchwerk Forever.`; Stitch_DungeonJournal Reader.lua:54 `'...ahead of your levelling guide, whenever it has somewhere to send you...'`; Sparkle.lua:32 `herb = 'a herb'` and :714 `'...Walk up to a herb, an ore node or a chest, then try again.'`

**Change:** Tracker Core.lua:117 -> 'Patchwerk picked the colors himself. You can pick again.'; Core.lua:127 -> '(gray, green, yellow, orange, red)'; Tracker toc:3 -> '...in a list you can move, resize and color.'; Reader.lua:54 -> 'leveling guide'; Sparkle.lua:714 -> 'Walk up to an herb, an ore node or a chest, then try again.' (and 'an herb' at :32 if that table keeps its present wording). Identifiers such as `colour = true` and `nameColour` are never shown and stay.

**Checked:** Searched every in-game string in the base, the Stitches and the three tools for British spellings: these are all there is besides setting keys. Cut the reader's MelloUI items ('go round', 'afterwards'): both are acceptable American usage and belong to ROADMAP A5 for Stitches this player does not run. The READMEs' own 'colour' spellings are ROADMAP A1.

### WS-11. Map data that fails to load is reported by folder name and a raw reason code

`addons/PatchwerkForever_Thread_Routes/Route.lua` line 63 (PatchwerkForever_Thread_Routes; wording; size S; impact low)

**Now:** Route.lua:63-64 `Once('data' .. name, 'Map data "' .. name .. '" could not be loaded (' .. tostring(reason or ok)` / `.. '). It is a separate addon: check it is installed and ticked in the addon list.')` (name is the folder, e.g. PatchwerkForever_Thread_Routes_Kalimdor; reason is the game's code, e.g. DISABLED, or "nil"/"false" when none is given). Route.lua:57 `'No map data for this area (map ' .. tostring(map) .. ').'`. Route.lua:464 `ns.Print(('Map %d, world %.1f, %.1f.'):format(map, x, y))` while Sources.lua:422 and :431 call the same number the continent. Base Core.lua:134 `P:Print(('The %s setting could not be applied: %s'):format(key, tostring(err)))` prints the saved key (e.g. foreverDirectGameMenu).

**Change:** Route.lua:63-64 -> `local ok2, title = pcall(C_AddOns.GetAddOnMetadata, name, 'Title')`; `title = ok2 and type(title) == 'string' and title or name`; `local why = reason and (_G['ADDON_' .. tostring(reason)] or tostring(reason)) or 'unknown reason'`; `Once('data' .. name, ('The map data addon "%s" could not be loaded (%s). Check that it is installed and enabled in the AddOns list.'):format(title, why))`. Route.lua:57 -> `'No map data for this area (map ' .. tostring(map) .. '). Routes cover Kalimdor, the Eastern Kingdoms and Zephras Isle.'`. Route.lua:464 -> 'Continent %d, world position %.1f, %.1f.' Base Core.lua:134 -> format with `(P.Settings.byKey[key] or {}).name or key`.

**Checked:** Cut down from the reader's wider list. Confirmed on this client: C_AddOns.LoadAddOn returns (loaded, value) and the game reads the reason as _G["ADDON_" .. reason] (Blizzard_SharedXML/AddOnUtil.lua:6, AddonList.lua:409); C_AddOns.GetAddOnMetadata exists (wrapped in pcall as the base's Meta() does). Dropped Sources.lua:417: GetQuestUiMapID and C_QuestLog.GetQuestsOnMap both exist here, so that line never prints. Dropped Guides.lua:75 (the base README tells players to report exactly that line), the 'Source:' lines and the cell line of /thread where, which are diagnostics that read well enough.

### WS-12. Headings that do not match what is under them, and "Looks" beside "Appearance"

`addons/PatchwerkForever_Thread_Tracker/Core.lua` line 37 (PatchwerkForever_Thread_Tracker (and Routes, Sparkle); layout; size S; impact low)

**Now:** Tracker Core.lua:37 `{ header = true, name = 'Fading' },` is followed at :44 by `name = 'Hide In Instances'`. Core.lua:118 `{ page = LOOK, header = true, name = 'Size' },` holds 'Scale', 'Font Size' and :123 'Background Opacity', and repeats the first page's :27 `{ header = true, name = 'Size' },` (Width, Max Height). Routes Core.lua:57 `header = true, name = 'Line Style'` is followed at :58 by a setting also named `'Line Style'`. Sparkle Core.lua:69 and :71 name the page `'Sparkle: Looks'` where the Tracker's equivalent is `'Tracker: Appearance'` (Tracker Core.lua:17).

**Change:** Tracker Core.lua:37 -> 'Visibility'. Core.lua:118 -> 'Scale And Font', and move the `back` entry (Background Opacity, lines 123-124) to the end of the 'Colors' group. Routes Core.lua:57 -> 'Line'. Sparkle: 'Sparkle: Looks' -> 'Sparkle: Effects' at Core.lua:69 and :71, in the chat line at Sparkle.lua:602 and in README.md:37. Page and heading names are not saved keys, but the tests assert them: tools/lua_tracker.py:237-238 (heading list), tools/lua_shell.py:732 and :745 (page name), :739 (heading list).

**Checked:** Confirmed all four. Trimmed the reader's proposal: 'Tracker: More' and 'Sparkle: Behind My Character' are left alone, since neither mislabels what is on the page and renaming them is taste, with test and README churn for no gain.

### WS: dropped

- **"Route To Pin, Guide Step Or Quest" is a long binding name beside "Stop Routing":** The quote is right (Routes Core.lua:159), but the name is accurate and says what the binding does; 'Start Routing' would say less. The only real roughness claimed, that Console Port's list cuts it off, cannot be confirmed without the game, so this is taste, not a confirmed defect.
- **The MelloUI Stitches: Patchwerk's voice in a confirmation box, "unticks", lowercase line starts, a setting key in a chat line:** The quotes are right, but this is ROADMAP item A5 (the Stitches' settings read through for standard wording), as the reader says, and it is for two addons the player this is built for does not run. The one-character colon edit to their chat tags is kept inside the chat prefix finding.
- **"Auto-Track Nearest Quest" does not track anything: it moves the quest arrow:** Confirmed and kept, merged into "One thing, two names" as item (a), with the README line corrected to 66.
- **/patchwerk listing: "Its parts", a lowercase "none.", "Give on or off." and a run-on status line:** Confirmed and kept, merged into the /patchwerk chat lines finding (same file, same pass). Its rename of the fix name 'Dungeon Journal quests as a route' was dropped: the other fixes are named in the same style.
- **"Needs a newer Patchwerk Forever" names the addon by its folder and does not say what to do:** Confirmed and kept, merged into the chat prefix finding, which edits the same line of the same seven Link.lua files.

## GP: The gamepad player and the first five minutes

### GP-1. Skipping a guide step or going back a step has no key binding, and a successful skip prints nothing

`addons/PatchwerkForever_Thread_Tracker/Guide.lua` line 28 (PatchwerkForever_Thread_Tracker; gamepad; size S; impact medium)

**Now:** Guide.lua:28-31 `local function Go(info, index, from)
	if not ns.Get('guideSkip') then return end
	if ns.Base.Guides:Go(info, index) then
		before = { source = info.source, index = from }` (a line is printed only on failure, line 33). The ways in are a left-click on the step, the right-click menu (Guide.lua:115-116 `{ 'Skip Step', ... }, { 'Previous Step', ... }`) and Core.lua:149 `ns.Print('  /tracker back: undo the last guide step you skipped by clicking')`. Bindings.xml holds PATCHWERKFOREVER_TRACKER_FOLD, _NEXT, _PREV and `CLICK PatchwerkForeverTrackerNearestItem:LeftButton` only.

**Change:** In Guide.lua add `function ns.GuideStep(step)`: `local pick = ns.Base.Choice:Get()`; `local info = (pick and pick.kind == 'guide') and ns.Base.Guides:Read(0, pick.id) or ns.Base.Guides:Read(0)`. With no `info` or no `info.index` print 'No guide step to skip.' and return. Otherwise call `ns.Base.Guides:Go(info, info.index + step)` directly (not gated by Click To Skip Steps, which only guards stray clicks); on true set `before = { source = info.source, index = info.index }` and print 'Skipped step N.' (step 1) or 'Went back one step.' (step -1); on false print the existing '%s could not jump to that step.'; then ns.Refresh(). Print the same 'Skipped step N.' line from the local Go() on success, so a stray click is noticed. Add to the Tracker's Bindings.xml two entries, PATCHWERKFOREVER_TRACKER_GUIDE_SKIP and PATCHWERKFOREVER_TRACKER_GUIDE_BACK, and in Core.lua `BINDING_NAME_PATCHWERKFOREVER_TRACKER_GUIDE_SKIP = 'Skip Guide Step'`, `..._GUIDE_BACK = 'Previous Guide Step'`, two global functions that call `ns.Try('the guide step', ns.GuideStep, 1 / -1)`, and a `/tracker skip` word with its help line. Tooltip at Core.lua:89 -> 'Click the current step to skip it, or an upcoming step to jump to it. Right-click a step for more. The Skip Guide Step and Previous Guide Step key bindings do the same without a mouse.' Add the two bindings to the README's Clicks section.

**Checked:** Quotes confirmed. Guides:Read(count, id) and Guides:Go exist in the base (Guides.lua:97, 116); RestedXP's Go returns false out of range, the Dungeon Journal reader's Go handles +1 and a negative offset. Not in ROADMAP.md or V1.md (T11 covered only next/previous quest). Corrected: info.index can be nil (a reader that only has the arrow's spot), so guard it; the Dungeon Journal list does not go back to index-1, hence the neutral 'Went back one step.' Dropped the claim that a gamepad player has no other way (a cursor click on the step works; RestedXP itself was not read), so impact lowered from high to medium.

### GP-2. The family's key bindings sit in the shared AddOns section with no visible heading

`addons/PatchwerkForever_Thread_Routes/Bindings.xml` line 2 (PatchwerkForever_Thread_Routes; discoverability; size S; impact medium; needs a look in the game)

**Now:** All four Bindings.xml files use `category="ADDONS"` with a header, e.g. `<Binding name="PATCHWERKFOREVER_THREAD_GO" header="PATCHWERKFOREVER_THREAD" category="ADDONS">`. On this client the game's Key Bindings page draws a header as an empty 25-pixel gap, not as text (forever-src Blizzard_SettingsDefinitions_Frame/Keybindings.lua:251-252 `if strsub(action, 1, 6) == "HEADER" then tinsert(bindingsCategories[cat].bindings, KeybindingSpacer);`, and Keybindings.xml `SettingsKeybindingSpacerTemplate` is a bare frame). So 'Stop Routing', 'Collapse / Expand Tracker', 'Ignore Targeted Object' and 'Route Through Dungeon Journal Quests' are listed among every other addon's bindings with no title. Routes' main action is named (Core.lua:159) `'Route To Pin, Guide Step Or Quest'`.

**Change:** Give every binding of the family one section of its own: `category="Patchwerk Forever"` in the Bindings.xml of Routes, Tracker, Sparkle and the Dungeon Journal Stitch (on every <Binding>, including the CLICK one). A literal name works: Keybindings.lua:220-227 uses `_G[cat]` when it is a string and otherwise the text itself, and the game's own Blizzard_GamepadActionBars/Bindings.xml uses `category="Gamepad Action Buttons"`. The action names do not change, so saved bindings are kept. Keep the header attributes for binding lists that do draw them. Rename 'Route To Pin, Guide Step Or Quest' to 'Start Routing' (pairs with 'Stop Routing'), and make sure each name says what it acts on now that no heading is drawn (Sparkle's 'Ignore Targeted Object' needs the word Sparkle in it). Update the four READMEs that send the player to AddOns: Routes README:121 and Sparkle README:49 ('Options → Keybindings → AddOns'), Tracker README:56-57 and Dungeon Journal README:45 ('Key Bindings, under AddOns'). To confirm in the game: how Console Port's binding list shows the new section and the headers.

**Checked:** Confirmed in all four Bindings.xml files and in the client source: headers become spacers, categories become the section titles, and a category that is not a global string is shown as written. Corrected: four READMEs mention the place, not three. Console Port's own list could not be read (outside the allowed folders), so how it groups them stays an in-game check.

### GP-3. A list taller than Max Height scrolls only with the mouse wheel, and Route To Next Quest can choose a quest that is out of view

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 127 (PatchwerkForever_Thread_Tracker; gamepad; size M; impact medium)

**Now:** Frame.lua:127-130 `body:SetScript('OnMouseWheel', function(_, delta)
		scroll = scroll - delta * WHEEL
		ns.Refresh()
	end)` is the only place `scroll` is moved (line 384 only clamps it). Core.lua:31 `desc = 'Maximum height of the tracker. A longer list scrolls with the mouse wheel.'`. ns.Cycle sets the choice, prints 'Routing to: ...' and ends with `ns.Refresh()` (Actions.lua:84-88); nothing scrolls to the chosen quest. Bright() (Frame.lua:466-474) wakes a tracker faded by Fade When Not Hovered only through `changed`, which is set (line 364) when a block's words change; moving the marker does not change them.

**Change:** In Render, while placing blocks, remember `markTop = y` and `markBottom = y + h` for the block whose `each.mark` is true. Add a file-local `reveal` flag and `function ns.Reveal() reveal = true; changed = GetTime(); ns.Refresh() end`. Just before the clamp at line 384: `if reveal and markTop then if markTop - PAD < scroll then scroll = markTop - PAD elseif markBottom + PAD > scroll + tall then scroll = markBottom + PAD - tall end end; reveal = false`. Call ns.Reveal() in place of ns.Refresh() at the end of ns.Cycle (Actions.lua:88), so the chosen quest is brought into view and a faded tracker brightens for the AWAKE seconds. Add `function ns.Scroll(dir) scroll = scroll + dir * 2 * WHEEL; changed = GetTime(); ns.Refresh() end` and two bindings in Bindings.xml and Core.lua, PATCHWERKFOREVER_TRACKER_SCROLL_UP = 'Scroll Tracker Up' and PATCHWERKFOREVER_TRACKER_SCROLL_DOWN = 'Scroll Tracker Down' (ns.Scroll(-1) and ns.Scroll(1)); the existing clamp keeps it in range. Tooltip at Core.lua:31 -> 'Maximum height of the tracker. A longer list scrolls with the mouse wheel or the Scroll Tracker key bindings.' Same sentence in README line 82.

**Checked:** Quotes confirmed; `scroll` is written only at Frame.lua:128 and clamped at 384, and Cycle never touches it. The Ready to Turn In group, Recipes (and Gathering, order 80) are the parts that fall below the fold. Not in ROADMAP.md or V1.md. Size raised from S to M (a reveal pass in Render plus two bindings and their checks); impact lowered from high to medium: Max Height can be raised to 1000 as a workaround, and the default sort keeps the nearest quests at the top.

### GP-4. A gathering run and Show Step Text again can only be started with a mouse click or a slash command

`addons/PatchwerkForever_Thread_Routes/Bindings.xml` line 1 (PatchwerkForever_Thread_Routes; gamepad; size S; impact medium)

**Now:** Bindings.xml has two actions only: `<Binding name="PATCHWERKFOREVER_THREAD_GO" header="PATCHWERKFOREVER_THREAD" category="ADDONS">` and `<Binding name="PATCHWERKFOREVER_THREAD_STOP" category="ADDONS">`. Core.lua:108-109: `ns.Print('  /thread step: show the step text again')` and `ns.Print('  /thread gather: route to the nearest recorded herb or ore node, then the next (gather round, gather <name>, gather list, gather stop)')`. The other way to start a run is a click on a row of the Tracker's Gathering section (Tracker Gather.lua:35-38). Gather.lua:164-165 ends its chat lines with '/thread gather stop to end.'

**Change:** Add two entries to Routes' Bindings.xml and Core.lua. PATCHWERKFOREVER_THREAD_GATHER = 'Route To Nearest Gathering Node': `function PatchwerkForever_Thread_Routes_Gather() ns.Try('gather', ns.GatherSay, ns.GatherActive() and 'stop' or '', true) end`, so one button starts the run and ends it; give ns.GatherSay a second argument `fromKey` and, when it is set, end the start line with 'Press the key again to stop.' in place of '/thread gather stop to end.' PATCHWERKFOREVER_THREAD_STEP = 'Show Step Text': `ns.Try('step', ns.FloatAgain)`. Optional third: a button under the Gathering Nodes heading of the first options page, `{ button = 'Forget', name = 'Forget Nearby Nodes', click = function() ns.NodesForget() end, desc = 'Delete recorded nodes within 15 yards of you.' }`, which today is '/thread nodes forget' only. Update Routes README:121 ('Two actions can be bound ...').

**Checked:** Quotes confirmed. ns.GatherActive (Gather.lua:119), ns.GatherSay (158), ns.FloatAgain (Float.lua:110) and ns.NodesForget (Nodes.lua:273, FORGET = 15) all exist; the settings list already supports `button =` entries (base Tools.lua:215). Stop Routing does end a run (Route.lua:426 sets user = true, Gather.lua:131 clears the run). PLAN-tracker.md:202 notes a binding was not asked for at the time, not that it was refused; no item in ROADMAP.md or V1.md covers it.

### GP-5. Nothing at first login says where the options are, and the two-trackers line sends the player to a slash command

`addons/PatchwerkForever/Core.lua` line 345 (PatchwerkForever; discoverability; size S; impact medium)

**Now:** The base's login handler adds only `hooks[#hooks + 1] = TellMissing;` (Core.lua:345), which prints nothing when every Stitch is installed. The lines a new player can get are the Console Port Stitch's 'Cleared native gamepad bindings that blocked Console Port: %s' (Conflicts.lua:90), Tracker Quiet.lua:155 `ns.Print('EllesmereUI\'s quest tracker is also enabled, so you will see two trackers. Disable one of them in the addon list (or type /tracker off to keep EllesmereUI\'s).')`, Routes' 'Your known flight points have not been read yet ...' (Route.lua:82) and 'Recorded your first gathering node ...' (Nodes.lua:102). None names the options page; the TOC Notes name only slash commands. PatchwerkForever.toc has no AddonCompartmentFunc line.

**Change:** 1) In Core.lua's login handler, after TellMissing: once per account (`local told = P:GetSaved('told'); if not told.welcome then told.welcome = true; ... end`) print one line with the base's prefix: 'Options are under Options > AddOns > Patchwerk Forever.' (the wording the tools' fallback lines already use). 2) Add `## AddonCompartmentFunc: PatchwerkForever_OnAddonCompartmentClick` to PatchwerkForever.toc and define that global in Settings.lua: `function PatchwerkForever_OnAddonCompartmentClick() if not ns.OpenSettings() then P:Print(InCombatLockdown() and 'Options cannot be opened in combat.' or 'Options are under Options > AddOns > Patchwerk Forever.') end end`, so the options are one click from the minimap's addon list. 3) Quiet.lua:155 -> 'EllesmereUI\'s quest tracker is also enabled, so two trackers are shown. Disable EllesmereUI\'s in the addon list, or untick Enable Tracker under Options > AddOns > Patchwerk Forever > Tracker (Thread).' Whether EllesmereUI leaves the minimap's addon button visible needs a look in the game.

**Checked:** All quoted lines confirmed at the places named. The client does read the TOC line: forever-src Blizzard_Minimap/Mainline/AddonCompartment.lua:105 `C_AddOns.GetAddOnMetadata(addonIndex, "AddonCompartmentFunc")`, and Camelot/AddonCompartment.xml defines AddonCompartmentFrame on MinimapCluster, so it exists on this client. The `told` table is the base's own (Core.lua:24, 312). Simplified the welcome line (the count of addons added nothing). The compartment entry is the most feature-like part; it is one TOC line and one function, so it stays.

### GP-6. Ignore Targeted Object cannot be undone without typing, and /sparkle undo does not undo the last ignore

`addons/PatchwerkForever_Thread_Sparkle/Sparkle.lua` line 615 (PatchwerkForever_Thread_Sparkle; feedback; size S; impact low)

**Now:** Sparkle.lua:620-621 `IgnoreList()[last.name] = true
	ns.Print('"' .. last.name .. '" added to the ignore list. /sparkle undo to revert.')`. IgnoreUndo (625-633) removes `last.name`, the object pointed at last (Update() rewrites `last` at line 504 for every object, ignored or not), not the object ignored last: after walking past another object it prints `'The last targeted object is not on the ignore list. /sparkle list shows the list.'`, while the help (Core.lua:117) says `/sparkle undo: undo the last ignore`. The options tooltip (Core.lua:41) says `'Ignored objects never sparkle. To ignore one, point at it and type /sparkle ignore, or use the key binding. This button clears the whole list.'`

**Change:** Make the binding a toggle. In ns.IgnoreThis: when `IgnoreList()[last.name]` is already set, remove it and print '"X" removed from the ignore list.'; otherwise add it, keep the name in a file-local `lastIgnored`, and print '"X" added to the ignore list. Press the key binding again to undo.' (`last` still follows an ignored object, so a second press on the same object finds it). Rename the binding (Core.lua:149) to 'Ignore / Unignore Sparkle Object', the form 'Collapse / Expand Tracker' already uses. Make ns.IgnoreUndo remove `lastIgnored` (falling back to today's check), which is what the help line promises. Tooltip -> 'Ignored objects never sparkle. To ignore an object, walk up to it and press the Ignore / Unignore Sparkle Object key binding, or type /sparkle ignore. This button clears the whole list.' Update Sparkle README:44-49. The list with a remove button for each entry stays ROADMAP S1.

**Checked:** Quotes confirmed (IgnoreUndo is lines 625-633). Traced Update(): `last` is replaced on every soft-target change and records `ignored`, so undo fails once another object has been pointed at, and a toggle on the same object works. Not the same as ROADMAP S1 (the list in the options). Impact lowered from medium to low: it only shows after a mistaken ignore.

### GP-7. Unlock Position shows nothing to drag when the list is empty, and the drag bar can only be locked by a slash command or the options button

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 378 (PatchwerkForever_Thread_Tracker; edge-case; size S; impact low)

**Now:** Frame.lua:378-381 `if usedHeads == 0 then
		frame:Hide()
		return After(false)
	end` runs before line 393 `if unlocked then handle:Show() else handle:Hide() end`, and the handle is a child of the frame, so with no tracked quest and no guide the drag bar never appears, yet ns.Unlock still prints (line 437) `'Unlocked. Drag the bar above the tracker to move it, then /tracker lock.'`. The bar itself says (line 144) `handle.words:SetText('Drag to move   /tracker lock')`, and line 433 says `'The tracker is disabled. Type /tracker on to enable it.'`.

**Change:** 1) In Render, hide an empty tracker only when it is locked: `if usedHeads == 0 and not unlocked then ...`. While unlocked and empty, give the frame its width and a height of about three lines (`math.max(total, 3 * (size + 6))`), write 'Quest Tracker' in the header color in the empty body (one font string made once, hidden otherwise), show the handle, and call After(true). 2) `handle:RegisterForClicks('RightButtonUp')` and `handle:SetScript('OnClick', function() ns.Unlock(false) end)`; bar text 'Drag to move, right-click to lock'; line 437 -> 'Tracker unlocked. Drag the bar above it to move it, then right-click the bar to lock it.'; line 433 -> 'The tracker is disabled. Tick Enable Tracker first.' 3) When Hide In Instances is hiding it (Render line 302), have ns.Unlock say 'The tracker is hidden in instances.' in place of the unlocked line. Tooltip of Unlock Position (Core.lua:34) -> '... Click again, or right-click the bar, to lock it in place.'

**Checked:** Quotes confirmed; with usedHeads == 0 Render returns before the handle is shown, and the same happens when Hide In Instances hides the frame. Cut down: the two position sliders the reader proposed are new settings (a feature), and the drag bar and Reset Position already exist, so only the polish parts are kept. Size lowered from M to S and impact from medium to low (an empty list at the moment of unlocking is uncommon).

### GP-8. Chat prefixes take three forms: the base and three Stitches have no colon, and Routes calls itself 'Thread'

`addons/PatchwerkForever/Core.lua` line 73 (PatchwerkForever; consistency; size S; impact low)

**Now:** Core.lua:72-74 `function P:Print(...)
	print(GOLD .. 'Patchwerk|r', ...)
end`, so the base's own lines read 'Patchwerk Console Port is running. The fixes and additions for it are a separate addon: ...', 'Patchwerk Active fixes:' and 'Patchwerk settings (/patchwerk set <name> on|off):'. The Stitches pass a second tag through the same function: `env:Print('|cff69ccf0Console Port|r', ...)` (Stitch_ConsolePort/GameMenu.lua:53), `ns:Print('|cff9b8cffRoute|r', ...)` (Stitch_MelloUIRoute/Shared.lua:116), `ns:Print('|cff9b8cffMelloUI|r', ...)` (Stitch_MelloUI/RouteOnly.lua:118), giving 'Patchwerk Console Port Cleared native gamepad bindings ...', while the Dungeon Journal Stitch writes 'Patchwerk Dungeon Journal: back to your main route.' (Reader.lua:273). The tools print '<Name>: text' (Tools.lua:68 `('|c%s%s|r: ')`), but Routes' Link.lua:12 passes `name = 'Thread',`, so its lines read 'Thread: Routing stopped.' beside 'Tracker: ...' and 'Sparkle: ...', all three being Thread tools.

**Change:** One form for every line: colored tag, colon, then a sentence that starts with a capital. (a) Stitch tags get the colon: GameMenu.lua:53 `'|cff69ccf0Console Port|r:'`, RouteOnly.lua:118 `'|cff9b8cffMelloUI|r:'`, Shared.lua:116 and :135 `'|cff9b8cffRoute|r:'`; in the Dungeon Journal Stitch's Reader.lua:273-282 keep the 'Dungeon Journal: ' tag and capitalize the word after it ('Back to your main route.', 'Nothing to route to. ...', 'Routing through the quests of your tracked dungeons.'). (b) P:Print is shared with the Stitches (P.SHARED), so leave it as it is and add `function ns.Say(...) print(GOLD .. 'Patchwerk|r:', ...) end` in Core.lua for the base's own lines: Core.lua:134, 288, 316, 349, 362, 375, 377, 403, 416; Settings.lua:115, 145; Gather.lua:44; Guides.lua:75; Front.lua:237. Capitalize Core.lua:362 ('Settings (/patchwerk set <name> on|off):') and change Front.lua:237 to 'The front page could not be drawn (...)'. Put the same colon in the seven Link.lua failure lines ('|cffd6a35bPatchwerk|r: '). (c) Routes' Link.lua:12 -> `name = 'Routes'` (its pages are already 'Routes (Thread)', 'Routes: Trail', 'Routes: Step Text'; the /thread command stays), and the example in the Tools.lua:16 comment. (d) Tools.lua:83 `'a problem in ' .. label` -> 'A problem in ', and the same words quoted in the base README line 68. Run the tools/lua_*.py checks afterwards in case one matches an old prefix.

**Checked:** Quotes confirmed. The reader's fix was wrong in two places and is corrected: a colon inside P:Print would turn every Stitch line into 'Patchwerk: Console Port Cleared ...' because the Stitches pass their own tag through it, and the Dungeon Journal Stitch's 'Dungeon Journal: ' lead is that Stitch's tag, the one form that already has a colon, so it stays. Impact lowered from medium to low (wording only; the base itself rarely prints).

### GP-9. Use Nearest Quest Item does nothing, silently, when no quest has an item or when Show Quest Item Bar is unticked

`addons/PatchwerkForever_Thread_Tracker/Items.lua` line 103 (PatchwerkForever_Thread_Tracker; feedback; size S; impact low)

**Now:** Items.lua:103 `if not (ns.Get('on') and ns.Get('items')) then return list end`, so with Show Quest Item Bar unticked the hidden binding button gets no item either, although the comment at line 202 says `-- the button a key is bound to: the nearest quest's item, whether the strip is on screen or not`. With no item, lines 205-206 clear its attributes (`nearest:SetAttribute('type', first and 'item' or nil)`) and a press does nothing at all. The option's tooltip (Core.lua:99) says 'You can bind a key to the first button.'

**Change:** In Wanted(), return early only on `not ns.Get('on')`; build the quest-item list always, and add the guide step's items only when `ns.Get('items')` is on. In Layout(), show the eight strip buttons only when the bar is ticked (`local item = x and ns.Get('items') and list[i]`) and add `tostring(ns.Get('items'))` to the `signature` parts so ticking the box lays it out again; `nearest` then always holds the nearest quest's item, as the comment and the binding's name say. Add once at load (outside combat): `nearest:SetScript('PostClick', function(self, _, down) if not down and not self.item then UIErrorsFrame:AddMessage('No usable quest item.', 1, 0.1, 0.1) end end)`; it reads a plain field and touches nothing secure, so a press with nothing to use answers in the game's own red text. Tooltip at Core.lua:99: replace 'You can bind a key to the first button.' with 'The Use Nearest Quest Item key binding works with the bar hidden too.'

**Checked:** Quotes confirmed; Layout() takes everything from Wanted(), so unticking the bar empties the binding's button as well. UIErrorsFrame:AddMessage(text, r, g, b) is used this way throughout the client source, and the button registers 'AnyUp' and 'AnyDown' (Items.lua:62), so the `not down` test gives one message a press. Added the signature detail the reader missed. A gamepad player who binds the item and hides the strip is exactly who hits this.

### GP-10. The base's addon-list note and three READMEs still describe the family without the Tracker and the Dungeon Journal Stitch

`addons/PatchwerkForever/PatchwerkForever.toc` line 3 (PatchwerkForever; docs; size S; impact low)

**Now:** `## Notes: The base of the Patchwerk Forever addons: their shared settings pages, saved data and /patchwerk. It does nothing by itself; add Stitch (fixes for Console Port and MelloUI) and Thread (our own tools: Routes, Sparkle).` The base README's Thread table (lines 40-43) lists only Routes and Sparkle, and line 66 says 'The Thread tools have commands of their own (`/thread`, `/sparkle`).' The Tracker README line 21 says 'Version 1.0.' (its TOC: 1.1.0) and has the '**Without a mouse**: bind "Route To Next Quest" ...' bullet under the heading 'Item buttons' (line 56). Routes' CHANGELOG.md has no title line and opens with '## 0.14.0 (beta)', above '## 0.16.0 (beta)' (line 18) and '## 0.15.0 (beta)' (line 28). The root README says Tracker '1.0.' (line 23), lists build names without tracker and dungeonjournal (line 52) and release tags without them (line 101).

**Change:** TOC Notes -> '... add Stitch (for Console Port, Dungeon Journal and MelloUI) and Thread (our own tools: Routes, Tracker, Sparkle).' Base README: add a Tracker (Thread) row to the Thread table; '(`/thread`, `/tracker`, `/sparkle`)' in Commands; in line 55 'when Console Port, DungeonJournal or MelloUI is running' (line 53 is the history of 1.x and stays). Tracker README: 'Version 1.1.'; move the 'Without a mouse' bullet to the Clicks section. Routes CHANGELOG: add '# Patchwerk Forever: Routes (Thread)' and a blank line at the top, and move the 0.14.0 entry (lines 1-16) down between 0.15.0 and 0.13.0. Root README: Tracker '1.0' -> '1.1'; add `dungeonjournal` and `tracker` to the build names in line 52; add `thread-tracker-1.1.0` and `stitch-dungeonjournal-1.0.0` to the tags in step 4.

**Checked:** Every quote confirmed against the files. Moving the changelog entry is safe: tools/upload.py:110 finds an entry by its '## <version>' heading wherever it stands, and release.py:291 only checks the heading is present. Corrected: the base README has one sentence to change (line 55), not two. tools/release.py already has the tracker and dungeonjournal keys and tags the README omits. ROADMAP A1 is about the READMEs' wording style, not these facts.

### GP-11. The four command helps are laid out four ways, and none says why the options did not open in combat

`addons/PatchwerkForever_Thread_Sparkle/Core.lua` line 128 (PatchwerkForever_Thread_Sparkle; consistency; size S; impact low)

**Now:** Sparkle Core.lua:128-129 `if word == '' or word == 'say' or word == 'sparkle' then
		ns.Try('sparkle', ns.SparkleSay)`: /sparkle alone prints 'Soft-target settings: Interact 1, InteractRange ...', where /thread and /tracker alone print their command list. /patchwerk alone lists parts and fixes and ends with (base Core.lua:423) `print('  /patchwerk config opens the settings. /patchwerk <id> for a fix\'s own commands.')`, with no word of /patchwerk set. /thread lists one command a line with config seventh of eleven; /tracker packs several a line (Core.lua:146 `'  /tracker move: unlock to drag;  /tracker lock: lock in place;  /tracker reset: reset position'`). The base says 'settings', the tools 'options'. When config fails (ns.OpenToolSettings and ns.OpenSettings return false in combat) the base says 'The settings page could not be opened here. /patchwerk set lists the settings.' and the tools 'Options are under Options > AddOns > Patchwerk Forever > Thread: ...'; neither says why.

**Change:** One layout for all four: a heading '<Name> commands (/cmd or /alias):', then one command a line as '  /cmd word: what it does', everyday ones first, diagnostics after, 'config: open the options' last. /patchwerk keeps its list of parts and fixes, then prints '/patchwerk config: open the options', '/patchwerk set <name> on|off: change a Stitch setting', '/patchwerk <id>: a fix\'s own commands'. Use 'options' everywhere. In all four config branches (base Core.lua:402, Routes Core.lua:133, Tracker Core.lua:176, Sparkle Core.lua:139), when InCombatLockdown() is true print 'Options cannot be opened in combat.' in place of the fallback line. Optional, and a change of documented behavior: /sparkle with no word prints the help and the diagnostic moves to '/sparkle check' (keep 'say' working); if done, update Sparkle README lines 43 and 47 and the first help line.

**Checked:** Quotes confirmed; /thread's help is eleven lines with config seventh, and both open functions refuse in combat (Tools.lua:322, Settings.lua:135) without a reason reaching the player. Corrected: the base's failure line does point to /patchwerk set, and /sparkle printing the diagnostic is documented in Sparkle's README (line 43, with /sparkle help at line 47), so that part is a consistency choice, not a mistake, and is marked optional. Typed commands matter little to a gamepad player; the combat line is the part most likely to be noticed.

### GP-12. A part newer than the base announces it in unclear words, and its key bindings then call functions that were never defined

`addons/PatchwerkForever_Thread_Tracker/Link.lua` line 20 (PatchwerkForever_Thread_Tracker; edge-case; size S; impact low)

**Now:** `print('|cffd6a35bPatchwerk|r ' .. ADDON .. ' needs a newer Patchwerk Forever (the base addon). It is not running.')` (the same sentence in all seven Link.lua files; the Stitches build it with `:format(addonName)`). It names the folder ('PatchwerkForever_Thread_Tracker'), 'It is not running' can be read as the base, and no version is given. P:Link and P:Tool just `return false` (base Core.lua:259-261, Tools.lua:63-66), every later file stops at `if not ns.linked then return end`, but Bindings.xml is still loaded, e.g. `PatchwerkForever_Thread_Tracker_Fold()`, a global that Core.lua:191 never got to define.

**Change:** 1) In each Link.lua read `local meta = C_AddOns and C_AddOns.GetAddOnMetadata` and print: 'Patchwerk: <Title> <Version> needs a newer Patchwerk Forever (<base Version> is installed). Update Patchwerk Forever; until then this addon does nothing.', with Title and Version from `meta(ADDON, 'Title')` / `meta(ADDON, 'Version')` and the base's from `meta('PatchwerkForever', 'Version')`, falling back to the folder name when a value is missing. 2) Guard each Bindings.xml body so a bound key is silent instead of a Lua error: `if PatchwerkForever_Thread_Tracker_Fold then PatchwerkForever_Thread_Tracker_Fold() end`, and the same for _Next, _Previous, PatchwerkForever_Thread_Routes_Go and _Stop, PatchwerkForever_Thread_Sparkle_Ignore and PatchwerkForever_Stitch_DungeonJournal_Route.

**Checked:** Quote confirmed in all seven Link.lua files; C_AddOns.GetAddOnMetadata is used by the client's own code (Blizzard_Minimap/Mainline/AddonCompartment.lua:105). Only arises when a part is updated and the base is not. Cut down: the reader's list of refused parts on the front page is a new mechanism, and raising P.API to 5 for Routes 0.16.0 is a release decision (see dropped). Size lowered from M to S, impact from medium to low.

### GP: dropped

- **Horizontal Offset and Vertical Offset sliders for the tracker's position (part of the Unlock Position finding):** New settings, so a feature and not polish; the drag bar and Reset Position already exist, and Place() keeps a dragged anchor that offsets would have to be reconciled with. The polish parts of that finding (empty tracker while unlocked, right-click to lock, the chat and bar text) are kept.
- **A P.Refused list shown on the front page and in /patchwerk for parts the base turned away (part of the version-mismatch finding):** A new mechanism in the base, not a refinement, and it can only help with mismatches against a future base. The clearer message and the guarded bindings are kept.
- **Raise P.API to 5 and Routes' api to 5 before 0.16.0 ships (part of the version-mismatch finding):** Not confirmed as roughness. The need is soft and already handled: on base 2.4.0 info.flyTo is nil and ns.FlightMissing(nil) returns false (Routes Flights.lua:103), so Routes falls back to its 0.15.0 behavior, and its changelog says 2.4.1 is needed 'for the guide part' only. Raising the number would make Routes refuse to run at all on base 2.4.0: a release decision, not polish.
- **Drop the 'Dungeon Journal: ' lead from the Dungeon Journal Stitch's three chat lines (part of the chat prefix finding):** Wrong as proposed. Every Stitch passes its own tag through P:Print ('Console Port', 'Route', 'MelloUI'); 'Dungeon Journal: ' is that Stitch's tag and the only one that already has a colon. The kept finding gives the other Stitch tags the colon instead.

## SM: Smoothness and quiet failure

### SM-1. A destination with no route is searched again every 10 seconds, and never says why

`addons/PatchwerkForever_Thread_Routes/Route.lua` line 342 (PatchwerkForever_Thread_Routes; smoothness; size M; impact high; needs a look in the game)

**Now:** `if GetTime() - lastPlan > 10 then ns.Plan(false) end` (Follow, run by the 1-second ticker whenever there is a destination and no route). Guide steps, quests and gathering nodes are set with announce = false (Sources.lua:390 `ns.SetDestination(map, x, y, false, false, source, more)`, Gather.lua:93), so `Fail(announce, why)` prints nothing and `Fresh(dest, route)` shows the step text with no route line. A search that throws runs `job = nil` / `ns.Print('Route search failed: ' .. tostring(err))` (lines 103-104) on every retry and never calls P.Forget(). A gathering run waits on such a node forever: Gather.lua:127 `if dest then return end`.

**Change:** All in Route.lua unless said. (1) Search: return a third value `true` from the `if not journey then` branch (lines 225-231), the only failure that costs a full search. (2) In ns.Plan's coroutine use `local route, why, dead = Search(...)`. When there is no route and `dead`: if `dest.failed` is nil, `announce` is false and ns.Get('notify') is on, ns.Print(why) once; then set `dest.failed = { map = map, x = px, y = py, at = GetTime(), wait = math.min(120, (dest.failed and dest.failed.wait or 10) * 2) }`. When a route is found set `dest.failed = nil`. Call `Fresh(dest, route, dead and 'No route found' or nil)`. (3) Fresh hands that note to ns.FloatRoute(dest, route, note); Float.lua:106 becomes `ns.FloatStep(lines, route and ns.Summary(route) or note)`, so the smaller line says 'No route found'. (4) Line 342: `local f = dest.failed; if f then if map ~= f.map or GetTime() - f.at > f.wait or (px - f.x) ^ 2 + (py - f.y) ^ 2 > 300 * 300 then ns.Plan(false) end elseif GetTime() - lastPlan > 10 then ns.Plan(false) end`. The cheap failures (no position, not standing on known ground) keep the 10-second retry. (5) In the runner's throw branch (lines 102-104) call P.Forget(), replace the ns.Print with `ns.Try('a route search', error, tostring(err), 0)` (said once, as line 130 already does for look-ahead searches), and set `failed` on ns.dest the same way so it backs off too. (6) Gather.lua line 127: `if dest then if dest.source == 'gather' and dest.failed and state.going then visited[state.going] = GetTime(); Go() end return end`.

**Checked:** Confirmed by reading: lastPlan is set when a search starts, a failed P.Route runs until its heap is empty (Planner.lua:416-477, best stays huge), and P.Journey then tries the boat chains; README line 129 lists places with no route today (the Great Lift, the Undercity's lifts). Only bites when a destination has no route. I replaced the reader's '50 yards or 60 seconds' gate: a running character covers 50 yards in about 7 seconds, so it would not have reduced anything; a doubling wait (20 s to 120 s) with a 300-yard or map-change override does. The chat line and the on-screen note are limited to the dear failure, because the cheap one ('not standing on ground the planner knows') happens in every building and heals itself. How long a failed search really takes needs timing in the game. Not in ROADMAP.md or V1.md (R2 there is adding the lifts, not this).

### SM-2. A timed quest flashes every second and keeps a faded tracker awake

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 363 (PatchwerkForever_Thread_Tracker; smoothness; size S; impact medium)

**Now:** `if seen[key] and seen[key] ~= words and not each.small then` / `changed = now` / `if ns.Get('flash') then block.glowAt = now end` (lines 363-366). Words() (lines 282-288) joins every line's text, and a timed quest carries Quests.lua:172 `lines[#lines + 1] = { text = 'Time left: ' .. Clock(quest.left), r = 1, g = quest.left < 60 and 0.3 or 0.8, b = 0.3 }`. Dungeon.lua:45 adds the same kind of line: `lines[#lines + 1] = { text = 'Time left: ' .. Clock(duration - elapsed), r = 1, g = 0.8, b = 0.3 }`.

**Change:** Add `clock = true` to the two 'Time left' lines (Quests.lua:172, Dungeon.lua:45). In Words() (Frame.lua:284) skip them: `if not line.clock then parts[#parts + 1] = ... end`. The clock still redraws each second; the glow and the wake-up from Fade When Not Hovered then happen only when the title or an objective changes.

**Checked:** Confirmed. A quest with `left` sets tick = true (Quests.lua:205), so the list is drawn every TICK = 1 s; the clock text differs at each draw, so glowAt is renewed every second against a GLOW of 0.9 s: the block pulses for as long as the timer runs. Flash On Progress defaults to on (Core.lua:69). Fade When Not Hovered defaults to off, so the 'never fades' half only shows for players who turned it on. C_QuestLog.GetTimeAllowed exists on this client (Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua:372). Timed quests are few, which is why this is medium and not high. I named the field `clock` rather than `quiet`, which is already a setting key and a file name here.

### SM-3. After it is moved, the tracker can grow from its middle or bottom

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 149 (PatchwerkForever_Thread_Tracker; layout; size S; impact medium; needs a look in the game)

**Now:** `local point, _, relative, x, y = frame:GetPoint(1)` / `if point then Saved().place = { point, relative, x, y } end` (lines 149-150, in OnDragStop after `frame:StopMovingOrSizing()`). Place() puts it back with `frame:SetPoint(place[1], UIParent, place[2] or place[1], place[3] or 0, place[4] or 0)` and Render() calls `frame:SetSize(width, tall)` (line 386) at every draw.

**Change:** Keep the horizontal half of the anchor the game chose and always pin the top edge. Add a local function Pin() and call it in OnDragStop in place of lines 149-150: `local point = frame:GetPoint(1); local side = point and (point:find('LEFT') and 'LEFT' or point:find('RIGHT') and 'RIGHT') or ''; local to = 'TOP' .. side; local ratio = UIParent:GetEffectiveScale() / frame:GetEffectiveScale(); local x = side == 'LEFT' and frame:GetLeft() or side == 'RIGHT' and (frame:GetRight() - UIParent:GetWidth() * ratio) or ((frame:GetLeft() + frame:GetRight()) / 2 - UIParent:GetWidth() * ratio / 2); local y = frame:GetTop() - UIParent:GetHeight() * ratio; frame:ClearAllPoints(); frame:SetPoint(to, UIParent, to, x, y); Saved().place = { to, to, x, y }`. In Render, after `frame:Show()` (line 394), call Pin() once when the saved place's point does not begin with 'TOP' and frame:GetTop() is not nil, so a place saved by an earlier version is put right without the player moving it again.

**Checked:** The quote is exact and nothing later re-anchors the frame, so a tracker dropped where the game picks LEFT, CENTER, RIGHT or a BOTTOM point resizes around that point each time its height changes; the default (TOPRIGHT) and any top-third drop are unaffected. That the game picks one of nine points after a drag is the engine's behaviour and is not in the UI source, so it needs a look in the game. I changed the reader's fix: anchoring TOPLEFT to UIParent's BOTTOMLEFT with screen-sized offsets would make the tracker jump across the screen when the Scale slider is moved (offsets are in the frame's own scale); keeping the nearest TOP point keeps the offsets small, as the default place has them, and keeps the saved format.

### SM-4. The same guide step is said on screen again each time its waypoint changes

`addons/PatchwerkForever_Thread_Routes/Sources.lua` line 390 (PatchwerkForever_Thread_Routes; feedback; size S; impact medium; needs a look in the game)

**Now:** `ns.SetDestination(map, x, y, false, false, source, more)`, and Route.lua:399 always makes the destination fresh: `local dest = { map = map, x = x, y = y, pin = pin, source = source, fresh = true }`, which shows the step text once the route is known (Fresh, Route.lua:183-188). Look() takes this path whenever the guide's place is more than SAME = 5 yards from the destination, also when the step and its words are unchanged.

**Change:** In Sources.lua keep `local shown = {}` (the guide step last said on screen). Just before line 390: `if guide and more then local words = table.concat(guide.words, '\n'); if shown.source == guide.source and shown.index == guide.index and shown.words == words then more.quiet = true else shown.source, shown.index, shown.words = guide.source, guide.index, words end end`. Set the same three fields where the words are said for a new step at the same place (lines 374-377). In Route.lua:399 use `fresh = not (more and more.quiet)`. ns.GoToSource (the Route To Pin, Guide Step Or Quest binding and /thread go) passes no `quiet`, so asking for it still says the step.

**Checked:** Confirmed in code: the place comes from RestedXP's arrow element (Guides/RestedXP.lua:127), which moves from one goto line of a step to the next while the step number and Guides.Words stay the same; each move is a new destination with fresh = true, so the same words come up for Duration seconds each time. RestedXP steps that cycle the arrow round several spots (a kill area) are common, so I raised the impact from low to medium; how often it shows needs watching in the game. I changed the test: the reader compared against ns.dest, but on arriving within 12 yards Follow calls ns.Stop(false) and ns.dest is nil by the time the next waypoint comes, so the commonest path would have been missed; remembering what was last said covers both. Comparing the words as well keeps the Dungeon Journal list working (its index is the same for every stop until a quest is turned in). I dropped the reader's second part (making the RestedXP reader remember the nearest place): a rare tie, and the reader is written to keep nothing between reads.

### SM-5. Quests swap rows back and forth when two are about as near as each other

`addons/PatchwerkForever_Thread_Tracker/Quests.lua` line 185 (PatchwerkForever_Thread_Tracker; smoothness; size S; impact low; needs a look in the game)

**Now:** `if a.yards ~= b.yards then return a.yards < b.yards end` in Nearer, used by every Sort Order except Default order (lines 211, 238, 247, 254). `yards = ns.QuestYards(id)` (line 107) is measured afresh at each draw, and `if ns.Get('distance') and #data.quests > 0 then tick = true end` (line 208) draws the list every second. Items.lua:119 has the same comparison for the quest item bar.

**Change:** Sort by a distance that only moves on a clear change, and keep showing the live one. In Places.lua add `local rank = {}` and `function ns.QuestRank(id) local yards = ns.QuestYards(id); if not yards then rank[id] = nil; return nil end; local kept = rank[id]; if not kept or math.abs(yards - kept) > math.max(15, kept * 0.15) then kept = yards; rank[id] = kept end; return kept end`. In Quests.lua ReadQuests add `rank = ns.QuestRank(id)` to each quest and have Nearer compare `a.rank` and `b.rank` where it compares `yards` today (still plain numbers, so table.sort stays safe). In Items.lua line 113 store `rank = ns.QuestRank(quest)` and compare it at lines 118-121. The note on each row keeps using `quest.yards`.

**Checked:** The code is as quoted; the default Sort Order (By zone) sorts each zone with Nearer and Show Distance defaults to on, so rows do change place the moment distances cross, and ns.questOrder (Route To Next Quest / Route To Previous Quest) and the first button of the quest item bar change with them. Sorting nearest first is the design; only the back-and-forth near a tie is rough, so I lowered the impact to low. Sources.lua:199-207 and Actions.lua:20 already hold on to a quest for this reason. Trade-off to accept: two rows can show distances up to about 15 yards or 15% out of order. I moved the kept value into Places.lua: in the reader's version it was only updated by ReadQuests, so the item bar would have read stale values whenever Show Quests is off. How often rows really swap needs a look in the game.

### SM-6. Look-ahead searches take the same 4 ms a frame as your own route, in combat too

`addons/PatchwerkForever_Thread_Routes/Route.lua` line 125 (PatchwerkForever_Thread_Routes; smoothness; size S; impact low; needs a look in the game)

**Now:** `P.deadline = debugprofilestop() + P.budget` for the searches that can wait, the same line as for your own route (line 100), with Planner.lua:27 `P.clock, P.budget, P.deadline = nil, 4, 0`. The runner's OnUpdate (lines 98-134) has no check for combat.

**Change:** In Route.lua add `local function Budget(ahead) local ms = ahead and 1.5 or math.min(4, 250 / math.max(GetFramerate(), 30)); if InCombatLockdown() then ms = ms / 2 end; return ms end`. Line 100 becomes `P.deadline = debugprofilestop() + Budget(false)` and line 125 `P.deadline = debugprofilestop() + Budget(true)`. Planner.lua is not changed (P.budget stays as the value for the tools that run it outside the game).

**Checked:** The code facts are confirmed: one budget for both kinds of search, spent every frame while any search is under way, in combat as well; Ahead.lua queues about one new leg per guide step with Upcoming Steps Shown at its default of 2. GetFramerate exists on this client (Blizzard_FramerateFrame). Whether the player can feel it is not confirmed: 4 ms only costs frame rate when the game's main thread is the limit, and short legs finish within a frame or two. I lowered the impact from medium to low for that reason; worth measuring with the frame rate shown while a long leg is being found.

### SM-7. If the quest list fails to draw, the default tracker stays hidden and nothing replaces it

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 315 (PatchwerkForever_Thread_Tracker; edge-case; size S; impact low)

**Now:** `local data = ns.Try('the ' .. section.id .. ' list', section.read)` then `if type(data) == 'table' and type(data.blocks) == 'table' and #data.blocks > 0 then` (lines 315-316). ns.Try returns nil for an error exactly as a section returns nil for nothing to show, and says the error once. Quiet.lua's `wanted` for ObjectiveTrackerFrame (lines 35-39) looks only at the settings: `if not (ns.Get('on') and ns.Get('quiet')) then return false end` / `if ns.Get('quietInstance') and InInstance() then return false end` / `return true`.

**Change:** In Render replace line 315 with `local ok, data = pcall(section.read); if not ok then ns.Try('the ' .. section.id .. ' list', error, tostring(data), 0); data = nil end` (said once, as today). For the section with id 'quests' keep `ns.questsBroken`: set it true on an error, and clear it only after the section has read without error for 10 seconds, so a passing error heals without a reload and an intermittent one does not flap. When it changes call ns.QuietSoon(); the first time in a session it becomes true, ns.Print('The quest list could not be shown. The default quest tracker is shown instead.'). In Quiet.lua add `if ns.questsBroken then return false end` as the first line of the ObjectiveTrackerFrame `wanted` function; Apply already waits for combat to end.

**Checked:** The mechanism is confirmed by reading: an error in a section's read is indistinguishable from an empty section, the section is skipped at every draw while the error lasts, and the default tracker stays at alpha 0 because `wanted` never learns of it. What is not confirmed is that any section throws today: every game call in Quests.lua goes through a pcall'd Ask. So this is insurance for a tracker that hides the game's own, and I lowered the impact from medium to low. I changed the fix: the reader's 'Type /reload to try again' would mislead when the error is tied to a quest's data (a reload would not help), and a flag that never clears would leave two trackers up after a one-off error.

### SM-8. README says each continent's map data loads only when you are there; the first route loads all three

`addons/PatchwerkForever_Thread_Routes/README.md` line 139 (PatchwerkForever_Thread_Routes; docs; size S; impact low)

**Now:** "- `PatchwerkForever_Thread_Routes_Kalimdor`, `_EasternKingdoms`, `_ZephrasIsle`: the map data, about 4 MB in all. Each is loaded only when you are on that continent." In the code, Journey.lua:34 runs `if use(a[1]) and use(b[1]) then` for every boat and zeppelin of your faction, and `use` is Route.lua:218 `use = function(m) return DATA[m] ~= nil and Data(m) end`, where Data() calls LoadAddOn.

**Change:** Change the last sentence of README.md line 139 to: "Each is loaded the first time a route needs it; with Use Boats And Zeppelins on (the default) that is all three, at your first route after login." tools/PLAN.md line 225 ("loaded only when the character is on that map") can take the same correction. No code change.

**Checked:** Confirmed: the Horde lines in Crossings.lua touch maps 0, 1 and 2991, so with Use Boats And Zeppelins on (default, Core.lua:36) Rides() loads all three load-on-demand data addons on the first search. The folders are 2.2 MB, 1.7 MB and 65 KB, so 'about 4 MB' is right. I kept only the doc fix. The reader's other option (loading inside the chain loop of P.Journey) is a few hours' work in a file the offline tools also run, to save one load at the first route and about 4 MB; not worth it as polish. The repository README's 'loaded on demand' is already true.

### SM-9. ns.Try reports one error per label, and many handlers share a label

`addons/PatchwerkForever/Tools.lua` line 81 (PatchwerkForever; feedback; size S; impact low)

**Now:** `if not reported[label] then` / `reported[label] = true;` / `env.Print('a problem in ' .. label .. ' (reported once): ' .. tostring(a))` (lines 81-83). The label is shared: every handler of a game event runs as `env.Try(event, fn, ...)` (line 153), every settings watcher as `env.Try('a setting', fn, key, value)` (line 128), the map and minimap listeners as `ns.Try('drawing', fn)` (Thread_Routes/Route.lua:31). The base's Gather.lua:37 has one flag for four calls: `local reported = false;`.

**Change:** In env.Try key the table by the label and the message, with a cap per label: `local key = label .. '\n' .. tostring(a); local said = counts[label] or 0; if not reported[key] and said < 3 then reported[key] = true; counts[label] = said + 1; env.Print(...) end` (add `local counts = {}` beside `reported`; the chat line stays as it is). In addons/PatchwerkForever/Gather.lua make `reported` a table keyed by `what`, so a failed Start is still said after a failed Near.

**Checked:** Confirmed: after the first message under a label, a different error under the same label is never shown. Four Tracker files listen for QUEST_LOG_UPDATE (Frame, Quiet, Places, Party), so the first to fail hides the other three for the session. A player only meets this when something is already broken, so low is honest. I added the cap of three per label so a message that carries a changing value cannot fill the chat. I left out the reader's second part (xpcall with CallErrorHandler): both exist on this client (Blizzard_SharedXMLBase/ErrorUtil.lua, FunctionUtil.lua), but handing every caught error to the game's error handler changes what ns.Try is documented to do ('an error is said once, not thrown').

### SM-10. The minimap trail and node icons are redrawn 20 times a second, and lag a turning minimap

`addons/PatchwerkForever_Thread_Routes/Minimap.lua` line 196 (PatchwerkForever_Thread_Routes; smoothness; size M; impact low; needs a look in the game)

**Now:** `ticker = C_Timer.NewTicker(EVERY, function() ns.Try('the minimap trail', Draw) end)` with `local EVERY = 0.05` (line 13); Nodes.lua:214 starts the same for the node icons: `ticker = C_Timer.NewTicker(MINI_EVERY, function()` with MINI_EVERY = 0.05. Each tick ns.MinimapView runs `frame:ClearAllPoints()` / `frame:SetAllPoints(Minimap)` / `frame:SetFrameStrata(Minimap:GetFrameStrata())` / `frame:SetFrameLevel(Minimap:GetFrameLevel() + above)` / `frame:Show()` (lines 54-58), and Trail() begins with `Clear()` and places every line again.

**Change:** (1) In ns.MinimapView anchor a layer once (keep a flag on the frame) and call SetFrameStrata and SetFrameLevel only when the Minimap's values differ from the last ones kept on the frame. (2) In Trail() (Minimap.lua) and MiniDraw() (Nodes.lua) call ns.MinimapView first and, before clearing anything, compare with values kept from the last draw: position rounded to 0.5 yard, sin and cos, perYard, radius, the `ns.route` table and `route.at`, the `ns.ahead` table, and a counter raised by ns.OnSetting; when all are equal and ns.TrailMoves() is false, return the last result without redrawing. (3) With that in place, drive both from one OnUpdate frame in place of the two tickers, so a turning minimap (Rotate Minimap) is followed every frame and a still one costs a few comparisons. (4) In MiniDraw return nil before ns.MinimapView when `buckets[map]` is nil for the map ns.Place() gives, so maps with no recorded nodes (instances) do no work.

**Checked:** The code is as quoted; the Nodes ticker starts at PLAYER_LOGIN and stays for the session once any node is recorded and Show Nodes On Minimap is on (Nodes.lua:212). For a player whose minimap does not turn this is not visible: the work per tick is small. The part a player can see is with Rotate Minimap on, where the layers step at 20 Hz behind a minimap that turns every frame; whether this player uses it is unknown, so the impact stays low and it ranks last. I dropped the reader's step of moving the four closures to file level: once unchanged draws are skipped it buys nothing. I also changed the comparison from a built string to kept values, so the check itself makes no garbage. C_Minimap.GetViewRadius and the rotateMinimap setting exist on this client.

### SM: dropped

- **A selected guide list is read in full about a dozen times a second:** The count is roughly right (Choice.lua:32 reads the guide in Stands(); with a Dungeon Journal list selected I count about ten reads a second across Routes' Look and the tracker's draw), but nothing of it reaches the player: the finding itself says none of it is visible, a read is a few dozen pcall'd quest calls and map lookups, and with RestedXP alone it is four small reads a second. It is an unseen optimization, not polish, and ROADMAP.md already holds this class of tracker work as T8 ('Redraw only what changed, not the whole list each second ... only if it shows in play').

## DL: Documents and listings

### DL-1. "Needs a newer Patchwerk Forever" names the folder and no version

`addons/PatchwerkForever_Thread_Tracker/Link.lua` line 20 (PatchwerkForever_Thread_Tracker; wording; size S; impact medium)

**Now:** print('|cffd6a35bPatchwerk|r ' .. ADDON .. ' needs a newer Patchwerk Forever (the base addon). It is not running.')

ADDON is the folder name, so the chat line reads "Patchwerk PatchwerkForever_Thread_Tracker needs a newer Patchwerk Forever (the base addon). It is not running." The same line is at addons/PatchwerkForever_Thread_Routes/Link.lua:18 and addons/PatchwerkForever_Thread_Sparkle/Link.lua:18, and at line 16 of Link.lua in all four Stitches (with addonName). The version needed is only in the changelogs ("Needs **Patchwerk Forever 2.4.0** or later"); no README gives it.

**Change:** In each of the seven Link.lua files add one constant beside the api number: the oldest base that carries that api (from the base CHANGELOG: api 1 = 2.0.0, 2 = 2.1.0, 3 = 2.2.0, 4 = 2.4.0). So NEEDS = '2.4.0' in Tracker, Routes and Dungeon Journal (Stitch) (api 4), and '2.0.0' in Sparkle and the three api-1 Stitches. Print the addon's title in gold instead of the folder name, and drop the separate "Patchwerk" prefix (the title already begins with "Patchwerk Forever", so keeping the prefix would read "Patchwerk Patchwerk Forever: ..."):

local title = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, 'Title')) or ADDON
print(('|cffd6a35b%s|r needs Patchwerk Forever %s or later and is not running. Update Patchwerk Forever.'):format(title, NEEDS))

(addonName in place of ADDON in the Stitches.) Keep the three api-1 Stitch files byte-identical, because tools/lua_patchwerk.py line 675 asserts that; change its assertion at line 352 from "needs a newer Patchwerk Forever" to "needs Patchwerk Forever 2.0.0 or later". Add "2.4.0 or later" to the "It needs Patchwerk Forever" sentence of the Tracker, Routes and Dungeon Journal READMEs. In the root README.md, line 98 (raising api) gains "and NEEDS beside it", and line 31 ("`Link.lua` is the same file in every Stitch") becomes "the same but for its api number and NEEDS" (the Dungeon Journal's already differs: API = 4). While there, fix the stale comment at Tracker/Link.lua:13, which says "(3: ...)" beside api = 4.

**Checked:** All seven lines read as quoted. The gate is P:Link / P:Tool comparing api with P.API (Core.lua:259, Tools.lua:64), and P.API = 4 since base 2.4.0 per the base CHANGELOG, so the version mapping is right. It does happen: release.py's ORDER uploads the parts before the base, and a 1.x base has no Link or Tool at all. C_AddOns.GetAddOnMetadata and GetAddOnTitle are both in this client's AddOnsDocumentation.lua (lines 165, 241). Corrected the proposal: the original kept the "Patchwerk" prefix before the title (doubled word) and missed the two assertions in tools/lua_patchwerk.py that the new text would break.

### DL-2. The base's addon-list tooltip and listing leave out Tracker and Dungeon Journal

`addons/PatchwerkForever/PatchwerkForever.toc` line 3 (PatchwerkForever; docs; size S; impact medium)

**Now:** \## Notes: The base of the Patchwerk Forever addons: their shared settings pages, saved data and /patchwerk. It does nothing by itself; add Stitch (fixes for Console Port and MelloUI) and Thread (our own tools: Routes, Sparkle).

Also addons/PatchwerkForever/README.md (copied whole as the base's CurseForge description): the Thread table at lines 40-43 has two rows, Routes and Sparkle; line 66 "The Thread tools have commands of their own (`/thread`, `/sparkle`)."; line 55 "The base tells you once, in chat, when Console Port or MelloUI is running and the Stitch for it is not installed."

**Change:** TOC line 3: end the Notes in the form the CurseForge summary in tools/release.py (lines 61-63) already uses, which names no addon and so cannot go stale: "...It does nothing by itself; add Stitch addons (fixes for other addons) and Thread addons (our own tools)." README.md: add a row to the Thread table after Routes: "| **Patchwerk Forever: Tracker (Thread)** | A quest tracker: your quests by zone with distances, your guide's steps, quest item buttons, tracked recipes and a gathering list. |"; line 66 becomes "(`/thread`, `/tracker`, `/sparkle`)"; line 55 becomes "when Console Port, MelloUI or DungeonJournal is running". To stop it recurring: in tools/release.py build(), for the key "patchwerk", add a problem line when the TOC Title of any other PROJECTS entry is not found in the base README.

**Checked:** TOC line and README lines 40-43, 55 and 66 read as quoted. Core.lua:44 has the Dungeon Journal in P.Family and TellMissing (Core.lua:310-320) tells for it; the base CHANGELOG 2.4.0 says so too. Tracker's command is /tracker (its Link.lua:18). Every other project's TOC Title appears in the base README in bold except Tracker's, so the proposed check would catch exactly this. Corrected: the original Notes still listed "Routes, Tracker, Sparkle", which would go stale again. Impact lowered from high: it is an omission in a listing and one tooltip, nothing broken.

### DL-3. Tracker README still says 1.0, and its binding text sits in the wrong section

`addons/PatchwerkForever_Thread_Tracker/README.md` line 21 (PatchwerkForever_Thread_Tracker; docs; size S; impact medium)

**Now:** Line 21: "Version 1.0. One piece is marked experimental and starts switched off: dungeon objectives, which depend on what Forever's dungeons report." (the TOC is "## Version: 1.1.0"; the root README.md line 23 also says "1.0.").

Line 56, under the heading "## Item buttons": "- **Without a mouse**: bind "Route To Next Quest" and "Route To Previous Quest" (Key Bindings, under AddOns) to step through the list; one step past either end returns to your main route."

Line 80: "- **Fold it** by clicking a heading, with `/tracker fold`, or with a key or gamepad button you bind." (the binding is 'Collapse / Expand Tracker', Core.lua line 187; the README never names it).

Line 25: the first bullet of "## What it lists" is the Dungeon Journal list, which needs a separate Stitch, ahead of the guide and the quests.

**Change:** Line 21: drop "Version 1.0." so the paragraph begins "One piece is marked experimental..." (the TOC and changelog carry the version); in the root README.md line 23 delete "1.0. ". Move line 56 out of "## Item buttons" into a new section "## Key bindings" placed before "## Settings", listing all four by the names the game shows: Collapse / Expand Tracker, Route To Next Quest, Route To Previous Quest, Use Nearest Quest Item, with the one sentence on where to bind them (Options → Keybindings → AddOns, or Console Port's binding list); line 57 keeps its note that the binding only ever uses a quest's item and may point to the new section. Move the Dungeon Journal bullet (line 25) to just after "Your guide's steps" (line 26), where its section sits in the tracker, so the list opens with what every player sees.

**Checked:** All four quotes confirmed. TOC is 1.1.0 and CHANGELOG.md has a 1.1.0 entry. The four binding names are at Core.lua lines 187-190 and Bindings.xml has all four. "Collapse" does not occur anywhere in the README. Changed where the Dungeon Journal bullet goes (after the guide, not last). This is accuracy, not the re-voicing listed as ROADMAP A1; it can go in the same pass.

### DL-4. Routes changelog is out of order and has no title line

`addons/PatchwerkForever_Thread_Routes/CHANGELOG.md` line 1 (PatchwerkForever_Thread_Routes; docs; size S; impact low)

**Now:** Line 1 is "## 0.14.0 (beta)"; there is no "# Patchwerk Forever: Routes (Thread)" heading, which the other seven CHANGELOG.md files have. The entries run 0.14.0 (line 1), 0.16.0 (line 18), 0.15.0 (line 28), 0.13.0 (line 33), 0.12.0, 0.11.0, 0.10.0, 0.9.0. The file ships in the zip and is copied whole to CurseForge-changelog.md.

**Change:** Add "# Patchwerk Forever: Routes (Thread)" and a blank line at the top, and move the 0.14.0 block (lines 1-17) to between the 0.15.0 and 0.13.0 entries, giving 0.16.0, 0.15.0, 0.14.0, 0.13.0 ... In tools/release.py build(), beside the check at line 291 ("CHANGELOG.md has no entry for"), also report a problem when the first line of CHANGELOG.md is not "# " + the TOC Title, or when the first "## " heading does not begin with "## " + the TOC version.

**Checked:** Confirmed by reading the file and listing its headings. tools/upload.py changelog() (line 107) picks the entry by version with a regex, so an upload made with the tool sends the right text; the roughness is for someone opening the file in the zip, or pasting from CurseForge-changelog.md by hand. The other seven changelogs already pass both proposed checks. Impact lowered to low.

### DL-5. British spelling and a non-standard noun in text the game shows

`addons/PatchwerkForever_Thread_Tracker/PatchwerkForever_Thread_Tracker.toc` line 3 (PatchwerkForever_Thread_Tracker; wording; size S; impact low)

**Now:** Tracker TOC line 3 (the addon list tooltip): "...tracked recipes and a gathering list, in a list you can move, size and colour. Needs Patchwerk Forever. Type /tracker."
Tracker Core.lua line 127 (a setting's tooltip): "Color quest names by difficulty (grey, green, yellow, orange, red)."
Routes TOC line 3: "...Also remembers herb and ore spots." (every setting and chat line of Routes says nodes: 'Record Gathering Nodes', 'Show Nodes On Minimap', '/thread nodes').
Dungeon Journal Reader.lua line 54 (a setting's tooltip): "Make the Dungeon Journal list the main route, ahead of your levelling guide, whenever it has somewhere to send you." (the same addon's TOC spells its category "Quests & Leveling").

**Change:** Tracker TOC line 3: "...in a list you can move, resize and color." Tracker Core.lua line 127: "(gray, green, yellow, orange, red)". Routes TOC line 3: "Also records herb and ore nodes." Reader.lua line 54: "leveling guide". No behavior changes. One more for the owner to settle: the Dungeon Journal TOC line 3 writes the other addon as "DungeonJournal" while the same addon's settings, chat lines and the base's chat line write "Dungeon Journal"; use in both whichever form the journal shows as its own title in the addon list.

**Checked:** All quotes confirmed. A search of the name/desc/Print strings in the addons' Lua for British spellings found only Reader.lua:54 and one the first reader missed, "grey" at Tracker Core.lua:127 (added). No tool or test asserts on these texts. Reader.lua:54 is a concrete case of ROADMAP A5 (the Stitches' settings read through). Cut the proposed "Dungeon Journal (ForeverDungeonJournal)" rewrite down to a note: the journal's own title could not be checked from the two folders allowed.

### DL-6. Dungeon Journal (Stitch) says it needs DungeonJournal but its TOC makes it optional

`addons/PatchwerkForever_Stitch_DungeonJournal/PatchwerkForever_Stitch_DungeonJournal.toc` line 11 (PatchwerkForever_Stitch_DungeonJournal; consistency; size S; impact low)

**Now:** \## Dependencies: PatchwerkForever
\## OptionalDeps: ForeverDungeonJournal

while line 3 says "Needs Patchwerk Forever and DungeonJournal" and README.md line 19 says "**It needs two addons:** DungeonJournal itself, and **Patchwerk Forever**, the base." The other three Stitches list their addon under Dependencies ("## Dependencies: PatchwerkForever, ConsolePort"). As written, without the journal this Stitch still loads, gets a "Dungeon Journal (Stitch)" options page with two settings that do nothing, and /patchwerk lists its fix as "waiting: Dungeon Journal is not loaded"; the addon list shows no missing dependency.

**Change:** Make it match the other Stitches: "## Dependencies: PatchwerkForever, ForeverDungeonJournal" and remove the OptionalDeps line. Reader.lua needs no change (it reads the journal lazily on every call), and the base's P.Family already uses 'ForeverDungeonJournal' as the folder name. Before doing it, open the journal's own TOC once: if it is LoadOnDemand, a hard dependency would load it at login by itself, and then keep the optional link and instead change TOC line 3 and README line 19 from "Needs ... DungeonJournal" to "For DungeonJournal; without it this addon does nothing". In tools/release.py add a check beside the "requires" one (line 280): a project with a "with" entry must name a second addon in Dependencies.

**Checked:** TOC lines 3, 11, 12 and README line 19 read as quoted. Reader.lua adds both settings and registers the fix unconditionally (lines 41-55, 286-295), so the dead page is real for someone without the journal. The root README (line 10) states the family rule: a Stitch needs the base and the addon it is for. Nothing in the repository says the optional link was deliberate. Added the LoadOnDemand caution, which could not be checked from here. Impact lowered to low: it only shows for a player who installs the Stitch without the journal, which is not this player.

### DL-7. Where to bind is written two ways, by description instead of by name; one options path and the trail styles are off

`addons/PatchwerkForever_Thread_Routes/README.md` line 121 (PatchwerkForever_Thread_Routes; docs; size S; impact low)

**Now:** Routes README line 121: "Two actions can be bound to a key or a gamepad button (Options → Keybindings → AddOns, or Console Port's binding list): route now, and stop routing." (in the game they are 'Route To Pin, Guide Step Or Quest' and 'Stop Routing').
Sparkle README line 49: "One action can be bound to a key or a gamepad button (Options → Keybindings → AddOns, or Console Port's binding list): never sparkle on this thing again." (in the game: 'Ignore Targeted Object').
Tracker README lines 56-57 and Dungeon Journal README line 45: "(Key Bindings, under AddOns)", with no mention of Console Port.
Tracker README line 87: "**Options, AddOns, Patchwerk Forever**, or `/tracker config`:" (every other README writes "Options → AddOns → Patchwerk Forever").
Routes README line 103: "The trail's colours, thickness and style (solid, dashes, dots, flowing) are on **Routes: Trail**" (the Line Style setting offers Solid, Dashed, Dotted; movement is the separate tick box Animate Line).

**Change:** Use one sentence in the Routes, Sparkle and Dungeon Journal READMEs (the Tracker's is covered by its own finding), with the names exactly as the game shows them: "Bind these under Options → Keybindings → AddOns, or in Console Port's binding list: <names>." Routes: Route To Pin, Guide Step Or Quest; Stop Routing. Sparkle: Ignore Targeted Object. Dungeon Journal: Route Through Dungeon Journal Quests. Do not add the addon's title as a further level: on this client the Keybindings page puts every category="ADDONS" binding in one "AddOns" section and draws a binding header as a blank gap, not as text. Tracker README line 87: "**Options → AddOns → Patchwerk Forever**". Routes README line 103: "style (solid, dashed or dotted, animated if you like)". Leave the chat fallbacks ("Options > AddOns > ...") as they are: plain ">" is right for a chat line.

**Checked:** All quotes confirmed; binding names are in Routes Core.lua:159-160, Sparkle Core.lua:149, Reader.lua:267; Line Style choices and Animate Line are at Routes Core.lua:57-62. Corrected the proposal: the first reader's path ended "→ AddOns → <the addon's title>", but forever-src Blizzard_SettingsDefinitions_Frame/Keybindings.lua (lines 53, 251-252) renders a HEADER inside a category as a spacer with no text. "Four ways" was overstated: the binding path has two forms, the options path one outlier. The exact word on the Options page ("Keybindings") is a global string that is not in the source dump, and the Console Port clause already stands in two READMEs; both are worth one look in the game but do not hold the edit up.

### DL-8. New pieces not yet tried in the game are listed as finished

`addons/PatchwerkForever_Stitch_DungeonJournal/README.md` line 47 (PatchwerkForever_Stitch_DungeonJournal; docs; size S; impact low)

**Now:** The Dungeon Journal Stitch's README section "## What it does not do" (line 47) lists three limits and none says it has only been run against a stand-in; its CHANGELOG.md line 5 says "The first release." and release.py (line 401) marks 1.0.0 as a full Release. ROADMAP.md line 86: "Passes the checks against a stand-in journal; not yet tried in the game with the real one."

Tracker CHANGELOG.md line 11: "The first full release. Everything in 0.9.0 has been played and works." while ROADMAP.md T6 is still open: "Party progress between two trackers, seen working | S | a second player running it".

Routes README line 23: "**This is a beta.** It has been played on a Horde character in Kalimdor." and the section "## Flight points you know" (lines 47-55) has no caveat; ROADMAP.md line 92: "Not yet tried in the game: what Forever's flight map reports for points you do not have is what it stands on."

**Change:** Only if any of these is uploaded before it has been played; remove each line once it has. Dungeon Journal README: add a first bullet under "## What it does not do": "It is new: so far it has passed its checks against a stand-in for the journal and has not been tried with the real one. Please report what it gets wrong.", and the same sentence after "The first release." in its CHANGELOG.md line 5. Tracker CHANGELOG.md line 11: "Everything in 0.9.0 has been played and works, except party progress between two trackers, which needs a second player to try." Routes README line 23: append "Reading your flight points from the flight map (0.16.0) and following the Dungeon Journal's list (0.15.0) are new and have not been played yet." Whether the Stitch's first upload should instead be numbered 0.9.0 (release.py then marks it Beta) is the owner's call.

**Checked:** Every quote confirmed, and tools/PLAN-tracker.md line 467 says the same of the Stitch ("Not seen in the game: any of it with the real journal"). Cut down from the first reader's version: no new "Not yet tried in the game" section in three READMEs, since Routes already carries a beta banner and the Tracker README already marks dungeon objectives "Untried" (line 33) and experimental (line 21). Left the Tracker README's "works with no other addon installed" alone: that is what its TOC and tools/lua_tracker.py establish, and the play check is ROADMAP A3. The trying itself is already on the roadmap; this is only what the listings say meanwhile. Impact lowered to low.

### DL-9. READMEs ask for reports but never say where to send them

`addons/PatchwerkForever/README.md` line 68 (PatchwerkForever; docs; size S; impact low)

**Now:** **Reporting a problem:** if something misbehaves, the chat line it prints ("… failed and was skipped", "a problem in …") is what to report.

Also line 34 of the same file "please report it"; Routes README line 23 "Please report what goes wrong." and line 126 "please report it"; Console Port README line 42 "please report it. If something misbehaves, the chat line it prints is what to report." None names a place, and the Tracker, Sparkle, Dungeon Journal, MelloUI and MelloUI Route READMEs have no reporting line at all.

**Change:** Give all eight READMEs the same one line, just above "## Credits": "**Reporting a problem:** leave a comment on this addon's CurseForge page with the chat line it printed, the versions `/patchwerk` lists, and what you were doing." (swap in the repository's issues address once it is on GitHub). In the base README, replace line 68 with it and keep the two example chat lines in brackets. The loose "please report it" phrases can stay as they are once the line exists on the same page.

**Checked:** Quotes confirmed; a search of every README for "report" finds only these, and no README gives an address of its own. The two example chat lines do exist (Tools.lua:83, Guides.lua:75, Gather.lua:44), and /patchwerk does list versions (Core.lua ListParts). Simplified from a new section in each README to one line. Corrected the list of READMEs with no reporting line: MelloUI and MelloUI Route have none either.

### DL-10. Repository docs describe the family before Tracker and Dungeon Journal

`README.md` line 52 (repo; docs; size S; impact low)

**Now:** README.md line 52: "builds every addon into the game's AddOns folder (`patchwerk`, `consoleport`, `melloui`, `melloroute`, `routes` or `sparkle` for one)" (tools/build.py line 4 also takes dungeonjournal and tracker).
Line 80: "`python lua_shell.py` | runs the base with both Thread tools through a pretend play session..." (there are three Thread tools now; it loads Routes and Sparkle).
Line 101: "Tag the commit: `patchwerk-forever-2.0.0`, `stitch-consoleport-2.0.0`, `stitch-melloui-2.0.0`, `stitch-melloroute-2.0.0`, `thread-routes-0.11.0`, `thread-sparkle-0.11.0`." (release.py TAGS also has thread-tracker and stitch-dungeonjournal).
Line 31: "`Link.lua` is the same file in every Stitch." (the Dungeon Journal's has API = 4, the others API = 1).
art/README.md line 12: "The addon folders are `PatchwerkForever`, `PatchwerkForever_Stitch_ConsolePort`, `PatchwerkForever_Stitch_MelloUI`, `PatchwerkForever_Stitch_MelloUIRoute`, `PatchwerkForever_Thread_Routes` and `PatchwerkForever_Thread_Sparkle`."
tools/release.py line 379 writes into release/UPLOAD.md: "**The order matters.** Patchwerk Forever 2.0.0 does nothing by itself, and people who have 1.x get it as" (the base is 2.4.1).

**Change:** README.md line 52: add `dungeonjournal` and `tracker` to the list. Line 80: "runs the base with Routes (Thread) and Sparkle (Thread)". Line 101: replace the list with "the tag for each project is in `release/UPLOAD.md`" (it is generated from TAGS and the TOC versions). Line 31: "the same file in every Stitch but for its api number". art/README.md line 12: "any folder under `addons/`". tools/release.py line 379: "Patchwerk Forever (from 2.0.0) does nothing by itself", and add one sentence to the same header paragraph: "Until the base's update is up, a part installed beside a 1.x base says it needs a newer Patchwerk Forever and does not run; upload the base in the same sitting."

**Checked:** Every quote confirmed against README.md, art/README.md, tools/build.py, tools/lua_shell.py (lines 25-26 load Routes and Sparkle) and tools/release.py (TAGS at 368-370, text at 379). Added README line 31, which the first reader did not list. Dropped the proposed per-project "Needs base" value in the generated checklist as new tooling; one sentence in the header says the same. Nothing here reaches a player; it is for whoever builds and uploads.

### DL: dropped

- **The owner's first name and verbatim messages are in tracked documents:** Not polish. The facts are as reported (V1.md lines 3 and 9 and ROADMAP.md line 3 name him and quote his messages; all 11 TOCs carry the same "## Author" line, and tools/pack.py line 191 writes it), but nothing here is a rough edge a player meets, and the author line on the shipped files is the owner's own choice. Whether the plan documents should carry his name and quoted messages once the repository is public is a privacy decision for him to make before it goes to GitHub, not a defect to fix in a polish pass. The proposed extension of the private-word check to tracked Markdown outside addons/ is new tooling rather than polish.

## GA: What the eleven angles missed

### GA-1. In an instance both trackers are shown with the default settings

`addons/PatchwerkForever_Thread_Tracker/Frame.lua` line 302 (PatchwerkForever_Thread_Tracker; defaults; size S; impact high; needs a look in the game)

**Now:** Frame.lua:302 `if not ns.Get('on') or (ns.Get('hideInstance') and IsInInstance and IsInInstance()) then` hides ours only for Hide In Instances, off by default (Core.lua:44 `{ key = 'hideInstance', default = false, name = 'Hide In Instances',`). Quiet.lua:37 `if ns.Get('quietInstance') and InInstance() then return false end` lets the default tracker back, on by default (Core.lua:25 `{ key = 'quietInstance', default = true, name = 'Keep Default Tracker In Instances', parent = 'quiet',`). Ours stands at Frame.lua:111 `frame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -40, -260)       -- under the minimap, where the game's is`. So with defaults every dungeon, raid and battleground shows two quest lists.

**Change:** Let ours step aside while the default tracker is let back. In Frame.lua add `function ns.AsideInInstance() return (IsInInstance and IsInInstance() and (ns.Get('hideInstance') or (ns.Get('quiet') and ns.Get('quietInstance')))) and true or false end` and use it on line 302 in place of the hideInstance test. Use the same function at Quiet.lua:42 in place of `ns.Get('hideInstance') and InInstance()`, so RestedXP's window comes back whenever ours is hidden. Nothing else is needed for redraw: Frame.lua:513 already refreshes on every setting, and ZONE_CHANGED_NEW_AREA and PLAYER_ENTERING_WORLD are listened for. Tooltips in Core.lua: line 26 -> 'In dungeons, raids and battlegrounds, show the default tracker in place of this one. It displays stage objectives, timers and scores there.'; line 45 -> 'Hide the tracker in dungeons, raids and battlegrounds, even when the default tracker is not kept there.' README line 75: add that this tracker steps aside while the default one is let back. Tests in tools/lua_tracker.py: the assertion at line 1078 (`assert s.shown() is not None, "it hides in a dungeon unasked"`) must change to expect nil with defaults; add: with quietInstance off ours is shown and ns.Quiet() is true; with quiet off ours stays shown. If POLISH E5 (TL-8) is built, its 'do not hide while unlocked' exception applies to this test too.

**Checked:** All four quotes exact. Traced: with on, quiet and quietInstance at their defaults, Quiet.lua's wanted() returns false in an instance and Render() does not hide, so both lists are up; no guard elsewhere. Not in ROADMAP, V1 or the audit (TI-10 covers only the half second after a loading screen). Two cautions: (1) this reverses a deliberate check (lua_tracker.py:1078) and his interview choice that hiding in dungeons starts off (PLAN-tracker.md:191), so it needs his yes; the alternative is to leave both and only say so in the tooltip. (2) Whether they overlap depends on where the default tracker stands under EllesmereUI; the double listing itself is certain. Use Nearest Quest Item keeps working with ours hidden (Items.lua:203-206 set the bound button whether or not the bar is shown), and line 114's tooltip already says to disable the keep option to see dungeon objectives.

### GA-2. Routes names a zeppelin or boat stop "a landing"

`addons/PatchwerkForever_Thread_Routes/Crossings.lua` line 106 (PatchwerkForever_Thread_Routes; wording; size S; impact medium)

**Now:** Crossings.lua:106 `{ 2991, "a landing", 1848.3, 569.1, 3957, 3649, 22 },` and :116 `{ 2991, "a landing", 1952.5, 1019.1, 3856, 3616, 7 },` (both Horde zeppelins to Zephras Isle); :71 "a landing near Feathermoon", :95 "a landing near Gadgetzan", :105 "a landing near Undercity", :126 "a landing near Stormwind". They come from tools/crossings.py:146 `s["name"] = near[0][1].split(",")[0] if near[0][0] <= NAMED else "a landing near " + near[0][1].split(",")[0]` and :148 `s["name"] = "a landing"`, are carried by Journey.lua:170 `out.rides[#out.rides + 1] = { kind = leg.crossing.kind, from = a[2], to = b[2] }` and printed by Route.lua:156 `parts[#parts + 1] = ('%s %s > %s'):format(ride.kind, ride.from, ride.to)`. So the summary reads 'zeppelin Thunder Bluff > a landing'.

**Change:** Fix it in the generator and make the data again (Crossings.lua says 'Do not edit: run pack.py again'). In tools/crossings.py: (1) add `MAP_NAMES = {0: "Eastern Kingdoms", 1: "Kalimdor", 2991: "Zephras Isle"}` and use `MAP_NAMES.get(s["map"], "a landing")` on line 148, giving 'zeppelin Thunder Bluff > Zephras Isle'; (2) on line 146 write `"near " + name` in place of `"a landing near " + name`, giving 'boat near Gadgetzan > Powderfuse Port' and 'zeppelin near Undercity > Zephras Isle'; (3) add an optional hand table `NAMES = {(line id, stop index): "name"}`, read first, so a stop gets its real name once it has been seen in the game (the Alliance line 303 would otherwise read 'boat Feathermoon > near Feathermoon'). Run `python crossings.py` (it reads the game's data files) then `python pack.py crossings`, and add a check to tools/lua_journeys.py that fails if any stop name begins with 'a landing'.

**Checked:** All quotes exact, in Crossings.lua, crossings.py and Route.lua; the name reaches the summary through Journey.lua:170 with nothing in between. The two bare 'a landing' stops are on the only Horde lines to Zephras Isle (ids 11398 and 11457), so this player sees it on every route there, under the step text and in chat. 'Zephras Isle' is the repository's spelling (the data addon's title). No real stop names can be read from either folder, so the hand table stays empty until he supplies them; none were invented here. ROADMAP R3 is about whether lines run, not their names.

### GA-3. Selecting a quest can leave the route unchanged, and nothing says so

`addons/PatchwerkForever_Thread_Routes/Sources.lua` line 276 (PatchwerkForever_Thread_Routes; feedback; size S; impact low)

**Now:** (1) A selected quest with no place Routes can go to: Sources.lua:271-277 `if pick.map then` ... `return 'quest', pick.map, pick.x, pick.y, true` / `end` / `-- (the game gives it no place you can go to: the main track keeps the say)`. (2) A map pin or /thread to spot is active: Look() returns before it reads the selection, Sources.lua:327-330 `if dest and not dest.source then                         -- your own pin or spot comes first` / `ns.Ahead.Set({})` / `return`. In both the Tracker has already marked the quest (Actions.lua:98 `if pick then return pick.kind == 'quest' and pick.id or nil end`) and, from the bindings, printed Actions.lua:86 `ns.Print('Routing to: ' .. tostring(Ask(C_QuestLog.GetTitleForQuestID, order[to]) or order[to]))`, while the trail keeps leading to the guide step or the pin.

**Change:** Have Routes say it, in Sources.lua only, with two file-locals `toldPick` and `toldPin`. (1) Add `pick.since = pick.since or now` beside `pick.at = now` (line 268). In Look(), right after `local source, map, x, y, picked = Target()` (line 339): `local id = Picked()`; when id is set, `picked ~= true`, `pick.since` is more than 2 seconds old and `toldPick ~= id`, set `toldPick = id` and print one line: when `QuestPlaces(id)` gives a place, ('"%s" is on another continent that routes cannot reach from here. Your main route continues.'):format(Title(id)); otherwise ('"%s" has no location on the map, so it cannot be routed to. Your main route continues.'). Set `toldPick = nil` when Picked() is nil or picked is true. (2) In the early return on line 327: when `ns.Base.Choice and ns.Base.Choice:Get()` is set and `toldPin ~= dest`, set `toldPin = dest` and print, for `dest.pin`, 'Your map pin comes first. The quest you selected is routed to once you arrive or remove the pin.', otherwise 'The location you gave comes first. The quest you selected is routed to once you arrive or stop routing.' (say 'The list you selected' when the choice's kind is 'guide'). Once per pin, not per selection, so stepping through quests with Route To Next Quest does not repeat it. No change in the Tracker. Add both cases to tools/lua_shell.py.

**Checked:** Both quotes exact and both paths traced: Target() falls through to the main track with no word when QuestSpot gives nothing, and Look() never reaches Target() while an own destination stands. Corrected the proposal: QuestSpot also gives nothing for a quest on a continent that cannot be crossed to (Sources.lua:154), so 'has no location on the map' alone would be wrong there; and the pin line is limited to once per pin. Impact lowered to low: it needs a quest with no map mark, or a pin standing at the moment of selecting, and Use Boats And Zeppelins is on by default. Not in ROADMAP, V1 or the audit (A2 is about a destination with no route, D7 about /thread quest).

### GA-4. A character without a gathering profession still gets the Gathering list and runs

`addons/PatchwerkForever_Thread_Routes/Gather.lua` line 31 (PatchwerkForever_Thread_Routes; edge-case; size S; impact low; needs a look in the game)

**Now:** Gather.lua:31-38 `local function Able()` / `local known = rawget(_G, 'IsPlayerSpell') or rawget(_G, 'IsSpellKnown')` / `if type(known) ~= 'function' then return { h = true, o = true } end` / `local okH, herbs = pcall(known, HERBS)` / `local okO, ore = pcall(known, ORE)` / `if not (okH and okO) or not (herbs or ore) then return { h = true, o = true } end`. A character with neither profession is treated as having both, and nodes are 'shared across your characters' (Core.lua:44), so the Tracker lists the Gathering section (Tracker Gather.lua:30-32) and 'Nearest Node (Any Type)' leads to nodes it cannot gather. README line 96 says 'Only what your character can gather is gone to.'

**Change:** Ask for the professions the way this client's own profession book does. In Able(): when `GetProfessions` and `GetProfessionInfo` are functions, go through every value `GetProfessions()` returns (use select('#', ...); they can be nil), take `select(7, GetProfessionInfo(index))` as the skill line, and compare with `C_TradeSkillUI.GetProfessionSkillLineID(Enum.Profession.Herbalism)` and `(Enum.Profession.Mining)` (fall back to 182 and 186 if that function is missing). When the calls succeed return `{ h = hasHerbalism, o = hasMining }`, both of which may be false; only when they cannot be asked fall back to today's spell test, and to 'both' last. Keep the answer for 10 seconds and drop it on SKILL_LINES_CHANGED, so a login where the game answers late corrects itself. With neither profession Near() already returns nothing, so the Tracker's section goes by itself; in Start() and in ns.GatherSay's list branch print 'This character has no gathering profession.' in place of the 'No ... node recorded nearby' lines. Minimap and world map node icons stay as they are. Add a stand-in GetProfessions and GetProfessionInfo to tools/wowstub.lua and a case to tools/lua_shell.py.

**Checked:** Quote exact; the 'says neither: both' fallback is deliberate (comment lines 29-30) and PLAN-tracker.md:235-236 lists it as still to be checked on Forever. Confirmed in the client source: IsPlayerSpell and IsSpellKnown exist only in Blizzard_DeprecatedSpellBook/Deprecated_SpellBook.lua, behind `if not GetCVarBool("loadDeprecationFallbacks") then return end`; GetProfessions and GetProfessionInfo (skill line as 7th value) are used by Blizzard_ProfessionsBook/Camelot/Blizzard_ProfessionsBook.lua:21 and :55; C_TradeSkillUI.GetProfessionSkillLineID and Enum.Profession are documented; SKILL_LINES_CHANGED is in SkillInfoDocumentation.lua. Proposal corrected to read every returned profession and to look the skill lines up instead of hard-coding them. Impact lowered to low: on a main with both professions nothing changes; it shows on alts. It becomes medium if `/dump IsPlayerSpell` prints nil in the game, because then every character is treated as having both. The risk the other way (a profession the game does not report hides the section) is why it needs a look in the game.

### GA-5. Clear Ignore List empties the whole list on one click, with no question

`addons/PatchwerkForever_Thread_Sparkle/Core.lua` line 40 (PatchwerkForever_Thread_Sparkle; feedback; size S; impact low)

**Now:** Core.lua:40-41 `{ button = 'Clear', name = 'Clear Ignore List', click = function() ns.IgnoreClear() end,` / `desc = 'Ignored objects never sparkle. To ignore one, point at it and type /sparkle ignore, or use the key binding. This button clears the whole list.' },`. Sparkle.lua:646-652 `function ns.IgnoreClear()` ... `PatchwerkForever_Thread_SparkleDB.sparkleIgnored = {}` / `ns.Print(('Ignore list cleared (%d object(s)).'):format(count))`. The base's own Reset To Defaults asks first (PatchwerkForever/Tools.lua:283-295).

**Change:** Ask first, from the button only. In Sparkle.lua add `function ns.IgnoreClearAsk()`: count the list; when it is empty print 'The ignore list is already empty.' and return; otherwise show a yes-or-no box made the way Tools.lua:284-294 makes its own: rawget StaticPopup_Show and StaticPopupDialogs, a dialog 'PATCHWERKFOREVER_SPARKLE_CLEAR' with text 'Clear the Sparkle ignore list (%s)? This cannot be undone.', button1 YES, button2 NO, OnAccept calling ns.Try around ns.IgnoreClear, timeout 0, whileDead and hideOnEscape true; pass the count as a string. Where the client has no such box, fall back to ns.IgnoreClear(). Point the button's click at ns.IgnoreClearAsk (Core.lua:40). The typed /sparkle clear stays immediate.

**Checked:** Quotes exact. The list is in PatchwerkForever_Thread_SparkleDB, an account-wide SavedVariables (TOC line 13), and nothing can bring it back after the click; the button is the third row under Hide In Instances' group on the first Sparkle page. StaticPopup_Show exists on this client (Blizzard_StaticPopup/StaticPopup.lua) and the base already adds its own dialog the same way. A confirmation on an existing destructive button is polish; it does not overlap ROADMAP S1 (the list shown in the options) or POLISH D4 (the wording of the 'cleared' line).

### GA-6. Tracker options that depend on a tick box are not greyed out with it

`addons/PatchwerkForever_Thread_Tracker/Core.lua` line 84 (PatchwerkForever_Thread_Tracker; consistency; size S; impact low)

**Now:** Core.lua:84 `{ page = GUIDE, key = 'guideAhead', default = 3, min = 0, max = 8, step = 1, name = 'Upcoming Steps',` and guideDone (86), guideSkip (88), guideItems (90) and guideHide (92) carry no `parent`, though each does nothing while Show Guide Steps (line 82, key 'guide') is off. Core.lua:102 `{ page = MORE, key = 'itemSide', default = 'left', name = 'Position', choices = { { 'left', 'Left of the tracker' }, { 'right', 'Right of the tracker' } },` has none either, while the row above it (100) has `parent = 'items'`.

**Change:** Add `parent = 'guide'` to guideAhead, guideDone, guideSkip, guideItems and guideHide, and `parent = 'items'` to itemSide. Each parent is defined earlier on the same page, which is what the base needs (Tools.lua:260-264). No behavior changes: the rows indent and grey out with their tick box. Leave the Quests page alone. Build it in the same pass as POLISH C6 so the pages look alike.

**Checked:** Quotes exact. Checked that each row is truly inert with its parent off: Guide.lua:68 reads no guide at all without 'guide' (so nothing to list, skip or count), Items.lua:125 tests 'guide' before 'guideItems', Quiet.lua:41 tests 'guide' before 'guideHide', and itemSide is read only when the bar is laid out (Items.lua:103, 174). Same mechanism the audit confirmed for Sparkle in SP-5. The Routes half of the reader's finding was cut (see dropped).

### GA-7. Going back to the main route removes the game's quest arrow instead of putting it back

`addons/PatchwerkForever_Thread_Tracker/Actions.lua` line 46 (PatchwerkForever_Thread_Tracker; edge-case; size S; impact low)

**Now:** Actions.lua:46-51 `if Choice:Is('quest', id) then` / `Choice:Clear()` / `PutArrow(0)` / `else` / `Choice:Set('quest', id)` / `PutArrow(id)`, and at the end of the list in ns.Cycle, lines 80-82 `Choice:Clear()` / `PutArrow(0)` / `ns.Print('Back to your main route.')`. Selecting a quest moves the game's arrow from wherever it was; un-selecting sets it to nothing. With no guide running, Routes' main route is the quest the arrow is on (Routes Core.lua:26 'Quest arrow, else nearest tracked'), so after select and un-select it leads to the nearest tracked quest, not the one it led to before.

**Change:** Remember the arrow and put it back, only on the player's own un-select. In Actions.lua add file-locals `arrowBefore` and `autoBefore`. In ns.Follow and ns.Cycle, in the branch that calls Choice:Set, when `Choice:Get()` was nil or not a quest before the call: `arrowBefore = Followed()` and `autoBefore = (auto ~= nil and auto == arrowBefore)` (read `auto` before line 44 and line 78 clear it). At the two `PutArrow(0)` lines: if the arrow is still on the quest being un-selected (or on nothing), call `PutArrow(back or 0)` where `back` is arrowBefore when `Ask(C_QuestLog.GetLogIndexForQuestID, arrowBefore)` still gives an index and it is not the quest just un-selected; if the player has since moved the arrow to another quest, leave it where it is. When `back` was restored and autoBefore is true, set `auto = back` so Auto-Track Nearest Quest keeps moving it. Clear both locals afterwards. ns.ArrowOff (a gathering run taking over) and a selection that ends by itself (turn in, abandon) stay as they are. Add a step to tools/lua_tracker.py: arrow on quest A, select B, select B again -> the arrow is on A.

**Checked:** Quotes exact (the Cycle lines are 80-82). Confirmed the consequence in Routes: ChooseQuest() takes Focused() first, then the nearest tracked. The game does not put an arrow back by itself: Blizzard_QuestSuperTracking.lua only places one on QUEST_ACCEPTED. Proposal tightened in two ways: restore only on the click or binding (restoring after a turn-in would move the game's arrow unasked, which the opt-in rule forbids), and do not overwrite an arrow the player moved meanwhile. If POLISH E6 (TI-4) is built first, `auto` is set through its setter. With a guide running Routes is unaffected; only the game's own arrow is lost, hence low.

### GA-8. While a new destination is being searched, the old trail stays up in the new destination's color

`addons/PatchwerkForever_Thread_Routes/Minimap.lua` line 174 (PatchwerkForever_Thread_Routes; visuals; size S; impact low; needs a look in the game)

**Now:** Minimap.lua:174 and WorldMap.lua:143 `r, g, b = ns.TrailColour(points[i + 1][3], follow and ns.dest and ns.dest.chosen)` color the route by the destination, not by the route. ns.SetDestination replaces ns.dest at once (Route.lua:403 `ns.dest = dest`) and starts a search (417 `ns.Plan(announce)`), but ns.route is swapped only when the search ends (290-291 `ns.route = route` / `Changed()`). Follow() does nothing meanwhile (327 `if not dest or job then return end`). So after selecting a quest in the Tracker, the old trail to the guide step is drawn in the Selected Route Color until the search is done.

**Change:** Tie the color to the route and show that it is being replaced. Route.lua: where a route is adopted (line 290 and the Ahead.Take branch at 411) set `route.dest = dest`; in ns.SetDestination call Changed() right after `ns.dest = dest` so the world map redraws too. In both drawers' Run() replace `follow and ns.dest and ns.dest.chosen` with `follow and trail.dest and trail.dest.chosen` (the look-ahead legs have no dest and stay as they are), and when `route.dest ~= ns.dest` draw the current route at alpha 0.45 in place of 0.95 (WorldMap.lua:93) and 0.9 (Minimap.lua:119), the look the fainter trails already use. A selection toggled on the same place keeps working, because Look() changes `dest.chosen` on the same table (Sources.lua:379-381); a new route after a wrong turn has the same dest and is not dimmed. Build it together with POLISH F2 (RO-8), which edits the same two lines.

**Checked:** Quotes exact. Traced: Look() calls ns.SetDestination directly when the source changes (Sources.lua:390) with no Stop in between; ns.route is assigned only at Route.lua:290 and :411 and cleared at :175 and in ns.Stop, so the old route does stay while the job runs, and the minimap redraws it every 0.05 s (Minimap.lua:13). How long that lasts depends on the search (4 ms a frame, Planner.lua:27) and could not be measured here: it may be a few frames for a near quest, which is why it needs a look in the game and stays low. Going back to the main route is usually instant (Ahead.Take hands over the way found ahead).

### GA-9. The Tracker's "followed" marker is worked out without asking Routes, and is wrong when Routes follows something else

`addons/PatchwerkForever_Thread_Tracker/Actions.lua` line 96 (PatchwerkForever_Thread_Tracker; consistency; size M; impact low)

**Now:** Actions.lua:96-102 `function ns.Marked()` / `local pick = ns.Base.Choice:Get()` / `if pick then return pick.kind == 'quest' and pick.id or nil end` / `if ns.Base.Gather:Has() and ns.Base.Gather:State() then return nil end       -- (a gathering run is)` / `if ns.GuideNow and ns.GuideNow() then return nil end` / `return Followed()`, and Guide.lua:138-141 `local followed = chosen` / `if main and not chosen then` / `followed = not Choice:Get() and not (ns.Base.Gather:Has() and ns.Base.Gather:State())`. Routes is never asked. So the guide step wears the marker while the trail leads to a quest (Routes Priority 'Tracked quest first', Follow RestedXP Guide unticked, or a guide step Routes cannot reach), to a map pin, and after Stop Routing; and with no guide and no quest arrow the quest Routes leads to has no marker (noted as known in tools/PLAN-tracker.md:293-294).

**Change:** Let whoever routes say what it follows, through the base, beside Choice. Base Choice.lua: `Choice:Report(kind, id)` stores `{ kind =, id = }` and calls the watchers only when kind or id changed; `Choice:Followed()` returns it (nil until a tool has reported, so without Routes today's rule stands); `Choice:Watch(fn)` adds a watcher, also called from Set and Clear. No API number change: callers test that the functions exist. Routes, all in Sources.lua Look(), which runs twice a second: Report('gather') in the gathering return (line 322), Report('pin') in the own-destination return (327), Report('none') where Target() gives no source (340), and after line 362 Report(source == 'quest' and 'quest' or 'guide', source == 'quest' and quest.id or guide.source), except Report('none') while a stop of the player's own stands (the skip at line 365 with `not skip.reached`). Reaching a place does not change the report, so the marker stays while you work there. Also register `Choice:Watch(function() C_Timer.After(0, function() ns.Try('following your guide and quests', Look) end) end)` so a click is answered on the next frame, not up to half a second later (one frame late on purpose, so a clear-and-set inside one call, as Gather:Start does, is not seen). Tracker: at the top of ns.Marked(), `local f = ns.Base.Choice.Followed and ns.Base.Choice:Followed()`; `if f then return f.kind == 'quest' and f.id or nil end`; in Guide.lua:138-141, when f is set, `followed = f.kind == 'guide' and f.id == info.source`, else today's rule; and `ns.Base.Choice.Watch and ns.Base.Choice:Watch(ns.Refresh)` so the bar moves when the report does. Extend tools/lua_tracker.py and tools/lua_shell.py: Priority 'quest' with a guide listed -> the quest is marked, the step is not; a pin -> nothing marked; Stop Routing -> nothing marked.

**Checked:** Quotes exact and each wrong case traced against Sources.lua Target() and Look(). It is polish of the existing marker (README line 48 says the bar 'shows what is being followed'), though it adds three small functions to the base. The reader's version was corrected: reporting from ns.SetDestination and ns.Stop left the report stale when Look() returns without a new destination (a reached step within 40 yards after a pin or a gathering run), and would have made the marker lag a click by up to a second; reporting from Look() and waking it on a choice fixes both. Impact lowered to low: with this player's defaults (guide first, the game placing its arrow on each accepted quest) the marker is right in the common case and wrong for a pin, after Stop Routing, and for an unreachable guide step. Related to the selection-feedback finding: with this built, a selected quest Routes cannot go to is no longer marked, and that finding's chat line is what explains it.

### GA: dropped

- **The Tracker and Routes each work out where a quest is, in different ways:** The code difference is real (Tracker Places.lua:36 asks GetQuestUiMapID(id) only; Routes Sources.lua:139-141 tries three maps), but no visible roughness could be confirmed. On this client the two calls differ only for a quest that has a next waypoint (Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua:1088-1098), which in this world means a quest on another continent, and for those the Tracker shows no distance by design (Places.lua:52 `if not (map and px and map == here) then return nil end`). Whether the third try (the map you are on) ever finds a quest the first misses cannot be told from the code. As proposed it is a refactor into a new base function, not a fix of something seen.
- **Routes half of 'options not greyed out with their tick box' (floatSize, floatHold, floatDown, floatAcross under Show Step Text):** These four are not inert while Show Step Text is off: ns.FloatAgain (/thread step, and the Show Step Text Again binding planned in POLISH B2) and the Preview Step Text button both call Show() without testing 'float' (Float.lua:110-121), and Show() reads all four settings. Greying them out would stop a player who shows the step text only on request from sizing or placing it. The Tracker half is kept.

