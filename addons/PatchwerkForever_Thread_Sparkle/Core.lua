-- Sparkle (Thread): its settings and the slash command.
local ADDON, ns = ...
if not ns.linked then return end

ns.TITLE = 'Patchwerk Forever: Sparkle (Thread)'
ns.BINDING = 'Ignore / Unignore Sparkle Object'     -- the key binding's name, as the game shows it

---------------------------------------------------------------------------
-- Settings: kept in PatchwerkForever_Thread_SparkleDB.settings
---------------------------------------------------------------------------
-- One entry a setting, in the order they are shown. The base makes the pages from this list and
-- says what each kind of entry becomes (its Tools.lua). page: the page it is on (none: the first,
-- "Sparkle (Thread)"). parent: grayed out while that tick box is off. percent: the slider's value
-- is shown as a percentage.
local EFFECTS = {
	{ 'star', 'Star' }, { 'glow', 'Soft Glow' }, { 'ring', 'Pulsing Ring' }, { 'beam', 'Light Beam' },
	{ 'swirl', 'Swirl' }, { 'brackets', 'Brackets' },
	{ 'glints', 'Subtle: Glints' }, { 'fireflies', 'Subtle: Fireflies' }, { 'shimmer', 'Subtle: Faint Shimmer' },
	{ 'ripple', 'Subtle: Ground Ripple' }, { 'wisp', 'Subtle: Wisp' },
	{ 'leaves', 'Themed: Falling Leaves' }, { 'embers', 'Themed: Embers' }, { 'coins', 'Themed: Coin Glints' },
	{ 'rays', 'Themed: Sun Rays' },
	{ 'none', 'None (Name Only)' },
}
-- the kinds of thing that can sparkle: key, its heading, its color and its effect to begin with, whether
-- it has a Show tick box of its own on the Appearance page (corpses have theirs on the first page), and
-- other starting values where they differ ('loot' is a chest; 'questcorpse' a corpse with loot for you
-- that belongs to one of your quests; 'corpse' any other with loot for you; 'skin' one you can skin;
-- 'waypoint' the game's own marker on the quest you track or your map pin)
ns.KINDS = {
	{ 'herb', 'Herbs', 'ff73ff73', 'star', true },
	{ 'ore', 'Ore', 'ffff9e33', 'star', true },
	{ 'loot', 'Chests', 'ff80ccff', 'glow', true },
	{ 'quest', 'Quest Objects', 'ffffd933', 'ring', true },
	{ 'questcorpse', 'Quest Corpses', 'ffffb84d', 'ring', true },
	{ 'corpse', 'Corpses With Loot', 'ffff7373', 'glow', false },
	{ 'skin', 'Skinnable Corpses', 'ffcc99ff', 'star', false },
	{ 'other', 'Other Objects', 'ffebebf5', 'glow', true },
	{ 'waypoint', 'Waypoint', 'ff66ddff', 'beam', true, { size = 140, height = 0 } },
}
local COLOR_MODES = { { 'kind', 'By Object Type' }, { 'fixed', 'Single Color' } }
-- the sounds an alert can play: the game's own (by its names for them, in SOUNDKIT), none of them copied
ns.SOUNDS = {
	{ 'none', 'None' }, { 'ping', 'Map Ping' }, { 'chime', 'Whisper Chime' }, { 'coins', 'Coins' },
	{ 'page', 'Page Turn' }, { 'chain', 'Chain' },
}
-- Whether the base can put a list on a page (base 2.9.0, its API 6): without it the lists are left out
-- and the chat commands do their work.
local LISTS = type(ns.Base) == 'table' and (tonumber(ns.Base.API) or 0) >= 6

ns.settings = {
	{ key = 'sparkle', default = true, name = 'Enable Sparkles',
		desc = 'Show a sparkle on the nearest herb, ore node, chest, quest object or corpse with loot as you approach it. While enabled, two game settings are turned on to give objects a nameplate (and a third with Sparkle With Keyboard And Mouse); they are put back when you disable this or log out.' },
	{ key = 'sparkleKeyboard', default = true, name = 'Sparkle With Keyboard And Mouse', parent = 'sparkle',
		desc = 'Turn on the game\'s Enable Interact Key (Options > Controls) while sparkles are enabled. Without it the game only picks an object for a gamepad, so nothing sparkles with keyboard and mouse. It is put back when you disable this or log out. Gamepad play is not changed.' },
	{ key = 'sparkleAll', default = false, name = 'Include All Interactable Objects', parent = 'sparkle',
		desc = 'Also show sparkles on mailboxes, doors, anvils and similar objects.' },
	{ key = 'sparkleCorpse', default = true, name = 'Sparkle On Corpses With Loot', parent = 'sparkle',
		desc = 'Show a sparkle on a corpse that has loot for you, when the game\'s interact key targets it.' },
	{ key = 'sparkleSkin', default = true, name = 'Sparkle On Skinnable Corpses', parent = 'sparkle',
		desc = 'Show a sparkle on a corpse you can skin, when the game\'s interact key targets it. Only for a character who has Skinning.' },
	{ key = 'sparkleCannot', default = 'show', name = 'Herbs And Ore I Cannot Gather', parent = 'sparkle',
		choices = { { 'show', 'Show' }, { 'dim', 'Dim' }, { 'hide', 'Hide' } },
		desc = 'Show, dim or hide the sparkle and name on herbs when your character does not have Herbalism, and on ore when it does not have Mining. Skill level is not checked.' },
	{ key = 'sparkleReach', default = 'game', name = 'Sparkle Distance', parent = 'sparkle',
		choices = { { 'game', 'Game Default' }, { '15', '15 Yards' }, { '20', '20 Yards' }, { '30', '30 Yards' }, { '40', '40 Yards' } },
		desc = 'How far away the game picks an object for the interact key, and so how far away a sparkle can show. Only ever raises the game\'s own setting (SoftTargetInteractRange), which is put back when you disable this or log out. You still have to walk up to an object to use it, and the game may cap the distance.' },
	{ key = 'sparkleNear', default = true, name = 'Brighter When Near', parent = 'sparkle',
		desc = 'The sparkle grows brighter as you come nearer: faint at the far edge of Sparkle Distance, full brightness up close. For herbs and ore this needs Patchwerk Forever: Routes (Thread), which knows where the nodes you have gathered are; for the waypoint the game gives the distance.' },
	{ key = 'sparkleGathering', default = true, name = 'Fade While Gathering', parent = 'sparkle',
		desc = 'Fade the sparkle and name while you gather from, open or loot the object, so it does not cover what you are doing.' },
	{ key = 'sparkleCombat', default = false, name = 'Hide In Combat', parent = 'sparkle',
		desc = 'Hide sparkles and names while you are in combat.' },
	{ key = 'sparkleInstance', default = false, name = 'Hide In Instances', parent = 'sparkle',
		desc = 'Hide sparkles and names in dungeons, raids and battlegrounds.' },
	{ button = 'Apply', name = 'Apply Subtle Preset', click = function() ns.SparkleSubtle() end,
		desc = 'Set every object type to a subtle effect: glints on herbs, ore and skinnable corpses, a faint shimmer on chests and corpses with loot, a ground ripple on quest objects and quest corpses, fireflies on the rest, a light beam on the waypoint. Only the effect changes; your colors and sizes are kept.' },
	{ button = 'Apply', name = 'Apply Themed Preset', click = function() ns.SparkleThemed() end,
		desc = 'Set every object type to an effect drawn for it: falling leaves on herbs and skinnable corpses, embers on ore, coin glints on chests and corpses with loot, sun rays on quest objects and quest corpses, a soft glow on the rest, a light beam on the waypoint. Only the effect changes; your colors and sizes are kept.' },

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
ns.settings[#ns.settings + 1] = { page = ns.APPEARANCE, button = 'Preview', name = 'Preview All Types', click = function() ns.SparkleTestAll() end,
	desc = 'Preview every object type\'s sparkle side by side for a few seconds, so you can compare them.' }
-- (what each kind is called in a sentence: "a sparkle on herbs")
local SAID = { herb = 'herbs', ore = 'ore', loot = 'chests', quest = 'quest objects', questcorpse = 'corpses with loot for one of your quests',
	other = 'other objects (and, with Include All Interactable Objects, mailboxes, doors and the like)',
	waypoint = 'the game\'s waypoint marker, on the quest you track or your map pin' }
for _, kind in ipairs(ns.KINDS) do
	local k, start = kind[1], kind[6] or {}
	local add = function(def) def.page = ns.APPEARANCE; ns.settings[#ns.settings + 1] = def end
	local show = kind[5] and ('look.' .. k .. '.show') or nil
	add({ header = true, name = kind[2] })
	if show then
		add({ key = show, default = true, name = 'Show',
			desc = 'Show a sparkle and name on ' .. (SAID[k] or k) .. '.' })
	end
	add({ key = 'look.' .. k .. '.effect', default = kind[4], name = 'Effect', choices = EFFECTS, parent = show,
		desc = 'Sparkle effect.' })
	add({ key = 'look.' .. k .. '.colour', colour = true, default = kind[3], name = 'Color', parent = show,
		desc = 'Color of the sparkle (and of the name, when names are colored by object type).' })
	add({ key = 'look.' .. k .. '.size', default = start.size or 110, min = 40, max = 260, step = 10, name = 'Size', parent = show,
		desc = 'Size of the sparkle.' })
	add({ key = 'look.' .. k .. '.bright', default = 100, min = 20, max = 100, step = 5, name = 'Brightness', percent = true, parent = show,
		desc = 'Brightness of the sparkle.' })
	add({ key = 'look.' .. k .. '.height', default = start.height or -40, min = -160, max = 100, step = 5, name = 'Vertical Offset', parent = show,
		desc = k == 'waypoint' and 'Position of the sparkle above (positive) or below (negative) the game\'s waypoint marker.'
			or 'Position of the sparkle above (positive) or below (negative) the nameplate, which floats a little above the object.' })
	add({ key = 'look.' .. k .. '.speed', default = 100, min = 25, max = 300, step = 25, name = 'Animation Speed', percent = true, parent = show,
		desc = 'How fast the sparkle moves.' })
	add({ key = 'look.' .. k .. '.sound', default = 'none', name = 'Alert Sound', choices = ns.SOUNDS, parent = show,
		desc = 'A sound the game plays when this kind of sparkle appears, once for each object (the same object again only after half a minute). Rumble On Gamepad is on Sparkle: Alerts.' })
	add({ button = 'Test', name = 'Preview Sparkle', click = function() ns.SparkleTest(k) end,
		desc = 'Preview this sparkle for a few seconds, beside the options window when there is room, and play its alert sound. The preview also follows the settings as you change them.' })
	add({ button = 'Copy', name = 'Use This Look For All', click = function() ns.SparkleCopyLook(k) end,
		desc = 'Give every other object type this effect, size, brightness, vertical offset and animation speed. Each type keeps its own color, alert sound and Show setting, and the waypoint its own vertical offset.' })
end

-- alerts: rumble (the sounds are set for each kind on the Appearance page), threat (Threat.lua) and
-- fishing (Fish.lua)
do
	local page = 'Sparkle: Alerts'
	local add = function(def) def.page = page; ns.settings[#ns.settings + 1] = def end
	add({ voice = 'Patchwerk feels a shiny thing in his hands before he sees it.' })
	add({ key = 'cueRumble', default = false, name = 'Rumble On Gamepad',
		desc = 'Rumble the gamepad when a sparkle appears, once for each object. Only while a gamepad is in use.' })
	add({ key = 'cueRumbleFor', default = 'alert', name = 'Rumble For', parent = 'cueRumble',
		choices = { { 'alert', 'Types With An Alert Sound' }, { 'all', 'Every Sparkle' } },
		desc = 'Types With An Alert Sound: only the object types whose Alert Sound (Sparkle: Appearance) is not None. Every Sparkle: all of them.' })
	add({ key = 'cueRumbleStrength', default = 50, min = 10, max = 100, step = 10, name = 'Rumble Strength', parent = 'cueRumble', percent = true,
		desc = 'How strong the rumble is.' })
	add({ button = 'Test', name = 'Preview Rumble', click = function() ns.CueTest() end,
		desc = 'Rumble the gamepad once, as a sparkle would.' })
	add({ header = true, name = 'Threat' })
	add({ key = 'threatRumble', default = false, name = 'Rumble When I Pull Threat',
		desc = 'Rumble the gamepad twice, short, when an enemy turns to attack you: you took it from your tank, or it came for you first. Several at once rumble once. Only while a gamepad is in use.' })
	add({ key = 'threatStrength', default = 80, min = 10, max = 100, step = 10, name = 'Threat Rumble Strength', parent = 'threatRumble', percent = true,
		desc = 'How strong the threat rumble is.' })
	add({ key = 'threatSound', default = 'none', name = 'Threat Alert Sound', choices = ns.SOUNDS,
		desc = 'A sound the game plays when an enemy turns to attack you, with or without a gamepad.' })
	add({ key = 'threatWhen', default = 'group', name = 'Alert For Threat',
		choices = { { 'group', 'In A Group, Not As A Tank' }, { 'always', 'Always' } },
		desc = 'In A Group, Not As A Tank: only in a party or raid, and not while your group role is Tank, where pulling threat is a warning. Always: solo too, each time an enemy comes for you.' })
	add({ button = 'Test', name = 'Preview Threat Alert', click = function() ns.ThreatTest() end,
		desc = 'Play the threat alert once: the sound, and the rumble.' })
	add({ header = true, name = 'Fishing' })
	add({ key = 'fishLoud', default = false, name = 'Louder Splash While Fishing',
		desc = 'While you fish, turn sound effects up and music and ambience down, so the splash of a bite is easy to hear. They are put back after the cast; a volume you change while fishing is kept. (The game does not tell addons when a fish bites, so the bite itself cannot be shown or rumbled.)' })
	add({ key = 'fishEffects', default = 100, min = 50, max = 100, step = 10, name = 'Sound Effects Volume', parent = 'fishLoud', percent = true,
		desc = 'The game\'s sound effects volume while you fish. Only ever raised: a higher volume of your own is kept. Sound effects are turned on while you fish if they are off.' })
	add({ key = 'fishBackground', default = 0, min = 0, max = 100, step = 10, name = 'Music And Ambience Volume', parent = 'fishLoud', percent = true,
		desc = 'Music and ambience while you fish, as a share of their own volume. 0% silences them.' })
	add({ key = 'fishRumble', default = false, name = 'Rumble When The Bobber Lands',
		desc = 'Rumble the gamepad once when your bobber lands within reach of the interact key, as strong as Rumble Strength. Only while a gamepad is in use.' })
end

-- the ignore list, with a Remove button for each object on it
do
	local page = 'Sparkle: Ignore List'
	local add = function(def) def.page = page; ns.settings[#ns.settings + 1] = def end
	add({ voice = 'Patchwerk has seen enough mailboxes for one lifetime.' })
	if LISTS then
		add({ list = function() return ns.IgnoreRows() end, name = 'Ignored Objects',
			empty = 'Nothing is ignored. To ignore an object, walk up to it and press the "' .. ns.BINDING .. '" key binding, or type /sparkle ignore.',
			desc = 'Objects and corpses that never sparkle.' })
	end
	add({ button = 'Clear', name = 'Clear Ignore List', click = function() ns.IgnoreClearAsk() end,
		desc = 'Ignored objects never sparkle. To ignore one, walk up to it and press the "' .. ns.BINDING .. '" key binding, or type /sparkle ignore. This button clears the whole list, after asking.' })
end

-- chests and nodes you came near and did not take (Passed.lua)
do
	local page = 'Sparkle: Passed'
	local add = function(def) def.page = page; ns.settings[#ns.settings + 1] = def end
	add({ voice = 'Patchwerk walked past a chest once. Patchwerk does not walk past chests now.' })
	add({ key = 'passed', default = true, name = 'Remember What I Pass',
		desc = 'Remember the chests, herbs and ore that sparkled and that you walked away from without opening or gathering them, and where you were. Nothing leaves your computer.' })
	add({ key = 'passedRoutes', default = true, name = 'Share Herb And Ore Spots With Routes', parent = 'passed',
		desc = 'Give the herbs and ore you pass to Patchwerk Forever: Routes (Thread), so they show on its maps with the ones you have gathered and a gathering run can go to them. The spot is where you stood, a few yards from the node. Needs Routes (Thread) 1.4.0 and Patchwerk Forever 2.9.0 or later.' })
	if LISTS then
		add({ list = function() return ns.PassedRows() end, name = 'Passed',
			empty = 'Nothing passed yet. Chests, herbs and ore that sparkle and that you walk away from are listed here, nearest first.',
			desc = 'What you passed, nearest first. Add To Route puts it on My Route, which Routes (Thread) leads you along and Tracker (Thread) lists.' })
	end
	add({ button = 'Forget', name = 'Forget Everything Passed', click = function() ns.PassedClear() end,
		desc = 'Empty the list of what you passed.' })
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
		desc = 'Assumed on-screen height of your character. Increase it for a tall character.' })
	add({ key = 'sparkleBehindMount', default = 160, min = 40, max = 400, step = 10, name = 'Character Height On Mount', parent = 'sparkleBehind', percent = true,
		desc = 'Assumed on-screen height of your character while mounted, used in place of Character Height.' })
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
	add({ key = 'wispColour', default = 'kind', name = 'Color Mode', parent = 'wisp',
		choices = { COLOR_MODES[1], { 'quality', 'By Item Quality' }, COLOR_MODES[2] },
		desc = 'By Object Type: like the sparkle of the object or corpse it came from (green from an herb, orange from ore, and so on). By Item Quality: the item\'s quality color (green, blue, purple), and quest items in the Quest Objects color. Single Color: one color for all. An item whose origin or quality is not known uses the single color.' })
	add({ key = 'wispFixed', colour = true, default = 'ffffe680', name = 'Wisp Color', parent = 'wisp',
		desc = 'Color of the wisp when Color Mode is Single Color, or when the item\'s origin or quality is not known.' })
	add({ key = 'wispRare', default = true, name = 'Celebrate Rare Loot', parent = 'wisp',
		desc = 'A Rare item or better flies with a bigger wisp, and the bag flares as it lands.' })
	add({ key = 'wispMoney', default = true, name = 'Coins Fly To Your Bag', parent = 'wisp',
		desc = 'Money you loot flies to your backpack as a small gold wisp.' })
	add({ key = 'wispQuest', default = true, name = 'Quest Items Fly To The Tracker', parent = 'wisp',
		desc = 'A quest item you loot flies to its quest in the quest tracker (Tracker (Thread)\'s, or the game\'s) in place of your bag, and the quest\'s line lights up as its count goes up.' })
	add({ button = 'Test', name = 'Preview Wisp', click = function() ns.WispTest() end,
		desc = 'Send a wisp from the middle of the screen to your backpack.' })
end

---------------------------------------------------------------------------
-- /sparkle
---------------------------------------------------------------------------
local function Help()
	ns.Print('Sparkle commands (/sparkle or /pfs):')
	ns.Print('  /sparkle status: show the targeted object or corpse, and why it does or does not sparkle')
	ns.Print('  /sparkle ignore: add the targeted object to the ignore list')
	ns.Print('  /sparkle undo: take the last ignore back')
	ns.Print('  /sparkle list: show the ignore list')
	ns.Print('  /sparkle clear: clear the ignore list')
	ns.Print('  /sparkle wisp: preview a loot wisp, and say whether they are shown')
	ns.Print('  /sparkle passed: list the chests, herbs and ore you passed, nearest first')
	ns.Print('  /sparkle passed route: add the nearest chest you passed to My Route')
	ns.Print('  /sparkle debug: show the game settings, professions and tooltip Sparkle reads, for a bug report')
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
	elseif word == 'passed' then
		if rest == 'route' then
			ns.Try('what you passed', ns.PassedRoute)
		elseif rest == 'clear' or rest == 'forget' then
			ns.Try('what you passed', ns.PassedClear)
		else
			ns.Try('what you passed', ns.PassedSay)
		end
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not ns.OpenSettings() then
			ns.Print(InCombatLockdown() and 'Options cannot be opened in combat.'
				or 'Options are under Options > AddOns > Patchwerk Forever > Sparkle (Thread).')
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
