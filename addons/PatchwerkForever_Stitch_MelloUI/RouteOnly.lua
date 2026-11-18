local _, ns = ...;
local MelloUI = _G.MelloUI;
if not ( ns.linked and MelloUI and MelloUI.RegisterModule and MelloUI.SetModuleEnabled ) then return end;
---------------------------------------------------------------
-- MelloUI: Route and guides only
---------------------------------------------------------------
-- Keeps MelloUI's Route (the way to your waypoint along roads) and
-- its Quest Tracker, and disables every other MelloUI module.
-- Route's guide reader (MelloUI_Route/Guides.lua) hands RestedXP's
-- current steps to the Quest Tracker, which shows them in a section
-- of their own. MelloUI's core stays, since both are built on it and
-- Route's boat and zeppelin data live there, as do MelloUI_Route and
-- MelloUI_Companion (the road network, loaded on demand). The other
-- MelloUI addons are disabled in the addon list, so they stop
-- loading from the next login.
--
-- The switches are flipped a few seconds after login, once MelloUI
-- has started, the same way /mello's switches flip them: each module
-- runs its own OnDisable, which puts back what it changed in the
-- game (chat colours, game settings it borrowed). A reload then
-- clears what was drawn. From then on the switches are already set,
-- so nothing more happens. The kept modules' settings are left alone.
-- Turning this fix off stops it from trimming; it does not enable
-- anything again (use /mello and the addon list for that).
--
-- Each module and addon is trimmed once. What the player enables
-- again in MelloUI afterwards stays enabled: at later logins only
-- what has not been seen before (a module a MelloUI update added)
-- is disabled. Disabling the setting and enabling it starts over.
--
-- PatchwerkForeverDB.MelloUI = {
--     seenIn     = { [profile] = { [module] = true } }, -- trimmed or kept once already, in that MelloUI profile
--     seen       = { [module] = true },                 -- the same for the account: MelloUI before 2.1.46
--     seenAddOns = { [character] = { [addon] = true } },
-- }
--
-- Off until asked for (its setting, or /patchwerk mello on). It
-- disables most of another addon, which no one should get by
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
	desc    = "Disables every other MelloUI module and MelloUI's other addons, for using its Route beside another interface addon. It does this once for each character's MelloUI profile: anything you enable again in MelloUI afterwards stays enabled.";
	note    = 'Disabling this does not enable anything again (use /mello and the addon list for that). Disabling it and enabling it again trims everything once more.';
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

-- Which modules are on belongs to a MelloUI profile, and since
-- MelloUI 2.1.46 each character has a profile of its own. So what
-- has been trimmed once is kept for each profile: a character
-- whose profile was never trimmed is trimmed at its first login,
-- and what the player enabled again in one profile stays enabled
-- there. Before 2.1.46 (no MelloUI:CharacterProfile) there is one
-- list for the account, as there was.
--
-- The account's list from before is handed to the first profile
-- met: at MelloUI's own change-over that is the profile that was
-- live, the one the list was made on.
local function SeenModules()
	local saved = ns:GetSaved('MelloUI');
	if not saved then
		return {};
	end
	local profile;
	if ( type(MelloUI.CharacterProfile) == 'function' ) then
		local ok, name = pcall(MelloUI.CharacterProfile, MelloUI);
		profile = ok and type(name) == 'string' and name ~= '' and name or nil;
	end
	if not profile then
		saved.seen = saved.seen or {};
		return saved.seen;
	end
	saved.seenIn = saved.seenIn or {};
	if not saved.seenIn[profile] then
		saved.seenIn[profile] = saved.seen or {};
		saved.seen = nil;
	end
	return saved.seenIn[profile];
end

local function StartOver()
	local saved = ns:GetSaved('MelloUI');
	if saved then
		saved.seen, saved.seenIn, saved.seenAddOns = nil, nil, nil;
	end
end

local function Print(...)
	ns:Print('|cff9b8cffMelloUI:|r', ...)
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

-- @return off : list of module titles disabled
-- @return on  : list of kept module titles enabled
local function TrimModules()
	local off, on, seen = {}, {}, SeenModules();
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

-- @return disabled : list of addons disabled
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
	text         = 'MelloUI was trimmed to Route and the Quest Tracker. Reload the UI to finish?';
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
		Print('Disabled:', table.concat(off, ', '))
	end
	if ( #on > 0 ) then
		table.sort(on)
		Print('Enabled:', table.concat(on, ', '))
	end
	if ( #addons > 0 ) then
		table.sort(addons)
		Print('Disabled in the addon list from the next login:', table.concat(addons, ', '))
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
	name    = 'MelloUI: only Route and the Quest Tracker';
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
		Print('Trimming to Route and the Quest Tracker is on. What you enable again in MelloUI afterwards stays enabled.')
		StartOver()
		RouteOnly()
	else
		Print('Trimming is off. Nothing was enabled again: use /mello and the addon list.')
	end
end)
