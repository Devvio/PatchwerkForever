-- Thread (Tracker): the steps of the guide you are running.
--
-- The base reads the guide addon (its Guides.lua; RestedXP is the one it knows). This lists what it
-- says: the step you are on with its lines, the steps after it dimmed, and in the heading the
-- guide's name, the number of the step and a thin bar of how far through the guide you are. With
-- no guide addon running there is no such section.
--
-- A click on the step you are on skips it; a click on one of the steps after it goes to that one.
-- Both are done by the guide addon's own means, through the base (Guides:Go), and only because you
-- clicked. /tracker back goes to the step you were on before the last such click.
--
-- The guide's words are shown from the guide addon's own tables as the game runs. None are kept.
local ADDON, ns = ...
if not ns.linked then return end

local before                  -- { source =, index = } the step you were on before the last click on a step
local lastKey

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
	local info = ns.Base.Guides:Read(0)
	if not (info and before and before.source == info.source) then
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

-- What the guide says now (for the item strip: the step's items). Asked once a drawing.
function ns.GuideNow()
	return ns.guideInfo
end

ns.AddSection('guide', 10, function()
	ns.guideInfo = nil
	if not ns.Get('guide') then return nil end
	local most = ns.Get('guideAhead') or 3
	local info = ns.Base.Guides:Read(most)
	-- (a reader that found only where the guide's arrow points has no step to list)
	if not (type(info) == 'table' and info.index) then return nil end
	ns.guideInfo = info
	if info.key ~= lastKey then
		lastKey = info.key
		if ns.QuietSoon then ns.QuietSoon() end       -- (the guide addon's own window may have redrawn itself)
	end
	local gr, gg, gb = ns.RGB(ns.Get('lookGuide'))
	local lines = {}
	for _, line in ipairs(info.lines or {}) do
		if not line.done or ns.Get('guideDone') then
			lines[#lines + 1] = { text = line.text, done = line.done }
		end
	end
	local blocks = { {
		key = 'step', title = ('Step %d'):format(info.index), r = gr, g = gg, b = gb, lines = lines,
		-- (marked while it is the track being followed: not while a quest you chose, or a gathering run, is)
		mark = not ns.Base.Choice:Get() and not (ns.Base.Gather:Has() and ns.Base.Gather:State()),
		click = ns.Get('guideSkip') and function(button, block)
			if button == 'RightButton' then
				ns.Menu(block, ('Step %d'):format(info.index), {
					{ 'Skip Step', function() Go(info, info.index + 1, info.index) end },
					{ 'Previous Step', function() Go(info, info.index - 1, info.index) end },
				})
			else
				Go(info, info.index + 1, info.index)
			end
		end or nil,
	} }
	for i, step in ipairs(info.after or {}) do
		if i > most then break end
		local index = step.index
		blocks[#blocks + 1] = {
			key = 'after' .. i, small = true, r = gr * 0.6, g = gg * 0.6, b = gb * 0.6,
			title = ('%d. %s'):format(index, First(step.lines) or '...'),
			click = ns.Get('guideSkip') and function() Go(info, index, info.index) end or nil,
		}
	end
	local note, bar
	if info.total and info.total > 0 then
		note = ('Step %d of %d'):format(info.index, info.total)
		bar = info.index / info.total
	end
	-- (tick: a line of the step is ticked off by the guide addon without any event of the game)
	return { title = info.guide or info.reader or 'Guide', note = note, bar = bar, blocks = blocks, tick = true }
end)

-- (a guide addon moves from step to step without any event of the game: looked at every second or so)
C_Timer.NewTicker(1, function()
	if not ns.Get('guide') then return end
	local info = ns.Base.Guides:Read(0)
	local key = info and info.key or false
	if key ~= ns.guideSeen then
		ns.guideSeen = key
		ns.Refresh()
	end
end)
