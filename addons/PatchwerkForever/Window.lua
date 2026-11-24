local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Window: the family's own options window (base 2.10.0)
---------------------------------------------------------------
-- Every option of every part, in one window of our own, dressed
-- in parchment and leather (OPTIONS-BLUEPRINT.md):
--
--   the title band     the banner and the family's name; drag it
--                      to move the window; the close button
--   the left column    a search box, then the parts, each with
--                      its picture; the part shown folds open to
--                      its further pages
--   the page           the page's intro, its headings and a row a
--                      setting, scrolling (Options.lua says what
--                      is on it)
--   the foot           Close
--
-- The controls are the game's own (tick box, slider with
-- steppers, dropdown, color swatch, button) on our parchment, so
-- the game's gamepad cursor and Console Port's reach them as they
-- reach the game's own options. A control the cursor moves to is
-- scrolled into view.
--
-- Opened by /patchwerk config, the Open Options key binding, the
-- minimap's addon list, a tool's own command, and the button on
-- Patchwerk Forever's one page in the game's options. Not in
-- combat; it closes when combat starts. Escape closes it. Where
-- it stood, and the page last shown, are kept for the account.

local NAME = 'PatchwerkForeverOptions';
local WIDE, TALL = 920, 640;
local BAND, COLUMN, FOOT = 70, 232, 44;     -- the title band, the left column, the foot
local LINE = 32;                            -- the height of a setting's row
local NAV_PART, NAV_PAGE = 28, 22;          -- the heights of a part's and a page's line on the left
local EVERY = 0.5;                          -- how often the values shown are read again
local FOLLOW = 12;                          -- room kept above and below a control scrolled into view

local win;                  -- the window
local state = { part = nil, page = nil, searching = nil, open = nil };
local pools = {};           -- [kind] = { widget, ... }
local used = {};            -- the widgets on the page now, in order
local navLines = {};
local saidCombat = false;

local function Saved()
	return P:GetSaved('window') or {};
end

local function Play(which)
	local play, kit = rawget(_G, 'PlaySound'), rawget(_G, 'SOUNDKIT');
	if ( type(play) == 'function' and type(kit) == 'table' and kit[which] ) then
		pcall(play, kit[which])
	end
end

-- The game's gamepad cursor: where it may stop, and where it sits on a control. Each is asked
-- for by name, as an older client has none of them.
local function Nav(name, ...)
	local fn = rawget(_G, name);
	if ( type(fn) == 'function' ) then pcall(fn, ...) end;
end

local function CursorAt(control, row)
	local anchor = rawget(_G, 'CreateAnchor');
	if ( type(anchor) == 'function' ) then
		local ok, where = pcall(anchor, 'RIGHT', row, 'LEFT', 30);
		if ok then Nav('SmartNavigation_SetCustomCursorAnchorPointForFrame', control, where) end;
	end
end

---------------------------------------------------------------
-- Tooltips
---------------------------------------------------------------
local function ShowTip(owner, title, text)
	local tip = rawget(_G, 'GameTooltip');
	if not ( type(tip) == 'table' and tip.SetOwner and ( title or text ) ) then return end;
	tip:SetOwner(owner, 'ANCHOR_RIGHT')
	local setTitle, line = rawget(_G, 'GameTooltip_SetTitle'), rawget(_G, 'GameTooltip_AddNormalLine');
	if ( type(setTitle) == 'function' and type(line) == 'function' ) then
		if title then setTitle(tip, title) end;
		if text then line(tip, text, true) end;
	else
		tip:SetText(text or title, 1, 1, 1, 1, true)
	end
	tip:Show()
end

local function HideTip()
	local tip = rawget(_G, 'GameTooltip');
	if ( type(tip) == 'table' and tip.Hide ) then tip:Hide() end;
end

---------------------------------------------------------------
-- Scrolling a control into view
---------------------------------------------------------------
local function Follow(widget)
	local scroll = win and win.Scroll;
	if not ( scroll and widget and widget.y ) then return end;
	local view = scroll:GetHeight() or 0;
	local at = scroll.GetVerticalScroll and scroll:GetVerticalScroll() or 0;
	local most = scroll.GetVerticalScrollRange and scroll:GetVerticalScrollRange() or 0;
	local top, bottom = widget.y, widget.y + ( widget.tall or LINE );
	local want = at;
	if ( top - FOLLOW < at ) then
		want = top - FOLLOW;
	elseif ( bottom + FOLLOW > at + view ) then
		want = bottom + FOLLOW - view;
	end
	want = math.max(0, math.min(most, want));
	if ( want ~= at and scroll.SetVerticalScroll ) then scroll:SetVerticalScroll(want) end;
