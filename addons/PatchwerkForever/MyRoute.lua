local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- My Route: stops you put in your own order
---------------------------------------------------------------
-- A list of stops for each character, followed in the order you
-- give it. It is one more guide reader (Guides.lua), 'route', so
-- whatever follows a guide follows it: Thread (Routes) leads you
-- along it and draws the stops after, Thread (Tracker) lists it.
-- It is a side list: followed when it is your focus (Focus.lua) or
-- you select it, never by itself.
--
-- What a stop can be:
--     { kind = 'quest', id = }        a quest in your log: where the game marks it (its next
--                                     objective, then whoever takes it in once it is done)
--     { kind = <a kind's id>, id = }  a quest a part knows where to pick up, such as 'fdj' (the
--                                     Dungeon Journal's quests): where that part says; once you
--                                     take the quest it becomes a 'quest' stop
--     { kind = 'spot', map =, x =, y =, label = }   a place (your map pin, added)
-- A quest handed in or abandoned leaves the list by itself, and so
-- does a map spot once you reach it. A hand-in can wait: while a
-- quest's objective or pickup further on is clearly nearer, it goes
-- first (2.7.1).
--
--     PatchwerkForever.MyRoute:Entries()          the stops, each a copy with name, state and place filled in
--     PatchwerkForever.MyRoute:Add(stop, at)      at the end, or at position `at`; false when already in it
--     PatchwerkForever.MyRoute:Has(kind, id)
--     PatchwerkForever.MyRoute:Remove(index)
--     PatchwerkForever.MyRoute:Move(from, to)     the stop at `from` to position `to`
--     PatchwerkForever.MyRoute:Lead(index)        follow on from the stop at `index` (this session)
--     PatchwerkForever.MyRoute:Order()            a short order: nearest first, each next nearest the one before
--     PatchwerkForever.MyRoute:Clear()
--     PatchwerkForever.MyRoute:OnChange(fn)       fn() whenever the list changes
--     PatchwerkForever.MyRoute:Kind(id, { Name = fn(stop), Place = fn(stop) -> map, x, y, label, zone })
--                                                 for a part that knows quests the game does not
-- Kept in PatchwerkForeverDB.characters[<character's GUID>].route.

local MyRoute = { kinds = {} };
P.MyRoute = MyRoute;

local SOURCE = 'route';
local REACHED = 10;                       -- yards from a map spot that count as there
local listeners = {};
-- this session only, as with the other lists: the stops skipped, and where to follow on from
-- (Lead): that stop's key, and its place in the list (kept when it leaves the list, so the route
-- goes on with the stop after it)
local skipped = {};
local startKey, startAt;
local last = { index = 0, order = {} };
local cache = { at = -1 };                -- the stops as last worked out (Entries), for a moment
local reaching = {};                      -- map spots reached, to be taken off the list
local detour;                             -- the key of the stop gone to before a hand-in (Sooner)
local NEARER_YARDS, NEARER_SHARE = 15, 0.15;

local function Ask(fn, ...)
	if ( type(fn) ~= 'function' ) then return nil end;
	local ok, a, b, c, d, e = pcall(fn, ...);
	if ok then return a, b, c, d, e end;
	return nil;
end

local function Now() return type(GetTime) == 'function' and GetTime() or 0 end

local function Later(fn)
	if ( type(RunNextFrame) == 'function' ) then RunNextFrame(fn) else fn() end;
end

-- The list kept for this character; nil before the game says who you are.
local function List()
	local mine = P:Character();
	if not mine then return nil end;
	mine.route = type(mine.route) == 'table' and mine.route or {};
	return mine.route;
end

local function Changed()
	last = { index = 0, order = {} };
	cache.at = -1;
	for _, fn in ipairs(listeners) do
		local ok, problem = pcall(fn);
		if not ok then geterrorhandler()(problem) end;
	end
end

function MyRoute:OnChange(fn)
	if ( type(fn) == 'function' ) then listeners[#listeners + 1] = fn end;
end

function MyRoute:Kind(id, kind)
	assert(type(id) == 'string' and type(kind) == 'table', 'A kind of stop needs an id and a table.')
	MyRoute.kinds[id] = kind;
	cache.at = -1;
end

local function Held(id)
	local index = Ask(C_QuestLog.GetLogIndexForQuestID, id);
	return index ~= nil and index ~= 0;
end
local function Finished(id) return Ask(C_QuestLog.IsComplete, id) and true or false end
local function HandedIn(id) return Ask(C_QuestLog.IsQuestFlaggedCompleted, id) and true or false end

local function Key(stop)
	if ( stop.kind == 'spot' ) then
		return ('spot:%d:%d:%d'):format(tonumber(stop.map) or 0, math.floor(( tonumber(stop.x) or 0 ) + 0.5), math.floor(( tonumber(stop.y) or 0 ) + 0.5));
	end
	return ('%s:%s'):format(tostring(stop.kind), tostring(stop.id));
end

-- A stop as shown and followed: { kind, id, name, state, map, x, y, label, zone, key }.
--   state: 'todo' (a quest under way), 'done' (finished: to hand in), 'pickup' (to be picked up),
--          'spot' (a place), 'nowhere' (no place known now)
local function Resolve(stop)
	local out = { kind = stop.kind, id = stop.id, key = Key(stop) };
	if ( stop.kind == 'spot' ) then
		out.name = type(stop.label) == 'string' and stop.label or 'Map point';
		out.state, out.map, out.x, out.y = 'spot', stop.map, stop.x, stop.y;
		out.zone = type(stop.zone) == 'string' and stop.zone or nil;
		return out;
	end
	if ( stop.kind == 'quest' ) then
		out.name = Ask(C_QuestLog.GetTitleForQuestID, stop.id) or stop.name or ( 'Quest ' .. tostring(stop.id) );
		out.state = Finished(stop.id) and 'done' or 'todo';
		out.map, out.x, out.y = P.Guides.QuestPlace(stop.id);
		out.zone = P.Guides.QuestZone(stop.id);
	else
		local kind = MyRoute.kinds[stop.kind];
		out.name = kind and Ask(kind.Name, stop) or stop.name or ( 'Quest ' .. tostring(stop.id) );
		out.state = 'pickup';
		if kind then out.map, out.x, out.y, out.label, out.zone = Ask(kind.Place, stop) end;
	end
	if not out.map then out.state = out.state == 'pickup' and 'nowhere' or out.state end;
	return out;
end

-- The stops, worked out again at most once a second (finding a quest's mark asks the game about
-- several maps, and this is asked many times a second): a new list each call, the stops shared.
function MyRoute:Entries()
	local time = Now();
	if not ( cache.list and cache.at >= 0 and time - cache.at < 1 ) then
		local list = {};
		for i, stop in ipairs(List() or {}) do
			local one = Resolve(stop);
			one.index = i;
			list[i] = one;
		end
		cache.list, cache.at = list, time;
	end
	local out = {};
	for i, one in ipairs(cache.list) do out[i] = one end
	return out;
end

function MyRoute:Has(kind, id)
	for _, stop in ipairs(List() or {}) do
		if ( stop.kind == kind and stop.id == id ) then return true end;
		-- (a journal quest taken is the same quest)
		if ( stop.id ~= nil and stop.id == id and ( kind == 'quest' or stop.kind == 'quest' ) ) then return true end;
	end
	return false;
end

function MyRoute:Add(stop, at)
	local list = List();
	if ( not list or type(stop) ~= 'table' or type(stop.kind) ~= 'string' ) then return false end;
	local copy = {};
	for k, v in pairs(stop) do
		if ( type(v) ~= 'table' and type(v) ~= 'function' ) then copy[k] = v end;
	end
	if ( copy.kind == 'spot' ) then
		if not ( tonumber(copy.map) and tonumber(copy.x) and tonumber(copy.y) ) then return false end;
		for _, one in ipairs(list) do
			if ( Key(one) == Key(copy) ) then return false end;
		end
	elseif ( copy.id == nil or MyRoute:Has(copy.kind, copy.id) ) then
		return false;
	end
	-- a journal quest you already hold is a quest in your log
	if ( copy.kind ~= 'quest' and copy.kind ~= 'spot' and tonumber(copy.id) and Held(copy.id) ) then copy.kind = 'quest' end;
	at = tonumber(at);
	if ( at and at >= 1 and at <= #list ) then table.insert(list, at, copy) else list[#list + 1] = copy end;
	Changed()
	return true;
end

function MyRoute:Remove(index)
	local list = List();
	if not ( list and list[index] ) then return false end;
	table.remove(list, index);
	Changed()
	return true;
end

function MyRoute:Move(from, to)
	local list = List();
	from, to = tonumber(from), tonumber(to);
	if not ( list and from and to and list[from] ) then return false end;
	to = math.max(1, math.min(#list, to));
	if ( from == to ) then return false end;
	local stop = table.remove(list, from);
	table.insert(list, to, stop);
	Changed()
	return true;
end

function MyRoute:Order()
	local list = List();
	if not ( list and #list >= 2 ) then return false end;
	local ordered = P.Guides.ShortOrder(list, function(stop)
		local one = Resolve(stop);
		return one.map, one.x, one.y;
	end);
	for i, stop in ipairs(ordered) do list[i] = stop end
	startKey, startAt = nil, nil;
	Changed()
	return true;
end

function MyRoute:Clear()
	local list = List();
	if not ( list and #list > 0 ) then return false end;
	P:Character().route = {};
	skipped, startKey, startAt = {}, nil, nil;
	Changed()
	return true;
end

---------------------------------------------------------------
-- Keeping it up to date as you play
---------------------------------------------------------------
-- Quests leave by the events that say which quest it was (handed in, abandoned), never because the
-- quest log looks empty: at login it is filled a moment later than the first events come.

local function DropQuest(id)
	local list = List();
	if not ( list and id ) then return end;
	local changed = false;
	for i = #list, 1, -1 do
		if ( list[i].kind ~= 'spot' and list[i].id == id ) then
			table.remove(list, i);
			changed = true;
		end
	end
	if changed then Changed() end;
end

-- A quest taken: a journal quest of that number becomes a quest in your log.
local function Taken(...)
	local list = List();
	if not list then return end;
	local changed = false;
	for i = 1, select('#', ...) do
		local id = select(i, ...);
		if ( type(id) == 'number' ) then
			for _, stop in ipairs(list) do
				if ( stop.kind ~= 'quest' and stop.kind ~= 'spot' and stop.id == id ) then
					stop.kind = 'quest';
					changed = true;
				end
			end
		end
	end
	if changed then Changed() end;
end

-- Everything at once, once the quest log is loaded and has quests in it: quests no longer held leave,
-- journal quests held become quests, journal quests handed in leave. False while the log is empty.
local function Sweep()
	local list = List();
	if not list then return false end;
	local numQuests = select(2, Ask(C_QuestLog.GetNumQuestLogEntries));
	if not ( tonumber(numQuests) and numQuests > 0 ) then return false end;
	local changed = false;
	for i = #list, 1, -1 do
		local stop = list[i];
		local id = tonumber(stop.id);
		if ( stop.kind ~= 'spot' and id ) then
			if ( stop.kind == 'quest' and not Held(id) ) then
				table.remove(list, i);
				changed = true;
			elseif ( stop.kind ~= 'quest' and Held(id) ) then
				stop.kind = 'quest';
				changed = true;
			elseif ( stop.kind ~= 'quest' and HandedIn(id) ) then
				table.remove(list, i);
				changed = true;
			end
		end
	end
	if changed then Changed() end;
	return true;
end
MyRoute.Sweep = Sweep;

local swept = false;
local Watcher = CreateFrame('Frame');
for _, event in ipairs({ 'QUEST_LOG_UPDATE', 'QUEST_ACCEPTED', 'QUEST_REMOVED', 'QUEST_TURNED_IN' }) do
	pcall(Watcher.RegisterEvent, Watcher, event);
end
Watcher:SetScript('OnEvent', function(_, event, ...)
	cache.at = -1;
	if ( event == 'QUEST_REMOVED' or event == 'QUEST_TURNED_IN' ) then
		DropQuest((...))
	elseif ( event == 'QUEST_ACCEPTED' ) then
		Taken(...)
	elseif ( event == 'QUEST_LOG_UPDATE' and not swept ) then
		swept = Sweep();
	end
end)

-- A map spot reached leaves the list (a moment later: not while the list is being read).
local function Reach(key)
	if reaching[key] then return end;
	reaching[key] = true;
	Later(function()
		reaching[key] = nil;
		local list = List();
		for i, stop in ipairs(list or {}) do
			if ( Key(stop) == key ) then
				table.remove(list, i);
				Changed()
				return;
			end
		end
	end)
end

---------------------------------------------------------------
-- As a guide reader
---------------------------------------------------------------
local WORDS = { todo = 'Do', done = 'Turn in', pickup = 'Accept', spot = 'Go to' };
local KINDS = { todo = 'complete', done = 'turnin', pickup = 'accept', spot = 'place' };

local function Step(one, index)
	local lines = { { text = ( WORDS[one.state] and ( WORDS[one.state] .. ': ' ) or '' ) .. one.name, done = false, kind = KINDS[one.state] or 'text' } };
	if one.label then lines[2] = { text = one.label, done = false } end;
	return { index = index, kind = KINDS[one.state] or 'text', lines = lines, map = one.map, x = one.x, y = one.y,
		quest = ( one.kind ~= 'spot' ) and one.id or nil, route = one.index, zone = one.zone };
end

-- The stops in the order they are followed: from the one you asked to go on from (Lead) to the end,
-- then the ones before it.
local function Followed(all)
	if startKey then
		for i, one in ipairs(all) do
			if ( one.key == startKey ) then startAt = i; break end;
		end
	end
	local from = ( startAt and #all > 0 ) and math.max(1, math.min(#all, startAt)) or 1;
	local out = {};
	for i = from, #all do out[#out + 1] = all[i] end
	for i = 1, from - 1 do out[#out + 1] = all[i] end
	return out;
end

-- Yards from where you stand, on your continent; nil elsewhere (or where the game gives no place).
local function Yards(one, px, py, here)
	if not ( px and one.map and one.map == here ) then return nil end;
	return math.sqrt(( one.x - px ) ^ 2 + ( one.y - py ) ^ 2);
end

-- a nearer than b by enough to change course: 15 yards, or 15 percent when that is more (as the
-- tracker's quest order), so two places about as near do not take turns
local function ClearlyNearer(a, b)
	if not a then return false end;
	if not b then return true end;
	return a < b - math.max(NEARER_YARDS, b * NEARER_SHARE);
end

-- A quest to turn in can wait. While the stop you are on is a hand-in, a quest's objective or a quest to
-- pick up further on in the list that is clearly nearer goes first; then the hand-in, or the next such
-- stop on the way. Once one is gone to it keeps the lead until the hand-in is clearly nearer than it.
-- A hand-in you chose yourself (a click, Go Here First) is not put off.
local function Sooner(all, head, px, py, here)
	if ( head.state ~= 'done' or head.key == startKey ) then detour = nil; return head end;
	if not px then return head end;
	local far = Yards(head, px, py, here);
	local best, near, kept, keptAt;
	for _, one in ipairs(all) do
		if ( one ~= head and ( one.state == 'todo' or one.state == 'pickup' ) and one.map
		and not skipped[one.key] and not reaching[one.key] ) then
			local d = Yards(one, px, py, here);
			if d then
				if ( not near or d < near ) then best, near = one, d end;
				if ( one.key == detour ) then kept, keptAt = one, d end;
			end
		end
	end
	-- the one gone to stays ahead of a stop only a little nearer, and of the hand-in unless it is clearly nearer
	if ( kept and not ClearlyNearer(near, keptAt) ) then best, near = kept, keptAt end;
	if ( best and ( best == kept and not ClearlyNearer(far, near) or best ~= kept and ClearlyNearer(near, far) ) ) then
		detour = best.key;
		return best;
	end
	detour = nil;
	return head;
end

local function Read(count)
	local all = Followed(MyRoute:Entries());
	local px, py, here = P.Guides.Here();
	-- the stop to go to: the first with a place that is not skipped (a map spot you stand on is done)
	local head;
	for _, one in ipairs(all) do
		if ( one.map and not skipped[one.key] and not reaching[one.key] ) then
			if ( one.kind == 'spot' and px and one.map == here
			and ( one.x - px ) ^ 2 + ( one.y - py ) ^ 2 <= REACHED ^ 2 ) then
				Reach(one.key);
			else
				head = one;
				break;
			end
		end
	end
	if not head then
		last = { index = 0, order = {} };
		detour = nil;
		return nil;
	end
	local now = Sooner(all, head, px, py, here);
	local info = Step(now, now.index);
	info.guide = 'My Route';
	info.total = #all;
	info.key = ('route:%s:%d:%d'):format(now.key, math.floor(now.x + 0.5), math.floor(now.y + 0.5));
	info.ahead, info.after, info.items = {}, {}, {};
	-- the stops after: on from the one you are on (the hand-in put off comes next), the one gone to left out
	local order, seen = { now.key }, false;
	for _, one in ipairs(all) do
		if ( one == head ) then seen = true end;
		if ( seen and one ~= now and not skipped[one.key] and not reaching[one.key] ) then
			order[#order + 1] = one.key;
			if ( #info.after < count ) then
				local step = Step(one, one.index);
				info.after[#info.after + 1] = step;
				if one.map then info.ahead[#info.ahead + 1] = step end;
			end
		end
	end
	last = { index = now.index, order = order, sooner = now ~= head };
	return info;
end

-- Go to the stop at `index` first (for this session), and follow on from it: a click on it, or Go
-- Here First. It is no longer skipped; the list's order is not changed.
function MyRoute:Lead(index)
	local one = MyRoute:Entries()[tonumber(index) or 0];
	if not one then return false end;
	skipped[one.key] = nil;
	startKey, startAt = one.key, one.index;
	Changed()
	return true;
end

-- Guides:Go, by list index: the stop followed next after the one you are on skips that one (for this
-- session); any other goes first, and the route follows on from it (no longer skipped, if it was).
local function Go(index)
	local target = MyRoute:Entries()[tonumber(index) or 0];
	if not ( target and last.order[1] ) then return false end;
	if ( target.key == last.order[1] ) then return false end;
	-- (while a hand-in is put off, the stop after is that hand-in: a click on it goes there, skipping nothing)
	if ( target.key == last.order[2] and not last.sooner ) then
		local key = last.order[1];
		skipped[key] = true;
		if ( startKey == key ) then startKey = nil end;
		Changed()
		return true;
	end
	return MyRoute:Lead(index);
end

P.Guides:Register(SOURCE, {
	name    = 'My Route',
	Read    = Read,
	Go      = Go,
	Side    = function() return true end,
	Running = function() return true end,   -- (always there to be chosen, even empty)
});

-- for the checks outside the game
function MyRoute:State() return skipped, startKey, last end
