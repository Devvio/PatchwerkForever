local addonName, ns = ...;
local P = ns.P;
---------------------------------------------------------------
-- Options: every option of the family, in one book
---------------------------------------------------------------
-- The family's options window (Window.lua) shows a book of
-- parts, each with its pages, each page a list of rows. The book
-- is made at login, when every part has loaded, from what the
-- parts already declare:
--
--   the base       its front page (Front.lua) and, if it has
--                  any that are not switches, a page General
--   each Stitch    one page of the settings it added
--                  (AddSetting), a heading for each section
--                  when there is more than one
--   each Thread    its pages, from its ns.settings (the format
--                  is at the top of Tools.lua), and at the foot
--                  of its first page Reset To Defaults
--
-- A row is { kind =, name =, desc =, ... } with kind one of
-- check, slider, choices, colour, button, header, list. A row
-- that holds a value has get() and set(value); one with a
-- parent is greyed out while enabled() says no.
--
-- For addon authors: PatchwerkForever.Options
--   :Open(addon, page)   opens the window at that addon's page
--                        (page: its name, "Sparkle: Appearance";
--                        none: the addon's first page)
--   :Close(), :IsShown(), :Frame()
--   :Book()              the parts, pages and rows
--   :Current()           the addon and page shown
--   :Search(text)        the rows whose name or description has it

local book;

local function Tooltip(def)
	if ( def.desc and def.note ) then
		return def.desc .. '\n\n' .. def.note;
	end
	return def.desc or def.note;
end

-- "Sparkle: Appearance" is listed as "Appearance" under Sparkle (Thread)
local function Short(name)
	return name:match('^[^:]+:%s*(.+)$') or name;
end

local function NewPart(addon, name)
	local part = { addon = addon, name = name, icon = P:Icon(addon), pages = {}, byName = {} };
	return part;
end

local function NewPage(part, name, voice)
	local page = part.byName[name];
	if not page then
		page = { part = part, name = name, short = ( #part.pages == 0 ) and name or Short(name),
			voice = voice, rows = {}, first = ( #part.pages == 0 ) };
		part.pages[#part.pages + 1] = page;
		part.byName[name] = page;
	end
	return page;
end

local function Add(page, row)
	row.page = page;
	page.rows[#page.rows + 1] = row;
	return row;
end

-- the kind of control a setting gets, from its entry
local function Kind(def)
	if def.header then return 'header' end;
	if def.button then return 'button' end;
	if def.list then return 'list' end;
	if def.colour then return 'colour' end;
	if def.choices then return 'choices' end;
	if ( type(def.default) == 'number' ) then return 'slider' end;
	if ( type(def.default) == 'boolean' ) then return 'check' end;
	return nil;
end

-- a value row: what it shows and how it reads and keeps its value
local function ValueRow(def, kind, get, set, enabled)
	return { kind = kind, key = def.key, name = ns.Sentence(def.name or def.key), desc = Tooltip(def),
		default = def.default, min = def.min, max = def.max, step = def.step, percent = def.percent,
		choices = def.choices, get = get, set = set, enabled = enabled };
end

---------------------------------------------------------------
-- The parts
---------------------------------------------------------------
local function BasePart()
	local part = NewPart(addonName, 'Patchwerk Forever');
	local front = NewPage(part, 'Patchwerk Forever', ns.VoiceOf(addonName));
	front.front = true;
	-- the base's settings that are not switches (the switches are on the front page)
	for _, def in ipairs(P.Settings.list) do
		if ( ( def.part or addonName ) == addonName and type(def.default) == 'number' ) then
			local key = def.key;
			Add(NewPage(part, 'General'), ValueRow(def, 'slider',
				function() return P:GetSetting(key) end, function(value) P:SetSetting(key, value) end));
		end
	end
	return part;
end

-- each Stitch: one page, a heading a section when it has more than one
local function StitchParts(list)
	local parts, order = {}, {};
	local sections = {};
	for _, def in ipairs(P.Settings.list) do
		local part = def.part or addonName;
		if ( part ~= addonName ) then
			sections[part] = sections[part] or { count = 0 };
			if ( def.section and not sections[part][def.section] ) then
				sections[part][def.section] = true;
				sections[part].count = sections[part].count + 1;
			end
		end
	end
	local last = {};
	for _, def in ipairs(P.Settings.list) do
		local addon = def.part or addonName;
		local kind = Kind(def);
		if ( addon ~= addonName and kind ) then
			local part = parts[addon];
			if not part then
				part = NewPart(addon, ns.PageName(addon));
				parts[addon] = part;
				order[#order + 1] = part;
			end
			local page = NewPage(part, part.name, ns.VoiceOf(addon));
			if ( sections[addon].count > 1 and def.section and def.section ~= last[addon] ) then
				Add(page, { kind = 'header', name = ns.Sentence(def.section) });
			end
			last[addon] = def.section;
			local key, parentKey = def.key, def.parent;
			Add(page, ValueRow(def, kind,
				function() return P:GetSetting(key) end,
				function(value) P:SetSetting(key, value) end,
				parentKey and function() return P:GetSetting(parentKey) == true end or nil));
		end
	end
	for _, part in ipairs(order) do list[#list + 1] = part end;
end

-- each Thread tool: its pages from its settings
local function ToolPart(tool)
	local env, spec = tool.env, tool.spec;
	local first = spec.page or tool.addon;
	local part = NewPart(tool.addon, first);
	part.tool = tool;
	local settings = type(env.settings) == 'table' and env.settings or {};
	local voices = {};
	for _, def in ipairs(settings) do
		if def.voice then voices[def.page or first] = def.voice end;
	end
	local front = NewPage(part, first, voices[first] or ns.VoiceOf(tool.addon));
	for _, def in ipairs(settings) do repeat
		if def.voice then break end;
		local kind = Kind(def);
		if not kind then break end;
		local page = NewPage(part, def.page or first, voices[def.page or first]);
		local shown = ns.Sentence(def.name);
		if ( kind == 'header' ) then
			Add(page, { kind = 'header', name = shown });
		elseif ( kind == 'button' ) then
			local click = def.click;
			Add(page, { kind = 'button', name = shown, desc = def.desc, button = def.button,
				click = function() env.Try('the options page (' .. tostring(def.name) .. ')', click) end });
		elseif ( kind == 'list' ) then
			Add(page, { kind = 'list', name = def.name, list = def.list, empty = def.empty });
		else
			local key, parentKey = def.key, def.parent;
			local row = ValueRow(def, kind,
				function() return env.Get(key) end,
				function(value) env.Set(key, value) end,
				parentKey and function() return env.Get(parentKey) == true end or nil);
			row.addon = tool.addon;
			Add(page, row);
		end
	until true end
	-- at the foot of its first page: every setting back to its default (after asking)
	Add(front, { kind = 'header', name = 'Defaults', foot = true });
	Add(front, { kind = 'button', name = 'Reset To Defaults', button = 'Reset', reset = true, foot = true,
		desc = 'Reset every option of this addon, on all of its pages, to its default. Positions and saved data are not changed.',
		click = function() ns.AskReset(tool) end });
	return part;
end

local function Make()
	local parts = { BasePart() };
	local rest = {};
	for _, tool in ipairs(P.Tools) do
		local ok, part = pcall(ToolPart, tool);
		if ok then
			rest[#rest + 1] = part;
		else
			tool.env.Print('A problem in the options window (reported once): ' .. tostring(part))
		end
	end
	StitchParts(rest);
	-- after the base, in the order of their names
	table.sort(rest, function(a, b) return a.name:lower() < b.name:lower() end)
	for _, part in ipairs(rest) do parts[#parts + 1] = part end;
	local byAddon = {};
	for _, part in ipairs(parts) do byAddon[part.addon] = part end;
	return { parts = parts, byAddon = byAddon };
end

function ns.Book()
	if not book then book = Make() end;
	return book;
end

-- the part and page for an addon and a page's name (either may be missing or wrong: the first is given)
function ns.FindPage(addon, name)
	local b = ns.Book();
	local part = b.byAddon[addon or ''] or b.parts[1];
	if not part then return nil end;
	return part, ( name and part.byName[name] ) or part.pages[1];
end

---------------------------------------------------------------
-- Search
---------------------------------------------------------------
local SEARCHED = { check = true, slider = true, choices = true, colour = true, button = true, list = true };

-- @return { { page =, rows = { row, ... } }, ... }: the rows whose name or description has the text, by page
function ns.SearchBook(text)
	text = tostring(text or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
	local found = {};
	if ( #text < 2 ) then return found end;
	for _, part in ipairs(ns.Book().parts) do
		for _, page in ipairs(part.pages) do
			local rows;
			for _, row in ipairs(page.rows) do
				if SEARCHED[row.kind] then
					local words = ( tostring(row.name or '') .. '\n' .. tostring(row.desc or '') ):lower();
					if words:find(text, 1, true) then
						rows = rows or {};
						rows[#rows + 1] = row;
					end
				end
			end
			if rows then found[#found + 1] = { page = page, rows = rows } end;
		end
	end
	return found;
end

---------------------------------------------------------------
-- For addon authors
---------------------------------------------------------------
P.Options = {};
function P.Options:Open(addon, page) return ns.OpenWindow(addon, page) end
function P.Options:Close() if ns.CloseWindow then ns.CloseWindow() end end
function P.Options:IsShown() return ns.WindowShown and ns.WindowShown() or false end
function P.Options:Frame() return ns.WindowFrame and ns.WindowFrame() or nil end
function P.Options:Book() return ns.Book() end
function P.Options:Current() if ns.WindowCurrent then return ns.WindowCurrent() end end
function P.Options:Search(text) return ns.SearchBook(text) end
