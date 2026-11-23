-- Routes (Thread): gathering. The way to the nearest herb or ore spot, and on to the next.
--
-- The spots are the ones remembered from your own gathering (Nodes.lua): they show where things grow,
-- not whether one is there now. So a gathering run does not stop at a spot: when you reach it, the
-- route goes on to the next nearest, leaving out the ones you have been to in the last few minutes,
-- until you stop it.
--
--   'any'     the nearest spot of anything your character can gather
--   'kind'    the nearest spot of one thing ("Peacebloom")
--   'round'   as 'any', but keeping to the spots near where the round began
--
-- A run is a destination like any other (its source is 'gather'), so the trail, the step said on
-- screen and a wrong turn all work as they do for a pin. While one is on, your guide and your quests
-- are not followed; a pin of your own still comes first, and the run goes on once the pin is gone.
-- A flight point search (Discover.lua) is a side path of the same kind, and there is one at a time:
-- starting a run ends a search, and starting a search ends a run.
--
-- This is offered through the base (its Gather service), which is how the tracker lists the spots
-- and starts a run without knowing this addon. /thread gather does the same from the chat.
local ADDON, ns = ...
if not ns.linked then return end

local REACH = 3000            -- yards within which a spot is looked for
local ROUND = 1200            -- yards from where a round began that its spots lie within
local AGAIN = 300             -- seconds before a spot you have been to is gone to again
local HERBS, ORE = 2383, 2580 -- Find Herbs and Find Minerals: learned with the profession
local HERBALISM, MINING = 182, 186    -- the professions' skill lines, where the game cannot be asked for them
local KEEP = 10               -- seconds what you can gather is kept before the game is asked again

local state                   -- nil, or { mode =, name =, map =, x =, y = (where it began), going = the spot gone to }
local visited = {}            -- [spot] = when you reached it
-- [spot] = when no way was found to it. Left out like one you have been to, but only for the run that
-- is on: that was from where you stood, and the next run may start where there is a way.
local noWay = {}

