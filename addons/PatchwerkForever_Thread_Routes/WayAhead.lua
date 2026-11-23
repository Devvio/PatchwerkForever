-- Routes (Thread): the way ahead, marked in the world (Mark The Way Ahead).
--
-- An addon cannot draw in the world. The game can: its waypoint marker, and the arrow at the edge of the
-- screen that points to it, stand on your map pin or the quest you track. So while a route is followed,
-- the game's map pin is moved to a spot on the trail a little way ahead of you (AHEAD yards on, along
-- the trail, not as the crow flies) and tracked, and it moves on as you walk: the marker leads you round
-- walls and through gates as the trail does. Near the end it stands on the destination itself. Where the
-- trail takes a flight, a boat or a zeppelin, it stands where that leaves.
--
-- The pin and the tracked quest are lent through the base (its Marker.lua), which keeps yours and gives
-- them back when the route ends, when the setting is disabled, and at logout; the route still goes where
-- your pin and your quest say, since this addon asks the base for them. Sparkle (Thread) hangs its
-- waypoint sparkle on the marker, and is told what the route leads to (Marker:Info()).
--
-- Not done: on a flight path, aboard a boat or zeppelin, in an instance (the game keeps your place to
-- itself there), and with no route found.
local ADDON, ns = ...
if not ns.linked then return end

local AHEAD = 40              -- yards along the trail ahead of you that the marker stands
local MOVE = 10               -- yards the spot must have moved before the pin is set again
local NEAR = 15               -- yards from the destination within which the marker stands on it
local EVERY = 0.5             -- seconds between looks

local placed                  -- where it was set last: { map, x, y }

local function Marker()
	local marker = ns.Base.Marker
	return (marker and type(marker.Place) == 'function') and marker or nil
end

local function Far(ax, ay, bx, by)
	return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- The spot AHEAD yards on along the trail from where you are on it: from the point of the stretch you
-- are on nearest you, along the walked stretches (a tunnel, a lift or a drop counts as walked), stopping
-- where a flight, a boat or a gap begins, and at the trail's end.
local function Ahead(route, px, py)
	local points = route.points
	local i = math.max(1, math.min(route.at or 1, #points))
	local a, b = points[i], points[i + 1]
	if not b then return a[1], a[2] end
	local dx, dy = b[1] - a[1], b[2] - a[2]
	local len = dx * dx + dy * dy
	local t = len > 0 and ((px - a[1]) * dx + (py - a[2]) * dy) / len or 0
	if t < 0 then t = 0 elseif t > 1 then t = 1 end
	local cx, cy = a[1] + dx * t, a[2] + dy * t
	local left = AHEAD
	for j = i + 1, #points do
		local p = points[j]
		local how = p[3]
		if how == 'fly' or how == 'ride' or how == 'gap' then return cx, cy end
		local d = Far(cx, cy, p[1], p[2])
		if d >= left and d > 0 then
			return cx + (p[1] - cx) * left / d, cy + (p[2] - cy) * left / d
		end
		left = left - d
		cx, cy = p[1], p[2]
	end
	return cx, cy
end

-- What the route leads to, in a few words, for the marker's sparkle: the step's first line, else "Map Pin".
local function Words(dest)
	local lines = dest.lines
	local first = type(lines) == 'table' and lines[1]
	if type(first) == 'table' then first = first.text end
	if type(first) == 'string' and first ~= '' then
		return (first:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''))
	end
	if dest.pin then return 'Map Pin' end
	if dest.source == 'corpse' then return 'Your Corpse' end
	return 'Your Route'
end

-- Where the marker is to stand now: map, x, y, and what it leads to; nothing when it is not to be shown.
local function Spot()
	if not ns.Get('wayAhead') then return nil end
	local dest, route = ns.dest, ns.route
	if not (dest and route and route.points and #route.points > 0) or route.loose then return nil end
	if UnitOnTaxi and UnitOnTaxi('player') then return nil end
	if IsInInstance and IsInInstance() then return nil end
	local px, py, map = ns.Place()
	if not px or map ~= route.map then return nil end
	local info = { words = Words(dest), map = dest.map, x = dest.x, y = dest.y }
	if map == dest.map and Far(px, py, dest.x, dest.y) <= NEAR + AHEAD then
		-- (near the end the marker waits on the destination itself, if the trail goes there)
		local last = route.points[#route.points]
		if Far(last[1], last[2], dest.x, dest.y) <= NEAR then return map, dest.x, dest.y, info end
	end
	local x, y = Ahead(route, px, py)
	return map, x, y, info
end

local function Look()
	local marker = Marker()
	if not marker then return end
	local map, x, y, info = Spot()
	if not map then
		if placed or marker:Active() then
			placed = nil
			marker:Release()
		end
		return
	end
	-- (each change of the map pin is work for the game and the maps: only once it has moved a little,
	-- or when the pin is no longer the one set here, as after you set one of your own)
	if placed and placed[1] == map and Far(placed[2], placed[3], x, y) < MOVE and marker:IsOurs() then return end
	if marker:Place(map, x, y, info) then
		placed = { map, x, y }
	else
		placed = nil
	end
end

local ticker
ns.On('PLAYER_LOGIN', function()
	ticker = ticker or C_Timer.NewTicker(EVERY, function() ns.Try('marking the way ahead', Look) end)
end)
-- (the route changed: looked at at once, not at the next tick)
if ns.OnRoute then ns.OnRoute(function() Look() end) end
ns.OnSetting(function(key)
	if key == 'wayAhead' then ns.Try('marking the way ahead', Look) end
end)

-- (for the checks in lua_shell.py)
function ns.WayAheadPlaced() return placed end
