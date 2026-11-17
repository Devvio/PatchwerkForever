-- Thread (Plainsrunning): its settings, the slash command and the key bindings.
--
-- Asked for on 2026-11-16: "as Plainsrunning stacks toward 30, slowly fade all of the UI until it is
-- completely hidden, then overlay speed streaks across the screen". Tauren in Forever have the passive
-- Plainsrunning (spell 1259918): the longer they keep moving, the more stacks of a speed buff they get
-- (spell 1299038, "Movement speed increased by $w1%", an aura of increased speed). Both numbers were read
-- out of Forever's own data (its hotfix cache) on 2026-11-16, and 1299038 was seen on the buff in the game.
--
-- Run.lua watches the buff and fades the interface (all of it, or all but the parts you keep);
-- Streaks.lua and Effects.lua draw the effects at full speed; Camera.lua pulls the camera back;
-- Records.lua keeps each character's run records.
--
-- How the interface is faded: the alpha of UIParent, the frame every window, bar and frame of the game's
-- interface hangs from. Alpha may be changed in a fight, on protected frames too; nothing is hidden,
-- moved or reparented, so nothing the game guards against addons is touched, and the alpha found is put
-- back as it was. Nameplates hang from the world, not UIParent, so they stay; so do the streaks.
local ADDON, ns = ...
if not ns.linked then return end

ns.TITLE = 'Patchwerk Forever: Thread (Plainsrunning)'

ns.BUFF = 1299038             -- the stacking speed buff
ns.PASSIVE = 1259918          -- the racial itself, a passive with no stacks: never taken for the buff
ns.NAME = 'Plainsrunning'     -- matched by name too, should the buff's number change in a patch
ns.MAX = 30                   -- the most stacks it gets

local E = 'Plainsrunning: Effects'      -- the second page

