-- Wayfarer: the route on the world map.
--
-- A layer over the map's canvas, above the map's picture and below its icons, with the route drawn
-- on it in the colours, thickness and style of the settings (Trail.lua): walking, a tunnel, bridge,
-- lift or drop, and a flight each in its own colour.
local ADDON, ns = ...

local MOST = 600          -- lines at most
local MOST_DOTS = 900     -- and dots
local AGAIN = 0.03        -- seconds between redraws while the trail's pattern is flowing

local layer, lines, used = nil, {}, 0
local dots, dotted = {}, 0

local function Layer(map)
	if layer then return layer end
	local canvas = map:GetCanvas()
	layer = CreateFrame('Frame', nil, canvas)
	layer:SetAllPoints(canvas)
	local level
	if map.GetPinFrameLevelsManager then
		local ok, value = pcall(function()
			return map:GetPinFrameLevelsManager():GetValidFrameLevel('PIN_FRAME_LEVEL_FLIGHT_POINT')
		end)
		level = ok and value
	end
	layer:SetFrameLevel(level or (canvas:GetFrameLevel() + 200))
	return layer
end

local function Line(parent)
	used = used + 1
	local line = lines[used]
	if not line then
		line = parent:CreateLine(nil, 'OVERLAY')
		lines[used] = line
	end
	return line
end

-- The part of a line from (ax, ay) to (bx, by) that lies inside the map (0 to 1 both ways), or nil.
local function Clip(ax, ay, bx, by)
	local t0, t1 = 0, 1
	local dx, dy = bx - ax, by - ay
	local function edge(p, q)
		if p == 0 then return q >= 0 end
		local t = q / p
		if p < 0 then
			if t > t1 then return false end
			if t > t0 then t0 = t end
		else
			if t < t0 then return false end
			if t < t1 then t1 = t end
		end
		return true
	end
	if edge(-dx, ax) and edge(dx, 1 - ax) and edge(-dy, ay) and edge(dy, 1 - ay) then
		return ax + dx * t0, ay + dy * t0, ax + dx * t1, ay + dy * t1
	end
	return nil
end

local function Wipe()
	for i = 1, used do lines[i]:Hide() end
	for i = 1, dotted do dots[i]:Hide() end
	used, dotted = 0, 0
end

local function Draw()
	local map = WorldMapFrame
	if not (map and map.GetCanvas and map:IsShown()) then return end
	Wipe()
	local route = ns.route
	if not (route and ns.Get('worldMap')) then return end
	local mapID = map:GetMapID()
	if not mapID then return end
	local info = C_Map.GetMapInfo(mapID)
	if not info or (Enum and Enum.UIMapType and info.mapType < Enum.UIMapType.Continent) then return end
	-- the shown map's corners in world coordinates; inside, the map is a plain rectangle of the world
	local m1, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
	local m2, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
	if not (topLeft and bottomRight) or m1 ~= m2 then return end
	-- the part of the route on the map shown: the part being walked, or, of a journey that crosses to
	-- another continent, the part over there
	local points, at = route.points, route.at
	if m1 ~= route.map then
		points, at = route.parts and route.parts[m1], nil
		if not points then return end
	end
	local top, left = topLeft:GetXY()
	local bottom, right = bottomRight:GetXY()
	if top == bottom or left == right then return end
	local parent = Layer(map)
	local width, height = parent:GetWidth(), parent:GetHeight()
	local scale = map.GetCanvasScale and tonumber(map:GetCanvasScale()) or 1
	if scale <= 0 then scale = 1 end
	local thick = (ns.Get('trailThickMap') or 3) / scale
	local pen = ns.TrailPen(1 / scale)
	local r, g, b = 1, 1, 1
	local function line(x1, y1, x2, y2)
		if used >= MOST then return end
		local l = Line(parent)
		l:SetColorTexture(r, g, b, 0.95)
		l:SetThickness(thick)
		l:SetStartPoint('TOPLEFT', parent, x1, y1)
		l:SetEndPoint('TOPLEFT', parent, x2, y2)
		l:Show()
	end
	local function dot(x, y)
		if dotted >= MOST_DOTS then return end
		dotted = dotted + 1
		local d = dots[dotted]
		if not d then
			d = parent:CreateTexture(nil, 'OVERLAY')
			d:SetTexture(ns.MEDIA .. 'dot')
			dots[dotted] = d
		end
		d:SetVertexColor(r, g, b)
		d:SetSize(thick * 2.2, thick * 2.2)
		d:ClearAllPoints()
		d:SetPoint('CENTER', parent, 'TOPLEFT', x, y)
		d:Show()
	end
	local px, py = ns.Place()
	local function spot(i)
		local p = points[i]
		local x, y = p[1], p[2]
		if i == at and px then x, y = px, py end               -- the trail starts at the character
		return (left - y) / (left - right), (top - x) / (top - bottom)
	end
	for i = math.max(1, at or 1), #points - 1 do
		if used >= MOST then break end
		local ax, ay = spot(i)
		local bx, by = spot(i + 1)
		local cx, cy, ex, ey = Clip(ax, ay, bx, by)
		if cx and points[i + 1][3] ~= 'gap' then
			r, g, b = ns.TrailColour(points[i + 1][3])
			ns.Stroke(pen, cx * width, -cy * height, ex * width, -ey * height, line, dot)
		end
	end
