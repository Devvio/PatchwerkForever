-- Thread (Routes): the focus and My Route on the world map.
--
-- A button at the map's top right opens a menu: the focuses that can be chosen (the one in use
-- checked), Edit My Route (Thread (Tracker)'s editor, opened beside the map) and Add Map Pin To My
-- Route. While My Route is followed (your focus, or the list you selected) its stops are marked on the
-- map, numbered in the list's order; a right-click on a mark offers Go Here First, Move Earlier, Move
-- Later and Remove, and a left-click goes there first.
--
-- The button is a child of the map's own border frame, never one of the map's "overlay frames"
-- (WorldMapFrame:AddOverlayFrame): those are walked through by the map's secure code, and a frame of
-- an addon's among them can get the game's "action blocked" errors. The marks are drawn in the same
-- layer as the trail (WorldMap.lua), each time the map is redrawn.
local ADDON, ns = ...
if not ns.linked then return end

local SIZE = 20           -- a mark's size on the screen, in pixels
local MOST = 60           -- marks at most

local Base = ns.Base
local Guides = Base.Guides

local function MyRoute() return Base.MyRoute end

-- A menu at the mouse, made with the game's own menus (as Thread (Tracker)'s right-click menus are).
-- build(root) adds the entries. Returns false when this client has none.
local toldNoMenu
local function Menu(owner, build)
	local util = rawget(_G, 'MenuUtil')
	if not (type(util) == 'table' and type(util.CreateContextMenu) == 'function') then
		if not toldNoMenu then
			toldNoMenu = true
			ns.Print('Right-click menus are not available on this client.')
		end
		return false
	end
	util.CreateContextMenu(owner, function(_, root) ns.Try('the world map menu', build, root) end)
	return true
end

-- A plain button in a menu: fn runs as a choice in the menu, its errors said once.
local function Entry(root, label, fn)
	return root:CreateButton(label, function() ns.Try('the menu (' .. label .. ')', fn) end)
end

-- Whether My Route is what the route follows now: your focus, or the list you selected.
local function Followed()
	if ns.FocusGet() == 'route' then return true end
	local choice = Base.Choice and Base.Choice:Get()
	return choice ~= nil and choice.kind == 'guide' and choice.id == 'route'
end

---------------------------------------------------------------------------
-- What the menus do
---------------------------------------------------------------------------
local function Changed()
	if ns.LookNow then ns.LookNow() end
	if ns.RedrawWorldMap then ns.RedrawWorldMap() end
end

-- Has the stop at `index` of My Route's list lead, for this session (the list's order is kept).
function ns.RouteGoFirst(index)
	local list = MyRoute()
	if list and list.Lead then list:Lead(index) end
	Changed()
end

-- Thread (Tracker)'s editor for My Route, beside anchor (the world map).
function ns.RouteEdit(anchor)
	local open = rawget(_G, 'PatchwerkForever_Thread_Tracker_OpenMyRoute')
	if type(open) == 'function' then
		open(anchor)
	else
		ns.Print('Editing My Route needs Thread (Tracker), which is not running.')
	end
end

-- Your map pin, as a stop at the end of My Route.
function ns.RouteAddPin()
	local list = MyRoute()
	if not list then return end
	local pin = C_Map and ns.Ask(C_Map.GetUserWaypoint)
	if not (type(pin) == 'table' and pin.uiMapID and pin.position) then
		ns.Print('Place a map pin first.')
		return
	end
	local px, py = pin.position.x, pin.position.y
	if type(pin.position.GetXY) == 'function' then px, py = pin.position:GetXY() end
	local map, x, y = Guides.WorldOf(pin.uiMapID, px, py)
	if not map then
		ns.Print('Your map pin is not on a map the route can use.')
		return
	end
	local zone = Guides.ZoneName and Guides.ZoneName(pin.uiMapID) or nil
	if list:Add({ kind = 'spot', map = map, x = x, y = y, label = 'Map pin', zone = zone }) then
		ns.Print('Map pin added to My Route.')
	else
		ns.Print('Your map pin is already in My Route.')
	end
