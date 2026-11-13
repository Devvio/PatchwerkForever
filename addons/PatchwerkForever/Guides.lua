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
--
-- Read gives what the first reader with a guide running says, or
-- nil. `count` is how many of the steps after the one you are on
-- are wanted. What is given:
--     source, reader   the reader's id and the guide addon's name
--     guide            the guide's own name, when it has one
--     index, total     the step you are on, and how many there are
--     kind             what the step asks for: 'fly', 'hearth', 'death', 'travel', 'home', 'fp',
--                      'turnin', 'accept', 'complete', 'train', 'vendor', 'place' (go somewhere)
--                      or 'text' (words only)
--     lines            the step's lines, each { text =, done =, kind = }, as the guide words them
--     map, x, y        where it sends you now, in the game's world coordinates; none when nowhere
--     key              changes when the step or its place does
--     ahead            the steps after it that have a place (or that carry you off), each
--                      { index, kind, lines, map, x, y }
--     after            the steps after it, whether they have a place or not, each { index, kind, lines }
--     items           the ids of the items the step wants used (a hearthstone, a quest's item)
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

function Guides:Read(count)
	for _, id in ipairs(Guides.order) do
		local reader = Guides.readers[id];
		local ok, info = pcall(reader.Read, tonumber(count) or 0);
		if not ok then
			-- (a guide addon changed under its reader: said once, and the next reader is asked)
			if not reported[id] then
				reported[id] = true;
				P:Print(('The reader for %s failed and was skipped: %s'):format(reader.name or id, tostring(info)))
			end
		elseif type(info) == 'table' then
			info.source, info.reader = id, reader.name or id;
			return info;
		end
	end
	return nil;
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
