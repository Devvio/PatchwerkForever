-- Thread (Sparkle): joining the base.
--
-- This addon is one of Patchwerk Forever's own tools. The base (the addon Patchwerk Forever) gives a
-- tool its chat lines, its events, its settings and their pages under Patchwerk Forever's in the
-- game's options: ns.Print, ns.Try, ns.On, ns.Get, ns.Set, ns.OnSetting, ns.RGB, ns.OpenSettings.
-- Without a base new enough ns.linked stays unset, and the files after this one do nothing.
local ADDON, ns = ...

local Base = rawget(_G, 'PatchwerkForever')
if not (type(Base) == 'table' and type(Base.Tool) == 'function' and Base:Tool(ADDON, ns, {
	api = 1,                                        -- the base's API this tool was written for
	name = 'Sparkle',
	colour = 'ffffe680',
	saved = 'PatchwerkForever_Thread_SparkleDB',
	page = 'Thread: Sparkle',
	slash = '/sparkle',
})) then
	print('|cffd6a35bPatchwerk|r ' .. ADDON .. ' needs a newer Patchwerk Forever (the base addon). It is not running.')
end
