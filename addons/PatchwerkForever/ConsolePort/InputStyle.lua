local _, env = ...;
local db = env.db;
if not env.NativeContext then return end;
---------------------------------------------------------------
-- Switching between gamepad and mouse and keyboard interface
---------------------------------------------------------------
-- ConsolePort_World sets up its loot window and its quick menu buff
-- and debuff rows for whichever interface style is active when it
-- loads: with Forever's gamepad interface on, the game's own loot
-- window and auras are left to it. Switching style mid-session
-- changed nothing, so the setup no longer matched. Each switch now
-- re-runs that setup through Console Port's own setting callbacks,
-- after Forever has finished its own switch, and out of combat.

local SETTINGS = { 'useCustomLootFrame', 'QMenuCollectionBuffs' };

local Watcher = CreateFrame('Frame')

local function Reapply()
	if InCombatLockdown() then
		return Watcher:RegisterEvent('PLAYER_REGEN_ENABLED')
	end
	for _, setting in ipairs(SETTINGS) do
		db:TriggerEvent('Settings/'..setting, db(setting))
	end
end

Watcher:RegisterEvent('INPUT_DEVICE_INTERFACE_TRANSITION')
Watcher:SetScript('OnEvent', function(self, event)
	if ( event == 'PLAYER_REGEN_ENABLED' ) then
		self:UnregisterEvent(event)
	end
	RunNextFrame(Reapply)
end)
