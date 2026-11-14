-- Thread (Routes): where to go when you have not said.
--
-- A map pin, or a spot given with /thread to, always comes first. With neither, the route goes
-- where one of these says, and moves on as it does:
--
--   your RestedXP guide   the step you are on, read from RestedXP as it runs (by the base): where it
--                         sends you, what it asks for, and the steps after it. A step that has you
--                         fly is gone to on foot, to the flight master the guide names; one with no
--                         place (a hearthstone, training) is said on screen. The way on through the
--                         next steps is drawn fainter and found ahead of time (Ahead.lua). Nothing
--                         of RestedXP's is changed.
--   a quest you track     the quest the game's own arrow is on (the "super-tracked" one), or failing
--                         that the nearest of the quests in your tracker. Where a quest is, is asked
--                         of the game the way its own world map asks: the map the quest is on
--                         (GetQuestUiMapID) and the quest's mark on that map (C_QuestLog.GetQuestsOnMap).
--                         That mark moves by itself to the next objective, and to whoever takes the
--                         quest in once it is done.
--
-- Which of the two goes first is a setting. The first that has a place you can go to (on your
-- continent, or on another with boats and zeppelins switched on) is the one followed. They are looked at twice a second.
--
-- That is the main track. A quest you choose (a click on it in the tracker, kept by the base: its
-- Choice.lua) is a side path and comes before it: the route goes to that quest, drawn in a colour of
-- its own, and the way on from there back to the guide is drawn fainter. Choosing it again, or
-- handing the quest in, gives the main track back. A second guide's list can be chosen the same
-- way (the Dungeon Journal's quests): it is then followed step after step, as the main guide is.
local ADDON, ns = ...
if not ns.linked then return end

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
local Guides = ns.Base.Guides
local World = Guides.WorldOf

---------------------------------------------------------------------------
-- The RestedXP guide
---------------------------------------------------------------------------
-- What the guide says now, from the base's guides service (which reads RestedXP, and in time other
-- guide addons): the step you are on, what it asks for, its lines, where it sends you, and the steps
-- after it. Read again at every look; nil with no guide running. guide.words: the lines still to be
-- done, as plain strings.
local guide

