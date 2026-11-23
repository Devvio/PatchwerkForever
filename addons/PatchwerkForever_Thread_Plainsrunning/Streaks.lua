-- Immersive Plainsrunning (Thread): the effects at full speed, and the speed streaks among them.
--
-- Every effect hangs from one frame on WorldFrame, not UIParent, so they show while the interface is
-- faded away. They come in together over half a second and go in less; how strongly they show is one
-- number for all of them. Each can be turned on or off by itself, and they add up: streaks, wind, dust,
-- rings and a glow may all show at once, over the darkened edges.
--
-- The speed streaks: lines of light rush outward from a point a little above the middle of the screen
-- (where the way ahead meets the horizon, the camera being behind you; Way.lua may lean it sideways
-- toward where your route goes next), longer, thicker and faster the further out they are, as things
-- going past do. A clear space is kept in the middle, so you still see your character and where you
-- are going. Each streak is a Line (a texture drawn between two points), the picture Media/streak
-- (made by tools/media.py): faint at its inner end and bright toward its outer.
--
-- The other effects are in Effects.lua; each puts itself in ns.effects.
local ADDON, ns = ...
if not ns.linked then return end

ns.MEDIA = 'Interface\\AddOns\\' .. ADDON .. '\\Media\\'
ns.effects = ns.effects or {}         -- { key = the setting that turns it on, Step = function(look), Clear = function() }
local COME, GO = 0.6, 0.35            -- seconds to come in and to go
local TAU = math.pi * 2

local overlay, vignette
local streaks = {}                    -- { line, angle, out (how far out its head is), speed, bright, wide }
local strength = 0                    -- how strongly they show now, 0..1
local look = {}                       -- what every effect is told each moment (see ns.StreaksStep)

local function Build()
	local parent = rawget(_G, 'WorldFrame') or UIParent
	overlay = CreateFrame('Frame', nil, parent)
	overlay:SetAllPoints(parent)
	overlay:SetFrameStrata('LOW')
	overlay:EnableMouse(false)
	vignette = overlay:CreateTexture(nil, 'BACKGROUND')
	vignette:SetTexture(ns.MEDIA .. 'vignette')
	vignette:SetAllPoints(overlay)
	vignette:SetVertexColor(0, 0, 0)
	vignette:SetBlendMode('BLEND')
	overlay:Hide()
end

local function Size()
	local w, h = overlay:GetWidth(), overlay:GetHeight()
	if not ( w and h and w > 0 and h > 0 ) then w, h = 1920, 1080 end
	return w, h, math.sqrt(w * w + h * h) / 2
end

-- a streak starts again at the clear middle, going another way
local function Spawn(s, reach, inner, anywhere)
	s.angle = math.random() * TAU
	s.out = inner + ( anywhere and math.random() * ( reach - inner ) or math.random() * reach * 0.1 )
	s.speed = 0.7 + math.random() * 0.8
	s.bright = 0.5 + math.random() * 0.5
	s.wide = 0.7 + math.random() * 0.6
end

local function Streak(i, reach, inner)
	local s = streaks[i]
	if not s then
		local line = overlay:CreateLine(nil, 'ARTWORK')
		line:SetTexture(ns.MEDIA .. 'streak')
		line:SetBlendMode('ADD')
		s = { line = line }
		streaks[i] = s
		Spawn(s, reach, inner, true)
	end
	return s
end

local function HideFrom(first)
	for i = first, #streaks do
		streaks[i].line:Hide()
	end
end

