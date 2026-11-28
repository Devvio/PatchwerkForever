-- Tracker (Thread): the collect list.
--
-- Any item against a number you set: "Linen Cloth 14/20". For cloth for First Aid, a reputation's
-- hand-ins, materials for crafting. A row is the item's name and, at its right, how many you have of
-- how many you want. The count goes from red to green as it fills, as a quest's counts do; a row
-- whose number is met is shown as a finished objective is, and stays until you remove it. What is in
-- your bank counts too (a setting, on to begin with). The list is kept for each character.
--
-- Two ways to add an item, and no command:
--
--   * Put it on the list. The game says when the cursor takes up or puts down something
--     (CURSOR_CHANGED) and what it holds (GetCursorInfo: 'item' and the item's number). While it
--     holds an item the Collect heading is shown, with nothing listed too, and a line under it says
--     what to do. A click on the heading or a row with the item, or a drag from the bags let go
--     there, puts the item back where it was (ClearCursor) and opens a small box of our own that
--     asks how many: Enter or Okay adds the row, Escape or Cancel does not. An item already listed
--     gets the new number.
--   * A tracked recipe's right-click menu, Collect What Is Missing (Recipes.lua): each reagent the
--     recipe's row shows too few of is added with the number the recipe needs. An item already
--     listed keeps the higher number.
--
--   left-click a row     with Routes (Thread) installed, and the item a herb or an ore it has a
--                        node for near you: a gathering run for that kind, as a click in the
--                        Gathering section starts (a second click stops it). Otherwise nothing.
--   right-click a row    Change Count, Remove
--   right-click heading  Remove Completed, Clear
--
-- Which node an item is gathered at is read off the names, the only thing the base's Gather service
-- gives: a herb's node has the herb's own name ("Peacebloom"), an ore's the ore's metal ("Copper
-- Ore" at a "Copper Vein", "Thorium Ore" at a "Rich Thorium Vein"). Only nodes near you count: the
-- service lists no others.
--
-- Nothing here is of the game's secure kind, and putting the cursor's item back is not protected,
-- so all of it works in a fight.
--
-- Kept in PatchwerkForever_Thread_TrackerDB: collect = { [character] = { { id = item, goal = n }, ... } },
-- in the order they were added.
local ADDON, ns = ...
if not ns.linked then return end

local MOST = 99999            -- the highest number an item can be given (five figures fit the box)
local FIRST = 20              -- the number the box starts at for an item not yet listed
local KINDS = 50              -- how many kinds of node near you are asked for, to find an item's
local NAME = 'PatchwerkForeverTrackerCollect'
local POPUP = 'PATCHWERKFOREVER_TRACKER_CLEAR_COLLECT'

local held = false            -- the cursor holds an item now
local waiting = false         -- an item's name was not known yet when last drawn
local box                     -- the box that asks how many

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

---------------------------------------------------------------------------
-- The list, and the items in it
---------------------------------------------------------------------------
-- This character's list. make: one is begun where there is none (to add to it).
local function List(make)
	local db = ns.Saved()
	if type(db.collect) ~= 'table' then
		if not make then return nil end
		db.collect = {}
	end
	local who = Ask(UnitGUID, 'player')
	who = (ns.Plain(who) and type(who) == 'string') and who or 'player'
	if type(db.collect[who]) ~= 'table' then
		if not make then return nil end
		db.collect[who] = {}
	end
	return db.collect[who]
end

local function Find(id)
	for i, one in ipairs(List() or {}) do
		if type(one) == 'table' and one.id == id then return i, one end
	end
	return nil
end

-- How many of an item you have: in your bags, and in your bank when that is to count.
local function Have(id)
	local bank = ns.Get('collectBank') and true or false
	local count = Ask(C_Item and C_Item.GetItemCount, id, bank, false, bank)
	if not (ns.Plain(count) and type(count) == 'number') then count = Ask(rawget(_G, 'GetItemCount'), id, bank) end
	return (ns.Plain(count) and type(count) == 'number') and count or 0
end

local function Name(id)
	local name = Ask(C_Item and C_Item.GetItemNameByID, id)
	if ns.Plain(name) and type(name) == 'string' and name ~= '' then return name end
	-- (the game has not been told this item yet: it is asked for, and the list drawn again when it comes)
	waiting = true
	Ask(C_Item and C_Item.RequestLoadItemDataByID, id)
	return 'item ' .. tostring(id)
end

local function Goal(text)
	local n = tonumber(text)
	n = n and math.floor(n)
	if not n or n < 1 then return nil end
	return math.min(n, MOST)
end

-- Lists an item with a number, or gives a listed one the new number. Said in chat.
function ns.CollectSet(id, goal)
	goal = Goal(goal)
	if not (type(id) == 'number' and goal) then return false end
	local _, one = Find(id)
	if one then
		if one.goal ~= goal then
			one.goal = goal
			ns.Print(('Count changed in Collect: %s (%d).'):format(Name(id), goal))
		end
	else
		local list = List(true)
		list[#list + 1] = { id = id, goal = goal }
		ns.Print(('Added to Collect: %s (%d).'):format(Name(id), goal))
	end
	ns.Wake()
	ns.Refresh()
	return true
end

function ns.CollectRemove(id)
	local i = Find(id)
	if not i then return false end
	table.remove(List(), i)
	ns.Print(('Removed from Collect: %s.'):format(Name(id)))
	ns.Refresh()
	return true
end

-- For a tracked recipe's menu (Recipes.lua). needs: the recipe's lines as its row shows them,
-- { item =, need =, done = } each. Every reagent the row shows too few of is listed with what the
-- recipe needs; one listed already keeps the higher number.
function ns.CollectMissing(title, needs)
	local missing, changed = 0, 0
	for _, line in ipairs(type(needs) == 'table' and needs or {}) do
		local goal = type(line) == 'table' and type(line.item) == 'number' and not line.done and Goal(line.need)
		if goal then
			missing = missing + 1
			local _, one = Find(line.item)
			if not one then
				local list = List(true)
				list[#list + 1] = { id = line.item, goal = goal }
				changed = changed + 1
			elseif (tonumber(one.goal) or 0) < goal then
				one.goal = goal
				changed = changed + 1
			end
		end
	end
	title = tostring(title or 'this recipe')
	if missing == 0 then
		ns.Print(('Nothing is missing for %s.'):format(title))
	elseif changed == 0 then
		ns.Print(('Collect already lists what is missing for %s.'):format(title))
	else
		ns.Print(('Added to Collect: %d %s for %s.'):format(changed, changed == 1 and 'item' or 'items', title))
	end
	ns.Wake()
	ns.Refresh()
end

local function RemoveCompleted()
	local list, gone = List() or {}, 0
	for i = #list, 1, -1 do
		local one = list[i]
		if type(one) == 'table' and type(one.id) == 'number' and Have(one.id) >= (tonumber(one.goal) or math.huge) then
			table.remove(list, i)
			gone = gone + 1
		end
	end
	if gone == 0 then
		ns.Print('No completed items in Collect.')
	else
		ns.Print(('Removed from Collect: %d completed %s.'):format(gone, gone == 1 and 'item' or 'items'))
	end
	ns.Refresh()
end

local function Empty()
	local list = List()
	for i = #(list or {}), 1, -1 do list[i] = nil end
	ns.Print('Collect cleared.')
	ns.Refresh()
end

-- Clears the list, after the game's yes-or-no box (as My Route's Clear asks).
local function Clear()
	local dialogs, show = rawget(_G, 'StaticPopupDialogs'), rawget(_G, 'StaticPopup_Show')
	if not (type(dialogs) == 'table' and type(show) == 'function') then
		return Empty()                                      -- (a client with no such box: cleared at once, and said)
	end
	dialogs[POPUP] = dialogs[POPUP] or {
		text = 'Remove all items from Collect?',
		button1 = rawget(_G, 'YES') or 'Yes',
		button2 = rawget(_G, 'NO') or 'No',
		OnAccept = Empty,
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
	show(POPUP)
end

---------------------------------------------------------------------------
-- The box that asks how many
---------------------------------------------------------------------------
local function Accept()
	if not (box and box.item) then return end
	local goal = Goal(box.edit:GetText())
	if not goal then
		-- (nothing, or none: the box stays for a number)
		box.edit:SetFocus()
		return
	end
	local id = box.item
	box:Hide()
	ns.CollectSet(id, goal)
end

-- A button of the box, in the game's own look.
local function BoxButton(text, fn)
	local ok, b = pcall(CreateFrame, 'Button', nil, box, 'UIPanelButtonTemplate')
	if not ok then b = CreateFrame('Button', nil, box) end
	b:SetSize(84, 22)
	b:SetText(text)
	b:SetScript('OnClick', function() ns.Try('Collect (' .. text .. ')', fn) end)
	return b
end

local function MakeBox()
	box = CreateFrame('Frame', NAME, UIParent)
	box:SetFrameStrata('DIALOG')
	box:SetClampedToScreen(true)
	box:EnableMouse(true)
	box:SetSize(230, 104)
	box:SetPoint('CENTER', UIParent, 'CENTER', 0, 120)
	box:Hide()
	local back = box:CreateTexture(nil, 'BACKGROUND')
	back:SetAllPoints(box)
	back:SetColorTexture(0, 0, 0, 0.85)
	-- a thin edge in the header color at its top and its foot, as the My Route window has
	local hr, hg, hb = ns.RGB(ns.Get('lookHeader'))
	for _, side in ipairs({ 'TOP', 'BOTTOM' }) do
		local e = box:CreateTexture(nil, 'BORDER')
		e:SetPoint(side .. 'LEFT', box, side .. 'LEFT', 0, 0)
		e:SetPoint(side .. 'RIGHT', box, side .. 'RIGHT', 0, 0)
		e:SetHeight(1)
		e:SetColorTexture(hr, hg, hb, 0.8)
	end
	box.title = box:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	box.title:SetPoint('TOPLEFT', box, 'TOPLEFT', 10, -8)
	box.title:SetJustifyH('LEFT')
	ns.Font(box.title, 13)
	box.title:SetText('Collect')
	box.title:SetTextColor(hr, hg, hb)
	box.words = box:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	box.words:SetPoint('TOPLEFT', box, 'TOPLEFT', 10, -28)
	box.words:SetJustifyH('LEFT')
	box.words:SetWordWrap(false)
	box.words:SetWidth(210)
	ns.Font(box.words, 12)
	box.ask = box:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	box.ask:SetPoint('TOPLEFT', box, 'TOPLEFT', 10, -50)
	box.ask:SetJustifyH('LEFT')
	ns.Font(box.ask, 12)
	box.ask:SetText('How many?')
	box.ask:SetTextColor(0.7, 0.7, 0.7)
	-- the number: the game's own box to type in; without its look, a plain one on a dark ground
	local ok, edit = pcall(CreateFrame, 'EditBox', nil, box, 'InputBoxTemplate')
	if not ok then
		edit = CreateFrame('EditBox', nil, box)
		pcall(edit.SetFontObject, edit, 'GameFontHighlight')
		local ground = edit:CreateTexture(nil, 'BACKGROUND')
		ground:SetAllPoints(edit)
		ground:SetColorTexture(1, 1, 1, 0.1)
	end
	edit:SetSize(70, 20)
	edit:SetPoint('TOPLEFT', box, 'TOPLEFT', 96, -46)
	edit:SetAutoFocus(false)
	edit:SetNumeric(true)
	edit:SetMaxLetters(5)
	edit:SetScript('OnEnterPressed', function() ns.Try('Collect', Accept) end)
	edit:SetScript('OnEscapePressed', function() box:Hide() end)
	box.edit = edit
	box.okay = BoxButton(rawget(_G, 'OKAY') or 'Okay', Accept)
	box.okay:SetPoint('BOTTOMLEFT', box, 'BOTTOMLEFT', 28, 8)
	box.cancel = BoxButton(rawget(_G, 'CANCEL') or 'Cancel', function() box:Hide() end)
	box.cancel:SetPoint('BOTTOMRIGHT', box, 'BOTTOMRIGHT', -28, 8)
	box:SetScript('OnHide', function(self)
		self.item = nil
		self.edit:ClearFocus()
	end)
	-- (Escape closes it when the number does not have the keyboard, as it closes the game's own windows)
	local special = rawget(_G, 'UISpecialFrames')
	if type(special) == 'table' then table.insert(special, NAME) end
end

-- Asks how many of an item to collect: its number now when it is listed, to be changed.
function ns.CollectAsk(id)
	if type(id) ~= 'number' then return end
	if not box then MakeBox() end
	local _, one = Find(id)
	box.item = id
	box.words:SetText(Name(id))
	box.edit:SetText(tostring(one and one.goal or FIRST))
	box:Show()
	box.edit:SetFocus()
	box.edit:HighlightText()
end

---------------------------------------------------------------------------
-- An item on the cursor
---------------------------------------------------------------------------
-- The item the cursor holds: its number, or nothing.
local function Held()
	local kind, id = Ask(rawget(_G, 'GetCursorInfo'))
	if not (ns.Plain(kind) and kind == 'item' and ns.Plain(id) and type(id) == 'number') then return nil end
	return id
end

-- A block's and the heading's `drop` (Frame.lua): the item the cursor holds is put back where it
-- was, and the box asks how many. False when the cursor holds no item, and the click is a click.
local function Take()
	local id = Held()
	if not id then return false end
	Ask(rawget(_G, 'ClearCursor'))
	ns.CollectAsk(id)
	return true
end

ns.Try('listening for CURSOR_CHANGED', ns.On, 'CURSOR_CHANGED', function()
	local now = Held() ~= nil
	if now == held then return end
	held = now
	if ns.Get('collect') then
		ns.Wake()                                           -- (a faded tracker is where the item is to go)
		ns.Refresh()
	end
end)

---------------------------------------------------------------------------
-- Gathering what is on the list
---------------------------------------------------------------------------
-- How well a node's name fits an item's: 3 the same name (a herb), 2 an ore's metal first in it
-- ("Copper Ore", "Copper Vein"), 1 the metal later in it ("Thorium Ore", "Rich Thorium Vein");
-- nothing when it does not. kind: 'h' for a herb's node, which fits only by its own name.
local function Fits(item, node, kind)
	item, node = item:lower(), node:lower()
	if item == node then return 3 end
	local metal = kind ~= 'h' and item:match('^(.+) ore$')
	if not metal then return nil end
	if node:sub(1, #metal + 1) == metal .. ' ' then return 2 end
	if (' ' .. node .. ' '):find(' ' .. metal .. ' ', 1, true) then return 1 end
	return nil
end

-- The kind of node an item is gathered at, by its name as a run is started for it: the one a run
-- is on for now, else the best fit among the kinds near you (spots: nearest first), else nothing.
local function Node(item, spots, state)
	if state and state.mode == 'kind' and type(state.name) == 'string' and Fits(item, state.name) then return state.name end
	local best, rank
	for _, spot in ipairs(spots) do
		local fit = type(spot) == 'table' and type(spot.name) == 'string' and Fits(item, spot.name, spot.kind)
		if fit and (not rank or fit > rank) then best, rank = spot.name, fit end
	end
	return best
end

---------------------------------------------------------------------------
-- The section
---------------------------------------------------------------------------
local function RowMenu(block, id, name)
	local entries = {}
	-- an item Routes knows the drops of: farm it (Routes with QuestieDB)
	local Gather = ns.Base.Gather
	if Gather and Gather.CanFarm and Gather:CanFarm(tostring(id)) then
		entries[#entries + 1] = { 'Farm This', function() Gather:Farm(tostring(id)) end }
	end
	entries[#entries + 1] = { 'Change Count', function() ns.CollectAsk(id) end }
	entries[#entries + 1] = { 'Remove', function() ns.CollectRemove(id) end }
	ns.Menu(block, name, entries)
end

ns.AddSection('collect', 75, function()
	if not ns.Get('collect') then return nil end
	local list = List() or {}
	if #list == 0 and not held then return nil end
	waiting = false
	local tr, tg, tb = ns.RGB(ns.Get('lookTitle'))
	local dr, dg, db = ns.RGB(ns.Get('lookDone'))
	local lr, lg, lb = ns.RGB(ns.Get('lookLine'))
	-- (what can be gathered near you is asked once a drawing, and only with something listed)
	local Gather = ns.Base.Gather
	local offers = #list > 0 and Gather and Gather:Has()
	local spots = offers and Gather:Near(KINDS) or {}
	local state = offers and Gather:State() or nil
	local blocks, complete = {}, 0
	for _, one in ipairs(list) do
		local id, goal = type(one) == 'table' and one.id, type(one) == 'table' and tonumber(one.goal)
		if type(id) == 'number' and goal then
			local have, name = Have(id), Name(id)
			local done = have >= goal
			local r, g, b, nr, ng, nb = tr, tg, tb, lr, lg, lb
			if done then
				complete = complete + 1
				r, g, b, nr, ng, nb = dr, dg, db, dr, dg, db
			elseif ns.Get('progress') and goal > 1 then
				nr, ng, nb = ns.Progress(have, goal)
			end
			local node = offers and Node(name, spots, state) or nil
			local on = node ~= nil and state ~= nil and state.mode == 'kind' and state.name == node
			local tip = {}
			if held then
				tip[1] = 'Click to collect the item you are holding.'
			elseif node then
				tip[1] = on and 'Click to stop.' or 'Click to route to the nearest node, and on to the next.'
			end
			tip[#tip + 1] = 'Right-click for more options.'
			blocks[#blocks + 1] = { key = 'collect:' .. id, title = name, r = r, g = g, b = b,
				note = ('%d/%d'):format(have, goal), noteR = nr, noteG = ng, noteB = nb, noteCounts = true,
				mark = on, tip = tip, drop = Take,
				click = function(button, block)
					if button == 'RightButton' then
						RowMenu(block, id, name)
					elseif node then
						ns.GatherStart('kind', node)
					end
				end }
		end
	end
	local rows = #blocks
	if rows == 0 then
		-- (nothing listed, and the cursor holds an item: the heading stands with a line saying what to do)
		if not held then return nil end
		blocks[1] = { key = 'hint', small = true, r = 0.6, g = 0.6, b = 0.6, drop = Take,
			title = 'Drop an item here to collect it.', tip = { 'Click to collect the item you are holding.' } }
	end
	local menu
	if rows > 0 then
		menu = function(head)
			local entries = {}
			if complete > 0 then entries[#entries + 1] = { 'Remove Completed', RemoveCompleted } end
			entries[#entries + 1] = { 'Clear', Clear }
			ns.Menu(head, 'Collect', entries)
		end
	end
	return { title = 'Collect', note = rows > 0 and tostring(rows) or nil, menu = menu, blocks = blocks,
		drop = Take, tip = held and { 'Click to collect the item you are holding.' } or nil }
end)

for _, event in ipairs({ 'BAG_UPDATE_DELAYED', 'PLAYERBANKSLOTS_CHANGED' }) do
	ns.Try('listening for ' .. event, ns.On, event, ns.Refresh)
end
ns.Try('listening for GET_ITEM_INFO_RECEIVED', ns.On, 'GET_ITEM_INFO_RECEIVED', function()
	if waiting then ns.Refresh() end
end)

-- (for the checks) the box that asks how many, and whether the cursor is taken to hold an item
function ns.CollectBox()
	return box, held
end
