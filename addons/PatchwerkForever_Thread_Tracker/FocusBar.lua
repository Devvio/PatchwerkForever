-- Tracker (Thread): the focus buttons, a slim row at the top of the list.
--
-- The base keeps a focus for each character (its Focus.lua): what the route follows, Auto (your guide
-- or your quests, as Routes (Thread)'s Priority setting says), one guide (RestedXP, the Dungeon
-- Journal list, My Route) or your quests only. This row has one small button for each focus there is
-- to choose now, the one in use lit, and the name of the one in use beside them. A click follows that
-- one; a right-click on the row gives the same choices as a menu. Choosing a focus lets go of a list
-- you selected in the tracker (a click on a side list: the base's Focus:Set does that), since the
-- focus is now that choice; a quest you clicked still comes first, as it does over your guide.
--
-- Routes (Thread) follows the focus and has /thread focus and the focus key bindings; this is only a
-- place to see and change it. "Show Focus Buttons" hides the row.
local ADDON, ns = ...
if not ns.linked then return end

local SIZE = 18               -- a button's size
local GAP = 3                 -- between two buttons

-- The pictures: the game's own icons, which every client has; a part's own icon where it has one.
local ICONS = {
	auto = 'Interface\\Icons\\INV_Misc_Map_01',
	quests = 'Interface\\GossipFrame\\AvailableQuestIcon',
	route = 'Interface\\Icons\\INV_Scroll_03',
	rxp = 'Interface\\Icons\\INV_Misc_Book_09',
	fdj = 'Interface\\Icons\\INV_Misc_Book_11',
}
local PARTS = { fdj = 'PatchwerkForever_Stitch_DungeonJournal' }
local OTHER = 'Interface\\Icons\\INV_Misc_Note_01'

local bar
local buttons = {}

local function Icon(id)
	local part = PARTS[id]
	if part and type(ns.Base.Icon) == 'function' then
		local ok, icon = pcall(ns.Base.Icon, ns.Base, part)
		if ok and type(icon) == 'string' then return icon end
	end
	return ICONS[id] or OTHER
end

-- Follows the focus id (see the top of this file for the list let go).
function ns.ChooseFocus(id)
	ns.Base.Focus:Set(id)
	ns.Refresh()
end

-- The same choices as a menu.
function ns.FocusMenu(owner)
	local Focus = ns.Base.Focus
	local now = Focus:Get()
	local list = {}
	for _, one in ipairs(Focus:Available()) do
		local id = one.id
		list[#list + 1] = { one.name .. (id == now and ' (Current)' or ''), function() ns.ChooseFocus(id) end }
	end
	ns.Menu(owner, 'Follow', list)
end

local function Tip(self)
	local tip = rawget(_G, 'GameTooltip')
	if not (type(tip) == 'table' and tip.SetOwner) then return end
	tip:SetOwner(self, 'ANCHOR_BOTTOM')
	tip:SetText(self.focusName or '', 1, 0.82, 0)
	if self.lit then
		tip:AddLine('Following now.', 1, 1, 1)
	else
		tip:AddLine('Click to follow.', 1, 1, 1)
	end
	tip:AddLine('Right-click for more options.', 0.6, 0.6, 0.6)
	tip:Show()
end

local function Untip()
	local tip = rawget(_G, 'GameTooltip')
	if type(tip) == 'table' and tip.Hide then tip:Hide() end
end

local function Button(i)
	local b = CreateFrame('Button', nil, bar)
	b:SetSize(SIZE, SIZE)
	b:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	-- (lit: a gold square behind the icon)
	b.lit = false
	b.back = b:CreateTexture(nil, 'BACKGROUND')
	b.back:SetAllPoints(b)
	b.icon = b:CreateTexture(nil, 'ARTWORK')
	b.icon:SetPoint('TOPLEFT', b, 'TOPLEFT', 2, -2)
	b.icon:SetPoint('BOTTOMRIGHT', b, 'BOTTOMRIGHT', -2, 2)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b:SetScript('OnClick', function(self, button)
		if button == 'RightButton' then
			ns.Try('the focus menu', ns.FocusMenu, self)
		elseif self.focusId then
			ns.Try('the focus buttons', ns.ChooseFocus, self.focusId)
		end
	end)
	b:SetScript('OnEnter', Tip)
	b:SetScript('OnLeave', Untip)
	buttons[i] = b
	return b
end

local function Make(content)
	bar = CreateFrame('Frame', nil, content)
	bar:EnableMouse(true)
	bar:SetScript('OnMouseUp', function(self, button)
		if button == 'RightButton' then ns.Try('the focus menu', ns.FocusMenu, self) end
	end)
	bar.words = bar:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	bar.words:SetPoint('RIGHT', bar, 'RIGHT', 0, 0)
	bar.words:SetJustifyH('RIGHT')
	bar.words:SetWordWrap(false)
end

-- Drawn at the top of the list by Frame.lua, each time the list is: the focus there is to choose now
-- (a guide addon turned on or off since) and the one in use.
ns.AddTop(function(content, x, y, width, size)
	if not ns.Get('focusBar') then
		if bar then bar:Hide() end
		return 0
	end
	if not bar then Make(content) end
	local Focus = ns.Base.Focus
	local list, now = Focus:Available(), Focus:Get()
	local hr, hg, hb = ns.RGB(ns.Get('lookHeader'))
	for i, one in ipairs(list) do
		local b = buttons[i] or Button(i)
		b.focusId, b.focusName, b.lit = one.id, one.name, one.id == now
		b.icon:SetTexture(Icon(one.id))
		if b.lit then
			b.back:SetColorTexture(hr, hg, hb, 0.9)
			b.icon:SetVertexColor(1, 1, 1)
		else
			b.back:SetColorTexture(0, 0, 0, 0.5)
			b.icon:SetVertexColor(0.55, 0.55, 0.55)
		end
		b:ClearAllPoints()
		b:SetPoint('TOPLEFT', bar, 'TOPLEFT', (i - 1) * (SIZE + GAP), 0)
		b:Show()
	end
	for i = #list + 1, #buttons do buttons[i]:Hide() end
	ns.Font(bar.words, math.max(8, size - 2))
	bar.words:SetText(Focus:Name(now))
	bar.words:SetTextColor(hr * 0.8, hg * 0.8, hb * 0.8)
	bar.words:SetWidth(math.max(20, width - #list * (SIZE + GAP) - 4))
	bar:ClearAllPoints()
	bar:SetPoint('TOPLEFT', content, 'TOPLEFT', x, -y)
	bar:SetSize(width, SIZE)
	bar:Show()
	return SIZE + 6
end)

-- (for the checks) the buttons shown: { id, lit } each, and the row itself
function ns.FocusShown()
	if not (bar and bar:IsShown()) then return nil end
	local out = {}
	for _, b in ipairs(buttons) do
		if b:IsShown() then out[#out + 1] = { id = b.focusId, lit = b.lit, button = b } end
	end
	return out, bar
end
