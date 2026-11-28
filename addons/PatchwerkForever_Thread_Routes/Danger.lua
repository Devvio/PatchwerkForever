-- Routes (Thread): going round danger on a PvP ruleset.
--
-- With Avoid Danger on (Auto: while you are flagged for PvP, which on a PvP realm is everywhere but
-- your own faction's lands), the planner counts dangerous ground as slower than it is, so a route
-- goes round it unless the way round is much longer. Four things make ground dangerous:
--
--   the other faction's lands   its towns, guards and NPCs: every spawn point QuestieDB has of an NPC
--                               friendly only to the other faction (guards count three times), and
--                               the zones that are its home ground
--   contested ground            a little, against your own faction's zones
--   enemy players seen          where you were when you saw one (a nameplate, a target, the mouse
--                               over one), fading over FADE_SEEN seconds
--   where players killed you    the place you died soon after seeing an enemy player, fading over FADE_DIED
--                               seconds; kept between sessions (for all your characters)
--
-- It is all given to the planner as one function, ns.DangerPenalty(map): a multiplier, 1 or more,
-- for a place on that continent (world coordinates), asked for each gate a search reaches. The
-- planner keeps routes honest with it: costs only ever go up, so the fastest way is still found
-- where there is no danger. Avoid Danger Strength sets how far round it goes.
--
-- Nothing of it acts in an instance, and the map data's search does the rest (Planner.lua).
local ADDON, ns = ...
if not ns.linked then return end

local CELL = 100              -- yards a side of the squares danger is counted in
local SPREAD = 2              -- squares round an NPC's spot its danger reaches (fading)
local GUARD = 3               -- how much more a guard counts
local FADE_SEEN = 300         -- seconds a hostile player seen is remembered
local FADE_DIED = 3600        -- seconds a death to a player is remembered
local SEEN_WEIGHT, DIED_WEIGHT = 6, 12
local HURT = 30               -- seconds after an enemy player was seen that a death counts as theirs
local FULL = 10               -- danger at which the cost multiplier is at its most
local BATCH = 400             -- NPCs read a frame while the map of danger is built
local CONTESTED, ENEMY = 0.1, 0.5   -- what contested ground and the other faction's zones add, at strength 3

-- Each continent's continent map, for which zone a place is in.
local CONTINENT_MAP = { [0] = 1415, [1] = 1414 }
-- The zones that are each faction's home ground (the game's own maps of them).
local HOME = {
	Horde = { [1411] = true, [1412] = true, [1413] = true, [1420] = true, [1421] = true,
		[1454] = true, [1456] = true, [1458] = true },
	Alliance = { [1426] = true, [1429] = true, [1432] = true, [1436] = true, [1438] = true, [1439] = true,
		[1453] = true, [1455] = true, [1457] = true },
}

local db
local npcGrid = {}            -- [continent] = { [square] = danger } from the other faction's NPCs
local building                -- the coroutine building it, while it runs
local seen = {}               -- { { map, x, y, at }, ... } hostile players seen
local zoneOf = {}             -- [continent] = { [square] = home of 'Horde', 'Alliance', or false }
local hurtAt = -1000          -- when an enemy player was last seen

-- Seconds by the wall clock (kept between sessions), or the game's clock where there is none.
local function Wall()
	local clock = rawget(_G, 'time')
	return type(clock) == 'function' and clock() or GetTime()
end

local function Side() return UnitFactionGroup and UnitFactionGroup('player') or nil end
local function Enemy()
	local side = Side()
	return side == 'Horde' and 'Alliance' or side == 'Alliance' and 'Horde' or nil
end

local function Square(x, y)
	return math.floor((x + 40000) / CELL) * 10000 + math.floor((y + 40000) / CELL)
end

-- Whether danger is avoided now.
function ns.DangerActive()
	local mode = ns.Get('pvpAvoid')
	if mode == 'off' then return false end
	if mode == 'on' then return true end
	return UnitIsPVP and UnitIsPVP('player') and true or false
end

---------------------------------------------------------------------------
-- The other faction's NPCs, from QuestieDB (built once, a little a frame)
---------------------------------------------------------------------------
local function Build()
	local q = ns.Base.QuestDB
	local enemy, mine = Enemy(), Side()
	if not (q and q:Ready() and enemy) then return end
	local lib = rawget(_G, 'LibQuestieDB')
	local ok, ids = pcall(lib.Npc.GetAllIds)
	if not (ok and type(ids) == 'table') then return end
	local letter, own = enemy == 'Horde' and 'H' or 'A', mine == 'Horde' and 'H' or 'A'
	local grids = {}
	for i, npc in ipairs(ids) do
		local to = q.Get('Npc', npc, 'friendlyToFaction')
		if type(to) == 'string' and to:find(letter, 1, true) and not to:find(own, 1, true) then
			local name = tostring(q.Get('Npc', npc, 'name') or '') .. ' ' .. tostring(q.Get('Npc', npc, 'subName') or '')
			local w = (name:find('Guard') or name:find('Grunt') or name:find('Sentinel') or name:find('Protector')) and GUARD or 1
			for _, s in ipairs(q.NpcSpots(npc)) do
				local grid = grids[s[1]]
				if not grid then grid = {}; grids[s[1]] = grid end
				local cx, cy = math.floor((s[2] + 40000) / CELL), math.floor((s[3] + 40000) / CELL)
				for a = -SPREAD, SPREAD do
					for b = -SPREAD, SPREAD do
						local f = w / (1 + a * a + b * b)
						local key = (cx + a) * 10000 + (cy + b)
						grid[key] = (grid[key] or 0) + f
					end
				end
			end
		end
		if i % BATCH == 0 then coroutine.yield() end
	end
	npcGrid = grids
