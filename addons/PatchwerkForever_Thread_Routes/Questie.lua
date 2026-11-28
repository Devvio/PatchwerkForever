-- Routes (Thread): QuestieDB.
--
-- With QuestieDB installed (it comes with Questie), the base asks it where quests are (the base's
-- QuestieDB.lua): a tracked quest is routed to the nearest spot of what it still needs (the NPC to
-- kill, the object to use, an NPC that drops the item) or to whoever takes it in, instead of the
-- middle of the game's quest area; a guide step that only names a quest goes to its giver or turn-in.
-- This file adds three things of Routes' own:
--
--   the setting      Use QuestieDB turns all of that off and on (for every tool of the family)
--   spots on maps    every spot of the quest being followed, on the minimap and the world map, the
--                    one gone to larger: the other places the same mob or object is
--   quest givers     /thread givers: to the nearest quest giver with a quest you can take now, then
--                    the next. A side path, as a gathering run or a flight point search is (source
--                    'givers'): a giver is left behind once you have taken its quests or walked away.
--
-- Which quests you can take now is Questie's own check where Questie runs; else the base's (level,
-- race, class, quests done before; quests asking for a skill or reputation are left out).
local ADDON, ns = ...
if not ns.linked then return end

local AWAY = 40               -- yards you must walk from a giver you reached before the run goes on
local MINI_SIZE, MINI_MOST = 8, 80
local MAP_SIZE, MAP_MOST = 9, 300
local GOING = 1.6             -- how much larger the spot gone to is drawn

local function QuestDB()
	local db = ns.Base.QuestDB
	if db and db:Ready() then return db end
	return nil
end

---------------------------------------------------------------------------
-- The spots of what is followed
---------------------------------------------------------------------------
-- The spots to show for the destination: a list of spots ({ map, x, y }) and the colour, or nothing.
local function Shown()
	local dest = ns.dest
	if not dest then return nil end
	if dest.giverSpots then return dest.giverSpots, 'giver' end
	local q = dest.questie
	local db = q and QuestDB()
	if not db then return nil end
	local spots, mode = db.Spots(q.quest, q.mode, q.obj)
	if not (spots and spots[1]) then return nil end
	return spots, mode
end

local COLOUR = {
	objective = { 1, 0.82, 0.1 },
	turnin = { 0.35, 0.85, 1 },
	giver = { 1, 0.95, 0.35 },
}

local function Dot(pool, n, parent, size)
	local dot = pool[n]
	if not dot then
		dot = parent:CreateTexture(nil, 'ARTWORK')
		dot:SetTexture('Interface\\AddOns\\' .. ADDON .. '\\Media\\dot')
		pool[n] = dot
	end
	dot:SetSize(size, size)
	return dot
end

local function Paint(dot, mode, going)
	local c = COLOUR[mode] or COLOUR.objective
	dot:SetVertexColor(c[1], c[2], c[3], going and 1 or 0.8)
end

local function IsGoing(spot)
	local dest = ns.dest
	return dest and spot[1] == dest.map and math.abs(spot[2] - dest.x) < 1 and math.abs(spot[3] - dest.y) < 1
end

-- on the minimap
local mini, miniDots, miniShown = nil, {}, 0

local function MiniDraw()
	for i = 1, miniShown do miniDots[i]:Hide() end
	miniShown = 0
	if not ns.Get('questieMinimap') then return end
	local spots, mode = Shown()
	if not spots then return end
	if not mini then mini = ns.MinimapLayer() end
	local px, py, map, perYard, sin, cos, radius = ns.MinimapView(mini, 7)
	if not px then return end
	local square = GetMinimapShape and GetMinimapShape() == 'SQUARE'
	local edge = radius - MINI_SIZE / 2
	for _, spot in ipairs(spots) do
		if miniShown >= MINI_MOST then break end
		if spot[1] == map then
			local east, north = (py - spot[3]) * perYard, (spot[2] - px) * perYard
			local x, y = east * cos + north * sin, north * cos - east * sin
			local inside
			if square then inside = math.abs(x) <= edge and math.abs(y) <= edge else inside = x * x + y * y <= edge * edge end
			if inside then
				miniShown = miniShown + 1
				local going = IsGoing(spot)
				local dot = Dot(miniDots, miniShown, mini, going and MINI_SIZE * GOING or MINI_SIZE)
				Paint(dot, mode, going)
				dot:ClearAllPoints()
				dot:SetPoint('CENTER', mini, 'CENTER', x, y)
				dot:Show()
			end
		end
	end
	return true
