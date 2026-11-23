-- Globe (Thread): zones coloured by level.
--
-- With Color Zones By Level, a thin wash of colour lies over each zone and says how its levels stand to
-- yours, in the game's own colours for that: grey for far below you, green, yellow, orange, and red for
-- far above. It answers "where next?" at a glance.
--
--   the shape    Covers.lua has, for every zone the game's map can discover, a soft-edged patch of
--                paper the shape of its land (beside the fog Explore.lua lays over a zone you have
--                seen nothing of). The wash is that patch, tinted and thin: one picture a zone, on a
--                layer of its own over the map, the ground and the fog, and under the paper's
--                age, the lines, the marks and the names. A zone with no such patch (the cities, and
--                the few zones the game's map has no pictures for) has no wash.
--   the levels   asked of the game by the zone's own map (ns.MapLevels in Places.lua, which also
--                writes them by the zone's name), a few zones at a time while the globe is open, and
--                kept. A zone is washed once its levels are known; one the game gives none for is not.
--   the colour   by the rule the levels by a zone's name are coloured with (ns.LevelColour), worked out
--                again when you gain a level.
--   by zoom      whole from the whole globe in to a zone that fills the picture, then fading out
--                toward the ground: there one colour would lie over everything in view and say nothing.
--                Both map styles; never on a city's or battleground's flat map.
--
-- While it shows, a small key to the five colours stands in the picture's lower left corner.
local ADDON, ns = ...
if not (ns.linked and ns.G and ns.Marks and ns.COVERS and ns.MapLevels and ns.LevelColour) then return end
local G = ns.G

local min = math.min
local ART = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\'
local VIEW = G.VIEW
local WASH = 0.42                     -- how much of the wash shows at most: thin, so the painting shows through
local GONE = { VIEW * 3.2, VIEW * 6 } -- zooming in to the ground, it fades out between these (the globe's radius, points)
local PAPER = { 214 / 255, 196 / 255, 152 / 255 }     -- the colour of the patches' paper (tools/globe_explore.py)
local EACH, TICK = 3, 0.1             -- this many zones are asked for their levels at a time, this many seconds apart
-- the key: the game's name for each colour (QuestDifficultyColors), the word beside it, and the colour
-- where the game does not give it; from far above you down to far below
local BANDS = {
	{ 'impossible', 'Far Above', { r = 1, g = 0.1, b = 0.1 } },
	{ 'verydifficult', 'Above', { r = 1, g = 0.5, b = 0.25 } },
	{ 'difficult', 'Your Level', { r = 1, g = 0.82, b = 0 } },
	{ 'standard', 'Below', { r = 0.25, g = 0.75, b = 0.25 } },
	{ 'trivial', 'Far Below', { r = 0.5, g = 0.5, b = 0.5 } },
}
local ROW = 14                        -- the key's rows are this far apart (points)

local zones                           -- one a zone map with a patch: { ui, pic, range ({ least, most }, false: none; nil: not known yet), colour }
local unknown, turn = 0, 1            -- how many zones' levels are not known yet, and the next to ask
local colouredFor                     -- the level the tints were worked out for
local shown, alphaNow = 0, 0          -- at the last drawing: zones washed, and how much of the wash showed
local key                             -- the key's frame

local function On() return ns.Get('globeLevels') and true or false end

local function Prepare()
	if zones then return end
	zones = {}
	for _, entry in pairs(ns.COVERS) do
		local c = G.continents[entry.map]
		local f = entry.shape or entry.whole
		if c and type(entry.ui) == 'number' and type(f) == 'table' then
			local w, h = entry.w, entry.h
			local column, row, columns, rows = f[5], f[6], f[7], f[8]
			zones[#zones + 1] = { ui = entry.ui, pic = { fdid = ART .. entry.file, layer = 'wash',
				coords = { f[1] / w, (f[1] + f[3]) / w, f[2] / h, (f[2] + f[4]) / h },
				At = function(fu, fv) return { G.OnGlobe(c, (column + columns * fu) / 16, (row + rows * fv) / 16) } end } }
		end
	end
	table.sort(zones, function(a, b) return a.ui < b.ui end)
	unknown = #zones
end

ns.GlobeOn('pictures', function(r)
	shown, alphaNow = 0, 0
	if not On() then return end
	Prepare()
	local alpha = WASH * (1 - G.Smooth(GONE[1], GONE[2], r))
	if alpha < 0.02 then return end
	alphaNow = alpha
	-- (a level gained: every zone's colour is worked out again)
	local mine = ns.MyLevel()
	local again = mine ~= colouredFor
	colouredFor = mine
	for _, zone in ipairs(zones) do
		local range = zone.range
		if range then
			if again or not zone.colour then
				local cr, cg, cb = ns.LevelColour(range[1], range[2])
				zone.colour = { cr, cg, cb }
				-- (the patch is the colour of paper, and a tint can only darken it: tinted so that what shows
				-- is the level's own colour, as near as that allows)
				zone.pic.tint = { min(1, cr / PAPER[1]), min(1, cg / PAPER[2]), min(1, cb / PAPER[3]) }
			end
			-- (not shaded toward the globe's edge: a darker wash there would read as another colour)
			G.Draw(zone.pic, r, alpha, false)
			shown = shown + 1
		end
	end
end)

-- The key to the colours, in the picture's lower left corner (clear of the coordinates at its lower
-- edge, and of the Globe button a flat map puts at its upper left).
local function Key(on)
	if not on then
		if key then key:Hide() end
		return
	end
	if not key then
		local _, view, canvas = G.Frames()
		key = CreateFrame('Frame', nil, view)
		key:SetSize(92, #BANDS * ROW + 8)
		key:SetPoint('BOTTOMLEFT', view, 'BOTTOMLEFT', 8, 26)
		-- (over the globe's own drawing and the candlelight, both on the canvas)
		if key.SetFrameLevel and canvas.GetFrameLevel then key:SetFrameLevel((canvas:GetFrameLevel() or 1) + 5) end
		local back = key:CreateTexture(nil, 'BACKGROUND')
		back:SetAllPoints(key)
		back:SetColorTexture(0, 0, 0, 0.5)
		local colours = rawget(_G, 'QuestDifficultyColors')
		key.rows = {}
		for i, band in ipairs(BANDS) do
			local c = type(colours) == 'table' and colours[band[1]]
			if not (type(c) == 'table' and type(c.r) == 'number' and type(c.g) == 'number' and type(c.b) == 'number') then c = band[3] end
			local swatch = key:CreateTexture(nil, 'ARTWORK')
			swatch:SetSize(10, 10)
			swatch:SetPoint('TOPLEFT', key, 'TOPLEFT', 6, -6 - (i - 1) * ROW)
			swatch:SetColorTexture(c.r, c.g, c.b, 1)
			local word = key:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
			word:SetPoint('LEFT', swatch, 'RIGHT', 6, 0)
			word:SetText(band[2])
			key.rows[i] = { word = band[2], colour = { c.r, c.g, c.b } }
		end
	end
	key:Show()
end

ns.GlobeOn('paint', function()
	-- (on a flat map nothing of the globe was drawn, and what the last drawing washed no longer counts)
	local flat = ns.FlatOn and ns.FlatOn()
	Key(On() and not flat and shown > 0 and alphaNow > 0)
end)
ns.GlobeOn('hide', function() Key(false) end)

-- The zones' levels, a few at a time while the globe is open and the wash is on.
local since = 0
ns.GlobeOn('frame', function(elapsed)
	if not On() or (zones and unknown == 0) then return end
	since = since + (elapsed or 0)
	if since < TICK then return end
	since = 0
	if ns.FlatOn and ns.FlatOn() then return end
	Prepare()
	local asked, found = 0, false
	for _ = 1, #zones do
		if asked >= EACH or unknown == 0 then break end
		local zone = zones[turn]
		turn = turn % #zones + 1
		if zone.range == nil then
			asked = asked + 1
			local range = ns.MapLevels(zone.ui)
			if range ~= nil then
				zone.range, unknown = range, unknown - 1
				found = found or range ~= false
			end
		end
	end
	if found then G.Changed() end
end)

-- Color Zones By Level, by key or gamepad.
ns.GlobeOn('key', function(what)
	if what ~= 'levels' then return false end
	ns.Set('globeLevels', not On())
	return true
end)

-- For the checks outside the game: what is known of the zones' levels is forgotten.
local forget = ns.LevelsForget
function ns.LevelsForget()
	forget()
	for _, zone in ipairs(zones or {}) do zone.range, zone.colour, zone.pic.tint = nil, nil, nil end
	unknown, turn, colouredFor = zones and #zones or 0, 1, nil
end

-- For the checks outside the game.
function ns.WashState()
	local out = { shown = shown, alpha = alphaNow, zones = zones and #zones or 0, unknown = unknown, known = {},
		key = key and key:IsShown() or false, rows = key and key.rows or nil }
	for _, zone in ipairs(zones or {}) do
		if zone.range then out.known[zone.ui] = { least = zone.range[1], most = zone.range[2], colour = zone.colour, tint = zone.pic.tint } end
	end
	return out
end
