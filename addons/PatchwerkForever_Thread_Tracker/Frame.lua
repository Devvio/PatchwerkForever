-- Thread (Tracker): the frame, and how what is in it is laid out.
--
-- The tracker is one frame holding sections one under another: the guide's steps, the quests you
-- track, and in time more. A section is a heading (its name, a short note on the right, a row of
-- stitches under it) and under that its blocks. A block is a title and its lines: a quest and its
-- objectives. Everything drawn is kept and used again, so drawing the list anew makes nothing new.
--
-- Another file adds a section with
--     ns.AddSection(id, order, read)
-- where read() gives { title =, note =, blocks = { { key =, title =, r =, g =, b =, lines = { { text =, done = } } } } },
-- or nothing when the section has nothing to show. Sections are drawn in the order of `order`.
-- ns.Refresh() asks for the list to be drawn again; it is done at most ten times a second.
--
-- The frame is as tall as what is in it, up to a height you set; past that the list scrolls with the
-- mouse wheel. Clicking a heading folds its section. The frame lets clicks through everywhere else.
--
-- Kept in PatchwerkForever_Thread_TrackerDB: place = { point, relative point, x, y } once you have
-- moved it, and folded = { [section] = true }.
local ADDON, ns = ...
if not ns.linked then return end

local PAD = 8                 -- room round the edge
local GAP = 6                 -- between two blocks
local INDENT = 10             -- of a block's lines under its title
local EVERY = 0.1             -- seconds between two drawings, at least
local WHEEL = 40              -- pixels a notch of the mouse wheel scrolls
local STITCH, STITCH_GAP = 7, 5

local sections = {}
local frame, back, body, content, handle
local heads, blocks = {}, {}
local scroll, dirty, last, unlocked = 0, true, 0, false

function ns.AddSection(id, order, read)
	sections[#sections + 1] = { id = id, order = order, read = read }
	table.sort(sections, function(a, b) return a.order < b.order end)
end

function ns.Refresh()
	dirty = true
end

local function Saved()
	local db = _G.PatchwerkForever_Thread_TrackerDB
	if type(db) ~= 'table' then
		db = {}
		_G.PatchwerkForever_Thread_TrackerDB = db
	end
	db.folded = type(db.folded) == 'table' and db.folded or {}
	return db
end
ns.Saved = Saved

local function Font(fs, size)
	local path = GameFontNormal and GameFontNormal.GetFont and GameFontNormal:GetFont()
	if not (path and fs:SetFont(path, size, '')) then
		fs:SetFont('Fonts\\FRIZQT__.TTF', size, '')
	end
	if fs.SetShadowOffset then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 0.9)
	end
end

local function Writing(parent, justify)
	local fs = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	fs:SetJustifyH(justify or 'LEFT')
	fs:SetWordWrap(true)
	return fs
end

-- How tall a piece of writing stands (the game says nothing until it has been drawn once: then a line's worth).
local function Tall(fs, size)
	local h = fs:GetStringHeight()
	if not h or h < size then h = size end
	return math.ceil(h)
end

---------------------------------------------------------------------------
-- Its place
---------------------------------------------------------------------------
local function Place()
	local place = Saved().place
	frame:ClearAllPoints()
	if type(place) == 'table' and place[1] then
		frame:SetPoint(place[1], UIParent, place[2] or place[1], place[3] or 0, place[4] or 0)
	else
		frame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -40, -260)       -- under the minimap, where the game's is
	end
end

local function Make()
	frame = CreateFrame('Frame', 'PatchwerkForeverTracker', UIParent)
	frame:SetFrameStrata('LOW')
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(false)
	back = frame:CreateTexture(nil, 'BACKGROUND')
	back:SetAllPoints(frame)
	body = CreateFrame('Frame', nil, frame)
	body:SetAllPoints(frame)
	body:SetClipsChildren(true)
	body:EnableMouse(false)
	body:SetScript('OnMouseWheel', function(_, delta)
		scroll = scroll - delta * WHEEL
		ns.Refresh()
	end)
	content = CreateFrame('Frame', nil, body)

	-- a bar to drag it by, there only while it is unlocked
	handle = CreateFrame('Button', nil, frame)
	handle:SetPoint('BOTTOMLEFT', frame, 'TOPLEFT', 0, 2)
	handle:SetPoint('BOTTOMRIGHT', frame, 'TOPRIGHT', 0, 2)
	handle:SetHeight(18)
	local bar = handle:CreateTexture(nil, 'BACKGROUND')
	bar:SetAllPoints(handle)
	bar:SetColorTexture(0.84, 0.64, 0.36, 0.55)
	handle.words = Writing(handle, 'CENTER')
	handle.words:SetPoint('CENTER', handle, 'CENTER', 0, 0)
	Font(handle.words, 11)
	handle.words:SetText('drag to move   /tracker lock')
	handle:RegisterForDrag('LeftButton')
	handle:SetScript('OnDragStart', function() frame:StartMoving() end)
	handle:SetScript('OnDragStop', function()
		frame:StopMovingOrSizing()
		local point, _, relative, x, y = frame:GetPoint(1)
		if point then Saved().place = { point, relative, x, y } end
	end)
	handle:Hide()
	Place()
