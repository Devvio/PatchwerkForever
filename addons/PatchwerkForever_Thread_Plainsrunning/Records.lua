-- Immersive Plainsrunning (Thread): each character's run records.
--
-- A run is from the first stack of the buff to its end. Kept for each character (in
-- PatchwerkForever_Thread_PlainsrunningRecords, saved per character):
--   longest   the most seconds spent at full stacks (30) in one run
--   fastest   the fewest seconds from the first stack to 30 (only runs seen from their first stack)
--   farthest  the most yards covered in one run (on foot: not mounted, on a flight or in a vehicle)
--   runs      how many runs reached 30;  total  yards covered in all runs
-- with the day each record was set. A new record is told in chat (Tell Me About New Records); the
-- first run that reaches 30 is told as the first. The preview never counts.
--
-- The stacks are told here when they change (from Run.lua); while a run lasts, a small frame adds up
-- the yards and the seconds at full stacks four times a second. The rest of the time nothing runs.
local ADDON, ns = ...
if not ns.linked then return end

local SAVED = 'PatchwerkForever_Thread_PlainsrunningRecords'
local EVERY = 0.25                    -- seconds between counts during a run

local run                             -- { start, partial, yards, full, reached, stacks }
local clock

local function DB()
	local db = rawget(_G, SAVED)
	if type(db) ~= 'table' then
		db = {}
		_G[SAVED] = db
	end
	return db
end

local function Time(seconds)
	seconds = math.floor(( seconds or 0 ) + 0.5)
	return ( '%d:%02d' ):format(math.floor(seconds / 60), seconds % 60)
end

local function Yards(yards)
	local n = tostring(math.floor(( yards or 0 ) + 0.5))
	while true do
		local done
		n, done = n:gsub('^(%d+)(%d%d%d)', '%1,%2')
		if done == 0 then break end
	end
	return n .. ' yards'
end

local function Today()
	local date = rawget(_G, 'date')
	return type(date) == 'function' and date('%Y-%m-%d') or nil
end

local function OnFoot()
	if rawget(_G, 'IsMounted') and IsMounted() then return false end
	if rawget(_G, 'UnitOnTaxi') and UnitOnTaxi('player') then return false end
	if rawget(_G, 'UnitInVehicle') and UnitInVehicle('player') then return false end
	return true
end

local function Count(elapsed)
	if not run then return end
	if OnFoot() then
		local speed = rawget(_G, 'GetUnitSpeed') and GetUnitSpeed('player')
		speed = ns.Plain(speed)                     -- (kept secret just now: this stretch is not counted)
		run.yards = run.yards + ( tonumber(speed) or 0 ) * elapsed
	end
	if run.stacks >= ns.MAX then run.full = run.full + elapsed end
end

local function Clock()
	if not clock then
		clock = CreateFrame('Frame')
		clock.wait = 0
		clock:SetScript('OnUpdate', function(self, elapsed)
			self.wait = self.wait + elapsed
			if self.wait >= EVERY then
				local ok, problem = pcall(Count, self.wait)
				self.wait = 0
				if not ok then
					run = nil
					self:Hide()
					ns.Print('This run is not counted in your records, because of a problem: ' .. tostring(problem))
				end
			end
		end)
	end
	return clock
end

-- the run is over: compare it with the records
local function Finish()
	local this = run
	run = nil
	if clock then
		clock.wait = 0
		clock:Hide()
	end
	if not ( this and this.reached ) then return end
	local db, today = DB(), Today()
	local first = ( db.runs or 0 ) == 0
	db.runs = ( db.runs or 0 ) + 1
	db.total = ( db.total or 0 ) + this.yards
	local news = {}
	local function Better(key, value, smaller, shown, name)
		local old = db[key]
		if old == nil or ( smaller and value < old ) or ( not smaller and value > old ) then
			db[key], db[key .. 'Day'] = value, today
			if old ~= nil then news[#news + 1] = ( '%s: %s (was %s)' ):format(name, shown(value), shown(old)) end
		end
	end
	Better('longest', this.full, false, Time, 'Longest at full speed')
	if not this.partial then Better('fastest', this.reached, true, Time, 'Fastest to 30 stacks') end
	if this.yards > 0 then Better('farthest', this.yards, false, Yards, 'Farthest run') end
	if not ns.Get('recordsTell') then return end
	if first then
		ns.Print(( 'First run at full speed recorded: %s at 30 stacks%s, %s. /plains records lists your records.' ):format(
			Time(this.full), this.partial and '' or ( ', 30 stacks in ' .. Time(this.reached) ), Yards(this.yards)))
	else
		for _, line in ipairs(news) do ns.Print('New record! ' .. line .. '.') end
	end
end

-- Told by Run.lua whenever the buff's stacks change.
function ns.RecordsAura(stacks, before)
	local ok, problem = pcall(function()
		local now = GetTime()
		if stacks > 0 and not run then
			run = { start = now, partial = before > 0 or stacks > 1, yards = 0, full = 0, stacks = stacks }
			Clock():Show()
		elseif run then
			pcall(Count, Clock().wait)      -- (the stacks before the change count up to now)
			Clock().wait = 0
		end
		if run then
			run.stacks = stacks
			if stacks >= ns.MAX and not run.reached then run.reached = now - run.start end
		end
		if stacks <= 0 and run then Finish() end
	end)
	if not ok then
		run = nil
		if clock then clock:Hide() end
		ns.Print('This run is not counted in your records, because of a problem: ' .. tostring(problem))
	end
end

function ns.SayRecords()
	local db = DB()
	if not db.runs or db.runs == 0 then
		ns.Print('No run records yet: they start with your first run to 30 stacks of Plainsrunning.')
		return
	end
	local function Day(key) return db[key .. 'Day'] and ( ' (' .. db[key .. 'Day'] .. ')' ) or '' end
	ns.Print('Run records for this character:')
	ns.Print('  Longest at full speed: ' .. Time(db.longest) .. Day('longest'))
	ns.Print('  Fastest to 30 stacks: ' .. ( db.fastest and ( Time(db.fastest) .. Day('fastest') ) or 'none yet' ))
	ns.Print('  Farthest run: ' .. ( db.farthest and ( Yards(db.farthest) .. Day('farthest') ) or 'none yet' ))
	ns.Print(( '  Runs at full speed: %d, %s in all' ):format(db.runs, Yards(db.total)))
	if run then ns.Print('  A run is going on now; it is counted when it ends.') end
end

function ns.ResetRecords()
	_G[SAVED] = {}
	ns.Print('Run records forgotten for this character.')
end

-- for the checks outside the game
function ns.RecordsState() return run, DB() end