ns.settings = {
	{ key = 'enabled', default = true, name = 'Enable Speed Mode',
		desc = 'Fade the interface away as Plainsrunning stacks up, and show speed streaks once it is gone. Everything comes back when the buff ends.' },
	{ key = 'fadeStart', default = 10, min = 1, max = 40, step = 1, name = 'Start Fading At', parent = 'enabled',
		desc = 'The interface begins to fade at this many stacks of Plainsrunning.' },
	{ key = 'fadeFull', default = 30, min = 1, max = 40, step = 1, name = 'Fully Hidden At', parent = 'enabled',
		desc = 'The interface is gone at this many stacks (Plainsrunning goes up to 30). Between the two it fades a little with every stack.' },
	{ key = 'fadeLeft', default = 0, min = 0, max = 60, step = 5, name = 'Hidden Interface Opacity', parent = 'enabled',
		desc = 'How much of the interface is left when it is fully faded, in percent. 0 hides it completely.' },

	{ header = true, name = 'Bring The Interface Back' },
	{ key = 'combatShow', default = true, name = 'In Combat',
		desc = 'Bring the interface back at once when a fight starts, and keep it while the fight lasts.' },
	{ key = 'windowShow', default = true, name = 'When A Window Opens',
		desc = 'Bring the interface back while the map, your bags, a menu or any other window is open, or while you type in chat.' },
	{ key = 'stillShow', default = true, name = 'When Standing Still',
		desc = 'Bring the interface back when you stop moving, even while the buff lasts.' },
	{ key = 'stillTime', default = 2, min = 0, max = 10, step = 1, name = 'Seconds Standing Still', parent = 'stillShow',
		desc = 'How long you must stand still before the interface comes back.' },
	{ key = 'deadShow', default = true, name = 'When You Die Or Take A Flight',
		desc = 'Bring the interface back when you die or take a flight.' },

	{ header = true, name = 'Keep While Faded' },
	{ key = 'keepMinimap', default = false, name = 'Keep The Minimap',
		desc = 'The minimap stays while the rest of the interface fades away.' },
	{ key = 'keepUnits', default = false, name = 'Keep Player And Target',
		desc = 'Your own frame, your pet\'s, your target\'s and its target\'s stay while the rest of the interface fades away.' },
	{ key = 'keepChat', default = false, name = 'Keep The Chat',
		desc = 'The chat windows and their tabs stay while the rest of the interface fades away.' },

	{ header = true, name = 'Run Records' },
	{ key = 'recordsTell', default = true, name = 'Tell Me About New Records',
		desc = 'Say in chat when a run beats your longest time at full speed, your fastest time to 30 stacks or your farthest run. Records are kept for each character.' },
	{ button = 'Show', name = 'Show My Records', click = function() ns.Try('the records', ns.SayRecords) end,
		desc = 'List this character\'s run records in chat (also /plains records).' },

	-- the effects at full speed (Streaks.lua, Effects.lua) and the camera (Camera.lua)
	{ page = E, voice = 'The air goes past Patchwerk very fast. Patchwerk can see it go.' },
	{ page = E, key = 'streakAt', default = 30, min = 1, max = 40, step = 1, name = 'Show Effects At',
		desc = 'The effects below come in at this many stacks of Plainsrunning, once the interface is gone (and only while it is not brought back for a fight or a window).' },
	{ page = E, key = 'streakFollow', default = true, name = 'Match My Speed',
		desc = 'The effects move faster the faster you run, and fade when you slow down or stop.' },
	{ page = E, key = 'streakUp', default = 5, min = -40, max = 40, step = 1, name = 'Vertical Offset',
		desc = 'Move the point the streaks, dust and rings rush out from up (positive) or down, in percent of the screen height. It should sit on the horizon ahead of you.' },
	{ page = E, key = 'streakClear', default = 30, min = 0, max = 70, step = 5, name = 'Clear Middle',
		desc = 'How much of the middle of the screen is kept free of streaks and dust, so you can see your character and the way ahead, in percent.' },

	{ page = E, header = true, name = 'Speed Streaks' },
	{ page = E, key = 'streaks', default = true, name = 'Show Speed Streaks',
		desc = 'Lines of light rush outward from the horizon ahead of you.' },
	{ page = E, key = 'streakCount', default = 40, min = 10, max = 120, step = 5, name = 'Number Of Streaks', parent = 'streaks',
		desc = 'How many streaks are on the screen at once.' },
	{ page = E, key = 'streakLength', default = 100, min = 30, max = 250, step = 10, name = 'Length', parent = 'streaks',
		desc = 'Length of the streaks, in percent.' },
	{ page = E, key = 'streakThick', default = 100, min = 30, max = 300, step = 10, name = 'Thickness', parent = 'streaks',
		desc = 'Thickness of the streaks, in percent.' },
	{ page = E, key = 'streakBright', default = 60, min = 10, max = 100, step = 5, name = 'Brightness', parent = 'streaks',
		desc = 'Brightness of the streaks, in percent.' },
	{ page = E, key = 'streakSpeed', default = 100, min = 25, max = 300, step = 25, name = 'Speed', parent = 'streaks',
		desc = 'How fast the streaks fly past, in percent.' },
	{ page = E, key = 'streakColour', colour = true, default = 'ffeaf4ff', name = 'Color', parent = 'streaks',
		desc = 'Color of the streaks.' },

	{ page = E, header = true, name = 'Wind Gusts' },
	{ page = E, key = 'wind', default = false, name = 'Show Wind Gusts',
		desc = 'Long, thin ribbons of wind ripple sideways across the lower half of the screen, like wind running through tall grass.' },
	{ page = E, key = 'windCount', default = 10, min = 2, max = 30, step = 1, name = 'Number Of Gusts', parent = 'wind',
		desc = 'How many gusts are on the screen at once.' },
	{ page = E, key = 'windBright', default = 45, min = 10, max = 100, step = 5, name = 'Brightness', parent = 'wind',
		desc = 'Brightness of the gusts, in percent.' },
	{ page = E, key = 'windColour', colour = true, default = 'ffe6f0d8', name = 'Color', parent = 'wind',
		desc = 'Color of the gusts.' },

	{ page = E, header = true, name = 'Dust And Seeds' },
	{ page = E, key = 'dust', default = false, name = 'Show Dust And Seeds',
		desc = 'Specks of dust and grass seeds fly past you toward the edges of the screen, most of them low, near the ground.' },
	{ page = E, key = 'dustCount', default = 50, min = 10, max = 200, step = 10, name = 'Amount', parent = 'dust',
		desc = 'How many specks and seeds are on the screen at once.' },
	{ page = E, key = 'dustSize', default = 100, min = 30, max = 300, step = 10, name = 'Size', parent = 'dust',
		desc = 'Size of the specks and seeds, in percent.' },
	{ page = E, key = 'dustBright', default = 70, min = 10, max = 100, step = 5, name = 'Brightness', parent = 'dust',
		desc = 'Brightness of the specks and seeds, in percent.' },
	{ page = E, key = 'dustColour', colour = true, default = 'fff0e2bc', name = 'Color', parent = 'dust',
		desc = 'Color of the dust. The seeds take a warmer shade of it.' },

	{ page = E, header = true, name = 'Warp Rings' },
	{ page = E, key = 'rings', default = false, name = 'Show Warp Rings',
		desc = 'Faint rings swell outward from the horizon ahead of you and pass beyond the edges of the screen.' },
	{ page = E, key = 'ringCount', default = 4, min = 1, max = 10, step = 1, name = 'Number Of Rings', parent = 'rings',
		desc = 'How many rings are on the screen at once.' },
	{ page = E, key = 'ringBright', default = 35, min = 10, max = 100, step = 5, name = 'Brightness', parent = 'rings',
		desc = 'Brightness of the rings, in percent.' },
	{ page = E, key = 'ringColour', colour = true, default = 'ffcfe6ff', name = 'Color', parent = 'rings',
		desc = 'Color of the rings.' },

	{ page = E, header = true, name = 'Edge Glow' },
	{ page = E, key = 'glow', default = false, name = 'Show Edge Glow',
		desc = 'A glow along the edges of the screen.' },
	{ page = E, key = 'glowBright', default = 50, min = 10, max = 100, step = 5, name = 'Brightness', parent = 'glow',
		desc = 'Brightness of the glow, in percent.' },
	{ page = E, key = 'glowPulse', default = true, name = 'Pulse With Your Stride', parent = 'glow',
		desc = 'The glow beats in time with your hooves: faster the faster you run.' },
	{ page = E, key = 'glowColour', colour = true, default = 'ffffc040', name = 'Color', parent = 'glow',
		desc = 'Color of the glow.' },

	{ page = E, header = true, name = 'Darken The Edges' },
	{ page = E, key = 'vignette', default = true, name = 'Darken The Edges',
		desc = 'Darken the edges of the screen while the effects show, for a sense of tunnel vision at speed.' },
	{ page = E, key = 'vignetteDark', default = 45, min = 10, max = 100, step = 5, name = 'Darkness', parent = 'vignette',
		desc = 'How dark the edges get, in percent.' },

	{ page = E, header = true, name = 'Camera' },
	{ page = E, key = 'camera', default = true, name = 'Pull The Camera Back',
		desc = 'The camera eases back a little when the effects come in, and returns to where it was when the run ends or the interface comes back.' },
	{ page = E, key = 'cameraYards', default = 3, min = 1, max = 10, step = 1, name = 'Camera Distance', parent = 'camera',
		desc = 'How far back the camera goes, in yards. It never goes beyond the game\'s own furthest zoom.' },

	{ page = E, header = true, name = 'Preview' },
	{ page = E, button = 'Test', name = 'Preview Speed Mode', click = function() ns.TestRun() end,
		desc = 'Pretend to run with Plainsrunning for about fifteen seconds: the stacks climb to 30, the interface fades away and the effects show, then it all comes back. Close the options to see it.' },
}

