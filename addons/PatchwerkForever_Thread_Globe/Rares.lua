-- Thread (Globe): what the game marks only while it is near you: rare creatures, treasures, events.
--
-- The game calls these vignettes (C_VignetteInfo): the star on the minimap for a rare creature, the
-- chest for a treasure. Each is shown where the game says it is, with the game's own icon and name.
local ADDON, ns = ...
if not (ns.linked and ns.Marks) then return end
local G, Marks = ns.G, ns.Marks
local Guides = ns.Base.Guides

local VIEW = G.VIEW
local FROM = VIEW * 0.9               -- shown from this zoom in (the globe's radius, points)
local PALE, GREY = { 0.75, 0.9, 1 }, { 0.6, 0.6, 0.6 }
local vignettes = rawget(_G, 'C_VignetteInfo') or {}

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
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

-- Where one is in the world: asked on your own continent's map first, then on the others'.
local function Where(guid)
	local mine = G.MyPlace()
	local maps = { mine and mine.map }
	for map in pairs(G.continents) do
		if not (mine and mine.map == map) then maps[#maps + 1] = map end
	end
	for _, map in ipairs(maps) do
		local continent = G.UiMap(map)
		local x, y = XY(continent and Ask(vignettes.GetVignettePosition, guid, continent))
		if x and x > 0 and x < 1 and y > 0 and y < 1 then
			local on, wx, wy = Guides.WorldOf(continent, x, y)
			if on then return on, wx, wy end
		end
	end
end

Marks.Source('rares', {
	order = 60,
	every = 5,                        -- (a creature walks)
	Shown = function() return ns.Get('globeRares') and type(vignettes.GetVignettes) == 'function' end,
	Fill = function(mark)
		local list = Ask(vignettes.GetVignettes)
		for _, guid in ipairs(type(list) == 'table' and list or {}) do
			local info = Ask(vignettes.GetVignetteInfo, guid)
			if type(info) == 'table' and Plain(info.name) and type(info.name) == 'string' and info.name ~= ''
				and (info.onWorldMap or info.onMinimap) then
				local map, x, y = Where(guid)
				if map then
					local atlas = type(info.atlasName) == 'string' and info.atlasName ~= '' and info.atlasName or nil
					local known = atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
					local dead = info.isDead and true or false
					mark({ map = map, x = x, y = y, atlas = atlas, icon = Marks.Icon('place'), size = 22, rank = 60, keep = true,
						from = FROM, name = info.name, lines = dead and { 'Dead' } or nil,
						tint = dead and GREY or (not known and PALE) or nil })
				end
			end
		end
	end,
})
Marks.On('VIGNETTES_UPDATED', function() Marks.Changed('rares') end)
Marks.On('VIGNETTE_MINIMAP_UPDATED', function() Marks.Changed('rares') end)
