-- Races (Thread): the courses. Making one as you ride it, keeping it, and sending it to others.
--
-- A course is a list of checkpoints: the first is the start, the last the finish. Each is kept as the
-- game's map and a place on it (0 to 1 across and down), the way a map pin is, so it can be made the
-- map pin when it is raced. Kept in PatchwerkForever_Thread_RacesDB.courses[name]:
--     { points = { { m = uiMapID, x =, y = }, ... }, radius = yards, made = date, by = who made it,
--       rule = 'any' or 'foot' (none, as on a course from before 0.2.0: 'any'),
--       best = { time = seconds, splits = { [checkpoint] = seconds }, date = },
--       footBest = { the same } }
-- How near you are to a checkpoint is reckoned in the world's own yards, from where the game says you
-- are (UnitPosition) and where the checkpoint is (C_Map.GetWorldPosFromMapPos), as Routes (Thread) does.
--
-- The rule: Anything Goes ('any'), or On Foot ('foot'), under which a run does not count when you were
-- mounted or on a flight path during it (Race.lua judges that). A course keeps a best run for each rule:
-- `best` is the one under Anything Goes, where every best run from before there were rules already is,
-- and `footBest` the one under On Foot. Changing the rule touches neither.
local ADDON, ns = ...
if not ns.linked then return end

local PREFIX = 'PWFRace'      -- the addon messages a course is sent in
local CHUNK = 200             -- characters of a course in one message (a message holds 255)
local MOST = 60               -- messages a course may come in; more is not a course of ours
local WAITING = 8             -- courses still arriving that are kept at once

local RULES = { any = 'Anything Goes', foot = 'On Foot' }
ns.PREFIX, ns.RULES = PREFIX, RULES

local function Plain(value)
	return value ~= nil and not (issecretvalue and issecretvalue(value))
end

local function DB()
	local db = PatchwerkForever_Thread_RacesDB
	db.courses = db.courses or {}
	return db
end
ns.DB = DB

-- 1:02.3 (or 0:09.8): a time in minutes and seconds.
function ns.Clock(seconds)
	seconds = seconds < 0 and 0 or seconds
	local m = math.floor(seconds / 60)
	return ('%d:%04.1f'):format(m, seconds - m * 60)
end

-- "1 checkpoint" or "3 checkpoints".
function ns.Checkpoints(count)
	return count == 1 and '1 checkpoint' or ('%d checkpoints'):format(count)
end

-- +1.2 or -0.8: how far behind (+) or ahead (-) of another time.
function ns.Gap(seconds)
	return (seconds >= 0 and '+%.1f' or '-%.1f'):format(math.abs(seconds))
end

---------------------------------------------------------------------------
-- Where things are
---------------------------------------------------------------------------
-- Where you stand, as a checkpoint is kept: the map and the place on it. Nothing where the game will not say.
function ns.Here()
	local map = C_Map.GetBestMapForUnit('player')
	if not Plain(map) or not map then return nil end
	local pos = C_Map.GetPlayerMapPosition(map, 'player')
	if not pos then return nil end
	local x, y = pos:GetXY()
	if not (Plain(x) and Plain(y) and x and y) or (x == 0 and y == 0) then return nil end
	return { m = map, x = math.floor(x * 10000 + 0.5) / 10000, y = math.floor(y * 10000 + 0.5) / 10000 }
end

-- Where you are in the world: x, y in yards and the continent. Nothing in places the game keeps to itself.
local function Place()
	local x, y, _, world = UnitPosition('player')
	if not (Plain(x) and Plain(y) and x and y) then return nil end
	return x, y, world
end

-- Where a checkpoint is in the world (worked out once a checkpoint).
local worlds = setmetatable({}, { __mode = 'k' })
local function World(point)
	local w = worlds[point]
	if w == nil then
		local ok, world, pos = pcall(C_Map.GetWorldPosFromMapPos, point.m, CreateVector2D(point.x, point.y))
		w = false
		if ok and pos then
			local x, y = pos:GetXY()
			if x and y then w = { x, y, world } end
		end
		worlds[point] = w
	end
	return w or nil
