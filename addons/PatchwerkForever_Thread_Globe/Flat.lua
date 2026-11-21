-- Globe (Thread): places with a flat map of their own, shown in the globe's window.
--
-- On this game the places with a map of their own that the globe does not already draw are the six
-- cities and the three battlegrounds (it has no maps of dungeons, and no floors). Such a map is the
-- game's own picture of it, laid flat in the globe's picture, with the same marks on it as on the
-- globe: the route, quests, places, flight points, your group, other addons' pins.
--
--   it opens     when the globe is opened, or Where I Am is pressed, while you are in such a place
--                (the City Maps setting); from Go To; by a click on a city that already fills the
--                picture; when the game's map is asked for one while the globe has the map key
--   it closes    by a right-click, Step Out, zooming out (wheel, key or stick), or the Globe button:
--                the globe is then turned to that place. Walking out of the place closes it too.
--
-- While it is up the globe is not turned or zoomed (ns.FlatOn), the marks are laid by ns.FlatProject,
-- and the point under the pointer is the map's (ns.FlatUnder), so the map pin, coordinates and the
-- rest work as they do on the globe. With keys or a gamepad, Next Mark steps from mark to mark.
--
-- A battleground is not part of the world the globe shows, so the marks that are places in that world
-- have nowhere to be on its map. There you and your group are drawn, and what the game says is on that
-- map itself: its places (graveyards, towers, mines), its flags and vehicles (Places.lua, which gives
-- such a mark its place on the map, not in the world: ns.FlatPoints).
local ADDON, ns = ...
if not (ns.linked and ns.Marks) then return end
local G, Marks = ns.G, ns.Marks
local Guides = ns.Base.Guides

local CITIES = { 1453, 1454, 1455, 1456, 1457, 1458 }      -- the game's own numbers for the cities' maps
local FIELDS = { 1459, 1460, 1461 }                         -- and the battlegrounds'
local VIEW, RW = G.VIEW, G.RW
local FRONT = G.EYE / (G.EYE - 1)
local FILLS = 0.96                    -- the map takes up this much of the picture
local AS_ZOOM = VIEW * 12             -- a flat map counts as the globe zoomed in this far, where its size in the world is not known
local FITTED = 0.8                    -- a city on the globe this near to filling the picture opens at a click

local flat                            -- the map shown: see Describe
local tiles, used = {}, 0             -- its pictures
local laid = {}                       -- the size it was last laid out for
local arrow, people, backButton = nil, {}, nil
local declined                        -- the map stepped out of by hand: not opened again by itself until the window closes
local since, sinceGroup = 0, 0
local isCity = {}
for _, ui in ipairs(CITIES) do isCity[ui] = true end

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

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

