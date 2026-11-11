local addonName, ns = ...;
---------------------------------------------------------------
-- Settings page
---------------------------------------------------------------
-- Patchwerk's own page in the game's options (Options > AddOns),
-- listing the settings the loaded fixes added (ns:AddSetting), a
-- heading per section. Loaded last, so every fix has added its own.
-- Each control is a proxy onto ns:GetSetting / ns:SetSetting: the
-- values stay in PatchwerkForeverDB.settings, changed here or with
-- /patchwerk set.

local TITLE = 'Patchwerk Forever';

local function Tooltip(def)
	if ( def.desc and def.note ) then
		return def.desc .. '\n\n' .. def.note;
	end
	return def.desc or def.note;
end

local function Build()
	if not ( Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting
	and Settings.CreateCheckbox and Settings.RegisterAddOnCategory and Settings.VarType ) then
		return;
	end
	if ( #ns.Settings.list == 0 ) then
		return;   -- (none of the addons it is for are loaded)
	end
	local category, layout = Settings.RegisterVerticalLayoutCategory(TITLE);
	local controls, section = {}, nil;
	for _, def in ipairs(ns.Settings.list) do
		if ( def.section ~= section ) then
			section = def.section;
			if ( section and CreateSettingsListSectionHeaderInitializer ) then
				local header = CreateSettingsListSectionHeaderInitializer(section);
				if Settings.RegisterInitializer then
					Settings.RegisterInitializer(category, header)
				elseif ( layout and layout.AddInitializer ) then
					layout:AddInitializer(header)
				end
			end
		end
		local key, isNumber = def.key, type(def.default) == 'number';
		local setting = Settings.RegisterProxySetting(category, addonName .. '_' .. key,
			isNumber and Settings.VarType.Number or Settings.VarType.Boolean,
			def.name or key, def.default,
			function() return ns:GetSetting(key) end,
			function(value) ns:SetSetting(key, value) end);
		local control;
		if isNumber then
			local options = Settings.CreateSliderOptions(def.min or 0, def.max or 1, def.step or 1);
			if ( options.SetLabelFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label ) then
				options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
			end
			control = Settings.CreateSlider(category, setting, options, Tooltip(def));
		else
			control = Settings.CreateCheckbox(category, setting, Tooltip(def));
		end
		controls[key] = control;
		-- (a setting that only matters while another is on: greyed with it)
		local parent = def.parent and controls[def.parent];
		if ( parent and control and control.SetParentInitializer ) then
			local parentKey = def.parent;
			control:SetParentInitializer(parent, function() return ns:GetSetting(parentKey) == true end)
		end
	end
	Settings.RegisterAddOnCategory(category)
	ns.settingsCategory = category;
end

function ns:OpenSettings()
	local category = self.settingsCategory;
	if not ( category and Settings and Settings.OpenToCategory ) or InCombatLockdown() then
		return false;
	end
	local ok = pcall(function() Settings.OpenToCategory(category:GetID()) end);
	return ok;
end

---------------------------------------------------------------
-- Settings from before the page
---------------------------------------------------------------
-- Before 1.0.0 the settings sat in Console Port's own (its Forever
-- Gamepad and Patchwork Route sections), or in each fix's saved
-- data without it. Carried over once, and taken out of Console
-- Port's saved settings, where they would be left behind.
local function OldKey(key)
	local route = key:match('^route(%u.*)$');
	if route then
		return 'patchRoute' .. route, route:sub(1, 1):lower() .. route:sub(2);
	end
	return key;
end

local function CarryOver()
	local db = PatchwerkForeverDB;
	if db.settingsCarried then return end;
	db.settingsCarried = true;
	local consolePort = { rawget(_G, 'ConsolePortCharacterSettings'), rawget(_G, 'ConsolePortSettings') };
	local routeOld = type(db.Route) == 'table' and type(db.Route.settings) == 'table' and db.Route.settings or {};
	for _, def in ipairs(ns.Settings.list) do
		local key = def.key;
		local oldVar, oldRoute = OldKey(key);
		local value;
		for i = 1, 2 do
			local source = consolePort[i];
			if ( type(source) == 'table' and source[oldVar] ~= nil ) then
				if ( value == nil ) then
					value = source[oldVar];
				end
				source[oldVar] = nil;
			end
		end
		if ( value == nil and oldRoute ) then
			value = routeOld[oldRoute];
		end
		if ( key == 'melloRouteOnly' and type(db.MelloUI) == 'table' and db.MelloUI.routeOnly ~= nil ) then
			value = db.MelloUI.routeOnly;
			db.MelloUI.routeOnly = nil;
		end
		if ( db.settings[key] == nil and type(value) == type(def.default) ) then
			db.settings[key] = value;
		end
	end
	if ( type(db.Route) == 'table' ) then
		db.Route.settings = nil;
	end
end

ns:WhenLoaded(function()
	CarryOver()
	local ok, err = pcall(Build);
	if not ok then
		ns:Print('The settings page could not be made (' .. tostring(err) .. '). /patchwerk set lists the settings.')
	end
end)
