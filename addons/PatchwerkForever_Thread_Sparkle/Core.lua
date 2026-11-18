-- Thread (Sparkle): its settings and the slash command.
local ADDON, ns = ...
if not ns.linked then return end

ns.TITLE = 'Patchwerk Forever: Thread (Sparkle)'
ns.BINDING = 'Ignore / Unignore Sparkle Object'     -- the key binding's name, as the game shows it

---------------------------------------------------------------------------
-- Settings: kept in PatchwerkForever_Thread_SparkleDB.settings
---------------------------------------------------------------------------
-- One entry a setting, in the order they are shown. The base makes the pages from this list and
-- says what each kind of entry becomes (its Tools.lua). page: the page it is on (none: the first,
-- "Thread: Sparkle"). parent: grayed out while that tick box is off. percent: the slider's value
-- is shown as a percentage.
local EFFECTS = {
	{ 'star', 'Star' }, { 'glow', 'Soft Glow' }, { 'ring', 'Pulsing Ring' }, { 'beam', 'Light Beam' },
	{ 'swirl', 'Swirl' }, { 'brackets', 'Brackets' },
	{ 'glints', 'Subtle: Glints' }, { 'fireflies', 'Subtle: Fireflies' }, { 'shimmer', 'Subtle: Faint Shimmer' },
	{ 'ripple', 'Subtle: Ground Ripple' }, { 'wisp', 'Subtle: Wisp' },
	{ 'none', 'None (Name Only)' },
}
-- the kinds of thing that can sparkle: key, its heading, its color and its effect to begin with
ns.KINDS = {
	{ 'herb', 'Herbs', 'ff73ff73', 'star' },
	{ 'ore', 'Ore', 'ffff9e33', 'star' },
	{ 'loot', 'Chests', 'ff80ccff', 'glow' },
	{ 'quest', 'Quest Objects', 'ffffd933', 'ring' },
	{ 'other', 'Other Objects', 'ffebebf5', 'glow' },
}
local COLOR_MODES = { { 'kind', 'By Object Type' }, { 'fixed', 'Single Color' } }

