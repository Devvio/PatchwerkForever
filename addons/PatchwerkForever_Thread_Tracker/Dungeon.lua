-- Thread (Tracker): a dungeon's stages. Untried, and off until you tick it.
--
-- Where the game runs a place in stages (it calls that a "scenario"), its own tracker shows the
-- stage you are on and what the stage asks. This asks the game the same way (C_Scenario.GetInfo,
-- C_Scenario.GetStepInfo, C_ScenarioInfo.GetCriteriaInfo) and lists it at the top.
--
-- Whether Forever's dungeons are run this way has not been seen yet: in a dungeon the game may say
-- nothing here, and then there is no such section. That is why the game's own tracker is still let
-- back in dungeons (a setting of its own) whatever this one shows.
local ADDON, ns = ...
if not ns.linked then return end

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local function Clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return ('%d:%02d'):format(seconds / 60, seconds % 60)
end

ns.AddSection('dungeon', 5, function()
	if not (ns.Get('dungeon') and C_Scenario and C_Scenario.GetInfo) then return nil end
	if C_Scenario.IsInScenario and not Ask(C_Scenario.IsInScenario) then return nil end
	local name, stage, stages = Ask(C_Scenario.GetInfo)
	if type(name) ~= 'string' or name == '' then return nil end
	local stageName, about, count = Ask(C_Scenario.GetStepInfo)
	local lines, tick = {}, false
	local criteria = C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo
	for i = 1, tonumber(count) or 0 do
		local c = Ask(criteria, i)
		if type(c) == 'table' and type(c.description) == 'string' then
			local text = c.description
			if tonumber(c.totalQuantity) and c.totalQuantity > 1 and not c.isWeightedProgress then
				text = ('%d/%d %s'):format(tonumber(c.quantity) or 0, c.totalQuantity, text)
			elseif c.isWeightedProgress and tonumber(c.quantity) then
				text = ('%s: %d%%'):format(text, c.quantity)
			end
			lines[#lines + 1] = { text = text, done = c.completed and true or false }
			local duration, elapsed = tonumber(c.duration), tonumber(c.elapsed)
			if duration and duration > 0 and elapsed and elapsed <= duration and not c.completed then
				lines[#lines + 1] = { text = 'Time left: ' .. Clock(duration - elapsed), r = 1, g = 0.8, b = 0.3, clock = true, plain = true }
				tick = true
			end
		end
	end
	if #lines == 0 and type(about) == 'string' and about ~= '' then lines[1] = { text = about } end
	local r, g, b = ns.RGB(ns.Get('lookTitle'))
	local title = (type(stageName) == 'string' and stageName ~= '') and stageName or name
	local note = (tonumber(stages) and stages > 1) and ('Stage %d of %d'):format(tonumber(stage) or 1, stages) or nil
	return { title = name, note = note, tick = tick, blocks = { { key = 'stage', title = title, r = r, g = g, b = b, lines = lines } } }
end)

for _, event in ipairs({ 'SCENARIO_UPDATE', 'SCENARIO_CRITERIA_UPDATE', 'SCENARIO_COMPLETED' }) do
	ns.Try('listening for ' .. event, ns.On, event, ns.Refresh)
end
