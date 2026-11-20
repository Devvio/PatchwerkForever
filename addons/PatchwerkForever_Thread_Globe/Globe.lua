-- Thread (Globe): the world on a globe you can spin and zoom.
--
-- An addon cannot make a 3D shape, but it can move the four corners of a picture anywhere on the
-- screen (Texture:SetVertexOffset). So the globe is a ball of pictures: each is laid on the sphere,
-- and every time the globe turns, its four corners are worked out where the eye sees them, in
-- perspective, and the picture is stretched between them.
--
-- The pictures (GLOBE-BLUEPRINT.md, milestone G1: still the game's own, asked for by number):
--   the continent maps   the painted world map of Kalimdor and of the Eastern Kingdoms, their edges
--                        fading into the sea (Map Style: Parchment)
--   the ground           each terrain tile's minimap picture (Tiles.lua), in true colour: fading in
--                        over the continent maps as you zoom in, or all the way with Map Style:
--                        Minimap Pictures
-- A picture is one piece while it is small and flat enough on the screen; else it is split in four,
-- and those again, as far as needed: so a large picture follows the curve of the sphere, and one
-- that crosses the globe's edge is cut down until its pieces are wholly in front (the rest dropped),
-- instead of folding over. The pieces' textures are shared out from a pool and given back when a
-- piece has not been seen for a while.
--
-- The game's continents are separate maps with no sea between them, so where each sits on the ball
-- is chosen here (PLACE): each is laid round its middle, its distances kept from there.
--
-- Turning: drag (it carries on a little after you let go). Zooming: the mouse wheel, toward the
-- pointer, or a double-click to zoom in on a spot. Names: the continents and their zones, from the
-- game's own map list, faded in and out by zoom. Your place: an arrow turned the way you face.
local ADDON, ns = ...
if not ns.linked then return end

local sin, cos, sqrt, floor, min, max, abs = math.sin, math.cos, math.sqrt, math.floor, math.min, math.max, math.abs
local asin, acos, atan2, exp, log = math.asin, math.acos, math.atan2 or math.atan, math.exp, math.log

local TILE = 1600 / 3                 -- yards across a terrain tile
local EDGE = 32 * TILE                -- the world's edge, from its middle (as Thread (Routes) counts cells)
-- the layout comes from Art.lua, written with the pictures (tools/globe_art.py), so the two always agree
local LAYOUT = ns.LAYOUT or {}
local RW = LAYOUT.rw or 19000         -- yards of the world to a radian of the globe (Kalimdor: about 90 degrees tall)
local EYE = 4                         -- the eye, in radii of the globe from its middle
local SEEN = 1 / EYE                  -- a point of the sphere is seen while it is nearer the eye than this
local HIDDEN = acos(SEEN)             -- (the angle from the middle of the view past which nothing is seen)
local LIMB = EYE / sqrt(EYE * EYE - 1)  -- the globe's edge as seen, in radii (a little wider: perspective)
local FRONT = EYE / (EYE - 1)         -- how much larger the point nearest the eye is seen
local VIEW = 600                      -- the picture, in points
local RMIN, RMAX = VIEW * 0.42, VIEW * 60
-- Where each continent's middle sits: latitude, longitude (radians). Kalimdor west, the Eastern
-- Kingdoms east (as on the game's world map), Zephra's Isle in the southern sea between them.
local PLACE = { [1] = { 0.05, -1.05 }, [0] = { 0.10, 1.05 }, [2991] = { -0.75, 0.0 } }
local CONTINENT_MAPS = { [1] = 1414, [0] = 1415 }      -- their world maps (others found through the world map, 947)
local GLIDE = 1.1                     -- seconds Where I Am takes to turn the globe there
-- splitting: a piece whose middle is seen this far (points) off the middle of its corners is split;
-- a picture is split this deep at most (each step halves it)
local CURVE = 1.5
local EDGE_PIECE = 10                 -- a piece crossing the globe's edge this small (points) is dropped: the sea disc shows there
local DEEPEST = { art = 4, ours = 8, detail = 5, ground = 2 }
-- zooming in: our detail pictures (8 yards a pixel) fade in over the world picture (58 yards a pixel) as
-- its pixels would start to show, then the ground (the minimap's pictures, 2 yards a pixel) over the
-- detail as its pixels would (by the globe's radius in points)
local DETAIL_FROM, DETAIL_TO = VIEW * 0.55, VIEW * 0.9
local GROUND_FROM, GROUND_TO = VIEW * 4, VIEW * 7
local MAP_FADE = 0.06                 -- how much of a continent map, from each edge, fades into the sea
local RELEASE = 20                    -- seconds a piece unseen keeps its texture
-- names: continents fade out, zones in, as you zoom (by the globe's radius in points)
local NAMES = {
	continent = { from = 0, full = 0, fade = VIEW * 1.5, gone = VIEW * 2.8,
		font = 'Fonts\\MORPHEUS.TTF', size = 22, colour = { 1, 0.86, 0.55 } },
	zone = { from = VIEW * 1.4, full = VIEW * 2.6, fade = VIEW * 28, gone = VIEW * 45,
		font = 'Fonts\\FRIZQT__.TTF', size = 12, colour = { 1, 0.95, 0.85 } },
	sea = { from = 0, full = 0, fade = VIEW * 2.2, gone = VIEW * 4,
		font = 'Fonts\\MORPHEUS.TTF', size = 15, colour = { 0.24, 0.17, 0.10 }, plain = true },
}
-- the seas' names, where they lie on the globe's own layout (latitude, longitude)
local SEAS_NAMED = {
	{ 'The Great Sea', 0.08, 0.0 }, { 'The Veiled Sea', 0.15, -2.35 }, { 'The Forbidding Sea', 0.30, 2.25 },
	{ 'The South Seas', -0.95, -1.2 },
}

---------------------------------------------------------------------------
-- The sphere
---------------------------------------------------------------------------
-- A place on the sphere (latitude, longitude): the way out from the middle there, then east, then north.
local function Basis(lat, lon)
	local cl, sl, co, so = cos(lat), sin(lat), cos(lon), sin(lon)
	return cl * co, cl * so, sl, -so, co, 0, -sl * co, -sl * so, cl
end

local continents = {}                 -- by the game's map number

-- A point of a continent (column gx, row gy, in tiles) on the sphere, as a direction: laid round the
-- continent's middle, its distance and bearing from there kept.
local function OnGlobe(c, gx, gy)
	local e, n = (gx - c.cx) * TILE, (c.cy - gy) * TILE
	local d = sqrt(e * e + n * n)
	local b = c.basis
	if d < 1e-6 then return b[1], b[2], b[3] end
	local cr, sr = cos(d / RW), sin(d / RW) / d
	return cr * b[1] + sr * (e * b[4] + n * b[7]),
		cr * b[2] + sr * (e * b[5] + n * b[8]),
		cr * b[3] + sr * (e * b[6] + n * b[9])
end

-- A place in the world (world x, world y, as UnitPosition gives them) on the sphere.
local function WorldOnGlobe(c, wx, wy)
	return { OnGlobe(c, (EDGE - wy) / TILE, (EDGE - wx) / TILE) }
end

local function Dot(p, q) return p[1] * q[1] + p[2] * q[2] + p[3] * q[3] end

---------------------------------------------------------------------------
-- The pictures
---------------------------------------------------------------------------
-- A picture: { fdid, layer ('art' or 'ground'), coords (the part of its texture: u0, u1, v0, v1),
-- At(fu, fv) (a point of it, 0 to 1 across and down, on the sphere), Fade(fu, fv) (how much of it
-- shows there: 1, less toward a continent map's edges), c (its continent), root (its first piece) }.
local pictures = { art = {}, ours = {}, detail = {}, ground = {} }

local function Prepare()
	if next(continents) then return end
	for _, c in ipairs(ns.TILES or {}) do
		local sx, sy, n = 0, 0, 0
		for index in pairs(c.tiles) do
			sx, sy, n = sx + index % 64, sy + floor(index / 64), n + 1
		end
		if n > 0 then
			local laid = LAYOUT.continents and LAYOUT.continents[c.map]
			local place = laid and { laid.lat, laid.lon } or PLACE[c.map] or { 0, 0 }
			c.cx, c.cy = laid and laid.cx or sx / n + 0.5, laid and laid.cy or sy / n + 0.5
			c.basis = { Basis(place[1], place[2]) }
			continents[c.map] = c
			for index, fdid in pairs(c.tiles) do
				local tx, ty = index % 64, floor(index / 64)
				pictures.ground[#pictures.ground + 1] = { fdid = fdid, layer = 'ground', c = c, coords = { 0, 1, 0, 1 },
					At = function(fu, fv) return { OnGlobe(c, tx + fu, ty + fv) } end }
			end
		end
	end
	-- our own pictures (Art.lua, made by tools/globe_art.py): the whole world in pieces, each over the
	-- longitudes and latitudes it covers; or one over a continent's terrain tiles
	for _, a in ipairs(ns.ART or {}) do
		if a.kind == 'world' then
			local l0, l1, a0, a1 = a.lon[1], a.lon[2], a.lat[1], a.lat[2]
			pictures.ours[#pictures.ours + 1] = { fdid = a.file, layer = 'ours', world = true, coords = { 0, 1, 0, 1 },
				At = function(fu, fv)
					local lon, lat = l0 + (l1 - l0) * fu, a0 + (a1 - a0) * fv
					return { cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat) }
				end }
			pictures.world = true
		elseif continents[a.map] then
			local c = continents[a.map]
			local c0, c1, r0, r1 = a.columns[1], a.columns[2], a.rows[1], a.rows[2]
			local layer = a.kind == 'detail' and 'detail' or 'ours'
			pictures[layer][#pictures[layer] + 1] = { fdid = a.file, layer = layer, c = c, coords = { 0, 1, 0, 1 },
				At = function(fu, fv) return { OnGlobe(c, c0 + (c1 - c0) * fu, r0 + (r1 - r0) * fv) } end }
		end
	end
end

-- Each continent's world map: the two the game has always had, and any other the world map lists.
local function FindMaps()
	local found = {}
	for map, uiMap in pairs(CONTINENT_MAPS) do found[map] = uiMap end
	local ok, children = pcall(C_Map.GetMapChildrenInfo, 947, Enum and Enum.UIMapType and Enum.UIMapType.Continent)
	for _, info in ipairs(ok and type(children) == 'table' and children or {}) do
		local okw, map = pcall(C_Map.GetWorldPosFromMapPos, info.mapID, CreateVector2D(0.5, 0.5))
		if okw and type(map) == 'number' and not found[map] then found[map] = info.mapID end
	end
	return found
end

-- A world map as a function from its own place (0 to 1 across and down) to the world, and back.
local function MapToWorld(uiMap)
	local function World(u, v)
		local ok, _, w = pcall(C_Map.GetWorldPosFromMapPos, uiMap, CreateVector2D(u, v))
		if ok and w then return w:GetXY() end
	end
	local x00, y00 = World(0, 0)
	local x10, y10 = World(1, 0)
	local x01, y01 = World(0, 1)
	if not (x00 and x10 and x01) then return nil end
	return function(u, v)
		return x00 + (x10 - x00) * u + (x01 - x00) * v, y00 + (y10 - y00) * u + (y01 - y00) * v
	end
end

-- The painted world map of a continent: the game's pictures of it (C_Map.GetMapArtLayerTextures),
-- laid where the map says each of its points is in the world. False when the game has none.
local function ArtPictures(c)
	local uiMap = c.uiMap
	if not uiMap then return false end
	local ok, layers = pcall(C_Map.GetMapArtLayers, uiMap)
	local layer = ok and type(layers) == 'table' and layers[1]
	local ok2, files = pcall(C_Map.GetMapArtLayerTextures, uiMap, 1)
	if not (layer and ok2 and type(files) == 'table' and #files > 0) then return false end
	local lw, lh, tw, th = layer.layerWidth, layer.layerHeight, layer.tileWidth, layer.tileHeight
	if not (lw and lh and tw and th and lw > 0 and lh > 0 and tw > 0 and th > 0) then return false end
	local toWorld = MapToWorld(uiMap)
	if not toWorld then return false end
	local function Ramp(t) t = max(0, min(1, t / MAP_FADE)); return t * t * (3 - 2 * t) end
	local cols, rows = math.ceil(lw / tw), math.ceil(lh / th)
	for j = 1, rows do
		for i = 1, cols do
			local fdid = files[(j - 1) * cols + i]
			local x0, y0 = (i - 1) * tw, (j - 1) * th
			local w, h = min(tw, lw - x0), min(th, lh - y0)
			if fdid and w > 0 and h > 0 then
				local function MapUV(fu, fv) return (x0 + w * fu) / lw, (y0 + h * fv) / lh end
				pictures.art[#pictures.art + 1] = { fdid = fdid, layer = 'art', c = c, coords = { 0, w / tw, 0, h / th },
					At = function(fu, fv)
						local wx, wy = toWorld(MapUV(fu, fv))
						return WorldOnGlobe(c, wx, wy)
					end,
					Fade = function(fu, fv)
						local u, v = MapUV(fu, fv)
						return min(Ramp(u), Ramp(1 - u), Ramp(v), Ramp(1 - v))
					end }
			end
		end
	end
	c.hasArt = true
	return true
end

local artReady = false
local function PrepareArt()
	if artReady then return end
	artReady = true
	Prepare()
	local maps = FindMaps()
	for _, c in ipairs(ns.TILES or {}) do
		if continents[c.map] then
			c.uiMap = maps[c.map]
			ArtPictures(c)
		end
	end
end

-- A piece of a picture: the part fu0..fu1 across, fv0..fv1 down; its corners and middle on the sphere,
-- and how far its corners reach from its middle (radians); its four halves made when first needed.
local function Piece(pic, fu0, fu1, fv0, fv1, depth)
	local p = { pic = pic, fu0 = fu0, fu1 = fu1, fv0 = fv0, fv1 = fv1, depth = depth,
		ul = pic.At(fu0, fv0), ll = pic.At(fu0, fv1), ur = pic.At(fu1, fv0), lr = pic.At(fu1, fv1),
		mid = pic.At((fu0 + fu1) / 2, (fv0 + fv1) / 2) }
	local reach = 0
	for _, k in ipairs({ p.ul, p.ll, p.ur, p.lr }) do
		reach = max(reach, acos(max(-1, min(1, Dot(p.mid, k)))))
	end
	p.reach = reach
	p.hideBelow = cos(min(math.pi, HIDDEN + reach))    -- (wholly behind while its middle is seen less than this)
	return p
end

local function Halves(p)
	if not p.kids then
		local um, vm = (p.fu0 + p.fu1) / 2, (p.fv0 + p.fv1) / 2
		local d = p.depth + 1
		p.kids = { Piece(p.pic, p.fu0, um, p.fv0, vm, d), Piece(p.pic, um, p.fu1, p.fv0, vm, d),
			Piece(p.pic, p.fu0, um, vm, p.fv1, d), Piece(p.pic, um, p.fu1, vm, p.fv1, d) }
	end
	return p.kids
end

---------------------------------------------------------------------------
-- The window's state
---------------------------------------------------------------------------
local window, view, canvas, ocean, halo, dot, arrow, statsText
local look = { lat = 0.05, lon = 0, r = RMIN * 1.05 }
local aim = { r = look.r }            -- the zoom being eased toward, and the point held under the pointer
local basis                           -- the eye's: out, east, north (Basis of look)
local dirty = false
local glide                           -- Where I Am on its way
local coast                           -- a drag's turn carrying on after it: radians a second
local last = { drawn = 0, ms = 0, made = 0, ground = 0, map = 0, names = 0 }
local frame = 0                       -- each drawing's number
local drawnNow, drawnBefore = {}, {}  -- the pieces drawn this time and the time before
local pool = {}                       -- textures given back, for the next piece
local owned = {}                      -- pieces holding a texture
local labels                          -- the names on the globe (made at the first drawing)

-- each style's sea and the rim round it
local SEAS = {
	parchment = { sea = LAYOUT.sea or { 0.72, 0.68, 0.56 }, rim = { 0.30, 0.20, 0.10, 0.45 } },
	minimap = { sea = { 0.03, 0.10, 0.22 }, rim = { 0.35, 0.60, 1, 0.22 } },
}
local colours = {}
local function Colour(slot, r, g, b, a)
	local c = colours[slot]
	if not c then
		c = CreateColor(r, g, b, a)
		colours[slot] = c
	end
	c:SetRGBA(r, g, b, a)
	return c
end

-- Can this client move a picture's corners? (Without it there is no globe to draw.)
local function CanBend()
	local probe = UIParent:CreateTexture(nil, 'BACKGROUND')
	local can = type(probe.SetVertexOffset) == 'function'
	probe:Hide()
	return can
end

local function Round(texture)
	local mask = canvas:CreateMaskTexture()
	mask:SetTexture('Interface\\CHARACTERFRAME\\TempPortraitAlphaMask', 'CLAMPTOBLACKADDITIVE', 'CLAMPTOBLACKADDITIVE')
	mask:SetAllPoints(texture)
	texture:AddMaskTexture(mask)
end

-- Where a direction on the sphere is seen: x, y from the middle of the picture (points), and its depth.
local function Seen(p, r)
	local b = basis
	local z = p[1] * b[1] + p[2] * b[2] + p[3] * b[3]
	local k = EYE / (EYE - z) * r
	return (p[1] * b[4] + p[2] * b[5] + p[3] * b[6]) * k, (p[1] * b[7] + p[2] * b[8] + p[3] * b[9]) * k, z
end

-- The point of the sphere seen at x, y (points from the middle), or nil off the globe.
local function Under(x, y)
	if not basis then return nil end
	local a, c = x / (EYE * look.r), y / (EYE * look.r)
	local s = a * a + c * c
	local disc = EYE * EYE - (s + 1) * (EYE * EYE - 1)
	if disc < 0 then return nil end
	local w = (EYE - sqrt(disc)) / (s + 1)             -- (the nearer of the two crossings)
	local vx, vy, vz = a * w, c * w, EYE - w
	local b = basis
	return { vx * b[4] + vy * b[7] + vz * b[1], vx * b[5] + vy * b[8] + vz * b[2], vx * b[6] + vy * b[9] + vz * b[3] }
end

-- Turn the globe by what the pointer moved (points): the ground under it follows it.
local function Turn(dx, dy)
	look.lon = look.lon - dx / (look.r * FRONT * max(0.25, cos(look.lat)))
	look.lat = max(-1.45, min(1.45, look.lat - dy / (look.r * FRONT)))
end

-- Turn the globe until the point p is seen at x, y (a few steps, each nearer).
local function Hold(p, x, y)
	for _ = 1, 4 do
		basis = { Basis(look.lat, look.lon) }
		local sx, sy, z = Seen(p, look.r)
		if z <= SEEN then return end
		Turn(x - sx, y - sy)
	end
	basis = { Basis(look.lat, look.lon) }
end

-- The pointer, in points from the middle of the picture; nil when it is not over it.
local function Pointer()
	local cx, cy = view:GetCenter()
	if not cx then return 0, 0 end
	local x, y = GetCursorPosition()
	local s = view:GetEffectiveScale()
	return x / s - cx, y / s - cy
end

-- Where you are: your continent, your place on the sphere, and your world x, y.
local function MyPlace()
	local x, y, _, map = UnitPosition('player')
	local c = map and continents[map]
	if not (x and c) or (issecretvalue and (issecretvalue(x) or issecretvalue(y))) then return nil end
	return c, WorldOnGlobe(c, x, y), x, y
end

local function Smooth(a, b, x)
	if b <= a then return x >= b and 1 or 0 end
	local t = max(0, min(1, (x - a) / (b - a)))
	return t * t * (3 - 2 * t)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local half = VIEW / 2

local function Acquire(layer)
	local t = table.remove(pool)
	if not t then
		t = canvas:CreateTexture(nil, 'ARTWORK')
		if t.SetSnapToPixelGrid then
			t:SetSnapToPixelGrid(false)
			t:SetTexelSnappingBias(0)
		end
		-- (it rests on the whole picture, once: after that only its corners are moved, which is much
		-- cheaper for the game than placing it again)
		t:SetPoint('TOPLEFT', canvas, 'TOPLEFT', 0, 0)
		t:SetSize(VIEW, VIEW)
		last.made = last.made + 1
	end
	t:SetDrawLayer('ARTWORK', layer == 'ground' and 3 or layer == 'detail' and 2 or layer == 'ours' and 1 or 0)
	return t
end

local function Give(p)
	p.tex:Hide()
	pool[#pool + 1] = p.tex
	p.tex, p.shown, p.colourKey = nil, false, nil
	owned[p] = nil
end

local function Show(p, x1, y1, x2, y2, x3, y3, x4, y4, lit, alpha)
	local t = p.tex
	if not t then
		t = Acquire(p.pic.layer)
		p.tex = t
		owned[p] = true
		local c, pic = p.pic.coords, p.pic
		t:SetTexture(pic.fdid)
		local du, dv = c[2] - c[1], c[4] - c[3]
		t:SetTexCoord(c[1] + du * p.fu0, c[1] + du * p.fu1, c[3] + dv * p.fv0, c[3] + dv * p.fv1)
	end
	-- each corner moved from where it rests (the picture's corners) to where it is seen
	t:SetVertexOffset(1, x1 + half, y1 - half)
	t:SetVertexOffset(2, x2 + half, y2 + half)
	t:SetVertexOffset(3, x3 - half, y3 - half)
	t:SetVertexOffset(4, x4 - half, y4 + half)
	-- how much shows: the level's fade, and toward a continent map's edges its own (as a gradient across
	-- the piece, the way it changes most; worked out once a piece). Set only when it changes enough to see.
	lit, alpha = floor(lit * 48 + 0.5) / 48, floor(alpha * 64 + 0.5) / 64
	local key = lit * 100 + alpha
	if key ~= p.colourKey then
		p.colourKey = key
		local Fade = p.pic.Fade
		if Fade and not p.fade then
			local fl, fr = Fade(p.fu0, (p.fv0 + p.fv1) / 2), Fade(p.fu1, (p.fv0 + p.fv1) / 2)
			local ft, fb = Fade((p.fu0 + p.fu1) / 2, p.fv0), Fade((p.fu0 + p.fu1) / 2, p.fv1)
			if abs(fl - fr) >= abs(ft - fb) and abs(fl - fr) > 0.01 then
				p.fade = { 'HORIZONTAL', fl, fr }
			elseif abs(ft - fb) > 0.01 then
				p.fade = { 'VERTICAL', fb, ft }        -- (a vertical gradient's first colour is its bottom)
			else
				p.fade = { false, (fl + fr + ft + fb) / 4 }
			end
		end
		local f = p.fade
		if f and f[1] then
			t:SetGradient(f[1], Colour(1, lit, lit, lit, alpha * f[2]), Colour(2, lit, lit, lit, alpha * f[3]))
		else
			t:SetVertexColor(lit, lit, lit, alpha * (f and f[2] or 1))
		end
	end
	if not p.shown then
		t:Show()
		p.shown = true
	end
	p.seen = GetTime()
	p.frame = frame
	drawnNow[#drawnNow + 1] = p
end

-- One piece: dropped when it is wholly behind or out of the window, split while it is too large to
-- lie flat or crosses the globe's edge, else drawn.
-- A corner behind the globe's edge, slid along the sphere onto the edge (where it is seen last).
local function OnEdge(p, r)
	local b = basis
	local z = p[1] * b[1] + p[2] * b[2] + p[3] * b[3]
	local tx, ty, tz = p[1] - z * b[1], p[2] - z * b[2], p[3] - z * b[3]
	local tl = sqrt(tx * tx + ty * ty + tz * tz)
	if tl < 1e-9 then return Seen(p, r) end
	local s = sqrt(1 - SEEN * SEEN) / tl
	return Seen({ SEEN * b[1] + tx * s, SEEN * b[2] + ty * s, SEEN * b[3] + tz * s }, r)
end

-- One piece: dropped when it is wholly behind or out of the window, split while it is too large to lie
-- flat, else drawn. One across the globe's edge with its middle in front is drawn with its corners
-- behind the edge slid onto it (once it is small enough), so it neither folds over nor leaves a gap.
local function Visit(p, r, alpha, shade)
	local zm = Dot(p.mid, basis)
	if zm < p.hideBelow then return end
	local x1, y1, z1 = Seen(p.ul, r)
	local x2, y2, z2 = Seen(p.ll, r)
	local x3, y3, z3 = Seen(p.ur, r)
	local x4, y4, z4 = Seen(p.lr, r)
	local front = z1 > SEEN and z2 > SEEN and z3 > SEEN and z4 > SEEN and zm > SEEN
	if (max(x1, x2, x3, x4) < -half or min(x1, x2, x3, x4) > half
		or max(y1, y2, y3, y4) < -half or min(y1, y2, y3, y4) > half) and (front or zm < SEEN) then
		return
	end
	local deep = p.depth >= DEEPEST[p.pic.layer]
	if not front then
		-- (across the edge: split while large, then drawn with its corners on the edge; dropped if its
		-- middle is behind and it can be split no more)
		local size = max(max(x1, x2, x3, x4) - min(x1, x2, x3, x4), max(y1, y2, y3, y4) - min(y1, y2, y3, y4))
		if not deep and (zm <= SEEN or size > EDGE_PIECE * 8) then
			for _, kid in ipairs(Halves(p)) do Visit(kid, r, alpha, shade) end
			return
		end
		if zm <= SEEN then return end
		if z1 <= SEEN then x1, y1 = OnEdge(p.ul, r) end
		if z2 <= SEEN then x2, y2 = OnEdge(p.ll, r) end
		if z3 <= SEEN then x3, y3 = OnEdge(p.ur, r) end
		if z4 <= SEEN then x4, y4 = OnEdge(p.lr, r) end
		if max(x1, x2, x3, x4) < -half or min(x1, x2, x3, x4) > half
			or max(y1, y2, y3, y4) < -half or min(y1, y2, y3, y4) > half then
			return
		end
		-- (slid corners can turn a sliver inside out: split it, or leave it out)
		if (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1) < 0 or (x4 - x3) * (y2 - y3) - (y4 - y3) * (x2 - x3) > 0 then
			if not deep then
				for _, kid in ipairs(Halves(p)) do Visit(kid, r, alpha, shade) end
			end
			return
		end
	elseif not deep then
		-- (toward the globe's edge, where everything is squeezed, more is let pass)
		local mx, my = Seen(p.mid, r)
		local edge = 1 - zm
		if abs(mx - (x1 + x2 + x3 + x4) / 4) + abs(my - (y1 + y2 + y3 + y4) / 4) > CURVE * (1 + 10 * edge * edge) then
			for _, kid in ipairs(Halves(p)) do Visit(kid, r, alpha, shade) end
			return
		end
	end
	-- even light, darkening a little toward the globe's edge
	local lit = shade and (0.62 + 0.38 * sqrt(max(0, (zm - SEEN) / (1 - SEEN)))) or 1
	Show(p, x1, y1, x2, y2, x3, y3, x4, y4, lit, alpha)
end

-- The names: the continents, and the zones in each, from the game's map list.
local function MakeLabels()
	labels = {}
	PrepareArt()
	local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
	for _, c in pairs(continents) do
		local uiMap = c.uiMap
		local okI, info = pcall(C_Map.GetMapInfo, uiMap or 0)
		if uiMap and okI and type(info) == 'table' and type(info.name) == 'string' then
			labels[#labels + 1] = { kind = 'continent', text = info.name, at = { OnGlobe(c, c.cx, c.cy) } }
			local ok, zones = pcall(C_Map.GetMapChildrenInfo, uiMap, zoneType)
			for _, z in ipairs(ok and type(zones) == 'table' and zones or {}) do
				local okW, map, w = pcall(C_Map.GetWorldPosFromMapPos, z.mapID, CreateVector2D(0.5, 0.5))
				if okW and map == c.map and w and type(z.name) == 'string' then
					local wx, wy = w:GetXY()
					labels[#labels + 1] = { kind = 'zone', text = z.name, at = WorldOnGlobe(c, wx, wy) }
				end
			end
		end
	end
	if pictures.world then
		for _, sea in ipairs(SEAS_NAMED) do
			local lat, lon = sea[2], sea[3]
			labels[#labels + 1] = { kind = 'sea', text = sea[1], at = { cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat) } }
		end
	end
	for _, label in ipairs(labels) do
		local style = NAMES[label.kind]
		local fs = canvas:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		local flags = style.plain and '' or 'OUTLINE'
		if not fs:SetFont(style.font, style.size, flags) then fs:SetFont('Fonts\\FRIZQT__.TTF', style.size, flags) end
		fs:SetTextColor(style.colour[1], style.colour[2], style.colour[3])
		fs:SetText(label.text)
		fs:Hide()
		label.fs = fs
	end
end

local function PaintLabels(r)
	if not labels then MakeLabels() end
	local on = ns.Get('globeNames')
	for _, label in ipairs(labels) do
		local style = NAMES[label.kind]
		local a = on and Smooth(style.from, style.full, r) * (1 - Smooth(style.fade, style.gone, r)) or 0
		local x, y, z = Seen(label.at, r)
		a = a * Smooth(SEEN + 0.03, SEEN + 0.2, z)
		if a > 0.02 and abs(x) < half and abs(y) < half then
			label.fs:ClearAllPoints()
			label.fs:SetPoint('CENTER', canvas, 'CENTER', x, y)
			label.fs:SetAlpha(min(1, a))
			label.fs:Show()
			label.shown, label.x, label.y, label.alpha = true, x, y, a
		else
			label.fs:Hide()
			label.shown = false
		end
	end
end

-- Your place: an arrow turned the way you face (a dot where the game does not say which way).
local function PaintMe()
	arrow:Hide()
	dot:Hide()
	if not basis then return end
	local c, me, wx, wy = MyPlace()
	if not me then return end
	local x, y, z = Seen(me, look.r)
	if z <= SEEN or abs(x) > half or abs(y) > half then return end
	local facing = GetPlayerFacing and GetPlayerFacing()
	if type(facing) == 'number' and not (issecretvalue and issecretvalue(facing)) then
		-- (facing: 0 is north, turning toward the west; north is world x, west is world y)
		local ax, ay = Seen(WorldOnGlobe(c, wx + 20 * cos(facing), wy + 20 * sin(facing)), look.r)
		arrow:ClearAllPoints()
		arrow:SetPoint('CENTER', canvas, 'CENTER', x, y)
		arrow:SetRotation(atan2(ay - y, ax - x) - math.pi / 2)
		arrow:Show()
	else
		dot:ClearAllPoints()
		dot:SetPoint('CENTER', canvas, 'CENTER', x, y)
		dot:Show()
	end
end

local function Stats()
	if not ns.Get('globeStats') then statsText:Hide(); return end
	statsText:SetText(('%d pieces (%d map, %d ground) in %.1f ms (names %.1f), %d fps, zoom %.1fx%s')
		:format(last.drawn, last.map, last.drawn - last.map, last.ms, last.names, floor((GetFramerate() or 0) + 0.5), look.r / RMIN,
			(last.ground > 0 and last.ground < 1) and (', ground %d%%'):format(floor(last.ground * 100 + 0.5)) or ''))
	statsText:Show()
end

local function Paint()
	dirty = false
	local started = debugprofilestop()
	frame = frame + 1
	basis = { Basis(look.lat, look.lon) }
	local r = look.r
	local style = ns.Get('globeStyle') == 'minimap' and 'minimap' or 'parchment'
	local shade = ns.Get('globeLight')
	local sea = SEAS[style]
	ocean:SetColorTexture(sea.sea[1], sea.sea[2], sea.sea[3], 1)
	halo:SetColorTexture(sea.rim[1], sea.rim[2], sea.rim[3], sea.rim[4])
	ocean:SetSize(2 * r * LIMB, 2 * r * LIMB)
	halo:SetSize(2 * r * LIMB * 1.05, 2 * r * LIMB * 1.05)
	drawnBefore, drawnNow = drawnNow, drawnBefore
	for i = #drawnNow, 1, -1 do drawnNow[i] = nil end
	-- the continent maps, then the ground over them, faded in as you zoom
	local ground = 1
	if style == 'parchment' then
		ground = Smooth(GROUND_FROM, GROUND_TO, r)
		if not pictures.world then                 -- (the game's continent maps, until our world picture is there)
			PrepareArt()
			for _, pic in ipairs(pictures.art) do
				pic.root = pic.root or Piece(pic, 0, 1, 0, 1, 0)
				Visit(pic.root, r, 1, shade)
			end
		end
		for _, pic in ipairs(pictures.ours) do
			pic.root = pic.root or Piece(pic, 0, 1, 0, 1, 0)
			Visit(pic.root, r, 1, shade)
		end
		local detail = Smooth(DETAIL_FROM, DETAIL_TO, r)
		if detail > 0.005 then
			for _, pic in ipairs(pictures.detail) do
				pic.root = pic.root or Piece(pic, 0, 1, 0, 1, 0)
				Visit(pic.root, r, detail, shade)
			end
		end
	end
	for _, pic in ipairs(pictures.ground) do
		-- (a continent with no world map of its own shows its ground at every zoom)
		local alpha = (pic.c.hasArt or pictures.world) and ground or 1
		if alpha > 0.005 then
			pic.root = pic.root or Piece(pic, 0, 1, 0, 1, 0)
			Visit(pic.root, r, alpha, shade)
		end
	end
	for _, p in ipairs(drawnBefore) do
		if p.frame ~= frame and p.shown then
			p.tex:Hide()
			p.shown = false
		end
	end
	local named = debugprofilestop()
	PaintLabels(r)
	PaintMe()
	local map = 0
	for _, p in ipairs(drawnNow) do
		if p.pic.layer ~= 'ground' then map = map + 1 end
	end
	last.drawn, last.map, last.ms, last.names = #drawnNow, map, debugprofilestop() - started, debugprofilestop() - named
	last.ground = style == 'parchment' and ground or 1
	Stats()
end

-- Pieces unseen for a while give their textures back.
local function Tidy()
	local now = GetTime()
	for p in pairs(owned) do
		if not p.shown and now - (p.seen or 0) > RELEASE then Give(p) end
	end
end

local function Changed() dirty = true end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function Build()
	if window then return true end
	if not CanBend() then
		ns.Print('This game client cannot bend pictures (no Texture:SetVertexOffset), so there is no globe to draw.')
		return false
	end
	Prepare()
	window = CreateFrame('Frame', 'PatchwerkForever_Thread_GlobeWindow', UIParent)
	window:SetSize(VIEW + 20, VIEW + 64)
	window:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	window:SetFrameStrata('HIGH')
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:EnableMouse(true)
	window:RegisterForDrag('LeftButton')
	window:SetScript('OnDragStart', window.StartMoving)
	window:SetScript('OnDragStop', window.StopMovingOrSizing)
	local back = window:CreateTexture(nil, 'BACKGROUND')
	back:SetAllPoints(window)
	back:SetColorTexture(0.02, 0.02, 0.04, 0.92)
	local title = window:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	title:SetPoint('TOP', window, 'TOP', 0, -9)
	title:SetText('Globe')
	local close = CreateFrame('Button', nil, window, 'UIPanelCloseButton')
	close:SetPoint('TOPRIGHT', window, 'TOPRIGHT', 0, 0)
	tinsert(UISpecialFrames, window:GetName())

	view = CreateFrame('Frame', nil, window)
	view:SetSize(VIEW, VIEW)
	view:SetPoint('TOP', window, 'TOP', 0, -30)
	view:SetClipsChildren(true)
	view:EnableMouse(true)
	view:EnableMouseWheel(true)
	canvas = CreateFrame('Frame', nil, view)
	canvas:SetAllPoints(view)

	halo = canvas:CreateTexture(nil, 'BACKGROUND', nil, 0)
	halo:SetPoint('CENTER', canvas, 'CENTER', 0, 0)
	Round(halo)
	ocean = canvas:CreateTexture(nil, 'BACKGROUND', nil, 1)
	ocean:SetPoint('CENTER', canvas, 'CENTER', 0, 0)
	Round(ocean)
	dot = canvas:CreateTexture(nil, 'OVERLAY')
	dot:SetSize(10, 10)
	dot:SetColorTexture(1, 0.85, 0.2, 1)
	Round(dot)
	dot:Hide()
	arrow = canvas:CreateTexture(nil, 'OVERLAY', nil, 1)
	arrow:SetSize(28, 28)
	arrow:SetTexture('Interface\\Minimap\\MinimapArrow')
	arrow:Hide()

	statsText = window:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	statsText:SetPoint('BOTTOMLEFT', window, 'BOTTOMLEFT', 12, 12)
	local me = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
	me:SetSize(110, 22)
	me:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -10, 7)
	me:SetText('Where I Am')
	me:SetScript('OnClick', function() ns.CenterOnMe() end)

	-- turning: the point under the pointer follows it, and carries on a little after; zooming: the
	-- wheel, eased, toward the pointer; a double-click zooms in on a spot
	local drag, lastDown
	view:SetScript('OnMouseDown', function(_, button)
		if button ~= 'LeftButton' then return end
		local x, y = Pointer()
		local now = GetTime()
		if lastDown and now - lastDown.t < 0.35 and abs(x - lastDown.x) + abs(y - lastDown.y) < 6 then
			local p = Under(x, y)
			if p then aim.r, aim.p, aim.x, aim.y = min(RMAX, look.r * 2), p, x, y end
			lastDown = nil
		else
			lastDown = { t = now, x = x, y = y }
		end
		drag = { x = x, y = y, vlat = 0, vlon = 0 }
		glide, coast = nil, nil
	end)
	view:SetScript('OnMouseUp', function()
		if drag and abs(drag.vlat) + abs(drag.vlon) > 0.02 then coast = { lat = drag.vlat, lon = drag.vlon } end
		drag = nil
	end)
	view:SetScript('OnMouseWheel', function(_, delta)
		glide, coast = nil, nil
		local x, y = Pointer()
		aim.r = max(RMIN, min(RMAX, aim.r * (delta > 0 and 1.3 or 1 / 1.3)))
		aim.p, aim.x, aim.y = Under(x, y), x, y
		Changed()
	end)
	local since, tidied = 0, 0
	window:SetScript('OnUpdate', function(_, elapsed)
		elapsed = min(elapsed, 0.1)
		if drag then
			local x, y = Pointer()
			local dx, dy = x - drag.x, y - drag.y
			local lat0, lon0 = look.lat, look.lon
			if dx ~= 0 or dy ~= 0 then
				drag.x, drag.y = x, y
				Turn(dx, dy)
				Changed()
			end
			-- (how fast it turns, smoothed, for the coast after)
			local k = min(1, elapsed * 12)
			drag.vlat = drag.vlat + ((look.lat - lat0) / elapsed - drag.vlat) * k
			drag.vlon = drag.vlon + ((look.lon - lon0) / elapsed - drag.vlon) * k
		elseif coast then
			look.lat = max(-1.45, min(1.45, look.lat + coast.lat * elapsed))
			look.lon = look.lon + coast.lon * elapsed
			local keep = exp(-elapsed * 4)
			coast.lat, coast.lon = coast.lat * keep, coast.lon * keep
			if abs(coast.lat) + abs(coast.lon) < 0.003 then coast = nil end
			Changed()
		end
		if glide then
			glide.t = min(1, glide.t + elapsed / GLIDE)
			local s = glide.t * glide.t * (3 - 2 * glide.t)      -- (eased in and out)
			look.lat = glide.lat + glide.dlat * s
			look.lon = glide.lon + glide.dlon * s
			look.r = exp(glide.lr + glide.dlr * s)               -- (the zoom eased by its ratio, so it feels even)
			aim.r, aim.p = look.r, nil
			if glide.t >= 1 then glide = nil end
			Changed()
		elseif abs(log(aim.r / look.r)) > 0.002 then
			look.r = exp(log(look.r) + log(aim.r / look.r) * min(1, elapsed * 12))
			if abs(log(aim.r / look.r)) <= 0.002 then look.r = aim.r end
			if aim.p then Hold(aim.p, aim.x, aim.y) end
			Changed()
		elseif aim.p then
			aim.p = nil
		end
		since, tidied = since + elapsed, tidied + elapsed
		if dirty then
			ns.Try('the globe', Paint)
			since = 0
		elseif since > 0.25 then              -- (your place and facing, four times a second)
			since = 0
			ns.Try('the globe', PaintMe)
			Stats()
		end
		if tidied > 5 then
			tidied = 0
			Tidy()
		end
	end)
	window:SetScript('OnShow', Changed)
	window:Hide()
	return true
end

function ns.Toggle(on)
	if not Build() then return end
	if on == true or not window:IsShown() then
		window:Show()
		Changed()
	else
		window:Hide()
	end
end

function ns.CenterOnMe()
	if not Build() then return end
	local _, me = MyPlace()
	if not me then
		ns.Print('Your place is not on the globe here (inside a dungeon, or on a map the globe does not have).')
		return
	end
	-- glide there: the short way round, zooming in to see the land round you
	local lat, lon = asin(max(-1, min(1, me[3]))), atan2(me[2], me[1])
	local dlon = (lon - look.lon + math.pi) % (2 * math.pi) - math.pi
	local r = max(look.r, VIEW * 4)
	glide, coast = { t = 0, lat = look.lat, dlat = lat - look.lat, lon = look.lon, dlon = dlon,
		lr = log(look.r), dlr = log(r) - log(look.r) }, nil
	Changed()
end

function ns.SayStats()
	Prepare()
	local style = ns.Get('globeStyle') == 'minimap' and 'Minimap pictures' or 'Parchment'
	ns.Print(('%s: %d pieces drawn at the last drawing, in %.1f ms; %d textures made, %d spare; %d fps.')
		:format(style, last.drawn, last.ms, last.made, #pool, floor((GetFramerate() or 0) + 0.5)))
end

-- For the checks outside the game: what was drawn last, and where.
function ns.GlobeState()
	local out = { look = look, drawn = {}, labels = {} }
	for _, p in ipairs(drawnNow) do
		local r = look.r
		local x1, y1 = Seen(p.ul, r)
		local x2, y2 = Seen(p.ll, r)
		local x3, y3 = Seen(p.ur, r)
		local x4, y4 = Seen(p.lr, r)
		out.drawn[#out.drawn + 1] = { fdid = p.pic.fdid, layer = p.pic.layer, depth = p.depth,
			fu0 = p.fu0, fu1 = p.fu1, fv0 = p.fv0, fv1 = p.fv1, x = { x1, x2, x3, x4 }, y = { y1, y2, y3, y4 } }
	end
	for _, label in ipairs(labels or {}) do
		out.labels[#out.labels + 1] = { text = label.text, kind = label.kind, shown = label.shown == true,
			x = label.x, y = label.y }
	end
	return out
end

ns.OnSetting(function(key)
	if key:find('^globe') then Changed() end
end)
