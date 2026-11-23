-- Sparkle (Thread): the chests, herbs and ore you passed (1.5.0).
--
-- A chest, an herb or a vein that the game pointed at and that you walked away from without opening or
-- gathering it is remembered, with where you were: halfway between where you stood when it came into
-- reach and where you stood when it left, which is about where you passed nearest. Nothing tells an
-- addon where the thing itself is, so the spot is yours, a few yards from it.
--
-- What is done with it:
--   - listed on the Sparkle: Passed page (nearest first) and by /sparkle passed;
--   - Add To Route puts it on My Route (the base's, as a place), which Routes (Thread) leads you along
--     and Tracker (Thread) and the Globe show;
--   - herbs and ore are given to Routes (Thread) through the base's Gather service (Gather:Note, base
--     2.9.0), so they show on its maps with the spots you gathered from and a gathering run goes there.
-- Gathering or opening one later takes it off the list.
--
-- Saved in PatchwerkForever_Thread_SparkleDB.passed = { { name =, kind = 'herb', 'ore' or 'loot', map =,
-- x =, y = (world coordinates, as the game gives your own place), at = (the date, in seconds) }, ... }.
local ADDON, ns = ...
if not ns.linked then return end

local KINDS = { herb = 'Herb', ore = 'Ore', loot = 'Chest' }
local SAME = 20               -- yards within which two of one name are the same one
local GLANCE = 1              -- seconds an object must be in reach to count as passed (not a flicker)
local KEEP_DAYS = 7           -- days an entry is kept
local MOST = 80               -- entries kept at most; the oldest go first
local LISTED = 8              -- entries /sparkle passed lists

local current                 -- the object in reach: { name =, kind =, map =, x =, y =, x2 =, y2 =, since =, taken = }

local function Now()
	local clock = rawget(_G, 'time') or rawget(_G, 'GetServerTime')
	local ok, t = pcall(clock or function() return 0 end)
	return ok and type(t) == 'number' and t or 0
end

local function List()
	local db = PatchwerkForever_Thread_SparkleDB
	if type(db) ~= 'table' then return {} end
	db.passed = type(db.passed) == 'table' and db.passed or {}
	return db.passed
end

local function Yards(entry, x, y, map)
	if not (x and entry.map == map) then return nil end
	return ((entry.x - x) ^ 2 + (entry.y - y) ^ 2) ^ 0.5
end

-- The entry of this name within SAME yards of a place, and its index.
local function Near(name, map, x, y)
	for i, entry in ipairs(List()) do
		if entry.name == name then
			local d = Yards(entry, x, y, map)
			if d and d <= SAME then return entry, i end
		end
	end
	return nil
end

-- Old entries go, and the oldest past MOST.
local function Tidy()
	local list, now = List(), Now()
	for i = #list, 1, -1 do
		local entry = list[i]
		if type(entry) ~= 'table' or type(entry.x) ~= 'number' or (now > 0 and (entry.at or 0) > 0 and now - entry.at > KEEP_DAYS * 86400) then
			table.remove(list, i)
		end
	end
	table.sort(list, function(a, b) return (a.at or 0) > (b.at or 0) end)
	for i = #list, MOST + 1, -1 do list[i] = nil end
end

-- Herbs and ore to Routes (Thread), through the base: shown on its maps, gone to on a gathering run.
local function Share(entry)
	if not ns.Get('passedRoutes') or (entry.kind ~= 'herb' and entry.kind ~= 'ore') then return end
	local gather = ns.Base and ns.Base.Gather
	if not (gather and type(gather.Note) == 'function') then return end
	pcall(gather.Note, gather, entry.name, entry.kind == 'herb' and 'h' or 'o', entry.map, entry.x, entry.y)
end

-- An object has left your reach.
local function Passed(seen)
	if seen.taken or not ns.Get('passed') or GetTime() - seen.since < GLANCE then return end
	local x, y = (seen.x + (seen.x2 or seen.x)) / 2, (seen.y + (seen.y2 or seen.y)) / 2
	local entry = Near(seen.name, seen.map, x, y)
	if entry then
		entry.x, entry.y, entry.at = x, y, Now()
	else
		entry = { name = seen.name, kind = seen.kind, map = seen.map, x = x, y = y, at = Now() }
		table.insert(List(), entry)
	end
	Tidy()
	Share(entry)
end

-- Taken after all (gathered or opened): off the list, where it is on it.
local function Taken()
	if not current then return end
	current.taken = true
	local x, y, map = ns.Here()
	if not x then return end
	local _, i = Near(current.name, map, x, y)
	if i then table.remove(List(), i) end
end

