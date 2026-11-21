-- Thread (Globe): places, people and words.
--
--   places       the towns and landmarks of the zone at the middle of the picture, and its dungeon and
--                raid entrances, with the game's own icons and names, from zone level in
--   directions   the flag the game puts on the map when a city guard tells you the way
--   battlegrounds  on a battleground's own flat map: its places, flags and vehicles
--   your death   while you are dead: your corpse, and the spirit healer the game would send you to.
--                (The game's own map marks the corpse only.)
--   your group   the members of your party or raid, each in their class's colour, grey when dead
--   words        the zone's levels by its name, coloured as the game colours them for your level; under
--                the name, the smaller place the pointer is over (a town, a camp, a pass); and at the
--                picture's lower edge your coordinates and the pointer's, on the zone's own map
--
-- With keys or a gamepad the pointer is the middle of the picture, here as everywhere: the place named
-- and the coordinates shown are those at the cross, and Next Mark steps through these marks too.
local ADDON, ns = ...
if not (ns.linked and ns.Marks) then return end
local G, Marks = ns.G, ns.Marks
local Guides = ns.Base.Guides

local VIEW = G.VIEW
local ZONE_FROM = VIEW * 1.2          -- places, and the smaller place's name, are shown from this zoom in
local POI_ICONS = 'Interface\\Minimap\\POIIcons'      -- the game's sheet of place icons
local GREY, PALE = { 0.6, 0.6, 0.6 }, { 0.62, 0.86, 1 }
local TRIES = 12                      -- how often a zone's levels are asked for before it is left without

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end

-- A value the game lets an addon read (in a fight it may hand over one that can only be passed on).
local function Plain(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end

local function XY(pos)
	if not Plain(pos) or type(pos) ~= 'table' then return nil end
	local x, y = pos.x, pos.y
	if pos.GetXY then x, y = pos:GetXY() end
	if Plain(x) and Plain(y) and type(x) == 'number' and type(y) == 'number' then return x, y end
	return nil
end

-- One of the game's own words, where this client has it.
local function Word(global, ours)
	local text = rawget(_G, global)
	return type(text) == 'string' and text ~= '' and text or ours
end

---------------------------------------------------------------------------
-- Places
---------------------------------------------------------------------------
local poi = rawget(_G, 'C_AreaPoiInfo') or {}
local journal = rawget(_G, 'C_EncounterJournal') or {}
local minimap = rawget(_G, 'C_Minimap') or {}

-- A place's picture: the game's named one where it gives a name this client knows, else its piece of
-- the game's sheet of place icons, else one of ours.
local function Picture(m, info, ours)
	if type(info.atlasName) == 'string' and info.atlasName ~= '' then m.atlas = info.atlasName end
	m.icon = Marks.Icon(ours)
	if type(info.textureIndex) == 'number' then
		local x1, x2, y1, y2 = Ask(minimap.GetPOITextureCoords, info.textureIndex)
		if type(x1) == 'number' and type(y2) == 'number' and x1 < x2 and y1 < y2 then
			m.icon, m.coords = POI_ICONS, { x1, x2, y1, y2 }
		end
	end
	return m
end

-- Where a mark goes, given a place on one of the game's maps (0 to 1 across and down): its place in
-- the globe's world; or, for a map that is no part of that world (a battleground's), its place on that
-- map itself, shown while the map is up flat. Neither: the mark has nowhere to be and is not shown.
local function At(m, ui, u, v)
	local map, wx, wy = Guides.WorldOf(ui, u, v)
	if map and G.continents[map] then
		m.map, m.x, m.y = map, wx, wy
	elseif ns.FlatMap and ns.FlatMap() == ui then
		m.on, m.u, m.v = ui, u, v
	end
	return m
end

Marks.Source('places', {
	order = 25,
	every = 60,
	Shown = function() return ns.Get('globePlaces') end,
	Key = function(r) return r >= ZONE_FROM and (Marks.ZoneMap()) or 'far' end,
	Fill = function(mark)
		if Marks.Zoom() < ZONE_FROM then return end
		local zone = Marks.ZoneMap()
		if not zone then return end
		-- (the places that are always there, and those of an event going on now)
		local seen = {}
		for _, list in ipairs({ Ask(poi.GetAreaPOIForMap, zone) or {}, Ask(poi.GetEventsForMap, zone) or {} }) do
			for _, id in ipairs(type(list) == 'table' and list or {}) do
				local info = not seen[id] and Ask(poi.GetAreaPOIInfo, zone, id)
				seen[id] = true
				local x, y = XY(type(info) == 'table' and info.position)
				if x and type(info.name) == 'string' and info.name ~= '' then
					local words = type(info.description) == 'string' and info.description ~= '' and { info.description } or nil
					mark(Picture(At({ size = 18, rank = 24, from = ZONE_FROM, name = info.name, lines = words }, zone, x, y), info, 'place'))
				end
			end
		end
		for _, info in ipairs(Ask(journal.GetDungeonEntrancesForMap, zone) or {}) do
			local x, y = XY(type(info) == 'table' and info.position)
			if x and type(info.name) == 'string' and info.name ~= '' then
				local raid = info.atlasName == 'Raid'
				mark(Picture(At({ size = 20, rank = 28, from = ZONE_FROM, name = info.name,
					lines = { raid and Word('RAID', 'Raid') or Word('DUNGEON', 'Dungeon') } }, zone, x, y), info, 'place'))
			end
		end
	end,
})
Marks.On('AREA_POIS_UPDATED', function() Marks.Changed('places') end)

---------------------------------------------------------------------------
-- A guard's directions
---------------------------------------------------------------------------
-- Ask a city guard the way and the game puts a flag on the map at the place. It is asked for on the
-- map at the middle of the picture (the flat map, when one is up) and on the map you are on.
local gossip = rawget(_G, 'C_GossipInfo') or {}

Marks.Source('directions', {
	order = 70,
	every = 10,
	Shown = function() return ns.Get('globePlaces') end,
	Fill = function(mark)
		local asked = {}
		for _, ui in ipairs({ (Marks.ZoneMap()) or false, Ask(C_Map.GetBestMapForUnit, 'player') or false }) do
			if Plain(ui) and type(ui) == 'number' and not asked[ui] then
				asked[ui] = true
				local id = Ask(gossip.GetPoiForUiMapID, ui)
				local info = Plain(id) and type(id) == 'number' and Ask(gossip.GetPoiInfo, ui, id)
				local x, y = XY(type(info) == 'table' and info.position)
				if x then
					local name = type(info.name) == 'string' and info.name ~= '' and info.name or 'Directions'
					mark(Picture(At({ size = 22, rank = 65, keep = true, name = name }, ui, x, y), info, 'place'))
					return
				end
			end
		end
	end,
})
Marks.On('DYNAMIC_GOSSIP_POI_UPDATED', function() Marks.Changed('directions') end)

---------------------------------------------------------------------------
-- A battleground's flags and vehicles
---------------------------------------------------------------------------
-- On the battleground's own flat map, where the game says they are. (Its graveyards, towers and the
-- like are places, above.) Asked once a second while a flat map is up; out of a battleground the game
-- has none to give.
local pvp = rawget(_G, 'C_PvP') or {}
local MOST_FLAGS = 8

