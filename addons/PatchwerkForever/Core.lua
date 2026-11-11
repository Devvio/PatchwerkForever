---------------------------------------------------------------
-- Patchwerk Forever
---------------------------------------------------------------
-- Fixes and additions for other addons. Each one lives in a folder
-- named after the addon it is for, and registers itself here only
-- when that addon is loaded.
--
-- PatchwerkForeverDB = {
--     settings = { [key] = value }, -- every setting, see below
--     [fixID]  = { ... },           -- each fix's own saved data
-- }

local addonName, ns = ...;

ns.Fixes = {};

local savedLoaded = false;
local loadHooks = {};

-- @return saved : the fix's saved table, or nil before saved variables load
function ns:GetSaved(fixID)
	if not savedLoaded then return end;
	PatchwerkForeverDB[fixID] = PatchwerkForeverDB[fixID] or {};
	return PatchwerkForeverDB[fixID];
end

-- fn run once the saved variables are in, in the order asked
function ns:WhenLoaded(fn)
	if savedLoaded then
		return fn();
	end
	loadHooks[#loadHooks + 1] = fn;
end

function ns:Print(...)
	print('|cffd6a35bPatchwerk|r', ...)
end

---------------------------------------------------------------
-- Settings
---------------------------------------------------------------
-- All of them are Patchwerk's own, kept in its saved variable and
-- shown on its own page of the game's options (Settings.lua): none
-- live in the settings of the addons it works with. A fix adds its
-- settings as its files load, so the page only lists what applies.
--
-- @param def : {
--     key     = id (string)
--     default = boolean or number
--     name    = label (string)
--     desc    = tooltip (string)
--     section = heading it is listed under (string)
--     parent  = key of the setting it depends on (optional)
--     min, max, step = for a number
-- }
ns.Settings = { list = {}, byKey = {} };

local handlers = {};

function ns:AddSetting(def)
	assert(type(def.key) == 'string' and def.default ~= nil, 'A setting needs a key and a default.')
	if self.Settings.byKey[def.key] then return end;
	self.Settings.byKey[def.key] = def;
	tinsert(self.Settings.list, def)
end

-- the value as saved, else its default (before the saved variables are in: the default)
function ns:GetSetting(key)
	local def = self.Settings.byKey[key];
	if not def then
		return nil;
	end
	local value;
	if savedLoaded then
		value = PatchwerkForeverDB.settings[key];
	end
	if ( type(value) ~= type(def.default) ) then
		value = def.default;
	end
	return value;
end

-- fn(value, initial) when the setting changes, and once as the saved
-- variables come in (initial = true) so what was set up with the
-- default follows the saved value
function ns:OnSetting(key, fn)
	handlers[key] = handlers[key] or {};
	tinsert(handlers[key], fn)
end

function ns:FireSetting(key, initial)
	local value = self:GetSetting(key);
	for _, fn in ipairs(handlers[key] or {}) do
		local ok, err = pcall(fn, value, initial);
		if not ok then
			self:Print(('The %s setting could not be applied: %s'):format(key, tostring(err)))
		end
	end
end

-- @return true when it was taken
function ns:SetSetting(key, value)
	local def = self.Settings.byKey[key];
	if not ( def and savedLoaded and type(value) == type(def.default) ) then
		return false;
	end
	if ( type(value) == 'number' ) then
		value = math.max(def.min or value, math.min(def.max or value, value));
	end
	if ( self:GetSetting(key) == value ) then
		return true;
	end
	PatchwerkForeverDB.settings[key] = value;
	self:FireSetting(key, false)
	return true;
end

-- the setting whose key is this, whatever its case (for typed commands)
function ns:FindSetting(text)
	text = tostring(text or ''):lower();
	for _, def in ipairs(self.Settings.list) do
		if ( def.key:lower() == text ) then
			return def;
		end
	end
end

---------------------------------------------------------------
-- Loading
---------------------------------------------------------------
local Loader = CreateFrame('Frame')
Loader:RegisterEvent('ADDON_LOADED')
Loader:SetScript('OnEvent', function(self, _, name)
	if ( name ~= addonName ) then return end;
	self:UnregisterEvent('ADDON_LOADED')
	PatchwerkForeverDB = PatchwerkForeverDB or {};
	PatchwerkForeverDB.settings = PatchwerkForeverDB.settings or {};
	savedLoaded = true;
	for _, fn in ipairs(loadHooks) do
		local ok, err = pcall(fn);
		if not ok then
			ns:Print('A part failed while loading: ' .. tostring(err))
		end
	end
	loadHooks = {};
	for _, def in ipairs(ns.Settings.list) do
		ns:FireSetting(def.key, true)
	end
end)

---------------------------------------------------------------
-- Fix registry
---------------------------------------------------------------
-- @param info : {
--     name    = display name (string)
--     addon   = the addon it fixes (string)
--     status  = function returning a one-line state (optional)
--     command = function(args) for /patchwerk <id> <args> (optional)
-- }
function ns:RegisterFix(fixID, info)
	info.id = fixID;
	self.Fixes[#self.Fixes + 1] = info;
end

local function FindFix(fixID)
	for _, fix in ipairs(ns.Fixes) do
		if ( fix.id:lower() == fixID ) then
			return fix;
		end
	end
end

local function OnOff(value)
	if ( type(value) == 'boolean' ) then
		return value and 'on' or 'off';
	end
	return tostring(value);
end
ns.OnOff = OnOff;

-- /patchwerk set <key> <on|off|number>
local function SetCommand(args)
	local key, text = args:match('^(%S+)%s+(%S+)$');
	local def = key and ns:FindSetting(key);
	if not def then
		ns:Print('settings (/patchwerk set <name> on|off):')
		for _, known in ipairs(ns.Settings.list) do
			print(('  %s: %s  |cff808080%s|r'):format(known.key, OnOff(ns:GetSetting(known.key)), known.name or ''))
		end
		return;
	end
	local value;
	if ( type(def.default) == 'number' ) then
		value = tonumber(text);
	elseif ( text == 'on' or text == 'off' ) then
		value = ( text == 'on' );
	end
	if ( value == nil or not ns:SetSetting(def.key, value) ) then
		return ns:Print(type(def.default) == 'number' and 'Give a number.' or 'Give on or off.');
	end
	ns:Print(('%s: %s'):format(def.key, OnOff(ns:GetSetting(def.key))))
end

SLASH_PATCHWERK1 = '/patchwerk';
SlashCmdList.PATCHWERK = function(msg)
	local word, args = (msg or ''):trim():match('^(%S*)%s*(.-)$');
	word = word:lower();
	if ( word == 'config' or word == 'settings' or word == 'options' ) then
		if not ( ns.OpenSettings and ns:OpenSettings() ) then
			ns:Print('The settings page could not be opened here. /patchwerk set lists the settings.')
		end
		return;
	elseif ( word == 'set' ) then
		return SetCommand(args:lower());
	end
	local fix = word ~= '' and FindFix(word);
	if ( fix and fix.command ) then
		return fix.command(args)
	end

	if ( #ns.Fixes == 0 ) then
		return ns:Print('No fixes are active: none of the addons they fix are loaded.')
	end
	ns:Print('Active fixes:')
	for _, fix in ipairs(ns.Fixes) do
		local status = fix.status and fix.status();
		print(('  |cffd6a35b%s|r (%s) for %s%s'):format(fix.name, fix.id, fix.addon,
			status and (': '..status) or ''))
	end
	print('  /patchwerk config opens the settings. /patchwerk <id> for a fix\'s own commands.')
end
