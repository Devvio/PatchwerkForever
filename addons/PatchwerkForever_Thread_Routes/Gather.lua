-- Thread (Routes): gathering. The way to the nearest herb or ore spot, and on to the next.
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
--
-- This is offered through the base (its Gather service), which is how the tracker lists the spots
-- and starts a run without knowing this addon. /thread gather does the same from the chat.
local ADDON, ns = ...
if not ns.linked then return end

local REACH = 3000            -- yards within which a spot is looked for
local ROUND = 1200            -- yards from where a round began that its spots lie within
local AGAIN = 300             -- seconds before a spot you have been to is gone to again
local HERBS, ORE = 2383, 2580 -- Find Herbs and Find Minerals: learned with the profession

local state                   -- nil, or { mode =, name =, map =, x =, y = (where it began), going = the spot gone to }
local visited = {}            -- [spot] = when you reached it
-- [spot] = when no way was found to it. Left out like one you have been to, but only for the run that
-- is on: that was from where you stood, and the next run may start where there is a way.
local noWay = {}

-- What this character can gather: { h = true, o = true }. The game is asked whether the profession's
-- tracking spell is known; when it will not say, or says neither, both are taken as possible.
local function Able()
	local known = rawget(_G, 'IsPlayerSpell') or rawget(_G, 'IsSpellKnown')
	if type(known) ~= 'function' then return { h = true, o = true } end
	local okH, herbs = pcall(known, HERBS)
	local okO, ore = pcall(known, ORE)
	if not (okH and okO) or not (herbs or ore) then return { h = true, o = true } end
	return { h = herbs and true or false, o = ore and true or false }
end

local function Far(node, x, y)
	return math.sqrt((node[1] - x) ^ 2 + (node[2] - y) ^ 2)
end

-- The nearest spot of each thing you can gather, nearest first: `count` of them at most.
local function Near(count)
	local px, py, map = ns.Place()
	if not px then return {} end
	local able, best = Able(), {}
	ns.NodesAround(map, px, py, REACH, function(node)
		local kind = ns.NodeKind(node[3])
		if kind and able[kind] then
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
	local able, now = Able(), GetTime()
	local best, far
	ns.NodesAround(map, px, py, REACH, function(node)
		local kind = ns.NodeKind(node[3])
		if not (kind and able[kind]) then return end
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
		ns.Print(state.mode == 'kind' and ('No unvisited %s node recorded nearby. Gathering stopped.'):format(state.name)
			or 'No unvisited herb or ore node recorded nearby. Gathering stopped.')
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
	state = { mode = mode, name = name, map = map, x = px, y = py }
	-- one side path at a time, as the base's Gather:Start has it: a run started here (/thread gather)
	-- ends a choice too. (After the run is set, so the look this sets off already sees the run.)
	local Choice = ns.Base.Choice
	if Choice and Choice.Clear then Choice:Clear() end
	noWay = {}
	Go()
	return state ~= nil
end

function ns.GatherActive()
	return state ~= nil
end

-- Once a second: a spot reached is noted and the next one gone to.
local function Watch()
	if not state then return end
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
}
if ns.Base.Gather and ns.Base.Gather.Offer then
	ns.Base.Gather:Offer(offered)
end

-- /thread gather, /thread gather round, /thread gather Peacebloom, /thread gather stop
function ns.GatherSay(rest)
	rest = (rest or ''):gsub('^%s+', ''):gsub('%s+$', '')
	if rest == 'stop' then
		ns.Print(Stop() and 'Gathering stopped.' or 'No gathering run is active.')
	elseif rest == '' or rest == 'round' then
		if Start(rest == 'round' and 'round' or 'any') then
			ns.Print(rest == 'round' and 'Farming nearby nodes: routing to the next one at each. /thread gather stop to end.'
				or 'Routing to the nearest node, then the next at each. /thread gather stop to end.')
		end
	elseif rest == 'list' then
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
			ns.Print(('Routing to the nearest %s, then the next at each. /thread gather stop to end.'):format(want))
		end
	end
end
