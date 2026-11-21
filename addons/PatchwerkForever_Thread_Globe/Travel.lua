-- Thread (Globe): travel on the globe.
--
--   your route        the trail Thread (Routes) leads you along, in its own colours (a flight is a
--                     dashed arc, a boat or zeppelin a dashed line over the sea), and the numbered
--                     stops of My Route; a click on a stop lists what can be done with it
--   boats, zeppelins  where each puts in and the way it sails (what Thread (Routes) knows of them)
--   flight points     those the game shows your side, from zone level in; grey ones you have not found
--   herb and ore      the spots Thread (Routes) remembers, close in
--   the map pin       the game's own: Ctrl-click sets it; a click on it has it tracked or not,
--                     Ctrl-click on it clears it, Shift-click links it in chat. With keys or a gamepad,
--                     Set Or Clear The Map Pin does it at the middle of the picture.
--
-- The trail, the boats and the spots come through the base (PatchwerkForever.Trails): this addon does
-- not know Thread (Routes), and shows none of them without it.
local ADDON, ns = ...
if not (ns.linked and ns.Marks) then return end
local G, Marks = ns.G, ns.Marks
local Base = ns.Base
local Trails, MyRoute, Guides = Base.Trails, Base.MyRoute, Base.Guides

local floor, ceil, log, sqrt = math.floor, math.ceil, math.log, math.sqrt
local VIEW = G.VIEW
local FLIGHTS_FROM = VIEW * 1.4       -- flight points are shown from this zoom in (the globe's radius, points)
local NODES_FROM = VIEW * 5           -- and herb and ore spots from this
local NEAR = 14                       -- with keys, the pin this near the middle of the picture is the one meant
local STOP_TINT = { 0.56, 0.80, 1.0 }
local BOAT, ZEPPELIN = { 0.42, 0.68, 0.90, 0.9 }, { 0.84, 0.64, 0.36, 0.9 }
local SIDES = { Alliance = 'A', Horde = 'H' }

local function World(uiMap, x, y)
	if Guides and Guides.WorldOf then return Guides.WorldOf(uiMap, x, y) end
end

local function XY(position)
	if type(position) ~= 'table' then return nil end
	if position.GetXY then return position:GetXY() end
	return position.x, position.y
end

local function Sound(name)
	local kit = rawget(_G, 'SOUNDKIT')
	if type(kit) == 'table' and kit[name] and PlaySound then pcall(PlaySound, kit[name]) end
end

local function HasTrails() return type(Trails) == 'table' and Trails.Has and Trails:Has() end

---------------------------------------------------------------------------
-- Boats and zeppelins
---------------------------------------------------------------------------
Marks.Source('crossings', {
	order = 20,
	Shown = function() return ns.Get('globeCrossings') and HasTrails() end,
	Fill = function(mark, line)
		local side = SIDES[UnitFactionGroup and UnitFactionGroup('player') or '']
		local stops, list = {}, {}
		for _, c in ipairs(Trails:Crossings()) do
			if not side or type(c.sides) ~= 'string' or c.sides:find(side, 1, true) then
				local air = c.kind == 'zeppelin'
				for _, ride in ipairs(c.rides or {}) do
					local from, to = c.stops[ride.from], c.stops[ride.to]
					if from and to then
						local key = from.map .. ':' .. from.name
						local stop = stops[key]
						if not stop then
							stop = { map = from.map, x = from.x, y = from.y, name = from.name, air = air, to = {}, seen = {}, wait = c.wait }
							stops[key] = stop
							list[#list + 1] = stop
						end
						if not stop.seen[to.name] then
							stop.seen[to.name] = true
							stop.to[#stop.to + 1] = to.name
						end
					end
				end
				-- (one of its two ways is drawn: there and back are near enough the same)
				local ride = c.rides and c.rides[1]
				if ride then
					local at = {}
					for _, leg in ipairs(ride.legs or {}) do
						for _, p in ipairs(leg.points) do
							local w = Marks.Where(leg.map, p[1], p[2])
							if w then at[#at + 1] = w end
						end
					end
					line({ at = at, colour = air and ZEPPELIN or BOAT, width = 3, dashed = true })
				end
			end
		end
		for _, stop in ipairs(list) do
			table.sort(stop.to)
			local lines = { (stop.air and 'Zeppelin to %s' or 'Boat to %s'):format(table.concat(stop.to, ', ')) }
			if type(stop.wait) == 'number' and stop.wait > 0 then
				lines[2] = ('Wait: about %d min'):format(ceil(stop.wait / 60))
			end
			mark({ map = stop.map, x = stop.x, y = stop.y, icon = Marks.Icon(stop.air and 'zeppelin' or 'boat'), size = 18, rank = 40,
				name = stop.name, lines = lines })
		end
	end,
})

---------------------------------------------------------------------------
-- Flight points
---------------------------------------------------------------------------
Marks.Source('flights', {
	order = 30,
	every = 120,
	Shown = function() return ns.Get('globeFlights') end,
	Fill = function(mark)
		local taxi = rawget(_G, 'C_TaxiMap')
		if not (type(taxi) == 'table' and taxi.GetTaxiNodesForMap) then return end
		local side = UnitFactionGroup and UnitFactionGroup('player')
		local sides = Enum and Enum.FlightPathFaction or {}
		local horde, alliance = sides.Horde or 1, sides.Alliance or 2
		for map in pairs(G.continents) do
			local uiMap = G.UiMap(map)
			local ok, nodes = pcall(taxi.GetTaxiNodesForMap, uiMap)
			for _, node in ipairs(uiMap and ok and type(nodes) == 'table' and nodes or {}) do
				local theirs = (node.faction == horde and side ~= 'Horde') or (node.faction == alliance and side ~= 'Alliance')
				local x, y = XY(node.position)
				if not theirs and x and type(node.name) == 'string' then
					local m, wx, wy = World(uiMap, x, y)
					local unknown = node.isUndiscovered and true or false
					mark({ map = m, x = wx, y = wy, atlas = type(node.atlasName) == 'string' and node.atlasName or nil,
						icon = Marks.Icon(unknown and 'flightoff' or 'flight'), size = 16, rank = unknown and 28 or 30,
						from = FLIGHTS_FROM, name = node.name,
						lines = { unknown and 'Flight point, not discovered yet' or 'Flight point' } })
				end
			end
		end
	end,
})
Marks.On('TAXI_NODE_STATUS_CHANGED', function() Marks.Changed('flights') end)

---------------------------------------------------------------------------
-- Herb and ore spots
---------------------------------------------------------------------------
-- How far the picture reaches from its middle (yards), in steps, so the spots are not asked for again
-- at every touch of the zoom.
local function Reach(r)
	local w, h = G.Size()
	local yards = sqrt(w * w + h * h) / 2 / Marks.PointsAYard(r)
	return 1.5 ^ ceil(log(yards) / log(1.5))
end

local function Middle()
	local p = G.Under(0, -G.Lift())
	if not p then return nil end
	return Marks.Place(p)
end

Marks.Source('nodes', {
	order = 10,
	Shown = function() return ns.Get('globeNodes') and HasTrails() end,
	Key = function(r)
		if r < NODES_FROM then return 'far' end
		local map, x, y = Middle()
		if not map then return 'sea' end
		local reach = Reach(r)
		return ('%d:%d:%d:%d'):format(map, floor(x / reach * 2), floor(y / reach * 2), floor(reach))
	end,
	Fill = function(mark)
		local r = G.look.r
		if r < NODES_FROM then return end
		local map, x, y = Middle()
		if not map then return end
		Trails:NodesAround(map, x, y, Reach(r) * 2, function(nx, ny, name, icon, kind)
			mark({ map = map, x = nx, y = ny, icon = icon, coords = icon and { 0.08, 0.92, 0.08, 0.92 } or nil, size = 14, rank = 5,
				from = NODES_FROM, name = name or 'Node', lines = { kind == 'h' and 'Herb' or kind == 'o' and 'Ore' or nil } })
		end)
	end,
})

---------------------------------------------------------------------------
-- The trail
---------------------------------------------------------------------------
Marks.Source('trail', {
	order = 60,
	every = 1,                       -- (the trail starts where you stand)
	Shown = function() return ns.Get('globeRoute') and HasTrails() end,
	Fill = function(mark, line)
		for _, trail in ipairs(Trails:List()) do
			local before
			local colour
			for _, piece in ipairs(trail.pieces or {}) do
				local at = {}
				for _, p in ipairs(piece.points or {}) do
					local w = Marks.Where(piece.map, p[1], p[2])
					if w then at[#at + 1] = w end
				end
				colour = { piece.r or 1, piece.g or 1, piece.b or 1, piece.alpha or trail.alpha or 1 }
				local width = trail.follow and 5 or 3.5
				local ride = piece.how == 'ride'
				-- a boat or zeppelin to another continent: its two halves are joined over the sea
				if before and before.ride and ride and before.map ~= piece.map and before.last and at[1] then
					line({ at = { before.last, at[1] }, colour = colour, width = width, dashed = true })
				end
				line({ at = at, colour = colour, width = width, dashed = ride or piece.how == 'fly', arc = piece.how == 'fly' })
				before = { ride = ride, map = piece.map, last = at[#at] }
			end
			-- (each step after the one you are on ends in a dot)
			local last = trail.last
			if not trail.follow and last and colour then
				mark({ map = last.map, x = last.x, y = last.y, icon = Marks.Icon('dot'), tint = colour, size = 12, rank = 1, under = true })
			end
		end
	end,
})
if type(Trails) == 'table' and Trails.OnChange then
	Trails:OnChange(function()
		Marks.Changed('trail')
		Marks.Changed('crossings')
		Marks.Changed('nodes')
	end)
end

---------------------------------------------------------------------------
-- My Route's stops
---------------------------------------------------------------------------
local function StopMenu(_, m)
	local index, count = m.index, m.count
	local _, view = G.Frames()
	G.Menu(view, function(root)
		root:CreateTitle(m.name)
		root:CreateButton('Go Here First', function() MyRoute:Lead(index) end)
		if index > 1 then root:CreateButton('Move Earlier', function() MyRoute:Move(index, index - 1) end) end
		if index < count then root:CreateButton('Move Later', function() MyRoute:Move(index, index + 1) end) end
		root:CreateButton('Remove From My Route', function() MyRoute:Remove(index) end)
	end)
end

Marks.Source('stops', {
	order = 70,
	every = 5,                       -- (a quest's stop moves as its objectives are done)
	Shown = function() return ns.Get('globeRoute') and type(MyRoute) == 'table' and MyRoute.Entries ~= nil end,
	Fill = function(mark)
		local entries = MyRoute:Entries()
		for _, e in ipairs(entries) do
			if type(e.map) == 'number' and type(e.x) == 'number' and type(e.y) == 'number' then
				local name = e.name or e.label or 'Stop'
				mark({ map = e.map, x = e.x, y = e.y, icon = Marks.Icon('badge'), tint = STOP_TINT, size = 20,
					text = tostring(e.index), rank = 70 - math.min(e.index, 20), keep = e.index == 1,
					name = name, index = e.index, count = #entries,
					lines = { ('My Route: stop %d of %d'):format(e.index, #entries), e.zone, 'Click for options.' },
					click = StopMenu })
			end
		end
	end,
})
if type(MyRoute) == 'table' and MyRoute.OnChange then
	MyRoute:OnChange(function() Marks.Changed('stops') end)
end

---------------------------------------------------------------------------
-- The map pin
---------------------------------------------------------------------------
local function Pin()
	if not (C_Map and C_Map.GetUserWaypoint) then return nil end
	local ok, point = pcall(C_Map.GetUserWaypoint)
	if not (ok and type(point) == 'table' and type(point.uiMapID) == 'number') then return nil end
	local x, y = XY(point.position)
	if not x then return nil end
	return World(point.uiMapID, x, y)
end

local function Tracked()
	local track = rawget(_G, 'C_SuperTrack')
	if not (type(track) == 'table' and track.IsSuperTrackingUserWaypoint) then return false end
	local ok, on = pcall(track.IsSuperTrackingUserWaypoint)
	return ok and on and true or false
end

local function Track(on)
	local track = rawget(_G, 'C_SuperTrack')
	if type(track) == 'table' and track.SetSuperTrackedUserWaypoint then pcall(track.SetSuperTrackedUserWaypoint, on) end
end

local function ClearPin()
	if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
	Track(false)
	Sound('UI_MAP_WAYPOINT_REMOVE')
	Marks.Changed('pin')
end

local function CanSet(uiMap)
	if type(uiMap) ~= 'number' then return false end
	if not C_Map.CanSetUserWaypointOnMap then return true end
	local ok, can = pcall(C_Map.CanSetUserWaypointOnMap, uiMap)
	return ok and can and true or false
end

-- Set the pin at x, y of the picture (points from the globe's middle): on the zone's own map where
-- the game knows one there, else on the continent's. True when there was a place there to set it.
local function SetPin(x, y)
	local p = G.Under(x, y)
	local map, wx, wy
	if p then map, wx, wy = Marks.Place(p) end
	if not (map and C_Map and C_Map.SetUserWaypoint and C_Map.GetMapPosFromWorldPos) then return false end
	local uiMap, px, py
	local ok, found, pos = pcall(C_Map.GetMapPosFromWorldPos, map, CreateVector2D(wx, wy))
	if ok and type(found) == 'number' then
		uiMap, px, py = found, XY(pos)
		local okc, info = pcall(C_Map.GetMapInfoAtPosition, found, px, py)
		local zone = okc and type(info) == 'table' and info.mapID
		if type(zone) == 'number' and zone ~= found then
			local okz, onZone, zonePos = pcall(C_Map.GetMapPosFromWorldPos, map, CreateVector2D(wx, wy), zone)
			local zx, zy = XY(okz and zonePos or nil)
			if okz and onZone == zone and zx and zx >= 0 and zx <= 1 and zy >= 0 and zy <= 1 and CanSet(zone) then
				uiMap, px, py = zone, zx, zy
			end
		end
	end
	if not (uiMap and px and CanSet(uiMap)) then
		ns.Print('A map pin cannot be set there.')
		return true
	end
	local set = pcall(C_Map.SetUserWaypoint, { uiMapID = uiMap, position = CreateVector2D(px, py) })
	if not set then
		ns.Print('A map pin cannot be set there.')
		return true
	end
	Track(false)
	Sound('UI_MAP_WAYPOINT_CONTROL_CLICK')
	Marks.Changed('pin')
	return true
end

local function PinClick()
	if IsModifiedClick and IsModifiedClick('CHATLINK') then
		local ok, link = pcall(C_Map.GetUserWaypointHyperlink)
		local chat = rawget(_G, 'ChatFrameUtil')
		if ok and type(link) == 'string' then
			if type(chat) == 'table' and chat.InsertLink then
				chat.InsertLink(link)
			elseif ChatEdit_InsertLink then
				ChatEdit_InsertLink(link)
			end
			Sound('UI_MAP_WAYPOINT_CHAT_SHARE')
		end
	elseif IsControlKeyDown and IsControlKeyDown() then
		ClearPin()
	else
		local on = not Tracked()
		Track(on)
		Sound(on and 'UI_MAP_WAYPOINT_SUPER_TRACK_ON' or 'UI_MAP_WAYPOINT_SUPER_TRACK_OFF')
		Marks.Changed('pin')
	end
end

Marks.Source('pin', {
	order = 90,
	every = 10,
	Fill = function(mark)
		local map, x, y = Pin()
		if not map then return end
		local tracked = Tracked()
		mark({ map = map, x = x, y = y, icon = Marks.Icon(tracked and 'pin' or 'pinoff'), size = 26, dy = 10, rank = 90, keep = true,
			name = 'Map Pin', tracked = tracked,
			lines = { tracked and 'Tracked' or 'Not tracked', 'Click: track it, or stop tracking it', 'Ctrl-click: remove it', 'Shift-click: link it in chat' },
			click = PinClick })
	end,
	Press = function(button, x, y, byKey)
		if button == 'LeftButton' and not byKey and IsControlKeyDown and IsControlKeyDown() then return SetPin(x, y) end
		return false
	end,
})
Marks.On('USER_WAYPOINT_UPDATED', function() Marks.Changed('pin') end)
Marks.On('SUPER_TRACKING_CHANGED', function() Marks.Changed('pin') end)

-- Set Or Clear The Map Pin, by key or gamepad: at the middle of the picture.
ns.GlobeOn('key', function(what)
	if what ~= 'pin' then return false end
	local y = -G.Lift()
	local m = Marks.At(0, y, NEAR)
	if m and m.source == 'pin' then
		ClearPin()
	else
		SetPin(0, y)
	end
	return true
end)