Marks.Source('field', {
	order = 78,
	every = 1,
	Shown = function() return ns.Get('globePlaces') and ns.FlatMap ~= nil and ns.FlatMap() ~= nil end,
	Fill = function(mark)
		local ui = ns.FlatMap()
		if not ui then return end
		local count = Ask(rawget(_G, 'GetNumBattlefieldFlagPositions'))
		for i = 1, Plain(count) and type(count) == 'number' and math.min(count, MOST_FLAGS) or 0 do
			local x, y, picture = Ask(pvp.GetBattlefieldFlagPosition, i, ui)
			if Plain(x) and Plain(y) and type(x) == 'number' and type(y) == 'number' and (x ~= 0 or y ~= 0) then
				local own = Plain(picture) and (type(picture) == 'number' or type(picture) == 'string') and picture ~= 0 and picture ~= ''
				mark(At({ size = 24, rank = 82, keep = true, name = 'Flag', icon = own and picture or Marks.Icon('place') }, ui, x, y))
			end
		end
		for _, v in ipairs(Ask(pvp.GetBattlefieldVehicles, ui) or {}) do
			if type(v) == 'table' and Plain(v.x) and Plain(v.y) and type(v.x) == 'number' and type(v.y) == 'number' then
				mark(At({ size = 22, rank = 76, keep = true, icon = Marks.Icon('place'),
					name = Plain(v.name) and type(v.name) == 'string' and v.name ~= '' and v.name or nil,
					atlas = Plain(v.atlas) and type(v.atlas) == 'string' and v.atlas ~= '' and v.atlas or nil,
					tint = v.isAlive == false and GREY or nil }, ui, v.x, v.y))
			end
		end
	end,
})

---------------------------------------------------------------------------
-- Your death
---------------------------------------------------------------------------
local death = rawget(_G, 'C_DeathInfo') or {}

local function Dead(unit)
	local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
	return Plain(dead) and dead and true or false
end

