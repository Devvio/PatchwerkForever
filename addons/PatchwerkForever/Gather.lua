local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Gather: where the herbs and the ore were
---------------------------------------------------------------
-- Routes (Thread) remembers each spot where you picked a herb or
-- mined a vein, and can lead you to the nearest. The tracker
-- lists them. Neither tool knows the other: Routes offers what
-- it can do here, and whoever wants it asks here. With Routes
-- not installed nothing is offered, and Has() says so.
--
--     PatchwerkForever.Gather:Offer(provider)     (Routes)
--     PatchwerkForever.Gather:Has()
--     PatchwerkForever.Gather:Near(count)         the nearest spot of each kind you can gather, nearest first:
--                                                 { { name =, kind = 'h' or 'o', yards =, map =, x =, y = }, ... }
--     PatchwerkForever.Gather:Start(mode, name)   mode: 'any' (the nearest spot of anything), 'kind' (the
--                                                 nearest of `name`) or 'round' (spots near where you are).
--                                                 On reaching a spot the next is gone to, until Stop.
--     PatchwerkForever.Gather:Stop()
--     PatchwerkForever.Gather:State()             nil, or { mode =, name =, going = the name of the spot gone to }
--     PatchwerkForever.Gather:Note(name, kind, map, x, y)   a spot another tool saw: kept as one gathered
--                                                 from (kind 'h' or 'o'; world coordinates, as UnitPosition
--                                                 gives them). Sparkle (Thread) tells of the herbs and ore
--                                                 you passed. True when it was taken; a provider without
--                                                 Note (an older Routes) takes nothing (2.9.0)

local Gather = {};
P.Gather = Gather;

local provider;

function Gather:Offer(given)
	assert(type(given) == 'table' and type(given.Near) == 'function' and type(given.Start) == 'function'
		and type(given.Stop) == 'function' and type(given.State) == 'function', 'A gathering provider needs Near, Start, Stop and State.')
	provider = given;
end

function Gather:Has()
	return provider ~= nil;
end

local reported = {};   -- (once for each of Near, Start, Stop and State: a failed Start is still said after a failed Near)
local function Ask(what, ...)
	if not provider then return nil end;
	local ok, a = pcall(provider[what], ...);
	if ok then return a end;
	if not reported[what] then
		reported[what] = true;
		ns.Say('Gathering failed and was skipped: ' .. tostring(a))
	end
	return nil;
end

function Gather:Near(count) return Ask('Near', tonumber(count) or 5) or {} end
function Gather:Start(mode, name)
	if ( provider and P.Choice ) then P.Choice:Clear() end;      -- (one side path at a time: Choice.lua)
	return Ask('Start', mode, name);
end
function Gather:Stop() return Ask('Stop') end
function Gather:State() return Ask('State') end
-- More a provider may offer (Routes 1.5.0 with base 2.12.0); each answers nil where it does not:
--     Gather:Best()            the best area to gather in: { count =, yards = } (a look, nothing started)
--     Gather:Skin()            route to where most creatures you can skin stand
--     Gather:SkinKnown()       how many kinds of skinnable creature are known
--     Gather:CanFarm(text)     the item's name when an item (name, link or id) has drop data to farm by
--     Gather:Farm(text)        route to where that item most likely drops
--     Gather:Tracking()        for a character with both: { on = 'h', 'o' or nil, key = the switch key or nil }
--     Gather:Givers(on)        start (true) or stop (false) a quest giver run
--     Gather:GiversState()     nil, or { going = the giver's name, quests = how many it has, near = how
--                              many givers with a quest for you are on the continent }
local function Optional(what, ...)
	if not ( provider and type(provider[what]) == 'function' ) then return nil end;
	return Ask(what, ...);
end
function Gather:Best() return Optional('Best') end
function Gather:Skin() return Optional('Skin') end
function Gather:SkinKnown() return Optional('SkinKnown') end
function Gather:CanFarm(text) return Optional('CanFarm', text) end
function Gather:Farm(text) return Optional('Farm', text) end
function Gather:Tracking() return Optional('Tracking') end
function Gather:Givers(on) return Optional('Givers', on) end
function Gather:GiversState() return Optional('GiversState') end

function Gather:Note(name, kind, map, x, y)
	if not ( provider and type(provider.Note) == 'function' ) then return false end;
	return Ask('Note', name, kind, map, x, y) == true;
end