end

-- what every control does as the mouse or a gamepad cursor comes to it
local function Hover(control, widget)
	control:HookScript('OnEnter', function()
		Follow(widget)
		local row = widget.row;
		if row then ShowTip(control, row.name, row.desc) end;
	end)
	control:HookScript('OnLeave', HideTip)
end

---------------------------------------------------------------
-- The rows
---------------------------------------------------------------
-- A widget is made once for each kind and used again for whatever row of that kind is shown.
local Make = {};

-- the rows of ours from Look.lua: an intro, a heading, a list
local function Dressed(mixin, tall)
	return function(parent)
		local frame = CreateFrame('Frame', nil, parent);
		for key, value in pairs(mixin) do frame[key] = value end;
		frame:SetHeight(tall)
		frame:OnLoad()
		frame.tall = tall;
		Nav('SmartNavigation_MarkFrameIgnored', frame)
		return frame;
	end
end
Make.intro = Dressed(PatchwerkForeverIntroMixin, 84);
Make.header = Dressed(PatchwerkForeverHeaderMixin, 44);
Make.list = Dressed(PatchwerkForeverListMixin, 266);

-- words on the parchment are in ink (Look.lua's rows are made for the game's dark pages)
local function Ink(fs, colour)
	if ( fs and fs.SetTextColor ) then fs:SetTextColor(colour[1], colour[2], colour[3]) end;
end

local function Fill(widget, data)
	widget:Init({ GetData = function() return data end })
	Ink(widget.Title, ns.RUST)
	Ink(widget.Voice, ns.INK)
	Ink(widget.Empty, ns.INK)
	Ink(widget.Page, ns.INK)
	for _, line in ipairs(widget.lines or {}) do Ink(line.Text, ns.INK) end;
end

-- a line of words (what the search found, or that it found nothing)
function Make.text(parent)
	local frame = CreateFrame('Frame', nil, parent);
	frame:SetHeight(30)
	frame.Text = ns.Writing(frame, 13, true);
	frame.Text:SetPoint('TOPLEFT', frame, 'TOPLEFT', 16, -8)
	frame.Text:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -16, -8)
	frame.Text:SetWordWrap(true)
	Ink(frame.Text, ns.INK)
	frame.tall = 30;
	return frame;
end

-- a setting's row: its name at the left, its control at the right of the middle
local function Row(parent)
	local frame = CreateFrame('Frame', nil, parent);
	frame:SetHeight(LINE)
	frame.Label = ns.Writing(frame, 13, true);
	frame.Label:SetPoint('LEFT', frame, 'LEFT', 24, 0)
	frame.Label:SetPoint('RIGHT', frame, 'CENTER', -10, 0)
	frame.Label:SetWordWrap(false)
	frame.tall = LINE;
	-- (the name shows the tooltip too; the cursor goes to the control, not the row)
	frame:EnableMouse(true)
	frame:SetScript('OnEnter', function(self) if self.row then ShowTip(self, self.row.name, self.row.desc) end end)
	frame:SetScript('OnLeave', HideTip)
	Nav('SmartNavigation_MarkFrameIgnored', frame)
	return frame;
end

local function Set(widget, value)
	local row = widget.row;
	if not ( row and row.set ) or widget.quiet then return end;
	if ( row.get and row.get() == value ) then return end;
	row.set(value)
	ns.WindowValues()
end

function Make.check(parent)
	local widget = Row(parent);
	local check = CreateFrame('CheckButton', nil, widget, 'UICheckButtonTemplate');
	check:SetSize(28, 28)
	check:SetPoint('LEFT', widget, 'CENTER', 0, 0)
	check:SetScript('OnClick', function(self)
		local on = self:GetChecked() and true or false;
		Play(on and 'IG_MAINMENU_OPTION_CHECKBOX_ON' or 'IG_MAINMENU_OPTION_CHECKBOX_OFF')
		Set(widget, on)
	end)
	Hover(check, widget)
	CursorAt(check, widget)
	widget.Control = check;
	function widget:Show_(row) self.Control:SetChecked(row.get() == true) end
	function widget:Value(row) local on = row.get() == true; if ( self.Control:GetChecked() and true or false ) ~= on then self.Control:SetChecked(on) end end
	return widget;
