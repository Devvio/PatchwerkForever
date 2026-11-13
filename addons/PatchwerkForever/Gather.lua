local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Gather: where the herbs and the ore were
---------------------------------------------------------------
-- Thread (Routes) remembers each spot where you picked a herb or
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

local reported = false;
local function Ask(what, ...)
	if not provider then return nil end;
	local ok, a = pcall(provider[what], ...);
	if ok then return a end;
	if not reported then
		reported = true;
		P:Print('Gathering failed and was skipped: ' .. tostring(a))
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
