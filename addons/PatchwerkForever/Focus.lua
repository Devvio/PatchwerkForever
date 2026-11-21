local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Focus: what the route follows, chosen and kept
---------------------------------------------------------------
-- By itself the route follows the main track: your guide, or
-- your tracked quests, in the order Routes (Thread)'s Priority
-- setting gives. A focus is your standing choice of one of them
-- instead, kept for each character until you change it:
--
--     'auto'    the main track, as without a focus
--     'quests'  your tracked quests only
--     a reader  that guide reader's list only: 'rxp' (RestedXP),
--               'fdj' (the Dungeon Journal), 'route' (My Route,
--               MyRoute.lua)
--
-- A choice (Choice.lua: a quest you click, a list you pick), your
-- map pin and a gathering run still come before the focus. With
-- nowhere to send you, the focus gives way to the main track; the
-- tool that follows it says so.
--
--     PatchwerkForever.Focus:Get()          the focus in use ('auto' when none)
--     PatchwerkForever.Focus:Set(id)        true when it is known: Auto, Quests or a registered reader
--     PatchwerkForever.Focus:Available()    { { id =, name = }, ... }: what can be chosen now
--     PatchwerkForever.Focus:Name(id)       its name, as shown
--     PatchwerkForever.Focus:Next()         the next of Available after the one in use (a key)
--     PatchwerkForever.Focus:OnChange(fn)   fn(id) whenever it is set to another
--
-- Kept in PatchwerkForeverDB.characters[<character's GUID>].focus.

local Focus = {};
P.Focus = Focus;

local NAMES = { auto = 'Auto', quests = 'Quests' };
local listeners = {};

-- this character's own saved table (nil before the game says who you are)
function P:Character()
	local ok, guid = pcall(UnitGUID, 'player');
	if not ( ok and type(guid) == 'string' and PatchwerkForeverDB ) then return nil end;
	PatchwerkForeverDB.characters = PatchwerkForeverDB.characters or {};
	PatchwerkForeverDB.characters[guid] = PatchwerkForeverDB.characters[guid] or {};
	return PatchwerkForeverDB.characters[guid];
end

function Focus:Name(id)
	if NAMES[id] then return NAMES[id] end;
	local reader = P.Guides.readers[id];
	return reader and ( reader.name or id ) or tostring(id);
end

-- Is the reader `id` there to be followed: registered, and running (it says it is, or it has something to say).
local function Running(id)
	local reader = P.Guides.readers[id];
	if not reader then return false end;
	if ( type(reader.Running) == 'function' ) then
		local ok, yes = pcall(reader.Running);
		return ok and yes and true or false;
	end
	return P.Guides:Read(0, id) ~= nil;
end

function Focus:Available()
	-- Auto, the guides, Quests, then My Route last
	local list = { { id = 'auto', name = NAMES.auto } };
	for _, id in ipairs(P.Guides.order) do
		if ( id ~= 'route' and Running(id) ) then list[#list + 1] = { id = id, name = Focus:Name(id) } end;
	end
	list[#list + 1] = { id = 'quests', name = NAMES.quests };
	if Running('route') then list[#list + 1] = { id = 'route', name = Focus:Name('route') } end;
	return list;
end

local function Known(id)
	return id == 'auto' or id == 'quests' or P.Guides.readers[id] ~= nil;
end

function Focus:Get()
	local mine = P:Character();
	local id = mine and mine.focus;
	-- (a reader gone since: its addon disabled; the focus is kept for when it comes back)
	if ( type(id) == 'string' and Known(id) ) then return id end;
	return 'auto';
end

local function Changed(id)
	for _, fn in ipairs(listeners) do
		local ok, problem = pcall(fn, id);
		if not ok then geterrorhandler()(problem) end;
	end
end

function Focus:Set(id)
	if not ( type(id) == 'string' and Known(id) ) then return false end;
	local mine = P:Character();
	if not mine then return false end;
	-- a list picked off the main track gives way to a focus chosen after it (a picked quest stays)
	local choice = P.Choice and P.Choice:Get();
	if ( choice and choice.kind == 'guide' ) then P.Choice:Clear() end;
	if ( ( mine.focus or 'auto' ) == id ) then return true end;
	mine.focus = ( id ~= 'auto' ) and id or nil;
	Changed(id)
	return true;
end

function Focus:Next()
	local list, now = Focus:Available(), Focus:Get();
	for i, one in ipairs(list) do
		if ( one.id == now ) then return list[i % #list + 1].id end;
	end
	return list[1].id;
end

function Focus:OnChange(fn)
	if ( type(fn) == 'function' ) then listeners[#listeners + 1] = fn end;
end
