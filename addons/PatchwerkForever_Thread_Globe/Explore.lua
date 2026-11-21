-- Globe (Thread): land you have not discovered is left blank, as the game's own map leaves it.
--
-- The game's map of a zone is drawn in pieces, one for each part of it you can discover, and tells an
-- addon which of them you have (C_MapExplorationInfo). Covers.lua has, for every such piece, the land
-- it stands for and a soft-edged patch of paper its shape (tools/globe_explore.py). The patches of
-- the pieces you have not discovered are laid over the globe's own map; one you discover fades away.
--
-- A zone of which nothing is discovered is covered by one patch of the whole of it while zoomed out.
-- The cities have no pieces and are never covered. Where this game client's picture of a zone is not
-- the one the patches were made from, that zone is left as it is. Parchment style only.
local ADDON, ns = ...
if not (ns.linked and ns.G and ns.Marks and ns.COVERS) then return end
local G, Marks = ns.G, ns.Marks

local ART = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\'
local VIEW = G.VIEW
local WHOLE_UPTO = VIEW * 2.2         -- zoomed in past this, an undiscovered zone is covered piece by piece
local REVEAL = 1.6                    -- seconds a newly discovered piece takes to clear
local AGAIN = 1                       -- what you have discovered is read at most this often (seconds)

local explore = rawget(_G, 'C_MapExplorationInfo')
local zones                           -- one a zone map: { entry, whole (a picture), pieces = { key = picture }, found, known, none }
local stale, readAt, read = true, -AGAIN, false
local clearing = {}                   -- pictures fading away: picture = the time its piece was discovered
local shown = 0

local function Picture(entry, c, f)
	local w, h = entry.w, entry.h
	local column, row, columns, rows = f[5], f[6], f[7], f[8]
	return { fdid = ART .. entry.file, layer = 'cover', coords = { f[1] / w, (f[1] + f[3]) / w, f[2] / h, (f[2] + f[4]) / h },
		At = function(fu, fv) return { G.OnGlobe(c, (column + columns * fu) / 16, (row + rows * fv) / 16) } end }
end

local function Prepare()
	if zones then return end
	zones = {}
	for art, entry in pairs(ns.COVERS) do
		local c = G.continents[entry.map]
		if c then
			local zone = { art = art, entry = entry, whole = Picture(entry, c, entry.whole), pieces = {}, found = {}, known = false, none = true }
			for key, f in pairs(entry.pieces) do zone.pieces[key] = Picture(entry, c, f) end
			zones[#zones + 1] = zone
		end
	end
end

-- Which pieces of each zone you have discovered. A zone whose picture here is another than the one its
-- patches were made from (or of which the game says nothing) is not known, and is not covered.
local function Read()
	Prepare()
	stale, readAt = false, GetTime()
	local now = readAt
	for _, zone in ipairs(zones) do
		local ui = zone.entry.ui
		local ok, art = pcall(C_Map.GetMapArtID, ui)
		local ok2, list = pcall(explore.GetExploredMapTextures, ui)
		if ok and art == zone.art and ok2 and type(list) == 'table' then
			local found, none = {}, true
			for _, piece in ipairs(list) do
				if type(piece) == 'table' and type(piece.offsetX) == 'number' and type(piece.offsetY) == 'number' then
					local key = piece.offsetX * 4096 + piece.offsetY
					if zone.pieces[key] then
						found[key], none = true, false
						-- (discovered since the last look: its patch fades away)
						if read and zone.known and not zone.found[key] then clearing[zone.pieces[key]] = now end
					end
				end
			end
			zone.found, zone.none, zone.known = found, none, true
		else
			zone.known = false
		end
	end
	read = true
end

local function Wanted()
	return ns.Get('globeExplore') and type(explore) == 'table' and type(explore.GetExploredMapTextures) == 'function'
		and type(C_Map.GetMapArtID) == 'function'
end

ns.GlobeOn('pictures', function(r, shade, style)
	shown = 0
	if style ~= 'parchment' or not Wanted() then return end
	local now = GetTime()
	if stale and now - readAt >= AGAIN then Read() end
	if not zones then return end
	for _, zone in ipairs(zones) do
		if zone.known then
			if zone.none and r < WHOLE_UPTO then
				G.Draw(zone.whole, r, 1, shade)
				shown = shown + 1
			else
				for key, pic in pairs(zone.pieces) do
					if not zone.found[key] then
						G.Draw(pic, r, 1, shade)
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
			G.Draw(pic, r, 1 - t * t * (3 - 2 * t), shade)
			shown = shown + 1
		end
	end
end)

ns.GlobeOn('frame', function()
	-- (while a patch fades, and when what you have discovered is to be read again, the globe is drawn again)
	if next(clearing) or (stale and Wanted() and GetTime() - readAt >= AGAIN) then G.Changed() end
end)

local function Stale() stale = true end
ns.GlobeOn('show', Stale)
Marks.On('MAP_EXPLORATION_UPDATED', Stale)
Marks.On('ZONE_CHANGED_NEW_AREA', Stale)
Marks.On('PLAYER_ENTERING_WORLD', Stale)

-- For the checks outside the game.
function ns.ExploreState()
	local out = { shown = shown, clearing = 0, zones = zones and #zones or 0, known = 0 }
	for _ in pairs(clearing) do out.clearing = out.clearing + 1 end
	for _, zone in ipairs(zones or {}) do
		if zone.known then out.known = out.known + 1 end
	end
	return out
end
