-- Tracker (Thread): joining the base.
--
-- This addon is one of Patchwerk Forever's own tools. The base (the addon Patchwerk Forever) gives a
-- tool its chat lines, its events, its settings and their pages under Patchwerk Forever's in the
-- game's options: ns.Print, ns.Try, ns.On, ns.Get, ns.Set, ns.OnSetting, ns.RGB, ns.OpenSettings.
-- It also reads the guide you are running, for the guide's steps (ns.Base.Guides), asks for
-- gathering runs where Routes (Thread) offers them (ns.Base.Gather), and shows and changes the focus
-- and My Route (ns.Base.Focus, ns.Base.MyRoute).
-- Without a base new enough ns.linked stays unset, and the files after this one do nothing.
local ADDON, ns = ...

local API = 5             -- the base's API this tool was written for (5: the focus, My Route, a choice's callbacks)
local NEEDS = '2.6.0'     -- the first base with that API

local Base = rawget(_G, 'PatchwerkForever')
if not (type(Base) == 'table' and type(Base.Tool) == 'function' and Base:Tool(ADDON, ns, {
	api = API,
	name = 'Tracker',
	colour = 'ff5fe0c8',
	saved = 'PatchwerkForever_Thread_TrackerDB',
	page = 'Tracker (Thread)',
	slash = '/tracker',
})) then
	-- (named as the addon list shows it, with its version, and the base it needs)
	local meta = C_AddOns and C_AddOns.GetAddOnMetadata
	local function Meta(field)
		if type(meta) ~= 'function' then return nil end
		local ok, value = pcall(meta, ADDON, field)
		return ok and type(value) == 'string' and value ~= '' and value or nil
	end
	local title = (Meta('Title') or ADDON):gsub('^Patchwerk Forever:%s*', '')
	local version = Meta('Version')
	print(('|cffd6a35bPatchwerk:|r %s%s needs Patchwerk Forever %s or later and is not running. Update Patchwerk Forever.')
		:format(title, version and (' ' .. version) or '', NEEDS))
end
