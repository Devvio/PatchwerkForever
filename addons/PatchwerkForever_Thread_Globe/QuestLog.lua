-- Globe (Thread): the quest log beside the globe.
--
-- A panel at the right of the window, as the world map's quest log sits beside its map (Show Quest
-- Log, off as it comes; the Quest Log button and key show and hide it):
--
--   your quests        under their headings, as the game's quest log has them: each with its level,
--                      its objectives, and Complete once it is done. A click turns the globe to where
--                      the quest is done and picks its mark out there; a right-click is a menu (Route
--                      To Quest, Quest Details, Track Quest, Share Quest, Add To My Route). A click on
--                      a heading folds it.
--   the journal list   under them, the stops of Dungeon Journal (Stitch)'s list while it runs (the
--                      dungeon quests to pick up and turn in, in the order it would take them). A click
--                      turns the globe to the stop; a right-click follows the list, or adds the quest
--                      to My Route.
--
-- The globe's picture is narrower while the panel shows (ns.GlobeSide). With keys, Next Quest picks
-- the quests in the list's order, one after another.
local ADDON, ns = ...
if not (ns.linked and ns.Marks and ns.GlobeSide) then return end
local G, Marks = ns.G, ns.Marks
local Base = ns.Base
local Guides, Choice, Following, MyRoute = Base.Guides, Base.Choice, Base.Following, Base.MyRoute

local WIDTH = 252                     -- the panel (points)
local GAP = 4                         -- between the picture and the panel
local TOP = 24                        -- the panel's own title above its list
local ROW, LINE = 18, 14              -- a heading's, quest's or stop's row, and an objective's line
local INDENT = 10                     -- a quest under its heading; its objectives further in
local JOURNAL = 'fdj'                 -- Dungeon Journal (Stitch)'s reader, in the base's Guides
local AHEAD = 30                      -- how many of the journal's stops are read after the first
local EVERY = 3                       -- the journal's list is read again this often while the panel shows (seconds)
local TURN_TO = G.VIEW * 2.4          -- a quest shown from further out than this is zoomed in on, to here (as Quests.lua)
local GOLD = { 1, 0.82, 0 }
local GRAY = { 0.55, 0.55, 0.55 }

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local log = rawget(_G, 'C_QuestLog') or {}

local panel, scroll, child, title, countText, button
local rows = {}                       -- the rows made so far, used again for each drawing
local list = {}                       -- what the rows show now, in order
local folded = {}                     -- the headings folded (by their words), until you reload
local picked                          -- what was picked from the list: a quest's id, or a journal stop's key
local dirty, since = true, 0

local function Shown() return panel ~= nil and panel:IsShown() end

-- The quest picked in the list, while it shows: Quests.lua draws its mark as it draws the one you route to.
function ns.QuestLogPicked()
	if Shown() and type(picked) == 'number' then return picked end
	return nil
end

---------------------------------------------------------------------------
-- What the list says
---------------------------------------------------------------------------
local function Done(id) return (Ask(log.IsComplete, id) or Ask(log.ReadyForTurnIn, id)) and true or false end

local function Level(info)
	local level = tonumber(info.difficultyLevel) or tonumber(info.level)
	if level and level > 0 then return level end
	return nil
end

local function Objectives(id)
	local out = {}
	for _, o in ipairs(Ask(log.GetQuestObjectives, id) or {}) do
		if type(o) == 'table' and type(o.text) == 'string' and o.text ~= '' then
			out[#out + 1] = { text = o.text, done = o.finished and true or false }
		end
	end
	return out
end

-- The first line of a journal stop, without its colors.
local function StopWords(step)
	for _, line in ipairs(type(step.lines) == 'table' and step.lines or {}) do
		if type(line) == 'table' and type(line.text) == 'string' and line.text ~= '' then
			return (line.text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''))
		end
	end
	return 'Dungeon Journal stop'
end

