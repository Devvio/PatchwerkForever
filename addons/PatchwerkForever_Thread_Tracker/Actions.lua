-- Thread (Tracker): what a click on a quest does, and following the nearest quest by itself.
--
--   left-click         the quest is chosen: a side path, off the main track (your guide, or the
--                      nearest of your quests). The base keeps the choice (its Choice.lua) and
--                      Thread (Routes), when installed, goes there first. The game's arrow is put on
--                      the quest as well. A second click gives the main track back.
--   shift-left-click   the quest is opened to read, as the game's own tracker opens it
--   right-click        a short menu: follow, read, share with the party, stop tracking, abandon
--
-- Everything here is done only because you clicked, with one exception that is a setting and starts
-- off: with no guide running and no quest or side list chosen by you, the game's arrow is put on the
-- nearest quest you track ("Follow The Nearest Quest By Itself").
--
-- Abandoning asks first, with the game's own question. Stopping tracking changes the game's watch
-- list, as the same entry in the game's own menu does.
local ADDON, ns = ...
if not ns.linked then return end

local LOOK = 2                -- seconds between two looks for the nearest quest
local NEARER = 0.85           -- another quest must be this much nearer before the arrow moves to it

local auto                    -- the quest the arrow was put on by itself (not by your click)

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

local function Followed()
	local id = C_SuperTrack and Ask(C_SuperTrack.GetSuperTrackedQuestID)
	return (type(id) == 'number' and id > 0) and id or nil
end

local function PutArrow(id)
	if not (C_SuperTrack and type(C_SuperTrack.SetSuperTrackedQuestID) == 'function') then return false end
	return (pcall(C_SuperTrack.SetSuperTrackedQuestID, id or 0))
end

-- Chooses a quest: the side path to follow in place of the main track. On the quest chosen
-- already, goes back to the main track.
function ns.Follow(id)
	auto = nil
	local Choice = ns.Base.Choice
	if Choice:Is('quest', id) then
		Choice:Clear()
		PutArrow(0)
	else
		Choice:Set('quest', id)
		PutArrow(id)
	end
	ns.Refresh()
end

