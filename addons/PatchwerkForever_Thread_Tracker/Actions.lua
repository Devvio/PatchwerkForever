-- Tracker (Thread): what a click on a quest does, and following the nearest quest by itself.
--
--   left-click         the quest is chosen: a side path, off the main track (your guide, or the
--                      nearest of your quests). The base keeps the choice (its Choice.lua) and
--                      Routes (Thread), when installed, goes there first. The game's arrow is put on
--                      the quest as well. A second click gives the main track back.
--   shift-left-click   the quest is opened to read, as the game's own tracker opens it
--   right-click        a short menu: follow, read, add to My Route (Route.lua), share with the
--                      party, stop tracking, abandon
--
-- Sharing is also a click on a quest's share mark (Party.lua) and a key binding, Share Quest With
-- Party, for the quest under the quest arrow.
--
-- Everything here is done only because you clicked, with one exception that is a setting and starts
-- off: with no guide running and no quest or side list chosen by you, the game's arrow is put on the
-- nearest quest you track ("Quest Arrow On Nearest Quest"). An arrow the game itself puts on a quest
-- you have just accepted counts as that setting's to move, and so does its own arrow after a reload.
--
-- Choosing a quest moves the game's arrow to it. Going back to the main route by a click or a key
-- puts the arrow back where it was before you chose (unless you have moved it since), so with no
-- guide the route leads where it did before. A quest you chose that you stop tracking in the quest
-- log is let go, as it is when you stop tracking it here.
--
-- Which block wears the bar of "being followed" is what Routes (Thread) says it follows, through the
-- base (PatchwerkForever.Following); with no such word (Routes not installed) it is worked out here.
--
-- Abandoning asks first, with the game's own question. Stopping tracking changes the game's watch
-- list, as the same entry in the game's own menu does.
local ADDON, ns = ...
if not ns.linked then return end

local LOOK = 2                -- seconds between two looks for the nearest quest
local NEARER = 0.85           -- another quest must be this much nearer before the arrow moves to it

local auto                    -- the quest the arrow was put on by itself (not by your click)
local arrowBefore             -- where the arrow was before you chose a quest, and whether it was
local autoBefore              -- the setting's own then: put back when you go back to the main route

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

