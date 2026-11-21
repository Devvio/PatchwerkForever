-- Thread (Globe): marks and lines on the globe.
--
-- Everything shown on the globe besides the map itself is a mark (an icon at a place, with a name and
-- what a click on it does) or a line (a trail from place to place, bent round the ball). They come from
-- sources: each is a function that lists its marks and lines when asked, and is asked again when it
-- says its list is stale (ns.Marks.Changed) or after a while (every).
--
--     ns.Marks.Source('flights', {
--         order = 20,                       -- sources are drawn in this order, the later over the earlier
--         every = 30,                       -- seconds its list is good for (none: until Changed)
--         Key = function(r) return 'x' end, -- (optional) its list is also made again when this changes
--         Shown = function() return ns.Get('globeFlights') end,
--         Fill = function(mark, line)
--             mark({ map =, x =, y =,       -- a place in the world (or p = a direction on the sphere)
--                 icon = / atlas =, coords = { l, r, t, b }, tint = { r, g, b }, size = 16, text = '3',
--                 name = 'Ratchet', lines = { 'Flight point' } or a function giving them,
--                 rank = 30,                -- where marks crowd, the higher rank is kept
--                 keep = true,              -- never left out for crowding
--                 from =, upto =,           -- shown between these zooms (the globe's radius, points)
--                 yards = 120,              -- (in place of size) as wide as this many yards of the world, twice over
--                 under = true,             -- drawn under the other marks, and not pointed at
--                 dy = 10,                  -- drawn this many points above its place (a pin's point is at its foot)
--                 click = function(button, mark) end })
--             line({ at = { p, p, ... },    -- directions on the sphere (ns.Marks.Where(map, x, y))
--                 colour = { r, g, b, a }, width = 5, dashed = true, arc = true, from =, upto = })
--         end,
--         Press = function(button, x, y, byKey) end,   -- a click on the picture no mark took: true when dealt with
--     })
--
-- Marks are pictures on the globe's own canvas, not buttons: the picture under them still turns and
-- zooms. The one under the pointer (or, with keys or a gamepad, at the middle of the picture) shows its
-- tooltip and takes the click.
local ADDON, ns = ...
if not (ns.linked and ns.G) then return end
local G = ns.G

local sin, cos, sqrt, floor, ceil, min, max, abs = math.sin, math.cos, math.sqrt, math.floor, math.ceil, math.min, math.max, math.abs
local acos, pi = math.acos, math.pi

local SEEN, EYE, VIEW, half = G.SEEN, G.EYE, G.VIEW, G.half
local LINE = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\line'      -- (across it: dark edges, a pale middle)
local MEDIA = 'Interface\\AddOns\\' .. ADDON .. '\\Media\\mark_'  -- our own pictures (tools/globe_marks.py)
local DOT = MEDIA .. 'dot'                                        -- a mark with no picture of its own
local FRONT = EYE / (EYE - 1)         -- how much larger the point nearest the eye is seen
local CELL = 18                       -- marks nearer each other than this (points) crowd: one is kept
local STEP = 3                        -- a line's points nearer than this on the screen (points) are passed over
local BEND = 0.02                     -- a line's stretch longer than this (radians) is bent round the globe
local BOW, BOW_MOST = 0.18, 0.05      -- an arc bows out this much of its length to one side (radians at most)
local DASH, GAP = 9, 6                -- a dashed line's dashes and gaps (points)
local MOST_LINES, MOST_MARKS = 1200, 400
local NEAR = 14                       -- with keys, the mark this near the middle of the picture is the one meant

local Marks = {}
ns.Marks = Marks

-- One of our own pictures: badge, pin, pinoff, boat, zeppelin, tram, lift, flight, flightoff, bang, ask,
-- person, grave, place, ring, dot.
function Marks.Icon(name) return MEDIA .. name end

local sources, order = {}, {}
local placed = {}                     -- the marks shown at the last drawing
local widgets, lineTex = {}, {}       -- the pictures marks and lines are drawn with
local marksUsed, linesUsed = 0, 0
local counts = {}                     -- lines drawn for each source at the last drawing
local hot                             -- the mark under the pointer
local tipUp = false
local pickedKey, crossMoved           -- on a flat map, by keys: the mark stepped to, and the cross put on it
local Picked

function Marks.Source(name, spec)
	spec.name, spec.order, spec.stale = name, spec.order or 50, true
	sources[name] = spec
	order[#order + 1] = spec
	table.sort(order, function(a, b) return a.order < b.order end)
end

-- A game event (one this game client may not have: then nothing is watched).
local watcher, watched = nil, {}
function Marks.On(event, fn)
	if not watcher then
		watcher = CreateFrame('Frame')
		watcher:SetScript('OnEvent', function(_, name, ...)
			for _, one in ipairs(watched[name] or {}) do ns.Try(name, one, ...) end
		end)
	end
	if not watched[event] then
		if not pcall(watcher.RegisterEvent, watcher, event) then return false end
		watched[event] = {}
	end
	watched[event][#watched[event] + 1] = fn
	return true
end

function Marks.Changed(name)
	local s = sources[name]
	if s then s.stale = true end
	G.Changed()
end

-- Every list is made again (the map under the marks is another: a flat map came up, or went).
function Marks.AllChanged()
	for _, s in ipairs(order) do s.stale = true end
	pickedKey = nil
	G.Changed()
end

-- The zoom the marks are shown for: the globe's radius (points), or what a flat map counts as.
function Marks.Zoom() return ns.FlatOn and ns.FlatOn() or G.look.r end

-- A place in the world (a continent's map number, world x, y) as a direction on the sphere; nil for a
-- continent the globe does not have.
function Marks.Where(map, x, y)
	local c = map and G.continents[map]
	if not (c and x and y) then return nil end
	return G.WorldOnGlobe(c, x, y)
end

local function Dot(p, q) return p[1] * q[1] + p[2] * q[2] + p[3] * q[3] end

-- The other way round: the continent a direction on the sphere is over (its map number), and the
-- world x, y there; nil over the open sea far from any.
function Marks.Place(p)
	local best, bx, by
	for map, c in pairs(G.continents) do
		if Dot(p, c.basis) > 0 then
			local gx, gy = G.FromGlobe(c, p)
			if gx >= 0 and gx <= 64 and gy >= 0 and gy <= 64 then
				local d = Dot(p, c.basis)
				if not best or d > best.d then best, bx, by = { map = map, d = d }, gx, gy end
			end
		end
	end
	if not best then return nil end
	return best.map, G.EDGE - by * G.TILE, G.EDGE - bx * G.TILE
end

-- The game's own maps at a direction on the sphere (the middle of the picture when none is given):
-- the zone's map there (nil where the game has none of its own there), the continent's map, the
-- continent (its map number), and the world x, y. Nothing over the open sea far from any continent.
local midAt, mid = {}, {}
local function ZoneMapAt(p)
	local map, wx, wy = Marks.Place(p)
	local continent = map and G.UiMap(map)
	if not continent then return nil end
	local zone
	if C_Map.GetMapPosFromWorldPos and C_Map.GetMapInfoAtPosition then
		local ok, found, pos = pcall(C_Map.GetMapPosFromWorldPos, map, CreateVector2D(wx, wy), continent)
		if ok and found and type(pos) == 'table' then
			local x, y = pos.x, pos.y
			if pos.GetXY then x, y = pos:GetXY() end
			local oki, info = pcall(C_Map.GetMapInfoAtPosition, found, x, y)
			zone = oki and type(info) == 'table' and info.mapID
			if type(zone) ~= 'number' or zone == found then zone = nil end
		end
	end
	return zone, continent, map, wx, wy
end
function Marks.ZoneMap(p)
	local flat = ns.FlatMap and ns.FlatMap()
	if flat then
		-- (a flat map is up: it is the zone's map, everywhere on it)
		p = p or G.Under(0, 0)
		local map, wx, wy
		if p then map, wx, wy = Marks.Place(p) end
		return flat, map and G.UiMap(map) or nil, map, wx, wy
	end
	if p then return ZoneMapAt(p) end
	local look, lift = G.look, G.Lift()
	if midAt[1] ~= look.lat or midAt[2] ~= look.lon or midAt[3] ~= look.r or midAt[4] ~= lift then
		midAt[1], midAt[2], midAt[3], midAt[4] = look.lat, look.lon, look.r, lift
		p = G.Under(0, -lift)
		if p then
			mid[1], mid[2], mid[3], mid[4], mid[5] = ZoneMapAt(p)
		else
			mid[1], mid[2], mid[3], mid[4], mid[5] = nil, nil, nil, nil, nil
		end
	end
	return mid[1], mid[2], mid[3], mid[4], mid[5]
end

-- How many points a yard of the world is, at the middle of the picture, at radius r.
function Marks.PointsAYard(r) return r * FRONT / G.RW end

-- A line's points, with those of each long stretch put in so that it follows the ball. An arc bows
-- out to one side between its first point and its last, as a flight is drawn on a map.
local function Bent(at, arc)
	local out = { { at[1][1], at[1][2], at[1][3] } }
	local whole = 0
	for i = 2, #at do whole = whole + acos(max(-1, min(1, Dot(at[i - 1], at[i])))) end
	local bow, nx, ny, nz = 0, 0, 0, 0
	if arc and whole > 0 then
		local a, z = at[1], at[#at]
		nx, ny, nz = a[2] * z[3] - a[3] * z[2], a[3] * z[1] - a[1] * z[3], a[1] * z[2] - a[2] * z[1]
		local n = sqrt(nx * nx + ny * ny + nz * nz)
		if n > 1e-9 then
			nx, ny, nz, bow = nx / n, ny / n, nz / n, min(BOW_MOST, whole * BOW)
		end
	end
	local gone = 0
	for i = 2, #at do
		local p, q = at[i - 1], at[i]
		local angle = acos(max(-1, min(1, Dot(p, q))))
		local n = max(1, min(64, ceil(angle / BEND)))
		local s = sin(angle)
		for k = 1, n do
			local t = k / n
			local x, y, z
			if s < 1e-6 then
				x, y, z = q[1], q[2], q[3]
			else
				local a, b = sin((1 - t) * angle) / s, sin(t * angle) / s
				x, y, z = a * p[1] + b * q[1], a * p[2] + b * q[2], a * p[3] + b * q[3]
			end
			if bow > 0 then
				local side = bow * sin(pi * (gone + angle * t) / whole)
				x, y, z = x + nx * side, y + ny * side, z + nz * side
				local l = sqrt(x * x + y * y + z * z)
				x, y, z = x / l, y / l, z / l
			end
			out[#out + 1] = { x, y, z }
		end
		gone = gone + angle
	end
	return out
end

local function Refresh(s)
	s.stale, s.at = false, GetTime()
	s.key = s.Key and ns.Try('the globe', s.Key, G.look.r) or nil
	local marks, lines = {}, {}
	local function mark(m)
		if m.on then
			-- (a place on one of the game's flat maps itself, on = the map and u, v across and down it: shown
			-- only while that map is up, Flat.lua. A battleground's marks: it is no part of the globe's world.)
			m.p = { m.u, m.v, m.on }
		else
			m.p = m.p or Marks.Where(m.map, m.x, m.y)
		end
		if m.p then
			m.source = s.name
			marks[#marks + 1] = m
		end
	end
	local function line(l)
		if type(l.at) == 'table' and #l.at >= 2 then
			l.ps = Bent(l.at, l.arc)
			lines[#lines + 1] = l
		end
	end
	ns.Try('the globe', s.Fill, mark, line)
	s.marks, s.lines = marks, lines
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local xMost, yLow, yHigh = half, -half, half

local function Quad(x1, y1, x2, y2, l)
	if linesUsed >= MOST_LINES then return end
	local dx, dy = x2 - x1, y2 - y1
	local length = sqrt(dx * dx + dy * dy)
	if length < 0.01 then return end
	if (x1 < -xMost and x2 < -xMost) or (x1 > xMost and x2 > xMost) or (y1 < yLow and y2 < yLow) or (y1 > yHigh and y2 > yHigh) then
		return
	end
	linesUsed = linesUsed + 1
	local t = lineTex[linesUsed]
	local _, _, canvas = G.Frames()
	if not t then
		t = canvas:CreateTexture(nil, 'ARTWORK')
		if t.SetSnapToPixelGrid then
			t:SetSnapToPixelGrid(false)
			t:SetTexelSnappingBias(0)
		end
		t:SetPoint('TOPLEFT', canvas, 'TOPLEFT', 0, 0)
		t:SetSize(VIEW, VIEW)
		t:SetTexture(LINE)
		t:SetDrawLayer('ARTWORK', 7)
		lineTex[linesUsed] = t
	end
	dx, dy = dx / length, dy / length
	local w = (l.width or 4) / 2
	local nx, ny = -dy * w, dx * w
	t:SetVertexOffset(1, x1 + nx + half, y1 + ny - half)
	t:SetVertexOffset(2, x1 - nx + half, y1 - ny + half)
	t:SetVertexOffset(3, x2 + nx - half, y2 + ny - half)
	t:SetVertexOffset(4, x2 - nx - half, y2 - ny + half)
	local c = l.colour
	t:SetVertexColor(c and c[1] or 1, c and c[2] or 1, c and c[3] or 1, c and c[4] or 1)
	t.x1, t.y1, t.x2, t.y2, t.source = x1, y1, x2, y2, l.source
	t:Show()
	counts[l.source] = (counts[l.source] or 0) + 1
end

local function Stroke(l, x1, y1, x2, y2)
	if not l.dashed then return Quad(x1, y1, x2, y2, l) end
	local dx, dy = x2 - x1, y2 - y1
	local length = sqrt(dx * dx + dy * dy)
	local t, turn = 0, DASH + GAP
	while t < length do
		local at = l.phase % turn
		local on = at < DASH
		local e = min(length, t + (on and DASH - at or turn - at))
		if on then Quad(x1 + dx * t / length, y1 + dy * t / length, x1 + dx * e / length, y1 + dy * e / length, l) end
		l.phase, t = l.phase + (e - t), e
	end
end

local function PaintLine(l, r, b)
	l.phase = 0
	local px, py
	local ps = l.ps
	local n = #ps
	for i = 1, n do
		local p = ps[i]
		local z = p[1] * b[1] + p[2] * b[2] + p[3] * b[3]
		if z <= SEEN + 0.01 then
			px = nil                                -- (behind the globe's edge: the line breaks off)
		else
			local k = EYE / (EYE - z) * r
			local x, y = (p[1] * b[4] + p[2] * b[5] + p[3] * b[6]) * k, (p[1] * b[7] + p[2] * b[8] + p[3] * b[9]) * k
			if not px then
				px, py = x, y
			elseif i == n or abs(x - px) + abs(y - py) >= STEP then
				Stroke(l, px, py, x, y)
				px, py = x, y
			end
		end
	end
end

-- A line on a flat map: its points laid by the map (Flat.lua), a stretch broken off where one of them
-- is not on the map's continent.
local function PaintFlat(l, Project)
	l.phase = 0
	local px, py
	local ps = l.ps
	local n = #ps
	for i = 1, n do
		local x, y = Project(ps[i])
		if not x then
			px = nil
		elseif not px then
			px, py = x, y
		elseif i == n or abs(x - px) + abs(y - py) >= STEP then
			Stroke(l, px, py, x, y)
			px, py = x, y
		end
	end
end

local function Widget(i)
	local w = widgets[i]
	if not w then
		local _, _, canvas = G.Frames()
		w = { tex = canvas:CreateTexture(nil, 'OVERLAY', nil, -2), under = false }
		widgets[i] = w
	end
	return w
end

local function Look(w, m)
	local key = (m.atlas or '') .. '|' .. tostring(m.icon or '') .. '|' .. (m.coords and table.concat(m.coords, ',') or '')
	if w.key ~= key then
		w.key = key
		local t = w.tex
		local info = m.atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(m.atlas)
		w.atlas = info and t.SetAtlas and true or false
		if w.atlas then
			t:SetAtlas(m.atlas)
		else
			t:SetTexture(m.icon or DOT)
			local c = m.icon and m.coords
			t:SetTexCoord(c and c[1] or 0, c and c[2] or 1, c and c[3] or 0, c and c[4] or 1)
		end
	end
end

local cand, taken = {}, {}
local function Paint(r)
	local b = G.Basis()
	local Project = ns.FlatOn and ns.FlatOn() and ns.FlatProject or nil
	if not (b or Project) then return end
	xMost, yLow, yHigh = G.Edges()
	local now = GetTime()
	local beforeLines, beforeMarks = linesUsed, marksUsed
	linesUsed, marksUsed = 0, 0
	for k in pairs(counts) do counts[k] = nil end
	for i = #cand, 1, -1 do cand[i] = nil end
	for k in pairs(taken) do taken[k] = nil end
	for i = #placed, 1, -1 do placed[i] = nil end
	for _, s in ipairs(order) do
		if not s.Shown or s.Shown() then
			if s.stale or (s.every and now - (s.at or 0) > s.every)
				or (s.Key and ns.Try('the globe', s.Key, r) ~= s.key) then
				Refresh(s)
			end
			for _, l in ipairs(s.lines) do
				if r >= (l.from or 0) and r <= (l.upto or math.huge) then
					l.source = s.name
					if Project then PaintFlat(l, Project) else PaintLine(l, r, b) end
				end
			end
			for _, m in ipairs(s.marks) do
				if r >= (m.from or 0) and r <= (m.upto or math.huge) then
					local p = m.p
					local z = not Project and p[1] * b[1] + p[2] * b[2] + p[3] * b[3]
					if Project then
						local x, y, on
						if m.on then
							if m.on == ns.FlatMap() then x, y = ns.FlatPoints(m.u, m.v) end
							on = x ~= nil
						else
							x, y, on = Project(p)
						end
						if on then
							m.sx, m.sy, m.sz = x, y + (m.dy or 0), 1
							cand[#cand + 1] = m
						end
					elseif not m.on and z > SEEN + 0.02 then
						local x, y = G.Seen(p, r)
						if abs(x) < xMost + 8 and y > yLow - 8 and y < yHigh + 8 then
							m.sx, m.sy, m.sz = x, y + (m.dy or 0), z
							cand[#cand + 1] = m
						end
					end
				end
			end
		end
	end
	-- where marks crowd, the higher rank is kept (and any that must always show)
	table.sort(cand, function(a, c)
		local ra, rc = (a.keep and 1000 or 0) + (a.rank or 1), (c.keep and 1000 or 0) + (c.rank or 1)
		if ra ~= rc then return ra > rc end
		return a.sx < c.sx
	end)
	local _, _, canvas = G.Frames()
	for _, m in ipairs(cand) do
		-- (crowded: one already kept is nearer than CELL; looked for in the squares round this one)
		local cx, cy = floor(m.sx / CELL), floor(m.sy / CELL)
		local crowded = false
		if not (m.keep or m.under) then
			for ix = cx - 1, cx + 1 do
				for iy = cy - 1, cy + 1 do
					local kept = taken[(ix + 4096) * 8192 + iy + 4096]
					while kept and not crowded do
						crowded = abs(kept.sx - m.sx) < CELL and abs(kept.sy - m.sy) < CELL
						kept = kept.nextKept
					end
				end
			end
		end
		if not crowded and marksUsed < MOST_MARKS then
			if not m.under then
				local cell = (cx + 4096) * 8192 + cy + 4096
				m.nextKept = taken[cell]
				taken[cell] = m
			end
			marksUsed = marksUsed + 1
			local w = Widget(marksUsed)
			Look(w, m)
			local t = w.tex
			local size = m.yards and max(m.least or 12, min(m.most or 400, 2 * m.yards * Marks.PointsAYard(r))) or m.size or 16
			m.shown = size
			if w.under ~= (m.under or false) then
				w.under = m.under or false
				t:SetDrawLayer('OVERLAY', m.under and -3 or -2)
			end
			t:SetSize(size, size)
			t:ClearAllPoints()
			t:SetPoint('CENTER', canvas, 'CENTER', m.sx, m.sy)
			local tint = m.tint
			local alpha = G.Smooth(SEEN + 0.02, SEEN + 0.12, m.sz) * (m.alpha or 1)
			t:SetVertexColor(tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1, alpha)
			t:Show()
			if m.text then
				if not w.fs then
					w.fs = canvas:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
					w.fs:SetFont('Fonts\\FRIZQT__.TTF', 11, 'OUTLINE')
				end
				w.fs:SetText(m.text)
				w.fs:ClearAllPoints()
				w.fs:SetPoint('CENTER', canvas, 'CENTER', m.sx, m.sy)
				w.fs:SetAlpha(min(1, alpha))
				w.fs:Show()
			elseif w.fs then
				w.fs:Hide()
			end
			placed[#placed + 1] = m
		end
	end
	for i = marksUsed + 1, beforeMarks do
		widgets[i].tex:Hide()
		if widgets[i].fs then widgets[i].fs:Hide() end
	end
	for i = linesUsed + 1, beforeLines do lineTex[i]:Hide() end
end

---------------------------------------------------------------------------
-- Pointing and pressing
---------------------------------------------------------------------------
-- The mark shown at x, y (points from the globe's middle), or within `reach` of there; the nearest.
function Marks.At(x, y, reach)
	local best, least
	for _, m in ipairs(placed) do
		local d = sqrt((m.sx - x) ^ 2 + (m.sy - y) ^ 2)
		if not m.under and d <= (reach or ((m.shown or 16) / 2 + 3)) and (not least or d < least) then
			best, least = m, d
		end
	end
	return best
end

-- The tooltip of the mark pointed at (was: the one pointed at before). A mark may put up one of its
-- own (tip: a function told the mark and whether the pointer came or went), as another addon's pin does.
local function Tip(was)
	local tip = rawget(_G, 'GameTooltip')
	if type(tip) ~= 'table' then return end
	if was and was.tip then ns.Try('the globe', was.tip, was, false) end
	if hot and hot.tip then
		if tipUp then
			tip:Hide()
			tipUp = false
		end
		ns.Try('the globe', hot.tip, hot, true)
		return
	end
	if not (hot and hot.name) then
		if tipUp then
			tip:Hide()
			tipUp = false
		end
		return
	end
	local _, view, _, cross = G.Frames()
	if G.ByKeys() then
		tip:SetOwner(cross, 'ANCHOR_BOTTOMRIGHT')
	else
		tip:SetOwner(view, 'ANCHOR_CURSOR')
	end
	tip:SetText(hot.name, 1, 0.82, 0)
	local lines = hot.lines
	if type(lines) == 'function' then lines = ns.Try('the globe', lines, hot) end
	for _, text in ipairs(type(lines) == 'table' and lines or {}) do
		if type(text) == 'string' and text ~= '' then tip:AddLine(text, 1, 1, 1, true) end
	end
	tip:Show()
	tipUp = true
end

ns.GlobeOn('paint', Paint)

-- With keys or a gamepad the pointer is the middle of the picture (the cross); zoomed right out, where
-- the globe sits above that, a mark the globe was turned to is at the globe's own middle.
local function AtCross()
	if ns.FlatOn and ns.FlatOn() then return Picked() end      -- (a flat map does not turn: the mark stepped to)
	local lift = G.Lift()
	return Marks.At(0, -lift, NEAR) or (lift ~= 0 and Marks.At(0, 0, NEAR)) or nil
end

local checked = 0
ns.GlobeOn('frame', function(elapsed)
	local _, view = G.Frames()
	-- (a list good only for a while is made again when its time is up, though nothing else has changed)
	checked = checked + (elapsed or 0)
	if checked > 0.5 then
		checked = 0
		local now = GetTime()
		for _, s in ipairs(order) do
			if s.every and s.at and now - s.at > s.every and (not s.Shown or s.Shown()) then
				G.Changed()
				break
			end
		end
	end
	local m
	if not G.Turning() then
		if G.ByKeys() then
			m = AtCross()
		elseif view:IsMouseOver() then
			local x, y = G.Pointer()
			m = Marks.At(x, y)
		end
	end
	-- (on a flat map, with keys, the cross sits on the mark stepped to)
	local at = G.ByKeys() and ns.FlatOn and ns.FlatOn() and Picked() or nil
	if at or crossMoved then
		local _, _, canvas, cross = G.Frames()
		cross:ClearAllPoints()
		if at then
			cross:SetPoint('CENTER', canvas, 'CENTER', at.sx, at.sy)
		else
			cross:SetPoint('CENTER', view, 'CENTER', 0, 0)
		end
		crossMoved = at ~= nil
	end
	if m ~= hot then
		local was = hot
		hot = m
		Tip(was)
	end
end)

ns.GlobeOn('hide', function()
	local was = hot
	hot, pickedKey = nil, nil
	Tip(was)
end)

ns.GlobeOn('press', function(button, x, y, byKey)
	local flat = ns.FlatOn and ns.FlatOn()
	-- (a right-click, or its like by key, wheel or stick, takes a flat map down)
	if flat and button == 'RightButton' then return ns.FlatPress(button) end
	local m
	if byKey then m = AtCross() else m = Marks.At(x, y) end
	if m and m.click and button == 'LeftButton' then
		ns.Try('the globe', m.click, button, m)
		return true
	end
	for i = #order, 1, -1 do
		local s = order[i]
		if s.Press and (not s.Shown or s.Shown()) and ns.Try('the globe', s.Press, button, x, y, byKey) then return true end
	end
	return flat and true or false       -- (nothing of the globe is under a flat map to take the press)
end)

-- Next Mark, by key or gamepad: the globe turns to the named mark nearest the middle of the picture
-- that it has not been turned to yet (and round again once it has been to all in the picture).
local stepped, steppedAt = {}, 0
local function StepKey(m)
	return ('%s:%s:%d:%d:%d'):format(m.source, tostring(m.name), floor(m.p[1] * 2e4), floor(m.p[2] * 2e4), floor(m.p[3] * 2e4))
end
function Picked()
	if not pickedKey then return nil end
	for _, m in ipairs(placed) do
		if not m.under and StepKey(m) == pickedKey then return m end
	end
	return nil
end

ns.GlobeOn('key', function(what)
	if what ~= 'next' then return false end
	if ns.FlatOn and ns.FlatOn() then
		-- (a flat map does not turn: the cross goes from mark to mark, left to right and down the map)
		local list = {}
		for _, m in ipairs(placed) do
			if not m.under and (m.name or m.tip) then list[#list + 1] = m end
		end
		table.sort(list, function(a, c)
			if a.sy ~= c.sy then return a.sy > c.sy end
			return a.sx < c.sx
		end)
		local pick = list[1]
		for i, m in ipairs(list) do
			if StepKey(m) == pickedKey then
				pick = list[i % #list + 1]
				break
			end
		end
		pickedKey = pick and StepKey(pick) or nil
		return true
	end
	local now = GetTime()
	if now - steppedAt > 10 then stepped = {} end
	steppedAt = now
	local my = -G.Lift()
	local function Nearest()
		local best, least
		for _, m in ipairs(placed) do
			if not m.under and m.name and not stepped[StepKey(m)] then
				local d = m.sx * m.sx + (m.sy - my) * (m.sy - my)
				if not least or d < least then best, least = m, d end
			end
		end
		return best
	end
	local m = Nearest()
	if not m and next(stepped) then
		stepped = {}
		m = Nearest()
	end
	if m then
		stepped[StepKey(m)] = true
		G.GlideTo(m.p, G.look.r)
	end
	return true
end)

-- For the checks outside the game: the marks shown at the last drawing, the lines drawn for each
-- source, and the mark under the pointer.
function Marks.State()
	local out = { marks = {}, lines = {}, strokes = {}, hot = hot and hot.name or nil }
	for i, m in ipairs(placed) do
		local w = widgets[i]
		out.marks[i] = { source = m.source, name = m.name, text = m.text, x = m.sx, y = m.sy, size = m.shown,
			icon = w.atlas and m.atlas or m.icon or DOT, atlas = w.atlas, mark = m }
	end
	for i = 1, linesUsed do
		local t = lineTex[i]
		out.strokes[i] = { t.x1, t.y1, t.x2, t.y2, t.source }
	end
	for name, n in pairs(counts) do out.lines[name] = n end
	return out
end
