-- Thread (Tracker): the frame, and how what is in it is laid out.
--
-- The tracker is one frame holding sections one under another: the guide's steps, the quests you
-- track, recipes, gathering. A section is a heading (its name, a short note on the right, a row of
-- stitches under it, and for a guide a thin bar of how far along you are) and under that its blocks.
-- A block is a title and its lines: a quest and its objectives. Everything drawn is kept and used
-- again, so drawing the list anew makes nothing new.
--
-- Another file adds a section with
--     ns.AddSection(id, order, read)
-- where read() gives
--     { title =, note =, bar = 0 to 1 or nil,
--       blocks = { { key =, title =, r =, g =, b =, note =, lines = { { text =, done =, r =, g =, b = } },
--                    click = function(button), mark = true, small = true } } }
-- or nothing when the section has nothing to show. Of a block: `note` is written on the right of
-- its title (a distance); `click` makes it take the mouse and is called with 'LeftButton' or
-- 'RightButton'; `mark` draws a bar beside it (the quest being followed); `small` makes it a quiet
-- heading inside the section (a zone's name). Sections are drawn in the order of `order`.
-- ns.Refresh() asks for the list to be drawn again; it is done at most ten times a second.
--
-- A block whose words change since it was last drawn glows for a moment. The frame can dim in a
-- fight, dim while the mouse is elsewhere, and hide in dungeons: three settings, all off to begin with.
-- (In a dungeon it also steps aside while the game's own tracker is let back there: ns.AsideInInstance.)
--
-- The frame is as tall as what is in it, up to a height you set; past that the list scrolls with the
-- mouse wheel or two key bindings (ns.Scroll), and the edge with more of the list past it darkens.
-- The list never scrolls by itself, with one exception that a key asks for: the quest chosen by the
-- next and previous quest bindings is brought into view (ns.Reveal). Clicking a heading folds its
-- section.
--
-- Kept in PatchwerkForever_Thread_TrackerDB: place = { point, relative point, x, y, 1 } once you have
-- moved it, and folded = { [section] = true }. The place is always a top corner of the tracker
-- against the same corner of the screen, in the screen's units, so the list grows downward from it
-- and the Scale setting does not move it. (Without the fifth field it was saved by an earlier
-- version, as the game gave it: it is made a top corner the first time the frame can be measured.)
local ADDON, ns = ...
if not ns.linked then return end

local PAD = 8                 -- room round the edge
local GAP = 6                 -- between two blocks
local INDENT = 10             -- of a block's lines under its title
local EVERY = 0.1             -- seconds between two drawings, at least
local TICK = 1                -- seconds between two drawings while something in it changes by itself (a distance, a timer)
local WHEEL = 40              -- pixels a notch of the mouse wheel scrolls
local SHADE = 14              -- pixels of an edge that darken while more of the list is past it
local STITCH, STITCH_GAP = 7, 5
local GLOW = 0.9              -- seconds a changed block glows
local AWAKE = 4               -- seconds it stays bright after a change, when it dims while the mouse is elsewhere

local sections = {}
local drawn = {}              -- functions called after each drawing (the item strip)
local frame, back, body, content, handle, shade
local heads, blocks = {}, {}
local scroll, dirty, last, unlocked = 0, true, 0, false
local scaled                  -- the scale the frame was last placed at
local reveal                  -- 'mark' or 'top': what a key asked the next drawing to scroll into view
local seen = {}               -- [section .. block key] = its words when last drawn
local changed = 0             -- when something in it last changed
local alpha = 1

function ns.AddSection(id, order, read)
	sections[#sections + 1] = { id = id, order = order, read = read }
	table.sort(sections, function(a, b) return a.order < b.order end)
end

function ns.Refresh()
	dirty = true
end

-- fn(frame) is called after each drawing; frame is nil while the tracker is not shown.
function ns.OnDrawn(fn)
	drawn[#drawn + 1] = fn
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
ns.Font = Font

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
-- The frame's own scale (the Scale setting). The game counts the offsets of a frame's place in that
-- frame's scale, so a place kept in the screen's units is divided by it.
local function Scale()
	local s = frame:GetScale()
	return (type(s) == 'number' and s > 0) and s or 1
end

local function Place()
	local place = Saved().place
	local s = Scale()
	frame:ClearAllPoints()
	if type(place) == 'table' and place[1] and place[5] then
		frame:SetPoint(place[1], UIParent, place[2] or place[1], (place[3] or 0) / s, (place[4] or 0) / s)
	elseif type(place) == 'table' and place[1] then
		-- (saved by an earlier version, in the frame's own scale: put back as it was; Render has Pin convert it)
		frame:SetPoint(place[1], UIParent, place[2] or place[1], place[3] or 0, place[4] or 0)
	else
		frame:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -40 / s, -260 / s)       -- under the minimap, where the game's is
	end
end

-- Saves where the tracker is now as a top corner, the left one in the left half of the screen and
-- the right one in the right half, and places it by that. After a drag the game anchors a frame to
-- whichever of nine points of the screen is nearest, and a list anchored by its middle or its foot
-- would move its first heading each time a line came or went.
-- Returns false while the game cannot say where the frame is.
local function Pin()
	local s = Scale()
	local left, right, top = frame:GetLeft(), frame:GetRight(), frame:GetTop()
	local wide, high = UIParent:GetWidth(), UIParent:GetHeight()
	if not (left and right and top and wide and high) then return false end
	local y = top * s - high
	if (left + right) / 2 * s > wide / 2 then
		Saved().place = { 'TOPRIGHT', 'TOPRIGHT', right * s - wide, y, 1 }
	else
		Saved().place = { 'TOPLEFT', 'TOPLEFT', left * s, y, 1 }
	end
	Place()
	return true
end

-- One edge of the list ('TOP' or 'BOTTOM') darkened, clearing toward the middle. Nothing on a
-- client that cannot draw a gradient: a plain black bar would only hide a line.
local function Edge(side)
	local tex = shade:CreateTexture(nil, 'OVERLAY')
	tex:SetPoint(side .. 'LEFT', shade, side .. 'LEFT', 0, 0)
	tex:SetPoint(side .. 'RIGHT', shade, side .. 'RIGHT', 0, 0)
	tex:SetHeight(SHADE)
	tex:SetColorTexture(0, 0, 0, 1)
	tex:Hide()
	local color = rawget(_G, 'CreateColor')
	if not (type(color) == 'function' and type(tex.SetGradient) == 'function') then return nil end
	-- (a vertical gradient runs from its first color at the bottom to its second at the top)
	local dark, clear = color(0, 0, 0, 0.75), color(0, 0, 0, 0)
	local ok = pcall(tex.SetGradient, tex, 'VERTICAL', side == 'TOP' and clear or dark, side == 'TOP' and dark or clear)
	return ok and tex or nil
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
	-- over the list, its two edges: each is darkened while more of the list is past it (it takes no mouse)
	shade = CreateFrame('Frame', nil, frame)
	shade:SetAllPoints(frame)
	shade:SetFrameLevel(content:GetFrameLevel() + 10)
	shade:EnableMouse(false)
	shade.top, shade.bottom = Edge('TOP'), Edge('BOTTOM')

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
	handle.words:SetText('Drag to move   /tracker lock')
	handle:RegisterForDrag('LeftButton')
	handle:SetScript('OnDragStart', function() frame:StartMoving() end)
	handle:SetScript('OnDragStop', function()
		frame:StopMovingOrSizing()
		if not Pin() then
			-- (it cannot be measured just now: kept as the game gave it, and made a top corner at the next drawing)
			local point, _, relative, x, y = frame:GetPoint(1)
			if point then Saved().place = { point, relative, x, y } end
		end
		ns.Refresh()
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
		head.bar = head:CreateTexture(nil, 'ARTWORK')
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
		block = CreateFrame('Button', nil, content)
		block:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
		block.title = Writing(block, 'LEFT')
		block.title:SetPoint('TOPLEFT', block, 'TOPLEFT', 0, 0)
		block.note = Writing(block, 'RIGHT')
		block.note:SetPoint('TOPRIGHT', block, 'TOPRIGHT', 0, 0)
		block.lines = {}
		block.mark = block:CreateTexture(nil, 'ARTWORK')
		block.mark:SetPoint('TOPLEFT', block, 'TOPLEFT', -5, 0)
		block.over = block:CreateTexture(nil, 'BACKGROUND')
		block.over:SetAllPoints(block)
		block.over:SetColorTexture(1, 1, 1, 0.07)
		block.over:Hide()
		block.glow = block:CreateTexture(nil, 'BACKGROUND')
		block.glow:SetAllPoints(block)
		block.glow:Hide()
		block:SetScript('OnClick', function(self, button)
			local data = self.data
			if data and data.click then ns.Try('a click on the tracker', data.click, button, self) end
		end)
		block:SetScript('OnEnter', function(self)
			if self.data and self.data.click then self.over:Show() end
		end)
		block:SetScript('OnLeave', function(self) self.over:Hide() end)
		blocks[i] = block
	end
	return block
end

-- Writes a block's title and lines into it. Returns how tall it came out.
local function Fill(block, data, width, size)
	block.data = data
	local small = data.small
	Font(block.title, small and size - 1 or size + 1)
	Font(block.note, size - 1)
	block.note:SetText(data.note or '')
	block.note:SetTextColor(0.7, 0.7, 0.7)
	local noteWide = (data.note and data.note ~= '') and (#data.note * (size - 1) * 0.6 + 6) or 0
	block.title:SetWidth(math.max(40, width - noteWide))
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
	if data.mark then
		local hr, hg, hb = ns.RGB(ns.Get('lookHeader'))
		block.mark:SetColorTexture(hr, hg, hb, 0.95)
		block.mark:SetSize(2, h)
		block.mark:Show()
	else
		block.mark:Hide()
	end
	block:EnableMouse(data.click ~= nil)
	if not data.click then block.over:Hide() end
	return h
end

-- What a block says, to tell whether it has changed since it was last drawn.
local function Words(data)
	local parts = { data.title or '' }
	for _, line in ipairs(data.lines or {}) do
		parts[#parts + 1] = tostring(line.text) .. (line.done and '*' or '')
	end
	return table.concat(parts, '\n')
end

---------------------------------------------------------------------------
-- Drawing the list
---------------------------------------------------------------------------
local wantsTick = false

local function After(shown)
	for _, fn in ipairs(drawn) do
		ns.Try('after drawing the tracker', fn, shown and frame or nil)
	end
end

-- Whether the tracker steps aside because you are in a dungeon, a raid or a battleground: you asked
-- for that (Hide In Instances), or the game's own tracker is let back there (Quiet.lua), and two
-- lists of the same quests are not shown side by side. With the game's tracker left alone
-- everywhere (Hide Default Quest Tracker off) both are yours to have, there as anywhere.
function ns.AsideInInstance()
	if not (IsInInstance and IsInInstance()) then return false end
	return (ns.Get('hideInstance') or (ns.Get('quiet') and ns.Get('quietInstance'))) and true or false
end

local function Render()
	-- (what a key asked to see is for this drawing only: a list that is not drawn does not scroll later)
	local show = reveal
	reveal = nil
	if not ns.Get('on') or ns.AsideInInstance() then
		if frame then frame:Hide() end
		return After(false)
	end
	if not frame then Make() end
	local width, size = ns.Get('width') or 260, ns.Get('fontSize') or 12
	local inner = width - 2 * PAD
	local folded = Saved().folded
	local hr, hg, hb = ns.RGB(ns.Get('lookHeader'))
	local y, usedHeads, usedBlocks = PAD, 0, 0
	local markTop, markBottom             -- where in the list the block being followed is
	local now, live = GetTime(), {}
	wantsTick = false
	for _, section in ipairs(sections) do
		local data = ns.Try('the ' .. section.id .. ' list', section.read)
		if type(data) == 'table' and type(data.blocks) == 'table' and #data.blocks > 0 then
			if data.tick then wantsTick = true end
			usedHeads = usedHeads + 1
			local head = Head(usedHeads)
			head.id = section.id
			Font(head.title, size + 1)
			Font(head.note, size - 1)
			head.title:SetText(data.title or section.id)
			head.title:SetTextColor(hr, hg, hb)
			local note = (data.note or '') .. (folded[section.id] and '  +' or '')
			head.note:SetText(note)
			head.note:SetTextColor(hr * 0.8, hg * 0.8, hb * 0.8)
			-- (a long name, a guide's, is cut short of the note beside it, not written over it)
			head.title:SetWordWrap(false)
			head.title:SetWidth(math.max(40, inner - (note ~= '' and (#note * (size - 1) * 0.6 + 8) or 0)))
			head:ClearAllPoints()
			head:SetPoint('TOPLEFT', content, 'TOPLEFT', PAD, -y)
			head:SetSize(inner, size + 6)
			Stitch(head, inner, hr, hg, hb)
			if data.bar then
				local part = math.max(0.02, math.min(1, data.bar))
				local br, bg, bb = ns.RGB(ns.Get('lookGuide'))
				head.bar:SetColorTexture(br, bg, bb, 0.9)
				head.bar:SetSize(inner * part, 2)
				head.bar:ClearAllPoints()
				head.bar:SetPoint('TOPLEFT', head, 'BOTTOMLEFT', 0, -4)
				head.bar:Show()
				y = y + 4
			else
				head.bar:Hide()
			end
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
					if each.mark and not markTop then markTop, markBottom = y, y + h end
					y = y + h + (each.small and 2 or GAP)
					-- a block whose words have changed since it was last drawn glows for a moment
					local key = section.id .. '\n' .. tostring(each.key or each.title)
					local words = Words(each)
					live[key] = words
					if seen[key] and seen[key] ~= words and not each.small then
						changed = now
						if ns.Get('flash') then block.glowAt = now end
					end
				end
			end
			y = y + 2
		end
	end
	seen = live
	for i = usedHeads + 1, #heads do heads[i]:Hide() end
	for i = usedBlocks + 1, #blocks do
		blocks[i]:Hide()
		blocks[i].glowAt, blocks[i].data = nil, nil
	end
	if usedHeads == 0 then
		frame:Hide()
		return After(false)
	end
	local total = y + PAD - 2
	local tall = math.min(total, ns.Get('height') or 450)
	-- a key asked for the top of the list, or for the block being followed, to be in view
	if show == 'top' then
		scroll = 0
	elseif show and markTop then
		scroll = math.min(markTop - PAD, math.max(scroll, markBottom + PAD - tall))
	end
	scroll = math.max(0, math.min(scroll, total - tall))
	-- (the scale before the size and the place: both are counted in it, so a new scale means placing again)
	local scale = (ns.Get('scale') or 100) / 100
	frame:SetScale(scale)
	if scale ~= scaled then
		scaled = scale
		Place()
	end
	frame:SetSize(width, tall)
	content:SetSize(width, total)
	content:ClearAllPoints()
	content:SetPoint('TOPLEFT', body, 'TOPLEFT', 0, scroll)
	-- (the wheel is taken only while there is more than fits: else it is left to the camera)
	body:EnableMouseWheel(total > tall)
	-- an edge is darkened while more of the list than its empty rim is past it
	if shade.top then
		if scroll > PAD then shade.top:Show() else shade.top:Hide() end
	end
	if shade.bottom then
		if total - tall - scroll > PAD + GAP then shade.bottom:Show() else shade.bottom:Hide() end
	end
	back:SetColorTexture(0, 0, 0, (ns.Get('back') or 25) / 100)
	if unlocked then handle:Show() else handle:Hide() end
	frame:Show()
	-- (a place saved by an earlier version: made a top corner now that the frame has a size to measure)
	local place = Saved().place
	if type(place) == 'table' and place[1] and not place[5] then Pin() end
	After(true)
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
			local note = block.note:GetText()
			out[#out + 1] = (block.data and block.data.mark and '> ' or '') .. (block.title:GetText() or '')
				.. ((note and note ~= '') and (' | ' .. note) or '')
			for _, fs in ipairs(block.lines) do
				if fs:IsShown() then out[#out + 1] = '  ' .. (fs:GetText() or '') end
			end
		end
	end
	return out
end

-- (for the checks) the block shown whose title holds these words
function ns.BlockOf(words)
	for _, block in ipairs(blocks) do
		if block:IsShown() and (block.title:GetText() or ''):find(words, 1, true) then return block end
	end
end

-- (for the checks) how far the list is scrolled, and whether its top and its bottom edge are darkened
function ns.Scrolled()
	if not (frame and frame:IsShown()) then return nil end
	return scroll, shade.top ~= nil and shade.top:IsShown(), shade.bottom ~= nil and shade.bottom:IsShown()
end

---------------------------------------------------------------------------
-- Scrolling without a mouse
---------------------------------------------------------------------------
-- A tracker dimmed while the mouse is elsewhere is bright again for a few seconds.
function ns.Wake()
	changed = GetTime()
end

-- Asks the next drawing to scroll the block being followed (the one with the bar beside it) into
-- view; top: to scroll to the top of the list instead. For the next and previous quest bindings,
-- which can choose a quest past the edge. Nothing else calls it, so the list never moves under the
-- mouse by itself.
function ns.Reveal(top)
	reveal = top and 'top' or 'mark'
	ns.Wake()
	ns.Refresh()
end

-- Scrolls a list longer than its frame, for a key or a gamepad button: dir 1 down, -1 up, two
-- notches of the mouse wheel at a time.
function ns.Scroll(dir)
	if not (frame and frame:IsShown()) then return end
	scroll = scroll + dir * 2 * WHEEL                  -- (Render keeps it within the list)
	ns.Wake()
	ns.Refresh()
end

---------------------------------------------------------------------------
-- Moving, folding
---------------------------------------------------------------------------
-- on: true to unlock, false to lock, nothing to turn it over
function ns.Unlock(on)
	if on == nil then on = not unlocked end
	unlocked = on and true or false
	if unlocked and not ns.Get('on') then
		ns.Print('The tracker is disabled. Type /tracker on to enable it.')
		unlocked = false
		return
	end
	ns.Print(unlocked and 'Unlocked. Drag the bar above the tracker to move it, then /tracker lock.' or 'Locked.')
	Render()
end

function ns.ResetPlace()
	Saved().place = nil
	if frame then Place() end
	ns.Print('Position reset.')
	ns.Refresh()
end

-- Folds every section up; with all folded already, opens them all.
function ns.Fold()
	local folded = Saved().folded
	local open = false
	for _, head in ipairs(heads) do                -- (only the sections on screen count: one with nothing to show is not "open")
		if head:IsShown() and not folded[head.id] then open = true end
	end
	for _, section in ipairs(sections) do
		folded[section.id] = open or nil
	end
	ns.Refresh()
end

---------------------------------------------------------------------------
-- When it is drawn, and how bright
---------------------------------------------------------------------------
-- How bright the tracker should be now: full, or dimmed in a fight, or dimmed while the mouse is
-- elsewhere and nothing in it has just changed.
local function Bright()
	local low = (ns.Get('fadeTo') or 35) / 100
	if ns.Get('fadeCombat') and InCombatLockdown() then return low end
	if ns.Get('fadeIdle') then
		local over = frame.IsMouseOver and frame:IsMouseOver()
		if not over and GetTime() - changed > AWAKE then return low end
	end
	return 1
end

local driver = CreateFrame('Frame')
driver:SetScript('OnUpdate', function(_, elapsed)
	local now = GetTime()
	if wantsTick and now - last >= TICK then dirty = true end
	if dirty and now - last >= EVERY then
		dirty, last = false, now
		ns.Try('the tracker', Render)
	end
	if not (frame and frame:IsShown()) then return end
	-- its brightness, eased toward what is wanted
	local want = Bright()
	if alpha ~= want then
		local step = (elapsed or 0.02) * 3
		alpha = alpha < want and math.min(want, alpha + step) or math.max(want, alpha - step)
		frame:SetAlpha(alpha)
	end
	-- the glow of blocks that have just changed
	for _, block in ipairs(blocks) do
		if block.glowAt then
			local t = (now - block.glowAt) / GLOW
			if t >= 1 or not block:IsShown() then
				block.glowAt = nil
				block.glow:Hide()
			else
				local r, g, b = ns.RGB(ns.Get('lookHeader'))
				block.glow:SetColorTexture(r, g, b, 0.38 * (1 - t))
				block.glow:Show()
			end
		end
	end
end)

for _, event in ipairs({ 'PLAYER_ENTERING_WORLD', 'QUEST_LOG_UPDATE', 'QUEST_WATCH_LIST_CHANGED', 'QUEST_WATCH_UPDATE',
	'QUEST_ACCEPTED', 'QUEST_REMOVED', 'QUEST_TURNED_IN', 'UNIT_QUEST_LOG_CHANGED', 'PLAYER_LEVEL_UP',
	'ZONE_CHANGED_NEW_AREA', 'ZONE_CHANGED', 'SUPER_TRACKING_CHANGED', 'GROUP_ROSTER_UPDATE', 'UI_SCALE_CHANGED' }) do
	ns.Try('listening for ' .. event, ns.On, event, ns.Refresh)
end
ns.OnSetting(function() ns.Refresh() end)
