local _, env = ...;
if not env.NativeContext then return end;
---------------------------------------------------------------
-- The game's bag bar and micro menu
---------------------------------------------------------------
-- On Forever, ConsolePort_Bar hides the game's bag bar and micro
-- menu for good when it loads, whether or not its toolbar takes
-- their buttons. With the toolbar off, or set not to show them,
-- they were gone, and so were other addons' options built on them
-- (EllesmereUI's Micro Menu Bar and Bag Bar). Each is put back
-- where the game keeps it while its buttons are still its own;
-- one whose buttons the toolbar took stays hidden.
--
-- Neither frame registers events of its own on Forever, so the
-- events ConsolePort_Bar cleared need nothing back.

-- The toolbar moves the micro buttons out of the micro menu.
local function MicroMenuHasButtons()
	for _, child in ipairs({ MicroMenu:GetChildren() }) do
		if child.layoutIndex then
			return true;
		end
	end
	return false;
end

local function RestoreMicroMenu()
	if not ( MicroMenu and MicroMenuContainer ) then return end;
	if ( MicroMenu:GetParent() == MicroMenuContainer or not MicroMenuHasButtons() ) then return end;
	MicroMenu:SetParent(MicroMenuContainer)
	MicroMenu:Show()
	if MicroMenuContainer.Layout then
		MicroMenuContainer:Layout()
	end
	return true;
end

-- The toolbar moves the backpack button out of the bag bar.
local function RestoreBagsBar()
	if not ( BagsBar and MainMenuBarBackpackButton ) then return end;
	if ( BagsBar:GetParent() == UIParent or MainMenuBarBackpackButton:GetParent() ~= BagsBar ) then return end;
	BagsBar:SetParent(UIParent)
	BagsBar:Show()
	if BagsBar.Layout then
		BagsBar:Layout()
	end
	return true;
end

local Watcher = CreateFrame('Frame')

local function Restore()
	if not env:GetSetting('foreverRestoreBars') then return end;
	if InCombatLockdown() then
		return Watcher:RegisterEvent('PLAYER_REGEN_ENABLED')
	end
	if RestoreMicroMenu() then env.Applied['Micro menu'] = true end;
	if RestoreBagsBar() then env.Applied['Bag bar'] = true end;
end

-- After the toolbar has taken what it shows at login.
EventUtil.ContinueOnAddOnLoaded('ConsolePort_Bar', function()
	Watcher:RegisterEvent('PLAYER_ENTERING_WORLD')
	Watcher:SetScript('OnEvent', function(self, event)
		self:UnregisterEvent(event)
		C_Timer.After(2, Restore)
	end)
	if IsLoggedIn() then
		C_Timer.After(2, Restore)
	end
end)
