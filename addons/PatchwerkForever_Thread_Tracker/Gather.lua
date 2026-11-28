-- Tracker (Thread): the gathering list.
--
-- Routes (Thread) remembers where you picked herbs and mined ore, and can lead you from one spot
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
	-- (a run to the best area is a round with its area: 'best' stops it, 'round' starts a round here)
	local same = state and ((mode == 'best' and state.best ~= nil)
		or (mode ~= 'best' and state.mode == mode and not (mode == 'round' and state.best) and (mode ~= 'kind' or state.name == name)))
	if same then
		Gather:Stop()
	else
		local pick = ns.Base.Choice:Get()
		Gather:Start(mode, name)
		if pick and pick.kind == 'quest' and not ns.Base.Choice:Get() then ns.ArrowOff() end
	end
	ns.Wake()
	ns.Refresh()
end
ns.GatherStart = Start        -- (a row of the collect list starts a run the same way: Collect.lua)

ns.AddSection('gather', 80, function()
	local Gather = ns.Base.Gather
	if not (ns.Get('gather') and Gather and Gather:Has()) then return nil end
	local near = Gather:Near(ns.Get('gatherMost') or 4)
	local state = Gather:State()
	local skins = Gather:SkinKnown() or 0
	if #near == 0 and not state and skins == 0 then return nil end
	local tr, tg, tb = ns.RGB(ns.Get('lookTitle'))
	local lr, lg, lb = ns.RGB(ns.Get('lookLine'))
	-- (the hint: what a click starts, or that it stops the run it started)
	local function Tip(on, what) return { on and 'Click to stop.' or what } end
	local any = state and state.mode == 'any'
	local best = state and state.best ~= nil
	local round = state and state.mode == 'round' and not best
	local blocks = {
		{ key = 'any', title = 'Nearest Node (Any Type)', r = tr, g = tg, b = tb, mark = any,
			tip = Tip(any, 'Click to route to the nearest node.'), click = function() Start('any') end },
		{ key = 'round', title = 'Farm Nearby Nodes', r = tr, g = tg, b = tb, mark = round,
			tip = Tip(round, 'Click to route through the nodes near here, one after another.'), click = function() Start('round') end },
	}
	-- the best area on the continent (Routes looks at most every half minute), and skinning
	local area = Gather:Best()
	if area or best then
		blocks[#blocks + 1] = { key = 'best', title = 'Best Gathering Area', r = tr, g = tg, b = tb, mark = best,
			note = area and ('%d nodes, %s'):format(area.count, ns.YardsText(area.yards)) or nil,
			tip = Tip(best, 'Click to route to the area with the most nodes you can gather, then round it.'),
			click = function() Start('best') end }
	end
	if skins > 0 then
		blocks[#blocks + 1] = { key = 'skin', title = 'Best Skinning Area', r = tr, g = tg, b = tb,
			note = ('%d %s known'):format(skins, skins == 1 and 'creature' or 'creatures'),
			tip = { 'Click to route to where most of the creatures you can skin stand.' },
			click = function() Gather:Skin(); ns.Wake(); ns.Refresh() end }
	end
	-- herbs and ore: which is tracked, and the key that switches (Routes: an addon may not switch it itself)
	local tracking = Gather:Tracking()
	if type(tracking) == 'table' then
		local on = tracking.on == 'h' and 'Herbs' or tracking.on == 'o' and 'Ore' or 'Neither'
		blocks[#blocks + 1] = { key = 'tracking', title = 'Tracking: ' .. on, r = lr, g = lg, b = lb,
			note = tracking.key and tostring(tracking.key) or nil,
			tip = { tracking.key and ('Press %s to switch between Find Herbs and Find Minerals.'):format(tostring(tracking.key))
				or 'Bind Switch Herb/Ore Tracking (key bindings, Patchwerk Forever) to switch between Find Herbs and Find Minerals with one key.' } }
	end
	for _, spot in ipairs(near) do
		local name = spot.name
		local on = state and state.mode == 'kind' and state.name == name
		blocks[#blocks + 1] = { key = 'kind:' .. tostring(name), title = tostring(name), r = tr, g = tg, b = tb,
			note = ns.YardsText(spot.yards), mark = on,
			tip = Tip(on, 'Click to route to the nearest one, and on to the next.'), click = function() Start('kind', name) end }
	end
	local note = state and ('To ' .. tostring(state.going or state.name or 'next node')) or nil
	return { title = 'Gathering', note = note, blocks = blocks, tick = true }
end)

-- Quest givers (Routes with QuestieDB): one row that starts or stops a run to the nearest quest
-- giver with a quest for you, then the next. Shown only where QuestieDB is there to ask.
ns.AddSection('givers', 82, function()
	local Gather = ns.Base.Gather
	if not (ns.Get('gather') and Gather and Gather:Has()) then return nil end
	local info = Gather:GiversState()
	if not info or (info.near == 0 and not info.going) then return nil end
	local tr, tg, tb = ns.RGB(ns.Get('lookTitle'))
	local on = info.going ~= nil
	local blocks = {
		{ key = 'givers', title = on and tostring(info.going) or 'Nearest Quest Giver', r = tr, g = tg, b = tb, mark = on,
			note = on and ('%d %s'):format(info.quests or 0, (info.quests or 0) == 1 and 'quest' or 'quests')
				or ('%d nearby'):format(info.near),
			tip = { on and 'Click to stop the quest giver run.' or 'Click to route to the nearest quest giver with a quest you can take, then the next.' },
			click = function() Gather:Givers(not on); ns.Wake(); ns.Refresh() end },
	}
	return { title = 'Quest Givers', note = on and 'To next giver' or nil, blocks = blocks, tick = true }
end)
