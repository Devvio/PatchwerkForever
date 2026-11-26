-- Tracker (Thread): the steps of the guides you are running.
--
-- The base reads the guide addons (its Guides.lua: RestedXP, and through a Stitch the Dungeon
-- Journal's quest list). Each gets a section: the step you are on with its lines, the steps after
-- it dimmed, and in the heading the guide's name, the number of the step and a thin bar of how far
-- through you are. With no guide addon running there is no such section.
--
-- The first is the main guide: the route follows it by itself. A click on its step skips it; a
-- click on one of the steps after it goes to that one.
--
-- Any other is a side list. A click on its step chooses it: the route then follows that list, step
-- after step, in place of the main guide, until you click it again or it has no more. A click on one
-- of its later steps goes to that one and chooses the list. Skipping is in its right-click menu.
--
-- A reader may say its guide is a side list (the Dungeon Journal's quests, unless set to lead). Then it
-- is one even when it is the first, or the only one listed: the route does not follow it by itself, so
-- a click must choose it and not skip a stop.
--
-- My Route is read as a guide too (the base's MyRoute.lua), but it has a section of its own
-- (Route.lua): it is left out here, so it is not listed twice. A step that names its quest (the
-- Dungeon Journal's do) has Add To My Route in its right-click menu.
--
-- Moving a guide to another step is done by its own reader, through the base (Guides:Go), and only
-- because you clicked. Each such click is said in chat. /tracker back, or Undo Skipped Guide Step, goes
-- to the step you were on before the last such click, unless another guide has been loaded since.
-- (A list whose step number does not move when it is moved has no step to go back to by number:
-- see Go below.)
--
-- A guide's words are shown from the guide addon's own tables as the game runs. None are kept.
--
-- With Show Quest Progress, the quests a step names are shown as your quest log has them, so they are
-- right even while the guide addon is paused: a line that has you complete one objective of a quest
-- shows the game's own words for it with its count, colored by progress as the quest list colors it;
-- a line that has you complete a whole quest, or hand one in, has under it the quest's objectives
-- still to do, or Ready to turn in. A step that names its quest (the Dungeon Journal's) has it the
-- same way. A quest that is not in your log shows nothing more.
local ADDON, ns = ...
if not ns.linked then return end

local MOST_GUIDES = 3

local before                  -- the step you were on before the last click on a step:
                              -- { source =, index =, guide = the guide's name then, to = the step the click went to }
local lastKey
local read = { at = -1, infos = {} }

-- A click moved the guide: said in chat, since one stray click does it, with how to take it back.
-- Not every list numbers its steps as a guide does: the Dungeon Journal's number counts the quests
-- turned in, so it stays where it was when a stop is skipped or brought forward, and going back to a
-- number does nothing there. The list is read again to tell: with its number unmoved (or the list
-- gone) no number is said and no undo is promised.
local function Go(info, index, from)
	if not ns.Get('guideSkip') then return end
	if ns.Base.Guides:Go(info, index) then
		local now = ns.Base.Guides:Read(0, info.source)
		local moved = now and now.index and now.index ~= from
		-- (a step back on a list whose number does not move is itself the list's own undo of the last
		-- skip: nothing is left for /tracker back to take back, or it would take back one more)
		if index < from and not moved then
			before = nil
		else
			before = { source = info.source, index = from, guide = info.guide, to = index }
		end
		if index == from + 1 then
			ns.Print(moved and ('Skipped step %d. Use the Undo Skipped Guide Step key binding or type /tracker back to undo.'):format(from)
				or 'Step skipped.')
		elseif index < from then
			ns.Print(moved and ('Back to step %d.'):format(index) or 'Went back one step.')
		else
			ns.Print(moved and ('Jumped to step %d. Type /tracker back to return to step %d.'):format(index, from)
				or 'Jumped to that step.')
		end
	else
		ns.Print(('%s could not jump to that step.'):format(info.reader or 'The guide'))
	end
	ns.Refresh()
end

-- Back to the step you were on before the last click on a step (/tracker back, and a key binding).
function ns.GuideBack()
	local info = before and ns.Base.Guides:Read(0, before.source)
	-- (another guide has been loaded since: the step's number means nothing in it)
	if info and info.guide ~= before.guide then info, before = nil, nil end
	if not info then
		ns.Print('No skipped step to undo.')
		return
	end
	local index, to = before.index, before.to
	before = nil
	if ns.Base.Guides:Go(info, index) then
		-- (read again, as Go does: on a list whose number does not move, the Dungeon Journal's, the
		-- last skip or jump was taken back, so the step it leads with changed, but its number did not
		-- and there is none to name)
		local now = ns.Base.Guides:Read(0, info.source)
		if now and now.index == info.index and now.key ~= info.key then
			ns.Print('Skip taken back.')
		-- (the guide has moved on since the click: said, so that going back many steps is no surprise)
		elseif info.index and info.index ~= to and info.index ~= index then
			ns.Print(('Back to step %d (from step %d).'):format(index, info.index))
		else
			ns.Print(('Back to step %d.'):format(index))
		end
	else
		ns.Print(('%s could not go back.'):format(info.reader or 'The guide'))
	end
	ns.Refresh()
end

-- The first words of a step, for a step listed on one line (cut short with an ellipsis: Frame.lua).
local function First(lines)
	for _, line in ipairs(lines or {}) do
		if not line.done and type(line.text) == 'string' and line.text ~= '' then return line.text end
	end
	return nil
end

---------------------------------------------------------------------------
-- Quest progress
---------------------------------------------------------------------------
local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

-- The quest's place in your log, or nil when it is not in it.
local function InLog(id)
	local index = Ask(C_QuestLog.GetLogIndexForQuestID, id)
	if index and index ~= 0 then return index end
	return nil
end

-- One objective of a quest as a line, as the game words it; nil for one it does not word.
local function Objective(o, sub)
	if not (type(o) == 'table' and type(o.text) == 'string' and o.text ~= '') then return nil end
	local each = { text = o.text, done = o.finished and true or false, sub = sub }
	local have, need = tonumber(o.numFulfilled), tonumber(o.numRequired)
	if ns.Get('progress') and not each.done and have and need and need > 1 then
		each.r, each.g, each.b = ns.Progress(have, need)
	end
	return each
end

local function Objectives(id)
	local list = Ask(C_QuestLog.GetQuestObjectives, id)
	return type(list) == 'table' and list or {}
end

-- What is left of a quest in your log, added to out as lines (set in under the line before, with sub):
-- its objectives still to do, or that it is ready to turn in (in the quest's own words when the game has
-- them, as the quest list says).
local function Left(id, out, sub)
	local index = InLog(id)
	if not index then return end
	if Ask(C_QuestLog.IsComplete, id) then
		local say = Ask(GetQuestLogCompletionText, index)
		if type(say) ~= 'string' or say == '' then say = 'Ready to turn in' end
		out[#out + 1] = { text = say, done = true, sub = sub }
		return
	end
	for _, o in ipairs(Objectives(id)) do
		if type(o) == 'table' and not o.finished then out[#out + 1] = Objective(o, sub) end
	end
end

-- A line of a step as shown: for one objective of a quest in your log, the game's words and count in
-- place of the guide's; else as the guide words it. Also the quest it names that is in your log.
local function Shown(line, progress)
	local quest = progress and not line.done and tonumber(line.quest) or nil
	if not (quest and InLog(quest)) then return { text = line.text, done = line.done }, nil end
	if line.kind == 'complete' and line.obj then
		local each = Objective(Objectives(quest)[line.obj])
		if each then return each, quest end
	end
	return { text = line.text, done = line.done }, quest
end

-- The first words of a step listed on one line, its quest's count in them as above.
local function FirstShown(lines)
	local progress = ns.Get('guideProgress')
	for _, line in ipairs(lines or {}) do
		local each, quest = Shown(line, progress)
		if not each.done and type(each.text) == 'string' and each.text ~= '' then return each.text end
		-- (a line the guide addon has not worded yet: what is left of its quest)
		if quest and not each.done and each.text == '' then
			local left = {}
			Left(quest, left)
			if left[1] then return left[1].text end
		end
	end
	return nil
end

-- Every guide with something to say, the main one first. Asked once a drawing.
local function Infos()
	local now = GetTime()
	if read.at ~= now then
		read.at = now
		read.infos = {}
		for _, info in ipairs(ns.Get('guide') and ns.Base.Guides:ReadAll(ns.Get('guideAhead') or 3) or {}) do
			-- (My Route has its own section: Route.lua)
			if info.source ~= 'route' then read.infos[#read.infos + 1] = info end
		end
	end
	return read.infos
end

-- What the main guide says now (for the item strip: the step's items).
function ns.GuideNow()
	return ns.guideInfo
end

-- A step that names its quest, as a stop of My Route: a quest of a kind the base knows where to pick up
-- (the Dungeon Journal's: 'fdj'), or a quest in your log; nothing for a step that names none.
local function StopOf(info, quest)
	if quest == nil then return nil end
	local MyRoute = ns.Base.MyRoute
	if MyRoute.kinds[info.source] then return { kind = info.source, id = quest } end
	local ok, index = pcall(C_QuestLog.GetLogIndexForQuestID, quest)
	if ok and index and index ~= 0 then return { kind = 'quest', id = quest } end
	return nil
end

-- The menu entry that adds a step's quest to My Route, or takes it out; nothing for a step that names none.
local function RouteEntry(info, quest, lines)
	local stop = StopOf(info, quest)
	if not stop then return nil end
	local MyRoute = ns.Base.MyRoute
	if MyRoute:Has(stop.kind, stop.id) then
		return { 'Remove From My Route', function() ns.RouteRemoveQuest(quest) end }
	end
	return { 'Add To My Route', function()
		local kind = MyRoute.kinds[stop.kind]
		local ok, name = false, nil
		if kind and type(kind.Name) == 'function' then ok, name = pcall(kind.Name, stop) end
		if not (ok and type(name) == 'string') then
			local asked, title = pcall(C_QuestLog.GetTitleForQuestID, quest)
			name = asked and title or nil
		end
		ns.RouteAdd(stop, name or First(lines) or ('Quest ' .. tostring(quest)))
	end }
end

-- Chooses a side list as the route to follow; on the one chosen already, goes back to the main route.
local function Choose(info)
	local Choice = ns.Base.Choice
	if Choice:Is('guide', info.source) then Choice:Clear() else Choice:Set('guide', info.source) end
	ns.Refresh()
end

local function Section(n)
	return function()
		local info = Infos()[n]
		if n == 1 then ns.guideInfo = nil end
		-- (a reader that found only where the guide's arrow points has no step to list)
		if not (type(info) == 'table' and info.index) then return nil end
		local main = n == 1 and not info.side           -- (a side list is one even when it is listed first)
		if main then
			ns.guideInfo = info
			if info.key ~= lastKey then
				lastKey = info.key
				if ns.QuietSoon then ns.QuietSoon() end       -- (the guide addon's own window may have redrawn itself)
			end
		end
		local most = ns.Get('guideAhead') or 3
		local Choice = ns.Base.Choice
		local chosen = Choice:Is('guide', info.source)
		local gr, gg, gb = ns.RGB(ns.Get('lookGuide'))
		local lines = {}
		local progress = ns.Get('guideProgress')
		local told = {}                                   -- (the quests whose objectives are shown already)
		for _, line in ipairs(info.lines or {}) do
			local each, quest = Shown(line, progress)
			if (not each.done or ns.Get('guideDone')) and type(each.text) == 'string' then
				local worded = each.text ~= ''
				if worded then lines[#lines + 1] = each end
				-- (a whole quest to complete, or one to hand in: what is left of it, under the line, or in
				-- its place while the guide addon has not worded it)
				if quest and not told[quest] and (line.kind == 'turnin' or (line.kind == 'complete' and not line.obj)) then
					told[quest] = true
					Left(quest, lines, worded)
				end
			end
		end
		local named = progress and tonumber(info.quest)
		if named and not told[named] then Left(named, lines, #lines > 0) end
		local skip = ns.Get('guideSkip')
		local click
		if main then
			click = skip and function(button, block)
				if button == 'RightButton' then
					local entries = {
						{ 'Skip Step', function() Go(info, info.index + 1, info.index) end },
						{ 'Previous Step', function() Go(info, info.index - 1, info.index) end },
					}
					entries[#entries + 1] = RouteEntry(info, info.quest, info.lines)
					ns.Menu(block, ('Step %d'):format(info.index), entries)
				else
					Go(info, info.index + 1, info.index)
				end
			end or nil
		else
			click = function(button, block)
				if button == 'RightButton' then
					local entries = { { chosen and 'Stop Routing To This List' or 'Route To This List', function() Choose(info) end } }
					if skip then
						entries[#entries + 1] = { 'Skip Step', function() Go(info, info.index + 1, info.index) end }
						entries[#entries + 1] = { 'Previous Step', function() Go(info, info.index - 1, info.index) end }
					end
					entries[#entries + 1] = RouteEntry(info, info.quest, info.lines)
					ns.Menu(block, info.guide or info.reader or 'Guide', entries)
				else
					Choose(info)
				end
			end
		end
		-- (marked while it is the track being followed. Routes (Thread) says which that is, through the
		-- base; without it: the main guide with nothing chosen and no gathering run on, and only on Auto
		-- or as the focus; a side list while it is the one chosen or the focus)
		local followed
		local said = ns.FollowingNow()
		if said then
			followed = said.kind == 'guide' and said.source == info.source
		else
			followed = chosen
			if not chosen and not Choice:Get() and not (ns.Base.Gather:Has() and ns.Base.Gather:State()) then
				local focus = ns.Focused()
				if main then followed = focus == 'auto' or focus == info.source else followed = focus == info.source end
			end
		end
		local tip
		if main then
			tip = skip and { 'Click to skip this step.', 'Right-click for more options.' } or nil
		else
			tip = { chosen and 'Click to stop routing along this list.' or 'Click to route along this list.', 'Right-click for more options.' }
		end
		local blocks = { { key = 'step', title = ('Step %d'):format(info.index), r = gr, g = gg, b = gb, lines = lines,
			mark = followed and true or false, click = click, tip = tip } }
		for i, step in ipairs(info.after or {}) do
			if i > most then break end
			local index = step.index
			local function GoThere()
				Go(info, index, info.index)
				if not main and not Choice:Is('guide', info.source) then Choice:Set('guide', info.source) end
			end
			-- (a later step that names its quest has a menu too: go to it, or add it to My Route)
			local click = skip and GoThere or nil
			local tip = skip and { 'Click to go to this step.' } or nil
			if StopOf(info, step.quest) then
				tip = tip or {}
				tip[#tip + 1] = 'Right-click for more options.'
				click = function(button, block)
					if button ~= 'RightButton' then
						if skip then GoThere() end
						return
					end
					local entries = {}
					if skip then entries[1] = { 'Go To This Step', GoThere } end
					entries[#entries + 1] = RouteEntry(info, step.quest, step.lines)
					ns.Menu(block, FirstShown(step.lines) or info.guide or 'Guide', entries)
				end
			end
			blocks[#blocks + 1] = {
				key = 'after' .. i, small = true, oneLine = true, r = gr * 0.6, g = gg * 0.6, b = gb * 0.6,
				title = ('%d. %s'):format(index, FirstShown(step.lines) or '...'),
				click = click, tip = tip,
			}
		end
		local note, bar
		if info.total and info.total > 0 then
			note = ('Step %d of %d'):format(info.index, info.total)
			bar = info.index / info.total
		end
		-- (tick: a line of the step is ticked off by the guide addon without any event of the game)
		return { title = info.guide or info.reader or 'Guide', note = note, bar = bar, blocks = blocks, tick = true }
	end
end

ns.AddSection('guide', 10, Section(1))
for n = 2, MOST_GUIDES do
	ns.AddSection('guide' .. n, 10 + n, Section(n))
end

-- (a guide addon moves from step to step without any event of the game: looked at every second or so)
C_Timer.NewTicker(1, function()
	if not ns.Get('guide') then return end
	local parts = {}
	for _, info in ipairs(ns.Base.Guides:ReadAll(0)) do
		parts[#parts + 1] = tostring(info.source) .. '=' .. tostring(info.key)
	end
	local key = table.concat(parts, '|')
	if key ~= ns.guideSeen then
		ns.guideSeen = key
		ns.Refresh()
	end
end)
