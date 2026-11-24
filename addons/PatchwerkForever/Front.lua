local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Front: Patchwerk's own page in the game's options
---------------------------------------------------------------
-- The first page under Options > AddOns > Patchwerk Forever. It
-- is a page drawn by us, not a list of the game's rows:
--
--   * the picture of Patchwerk at his bench across the top, with
--     the family's name and a line in his voice on its dark side;
--   * "What is sewn on": every part that is running, with its
--     picture, its version, what Patchwerk says of it, and a
--     button that opens its page;
--   * the parts that are for an addon you run and are not there;
--   * the base's own switches.
--
-- It is the first page of the family's options window
-- (Window.lua); where the window cannot be made, the game shows
-- it in its own options window instead (Settings.lua).

local BANNER = 3;             -- the picture is three times as wide as it is tall
local ROW = 60;               -- the height of one part's row: its name, and two lines of what is said
local NUMBER = { 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten' };

-- what Patchwerk says at the top; one is picked each time the page opens. %s: what is sewn on.
local SAYS = {
	'Patchwerk keeps the pieces in one bag. %s. All still attached.',
	'Patchwerk counted the pieces twice. %s. Same both times. Good day.',
	'Needle is sharp. Thread is long. %s, and room for more.',
	'Something fell off? Patchwerk sews it back. %s so far.',
};

local frame, rows, checks = nil, {}, {};

local function Count(n, one, many)
	return ( NUMBER[n] or tostring(n) ) .. ' ' .. ( n == 1 and one or many );
end

-- "Two stitches, three threads", or "Nothing sewn on yet".
local function SewnOn()
	local stitches, threads = 0, 0;
	for _, part in ipairs(P.Parts) do
		if part.addon:find('_Stitch_', 1, true) then stitches = stitches + 1 else threads = threads + 1 end;
	end
	local parts = {};
	if ( stitches > 0 ) then parts[#parts + 1] = Count(stitches, 'stitch', 'stitches') end;
	if ( threads > 0 ) then parts[#parts + 1] = Count(threads, 'thread', 'threads') end;
	if ( #parts == 0 ) then return 'Nothing sewn on yet' end;
	local said = table.concat(parts, ', ');
	return said:sub(1, 1):upper() .. said:sub(2);
end

local function Short(title)
	return ( tostring(title):gsub('^Patchwerk Forever:%s*', '') );
end

local function Open(addon)
	if ns.OpenWindow then ns.OpenWindow(addon) end;   -- (it says so in combat)
end

local function Row(i)
	local row = rows[i];
	if not row then
		row = CreateFrame('Frame', nil, frame);
		row:SetHeight(ROW)
		row.Icon = row:CreateTexture(nil, 'ARTWORK');
		row.Icon:SetSize(34, 34)
		row.Icon:SetPoint('LEFT', row, 'LEFT', 4, 0)
		row.Name = ns.Writing(row, 13, true);
		row.Name:SetPoint('TOPLEFT', row, 'TOPLEFT', 46, -7)
		row.Name:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -70, -7)
		row.Name:SetWordWrap(false)
		-- (the whole width of the row under the name, the button beside the name: two lines fit)
		row.Says = ns.Writing(row, 11, true);
		row.Says:SetPoint('TOPLEFT', row, 'TOPLEFT', 46, -29)
		row.Says:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -6, -29)
		row.Says:SetWordWrap(true)
		if row.Says.SetMaxLines then row.Says:SetMaxLines(2) end;
		row.Open = CreateFrame('Button', nil, row, 'UIPanelButtonTemplate');
		row.Open:SetSize(58, 22)
		row.Open:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -6, -4)
		row.Open:SetText('Open')
		row.Open:SetScript('OnClick', function(self) Open(self.addon) end)
		rows[i] = row;
	end
	return row;
end

local function Check(i)
	local check = checks[i];
	if not check then
		check = CreateFrame('CheckButton', nil, frame, 'UICheckButtonTemplate');
		check:SetSize(26, 26)
		check.Label = ns.Writing(frame, 12, true);
		check.Label:SetPoint('LEFT', check, 'RIGHT', 4, 0)
		-- as the game's own tick boxes on the other pages: its sound, and a tooltip of name and description
		check:SetScript('OnClick', function(self)
			P:SetSetting(self.key, self:GetChecked() and true or false)
			local play, kit = rawget(_G, 'PlaySound'), rawget(_G, 'SOUNDKIT');
			if ( type(play) == 'function' and type(kit) == 'table' ) then
				play(self:GetChecked() and kit.IG_MAINMENU_OPTION_CHECKBOX_ON or kit.IG_MAINMENU_OPTION_CHECKBOX_OFF)
			end
		end)
		check:SetScript('OnEnter', function(self)
			local tip = rawget(_G, 'GameTooltip');
			if not ( self.desc and type(tip) == 'table' and tip.SetOwner ) then return end;
			tip:SetOwner(self, 'ANCHOR_RIGHT')
			local title, line = rawget(_G, 'GameTooltip_SetTitle'), rawget(_G, 'GameTooltip_AddNormalLine');
			if ( type(title) == 'function' and type(line) == 'function' and self.name ) then
				title(tip, self.name)
				line(tip, self.desc, true)
			else
				tip:SetText(self.desc, 1, 1, 1, 1, true)
			end
			tip:Show()
		end)
		check:SetScript('OnLeave', function()
			local tip = rawget(_G, 'GameTooltip');
			if ( type(tip) == 'table' and tip.Hide ) then tip:Hide() end;
		end)
		checks[i] = check;
	end
	return check;
end

-- Lays the page out for the width it has, and fills it with what is installed now.
local function Refresh()
	local width = frame:GetWidth();
	if not ( width and width > 100 ) then width = 640 end;
	local tall = math.floor(width / BANNER);
	frame.Banner:SetHeight(tall)
	frame.Voice:SetWidth(math.max(120, width * 0.26))   -- (left of the candles in the picture)
	frame.stitches:Fit(width)

	-- the parts that are running, then the ones that are for an addon you run and are not there
	local list = {};
	for _, part in ipairs(P.Parts) do
		list[#list + 1] = { addon = part.addon, name = Short(part.title), version = part.version, says = ns.VoiceOf(part.addon), on = true };
	end
	for _, part in ipairs(P.Family) do
		if ( ns.IsLoaded(part.needs) and not ns.IsLoaded(part.addon) ) then
			list[#list + 1] = { addon = part.addon, name = Short(part.name), on = false,
				says = ( ns.IsInstalled(part.addon) and 'Disabled in the addon list.' or 'Not sewn on.' )
					.. ' It is for ' .. part.what .. ', which is running.' };
		end
	end
	local y = tall + 14;
	frame.Sewn:SetPoint('TOPLEFT', frame, 'TOPLEFT', 8, -y)
	frame.Sewn:SetText(#list > 0 and 'What is sewn on' or 'Nothing is sewn on yet')
	local heading = frame.ink and ns.RUST or ns.GOLD;
	frame.Sewn:SetTextColor(heading[1], heading[2], heading[3])
	y = y + 26;
	local half = math.floor(( width - 12 ) / 2);
	for i, part in ipairs(list) do
		local row = Row(i);
		local column, line = ( i - 1 ) % 2, math.floor(( i - 1 ) / 2);
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', frame, 'TOPLEFT', column * ( half + 12 ), -( y + line * ROW ))
		row:SetWidth(half)
		local icon = part.on and P:Icon(part.addon);
		if icon then
			row.Icon:SetTexture(icon)
			row.Icon:Show()
		else
			row.Icon:Hide()
		end
		row.Name:SetText(part.name .. ( part.version and ( '  |cff808080' .. part.version .. '|r' ) or '' ))
		local shade = part.on and 1 or 0.55;
		-- (on the options window's parchment, in ink: frame.ink)
		if frame.ink then
			local name, says = part.on and ns.RUST or ns.FADED, part.on and ns.INK or ns.FADED;
			row.Name:SetTextColor(name[1], name[2], name[3])
			row.Says:SetTextColor(says[1], says[2], says[3])
		else
			row.Name:SetTextColor(shade, shade, shade)
			row.Says:SetTextColor(ns.CREAM[1] * shade, ns.CREAM[2] * shade, ns.CREAM[3] * shade)
		end
		row.Says:SetText(part.says or '')
		row.Open.addon = part.addon;
		if ( part.on and ns.Book and ns.Book().byAddon[part.addon] ) then row.Open:Show() else row.Open:Hide() end;
		row:Show()
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	y = y + math.ceil(#list / 2) * ROW + 10;

	-- the base's own switches
	local used = 0;
	for _, def in ipairs(P.Settings.list) do
		if ( ( def.part or addonName ) == addonName and type(def.default) == 'boolean' ) then
			used = used + 1;
			local check = Check(used);
			check.key, check.desc, check.name = def.key, def.desc, ns.Sentence(def.name or def.key);
			check:ClearAllPoints()
			check:SetPoint('TOPLEFT', frame, 'TOPLEFT', 4, -y)
			check:SetChecked(P:GetSetting(def.key) and true or false)
			check.Label:SetText(check.name)
			local ink = frame.ink and ns.INK or ns.CREAM;
			check.Label:SetTextColor(ink[1], ink[2], ink[3])
			-- (the label is part of what takes the click)
			if ( check.SetHitRectInsets and check.Label.GetStringWidth ) then
				check:SetHitRectInsets(0, -( check.Label:GetStringWidth() + 4 ), 0, 0)
			end
			check:Show()
			check.Label:Show()
			y = y + 28;
		end
	end
	for i = used + 1, #checks do
		checks[i]:Hide()
		checks[i].Label:Hide()
	end
	frame.Said:SetText(SAYS[math.random(#SAYS)]:format(SewnOn()))
	frame.tall = y + 12;          -- (how tall it is drawn: the options window makes its page this tall)
end
ns.FrontRefresh = Refresh;

-- Makes the page. The game's options window takes it as its own and shows it when it is asked for.
function ns.FrontPage()
	if frame then return frame end;
	frame = CreateFrame('Frame');
	frame:Hide()
	frame.Banner = frame:CreateTexture(nil, 'BACKGROUND');
	frame.Banner:SetTexture(ns.MEDIA .. 'banner')
	frame.Banner:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
	frame.Banner:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 0)
	frame.Banner:SetHeight(200)
	-- on the picture's dark side: the name, the version, and what Patchwerk says
	frame.Title = ns.Writing(frame, 30);
	frame.Title:SetPoint('TOPLEFT', frame.Banner, 'TOPLEFT', 22, -26)
	frame.Title:SetText('Patchwerk')
	frame.Title:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
	frame.Title2 = ns.Writing(frame, 30);
	frame.Title2:SetPoint('TOPLEFT', frame.Title, 'BOTTOMLEFT', 0, -2)
	frame.Title2:SetText('Forever')
	frame.Title2:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
	frame.Version = ns.Writing(frame, 11, true);
	frame.Version:SetPoint('TOPLEFT', frame.Title2, 'BOTTOMLEFT', 1, -4)
	frame.Version:SetText('the base, ' .. ( ns.Meta(addonName, 'Version') or '' ))
	frame.Version:SetTextColor(0.6, 0.6, 0.6)
	frame.Voice = ns.Writing(frame, 12, true);
	frame.Voice:SetPoint('TOPLEFT', frame.Version, 'BOTTOMLEFT', 0, -12)
	frame.Voice:SetWordWrap(true)
	frame.Voice:SetWidth(170)
	frame.Voice:SetTextColor(ns.CREAM[1], ns.CREAM[2], ns.CREAM[3])
	frame.Said = frame.Voice;
	-- a row of stitches along the foot of the picture
	frame.Seam = CreateFrame('Frame', nil, frame);
	frame.Seam:SetPoint('TOPLEFT', frame.Banner, 'BOTTOMLEFT', 0, -2)
	frame.Seam:SetPoint('TOPRIGHT', frame.Banner, 'BOTTOMRIGHT', 0, -2)
	frame.Seam:SetHeight(4)
	frame.stitches = ns.Stitches(frame.Seam, 0, 0);
	frame.Sewn = ns.Writing(frame, 17);
	frame.Sewn:SetTextColor(ns.GOLD[1], ns.GOLD[2], ns.GOLD[3])
	frame:SetScript('OnShow', function() ns.TryFront(Refresh) end)
	frame:SetScript('OnSizeChanged', function() if frame:IsShown() then ns.TryFront(Refresh) end end)
	return frame;
end

-- (a mistake on this page is said once in chat, and never stops the options window)
local told = false;
function ns.TryFront(fn)
	local ok, err = pcall(fn);
	if ( not ok and not told ) then
		told = true;
		ns.Say('The front page could not be drawn (' .. tostring(err) .. '). The other pages are as they were.')
	end
end

-- (for the checks) what the page shows now
function ns.FrontShown()
	if not frame then return nil end;
	local out = { said = frame.Said:GetText(), parts = {}, switches = {} };
	for _, row in ipairs(rows) do
		if row:IsShown() then
			out.parts[#out.parts + 1] = { name = row.Name:GetText(), says = row.Says:GetText(), open = row.Open:IsShown(), row = row };
		end
	end
	for _, check in ipairs(checks) do
		if check:IsShown() then out.switches[#out.switches + 1] = check end;
	end
	return out;
end
