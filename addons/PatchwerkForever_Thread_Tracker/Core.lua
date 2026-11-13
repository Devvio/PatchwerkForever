-- Thread (Tracker): its settings and the slash command.
local ADDON, ns = ...
if not ns.linked then return end

ns.TITLE = 'Patchwerk Forever: Thread (Tracker)'

---------------------------------------------------------------------------
-- Settings: kept in PatchwerkForever_Thread_TrackerDB.settings
---------------------------------------------------------------------------
-- One entry a setting, in the order they are shown. The base makes the pages from this list and
-- says what each kind of entry becomes (its Tools.lua). page: the page it is on (none: the first,
-- "Thread: Tracker"). parent: greyed out while that tick box is off.
ns.settings = {
	{ key = 'on', default = true, name = 'Show The Tracker',
		desc = 'A list of the quests you track, with what each still asks of you. Unticked, it is gone and the game\'s own tracker is as it was.' },
	{ key = 'quiet', default = true, name = 'Hide The Game\'s Own Tracker', parent = 'on',
		desc = 'While this tracker is shown, the game\'s own is made invisible and lets clicks through, so you do not see every quest twice. It is not removed: unticking this brings it back.' },
	{ key = 'quietInstance', default = true, name = 'But Not In Dungeons And Raids', parent = 'quiet',
		desc = 'Inside a dungeon, a raid or a battleground the game\'s own tracker is let back, because it shows things there that this one does not: a dungeon\'s stages, timers, scores.' },
	{ key = 'levels', default = true, name = 'Quest Levels',
		desc = 'Write a quest\'s level before its name.' },
	{ key = 'doneLines', default = true, name = 'Objectives Already Done',
		desc = 'Keep an objective in the list, dimmed, once it is done. Unticked, it goes as soon as it is done.' },
	{ key = 'width', default = 260, min = 180, max = 500, step = 10, name = 'Width',
		desc = 'How wide the tracker is.' },
	{ key = 'height', default = 450, min = 150, max = 1000, step = 25, name = 'Tallest It Grows',
		desc = 'The tracker is as tall as what is in it, up to this; past it, the list scrolls with the mouse wheel.' },
	{ header = true, name = 'Its Place' },
	{ button = 'Move', name = 'Move It With The Mouse', click = function() ns.Unlock() end,
		desc = 'Shows a bar along the tracker\'s top to drag it by. Press the button again, or type /tracker lock, to fix it there.' },
	{ button = 'Reset', name = 'Put It Back', click = function() ns.ResetPlace() end,
		desc = 'Puts the tracker back where it began, under the minimap.' },

	-- how it looks
	{ page = 'Tracker: Look', key = 'scale', default = 100, min = 60, max = 160, step = 5, name = 'Size',
		desc = 'How large the whole tracker is, in percent.' },
	{ page = 'Tracker: Look', key = 'fontSize', default = 12, min = 9, max = 20, step = 1, name = 'Size Of The Writing',
		desc = 'How large the words are written.' },
	{ page = 'Tracker: Look', key = 'back', default = 25, min = 0, max = 90, step = 5, name = 'Background',
		desc = 'How dark the tracker\'s background is, in percent. Zero is none.' },
	{ page = 'Tracker: Look', key = 'titleByLevel', default = true, name = 'Colour Quests By Difficulty',
		desc = 'A quest\'s name in the game\'s colours for its difficulty: grey, green, yellow, orange, red. Unticked, every name has the one colour below.' },
	{ page = 'Tracker: Look', key = 'lookTitle', colour = true, default = 'ffffd200', name = 'Colour: Quest Names',
		desc = 'The colour of a quest\'s name, when names are not coloured by difficulty.' },
	{ page = 'Tracker: Look', key = 'lookHeader', colour = true, default = 'ffd6a35b', name = 'Colour: Headings',
		desc = 'The colour of the headings and of the stitches under them.' },
	{ page = 'Tracker: Look', key = 'lookLine', colour = true, default = 'ffd8d8d8', name = 'Colour: Objectives',
		desc = 'The colour of an objective still to be done.' },
	{ page = 'Tracker: Look', key = 'lookDone', colour = true, default = 'ff6fbf73', name = 'Colour: Done',
		desc = 'The colour of an objective that is done, and of a quest ready to hand in.' },
}

---------------------------------------------------------------------------
-- /tracker
---------------------------------------------------------------------------
local function Help()
	ns.Print('the quests you track, in a list of our own.')
	ns.Print('  /tracker on, /tracker off: show it, or go back to the game\'s own')
	ns.Print('  /tracker move: drag it somewhere else;  /tracker lock: fix it there;  /tracker reset: put it back')
	ns.Print('  /tracker fold: fold it up, or open it again')
	ns.Print('  /tracker config: open the settings')
end

SLASH_PATCHWERKFOREVER_TRACKER1 = '/tracker'
SLASH_PATCHWERKFOREVER_TRACKER2 = '/pftr'
SlashCmdList.PATCHWERKFOREVER_TRACKER = function(text)
	local word = (text or ''):lower():match('^%s*(%S*)')
	if word == 'on' or word == 'off' then
		ns.Set('on', word == 'on')
		ns.Print(word == 'on' and 'shown.' or 'hidden. The game\'s own tracker is as it was.')
	elseif word == 'move' or word == 'unlock' then
		ns.Try('move', ns.Unlock, true)
	elseif word == 'lock' then
		ns.Try('lock', ns.Unlock, false)
	elseif word == 'reset' then
		ns.Try('reset', ns.ResetPlace)
	elseif word == 'fold' or word == 'toggle' then
		ns.Try('fold', ns.Fold)
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not ns.OpenSettings() then
			ns.Print('the settings are under Options > AddOns > Patchwerk Forever > Thread: Tracker.')
		end
	else
		Help()
	end
end

-- For key and gamepad bindings (Bindings.xml).
BINDING_HEADER_PATCHWERKFOREVER_TRACKER = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_TRACKER_FOLD = 'Fold the tracker up, or open it'
function PatchwerkForever_Thread_Tracker_Fold() ns.Try('fold', ns.Fold) end
