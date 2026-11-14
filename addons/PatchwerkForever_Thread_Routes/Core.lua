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
	{ header = true, name = 'Destinations' },
	{ key = 'auto', default = true, name = 'Route To Map Pin',
		desc = 'Automatically route to a pin you place on the world map.' },
	{ key = 'rxp', default = true, name = 'Follow RestedXP Guide',
		desc = 'With no map pin, route to the current step of your RestedXP guide and continue to the next as you progress.' },
	{ key = 'rxpTravel', default = true, name = 'Use Guide Travel Steps', parent = 'rxp',
		desc = 'When a guide step tells you to fly, route on foot to the flight master it names instead of planning a different route. Steps without a location (hearthstone, training) are shown on screen, and no quest is routed to in their place.' },
	{ key = 'rxpAhead', default = 2, min = 0, max = 5, step = 1, name = 'Upcoming Steps Shown', parent = 'rxp',
		desc = 'Draw a fainter trail through this many upcoming guide steps on the world map and minimap. Routes to them are calculated in advance, so the trail updates instantly when a step is completed. 0 disables this.' },
	{ key = 'quests', default = true, name = 'Follow Tracked Quests',
		desc = 'With no map pin, route to a tracked quest: to its objective, and to the turn-in once it is complete.' },
	{ key = 'questPick', default = 'nearest', name = 'Quest Selection', parent = 'quests',
		choices = { { 'nearest', 'Quest arrow, else nearest tracked' }, { 'focus', 'Quest arrow only' } },
		desc = 'The quest with the game\'s quest arrow always comes first. Without one, route either to the nearest tracked quest or to none.' },
	{ key = 'sourceFirst', default = 'rxp', name = 'Priority',
		choices = { { 'rxp', 'RestedXP guide first' }, { 'quest', 'Tracked quest first' } },
		desc = 'Which to follow when both your guide and a tracked quest have a destination. The other is used when the first has none on this continent.' },
	{ header = true, name = 'Travel Options' },
	{ key = 'flights', default = true, name = 'Use Flight Paths',
		desc = 'Use flight paths when they are faster than walking.' },
	{ key = 'knownOnly', default = true, name = 'Known Flight Points Only', parent = 'flights',
		desc = 'Only fly between flight points this character has discovered. They are read from the flight map when you open it at a flight master, and remembered. Until one has been opened on a continent, routes there go on foot.' },
	{ key = 'rides', default = true, name = 'Use Boats And Zeppelins',
		desc = 'Use boats and zeppelins when they are faster, and to reach other continents. Only those available to your faction. Waiting time is unknown, so the estimate allows half a round trip.' },
	{ header = true, name = 'Chat' },
	{ key = 'notify', default = true, name = 'Print Route In Chat',
		desc = 'Print the time, distance and flights of each new route in chat.' },

	{ header = true, name = 'Gathering Nodes' },
	{ key = 'nodes', default = true, name = 'Record Gathering Nodes',
		desc = 'Record the location of each herb and ore node you gather, shared across your characters.' },
	{ key = 'nodesMinimap', default = true, name = 'Show Nodes On Minimap',
		desc = 'Show recorded nodes on the minimap, with the icon of what you gathered there. They mark where nodes spawn, not whether one is currently there.' },
	{ key = 'nodesWorldMap', default = true, name = 'Show Nodes On World Map',
		desc = 'Show recorded nodes on zone maps.' },

	-- the route's trail
	{ page = 'Routes: Trail', voice = 'A line on the ground. Patchwerk walks on the line. The line is never wrong. Mostly.' },
	{ page = 'Routes: Trail', header = true, name = 'Display' },
	{ page = 'Routes: Trail', key = 'worldMap', default = true, name = 'Show On World Map',
		desc = 'Draw the route on the world map.' },
	{ page = 'Routes: Trail', key = 'minimap', default = true, name = 'Show On Minimap',
		desc = 'Draw the route on the minimap.' },
	{ page = 'Routes: Trail', header = true, name = 'Line Style' },
	{ page = 'Routes: Trail', key = 'trailStyle', default = 'solid', name = 'Line Style',
		choices = { { 'solid', 'Solid' }, { 'dashes', 'Dashed' }, { 'dots', 'Dotted' } },
		desc = 'How the route line is drawn.' },
	{ page = 'Routes: Trail', key = 'trailMoving', default = false, name = 'Animate Line',
		desc = 'Animate dashes or dots along the route toward your destination. Solid lines are not animated.' },
	{ page = 'Routes: Trail', key = 'trailSpeed', default = 100, min = 25, max = 300, step = 25, name = 'Animation Speed',
		parent = 'trailMoving', desc = 'Speed of the line animation, in percent.' },
	{ page = 'Routes: Trail', key = 'trailThickMap', default = 3, min = 1, max = 8, step = 0.5, name = 'World Map Line Width',
		desc = 'Width of the route line on the world map.' },
	{ page = 'Routes: Trail', key = 'trailThickMini', default = 2.5, min = 1, max = 6, step = 0.5, name = 'Minimap Line Width',
		desc = 'Width of the route line on the minimap.' },
	{ page = 'Routes: Trail', header = true, name = 'Colors' },
	{ page = 'Routes: Trail', key = 'trailWalk', colour = true, default = 'ffffd11a', name = 'Walking Color',
		desc = 'Color of sections you walk.' },
	{ page = 'Routes: Trail', key = 'trailLink', colour = true, default = 'ffff73cc', name = 'Tunnel, Lift And Drop Color',
		desc = 'Color of tunnels, bridges, lifts and drops.' },
	{ page = 'Routes: Trail', key = 'trailFly', colour = true, default = 'ff73d9ff', name = 'Flight Color',
		desc = 'Color of flights.' },
	{ page = 'Routes: Trail', key = 'trailRide', colour = true, default = 'ff66e6c8', name = 'Boat And Zeppelin Color',
		desc = 'Color of boat and zeppelin crossings.' },
	{ page = 'Routes: Trail', key = 'trailChosen', colour = true, default = 'ffff8c42', name = 'Selected Route Color',
		desc = 'Color of walking sections on a route you selected yourself: a quest clicked in the tracker, or a gathering run. Your main route (guide or tracked quests) uses the walking color.' },

	-- the step, said on screen
	{ page = 'Routes: Step Text', voice = 'Big words in the sky, so Patchwerk does not forget why he is walking.' },
	{ page = 'Routes: Step Text', key = 'float', default = true, name = 'Show Step Text',
		desc = 'Show a short description on screen when the route gets a new destination (guide step, quest objective or map pin). It fades in, stays a few seconds and fades out. Not shown when a route is only recalculated.' },
	{ page = 'Routes: Step Text', key = 'floatRoute', default = true, name = 'Show Route Summary', parent = 'float',
		desc = 'Show a smaller line below the text with the travel time, walking distance and flights.' },
	{ page = 'Routes: Step Text', key = 'floatSize', default = 20, min = 12, max = 40, step = 1, name = 'Font Size',
		desc = 'Font size of the step text.' },
	{ page = 'Routes: Step Text', key = 'floatHold', default = 5, min = 2, max = 15, step = 1, name = 'Duration',
		desc = 'How long the text stays on screen, in seconds.' },
	{ page = 'Routes: Step Text', key = 'floatDown', default = 18, min = 0, max = 80, step = 1, name = 'Vertical Position',
		desc = 'Distance from the top of the screen, in percent of screen height.' },
	{ page = 'Routes: Step Text', key = 'floatAcross', default = 0, min = -40, max = 40, step = 1, name = 'Horizontal Offset',
		desc = 'Offset from the center of the screen, in percent of screen width. Negative moves left.' },
	{ page = 'Routes: Step Text', button = 'Show', name = 'Preview Step Text', click = function() ns.FloatTest() end,
		desc = 'Show a sample step text with the current settings.' },
}

