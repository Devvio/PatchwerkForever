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
	{ key = 'globeLight', default = true, name = 'Shade The Globe',
		desc = 'Darken the globe a little toward its edge, as a ball is.' },
	{ key = 'globeStats', default = true, name = 'Show Drawing Numbers',
		desc = 'Show under the globe how many map pieces are drawn and how long drawing them takes. For trying the prototype.' },
	{ button = 'Open', name = 'Open The Globe', click = function() ns.Toggle(true) end,
		desc = 'Open the globe window. /globe does the same.' },
}

local function Help()
	ns.Print('Globe commands (/globe or /pfg):')
	ns.Print('  /globe: open or close the globe')
	ns.Print('  /globe me: open it turned to where you are')
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
