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
--
-- What starts unticked: anything that changes something of the game's or of another addon's by
-- itself (moving the game's arrow, hiding RestedXP's window), the three ways of stepping back, and
-- the dungeon stages, which have not been seen in a dungeon yet.
local QUESTS, GUIDE, MORE, LOOK = 'Tracker: Quests', 'Tracker: Guide', 'Tracker: More', 'Tracker: Appearance'

ns.settings = {
	{ header = true, name = 'General' },
	{ key = 'on', default = true, name = 'Enable Tracker',
		desc = 'Show the Patchwerk quest tracker. When disabled, the default quest tracker is used.' },
	{ key = 'quiet', default = true, name = 'Hide Default Quest Tracker', parent = 'on',
		desc = 'Hide the default quest tracker while this one is shown, so quests are not listed twice. Disabling this option brings it back.' },
	{ key = 'quietInstance', default = true, name = 'Keep Default Tracker In Instances', parent = 'quiet',
		desc = 'In dungeons, raids and battlegrounds, show the default tracker in place of this one. It displays stage objectives, timers and scores there.' },
	{ header = true, name = 'Size' },
	{ key = 'width', default = 260, min = 180, max = 500, step = 10, name = 'Width',
		desc = 'Width of the tracker.' },
	{ key = 'height', default = 450, min = 150, max = 1000, step = 25, name = 'Max Height',
		desc = 'Maximum height of the tracker. A longer list scrolls with the mouse wheel or the Scroll Tracker Up and Scroll Tracker Down key bindings.' },
	{ header = true, name = 'Position' },
	{ button = 'Unlock', name = 'Unlock Position', click = function() ns.Unlock() end,
		desc = 'Show a drag bar above the tracker so you can move it. Click again, or type /tracker lock, to lock it in place.' },
	{ button = 'Reset', name = 'Reset Position', click = function() ns.ResetPlace() end,
		desc = 'Move the tracker back to its default position under the minimap.' },
	{ header = true, name = 'Fading' },
	{ key = 'fadeCombat', default = false, name = 'Fade In Combat',
		desc = 'Fade the tracker while you are in combat.' },
	{ key = 'fadeIdle', default = false, name = 'Fade When Not Hovered',
		desc = 'Fade the tracker unless the mouse is over it or something in it has just changed.' },
	{ key = 'fadeTo', default = 35, min = 10, max = 90, step = 5, name = 'Faded Opacity',
		desc = 'Opacity of the tracker while it is faded, in percent.' },
	{ key = 'hideInstance', default = false, name = 'Hide In Instances',
		desc = 'Hide the tracker in dungeons, raids and battlegrounds, even when the default tracker is not kept there.' },

	-- the quests
	{ page = QUESTS, voice = 'So many jobs. Patchwerk does the near one first.' },
	{ page = QUESTS, header = true, name = 'Quest List' },
	{ page = QUESTS, key = 'quests', default = true, name = 'Show Quests',
		desc = 'List your tracked quests and their objectives.' },
	{ page = QUESTS, key = 'order', default = 'zone', name = 'Sort Order',
		choices = { { 'zone', 'By zone (current zone first)' }, { 'near', 'By distance' },
			{ 'ready', 'Completed first, then by zone' }, { 'short', 'Shortest Trip' }, { 'game', 'Default order' } },
		desc = 'How quests are sorted. Shortest Trip lists them in a short path: the nearest first, then each next quest nearest to the one before. It is worked out again when a quest is added, removed or completed. Route To Next Quest and Route To Previous Quest follow the order shown.' },
	{ page = QUESTS, key = 'readyGroup', default = true, name = 'Group Completed Quests',
		desc = 'Move quests that are ready to turn in to a separate group at the bottom of the list. Your tracked quests are not changed.' },
	{ page = QUESTS, header = true, name = 'Quest Details' },
	{ page = QUESTS, key = 'levels', default = true, name = 'Show Quest Level',
		desc = 'Show the quest level before its name.' },
	{ page = QUESTS, key = 'kinds', default = true, name = 'Show Quest Type',
		desc = 'Show the quest type after its name: elite, dungeon, raid, daily or group. Timed quests always show the time left.' },
	{ page = QUESTS, key = 'distance', default = true, name = 'Show Distance',
		desc = 'Show the distance to each quest, in yards.' },
	{ page = QUESTS, key = 'progress', default = true, name = 'Color Objectives By Progress',
		desc = 'Color counted objectives (4/10) from red through yellow to green as they fill.' },
	{ page = QUESTS, key = 'doneLines', default = true, name = 'Show Completed Objectives',
		desc = 'Keep completed objectives in the list, dimmed. When disabled, they are removed as soon as they are done.' },
	{ page = QUESTS, key = 'flash', default = true, name = 'Flash On Progress',
		desc = 'Briefly highlight a quest when its progress changes.' },
	{ page = QUESTS, header = true, name = 'Party' },
	{ page = QUESTS, key = 'party', default = true, name = 'Show Party Members On Quest',
		desc = 'Show which party members are on each quest.' },
	{ page = QUESTS, key = 'partyShare', default = true, name = 'Share Progress With Party', parent = 'party',
		desc = 'Send your quest progress (quest and percent complete) to party members who also use this addon, and show theirs. The game does not provide party progress, so this only works between players running the addon.' },
	{ page = QUESTS, header = true, name = 'Automation' },
	{ page = QUESTS, key = 'followNearest', default = false, name = 'Auto-Track Nearest Quest',
		desc = 'When no guide is active and you have not selected a quest or a list, automatically put the quest arrow on your nearest tracked quest.' },

	-- the guide
	{ page = GUIDE, voice = 'The clever book says where to go. Patchwerk reads the pictures.' },
	{ page = GUIDE, header = true, name = 'Guide Steps' },
	{ page = GUIDE, key = 'guide', default = true, name = 'Show Guide Steps',
		desc = 'Show the current step of your guide addon (RestedXP) above your quests, with the guide name and your progress.' },
	{ page = GUIDE, key = 'guideAhead', default = 3, min = 0, max = 8, step = 1, name = 'Upcoming Steps',
		desc = 'Number of upcoming steps shown below the current one.' },
	{ page = GUIDE, key = 'guideDone', default = false, name = 'Show Completed Lines',
		desc = 'Keep completed lines of the current step in the list, dimmed.' },
	{ page = GUIDE, key = 'guideSkip', default = true, name = 'Click To Skip Steps',
		desc = 'Click the current step to skip it, or an upcoming step to jump to it. /tracker back, or the Undo Skipped Guide Step key binding, undoes the last skip.' },
	{ page = GUIDE, key = 'guideItems', default = true, name = 'Show Guide Item Buttons',
		desc = 'Add buttons for items the current step uses (such as your hearthstone) to the quest item bar.' },
	{ page = GUIDE, key = 'guideHide', default = false, name = 'Hide RestedXP Window',
		desc = 'Hide the RestedXP guide window while the tracker shows the guide. RestedXP settings are not changed, and its arrow and item buttons stay visible.' },

	{ page = GUIDE, header = true, name = 'Focus' },
	{ page = GUIDE, key = 'focusBar', default = true, name = 'Show Focus Buttons',
		desc = 'Show a row of buttons at the top of the tracker, one for each route you can follow: Auto, your guide (RestedXP), the Dungeon Journal list, Quests and My Route. Click one to follow it; right-click the row for the same choices as a menu.' },
	{ page = GUIDE, header = true, name = 'My Route' },
	{ page = GUIDE, key = 'myRoute', default = true, name = 'Show My Route',
		desc = 'List My Route, your own stops in your own order, above your quests. Right-click a quest and choose Add To My Route to add it; drag the stops to reorder them, or right-click the heading to open the My Route window.' },

	-- item buttons, recipes, gathering, dungeons
	{ page = MORE, voice = 'Pockets, pots and flowers. All the small jobs.' },
	{ page = MORE, header = true, name = 'Quest Item Bar' },
	{ page = MORE, key = 'items', default = true, name = 'Show Quest Item Bar',
		desc = 'Show a bar of buttons for usable quest items next to the tracker, nearest quest first. You can bind a key to the first button. The bar does not update during combat.' },
	{ page = MORE, key = 'itemSize', default = 32, min = 20, max = 56, step = 2, name = 'Button Size', parent = 'items',
		desc = 'Size of the item buttons.' },
	{ page = MORE, key = 'itemSide', default = 'left', name = 'Position', choices = { { 'left', 'Left of the tracker' }, { 'right', 'Right of the tracker' } },
		desc = 'Which side of the tracker the item bar is on.' },
	{ page = MORE, header = true, name = 'Recipes' },
	{ page = MORE, key = 'recipes', default = true, name = 'Show Tracked Recipes',
		desc = 'List tracked profession recipes with their reagents and how many you have.' },
	{ page = MORE, header = true, name = 'Gathering' },
	{ page = MORE, key = 'gather', default = true, name = 'Show Gathering Nodes',
		desc = 'List the nearest herb and ore nodes you have gathered before. Click one to route to it. Requires Thread (Routes).' },
	{ page = MORE, key = 'gatherMost', default = 4, min = 1, max = 8, step = 1, name = 'Nodes Shown', parent = 'gather',
		desc = 'Number of node types listed, nearest first.' },
	{ page = MORE, header = true, name = 'Dungeons' },
	{ page = MORE, key = 'dungeon', default = false, name = 'Show Dungeon Objectives (Experimental)',
		desc = 'Show the current stage and objectives of a dungeon or scenario. Not yet tested in a dungeon. This tracker is shown in instances only while Keep Default Tracker In Instances is disabled.' },

	-- how it looks
	{ page = LOOK, voice = 'Patchwerk picked the colours himself. You can pick again.' },
	{ page = LOOK, header = true, name = 'Size' },
	{ page = LOOK, key = 'scale', default = 100, min = 60, max = 160, step = 5, name = 'Scale',
		desc = 'Scale of the tracker, in percent.' },
	{ page = LOOK, key = 'fontSize', default = 12, min = 9, max = 20, step = 1, name = 'Font Size',
		desc = 'Font size of the tracker text.' },
	{ page = LOOK, key = 'back', default = 25, min = 0, max = 90, step = 5, name = 'Background Opacity',
		desc = 'Opacity of the tracker background, in percent. 0 hides it.' },
	{ page = LOOK, header = true, name = 'Colors' },
	{ page = LOOK, key = 'titleByLevel', default = true, name = 'Color Quests By Difficulty',
		desc = 'Color quest names by difficulty (grey, green, yellow, orange, red). When disabled, all names use the color below.' },
	{ page = LOOK, key = 'lookTitle', colour = true, default = 'ffffd200', name = 'Quest Name Color',
		desc = 'Color of quest names when they are not colored by difficulty.' },
	{ page = LOOK, key = 'lookHeader', colour = true, default = 'ffd6a35b', name = 'Header Color',
		desc = 'Color of section headers and their underline.' },
	{ page = LOOK, key = 'lookGuide', colour = true, default = 'ff5fe0c8', name = 'Guide Color',
		desc = 'Color of the current guide step and the guide progress bar.' },
	{ page = LOOK, key = 'lookLine', colour = true, default = 'ffd8d8d8', name = 'Objective Color',
		desc = 'Color of objectives that are not yet complete.' },
	{ page = LOOK, key = 'lookDone', colour = true, default = 'ff6fbf73', name = 'Completed Color',
		desc = 'Color of completed objectives and of quests that are ready to turn in.' },
}