end

-- For anything else drawn on the world map (the herb and ore spots in Nodes.lua). Returns nothing while
-- the map is not shown or is of the whole world, else a table: canvas (the frame to draw on), width,
-- height, scale (divide a size by it to keep it the same on the screen), level (the trail's frame
-- level), map (the continent shown), zone (true for a zone's map, false for a continent's) and
-- at(x, y), which takes a world position to its place on the canvas as fractions of its width and height.
function ns.WorldMapView()
	local map = WorldMapFrame
	if not (map and map.GetCanvas and map:IsShown()) then return end
	local mapID = map:GetMapID()
	local info = mapID and C_Map.GetMapInfo(mapID)
	if not info or (Enum and Enum.UIMapType and info.mapType < Enum.UIMapType.Continent) then return end
	local m1, topLeft = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
	local m2, bottomRight = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 1))
	if not (topLeft and bottomRight) or m1 ~= m2 then return end
	local top, left = topLeft:GetXY()
	local bottom, right = bottomRight:GetXY()
	if top == bottom or left == right then return end
	local parent = Layer(map)
	local scale = map.GetCanvasScale and tonumber(map:GetCanvasScale()) or 1
	if scale <= 0 then scale = 1 end
	return {
		canvas = map:GetCanvas(), width = parent:GetWidth(), height = parent:GetHeight(), scale = scale,
		level = parent:GetFrameLevel(), map = m1,
		zone = not (Enum and Enum.UIMapType) or info.mapType > Enum.UIMapType.Continent,
		at = function(x, y) return (left - y) / (left - right), (top - x) / (top - bottom) end,
	}
end

-- Others that draw on the world map: called after the trail each time the map is redrawn, and with
-- `true` when the map lets go of what is on it.
local drawers = {}
function ns.OnWorldMapDraw(fn) drawers[#drawers + 1] = fn end

local function Redraw()
	ns.Try('the world map trail', Draw)
	for _, fn in ipairs(drawers) do
		ns.Try('the world map spots', fn)
	end
end
ns.RedrawWorldMap = Redraw

local provider
local function Attach()
	if provider or not (WorldMapFrame and WorldMapFrame.AddDataProvider and MapCanvasDataProviderMixin) then return end
	provider = CreateFromMixins(MapCanvasDataProviderMixin)
	provider.RefreshAllData = Redraw
	provider.OnCanvasScaleChanged = Redraw
	provider.OnCanvasSizeChanged = Redraw
	provider.OnMapChanged = Redraw
	provider.RemoveAllData = function()
		Wipe()
		for _, fn in ipairs(drawers) do
			ns.Try('the world map spots', fn, true)
		end
	end
	WorldMapFrame:AddDataProvider(provider)
	WorldMapFrame:HookScript('OnShow', Redraw)
	-- a flowing trail is drawn again and again, but only while the map is open (a frame of the map's
	-- gets no updates while the map is shut)
	local mover, since = CreateFrame('Frame', nil, WorldMapFrame), 0
	mover:SetScript('OnUpdate', function(_, elapsed)
		since = since + elapsed
		if since < AGAIN then return end
		since = 0
		if ns.route and ns.Get('worldMap') and ns.TrailMoves() then
			ns.Try('the world map trail', Draw)
		end
	end)
end

ns.On('PLAYER_LOGIN', function() ns.Try('the world map trail', Attach) end)
ns.OnRoute(Redraw)
ns.OnSetting(function(key)
	if key == 'worldMap' or key:find('^trail') then Redraw() end
end)
