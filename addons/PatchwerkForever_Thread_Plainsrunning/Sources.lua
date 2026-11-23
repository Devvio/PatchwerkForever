-- Immersive Plainsrunning (Thread): other ways of going fast: a mount, a travel form, a flight.
--
-- Each is a setting of its own (Other Ways Of Going Fast), off until enabled, and works for every race.
-- None of them has stacks, so they are counted some here. Once you have kept going for Seconds Before
-- Fading a run begins: it counts as Plainsrunning at the first stack that does anything (Start Fading
-- At, as the options come) and climbs a stack every half second to 30, about as the buff does at a run.
-- Run.lua takes these for the buff's stacks whenever the buff has none of its own, so the fade, the
-- effects, the camera and every reason to bring the interface back are the same code for all of them,
-- and Plainsrunning wins when both apply. The run records never hear of these: they stay Plainsrunning's.
--
-- A run lasts while you are mounted, in the form or on the flight. Standing still brings the interface
-- back as it does under Plainsrunning (When Standing Still); a stop of ten seconds ends the run, as a
-- buff would run out, and the next one waits and climbs again. On a flight there is no standing still.
--
-- While one of the three is enabled, a small frame looks four times a second whether you are mounted,
-- in a form or on a flight, and for how long you have been going. With none enabled nothing runs here.
local ADDON, ns = ...
if not ns.linked then return end