-- One of the game's maps as something to lay flat: its name, its pictures (in rows, tw by th each, of
-- a whole lw by lh), and where it lies in the world when that is on the globe (map: the continent;
-- wx0, wy0: its top left; wx1, wy1: its bottom right). Nil for a map with no pictures.
local function Describe(ui)
	if type(ui) ~= 'number' then return nil end
	local info = Ask(C_Map.GetMapInfo, ui)
	local layers = Ask(C_Map.GetMapArtLayers, ui)
	local layer = type(layers) == 'table' and layers[1]
	local files = Ask(C_Map.GetMapArtLayerTextures, ui, 1)
	if not (type(info) == 'table' and type(layer) == 'table' and type(files) == 'table' and #files > 0) then return nil end
	local lw, lh, tw, th = layer.layerWidth, layer.layerHeight, layer.tileWidth, layer.tileHeight
	if not (type(lw) == 'number' and type(lh) == 'number' and type(tw) == 'number' and type(th) == 'number'
		and lw > 0 and lh > 0 and tw > 0 and th > 0) then return nil end
	local d = { ui = ui, name = type(info.name) == 'string' and info.name ~= '' and info.name or 'Map',
		lw = lw, lh = lh, tw = tw, th = th, files = files }
	local map, wx0, wy0 = Guides.WorldOf(ui, 0, 0)
	local map1, wx1, wy1 = Guides.WorldOf(ui, 1, 1)
	if map and map == map1 and G.continents[map] and wx0 ~= wx1 and wy0 ~= wy1 then
		d.map, d.wx0, d.wy0, d.wx1, d.wy1 = map, wx0, wy0, wx1, wy1
	end
	return d
end

-- The flat map to show for where you are: the city you are in, or the map of a place the globe does
-- not have (a battleground). Nil out in the world.
local function Mine()
	local ui = Ask(C_Map.GetBestMapForUnit, 'player')
	if not (Plain(ui) and type(ui) == 'number') then return nil end
	if isCity[ui] or Ask(C_Map.IsCityMap, ui) == true then return ui end
	-- (a map that is not part of the globe's world; inside a dungeon the game gives the map of the zone
	-- round it, or none, and the globe stays as it is)
	local d = not G.MyPlace() and Describe(ui)
	if d and not d.map then return ui end
	return nil
end

---------------------------------------------------------------------------
-- From the world to the picture and back
---------------------------------------------------------------------------
-- A place on the flat map (0 to 1 across and down) in points from the middle of the picture.
local function Points(u, v) return (u - 0.5) * flat.w, (0.5 - v) * flat.h end

-- A direction on the sphere as a point of the picture: x, y, and whether it is on the map. Nothing for
-- a place on another continent, or while the map's place in the world is not known.
function ns.FlatProject(p)
	if not (flat and flat.map) then return nil end
	local map, wx, wy = Marks.Place(p)
	if map ~= flat.map then return nil end
	local u, v = (flat.wy0 - wy) / (flat.wy0 - flat.wy1), (flat.wx0 - wx) / (flat.wx0 - flat.wx1)
	local x, y = Points(u, v)
	return x, y, u >= 0 and u <= 1 and v >= 0 and v <= 1
end

-- A place on the map that is up (0 to 1 across and down) as a point of the picture; nil off the map.
function ns.FlatPoints(u, v)
	if not (flat and flat.w and u and v and u >= 0 and u <= 1 and v >= 0 and v <= 1) then return nil end
	return Points(u, v)
end

-- The other way: the direction on the sphere of the place at x, y of the picture; nil off the map.
function ns.FlatUnder(x, y)
	if not (flat and flat.map and flat.w) then return nil end
	local u, v = x / flat.w + 0.5, 0.5 - y / flat.h
	if u < 0 or u > 1 or v < 0 or v > 1 then return nil end
	return Marks.Where(flat.map, flat.wx0 + (flat.wx1 - flat.wx0) * v, flat.wy0 + (flat.wy1 - flat.wy0) * u)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
-- The map's pictures, laid in the middle of the picture as large as they fit.
local function Layout()
	local _, view = G.Frames()
	local vw, vh = G.Size()
	if not view then
		flat.r = AS_ZOOM
		return
	end
	laid.ui, laid.w, laid.h = flat.ui, vw, vh
	local scale = math.min(vw * FILLS / flat.lw, vh * FILLS / flat.lh)
	flat.w, flat.h = flat.lw * scale, flat.lh * scale
	flat.r = flat.map and (flat.w / math.abs(flat.wy0 - flat.wy1)) * RW / FRONT or AS_ZOOM
	local columns, rows = math.ceil(flat.lw / flat.tw), math.ceil(flat.lh / flat.th)
	local before = used
	used = 0
	for j = 1, rows do
		for i = 1, columns do
			local file = flat.files[(j - 1) * columns + i]
			local x0, y0 = (i - 1) * flat.tw, (j - 1) * flat.th
			local w, h = math.min(flat.tw, flat.lw - x0), math.min(flat.th, flat.lh - y0)
			if file and w > 0 and h > 0 then
				used = used + 1
				local t = tiles[used]
				if not t then
					t = view:CreateTexture(nil, 'BACKGROUND')
					tiles[used] = t
				end
				t:SetTexture(file)
				t:SetTexCoord(0, w / flat.tw, 0, h / flat.th)
				t:SetSize(w * scale, h * scale)
				t:ClearAllPoints()
				t:SetPoint('TOPLEFT', view, 'CENTER', -flat.w / 2 + x0 * scale, flat.h / 2 - y0 * scale)
				t:Show()
			end
		end
	end
	for i = used + 1, before do tiles[i]:Hide() end
end

-- While a flat map is up: the globe's zoom it counts as (so the marks that show by zoom do), else nil.
-- (Asked before anything of it is drawn, so this is where it is laid out, and again when the picture's
-- size has changed.)
function ns.FlatOn()
	if not flat then return nil end
	local vw, vh = G.Size()
	if laid.ui ~= flat.ui or laid.w ~= vw or laid.h ~= vh then Layout() end
	return flat.r
end
-- The map shown, for the marks that ask the game by map: its number.
function ns.FlatMap() return flat and flat.ui or nil end

local function Clear()
	for i = 1, used do tiles[i]:Hide() end
	used, laid.ui = 0, nil
	if arrow then arrow:Hide() end
	for _, t in ipairs(people) do t:Hide() end
	if backButton then backButton:Hide() end
end

-- You, where the game says you are on this map, turned the way you face.
local function PaintMe()
	if not arrow then
		local _, _, canvas = G.Frames()
		arrow = canvas:CreateTexture(nil, 'OVERLAY')
		arrow:SetDrawLayer('OVERLAY', 1)
		arrow:SetSize(28, 28)
		arrow:SetTexture('Interface\\Minimap\\MinimapArrow')
	end
	local u, v = XY(Ask(C_Map.GetPlayerMapPosition, flat.ui, 'player'))
	if not (u and u >= 0 and u <= 1 and v >= 0 and v <= 1) then
		arrow:Hide()
		return
	end
	local _, _, canvas = G.Frames()
	local x, y = Points(u, v)
	arrow:ClearAllPoints()
	arrow:SetPoint('CENTER', canvas, 'CENTER', x, y)
	local facing = GetPlayerFacing and GetPlayerFacing()
	arrow:SetRotation(Plain(facing) and type(facing) == 'number' and facing or 0)
	arrow:Show()
	flat.me = { x, y }
end

-- Your group, on a map that is not part of the globe's world (there the marks layer shows them).
local function PaintGroup()
	local n = 0
	if not flat.map and ns.Get('globePeople') and IsInGroup and IsInGroup() then
		local _, _, canvas = G.Frames()
		local raid = IsInRaid and IsInRaid() and true or false
		local most = raid and (GetNumGroupMembers and GetNumGroupMembers() or 40) or 4
		local colours = rawget(_G, 'RAID_CLASS_COLORS')
		for i = 1, most do
			local unit = (raid and 'raid' or 'party') .. i
			if UnitExists(unit) and not UnitIsUnit(unit, 'player') then
				local u, v = XY(Ask(C_Map.GetPlayerMapPosition, flat.ui, unit))
				if u and u >= 0 and u <= 1 and v >= 0 and v <= 1 then
					n = n + 1
					local t = people[n]
					if not t then
						t = canvas:CreateTexture(nil, 'OVERLAY')
						t:SetDrawLayer('OVERLAY', 0)
						t:SetSize(16, 16)
						t:SetTexture(Marks.Icon('person'))
						people[n] = t
					end
					local _, token = UnitClass(unit)
					local colour = Plain(token) and type(colours) == 'table' and colours[token]
					local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
					if Plain(dead) and dead then
						t:SetVertexColor(0.6, 0.6, 0.6, 1)
					elseif type(colour) == 'table' then
						t:SetVertexColor(colour.r, colour.g, colour.b, 1)
					else
						t:SetVertexColor(1, 1, 1, 1)
					end
					local x, y = Points(u, v)
					t:ClearAllPoints()
					t:SetPoint('CENTER', canvas, 'CENTER', x, y)
					t:Show()
				end
			end
		end
	end
	for i = n + 1, #people do people[i]:Hide() end
	flat.people = n
end

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------
local function Open(ui, auto)
	local d = Describe(ui)
	if not d then return false end
	if flat and flat.ui == ui then
		flat.auto = auto or false
		return true
	end
	d.auto = auto or false
	flat = d
	laid.ui = nil
	Marks.AllChanged()
	G.Changed()
	return true
end

-- Back to the globe, turned to where the flat map's place is (or left as it was, for a place that is
-- not on it).
local function Close(byHand)
	if not flat then return false end
	local was = flat
	flat = nil
	Clear()
	if byHand then declined = was.ui end
	if was.map then
		local mid = Marks.Where(was.map, (was.wx0 + was.wx1) / 2, (was.wy0 + was.wy1) / 2)
		local corner = Marks.Where(was.map, was.wx0, was.wy0)
		if mid and corner then
			local reach = math.acos(math.max(-1, math.min(1, G.Dot(mid, corner))))
			local look = G.look
			-- (set there outright, a little closer in, and eased out: the city's map opens out into the land)
			look.lat, look.lon = math.asin(math.max(-1, math.min(1, mid[3]))), math.atan2(mid[2], mid[1])
			look.r = G.FitRadius(reach * 0.45)
			G.GlideTo(mid, G.FitRadius(reach * 0.8))
		end
	end
	Marks.AllChanged()
	G.Changed()
	return true
end

function ns.FlatOpen(ui) return Open(ui, false) end
function ns.FlatClose() return Close(true) end
-- The flat map taken down without a word, by something that is about to turn the globe itself.
function ns.FlatLeave()
	if not flat then return end
	flat = nil
	Clear()
	Marks.AllChanged()
end

-- A press while a flat map is up that is the globe's to take: a right-click (or its like by key,
-- wheel or stick) closes the map.
function ns.FlatPress(button)
	if not flat then return false end
	if button == 'RightButton' then Close(true) end
	return true
