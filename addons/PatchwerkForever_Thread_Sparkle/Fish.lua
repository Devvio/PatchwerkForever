-- Sparkle (Thread): fishing (1.6.0).
--
-- The game tells an addon nothing when a fish bites. A probe made for 1.6.0 recorded every event and
-- what the game said of the bobber, every frame, through whole casts: nothing changes at the bite. It
-- is only the splash sound and the bobber's dip, and an addon can see neither. So Sparkle makes the
-- splash easy to hear, and says when the bobber is out:
--   Louder Splash While Fishing (off to begin with): while the Fishing channel runs, sound effects are
--     turned up (and on, where they were off) and music and ambience down. They are put back a moment
--     after the cast ends, not between two casts in a row. Only what is still as Sparkle set it is put
--     back: a volume you change while fishing stays yours. What they were is kept
--     (PatchwerkForever_Thread_SparkleDB.fishWas, with what Sparkle set in .fishSet), so a disconnect
--     mid-cast is mended at the next login.
--   Rumble When The Bobber Lands (off): the game hands the bobber to the interact key a moment after
--     the cast (within a fifth of a second, in the probe); the gamepad rumbles once then.
local ADDON, ns = ...
if not ns.linked then return end

local Plain = ns.Plain        -- (Sparkle.lua's)
local AFTER = 3               -- seconds after a cast before the sound is put back (the loot, a cast again)
local LANDS = 3               -- seconds after the cast in which any object handed to the interact key is the bobber
local BOBBER = 35591          -- the Fishing Bobber object, as its GUID names it
-- Fishing in each of the game's versions (its name is asked of the game too, for any other)
local FISHING = { [7620] = true, [7731] = true, [7732] = true, [18248] = true, [33095] = true, [51294] = true,
	[88868] = true, [131474] = true, [131476] = true, [131490] = true }
local EFFECTS, ENABLE = 'Sound_SFXVolume', 'Sound_EnableSFX'
local QUIET = { 'Sound_MusicVolume', 'Sound_AmbienceVolume' }

local fishing                 -- the cast running: { start =, landed = }
local waiting = 0             -- (a later cast or a change cancels the putting back that was waiting)

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
	if not ok then return nil end
	return a, b, c, d, e, f, g, h
end

local function SpellName(id)
	local spell = rawget(_G, 'C_Spell')
	if type(spell) == 'table' and spell.GetSpellName then return (Ask(spell.GetSpellName, id)) end
	return (Ask(rawget(_G, 'GetSpellInfo'), id))
end

local function IsFishing(id, name)
	if Plain(id) and FISHING[id] then return true end
	local fishingName = SpellName(7620)
	return Plain(name) and Plain(fishingName) and fishingName ~= nil and name == fishingName
end

local function DB()
	local db = PatchwerkForever_Thread_SparkleDB
	if type(db) ~= 'table' then return nil end
	db.fishWas = type(db.fishWas) == 'table' and db.fishWas or {}
	db.fishSet = type(db.fishSet) == 'table' and db.fishSet or {}
	return db
end

local function Get(name) return (Ask(rawget(_G, 'GetCVar'), name)) end

-- Sets a game setting for the cast, keeping what it was the first time.
local function Change(db, name, value)
	local now = Get(name)
	if now == nil then return end
	if db.fishWas[name] == nil then db.fishWas[name] = now end
	if value ~= now then Ask(rawget(_G, 'SetCVar'), name, value) end
	db.fishSet[name] = Get(name)
end

-- Puts back what Sparkle changed, where it is still as Sparkle set it.
local function Restore()
	waiting = waiting + 1
	local db = DB()
	if not db then return end
	for name, was in pairs(db.fishWas) do
		local now = Get(name)
		if now ~= nil and now == db.fishSet[name] and now ~= was then
			Ask(rawget(_G, 'SetCVar'), name, was)
		end
	end
	db.fishWas, db.fishSet = {}, {}
end

-- The sound while fishing: effects up (never down) and on, music and ambience a share of their own.
local function Loud()
	waiting = waiting + 1
	local db = DB()
	if not db then return end
	local function Own(name) return tonumber(db.fishWas[name]) or tonumber(Get(name)) end
	local effects = Own(EFFECTS)
	local want = (tonumber(ns.Get('fishEffects')) or 100) / 100
	if effects then Change(db, EFFECTS, ('%.2f'):format(math.max(effects, want))) end
	if db.fishWas[ENABLE] ~= nil or Get(ENABLE) == '0' then Change(db, ENABLE, '1') end
	local share = (tonumber(ns.Get('fishBackground')) or 0) / 100
	for _, name in ipairs(QUIET) do
		local own = Own(name)
		if own then Change(db, name, ('%.2f'):format(own * share)) end
	end
end

ns.On('UNIT_SPELLCAST_CHANNEL_START', function(unit, _, spell)
	if unit ~= 'player' then return end
	local name, _, _, _, _, _, _, id = Ask(rawget(_G, 'UnitChannelInfo'), 'player')
	if not IsFishing(spell or id, name) then return end
	fishing = { start = GetTime() }
	if ns.Get('fishLoud') then Loud() else waiting = waiting + 1 end
end)

ns.On('UNIT_SPELLCAST_CHANNEL_STOP', function(unit)
	if unit ~= 'player' or not fishing then return end
	fishing = nil
	waiting = waiting + 1
	local mine = waiting
	C_Timer.After(AFTER, function()
		if mine == waiting and not fishing then ns.Try('fishing', Restore) end
	end)
end)

-- The bobber handed to the interact key: by its GUID, or any object just after the cast.
ns.On('PLAYER_SOFT_INTERACT_CHANGED', function(_, guid)
	if not (fishing and not fishing.landed and Plain(guid) and type(guid) == 'string') then return end
	local kind, entry = guid:match('^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-')
	if kind ~= 'GameObject' then return end
	if tonumber(entry) ~= BOBBER and GetTime() - fishing.start > LANDS then return end
	fishing.landed = true
	if ns.Get('fishRumble') then ns.Rumble() end
end)

ns.OnSetting(function(key)
	if key == 'fishLoud' or key == 'fishEffects' or key == 'fishBackground' then
		if fishing and ns.Get('fishLoud') then Loud() elseif key == 'fishLoud' then Restore() end
	end
end)

-- (left over from a cast the game did not see the end of)
ns.On('PLAYER_LOGIN', function()
	Restore()
	local db = DB()
	if db then db.fishProbe = nil end                 -- (the probe's casts, from before 1.6.0 was released)
end)
ns.On('PLAYER_LOGOUT', function() fishing = nil; Restore() end)
