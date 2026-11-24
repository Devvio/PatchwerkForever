local _, env = ...;
local db = env.db;
if not env.NativeContext then return end;
---------------------------------------------------------------
-- Open game menu directly
---------------------------------------------------------------
-- On Forever, the game menu binding first runs a chain of escape
-- handlers. While the game may switch the gamepad cursor on by
-- itself, one handler clears the target or switches the cursor on,
-- and another switches it back off, each ending the chain before
-- the game menu opens. Holding a modifier skips both, which is why
-- a modified game menu binding works. With the automatic cursor
-- off, neither handler runs.

local CVAR = 'GamePadCursorAutoEnable';

local function Print(...)
	env:Print('|cff69ccf0Console Port:|r', ...)
end

-- It changes a setting of the game's, so it says so each time it does, and when it puts it back.
function env:UpdateDirectGameMenu()
	local saved = self:GetConsolePortSaved();
	if not saved then return end;
	if self:GetSetting('foreverDirectGameMenu') then
		if ( saved.autoEnable == nil ) then
			-- Already 0 means an earlier version of this fix set it, before
			-- the value it replaced was saved here: put back the default.
			local value = GetCVar(CVAR);
			saved.autoEnable = ( value == '0' ) and C_CVar.GetCVarDefault(CVAR) or value;
		end
		if ( GetCVar(CVAR) ~= '0' ) then
			SetCVar(CVAR, 0)
			Print("Open Game Menu Directly turned off the game's automatic gamepad cursor. Disable that option to put it back.")
		end
	elseif ( saved.autoEnable ~= nil ) then
		SetCVar(CVAR, saved.autoEnable)
		saved.autoEnable = nil;
		Print("The game's automatic gamepad cursor is set back as it was.")
	end
end

local Handler = CreateFrame('Frame')
Handler:RegisterEvent('PLAYER_LOGIN')
Handler:SetScript('OnEvent', function()
	env:UpdateDirectGameMenu()
end)

-- (as the saved variables come in the game's own settings may not be: PLAYER_LOGIN applies it then)
env:OnSetting('foreverDirectGameMenu', function(_, initial)
	if not initial then
		env:UpdateDirectGameMenu()
	end
end)

---------------------------------------------------------------
-- Registration and diagnostics: /patchwerk consoleport
---------------------------------------------------------------
-- Which of the smaller fixes took hold (env.Applied, set by each fix's file where it attaches): a fix
-- that did not may no longer be needed, or Console Port may have changed under it.
local FIXES = {
	'Extra Action Button', 'Item menu equip slots', 'Interact (tap)', 'Target Friendly / Target Hostile',
	'Key ring slot', 'StaticPopup_Resize', 'ActionButton_SetTooltip', 'GetScaledCursorPosition',
	'Micro menu', 'Bag bar', 'Options window',
};

local function Applied()
	local yes, no = {}, {};
	for _, name in ipairs(FIXES) do
		if env.Applied[name] then yes[#yes + 1] = name else no[#no + 1] = name end;
	end
	return yes, no;
end

local function DescribeKey(keyChord)
	local regular = CPAPI.GetBindingAction(keyChord, false, env.RegularContext);
	local native  = CPAPI.GetBindingAction(keyChord, false, env.NativeContext);
	return ('%s: regular=%s native=%s'):format(keyChord,
		regular ~= '' and regular or '-', native ~= '' and native or '-');
end

local function PrintDiagnostics()
	local yes, no = Applied();
	Print('Fixes applied:', #yes > 0 and table.concat(yes, ', ') or 'none')
	Print('Not applied (not needed here, or Console Port has changed):', #no > 0 and table.concat(no, ', ') or 'none')
	local saved = env:GetConsolePortSaved() or {};
	Print('Gamepad UI enabled:', tostring(InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled()))
	Print(CVAR..':', GetCVar(CVAR), '| saved:', tostring(saved.autoEnable),
		'| setting:', tostring(env:GetSetting('foreverDirectGameMenu')))
	Print('Auto cursor allowed (on/off):',
		tostring(CanAutoSetGamePadCursorControl(true)), tostring(CanAutoSetGamePadCursorControl(false)))
	Print('Cursor control:', tostring(IsGamePadCursorControlEnabled()),
		'| native context active:', tostring(C_KeyBindings.IsBindingContextActive
			and C_KeyBindings.IsBindingContextActive(env.NativeContext)))

	if env.MenuRingState then
		local loaded, hooked, enabled = env:MenuRingState();
		Print('Menu ring:', loaded and ( 'loaded, ' .. ( enabled and 'opens' or 'kept closed by Console Port' ) ) or 'not loaded yet',
			'| Keep The Menu Ring:', tostring(env:GetSetting('foreverKeepMenuRing')), hooked and '(watching)' or '')
		if env.MenuRingDetails then
			for _, line in ipairs(env:MenuRingDetails()) do Print('  ' .. line) end
		end
	end

	local keys = { GetBindingKey('TOGGLEGAMEMENU', false, env.RegularContext) };
	Print('Game menu keys:', #keys > 0 and table.concat(keys, ', ') or 'none')
	for _, keyChord in ipairs(keys) do
		Print('  '..DescribeKey(keyChord))
	end

	for action in pairs(env:GetNativeActions()) do
		local native = { GetBindingKey(action, false, env.NativeContext) };
		if ( #native > 0 ) then
			Print('Native', env:GetActionName(action)..':', table.concat(native, ', '))
		end
	end
end

env:RegisterFix('consoleport', {
	name    = 'Console Port on Forever';
	addon   = 'ConsolePort';
	command = PrintDiagnostics;
	status  = function()
		local yes = Applied();
		return ('on: %d of %d fixes applied'):format(#yes, #FIXES);
	end;
})
