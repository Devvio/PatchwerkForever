-- Thread (Tracker): the quests you track, as the game has them.
--
-- The game keeps a list of the quests you have chosen to track (the "watch list"), and for each quest
-- in your log its name, level, the zone it is filed under, and its objectives with how far each has
-- got. This reads them and gives the tracker's frame a plain list to draw. Nothing is changed here:
-- tracking and untracking stay the game's own, done from its quest log.
--
-- ns.ReadQuests() gives
--     { quests = { quest, ... }, held = how many quests you have, room = how many you may have }
-- and a quest is
--     { id, title, level, zone, done (ready to hand in), failed,
--       lines = { { text, done }, ... }  its objectives, or one line saying it is ready }
local ADDON, ns = ...
if not ns.linked then return end

-- Asks the game; an error or a function this client lacks gives nothing.
local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

-- The zone each quest is filed under in the quest log: the log is a list of headings, each followed
-- by its quests.
local function Zones()
	local zones, held, heading = {}, 0, nil
	local entries = Ask(C_QuestLog.GetNumQuestLogEntries) or 0
	for i = 1, entries do
		local info = Ask(C_QuestLog.GetInfo, i)
		if type(info) == 'table' then
			if info.isHeader then
				heading = info.title
			elseif info.questID and not info.isHidden then
				zones[info.questID] = heading
				held = held + 1
			end
		end
	end
	return zones, held
end

local function Lines(id, done)
	local lines = {}
	for _, o in ipairs(Ask(C_QuestLog.GetQuestObjectives, id) or {}) do
		if type(o) == 'table' and type(o.text) == 'string' and o.text ~= '' then
			lines[#lines + 1] = { text = o.text, done = o.finished and true or false }
		end
	end
	if done then
		-- every objective met: what is left is to hand it in
		local index = Ask(C_QuestLog.GetLogIndexForQuestID, id)
		local say = index and Ask(GetQuestLogCompletionText, index)
		if type(say) ~= 'string' or say == '' then say = 'Ready to hand in' end
		for _, line in ipairs(lines) do line.done = true end
		lines[#lines + 1] = { text = say, done = true, ready = true }
	end
	return lines
end

function ns.ReadQuests()
	local zones, held = Zones()
	local quests = {}
	local watched = Ask(C_QuestLog.GetNumQuestWatches) or 0
	for i = 1, watched do
		local id = Ask(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
		if id then
			local index = Ask(C_QuestLog.GetLogIndexForQuestID, id)
			local info = index and Ask(C_QuestLog.GetInfo, index)
			info = type(info) == 'table' and info or {}
			local done = Ask(C_QuestLog.IsComplete, id) and true or false
			quests[#quests + 1] = {
				id = id,
				title = info.title or Ask(C_QuestLog.GetTitleForQuestID, id) or ('Quest ' .. tostring(id)),
				level = tonumber(info.difficultyLevel) or tonumber(info.level),
				zone = zones[id],
				done = done,
				failed = Ask(C_QuestLog.IsFailed, id) and true or false,
				lines = Lines(id, done),
			}
		end
	end
	return { quests = quests, held = held, room = Ask(C_QuestLog.GetMaxNumQuestsCanAccept) }
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
ns.AddSection('quests', 50, function()
	local data = ns.ReadQuests()
	local blocks = {}
	for _, quest in ipairs(data.quests) do
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
		if quest.failed then title = title .. ' (failed)' end
		local lines = {}
		for _, line in ipairs(quest.lines) do
			-- (an objective that is done goes, when asked to; a quest that is all done keeps only its last word)
			if (not line.done or line.ready or ns.Get('doneLines')) and not (quest.done and not line.ready) then
				lines[#lines + 1] = { text = line.text, done = line.done }
			end
		end
		blocks[#blocks + 1] = { key = quest.id, title = title, r = r, g = g, b = b, lines = lines }
	end
	local note = data.room and ('%d/%d'):format(data.held, data.room) or tostring(data.held)
	return { title = 'Quests', note = note, blocks = blocks }
end)
