-- Routes (Thread): the flight points this character knows.
--
-- A route may only fly between flight points you have found. Which those are is learned three ways,
-- the surest first:
--
--   at a flight master   When you open a flight map, the game lists every point with whether you can
--                        fly to it. That is remembered for this character. A point of that continent
--                        the map does not list, or lists as out of reach, is one you do not have.
--   as you find one      The game's "new flight path discovered" message marks the flight point you
--                        are standing at as known.
--   the world map        Before you have opened a flight map on a continent, what the game's world
--                        map says of its flight points is used. If it ever says you know a point
--                        that a flight map then shows you do not, it is not believed again.
--
-- With none of these (a continent you have opened no flight map on, and the game saying nothing),
-- no flight point counts as known and routes go on foot. That is said once, with what to do.
--
-- The flight point search (Discover.lua) asks here for the points you lack, and takes only a flight
-- map's word for it: until one has been opened on a continent, a point you have not discovered cannot
-- be told from one that was never read.
--
-- Kept in PatchwerkForever_Thread_RoutesDB.taxi, by character:
--     { known = { [flight point] = true or false }, seen = { [continent] = true }, gameWrong = true }
local ADDON, ns = ...
if not ns.linked then return end

local P = ns.Planner
local CONTINENT_MAP = ns.CONTINENT_MAP                -- the world-map ids of the two continents (Route.lua)
local NEAR = 60               -- cells (about 250 yards) within which a point just found is the one you stand at
local Ask, Side = ns.Ask, ns.Side

-- What is remembered for this character.
local function Mine()
	local db = rawget(_G, 'PatchwerkForever_Thread_RoutesDB')
	if type(db) ~= 'table' then
		db = {}
		_G.PatchwerkForever_Thread_RoutesDB = db
	end
	if type(db.taxi) ~= 'table' then db.taxi = {} end
	local who = Ask(UnitGUID, 'player') or 'character'
	local mine = db.taxi[who]
	if type(mine) ~= 'table' then
		mine = {}
		db.taxi[who] = mine
	end
	mine.known = type(mine.known) == 'table' and mine.known or {}
	mine.seen = type(mine.seen) == 'table' and mine.seen or {}
	return mine
end

-- The flight points of a continent, from its map data (when that is loaded): { { id, name, x, y, sides ... } }.
local function Points(map)
	local data = rawget(_G, 'PatchwerkForever_Thread_RoutesData')
	local D = type(data) == 'table' and data[map]
	return type(D) == 'table' and type(D.points) == 'table' and D.points or {}
end

-- What the game's world map says: { [flight point] = true when known }, or nothing when it says nothing.
local function GameSays(map)
	local id = CONTINENT_MAP[map]
	local nodes = id and C_TaxiMap and Ask(C_TaxiMap.GetTaxiNodesForMap, id)
	if type(nodes) ~= 'table' or #nodes == 0 then return nil end
	local says = {}
	for _, node in ipairs(nodes) do
		if type(node) == 'table' and node.nodeID then says[node.nodeID] = not node.isUndiscovered end
	end
	return says
end

