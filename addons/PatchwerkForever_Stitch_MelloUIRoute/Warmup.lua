local _, ns = ...;
local R = ns.Route;
if not R then return end;
local M, MelloUI = R.M, R.MelloUI;
---------------------------------------------------------------
-- Roads ready at login
---------------------------------------------------------------
-- Route loads its road data (a large file, read in one frame) and
-- builds its road map only when the first route is wanted: a hitch
-- and a few seconds' wait in the world, and later still while it
-- waits for a guide to name its step. Here the data is loaded at
-- login, behind the loading screen, and the build is started as
-- soon as Route is on, so the map is usually built by the time a
-- destination arrives.

local TRIES = 30;   -- seconds waited for Route to come on
local started = false;

local function Wanted()
	return R:Get('warmup') and MelloUI.IsModuleEnabled and MelloUI:IsModuleEnabled('Route');
end

local function Preload()
	if ( Wanted() and MelloUI.LoadCompanion ) then
		MelloUI:LoadCompanion()
	end
end

local function StartBuild(tries)
	if ( started or not Wanted() ) then return end;
	-- (after Route's own start: a build begun before it leaves the
	-- paths shipped with it out for the session)
	if not R:Active() then
		tries = ( tries or 0 ) + 1;
		if ( tries <= TRIES ) then
			C_Timer.After(1, function() StartBuild(tries) end)
		end
		return;
	end
	started = true;
	M:WhenReady(nop)
end

local Frame = CreateFrame('Frame')
Frame:RegisterEvent('PLAYER_LOGIN')
Frame:RegisterEvent('PLAYER_ENTERING_WORLD')
Frame:SetScript('OnEvent', function(self, event)
	self:UnregisterEvent(event)
	if ( event == 'PLAYER_LOGIN' ) then
		return R.Try('road data preload', Preload);
	end
	C_Timer.After(0.5, function()
		R.Try('road map build', function()
			if MelloUI.WhenModulesOn then
				MelloUI:WhenModulesOn(function() R.Try('road map build', StartBuild) end)
			else
				StartBuild()
			end
		end)
	end)
end)
