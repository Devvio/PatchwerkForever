-- Wayfarer: where to, where from, and keeping the route up to date.
--
-- ns.dest    where the route goes: { map =, x =, y =, pin = true if it came from the map pin }
-- ns.route   the route found: { map =, points = { { x, y, how }, ... }, seconds =, yards =, swum =,
--            flown = { { name, name, ... }, ... }, at = the point the character has reached }
-- x and y are the game's world coordinates (x north, y west), `how` is "walk", "link" or "fly".
local ADDON, ns = ...
local P = ns.Planner

local DATA = {
	[0] = 'PatchwerkForever_Wayfarer_EasternKingdoms',
	[1] = 'PatchwerkForever_Wayfarer_Kalimdor',
	[2991] = 'PatchwerkForever_Wayfarer_ZephrasIsle',
}
local CONTINENT_MAP = { [0] = 1415, [1] = 1414 }     -- the world-map ids of the two continents

local ARRIVED = 12        -- yards from the destination that count as there
local STRAYED = 35        -- yards from the trail before a new route is found
local AGAIN = 3           -- seconds between two searches, at least

P.clock = debugprofilestop

---------------------------------------------------------------------------
-- Listeners (the map and minimap layers)
---------------------------------------------------------------------------
local listeners = {}
function ns.OnRoute(fn) listeners[#listeners + 1] = fn end
local function Changed()
	for _, fn in ipairs(listeners) do
		ns.Try('drawing', fn)
	end
end

---------------------------------------------------------------------------
-- The character, the map data, the flight points
---------------------------------------------------------------------------
local function Place()
	local x, y, _, map = UnitPosition('player')
	if not x then return nil end
	return x, y, map
end
ns.Place = Place

local told = {}
local function Once(key, text)
	if not told[key] then
		told[key] = true
		ns.Print(text)
	end
end

local function Data(map)
	if P.Use(map) then return true end
	local name = DATA[map]
	if not name then
		Once('map' .. tostring(map), 'there is no map data for this place (map ' .. tostring(map) .. ').')
		return false
	end
	local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
	local ok, reason = load(name)
	if P.Use(map) then return true end
	Once('data' .. name, 'the map data "' .. name .. '" could not be loaded (' .. tostring(reason or ok)
		.. '). It is a separate addon: check it is installed and ticked in the addon list.')
	return false
end

local function Side()
	local side = UnitFactionGroup('player')
	return side == 'Alliance' and 'A' or side == 'Horde' and 'H' or nil
end

-- The flight points this character has found: { [id] = true }, or nil for "all of them".
local function Known(map)
	if not ns.Get('knownOnly') then return nil end
	local id = CONTINENT_MAP[map]
	local nodes = id and C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap and C_TaxiMap.GetTaxiNodesForMap(id)
	if type(nodes) ~= 'table' or #nodes == 0 then
		Once('known' .. tostring(map), 'the game did not say which flight points you know here, so all of your side\'s are used.')
		return nil
	end
	local known = {}
	for _, node in ipairs(nodes) do
		if not node.isUndiscovered then known[node.nodeID] = true end
	end
	return known
end

---------------------------------------------------------------------------
-- Searching, a little each frame
---------------------------------------------------------------------------
local job, lastPlan = nil, 0
local runner = CreateFrame('Frame')
runner:Hide()
runner:SetScript('OnUpdate', function()
	if not job then
		runner:Hide()
		return
	end
	P.deadline = debugprofilestop() + P.budget
	local ok, err = coroutine.resume(job)
	if not ok then
		job = nil
		ns.Print('the search stopped on an error: ' .. tostring(err))
	elseif coroutine.status(job) == 'dead' then
		job = nil
	end
end)

local function Duration(seconds)
	if seconds < 90 then return ('%d s'):format(seconds) end
	return ('%d min'):format(math.floor(seconds / 60 + 0.5))
end

local function Say(route)
	local parts = { ('walk %d yd'):format(route.yards) }
	for _, flight in ipairs(route.flown) do
		parts[#parts + 1] = 'fly ' .. table.concat(flight, ' > ')
	end
	local text = Duration(route.seconds) .. ': ' .. table.concat(parts, ', ') .. '.'
	if route.swum > 300 then
		text = text .. (' It swims %d yd: have a look before you trust it.'):format(route.swum)
	end
	if route.short and route.short > 25 then
		text = text .. (' It ends on the nearest ground it knows, %d yd from the spot (a building?).'):format(route.short)
	end
	ns.Print(text)
end

local function Fail(announce, text)
	if ns.route then
		ns.route = nil
		Changed()
	end
	if announce then ns.Print(text) end
end

-- Finds the route to ns.dest from where the character stands. `announce` says it in chat.
function ns.Plan(announce)
	local dest = ns.dest
	if not dest then return end
	local px, py, map = Place()
	if not px then return Fail(announce, 'the game does not say where you are here.') end
	if map ~= dest.map then
		return Fail(announce, 'that is on another continent (or you are indoors): routes across continents come later.')
	end
	if not Data(map) then return Fail(false) end
	lastPlan = GetTime()
	job = coroutine.create(function()
		local sx, sy = P.CellOf(map, px, py)
		sx, sy = P.Nearest(map, sx, sy, 12)
		if not sx then
			return Fail(announce, 'you are not standing on ground the planner knows (inside a building, or on one?).')
		end
		local gx, gy = P.CellOf(map, dest.x, dest.y)
		local tx, ty = gx, gy
		gx, gy = P.Nearest(map, gx, gy, 24)
		if not gx then
			return Fail(announce, 'there is no ground the planner knows within 100 yards of that spot.')
		end
		local opts = {}
		if ns.Get('flights') then
			opts.side = Side()
			opts.known = opts.side and Known(map)
		end
		local found = P.Route(map, sx, sy, gx, gy, opts)
		if not found then
			P.Forget()
			return Fail(announce, 'no way found. The spot may be cut off by something the planner does not know: a lift, a boat, a locked gate.')
		end
		local line = P.Line(map, sx, sy, gx, gy, found)
		local points = {}
		for i, p in ipairs(line.points) do
			local x, y = P.WorldOf(map, p[1], p[2])
			points[i] = { x, y, p[3] }
		end
		points[1][1], points[1][2] = px, py
		local short = math.sqrt((tx - gx) * (tx - gx) + (ty - gy) * (ty - gy)) * 4.1667
		if short < 8 and #points > 1 then
			points[#points][1], points[#points][2] = dest.x, dest.y
		end
		local flown = {}
		for i, flight in ipairs(line.flown) do
			flown[i] = {}
			for k, id in ipairs(flight) do
				flown[i][k] = (P.PointName(map, id):match('^[^,]+')) or tostring(id)
			end
		end
		P.Forget()
		if ns.dest ~= dest then return end        -- the destination changed while this was being found
		ns.route = { map = map, points = points, seconds = line.seconds, yards = line.yards, swum = line.swum,
			flown = flown, at = 1, short = short }
		Changed()
		if announce and ns.Get('notify') then Say(ns.route) end
	end)
	runner:Show()
end

---------------------------------------------------------------------------
-- Following: where on the trail the character is, and noticing a wrong turn
---------------------------------------------------------------------------
local function ToSegment(px, py, a, b)
	local ax, ay, bx, by = a[1], a[2], b[1], b[2]
	local dx, dy = bx - ax, by - ay
	local len = dx * dx + dy * dy
	local t = len > 0 and ((px - ax) * dx + (py - ay) * dy) / len or 0
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	local cx, cy = ax + dx * t - px, ay + dy * t - py
	return math.sqrt(cx * cx + cy * cy)
end

local function NearestOnTrail(route, px, py, from, to)
	local points = route.points
	local best, at
	for i = math.max(1, from), math.min(#points - 1, to) do
		if points[i + 1][3] ~= 'fly' then
			local d = ToSegment(px, py, points[i], points[i + 1])
			if not best or d < best then best, at = d, i end
		end
	end
	return best, at
end

local function Follow()
	local dest = ns.dest
	if not dest or job then return end
	local px, py, map = Place()
	if not px or map ~= dest.map then return end
	local dx, dy = px - dest.x, py - dest.y
	if dx * dx + dy * dy < ARRIVED * ARRIVED then
		ns.Stop(false)
		-- (a guide's steps come one after another: no line in chat for each)
		if ns.Get('notify') and not dest.source then ns.Print('you are there.') end
		return
	end
	if UnitOnTaxi and UnitOnTaxi('player') then return end
	local route = ns.route
	if not route then
		if GetTime() - lastPlan > 10 then ns.Plan(false) end
		return
	end
	local off, at = NearestOnTrail(route, px, py, route.at - 2, route.at + 15)
	if not off or off > STRAYED then
		off, at = NearestOnTrail(route, px, py, 1, #route.points)
	end
	if off and off <= STRAYED then
		if at ~= route.at then
			route.at = at
			Changed()
		end
	elseif GetTime() - lastPlan > AGAIN then
		ns.Plan(false)
	end
end

local ticker
local function Watch(on)
	if on and not ticker then
		ticker = C_Timer.NewTicker(1, function() ns.Try('following', Follow) end)
	elseif not on and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

---------------------------------------------------------------------------
-- Destinations
---------------------------------------------------------------------------
local function PinPlace()
	if not (C_Map and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()) then return nil end
	local point = C_Map.GetUserWaypoint()
	if not (point and point.uiMapID and point.position) then return nil end
	local map, world = C_Map.GetWorldPosFromMapPos(point.uiMapID, point.position)
	if not world then return nil end
	local x, y = world:GetXY()
	return map, x, y
end

-- source: nil for a place you chose (the pin, /wayfarer to), or what chose it for you ('rxp' or 'quest': Sources.lua).
function ns.SetDestination(map, x, y, pin, announce, source)
	ns.dest = { map = map, x = x, y = y, pin = pin, source = source }
	ns.stopped = nil
	Watch(true)
	ns.Plan(announce)
end

-- announce: true when you stopped it yourself. What was stopped is left in ns.stopped for Sources.lua, so it
-- does not at once route to the same guide step again.
function ns.Stop(announce)
	local had = ns.dest
	ns.dest, ns.route, job = nil, nil, nil
	ns.stopped = had and { dest = had, user = announce and true or false } or nil
	Watch(false)
	Changed()
	if announce then ns.Print(had and 'stopped.' or 'there is no route to stop.') end
end

function ns.Go()
	local map, x, y = PinPlace()
	if not map then
		if ns.GoToSource and ns.GoToSource() then return end
		ns.Print('put a pin on the world map or track a quest first, then try again.')
		return
	end
	ns.SetDestination(map, x, y, true, true)
end

function ns.GoToMapSpot(xPercent, yPercent)
	local uiMap = C_Map.GetBestMapForUnit('player')
	if not uiMap then
		ns.Print('the game does not say which map you are on.')
		return
	end
	local map, world = C_Map.GetWorldPosFromMapPos(uiMap, CreateVector2D(xPercent / 100, yPercent / 100))
	if not world then
		ns.Print('the game could not place that spot.')
		return
	end
	local x, y = world:GetXY()
	ns.SetDestination(map, x, y, false, true)
end

local KINDS = { [0] = 'no ground the planner can use', 'walkable ground', 'shallow water', 'deep water' }
function ns.SayWhere()
	local x, y, map = Place()
	if not x then
		ns.Print('the game does not say where you are here.')
		return
	end
	ns.Print(('map %d, world %.1f, %.1f.'):format(map, x, y))
	if not Data(map) then return end
	local cx, cy = P.CellOf(map, x, y)
	ns.Print(('cell %d, %d: %s.'):format(cx, cy, KINDS[P.KindAt(map, cx, cy)] or '?'))
	local nx, ny = P.Nearest(map, cx, cy, 12)
	if nx and (nx ~= cx or ny ~= cy) then
		ns.Print(('nearest usable ground: %d yd away.'):format(math.sqrt((nx - cx) ^ 2 + (ny - cy) ^ 2) * 4.1667))
	end
	P.Forget()
end

---------------------------------------------------------------------------
-- The map pin
---------------------------------------------------------------------------
local function PinChanged(announce)
	if not ns.Get('auto') then return end
	local map, x, y = PinPlace()
	if map then
		ns.SetDestination(map, x, y, true, announce)
	elseif ns.dest and ns.dest.pin then
		ns.Stop(false)
	end
end

ns.On('USER_WAYPOINT_UPDATED', function() PinChanged(true) end)
ns.On('PLAYER_ENTERING_WORLD', function()
	if not ns.dest then PinChanged(false) end
end)
ns.OnSetting(function(key, value)
	if key == 'flights' or key == 'knownOnly' then
		if ns.dest then ns.Plan(true) end
	elseif key == 'auto' and value then
		PinChanged(true)
	end
end)
