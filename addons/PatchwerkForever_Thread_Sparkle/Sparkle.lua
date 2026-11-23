-- Sparkle (Thread): a sparkle, and a name, on the thing nearby you can use.
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
-- veins the names of the nodes you have gathered count as well, when Routes (Thread) is installed
-- (it remembers them).
--
-- A dead creature the game points at sparkles too (1.4.0), as a kind of its own, when it has loot for
-- you (the game's UnitHasLootInteraction, which its own gamepad action bar asks of "softinteract"), and
-- as another when it can be skinned and the character has Skinning. No function says a corpse can be
-- skinned: it is read from the cursor the game would show (the skinning one) and from the corpse's
-- tooltip (the game's own word, UNIT_SKINNABLE_LEATHER). A living creature or a person never sparkles.
--
-- An herb for a character without Herbalism, or a vein for one without Mining, can be dimmed or hidden
-- (Herbs And Ore I Cannot Gather). The professions are asked of the game's profession book; until the
-- game says what they are, everything shows. Skill level is not looked at: nothing tells an addon
-- plainly that a node needs more skill than the character has.
--
-- 1.5.0 added: a Show tick box for each kind; Sparkle Distance (the game's reach, SoftTargetInteractRange,
-- only ever raised and put back as the other settings are); Brighter When Near (how far the node is,
-- from the spots Routes remembers); Fade While Gathering; quest corpses (UnitIsRelatedToActiveQuest);
-- four themed effects; and the probe in /sparkle debug (the tooltip's lines). The waypoint's sparkle
-- is Waypoint.lua, the alerts Cue.lua, what you passed Passed.lua.
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
local RANGE = 'SoftTargetInteractRange'   -- how far away the game picks an object (Sparkle Distance raises it)
local REACH_ASSUMED = 20      -- yards taken as the game's reach where it does not say
local REACH_MOST = 60         -- and never more than this, whatever it says
local NEAR_FULL = 4           -- yards nearer than which a sparkle is at full brightness (Brighter When Near)
local NEAR_LEAST = 0.4        -- how bright it is at the far edge of the reach, against full
local NEAR_EVERY = 0.25       -- seconds between two looks at how far away the node is
local NODE_SLACK = 8          -- yards a remembered spot may lie past the reach (it is where you stood to gather)
local GATHER_FADE = 0.25      -- how bright the sparkle and name are while you gather from the object (Fade While Gathering)
local FONTS = { friz = 'Fonts\\FRIZQT__.TTF', arial = 'Fonts\\ARIALN.TTF', morpheus = 'Fonts\\MORPHEUS.TTF',
	skurri = 'Fonts\\SKURRI.TTF' }
local OUTLINES = { none = '', thin = 'OUTLINE', thick = 'THICKOUTLINE' }
local TEST_SECONDS = 6        -- how long a preview sparkle stays after the last change
local LINGER = 10             -- how long the fade area's oval stays after the last change, or after the options close
local REMEMBER = 20           -- seconds an object still counts as targeted after the game lets go of it (time to type)
local DIM = 0.3               -- how bright a dimmed sparkle and name are (Herbs And Ore I Cannot Gather), against 1
local KEEP = 10               -- seconds the character's professions are kept before the game is asked again
local LOOTED = 0.5            -- seconds after the loot window closes that a corpse is looked at once more
-- The names the preview writes: a real object of each kind, so the preview reads as the real thing does.
local PREVIEW_NAMES = { herb = 'Peacebloom', ore = 'Copper Vein', loot = 'Battered Chest', quest = 'Quest Object',
	questcorpse = 'Bristleback Quilboar', corpse = 'Kobold Vermin', skin = 'Mottled Boar', other = 'Mailbox', waypoint = 'Waypoint (120 yd)' }
ns.PREVIEW_NAMES = PREVIEW_NAMES
-- How /sparkle status names each kind. ('dead': a corpse with nothing for you, which never sparkles.)
local TYPES = { herb = 'Herb', ore = 'Ore', loot = 'Chest', quest = 'Quest Object', other = 'Other Object',
	questcorpse = 'Quest Corpse', corpse = 'Corpse With Loot', skin = 'Skinnable Corpse', dead = 'Corpse', waypoint = 'Waypoint' }
-- Each kind's heading on the Appearance page, for the reasons /sparkle status gives.
local HEADINGS = {}
for _, kind in ipairs(ns.KINDS) do HEADINGS[kind[1]] = kind[2] end
-- The professions that matter here: the game's name for each (in Enum.Profession, and as it is said),
-- and its skill line where the game cannot be asked for it.
local CRAFTS = { herb = { 'Herbalism', 182 }, ore = { 'Mining', 186 }, skin = { 'Skinning', 393 } }
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

-- What one of the game's yes-or-no functions says, when it says so plainly: true or false. Nil when
-- this client does not have the function, when it fails, or when it keeps its answer secret (unit
-- data can be secret in combat).
local function Says(name, ...)
	local fn = rawget(_G, name)
	if type(fn) ~= 'function' then return nil end
	local ok, value = pcall(fn, ...)
	if not (ok and Plain(value)) then return nil end
	return value == true
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

-- 'herb', 'ore', 'quest', 'loot' or 'other'; whether that is known (true) or only assumed (false);
-- and the cursor's name, for /sparkle debug.
local function Kind()
	local cursor = Cursor()
	local name = UnitName(UNIT)
	if type(name) == 'string' and Plain(name) then
		-- (Routes (Thread), when it is installed, remembers what was gathered from nodes of this name)
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
	-- The themed ones (1.5.0): an effect drawn for one kind of thing.
	-- Leaves drifting down past the thing, swaying and turning as they fall: herbs.
	leaves = { pieces = { { 'a', 'leaf' }, { 'b', 'leaf' }, { 'c', 'leaf' }, { 'd', 'leaf' }, { 'e', 'leaf' } },
		tick = function(m, p, t, s, a)
			for i, key in ipairs(LETTERS) do
				local piece = p[key]
				if piece then
					local n, u = Turn(t, 2.6 + 0.4 * i, i * 0.31)
					Spot(piece, m, (Chance(i, n) - 0.5) * s * 0.7 + sin(t * 1.3 + i * 1.9) * s * 0.08,
						s * 0.32 - u * s * 0.6, s * (0.13 + 0.04 * Chance(i + 4, n)), a * 0.85 * sin(u * PI))
					piece:SetRotation(t * (0.8 + 0.3 * i) * (i % 2 == 0 and 1 or -1))
				end
			end
		end },
	-- Sparks rising fast from a warm glow and flickering out: ore.
	embers = { pieces = { { 'g', 'glow' }, { 'a', 'ember' }, { 'b', 'ember' }, { 'c', 'ember' }, { 'd', 'ember' }, { 'e', 'ember' } },
		tick = function(m, p, t, s, a)
			Put(p.g, m, s * 0.5, a * (0.22 + 0.06 * sin(t * 7)))
			for i, key in ipairs(LETTERS) do
				local piece = p[key]
				if piece then
					local n, u = Turn(t, 1.1 + 0.25 * i, i * 0.23)
					Spot(piece, m, (Chance(i, n) - 0.5) * s * 0.5 + sin(t * 3 + i) * s * 0.04, -s * 0.1 + u * s * 0.55,
						s * (0.07 + 0.03 * Chance(i + 2, n)) * (1 - 0.5 * u),
						a * 0.9 * (1 - u) * (u < 0.1 and u / 0.1 or 1) * (0.7 + 0.3 * sin(t * 15 + i)))
				end
			end
		end },
	-- Coins turning over in the air, each catching the light, and now and then a glint: chests.
	coins = { pieces = { { 'a', 'coin' }, { 'b', 'coin' }, { 'c', 'coin' }, { 'd', 'coin' }, { 'e', 'glint' } }, white = { e = true },
		tick = function(m, p, t, s, a)
			for i = 1, 4 do
				local piece = p[LETTERS[i]]
				local n, u = Turn(t, 2.2 + 0.3 * i, i * 0.41)
				local size = s * 0.14
				local wide = size * math.max(0.15, math.abs(cos(t * 3 + i * 1.3)))
				piece:SetSize(wide, size)
				piece:SetAlpha(Fade(a * 0.9 * sin(u * PI)))
				piece:ClearAllPoints()
				piece:SetPoint('CENTER', m, 'CENTER', (Chance(i, n) - 0.5) * s * 0.6, (Chance(i + 7, n) - 0.5) * s * 0.3 + u * s * 0.12)
			end
			local n, u = Turn(t, 1.9, 0.5)
			local flare = u < 0.25 and sin(u / 0.25 * PI) or 0
			Spot(p.e, m, (Chance(5, n) - 0.5) * s * 0.5, (Chance(6, n) - 0.5) * s * 0.3, s * (0.08 + 0.12 * flare), a * 0.8 * flare)
		end },
	-- Rays of light turning slowly round a soft glow, two wheels of them the opposite ways: quest objects.
	rays = { pieces = { { 'b', 'glow' }, { 'a', 'rays' }, { 'c', 'rays' } },
		tick = function(m, p, t, s, a)
			Put(p.b, m, s * 0.5, a * 0.45)
			Put(p.a, m, s * 1.1, a * (0.45 + 0.15 * sin(t * 1.3)), t * 0.15)
			Put(p.c, m, s * 0.8, a * (0.35 + 0.15 * sin(t * 1.7 + 1)), -t * 0.22)
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
	local mounted = Says('IsMounted') == true
	local height = mounted and (ns.Get('sparkleBehindMount') or 160) or (ns.Get('sparkleBehindSize') or 100)
	local tall = BODY_YARDS / zoom * height / 100
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
-- it stays as bright as it was. (dim: a mark that is dimmed anyway stays so.)
local function Tuck(m)
	local ok, covered = pcall(Covered, m)
	if not ok or type(covered) ~= 'number' then
		m.unplaced, covered = true, 0
	else
		m.unplaced = nil
	end
	m.covered = covered
	local left = (ns.Get('sparkleBehindLeft') or 0) / 100
	m:SetAlpha(Fade((1 - covered * (1 - left)) * (m.dim or 1)))
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

---------------------------------------------------------------------------
-- How near the thing is (Brighter When Near)
---------------------------------------------------------------------------
-- Nothing tells an addon where a thing in the world is. Herbs and veins come back in the same places,
-- though, and Routes (Thread), when it is installed, remembers where you stood each time you gathered
-- one (its saved nodes: { [map] = { { x, y, name }, ... } }, in world coordinates, as the game gives
-- your own place). The nearest remembered spot of the same name is taken to be the node in front of
-- you, while it is within the game's reach. The waypoint has a distance from the game (Waypoint.lua).

-- How far away the game picks a thing, in yards: its own setting, which Sparkle Distance may raise.
local function Reach()
	local r = tonumber(GetCVar and GetCVar(RANGE))
	if not r or r <= 0 then r = REACH_ASSUMED end
	return r > REACH_MOST and REACH_MOST or r
end
ns.Reach = Reach

-- Your place in the world: x, y and the map; nothing where the game keeps it to itself (in an instance).
local function Here()
	if not UnitPosition then return nil end
	local x, y, _, map = UnitPosition('player')
	if not (Plain(x) and Plain(y) and Plain(map) and type(x) == 'number' and type(y) == 'number') then return nil end
	return x, y, map
end
ns.Here = Here

-- The spots of this name Routes remembers around you: { map =, list = { node, ... } }, or nothing.
local function Spots(name)
	local routes = rawget(_G, 'PatchwerkForever_Thread_RoutesDB')
	local nodes = type(routes) == 'table' and type(routes.nodes) == 'table' and routes.nodes
	local px, py, map = Here()
	if not (nodes and px and type(name) == 'string') then return nil end
	local list = nodes[map]
	if type(list) ~= 'table' then return nil end
	local far = Reach() + NODE_SLACK + 40          -- (a little more: you may walk on and come nearer)
	local out = {}
	for i = 1, #list do
		local node = list[i]
		if type(node) == 'table' and node[3] == name and type(node[1]) == 'number' and type(node[2]) == 'number'
			and math.abs(node[1] - px) < far and math.abs(node[2] - py) < far then
			out[#out + 1] = node
		end
	end
	return #out > 0 and { map = map, list = out } or nil
end

-- How far away the nearest of those spots is, in yards; nothing when none is within the game's reach
-- (then the node in front of you is one not remembered).
local function Yards(spots)
	local px, py, map = Here()
	if not (spots and px and map == spots.map) then return nil end
	local best
	for _, node in ipairs(spots.list) do
		local d = ((node[1] - px) ^ 2 + (node[2] - py) ^ 2) ^ 0.5
		if not best or d < best then best = d end
	end
	if best and best > Reach() + NODE_SLACK then return nil end
	return best
end

-- How bright a sparkle so far away is, against full (NEAR_LEAST at the edge of `reach`, 1 up close);
-- 1 when the distance is not known.
local function Nearness(yards, reach)
	if type(yards) ~= 'number' then return 1 end
	local u = Fade((yards - NEAR_FULL) / math.max(1, (reach or Reach()) - NEAR_FULL))
	return 1 - (1 - NEAR_LEAST) * u
end
ns.Nearness = Nearness

local function NewMark()
	local m = CreateFrame('Frame', nil, UIParent)
	m:SetSize(100, 100)
	m:EnableMouse(false)
	m:Hide()
	m.pieces, m.time, m.effect, m.age, m.near, m.nearAt = {}, 0, nil, ARRIVE, 1, 0
	m.name = m:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	m:SetScript('OnUpdate', function(self, elapsed)
		local look = self.look
		if not look then return end
		self.time = self.time + elapsed * look.speed
		self.age = self.age + elapsed
		local arrived = Arrived(self)
		-- (nearer is brighter and a little larger: Brighter When Near, where the distance is known)
		if self.spots and ns.Get('sparkleNear') then
			self.nearAt = self.nearAt - elapsed
			if self.nearAt <= 0 then
				self.nearAt = NEAR_EVERY
				self.yards = Yards(self.spots)
				self.near = Nearness(self.yards)
			end
		elseif self.Distance and ns.Get('sparkleNear') then
			self.near = self:Distance()
		else
			self.near, self.yards = 1, nil
		end
		local near = self.near or 1
		look.def.tick(self, self.parts, self.time, look.size * (0.7 + 0.3 * near), look.bright * arrived * near)
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
		height = ns.Get(key .. 'height') or -40, speed = (ns.Get(key .. 'speed') or 100) / 100,
		sound = ns.Get(key .. 'sound') or 'none' }
end
ns.Look = Look
ns.EFFECTS = EFFECTS

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
-- (for the waypoint's sparkle, Waypoint.lua, which is made and dressed as an object's is)
ns.NewMark, ns.Dress, ns.WriteName, ns.Arrive, ns.Tuck = NewMark, Dress, Write, Arrive, Tuck

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

---------------------------------------------------------------------------
-- What the character can gather
---------------------------------------------------------------------------
-- A profession's skill line: asked of the game, else the number it has had since the first game.
local function SkillLine(craft)
	local trade, enum = rawget(_G, 'C_TradeSkillUI'), rawget(_G, 'Enum')
	local get = type(trade) == 'table' and trade.GetProfessionSkillLineID
	local which = type(enum) == 'table' and type(enum.Profession) == 'table' and enum.Profession[craft[1]]
	if type(get) == 'function' and which ~= nil then
		local ok, id = pcall(get, which)
		if ok and Plain(id) and type(id) == 'number' and id > 0 then return id end
	end
	return craft[2]
end

-- The skill lines of the professions in the game's profession book, as the book itself asks for them
-- (GetProfessions gives a number for each profession the character has, GetProfessionInfo its skill
-- line): [skill line] = true. Nothing when the book lists none, or one of them cannot be read.
local function Book(ok, ...)
	if not ok then return nil end
	local info = rawget(_G, 'GetProfessionInfo')
	local lines, any = {}, false
	for i = 1, select('#', ...) do                         -- (any of them can be nil)
		local index = select(i, ...)
		if index ~= nil then
			if not Plain(index) then return nil end
			local line = select(8, pcall(info, index))        -- (pcall's true first, then the skill line seventh)
			if not (Plain(line) and type(line) == 'number') then return nil end
			lines[line], any = true, true
		end
	end
	return any and lines or nil
end

-- The same from the character's skills, for a character with no profession in the book: once the game
-- lists any skill at all it knows them, and a skill asked for by its line has a rank only when the
-- character has it. { herb =, ore =, skin = }, or nothing while the game lists no skills.
local function Skills()
	local skills = rawget(_G, 'C_SkillInfo')
	local count = type(skills) == 'table' and skills.GetNumSkillLines
	local byLine = type(skills) == 'table' and skills.GetSkillLineInfoByID
	if type(count) ~= 'function' or type(byLine) ~= 'function' then return nil end
	local ok, lines = pcall(count)
	if not (ok and Plain(lines) and type(lines) == 'number' and lines > 0) then return nil end
	local out = {}
	for kind, craft in pairs(CRAFTS) do
		local got, info = pcall(byLine, SkillLine(craft))
		local rank = got and type(info) == 'table' and info.rank
		out[kind] = Plain(rank) and type(rank) == 'number' and rank > 0
	end
	return out
end

-- Which of the three professions the character has: { herb =, ore =, skin = }, each true or false.
-- Nil while the game does not say (just after login, or on a client with neither way of asking); then
-- nothing is dimmed or hidden. Kept a few seconds, and forgotten when the character's skills change.
local have, haveAt = nil, 0
local function Professions()
	if have and GetTime() - haveAt <= KEEP then return have end
	have, haveAt = nil, GetTime()
	local list = rawget(_G, 'GetProfessions')
	local lines = type(list) == 'function' and type(rawget(_G, 'GetProfessionInfo')) == 'function' and Book(pcall(list))
	if lines then
		have = {}
		for kind, craft in pairs(CRAFTS) do have[kind] = lines[SkillLine(craft)] == true end
	else
		have = Skills()
	end
	return have
end

-- An herb or a vein the character has no profession for, by Herbs And Ore I Cannot Gather: 'dim' or
-- 'hide'. Nil when it shows as ever: the character has the profession, the setting is Show, or the
-- game has not yet said what the professions are.
local function Cannot(kind)
	if kind ~= 'herb' and kind ~= 'ore' then return nil end
	local how = ns.Get('sparkleCannot')
	if how ~= 'dim' and how ~= 'hide' then return nil end
	local has = Professions()
	if not has or has[kind] then return nil end
	return how
end

---------------------------------------------------------------------------
-- A corpse
---------------------------------------------------------------------------
-- Is the game pointing at a dead creature (not a person, and not one alive)? Only when the game says
-- so plainly: where it will not say, it is taken not to be one, and nothing sparkles, as before 1.4.0.
local function Dead(unit)
	return Says('UnitIsDead', unit) == true and Says('UnitIsPlayer', unit) == false
end

-- Does the corpse have loot for you? Asked as the game's own gamepad action bar asks it of the thing
-- the interact key points at; on a client without that, by the creature itself (CanLootUnit: whether
-- it has loot, and whether it is yours to take).
local function HasLoot(unit)
	local has = Says('UnitHasLootInteraction', unit)
	if has ~= nil then return has end
	local can, guid = rawget(_G, 'CanLootUnit'), UnitGUID(unit)
	if type(can) ~= 'function' or not (Plain(guid) and type(guid) == 'string') then return false end
	local ok, hasLoot, canLoot = pcall(can, guid)
	return ok and Plain(hasLoot) and Plain(canLoot) and hasLoot == true and canLoot == true
end

-- Does a line of the unit's tooltip, as the game would write it, hold this word?
local function TooltipSays(get, unit, word)
	local data = get(unit)
	local lines = Plain(data) and type(data) == 'table' and data.lines
	if not Plain(lines) or type(lines) ~= 'table' then return false end
	for _, line in ipairs(lines) do
		local text = type(line) == 'table' and line.leftText
		if Plain(text) and type(text) == 'string' and text:find(word, 1, true) then return true end
	end
	return false
end

-- Can the corpse be skinned? No function says so. The cursor the game would show over it does (the
-- skinning one has "skin" in its name), and so does its tooltip, which has a line of its own for it
-- in the game's own word. (The tooltip is read under pcall: what it holds for a unit in combat, and
-- whether that can be gone through, is not known.)
local function Skinnable(unit, cursor)
	if type(cursor) == 'string' and cursor:lower():find('skin', 1, true) then return true end
	local word, tips = rawget(_G, 'UNIT_SKINNABLE_LEATHER'), rawget(_G, 'C_TooltipInfo')
	local get = type(tips) == 'table' and tips.GetUnit
	if type(word) ~= 'string' or word == '' or type(get) ~= 'function' then return false end
	local ok, yes = pcall(TooltipSays, get, unit, word)
	return ok and yes == true
end

-- The corpse the game points at: its kind ('corpse': it has loot for you; 'skin': it can be skinned;
-- 'dead': neither), why it is not to sparkle (nil when it is), and the cursor's name for /sparkle
-- debug. Nothing at all when the game is not pointing at a corpse.
local function Corpse(unit)
	if not Dead(unit) then return nil end
	local cursor = Cursor()
	if HasLoot(unit) then
		-- (one that belongs to a quest of yours: the boar whose pelt you need, 1.5.0)
		if Says('UnitIsRelatedToActiveQuest', unit) == true then return 'questcorpse', nil, cursor end
		return 'corpse', not ns.Get('sparkleCorpse') and 'Sparkle On Corpses With Loot is disabled' or nil, cursor
	end
	if Skinnable(unit, cursor) then
		local has = Professions()
		if not ns.Get('sparkleSkin') then return 'skin', 'Sparkle On Skinnable Corpses is disabled', cursor end
		if not has then return 'skin', 'the game has not yet said whether this character has Skinning', cursor end
		if not has.skin then return 'skin', 'this character does not have Skinning', cursor end
		return 'skin', nil, cursor
	end
	return 'dead', 'it has no loot for you', cursor
end

-- Is the game pointing at something a sparkle could be on: a thing in the world, or a corpse?
local function Pointed()
	return IsThing(UNIT) or Dead(UNIT)
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
	-- Sparkle Distance (1.5.0): the game's reach only ever raised, never lowered below its own value,
	-- and that value kept to be put back, as the others are.
	local want = on and tonumber(ns.Get('sparkleReach'))
	local was, now = db.sparkleWas[RANGE], GetCVar(RANGE)
	if want and now ~= nil then
		local own = tonumber(was or now)
		local target = own and own > want and own or want
		if tonumber(now) ~= target then
			if was == nil then db.sparkleWas[RANGE] = now end
			pcall(SetCVar, RANGE, tostring(target))
		end
	elseif was ~= nil then
		pcall(SetCVar, RANGE, was)
		db.sparkleWas[RANGE] = nil
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

-- Is this kind's Show tick box on (Sparkle: Appearance)? Kinds without one (corpses) always are.
local function Shown(kind)
	return ns.Get('look.' .. kind .. '.show') ~= false
end
ns.Shown = Shown

-- While you gather from the thing pointed at or loot it: { name =, at = }, the thing a cast was aimed at
-- (by its name) until the cast ends, and the thing pointed at when the loot window opened until it
-- closes; never longer than WORKING seconds, should the game not say it has ended.
local working, looting = nil, nil
local WORKING = 15

local function Gathering(name)
	for _, busy in ipairs({ working or false, looting or false }) do
		if busy and busy.name == name and GetTime() - busy.at < WORKING then return true end
	end
	return false
end

local function Update()
	-- a thing in the world, as ever; or a corpse, with its kind and why it is not to sparkle
	local kind, known, cursor, why
	local corpse = not IsThing(UNIT)
	if corpse then
		kind, why, cursor = Corpse(UNIT)
		known = true
	else
		kind, known, cursor = Kind()
	end
	if not kind then                                      -- a living creature, a person, or nothing
		if last and not last.lost then last.lost = GetTime() end
		if ns.PassedSee then ns.PassedSee(nil) end
		return Hide()
	end
	local barred = Barred()
	local plate = Plate()
	local name = UnitName(UNIT)
	if not Plain(name) or type(name) ~= 'string' then name = nil end
	local ignored = Ignored(name)
	local cannot = Cannot(kind)                           -- (an herb or a vein you cannot gather: 'dim' or 'hide')
	local hidden = kind ~= 'dead' and not Shown(kind)      -- (its Show tick box is off)
	local wanted
	if corpse then
		wanted = why == nil and not ignored and not hidden
	else
		wanted = Wanted(kind, known) and cannot ~= 'hide' and not ignored and not hidden
	end
	last = { name = name, kind = kind, known = known, cursor = cursor, plate = plate ~= nil, barred = barred,
		shown = not barred and wanted and plate ~= nil, ignored = ignored, cannot = cannot, corpse = corpse, why = why,
		hidden = hidden, time = GetTime() }
	if ns.PassedSee then ns.PassedSee(last) end
	if barred or not wanted then return Hide() end
	if not plate then
		Recheck()
		return Hide()
	end
	if not live then live = NewMark() end
	local fresh = not live:IsShown() or live.thing ~= name
	if fresh then
		Arrive(live)
		-- (where the node is, for Brighter When Near: the spots Routes remembers of this name)
		live.spots = (kind == 'herb' or kind == 'ore') and Spots(name) or nil
		live.near, live.nearAt, live.yards = 1, 0, nil
	end
	live.thing, live.kind, live.spotted = name, kind, true
	local look = Look(kind)
	Dress(live, look)
	live:SetParent(plate)
	live:ClearAllPoints()
	live:SetPoint('CENTER', plate, 'CENTER', 0, look.height)
	Write(live, plate, name, look)
	-- (the mark's own opacity dims the effect and the name alike: a herb you cannot gather, and while you
	-- gather from it)
	live.dim = (cannot == 'dim' and DIM or 1) * (Gathering(name) and ns.Get('sparkleGathering') and GATHER_FADE or 1)
	live.behind = ns.Get('sparkleBehind') and true or false
	if fresh and ns.Cue then ns.Cue(kind, name, look) end
	if live.behind then
		Tuck(live)
	else
		live:SetAlpha(live.dim)
	end
	live:Show()
end

local function Refresh()
	ns.Try('the sparkle', Update)
end
ns.Barred, ns.Says = Barred, Says

-- The object (or corpse) targeted now, or until a moment ago: its name; nil when there is none.
local function Targeted()
	Refresh()
	if not (last and last.name) then return nil end
	if Pointed() or (last.lost and GetTime() - last.lost <= REMEMBER) then return last.name end
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
	-- (its alert sound too, when the button was pressed: not each time a setting changes)
	if not keep and ns.CuePlay then ns.CuePlay(look.sound) end
	testing = testing + 1
	local mine = testing
	C_Timer.After(TEST_SECONDS, function()
		if mine == testing then test:Hide() end
	end)
end

-- Preview All Types: every kind's sparkle in a row across the screen for a few seconds, each with its
-- real name, so they can be compared.
local row, rows = {}, 0
local GAP = 150               -- pixels from one preview's middle to the next
function ns.SparkleTestAll()
	if test then test:Hide() end
	local count = #ns.KINDS
	for i, kind in ipairs(ns.KINDS) do
		local m = row[i]
		if not m then
			m = NewMark()
			m.anchor = CreateFrame('Frame', nil, UIParent)
			m.anchor:SetSize(1, 1)
			row[i] = m
		end
		local look = Look(kind[1])
		Arrive(m)
		m.kind = kind[1]
		Dress(m, look)
		m.anchor:ClearAllPoints()
		m.anchor:SetPoint('CENTER', UIParent, 'CENTER', (i - (count + 1) / 2) * GAP, 160)
		m:SetParent(UIParent)
		m:SetFrameStrata('DIALOG')
		m:ClearAllPoints()
		m:SetPoint('CENTER', m.anchor, 'CENTER', 0, kind[1] == 'waypoint' and look.height or 0)
		Write(m, m.anchor, PREVIEW_NAMES[kind[1]] or kind[2], look)
		m:Show()
	end
	rows = rows + 1
	local mine = rows
	C_Timer.After(TEST_SECONDS, function()
		if mine ~= rows then return end
		for _, m in ipairs(row) do m:Hide() end
	end)
end

-- Use This Look For All: every other kind gets this kind's effect, size, brightness, speed and (between
-- the kinds that hang from a nameplate) vertical offset; colors, sounds and Show stay as they were.
local SHARED = { 'effect', 'size', 'bright', 'speed', 'height' }
function ns.SparkleCopyLook(from)
	local name
	for _, kind in ipairs(ns.KINDS) do
		if kind[1] == from then name = kind[2] end
	end
	for _, kind in ipairs(ns.KINDS) do
		local k = kind[1]
		if k ~= from then
			for _, part in ipairs(SHARED) do
				-- (the waypoint hangs from the game's marker, not a nameplate: its offset is its own)
				if not (part == 'height' and (k == 'waypoint' or from == 'waypoint')) then
					ns.Set('look.' .. k .. '.' .. part, ns.Get('look.' .. from .. '.' .. part))
				end
			end
		end
	end
	ns.Print(('Every object type now looks like %s. Each keeps its own color, alert sound and Show setting.'):format(name or from))
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
local SUBTLE = { herb = 'glints', ore = 'glints', loot = 'shimmer', quest = 'ripple', questcorpse = 'ripple', corpse = 'shimmer',
	skin = 'glints', other = 'fireflies', waypoint = 'beam' }
function ns.SparkleSubtle()
	for _, kind in ipairs(ns.KINDS) do
		ns.Set('look.' .. kind[1] .. '.effect', SUBTLE[kind[1]] or 'shimmer')
	end
	ns.Print('Subtle preset applied: glints on herbs, ore and skinnable corpses, a faint shimmer on chests and corpses with loot, a ground ripple on quest objects and quest corpses, fireflies on the rest, a light beam on the waypoint. Change any of them under ' .. ns.APPEARANCE .. '.')
end

-- Apply Themed Preset (1.5.0): an effect drawn for each kind.
local THEMED = { herb = 'leaves', ore = 'embers', loot = 'coins', quest = 'rays', questcorpse = 'rays', corpse = 'coins',
	skin = 'leaves', other = 'glow', waypoint = 'beam' }
function ns.SparkleThemed()
	for _, kind in ipairs(ns.KINDS) do
		ns.Set('look.' .. kind[1] .. '.effect', THEMED[kind[1]] or 'glow')
	end
	ns.Print('Themed preset applied: falling leaves on herbs and skinnable corpses, embers on ore, coin glints on chests and corpses with loot, sun rays on quest objects and quest corpses, a soft glow on the rest, a light beam on the waypoint. Change any of them under ' .. ns.APPEARANCE .. '.')
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

-- The ignore list on its options page (the base's list, 2.9.0): a row for each name, A to Z, each
-- with a Remove button.
function ns.IgnoreRows()
	local names = {}
	for name in pairs(IgnoreList()) do names[#names + 1] = name end
	table.sort(names)
	local rows = {}
	for i, name in ipairs(names) do
		rows[i] = { text = name, buttons = { { text = 'Remove', click = function() Remove(name) end } } }
	end
	return rows
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
	if was.why then return was.why end                    -- (a corpse: no loot for you, no Skinning, its setting off)
	if was.hidden then
		return ('Show is off for %s on %s'):format(HEADINGS[was.kind] or was.kind, ns.APPEARANCE)
	end
	if was.cannot == 'hide' then
		return ('this character does not have %s and Herbs And Ore I Cannot Gather is set to Hide'):format(CRAFTS[was.kind][1])
	end
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

-- One plain sentence: the object or corpse, its kind, and whether it sparkles (dimmed, and why) and why not.
local function Told(was)
	local why = WhyNot(was)
	local how = 'sparkling'
	if why then
		how = 'not sparkling: ' .. why
	elseif was.cannot == 'dim' then
		how = ('sparkling, dimmed: this character does not have %s and Herbs And Ore I Cannot Gather is set to Dim'):format(CRAFTS[was.kind][1])
	end
	return ('%s (%s): %s.'):format(was.name or (was.corpse and 'A corpse whose name is not available' or 'An object whose name is not available'),
		TYPES[was.kind] or was.kind, how)
end

-- /sparkle status: what the game is pointing at just now, and why it does or does not sparkle.
function ns.SparkleSay()
	Refresh()
	if Pointed() and last then
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
	if ns.WaypointSay then ns.WaypointSay() end
end

-- /sparkle debug: the raw values, for a bug report.
function ns.SparkleDebug()
	local parts = {}
	for _, name in ipairs({ 'SoftTargetInteract', 'SoftTargetInteractRange', 'SoftTargetInteractArc',
		'SoftTargetNameplateInteract', 'SoftTargetIconGameObject', 'SoftTargetIconInteract' }) do
		parts[#parts + 1] = name .. ' ' .. tostring(GetCVar and GetCVar(name))
	end
	ns.Print('Game interact settings: ' .. table.concat(parts, ', ') .. '.')
	local has = Professions()
	if has then
		ns.Print(('Professions: Herbalism %s, Mining %s, Skinning %s.'):format(has.herb and 'yes' or 'no',
			has.ore and 'yes' or 'no', has.skin and 'yes' or 'no'))
	else
		ns.Print('Professions: not available.')
	end
	Refresh()
	if not last then
		ns.Print('Nothing targeted since login.')
		return
	end
	ns.Print(('Last object: %s; targeted now: %s; type %s (%s); cursor %s; nameplate %s; shown %s; ignored %s; cannot gather: %s; hidden by: %s.')
		:format(tostring(last.name), tostring(Pointed()), last.kind, last.known and 'known' or 'guessed',
			tostring(last.cursor), last.plate and 'yes' or 'no', tostring(last.shown), tostring(last.ignored),
			tostring(last.cannot or 'no'), tostring(last.barred or last.why or (last.hidden and 'its Show setting') or 'nothing')))
	-- The probe (1.5.0): what the game's tooltip says of the thing pointed at now, line by line with the
	-- color of each where it is not the usual white or gold (a red "Requires Herbalism (150)" says the
	-- skill is too low), and what the game says of it otherwise. Read for what Sparkle could learn next.
	if not Pointed() then
		ns.Print('Tooltip: point at an object or corpse and type /sparkle debug again to see what its tooltip says.')
		return
	end
	local lines = ns.TooltipLines(UNIT)
	if lines then
		ns.Print('Tooltip: ' .. (#lines > 0 and table.concat(lines, ' / ') or 'no lines') .. '.')
	else
		ns.Print('Tooltip: not available for this object.')
	end
	local related = Says('UnitIsRelatedToActiveQuest', UNIT)
	local guid = UnitGUID(UNIT)
	ns.Print(('Related to an active quest: %s; GUID %s; distance %s; reach %d yards.'):format(
		related == nil and 'not available' or (related and 'yes' or 'no'),
		Plain(guid) and tostring(guid) or 'not available',
		live and live:IsShown() and live.yards and ('%.1f yards (from Routes)'):format(live.yards) or 'not known', Reach()))
end

-- Is a color the tooltip's usual white or gold? (Those are not worth printing.)
local function Usual(r, g, b)
	return (r > 0.95 and g > 0.95 and b > 0.95) or (r > 0.95 and g > 0.78 and g < 0.86 and b < 0.05)
end

-- The tooltip's lines for a unit, each as "words" or "words {r g b}"; nothing when the game gives none.
function ns.TooltipLines(unit)
	local tips = rawget(_G, 'C_TooltipInfo')
	local get = type(tips) == 'table' and tips.GetUnit
	if type(get) ~= 'function' then return nil end
	local ok, data = pcall(get, unit)
	if not (ok and Plain(data) and type(data) == 'table' and type(data.lines) == 'table') then return nil end
	local out = {}
	for _, line in ipairs(data.lines) do
		local words = type(line) == 'table' and line.leftText
		if Plain(words) and type(words) == 'string' and words ~= '' then
			local right = line.rightText
			if Plain(right) and type(right) == 'string' and right ~= '' then words = words .. ' | ' .. right end
			local c = line.leftColor
			local r, g, b = type(c) == 'table' and c.r, type(c) == 'table' and c.g, type(c) == 'table' and c.b
			if Plain(r) and Plain(g) and Plain(b) and type(r) == 'number' and type(g) == 'number' and type(b) == 'number'
				and not Usual(r, g, b) then
				words = ('%s {%.2f %.2f %.2f}'):format(words, r, g, b)
			end
			out[#out + 1] = words
		end
	end
	return out
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
-- (a game that does not know an event refuses to listen for it: then that is simply not watched)
-- A corpse can change while the game goes on pointing at it: looted, it has nothing more for you, or is
-- one to skin now. The game says when a creature's loot changes; and after the loot window closes a
-- corpse still pointed at is looked at again, at once and a moment later.
pcall(ns.On, 'UNIT_LOOT', Refresh)
pcall(ns.On, 'LOOT_CLOSED', function()
	looting = nil
	Refresh()
	if last and last.corpse and not last.lost then C_Timer.After(LOOTED, Refresh) end
end)
-- the character's skills changed: a profession learned or dropped
pcall(ns.On, 'SKILL_LINES_CHANGED', function() have = nil; Refresh() end)
-- Fade While Gathering: a cast aimed at the thing pointed at (the game names its target as it is sent),
-- until it ends; and the loot window while it is open.
pcall(ns.On, 'UNIT_SPELLCAST_SENT', function(unit, target)
	if unit ~= 'player' or not (Plain(target) and type(target) == 'string') then return end
	if last and last.name == target and not last.lost then
		working = { name = target, at = GetTime() }
		Refresh()
	end
end)
for _, event in ipairs({ 'UNIT_SPELLCAST_STOP', 'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_INTERRUPTED',
	'UNIT_SPELLCAST_SUCCEEDED', 'UNIT_SPELLCAST_CHANNEL_STOP' }) do
	pcall(ns.On, event, function(unit)
		if unit == 'player' and working then
			working = nil
			Refresh()
		end
	end)
end
pcall(ns.On, 'LOOT_OPENED', function()
	looting = last and last.name and not last.lost and { name = last.name, at = GetTime() } or nil
	Refresh()
end)
ns.On('PLAYER_LOGIN', function()
	Needs(ns.Get('sparkle'))
end)
-- (put back at every logout and reload, so the game keeps its own values should the addon be gone at
-- the next login; the login turns them on again)
ns.On('PLAYER_LOGOUT', function() Needs(false) end)
ns.OnSetting(function(key, value)
	if key == 'sparkle' then Needs(value) end
	if key == 'sparkleKeyboard' or key == 'sparkleReach' then Needs(ns.Get('sparkle')) end
	if key:find('^sparkle') or key:find('^look%.') or key:find('^name') then Refresh() end
	Follow(key)
	if where and where:IsShown() and key:find('^sparkleBehind.') then Linger() end
end)