end

---------------------------------------------------------------------------
-- The focus button
---------------------------------------------------------------------------
local button

local function FocusMenu(root)
	root:CreateTitle('Route Focus')
	for _, one in ipairs(ns.FocusList()) do
		root:CreateRadio(one.name,
			function(id) return ns.FocusGet() == id end,
			function(id) ns.Try('the menu (focus)', ns.FocusTo, id) end,
			one.id)
	end
	if root.CreateDivider then root:CreateDivider() end
	Entry(root, 'Edit My Route', function() ns.RouteEdit(WorldMapFrame) end)
	Entry(root, 'Add Map Pin To My Route', ns.RouteAddPin)
end

local function Tip(self)
	local tip = rawget(_G, 'GameTooltip')
	if not (type(tip) == 'table' and tip.SetOwner) then return end
	tip:SetOwner(self, 'ANCHOR_LEFT')
	tip:SetText('Route Focus')
	tip:AddLine(('Following: %s'):format(ns.FocusName(ns.FocusGet())), 1, 1, 1)
	tip:AddLine('Click to choose what the route follows.', 0.8, 0.8, 0.8, true)
	tip:Show()
end

local function Untip()
	local tip = rawget(_G, 'GameTooltip')
	if type(tip) == 'table' and tip.Hide then tip:Hide() end
end

local function ShowButton()
	if button then button:SetShown(ns.Get('focusButton') and true or false) end
end