end

local function Percent(value) return ('%d%%'):format(math.floor(value + 0.5)) end
local function Plain(value)
	if ( math.floor(value) == value ) then return tostring(value) end;
	return ('%.2f'):format(value):gsub('0+$', ''):gsub('%.$', '');
end

-- a value put on the slider's steps and inside its range
local function Stepped(row, value)
	local low, high, step = row.min or 0, row.max or 1, row.step or 1;
	value = low + math.floor(( value - low ) / step + 0.5) * step;
	return math.max(low, math.min(high, value));
end

function Make.slider(parent)
	local widget = Row(parent);
	local slider = CreateFrame('Frame', nil, widget, 'MinimalSliderWithSteppersTemplate');
	slider:SetSize(250, 20)
	slider:SetPoint('LEFT', widget, 'CENTER', 4, 0)
	local mixin = rawget(_G, 'MinimalSliderWithSteppersMixin');
	if ( slider.RegisterCallback and mixin and mixin.Event ) then
		slider:RegisterCallback(mixin.Event.OnValueChanged, function(_, value)
			local row = widget.row;
			if row then Set(widget, Stepped(row, value)) end;
		end, widget)
	end
	-- (the gamepad cursor stops on the steppers, which an A press moves a step; the bar itself is skipped)
	if slider.Slider then
		Nav('SmartNavigation_MarkFrameIgnored', slider.Slider)
		Hover(slider.Slider, widget)
	end
	for _, stepper in ipairs({ slider.Back or false, slider.Forward or false }) do
		if stepper then Hover(stepper, widget) end;
	end
	if slider.Back then CursorAt(slider.Back, widget) end;
	widget.Control = slider;
	function widget:Show_(row)
		local low, high, step = row.min or 0, row.max or 1, row.step or 1;
		local formatters;
		if ( mixin and mixin.Label ) then
			formatters = { [mixin.Label.Right] = row.percent and Percent or Plain };
		end
		self.quiet = true;
		-- (a value saved outside the range, by an older version or by hand, is shown at its end)
		local value = math.max(low, math.min(high, tonumber(row.get()) or low));
		self.Control:Init(value, low, high, math.max(1, math.floor(( high - low ) / step + 0.5)), formatters)
		self.quiet = false;
		self.shown = row.get();
	end
	function widget:Value(row)
		local value = row.get();
		if ( value ~= self.shown ) then
			self.quiet = true;
			self.Control:SetValue(math.max(row.min or 0, math.min(row.max or 1, tonumber(value) or 0)))
			self.quiet = false;
			self.shown = value;
		end
	end
	return widget;
end

function Make.choices(parent)
	local widget = Row(parent);
	local dropdown = CreateFrame('DropdownButton', nil, widget, 'WowStyle1DropdownTemplate');
	dropdown:SetWidth(240)
	dropdown:SetPoint('LEFT', widget, 'CENTER', 4, 0)
	dropdown:SetupMenu(function(_, root)
		local row = widget.row;
		if not row then return end;
		for _, choice in ipairs(row.choices or {}) do
			local value = choice[1];
			root:CreateRadio(choice[2],
				function() return widget.row and widget.row.get() == value end,
				function() Set(widget, value) end,
				value)
		end
	end)
	Hover(dropdown, widget)
	CursorAt(dropdown, widget)
	widget.Control = dropdown;
	function widget:Show_(row)
		self.shown = row.get();
		self.Control:GenerateMenu()
	end
	function widget:Value(row)
		local value = row.get();
		if ( value ~= self.shown ) then
			self.shown = value;
			self.Control:GenerateMenu()
		end
	end
	return widget;
end

local function Hex(r, g, b)
	local function Byte(x) return math.max(0, math.min(255, math.floor(( tonumber(x) or 0 ) * 255 + 0.5))) end
	return ('ff%02x%02x%02x'):format(Byte(r), Byte(g), Byte(b));
end
ns.ColourHex = Hex;

local function RGB(hex)
	local r, g, b = tostring(hex):match('(%x%x)(%x%x)(%x%x)$');
	if not r then return 1, 1, 1 end;
	return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255;
end

