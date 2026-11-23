-- Immersive Plainsrunning (Thread): the wind shows the way.
--
-- With Routes (Thread) installed and a route being followed, the point the effects rush out from leans
-- left or right toward where the route goes next, so the route can be followed with the interface gone
-- (Wind Shows The Way, off until enabled). Straight ahead is the middle of the screen; a turn to come
-- leans the point that way, more the sharper it is; a route behind you leans it all the way to the
-- nearer side. How far "all the way" is, is How Far It Leans, a share of the screen's width.
--
-- This addon does not know Routes (Thread): the trail comes through the base (PatchwerkForever.Trails),
-- in the game's world coordinates (x north, y west, on the continent UnitPosition names). It is read
-- when the base says it changed and every couple of seconds besides (it starts where you stood when it
-- was read), and only its first few hundred yards on foot are kept. Ten times a second your place and
-- the way you face are asked for, and the point aimed at is found: the place on the trail nearest you,
-- and then some tens of yards on along it, so a kink underfoot does not jerk the wind about. The lean
-- follows that gently, every moment the effects are drawn; nothing runs here while they are not.
--
-- Without a base that has the service, without Routes, without a route, on another continent than the
-- trail's, on a flight, or where the game does not say where you are or which way you face (in
-- instances, or kept secret): no lean, and the effects come from the middle as they always did.
local ADDON, ns = ...
if not ns.linked then return end

local AHEAD = 40            -- yards along the trail, from the place on it nearest you, the wind points at
local KEEP = 400            -- yards of the trail kept
local MOST = 200            -- and no more points of it than this
local ARRIVED = 5           -- yards: with the trail's end this near there is nowhere left to point
local READ_EVERY = 2        -- seconds between readings of the trail
local AIM_EVERY = 0.1       -- seconds between looks at where you are and which way you face
local EASE = 3              -- how fast the lean follows what is aimed at (a share of what is left, a second)
local AFRESH = 0.5          -- seconds without the effects after which the lean starts where it should be

local IsSecret = rawget(_G, 'issecretvalue')
local sqrt, abs, pi = math.sqrt, math.abs, math.pi

local xs, ys, lens = {}, {}, {}        -- the trail's points, and the yards from each to the next
local count, onMap = 0, nil            -- how many, and the continent they are on
local stale = true                     -- the base said the trail changed
local readAt, aimedAt, calledAt = -1e9, -1e9, -1e9
local want, lean = 0, 0                -- the lean aimed at and the lean now: -1 (left) .. 1 (right)
local listening = false
local failed                           -- set when something went wrong here: no more lean

-- the base's service, if this base has it and Routes (Thread) has offered its trails there
local function Service()
	local trails = type(ns.Base) == 'table' and ns.Base.Trails
	if type(trails) ~= 'table' or type(trails.Has) ~= 'function' or type(trails.List) ~= 'function' then return nil end
	if not listening and type(trails.OnChange) == 'function' then
		listening = true
		trails:OnChange(function() stale = true end)
	end
	return trails:Has() and trails or nil
end

-- a plain number from the game, or nil
local function Number(value)
	if IsSecret and IsSecret(value) then return nil end
	return type(value) == 'number' and value or nil
end

-- The trail you are on, as far as it is gone on foot ('walk', and 'link': a tunnel, a lift, a dock)
-- on the continent it starts on. A flight or a boat ends it: the wind cannot steer those.
local function ReadTrail(trails, now)
	readAt, stale = now, false
	count, onMap = 0, nil
	local list, trail = trails:List(), nil
	if type(list) ~= 'table' then return end
	for _, one in ipairs(list) do
		if type(one) == 'table' and one.follow then
			trail = one
			break
		end
	end
	if not ( trail and type(trail.pieces) == 'table' ) then return end
	local far = 0
	for _, piece in ipairs(trail.pieces) do
		if type(piece) ~= 'table' or not ( piece.how == 'walk' or piece.how == 'link' ) then break end
		if onMap and piece.map ~= onMap then break end
		onMap = piece.map
		for _, p in ipairs(type(piece.points) == 'table' and piece.points or {}) do
			local x, y
			if type(p) == 'table' then x, y = Number(p[1]), Number(p[2]) end
			if x and y then
				local step = count > 0 and sqrt(( x - xs[count] ) ^ 2 + ( y - ys[count] ) ^ 2) or nil
				if not step or step > 0.01 then              -- (a point twice over is one point)
					if step then
						lens[count] = step
						far = far + step
					end
					count = count + 1
					xs[count], ys[count] = x, y
					if far >= KEEP or count >= MOST then return end
				end
			end
		end
	end
