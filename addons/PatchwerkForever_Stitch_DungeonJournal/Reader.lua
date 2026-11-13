local addonName, ns = ...;
if not ns.linked then return end;
---------------------------------------------------------------
-- The Dungeon Journal's quests, as a list to route through
---------------------------------------------------------------
-- DungeonJournal (ForeverDungeonJournal, by Exehn) lists each
-- dungeon's quests, and you tick the dungeons you mean to do. It
-- knows where each quest is picked up and handed in. This reads
-- that as the journal runs and gives it to Patchwerk Forever's
-- guides service as one more guide, so Thread (Routes) can lead
-- you from one quest giver to the next and Thread (Tracker) can
-- list them.
--
-- What is read, each time it is asked for, from the journal's own
-- tables in memory (its global ForeverDungeonJournal_NS and its
-- saved list of tracked dungeons):
--   * the dungeons you track in it, and their quests;
--   * where a quest starts and where it is handed in;
--   * the quests that must be done before another is offered;
--   * the spot its own map arrow is on, when it has one.
-- Whether you have a quest, have finished it or have handed it in
-- is asked of the game.
--
-- Nothing of the journal is changed, and nothing of it is kept:
-- its places and names are shown from its tables at that moment
-- and are not stored in ours or shipped with this addon. Every
-- read is wary: a table that is not there, or not shaped as
-- expected, gives no list and no error.
--
-- A stop is a place to go for one quest: where to accept it, or
-- where to hand it in once it is done. A quest you hold and have
-- not finished has no stop: its work is inside the dungeon. The
-- stops are put in a short order, the nearest first and each next
-- one nearest the one before.

local P = ns.Base;
local Guides = P.Guides;
local SOURCE = 'fdj';
local SECTION = 'Dungeon Journal';

ns:AddSetting({
	key     = 'djList';
	default = true;
	section = SECTION;
	name    = 'Route Dungeon Journal Quests';
	desc    = 'Offer the quests of the dungeons you track in the Dungeon Journal as a list to route through: where to accept each, and where to turn it in. Thread (Tracker) lists it and Thread (Routes) leads you along it once you select it.';
})
ns:AddSetting({
	key     = 'djLeads';
	default = false;
	section = SECTION;
	parent  = 'djList';
	name    = 'Dungeon Journal Before RestedXP';
	desc    = 'Make the Dungeon Journal list the main route, ahead of your levelling guide, whenever it has somewhere to send you. When disabled, your guide stays the main route and the list is followed only while you select it.';
})

local skipped, skipOrder = {}, {};     -- quests you skipped this session, and in what order
local pinned;                          -- the quest you asked to go to first
local last = { index = 0, order = {} };-- what was last given: its step number, and its stops' quests in order

local function Ask(fn, ...)
	if ( type(fn) ~= 'function' ) then return nil end;
	local ok, a, b, c = pcall(fn, ...);
	if ok then return a, b, c end;
	return nil;
end

local function Journal()
	local journal = rawget(_G, 'ForeverDungeonJournal_NS');
	if ( type(journal) == 'table' and type(journal.DB) == 'table' ) then return journal end;
	return nil;
end

-- The dungeons ticked in the journal, in its order.
local function Tracked()
	local saved = rawget(_G, 'ForeverDungeonJournalCharacterDB');
	local list = type(saved) == 'table' and saved.trackedDungeons;
	return type(list) == 'table' and list or {};
end

local function HandedIn(id) return Ask(C_QuestLog.IsQuestFlaggedCompleted, id) and true or false end
local function Held(id)
	local index = Ask(C_QuestLog.GetLogIndexForQuestID, id);
	return index ~= nil and index ~= 0;
end
local function Finished(id) return Ask(C_QuestLog.IsComplete, id) and true or false end

local function ForMySide(journal, quest, side)
	if ( type(journal.QuestMatchesFaction) == 'function' ) then
		local ok, yes = pcall(journal.QuestMatchesFaction, quest, side);
		if ok then return yes and true or false end;
	end
	local faction = quest.faction;
	return faction == nil or faction == 'Both' or faction == 'Neutral' or faction == side;
end

