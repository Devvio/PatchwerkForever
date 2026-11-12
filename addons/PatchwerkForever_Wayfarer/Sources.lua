-- Wayfarer: where to go when you have not said.
--
-- A map pin, or a spot given with /wayfarer to, always comes first. With neither, the route goes
-- where one of these says, and moves on as it does:
--
--   your RestedXP guide   RestedXP keeps the place its arrow points at on the arrow's frame
--                         (RXPG_ARROW.element). Nothing of RestedXP's is changed.
--   a quest you track     the quest the game's own arrow is on (the "super-tracked" one), or failing
--                         that the nearest of the quests in your tracker. Where a quest is, is asked
--                         of the game the way its own world map asks: the map the quest is on
--                         (GetQuestUiMapID) and the quest's mark on that map (C_QuestLog.GetQuestsOnMap).
--                         That mark moves by itself to the next objective, and to whoever takes the
--                         quest in once it is done.
--
-- Which of the two goes first is a setting. The first that has a place you can go to (on your
-- continent, or on another with boats and zeppelins switched on) is the one followed. They are looked at twice a second.
local ADDON, ns = ...

local EVERY = 0.5         -- seconds between looks
local SAME = 5            -- yards within which two places are the same place
local STALE = 5           -- seconds a quest's place is kept before the game is asked again
-- yards you must leave a place you had reached before it is routed to again (a quest's mark is the
-- middle of an area you wander about in; a guide's step is a spot)
local BACK = { rxp = 40, quest = 120 }
local SETTING = { rxp = 'rxp', quest = 'quests' }
local GUIDE_FIRST, QUEST_FIRST = { 'rxp', 'quest' }, { 'quest', 'rxp' }

-- A place not to route to for now: one you stopped yourself (until what gave it moves on), or one you
-- have reached (until it moves on, or you walk away from it with it still standing).
local skip

local function Apart(ax, ay, bx, by)
	return math.sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by))
end

-- A spot on one of the game's maps (0 to 1 across and down) as: continent, world x, world y.
local function World(uiMap, x, y)
	if type(uiMap) ~= 'number' or type(x) ~= 'number' or type(y) ~= 'number' then return nil end
	local ok, map, world = pcall(C_Map.GetWorldPosFromMapPos, uiMap, CreateVector2D(x, y))
	if not (ok and map and world) then return nil end
	local wx, wy = world:GetXY()
	return map, wx, wy
end

---------------------------------------------------------------------------
-- The RestedXP guide
---------------------------------------------------------------------------
-- The place the RestedXP arrow points at: map, world x, world y; nothing when there is none.
local function GuideTarget()
	local arrow = _G.RXPG_ARROW
	local e = arrow and arrow.element
	if type(e) ~= 'table' then return nil end
	-- its place on a zone's map, which the game turns into world coordinates itself
	if e.zone and e.x and e.y then
		local map, x, y = World(e.zone, e.x / 100, e.y / 100)
		if map then return map, x, y end
	end
	-- else RestedXP's own world coordinates: its x runs west and its y north, the game's the other way round
	if type(e.wx) == 'number' and type(e.wy) == 'number' and type(e.instance) == 'number' then
		return e.instance, e.wy, e.wx
	end
	return nil
end

---------------------------------------------------------------------------
-- The quests you track
---------------------------------------------------------------------------
-- Asks the game; an error or a function this client lacks gives nothing.
local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local function Title(id)
	local title = C_QuestLog and Ask(C_QuestLog.GetTitleForQuestID, id)
	return type(title) == 'string' and title or ('quest ' .. tostring(id))
end

-- A quest's mark on one map: continent, world x, world y.
local function MarkOn(uiMap, id)
	if type(uiMap) ~= 'number' or uiMap == 0 then return nil end
	local list = Ask(C_QuestLog.GetQuestsOnMap, uiMap)
	if type(list) ~= 'table' then return nil end
	for _, q in ipairs(list) do
		if type(q) == 'table' and q.questID == id then
			local map, x, y = World(uiMap, q.x, q.y)
			if map then return map, x, y end
		end
	end
	return nil
end

