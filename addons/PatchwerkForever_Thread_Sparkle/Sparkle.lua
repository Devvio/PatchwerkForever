-- Thread (Sparkle): a sparkle, and a name, on the thing nearby you can use.
--
-- The game itself picks, at every moment, the one thing near you that pressing Interact would use
-- (its "soft interact" target) and gives it a nameplate. This hangs a light effect on that nameplate
-- and writes the thing's name there. Each kind of thing (an herb, a vein, a chest, a quest object,
-- anything else) has its own effect, color, size, brightness, height and speed, set on the options
-- page. Nothing is read off the minimap and nothing is searched for: the game says what the thing is.
--
-- What kind of thing it is comes from the cursor the game would show over it (the game's own
-- SetUnitCursorTexture, the function its nameplates use for their icon). On this client the cursor
-- comes back as a named piece of a shared picture (an atlas, "Cursor_Crosshair_GatherHerbs_64"), so
-- the kind is read from words in that name; a plain file's path is read the same way. For herbs and
-- veins the names of the nodes you have gathered count as well, when Thread (Routes) is installed
-- (it remembers them).
--
-- The effects are drawn from the addon's own pictures (Media, made by the tools' media.py).
--
-- While Enable Sparkles is on, two of the game's own settings are turned on, because without them
-- the game gives the thing no nameplate to hang anything on: SoftTargetNameplateInteract and
-- SoftTargetIconGameObject. What they were is kept (PatchwerkForever_Thread_SparkleDB.sparkleWas) and
-- put back when the setting is disabled, and at every logout or reload, so that disabling or removing
-- the addon leaves the game as it was; the login after turns them on again.
--
-- With Sparkle With Keyboard And Mouse (on to begin with) a third is kept the same way: SoftTargetInteract,
-- which the game's Enable Interact Key option sets. At 1 (its default) the game only picks an object for
-- a gamepad; at 3 for keyboard and mouse as well (2, keyboard and mouse only, is left as it is).
local ADDON, ns = ...
if not ns.linked then return end

local UNIT = 'softinteract'
local MEDIA = 'Interface\\AddOns\\' .. ADDON .. '\\Media\\'
local NEEDS = { SoftTargetNameplateInteract = '1', SoftTargetIconGameObject = '1' }
local INTERACT, INTERACT_ON = 'SoftTargetInteract', '3'   -- (Enum.SoftTargetEnableFlags.Any)
local FONTS = { friz = 'Fonts\\FRIZQT__.TTF', arial = 'Fonts\\ARIALN.TTF', morpheus = 'Fonts\\MORPHEUS.TTF',
	skurri = 'Fonts\\SKURRI.TTF' }
local OUTLINES = { none = '', thin = 'OUTLINE', thick = 'THICKOUTLINE' }
local TEST_SECONDS = 6        -- how long a preview sparkle stays after the last change
local LINGER = 10             -- how long the fade area's oval stays after the last change, or after the options close
local REMEMBER = 20           -- seconds an object still counts as targeted after the game lets go of it (time to type)
-- The names the preview writes: a real object of each kind, so the preview reads as the real thing does.
local PREVIEW_NAMES = { herb = 'Peacebloom', ore = 'Copper Vein', loot = 'Battered Chest', quest = 'Quest Object',
	other = 'Mailbox' }
-- How /sparkle status names each kind.
local TYPES = { herb = 'Herb', ore = 'Ore', loot = 'Chest', quest = 'Quest Object', other = 'Other Object' }
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

