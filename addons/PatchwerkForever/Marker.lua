local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Marker: the game's waypoint, lent to the route planner (2.9.0)
---------------------------------------------------------------
-- The game draws its waypoint marker in the world (and its arrow
-- at the screen's edge) on one place: your map pin or the quest
-- you track. It is the only place in the world whose spot on
-- screen an addon is told. So the route planner can borrow it to
-- mark the way ahead of you on its trail: Routes (Thread) puts it
-- a little way along the trail as you walk (Mark The Way Ahead),
-- and Sparkle (Thread) hangs its waypoint sparkle on it.
--
-- While it is lent, the game's map pin and the tracked quest are
-- the planner's. What was yours is kept here, and given back when
-- the planner lets go and at every logout or reload. A pin you set
-- or a quest you track while it is lent becomes yours, as ever:
-- it is kept to be given back, and the planner, which reads them
-- here, goes there. So every tool that reads your pin or your
-- tracked quest asks here, not the game:
--
--     PatchwerkForever.Marker:Pin()      your own map pin, as the game gives one ({ uiMapID =, position = }), or nil
--     PatchwerkForever.Marker:Quest()    the quest you track (0 or nil: none)
--     PatchwerkForever.Marker:Place(map, x, y, info)   the planner: the marker to that place (world
--                                        coordinates, as UnitPosition gives them); info is kept for
--                                        Info() ({ words =, map =, x =, y = } of where the trail leads).
--                                        True when the game took it
--     PatchwerkForever.Marker:Release()  the planner: give everything back
--     PatchwerkForever.Marker:Active()   whether it is lent;  :IsOurs() whether the game's pin now is the lent
--                                        one, and tracked
--     PatchwerkForever.Marker:Info()     the info given with the last Place
--     PatchwerkForever.Marker:Quiet()    true for a moment after the pin was changed here, while it is
--                                        still the one set here (the game's word of that is not news)
--     PatchwerkForever.Marker:OnChange(fn)   fn() when it is lent, moved, given back, or what is yours changes
--
-- Kept in PatchwerkForeverDB.characters[<GUID>].marker while lent, so that a pin left lent by a game
-- that closed without a logout is put back at the next login.

local Marker = {};
P.Marker = Marker;

local QUIET = 1;              -- seconds after a change made here that the game's word of it is ours
local SAME = 0.0005;          -- how far apart, in map coordinates, two pins may be and be one

local lent;                   -- nil, or { pin = { uiMapID, x, y } or false, tracked =, quest =, ours = { uiMapID, x, y }, info = }
local quietUntil = 0;
local lastSet;                -- the pin set here last ({ uiMapID, x, y }, or false: cleared), for Quiet
local listeners = {};

local function Ask(fn, ...)
	if ( type(fn) ~= 'function' ) then return nil end;
	local ok, a, b = pcall(fn, ...);
	if ok then return a, b end;
	return nil;
end

local function Changed()
	for _, fn in ipairs(listeners) do
		local ok, problem = pcall(fn);
		if not ok then geterrorhandler()(problem) end;
	end
end

function Marker:OnChange(fn)
	if ( type(fn) == 'function' ) then listeners[#listeners + 1] = fn end;
end

-- A pin as { uiMapID, x, y }, from what the game gives.
local function Point(pin)
	if ( type(pin) ~= 'table' or type(pin.uiMapID) ~= 'number' or type(pin.position) ~= 'table' ) then return nil end;
	local pos, x, y = pin.position;
	if ( type(pos.GetXY) == 'function' ) then x, y = pos:GetXY() else x, y = pos.x, pos.y end;
	if ( type(x) ~= 'number' or type(y) ~= 'number' ) then return nil end;
	return { pin.uiMapID, x, y };
end

local function AsPin(point)
	return { uiMapID = point[1], position = CreateVector2D(point[2], point[3]) };
end

local function Same(a, b)
	return a ~= nil and b ~= nil and a[1] == b[1] and math.abs(a[2] - b[2]) < SAME and math.abs(a[3] - b[3]) < SAME;
end

local function Track() return rawget(_G, 'C_SuperTrack') end

-- The game's pin now, as { uiMapID, x, y }, or nil.
local function Now()
	if not ( C_Map and C_Map.GetUserWaypoint ) then return nil end;
	if ( C_Map.HasUserWaypoint and not Ask(C_Map.HasUserWaypoint) ) then return nil end;
	return Point(Ask(C_Map.GetUserWaypoint));
end

local function GameQuest()
	local track = Track();
	local id = track and Ask(track.GetSuperTrackedQuestID);
	return type(id) == 'number' and id or 0;
end

local function PinTracked()
	local track = Track();
	return ( track and Ask(track.IsSuperTrackingUserWaypoint) ) == true;
end

local function Keep()
	local mine = P:Character();
	if not mine then return end;
	mine.marker = lent and { pin = lent.pin, tracked = lent.tracked, quest = lent.quest, ours = lent.ours } or nil;
end

-- A pin is about to be set here (false: cleared): the game's word of it, for a moment, is not news.
local function Hush(point)
	quietUntil = GetTime() + QUIET;
	if ( point ~= nil ) then lastSet = point end;
end

---------------------------------------------------------------
-- What you do while it is lent
---------------------------------------------------------------
-- A pin the game has that is not the lent one is one you set (yours, to go to); the lent one gone is
-- one you took away (so is yours). A quest the game tracks while the pin is not tracked is one you
-- chose. Looked at whenever the game says something changed and whenever a tool asks, since which
-- addon hears the game first is not known.
local function Adopt()
	if not lent then return end;
	local changed = false;
	local now = Now();
	if ( lent.ours and not Same(now, lent.ours) ) then
		lent.pin, lent.ours = now or false, nil;
		if now then lent.tracked = true end;
		changed = true;
	end
	-- (the pin not tracked: whatever the game tracks now, or nothing, you chose)
	local id = GameQuest();
	if ( id ~= lent.quest and not PinTracked() ) then
		lent.quest, lent.tracked = id, false;
		changed = true;
	end
	if changed then
		Keep()
		Changed()
	end
end

---------------------------------------------------------------
-- Reading what is yours
---------------------------------------------------------------
function Marker:Pin()
	Adopt()
	if lent then return lent.pin and AsPin(lent.pin) or nil end;
	if not ( C_Map and C_Map.GetUserWaypoint ) then return nil end;
	if ( C_Map.HasUserWaypoint and not Ask(C_Map.HasUserWaypoint) ) then return nil end;
	return Ask(C_Map.GetUserWaypoint);
end

function Marker:Quest()
	Adopt()
	if lent then return lent.quest end;
	return GameQuest();
end

function Marker:Active() return lent ~= nil end
-- (ours: the game's pin is the lent one, and it is the one tracked where the game can say)
function Marker:IsOurs()
	if not ( lent and lent.ours and Same(Now(), lent.ours) ) then return false end;
	local track = Track();
	return not ( track and track.IsSuperTrackingUserWaypoint ) or PinTracked();
end
function Marker:Info() return lent and lent.info or nil end
-- (only while the pin is the very one set here: a pin you set in that moment is news)
function Marker:Quiet()
	if ( GetTime() >= quietUntil or lastSet == nil ) then return false end;
	local now = Now();
	if ( lastSet == false ) then return now == nil end;
	return Same(now, lastSet);
end

---------------------------------------------------------------
-- Lending and giving back
---------------------------------------------------------------
function Marker:Place(map, x, y, info)
	if not ( C_Map and C_Map.SetUserWaypoint and C_Map.GetMapPosFromWorldPos and CreateVector2D ) then return false end;
	if ( type(map) ~= 'number' or type(x) ~= 'number' or type(y) ~= 'number' ) then return false end;
	local ok, uiMap, pos = pcall(C_Map.GetMapPosFromWorldPos, map, CreateVector2D(x, y));
	local where = ok and Point({ uiMapID = uiMap, position = pos });
	if not where then return false end;
	-- (a pin is set on the zone's own map where the game knows one there, as the world map sets it)
	local under = C_Map.GetMapInfoAtPosition and Ask(C_Map.GetMapInfoAtPosition, where[1], where[2], where[3]);
	local zone = type(under) == 'table' and under.mapID;
	if ( type(zone) == 'number' and zone ~= where[1] ) then
		local okz, onZone, zonePos = pcall(C_Map.GetMapPosFromWorldPos, map, CreateVector2D(x, y), zone);
		local there = okz and onZone == zone and Point({ uiMapID = zone, position = zonePos });
		if ( there and there[2] >= 0 and there[2] <= 1 and there[3] >= 0 and there[3] <= 1 ) then where = there end;
	end
	if ( C_Map.CanSetUserWaypointOnMap and Ask(C_Map.CanSetUserWaypointOnMap, where[1]) == false ) then return false end;
	if not lent then
		lent = { pin = Now() or false, tracked = PinTracked(), quest = GameQuest() };
	end
	Adopt()
	lent.info = info;
	if not ( Same(lent.ours, where) and Same(Now(), where) ) then
		-- (noted as ours before it is set: the game's word that it changed may come at once)
		local before = lent.ours;
		lent.ours = where;
		Hush(where);
		if not pcall(C_Map.SetUserWaypoint, AsPin(where)) then
			lent.ours = before;
			Keep();
			return false;
		end
	end
	local track = Track();
	if ( track and track.SetSuperTrackedUserWaypoint and not PinTracked() ) then
		Hush();
		pcall(track.SetSuperTrackedUserWaypoint, true)
	end
	Keep()
	Changed()
	return true;
end

-- Gives back what was kept: your pin (or none) and what you tracked.
local function GiveBack(was)
	Hush();
	local now = Now();
	-- (a pin that is not the lent one is yours already, and stays)
	if ( not now or Same(now, was.ours) ) then
		Hush(was.pin or false);
		if was.pin then
			pcall(C_Map.SetUserWaypoint, AsPin(was.pin))
		elseif C_Map and C_Map.ClearUserWaypoint then
			pcall(C_Map.ClearUserWaypoint)
		end
	end
	local track = Track();
	if not track then return end;
	if ( was.tracked and was.pin and track.SetSuperTrackedUserWaypoint ) then
		pcall(track.SetSuperTrackedUserWaypoint, true)
	elseif ( ( was.quest or 0 ) > 0 and track.SetSuperTrackedQuestID ) then
		pcall(track.SetSuperTrackedQuestID, was.quest)
	elseif track.SetSuperTrackedUserWaypoint then
		pcall(track.SetSuperTrackedUserWaypoint, false)
	end
end

function Marker:Release()
	if not lent then return end;
	local was = lent;
	lent = nil;
	GiveBack(was)
	Keep()
	Changed()
end

---------------------------------------------------------------
-- Events
---------------------------------------------------------------
local Watcher = CreateFrame('Frame');
for _, event in ipairs({ 'USER_WAYPOINT_UPDATED', 'SUPER_TRACKING_CHANGED', 'PLAYER_LOGIN', 'PLAYER_LOGOUT' }) do
	pcall(Watcher.RegisterEvent, Watcher, event);
end
Watcher:SetScript('OnEvent', function(_, event)
	if ( event == 'PLAYER_LOGOUT' ) then
		Marker:Release()
		return;
	end
	if ( event == 'PLAYER_LOGIN' ) then
		-- (lent when the game last closed without a logout: given back now)
		local mine = P:Character();
		local was = mine and type(mine.marker) == 'table' and mine.marker;
		if ( was and type(was.ours) == 'table' ) then
			GiveBack(was)
			mine.marker = nil;
		end
		return;
	end
	Adopt()
end)