function Make.colour(parent)
	local widget = Row(parent);
	local swatch = CreateFrame('Button', nil, widget);
	swatch:SetSize(26, 26)
	swatch:SetPoint('LEFT', widget, 'CENTER', 2, 0)
	swatch.Edge = swatch:CreateTexture(nil, 'BACKGROUND');
	swatch.Edge:SetAllPoints(swatch)
	swatch.Edge:SetColorTexture(0.1, 0.07, 0.04, 1)
	swatch.Colour = swatch:CreateTexture(nil, 'ARTWORK');
	swatch.Colour:SetPoint('TOPLEFT', swatch, 'TOPLEFT', 3, -3)
	swatch.Colour:SetPoint('BOTTOMRIGHT', swatch, 'BOTTOMRIGHT', -3, 3)
	swatch.Colour:SetColorTexture(1, 1, 1, 1)
	swatch:SetScript('OnClick', function()
		local row = widget.row;
		local picker = rawget(_G, 'ColorPickerFrame');
		if not ( row and type(picker) == 'table' and picker.SetupColorPickerAndShow ) then return end;
		local was = row.get();
		local r, g, b = RGB(was);
		picker:SetupColorPickerAndShow({
			r = r, g = g, b = b, hasOpacity = false, swatch = swatch,
			swatchFunc = function() Set(widget, Hex(picker:GetColorRGB())) end,
			cancelFunc = function() Set(widget, was) end,
		})
	end)
	Hover(swatch, widget)
	CursorAt(swatch, widget)
	widget.Control = swatch;
	function widget:Show_(row) self.Control.Colour:SetColorTexture(RGB(row.get())) self.shown = row.get() end
	function widget:Value(row)
		if ( row.get() ~= self.shown ) then self:Show_(row) end;
	end
	return widget;
end

function Make.button(parent)
	local widget = Row(parent);
	local button = CreateFrame('Button', nil, widget, 'UIPanelButtonTemplate');
	button:SetSize(170, 24)
	button:SetPoint('LEFT', widget, 'CENTER', 4, 0)
	button:SetScript('OnClick', function()
		local row = widget.row;
		if not ( row and type(row.click) == 'function' ) then return end;
		Play('IG_MAINMENU_OPTION')
		local ok, problem = pcall(row.click);
		if not ok then ns.Say('That button could not be pressed: ' .. tostring(problem)) end;
		ns.WindowValues()
	end)
	Hover(button, widget)
	CursorAt(button, widget)
	widget.Control = button;
	function widget:Show_(row) self.Control:SetText(row.button or row.name or '') end
	function widget:Value() end
	return widget;
end

local function Acquire(kind, parent)
	pools[kind] = pools[kind] or {};
	for _, widget in ipairs(pools[kind]) do
		if not widget.busy then
			widget.busy = true;
			return widget;
		end
	end
	local widget = Make[kind](parent);
	widget.kind = kind;
	widget.busy = true;
	pools[kind][#pools[kind] + 1] = widget;
	return widget;
end

local function Enabled(row)
	return not ( row.enabled and not row.enabled() );
end

-- greys a row out while the tick box it hangs from is off, and keeps the cursor off it
local function Grey(widget, row)
	local on = Enabled(row);
	if widget.Label then Ink(widget.Label, on and ns.INK or ns.FADED) end;
	local control = widget.Control;
	if ( control and control.SetEnabled and widget.enabled ~= on ) then
		control:SetEnabled(on)
		Nav(on and 'SmartNavigation_ClearIgnoreStatus' or 'SmartNavigation_MarkFrameIgnored', control)
	end
	widget.enabled = on;
end

---------------------------------------------------------------
-- The page
---------------------------------------------------------------
local function Clear()
	for _, list in pairs(pools) do
		for _, widget in ipairs(list) do
			widget.busy, widget.row = false, nil;
			widget:Hide()
		end
	end
	used = {};
	local front = ns.FrontPage and ns.FrontPage();
	if ( front and front:GetParent() == win.Content ) then front:Hide() end;
end

-- lays the rows out down the page, and makes the page as tall as they are
local function Lay(rows, intro)
	Clear()
	local content = win.Content;
	local width = content:GetWidth() or 600;
	local y = 0;
	local function Put(widget, tall)
		widget:ClearAllPoints()
		widget:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -y)
		widget:SetWidth(width)
		widget.y, widget.tall = y, tall;
		widget:Show()
		used[#used + 1] = widget;
		y = y + tall;
	end
	if intro then
		local widget = Acquire('intro', content);
		Fill(widget, intro);
		Put(widget, 84)
	end
	for _, row in ipairs(rows) do
		if ( row.kind == 'front' ) then
			local front = ns.FrontPage();
			front.ink = true;
			front:SetParent(content)
			front:ClearAllPoints()
			front:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -y)
			front:SetWidth(width)
			front:Show()
			ns.TryFront(ns.FrontRefresh)
			local tall = math.max(LINE, tonumber(front.tall) or 400);
			front:SetHeight(tall)
			y = y + tall;
		else
			local widget = Acquire(row.kind, content);
			widget.row = row;
			if ( row.kind == 'intro' or row.kind == 'header' ) then
				Fill(widget, { name = row.name, icon = row.icon, voice = row.voice })
			elseif ( row.kind == 'list' ) then
				Fill(widget, { name = row.name, list = row.list, empty = row.empty })
			elseif ( row.kind == 'text' ) then
				widget.Text:SetText(row.name or '')
			else
				widget.Label:SetText(row.name or '')
				widget.enabled = nil;
				widget:Show_(row)
				Grey(widget, row)
			end
			Put(widget, widget.tall or LINE)
		end
	end
	content:SetHeight(math.max(1, y + 16))
	if win.Scroll.SetVerticalScroll then win.Scroll:SetVerticalScroll(0) end;
