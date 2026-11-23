-- Sparkle (Thread): a sparkle on the way you are following (1.5.0).
--
-- The game draws its own waypoint marker in the world, on your map pin or the quest you track, and
-- C_Navigation.GetFrame() is a frame it keeps over that place on screen: the one place in the world
-- besides the thing in front of you whose spot on screen an addon is told. The Waypoint kind hangs its
-- sparkle there, a light beam to begin with.
--
-- With Patchwerk Forever: Routes (Thread) and its Mark The Way Ahead, that marker is lent to the route
-- (the base's Marker.lua): it stands on the trail a little way ahead of you and moves on as you walk.
-- The beam then follows the route, and under it are what the route leads to and how far that is
-- (Marker:Info()), and Brighter When Near goes by that distance. While Routes holds the marker for
-- nothing, or another addon has it, no beam is drawn. Without Routes the beam stands on the game's
-- marker as the game places it, with the quest's name and the game's distance.
--
-- The beam is drawn only where the game draws its own marker: not while the game says the place has no
-- valid spot on screen or the way to it is not valid (C_Navigation.HasValidScreenPosition and
-- GetTargetState, as the game's own marker asks), nor while the place is off screen and the frame is
-- held at the screen's edge (WasClampedToScreen), where the game's arrow shows the way.
local ADDON, ns = ...
if not ns.linked then return end

local FAR = 200               -- yards at which the waypoint's sparkle is faintest (Brighter When Near)
local EVERY = 0.5             -- seconds between two looks at its name and distance
local IDLE = 0.25             -- seconds between two looks for the game's marker while there is none

local Plain = ns.Plain
local mark, driver
local idle, wordsAt = 0, 0
-- the ways to a place the game says cannot be shown (Enum.NavigationState: Invalid, Disabled)
local NOT_SHOWN = { [0] = true, [3] = true }

-- What the game says of its marker, by asking it: true or false; nil where it cannot be asked.
local function Asked(nav, name)
	local fn = type(nav) == 'table' and nav[name]
	if type(fn) ~= 'function' then return nil end
	local ok, value = pcall(fn)
	if not (ok and Plain(value)) then return nil end
	return value
end

-- The lent marker (Routes' Mark The Way Ahead, through the base), while it is lent.
local function Lent()
	local marker = ns.Base and ns.Base.Marker
	if not (marker and type(marker.Active) == 'function' and marker:Active()) then return nil end
	return marker
end

-- Where the game's marker is on screen, in UIParent's units; nothing while the game itself would not
-- show it (nothing tracked, no valid spot on screen, no valid way), while it is off screen and held at
-- the edge, or while it is lent to the route and not standing on the way.
local function Navigation()
	local nav = rawget(_G, 'C_Navigation')
	if not (type(nav) == 'table' and type(nav.GetFrame) == 'function') then return nil end
	local ok, frame = pcall(nav.GetFrame)
	if not (ok and frame and frame.GetCenter) then return nil end
	local track = rawget(_G, 'C_SuperTrack')
	if Asked(track, 'IsSuperTrackingAnything') == false then return nil end
	if Asked(nav, 'HasValidScreenPosition') == false then return nil end
	local state = Asked(nav, 'GetTargetState')
	if state ~= nil and NOT_SHOWN[state] then return nil end
	if Asked(nav, 'WasClampedToScreen') == true then return nil end
	local lent = Lent()
	if lent and not lent:IsOurs() then return nil end
	local x, y = frame:GetCenter()
	if not (Plain(x) and Plain(y) and type(x) == 'number' and type(y) == 'number') then return nil end
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * scale, y * scale
end

-- How far away the waypoint is, in yards: while it marks the way ahead, how far it is to where the route
-- leads (as the crow flies); else as the game says. Nothing when neither is known.
local function Distance()
	local lent = Lent()
	local info = lent and lent:Info()
	if type(info) == 'table' and type(info.x) == 'number' and type(info.y) == 'number' then
		local px, py, map = ns.Here()
		if px and map == info.map then return ((px - info.x) ^ 2 + (py - info.y) ^ 2) ^ 0.5 end
	end
	local nav = rawget(_G, 'C_Navigation')
	if not (type(nav) == 'table' and type(nav.GetDistance) == 'function') then return nil end
	local ok, d = pcall(nav.GetDistance)
	if ok and Plain(d) and type(d) == 'number' and d >= 0 then return d end
	return nil
end
ns.WaypointDistance = Distance

-- What the waypoint is: what the route leads to, while it marks the way ahead; else the tracked quest's
-- name, "Map Pin", "Your Corpse" or "Waypoint".
local function Title()
	local lent = Lent()
	local info = lent and lent:Info()
	if type(info) == 'table' and type(info.words) == 'string' and info.words ~= '' then return info.words end
	local track = rawget(_G, 'C_SuperTrack')
	local function Ask(name, ...)
		local fn = type(track) == 'table' and track[name]
		if type(fn) ~= 'function' then return nil end
		local ok, a = pcall(fn, ...)
		return ok and Plain(a) and a or nil
	end
	if Ask('IsSuperTrackingUserWaypoint') == true then return 'Map Pin' end
	if Ask('IsSuperTrackingCorpse') == true then return 'Your Corpse' end
	local id = Ask('GetSuperTrackedQuestID')
	if type(id) == 'number' and id > 0 and C_QuestLog and C_QuestLog.GetTitleForQuestID then
		local ok, title = pcall(C_QuestLog.GetTitleForQuestID, id)
		if ok and Plain(title) and type(title) == 'string' and title ~= '' then return title end
	end
	return 'Waypoint'
end

-- Why the waypoint does not sparkle just now, or nil.
local function Why()
	local barred = ns.Barred()
	if barred then return barred end
	if not ns.Shown('waypoint') then return ('Show is off for Waypoint on %s'):format(ns.APPEARANCE) end
	return nil
end

local function Words(far)
	local title = Title()
	if far then return ('%s (%d yd)'):format(title, math.floor(far + 0.5)) end
	return title
end

-- One frame: the sparkle placed over the game's marker, or hidden.
local function Place(self, elapsed)
	local x, y
	if not Why() then x, y = Navigation() end
	if not x then
		if mark and mark:IsShown() then mark:Hide() end
		return
	end
	if not mark then
		mark = ns.NewMark()
		mark.kind, mark.anchor = 'waypoint', ns.waypointAnchor
		-- (Brighter When Near reads this, in place of the spots of an herb: Sparkle.lua's NewMark)
		mark.Distance = function(m)
			m.yards = Distance()
			return ns.Nearness(m.yards, FAR)
		end
	end
	local look = mark.look
	if not mark:IsShown() then
		ns.Arrive(mark)
		look = ns.Look('waypoint')
		ns.Dress(mark, look)
		mark:Show()
		wordsAt = 0
		if ns.Cue then ns.Cue('waypoint', Title(), look) end
	end
	mark.anchor:ClearAllPoints()
	mark.anchor:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', x, y)
	mark:ClearAllPoints()
	mark:SetPoint('CENTER', mark.anchor, 'CENTER', 0, look.height)
	wordsAt = wordsAt - (elapsed or 0)
	if wordsAt <= 0 then
		wordsAt = EVERY
		ns.WriteName(mark, mark.anchor, Words(Distance()), look)
	end
	mark.dim = 1
	if ns.Get('sparkleBehind') then ns.Tuck(mark) else mark:SetAlpha(1) end
end

local function Drive(self, elapsed)
	-- (while there is no marker, it is looked for a few times a second, not every frame)
	if not (mark and mark:IsShown()) then
		idle = idle - (elapsed or 0)
		if idle > 0 then return end
		idle = IDLE
	end
	Place(self, elapsed)
end

-- Its look changed: dressed anew (a setting, or Reset To Defaults).
local function Redress()
	if mark and mark:IsShown() then
		local look = ns.Look('waypoint')
		ns.Dress(mark, look)
		wordsAt = 0
	end
end

do
	driver = CreateFrame('Frame', nil, UIParent)
	driver:EnableMouse(false)
	driver:SetScript('OnUpdate', function(self, elapsed) ns.Try('the waypoint\'s sparkle', Drive, self, elapsed) end)
	-- (the mark needs a frame of its own to hang from: the game's marker moves every frame)
	local anchor = CreateFrame('Frame', nil, UIParent)
	anchor:SetSize(1, 1)
	anchor:EnableMouse(false)
	ns.waypointAnchor = anchor
end

ns.OnSetting(function(key)
	if key:find('^look%.waypoint%.') or key:find('^name') then Redress() end
end)

-- /sparkle status: a line for the waypoint, when the game shows one.
function ns.WaypointSay()
	local x = Navigation()
	local far = Distance()
	if not x and not far then return end
	local why = Why()
	if why then
		ns.Print(('Waypoint: %s: not sparkling: %s.'):format(Title(), why))
	elseif not x then
		ns.Print(('Waypoint: %s (%s): not shown: off screen, or the game has no place on screen for it.'):format(Title(),
			far and ('%d yd'):format(far) or 'distance not known'))
	else
		ns.Print(('Waypoint: %s: sparkling.'):format(Words(far)))
	end
end

-- (for the checks in lua_sparkle.py) the waypoint's mark, once made
function ns.WaypointMark() return mark end