end

-- How far you are from a checkpoint, in yards; nothing when it cannot be told this way.
function ns.Distance(point)
	local w = World(point)
	local x, y, world = Place()
	if not (w and x) or (w[3] and world and w[3] ~= world) then return nil end
	local dx, dy = x - w[1], y - w[2]
	return (dx * dx + dy * dy) ^ 0.5
end

-- How far apart two checkpoints are, in yards; nothing when it cannot be told.
local function Apart(a, b)
	local p, q = World(a), World(b)
	if not (p and q) or p[3] ~= q[3] then return nil end
	return ((p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2) ^ 0.5
end

-- The course of that name, or the last one raced or made when no name is given; and its name.
function ns.Course(name)
	local db = DB()
	name = name and name ~= '' and name or db.last
	if not name then return nil end
	if db.courses[name] then return db.courses[name], name end
	local lower = name:lower()
	for other, course in pairs(db.courses) do
		if other:lower() == lower then return course, other end
	end
	return nil, name
end

local function Clean(name)
	return ((name or ''):gsub('[|;:]', ''):gsub('^%s+', ''):gsub('%s+$', ''))
end
ns.Clean = Clean

-- A course's rule ('any' or 'foot'), and where the best run under a rule is kept on a course.
function ns.Rule(course)
	return course.rule == 'foot' and 'foot' or 'any'
end

function ns.BestKey(rule)
	return rule == 'foot' and 'footBest' or 'best'
end

-- The best run on a course under a rule (the course's own, when none is given).
function ns.Best(course, rule)
	return course[ns.BestKey(rule or ns.Rule(course))]
end

-- A number that is the same for the same checkpoints and size, whatever the course is named: how two
-- players know they have the same course (Together.lua). Not a secret, only a comparison.
function ns.Fingerprint(course)
	local sum = 7
	local function Add(text)
		for i = 1, #text do sum = (sum * 31 + text:byte(i)) % 2147483647 end
	end
	Add(tostring(course.radius or 12))
	for _, p in ipairs(course.points) do Add((';%d,%.4f,%.4f'):format(p.m, p.x, p.y)) end
	return ('%d'):format(sum)
end

---------------------------------------------------------------------------
-- Making a course
---------------------------------------------------------------------------
local making                  -- the course being made: { name =, points = {} }

function ns.CourseNew(name)
	name = Clean(name)
	if name == '' then
		ns.Print('Give the course a name: /race new <name>.')
		return
	end
	if ns.racing then ns.RaceStop() end
	making = { name = name, points = {} }
	ns.Print(('New course "%s". The start is placed where you stand; ride the course and place a checkpoint at each turn with /race mark (or the Place Checkpoint key binding). The last one is the finish. /race save when done.'):format(name))
	if DB().courses[name] then
		ns.Print('A course of that name already exists; saving replaces it.')
	end
	ns.CourseMark()
end

function ns.CourseMark()
	if not making then
		ns.Print('No course is being made. Start one with /race new <name>.')
		return
	end
	local here = ns.Here()
	if not here then
		ns.Print('Your position on the map is not available here, so no checkpoint can be placed.')
		return
	end
	local points = making.points
	local before = points[#points]
	points[#points + 1] = here
	if #points == 1 then
		ns.Print('Start placed.')
	else
		local far = Apart(before, here)
		ns.Print(('Checkpoint %d placed%s.'):format(#points - 1, far and (' (%d yards from the last)'):format(far) or ''))
		if far and far < (ns.Get('radius') or 12) then
			ns.Print('That is inside the last checkpoint. /race undo takes it back.')
		end
	end
	if ns.Shown then ns.Shown(here, #points == 1 and 'start' or 'checkpoint') end
end

function ns.CourseUndo()
	if not (making and #making.points > 0) then
		ns.Print('No checkpoint to take back.')
		return
	end
	making.points[#making.points] = nil
	ns.Print(#making.points == 0 and 'Start taken back. /race mark places it again.'
		or ('Checkpoint taken back; %d left after the start.'):format(#making.points - 1))
end

function ns.CourseCancel()
	if not making then
		ns.Print('No course is being made.')
		return
	end
	ns.Print(('Course "%s" thrown away.'):format(making.name))
	making = nil
end

function ns.CourseSave()
	if not making then
		ns.Print('No course is being made. Start one with /race new <name>.')
		return
	end
	if #making.points < 2 then
		ns.Print('A course needs a start and at least one more checkpoint. Place one with /race mark.')
		return
	end
	local db = DB()
	local rule = ns.Get('rule') == 'foot' and 'foot' or 'any'
	db.courses[making.name] = { points = making.points, radius = ns.Get('radius') or 12,
		made = date and date('%Y-%m-%d') or '', by = UnitName('player'), rule = rule }
	db.last = making.name
	local between = #making.points - 2
	ns.Print(('Course "%s" saved: %s. /race start to race it.'):format(making.name, between == 0
		and 'a start and the finish' or ('a start, %s and the finish'):format(ns.Checkpoints(between))))
	if rule == 'foot' then ns.Print('Its rule is On Foot. /race rule any changes it.') end
	making = nil
end

function ns.Making() return making end

---------------------------------------------------------------------------
-- The courses you have
---------------------------------------------------------------------------
local function Length(course)
	local total = 0
	for i = 2, #course.points do
		local far = Apart(course.points[i - 1], course.points[i])
		if not far then return nil end
		total = total + far
	end
	return total
end

local function Describe(name, course)
	local length = Length(course)
	local best = ns.Best(course)
	return ('"%s": %s%s, %s%s'):format(name, ns.Checkpoints(#course.points - 1),
		length and (', %d yards'):format(length) or '', RULES[ns.Rule(course)],
		best and (', best ' .. ns.Clock(best.time)) or '')
end

function ns.CourseList()
	local names = {}
	for name in pairs(DB().courses) do names[#names + 1] = name end
	table.sort(names)
	if #names == 0 then
		ns.Print('No courses yet. /race new <name> starts one where you stand.')
		return
	end
	ns.Print('Your courses:')
	for _, name in ipairs(names) do ns.Print('  ' .. Describe(name, DB().courses[name])) end
end

function ns.CourseBest(name)
	local course, named = ns.Course(name)
	if not course then
		ns.Print(named and ('No course named "%s".'):format(named) or 'No course yet.')
		return
	end
	local rule = ns.Rule(course)
	local best = ns.Best(course, rule)
	local other = rule == 'foot' and 'any' or 'foot'
	local kept = ns.Best(course, other)              -- (the best run under the rule it does not have now)
	if not best then
		ns.Print(('"%s" (%s) has not been finished yet.'):format(named, RULES[rule]))
	else
		local parts = {}
		for i = 2, #course.points do
			local t = best.splits[i]
			if t then parts[#parts + 1] = (i == #course.points and 'finish ' or (i - 1) .. ': ') .. ns.Clock(t) end
		end
		ns.Print(('Best on "%s" (%s): %s (%s). %s.'):format(named, RULES[rule], ns.Clock(best.time), best.date or '',
			table.concat(parts, ', ')))
	end
	if kept then
		ns.Print(('Its best under %s: %s (%s).'):format(RULES[other], ns.Clock(kept.time), kept.date or ''))
	end
end

function ns.CourseDelete(name)
	local course, named = ns.Course(name ~= '' and name or '\0')
	if not course then
		ns.Print('Name the course to delete: /race delete <name>. /race list shows them.')
		return
	end
	if ns.racing and ns.racing.name == named then ns.RaceStop() end
	DB().courses[named] = nil
	if DB().last == named then DB().last = nil end
	ns.Print(('Course "%s" deleted.'):format(named))
end

function ns.CourseReset(name)
	local course, named = ns.Course(name ~= '' and name or '\0')
	if not course then
		ns.Print('Name the course: /race reset <name>. /race list shows them.')
		return
	end
	-- (only the one under the rule the course has now; the other rule's is not what was asked about)
	course[ns.BestKey(ns.Rule(course))] = nil
	ns.Print(('Best run on "%s" under %s forgotten.'):format(named, RULES[ns.Rule(course)]))
end

-- /race rule foot|any [name]: a course's rule. Without anything, says the last course's rule.
function ns.CourseRule(text)
	local word, name = (text or ''):match('^%s*(%S*)%s*(.-)%s*$')
	word = word:lower()
	local rule = (word == 'foot' or word == 'onfoot') and 'foot' or (word == 'any' or word == 'anything') and 'any' or nil
	if not rule and word ~= '' then
		ns.Print('Rules: /race rule foot [name] for On Foot, /race rule any [name] for Anything Goes.')
		return
	end
	local course, named = ns.Course(name)
	if not course then
		ns.Print(named and ('No course named "%s". /race list shows them.'):format(named) or 'No course yet.')
		return
	end
	if not rule then
		ns.Print(('The rule of "%s" is %s. /race rule foot or /race rule any changes it.'):format(named, RULES[ns.Rule(course)]))
		return
	end
	if ns.Rule(course) == rule then
		ns.Print(('The rule of "%s" is already %s.'):format(named, RULES[rule]))
		return
	end
	local before = ns.Rule(course)
	course.rule = rule
	ns.Print(('The rule of "%s" is now %s%s.%s'):format(named, RULES[rule],
		rule == 'foot' and ': a run during which you are mounted or on a flight path does not count' or '',
		ns.Best(course, before) and (' Its best run under %s is kept.'):format(RULES[before]) or ''))
	if ns.racing and ns.racing.course == course then
		ns.Print('The race that is on keeps the rule it started with.')
	end
end

---------------------------------------------------------------------------
-- Sending a course to someone, and keeping one you were sent
---------------------------------------------------------------------------
-- A course as a line of text: "1;radius;name;map,x,y;map,x,y;...", sent in pieces "id:piece:pieces:text".
--
-- The rule is not in that line. Races 0.1.x reads every part after the name as a checkpoint and drops
-- the whole course when one is not, so nothing can be added to the line that it would still accept. The
-- rule goes in a message of its own, "R:id:foot", sent before the pieces: 0.1.x passes over a message
-- that does not begin with a number, and keeps the course as it always did. A course that comes with no
-- such message (from 0.1.x, or an Anything Goes course) is Anything Goes.
-- Every other message that begins with a letter belongs to a race together (Together.lua).
function ns.Encode(name, course)
	local parts = { '1', tostring(course.radius or 12), Clean(name) }
	for _, p in ipairs(course.points) do
		parts[#parts + 1] = ('%d,%.4f,%.4f'):format(p.m, p.x, p.y)
	end
	return table.concat(parts, ';')
end

function ns.Decode(text)
	local parts = {}
	for piece in (text .. ';'):gmatch('([^;]*);') do parts[#parts + 1] = piece end
	if parts[1] ~= '1' or #parts < 5 then return nil end
	local course = { radius = tonumber(parts[2]) or 12, points = {} }
	for i = 4, #parts do
		local m, x, y = parts[i]:match('^(%d+),([%d%.]+),([%d%.]+)$')
		if not m then return nil end
		course.points[#course.points + 1] = { m = tonumber(m), x = tonumber(x), y = tonumber(y) }
	end
	return Clean(parts[3]), course
end

local function Group()
	if IsInRaid and IsInRaid() then return 'RAID' end
	if IsInGroup and IsInGroup() then return 'PARTY' end
	return nil
end
ns.Group = Group

function ns.CourseShare(text)
	local course, name = ns.Course(text)             -- all of it a course's name (none: the last course)
	local to
	if not course and text ~= '' then
		local first, last = text:match('^(.-)%s*(%S+)$')  -- a name and a player, or only a player
		course, name = ns.Course(first)
		to = last
	end
	if not course then
		ns.Print('No such course. /race list shows them; /race share <name> [player].')
		return
	end
	local channel = to and 'WHISPER' or Group()
	if not channel then
		ns.Print('You are not in a group. Name a player to send it to: /race share ' .. name .. ' <player>.')
		return
	end
	local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
	if not send then
		ns.Print('This game client cannot send addon messages.')
		return
	end
	local line = ns.Encode(name, course)
	local id = tostring(math.random(1000, 9999))
	local total = math.ceil(#line / CHUNK)
	if ns.Rule(course) == 'foot' then send(PREFIX, ('R:%s:foot'):format(id), channel, to) end
	for i = 1, total do
		send(PREFIX, ('%s:%d:%d:%s'):format(id, i, total, line:sub((i - 1) * CHUNK + 1, i * CHUNK)), channel, to)
	end
	ns.Print(('Course "%s" sent to %s. They need Races (Thread) to keep it.'):format(name, to or 'your group'))
end

local incoming, offered = {}, nil

-- The course a sender is sending under an id, while its messages arrive. What others send is not
-- trusted to end: when too many are half arrived, they are all let go.
local function Arriving(key)
	local got = incoming[key]
	if got then return got end
	local count = 0
	for _ in pairs(incoming) do count = count + 1 end
	if count >= WAITING then incoming = {} end
	got = { parts = {}, count = 0 }
	incoming[key] = got
	return got
end

local function Heard(prefix, text, channel, sender)
	if not (Plain(prefix) and Plain(text) and Plain(sender)) then return end
	if prefix ~= PREFIX or type(text) ~= 'string' or #text > 255 then return end
	if type(sender) ~= 'string' or sender:match('^([^%-]+)') == UnitName('player') then return end
	local kind, rest = text:match('^(%a):(.*)$')
	if kind == 'R' then                              -- the rule of a course on its way, or just arrived
		local id, rule = rest:match('^(%d%d?%d?%d?%d?%d?):(%a+)$')
		if not (id and RULES[rule]) then return end
		local key = sender .. id
		if offered and offered.key == key then
			offered.course.rule = rule
		else
			Arriving(key).rule = rule
		end
		return
	elseif kind then
		return ns.TogetherHeard(kind, rest, Plain(channel) and channel or nil, sender)
	end
	local id, i, total, data = text:match('^(%d+):(%d+):(%d+):(.*)$')
	if not id then return end
	i, total = tonumber(i), tonumber(total)
	if total < 1 or total > MOST or i < 1 or i > total then return end
	local key = sender .. id
	local got = Arriving(key)
	if not got.parts[i] then got.count = got.count + 1 end
	got.parts[i] = data
	if got.count < total then return end
	incoming[key] = nil
	local name, course = ns.Decode(table.concat(got.parts))
	if not name then return end
	course.by = sender
	course.rule = got.rule or 'any'
	offered = { name = name, course = course, from = sender, key = key }
	ns.Print(('%s sent you the course "%s" (%s, %s). /race accept to keep it.')
		:format(sender, name, ns.Checkpoints(#course.points - 1), RULES[course.rule]))
end

function ns.CourseAccept()
	if not offered then
		ns.Print('Nobody has sent you a course.')
		return
	end
	local db, name = DB(), offered.name
	if db.courses[name] then name = ('%s (%s)'):format(name, (tostring(offered.from):match('^([^%-]+)'))) end
	offered.course.made = date and date('%Y-%m-%d') or ''
	db.courses[name] = offered.course
	db.last = name
	ns.Print(('Course "%s" kept (%s). /race start to race it.'):format(name, RULES[ns.Rule(offered.course)]))
	offered = nil
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
	pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
end
ns.Try('listening for courses', ns.On, 'CHAT_MSG_ADDON', function(...) Heard(...) end)
