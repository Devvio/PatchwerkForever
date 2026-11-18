-- Thread (Races): the marker on the next checkpoint, and the words in the middle of the screen.
--
-- While a race is on, the next checkpoint is your map pin and is tracked (Race.lua). The game then draws
-- its own waypoint marker at that place in the world, and C_Navigation.GetFrame() is a frame it keeps
-- over that place on screen. This draws, at that frame, a ring lying flat on the ground with a beam of
-- light rising from it, larger as you come nearer, with the checkpoint's number and distance under it.
-- When the place is off screen the game keeps its frame at the screen's edge (WasClampedToScreen): the
-- ring is not drawn then, and the game's own arrow at the edge shows the way.
local ADDON, ns = ...
if not ns.linked then return end

local MEDIA = 'Interface\\AddOns\\' .. ADDON .. '\\Media\\'
local FLAT = 0.36             -- how tall a ring lying on the ground looks, against its width
local FAR = 40                -- yards at which the marker is drawn at Size
local NEAREST = 6             -- nearer than this it stops growing
local TEST_SECONDS = 6

local sin = math.sin

local function Fade(a)
	return a < 0 and 0 or a > 1 and 1 or a
end

local function Plain(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

---------------------------------------------------------------------------
-- The marker
---------------------------------------------------------------------------
local mark

local function Piece(file, layer)
	local t = mark:CreateTexture(nil, layer or 'ARTWORK')
	t:SetTexture(MEDIA .. file)
	t:SetBlendMode('ADD')
	return t
end

local function Mark()
	if mark then return mark end
	mark = CreateFrame('Frame', nil, UIParent)
	mark:SetFrameStrata('LOW')
	mark:SetSize(100, 100)
	mark:EnableMouse(false)
	mark:Hide()
	mark.glow = Piece('glow', 'BACKGROUND')
	mark.glow:SetPoint('CENTER', mark, 'CENTER', 0, 0)
	mark.ring = Piece('ring')
	mark.ring:SetPoint('CENTER', mark, 'CENTER', 0, 0)
	mark.pulse = Piece('ring')
	mark.pulse:SetPoint('CENTER', mark, 'CENTER', 0, 0)
	mark.beam = Piece('beam')
	mark.beam:SetPoint('BOTTOM', mark, 'CENTER', 0, 0)       -- it stands on the ring
	mark.text = mark:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	mark.text:SetPoint('TOP', mark, 'CENTER', 0, -12)
	mark.time = 0
	mark:SetScript('OnUpdate', function(self, elapsed) ns.Try('the checkpoint marker', ns.MarkerUpdate, self, elapsed) end)
	return mark
end

-- Draws nothing, while staying ready to (the frame keeps running until the place comes on screen).
local function Blank(m)
	m.glow:Hide(); m.ring:Hide(); m.pulse:Hide(); m.beam:Hide(); m.text:Hide()
end

-- The color of the marker for this kind of checkpoint ('start', 'checkpoint', 'finish').
local function Colour(kind)
	local key = kind == 'start' and 'startColour' or kind == 'finish' and 'finishColour' or 'markerColour'
	return ns.RGB(ns.Get(key))
end

-- Draws the marker at x, y (UIParent's units), for a checkpoint `far` yards away.
local function Draw(m, x, y, far, kind, words, elapsed)
	m.time = m.time + elapsed
	local t = m.time
	local base = ns.Get('markerSize') or 120
	local near = far and (far > NEAREST and far or NEAREST) or FAR
	local size = base * FAR / near
	if size > base * 4 then size = base * 4 end
	if size < base * 0.25 then size = base * 0.25 end
	local r, g, b = Colour(kind)
	m:ClearAllPoints()
	m:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', x, y + (ns.Get('markerHeight') or 0))
	m.glow:Show(); m.ring:Show(); m.pulse:Show()
	m.glow:SetSize(size * 0.9, size * 0.9 * FLAT)
	m.glow:SetVertexColor(r, g, b)
	m.glow:SetAlpha(0.35 + 0.1 * sin(t * 2))
	m.ring:SetSize(size, size * FLAT)
	m.ring:SetVertexColor(r, g, b)
	m.ring:SetAlpha(0.9)
	local u = (t * 0.6) % 1
	m.pulse:SetSize(size * (0.6 + 0.6 * u), size * (0.6 + 0.6 * u) * FLAT)
	m.pulse:SetVertexColor(r, g, b)
	m.pulse:SetAlpha(Fade(0.8 * (1 - u)))
	if ns.Get('markerBeam') then
		m.beam:SetSize(size * 0.3, size * 2.2)
		m.beam:SetVertexColor(r, g, b)
		m.beam:SetAlpha(0.55 + 0.15 * sin(t * 3))
		m.beam:Show()
	else
		m.beam:Hide()
	end
	if ns.Get('markerText') and words then
		m.text:SetText(far and ('%s  %d yd'):format(words, far) or words)
		m.text:SetTextColor(r, g, b)
		m.text:Show()
	else
		m.text:Hide()
	end
end

-- Where the game's marker for the tracked pin is on screen, in UIParent's units; nothing while it is
-- off screen, held at the edge, or not there.
local function Navigation()
	local nav = C_Navigation
	if not (nav and nav.GetFrame) then return nil end
	local frame = nav.GetFrame()
	if not frame then return nil end
	if nav.WasClampedToScreen and nav.WasClampedToScreen() then return nil end
	local x, y = frame:GetCenter()
	if not (Plain(x) and Plain(y) and type(x) == 'number' and type(y) == 'number') then return nil end
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * scale, y * scale
end

local testing = 0

function ns.MarkerUpdate(m, elapsed)
	if testing > 0 then
		Draw(m, UIParent:GetWidth() / 2, UIParent:GetHeight() * 0.55, 40 + 20 * sin(m.time), 'checkpoint', 'Checkpoint 2/5', elapsed)
		return
	end
	local aim = ns.aim
	if not (aim and ns.Get('marker')) then return m:Hide() end
	local x, y = Navigation()
	if not x then return Blank(m) end
	local far = ns.Distance(aim.point)
	if not far and C_Navigation and C_Navigation.GetDistance then
		local d = C_Navigation.GetDistance()
		if Plain(d) and type(d) == 'number' then far = d end
	end
	Draw(m, x, y, far, aim.kind, aim.words, elapsed)
end

-- Starts and stops the marker (Race.lua calls this whenever ns.aim changes).
function ns.MarkerShow()
	local m = Mark()
	if (ns.aim and ns.Get('marker')) or testing > 0 then
		m:Show()
	else
		m:Hide()
	end
	ns.GameMarker(ns.aim ~= nil and ns.Get('hideGameMarker'))
end

function ns.MarkerTest()
	testing = testing + 1
	local mine = testing
	ns.MarkerShow()
	C_Timer.After(TEST_SECONDS, function()
		if mine == testing then
			testing = 0
			ns.MarkerShow()
		end
	end)
end

-- The game's own waypoint icon and its distance, hidden while a race is on when asked for.
local hid = false
function ns.GameMarker(hide)
	local frame = rawget(_G, 'SuperTrackedFrame')
	if not (frame and frame.SetAlpha) then return end
	if hide then
		if not hid then hid = frame:GetAlpha() or 1 end
		frame:SetAlpha(0)
	elseif hid then
		frame:SetAlpha(hid)
		hid = false
	end
end

---------------------------------------------------------------------------
-- Words in the middle of the screen: the countdown, a split time, the finish
---------------------------------------------------------------------------
local banner

local function Banner()
	if banner then return banner end
	banner = CreateFrame('Frame', nil, UIParent)
	banner:SetFrameStrata('HIGH')
	banner:SetSize(600, 120)
	banner:SetPoint('CENTER', UIParent, 'CENTER', 0, 200)
	banner:EnableMouse(false)
	banner.big = banner:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
	banner.big:SetPoint('TOP', banner, 'TOP', 0, 0)
	banner.small = banner:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightLarge')
	banner.small:SetPoint('TOP', banner.big, 'BOTTOM', 0, -6)
	local fonts = GameFontNormal and GameFontNormal.GetFont and GameFontNormal:GetFont()
	if fonts then
		banner.big:SetFont(fonts, 42, 'THICKOUTLINE')
		banner.small:SetFont(fonts, 20, 'OUTLINE')
	end
	banner:SetScript('OnUpdate', function(self, elapsed)
		self.left = self.left - elapsed
		if self.left <= 0 then self:Hide() return end
		self:SetAlpha(Fade(self.left / 0.6))
	end)
	banner:Hide()
	return banner
end

-- Shows big words, and smaller under them, for `seconds`, in a color ('ffRRGGBB').
function ns.Say(big, small, colour, seconds)
	local b = Banner()
	b.big:SetText(big or '')
	b.small:SetText(small or '')
	local r, g, bl = ns.RGB(colour or 'ffffffff')
	b.big:SetTextColor(r, g, bl)
	b.small:SetTextColor(1, 1, 1)
	b.left = seconds or 2.5
	b:SetAlpha(1)
	b:Show()
end

-- While a course is made: a word on screen for each checkpoint placed.
function ns.Shown(point, kind)
	local making = ns.Making and ns.Making()
	local count = making and #making.points or 0
	ns.Say(kind == 'start' and 'Start' or ('Checkpoint ' .. (count - 1)), 'placed', ns.Get(kind == 'start' and 'startColour' or 'markerColour'), 1.5)
end
