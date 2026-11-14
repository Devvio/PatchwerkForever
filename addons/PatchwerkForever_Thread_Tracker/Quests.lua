-- Thread (Tracker): the quests you track, as the game has them, and the section that lists them.
--
-- The game keeps a list of the quests you have chosen to track (the "watch list"), and for each quest
-- in your log its name, level, the zone it is filed under, and its objectives with how far each has
-- got. This reads them and gives the tracker's frame its blocks. Tracking and untracking stay the
-- game's own; nothing here changes the watch list.
--
-- ns.ReadQuests() gives
--     { quests = { quest, ... }, held = how many quests you have, room = how many you may have }
-- and a quest is
--     { id, title, level, zone, done (ready to hand in), failed, tag ("Elite", "Daily" ...),
--       left = seconds left on a timed quest, yards = how far, rank = the distance it is sorted by
--       (Places.lua), followed = it is the one being followed,
--       lines = { { text, done, have, need } ... }  its objectives, or one line saying it is ready }
--
-- How they are listed is a setting:
--     zone    under the zone each is filed in, the zone you are in first, nearest first within a zone
--     near    one list, nearest first
--     game    the order you tracked them in
--     ready   the ones ready to hand in first, then by zone
-- A quest that is ready can leave the list for a short group of its own at the foot (a setting).
local ADDON, ns = ...
if not ns.linked then return end

ns.questOrder = {}           -- the quests in the order they are listed, when last drawn

-- Asks the game; an error or a function this client lacks gives nothing.
local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

