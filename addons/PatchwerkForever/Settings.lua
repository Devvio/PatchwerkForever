local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Settings page
---------------------------------------------------------------
-- Patchwerk's own page in the game's options (Options > AddOns),
-- listing the settings the base and the installed Stitch parts
-- added (AddSetting), a heading per section, with the pages of
-- our own tools beneath it (Tools.lua). Made at login, when every
-- part has loaded and added its own. Each control is a proxy onto
-- GetSetting / SetSetting: the values stay in
-- PatchwerkForeverDB.settings, changed here or with /patchwerk set.

local TITLE = 'Patchwerk Forever';

local function Tooltip(def)
	if ( def.desc and def.note ) then
		return def.desc .. '\n\n' .. def.note;
	end
	return def.desc or def.note;
end

local settingsCategory;

local function Build()
	if not ( Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting
	and Settings.CreateCheckbox and Settings.RegisterAddOnCategory and Settings.VarType ) then
		return;
	end
	local parentCategory, parentLayout = Settings.RegisterVerticalLayoutCategory(TITLE);
	-- The base's own settings are on its page. Each Stitch has a page of its own beneath it
	-- ("Stitch: Console Port"), beside the tools' pages, so the list on the left shows what is
	-- installed. (A client without sub-pages gets them all on the one page, a heading for each.)
	local pages, sectionsOf = {}, {};
	for _, def in ipairs(P.Settings.list) do
		local part = def.part or addonName;
		sectionsOf[part] = sectionsOf[part] or { count = 0 };
		if ( def.section and not sectionsOf[part][def.section] ) then
			sectionsOf[part][def.section] = true;
			sectionsOf[part].count = sectionsOf[part].count + 1;
		end
	end
	local function PageOf(part)
		if ( part == addonName or not Settings.RegisterVerticalLayoutSubcategory ) then
			return parentCategory, parentLayout, true;
		end
		local page = pages[part];
		if not page then
			local sub, subLayout = Settings.RegisterVerticalLayoutSubcategory(parentCategory, ns.PageName(part));
			page = { category = sub, layout = subLayout };
			pages[part] = page;
		end
		-- (one section on a page of its own needs no heading: the page's name says it)
		return page.category, page.layout, sectionsOf[part].count > 1;
	end
	local controls, section, sectionPart = {}, nil, nil;
	for _, def in ipairs(P.Settings.list) do
		local part = def.part or addonName;
		local category, layout, headings = PageOf(part);
		if ( def.section ~= section or part ~= sectionPart ) then
			section, sectionPart = def.section, part;
			if ( headings and section and CreateSettingsListSectionHeaderInitializer ) then
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
			function() return P:GetSetting(key) end,
			function(value) P:SetSetting(key, value) end);
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
			control:SetParentInitializer(parent, function() return P:GetSetting(parentKey) == true end)
		end
	end
	-- our own tools' pages, under this one (Tools.lua)
	local ok, err = pcall(ns.BuildToolPages, parentCategory);
	if not ok then
		P:Print('The pages of the tools could not be made (' .. tostring(err) .. ').')
	end
	Settings.RegisterAddOnCategory(parentCategory)
	settingsCategory = parentCategory;
end

-- What a Stitch's page is called: its title without the family's name, "Stitch (Console Port)"
-- written as the tools' pages are, "Stitch: Console Port".
function ns.PageName(part)
	local title = ns.Meta(part, 'Title') or part;
	title = title:gsub('^Patchwerk Forever:%s*', '');
	local track, what = title:match('^(%a+)%s*%((.+)%)$');
	if track then
		return track .. ': ' .. what;
	end
	return title;
end

function ns.OpenSettings()
	local category = settingsCategory;
	if not ( category and Settings and Settings.OpenToCategory ) or InCombatLockdown() then
		return false;
	end
	local ok = pcall(function() Settings.OpenToCategory(category:GetID()) end);
	return ok;
end

ns.AtLogin(function()
	local ok, err = pcall(Build);
	if not ok then
		P:Print('The settings page could not be made (' .. tostring(err) .. '). /patchwerk set lists the settings.')
	end
end)
