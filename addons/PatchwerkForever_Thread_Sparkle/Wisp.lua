-- Thread (Sparkle): a wisp that carries what you pick up into your bag.
--
-- Asked for on 2026-11-16: a wisp that floats into the bag when you pick an item up. The game says when an item goes into a bag, and which bag, and the item's picture (ITEM_PUSH). A
-- small light then leaves the place the thing was and flies in a curve to that bag's button, with a
-- short tail and, if wanted, the item's picture riding along, and the bag glows as it lands.
--
-- Where it starts: the loot window, while it is open; else the place on screen of the herb, vein,
-- chest or quest object the sparkle was last on, if that was only a moment ago (Sparkle.lua keeps it in
-- ns.spot); else a little below the middle of the screen, where your character stands.
-- Where it lands: the bag's own button on the bag bar; else the open bags; else the backpack's button;
-- else the lower right corner (a UI that hides the bag bar, such as Console Port's).
--
-- Only what you loot or gather is carried, unless the setting says everything: an item bought, taken
-- from the mail, the bank or a trade is not, since the window for it is open. Nothing here is a
-- protected frame: these are plain pictures, so it works in a fight as well.
local ADDON, ns = ...
if not ns.linked then return end

local MEDIA = 'Interface\\AddOns\\' .. ADDON .. '\\Media\\'
local TAIL = 5                -- specks in the tail
local MOST = 8                -- wisps in the air at once; more items at once wait their turn
local STAGGER = 0.12          -- seconds between two wisps that leave together
local FLIGHT = 0.9            -- seconds a wisp flies at Wisp Speed 100
local GLOW = 0.45             -- seconds the bag glows
local LOOTED = 2.5            -- seconds after the loot window closes that an item still counts as looted
local FRESH = 5               -- seconds the place of a sparkle counts as where a thing was
local FALLBACK = 'ffffe680'   -- the wisp's color when the thing it came from is not known

local sin, random = math.sin, math.random
local Fade, Plain = ns.Fade, ns.Plain           -- (Sparkle.lua's)

---------------------------------------------------------------------------
-- What counts as picked up
---------------------------------------------------------------------------
local looting, closed = false, -100
local busy = {}               -- the windows open that put things in your bags without looting: [name] = true

local function Busy()
	return next(busy) ~= nil
end

local function Looted()
	return looting or GetTime() - closed <= LOOTED
end

local function Fresh()
	local spot = ns.spot
	return spot and GetTime() - spot.time <= FRESH and spot or nil
end

-- Why no wisp flies just now, or nil.
local function Barred()
	if not ns.Get('wisp') then return 'Show Loot Wisps is disabled' end
	if ns.Get('wispCombat') and InCombatLockdown and InCombatLockdown() then
		return 'you are in combat and Hide In Combat is enabled'
	end
	return nil
end

-- Whether an item that has just gone into a bag is one to carry.
local function Wanted()
	if Barred() then return false end
	if ns.Get('wispWhen') == 'all' then return true end
	if Busy() then return false end
	return Looted() or Fresh() ~= nil
end

---------------------------------------------------------------------------
-- Where a wisp starts and lands, in the units of UIParent from its lower left corner
---------------------------------------------------------------------------
local function Middle(frame)
	if not (frame and frame.IsVisible and frame:IsVisible()) then return nil end
	local x, y = frame:GetCenter()
	if not (Plain(x) and Plain(y)) then return nil end
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * scale, y * scale
end

local function Start()
	local x, y = Middle(rawget(_G, 'LootFrame'))
	if x and looting then return x, y end
	local spot = Fresh()
	if spot then
		local scale = UIParent:GetEffectiveScale()
		return spot.x / scale, spot.y / scale, spot.kind
	end
	return UIParent:GetWidth() / 2, UIParent:GetHeight() * 0.42
end

-- The bag bar's buttons: the backpack, the four bags, the reagent bag.
local BUTTONS = { [0] = 'MainMenuBarBackpackButton', 'CharacterBag0Slot', 'CharacterBag1Slot', 'CharacterBag2Slot',
	'CharacterBag3Slot', 'CharacterReagentBag0Slot' }
local OPEN = { 'ContainerFrameCombinedBags', 'ContainerFrame1' }

local function Land(bag)
	local x, y = Middle(rawget(_G, BUTTONS[tonumber(bag) or 0] or ''))
	if x then return x, y end
	for _, name in ipairs(OPEN) do
		x, y = Middle(rawget(_G, name))
		if x then return x, y end
	end
	x, y = Middle(rawget(_G, BUTTONS[0]))
	if x then return x, y end
	return UIParent:GetWidth() - 60, 60
end

---------------------------------------------------------------------------
-- The wisps
---------------------------------------------------------------------------
local sky                     -- the frame they fly over: the whole screen
local wisps, waiting = {}, {}

local function Piece(file, layer)
	local t = sky:CreateTexture(nil, layer or 'ARTWORK')
	t:SetTexture(MEDIA .. file)
	t:SetBlendMode('ADD')
	t:Hide()
	return t
end

local function Put(t, x, y, size, alpha)
	if size < 1 then size = 1 end
	t:ClearAllPoints()
	t:SetPoint('CENTER', sky, 'BOTTOMLEFT', x, y)
	t:SetSize(size, size)
	t:SetAlpha(Fade(alpha))
end

local function NewWisp()
	local w = { glow = Piece('glow'), core = Piece('mote', 'OVERLAY'), land = Piece('glow'), tail = {} }
	for i = 1, TAIL do w.tail[i] = Piece('mote') end
	w.icon = sky:CreateTexture(nil, 'OVERLAY')
	w.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	w.icon:Hide()
	return w
end

-- Slow at both ends, quick in the middle.
local function Ease(u)
	return u < 0.5 and 2 * u * u or 1 - (2 - 2 * u) * (2 - 2 * u) / 2
end

-- A point on the curve from a to b, bent by c.
local function Curve(w, u)
	local v = 1 - u
	return v * v * w.ax + 2 * v * u * w.cx + u * u * w.bx, v * v * w.ay + 2 * v * u * w.cy + u * u * w.by
end

local function Hide(w)
	w.glow:Hide(); w.core:Hide(); w.land:Hide(); w.icon:Hide()
	for _, t in ipairs(w.tail) do t:Hide() end
	w.flying = false
end

-- One frame of one wisp. Returns false once it has landed and its glow has gone.
local function Fly(w, now)
	local t = now - w.start
	if t < 0 then return true end                              -- waiting for its turn to leave
	local size = w.size
	if t < w.long then
		local u = t / w.long
		local x, y = Curve(w, Ease(u))
		local arrive = u < 0.12 and u / 0.12 or 1
		local shrink = 1 - 0.45 * u
		w.glow:Show(); w.core:Show()
		Put(w.glow, x, y, size * shrink * (0.95 + 0.08 * sin(t * 14)), 0.7 * arrive)
		Put(w.core, x, y, size * 0.32 * shrink, arrive)
		for i, speck in ipairs(w.tail) do
			local back = u - i * 0.035
			if back > 0 then
				local tx, ty = Curve(w, Ease(back))
				local sway = sin(t * 9 + i * 1.7) * size * 0.04
				speck:Show()
				Put(speck, tx + sway, ty + sway * 0.5, size * 0.28 * (1 - i / (TAIL + 1)) * shrink,
					0.75 * (1 - i / (TAIL + 1)) * arrive)
			else
				speck:Hide()
			end
		end
		if w.showIcon then
			w.icon:Show()
			Put(w.icon, x, y, size * 0.42 * shrink, Fade((0.85 - u) / 0.25) * arrive)
		end
		w.land:Hide()
		return true
	end
	-- landed: the bag glows a moment
	w.glow:Hide(); w.core:Hide(); w.icon:Hide()
	for _, speck in ipairs(w.tail) do speck:Hide() end
	local g = (t - w.long) / GLOW
	if g >= 1 then Hide(w) return false end
	w.land:Show()
	Put(w.land, w.bx, w.by, size * (0.8 + 0.9 * g), 0.9 * (1 - g))
	return true
end

local function Colour(w, r, g, b)
	w.glow:SetVertexColor(r, g, b)
	w.land:SetVertexColor(r, g, b)
	w.core:SetVertexColor(1, 1, 1)
	for _, speck in ipairs(w.tail) do speck:SetVertexColor(r, g, b) end
end

local function Tick()
	local now, any = GetTime(), false
	for _, w in ipairs(wisps) do
		if w.flying then
			if Fly(w, now) then any = true end
		end
	end
	-- (a wisp that had to wait for a free one leaves now)
	while #waiting > 0 do
		local free
		for _, w in ipairs(wisps) do
			if not w.flying then free = w break end
		end
		if not free then break end
		local job = table.remove(waiting, 1)
		job(free)
		any = true
	end
	if not any then sky:Hide() end
end

local function Sky()
	if sky then return sky end
	sky = CreateFrame('Frame', nil, UIParent)
	sky:SetAllPoints(UIParent)
	sky:SetFrameStrata('TOOLTIP')
	sky:EnableMouse(false)
	sky:Hide()
	sky:SetScript('OnUpdate', function() ns.Try('the loot wisp', Tick) end)
	return sky
end

local last = 0                -- when the last wisp was sent off, to space out several at once

-- Sends a wisp from (ax, ay) to (bx, by). kind: the kind of thing it came from, for its color; icon:
-- the item's picture.
local function Launch(ax, ay, bx, by, kind, icon)
	Sky()
	local now = GetTime()
	local leave = now > last + STAGGER and now or last + STAGGER
	last = leave
	local size = ns.Get('wispSize') or 70
	local long = FLIGHT * 100 / (ns.Get('wispSpeed') or 100)
	local r, g, b
	if ns.Get('wispColour') == 'kind' and kind then
		r, g, b = ns.RGB(ns.Get('look.' .. kind .. '.colour') or FALLBACK)
	else
		r, g, b = ns.RGB(ns.Get('wispFixed') or FALLBACK)
	end
	-- the curve bends up and to one side, a little differently each time
	local dx, dy = bx - ax, by - ay
	local far = (dx * dx + dy * dy) ^ 0.5
	local side = (random() < 0.5 and -1 or 1) * (0.18 + 0.12 * random())
	local mx, my = (ax + bx) / 2, (ay + by) / 2
	local nx, ny = 0, 1
	if far > 1 then nx, ny = -dy / far, dx / far end
	if ny < 0 then nx, ny = -nx, -ny end                       -- always bowing upward
	local cx, cy = mx + nx * far * math.abs(side) + dx * side * 0.2, my + ny * far * math.abs(side) + far * 0.12
	local function Go(w)
		w.ax, w.ay, w.bx, w.by, w.cx, w.cy = ax, ay, bx, by, cx, cy
		w.start, w.long, w.size = leave > GetTime() and leave or GetTime(), long, size
		w.showIcon = ns.Get('wispIcon') and icon ~= nil
		if w.showIcon then w.icon:SetTexture(icon) end
		Colour(w, r, g, b)
		w.flying = true
	end
	local free
	for _, w in ipairs(wisps) do
		if not w.flying then free = w break end
	end
	if not free and #wisps < MOST then
		free = NewWisp()
		wisps[#wisps + 1] = free
	end
	if free then Go(free) else waiting[#waiting + 1] = Go end
	sky:Show()
end

-- An item has gone into a bag.
local function Pushed(bag, icon)
	if not Wanted() then return end
	local ax, ay, kind = Start()
	-- (a few items from one loot window leave from about the same place, not one on top of another)
	ax, ay = ax + (random() - 0.5) * 24, ay + (random() - 0.5) * 16
	local bx, by = Land(bag)
	if not Plain(icon) then icon = nil end
	Launch(ax, ay, bx, by, kind, icon)
end

-- How many wisps are in the air, and how many wait for a free one (for the checks in tools/lua_races.py).
function ns.WispsInAir()
	local flying = 0
	for _, w in ipairs(wisps) do
		if w.flying then flying = flying + 1 end
	end
	return flying, #waiting
end

-- The Test button: a wisp from the middle of the screen to your backpack.
function ns.WispTest()
	local bx, by = Land(0)
	Launch(UIParent:GetWidth() / 2, UIParent:GetHeight() * 0.6, bx, by, ns.spot and ns.spot.kind or 'herb')
	if not ns.Get('wisp') then
		ns.Print('Preview only: Show Loot Wisps is disabled, so no wisps fly when you loot.')
	end
end

-- /sparkle wisp: what it would do, and why.
function ns.WispSay()
	local barred = Barred()
	if barred then
		ns.Print(('No loot wisps fly right now: %s.'):format(barred))
	else
		ns.Print(('Loot wisps are enabled, for %s.'):format(
			ns.Get('wispWhen') == 'all' and 'every item that enters your bags' or 'what you loot or gather'))
	end
	if Busy() then
		local open = {}
		for name in pairs(busy) do open[#open + 1] = name end
		table.sort(open)
		ns.Print('No wisps for now: ' .. table.concat(open, ', ') .. ' open.')
	end
	ns.WispTest()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- (a game that does not know an event refuses to listen for it: such a window is simply not watched)
local function Listen(event, fn)
	pcall(ns.On, event, fn)
end

ns.Try('listening for ITEM_PUSH', ns.On, 'ITEM_PUSH', function(bag, icon) ns.Try('the loot wisp', Pushed, bag, icon) end)
Listen('LOOT_READY', function() looting = true end)
Listen('LOOT_OPENED', function() looting = true end)
Listen('LOOT_CLOSED', function() looting, closed = false, GetTime() end)

-- the windows that put things in your bags without looting: opened, closed
local WINDOWS = {
	merchant = { 'MERCHANT_SHOW', 'MERCHANT_CLOSED' },
	mail = { 'MAIL_SHOW', 'MAIL_CLOSED' },
	trade = { 'TRADE_SHOW', 'TRADE_CLOSED' },
	bank = { 'BANKFRAME_OPENED', 'BANKFRAME_CLOSED' },
	['auction house'] = { 'AUCTION_HOUSE_SHOW', 'AUCTION_HOUSE_CLOSED' },
	['quest window'] = { 'QUEST_COMPLETE', 'QUEST_FINISHED' },
}
for name, pair in pairs(WINDOWS) do
	Listen(pair[1], function() busy[name] = true end)
	Listen(pair[2], function() busy[name] = nil end)
end
ns.On('PLAYER_ENTERING_WORLD', function() busy, looting = {}, false end)
