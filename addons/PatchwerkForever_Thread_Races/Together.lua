-- Races (Thread): racing a course together, with your party or raid.
--
-- One player invites the group to a course (/race together). Every member who has Races and that course
-- is told, and joins or not (/race join). Everyone who joined goes to the start, as in a race alone, and
-- waits there. The one who invited gives the start (/race go): one message, and each racer's countdown
-- runs from when it arrives. At each checkpoint a racer's time goes to the group, so each sees the gap to
-- the racer ahead or the lead over the one behind; at the finish, the placings.
--
-- Each racer's clock is their own: it starts when the start reaches them and stops at their finish, so
-- the times compared are fair whatever the delay between players. For the same reason who is "ahead" is
-- reckoned from the times, not from whose message came first.
--
-- The messages, on the addon channel a course is shared on (Courses.lua), to the party or raid:
--     I:id:fingerprint:rule:name    an invitation: the course's fingerprint, the rule the race is run under
--     J:id                          the sender joined
--     G:id:seconds                  the start, with the seconds of countdown (only from the one who invited)
--     C:id:checkpoint:time          the sender reached a checkpoint, at that time in seconds
--     F:id:time:0 or 1              the sender finished; 1: the run does not count under the rule
--     Q:id                          the sender stopped after the start: not finished
--     O:id                          the sender is out before the race began for them: not in it (from the
--                                   one who invited, before the start: the race is called off)
-- All begin with a letter, which Races 0.1.x passes over. Nothing is sent unless you invited or joined.
--
-- What arrives is not trusted. A message is used only when it has exactly the shape above, a number in
-- range where a number belongs, the id of the race you know of, and comes from your party or raid (not by
-- whisper); the start only counts from the one who invited. A name in it is stripped of what could draw
-- or link in chat. Nothing in a message is run, and nothing in it changes what you have saved: it is only
-- shown. The course raced is always your own copy, found by its fingerprint; your best run is your own.
local ADDON, ns = ...
if not ns.linked then return end

local ME = ''                 -- your own place among the racers (no sender has that name)
local MOST = 40               -- racers kept in one race: a raid's size
local NAME = 100              -- characters of a course's name in an invitation
local LONGEST = 86400         -- seconds; a time beyond a day is not a time
local SHOWN = 5               -- placings on screen at once
local QUIET = 5               -- seconds in which another invitation from the same player is passed over

-- The race together you know of (one at a time):
-- { id = '123456', host = the sender who invited (ME: you), title = the course's name as they have it,
--   sum = its fingerprint, rule = 'any' or 'foot', state = 'gather' (before the start) or 'run',
--   course =, named = your own course with that fingerprint (none: you lack it), joined = you are in it,
--   racers = { [sender or ME] = { name =, splits = { [checkpoint] = seconds }, time = the finish,
--   void = does not count, out = not finished } }, count = how many racers }
local party
local last = {}               -- who = the last sender of an invitation, when = and when

