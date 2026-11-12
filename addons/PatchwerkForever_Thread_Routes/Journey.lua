-- Thread (Routes): journeys. A route that may take boats and zeppelins, on one map or from one to another.
--
-- The planner (Planner.lua) finds the way between two places on one map. A journey is walks found
-- by it, joined by rides: from the start to where a boat is boarded, the ride, and on from where it
-- lands, up to MOST_RIDES rides. Every chain of rides that could do is listed with the least it
-- could cost (each walk taken as flown straight), and they are worked out in that order until none
-- left could beat the best found. A walk worked out once is kept for the chains that share it.
--
-- Like the planner this uses no game function, so the tools run it outside the game (lua_journeys.py).
--
-- A ride costs: the wait for the boat (half its round trip, on average), the ride, and getting on
-- and off (the walk along the dock or the climb up the tower at each end).
local ADDON, ns = ...
local P = ns.Planner

local sqrt, huge = math.sqrt, math.huge
local MOST_RIDES = 2

-- The least a walk between two cells of a map can take: straight there at the speed of a flight.
local function least(map, ax, ay, bx, by)
	local s = P.Use(map)
	local air = s.D.air and s.D.air.speed or 32
	return sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by)) * s.cell / air
end

-- The rides a character of this side can take between maps whose data is there:
-- { crossing, ride, from (a stop), to (a stop), cost }.
local function Rides(crossings, side, use)
	local list = {}
	for _, c in ipairs(crossings or {}) do
		if c.sides == 'AH' or (side and c.sides:find(side, 1, true)) then
			for _, r in ipairs(c.rides) do
				local a, b = c.stops[r[1]], c.stops[r[2]]
				if use(a[1]) and use(b[1]) then
					list[#list + 1] = { crossing = c, ride = r, from = a, to = b, cost = c.wait + r[3] + a[7] + b[7] }
				end
			end
		end
	end
	return list
end

-- from, to: { map =, x =, y = } (cells that can be stood on).
-- opts: rides = the list of crossings (ns.Crossings), or nil for none
--       side = 'A' or 'H', for the rides
--       walk = function(map) returning the options the planner takes for a walk on that map
--              ({ side =, known = } for flight paths; nil or an empty table for none)
--       use = function(map) saying whether that map's data is there (it may load it)
-- Returns nil where there is no way, else { cost = seconds, legs = { leg, ... } }, a leg being
--   { kind = 'walk', map =, sx =, sy =, gx =, gy =, found = what the planner found }
--   { kind = 'ride', crossing =, ride =, from = stop, to = stop, cost = }
function P.Journey(from, to, opts)
	opts = opts or {}
	local use = opts.use or function(map) return P.Use(map) ~= nil end
	if not (use(from.map) and use(to.map)) then return nil end
	local rides = Rides(opts.rides, opts.side, use)

	-- every chain of rides that leads from the start's map to the goal's, with the least it could cost
	local chains = {}
	local function add(a, b)
		local lb, map, x, y = 0, from.map, from.x, from.y
		for _, r in ipairs({ a, b }) do
			lb = lb + least(map, x, y, r.from[5], r.from[6]) + r.cost
			map, x, y = r.to[1], r.to[5], r.to[6]
		end
		chains[#chains + 1] = { a, b, lb = lb + least(map, x, y, to.x, to.y) }
	end
	if from.map == to.map then add() end
	for _, a in ipairs(rides) do
		if a.from[1] == from.map then
			if a.to[1] == to.map then add(a) end
			if MOST_RIDES >= 2 then
				for _, b in ipairs(rides) do
					if b.crossing ~= a.crossing and b.from[1] == a.to[1] and b.to[1] == to.map then add(a, b) end
				end
			end
		end
	end
	table.sort(chains, function(p, q) return p.lb < q.lb end)

	local walks = {}
	local function walk(map, ax, ay, bx, by)
		if ax == bx and ay == by then return { cost = 0, nodes = {} } end
		local key = map .. ':' .. ax .. ':' .. ay .. ':' .. bx .. ':' .. by
		local found = walks[key]
		if found == nil then
			found = P.Route(map, ax, ay, bx, by, opts.walk and opts.walk(map) or {}) or false
			walks[key] = found
		end
		return found
	end

	local best
	for _, chain in ipairs(chains) do
		if best and chain.lb >= best.cost then break end
		local legs, cost, map, x, y = {}, 0, from.map, from.x, from.y
		for _, r in ipairs(chain) do
			local found = walk(map, x, y, r.from[5], r.from[6])
			if not found then cost = huge break end
			legs[#legs + 1] = { kind = 'walk', map = map, sx = x, sy = y, gx = r.from[5], gy = r.from[6], found = found }
			legs[#legs + 1] = { kind = 'ride', crossing = r.crossing, ride = r.ride, from = r.from, to = r.to, cost = r.cost }
			cost = cost + found.cost + r.cost
			map, x, y = r.to[1], r.to[5], r.to[6]
			if best and cost >= best.cost then cost = huge break end
		end
		if cost < huge then
			local found = walk(map, x, y, to.x, to.y)
			if found then
				cost = cost + found.cost
				legs[#legs + 1] = { kind = 'walk', map = map, sx = x, sy = y, gx = to.x, gy = to.y, found = found }
				if not best or cost < best.cost then best = { cost = cost, legs = legs } end
			end
		end
	end
	return best
end

-- A journey as lines to draw and words to say:
--   parts   = { { map =, points = { { world x, world y, how }, ... } }, ... } in the order travelled, a
--             new part wherever the map changes. `how` says how a point is reached from the one
--             before: "walk", "link" (a tunnel, a lift, the way up to a boat), "fly", "ride" (aboard
--             a boat or zeppelin) or "gap" (not travelled: the boat is moved there)
--   yards, swum   walked in all, and how much of that swimming
--   seconds       the time it really takes
--   flown   = { { name, name, ... }, ... }   the flights, each through its flight points
--   rides   = { { kind =, from =, to = }, ... }   the boats and zeppelins, by the names of their stops
function P.JourneyLine(journey)
	local parts, part = {}, nil
	local out = { parts = parts, yards = 0, swum = 0, seconds = journey.cost, flown = {}, rides = {} }
	local function put(map, x, y, how)
		if not part or part.map ~= map then
			part = { map = map, points = {} }
			parts[#parts + 1] = part
		end
		part.points[#part.points + 1] = { x, y, how }
	end
	for _, leg in ipairs(journey.legs) do
		if leg.kind == 'walk' and leg.sx == leg.gx and leg.sy == leg.gy then
			local x, y = P.WorldOf(leg.map, leg.sx, leg.sy)       -- no walk at all: you stand where you board
			put(leg.map, x, y, 'walk')
		elseif leg.kind == 'walk' then
			local line = P.Line(leg.map, leg.sx, leg.sy, leg.gx, leg.gy, leg.found)
			for _, p in ipairs(line.points) do
				local x, y = P.WorldOf(leg.map, p[1], p[2])
				put(leg.map, x, y, p[3])
			end
			out.yards, out.swum = out.yards + line.yards, out.swum + line.swum
			out.seconds = out.seconds - (leg.found.cost - line.seconds)
			for _, flight in ipairs(line.flown) do
				local names = {}
				for k, id in ipairs(flight) do
					names[k] = (P.PointName(leg.map, id):match('^[^,]+')) or tostring(id)
				end
				out.flown[#out.flown + 1] = names
			end
		else
			local a, b = leg.from, leg.to
			put(a[1], a[3], a[4], 'link')                        -- along the dock, or up the tower
			local line, jump = leg.ride[4], false
			for n = 1, #line, 3 do
				if line[n] < 0 then
					jump = true
				else
					put(line[n], line[n + 1], line[n + 2], jump and 'gap' or 'ride')
					jump = false
				end
			end
			local x, y = P.WorldOf(b[1], b[5], b[6])
			put(b[1], x, y, 'link')
			out.rides[#out.rides + 1] = { kind = leg.crossing.kind, from = a[2], to = b[2] }
		end
	end
	return out
end
