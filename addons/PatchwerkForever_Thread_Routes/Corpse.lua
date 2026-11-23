-- Routes (Thread): the way back to your corpse.
--
-- When you have died and released you are a ghost at a graveyard, and your corpse lies where you
-- fell. While that is so the route leads to the corpse, before everything else: a gathering run, a
-- flight point search, a pin of your own, a quest you selected, the focus, the main track. None of
-- those is ended or changed. They wait: Sources.lua, Gather.lua and Discover.lua ask here before they
-- do anything, and Route.lua lets no other destination be set. When you are alive again each is
-- followed as it was: a pin or a spot of your own is gone to again from here, the others find their
-- own way back at their next look.
--
-- A ghost takes no flight, boat, zeppelin or tram, so the way is on foot, and a corpse on another
-- continent than the ghost is not routed to. A ghost also walks on water, and that the planner is
-- not told: what crossing water costs is worked into the map data itself (the walks between a
-- block's gates, made by pack.py), not only into the search, so it cannot be changed for one search
-- without working those walks out again. The way is the one a living character would walk; straight
-- across a lake may be shorter. The time is a living character's too (a ghost runs faster).
--
-- Where the corpse lies is asked of the game as its own world map asks (C_DeathInfo.GetCorpseMapPosition):
-- on each continent's map, since the corpse may lie on another continent than the ghost, then on the
-- map you are on and the maps that one is part of. Where the game gives nothing (the corpse lies in
-- an instance, or you are in one), nothing is routed, your other routes go on, and the chat says why
-- once for a death. Not on a battleground or in an arena, though: there you die again and again, the
-- spirit healer brings you back, and a line in chat for each death would only be in the way.
local ADDON, ns = ...
if not ns.linked then return end

local Ask = ns.Ask
local Guides = ns.Base.Guides
local TRIES = 5           -- looks, a second apart, the game is given to say where the corpse lies before the chat says it does not
local SLOW = 5            -- once that is said, the game is asked only every so many looks
local WORDS = { 'To your corpse' }

-- nil, or while the corpse has the say: { map =, x =, y = where it lies, own = the pin or spot of
-- your own that waits ({ pin = true } or { map =, x =, y =, lines = }), stopped = ns.stopped as it was }
local held
-- nil while you are alive, else this death: { looks =, misses = looks in a row with no place to go
-- to, told = that has been said, done = you reached the corpse or stopped the way to it }
local death
local ticker, Check

-- A value the game lets an addon read (in a fight it may hand over one that can only be passed on).
local function Plain(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- A yes or no the game says of you (UnitIsGhost, UnitIsDeadOrGhost): only a plain true counts.
local function Is(name)
	local yes = Ask(rawget(_G, name), 'player')
	return Plain(yes) and yes == true
end

local function XY(pos)
	if not Plain(pos) or type(pos) ~= 'table' then return nil end
	local x, y = pos.x, pos.y
	if type(pos.GetXY) == 'function' then x, y = Ask(pos.GetXY, pos) end
	if Plain(x) and Plain(y) and type(x) == 'number' and type(y) == 'number' then return x, y end
	return nil
end

-- Where your corpse lies: continent, world x, world y; nothing where the game does not say.
local function Where()
	local info = rawget(_G, 'C_DeathInfo')
	local ask = type(info) == 'table' and info.GetCorpseMapPosition
	if type(ask) ~= 'function' then return nil end
	local asked = {}
	local function On(uiMap)
		if asked[uiMap] then return nil end
		asked[uiMap] = true
		local x, y = XY(Ask(ask, uiMap))
		if not x then return nil end
		local map, wx, wy = Guides.WorldOf(uiMap, x, y)
		if Plain(map) and type(map) == 'number' and type(wx) == 'number' and type(wy) == 'number' then return map, wx, wy end
		return nil
	end
	for _, uiMap in pairs(ns.CONTINENT_MAP) do
		local map, x, y = On(uiMap)
		if map then return map, x, y end
	end
	-- (a continent whose own map is not kept here, Zephras Isle: found from the map you are on)
	local uiMap = C_Map and Ask(C_Map.GetBestMapForUnit, 'player')
	for _ = 1, 4 do
		if not Plain(uiMap) or type(uiMap) ~= 'number' or uiMap == 0 then break end
		local map, x, y = On(uiMap)
		if map then return map, x, y end
		local above = Ask(C_Map.GetMapInfo, uiMap)
		uiMap = Plain(above) and type(above) == 'table' and above.parentMapID or nil
	end
	return nil
end

local function Lead()
	ns.SetDestination(held.map, held.x, held.y, false, false, 'corpse', { lines = WORDS, walkOnly = true })
end

-- The corpse takes the say. What the route went to is not stopped (a stop would be taken for a place
-- you had reached): it is replaced, and a pin or spot of your own is noted, to be gone to again.
local function Take(map, x, y)
	local dest = ns.dest
	held = { map = map, x = x, y = y, stopped = ns.stopped }
	if dest and not dest.source then
		held.own = dest.pin and { pin = true } or { map = dest.map, x = dest.x, y = dest.y, lines = dest.lines }
	end
	Lead()
	if ns.LookNow then ns.LookNow() end                   -- (told to the base at once)
end

-- The corpse gives the say back: you are alive, or it can no longer be gone to.
local function Release()
	local was = held
	held = nil
	if ns.dest and ns.dest.source == 'corpse' then ns.Stop(false) end
	ns.stopped = was.stopped                              -- (as it was, for whoever had not yet seen it)
	local own = was.own
	if own and own.pin then
		-- (the pin as it stands now: moved meanwhile it is gone to in its new place, removed it is not)
		local map, x, y = ns.PinPlace()
		if map then ns.SetDestination(map, x, y, true, false) end
	elseif own then
		ns.SetDestination(own.map, own.x, own.y, false, false, nil, { lines = own.lines })
	end
	if ns.LookNow then ns.LookNow() end                   -- (your guide or quest again at once)
end

local function Watching(on)
	if on and not ticker then
		ticker = C_Timer.NewTicker(1, function() ns.Try('the way to your corpse', Check) end)
	elseif not on and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function Say(why, map)
	local _, kind = Ask(rawget(_G, 'IsInInstance'))
	if Plain(kind) and (kind == 'pvp' or kind == 'arena') then return end
	if why == 'far' then
		ns.Print(('Your corpse is on another continent (%s). A ghost takes no boat or zeppelin, so it is not routed to.')
			:format(ns.ContinentName(map)))
	elseif why == 'here' then
		ns.Print('Your position is not available here, so your corpse is not routed to.')
	else
		ns.Print('Your corpse has no location on the map (it may be in an instance), so it is not routed to.')
	end
end

-- Looked at when you die, release or come back to life, and once a second while you are dead (a
-- ticker that runs only then): the game says where the corpse lies a moment after you release.
Check = function()
	if not (ns.Get('corpse') and (Is('UnitIsDeadOrGhost') or Is('UnitIsGhost'))) then
		-- alive, or the setting is off: what waited is followed again
		if held then Release() end
		death = nil
		Watching(false)
		return
	end
	Watching(true)
	death = death or { looks = 0, misses = 0 }
	if not Is('UnitIsGhost') then                         -- dead and not released: you lie where your corpse does
		if held then Release() end
		return
	end
	local px, _, here = ns.Place()
	if held then
		if px and here ~= held.map then
			Release()                                         -- (carried to another continent as a ghost: looked at afresh, below)
		else
			local dest = ns.dest
			if not (dest and dest.source == 'corpse') and not death.done then
				-- The way to it is gone: you are there, or you stopped it. Nothing more is routed for this
				-- death (Start Routing leads there again), and the stop is not left for the others to read.
				death.done = true
				local stopped = ns.stopped
				if stopped and stopped.dest and stopped.dest.source == 'corpse' then ns.stopped = nil end
			end
			return
		end
	end
	if death.done then return end
	death.looks = death.looks + 1
	if death.told and death.looks % SLOW ~= 0 then return end
	local map, x, y = Where()
	local why = (not px and 'here') or (not map and 'none') or (map ~= here and 'far') or nil
	if why then
		death.misses = death.misses + 1
		if death.misses >= TRIES and not death.told then
			death.told = true
			Say(why, map)
		end
		return
	end
	death.misses = 0
	Take(map, x, y)
end

-- Whether the way to your corpse has the say now (asked by whatever else would lead).
function ns.CorpseActive()
	return held ~= nil
end

-- Asked by Route.lua before any other destination is set. true: not now. A pin or a spot of your own
-- is kept in place of the one that waited, and where you asked for it yourself that is said.
function ns.CorpseHolds(map, x, y, pin, announce, source, more)
	if not held then return false end
	if not source then
		held.own = pin and { pin = true } or { map = map, x = x, y = y, lines = type(more) == 'table' and more.lines or nil }
		if announce then
			ns.Print(pin and 'Your corpse comes first. Your map pin is routed to once you are alive.'
				or 'Your corpse comes first. The coordinates you gave are routed to once you are alive.')
		end
	end
	return true
end

-- Start Routing while the corpse has the say: the way to it, again if you had stopped it or reached
-- it. Returns true when that was done (Route.lua then does nothing else).
function ns.CorpseGo()
	if not held then return false end
	if death then death.done = nil end
	if ns.Get('notify') then ns.Print('Routing to your corpse:') end
	ns.SetDestination(held.map, held.x, held.y, false, true, 'corpse', { lines = WORDS, walkOnly = true })
	return true
end

for _, event in ipairs({ 'PLAYER_DEAD', 'PLAYER_ALIVE', 'PLAYER_UNGHOST', 'PLAYER_ENTERING_WORLD' }) do
	ns.Try('listening for ' .. event, ns.On, event, function() ns.Try('the way to your corpse', Check) end)
end
ns.OnSetting(function(key)
	if key == 'corpse' then Check() end
end)

-- (for the checks: what waits, and how this death stands)
function ns.CorpseState()
	return { held = held, death = death, watching = ticker ~= nil }
end
