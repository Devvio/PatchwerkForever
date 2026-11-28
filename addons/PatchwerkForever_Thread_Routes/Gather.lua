-- Routes (Thread): gathering. The way to the nearest herb or ore spot, and on to the next.
--
-- The spots are the ones remembered from your own gathering (Nodes.lua) and, with GatherMate2 installed,
-- its spots (GatherMate.lua): they show where things grow, not whether one is there now. The next spot
-- is the first of the shortest walk through three (Pick), and spots above your skill are left out, or
-- kept with a note when the setting Nodes Above Your Skill allows them. So a gathering run does not stop at a spot: when you reach it, the
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
	local out = { h = false, o = false, rank = {} }
	for _, index in pairs({ a, b, c, d, e }) do           -- (any of them can be nil)
		-- (pcall's true first, then the skill level third and the skill line seventh)
		local _, _, _, rank, _, _, _, line = pcall(info, index)
		local kind = (line == herbs and 'h') or (line == ore and 'o') or nil
		if kind then
			out[kind] = true
			if type(rank) == 'number' then out.rank[kind] = rank end
		end
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

-- Your Herbalism and Mining skill where the profession book did not give it: the skills list of the
-- older clients (GetSkillLineInfo: name first, skill level fourth), by the professions' English names.
local SKILL_NAMES = { Herbalism = 'h', Mining = 'o' }
local function AskSkillLines(rank)
	local num, info = rawget(_G, 'GetNumSkillLines'), rawget(_G, 'GetSkillLineInfo')
	if type(num) ~= 'function' or type(info) ~= 'function' then return end
	local ok, n = pcall(num)
	for i = 1, (ok and type(n) == 'number') and n or 0 do
		local got, name, header, _, level = pcall(info, i)
		local kind = got and not header and SKILL_NAMES[name]
		if kind and rank[kind] == nil and type(level) == 'number' then rank[kind] = level end
	end
end

local function Able()
	if not able or GetTime() - ableAt > KEEP then
		able, ableAt = AskProfessions() or AskSpells() or { h = true, o = true }, GetTime()
		able.rank = able.rank or {}
		AskSkillLines(able.rank)
	end
	return able
end

-- Whether a spot is one to go to for its skill: false when it asks for more than your skill and the
-- setting Nodes Above Your Skill allows; else true, and the skill it asks for when that is above yours.
-- Where your skill or the spot's is not known, it is gone to.
local function SkillOk(node, kind, can)
	local need = ns.NodeSkill and ns.NodeSkill(node)
	local have = can.rank and can.rank[kind]
	if not (need and have) or need <= have then return true end
	if need > have + (ns.Get('gatherAbove') or 0) then return false end
	return true, need, have
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

-- Calls fn(spot, kind) for each spot within `reach` yards of a place: the ones Routes remembers
-- (Nodes.lua), then GatherMate2's (GatherMate.lua; its kind is its own).
local function Each(map, x, y, reach, fn)
	ns.NodesAround(map, x, y, reach, function(node)
		local kind = ns.NodeKind(node[3])
		if kind then fn(node, kind) end
	end)
	if ns.GatherMateAround then
		ns.GatherMateAround(map, x, y, reach, function(node) fn(node, node.kind) end)
	end
end

-- The nearest spot of each thing you can gather, nearest first: `count` of them at most.
local function Near(count)
	local px, py, map = ns.Place()
	if not px then return {} end
	local can, best = Able(), {}
	Each(map, px, py, REACH, function(node, kind)
		if can[kind] and SkillOk(node, kind, can) then
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

-- The spot to go to next: not simply the nearest, but the first of the shortest walk through three
-- spots, tried over the nearest few. So a run works through a cluster before it leaves it, instead
-- of going to a lone spot a little nearer and coming back. A spot above your skill (kept by the
-- setting Nodes Above Your Skill) counts as farther than it is, so the ones you can gather come first.
local LOOK = 12               -- spots looked at for the walk through three
local ABOVE = 1.5             -- how much farther a spot above your skill counts

-- Density: a candidate with many spots round it is worth more, so the run leans toward rich ground
-- rather than only the nearest group. Each spot you could go to within DENSE yards of it counts
-- (one above your skill half), up to DENSE_MOST; the walk through three is then made shorter by
-- DENSITY for each. GatherMate2's data is where things can grow, not what is up now: density says
-- where a run is worth making, not which spot holds a node.
local DENSE = 150             -- yards round a candidate whose spots count for it
local DENSE_MOST = 20         -- spots counted at most
local DENSITY = 0.08          -- how much shorter the walk counts for each spot round its first stop

-- The order to go in, from the nearest candidates: the first spot of the cheapest three. cands: { node, far, above }.
local function Ahead(cands, px, py)
	local function Cost(a, _, to)        -- (from a spot, or from you with a nil, to another; above: farther)
		local ax, ay = a and a.node[1] or px, a and a.node[2] or py
		local d = math.sqrt((to.node[1] - ax) ^ 2 + (to.node[2] - ay) ^ 2)
		return to.need and d * ABOVE or d
	end
	local best, bestCost
	local n = #cands
	for i = 1, n do
		local a = cands[i]
		local ca = Cost(nil, nil, a)
		if not bestCost or ca < bestCost then
			local tail = 0
			if n > 1 then
				tail = nil
				for j = 1, n do
					if j ~= i then
						local b = cands[j]
						local cb = Cost(a, nil, b)
						local cc = 0
						if n > 2 then
							cc = nil
							for k = 1, n do
								if k ~= i and k ~= j then
									local c = Cost(b, nil, cands[k])
									if not cc or c < cc then cc = c end
								end
							end
						end
						if not tail or cb + cc < tail then tail = cb + cc end
					end
				end
			end
			-- (shorter for the spots round its first stop: Density, above)
			local cost = (ca + tail) / (1 + DENSITY * (a.dense or 0))
			if not bestCost or cost < bestCost then best, bestCost = a, cost end
		end
	end
	return best
end

-- Whether a spot is one this run may go to now: ok, and the skill it asks for and yours when that is
-- above yours (see SkillOk). Not one of a kind you cannot gather, of another kind than the run's, out
-- of a round's reach, or one you have been to (or found no way to) a short while ago.
local function Eligible(node, kind, can, now)
	if not can[kind] then return false end
	if state.mode == 'kind' and node[3] ~= state.name then return false end
	if state.mode == 'round' and Far(node, state.x, state.y) > (state.radius or ROUND) then return false end
	if visited[node] and now - visited[node] < AGAIN then return false end
	if noWay[node] and now - noWay[node] < AGAIN then return false end
	return SkillOk(node, kind, can)
end

local function Pick()
	local px, py, map = ns.Place()
	if not (px and state) then return nil end
	if state.mode == 'round' and map ~= state.map then return nil end
	local can, now = Able(), GetTime()
	local cands = {}
	-- (a round looks round where it is, which may be far from you: a run to the best area starts there)
	local cx, cy, reach = px, py, REACH
	if state.mode == 'round' then cx, cy, reach = state.x, state.y, state.radius or ROUND end
	Each(map, cx, cy, reach, function(node, kind)
		local ok, need, have = Eligible(node, kind, can, now)
		if not ok then return end
		cands[#cands + 1] = { node = node, kind = kind, far = Far(node, px, py), need = need, have = have }
	end)
	if #cands == 0 then return nil end
	table.sort(cands, function(a, b) return (a.need and a.far * ABOVE or a.far) < (b.need and b.far * ABOVE or b.far) end)
	for i = #cands, LOOK + 1, -1 do cands[i] = nil end
	for _, c in ipairs(cands) do
		local dense = 0
		Each(map, c.node[1], c.node[2], DENSE, function(other, kind)
			if other ~= c.node and Far(other, c.node[1], c.node[2]) <= DENSE then
				local ok, need = Eligible(other, kind, can, now)
				if ok then dense = dense + (need and 0.5 or 1) end
			end
		end)
		c.dense = math.min(dense, DENSE_MOST)
	end
	local chosen = Ahead(cands, px, py)
	return chosen.node, map, chosen
end

-- The best area on your continent to gather in: the place with the most spots you could go to within
-- BEST_RADIUS yards (one above your skill counts half), a little less for one far away (up to half at
-- BEST_FAR yards). Returns its middle (the mean of its spots), how many it has and how far it is; or nothing.
local BEST_RADIUS = 400       -- yards round an area's middle that its spots lie within
local BEST_REACH = 20000      -- yards round you that areas are looked for in (a whole continent)
local BEST_CELL = 200         -- yards a side of the squares spots are counted in first
local BEST_FAR = 10000        -- yards at which an area counts half
local BEST_TRY = 12           -- the best squares then counted exactly
-- The densest area among weighted spots ({ x, y, weight }, all on one continent) from where you stand:
-- its middle, its weight, how far. For gathering (below) and for skinning and drops (Farm.lua).
function ns.DensestArea(spots, px, py)
	if #spots == 0 then return nil end
	local cells = {}
	for _, s in ipairs(spots) do
		local key = math.floor((s[1] + 40000) / BEST_CELL) * 1000 + math.floor((s[2] + 40000) / BEST_CELL)
		cells[key] = (cells[key] or 0) + s[3]
	end
	-- first by squares: each square's spots and those of the squares round it
	local span = math.floor(BEST_RADIUS / BEST_CELL)
	local rough = {}
	for key in pairs(cells) do
		local i, j = math.floor(key / 1000), key % 1000
		local sum = 0
		for a = i - span, i + span do
			for b = j - span, j + span do sum = sum + (cells[a * 1000 + b] or 0) end
		end
		rough[#rough + 1] = { i = i, j = j, sum = sum }
	end
	table.sort(rough, function(a, b) return a.sum > b.sum end)
	-- then the best few exactly: the spots within the radius of the square's middle, and their mean
	local best, bestScore
	for n = 1, math.min(BEST_TRY, #rough) do
		local r = rough[n]
		local mx, my = (r.i + 0.5) * BEST_CELL - 40000, (r.j + 0.5) * BEST_CELL - 40000
		local count, sx, sy = 0, 0, 0
		for _, s in ipairs(spots) do
			if (s[1] - mx) ^ 2 + (s[2] - my) ^ 2 <= BEST_RADIUS * BEST_RADIUS then
				count, sx, sy = count + s[3], sx + s[1] * s[3], sy + s[2] * s[3]
			end
		end
		if count > 0 then
			local ax, ay = sx / count, sy / count
			local far = math.sqrt((ax - px) ^ 2 + (ay - py) ^ 2)
			local score = count * (1 - 0.5 * math.min(far, BEST_FAR) / BEST_FAR)
			if not bestScore or score > bestScore then best, bestScore = { x = ax, y = ay, count = count, far = far }, score end
		end
	end
	return best
end
ns.BEST_RADIUS = BEST_RADIUS

local function Best(map, px, py, can)
	local now = GetTime()
	local spots = {}
	Each(map, px, py, BEST_REACH, function(node, kind)
		local ok, need = Eligible(node, kind, can, now)
		if ok then spots[#spots + 1] = { node[1], node[2], need and 0.5 or 1 } end
	end)
	return ns.DensestArea(spots, px, py)
end

-- A spot reached: it, and every spot of the same kind within a few yards (the same spot told by
-- GatherMate2 and by Routes), are left out for a while.
local SAME = 15
local function Reached(node)
	local now = GetTime()
	visited[node] = now
	local px, py, map = ns.Place()
	if not px then return end
	local kind = node.kind or ns.NodeKind(node[3])
	-- (Each gives whole squares of spots: the ones within SAME yards are picked out here)
	Each(map, node[1], node[2], SAME, function(other, okind)
		if okind == kind and Far(other, node[1], node[2]) <= SAME then visited[other] = now end
	end)
end

local PROFESSION = { h = 'Herbalism', o = 'Mining' }

local function Go()
	local node, map, chosen = Pick()
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
	local line = 'Gather: ' .. node[3]
	if chosen and chosen.need then
		-- (one above your skill, kept by the setting: said, so you know it cannot be gathered yet)
		line = ('%s (needs %s %d; you have %d)'):format(line, PROFESSION[chosen.kind] or 'skill', chosen.need, chosen.have)
	end
	-- (a run in the best area: the area is drawn on the maps, Area.lua)
	local area = state.best and { map = state.map, x = state.x, y = state.y, radius = state.radius } or nil
	ns.SetDestination(map, node[1], node[2], false, false, 'gather', { lines = { line }, chosen = true, area = area })
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
	if mode ~= 'kind' and mode ~= 'round' and mode ~= 'best' then mode = 'any' end
	if mode == 'kind' and type(name) ~= 'string' then return false end
	if not AbleAny() then
		ns.Print('This character has no gathering profession.')
		return false
	end
	local before = state
	if mode == 'best' then
		-- the best area on the continent: found first, then gone round as a round with its middle there
		state = { mode = 'any' }
		local area = Best(map, px, py, Able())
		state = before
		if not area then
			ns.Print('No herb or ore nodes you can gather are known on this continent.')
			return false
		end
		state = { mode = 'round', map = map, x = area.x, y = area.y, radius = BEST_RADIUS, best = area }
		ns.Print(('Best gathering area: %d nodes you can gather within %d yards, %d yards away.')
			:format(math.floor(area.count + 0.5), BEST_RADIUS, math.floor(area.far + 0.5)))
	else
		state = { mode = mode, name = name, map = map, x = px, y = py }
	end
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
	if state and ns.GiversStop then ns.GiversStop() end
	return state ~= nil
end

function ns.GatherActive()
	return state ~= nil
end

-- The best area as a look, for the tracker's row: { count =, yards = }, or nil. Looked at again after
-- LOOK_AGAIN seconds, or once you have moved LOOK_MOVED yards.
local LOOK_AGAIN, LOOK_MOVED = 30, 300
local look
function ns.GatherBestLook()
	local px, py, map = ns.Place()
	if not px or not AbleAny() then return nil end
	if look and look.map == map and GetTime() - look.at < LOOK_AGAIN
		and (px - look.x) ^ 2 + (py - look.y) ^ 2 < LOOK_MOVED * LOOK_MOVED then
		return look.area
	end
	local before = state
	state = { mode = 'any' }
	local ok, area = pcall(Best, map, px, py, Able())
	state = before
	area = ok and area or nil
	look = { map = map, x = px, y = py, at = GetTime(),
		area = area and { count = math.floor(area.count + 0.5), yards = area.far } or nil }
	return look.area
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
		if state.going then Reached(state.going) end
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
		return { mode = state.mode, name = state.name, going = state.going and state.going[3] or nil,
			best = state.best and { x = state.best.x, y = state.best.y, count = state.best.count } or nil }
	end,
	-- the best area, looked at for the tracker (kept a while: the look goes over the whole continent)
	Best = function() return ns.GatherBestLook() end,
	Skin = function() return ns.SkinSay and ns.SkinSay('') end,
	SkinKnown = function() return ns.SkinKnown and ns.SkinKnown() or 0 end,
	CanFarm = function(text) return ns.FarmCan and ns.FarmCan(text) or nil end,
	Farm = function(text) return ns.FarmSay and ns.FarmSay(text) end,
	Tracking = function() return ns.TrackingMode and ns.TrackingMode() or nil end,
	Givers = function(on) return ns.GiversSay and ns.GiversSay(on and '' or 'stop') end,
	GiversState = function() return ns.GiversInfo and ns.GiversInfo() or nil end,
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
	elseif rest == 'best' then
		if Start('best') then
			ns.Print(('Gathering run started in the best area: there first, then round it. %s'):format(ends))
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
