-- Globe (Thread): a gamepad.
--
-- While the globe is open (and Gamepad Turns The Globe is on, and you are not in combat), a frame the
-- size of the window takes the gamepad: the left stick turns the globe, the right stick (up and down)
-- and the triggers zoom, the first button fits the zone at the middle of the picture (or presses the
-- mark there), the second steps out, and closes the window from the whole globe, the third turns the
-- globe to the next mark, the fourth sets or clears the map pin at the middle. Every other button
-- is passed on to whatever it is bound to. In combat the frame is hidden and the gamepad is the game's
-- again: taking and passing on buttons are things the game lets an addon do only out of combat.
--
-- The globe's key bindings (Bindings.xml) are also listed with Console Port's own, so its settings can
-- give any of them to a button.
local ADDON, ns = ...
if not (ns.linked and ns.G) then return end
local G = ns.G

local abs = math.abs
local DEAD = 0.18                     -- a stick this near its rest is at rest
local PRESS = { PAD1 = 'fit', PAD2 = 'back', PAD3 = 'next', PAD4 = 'pin' }
local HOLD = { PADLTRIGGER = 'out', PADRTRIGGER = 'in' }
local TURNS = { Movement = true, Left = true }
local ZOOMS = { Camera = true, Right = true }

local catcher
local zoomStick = 0
local state = { taken = false, why = 'closed' }

local function Live(v)
	if type(v) ~= 'number' or abs(v) < DEAD then return 0 end
	return (v - (v > 0 and DEAD or -DEAD)) / (1 - DEAD)
end

local function Wanted()
	local window = ns.GlobeWindow()
	if not (window and window:IsShown()) then return false, 'closed' end
	if not ns.Get('globePad') then return false, 'off' end
	if InCombatLockdown() then return false, 'combat' end
	return true
end

local function Stick(_, stick, x, y)
	if TURNS[stick] then
		ns.GlobePad(Live(x), Live(y), nil)
		return false
	elseif ZOOMS[stick] then
		zoomStick = Live(y)
		ns.GlobePad(nil, nil, zoomStick)
		return false
	end
	return true
end

-- A button the globe has no use for goes on to its binding. (Setting that is refused in combat; the
-- frame is hidden there.)
local function Pass(self, on)
	if self.SetPropagateKeyboardInput then pcall(self.SetPropagateKeyboardInput, self, on) end
end

local function ButtonDown(self, button)
	if PRESS[button] then
		Pass(self, false)
		if button == 'PAD2' and G.Whole() then
			ns.Toggle(false)
		else
			ns.GlobeKey(PRESS[button])
		end
	elseif HOLD[button] then
		Pass(self, false)
		ns.GlobeKey(HOLD[button], true)
	else
		Pass(self, true)
	end
end

local function ButtonUp(_, button)
	if HOLD[button] then ns.GlobeKey(HOLD[button], false) end
end

local function Make()
	local window = ns.GlobeWindow()
	catcher = CreateFrame('Frame', nil, window)
	catcher:SetAllPoints(window)
	catcher:Hide()
	catcher:SetScript('OnGamePadStick', Stick)
	catcher:SetScript('OnGamePadButtonDown', ButtonDown)
	catcher:SetScript('OnGamePadButtonUp', ButtonUp)
	catcher:SetScript('OnHide', function()
		zoomStick = 0
		ns.GlobePad(0, 0, 0)
		ns.GlobeKey('in', false)
		ns.GlobeKey('out', false)
	end)
end

-- Take the gamepad, or give it back, as things stand now.
local function Set()
	local want, why = Wanted()
	if not catcher then
		if not want then
			state.taken, state.why = false, why
			return
		end
		Make()
	end
	if want and not catcher.taking then
		-- (the game may refuse: then nothing is taken, and the keys under Key Bindings still work)
		local a = not catcher.EnableGamePadStick or pcall(catcher.EnableGamePadStick, catcher, true)
		local b = not catcher.EnableGamePadButton or pcall(catcher.EnableGamePadButton, catcher, true)
		catcher.taking = a and b
		if not catcher.taking then want, why = false, 'refused' end
	end
	catcher:SetShown(want)
	state.taken, state.why = want, want and nil or why
end

ns.GlobeOn('show', Set)
ns.GlobeOn('hide', Set)
ns.On('PLAYER_REGEN_DISABLED', function()
	if catcher then
		catcher:Hide()
		state.taken, state.why = false, 'combat'
	end
end)
ns.On('PLAYER_REGEN_ENABLED', Set)
ns.OnSetting(function(key)
	if key == 'globePad' then Set() end
end)

-- Console Port's binding list, when Console Port is here. (Its LinkEnv hands back its database; the
-- table given is not kept.)
local LISTED = { 'TOGGLE', 'ME', 'FULL', 'GOTO', 'FIT', 'BACK', 'LEFT', 'RIGHT', 'UP', 'DOWN', 'IN', 'OUT', 'PIN', 'NEXT', 'ROUTE' }
local listed = false
ns.On('PLAYER_LOGIN', function()
	local api = rawget(_G, 'CPAPI')
	if listed or not (type(api) == 'table' and api.LinkEnv and rawget(_G, 'ConsolePort')) then return end
	local ok, _, _, _, db = pcall(api.LinkEnv, ADDON, {})
	local special = ok and type(db) == 'table' and type(db.Bindings) == 'table' and db.Bindings.Special
	if type(special) ~= 'table' then return end
	listed = true
	for _, action in ipairs(LISTED) do
		local name = rawget(_G, 'BINDING_NAME_PATCHWERKFOREVER_GLOBE_' .. action)
		if name then
			special[#special + 1] = { binding = 'PATCHWERKFOREVER_GLOBE_' .. action, name = 'Globe: ' .. name,
				desc = 'Globe (Thread). ' .. name .. '.' }
		end
	end
end)

-- For the checks outside the game.
function ns.PadState()
	return { taken = state.taken, why = state.why, catcher = catcher, listed = listed }
end
