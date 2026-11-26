local _, env = ...;
if not env.NativeContext then return end;
---------------------------------------------------------------
-- Console Port's menu ring
---------------------------------------------------------------
-- Since Console Port 3.3.14 its large game menu ring (ConsolePort_Menu,
-- the frame ConsolePortMenuRing) opens only while its Game Menu
-- setting is ticked and the game's own gamepad interface is off. Up
-- to 3.3.13 the ring opened from its binding whatever either was,
-- and on Forever the Game Menu setting started unticked, so a ring
-- bound and used every day stopped opening after the update.
--
-- Two things go wrong, and both are put right here:
--
-- 1. The ring has no buttons. When the ring starts out shut, Console
--    Port's setup closes it with ring:RunAttribute('ClearAndHide'),
--    and Forever's frames have no RunAttribute outside the secure
--    environment: the call fails ("attempt to call a nil value",
--    ConsolePort_Menu/View/Ring.lua:209) and the setup stops before it
--    adds the buttons. The ring is given a RunAttribute that does the
--    same through its own secure Execute (as Console Port's
--    CPAPI.SecureExportMixin does), and a setup that stopped is run
--    again, its empty button pool cleared first. This is always on,
--    like the other missing functions in Compat.lua. Console Port
--    3.3.16 fixed this itself (the setup no longer calls
--    RunAttribute), and there the repair finds the buttons already
--    in place and does nothing; it stays for 3.3.14 and 3.3.15.
--
-- 2. The ring stays shut. It decides through a secure attribute,
--    'enabled', which Console Port sets each time its settings or the
--    interface style change. With Keep The Menu Ring on, it is set
--    back to on right after. The game's own game menu is left as
--    Console Port has it: only the ring is kept.
--
-- The ring is a secure frame: nothing here touches it in a fight; a
-- change asked for then waits for the fight's end.

local ADDON_NAME = 'ConsolePort_Menu';
local hooked, waiting, repaired = false, false, false;

local function Ring()
	return rawget(_G, 'ConsolePortMenuRing');
end

-- a value written into a secure snippet
local function Literal(value)
	local kind = type(value);
	if ( kind == 'boolean' or kind == 'number' ) then return tostring(value) end;
	if ( kind == 'string' ) then return ('%q'):format(value) end;
	if ( value == nil ) then return 'nil' end;
	error("the ring's RunAttribute cannot pass a " .. kind);
end

-- ring:RunAttribute(name, ...): the snippet in that attribute, run in the secure environment
local function RunAttribute(self, name, ...)
	local args = {};
	for i = 1, select('#', ...) do
		args[i] = Literal((select(i, ...)));
	end
	return self:Execute(('self:RunAttribute(%q%s)'):format(name,
		#args > 0 and ( ', ' .. table.concat(args, ', ') ) or ''))
end

local function Keep()
	local ring = Ring();
	if not ( ring and env:GetSetting('foreverKeepMenuRing') ) then return end;
	if ring:GetAttribute('enabled') then return end;
	if InCombatLockdown() then
		waiting = true;
		return;
	end
	ring:SetAttribute('enabled', true)
end

-- the missing RunAttribute, and Console Port's setup finished if it stopped for the want of it
local function Repair()
	local ring = Ring();
	if not ( ring and ring.Execute ) then return end;
	if ( ring.RunAttribute == nil ) then
		ring.RunAttribute = RunAttribute;
	end
	-- (its pool made but no button in it, and the setup still waiting to be marked done: it stopped)
	if repaired or not ( ring.OnDataLoaded and ring.ObjectPool ) then return end;
	if ( ( tonumber(ring:GetAttribute('numbuttons')) or 0 ) > 0 ) then return end;
	if InCombatLockdown() then
		waiting = true;
		return;
	end
	repaired = true;
	ring.ObjectPool, ring.ObjectPoolMixin = nil, nil;
	local ok, problem = pcall(CPAPI.EventMixin.ADDON_LOADED, ring, ADDON_NAME);
	if not ok then
		env:Print('|cff69ccf0Console Port:|r', "The menu ring's buttons could not be added:", tostring(problem))
	end
end

-- Console Port's own answer, for turning the fix off again
local function GiveBack()
	local ring = Ring();
	if not ( ring and ring.OnEnabledChanged ) or InCombatLockdown() then return end;
	ring:OnEnabledChanged()
end

local function Hook()
	local ring = Ring();
	if hooked or not ring then return end;
	hooked = true;
	-- (Console Port's callbacks hold its own OnEnabledChanged, so the attribute is watched instead)
	hooksecurefunc(ring, 'SetAttribute', function(_, key, value)
		if ( key == 'enabled' and not value ) then Keep() end;
	end)
end

local function Update()
	Repair()
	Hook()
	Keep()
end

local Watcher = CreateFrame('Frame')
Watcher:RegisterEvent('ADDON_LOADED')
Watcher:RegisterEvent('PLAYER_LOGIN')
Watcher:RegisterEvent('PLAYER_REGEN_ENABLED')
Watcher:SetScript('OnEvent', function(_, event, name)
	if ( event == 'ADDON_LOADED' and name ~= ADDON_NAME ) then return end;
	if ( event == 'PLAYER_REGEN_ENABLED' ) then
		if not waiting then return end;
		waiting = false;
	end
	Update()
end)
if not InCombatLockdown() then Update() end;

env:OnSetting('foreverKeepMenuRing', function(_, initial)
	if initial then return end;
	if env:GetSetting('foreverKeepMenuRing') then
		Update()
	else
		GiveBack()
	end
end)

-- for /patchwerk consoleport: what the ring holds, to see why it might show without its buttons
function env:MenuRingDetails()
	local ring, out = Ring(), {};
	if not ring then return out end;
	local function Say(...) out[#out + 1] = table.concat({ tostringall(...) }, ' ') end;
	Say('numbuttons:', ring:GetAttribute('numbuttons'), '| active:', ring.GetNumActive and ring:GetNumActive(),
		'| shown:', ring:IsShown(), '| alpha:', ring:GetAlpha(), '| scale:', ring:GetScale())
	Say('Game Menu setting:', env.db and env.db('gameMenuEnable'),
		'| game gamepad interface:', CPAPI.IsNativeNavigationActive and CPAPI.IsNativeNavigationActive())
	local count = 0;
	if ring.EnumerateActive then
		for button in ring:EnumerateActive() do
			count = count + 1;
			if count <= 3 then
				Say(('button %d: shown %s, alpha %.2f, size %dx%d, text %s, icon %s'):format(button:GetID(),
					tostring(button:IsShown()), button:GetAlpha(), button:GetWidth() or 0, button:GetHeight() or 0,
					tostring(button.text), tostring(button.icon and button.icon:GetTexture())))
			end
		end
	end
	Say('buttons made:', count)
	return out;
end

-- for the diagnostics and the checks outside the game
function env:MenuRingState()
	local ring = Ring();
	return ring ~= nil, hooked, ring and ring:GetAttribute('enabled') or false;
end