-- Where a quest is, as far as the game says: { map, x, y } where it is to be done, and { map, x, y }
-- for the game's own next stop on the way there (a boat, a portal) where it gives one. Either can be nil.
local function QuestPlaces(id)
	local place, stop
	local tried = {}
	local function try(uiMap)
		if place or type(uiMap) ~= 'number' or uiMap == 0 or tried[uiMap] then return end
		tried[uiMap] = true
		local map, x, y = MarkOn(uiMap, id)
		if map then place = { map, x, y } end
	end
	try(Ask(GetQuestUiMapID, id, true))                   -- the map it is to be done on
	try(Ask(GetQuestUiMapID, id))                         -- the map the game would open for it
	try(Ask(C_Map.GetBestMapForUnit, 'player'))           -- the map you are on
	local uiMap, x, y = Ask(C_QuestLog.GetNextWaypoint, id)
	if uiMap then
		local map, wx, wy = World(uiMap, x, y)
		if map then stop = { map, wx, wy } end
	end
	return place, stop
end

-- The spot to go to for a quest from where you are: the quest itself when it is on your continent or
-- one a boat or zeppelin may lead to, else the game's next stop when that is on yours. Then: map, x, y, and true if it is only a stop on the way.
local function QuestSpot(id, here)
	local place, stop = QuestPlaces(id)
	if place and (here == nil or place[1] == here or ns.CanCross(place[1])) then return place[1], place[2], place[3], false end
	if stop and (here == nil or stop[1] == here) then return stop[1], stop[2], stop[3], true end
	return nil
end

-- The quest the game's own arrow is on, or nil.
local function Focused()
	local id = C_SuperTrack and Ask(C_SuperTrack.GetSuperTrackedQuestID)
	if type(id) == 'number' and id ~= 0 then return id end
	return nil
end

