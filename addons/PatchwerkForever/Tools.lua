local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Tools: what one of our own tools gets from the base
---------------------------------------------------------------
-- Patchwerk Forever has two tracks. Stitch is what is sewn onto
-- other people's addons (Core.lua: Link). Thread is our own
-- tools, which stand on nothing but this base. A tool has many
-- settings, of more kinds than a tick box, pages of its own under
-- Patchwerk Forever's in the game's options, and a saved variable
-- of its own. It joins in its first file:
--
--     local addonName, ns = ...;
--     PatchwerkForever:Tool(addonName, ns, {
--         api    = 1,                 -- the P.API it was written for
--         name   = 'Routes',          -- what its chat lines begin with
--         colour = 'ff7fd4ff',        -- and in what colour
--         saved  = 'MyToolDB',        -- its SavedVariables, as its TOC names it
--         page   = 'Thread: Routes',  -- its first page under Patchwerk Forever's
--         slash  = '/thread',         -- shown in /patchwerk
--     })
--
-- and then finds on its own table (ns):
--     ns.Print(...)             a chat line
--     ns.Try(label, fn, ...)    runs fn; an error is said in chat, not thrown
--     ns.On(event, fn)          fn(...) on a game event;  ns.frame
--     ns.Get(key), ns.Set(key, value), ns.OnSetting(fn(key, value))
--     ns.RGB('ffRRGGBB')        red, green, blue, each 0 to 1
--     ns.OpenSettings()         opens its first page
--     ns.linked                 true
--
-- The tool lists its settings in ns.settings, one entry a setting
-- in the order they are shown. What control each gets follows
-- from the entry:
--     default true/false                  a tick box
--     default a number, min, max, step    a slider (percent = true: its value shown as "100%")
--     choices = { { value, label }, ... } a list to pick from
--     colour = true                       a colour (default 'ffRRGGBB')
--     button = 'text', click = function   a button; no value
--     header = true                       a heading; no value
--     (a Reset To Defaults button is put at the foot of the tool's first page by the base)
--     voice  = 'words'                    what Patchwerk says at the top of the page it names
--                                         (the first page says the TOC's X-Patchwerk-Voice line)
--     page   = 'name'                     the page it is on (none: the tool's first)
--     parent = key                        greyed out while that tick box is off
-- Values are kept in <saved>.settings.

P.Tools = {};

local colours = {};
local function RGB(hex)
	local c = colours[hex];
	if not c then
		local r, g, b = tostring(hex):match('(%x%x)(%x%x)(%x%x)$');   -- (the last six: 'RRGGBB' will do too)
		c = r and { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255 } or { 1, 1, 1 };
		colours[hex] = c;
	end
	return c[1], c[2], c[3];
end

-- @return true when it joined; false when this base is too old for it
function P:Tool(name, env, spec)
	if not ( type(name) == 'string' and type(env) == 'table' and type(spec) == 'table'
	and type(spec.saved) == 'string' and ( tonumber(spec.api) or 1 ) <= P.API ) then
		return false;
	end
	local tool = { addon = name, env = env, spec = spec, pages = {}, controls = {}, proxies = {} };
	local prefix = ('|c%s%s|r: '):format(spec.colour or 'ffd6a35b', spec.name or name);

	function env.Print(...)
		local chat = DEFAULT_CHAT_FRAME;
		if chat then
			chat:AddMessage(prefix .. strjoin(' ', tostringall(...)))
		end
	end

	-- Each different error is said once, and at most three under one label: many handlers share a
	-- label (every handler of one event, every settings watcher), so one per label would hide the rest.
	local reported, counts = {}, {};
	function env.Try(label, fn, ...)
		local ok, a, b, c = pcall(fn, ...);
		if ok then return a, b, c end;
		local key, said = label .. '\n' .. tostring(a), counts[label] or 0;
		if ( not reported[key] and said < 3 ) then
			reported[key], counts[label] = true, said + 1;
			env.Print('A problem in ' .. label .. ' (reported once): ' .. tostring(a))
		end
		return nil;
	end

	env.RGB = RGB;

	-- settings
	local byKey;
	local function Def(key)
		if not byKey then
			if ( type(env.settings) ~= 'table' ) then return nil end;   -- (not listed yet)
			byKey = {};
			for _, def in ipairs(env.settings) do
				if def.key then byKey[def.key] = def end;
			end
		end
		return byKey[key];
	end
	local function Saved()
		local db = _G[spec.saved];
		if ( type(db) ~= 'table' ) then
			db = {};
			_G[spec.saved] = db;
		end
		db.settings = db.settings or {};
		return db;
	end
	local watchers = {};

	function env.Get(key)
		local db = _G[spec.saved];
		local saved = type(db) == 'table' and db.settings;
		local value = saved and saved[key];
		if ( value == nil ) then
			local def = Def(key);
			return def and def.default;
		end
		return value;
	end

	function env.Set(key, value)
		if not Def(key) then return end;
		Saved().settings[key] = value;
		for _, fn in ipairs(watchers) do
			env.Try('a setting', fn, key, value)
		end
	end

	function env.OnSetting(fn)
		watchers[#watchers + 1] = fn;
	end

	-- events
	local frame = CreateFrame('Frame');
	local handlers = {};
	env.frame = frame;

	function env.On(event, fn)
		if not handlers[event] then
			handlers[event] = {};
			frame:RegisterEvent(event)
		end
		table.insert(handlers[event], fn)
	end

	frame:SetScript('OnEvent', function(_, event, ...)
		local list = handlers[event];
		if list then
			for _, fn in ipairs(list) do
				env.Try(event, fn, ...)
			end
		end
	end)

	env.On('ADDON_LOADED', function(loaded)
		if ( loaded == name ) then
			Saved()
		end
	end)

	function env.OpenSettings()
		return ns.OpenToolSettings(tool);
	end

	env.linked, env.Base = true, P;
	P.Tools[#P.Tools + 1] = tool;
	P.Parts[#P.Parts + 1] = { addon = name, title = ns.Meta(name, 'Title') or name, version = ns.Meta(name, 'Version'),
		slash = spec.slash };
	return true;
end

---------------------------------------------------------------
-- A tool's pages
---------------------------------------------------------------
-- Made by Settings.lua at login, under Patchwerk Forever's own
-- page: the tool's first page, and one for each `page` its
-- settings name. Every control is made on its own, so one the
-- client will not make leaves the rest standing.
local function Page(category, tool, name)
	name = name or tool.spec.page or tool.addon;
	local page = tool.pages[name];
	if not page then
		local sub, layout = Settings.RegisterVerticalLayoutSubcategory(category, name);
		page = { category = sub, layout = layout };
		tool.pages[name] = page;
		-- every page opens with its name, the tool's picture and a line in Patchwerk's voice (Look.lua)
		local voice = tool.voices and tool.voices[name];
		if not tool.first then
			tool.first = page;
			ns.pageOf[tool.addon] = sub;
			voice = voice or ns.VoiceOf(tool.addon);
		end
		pcall(ns.PlaceIntro, page, name, tool.addon, voice)
	end
	return page;
end

-- A slider's options: its range, and its value shown at its right, as "100%" for a setting marked
-- percent = true (a Stitch's setting from AddSetting may be marked so too).
local function Percent(value) return ('%d%%'):format(math.floor(value + 0.5)) end
function ns.SliderOptions(def)
	local options = Settings.CreateSliderOptions(def.min or 0, def.max or 1, def.step or 1);
	if ( options.SetLabelFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label ) then
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, def.percent and Percent or nil)
	end
	return options;
end

-- puts something that is not a setting (a heading, a button) on a page
local function Place(page, initializer)
	ns.PlaceOn(page, initializer)
end

local function Control(category, tool, def)
	local env = tool.env;
	if def.voice then return end;                    -- (said in the page's intro: Page)
	local page = Page(category, tool, def.page);
	local shown = ns.Sentence(def.name);
	if def.header then
		ns.PlaceHeader(page, shown)
		return;
	end
	if def.button then
		if CreateSettingsButtonInitializer then
			Place(page, CreateSettingsButtonInitializer(shown, def.button, def.click, def.desc, true))
		end
		return;
	end
	local key = def.key;
	local variable = tool.addon .. '_' .. ( key:gsub('%.', '_') );
	local function get() return env.Get(key) end
	local function set(value) env.Set(key, value) end
	local control, setting;
	if def.colour then
		if not Settings.CreateColorSwatch then return end;
		setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.String, shown,
			def.default, get, set);
		control = Settings.CreateColorSwatch(page.category, setting, def.desc);
	elseif def.choices then
		if not ( Settings.CreateDropdown and Settings.CreateControlTextContainer ) then return end;
		setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.String, shown,
			def.default, get, set);
		local function Options()
			local container = Settings.CreateControlTextContainer();
			for _, choice in ipairs(def.choices) do
				container:Add(choice[1], choice[2])
			end
			return container:GetData();
		end
		control = Settings.CreateDropdown(page.category, setting, Options, def.desc);
	elseif ( type(def.default) == 'number' ) then
		if not ( Settings.CreateSlider and Settings.CreateSliderOptions ) then return end;
		setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.Number, shown,
			def.default, get, set);
		local options = ns.SliderOptions(def);
		control = Settings.CreateSlider(page.category, setting, options, def.desc);
	else
		setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.Boolean, shown,
			def.default, get, set);
		control = Settings.CreateCheckbox(page.category, setting, def.desc);
	end
	tool.controls[key] = control;
	tool.proxies[key] = setting;
	-- a setting that only matters while a tick box is on: greyed out with it
	local parent = def.parent and tool.controls[def.parent];
	if ( parent and control and control.SetParentInitializer ) then
		local parentKey = def.parent;
		control:SetParentInitializer(parent, function() return env.Get(parentKey) == true end)
	end
end

-- Puts every setting of a tool back to its default. Each goes through the game's own setting where
-- there is one, so an options page that is open shows the new value at once.
local function Reset(tool)
	local env = tool.env;
	for _, def in ipairs(type(env.settings) == 'table' and env.settings or {}) do
		if ( def.key and def.default ~= nil ) then
			local proxy = tool.proxies[def.key];
			if not ( proxy and proxy.SetValue and pcall(proxy.SetValue, proxy, def.default) ) then
				env.Set(def.key, def.default)
			end
		end
	end
	env.Print('Options reset to defaults.')
end

-- Asks first, with the game's own yes-or-no box.
local function AskReset(tool)
	local show, dialogs = rawget(_G, 'StaticPopup_Show'), rawget(_G, 'StaticPopupDialogs');
	if not ( type(show) == 'function' and type(dialogs) == 'table' ) then return Reset(tool) end;
	if not dialogs.PATCHWERKFOREVER_RESET then
		dialogs.PATCHWERKFOREVER_RESET = {
			text = 'Reset all %s options, on all of its pages, to their defaults?\n\nPositions and saved data are not changed.',
			button1 = rawget(_G, 'YES') or 'Yes', button2 = rawget(_G, 'NO') or 'No',
			OnAccept = function(_, which) if which then which.env.Try('resetting the options', Reset, which) end end,
			timeout = 0, whileDead = true, hideOnEscape = true,
		};
	end
	show('PATCHWERKFOREVER_RESET', tool.spec.page or tool.addon, nil, tool)
end

-- @param category : Patchwerk Forever's own page, not yet handed to the game
function ns.BuildToolPages(category)
	if not Settings.RegisterVerticalLayoutSubcategory then return end;
	for _, tool in ipairs(P.Tools) do
		local env = tool.env;
		tool.voices = {};
		for _, def in ipairs(type(env.settings) == 'table' and env.settings or {}) do
			if def.voice then tool.voices[def.page or tool.spec.page or tool.addon] = def.voice end;
		end
		env.Try('the options page', Page, category, tool)   -- (its first page, even when it has nothing on it)
		for _, def in ipairs(type(env.settings) == 'table' and env.settings or {}) do
			env.Try('the options page (' .. tostring(def.name) .. ')', Control, category, tool, def)
		end
		-- at the foot of its first page: every setting back to its default
		env.Try('the options page (reset)', function()
			if not ( tool.first and CreateSettingsButtonInitializer ) then return end;
			ns.PlaceHeader(tool.first, 'Defaults')
			Place(tool.first, CreateSettingsButtonInitializer('Reset To Defaults', 'Reset', function() AskReset(tool) end,
				'Reset every option of this addon, on all of its pages, to its default. Positions and saved data are not changed.', true))
		end)
	end
end

function ns.OpenToolSettings(tool)
	local page = tool.first;
	if not ( page and page.category and Settings and Settings.OpenToCategory ) or InCombatLockdown() then
		return false;
	end
	return ( pcall(function() Settings.OpenToCategory(page.category:GetID()) end) );
end
