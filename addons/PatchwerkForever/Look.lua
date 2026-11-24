local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Look: how Patchwerk's pages are dressed
---------------------------------------------------------------
-- The pages in the game's options are the game's own rows: a
-- tick box, a slider, a list. Two rows of ours go between them
-- so the pages look like they belong to someone:
--
--   an intro   the page's picture and name in the game's old
--              storybook lettering, a line in Patchwerk's voice,
--              and a row of stitches under it
--   a heading  a section's name in gold, stitched under
--
-- The game makes a row from a template named in an XML file
-- (Look.xml) and calls Init on it with what the row is to show.
-- Everything a row holds is made here, in its OnLoad, so the XML
-- says only its name and its height.
--
-- Setting names are in Title Case, as the game's own options are.
-- ns.Sentence can show them in sentence case instead ("Hide
-- default quest tracker"): one line here switches it on.

local SENTENCE = false;       -- true: show setting names in sentence case. The game's own options use Title Case, so ours do.

ns.GOLD  = { 0.84, 0.64, 0.36 };
ns.CREAM = { 0.90, 0.84, 0.70 };
-- on the options window's parchment (2.10.0): dark ink for words, a red-brown for names and headings
ns.INK   = { 0.20, 0.13, 0.07 };
ns.RUST  = { 0.45, 0.15, 0.05 };
ns.FADED = { 0.45, 0.37, 0.27 };
ns.MEDIA = 'Interface\\AddOns\\' .. addonName .. '\\Media\\';

local STITCH, STITCH_GAP = 9, 6;

-- names that keep their capital wherever they stand
local KEEP = { Console = true, Port = true, Patchwerk = true, Forever = true, I = true, Thread = true, Stitch = true };

function ns.Sentence(name)
	if not ( SENTENCE and type(name) == 'string' ) then return name end;
	local first = true;
	return ( name:gsub('%S+', function(word)
		if first then
			first = false;
			return word;
		end
		-- (a word with a capital inside it is a name: RestedXP, MelloUI)
		local bare = word:gsub('[^%a]', '');
		if ( KEEP[bare] or word:sub(2):find('%u') ) then return word end;
		return ( word:gsub('^(%p*)(%u)', function(before, letter) return before .. letter:lower() end) );
	end) );
end

-- The game's storybook lettering, or its plain one where that is missing.
function ns.Lettering(fs, size, plain)
	local fallback = STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF';
	if not ( not plain and fs:SetFont('Fonts\\MORPHEUS.TTF', size, '') ) then
		fs:SetFont(fallback, size, '')
	end
	if fs.SetShadowOffset then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 0.9)
	end
end

-- A row of stitches along the foot of a frame. Fit(width) shows as many as fit.
function ns.Stitches(frame, left, up)
	local row = { pieces = {} };
	function row:Fit(width)
		width = ( tonumber(width) or 0 ) - ( left or 0 ) * 2;
		local n = math.max(0, math.min(120, math.floor(( width + STITCH_GAP ) / ( STITCH + STITCH_GAP ))));
		for i = 1, n do
			local piece = self.pieces[i];
			if not piece then
				piece = frame:CreateTexture(nil, 'ARTWORK');
				piece:SetColorTexture(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], 0.7)
				piece:SetSize(STITCH, 2)
				piece:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', ( left or 0 ) + ( i - 1 ) * ( STITCH + STITCH_GAP ), up or 0)
				self.pieces[i] = piece;
			end
			piece:Show()
		end
		for i = n + 1, #self.pieces do self.pieces[i]:Hide() end
	end
	return row;
end

local function Writing(frame, size, plain)
	local fs = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal');
	fs:SetJustifyH('LEFT')
	ns.Lettering(fs, size, plain)
	return fs;
end
ns.Writing = Writing;

---------------------------------------------------------------
-- The intro row (PatchwerkForeverIntroTemplate, 84 high)
---------------------------------------------------------------
PatchwerkForeverIntroMixin = {};

function PatchwerkForeverIntroMixin:OnLoad()
	self.Icon = self:CreateTexture(nil, 'ARTWORK');
	self.Icon:SetSize(48, 48)
	self.Icon:SetPoint('TOPLEFT', self, 'TOPLEFT', 6, -12)
	self.Title = Writing(self, 22);
	self.Title:SetPoint('TOPLEFT', self, 'TOPLEFT', 66, -14)
	self.Title:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -24, -14)
	self.Title:SetWordWrap(false)
	self.Title:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
	self.Voice = Writing(self, 12, true);
	self.Voice:SetPoint('TOPLEFT', self, 'TOPLEFT', 67, -42)
	self.Voice:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -24, -42)
	self.Voice:SetWordWrap(true)
	if self.Voice.SetMaxLines then self.Voice:SetMaxLines(2) end;
	self.Voice:SetTextColor(ns.CREAM[1], ns.CREAM[2], ns.CREAM[3])
	self.stitches = ns.Stitches(self, 6, 4);
	self:SetScript('OnSizeChanged', function(row, width) row.stitches:Fit(width) end)
