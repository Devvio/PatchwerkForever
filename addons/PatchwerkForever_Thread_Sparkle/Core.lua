-- Thread (Sparkle): its settings and the slash command.
local ADDON, ns = ...
if not ns.linked then return end

ns.TITLE = 'Patchwerk Forever: Thread (Sparkle)'

---------------------------------------------------------------------------
-- Settings: kept in PatchwerkForever_Thread_SparkleDB.settings
---------------------------------------------------------------------------
-- One entry a setting, in the order they are shown. The base makes the pages from this list and
-- says what each kind of entry becomes (its Tools.lua). page: the page it is on (none: the first,
-- "Thread: Sparkle"). parent: greyed out while that tick box is off.
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
		desc = 'A thing you ignore never sparkles again: point at it and type /sparkle ignore, or use the key you bound to it. This button forgets the whole list.' },

	-- the name written over the thing
	{ page = 'Sparkle: Names', key = 'sparkleName', default = true, name = 'Name Over The Thing',
		desc = 'Write the name of the thing over it.' },
	{ page = 'Sparkle: Names', key = 'nameSize', default = 13, min = 8, max = 32, step = 1, name = 'Size',
		desc = 'How large the name is written.' },
	{ page = 'Sparkle: Names', key = 'nameFont', default = 'game', name = 'Font',
		choices = { { 'game', 'The game\'s own' }, { 'friz', 'Friz Quadrata' }, { 'arial', 'Arial Narrow' },
			{ 'morpheus', 'Morpheus' }, { 'skurri', 'Skurri' } },
		desc = 'The lettering the name is written in.' },
	{ page = 'Sparkle: Names', key = 'nameOutline', default = 'thin', name = 'Outline',
		choices = { { 'none', 'None' }, { 'thin', 'Thin' }, { 'thick', 'Thick' } },
		desc = 'A dark edge round the letters, to read them against anything.' },
	{ page = 'Sparkle: Names', key = 'nameColour', default = 'kind', name = 'Colour',
		choices = { { 'kind', 'The colour of its kind' }, { 'fixed', 'One colour for all' } },
		desc = 'Green for a herb, orange for ore and so on, or the one colour below for everything.' },
	{ page = 'Sparkle: Names', key = 'nameFixed', colour = true, default = 'ffffffff', name = 'The One Colour',
		desc = 'The colour of every name when "One colour for all" is chosen above.' },
	{ page = 'Sparkle: Names', key = 'namePlace', default = 'below', name = 'Place',
		choices = { { 'below', 'Under the game\'s icon' }, { 'above', 'Over the game\'s icon' } },
		desc = 'Where the name stands.' },
	{ page = 'Sparkle: Names', key = 'nameOffset', default = 14, min = 0, max = 80, step = 2, name = 'Distance',
		desc = 'How far from the icon the name stands.' },
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

---------------------------------------------------------------------------
-- /sparkle
---------------------------------------------------------------------------
local function Help()
	ns.Print('a sparkle and a name on the herb, vein, chest or quest object you are coming up to.')
	ns.Print('  /sparkle: what the game is pointing at just now, and why it does or does not sparkle')
	ns.Print('  /sparkle ignore: never sparkle again on the thing you are pointing at')
	ns.Print('  /sparkle undo: take the last ignore back;  /sparkle list;  /sparkle clear')
	ns.Print('  /sparkle config: open the settings')
end

SLASH_PATCHWERKFOREVER_SPARKLE1 = '/sparkle'
SLASH_PATCHWERKFOREVER_SPARKLE2 = '/pfs'
SlashCmdList.PATCHWERKFOREVER_SPARKLE = function(text)
	local word, rest = (text or ''):lower():match('^%s*(%S*)%s*(.-)%s*$')
	if word == 'ignore' and rest ~= '' then
		word = rest                                   -- (/sparkle ignore undo, as it was under the route planner)
	end
	if word == '' or word == 'say' or word == 'sparkle' then
		ns.Try('sparkle', ns.SparkleSay)
	elseif word == 'ignore' then
		ns.Try('ignore', ns.IgnoreThis)
	elseif word == 'undo' then
		ns.Try('ignore', ns.IgnoreUndo)
	elseif word == 'list' then
		ns.Try('ignore', ns.IgnoreSay)
	elseif word == 'clear' then
		ns.Try('ignore', ns.IgnoreClear)
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not ns.OpenSettings() then
			ns.Print('the settings are under Options > AddOns > Patchwerk Forever > Thread: Sparkle.')
		end
	else
		Help()
	end
end

-- For key and gamepad bindings (Bindings.xml).
BINDING_HEADER_PATCHWERKFOREVER_SPARKLE = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_SPARKLE_IGNORE = 'Never sparkle on this thing again'
function PatchwerkForever_Thread_Sparkle_Ignore() ns.Try('ignore', ns.IgnoreThis) end
