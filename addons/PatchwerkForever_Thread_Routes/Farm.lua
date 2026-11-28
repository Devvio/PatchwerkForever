-- Routes (Thread): skinning, and farming an item. The way to the best place for either.
--
-- Both use QuestieDB (the base's QuestieDB.lua) for where creatures stand and how high their levels
-- are, and the gathering run's search for the densest area (Gather.lua: ns.DensestArea).
--
--   /thread skin          to the area on your continent with the most creatures you can skin. Which
--                         creatures can be skinned is in no file Routes can read: it is learned as you
--                         play. Each creature you skin is remembered (for all your characters), and its
--                         spawn points then count. One you can skin is one whose level asks for no more
--                         Skinning than you have (the game's rule: up to level 10 any, to level 20 ten
--                         points a level over 10, above that five points a level).
--   /thread skin list     the creatures remembered
--   /thread farm <item>   to the area where the item is most likely to drop: QuestieDB's Wowhead drop
--                         rates (quest items and the things quests ask for, not every item), times how
--                         many of the creatures that drop it stand there
--
-- Creatures more than ABOVE levels over you are left out of both. The place gone to is the spawn point
-- nearest the area's middle, routed to as a spot you gave (/thread to): it comes first, and the route
-- ends when you are there.
local ADDON, ns = ...
if not ns.linked then return end

local SKINNING = 393                          -- the profession's skill line
local SKIN_SPELLS = { [8613] = true, [8617] = true, [8618] = true, [10768] = true }
local WINDOW = 5                              -- seconds from starting to skin to the loot showing, at most
local ABOVE = 3                               -- levels over yours a creature may be and still count
local REACH = 20000                           -- yards round you looked in (a whole continent)
local UNKNOWN_RATE = 5                        -- percent counted for a dropper QuestieDB has no rate for

local db
local skinning                                -- { at = when, npc = the creature aimed at } while a skinning cast is on

local function QuestDB()
	local q = ns.Base.QuestDB
	if q and q:Ready() then return q end
	return nil
end

-- A creature's number from its GUID ("Creature-0-1-2-3-<npc>-<spawn>"), or nil.
local function NpcOf(guid)
	if type(guid) ~= 'string' then return nil end
	local kind, npc = guid:match('^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)')
	if kind == 'Creature' then return tonumber(npc) end
	return nil
end

---------------------------------------------------------------------------
-- Learning what can be skinned
---------------------------------------------------------------------------
local function Remember(npc, name)
	if not (db and npc) or not ns.Get('skinRecord') then return end
	local known = db.skinned[npc]
	if not known then
		known = { n = 0 }
		db.skinned[npc] = known
	end
	known.n = known.n + 1
	if type(name) == 'string' and name ~= '' then known.name = name end
end

ns.On('UNIT_SPELLCAST_SENT', function(unit, _, _, spell)
	if unit ~= 'player' or not SKIN_SPELLS[spell] then return end
	skinning = { at = GetTime(), npc = NpcOf(UnitGUID and UnitGUID('target')),
		name = UnitName and UnitName('target') or nil }
end)

ns.On('LOOT_OPENED', function()
	local was = skinning
	skinning = nil
	if not was or GetTime() - was.at > WINDOW then return end
	-- the creature the loot came from, as the loot says; else the one you aimed at
	local npc
	local count = rawget(_G, 'GetNumLootItems')
	local source = rawget(_G, 'GetLootSourceInfo')
	if type(count) == 'function' and type(source) == 'function' then
		local ok, n = pcall(count)
		for slot = 1, (ok and type(n) == 'number') and n or 0 do
			local got, guid = pcall(source, slot)
			npc = got and NpcOf(guid) or npc
			if npc then break end
		end
	end
	npc = npc or was.npc
	local name = was.name
	if npc and not name then
		local q = QuestDB()
		name = q and q.Get('Npc', npc, 'name')
	end
	Remember(npc, name)
end)

ns.On('ADDON_LOADED', function(name)
	if name ~= ADDON then return end
	db = PatchwerkForever_Thread_RoutesDB
	db.skinned = db.skinned or {}
end)

---------------------------------------------------------------------------
-- The best place
---------------------------------------------------------------------------
-- Your Skinning skill, or nil where it is not known.
local function SkinSkill()
	local list, info = rawget(_G, 'GetProfessions'), rawget(_G, 'GetProfessionInfo')
	if type(list) == 'function' and type(info) == 'function' then
		local ok, a, b, c, d, e = pcall(list)
		for _, index in pairs(ok and { a, b, c, d, e } or {}) do
			local _, _, _, rank, _, _, _, line = pcall(info, index)
			if line == SKINNING and type(rank) == 'number' then return rank end
		end
	end
	local num, line = rawget(_G, 'GetNumSkillLines'), rawget(_G, 'GetSkillLineInfo')
	if type(num) == 'function' and type(line) == 'function' then
		local ok, n = pcall(num)
		for i = 1, (ok and type(n) == 'number') and n or 0 do
			local got, name, header, _, rank = pcall(line, i)
			if got and not header and name == 'Skinning' and type(rank) == 'number' then return rank end
		end
	end
	return nil
end

-- The Skinning a creature of that level asks for.
function ns.SkinNeeds(level)
	if type(level) ~= 'number' or level <= 10 then return 1 end
	if level <= 20 then return (level - 10) * 10 end
	return level * 5
end

-- Whether a creature is one to count: not too far above you. Its levels, for the words.
local function Fair(q, npc)
	local low, high = q.NpcLevels(npc)
	local mine = UnitLevel and UnitLevel('player') or 1
	if type(low) == 'number' and low > mine + ABOVE then return false end
	return true, low, high
end

-- Goes to the densest area of the weighted spawn points given: pts = { { x, y, weight, npc } } on the
-- continent you are on. what: the words for it. Returns true when there was one.
local function GoTo(pts, map, px, py, what)
	local area = ns.DensestArea(pts, px, py)
	if not area then return false end
	local radius = ns.BEST_RADIUS or 400
	-- which creatures stand there, and the spawn point nearest the middle (a place the creatures walk)
	local in_, near, nearD = {}, nil, nil
	for _, p in ipairs(pts) do
		local d = (p[1] - area.x) ^ 2 + (p[2] - area.y) ^ 2
		if d <= radius * radius then in_[p[4]] = (in_[p[4]] or 0) + 1 end
		if not nearD or d < nearD then near, nearD = p, d end
	end
	local q = QuestDB()
	local names, total = {}, 0
	for npc, n in pairs(in_) do
		total = total + n
		names[#names + 1] = { name = tostring(q and q.Get('Npc', npc, 'name') or ('creature ' .. npc)), n = n }
	end
	table.sort(names, function(a, b) return a.n > b.n end)
	local list = {}
	for i = 1, math.min(3, #names) do list[i] = names[i].name end
	if #names > 3 then list[#list + 1] = ('%d more'):format(#names - 3) end
	local words = what(total, table.concat(list, ', '), radius, area.far)
	ns.Print(words)
	-- (the area is drawn on the maps while it is gone to: Area.lua)
	ns.SetDestination(map, near[1], near[2], false, true, nil,
		{ lines = { words }, area = { map = map, x = area.x, y = area.y, radius = radius } })
	return true
end

-- How many kinds of skinnable creature are known.
function ns.SkinKnown()
	local n = 0
	for _ in pairs(db and db.skinned or {}) do n = n + 1 end
	return n
end

-- The item's name when it (a name, link or id) has drops to farm by; else nil.
local canCache = {}
function ns.FarmCan(text)
	if type(text) ~= 'string' or text == '' then return nil end
	local known = canCache[text]
	if known ~= nil then return known or nil end
	local q = QuestDB()
	if not q then return nil end
	local item, name = q.FindItem(text)
	local ok = item and #q.ItemDrops(item) > 0 and name or false
	canCache[text] = ok
	return ok or nil
end

-- /thread skin
local function Skin()
	local q = QuestDB()
	if not q then
		ns.Print('QuestieDB is not installed or Use QuestieDB is off: creatures cannot be found.')
		return
	end
	if not next(db.skinned) then
		ns.Print('No skinnable creatures known yet. Each creature you skin is remembered; then /thread skin finds where most of them are.')
		return
	end
	local px, py, map = ns.Place()
	if not px then ns.Print('Your position is not available here.'); return end
	local skill = SkinSkill()
	local pts = {}
	for npc in pairs(db.skinned) do
		local ok, low, high = Fair(q, npc)
		local can = true
		if skill and ns.SkinNeeds(low) > skill then can = false end
		if ok and can then
			-- (some of its levels above your skill: half)
			local w = (skill and ns.SkinNeeds(high) > skill) and 0.5 or 1
			for _, s in ipairs(q.NpcSpots(npc)) do
				if s[1] == map and (s[2] - px) ^ 2 + (s[3] - py) ^ 2 <= REACH * REACH then
					pts[#pts + 1] = { s[2], s[3], w, npc }
				end
			end
		end
	end
	if not GoTo(pts, map, px, py, function(n, names, radius, far)
		return ('Best skinning area: %d spawn points (%s) within %d yards, %d yards away.'):format(n, names, radius, math.floor(far + 0.5))
	end) then
		ns.Print('None of the skinnable creatures you know, at your skill and level, stand on this continent.')
	end
end

local function SkinList()
	local list = {}
	for npc, known in pairs(db.skinned) do list[#list + 1] = { npc = npc, name = known.name or ('creature ' .. npc), n = known.n } end
	table.sort(list, function(a, b) return a.name < b.name end)
	ns.Print(('%d skinnable creatures known.'):format(#list))
	for i = 1, math.min(#list, 20) do
		ns.Print(('  %s: skinned %d times'):format(list[i].name, list[i].n))
	end
	if #list > 20 then ns.Print(('  and %d more'):format(#list - 20)) end
end

function ns.SkinSay(rest)
	rest = (rest or ''):gsub('^%s+', ''):gsub('%s+$', '')
	if not db then return end
	if rest == 'list' then SkinList() elseif rest == '' then Skin()
	else ns.Print('Usage: /thread skin, or /thread skin list.') end
end

-- /thread farm <item>
function ns.FarmSay(rest)
	rest = (rest or ''):gsub('^%s+', ''):gsub('%s+$', '')
	local q = QuestDB()
	if not q then
		ns.Print('QuestieDB is not installed or Use QuestieDB is off: drops cannot be looked up.')
		return
	end
	if rest == '' then ns.Print('Usage: /thread farm <item name, link or id>'); return end
	local item, name = q.FindItem(rest)
	if not item then
		ns.Print(('"%s" is not an item QuestieDB knows drops for. It has quest items and the things quests ask for.'):format(rest))
		return
	end
	local drops = q.ItemDrops(item)
	if #drops == 0 then ns.Print(('No creature is known to drop %s.'):format(name)); return end
	local px, py, map = ns.Place()
	if not px then ns.Print('Your position is not available here.'); return end
	local pts = {}
	for _, drop in ipairs(drops) do
		if Fair(q, drop.npc) then
			local w = (drop.rate or UNKNOWN_RATE) / 100
			for _, s in ipairs(q.NpcSpots(drop.npc)) do
				if s[1] == map and (s[2] - px) ^ 2 + (s[3] - py) ^ 2 <= REACH * REACH then
					pts[#pts + 1] = { s[2], s[3], w, drop.npc }
				end
			end
		end
	end
	if not GoTo(pts, map, px, py, function(n, names, radius, far)
		return ('Best place for %s: %d spawn points (%s) within %d yards, %d yards away.'):format(name, n, names, radius, math.floor(far + 0.5))
	end) then
		ns.Print(('No creature that drops %s, at your level, stands on this continent.'):format(name))
	end
end
