---------------------------------------------------------------
-- Console Port on WoW Forever
---------------------------------------------------------------
-- WoW Forever's gamepad mode activates its own binding context
-- (GamepadModeInGameCore) for native actions such as switch to
-- cursor, the radial menu and ping. That context wins over regular
-- bindings, so a button bound in Console Port can still fire the
-- native action instead. This fix clears those conflicts, adds the
-- native actions to Console Port's binding list, and lets the game
-- menu binding open the game menu (GameMenu.lua).

if not ( select(2, ...).linked and CPAPI and ConsolePort ) then return end;   -- (linked: Link.lua joined the base)
local _, Data, env, db = CPAPI.LinkEnv(...);

env.NativeContext  = Enum.BindingContext and Enum.BindingContext.GamepadModeInGameCore;
env.RegularContext = Enum.BindingContext and Enum.BindingContext.None;
if not env.NativeContext then return end;

-- The action bound to a chord in exactly one context, asked of the game itself. Console Port's own
-- CPAPI.GetBindingAction cannot be used for this since 3.3.16: asked about the regular context it
-- answers with the native binding when the regular one is empty, so every native binding would look
-- like a conflict.
function env:BindingIn(keyChord, context)
	return GetBindingAction(keyChord, false, context) or '';
end

-- @return saved : { cleared = {...}, autoEnable = cvar value }, or nil before load
function env:GetConsolePortSaved()
	local saved = self:GetSaved('ConsolePort');
	if saved then
		saved.cleared = saved.cleared or {};
	end
	return saved;
end

---------------------------------------------------------------
-- Native actions
---------------------------------------------------------------
-- setting  : variable that allows the conflict sweep to clear it
-- bindable : listed in Console Port's binding list
env.NativeActions = {
	{	action   = 'TOGGLEUIFOCUS';
		setting  = 'foreverClearUIFocus';
		bindable = true;
		name     = 'Switch to Cursor';
		desc     = "Switches between controlling your character and navigating the interface with Forever's native gamepad cursor.";
	};
	{	action   = 'OPENRADIAL';
		setting  = 'foreverClearRadial';
		bindable = true;
		name     = 'Gamepad Radial Menu';
		desc     = "Opens Forever's native radial menu. Also skips cinematics.";
	};
	{	action   = 'TOGGLEPINGSYSTEM';
		setting  = 'foreverClearPing';
		bindable = true;
		name     = 'Ping';
		desc     = 'Tap to ping, hold to open the ping wheel.';
	};
	{	action   = 'GAMEPADLEFTTARGETMODIFIER';
		setting  = 'foreverClearTargetModifiers';
		bindable = true;
		name     = 'Left Targeting Modifier';
		desc     = "Hold to use Forever's friendly targeting actions (hostile when the targeting modifiers are swapped).";
	};
	{	action   = 'GAMEPADRIGHTTARGETMODIFIER';
		setting  = 'foreverClearTargetModifiers';
		bindable = true;
		name     = 'Right Targeting Modifier';
		desc     = "Hold to use Forever's hostile targeting actions (friendly when the targeting modifiers are swapped).";
	};
};

-- Every other native action (the hidden native action bar and its
-- modifiers, and anything Forever adds later) falls under this one.
env.OtherSetting = 'foreverClearOther';

env.ActionInfo = {};
for _, info in ipairs(env.NativeActions) do
	env.ActionInfo[info.action] = info;
end

-- Native actions are hidden bindings, so the binding list may not
-- include them; known ones are always checked.
local KnownOtherActions = {
	'GAMEPADLEFTMOD', 'GAMEPADRIGHTMOD',
	'GAMEPADACTIONBUTTON1', 'GAMEPADACTIONBUTTON2', 'GAMEPADACTIONBUTTON3', 'GAMEPADACTIONBUTTON4',
	'GAMEPADACTIONBUTTON5', 'GAMEPADACTIONBUTTON6', 'GAMEPADACTIONBUTTON7', 'GAMEPADACTIONBUTTON8',
};

