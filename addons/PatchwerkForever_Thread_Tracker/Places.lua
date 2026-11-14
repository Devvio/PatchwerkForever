-- Thread (Tracker): where a quest is, and how far.
--
-- The game is asked the way its own world map asks: the map a quest is on (GetQuestUiMapID) and the
-- quest's mark on that map (C_QuestLog.GetQuestsOnMap), which the game turns into a place in the
-- world. The mark moves by itself to the next objective, and to whoever takes the quest in once it
-- is done. A place is kept for a few seconds, so the game is not asked for every quest at every
-- drawing. A quest the game gives no mark has no distance.
local ADDON, ns = ...
if not ns.linked then return end

local KEPT = 5                -- seconds a quest's place is kept

local places = {}             -- [quest] = { at = when asked, map =, x =, y = }
local rank = {}               -- [quest] = the distance it is sorted by (ns.QuestRank)

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

-- Where you are: world x, world y, continent; nothing where the game gives none.
function ns.Here()
	local x, y, _, map = UnitPosition('player')
	if not x then return nil end
	return x, y, map
end

-- Where a quest is: continent, world x, world y; nothing when the game gives it no mark.
function ns.QuestPlace(id)
	local now = GetTime()
	local had = places[id]
	if had and now - had.at < KEPT then return had.map, had.x, had.y end
	local place = { at = now }
	places[id] = place
	local uiMap = Ask(GetQuestUiMapID, id)
	if type(uiMap) == 'number' and uiMap > 0 then
		for _, mark in ipairs(Ask(C_QuestLog.GetQuestsOnMap, uiMap) or {}) do
			if type(mark) == 'table' and mark.questID == id then
				place.map, place.x, place.y = ns.Base.Guides.WorldOf(uiMap, mark.x, mark.y)
				break
			end
		end
	end
	return place.map, place.x, place.y
end

-- How far a quest is from you in yards; nothing when it has no place or is on another continent.
function ns.QuestYards(id)
	local map, x, y = ns.QuestPlace(id)
	local px, py, here = ns.Here()
	if not (map and px and map == here) then return nil end
	return math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
end

-- The distance a quest is sorted by: the one measured, held until the measured one has moved
-- clearly away from it (15 yards, or 15 percent when that is more). Two quests about as near as
-- each other would otherwise swap rows, and item buttons, each time you crossed the line between
-- them. Kept here, not by the list, so the item strip sorts the same way while quests are not
-- listed. What is shown beside a quest is still the distance measured (ns.QuestYards).
function ns.QuestRank(id)
	local yards = ns.QuestYards(id)
	if not yards then
		rank[id] = nil
		return nil
	end
	local kept = rank[id]
	if not kept or math.abs(yards - kept) > math.max(15, kept * 0.15) then
		kept = yards
		rank[id] = kept
	end
	return kept
end

-- A distance in a few letters.
function ns.YardsText(yards)
	if not yards then return nil end
	if yards >= 10000 then return ('%dk yd'):format(math.floor(yards / 1000 + 0.5)) end
	return ('%d yd'):format(math.floor(yards + 0.5))
end

-- (when quests change, their places are asked for again)
local function Forget() places = {} end
for _, event in ipairs({ 'QUEST_LOG_UPDATE', 'QUEST_ACCEPTED', 'QUEST_REMOVED', 'QUEST_TURNED_IN', 'QUEST_POI_UPDATE', 'ZONE_CHANGED_NEW_AREA' }) do
	ns.Try('listening for ' .. event, ns.On, event, Forget)
end
-- (the distance a quest is sorted by is dropped only when the quest leaves the log: the events
-- above come too often to drop it there)
ns.Try('listening for QUEST_REMOVED', ns.On, 'QUEST_REMOVED', function(id)
	if id ~= nil then rank[id] = nil end
end)
