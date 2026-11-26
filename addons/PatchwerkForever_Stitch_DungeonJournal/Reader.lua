local addonName, ns = ...;
if not ns.linked then return end;
---------------------------------------------------------------
-- The Dungeon Journal's quests, as a list to route through
---------------------------------------------------------------
-- DungeonJournal (ForeverDungeonJournal, by Exehn) lists each
-- dungeon's quests, and you tick the dungeons you mean to do. It
-- knows where each quest is picked up and handed in. This reads
-- that as the journal runs and gives it to Patchwerk Forever's
-- guides service as one more guide, so Routes (Thread) can lead
-- you from one quest giver to the next and Tracker (Thread) can
-- list them.
--
-- What is read, each time it is asked for, from the journal's own
-- tables in memory (its global ForeverDungeonJournal_NS and its
-- saved list of tracked dungeons):
--   * the dungeons you track in it, and their quests;
--   * where a quest starts and where it is handed in;
--   * the quests that must be done before another is offered;
--   * the spot its own map arrow is on, when it has one.
-- Whether you have a quest or have finished it is asked of the
-- game. Whether it is handed in, and whether it is one for this
-- character at all, is asked of the journal's own functions, as its
-- tracker asks them (with the game's answer when one is missing):
-- it counts a few quests the game does not (the Mallet of
-- Zul'Farrak, a choice between two quests, a quest done once), and
-- leaves out other classes' quests, quests no longer available, and
-- quests its RPG Mode keeps locked.
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
-- one nearest the one before. The stop that led last time keeps
-- the lead unless another is clearly nearer, so two stops about as
-- near as each other do not take turns as you walk.
--
-- The journal's own map arrow comes first, with one exception: the
-- journal points it at a quest's hand-in as soon as the quest is in
-- your log, finished or not. An arrow to a hand-in is followed only
-- once that quest is finished (seen 2026-11-18: Wailing Caverns
-- quests sent you to Nalpak and Ebru before their work was done).
-- An arrow on a listed stop (within 15 yards) brings that stop to
-- the front; elsewhere it is a stop of its own. While you are a
-- ghost the journal points it at your corpse; that is not a stop.
--
-- A quest that starts from an item (one a creature drops) has no
-- place to accept it, so it gets no stop until you hold it. A chain
-- step that is an item and not a quest (the Gnomeregan punch cards)
-- is passed over, as the journal does.
--
-- Skipping a stop (a click in Tracker (Thread)) lasts for the
-- session; Previous Step or /tracker back takes the last skip or
-- jump back, and the binding brings every skipped stop back when
-- nothing else is left.

local P = ns.Base;
local Guides = P.Guides;
local SOURCE = 'fdj';
local SECTION = 'Dungeon Journal';

ns:AddSetting({
	key     = 'djList';
	default = true;
	section = SECTION;
	name    = 'Route Dungeon Journal Quests';
	desc    = 'Offer the quests of the dungeons you track in the Dungeon Journal as a list to route through: where to accept each, and where to turn it in. Tracker (Thread) lists it and Routes (Thread) leads you along it once you select it.';
})
ns:AddSetting({
	key     = 'djLeads';
	default = false;
	section = SECTION;
	parent  = 'djList';
	name    = 'Dungeon Journal First';
	desc    = 'Make the Dungeon Journal list the main route, ahead of your leveling guide, whenever it has somewhere to send you. When disabled, your guide stays the main route and the list is followed only while you select it.';
})

local FOLD = 15;                        -- yards: the journal's arrow this near a listed stop is that stop
local NEARER = 0.72;                    -- (0.85 squared) how much nearer another stop must be to take the lead

local skipped = {};                     -- quests you skipped this session
local arrowSkipped;                     -- the spot of the journal's arrow, skipped (pointing it elsewhere ends that)
local undo = {};                        -- skips and jumps, the last one last, for Previous Step and /tracker back
local pinned;                           -- the quest you asked to go to first
local told = false;                     -- (the first skip of a session says how to take it back)
-- what was last given: its step number, its stops' quests in order (false for the arrow's own spot),
-- and the arrow's spot when the arrow leads
local last = { index = 0, order = {} };

local function Print(...)
	ns:Print('|cff7fd4a0Dungeon Journal:|r', ...)
end

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

local function HandedIn(id)
	local journal = Journal();
	if ( journal and type(journal.QuestTurnedIn) == 'function' ) then
		local ok, yes = pcall(journal.QuestTurnedIn, id);
		if ok then return yes == true end;
	end
	return Ask(C_QuestLog.IsQuestFlaggedCompleted, id) and true or false;
end
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

-- The journal's own word on a quest, when it has that function: a missing one, or one that fails, says nothing.
local function Says(journal, fn, ...)
	if ( type(journal[fn]) ~= 'function' ) then return nil end;
	local ok, yes = pcall(journal[fn], ...);
	if ok then return yes and true or false end;
	return nil;
end

-- Whether the journal lists a quest of a dungeon for this character, as its own tracker does: your
-- side, your class and professions, still available, and not locked by its RPG Mode.
local function ForMe(journal, name, quest, side)
	if not ForMySide(journal, quest, side) then return false end;
	if ( Says(journal, 'QuestCountsForCharacter', quest) == false ) then return false end;
	if Says(journal, 'IsQuestUnavailable', quest) then return false end;
	if ( name and Says(journal, 'RPGQuestHidden', name, quest) ) then return false end;
	return true;
end

-- A spot of the journal's ({ mapID, x, y, label }) as a place in the world, with its label.
local function Place(spot)
	if ( type(spot) ~= 'table' or not spot.mapID ) then return nil end;
	local map, x, y = Guides.WorldOf(spot.mapID, tonumber(spot.x), tonumber(spot.y));
	if not map then return nil end;
	return { map = map, x = x, y = y, label = type(spot.label) == 'string' and spot.label or nil,
		zone = Guides.ZoneName and Guides.ZoneName(spot.mapID) or nil };
end

local function Stop(quest, kind, words, place)
	local lines = { { text = words, done = false, kind = kind } };
	if place.label then lines[2] = { text = place.label, done = false } end;
	return { quest = quest, kind = kind, lines = lines, map = place.map, x = place.x, y = place.y, zone = place.zone };
end

-- Where a quest is picked up: its own spot, else the journal's spot for that quest. None for a quest
-- that starts from an item (the journal's spot for one of those can be where it is handed in).
local function StartPlace(journal, id, startMap, startItem)
	if startItem then return nil end;
	local starts = type(journal.QUEST_START_MAPS) == 'table' and journal.QUEST_START_MAPS or {};
	return Place(startMap) or Place(starts[id]);
end

-- Where one quest of a dungeon sends you now, or nothing.
local function StopFor(journal, quest)
	local id, name = quest.id, tostring(quest.name);
	local details = type(journal.QUEST_PREREQ_DETAILS) == 'table' and journal.QUEST_PREREQ_DETAILS or {};
	if Held(id) then
		if not Finished(id) then return nil end;                 -- (still to be done, inside)
		local place = Place(Ask(journal.TurnInSpotFor, quest));
		return place and Stop(id, 'turnin', 'Turn in: ' .. name, place) or nil;
	end
	-- not taken yet: a quest that must be done first comes before it
	local chains = type(journal.QUEST_PREREQ_CHAINS) == 'table' and journal.QUEST_PREREQ_CHAINS[id];
	for _, first in ipairs(type(chains) == 'table' and chains or {}) do
		if ( type(first) == 'table' and type(first.id) == 'number' and not first.itemStep and not HandedIn(first.id) ) then
			if Held(first.id) then return nil end;                -- (under way: nothing to fetch for it)
			local more = type(details[first.id]) == 'table' and details[first.id] or {};
			local place = StartPlace(journal, first.id, more.map, more.startItem);
			return place and Stop(id, 'accept', ('Accept: %s (needed for %s)'):format(tostring(first.name or first.id), name), place) or nil;
		end
	end
	local place = StartPlace(journal, id, quest.startMap, quest.startItem);
	return place and Stop(id, 'accept', 'Accept: ' .. name, place) or nil;
end

-- The quest the journal's arrow is for: the one a pin was opened for, else the quest of that title,
-- in your log first, then in the journal. nil when it cannot be told.
local function ArrowQuest(journal, spot)
	local id = tonumber(spot.fdjAutoQuest);
	if id then return id end;
	local title = spot.questTitle;
	if ( type(title) ~= 'string' ) then return nil end;
	local found;
	for _, dungeon in pairs(journal.DB) do
		for _, quest in ipairs(type(dungeon) == 'table' and type(dungeon.quests) == 'table' and dungeon.quests or {}) do
			if ( type(quest) == 'table' and type(quest.id) == 'number'
			and ( quest.name == title or quest.arrowName == title ) ) then
				if Held(quest.id) then return quest.id end;
				found = found or quest.id;
			end
		end
	end
	return found;
end

-- Whether to follow the journal's arrow: anywhere but a hand-in, and a hand-in once its quest is finished.
local function FollowArrow(journal, spot)
	if not spot.turnIn then return true end;
	local id = ArrowQuest(journal, spot);
	return id ~= nil and Held(id) and Finished(id);
end

-- Every stop of the dungeons you track, how many quests there are in all, how many are handed in, the
-- dungeons' names, and (for saying why there is no stop) how many have none and how many are skipped.
local function Stops(journal)
	local stops, total, done, inside, skips = {}, 0, 0, 0, 0;
	local side = Ask(UnitFactionGroup, 'player');
	local names = {};
	for _, name in ipairs(Tracked()) do
		local dungeon = journal.DB[name];
		if ( type(dungeon) == 'table' and not dungeon.previewOnly ) then
			names[#names + 1] = tostring(name);
			for _, quest in ipairs(type(dungeon.quests) == 'table' and dungeon.quests or {}) do
				if ( type(quest) == 'table' and type(quest.id) == 'number' and quest.name and not quest.repeatable
				and not quest.hideFromMainList and ForMe(journal, name, quest, side) ) then
					total = total + 1;
					if HandedIn(quest.id) then
						done = done + 1;
					elseif not skipped[quest.id] then
						local stop = StopFor(journal, quest);
						if stop then stops[#stops + 1] = stop else inside = inside + 1 end;
					else
						skips = skips + 1;
					end
				end
			end
		end
	end
	return stops, total, done, names, inside, skips;
end

-- The stops in the order to go: the one you asked for first, else the one that led last time unless
-- another on your continent is clearly nearer, then always the nearest to the one before, beginning
-- from where you stand. A stop on another continent comes after those on yours.
local function InOrder(stops)
	local px, py, here = Guides.Here();
	local at = { map = here, x = px, y = py };
	local left, out = {}, {};
	for _, stop in ipairs(stops) do left[#left + 1] = stop end
	local function Take(i)
		at = table.remove(left, i);
		out[#out + 1] = at;
	end
	local function Far(stop)
		return ( stop.x - px ) ^ 2 + ( stop.y - py ) ^ 2;
	end
	local first;
	for i, stop in ipairs(left) do
		if ( pinned and stop.quest == pinned ) then first = i; break end;
	end
	-- (a pin whose stop has gone, accepted or handed in, is let go)
	if ( pinned and not first ) then pinned = nil end;
	-- (the list is read all the time, followed or not: the lead is kept only against stops on your
	-- continent, so one picked far away an hour ago does not stay first)
	local keep = last.order[1] or last.order[2];
	if ( not first and keep and px ) then
		for i, stop in ipairs(left) do
			if ( stop.quest == keep and stop.map == here ) then first = i; break end;
		end
		if first then
			local mine = Far(left[first]);
			for _, stop in ipairs(left) do
				if ( stop.map == here and Far(stop) < mine * NEARER ) then first = nil; break end;
			end
		end
	end
	if first then Take(first) end;
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

-- The journal's arrow as a key: its continent and spot, to the yard.
local function ArrowKey(place)
	return ('%d:%d:%d'):format(place.map, math.floor(place.x + 0.5), math.floor(place.y + 0.5));
end

local function Read(count)
	if not ns:GetSetting('djList') then return nil end;
	local journal = Journal();
	if not journal then return nil end;
	local stops, total, done, names = Stops(journal);
	stops = InOrder(stops);
	-- the spot the journal's own map arrow is on comes first: you asked it to point there. On a listed
	-- stop it is that stop, which keeps its own words and can be skipped as any other.
	local arrow;
	local spot = Ask(journal.WaypointArrowTarget);
	local place = Place(spot);
	if ( place and not spot.corpse and FollowArrow(journal, spot) ) then
		arrow = ArrowKey(place);
		local near, nearest;
		for i, stop in ipairs(stops) do
			local d = ( stop.map == place.map ) and ( stop.x - place.x ) ^ 2 + ( stop.y - place.y ) ^ 2;
			if ( d and d <= FOLD ^ 2 and ( not nearest or d < nearest ) ) then near, nearest = i, d end;
		end
		if near then
			table.insert(stops, 1, table.remove(stops, near));
		elseif ( arrow ~= arrowSkipped ) then
			local words = type(spot.questTitle) == 'string' and spot.questTitle or place.label or 'Dungeon Journal map point';
			table.insert(stops, 1, { kind = 'place', map = place.map, x = place.x, y = place.y,
				lines = { { text = ( spot.turnIn and 'Turn in: ' or 'Go to: ' ) .. words, done = false, kind = 'place' } } });
		else
			arrow = nil;
		end
	end
	local now = stops[1];
	if not now then
		last = { index = 0, order = {} };
		return nil;
	end
	local index = math.min(math.max(total, 1), done + 1);
	local info = {
		guide = 'Dungeon Journal' .. ( #names == 1 and ( ': ' .. names[1] ) or '' ),
		-- (the arrow's own stop is one more than the quests: no line is numbered past the total)
		index = index, total = math.max(total, index + #stops - 1), quest = now.quest,
		kind = now.kind, lines = now.lines, map = now.map, x = now.x, y = now.y,
		key = ('%s:%s:%d:%d'):format(tostring(now.quest or 'arrow'), now.kind, math.floor(now.x + 0.5), math.floor(now.y + 0.5)),
		ahead = {}, after = {}, items = {},
	};
	local order = { now.quest or false };
	for i = 2, #stops do
		local stop = stops[i];
		order[i] = stop.quest or false;
		if ( i - 1 <= count ) then
			local step = { index = index + i - 1, kind = stop.kind, lines = stop.lines, map = stop.map, x = stop.x, y = stop.y, quest = stop.quest };
			info.ahead[#info.ahead + 1] = step;
			info.after[#info.after + 1] = step;
		end
	end
	last = { index = index, order = order, arrow = arrow };
	return info;
end

-- Moves the list, because you clicked. The step number counts the quests turned in, so it does not
-- move with a skip: the next number skips the stop that leads, and the stop shown next (the one you
-- clicked) leads after it; a later one brings that stop to the front; the same or an earlier number
-- (Previous Step, /tracker back) takes the last skip or jump back.
local function Go(index)
	local offset = index - last.index;
	if ( offset == 1 ) then
		local quest, arrow = last.order[1], last.arrow;
		if not ( quest or arrow ) then return false end;
		if quest then skipped[quest] = true end;
		if arrow then arrowSkipped = arrow end;
		undo[#undo + 1] = { quest = quest or nil, arrow = arrow, pinned = pinned };
		pinned = last.order[2] or nil;
		if not told then
			told = true;
			Print('A skipped stop stays skipped until you reload. Previous Step in the tracker, or /tracker back, brings it back.')
		end
		return true;
	elseif ( offset > 1 ) then
		local quest = last.order[offset + 1];
		if not quest then return false end;
		undo[#undo + 1] = { pinned = pinned };
		pinned = quest;
		return true;
	end
	local back = table.remove(undo);
	if not back then return false end;
	if back.quest then skipped[back.quest] = nil end;
	if ( back.arrow and arrowSkipped == back.arrow ) then arrowSkipped = nil end;
	pinned = back.quest or back.pinned;
	return true;
end

-- The quest of a step, as My Route keeps it: where the journal sends you for it now (to pick it up,
-- or to what must be done first), and its name. (Patchwerk Forever 2.6.0 and later.)
local function QuestOf(id)
	local journal = Journal();
	if not journal then return nil end;
	for name, dungeon in pairs(journal.DB) do
		for _, quest in ipairs(type(dungeon) == 'table' and type(dungeon.quests) == 'table' and dungeon.quests or {}) do
			if ( type(quest) == 'table' and quest.id == id ) then return journal, quest, name end;
		end
	end
	return nil;
end

if P.MyRoute then
	P.MyRoute:Kind(SOURCE, {
		Name = function(stop)
			local _, quest = QuestOf(stop.id);
			return quest and tostring(quest.name) or nil;
		end,
		Place = function(stop)
			local journal, quest, name = QuestOf(stop.id);
			if not journal then return nil end;
			-- (a quest of the other side, or one the journal does not list for you, is never routed to)
			if not ForMe(journal, name, quest, Ask(UnitFactionGroup, 'player')) then return nil end;
			local found = StopFor(journal, quest);
			if not found then return nil end;
			local label = found.lines[1] and found.lines[1].text;
			return found.map, found.x, found.y, label, found.zone;
		end,
	});
end

Guides:Register(SOURCE, {
	name = 'Dungeon Journal',
	Read = Read,
	Go = Go,
	-- (a choice to focus on while the journal is running and the list is enabled, even with nothing to say)
	Running = function() return Journal() ~= nil and ns:GetSetting('djList') and true or false end,
	Leads = function() return ns:GetSetting('djLeads') and true or false end,
	-- (a side list unless set to lead: with no guide running it is not followed until selected)
	Side = function() return not ns:GetSetting('djLeads') end,
});

---------------------------------------------------------------
-- A key or a gamepad button: route through the list, or stop
---------------------------------------------------------------
BINDING_HEADER_PATCHWERKFOREVER_DUNGEONJOURNAL = 'Patchwerk Forever: Dungeon Journal (Stitch)';
BINDING_NAME_PATCHWERKFOREVER_DUNGEONJOURNAL_ROUTE = 'Toggle Dungeon Journal Route';

-- Why the list is empty, in one sentence (only when asked: not on the reads many times a second).
local function Why()
	local journal = Journal();
	if not journal then
		local loaded = C_AddOns and C_AddOns.IsAddOnLoaded;
		if Ask(loaded, 'ForeverDungeonJournal') then
			return 'Dungeon Journal is running, but its quest data was not found. This addon may need an update.';
		end
		return 'Dungeon Journal is not running.';
	end
	if not ns:GetSetting('djList') then
		return 'Route Dungeon Journal Quests is disabled (/patchwerk config, Dungeon Journal (Stitch)).';
	end
	local _, total, done, names, inside, skips = Stops(journal);
	if ( #names == 0 ) then return 'No dungeon is tracked in the Dungeon Journal.' end;
	if ( total == 0 ) then return 'The tracked dungeons have no quests for your faction.' end;
	if ( done == total ) then return 'Every quest of your tracked dungeons is turned in.' end;
	return ('Nothing to route to right now: %d of %d turned in, %d in your quest log to finish in the dungeon, %d skipped.')
		:format(done, total, inside, skips);
end

local function Stopped()
	if not P.Choice:Is('guide', SOURCE) then return false end;
	P.Choice:Clear()
	Print('Back to your main route.')
	return true;
end

local function Started()
	local info = Guides:Read(0, SOURCE);
	-- (everything left was skipped: the skips are taken back, since you asked for the list)
	if ( not info and ( next(skipped) or arrowSkipped ) ) then
		wipe(skipped)
		wipe(undo)
		arrowSkipped, pinned = nil, nil;
		info = Guides:Read(0, SOURCE);
		if info then Print('Skipped stops are back on the list.') end;
	end
	if not info then
		Print(Why())
		return false;
	end
	P.Choice:Set('guide', SOURCE)
	local first = info.lines and info.lines[1] and info.lines[1].text or '';
	local stops = #last.order;
	if ( stops == 1 ) then
		Print(('Routing to 1 stop: %s.'):format(first))
	else
		Print(('Routing through %d stops. First: %s.'):format(stops, first))
	end
	return true;
end

function PatchwerkForever_Stitch_DungeonJournal_Route()
	if not Stopped() then Started() end;
end

local function Status()
	if not Journal() then return 'waiting: Dungeon Journal is not loaded' end;
	if not ns:GetSetting('djList') then return 'off' end;
	if not Guides:Read(0, SOURCE) then return 'on: no stops. ' .. Why() end;
	local stops = #last.order;
	return ('on: %d %s%s'):format(stops, stops == 1 and 'stop' or 'stops',
		P.Choice:Is('guide', SOURCE) and ', being followed' or '');
end

-- /patchwerk dj [on | off | status]: the same, from the chat
ns:RegisterFix('dj', {
	name    = 'Dungeon Journal quests as a route';
	addon   = 'ForeverDungeonJournal';
	status  = Status;
	command = function(args)
		local word = tostring(args or ''):lower():match('^%s*(%S*)');
		if ( word == '' ) then
			PatchwerkForever_Stitch_DungeonJournal_Route()
		elseif ( word == 'on' or word == 'start' ) then
			if not P.Choice:Is('guide', SOURCE) then Started() end;
		elseif ( word == 'off' or word == 'stop' ) then
			if not Stopped() then Print('The Dungeon Journal list is not being followed.') end;
		elseif ( word == 'status' ) then
			Print(Status())
		else
			Print('Usage: /patchwerk dj [on | off | status]')
		end
	end;
})