local function Plain(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function Short(sender)
	return sender:match('^([^%-]+)') or sender
end

local function Myself()
	local name = UnitName('player')
	return Plain(name) and type(name) == 'string' and name or 'You'
end

-- A name someone else sent, made fit to show: nothing that draws, links or breaks a line in chat.
local function Safe(text)
	return ns.Clean((text:gsub('%c', '')))
end

-- Sends a line to the group. False when it could not be sent, as far as the game tells.
local function Send(text)
	local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
	local channel = ns.Group()
	if not (send and channel) then return false end
	local ok, result = pcall(send, ns.PREFIX, text, channel)
	if not ok then return false end
	-- (this client answers with a number, 0 for sent; older ones with true, or nothing)
	if Plain(result) and (result == false or (type(result) == 'number' and result ~= 0)) then return false end
	return true
end

local function Racer(who, name)
	local racer = party.racers[who]
	if racer then return racer end
	if party.count >= MOST and who ~= ME then return nil end
	racer = { name = name or Short(who), splits = {} }
	party.racers[who] = racer
	party.count = party.count + 1
	return racer
end

local function Remove(who)
	if party.racers[who] then
		party.racers[who] = nil
		party.count = party.count - 1
	end
end

local function Host()
	return party.host == ME and Myself() or Short(party.host)
end

-- Your own course with a fingerprint (the one named as the invitation names it, when that fits).
local function Mine(sum, title)
	local courses = ns.DB().courses
	local function Same(course)
		return type(course) == 'table' and type(course.points) == 'table' and #course.points >= 2
			and ns.Fingerprint(course) == sum
	end
	if Same(courses[title]) then return courses[title], title end
	for name, course in pairs(courses) do
		if Same(course) then return course, name end
	end
	return nil
end

-- Are you racing in the race together you know of?
local function Racing()
	return party ~= nil and ns.racing ~= nil and ns.racing.together == party
end

---------------------------------------------------------------------------
-- The placings
---------------------------------------------------------------------------
-- Those who finished, fastest first; those who did not finish; and how many are still racing.
local function Ordered()
	local done, out, running = {}, {}, 0
	for _, racer in pairs(party.racers) do
		if racer.time then
			done[#done + 1] = racer
		elseif racer.out then
			out[#out + 1] = racer.name
		else
			running = running + 1
		end
	end
	table.sort(done, function(a, b)
		if a.time ~= b.time then return a.time < b.time end
		return a.name < b.name
	end)
	table.sort(out)
	return done, out, running
end

local function Placing(place, racer)
	return ('%d. %s  %s%s'):format(place, racer.name, ns.Clock(racer.time), racer.void and ' (does not count)' or '')
end

-- The placings so far, for the screen: the first few, a line each, and who did not finish.
local function Screen()
	local done, out = Ordered()
	local lines = {}
	for place = 1, math.min(#done, SHOWN) do lines[place] = Placing(place, done[place]) end
	if #out > 0 then lines[#lines + 1] = 'Not finished: ' .. table.concat(out, ', ') end
	return table.concat(lines, '\n')
end

-- After anything that changes who is still racing. Writes the placings in chat (`now`: a racer just
-- finished; and in any case once everyone has finished or is out), and lets the race go when it is over.
local function Placings(now)
	local done, out, running = Ordered()
	local over = party.state == 'run' and running == 0
	-- (alone in it, your own finish said it all; Split Times In Chat governs this as it does the result)
	if (now or over) and party.joined and party.count > 1 and ns.Get('chat') then
		local parts = {}
		for place, racer in ipairs(done) do parts[place] = Placing(place, racer) end
		local text = #parts > 0 and table.concat(parts, '; ') or 'nobody finished'
		if over and #out > 0 then text = text .. '. Not finished: ' .. table.concat(out, ', ') end
		ns.Print(('%s on "%s": %s.'):format(over and 'Final placings' or 'Placings', party.named or party.title, text))
	end
	if over then party = nil end
end

-- "Mira +2.4 s": behind that racer by so much (in the color of behind), or "Mira -2.4 s": ahead.
local function Versus(name, gap)
	return ('%s %s s'):format(name, ns.Gap(gap)), gap >= 0 and ns.BEHIND or ns.AHEAD
end

---------------------------------------------------------------------------
-- What Race.lua tells as your own race goes
---------------------------------------------------------------------------
-- You reached the start of a race together: here you wait.
function ns.TogetherAtStart(race)
	if not (party and race.together == party) then return end
	if party.host == ME then
		ns.Say('At The Start', '/race go starts the race', ns.Get('startColour'), 3)
		ns.Print('You are at the start. When everyone is there, /race go (or the Race Together key binding) starts the race for all.')
	else
		ns.Say('At The Start', ('Waiting for %s to start the race'):format(Host()), ns.Get('startColour'), 3)
		ns.Print(('You are at the start. %s starts the race.'):format(Host()))
	end
end

-- You reached a checkpoint: the group is told. Returns the racer nearest ahead of you there and by how
-- much, or the one nearest behind when nobody is ahead, in color; nothing when you are the first there
-- (the lead is then shown when the next racer's time arrives).
function ns.TogetherSplit(race, i, split)
	if not (party and race.together == party) then return nil end
	Racer(ME, Myself()).splits[i] = split
	Send(('C:%s:%d:%.2f'):format(party.id, i, split))
	local ahead, behind
	for who, racer in pairs(party.racers) do
		local t = who ~= ME and racer.splits[i]
		if t and t <= split then
			if not ahead or t > ahead.splits[i] then ahead = racer end
		elseif t then
			if not behind or t < behind.splits[i] then behind = racer end
		end
	end
	local rival = ahead or behind
	race.leading = not rival and i or nil
	if not rival then return nil end
	local words, colour = Versus(rival.name, split - rival.splits[i])
	return ('|c%s%s|r'):format(colour, words)
end

-- You finished: the group is told. Returns the placings so far for the screen (nothing, alone in it).
function ns.TogetherFinish(race, time)
	if not (party and race.together == party) then return nil end
	local me = Racer(ME, Myself())
	me.time, me.void = time, race.void ~= nil
	Send(('F:%s:%.2f:%d'):format(party.id, time, race.void and 1 or 0))
	local screen = party.count > 1 and Screen() or nil
	Placings(true)
	return screen
end

-- Your race ended without a finish (you stopped it, or started another): the group is told.
function ns.TogetherLeft(race)
	if not (party and race.together == party) then return end
	if party.state == 'gather' then
		Send('O:' .. party.id)
		if party.host == ME then
			ns.Print('The race together is called off.')
			party = nil
		else
			-- (the invitation stands: /race join again, until the start is given)
			Remove(ME)
			party.joined = false
		end
	else
		Send('Q:' .. party.id)
		Racer(ME, Myself()).out = true
		Placings(false)
	end
end

---------------------------------------------------------------------------
-- Inviting, joining, and giving the start
---------------------------------------------------------------------------
-- Is a race together you are in waiting for its start? (/race go then gives it, or says who does.)
function ns.TogetherBusy()
	return Racing() and party.state == 'gather'
end

-- /race together [name]: invites the group to a course. Again, while it waits for its start: gives the start.
function ns.RaceTogether(name)
	if ns.TogetherBusy() and party.host == ME then
		local course = name ~= '' and ns.Course(name) or party.course
		if course == party.course then return ns.TogetherGo() end
	end
	local course, named = ns.RaceCourse(name)
	if not course then return end
	if not ns.Group() then
		ns.Print('You are not in a group. /race start races a course alone.')
		return
	end
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
		ns.Print('This game client cannot send addon messages.')
		return
	end
	local new = { id = tostring(math.random(100000, 999999)), host = ME, title = named, named = named, course = course,
		sum = ns.Fingerprint(course), rule = ns.Rule(course), state = 'gather', joined = true, racers = {}, count = 0 }
	-- (a race you are in ends here, as it does when you start any other; its group is told by that)
	if not ns.RaceBegin(course, named, new) then return end
	party = new
	Racer(ME, Myself())
	if not Send(('I:%s:%s:%s:%s'):format(new.id, new.sum, new.rule, named:sub(1, NAME))) then
		party = nil
		ns.RaceEnd()
		ns.Print('The invitation could not be sent just now. Try again in a moment.')
		return
	end
	local far = ns.Distance(course.points[1])
	ns.Print(('Your group is invited to race "%s" (%s, %s). Go to the start%s. When everyone is there, /race go (or /race together again) starts the race for all.')
		:format(named, ns.RULES[new.rule], ns.Checkpoints(#course.points - 1), far and (' (%d yards away)'):format(far) or ''))
end

-- /race go in a race together: the start, for everyone, from the one who invited.
function ns.TogetherGo()
	if not ns.TogetherBusy() then
		ns.Print('No race together is waiting for its start. /race together invites your group to one.')
		return
	end
	if party.host ~= ME then
		ns.Print(('Only %s can start this race.'):format(Host()))
		return
	end
	if not ns.RaceAtStart() then
		ns.Print('Go to the start first. The race starts for everyone when you give the start there.')
		return
	end
	-- (your Countdown At The Start decides for everyone, so that the countdown is the same for all)
	local seconds = ns.Get('countdown') and ns.COUNT or 0
	if not Send(('G:%s:%d'):format(party.id, seconds)) then
		ns.Print('The start could not be sent just now. Try again in a moment.')
		return
	end
	party.state = 'run'
	if party.count < 2 then ns.Print('Nobody joined: you race alone.') end
	ns.RaceGo(seconds)
end

-- /race join: joins the race you were invited to.
function ns.TogetherJoin()
	if not party or party.host == ME then
		ns.Print(ns.TogetherBusy() and 'This race is your own: /race go starts it.' or 'Nobody has invited you to a race.')
		return
	end
	if party.state ~= 'gather' then
		ns.Print('That race has already started.')
		return
	end
	if Racing() then
		ns.Print(('You are already in this race. %s starts it.'):format(Host()))
		return
	end
	-- (the course may have been sent to you, or deleted, since the invitation)
	if party.course and ns.DB().courses[party.named] ~= party.course then party.course = nil end
	if not party.course then party.course, party.named = Mine(party.sum, party.title) end
	if not party.course then
		ns.Print(('You do not have the course "%s". Ask %s for it: they send it with /race share, and /race accept keeps it.')
			:format(party.title, Host()))
		return
	end
	local joining = party
	if not ns.RaceBegin(joining.course, joining.named, joining) then return end
	party = joining
	party.joined = true
	Racer(ME, Myself())
	Send('J:' .. party.id)
	local far = ns.Distance(party.course.points[1])
	ns.Print(('You joined %s\'s race on "%s" (%s). Go to the start%s; %s starts the race. /race stop to leave it.')
		:format(Host(), party.named, ns.RULES[party.rule], far and (' (%d yards away)'):format(far) or '', Host()))
end

---------------------------------------------------------------------------
-- What the group sends
---------------------------------------------------------------------------
local function Invited(rest, sender)
	local id, sum, rule, title = rest:match('^(%d%d?%d?%d?%d?%d?):(%d%d?%d?%d?%d?%d?%d?%d?%d?%d?):(%a+):(.*)$')
	if not (id and ns.RULES[rule]) then return end
	title = Safe(title)
	if title == '' or #title > NAME then return end
	-- (busy with a race together of your own, or in one: a race is not left by being invited to another)
	if party and (Racing() or (party.host == ME and party.state == 'gather')) then return end
	local now = GetTime()
	if last.who == sender and now - (last.when or 0) < QUIET then return end
	last.who, last.when = sender, now
	local course, named = Mine(sum, title)
	party = { id = id, host = sender, title = title, sum = sum, rule = rule, state = 'gather', course = course, named = named,
		joined = false, racers = {}, count = 0 }
	Racer(sender)
	if not course then
		ns.Print(('%s invites your group to race "%s", a course you do not have. Ask for it: they send it with /race share, /race accept keeps it, and /race join joins the race.')
			:format(Host(), title))
		return
	end
	if ns.Get('autoJoin') and not ns.racing and not (ns.Making and ns.Making()) then
		return ns.TogetherJoin()
	end
	ns.Print(('%s invites your group to race "%s" (%s, %s). /race join joins it (or the Join Race key binding).')
		:format(Host(), named, ns.RULES[rule], ns.Checkpoints(#course.points - 1)))
end

local function Joined(sender)
	if party.racers[sender] then return end
	local racer = Racer(sender)
	if racer and party.joined and party.state == 'gather' then
		ns.Print(('%s joined the race (%d racers).'):format(racer.name, party.count))
	end
end

-- The race is called off by the one who invited (or they left the group before the start).
local function CalledOff()
	local was = party
	party, last.who = nil, nil
	if was.joined and ns.racing and ns.racing.together == was then
		ns.RaceEnd()
		ns.Print(('%s called the race off.'):format(Short(was.host)))
	end
end

local function Started(sender, seconds)
	if sender ~= party.host or party.state ~= 'gather' or seconds > 10 then return end
	if not Racing() then                             -- (you did not join: it is not your race)
		party, last.who = nil, nil
		return
	end
	if not ns.RaceAtStart() then
		local was = party
		party = nil
		Send('O:' .. was.id)
		ns.RaceEnd()
		ns.Print(('%s gave the start and you were not at the start, so you are not in this race.'):format(Short(was.host)))
		return
	end
	party.state = 'run'
	ns.RaceGo(seconds)
end

local function Checkpoint(sender, i, time)
	local points = party.course and #party.course.points
	if not points or i < 2 or i >= points then return end       -- (the finish has its own message)
	local racer = Racer(sender)
	if not racer or racer.splits[i] then return end
	racer.splits[i] = time
	-- you were the first at that checkpoint: now the lead is known (or that their time was the better)
	local race = ns.racing
	if race and race.together == party and race.leading == i then
		race.leading = nil
		local mine = party.racers[ME] and party.racers[ME].splits[i]
		if mine and ns.Get('splits') then
			local words, colour = Versus(racer.name, mine - time)
			ns.Say(words, ('Checkpoint %d/%d'):format(i - 1, points - 2), colour, 2)
			if ns.Get('chat') then ns.Print(('Checkpoint %d/%d: |c%s%s|r'):format(i - 1, points - 2, colour, words)) end
		end
	end
end

local function Finished(sender, time, void)
	local racer = Racer(sender)
	if not racer or racer.time or racer.out then return end
	racer.time, racer.void = time, void
	-- (a finish that arrives before the start has reached you is kept, and shown with the next one)
	if party.state ~= 'run' then return end
	local me = party.racers[ME]
	if party.joined and me and not me.out then
		ns.Say(('%s  %s'):format(racer.name, ns.Clock(time)), Screen(), ns.Get('finishColour'), 3)
	end
	Placings(true)
end

local function Stopped(sender)
	local racer = party.racers[sender]
	if not racer or racer.time then return end
	racer.out = true
	Placings(false)
end

local function Out(sender)
	if sender == party.host and party.state == 'gather' then return CalledOff() end
	local racer = party.racers[sender]
	if not racer or racer.time then return end
	Remove(sender)
	if party.state ~= 'gather' then return Placings(false) end
	if party.joined then ns.Print(('%s left the race.'):format(racer.name)) end
end

local function Seconds(text)
	if #text > 9 then return nil end
	local time = tonumber(text)
	if not time or time ~= time or time < 0 or time > LONGEST then return nil end
	return time
end

-- A message of a race together: its letter, the rest of it, the channel it came by and who sent it
-- (never yourself: Courses.lua has seen to that, and that nothing in it is secret).
function ns.TogetherHeard(kind, rest, channel, sender)
	if channel ~= 'PARTY' and channel ~= 'RAID' then return end
	if kind == 'I' then return Invited(rest, sender) end
	local id, more = rest:match('^(%d%d?%d?%d?%d?%d?)(.*)$')
	if not (party and id == party.id) then return end
	if kind == 'J' then
		if more == '' then Joined(sender) end
	elseif kind == 'G' then
		local seconds = more:match('^:(%d%d?)$')
		if seconds then Started(sender, tonumber(seconds)) end
	elseif kind == 'C' then
		local i, time = more:match('^:(%d%d?%d?):(%d+%.?%d*)$')
		time = time and Seconds(time)
		if time then Checkpoint(sender, tonumber(i), time) end
	elseif kind == 'F' then
		local time, void = more:match('^:(%d+%.?%d*):([01])$')
		time = time and Seconds(time)
		if time then Finished(sender, time, void == '1') end
	elseif kind == 'Q' then
		if more == '' then Stopped(sender) end
	elseif kind == 'O' then
		if more == '' then Out(sender) end
	end
end

---------------------------------------------------------------------------
-- Who is still in the group
---------------------------------------------------------------------------
-- The names of the group's other members; nothing when the game will not say just now.
local function Members()
	local exists = rawget(_G, 'UnitExists')
	if type(exists) ~= 'function' then return nil end
	local raid = IsInRaid and IsInRaid()
	local names = {}
	for i = 1, raid and 40 or 4 do
		local unit = (raid and 'raid' or 'party') .. i
		local ok, there = pcall(exists, unit)
		if ok and Plain(there) and there then
			local name = UnitName(unit)
			-- (a member not loaded yet has no name: say nothing rather than say they left)
			if not Plain(name) or type(name) ~= 'string' or name == rawget(_G, 'UNKNOWNOBJECT') then return nil end
			names[name] = true
		end
	end
	return names
end

local function Roster()
	if not party then return end
	if not ns.Group() then
		-- you are out of the group: nobody to race with, and nobody to tell
		local was = party
		party = nil
		local race = ns.racing
		if race and race.together == was then
			race.together, race.leading = nil, nil
			ns.Print('You are no longer in a group. The race goes on alone.')
		end
		return
	end
	local here = Members()
	if not here then return end
	local changed = false
	for who, racer in pairs(party.racers) do
		if who ~= ME and not racer.time and not racer.out and not here[racer.name] then
			if party.state == 'gather' then
				if who == party.host then return CalledOff() end
				Remove(who)
			else
				racer.out = true                         -- (left the group during the race: not finished)
				changed = true
			end
		end
	end
	if changed then Placings(false) end
end

ns.Try('watching the group', ns.On, 'GROUP_ROSTER_UPDATE', function() Roster() end)

-- for the checks outside the game
function ns.TogetherState() return party end
