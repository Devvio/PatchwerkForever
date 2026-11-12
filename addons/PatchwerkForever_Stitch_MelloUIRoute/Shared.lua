local _, ns = ...;
local MelloUI = _G.MelloUI;
local M = MelloUI and MelloUI.GetModule and MelloUI:GetModule('Route');
if not ( ns.linked and M and type(M.Ground) == 'table' and M.CurrentRoute and M.Where and M.WhenReady ) then return end;
---------------------------------------------------------------
-- MelloUI Route: shared
---------------------------------------------------------------
-- Additions to MelloUI's Route, all from outside: nothing of
-- MelloUI's is edited, and its road data is never read here. Each
-- addition is a file of its own with a switch of its own.
--
-- Its settings are Patchwerk's own (the base's), listed on its page of
-- the game's options under MelloUI Route; R:Get('warmup') reads the
-- setting routeWarmup.
--
-- PatchwerkForeverDB.Route = {
--     blocks    = { { cont, x, y, r, dx, dy, at, n }, ... },
--     binds     = { [character] = { cont, x, y, name } },
--     teleports = { [spellID] = { cont, x, y, name } },
--     forget    = { { cont, x, y, r }, ... } asked to be forgotten at the next login,
--     learnPaused = true while Route's learning is held off by us,
-- }

local R = { M = M, MelloUI = MelloUI };
ns.Route = R;

local SECTION = 'MelloUI Route';

local function Key(key)
	return 'route' .. key:sub(1, 1):upper() .. key:sub(2);
end

R.Defaults = {};

for _, def in ipairs({
	{	key  = 'warmup';
		name = 'Ready Roads At Login';
		desc = "Loads MelloUI's road data behind the loading screen and builds its road map straight after login, so the first route appears sooner.";
	};
	{	key  = 'preferRoads';
		name = 'Prefer Roads';
		desc = 'Routes keep to roads and paths unless a shortcut across open ground is clearly shorter. Fewer trails over ridges and through fences.';
		note = 'Takes full effect after a reload.';
	};
	{	key  = 'avoidWater';
		name = 'Avoid Swimming';
		desc = 'Routes go round water unless swimming is much shorter.';
	};
	{	key  = 'safeLearning';
		name = 'Learn Only Real Paths';
		desc = "Stops Route from learning a path while you drop off a ledge, swim, fly or run as a ghost, so it doesn't send you back that way.";
	};
	{	key  = 'cityStreets';
		name = 'Keep To City Streets';
		desc = "In the capitals Route uses only MelloUI's own walked streets, with their lifts and trams: nothing is learned from you there, and what was is forgotten at login.";
		note = 'Stops trails that lead off Thunder Bluff where you once jumped or fell.';
	};
	{	key  = 'blocked';
		name = 'Learn Blocked Spots';
		desc = "Notices when you can't follow the trail and marks that spot as blocked for every character. Shortcuts and paths you taught Route avoid it from then on.";
		note = 'Undo the last one with the Route: Undo Blocked Spot binding or /patchwerk route unblock.';
	};
	{	key  = 'travel';
		name = 'Suggest Hearthstone And Teleports';
		desc = 'Tells you when your hearthstone or a teleport you have used before would get you to the destination clearly sooner.';
		note = 'Use it with the Route: Use Suggested Shortcut binding.';
	};
	{	key  = 'guidePreview';
		name = 'Show Next Guide Steps';
		desc = 'On the world map and the minimap, a fainter trail from the current guide step on through the next few steps.';
	};
	{	key  = 'previewSteps', default = 3, min = 1, max = 5, step = 1, parent = 'guidePreview';
		name = 'Guide Steps Ahead';
		desc = 'How many steps past the current one are shown.';
	};
	{	key  = 'notify';
		name = 'Route Messages';
		desc = 'Chat messages when a spot is marked blocked, a shortcut is suggested or a quest run changes.';
	};
}) do
	if ( def.default == nil ) then
		def.default = true;
	end
	R.Defaults[def.key] = def.default;
	def.key, def.section, def.parent = Key(def.key), SECTION, def.parent and Key(def.parent);
	ns:AddSetting(def)
end

function R:GetSaved()
	local saved = ns:GetSaved('Route');
	if saved then
		saved.blocks    = saved.blocks    or {};
		saved.binds     = saved.binds     or {};
		saved.teleports = saved.teleports or {};
	end
	return saved;
end

function R:Get(key)
	return ns:GetSetting(Key(key));
end

-- fn run when the setting changes, and once as the saved settings come in
function R:OnSetting(key, fn)
	ns:OnSetting(Key(key), function() self.Try('setting ' .. key, fn) end)
end

function R:Set(key, value)
	if ( self.Defaults[key] == nil ) then
		return false;
	end
	return ns:SetSetting(Key(key), value);
end

function R:Print(...)
	ns:Print('|cff9b8cffRoute|r', ...)
end

function R:Say(...)
	if self:Get('notify') then
		self:Print(...)
	end
end

-- An addition must never break Route: its own errors are caught,
-- and each kind said once so it can be reported.
local reported = {};
function R.Try(label, fn, ...)
	local ok, a, b, c = pcall(fn, ...);
	if ok then
		return a, b, c;
	end
	if not reported[label] then
		reported[label] = true;
		ns:Print('|cff9b8cffRoute|r', ('%s failed and was skipped: %s'):format(label, tostring(a)))
	end
end

function R.Dist(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by;
	return math.sqrt(dx * dx + dy * dy);
end

-- the player's place in Route's yards: cont, x, y (nil where the game gives none)
function R:Where()
	local ok, cont, x, y = pcall(M.Where, M);
	if ( ok and cont and x and y ) then
		return cont, x, y;
	end
end

function R:Character()
	local name, realm = UnitName('player'), GetRealmName();
	return ('%s-%s'):format(tostring(name), tostring(realm));
end

-- whether Route is on and its settings are there
function R:Active()
	return M.isEnabled and type(M.db) == 'table';
end
