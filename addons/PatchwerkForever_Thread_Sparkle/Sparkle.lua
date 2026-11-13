-- Thread (Sparkle): a sparkle, and a name, on the thing nearby you can use.
--
-- The game itself picks, at every moment, the one thing near you that pressing Interact would use
-- (its "soft interact" target) and gives it a nameplate. This hangs a light effect on that nameplate
-- and writes the thing's name there. Each kind of thing (a herb, a vein, a chest, a quest object,
-- anything else) has its own effect, colour, size, brightness, height and speed, set on the options
-- page. Nothing is read off the minimap and nothing is searched for: the game says what the thing is.
--
-- What kind of thing it is comes from the cursor the game would show over it (the game's own
-- SetUnitCursorTexture, the function its nameplates use for their icon). On this client the cursor
-- comes back as a named piece of a shared picture (an atlas, "Cursor_Crosshair_GatherHerbs_64"), so
-- the kind is read from words in that name; a plain file's path is read the same way. For herbs and
-- veins the names of the spots you have gathered count as well, when Thread (Routes) is installed
-- (it remembers them).
--
-- The effects are drawn from the addon's own pictures (Media, made by the tools' media.py).
--
-- While the setting is ticked two of the game's own settings are switched on, because without them
-- the game gives the thing no nameplate to hang anything on: SoftTargetNameplateInteract and
-- SoftTargetIconGameObject. What they were is kept (PatchwerkForever_Thread_SparkleDB.sparkleWas) and put back when
-- the setting is unticked.
local ADDON, ns = ...
if not ns.linked then return end

local UNIT = 'softinteract'
local MEDIA = 'Interface\\AddOns\\' .. ADDON .. '\\Media\\'
local NEEDS = { SoftTargetNameplateInteract = '1', SoftTargetIconGameObject = '1' }
local FONTS = { friz = 'Fonts\\FRIZQT__.TTF', arial = 'Fonts\\ARIALN.TTF', morpheus = 'Fonts\\MORPHEUS.TTF',
	skurri = 'Fonts\\SKURRI.TTF' }
local OUTLINES = { none = '', thin = 'OUTLINE', thick = 'THICKOUTLINE' }
local TEST_SECONDS = 6
local KIND_NAMES = { herb = 'a herb', ore = 'ore', loot = 'a chest', quest = 'a quest object', other = 'another thing' }
-- Words in a cursor's name, and what they mean. The first found wins, so "questinteract" is a quest
-- before it is a plain interaction. ("Unable..." forms, for a thing out of reach or not yet yours to
-- use, hold the same words.)
local WORDS = {
	{ 'gatherherbs', 'herb' }, { 'herb', 'herb' },
	{ 'mine', 'ore' }, { 'mining', 'ore' },
	{ 'quest', 'quest' },
	{ 'lootall', 'loot' }, { 'pickup', 'loot' }, { 'picklock', 'loot' },
	{ 'interact', 'other' }, { 'speak', 'other' }, { 'mail', 'other' }, { 'inspect', 'other' },
	{ 'item', 'other' }, { 'work', 'other' }, { 'innkeeper', 'other' }, { 'taxi', 'other' },
	{ 'trainer', 'other' }, { 'repair', 'other' }, { 'buy', 'other' },
}

local sin, floor = math.sin, math.floor

