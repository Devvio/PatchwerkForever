local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Settings page
---------------------------------------------------------------
-- Since 2.10.0 the options are in the family's own window
-- (Window.lua, Options.lua). The game's options (Options >
-- AddOns) keep one page, Patchwerk Forever: the banner, a line
-- in Patchwerk's voice and a button that opens the window.
--
-- Where the window cannot be made, the pages are made in the
-- game's options as before 2.10.0 (BuildGamePages): the front
-- page drawn by us (Front.lua), beneath it a page for each
-- installed Stitch of the settings it added (AddSetting), a
-- heading per section, and our own tools' pages (Tools.lua).
-- Each control there is a proxy onto GetSetting / SetSetting:
-- the values stay in PatchwerkForeverDB.settings either way.

local TITLE = 'Patchwerk Forever';

local function Tooltip(def)
	if ( def.desc and def.note ) then
		return def.desc .. '\n\n' .. def.note;
	end
	return def.desc or def.note;
end

local settingsCategory;

local function BuildGamePages()
	if not ( Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting
	and Settings.CreateCheckbox and Settings.RegisterAddOnCategory and Settings.VarType ) then
		return;
	end
	-- The first page is drawn by us where the game takes such a page; else it is a list like the rest.
	local parentCategory, parentLayout, drawn;
	if ( Settings.RegisterCanvasLayoutCategory and ns.FrontPage ) then
		local made, front = pcall(ns.FrontPage);
		if ( made and type(front) == 'table' ) then
			local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, front, TITLE);
			if ( ok and category ) then parentCategory, drawn = category, true end;
		end
	end
	if not parentCategory then
		parentCategory, parentLayout = Settings.RegisterVerticalLayoutCategory(TITLE);
	end
	-- The base's own switches are on the first page. Each Stitch has a page of its own beneath it
	-- ("Console Port (Stitch)"), beside the tools' pages, so the list on the left shows what is
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
		local own = ( part == addonName );
		if ( not Settings.RegisterVerticalLayoutSubcategory or ( own and not drawn ) ) then
			return { category = parentCategory, layout = parentLayout }, true;
		end
		local page = pages[part];
		if not page then
			-- (a setting of the base's that is not a switch, with the first page drawn: a page called General)
			local name = own and 'General' or ns.PageName(part);
			local sub, subLayout = Settings.RegisterVerticalLayoutSubcategory(parentCategory, name);
			page = { category = sub, layout = subLayout };
			pages[part] = page;
			ns.pageOf[part] = sub;
			pcall(ns.PlaceIntro, page, name, part, ns.VoiceOf(part))
		end
		-- (one section on a page of its own needs no heading: the page's name says it)
		return page, sectionsOf[part].count > 1;
	end
	local controls, section, sectionPart = {}, nil, nil;
	for _, def in ipairs(P.Settings.list) do repeat
		local part = def.part or addonName;
		-- (the base's own switches are tick boxes on the first page, when that page is drawn: Front.lua)
		if ( drawn and part == addonName and type(def.default) == 'boolean' ) then break end;
		local page, headings = PageOf(part);
		local category = page.category;
		if ( def.section ~= section or part ~= sectionPart ) then
			section, sectionPart = def.section, part;
			if ( headings and section ) then
				ns.PlaceHeader(page, ns.Sentence(section))
			end
		end
		local key, isNumber = def.key, type(def.default) == 'number';
		local setting = Settings.RegisterProxySetting(category, addonName .. '_' .. key,
			isNumber and Settings.VarType.Number or Settings.VarType.Boolean,
			ns.Sentence(def.name or key), def.default,
			function() return P:GetSetting(key) end,
			function(value) P:SetSetting(key, value) end);
		local control;
		if isNumber then
			control = Settings.CreateSlider(category, setting, ns.SliderOptions(def), Tooltip(def));
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
	until true end
	-- our own tools' pages, under this one (Tools.lua)
	local ok, err = pcall(ns.BuildToolPages, parentCategory);
	if not ok then
		ns.Say('The options pages of the Thread tools could not be created (' .. tostring(err) .. ').')
	end
	Settings.RegisterAddOnCategory(parentCategory)
	settingsCategory = parentCategory;
end

-- What a Stitch's page is called: its title without the family's name, "Console Port (Stitch)", as
-- the tools' pages are named ("Routes (Thread)").
function ns.PageName(part)
	local title = ns.Meta(part, 'Title') or part;
	title = title:gsub('^Patchwerk Forever:%s*', '');
	return title;
end

-- The one page in the game's options: the banner, a line, and the button that opens the window.
local door;
local function Door()
	door = CreateFrame('Frame');
	door:Hide()
	door.Banner = door:CreateTexture(nil, 'BACKGROUND');
	door.Banner:SetTexture(ns.MEDIA .. 'banner')
	door.Banner:SetPoint('TOPLEFT', door, 'TOPLEFT', 0, 0)
	door.Banner:SetPoint('TOPRIGHT', door, 'TOPRIGHT', 0, 0)
	door.Banner:SetHeight(200)
	door.Title = ns.Writing(door, 30);
	door.Title:SetPoint('TOPLEFT', door.Banner, 'TOPLEFT', 22, -26)
	door.Title:SetText('Patchwerk Forever')
	door.Title:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
	door.Said = ns.Writing(door, 13, true);
	door.Said:SetPoint('TOPLEFT', door.Title, 'BOTTOMLEFT', 1, -10)
	door.Said:SetWidth(240)
	door.Said:SetWordWrap(true)
	door.Said:SetText('Patchwerk keeps every option in his own book now. One button, all the pages.')
	door.Said:SetTextColor(ns.CREAM[1], ns.CREAM[2], ns.CREAM[3])
	door.Open = CreateFrame('Button', nil, door, 'UIPanelButtonTemplate');
	door.Open:SetSize(240, 30)
	door.Open:SetPoint('TOPLEFT', door.Banner, 'BOTTOMLEFT', 6, -24)
	door.Open:SetText('Open Patchwerk Forever Options')
	door.Open:SetScript('OnClick', function() ns.OpenWindow() end)
	door.Note = ns.Writing(door, 12, true);
	door.Note:SetPoint('TOPLEFT', door.Open, 'BOTTOMLEFT', 2, -12)
	door.Note:SetWidth(420)
	door.Note:SetWordWrap(true)
	door.Note:SetText('Also /patchwerk config, the Open Options key binding, or Patchwerk Forever in the minimap\'s addon list.')
	door.Note:SetTextColor(0.7, 0.7, 0.7)
	door:SetScript('OnSizeChanged', function(self, width)
		if ( tonumber(width) and width > 100 ) then self.Banner:SetHeight(math.floor(width / 3)) end;
	end)
	return door;
end

local function Build()
	local made, window = pcall(ns.MakeWindow);
	if not ( made and window ) then
		ns.Say('The options window could not be made (' .. tostring(window) .. '). The options are in the game\'s options instead.')
		return BuildGamePages();
	end
	ns.Book()
	if not ( Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory ) then return end;
	local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, Door(), TITLE);
	if ( ok and category ) then
		Settings.RegisterAddOnCategory(category)
		settingsCategory = category;
	end
end

-- The options: the family's window, else (where it could not be made) the game's options.
function ns.OpenSettings()
	if ( ns.WindowFrame and ns.WindowFrame() ) then
		return ns.OpenWindow();
	end
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
		ns.Say('The options could not be created (' .. tostring(err) .. '). /patchwerk set lists the options in chat.')
	end
end)

-- A click on Patchwerk Forever in the minimap's addon list (AddonCompartmentFunc in the TOC).
function PatchwerkForever_OnAddonCompartmentClick()
	ns.OpenOptions()
end
