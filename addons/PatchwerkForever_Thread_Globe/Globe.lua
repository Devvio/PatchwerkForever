-- Globe (Thread): the world on a globe you can spin and zoom.
--
-- An addon cannot make a 3D shape, but it can move the four corners of a picture anywhere on the
-- screen (Texture:SetVertexOffset). So the globe is a ball of pictures: each is laid on the sphere,
-- and every time the globe turns, its four corners are worked out where the eye sees them, in
-- perspective, and the picture is stretched between them.
--
-- The pictures (GLOBE-BLUEPRINT.md), coarsest first, each fading in over the one before as you zoom in:
--   the world            our own parchment picture of the whole sphere (Art.lua, kind 'world')
--   the detail           our own, each continent at 8 yards a pixel (kind 'detail')
--   the ground           the game's own, asked for by number: each terrain tile's minimap picture
--                        (Tiles.lua), in true colour. Drawn where there is land, fading out to the
--                        parchment sea over the tiles round it. With Map Style: Minimap Pictures it is
--                        all there is, at every zoom.
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
--
-- Hand-made pieces (Art.lua): a compass rose, sea serpents and ships in ink on the open sea, each a
-- picture of its own on the sphere; and a brass ring round the ball (the ring's picture may have a stand
-- under it, or none: its numbers in Art.lua say what is drawn). Zoomed right out, the whole of that
-- picture is in view, the ball as far above the middle as it takes to sit it evenly; zooming in, the
-- ball comes to the middle and grows past the picture, the ring with it.
--
-- Zones (Zones.lua): the one under the pointer is outlined and named; a click turns and zooms the
-- globe to fit it, and a right-click steps back out, to the continent and then the whole globe.
--
-- The window is sized by its corner or fills the screen, and remembers both. Everything the mouse does
-- can be done with keys (Bindings.xml) and with a gamepad (Pad.lua), through ns.GlobeKey: turning and
-- zooming while a key is held, and, with no pointer to go by, the middle of the picture (marked with a
-- cross) standing in for it. Go To lists the continents and their zones.
--
-- What is shown on the globe besides the map itself (marks, trails, quests, people) is in the files
-- after this one. They reach the globe through ns.G (its geometry and frames) and ns.GlobeOn (to be
-- told of a drawing, a frame, a press, a key, the window opening and closing).
local ADDON, ns = ...
if not ns.linked then return end

local sin, cos, sqrt, floor, min, max, abs = math.sin, math.cos, math.sqrt, math.floor, math.min, math.max, math.abs
local asin, acos, atan2, exp, log = math.asin, math.acos, math.atan2 or math.atan, math.exp, math.log