local function Read()
	local out, count = {}, 0
	local heading, pending                -- (a heading is listed with the first quest under it)
	for i = 1, Ask(log.GetNumQuestLogEntries) or 0 do
		local info = Ask(log.GetInfo, i)
		if type(info) == 'table' then
			if info.isHeader then
				heading = type(info.title) == 'string' and info.title or 'Other'
				pending = { kind = 'heading', text = heading, key = 'h:' .. heading }
			elseif not info.isHidden and type(info.questID) == 'number' then
				count = count + 1
				if pending then
					out[#out + 1] = pending
					pending = nil
				end
				if not (heading and folded['h:' .. heading]) then
					local id = info.questID
					local done = Done(id)
					local name = type(info.title) == 'string' and info.title or Ask(log.GetTitleForQuestID, id) or ('Quest ' .. tostring(id))
					local lines = Objectives(id)
					out[#out + 1] = { kind = 'quest', id = id, key = id, text = name, level = Level(info), done = done,
						failed = Ask(log.IsFailed, id) and true or false, lines = lines }
					for _, line in ipairs(lines) do
						out[#out + 1] = { kind = 'line', id = id, key = id, text = line.text, done = line.done or done }
					end
				end
			end
		end
	end
	-- Dungeon Journal (Stitch)'s list, when its reader is there and has something to say
	local info = type(Guides) == 'table' and Guides.Read and Guides:Read(AHEAD, JOURNAL)
	if type(info) == 'table' and type(info.map) == 'number' then
		local name = type(info.guide) == 'string' and info.guide or type(info.reader) == 'string' and info.reader or 'Dungeon Journal'
		out[#out + 1] = { kind = 'heading', text = name, key = 'h:journal', journal = true }
		if not folded['h:journal'] then
			local steps = { info }
			for _, step in ipairs(type(info.ahead) == 'table' and info.ahead or {}) do steps[#steps + 1] = step end
			for n, step in ipairs(steps) do
				if type(step.map) == 'number' and type(step.x) == 'number' and type(step.y) == 'number' then
					local quest = tonumber(step.quest)
					out[#out + 1] = { kind = 'stop', text = StopWords(step), quest = quest, map = step.map, x = step.x, y = step.y,
						first = n == 1, key = ('s:%s:%d:%d'):format(tostring(quest or n), math.floor(step.x + 0.5), math.floor(step.y + 0.5)) }
				end
			end
		end
	end
	return out, count
end

---------------------------------------------------------------------------
-- What a click does
---------------------------------------------------------------------------
local Refresh

-- Turn the globe to a place (a continent's map number, world x, y); false when the globe has no such place.
local function TurnTo(map, x, y)
	local p = map and Marks.Where(map, x, y)
	if not p then return false end
	G.GlideTo(p, math.max(G.look.r, TURN_TO))
	return true
end

local function ShowQuest(id)
	picked = id
	Marks.Changed('quests')
	local map, x, y
	if Guides and Guides.QuestPlace then map, x, y = Guides.QuestPlace(id) end
	if not TurnTo(map, x, y) then ns.Print('The game shows no place on the map for this quest.') end
	Refresh()
end

local function ShowStop(row)
	picked = row.key
	Marks.Changed('quests')
	TurnTo(row.map, row.x, row.y)
	Refresh()
end

-- Opens a quest to read, as the game's own quest log would.
local function Details(id)
	if Ask(rawget(_G, 'InCombatLockdown')) then
		ns.Print('Quest details cannot be opened in combat.')
		return
	end
	local util = rawget(_G, 'QuestUtil')
	if type(util) == 'table' and type(util.OpenQuestDetails) == 'function' and pcall(util.OpenQuestDetails, id) then return end
	local open = rawget(_G, 'QuestMapFrame_OpenToQuestDetails')
	if type(open) == 'function' and pcall(open, id) then return end
	ns.Print('Quest details could not be opened on this client.')
end

-- Whether a quest is in the game's tracker: nil when this client cannot say.
local function Watched(id)
	if type(log.GetQuestWatchType) == 'function' then return Ask(log.GetQuestWatchType, id) ~= nil end
	if type(log.IsQuestWatched) == 'function' then return Ask(log.IsQuestWatched, id) and true or false end
	return nil
end

local function Share(id)
	local util = rawget(_G, 'QuestUtil')
	if type(util) == 'table' and type(util.ShareQuest) == 'function' and pcall(util.ShareQuest, id) then return end
	local index = Ask(log.GetLogIndexForQuestID, id)
	local push = rawget(_G, 'QuestLogPushQuest')
	if not (index and type(push) == 'function' and pcall(push, index)) then ns.Print('The quest could not be shared on this client.') end
end

-- The My Route entry for a quest of your log or of the journal's list (kind 'quest' or the journal's
-- own), or nothing: My Route is not there, or the quest is in it already.
local function RouteEntry(root, kind, id, name)
	if not (type(MyRoute) == 'table' and MyRoute.Add and MyRoute.Has and id) then return end
	if kind ~= 'quest' and not (type(MyRoute.kinds) == 'table' and MyRoute.kinds[kind]) then return end
	if Ask(MyRoute.Has, MyRoute, kind, id) then return end
	root:CreateButton('Add To My Route', function()
		if not MyRoute:Add({ kind = kind, id = id }) then ns.Print(('"%s" is already in My Route.'):format(name)) end
	end)
end

local function QuestMenu(row, owner)
	local id = row.id
	G.Menu(owner, function(root)
		root:CreateTitle(row.text)
		root:CreateButton('Show On Globe', function() ShowQuest(id) end)
		if ns.QuestRoute then
			local on = ns.QuestChosen and ns.QuestChosen(id)
			root:CreateButton(on and 'Stop Routing To Quest' or 'Route To Quest', function()
				ns.QuestRoute(id)
				Refresh()
			end)
		end
		root:CreateButton('Quest Details', function() Details(id) end)
		local watched = Watched(id)
		if watched ~= nil then
			root:CreateButton(watched and 'Untrack Quest' or 'Track Quest', function()
				if watched then Ask(log.RemoveQuestWatch, id) else Ask(log.AddQuestWatch, id) end
				Refresh()
			end)
		end
		if Ask(rawget(_G, 'IsInGroup')) and Ask(log.IsPushableQuest, id) then
			root:CreateButton('Share Quest', function() Share(id) end)
		end
		RouteEntry(root, 'quest', id, row.text)
	end)
end

local function FollowingList()
	return type(Choice) == 'table' and Choice.Is and Choice:Is('guide', JOURNAL) and true or false
end

local function StopMenu(row, owner)
	G.Menu(owner, function(root)
		root:CreateTitle(row.text)
		root:CreateButton('Show On Globe', function() ShowStop(row) end)
		if type(Choice) == 'table' and Choice.Set then
			if FollowingList() then
				root:CreateButton('Back To Your Main Route', function()
					Choice:Clear()
					Refresh()
				end)
			else
				root:CreateButton('Follow This List', function()
					Choice:Set('guide', JOURNAL)
					Refresh()
				end)
			end
		end
		if row.quest then RouteEntry(root, JOURNAL, row.quest, row.text) end
	end)
end

local function Click(self, mouse)
	local row = self.row
	if not row then return end
	if row.kind == 'heading' then
		folded[row.key] = not folded[row.key] or nil
		Refresh()
	elseif row.kind == 'stop' then
		if mouse == 'RightButton' then StopMenu(row, self) else ShowStop(row) end
	elseif row.id then
		if mouse == 'RightButton' then
			QuestMenu(list[self.quest] or row, self)
		else
			ShowQuest(row.id)
		end
	end
end

local function Enter(self)
	local row = self.row
	local tip = rawget(_G, 'GameTooltip')
	if not (row and tip) or row.kind == 'heading' then return end
	local quest = list[self.quest] or row
	tip:SetOwner(self, 'ANCHOR_LEFT')
	tip:SetText(quest.text)
	if quest.kind == 'quest' then
		for _, line in ipairs(quest.lines or {}) do
			tip:AddLine(line.done and ('|cff808080' .. line.text .. '|r') or line.text)
		end
		if quest.done then tip:AddLine('Ready to turn in') end
		tip:AddLine('|cff66c2ffClick to show it on the globe. Right-click for more.|r')
	else
		tip:AddLine('Dungeon Journal')
		tip:AddLine('|cff66c2ffClick to show it on the globe. Right-click to follow this list.|r')
	end
	tip:Show()
end

local function Leave()
	local tip = rawget(_G, 'GameTooltip')
	if tip then tip:Hide() end
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------
local function Row(i)
	local r = rows[i]
	if r then return r end
	r = CreateFrame('Button', nil, child)
	if r.RegisterForClicks then r:RegisterForClicks('LeftButtonUp', 'RightButtonUp') end
	r.back = r:CreateTexture(nil, 'BACKGROUND')
	r.back:SetAllPoints(r)
	r.back:SetColorTexture(1, 0.82, 0, 0.16)
	r.back:Hide()
	r.lit = r:CreateTexture(nil, 'HIGHLIGHT')
	r.lit:SetAllPoints(r)
	r.lit:SetColorTexture(1, 1, 1, 0.08)
	r.dot = r:CreateTexture(nil, 'ARTWORK')
	r.dot:SetSize(6, 6)
	r.dot:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	r.dot:SetPoint('LEFT', r, 'LEFT', 1, 0)
	r.dot:Hide()
	r.text = r:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	r.text:SetPoint('LEFT', r, 'LEFT', 9, 0)
	r.text:SetPoint('RIGHT', r, 'RIGHT', -64, 0)
	r.text:SetJustifyH('LEFT')
	r.text:SetWordWrap(false)
	r.right = r:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	r.right:SetPoint('RIGHT', r, 'RIGHT', -2, 0)
	r.right:SetJustifyH('RIGHT')
	r.right:SetWordWrap(false)
	r:SetScript('OnClick', Click)
	r:SetScript('OnEnter', Enter)
	r:SetScript('OnLeave', Leave)
	rows[i] = r
	return r
end

local function Colour(fs, c) fs:SetTextColor(c[1], c[2], c[3]) end

-- The color the game writes a quest of this level in, for your level.
local function LevelColour(level)
	local get = rawget(_G, 'GetQuestDifficultyColor')
	local c = level and Ask(get, level)
	if type(c) == 'table' and c.r then return { c.r, c.g, c.b } end
	return GOLD
end

local function Draw()
	dirty, since = false, 0
	if not Shown() then return end
	local out, count = Read()
	list = out
	-- (a pick that is gone from the list is let go)
	local still = false
	for _, row in ipairs(out) do
		if row.key == picked and (row.kind == 'quest' or row.kind == 'stop') then still = true end
	end
	if picked ~= nil and not still then
		picked = nil
		Marks.Changed('quests')
	end
	local routed = ns.QuestPicked and ns.QuestPicked()
	local following = FollowingList()
	local room = Ask(log.GetMaxNumQuestsCanAccept)
	countText:SetText(tonumber(room) and room > 0 and ('%d/%d'):format(count, room) or tostring(count))
	local y, quest = 0, nil
	for i, row in ipairs(out) do
		local r = Row(i)
		r.row = row
		if row.kind == 'quest' then quest = i end
		r.quest = (row.kind == 'quest' or row.kind == 'line') and quest or nil
		local h, indent = ROW, 0
		local text, right, colour = row.text, '', GOLD
		local font = 'GameFontNormal'
		if row.kind == 'heading' then
			text = (folded[row.key] and '+ ' or '- ') .. row.text
			colour = { 1, 0.92, 0.72 }
		elseif row.kind == 'quest' then
			indent = INDENT
			text = row.level and ('[%d] %s'):format(row.level, row.text) or row.text
			colour = LevelColour(row.level)
			if row.failed then
				right, colour = 'Failed', { 1, 0.2, 0.2 }
			elseif row.done then
				right = 'Complete'
			end
		elseif row.kind == 'line' then
			h, indent, font = LINE, INDENT * 2, 'GameFontHighlightSmall'
			colour = row.done and GRAY or { 0.9, 0.9, 0.9 }
			text = '- ' .. row.text
		else
			indent = INDENT
			colour = { 0.55, 0.95, 0.78 }
			right = row.first and 'Next' or ''
		end
		r.text:SetFontObject(font)
		r.text:SetText(text)
		Colour(r.text, colour)
		r.right:SetText(right)
		Colour(r.right, row.failed and { 1, 0.2, 0.2 } or GOLD)
		r.back:SetShown(row.kind ~= 'heading' and row.kind ~= 'line' and row.key == picked)
		r.dot:SetShown((row.kind == 'quest' and row.id == routed) or (row.kind == 'stop' and row.first and following))
		r:ClearAllPoints()
		r:SetPoint('TOPLEFT', child, 'TOPLEFT', indent, -y)
		r:SetPoint('RIGHT', child, 'RIGHT', 0, 0)
		r:SetHeight(h)
		r:Show()
		y = y + h
	end
	for i = #out + 1, #rows do
		rows[i].row = nil
		rows[i]:Hide()
	end
	child:SetHeight(math.max(1, y))
	-- (a list grown shorter is scrolled back into range)
	if scroll.GetVerticalScrollRange and scroll:GetVerticalScroll() > scroll:GetVerticalScrollRange() then
		scroll:SetVerticalScroll(scroll:GetVerticalScrollRange())
	end
	if #out == 0 then
		local r = Row(1)
		r.row = nil
		r.text:SetFontObject('GameFontHighlightSmall')
		r.text:SetText('No quests.')
		Colour(r.text, GRAY)
		r.right:SetText('')
		r.back:Hide()
		r.dot:Hide()
		r:ClearAllPoints()
		r:SetPoint('TOPLEFT', child, 'TOPLEFT', 0, 0)
		r:SetPoint('RIGHT', child, 'RIGHT', 0, 0)
		r:SetHeight(ROW)
		r:Show()
	end
end

Refresh = function()
	dirty = true
	if Shown() then ns.Try('the quest log', Draw) end
end

local function Build(window, view)
	panel = CreateFrame('Frame', nil, window)
	panel:SetPoint('TOPLEFT', view, 'TOPRIGHT', GAP, 0)
	panel:SetPoint('BOTTOMLEFT', view, 'BOTTOMRIGHT', GAP, 0)
	panel:SetWidth(WIDTH)
	panel:EnableMouse(true)
	local back = panel:CreateTexture(nil, 'BACKGROUND')
	back:SetAllPoints(panel)
	back:SetColorTexture(0.10, 0.08, 0.05, 0.85)
	title = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	title:SetPoint('TOPLEFT', panel, 'TOPLEFT', 8, -6)
	title:SetText('Quest Log')
	countText = panel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	countText:SetPoint('TOPRIGHT', panel, 'TOPRIGHT', -8, -7)
	countText:SetJustifyH('RIGHT')
	scroll = CreateFrame('ScrollFrame', nil, panel, 'UIPanelScrollFrameTemplate')
	scroll:SetPoint('TOPLEFT', panel, 'TOPLEFT', 4, -TOP)
	scroll:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', -24, 4)
	child = CreateFrame('Frame', nil, scroll)
	child:SetSize(WIDTH - 28, 1)
	scroll:SetScrollChild(child)
	panel:SetScript('OnShow', function() Refresh() end)
	panel:SetScript('OnHide', function()
		if picked ~= nil then Marks.Changed('quests') end
	end)
	panel:Hide()
end

-- The panel shown or hidden as the setting says, and the globe's picture made room for it.
local function Apply()
	local window, view = ns.GlobeWindow()
	if not window then return end
	if not panel then Build(window, view) end
	local on = ns.Get('globeQuestLog') and true or false
	ns.GlobeSide(on and (WIDTH + GAP) or 0)
	panel:SetShown(on)
	if on then Refresh() end
end

---------------------------------------------------------------------------
-- When it is drawn again
---------------------------------------------------------------------------
ns.GlobeOn('show', function()
	local window = ns.GlobeWindow()
	if not button then
		button = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
		button:SetSize(80, 22)
		button:SetPoint('TOPLEFT', window, 'TOPLEFT', 212, -4)       -- (beside Go To, Route and Show)
		button:SetText('Quest Log')
		button:SetScript('OnClick', function() ns.Set('globeQuestLog', not ns.Get('globeQuestLog')) end)
	end
	Apply()
end)
ns.OnSetting(function(key)
	if key == 'globeQuestLog' then Apply() end
end)
ns.GlobeOn('frame', function(elapsed)
	if not Shown() then return end
	since = since + (elapsed or 0)
	if dirty or since >= EVERY then ns.Try('the quest log', Draw) end
end)
local function Stale() dirty = true end
for _, event in ipairs({ 'QUEST_LOG_UPDATE', 'QUEST_WATCH_LIST_CHANGED', 'SUPER_TRACKING_CHANGED', 'QUEST_ACCEPTED', 'QUEST_REMOVED',
	'QUEST_TURNED_IN', 'UNIT_QUEST_LOG_CHANGED', 'PLAYER_LEVEL_UP' }) do
	Marks.On(event, Stale)
end
if type(Choice) == 'table' and Choice.OnChange then Choice:OnChange(Stale) end
if type(Following) == 'table' and Following.OnChange then Following:OnChange(Stale) end

-- Keys: show or hide the panel; pick the next quest of the list (from the last one, the first again).
ns.GlobeOn('key', function(what)
	if what == 'questlog' then
		ns.Set('globeQuestLog', not ns.Get('globeQuestLog'))
		return true
	elseif what == 'nextquest' then
		if dirty or #list == 0 then
			local out = Read()
			list = out
		end
		local quests, at = {}, nil
		for _, row in ipairs(list) do
			if row.kind == 'quest' then
				quests[#quests + 1] = row.id
				if row.id == picked then at = #quests end
			end
		end
		if #quests == 0 then
			ns.Print('No quests.')
		else
			ShowQuest(quests[at and (at % #quests + 1) or 1])
		end
		return true
	end
	return false
end)

-- For the checks outside the game.
function ns.QuestLogState()
	local out = { panel = panel, button = button, scroll = scroll, child = child, shown = Shown(), picked = picked,
		count = countText and countText.text, rows = {} }
	for _, r in ipairs(rows) do
		if not r:IsShown() then break end
		out.rows[#out.rows + 1] = { frame = r, kind = r.row and r.row.kind, text = r.text.text, right = r.right.text,
			picked = r.back:IsShown(), routed = r.dot:IsShown(), id = r.row and (r.row.id or r.row.quest) }
	end
	return out
end