-- What counts as a travel form. AN ASSUMPTION, TO BE CHECKED IN THE GAME: the names and spell numbers
-- are those of the classic game, and the form numbers those the game's own interface code names
-- (DRUID_TRAVEL_FORM = 3, DRUID_ACQUATIC_FORM = 4, SHAMAN_GHOST_WOLF_FORM = 16); none of them could be
-- read out of Forever itself.
--   form  : a shapeshift, known by its number (GetShapeshiftFormID) or by `spell` being the spell of
--           the stance bar's active button (GetShapeshiftFormInfo)
--   spell, name : without `form` it is an aura on you (a hunter's aspect), looked for by its number,
--           then by its name should the number be another here
local TRAVEL = {
	{ name = 'Travel Form', spell = 783, form = 3 },
	{ name = 'Aquatic Form', spell = 1066, form = 4 },
	{ name = 'Ghost Wolf', spell = 2645, form = 16 },
	{ name = 'Aspect of the Cheetah', spell = 5118 },
	{ name = 'Aspect of the Pack', spell = 13159 },
}

local PER_STACK = 0.5       -- seconds a stack: an assumption too, about how fast Plainsrunning stacks up at a run
local LAPSE = 10            -- seconds standing still that end a run
local EVERY = 0.25          -- seconds between looks

local Plain = ns.Plain
local IsSecret = rawget(_G, 'issecretvalue')

local formIDs, formSpells = {}, {}
for _, kind in ipairs(TRAVEL) do
	if kind.form then
		formIDs[kind.form] = true
		formSpells[kind.spell] = true
	end
end

local source                -- what you are going fast on now: 'a mount', 'a travel form', 'a flight', or nil
local goingSince            -- when you set off on it (nil while standing still)
local stillSince            -- when you last stopped
local runStart              -- when the run began (the wait over); nil: no run
local inForm, hasAura = false, false       -- a travel form, a travel aura: as last known
local dirty = true          -- the auras changed since they were last read
local failed                -- set when something went wrong here: nothing more is looked for
local watch

---------------------------------------------------------------------------
-- what you are on
---------------------------------------------------------------------------
-- asks the game; nothing when it has no such function, or the function fails
local function Ask(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c, d = pcall(fn, ...)
	if ok then return a, b, c, d end
	return nil
end

local function Mounted()
	return Plain(Ask('IsMounted')) and true or false
end

-- @return true in a travel form; false in none; nil when the game keeps it secret just now
local function Form()
	local id = Ask('GetShapeshiftFormID')
	if IsSecret and IsSecret(id) then return nil end
	if id ~= nil and formIDs[id] then return true end
	-- (the stance bar: the button that is active, by its spell)
	local count = tonumber(Plain(Ask('GetNumShapeshiftForms'))) or 0
	for i = 1, count do
		local _, active, _, spell = Ask('GetShapeshiftFormInfo', i)
		if IsSecret and ( IsSecret(active) or IsSecret(spell) ) then return nil end
		if active and spell ~= nil and formSpells[spell] then return true end
	end
	return false
end

-- @return whether an aura is there (true, false), or nil when the game keeps it secret
local function Found(fn, ...)
	if type(fn) ~= 'function' then return false end
	local ok, aura = pcall(fn, ...)
	if not ok then return false end
	if IsSecret and IsSecret(aura) then return nil end
	return aura ~= nil and aura ~= false
end

-- @return true under a travel aura; false under none; nil when that is not known. The game may keep
-- auras from addons in a fight, so there "not found" is not believed: what was known stays.
local function Aura()
	local auras = rawget(_G, 'C_UnitAuras')
	if type(auras) ~= 'table' then return false end
	-- (a shapeshift is asked for as a form; as an aura only where the game has no way to ask for forms)
	local forms = rawget(_G, 'GetShapeshiftFormID') or rawget(_G, 'GetShapeshiftFormInfo')
	local secret = false
	for _, kind in ipairs(TRAVEL) do
		if not ( kind.form and forms ) then
			local found = Found(auras.GetPlayerAuraBySpellID, kind.spell)
			if found == false then found = Found(auras.GetAuraDataBySpellName, 'player', kind.name, 'HELPFUL') end
			if found then return true end
			if found == nil then secret = true end
		end
	end
	if secret or InCombatLockdown() then return nil end
	return false
end

local function Travelling()
	local form = Form()
	if form ~= nil then inForm = form end
	if dirty then
		dirty = false
		local aura = Aura()
		if aura ~= nil then hasAura = aura end
	end
	return inForm or hasAura
end

-- @return what you are going fast on now, of the sources that are enabled; nil: nothing
local function Active()
	if ns.Get('otherFlights') and ns.OnFlight() then return 'a flight' end
	if ns.Get('otherMounts') and Mounted() then return 'a mount' end
	if ns.Get('otherForms') and Travelling() then return 'a travel form' end
	return nil
end

---------------------------------------------------------------------------
-- the run
---------------------------------------------------------------------------
local function Stop()
	local was = runStart
	source, goingSince, stillSince, runStart = nil, nil, nil, nil
	if was and ns.OtherOver then ns.OtherOver() end
end

local function Look(now)
	local on = Active()
	if not on then
		Stop()
		return
	end
	source = on                                          -- (from a form onto a mount, say: the run goes on)
	if on == 'a flight' or ns.Speed() > 0.1 then
		stillSince = nil
		goingSince = goingSince or now
		if not runStart and now - goingSince >= ns.Get('otherWait') then runStart = now end
	else
		goingSince = nil                                 -- (before the run: the wait starts over)
		stillSince = stillSince or now
		if runStart and now - stillSince >= LAPSE then
			Stop()
			return
		end
	end
	-- (below the stacks that fade anything Run.lua stops running, and no aura change wakes it for these)
	if runStart then ns.Wake() end
end

-- @return the stacks a run on another source counts as now (0: no run), and what it is on
function ns.OtherStacks(now)
	if not runStart then return 0 end
	local first = math.min(ns.Get('fadeStart'), ns.Get('fadeFull'), ns.Get('streakAt'), ns.MAX)
	return math.min(ns.MAX, math.max(1, first) + ( now - runStart ) / PER_STACK), source
end

-- @return the other sources that are enabled, as the options name them ('Mounts, Flight Paths'); nil: none
function ns.OtherEnabled()
	local list = {}
	if ns.Get('otherMounts') then list[#list + 1] = 'Mounts' end
	if ns.Get('otherForms') then list[#list + 1] = 'Travel Forms' end
	if ns.Get('otherFlights') then list[#list + 1] = 'Flight Paths' end
	return #list > 0 and table.concat(list, ', ') or nil
end

---------------------------------------------------------------------------
-- looking, while any of them is enabled
---------------------------------------------------------------------------
watch = CreateFrame('Frame')
watch:Hide()
watch.wait = 0
watch:SetScript('OnUpdate', function(self, elapsed)
	self.wait = self.wait + elapsed
	if self.wait < EVERY then return end
	self.wait = 0
	local ok, problem = pcall(Look, GetTime())
	if not ok then
		failed = true
		self:Hide()
		Stop()
		ns.Print('Mounts, travel forms and flights no longer start speed mode, because of a problem. /reload starts them again. The problem: ' .. tostring(problem))
	end
end)

local function Arrange()
	if not failed and ns.Get('enabled') and ns.OtherEnabled() then
		dirty = true
		watch:Show()
	else
		watch:Hide()
		Stop()
	end
end

ns.OnSetting(Arrange)
ns.On('PLAYER_ENTERING_WORLD', Arrange)
ns.On('UNIT_AURA', function(unit)
	if unit == nil or unit == 'player' then dirty = true end
end)
ns.On('PLAYER_REGEN_ENABLED', function() dirty = true end)

-- for the checks outside the game: what you are on, whether a run is on, whether anything is looking
function ns.OtherState() return source, runStart ~= nil, watch:IsShown() end