-- (asked of the base, which keeps the quest you track while the game's waypoint is lent to Routes)
local function Followed()
	local id = (ns.Base.Marker and ns.Base.Marker.Quest) and ns.Base.Marker:Quest() or (C_SuperTrack and Ask(C_SuperTrack.GetSuperTrackedQuestID))
	return (type(id) == 'number' and id > 0) and id or nil
end

local function PutArrow(id)
	if not (C_SuperTrack and type(C_SuperTrack.SetSuperTrackedQuestID) == 'function') then return false end
	return (pcall(C_SuperTrack.SetSuperTrackedQuestID, id or 0))
end

-- The quest the arrow is the setting's own on, kept for this character across a reload.
local function SetAuto(id)
	auto = id
	local db = ns.Saved()
	db.auto = type(db.auto) == 'table' and db.auto or {}
	db.auto[Ask(UnitGUID, 'player') or 'player'] = id
end

-- Before a quest is chosen where none was: where the arrow is now, to be put back after.
local function Remember()
	local pick = ns.Base.Choice:Get()
	if pick and pick.kind == 'quest' then return end
	arrowBefore = Followed()
	autoBefore = auto ~= nil and auto == arrowBefore
end

-- Back to the main route by your own click or key, from the quest id: the arrow goes back where it
-- was before you chose, if that quest is still in your log. An arrow you moved since is left alone.
local function PutBack(id)
	local now = Followed()
	if now == nil or now == id then
		local back = arrowBefore
		if back == id or not (back and Ask(C_QuestLog.GetLogIndexForQuestID, back)) then back = nil end
		PutArrow(back or 0)
		if back and autoBefore then SetAuto(back) end
	end
	arrowBefore, autoBefore = nil, nil
end

-- Chooses a quest: the side path to follow in place of the main track. On the quest chosen
-- already, goes back to the main track.
function ns.Follow(id)
	local Choice = ns.Base.Choice
	if Choice:Is('quest', id) then
		auto = nil
		Choice:Clear()
		PutBack(id)
	else
		Remember()
		auto = nil
		Choice:Set('quest', id)
		PutArrow(id)
	end
	ns.Wake()
	ns.Refresh()
end

-- The focus in effect (the base's Focus.lua): 'auto', 'quests', or a guide reader's id. A guide
-- focused that has nowhere to send you gives way to 'auto', as the route does.
function ns.Focused()
	local Focus = ns.Base.Focus
	local id = Focus and Focus:Get() or 'auto'
	if id == 'auto' or id == 'quests' then return id end
	if ns.Base.Guides:Read(0, id) then return id end
	return 'auto'
end

-- Chooses the quest after (step 1) or before (step -1) the one chosen now, in the order they are
-- listed: for a key or a gamepad button, where there is no mouse to click a quest with. From no
-- quest, the first (or the last); one step past either end is no quest again: your main route.
-- While My Route is the focus or the list selected, its stops are walked instead (Route.lua).
function ns.Cycle(step)
	if ns.RouteWalk(step) then return end
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
	-- (the quest chosen may be past the edge of a long list: it is scrolled into view, and with no
	-- quest the list goes back to its top. The list is drawn again either way.)
	if to < 1 or to > #order then
		auto = nil
		Choice:Clear()
		PutBack(at and order[at])
		ns.Print('Back to your main route.')
		ns.Reveal(true)
	else
		Remember()
		auto = nil
		Choice:Set('quest', order[to])
		PutArrow(order[to])
		ns.Print(('Routing to quest "%s".'):format(tostring(Ask(C_QuestLog.GetTitleForQuestID, order[to]) or order[to])))
		ns.Reveal()
	end
end

-- (for the gathering list: a run takes the place of a quest you chose, and the arrow put on it goes too)
function ns.ArrowOff() PutArrow(0) end

-- What Routes (Thread) says it follows now (the base's Following), or nothing when no route planner
-- says (Routes not installed, or it has not looked yet): then the tracker works it out itself.
function ns.FollowingNow()
	local Following = ns.Base.Following
	local info = Following and Following:Get()
	return type(info) == 'table' and info or nil
end

-- The quest to mark as the one being followed: the one Routes says. Without its word: the one you
-- chose; with none chosen and no guide leading, the one the game's arrow is on. With your quests as
-- the focus, that one even while a guide runs; with a guide as the focus (My Route among them), none.
function ns.Marked()
	local said = ns.FollowingNow()
	if said then return said.kind == 'quest' and said.quest or nil end
	local pick = ns.Base.Choice:Get()
	if pick then return pick.kind == 'quest' and pick.id or nil end
	if ns.Base.Gather:Has() and ns.Base.Gather:State() then return nil end       -- (a gathering run is)
	local focus = ns.Focused()
	if focus == 'quests' then return Followed() end
	if focus ~= 'auto' then return nil end
	if ns.GuideNow() then return nil end
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

-- Shares a quest with your party, as the game's own tracker and quest log do. Returns whether the
-- game was asked to.
local function Share(id)
	local util = rawget(_G, 'QuestUtil')
	if type(util) == 'table' and type(util.ShareQuest) == 'function' and pcall(util.ShareQuest, id) then return true end
	local index = Ask(C_QuestLog.GetLogIndexForQuestID, id)
	local push = rawget(_G, 'QuestLogPushQuest')
	if index and type(push) == 'function' then return (pcall(push, index)) end
	return false
end

-- The same, said in chat: for the share mark on a quest's row (Party.lua) and the key binding, where
-- nothing else shows that the click or the key did something.
function ns.ShareQuest(id)
	if Share(id) then
		ns.Print(('Sharing quest "%s" with your party.'):format(tostring(Ask(C_QuestLog.GetTitleForQuestID, id) or id)))
	else
		ns.Print('The quest could not be shared on this client.')
	end
end

-- For the key binding "Share Quest With Party": the quest under the quest arrow, picked as Add Quest
-- To My Route picks its quest (ns.QuestAtHand, Route.lua). What stands in the way is said.
function ns.ShareAtHand()
	local id = ns.QuestAtHand()
	if not id then
		ns.Print('No quest selected. Put the quest arrow on a quest, then try again.')
		return
	end
	if not Ask(rawget(_G, 'IsInGroup')) then
		ns.Print('You are not in a party.')
		return
	end
	local can = Ask(C_QuestLog.IsPushableQuest, id)
	if not (ns.Plain(can) and can) then
		ns.Print(('Quest "%s" cannot be shared.'):format(tostring(Ask(C_QuestLog.GetTitleForQuestID, id) or id)))
		return
	end
	ns.ShareQuest(id)
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
		if ns.RouteHasQuest(id) then
			entries[#entries + 1] = { 'Remove From My Route', function() ns.RouteRemoveQuest(id) end }
		else
			entries[#entries + 1] = { 'Add To My Route', function() ns.RouteAddQuest(id) end }
		end
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
		if auto then SetAuto(nil) end
		return
	end
	local now = Followed()
	if now and now ~= auto then return end              -- a quest you chose: left alone
	if not now and auto then SetAuto(nil) end
	local focus = ns.Focused()
	if focus ~= 'auto' and focus ~= 'quests' then return end       -- a guide is the focus (My Route among them)
	if focus == 'auto' and ns.Base.Guides:Read(0) then return end  -- a guide is leading
	if ns.Base.Choice:Get() then return end             -- so is a side list you chose (never read as the main guide)
	local best, yards, yardsOf = Nearest()
	if not best or best == now then return end
	-- (the arrow stays on the quest it is on until another is clearly nearer)
	if now and yardsOf[now] and yards > yardsOf[now] * NEARER then return end
	if PutArrow(best) then
		SetAuto(best)
		ns.Refresh()
	end
end

C_Timer.NewTicker(LOOK, function() ns.Try('following the nearest quest', Look) end)

-- The game puts its arrow on a quest you accept when it points at nothing: that arrow is the
-- setting's to move on, not a quest you chose. (Looked at a moment later: the game places it after
-- this event.)
ns.On('QUEST_ACCEPTED', function(id)
	C_Timer.After(0, function()
		if ns.Get('on') and ns.Get('followNearest') and id and Followed() == id and not ns.Base.Choice:Is('quest', id) then
			SetAuto(id)
		end
	end)
end)

-- Ticked: an arrow already on a quest you did not choose in the tracker is the setting's to move, at once.
ns.OnSetting(function(key, value)
	if key ~= 'followNearest' or not value then return end
	local now = Followed()
	if now and not ns.Base.Choice:Is('quest', now) then SetAuto(now) end
	ns.Try('following the nearest quest', Look)
end)

-- After a reload: the arrow the setting put on a quest is still its own.
ns.On('PLAYER_LOGIN', function()
	local kept = ns.Saved().auto
	local id = type(kept) == 'table' and kept[Ask(UnitGUID, 'player') or 'player'] or nil
	if id and Followed() == id then auto = id end
end)

-- A quest you chose and then stopped tracking in the quest log (or on the map) is let go, as when you
-- stop tracking it here, since the tracker no longer lists it. (Untrack above lets go first, so this
-- says nothing twice.)
ns.On('QUEST_WATCH_LIST_CHANGED', function(id, added)
	-- (only while the quest is still in your log: handed in or abandoned, the choice lapses by itself)
	if added == false and id and ns.Base.Choice:Is('quest', id)
	and (tonumber(Ask(C_QuestLog.GetLogIndexForQuestID, id)) or 0) > 0 then
		ns.Base.Choice:Clear()
		ns.Print('Back to your main route.')
		ns.Refresh()
	end
end)

-- (Routes says it follows something else: the bar moves at the next drawing)
if ns.Base.Following then ns.Base.Following:OnChange(function() ns.Refresh() end) end

-- (for the checks)
function ns.AutoFollowed() return auto end