-- A spot of the journal's ({ mapID, x, y, label }) as a place in the world, with its label.
local function Place(spot)
	if ( type(spot) ~= 'table' or not spot.mapID ) then return nil end;
	local map, x, y = Guides.WorldOf(spot.mapID, tonumber(spot.x), tonumber(spot.y));
	if not map then return nil end;
	return { map = map, x = x, y = y, label = type(spot.label) == 'string' and spot.label or nil };
end

local function Stop(quest, kind, words, place)
	local lines = { { text = words, done = false, kind = kind } };
	if place.label then lines[2] = { text = place.label, done = false } end;
	return { quest = quest, kind = kind, lines = lines, map = place.map, x = place.x, y = place.y };
end

-- Where one quest of a dungeon sends you now, or nothing.
local function StopFor(journal, quest)
	local id, name = quest.id, tostring(quest.name);
	local starts = type(journal.QUEST_START_MAPS) == 'table' and journal.QUEST_START_MAPS or {};
	if Held(id) then
		if not Finished(id) then return nil end;                 -- (still to be done, inside)
		local place = Place(Ask(journal.TurnInSpotFor, quest));
		return place and Stop(id, 'turnin', 'Turn in: ' .. name, place) or nil;
	end
	-- not taken yet: a quest that must be done first comes before it
	local chains = type(journal.QUEST_PREREQ_CHAINS) == 'table' and journal.QUEST_PREREQ_CHAINS[id];
	for _, first in ipairs(type(chains) == 'table' and chains or {}) do
		if ( type(first) == 'table' and type(first.id) == 'number' and not HandedIn(first.id) ) then
			if Held(first.id) then return nil end;                -- (under way: nothing to fetch for it)
			local place = Place(starts[first.id]);
			return place and Stop(id, 'accept', ('Accept: %s (needed for %s)'):format(tostring(first.name or first.id), name), place) or nil;
		end
	end
	local place = Place(quest.startMap) or Place(starts[id]);
	return place and Stop(id, 'accept', 'Accept: ' .. name, place) or nil;
end

