-- Thread (Races): its settings, the slash command and the key bindings.
--
-- Race courses of your own (asked for on 2026-11-16: "custom race courses with markers"). You ride the
-- course once and place a checkpoint at each turn (Courses.lua); then you race it: the next checkpoint is
-- put on the map as your map pin and tracked, so the game shows its own marker for it in the world, and a
-- ring and a beam of light are drawn on that marker (Marker.lua). Reaching a checkpoint lights the next;
-- the time, the split at each checkpoint and your best run are kept (Race.lua).
--
-- An addon cannot draw in the world itself. The game's marker for a tracked pin is the one place in the
-- world an addon is told the screen position of (C_Navigation.GetFrame), which is why there is one
-- checkpoint marker at a time.
local ADDON, ns = ...
if not ns.linked then return end

ns.TITLE = 'Patchwerk Forever: Thread (Races)'

ns.settings = {
	{ key = 'radius', default = 12, min = 4, max = 40, step = 1, name = 'Checkpoint Size',
		desc = 'How near a checkpoint you must pass for it to count, in yards. A course you were sent keeps the size it was made with.' },
	{ key = 'countdown', default = true, name = 'Countdown At The Start',
		desc = 'Count down from 3 when you reach the start. Disabled: the clock starts the moment you reach it.' },
	{ key = 'splits', default = true, name = 'Show Split Times',
		desc = 'At each checkpoint, show your time and how far ahead of or behind your best run you are.' },
	{ key = 'sounds', default = true, name = 'Play Sounds',
		desc = 'Play a sound at the countdown, at each checkpoint and at the finish.' },
	{ key = 'restorePin', default = true, name = 'Restore Map Pin After A Race',
		desc = 'A race uses your map pin for the next checkpoint. Put back the pin you had before the race when it ends; disabled, the pin is cleared.' },
	{ key = 'chat', default = true, name = 'Split Times In Chat',
		desc = 'Also write each checkpoint\'s time, and the result, in chat.' },

	-- the marker drawn on the next checkpoint
	{ page = 'Races: Marker', voice = 'A ring on the ground. Patchwerk runs through it. Patchwerk is very proud.' },
	{ page = 'Races: Marker', key = 'marker', default = true, name = 'Show Checkpoint Marker',
		desc = 'Draw a ring and a beam of light on the next checkpoint, over the game\'s own waypoint marker.' },
	{ page = 'Races: Marker', key = 'markerSize', default = 120, min = 40, max = 300, step = 10, name = 'Size', parent = 'marker',
		desc = 'Size of the marker 40 yards away. It grows as you come nearer.' },
	{ page = 'Races: Marker', key = 'markerHeight', default = 0, min = -120, max = 120, step = 5, name = 'Vertical Offset', parent = 'marker',
		desc = 'Move the ring up (positive) or down from the game\'s waypoint marker, so it sits on the ground.' },
	{ page = 'Races: Marker', key = 'markerBeam', default = true, name = 'Show Light Beam', parent = 'marker',
		desc = 'A beam of light rising from the ring, to see it from far away.' },
	{ page = 'Races: Marker', key = 'markerText', default = true, name = 'Show Checkpoint Number And Distance', parent = 'marker',
		desc = 'Write which checkpoint it is and how far away, under the ring.' },
	{ page = 'Races: Marker', key = 'startColour', colour = true, default = 'ff66ff80', name = 'Start Color', parent = 'marker',
		desc = 'Color of the marker on the start.' },
	{ page = 'Races: Marker', key = 'markerColour', colour = true, default = 'ff4dd2ff', name = 'Checkpoint Color', parent = 'marker',
		desc = 'Color of the marker on a checkpoint.' },
	{ page = 'Races: Marker', key = 'finishColour', colour = true, default = 'ffffd24d', name = 'Finish Color', parent = 'marker',
		desc = 'Color of the marker on the finish.' },
	{ page = 'Races: Marker', key = 'hideGameMarker', default = false, name = 'Hide Game Waypoint Icon During Races',
		desc = 'Hide the game\'s own waypoint icon and distance while a race is on, so only this marker shows. It comes back when the race ends.' },
	{ page = 'Races: Marker', button = 'Test', name = 'Preview Marker', click = function() ns.MarkerTest() end,
		desc = 'Show the marker in the middle of the screen for a few seconds.' },
}

---------------------------------------------------------------------------
-- /race
---------------------------------------------------------------------------
local function Help()
	ns.Print('Race commands:')
	ns.Print('  /race new <name>: start a new course where you stand; then /race mark at each checkpoint, /race undo to take the last one back')
	ns.Print('  /race save: keep the course (the last checkpoint is the finish);  /race cancel: throw it away')
	ns.Print('  /race start [name]: race a course (the last one, without a name);  /race stop: stop racing')
	ns.Print('  /race list;  /race best [name];  /race delete <name>;  /race reset <name>: forget its best run')
	ns.Print('  /race share [name] [player]: send a course to your party, or to one player;  /race accept: keep one you were sent')
	ns.Print('  /race config: open the options')
end

SLASH_PATCHWERKFOREVER_RACES1 = '/race'
SLASH_PATCHWERKFOREVER_RACES2 = '/pfr'
SlashCmdList.PATCHWERKFOREVER_RACES = function(text)
	local word, rest = (text or ''):match('^%s*(%S*)%s*(.-)%s*$')
	word = word:lower()
	if word == 'new' then
		ns.Try('the new course', ns.CourseNew, rest)
	elseif word == 'mark' or word == 'add' then
		ns.Try('placing a checkpoint', ns.CourseMark)
	elseif word == 'undo' then
		ns.Try('taking a checkpoint back', ns.CourseUndo)
	elseif word == 'save' or word == 'done' then
		ns.Try('saving the course', ns.CourseSave)
	elseif word == 'cancel' then
		ns.Try('the new course', ns.CourseCancel)
	elseif word == 'start' or word == 'go' then
		ns.Try('the race', ns.RaceStart, rest)
	elseif word == 'stop' then
		ns.Try('the race', ns.RaceStop)
	elseif word == 'list' then
		ns.Try('the courses', ns.CourseList)
	elseif word == 'best' then
		ns.Try('the courses', ns.CourseBest, rest)
	elseif word == 'delete' then
		ns.Try('the courses', ns.CourseDelete, rest)
	elseif word == 'reset' then
		ns.Try('the courses', ns.CourseReset, rest)
	elseif word == 'share' or word == 'send' then
		ns.Try('sharing a course', ns.CourseShare, rest)
	elseif word == 'accept' then
		ns.Try('a course you were sent', ns.CourseAccept)
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not ns.OpenSettings() then
			ns.Print('Options are under Options > AddOns > Patchwerk Forever > Thread: Races.')
		end
	elseif word == '' and ns.racing then
		ns.Try('the race', ns.RaceSay)
	else
		Help()
	end
end

-- For key and gamepad bindings (Bindings.xml).
BINDING_HEADER_PATCHWERKFOREVER_RACES = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_RACES_MARK = 'Place Checkpoint'
BINDING_NAME_PATCHWERKFOREVER_RACES_START = 'Start Last Race'
BINDING_NAME_PATCHWERKFOREVER_RACES_STOP = 'Stop Race'
function PatchwerkForever_Thread_Races_Mark() ns.Try('placing a checkpoint', ns.CourseMark) end
function PatchwerkForever_Thread_Races_Start() ns.Try('the race', ns.RaceStart, '') end
function PatchwerkForever_Thread_Races_Stop() ns.Try('the race', ns.RaceStop) end
