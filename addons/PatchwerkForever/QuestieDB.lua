local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- QuestDB: where quests are, from QuestieDB
---------------------------------------------------------------
-- QuestieDB (the database addon that comes with Questie since
-- Questie 12) has a public interface, LibQuestieDB: every
-- quest's givers, turn-ins and objectives, and where every NPC
-- and object stands. Our tools ask here, and here asks it; with
-- QuestieDB not installed (or of a contract this was not written
-- for) every answer is nothing, and the game's own quest marks
-- are used as before. Nothing of QuestieDB's is changed: no
-- correction is registered, no cache dropped.
--
--     QuestDB:Ready()                    true when QuestieDB can be asked
--     QuestDB.Spots(questID, mode, obj)  the places for a quest, and the mode found:
--                                        'giver' (not in your log), 'turnin' (done),
--                                        'objective' (what is still to do); mode
--                                        forces one; obj: one objective's number
--     QuestDB.Place(questID, mode, obj)  the nearest of those spots: map, x, y
--     QuestDB.Givers()                   the quest givers on your continent with a
--                                        quest you can take now
--     QuestDB.NpcSpots(npc), NpcLevels   where a creature stands, and its levels
--     QuestDB.ItemDrops(item)            the creatures that drop an item, with
--                                        Wowhead's drop rate where QuestieDB has one
--     QuestDB.FindItem(text)             an item by id, link or name
--
-- A spot is { map, x, y, name = what stands there }, in the
-- game's world coordinates (as Guides.WorldOf gives them).
-- QuestieDB's spawn points are percentages of a zone's map, keyed
-- by area: the area is turned into the game's map number with
-- QuestieDB's own table for that (its ZoneDB support data).

local QuestDB = { CONTRACT = 4, enabled = true };
P.QuestDB = QuestDB;

local ENTITIES = 25         -- NPCs or objects looked at for one objective, at most
local SPOTS = 400           -- spots kept for one quest, at most
local STALE = 10            -- seconds a quest's spots are kept while nothing in your log changes
local STICK = 80            -- yards nearer a new spot must be before the one gone to is let go

local lib, refused;

-- QuestieDB's interface, or nil. A contract it does not support is said once.
local function Lib()
	if lib then return lib end;
	if refused then return nil end;
	local found = rawget(_G, 'LibQuestieDB');
	if ( type(found) ~= 'table' or type(found.RequireContract) ~= 'function' ) then return nil end;
	local ok, yes, why = pcall(found.RequireContract, QuestDB.CONTRACT);
	if not ( ok and yes ) then
		refused = true;
		ns.Say(('QuestieDB is installed but cannot be used: %s'):format(tostring(why or yes)))
		return nil;
	end
	lib = found;
	return lib;
end

function QuestDB:Ready()
	return QuestDB.enabled and Lib() ~= nil;
end

-- A tool's setting turns it off and on (Routes: Use QuestieDB).
function QuestDB:SetEnabled(on)
	QuestDB.enabled = on and true or false;
	QuestDB.Forget();
end

-- One field of an entity, or nil where QuestieDB errs.
local function Get(kind, id, field)
	local entity = lib and lib[kind];
	local fn = entity and entity[field];
	if ( type(fn) ~= 'function' or type(id) ~= 'number' ) then return nil end;
	local ok, value = pcall(fn, id);
	if ok then return value end;
	return nil;
end
QuestDB.Get = Get;

---------------------------------------------------------------
-- Areas to maps
---------------------------------------------------------------
local areaMap;

local function Decode(source)
	if ( type(source) == 'table' ) then return source end;
	if ( type(source) ~= 'string' ) then return nil end;
	local chunk = loadstring(source);
	if not chunk then return nil end;
	local ok, value = pcall(chunk);
	return ok and type(value) == 'table' and value or nil;
end