function env:GetNativeActions()
	local actions = {};
	for _, info in ipairs(self.NativeActions) do
		actions[info.action] = true;
	end
	for _, action in ipairs(KnownOtherActions) do
		actions[action] = true;
	end
	for i = 1, GetNumBindings() do
		local action = GetBinding(i)
		if self:IsNativeAction(action) then
			actions[action] = true;
		end
	end
	return actions;
end

function env:GetSettingForAction(action)
	local info = self.ActionInfo[action];
	return info and info.setting or self.OtherSetting;
end

function env:GetActionName(action)
	local info = self.ActionInfo[action];
	return info and info.name or GetBindingName(action);
end

function env:IsNativeAction(action)
	return action and C_KeyBindings.GetBindingContextForAction(action) == self.NativeContext;
end

-- A binding change, said in chat as every other line of this addon (Report Binding Changes).
function env:Notify(text, ...)
	if self:GetSetting('foreverNotify') then
		self:Print('|cff69ccf0Console Port:|r', text:format(...))
	end
end

-- The smaller fixes that took hold, by name (GameMenu.lua lists them in /patchwerk consoleport).
env.Applied = {};

function env:SaveBindings()
	local setID = GetCurrentBindingSet()
	if ( setID == Enum.BindingSet.Account or setID == Enum.BindingSet.Character ) then
		SaveBindings(setID)
	end
end

---------------------------------------------------------------
-- Settings
---------------------------------------------------------------
-- Patchwerk's own, on its own page of the game's options: nothing
-- is added to Console Port's settings.
local SECTION = 'Console Port on Forever';

for _, def in ipairs({
	{	key  = 'foreverDirectGameMenu';
		name = 'Open Game Menu Directly';
		desc = "Stops the game menu button from clearing your target or switching the gamepad cursor on and off before it opens the game menu.";
		note = "Turns off the game's automatic gamepad cursor, so opening bags or loot no longer switches it on by itself.";
	};
	{	key  = 'foreverClearConflicts';
		name = 'Clear Native Conflicts';
		desc = "Removes Forever's native gamepad binding from any button that has a Console Port binding, so the Console Port binding works.";
		note = 'Turning off a type below puts back the native bindings that were removed for it.';
	};
	{	key  = 'foreverClearUIFocus', parent = 'foreverClearConflicts';
		name = 'Clear Switch to Cursor';
		desc = 'Allow clearing the native switch to cursor binding.';
	};
	{	key  = 'foreverClearRadial', parent = 'foreverClearConflicts';
		name = 'Clear Radial Menu';
		desc = 'Allow clearing the native radial menu binding.';
	};
	{	key  = 'foreverClearPing', parent = 'foreverClearConflicts';
		name = 'Clear Ping';
		desc = 'Allow clearing the native ping binding.';
	};
	{	key  = 'foreverClearTargetModifiers', parent = 'foreverClearConflicts';
		name = 'Clear Targeting Modifiers';
		desc = 'Allow clearing the native left and right targeting modifier bindings.';
	};
	{	key  = 'foreverClearOther', parent = 'foreverClearConflicts';
		name = 'Clear Other Native Bindings';
		desc = "Allow clearing every other native binding, such as the native action bar that Console Port hides.";
	};
	{	key  = 'foreverNotify';
		name = 'Report Binding Changes';
		desc = 'Print a chat message when native bindings are cleared, restored or replaced.';
	};
	{	key  = 'foreverRestoreBars';
		name = "Keep The Game's Bag Bar And Micro Menu";
		desc = "Console Port's action bars hide the game's own bag bar and micro menu for good. With this on, each is put back while Console Port's toolbar is not showing its buttons.";
		note = 'Takes effect after a reload.';
	};
	{	key  = 'foreverKeepMenuRing';
		name = 'Keep The Menu Ring';
		desc = "Since Console Port 3.3.14 its large game menu ring opens only while its Game Menu setting is on and the game's own gamepad interface is off. With this on, the ring opens from its binding as it did before.";
		note = "Console Port's game menu itself is left as Console Port has it.";
	};
}) do
	def.default, def.section = true, SECTION;
	env:AddSetting(def)
end
