-- Races (Thread): racing a course.
--
-- /race start: the start of the course becomes your map pin, tracked, so the game shows its marker in
-- the world and Marker.lua draws on it. Reaching the start counts down from 3 (or not, by the setting)
-- and the clock runs. The next checkpoint is then the pin; reaching one (within the course's size, in
-- yards) says your time there and how far ahead of or behind your best run you are, and moves the pin on.
-- The last is the finish: your time, and the best run kept if it is better. The pin you had before is
-- put back (or cleared, by the setting).
--
-- The checkpoints are taken in order; one missed is not skipped, it stays the next until you reach it.
-- With Routes (Thread) installed, its trail leads to each checkpoint as the pin moves on.
--
-- The rule. A race is run under its course's rule (Courses.lua). Under On Foot, a run during which you
-- are mounted or on a flight path at any moment while the clock runs does not count: it is said once,
-- when it happens, the race goes on to the finish, and no best run is kept from it. Only what the game
-- tells plainly is judged (IsMounted, UnitOnTaxi); shapeshift forms and speed buffs are allowed. The best
-- run is kept, and the splits compared, under the rule the race is run under.
--
-- A race together (Together.lua) is this same race with three differences: it waits at the start until
-- the start is given for everyone (ns.RaceGo), it is run under the rule of the one who invited, and each
-- checkpoint, the finish and a stop are told to the group.
local ADDON, ns = ...
if not ns.linked then return end

local LOOK = 0.05             -- seconds between two looks at how near you are
local COUNT = 3               -- seconds of countdown
local AGAIN = 1               -- seconds before the pin is put back, when something else took it away
local AHEAD, BEHIND = 'ff66ff80', 'ffff6666'      -- the colors of a time ahead of and behind another

ns.COUNT, ns.AHEAD, ns.BEHIND = COUNT, AHEAD, BEHIND

local function Plain(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

-- Asks the game a yes-or-no question. A function this client lacks, an error, or an answer kept
-- secret is no answer, and no answer is not a yes.
local function Told(name, ...)
	local ask = rawget(_G, name)
	if type(ask) ~= 'function' then return false end
	local ok, answer = pcall(ask, ...)
	return ok and Plain(answer) and answer == true
end

-- What breaks On Foot just now, in words, or nothing.
local function Riding()
	if Told('IsMounted') then return 'you mounted' end
	if Told('UnitOnTaxi', 'player') then return 'you took a flight path' end
	return nil
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
-- 'run', go = when the clock started, splits = {}, rule = 'any' or 'foot', void = why the run does not
-- count (under On Foot), together = the race with the group it is part of (Together.lua), done = true
-- once it is finished }.
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
	local race = ns.racing
	ns.racing, ns.aim = nil, nil
	if looker then looker:Hide() end
	GiveBack()
	ns.MarkerShow()
	if not quiet then ns.Print('Race stopped.') end
	-- (a race together you did not finish: the group is told you are out of it)
	if race and race.together and not race.done then ns.Try('the race together', ns.TogetherLeft, race) end
end

local function Finish(race, now)
	local time = now - race.go
	local course, key = race.course, ns.BestKey(race.rule)
	local best = course[key]
	local small
	if race.void then
		small = 'Does not count: On Foot, and ' .. race.void
	else
		local better = not best or time < best.time
		local gap = best and ns.Gap(time - best.time) or nil
		local first = (course.best or course.footBest) and ('Your first time under ' .. ns.RULES[race.rule])
			or 'Your first time on this course'
		if better then
			course[key] = { time = time, splits = race.splits, date = date and date('%Y-%m-%d') or '' }
		end
		small = better and (best and ('New best! ' .. gap) or first) or ('Best ' .. ns.Clock(best.time) .. '  ' .. gap)
	end
	Sound('finish')
	Chat(('"%s" finished in %s. %s.'):format(race.name, ns.Clock(time), small))
	race.done = true
	-- (a race together: the group is told, and the placings so far go under your own time)
	local placings = race.together and ns.Try('the race together', ns.TogetherFinish, race, time) or nil
	ns.Say('Finish  ' .. ns.Clock(time), placings and (small .. '\n' .. placings) or small, ns.Get('finishColour'), 5)
	Stop(true)
end

-- The clock starts: the first checkpoint lights up.
local function Off(race)
	race.phase = 'run'
	Sound('go')
	ns.Say('Go!', race.name, ns.Get('startColour'), 1.5)
	Aim(2)
end

local function Reached(race, now)
	local i = race.next
	local points = race.course.points
	if race.phase == 'start' then
		if ns.Get('countdown') then
			race.phase, race.go, race.said = 'count', now + COUNT, nil
		else
			race.go = now
			Off(race)
		end
		return
	end
	local split = now - race.go
	race.splits[i] = split
	if i == #points then return Finish(race, now) end
	Sound('checkpoint')
	-- (a race together: the group is told your time here; the racer ahead of you, when there is one)
	local rival = race.together and ns.Try('the race together', ns.TogetherSplit, race, i, split) or nil
	if ns.Get('splits') then
		local run = ns.Best(race.course, race.rule)
		local best = run and run.splits[i]
		local gap = best and ns.Gap(split - best) or nil
		ns.Say(ns.Clock(split), ('Checkpoint %d/%d%s%s'):format(i - 1, #points - 2, gap and ('   ' .. gap) or '',
				rival and ('   ' .. rival) or ''),
			best and (split <= best and AHEAD or BEHIND) or ns.Get('markerColour'), 2)
		Chat(('Checkpoint %d/%d: %s%s%s'):format(i - 1, #points - 2, ns.Clock(split), gap and (' (' .. gap .. ')') or '',
			rival and (', ' .. rival) or ''))
	end
	Aim(i + 1)
