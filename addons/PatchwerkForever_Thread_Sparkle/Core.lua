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
	{ 'other', 'Sparkle: Other Objects', 'ffebebf5', 'glow' },
}

ns.settings = {
	{ key = 'sparkle', default = true, name = 'Enable Sparkles',
		desc = 'Show a sparkle on the nearest herb, ore node, chest or quest object as you approach it. While enabled, two game settings are turned on to give objects a nameplate; they are restored when you disable this.' },
	{ key = 'sparkleAll', default = false, name = 'Include All Interactable Objects', parent = 'sparkle',
		desc = 'Also show sparkles on mailboxes, doors, anvils and similar objects.' },
	{ key = 'sparkleCombat', default = false, name = 'Hide In Combat', parent = 'sparkle',
		desc = 'Hide sparkles and names while you are in combat.' },
	{ key = 'sparkleInstance', default = false, name = 'Hide In Instances', parent = 'sparkle',
		desc = 'Hide sparkles and names in dungeons, raids and battlegrounds.' },
	{ button = 'Apply', name = 'Apply Subtle Preset', click = function() ns.SparkleSubtle() end,
		desc = 'Set every object type to a subtle effect: glints on herbs and ore, a faint shimmer on chests, a ground ripple on quest objects, fireflies on the rest. Only the effect changes; your colors and sizes are kept.' },
	{ button = 'Clear', name = 'Clear Ignore List', click = function() ns.IgnoreClear() end,
		desc = 'Ignored objects never sparkle. To ignore one, point at it and type /sparkle ignore, or use the key binding. This button clears the whole list.' },

	-- the name written over the thing
	{ page = 'Sparkle: Names', voice = 'Patchwerk likes to know what a thing is before he picks it up.' },
	{ page = 'Sparkle: Names', key = 'sparkleName', default = true, name = 'Show Object Name',
		desc = 'Show the name of the object next to it.' },
	{ page = 'Sparkle: Names', key = 'nameSize', default = 13, min = 8, max = 32, step = 1, name = 'Font Size',
		desc = 'Font size of the name.' },
	{ page = 'Sparkle: Names', key = 'nameFont', default = 'game', name = 'Font',
		choices = { { 'game', 'Default' }, { 'friz', 'Friz Quadrata' }, { 'arial', 'Arial Narrow' },
			{ 'morpheus', 'Morpheus' }, { 'skurri', 'Skurri' } },
		desc = 'Font of the name.' },
	{ page = 'Sparkle: Names', key = 'nameOutline', default = 'thin', name = 'Outline',
		choices = { { 'none', 'None' }, { 'thin', 'Thin' }, { 'thick', 'Thick' } },
		desc = 'Outline around the text, for readability.' },
	{ page = 'Sparkle: Names', key = 'nameColour', default = 'kind', name = 'Color Mode',
		choices = { { 'kind', 'By object type' }, { 'fixed', 'Single color' } },
		desc = 'Color names by object type (green for herbs, orange for ore, and so on) or use a single color for all.' },
	{ page = 'Sparkle: Names', key = 'nameFixed', colour = true, default = 'ffffffff', name = 'Name Color',
		desc = 'Color of all names when Color Mode is set to Single color.' },
	{ page = 'Sparkle: Names', key = 'namePlace', default = 'below', name = 'Position',
		choices = { { 'below', 'Below the icon' }, { 'above', 'Above the icon' } },
		desc = 'Where the name appears.' },
	{ page = 'Sparkle: Names', key = 'nameOffset', default = 14, min = 0, max = 80, step = 2, name = 'Offset',
		desc = 'Distance between the name and the icon.' },
}
-- each kind of thing: how its sparkle looks
-- (one page for all of them, a heading for each kind)
ns.settings[#ns.settings + 1] = { page = 'Sparkle: Looks', voice = 'Every shiny thing gets a shine of its own. Patchwerk is fair.' }
for _, kind in ipairs(ns.KINDS) do
	local k, page = kind[1], 'Sparkle: Looks'
	local add = function(def) def.page = page; ns.settings[#ns.settings + 1] = def end
	add({ header = true, name = (kind[2]:gsub('^Sparkle: ', '')) })
	add({ key = 'look.' .. k .. '.effect', default = kind[4], name = 'Effect', choices = EFFECTS,
		desc = 'Sparkle effect.' })
	add({ key = 'look.' .. k .. '.colour', colour = true, default = kind[3], name = 'Color',
		desc = 'Color of the sparkle (and of the name, when names are colored by object type).' })
	add({ key = 'look.' .. k .. '.size', default = 110, min = 40, max = 260, step = 10, name = 'Size',
		desc = 'Size of the sparkle.' })
	add({ key = 'look.' .. k .. '.bright', default = 100, min = 20, max = 100, step = 5, name = 'Brightness',
		desc = 'Brightness of the sparkle, in percent.' })
	add({ key = 'look.' .. k .. '.height', default = -40, min = -160, max = 100, step = 5, name = 'Vertical Offset',
		desc = 'Position of the sparkle above (positive) or below (negative) the nameplate, which floats a little above the object.' })
	add({ key = 'look.' .. k .. '.speed', default = 100, min = 25, max = 300, step = 25, name = 'Animation Speed',
		desc = 'Animation speed, in percent.' })
	add({ button = 'Test', name = 'Preview Sparkle', click = function() ns.SparkleTest(k) end,
		desc = 'Preview this sparkle in the middle of the screen for a few seconds.' })
end
-- the sparkle fading where it comes over your character
do
	local page = 'Sparkle: Behind My Character'
	local add = function(def) def.page = page; ns.settings[#ns.settings + 1] = def end
	add({ voice = 'Patchwerk is wide. Things hide behind Patchwerk.' })
	add({ key = 'sparkleBehind', default = false, name = 'Fade Behind Character',
		desc = 'Fade the sparkle and name when they overlap your character on screen. Addons cannot draw behind your character, so this approximates it from the camera distance; the sliders below adjust it and the button previews it.' })
	add({ key = 'sparkleBehindLeft', default = 0, min = 0, max = 80, step = 5, name = 'Minimum Opacity',
		desc = 'Opacity of the sparkle when it is directly over your character, in percent. 0 hides it.' })
	add({ key = 'sparkleBehindSize', default = 100, min = 40, max = 300, step = 10, name = 'Character Height',
		desc = 'Assumed on-screen height of your character, in percent. Increase it for a tall character or a mount.' })
	add({ key = 'sparkleBehindWide', default = 50, min = 20, max = 200, step = 10, name = 'Character Width',
		desc = 'Assumed width of your character, in percent of its height.' })
	add({ key = 'sparkleBehindAcross', default = 0, min = -40, max = 40, step = 1, name = 'Horizontal Offset',
		desc = 'Move the fade area left (negative) or right, in percent of screen width. For cameras that keep your character off-center.' })
	add({ key = 'sparkleBehindUp', default = 0, min = -40, max = 40, step = 1, name = 'Vertical Offset',
		desc = 'Move the fade area down (negative) or up, in percent of screen height.' })
	add({ button = 'Show', name = 'Preview Area', click = function() ns.SparkleBehindShow() end,
		desc = 'Show the fade area as an oval for ten seconds. It should surround your character, and it follows the camera as you zoom.' })
end

---------------------------------------------------------------------------
-- /sparkle
---------------------------------------------------------------------------
local function Help()
	ns.Print('Sparkle commands:')
	ns.Print('  /sparkle: show the object currently targeted for interaction, and why it does or does not sparkle')
	ns.Print('  /sparkle ignore: add the targeted object to the ignore list')
	ns.Print('  /sparkle undo: undo the last ignore;  /sparkle list: show the ignore list;  /sparkle clear: clear it')
	ns.Print('  /sparkle config: open the options')
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
			ns.Print('Options are under Options > AddOns > Patchwerk Forever > Thread: Sparkle.')
		end
	else
		Help()
	end
end

-- For key and gamepad bindings (Bindings.xml).
BINDING_HEADER_PATCHWERKFOREVER_SPARKLE = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_SPARKLE_IGNORE = 'Ignore Targeted Object'
function PatchwerkForever_Thread_Sparkle_Ignore() ns.Try('ignore', ns.IgnoreThis) end