-- The zone each quest is filed under in the quest log (the log is a list of headings, each followed
-- by its quests), the order of the zones, and how many quests you hold.
local function Zones()
	local zones, order, held, heading = {}, {}, 0, nil
	local entries = Ask(C_QuestLog.GetNumQuestLogEntries) or 0
	for i = 1, entries do
		local info = Ask(C_QuestLog.GetInfo, i)
		if type(info) == 'table' then
			if info.isHeader then
				heading = info.title
				order[#order + 1] = heading
			elseif info.questID and not info.isHidden then
				zones[info.questID] = heading
				held = held + 1
			end
		end
	end
	return zones, order, held
end

local function Lines(id, done)
	local lines = {}
	for _, o in ipairs(Ask(C_QuestLog.GetQuestObjectives, id) or {}) do
		if type(o) == 'table' and type(o.text) == 'string' and o.text ~= '' then
			lines[#lines + 1] = { text = o.text, done = o.finished and true or false,
				have = tonumber(o.numFulfilled), need = tonumber(o.numRequired) }
		end
	end
	if done then
		-- every objective met: what is left is to hand it in
		local index = Ask(C_QuestLog.GetLogIndexForQuestID, id)
		local say = index and Ask(GetQuestLogCompletionText, index)
		if type(say) ~= 'string' or say == '' then say = 'Ready to turn in' end
		for _, line in ipairs(lines) do line.done = true end
		lines[#lines + 1] = { text = say, done = true, ready = true }
	end
	return lines
end

-- What kind of quest it is, in a word: elite, dungeon, raid, daily, for a group.
local function Tag(id, info)
	local overrides = rawget(_G, 'QuestUtilsOverrides')
	local said = type(overrides) == 'table' and Ask(overrides.GetQuestTagText, id)
	if type(said) == 'string' and said ~= '' then
		return (said:gsub('^%((.*)%)$', '%1'))
	end
	if info.frequency == 1 or (Enum and Enum.QuestFrequency and info.frequency == Enum.QuestFrequency.Daily) then return 'Daily' end
	if tonumber(info.suggestedGroup) and info.suggestedGroup > 1 then return 'Group' end
	return nil
end

function ns.ReadQuests()
	local zones, order, held = Zones()
	local quests = {}
	local followed = ns.Marked and ns.Marked()
	local watched = Ask(C_QuestLog.GetNumQuestWatches) or 0
	for i = 1, watched do
		local id = Ask(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
		if id then
			local index = Ask(C_QuestLog.GetLogIndexForQuestID, id)
			local info = index and Ask(C_QuestLog.GetInfo, index)
			info = type(info) == 'table' and info or {}
			local done = Ask(C_QuestLog.IsComplete, id) and true or false
			local total, gone = Ask(C_QuestLog.GetTimeAllowed, id)
			quests[#quests + 1] = {
				id = id, watch = i,
				title = info.title or Ask(C_QuestLog.GetTitleForQuestID, id) or ('Quest ' .. tostring(id)),
				level = tonumber(info.difficultyLevel) or tonumber(info.level),
				zone = zones[id],
				done = done,
				failed = Ask(C_QuestLog.IsFailed, id) and true or false,
				tag = Tag(id, info),
				left = (tonumber(total) and total > 0) and math.max(0, total - (tonumber(gone) or 0)) or nil,
				yards = ns.QuestYards(id),
				rank = ns.QuestRank(id),
				followed = followed == id,
				lines = Lines(id, done),
			}
		end
	end
	return { quests = quests, zones = order, held = held, room = Ask(C_QuestLog.GetMaxNumQuestsCanAccept) }
end

-- The game's colour for a quest of this level, as red, green, blue; nothing when it will not say.
function ns.LevelColour(level)
	if not level then return nil end
	local colour = Ask(GetQuestDifficultyColor, level)
	if type(colour) == 'table' and colour.r then return colour.r, colour.g, colour.b end
	return nil
end

---------------------------------------------------------------------------
-- The section of the tracker (Frame.lua)
---------------------------------------------------------------------------
-- An objective's colour by how far it has got: red, through yellow, to green.
local function Progress(have, need)
	local part = math.max(0, math.min(1, have / need))
	if part < 0.5 then
		local t = part * 2
		return 1, 0.35 + 0.5 * t, 0.3
	end
	local t = (part - 0.5) * 2
	return 1 - 0.55 * t, 0.85 + 0.05 * t, 0.3 + 0.15 * t
end

local function Clock(seconds)
	seconds = math.floor(seconds)
	if seconds >= 3600 then return ('%d:%02d:%02d'):format(seconds / 3600, seconds / 60 % 60, seconds % 60) end
	return ('%d:%02d'):format(seconds / 60, seconds % 60)
end

-- One quest as a block of the tracker. brief: its name and where to hand it in, no more.
local function BlockOf(quest, brief)
	ns.questOrder[#ns.questOrder + 1] = quest.id         -- (the order on screen, for the next and previous quest: Actions.lua)
	local r, g, b
	if quest.failed then
		r, g, b = 0.9, 0.25, 0.25
	elseif quest.done then
		r, g, b = ns.RGB(ns.Get('lookDone'))
	elseif ns.Get('titleByLevel') then
		r, g, b = ns.LevelColour(quest.level)
	end
	if not r then r, g, b = ns.RGB(ns.Get('lookTitle')) end
	local title = quest.title
	if ns.Get('levels') and quest.level then title = ('[%d] %s'):format(quest.level, title) end
	if ns.Get('kinds') and quest.tag then title = title .. ' (' .. quest.tag .. ')' end
	if quest.failed then title = title .. ' (Failed)' end
	local lines = {}
	for _, line in ipairs(quest.lines) do
		-- (an objective that is done goes, when asked to; a quest that is all done keeps only its last word)
		if (not line.done or line.ready or ns.Get('doneLines')) and not (quest.done and not line.ready) then
			local each = { text = line.text, done = line.done }
			if ns.Get('progress') and not line.done and line.have and line.need and line.need > 1 then
				each.r, each.g, each.b = Progress(line.have, line.need)
			end
			lines[#lines + 1] = each
		end
	end
	if quest.left and not quest.done then
		lines[#lines + 1] = { text = 'Time left: ' .. Clock(quest.left), r = 1, g = quest.left < 60 and 0.3 or 0.8, b = 0.3 }
	end
	if ns.PartyLine and ns.Get('party') and not brief then
		local with = ns.PartyLine(quest.id)
		if with then lines[#lines + 1] = { text = with, r = 0.55, g = 0.75, b = 1 } end
	end
	return { key = quest.id, title = title, r = r, g = g, b = b, lines = lines, mark = quest.followed,
		note = ns.Get('distance') and ns.YardsText(quest.yards) or nil,
		click = function(button, block) ns.QuestClick(quest, button, block) end }
end

-- (by the distance held for sorting, not the one shown: rows do not swap each time two distances cross)
local function Nearer(a, b)
	if a.rank and b.rank then
		if a.rank ~= b.rank then return a.rank < b.rank end
	elseif a.rank or b.rank then
		return a.rank ~= nil
	end
	return a.watch < b.watch
end

local function ZoneHeading(name)
	local r, g, b = ns.RGB(ns.Get('lookHeader'))
	return { key = 'zone:' .. name, title = name, small = true, r = r * 0.85, g = g * 0.85, b = b * 0.85 }
end

ns.AddSection('quests', 50, function()
	ns.questOrder = {}
	if not ns.Get('quests') then return nil end
	local data = ns.ReadQuests()
	local order = ns.Get('order') or 'zone'
	local apart = ns.Get('readyGroup')
	local open, ready, tick = {}, {}, false
	for _, quest in ipairs(data.quests) do
		if quest.left then tick = true end
		if quest.done and apart then ready[#ready + 1] = quest else open[#open + 1] = quest end
	end
	if ns.Get('distance') and #data.quests > 0 then tick = true end
	local blocks = {}
	if order == 'near' then
		table.sort(open, Nearer)
		for _, quest in ipairs(open) do blocks[#blocks + 1] = BlockOf(quest) end
	elseif order == 'game' then
		for _, quest in ipairs(open) do blocks[#blocks + 1] = BlockOf(quest) end
	else
		-- by zone: the one you are in first, the others in the quest log's order
		local here = Ask(GetRealZoneText) or Ask(GetZoneText)
		local byZone, names = {}, {}
		for _, quest in ipairs(open) do
			local zone = quest.zone or 'Elsewhere'
			if not byZone[zone] then
				byZone[zone] = {}
				names[#names + 1] = zone
			end
			table.insert(byZone[zone], quest)
		end
		local rank = {}
		for i, zone in ipairs(data.zones) do rank[zone] = i end
		table.sort(names, function(a, b)
			if (a == here) ~= (b == here) then return a == here end
			return (rank[a] or 999) < (rank[b] or 999)
		end)
		if order == 'ready' then
			local first = {}
			for _, quest in ipairs(open) do
				if quest.done then first[#first + 1] = quest end
			end
			table.sort(first, Nearer)
			for _, quest in ipairs(first) do blocks[#blocks + 1] = BlockOf(quest) end
		end
		for _, zone in ipairs(names) do
			local list = {}
			for _, quest in ipairs(byZone[zone]) do
				if not (order == 'ready' and quest.done) then list[#list + 1] = quest end
			end
			if #list > 0 then
				table.sort(list, Nearer)
				if #names > 1 or order == 'ready' then blocks[#blocks + 1] = ZoneHeading(zone) end
				for _, quest in ipairs(list) do blocks[#blocks + 1] = BlockOf(quest) end
			end
		end
	end
	if #ready > 0 then
		table.sort(ready, Nearer)
		blocks[#blocks + 1] = ZoneHeading('Ready to Turn In')
		for _, quest in ipairs(ready) do blocks[#blocks + 1] = BlockOf(quest, true) end
	end
	local note = data.room and ('%d/%d'):format(data.held, data.room) or tostring(data.held)
	return { title = 'Quests', note = note, blocks = blocks, tick = tick }
end)