---------------------------------------------------------------------------
-- /plains
---------------------------------------------------------------------------
local function Help()
	ns.Print('Plainsrunning commands:')
	ns.Print('  /plains: what speed mode is doing now')
	ns.Print('  /plains on | off: turn speed mode on or off;  /plains test: pretend to run for fifteen seconds')
	ns.Print('  /plains show: bring the interface back until this run ends;  /plains config: open the options')
	ns.Print('  /plains records: your run records;  /plains records reset: forget them')
end

SLASH_PATCHWERKFOREVER_PLAINS1 = '/plains'
SLASH_PATCHWERKFOREVER_PLAINS2 = '/pfplains'
SlashCmdList.PATCHWERKFOREVER_PLAINS = function(text)
	local word = (text or ''):match('^%s*(%S*)'):lower()
	if word == '' or word == 'status' then
		ns.Try('speed mode', ns.Say)
	elseif word == 'on' or word == 'off' or word == 'toggle' then
		local on = word == 'on' or ( word == 'toggle' and not ns.Get('enabled') )
		ns.Set('enabled', on)
		ns.Print('Speed mode ' .. ( on and 'enabled.' or 'disabled.' ))
	elseif word == 'test' or word == 'preview' then
		ns.Try('the preview', ns.TestRun)
	elseif word == 'records' or word == 'record' then
		if ( text or '' ):lower():match('^%s*%S+%s+reset%s*$') then
			ns.Try('the records', ns.ResetRecords)
		else
			ns.Try('the records', ns.SayRecords)
		end
	elseif word == 'show' then
		ns.Try('speed mode', ns.ShowForThisRun)
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not ns.OpenSettings() then
			ns.Print('Options are under Options > AddOns > Patchwerk Forever > Thread: Plainsrunning.')
		end
	else
		Help()
	end
end

-- For key and gamepad bindings (Bindings.xml).
BINDING_HEADER_PATCHWERKFOREVER_PLAINS = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_PLAINS_PEEK = 'Show Interface While Held'
BINDING_NAME_PATCHWERKFOREVER_PLAINS_TOGGLE = 'Turn Speed Mode On Or Off'
function PatchwerkForever_Thread_Plainsrunning_Peek(keystate)
	ns.Try('speed mode', ns.Peek, keystate ~= 'up')
end
function PatchwerkForever_Thread_Plainsrunning_Toggle()
	SlashCmdList.PATCHWERKFOREVER_PLAINS('toggle')
end
