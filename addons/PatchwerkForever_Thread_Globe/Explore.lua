-- Globe (Thread): land you have not discovered lies under fog (the game's own map leaves it blank).
--
-- The game's map of a zone is drawn in pieces, one for each part of it you can discover, and tells an
-- addon which of them you have (C_MapExplorationInfo). Covers.lua has, for every such piece, the land
-- it stands for and a patch of fog its shape, thinning out to mist at its edge (tools/globe_explore.py).
-- The patches of the pieces you have not discovered are laid over the globe's own map; one you
-- discover clears away.
--
-- A zone of which nothing is discovered is covered by one patch of the whole of it, at every zoom.
-- The fog is thin (Fog Opacity): the painted map shows through it.
--
-- Zoomed in to the ground, where the minimap's pictures come in over the painted map, they come in
-- only over land you have discovered: the rest stays the painted map under its fog. Covers.lua says
-- whose piece the land is at each corner of a quarter of a terrain tile; a ground picture shows fully
-- at a corner that is discovered (or no piece's) and not at all at one that is not, fading between.
-- For a zone you have never entered the game gives no list at all (nil, not an empty one): that is
-- nothing discovered too, once the game has given a list for any zone (before that it may not be
-- telling yet, and nothing is covered). The cities have no pieces and are never covered. Where this
-- game client's picture of a zone is not the one the patches were made from, that zone is left as
-- it is. Parchment style only.
local ADDON, ns = ...
if not (ns.linked and ns.G and ns.Marks and ns.COVERS) then return end
local G, Marks = ns.G, ns.Marks
local floor, min, max = math.floor, math.min, math.max

local ART = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\'
local VIEW = G.VIEW
local REVEAL = 1.6                    -- seconds a newly discovered piece takes to clear
local PER = 4                         -- corners to a terrain tile's side at which the ground is shown or not (Covers.lua)
local ACROSS = 64 * PER + 1           -- such corners across a continent
local SIDE = PER + 1                  -- and along a tile's side, both ends counted
local AGAIN = 1                       -- what you have discovered is read at most this often (seconds)

local explore = rawget(_G, 'C_MapExplorationInfo')
local zones                           -- one a zone map: { entry, whole (a picture), pieces = { key = picture }, found, known, none }
local stale, readAt, read = true, -AGAIN, false
local telling = false                 -- the game has given a list of discovered pieces for some zone
local clearing = {}                   -- pictures fading away: picture = the time its piece was discovered
local shown = 0                       -- the patches of fog laid at the last drawing (those out of the picture too)
local veilOn, veilStale = false, false   -- the ground is kept off undiscovered land; and what is discovered has changed
local veiled = 0                      -- ground pictures now shown in part or not at all
local fogged = 0                      -- how much the fog hid at the last drawing (0 to 1)
local plain = {}                      -- a ground picture as the globe made it: picture = { Fade, deepest, uneven } (false: none)

local function Picture(entry, c, f)
	local w, h = entry.w, entry.h
	local column, row, columns, rows = f[5], f[6], f[7], f[8]
	return { fdid = ART .. entry.file, layer = 'cover', coords = { f[1] / w, (f[1] + f[3]) / w, f[2] / h, (f[2] + f[4]) / h },
		At = function(fu, fv) return { G.OnGlobe(c, (column + columns * fu) / 16, (row + rows * fv) / 16) } end }
end

local function Prepare()
	if zones then return end
	zones = {}
	local byArt = {}
	for art, entry in pairs(ns.COVERS) do
		local c = G.continents[entry.map]
		if c then
			local zone = { art = art, entry = entry, whole = Picture(entry, c, entry.whole), pieces = {}, found = {}, known = false, none = true,
				points = {} }             -- (by piece: the corners of quarter tiles that are its land, row * ACROSS + column)
			zone.whole.deepest = 5        -- (a whole zone's sheet is drawn close in too: cut a step finer than a piece's)
			for key, f in pairs(entry.pieces) do zone.pieces[key] = Picture(entry, c, f) end
			zones[#zones + 1] = zone
			byArt[art] = zone
		end
	end
	for _, data in pairs(ns.COVER_POINTS or {}) do
		local owners = data.owners
		if data.per == PER then
			for n, runs in ipairs(data.rows) do
				local row, column = data.row0 + n - 1, 0
				for count, owner in runs:gmatch('(%d+),(%d+)') do
					count, owner = tonumber(count), tonumber(owner)
					local zone, key = byArt[owners[owner * 2 - 1]], owners[owner * 2]
					if zone and zone.pieces[key] then
						local list = zone.points[key]
						if not list then
							list = {}
							zone.points[key] = list
						end
						for at = row * ACROSS + column, row * ACROSS + column + count - 1 do list[#list + 1] = at end
					end
					column = column + count
				end
			end
		end
	end
end

-- One ground picture, given which of the corners on it are of undiscovered land (dark: a number, a bit
-- a corner, row by row; 0 for none): it shows fully at the others and not at all at these, fading from
-- corner to corner, times what it showed before (a tile at the coast fades out to sea).
local function Veil(pic, dark)
	local was = plain[pic]
	if not was then
		was = { pic.Fade or false, pic.deepest or false, pic.uneven or false }
		plain[pic] = was
	end
	if (pic.veil or 0) ~= 0 then veiled = veiled - 1 end
	pic.veil = dark
	if dark == 0 then
		pic.Fade, pic.deepest, pic.uneven, pic.Cut = was[1] or nil, was[2] or nil, was[3] or nil, nil
	else
		veiled = veiled + 1
		local v, rest = {}, dark
		for k = 1, SIDE * SIDE do
			local bit = rest % 2
			v[k], rest = 1 - bit, (rest - bit) / 2
		end
		local Before, uneven = was[1], was[3]
		pic.Fade = function(fu, fv)
			local x, y = fu * PER, fv * PER
			local i, j = min(PER - 1, floor(x)), min(PER - 1, floor(y))
			local k = j * SIDE + i + 1
			local a, b = x - i, y - j
			local lit = (v[k] + (v[k + 1] - v[k]) * a) * (1 - b) + (v[k + SIDE] + (v[k + SIDE + 1] - v[k + SIDE]) * a) * b
			return Before and lit * Before(fu, fv) or lit
		end
		-- (a piece lies between four corners once it is a quarter of the tile's side or less. Until then it
		-- is cut smaller wherever its corners differ; after that only where it fades toward one corner)
		pic.Cut = function(fu0, fu1, fv0, fv1, depth)
			local n, i0, j0 = 1, nil, nil
			if 2 ^ depth < PER then
				n = PER / 2 ^ depth
				i0, j0 = floor(fu0 * PER + 0.5), floor(fv0 * PER + 0.5)
			else
				i0, j0 = min(PER - 1, floor((fu0 + fu1) / 2 * PER)), min(PER - 1, floor((fv0 + fv1) / 2 * PER))
			end
			local lit, all = 0, (n + 1) * (n + 1)
			for j = j0, j0 + n do
				for i = i0, i0 + n do lit = lit + v[j * SIDE + i + 1] end
			end
			if lit == 0 then return 0 end
			if lit == all then return uneven and 2 or nil end
			if n > 1 then return 1 end
			local k = j0 * SIDE + i0 + 1
			if uneven or v[k] + v[k + SIDE + 1] ~= v[k + 1] + v[k + SIDE] then return 2 end
		end
		pic.deepest, pic.uneven = G.FADE_DEEPEST, nil
	end
	G.Forget(pic)
end

-- The ground kept off the land you have not discovered (on), or shown everywhere as the globe made it.
-- Only the pictures for which something changed are touched.
local function Veils(on)
	veilOn, veilStale = on, false
	local dark = {}
	if on then
		for _, zone in ipairs(zones or {}) do
			if zone.known then
				local d = dark[zone.entry.map]
				if not d then
					d = {}
					dark[zone.entry.map] = d
				end
				for key, list in pairs(zone.points) do
					if not zone.found[key] then
						for n = 1, #list do d[list[n]] = true end
					end
				end
			end
		end
	end
	local changed = false
	for map, c in pairs(G.continents) do
		local d = dark[map]
		for index, pic in pairs(c.ground or {}) do
			local sum = 0
			if d then
				local i0, j0, bit = (index % 64) * PER, floor(index / 64) * PER, 1
				for j = j0, j0 + PER do
					local at = j * ACROSS + i0
					for i = 0, PER do
						if d[at + i] then sum = sum + bit end
						bit = bit * 2
					end
				end
			end
			if sum ~= (pic.veil or 0) then
				Veil(pic, sum)
				changed = true
			end
		end
	end
	if changed then G.Changed() end
end

-- Which pieces of each zone you have discovered. A zone whose picture here is another than the one its
-- patches were made from (or which the game could not be asked about) is not known, and is not covered.
-- No list for a zone is nothing discovered in it, once the game is telling.
local function Read()
	Prepare()
	stale, readAt = false, GetTime()
	local now = readAt
	local lists = {}
	for i, zone in ipairs(zones) do
		local ui = zone.entry.ui
		local ok, art = pcall(C_Map.GetMapArtID, ui)
		local ok2, list = pcall(explore.GetExploredMapTextures, ui)
		if ok and art == zone.art and ok2 and (list == nil or type(list) == 'table') then
			lists[i] = list or false
			if list then telling = true end
		end
	end
	for i, zone in ipairs(zones) do
		local list = lists[i]
		if list or (list == false and telling) then
			local found, none = {}, true
			for _, piece in ipairs(list or {}) do
				if type(piece) == 'table' and type(piece.offsetX) == 'number' and type(piece.offsetY) == 'number' then
					local key = piece.offsetX * 4096 + piece.offsetY
					if zone.pieces[key] then
						found[key], none = true, false
						-- (discovered since the last look: its patch fades away)
						if read and zone.known and not zone.found[key] then clearing[zone.pieces[key]] = now end
					end
				end
			end
			local left = 0
			for key in pairs(zone.pieces) do
				if not found[key] then left = left + 1 end
			end
			zone.found, zone.none, zone.known, zone.left = found, none, true, left
		else
			zone.known = false
		end
	end
	read, veilStale = true, true
end

local function Wanted()
	return ns.Get('globeExplore') and type(explore) == 'table' and type(explore.GetExploredMapTextures) == 'function'
		and type(C_Map.GetMapArtID) == 'function'
end

ns.GlobeOn('pictures', function(r, shade, style)
	shown = 0
	if style ~= 'parchment' or not Wanted() then return end
	local now = GetTime()
	local fog = max(0, min(1, (tonumber(ns.Get('globeFog')) or 30) / 100))
	fogged = fog
	if stale and now - readAt >= AGAIN then Read() end
	if not zones then return end
	for _, zone in ipairs(zones) do
		if zone.known and not G.InView(zone.whole, r, 1.1) then
			-- (a zone out of the picture is passed over whole: its pieces all lie within its one sheet. Its
			-- fog is counted all the same)
			shown = shown + (zone.none and 1 or zone.left)
		elseif zone.known then
			if zone.none then
				G.Draw(zone.whole, r, fog, shade)
				shown = shown + 1
			else
				for key, pic in pairs(zone.pieces) do
					if not zone.found[key] then
						G.Draw(pic, r, fog, shade)
						shown = shown + 1
					end
				end
			end
		end
	end
	for pic, since in pairs(clearing) do
		local t = (now - since) / REVEAL
		if t >= 1 then
			clearing[pic] = nil
		else
			G.Draw(pic, r, fog * (1 - t * t * (3 - 2 * t)), shade)
			shown = shown + 1
		end
	end
end)

ns.GlobeOn('frame', function()
	-- (while a patch fades, and when what you have discovered is to be read again, the globe is drawn again)
	if next(clearing) or (stale and Wanted() and GetTime() - readAt >= AGAIN) then G.Changed() end
	-- (the ground is kept off undiscovered land between two drawings, never within one)
	local on = Wanted() and ns.Get('globeStyle') == 'parchment'
	if on ~= veilOn or (veilStale and on) then Veils(on) end
end)

local function Stale() stale = true end
ns.GlobeOn('show', Stale)
Marks.On('MAP_EXPLORATION_UPDATED', Stale)
Marks.On('ZONE_CHANGED_NEW_AREA', Stale)
Marks.On('PLAYER_ENTERING_WORLD', Stale)

-- For the checks outside the game.
function ns.ExploreState()
	local out = { shown = shown, clearing = 0, zones = zones and #zones or 0, known = 0, veiled = veiled, fog = fogged }
	for _ in pairs(clearing) do out.clearing = out.clearing + 1 end
	for _, zone in ipairs(zones or {}) do
		if zone.known then out.known = out.known + 1 end
	end
	return out
end
