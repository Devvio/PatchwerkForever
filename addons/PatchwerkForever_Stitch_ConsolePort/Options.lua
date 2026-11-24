local _, env = ...;
if not env.NativeContext then return end;
---------------------------------------------------------------
-- Patchwerk Forever's options window, for Console Port's cursor
---------------------------------------------------------------
-- Since Patchwerk Forever 2.10.0 the family's options are in a
-- window of its own (PatchwerkForeverOptions), not the game's.
-- Console Port's interface cursor moves only through the windows
-- it knows, so it is told about this one, as it knows the game's
-- own options window. The window is made at login by the base;
-- it is asked for a moment after, when it is there.

local Handler = CreateFrame('Frame');
Handler:RegisterEvent('PLAYER_LOGIN')
Handler:SetScript('OnEvent', function(self)
	self:UnregisterEvent('PLAYER_LOGIN')
	C_Timer.After(0, function()
		local options = env.Base and env.Base.Options;
		local window = type(options) == 'table' and type(options.Frame) == 'function' and options:Frame();
		local cp = rawget(_G, 'ConsolePort');
		if not ( window and type(cp) == 'table' and type(cp.AddInterfaceCursorFrame) == 'function' ) then return end;
		local ok, added = pcall(cp.AddInterfaceCursorFrame, cp, window);
		if ( ok and added ) then env.Applied['Options window'] = true end;
	end)
end)