-- The game's map number for one of QuestieDB's areas, or nil.
local function MapOfArea(area)
	if not areaMap then
		areaMap = {};
		local support = lib and lib.Support;
		local ok, zones = false, nil;
		if ( type(support) == 'table' and type(support.Get) == 'function' ) then
			ok, zones = pcall(support.Get, 'ZoneDB');
		end
		local private = ok and type(zones) == 'table' and zones.private;
		if ( type(private) == 'table' ) then
			for _, name in ipairs({ 'areaIdToUiMapId', 'areaIdToUiMapIdOverride' }) do
				for a, m in pairs(Decode(private[name]) or {}) do areaMap[a] = m end;
			end
			-- (a part of a zone that has no map of its own: its zone's)
			local parents = Decode(private.subZoneToParentZone) or {};
			for a, parent in pairs(Decode(private.subZoneToParentZoneOverride) or {}) do parents[a] = parent end;
			for a, parent in pairs(parents) do
				if ( areaMap[a] == nil and areaMap[parent] ) then areaMap[a] = areaMap[parent] end;
			end
		end
	end
	local m = areaMap[area];
	if ( type(m) == 'number' and m > 0 ) then return m end;
	return nil;
end

---------------------------------------------------------------
-- Where an NPC or object stands
---------------------------------------------------------------
local where = { Npc = {}, Object = {} };

-- The spots of one NPC or object (kind 'Npc' or 'Object'): a list, perhaps empty. Kept.
local function Where(kind, id)
	local known = where[kind][id];
	if known then return known end;
	local list = {};
	local name = Get(kind, id, 'name');
	local function Add(area, x, y)
		if ( type(x) ~= 'number' or type(y) ~= 'number' or x < 0 or y < 0 ) then return end;  -- (-1, -1: inside an instance)
		local uiMap = MapOfArea(area);
		local map, wx, wy = P.Guides.WorldOf(uiMap, x / 100, y / 100);
		if map then list[#list + 1] = { map, wx, wy, name = name } end;
	end
	for area, points in pairs(Get(kind, id, 'spawns') or {}) do
		for _, point in ipairs(type(points) == 'table' and points or {}) do Add(area, point[1], point[2]) end;
	end
	-- (one that only walks a path: where each of its paths begins)
	if ( #list == 0 ) then
		for area, paths in pairs(Get(kind, id, 'waypoints') or {}) do
			for _, path in ipairs(type(paths) == 'table' and paths or {}) do
				local first = type(path) == 'table' and path[1];
				if ( type(first) == 'table' ) then Add(area, first[1], first[2]) end;
			end
		end
	end
	where[kind][id] = list;
	return list;
end

-- Whether an NPC is friendly to your side (one QuestieDB does not say of is taken as friendly).
local function Friendly(npc)
	local to = Get('Npc', npc, 'friendlyToFaction');
	if ( type(to) ~= 'string' ) then return true end;
	local side = UnitFactionGroup and UnitFactionGroup('player');
	if ( side == 'Alliance' ) then return to:find('A', 1, true) ~= nil end;
	if ( side == 'Horde' ) then return to:find('H', 1, true) ~= nil end;
	return true;
end

local function AddAll(out, list)
	for _, spot in ipairs(list) do
		if ( #out >= SPOTS ) then return end;
		out[#out + 1] = spot;
	end
end

-- The spots of a list of NPCs and objects: { npcs }, { objects }. friendly: hostile NPCs left out
-- (givers and turn-ins), unless that would leave none.
local function Gather(out, npcs, objects, friendly)
	local count = 0;
	local hostile = {};
	for _, npc in ipairs(type(npcs) == 'table' and npcs or {}) do
		if ( count >= ENTITIES ) then break end;
		count = count + 1;
		if ( friendly and not Friendly(npc) ) then hostile[#hostile + 1] = npc else AddAll(out, Where('Npc', npc)) end;
	end
	for _, object in ipairs(type(objects) == 'table' and objects or {}) do
		if ( count >= ENTITIES ) then break end;
		count = count + 1;
		AddAll(out, Where('Object', object));
	end
	if ( #out == 0 ) then
		for _, npc in ipairs(hostile) do AddAll(out, Where('Npc', npc)) end;
	end
end

-- Where an item comes from: the NPCs that drop it and the objects it is in.
local function ItemSources(out, item)
	Gather(out, Get('Item', item, 'npcDrops'), Get('Item', item, 'objectDrops'));
end

---------------------------------------------------------------
-- A quest's spots
---------------------------------------------------------------
local function Lower(text)
	return type(text) == 'string' and text:lower() or '';
end

-- The objectives the game shows for a quest in your log, or nil.
local function LogObjectives(id)
	local get = C_QuestLog and C_QuestLog.GetQuestObjectives;
	if ( type(get) ~= 'function' ) then return nil end;
	local ok, list = pcall(get, id);
	return ok and type(list) == 'table' and list or nil;
end

-- The game's kinds of objective, and which of QuestieDB's lists answer each.
local OF_KIND = { monster = 1, object = 2, item = 3 };

-- The spots for one of the game's objectives. db: QuestieDB's objectives; nth: how many of the
-- game's objectives of the same kind came before it.
local function ObjectiveSpots(out, id, db, objective, nth)
	local slot = OF_KIND[objective.type];
	local text = Lower(objective.text);
	if slot then
		local entries = type(db[slot]) == 'table' and db[slot] or {};
		local kind = slot == 1 and 'Npc' or slot == 2 and 'Object' or 'Item';
		-- the one whose name is in the objective's words; else the one in the same place in the list
		local chosen;
		for _, entry in ipairs(entries) do
			local name = Lower(type(entry) == 'table' and ( entry[2] or Get(kind, entry[1], 'name') ));
			if ( name ~= '' and text:find(name, 1, true) ) then chosen = entry; break end;
		end
		chosen = chosen or entries[nth + 1];
		if ( type(chosen) == 'table' and type(chosen[1]) == 'number' ) then
			if ( slot == 1 ) then Gather(out, { chosen[1] })
			elseif ( slot == 2 ) then Gather(out, nil, { chosen[1] })
			else ItemSources(out, chosen[1]) end;
			if ( #out > 0 ) then return end;
		end
		-- a kill that counts for others (QuestieDB's kill credit): every NPC that gives it
		if ( slot == 1 ) then
			for _, credit in ipairs(type(db[5]) == 'table' and db[5] or {}) do
				local root = type(credit) == 'table' and Lower(credit[3] or Get('Npc', credit[2], 'name'));
				if ( root and root ~= '' and text:find(root, 1, true) ) then
					Gather(out, credit[1]);
					return;
				end
			end
		end
	end
	-- an event (go somewhere, or the end of an escort): where QuestieDB says it ends
	local trigger = Get('Quest', id, 'triggerEnd');
	if ( type(trigger) == 'table' and type(trigger[2]) == 'table' and objective.type ~= 'item' ) then
		for area, points in pairs(trigger[2]) do
			for _, point in ipairs(type(points) == 'table' and points or {}) do
				local map, wx, wy = P.Guides.WorldOf(MapOfArea(area), ( point[1] or -1 ) / 100, ( point[2] or -1 ) / 100);
				if map then out[#out + 1] = { map, wx, wy, name = trigger[1] } end;
			end
		end
	end
end

-- All of QuestieDB's objective spots for a quest (the game gives no objectives to match).
local function AllObjectives(out, id, db)
	local npcs, objects = {}, {};
	for _, e in ipairs(type(db[1]) == 'table' and db[1] or {}) do npcs[#npcs + 1] = e[1] end;
	for _, e in ipairs(type(db[2]) == 'table' and db[2] or {}) do objects[#objects + 1] = e[1] end;
	Gather(out, npcs, objects);
	for _, e in ipairs(type(db[3]) == 'table' and db[3] or {}) do ItemSources(out, e[1]) end;
	for _, credit in ipairs(type(db[5]) == 'table' and db[5] or {}) do Gather(out, credit[1]) end;
	if ( #out == 0 ) then ObjectiveSpots(out, id, db, { type = 'event' }, 0) end;
end

local function InLog(id)
	local get = C_QuestLog and C_QuestLog.GetLogIndexForQuestID;
	if ( type(get) ~= 'function' ) then return false end;
	local ok, index = pcall(get, id);
	return ok and type(index) == 'number' and index > 0;
end

local function Complete(id)
	if not C_QuestLog then return false end;
	for _, name in ipairs({ 'ReadyForTurnIn', 'IsComplete' }) do
		local fn = C_QuestLog[name];
		if ( type(fn) == 'function' ) then
			local ok, yes = pcall(fn, id);
			if ( ok and yes ) then return true end;
		end
	end
	return false;
end

local cache = {};

-- What a quest's spots rest on: whether it is in your log, done, and which objectives are.
local function State(id, objectives)
	local parts = { InLog(id) and 'L' or '-', Complete(id) and 'C' or '-' };
	for _, o in ipairs(objectives or {}) do parts[#parts + 1] = o.finished and '1' or '0' end;
	return table.concat(parts);
end

function QuestDB.Spots(id, mode, obj)
	if not ( QuestDB:Ready() and type(id) == 'number' and Get('Quest', id, 'name') ) then return nil end;
	local objectives = LogObjectives(id);
	local state = State(id, objectives);
	local key = ('%d:%s:%s'):format(id, tostring(mode), tostring(obj));
	local kept = cache[key];
	if ( kept and kept.state == state and GetTime() - kept.at < STALE ) then return kept.spots, kept.mode end;
	if not mode then
		if not InLog(id) then mode = 'giver'
		elseif Complete(id) then mode = 'turnin'
		else mode = 'objective' end;
	end
	local out = {};
	if ( mode == 'giver' ) then
		local by = Get('Quest', id, 'startedBy') or {};
		Gather(out, by[1], by[2], true);
		for _, item in ipairs(type(by[3]) == 'table' and by[3] or {}) do ItemSources(out, item) end;
	elseif ( mode == 'turnin' ) then
		local by = Get('Quest', id, 'finishedBy') or {};
		Gather(out, by[1], by[2], true);
	else
		local db = Get('Quest', id, 'objectives') or {};
		local seen, any = {}, false;
		for i, o in ipairs(objectives or {}) do
			if ( type(o) == 'table' ) then
				local kind = tostring(o.type);
				local nth = seen[kind] or 0;
				seen[kind] = nth + 1;
				if ( ( obj == nil and not o.finished ) or obj == i ) then
					any = true;
					ObjectiveSpots(out, id, db, o, nth);
				end
			end
		end
		if ( not any and obj == nil ) then AllObjectives(out, id, db) end;
	end
	cache[key] = { state = state, at = GetTime(), spots = out, mode = mode };
	return out, mode;
end

-- The spot gone to for each quest, kept so that two spots about as near do not take turns.
local chosen = {};

-- The nearest spot of a list from where you stand (one on your continent first); key: what to
-- remember the choice under. map, x, y, and the spot.
function QuestDB.Nearest(spots, key)
	if not ( type(spots) == 'table' and spots[1] ) then return nil end;
	local px, py, here = P.Guides.Here();
	local best, far;
	for _, spot in ipairs(spots) do
		local d = ( px and spot[1] == here ) and ( ( spot[2] - px ) ^ 2 + ( spot[3] - py ) ^ 2 ) or nil;
		if ( d and ( not far or d < far ) ) then best, far = spot, d end;
	end
	if not best then best = spots[1] end;
	local last = key and chosen[key];
	if ( last and far and px ) then
		for _, spot in ipairs(spots) do
			if ( spot[1] == last[1] and math.abs(spot[2] - last[2]) < 1 and math.abs(spot[3] - last[3]) < 1 ) then
				local d = math.sqrt(( spot[2] - px ) ^ 2 + ( spot[3] - py ) ^ 2);
				if ( d - math.sqrt(far) < STICK ) then best = spot end;
				break;
			end
		end
	end
	if key then chosen[key] = best end;
	return best[1], best[2], best[3], best;
end

function QuestDB.Place(id, mode, obj)
	local spots, found = QuestDB.Spots(id, mode, obj);
	if not spots then return nil end;
	return QuestDB.Nearest(spots, ('%s:%s'):format(tostring(id), tostring(found)));
end

-- Drops what is kept (the spots are worked out again at the next ask).
function QuestDB.Forget()
	cache, chosen = {}, {};
end

---------------------------------------------------------------
-- Quests you can take now
---------------------------------------------------------------
local function Done(id)
	local fn = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or rawget(_G, 'IsQuestFlaggedCompleted');
	if ( type(fn) ~= 'function' ) then return false end;
	local ok, yes = pcall(fn, id);
	return ok and yes and true or false;
end

local function AnyDone(list)
	for _, q in ipairs(type(list) == 'table' and list or {}) do if Done(q) then return true end end;
	return false;
end

local function AllDone(list)
	for _, q in ipairs(type(list) == 'table' and list or {}) do if not Done(q) then return false end end;
	return true;
end

local function Band(a, b)
	return bit and bit.band and bit.band(a, b) or 0;
end

-- Questie's own check, where Questie runs (it knows hidden quests and reputations); else ours.
local function QuestieDoable()
	local loader = rawget(_G, 'QuestieLoader');
	if not ( type(loader) == 'table' and type(loader.ImportModule) == 'function' ) then return nil end;
	local ok, db = pcall(loader.ImportModule, loader, 'QuestieDB');
	local questie = rawget(_G, 'Questie');
	if not ( ok and type(db) == 'table' and type(db.IsDoable) == 'function'
		and type(questie) == 'table' and type(questie.db) == 'table' and type(questie.db.char) == 'table'
		and type(questie.db.char.complete) == 'table' ) then
		return nil;
	end
	return db.IsDoable;
end

-- Whether you can take a quest now (not counting where its giver stands).
local function Takeable(id, level, race, class, doable)
	local need = Get('Quest', id, 'requiredLevel');
	if ( type(need) == 'number' and need > level ) then return false end;
	local most = Get('Quest', id, 'requiredMaxLevel');
	if ( type(most) == 'number' and most > 0 and most < level ) then return false end;
	-- (grey quests left out: a quest far below you gives next to nothing)
	local qlevel = Get('Quest', id, 'questLevel');
	local green = ( GetQuestGreenRange and GetQuestGreenRange() ) or 8;
	if ( type(qlevel) == 'number' and qlevel > 0 and qlevel < level - green ) then return false end;
	if ( Done(id) or InLog(id) ) then return false end;
	if doable then
		local ok, yes = pcall(doable, id);
		return ok and yes and true or false;
	end
	local races = Get('Quest', id, 'requiredRaces');
	if ( type(races) == 'number' and races > 0 and race and Band(races, race) == 0 ) then return false end;
	local classes = Get('Quest', id, 'requiredClasses');
	if ( type(classes) == 'number' and classes > 0 and class and Band(classes, class) == 0 ) then return false end;
	-- (skills and reputations cannot be told here cheaply: such quests are left out)
	if ( Get('Quest', id, 'requiredSkill') or Get('Quest', id, 'requiredMinRep') or Get('Quest', id, 'requiredMaxRep') ) then return false end;
	local single = Get('Quest', id, 'preQuestSingle');
	if ( type(single) == 'table' and #single > 0 and not AnyDone(single) ) then return false end;
	if not AllDone(Get('Quest', id, 'preQuestGroup')) then return false end;
	for _, other in ipairs(Get('Quest', id, 'exclusiveTo') or {}) do
		if ( Done(other) or InLog(other) ) then return false end;
	end
	return true;
end

local givers;

-- The quest givers on your continent with a quest you can take now: a list of
-- { kind = 'Npc' or 'Object', id =, name =, quests = { quest ids }, spots = { spots on your continent } }.
-- Kept until your log, your level or where you are changes continent (QuestDB.Forget drops it too).
function QuestDB.Givers()
	if not QuestDB:Ready() then return nil end;
	local _, _, here = P.Guides.Here();
	if not here then return nil end;
	if ( givers and givers.map == here ) then return givers.list end;
	local level = UnitLevel and UnitLevel('player') or 1;
	local raceID, classID;
	if UnitRace then raceID = select(3, UnitRace('player')) end;
	if UnitClass then classID = select(3, UnitClass('player')) end;
	local race = raceID and lib.Enum and lib.Enum.raceMaskById and lib.Enum.raceMaskById[raceID];
	local class = classID and 2 ^ ( classID - 1 );
	local doable = QuestieDoable();
	local ok, ids = pcall(lib.Quest.GetAllIds);
	local byGiver, list = {}, {};
	for _, id in ipairs(ok and type(ids) == 'table' and ids or {}) do
		if Takeable(id, level, race, class, doable) then
			local by = Get('Quest', id, 'startedBy') or {};
			for slot, kind in ipairs({ 'Npc', 'Object' }) do
				for _, giver in ipairs(type(by[slot]) == 'table' and by[slot] or {}) do
					if ( kind == 'Object' or Friendly(giver) ) then
						local key = kind .. giver;
						local entry = byGiver[key];
						if not entry then
							local spots = {};
							for _, spot in ipairs(Where(kind, giver)) do
								if ( spot[1] == here ) then spots[#spots + 1] = spot end;
							end
							entry = { kind = kind, id = giver, name = Get(kind, giver, 'name'), quests = {}, spots = spots };
							byGiver[key] = entry;
							if ( #spots > 0 ) then list[#list + 1] = entry end;
						end
						entry.quests[#entry.quests + 1] = id;
					end
				end
			end
		end
	end
	givers = { map = here, list = list };
	return list;
end

---------------------------------------------------------------
-- Creatures and what they drop
---------------------------------------------------------------
-- Where a creature stands (a list of spots, perhaps empty), and its levels (lowest, highest).
function QuestDB.NpcSpots(npc)
	if not ( QuestDB:Ready() and type(npc) == 'number' ) then return {} end;
	return Where('Npc', npc);
end

function QuestDB.NpcLevels(npc)
	if not QuestDB:Ready() then return nil end;
	return Get('Npc', npc, 'minLevel'), Get('Npc', npc, 'maxLevel');
end

-- QuestieDB's Wowhead drop rates: [item] = { [npc] = percent }. Built from quest objectives, so quest
-- items and the things quests ask for, not every item. Decoded once.
local rates;
local function Rates()
	if rates then return rates end;
	rates = {};
	local support = lib and lib.Support;
	if ( type(support) == 'table' and type(support.Get) == 'function' ) then
		local ok, drops = pcall(support.Get, 'QuestieClassicItemDrops');
		if ( ok and type(drops) == 'table' ) then rates = Decode(drops.wowheadData) or {} end;
	end
	return rates;
end

-- The creatures that drop an item: a list of { npc =, rate = percent or nil (QuestieDB names it a
-- dropper but has no rate) }, highest rate first.
function QuestDB.ItemDrops(item)
	if not ( QuestDB:Ready() and type(item) == 'number' ) then return {} end;
	local out, seen = {}, {};
	for npc, rate in pairs(Rates()[item] or {}) do
		if ( type(npc) == 'number' and type(rate) == 'number' ) then
			out[#out + 1] = { npc = npc, rate = rate };
			seen[npc] = true;
		end
	end
	for _, npc in ipairs(Get('Item', item, 'npcDrops') or {}) do
		if not seen[npc] then out[#out + 1] = { npc = npc } end;
	end
	table.sort(out, function(a, b) return ( a.rate or 0 ) > ( b.rate or 0 ) end);
	return out;
end

-- An item by its id, its link or its name (any case): id, name; nothing when not known. A name is
-- looked for among the items with drop rates first, then by QuestieDB's own index of exact names.
function QuestDB.FindItem(text)
	if not ( QuestDB:Ready() and type(text) == 'string' ) then return nil end;
	local id = tonumber(text:match('item:(%d+)') or text:match('^%s*(%d+)%s*$'));
	if id then
		local name = Get('Item', id, 'name');
		if name then return id, name end;
		return nil;
	end
	local want = Lower(( text:gsub('^%s+', ''):gsub('%s+$', '') ));
	for item in pairs(Rates()) do
		local name = Get('Item', item, 'name');
		if ( type(name) == 'string' and name:lower() == want ) then return item, name end;
	end
	local index = lib.Item and lib.Item.IdsByName;
	if ( type(index) == 'function' ) then
		local ok, ids = pcall(index, text);
		if ( ok and type(ids) == 'table' and ids[1] ) then return ids[1], Get('Item', ids[1], 'name') end;
	end
	return nil;
end

local watch = CreateFrame('Frame');
for _, event in ipairs({ 'QUEST_ACCEPTED', 'QUEST_TURNED_IN', 'QUEST_REMOVED', 'PLAYER_LEVEL_UP' }) do
	pcall(watch.RegisterEvent, watch, event)
end
watch:SetScript('OnEvent', function()
	givers = nil;
	cache = {};
end)