end

local redraws = ns.MinimapRedraws('the QuestieDB spots', function()
	if not MiniDraw() and mini then mini:Hide() end
end)

-- on the world map
local layer, mapDots, mapShown = nil, {}, 0

local function MapDraw(letGo)
	for i = 1, mapShown do mapDots[i]:Hide() end
	mapShown = 0
	if letGo or not ns.Get('questieWorldMap') then return end
	local spots, mode = Shown()
	if not spots then return end
	local view = ns.WorldMapView()
	if not view then return end
	if not layer then
		layer = CreateFrame('Frame', nil, view.canvas)
		layer:SetAllPoints(view.canvas)
	end
	layer:SetFrameLevel(view.level + 1)
	local size = MAP_SIZE / view.scale
	for _, spot in ipairs(spots) do
		if mapShown >= MAP_MOST then break end
		if spot[1] == view.map then
			local u, v = view.at(spot[2], spot[3])
			if u >= 0 and u <= 1 and v >= 0 and v <= 1 then
				mapShown = mapShown + 1
				local going = IsGoing(spot)
				local dot = Dot(mapDots, mapShown, layer, going and size * GOING or size)
				Paint(dot, mode, going)
				dot:ClearAllPoints()
				dot:SetPoint('CENTER', layer, 'TOPLEFT', u * view.width, -v * view.height)
				dot:Show()
			end
		end
	end
end

local function Refresh()
	local want = ns.Get('questieMinimap') and Shown() ~= nil
	redraws.Dirty()
	redraws.On(want and true or false)
	if not want then
		for i = 1, miniShown do miniDots[i]:Hide() end
		miniShown = 0
		if mini then mini:Hide() end
	end
end

---------------------------------------------------------------------------
-- Quest givers
---------------------------------------------------------------------------
-- nil, or { going = the giver gone to (an entry of QuestDB.Givers), at = true once reached,
-- left = { [kind .. id] = true } for givers done with or not reached }
local state

local function Key(giver) return giver.kind .. giver.id end

-- Whether a giver still has a quest for you that you have not taken.
local function StillGives(giver)
	local db = QuestDB()
	if not db then return false end
	for _, entry in ipairs(db.Givers() or {}) do
		if entry.kind == giver.kind and entry.id == giver.id then return true end
	end
	return false
end

-- The nearest giver not left out, and its nearest spot.
local function Pick()
	local db = QuestDB()
	if not db then return nil, 'none' end
	local px, py, map = ns.Place()
	if not px then return false end
	local best, bestSpot, far
	for _, giver in ipairs(db.Givers() or {}) do
		if not state.left[Key(giver)] then
			for _, spot in ipairs(giver.spots) do
				if spot[1] == map then
					local d = (spot[2] - px) ^ 2 + (spot[3] - py) ^ 2
					if not far or d < far then best, bestSpot, far = giver, spot, d end
				end
			end
		end
	end
	return best, bestSpot
end

