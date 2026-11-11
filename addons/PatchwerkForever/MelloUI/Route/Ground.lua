local _, ns = ...;
local R = ns.Route;
if not R then return end;
local M = R.M;
local G = M.Ground;
---------------------------------------------------------------
-- Roads before shortcuts, and round water
---------------------------------------------------------------
-- Route prices open ground at PACE times a road (1.05: nearly the
-- same) and a swum yard at SWIM times one (about 1.5 once its
-- ground map is in), so a shortcut over a ridge or through a lake
-- wins over the road round it by a hair. Both are plain fields of
-- Route's ground table, read each time a leg is priced; the ground
-- links of its road map take PACE as that map is built, so Prefer
-- Roads is whole after a reload.

local ROADS_PACE = 1.35;   -- a shortcut must save a quarter of the way
local WATER_SWIM = 3.5;

local base = { PACE = G.PACE, SWIM = G.SWIM };

local function HasEdgeGrid()
	for _, grid in pairs(G.grids or {}) do
		if ( type(grid) == 'table' and grid.edges ) then
			return true;
		end
	end
	return false;
end

local function Apply()
	G.PACE = R:Get('preferRoads') and math.max(base.PACE, ROADS_PACE) or base.PACE;
	-- (Route's own: the real swimming pace once its ground map knows water)
	local swim = ( HasEdgeGrid() and G.SWIM_REAL ) or base.SWIM;
	G.SWIM = R:Get('avoidWater') and math.max(swim, WATER_SWIM) or swim;
end

Apply()
-- Route sets SWIM as it takes its ground map in, just before the
-- road map's links are priced: ours again right after.
if ( type(G.Set) == 'function' ) then
	hooksecurefunc(G, 'Set', function() R.Try('ground prices', Apply) end)
end
R:OnSetting('preferRoads', Apply)
R:OnSetting('avoidWater', Apply)

---------------------------------------------------------------
-- Learn only real paths
---------------------------------------------------------------
-- Route learns where you go: a crumb every half second, linked to
-- the one before as a path both ways at walking price. A drop off
-- a ledge, a swim, a flying mount or a ghost's run are learned the same,
-- and routes then lead up the cliff or through the lake. Its
-- learning has one switch (its Learn Paths While Playing setting),
-- held off here for those moments. Route links a new crumb to the
-- last one within 50 yards, so after a drop the switch stays off
-- until you are farther than that from where it began.
--
-- A hop is told from a drop by the jump key: a fall that began
-- with a jump and ends within a second is a hop.

local CLEAR      = 58;    -- yards from where it began before learning is back
local HOP        = 1.1;   -- seconds: a jump's fall up to this long is a hop
local STEP       = 0.5;   -- seconds: a fall without a jump up to this long is a step down
local SWIM_AFTER = 1.5;   -- seconds swimming before it counts
local TICK       = 0.1;

local held;        -- nil, or { cont, x, y, hard = bool }: why learning is off
local fallAt, fallJumped, swimAt;
local lastJump = 0;

R.lastDrop = 0;    -- when a real drop last ended (the blocked spots' reader)

if ( type(JumpOrAscendStart) == 'function' ) then
	hooksecurefunc('JumpOrAscendStart', function() lastJump = GetTime() end)
end

local function Hold(hard)
	local saved = R:GetSaved();
	if not held then
		if not M.db.learn then return end;   -- (the player's own choice: left alone)
		local cont, x, y = R:Where();
		held = { cont = cont, x = x, y = y };
		M.db.learn = false;
		if saved then saved.learnPaused = true end;
	end
	held.hard = held.hard or hard or false;
end

local function Release()
	held = nil;
	M.db.learn = true;
	local saved = R:GetSaved();
	if saved then saved.learnPaused = nil end;
end

-- A session that ended while learning was held: back on.
local function Restore()
	local saved = R:GetSaved();
	if ( saved and saved.learnPaused and not held and type(M.db) == 'table' ) then
		M.db.learn = true;
		saved.learnPaused = nil;
	end
end

-- The capitals whose streets MelloUI ships, walked by hand with their
-- lifts and trams (Route's own list of them). Nothing is learned
-- there: a crumb trail off Thunder Bluff's rim is a path like any
-- other to Route, and it led routes over the edge.
local CITIES = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true };
local cityAt, inCity = 0, false;

local function InCity(now)
	if ( now - cityAt >= 1 ) then
		cityAt = now;
		local ok, mapID = pcall(C_Map.GetBestMapForUnit, 'player');
		inCity = ok and CITIES[mapID] or false;
	end
	return inCity;
end

local function Tick()
	if not R:Active() then return end;
	local safe, streets = R:Get('safeLearning'), R:Get('cityStreets');
	if not ( safe or streets ) then
		if held then Release() end;
		return;
	end
	local now = GetTime();
	local falling, swimming = safe and IsFalling(), safe and IsSwimming();
	-- (a flight master's flight is Route's own to learn: its times)
	local away = ( safe and ( UnitIsGhost('player') or IsFlying() ) ) or ( streets and InCity(now) );

	if falling then
		if not fallAt then
			fallAt, fallJumped = now, ( now - lastJump ) < 0.4;
			Hold(false)   -- (from its first moment: a crumb in the air is linked like any other)
		end
		if ( now - fallAt ) > ( fallJumped and HOP or STEP ) then
			Hold(true)
			R.lastDrop = now;
		end
	elseif fallAt then
		fallAt = nil;
	end

	if swimming then
		swimAt = swimAt or now;
		if ( now - swimAt ) > SWIM_AFTER then
			Hold(true)
		end
	else
		swimAt = nil;
	end

	if away then
		Hold(true)
	end

	if ( held and not falling and not swimming and not away ) then
		if not held.hard then
			return Release();
		end
		local cont, x, y = R:Where();
		if ( cont and ( cont ~= held.cont or not held.x or R.Dist(x, y, held.x, held.y) > CLEAR ) ) then
			Release()
		end
	end
end

---------------------------------------------------------------
-- Forgetting what was learned
---------------------------------------------------------------
-- MelloUIRouteSaved.routes.graphs[cont][cell] = { x, y, { [cell] = seconds } }:
-- the player's own walked paths, which Route keeps in its saved
-- variable and merges into its road map as that is built. Points
-- are taken out of it at login, before that build; Route's map of
-- a session under way cannot be changed, and its logout writes that
-- map back, so a forgetting asked for mid-session waits for the
-- next login (PatchwerkForeverDB.Route.forget).
local Learned = {};
R.Learned = Learned;

function Learned:Graph(cont)
	local saved = rawget(_G, 'MelloUIRouteSaved');
	local graphs = type(saved) == 'table' and type(saved.routes) == 'table' and saved.routes.graphs;
	local graph = type(graphs) == 'table' and ( graphs[cont] or graphs[tostring(cont)] );
	return type(graph) == 'table' and graph or nil;
end

-- the saved point at a place, when it is the player's own (Route keys them by their 10 yard cell)
function Learned:At(cont, x, y)
	local graph = self:Graph(cont);
	local node = graph and graph[math.floor(x / 10) .. ':' .. math.floor(y / 10)];
	return type(node) == 'table' and type(node[1]) == 'number' and type(node[2]) == 'number'
		and math.abs(node[1] - x) < 1 and math.abs(node[2] - y) < 1;
end

-- @param inside : function(x, y) -> true for a point to forget
-- @return count : points forgotten
function Learned:Forget(cont, inside)
	local graph = self:Graph(cont);
	if not graph then
		return 0;
	end
	local gone, count = {}, 0;
	for key, node in pairs(graph) do
		if ( type(node) == 'table' and type(node[1]) == 'number' and type(node[2]) == 'number' and inside(node[1], node[2]) ) then
			gone[key], count = true, count + 1;
		end
	end
	if ( count == 0 ) then
		return 0;
	end
	for key in pairs(gone) do
		graph[key] = nil;
	end
	for _, node in pairs(graph) do
		if ( type(node) == 'table' and type(node[3]) == 'table' ) then
			for other in pairs(node[3]) do
				if gone[other] then
					node[3][other] = nil;
				end
			end
		end
	end
	return count;
end

-- what was learned inside a capital's own map
local function ForgetCities()
	if not ( M.OnMap and M.ContinentOf ) then
		return 0;
	end
	local count = 0;
	for mapID in pairs(CITIES) do
		local cont = M.ContinentOf(mapID);
		-- (a map's place is a straight scaling of the continent's yards: two asks give it)
		local ax, ay, bx, by;
		if cont then
			ax, ay = M.OnMap(mapID, cont, 0, 0);
			bx, by = M.OnMap(mapID, cont, 10000, 10000);
		end
		if ( ax and ay and bx and by ) then
			count = count + Learned:Forget(cont, function(x, y)
				local fx, fy = ax + ( bx - ax ) * x / 10000, ay + ( by - ay ) * y / 10000;
				return fx >= 0 and fx <= 1 and fy >= 0 and fy <= 1;
			end);
		end
	end
	return count;
end

-- the places asked to be forgotten last session (/patchwerk route forget)
local function ForgetAsked()
	local saved = R:GetSaved();
	local list = saved and saved.forget;
	if ( type(list) ~= 'table' ) then
		return 0;
	end
	saved.forget = nil;
	local count = 0;
	for _, disc in ipairs(list) do
		if ( type(disc) == 'table' and disc.cont and disc.x and disc.y and disc.r ) then
			count = count + Learned:Forget(disc.cont, function(x, y)
				return R.Dist(x, y, disc.x, disc.y) <= disc.r;
			end);
		end
	end
	return count;
end

-- @return true when it is kept for the next login
function Learned:ForgetHere(radius)
	local saved = R:GetSaved();
	local cont, x, y = R:Where();
	if not ( saved and cont ) then
		return false;
	end
	saved.forget = saved.forget or {};
	tinsert(saved.forget, { cont = cont, x = x, y = y, r = radius })
	return true;
end

-- (the maps may not answer in the login's first moment: once more as the world comes in,
-- still before Route's road map is built)
local citiesDone = false;
local function AtLoginCities()
	if citiesDone then return end;
	if not R:Get('cityStreets') then
		citiesDone = true;
		return;
	end
	local ok, cities = pcall(ForgetCities);
	if not ok then return end;
	citiesDone = true;
	if ( cities > 0 ) then
		R:Say(("Forgot %d points Route had learned from you inside cities. MelloUI's own city streets, lifts included, are used there."):format(cities))
	end
end

local function AtLogin()
	local asked = ForgetAsked();
	if ( asked > 0 ) then
		R:Say(('Forgot %d points of the paths you taught Route where you asked.'):format(asked))
	end
	AtLoginCities()
end

local Watcher = CreateFrame('Frame')
local elapsed = 0;
Watcher:SetScript('OnUpdate', function(_, dt)
	elapsed = elapsed + dt;
	if ( elapsed < TICK ) then return end;
	elapsed = 0;
	R.Try('learning watch', Tick)
end)
Watcher:RegisterEvent('PLAYER_LOGIN')
Watcher:RegisterEvent('PLAYER_LOGOUT')
Watcher:RegisterEvent('PLAYER_ENTERING_WORLD')
Watcher:SetScript('OnEvent', function(self, event)
	if ( event == 'PLAYER_LOGOUT' ) then
		if ( held and type(M.db) == 'table' ) then
			Release()
		end
		return;
	elseif ( event == 'PLAYER_ENTERING_WORLD' ) then
		self:UnregisterEvent(event)
		return R.Try('learned paths', AtLoginCities);
	end
	R.Try('learned paths', AtLogin)
	C_Timer.After(5, function() R.Try('learning restore', Restore) end)
end)
