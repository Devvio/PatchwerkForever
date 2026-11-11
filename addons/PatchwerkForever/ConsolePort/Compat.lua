local _, env = ...;
if not env.NativeContext then return end;
---------------------------------------------------------------
-- Blizzard functions Console Port calls that Forever lacks
---------------------------------------------------------------
-- Each is defined only while missing, as what it became on Forever.

-- ConsolePort_Cursor's blocked action warning resizes the popup
-- after rewriting its text: the dialogs resize themselves now.
if not StaticPopup_Resize then
	function StaticPopup_Resize(dialog, which)
		if ( dialog and dialog.Resize ) then
			dialog:Resize(which)
		end
	end
end

-- ConsolePort_Cursor shows a Blizzard action button's tooltip when
-- the interface cursor lands on it: a method of the button now.
if not ActionButton_SetTooltip then
	function ActionButton_SetTooltip(button)
		if ( button and button.SetTooltip ) then
			button:SetTooltip()
		end
	end
end

-- ConsolePort_Keyboard reads it when the keyboard is dropped after
-- a drag: only the login screen has it.
if not GetScaledCursorPosition then
	function GetScaledCursorPosition()
		local x, y = GetCursorPosition();
		local scale = UIParent:GetEffectiveScale();
		return x / scale, y / scale;
	end
end
