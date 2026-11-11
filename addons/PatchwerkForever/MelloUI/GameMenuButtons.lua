local _, ns = ...;
if not ( _G.MelloUI and GameMenuFrame and type(GameMenuFrame.Layout) == 'function' ) then return end;
---------------------------------------------------------------
-- MelloUI and EllesmereUI: game menu buttons
---------------------------------------------------------------
-- Both put their button straight under the game menu's Shop (or
-- Options) button after the menu's layout, so one covers the other.
-- Each also pushes the game's buttons below down by its own height,
-- so the room for both is already there: MelloUI's button is moved
-- under EllesmereUI's last one, into that room.

local GAP = 4; -- EllesmereUI's own gap between its two buttons

local function GetLastEllesmereButton()
	local last;
	for _, name in ipairs({ 'EllesmereUI_GameMenuButton', 'EllesmereUI_UnlockMenuButton' }) do
		local button = _G[name];
		if ( button and button:IsShown() and button:GetParent() == GameMenuFrame ) then
			last = button;
		end
	end
	return last;
end

local function Arrange()
	local entry = _G.MelloUIGameMenuEntry;
	if not ( entry and entry:IsShown() and entry:GetParent() == GameMenuFrame ) then return end;
	local last = GetLastEllesmereButton();
	if not last then return end;
	entry:ClearAllPoints()
	entry:SetPoint('TOP', last, 'BOTTOM', 0, -GAP)
end

-- After every other hook on the layout has placed its buttons.
hooksecurefunc(GameMenuFrame, 'Layout', function()
	C_Timer.After(0, Arrange)
end)

ns:RegisterFix('gamemenu', {
	name   = 'MelloUI button under EllesmereUI\'s';
	addon  = 'MelloUI, EllesmereUI';
	status = function()
		return _G.EllesmereUI and 'on' or 'waiting: EllesmereUI is not loaded';
	end;
})
