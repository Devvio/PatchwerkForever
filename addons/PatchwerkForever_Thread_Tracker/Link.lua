-- Thread (Tracker): joining the base.
--
-- This addon is one of Patchwerk Forever's own tools. The base (the addon Patchwerk Forever) gives a
-- tool its chat lines, its events, its settings and their pages under Patchwerk Forever's in the
-- game's options: ns.Print, ns.Try, ns.On, ns.Get, ns.Set, ns.OnSetting, ns.RGB, ns.OpenSettings.
-- It also reads the guide you are running, for the guide's steps (ns.Base.Guides), asks for
-- gathering runs where Thread (Routes) offers them (ns.Base.Gather), and shows and changes the focus
-- and My Route (ns.Base.Focus, ns.Base.MyRoute).
-- Without a base new enough ns.linked stays unset, and the files after this one do nothing.
local ADDON, ns = ...

local Base = rawget(_G, 'PatchwerkForever')
if not (type(Base) == 'table' and type(Base.Tool) == 'function' and Base:Tool(ADDON, ns, {
	api = 5,                                        -- the base's API this tool was written for (5: the focus, My Route, a choice's callbacks)
	name = 'Tracker',
	colour = 'ff5fe0c8',
	saved = 'PatchwerkForever_Thread_TrackerDB',
	page = 'Thread: Tracker',
	slash = '/tracker',
})) then
	print('|cffd6a35bPatchwerk|r ' .. ADDON .. ' needs a newer Patchwerk Forever (the base addon). It is not running.')
end
