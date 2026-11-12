local _, ns = ...;
local MelloUI = _G.MelloUI;
if not ( ns.linked and MelloUI and MelloUI.RegisterModule and MelloUI.SetModuleEnabled ) then return end;
---------------------------------------------------------------
-- MelloUI: Route and guides only
---------------------------------------------------------------
-- Keeps MelloUI's Route (the way to your waypoint along roads) and
-- its Quest Tracker, and switches every other MelloUI module off.
-- Route's guide reader (MelloUI_Route/Guides.lua) hands RestedXP's
-- current steps to the Quest Tracker, which shows them in a section
-- of their own. MelloUI's core stays, since both are built on it and
-- Route's boat and zeppelin data live there, as do MelloUI_Route and
-- MelloUI_Companion (the road network, loaded on demand). The other
-- MelloUI addons are unticked in the addon list, so they stop
-- loading from the next login.
--
-- The switches are flipped a few seconds after login, once MelloUI
-- has started, the same way /mello's switches flip them: each module
-- runs its own OnDisable, which puts back what it changed in the
-- game (chat colours, game settings it borrowed). A reload then
-- clears what was drawn. From then on the switches are already set,
-- so nothing more happens. The kept modules' settings are left alone.
-- Turning this fix off stops it from trimming; it does not switch
-- anything back on (use /mello and the addon list for that).
--
-- Each module and addon is trimmed once. What the player switches
-- back on in MelloUI afterwards stays on: at later logins only what
-- has not been seen before (a module a MelloUI update added) is
-- switched off. Switching the setting off and on starts over.
--
-- PatchwerkForeverDB.MelloUI = {
--     seen       = { [module] = true }, -- trimmed or kept once already
--     seenAddOns = { [character] = { [addon] = true } },
-- }
--
-- Off until asked for (its setting, or /patchwerk mello on). It
-- switches off most of another addon, which no one should get by
-- installing this one.

local KEEP_MODULES = {
	Route        = true;
	QuestTracker = true; -- shows the guide's steps Route reads
};
local KEEP_ADDONS = {
	MelloUI           = true;
	MelloUI_Route     = true;
	MelloUI_Companion = true;
	MelloUI_Languages = true; -- load on demand: only for a configurator in another language
};

local SETTING = 'melloRouteOnly';

ns:AddSetting({
	key     = SETTING;
	default = false;
	section = 'MelloUI';
	name    = 'Only Route And The Quest Tracker';
	desc    = "Switches every other MelloUI module off and unticks MelloUI's other addons, for using its Route beside another interface addon. It does this once: anything you switch back on in MelloUI afterwards stays on.";
	note    = 'Turning this off does not switch anything back on (use /mello and the addon list for that). Turning it off and on again trims everything once more.';
})

local function Wanted()
	return ns:GetSetting(SETTING) == true;
end

-- what has been trimmed or kept once already: left as the player has it from then on
local function Seen(kind)
	local saved = ns:GetSaved('MelloUI');
	if not saved then
		return {};
	end
	saved[kind] = saved[kind] or {};
	return saved[kind];
end

local function StartOver()
	local saved = ns:GetSaved('MelloUI');
	if saved then
		saved.seen, saved.seenAddOns = nil, nil;
	end
end

local function Print(...)
	ns:Print('|cff9b8cffMelloUI|r', ...)
end

-- Modules with a switch of their own, as MelloUI's Everything Off
-- profile tells them (MelloUI:FreshProfileText).
local function HasOwnSwitch(module)
	return not ( module.hidden or module.noSwitch );
end

