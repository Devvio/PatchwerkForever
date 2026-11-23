-- Routes (Thread): the flight point search. The way to the nearest flight point you lack, and on to the next.
--
-- /thread discover leads to the nearest flight point of your side that this character has not
-- discovered. When that one is discovered the route goes on to the next nearest, until none is left
-- on the continent or you stop it.
--
-- Which points you lack is Flights.lua's to say, and it can only say so once a flight map has been
-- opened at a flight master on the continent: before that, a point not known may just never have been
-- read. So without one the search does not start, and says what to do.
--
-- A search is a side path as a gathering run is (Gather.lua), and made the same way: a destination
-- like any other (its source is 'discover'), found as any other (it may fly between points you have),
-- one side path at a time (starting it ends a gathering run and lets a selected quest go, and either
-- of those ends the search), a pin of your own still first, Start Routing ends it. While one is on,
-- your guide and your quests are not followed.
--
-- A flight point is discovered at its flight master, so reaching the place is not the end of it: the
-- search waits there until the game says the point is yours (Flights.lua hears that, and the flight
-- map when it is opened), then goes on. Three kinds of point are left out for the rest of the search,
-- and named when it ends: one no way was found to, one the map data has no walk to at all (the flight
-- masters inside Ironforge and the Undercity: a search for the way there could only fail, and a whole
-- search that fails is the dearest there is), and one you walked away from without it being
-- discovered (not every point can be had by every character).
local ADDON, ns = ...
if not ns.linked then return end

local P = ns.Planner
local AWAY = 60               -- yards you must walk from a flight point you reached before it is given up as not discovered

