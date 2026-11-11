local _, ns = ...;
local R = ns.Route;
if not R then return end;
local M = R.M;
local G = M.Ground;
local Dist = R.Dist;
---------------------------------------------------------------
-- Blocked spots
---------------------------------------------------------------
-- Route's ground map is flat: it knows a wall between two cells,
-- not a cliff's height, and a trail can lead where no one can
-- walk. Here the spot is learned: when you are on the trail,
-- trying to move and getting nowhere, the stretch just ahead is
-- marked blocked, for every character (PatchwerkForeverDB is the
-- account's).
--
-- What a blocked spot does:
--   * Route's ground map has no floor there (its cells read as "z",
--     stamped over the pieces of rows Route spells out as it reads
--     them: M.Ground.Piece). Every straight leg, shortcut and walk
--     over open ground is checked against that map, so none crosses
--     the spot any more. Only the navmesh's grids (g.edges) are
--     stamped; a continent without one is left as it is.
--   * The paths Route learned from you that cross it are cut from
--     its saved paths at login, before its road map is built.
-- What it cannot do: the roads shipped with MelloUI are links in
-- Route's own graph, out of reach from here. A route along one of
-- those through a blocked spot is said, not changed.
--
-- A spot seen once is forgotten after a month; seen again, it stays.

local RADIUS   = 9;     -- yards
local AHEAD    = 12;    -- the spot's middle, this far along the trail from where you stood
local NEAR     = 30;    -- yards beside the trail: farther is a detour, not a block
local WANDER   = 35;    -- yards from where progress stopped: farther is somewhere else
local PUSHING  = 4;     -- seconds moving without getting anywhere (a wall, a ledge)
local MILLING  = 20;    -- seconds moving about with no progress along the trail
local GOAL     = 60;    -- yards from the destination: nearer, standing about is expected
local COOLDOWN = 30;    -- seconds between two spots
local EXPIRE   = 30 * 24 * 3600;
local MOST     = 200;

local Blocks = {};
R.Blocks = Blocks;

local function List()
	local saved = R:GetSaved();
	return saved and saved.blocks or {};
end

---------------------------------------------------------------
-- Geometry
---------------------------------------------------------------
-- the nearest point of segment a-b to p: its share along the segment, the distance
local function Project(px, py, ax, ay, bx, by)
	local dx, dy = bx - ax, by - ay;
	local len2 = dx * dx + dy * dy;
	local t = len2 > 0 and ( ( px - ax ) * dx + ( py - ay ) * dy ) / len2 or 0;
	t = t < 0 and 0 or t > 1 and 1 or t;
	return t, Dist(px, py, ax + dx * t, ay + dy * t);
end

local function Walkable(a, b)
	return a[1] == b[1] and b[4] ~= 'boat' and b[4] ~= 'flight';
end

---------------------------------------------------------------
-- The ground map
---------------------------------------------------------------
local index = {};   -- [grid] = { [row] = { [column] = true } }