-- The quests in your tracker.
local function Watched()
	local list = {}
	local count = C_QuestLog and Ask(C_QuestLog.GetNumQuestWatches)
	if type(count) ~= 'number' then return list end
	for i = 1, count do
		local id = Ask(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
		if type(id) == 'number' and id ~= 0 then list[#list + 1] = id end
	end
	return list
end

-- The quest chosen and its spot, kept for a few seconds: asking goes through every quest on a map.
local quest = { dirty = true, at = 0 }

local function ChooseQuest()
	local px, py, here = ns.Place()
	local id = Focused()
	if id then
		local map, x, y, stop = QuestSpot(id, here)
		if map then return id, map, x, y, stop end
	end
	if ns.Get('questPick') ~= 'nearest' then return nil end
	local watched = Watched()
	-- the one being followed is kept while it still stands, so two quests as near as each other do not take turns
	if quest.id then
		for _, other in ipairs(watched) do
			if other == quest.id then
				local map, x, y, stop = QuestSpot(other, here)
				if map then return other, map, x, y, stop end
			end
		end
	end
	local best, bid, bmap, bx, by, bstop
	for _, other in ipairs(watched) do
		if other ~= id then
			local map, x, y, stop = QuestSpot(other, here)
			if map then
				local far = px and Apart(px, py, x, y) or 0
				if not best or far < best then best, bid, bmap, bx, by, bstop = far, other, map, x, y, stop end
			end
		end
	end
	return bid, bmap, bx, by, bstop
end

local function QuestTarget()
	local now = GetTime()
	if quest.dirty or now - quest.at > STALE then
		quest.dirty, quest.at = false, now
		quest.id, quest.map, quest.x, quest.y, quest.stop = ChooseQuest()
	end
	if not quest.id then return nil end
	return quest.map, quest.x, quest.y
end

---------------------------------------------------------------------------
-- Choosing between them, and following
---------------------------------------------------------------------------
local FIND = { rxp = GuideTarget, quest = QuestTarget }

-- The place to go when you have not said: what gives it ('rxp' or 'quest'), map, world x, world y.
local function Target()
	local _, _, here = ns.Place()
	local order = ns.Get('sourceFirst') == 'quest' and QUEST_FIRST or GUIDE_FIRST
	for _, name in ipairs(order) do
		if ns.Get(SETTING[name]) then
			local map, x, y = FIND[name]()
			if map and (here == nil or map == here or ns.CanCross(map)) then return name, map, x, y end
		end
	end
	return nil
end

local function Look()
	local dest = ns.dest
	if dest and not dest.source then return end              -- your own pin or spot comes first
	local stopped = ns.stopped
	if stopped then
		ns.stopped = nil
		local was = stopped.dest
		if was.source then
			skip = { source = was.source, map = was.map, x = was.x, y = was.y, reached = not stopped.user }
		end
	end
	local source, map, x, y = Target()
	if not source then
		if dest then
			ns.Stop(false)
			ns.stopped = nil
		end
		return
	end
	if skip then
		if skip.source == source and skip.map == map and Apart(skip.x, skip.y, x, y) <= SAME then
			if not skip.reached then return end
			local px, py, pmap = ns.Place()
			if not px or pmap ~= map or Apart(px, py, x, y) < BACK[source] then return end
		end
		skip = nil
	end
	if dest and dest.source == source and dest.map == map and Apart(dest.x, dest.y, x, y) <= SAME then return end
	ns.SetDestination(map, x, y, false, false, source)
end

-- Routes to what the guide or a quest gives now (for /wayfarer go with no pin). Returns true if there is one.
function ns.GoToSource()
	quest.dirty = true
	local source, map, x, y = Target()
	if not source then return false end
	skip = nil
	if source == 'quest' and ns.Get('notify') then
		ns.Print((quest.stop and 'on the way to your quest "%s":' or 'to your quest "%s":'):format(Title(quest.id)))
	end
	ns.SetDestination(map, x, y, false, true, source)
	return true
end

-- /wayfarer quest: what the game says of the quests you track, and which one is followed.
function ns.QuestSay()
	if not ns.Get('quests') then ns.Print('following tracked quests is switched off (Follow My Tracked Quest, on the options page).') end
	if not (C_QuestLog and C_QuestLog.GetQuestsOnMap and GetQuestUiMapID) then
		ns.Print('this client lacks the functions the quest places are read with (C_QuestLog.GetQuestsOnMap, GetQuestUiMapID).')
		return
	end
	local _, _, here = ns.Place()
	local focused, watched = Focused(), Watched()
	ns.Print(('the game\'s arrow is on: %s. Quests in your tracker: %d. You are on continent %s.'):format(
		focused and ('"' .. Title(focused) .. '"') or 'no quest', #watched, tostring(here)))
	local seen, said = {}, 0
	local function Tell(id)
		if seen[id] or said >= 10 then return end
		seen[id], said = true, said + 1
		local place, stop = QuestPlaces(id)
		local where
		if place then
			where = ('at %.0f, %.0f on continent %d%s'):format(place[2], place[3], place[1],
				(here ~= nil and place[1] ~= here) and ' (not the one you are on)' or '')
		else
			where = 'the game gives no place on the map'
		end
		if stop then where = where .. ('; the game\'s next stop on the way: %.0f, %.0f on continent %d'):format(stop[2], stop[3], stop[1]) end
		ns.Print(('  "%s" (%d): %s.'):format(Title(id), id, where))
	end
	if focused then Tell(focused) end
	for _, id in ipairs(watched) do Tell(id) end
	quest.dirty = true
	local source = Target()
	if source == 'quest' then
		ns.Print(('followed now: "%s"%s.'):format(Title(quest.id), quest.stop and ' (to the game\'s next stop on the way)' or ''))
	elseif source == 'rxp' then
		ns.Print('followed now: your RestedXP guide, which comes first (the order is on the options page).')
	elseif ns.dest and not ns.dest.source then
		ns.Print('followed now: your own pin or spot, which always comes first.')
	else
		ns.Print('followed now: nothing.')
	end
end

local function Dirty()
	quest.dirty = true
end
for _, event in ipairs({ 'SUPER_TRACKING_CHANGED', 'QUEST_WATCH_LIST_CHANGED', 'QUEST_LOG_UPDATE', 'QUEST_POI_UPDATE',
	'QUEST_ACCEPTED', 'QUEST_TURNED_IN', 'QUEST_REMOVED', 'ZONE_CHANGED_NEW_AREA', 'PLAYER_ENTERING_WORLD' }) do
	ns.Try('listening for ' .. event, ns.On, event, Dirty)
end

ns.On('PLAYER_LOGIN', function()
	C_Timer.NewTicker(EVERY, function() ns.Try('following your guide and quests', Look) end)
end)
ns.OnSetting(function(key)
	if key == 'rxp' or key == 'quests' or key == 'questPick' or key == 'sourceFirst' then
		quest.dirty = true
		Look()
	end
end)
