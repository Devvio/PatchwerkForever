-- Wayfarer: saved settings, messages, the slash command.
local ADDON, ns = ...

ns.TITLE = 'Patchwerk Forever: Wayfarer'
local PREFIX = '|cff7fd4ffWayfarer|r: '

function ns.Print(...)
	local frame = DEFAULT_CHAT_FRAME
	if frame then
		frame:AddMessage(PREFIX .. strjoin(' ', tostringall(...)))
	end
end

-- Runs fn; an error is reported once per label, not thrown, so one broken part does not take the rest with it.
local reported = {}
function ns.Try(label, fn, ...)
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	if not reported[label] then
		reported[label] = true
		ns.Print('a problem in ' .. label .. ' (reported once): ' .. tostring(a))
	end
	return nil
end

---------------------------------------------------------------------------
-- Settings: kept in PatchwerkForever_WayfarerDB.settings
---------------------------------------------------------------------------
-- One entry a setting, in the order they are shown. What kind of control it gets on the options page
-- (Settings.lua) follows from the entry:
--   default true/false          a tick box
--   default a number, min, max, step     a slider
--   choices = { { value, label }, ... }   a list to pick from (default is one of the values)
--   colour = true               a colour (default "ffRRGGBB", as the game's colour swatch keeps it)
--   button = 'text', click = function    a button; no value
--   header = true               a heading; no value
-- page: the sub-page it is on (nil: the first page). parent: greyed out while that tick box is off.
local EFFECTS = {
	{ 'star', 'Star' }, { 'glow', 'Soft glow' }, { 'ring', 'Pulsing ring' }, { 'beam', 'Light beam' },
	{ 'swirl', 'Swirl' }, { 'brackets', 'Brackets' },
	{ 'glints', 'Subtle: glints' }, { 'fireflies', 'Subtle: fireflies' }, { 'shimmer', 'Subtle: faint shimmer' },
	{ 'ripple', 'Subtle: ground ripple' }, { 'wisp', 'Subtle: wisp' },
	{ 'none', 'None (name only)' },
}
-- the kinds of thing that can sparkle: key, its page, its colour and its effect to begin with
ns.KINDS = {
	{ 'herb', 'Sparkle: Herbs', 'ff73ff73', 'star' },
	{ 'ore', 'Sparkle: Ore', 'ffff9e33', 'star' },
	{ 'loot', 'Sparkle: Chests', 'ff80ccff', 'glow' },
	{ 'quest', 'Sparkle: Quest Objects', 'ffffd933', 'ring' },
	{ 'other', 'Sparkle: Other Things', 'ffebebf5', 'glow' },
}

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
	{ key = 'nodes', default = true, name = 'Remember Herb And Ore Spots',
		desc = 'Remember each spot where you pick a herb or mine a vein, for all your characters.' },
	{ key = 'nodesMinimap', default = true, name = 'Herb And Ore Spots On The Minimap',
		desc = 'Show the remembered spots on the minimap, each with the icon of what you got there. They show where things grow, not whether one is there now.' },
	{ key = 'nodesWorldMap', default = true, name = 'Herb And Ore Spots On The World Map',
		desc = 'Show the remembered spots on a zone\'s map.' },

	{ header = true, name = 'Sparkle' },
	{ key = 'sparkle', default = true, name = 'Sparkle On Things Nearby',
		desc = 'Puts a sparkle on the herb, vein, chest or quest object nearest you as you come up to it. While this is ticked it switches on two of the game\'s own settings, which give the thing a nameplate to hang the sparkle on; unticking puts them back as they were. Each kind of thing has its own page for how it looks.' },
	{ key = 'sparkleAll', default = false, name = 'Sparkle On Everything You Can Use', parent = 'sparkle',
		desc = 'Also mailboxes, doors, anvils and the like.' },
	{ key = 'sparkleCombat', default = false, name = 'Hide In Combat', parent = 'sparkle',
		desc = 'No sparkle and no name while you are fighting.' },
	{ key = 'sparkleInstance', default = false, name = 'Hide In Dungeons And Raids', parent = 'sparkle',
		desc = 'No sparkle and no name inside a dungeon, a raid or a battleground.' },
	{ button = 'Apply', name = 'Subtle Sparkles For Every Kind', click = function() ns.SparkleSubtle() end,
		desc = 'Gives every kind of thing one of the subtle effects: glints on herbs and ore, a faint shimmer on chests, a ground ripple on quest objects, fireflies on the rest. Only the effect changes; your colours and sizes stay. Each kind can be changed again on its own page.' },
	{ button = 'Forget', name = 'Things You Ignore', click = function() ns.IgnoreClear() end,
		desc = 'A thing you ignore never sparkles again: point at it and type /wayfarer ignore, or use the key you bound to it. This button forgets the whole list.' },

	-- the name written over the thing
	{ page = 'Name Over Things', key = 'sparkleName', default = true, name = 'Name Over The Thing',
		desc = 'Write the name of the thing over it.' },
	{ page = 'Name Over Things', key = 'nameSize', default = 13, min = 8, max = 32, step = 1, name = 'Size',
		desc = 'How large the name is written.' },
	{ page = 'Name Over Things', key = 'nameFont', default = 'game', name = 'Font',
		choices = { { 'game', 'The game\'s own' }, { 'friz', 'Friz Quadrata' }, { 'arial', 'Arial Narrow' },
			{ 'morpheus', 'Morpheus' }, { 'skurri', 'Skurri' } },
		desc = 'The lettering the name is written in.' },
	{ page = 'Name Over Things', key = 'nameOutline', default = 'thin', name = 'Outline',
		choices = { { 'none', 'None' }, { 'thin', 'Thin' }, { 'thick', 'Thick' } },
		desc = 'A dark edge round the letters, to read them against anything.' },
	{ page = 'Name Over Things', key = 'nameColour', default = 'kind', name = 'Colour',
		choices = { { 'kind', 'The colour of its kind' }, { 'fixed', 'One colour for all' } },
		desc = 'Green for a herb, orange for ore and so on, or the one colour below for everything.' },
	{ page = 'Name Over Things', key = 'nameFixed', colour = true, default = 'ffffffff', name = 'The One Colour',
		desc = 'The colour of every name when "One colour for all" is chosen above.' },
	{ page = 'Name Over Things', key = 'namePlace', default = 'below', name = 'Place',
		choices = { { 'below', 'Under the game\'s icon' }, { 'above', 'Over the game\'s icon' } },
		desc = 'Where the name stands.' },
	{ page = 'Name Over Things', key = 'nameOffset', default = 14, min = 0, max = 80, step = 2, name = 'Distance',
		desc = 'How far from the icon the name stands.' },

	-- the route's trail
	{ page = 'Trail', key = 'worldMap', default = true, name = 'Trail On The World Map',
		desc = 'Draw the route on the world map.' },
	{ page = 'Trail', key = 'minimap', default = true, name = 'Trail On The Minimap',
		desc = 'Draw the route on the minimap.' },
	{ page = 'Trail', key = 'trailStyle', default = 'solid', name = 'Style',
		choices = { { 'solid', 'A solid line' }, { 'dashes', 'Dashes' }, { 'dots', 'Dots' } },
		desc = 'How the trail is drawn.' },
	{ page = 'Trail', key = 'trailMoving', default = false, name = 'Moving Trail',
		desc = 'Dashes or dots flow along the route toward where you are going. (A solid line does not move.)' },
	{ page = 'Trail', key = 'trailSpeed', default = 100, min = 25, max = 300, step = 25, name = 'Speed Of The Moving Trail',
		parent = 'trailMoving', desc = 'How fast the dashes or dots flow, in percent.' },
	{ page = 'Trail', key = 'trailThickMap', default = 3, min = 1, max = 8, step = 0.5, name = 'Thickness On The World Map',
		desc = 'How thick the trail is on the world map.' },
	{ page = 'Trail', key = 'trailThickMini', default = 2.5, min = 1, max = 6, step = 0.5, name = 'Thickness On The Minimap',
		desc = 'How thick the trail is on the minimap.' },
	{ page = 'Trail', key = 'trailWalk', colour = true, default = 'ffffd11a', name = 'Colour: Walking',
		desc = 'The colour of the stretches you walk.' },
	{ page = 'Trail', key = 'trailLink', colour = true, default = 'ffff73cc', name = 'Colour: Tunnels, Lifts And Drops',
		desc = 'The colour of a tunnel, a bridge, a lift or a drop.' },
	{ page = 'Trail', key = 'trailFly', colour = true, default = 'ff73d9ff', name = 'Colour: Flights',
		desc = 'The colour of a flight.' },
	{ page = 'Trail', key = 'trailRide', colour = true, default = 'ff66e6c8', name = 'Colour: Boats And Zeppelins',
		desc = 'The colour of the course a boat or a zeppelin takes.' },
}
-- each kind of thing: how its sparkle looks
for _, kind in ipairs(ns.KINDS) do
	local k, page = kind[1], kind[2]
	local add = function(def) def.page = page; ns.settings[#ns.settings + 1] = def end
	add({ key = 'look.' .. k .. '.effect', default = kind[4], name = 'Effect', choices = EFFECTS,
		desc = 'What the sparkle looks like.' })
	add({ key = 'look.' .. k .. '.colour', colour = true, default = kind[3], name = 'Colour',
		desc = 'The colour of the sparkle (and of the name, when names take the colour of their kind).' })
	add({ key = 'look.' .. k .. '.size', default = 110, min = 40, max = 260, step = 10, name = 'Size',
		desc = 'How large the sparkle is.' })
	add({ key = 'look.' .. k .. '.bright', default = 100, min = 20, max = 100, step = 5, name = 'Brightness',
		desc = 'How bright the sparkle is, in percent.' })
	add({ key = 'look.' .. k .. '.height', default = -40, min = -160, max = 100, step = 5, name = 'Height',
		desc = 'How far under (below zero) or over the nameplate the sparkle sits. The nameplate floats a little above the thing.' })
	add({ key = 'look.' .. k .. '.speed', default = 100, min = 25, max = 300, step = 25, name = 'Speed',
		desc = 'How fast it turns and pulses, in percent.' })
	add({ button = 'Test', name = 'Show Me', click = function() ns.SparkleTest(k) end,
		desc = 'Shows this sparkle in the middle of the screen for a few seconds.' })
end
-- the sparkle fading where it comes over your character
do
	local page = 'Sparkle: Behind My Character'
	local add = function(def) def.page = page; ns.settings[#ns.settings + 1] = def end
	add({ key = 'sparkleBehind', default = false, name = 'Fade Behind My Character',
		desc = 'An addon cannot draw behind your character, so this stands in for it: the sparkle and the name fade as they come over the place on screen where your character stands. That place is worked out from how far out the camera is; the sliders below correct it and the button shows it.' })
	add({ key = 'sparkleBehindLeft', default = 0, min = 0, max = 80, step = 5, name = 'Brightness Left',
		desc = 'How much of the sparkle still shows when it is right over your character, in percent. Zero hides it.' })
	add({ key = 'sparkleBehindSize', default = 100, min = 40, max = 300, step = 10, name = 'Character Size',
		desc = 'How tall your character is taken to be on screen, in percent. Raise it for a tall character or a mount.' })
	add({ key = 'sparkleBehindWide', default = 50, min = 20, max = 200, step = 10, name = 'Character Width',
		desc = 'How wide your character is taken to be, in percent of its height.' })
	add({ key = 'sparkleBehindAcross', default = 0, min = -40, max = 40, step = 1, name = 'Across',
		desc = 'Moves the place left (below zero) or right, in percent of the screen. For a camera that keeps your character off to one side.' })
	add({ key = 'sparkleBehindUp', default = 0, min = -40, max = 40, step = 1, name = 'Up',
		desc = 'Moves the place down (below zero) or up, in percent of the screen.' })
	add({ button = 'Show', name = 'Show Where', click = function() ns.SparkleBehindShow() end,
		desc = 'Draws an oval for ten seconds where your character is taken to be. It should sit round your character; it follows the camera as you zoom.' })
end

local byKey, watchers = {}, {}
for _, def in ipairs(ns.settings) do
	if def.key then byKey[def.key] = def end
end

-- A colour kept as "ffRRGGBB": its red, green and blue, each 0 to 1.
local colours = {}
function ns.RGB(hex)
	local c = colours[hex]
	if not c then
		local r, g, b = tostring(hex):match('(%x%x)(%x%x)(%x%x)$')        -- the last six: "RRGGBB" will do too
		c = r and { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 } or { 1, 1, 1 }
		colours[hex] = c
	end
	return c[1], c[2], c[3]
end

function ns.Get(key)
	local saved = PatchwerkForever_WayfarerDB and PatchwerkForever_WayfarerDB.settings
	local value = saved and saved[key]
	if value == nil then
		local def = byKey[key]
		return def and def.default
	end
	return value
end

function ns.Set(key, value)
	if not byKey[key] then return end
	PatchwerkForever_WayfarerDB = PatchwerkForever_WayfarerDB or {}
	PatchwerkForever_WayfarerDB.settings = PatchwerkForever_WayfarerDB.settings or {}
	PatchwerkForever_WayfarerDB.settings[key] = value
	for _, fn in ipairs(watchers) do
		ns.Try('a setting', fn, key, value)
	end
end

function ns.OnSetting(fn)
	watchers[#watchers + 1] = fn
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame('Frame')
local handlers = {}
ns.frame = frame

function ns.On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		frame:RegisterEvent(event)
	end
	table.insert(handlers[event], fn)
end

frame:SetScript('OnEvent', function(_, event, ...)
	local list = handlers[event]
	if list then
		for _, fn in ipairs(list) do
			ns.Try(event, fn, ...)
		end
	end
end)

ns.On('ADDON_LOADED', function(name)
	if name == ADDON then
		PatchwerkForever_WayfarerDB = PatchwerkForever_WayfarerDB or {}
		PatchwerkForever_WayfarerDB.settings = PatchwerkForever_WayfarerDB.settings or {}
	end
end)

---------------------------------------------------------------------------
-- /wayfarer
---------------------------------------------------------------------------
local function Help()
	ns.Print('finds the way to your map pin, or with no pin to the current step of your RestedXP guide or to a quest you track.')
	ns.Print('  /wayfarer go: route to the map pin now, or with none to the guide step or tracked quest')
	ns.Print('  /wayfarer to 45.2 61.8: route to that spot on the map you are on')
	ns.Print('  /wayfarer stop: stop routing (a guide step or quest is left alone until it moves on)')
	ns.Print('  /wayfarer quest: where the game says your tracked quests are, and which one is followed')
	ns.Print('  /wayfarer config: open the settings')
	ns.Print('  /wayfarer where: say where the planner thinks you are')
	ns.Print('  /wayfarer nodes: how many herb and ore spots are remembered')
	ns.Print('  /wayfarer nodes forget: forget the spots within 15 yards of you')
	ns.Print('  /wayfarer sparkle: what the game is pointing at just now, and why it does or does not sparkle')
	ns.Print('  /wayfarer ignore: never sparkle again on the thing you are pointing at (ignore undo, ignore list, ignore clear)')
end

SLASH_PATCHWERKFOREVER_WAYFARER1 = '/wayfarer'
SLASH_PATCHWERKFOREVER_WAYFARER2 = '/pfw'
SlashCmdList.PATCHWERKFOREVER_WAYFARER = function(text)
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
			ns.Print('say it like this: /wayfarer to 45.2 61.8')
		end
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not (ns.OpenSettings and ns.OpenSettings()) then
			ns.Print('the settings are under Options > AddOns > ' .. ns.TITLE .. '.')
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
	elseif word == 'sparkle' then
		ns.Try('sparkle', ns.SparkleSay)
	elseif word == 'ignore' then
		if rest == 'list' then
			ns.Try('ignore', ns.IgnoreSay)
		elseif rest == 'clear' then
			ns.Try('ignore', ns.IgnoreClear)
		elseif rest == 'undo' then
			ns.Try('ignore', ns.IgnoreUndo)
		else
			ns.Try('ignore', ns.IgnoreThis)
		end
	else
		Help()
	end
end

-- For key and gamepad bindings (Bindings.xml).
BINDING_HEADER_PATCHWERKFOREVER_WAYFARER = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_WAYFARER_GO = 'Route to my map pin, guide step or quest'
BINDING_NAME_PATCHWERKFOREVER_WAYFARER_STOP = 'Stop routing'
BINDING_NAME_PATCHWERKFOREVER_WAYFARER_IGNORE = 'Never sparkle on this thing again'
function PatchwerkForever_Wayfarer_Ignore() ns.Try('ignore', ns.IgnoreThis) end
function PatchwerkForever_Wayfarer_Go() ns.Try('go', ns.Go) end
function PatchwerkForever_Wayfarer_Stop() ns.Try('stop', ns.Stop, true) end