-- What this character can gather: { h = true or false, o = true or false }. The game is asked the way
-- its own profession book asks (GetProfessions: each profession's skill line); where it cannot be
-- asked, whether the profession's tracking spell is known; where neither can be, or the spells say
-- neither, both are taken as possible. Kept a few seconds, and forgotten when your skills change.
local able, ableAt = nil, 0

local function SkillLine(profession, fallback)
	local trade, kinds = rawget(_G, 'C_TradeSkillUI'), Enum and Enum.Profession
	local id = trade and kinds and kinds[profession] and ns.Ask(trade.GetProfessionSkillLineID, kinds[profession])
	return type(id) == 'number' and id or fallback
end

local function AskProfessions()
	local list, info = rawget(_G, 'GetProfessions'), rawget(_G, 'GetProfessionInfo')
	if type(list) ~= 'function' or type(info) ~= 'function' then return nil end
	local ok, a, b, c, d, e = pcall(list)
	if not ok then return nil end
	local herbs, ore = SkillLine('Herbalism', HERBALISM), SkillLine('Mining', MINING)
	local out = { h = false, o = false }
	for _, index in pairs({ a, b, c, d, e }) do           -- (any of them can be nil)
		local line = select(8, pcall(info, index))         -- (pcall's true first, then the skill line seventh)
		if line == herbs then out.h = true elseif line == ore then out.o = true end
	end
	-- (a list with nothing in it is no answer: this client may keep its professions some other way, so
	-- the spells are asked next rather than every character being told it gathers nothing; a list with
	-- professions in it, and neither of these two, is an answer)
	if a == nil and b == nil and c == nil and d == nil and e == nil then return nil end
	return out
end

local function AskSpells()
	local known = rawget(_G, 'IsPlayerSpell') or rawget(_G, 'IsSpellKnown')
	if type(known) ~= 'function' then return nil end
	local okH, herbs = pcall(known, HERBS)
	local okO, ore = pcall(known, ORE)
	if not (okH and okO) or not (herbs or ore) then return nil end
	return { h = herbs and true or false, o = ore and true or false }
end

local function Able()
	if not able or GetTime() - ableAt > KEEP then
		able, ableAt = AskProfessions() or AskSpells() or { h = true, o = true }, GetTime()
	end
	return able
end
ns.Try('watching for professions learned', ns.On, 'SKILL_LINES_CHANGED', function() able = nil end)

-- Whether this character can gather anything at all.
local function AbleAny()
	local can = Able()
	return can.h or can.o
end

local function Far(node, x, y)
	return math.sqrt((node[1] - x) ^ 2 + (node[2] - y) ^ 2)
end

-- The nearest spot of each thing you can gather, nearest first: `count` of them at most.
local function Near(count)
	local px, py, map = ns.Place()
	if not px then return {} end
	local can, best = Able(), {}
	ns.NodesAround(map, px, py, REACH, function(node)
		local kind = ns.NodeKind(node[3])
		if kind and can[kind] then
			local far = Far(node, px, py)
			local had = best[node[3]]
			if not had or far < had.yards then
				best[node[3]] = { name = node[3], kind = kind, yards = far, map = map, x = node[1], y = node[2] }
			end
		end
	end)
	local list = {}
	for _, spot in pairs(best) do list[#list + 1] = spot end
	table.sort(list, function(a, b) return a.yards < b.yards end)
	for i = #list, (count or 5) + 1, -1 do list[i] = nil end
	return list
end

-- The spot to go to next, or nothing.
local function Pick()
	local px, py, map = ns.Place()
	if not (px and state) then return nil end
	local can, now = Able(), GetTime()
	local best, far
	ns.NodesAround(map, px, py, REACH, function(node)
		local kind = ns.NodeKind(node[3])
		if not (kind and can[kind]) then return end
		if state.mode == 'kind' and node[3] ~= state.name then return end
		if state.mode == 'round' and (map ~= state.map or Far(node, state.x, state.y) > ROUND) then return end
		if visited[node] and now - visited[node] < AGAIN then return end
		if noWay[node] and now - noWay[node] < AGAIN then return end
		local d = Far(node, px, py)
		if not far or d < far then best, far = node, d end
	end)
	return best, map
end

local function Go()
	local node, map = Pick()
	if not node then
		if state.going then
			ns.Print('All nearby nodes were visited in the last 5 minutes. Gathering stopped.')
		else
			-- (the run never began)
			ns.Print(('No %s nodes recorded nearby, or all were visited in the last 5 minutes.')
				:format(state.mode == 'kind' and state.name or 'herb or ore'))
		end
		state = nil
		return
	end
	state.going = node
	ns.SetDestination(map, node[1], node[2], false, false, 'gather', { lines = { 'Gather: ' .. node[3] }, chosen = true })
end

local function Stop()
	local was = state
	state = nil
	if ns.dest and ns.dest.source == 'gather' then
		ns.Stop(false)
		ns.stopped = nil
	end
	return was ~= nil
end

local function Start(mode, name)
	local px, py, map = ns.Place()
	if not px then
		ns.Print('Your position is not available here.')
		return false
	end
	if mode ~= 'kind' and mode ~= 'round' then mode = 'any' end
	if mode == 'kind' and type(name) ~= 'string' then return false end
	if not AbleAny() then
		ns.Print('This character has no gathering profession.')
		return false
	end
	state = { mode = mode, name = name, map = map, x = px, y = py }
	-- One side path at a time, as the base's Gather:Start has it: a run started here (/thread gather)
	-- ends a choice too. (After the run is set, so the look this sets off already sees the run.) A run
	-- that does not start puts the choice back.
	local Choice = ns.Base.Choice
	local had = Choice and Choice.Get and Choice:Get()
	if had and Choice.Clear then Choice:Clear() end
	noWay = {}
	Go()
	if had and not state and Choice.Set then Choice:Set(had.kind, had.id) end
	-- (a flight point search is a side path too: a run that has started ends it; Discover.lua)
	if state and ns.DiscoverStop then ns.DiscoverStop() end
	return state ~= nil
end

function ns.GatherActive()
	return state ~= nil
end

-- Ends the run, if one is on. Returns true when there was one.
function ns.GatherStop()
	return Stop()
end

-- Once a second: a spot reached is noted and the next one gone to.
local function Watch()
	if not state then return end
	if ns.CorpseActive and ns.CorpseActive() then return end  -- (a ghost goes to its corpse first: the run waits; Corpse.lua)
	local dest = ns.dest
	if dest then                                          -- on the way; or a pin of your own, which comes first
		-- a spot no way was found to (Route.lua) is not waited at: it is left out for now, and the next is gone to
		if dest.source == 'gather' and dest.failed and state.going then
			noWay[state.going] = GetTime()
			Go()
			if not state then                                 -- (there is no next: the run is over, and so is the way to this one)
				ns.Stop(false)
				ns.stopped = nil
			end
		end
		return
	end
	local stopped = ns.stopped
	if stopped and stopped.dest and stopped.dest.source == 'gather' then
		ns.stopped = nil
		if stopped.user then                              -- you stopped it yourself: the run is over
			state = nil
			return
		end
		if state.going then visited[state.going] = GetTime() end
	end
	Go()
end

ns.On('PLAYER_LOGIN', function()
	C_Timer.NewTicker(1, function() ns.Try('gathering', Watch) end)
end)

local offered = {
	Near = Near,
	Start = Start,
	Stop = Stop,
	State = function()
		if not state then return nil end
		return { mode = state.mode, name = state.name, going = state.going and state.going[3] or nil }
	end,
	-- a spot another tool tells of (base 2.9.0: Sparkle (Thread)'s herbs and ore you passed)
	Note = function(name, kind, map, x, y) return ns.NodesNote and ns.NodesNote(name, kind, map, x, y) or false end,
}
if ns.Base.Gather and ns.Base.Gather.Offer then
	ns.Base.Gather:Offer(offered)
end

-- /thread gather, /thread gather round, /thread gather Peacebloom, /thread gather stop.
-- fromKey: started with the Toggle Gathering Run key, which also ends it.
function ns.GatherSay(rest, fromKey)
	rest = (rest or ''):gsub('^%s+', ''):gsub('%s+$', '')
	local ends = fromKey and 'Press the key again to stop.' or '/thread gather stop ends it.'
	if rest == 'stop' then
		ns.Print(Stop() and 'Gathering stopped.' or 'No gathering run is active.')
	elseif rest == '' or rest == 'round' then
		if Start(rest == 'round' and 'round' or 'any') then
			ns.Print((rest == 'round' and 'Gathering run started near here: nearest node first, then the next. %s'
				or 'Gathering run started: nearest node first, then the next. %s'):format(ends))
		end
	elseif rest == 'list' then
		if not AbleAny() then
			ns.Print('This character has no gathering profession.')
			return
		end
		local near = Near(8)
		if #near == 0 then ns.Print('No herb or ore nodes recorded nearby.') end
		for _, spot in ipairs(near) do
			ns.Print(('  %s: %d yd'):format(spot.name, math.floor(spot.yards + 0.5)))
		end
	else
		-- a kind, by its name, whatever its case
		local want
		for _, spot in ipairs(Near(50)) do
			if spot.name:lower() == rest:lower() then want = spot.name end
		end
		if not want then
			ns.Print(('No "%s" node recorded nearby. /thread gather list shows what is.'):format(rest))
		elseif Start('kind', want) then
			ns.Print(('Gathering run started: nearest %s first, then the next. %s'):format(want, ends))
		end
	end
end