---------------------------------------------------------------------------
-- /thread
---------------------------------------------------------------------------
local function Help()
	ns.Print('Route planner commands:')
	ns.Print('  /thread go: route to your map pin, or to your guide step or tracked quest')
	ns.Print('  /thread to 45.2 61.8: route to those coordinates on your current map')
	ns.Print('  /thread stop: stop routing (a route to a guide step or quest resumes when the step or objective changes)')
	ns.Print('  /thread quest: list tracked quest locations and which one is being followed')
	ns.Print('  /thread step: show the step text again')
	ns.Print('  /thread gather: route to the nearest recorded herb or ore node, then the next (gather round, gather <name>, gather list, gather stop)')
	ns.Print('  /thread config: open the options')
	ns.Print('  /thread where: show your position as the planner sees it')
	ns.Print('  /thread flights: list the flight points you know on this continent, and how that is known')
	ns.Print('  /thread nodes: count recorded herb and ore nodes')
	ns.Print('  /thread nodes forget: delete recorded nodes within 15 yards')
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
			ns.Print('Usage: /thread to 45.2 61.8')
		end
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not ns.OpenSettings() then
			ns.Print('Options are under Options > AddOns > Patchwerk Forever > Thread: Routes.')
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
	elseif word == 'step' then
		ns.Try('step', ns.FloatAgain)
	elseif word == 'flights' then
		ns.Try('flights', ns.FlightsSay)
	elseif word == 'gather' then
		ns.Try('gather', ns.GatherSay, rest)
	else
		Help()
	end
end

-- For key and gamepad bindings (Bindings.xml).
BINDING_HEADER_PATCHWERKFOREVER_THREAD = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_THREAD_GO = 'Route To Pin, Guide Step Or Quest'
BINDING_NAME_PATCHWERKFOREVER_THREAD_STOP = 'Stop Routing'
function PatchwerkForever_Thread_Routes_Go() ns.Try('go', ns.Go) end
function PatchwerkForever_Thread_Routes_Stop() ns.Try('stop', ns.Stop, true) end
