-- Wayfarer: the planner.
--
-- Finds the quickest way over the ground (and, if asked, by flight path) between two places on a
-- map. It uses no game function, so the same file is run outside the game against the Python
-- prototype it was written from (tools: lua_trips.py).
--
-- The ground is a grid of cells of about 4.17 yards, cut into blocks of 32 x 32. Each block has
-- gates on its edges and the cost of walking between them (the map data, see pack.py). A route is:
-- from the start to its block's gates, from gate to gate across the map, from the goal's block's
-- gates to the goal. Costs are seconds at running speed.
--
-- Cells are (x, y) counted east and south from the map's north-west corner. A gate's number is
-- block * 32 + its place in the block; a block's is y * 256 + x. A flight point in the air is minus
-- its id.

local ADDON, ns = ...
local P = {}
ns.Planner = P

local byte, rep, char, concat = string.byte, string.rep, string.char, table.concat
local floor, sqrt, huge, abs, min, max = math.floor, math.sqrt, math.huge, math.abs, math.min, math.max
local BLOCK = 32
local SQ2 = sqrt(2)
local TILES_KEPT = 48                -- decoded tiles kept (16 KB each)

-- Set by the game side so a long search gives way to the next frame; left unset outside the game.
P.clock, P.budget, P.deadline = nil, 4, 0

local function breathe()
	if P.clock and P.clock() > P.deadline then
		coroutine.yield()
	end
end

---------------------------------------------------------------------------
-- A map's data, decoded as needed
---------------------------------------------------------------------------
local maps = {}