-- Made once the map is there: on the map's border frame, at the top right of the map's picture.
local function MakeButton()
	local map = rawget(_G, 'WorldMapFrame')
	if button or type(map) ~= 'table' then return end
	local parent = map.BorderFrame or map.ScrollContainer or map
	local corner = map.ScrollContainer or map
	button = CreateFrame('Button', nil, parent)
	button:SetSize(30, 30)
	-- (left of the map's own two buttons at its top right, the filter and the pin, at -4 and -36)
	button:SetPoint('TOPRIGHT', corner, 'TOPRIGHT', -68, -2)
	if button.SetFrameStrata then button:SetFrameStrata('HIGH') end
	if parent.GetFrameLevel then button:SetFrameLevel(parent:GetFrameLevel() + 10) end
	local back = button:CreateTexture(nil, 'BACKGROUND')
	back:SetAllPoints(button)
	-- (the look of the map's own buttons beside it, where the client has it; else a plain dark square)
	if not (back.SetAtlas and pcall(back.SetAtlas, back, 'common-dropdown-a-button')) then
		back:SetColorTexture(0, 0, 0, 0.6)
	end
	local icon = button:CreateTexture(nil, 'ARTWORK')
	icon:SetSize(18, 18)
	icon:SetPoint('CENTER', button, 'CENTER', 0, 0)
	icon:SetTexture(ns.MEDIA .. 'icon')
	button.icon = icon
	if button.RegisterForClicks then button:RegisterForClicks('LeftButtonUp', 'RightButtonUp') end
	button:SetScript('OnClick', function(self) Menu(self, FocusMenu) end)
	button:SetScript('OnEnter', Tip)
	button:SetScript('OnLeave', Untip)
	ShowButton()
end

-- (for the checks: the button, and what its menu offers)
function ns.MapFocusButton() return button end

---------------------------------------------------------------------------
-- My Route's stops, numbered
---------------------------------------------------------------------------
local layer, marks, shown = nil, {}, 0

local function MarkMenu(mark)
	local list = MyRoute()
	if not list then return end
	local index = mark.index
	local count = #list:Entries()
	Menu(mark, function(root)
		root:CreateTitle(('%d. %s'):format(index, tostring(mark.name)))
		Entry(root, 'Go Here First', function() ns.RouteGoFirst(index) end)
		if index > 1 then Entry(root, 'Move Earlier', function() list:Move(index, index - 1) end) end
		if index < count then Entry(root, 'Move Later', function() list:Move(index, index + 1) end) end
		Entry(root, 'Remove', function() list:Remove(index) end)
	end)
end

local function MarkTip(self)
	local tip = rawget(_G, 'GameTooltip')
	if not (type(tip) == 'table' and tip.SetOwner) then return end
	tip:SetOwner(self, 'ANCHOR_RIGHT')
	tip:SetText(('%d. %s'):format(self.index, tostring(self.name)))
	tip:AddLine('My Route. Click to go here first; right-click for more.', 0.8, 0.8, 0.8, true)
	tip:Show()
end

local function Mark(i)
	local mark = marks[i]
	if mark then return mark end
	mark = CreateFrame('Button', nil, layer)
	mark:SetSize(SIZE, SIZE)
	local edge = mark:CreateTexture(nil, 'ARTWORK')
	edge:SetAllPoints(mark)
	edge:SetTexture(ns.MEDIA .. 'dot')
	edge:SetVertexColor(0.1, 0.07, 0.02)
	local disc = mark:CreateTexture(nil, 'OVERLAY')
	disc:SetSize(SIZE - 4, SIZE - 4)
	disc:SetPoint('CENTER', mark, 'CENTER', 0, 0)
	disc:SetTexture(ns.MEDIA .. 'dot')
	disc:SetVertexColor(1, 0.82, 0.1)
	local number = mark:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	number:SetPoint('CENTER', mark, 'CENTER', 0, 0)
	ns.Font(number, 11, 'OUTLINE')
	number:SetTextColor(1, 1, 1)
	mark.number = number
	if mark.RegisterForClicks then mark:RegisterForClicks('LeftButtonUp', 'RightButtonUp') end
	mark:SetScript('OnClick', function(self, which)
		if which == 'RightButton' then
			MarkMenu(self)
		else
			ns.Try('going to a stop first', ns.RouteGoFirst, self.index)
		end
	end)
	mark:SetScript('OnEnter', MarkTip)
	mark:SetScript('OnLeave', Untip)
	marks[i] = mark
	return mark
end

local function MarksDraw(letGo)
	for i = 1, shown do marks[i]:Hide() end
	shown = 0
	local list = MyRoute()
	if letGo or not (list and ns.Get('myRouteMap') and Followed()) then return end
	local view = ns.WorldMapView()
	if not view then return end
	if not layer then
		layer = CreateFrame('Frame', nil, view.canvas)
		layer:SetAllPoints(view.canvas)
	end
	layer:SetFrameLevel(view.level + 5)
	for _, stop in ipairs(list:Entries()) do
		if shown >= MOST then break end
		if stop.map == view.map and stop.x and stop.y then
			local u, v = view.at(stop.x, stop.y)
			if u >= 0 and u <= 1 and v >= 0 and v <= 1 then
				shown = shown + 1
				local mark = Mark(shown)
				mark.index, mark.name = stop.index, stop.name
				mark.number:SetText(tostring(stop.index))
				-- (kept the same size on the screen however far the map is zoomed: the canvas is scaled,
				-- and a frame's offsets are in its own scale, as the map's own pins are placed)
				mark:SetScale(1 / view.scale)
				mark:ClearAllPoints()
				mark:SetPoint('CENTER', layer, 'TOPLEFT', u * view.width * view.scale, -v * view.height * view.scale)
				mark:Show()
			end
		end
	end
end

-- (for the checks: the marks shown now, each { index =, name = }, and a mark itself)
function ns.RouteMarks()
	local out = {}
	for i = 1, shown do out[i] = marks[i] end
	return out
end

ns.On('PLAYER_LOGIN', function()
	ns.Try('the world map focus button', MakeButton)
	ShowButton()
	if ns.OnWorldMapDraw then ns.OnWorldMapDraw(MarksDraw) end
end)
-- (in case the map is loaded after login)
ns.On('ADDON_LOADED', function(name)
	if name == 'Blizzard_WorldMap' then ns.Try('the world map focus button', MakeButton) end
end)
ns.OnSetting(function(key)
	if key == 'focusButton' then
		ShowButton()
	elseif key == 'myRouteMap' and ns.RedrawWorldMap then
		ns.RedrawWorldMap()
	end
end)