end

local function Step()
	if not building then return end
	local ok, err = coroutine.resume(building)
	if coroutine.status(building) == 'dead' then
		building = nil
		if not ok then ns.Print(('Danger from the other faction could not be read: %s'):format(tostring(err))) end
	end
end

local function StartBuild()
	if building or next(npcGrid) then return end
	building = coroutine.create(Build)
end

---------------------------------------------------------------------------
-- Zones: which faction's home ground a place is
---------------------------------------------------------------------------
local function Home(map, x, y)
	local cont = CONTINENT_MAP[map]
	if not (cont and C_Map and C_Map.GetMapPosFromWorldPos and C_Map.GetMapInfoAtPosition) then return nil end
	local zones = zoneOf[map]
	if not zones then zones = {}; zoneOf[map] = zones end
	local key = math.floor((x + 40000) / 400) * 10000 + math.floor((y + 40000) / 400)
	local known = zones[key]
	if known ~= nil then return known or nil end
	local home = false
	local ok, pos = pcall(C_Map.GetMapPosFromWorldPos, map, CreateVector2D(x, y), cont)
	if ok and pos then
		local got, info = pcall(C_Map.GetMapInfoAtPosition, cont, pos:GetXY())
		local id = got and type(info) == 'table' and info.mapID
		if id then home = (HOME.Horde[id] and 'Horde') or (HOME.Alliance[id] and 'Alliance') or 'contested' end
	end
	zones[key] = home
	return home or nil
end

---------------------------------------------------------------------------
-- Players: seen, and deaths to them
---------------------------------------------------------------------------
local function Saw(unit)
	if not (UnitExists and UnitExists(unit) and UnitIsPlayer and UnitIsPlayer(unit)) then return end
	if not (UnitIsEnemy and UnitIsEnemy('player', unit)) then return end
	local px, py, map = ns.Place()
	if not px then return end
	local now = GetTime()
	hurtAt = now
	-- (one note a place: one seen again near where one was seen is that note made fresh)
	for _, s in ipairs(seen) do
		if s[1] == map and (s[2] - px) ^ 2 + (s[3] - py) ^ 2 < CELL * CELL then s[4] = now; return end
	end
	seen[#seen + 1] = { map, px, py, now }
end

ns.On('NAME_PLATE_UNIT_ADDED', function(unit) Saw(unit) end)
ns.On('PLAYER_TARGET_CHANGED', function() Saw('target') end)
ns.On('UPDATE_MOUSEOVER_UNIT', function() Saw('mouseover') end)

-- A death counts as a death to a player when an enemy player was seen (above) within HURT seconds
-- before it. (The game's log of fights would say who hurt you, but this client does not let an
-- addon listen to it: registering for it gets the addon blocked.)
ns.On('PLAYER_DEAD', function()
	if GetTime() - hurtAt > HURT or not db then return end
	local px, py, map = ns.Place()
	if not px then return end
	local list = db.pvpDeaths
	list[#list + 1] = { map, px, py, Wall() }
end)

ns.On('ADDON_LOADED', function(name)
	if name ~= ADDON then return end
	db = PatchwerkForever_Thread_RoutesDB
	db.pvpDeaths = db.pvpDeaths or {}
	-- (old ones go)
	local now, kept = Wall(), {}
	for _, d in ipairs(db.pvpDeaths) do if now - (d[4] or 0) < FADE_DIED then kept[#kept + 1] = d end end
	db.pvpDeaths = kept
end)

---------------------------------------------------------------------------
-- The planner's penalty
---------------------------------------------------------------------------
-- A function(map, x, y) -> multiplier for the planner, or nil when danger is not avoided now.
function ns.DangerPenalty(map)
	if not ns.DangerActive() then return nil end
	StartBuild()
	local enemy = Enemy()
	local strength = (ns.Get('pvpStrength') or 3) / 3
	local grid = npcGrid[map] or {}
	local now, wall = GetTime(), Wall()
	-- the players seen and deaths on this map, with how much each still counts
	local points = {}
	for _, s in ipairs(seen) do
		local left = 1 - (now - s[4]) / FADE_SEEN
		if s[1] == map and left > 0 then points[#points + 1] = { s[2], s[3], SEEN_WEIGHT * left } end
	end
	for _, d in ipairs(db and db.pvpDeaths or {}) do
		local left = 1 - (wall - (d[4] or 0)) / FADE_DIED
		if d[1] == map and left > 0 then points[#points + 1] = { d[2], d[3], DIED_WEIGHT * left } end
	end
	local reach = CELL * (SPREAD + 1)
	return function(m, x, y)
		if m ~= map then return 1 end
		local danger = grid[Square(x, y)] or 0
		for _, p in ipairs(points) do
			local d2 = (p[1] - x) ^ 2 + (p[2] - y) ^ 2
			if d2 < reach * reach then danger = danger + p[3] / (1 + d2 / (CELL * CELL)) end
		end
		local add = math.min(danger, FULL) / FULL * 2
		local home = Home(map, x, y)
		if home == enemy then add = add + ENEMY elseif home == 'contested' then add = add + CONTESTED end
		return 1 + add * strength
	end
end

-- (for /thread where and the checks: the danger here)
function ns.DangerHere()
	local px, py, map = ns.Place()
	local pen = px and ns.DangerPenalty(map)
	return pen and pen(map, px, py) or 1
end

ns.On('PLAYER_LOGIN', function()
	C_Timer.NewTicker(0.1, function() ns.Try('reading danger', Step) end)
end)

-- (for the checks: the build run to its end at once)
function ns.DangerBuildNow()
	StartBuild()
	while building do Step() end
end
