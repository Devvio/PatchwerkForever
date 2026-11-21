-- Tracker (Thread): the My Route window, for putting your stops in order.
--
-- A small window in the tracker's look: the stops numbered, each with a grip to drag it by, its name,
-- the zone of a quest, how far it is and a cross to take it out; at its foot Order For Me, Add Tracked
-- Quests, Clear and Close. Drag a row to another place (Drag.lua); click a row to select it for the
-- Move My Route Stop Up and Down bindings; right-click a row for its menu (as in the tracker's
-- section). It follows the list as it changes, from any addon, and keeps where you drag it (the
-- tracker's saved table: routePlace). Escape closes it.
--
-- It is opened from the My Route heading's menu, with /tracker route, the Open My Route binding, or
-- from another addon with
--     PatchwerkForever_Thread_Tracker_OpenMyRoute(anchorFrame)
-- which opens it, or closes it when open; given a frame (the world map), it opens beside that frame
-- instead of where you left it. Nothing in it is of the game's secure kind: it works in a fight.
local ADDON, ns = ...
if not ns.linked then return end

local NAME = 'PatchwerkForeverTrackerRoute'
local WIDTH = 350
local ROW = 22                -- a row's height
local MOST = 14               -- rows shown at once; more scroll with the mouse wheel
local TOP, FOOT = 30, 34      -- the title's room and the footer's

local win
local rows = {}
local offset = 0              -- how many rows are scrolled past

local function MyRoute() return ns.Base.MyRoute end

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

-- The zone a quest is done in, from the map the game would open for it; nothing when it will not say.
local function Zone(one)
	if one.kind ~= 'quest' then return nil end
	local uiMap = Ask(rawget(_G, 'GetQuestUiMapID'), one.id)
	if type(uiMap) ~= 'number' or uiMap == 0 then return nil end
	local info = C_Map and Ask(C_Map.GetMapInfo, uiMap)
	return type(info) == 'table' and type(info.name) == 'string' and info.name or nil
end

local function Place()
	local place = ns.Saved().routePlace
	win:ClearAllPoints()
	if type(place) == 'table' and place[1] then
		win:SetPoint(place[1], UIParent, place[2] or place[1], place[3] or 0, place[4] or 0)
	else
		win:SetPoint('CENTER', UIParent, 'CENTER', 0, 60)
	end
end

-- Beside another frame (the world map): on its right where the screen has room, else inside its right edge.
local function Beside(anchor)
	win:ClearAllPoints()
	local right = type(anchor.GetRight) == 'function' and anchor:GetRight() or nil
	local scale = (type(anchor.GetEffectiveScale) == 'function' and anchor:GetEffectiveScale() or 1) / UIParent:GetEffectiveScale()
	local wide = UIParent:GetWidth()
	if right and wide and right * scale + WIDTH + 8 <= wide then
		win:SetPoint('TOPLEFT', anchor, 'TOPRIGHT', 6, 0)
	else
		win:SetPoint('TOPRIGHT', anchor, 'TOPRIGHT', -12, -70)
	end
end

-- The rows shown now, for a drag to land among.
local function Shown()
	local out = {}
	for _, row in ipairs(rows) do
		if row:IsShown() and row.entry then out[#out + 1] = { frame = row, index = row.entry.index } end
	end
	return out
end

local Fill

local function Row(i)
	local row = CreateFrame('Button', nil, win)
	row:SetSize(WIDTH - 16, ROW)
	row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	row:RegisterForDrag('LeftButton')
	row.over = row:CreateTexture(nil, 'BACKGROUND')
	row.over:SetAllPoints(row)
	row.over:SetColorTexture(1, 1, 1, 0.07)
	row.over:Hide()
	row.picked = row:CreateTexture(nil, 'BACKGROUND')
	row.picked:SetAllPoints(row)
	row.picked:SetColorTexture(1, 0.82, 0, 0.12)
	row.picked:Hide()
	-- the grip: three short lines
	row.grip = {}
	for n = 1, 3 do
		local g = row:CreateTexture(nil, 'ARTWORK')
		g:SetColorTexture(0.6, 0.6, 0.6, 0.8)
		g:SetSize(8, 1)
		g:SetPoint('LEFT', row, 'LEFT', 2, 4 - (n - 1) * 4)
		row.grip[n] = g
	end
	row.name = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	row.name:SetPoint('LEFT', row, 'LEFT', 16, 0)
	row.name:SetJustifyH('LEFT')
	row.name:SetWordWrap(false)
	row.far = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	row.far:SetPoint('RIGHT', row, 'RIGHT', -22, 0)
	row.far:SetJustifyH('RIGHT')
	row.far:SetWordWrap(false)
	row.cross = CreateFrame('Button', nil, row)
	row.cross:SetSize(16, 16)
	row.cross:SetPoint('RIGHT', row, 'RIGHT', -2, 0)
	row.cross.tex = row.cross:CreateTexture(nil, 'ARTWORK')
	row.cross.tex:SetAllPoints(row.cross)
	row.cross.tex:SetTexture('Interface\\Buttons\\UI-GroupLoot-Pass-Up')
	row.cross:SetScript('OnClick', function(self)
		local entry = self:GetParent().entry
		if entry then ns.Try('My Route', ns.RouteRemove, entry.key) end
	end)
	row:SetScript('OnClick', function(self, button)
		-- (the button let go at the end of a drag is not also a click, whichever the game sends first)
		if ns.Dragging() or ns.DragJustEnded() or not self.entry then return end
		local entry = self.entry
		if button == 'RightButton' then
			ns.Try('My Route', ns.RouteRowMenu, self, entry.index)
		else
			ns.Try('My Route', ns.RouteSelect, entry.key)
		end
		Fill()
	end)
	row:SetScript('OnDragStart', function(self)
		local entry = self.entry
		if not entry then return end
		ns.RouteSelect(entry.key)
		ns.Try('dragging', ns.DragBegin, self, { from = entry.index, key = entry.key, text = self.name:GetText(), rows = Shown })
	end)
	row:SetScript('OnDragStop', function() ns.Try('dragging', ns.DragStop) end)
	row:SetScript('OnMouseUp', function(_, button)
		if button == 'LeftButton' and ns.Dragging() then ns.Try('dragging', ns.DragStop) end
	end)
	row:SetScript('OnEnter', function(self) self.over:Show() end)
	row:SetScript('OnLeave', function(self) self.over:Hide() end)
	rows[i] = row
	return row
end

-- A button of the footer, in the game's own look.
local function FootButton(text, wide, fn)
	local ok, b = pcall(CreateFrame, 'Button', nil, win, 'UIPanelButtonTemplate')
	if not ok then b = CreateFrame('Button', nil, win) end
	b:SetSize(wide, 22)
	b:SetText(text)
	b:SetScript('OnClick', function() ns.Try('My Route (' .. text .. ')', fn) end)
	return b
end

local function Make()
	win = CreateFrame('Frame', NAME, UIParent)
	win:SetFrameStrata('DIALOG')
	win:SetClampedToScreen(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:SetSize(WIDTH, 200)
	win:Hide()
	local back = win:CreateTexture(nil, 'BACKGROUND')
	back:SetAllPoints(win)
	back:SetColorTexture(0, 0, 0, 0.85)
	-- a thin edge in the header color at its top and its foot
	local hr, hg, hb = ns.RGB(ns.Get('lookHeader'))
	for _, side in ipairs({ 'TOP', 'BOTTOM' }) do
		local e = win:CreateTexture(nil, 'BORDER')
		e:SetPoint(side .. 'LEFT', win, side .. 'LEFT', 0, 0)
		e:SetPoint(side .. 'RIGHT', win, side .. 'RIGHT', 0, 0)
		e:SetHeight(1)
		e:SetColorTexture(hr, hg, hb, 0.8)
	end
	-- the title bar, to drag the window by
	local bar = CreateFrame('Frame', nil, win)
	bar:SetPoint('TOPLEFT', win, 'TOPLEFT', 0, 0)
	bar:SetPoint('TOPRIGHT', win, 'TOPRIGHT', 0, 0)
	bar:SetHeight(TOP - 4)
	bar:EnableMouse(true)
	bar:RegisterForDrag('LeftButton')
	bar:SetScript('OnDragStart', function() win:StartMoving() end)
	bar:SetScript('OnDragStop', function()
		win:StopMovingOrSizing()
		local point, _, relative, x, y = win:GetPoint(1)
		if point then ns.Saved().routePlace = { point, relative or point, x or 0, y or 0 } end
	end)
	win.bar = bar
	win.title = win:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	win.title:SetPoint('TOPLEFT', win, 'TOPLEFT', 10, -8)
	win.title:SetJustifyH('LEFT')
	ns.Font(win.title, 13)
	win.title:SetText('My Route')
	win.title:SetTextColor(hr, hg, hb)
	win.note = win:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	win.note:SetPoint('TOPRIGHT', win, 'TOPRIGHT', -30, -9)
	win.note:SetJustifyH('RIGHT')
	ns.Font(win.note, 11)
	local ok, close = pcall(CreateFrame, 'Button', nil, win, 'UIPanelCloseButton')
	if not ok then close = CreateFrame('Button', nil, win) end
	close:SetSize(24, 24)
	close:SetPoint('TOPRIGHT', win, 'TOPRIGHT', -2, -2)
	close:SetScript('OnClick', function() win:Hide() end)
	win.close = close
	win.empty = win:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	win.empty:SetPoint('TOPLEFT', win, 'TOPLEFT', 12, -TOP - 4)
	win.empty:SetJustifyH('LEFT')
	win.empty:SetWidth(WIDTH - 24)
	ns.Font(win.empty, 12)
	win.empty:SetTextColor(0.7, 0.7, 0.7)
	win.empty:SetText('No stops yet. Right-click a quest in the tracker and choose Add To My Route, or add your tracked quests below.')
	win.foot = {
		FootButton('Order For Me', 96, ns.RouteOrder),
		FootButton('Add Tracked Quests', 128, ns.RouteAddTracked),
		FootButton('Clear', 54, ns.RouteClear),
		FootButton('Close', 54, function() win:Hide() end),
	}
	local x = 8
	for _, b in ipairs(win.foot) do
		b:SetPoint('BOTTOMLEFT', win, 'BOTTOMLEFT', x, 8)
		x = x + (b:GetWidth() or 60) + 2
	end
	win:EnableMouseWheel(true)
	win:SetScript('OnMouseWheel', function(_, delta)
		offset = offset - delta
		Fill()
	end)
	win:SetScript('OnHide', function() if ns.Dragging() then ns.DragCancel() end end)
	-- (Escape closes it, as it closes the game's own windows)
	local special = rawget(_G, 'UISpecialFrames')
	if type(special) == 'table' then table.insert(special, NAME) end
	Place()
end

function Fill()
	if not (win and win:IsShown()) then return end
	local entries = MyRoute():Entries()
	local n = #entries
	offset = math.max(0, math.min(offset, n - MOST))
	local picked = ns.RouteSelected()
	local size = 12
	local shown = math.min(MOST, n - offset)
	for i = 1, shown do
		local one = entries[offset + i]
		local row = rows[i] or Row(i)
		row.entry = one
		local r, g, b = ns.RouteColour(one.state)
		local zone = Zone(one)
		local word = ns.RouteWord(one.state)
		ns.Font(row.name, size)
		ns.Font(row.far, size - 1)
		row.name:SetWidth(WIDTH - 16 - 16 - 80)
		row.name:SetText(('%d. %s'):format(one.index, one.name)
			.. ((zone or word ~= '') and ('  |cff999999' .. (zone or word) .. '|r') or ''))
		row.name:SetTextColor(r, g, b)
		row.far:SetText(ns.YardsText(ns.RouteYards(one.map, one.x, one.y)) or '')
		row.far:SetTextColor(0.7, 0.7, 0.7)
		if picked and picked == one.key then row.picked:Show() else row.picked:Hide() end
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', win, 'TOPLEFT', 8, -TOP - (i - 1) * ROW)
		row:Show()
	end
	for i = shown + 1, #rows do
		rows[i]:Hide()
		rows[i].entry = nil
	end
	if n == 0 then win.empty:Show() else win.empty:Hide() end
	local note = ('%d %s'):format(n, n == 1 and 'stop' or 'stops')
	if n > MOST then note = ('%d-%d of %d'):format(offset + 1, offset + shown, n) end
	win.note:SetText(note)
	win.note:SetTextColor(0.7, 0.7, 0.7)
	win:SetHeight(TOP + math.max(2, shown) * ROW + 8 + FOOT)
end

-- Opens the window, or closes it when it is open. anchor: a frame to open it beside (the world map).
-- Returns true when it is open after.
function ns.OpenRoute(anchor)
	if not win then Make() end
	if win:IsShown() then
		win:Hide()
		return false
	end
	if type(anchor) == 'table' then Beside(anchor) else Place() end
	win:Show()
	Fill()
	return true
end

function PatchwerkForever_Thread_Tracker_OpenMyRoute(anchor)
	return ns.Try('My Route', ns.OpenRoute, anchor) and true or false
end

-- (live: the list changes from anywhere; the distances change as you walk)
MyRoute():OnChange(function() ns.Try('My Route', Fill) end)
C_Timer.NewTicker(1, function() ns.Try('My Route', Fill) end)
ns.OnSetting(function() ns.Try('My Route', Fill) end)

-- (for the checks) the window, and its rows shown: { text, distance, row } each
function ns.RouteWindow()
	if not win then return nil end
	local out = {}
	for _, row in ipairs(rows) do
		if row:IsShown() and row.entry then out[#out + 1] = { text = row.name:GetText(), far = row.far:GetText(), row = row } end
	end
	return win, out
end
