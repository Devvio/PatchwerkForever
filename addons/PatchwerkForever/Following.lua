local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Following: what the route planner leads to now
---------------------------------------------------------------
-- The route planner decides what it follows (a map pin, a
-- gathering run, the chosen side path, the guide step, a quest),
-- and the tracker marks the line that matches. Asking the planner
-- directly would tie the two together, and the tracker working it
-- out alone gets it wrong whenever the planner chose otherwise:
-- the planner says it here instead.
--
--     PatchwerkForever.Following:Set(info)   info, or nil when nothing is followed
--     PatchwerkForever.Following:Get()       the info last set, or nil
--     PatchwerkForever.Following:OnChange(fn) fn(info) when the kind or key changes, or the travel
--     PatchwerkForever.Following:SetTravel(words) how the planner gets there, once its route is found:
--                                             a few words ("Fly from Crossroads to Thunder Bluff, then
--                                             walk (3 min)"), or nil; kept as info.travel until the
--                                             destination changes (2.7.0)
--
-- info = {
--     kind   = 'pin', 'spot', 'gather', 'guide', 'quest' or 'none'
--     source = the guide reader's id (Guides.lua), for a guide step
--     quest  = the quest's id, for a quest or a guide step about one
--     key    = a string that changes whenever the destination does
-- }
--
-- The planner sets it each time it looks again, so listeners are
-- told only when the kind or the key differs: a planner saying
-- the same thing twice costs the tracker nothing.

local Following = {};
P.Following = Following;

local current;
local listeners = {};

function Following:OnChange(fn)
	if ( type(fn) == 'function' ) then listeners[#listeners + 1] = fn end;
end

function Following:Get()
	return current;
end

local function Changed()
	for _, fn in ipairs(listeners) do
		local ok, problem = pcall(fn, current);
		if not ok then geterrorhandler()(problem) end;
	end
end

function Following:Set(info)
	if ( type(info) ~= 'table' ) then info = nil end;
	local was = current;
	current = info;
	local same = ( was == nil and info == nil )
		or ( was ~= nil and info ~= nil and was.kind == info.kind and was.key == info.key );
	if same then
		-- (the same destination told again: the travel found for it stays)
		if ( info and was ) then info.travel = was.travel end;
		return;
	end
	Changed()
end

function Following:SetTravel(words)
	if not current then return end;
	if ( type(words) ~= 'string' or words == '' ) then words = nil end;
	if ( current.travel == words ) then return end;
	current.travel = words;
	Changed()
end