-- Chooses the quest after (step 1) or before (step -1) the one chosen now, in the order they are
-- listed: for a key or a gamepad button, where there is no mouse to click a quest with. From no
-- quest, the first (or the last); one step past either end is no quest again: your main route.
function ns.Cycle(step)
	local order = ns.questOrder
	if not (order and #order > 0) then                       -- (the list is not drawn: the game's own order)
		order = {}
		for i = 1, Ask(C_QuestLog.GetNumQuestWatches) or 0 do
			order[#order + 1] = Ask(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
		end
	end
	if #order == 0 then
		ns.Print('No tracked quests.')
		return
	end
	local Choice = ns.Base.Choice
	local pick = Choice:Get()
	local at
	for i, id in ipairs(order) do
		if pick and pick.kind == 'quest' and pick.id == id then at = i end
	end
	local to = at and (at + step) or (step > 0 and 1 or #order)
	auto = nil
	-- (the quest chosen may be past the edge of a long list: it is scrolled into view, and with no
	-- quest the list goes back to its top. The list is drawn again either way.)
	if to < 1 or to > #order then
		Choice:Clear()
		PutArrow(0)
		ns.Print('Back to your main route.')
		ns.Reveal(true)
	else
		Choice:Set('quest', order[to])
		PutArrow(order[to])
		ns.Print('Routing to: ' .. tostring(Ask(C_QuestLog.GetTitleForQuestID, order[to]) or order[to]))
		ns.Reveal()
	end
end

-- (for the gathering list: a run takes the place of a quest you chose, and the arrow put on it goes too)
function ns.ArrowOff() PutArrow(0) end

-- The quest to mark as the one being followed: the one you chose; with none chosen and no guide
-- leading, the one the game's arrow is on.
function ns.Marked()
	local pick = ns.Base.Choice:Get()
	if pick then return pick.kind == 'quest' and pick.id or nil end
	if ns.Base.Gather:Has() and ns.Base.Gather:State() then return nil end       -- (a gathering run is)
	if ns.GuideNow and ns.GuideNow() then return nil end
	return Followed()
end

-- Opens a quest to read.
function ns.OpenQuest(id)
	if InCombatLockdown() then
		ns.Print('Quest details cannot be opened in combat.')
		return
	end
	local util = rawget(_G, 'QuestUtil')
	if type(util) == 'table' and type(util.OpenQuestDetails) == 'function' and pcall(util.OpenQuestDetails, id) then return end
	local open = rawget(_G, 'QuestMapFrame_OpenToQuestDetails')
	if type(open) == 'function' and pcall(open, id) then return end
	ns.Print('Quest details could not be opened on this client.')
end

local function Share(id)
	local util = rawget(_G, 'QuestUtil')
	if type(util) == 'table' and type(util.ShareQuest) == 'function' and pcall(util.ShareQuest, id) then return end
	local index = Ask(C_QuestLog.GetLogIndexForQuestID, id)
	local push = rawget(_G, 'QuestLogPushQuest')
	if index and type(push) == 'function' then pcall(push, index) end
end

local function Untrack(id)
	if ns.Base.Choice:Is('quest', id) then ns.Base.Choice:Clear() end
	if Followed() == id then PutArrow(0) end
	Ask(C_QuestLog.RemoveQuestWatch, id)
	ns.Refresh()
end

-- The game's own question ("Abandon ...?") is what abandons it, or does not.
local function Abandon(id, title)
	if InCombatLockdown() then
		ns.Print('Quests cannot be abandoned from the tracker in combat.')
		return
	end
	local ask = rawget(_G, 'QuestMapQuestOptions_AbandonQuest')
	if type(ask) == 'function' and pcall(ask, id) then return end
	local popup = rawget(_G, 'StaticPopup_Show')
	if type(C_QuestLog.SetSelectedQuest) == 'function' and type(C_QuestLog.SetAbandonQuest) == 'function' and type(popup) == 'function' then
		C_QuestLog.SetSelectedQuest(id)
		C_QuestLog.SetAbandonQuest()
		popup('ABANDON_QUEST', title)
		return
	end
	ns.Print('Could not abandon the quest from the tracker. Use the quest log.')
end

-- A menu at the mouse: a title and entries { text, fn }. Returns false when this client has none.
function ns.Menu(owner, title, entries)
	local util = rawget(_G, 'MenuUtil')
	if not (type(util) == 'table' and type(util.CreateContextMenu) == 'function') then
		if not ns.toldNoMenu then
			ns.toldNoMenu = true
			ns.Print('Right-click menus are not available on this client.')
		end
		return false
	end
	util.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(title)
		for _, entry in ipairs(entries) do
			local label, fn = entry[1], entry[2]
			root:CreateButton(label, function() ns.Try('the menu (' .. label .. ')', fn) end)
		end
	end)
	return true
end

function ns.QuestClick(quest, button, block)
	local id = quest.id
	if button == 'RightButton' then
		local entries = {
			{ ns.Base.Choice:Is('quest', id) and 'Stop Routing To Quest' or 'Route To Quest', function() ns.Follow(id) end },
			{ 'Quest Details', function() ns.OpenQuest(id) end },
		}
		local grouped = type(IsInGroup) == 'function' and IsInGroup()
		if grouped and Ask(C_QuestLog.IsPushableQuest, id) then
			entries[#entries + 1] = { 'Share Quest', function() Share(id) end }
		end
		entries[#entries + 1] = { 'Untrack Quest', function() Untrack(id) end }
		entries[#entries + 1] = { 'Abandon Quest', function() Abandon(id, quest.title) end }
		ns.Menu(block, quest.title, entries)
	elseif type(IsShiftKeyDown) == 'function' and IsShiftKeyDown() then
		ns.OpenQuest(id)
	else
		ns.Follow(id)
	end
end

---------------------------------------------------------------------------
-- Following the nearest quest by itself (a setting, off to begin with)
---------------------------------------------------------------------------
local function Nearest()
	local best, bestYards, yardsOf = nil, nil, {}
	for i = 1, Ask(C_QuestLog.GetNumQuestWatches) or 0 do
		local id = Ask(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
		local yards = id and ns.QuestYards(id)
		if yards then
			yardsOf[id] = yards
			if not bestYards or yards < bestYards then best, bestYards = id, yards end
		end
	end
	return best, bestYards, yardsOf
end

local function Look()
	if not (ns.Get('on') and ns.Get('followNearest')) then
		auto = nil
		return
	end
	local now = Followed()
	if now and now ~= auto then return end              -- a quest you chose: left alone
	if not now then auto = nil end
	if ns.Base.Guides:Read(0) then return end           -- a guide is leading
	if ns.Base.Choice:Get() then return end             -- so is a side list you chose (never read as the main guide)
	local best, yards, yardsOf = Nearest()
	if not best or best == now then return end
	-- (the arrow stays on the quest it is on until another is clearly nearer)
	if now and yardsOf[now] and yards > yardsOf[now] * NEARER then return end
	if PutArrow(best) then
		auto = best
		ns.Refresh()
	end
end

C_Timer.NewTicker(LOOK, function() ns.Try('following the nearest quest', Look) end)

-- (for the checks)
function ns.AutoFollowed() return auto end
