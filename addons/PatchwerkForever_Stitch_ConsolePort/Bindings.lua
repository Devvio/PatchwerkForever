local _, env = ...;
local db, ctx, regular = env.db, env.NativeContext, env.RegularContext;
if not ctx then return end;
---------------------------------------------------------------
-- Bindable native actions
---------------------------------------------------------------
-- Listed with Console Port's special bindings, so the config can
-- bind them. CPAPI.SetBinding already writes each action to its
-- own context.

for _, info in ipairs(env.NativeActions) do
	if info.bindable then
		tinsert(db.Bindings.Special, {
			binding = info.action;
			name    = info.name;
			desc    = info.desc;
		})
	end
end

---------------------------------------------------------------
-- Extra Action Button
---------------------------------------------------------------
-- Forever has no EXTRAACTIONBUTTON1 binding, so binding Console
-- Port's Extra Action Button fails with its binding error. The
-- button itself is still there (ExtraActionButton1, shown whenever
-- the game hands out an extra action, and given its action slot by
-- Console Port), so the entry clicks it instead. The proxied ID moves
-- with it, so Rings sees it bound and stops adding the extra action
-- to the utility ring.

local function HasBinding(action)
	for i = 1, GetNumBindings() do
		if ( GetBinding(i) == action ) then
			return true;
		end
	end
	return false;
end

local EXTRA_ACTION = db.Bindings.Proxied.ExtraActionButton;
local EXTRA_ACTION_CLICK = 'CLICK ExtraActionButton1:LeftButton';

if ( ExtraActionButton1 and not HasBinding(EXTRA_ACTION) ) then
	db.Bindings.Proxied.ExtraActionButton = EXTRA_ACTION_CLICK;
	for _, set in ipairs(db.Bindings.Primary) do
		if ( set.binding == EXTRA_ACTION ) then
			set.binding = EXTRA_ACTION_CLICK;
		end
	end
	env.Applied['Extra Action Button'] = true;
end

---------------------------------------------------------------
-- Last binding wins
---------------------------------------------------------------
-- A native and a regular binding on the same chord can't both work,
-- since the native one always wins. When Console Port binds either
-- kind, clear the other kind from that chord.

local changes, flushing = {}, false;

local function Flush()
	flushing = false;
	if ( #changes == 0 ) then return end;
	table.sort(changes)
	env:Notify('Replaced on the same button: %s', table.concat(changes, ', '))
	wipe(changes)
end

local function Report(keyChord, oldAction, newAction)
	changes[#changes + 1] = ('%s (%s -> %s)'):format(keyChord, env:GetActionName(oldAction), env:GetActionName(newAction));
	if not flushing then
		flushing = true;
		C_Timer.After(0, Flush)
	end
end

hooksecurefunc(CPAPI, 'SetBinding', function(keyChord, bindingID)
	if ( not keyChord or not bindingID or bindingID == '' ) then return end;
	if ( InCombatLockdown() or not env:GetConsolePortSaved() ) then return end;

	if env:IsNativeAction(bindingID) then
		if ( CPAPI.GetBindingAction(keyChord, false, ctx) ~= bindingID ) then return end;
		-- The user placed this action themselves, so whatever the sweep
		-- cleared for it before is no longer worth putting back.
		env:ForgetCleared(bindingID)
		local replaced = CPAPI.GetBindingAction(keyChord, false, regular);
		if ( replaced ~= '' and SetBinding(keyChord, nil, regular) ) then
			env:SaveBindings()
			Report(keyChord, replaced, bindingID)
		end
	else
		if ( CPAPI.GetBindingAction(keyChord, false, regular) ~= bindingID ) then return end;
		local native = CPAPI.GetBindingAction(keyChord, false, ctx);
		if ( native ~= '' and SetBinding(keyChord, nil, ctx) ) then
			-- Only a clear the sweep would also have made is put back later.
			if env:IsClearingAllowed(native) then
				env:RecordCleared(native, keyChord)
			end
			env:SaveBindings()
			Report(keyChord, native, bindingID)
		end
	end
end)
