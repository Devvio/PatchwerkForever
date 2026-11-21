-- Thread (Routes): what it knows of the way, for the family's other tools.
--
-- A tool with a map of its own (Thread (Globe)) draws the same trail the world map and the minimap
-- show, the boats and zeppelins, and the herb and ore spots. It does not know this addon: it asks
-- the base (PatchwerkForever.Trails), and this file answers there. With a base older than 2.8.0
-- there is nowhere to answer, and this file does nothing.
local ADDON, ns = ...
if not ns.linked then return end
local Trails = ns.Base.Trails
if not (type(Trails) == 'table' and Trails.Offer and Trails.Changed) then return end

local max = math.max

-- The pieces of one run of points on one continent: each a stretch gone one way (walked, flown...),
-- in the colour the trail has on the maps. start: where the first point is drawn (you).
local function Pieces(out, map, points, from, start, chosen, alpha)
	local piece
	for i = from, #points - 1 do
		local how = points[i + 1][3]
		if how == 'gap' then
			piece = nil
		else
			if not (piece and piece.how == how) then
				local a = (i == from and start) or points[i]
				local r, g, b = ns.TrailColour(how, chosen)
				piece = { map = map, how = how or 'walk', r = r, g = g, b = b, alpha = alpha, points = { { a[1], a[2] } } }
				out[#out + 1] = piece
			end
			piece.points[#piece.points + 1] = { points[i + 1][1], points[i + 1][2] }
		end
	end
end

-- One trail (the route you are on, or a leg ahead), as the world map draws it: from where you are
-- on, and on the other continents it crosses to.
local function Trail(trail, follow)
	local chosen, alpha = ns.TrailLook(trail, follow, 0.95, 0.45)
	local out = { follow = follow or false, alpha = alpha, pieces = {} }
	local at = follow and trail.at or nil
	local start
	if at and not trail.loose then
		local px, py, map = ns.Place()
		if px and map == trail.map then start = { px, py } end
	end
	Pieces(out.pieces, trail.map, trail.points, max(1, at or 1), start, chosen, alpha)
	local last, lastMap = trail.points[#trail.points], trail.map
	for map, points in pairs(trail.parts or {}) do
		if map ~= trail.map then
			Pieces(out.pieces, map, points, 1, nil, chosen, alpha)
			if trail.to and trail.to.map == map then last, lastMap = points[#points], map end
		end
	end
	if last then out.last = { map = lastMap, x = last[1], y = last[2] } end
	return out
end

local function List()
	local out = {}
	if ns.route then out[#out + 1] = Trail(ns.route, true) end
	for _, leg in ipairs(ns.ahead and ns.ahead.legs or {}) do out[#out + 1] = Trail(leg, false) end
	return out
end

-- The boats and zeppelins (Crossings.lua), each ride's line cut where it jumps from one continent's
-- edge to the other's.
local crossings
local function Crossings()
	if crossings then return crossings end
	crossings = {}
	for _, c in ipairs(ns.Crossings or {}) do
		local one = { id = c.id, kind = c.kind, sides = c.sides, wait = c.wait, stops = {}, rides = {} }
		for i, s in ipairs(c.stops) do one.stops[i] = { map = s[1], name = s[2], x = s[3], y = s[4] } end
		for i, r in ipairs(c.rides) do
			local legs, leg = {}, nil
			local line = r[4]
			for n = 1, #line - 2, 3 do
				local map = line[n]
				if map == -1 then
					leg = nil
				else
					if not (leg and leg.map == map) then
						leg = { map = map, points = {} }
						legs[#legs + 1] = leg
					end
					leg.points[#leg.points + 1] = { line[n + 1], line[n + 2] }
				end
			end
			one.rides[i] = { from = r[1], to = r[2], secs = r[3], legs = legs }
		end
		crossings[#crossings + 1] = one
	end
	return crossings
end

-- The lifts the planner knows (Crossings.lua has them once more, for showing).
local lifts
local function Lifts()
	if lifts then return lifts end
	lifts = {}
	for i, l in ipairs(ns.Lifts or {}) do lifts[i] = { map = l[1], x = l[2], y = l[3], name = l[4] ~= '' and l[4] or nil } end
	return lifts
end

local function NodesAround(map, x, y, reach, fn)
	ns.NodesAround(map, x, y, reach, function(spot)
		fn(spot[1], spot[2], spot[3], ns.NodeIcon(spot[3]), ns.NodeKind(spot[3]))
	end)
end

Trails:Offer({ List = List, Crossings = Crossings, Lifts = Lifts, NodesAround = NodesAround })
ns.OnRoute(function() Trails:Changed() end)
