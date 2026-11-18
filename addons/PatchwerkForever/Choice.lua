local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Choice: the side path you chose
---------------------------------------------------------------
-- There is a main track: the guide you are running, or with no
-- guide the quests you track. Now and then you want to go
-- somewhere else for a while: one quest in particular. That is a
-- choice. It is made in one tool (a click on a quest in the
-- tracker) and followed in another (the route planner), and
-- neither knows the other: the choice is kept here.
--
--     PatchwerkForever.Choice:Set('quest', questID)
--     PatchwerkForever.Choice:Set('guide', readerID)   a second guide's list (Guides.lua), followed as a side path
--     PatchwerkForever.Choice:Get()        nil, or { kind = 'quest', id = }
--     PatchwerkForever.Choice:Is(kind, id)
--     PatchwerkForever.Choice:Clear()      back to the main track
--     PatchwerkForever.Choice:OnChange(fn) fn(choice) whenever it is set, cleared or lapses (API 5)
--
-- A chosen quest stands until it is cleared or the quest leaves
-- your log (handed in, abandoned). It is not kept between logins.
-- A gathering run (Gather.lua) is a side path too, and there is
-- only one at a time: choosing a quest ends a run, and starting
-- a run clears the choice.

local Choice = {};
P.Choice = Choice;

local chosen;
local listeners = {};

local function Changed()
	for _, fn in ipairs(listeners) do
		local ok, problem = pcall(fn, chosen);
		if not ok then geterrorhandler()(problem) end;
	end
end

function Choice:OnChange(fn)
	if ( type(fn) == 'function' ) then listeners[#listeners + 1] = fn end;
end

local function Stands(choice)
	-- (a guide stands while its reader has something to say)
	if ( choice.kind == 'guide' ) then return P.Guides:Read(0, choice.id) ~= nil end;
	if ( choice.kind ~= 'quest' ) then return true end;
	local find = C_QuestLog and C_QuestLog.GetLogIndexForQuestID;
	if ( type(find) ~= 'function' ) then return true end;
	local ok, index = pcall(find, choice.id);
	return ( not ok ) or ( index ~= nil and index ~= 0 );
end

function Choice:Set(kind, id)
	if ( type(kind) ~= 'string' or id == nil ) then return false end;
	chosen = { kind = kind, id = id };
	if ( P.Gather and P.Gather:State() ) then P.Gather:Stop() end;
	Changed()
	return true;
end

function Choice:Get()
	if ( chosen and not Stands(chosen) ) then
		chosen = nil;
		-- (told a moment later: Get is asked while lists are being read and drawn)
		if ( type(RunNextFrame) == 'function' ) then RunNextFrame(Changed) else Changed() end;
	end
	return chosen;
end

function Choice:Is(kind, id)
	local now = Choice:Get();
	return now ~= nil and now.kind == kind and now.id == id;
end

function Choice:Clear()
	local was = chosen;
	chosen = nil;
	if was then Changed() end;
end