-- Sparkle.lua tells what the game points at, at every look: `was` its record (name, kind, ...), or
-- nothing when it points at nothing.
function ns.PassedSee(was)
	local wanted = was and was.name and KINDS[was.kind] and not was.ignored
	if current and not (wanted and was.name == current.name) then
		local seen = current
		current = nil
		Passed(seen)
	end
	if not wanted then return end
	local x, y, map = ns.Here()
	if not x then return end                              -- (in an instance the game keeps your place to itself)
	if current then
		if map == current.map then current.x2, current.y2 = x, y end
		return
	end
	current = { name = was.name, kind = was.kind, map = map, x = x, y = y, since = GetTime() }
end

pcall(ns.On, 'UNIT_SPELLCAST_SENT', function(unit, target)
	if unit == 'player' and current and target == current.name then Taken() end
end)
pcall(ns.On, 'LOOT_OPENED', function() if current then Taken() end end)

---------------------------------------------------------------------------
-- Telling it, and going there
---------------------------------------------------------------------------
-- The entries, nearest first (those on another continent last), each with its distance in yards.
local function Sorted()
	Tidy()
	local x, y, map = ns.Here()
	local out = {}
	for _, entry in ipairs(List()) do out[#out + 1] = { entry = entry, yards = Yards(entry, x, y, map) } end
	table.sort(out, function(a, b)
		if a.yards and b.yards then return a.yards < b.yards end
		if a.yards or b.yards then return a.yards ~= nil end
		return (a.entry.at or 0) > (b.entry.at or 0)
	end)
	return out
end

local function Said(item)
	local entry = item.entry
	local far = item.yards and ('%d yd'):format(math.floor(item.yards + 0.5)) or 'on another map'
	return ('%s (%s), %s'):format(entry.name, KINDS[entry.kind] or entry.kind, far)
end

-- Puts an entry on My Route. True when it was added.
local function Route(entry)
	local route = ns.Base and ns.Base.MyRoute
	if not (route and type(route.Add) == 'function') then
		ns.Print('My Route needs Patchwerk Forever 2.6.0 or later.')
		return false
	end
	local label = ('%s: %s'):format(KINDS[entry.kind] or 'Passed', entry.name)
	local ok, added = pcall(route.Add, route, { kind = 'spot', map = entry.map, x = entry.x, y = entry.y, label = label })
	if ok and added then
		ns.Print(('"%s" added to My Route.'):format(label))
		return true
	end
	ns.Print(('"%s" is already on My Route.'):format(label))
	return false
end

local function Forget(entry)
	local list = List()
	for i = #list, 1, -1 do
		if list[i] == entry then table.remove(list, i) end
	end
	ns.Print(('"%s" forgotten.'):format(entry.name))
end

-- The Sparkle: Passed page's list (the base's list, 2.9.0).
function ns.PassedRows()
	local rows = {}
	for i, item in ipairs(Sorted()) do
		local entry = item.entry
		rows[i] = { text = Said(item), buttons = {
			{ text = 'Add To Route', click = function() Route(entry) end },
			{ text = 'Forget', click = function() Forget(entry) end },
		} }
	end
	return rows
end

-- /sparkle passed
function ns.PassedSay()
	local items = Sorted()
	if #items == 0 then
		ns.Print(ns.Get('passed') and 'Nothing passed yet: chests, herbs and ore that sparkle and that you walk away from are listed here.'
			or 'Nothing passed. Remember What I Pass is disabled (Sparkle: Passed).')
		return
	end
	ns.Print(('Passed, nearest first (%d):'):format(#items))
	for i = 1, math.min(LISTED, #items) do ns.Print('  ' .. Said(items[i])) end
	if #items > LISTED then ns.Print(('  and %d more, on the Sparkle: Passed page.'):format(#items - LISTED)) end
	ns.Print('/sparkle passed route adds the nearest chest to My Route.')
end

-- /sparkle passed route: the nearest chest on this map, else the nearest of anything, onto My Route.
function ns.PassedRoute()
	local items, pick = Sorted(), nil
	for _, item in ipairs(items) do
		if item.yards and item.entry.kind == 'loot' then pick = item break end
	end
	pick = pick or (items[1] and items[1].yards and items[1]) or nil
	if not pick then
		ns.Print('Nothing passed on this map to go back to.')
		return
	end
	Route(pick.entry)
end

-- Forget Everything Passed, and /sparkle passed clear.
function ns.PassedClear()
	local count = #List()
	PatchwerkForever_Thread_SparkleDB.passed = {}
	ns.Print(count == 0 and 'Nothing passed to forget.'
		or (count == 1 and '1 passed object forgotten.' or ('%d passed objects forgotten.'):format(count)))
end
