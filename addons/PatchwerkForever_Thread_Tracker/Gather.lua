-- Thread (Tracker): the gathering list.
--
-- Thread (Routes) remembers where you picked herbs and mined ore, and can lead you from one spot
-- to the next. It offers that through the base (PatchwerkForever.Gather); this lists it and starts
-- it. The two addons do not know each other: with Routes not installed nothing is offered and
-- there is no such list. The only spots known are the ones you have gathered from yourself.
--
-- The list: the nearest spot of each kind you can gather, with how far it is. A click on one leads
-- you to the nearest of that kind, and on reaching it to the next, until you click it again.
-- Above them, two more: the nearest spot of anything, and a round through the spots near here.
local ADDON, ns = ...
if not ns.linked then return end

local function Start(mode, name)
	local Gather = ns.Base.Gather
	local state = Gather:State()
	if state and state.mode == mode and (mode ~= 'kind' or state.name == name) then
		Gather:Stop()
	else
		local pick = ns.Base.Choice:Get()
		Gather:Start(mode, name)
		if pick and pick.kind == 'quest' and not ns.Base.Choice:Get() then ns.ArrowOff() end
	end
	ns.Refresh()
end

ns.AddSection('gather', 80, function()
	local Gather = ns.Base.Gather
	if not (ns.Get('gather') and Gather and Gather:Has()) then return nil end
	local near = Gather:Near(ns.Get('gatherMost') or 4)
	local state = Gather:State()
	if #near == 0 and not state then return nil end
	local tr, tg, tb = ns.RGB(ns.Get('lookTitle'))
	local blocks = {
		{ key = 'any', title = 'Nearest Node (Any Type)', r = tr, g = tg, b = tb, mark = state and state.mode == 'any',
			click = function() Start('any') end },
		{ key = 'round', title = 'Farm Nearby Nodes', r = tr, g = tg, b = tb, mark = state and state.mode == 'round',
			click = function() Start('round') end },
	}
	for _, spot in ipairs(near) do
		local name = spot.name
		blocks[#blocks + 1] = { key = 'kind:' .. tostring(name), title = tostring(name), r = tr, g = tg, b = tb,
			note = ns.YardsText(spot.yards), mark = state and state.mode == 'kind' and state.name == name,
			click = function() Start('kind', name) end }
	end
	local note = state and ('To ' .. tostring(state.going or state.name or 'next node')) or nil
	return { title = 'Gathering', note = note, blocks = blocks, tick = true }
end)