local function Rows(cont, g)
	local rows = {};
	for _, b in ipairs(List()) do
		if ( b.cont == cont ) then
			local cell = g.cell;
			local cx = ( b.x / g.sx - g.e0 ) / cell;
			local cy = ( b.y / g.sy - g.s0 ) / cell;
			-- (two cells thick at least: a line's own end cell is never asked)
			local reach = math.max(1.3, ( b.r or RADIUS ) / g.sx / cell);
			for r = math.floor(cy - reach), math.floor(cy + reach) do
				for q = math.floor(cx - reach), math.floor(cx + reach) do
					local ox, oy = q + 0.5 - cx, r + 0.5 - cy;
					if ( ox * ox + oy * oy <= reach * reach and r >= 0 and q >= 0 and r < g.h and q < g.w ) then
						rows[r] = rows[r] or {};
						rows[r][q] = true;
					end
				end
			end
		end
	end
	return rows;
end

-- the pieces of rows Route keeps spelled out, let go where a spot lies: read again, stamped or not
local function Flush(g, rows)
	local seg = G.SEG;
	if not ( type(g.pieces) == 'table' and seg ) then return end;
	for r, row in pairs(rows) do
		for q in pairs(row) do
			g.pieces[r * 65536 + ( q - q % seg )] = nil;
		end
	end
end

local function Rebuild()
	for g, rows in pairs(index) do
		Flush(g, rows)
	end
	index = {};
	if not R:Get('blocked') then return end;
	for cont, g in pairs(G.grids or {}) do
		if ( type(g) == 'table' and g.edges and type(g.cell) == 'number' and g.sx and g.e0 and g.w ) then
			local rows = Rows(cont, g);
			if next(rows) then
				index[g] = rows;
				Flush(g, rows)
			end
		end
	end
end

local function Changed()
	R.Try('blocked spots map', Rebuild)
end

local function Stamp(g, r, c0, piece, row)
	local len, changed = #piece, false;
	for q in pairs(row) do
		local o = q - c0;
		if ( o >= 0 and o < len ) then
			piece = piece:sub(1, o) .. 'z' .. piece:sub(o + 2);
			changed = true;
		end
	end
	if changed then
		g.pieces[r * 65536 + c0] = piece;
		return piece;
	end
end

local Piece = G.Piece;
if ( type(Piece) == 'function' and G.SEG and G.OPENB and G.OPENB[122] == nil ) then
	G.Piece = function(g, r, c0)
		local piece = Piece(g, r, c0);
		local rows = index[g];
		local row = rows and rows[r];
		if ( row and type(piece) == 'string' ) then
			local ok, stamped = pcall(Stamp, g, r, c0, piece, row);
			if ( ok and stamped ) then
				return stamped;
			end
		end
		return piece;
	end
	-- (Route's ground map comes in with its road map: the spots onto it then)
	if ( type(G.Set) == 'function' ) then
		hooksecurefunc(G, 'Set', Changed)
	end
end
R:OnSetting('blocked', Changed)

---------------------------------------------------------------
-- The list
---------------------------------------------------------------
local lastAdded;

function Blocks:Count()
	return #List();
end

function Blocks:Add(cont, x, y, dx, dy)
	local list = List();
	for _, b in ipairs(list) do
		if ( b.cont == cont and Dist(b.x, b.y, x, y) < RADIUS ) then
			b.n, b.at = ( b.n or 1 ) + 1, time();
			return b, false;
		end
	end
	local b = { cont = cont, x = x, y = y, r = RADIUS, dx = dx, dy = dy, at = time(), n = 1 };
	tinsert(list, b)
	while ( #list > MOST ) do
		tremove(list, 1)
	end
	lastAdded = b;
	Changed()
	return b, true;
end

-- the spot marked last (this session's, else the newest saved): taken back
function Blocks:Undo()
	local list = List();
	local at;
	for i, b in ipairs(list) do
		if ( b == lastAdded ) then
			at = i;
			break;
		end
		if ( not at or ( b.at or 0 ) > ( list[at].at or 0 ) ) then
			at = i;
		end
	end
	if not at then
		return false;
	end
	tremove(list, at)
	lastAdded = nil;
	Changed()
	return true;
end

function Blocks:Clear()
	local list = List();
	local n = #list;
	wipe(list)
	lastAdded = nil;
	Changed()
	return n;
end

---------------------------------------------------------------
-- The paths Route learned from you
---------------------------------------------------------------
-- MelloUIRouteSaved.routes.graphs[cont][cell] = { x, y, { [cell] = seconds } }:
-- the player's own walked paths, kept by Route in its saved variable
-- and merged into its road map as that is built.
local function Prune()
	local saved = rawget(_G, 'MelloUIRouteSaved');
	local graphs = type(saved) == 'table' and type(saved.routes) == 'table' and saved.routes.graphs;
	if ( type(graphs) ~= 'table' ) then
		return 0;
	end
	local cut = 0;
	for _, b in ipairs(List()) do
		local graph = graphs[b.cont] or graphs[tostring(b.cont)];
		if ( type(graph) == 'table' ) then
			local reach = ( b.r or RADIUS ) + 55;   -- (Route links crumbs up to 50 yards apart)
			for key, node in pairs(graph) do
				if ( type(node) == 'table' and type(node[1]) == 'number' and type(node[2]) == 'number' and type(node[3]) == 'table'
				and math.abs(node[1] - b.x) < reach and math.abs(node[2] - b.y) < reach ) then
					for other in pairs(node[3]) do
						local far = graph[other];
						if ( type(far) == 'table' and type(far[1]) == 'number' and type(far[2]) == 'number' ) then
							local _, d = Project(b.x, b.y, node[1], node[2], far[1], far[2]);
							if ( d < ( b.r or RADIUS ) ) then
								node[3][other] = nil;
								if ( type(far[3]) == 'table' ) then
									far[3][key] = nil;
								end
								cut = cut + 1;
							end
						end
					end
				end
			end
		end
	end
	return cut;
end

local function Expire()
	local list, now = List(), time();
	for i = #list, 1, -1 do
		local b = list[i];
		if ( ( b.n or 1 ) < 2 and now - ( b.at or now ) > EXPIRE ) then
			tremove(list, i)
		end
	end
end

---------------------------------------------------------------
-- Noticing a block
---------------------------------------------------------------
local track = {};

-- a route's length up to each of its points, over what is walked
local function Measure(points)
	local cum, total = { 0 }, 0;
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1];
		if Walkable(a, b) then
			total = total + Dist(a[2], a[3], b[2], b[3]);
		end
		cum[i + 1] = total;
	end
	return cum, total;
end

-- where on the route the player is: the yards along it, the yards beside it
local function Place(points, cum, cont, px, py)
	local along, beside = nil, math.huge;
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1];
		if ( a[1] == cont and Walkable(a, b) ) then
			local t, d = Project(px, py, a[2], a[3], b[2], b[3]);
			if ( d < beside ) then
				along, beside = cum[i] + ( cum[i + 1] - cum[i] ) * t, d;
			end
		end
	end
	return along, beside;
end

-- the point this far along the route, and the way the route runs there
local function PointAt(points, cum, along)
	for i = 1, #points - 1 do
		local len = cum[i + 1] - cum[i];
		if ( len > 0 and along <= cum[i + 1] ) then
			local a, b = points[i], points[i + 1];
			local t = ( along - cum[i] ) / len;
			t = t < 0 and 0 or t;
			return a[1], a[2] + ( b[2] - a[2] ) * t, a[3] + ( b[3] - a[3] ) * t, ( b[2] - a[2] ) / len, ( b[3] - a[3] ) / len;
		end
	end
end

-- a route along MelloUI's own roads through a spot: said, since it cannot be changed
local saidAt = 0;
local function Crossing(points)
	local list = List();
	if ( #list == 0 or GetTime() - saidAt < 120 ) then return end;
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1];
		if Walkable(a, b) then
			for _, s in ipairs(list) do
				if ( s.cont == a[1] and math.abs(a[2] - s.x) < 80 and math.abs(a[3] - s.y) < 80 ) then
					local _, d = Project(s.x, s.y, a[2], a[3], b[2], b[3]);
					if ( d < ( s.r or RADIUS ) * 0.6 ) then
						saidAt = GetTime();
						return R:Say("This route still crosses a spot marked blocked: one of MelloUI's own roads runs through it, which can't be changed from here. Expect to go round it.");
					end
				end
			end
		end
	end
end

local function Still()
	track.moving, track.pushing = 0, 0;
end

local function Tick()
	if not ( R:Active() and R:Get('blocked') ) then return end;
	local route, dest = M:CurrentRoute();
	local points = type(route) == 'table' and route.points;
	if not ( dest and type(points) == 'table' and #points >= 2 ) then
		track.route = nil;
		return;
	end
	if ( track.route ~= route ) then
		track.route = route;
		track.cum, track.total = Measure(points);
		track.best, track.bx, track.by, track.lastX = nil, nil, nil, nil;
		Still()
		Crossing(points)
	end
	if ( UnitAffectingCombat('player') or UnitIsDeadOrGhost('player') or UnitOnTaxi('player')
	or IsFlying() or IsFalling() or IsSwimming() ) then
		track.lastX = nil;
		return Still();
	end
	local cont, x, y = R:Where();
	if not cont then return end;
	local along, beside = Place(points, track.cum, cont, x, y);
	local now = GetTime();
	if ( not along or beside > NEAR ) then
		track.best, track.lastX = nil, nil;
		return Still();
	end
	if ( not track.best or along > track.best + 3 or Dist(x, y, track.bx, track.by) > WANDER ) then
		-- (getting on, or gone somewhere else: from here again)
		track.best, track.bx, track.by = along, x, y;
		Still()
	elseif track.lastX then
		local dt = now - track.lastAt;
		local speed = GetUnitSpeed('player') or 0;
		if ( speed > 1 and dt > 0 and dt < 3 ) then
			track.moving = track.moving + dt;
			if ( Dist(x, y, track.lastX, track.lastY) < speed * dt * 0.35 ) then
				track.pushing = track.pushing + dt;
			end
		end
	end
	track.lastX, track.lastY, track.lastAt = x, y, now;

	if ( now < ( track.quietUntil or 0 ) ) then return end;
	if not ( track.pushing >= PUSHING or track.moving >= MILLING ) then return end;
	local goalFar = dest.cont ~= cont or not dest.x or Dist(x, y, dest.x, dest.y) > GOAL;
	if ( goalFar and track.total - track.best > GOAL ) then
		local bcont, bx, by, dx, dy = PointAt(points, track.cum, track.best + AHEAD);
		if bcont then
			local _, new = Blocks:Add(bcont, bx, by, dx, dy);
			if new then
				R:Say("You don't seem able to follow the trail here, so the stretch ahead is marked blocked. Step off the trail and Route plans another way. (Undo: /patchwerk route unblock)")
			end
		end
	end
	track.quietUntil = now + COOLDOWN;
	Still()
end

---------------------------------------------------------------
-- By hand
---------------------------------------------------------------
-- where the player is on the route now: its points, lengths, the yards along and beside it
local function Here()
	local route, dest = M:CurrentRoute();
	local points = type(route) == 'table' and route.points;
	if not ( dest and type(points) == 'table' and #points >= 2 ) then
		return nil, 'There is no route.';
	end
	local cont, x, y = R:Where();
	if not cont then
		return nil, 'The game gives no place for you here.';
	end
	local cum = Measure(points);
	local along, beside = Place(points, cum, cont, x, y);
	if ( not along or beside > NEAR + 10 ) then
		return nil, 'You are not on the trail.';
	end
	return points, cum, along;
end

-- The trail just ahead marked blocked: for a stretch no one should
-- try (a drop off a cliff), which the watch above never sees.
-- @return true, or false and why not
function Blocks:MarkAhead()
	local points, cum, along = Here();
	if not points then
		return false, cum;
	end
	local cont, x, y, dx, dy = PointAt(points, cum, along + AHEAD);
	if not cont then
		return false, 'The trail ends here.';
	end
	local b = self:Add(cont, x, y, dx, dy);
	b.n = math.max(b.n or 1, 2);   -- (marked by hand: kept, not forgotten after a month)
	return true;
end

-- What the next stretch of the trail is made of, so a bad one can be
-- told apart: a path the player taught Route (which can be forgotten),
-- a straight line where Route knows nothing, or MelloUI's own roads.
-- @return lines of text, or nil and why not
function Blocks:Describe(reach)
	local points, cum, along = Here();
	if not points then
		return nil, cum;
	end
	local Learned = R.Learned;
	local function Kind(a, b)
		if ( b[4] == 'flight' or b[4] == 'boat' ) then
			return 'a ' .. b[4];
		elseif ( b[4] == 'guess' ) then
			return 'a straight line (nothing known there)';
		elseif ( Learned and Learned:At(a[1], a[2], a[3]) and Learned:At(b[1], b[2], b[3]) ) then
			return 'a path you taught Route';
		end
		return "MelloUI's roads and ground";
	end
	local lines, kind, from = {}, nil, 0;
	local function Close(to)
		if kind then
			lines[#lines + 1] = ('%d to %d yd: %s'):format(from, to, kind);
		end
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1];
		local start, stop = cum[i] - along, cum[i + 1] - along;
		if ( stop > 0 and start < reach and ( stop > start or not Walkable(a, b) ) ) then
			local now = Kind(a, b);
			if ( now ~= kind ) then
				local at = math.max(0, math.floor(start + 0.5));
				Close(at)
				kind, from = now, at;
			end
		end
		if ( start >= reach ) then
			break;
		end
	end
	Close(reach)
	return lines;
end

local Watcher = CreateFrame('Frame')
local elapsed = 0;
Watcher:SetScript('OnUpdate', function(_, dt)
	elapsed = elapsed + dt;
	if ( elapsed < 1 ) then return end;
	elapsed = 0;
	R.Try('blocked spots watch', Tick)
end)
Watcher:RegisterEvent('PLAYER_LOGIN')
Watcher:SetScript('OnEvent', function(self, event)
	self:UnregisterEvent(event)
	R.Try('blocked spots load', function()
		Expire()
		if R:Get('blocked') then
			Prune()
		end
		Rebuild()
	end)
end)