-- The flight points of a continent this character knows: { [flight point] = true }, and whether
-- anything at all was known of that continent (false: the list is empty for want of knowing).
function ns.FlightsKnown(map)
	local mine = Mine()
	local game = not mine.gameWrong and GameSays(map) or nil
	local known = {}
	if not (mine.seen[map] or game) then
		-- (a point found since login still counts)
		for id, yes in pairs(mine.known) do
			if yes then known[id] = true end
		end
		return known, false
	end
	for _, p in ipairs(Points(map)) do
		local id = p[1]
		local yes = mine.known[id]
		-- (not remembered: after a flight map was seen here it is one you do not have; before, the world map's word)
		if yes == nil and not mine.seen[map] then yes = game and game[id] end
		if yes then known[id] = true end
	end
	return known, true
end

-- Whether a flight point of this name (as a guide names it: "Orgrimmar") is one you do not have.
-- Returns true and the point's full name; false when you have it, or when no such point is known of.
function ns.FlightMissing(name)
	if type(name) ~= 'string' or name == '' or not ns.Get('knownOnly') then return false end
	local want, side = name:upper(), Side()
	for map in pairs(CONTINENT_MAP) do
		for _, p in ipairs(Points(map)) do
			local full = tostring(p[2]):upper()
			if (full == want or full:match('^([^,]+)') == want) and (not side or tostring(p[5]):find(side, 1, true)) then
				return not ns.FlightsKnown(map)[p[1]], p[2]
			end
		end
	end
	return false
end

-- The flight points of your side on a continent that you have not discovered: { point, ... }, each as
-- the map data has it ({ id, name, cell x, cell y, sides, walked to or not, ... }). Then whether a
-- flight map has been opened on that continent: only then is a point that is not known one you lack,
-- and not one that was never read (the world map's word is not taken for this). Then whether the
-- continent has flight points of your side at all. For the flight point search (Discover.lua).
function ns.FlightsLacking(map)
	local mine, side = Mine(), Side()
	local lacking, any = {}, false
	for _, p in ipairs(Points(map)) do
		if not side or tostring(p[5]):find(side, 1, true) then
			any = true
			if mine.known[p[1]] ~= true then lacking[#lacking + 1] = p end
		end
	end
	return lacking, mine.seen[map] == true, any
end

-- Whether a flight point is remembered as one you have (asked every second while a search is on).
function ns.FlightHave(id)
	return Mine().known[id] == true
end

local function Changed()
	if ns.dest and ns.Plan then ns.Try('a new route', ns.Plan, false) end
end

---------------------------------------------------------------------------
-- At a flight master: the flight map says what you have
---------------------------------------------------------------------------
local function AtFlightMaster()
	local mine = Mine()
	local _, _, map = ns.Place()
	local out = Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable or 2
	local listed, any = {}, false
	local uiMap = Ask(rawget(_G, 'GetTaxiMapID'))
	local nodes = uiMap and C_TaxiMap and Ask(C_TaxiMap.GetAllTaxiNodes, uiMap)
	for _, node in ipairs(type(nodes) == 'table' and nodes or {}) do
		if type(node) == 'table' and node.nodeID and node.state ~= nil then
			listed[node.nodeID] = node.state ~= out
			any = true
		end
	end
	if not any then
		-- (a client that lists them the old way: by number, with a name and a kind)
		local byName = {}
		for _, p in ipairs(Points(map)) do byName[tostring(p[2])] = p[1] end
		for i = 1, Ask(rawget(_G, 'NumTaxiNodes')) or 0 do
			local id = byName[Ask(rawget(_G, 'TaxiNodeName'), i) or false]
			local kind = Ask(rawget(_G, 'TaxiNodeGetType'), i)
			if id and kind then
				listed[id] = (kind == 'CURRENT' or kind == 'REACHABLE')
				any = true
			end
		end
	end
	if not any or map == nil then return end
	local was = {}
	for id, yes in pairs(mine.known) do was[id] = yes end
	for _, p in ipairs(Points(map)) do
		mine.known[p[1]] = listed[p[1]] == true
	end
	for id, yes in pairs(listed) do
		if mine.known[id] == nil then mine.known[id] = yes end
	end
	-- (the first time on this continent: said, as the notice that asked you to open the flight map is)
	if not mine.seen[map] then
		local count = 0
		for _, yes in pairs(listed) do
			if yes then count = count + 1 end
		end
		ns.Print(('Flight map read: %d flight points known on this continent.'):format(count))
	end
	mine.seen[map] = true
	-- (the world map said you had one the flight map shows you do not: its word is not taken again)
	local game = GameSays(map)
	for id, yes in pairs(game or {}) do
		if yes and mine.known[id] == false then mine.gameWrong = true end
	end
	for _, p in ipairs(Points(map)) do
		if was[p[1]] ~= mine.known[p[1]] then return Changed() end
	end
end

---------------------------------------------------------------------------
-- A flight point found as you walk up to it
---------------------------------------------------------------------------
local function Found()
	local px, py, map = ns.Place()
	if not px or not P or not P.CellOf then return end
	-- (the map data, where no route has loaded it yet: a point found before any route is remembered too)
	if ns.Data and not ns.Data(map) then return end
	local cx, cy = Ask(P.CellOf, map, px, py)
	if not cx then return end
	local side, best, far = Side(), nil, nil
	for _, p in ipairs(Points(map)) do
		if not side or tostring(p[5]):find(side, 1, true) then
			local d = (p[3] - cx) ^ 2 + (p[4] - cy) ^ 2
			if d <= NEAR * NEAR and (not far or d < far) then best, far = p, d end
		end
	end
	if not best then return end
	local mine = Mine()
	if mine.known[best[1]] == true then return end
	mine.known[best[1]] = true
	if ns.Get('notify') then ns.Print(('Flight point discovered: %s.'):format(tostring(best[2]))) end
	Changed()
end

ns.Try('listening for TAXIMAP_OPENED', ns.On, 'TAXIMAP_OPENED', function() ns.Try('reading the flight map', AtFlightMaster) end)
ns.Try('listening for UI_INFO_MESSAGE', ns.On, 'UI_INFO_MESSAGE', function(_, message)
	local found = rawget(_G, 'ERR_NEWTAXIPATH')
	if type(found) == 'string' and message == found then ns.Try('a flight point found', Found) end
end)

-- /thread flights: what is known, and from where.
function ns.FlightsSay()
	local _, _, map = ns.Place()
	if map == nil then
		ns.Print('Your position is not available here.')
		return
	end
	if not ns.Get('flights') then
		ns.Print('Use Flight Paths is disabled: routes do not fly.')
		return
	end
	-- (the map data holds the flight points: loaded first, where no route has loaded it yet)
	if ns.Data and not ns.Data(map, true) then return end
	if #Points(map) == 0 then
		ns.Print('No flight points on this map.')
		return
	end
	local mine = Mine()
	local known, sure = ns.FlightsKnown(map)
	local side, have, lack = Side(), {}, {}
	for _, p in ipairs(Points(map)) do
		if not side or tostring(p[5]):find(side, 1, true) then
			local list = known[p[1]] and have or lack
			list[#list + 1] = tostring(p[2])
		end
	end
	table.sort(have)
	table.sort(lack)
	if not ns.Get('knownOnly') then
		ns.Print('Known Flight Points Only is disabled: routes use every flight point of your faction.')
	end
	ns.Print(('Flight points on this continent: %d known, %d not.'):format(#have, #lack))
	if mine.seen[map] then
		ns.Print('Source: the flight map you last opened here, and points found since.')
	elseif sure then
		ns.Print('Source: the game\'s world map. Open a flight map at any flight master to confirm it.')
	else
		ns.Print('Source: none yet. Open a flight map at any flight master' .. (ns.Get('knownOnly') and '; until then routes go on foot.' or '.'))
	end
	if #have > 0 then ns.Print('  Known: ' .. table.concat(have, '; ') .. '.') end
	if #lack > 0 then ns.Print('  Not known: ' .. table.concat(lack, '; ') .. '.') end
end