end

---------------------------------------------------------------------------
-- Headings and blocks, kept and used again
---------------------------------------------------------------------------
local function Head(i)
	local head = heads[i]
	if not head then
		head = CreateFrame('Button', nil, content)
		head.title = Writing(head, 'LEFT')
		head.title:SetPoint('LEFT', head, 'LEFT', 0, 1)
		head.note = Writing(head, 'RIGHT')
		head.note:SetPoint('RIGHT', head, 'RIGHT', 0, 1)
		head.stitches = {}
		head:SetScript('OnClick', function(self)
			local folded = Saved().folded
			folded[self.id] = not folded[self.id] or nil
			ns.Refresh()
		end)
		heads[i] = head
	end
	return head
end

-- the row of stitches under a heading
local function Stitch(head, width, r, g, b)
	local n = math.floor((width + STITCH_GAP) / (STITCH + STITCH_GAP))
	for i = 1, n do
		local s = head.stitches[i]
		if not s then
			s = head:CreateTexture(nil, 'ARTWORK')
			head.stitches[i] = s
		end
		s:SetColorTexture(r, g, b, 0.75)
		s:SetSize(STITCH, 2)
		s:ClearAllPoints()
		s:SetPoint('TOPLEFT', head, 'BOTTOMLEFT', (i - 1) * (STITCH + STITCH_GAP), 0)
		s:Show()
	end
	for i = n + 1, #head.stitches do head.stitches[i]:Hide() end
end

local function Block(i)
	local block = blocks[i]
	if not block then
		block = CreateFrame('Frame', nil, content)
		block:EnableMouse(false)
		block.title = Writing(block, 'LEFT')
		block.title:SetPoint('TOPLEFT', block, 'TOPLEFT', 0, 0)
		block.lines = {}
		blocks[i] = block
	end
	return block
end

-- Writes a block's title and lines into it. Returns how tall it came out.
local function Fill(block, data, width, size)
	Font(block.title, size + 1)
	block.title:SetWidth(width)
	block.title:SetText(data.title or '')
	block.title:SetTextColor(data.r or 1, data.g or 0.82, data.b or 0)
	local h = Tall(block.title, size + 1)
	local lr, lg, lb = ns.RGB(ns.Get('lookLine'))
	local dr, dg, db = ns.RGB(ns.Get('lookDone'))
	local lines = data.lines or {}
	for i, line in ipairs(lines) do
		local fs = block.lines[i]
		if not fs then
			fs = Writing(block, 'LEFT')
			block.lines[i] = fs
		end
		Font(fs, size)
		fs:SetWidth(width - INDENT)
		fs:SetText('- ' .. tostring(line.text))
		if line.r then
			fs:SetTextColor(line.r, line.g, line.b)
		elseif line.done then
			fs:SetTextColor(dr, dg, db)
		else
			fs:SetTextColor(lr, lg, lb)
		end
		fs:ClearAllPoints()
		fs:SetPoint('TOPLEFT', block, 'TOPLEFT', INDENT, -(h + 2))
		fs:Show()
		h = h + 2 + Tall(fs, size)
	end
	for i = #lines + 1, #block.lines do block.lines[i]:Hide() end
	return h
end

