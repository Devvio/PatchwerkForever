-- Thread (Tracker): dragging a stop of My Route to another place in it.
--
-- Rows of My Route, in the tracker's section and in its window (Editor.lua), can be dragged with the
-- left button. While you drag, a ghost of the row follows the pointer and a gold line shows where it
-- would land; let go and the stop is moved there (the base's MyRoute:Move). Let go away from the
-- rows, or press Escape, and nothing moves.
--
--     ns.DragBegin(row, spec)   a drag starts on `row`; spec = { from = its place in the list,
--                               key = its stop's key, text = what the ghost says,
--                               rows = fn() -> { { frame =, index = }, ... } the rows it may land
--                               among, top to bottom }
--     ns.DragStop()             it is let go (OnDragStop, or OnMouseUp where the game sends none)
--     ns.DragCancel()           it is called off
--     ns.Dragging()             a drag is under way
--     ns.DragJustEnded()        a drag ended this very moment: the button let go is not a click
--
-- Nothing here is of the game's secure kind, so it works in a fight. The one thing left out there is
-- Escape: telling the game to pass every key but Escape on is not allowed in a fight, and a frame that
-- kept the keys would stop you moving. In a fight a drag is called off by letting go off the rows.
-- A gamepad cannot drag: the rows' menus (Move Up, Move Down, Move To Top) and two key bindings do
-- the same.
local ADDON, ns = ...
if not ns.linked then return end

local MARGIN = 14             -- how far off the rows a drop still counts, in the screen's units
local GHOST_W, GHOST_H = 220, 20

local drag                    -- the drag under way: the spec, and where it would land now
local endedAt                 -- when the last drag ended
local ghost, line

local function Cursor()
	local get = rawget(_G, 'GetCursorPosition')
	if type(get) ~= 'function' then return nil end
	local x, y = get()
	local s = UIParent:GetEffectiveScale()
	if not (x and y and s and s > 0) then return nil end
	return x / s, y / s
end

-- A frame's edges in UIParent's units: left, right, top, bottom; nothing while the game cannot say.
local function Edges(frame)
	local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (l and r and t and b) then return nil end
	local s = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return l * s, r * s, t * s, b * s
end

-- Where a drop at x, y would land among the rows: the place in the list it would take, and the
-- gap's height, left and right (for the gold line); nothing when it is off the rows.
local function Landing(x, y)
	if not (drag and x) then return nil end
	local rows = ns.Try('dragging', drag.rows) or {}
	local placed, left, right, top, bottom = {}, nil, nil, nil, nil
	for _, row in ipairs(rows) do
		local l, r, t, b = Edges(row.frame)
		if l then
			placed[#placed + 1] = { index = row.index, top = t, bottom = b }
			left, right = math.min(left or l, l), math.max(right or r, r)
			top, bottom = math.max(top or t, t), math.min(bottom or b, b)
		end
	end
	if #placed == 0 then return nil end
	if x < left - MARGIN or x > right + MARGIN or y > top + MARGIN or y < bottom - MARGIN then return nil end
	-- (above the middle of a row: before it; below the last row's middle: after it)
	local slot, gap = nil, nil
	for _, row in ipairs(placed) do
		if y > (row.top + row.bottom) / 2 then
			slot, gap = row.index, row.top
			break
		end
	end
	if not slot then
		local last = placed[#placed]
		slot, gap = last.index + 1, last.bottom
	end
	-- (taken out from above, the stops below it move up one)
	local to = slot > drag.from and slot - 1 or slot
	return to, gap, left, right
end

-- The ghost follows the pointer, and the gold line shows where it would land.
local function Follow()
	local x, y = Cursor()
	if not (x and drag) then return end
	ghost:ClearAllPoints()
	ghost:SetPoint('LEFT', UIParent, 'BOTTOMLEFT', x + 12, y)
	local to, gap, left, right = Landing(x, y)
	drag.to = to
	if to and to ~= drag.from then
		line:ClearAllPoints()
		line:SetPoint('LEFT', UIParent, 'BOTTOMLEFT', left, gap)
		line:SetSize(math.max(1, right - left), 2)
		line:Show()
	else
		line:Hide()
	end
end

local function Make()
	ghost = CreateFrame('Frame', nil, UIParent)
	ghost:SetFrameStrata('TOOLTIP')
	ghost:SetSize(GHOST_W, GHOST_H)
	ghost:EnableMouse(false)
	local back = ghost:CreateTexture(nil, 'BACKGROUND')
	back:SetAllPoints(ghost)
	back:SetColorTexture(0, 0, 0, 0.75)
	ghost.words = ghost:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	ghost.words:SetPoint('LEFT', ghost, 'LEFT', 6, 0)
	ghost.words:SetJustifyH('LEFT')
	ghost.words:SetWordWrap(false)
	ns.Font(ghost.words, 12)
	ghost:Hide()
	line = CreateFrame('Frame', nil, UIParent)
	line:SetFrameStrata('TOOLTIP')
	line:SetSize(GHOST_W, 2)
	line:EnableMouse(false)
	line.tex = line:CreateTexture(nil, 'OVERLAY')
	line.tex:SetAllPoints(line)
	line.tex:SetColorTexture(1, 0.82, 0, 1)
	line:Hide()
	ghost:SetScript('OnUpdate', function() ns.Try('dragging', Follow) end)
	-- Escape calls the drag off and goes no further (out of a fight: see the top of this file); every
	-- other key goes on to the game as usual, as it was set to when the drag began
	ghost:SetScript('OnKeyDown', function(self, key)
		if key ~= 'ESCAPE' then return end
		if not InCombatLockdown() then pcall(self.SetPropagateKeyboardInput, self, false) end
		ns.DragCancel()
	end)
end

-- Takes the keyboard for Escape, out of a fight only (see the top of this file).
local function Keys(on)
	if not (ghost and type(ghost.EnableKeyboard) == 'function') then return end
	if on and InCombatLockdown() then return end
	if on then pcall(ghost.SetPropagateKeyboardInput, ghost, true) end
	pcall(ghost.EnableKeyboard, ghost, on and true or false)
end

local function Finish()
	if ghost then
		Keys(false)
		ghost:Hide()
		line:Hide()
	end
	if drag and drag.row and drag.row.SetAlpha then drag.row:SetAlpha(1) end
	drag = nil
	endedAt = GetTime()
end

function ns.DragBegin(row, spec)
	if drag then Finish() end
	if not (type(spec) == 'table' and tonumber(spec.from) and type(spec.rows) == 'function') then return end
	if not ghost then Make() end
	drag = { from = spec.from, key = spec.key, rows = spec.rows, row = row }
	ghost.words:SetText(spec.text or '')
	ghost:Show()
	Keys(true)
	if row and row.SetAlpha then row:SetAlpha(0.4) end
	Follow()
end

function ns.DragStop()
	if not drag then return end
	local x, y = Cursor()
	local to = Landing(x, y)
	local from, key = drag.from, drag.key
	Finish()
	if not to or to == from then return end
	-- (the list may have changed under the drag: the stop is found again by its key)
	local MyRoute = ns.Base.MyRoute
	local entries = MyRoute:Entries()
	if key and not (entries[from] and entries[from].key == key) then
		from = nil
		for i, one in ipairs(entries) do
			if one.key == key then from = i end
		end
		if not from then return end
	end
	if ns.RouteSelect and key then ns.RouteSelect(key) end
	MyRoute:Move(from, to)
	ns.Refresh()
end

function ns.DragCancel()
	if drag then Finish() end
end

function ns.Dragging()
	return drag ~= nil
end

function ns.DragJustEnded()
	return endedAt ~= nil and endedAt == GetTime()
end

-- (for the checks) the ghost and the gold line, and where the drop would land now
function ns.DragShown()
	return ghost ~= nil and ghost:IsShown(), line ~= nil and line:IsShown(), drag and drag.to
end
