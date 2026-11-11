-- Wayfarer: its pages in the game's options (Options > AddOns).
--
-- Built from the list in Core.lua (ns.settings): a first page, and a sub-page for each `page` named
-- there (one for each kind of thing that sparkles, one for the name, one for the trail). Each control
-- is a view onto ns.Get / ns.Set; the values live in PatchwerkForever_WayfarerDB.settings.
--   a tick box, a slider, a list to pick from, a colour (the game's own colour swatch and picker),
--   a button, a heading
-- Every control is made on its own, so one the client will not make leaves the rest standing.
local ADDON, ns = ...

local category
local pages = {}              -- [page name] = { category =, layout = }

local function Page(name)
	if not name then return pages[1] end
	local page = pages[name]
	if not page then
		local sub, layout = Settings.RegisterVerticalLayoutSubcategory(category, name)
		page = { category = sub, layout = layout }
		pages[name] = page
	end
	return page
end

-- Puts something that is not a setting (a heading, a button) on a page.
local function Place(page, initializer)
	if Settings.RegisterInitializer then
		Settings.RegisterInitializer(page.category, initializer)
	elseif page.layout and page.layout.AddInitializer then
		page.layout:AddInitializer(initializer)
	end
end

local controls = {}

local function Control(def)
	local page = Page(def.page)
	if def.header then
		if CreateSettingsListSectionHeaderInitializer then
			Place(page, CreateSettingsListSectionHeaderInitializer(def.name))
		end
		return
	end
	if def.button then
		if CreateSettingsButtonInitializer then
			Place(page, CreateSettingsButtonInitializer(def.name, def.button, def.click, def.desc, true))
		end
		return
	end
	local key = def.key
	local variable = ADDON .. '_' .. (key:gsub('%.', '_'))
	local function get() return ns.Get(key) end
	local function set(value) ns.Set(key, value) end
	local control
	if def.colour then
		if not Settings.CreateColorSwatch then return end
		local setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.String, def.name,
			def.default, get, set)
		control = Settings.CreateColorSwatch(page.category, setting, def.desc)
	elseif def.choices then
		if not (Settings.CreateDropdown and Settings.CreateControlTextContainer) then return end
		local setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.String, def.name,
			def.default, get, set)
		local function Options()
			local container = Settings.CreateControlTextContainer()
			for _, choice in ipairs(def.choices) do
				container:Add(choice[1], choice[2])
			end
			return container:GetData()
		end
		control = Settings.CreateDropdown(page.category, setting, Options, def.desc)
	elseif type(def.default) == 'number' then
		if not (Settings.CreateSlider and Settings.CreateSliderOptions) then return end
		local setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.Number, def.name,
			def.default, get, set)
		local options = Settings.CreateSliderOptions(def.min, def.max, def.step)
		if options.SetLabelFormatter and MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end
		control = Settings.CreateSlider(page.category, setting, options, def.desc)
	else
		local setting = Settings.RegisterProxySetting(page.category, variable, Settings.VarType.Boolean, def.name,
			def.default, get, set)
		control = Settings.CreateCheckbox(page.category, setting, def.desc)
	end
	controls[key] = control
	-- a setting that only matters while a tick box is on: greyed out with it
	local parent = def.parent and controls[def.parent]
	if parent and control and control.SetParentInitializer then
		local parentKey = def.parent
		control:SetParentInitializer(parent, function() return ns.Get(parentKey) == true end)
	end
end

local function Build()
	if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterVerticalLayoutSubcategory
		and Settings.RegisterProxySetting and Settings.CreateCheckbox and Settings.RegisterAddOnCategory
		and Settings.VarType) then
		return
	end
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory(ns.TITLE)
	pages[1] = { category = category, layout = layout }
	for _, def in ipairs(ns.settings) do
		ns.Try('the options page (' .. tostring(def.name) .. ')', Control, def)
	end
	Settings.RegisterAddOnCategory(category)
end

function ns.OpenSettings()
	if not (category and Settings and Settings.OpenToCategory) or InCombatLockdown() then
		return false
	end
	return (pcall(function() Settings.OpenToCategory(category:GetID()) end))
end

ns.On('PLAYER_LOGIN', function() ns.Try('the options page', Build) end)
