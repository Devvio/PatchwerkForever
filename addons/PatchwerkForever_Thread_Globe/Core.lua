-- Thread (Globe): its settings and the slash command.
local ADDON, ns = ...
if not ns.linked then return end

ns.TITLE = 'Patchwerk Forever: Thread (Globe)'

-- One entry a setting, in the order they are shown (the base makes the page from this list).
ns.settings = {
	{ key = 'globeStyle', default = 'parchment', name = 'Map Style',
		choices = { { 'parchment', 'Parchment' }, { 'minimap', 'Minimap Pictures' } },
		desc = 'Parchment: the painted world map of each continent, as the world map shows it. Minimap Pictures: the land as the minimap shows it, from above.' },
	{ key = 'globeNames', default = true, name = 'Show Names',
		desc = 'Show the names of the continents when the whole globe is in view, and of the zones as you zoom in.' },
	{ key = 'globeRoute', default = true, name = 'Show Your Route',
		desc = 'Show the trail Thread (Routes) leads you along, and the numbered stops of My Route. Click a stop for what can be done with it.' },
	{ key = 'globeQuests', default = true, name = 'Show Quests',
		desc = 'Show where your quests are done and handed in, quests on offer, and the steps of the guide you run. Click a quest to route to it.' },
	{ key = 'globeTracker', default = true, name = 'Tracker Beside The Globe',
		desc = 'While the globe is open, put the list of Thread (Tracker) beside it. It goes back where you keep it when the globe closes. Needs Thread (Tracker).' },
	{ key = 'globePlaces', default = true, name = 'Show Places',
		desc = 'Show towns, landmarks, and dungeon and raid entrances as you zoom in, and while you are dead your corpse and the spirit healer.' },
	{ key = 'globePeople', default = true, name = 'Show Your Group',
		desc = 'Show the members of your party or raid, each in the colour of their class.' },
	{ key = 'globeCoords', default = true, name = 'Show Coordinates',
		desc = 'Show your coordinates, and those of the place under the pointer, at the lower edge of the picture.' },
	{ key = 'globeFlights', default = true, name = 'Show Flight Points',
		desc = 'Show the flight points of your side as you zoom in. Those you have not discovered are grey.' },
	{ key = 'globeCrossings', default = true, name = 'Show Boats And Zeppelins',
		desc = 'Show where the boats and zeppelins you can take put in, and the way they go. Needs Thread (Routes).' },
	{ key = 'globeNodes', default = true, name = 'Show Herb And Ore Nodes',
		desc = 'Show the herb and ore nodes Thread (Routes) has recorded, when you zoom right in. Needs Thread (Routes).' },
	{ key = 'globeLight', default = true, name = 'Shade The Globe',
		desc = 'Darken the globe a little toward its edge, as a ball is.' },
	{ key = 'globeStats', default = true, name = 'Show Drawing Numbers',
		desc = 'Show under the globe how many map pieces are drawn and how long drawing them takes. For trying the prototype.' },
	{ key = 'globePad', default = true, name = 'Gamepad Turns The Globe',
		desc = 'While the globe is open and you are not in combat, a gamepad turns it with the left stick and zooms with the right stick or the triggers. Its four face buttons press what is at the middle of the picture (or fit the zone there), step out (and close from the whole globe), go to the next mark, and set or clear the map pin. Your character does not move by the left stick meanwhile. Off: the gamepad is left alone, and the keys under Key Bindings can be given to its buttons.' },
	{ button = 'Open', name = 'Open The Globe', click = function() ns.Toggle(true) end,
		desc = 'Open the globe window. /globe does the same.' },
}

local function Help()
	ns.Print('Globe commands (/globe or /pfg):')
	ns.Print('  /globe: open or close the globe')
	ns.Print('  /globe me: open it turned to where you are')
	ns.Print('  /globe full: fill the screen with it, or back to a window')
	ns.Print('  /globe stats: say how the last drawing went')
	ns.Print('  /globe config: open the options')
end

SLASH_PATCHWERKFOREVER_GLOBE1 = '/globe'
SLASH_PATCHWERKFOREVER_GLOBE2 = '/pfg'
SlashCmdList.PATCHWERKFOREVER_GLOBE = function(text)
	local word = (text or ''):lower():match('^%s*(%S*)')
	if word == '' then
		ns.Try('the globe', ns.Toggle)
	elseif word == 'me' then
		ns.Try('the globe', function() ns.Toggle(true); ns.CenterOnMe() end)
	elseif word == 'full' then
		ns.Try('the globe', function() ns.Toggle(true); ns.GlobeFull() end)
	elseif word == 'stats' then
		ns.Try('the globe', ns.SayStats)
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not ns.OpenSettings() then
			ns.Print(InCombatLockdown() and 'Options cannot be opened in combat.'
				or 'Options are under Options > AddOns > Patchwerk Forever > Thread: Globe.')
		end
	else
		Help()
	end
end

-- Key bindings (Bindings.xml), in the family's own section of the Key Bindings page. The turning and
-- zooming ones work while their key is held (down: it went down; false: it was let go).
BINDING_HEADER_PATCHWERKFOREVER_GLOBE = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_GLOBE_TOGGLE = 'Open Or Close The Globe'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_ME = 'Where I Am'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_FULL = 'Full Screen Or Window'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_GOTO = 'Go To'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_FIT = 'Fit The Zone At The Middle'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_BACK = 'Step Out'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_LEFT = 'Turn Left'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_RIGHT = 'Turn Right'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_UP = 'Turn Up'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_DOWN = 'Turn Down'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_IN = 'Zoom In'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_OUT = 'Zoom Out'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_PIN = 'Set Or Clear The Map Pin At The Middle'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_NEXT = 'Next Mark'
BINDING_NAME_PATCHWERKFOREVER_GLOBE_ROUTE = 'Route Menu'
function PatchwerkForever_Thread_Globe_Key(what, down)
	if what == 'toggle' then
		ns.Try('the globe', ns.Toggle)
	else
		ns.Try('the globe', ns.GlobeKey, what, down)
	end
end