Marks.Source('death', {
	order = 85,
	every = 2,
	Shown = function() return ns.Get('globePlaces') and Dead('player') end,
	Fill = function(mark)
		-- (each continent's own map is asked: the corpse may lie on another than the one your ghost is on)
		local corpse, healer
		for map in pairs(G.continents) do
			local continent = G.UiMap(map)
			if continent then
				local x, y = XY(Ask(death.GetCorpseMapPosition, continent))
				if x and not corpse then
					local on, wx, wy = Guides.WorldOf(continent, x, y)
					corpse = { map = on, x = wx, y = wy, icon = Marks.Icon('grave'), size = 24, rank = 90, keep = true,
						name = Word('CORPSE', 'Corpse') }
				end
				x, y = XY(Ask(death.GetDeathReleasePosition, continent))
				if x and not healer then
					local on, wx, wy = Guides.WorldOf(continent, x, y)
					healer = { map = on, x = wx, y = wy, icon = Marks.Icon('place'), tint = PALE, size = 20, rank = 70, keep = true,
						name = Word('SPIRIT_HEALER', 'Spirit Healer') }
				end
			end
		end
		if healer then mark(healer) end
		if corpse then mark(corpse) end
	end,
})
for _, event in ipairs({ 'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST', 'CORPSE_POSITION_UPDATE' }) do
	Marks.On(event, function() Marks.Changed('death') end)
end

---------------------------------------------------------------------------
-- Your group
---------------------------------------------------------------------------
local function InGroup()
	return IsInGroup ~= nil and IsInGroup() and true or false
end

Marks.Source('people', {
	order = 80,
	every = 1,                       -- (they walk)
	Shown = function() return ns.Get('globePeople') and InGroup() end,
	Fill = function(mark)
		local raid = IsInRaid ~= nil and IsInRaid() and true or false
		local most = raid and (GetNumGroupMembers and GetNumGroupMembers() or 40) or 4
		local colours = rawget(_G, 'RAID_CLASS_COLORS')
		for i = 1, most do
			local unit = (raid and 'raid' or 'party') .. i
			if UnitExists(unit) and not UnitIsUnit(unit, 'player') then
				-- (no place is given for one inside a dungeon, and maybe none an addon may read in a fight)
				local ok, x, y, _, map = pcall(UnitPosition, unit)
				if ok and Plain(x) and Plain(y) and Plain(map) and type(x) == 'number' and type(y) == 'number' then
					local name = UnitName(unit)
					if not (Plain(name) and type(name) == 'string' and name ~= '') then name = 'Group member' end
					local class, token = UnitClass(unit)
					local colour = Plain(token) and type(colours) == 'table' and colours[token]
					local dead = Dead(unit)
					local words = {}
					if Plain(class) and type(class) == 'string' then words[#words + 1] = class end
					if dead then words[#words + 1] = Word('DEAD', 'Dead') end
					mark({ map = map, x = x, y = y, icon = Marks.Icon('person'), size = 16, rank = 75, name = name, lines = words,
						tint = dead and GREY or (type(colour) == 'table' and { colour.r, colour.g, colour.b }) or nil })
				end
			end
		end
	end,
})
Marks.On('GROUP_ROSTER_UPDATE', function() Marks.Changed('people') end)

---------------------------------------------------------------------------
-- Words: a zone's levels, the smaller place, coordinates
---------------------------------------------------------------------------
-- The point of the sphere pointed at: under the pointer, or with keys at the middle of the picture.
local function Pointed()
	if G.ByKeys() then return G.Under(0, -G.Lift()) end
	local _, view = G.Frames()
	if view and view:IsMouseOver() then return G.Under(G.Pointer()) end
	return nil
end

local levels, tried = {}, {}          -- by a zone's own number: { least, most }, or false where the game gives none

-- A zone's levels come from the game's own map of it, found at the point pointed at. Right at a
-- border that map can be the next zone's: then nothing is kept, and it is asked again a little later.
local function Levels(hover)
	local id = hover.zone.id
	if levels[id] ~= nil then return levels[id] end
	if type(C_Map.GetMapLevels) ~= 'function' then
		levels[id] = false
		return false
	end
	tried[id] = (tried[id] or 0) + 1
	if tried[id] > TRIES then
		levels[id] = false
		return false
	end
	local p = Pointed()
	local zone = p and Marks.ZoneMap(p)
	local info = zone and Ask(C_Map.GetMapInfo, zone)
	if not (type(info) == 'table' and info.name == G.ZoneName(hover.zone)) then return nil end
	local least, most = Ask(C_Map.GetMapLevels, zone)
	levels[id] = type(least) == 'number' and type(most) == 'number' and least > 0 and most >= least and { least, most } or false
	return levels[id]
end

-- The colour of a zone's levels: as a quest of its lowest level would be while you are below them, as
-- one a little under its highest once you are above them, and yellow while you are within them.
local function LevelColour(least, most)
	local mine = UnitLevel and UnitLevel('player')
	local c
	if type(mine) == 'number' and type(GetQuestDifficultyColor) == 'function' then
		if mine < least then
			c = GetQuestDifficultyColor(least)
		elseif mine > most then
			c = GetQuestDifficultyColor(math.max(1, most - 2))
		end
	end
	if type(c) ~= 'table' or not (c.r and c.g and c.b) then c = { r = 1, g = 0.82, b = 0 } end
	local function Part(v) return math.floor(math.max(0, math.min(1, v)) * 255 + 0.5) end
	return ('|cff%02x%02x%02x'):format(Part(c.r), Part(c.g), Part(c.b))
end

-- The words at the top of the picture for the zone pointed at (Globe.lua asks, and shows them).
function ns.ZoneWords(hover, name)
	local range = Levels(hover)
	if not range then return name end
	local least, most = range[1], range[2]
	return ('%s %s(%s)|r'):format(name, LevelColour(least, most), least == most and tostring(most) or (least .. '-' .. most))
end

local function AreaName(hover)
	local id = hover.area
	if not id then return nil end
	local name = Ask(C_Map.GetAreaInfo, id)
	if not (type(name) == 'string' and name ~= '') then name = ns.AREAS and ns.AREAS[id] end
	if type(name) == 'string' and name ~= G.ZoneName(hover.zone) then return name end
	return nil
end

local areaText, coordsText
local shownArea, shownCoords

ns.GlobeOn('paint', function(r)
	local hover = G.Hover()
	local name = hover and r >= ZONE_FROM and AreaName(hover) or nil
	if name and not areaText then
		local _, _, canvas = G.Frames()
		areaText = canvas:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
		areaText:SetFont('Fonts\\FRIZQT__.TTF', 13, 'OUTLINE')
		areaText:SetTextColor(1, 1, 1)
		areaText:SetPoint('TOP', G.ZoneText(), 'BOTTOM', 0, -2)
	end
	if name ~= shownArea then
		shownArea = name
		if name then
			areaText:SetText(name)
			areaText:Show()
		elseif areaText then
			areaText:Hide()
		end
	end
end)

-- A world place as a spot on one of the game's maps, in hundredths across and down.
local function OnMap(uiMap, map, wx, wy)
	local ok, found, pos = pcall(C_Map.GetMapPosFromWorldPos, map, CreateVector2D(wx, wy), uiMap)
	if not (ok and found) then return nil end
	local x, y = XY(pos)
	if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x * 100, y * 100 end
	return nil
end

local function Coordinates()
	local parts = {}
	local mine = Ask(C_Map.GetBestMapForUnit, 'player')
	local x, y = XY(Plain(mine) and mine and Ask(C_Map.GetPlayerMapPosition, mine, 'player'))
	if x then parts[#parts + 1] = ('Player: %.1f, %.1f'):format(x * 100, y * 100) end
	local p = Pointed()
	if p then
		local zone, continent, map, wx, wy = Marks.ZoneMap(p)
		if zone or continent then
			x, y = OnMap(zone or continent, map, wx, wy)
			if x then parts[#parts + 1] = ('%s: %.1f, %.1f'):format(G.ByKeys() and 'Middle' or 'Cursor', x, y) end
		end
	end
	return table.concat(parts, '    ')
end

local since, asked = 0, 0
ns.GlobeOn('frame', function(elapsed)
	since, asked = since + (elapsed or 0), asked + (elapsed or 0)
	-- (a zone's levels not found yet are asked for again, and its name written again once they are)
	if asked > 0.25 then
		asked = 0
		local hover = G.Hover()
		if hover and levels[hover.zone.id] == nil and Levels(hover) ~= nil then G.Changed() end
	end
	if since < 0.1 then return end
	since = 0
	local text = ns.Get('globeCoords') and ns.Try('the globe', Coordinates) or ''
	if text == shownCoords then return end
	shownCoords = text
	if text ~= '' and not coordsText then
		local _, view, canvas = G.Frames()
		coordsText = canvas:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
		coordsText:SetFont('Fonts\\FRIZQT__.TTF', 11, 'OUTLINE')
		coordsText:SetPoint('BOTTOM', view, 'BOTTOM', 0, 8)
	end
	if coordsText then
		coordsText:SetText(text)
		if text ~= '' then coordsText:Show() else coordsText:Hide() end
	end
end)

-- (your level changes how a zone's levels are coloured)
Marks.On('PLAYER_LEVEL_UP', function() G.Changed() end)

-- For the checks outside the game.
function ns.PlacesState()
	return { area = shownArea, coords = shownCoords, areaText = areaText, coordsText = coordsText }
end