local function Names(giver)
	local db = ns.Base.QuestDB
	local names = {}
	for i, q in ipairs(giver.quests) do
		if i > 3 then names[#names + 1] = ('and %d more'):format(#giver.quests - 3); break end
		names[#names + 1] = tostring(db and db.Get('Quest', q, 'name') or ('quest ' .. q))
	end
	return table.concat(names, ', ')
end

local function Go()
	local giver, spot = Pick()
	if giver == false then return end                    -- (no position here: tried again at the next look)
	if not giver then
		state = nil
		ns.Print('No more quest givers with a quest for you on this continent.')
		return
	end
	state.going, state.at = giver, nil
	local spots = {}
	for _, s in ipairs(giver.spots) do spots[#spots + 1] = s end
	ns.SetDestination(spot[1], spot[2], spot[3], false, false, 'givers', {
		lines = { ('%s: %s'):format(tostring(giver.name or 'Quest giver'), Names(giver)) },
		chosen = true, giverSpots = spots,
	})
end

local function Stop()
	local was = state
	state = nil
	if ns.dest and ns.dest.source == 'givers' then
		ns.Stop(false)
		ns.stopped = nil
	end
	return was ~= nil
end

local function Start()
	local db = QuestDB()
	if not db then
		ns.Print('QuestieDB is not installed or Use QuestieDB is off: quest givers cannot be found.')
		return false
	end
	if not ns.Place() then
		ns.Print('Your position is not available here.')
		return false
	end
	local list = db.Givers() or {}
	if #list == 0 then
		ns.Print('No quest giver on this continent has a quest you can take now.')
		return false
	end
	state = { left = {} }
	-- One side path at a time: this ends a gathering run, a flight point search and a selected quest.
	if ns.GatherActive and ns.GatherActive() and ns.GatherStop() then ns.Print('Gathering stopped.') end
	if ns.DiscoverActive and ns.DiscoverActive() and ns.DiscoverStop() then ns.Print('Flight point search stopped.') end
	local Choice = ns.Base.Choice
	if Choice and Choice.Get and Choice:Get() and Choice.Clear then Choice:Clear() end
	Go()
	return state ~= nil
end

function ns.GiversActive() return state ~= nil end

-- For the tracker: nil while no QuestieDB; else { near = givers with a quest for you on this continent,
-- going = the giver gone to's name (a run on), quests = how many it has }.
function ns.GiversInfo()
	local db = QuestDB()
	if not db then return nil end
	local list = db.Givers() or {}
	local info = { near = #list }
	if state and state.going then
		info.going = state.going.name or 'Quest giver'
		info.quests = #state.going.quests
	end
	return info
end
function ns.GiversStop() return Stop() end

-- Once a second: a giver whose quests you have taken, or that you walked away from, is left behind.
local function Watch()
	if not state then return end
	if ns.CorpseActive and ns.CorpseActive() then return end
	local dest, going = ns.dest, state.going
	local mine = dest ~= nil and dest.source == 'givers'
	if dest and not mine then return end                 -- a pin of your own, which comes first
	if mine then
		if dest.failed and going then                     -- no way there: the next one
			state.left[Key(going)] = true
			Go()
			if not state then ns.Stop(false); ns.stopped = nil end
			return
		end
		if going and not StillGives(going) then          -- its quests taken: the next one
			state.left[Key(going)] = true
			ns.Stop(false)
			ns.stopped = nil
			Go()
		end
		return
	end
	local stopped = ns.stopped
	if stopped and stopped.dest and stopped.dest.source == 'givers' then
		ns.stopped = nil
		if stopped.user then state = nil; return end     -- you stopped it yourself
		if going and not state.at then
			state.at = { stopped.dest.x, stopped.dest.y, stopped.dest.map }
			if ns.Get('notify') then ns.Print(('You have arrived at %s.'):format(tostring(going.name or 'the quest giver'))) end
		end
	end
	if going and state.at then
		local px, py, map = ns.Place()
		local at = state.at
		local gone = not StillGives(going)
		if not gone and (not px or (map == at[3] and (px - at[1]) ^ 2 + (py - at[2]) ^ 2 <= AWAY * AWAY)) then return end
		state.left[Key(going)] = true
	end
	Go()
end

-- /thread givers, /thread givers stop
function ns.GiversSay(rest)
	rest = (rest or ''):gsub('^%s+', ''):gsub('%s+$', '')
	if rest == 'stop' then
		ns.Print(Stop() and 'Quest giver run stopped.' or 'No quest giver run is active.')
	elseif rest == '' then
		if Start() then
			ns.Print('Quest giver run started: nearest quest giver with a quest you can take first, then the next. /thread givers stop ends it.')
		end
	else
		ns.Print('Usage: /thread givers, or /thread givers stop.')
	end
end

---------------------------------------------------------------------------
-- Setting up
---------------------------------------------------------------------------
local function Apply()
	local db = ns.Base.QuestDB
	if db and db.SetEnabled then db:SetEnabled(ns.Get('questie')) end
end
Apply()   -- (before any look: the base's default is on)

ns.On('PLAYER_LOGIN', function()
	Apply()
	if ns.OnWorldMapDraw then ns.OnWorldMapDraw(MapDraw) end
	if ns.OnRoute then ns.OnRoute(function() Refresh() end) end
	Refresh()
	C_Timer.NewTicker(1, function() ns.Try('the quest giver run', Watch) end)
end)

ns.OnSetting(function(key)
	if key == 'questie' then
		Apply()
		if not ns.Get('questie') and state then Stop() end
	end
	if key == 'questie' or key == 'questieMinimap' then Refresh() end
	if (key == 'questie' or key == 'questieWorldMap') and ns.RedrawWorldMap then ns.RedrawWorldMap() end
end)

-- A quest or a list you select is a side path too: it ends the run. (A gathering run or flight point
-- search started ends it in their own files.)
local Choice = ns.Base.Choice
if Choice and Choice.OnChange then
	Choice:OnChange(function(choice)
		if choice and state then Stop() end
	end)
end
