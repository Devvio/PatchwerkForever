-- Routes (Thread): GatherMate2's herb and ore spots, for gathering runs.
--
-- With GatherMate2 installed, a gathering run (Gather.lua) goes to its spots as well as to the ones
-- Routes remembers itself (Nodes.lua). Two kinds are read:
--
--   what GatherMate2 has      the spots it collected and any data you imported into it, through its
--                             own GetNodesForZone, so its filters (herbs you hid in it) hold
--   its bundled data          GatherMate2_Data's Wowhead spots for Forever, read as they are: no
--                             import into GatherMate2 is needed, and nothing is written into it. The
--                             data addon is loaded on demand when it is not loaded yet.
--
-- Spots are kept a continent at a time in the game's world coordinates, the first time a run looks
-- on that continent. A spot within SAME yards of one of the same kind already kept (one of Routes'
-- own, or the other source's) is left out. Nothing of GatherMate2's is changed.
--
-- Each spot is { x, y, name, kind = 'h' or 'o', id = GatherMate2's node id }. Its required skill
-- is in SKILL below (by GatherMate2's node id), and NAMES gives the same by English name for
-- Routes' own spots.
local ADDON, ns = ...
if not ns.linked then return end

local SAME = 15               -- yards within which two spots of one kind are one spot
local BUCKET = 250            -- yards a side of the squares the spots are sorted into
local TYPES = { h = 'Herb Gathering', o = 'Mining' }
local DATA = { h = 'GatherMateData2HerbDB', o = 'GatherMateData2MineDB' }

-- The skill each node asks for (the game's own numbers for these nodes), by GatherMate2's node id.
local SKILL = {
	-- herbs
	[401] = 1, [402] = 1, [403] = 15, [404] = 50, [405] = 70, [407] = 85, [408] = 100, [409] = 115,
	[410] = 120, [411] = 125, [412] = 150, [413] = 160, [414] = 170, [415] = 185, [416] = 195,
	[417] = 205, [418] = 210, [420] = 220, [421] = 230, [422] = 235, [423] = 245, [424] = 250,
	[425] = 260, [426] = 270, [427] = 280, [428] = 285, [429] = 290, [431] = 300,
	-- ore
	[201] = 1, [202] = 65, [203] = 125, [204] = 75, [205] = 155, [206] = 175, [207] = 175, [208] = 230,
	[209] = 75, [210] = 155, [211] = 230, [212] = 275, [213] = 245, [214] = 245, [215] = 275,
	[217] = 230, [218] = 75, [219] = 65, [220] = 150,
}
local NAMES = {
	['Peacebloom'] = 401, ['Silverleaf'] = 402, ['Earthroot'] = 403, ['Mageroyal'] = 404, ['Briarthorn'] = 405,
	['Stranglekelp'] = 407, ['Bruiseweed'] = 408, ['Wild Steelbloom'] = 409, ['Grave Moss'] = 410,
	['Kingsblood'] = 411, ['Liferoot'] = 412, ['Fadeleaf'] = 413, ['Goldthorn'] = 414,
	["Khadgar's Whisker"] = 415, ['Wintersbite'] = 416, ['Firebloom'] = 417, ['Purple Lotus'] = 418,
	["Arthas' Tears"] = 420, ['Sungrass'] = 421, ['Blindweed'] = 422, ['Ghost Mushroom'] = 423,
	['Gromsblood'] = 424, ['Golden Sansam'] = 425, ['Dreamfoil'] = 426, ['Mountain Silversage'] = 427,
	['Plaguebloom'] = 428, ['Icecap'] = 429, ['Black Lotus'] = 431,
	['Copper Vein'] = 201, ['Tin Vein'] = 202, ['Iron Deposit'] = 203, ['Silver Vein'] = 204,
	['Gold Vein'] = 205, ['Mithril Deposit'] = 206, ['Ooze Covered Mithril Deposit'] = 207,
	['Truesilver Deposit'] = 208, ['Ooze Covered Silver Vein'] = 209, ['Ooze Covered Gold Vein'] = 210,
	['Ooze Covered Truesilver Deposit'] = 211, ['Ooze Covered Rich Thorium Vein'] = 212,
	['Ooze Covered Thorium Vein'] = 213, ['Small Thorium Vein'] = 214, ['Rich Thorium Vein'] = 215,
	['Dark Iron Deposit'] = 217, ['Lesser Bloodstone Deposit'] = 218, ['Incendicite Mineral Vein'] = 219,
	['Indurium Mineral Vein'] = 220,
}

-- GatherMate2 itself (its AceAddon object), or nil.
local function GM()
	local stub = rawget(_G, 'LibStub')
	if type(stub) ~= 'table' then return nil end
	local ok, ace = pcall(stub, 'AceAddon-3.0', true)
	if not (ok and type(ace) == 'table' and ace.GetAddon) then return nil end
	local found, gm = pcall(ace.GetAddon, ace, 'GatherMate2', true)
	if found and type(gm) == 'table' and type(gm.GetNodesForZone) == 'function' then return gm end
	return nil
end

-- The skill a spot asks for, or nil where it is not known. node: a spot of either source.
function ns.NodeSkill(node)
	local id = node.id
	if not id and type(node[3]) == 'string' then
		id = NAMES[node[3]]
		if not id then
			local gm, kind = GM(), ns.NodeKind and ns.NodeKind(node[3])
			if gm and kind and gm.GetIDForNode then
				local ok, found = pcall(gm.GetIDForNode, gm, TYPES[kind], node[3])
				if ok then id = found end
			end
		end
	end
	return id and SKILL[id] or nil
end

---------------------------------------------------------------------------
-- Reading, a continent at a time
---------------------------------------------------------------------------
local byMap = {}              -- [continent] = { [square] = { spot, ... } }, false while it has none
local count = 0

local function Square(x, y)
	return math.floor((x + 40000) / BUCKET) * 1000 + math.floor((y + 40000) / BUCKET)
end

local function Around(squares, x, y, reach, fn)
	local r = math.ceil(reach / BUCKET)
	local cx, cy = math.floor((x + 40000) / BUCKET), math.floor((y + 40000) / BUCKET)
	for i = cx - r, cx + r do
		for j = cy - r, cy + r do
			local list = squares[i * 1000 + j]
			if list then
				for _, spot in ipairs(list) do
					if (spot[1] - x) ^ 2 + (spot[2] - y) ^ 2 <= reach * reach then fn(spot) end
				end
			end
		end
	end
end

-- A zone's map (0 to 1 across and down) as a continent and a straight line to world x, y: the
-- corners asked once, every spot of the zone placed between them.
local corners = {}
local function Corners(uiMap)
	local known = corners[uiMap]
	if known ~= nil then return known end
	local WorldOf = ns.Base.Guides.WorldOf
	local m1, x0, y0 = WorldOf(uiMap, 0, 0)
	local m2, x1, y1 = WorldOf(uiMap, 1, 1)
	known = (m1 and m1 == m2 and x0 ~= x1) and { m1, x0, y0, x1 - x0, y1 - y0 } or false
	corners[uiMap] = known
	return known
end

local function Decode(coord)
	return math.floor(coord / 1000000) / 10000, math.floor(coord % 1000000 / 100) / 10000
end

-- The bundled data's tables (loading GatherMate2_Data where it is not loaded and can be).
local function DataTables()
	if not (rawget(_G, DATA.h) or rawget(_G, DATA.o)) then
		local load = C_AddOns and C_AddOns.LoadAddOn or rawget(_G, 'LoadAddOn')
		if type(load) == 'function' then pcall(load, 'GatherMate2_Data') end
	end
	return { h = rawget(_G, DATA.h), o = rawget(_G, DATA.o) }
end

local function Build(continent)
	local squares, added = {}, 0
	local function Add(kind, id, name, x, y)
		-- (one already kept here, of this kind: from the other source, or Routes' own)
		local twin = false
		Around(squares, x, y, SAME, function(spot) if spot.kind == kind then twin = true end end)
		if not twin and ns.NodesAround then
			-- (Routes' own spots come a whole square at a time: only those within SAME yards count)
			ns.NodesAround(continent, x, y, SAME, function(own)
				if (own[1] - x) ^ 2 + (own[2] - y) ^ 2 <= SAME * SAME and ns.NodeKind and ns.NodeKind(own[3]) == kind then
					twin = true
				end
			end)
		end
		if twin then return end
		local key = Square(x, y)
		squares[key] = squares[key] or {}
		table.insert(squares[key], { x, y, name, kind = kind, id = id })
		added = added + 1
	end
	local gm = GM()
	local function Name(kind, id)
		if gm and gm.GetNameForNode then
			local ok, name = pcall(gm.GetNameForNode, gm, TYPES[kind], id)
			if ok and type(name) == 'string' then return name end
		end
		for name, nid in pairs(NAMES) do if nid == id then return name end end
		return tostring(id)
	end
	local function Zone(kind, uiMap, nodes, filtered)
		local c = Corners(uiMap)
		if not (c and c[1] == continent) then return end
		local iter, state, start
		if filtered then
			local ok, a, b, d = pcall(gm.GetNodesForZone, gm, uiMap, TYPES[kind], false)
			if not ok then return end
			iter, state, start = a, b, d
		else
			iter, state, start = pairs(nodes)
		end
		for coord, id in iter, state, start do
			if type(coord) == 'number' and type(id) == 'number' then
				local u, v = Decode(coord)
				Add(kind, id, Name(kind, id), c[2] + v * c[4], c[3] + u * c[5])
			end
		end
	end
	-- (WorldOf takes the map's across and down: world x follows down, world y across; see Corners)
	for kind, tname in pairs(TYPES) do
		if gm and type(gm.gmdbs) == 'table' and gm.gmdbs[tname] then
			local base = rawget(_G, 'GatherMate2' .. (kind == 'h' and 'Herb' or 'Mine') .. 'DB')
			for uiMap in pairs(type(base) == 'table' and base or {}) do
				if type(uiMap) == 'number' then Zone(kind, uiMap, nil, true) end
			end
		end
	end
	local data = DataTables()
	for kind, tbl in pairs(data) do
		for uiMap, nodes in pairs(type(tbl) == 'table' and tbl or {}) do
			if type(uiMap) == 'number' and type(nodes) == 'table' then Zone(kind, uiMap, nodes, false) end
		end
	end
	count = count + added
	return added > 0 and squares or false
end

-- Calls fn(spot) for each of GatherMate2's spots within `reach` yards of a place on a continent.
function ns.GatherMateAround(map, x, y, reach, fn)
	if not ns.Get('gathermate') then return end
	local squares = byMap[map]
	if squares == nil then
		local ok, built = pcall(Build, map)
		squares = ok and built or false
		byMap[map] = squares
		if not ok and not ns.gmReported then
			ns.gmReported = true
			ns.Print(('GatherMate2 nodes could not be read: %s'):format(tostring(built)))
		end
	end
	if squares then Around(squares, x, y, reach, fn) end
end

-- Whether GatherMate2 or its data is there to be read.
function ns.GatherMatePresent()
	return GM() ~= nil or rawget(_G, DATA.h) ~= nil or rawget(_G, DATA.o) ~= nil
end

-- Read again at the next run (the setting changed, or GatherMate2 learned spots).
function ns.GatherMateForget()
	byMap, count = {}, 0
end

ns.OnSetting(function(key)
	if key == 'gathermate' then ns.GatherMateForget() end
end)