---------------------------------------------------------------------------
-- /tracker
---------------------------------------------------------------------------
local function Help()
	ns.Print('Quest tracker commands:')
	ns.Print('  /tracker on, /tracker off: enable or disable the tracker')
	ns.Print('  /tracker move: unlock to drag;  /tracker lock: lock in place;  /tracker reset: reset position')
	ns.Print('  /tracker fold: collapse or expand all sections')
	ns.Print('  /tracker next, /tracker previous: route to the next or previous quest in the list')
	ns.Print('  /tracker back: undo the last guide step you skipped by clicking')
	ns.Print('  /tracker route: open or close the My Route window')
	ns.Print('  /tracker config: open the options')
	ns.Print('  In the list: click a quest to route to it, shift-click for details, right-click for more.')
end

SLASH_PATCHWERKFOREVER_TRACKER1 = '/tracker'
SLASH_PATCHWERKFOREVER_TRACKER2 = '/pftr'
SlashCmdList.PATCHWERKFOREVER_TRACKER = function(text)
	local word = (text or ''):lower():match('^%s*(%S*)')
	if word == 'on' or word == 'off' then
		ns.Set('on', word == 'on')
		ns.Print(word == 'on' and 'Tracker enabled.' or 'Tracker disabled. The default quest tracker is back.')
	elseif word == 'move' or word == 'unlock' then
		ns.Try('move', ns.Unlock, true)
	elseif word == 'lock' then
		ns.Try('lock', ns.Unlock, false)
	elseif word == 'reset' then
		ns.Try('reset', ns.ResetPlace)
	elseif word == 'fold' or word == 'toggle' then
		ns.Try('fold', ns.Fold)
	elseif word == 'next' then
		ns.Try('the next quest', ns.Cycle, 1)
	elseif word == 'previous' or word == 'prev' then
		ns.Try('the previous quest', ns.Cycle, -1)
	elseif word == 'back' then
		ns.Try('back', ns.GuideBack)
	elseif word == 'route' then
		ns.Try('My Route', ns.OpenRoute)
	elseif word == 'config' or word == 'settings' or word == 'options' then
		if not ns.OpenSettings() then
			ns.Print('Options are under Options > AddOns > Patchwerk Forever > Thread: Tracker.')
		end
	else
		Help()
	end
