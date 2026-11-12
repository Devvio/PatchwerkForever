local _, ns = ...;
local R = ns.Route;
if not R then return end;
---------------------------------------------------------------
-- Route: buttons, bindings and /patchwerk route
---------------------------------------------------------------
-- Each action is a button a key can click, so it can be bound in
-- Console Port (its binding list and its rings) or put in a macro
-- (/click PatchwerkRouteQuestRun). The shortcut's own button is
-- secure and made with its suggestion (Travel.lua).

local function Unblock()
	if R.Blocks:Undo() then
		R:Print(('The last blocked spot is taken back. %d left.'):format(R.Blocks:Count()))
	else
		R:Print('No blocked spot to take back.')
	end
end

local function Block()
	local ok, why = R.Blocks:MarkAhead();
	if ok then
		R:Print('The trail just ahead of you is marked blocked. Step off the trail and Route plans another way; paths you taught it through here are cut at your next login. (Undo: /patchwerk route unblock)')
	else
		R:Print(why or 'Could not mark the trail here.')
	end
end

local function Why()
	local lines, why = R.Blocks:Describe(300);
	if not lines then
		return R:Print(why or 'Nothing to say about the trail here.');
	end
	R:Print('the trail ahead of you:')
	for _, line in ipairs(lines) do
		print('  ' .. line)
	end
	print("  A path you taught Route can be forgotten: stand on it and type /patchwerk route forget. Any stretch can be marked blocked: /patchwerk route block.")
end

local function Forget(radius)
	radius = math.min(math.max(tonumber(radius) or 60, 10), 500);
	if ( R.Learned and R.Learned:ForgetHere(radius) ) then
		R:Print(('The paths you taught Route within %d yards of here are forgotten at your next login or /reload.'):format(radius))
	else
		R:Print('Could not note this place.')
	end
end

local actions = {
	{	id = 'PatchwerkRouteBlock', button = 'PatchwerkRouteBlock';
		name = 'Route: Mark Trail Ahead Blocked';
		desc = "Marks the trail just ahead of you as blocked, for a stretch you shouldn't follow (a drop off a cliff).";
		run  = R.Blocks and Block;
	};
	{	id = 'PatchwerkRouteQuestRun', button = 'PatchwerkRouteQuestRun';
		name = 'Route: Quest Run';
		desc = 'Starts a run through your tracked quests in a short order, or stops the one under way.';
		run  = R.Trips and function() R.Trips:ToggleRun() end;
	};
	{	id = 'PatchwerkRouteNextStop', button = 'PatchwerkRouteNextStop';
		name = 'Route: Next Quest Run Stop';
		desc = 'Moves a quest run on to its next stop.';
		run  = R.Trips and function() R.Trips:NextStop() end;
	};
	{	id = 'PatchwerkRouteUnblock', button = 'PatchwerkRouteUnblock';
		name = 'Route: Undo Blocked Spot';
		desc = 'Takes back the spot marked blocked last.';
		run  = R.Blocks and Unblock;
	};
	{	id = 'PatchwerkRouteTravel', button = 'PatchwerkRouteTravel';
		name = 'Route: Use Suggested Shortcut';
		desc = 'Uses the hearthstone or teleport Route suggested. Does nothing when none is suggested.';
		made = R.Travel ~= nil;   -- (the secure button itself)
	};
};

for _, action in ipairs(actions) do
	if ( action.run and not _G[action.button] ) then
		local button = CreateFrame('Button', action.button, UIParent);
		button:SetScript('OnClick', function() R.Try(action.name, action.run) end)
		action.made = true;
	end
end

-- Console Port's binding list, when Console Port is here. (Its
-- LinkEnv hands back its database; the table given is not kept.)
local consolePort;
if ( rawget(_G, 'CPAPI') and CPAPI.LinkEnv and rawget(_G, 'ConsolePort') ) then
	local ok, _, _, _, db = pcall(CPAPI.LinkEnv, 'PatchwerkForever_Stitch_MelloUIRoute', {});
	consolePort = ok and type(db) == 'table' and db or nil;
