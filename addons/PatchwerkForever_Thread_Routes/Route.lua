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
		Once('map' .. tostring(map), 'No map data for this area (map ' .. tostring(map) .. ').')
		return false
	end
	local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
	local ok, reason = load(name)
	if P.Use(map) then return true end
	Once('data' .. name, 'Map data "' .. name .. '" could not be loaded (' .. tostring(reason or ok)
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
		Once('known' .. tostring(map), 'Known flight points are not available here, so all of your faction\'s flight points are used.')
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
-- job: the search for the route you are on. It comes first. Behind it, one at a time and only while
-- there is no job, run the searches that can wait (ns.SearchLater: the ways between the guide's next
-- steps, Ahead.lua). A job that starts while one of those is under way puts it back to wait.
local job, lastPlan = nil, 0
local waiting, behind, behindAsk = {}, nil, nil
local Search
local runner = CreateFrame('Frame')
runner:Hide()
runner:SetScript('OnUpdate', function()
	if job then
		P.deadline = debugprofilestop() + P.budget
		local ok, err = coroutine.resume(job)
		if not ok then
			job = nil
			ns.Print('Route search failed: ' .. tostring(err))
		elseif coroutine.status(job) == 'dead' then
			job = nil
		end
		return
	end
	if not behind then
		local ask = table.remove(waiting, 1)
		while ask and ask.want and not ask.want() do          -- (no longer wanted: the guide moved on)
			ask = table.remove(waiting, 1)
		end
		if not ask then
			runner:Hide()
			return
		end
		behindAsk = ask
		behind = coroutine.create(function()
			local route = Search(ask.from, ask.to, ask.opts or {})
			ask.done(route)
		end)
	end
	P.deadline = debugprofilestop() + P.budget
	local ok, err = coroutine.resume(behind)
	if not ok then
		behind, behindAsk = nil, nil
		P.Forget()
		ns.Try('a search ahead', error, tostring(err), 0)     -- (said once, not thrown)
	elseif coroutine.status(behind) == 'dead' then
		behind, behindAsk = nil, nil
	end
end)

-- A search that can wait. from, to: { map =, x =, y = } in world coordinates. done(route) is called with
-- the route, or with nothing when there is no way. want(), when given, is asked just before the search
-- starts: false drops it.
function ns.SearchLater(from, to, opts, done, want)
	waiting[#waiting + 1] = { from = from, to = to, opts = opts, done = done, want = want }
	runner:Show()
end

local function Duration(seconds)
	if seconds < 90 then return ('%d s'):format(seconds) end
	return ('%d min'):format(math.floor(seconds / 60 + 0.5))
end

-- A route in a few words: how long, how far on foot, and what it flies or rides.
local function Summary(route)
	local parts = { ('walk %d yd'):format(route.yards) }
	for _, flight in ipairs(route.flown) do
		parts[#parts + 1] = 'fly ' .. table.concat(flight, ' > ')
	end
	for _, ride in ipairs(route.rides or {}) do
		parts[#parts + 1] = ('%s %s > %s'):format(ride.kind, ride.from, ride.to)
	end
	return Duration(route.seconds) .. ': ' .. table.concat(parts, ', ')
end
ns.Summary = Summary

local function Say(route)
	local text = Summary(route) .. '.'
	if route.swum > 300 then
		text = text .. (' Includes %d yd of swimming; check it before relying on it.'):format(route.swum)
	end
	if route.short and route.short > 25 then
		text = text .. (' Ends at the nearest known ground, %d yd from the destination (possibly a building).'):format(route.short)
	end
	ns.Print(text)
end

local function Fail(announce, text)
	if ns.route then
		ns.route = nil
		Changed()
	end
	if announce and text then ns.Print(text) end
end

-- A destination you have just been given is described on screen once its route is known (Float.lua):
-- not again when the way is found anew after a wrong turn.
local function Fresh(dest, route)
	if dest and dest.fresh then
		dest.fresh = nil
		if ns.FloatRoute then ns.Try('the step on screen', ns.FloatRoute, dest, route) end
	end
end

-- Finds the way from one place to another. It is run inside a search (a coroutine) and gives up its
-- turn as it goes. from, to: { map =, x =, y = } in world coordinates. opts.walkOnly: on foot (no
-- flights, and no boats where both ends are on one map). Returns the route, or nothing and why not
-- (no reason given: the map data could not be had, which has been said already).
Search = function(from, to, opts)
	local map = from.map
	local rides = ns.Get('rides') and ns.Crossings or nil
	if map ~= to.map and not rides then
		return nil, 'That location is on another continent, and Use Boats And Zeppelins is disabled.'
	end
	if not Data(map) then return nil end
	if map ~= to.map and not Data(to.map) then return nil end
	if opts.walkOnly and map == to.map then rides = nil end
	local sx, sy = P.CellOf(map, from.x, from.y)
	sx, sy = P.Nearest(map, sx, sy, 12)
	if not sx then
		return nil, 'you are not standing on ground the planner knows (inside a building, on a boat, or on one?).'
	end
	local gx, gy = P.CellOf(to.map, to.x, to.y)
	local tx, ty = gx, gy
	gx, gy = P.Nearest(to.map, gx, gy, 24)
	if not gx then
		return nil, 'No known walkable ground within 100 yards of that location.'
	end
	-- walks found by the planner, joined by boats and zeppelins where that is quicker or the only way
	local side, flights, known = Side(), ns.Get('flights') and not opts.walkOnly, {}
	local journey = P.Journey({ map = map, x = sx, y = sy }, { map = to.map, x = gx, y = gy }, {
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
		if map ~= to.map then
			return nil, 'No route found to that continent: no boat or zeppelin available to your faction goes there, or the location is unreachable.'
		end
		return nil, 'No route found. The location may be unreachable by something the planner does not know: a lift, a boat or a locked gate.'
	end
	local line = P.JourneyLine(journey)
	P.Forget()
	-- the part on the map it starts on is the one followed; the parts on other maps wait their turn
	local points = line.parts[1].points
	points[1][1], points[1][2] = from.x, from.y
	local short = math.sqrt((tx - gx) * (tx - gx) + (ty - gy) * (ty - gy)) * 4.1667
	local last = line.parts[#line.parts].points
	if short < 8 and #last > 1 then
		last[#last][1], last[#last][2] = to.x, to.y
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
	return { map = map, points = points, parts = parts, seconds = line.seconds, yards = line.yards,
		swum = line.swum, flown = line.flown, rides = line.rides, at = 1, short = short,
		to = { map = to.map, x = to.x, y = to.y } }
end

-- Finds the route to ns.dest from where the character stands. `announce` says it in chat.
function ns.Plan(announce)
	local dest = ns.dest
	if not dest then return end
	local px, py, map = Place()
	if not px then
		Fresh(dest)
		return Fail(announce, 'Your position is not available here.')
	end
	if map ~= dest.map and not (ns.Get('rides') and ns.Crossings) then
		Fresh(dest)
		return Fail(announce, 'That location is on another continent, and Use Boats And Zeppelins is disabled.')
	end
	if not Data(map) or (map ~= dest.map and not Data(dest.map)) then
		Fresh(dest)
		return Fail(false)
	end
	lastPlan = GetTime()
	if behind then
		-- a search that can wait is under way: it goes back to wait, and starts over later
		table.insert(waiting, 1, behindAsk)
		behind, behindAsk = nil, nil
		P.Forget()
	end
	job = coroutine.create(function()
		local route, why = Search({ map = map, x = px, y = py }, dest, { walkOnly = dest.walkOnly })
		if ns.dest ~= dest then return end        -- the destination changed while this was being found
		if not route then
			Fail(announce, why)
		else
			ns.route = route
			Changed()
			if announce and ns.Get('notify') then Say(route) end
		end
		Fresh(dest, route)
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
			if ns.Get('notify') and not dest.source then ns.Print('You have arrived.') end
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
-- more: what else is known of it (Sources.lua): lines, the words that describe it on screen; kind, what
-- a guide's step asks for; walkOnly, to be gone to on foot.
function ns.SetDestination(map, x, y, pin, announce, source, more)
	local dest = { map = map, x = x, y = y, pin = pin, source = source, fresh = true }
	for key, value in pairs(more or {}) do
		dest[key] = value
	end
	ns.dest = dest
	ns.stopped = nil
	Watch(true)
	-- the way to a guide's next step may have been found already, while you were on the step before
	local ready = ns.Ahead and ns.Ahead.Take(dest)
	if ready then
		job = nil
		lastPlan = GetTime()
		ns.route = ready
		Changed()
		if announce and ns.Get('notify') then Say(ready) end
		Fresh(dest, ready)
		return
	end
	ns.Plan(announce)
end
ns.RouteChanged = Changed

-- announce: true when you stopped it yourself. What was stopped is left in ns.stopped for Sources.lua, so it
-- does not at once route to the same guide step again.
function ns.Stop(announce)
	local had = ns.dest
	ns.dest, ns.route, job = nil, nil, nil
	ns.stopped = had and { dest = had, user = announce and true or false } or nil
	Watch(false)
	Changed()
	if announce then ns.Print(had and 'Routing stopped.' or 'No active route.') end
end

function ns.Go()
	local map, x, y = PinPlace()
	if not map then
		if ns.GoToSource and ns.GoToSource() then return end
		ns.Print('Place a map pin or track a quest first.')
		return
	end
	ns.SetDestination(map, x, y, true, true)
end

function ns.GoToMapSpot(xPercent, yPercent)
	local uiMap = C_Map.GetBestMapForUnit('player')
	if not uiMap then
		ns.Print('Your current map is not available.')
		return
	end
	local map, world = C_Map.GetWorldPosFromMapPos(uiMap, CreateVector2D(xPercent / 100, yPercent / 100))
	if not world then
		ns.Print('Those coordinates could not be resolved.')
		return
	end
	local x, y = world:GetXY()
	ns.SetDestination(map, x, y, false, true)
end

local KINDS = { [0] = 'not walkable', 'walkable ground', 'shallow water', 'deep water' }
function ns.SayWhere()
	local x, y, map = Place()
	if not x then
		ns.Print('Your position is not available here.')
		return
	end
	ns.Print(('Map %d, world %.1f, %.1f.'):format(map, x, y))
	if not Data(map) then return end
	local cx, cy = P.CellOf(map, x, y)
	ns.Print(('Cell %d, %d: %s.'):format(cx, cy, KINDS[P.KindAt(map, cx, cy)] or '?'))
	local nx, ny = P.Nearest(map, cx, cy, 12)
	if nx and (nx ~= cx or ny ~= cy) then
		ns.Print(('Nearest walkable ground: %d yd away.'):format(math.sqrt((nx - cx) ^ 2 + (ny - cy) ^ 2) * 4.1667))
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