local function DrawStreaks(elapsed, pace, reach, cx, cy, inner)
	local count = ns.Get('streakCount')
	local long = reach * 0.22 * ns.Get('streakLength') / 100
	local thick = 2 * ns.Get('streakThick') / 100
	local bright = ns.Get('streakBright') / 100
	local fly = reach * 0.9 * pace * ns.Get('streakSpeed') / 100
	local r, g, b = ns.RGB(ns.Get('streakColour'))

	for i = 1, count do
		local s = Streak(i, reach, inner)
		local far = s.out / reach                                    -- 0 at the middle, 1 at the corners
		s.out = s.out + fly * s.speed * ( 0.4 + 1.6 * far ) * elapsed
		local length = long * ( 0.35 + far )
		if s.out - length > reach then
			Spawn(s, reach, inner, false)
			far = s.out / reach
			length = long * ( 0.35 + far )
		end
		local tail = math.max(inner * 0.8, s.out - length)
		local dx, dy = math.cos(s.angle), math.sin(s.angle)
		local line = s.line
		line:SetStartPoint('CENTER', overlay, cx + dx * tail, cy + dy * tail)
		line:SetEndPoint('CENTER', overlay, cx + dx * s.out, cy + dy * s.out)
		line:SetThickness(math.max(0.5, thick * s.wide * ( 0.6 + far )))
		line:SetVertexColor(r, g, b)
		-- in from nothing just past the clear middle
		local enter = math.min(1, math.max(0, ( s.out - inner ) / ( reach * 0.15 )))
		line:SetAlpha(math.min(1, strength * bright * s.bright * enter))
		line:Show()
	end
	HideFrom(count + 1)
end

-- whether any effect at all is turned on
local function AnyOn()
	if ns.Get('streaks') or ns.Get('vignette') then return true end
	for _, effect in ipairs(ns.effects) do
		if ns.Get(effect.key) then return true end
	end
	return false
end

function ns.StreaksClear()
	strength = 0
	if overlay then
		HideFrom(1)
		for _, effect in ipairs(ns.effects) do pcall(effect.Clear) end
		overlay:Hide()
	end
end

-- One moment of the game.
-- @param on    : whether the effects are wanted (enough stacks, the interface gone)
-- @param ratio : your speed now, as a share of running speed (1 = running unbuffed)
-- @return true while anything is drawn
function ns.StreaksStep(elapsed, on, ratio)
	-- how fast, and whether you are going fast enough for them at all
	local go, pace = 1, 1
	if ns.Get('streakFollow') then
		go = math.min(1, math.max(0, ( ratio - 0.95 ) / 0.25))
		pace = math.min(2.5, math.max(0.5, ratio / 1.6))
	end
	local want = ( on and AnyOn() ) and go or 0
	if want > strength then
		strength = math.min(want, strength + elapsed / COME)
	elseif want < strength then
		strength = math.max(want, strength - elapsed / GO)
	end
	if strength <= 0 then
		if overlay and overlay:IsShown() then ns.StreaksClear() end
		return false
	end
	if not overlay then Build() end
	overlay:Show()

	local w, h, reach = Size()
	-- (the point they come from: the middle, moved up by Vertical Offset, and sideways toward where
	-- your route goes next with Wind Shows The Way: Way.lua)
	local cx, cy = ns.WayOffset and ns.WayOffset(elapsed, w) or 0, h * ns.Get('streakUp') / 100
	local inner = reach * ns.Get('streakClear') / 100

	if ns.Get('streaks') then
		DrawStreaks(elapsed, pace, reach, cx, cy, inner)
	else
		HideFrom(1)
	end

	look.elapsed, look.strength, look.pace, look.ratio = elapsed, strength, pace, ratio
	look.w, look.h, look.reach, look.cx, look.cy, look.inner, look.overlay = w, h, reach, cx, cy, inner, overlay
	for _, effect in ipairs(ns.effects) do
		if ns.Get(effect.key) then effect.Step(look) else effect.Clear() end
	end

	if ns.Get('vignette') then
		vignette:SetAlpha(math.min(1, strength * ns.Get('vignetteDark') / 100))
		vignette:Show()
	else
		vignette:Hide()
	end
	return true
end

-- for the checks outside the game
function ns.StreaksOrigin() return look.cx, look.cy end
function ns.StreaksShown()
	local n = 0
	for _, s in ipairs(streaks) do
		if s.line:IsShown() then n = n + 1 end
	end
	return n, strength
end