end

function PatchwerkForeverIntroMixin:Init(initializer)
	local data = initializer:GetData() or {};
	self.Title:SetText(data.name or '')
	self.Voice:SetText(data.voice or '')
	if data.icon then
		self.Icon:SetTexture(data.icon)
		self.Icon:Show()
	else
		self.Icon:Hide()
	end
	self.stitches:Fit(self:GetWidth())
end

---------------------------------------------------------------
-- The heading row (PatchwerkForeverHeaderTemplate, 44 high)
---------------------------------------------------------------
PatchwerkForeverHeaderMixin = {};

function PatchwerkForeverHeaderMixin:OnLoad()
	self.Title = Writing(self, 17);
	self.Title:SetPoint('TOPLEFT', self, 'TOPLEFT', 7, -16)
	self.Title:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -24, -16)
	self.Title:SetWordWrap(false)
	self.Title:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
	self.stitches = ns.Stitches(self, 6, 3);
	self:SetScript('OnSizeChanged', function(row, width) row.stitches:Fit(width) end)
end

function PatchwerkForeverHeaderMixin:Init(initializer)
	local data = initializer:GetData() or {};
	self.Title:SetText(data.name or '')
	self.stitches:Fit(self:GetWidth())
end

---------------------------------------------------------------
-- The list row (PatchwerkForeverListTemplate, 266 high; 2.9.0)
---------------------------------------------------------------
-- A tool's list on its page: a line of words for each entry, with
-- up to two buttons at its right ("Remove", "Add To Route"), eight
-- lines a page and Previous and Next under them. What it lists is
-- asked of the tool (data.list(), giving { { text =, buttons =
-- { { text =, click = fn }, ... } }, ... }) as the row is shown, a
-- moment after a button is pressed, and twice a second while it
-- shows, so a list changed from the chat is up to date too.
local LIST_LINES, LINE_TALL, LIST_EVERY = 8, 26, 0.5;
local BUTTON_WIDE = 116;

PatchwerkForeverListMixin = {};

local function ListButton(parent, text, width)
	local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate');
	button:SetSize(width or BUTTON_WIDE, 22)
	if text then button:SetText(text) end;
	return button;
end

local function Enable(button, on)
	if button.SetEnabled then button:SetEnabled(on) end;
end

function PatchwerkForeverListMixin:OnLoad()
	self.Title = Writing(self, 13, true);
	self.Title:SetPoint('TOPLEFT', self, 'TOPLEFT', 37, -6)
	self.Title:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
	self.lines = {};
	for i = 1, LIST_LINES do
		local line = CreateFrame('Frame', nil, self);
		line:SetHeight(LINE_TALL - 2)
		line:SetPoint('TOPLEFT', self, 'TOPLEFT', 37, -26 - ( i - 1 ) * LINE_TALL)
		line:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -24, -26 - ( i - 1 ) * LINE_TALL)
		line.Text = Writing(line, 12, true);
		line.Text:SetPoint('LEFT', line, 'LEFT', 0, 0)
		line.Text:SetPoint('RIGHT', line, 'RIGHT', -( BUTTON_WIDE * 2 + 12 ), 0)
		line.Text:SetWordWrap(false)
		line.Text:SetTextColor(ns.CREAM[1], ns.CREAM[2], ns.CREAM[3])
		line.buttons = {};
		for b = 1, 2 do
			local button = ListButton(line);
			button:SetPoint('RIGHT', line, 'RIGHT', -( b - 1 ) * ( BUTTON_WIDE + 6 ), 0)
			button:SetScript('OnClick', function(pressed)
				if ( type(pressed.click) == 'function' ) then
					local ok, problem = pcall(pressed.click);
					if not ok then geterrorhandler()(problem) end;
				end
				self:Refresh()
			end)
			line.buttons[b] = button;
		end
		self.lines[i] = line;
	end
	self.Empty = Writing(self, 12, true);
	self.Empty:SetPoint('TOPLEFT', self, 'TOPLEFT', 37, -30)
	self.Empty:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -24, -30)
	self.Empty:SetWordWrap(true)
	self.Empty:SetTextColor(ns.CREAM[1], ns.CREAM[2], ns.CREAM[3])
	self.Previous = ListButton(self, 'Previous', 96);
	self.Previous:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', 37, 6)
	self.Previous:SetScript('OnClick', function() self.page = ( self.page or 1 ) - 1; self:Refresh() end)
	self.Next = ListButton(self, 'Next', 96);
	self.Next:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', 139, 6)
	self.Next:SetScript('OnClick', function() self.page = ( self.page or 1 ) + 1; self:Refresh() end)
	self.Page = Writing(self, 12, true);
	self.Page:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', 247, 11)
	self.Page:SetTextColor(ns.CREAM[1], ns.CREAM[2], ns.CREAM[3])
	self.wait = 0;
	self:SetScript('OnShow', function(row) row:Refresh() end)
	self:SetScript('OnUpdate', function(row, elapsed)
		row.wait = row.wait - ( elapsed or 0 );
		if ( row.wait > 0 ) then return end;
		row:Refresh()
	end)
