-- Thread (Routes): choosing the focus.
--
-- The focus (kept by the base: its Focus.lua) is what the route follows by itself: Auto (your guide or
-- your quests, by the Priority setting), one guide's list (RestedXP, the Dungeon Journal, My Route) or
-- your tracked quests only. How it is followed is Sources.lua's; here it is chosen: /thread focus, the
-- key bindings (Bindings.xml, named in Core.lua) and the world map's focus button (MapRoute.lua).
local ADDON, ns = ...
if not ns.linked then return end

-- what may be typed after /thread focus, and the focus each one means
local WORDS = {
	auto = 'auto',
	rxp = 'rxp', restedxp = 'rxp', guide = 'rxp',
	dj = 'fdj', fdj = 'fdj', journal = 'fdj', dungeonjournal = 'fdj',
	quests = 'quests', quest = 'quests',
	route = 'route', myroute = 'route',
}
-- the names of the focuses we know, for one whose addon is not running (the base names only those it has)
local NAMES = { auto = 'Auto', rxp = 'RestedXP', fdj = 'Dungeon Journal', quests = 'Quests', route = 'My Route' }

local function Focus()
	local focus = ns.Base.Focus
	if type(focus) == 'table' and type(focus.Get) == 'function' then return focus end
	return nil
end

-- The name of a focus, as shown.
function ns.FocusName(id)
	local focus = Focus()
	local ok, name = false, nil
	if focus then ok, name = pcall(focus.Name, focus, id) end
	if ok and type(name) == 'string' and name ~= id then return name end
	return NAMES[id] or tostring(id)
end

-- What can be chosen now: { { id =, name = }, ... }, Auto first.
function ns.FocusList()
	local focus = Focus()
	local ok, list = false, nil
	if focus then ok, list = pcall(focus.Available, focus) end
	return ok and type(list) == 'table' and list or { { id = 'auto', name = 'Auto' } }
end

function ns.FocusGet()
	local focus = Focus()
	return focus and focus:Get() or 'auto'
end

local function Available(id)
	for _, one in ipairs(ns.FocusList()) do
		if one.id == id then return true end
	end
	return false
end

-- Makes `id` the focus. say: tell it in chat (a command). Returns true when it is the focus now.
-- (The step text says "Following: <name>" by itself: Sources.lua.)
function ns.FocusTo(id, say)
	local focus = Focus()
	if not focus then return false end
	if not Available(id) then
		ns.Print(('%s is not available now.'):format(ns.FocusName(id)))
		return false
	end
	if not focus:Set(id) then return false end
	if say then ns.Print(('Focus: %s.'):format(ns.FocusName(id))) end
	return true
end

-- The next of the focuses that can be chosen (the Next Focus key).
function ns.FocusNext()
	local focus = Focus()
	if focus then ns.FocusTo(focus:Next()) end
end

-- /thread focus: which focus is in use and what can be chosen. /thread focus <name>: chooses it.
function ns.FocusSay(rest)
	rest = (rest or ''):lower():gsub('[%s_%-]', '')
	if rest == '' then
		local names = {}
		for _, one in ipairs(ns.FocusList()) do names[#names + 1] = one.name end
		ns.Print(('Focus: %s. Available: %s.'):format(ns.FocusName(ns.FocusGet()), table.concat(names, ', ')))
		ns.Print('Change it with /thread focus auto, rxp, dj, quests or route.')
		return
	end
	local id = WORDS[rest]
	if not id then
		-- (any other guide reader, by its id or its name)
		for _, one in ipairs(ns.FocusList()) do
			if one.id:lower() == rest or tostring(one.name):lower():gsub('[%s_%-]', '') == rest then id = one.id end
		end
	end
	if not id then
		ns.Print(('Unknown focus "%s". Use /thread focus auto, rxp, dj, quests or route.'):format(rest))
		return
	end
	ns.FocusTo(id, true)
end
