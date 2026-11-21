-- Routes (Thread): herbs and ore.
--
-- Remembers each spot where you pick a herb or mine a vein, and shows the spots on the minimap and
-- the world map with the icon of what you got there. Herbs and veins come back in the same places,
-- so the maps fill in as you play; the spots are kept for all your characters.
--
-- It shows where things grow, not whether one is there now: the game does not tell an addon where
-- the dots of Find Herbs and Find Minerals are, and reading them off the minimap means moving the
-- minimap about under the mouse, which this addon will not do.
--
-- How a spot is noticed: you start a cast aimed at something that is not a creature (the game gives
-- its name, "Peacebloom", "Copper Vein"), and within a few seconds loot opens holding a herb or an
-- ore. The spot is where you stood when the cast began.
--
-- Saved in PatchwerkForever_Thread_RoutesDB: nodes = { [map] = { { x, y, name }, ... } } in world coordinates, and
-- nodeKinds = { [name] = { icon =, kind = 'h' or 'o' } }.
local ADDON, ns = ...
if not ns.linked then return end

local WINDOW = 12             -- seconds from starting to gather to the loot showing, at most
local SAME = 12               -- yards within which two spots of one name are one spot
local FORGET = 15             -- yards round you that /thread nodes forget clears
local BUCKET = 250            -- yards a side of the squares the spots are sorted into
local TRADE, HERB, STONE = 7, 9, 7     -- the item class Trade Goods, and in it Herb, and Metal & Stone
local MINI_SIZE, MINI_MOST = 14, 60
local MAP_SIZE, MAP_MOST = 14, 500

local db
local buckets = {}            -- [map] = { [square] = { node, ... } }

local function Square(x, y)
	return math.floor((x + 40000) / BUCKET) * 1000 + math.floor((y + 40000) / BUCKET)
end