end

-- Turn the globe to one of the game's maps (the game's map was asked for it): a city or a
-- battleground opens flat, a zone or a continent is fitted in the picture.
function ns.GlobeShowMap(ui)
	if type(ui) ~= 'number' then return false end
	if isCity[ui] or Ask(C_Map.IsCityMap, ui) == true then return Open(ui, false) end
	local info = Ask(C_Map.GetMapInfo, ui)
	local kind = type(info) == 'table' and info.mapType
	if kind == 0 or kind == 1 then
		-- (the map of the whole world, or of all the worlds: the whole globe)
		local look = G.look
		G.GlideTo({ math.cos(look.lat) * math.cos(look.lon), math.cos(look.lat) * math.sin(look.lon), math.sin(look.lat) }, G.Least())
		return true
	end
	local map, wx0, wy0 = Guides.WorldOf(ui, 0, 0)
	local map1, wx1, wy1 = Guides.WorldOf(ui, 1, 1)
	if map and map == map1 and G.continents[map] then
		local mid = Marks.Where(map, (wx0 + wx1) / 2, (wy0 + wy1) / 2)
		local corner = Marks.Where(map, wx0, wy0)
		if mid and corner then
			-- (a map's corners are well outside its land: three fifths of the way to them fills the picture)
			G.GlideTo(mid, G.FitRadius(math.acos(math.max(-1, math.min(1, G.Dot(mid, corner)))) * 0.6))
			return true
		end
		return false
	end
	return Open(ui, false)
end

-- Go To's list of flat maps (Globe.lua asks).
function ns.FlatMenu(root)
	local function List(title, maps)
		local names = {}
		for _, ui in ipairs(maps) do
			local info = Ask(C_Map.GetMapInfo, ui)
			if type(info) == 'table' and type(info.name) == 'string' and info.name ~= '' and Ask(C_Map.GetMapArtLayerTextures, ui, 1) then
				names[#names + 1] = { ui = ui, name = info.name }
			end
		end
		if #names == 0 then return end
		table.sort(names, function(a, b) return a.name < b.name end)
		local sub = root:CreateButton(title)
		for _, one in ipairs(names) do
			sub:CreateButton(one.name, function() Open(one.ui, false) end)
		end
	end
	List('City Maps', CITIES)
	List('Battleground Maps', FIELDS)
end

-- Opening the globe, or Where I Am (asked), in a place with a flat map of its own: true when its map
-- is up. Out in the world, the flat map that was opened for where you were is taken down (and Where I
-- Am takes any down).
local function Follow(asked)
	local ui = ns.Get('globeFlat') and Mine() or nil
	if not ui then
		if flat and (flat.auto or asked) then Close(false) end
		return false
	end
	if not asked and declined == ui then return false end
	if asked then declined = nil end
	return Open(ui, true)
end
ns.FlatFollow = Follow

ns.GlobeOn('show', function() ns.Try('the globe', Follow, false) end)
ns.GlobeOn('hide', function() declined = nil end)

-- Walking out of the place whose map is up (or into another such place) follows you, when the map was
-- opened for where you are.
local function Moved()
	local window = G.Frames()
	if not (window and window:IsShown() and flat and flat.auto) then return end
	local ui = Mine()
	if ui == flat.ui then return end
	if ui and ns.Get('globeFlat') then
		Open(ui, true)
	else
		Close(false)
	end
end
for _, event in ipairs({ 'ZONE_CHANGED_NEW_AREA', 'ZONE_CHANGED', 'ZONE_CHANGED_INDOORS', 'PLAYER_ENTERING_WORLD' }) do
	Marks.On(event, function() ns.Try('the globe', Moved) end)
end

-- A click on a city that already fills the picture opens its own map.
local byName
ns.GlobeOn('press', function(button, x, y, byKey)
	if flat or button ~= 'LeftButton' or (IsControlKeyDown and IsControlKeyDown()) then return false end
	local p = byKey and G.Under(0, -G.Lift()) or G.Under(x, y)
	if not p then return false end
	local c, zone = G.ZoneAt(p)
	if not zone then return false end
	if not byName then
		byName = {}
		for _, ui in ipairs(CITIES) do
			local info = Ask(C_Map.GetMapInfo, ui)
			if type(info) == 'table' and type(info.name) == 'string' then byName[info.name] = ui end
		end
	end
	local ui = byName[G.ZoneName(zone)]
	if not ui then return false end
	G.Outline(c, zone)
	if G.look.r < G.FitRadius(zone.reach) * FITTED then return false end
	return Open(ui, false)
end)

ns.GlobeOn('paint', function()
	if not flat then return end
	local _, view = G.Frames()
	local words = G.ZoneText()
	words:SetText(flat.name)
	words:Show()
	if not backButton then
		backButton = CreateFrame('Button', nil, view, 'UIPanelButtonTemplate')
		backButton:SetSize(64, 22)
		backButton:SetPoint('TOPLEFT', view, 'TOPLEFT', 8, -8)
		backButton:SetText('Globe')
		backButton:SetScript('OnClick', function() ns.Try('the globe', Close, true) end)
	end
	backButton:Show()
	PaintMe()
	PaintGroup()
end)

ns.GlobeOn('frame', function(elapsed)
	if not flat or not flat.w then return end
	since, sinceGroup = since + (elapsed or 0), sinceGroup + (elapsed or 0)
	if since >= 0.05 then
		since = 0
		PaintMe()
	end
	if sinceGroup >= 0.5 then
		sinceGroup = 0
		PaintGroup()
	end
end)

ns.OnSetting(function(key)
	if key == 'globeFlat' and not ns.Get('globeFlat') and flat and flat.auto then Close(false) end
end)

-- For the checks outside the game.
function ns.FlatState()
	if not flat then return nil end
	local shown = 0
	for i = 1, used do
		if tiles[i]:IsShown() then shown = shown + 1 end
	end
	return { ui = flat.ui, name = flat.name, map = flat.map, w = flat.w, h = flat.h, r = flat.r, tiles = shown, auto = flat.auto,
		me = arrow and arrow:IsShown() and flat.me or nil, people = flat.people or 0, back = backButton and backButton:IsShown() or false }
end
