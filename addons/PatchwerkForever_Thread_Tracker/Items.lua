-- Thread (Tracker): buttons for the items your quests give you to use.
--
-- Using an item is something the game lets only its "secure" kind of button do, and a secure
-- button may not be made to appear, vanish, move or change what it does while you are in a fight.
-- Rows of a list move whenever a quest above them changes. So the buttons are not on the rows:
--
--   * They stand in a strip of their own beside the tracker, the nearest quest's item first, then
--     the items the guide's step wants used (a hearthstone, say), where you carry them.
--   * They are made once, when the addon loads, and are placed against the screen, not against the
--     tracker: a frame a secure button hangs from may not move in a fight either.
--   * In a fight nothing of them is touched. What changed meanwhile (a quest done, the tracker
--     moved) is applied when the fight is over. Only a button's cooldown and count are redrawn,
--     which the game allows at any time.
--
-- One more button, never shown, is for a key or a gamepad button: "Use the nearest quest's item"
-- (Bindings.xml) presses it. It only ever holds a quest's item, never the guide's: a binding that
-- used your hearthstone when no quest had an item would be a bad surprise.
local ADDON, ns = ...
if not ns.linked then return end

local MOST = 8                -- buttons in the strip, at most
local GAP = 4

local buttons = {}
local nearest
local pending = false         -- something was wanted in a fight
local lastFrame               -- the tracker's frame when last drawn (nil: not shown)
local signature               -- what the strip was last laid out as

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end

local function Count(id)
	return Ask(C_Item and C_Item.GetItemCount, id, false, true) or Ask(rawget(_G, 'GetItemCount'), id, false, true) or 0
end

local function Icon(id)
	return Ask(C_Item and C_Item.GetItemIconByID, id) or Ask(rawget(_G, 'GetItemIcon'), id) or 134400      -- (a question mark)
end

---------------------------------------------------------------------------
-- The buttons, made once
---------------------------------------------------------------------------
local function Tip(self)
	local tip = rawget(_G, 'GameTooltip')
	if not (self.item and type(tip) == 'table' and tip.SetOwner) then return end
	tip:SetOwner(self, 'ANCHOR_LEFT')
	if self.link and tip.SetHyperlink then tip:SetHyperlink(self.link) elseif tip.SetItemByID then tip:SetItemByID(self.item) end
	if self.quest and tip.AddLine then
		local title = Ask(C_QuestLog.GetTitleForQuestID, self.quest)
		if title then tip:AddLine('For: ' .. title, 0.84, 0.64, 0.36) end
	end
	tip:Show()
end

