local addonName, ns = ...;
local Guides = ns.P.Guides;
---------------------------------------------------------------
-- Guides: RestedXP
---------------------------------------------------------------
-- RestedXP keeps the guide it is running where another addon can
-- look: the guide's steps (RXP.currentGuide.steps), the number of
-- the step you are on (RXPCData.currentStep), and on its arrow's
-- frame the spot the arrow points at (RXPG_ARROW.element). A step
-- is a list of lines ("elements"): each has a tag that says what
-- kind of line it is (goto, accept, turnin, fly, hs...), usually
-- some words, and for a place its coordinates.
--
-- RestedXP may change how it keeps these. Every read is wary:
-- what is not there gives nothing, and with no steps to be found
-- the arrow's spot alone is given, as a step with no words.
--
-- Nothing of RestedXP's is changed or copied. Its words are shown
-- from its own tables as the game runs and are not kept.

local LOOK_AHEAD = 20;        -- steps past the one you are on that are looked through, at most
local MOST_LINES = 8;

-- what a line's tag says of the step; the first of these found, in this order, is the step's kind
local KIND_OF = {
	hs = 'hearth', hastyhearth = 'hearth',
	fly = 'fly',
	deathskip = 'death',
	zone = 'travel',
	home = 'home', bindlocation = 'home',
	fp = 'fp',
	turnin = 'turnin', dailyturnin = 'turnin', turninmultiple = 'turnin',
	accept = 'accept', daily = 'accept', acceptmultiple = 'accept',
	complete = 'complete',
	train = 'train', trainer = 'train',
	vendor = 'vendor',
};
local ORDER = { 'hearth', 'fly', 'death', 'travel', 'home', 'fp', 'turnin', 'accept', 'complete', 'train', 'vendor' };

-- Where a line of a step is: map, world x, world y; nothing for a line that is not a place.
local function PlaceOf(e)
	if ( type(e) ~= 'table' ) then return nil end;
	-- its place on a zone's map, which the game turns into world coordinates itself
	if ( e.zone and e.x and e.y ) then
		local map, x, y = Guides.WorldOf(e.zone, e.x / 100, e.y / 100);
		if map then return map, x, y end;
	end
	-- else RestedXP's own world coordinates: its x runs west and its y north, the game's the other way round
	if ( type(e.wx) == 'number' and type(e.wy) == 'number' and type(e.instance) == 'number' ) then
		return e.instance, e.wy, e.wx;
	end
	return nil;
end

local function Elements(step)
	return type(step.elements) == 'table' and step.elements or step;
end

-- What a step is: its kind, its lines ({ text, done, kind }), and its places still to be gone to
-- (each { map, x, y }).
local function Describe(step)
	local found, lines, places, seen = {}, {}, {}, {};
	for _, e in ipairs(Elements(step)) do
		if ( type(e) == 'table' ) then
			local done = e.completed and true or false;
			local kind = KIND_OF[e.tag];
			if ( kind and not done ) then found[kind] = true end;
			local text = e.text;
			if ( type(text) == 'string' and #lines < MOST_LINES ) then
				text = text:gsub('^%s+', ''):gsub('%s+$', '');
				if ( text ~= '' and not seen[text] ) then
					seen[text] = true;
					lines[#lines + 1] = { text = text, done = done, kind = kind };
				end
			end
			if not ( done or e.skip ) then
				local map, x, y = PlaceOf(e);
				if map then places[#places + 1] = { map, x, y } end;
			end
		end
	end
	local kind;
	for _, name in ipairs(ORDER) do
		if found[name] then kind = name; break end;
	end
	return kind or ( #places > 0 and 'place' or 'text' ), lines, places;
end

local function Key(index, map, x, y)
	if not map then return tostring(index) .. ':nowhere' end;
	return ('%s:%d:%d:%d'):format(tostring(index), map, math.floor(x + 0.5), math.floor(y + 0.5));
end

local function Arrow()
	local arrow = rawget(_G, 'RXPG_ARROW');
	if ( type(arrow) ~= 'table' ) then return nil end;
	-- (while RestedXP hides its arrow, what the arrow last pointed at is left on it: not to be gone to)
	if ( type(arrow.IsShown) == 'function' ) then
		local ok, shown = pcall(arrow.IsShown, arrow);
		if ( ok and not shown ) then return nil end;
	end
	return type(arrow.element) == 'table' and arrow.element or nil;
end

local function Read(count)
	local rxp, data = rawget(_G, 'RXP'), rawget(_G, 'RXPCData');
	local guide = type(rxp) == 'table' and type(rxp.currentGuide) == 'table' and rxp.currentGuide;
	local steps = guide and guide.steps;
	local n = type(data) == 'table' and tonumber(data.currentStep);
	local spot = Arrow();
	if not ( type(steps) == 'table' and n and type(steps[n]) == 'table' ) then
		-- no steps to read: the arrow's spot alone, if it has one
		local map, x, y = PlaceOf(spot);
		if not map then return nil end;
		return { kind = 'place', lines = {}, map = map, x = x, y = y, key = Key('arrow', map, x, y), ahead = {} };
	end

	-- the step the arrow's spot belongs to, when RestedXP has more than one open; else the one you are on
	local step = steps[n];
	if ( spot and type(spot.step) == 'table' and spot.step ~= step and spot.step.active ) then
		step = spot.step;
	end
	local kind, lines, places = Describe(step);
	local map, x, y = PlaceOf(spot);
	if ( not map and places[1] ) then
		-- RestedXP's arrow is hidden or has nothing: the nearest of the step's own places
		local px, py, here = Guides.Here();
		local best;
		for _, p in ipairs(places) do
			local far = ( px and p[1] == here ) and ( ( p[2] - px ) ^ 2 + ( p[3] - py ) ^ 2 ) or math.huge;
			if ( not best or far < best ) then best, map, x, y = far, p[1], p[2], p[3] end;
		end
	end
	local index = tonumber(step.index) or n;
	local name = guide.displayname or guide.name;
	local info = {
		guide = type(name) == 'string' and name or nil, index = index, total = #steps,
		kind = kind, lines = lines, map = map, x = x, y = y, key = Key(index, map, x, y), ahead = {},
	};

	local skipped = type(data.stepSkip) == 'table' and data.stepSkip or {};
	for i = n + 1, math.min(#steps, n + LOOK_AHEAD) do
		if ( #info.ahead >= count ) then break end;
		local s = steps[i];
		if ( type(s) == 'table' and not s.completed and not skipped[i] ) then
			local k, l, p = Describe(s);
			if p[1] then
				info.ahead[#info.ahead + 1] = { index = i, kind = k, lines = l, map = p[1][1], x = p[1][2], y = p[1][3] };
			elseif Guides.AWAY[k] then
				info.ahead[#info.ahead + 1] = { index = i, kind = k, lines = l };
			end
		end
	end
	return info;
end

Guides:Register('rxp', { name = 'RestedXP', Read = Read });
