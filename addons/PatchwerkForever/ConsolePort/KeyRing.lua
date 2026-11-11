local _, env = ...;
if not env.NativeContext then return end;
---------------------------------------------------------------
-- Key ring slot on the toolbar
---------------------------------------------------------------
-- Forever hides and disables the key ring slot for characters that
-- shouldn't have one; Console Port's toolbar shows every bag slot
-- it takes over, so those characters got a dead key ring slot. It
-- is hidden again whenever it is shown and shouldn't be, before the
-- toolbar lays its slots out.

if not ( KeyRingButton and C_ActionBar and C_ActionBar.ShouldShowKeyring ) then return end;

hooksecurefunc(KeyRingButton, 'Show', function(self)
	if not C_ActionBar.ShouldShowKeyring() then
		self:Hide()
	end
end)
