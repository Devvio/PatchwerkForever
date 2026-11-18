---------------------------------------------------------------
-- Patchwerk Forever: the base
---------------------------------------------------------------
-- What every part of Patchwerk Forever shares: the saved data,
-- the settings and their page, /patchwerk, and the art. It does
-- nothing by itself. Its parts are addons of their own, on two
-- tracks:
--     Stitch  what is sewn onto other people's addons, fixes
--             and additions (Stitch (Console Port), ...)
--     Thread  our own tools (Thread (Routes), ...): Tools.lua
-- A Stitch part needs this base and joins it as its first file
-- loads:
--
--     local addonName, ns = ...;
--     PatchwerkForever:Link(addonName, ns, 1)
--
-- after which ns:AddSetting, ns:GetSaved, ns:RegisterFix and the
-- rest below are there for its files, as they were when all of
-- it was one addon.
--
-- PatchwerkForeverDB = {
--     settings = { [key] = value }, -- every setting, of every part
--     [fixID]  = { ... },           -- each fix's own saved data
--     told     = { [addon] = true } -- parts the player was told are missing
-- }

local addonName, ns = ...;

-- API: raised when something is added that a part may need (2: the guides service, Guides.lua;
-- 3: the gathering service, Gather.lua, and a guide step's items and skipping)
local P = { API = 5, Fixes = {}, Parts = {}, Settings = { list = {}, byKey = {} } };
PatchwerkForever = P;
ns.P = P;

local GOLD = '|cffd6a35b';

-- The parts there are, and the addon each one is for. A part that
-- is not listed here still joins and works: this list is only for
-- telling the player about one that is missing.
P.Family = {
	{ addon = 'PatchwerkForever_Stitch_ConsolePort',  name = 'Patchwerk Forever: Stitch (Console Port)',  needs = 'ConsolePort', what = 'Console Port' };
	{ addon = 'PatchwerkForever_Stitch_MelloUI',      name = 'Patchwerk Forever: Stitch (MelloUI)',       needs = 'MelloUI',     what = 'MelloUI' };
	{ addon = 'PatchwerkForever_Stitch_MelloUIRoute', name = 'Patchwerk Forever: Stitch (MelloUI Route)', needs = 'MelloUI',     what = "MelloUI's Route" };
	{ addon = 'PatchwerkForever_Stitch_DungeonJournal', name = 'Patchwerk Forever: Stitch (Dungeon Journal)', needs = 'ForeverDungeonJournal', what = 'Dungeon Journal' };
};

local savedLoaded = false;
local loading;          -- the part whose files are being run, from its Link to its ADDON_LOADED
local loadHooks = {};   -- (WhenLoaded) waiting for the saved variables, or for the part to finish loading
local fresh = {};       -- settings added since the last ones were given their saved values
local loginHooks = {};

-- None of these use self: a part calls them through its own table
-- (ns:GetSaved, env:AddSetting), which Link filled with them.

-- @return saved : the fix's saved table, or nil before saved variables load
function P:GetSaved(fixID)
	if not savedLoaded then return end;
	PatchwerkForeverDB[fixID] = PatchwerkForeverDB[fixID] or {};
	return PatchwerkForeverDB[fixID];
end

-- fn run once the saved variables are in and the part asking has run
-- all its files, in the order asked; at once when that is long past
function P:WhenLoaded(fn)
	if ( savedLoaded and not loading ) then
		return fn();
	end
	loadHooks[#loadHooks + 1] = fn;
end

function P:Print(...)
	print(GOLD .. 'Patchwerk|r', ...)
end

---------------------------------------------------------------
-- Settings
---------------------------------------------------------------
-- All of them are Patchwerk's own, kept in the base's saved
-- variable and shown on its page of the game's options
-- (Settings.lua): none live in the settings of the addons the
-- parts work with. A part adds its settings as its files load,
-- so the page only lists what is installed and applies.
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
local handlers = {};

function P:AddSetting(def)
	assert(type(def.key) == 'string' and def.default ~= nil, 'A setting needs a key and a default.')
	if P.Settings.byKey[def.key] then return end;
	P.Settings.byKey[def.key] = def;
	def.part = loading or addonName;
	tinsert(P.Settings.list, def)
	fresh[#fresh + 1] = def.key;
end

-- the value as saved, else its default (before the saved variables are in: the default)
function P:GetSetting(key)
	local def = P.Settings.byKey[key];
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

-- fn(value, initial) when the setting changes, and once as the part
-- that added it finishes loading (initial = true) so what was set up
-- with the default follows the saved value
function P:OnSetting(key, fn)
	handlers[key] = handlers[key] or {};
	tinsert(handlers[key], fn)
end

function P:FireSetting(key, initial)
	local value = P:GetSetting(key);
	for _, fn in ipairs(handlers[key] or {}) do
		local ok, err = pcall(fn, value, initial);
		if not ok then
			P:Print(('The %s setting could not be applied: %s'):format(key, tostring(err)))
		end
	end
end

-- @return true when it was taken
function P:SetSetting(key, value)
	local def = P.Settings.byKey[key];
	if not ( def and savedLoaded and type(value) == type(def.default) ) then
		return false;
	end
	if ( type(value) == 'number' ) then
		value = math.max(def.min or value, math.min(def.max or value, value));
	end
	if ( P:GetSetting(key) == value ) then
		return true;
	end
	PatchwerkForeverDB.settings[key] = value;
	P:FireSetting(key, false)
	return true;
end

-- the setting whose key is this, whatever its case (for typed commands)
function P:FindSetting(text)
	text = tostring(text or ''):lower();
	for _, def in ipairs(P.Settings.list) do
		if ( def.key:lower() == text ) then
			return def;
		end
	end
end

local function OnOff(value)
	if ( type(value) == 'boolean' ) then
		return value and 'on' or 'off';
	end
	return tostring(value);
end
P.OnOff = OnOff;

---------------------------------------------------------------
-- Fix registry
---------------------------------------------------------------
-- @param info : {
--     name    = display name (string)
--     addon   = the addon it fixes (string)
--     status  = function returning a one-line state (optional)
--     command = function(args) for /patchwerk <id> <args> (optional)
-- }
function P:RegisterFix(fixID, info)
	info.id = fixID;
	info.part = loading or addonName;
	P.Fixes[#P.Fixes + 1] = info;
end

local function FindFix(fixID)
	for _, fix in ipairs(P.Fixes) do
		if ( fix.id:lower() == fixID ) then
			return fix;
		end
	end
end

---------------------------------------------------------------
-- Parts
---------------------------------------------------------------
local function Meta(name, field)   -- (ns.Meta below)
	local get = ( C_AddOns and C_AddOns.GetAddOnMetadata ) or GetAddOnMetadata;
	if not get then return end;
	local ok, value = pcall(get, name, field);
	if ( ok and type(value) == 'string' and value ~= '' ) then
		return value;
	end
end

ns.Meta = Meta;

local function IsLoaded(name)
	local loaded = ( C_AddOns and C_AddOns.IsAddOnLoaded ) or IsAddOnLoaded;
	if not loaded then return false end;
	local ok, value = pcall(loaded, name);
	return ok and value and true or false;
end

-- whether the addon is in the AddOns folder at all (ticked or not)
local function IsInstalled(name)
	if ( C_AddOns and C_AddOns.DoesAddOnExist ) then
		local ok, value = pcall(C_AddOns.DoesAddOnExist, name);
		if ok then
			return value and true or false;
		end
	end
	local info = ( C_AddOns and C_AddOns.GetAddOnInfo ) or GetAddOnInfo;
	if not info then return true end;   -- (cannot tell: say nothing)
	local ok, found, _, _, _, reason = pcall(info, name);
	if not ok then return true end;
	return found ~= nil and reason ~= 'MISSING';
end
ns.IsLoaded, ns.IsInstalled = IsLoaded, IsInstalled;

-- The picture an addon of the family shows in the game's addon list
-- (the IconTexture line of its TOC), for use anywhere a texture goes.
function P:Icon(name)
	return Meta(name or addonName, 'IconTexture');
end

-- the same, as a piece of text for a chat line or a label
function P:IconText(name, size)
	local icon = P:Icon(name);
	return icon and ('|T%s:%d|t '):format(icon, size or 0) or '';
end

P.SHARED = { 'GetSaved', 'WhenLoaded', 'Print', 'AddSetting', 'GetSetting', 'OnSetting', 'FireSetting',
	'SetSetting', 'FindSetting', 'RegisterFix', 'OnOff', 'Icon', 'IconText', 'OpenSettings' };

function P:OpenSettings()
	return ns.OpenSettings and ns.OpenSettings() or false;
end

-- Joins a part to the base. Called by the part's first file.
-- @param name : the part's addon name
-- @param env  : the part's own table (the second of its ...)
-- @param api  : the P.API the part was written for
-- @return true when it joined; false when this base is too old for it
function P:Link(name, env, api)
	if not ( type(name) == 'string' and type(env) == 'table' and ( tonumber(api) or 1 ) <= P.API ) then
		return false;
	end
	for _, key in ipairs(P.SHARED) do
		env[key] = P[key];   -- (none of them use self, so env:GetSaved() is the base's)
	end
	env.linked, env.Base = true, P;
	P.Parts[#P.Parts + 1] = { addon = name, title = Meta(name, 'Title') or name, version = Meta(name, 'Version') };
	loading = name;
	return true;
end

-- fn run at login, when every addon ticked in the list has loaded
function ns.AtLogin(fn)
	loginHooks[#loginHooks + 1] = fn;
end

---------------------------------------------------------------
-- Loading
---------------------------------------------------------------
-- A part's files run, then its ADDON_LOADED comes: only then are
-- its WhenLoaded functions run and its settings given their saved
-- values, as it was when every file belonged to one addon.
local function Flush()
	local hooks = loadHooks;
	loadHooks = {};
	for _, fn in ipairs(hooks) do
		local ok, err = pcall(fn);
		if not ok then
			P:Print('A part failed while loading: ' .. tostring(err))
		end
	end
	local keys = fresh;
	fresh = {};
	for _, key in ipairs(keys) do
		P:FireSetting(key, true)
	end
end

P:AddSetting({
	key     = 'baseTellMissing';
	default = true;
	section = 'Patchwerk Forever';
	name = 'Notify About Missing Addons';
	desc = 'Print a one-time chat message when an addon Patchwerk Forever has fixes for is enabled, but the Stitch addon with those fixes is not installed.';
})

-- Since 2.0.0 the fixes are addons of their own. Someone who had
-- them all in one, or who adds Console Port later, is told once
-- for each which part to get; a part that is installed but
-- unticked was switched off on purpose and is not mentioned.
local function TellMissing()
	if not P:GetSetting('baseTellMissing') then return end;
	local told = P:GetSaved('told');
	for _, part in ipairs(P.Family) do
		if ( not told[part.addon] and IsLoaded(part.needs) and not IsInstalled(part.addon) ) then
			told[part.addon] = true;
			P:Print(('%s is running. The fixes and additions for it are a separate addon: |cffffffff%s|r.')
				:format(part.what, part.name))
		end
	end
end

local Loader = CreateFrame('Frame')
Loader:RegisterEvent('ADDON_LOADED')
Loader:RegisterEvent('PLAYER_LOGIN')
Loader:SetScript('OnEvent', function(self, event, name)
	if ( event == 'ADDON_LOADED' ) then
		if ( name == addonName ) then
			PatchwerkForeverDB = PatchwerkForeverDB or {};
			PatchwerkForeverDB.settings = PatchwerkForeverDB.settings or {};
			savedLoaded = true;
			Flush()
		elseif ( name == loading ) then
			loading = nil;
			if savedLoaded then
				Flush()
			end
		end
		return;
	end
	self:UnregisterEvent('PLAYER_LOGIN')
	loading = nil;
	Flush()
	local hooks = loginHooks;
	loginHooks = {};
	hooks[#hooks + 1] = TellMissing;
	for _, fn in ipairs(hooks) do
		local ok, err = pcall(fn);
		if not ok then
			P:Print('Something failed at login: ' .. tostring(err))
		end
	end
end)

---------------------------------------------------------------
-- /patchwerk
---------------------------------------------------------------
-- /patchwerk set <key> <on|off|number>
local function SetCommand(args)
	local key, text = args:match('^(%S+)%s+(%S+)$');
	local def = key and P:FindSetting(key);
	if not def then
		P:Print('settings (/patchwerk set <name> on|off):')
		for _, known in ipairs(P.Settings.list) do
			print(('  %s: %s  |cff808080%s|r'):format(known.key, OnOff(P:GetSetting(known.key)), known.name or ''))
		end
		return;
	end
	local value;
	if ( type(def.default) == 'number' ) then
		value = tonumber(text);
	elseif ( text == 'on' or text == 'off' ) then
		value = ( text == 'on' );
	end
	if ( value == nil or not P:SetSetting(def.key, value) ) then
		return P:Print(type(def.default) == 'number' and 'Give a number.' or 'Give on or off.');
	end
	P:Print(('%s: %s'):format(def.key, OnOff(P:GetSetting(def.key))))
end

local function ListParts()
	print(('%s%sPatchwerk Forever|r %s. Its parts:'):format(P:IconText(addonName, 14), GOLD, Meta(addonName, 'Version') or ''))
	for _, part in ipairs(P.Parts) do
		print(('  %s%s%s|r %s%s'):format(P:IconText(part.addon, 14), GOLD, part.title, part.version or '',
			part.slash and ('  |cff808080' .. part.slash .. '|r') or ''))
	end
	if ( #P.Parts == 0 ) then
		print('  none. This is the base: the Stitch and Thread addons are downloads of their own.')
	end
	for _, part in ipairs(P.Family) do
		if ( IsLoaded(part.needs) and not IsLoaded(part.addon) ) then
			print(('  |cff808080%s (for %s): %s|r'):format(part.name, part.what,
				IsInstalled(part.addon) and 'installed, not switched on' or 'not installed'))
		end
	end
end

SLASH_PATCHWERK1 = '/patchwerk';
SlashCmdList.PATCHWERK = function(msg)
	local word, args = (msg or ''):trim():match('^(%S*)%s*(.-)$');
	word = word:lower();
	if ( word == 'config' or word == 'settings' or word == 'options' ) then
		if not P:OpenSettings() then
			P:Print('The settings page could not be opened here. /patchwerk set lists the settings.')
		end
		return;
	elseif ( word == 'set' ) then
		return SetCommand(args:lower());
	end
	local fix = word ~= '' and FindFix(word);
	if ( fix and fix.command ) then
		return fix.command(args)
	end

	ListParts()
	if ( #P.Fixes > 0 ) then
		P:Print('Active fixes:')
		for _, known in ipairs(P.Fixes) do
			local status = known.status and known.status();
			print(('  %s%s|r (%s) for %s%s'):format(GOLD, known.name, known.id, known.addon,
				status and (': '..status) or ''))
		end
	end
	print('  /patchwerk config opens the settings. /patchwerk <id> for a fix\'s own commands.')
end