---------------------------------------------------------------------------
-- Drawing the list
---------------------------------------------------------------------------
local function Render()
	if not ns.Get('on') then
		if frame then frame:Hide() end
		return
	end
	if not frame then Make() end
	local width, size = ns.Get('width') or 260, ns.Get('fontSize') or 12
	local inner = width - 2 * PAD
	local folded = Saved().folded
	local hr, hg, hb = ns.RGB(ns.Get('lookHeader'))
	local y, usedHeads, usedBlocks = PAD, 0, 0
	for _, section in ipairs(sections) do
		local data = ns.Try('the ' .. section.id .. ' list', section.read)
		if type(data) == 'table' and type(data.blocks) == 'table' and #data.blocks > 0 then
			usedHeads = usedHeads + 1
			local head = Head(usedHeads)
			head.id = section.id
			Font(head.title, size + 1)
			Font(head.note, size - 1)
			head.title:SetText(data.title or section.id)
			head.title:SetTextColor(hr, hg, hb)
			head.note:SetText((data.note or '') .. (folded[section.id] and '  +' or ''))
			head.note:SetTextColor(hr * 0.8, hg * 0.8, hb * 0.8)
			head:ClearAllPoints()
			head:SetPoint('TOPLEFT', content, 'TOPLEFT', PAD, -y)
			head:SetSize(inner, size + 6)
			Stitch(head, inner, hr, hg, hb)
			head:Show()
			y = y + size + 6 + 6
			if not folded[section.id] then
				for _, each in ipairs(data.blocks) do
					usedBlocks = usedBlocks + 1
					local block = Block(usedBlocks)
					local h = Fill(block, each, inner, size)
					block:ClearAllPoints()
					block:SetPoint('TOPLEFT', content, 'TOPLEFT', PAD, -y)
					block:SetSize(inner, h)
					block:Show()
					y = y + h + GAP
				end
			end
			y = y + 2
		end
	end
	for i = usedHeads + 1, #heads do heads[i]:Hide() end
	for i = usedBlocks + 1, #blocks do blocks[i]:Hide() end
	if usedHeads == 0 then
		frame:Hide()
		return
	end
	local total = y + PAD - 2
	local tall = math.min(total, ns.Get('height') or 450)
	scroll = math.max(0, math.min(scroll, total - tall))
	frame:SetScale((ns.Get('scale') or 100) / 100)
	frame:SetSize(width, tall)
	content:SetSize(width, total)
	content:ClearAllPoints()
	content:SetPoint('TOPLEFT', body, 'TOPLEFT', 0, scroll)
	-- (the wheel is taken only while there is more than fits: else it is left to the camera)
	body:EnableMouseWheel(total > tall)
	back:SetColorTexture(0, 0, 0, (ns.Get('back') or 25) / 100)
	if unlocked then handle:Show() else handle:Hide() end
	frame:Show()
end

-- (for the checks) what is on screen: the headings and blocks in use, as plain text
function ns.Shown()
	if not (frame and frame:IsShown()) then return nil end
	local out = {}
	for _, head in ipairs(heads) do
		if head:IsShown() then out[#out + 1] = '# ' .. (head.title:GetText() or '') .. ' | ' .. (head.note:GetText() or '') end
	end
	for _, block in ipairs(blocks) do
		if block:IsShown() then
			out[#out + 1] = block.title:GetText() or ''
			for _, fs in ipairs(block.lines) do
				if fs:IsShown() then out[#out + 1] = '  ' .. (fs:GetText() or '') end
			end
		end
	end
	return out
end

---------------------------------------------------------------------------
-- Moving, folding
---------------------------------------------------------------------------
-- on: true to unlock, false to lock, nothing to turn it over
function ns.Unlock(on)
	if on == nil then on = not unlocked end
	unlocked = on and true or false
	if unlocked and not ns.Get('on') then
		ns.Print('the tracker is switched off: /tracker on shows it.')
		unlocked = false
		return
	end
	ns.Print(unlocked and 'drag it by the bar along its top. /tracker lock fixes it there.' or 'fixed where it is.')
	Render()
end

function ns.ResetPlace()
	Saved().place = nil
	if frame then Place() end
	ns.Print('back under the minimap.')
end

-- Folds every section up; with all folded already, opens them all.
function ns.Fold()
	local folded = Saved().folded
	local open = false
	for _, section in ipairs(sections) do
		if not folded[section.id] then open = true end
	end
	for _, section in ipairs(sections) do
		folded[section.id] = open or nil
	end
	ns.Refresh()
end

---------------------------------------------------------------------------
-- When it is drawn
---------------------------------------------------------------------------
local driver = CreateFrame('Frame')
driver:SetScript('OnUpdate', function()
	if not dirty then return end
	local now = GetTime()
	if now - last < EVERY then return end
	dirty, last = false, now
	ns.Try('the tracker', Render)
end)

for _, event in ipairs({ 'PLAYER_ENTERING_WORLD', 'QUEST_LOG_UPDATE', 'QUEST_WATCH_LIST_CHANGED', 'QUEST_WATCH_UPDATE',
	'QUEST_ACCEPTED', 'QUEST_REMOVED', 'QUEST_TURNED_IN', 'UNIT_QUEST_LOG_CHANGED', 'PLAYER_LEVEL_UP',
	'ZONE_CHANGED_NEW_AREA', 'UI_SCALE_CHANGED' }) do
	ns.Try('listening for ' .. event, ns.On, event, ns.Refresh)
end
ns.OnSetting(function() ns.Refresh() end)
