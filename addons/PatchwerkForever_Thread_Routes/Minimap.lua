-- Thread (Routes): the route on the minimap.
--
-- Lines over the minimap for the part of the route within its view, turned with the minimap when it
-- turns with the character, and cut off at its edge (round, or square where the minimap says it is).
--
-- Drawn again when something it shows may have changed (where you stand, the route, the minimap's
-- view, a setting), looked at twenty times a second; and every frame while the minimap turns with
-- you (Rotate Minimap), so the trail turns with it rather than a step behind. The herb and ore
-- nodes on the minimap (Nodes.lua) are drawn the same way.
--
-- The layer is a frame of its own laid over the minimap, not a part of the minimap: with MelloUI's
-- Route and EllesmereUI's minimap both running, a layer inside the minimap went with the minimap
-- turning black (seen 2026-11-11; the cause was not found, moving the layer out cured it). Keep
-- it a frame beside the minimap.
local ADDON, ns = ...
if not ns.linked then return end

local EVERY = 0.05        -- seconds between looks at whether to draw again
local MOST = 160          -- lines at most
local MOST_DOTS = 200     -- and dots
local STEADY = 1          -- seconds the minimap must hold still for after a login or reload
local WAIT = 8            -- seconds waited at most for that

-- After a login or a reload the minimap moves about for a few seconds while other addons set its
-- size and zoom (seen 2026-11-11: the map bounces, then settles, and the trail jumped about with
-- it). The trail is held back until the minimap has kept one size, place and zoom for a second.
local settling, since, began, last = false, 0, 0, nil

local function Settled(view)
	if not settling then return true end
	local time = GetTime()
	local now = ('%.1f %.1f %.1f %.1f'):format(view, Minimap:GetWidth() or 0, Minimap:GetLeft() or 0, Minimap:GetTop() or 0)
	if now ~= last then
		last, since = now, time
	end
	if time - since >= STEADY or time - began >= WAIT then
		settling = false
		return true
	end
	return false
end