end
local Bindings = consolePort and consolePort.Bindings;
if ( type(Bindings) == 'table' and Bindings.Special and Bindings.Custom and Bindings.Macroable ) then
	for _, action in ipairs(actions) do
		if action.made then
			local binding = ('CLICK %s:LeftButton'):format(action.button);
			Bindings.Custom[action.id] = binding;
			Bindings.Macroable[action.id] = true;
			tinsert(Bindings.Special, { binding = binding, name = action.name, desc = action.desc })
		end
	end
end

---------------------------------------------------------------
-- /patchwerk route
---------------------------------------------------------------
local function OnOff(value)
	if ( type(value) == 'boolean' ) then
		return value and 'on' or 'off';
	end
	return tostring(value);
end

local function Status()
	R:Print('settings (/patchwerk config, or /patchwerk route set <name> on|off):')
	local keys = {};
	for key in pairs(R.Defaults) do
		keys[#keys + 1] = key;
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		print(('  %s: %s'):format(key, OnOff(R:Get(key))))
	end
	if R.Blocks then
		print(('  blocked spots: %d (block, unblock, blocks clear)'):format(R.Blocks:Count()))
		print('  why: what the trail ahead is made of; forget [yards]: forget the paths you taught Route here')
	end
	local saved = R:GetSaved();
	if ( saved and R.Travel ) then
		local bind = saved.binds[R:Character()];
		local teleports = 0;
		for _ in pairs(saved.teleports) do
			teleports = teleports + 1;
		end
		local suggestion = R.Travel:Suggestion();
		print(('  hearthstone: %s; teleports known: %d; suggested now: %s (shortcut)'):format(
			bind and bind.name or 'not seen yet (use it or set it once)', teleports, suggestion and suggestion.label or 'none'))
	end
	if R.Trips then
		print(('  quest run: %s (run, next, stop)'):format(R.Trips:RunActive() and 'under way' or 'none'))
	end
end

local function Command(args)
	local word, rest = ( args or '' ):lower():match('^(%S*)%s*(.-)$');
	if ( word == 'run' and R.Trips ) then
		R.Trips:StartRun()
	elseif ( word == 'stop' and R.Trips ) then
		R.Trips:StopRun()
	elseif ( word == 'next' and R.Trips ) then
		R.Trips:NextStop()
	elseif ( word == 'unblock' and R.Blocks ) then
		Unblock()
	elseif ( word == 'block' and R.Blocks ) then
		Block()
	elseif ( word == 'why' and R.Blocks ) then
		Why()
	elseif ( word == 'forget' ) then
		Forget(rest)
	elseif ( word == 'blocks' and rest == 'clear' and R.Blocks ) then
		R:Print(('%d blocked spots forgotten.'):format(R.Blocks:Clear()))
	elseif ( word == 'shortcut' and R.Travel ) then
		R.Travel:Look()
		R:Print('Looking for a shortcut; it is said when one is worth it.')
	elseif ( word == 'set' ) then
		local key, value = rest:match('^(%S+)%s+(%S+)$');
		local name;
		for known in pairs(R.Defaults) do
			if ( key and known:lower() == key ) then
				name = known;
			end
		end
		if not name then
			return R:Print('No such setting. /patchwerk route lists them.');
		end
		if ( type(R.Defaults[name]) == 'number' ) then
			value = tonumber(value);
		elseif ( value == 'on' or value == 'off' ) then
			value = ( value == 'on' );
		else
			value = nil;
		end
		if ( value == nil ) then
			return R:Print('Give on or off (a number for previewSteps).');
		end
		R:Set(name, value)
		R:Print(('%s: %s'):format(name, OnOff(R:Get(name))))
	else
		Status()
	end
end

ns:RegisterFix('route', {
	name    = 'MelloUI Route additions';
	addon   = 'MelloUI_Route';
	command = function(args) R.Try('/patchwerk route', Command, args) end;
	status  = function()
		return ('%d blocked spots; /patchwerk route for settings and commands'):format(R.Blocks and R.Blocks:Count() or 0);
	end;
})