ns.settings = {
	{ key = 'sparkle', default = true, name = 'Enable Sparkles',
		desc = 'Show a sparkle on the nearest herb, ore node, chest or quest object as you approach it. While enabled, two game settings are turned on to give objects a nameplate; they are put back when you disable this or log out.' },
	{ key = 'sparkleAll', default = false, name = 'Include All Interactable Objects', parent = 'sparkle',
		desc = 'Also show sparkles on mailboxes, doors, anvils and similar objects.' },
	{ key = 'sparkleCombat', default = false, name = 'Hide In Combat', parent = 'sparkle',
		desc = 'Hide sparkles and names while you are in combat.' },
	{ key = 'sparkleInstance', default = false, name = 'Hide In Instances', parent = 'sparkle',
		desc = 'Hide sparkles and names in dungeons, raids and battlegrounds.' },
	{ button = 'Apply', name = 'Apply Subtle Preset', click = function() ns.SparkleSubtle() end,
		desc = 'Set every object type to a subtle effect: glints on herbs and ore, a faint shimmer on chests, a ground ripple on quest objects, fireflies on the rest. Only the effect changes; your colors and sizes are kept.' },
	{ button = 'Clear', name = 'Clear Ignore List', click = function() ns.IgnoreClearAsk() end,
		desc = 'Ignored objects never sparkle. To ignore one, walk up to it and press the "' .. ns.BINDING .. '" key binding, or type /sparkle ignore. This button clears the whole list, after asking.' },

	-- the name written over the object
	{ page = 'Sparkle: Names', voice = 'Patchwerk likes to know what a thing is before he picks it up.' },
	{ page = 'Sparkle: Names', key = 'sparkleName', default = true, name = 'Show Object Name',
		desc = 'Show the name of the object next to it.' },
	{ page = 'Sparkle: Names', key = 'nameSize', default = 13, min = 8, max = 32, step = 1, name = 'Font Size', parent = 'sparkleName',
		desc = 'Font size of the name.' },
	{ page = 'Sparkle: Names', key = 'nameFont', default = 'game', name = 'Font', parent = 'sparkleName',
		choices = { { 'game', 'Default' }, { 'friz', 'Friz Quadrata' }, { 'arial', 'Arial Narrow' },
			{ 'morpheus', 'Morpheus' }, { 'skurri', 'Skurri' } },
		desc = 'Font of the name.' },
	{ page = 'Sparkle: Names', key = 'nameOutline', default = 'thin', name = 'Outline', parent = 'sparkleName',
		choices = { { 'none', 'None' }, { 'thin', 'Thin' }, { 'thick', 'Thick' } },
		desc = 'Outline around the text, for readability.' },
	{ page = 'Sparkle: Names', key = 'nameColour', default = 'kind', name = 'Color Mode', parent = 'sparkleName',
		choices = COLOR_MODES,
		desc = 'Color names by object type (green for herbs, orange for ore, and so on) or use a single color for all.' },
	{ page = 'Sparkle: Names', key = 'nameFixed', colour = true, default = 'ffffffff', name = 'Name Color', parent = 'sparkleName',
		desc = 'Color of all names when Color Mode is set to Single Color.' },
	{ page = 'Sparkle: Names', key = 'namePlace', default = 'below', name = 'Position', parent = 'sparkleName',
		choices = { { 'below', 'Below Icon' }, { 'above', 'Above Icon' } },
		desc = 'Where the name appears.' },
	{ page = 'Sparkle: Names', key = 'nameOffset', default = 14, min = 0, max = 80, step = 2, name = 'Offset', parent = 'sparkleName',
		desc = 'Distance of the name from the nameplate (Below Icon) or from the game\'s icon (Above Icon).' },
	{ page = 'Sparkle: Names', button = 'Test', name = 'Preview Name', click = function() ns.SparkleTest('herb') end,
		desc = 'Preview the name on a sparkle for a few seconds. The preview also follows the settings as you change them.' },
}
-- each kind of object: how its sparkle looks (one page for all of them, a heading for each kind)
ns.APPEARANCE = 'Sparkle: Appearance'
ns.settings[#ns.settings + 1] = { page = ns.APPEARANCE, voice = 'Every shiny thing gets a shine of its own. Patchwerk is fair.' }
for _, kind in ipairs(ns.KINDS) do
	local k = kind[1]
	local add = function(def) def.page = ns.APPEARANCE; ns.settings[#ns.settings + 1] = def end
	add({ header = true, name = kind[2] })
	add({ key = 'look.' .. k .. '.effect', default = kind[4], name = 'Effect', choices = EFFECTS,
		desc = 'Sparkle effect.' })
	add({ key = 'look.' .. k .. '.colour', colour = true, default = kind[3], name = 'Color',
		desc = 'Color of the sparkle (and of the name, when names are colored by object type).' })
	add({ key = 'look.' .. k .. '.size', default = 110, min = 40, max = 260, step = 10, name = 'Size',
		desc = 'Size of the sparkle.' })
	add({ key = 'look.' .. k .. '.bright', default = 100, min = 20, max = 100, step = 5, name = 'Brightness', percent = true,
		desc = 'Brightness of the sparkle.' })
	add({ key = 'look.' .. k .. '.height', default = -40, min = -160, max = 100, step = 5, name = 'Vertical Offset',
		desc = 'Position of the sparkle above (positive) or below (negative) the nameplate, which floats a little above the object.' })
	add({ key = 'look.' .. k .. '.speed', default = 100, min = 25, max = 300, step = 25, name = 'Animation Speed', percent = true,
		desc = 'How fast the sparkle moves.' })
	add({ button = 'Test', name = 'Preview Sparkle', click = function() ns.SparkleTest(k) end,
		desc = 'Preview this sparkle for a few seconds, beside the options window when there is room. The preview also follows the settings as you change them.' })
end
-- the sparkle fading where it comes over your character
do
	local page = 'Sparkle: Behind My Character'
	local add = function(def) def.page = page; ns.settings[#ns.settings + 1] = def end
	add({ voice = 'Patchwerk is wide. Things hide behind Patchwerk.' })
	add({ key = 'sparkleBehind', default = false, name = 'Fade Behind Character',
		desc = 'Fade the sparkle and name when they overlap your character on screen. Addons cannot draw behind your character, so this approximates it from the camera distance; the sliders below adjust it and the button previews it.' })
	add({ key = 'sparkleBehindLeft', default = 0, min = 0, max = 80, step = 5, name = 'Minimum Opacity', parent = 'sparkleBehind', percent = true,
		desc = 'Opacity of the sparkle when it is directly over your character. 0% hides it.' })
	add({ key = 'sparkleBehindSize', default = 100, min = 40, max = 300, step = 10, name = 'Character Height', parent = 'sparkleBehind', percent = true,
		desc = 'Assumed on-screen height of your character. Increase it for a tall character or a mount.' })
	add({ key = 'sparkleBehindWide', default = 50, min = 20, max = 200, step = 10, name = 'Character Width', parent = 'sparkleBehind', percent = true,
		desc = 'Assumed width of your character, in percent of its height.' })
	add({ key = 'sparkleBehindAcross', default = 0, min = -40, max = 40, step = 1, name = 'Horizontal Offset', parent = 'sparkleBehind', percent = true,
		desc = 'Move the fade area left (negative) or right, in percent of screen width. For cameras that keep your character off-center.' })
	add({ key = 'sparkleBehindUp', default = 0, min = -40, max = 40, step = 1, name = 'Vertical Offset', parent = 'sparkleBehind', percent = true,
		desc = 'Move the fade area down (negative) or up, in percent of screen height.' })
	add({ button = 'Show', name = 'Preview Area', click = function() ns.SparkleBehindShow() end,
		desc = 'Show the fade area as an oval. It stays for ten seconds after your last change and for ten seconds after you close the options, so you can compare it with your character. It follows the camera as you zoom.' })
end

-- the wisp that carries what you pick up into your bag (Wisp.lua)
do
	local page = 'Sparkle: Loot Wisps'
	local add = function(def) def.page = page; ns.settings[#ns.settings + 1] = def end
	add({ voice = 'Patchwerk picks a thing up. A little light takes it home to the bag.' })
	add({ key = 'wisp', default = true, name = 'Show Loot Wisps',
		desc = 'When an item goes into your bags, a small wisp of light flies from where it came from to that bag\'s button, and the bag glows as it lands.' })
	add({ key = 'wispWhen', default = 'loot', name = 'Show For', parent = 'wisp',
		choices = { { 'loot', 'Looting And Gathering' }, { 'all', 'Every Item' } },
		desc = 'Looting And Gathering: only items you loot, gather or pick up from an object. Every Item: also items you buy, take from the mail or the bank, trade for or get as a quest reward.' })
	add({ key = 'wispIcon', default = true, name = 'Carry Item Icon', parent = 'wisp',
		desc = 'Show the item\'s icon riding along with the wisp.' })
	add({ key = 'wispCombat', default = false, name = 'Hide In Combat', parent = 'wisp',
		desc = 'Show no wisps while you are in combat.' })
	add({ key = 'wispSize', default = 70, min = 30, max = 160, step = 5, name = 'Size', parent = 'wisp',
		desc = 'Size of the wisp.' })
	add({ key = 'wispSpeed', default = 100, min = 50, max = 250, step = 10, name = 'Speed', parent = 'wisp', percent = true,
		desc = 'How fast the wisp flies. At 100% it takes a little under a second.' })
	add({ key = 'wispColour', default = 'kind', name = 'Color Mode', parent = 'wisp', choices = COLOR_MODES,
		desc = 'Color the wisp like the sparkle of the object it came from (green from an herb, orange from ore, and so on), or use one color for all. Items from a corpse or with no object use the single color.' })
	add({ key = 'wispFixed', colour = true, default = 'ffffe680', name = 'Wisp Color', parent = 'wisp',
		desc = 'Color of the wisp when Color Mode is Single Color, or when the item did not come from an object.' })
	add({ button = 'Test', name = 'Preview Wisp', click = function() ns.WispTest() end,
		desc = 'Send a wisp from the middle of the screen to your backpack.' })
end

---------------------------------------------------------------------------
-- /sparkle
---------------------------------------------------------------------------
local function Help()
	ns.Print('Sparkle commands (/sparkle or /pfs):')
	ns.Print('  /sparkle status: show the targeted object, and why it does or does not sparkle')
	ns.Print('  /sparkle ignore: add the targeted object to the ignore list')
	ns.Print('  /sparkle undo: take the last ignore back')
	ns.Print('  /sparkle list: show the ignore list')
	ns.Print('  /sparkle clear: clear the ignore list')
	ns.Print('  /sparkle wisp: preview a loot wisp, and say whether they are shown')
	ns.Print('  /sparkle debug: show the game settings Sparkle reads, for a bug report')
	ns.Print('  /sparkle config: open the options')
end

SLASH_PATCHWERKFOREVER_SPARKLE1 = '/sparkle'
SLASH_PATCHWERKFOREVER_SPARKLE2 = '/pfs'
SlashCmdList.PATCHWERKFOREVER_SPARKLE = function(text)
	local word, rest = (text or ''):lower():match('^%s*(%S*)%s*(.-)%s*$')
	if word == 'ignore' and rest ~= '' then
		word = rest                                   -- (/sparkle ignore undo, as it was under the route planner)
	end
	-- ('say' and 'sparkle' are the older words for status)
	if word == 'status' or word == 'say' or word == 'sparkle' then
		ns.Try('sparkle', ns.SparkleSay)
	elseif word == 'debug' then
		ns.Try('sparkle', ns.SparkleDebug)
	elseif word == 'ignore' then
		ns.Try('ignore', ns.IgnoreThis)
	elseif word == 'undo' then
		ns.Try('ignore', ns.IgnoreUndo)
	elseif word == 'list' then
		ns.Try('ignore', ns.IgnoreSay)
	elseif word == 'clear' then
		ns.Try('ignore', ns.IgnoreClear)
	elseif word == 'wisp' or word == 'wisps' then
		ns.Try('the loot wisp', ns.WispSay)
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not ns.OpenSettings() then
			ns.Print(InCombatLockdown() and 'Options cannot be opened in combat.'
				or 'Options are under Options > AddOns > Patchwerk Forever > Thread: Sparkle.')
		end
	else
		Help()
	end
end

-- For key and gamepad bindings (Bindings.xml). The binding adds the targeted object to the ignore
-- list, or takes it off again when it is already there.
BINDING_HEADER_PATCHWERKFOREVER_SPARKLE = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_SPARKLE_IGNORE = ns.BINDING
function PatchwerkForever_Thread_Sparkle_Ignore() ns.Try('ignore', ns.IgnoreToggle) end
