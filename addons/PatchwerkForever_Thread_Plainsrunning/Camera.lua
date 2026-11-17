-- Thread (Immersive Plainsrunning): the camera eases back a little at full speed, and returns after.
--
-- It moves with the game's own CameraZoomOut and CameraZoomIn, as the mouse wheel does, so the game eases
-- it there at its own zoom speed. It goes back by no more than it went: the game stops the camera at its
-- furthest zoom, so a second after going out the distance it really moved is read (GetCameraZoom), and
-- that is what is taken back. It does not go back within that second, so it always knows. Zooming
-- yourself during a run is kept: only this addon's part is taken back.
local ADDON, ns = ...
if not ns.linked then return end

local SETTLE = 1.0          -- seconds for the camera to get where it was sent

local applied = 0           -- yards this addon asked for, now
local gained                -- yards it really went (known a moment after going), or nil
local start                 -- the camera's distance before it went
local settleAt              -- when to read how far it really went

local function Zoom() return rawget(_G, 'GetCameraZoom') and tonumber(GetCameraZoom()) end

local function Back(yards)
	if yards > 0 then CameraZoomIn(yards) end
end

-- One moment of the game.
-- @param full : whether the effects are wanted now (the interface gone at full speed)
-- @return true while the camera is out (or on its way), so the moments keep coming until it is back
function ns.CameraStep(now, full)
	if not ( rawget(_G, 'CameraZoomOut') and rawget(_G, 'CameraZoomIn') ) then return false end
	local want = ( full and ns.Get('camera') ) and ns.Get('cameraYards') or 0
	if settleAt and now >= settleAt then
		settleAt = nil
		local z = Zoom()
		if z and start then gained = math.max(0, math.min(applied, z - start)) end
	end
	if want ~= applied and not settleAt then
		if want > applied then
			if applied == 0 then start, gained = Zoom(), nil end
			CameraZoomOut(want - applied)
			applied = want
			settleAt = now + SETTLE
		else
			local have = gained or applied
			Back(math.max(0, have - want))
			applied = want
			gained = math.min(have, want)
			if want == 0 then start, gained = nil, nil end
		end
	end
	return applied > 0 or settleAt ~= nil
end

-- back at once (a problem, or leaving the world)
function ns.CameraBack()
	if applied > 0 and rawget(_G, 'CameraZoomIn') then
		local have = gained or applied
		applied, gained, start, settleAt = 0, nil, nil, nil
		Back(have)
	end
end

-- for the checks outside the game
function ns.CameraState() return applied, gained, settleAt ~= nil end