-- For anything drawn over the minimap (the trail here, the herb and ore spots in Nodes.lua): lays `frame`
-- over the minimap, `above` frame levels above it, and says how to place things on it. Returns nothing
-- while the minimap cannot be drawn on, else the character's place (world x, y), the map, the pixels a
-- yard, the sine and cosine that turn the picture with the minimap, and the minimap's radius in pixels.
-- A spot at world (x, y) goes, from the frame's middle, at
--     east, north = (py - y) * perYard, (x - px) * perYard
--     east * cos + north * sin, north * cos - east * sin
function ns.MinimapView(frame, above)
	if not (Minimap and Minimap:IsVisible()) then return end
	-- a minimap that is there but faded out (another addon's, while it sets itself up) gets nothing
	if Minimap.GetEffectiveAlpha and Minimap:GetEffectiveAlpha() < 0.05 then return end
	local px, py, map = ns.Place()
	if not px then return end
	local view = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
	if not view or view <= 0 then return end
	if not Settled(view) then return end
	frame:ClearAllPoints()
	frame:SetAllPoints(Minimap)
	frame:SetFrameStrata(Minimap:GetFrameStrata())
	frame:SetFrameLevel(Minimap:GetFrameLevel() + above)
	frame:Show()
	local radius = frame:GetWidth() / 2
	if not radius or radius <= 0 then return end
	local sin, cos = 0, 1
	if GetCVar('rotateMinimap') == '1' and GetPlayerFacing then
		local facing = GetPlayerFacing()
		if facing then sin, cos = math.sin(facing), math.cos(facing) end
	end
	return px, py, map, radius / view, sin, cos, radius
end

-- A frame of our own to lay over the minimap (never a child of it: see the top of this file).
function ns.MinimapLayer()
	local frame = CreateFrame('Frame', nil, UIParent)
	frame:EnableMouse(false)
	frame:Hide()
	return frame
end

-- Whether the minimap turns with the character, and which way the character faces then.
local function Facing()
	if GetCVar('rotateMinimap') ~= '1' or not GetPlayerFacing then return nil end
	return GetPlayerFacing()
end

-- Keeps something drawn over the minimap up to date. draw() draws it; always(), where given, says it
-- must be drawn at each look all the same (a flowing trail). Returns { On = function(on), Dirty = function() }:
-- On starts or stops it, Dirty has it drawn at the next look. Each look compares what the drawing rests
-- on with the last time (where you stand, the minimap's view, size, place and whether it is shown);
-- while the minimap is settling after a login (see Settled) every look draws. A skipped look leaves
-- nothing floating: a minimap hidden or faded out changes what is compared, and is drawn (hidden) for.
function ns.MinimapRedraws(label, draw, always)
	local ticker, dirty = nil, true
	local lx, ly, lmap, lview, lwidth, lleft, ltop, lshown, lface
	local function Look()
		local px, py, map = ns.Place()
		local view = C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
		local shown = Minimap and Minimap:IsVisible() and not (Minimap.GetEffectiveAlpha and Minimap:GetEffectiveAlpha() < 0.05)
		local width = Minimap and Minimap:GetWidth()
		local left, top = Minimap and Minimap:GetLeft(), Minimap and Minimap:GetTop()
		local face = Facing()
		if not (dirty or settling or (always and always())) and px == lx and py == ly and map == lmap
			and view == lview and width == lwidth and left == lleft and top == ltop and shown == lshown and face == lface then
			return
		end
		dirty = false
		lx, ly, lmap, lview, lwidth, lleft, ltop, lshown, lface = px, py, map, view, width, left, top, shown, face
		draw()
	end
	-- every frame while the minimap turns with you: only a turn is looked for there, the rest at each look
	local turner = CreateFrame('Frame', nil, UIParent)
	turner:Hide()
	turner:SetScript('OnUpdate', function()
		local face = Facing()
		if face and face ~= lface then ns.Try(label, Look) end
	end)
	local self = {}
	function self.On(on)
		if on and not ticker then
			dirty = true
			ticker = C_Timer.NewTicker(EVERY, function() ns.Try(label, Look) end)
			turner:Show()
		elseif not on and ticker then
			ticker:Cancel()
			ticker = nil
			turner:Hide()
		end
	end
	function self.Dirty() dirty = true end
	return self
end

local layer, lines, used = nil, {}, 0
local dots, dotted = {}, 0

local function Clear()
	for i = 1, used do lines[i]:Hide() end
	for i = 1, dotted do dots[i]:Hide() end
	used, dotted = 0, 0
end

local function Layer()
	if not layer then layer = ns.MinimapLayer() end
	return layer
end

-- The part of a line inside a circle of radius r about the middle, or nil.
-- (A square minimap's edge is a box: ns.ClipBox, Trail.lua.)
local function InCircle(ax, ay, bx, by, r)
	local dx, dy = bx - ax, by - ay
	local a = dx * dx + dy * dy
	if a == 0 then return nil end
	local b = 2 * (ax * dx + ay * dy)
	local c = ax * ax + ay * ay - r * r
	local disc = b * b - 4 * a * c
	if disc <= 0 then return nil end
	local root = math.sqrt(disc)
	local t0, t1 = (-b - root) / (2 * a), (-b + root) / (2 * a)
	if t1 <= 0 or t0 >= 1 then return nil end
	if t0 < 0 then t0 = 0 end
	if t1 > 1 then t1 = 1 end
	return ax + dx * t0, ay + dy * t0, ax + dx * t1, ay + dy * t1
end

-- Returns true when the trail was drawn (so the layer stays up), nothing otherwise.
local function Trail()
	Clear()
	local route = ns.route
	local ahead = ns.ahead and ns.ahead.legs
	if not ((route or ahead) and ns.Get('minimap')) then return end
	local parent = Layer()
	local px, py, map, perYard, sin, cos, radius = ns.MinimapView(parent, 8)
	if not px then return end
	local edge = radius * 0.96
	-- (asked as the node icons ask, Nodes.lua: a minimap addon that makes it square says so here)
	local square = GetMinimapShape and GetMinimapShape() == 'SQUARE'
	local full = ns.Get('trailThickMini') or 2.5
	local thick, alpha = full, 0.9
	local pen = ns.TrailPen(1, true, full)
	local r, g, b = 1, 1, 1
	local chosen
	local function line(x1, y1, x2, y2)
		if used >= MOST then return end
		used = used + 1
		local l = lines[used]
		if not l then
			l = parent:CreateLine(nil, 'OVERLAY')
			lines[used] = l
		end
		l:SetThickness(thick)
		l:SetColorTexture(r, g, b, alpha)
		l:SetStartPoint('CENTER', parent, x1, y1)
		l:SetEndPoint('CENTER', parent, x2, y2)
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
		if d.SetAlpha then d:SetAlpha(alpha) end
		d:SetSize(thick * 2.2, thick * 2.2)
		d:ClearAllPoints()
		d:SetPoint('CENTER', parent, 'CENTER', x, y)
		d:Show()
	end
	local points, at, loose
	local function spot(i)
		-- the trail starts at the character (but not one found while you were on a flight path, with
		-- no flight on it: Route.lua)
		if i == at and not loose then return 0, 0 end
		local p = points[i]
		local east, north = (py - p[2]) * perYard, (p[1] - px) * perYard
		return east * cos + north * sin, north * cos - east * sin
	end
	-- one trail: the part of it on the map you are on
	local drew = false
	local function Run(trail, follow)
		points, at, loose = trail.points, follow and trail.at or nil, follow and trail.loose
		chosen, alpha = ns.TrailLook(trail, follow, 0.9, 0.45)
		if map ~= trail.map then
			points, at = trail.parts and trail.parts[map], nil
		end
		if not points then return end
		drew = true
		for i = math.max(1, at or 1), #points - 1 do
			if used >= MOST then break end
			local ax, ay = spot(i)
			local bx, by = spot(i + 1)
			local cx, cy, ex, ey
			if square then
				cx, cy, ex, ey = ns.ClipBox(ax, ay, bx, by, -edge, -edge, edge, edge)
			else
				cx, cy, ex, ey = InCircle(ax, ay, bx, by, edge)
			end
			if cx and points[i + 1][3] ~= 'gap' then
				r, g, b = ns.TrailColour(points[i + 1][3], chosen)
				ns.Stroke(pen, cx, cy, ex, ey, line, dot)
			end
		end
	end
	if route and map == route.map then Run(route, true) end
	-- the way on through a guide's next steps (Ahead.lua): fainter and finer
	thick = full * 0.7
	for _, leg in ipairs(ahead or {}) do
		Run(leg, false)
	end
	return drew or nil
end

local function Draw()
	if not Trail() and layer then layer:Hide() end
end

local redraws = ns.MinimapRedraws('the minimap trail', Draw, ns.TrailMoves)
local function Watch()
	local want = (ns.route ~= nil or ns.ahead ~= nil) and ns.Get('minimap')
	redraws.Dirty()
	redraws.On(want)
	if not want then
		Clear()
		if layer then layer:Hide() end
	end
end

ns.OnRoute(Watch)
ns.On('PLAYER_ENTERING_WORLD', function()
	settling, last = true, nil
	since, began = GetTime(), GetTime()
end)
ns.OnSetting(function(key)
	if key == 'minimap' then Watch() else redraws.Dirty() end
end)
