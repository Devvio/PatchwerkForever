-- Thread (Races): racing a course.
--
-- /race start: the start of the course becomes your map pin, tracked, so the game shows its marker in
-- the world and Marker.lua draws on it. Reaching the start counts down from 3 (or not, by the setting)
-- and the clock runs. The next checkpoint is then the pin; reaching one (within the course's size, in
-- yards) says your time there and how far ahead of or behind your best run you are, and moves the pin on.
-- The last is the finish: your time, and the best run kept if it is better. The pin you had before is
-- put back (or cleared, by the setting).
--
-- The checkpoints are taken in order; one missed is not skipped, it stays the next until you reach it.
-- With Thread (Routes) installed, its trail leads to each checkpoint as the pin moves on.
local ADDON, ns = ...
if not ns.linked then return end

local LOOK = 0.05             -- seconds between two looks at how near you are
local COUNT = 3               -- seconds of countdown
local AGAIN = 1               -- seconds before the pin is put back, when something else took it away

local function Plain(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function Sound(which)
	if not ns.Get('sounds') or not PlaySound then return end
	local kit = SOUNDKIT or {}
	local id = ({ tick = kit.UI_BATTLEGROUND_COUNTDOWN_TIMER or kit.RAID_WARNING,
		go = kit.UI_BATTLEGROUND_COUNTDOWN_FINISHED or kit.READY_CHECK,
		checkpoint = kit.IG_QUEST_LIST_COMPLETE or kit.UI_QUEST_ROLLING_FORWARD_01,
		finish = kit.UI_EPICLOOT_TOAST or kit.LEVELUPSOUND or kit.READY_CHECK })[which]
	if id then pcall(PlaySound, id, 'Master') end
end

local function Chat(text)
	if ns.Get('chat') then ns.Print(text) end
end

---------------------------------------------------------------------------
-- The pin
---------------------------------------------------------------------------
local before                  -- the pin you had before the race: { m, x, y }, or false for none
local ours                    -- the pin this race put down: { m, x, y }

local function Pin(point)
	if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return false end
	local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(point.m, point.x, point.y))
	if not ok then return false end
	ours = { point.m, point.x, point.y }
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
	end
	return true
end

local function Remember()
	if before ~= nil then return end
	before = false
	if C_Map.HasUserWaypoint and C_Map.HasUserWaypoint() then
		local pin = C_Map.GetUserWaypoint()
		if pin and pin.uiMapID and pin.position then
			local x, y = pin.position:GetXY()
			before = { pin.uiMapID, x, y }
		end
	end
end

local function GiveBack()
	if before == nil then return end
	if before and ns.Get('restorePin') then
		pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(before[1], before[2], before[3]))
	elseif C_Map.ClearUserWaypoint then
		pcall(C_Map.ClearUserWaypoint)
	end
	before, ours = nil, nil
end

-- Is our pin still the pin? (Something else may have moved it, or you cleared it.)
local function Ours()
	if not (ours and C_Map.HasUserWaypoint and C_Map.HasUserWaypoint()) then return false end
	local pin = C_Map.GetUserWaypoint()
	if not (pin and pin.position) then return false end
	local x, y = pin.position:GetXY()
	return pin.uiMapID == ours[1] and math.abs(x - ours[2]) < 1e-4 and math.abs(y - ours[3]) < 1e-4
end

---------------------------------------------------------------------------
-- The race
---------------------------------------------------------------------------
-- ns.racing = { name =, course =, next = index of the checkpoint to reach, phase = 'start', 'count' or
-- 'run', go = when the clock started, splits = {} }.
-- ns.aim = { point =, kind = 'start', 'checkpoint' or 'finish', words = }: what the marker is on.
local looker