local function Plain(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

---------------------------------------------------------------------------
-- What kind of thing
---------------------------------------------------------------------------
local probe

-- The cursor the game would show over the thing, as a name to read: an atlas's name or a file's path
-- (or a file's number, which says nothing). Nothing when the game shows none.
local function Cursor()
	if not SetUnitCursorTexture then return nil end
	if not probe then
		probe = UIParent:CreateTexture(nil, 'BACKGROUND')
		probe:SetSize(1, 1)
		probe:Hide()
	end
	local ok, has = pcall(SetUnitCursorTexture, probe, UNIT, nil, true)
	if not (ok and has) then return nil end
	local atlas = probe.GetAtlas and probe:GetAtlas()
	if Plain(atlas) and atlas ~= '' then return atlas end
	local shown = probe:GetTexture()
	if Plain(shown) then return shown end
	return nil
end

local function FromWords(name)
	if type(name) ~= 'string' then return nil end
	local text = name:lower()
	for _, pair in ipairs(WORDS) do
		if text:find(pair[1], 1, true) then return pair[2] end
	end
	return nil
end

-- 'herb', 'ore', 'quest', 'loot' or 'other'; and whether that is known (true) or only assumed (false).
local function Kind()
	local name = UnitName(UNIT)
	if type(name) == 'string' and Plain(name) then
		-- (the route planner, when it is installed, remembers what was gathered from spots of this name)
		local routes = rawget(_G, 'PatchwerkForever_Thread_RoutesDB')
		local known = type(routes) == 'table' and routes.nodeKinds and routes.nodeKinds[name]
		if known then return known.kind == 'h' and 'herb' or 'ore', true end
	end
	local kind = FromWords(Cursor())
	if kind then return kind, true end
	return 'other', false
end

---------------------------------------------------------------------------
-- The effects
---------------------------------------------------------------------------
-- A mark is a frame holding the pictures of whichever effect it shows, and the name. An effect is a
-- list of the pictures it uses (a name for the piece, and the file) and a function called every frame
-- with the mark, the time, the size and the brightness (0 to 1), which places and fades them.
local function Fade(a)
	return a < 0 and 0 or a > 1 and 1 or a
end

local function Put(piece, m, size, alpha, turn)
	piece:SetSize(size, size)
	piece:SetAlpha(Fade(alpha))
	if turn then piece:SetRotation(turn) end
end

-- the four corners of the brackets: the piece, and which way from the middle (right, up)
local CORNERS = { { 'a', -1, 1 }, { 'b', 1, 1 }, { 'c', -1, -1 }, { 'd', 1, -1 } }

-- For the subtle effects (2026-11-12, asked for as "subtle and immersive"): small, slow and
-- faint, meant to look like something in the world and not like a marker laid over it.
local PI, cos = math.pi, math.cos
local LETTERS = { 'a', 'b', 'c', 'd', 'e', 'f' }
local FLAT = 0.36             -- how tall a ring lying on the ground looks, against its width

-- A number from 0 to 1, always the same for the same two numbers: where and when each speck shows
-- looks like chance without anything being remembered.
local function Chance(i, n)
	local v = sin(i * 12.9898 + n * 78.233) * 43758.5453
	return v - floor(v)
end

-- Puts a piece at a place off the mark's middle.
local function Spot(piece, m, x, y, size, alpha)
	if size < 1 then size = 1 end
	piece:SetSize(size, size)
	piece:SetAlpha(Fade(alpha))
	piece:ClearAllPoints()
	piece:SetPoint('CENTER', m, 'CENTER', x, y)
end

-- How far through its turn a speck is: which turn it is (a whole number) and how far through (0 to 1).
local function Turn(t, long, late)
	local turn = t / long + late
	local n = floor(turn)
	return n, turn - n
end

local EFFECTS = {
	star = { pieces = { { 'a', 'star' }, { 'b', 'star' } }, white = { b = true },
		tick = function(m, p, t, s, a)
			Put(p.a, m, s, a * (0.62 + 0.30 * sin(t * 2.4)), t * 0.5)
			Put(p.b, m, s * 0.6, a * (0.60 + 0.40 * sin(t * 5.1 + 1)), -t * 0.9)
		end },
	glow = { pieces = { { 'a', 'glow' } },
		tick = function(m, p, t, s, a)
			Put(p.a, m, s * (0.92 + 0.08 * sin(t * 2.0)), a * (0.70 + 0.30 * sin(t * 2.0 + 0.6)))
		end },
	ring = { pieces = { { 'a', 'glow' }, { 'b', 'ring' }, { 'c', 'ring' } },
		tick = function(m, p, t, s, a)
			Put(p.a, m, s * 0.55, a * 0.5)
			local first = (t * 0.5) % 1
			local second = (t * 0.5 + 0.5) % 1
			Put(p.b, m, s * (0.25 + 0.75 * first), a * (1 - first))
			Put(p.c, m, s * (0.25 + 0.75 * second), a * (1 - second))
		end },
	beam = { pieces = { { 'a', 'glow' }, { 'b', 'beam' } }, foot = { b = true },
		tick = function(m, p, t, s, a)
			Put(p.a, m, s * 0.6, a * 0.6)
			p.b:SetSize(s * 0.4, s * 2.4)
			p.b:SetAlpha(Fade(a * (0.75 + 0.25 * sin(t * 2.2))))
		end },
	swirl = { pieces = { { 'a', 'glow' }, { 'b', 'arcs' }, { 'c', 'arcs' } },
		tick = function(m, p, t, s, a)
			Put(p.a, m, s * 0.4, a * 0.35)
			Put(p.b, m, s, a * 0.9, t * 1.3)
			Put(p.c, m, s * 0.66, a * 0.7, -t * 1.7)
		end },
	brackets = { pieces = { { 'a', 'bracket' }, { 'b', 'bracket' }, { 'c', 'bracket' }, { 'd', 'bracket' } },
		-- one corner drawn, the other three mirrored: left, right, top, bottom of the picture
		coords = { a = { 0, 1, 0, 1 }, b = { 1, 0, 0, 1 }, c = { 0, 1, 1, 0 }, d = { 1, 0, 1, 0 } },
		tick = function(m, p, t, s, a)
			local out = s * (0.34 + 0.04 * sin(t * 3.0))
			local size, alpha = s * 0.26, Fade(a * (0.80 + 0.20 * sin(t * 3.0)))
			for _, corner in ipairs(CORNERS) do
				local piece = p[corner[1]]
				piece:SetSize(size, size)
				piece:SetAlpha(alpha)
				piece:ClearAllPoints()
				piece:SetPoint('CENTER', m, 'CENTER', corner[2] * out, corner[3] * out)
			end
		end },
	-- The subtle ones.
	-- A few fine twinkles, each flaring for a moment at a spot of its own and gone again: light on dew.
	glints = { pieces = { { 'a', 'glint' }, { 'b', 'glint' }, { 'c', 'glint' }, { 'd', 'glint' }, { 'e', 'glint' } },
		white = { b = true, d = true },
		tick = function(m, p, t, s, a)
			for i, key in ipairs(LETTERS) do
				local piece = p[key]
				if piece then
					local n, u = Turn(t, 1.7 + 0.35 * i, i * 0.37)
					local flare = u < 0.4 and sin(u / 0.4 * PI) or 0
					Spot(piece, m, (Chance(i, n) - 0.5) * s * 0.7, (Chance(i + 9, n) - 0.5) * s * 0.45,
						s * (0.10 + 0.12 * flare), a * 0.85 * flare * flare)
				end
			end
		end },
	-- Specks of light drifting slowly up and swaying, each fading in and out: fireflies, or pollen.
	fireflies = { pieces = { { 'a', 'mote' }, { 'b', 'mote' }, { 'c', 'mote' }, { 'd', 'mote' }, { 'e', 'mote' }, { 'f', 'mote' } },
		tick = function(m, p, t, s, a)
			for i, key in ipairs(LETTERS) do
				local piece = p[key]
				if piece then
					local n, u = Turn(t, 3.2 + 0.5 * i, i * 0.29)
					Spot(piece, m, (Chance(i, n) - 0.5) * s * 0.7 + sin(t * 0.9 + i * 2.1) * s * 0.05,
						(Chance(i + 5, n) - 0.6) * s * 0.3 + u * s * 0.35,
						s * (0.06 + 0.03 * Chance(i + 3, n)),
						a * 0.75 * sin(u * PI) * (0.75 + 0.25 * sin(t * 6 + i)))
				end
			end
		end },
	-- A faint light that breathes, and now and then one fine twinkle in it.
	shimmer = { pieces = { { 'a', 'glow' }, { 'b', 'glint' } }, white = { b = true },
		tick = function(m, p, t, s, a)
			Put(p.a, m, s * (0.62 + 0.05 * sin(t * 0.9)), a * (0.20 + 0.09 * sin(t * 1.1)))
			local n, u = Turn(t, 3.7, 0)
			local flare = u < 0.18 and sin(u / 0.18 * PI) or 0
			Spot(p.b, m, (Chance(1, n) - 0.5) * s * 0.3, (Chance(2, n) - 0.5) * s * 0.2, s * (0.10 + 0.10 * flare), a * 0.7 * flare)
		end },
	-- Rings lying flat on the ground, widening and fading: a ripple on still water.
	ripple = { pieces = { { 'a', 'ring' }, { 'b', 'ring' }, { 'c', 'glow' } },
		tick = function(m, p, t, s, a)
			local first, second = (t * 0.3) % 1, (t * 0.3 + 0.5) % 1
			local w = s * (0.25 + 0.75 * first)
			p.a:SetSize(w, w * FLAT)
			p.a:SetAlpha(Fade(a * 0.5 * (1 - first) * (first < 0.15 and first / 0.15 or 1)))
			w = s * (0.25 + 0.75 * second)
			p.b:SetSize(w, w * FLAT)
			p.b:SetAlpha(Fade(a * 0.5 * (1 - second) * (second < 0.15 and second / 0.15 or 1)))
			p.c:SetSize(s * 0.5, s * 0.5 * FLAT)
			p.c:SetAlpha(Fade(a * 0.18))
		end },
	-- One small light going slowly round the thing with a short tail behind it, fainter on the far side.
	wisp = { pieces = { { 'a', 'mote' }, { 'b', 'mote' }, { 'c', 'mote' }, { 'd', 'mote' } }, white = { a = true },
		tick = function(m, p, t, s, a)
			for i, key in ipairs(LETTERS) do
				local piece = p[key]
				if piece then
					local angle = t * 1.1 - (i - 1) * 0.28
					local depth = sin(angle)                      -- 1 at the back, -1 at the front
					Spot(piece, m, cos(angle) * s * 0.36, depth * s * 0.12 + sin(t * 0.7) * s * 0.02,
						s * (0.11 - 0.022 * (i - 1)) * (1 - 0.2 * depth),
						a * (0.85 - 0.2 * (i - 1)) * (0.75 - 0.25 * depth))
				end
			end
		end },
	none = { pieces = {}, tick = function() end },
}

-- A mark comes in softly, not all at once: how bright it is so soon after it showed (0 to 1).
local ARRIVE = 0.35           -- seconds
local function Arrived(m)
	return m.age < ARRIVE and m.age / ARRIVE or 1
end

-- Starts a mark's coming in over again (it has just shown, or it is on another thing now).
local function Arrive(m)
	m.age, m.arriving = 0, true
	m.name:SetAlpha(0)
end

---------------------------------------------------------------------------
-- Behind your character
---------------------------------------------------------------------------
-- An addon draws on top of the game's finished picture, so a sparkle can never truly pass behind
-- anything. This stands in for it (2026-11-11): the sparkle fades as it comes over
-- the place on screen where your character stands. Where that is, is worked out, not known. The camera
-- looks at your character's head, so the body hangs below the middle of the screen, and it looks
-- smaller the further out the camera is. The options page has sliders to correct the guess and a button
-- that shows it. It fades the whole sparkle, and it takes the thing to be on the far side of you.
local BODY_YARDS = 2.2        -- the camera distance, in yards, at which a character would fill the screen top to bottom
local NEAREST = 1.5           -- nearer than this the camera is inside your head: there is nothing to be behind
local HEAD = 0.8              -- how far the oval's middle hangs under the camera's aim, in half-heights
local INNER, OUTER = 0.8, 1.2 -- fully covered inside this share of the oval, not at all outside that one
local RING = 0.82             -- how much of ring.tga its circle spans
local ASSUMED = 15            -- the camera distance taken where the game does not tell it

-- How far out the camera is, in yards, and whether the game said so. (GetCameraZoom is an old function
-- the game's own interface never calls, so its being on this client is not known from the source.)
local function Zoom()
	local zoom = GetCameraZoom and GetCameraZoom()
	if Plain(zoom) and type(zoom) == 'number' then return zoom, true end
	return ASSUMED, false
end

-- The oval your character fills on screen: its middle and half its width and height, in the units of
-- a frame of scale 1. Nothing when the camera is too close.
local function Body()
	local zoom = Zoom()
	if zoom < NEAREST then return nil end
	local scale = UIParent:GetEffectiveScale()
	local w, h = UIParent:GetWidth() * scale, UIParent:GetHeight() * scale
	local tall = BODY_YARDS / zoom * (ns.Get('sparkleBehindSize') or 100) / 100
	if tall > 0.95 then tall = 0.95 end
	local hh = tall * h / 2
	local hw = hh * (ns.Get('sparkleBehindWide') or 50) / 100
	local cx = w / 2 + w * (ns.Get('sparkleBehindAcross') or 0) / 100
	local cy = h / 2 - hh * HEAD + h * (ns.Get('sparkleBehindUp') or 0) / 100
	return cx, cy, hw, hh
end

-- How far a mark is over your character: 0 (clear of it) to 1 (right over it).
local function Covered(m)
	local cx, cy, hw, hh = Body()
	if not cx then return 0 end
	local x, y = m:GetCenter()
	if not (Plain(x) and Plain(y)) then return nil end    -- no place yet, or one the game keeps to itself
	local scale = m:GetEffectiveScale()
	local dx, dy = (x * scale - cx) / hw, (y * scale - cy) / hh
	local d = (dx * dx + dy * dy) ^ 0.5
	return Fade((OUTER - d) / (OUTER - INNER))
end

-- Fades a mark by how far it is over your character. Where the game will not say where the mark is,
-- it stays as bright as it was.
local function Tuck(m)
	local ok, covered = pcall(Covered, m)
	if not ok or type(covered) ~= 'number' then
		m.unplaced, covered = true, 0
	else
		m.unplaced = nil
	end
	m.covered = covered
	local left = (ns.Get('sparkleBehindLeft') or 0) / 100
	m:SetAlpha(Fade(1 - covered * (1 - left)))
end

local function NewMark()
	local m = CreateFrame('Frame', nil, UIParent)
	m:SetSize(100, 100)
	m:EnableMouse(false)
	m:Hide()
	m.pieces, m.time, m.effect, m.age = {}, 0, nil, ARRIVE
	m.name = m:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	m:SetScript('OnUpdate', function(self, elapsed)
		local look = self.look
		if not look then return end
		self.time = self.time + elapsed * look.speed
		self.age = self.age + elapsed
		local arrived = Arrived(self)
		look.def.tick(self, self.parts, self.time, look.size, look.bright * arrived)
		if self.arriving then
			self.name:SetAlpha(arrived)
			self.arriving = arrived < 1
		end
		if self.behind then Tuck(self) end
	end)
	return m
end

-- The look of a kind of thing, from the settings.
local function Look(kind)
	local key = 'look.' .. kind .. '.'
	local effect = ns.Get(key .. 'effect')
	local r, g, b = ns.RGB(ns.Get(key .. 'colour'))
	return { effect = effect, def = EFFECTS[effect] or EFFECTS.star, r = r, g = g, b = b,
		size = ns.Get(key .. 'size') or 110, bright = (ns.Get(key .. 'bright') or 100) / 100,
		height = ns.Get(key .. 'height') or -40, speed = (ns.Get(key .. 'speed') or 100) / 100 }
end

-- Dresses a mark in a look: the pictures of its effect shown and tinted, the others hidden.
local function Dress(m, look)
	for _, piece in pairs(m.pieces) do piece:Hide() end
	m.parts = {}
	local def = look.def
	for _, entry in ipairs(def.pieces) do
		local key, file = entry[1], entry[2]
		local id = (look.effect or 'star') .. '.' .. key
		local piece = m.pieces[id]
		if not piece then
			piece = m:CreateTexture(nil, 'ARTWORK')
			piece:SetTexture(MEDIA .. file)
			piece:SetBlendMode('ADD')
			local c = def.coords and def.coords[key]
			if c then piece:SetTexCoord(c[1], c[2], c[3], c[4]) end
			piece:ClearAllPoints()
			if def.foot and def.foot[key] then
				piece:SetPoint('BOTTOM', m, 'CENTER', 0, 0)      -- it stands on the thing
			else
				piece:SetPoint('CENTER', m, 'CENTER', 0, 0)
			end
			m.pieces[id] = piece
		end
		if def.white and def.white[key] then
			piece:SetVertexColor(1, 1, 1)
		else
			piece:SetVertexColor(look.r, look.g, look.b)
		end
		piece:Show()
		m.parts[key] = piece
	end
	m.look = look
	m:SetSize(look.size, look.size)
	def.tick(m, m.parts, m.time, look.size, look.bright * Arrived(m))
end

-- Writes the name on a mark, by the settings, standing by `anchor` (the nameplate, or the mark itself).
local function Write(m, anchor, text, look)
	local fs = m.name
	if not (ns.Get('sparkleName') and type(text) == 'string') then
		fs:Hide()
		return
	end
	local game = GameFontNormal and GameFontNormal.GetFont and GameFontNormal:GetFont()
	local path = FONTS[ns.Get('nameFont')] or game
	local flags = OUTLINES[ns.Get('nameOutline')] or 'OUTLINE'
	local size = ns.Get('nameSize') or 13
	if not (path and fs:SetFont(path, size, flags)) and game then
		fs:SetFont(game, size, flags)                     -- a font this client does not have: the game's own
	end
	if ns.Get('nameColour') == 'fixed' then
		fs:SetTextColor(ns.RGB(ns.Get('nameFixed')))
	else
		fs:SetTextColor(look.r, look.g, look.b)
	end
	local far = ns.Get('nameOffset') or 14
	fs:ClearAllPoints()
	if ns.Get('namePlace') == 'above' then
		fs:SetPoint('BOTTOM', anchor, 'CENTER', 0, far)
	else
		fs:SetPoint('TOP', anchor, 'CENTER', 0, -far)
	end
	fs:SetText(text)
	fs:Show()
end

---------------------------------------------------------------------------
-- The thing pointed at
---------------------------------------------------------------------------
local live

local function Hide()
	if live and live:IsShown() then live:Hide() end
end

-- A thing of a known kind always; one whose kind the game did not tell as well (better a sparkle too
-- many than none); a plain "use this" thing (a mailbox, a door) only when asked for.
local function Wanted(kind, known)
	return kind ~= 'other' or not known or ns.Get('sparkleAll')
end

-- Is the game pointing at a thing in the world (not a creature or a person)? A thing does not "exist"
-- as UnitExists means it, even while the game points at it (the first in-game try, 2026-11-11: the game's
-- icon showed over a herb and UnitExists said no), so the game is asked whether it is a game object.
local function IsThing(unit)
	if UnitIsGameObject then
		local ok, yes = pcall(function() return UnitIsGameObject(unit) == true end)
		if ok then return yes end
	end
	local guid = UnitGUID(unit)
	return type(guid) == 'string' and Plain(guid) and guid:sub(1, 10) == 'GameObject'
end

-- The nameplate of the thing pointed at. Asking for it by "softinteract" is usually enough; where that
-- gives nothing, the nameplates on screen are gone through for the one that is the same thing.
local plates = {}             -- the nameplates on screen: [their unit name] = true
local function Plate()
	local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
	if not get then return nil end
	local plate = get(UNIT)
	if plate then return plate end
	for token in pairs(plates) do
		local ok, same = pcall(function() return UnitIsUnit(token, UNIT) == true end)
		if ok and same then
			plate = get(token)
			if plate then return plate end
		end
	end
	return nil
end

local function Ignored(name)
	local list = PatchwerkForever_Thread_SparkleDB and PatchwerkForever_Thread_SparkleDB.sparkleIgnored
	return name ~= nil and list ~= nil and list[name] == true
end

-- Why nothing is to be shown just now, or nil.
local fighting = false        -- (kept from the game's two events: the first comes a moment before the game says so itself)
local function Barred()
	if not ns.Get('sparkle') then return 'sparkles are disabled' end
	if ns.Get('sparkleCombat') and (fighting or (InCombatLockdown and InCombatLockdown())) then return 'you are in combat' end
	if ns.Get('sparkleInstance') and IsInInstance and IsInInstance() then return 'you are in an instance' end
	return nil
end

-- What was last pointed at and what was done about it, for /sparkle and /sparkle ignore:
-- typing on a keyboard can make the game drop what it points at (it may only point for a gamepad).
local last

local function Update()
	if Barred() or not IsThing(UNIT) then return Hide() end
	local kind, known = Kind()
	local plate = Plate()
	local name = UnitName(UNIT)
	if not Plain(name) or type(name) ~= 'string' then name = nil end
	local wanted = Wanted(kind, known) and not Ignored(name)
	last = { name = name, kind = kind, known = known, cursor = Cursor(), plate = plate ~= nil,
		shown = wanted and plate ~= nil, ignored = Ignored(name), time = GetTime() }
	if not wanted or not plate then return Hide() end
	if not live then live = NewMark() end
	if not live:IsShown() or live.thing ~= name then Arrive(live) end
	live.thing = name
	local look = Look(kind)
	Dress(live, look)
	live:SetParent(plate)
	live:ClearAllPoints()
	live:SetPoint('CENTER', plate, 'CENTER', 0, look.height)
	Write(live, plate, name, look)
	live.behind = ns.Get('sparkleBehind') and true or false
	if live.behind then
		Tuck(live)
	else
		live:SetAlpha(1)
	end
	live:Show()
end

local function Refresh()
	ns.Try('the sparkle', Update)
end

---------------------------------------------------------------------------
-- Showing one in the middle of the screen (the Test buttons)
---------------------------------------------------------------------------
local test, testing = nil, 0

function ns.SparkleTest(kind)
	if not test then test = NewMark() end
	Arrive(test)
	local look = Look(kind)
	Dress(test, look)
	test:SetParent(UIParent)
	test:SetFrameStrata('DIALOG')
	test:ClearAllPoints()
	test:SetPoint('CENTER', UIParent, 'CENTER', 0, 120)
	Write(test, test, 'This is ' .. (KIND_NAMES[kind] or kind), look)
	test:Show()
	testing = testing + 1
	local mine = testing
	C_Timer.After(TEST_SECONDS, function()
		if mine == testing then test:Hide() end
	end)
end

-- Shows, for a while, the oval your character is taken to fill (the Show button), so the sliders can
-- be set by eye. It follows the camera as you zoom.
local where, wheres = nil, 0

local function PlaceWhere(self)
	local cx, cy, hw, hh = Body()
	self:ClearAllPoints()
	if not cx then
		self.ring:Hide()
		self.text:SetText('The camera is too close: nothing fades')
		self:SetSize(200, 40)
		self:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
		return
	end
	local scale = UIParent:GetEffectiveScale()
	self.ring:Show()
	self.text:SetText('Your character is taken to be here')
	self:SetSize(2 * hw / scale / RING, 2 * hh / scale / RING)
	self:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', cx / scale, cy / scale)
end

function ns.SparkleBehindShow()
	if not where then
		where = CreateFrame('Frame', nil, UIParent)
		where:SetFrameStrata('DIALOG')
		where:EnableMouse(false)
		where.ring = where:CreateTexture(nil, 'ARTWORK')
		where.ring:SetTexture(MEDIA .. 'ring')
		where.ring:SetBlendMode('ADD')
		where.ring:SetAllPoints(where)
		where.text = where:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		where.text:SetPoint('BOTTOM', where, 'TOP', 0, 6)
		where:SetScript('OnUpdate', function(self) ns.Try('showing where your character is', PlaceWhere, self) end)
	end
	PlaceWhere(where)
	where:Show()
	wheres = wheres + 1
	local mine = wheres
	C_Timer.After(TEST_SECONDS + 4, function()
		if mine == wheres then where:Hide() end
	end)
end

-- Gives every kind of thing one of the subtle effects (the button on the first page). Only the effect
-- is changed: colours, sizes and the rest stay as you set them.
local SUBTLE = { herb = 'glints', ore = 'glints', loot = 'shimmer', quest = 'ripple', other = 'fireflies' }
function ns.SparkleSubtle()
	for _, kind in ipairs(ns.KINDS) do
		ns.Set('look.' .. kind[1] .. '.effect', SUBTLE[kind[1]] or 'shimmer')
	end
	ns.Print('Subtle preset applied: glints on herbs and ore, a faint shimmer on chests, a ground ripple on quest objects, fireflies on the rest. Change any of them under Sparkle: Looks.')
end

---------------------------------------------------------------------------
-- Things you ignore
---------------------------------------------------------------------------
local function IgnoreList()
	local db = PatchwerkForever_Thread_SparkleDB
	db.sparkleIgnored = db.sparkleIgnored or {}
	return db.sparkleIgnored
end

-- Ignores the thing the game points at, or pointed at last.
function ns.IgnoreThis()
	if not (last and last.name) then
		ns.Print('No object targeted. Walk up to one first.')
		return
	end
	IgnoreList()[last.name] = true
	ns.Print('"' .. last.name .. '" added to the ignore list. /sparkle undo to revert.')
	Refresh()
end

function ns.IgnoreUndo()
	if last and last.name and IgnoreList()[last.name] then
		IgnoreList()[last.name] = nil
		ns.Print('"' .. last.name .. '" removed from the ignore list.')
		Refresh()
	else
		ns.Print('The last targeted object is not on the ignore list. /sparkle list shows the list.')
	end
end

function ns.IgnoreSay()
	local names = {}
	for name in pairs(IgnoreList()) do names[#names + 1] = name end
	table.sort(names)
	if #names == 0 then
		ns.Print('The ignore list is empty. Target an object and type /sparkle ignore to add it.')
	else
		ns.Print('Ignored: ' .. table.concat(names, ', ') .. '.')
	end
end

function ns.IgnoreClear()
	local count = 0
	for _ in pairs(IgnoreList()) do count = count + 1 end
	PatchwerkForever_Thread_SparkleDB.sparkleIgnored = {}
	ns.Print(('Ignore list cleared (%d object(s)).'):format(count))
	Refresh()
end

---------------------------------------------------------------------------
-- The game's own settings it needs
---------------------------------------------------------------------------
local function Needs(on)
	local db = PatchwerkForever_Thread_SparkleDB
	if not (db and GetCVar and SetCVar) then return end
	db.sparkleWas = db.sparkleWas or {}
	for name, value in pairs(NEEDS) do
		local now = GetCVar(name)
		if on then
			if now ~= nil and now ~= value then
				if db.sparkleWas[name] == nil then db.sparkleWas[name] = now end
				pcall(SetCVar, name, value)
			end
		elseif db.sparkleWas[name] ~= nil then
			pcall(SetCVar, name, db.sparkleWas[name])
			db.sparkleWas[name] = nil
		end
	end
end

-- /sparkle: what the game is pointing at just now, and why it does or does not sparkle.
function ns.SparkleSay()
	local parts = {}
	for _, name in ipairs({ 'SoftTargetInteract', 'SoftTargetInteractRange', 'SoftTargetInteractArc',
		'SoftTargetNameplateInteract', 'SoftTargetIconGameObject', 'SoftTargetIconInteract' }) do
		parts[#parts + 1] = (name:gsub('SoftTarget', '')) .. ' ' .. tostring(GetCVar(name))
	end
	ns.Print('Soft-target settings: ' .. table.concat(parts, ', ') .. '.')
	local barred = Barred()
	if barred then ns.Print('Sparkles are currently hidden: ' .. barred .. '.') end
	Refresh()
	local function Told(what, was)
		ns.Print(('%s: %s; cursor: %s; type: %s%s; nameplate: %s; it %s.'):format(what,
			tostring(was.name or '(name hidden)'), tostring(was.cursor), was.kind,
			was.known and '' or ' (guessed)', was.plate and 'yes' or 'NO',
			was.ignored and 'is on your ignore list' or was.shown and 'sparkles' or 'does not sparkle'))
	end
	if ns.Get('sparkleBehind') then
		local zoom, told = Zoom()
		if not told then
			ns.Print('Fade Behind Character: camera distance is not available, so ' .. ASSUMED .. ' yards is assumed. Adjust Character Height using the Preview Area button.')
		end
		if not Body() then
			ns.Print(('Fade Behind Character: the camera is too close (%.1f yards), so nothing fades.'):format(zoom))
		elseif live and live:IsShown() and live.unplaced then
			ns.Print('Fade Behind Character: the sparkle\'s screen position is not available, so it cannot fade.')
		elseif live and live:IsShown() then
			ns.Print(('Fade Behind Character: camera distance %.0f yards; the sparkle is %d%% covered.'):format(zoom, (live.covered or 0) * 100))
		else
			ns.Print(('Fade Behind Character: enabled; camera distance %.0f yards.'):format(zoom))
		end
	end
	if IsThing(UNIT) and last then
		Told('Targeted', last)
	else
		ns.Print('No object is currently targeted for interaction (using the keyboard can clear the target).')
		if last then
			Told(('Targeted %d s ago'):format(GetTime() - last.time), last)
		else
			ns.Print('Nothing has been targeted since you logged in or reloaded. Walk up to a herb, an ore node or a chest, then try again.')
		end
	end
end

ns.On('PLAYER_SOFT_INTERACT_CHANGED', Refresh)
ns.On('NAME_PLATE_UNIT_ADDED', function(token)
	if type(token) == 'string' then plates[token] = true end
	Refresh()
end)
ns.On('NAME_PLATE_UNIT_REMOVED', function(token)
	if type(token) == 'string' then plates[token] = nil end
	Refresh()
end)
ns.On('PLAYER_ENTERING_WORLD', Refresh)
ns.On('PLAYER_REGEN_DISABLED', function() fighting = true; Refresh() end)
ns.On('PLAYER_REGEN_ENABLED', function() fighting = false; Refresh() end)
ns.On('PLAYER_LOGIN', function()
	Needs(ns.Get('sparkle'))
end)
ns.OnSetting(function(key, value)
	if key == 'sparkle' then Needs(value) end
	if key:find('^sparkle') or key:find('^look%.') or key:find('^name') then Refresh() end
end)
