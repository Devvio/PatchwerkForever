-- Thread (Immersive Plainsrunning): the buff, and the interface fading away as it stacks up.
--
-- The stacks of the buff are read when the game says the player's auras changed (UNIT_AURA). While
-- there is anything to do (stacks enough to fade, the interface not yet back as it was, streaks still
-- on the screen, the preview) a frame runs each moment of the game; the rest of the time nothing runs.
--
-- How far the interface should be faded follows from the stacks: none below Start Fading At, all of it
-- at Fully Hidden At, a step for every stack between. It is not faded at all while one of the reasons
-- to bring it back holds (a fight, a window open, standing still, dead or on a flight, the Show key held,
-- /plains show, speed mode disabled). It moves there gently: a stack's step fades in over most of a
-- second; coming back takes a quarter of a second, and a fight brings it back at once.
--
-- Safety: the interface is only ever made see-through (UIParent's alpha), never hidden, so a click in a
-- fight still works, a /reload always brings it back, and should anything here go wrong the alpha found
-- is put back and speed mode stops until the next /reload.
--
-- Only for Tauren: on any other race nothing is read and nothing runs (the preview still plays).
-- Numbers the game keeps secret (your speed, an aura's stacks, while it restricts them, as in a fight)
-- are never counted with: a secret speed counts as the last one known, a secret aura changes nothing.
--
-- The parts you keep (Keep While Faded: the minimap and what other addons lay over it, the unit frames,
-- the chat) are told to ignore UIParent's alpha while the interface is faded, and told what they had
-- before once it is back. A frame the game protects is never changed in a fight: should the interface
-- come back during one, it is put back as it was when the fight ends (until then, ignoring an alpha
-- that is whole again changes nothing you can see).
local ADDON, ns = ...
if not ns.linked then return end

local FADE_IN, FADE_OUT = 0.8, 0.25        -- seconds for a whole fade, going away and coming back
local RUN_SPEED = 7                        -- yards a second, running unbuffed

local fade = 0                 -- how far the interface is faded now: 0 not at all .. 1 all the way
local base                     -- UIParent's alpha before this addon touched it (nil: not touching it)
local stacks = 0               -- of the buff, as last read
local stillSince               -- when you last stopped moving
local movingSince              -- when you last set off again
local resting = false          -- the interface came back for standing still, and you have not moved for long enough since
local peek, held = false, false
local test                     -- when the preview began
local broken                   -- set when something went wrong: speed mode stops
local driver

---------------------------------------------------------------------------
-- what may be read
---------------------------------------------------------------------------
-- a value the game hands over as a secret is nil here: it cannot be counted with or compared
local IsSecret = rawget(_G, 'issecretvalue')
local function Plain(value)
	if IsSecret and IsSecret(value) then return nil end
	return value
end
ns.Plain = Plain

local TAUREN = 6                            -- the race's number (UnitRace's third answer)

-- @return whether this character is a Tauren, the only race with Plainsrunning
function ns.IsTauren()
	if not rawget(_G, 'UnitRace') then return false end
	local _, file, id = UnitRace('player')
	file, id = Plain(file), Plain(id)
	return file == 'Tauren' or id == TAUREN
end

---------------------------------------------------------------------------
-- the buff
---------------------------------------------------------------------------
local function Count(n) return math.max(1, tonumber(n) or 0) end

-- @return the stacks of Plainsrunning's speed buff on you; 0 without it; nil when the game keeps the
-- auras secret just now (nothing is known, so nothing should change)
local function ReadStacks()
	local auras = rawget(_G, 'C_UnitAuras')
	if auras and auras.GetPlayerAuraBySpellID then
		local aura = auras.GetPlayerAuraBySpellID(ns.BUFF)
		if aura then
			local count = aura.applications
			if IsSecret and IsSecret(count) then return nil end
			return Count(count)
		end
	end
	-- each buff in turn: the buff by its number, or by its name should its number have changed (never
	-- the racial passive, which has the same name and no stacks)
	for i = 1, 40 do
		local name, count, id
		if auras and auras.GetAuraDataByIndex then
			local aura = auras.GetAuraDataByIndex('player', i, 'HELPFUL')
			if not aura then break end
			name, count, id = aura.name, aura.applications, aura.spellId
		elseif rawget(_G, 'UnitAura') then
			local n, _, c, _, _, _, _, _, _, spell = UnitAura('player', i, 'HELPFUL')
			if not n then break end
			name, count, id = n, c, spell
		else
			break
		end
		if IsSecret and ( IsSecret(name) or IsSecret(count) or IsSecret(id) ) then return nil end
		if id == ns.BUFF or ( name == ns.NAME and id ~= ns.PASSIVE and ( tonumber(count) or 0 ) > 0 ) then
			return Count(count)
		end
	end
	return 0
end

-- the preview: up to 30 over seven seconds, held for eight, then gone
local TEST_CLIMB, TEST_HOLD = 7, 8
local function TestStacks(now)
	local t = now - test
	if t < TEST_CLIMB then return 1 + math.floor(t / TEST_CLIMB * 29) end
	if t < TEST_CLIMB + TEST_HOLD then return 30 end
	test = nil
	ns.Print('Preview over.')
	return 0
end

local function Stacks(now)
	if test then return TestStacks(now) end
	return stacks
end

-- yards a second (while the game keeps it secret, the last speed known)
local lastSpeed = 0
local function Speed()
	if test then return RUN_SPEED * ( 1 + 0.02 * Stacks(GetTime()) ) end
	local speed = rawget(_G, 'GetUnitSpeed') and GetUnitSpeed('player')
	if IsSecret and IsSecret(speed) then return lastSpeed end
	lastSpeed = tonumber(speed) or 0
	return lastSpeed
end
ns.Speed = Speed

---------------------------------------------------------------------------
-- reasons to bring the interface back
---------------------------------------------------------------------------
-- windows the game opens; any of them shown brings the interface back
local WINDOWS = { 'WorldMapFrame', 'GameMenuFrame', 'SettingsPanel', 'InterfaceOptionsFrame', 'VideoOptionsFrame',
	'CharacterFrame', 'SpellBookFrame', 'PlayerSpellsFrame', 'PlayerTalentFrame', 'ClassTalentFrame', 'TalentFrame',
	'QuestFrame', 'QuestLogFrame', 'GossipFrame', 'MerchantFrame', 'MailFrame', 'BankFrame', 'GuildBankFrame',
	'TradeFrame', 'FriendsFrame', 'PVEFrame', 'LFGParentFrame', 'CollectionsJournal', 'AchievementFrame',
	'EncounterJournal', 'ProfessionsFrame', 'TradeSkillFrame', 'CraftFrame', 'AuctionHouseFrame', 'AuctionFrame',
	'LootFrame', 'GroupLootContainer', 'TaxiFrame', 'FlightMapFrame', 'MacroFrame', 'KeyBindingFrame',
	'ContainerFrameCombinedBags', 'StaticPopup1', 'ItemTextFrame', 'ClassTrainerFrame', 'PetStableFrame',
	'CommunitiesFrame', 'HelpFrame', 'MovieFrame', 'CinematicFrame' }
for i = 1, 13 do WINDOWS[#WINDOWS + 1] = 'ContainerFrame' .. i end

local function Shown(name)
	local frame = rawget(_G, name)
	return type(frame) == 'table' and frame.IsShown and frame:IsShown() and true or false
end

local function WindowOpen()
	for _, name in ipairs(WINDOWS) do
		if Shown(name) then return name end
	end
	local focus = rawget(_G, 'GetCurrentKeyBoardFocus') and GetCurrentKeyBoardFocus()
	if focus then return 'typing' end
	return nil
end

local function InFight()
	return InCombatLockdown() or ( rawget(_G, 'UnitAffectingCombat') and UnitAffectingCombat('player') ) and true or false
end

-- standing still and moving again, followed every moment whatever else keeps the interface
local function Moving(now)
	if Speed() > 0.1 then
		stillSince = nil
		movingSince = movingSince or now
	else
		movingSince = nil
		stillSince = stillSince or now
	end
	if not ns.Get('stillShow') then
		resting = false
	elseif not resting and stillSince and now - stillSince >= ns.Get('stillTime') then
		resting = true                                   -- (stood still long enough: back)
	elseif resting and movingSince and now - movingSince >= ns.Get('moveTime') then
		resting = false                                  -- (moved again long enough: away again)
	end
end

-- @return why the interface is being kept, or nil
local function Kept(now)
	Moving(now)
	if not ( ns.Get('enabled') or test ) then return 'speed mode is disabled' end
	if peek then return 'the Show Interface key is held' end
	if held then return '/plains show' end
	if ns.Get('combatShow') and InFight() then return 'you are in combat' end
	if ns.Get('deadShow') and ( ( rawget(_G, 'UnitIsDeadOrGhost') and UnitIsDeadOrGhost('player') )
		or ( rawget(_G, 'UnitOnTaxi') and UnitOnTaxi('player') ) ) then
		return 'you are dead or on a flight'
	end
	if ns.Get('windowShow') then
		local window = WindowOpen()
		if window then return window == 'typing' and 'you are typing' or 'a window is open (' .. window .. ')' end
	end
	if resting then
		return movingSince and 'you have only just set off again' or 'you are standing still'
	end
	return nil
end

-- @return how far the interface should be faded (0..1), whether streaks may show, and why it is kept
local function Wanted(now)
	local n = Stacks(now)
	if n <= 0 then return 0, false end
	if n < ns.Get('fadeStart') and n < ns.Get('fadeFull') and n < ns.Get('streakAt') then return 0, false end
	local why = Kept(now)
	if why then return 0, false, why end
	local from, full = ns.Get('fadeStart'), ns.Get('fadeFull')
	local want
	if n >= full then
		want = 1
	elseif n < from then
		want = 0
	else
		want = ( n - from + 1 ) / ( full - from + 1 )
	end
	return want, n >= ns.Get('streakAt')
end

---------------------------------------------------------------------------
-- the parts kept while faded
---------------------------------------------------------------------------
local KEEP = {
	keepMinimap = { 'MinimapCluster', 'Minimap' },
	keepUnits = { 'PlayerFrame', 'PetFrame', 'TargetFrame', 'TargetFrameToT' },
	keepChat = { 'GeneralDockManager', 'ChatFrameMenuButton', 'ChatFrameChannelButton' },
}
for i = 1, tonumber(rawget(_G, 'NUM_CHAT_WINDOWS')) or 10 do
	table.insert(KEEP.keepChat, 'ChatFrame' .. i)
	table.insert(KEEP.keepChat, 'ChatFrame' .. i .. 'Tab')
end
local kept = {}                -- frame -> whether it ignored its parent's alpha before this addon told it to

-- whether a frame may be changed now (a protected one: not in a fight)
local function Free(frame)
	return not ( InCombatLockdown() and frame.IsProtected and frame:IsProtected() )
end

-- Frames of other addons laid over the minimap rather than inside it (the path and the herb and ore
-- spots of Thread (Routes), for one: see its Minimap.lua) fade with the interface, not with the
-- minimap, so with the minimap kept they are kept too. They are found by where they are: a child of
-- UIParent with the minimap's size and place on the screen. Looked for again every second, as such a
-- layer may be made or moved during a run.
local LOOK_EVERY = 1
local over, looked = {}, nil

local function Near(a, b) return math.abs(a - b) < 1.5 end

local function Over()
	local now = GetTime()
	if looked and now - looked < LOOK_EVERY then return over end
	looked = now
	over = {}
	local map = rawget(_G, 'Minimap')
	if type(map) ~= 'table' or not ( map.GetCenter and UIParent.GetChildren ) then return over end
	local x, y = map:GetCenter()
	local w, h = map:GetWidth(), map:GetHeight()
	if not ( x and y and w and h ) or w <= 0 or h <= 0 then return over end
	local s = map:GetEffectiveScale()
	x, y, w, h = x * s, y * s, w * s, h * s
	for _, frame in ipairs({ UIParent:GetChildren() }) do
		if frame ~= map and frame ~= rawget(_G, 'MinimapCluster') and frame.SetIgnoreParentAlpha
			and not ( frame.IsForbidden and frame:IsForbidden() ) then
			local fx, fy = frame:GetCenter()
			local fw, fh = frame:GetWidth(), frame:GetHeight()
			if fx and fy and fw and fh then
				local fs = frame:GetEffectiveScale()
				if Near(fx * fs, x) and Near(fy * fs, y) and Near(fw * fs, w) and Near(fh * fs, h) then
					over[#over + 1] = frame
				end
			end
		end
	end
	return over
end

local want = {}                -- (the frames to keep now; one table, used again each time)

-- @param fading : whether the interface is faded now
local function Keep(fading)
	for frame in pairs(want) do want[frame] = nil end
	if fading then
		for key, names in pairs(KEEP) do
			if ns.Get(key) then
				for _, name in ipairs(names) do
					local frame = rawget(_G, name)
					if type(frame) == 'table' and frame.SetIgnoreParentAlpha then want[frame] = true end
				end
				if key == 'keepMinimap' then
					for _, frame in ipairs(Over()) do want[frame] = true end
				end
			end
		end
	end
	for frame, before in pairs(kept) do
		if not want[frame] and Free(frame) then
			frame:SetIgnoreParentAlpha(before)
			kept[frame] = nil
		end
	end
	for frame in pairs(want) do
		if kept[frame] == nil and Free(frame) then
			kept[frame] = frame.IsIgnoringParentAlpha and frame:IsIgnoringParentAlpha() or false
			frame:SetIgnoreParentAlpha(true)
		end
	end
end
local function Keeping() return next(kept) ~= nil end

---------------------------------------------------------------------------
-- the interface's alpha
---------------------------------------------------------------------------
local function Apply()
	if fade > 0 or Keeping() then Keep(fade > 0) end
	if fade > 0 then
		if not base then base = UIParent:GetAlpha() end
		local left = ns.Get('fadeLeft') / 100
		local alpha = base * ( 1 - fade * ( 1 - left ) )
		UIParent:SetAlpha(math.min(1, math.max(0, alpha)))
	elseif base then
		UIParent:SetAlpha(base)
		base = nil
	end
end

-- everything back as it was, at once
local function Restore()
	fade = 0
	if base then
		pcall(UIParent.SetAlpha, UIParent, base)
		base = nil
	end
	pcall(Keep, false)
	if ns.StreaksClear then pcall(ns.StreaksClear) end
	if ns.CameraBack then pcall(ns.CameraBack) end
end
ns.Restore = Restore

local function Step(elapsed)
	local now = GetTime()
	local want, streaks, why = Wanted(now)
	if why == 'you are in combat' then
		fade = 0                                         -- (a fight: back at once)
	elseif want > fade then
		fade = math.min(want, fade + elapsed / FADE_IN)
	elseif want < fade then
		fade = math.max(want, fade - elapsed / FADE_OUT)
	end
	Apply()
	local full = streaks and fade >= 0.999
	local drawing = ns.StreaksStep and ns.StreaksStep(elapsed, full, Speed() / RUN_SPEED)
	local camera = ns.CameraStep and ns.CameraStep(now, full)
	-- nothing left to do: stop running until the buff changes (too few stacks to fade or for effects)
	local n = Stacks(now)
	local idle = n <= 0 or not ns.Get('enabled')
		or ( n < ns.Get('fadeStart') and n < ns.Get('fadeFull') and n < ns.Get('streakAt') )
	if fade <= 0 and not drawing and not camera and not Keeping() and not test and idle then
		driver:Hide()
	end
end

local function Wake()
	if broken then return end
	if not ( ns.IsTauren() or test or fade > 0 or Keeping() ) then return end    -- (not a Tauren: nothing to do)
	driver:Show()
end
ns.Wake = Wake

driver = CreateFrame('Frame')
driver:Hide()
driver:SetScript('OnUpdate', function(_, elapsed)
	local ok, problem = pcall(Step, elapsed)
	if not ok then
		broken = true
		driver:Hide()
		Restore()
		ns.Print('a problem in speed mode, so it has stopped and your interface is back (until /reload): ' .. tostring(problem))
	end
end)

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------
local function Read()
	if not ns.IsTauren() then
		stacks = 0
		return
	end
	local now = ReadStacks()
	if now == nil then return end                    -- (secret just now: as it was)
	local before = stacks
	stacks = now
	if stacks <= 0 and before > 0 then
		held = false                                     -- (/plains show lasts one run)
		resting = false
	end
	if ns.RecordsAura and stacks ~= before then ns.RecordsAura(stacks, before) end
	if stacks > 0 or fade > 0 or Keeping() then Wake() end
end

ns.On('UNIT_AURA', function(unit)
	if unit == nil or unit == 'player' then Read() end
end)
ns.On('PLAYER_ENTERING_WORLD', Read)
ns.On('PLAYER_REGEN_DISABLED', function()
	-- a fight: the interface back this very moment, not at the next drawn frame
	if fade > 0 and ns.Get('combatShow') then
		fade = 0
		Apply()
	end
	Wake()
end)
ns.On('PLAYER_REGEN_ENABLED', Wake)
ns.On('PLAYER_LEAVING_WORLD', Restore)
ns.OnSetting(function() Wake() end)

---------------------------------------------------------------------------
-- what the commands and key bindings do
---------------------------------------------------------------------------
function ns.TestRun()
	if broken then
		ns.Print('Speed mode stopped after a problem; /reload to start it again.')
		return
	end
	test = GetTime()
	ns.Print('Preview: the stacks climb to 30 over seven seconds, then hold for eight. Close the options to see it.')
	Wake()
end

function ns.Peek(down)
	peek = down and true or false
	Wake()
end

function ns.ShowForThisRun()
	if Stacks(GetTime()) <= 0 then
		ns.Print('You have no Plainsrunning right now; the interface is not hidden.')
		return
	end
	held = true
	ns.Print('Interface back until this run ends.')
	Wake()
end

function ns.Say()
	local now = GetTime()
	local n = Stacks(now)
	if not ns.IsTauren() then
		ns.Print('Speed mode is for Tauren, and this character is not one, so it does nothing here. The preview still plays: /plains test.')
		return
	end
	local _, _, why = Wanted(now)
	ns.Print(( 'Speed mode is %s. Plainsrunning: %s. Interface faded %d%%.' ):format(
		broken and 'stopped after a problem (/reload)' or ( ns.Get('enabled') and 'enabled' or 'disabled' ),
		n > 0 and ( n .. ( n == 1 and ' stack' or ' stacks' ) ) or 'none', math.floor(fade * 100 + 0.5)))
	if why then ns.Print('The interface is kept because ' .. why .. '.') end
end

-- for the checks outside the game (tools/lua_plainsrunning.py)
function ns.State() return fade, stacks, base, driver:IsShown(), test ~= nil end
function ns.Kept(frame) return kept[frame] end