local TILE = 1600 / 3                 -- yards across a terrain tile
local EDGE = 32 * TILE                -- the world's edge, from its middle (as Routes (Thread) counts cells)
-- the layout comes from Art.lua, written with the pictures (tools/globe_art.py), so the two always agree
local LAYOUT = ns.LAYOUT or {}
local RW = LAYOUT.rw or 19000         -- yards of the world to a radian of the globe (Kalimdor: about 90 degrees tall)
local EYE = 4                         -- the eye, in radii of the globe from its middle
local SEEN = 1 / EYE                  -- a point of the sphere is seen while it is nearer the eye than this
local HIDDEN = acos(SEEN)             -- (the angle from the middle of the view past which nothing is seen)
local LIMB = EYE / sqrt(EYE * EYE - 1)  -- the globe's edge as seen, in radii (a little wider: perspective)
local FRONT = EYE / (EYE - 1)         -- how much larger the point nearest the eye is seen
local VIEW = 600                      -- the picture as it first opens, in points; zoom levels are counted in it
-- The picture can be any size (the window is sized by its corner, or fills the screen): everything is
-- laid out from the globe's middle, and what depends on the picture's size is worked out by Sized.
local viewW, viewH = VIEW, VIEW       -- the picture now (points)
-- The brass ring (Art.lua): its hole is a little wider than the ball. Zoomed right out, the whole of
-- its picture is in view, 8 points clear above and below. The ball is lifted by half of what the picture
-- has more under the hole's middle than over it: a long way for a ring on a stand, hardly at all for a
-- ring alone (and down, should there be more over it).
local RING = ns.RING
local RING_GAP = 1.03                 -- the ring's hole, in radii of the ball as seen
local RMIN, LIFT                      -- the smallest globe (points), and how far it is lifted then
local LIFT_GONE                       -- the globe is in the middle again by this radius (it fills the picture)
local RMAX = VIEW * 60
local function Sized(w, h)
	viewW, viewH = w, h
	local least = min(w, h)
	RMIN, LIFT = least * 0.42, 0
	if RING then
		-- (the ring's picture, in points: as tall as the picture lets it be, and no wider than it)
		local side = min((h - 16) / (RING.bottom - RING.top), w)
		RMIN = side * RING.inner / (RING_GAP * LIMB)
		LIFT = (RING.bottom + RING.top - 2 * RING.cy) * side / 2
	end
	LIFT_GONE = least / 2 / LIMB * 0.95
end
Sized(VIEW, VIEW)
-- Where each continent's middle sits: latitude, longitude (radians). Kalimdor west, the Eastern
-- Kingdoms east (as on the game's world map), Zephra's Isle in the southern sea between them.
local PLACE = { [1] = { 0.05, -1.05 }, [0] = { 0.10, 1.05 }, [2991] = { -0.75, 0.0 } }
local CONTINENT_MAPS = { [1] = 1414, [0] = 1415 }      -- their world maps (others found through the world map, 947)
local GLIDE = 1.1                     -- seconds Where I Am takes to turn the globe there
-- splitting: a piece whose middle is seen this far (points) off the middle of its corners is split;
-- a picture is split this deep at most (each step halves it)
local CURVE = 1.5
-- (what lies over the map with nothing in it to line up with the map's own lines is split less finely: a
-- stain or a cloud a few points from where the sphere would have it looks the same, and costs a quarter)
local CURVES = { age = 5, wear = 4, sky = 8, cover = 2.5, wash = 2.5 }
local EDGE_PIECE = 10                 -- a piece crossing the globe's edge this small (points) is dropped: the sea disc shows there
local DEEPEST = { art = 4, ours = 8, detail = 5, decor = 4, ground = 2, cover = 4, wash = 4, age = 4, wear = 4, sky = 5 }
-- a ground tile that fades out toward a corner is cut smaller, since a piece can fade only straight
-- across or straight down: as deep as this at most, and no smaller than this on the screen (points)
local FADE_DEEPEST, FADE_PIECE = 4, 48
local NEAR_MOST = 10                  -- the ground is picked by place while the picture shows fewer tiles than this from its middle
-- which is drawn over which: the map, the ground, the fog over undiscovered land, the wash that
-- colours a zone by its levels (over the fog too: where to go next is mostly land not yet
-- seen), then the paper's age and the clouds
local SUBLEVEL = { art = -3, ours = -2, detail = -1, decor = 0, ground = 1, cover = 2, wash = 3, age = 4, wear = 5, sky = 6 }
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
-- (the Maelstrom is drawn at the middle of the Great Sea, tools/globe_art.py: its name is under it, and
-- the sea's own name south of that)
local SEAS_NAMED = {
	{ 'The Great Sea', -0.42, 0.0 }, { 'The Veiled Sea', 0.15, -2.35 }, { 'The Forbidding Sea', 0.30, 2.25 },
	{ 'The South Seas', -0.95, -1.2 }, { 'The Maelstrom', -0.20, 0.0 },
}
-- zones (Zones.lua, made by tools/globe_art.py from the area of each terrain chunk)
local ZONES = ns.ZONES or {}
local LINE = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\line'     -- (across it: dark edges, a pale middle)
local LINE_WIDTH = 5                  -- an outline's width (points)
local LINE_STEP = 3                   -- an outline's points nearer than this on the screen (points) are passed over
local FIT = 0.82                      -- a zone fitted takes up this much of the picture
local CLICK = 5                       -- a press that moves less than this (points) is a click, not a drag
local EDGES_W, EDGES_H = 20, 64       -- the window round the picture: across, and up and down (title and foot)
local VIEW_LEAST = 320                -- the smallest picture the window can be sized to
local side = 0                        -- room kept at the window's right for a panel beside the picture (ns.GlobeSide)
local KEY_TURN = 420                  -- a held key turns the globe as a drag this fast would (points a second)
local KEY_ZOOM = 1.6                  -- and zooms this fast (the zoom's logarithm a second)

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
-- shows there: 1, less toward a continent map's edges), tint ({ r, g, b }: it is drawn in that colour;
-- a picture given another tint table is coloured again), c (its continent), root (its first piece) }.
local pictures = { art = {}, ours = {}, detail = {}, decor = {}, ground = {} }

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
			-- The ground is drawn where there is land (Zones.lua says which tiles have any). So that it
			-- does not end in a square edge out at sea, each corner between tiles is worth 1 where one of
			-- the four tiles round it has land, and 0 where none has (or one of them has no picture at
			-- all); a tile shows as much as its corners say, fading between them. So the tiles of open sea
			-- next to land fade out, and those further off are left to the parchment.
			local data, landed = ZONES[c.map], nil
			if data and type(data.land) == 'string' then
				landed = {}
				for index in data.land:gmatch('%d+') do landed[tonumber(index)] = true end
			end
			local function Corner(x, y)
				local any = false
				for ty = y - 1, y do
					for tx = x - 1, x do
						if tx < 0 or tx > 63 or ty < 0 or not c.tiles[ty * 64 + tx] then return 0 end
						any = any or landed[ty * 64 + tx]
					end
				end
				return any and 1 or 0
			end
			c.ground = {}
			for index, fdid in pairs(c.tiles) do
				local tx, ty = index % 64, floor(index / 64)
				local pic = { fdid = fdid, layer = 'ground', c = c, coords = { 0, 1, 0, 1 },
					At = function(fu, fv) return { OnGlobe(c, tx + fu, ty + fv) } end }
				local shows = true
				if landed then
					local ul, ur, ll, lr = Corner(tx, ty), Corner(tx + 1, ty), Corner(tx, ty + 1), Corner(tx + 1, ty + 1)
					shows = ul + ur + ll + lr > 0
					if shows and ul + ur + ll + lr < 4 then
						pic.Fade = function(fu, fv)
							return (ul + (ur - ul) * fu) * (1 - fv) + (ll + (lr - ll) * fu) * fv
						end
						-- (fading toward a corner, not straight across or down: cut smaller)
						if ul + lr ~= ur + ll then pic.deepest, pic.uneven = FADE_DEEPEST, true end
					end
				end
				if shows then
					pictures.ground[#pictures.ground + 1] = pic
					c.ground[index] = pic
				end
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
		elseif a.kind == 'decor' then
			-- (an ink piece on the open sea: a square round its middle, its distances kept from there)
			local b, size = { Basis(a.lat, a.lon) }, a.size
			-- (flip: the picture turned to face the other way)
			pictures.decor[#pictures.decor + 1] = { fdid = a.file, layer = 'decor', coords = a.flip and { 1, 0, 0, 1 } or { 0, 1, 0, 1 },
				At = function(fu, fv)
					local e, n = (fu - 0.5) * size, (0.5 - fv) * size
					local d = sqrt(e * e + n * n)
					if d < 1e-9 then return { b[1], b[2], b[3] } end
					local cr, sr = cos(d), sin(d) / d
					return { cr * b[1] + sr * (e * b[4] + n * b[7]), cr * b[2] + sr * (e * b[5] + n * b[8]),
						cr * b[3] + sr * (e * b[6] + n * b[9]) }
				end }
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
-- and how far its corners reach from its middle (radians, and straight through the sphere); its four
-- halves made when first needed. A point is { x, y, z } and is the picture's own (At makes it new): a
-- half's corners are the very points of the piece it was cut from, so that where each is seen is worked
-- out once a drawing for all the pieces that meet there (Corner keeps it in the point: [4] the drawing,
-- [5] [6] [7] where it was seen then).
local function Piece(pic, fu0, fu1, fv0, fv1, depth, ul, ll, ur, lr)
	local mid = pic.At((fu0 + fu1) / 2, (fv0 + fv1) / 2)
	ul, ll = ul or pic.At(fu0, fv0), ll or pic.At(fu0, fv1)
	ur, lr = ur or pic.At(fu1, fv0), lr or pic.At(fu1, fv1)
	local least = min(Dot(mid, ul), Dot(mid, ll), Dot(mid, ur), Dot(mid, lr))
	local reach = acos(max(-1, min(1, least)))
	return { pic = pic, fu0 = fu0, fu1 = fu1, fv0 = fv0, fv1 = fv1, depth = depth, ul = ul, ll = ll, ur = ur, lr = lr, mid = mid,
		reach = reach, chord = 2 * sin(reach / 2),
		hideBelow = cos(min(math.pi, HIDDEN + reach)),    -- (wholly behind while its middle is seen less than this)
		deep = depth >= (pic.deepest or DEEPEST[pic.layer]), curve = CURVES[pic.layer] or CURVE,
		-- (a picture that shows unevenly says of each piece: 0 none of it shows, 1 cut it smaller, 2 cut it
		-- smaller while it is large; Explore.lua does, for the ground over land you have not discovered)
		cut = pic.Cut and pic.Cut(fu0, fu1, fv0, fv1, depth) or nil }
end

local function Halves(p)
	local kids = p.kids
	if not kids then
		local pic, fu0, fu1, fv0, fv1, mid = p.pic, p.fu0, p.fu1, p.fv0, p.fv1, p.mid
		local um, vm = (fu0 + fu1) / 2, (fv0 + fv1) / 2
		local d = p.depth + 1
		local top, bottom, left, right = pic.At(um, fv0), pic.At(um, fv1), pic.At(fu0, vm), pic.At(fu1, vm)
		kids = { Piece(pic, fu0, um, fv0, vm, d, p.ul, left, top, mid), Piece(pic, um, fu1, fv0, vm, d, top, mid, p.ur, right),
			Piece(pic, fu0, um, vm, fv1, d, left, p.ll, mid, bottom), Piece(pic, um, fu1, vm, fv1, d, mid, bottom, right, p.lr) }
		p.kids = kids
	end
	return kids
end

---------------------------------------------------------------------------
-- The window's state
---------------------------------------------------------------------------
local window, view, canvas, ocean, halo, dot, arrow, statsText, zoneText, ring, grip, fullButton, cross
-- What the files after this one ask to be told: 'paint' (r: after each drawing of the map), 'frame'
-- (elapsed: each frame the window is shown), 'press' (button, x, y, byKey: a click on the picture, in
-- points from the globe's middle; a function returning true has dealt with it, and the globe does
-- nothing more), 'key' (what: a key the globe itself has no use for), 'show', 'hide', 'place' (the
-- window was put somewhere: full screen or back), 'pictures' (r, shade, style: more pictures to lay on
-- the globe at this drawing, each with G.Draw).
-- A place with a flat map of its own (a city, a battleground) is shown by Flat.lua in the same picture:
-- while it is (ns.FlatOn), the globe draws nothing of its own and is not turned or zoomed.
local hooks = { paint = {}, frame = {}, press = {}, key = {}, show = {}, hide = {}, place = {}, pictures = {} }

-- A text on the globe: its font, and how it is set off from the map under it. The game's fonts come
-- with a drop shadow, and an outline over that is twice as heavy down and to the right: it clogs small
-- letters, and a number looks pushed off the middle of its mark. So a text has an outline and no
-- shadow, or (Name Outline: Shadow) a shadow and no outline, never both.
--   how    nil: a name (as Name Outline says); 'plain': ink on the paper, neither; 'always': an outline
--          whatever the setting (a number on a mark)
--   back   the size in the game's plain font, where this client lacks the font asked for
do
	local texts = {}
	local function Set(fs, t)
		local outline = t.how == 'always' or (t.how ~= 'plain' and ns.Get('globeNameEdge') ~= 'shadow')
		local flags = outline and 'OUTLINE' or ''
		if not fs:SetFont(t.font, t.size, flags) then fs:SetFont('Fonts\\FRIZQT__.TTF', t.back or t.size, flags) end
		if fs.SetShadowOffset and fs.SetShadowColor then
			if outline or t.how == 'plain' then
				fs:SetShadowOffset(0, 0)
			else
				fs:SetShadowColor(0, 0, 0, 1)
				fs:SetShadowOffset(1, -1)
			end
		end
	end
	function ns.GlobeText(fs, font, size, how, back)
		local t = { font = font, size = size, how = how, back = back }
		texts[fs] = t
		Set(fs, t)
		return fs
	end
	ns.OnSetting(function(key)
		if key == 'globeNameEdge' then
			for fs, t in pairs(texts) do Set(fs, t) end
		end
	end)
end
function ns.GlobeOn(what, fn) hooks[what][#hooks[what] + 1] = fn end
local function Fire(what, ...)
	for _, fn in ipairs(hooks[what]) do
		local ok, dealt = pcall(fn, ...)
		if not ok then
			ns.Try('the globe', error, dealt, 0)
		elseif dealt then
			return true
		end
	end
	return false
end
local held = { x = 0, y = 0, z = 0 }  -- keys held: the way the view moves (east, north) and zooms (in), each -1 to 1
local pad = { x = 0, y = 0, z = 0 }   -- and a gamepad's sticks, the same way
local byKeys = false                  -- the last thing done was by key or gamepad: the picture's middle is the pointer
local look = { lat = 0.05, lon = 0, r = RMIN }
local lift = 0                        -- how far the globe is drawn above the middle of the picture (points)
local aim = { r = look.r }            -- the zoom being eased toward, and the point held under the pointer
                                      -- (x, y: where in the picture, from its middle)
local basis                           -- the eye's: out, east, north (Basis of look)
local b1, b2, b3, b4, b5, b6, b7, b8, b9 = 1, 0, 0, 0, 1, 0, 0, 0, 1   -- (the same, for the drawing: no table to look in)
local drawingAt = 0                   -- the time of the drawing being made
local dirty = false
local glide                           -- Where I Am on its way
local coast                           -- a drag's turn carrying on after it: radians a second
local last = { drawn = 0, ms = 0, made = 0, ground = 0, map = 0, names = 0 }
local drawnNow, drawnBefore = {}, {}  -- the pieces drawn this time and the time before
local pool = {}                       -- textures given back, for the next piece
local owned = {}                      -- pieces holding a texture
local labels                          -- the names on the globe (made at the first drawing)
local hover                           -- the zone under the pointer: { c = its continent, zone = it }
local lineTex, linesUsed = {}, 0      -- the pictures an outline is drawn with, and how many are in use

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

-- The same for a point of a piece, worked out once a drawing (pieces share their corners).
local frame = 0                       -- each drawing's number
-- A drawing begins: the eye's basis from where the globe is turned to.
local function Look()
	drawingAt = GetTime()
	b1, b2, b3, b4, b5, b6, b7, b8, b9 = Basis(look.lat, look.lon)
	basis = { b1, b2, b3, b4, b5, b6, b7, b8, b9 }
end
local function Corner(p, r)
	if p[4] == frame then return p[5], p[6], p[7] end
	local px, py, pz = p[1], p[2], p[3]
	local z = px * b1 + py * b2 + pz * b3
	local k = EYE / (EYE - z) * r
	local x, y = (px * b4 + py * b5 + pz * b6) * k, (px * b7 + py * b8 + pz * b9) * k
	p[4], p[5], p[6], p[7] = frame, x, y, z
	return x, y, z
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

-- The pointer, in points from the middle of the globe (which is `lift` above the picture's).
local function Pointer()
	local cx, cy = view:GetCenter()
	if not cx then return 0, 0 end
	local x, y = GetCursorPosition()
	local s = view:GetEffectiveScale()
	return x / s - cx, y / s - cy - lift
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

-- How far the globe is lifted above the middle of the picture at radius r: all the way with the
-- whole ring in view, not at all once the ball fills the picture.
local function Lift(r)
	if LIFT == 0 then return 0 end
	return LIFT * (1 - Smooth(RMIN * 1.15, LIFT_GONE, r))
end

---------------------------------------------------------------------------
-- Zones
---------------------------------------------------------------------------
-- A direction on the sphere as a continent's column and row (OnGlobe, the other way round).
local function FromGlobe(c, p)
	local b = c.basis
	local e, n = p[1] * b[4] + p[2] * b[5] + p[3] * b[6], p[1] * b[7] + p[2] * b[8] + p[3] * b[9]
	local h = sqrt(e * e + n * n)
	if h < 1e-9 then return c.cx, c.cy end
	local d = acos(max(-1, min(1, Dot(p, b)))) * RW / TILE / h
	return c.cx + e * d, c.cy - n * d
end

-- What a row of chunks says at a column: rows are kept as text ('count,value,count,value,...') until
-- first asked about.
local function RunAt(rows, row, column)
	local runs = rows[row]
	if not runs or column < 0 then return nil end
	if type(runs) == 'string' then
		local read = {}
		for count, value in runs:gmatch('(%d+),(%d+)') do
			read[#read + 1] = tonumber(count)
			read[#read + 1] = tonumber(value)
		end
		rows[row] = read
		runs = read
	end
	local upTo = 0
	for i = 1, #runs, 2 do
		upTo = upTo + runs[i]
		if column < upTo then return runs[i + 1] end
	end
	return nil
end

-- The zone at a point of the sphere, its continent, and the smaller place there (the game's area: a
-- town, a camp, a pass) where the chunk is of one. Nil on the open sea and on land of no zone.
local function ZoneAt(p)
	for map, data in pairs(ZONES) do
		local c = continents[map]
		if c and Dot(p, c.basis) > 0 then
			local gx, gy = FromGlobe(c, p)
			local column, row = floor(gx * 16), floor(gy * 16) - data.row0 + 1
			local zone = data.zones[RunAt(data.rows, row, column) or 0]
			if zone then
				local area = data.areas and RunAt(data.areas, row, column)
				return c, zone, area and area > 0 and area or nil
			end
		end
	end
end

-- A zone's outlines on the sphere (read from their text the first time), with its middle and how far
-- it reaches from there (radians).
local function Outline(c, zone)
	if zone.lines then return zone.lines end
	local per = ZONES[c.map].per
	local lines = {}
	local x0, x1, y0, y1
	for _, text in ipairs(zone.rings) do
		local ring, x = {}, nil
		for number in text:gmatch('%d+') do
			local n = tonumber(number) / per
			if x then
				ring[#ring + 1] = { OnGlobe(c, x, n) }
				x0, x1, y0, y1 = min(x0 or x, x), max(x1 or x, x), min(y0 or n, n), max(y1 or n, n)
				x = nil
			else
				x = n
			end
		end
		lines[#lines + 1] = ring
	end
	zone.mid = { OnGlobe(c, ((x0 or c.cx) + (x1 or c.cx)) / 2, ((y0 or c.cy) + (y1 or c.cy)) / 2) }
	local reach = 0
	for _, ring in ipairs(lines) do
		for _, p in ipairs(ring) do reach = max(reach, acos(max(-1, min(1, Dot(zone.mid, p))))) end
	end
	zone.reach, zone.lines = reach, lines
	return lines
end

-- A zone's name: the game's own for its area, else the one written with the outlines (English).
local function ZoneName(zone)
	if not zone.shown then
		local ok, name = pcall(C_Map.GetAreaInfo, zone.id)
		zone.shown = ok and type(name) == 'string' and name ~= '' and name or zone.name
	end
	return zone.shown
end

-- The globe's radius (points) at which something reaching this far (radians) from the middle of the
-- picture fits in it.
local function FitRadius(reach)
	local t = max(0.004, min(1.2, reach))
	return max(RMIN, min(RMAX, FIT * min(viewW, viewH) / 2 * (EYE - cos(t)) / (EYE * sin(t))))
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local half = VIEW / 2                 -- (a piece's corners are moved from those of a square this far from the globe's middle)
-- the picture's edges, in points from the globe's middle (which is `lift` above the picture's)
local xMost, yLow, yHigh = VIEW / 2, -VIEW / 2, VIEW / 2
local function Out(x1, x2, x3, x4, y1, y2, y3, y4)
	return max(x1, x2, x3, x4) < -xMost or min(x1, x2, x3, x4) > xMost
		or max(y1, y2, y3, y4) < yLow or min(y1, y2, y3, y4) > yHigh
end

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
	t:SetDrawLayer('ARTWORK', SUBLEVEL[layer])
	return t
end

local function Give(p)
	p.tex:Hide()
	pool[#pool + 1] = p.tex
	p.tex, p.shown, p.colourKey, p.tinted = nil, false, nil, nil
	owned[p] = nil
end

local function Show(p, x1, y1, x2, y2, x3, y3, x4, y4, lit, alpha)
	local t = p.tex
	if not t then
		t = Acquire(p.pic.layer)
		p.tex = t
		owned[p] = true
		local c, pic = p.pic.coords, p.pic
		if pic.wrap then t:SetTexture(pic.fdid, pic.wrap, pic.wrap) else t:SetTexture(pic.fdid) end
		local du, dv = c[2] - c[1], c[4] - c[3]
		t:SetTexCoord(c[1] + du * p.fu0, c[1] + du * p.fu1, c[3] + dv * p.fv0, c[3] + dv * p.fv1)
		if pic.Moved then pic.Moved(p, t) end      -- (a picture that turns or slides in its place: Effects.lua)
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
	local tint = p.pic.tint
	if key ~= p.colourKey or tint ~= p.tinted then
		p.colourKey, p.tinted = key, tint
		local lr, lg, lb = lit, lit, lit
		if tint then lr, lg, lb = lit * tint[1], lit * tint[2], lit * tint[3] end
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
			t:SetGradient(f[1], Colour(1, lr, lg, lb, alpha * f[2]), Colour(2, lr, lg, lb, alpha * f[3]))
		else
			t:SetVertexColor(lr, lg, lb, alpha * (f and f[2] or 1))
		end
	end
	if not p.shown then
		t:Show()
		p.shown = true
	end
	p.seen = drawingAt
	p.frame = frame
	drawnNow[#drawnNow + 1] = p
end

-- One piece: dropped when it is wholly behind or out of the window, split while it is too large to
-- lie flat or crosses the globe's edge, else drawn.
-- A corner behind the globe's edge, slid along the sphere onto the edge (where it is seen last).
local EDGE_OUT = sqrt(1 - SEEN * SEEN)
local function OnEdge(p, r)
	local px, py, pz = p[1], p[2], p[3]
	local z = px * b1 + py * b2 + pz * b3
	local tx, ty, tz = px - z * b1, py - z * b2, pz - z * b3
	local tl = sqrt(tx * tx + ty * ty + tz * tz)
	if tl < 1e-9 then return Seen(p, r) end
	-- (the point of the edge that way: as deep as the edge is, SEEN)
	local s = EDGE_OUT / tl
	local qx, qy, qz = SEEN * b1 + tx * s, SEEN * b2 + ty * s, SEEN * b3 + tz * s
	local k = EYE / (EYE - SEEN) * r
	return (qx * b4 + qy * b5 + qz * b6) * k, (qx * b7 + qy * b8 + qz * b9) * k
end

-- How far from where its middle is seen a piece's corner can be seen at most, for each radius of the
-- globe its corners lie from its middle (straight): nearer the eye things are seen larger, hence more.
local REACH = FRONT + EYE / ((EYE - 1) * (EYE - 1))
-- Can any of a piece be in the picture? No when it is wholly behind the globe, or wholly in front and
-- its middle is seen further out of the picture than its corners reach in (far cheaper than its corners).
local function InView(p, r, slack)
	local m = p.mid
	local zm = m[1] * b1 + m[2] * b2 + m[3] * b3
	if zm < p.hideBelow then return false end
	local chord = p.chord * (slack or 1)
	if zm - chord > SEEN then
		local mx, my = Corner(m, r)
		local far = chord * r * REACH
		if mx - far > xMost or mx + far < -xMost or my - far > yHigh or my + far < yLow then return false end
	end
	return true
end

-- One piece: dropped when it is wholly behind or out of the window, split while it is too large to lie
-- flat, else drawn. One across the globe's edge with its middle in front is drawn with its corners
-- behind the edge slid onto it (once it is small enough), so it neither folds over nor leaves a gap.
local function Visit(p, r, alpha, shade)
	local cut = p.cut
	if cut == 0 then return end
	local m = p.mid
	local zm = m[1] * b1 + m[2] * b2 + m[3] * b3
	if zm < p.hideBelow then return end
	-- (wholly in front, and its middle further out of the picture than its corners reach in: not in it)
	local mx, my
	local chord = p.chord
	if zm - chord > SEEN then
		mx, my = Corner(m, r)
		local far = chord * r * REACH
		if mx - far > xMost or mx + far < -xMost or my - far > yHigh or my + far < yLow then return end
	end
	local x1, y1, z1 = Corner(p.ul, r)
	local x2, y2, z2 = Corner(p.ll, r)
	local x3, y3, z3 = Corner(p.ur, r)
	local x4, y4, z4 = Corner(p.lr, r)
	local front = z1 > SEEN and z2 > SEEN and z3 > SEEN and z4 > SEEN and zm > SEEN
	if Out(x1, x2, x3, x4, y1, y2, y3, y4) and (front or zm < SEEN) then return end
	local deep = p.deep
	if not front then
		-- (across the edge: split while large, then drawn with its corners on the edge; dropped if its
		-- middle is behind and it can be split no more)
		local size = max(max(x1, x2, x3, x4) - min(x1, x2, x3, x4), max(y1, y2, y3, y4) - min(y1, y2, y3, y4))
		if not deep and (zm <= SEEN or size > EDGE_PIECE * 8) then
			local kids = p.kids or Halves(p)
			Visit(kids[1], r, alpha, shade); Visit(kids[2], r, alpha, shade); Visit(kids[3], r, alpha, shade); Visit(kids[4], r, alpha, shade)
			return
		end
		if zm <= SEEN then return end
		if z1 <= SEEN then x1, y1 = OnEdge(p.ul, r) end
		if z2 <= SEEN then x2, y2 = OnEdge(p.ll, r) end
		if z3 <= SEEN then x3, y3 = OnEdge(p.ur, r) end
		if z4 <= SEEN then x4, y4 = OnEdge(p.lr, r) end
		if Out(x1, x2, x3, x4, y1, y2, y3, y4) then return end
		-- (slid corners can turn a sliver inside out: split it, or leave it out)
		if (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1) < 0 or (x4 - x3) * (y2 - y3) - (y4 - y3) * (x2 - x3) > 0 then
			if not deep then
				local kids = p.kids or Halves(p)
				Visit(kids[1], r, alpha, shade); Visit(kids[2], r, alpha, shade); Visit(kids[3], r, alpha, shade); Visit(kids[4], r, alpha, shade)
			end
			return
		end
	elseif not deep then
		-- (toward the globe's edge, where everything is squeezed, more is let pass)
		if not mx then mx, my = Corner(m, r) end
		local edge = 1 - zm
		if cut == 1 or abs(mx - (x1 + x2 + x3 + x4) / 4) + abs(my - (y1 + y2 + y3 + y4) / 4) > p.curve * (1 + 10 * edge * edge)
			or ((cut == 2 or p.pic.uneven) and max(max(x1, x2, x3, x4) - min(x1, x2, x3, x4),
				max(y1, y2, y3, y4) - min(y1, y2, y3, y4)) > FADE_PIECE) then
			local kids = p.kids or Halves(p)
			Visit(kids[1], r, alpha, shade); Visit(kids[2], r, alpha, shade); Visit(kids[3], r, alpha, shade); Visit(kids[4], r, alpha, shade)
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
		ns.GlobeText(fs, style.font, style.size, style.plain and 'plain' or nil)
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
		if a > 0.02 and abs(x) < xMost and y > yLow and y < yHigh then
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
	if not basis or (ns.FlatOn and ns.FlatOn()) then return end
	local c, me, wx, wy = MyPlace()
	if not me then return end
	local x, y, z = Seen(me, look.r)
	if z <= SEEN or abs(x) > xMost or y < yLow or y > yHigh then return end
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

-- One stretch of an outline, from x1, y1 to x2, y2: a picture of the line, its corners moved to the
-- stretch's two ends (a little past them, so the stretches join), LINE_WIDTH across.
local function Line(x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	local length = sqrt(dx * dx + dy * dy)
	if length < 0.01 then return end
	linesUsed = linesUsed + 1
	local t = lineTex[linesUsed]
	if not t then
		t = canvas:CreateTexture(nil, 'ARTWORK')
		if t.SetSnapToPixelGrid then
			t:SetSnapToPixelGrid(false)
			t:SetTexelSnappingBias(0)
		end
		t:SetPoint('TOPLEFT', canvas, 'TOPLEFT', 0, 0)
		t:SetSize(VIEW, VIEW)
		t:SetTexture(LINE)
		t:SetDrawLayer('ARTWORK', 7)               -- (over every map piece, under the names and the arrow)
		lineTex[linesUsed] = t
	end
	dx, dy = dx / length, dy / length
	x1, y1, x2, y2 = x1 - dx, y1 - dy, x2 + dx, y2 + dy
	local nx, ny = -dy * LINE_WIDTH / 2, dx * LINE_WIDTH / 2
	t:SetVertexOffset(1, x1 + nx + half, y1 + ny - half)
	t:SetVertexOffset(2, x1 - nx + half, y1 - ny + half)
	t:SetVertexOffset(3, x2 + nx - half, y2 + ny - half)
	t:SetVertexOffset(4, x2 - nx - half, y2 - ny + half)
	t.x1, t.y1, t.x2, t.y2 = x1, y1, x2, y2
	t:Show()
end

-- The zone under the pointer: its outline, drawn point to point where it faces you and is in the
-- picture (points too near the last one on the screen passed over), and its name at the top.
local function PaintZone(r)
	local before = linesUsed
	linesUsed = 0
	if hover then
		for _, ring in ipairs(Outline(hover.c, hover.zone)) do
			local n = #ring
			local px, py
			for i = 1, n + 1 do
				local x, y, z = Seen(ring[(i - 1) % n + 1], r)
				if z <= SEEN + 0.01 then
					px = nil                            -- (behind the globe's edge: the line breaks off)
				elseif not px then
					px, py = x, y
				elseif i > n or abs(x - px) + abs(y - py) >= LINE_STEP then
					if not ((px < -xMost and x < -xMost) or (px > xMost and x > xMost)
						or (py < yLow and y < yLow) or (py > yHigh and y > yHigh)) then
						Line(px, py, x, y)
					end
					px, py = x, y
				end
			end
		end
		-- (Places.lua adds the zone's levels to its name, and names the smaller place under it)
		zoneText:SetText(ns.ZoneWords and ns.ZoneWords(hover, ZoneName(hover.zone)) or ZoneName(hover.zone))
		zoneText:Show()
	else
		zoneText:Hide()
	end
	for i = linesUsed + 1, before do lineTex[i]:Hide() end
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
	Look()
	local r = look.r
	local style = ns.Get('globeStyle') == 'minimap' and 'minimap' or 'parchment'
	local shade = ns.Get('globeLight')
	local sea = SEAS[style]
	if ns.FlatOn and ns.FlatOn() then
		-- (a flat map is up: nothing of the globe is drawn; the marks are laid on the flat map)
		for i = #drawnNow, 1, -1 do
			local p = drawnNow[i]
			if p.shown then
				p.tex:Hide()
				p.shown = false
			end
			drawnNow[i] = nil
		end
		ocean:Hide()
		halo:Hide()
		if ring then ring:Hide() end
		for _, label in ipairs(labels or {}) do
			label.fs:Hide()
			label.shown = false
		end
		for i = 1, linesUsed do lineTex[i]:Hide() end
		linesUsed = 0
		zoneText:Hide()
		if lift ~= 0 then
			lift = 0
			canvas:SetPoint('CENTER', view, 'CENTER', 0, 0)
		end
		xMost, yLow, yHigh = viewW / 2, -viewH / 2, viewH / 2
		Fire('paint', ns.FlatOn())
		PaintMe()
		last.drawn, last.map, last.ms, last.names = 0, 0, debugprofilestop() - started, 0
		Stats()
		return
	end
	ocean:Show()
	halo:Show()
	ocean:SetColorTexture(sea.sea[1], sea.sea[2], sea.sea[3], 1)
	halo:SetColorTexture(sea.rim[1], sea.rim[2], sea.rim[3], sea.rim[4])
	ocean:SetSize(2 * r * LIMB, 2 * r * LIMB)
	halo:SetSize(2 * r * LIMB * 1.05, 2 * r * LIMB * 1.05)
	local up = Lift(r)
	if up ~= lift then
		lift = up
		canvas:SetPoint('CENTER', view, 'CENTER', 0, lift)
	end
	xMost, yLow, yHigh = viewW / 2, -viewH / 2 - lift, viewH / 2 - lift
	if ring then
		-- (the ring's hole round the ball; gone once the hole is wider than the picture)
		local side = RING_GAP * LIMB * r / RING.inner
		if RING.inner * side < max(viewW, viewH) * 0.75 then
			ring:SetSize(side, side)
			ring:SetPoint('CENTER', canvas, 'CENTER', (0.5 - RING.cx) * side, (RING.cy - 0.5) * side)
			ring:Show()
		else
			ring:Hide()
		end
	end
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
		for _, pic in ipairs(pictures.decor) do
			pic.root = pic.root or Piece(pic, 0, 1, 0, 1, 0)
			Visit(pic.root, r, 1, shade)
		end
	end
	-- the ground: zoomed in, only the tiles round the middle of the picture are looked at (found by
	-- their place); further out, all of them
	local asked = 0
	local near = (sqrt(viewW * viewW + viewH * viewH) / 2 + abs(lift)) / (EYE / (EYE - 1) * r) * RW / TILE * 1.15 + 1    -- tiles, from the middle
	for _, c in pairs(continents) do
		-- (a continent with no world map of its own shows its ground at every zoom)
		local alpha = (c.hasArt or pictures.world) and ground or 1
		if alpha > 0.005 and c.ground then
			if near < NEAR_MOST then
				if Dot(basis, c.basis) > 0 then
					local gx, gy = FromGlobe(c, basis)
					for ty = max(0, floor(gy - near)), floor(gy + near) do
						for tx = max(0, floor(gx - near)), min(63, floor(gx + near)) do
							local pic = c.ground[ty * 64 + tx]
							if pic then
								asked = asked + 1
								pic.root = pic.root or Piece(pic, 0, 1, 0, 1, 0)
								Visit(pic.root, r, alpha, shade)
							end
						end
					end
				end
			else
				for _, pic in pairs(c.ground) do
					asked = asked + 1
					pic.root = pic.root or Piece(pic, 0, 1, 0, 1, 0)
					Visit(pic.root, r, alpha, shade)
				end
			end
		end
	end
	last.asked = asked
	Fire('pictures', r, shade, style)
	for _, p in ipairs(drawnBefore) do
		if p.frame ~= frame and p.shown then
			p.tex:Hide()
			p.shown = false
		end
	end
	local named = debugprofilestop()
	PaintLabels(r)
	PaintZone(r)
	Fire('paint', r)
	PaintMe()
	local map = 0
	for _, p in ipairs(drawnNow) do
		if p.pic.layer ~= 'ground' then map = map + 1 end
	end
	last.drawn, last.map, last.ms, last.names = #drawnNow, map, debugprofilestop() - started, debugprofilestop() - named
	last.ground = style == 'parchment' and ground or 1
	Stats()
end

-- Pieces unseen for a while give their textures back; and now and then the pieces cut from one that
-- hold no texture any more are forgotten (a long look round the world would else keep them all).
local others = {}                     -- the pictures laid on the globe by the files after this one (G.Draw)
local function Thin(p)
	local holds, kids = p.tex ~= nil, p.kids
	if kids then
		local any = false
		for i = 1, 4 do
			if Thin(kids[i]) then any = true end
		end
		if any then holds = true else p.kids = nil end
	end
	return holds
end
local tidies = 0
local function Tidy()
	local now = GetTime()
	for p in pairs(owned) do
		if not p.shown and now - (p.seen or 0) > RELEASE then Give(p) end
	end
	tidies = tidies + 1
	if tidies % 6 == 0 then
		for _, list in pairs(pictures) do
			if type(list) == 'table' then
				for _, pic in ipairs(list) do
					if pic.root then Thin(pic.root) end
				end
			end
		end
		for pic in pairs(others) do
			if pic.root then Thin(pic.root) end
		end
	end
end

local function Changed() dirty = true end

-- Turn and zoom the globe, eased, until the point p is in the middle at radius r: the short way round.
local function GlideTo(p, r)
	if ns.FlatLeave then ns.FlatLeave() end        -- (a flat map that is up gives way: the globe is being turned)
	local lat = max(-1.45, min(1.45, asin(max(-1, min(1, p[3])))))
	local lon = atan2(p[2], p[1])
	local dlon = (lon - look.lon + math.pi) % (2 * math.pi) - math.pi
	glide, coast = { t = 0, lat = look.lat, dlat = lat - look.lat, lon = look.lon, dlon = dlon,
		lr = log(look.r), dlr = log(r) - log(look.r) }, nil
	aim.p = nil
	Changed()
end

-- A click on a zone turns and zooms the globe to fit it: when that zooms in, or when it is another
-- zone than the one in the middle of the picture (but not from far closer in than a zone: there a
-- click may be the first of a double-click, and is left alone).
local function Click(x, y)
	local p = Under(x, y)
	if not p then return end
	local c, zone = ZoneAt(p)
	if not zone then return end
	Outline(c, zone)
	local r = FitRadius(zone.reach)
	local _, middle = ZoneAt({ basis[1], basis[2], basis[3] })
	if r > look.r * 1.15 or (zone ~= middle and look.r < r * 3) then GlideTo(zone.mid, r) end
end

-- A right-click steps back out: to the whole of the continent nearest the middle of the picture, and
-- from there to the whole globe.
local function StepOut()
	if not basis then return end
	local best, nearest
	for map, data in pairs(ZONES) do
		local c = continents[map]
		if c then
			local mid = { OnGlobe(c, data.middle[1], data.middle[2]) }
			local d = Dot(mid, basis)
			if not nearest or d > nearest then
				best, nearest = { mid = mid, r = FitRadius(data.reach * TILE / RW) }, d
			end
		end
	end
	if best and look.r > best.r * 1.15 then
		GlideTo(best.mid, best.r)
	else
		GlideTo({ basis[1], basis[2], basis[3] }, RMIN)
	end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- The mouse, and each frame
---------------------------------------------------------------------------
-- turning: the point under the pointer follows it, and carries on a little after; zooming: the
-- wheel, eased, toward the pointer; a double-click zooms in on a spot; a click on a zone fits it
-- in the picture, a right-click steps back out
local drag, lastDown
local function MouseDown(_, button)
	byKeys = false
	if button ~= 'LeftButton' then return end
	local x, y = Pointer()
	local now = GetTime()
	local second = false
	if ns.FlatOn and ns.FlatOn() then
		-- (a flat map does not turn: a press on it is only ever a click)
		drag = { x = x, y = y, vlat = 0, vlon = 0, moved = 0, t = now, second = false, flat = true }
		return
	end
	if lastDown and now - lastDown.t < 0.35 and abs(x - lastDown.x) + abs(y - lastDown.y) < 6 then
		local p = Under(x, y)
		if p then aim.r, aim.p, aim.x, aim.y = min(RMAX, look.r * 2), p, x, y + lift end
		lastDown, second = nil, true
	else
		lastDown = { t = now, x = x, y = y }
	end
	drag = { x = x, y = y, vlat = 0, vlon = 0, moved = 0, t = now, second = second }
	glide, coast = nil, nil
end

local function MouseUp(_, button)
	if button == 'RightButton' then
		local x, y = Pointer()
		if not Fire('press', 'RightButton', x, y) then StepOut() end
		return
	end
	if not drag then return end
	if abs(drag.vlat) + abs(drag.vlon) > 0.02 then
		coast = { lat = drag.vlat, lon = drag.vlon }
	elseif not drag.second and drag.moved < CLICK and GetTime() - drag.t < 0.4 then
		-- (a press let go where it was made)
		if not Fire('press', 'LeftButton', drag.x, drag.y) then Click(drag.x, drag.y) end
	end
	drag = nil
end

local function MouseWheel(_, delta)
	glide, coast = nil, nil
	byKeys = false
	if ns.FlatOn and ns.FlatOn() then
		-- (the wheel turned back steps out of a flat map, as a right-click does)
		if delta < 0 then Fire('press', 'RightButton', 0, 0) end
		return
	end
	local x, y = Pointer()
	aim.r = max(RMIN, min(RMAX, aim.r * (delta > 0 and 1.3 or 1 / 1.3)))
	aim.p, aim.x, aim.y = Under(x, y), x, y + lift
	Changed()
end

local since, tidied = 0, 0
local function Update(_, elapsed)
	elapsed = min(elapsed, 0.1)
	local flat = ns.FlatOn and ns.FlatOn()
	if drag and drag.flat then
		local x, y = Pointer()
		drag.moved = drag.moved + abs(x - drag.x) + abs(y - drag.y)
		drag.x, drag.y = x, y
	elseif drag then
		local x, y = Pointer()
		local dx, dy = x - drag.x, y - drag.y
		local lat0, lon0 = look.lat, look.lon
		if dx ~= 0 or dy ~= 0 then
			drag.x, drag.y, drag.moved = x, y, drag.moved + abs(dx) + abs(dy)
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
	local tx, ty, tz = max(-1, min(1, held.x + pad.x)), max(-1, min(1, held.y + pad.y)), max(-1, min(1, held.z + pad.z))
	if flat then
		-- (zooming out with a key or a stick steps out of the flat map)
		if tz < -0.5 then Fire('press', 'RightButton', 0, 0, true) end
		tx, ty, tz = 0, 0, 0
	end
	if tx ~= 0 or ty ~= 0 then
		glide, coast = nil, nil
		Turn(-tx * KEY_TURN * elapsed, -ty * KEY_TURN * elapsed)
		Changed()
	end
	if tz ~= 0 then
		glide = nil
		aim.r, aim.p = max(RMIN, min(RMAX, aim.r * exp(tz * KEY_ZOOM * elapsed))), nil
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
		if aim.p then Hold(aim.p, aim.x, aim.y - Lift(look.r)) end
		Changed()
	elseif aim.p then
		aim.p = nil
	end
	-- the zone under the pointer (left as it is while the globe is turned by hand)
	if cross:IsShown() ~= byKeys then cross:SetShown(byKeys) end
	if not drag then
		local c, zone, area
		if basis and not flat and (byKeys or view:IsMouseOver()) then
			local p
			if byKeys then p = Under(0, -lift) else p = Under(Pointer()) end
			if p then c, zone, area = ZoneAt(p) end
		end
		if zone ~= (hover and hover.zone) or area ~= (hover and hover.area) then
			hover = zone and { c = c, zone = zone, area = area } or nil
			Changed()
		end
	end
	Fire('frame', elapsed)
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
end

-- What is remembered of the window (in the tool's saved variable): w, h (its size), x, y (its top left,
-- from the screen's bottom left), full (it fills the screen).
local function Saved()
	local db = rawget(_G, ADDON .. 'DB')
	if type(db) ~= 'table' then return {} end
	if type(db.window) ~= 'table' then db.window = {} end
	return db.window
end

-- The picture takes the window's size, less its edges; the smallest globe follows it. A globe that was
-- zoomed right out stays so; else the zoom is kept, and more or less of the world is seen.
local function Layout()
	local w, h = window:GetWidth(), window:GetHeight()
	local vw, vh = max(VIEW_LEAST, w - EDGES_W - side), max(VIEW_LEAST, h - EDGES_H)
	if vw == viewW and vh == viewH then return end
	local out = look.r <= RMIN * 1.02
	view:SetSize(vw, vh)
	Sized(vw, vh)
	if out or look.r < RMIN then look.r = RMIN end
	aim.r = out and RMIN or max(RMIN, aim.r)
	Changed()
end

-- Put the window where it was left: filling the screen, or at its own size and place.
local function Place()
	local saved = Saved()
	local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
	window:ClearAllPoints()
	if saved.full then
		window:SetFrameStrata('FULLSCREEN')
		window:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', 0, 0)
		window:SetSize(sw, sh)
	else
		window:SetFrameStrata('HIGH')
		local w = max(VIEW_LEAST + EDGES_W + side, min(sw, tonumber(saved.w) or VIEW + EDGES_W))
		local h = max(VIEW_LEAST + EDGES_H, min(sh, tonumber(saved.h) or VIEW + EDGES_H))
		window:SetSize(w, h)
		if tonumber(saved.x) and tonumber(saved.y) then
			window:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', saved.x, saved.y)
		else
			window:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
		end
	end
	grip:SetShown(not saved.full)
	fullButton:SetText(saved.full and 'Window' or 'Full Screen')
	Layout()
	Fire('place')
end

local function Full(on)
	local saved = Saved()
	if on == nil then on = not saved.full end
	saved.full = on and true or nil
	Place()
end

-- A menu at the pointer, made with the game's own menus. build(root) adds the entries.
local toldNoMenu
local function Menu(owner, build)
	local util = rawget(_G, 'MenuUtil')
	if not (type(util) == 'table' and type(util.CreateContextMenu) == 'function') then
		if not toldNoMenu then
			toldNoMenu = true
			ns.Print('This game client has no menus an addon can use, so there is no list here.')
		end
		return false
	end
	util.CreateContextMenu(owner, function(_, root) build(root) end)
	return true
end

-- Go To: the whole globe, where you are, and each continent with its zones, by name.
local function GoTo(owner)
	Menu(owner, function(root)
		root:CreateTitle('Go To')
		root:CreateButton('The Whole Globe', function() GlideTo({ basis[1], basis[2], basis[3] }, RMIN) end)
		root:CreateButton('Where I Am', function() ns.CenterOnMe() end)
		local lands = {}
		for map, data in pairs(ZONES) do
			local c = continents[map]
			if c then lands[#lands + 1] = { c = c, data = data, name = c.name or ('Map ' .. map) } end
		end
		table.sort(lands, function(a, b) return a.name < b.name end)
		for _, land in ipairs(lands) do
			local c, data = land.c, land.data
			local sub = root:CreateButton(land.name)
			if sub.SetScrollMode then sub:SetScrollMode(420) end
			sub:CreateButton('All Of ' .. land.name, function()
				GlideTo({ OnGlobe(c, data.middle[1], data.middle[2]) }, FitRadius(data.reach * TILE / RW))
			end)
			local zones = {}
			for _, zone in ipairs(data.zones) do zones[#zones + 1] = { zone = zone, name = ZoneName(zone) } end
			table.sort(zones, function(a, b) return a.name < b.name end)
			for _, z in ipairs(zones) do
				sub:CreateButton(z.name, function()
					Outline(c, z.zone)
					GlideTo(z.zone.mid, FitRadius(z.zone.reach))
				end)
			end
		end
		if ns.FlatMenu then ns.FlatMenu(root) end      -- (the cities' and battlegrounds' own maps: Flat.lua)
		if ns.MapMenu then ns.MapMenu(root) end        -- (the game's own world map: MapKey.lua)
	end)
end

-- Keys and the gamepad. Held: 'left', 'right', 'up', 'down' (the view moves that way), 'in', 'out'
-- (zooming). Pressed: 'fit' (the zone at the middle of the picture, or closer in where there is none),
-- 'back' (step out), 'me', 'full', 'goto'. down: the key went down (nil for one that is only pressed).
local HELD = { left = { 'x', -1 }, right = { 'x', 1 }, up = { 'y', 1 }, down = { 'y', -1 }, ['in'] = { 'z', 1 }, out = { 'z', -1 } }
function ns.GlobeKey(what, down)
	local axis = HELD[what]
	if axis then
		if not (window and window:IsShown()) then
			held[axis[1]] = 0
			return
		end
		-- (letting go of one of a pair stops it only if it is the one that is turning)
		if down ~= false then
			held[axis[1]] = axis[2]
		elseif held[axis[1]] == axis[2] then
			held[axis[1]] = 0
		end
		byKeys = true
		Changed()
		return
	end
	if down == false then return end
	if what == 'me' then
		ns.Toggle(true)
		ns.CenterOnMe()
		return
	end
	if not (window and window:IsShown()) then return end
	byKeys = true
	if what == 'fit' then
		if Fire('press', 'LeftButton', 0, -lift, true) then
			Changed()
			return
		end
		local p = Under(0, -lift)
		local _, zone
		if p then _, zone = ZoneAt(p) end
		local r0 = aim.r
		if zone then Click(0, -lift) end
		if not glide and aim.r == r0 then          -- (no zone there, or it is fitted already: closer in)
			coast = nil
			aim.r, aim.p = min(RMAX, aim.r * 1.6), nil
		end
	elseif what == 'back' then
		if not (ns.FlatOn and ns.FlatOn() and Fire('press', 'RightButton', 0, 0, true)) then StepOut() end
	elseif what == 'full' then
		Full()
	elseif what == 'goto' then
		GoTo(view)
	else
		Fire('key', what)
	end
	Changed()
end

-- A gamepad's sticks (Pad.lua): the view's way east and north, and the zoom, each -1 to 1.
function ns.GlobePad(x, y, z)
	pad.x, pad.y, pad.z = x or pad.x, y or pad.y, z or pad.z
	if window and window:IsShown() and (pad.x ~= 0 or pad.y ~= 0 or pad.z ~= 0) then
		byKeys = true
		Changed()
	end
end

function ns.GlobeFull(on) if window then Full(on) end end

-- The smallest the window can be sized to: the smallest picture, and the panel beside it.
local function Bounds()
	if window.SetResizeBounds then
		window:SetResizeBounds(VIEW_LEAST + EDGES_W + side, VIEW_LEAST + EDGES_H)
	elseif window.SetMinResize then
		window:SetMinResize(VIEW_LEAST + EDGES_W + side, VIEW_LEAST + EDGES_H)
	end
end

-- Room at the window's right for a panel beside the picture (QuestLog.lua): w points, or none. The
-- picture is that much narrower; a window too narrow for both is widened while the panel shows.
function ns.GlobeSide(w)
	w = max(0, tonumber(w) or 0)
	if w == side then return end
	side = w
	if window then
		Bounds()
		Place()
	end
end
function ns.GlobeSideWidth() return side end
function ns.GlobeWindow() return window, view end

local function Build()
	if window then return true end
	if not CanBend() then
		ns.Print('This game client cannot bend pictures (no Texture:SetVertexOffset), so there is no globe to draw.')
		return false
	end
	Prepare()
	window = CreateFrame('Frame', 'PatchwerkForever_Thread_GlobeWindow', UIParent)
	window:SetSize(VIEW + EDGES_W, VIEW + EDGES_H)
	window:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
	window:SetFrameStrata('HIGH')
	window:SetMovable(true)
	window:SetResizable(true)
	Bounds()
	window:SetClampedToScreen(true)
	window:EnableMouse(true)
	window:RegisterForDrag('LeftButton')
	-- (moved by its title, sized by its corner; not while it fills the screen. Where it is left is kept.)
	local function Keep()
		window:StopMovingOrSizing()
		local saved = Saved()
		if saved.full then return end
		saved.w, saved.h = window:GetWidth(), window:GetHeight()
		saved.x, saved.y = window:GetLeft(), window:GetTop()
	end
	window:SetScript('OnDragStart', function() if not Saved().full then window:StartMoving() end end)
	window:SetScript('OnDragStop', Keep)
	window:SetScript('OnSizeChanged', function() if view then Layout() end end)
	local back = window:CreateTexture(nil, 'BACKGROUND')
	back:SetAllPoints(window)
	back:SetColorTexture(0.02, 0.02, 0.04, 0.92)
	local title = window:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	title:SetPoint('TOP', window, 'TOP', 0, -9)
	title:SetText('Globe')
	local close = CreateFrame('Button', nil, window, 'UIPanelCloseButton')
	close:SetPoint('TOPRIGHT', window, 'TOPRIGHT', 0, 0)
	tinsert(UISpecialFrames, window:GetName())
	fullButton = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
	fullButton:SetSize(96, 22)
	fullButton:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -30, -4)
	fullButton:SetText('Full Screen')
	fullButton:SetScript('OnClick', function() Full() end)
	local go = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
	go:SetSize(64, 22)                -- (Route and Show stand beside it: Quests.lua, Show.lua)
	go:SetPoint('TOPLEFT', window, 'TOPLEFT', 8, -4)
	go:SetText('Go To')
	go:SetScript('OnClick', function(self) GoTo(self) end)
	grip = CreateFrame('Button', nil, window)
	grip:SetSize(16, 16)
	grip:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -2, 2)
	grip:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
	grip:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
	grip:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')
	grip:SetScript('OnMouseDown', function() window:StartSizing('BOTTOMRIGHT') end)
	grip:SetScript('OnMouseUp', Keep)

	view = CreateFrame('Frame', nil, window)
	view:SetSize(viewW, viewH)
	view:SetPoint('TOPLEFT', window, 'TOPLEFT', EDGES_W / 2, -30)     -- (a panel beside it takes the right: ns.GlobeSide)
	view:SetClipsChildren(true)
	view:EnableMouse(true)
	view:EnableMouseWheel(true)
	-- (everything of the globe is laid on the canvas, which is moved up and down in the picture: Lift)
	canvas = CreateFrame('Frame', nil, view)
	canvas:SetSize(VIEW, VIEW)
	canvas:SetPoint('CENTER', view, 'CENTER', 0, 0)

	halo = canvas:CreateTexture(nil, 'BACKGROUND', nil, 0)
	halo:SetPoint('CENTER', canvas, 'CENTER', 0, 0)
	Round(halo)
	ocean = canvas:CreateTexture(nil, 'BACKGROUND', nil, 1)
	ocean:SetPoint('CENTER', canvas, 'CENTER', 0, 0)
	Round(ocean)
	if RING then
		ring = canvas:CreateTexture(nil, 'BACKGROUND', nil, 2)
		ring:SetTexture(RING.file)
		ring:Hide()
	end
	dot = canvas:CreateTexture(nil, 'OVERLAY')
	dot:SetSize(10, 10)
	dot:SetColorTexture(1, 0.85, 0.2, 1)
	Round(dot)
	dot:Hide()
	arrow = canvas:CreateTexture(nil, 'OVERLAY', nil, 1)
	arrow:SetSize(28, 28)
	arrow:SetTexture('Interface\\Minimap\\MinimapArrow')
	arrow:Hide()

	zoneText = canvas:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	ns.GlobeText(zoneText, 'Fonts\\MORPHEUS.TTF', 20, nil, 18)
	zoneText:SetTextColor(1, 0.92, 0.72)
	zoneText:SetPoint('TOP', view, 'TOP', 0, -12)
	zoneText:Hide()

	-- the middle of the picture, marked while keys or a gamepad turn the globe (it is their pointer)
	cross = CreateFrame('Frame', nil, view)
	cross:SetSize(14, 14)
	cross:SetPoint('CENTER', view, 'CENTER', 0, 0)
	for _, size in ipairs({ { 14, 2 }, { 2, 14 } }) do
		local bar = cross:CreateTexture(nil, 'OVERLAY')
		bar:SetSize(size[1], size[2])
		bar:SetPoint('CENTER', cross, 'CENTER', 0, 0)
		bar:SetColorTexture(1, 0.92, 0.72, 0.9)
	end
	cross:Hide()

	local me = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
	me:SetSize(110, 22)
	me:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -24, 7)
	me:SetText('Where I Am')
	me:SetScript('OnClick', function() ns.CenterOnMe() end)
	statsText = window:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	statsText:SetPoint('BOTTOMLEFT', window, 'BOTTOMLEFT', 12, 12)
	statsText:SetPoint('RIGHT', me, 'LEFT', -8, 0)
	statsText:SetJustifyH('LEFT')
	statsText:SetWordWrap(false)

	view:SetScript('OnMouseDown', MouseDown)
	view:SetScript('OnMouseUp', MouseUp)
	view:SetScript('OnMouseWheel', MouseWheel)
	window:SetScript('OnUpdate', Update)
	window:SetScript('OnShow', function()
		Changed()
		Fire('show')
	end)
	window:SetScript('OnHide', function()
		held.x, held.y, held.z, pad.x, pad.y, pad.z, byKeys = 0, 0, 0, 0, 0, 0, false
		Fire('hide')
	end)
	Place()
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
	-- (in a city or a battleground, its own map: Flat.lua)
	if ns.FlatFollow and ns.FlatFollow(true) then
		Changed()
		return
	end
	local _, me = MyPlace()
	if not me then
		ns.Print('Your place is not on the globe here (inside a dungeon, or on a map the globe does not have).')
		return
	end
	-- glide there: the short way round, zooming in to see the land round you
	GlideTo(me, max(look.r, VIEW * 4))
end

-- The globe turned and zoomed to where you are at once, with no glide: before the window opens (the map
-- key, MapKey.lua). False where your place is not on the globe; the globe is then left as it was.
function ns.LookAtMe()
	if not Build() then return false end
	local _, me = MyPlace()
	if not me then return false end
	look.lat = max(-1.45, min(1.45, asin(max(-1, min(1, me[3])))))
	look.lon = atan2(me[2], me[1])
	look.r = max(look.r, VIEW * 4)
	aim.r, aim.p = look.r, nil
	glide, coast = nil, nil
	Changed()
	return true
end

function ns.SayStats()
	Prepare()
	local style = ns.Get('globeStyle') == 'minimap' and 'Minimap pictures' or 'Parchment'
	ns.Print(('%s: %d pieces drawn at the last drawing, in %.1f ms; %d textures made, %d spare; %d fps.')
		:format(style, last.drawn, last.ms, last.made, #pool, floor((GetFramerate() or 0) + 0.5)))
end

-- The globe, for the files after this one.
ns.G = {
	TILE = TILE, EDGE = EDGE, RW = RW, EYE = EYE, SEEN = SEEN, VIEW = VIEW, half = half,
	continents = continents,          -- by the game's map number, once the window is built
	look = look,                      -- lat, lon, r
	Seen = Seen,                      -- (p, r): x, y from the globe's middle (points), depth
	Under = function(x, y)            -- (x, y): the point of the sphere seen there, or nil (on a flat map: the place there)
		if ns.FlatOn and ns.FlatOn() then return ns.FlatUnder(x, y) end
		return Under(x, y)
	end,
	OnGlobe = OnGlobe,                -- (c, column, row): a direction
	WorldOnGlobe = WorldOnGlobe,      -- (c, world x, world y): { direction }
	FromGlobe = FromGlobe,            -- (c, p): column, row
	Pointer = Pointer,                -- the pointer, from the globe's middle
	Smooth = Smooth, Dot = Dot, Changed = Changed, GlideTo = GlideTo, FitRadius = FitRadius, Menu = Menu,
	ZoneAt = ZoneAt, ZoneName = ZoneName, MyPlace = MyPlace, PrepareArt = PrepareArt,
	Outline = Outline,                -- (c, zone): its outlines; the zone then has its middle (mid) and reach
	NameAt = function(text)           -- where a zone's name is written on the globe: a direction, or nil (no such name, or none made yet)
		for _, label in ipairs(labels or {}) do
			if label.kind == 'zone' and label.text == text then return label.at end
		end
	end,
	pictures = pictures,              -- the globe's own pictures, by layer
	-- lay one more picture on the globe at this drawing (from a 'pictures' hook): { fdid, layer ('cover',
	-- 'wash', 'sky'), coords, At, Fade, tint, wrap, Moved }
	Draw = function(pic, r, alpha, shade)
		if not pic.root then
			pic.root = Piece(pic, 0, 1, 0, 1, 0)
			others[pic] = true
		end
		Visit(pic.root, r, alpha, shade)
	end,
	-- can any of a picture be in the window at this drawing (from a 'pictures' hook: a quick look, before
	-- many small pictures that lie within it are each asked for); slack: its reach taken this much larger
	InView = function(pic, r, slack)
		if not pic.root then
			pic.root = Piece(pic, 0, 1, 0, 1, 0)
			others[pic] = true
		end
		return InView(pic.root, r, slack)
	end,
	-- a picture whose Fade, Cut or deepest has changed is cut afresh at the next drawing (not from within
	-- a drawing: its pieces would be gone from that one)
	Forget = function(pic)
		local function Drop(p)
			if p.tex then Give(p) end
			if p.kids then
				for i = 1, 4 do Drop(p.kids[i]) end
			end
		end
		if pic.root then
			Drop(pic.root)
			pic.root = nil
		end
	end,
	FADE_DEEPEST = FADE_DEEPEST,
	Least = function() return RMIN end,   -- the globe's radius with the whole of it in the picture
	Basis = function() return basis end,
	Lift = function() return lift end,
	Edges = function() return xMost, yLow, yHigh end,
	Frames = function() return window, view, canvas, cross end,
	ByKeys = function() return byKeys end,
	Turning = function() return drag ~= nil end,
	Whole = function()                -- the whole globe is in view
		return not glide and look.r <= RMIN * 1.02 and not (ns.FlatOn and ns.FlatOn())
	end,
	Hover = function() return hover end,  -- the zone pointed at: { c, zone, area }
	ZoneText = function() return zoneText end,
	Size = function() return viewW, viewH end,
	UiMap = function(map)             -- a continent's own world map (the game's number for it), or nil
		PrepareArt()
		local c = continents[map]
		return c and c.uiMap or nil
	end,
}

-- For the checks outside the game: where a place in the world (a continent's map number, world x, y)
-- is seen now, in points from the middle of the picture.
function ns.GlobeWhere(map, wx, wy)
	local c = continents[map]
	if c and basis then return Seen(WorldOnGlobe(c, wx, wy), look.r) end
end

-- For the checks outside the game: glide to a place of a continent (column, row, in tiles) at a zoom.
function ns.GlobeGo(map, gx, gy, r)
	local c = continents[map]
	if c then GlideTo({ OnGlobe(c, gx, gy) }, r) end
end

-- For the checks outside the game: what was drawn last, and where.
function ns.GlobeState()
	local out = { look = look, drawn = {}, labels = {}, rmin = RMIN, lift = lift, asked = last.asked, ms = last.ms,
		ground = last.ground, w = viewW, h = viewH, byKeys = byKeys, cross = cross and cross:IsShown() or false }
	if ring and ring:IsShown() then
		-- (the top and bottom of what the ring's picture draws, in points from the middle of the picture)
		local side = RING_GAP * LIMB * look.r / RING.inner
		out.ring = { top = lift + (RING.cy - RING.top) * side, bottom = lift - (RING.bottom - RING.cy) * side,
			hole = RING.inner * side }
	end
	for _, p in ipairs(drawnNow) do
		local r = look.r
		local x1, y1 = Seen(p.ul, r)
		local x2, y2 = Seen(p.ll, r)
		local x3, y3 = Seen(p.ur, r)
		local x4, y4 = Seen(p.lr, r)
		local f = p.fade
		out.drawn[#out.drawn + 1] = { fdid = p.pic.fdid, layer = p.pic.layer, depth = p.depth, tint = p.tinted,
			fu0 = p.fu0, fu1 = p.fu1, fv0 = p.fv0, fv1 = p.fv1, x = { x1, x2, x3, x4 }, y = { y1, y2, y3, y4 },
			-- (how much of it shows: one figure, or from one side to the other)
			fade = f and { f[1] or 'FLAT', f[2], f[3] or f[2] } or nil }
	end
	for _, label in ipairs(labels or {}) do
		local _, _, flags = label.fs:GetFont()
		out.labels[#out.labels + 1] = { text = label.text, kind = label.kind, shown = label.shown == true,
			x = label.x, y = label.y, flags = flags, shadow = label.fs.GetShadowOffset and label.fs:GetShadowOffset() or nil }
	end
	out.zone = hover and { id = hover.zone.id, name = ZoneName(hover.zone), reach = hover.zone.reach } or nil
	out.lines = {}
	for i = 1, linesUsed do
		local t = lineTex[i]
		out.lines[i] = { t.x1, t.y1, t.x2, t.y2 }
	end
	return out
end

ns.OnSetting(function(key)
	if key:find('^globe') then Changed() end
end)