-- The place the guide sends you: map, world x, world y; nothing when there is none.
-- A step that has you fly to a flight point you do not have cannot be done as the guide means it.
-- The route then goes, by whatever way there is, to where the guide sends you after the flight, and
-- says so. (Only with a place to go after it; else the step is left as the guide has it.)
local function OnFootInstead(info)
	if not (info and info.kind == 'fly' and ns.Get('rxpTravel') and ns.FlightMissing) then return end
	local missing, name = ns.FlightMissing(info.flyTo)
	local after = info.ahead and info.ahead[1]
	if not (missing and after and after.map) then return end
	table.remove(info.ahead, 1)
	info.map, info.x, info.y = after.map, after.x, after.y
	info.kind, info.onFoot = 'place', true
	info.key = tostring(info.key) .. ':onfoot'
	-- (what is said: that the flight cannot be taken, then what the step gone to asks for)
	local words = { ('No flight path to %s: going by another way'):format(tostring(name or info.flyTo)) }
	for _, text in ipairs(Guides.Words({ lines = after.lines }, 2)) do words[#words + 1] = text end
	info.words = words
end

local function GuideTarget()
	guide = Guides:Read(ns.Get('rxpAhead') or 0)
	if guide then
		guide.words = Guides.Words(guide)
		OnFootInstead(guide)
	end
	if not (guide and guide.map) then return nil end
	return guide.map, guide.x, guide.y
end

-- What goes with a guide's step when it becomes the destination: its words, its kind, and, for a step
-- that has you fly, that the way to the flight master is to be gone on foot (the guide names the
-- flight; the planner is not to think of another).
local function GuideMore()
	if not guide then return nil end
	return { lines = guide.words, kind = guide.kind, step = guide.index,
		walkOnly = (guide.kind == 'fly' and ns.Get('rxpTravel')) or nil }
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

-- The quest you chose yourself (the base's Choice), or nil.
local function Picked()
	local Choice = ns.Base.Choice
	local pick = Choice and Choice:Get()
	if pick and pick.kind == 'quest' and type(pick.id) == 'number' then return pick.id end
	return nil
end
local lastPick, pick = nil, { at = 0 }

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

-- The place to go when you have not said: what gives it ('rxp' or 'quest'), map, world x, world y,
-- and true when it is a quest you chose yourself.
local function Target()
	local _, _, here = ns.Place()
	local order = ns.Get('sourceFirst') == 'quest' and QUEST_FIRST or GUIDE_FIRST
	guide = nil
	-- what you chose comes before the main track, whatever the settings for followed quests say
	local choice = ns.Base.Choice and ns.Base.Choice:Get()
	local chosen = choice and (tostring(choice.kind) .. ':' .. tostring(choice.id)) or nil
	if chosen ~= lastPick then
		lastPick = chosen
		pick = { at = 0 }
		quest.id, quest.dirty = nil, true                 -- (the main track is worked out afresh, not left on the quest you had chosen)
	end
	-- a second guide's list you chose (the Dungeon Journal's quests beside your levelling guide):
	-- followed the way a guide is, step after step, until it has no more or you go back
	if choice and choice.kind == 'guide' then
		guide = Guides:Read(ns.Get('rxpAhead') or 0, choice.id)
		if guide then
			guide.words = Guides.Words(guide)
			OnFootInstead(guide)
			if guide.map and (here == nil or guide.map == here or ns.CanCross(guide.map)) then
				return 'rxp', guide.map, guide.x, guide.y, 'guide'
			end
			if not guide.map and guide.kind ~= 'place' then return 'rxp', nil, nil, nil, 'guide' end
		end
		guide = nil                                       -- (nowhere it can send you from here: the main track keeps the say)
	end
	local id = Picked()
	if id then
		local now = GetTime()
		if quest.dirty or now - pick.at > STALE then
			pick.at = now
			pick.map, pick.x, pick.y, pick.stop = QuestSpot(id, here)
		end
		if pick.map then
			quest.id, quest.map, quest.x, quest.y, quest.stop = id, pick.map, pick.x, pick.y, pick.stop
			quest.dirty, quest.at = false, now
			return 'quest', pick.map, pick.x, pick.y, true
		end
		-- (the game gives it no place you can go to: the main track keeps the say)
	end
	for _, name in ipairs(order) do
		if ns.Get(SETTING[name]) then
			local map, x, y = FIND[name]()
			if map and (here == nil or map == here or ns.CanCross(map)) then return name, map, x, y end
			-- A guide's step that sends you nowhere (use your hearthstone, train, buy food): the guide
			-- still has the say, so no quest is followed behind its back. It is said on screen instead.
			if name == 'rxp' and guide and not guide.map and ns.Get('rxpTravel') and guide.kind ~= 'place' then
				return name
			end
		end
	end
	return nil
end

-- The fainter trail on through the guide's next steps (Ahead.lua), and with it the way to the next
-- step found ahead of time. Nothing of it while something else than the guide is followed.
local function LookAhead(from)
	if not (guide and from and #guide.ahead > 0 and (ns.Get('rxpAhead') or 0) > 0) then
		return ns.Ahead.Set({})
	end
	local chain = { { map = from.map, x = from.x, y = from.y, kind = ns.Get('rxpTravel') and guide.kind or 'place' } }
	for _, step in ipairs(guide.ahead) do
		chain[#chain + 1] = { map = step.map, x = step.x, y = step.y, kind = ns.Get('rxpTravel') and step.kind or 'place' }
	end
	ns.Ahead.Set(chain)
end

-- On a side path: the main track drawn fainter on from where the side path ends, so you see the way
-- back to your guide. (With that way found ahead of time, the trail changes at once when you go back.)
local function LookBack(from)
	local main = ns.Get('rxp') and (ns.Get('rxpAhead') or 0) > 0 and Guides:Read(ns.Get('rxpAhead')) or nil
	if not (main and main.map and from) then return ns.Ahead.Set({}) end
	local travel = ns.Get('rxpTravel')
	local chain = { { map = from.map, x = from.x, y = from.y, kind = 'place' },
		{ map = main.map, x = main.x, y = main.y, kind = travel and main.kind or 'place' } }
	for _, step in ipairs(main.ahead) do
		chain[#chain + 1] = { map = step.map, x = step.x, y = step.y, kind = travel and step.kind or 'place' }
	end
	ns.Ahead.Set(chain)
end

-- A step is said on screen once. `said` is what was last said of where the route goes by itself:
--   a guide's step   { source = which reader, guide = which guide of its, index = which step,
--                      onFoot = gone to by another way (OnFootInstead), had = { [line] = true } its lines then }
--   a quest          { quest = its id, map =, x =, y = where its mark was }
-- and with either, with = the destination it is said with, which is once that one's route is known.
-- A guide's step is not said again when only its place moves (RestedXP's arrow going round the spots
-- of one step), and neither is said again when you are led back to a place you had reached. Your own
-- pin or a gathering run in between forgets it, so what leads again after them is said.
local said

-- A line of a step without its numbers: a count that has gone up ("3/10") makes no new line.
local function Plain(text)
	return (tostring(text):gsub('%d+', '#'))
end

-- Whether the guide's step is the one last said: the same reader, guide and number, and nothing in
-- its words that it did not have then. Lines done drop out of the words and counts go up without that
-- making it new; the stops of a list that share one number (the Dungeon Journal's) are told apart by
-- their words. dest: the destination that is being kept, where one is.
local function Told(dest)
	if not said or said.source ~= guide.source or said.guide ~= guide.guide or said.index ~= guide.index
		or said.onFoot ~= guide.onFoot then return false end
	-- (said with a destination whose route is not known yet: not on screen yet, and never if that one is replaced first)
	if said.with and said.with.fresh and said.with ~= dest then return false end
	for _, text in ipairs(guide.words) do
		if not said.had[Plain(text)] then return false end
	end
	return true
end

-- Notes the guide's step as said. with: the destination it is said with, once that one's route is known.
local function Note(with)
	local had = {}
	for _, line in ipairs(guide.lines or {}) do had[Plain(line.text)] = true end
	for _, text in ipairs(guide.words) do had[Plain(text)] = true end
	said = { source = guide.source, guide = guide.guide, index = guide.index, onFoot = guide.onFoot, had = had, with = with }
end

-- The same for the quest followed. It is the one last said while it is the same quest with its mark
-- where it was: a mark that has moved is its next objective, and is said.
local function ToldQuest(map, x, y)
	return said ~= nil and said.quest == quest.id and said.map == map and Apart(said.x, said.y, x, y) <= SAME
		and not (said.with and said.with.fresh)
end

local function NoteQuest(with)
	said = { quest = quest.id, map = with.map, x = with.x, y = with.y, with = with }
end

local function Look()
	if ns.GatherActive and ns.GatherActive() then            -- a gathering run is on: it has the say (Gather.lua)
		said = nil
		ns.Ahead.Set({})
		return
	end
	local dest = ns.dest
	if dest and not dest.source then                         -- your own pin or spot comes first
		said = nil
		ns.Ahead.Set({})
		return
	end
	local stopped = ns.stopped
	if stopped then
		ns.stopped = nil
		local was = stopped.dest
		if was.source then
			skip = { source = was.source, map = was.map, x = was.x, y = was.y, reached = not stopped.user }
		end
	end
	local source, map, x, y, picked = Target()
	if not source then
		if dest then
			ns.Stop(false)
			ns.stopped = nil
		end
		ns.Ahead.Set({})
		return
	end
	if not map then
		-- the guide's step has no place: nothing to go to, its words on screen once
		if dest then
			ns.Stop(false)
			ns.stopped = nil
		end
		if not Told() then
			Note()
			ns.FloatStep(guide.words)
		end
		-- (nothing is drawn on ahead: there is no telling from here where the next walk begins)
		ns.Ahead.Set({})
		return
	end
	if source ~= 'rxp' then guide = nil end
	if skip then
		if skip.source == source and skip.map == map and Apart(skip.x, skip.y, x, y) <= SAME then
			if not skip.reached then
				-- (you stopped it: the way on from it is not drawn either)
				ns.Ahead.Set({})
				return
			end
			local px, py, pmap = ns.Place()
			if not px or pmap ~= map or Apart(px, py, x, y) < BACK[source] then
				-- you are still there. A guide that has moved on to another step at this very spot has
				-- nowhere new to send you: its words alone.
				if guide and not Told() then
					Note()
					ns.FloatStep(guide.words)
				end
				return
			end
			-- (you have come away from it with it still standing: led back, below, and not said again)
		end
		skip = nil
	end
	if dest and dest.source == source and dest.map == map and Apart(dest.x, dest.y, x, y) <= SAME then
		-- the same place still. A guide that has moved on to another step there (take the quest, then
		-- hand one in to the same person) gets its new words said, with the route as it stands; or,
		-- where the last whole search found no way there (dest.wait: Route.lua), with that under them.
		if guide and not Told(dest) then
			dest.step, dest.lines, dest.kind = guide.index, guide.words, guide.kind
			Note()
			local none = not ns.route and dest.wait and ns.NO_WAY or nil
			ns.FloatStep(guide.words, ns.route and ns.Summary(ns.route) or none, none and true or nil)
		end
		-- (the quest being followed anyway, now chosen, or no longer: the same way, in the other colour)
		if (dest.chosen and true or false) ~= (picked and true or false) then
			dest.chosen = picked and true or nil
			if ns.RouteChanged then ns.RouteChanged() end
		end
		-- (a quest you chose: the way back to the main track; a guide, main or chosen: on through its next steps)
		if picked == true then LookBack(dest) else LookAhead(dest) end
		return
	end
	local more = guide and GuideMore()
		or (source == 'quest' and quest.id and { lines = { 'Quest: ' .. Title(quest.id) } }) or nil
	if more and picked then more.chosen = true end
	-- Its words come on screen once its route is known, unless they have been there already: a step
	-- of the guide's whose place has only moved, or a place you had reached and are led back to. (They
	-- are kept for /thread step all the same.)
	local told
	if guide then told = Told() elseif more then told = ToldQuest(map, x, y) end
	if told and more then more.quiet = true end
	ns.SetDestination(map, x, y, false, false, source, more)
	if not told then
		if guide then Note(ns.dest) elseif more then NoteQuest(ns.dest) end
	end
	if picked == true then LookBack(ns.dest) else LookAhead(ns.dest) end
end

-- Routes to what the guide or a quest gives now (for /thread go with no pin). Returns true if there is one.
-- You asked: its words are said whether or not they have been before.
function ns.GoToSource()
	quest.dirty = true
	local source, map, x, y = Target()
	if not source then return false end
	skip = nil
	if not map then                                    -- the guide's step has no place: its words, again
		Note()
		ns.FloatStep(guide.words)
		ns.Print('The current guide step has no location: ' .. (guide.words[1] or 'no text') .. '.')
		return true
	end
	if source == 'quest' and ns.Get('notify') then
		ns.Print((quest.stop and 'Routing toward quest "%s":' or 'Routing to quest "%s":'):format(Title(quest.id)))
	end
	local more = (source == 'rxp' and GuideMore()) or (source == 'quest' and quest.id and { lines = { 'Quest: ' .. Title(quest.id) } }) or nil
	ns.SetDestination(map, x, y, false, true, source, more)
	if source == 'rxp' then Note(ns.dest) elseif more then NoteQuest(ns.dest) end
	return true
end

-- /thread quest: what the game says of the quests you track, and which one is followed.
function ns.QuestSay()
	if not ns.Get('quests') then ns.Print('Following tracked quests is disabled (Follow Tracked Quests, in the options).') end
	if not (C_QuestLog and C_QuestLog.GetQuestsOnMap and GetQuestUiMapID) then
		ns.Print('This client does not provide quest locations (C_QuestLog.GetQuestsOnMap, GetQuestUiMapID).')
		return
	end
	local _, _, here = ns.Place()
	local focused, watched = Focused(), Watched()
	ns.Print(('Quest arrow: %s. Tracked quests: %d. Continent: %s.'):format(
		focused and ('"' .. Title(focused) .. '"') or 'none', #watched, tostring(here)))
	local seen, said = {}, 0
	local function Tell(id)
		if seen[id] or said >= 10 then return end
		seen[id], said = true, said + 1
		local place, stop = QuestPlaces(id)
		local where
		if place then
			where = ('at %.0f, %.0f on continent %d%s'):format(place[2], place[3], place[1],
				(here ~= nil and place[1] ~= here) and ' (not your current continent)' or '')
		else
			where = 'no map location'
		end
		if stop then where = where .. ('; next waypoint: %.0f, %.0f on continent %d'):format(stop[2], stop[3], stop[1]) end
		ns.Print(('  "%s" (%d): %s.'):format(Title(id), id, where))
	end
	if focused then Tell(focused) end
	for _, id in ipairs(watched) do Tell(id) end
	quest.dirty = true
	local source = Target()
	if source == 'quest' then
		ns.Print(('Following: "%s"%s%s.'):format(Title(quest.id), quest.stop and ' (via the next waypoint)' or '',
			Picked() == quest.id and ' (selected by you; click it again to return to your main route)' or ''))
	elseif source == 'rxp' then
		ns.Print('Following: your RestedXP guide (it has priority; change this in the options).')
	elseif ns.dest and not ns.dest.source then
		ns.Print('Following: your map pin or coordinates (always first).')
	else
		ns.Print('Following: nothing.')
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
	if key == 'rxp' or key == 'quests' or key == 'questPick' or key == 'sourceFirst' or key == 'rxpTravel' or key == 'rxpAhead' then
		quest.dirty = true
		Look()
	end
end)