local function Sort(map, node)
	local squares = buckets[map]
	if not squares then squares = {}; buckets[map] = squares end
	local key = Square(node[1], node[2])
	local list = squares[key]
	if not list then list = {}; squares[key] = list end
	list[#list + 1] = node
end

local function SortAll()
	buckets = {}
	for map, list in pairs(db.nodes) do
		for _, node in ipairs(list) do Sort(map, node) end
	end
end

-- Calls fn(node) for each spot in the squares within `reach` yards of a place.
local function Around(map, x, y, reach, fn)
	local squares = buckets[map]
	if not squares then return end
	local span = math.ceil(reach / BUCKET)
	local cx, cy = math.floor((x + 40000) / BUCKET), math.floor((y + 40000) / BUCKET)
	for sx = cx - span, cx + span do
		for sy = cy - span, cy + span do
			local list = squares[sx * 1000 + sy]
			if list then
				for i = 1, #list do fn(list[i]) end
			end
		end
	end
end

local function Count()
	local herbs, ore, here = 0, 0, 0
	local _, _, map = ns.Place()
	for m, list in pairs(db.nodes) do
		for _, node in ipairs(list) do
			local kind = db.nodeKinds[node[3]]
			if kind and kind.kind == 'h' then herbs = herbs + 1 else ore = ore + 1 end
		end
		if m == map then here = #list end
	end
	return herbs, ore, here
end

---------------------------------------------------------------------------
-- Noticing a spot
---------------------------------------------------------------------------
local pending
local Watch                   -- (below) starts or stops the minimap's redraws, and has it drawn anew

local function Remember(p, kind, icon)
	if not db.nodeKinds[p.name] then
		db.nodeKinds[p.name] = { icon = icon, kind = kind }
	end
	local known = false
	Around(p.map, p.x, p.y, SAME, function(node)
		if node[3] == p.name and (node[1] - p.x) ^ 2 + (node[2] - p.y) ^ 2 <= SAME * SAME then known = true end
	end)
	if known then return end
	local list = db.nodes[p.map]
	if not list then list = {}; db.nodes[p.map] = list end
	local node = { math.floor(p.x * 10 + 0.5) / 10, math.floor(p.y * 10 + 0.5) / 10, p.name }
	list[#list + 1] = node
	Sort(p.map, node)
	if not db.nodesTold then
		db.nodesTold = true
		ns.Print('Recorded your first gathering node (' .. p.name .. '). Nodes are shown on the minimap and world map; /thread nodes counts them.')
	end
	Watch()
	if ns.RedrawWorldMap then ns.RedrawWorldMap() end
end

-- True unless the game says this loot came from a creature (a herb or a stone off a corpse is not a spot).
local function FromObject(slot)
	if not GetLootSourceInfo then return true end
	local guid = GetLootSourceInfo(slot)
	if type(guid) ~= 'string' or (issecretvalue and issecretvalue(guid)) then return true end
	return guid:sub(1, 10) == 'GameObject'
end

local function Loot()
	local p = pending
	if not p then return end
	pending = nil
	if GetTime() - p.time > WINDOW then return end
	local instant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
	if not (instant and GetNumLootItems and GetLootSlotLink) then return end
	for slot = 1, GetNumLootItems() do
		local link = GetLootSlotLink(slot)
		if link then
			local _, _, _, _, icon, class, sub = instant(link)
			if class == TRADE and (sub == HERB or sub == STONE) then
				if FromObject(slot) then Remember(p, sub == HERB and 'h' or 'o', icon) end
				return
			end
		end
	end
end

ns.On('UNIT_SPELLCAST_SENT', function(unit, target)
	if unit ~= 'player' or not ns.Get('nodes') then return end
	pending = nil
	if issecretvalue and issecretvalue(target) then return end
	if type(target) ~= 'string' or target == '' then return end
	if target == UnitName('player') or target == UnitName('target') then return end     -- aimed at a creature
	local x, y, map = ns.Place()
	if not x then return end
	pending = { name = target, x = x, y = y, map = map, time = GetTime() }
end)
ns.On('LOOT_READY', Loot)
ns.On('LOOT_OPENED', Loot)

---------------------------------------------------------------------------
-- On the minimap
---------------------------------------------------------------------------
local mini, miniIcons, miniShown = nil, {}, 0
local near, nearX, nearY, nearMap, nearTime = {}, nil, nil, nil, 0

local function Icon(pool, n, parent, size)
	local icon = pool[n]
	if not icon then
		icon = parent:CreateTexture(nil, 'ARTWORK')
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		pool[n] = icon
	end
	icon:SetSize(size, size)
	return icon
end

-- Returns true when there was a minimap to draw on (so the layer stays up).
local function MiniDraw()
	for i = 1, miniShown do miniIcons[i]:Hide() end
	miniShown = 0
	if not ns.Get('nodesMinimap') then return end
	if not mini then mini = ns.MinimapLayer() end
	local px, py, map, perYard, sin, cos, radius = ns.MinimapView(mini, 6)
	if not px then return end
	if not buckets[map] then return true end
	local view = radius / perYard
	-- the spots near enough to matter, looked up again after 20 yards or half a second
	local time = GetTime()
	if map ~= nearMap or time - nearTime > 0.5 or (px - nearX) ^ 2 + (py - nearY) ^ 2 > 400 then
		near, nearX, nearY, nearMap, nearTime = {}, px, py, map, time
		Around(map, px, py, view * 1.5 + 30, function(node) near[#near + 1] = node end)
	end
	local square = GetMinimapShape and GetMinimapShape() == 'SQUARE'
	local edge = radius - MINI_SIZE / 2
	for i = 1, #near do
		if miniShown >= MINI_MOST then break end
		local node = near[i]
		local east, north = (py - node[2]) * perYard, (node[1] - px) * perYard
		local x, y = east * cos + north * sin, north * cos - east * sin
		local inside
		if square then
			inside = math.abs(x) <= edge and math.abs(y) <= edge
		else
			inside = x * x + y * y <= edge * edge
		end
		local kind = db.nodeKinds[node[3]]
		if inside and kind then
			miniShown = miniShown + 1
			local icon = Icon(miniIcons, miniShown, mini, MINI_SIZE)
			if icon.shows ~= kind.icon then
				icon.shows = kind.icon
				icon:SetTexture(kind.icon)
			end
			icon:ClearAllPoints()
			icon:SetPoint('CENTER', mini, 'CENTER', x, y)
			icon:Show()
		end
	end
	return true
end

-- (drawn again when something it shows may have changed, as the trail is: Minimap.lua)
local redraws = ns.MinimapRedraws('the minimap spots', function()
	if not MiniDraw() and mini then mini:Hide() end
end)
function Watch()
	local want = db and next(db.nodes) ~= nil and ns.Get('nodesMinimap')
	nearMap = nil                     -- (the nodes near you are looked up again: one may have been added)
	redraws.Dirty()
	redraws.On(want)
	if not want then
		for i = 1, miniShown do miniIcons[i]:Hide() end
		miniShown = 0
		if mini then mini:Hide() end
	end
end

---------------------------------------------------------------------------
-- On the world map (a zone's map; a whole continent would be a smear of icons)
---------------------------------------------------------------------------
local layer, mapIcons, mapShown = nil, {}, 0

local function MapDraw(letGo)
	for i = 1, mapShown do mapIcons[i]:Hide() end
	mapShown = 0
	if letGo or not (db and ns.Get('nodesWorldMap')) then return end
	local view = ns.WorldMapView()
	if not (view and view.zone) then return end
	local list = db.nodes[view.map]
	if not list then return end
	if not layer then
		layer = CreateFrame('Frame', nil, view.canvas)
		layer:SetAllPoints(view.canvas)
	end
	layer:SetFrameLevel(math.max(1, view.level - 1))
	local size = MAP_SIZE / view.scale
	for i = 1, #list do
		if mapShown >= MAP_MOST then break end
		local node = list[i]
		local u, v = view.at(node[1], node[2])
		local kind = db.nodeKinds[node[3]]
		if kind and u >= 0 and u <= 1 and v >= 0 and v <= 1 then
			mapShown = mapShown + 1
			local icon = Icon(mapIcons, mapShown, layer, size)
			if icon.shows ~= kind.icon then
				icon.shows = kind.icon
				icon:SetTexture(kind.icon)
			end
			icon:ClearAllPoints()
			icon:SetPoint('CENTER', layer, 'TOPLEFT', u * view.width, -v * view.height)
			icon:Show()
		end
	end
end

---------------------------------------------------------------------------
-- Commands and settings
---------------------------------------------------------------------------
function ns.NodesSay()
	local herbs, ore, here = Count()
	ns.Print(('%d herb nodes and %d ore nodes recorded, %d on this map.'):format(herbs, ore, here))
	if not ns.Get('nodes') then ns.Print('Recording new nodes is disabled in the options.') end
end

function ns.NodesForget()
	local px, py, map = ns.Place()
	local list = px and db.nodes[map]
	local gone = 0
	if list then
		for i = #list, 1, -1 do
			if (list[i][1] - px) ^ 2 + (list[i][2] - py) ^ 2 <= FORGET * FORGET then
				table.remove(list, i)
				gone = gone + 1
			end
		end
	end
	if gone > 0 then
		SortAll()
		Watch()
		if ns.RedrawWorldMap then ns.RedrawWorldMap() end
	end
	ns.Print(('%d %s within %d yards deleted.'):format(gone, gone == 1 and 'node' or 'nodes', FORGET))
end

ns.On('ADDON_LOADED', function(name)
	if name ~= ADDON then return end
	db = PatchwerkForever_Thread_RoutesDB
	db.nodes = db.nodes or {}
	db.nodeKinds = db.nodeKinds or {}
	SortAll()
end)
ns.On('PLAYER_LOGIN', function()
	Watch()
	if ns.OnWorldMapDraw then ns.OnWorldMapDraw(MapDraw) end
end)
ns.OnSetting(function(key)
	if key == 'nodesMinimap' then
		Watch()
	elseif key == 'nodesWorldMap' and ns.RedrawWorldMap then
		ns.RedrawWorldMap()
	end
end)

---------------------------------------------------------------------------
-- For gathering runs (Gather.lua)
---------------------------------------------------------------------------
-- Calls fn(spot) for each remembered spot within `reach` yards of a place; a spot is { x, y, name }.
function ns.NodesAround(map, x, y, reach, fn)
	if db then Around(map, x, y, reach, fn) end
end

-- What grows at spots of this name: 'h' for a herb, 'o' for ore; nothing when it is not known.
function ns.NodeKind(name)
	local kind = db and db.nodeKinds and db.nodeKinds[name]
	return kind and kind.kind or nil
end

-- The icon of what was got at spots of this name.
function ns.NodeIcon(name)
	local kind = db and db.nodeKinds and db.nodeKinds[name]
	return kind and kind.icon or nil
end