end

-- the values shown read again (a button or the chat may have changed them), and the greying with them
function ns.WindowValues()
	for _, widget in ipairs(used) do
		local row = widget.row;
		if ( row and widget.Value and row.get ) then
			widget:Value(row)
			Grey(widget, row)
		end
	end
end

local Nav_;

local function ShowPage(part, page)
	state.part, state.page, state.searching = part, page, nil;
	local rows = page.rows;
	if page.front then rows = { { kind = 'front' } } end;
	local intro = not page.front and { name = page.name, icon = part.icon, voice = page.voice } or nil;
	Lay(rows, intro)
	local saved = Saved();
	saved.addon, saved.page = part.addon, page.name;
	Nav_()
end

local function ShowSearch(text)
	state.searching = text;
	local found = ns.SearchBook(text);
	local rows, count = {}, 0;
	for _, group in ipairs(found) do
		rows[#rows + 1] = { kind = 'header', name = group.page.name };
		for _, row in ipairs(group.rows) do
			rows[#rows + 1] = row;
			count = count + 1;
		end
	end
	if ( count == 0 ) then
		rows[1] = { kind = 'text', name = ('No options found for "%s".'):format(text) };
	end
	Lay(rows, { name = 'Search Results', icon = P:Icon(addonName),
		voice = count == 1 and '1 option found.' or ( count .. ' options found.' ) })
	Nav_()
end

---------------------------------------------------------------
-- The left column
---------------------------------------------------------------
local function NavLine(i)
	local line = navLines[i];
	if not line then
		line = CreateFrame('Button', nil, win.Column);
		line:SetHeight(NAV_PART)
		line.Lit = line:CreateTexture(nil, 'BACKGROUND');
		line.Lit:SetAllPoints(line)
		line.Lit:SetColorTexture(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3], 0.28)
		line.Hover = line:CreateTexture(nil, 'BORDER');
		line.Hover:SetAllPoints(line)
		line.Hover:SetColorTexture(1, 0.9, 0.7, 0.10)
		line.Hover:Hide()
		line.Icon = line:CreateTexture(nil, 'ARTWORK');
		line.Icon:SetSize(20, 20)
		line.Icon:SetPoint('LEFT', line, 'LEFT', 8, 0)
		line.Fold = ns.Writing(line, 13, true);
		line.Fold:SetPoint('RIGHT', line, 'RIGHT', -8, 0)
		line.Fold:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
		line.Text = ns.Writing(line, 13, true);
		line.Text:SetPoint('LEFT', line, 'LEFT', 34, 0)
		line.Text:SetPoint('RIGHT', line, 'RIGHT', -24, 0)
		line.Text:SetWordWrap(false)
		line:SetScript('OnEnter', function(self) self.Hover:Show() end)
		line:SetScript('OnLeave', function(self) self.Hover:Hide() end)
		line:SetScript('OnClick', function(self)
			Play('IG_MAINMENU_OPTION')
			if win.Search and win.Search.SetText and state.searching then
				win.Search:SetText('')
				if win.Search.ClearFocus then win.Search:ClearFocus() end;
			end
			if ( self.page ) then
				ShowPage(self.part, self.page)
			elseif ( self.part == state.part and #self.part.pages > 1 ) then
				state.open = ( state.open ~= self.part ) and self.part or false;
				Nav_()
			else
				state.open = self.part;
				ShowPage(self.part, self.part.pages[1])
			end
		end)
		navLines[i] = line;
	end
	return line;
end

-- the parts, and the further pages of the one open
Nav_ = function()
	local b = ns.Book();
	local y, n = 6, 0;
	local top = win.Search and 40 or 8;
	for _, part in ipairs(b.parts) do
		n = n + 1;
		local line = NavLine(n);
		line.part, line.page = part, nil;
		line:ClearAllPoints()
		line:SetPoint('TOPLEFT', win.Column, 'TOPLEFT', 6, -( top + y ))
		line:SetPoint('TOPRIGHT', win.Column, 'TOPRIGHT', -6, -( top + y ))
		line:SetHeight(NAV_PART)
		if part.icon then line.Icon:SetTexture(part.icon) line.Icon:Show() else line.Icon:Hide() end;
		line.Text:SetPoint('LEFT', line, 'LEFT', 34, 0)
		line.Text:SetText(part.name)
		line.Text:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
		local open = ( state.open == nil and part == state.part ) or state.open == part;
		line.Fold:SetText(#part.pages > 1 and ( open and '-' or '+' ) or '')
		local here = not state.searching and part == state.part and ( state.page == part.pages[1] );
		if here then line.Lit:Show() else line.Lit:Hide() end;
		line:Show()
		y = y + NAV_PART;
		if ( open and #part.pages > 1 ) then
			for i = 2, #part.pages do
				local page = part.pages[i];
				n = n + 1;
				local sub = NavLine(n);
				sub.part, sub.page = part, page;
				sub:ClearAllPoints()
				sub:SetPoint('TOPLEFT', win.Column, 'TOPLEFT', 6, -( top + y ))
				sub:SetPoint('TOPRIGHT', win.Column, 'TOPRIGHT', -6, -( top + y ))
				sub:SetHeight(NAV_PAGE)
				sub.Icon:Hide()
				sub.Fold:SetText('')
				sub.Text:SetPoint('LEFT', sub, 'LEFT', 44, 0)
				sub.Text:SetText(page.short)
				sub.Text:SetTextColor(ns.CREAM[1], ns.CREAM[2], ns.CREAM[3])
				local lit = not state.searching and state.page == page;
				if lit then sub.Lit:Show() else sub.Lit:Hide() end;
				sub:Show()
				y = y + NAV_PAGE;
			end
		end
	end
	for i = n + 1, #navLines do navLines[i]:Hide() end
end

---------------------------------------------------------------
-- The window
---------------------------------------------------------------
-- A texture of ours, over a plain color, so the window is never see-through if a picture is missing.
local function Cloth(frame, picture, r, g, b)
	local under = frame:CreateTexture(nil, 'BACKGROUND');
	under:SetAllPoints(frame)
	under:SetColorTexture(r, g, b, 1)
	local over = frame:CreateTexture(nil, 'BORDER');
	over:SetAllPoints(frame)
	over:SetTexture(ns.MEDIA .. picture)
	return over;
end

-- a thin dark edge round a frame
local function Edge(frame, r, g, b)
	for _, side in ipairs({ { 'TOPLEFT', 'TOPRIGHT', 0, 2 }, { 'BOTTOMLEFT', 'BOTTOMRIGHT', 0, 2 },
		{ 'TOPLEFT', 'BOTTOMLEFT', 2, 0 }, { 'TOPRIGHT', 'BOTTOMRIGHT', 2, 0 } }) do
		local line = frame:CreateTexture(nil, 'OVERLAY');
		line:SetColorTexture(r, g, b, 1)
		line:SetPoint(side[1], frame, side[1], 0, 0)
		line:SetPoint(side[2], frame, side[2], 0, 0)
		if ( side[3] > 0 ) then line:SetWidth(side[3]) else line:SetHeight(side[4]) end;
	end
end

local function Place()
	local saved = Saved();
	win:ClearAllPoints()
	if ( type(saved.x) == 'number' and type(saved.y) == 'number' ) then
		win:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', saved.x, saved.y)
	else
		win:SetPoint('CENTER', UIParent, 'CENTER', 0, 20)
	end
end

local function Build()
	win = CreateFrame('Frame', NAME, UIParent);
	win:Hide()
	win:SetSize(WIDE, TALL)
	win:SetFrameStrata('HIGH')        -- (as the game's options window: the color picker and the menus open above it)
	win:EnableMouse(true)
	if win.SetToplevel then win:SetToplevel(true) end;
	if win.SetMovable then win:SetMovable(true) end;
	if win.SetClampedToScreen then win:SetClampedToScreen(true) end;
	Cloth(win, 'parchment', 0.80, 0.70, 0.52);
	Edge(win, 0.16, 0.10, 0.05)

	-- the title band: the banner, the name, a row of stitches; dragged to move the window
	local band = CreateFrame('Frame', nil, win);
	band:SetPoint('TOPLEFT', win, 'TOPLEFT', 0, 0)
	band:SetPoint('TOPRIGHT', win, 'TOPRIGHT', 0, 0)
	band:SetHeight(BAND)
	local dark = band:CreateTexture(nil, 'BACKGROUND');
	dark:SetAllPoints(band)
	dark:SetColorTexture(0.10, 0.07, 0.05, 1)
	local banner = band:CreateTexture(nil, 'ARTWORK');
	banner:SetPoint('TOPRIGHT', band, 'TOPRIGHT', 0, 0)
	banner:SetSize(BAND * 3, BAND)
	banner:SetTexture(ns.MEDIA .. 'banner')
	banner:SetTexCoord(0.62, 1, 0.05, 0.43)
	band.Title = ns.Writing(band, 26);
	band.Title:SetPoint('LEFT', band, 'LEFT', 22, 4)
	band.Title:SetText('Patchwerk Forever')
	band.Title:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
	band.Under = ns.Writing(band, 12, true);
	band.Under:SetPoint('TOPLEFT', band.Title, 'BOTTOMLEFT', 2, -2)
	band.Under:SetText('Options')
	band.Under:SetTextColor(ns.CREAM[1], ns.CREAM[2], ns.CREAM[3])
	band.stitches = ns.Stitches(band, 6, 4);
	band.stitches:Fit(WIDE)
	band:EnableMouse(true)
	if band.RegisterForDrag then band:RegisterForDrag('LeftButton') end;
	band:SetScript('OnDragStart', function() if win.StartMoving then win:StartMoving() end end)
	band:SetScript('OnDragStop', function()
		if win.StopMovingOrSizing then win:StopMovingOrSizing() end;
		local saved = Saved();
		saved.x, saved.y = win:GetLeft(), win:GetTop();
	end)
	win.Band = band;
	local close = CreateFrame('Button', nil, win, 'UIPanelCloseButton');
	close:SetPoint('TOPRIGHT', win, 'TOPRIGHT', -4, -4)
	close:SetScript('OnClick', function() win:Hide() end)

	-- the left column: the search box and the parts
	local column = CreateFrame('Frame', nil, win);
	column:SetPoint('TOPLEFT', win, 'TOPLEFT', 2, -BAND)
	column:SetPoint('BOTTOMLEFT', win, 'BOTTOMLEFT', 2, FOOT)
	column:SetWidth(COLUMN)
	Cloth(column, 'leather', 0.30, 0.19, 0.11);
	win.Column = column;
	local search = CreateFrame('EditBox', nil, column, 'SearchBoxTemplate');
	search:SetSize(COLUMN - 30, 22)
	search:SetPoint('TOPLEFT', column, 'TOPLEFT', 16, -10)
	if search.SetAutoFocus then search:SetAutoFocus(false) end;
	if ( search.Instructions and search.Instructions.SetText ) then search.Instructions:SetText('Search') end;
	search:HookScript('OnTextChanged', function(box)
		local text = box:GetText() or '';
		if ( #text >= 2 ) then
			ShowSearch(text)
		elseif state.searching then
			local part, page = state.part, state.page;
			if ( part and page ) then ShowPage(part, page) end;
		end
	end)
	win.Search = search;

	-- the page, scrolling
	local scroll = CreateFrame('ScrollFrame', nil, win, 'UIPanelScrollFrameTemplate');
	scroll:SetPoint('TOPLEFT', column, 'TOPRIGHT', 12, -10)
	scroll:SetPoint('BOTTOMRIGHT', win, 'BOTTOMRIGHT', -32, FOOT + 6)
	local content = CreateFrame('Frame', nil, scroll);
	content:SetSize(WIDE - COLUMN - 60, 400)
	scroll:SetScrollChild(content)
	win.Scroll, win.Content = scroll, content;

	-- the foot: a row of stitches, the version, Close
	local foot = CreateFrame('Frame', nil, win);
	foot:SetPoint('BOTTOMLEFT', win, 'BOTTOMLEFT', 0, 0)
	foot:SetPoint('BOTTOMRIGHT', win, 'BOTTOMRIGHT', 0, 0)
	foot:SetHeight(FOOT)
	local footDark = foot:CreateTexture(nil, 'BACKGROUND');
	footDark:SetAllPoints(foot)
	footDark:SetColorTexture(0.10, 0.07, 0.05, 1)
	foot.Version = ns.Writing(foot, 11, true);
	foot.Version:SetPoint('LEFT', foot, 'LEFT', 18, 0)
	foot.Version:SetText('Patchwerk Forever ' .. ( ns.Meta(addonName, 'Version') or '' ))
	foot.Version:SetTextColor(0.6, 0.6, 0.6)
	local done = CreateFrame('Button', nil, foot, 'UIPanelButtonTemplate');
	done:SetSize(110, 24)
	done:SetPoint('RIGHT', foot, 'RIGHT', -14, 0)
	done:SetText(rawget(_G, 'CLOSE') or 'Close')
	done:SetScript('OnClick', function() win:Hide() end)
	win.Done = done;

	local wait = 0;
	win:SetScript('OnUpdate', function(_, elapsed)
		wait = wait - ( elapsed or 0 );
		if ( wait > 0 ) then return end;
		wait = EVERY;
		ns.WindowValues()
	end)
	win:SetScript('OnShow', function() Play('IG_CHARACTER_INFO_OPEN') end)
	win:SetScript('OnHide', function() Play('IG_CHARACTER_INFO_CLOSE') HideTip() end)
	win:RegisterEvent('PLAYER_REGEN_DISABLED')
	win:SetScript('OnEvent', function()
		if not win:IsShown() then return end;
		win:Hide()
		if not saidCombat then
			saidCombat = true;
			ns.Say('Options closed for combat.')
		end
	end)
	-- Escape closes it, as it does the game's own windows
	local special = rawget(_G, 'UISpecialFrames');
	if ( type(special) == 'table' ) then table.insert(special, NAME) end;
	Place()
	return win;
end

-- Made at login, so a Stitch can tell another addon about it (Console Port's cursor).
function ns.MakeWindow()
	if not win then
		local ok, problem = pcall(Build);
		if not ok then
			-- (half made is not made: the game's options are used instead, Settings.lua)
			if win then win:Hide() end;
			win = nil;
			error(problem, 0)
		end
	end
	return win;
end

-- @param addon : whose page (none: the page last shown, else the front page)
-- @param name  : the page's name ("Sparkle: Appearance"; none: the addon's first)
-- @return true when it opened
function ns.OpenWindow(addon, name)
	if InCombatLockdown() then
		ns.Say('Options cannot be opened in combat.')
		return false;
	end
	ns.MakeWindow()
	local saved = Saved();
	if not addon then addon, name = saved.addon, saved.page end;
	local part, page = ns.FindPage(addon, name);
	if not part then return false end;
	-- (the game's options window, if open, is put away so the two are not on top of each other)
	local panel = rawget(_G, 'SettingsPanel');
	local hide = rawget(_G, 'HideUIPanel');
	if ( type(panel) == 'table' and panel.IsShown and panel:IsShown() and type(hide) == 'function' ) then
		pcall(hide, panel)
	end
	state.open = part;
	if ( win.Search and win.Search.SetText ) then win.Search:SetText('') end;
	win:Show()
	ShowPage(part, page)
	return true;
end

function ns.CloseWindow()
	if win then win:Hide() end;
end

function ns.WindowShown()
	return win and win:IsShown() and true or false;
end

function ns.WindowFrame()
	return win;
end

-- (for the checks too) the addon and the page shown, and what a search shows
function ns.WindowCurrent()
	if not ( win and win:IsShown() ) then return nil end;
	return state.part and state.part.addon, state.page and state.page.name, state.searching;
end

-- (for the checks) the widgets on the page now, and the lines on the left
function ns.WindowShownRows()
	return used, navLines;
end