-- nil, or { going = the point gone to (the map data's own row), map = its continent, x =, y = its place,
-- at = true once you have reached it, left = { [point id] = its name, for each one left out } }
local state

-- A flight point's name without its zone: "Crossroads" of "Crossroads, The Barrens".
local function Short(point)
	local name = tostring(point[2])
	return name:match('^[^,]+') or name
end

-- Whether a flight point is one you have now. (A search is only on where a flight map has been read,
-- so what is remembered of the point is the whole answer.)
local function Have(point)
	return ns.FlightHave(point[1])
end

-- Whether you are on a flight path. One may pass right over a flight point, which is not being there.
local function Aloft()
	return ns.Ask(rawget(_G, 'UnitOnTaxi'), 'player') == true
end

-- The names of the points left out, in order.
local function LeftOut()
	local names = {}
	for _, name in pairs(state.left) do names[#names + 1] = name end
	table.sort(names)
	return names
end

-- The point to go to next and its continent. Nothing when there is none, with why: 'unread' (no flight
-- map opened on this continent), 'data' (no map data: said already) or nil (none left). false when
-- your position is not to be had (in an instance): the search waits.
local function Pick()
	local px, py, map = ns.Place()
	if not px then return false end
	if not ns.Data(map) then return nil, 'data' end
	local lacking, read = ns.FlightsLacking(map)
	if not read then return nil, 'unread' end
	local cx, cy = P.CellOf(map, px, py)
	local best, far
	for _, p in ipairs(lacking) do
		if not state.left[p[1]] then
			-- (one the map data has no walk to, from where it stands to anywhere: there is no way to find)
			if not p[6] then
				state.left[p[1]] = tostring(p[2])
			else
				local d = (p[3] - cx) ^ 2 + (p[4] - cy) ^ 2
				if not far or d < far then best, far = p, d end
			end
		end
	end
	if not best then return nil end
	return best, map
end

-- The search is over: said, with the points left out where there are any.
local function Finish(why)
	local names = LeftOut()
	state = nil
	if why == 'unread' then
		ns.Print('Flight point search stopped: open the flight map at a flight master on this continent first.')
	elseif why == 'data' then
		ns.Print('Flight point search stopped.')
	elseif #names > 0 then
		ns.Print(('Flight point search ended. Not reached or not discovered: %s.'):format(table.concat(names, '; ')))
	else
		ns.Print('All flight points on this continent are known.')
	end
end

-- Goes to the next point, or ends the search where there is none. point, map: one picked already.
local function Go(point, map)
	if not point then point, map = Pick() end
	if point == false then return end                     -- (no position here: tried again at the next look)
	if not point then return Finish(map) end              -- (with why, where Pick gave one)
	local x, y = P.WorldOf(map, point[3], point[4])
	state.going, state.map, state.x, state.y, state.at = point, map, x, y, nil
	ns.SetDestination(map, x, y, false, false, 'discover',
		{ lines = { 'Discover the flight point at ' .. Short(point) }, chosen = true })
end

local function Stop()
	local was = state
	state = nil
	if ns.dest and ns.dest.source == 'discover' then
		ns.Stop(false)
		ns.stopped = nil
	end
	return was ~= nil
end

local function Start()
	local px, _, map = ns.Place()
	if not px then
		ns.Print('Your position is not available here.')
		return false
	end
	if not ns.Side() then
		ns.Print('Your faction is not known yet, so your flight points cannot be told from the others.')
		return false
	end
	-- (the map data holds the flight points: loaded first, where no route has loaded it yet)
	if not ns.Data(map, true) then return false end
	local lacking, read, any = ns.FlightsLacking(map)
	if not any then
		ns.Print('No flight points on this map.')
		return false
	end
	if not read then
		ns.Print('Open the flight map at a flight master first. Until then, a flight point you have not discovered cannot be told from one that was never read.')
		return false
	end
	if #lacking == 0 then
		ns.Print('All flight points on this continent are known.')
		return false
	end
	local before = state
	state = { left = {} }
	local point = Pick()
	if not point then
		-- (points you lack, and none of them can be gone to: said, and a search that was on stays as it was)
		ns.Print(('No route to the flight points you have not discovered: %s.'):format(table.concat(LeftOut(), '; ')))
		state = before
		return false
	end
	-- One side path at a time: a search ends a gathering run and lets a selected quest go. (After the
	-- search is set, so the look this sets off already sees it.)
	if ns.GatherActive and ns.GatherActive() and ns.GatherStop() then ns.Print('Gathering stopped.') end
	local Choice = ns.Base.Choice
	if Choice and Choice.Get and Choice:Get() and Choice.Clear then Choice:Clear() end
	Go(point, map)
	return state ~= nil
end

function ns.DiscoverActive()
	return state ~= nil
end

-- Ends the search, if one is on. Returns true when there was one.
function ns.DiscoverStop()
	return Stop()
end

-- Once a second: a point discovered is left behind and the next one gone to.
local function Watch()
	if not state then return end
	if ns.CorpseActive and ns.CorpseActive() then return end  -- (a ghost goes to its corpse first: the search waits; Corpse.lua)
	local dest, going = ns.dest, state.going
	local mine = dest ~= nil and dest.source == 'discover'
	if going and Have(going) then              -- discovered: on to the next
		state.going, state.at, going = nil, nil, nil
		if mine then
			ns.Stop(false)
			ns.stopped = nil
			dest, mine = nil, false
		end
	end
	if dest and not mine then return end                  -- a pin of your own, which comes first
	if mine then
		-- a point no way was found to (Route.lua) is not waited at: it is left out, and the next is gone to
		if dest.failed and going then
			state.left[going[1]] = tostring(going[2])
			Go()
			if not state then                                 -- (there is no next: the search is over, and so is the way to this one)
				ns.Stop(false)
				ns.stopped = nil
			end
		end
		return
	end
	local stopped = ns.stopped
	if stopped and stopped.dest and stopped.dest.source == 'discover' then
		ns.stopped = nil
		if stopped.user then                              -- you stopped it yourself: the search is over
			state = nil
			return
		end
		-- you are there. The point is yours once its flight master says so: waited for, and said once
		if going and not state.at and not Aloft() then
			state.at = true
			if ns.Get('notify') then
				ns.Print(('You have arrived at %s. Speak to the flight master to discover the flight point.'):format(Short(going)))
			end
		end
	end
	if going and state.at then
		-- still there, waiting; walked away with it not discovered: it is left out, and the next is gone to
		local px, py, map = ns.Place()
		if not px or Aloft() or (map == state.map and (px - state.x) ^ 2 + (py - state.y) ^ 2 <= AWAY * AWAY) then return end
		state.left[going[1]] = tostring(going[2])
		ns.Print(('%s was not discovered, and is left out of this search.'):format(Short(going)))
	end
	Go()
end

ns.On('PLAYER_LOGIN', function()
	C_Timer.NewTicker(1, function() ns.Try('the flight point search', Watch) end)
end)

-- A quest or a list you select is a side path too: it ends the search. (A gathering run started
-- ends it in Gather.lua.)
local Choice = ns.Base.Choice
if Choice and Choice.OnChange then
	Choice:OnChange(function(choice)
		if choice and state then Stop() end
	end)
end

-- /thread discover, /thread discover stop. fromKey: asked for with the Toggle Flight Point Search key,
-- which also ends it.
function ns.DiscoverSay(rest, fromKey)
	rest = (rest or ''):gsub('^%s+', ''):gsub('%s+$', '')
	if rest == 'stop' then
		ns.Print(Stop() and 'Flight point search stopped.' or 'No flight point search is active.')
	elseif rest == '' then
		if Start() then
			ns.Print(('Flight point search started: nearest undiscovered flight point first, then the next. %s')
				:format(fromKey and 'Press the key again to stop.' or '/thread discover stop ends it.'))
		end
	else
		ns.Print('Usage: /thread discover, or /thread discover stop.')
	end
end

-- (for the checks: where the search stands)
function ns.DiscoverState()
	if not state then return nil end
	return { going = state.going and state.going[2] or nil, at = state.at or false, left = LeftOut() }
end
