-- Immersive Plainsrunning (Thread): the effects at full speed besides the streaks (Streaks.lua draws those, and
-- calls each of these every moment one is turned on).
--
--   Wind Gusts      long thin ribbons of wind rippling sideways across the lower half of the screen,
--                   outward from the middle, like wind running through tall grass
--   Dust And Seeds  specks of dust and grass seeds flying outward past you, most of them low
--   Warp Rings      faint rings swelling outward from the horizon ahead and past the edges
--   Edge Glow       a glow along the edges of the screen, beating in time with your stride
--
-- Each is told, every moment (the table `look`): elapsed, strength (how strongly the effects show,
-- 0..1), pace (how fast they should move, 1 = as at full stacks), ratio (your speed as a share of
-- running speed), w and h (the screen), reach (from the middle to a corner), cx and cy (the point on
-- the horizon they rush out from, from the middle of the screen), inner (the clear middle's radius)
-- and overlay (the frame to draw on). Their pictures are made by tools/media.py.
local ADDON, ns = ...
if not ns.linked then return end

local TAU = math.pi * 2
local function Clamp(v) return v < 0 and 0 or v > 1 and 1 or v end
local function Add(effect) ns.effects[#ns.effects + 1] = effect end

---------------------------------------------------------------------------
-- Wind Gusts: each gust is a ribbon of a few Lines, its points rippling on a wave as it goes
---------------------------------------------------------------------------
do
	local SEG = 5                         -- Lines in a gust
	local gusts = {}                      -- { lines, side, head, len, y, speed, bright, amp, wave, phase, thick, age }

	local function Spawn(g, look, anywhere)
		local half = look.w / 2
		g.side = math.random() < 0.5 and -1 or 1
		g.len = look.w * ( 0.16 + math.random() * 0.18 )
		g.head = look.w * 0.04 + g.len + ( anywhere and math.random() * half or 0 )      -- (all of it past the middle)
		g.age = anywhere and 1 or 0
		g.y = look.cy - look.h * ( 0.06 + math.random() * 0.40 )       -- below the horizon
		g.speed = 0.7 + math.random() * 0.6
		g.bright = 0.5 + math.random() * 0.5
		g.amp = look.h * ( 0.006 + math.random() * 0.014 )
		g.wave = TAU / ( g.len * ( 0.5 + math.random() * 0.5 ) )
		g.phase = math.random() * TAU
		g.thick = 1.2 + math.random() * 1.2
	end

	local function Gust(i, look)
		local g = gusts[i]
		if not g then
			g = { lines = {} }
			for j = 1, SEG do
				local line = look.overlay:CreateLine(nil, 'ARTWORK')
				line:SetTexture(ns.MEDIA .. 'wisp')
				line:SetBlendMode('ADD')
				g.lines[j] = line
			end
			gusts[i] = g
			Spawn(g, look, true)
		end
		return g
	end

	local function HideFrom(first)
		for i = first, #gusts do
			for _, line in ipairs(gusts[i].lines) do line:Hide() end
		end
	end

	local function Step(look)
		local half = look.w / 2
		local count = ns.Get('windCount')
		local bright = ns.Get('windBright') / 100
		local r, g, b = ns.RGB(ns.Get('windColour'))
		for i = 1, count do
			local gust = Gust(i, look)
			local far = Clamp(gust.head / half)
			gust.head = gust.head + look.w * 0.45 * look.pace * gust.speed * ( 0.5 + far ) * look.elapsed
			gust.phase = gust.phase + look.elapsed * 4 * look.pace
			gust.age = gust.age + look.elapsed
			if gust.head - gust.len > half + 20 then
				Spawn(gust, look, false)
				far = 0
			end
			-- the points along it, tail to head: outward from the middle, dropping a little as they go
			-- (the ground coming nearer), rippling on the wave
			local px, py
			local fresh = Clamp(gust.age / 0.5)                         -- (a new gust comes in over half a second)
			for j = 0, SEG do
				local d = gust.head - gust.len * ( 1 - j / SEG )
				local x = look.cx + gust.side * d
				local y = gust.y - ( d / half ) * look.h * 0.08 + gust.amp * math.sin(gust.phase + d * gust.wave)
				if j > 0 then
					local line = gust.lines[j]
					local from = gust.head - gust.len * ( 1 - ( j - 1 ) / SEG )
					if from < 0 then
						line:Hide()
					else
						line:SetStartPoint('CENTER', look.overlay, px, py)
						line:SetEndPoint('CENTER', look.overlay, x, y)
						line:SetThickness(gust.thick * ( 0.7 + 0.8 * Clamp(d / half) ))
						line:SetVertexColor(r, g, b)
						line:SetAlpha(Clamp(look.strength * bright * gust.bright * ( j / SEG ) ^ 1.3 * fresh))
						line:Show()
					end
				end
				px, py = x, y
			end
		end
		HideFrom(count + 1)
	end

	Add({ key = 'wind', Step = Step, Clear = function() HideFrom(1) end,
		Shown = function()
			local n = 0
			for _, gust in ipairs(gusts) do
				for _, line in ipairs(gust.lines) do
					if line:IsShown() then n = n + 1 break end
				end
			end
			return n
		end })
end

---------------------------------------------------------------------------
-- Dust And Seeds: textures flying outward, faster and bigger as they near the edges
---------------------------------------------------------------------------
do
	local motes = {}                      -- { tex, angle, out, speed, bright, seed, size, wobble }

	local function Spawn(m, look, anywhere)
		local low = math.random() < 0.7                                 -- most of it near the ground
		m.angle = low and ( math.pi + math.random() * math.pi ) or math.random() * math.pi
		local from = look.inner * 0.7
		m.out = from + ( anywhere and math.random() * ( look.reach - from ) or math.random() * look.reach * 0.1 )
		m.speed = 0.6 + math.random() * 0.9
		m.bright = 0.4 + math.random() * 0.6
		local seed = math.random() < 0.3
		if seed ~= m.seed then
			m.tex:SetTexture(ns.MEDIA .. ( seed and 'seed' or 'speck' ))
			m.seed = seed
		end
		m.size = seed and ( 9 + math.random() * 7 ) or ( 2.5 + math.random() * 4 )
		m.wobble = math.random() * TAU
	end

	local function Mote(i, look)
		local m = motes[i]
		if not m then
			local tex = look.overlay:CreateTexture(nil, 'OVERLAY')
			tex:SetBlendMode('ADD')
			m = { tex = tex }
			motes[i] = m
			Spawn(m, look, true)
		end
		return m
	end

	local function HideFrom(first)
		for i = first, #motes do motes[i].tex:Hide() end
	end

	local function Step(look)
		local count = ns.Get('dustCount')
		local scale = ns.Get('dustSize') / 100
		local bright = ns.Get('dustBright') / 100
		local r, g, b = ns.RGB(ns.Get('dustColour'))
		local fly = look.reach * 0.7 * look.pace
		local from = look.inner * 0.7
		for i = 1, count do
			local m = Mote(i, look)
			local far = m.out / look.reach
			m.out = m.out + fly * m.speed * ( 0.3 + 2 * far ) * look.elapsed
			m.wobble = m.wobble + look.elapsed * 3
			if m.out > look.reach * 1.05 then
				Spawn(m, look, false)
				far = m.out / look.reach
			end
			local size = m.size * ( 0.4 + 1.8 * far ) * scale
			local tex = m.tex
			tex:SetPoint('CENTER', look.overlay, 'CENTER',
				look.cx + math.cos(m.angle) * m.out, look.cy + math.sin(m.angle) * m.out)
			if m.seed then
				tex:SetSize(size, size / 2)
				tex:SetRotation(m.angle + 0.25 * math.sin(m.wobble))
				tex:SetVertexColor(r, g * 0.88, b * 0.6)
			else
				tex:SetSize(size, size)
				tex:SetVertexColor(r, g, b)
			end
			local enter = Clamp(( m.out - from ) / ( look.reach * 0.1 ))
			tex:SetAlpha(Clamp(look.strength * bright * m.bright * enter))
			tex:Show()
		end
		HideFrom(count + 1)
	end

	Add({ key = 'dust', Step = Step, Clear = function() HideFrom(1) end,
		Shown = function()
			local n = 0
			for _, m in ipairs(motes) do if m.tex:IsShown() then n = n + 1 end end
			return n
		end })
end

---------------------------------------------------------------------------
-- Warp Rings: each ring lives a moment, growing from small at the horizon to past the corners
---------------------------------------------------------------------------
do
	local rings = {}                      -- { tex, t (how far through its life, 0..1) }

	local function HideFrom(first)
		for i = first, #rings do rings[i].tex:Hide() end
	end

	local function Step(look)
		local count = ns.Get('ringCount')
		local bright = ns.Get('ringBright') / 100
		local r, g, b = ns.RGB(ns.Get('ringColour'))
		local from = math.max(look.reach * 0.04, look.inner * 0.3)
		local to = look.reach * 1.25
		for i = 1, count do
			local ring = rings[i]
			if not ring then
				local tex = look.overlay:CreateTexture(nil, 'ARTWORK', nil, -1)
				tex:SetTexture(ns.MEDIA .. 'warp')
				tex:SetBlendMode('ADD')
				ring = { tex = tex, t = ( i - 1 ) / count }
				rings[i] = ring
			end
			ring.t = ( ring.t + look.elapsed * 0.35 * look.pace ) % 1
			local radius = from * ( to / from ) ^ ring.t                -- (growing ever faster, as things nearing do)
			local tex = ring.tex
			tex:SetSize(radius * 2, radius * 2)
			tex:SetPoint('CENTER', look.overlay, 'CENTER', look.cx, look.cy)
			tex:SetVertexColor(r, g, b)
			tex:SetAlpha(Clamp(look.strength * bright * math.sin(math.pi * ring.t) ^ 1.5))
			tex:Show()
		end
		HideFrom(count + 1)
	end

	Add({ key = 'rings', Step = Step, Clear = function() HideFrom(1) end,
		Shown = function()
			local n = 0
			for _, ring in ipairs(rings) do if ring.tex:IsShown() then n = n + 1 end end
			return n
		end })
end

---------------------------------------------------------------------------
-- Edge Glow: one picture over the screen, beating with your stride
---------------------------------------------------------------------------
do
	local tex
	local beat = 0                        -- where in a stride, 0..1

	local function Step(look)
		if not tex then
			tex = look.overlay:CreateTexture(nil, 'BORDER')
			tex:SetTexture(ns.MEDIA .. 'edgeglow')
			tex:SetAllPoints(look.overlay)
			tex:SetBlendMode('ADD')
		end
		local pulse = 1
		if ns.Get('glowPulse') then
			-- about two beats a second at full stacks; a sharp beat, then easing off
			beat = ( beat + look.elapsed * 1.4 * math.min(3, math.max(0.5, look.ratio)) ) % 1
			pulse = 0.45 + 0.55 * ( 1 - beat ) ^ 2.5
		end
		tex:SetVertexColor(ns.RGB(ns.Get('glowColour')))
		tex:SetAlpha(Clamp(look.strength * ns.Get('glowBright') / 100 * pulse))
		tex:Show()
	end

	Add({ key = 'glow', Step = Step, Clear = function() if tex then tex:Hide() end end,
		Shown = function() return tex and tex:IsShown() and 1 or 0 end })
end

-- for the checks outside the game: how many of each effect's pieces are drawn now
function ns.EffectsShown()
	local out = {}
	for _, effect in ipairs(ns.effects) do out[effect.key] = effect.Shown() end
	return out
end
