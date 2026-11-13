-- Thread (Tracker): the steps of the guides you are running.
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
-- Moving a guide to another step is done by its own reader, through the base (Guides:Go), and only
-- because you clicked. /tracker back goes to the step you were on before the last such click.
--
-- A guide's words are shown from the guide addon's own tables as the game runs. None are kept.
local ADDON, ns = ...
if not ns.linked then return end

local MOST_GUIDES = 3

local before                  -- { source =, index = } the step you were on before the last click on a step
local lastKey
local read = { at = -1, infos = {} }

local function Go(info, index, from)
	if not ns.Get('guideSkip') then return end
	if ns.Base.Guides:Go(info, index) then
		before = { source = info.source, index = from }
	else
		ns.Print(('%s could not jump to that step.'):format(info.reader or 'The guide'))
	end
	ns.Refresh()
end

-- Back to the step you were on before the last click on a step.
function ns.GuideBack()
	local info = before and ns.Base.Guides:Read(0, before.source)
	if not info then
		ns.Print('No skipped step to undo.')
		return
	end
	local index = before.index
	before = nil
	if ns.Base.Guides:Go(info, index) then
		ns.Print(('Back to step %d.'):format(index))
	else
		ns.Print(('%s could not go back.'):format(info.reader or 'The guide'))
	end
	ns.Refresh()
end

-- The first words of a step, for a step listed on one line.
local function First(lines)
	for _, line in ipairs(lines or {}) do
		if not line.done and type(line.text) == 'string' and line.text ~= '' then return line.text end
	end
	return nil
end

-- Every guide with something to say, the main one first. Asked once a drawing.
local function Infos()
	local now = GetTime()
	if read.at ~= now then
		read.at = now
		read.infos = ns.Get('guide') and ns.Base.Guides:ReadAll(ns.Get('guideAhead') or 3) or {}
	end
	return read.infos
end

-- What the main guide says now (for the item strip: the step's items).
function ns.GuideNow()
	return ns.guideInfo
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
		local main = n == 1
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
		for _, line in ipairs(info.lines or {}) do
			if not line.done or ns.Get('guideDone') then
				lines[#lines + 1] = { text = line.text, done = line.done }
			end
		end
		local skip = ns.Get('guideSkip')
		local click
		if main then
			click = skip and function(button, block)
				if button == 'RightButton' then
					ns.Menu(block, ('Step %d'):format(info.index), {
						{ 'Skip Step', function() Go(info, info.index + 1, info.index) end },
						{ 'Previous Step', function() Go(info, info.index - 1, info.index) end },
					})
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
					ns.Menu(block, info.guide or info.reader or 'Guide', entries)
				else
					Choose(info)
				end
			end
		end
		-- (marked while it is the track being followed: the main guide with nothing chosen and no
		-- gathering run on; a side list while it is the one chosen)
		local followed = chosen
		if main and not chosen then
			followed = not Choice:Get() and not (ns.Base.Gather:Has() and ns.Base.Gather:State())
		end
		local blocks = { { key = 'step', title = ('Step %d'):format(info.index), r = gr, g = gg, b = gb, lines = lines,
			mark = followed and true or false, click = click } }
		for i, step in ipairs(info.after or {}) do
			if i > most then break end
			local index = step.index
			blocks[#blocks + 1] = {
				key = 'after' .. i, small = true, r = gr * 0.6, g = gg * 0.6, b = gb * 0.6,
				title = ('%d. %s'):format(index, First(step.lines) or '...'),
				click = skip and function()
					Go(info, index, info.index)
					if not main and not Choice:Is('guide', info.source) then Choice:Set('guide', info.source) end
				end or nil,
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
