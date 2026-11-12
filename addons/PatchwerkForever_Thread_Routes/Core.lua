-- Thread (Routes): its settings and the slash command.
local ADDON, ns = ...
if not ns.linked then return end

ns.TITLE = 'Patchwerk Forever: Thread (Routes)'

---------------------------------------------------------------------------
-- Settings: kept in PatchwerkForever_Thread_RoutesDB.settings
---------------------------------------------------------------------------
-- One entry a setting, in the order they are shown. The base makes the pages from this list and
-- says what each kind of entry becomes (its Tools.lua). page: the page it is on (none: the first,
-- "Thread: Routes"). parent: greyed out while that tick box is off.
ns.settings = {
	{ key = 'auto', default = true, name = 'Route To My Map Pin',
		desc = 'When you put a pin on the world map, find the way to it at once.' },
	{ key = 'rxp', default = true, name = 'Follow My RestedXP Guide',
		desc = 'With no map pin, route to the current step of your RestedXP guide, and on to the next as you go.' },
	{ key = 'quests', default = true, name = 'Follow My Tracked Quest',
		desc = 'With no map pin, route to a quest you are tracking: to where it is to be done, on to its next objective, and to whoever takes it in once it is done.' },
	{ key = 'questPick', default = 'nearest', name = 'Which Quest', parent = 'quests',
		choices = { { 'nearest', 'The game\'s arrow, else the nearest tracked' }, { 'focus', 'Only the one the game\'s arrow is on' } },
		desc = 'The quest the game\'s own arrow is on always comes first. With none, either the nearest of the quests in your tracker, or nothing.' },
	{ key = 'sourceFirst', default = 'rxp', name = 'When A Guide And A Quest Both Lead Somewhere',
		choices = { { 'rxp', 'My RestedXP guide first' }, { 'quest', 'My tracked quest first' } },
		desc = 'Which one the route follows when both your guide and a tracked quest have somewhere to go. The other is followed when the first has nowhere on this continent.' },
	{ key = 'flights', default = true, name = 'Use Flight Paths',
		desc = 'Fly where that is quicker than walking.' },
	{ key = 'knownOnly', default = true, name = 'Only Flight Points I Know', parent = 'flights',
		desc = 'Leave out flight points this character has not found yet.' },
	{ key = 'rides', default = true, name = 'Use Boats And Zeppelins',
		desc = 'Take a boat or a zeppelin where that is quicker, and to reach another continent. Only the ones your side can use. How long you wait for one is not known, so the time given allows for half its round trip.' },
	{ key = 'notify', default = true, name = 'Say The Route In Chat',
		desc = 'Print the time, the distance and the flights of a new route.' },

	{ header = true, name = 'Herb And Ore Spots' },
	{ key = 'nodes', default = true, name = 'Remember Herb And Ore Spots',
		desc = 'Remember each spot where you pick a herb or mine a vein, for all your characters.' },
	{ key = 'nodesMinimap', default = true, name = 'Herb And Ore Spots On The Minimap',
		desc = 'Show the remembered spots on the minimap, each with the icon of what you got there. They show where things grow, not whether one is there now.' },
	{ key = 'nodesWorldMap', default = true, name = 'Herb And Ore Spots On The World Map',
		desc = 'Show the remembered spots on a zone\'s map.' },

	-- the route's trail
	{ page = 'Thread: Trail', key = 'worldMap', default = true, name = 'Trail On The World Map',
		desc = 'Draw the route on the world map.' },
	{ page = 'Thread: Trail', key = 'minimap', default = true, name = 'Trail On The Minimap',
		desc = 'Draw the route on the minimap.' },
	{ page = 'Thread: Trail', key = 'trailStyle', default = 'solid', name = 'Style',
		choices = { { 'solid', 'A solid line' }, { 'dashes', 'Dashes' }, { 'dots', 'Dots' } },
		desc = 'How the trail is drawn.' },
	{ page = 'Thread: Trail', key = 'trailMoving', default = false, name = 'Moving Trail',
		desc = 'Dashes or dots flow along the route toward where you are going. (A solid line does not move.)' },
	{ page = 'Thread: Trail', key = 'trailSpeed', default = 100, min = 25, max = 300, step = 25, name = 'Speed Of The Moving Trail',
		parent = 'trailMoving', desc = 'How fast the dashes or dots flow, in percent.' },
	{ page = 'Thread: Trail', key = 'trailThickMap', default = 3, min = 1, max = 8, step = 0.5, name = 'Thickness On The World Map',
		desc = 'How thick the trail is on the world map.' },
	{ page = 'Thread: Trail', key = 'trailThickMini', default = 2.5, min = 1, max = 6, step = 0.5, name = 'Thickness On The Minimap',
		desc = 'How thick the trail is on the minimap.' },
	{ page = 'Thread: Trail', key = 'trailWalk', colour = true, default = 'ffffd11a', name = 'Colour: Walking',
		desc = 'The colour of the stretches you walk.' },
	{ page = 'Thread: Trail', key = 'trailLink', colour = true, default = 'ffff73cc', name = 'Colour: Tunnels, Lifts And Drops',
		desc = 'The colour of a tunnel, a bridge, a lift or a drop.' },
	{ page = 'Thread: Trail', key = 'trailFly', colour = true, default = 'ff73d9ff', name = 'Colour: Flights',
		desc = 'The colour of a flight.' },
	{ page = 'Thread: Trail', key = 'trailRide', colour = true, default = 'ff66e6c8', name = 'Colour: Boats And Zeppelins',
		desc = 'The colour of the course a boat or a zeppelin takes.' },
}