end

-- @return the lean to aim at now: -1 (all the way left) .. 1 (right); nil when there is nothing to
-- point at or the game does not say where you are or which way you face
local function Aim()
	if count < 2 then return nil end
	local position, facingOf = rawget(_G, 'UnitPosition'), rawget(_G, 'GetPlayerFacing')
	if not ( position and facingOf ) then return nil end
	if ns.OnFlight and ns.OnFlight() then return nil end
	local ok, x, y, _, map = pcall(position, 'player')
	if not ok then return nil end
	x, y, map = Number(x), Number(y), Number(map)
	if not ( x and y ) or map ~= onMap then return nil end
	local known, facing = pcall(facingOf)
	facing = known and Number(facing)
	if not facing then return nil end

	-- the place on the trail nearest you: on which stretch, and how far along it (0..1)
	local best, at, along = math.huge, 1, 0
	for i = 1, count - 1 do
		local ax, ay = xs[i], ys[i]
		local dx, dy = xs[i + 1] - ax, ys[i + 1] - ay
		local t = ( ( x - ax ) * dx + ( y - ay ) * dy ) / ( lens[i] * lens[i] )
		t = t < 0 and 0 or t > 1 and 1 or t
		local d = ( ax + dx * t - x ) ^ 2 + ( ay + dy * t - y ) ^ 2
		if d < best then best, at, along = d, i, t end
	end
	-- and AHEAD yards on from there (the trail's end, if that comes first)
	local left = AHEAD + along * lens[at]
	while at < count - 1 and left > lens[at] do
		left = left - lens[at]
		at = at + 1
	end
	local t = math.min(1, left / lens[at])
	local tx, ty = xs[at] + ( xs[at + 1] - xs[at] ) * t, ys[at] + ( ys[at + 1] - ys[at] ) * t
	local dx, dy = tx - x, ty - y
	if dx * dx + dy * dy < ARRIVED * ARRIVED then return 0 end

	-- Facing is 0 looking north and grows turning left (toward the west); x is north and y is west,
	-- so the bearing of a point is measured the same way, and their difference is the turn to make:
	-- more than nothing is to the left.
	local turn = ( math.atan2(dy, dx) - facing ) % ( 2 * pi )
	if turn > pi then turn = turn - 2 * pi end
	if abs(turn) >= pi / 2 then return turn > 0 and -1 or 1 end      -- (beside or behind you: all the way)
	return -math.sin(turn)
end

local function Offset(elapsed, w)
	local trails = ns.Get('wayWind') and Service()
	if not trails then
		want, lean = 0, 0
		return 0
	end
	local now = GetTime()
	local afresh = now - calledAt > AFRESH
	calledAt = now
	if stale or now - readAt >= READ_EVERY then
		ReadTrail(trails, now)
		aimedAt = -1e9                                   -- (a new trail: aimed at again at once)
	end
	if afresh or now - aimedAt >= AIM_EVERY then
		aimedAt = now
		want = Aim() or 0
	end
	if afresh then
		lean = want                                      -- (the effects are only now coming in: no swing to see)
	else
		lean = lean + ( want - lean ) * math.min(1, elapsed * EASE)
		if abs(want - lean) < 0.001 then lean = want end
	end
	return lean * w * ns.Get('wayReach') / 100
end

-- One moment of the effects being drawn.
-- @param w : the screen's width
-- @return how far left (less than nothing) or right the point the effects come from is moved
function ns.WayOffset(elapsed, w)
	if failed then return 0 end
	local ok, offset = pcall(Offset, elapsed, w)
	if ok then return offset end
	-- (the effects go on from the middle; only the lean stops)
	failed = true
	want, lean = 0, 0
	ns.Print('Wind Shows The Way stopped after a problem, and the effects come from the middle again. /reload starts it again. The problem: ' .. tostring(offset))
	return 0
end

-- for the checks outside the game: the lean now, the lean aimed at, the points of the trail kept
function ns.WayState() return lean, want, count end
