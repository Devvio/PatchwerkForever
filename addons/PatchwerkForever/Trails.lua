local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Trails: the way the route goes, for a tool that draws it
---------------------------------------------------------------
-- Routes (Thread) finds the way and draws it on the world map and
-- the minimap. A tool with a map of its own (Globe (Thread)) asks
-- here for the same trail, the boats and zeppelins, and the herb
-- and ore spots. Neither tool knows the other: Routes offers what
-- it knows here, and whoever wants it asks here. With Routes not
-- installed nothing is offered, and Has() says so.
--
--     PatchwerkForever.Trails:Offer(provider)     (Routes)
--     PatchwerkForever.Trails:Has()
--     PatchwerkForever.Trails:List()              the trails drawn now, the one you are on first:
--         { { follow = true for the one you are on, alpha =, last = { map =, x =, y = },
--             pieces = { { map =, how = 'walk', 'link', 'fly' or 'ride', r =, g =, b =,
--                          points = { { x, y }, ... } }, ... } }, ... }
--         (world coordinates on the continent `map`; the colours are the player's own, from Routes'
--         options; the trail you are on starts where you stand)
--     PatchwerkForever.Trails:Crossings()         the boats and zeppelins:
--         { { id =, kind = 'boat' or 'zeppelin', sides = 'A', 'H' or 'AH', wait = seconds,
--             stops = { { map =, name =, x =, y = }, ... },
--             rides = { { from = stop, to = stop, secs =, legs = { { map =, points = { { x, y }, ... } }, ... } }, ... } }, ... }
--     PatchwerkForever.Trails:Lifts()             the lifts the planner knows: { { map =, x =, y =, name = or nil }, ... }
--     PatchwerkForever.Trails:NodesAround(map, x, y, reach, fn)
--                                                 fn(x, y, name, icon, kind) for each remembered herb ('h') or
--                                                 ore ('o') spot within `reach` yards of a place
--     PatchwerkForever.Trails:OnChange(fn)        fn() when the trail has changed (and when Routes comes or goes)
--     PatchwerkForever.Trails:Changed()           (Routes)

local Trails = {};
P.Trails = Trails;

local provider;
local listeners = {};
local NEEDS = { 'List', 'Crossings', 'NodesAround' };

function Trails:Changed()
	for _, fn in ipairs(listeners) do
		local ok, err = pcall(fn);
		if not ok then ns.Say('A trail listener failed: ' .. tostring(err)) end
	end
end

function Trails:OnChange(fn)
	if ( type(fn) == 'function' ) then listeners[#listeners + 1] = fn end;
end

function Trails:Offer(given)
	assert(type(given) == 'table', 'A trail provider is a table.')
	for _, name in ipairs(NEEDS) do
		assert(type(given[name]) == 'function', 'A trail provider needs List, Crossings and NodesAround.')
	end
	provider = given;
	self:Changed()
end

function Trails:Has()
	return provider ~= nil;
end

local reported = {};   -- (once for each)
local function Ask(what, ...)
	if not provider then return nil end;
	local ok, a = pcall(provider[what], ...);
	if ok then return a end;
	if not reported[what] then
		reported[what] = true;
		ns.Say('Reading the route failed and was skipped: ' .. tostring(a))
	end
	return nil;
end

function Trails:List() return Ask('List') or {} end
function Trails:Crossings() return Ask('Crossings') or {} end
function Trails:Lifts()
	-- (a provider need not have them)
	return provider and type(provider.Lifts) == 'function' and Ask('Lifts') or {}
end
function Trails:NodesAround(map, x, y, reach, fn)
	if ( type(fn) == 'function' and map and x and y ) then Ask('NodesAround', map, x, y, tonumber(reach) or 500, fn) end
end