end

-- For key and gamepad bindings (Bindings.xml). The second is a click on a button of the item strip
-- (Items.lua): using an item is something only a button of the game's secure kind may do.
BINDING_HEADER_PATCHWERKFOREVER_TRACKER = ns.TITLE
BINDING_NAME_PATCHWERKFOREVER_TRACKER_FOLD = 'Collapse / Expand Tracker'
_G['BINDING_NAME_CLICK PatchwerkForeverTrackerNearestItem:LeftButton'] = 'Use Nearest Quest Item'
BINDING_NAME_PATCHWERKFOREVER_TRACKER_NEXT = 'Route To Next Quest'
BINDING_NAME_PATCHWERKFOREVER_TRACKER_PREV = 'Route To Previous Quest'
BINDING_NAME_PATCHWERKFOREVER_TRACKER_SCROLL_UP = 'Scroll Tracker Up'
BINDING_NAME_PATCHWERKFOREVER_TRACKER_SCROLL_DOWN = 'Scroll Tracker Down'
BINDING_NAME_PATCHWERKFOREVER_TRACKER_BACK = 'Undo Skipped Guide Step'
BINDING_NAME_PATCHWERKFOREVER_TRACKER_ROUTE_ADD = 'Add Quest To My Route'
BINDING_NAME_PATCHWERKFOREVER_TRACKER_ROUTE_UP = 'Move My Route Stop Up'
BINDING_NAME_PATCHWERKFOREVER_TRACKER_ROUTE_DOWN = 'Move My Route Stop Down'
BINDING_NAME_PATCHWERKFOREVER_TRACKER_ROUTE_OPEN = 'Open My Route'
function PatchwerkForever_Thread_Tracker_Fold() ns.Try('fold', ns.Fold) end
function PatchwerkForever_Thread_Tracker_Next() ns.Try('the next quest', ns.Cycle, 1) end
function PatchwerkForever_Thread_Tracker_Previous() ns.Try('the previous quest', ns.Cycle, -1) end
function PatchwerkForever_Thread_Tracker_ScrollUp() ns.Try('scrolling', ns.Scroll, -1) end
function PatchwerkForever_Thread_Tracker_ScrollDown() ns.Try('scrolling', ns.Scroll, 1) end
function PatchwerkForever_Thread_Tracker_Back() ns.Try('back', ns.GuideBack) end
function PatchwerkForever_Thread_Tracker_RouteAdd() ns.Try('My Route', ns.RouteAddAtHand) end
function PatchwerkForever_Thread_Tracker_RouteUp() ns.Try('My Route', ns.RouteNudge, -1) end
function PatchwerkForever_Thread_Tracker_RouteDown() ns.Try('My Route', ns.RouteNudge, 1) end
function PatchwerkForever_Thread_Tracker_RouteOpen() ns.Try('My Route', ns.OpenRoute) end