-- Whether a value the game handed over can be read: not nil, and not one it keeps secret.
local function Plain(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end
ns.Plain = Plain

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

-- 'herb', 'ore', 'quest', 'loot' or 'other'; whether that is known (true) or only assumed (false);
-- and the cursor's name, for /sparkle debug.
local function Kind()
	local cursor = Cursor()
	local name = UnitName(UNIT)
	if type(name) == 'string' and Plain(name) then
		-- (Thread (Routes), when it is installed, remembers what was gathered from nodes of this name)
		local routes = rawget(_G, 'PatchwerkForever_Thread_RoutesDB')
		local known = type(routes) == 'table' and routes.nodeKinds and routes.nodeKinds[name]
		if known then return known.kind == 'h' and 'herb' or 'ore', true, cursor end
	end
	local kind = FromWords(cursor)
	if kind then return kind, true, cursor end
	return 'other', false, cursor
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
ns.Fade = Fade

local function Put(piece, m, size, alpha, turn)
	piece:SetSize(size, size)
	piece:SetAlpha(Fade(alpha))
	if turn then piece:SetRotation(turn) end
end

-- the four corners of the brackets: the piece, and which way from the middle (right, up)
local CORNERS = { { 'a', -1, 1 }, { 'b', 1, 1 }, { 'c', -1, -1 }, { 'd', 1, -1 } }

-- For the subtle effects (2026-11-12): small, slow and faint, meant to look like something in the
-- world and not like a marker laid over it.
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

-- Keeps where on screen the thing pointed at is (in pixels), and what kind it is, for the wisp that
-- carries what you take from it (Wisp.lua). A place the game keeps to itself is not kept.
local function Spotted(m)
	local x, y = m:GetCenter()
	if not (Plain(x) and Plain(y) and type(x) == 'number' and type(y) == 'number') then return end
	local scale = m:GetEffectiveScale()
	local spot = ns.spot or {}
	spot.x, spot.y, spot.kind, spot.time = x * scale, y * scale, m.kind, GetTime()
	ns.spot = spot
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
		if self.spotted then pcall(Spotted, self) end
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

-- The game's own icon over a nameplate, while it shows: the frame that holds it. (The game anchors
-- that frame just above the nameplate and shows or hides only its Icon; another nameplate addon may
-- hide it, and the preview's stand-in has none.)
local function Icon(plate)
	local frame = type(plate) == 'table' and rawget(plate, 'UnitFrame')
	local soft = type(frame) == 'table' and rawget(frame, 'SoftTargetFrame')
	local art = type(soft) == 'table' and rawget(soft, 'Icon')
	if art and art.IsVisible and art:IsVisible() then return soft end
	return nil
end

-- Writes the name on a mark, by the settings, standing by `anchor` (the nameplate, or the preview's
-- stand-in for one). Below Icon: under the nameplate's middle. Above Icon: over the game's icon, or
-- over the nameplate's middle when no icon shows.
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
		local icon = Icon(anchor)
		if icon then
			fs:SetPoint('BOTTOM', icon, 'TOP', 0, far)
		else
			fs:SetPoint('BOTTOM', anchor, 'CENTER', 0, far)
		end
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
	if not ns.Get('sparkle') then return 'Enable Sparkles is disabled' end
	if ns.Get('sparkleCombat') and (fighting or (InCombatLockdown and InCombatLockdown())) then
		return 'you are in combat and Hide In Combat is enabled'
	end
	if ns.Get('sparkleInstance') and IsInInstance and IsInInstance() then
		return 'you are in an instance and Hide In Instances is enabled'
	end
	return nil
end

---------------------------------------------------------------------------
-- The game's own settings it needs
---------------------------------------------------------------------------
-- Does the interact setting already include keyboard and mouse (2 or 3)?
local function Keyboard(value)
	local mode = tonumber(value)
	return mode == 2 or mode == 3
end

local function Needs(on)
	local db = PatchwerkForever_Thread_SparkleDB
	if not (db and GetCVar and SetCVar) then return end
	db.sparkleWas = db.sparkleWas or {}
	local wanted = {}
	for name, value in pairs(NEEDS) do wanted[name] = value end
	wanted[INTERACT] = INTERACT_ON
	for name, value in pairs(wanted) do
		local now = GetCVar(name)
		local want = on and (name ~= INTERACT or ns.Get('sparkleKeyboard'))
		if want then
			if now ~= nil and now ~= value and not (name == INTERACT and Keyboard(now)) then
				if db.sparkleWas[name] == nil then db.sparkleWas[name] = now end
				pcall(SetCVar, name, value)
			end
		elseif db.sparkleWas[name] ~= nil then
			pcall(SetCVar, name, db.sparkleWas[name])
			db.sparkleWas[name] = nil
		end
	end
end

-- The game can turn one of the two settings off by itself (its Interact Key Icons option does), and
-- then no object gets a nameplate. When a wanted object has none, out of combat, a setting found off
-- is turned on again and that is said, once a session for each: a setting the game keeps holding
-- down is not fought over.
local retried = {}
local function Recheck()
	if not (GetCVar and SetCVar) or (InCombatLockdown and InCombatLockdown()) then return end
	for name, value in pairs(NEEDS) do
		local now = GetCVar(name)
		if now ~= nil and now ~= value and not retried[name] then
			retried[name] = true
			Needs(true)
			ns.Print(('The game setting %s was off, so it was turned back on: sparkles need it. To stop this, disable Enable Sparkles.'):format(name))
		end
	end
end

---------------------------------------------------------------------------
-- The sparkle on it
---------------------------------------------------------------------------
-- What was last pointed at and what was done about it, for /sparkle status and the ignore list. It
-- is kept a while after the game lets go (typing on a keyboard can make the game drop what it points
-- at: it may only point for a gamepad), and built while sparkles are hidden as well, so it is never
-- an object from long ago. lost: when the game let go of it.
local last

local function Update()
	if not IsThing(UNIT) then
		if last and not last.lost then last.lost = GetTime() end
		return Hide()
	end
	local barred = Barred()
	local kind, known, cursor = Kind()
	local plate = Plate()
	local name = UnitName(UNIT)
	if not Plain(name) or type(name) ~= 'string' then name = nil end
	local ignored = Ignored(name)
	local wanted = Wanted(kind, known) and not ignored
	last = { name = name, kind = kind, known = known, cursor = cursor, plate = plate ~= nil, barred = barred,
		shown = not barred and wanted and plate ~= nil, ignored = ignored, time = GetTime() }
	if barred or not wanted then return Hide() end
	if not plate then
		Recheck()
		return Hide()
	end
	if not live then live = NewMark() end
	if not live:IsShown() or live.thing ~= name then Arrive(live) end
	live.thing, live.kind, live.spotted = name, kind, true
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

-- The object targeted now, or until a moment ago: its name; nil when there is none.
local function Targeted()
	Refresh()
	if not (last and last.name) then return nil end
	if IsThing(UNIT) or (last.lost and GetTime() - last.lost <= REMEMBER) then return last.name end
	return nil
end

---------------------------------------------------------------------------
-- The previews: a sparkle (the Preview Sparkle and Preview Name buttons) and the fade area
---------------------------------------------------------------------------
-- The options window, while it is open.
local function Panel()
	local panel = rawget(_G, 'SettingsPanel')
	if type(panel) == 'table' and panel.IsShown and panel:IsShown() then return panel end
	return nil
end

-- The preview hangs from a stand-in for a nameplate, so Vertical Offset, Position and Offset show as
-- they will in the world. The stand-in goes in the gap to the right of the options window when that
-- is wide enough for a sparkle of this size; otherwise above the middle of the screen. Both edges are
-- compared in pixels, since the window and the screen may have scales of their own.
local stand
local function Stand(size)
	if not stand then
		stand = CreateFrame('Frame', nil, UIParent)
		stand:SetSize(1, 1)
		stand:EnableMouse(false)
	end
	stand:ClearAllPoints()
	local panel = Panel()
	if panel and panel.GetRight and panel.GetTop and panel.GetBottom and UIParent.GetRight then
		local us, ps = UIParent:GetEffectiveScale(), panel:GetEffectiveScale()
		local right, edge, top, bottom = panel:GetRight(), UIParent:GetRight(), panel:GetTop(), panel:GetBottom()
		if type(right) == 'number' and type(edge) == 'number' and type(top) == 'number' and type(bottom) == 'number' then
			local gap = (edge * us - right * ps) / us
			if gap >= size + 60 then
				stand:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', (right * ps) / us + gap / 2, (top + bottom) / 2 * ps / us)
				return stand
			end
		end
	end
	stand:SetPoint('CENTER', UIParent, 'CENTER', 0, 120)
	return stand
end

local test, testing = nil, 0

-- Shows a preview sparkle of a kind for a few seconds, as a real one is laid out. keep: it is the
-- same preview again after a change of setting, so it does not come in over again.
function ns.SparkleTest(kind, keep)
	if not test then test = NewMark() end
	if not (keep and test:IsShown() and test.kind == kind) then Arrive(test) end
	test.kind = kind
	local look = Look(kind)
	Dress(test, look)
	local spot = Stand(look.size)
	test:SetParent(UIParent)
	test:SetFrameStrata('DIALOG')
	test:ClearAllPoints()
	test:SetPoint('CENTER', spot, 'CENTER', 0, look.height)
	Write(test, spot, PREVIEW_NAMES[kind] or kind, look)
	test:Show()
	testing = testing + 1
	local mine = testing
	C_Timer.After(TEST_SECONDS, function()
		if mine == testing then test:Hide() end
	end)
end

-- While the options are open the preview follows the settings. Changes made in the same moment are
-- taken together on the next frame: one kind's look changed shows that kind; only a name setting
-- changed shows the preview showing, or an herb; many kinds at once (Reset To Defaults, the subtle
-- preset) only redress a preview already showing.
local follow
local function Follow(key)
	if not Panel() then return end
	local kind = key:match('^look%.(%a+)%.')
	if not (kind or key:find('^name') or key == 'sparkleName') then return end
	if not follow then
		follow = { kinds = {} }
		C_Timer.After(0, function()
			local kinds, count, one = follow.kinds, 0, nil
			follow = nil
			for k in pairs(kinds) do count, one = count + 1, k end
			local showing = test and test:IsShown() and test.kind
			if count == 1 then
				ns.SparkleTest(one, true)
			elseif count == 0 then
				ns.SparkleTest(showing or 'herb', true)
			elseif showing then
				ns.SparkleTest(showing, true)
			end
		end)
	end
	if kind then follow.kinds[kind] = true end
end

-- Shows the oval your character is taken to fill (the Show button), so the sliders can be set by eye.
-- It follows the camera and the sliders as they change, and stays for a while after the last change
-- and after the options close (Linger), so you can compare it with your character, whom the options
-- window hides.
local where, wheres = nil, 0

local function Linger()
	wheres = wheres + 1
	local mine = wheres
	C_Timer.After(LINGER, function()
		if mine == wheres and where then where:Hide() end
	end)
end

local function PlaceWhere(self)
	local open = Panel() ~= nil
	if self.open and not open then Linger() end
	self.open = open
	local cx, cy, hw, hh = Body()
	self:ClearAllPoints()
	if not cx then
		self.ring:Hide()
		self.text:SetText('Camera too close: no fading')
		self:SetSize(200, 40)
		self:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
		return
	end
	local scale = UIParent:GetEffectiveScale()
	self.ring:Show()
	self.text:SetText(select(2, Zoom()) and 'Fade Area' or ('Fade Area (camera distance not available: %d yards assumed)'):format(ASSUMED))
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
		where:SetScript('OnUpdate', function(self) ns.Try('showing the fade area', PlaceWhere, self) end)
	end
	PlaceWhere(where)
	where:Show()
	Linger()
end

-- Gives every kind of object one of the subtle effects (the button on the first page). Only the effect
-- is changed: colors, sizes and the rest stay as you set them.
local SUBTLE = { herb = 'glints', ore = 'glints', loot = 'shimmer', quest = 'ripple', other = 'fireflies' }
function ns.SparkleSubtle()
	for _, kind in ipairs(ns.KINDS) do
		ns.Set('look.' .. kind[1] .. '.effect', SUBTLE[kind[1]] or 'shimmer')
	end
	ns.Print('Subtle preset applied: glints on herbs and ore, a faint shimmer on chests, a ground ripple on quest objects, fireflies on the rest. Change any of them under ' .. ns.APPEARANCE .. '.')
end

---------------------------------------------------------------------------
-- Objects you ignore
---------------------------------------------------------------------------
local undo                    -- the name of the object ignored last, for /sparkle undo

local function IgnoreList()
	local db = PatchwerkForever_Thread_SparkleDB
	db.sparkleIgnored = db.sparkleIgnored or {}
	return db.sparkleIgnored
end

local function Objects(count)
	return count == 1 and '1 object' or ('%d objects'):format(count)
end

local function Add(name, key)
	IgnoreList()[name] = true
	undo = name
	ns.Print(('"%s" added to the ignore list. %s'):format(name,
		key and 'Press the key again to remove it.' or 'Type /sparkle undo to remove it.'))
	Refresh()
end

local function Remove(name)
	IgnoreList()[name] = nil
	if undo == name then undo = nil end
	ns.Print(('"%s" removed from the ignore list.'):format(name))
	Refresh()
end

local function NoTarget()
	ns.Print('No object targeted. Walk up to one first.')
end

-- /sparkle ignore: adds the object targeted now, or a moment ago.
function ns.IgnoreThis()
	local name = Targeted()
	if not name then return NoTarget() end
	if IgnoreList()[name] then
		ns.Print(('"%s" is already on the ignore list. /sparkle undo or the %s key binding removes it.'):format(name, ns.BINDING))
		return
	end
	Add(name, false)
end

-- The key binding: adds the targeted object, or takes it off again when it is already on the list.
function ns.IgnoreToggle()
	local name = Targeted()
	if not name then return NoTarget() end
	if IgnoreList()[name] then Remove(name) else Add(name, true) end
end

-- /sparkle undo: takes back the last ignore; with none this session, the targeted object's.
function ns.IgnoreUndo()
	local name = undo and IgnoreList()[undo] and undo
	if not name then
		local targeted = Targeted()
		name = targeted and IgnoreList()[targeted] and targeted
	end
	if name then
		Remove(name)
	else
		ns.Print('Nothing to undo: no object was ignored since you logged in, and the targeted one is not on the ignore list. /sparkle list shows the list.')
	end
end

function ns.IgnoreSay()
	local names = {}
	for name in pairs(IgnoreList()) do names[#names + 1] = name end
	table.sort(names)
	if #names == 0 then
		ns.Print(('The ignore list is empty. To add an object, walk up to it and type /sparkle ignore, or press the %s key binding.'):format(ns.BINDING))
	else
		ns.Print('Ignored: ' .. table.concat(names, ', ') .. '.')
	end
end

local function Count()
	local count = 0
	for _ in pairs(IgnoreList()) do count = count + 1 end
	return count
end

-- /sparkle clear, and the button once it has asked: empties the list at once.
function ns.IgnoreClear()
	local count = Count()
	if count == 0 then
		ns.Print('The ignore list is already empty.')
		return
	end
	PatchwerkForever_Thread_SparkleDB.sparkleIgnored = {}
	undo = nil
	ns.Print(('%s removed from the ignore list.'):format(Objects(count)))
	Refresh()
end

-- The Clear Ignore List button: asks first with the game's own yes-or-no box (nothing brings the list
-- back), where the client has one.
function ns.IgnoreClearAsk()
	local count = Count()
	local show, dialogs = rawget(_G, 'StaticPopup_Show'), rawget(_G, 'StaticPopupDialogs')
	if count == 0 or not (type(show) == 'function' and type(dialogs) == 'table') then return ns.IgnoreClear() end
	if not dialogs.PATCHWERKFOREVER_SPARKLE_CLEAR then
		dialogs.PATCHWERKFOREVER_SPARKLE_CLEAR = {
			text = 'Clear the Sparkle ignore list (%s)? This cannot be undone.',
			button1 = rawget(_G, 'YES') or 'Yes', button2 = rawget(_G, 'NO') or 'No',
			OnAccept = function() ns.Try('the ignore list', ns.IgnoreClear) end,
			timeout = 0, whileDead = true, hideOnEscape = true,
		}
	end
	show('PATCHWERKFOREVER_SPARKLE_CLEAR', Objects(count))
end

---------------------------------------------------------------------------
-- /sparkle status and /sparkle debug
---------------------------------------------------------------------------
-- Why the object recorded in `was` does not sparkle, or nil when it does.
local function WhyNot(was)
	if was.barred then return was.barred end
	if was.ignored then return 'it is on the ignore list' end
	if was.kind == 'other' and was.known and not ns.Get('sparkleAll') then
		return 'Include All Interactable Objects is disabled'
	end
	if not was.plate then
		for name, value in pairs(NEEDS) do
			local now = GetCVar and GetCVar(name)
			if now ~= nil and now ~= value then
				return ('the game gave it no nameplate (the game setting %s is off; disable and enable Enable Sparkles to turn it back on)'):format(name)
			end
		end
		return 'the game gave it no nameplate'
	end
	return nil
end

-- One plain sentence: the object, its kind, and whether it sparkles and why not.
local function Told(was)
	local why = WhyNot(was)
	return ('%s (%s): %s.'):format(was.name or 'An object whose name is not available', TYPES[was.kind] or was.kind,
		why and ('not sparkling: ' .. why) or 'sparkling')
end

-- /sparkle status: what the game is pointing at just now, and why it does or does not sparkle.
function ns.SparkleSay()
	Refresh()
	if IsThing(UNIT) and last then
		ns.Print(Told(last))
	else
		ns.Print('No object is targeted right now.')
		if last then
			ns.Print(('Last targeted %d s ago: %s'):format(floor(GetTime() - (last.lost or last.time)), Told(last)))
		else
			ns.Print('Nothing has been targeted since you logged in or reloaded. Walk up to an herb, an ore node or a chest, then try again.')
		end
		local barred = Barred()
		if barred then ns.Print('Sparkles are hidden now: ' .. barred .. '.') end
		-- (0 and 1: the game targets objects for a gamepad only; 2 and 3 include the keyboard)
		if not Keyboard(GetCVar and GetCVar(INTERACT)) then
			ns.Print(('With keyboard and mouse the game only targets objects when "%s" is on in its Controls options, or when Sparkle With Keyboard And Mouse is enabled.')
				:format(rawget(_G, 'ENABLE_INTERACT_TEXT') or 'Enable Interact Key'))
		end
	end
	if ns.Get('sparkleBehind') then
		local zoom, told = Zoom()
		if not told then
			ns.Print('Fade Behind Character: the camera distance is not available, so ' .. ASSUMED .. ' yards is assumed. Adjust Character Height using the Preview Area button.')
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
end

-- /sparkle debug: the raw values, for a bug report.
function ns.SparkleDebug()
	local parts = {}
	for _, name in ipairs({ 'SoftTargetInteract', 'SoftTargetInteractRange', 'SoftTargetInteractArc',
		'SoftTargetNameplateInteract', 'SoftTargetIconGameObject', 'SoftTargetIconInteract' }) do
		parts[#parts + 1] = name .. ' ' .. tostring(GetCVar and GetCVar(name))
	end
	ns.Print('Game interact settings: ' .. table.concat(parts, ', ') .. '.')
	Refresh()
	if not last then
		ns.Print('Nothing targeted since login.')
		return
	end
	ns.Print(('Last object: %s; targeted now: %s; type %s (%s); cursor %s; nameplate %s; shown %s; ignored %s; hidden by: %s.')
		:format(tostring(last.name), tostring(IsThing(UNIT)), last.kind, last.known and 'known' or 'guessed',
			tostring(last.cursor), last.plate and 'yes' or 'no', tostring(last.shown), tostring(last.ignored),
			tostring(last.barred or 'nothing')))
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
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
-- (put back at every logout and reload, so the game keeps its own values should the addon be gone at
-- the next login; the login turns them on again)
ns.On('PLAYER_LOGOUT', function() Needs(false) end)
ns.OnSetting(function(key, value)
	if key == 'sparkle' then Needs(value) end
	if key == 'sparkleKeyboard' then Needs(ns.Get('sparkle')) end
	if key:find('^sparkle') or key:find('^look%.') or key:find('^name') then Refresh() end
	Follow(key)
	if where and where:IsShown() and key:find('^sparkleBehind.') then Linger() end
end)
