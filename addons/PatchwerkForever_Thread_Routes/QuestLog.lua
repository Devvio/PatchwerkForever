-- Thread (Routes): adding quests to My Route from the game's quest log.
--
-- Forever's quest log is the side panel of the world map (QuestMapFrame, from Blizzard's modern world
-- map). Each quest's title in it is a button from a pool (QuestScrollFrame.titleFramePool), and the
-- whole list is drawn again by QuestLogQuests_Update. After each time it is drawn, a small "+" is put
-- beside every quest's title: a click adds the quest to My Route; a quest already in it shows a check
-- mark instead, and a click takes it out. The quest's own right-click menu (tagged
-- MENU_QUEST_MAP_LOG_TITLE) gets Add To My Route or Remove From My Route as well, through the game's
-- own way for addons to add to its menus (Menu.ModifyMenu).
--
-- Nothing of the quest log is changed: the list is only looked at after the game has drawn it, and the
-- buttons are our own frames. A game rule can switch the side panel off (QuestLogPanelDisabled); with
-- no panel, or a client without these functions, nothing is done.
local ADDON, ns = ...
if not ns.linked then return end

local SIZE = 14           -- the button's size, in pixels
local PLUS = 'Interface\\Buttons\\UI-PlusButton-Up'
local CHECK = 'Interface\\RaidFrame\\ReadyCheck-Ready'

local function MyRoute() return ns.Base.MyRoute end

-- The quest's place in My Route's list, or nil.
local function Find(id)
	local list = MyRoute()
	if not list then return nil end
	for _, stop in ipairs(list:Entries()) do
		if stop.kind ~= 'spot' and stop.id == id then return stop.index end
	end
	return nil
end

-- Adds the quest to My Route, or takes it out when it is in it already.
function ns.RouteToggleQuest(id)
	local list = MyRoute()
	if not (list and type(id) == 'number') then return end
	local index = Find(id)
	if index then
		list:Remove(index)
	else
		list:Add({ kind = 'quest', id = id })
	end
end

-- our button on each of the quest log's title buttons (the pool's buttons are reused: kept by button)
local added = setmetatable({}, { __mode = 'k' })

local function Tip(self)
	local tip = rawget(_G, 'GameTooltip')
	if not (type(tip) == 'table' and tip.SetOwner) then return end
	tip:SetOwner(self, 'ANCHOR_RIGHT')
	tip:SetText(Find(self.questID) and 'Remove From My Route' or 'Add To My Route')
	tip:Show()
end

local function Untip()
	local tip = rawget(_G, 'GameTooltip')
	if type(tip) == 'table' and tip.Hide then tip:Hide() end
end

local function Paint(plus)
	plus.icon:SetTexture(Find(plus.questID) and CHECK or PLUS)
end

local function Plus(title)
	local plus = added[title]
	if plus then return plus end
	plus = CreateFrame('Button', nil, title)
	plus:SetSize(SIZE, SIZE)
	-- (at the left of the title, where the game leaves room before the quest's name)
	plus:SetPoint('TOPLEFT', title, 'TOPLEFT', 12, -7)
	local icon = plus:CreateTexture(nil, 'ARTWORK')
	icon:SetAllPoints(plus)
	plus.icon = icon
	if plus.RegisterForClicks then plus:RegisterForClicks('LeftButtonUp') end
	plus:SetScript('OnClick', function(self) ns.Try('the quest log button', ns.RouteToggleQuest, self.questID) end)
	plus:SetScript('OnEnter', Tip)
	plus:SetScript('OnLeave', Untip)
	added[title] = plus
	return plus
end

-- The quest log's title buttons in use now, or nothing.
local function Titles()
	local scroll = rawget(_G, 'QuestScrollFrame')
	local pool = type(scroll) == 'table' and scroll.titleFramePool
	if not (type(pool) == 'table' and type(pool.EnumerateActive) == 'function') then return nil end
	local ok, walk, state, start = pcall(pool.EnumerateActive, pool)
	if not (ok and type(walk) == 'function') then return nil end
	return walk, state, start
end

-- After the game has drawn the list: a button on each quest's title.
local function Decorate()
	if not MyRoute() then return end
	local walk, state, start = Titles()
	if not walk then return end
	for title in walk, state, start do
		local id = type(title) == 'table' and title.questID
		if type(id) == 'number' and id > 0 then
			local plus = Plus(title)
			plus.questID = id
			Paint(plus)
			plus:Show()
		elseif added[title] then
			added[title]:Hide()
		end
	end
end

-- After My Route changes: the buttons shown again as they now are.
local function Repaint()
	for title, plus in pairs(added) do
		if plus.questID and type(title) == 'table' then Paint(plus) end
	end
end

-- The quest's own right-click menu: Add To My Route, or Remove From My Route.
local function ModifyMenu(owner, root)
	local id = type(owner) == 'table' and rawget(owner, 'questID')
	if not (type(id) == 'number' and id > 0 and MyRoute() and type(root) == 'table') then return end
	if root.CreateDivider then root:CreateDivider() end
	root:CreateButton(Find(id) and 'Remove From My Route' or 'Add To My Route', function()
		ns.Try('the quest menu', ns.RouteToggleQuest, id)
	end)
end

local hooked, menued = false, false
local function Hook()
	local secure = rawget(_G, 'hooksecurefunc')
	if not hooked and type(secure) == 'function' and type(rawget(_G, 'QuestLogQuests_Update')) == 'function' then
		hooked = pcall(secure, 'QuestLogQuests_Update', function() ns.Try('the quest log buttons', Decorate) end)
	end
	local menu = rawget(_G, 'Menu')
	if not menued and type(menu) == 'table' and type(menu.ModifyMenu) == 'function' then
		menued = pcall(menu.ModifyMenu, 'MENU_QUEST_MAP_LOG_TITLE', function(owner, root)
			ns.Try('the quest menu', ModifyMenu, owner, root)
		end)
	end
end

-- (for the checks: whether the hooks are in, and the button on a title button)
function ns.QuestLogHooked() return hooked, menued end
function ns.QuestLogPlus(title) return added[title] end

ns.Try('the quest log buttons', Hook)
ns.On('PLAYER_LOGIN', function() Hook() end)
ns.On('ADDON_LOADED', function() if not (hooked and menued) then Hook() end end)
if ns.Base.MyRoute and ns.Base.MyRoute.OnChange then
	ns.Base.MyRoute:OnChange(function() ns.Try('the quest log buttons', Repaint) end)
end