-- (as Console Port's module switches pass it to the addon list)
local function GetCharacter()
	return UnitGUID('player');
end

local function IsAddOnEnabled(name)
	local state = C_AddOns.GetAddOnEnableState(name, GetCharacter());
	return state ~= nil and state > 0;
end

-- @return off : list of module titles switched off
-- @return on  : list of kept module titles switched on
local function TrimModules()
	local off, on, seen = {}, {}, Seen('seen');
	for name, module in MelloUI:IterateModules() do
		local enabled = MelloUI:IsModuleEnabled(name);
		if seen[name] then
			-- (the player's own choice since)
		elseif KEEP_MODULES[name] then
			seen[name] = true;
			if not enabled then
				MelloUI:SetModuleEnabled(name, true)
				on[#on + 1] = module.title or name;
			end
		else
			seen[name] = true;
			if ( HasOwnSwitch(module) and enabled ) then
				MelloUI:SetModuleEnabled(name, false)
				off[#off + 1] = module.title or name;
			end
		end
	end
	-- (a module of one of MelloUI's other addons that is not loaded now comes back with its
	-- addon, when the player ticks that again: their choice, so it counts as seen too)
	for feature in pairs(type(MelloUI.Features) == 'table' and MelloUI.Features or {}) do
		seen[feature] = true;
	end
	return off, on;
end

-- @return disabled : list of addons unticked
local function TrimAddOns()
	-- (the addon list is each character's own)
	local disabled, all, character = {}, Seen('seenAddOns'), GetCharacter() or '';
	all[character] = all[character] or {};
	local seen = all[character];
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i);
		if ( name and name:find('^MelloUI_') and not seen[name] ) then
			seen[name] = true;
			if KEEP_ADDONS[name] then
				if not IsAddOnEnabled(name) then
					C_AddOns.EnableAddOn(name, GetCharacter())
				end
			elseif IsAddOnEnabled(name) then
				C_AddOns.DisableAddOn(name, GetCharacter())
				disabled[#disabled + 1] = name;
			end
		end
	end
	return disabled;
end

StaticPopupDialogs.PATCHWERK_MELLOUI_RELOAD = {
	text         = 'Patchwerk switched MelloUI down to Route and the Quest Tracker. Reload to finish?';
	button1      = RELOADUI;
	button2      = LATER;
	OnAccept     = ReloadUI;
	timeout      = 0;
	whileDead    = true;
	hideOnEscape = true;
};

local Waiter = CreateFrame('Frame')

local function RouteOnly()
	if not Wanted() then return end;
	if not MelloUI.initialized then
		return C_Timer.After(3, RouteOnly)
	elseif InCombatLockdown() then
		return Waiter:RegisterEvent('PLAYER_REGEN_ENABLED')
	end

	local off, on = TrimModules();
	local addons  = TrimAddOns();
	if ( #off > 0 ) then
		table.sort(off)
		Print('Switched off:', table.concat(off, ', '))
	end
	if ( #on > 0 ) then
		table.sort(on)
		Print('Switched on:', table.concat(on, ', '))
	end
	if ( #addons > 0 ) then
		table.sort(addons)
		Print('Unticked in the addon list from the next login:', table.concat(addons, ', '))
	end
	-- A module switched live may leave what it drew, or miss its
	-- login setup, until a reload.
	if ( #off > 0 or #on > 0 ) then
		StaticPopup_Show('PATCHWERK_MELLOUI_RELOAD')
	end
end

-- After the login, once MelloUI's start-up pass has run over its
-- first frames.
Waiter:RegisterEvent('PLAYER_ENTERING_WORLD')
Waiter:SetScript('OnEvent', function(self, event)
	self:UnregisterEvent(event)
	C_Timer.After(3, RouteOnly)
end)

---------------------------------------------------------------
-- /patchwerk mello
---------------------------------------------------------------
local function ListRunning()
	local running = {};
	for name, module in MelloUI:IterateModules() do
		if MelloUI:IsModuleEnabled(name) then
			running[#running + 1] = (module.title or name) .. (HasOwnSwitch(module) and '' or ' (always on)');
		end
	end
	table.sort(running)
	return running;
end

ns:RegisterFix('mello', {
	name    = 'MelloUI Route and guides only';
	addon   = 'MelloUI';
	status  = function()
		return Wanted() and 'on' or 'off';
	end;
	command = function(args)
		args = args:lower();
		if ( args == 'on' or args == 'off' ) then
			ns:SetSetting(SETTING, args == 'on')
		else
			Print('Trimming to Route and the Quest Tracker:', Wanted() and 'on' or 'off', '(/patchwerk mello on | off)')
			Print('Modules running:', table.concat(ListRunning(), ', '))
		end
	end;
})

-- (at login the trim runs from the world's coming in, above)
ns:OnSetting(SETTING, function(on, initial)
	if initial then return end;
	if on then
		Print('Trimming to Route and the Quest Tracker is on. What you switch back on in MelloUI afterwards stays on.')
		StartOver()
		RouteOnly()
	else
		Print('Trimming is off. Nothing was switched back on: use /mello and the addon list.')
	end
end)
