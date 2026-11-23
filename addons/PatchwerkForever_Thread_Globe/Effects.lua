-- Globe (Thread): light and movement, so the globe is a thing on a desk and not a diagram.
--
--   candlelight   the corners of the picture darkened and flickering a little, more so at night by the
--                 game's clock; a soft shine on the ball while the whole of it is in view
--   sea and sky   the Maelstrom turns in its place; cloud shadows drift over the globe, zoomed out
--   opening       the window fades in and the globe turns into place; the map's own sounds
--   your place    a ring spreads from where you are, every few seconds
--   age           the paper of an old globe: stains, foxing, rubbed patches, and closer to, hairline
--                 cracks, specks and the seams between the paper's twelve strips. Laid over the map, the
--                 ink drawings and the fog alike; gone by the time the ground shows
--
-- Each has its setting. None of it is drawn again by the globe: a moving picture's pieces are given
-- new parts of their texture where they lie (the Maelstrom's turned about its middle, the clouds' slid
-- along), which costs far less than a drawing. The pictures are our own (tools/globe_fx.py).
local ADDON, ns = ...
if not (ns.linked and ns.G and ns.Marks) then return end
local G, Marks = ns.G, ns.Marks

local sin, cos, min, max, pi = math.sin, math.cos, math.min, math.max, math.pi
local FX = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\Fx\\'
local VIEW, SEEN = G.VIEW, G.SEEN
local TURN = 48                       -- seconds the Maelstrom takes to turn once
local DRIFT = 300                     -- seconds a cloud takes to cross its own picture
local BANDS = 6                       -- the clouds are laid round the globe in this many pieces, their picture twice across each
local SKY_TOP = 1.15                  -- and from this latitude south to the same north
local CLOUDS_GONE = { VIEW * 1.3, VIEW * 3.2 }    -- zooming in, the clouds thin out between these
local CLOUDS = 0.6                    -- how much of their picture shows at most
local TICK = 0.05                     -- seconds between two steps of what moves
local FADE = 0.25                     -- seconds the window takes to fade in
local PING = 2.6                      -- seconds between two rings from your place
local AGE, WEAR = 0.95, 0.85          -- how much of the aging's two pictures shows at most
local AGE_GONE = { VIEW * 3.5, VIEW * 6 }         -- zooming in to the ground, the stains fade out between these
local WEAR_GONE = { VIEW * 1.8, VIEW * 3.6 }      -- and the small things sooner (their picture would show its pixels)
local STRIPS = 12                     -- the paper's strips round the globe (the small things' picture has the seam at its edge)

local state = { turn = 0, drift = 0, clock = 0, since = 0, fade = nil }
local light, sheen, ping
local sky                             -- the clouds' pictures
local aged, worn                      -- the aging's: stains for the whole sphere, and the small things, repeating
local maelstrom                       -- the Maelstrom's picture (one of the globe's own ink pieces)

local function On(key) return ns.Get(key) and true or false end

---------------------------------------------------------------------------
-- What moves in its place
---------------------------------------------------------------------------
-- The Maelstrom's piece p shows the part of its picture that is under it once the picture is turned.
local function Turned(p, t)
	local ca, sa = cos(state.turn), sin(state.turn)
	local function At(fu, fv)
		local x, y = fu - 0.5, fv - 0.5
		return 0.5 + x * ca - y * sa, 0.5 + x * sa + y * ca
	end
	local a1, b1 = At(p.fu0, p.fv0)
	local a2, b2 = At(p.fu0, p.fv1)
	local a3, b3 = At(p.fu1, p.fv0)
	local a4, b4 = At(p.fu1, p.fv1)
	t:SetTexCoord(a1, b1, a2, b2, a3, b3, a4, b4)
end

-- A cloud piece shows its part of the picture, slid along.
local function Slid(p, t)
	local c = p.pic.coords
	local du, dv = c[2] - c[1], c[4] - c[3]
	local s = state.drift
	t:SetTexCoord(c[1] + du * p.fu0 + s, c[1] + du * p.fu1 + s, c[3] + dv * p.fv0, c[3] + dv * p.fv1)
end

-- (every piece that holds a texture, shown or not: one kept for a moment out of the picture comes back
-- as it should be)
local function Walk(p, Moved)
	if p.tex then Moved(p, p.tex) end
	if p.kids then
		for _, kid in ipairs(p.kids) do Walk(kid, Moved) end
	end
end

