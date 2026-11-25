-- Sparkle (Thread): an alert when you pull threat (1.6.0).
--
-- When an enemy turns to attack you (you took its threat from your group's tank, or it came for you
-- first), the gamepad rumbles twice, short (Rumble When I Pull Threat), and a sound plays (Threat
-- Alert Sound). Both are off to begin with, and on Sparkle: Alerts.
--
-- Each enemy is asked of the game as its threat changes (UNIT_THREAT_LIST_UPDATE, with its nameplate,
-- target, focus or boss token): UnitThreatSituation('player', enemy) is 2 or 3 while it is attacking
-- you. Forever keeps threat secret only between two units neither of which is you or an ally, so this
-- one is plain; where the game keeps it secret anyway, nothing is done. Each enemy alerts once while it
-- stays on you, again if it leaves you and comes back, and several turning at once (a pack) alert once.
--   Alert For: In A Group, Not As A Tank (where pulling threat is a warning; a tank is the one whose
--   role the group's finder or leader set to Tank), or Always (solo too: each enemy that comes for you).
local ADDON, ns = ...
if not ns.linked then return end

local Plain = ns.Plain        -- (Sparkle.lua's)
local GAP = 1.5               -- seconds in which further enemies turning on you do not alert again
local PULSE, BETWEEN = 0.15, 0.27   -- each rumble's length, and from the start of one to the next

local on = {}                 -- [the enemy's GUID] = true while it is attacking you
local last = -math.huge       -- when the last alert was

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b = pcall(fn, ...)
	if not ok then return nil end
	return a, b
end

local function Enemy(unit)
	return type(unit) == 'string' and (unit:match('^nameplate%d+$') or unit:match('^boss%d+$')
		or unit == 'target' or unit == 'focus' or unit == 'softenemy') and true or false
end

-- Is an alert wanted just now? (Alert For)
local function Wanted()
	if not ns.Get('threatRumble') and (ns.Get('threatSound') or 'none') == 'none' then return false end
	if ns.Get('threatWhen') == 'always' then return true end
	local group = Ask(rawget(_G, 'IsInGroup'))
	if not Plain(group) or not group then
		local count = Ask(rawget(_G, 'GetNumGroupMembers'))
		group = Plain(count) and type(count) == 'number' and count > 0
	end
	if not group then return false end
	local role = Ask(rawget(_G, 'UnitGroupRolesAssigned'), 'player')
	return not (Plain(role) and role == 'TANK')
end

-- The alert: the sound, and two short rumbles. `test`: whatever the settings say.
local function Alert(test)
	local sound = ns.Get('threatSound') or 'none'
	if sound ~= 'none' then ns.CuePlay(sound) end
	if not (test or ns.Get('threatRumble')) then return sound ~= 'none' end
	local strength = (tonumber(ns.Get('threatStrength')) or 80) / 100
	local took = ns.Rumble(strength, PULSE)
	if took then C_Timer.After(BETWEEN, function() ns.Rumble(strength, PULSE) end) end
	return took
end

local function Check(unit)
	if not Enemy(unit) then return end
	local guid = Ask(rawget(_G, 'UnitGUID'), unit)
	if not (Plain(guid) and type(guid) == 'string') then return end
	local status = Ask(rawget(_G, 'UnitThreatSituation'), 'player', unit)
	if not Plain(status) then return end
	local mine = type(status) == 'number' and status >= 2
	if not mine then
		on[guid] = nil
	elseif not on[guid] then
		on[guid] = true
		local now = GetTime()
		if now - last >= GAP and Wanted() then
			last = now
			Alert()
		end
	end
end

ns.On('UNIT_THREAT_LIST_UPDATE', Check)
-- (your own threat changed: each enemy with a nameplate, and the target, asked again)
ns.On('UNIT_THREAT_SITUATION_UPDATE', function(unit)
	if unit ~= 'player' then return end
	for i = 1, 40 do
		local plate = 'nameplate' .. i
		if Ask(rawget(_G, 'UnitExists'), plate) then Check(plate) end
	end
	Check('target')
end)
-- (out of combat: nothing is attacking you any more)
ns.On('PLAYER_REGEN_ENABLED', function() on = {} end)

-- The Preview Threat Alert button.
function ns.ThreatTest()
	if not Alert(true) then
		ns.Print('No gamepad in use, or the game did not let the gamepad rumble.')
	elseif not ns.Get('threatRumble') then
		ns.Print('Preview only: Rumble When I Pull Threat is disabled.')
	end
end