end

-- How far the checkpoint the marker is on is, in yards; nothing when it cannot be told.
local function Far()
	local far = ns.Distance(ns.aim.point)
	if not far and C_Navigation and C_Navigation.GetDistance and Ours() then
		local d = C_Navigation.GetDistance()
		if Plain(d) and type(d) == 'number' and d > 0 then far = d end
	end
	return far
end

-- Are you at the checkpoint the marker is on?
local function There(race)
	local far = Far()
	return far ~= nil and far <= (race.course.radius or ns.Get('radius') or 12)
end

local function Look()
	local race = ns.racing
	if not race then return end
	local now = GetTime()
	if race.phase == 'count' then
		local left = math.ceil(race.go - now)
		if left <= 0 then
			Off(race)
		elseif left ~= race.said then
			race.said = left
			Sound('tick')
			ns.Say(tostring(left), race.name, ns.Get('startColour'), 1)
		end
		return
	end
	-- On Foot, while the clock runs: said once, and the race goes on
	if race.phase == 'run' and race.rule == 'foot' and not race.void then
		local why = Riding()
		if why then
			race.void = why
			ns.Say('Does Not Count', 'On Foot, and ' .. why, BEHIND, 3)
			ns.Print(('This run on "%s" will not count: the course is On Foot and %s. The race goes on to the finish.')
				:format(race.name, why))
		end
	end
	-- the pin taken away or moved by something else: put back after a moment
	if not Ours() and now - (race.pinned or 0) > AGAIN then
		Pin(ns.aim.point)
		race.pinned = now
	end
	if There(race) then
		if race.together and race.phase == 'start' then
			-- (a race together starts for everyone at once: here you wait for the start to be given)
			if not race.waiting then
				race.waiting = true
				ns.Try('the race together', ns.TogetherAtStart, race)
			end
		else
			Reached(race, now)
		end
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

-- The course of a name (the last one, without a name), or nothing and a line in chat saying why not.
function ns.RaceCourse(name)
	local course, named = ns.Course(name)
	if not course then
		if named then
			ns.Print(('No course named "%s". /race list shows them.'):format(named))
		else
			ns.Print('No course yet. /race new <name> starts one where you stand.')
		end
		return nil
	end
	return course, named
end

-- Starts a race on a course: its start becomes the pin. `together` is the race with the group this one
-- is part of (Together.lua), whose rule it is then run under. False, and a line in chat, when it cannot.
function ns.RaceBegin(course, named, together)
	if #course.points < 2 then
		ns.Print(('"%s" has no checkpoints to race.'):format(named))
		return false
	end
	local making = ns.Making and ns.Making()
	if making then
		ns.Print(('Course "%s" is still being made: /race save or /race cancel it first.'):format(making.name))
		return false
	end
	if ns.racing then Stop(true) end
	Remember()
	ns.DB().last = named
	ns.racing = { name = named, course = course, phase = 'start', splits = {}, together = together,
		rule = together and together.rule or ns.Rule(course) }
	Aim(1)
	Looker():Show()
	if ns.racing.rule == 'foot' and not (rawget(_G, 'IsMounted') or rawget(_G, 'UnitOnTaxi')) then
		ns.Print('This game client does not say whether you are mounted, so On Foot cannot be judged: the run counts.')
	end
	return true
end

function ns.RaceStart(name)
	local course, named = ns.RaceCourse(name)
	if not (course and ns.RaceBegin(course, named)) then return end
	local far = ns.Distance(course.points[1])
	local best = ns.Best(course)
	ns.Print(('Racing "%s"%s: %s%s. Go to the start%s; the clock starts there. /race stop to stop.')
		:format(named, ns.Rule(course) == 'foot' and ' (On Foot)' or '', ns.Checkpoints(#course.points - 1),
			best and (', best ' .. ns.Clock(best.time)) or '', far and (' (%d yards away)'):format(far) or ''))
end

-- A race together: are you at the start? And the start given for everyone: the countdown runs from now
-- (none, with 0 seconds), whatever your own Countdown At The Start says, so that it is the same for all.
function ns.RaceAtStart()
	local race = ns.racing
	return race ~= nil and race.phase == 'start' and There(race)
end

function ns.RaceGo(seconds)
	local race = ns.racing
	if not (race and race.phase == 'start') then return end
	local now = GetTime()
	if seconds > 0 then
		race.phase, race.go, race.said = 'count', now + seconds, nil
	else
		race.go = now
		Off(race)
	end
end

function ns.RaceStop()
	if not ns.racing then
		ns.Print('No race is on.')
		return
	end
	Stop(false)
end

-- Ends the race that is on, if any, without a word (Together.lua says why itself).
function ns.RaceEnd()
	if ns.racing then Stop(true) end
end

-- /race while racing: where you are in it.
function ns.RaceSay()
	local race = ns.racing
	local points = race.course.points
	if race.phase == 'start' then
		local far = ns.Distance(points[1])
		ns.Print(('"%s": go to the start%s%s.'):format(race.name, far and (' (%d yards)'):format(far) or '',
			race.together and '; the race starts for everyone when the start is given' or ''))
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
