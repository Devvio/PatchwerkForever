-- Routes (Thread): the area gone to, and GatherMate2's spots, drawn on the maps.
--
--   the area      a run to the best gathering area (Gather.lua), and the way to the best place to skin
--                 or farm an item (Farm.lua), go to an area, not a spot: its edge is drawn as a ring
--                 of small dots on the minimap and the world map while it is gone to (Show Area On Maps)
--   GatherMate2   its herb and ore spots near you on the minimap, in the herb or ore colour (Show
--                 GatherMate2 Nodes On Minimap; off to begin with, since GatherMate2 draws its own
--                 spots once its data is imported). Only kinds your character can gather.
local ADDON, ns = ...
if not ns.linked then return end

local RING = 36               -- dots round an area's edge
local RING_SIZE = 5
local GM_SIZE, GM_MOST = 7, 120
local COLOUR = { h = { 0.35, 0.95, 0.35 }, o = { 1, 0.6, 0.2 }, ring = { 1, 0.85, 0.3 } }

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

local function Paint(dot, c, a)
	dot:SetVertexColor(c[1], c[2], c[3], a or 0.9)
end

local function Area()
	local dest = ns.dest
	local area = dest and dest.area
	if area and ns.Get('areaRing') then return area end
	return nil
end

-- The kinds you can gather ('h', 'o'), for GatherMate2's dots: by the tracking spells you know.
local function Kinds()
	local known = rawget(_G, 'IsPlayerSpell') or rawget(_G, 'IsSpellKnown')
	local out = {}
	if type(known) == 'function' then
		local okH, h = pcall(known, 2383)
		local okO, o = pcall(known, 2580)
		out.h, out.o = okH and h or false, okO and o or false
	end
	if not (out.h or out.o) then out.h, out.o = true, true end
	return out
end

---------------------------------------------------------------------------
-- The minimap
---------------------------------------------------------------------------
local mini, miniDots, miniShown = nil, {}, 0

local function MiniDraw()
	for i = 1, miniShown do miniDots[i]:Hide() end
	miniShown = 0
	local area = Area()
	local gm = ns.Get('gathermateMinimap') and ns.GatherMateAround
	if not (area or gm) then return end
	if not mini then mini = ns.MinimapLayer() end
	local px, py, map, perYard, sin, cos, radius = ns.MinimapView(mini, 5)
	if not px then return end
	local square = GetMinimapShape and GetMinimapShape() == 'SQUARE'
	local function Place(wx, wy, size)
		local east, north = (py - wy) * perYard, (wx - px) * perYard
		local x, y = east * cos + north * sin, north * cos - east * sin
		local edge = radius - size / 2
		local inside
		if square then inside = math.abs(x) <= edge and math.abs(y) <= edge else inside = x * x + y * y <= edge * edge end
		return inside, x, y
	end
	local function Put(wx, wy, size, c, a)
		local inside, x, y = Place(wx, wy, size)
		if not inside then return end
		miniShown = miniShown + 1
		local dot = Dot(miniDots, miniShown, mini, size)
		Paint(dot, c, a)
		dot:ClearAllPoints()
		dot:SetPoint('CENTER', mini, 'CENTER', x, y)
		dot:Show()
	end
	if gm then
		local kinds, view, n = Kinds(), radius / perYard, 0
		ns.GatherMateAround(map, px, py, view * 1.5, function(spot)
			if n < GM_MOST and kinds[spot.kind] then
				n = n + 1
				Put(spot[1], spot[2], GM_SIZE, COLOUR[spot.kind], 0.85)
			end
		end)
	end
	if area and area.map == map then
		for i = 1, RING do
			local t = 2 * math.pi * i / RING
			Put(area.x + area.radius * math.cos(t), area.y + area.radius * math.sin(t), RING_SIZE, COLOUR.ring, 0.8)
		end
	end
	return true
end

local redraws = ns.MinimapRedraws('the area and GatherMate2 spots', function()
	if not MiniDraw() and mini then mini:Hide() end
end)

---------------------------------------------------------------------------
-- The world map (the ring only: GatherMate2 draws its own spots there)
---------------------------------------------------------------------------
local layer, mapDots, mapShown = nil, {}, 0

local function MapDraw(letGo)
	for i = 1, mapShown do mapDots[i]:Hide() end
	mapShown = 0
	local area = not letGo and Area()
	if not area then return end
	local view = ns.WorldMapView()
	if not (view and view.map == area.map) then return end
	if not layer then
		layer = CreateFrame('Frame', nil, view.canvas)
		layer:SetAllPoints(view.canvas)
	end
	layer:SetFrameLevel(view.level + 1)
	local size = RING_SIZE * 1.4 / view.scale
	for i = 1, RING do
		local t = 2 * math.pi * i / RING
		local u, v = view.at(area.x + area.radius * math.cos(t), area.y + area.radius * math.sin(t))
		if u >= 0 and u <= 1 and v >= 0 and v <= 1 then
			mapShown = mapShown + 1
			local dot = Dot(mapDots, mapShown, layer, size)
			Paint(dot, COLOUR.ring, 0.85)
			dot:ClearAllPoints()
			dot:SetPoint('CENTER', layer, 'TOPLEFT', u * view.width, -v * view.height)
			dot:Show()
		end
	end
end

local function Refresh()
	local want = (Area() ~= nil) or (ns.Get('gathermateMinimap') and true or false)
	redraws.Dirty()
	redraws.On(want)
	if not want then
		for i = 1, miniShown do miniDots[i]:Hide() end
		miniShown = 0
		if mini then mini:Hide() end
	end
end

ns.On('PLAYER_LOGIN', function()
	if ns.OnWorldMapDraw then ns.OnWorldMapDraw(MapDraw) end
	if ns.OnRoute then ns.OnRoute(function() Refresh() end) end
	Refresh()
end)

ns.OnSetting(function(key)
	if key == 'areaRing' or key == 'gathermateMinimap' or key == 'gathermate' then
		Refresh()
		if ns.RedrawWorldMap then ns.RedrawWorldMap() end
	end
end)