function P.Use(id)
	local s = maps[id]
	if s then return s end
	local D = PatchwerkForever_WayfarerData and PatchwerkForever_WayfarerData[id]
	if not (D and D.links and D.cells and D.graph) then return nil end
	s = {
		id = id, D = D,
		cell = D.cell, edge = 32 * D.tile,
		step = D.cell / D.speed, tick = D.tick,
		factor = { [0] = 0, D.factor[1], D.factor[2], D.factor[3] },
		tiles = {}, tileCount = 0, blocks = {}, far = {},
	}
	for _, l in ipairs(D.links) do
		local a, b = l[1] * 32 + l[2], l[3] * 32 + l[4]
		local t = s.far[a]; if not t then t = {}; s.far[a] = t end
		t[#t + 1] = b; t[#t + 1] = l[5]
		if not l[6] then                 -- (a 1 here: one way only, a drop)
			t = s.far[b]; if not t then t = {}; s.far[b] = t end
			t[#t + 1] = a; t[#t + 1] = l[5]
		end
	end
	maps[id] = s
	return s
end

function P.Forget()                  -- lets go of everything decoded (after a search, to give memory back)
	for _, s in pairs(maps) do
		s.tiles, s.tileCount, s.blocks = {}, 0, {}
	end
end

local KIND = { [0] = char(0), char(1), char(2), char(3) }

local function tileOf(s, key)        -- a tile's 128 x 128 cells as a string of kinds, or false
	local t = s.tiles[key]
	if t ~= nil then return t end
	local text = s.D.cells[key]
	if not text then
		s.tiles[key] = false
		return false
	end
	if s.tileCount >= TILES_KEPT then
		s.tiles, s.tileCount = {}, 0
	end
	local out, n, i, len = {}, 0, 1, #text
	while i <= len do
		local v = byte(text, i) - 62
		local k = v % 4
		local run = (v - k) / 4
		if run == 0 then
			run = (byte(text, i + 1) - 62) + (byte(text, i + 2) - 62) * 64 + 1
			i = i + 3
		else
			i = i + 1
		end
		n = n + 1
		out[n] = rep(KIND[k], run)
	end
	t = concat(out)
	s.tiles[key] = t
	s.tileCount = s.tileCount + 1
	return t
end

local function kindAt(s, x, y)       -- 0 no way, 1 walk, 2 wade, 3 swim
	if x < 0 or y < 0 or x >= 8192 or y >= 8192 then return 0 end
	local t = tileOf(s, floor(y / 128) * 64 + floor(x / 128))
	if not t then return 0 end
	return byte(t, (y % 128) * 128 + x % 128 + 1)
end
P.KindAt = function(id, x, y) local s = P.Use(id); return s and kindAt(s, x, y) or 0 end

local function blockOf(s, key)       -- a block's gates and the walks between them, or false
	local b = s.blocks[key]
	if b ~= nil then return b end
	local text = s.D.graph[key]
	if not text then
		s.blocks[key] = false
		return false
	end
	local n = byte(text, 1) - 62
	b = { n = n, r = {}, c = {}, k = {}, at = {}, adj = {} }
	local p = 2
	for i = 0, n - 1 do
		local v = byte(text, p) - 62 + (byte(text, p + 1) - 62) * 64
		p = p + 2
		local r = v % 32
		local c = ((v - r) / 32) % 32
		b.r[i], b.c[i], b.k[i] = r, c, floor(v / 1024)
		b.at[r * 32 + c] = i
		b.adj[i] = {}
	end
	local walks = byte(text, p) - 62 + (byte(text, p + 1) - 62) * 64
	p = p + 2
	local tick = s.tick
	for _ = 1, walks do
		local i, j = byte(text, p) - 62, byte(text, p + 1) - 62
		local cost = (byte(text, p + 2) - 62 + (byte(text, p + 3) - 62) * 64) * tick
		p = p + 4
		local a = b.adj[i]; a[#a + 1] = j; a[#a + 1] = cost
		a = b.adj[j]; a[#a + 1] = i; a[#a + 1] = cost
	end
	s.blocks[key] = b
	return b
end

---------------------------------------------------------------------------
-- A small heap: the cheapest first
---------------------------------------------------------------------------
local function push(h, key, a, b)
	local n = h.n + 1
	h.n = n
	local keys, as, bs = h.k, h.a, h.b
	while n > 1 do
		local up = floor(n / 2)
		if keys[up] <= key then break end
		keys[n], as[n], bs[n] = keys[up], as[up], bs[up]
		n = up
	end
	keys[n], as[n], bs[n] = key, a, b
end

local function pop(h)
	local keys, as, bs = h.k, h.a, h.b
	local n = h.n
	local key, a, b = keys[1], as[1], bs[1]
	local lk, la, lb = keys[n], as[n], bs[n]
	keys[n], as[n], bs[n] = nil, nil, nil
	n = n - 1
	h.n = n
	if n > 0 then
		local i = 1
		while true do
			local child = i * 2
			if child > n then break end
			if child < n and keys[child + 1] < keys[child] then child = child + 1 end
			if keys[child] >= lk then break end
			keys[i], as[i], bs[i] = keys[child], as[child], bs[child]
			i = child
		end
		keys[i], as[i], bs[i] = lk, la, lb
	end
	return key, a, b
end

local function heap()
	return { n = 0, k = {}, a = {}, b = {} }
end

---------------------------------------------------------------------------
-- Inside one block: the cheapest walk from a cell to every cell it can reach
---------------------------------------------------------------------------
local MOVES = { 1, 0, 1, -1, 0, 1, 0, 1, 1, 0, -1, 1, 1, 1, SQ2, 1, -1, SQ2, -1, 1, SQ2, -1, -1, SQ2 }

-- Returns cost and parent, both indexed by row * 32 + column + 1. With `target` it stops once that is reached.
local function spread(s, bx, by, r0, c0, target)
	local f, factor = {}, s.factor
	local x0, y0 = bx * BLOCK, by * BLOCK
	local t = tileOf(s, floor(y0 / 128) * 64 + floor(x0 / 128))
	local cost, parent = {}, {}
	if not t then return cost, parent end
	local base = (y0 % 128) * 128 + x0 % 128
	for r = 0, 31 do
		local at = base + r * 128
		for c = 0, 31 do
			f[r * 32 + c + 1] = factor[byte(t, at + c + 1)]
		end
	end
	local start = r0 * 32 + c0 + 1
	if f[start] == 0 then return cost, parent end
	local step = s.step
	cost[start] = 0
	local h = heap()
	push(h, 0, start, 0)
	while h.n > 0 do
		local d, at = pop(h)
		if d <= cost[at] then
			if at == target then break end
			local r = floor((at - 1) / 32)
			local c = (at - 1) % 32
			local here = f[at]
			for m = 1, 24, 3 do
				local dr, dc = MOVES[m], MOVES[m + 1]
				local rr, cc = r + dr, c + dc
				if rr >= 0 and cc >= 0 and rr < 32 and cc < 32 then
					local to = rr * 32 + cc + 1
					local there = f[to]
					-- no cutting a corner the ground does not allow
					if there ~= 0 and (dr == 0 or dc == 0 or (f[r * 32 + cc + 1] ~= 0 and f[rr * 32 + c + 1] ~= 0)) then
						local nd = d + step * MOVES[m + 2] * (here + there) / 2
						if nd < (cost[to] or huge) then
							cost[to] = nd
							parent[to] = at
							push(h, nd, to, 0)
						end
					end
				end
			end
		end
	end
	return cost, parent
end

---------------------------------------------------------------------------
-- Places
---------------------------------------------------------------------------
function P.CellOf(id, worldX, worldY)
	local s = P.Use(id)
	if not s then return nil end
	return floor((s.edge - worldY) / s.cell), floor((s.edge - worldX) / s.cell)
end

function P.WorldOf(id, x, y)          -- the middle of a cell
	local s = P.Use(id)
	return s.edge - (y + 0.5) * s.cell, s.edge - (x + 0.5) * s.cell
end

function P.Nearest(id, x, y, reach)   -- the nearest cell a character can stand on, or nil
	local s = P.Use(id)
	if not s then return nil end
	if kindAt(s, x, y) ~= 0 then return x, y end
	for radius = 1, reach or 12 do
		local best, bx, by
		for d = -radius, radius do
			for side = 1, 4 do
				local cx, cy
				if side == 1 then cx, cy = x + d, y - radius
				elseif side == 2 then cx, cy = x + d, y + radius
				elseif side == 3 then cx, cy = x - radius, y + d
				else cx, cy = x + radius, y + d end
				if kindAt(s, cx, cy) ~= 0 then
					local far = (cx - x) * (cx - x) + (cy - y) * (cy - y)
					if not best or far < best then best, bx, by = far, cx, cy end
				end
			end
		end
		if best then return bx, by end
	end
	return nil
end

---------------------------------------------------------------------------
-- The search
---------------------------------------------------------------------------
local function position(s, air, node)
	if node < 0 then
		local p = air.pos[node]
		return p[1], p[2]
	end
	local key = floor(node / 32)
	local b = blockOf(s, key)
	local i = node % 32
	return (key % 256) * BLOCK + b.c[i], floor(key / 256) * BLOCK + b.r[i]
end

-- The flight points of one side that the character knows, ready for a search.
local function flights(s, side, known)
	local D = s.D
	if not side or not D.points then return nil end
	local air = { pos = {}, out = {}, fromGate = {}, cells = {}, point = {} }
	local board, land = D.air.board, D.air.land
	local any = false
	for _, p in ipairs(D.points) do
		local id = p[1]
		if p[5]:find(side, 1, true) and (not known or known[id]) then
			local x, y, climb = p[3], p[4], p[7]
			air.pos[-id] = { x, y }
			air.point[-id] = p
			local out = {}
			air.out[-id] = out
			if p[6] then
				local key = floor(y / BLOCK) * 256 + floor(x / BLOCK)
				local legs = p[8]
				for n = 1, #legs, 2 do
					local gate = key * 32 + legs[n]
					local from = air.fromGate[gate]
					if not from then from = {}; air.fromGate[gate] = from end
					from[#from + 1] = -id; from[#from + 1] = legs[n + 1] + board + climb
					out[#out + 1] = gate; out[#out + 1] = legs[n + 1] + land + climb
				end
				air.cells[#air.cells + 1] = -id
				any = true
			end
		end
	end
	if not any then return nil end
	for _, f in ipairs(D.flights) do
		local out = air.out[-f[1]]
		if out and air.out[-f[2]] then
			out[#out + 1] = -f[2]; out[#out + 1] = f[3]
		end
	end
	return air
end

-- From cell (sx, sy) to cell (gx, gy), both ones a character can stand on.
-- opts.side "A" or "H" to use that side's flight paths; opts.known { [flight point id] = true } to use only those.
-- Returns nil where there is no way, or { cost = seconds, nodes = { gate or flight point, ... }, expanded = n }.
function P.Route(id, sx, sy, gx, gy, opts)
	local s = P.Use(id)
	if not s then return nil end
	opts = opts or {}
	local step, factor = s.step, s.factor
	local sbx, sby, gbx, gby = floor(sx / BLOCK), floor(sy / BLOCK), floor(gx / BLOCK), floor(gy / BLOCK)
	local skey, gkey = sby * 256 + sbx, gby * 256 + gbx
	local scost = spread(s, sbx, sby, sy % BLOCK, sx % BLOCK)
	local gcost = spread(s, gbx, gby, gy % BLOCK, gx % BLOCK)
	local air = flights(s, opts.side, opts.known)

	local goalLeg = {}
	local gb = blockOf(s, gkey)
	if gb then
		for i = 0, gb.n - 1 do
			local d = gcost[gb.r[i] * 32 + gb.c[i] + 1]
			if d then goalLeg[gkey * 32 + i] = d end
		end
	end
	local best, bestNode = huge, nil
	if skey == gkey then
		best = scost[(gy % BLOCK) * 32 + gx % BLOCK + 1] or huge
	end

	-- the least a route can still cost from a node: on foot straight to the goal, or, with flights, flying
	-- straight there and then walking from the flight point nearest the goal
	local lastWalk, fly = 0, s.cell / (s.D.air and s.D.air.speed or 32)
	if air then
		lastWalk = huge
		for _, node in ipairs(air.cells) do
			local p = air.pos[node]
			local d = sqrt((p[1] - gx) * (p[1] - gx) + (p[2] - gy) * (p[2] - gy)) * step
			if d < lastWalk then lastWalk = d end
		end
	end
	local function guess(node)
		local x, y = position(s, air, node)
		local d = sqrt((x - gx) * (x - gx) + (y - gy) * (y - gy))
		if air then
			return min(d * step, max(lastWalk, d * fly))
		end
		return d * step
	end

	local dist, parent, h = {}, {}, heap()
	local function reach(node, nd, from)
		if nd < (dist[node] or huge) then
			dist[node] = nd
			parent[node] = from
			push(h, nd + guess(node), node, nd)
		end
	end

	local sb = blockOf(s, skey)
	if sb then
		for i = 0, sb.n - 1 do
			local d = scost[sb.r[i] * 32 + sb.c[i] + 1]
			if d then reach(skey * 32 + i, d, false) end
		end
	end
	-- a flight master in the start's own block is walked to directly, and one in the goal's block walked from
	if air then
		local board, land = s.D.air.board, s.D.air.land
		for _, node in ipairs(air.cells) do
			local p = air.pos[node]
			local key = floor(p[2] / BLOCK) * 256 + floor(p[1] / BLOCK)
			local at = (p[2] % BLOCK) * 32 + p[1] % BLOCK + 1
			local climb = air.point[node][7]
			if key == skey and scost[at] then
				reach(node, scost[at] + board + climb, false)
			end
			if key == gkey and gcost[at] then
				goalLeg[node] = gcost[at] + land + climb
			end
		end
	end

	local expanded = 0
	while h.n > 0 do
		local f, at, d = pop(h)
		if d <= dist[at] then
			if f >= best then break end
			expanded = expanded + 1
			if expanded % 64 == 0 then breathe() end
			local leg = goalLeg[at]
			if leg and d + leg < best then
				best, bestNode = d + leg, at
			end
			if at < 0 then
				local out = air.out[at]
				for n = 1, #out, 2 do
					reach(out[n], d + out[n + 1], at)
				end
			else
				local key = floor(at / 32)
				local i = at % 32
				local b = blockOf(s, key)
				local adj = b.adj[i]
				local base = key * 32
				for n = 1, #adj, 2 do
					reach(base + adj[n], d + adj[n + 1], at)
				end
				-- across the block's edge
				local r, c, k = b.r[i], b.c[i], b.k[i]
				local bx = key % 256
				if c == 31 and bx < 255 then
					local nb = blockOf(s, key + 1)
					local j = nb and nb.at[r * 32]
					if j then reach((key + 1) * 32 + j, d + step * (factor[k] + factor[nb.k[j]]) / 2, at) end
				elseif c == 0 and bx > 0 then
					local nb = blockOf(s, key - 1)
					local j = nb and nb.at[r * 32 + 31]
					if j then reach((key - 1) * 32 + j, d + step * (factor[k] + factor[nb.k[j]]) / 2, at) end
				end
				if r == 31 then
					local nb = blockOf(s, key + 256)
					local j = nb and nb.at[c]
					if j then reach((key + 256) * 32 + j, d + step * (factor[k] + factor[nb.k[j]]) / 2, at) end
				elseif r == 0 and key >= 256 then
					local nb = blockOf(s, key - 256)
					local j = nb and nb.at[31 * 32 + c]
					if j then reach((key - 256) * 32 + j, d + step * (factor[k] + factor[nb.k[j]]) / 2, at) end
				end
				local far = s.far[at]
				if far then
					for n = 1, #far, 2 do
						reach(far[n], d + far[n + 1], at)
					end
				end
				local up = air and air.fromGate[at]
				if up then
					for n = 1, #up, 2 do
						reach(up[n], d + up[n + 1], at)
					end
				end
			end
		end
	end

	if best == huge then return nil end
	local nodes, at = {}, bestNode
	while at do
		nodes[#nodes + 1] = at
		at = parent[at]
	end
	for i = 1, floor(#nodes / 2) do
		nodes[i], nodes[#nodes + 1 - i] = nodes[#nodes + 1 - i], nodes[i]
	end
	return { cost = best, nodes = nodes, expanded = expanded, air = air }
end

---------------------------------------------------------------------------
-- A smoother line: detours cut out, then corners rounded
---------------------------------------------------------------------------
-- The search walks from cell to cell in eight directions, so its path zig-zags. Here a stretch of it is
-- replaced by the straight line between its ends wherever that line stays on ground, costs no more than
-- the stretch did and swims no more of it; then the corners left are rounded. Links and flights, and the
-- points at their ends, are left alone.
P.smooth = true                      -- false: the line as the search walked it; "straight": corners not rounded
local MARGIN = 0.25                  -- cells kept clear on each side of a straight stretch (about a yard)
local SLACK = 1e-6
local ROUND = 6                      -- a corner's rounding starts this many cells before it, at most (25 yards)
local SHARP = 3.0                    -- a corner turning more than this (all but back on itself) is left as it is
-- How finely corners are rounded: the most the line turns at one point of a rounded corner, and the turn below
-- which a corner is left as it is (radians: 0.35 is 20 degrees). The first that keeps the line under POINTS is used.
local FINE = { { 0.35, 0.12 }, { 0.45, 0.26 }, { 0.6, 0.4 }, { 0.8, 0.55 }, { 4, 0.7 } }
local PIECE = 1.5                    -- cells between two points of a rounded corner, at least
local POINTS = 300                   -- about the most points a line is given
local worked = 0

-- The straight line from (x0, y0) to (x1, y1), here with the cells' corners at whole numbers. Returns what
-- walking it is priced at (cells, weighted as the search weights them) and how much of it is deep water;
-- or nil where it leaves the ground or slips between two cells that are no way.
local function ray(s, x0, y0, x1, y1)
	if kindAt(s, floor(x1), floor(y1)) == 0 then return nil end
	local dx, dy = x1 - x0, y1 - y0
	local len = sqrt(dx * dx + dy * dy)
	local cx, cy = floor(x0), floor(y0)
	local sx, sy = dx > 0 and 1 or -1, dy > 0 and 1 or -1
	local tx, ty, px, py = huge, huge, huge, huge      -- when the next edge of a cell is met, and how far apart they come
	if dx ~= 0 then
		px = abs(1 / dx)
		tx = ((dx > 0 and cx + 1 or cx) - x0) / dx
	end
	if dy ~= 0 then
		py = abs(1 / dy)
		ty = ((dy > 0 and cy + 1 or cy) - y0) / dy
	end
	local factor = s.factor
	local t, price, swum = 0, 0, 0
	while true do
		local k = kindAt(s, cx, cy)
		if k == 0 then return nil end
		worked = worked + 1
		if worked % 256 == 0 then breathe() end
		local nt = min(tx, ty)
		if nt > 1 then nt = 1 end
		local part = (nt - t) * len
		price = price + part * factor[k]
		if k == 3 then swum = swum + part end
		if nt >= 1 then return price, swum end
		if tx < ty - 1e-9 then
			cx, tx = cx + sx, tx + px
		elseif ty < tx - 1e-9 then
			cy, ty = cy + sy, ty + py
		else                                              -- through a corner: not between two cells that are no way
			if kindAt(s, cx + sx, cy) == 0 or kindAt(s, cx, cy + sy) == 0 then return nil end
			cx, cy, tx, ty = cx + sx, cy + sy, tx + px, ty + py
		end
		t = nt
	end
end

-- The same between two points of a line (a cell's middle at whole numbers), with room on both sides.
-- `middle`: also along the line itself, for points that are not the middles of cells.
local function sight(s, ax, ay, bx, by, middle)
	local dx, dy = bx - ax, by - ay
	local len = sqrt(dx * dx + dy * dy)
	if len == 0 then return 0, 0 end
	if middle and not ray(s, ax + 0.5, ay + 0.5, bx + 0.5, by + 0.5) then return nil end
	local ox, oy = -dy / len * MARGIN, dx / len * MARGIN
	local p1, w1 = ray(s, ax + 0.5 + ox, ay + 0.5 + oy, bx + 0.5 + ox, by + 0.5 + oy)
	if not p1 then return nil end
	local p2, w2 = ray(s, ax + 0.5 - ox, ay + 0.5 - oy, bx + 0.5 - ox, by + 0.5 - oy)
	if not p2 then return nil end
	return (p1 + p2) / 2, (w1 + w2) / 2
end

-- The cell-by-cell points with the detours cut out: each point kept is the farthest one seen from the one before.
local function straighten(s, points)
	local count, factor = #points, s.factor
	-- what the path is priced at up to each point, and how much of it is deep water
	local price, wet = { 0 }, { 0 }
	local k0 = kindAt(s, points[1][1], points[1][2])
	for n = 2, count do
		local a, b = points[n - 1], points[n]
		local k1 = kindAt(s, b[1], b[2])
		if b[3] == "walk" then
			local d = sqrt((a[1] - b[1]) * (a[1] - b[1]) + (a[2] - b[2]) * (a[2] - b[2]))
			price[n] = price[n - 1] + d * (factor[k0] + factor[k1]) / 2
			wet[n] = wet[n - 1] + d * ((k0 == 3 and 0.5 or 0) + (k1 == 3 and 0.5 or 0))
		else
			price[n], wet[n] = price[n - 1], wet[n - 1]
		end
		k0 = k1
	end
	-- the last point of the dead straight run of cells that each walked step begins
	local run = {}
	for n = count - 1, 1, -1 do
		local a, b, c = points[n], points[n + 1], points[n + 2]
		if c and b[3] == "walk" and c[3] == "walk" and b[1] - a[1] == c[1] - b[1] and b[2] - a[2] == c[2] - b[2] then
			run[n] = run[n + 1]
		else
			run[n] = n + 1
		end
	end
	local function seen(i, j)
		if j <= run[i] then return true end
		local a, b = points[i], points[j]
		local cost, swum = sight(s, a[1], a[2], b[1], b[2])
		return cost and cost <= price[j] - price[i] + SLACK and swum <= wet[j] - wet[i] + SLACK
	end

	local kept, n = { 1 }, 1
	while n < count do
		if points[n + 1][3] ~= "walk" then
			n = n + 1
			kept[#kept + 1] = n
		else
			local last = n + 1
			while last < count and points[last + 1][3] == "walk" do last = last + 1 end
			while n < last do
				-- further and further in doubling strides until one is not seen, then between the last two
				local good, bad, stride = run[n], nil, 1
				while good < last and not bad do
					local j = min(good + stride, last)
					if seen(n, j) then good, stride = j, stride * 2 else bad = j end
				end
				while bad and bad - good > 1 do
					local mid = floor((good + bad) / 2)
					if seen(n, mid) then good = mid else bad = mid end
				end
				n = good
				kept[#kept + 1] = n
			end
		end
	end
	-- once more over the points kept: one that the points on both sides of it see past is dropped
	local line, at = { points[1] }, 1
	for k = 2, #kept - 1 do
		local here, after = points[kept[k]], points[kept[k + 1]]
		if not (here[3] == "walk" and after[3] == "walk" and seen(at, kept[k + 1])) then
			at = kept[k]
			line[#line + 1] = here
		end
	end
	if count > 1 then line[#line + 1] = points[count] end
	return line
end

-- The line with its corners rounded: each becomes a few points on an arc that touches both its sides.
-- `fine` is the most the line turns at one of those points; a corner turning less than `gentle` is left. A
-- corner whose arc would leave the ground, or cost or swim more than the corner does, is tried smaller and
-- then left as it is.
local function rounded(s, line, fine, gentle)
	local out, count = { line[1] }, #line
	local function add(x, y)
		local z = out[#out]
		if abs(z[1] - x) > 0.01 or abs(z[2] - y) > 0.01 then out[#out + 1] = { x, y, "walk" } end
	end
	for k = 2, count do
		local b = line[k]
		local done = false
		if k < count and b[3] == "walk" and line[k + 1][3] == "walk" then
			local a, c = line[k - 1], line[k + 1]
			local bx, by = b[1], b[2]
			local ux, uy, vx, vy = bx - a[1], by - a[2], c[1] - bx, c[2] - by
			local la, lb = sqrt(ux * ux + uy * uy), sqrt(vx * vx + vy * vy)
			local turn = 0
			if la > 0 and lb > 0 then
				ux, uy, vx, vy = ux / la, uy / la, vx / lb, vy / lb
				turn = math.acos(max(-1, min(1, ux * vx + uy * vy)))
			end
			if turn > gentle and turn < SHARP then
				local side = ux * vy - uy * vx > 0 and 1 or -1
				local d = min(ROUND, la / 2, lb / 2)
				while d >= 0.5 and not done do
					-- from d before the corner to d after it, on a circle that touches both sides there
					local x1, y1, x2, y2 = bx - ux * d, by - uy * d, bx + vx * d, by + vy * d
					local c1, w1 = sight(s, x1, y1, bx, by, true)
					local c2, w2 = sight(s, bx, by, x2, y2, true)
					if not (c1 and c2) then break end
					local radius = d / math.tan(turn / 2)
					local pieces = max(1, min(math.ceil(turn / fine), floor(radius * turn / PIECE)))
					local mx, my = x1 - uy * side * radius, y1 + ux * side * radius      -- the circle's middle
					local arc = { x1, y1 }
					for m = 1, pieces - 1 do
						local angle = side * turn * m / pieces
						local cos, sin = math.cos(angle), math.sin(angle)
						local rx, ry = x1 - mx, y1 - my
						arc[#arc + 1] = mx + rx * cos - ry * sin
						arc[#arc + 1] = my + rx * sin + ry * cos
					end
					arc[#arc + 1] = x2; arc[#arc + 1] = y2
					local cost, swum = 0, 0
					for m = 3, #arc, 2 do
						local c3, w3 = sight(s, arc[m - 2], arc[m - 1], arc[m], arc[m + 1], true)
						if not c3 then cost = nil; break end
						cost, swum = cost + c3, swum + w3
					end
					if cost and cost <= c1 + c2 + SLACK and swum <= w1 + w2 + SLACK then
						for m = 1, #arc, 2 do add(arc[m], arc[m + 1]) end
						done = true
					end
					d = d / 2
				end
			end
		end
		if not done then
			local z = out[#out]
			if b[3] ~= "walk" or k == count or z[1] ~= b[1] or z[2] ~= b[2] then out[#out + 1] = b end
		end
	end
	-- points that came to lie in one straight line (a zig-zag's corners, each cut) are its two ends
	local slim = { out[1] }
	for k = 2, #out - 1 do
		local a, b, c = slim[#slim], out[k], out[k + 1]
		local ux, uy, vx, vy = b[1] - a[1], b[2] - a[2], c[1] - b[1], c[2] - b[2]
		local straight = b[3] == "walk" and c[3] == "walk" and abs(ux * vy - uy * vx) < 1e-9
			and ux * vx + uy * vy > 0
		if not straight then slim[#slim + 1] = b end
	end
	if #out > 1 then slim[#slim + 1] = out[#out] end
	return slim
end

local function smoothed(s, points)
	local line = straighten(s, points)
	if P.smooth == "straight" then return line end
	local best
	for _, fine in ipairs(FINE) do
		local try = rounded(s, line, fine[1], fine[2])
		if not best or #try < #best then best = try end
		if #best <= POINTS then break end
	end
	return best
end

---------------------------------------------------------------------------
-- The route as a line to draw, and what it is made of
---------------------------------------------------------------------------
-- Returns { points = { { x, y, how }, ... }, yards =, swum =, flown = { { id, id, ... }, ... }, seconds = }.
-- x and y are cells; `how` says how a point is reached from the one before: "walk", "link" (a tunnel, bridge
-- or lift) or "fly". The walked stretches are smoothed (above), so x and y may fall between cells; the yards
-- and the time are those of the path as the search walked it.
function P.Line(id, sx, sy, gx, gy, found)
	local s = P.Use(id)
	local air = found.air
	local stops = { { sx, sy, false } }
	for _, node in ipairs(found.nodes) do
		local x, y = position(s, air, node)
		stops[#stops + 1] = { x, y, node < 0, node }
	end
	stops[#stops + 1] = { gx, gy, false }
	local points = { { sx, sy, "walk" } }
	local flown, flight = {}, nil
	for n = 2, #stops do
		local a, b = stops[n - 1], stops[n]
		local ax, ay, bx, by = a[1], a[2], b[1], b[2]
		if a[3] and b[3] then
			if not flight then flight = { -a[4] }; flown[#flown + 1] = flight end
			flight[#flight + 1] = -b[4]
			points[#points + 1] = { bx, by, "fly" }
		else
			flight = nil
			local abx, aby = floor(ax / BLOCK), floor(ay / BLOCK)
			if ax == bx and ay == by then
				-- the same cell: boarding or landing beside the flight master
			elseif abx == floor(bx / BLOCK) and aby == floor(by / BLOCK) then
				local target = (by % BLOCK) * 32 + bx % BLOCK + 1
				local cost, parent = spread(s, abx, aby, ay % BLOCK, ax % BLOCK, target)
				if cost[target] then
					local back, at = {}, target
					while at do
						back[#back + 1] = at
						at = parent[at]
					end
					for k = #back - 1, 1, -1 do
						local cell = back[k] - 1
						points[#points + 1] = { abx * BLOCK + cell % 32, aby * BLOCK + floor(cell / 32), "walk" }
					end
				else
					points[#points + 1] = { bx, by, "link" }
				end
				breathe()
			elseif abs(ax - bx) <= 1 and abs(ay - by) <= 1 then
				points[#points + 1] = { bx, by, "walk" }
			else
				points[#points + 1] = { bx, by, "link" }
			end
		end
	end
	-- lengths, and the time it really takes (swimming is priced above its real slowness)
	local yards, swum = 0, 0
	for n = 2, #points do
		local a, b = points[n - 1], points[n]
		if b[3] == "walk" then
			local d = sqrt((a[1] - b[1]) * (a[1] - b[1]) + (a[2] - b[2]) * (a[2] - b[2])) * s.cell
			yards = yards + d
			if kindAt(s, a[1], a[2]) == 3 and kindAt(s, b[1], b[2]) == 3 then swum = swum + d end
		end
	end
	local seconds = found.cost - swum * (s.factor[3] - 1.5) / s.D.speed
	if P.smooth then
		return { points = smoothed(s, points), yards = yards, swum = swum, flown = flown, seconds = seconds }
	end
	-- not smoothed: a straight run of cells is its two ends
	local slim = { points[1] }
	for n = 2, #points - 1 do
		local a, b, c = slim[#slim], points[n], points[n + 1]
		local straight = b[3] == "walk" and c[3] == "walk"
			and (b[1] - a[1]) * (c[2] - b[2]) == (b[2] - a[2]) * (c[1] - b[1])
			and (b[1] - a[1]) * (c[1] - b[1]) >= 0 and (b[2] - a[2]) * (c[2] - b[2]) >= 0
		if not straight then slim[#slim + 1] = b end
	end
	if #points > 1 then slim[#slim + 1] = points[#points] end
	return { points = slim, yards = yards, swum = swum, flown = flown, seconds = seconds }
end

function P.PointName(id, pointID)
	local s = P.Use(id)
	if s and s.D.points then
		for _, p in ipairs(s.D.points) do
			if p[1] == pointID then return p[2] end
		end
	end
	return tostring(pointID)
end
