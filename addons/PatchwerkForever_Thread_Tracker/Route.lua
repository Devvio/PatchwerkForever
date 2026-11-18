-- Thread (Tracker): My Route, stops you put in your own order.
--
-- The base keeps the list (its MyRoute.lua) and reads it as one more guide, 'route', so Thread
-- (Routes) can lead you along it. This lists it in a section of its own, under the guides and above
-- your quests: each stop numbered, its name, what is to be done there and how far it is. The section
-- is there while the list has stops, or while My Route is the focus (then with a line on how to add
-- one). The generic guide sections leave it out (Guide.lua), so it is not listed twice.
--
--   left-click a stop    go there first: My Route is followed from that stop on
--   right-click a stop   Go Here First, Move Up, Move Down, Move To Top, Quest Details, Remove
--   drag a stop          to another place in the list (Drag.lua)
--   right-click heading  Edit My Route (the window, Editor.lua), Order For Me, Add All Tracked
--                        Quests, Add Map Pin, Clear
--
-- Quests are added from a quest's right-click menu (Actions.lua), from the Dungeon Journal list's
-- stops (Guide.lua) and with a key binding for the quest under the game's arrow. The stop you last
-- clicked is the one the Move My Route Stop Up and Down bindings move: a gamepad cannot drag.
--
-- While My Route is the focus, or the list you selected, Route To Next Quest and Route To Previous
-- Quest walk its stops instead of your quests (ns.RouteWalk, from ns.Cycle in Actions.lua).
local ADDON, ns = ...
if not ns.linked then return end

local SOURCE = 'route'
local WORDS = { todo = 'In progress', done = 'Turn in', pickup = 'Accept', spot = 'Go to', nowhere = 'No place known' }

local selected                -- the key of the stop last clicked (for the move bindings)

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local function MyRoute() return ns.Base.MyRoute end

local function IndexOf(key)
	for i, one in ipairs(MyRoute():Entries()) do
		if one.key == key then return i, one end
	end
	return nil
end

function ns.RouteSelect(key)
	selected = key
	ns.Refresh()
end

function ns.RouteSelected()
	return selected
end

-- Is My Route the track being followed now: what Thread (Routes) says; without its word, the list
-- you selected, or the focus with nothing chosen before it (a quest you clicked, a gathering run).
function ns.RouteFollowed()
	local said = ns.FollowingNow()
	if said then return said.kind == 'guide' and said.source == SOURCE end
	local Choice = ns.Base.Choice
	if Choice:Is('guide', SOURCE) then return true end
	if Choice:Get() then return false end
	if ns.Base.Gather:Has() and ns.Base.Gather:State() then return false end
	return ns.Focused() == SOURCE
end

-- Whether the next and previous quest bindings walk My Route: it is the focus, or the list you selected.
local function Walking()
	return ns.Base.Choice:Is('guide', SOURCE) or ns.Base.Focus:Get() == SOURCE
end

-- Makes My Route the track followed: with it as the focus, a choice made before it is let go; else it
-- is selected, as a click on any side list selects it.
local function Follow()
	local Choice = ns.Base.Choice
	if ns.Base.Focus:Get() == SOURCE then
		if Choice:Get() and not Choice:Is('guide', SOURCE) then Choice:Clear() end
	elseif not Choice:Is('guide', SOURCE) then
		Choice:Set('guide', SOURCE)
	end
end

-- How far a place is, in yards; nothing on another continent or with no place.
local function Yards(map, x, y)
	local px, py, here = ns.Here()
	if not (map and px and map == here) then return nil end
	return math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
end
ns.RouteYards = Yards

---------------------------------------------------------------------------
-- Going to a stop
---------------------------------------------------------------------------
-- The base puts any stop first for this session without changing the saved order (MyRoute:Lead).
function ns.RouteGo(index)
	local target = MyRoute():Entries()[index]
	if not target then return false end
	if not target.map then
		ns.Print(('No place is known for %s yet.'):format(target.name))
		return false
	end
	Follow()
	MyRoute():Lead(index)
	local info = ns.Base.Guides:Read(0, SOURCE)
	return info ~= nil and info.route == index
end

