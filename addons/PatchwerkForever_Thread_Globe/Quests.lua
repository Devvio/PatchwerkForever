-- Thread (Globe): quests on the globe.
--
--   your quests       each quest in your log that the game marks a place for: a numbered mark where
--                     its next objective is, a ? where it is handed in once it is done. The one the
--                     route follows (or you chose, or the game's arrow is on) is larger, with a soft
--                     ring round where it is done. (The game draws a quest's area as a shape only on
--                     its own map; the ring stands in for it.) A click chooses the quest, as a click
--                     on it in Thread (Tracker) does: Thread (Routes) goes there first. A click on
--                     the chosen one goes back to your main route.
--   quests on offer   a ! where the game says a quest can be picked up, in the zone at the middle of
--                     the picture, from zone level in
--   a guide's steps   where the guide you run sends you now, and its next steps, numbered; a side list
--                     (Stitch (Dungeon Journal)'s quests) shows each of its quests as a !, and a click
--                     follows that list
--
-- The Route button (and the Route Menu key) lists what the route can follow, adds the map pin to My
-- Route, opens My Route's editor beside the globe, and keeps Thread (Tracker)'s list beside the globe
-- while it is open. A quest chosen anywhere (a click in the tracker) turns the globe to it.
local ADDON, ns = ...
if not (ns.linked and ns.Marks) then return end
local G, Marks = ns.G, ns.Marks
local Base = ns.Base
local Guides, Choice, Following, Focus, MyRoute = Base.Guides, Base.Choice, Base.Following, Base.Focus, Base.MyRoute

local VIEW = G.VIEW
local ZONE_FROM = VIEW * 1.2          -- offers, and the ring, are shown from this zoom in
local TURN_TO = VIEW * 2.4            -- a quest chosen from further out than this is zoomed in on, to here
local GOLD, GUIDE = { 1, 0.84, 0.25 }, { 0.55, 0.95, 0.78 }
local RING_YARDS = 90

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local log = rawget(_G, 'C_QuestLog') or {}
local track = rawget(_G, 'C_SuperTrack') or {}

---------------------------------------------------------------------------
-- Your quests
---------------------------------------------------------------------------
local function Chosen(id)
	return type(Choice) == 'table' and Choice.Is and Choice:Is('quest', id) and true or false
end

-- The quest picked out: the one the route follows, else the one you chose, else the game's arrow's.
local function Picked()
	local info = type(Following) == 'table' and Following.Get and Following:Get()
	if type(info) == 'table' and type(info.quest) == 'number' then return info.quest end
	local choice = type(Choice) == 'table' and Choice.Get and Choice:Get()
	if type(choice) == 'table' and choice.kind == 'quest' then return choice.id end
	local id = Ask(track.GetSuperTrackedQuestID)
	return type(id) == 'number' and id > 0 and id or nil
end

local function Done(id)
	return (Ask(log.IsComplete, id) or Ask(log.ReadyForTurnIn, id)) and true or false
end

local function QuestLines(m)
	local lines = {}
	for _, o in ipairs(Ask(log.GetQuestObjectives, m.quest) or {}) do
		if type(o) == 'table' and type(o.text) == 'string' and o.text ~= '' then
			lines[#lines + 1] = o.finished and ('|cff808080' .. o.text .. '|r') or o.text
		end
	end
	if m.done then lines[#lines + 1] = 'Ready to turn in' end
	lines[#lines + 1] = Chosen(m.quest) and '|cff66c2ffClick to go back to your main route.|r' or '|cff66c2ffClick to route to this quest.|r'
	return lines
end

local arrowed                 -- the quest the game's arrow was put on here
local function QuestClick(_, m)
	if not (type(Choice) == 'table' and Choice.Set) then return end
	if Chosen(m.quest) then
		Choice:Clear()
		if arrowed == m.quest and Ask(track.GetSuperTrackedQuestID) == m.quest then Ask(track.SetSuperTrackedQuestID, 0) end
		arrowed = nil
	else
		Choice:Set('quest', m.quest)
		-- (with no Thread (Tracker) to move the game's own arrow, it is put on the quest here, and taken
		-- off again when you go back)
		if not rawget(_G, 'PatchwerkForeverTracker') and not rawget(_G, 'PatchwerkForever_Thread_Tracker_Dock') then
			Ask(track.SetSuperTrackedQuestID, m.quest)
			arrowed = m.quest
		end
	end
end

Marks.Source('quests', {
	order = 50,
	every = 5,                       -- (a quest's mark moves to its next objective by itself)
	Shown = function() return ns.Get('globeQuests') end,
	Fill = function(mark)
		if not (Guides and Guides.QuestPlace) then return end
		local picked = Picked()
		local n = 0
		for i = 1, Ask(log.GetNumQuestLogEntries) or 0 do
			local info = Ask(log.GetInfo, i)
			if type(info) == 'table' and not info.isHeader and not info.isHidden and type(info.questID) == 'number' then
				local id = info.questID
				local map, x, y = Guides.QuestPlace(id)
				if map and x and y then
					n = n + 1
					local done, mine = Done(id), id == picked
					local title = type(info.title) == 'string' and info.title or Ask(log.GetTitleForQuestID, id) or 'Quest'
					if mine and not done then
						mark({ map = map, x = x, y = y, icon = Marks.Icon('ring'), tint = GOLD, alpha = 0.85, yards = RING_YARDS, least = 34,
							most = 260, from = ZONE_FROM, under = true })
					end
					mark({ map = map, x = x, y = y, icon = Marks.Icon(done and 'ask' or 'badge'), tint = (not done) and GOLD or nil,
						size = (done and 22 or 20) + (mine and 6 or 0), text = (not done) and tostring(n) or nil,
						rank = (mine and 80 or 50) + (done and 3 or 0), keep = mine,
						name = title, quest = id, done = done, picked = mine, lines = QuestLines, click = QuestClick })
				end
			end
		end
	end,
})
for _, event in ipairs({ 'QUEST_LOG_UPDATE', 'QUEST_WATCH_LIST_CHANGED', 'SUPER_TRACKING_CHANGED', 'QUEST_ACCEPTED', 'QUEST_REMOVED', 'QUEST_TURNED_IN' }) do
	Marks.On(event, function() Marks.Changed('quests') end)
end
if type(Following) == 'table' and Following.OnChange then
	Following:OnChange(function() Marks.Changed('quests') end)
end

-- A quest chosen (here, or by a click in the tracker) is turned to, while the globe is open.
if type(Choice) == 'table' and Choice.OnChange then
	Choice:OnChange(function(choice)
		Marks.Changed('quests')
		Marks.Changed('steps')
		local window = ns.GlobeWindow()
		if not (window and window:IsShown() and type(choice) == 'table' and choice.kind == 'quest' and Guides and Guides.QuestPlace) then return end
		local map, x, y = Guides.QuestPlace(choice.id)
		local p = map and Marks.Where(map, x, y)
		if p then G.GlideTo(p, math.max(G.look.r, TURN_TO)) end
	end)
end

---------------------------------------------------------------------------
-- Quests on offer
---------------------------------------------------------------------------
local lines = rawget(_G, 'C_QuestLine') or {}

-- The zone's own map at the middle of the picture (the game's number for it).
local function ZoneMap() return (Marks.ZoneMap()) end

local asked
Marks.Source('offers', {
	order = 45,
	every = 30,
	Shown = function() return ns.Get('globeQuests') and lines.GetAvailableQuestLines ~= nil end,
	Key = function(r) return r >= ZONE_FROM and ZoneMap() or 'far' end,
	Fill = function(mark)
		if G.look.r < ZONE_FROM then return end
		local zone = ZoneMap()
		if not zone then return end
		if asked ~= zone then
			asked = zone
			Ask(lines.RequestQuestLinesForMap, zone)       -- (the answer comes with QUESTLINE_UPDATE)
		end
		for _, offer in ipairs(Ask(lines.GetAvailableQuestLines, zone) or {}) do
			if type(offer) == 'table' and type(offer.x) == 'number' and type(offer.y) == 'number' and not offer.inProgress
				and not (offer.isHidden) then
				local map, wx, wy = Guides.WorldOf(type(offer.startMapID) == 'number' and offer.startMapID > 0 and offer.startMapID or zone, offer.x, offer.y)
				if not map then map, wx, wy = Guides.WorldOf(zone, offer.x, offer.y) end
				mark({ map = map, x = wx, y = wy, icon = Marks.Icon('bang'), size = 20, rank = 35, from = ZONE_FROM,
					name = type(offer.questName) == 'string' and offer.questName or 'Quest', lines = { 'Available quest' } })
			end
		end
	end,
})
Marks.On('QUESTLINE_UPDATE', function() Marks.Changed('offers') end)

---------------------------------------------------------------------------
-- A guide's steps
---------------------------------------------------------------------------
local function Words(step)
	local out = {}
	for _, line in ipairs(type(step.lines) == 'table' and step.lines or {}) do
		if type(line) == 'table' and type(line.text) == 'string' and line.text ~= '' and #out < 4 then
			out[#out + 1] = line.done and ('|cff808080' .. line.text .. '|r') or line.text
		end
	end
	return out
end

local function ListClick(_, m)
	if type(Choice) == 'table' and Choice.Set and m.list then Choice:Set('guide', m.list) end
end

Marks.Source('steps', {
	order = 55,
	every = 3,
	Shown = function() return ns.Get('globeQuests') and type(Guides) == 'table' and Guides.ReadAll ~= nil end,
	Fill = function(mark)
		for _, info in ipairs(Guides:ReadAll(8) or {}) do
			if type(info) == 'table' and info.source ~= 'route' then       -- (My Route's stops are marked in Travel.lua)
				local reader = type(info.reader) == 'string' and info.reader or 'Guide'
				local steps = { info }
				for _, step in ipairs(type(info.ahead) == 'table' and info.ahead or {}) do steps[#steps + 1] = step end
				for n, step in ipairs(steps) do
					if type(step.map) == 'number' and type(step.x) == 'number' and type(step.y) == 'number' then
						local words = Words(step)
						local name = words[1] and words[1]:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '') or reader
						if info.side then
							words[#words + 1] = reader
							words[#words + 1] = '|cff66c2ffClick to follow this list.|r'
							mark({ map = step.map, x = step.x, y = step.y, icon = Marks.Icon('bang'), size = n == 1 and 22 or 18, rank = 44 - n,
								name = name, lines = words, list = info.source, click = ListClick })
						else
							table.insert(words, 1, n == 1 and (reader .. ': the step you are on') or (reader .. ': step ' .. tostring(step.index or n)))
							mark({ map = step.map, x = step.x, y = step.y, icon = Marks.Icon('badge'), tint = GUIDE, size = n == 1 and 24 or 18,
								text = tostring(n), rank = 66 - n, keep = n == 1, name = name, lines = words })
						end
					end
				end
			end
		end
	end,
})

---------------------------------------------------------------------------
-- The Route button, and Thread (Tracker) beside the globe
---------------------------------------------------------------------------
local function Pin()
	local point = C_Map and Ask(C_Map.GetUserWaypoint)
	if not (type(point) == 'table' and type(point.uiMapID) == 'number' and type(point.position) == 'table') then return nil end
	local x, y = point.position.x, point.position.y
	if point.position.GetXY then x, y = point.position:GetXY() end
	return Guides.WorldOf(point.uiMapID, x, y)
end

local function TrackerDock() return rawget(_G, 'PatchwerkForever_Thread_Tracker_Dock') end

-- Thread (Tracker)'s list beside the globe while it is open, and back where you keep it after.
local docked = false
local function Dock()
	local dock = TrackerDock()
	if type(dock) ~= 'function' then return end
	local window = ns.GlobeWindow()
	local want = window and window:IsShown() and ns.Get('globeTracker') and true or false
	if want then
		docked = pcall(dock, window) and true or false
	elseif docked then
		docked = false
		pcall(dock, nil)
	end
end

local function RouteMenu(owner)
	local window, view = ns.GlobeWindow()
	G.Menu(owner or view, function(root)
		root:CreateTitle('Route')
		if type(Focus) == 'table' and Focus.Available then
			local now = Focus:Get()
			local sub = root:CreateButton('Follow')
			for _, one in ipairs(Focus:Available()) do
				local id = one.id
				if sub.CreateRadio then
					sub:CreateRadio(one.name, function() return Focus:Get() == id end, function() Focus:Set(id) end)
				else
					sub:CreateButton((id == now and '> ' or '') .. one.name, function() Focus:Set(id) end)
				end
			end
		end
		if type(MyRoute) == 'table' and MyRoute.Add then
			local map, x, y = Pin()
			if map then
				root:CreateButton('Add Map Pin To My Route', function()
					if not MyRoute:Add({ kind = 'spot', map = map, x = x, y = y, label = 'Map Pin' }) then
						ns.Print('The map pin is already in My Route.')
					end
				end)
			end
		end
		local editor = rawget(_G, 'PatchwerkForever_Thread_Tracker_OpenMyRoute')
		if type(editor) == 'function' then
			root:CreateButton('Edit My Route', function() editor(window) end)
		end
		if type(TrackerDock()) == 'function' then
			local on = ns.Get('globeTracker')
			if root.CreateCheckbox then
				root:CreateCheckbox('Tracker Beside The Globe', function() return ns.Get('globeTracker') end,
					function() ns.Set('globeTracker', not ns.Get('globeTracker')) end)
			else
				root:CreateButton(on and 'Tracker Back Where I Keep It' or 'Tracker Beside The Globe', function() ns.Set('globeTracker', not on) end)
			end
		end
	end)
end

local button
ns.GlobeOn('show', function()
	local window = ns.GlobeWindow()
	if not button then
		button = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
		button:SetSize(72, 22)
		button:SetPoint('TOPLEFT', window, 'TOPLEFT', 84, -4)
		button:SetText('Route')
		button:SetScript('OnClick', function(self) ns.Try('the globe', RouteMenu, self) end)
	end
	Dock()
end)
ns.GlobeOn('hide', Dock)
ns.GlobeOn('place', Dock)
ns.OnSetting(function(key)
	if key == 'globeTracker' then Dock() end
end)
ns.GlobeOn('key', function(what)
	if what ~= 'route' then return false end
	RouteMenu()
	return true
end)

-- For the checks outside the game.
function ns.QuestsState() return { docked = docked, button = button } end
