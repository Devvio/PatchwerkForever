-- Tracker (Thread): the game's own tracker, and RestedXP's window, kept quiet while ours is shown.
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
--     ours may not. Ours steps aside while it is (Frame.lua), so there is one list there too.
--   * Switching ours off, or unticking the setting, puts back what was changed: its alpha as it was,
--     and the mouse on the pieces it was taken from.
--
-- RestedXP's guide window (RXPFrame) is treated the same way, when you ask for it (a setting, off to
-- begin with) and only while our list shows the guide's steps. None of RestedXP's settings is
-- changed; its arrow and its own item buttons are other frames and are left alone.
--
-- If EllesmereUI's quest tracker is running too, there are two trackers on screen. That is said once;
-- which to keep is yours to choose.
local ADDON, ns = ...
if not ns.linked then return end

local DEEP = 12               -- how far down into a frame its pieces are looked for
local SOON = 0.5              -- seconds after the game changes its list before the pieces are gone over again
local AGAIN = 3               -- seconds between two looks at whether something made a quiet frame visible again

local function InInstance()
	return IsInInstance and IsInInstance() and true or false
end

local targets = {
	{ name = 'ObjectiveTrackerFrame', wanted = function()
		if ns.questsBroken then return false end              -- (ours cannot list the quests: Frame.lua)
		if not (ns.Get('on') and ns.Get('quiet')) then return false end
		if ns.Get('quietInstance') and InInstance() then return false end
		return true
	end },
	{ name = 'RXPFrame', wanted = function()
		if not (ns.Get('on') and ns.Get('guide') and ns.Get('guideHide')) then return false end
		if ns.AsideInInstance() then return false end             -- (ours is not shown there: Frame.lua)
		local info = ns.Base.Guides:Read(0, 'rxp')         -- (its own window: only while its own guide is listed)
		return type(info) == 'table' and info.index ~= nil
	end },
}
for _, target in ipairs(targets) do
	target.quieted, target.touched = false, {}
end

local waiting = false         -- something was wanted in a fight
local planned = false

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

local function ApplyTo(target)
	local frame = rawget(_G, target.name)
	if type(frame) ~= 'table' or type(frame.SetAlpha) ~= 'function' then return end
	if target.wanted() then
		if not target.quieted then
			target.wasAlpha = frame.GetAlpha and frame:GetAlpha() or 1
			target.quieted = true
		end
		frame:SetAlpha(0)
		Each(frame, function(piece)
			if type(piece.EnableMouse) == 'function' and type(piece.IsMouseEnabled) == 'function'
				and not Untouchable(piece) and piece:IsMouseEnabled() then
				piece:EnableMouse(false)
				target.touched[piece] = true
			end
		end, 0)
	elseif target.quieted then
		target.quieted = false
		frame:SetAlpha(target.wasAlpha or 1)
		for piece in pairs(target.touched) do
			if not Untouchable(piece) then piece:EnableMouse(true) end
		end
		target.touched = {}
	end
end

local function Apply()
	if InCombatLockdown() then
		waiting = true
		return
	end
	waiting = false
	for _, target in ipairs(targets) do
		ns.Try('quietening ' .. target.name, ApplyTo, target)
	end
end

local function Soon()
	if planned then return end
	planned = true
	C_Timer.After(SOON, function()
		planned = false
		ns.Try('quietening', Apply)
	end)
end
ns.QuietSoon = Soon

-- (for the checks) whether the game's tracker is quiet now; or, with a name, that frame
function ns.Quiet(name)
	for _, target in ipairs(targets) do
		if target.name == (name or 'ObjectiveTrackerFrame') then return target.quieted end
	end
	return false
end

for _, event in ipairs({ 'ZONE_CHANGED_NEW_AREA', 'QUEST_WATCH_LIST_CHANGED', 'QUEST_LOG_UPDATE',
	'QUEST_ACCEPTED', 'QUEST_REMOVED', 'PLAYER_REGEN_ENABLED' }) do
	ns.Try('listening for ' .. event, ns.On, event, Soon)
end
-- At login and after each loading screen: at once, so the game's tracker is not seen beside ours for
-- the half second Soon waits, and again after it for the pieces the game lays out later.
for _, event in ipairs({ 'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD' }) do
	ns.Try('listening for ' .. event, ns.On, event, function()
		ns.Try('quietening', Apply)
		Soon()
	end)
end
ns.OnSetting(function(key)
	if key == 'on' or key == 'quiet' or key == 'quietInstance' or key == 'guide' or key == 'guideHide' or key == 'hideInstance' then
		ns.Try('quietening', Apply)
	end
end)

-- Something else may make a quiet frame visible again (its own addon redrawing it), or the guide
-- may start or stop: looked at now and then.
C_Timer.NewTicker(AGAIN, function()
	if InCombatLockdown() then return end
	for _, target in ipairs(targets) do
		local frame = rawget(_G, target.name)
		if type(frame) == 'table' and type(frame.GetAlpha) == 'function' then
			local ok, want = pcall(target.wanted)
			if ok and (want ~= target.quieted or (want and frame:GetAlpha() > 0)) then
				return Soon()
			end
		end
	end
end)

-- Two trackers at once: said once for the account.
ns.On('PLAYER_LOGIN', function()
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
	if not (ns.Get('on') and loaded and loaded('EllesmereUIQuestTracker')) then return end
	local db = ns.Saved()
	if db.toldOfOther then return end
	db.toldOfOther = true
	ns.Print('EllesmereUI\'s quest tracker is also enabled, so you will see two trackers. Disable one of them in the addon list (or type /tracker off to keep EllesmereUI\'s).')
end)