-- For Route To Next Quest and Route To Previous Quest while My Route is walked: the next stop with
-- a place after the one you are on (step 1), or the one before it (step -1). Returns false when My
-- Route has nowhere to send you, and the quests are walked instead.
function ns.RouteWalk(step)
	if not Walking() then return false end
	local info = ns.Base.Guides:Read(0, SOURCE)
	if not (info and info.route) then return false end
	local entries = MyRoute():Entries()
	local to
	if step > 0 then
		for i = info.route + 1, #entries do
			if entries[i].map then to = i break end
		end
	else
		for i = info.route - 1, 1, -1 do
			if entries[i].map then to = i break end
		end
	end
	if not to then
		Follow()
		ns.Print(step > 0 and 'This is the last stop in My Route.' or 'This is the first stop in My Route.')
		ns.Wake()
		ns.Refresh()
		return true
	end
	if ns.RouteGo(to) then
		selected = entries[to].key
		ns.Print(('Routing to stop %d of %d in My Route: %s.'):format(to, #entries, entries[to].name))
	end
	ns.Reveal()
	return true
end

---------------------------------------------------------------------------
-- Adding, removing, moving
---------------------------------------------------------------------------
-- Adds a stop and says so. name: what to call it in chat.
function ns.RouteAdd(stop, name)
	if MyRoute():Add(stop) then
		ns.Print(('Added to My Route: %s.'):format(name or 'stop'))
		ns.Refresh()
		return true
	end
	ns.Print('Already in My Route.')
	return false
end

local function QuestName(id)
	return Ask(C_QuestLog.GetTitleForQuestID, id) or ('Quest ' .. tostring(id))
end

function ns.RouteAddQuest(id)
	return ns.RouteAdd({ kind = 'quest', id = id }, QuestName(id))
end

-- Takes a quest out of My Route, whatever kind of stop it is (a journal quest taken is the same quest).
function ns.RouteRemoveQuest(id)
	for i, one in ipairs(MyRoute():Entries()) do
		if one.kind ~= 'spot' and one.id == id then
			MyRoute():Remove(i)
			ns.Print(('Removed from My Route: %s.'):format(one.name))
			ns.Refresh()
			return true
		end
	end
	return false
end

function ns.RouteHasQuest(id)
	return MyRoute():Has('quest', id)
end

-- The quest under the game's arrow; else the quest you clicked; else the quest selected in the quest log.
local function QuestAtHand()
	local id = C_SuperTrack and Ask(C_SuperTrack.GetSuperTrackedQuestID)
	if type(id) == 'number' and id > 0 then return id end
	local pick = ns.Base.Choice:Get()
	if pick and pick.kind == 'quest' then return pick.id end
	id = Ask(C_QuestLog.GetSelectedQuest)
	if type(id) == 'number' and id > 0 then return id end
	return nil
end

-- For the key binding "Add Quest To My Route".
function ns.RouteAddAtHand()
	local id = QuestAtHand()
	if not id then
		ns.Print('No quest selected. Put the quest arrow on a quest, then try again.')
		return
	end
	ns.RouteAddQuest(id)
end

function ns.RouteAddTracked()
	local added, watched = 0, Ask(C_QuestLog.GetNumQuestWatches) or 0
	for i = 1, watched do
		local id = Ask(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
		if id and MyRoute():Add({ kind = 'quest', id = id }) then added = added + 1 end
	end
	if watched == 0 then
		ns.Print('No tracked quests.')
	elseif added == 0 then
		ns.Print('All tracked quests are already in My Route.')
	else
		ns.Print(('Added to My Route: %d %s.'):format(added, added == 1 and 'quest' or 'quests'))
	end
	ns.Refresh()
end

-- Your map pin as a stop, named after the map it is on.
function ns.RouteAddPin()
	local pin = C_Map and Ask(C_Map.GetUserWaypoint)
	local position = type(pin) == 'table' and pin.position
	local x, y
	if type(position) == 'table' then
		if type(position.GetXY) == 'function' then x, y = position:GetXY() else x, y = position.x, position.y end
	end
	local map, wx, wy = ns.Base.Guides.WorldOf(pin and pin.uiMapID, x, y)
	if not map then
		ns.Print('No map pin is set. Place one on the world map first.')
		return
	end
	local info = C_Map and Ask(C_Map.GetMapInfo, pin.uiMapID)
	local label = (type(info) == 'table' and type(info.name) == 'string') and ('Map Pin: ' .. info.name) or 'Map Pin'
	local zone = (type(info) == 'table' and type(info.name) == 'string') and info.name or nil
	ns.RouteAdd({ kind = 'spot', map = map, x = wx, y = wy, label = label, zone = zone }, label)
end

function ns.RouteOrder()
	if MyRoute():Order() then
		ns.Print('My Route is ordered: nearest first, each next stop nearest the one before.')
	else
		ns.Print('My Route needs two stops or more to order.')
	end
	ns.Refresh()
end

function ns.RouteMove(key, to)
	local from = IndexOf(key)
	if not from then return false end
	local moved = MyRoute():Move(from, to)
	ns.Refresh()
	return moved
end

function ns.RouteRemove(key)
	local i, one = IndexOf(key)
	if not i then return false end
	MyRoute():Remove(i)
	if selected == key then selected = nil end
	ns.Print(('Removed from My Route: %s.'):format(one.name))
	ns.Refresh()
	return true
end

local POPUP = 'PATCHWERKFOREVER_TRACKER_CLEAR_ROUTE'

-- Clears My Route, after the game's yes-or-no box.
function ns.RouteClear()
	if #MyRoute():Entries() == 0 then
		ns.Print('My Route is empty.')
		return
	end
	local dialogs, show = rawget(_G, 'StaticPopupDialogs'), rawget(_G, 'StaticPopup_Show')
	if not (type(dialogs) == 'table' and type(show) == 'function') then
		-- (a client with no such box: cleared at once, and said)
		MyRoute():Clear()
		ns.Print('My Route cleared.')
		return
	end
	dialogs[POPUP] = dialogs[POPUP] or {
		text = 'Remove all stops from My Route?',
		button1 = rawget(_G, 'YES') or 'Yes',
		button2 = rawget(_G, 'NO') or 'No',
		OnAccept = function()
			MyRoute():Clear()
			selected = nil
			ns.Print('My Route cleared.')
			ns.Refresh()
		end,
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
	show(POPUP)
end

-- For the key bindings "Move My Route Stop Up" and "Move My Route Stop Down": the stop you last clicked.
function ns.RouteNudge(dir)
	local i, one = nil, nil
	if selected then i, one = IndexOf(selected) end
	if not i then
		ns.Print('Select a stop first: click it in the My Route section or window.')
		return
	end
	local n = #MyRoute():Entries()
	local to = math.max(1, math.min(n, i + dir))
	if to == i then
		ns.Print(dir < 0 and 'That stop is already first in My Route.' or 'That stop is already last in My Route.')
		return
	end
	MyRoute():Move(i, to)
	ns.Print(('Moved to stop %d: %s.'):format(to, one.name))
	ns.Refresh()
end

---------------------------------------------------------------------------
-- The menus
---------------------------------------------------------------------------
-- A stop's right-click menu, in the section and in the window.
function ns.RouteRowMenu(owner, index)
	local entries = MyRoute():Entries()
	local one = entries[index]
	if not one then return end
	local key = one.key
	selected = key
	local list = { { 'Go Here First', function()
		local i = IndexOf(key)
		if i then ns.RouteGo(i) end
	end } }
	if index > 1 then list[#list + 1] = { 'Move Up', function() ns.RouteMove(key, (IndexOf(key) or 1) - 1) end } end
	if index < #entries then list[#list + 1] = { 'Move Down', function() ns.RouteMove(key, (IndexOf(key) or 0) + 1) end } end
	if index > 1 then list[#list + 1] = { 'Move To Top', function() ns.RouteMove(key, 1) end } end
	if one.kind == 'quest' then list[#list + 1] = { 'Quest Details', function() ns.OpenQuest(one.id) end } end
	list[#list + 1] = { 'Remove', function() ns.RouteRemove(key) end }
	ns.Menu(owner, one.name, list)
end

-- The heading's menu.
function ns.RouteMenu(owner)
	local n = #MyRoute():Entries()
	local list = { { 'Edit My Route', function() ns.OpenRoute() end } }
	if n > 1 then list[#list + 1] = { 'Order For Me', ns.RouteOrder } end
	list[#list + 1] = { 'Add All Tracked Quests', ns.RouteAddTracked }
	list[#list + 1] = { 'Add Map Pin', ns.RouteAddPin }
	if n > 0 then list[#list + 1] = { 'Clear', ns.RouteClear } end
	ns.Menu(owner, 'My Route', list)
end

---------------------------------------------------------------------------
-- The section
---------------------------------------------------------------------------
-- The rows of the section shown now, for a drag to land among.
local function Rows()
	local out = {}
	for _, block in ipairs(ns.ShownBlocks()) do
		if block.data.routeIndex then out[#out + 1] = { frame = block, index = block.data.routeIndex } end
	end
	return out
end

-- A stop's color by what is to be done there.
function ns.RouteColour(state)
	if state == 'done' then return ns.RGB(ns.Get('lookDone')) end
	if state == 'nowhere' then return 0.5, 0.5, 0.5 end
	if state == 'spot' then return ns.RGB(ns.Get('lookGuide')) end
	return ns.RGB(ns.Get('lookTitle'))
end

function ns.RouteWord(state)
	return WORDS[state] or ''
end

ns.AddSection('route', 30, function()
	if not ns.Get('myRoute') then return nil end
	local entries = MyRoute():Entries()
	local focused = ns.Base.Focus:Get() == SOURCE or ns.Base.Choice:Is('guide', SOURCE)
	if #entries == 0 and not focused then return nil end
	local menu = function(head) ns.RouteMenu(head) end
	if #entries == 0 then
		return { title = 'My Route', menu = menu, blocks = { { key = 'hint', small = true, r = 0.6, g = 0.6, b = 0.6,
			title = 'No stops yet. Right-click a quest and choose Add To My Route.' } } }
	end
	local now = ns.Base.Guides:Read(0, SOURCE)
	local current = now and now.route
	local followed = ns.RouteFollowed()
	local blocks = {}
	-- at the top, where the route goes next: the stop, its zone, and while My Route is followed, how
	-- the way goes there (where to fly from and to), as Thread (Routes) words it once the route is found
	local coming = current and entries[current]
	if coming then
		local lines = {}
		if coming.zone then lines[#lines + 1] = { text = 'In ' .. coming.zone } end
		local info = followed and ns.Base.Following and ns.Base.Following:Get()
		if info and info.source == SOURCE and info.travel then lines[#lines + 1] = { text = info.travel } end
		blocks[#blocks + 1] = {
			key = 'route:next', title = ('Next: %s'):format(coming.name), lines = lines,
			r = 1, g = 0.82, b = 0,
			tip = { 'Where My Route goes next.', 'Click to route there.' },
			click = function()
				local i = IndexOf(coming.key)
				if i then ns.RouteGo(i) end
			end,
		}
	end
	for _, one in ipairs(entries) do
		local index, key = one.index, one.key
		local r, g, b = ns.RouteColour(one.state)
		local title = ('%d. %s'):format(index, one.name)
		local word = WORDS[one.state]
		blocks[#blocks + 1] = {
			key = 'route:' .. key, title = title, r = r, g = g, b = b, routeIndex = index,
			lines = word and { { text = one.zone and ('%s (%s)'):format(word, one.zone) or word, done = one.state == 'done', r = one.state == 'nowhere' and 0.5 or nil,
				g = one.state == 'nowhere' and 0.5 or nil, b = one.state == 'nowhere' and 0.5 or nil } } or nil,
			note = ns.Get('distance') and ns.YardsText(Yards(one.map, one.x, one.y)) or nil,
			mark = followed and current == index,
			tip = { 'Click to go here first.', 'Drag to move it.', 'Right-click for more options.' },
			click = function(button, block)
				selected = key
				if button == 'RightButton' then
					ns.RouteRowMenu(block, IndexOf(key) or index)
				else
					local i = IndexOf(key)
					if i then ns.RouteGo(i) end
				end
			end,
			drag = function(block)
				selected = key
				ns.DragBegin(block, { from = index, key = key, text = title, rows = Rows })
			end,
		}
	end
	return { title = 'My Route', note = ('%d %s'):format(#entries, #entries == 1 and 'stop' or 'stops'),
		menu = menu, blocks = blocks, tick = ns.Get('distance') and true or nil }
end)

-- (the list, the choice and the focus change at a click, in this addon or another: drawn again then.
-- A focus changed by a key binding of Thread (Routes) wakes a faded tracker, as the tracker's own keys do.)
MyRoute():OnChange(function() ns.Refresh() end)
ns.Base.Choice:OnChange(function() ns.Refresh() end)
ns.Base.Focus:OnChange(function()
	ns.Wake()
	ns.Refresh()
end)
