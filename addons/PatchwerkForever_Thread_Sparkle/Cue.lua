-- Sparkle (Thread): an alert when a sparkle appears, a sound and a rumble of the gamepad (1.5.0).
--
-- Each kind of object has an Alert Sound (Sparkle: Appearance), None to begin with. When a sparkle
-- appears on an object it is played, once: the same object again (by its name) only after half a
-- minute, so walking back and forth past an herb does not ring each time. The sounds are the game's
-- own, played by the game's names for them (SOUNDKIT); none is copied into the addon.
--
-- Rumble On Gamepad (Sparkle: Alerts, off to begin with) shakes the gamepad a moment, through the game's
-- C_GamePad.SetVibration (in Forever's API documentation), and only while a gamepad is in use. Which
-- kinds of rumble a gamepad has, and whether Console Port leaves them to an addon, is for the game to
-- show: anything it refuses is left alone without a word.
local ADDON, ns = ...
if not ns.linked then return end

local AGAIN = 30              -- seconds before the same object alerts again
local RUMBLE = 0.18           -- seconds the gamepad rumbles
-- the game's name for each sound (SOUNDKIT), and its number where the game has no such table
local KITS = { ping = { 'MAP_PING', 3175 }, chime = { 'TELL_MESSAGE', 3081 }, coins = { 'LOOT_WINDOW_COIN_SOUND', 120 },
	page = { 'IG_QUEST_LIST_OPEN', 875 }, chain = { 'PUT_DOWN_SMALL_CHAIN', 1212 } }

local heard = {}              -- [name] = when it last alerted

-- Plays one of the sounds by its key ('none' plays nothing). True when the game took it.
function ns.CuePlay(sound)
	local kit = KITS[sound]
	if not (kit and PlaySound) then return false end
	local kits = rawget(_G, 'SOUNDKIT')
	local id = type(kits) == 'table' and tonumber(kits[kit[1]]) or kit[2]
	return (pcall(PlaySound, id))
end

-- Is a gamepad in use? Asked of the game; where it cannot be asked, no.
local function Gamepad()
	local pad = rawget(_G, 'C_GamePad')
	if type(pad) ~= 'table' or type(pad.SetVibration) ~= 'function' then return false end
	if type(pad.IsEnabled) == 'function' then
		local ok, on = pcall(pad.IsEnabled)
		if ok and on == false then return false end
	end
	if type(pad.GetActiveDeviceID) == 'function' then
		local ok, id = pcall(pad.GetActiveDeviceID)
		if ok and id == nil then return false end
	end
	return true
end

local rumbles = 0
-- Rumbles the gamepad a moment, as strong as Rumble Strength says (or `strength`, 0 to 1, for
-- seconds `long`). True when the game took it.
function ns.Rumble(strength, long)
	if not Gamepad() then return false end
	local pad = C_GamePad
	strength = strength or (ns.Get('cueRumbleStrength') or 50) / 100
	if not pcall(pad.SetVibration, 'Low', strength) then return false end
	rumbles = rumbles + 1
	local mine = rumbles
	C_Timer.After(long or RUMBLE, function()
		if mine == rumbles and type(pad.StopVibration) == 'function' then pcall(pad.StopVibration) end
	end)
	return true
end

-- A sparkle has just appeared on an object (Sparkle.lua): alert, unless this one did a moment ago.
function ns.Cue(kind, name, look)
	local now = GetTime()
	local key = (name or '?') .. ':' .. tostring(kind)
	if heard[key] and now - heard[key] < AGAIN then return end
	local sound = look and look.sound or 'none'
	local rumble = ns.Get('cueRumble') and (ns.Get('cueRumbleFor') == 'all' or sound ~= 'none')
	if sound == 'none' and not rumble then return end
	heard[key] = now
	if sound ~= 'none' then ns.CuePlay(sound) end
	if rumble then ns.Rumble() end
end

-- The Preview Rumble button.
function ns.CueTest()
	if not ns.Rumble() then
		ns.Print('No gamepad in use, or the game did not let the gamepad rumble.')
	elseif not ns.Get('cueRumble') then
		ns.Print('Preview only: Rumble On Gamepad is disabled.')
	end
end
