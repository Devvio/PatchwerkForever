local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Guides: what the guide you are running says
---------------------------------------------------------------
-- Guide addons (RestedXP, and others in time) lead you step by
-- step. More than one of our tools wants to know what the step
-- is: the route planner goes where it sends you, the tracker
-- lists it. They ask here, and here asks a reader, one for each
-- guide addon (the files in Guides\). A reader looks at its guide
-- addon as it runs and changes nothing of it; with that addon not
-- running it says nothing. Nothing a guide says is kept: it is
-- read again each time it is asked for.
--
--     PatchwerkForever.Guides:Register(id, { name = 'RestedXP', Read = function(count) ... end })
--     PatchwerkForever.Guides:Read(count)
--     PatchwerkForever.Guides:Read(count, id)     what that one reader says
--     PatchwerkForever.Guides:ReadAll(count)      every reader with a guide, the leading one first
--
-- More than one may be running: a levelling guide, and a list of
-- dungeon quests beside it. The first with something to say is the
-- main one, in the order they joined; a reader that has a Leads
-- function is asked first while that returns true. A reader that
-- has a Side function is a side list while that returns true: it
-- is never the main one, not even when it is the only one with
-- something to say. It is followed once the player selects it
-- (Choice.lua). Read without an id passes it over; Read with its
-- id and ReadAll give it as any other, marked side = true.
--
-- Read gives what the main reader with a guide running says, or
-- nil. `count` is how many of the steps after the one you are on
-- are wanted. What is given:
--     source, reader   the reader's id and the guide addon's name
--     side             true when the reader says it is a side list
--     guide            the guide's own name, when it has one
--     index, total     the step you are on, and how many there are
--     kind             what the step asks for: 'fly', 'hearth', 'death', 'travel', 'home', 'fp',
--                      'turnin', 'accept', 'complete', 'train', 'vendor', 'place' (go somewhere)
--                      or 'text' (words only)
--     lines            the step's lines, each { text =, done =, kind = }, as the guide words them; a
--                      line that has you take, finish or hand in a quest also has quest = its id, and
--                      for one objective of it obj = that objective's number (C_QuestLog.GetQuestObjectives).
--                      Its text may be '' while the guide addon has not worded it yet
--     map, x, y        where it sends you now, in the game's world coordinates; none when nowhere
--     key              changes when the step or its place does
--     ahead            the steps after it that have a place (or that carry you off), each
--                      { index, kind, lines, map, x, y }
--     after            the steps after it, whether they have a place or not, each { index, kind, lines }
--     items           the ids of the items the step wants used (a hearthstone, a quest's item)
--     flyTo           for a step that has you fly: the name of the flight point flown to, as the guide has it
--
-- One thing here acts on the guide addon instead of reading it, and only when the player asks:
--     PatchwerkForever.Guides:Go(info, index)
-- has the guide move to the step of that number (the one after the step you are on skips it;
-- the one before goes back), by the guide addon's own means. It returns true when the reader
-- can do that and did.

local Guides = { readers = {}, order = {} };
P.Guides = Guides;

-- kinds of step that carry you off, so that no walk leads on from where you stood
Guides.AWAY = { hearth = true, death = true };

function Guides:Register(id, reader)
	assert(type(id) == 'string' and type(reader) == 'table' and type(reader.Read) == 'function',
		'A guide reader needs an id and a Read function.')
	if not Guides.readers[id] then
		Guides.order[#Guides.order + 1] = id;
	end
	Guides.readers[id] = reader;
end

local reported = {};

-- What one reader says, or nil.
local function Ask(id, count)
	local reader = Guides.readers[id];
	if not reader then return nil end;
	local ok, info = pcall(reader.Read, tonumber(count) or 0);
	if not ok then
		-- (a guide addon changed under its reader: said once, and the next reader is asked)
		if not reported[id] then
			reported[id] = true;
			ns.Say(('The reader for %s failed and was skipped: %s'):format(reader.name or id, tostring(info)))
		end
		return nil;
	end
	if ( type(info) ~= 'table' ) then return nil end;
	info.source, info.reader = id, reader.name or id;
	-- (a reader may say it is a side list; one that fails to say is not one, as with Leads)
	if ( type(reader.Side) == 'function' ) then
		local asked, side = pcall(reader.Side);
		info.side = ( asked and side ) and true or nil;
	end
	return info;
end

-- The readers in the order they are asked: the ones that say they lead first, then as they joined.
local function Order()
	local first, rest = {}, {};
	for _, id in ipairs(Guides.order) do
		local leads = Guides.readers[id].Leads;
		local ok, yes = false, false;
		if ( type(leads) == 'function' ) then ok, yes = pcall(leads) end;
		if ( ok and yes ) then first[#first + 1] = id else rest[#rest + 1] = id end;
	end
	for _, id in ipairs(rest) do first[#first + 1] = id end
	return first;
end

function Guides:Read(count, source)
	if ( source ~= nil ) then return Ask(source, count) end;
	for _, id in ipairs(Order()) do
		local info = Ask(id, count);
		-- (a side list is not the main guide: it is read by its id, once selected)
		if ( info and not info.side ) then return info end;
	end
	return nil;
end

function Guides:ReadAll(count)
	local all = {};
	for _, id in ipairs(Order()) do
		local info = Ask(id, count);
		if info then all[#all + 1] = info end;
	end
	return all;
end

-- Has the guide move to the step numbered `index`. info: what Read gave.
function Guides:Go(info, index)
	local reader = type(info) == 'table' and Guides.readers[info.source];
	if not ( reader and type(reader.Go) == 'function' and tonumber(index) ) then return false end;
	local ok, went = pcall(reader.Go, tonumber(index));
	return ok and went and true or false;
end

-- The words of a step still to be done, as plain strings: `most` of them at most (three when not said).
function Guides.Words(info, most)
	local words = {};
	for _, line in ipairs(type(info) == 'table' and info.lines or {}) do
		if #words >= ( most or 3 ) then break end;
		if not line.done and type(line.text) == 'string' and line.text ~= '' then
			words[#words + 1] = line.text;
		end
	end
	return words;
end

-- For readers: a spot on one of the game's maps (0 to 1 across and down) as continent, world x, world y.
function Guides.WorldOf(uiMap, x, y)
	if ( type(uiMap) ~= 'number' or type(x) ~= 'number' or type(y) ~= 'number' ) then return nil end;
	local ok, map, world = pcall(C_Map.GetWorldPosFromMapPos, uiMap, CreateVector2D(x, y));
	if not ( ok and map and world ) then return nil end;
	local wx, wy = world:GetXY();
	return map, wx, wy;
end

-- For readers: where the character is, as world x, world y, continent (nothing where the game gives none).
function Guides.Here()
	local x, y, _, map = UnitPosition('player');
	if not x then return nil end;
	return x, y, map;
end

-- For readers: the name of one of the game's maps (a zone, usually), or nil.
function Guides.ZoneName(uiMap)
	if ( type(uiMap) ~= 'number' or not ( C_Map and C_Map.GetMapInfo ) ) then return nil end;
	local ok, info = pcall(C_Map.GetMapInfo, uiMap);
	local name = ok and type(info) == 'table' and info.name;
	return type(name) == 'string' and name ~= '' and name or nil;
end

-- For readers: the zone a quest in your log is done in (or the map the game would open for it), or nil.
function Guides.QuestZone(id)
	local get = rawget(_G, 'GetQuestUiMapID');
	if ( type(get) ~= 'function' ) then return nil end;
	for _, done in ipairs({ true, false }) do
		local ok, uiMap = pcall(get, id, done or nil);
		local name = ok and Guides.ZoneName(uiMap);
		if name then return name end;
	end
	return nil;
end

-- For readers: where the game marks a quest in your log (its next objective, or whoever takes it in once
-- it is done), as continent, world x, world y; nothing when the game shows no mark for it.
function Guides.QuestPlace(id)
	if not ( C_QuestLog and type(C_QuestLog.GetQuestsOnMap) == 'function' ) then return nil end;
	local tried = {};
	local function On(uiMap)
		if ( type(uiMap) ~= 'number' or uiMap == 0 or tried[uiMap] ) then return nil end;
		tried[uiMap] = true;
		local ok, list = pcall(C_QuestLog.GetQuestsOnMap, uiMap);
		for _, q in ipairs(ok and type(list) == 'table' and list or {}) do
			if ( type(q) == 'table' and q.questID == id ) then return Guides.WorldOf(uiMap, q.x, q.y) end;
		end
		return nil;
	end
	local get = rawget(_G, 'GetQuestUiMapID');
	local best = C_Map and C_Map.GetBestMapForUnit;
	local function Try(fn, ...)
		if ( type(fn) ~= 'function' ) then return nil end;
		local ok, uiMap = pcall(fn, ...);
		if ok then return On(uiMap) end;
		return nil;
	end
	-- the map it is to be done on, the map the game would open for it, the map you are on
	local map, x, y = Try(get, id, true);
	if not map then map, x, y = Try(get, id) end;
	if not map then map, x, y = Try(best, 'player') end;
	return map, x, y;
end

-- A short order through places: the nearest to where you stand first, then always the nearest to the
-- one before; those on another continent after, in the order given; those with no place last, in the
-- order given. list: anything; Where(item) gives its continent, world x, world y, or nothing.
-- Returns a new list.
function Guides.ShortOrder(list, Where)
	local px, py, here = Guides.Here();
	local left, out, lost = {}, {}, {};
	for _, item in ipairs(list) do
		local map, x, y = Where(item);
		if map then left[#left + 1] = { item = item, map = map, x = x, y = y } else lost[#lost + 1] = item end;
	end
	local at = { map = here, x = px, y = py };
	while ( #left > 0 ) do
		local best, far;
		for i, one in ipairs(left) do
			local d;
			if ( at.x and one.map == at.map ) then
				d = ( one.x - at.x ) ^ 2 + ( one.y - at.y ) ^ 2;
			else
				d = 1e15 + i;                   -- (another continent, or nowhere known yet: as given)
			end
			if ( not far or d < far ) then best, far = i, d end;
		end
		at = table.remove(left, best);
		out[#out + 1] = at.item;
	end
	for _, item in ipairs(lost) do out[#out + 1] = item end
	return out;
end
