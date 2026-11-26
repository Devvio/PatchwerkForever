local _, env = ...;
local db, ctx, regular = env.db, env.NativeContext, env.RegularContext;
if not ctx then return end;
---------------------------------------------------------------
-- Native conflict sweep
---------------------------------------------------------------
-- Clears native bindings that share a gamepad chord with a regular
-- binding, and records what was cleared so it can be put back when
-- the user turns clearing off for that type of action.
--
-- PatchwerkForeverDB.ConsolePort.cleared = {
--     [action] = { [keyChord] = true, ... }, ...
-- }

local Sweep = CreateFrame('Frame')
local pending = false;

local function FormatChanges(changes)
	table.sort(changes)
	return table.concat(changes, ', ')
end

function env:RecordCleared(action, keyChord)
	local cleared = self:GetConsolePortSaved().cleared;
	cleared[action] = cleared[action] or {};
	cleared[action][keyChord] = true;
end

function env:ForgetCleared(action)
	local saved = self:GetConsolePortSaved();
	if saved then
		saved.cleared[action] = nil;
	end
end

function env:IsClearingAllowed(action)
	return self:GetSetting('foreverClearConflicts') and self:GetSetting(self:GetSettingForAction(action));
end

-- @return changes : list of 'KEY (Action)' strings
function env:RestoreDisallowed()
	local changes, cleared = {}, self:GetConsolePortSaved().cleared;
	for action, keys in pairs(cleared) do
		if not self:IsClearingAllowed(action) then
			for keyChord in pairs(keys) do
				if ( env:BindingIn(keyChord, ctx) == '' and SetBinding(keyChord, action, ctx) ) then
					changes[#changes + 1] = ('%s (%s)'):format(keyChord, self:GetActionName(action));
				end
			end
			cleared[action] = nil;
		end
	end
	return changes;
end

-- @return changes : list of 'KEY (Action)' strings
function env:ClearConflicts()
	local changes = {};
	for action in pairs(self:GetNativeActions()) do
		if self:IsClearingAllowed(action) then
			for _, keyChord in ipairs({GetBindingKey(action, false, ctx)}) do
				if ( IsBindingForGamePad(keyChord)
				and env:BindingIn(keyChord, regular) ~= ''
				and SetBinding(keyChord, nil, ctx) ) then
					self:RecordCleared(action, keyChord)
					changes[#changes + 1] = ('%s (%s)'):format(keyChord, self:GetActionName(action));
				end
			end
		end
	end
	return changes;
end

function env:UpdateNativeBindings()
	pending = false;
	if InCombatLockdown() then
		return Sweep:RegisterEvent('PLAYER_REGEN_ENABLED')
	end

	local restored = self:RestoreDisallowed()
	local cleared  = self:ClearConflicts()

	if ( #restored > 0 or #cleared > 0 ) then
		self:SaveBindings()
	end
	if ( #restored > 0 ) then
		self:Notify('Restored native gamepad bindings: %s', FormatChanges(restored))
	end
	if ( #cleared > 0 ) then
		self:Notify('Cleared native gamepad bindings that blocked Console Port: %s', FormatChanges(cleared))
	end
end

function env:QueueUpdate()
	if pending or not self:GetConsolePortSaved() then return end;
	pending = true;
	C_Timer.After(0.5, function() self:UpdateNativeBindings() end)
end

---------------------------------------------------------------
-- Events
---------------------------------------------------------------
Sweep:RegisterEvent('PLAYER_ENTERING_WORLD')
Sweep:RegisterEvent('UPDATE_BINDINGS')
Sweep:SetScript('OnEvent', function(self, event)
	if ( event == 'PLAYER_REGEN_ENABLED' ) then
		self:UnregisterEvent(event)
	end
	env:QueueUpdate()
end)

for _, setting in ipairs({
	'foreverClearConflicts',
	'foreverClearUIFocus',
	'foreverClearRadial',
	'foreverClearPing',
	'foreverClearTargetModifiers',
	'foreverClearOther',
}) do
	env:OnSetting(setting, function(_, initial)
		if not initial then
			env:QueueUpdate()
		end
	end)
end
