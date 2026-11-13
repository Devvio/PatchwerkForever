-- Thread (Tracker): the game's own tracker, kept quiet while ours is shown.
--
-- With both shown every quest is on screen twice. The game's tracker (ObjectiveTrackerFrame) is not
-- hidden or moved: hiding it sets off the game's own layout of the frames round it, run from an
-- addon's hand, and that is how "action blocked" errors begin. It is made invisible (its alpha set
-- to nothing) and the pieces of it that take the mouse are told not to, so a click where it stands
-- goes through to the world.
--
--   * Pieces the game protects (the buttons that use a quest's item) are not touched: an addon may
--     not, in a fight, and should not out of one. They stay where they were, unseen.
--   * Nothing of it is touched in a fight. What was wanted then is done when the fight is over.
--   * In a dungeon, a raid or a battleground it is let back (a setting): it shows things there that
--     ours does not.
--   * Switching ours off, or unticking the setting, puts back what was changed: its alpha as it was,
--     and the mouse on the pieces it was taken from.
--
-- If EllesmereUI's quest tracker is running too, there are two trackers on screen. That is said once;
-- which to keep is yours to choose.
local ADDON, ns = ...
if not ns.linked then return end

local DEEP = 12               -- how far down into the game's tracker its pieces are looked for
local SOON = 0.5              -- seconds after the game changes its list before its pieces are gone over again

local quieted, wasAlpha = false, nil
local touched = {}            -- [piece] = true: the mouse was taken from it by us
local waiting = false         -- something was wanted in a fight
local planned = false

local function Wanted()
	if not (ns.Get('on') and ns.Get('quiet')) then return false end
	if ns.Get('quietInstance') and IsInInstance and IsInInstance() then return false end
	return true
end

local function Each(piece, fn, depth)
	fn(piece)
	if depth >= DEEP or type(piece.GetChildren) ~= 'function' then return end
	for _, child in ipairs({ piece:GetChildren() }) do
		if type(child) == 'table' then Each(child, fn, depth + 1) end
	end
end

local function Untouchable(piece)
	if type(piece.IsForbidden) == 'function' and piece:IsForbidden() then return true end
	if type(piece.IsProtected) == 'function' and piece:IsProtected() then return true end
	return false
end

local function Apply()
	local tracker = rawget(_G, 'ObjectiveTrackerFrame')
	if type(tracker) ~= 'table' or type(tracker.SetAlpha) ~= 'function' then return end
	if InCombatLockdown() then
		waiting = true
		return
	end
	waiting = false
	if Wanted() then
		if not quieted then
			wasAlpha = tracker.GetAlpha and tracker:GetAlpha() or 1
			quieted = true
		end
		tracker:SetAlpha(0)
		Each(tracker, function(piece)
			if type(piece.EnableMouse) == 'function' and type(piece.IsMouseEnabled) == 'function'
				and not Untouchable(piece) and piece:IsMouseEnabled() then
				piece:EnableMouse(false)
				touched[piece] = true
			end
		end, 0)
	elseif quieted then
		quieted = false
		tracker:SetAlpha(wasAlpha or 1)
		for piece in pairs(touched) do
			if not Untouchable(piece) then piece:EnableMouse(true) end
		end
		touched = {}
	end
end

local function Soon()
	if planned then return end
	planned = true
	C_Timer.After(SOON, function()
		planned = false
		ns.Try('quietening the game\'s tracker', Apply)
	end)
end

-- (for the checks) whether the game's tracker is quiet now
function ns.Quiet()
	return quieted
end

for _, event in ipairs({ 'PLAYER_ENTERING_WORLD', 'ZONE_CHANGED_NEW_AREA', 'QUEST_WATCH_LIST_CHANGED', 'QUEST_LOG_UPDATE',
	'QUEST_ACCEPTED', 'QUEST_REMOVED', 'PLAYER_REGEN_ENABLED' }) do
	ns.Try('listening for ' .. event, ns.On, event, Soon)
end
ns.OnSetting(function(key)
	if key == 'on' or key == 'quiet' or key == 'quietInstance' then
		ns.Try('quietening the game\'s tracker', Apply)
	end
end)

-- Two trackers at once: said once for the account.
ns.On('PLAYER_LOGIN', function()
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
	if not (ns.Get('on') and loaded and loaded('EllesmereUIQuestTracker')) then return end
	local db = ns.Saved()
	if db.toldOfOther then return end
	db.toldOfOther = true
	ns.Print('EllesmereUI\'s quest tracker is running too, so you will see two. Untick one of them in the game\'s addon list (or /tracker off to keep EllesmereUI\'s).')
end)
