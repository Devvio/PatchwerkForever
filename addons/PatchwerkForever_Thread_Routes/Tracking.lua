-- Routes (Thread): Find Herbs and Find Minerals, switched with one key.
--
-- A character with both Herbalism and Mining can have only one of the two tracking spells on at a
-- time. On this client an addon may not switch tracking by itself (C_Minimap.SetTracking is for the
-- game's own interface only: calling it from an addon has the game block the addon), so it is done
-- the way the game allows: the key binding Switch Herb/Ore Tracking presses a secure button of ours
-- that casts the other of the two spells. The button is told which one to cast whenever your tracking
-- changes, outside combat (the game lets a secure button be changed only then).
--
-- Nothing here runs on a timer and nothing calls a protected function. What the button will cast,
-- and which of the two is on, is told to the tracker (ns.TrackingMode).
local ADDON, ns = ...
if not ns.linked then return end

local HERBS, ORE = 2383, 2580  -- Find Herbs, Find Minerals
local BUTTON = 'PatchwerkForeverTrackSwitch'

local function Known(spell)
	local known = rawget(_G, 'IsPlayerSpell') or rawget(_G, 'IsSpellKnown')
	if type(known) ~= 'function' then return false end
	local ok, yes = pcall(known, spell)
	return ok and yes and true or false
end

local function SpellName(spell)
	local get = C_Spell and C_Spell.GetSpellName
	if type(get) == 'function' then
		local ok, name = pcall(get, spell)
		if ok and type(name) == 'string' then return name end
	end
	local info = rawget(_G, 'GetSpellInfo')
	if type(info) == 'function' then
		local ok, name = pcall(info, spell)
		if ok and type(name) == 'string' then return name end
	end
	return nil
end

-- Which of the two is on: 'h', 'o', or nil. (The game's tracking list, read only.)
local function Active()
	local count = C_Minimap and C_Minimap.GetNumTrackingTypes or rawget(_G, 'GetNumTrackingTypes')
	local get = C_Minimap and C_Minimap.GetTrackingInfo or rawget(_G, 'GetTrackingInfo')
	if type(count) ~= 'function' or type(get) ~= 'function' then return nil end
	local ok, n = pcall(count)
	for i = 1, (ok and type(n) == 'number') and n or 0 do
		local got, a, _, c, _, _, f = pcall(get, i)
		if got and a ~= nil then
			local spell, active
			if type(a) == 'table' then spell, active = a.spellID, a.active
			else spell, active = f, c end              -- (older clients: name, texture, active, category, nested, spellID)
			if active and spell == HERBS then return 'h' end
			if active and spell == ORE then return 'o' end
		end
	end
	return nil
end

local button = CreateFrame('Button', BUTTON, UIParent, 'SecureActionButtonTemplate')
button:Hide()
if button.RegisterForClicks then button:RegisterForClicks('AnyUp', 'AnyDown') end
local function Attr(key, value)
	if button.SetAttribute then button:SetAttribute(key, value) end
end
Attr('type', 'spell')

-- What the key will cast: the one of the two that is not on (Find Herbs when neither is).
local casts
local function Point()
	if InCombatLockdown and InCombatLockdown() then return end     -- (done when the fight ends)
	if not (Known(HERBS) and Known(ORE)) then
		Attr('spell', nil)
		casts = nil
		return
	end
	local next = Active() == 'h' and ORE or HERBS
	local name = SpellName(next)
	Attr('spell', name or next)
	casts = next
end

for _, event in ipairs({ 'PLAYER_LOGIN', 'MINIMAP_UPDATE_TRACKING', 'SPELLS_CHANGED', 'PLAYER_REGEN_ENABLED',
	'SKILL_LINES_CHANGED', 'LEARNED_SPELL_IN_TAB' }) do
	ns.Try('watching tracking', ns.On, event, function() ns.Try('the tracking key', Point) end)
end

-- For the tracker: nil for a character without both spells; else { on = 'h', 'o' or nil, key = the key
-- bound to the switch, or nil }.
function ns.TrackingMode()
	if not (Known(HERBS) and Known(ORE)) then return nil end
	local key
	local get = rawget(_G, 'GetBindingKey')
	if type(get) == 'function' then key = get('CLICK ' .. BUTTON .. ':LeftButton') end
	return { on = Active(), key = key }
end

-- (for the checks: what the key would cast now)
function ns.TrackingCasts() return casts end
