-- Thread (Routes): where to, where from, and keeping the route up to date.
--
-- ns.dest    where the route goes: { map =, x =, y =, pin = true if it came from the map pin }
-- ns.route   the route found: { map =, points = { { x, y, how }, ... }, seconds =, yards =, swum =,
--            flown = { { name, name, ... }, ... }, at = the point the character has reached }
-- x and y are the game's world coordinates (x north, y west), `how` is "walk", "link" or "fly".
local ADDON, ns = ...
if not ns.linked then return end
local P = ns.Planner

local DATA = {
	[0] = 'PatchwerkForever_Thread_Routes_EasternKingdoms',
	[1] = 'PatchwerkForever_Thread_Routes_Kalimdor',
	[2991] = 'PatchwerkForever_Thread_Routes_ZephrasIsle',
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
	if not id then return nil end
	local nodes = C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap and C_TaxiMap.GetTaxiNodesForMap(id)
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
	for _, ride in ipairs(route.rides or {}) do
		parts[#parts + 1] = ('%s %s > %s'):format(ride.kind, ride.from, ride.to)
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
	local rides = ns.Get('rides') and ns.Crossings or nil
	if map ~= dest.map and not rides then
		return Fail(announce, 'that is on another continent, and Use Boats And Zeppelins is switched off.')
	end
	if not Data(map) then return Fail(false) end
	if map ~= dest.map and not Data(dest.map) then return Fail(false) end
	lastPlan = GetTime()
	job = coroutine.create(function()
		local sx, sy = P.CellOf(map, px, py)
		sx, sy = P.Nearest(map, sx, sy, 12)
		if not sx then
			return Fail(announce, 'you are not standing on ground the planner knows (inside a building, on a boat, or on one?).')
		end
		local gx, gy = P.CellOf(dest.map, dest.x, dest.y)
		local tx, ty = gx, gy
		gx, gy = P.Nearest(dest.map, gx, gy, 24)
		if not gx then
			return Fail(announce, 'there is no ground the planner knows within 100 yards of that spot.')
		end
		-- walks found by the planner, joined by boats and zeppelins where that is quicker or the only way
		local side, flights, known = Side(), ns.Get('flights'), {}
		local journey = P.Journey({ map = map, x = sx, y = sy }, { map = dest.map, x = gx, y = gy }, {
			rides = rides, side = side,
			use = function(m) return DATA[m] ~= nil and Data(m) end,
			walk = function(m)
				if not flights then return {} end
				if known[m] == nil then known[m] = Known(m) or false end
				return { side = side, known = known[m] or nil }
			end,
		})
		if not journey then
			P.Forget()
			if map ~= dest.map then
				return Fail(announce, 'no way found to that continent: no boat or zeppelin your side can take leads there, or the spot is cut off.')
			end
			return Fail(announce, 'no way found. The spot may be cut off by something the planner does not know: a lift, a boat, a locked gate.')
		end
		local line = P.JourneyLine(journey)
		P.Forget()
		if ns.dest ~= dest then return end        -- the destination changed while this was being found
		-- the part on the map you are on is the one followed; the parts on other maps wait their turn
		local points = line.parts[1].points
		points[1][1], points[1][2] = px, py
		local short = math.sqrt((tx - gx) * (tx - gx) + (ty - gy) * (ty - gy)) * 4.1667
		local last = line.parts[#line.parts].points
		if short < 8 and #last > 1 then
			last[#last][1], last[#last][2] = dest.x, dest.y
		end
		local parts = {}
		for n = 2, #line.parts do
			local part = line.parts[n]
			if part.map ~= map then
				local list = parts[part.map]
				if not list then
					parts[part.map] = part.points
				else                                  -- on that map a second time: joined on, the join not drawn
					part.points[1][3] = 'gap'
					for _, p in ipairs(part.points) do list[#list + 1] = p end
				end
			end
		end
		ns.route = { map = map, points = points, parts = parts, seconds = line.seconds, yards = line.yards,
			swum = line.swum, flown = line.flown, rides = line.rides, at = 1, short = short }
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
		local how = points[i + 1][3]
		if how ~= 'fly' and how ~= 'gap' then
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
	if not px then return end
	if map == dest.map then
		local dx, dy = px - dest.x, py - dest.y
		if dx * dx + dy * dy < ARRIVED * ARRIVED then
			ns.Stop(false)
			-- (a guide's steps come one after another: no line in chat for each)
			if ns.Get('notify') and not dest.source then ns.Print('you are there.') end
			return
		end
	end
	if UnitOnTaxi and UnitOnTaxi('player') then return end
	local route = ns.route
	if not route then
		if GetTime() - lastPlan > 10 then ns.Plan(false) end
		return
	end
	if route.map ~= map then
		-- you have crossed to another map: the part of the journey found for it is followed from here,
		-- or, where there is none (you went somewhere else), the way is found again
		local rest = route.parts and route.parts[map]
		if rest then
			route.parts[map] = nil
			route.map, route.points, route.at = map, rest, 1
			Changed()
		elseif GetTime() - lastPlan > AGAIN then
			ns.Plan(false)
		end
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

-- source: nil for a place you chose (the pin, /thread to), or what chose it for you ('rxp' or 'quest': Sources.lua).
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
-- Whether a place on another map can be gone to at all: boats and zeppelins are on, and the map is one
-- there is data for. (Whether a boat your side can take leads there is only known once it is tried.)
function ns.CanCross(map)
	return ns.Get('rides') and DATA[map] ~= nil
end

ns.OnSetting(function(key, value)
	if key == 'flights' or key == 'knownOnly' or key == 'rides' then
		if ns.dest then ns.Plan(true) end
	elseif key == 'auto' and value then
		PinChanged(true)
	end
end)