-- Every stop of the dungeons you track, how many quests there are in all, and how many are handed in.
local function Stops(journal)
	local stops, total, done = {}, 0, 0;
	local side = Ask(UnitFactionGroup, 'player');
	local names = {};
	for _, name in ipairs(Tracked()) do
		local dungeon = journal.DB[name];
		if ( type(dungeon) == 'table' and not dungeon.previewOnly ) then
			names[#names + 1] = tostring(name);
			for _, quest in ipairs(type(dungeon.quests) == 'table' and dungeon.quests or {}) do
				if ( type(quest) == 'table' and type(quest.id) == 'number' and quest.name and not quest.repeatable
				and not quest.hideFromMainList and ForMySide(journal, quest, side) ) then
					total = total + 1;
					if HandedIn(quest.id) then
						done = done + 1;
					elseif not skipped[quest.id] then
						local stop = StopFor(journal, quest);
						if stop then stops[#stops + 1] = stop end;
					end
				end
			end
		end
	end
	return stops, total, done, names;
end

-- The stops in the order to go: the one you asked for first, then always the nearest to the one
-- before, beginning from where you stand. A stop on another continent comes after those on yours.
local function InOrder(stops)
	local px, py, here = Guides.Here();
	local at = { map = here, x = px, y = py };
	local left, out = {}, {};
	for _, stop in ipairs(stops) do left[#left + 1] = stop end
	local function Take(i)
		at = table.remove(left, i);
		out[#out + 1] = at;
	end
	for i, stop in ipairs(left) do
		if ( pinned and stop.quest == pinned ) then Take(i); break end;
	end
	while ( #left > 0 ) do
		local best, far;
		for i, stop in ipairs(left) do
			local d = math.huge;
			if ( at.x and stop.map == at.map ) then
				d = ( stop.x - at.x ) ^ 2 + ( stop.y - at.y ) ^ 2;
			elseif ( at.x and stop.map ~= at.map ) then
				d = 1e12 + i;                                   -- (another continent: after the ones here, in the journal's order)
			end
			if ( not far or d < far ) then best, far = i, d end;
		end
		Take(best)
	end
	return out;
end

local function Read(count)
	if not ns:GetSetting('djList') then return nil end;
	local journal = Journal();
	if not journal then return nil end;
	local stops, total, done, names = Stops(journal);
	stops = InOrder(stops);
	-- the spot the journal's own map arrow is on comes first: you asked it to point there
	local spot = Ask(journal.WaypointArrowTarget);
	local place = Place(spot);
	if place then
		local words = type(spot.questTitle) == 'string' and spot.questTitle or place.label or 'Dungeon Journal map point';
		table.insert(stops, 1, { kind = 'place', map = place.map, x = place.x, y = place.y,
			lines = { { text = ( spot.turnIn and 'Turn in: ' or 'Go to: ' ) .. words, done = false, kind = 'place' } } });
	end
	local now = stops[1];
	if not now then
		last = { index = 0, order = {} };
		return nil;
	end
	local index = math.min(math.max(total, 1), done + 1);
	local info = {
		guide = 'Dungeon Journal' .. ( #names == 1 and ( ': ' .. names[1] ) or '' ),
		index = index, total = math.max(total, index),
		kind = now.kind, lines = now.lines, map = now.map, x = now.x, y = now.y,
		key = ('%s:%s:%d:%d'):format(tostring(now.quest or 'arrow'), now.kind, math.floor(now.x + 0.5), math.floor(now.y + 0.5)),
		ahead = {}, after = {}, items = {},
	};
	local order = { now.quest or false };
	for i = 2, #stops do
		local stop = stops[i];
		order[i] = stop.quest or false;
		if ( i - 1 <= count ) then
			local step = { index = index + i - 1, kind = stop.kind, lines = stop.lines, map = stop.map, x = stop.x, y = stop.y };
			info.ahead[#info.ahead + 1] = step;
			info.after[#info.after + 1] = step;
		end
	end
	last = { index = index, order = order };
	return info;
end

-- Moves the list, because you clicked: the next step number skips the stop you are on; a later one
-- brings that stop to the front; an earlier one takes the last skip back.
local function Go(index)
	local offset = index - last.index;
	if ( offset == 1 ) then
		local quest = last.order[1];
		if not quest then return false end;                   -- (the journal's own map point: cleared in the journal)
		skipped[quest] = true;
		skipOrder[#skipOrder + 1] = quest;
		if ( pinned == quest ) then pinned = nil end;
		return true;
	elseif ( offset > 1 ) then
		local quest = last.order[offset + 1];
		if not quest then return false end;
		pinned = quest;
		return true;
	elseif ( offset < 0 ) then
		local quest = table.remove(skipOrder);
		if not quest then return false end;
		skipped[quest] = nil;
		pinned = quest;
		return true;
	end
	return false;
end

Guides:Register(SOURCE, {
	name = 'Dungeon Journal',
	Read = Read,
	Go = Go,
	Leads = function() return ns:GetSetting('djLeads') and true or false end,
});

---------------------------------------------------------------
-- A key or a gamepad button: route through the list, or stop
---------------------------------------------------------------
BINDING_HEADER_PATCHWERKFOREVER_DUNGEONJOURNAL = 'Patchwerk Forever: Stitch (Dungeon Journal)';
BINDING_NAME_PATCHWERKFOREVER_DUNGEONJOURNAL_ROUTE = 'Route Through Dungeon Journal Quests';

function PatchwerkForever_Stitch_DungeonJournal_Route()
	local Choice = P.Choice;
	if Choice:Is('guide', SOURCE) then
		Choice:Clear()
		ns:Print('Dungeon Journal: back to your main route.')
		return;
	end
	if not Guides:Read(0, SOURCE) then
		ns:Print(Journal() and 'Dungeon Journal: nothing to route to. Track a dungeon in the journal first, or every quest is done.'
			or 'Dungeon Journal is not running.')
		return;
	end
	Choice:Set('guide', SOURCE)
	ns:Print('Dungeon Journal: routing through the quests of your tracked dungeons.')
end

-- /patchwerk dj: the same, from the chat
ns:RegisterFix('dj', {
	name    = 'Dungeon Journal quests as a route';
	addon   = 'ForeverDungeonJournal';
	status  = function()
		if not Journal() then return 'waiting: Dungeon Journal is not loaded' end;
		if not ns:GetSetting('djList') then return 'off' end;
		return P.Choice:Is('guide', SOURCE) and 'on, and being followed' or 'on';
	end;
	command = function() PatchwerkForever_Stitch_DungeonJournal_Route() end;
})
