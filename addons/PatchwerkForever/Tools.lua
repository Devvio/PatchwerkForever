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
--         name   = 'Thread',          -- what its chat lines begin with
--         colour = 'ff7fd4ff',        -- and in what colour
--         saved  = 'MyToolDB',        -- its SavedVariables, as its TOC names it
--         page   = 'Thread: Routes',  -- its first page under Patchwerk Forever's
--         slash  = '/thread',         -- shown in /patchwerk
--     })
--
-- and then finds on its own table (ns):
--     ns.Print(...)             a chat line
--     ns.Try(label, fn, ...)    runs fn; an error is said once, not thrown
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
--     default a number, min, max, step    a slider
--     choices = { { value, label }, ... } a list to pick from
--     colour = true                       a colour (default 'ffRRGGBB')
--     button = 'text', click = function   a button; no value
--     header = true                       a heading; no value
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
	local tool = { addon = name, env = env, spec = spec, pages = {}, controls = {} };
	local prefix = ('|c%s%s|r: '):format(spec.colour or 'ffd6a35b', spec.name or name);

	function env.Print(...)
		local chat = DEFAULT_CHAT_FRAME;
		if chat then
			chat:AddMessage(prefix .. strjoin(' ', tostringall(...)))
		end
	end

	local reported = {};
	function env.Try(label, fn, ...)
		local ok, a, b, c = pcall(fn, ...);
		if ok then return a, b, c end;
		if not reported[label] then
			reported[label] = true;
			env.Print('a problem in ' .. label .. ' (reported once): ' .. tostring(a))
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
		tool.first = tool.first or page;
	end
	return page;
end

-- puts something that is not a setting (a heading, a button) on a page
local function Place(page, initializer)
	if Settings.RegisterInitializer then
		Settings.RegisterInitializer(page.category, initializer)
	elseif ( page.layout and page.layout.AddInitializer ) then
		page.layout:AddInitializer(initializer)
	end
end

local function Control(category, tool, def)
	local env = tool.env;
	local page = Page(category, tool, def.page);
	if def.header then
		if CreateSettingsListSectionHeaderInitializer then
			Place(page, CreateSettingsListSectionHeaderInitializer(def.name))
		end
		return;
	end
	if def.button then
		if CreateSettingsButtonInitializer then
			Place(page, CreateSettingsButtonInitializer(def.name, def.button, def.click, def.desc, true))
		end
		return;
	end
	local key = def.key;
	local variable = tool.addon .. '_' .. ( key:gsub('%.', '_') );
	local function get() return env.Get(key) end
	local function set(value) env.Set(key, value) end
	local control;
	if def.colour then
		if not Settings.CreateColorSwatch then return end;
		local setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.String, def.name,
			def.default, get, set);
		control = Settings.CreateColorSwatch(page.category, setting, def.desc);
	elseif def.choices then
		if not ( Settings.CreateDropdown and Settings.CreateControlTextContainer ) then return end;
		local setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.String, def.name,
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
		local setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.Number, def.name,
			def.default, get, set);
		local options = Settings.CreateSliderOptions(def.min, def.max, def.step);
		if ( options.SetLabelFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label ) then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end
		control = Settings.CreateSlider(page.category, setting, options, def.desc);
	else
		local setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.Boolean, def.name,
			def.default, get, set);
		control = Settings.CreateCheckbox(page.category, setting, def.desc);
	end
	tool.controls[key] = control;
	-- a setting that only matters while a tick box is on: greyed out with it
	local parent = def.parent and tool.controls[def.parent];
	if ( parent and control and control.SetParentInitializer ) then
		local parentKey = def.parent;
		control:SetParentInitializer(parent, function() return env.Get(parentKey) == true end)
	end
end

-- @param category : Patchwerk Forever's own page, not yet handed to the game
function ns.BuildToolPages(category)
	if not Settings.RegisterVerticalLayoutSubcategory then return end;
	for _, tool in ipairs(P.Tools) do
		local env = tool.env;
		env.Try('the options page', Page, category, tool)   -- (its first page, even when it has nothing on it)
		for _, def in ipairs(type(env.settings) == 'table' and env.settings or {}) do
			env.Try('the options page (' .. tostring(def.name) .. ')', Control, category, tool, def)
		end
	end
end

function ns.OpenToolSettings(tool)
	local page = tool.first;
	if not ( page and page.category and Settings and Settings.OpenToCategory ) or InCombatLockdown() then
		return false;
	end
	return ( pcall(function() Settings.OpenToCategory(page.category:GetID()) end) );
end