end

function PatchwerkForeverListMixin:Init(initializer)
	self.data = initializer:GetData() or {};
	self.page = 1;
	self.Title:SetText(self.data.name or '')
	self:Refresh()
end

function PatchwerkForeverListMixin:Refresh()
	self.wait = LIST_EVERY;
	local data = self.data;
	if not data then return end;
	local rows = {};
	if ( type(data.list) == 'function' ) then
		local ok, got = pcall(data.list);
		if ( ok and type(got) == 'table' ) then rows = got end;
	end
	local pages = math.max(1, math.ceil(#rows / LIST_LINES));
	self.page = math.max(1, math.min(pages, self.page or 1));
	local first = ( self.page - 1 ) * LIST_LINES;
	for i, line in ipairs(self.lines) do
		local entry = rows[first + i];
		if ( type(entry) == 'table' ) then
			line.Text:SetText(tostring(entry.text or ''))
			for b, button in ipairs(line.buttons) do
				local given = type(entry.buttons) == 'table' and entry.buttons[b];
				if ( type(given) == 'table' and type(given.text) == 'string' ) then
					button:SetText(given.text)
					button.click = given.click;
					button:Show()
				else
					button.click = nil;
					button:Hide()
				end
			end
			line:Show()
		else
			line:Hide()
		end
	end
	if ( #rows == 0 ) then
		self.Empty:SetText(data.empty or '')
		self.Empty:Show()
	else
		self.Empty:Hide()
	end
	local paged = pages > 1;
	for _, part in ipairs({ self.Previous, self.Next, self.Page }) do
		if paged then part:Show() else part:Hide() end;
	end
	if paged then
		self.Page:SetText(('Page %d of %d'):format(self.page, pages))
		Enable(self.Previous, self.page > 1)
		Enable(self.Next, self.page < pages)
	end
end

---------------------------------------------------------------
-- Putting them on a page
---------------------------------------------------------------
-- puts something that is not a setting on a page: { category =, layout = }
function ns.PlaceOn(page, initializer)
	if Settings.RegisterInitializer then
		Settings.RegisterInitializer(page.category, initializer)
	elseif ( page.layout and page.layout.AddInitializer ) then
		page.layout:AddInitializer(initializer)
	end
end

-- Whether the game knows a row of ours (Look.xml was read, and this client can be asked). A row
-- the game does not know would stop the whole page from showing, so it is asked first, once.
local known = {};
local function Ready(template)
	if ( known[template] == nil ) then
		known[template] = false;
		if ( Settings.CreateElementInitializer and C_XMLUtil and C_XMLUtil.GetTemplateInfo ) then
			local ok, info = pcall(C_XMLUtil.GetTemplateInfo, template);
			known[template] = ( ok and type(info) == 'table' and ( tonumber(info.height) or 0 ) > 0 ) and true or false;
		end
	end
	return known[template];
end

-- A section's heading: ours where the game lets an addon bring a row of its own, else the game's.
function ns.PlaceHeader(page, name)
	if Ready('PatchwerkForeverHeaderTemplate') then
		return ns.PlaceOn(page, Settings.CreateElementInitializer('PatchwerkForeverHeaderTemplate', { name = name }));
	end
	if CreateSettingsListSectionHeaderInitializer then
		ns.PlaceOn(page, CreateSettingsListSectionHeaderInitializer(name))
	end
end

-- A tool's list (2.9.0), its name written over it. Where the game does not know our row
-- the list is left out (the tool's chat commands do the same work) and false is given.
function ns.PlaceList(page, def)
	if not Ready('PatchwerkForeverListTemplate') then return false end;
	ns.PlaceOn(page, Settings.CreateElementInitializer('PatchwerkForeverListTemplate',
		{ name = def.name, list = def.list, empty = def.empty }))
	return true;
end

-- A page's intro: its name, the picture of the addon it belongs to, and a line in Patchwerk's voice.
function ns.PlaceIntro(page, name, addon, voice)
	if not Ready('PatchwerkForeverIntroTemplate') then return end;
	ns.PlaceOn(page, Settings.CreateElementInitializer('PatchwerkForeverIntroTemplate',
		{ name = name, icon = P:Icon(addon), voice = voice }))
end

-- What Patchwerk says of one of the family's addons: the X-Patchwerk-Voice line of its TOC.
function ns.VoiceOf(addon)
	return ns.Meta(addon, 'X-Patchwerk-Voice');
end

-- The page of each addon of the family, for the front page's buttons: [addon] = the game's category.
ns.pageOf = {};