---------------------------------------------------------------------------
-- /thread
---------------------------------------------------------------------------
local function Help()
	ns.Print('finds the way to your map pin, or with no pin to the current step of your RestedXP guide or to a quest you track.')
	ns.Print('  /thread go: route to the map pin now, or with none to the guide step or tracked quest')
	ns.Print('  /thread to 45.2 61.8: route to that spot on the map you are on')
	ns.Print('  /thread stop: stop routing (a guide step or quest is left alone until it moves on)')
	ns.Print('  /thread quest: where the game says your tracked quests are, and which one is followed')
	ns.Print('  /thread config: open the settings')
	ns.Print('  /thread where: say where the planner thinks you are')
	ns.Print('  /thread nodes: how many herb and ore spots are remembered')
	ns.Print('  /thread nodes forget: forget the spots within 15 yards of you')
end

SLASH_PATCHWERKFOREVER_THREAD1 = '/thread'
SLASH_PATCHWERKFOREVER_THREAD2 = '/pft'
SlashCmdList.PATCHWERKFOREVER_THREAD = function(text)
	local word, rest = (text or ''):lower():match('^%s*(%S*)%s*(.-)%s*$')
	if word == 'go' then
		ns.Try('go', ns.Go)
	elseif word == 'stop' or word == 'clear' then
		ns.Try('stop', ns.Stop, true)
	elseif word == 'to' then
		local x, y = rest:match('^([%d%.]+)[,%s]+([%d%.]+)$')
		if x then
			ns.Try('to', ns.GoToMapSpot, tonumber(x), tonumber(y))
		else
			ns.Print('say it like this: /thread to 45.2 61.8')
		end
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not ns.OpenSettings() then
			ns.Print('the settings are under Options > AddOns > Patchwerk Forever > Thread: Routes.')
		end
	elseif word == 'where' then
		ns.Try('where', ns.SayWhere)
	elseif word == 'nodes' then
		if rest == 'forget' then
			ns.Try('nodes', ns.NodesForget)
		else
			ns.Try('nodes', ns.NodesSay)
		end
	elseif word == 'quest' or word == 'quests' then
		ns.Try('quest', ns.QuestSay)
	else
		Help()
	end
end

-- For key and gamepad bindings (Bindings.xml).
BINDING_HEADER_PATCHWERKFOREVER_THREAD = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_THREAD_GO = 'Route to my map pin, guide step or quest'
BINDING_NAME_PATCHWERKFOREVER_THREAD_STOP = 'Stop routing'
function PatchwerkForever_Thread_Routes_Go() ns.Try('go', ns.Go) end
function PatchwerkForever_Thread_Routes_Stop() ns.Try('stop', ns.Stop, true) end