local function Button(name)
	local b = CreateFrame('Button', name, UIParent, 'SecureActionButtonTemplate')
	b:RegisterForClicks('AnyUp', 'AnyDown')         -- (the game picks press or release by the player's own setting)
	b:SetFrameStrata('LOW')
	b:SetSize(32, 32)
	b:Hide()
	return b
end

local function Dress(b)
	b.back = b:CreateTexture(nil, 'BACKGROUND')
	b.back:SetAllPoints(b)
	b.back:SetColorTexture(0, 0, 0, 0.7)
	b.icon = b:CreateTexture(nil, 'ARTWORK')
	b.icon:SetAllPoints(b)
	b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	b.count = b:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	b.count:SetPoint('BOTTOMRIGHT', b, 'BOTTOMRIGHT', -1, 1)
	ns.Font(b.count, 11)
	b.count:SetTextColor(1, 1, 1)
	local ok, cool = pcall(CreateFrame, 'Cooldown', nil, b, 'CooldownFrameTemplate')
	if ok and cool then
		cool:SetAllPoints(b)
		b.cool = cool
	end
	b:SetScript('OnEnter', Tip)
	b:SetScript('OnLeave', function()
		local tip = rawget(_G, 'GameTooltip')
		if type(tip) == 'table' and tip.Hide then tip:Hide() end
	end)
end

for i = 1, MOST do
	buttons[i] = Button('PatchwerkForeverTrackerItem' .. i)
	Dress(buttons[i])
end
nearest = Button('PatchwerkForeverTrackerNearestItem')

---------------------------------------------------------------------------
-- Which items
---------------------------------------------------------------------------
local function Wanted()
	local list, has = {}, {}
	if not (ns.Get('on') and ns.Get('items')) then return list end
	local special = rawget(_G, 'GetQuestLogSpecialItemInfo')
	for i = 1, Ask(C_QuestLog.GetNumQuestWatches) or 0 do
		local quest = Ask(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
		local index = quest and Ask(C_QuestLog.GetLogIndexForQuestID, quest)
		if index then
			local link, texture, _, whenDone = Ask(special, index)
			local id = type(link) == 'string' and tonumber(link:match('item:(%d+)'))
			if id and not has[id] and (whenDone or not Ask(C_QuestLog.IsComplete, quest)) then
				has[id] = true
				list[#list + 1] = { id = id, link = link, icon = texture or Icon(id), quest = quest, watch = i, rank = ns.QuestRank(quest) }
			end
		end
	end
	-- (by the distance held for sorting, as the list of quests is: Places.lua)
	table.sort(list, function(a, b)
		if a.rank and b.rank then
			if a.rank ~= b.rank then return a.rank < b.rank end
		elseif a.rank or b.rank then
			return a.rank ~= nil
		end
		return a.watch < b.watch
	end)
	local guide = ns.Get('guide') and ns.Get('guideItems') and ns.GuideNow and ns.GuideNow()
	for _, id in ipairs(guide and guide.items or {}) do
		if not has[id] and Count(id) > 0 then
			has[id] = true
			list[#list + 1] = { id = id, icon = Icon(id) }
		end
	end
	for i = #list, MOST + 1, -1 do list[i] = nil end
	return list
end

---------------------------------------------------------------------------
-- Cooldowns and counts: redrawn at any time
---------------------------------------------------------------------------
local function Cooling()
	for _, b in ipairs(buttons) do
		if b.item and b:IsShown() then
			local start, duration = Ask(C_Container and C_Container.GetItemCooldown, b.item)
			if start == nil then start, duration = Ask(rawget(_G, 'GetItemCooldown'), b.item) end
			if b.cool then
				if tonumber(duration) and duration > 0 then b.cool:SetCooldown(start, duration) else b.cool:Clear() end
			end
			local count = Count(b.item)
			b.count:SetText(count > 1 and tostring(count) or '')
		end
	end
end

---------------------------------------------------------------------------
-- Laying the strip out: never in a fight
---------------------------------------------------------------------------
local function Layout()
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local list = Wanted()
	local frame = lastFrame
	local size = ns.Get('itemSize') or 32
	local x, top
	if frame and #list > 0 then
		local left, right, up = frame:GetLeft(), frame.GetRight and frame:GetRight(), frame:GetTop()
		if not (left and right and up) then
			-- (the game has not placed the tracker yet: asked again in a moment)
			C_Timer.After(0.2, ns.Refresh)
			return
		end
		local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		x = ns.Get('itemSide') == 'right' and (right * scale + GAP) or (left * scale - GAP - size)
		top = up * scale
		x, top = math.floor(x + 0.5), math.floor(top + 0.5)
	end
	local parts = { tostring(x), tostring(top), tostring(size) }
	for _, item in ipairs(list) do parts[#parts + 1] = tostring(item.id) end
	local now = table.concat(parts, ' ')
	if now == signature then return Cooling() end
	signature = now

	for i, b in ipairs(buttons) do
		local item = x and list[i]
		if item then
			b.item, b.link, b.quest = item.id, item.link, item.quest
			b:SetAttribute('type', 'item')
			b:SetAttribute('item', 'item:' .. item.id)
			b:SetSize(size, size)
			b:ClearAllPoints()
			b:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', x, top - (i - 1) * (size + GAP))
			b.icon:SetTexture(item.icon)
			b:Show()
		else
			b.item, b.link, b.quest = nil, nil, nil
			b:SetAttribute('type', nil)
			b:SetAttribute('item', nil)
			b:Hide()
		end
	end
	-- the button a key is bound to: the nearest quest's item, whether the strip is on screen or not
	local first = list[1] and list[1].quest and list[1] or nil
	nearest.item = first and first.id or nil
	nearest:SetAttribute('type', first and 'item' or nil)
	nearest:SetAttribute('item', first and ('item:' .. first.id) or nil)
	Cooling()
end

ns.OnDrawn(function(frame)
	lastFrame = frame
	Layout()
end)

ns.On('PLAYER_REGEN_ENABLED', function()
	if pending then Layout() end
end)
for _, event in ipairs({ 'BAG_UPDATE_COOLDOWN', 'SPELL_UPDATE_COOLDOWN' }) do
	ns.Try('listening for ' .. event, ns.On, event, Cooling)
end
ns.Try('listening for BAG_UPDATE_DELAYED', ns.On, 'BAG_UPDATE_DELAYED', ns.Refresh)

-- (for the checks) the items on the strip's buttons, in order, and the one the binding would use
function ns.ItemsShown()
	local out = {}
	for _, b in ipairs(buttons) do
		if b:IsShown() then out[#out + 1] = b.item end
	end
	return out, nearest.item
end
