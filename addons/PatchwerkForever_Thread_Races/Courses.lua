-- Thread (Races): the courses. Making one as you ride it, keeping it, and sending it to others.
--
-- A course is a list of checkpoints: the first is the start, the last the finish. Each is kept as the
-- game's map and a place on it (0 to 1 across and down), the way a map pin is, so it can be made the
-- map pin when it is raced. Kept in PatchwerkForever_Thread_RacesDB.courses[name]:
--     { points = { { m = uiMapID, x =, y = }, ... }, radius = yards, made = date, by = who made it,
--       best = { time = seconds, splits = { [checkpoint] = seconds }, date = } }
-- How near you are to a checkpoint is reckoned in the world's own yards, from where the game says you
-- are (UnitPosition) and where the checkpoint is (C_Map.GetWorldPosFromMapPos), as Thread (Routes) does.
local ADDON, ns = ...
if not ns.linked then return end

local PREFIX = 'PWFRace'      -- the addon messages a course is sent in
local CHUNK = 200             -- characters of a course in one message (a message holds 255)

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
	db.courses[making.name] = { points = making.points, radius = ns.Get('radius') or 12,
		made = date and date('%Y-%m-%d') or '', by = UnitName('player') }
	db.last = making.name
	ns.Print(('Course "%s" saved: a start, %d checkpoint(s) and the finish. /race start to race it.')
		:format(making.name, #making.points - 2))
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
	return ('"%s": %d checkpoints%s%s'):format(name, #course.points - 1,
		length and (', %d yards'):format(length) or '',
		course.best and (', best ' .. ns.Clock(course.best.time)) or '')
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
	if not course.best then
		ns.Print(('"%s" has not been finished yet.'):format(named))
		return
	end
	local parts = {}
	for i = 2, #course.points do
		local t = course.best.splits[i]
		if t then parts[#parts + 1] = (i == #course.points and 'finish ' or (i - 1) .. ': ') .. ns.Clock(t) end
	end
	ns.Print(('Best on "%s": %s (%s). %s.'):format(named, ns.Clock(course.best.time), course.best.date or '',
		table.concat(parts, ', ')))
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
	course.best = nil
	ns.Print(('Best run on "%s" forgotten.'):format(named))
end

---------------------------------------------------------------------------
-- Sending a course to someone, and keeping one you were sent
---------------------------------------------------------------------------
-- A course as a line of text: "1;radius;name;map,x,y;map,x,y;...".
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
	for i = 1, total do
		send(PREFIX, ('%s:%d:%d:%s'):format(id, i, total, line:sub((i - 1) * CHUNK + 1, i * CHUNK)), channel, to)
	end
	ns.Print(('Course "%s" sent to %s. They need Thread (Races) to keep it.'):format(name, to or 'your group'))
end

local incoming, offered = {}, nil

local function Heard(prefix, text, channel, sender)
	if prefix ~= PREFIX or type(text) ~= 'string' or not Plain(sender) then return end
	if type(sender) ~= 'string' or sender:match('^([^%-]+)') == UnitName('player') then return end
	local id, i, total, data = text:match('^(%d+):(%d+):(%d+):(.*)$')
	if not id then return end
	i, total = tonumber(i), tonumber(total)
	local key = tostring(sender) .. id
	local got = incoming[key] or { parts = {}, count = 0 }
	incoming[key] = got
	if not got.parts[i] then got.count = got.count + 1 end
	got.parts[i] = data
	if got.count < total then return end
	incoming[key] = nil
	local name, course = ns.Decode(table.concat(got.parts))
	if not name then return end
	course.by = sender
	offered = { name = name, course = course, from = sender }
	ns.Print(('%s sent you the course "%s" (%d checkpoints). /race accept to keep it.')
		:format(tostring(sender), name, #course.points - 1))
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
	ns.Print(('Course "%s" kept. /race start to race it.'):format(name))
	offered = nil
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
	pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
end
ns.Try('listening for courses', ns.On, 'CHAT_MSG_ADDON', function(...) Heard(...) end)