local function Prepare()
	if sky then return end
	sky = {}
	local top = SKY_TOP
	for i = 0, BANDS - 1 do
		local l0, l1 = -pi + 2 * pi * i / BANDS, -pi + 2 * pi * (i + 1) / BANDS
		sky[#sky + 1] = { fdid = FX .. 'clouds', layer = 'sky', wrap = 'REPEAT', coords = { 0, 2, 0, 4 }, Moved = Slid,
			At = function(fu, fv)
				local lon, lat = l0 + (l1 - l0) * fu, top - 2 * top * fv
				return { cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat) }
			end,
			-- (thinning out toward the top and the bottom, where the picture is squeezed)
			Fade = function(_, fv) return max(0, sin(pi * fv)) ^ 0.6 end }
	end
	for _, pic in ipairs(G.pictures.decor or {}) do
		if type(pic.fdid) == 'string' and pic.fdid:find('decor_maelstrom', 1, true) then maelstrom = pic end
	end
	-- the aging: the sphere in four pieces round and two down, as the world's own picture is laid
	aged, worn = {}, {}
	local across = STRIPS / 4
	for j = 0, 1 do
		for i = 0, 3 do
			local l0, l1 = -pi + pi / 2 * i, -pi + pi / 2 * (i + 1)
			local a0, a1 = pi / 2 - pi / 2 * j, pi / 2 - pi / 2 * (j + 1)
			local function At(fu, fv)
				local lon, lat = l0 + (l1 - l0) * fu, a0 + (a1 - a0) * fv
				return { cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat) }
			end
			aged[#aged + 1] = { fdid = FX .. 'age', layer = 'age', coords = { i / 4, (i + 1) / 4, j / 2, (j + 1) / 2 }, At = At }
			-- (half a strip along, so that no seam runs down the middle of a continent; thinning out toward
			-- the poles, where the strips narrow to nothing)
			worn[#worn + 1] = { fdid = FX .. 'wear', layer = 'wear', wrap = 'REPEAT', coords = { 0.5, across + 0.5, 0, across }, At = At,
				Fade = function(_, fv) return 1 - G.Smooth(1.1, 1.45, math.abs(a0 + (a1 - a0) * fv)) end }
		end
	end
end

local function Moving(on)
	if not maelstrom then return end
	maelstrom.Moved = on and Turned or nil
	if not on then
		state.turn = 0
		if maelstrom.root then Walk(maelstrom.root, Turned) end
	end
end

ns.GlobeOn('pictures', function(r, shade, style)
	Prepare()
	state.aged = 0
	if On('globeAge') and style == 'parchment' then
		local stains = AGE * (1 - G.Smooth(AGE_GONE[1], AGE_GONE[2], r))
		local small = WEAR * (1 - G.Smooth(WEAR_GONE[1], WEAR_GONE[2], r))
		if stains >= 0.02 then
			for _, pic in ipairs(aged) do G.Draw(pic, r, stains, false) end
		end
		if small >= 0.02 then
			for _, pic in ipairs(worn) do G.Draw(pic, r, small, false) end
		end
		state.aged = stains >= 0.02 and (small >= 0.02 and 2 or 1) or 0
	end
	local on = On('globeFxMove')
	if (maelstrom and maelstrom.Moved ~= nil) ~= on then Moving(on) end
	state.clouds = false
	if not on or style ~= 'parchment' then return end
	local alpha = CLOUDS * (1 - G.Smooth(CLOUDS_GONE[1], CLOUDS_GONE[2], r))
	if alpha < 0.02 then return end
	state.clouds = true
	for _, pic in ipairs(sky) do G.Draw(pic, r, alpha, false) end
end)

---------------------------------------------------------------------------
-- Light
---------------------------------------------------------------------------
-- How much of the night it is by the game's clock: 0 by day, 1 in the dead of night.
local function Night()
	local hour, minute = 12, 0
	if GetGameTime then
		local ok, h, m = pcall(GetGameTime)
		if ok and type(h) == 'number' then hour, minute = h, type(m) == 'number' and m or 0 end
	end
	local t = hour + minute / 60
	local fromNoon = math.abs(t - 12)             -- 0 at noon, 12 at midnight
	return G.Smooth(5.5, 8.5, fromNoon)
end

-- (The light lies over the map and the lines on it, and under the marks and the words: those stay clear.)
local function Build()
	if light then return true end
	local _, view, canvas = G.Frames()
	if not view then return false end
	light = canvas:CreateTexture(nil, 'ARTWORK')
	light:SetDrawLayer('ARTWORK', 7)
	light:SetAllPoints(view)
	light:SetTexture(FX .. 'light')
	light:Hide()
	sheen = canvas:CreateTexture(nil, 'ARTWORK')
	sheen:SetDrawLayer('ARTWORK', 7)
	sheen:SetTexture(FX .. 'sheen')
	if sheen.SetBlendMode then sheen:SetBlendMode('ADD') end
	sheen:Hide()
	ping = canvas:CreateTexture(nil, 'OVERLAY')
	ping:SetDrawLayer('OVERLAY', -4)
	ping:SetTexture(Marks.Icon('ring'))
	ping:Hide()
	return true
end

ns.GlobeOn('paint', function(r)
	if not Build() then return end
	local _, _, canvas = G.Frames()
	local flat = ns.FlatOn and ns.FlatOn()
	local least = G.Least()
	local shine = (On('globeFxLight') and not flat) and 0.17 * (1 - G.Smooth(least * 1.5, least * 3.5, r)) or 0
	if shine > 0.01 then
		sheen:SetSize(r * 1.25, r * 1.25)
		sheen:ClearAllPoints()
		sheen:SetPoint('CENTER', canvas, 'CENTER', -0.36 * r, 0.40 * r)
		sheen:SetAlpha(shine)
		sheen:Show()
	else
		sheen:Hide()
	end
end)

---------------------------------------------------------------------------
-- Each frame
---------------------------------------------------------------------------
ns.GlobeOn('frame', function(elapsed)
	if not Build() then return end
	local window, _, canvas = G.Frames()
	elapsed = elapsed or 0
	state.clock = state.clock + elapsed
	-- the window fading in
	if state.fade then
		state.fade = state.fade + elapsed / FADE
		if state.fade >= 1 then
			state.fade = nil
			window:SetAlpha(1)
		else
			window:SetAlpha(state.fade)
		end
	end
	-- candlelight
	if On('globeFxLight') then
		local night = Night()
		local t = state.clock
		local flicker = sin(t * 7.3) * 0.5 + sin(t * 13.1 + 1) * 0.3 + sin(t * 3.7 + 2) * 0.2
		local alpha = 0.34 + 0.34 * night + (0.02 + 0.035 * night) * flicker
		state.light = max(0, min(1, alpha))
		light:SetAlpha(state.light)
		if not light:IsShown() then light:Show() end
	elseif light:IsShown() then
		light:Hide()
		state.light = nil
	end
	-- the ring from your place
	local shown = false
	if On('globeFxPing') and not (ns.FlatOn and ns.FlatOn()) and G.Basis() then
		local _, me = G.MyPlace()
		if me then
			local x, y, z = G.Seen(me, G.look.r)
			local xMost, yLow, yHigh = G.Edges()
			if z > SEEN + 0.05 and math.abs(x) < xMost and y > yLow and y < yHigh then
				local t = (state.clock % PING) / PING
				if t < 0.6 then
					local k = t / 0.6
					local size = 16 + 54 * k
					ping:SetSize(size, size)
					ping:ClearAllPoints()
					ping:SetPoint('CENTER', canvas, 'CENTER', x, y)
					ping:SetVertexColor(1, 0.86, 0.35, 0.75 * (1 - k))
					shown = true
				end
			end
		end
	end
	if shown ~= ping:IsShown() then
		if shown then ping:Show() else ping:Hide() end
	end
	-- what moves in its place, a few times a second
	state.since = state.since + elapsed
	if state.since >= TICK and On('globeFxMove') and not (ns.FlatOn and ns.FlatOn()) then
		state.turn = (state.turn + state.since / TURN * 2 * pi) % (2 * pi)
		state.drift = (state.drift + state.since / DRIFT) % 1
		state.since = 0
		if maelstrom and maelstrom.root then Walk(maelstrom.root, Turned) end
		-- (the clouds only while they are drawn: zoomed in past them there is nothing to slide)
		if state.clouds then
			for _, pic in ipairs(sky or {}) do
				if pic.root then Walk(pic.root, Slid) end
			end
		end
	elseif state.since >= TICK then
		state.since = 0
	end
end)

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------
local function Sound(name)
	local kit = rawget(_G, 'SOUNDKIT')
	if On('globeFxSound') and type(kit) == 'table' and kit[name] and PlaySound then pcall(PlaySound, kit[name]) end
end

ns.GlobeOn('show', function()
	Sound('IG_QUEST_LOG_OPEN')
	if not On('globeFxOpen') then return end
	local window = G.Frames()
	state.fade = 0
	window:SetAlpha(0)
	if ns.FlatOn and ns.FlatOn() then return end
	-- the globe turns into place: from a little to one side and a little smaller, to where it was left
	local look = G.look
	local lat, lon, r = look.lat, look.lon, look.r
	look.lon, look.r = lon - 0.32, max(G.Least(), r * 0.9)
	G.GlideTo({ cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat) }, r)
end)

ns.GlobeOn('hide', function()
	Sound('IG_QUEST_LOG_CLOSE')
	state.fade = nil
	local window = G.Frames()
	if window then window:SetAlpha(1) end
end)

-- For the checks outside the game.
function ns.EffectsState()
	local out = { turn = state.turn, drift = state.drift, light = state.light, fading = state.fade ~= nil,
		sheen = sheen and sheen:IsShown() or false, ping = ping and ping:IsShown() or false,
		maelstrom = maelstrom ~= nil, moving = maelstrom ~= nil and maelstrom.Moved ~= nil, sky = sky and #sky or 0,
		aged = state.aged or 0 }
	return out
end
