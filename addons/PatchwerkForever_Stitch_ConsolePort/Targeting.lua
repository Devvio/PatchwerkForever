local _, env = ...;
local db = env.db;
if not env.NativeContext then return end;
---------------------------------------------------------------
-- Target Friendly / Target Hostile hold buttons
---------------------------------------------------------------
-- Released without a target picked, and with Forever's tab-target
-- on release option on, Console Port's buttons fall back to
-- TargetNearestFriend/Enemy from their own (insecure) click script.
-- Those are protected, so the game blocks it and shows an addon
-- action blocked error. The buttons keep everything else; the
-- fallback is dropped, so releasing without a target does nothing.

local function OnClick(self, _, down)
	if down then
		C_GamepadTargeting.SetFilter(self.patchwerkFilter)
		C_GamepadTargeting.Enable()
		return;
	end
	C_GamepadTargeting.Disable()
	db.Radial:ReleaseStick('Camera')
end

for name, filter in pairs({
	ConsolePortTargetFriendly = Enum.GamepadTargetingFilters and Enum.GamepadTargetingFilters.Friendly;
	ConsolePortTargetHostile  = Enum.GamepadTargetingFilters and Enum.GamepadTargetingFilters.Hostile;
}) do
	local button = _G[name];
	if ( button and filter ) then
		button.patchwerkFilter = filter;
		button:SetScript('OnClick', OnClick)
		env.Applied['Target Friendly / Target Hostile'] = true;
	end
end