local function Aim(i)
	local race = ns.racing
	local points = race.course.points
	local kind = i == 1 and 'start' or i == #points and 'finish' or 'checkpoint'
	local words = kind == 'start' and 'Start' or kind == 'finish' and 'Finish'
		or ('Checkpoint %d/%d'):format(i - 1, #points - 2)
	race.next = i
	ns.aim = { point = points[i], kind = kind, words = words, index = i }
	if not Pin(points[i]) then
		ns.Print('The map pin could not be placed, so the marker cannot be shown. Times are still kept.')
	end
	race.pinned = GetTime()
	ns.MarkerShow()
end

local function Stop(quiet)
	ns.racing, ns.aim = nil, nil
	if looker then looker:Hide() end
	GiveBack()
	ns.MarkerShow()
	if not quiet then ns.Print('Race stopped.') end
end

local function Finish(race, now)
	local time = now - race.go
	local course, best = race.course, race.course.best
	local better = not best or time < best.time
	local gap = best and ns.Gap(time - best.time) or nil
	if better then
		course.best = { time = time, splits = race.splits, date = date and date('%Y-%m-%d') or '' }
	end
	Sound('finish')
	local small = better and (best and ('New best! ' .. gap) or 'Your first time on this course')
		or ('Best ' .. ns.Clock(best.time) .. '  ' .. gap)
	ns.Say('Finish  ' .. ns.Clock(time), small, ns.Get('finishColour'), 5)
	Chat(('"%s" finished in %s. %s.'):format(race.name, ns.Clock(time), small))
	Stop(true)
end

local function Reached(race, now)
	local i = race.next
	local points = race.course.points
	if race.phase == 'start' then
		if ns.Get('countdown') then
			race.phase, race.go, race.said = 'count', now + COUNT, nil
		else
			race.phase, race.go = 'run', now
			Sound('go')
			ns.Say('Go!', race.name, ns.Get('startColour'), 1.5)
			Aim(2)
		end
		return
	end
	local split = now - race.go
	race.splits[i] = split
	if i == #points then return Finish(race, now) end
	Sound('checkpoint')
	if ns.Get('splits') then
		local best = race.course.best and race.course.best.splits[i]
		local gap = best and ns.Gap(split - best) or nil
		ns.Say(ns.Clock(split), ('Checkpoint %d/%d%s'):format(i - 1, #points - 2, gap and ('   ' .. gap) or ''),
			best and (split <= best and 'ff66ff80' or 'ffff6666') or ns.Get('markerColour'), 2)
		Chat(('Checkpoint %d/%d: %s%s'):format(i - 1, #points - 2, ns.Clock(split), gap and (' (' .. gap .. ')') or ''))
	end
	Aim(i + 1)
end

local function Look()
	local race = ns.racing
	if not race then return end
	local now = GetTime()
	if race.phase == 'count' then
		local left = math.ceil(race.go - now)
		if left <= 0 then
			race.phase = 'run'
			Sound('go')
			ns.Say('Go!', race.name, ns.Get('startColour'), 1.5)
			Aim(2)
		elseif left ~= race.said then
			race.said = left
			Sound('tick')
			ns.Say(tostring(left), race.name, ns.Get('startColour'), 1)
		end
		return
	end
	-- the pin taken away or moved by something else: put back after a moment
	if not Ours() and now - (race.pinned or 0) > AGAIN then
		Pin(ns.aim.point)
		race.pinned = now
	end
	local far = ns.Distance(ns.aim.point)
	if not far and C_Navigation and C_Navigation.GetDistance and Ours() then
		local d = C_Navigation.GetDistance()
		if Plain(d) and type(d) == 'number' and d > 0 then far = d end
	end
	if far and far <= (race.course.radius or ns.Get('radius') or 12) then
		Reached(race, now)
	end
end

local function Looker()
	if looker then return looker end
	looker = CreateFrame('Frame')
	looker.wait = 0
	looker:SetScript('OnUpdate', function(self, elapsed)
		self.wait = self.wait - elapsed
		if self.wait > 0 then return end
		self.wait = LOOK
		ns.Try('the race', Look)
	end)
	looker:Hide()
	return looker
end

function ns.RaceStart(name)
	local course, named = ns.Course(name)
	if not course then
		if named then
			ns.Print(('No course named "%s". /race list shows them.'):format(named))
		else
			ns.Print('No course yet. /race new <name> starts one where you stand.')
		end
		return
	end
	if #course.points < 2 then
		ns.Print(('"%s" has no checkpoints to race.'):format(named))
		return
	end
	local making = ns.Making and ns.Making()
	if making then
		ns.Print(('Course "%s" is still being made: /race save or /race cancel it first.'):format(making.name))
		return
	end
	if ns.racing then Stop(true) end
	Remember()
	ns.DB().last = named
	ns.racing = { name = named, course = course, phase = 'start', splits = {} }
	Aim(1)
	Looker():Show()
	local far = ns.Distance(course.points[1])
	ns.Print(('Racing "%s": %s%s. Go to the start%s; the clock starts there. /race stop to stop.')
		:format(named, ns.Checkpoints(#course.points - 1), course.best and (', best ' .. ns.Clock(course.best.time)) or '',
			far and (' (%d yards away)'):format(far) or ''))
end

function ns.RaceStop()
	if not ns.racing then
		ns.Print('No race is on.')
		return
	end
	Stop(false)
end

-- /race while racing: where you are in it.
function ns.RaceSay()
	local race = ns.racing
	local points = race.course.points
	if race.phase == 'start' then
		local far = ns.Distance(points[1])
		ns.Print(('"%s": go to the start%s.'):format(race.name, far and (' (%d yards)'):format(far) or ''))
	else
		local far = ns.Distance(points[race.next])
		ns.Print(('"%s": %s, next %s%s.'):format(race.name, ns.Clock(math.max(0, GetTime() - race.go)),
			ns.aim.words, far and (' (%d yards)'):format(far) or ''))
	end
end

ns.OnSetting(function(key)
	if key == 'marker' or key == 'hideGameMarker' then ns.MarkerShow() end
end)
-- (a loading screen, a new continent: the race goes on; the pin is put back if the game dropped it)
ns.On('PLAYER_LOGOUT', function() if ns.racing then Stop(true) end end)
