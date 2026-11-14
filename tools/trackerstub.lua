-- More of a stand-in for the game, on top of wowstub.lua, for Thread (Tracker): the quest log as the
-- game answers about it, the game's own tracker as a frame with pieces, and the frame functions a
-- list on screen needs. (lua_tracker.py.) It checks our own code runs and does sensible things with
-- these answers: it cannot check that the real game answers as the stand-in does.

function print(...)
	local out = {}
	for i = 1, select('#', ...) do out[#out + 1] = tostring((select(i, ...))) end
	STUB.messages[#STUB.messages + 1] = table.concat(out, ' ')
end
tinsert = table.insert

---------------------------------------------------------------------------
-- Frames: what a list on screen asks of them
---------------------------------------------------------------------------
STUB.touchedInCombat = {}            -- pieces whose mouse was changed during a fight: there must be none
STUB.secureInCombat = {}             -- touches of a secure button during a fight: there must be none

local function Writing(fs)
	function fs:GetText() return self.text end
	function fs:SetWidth(w) assert(w > 0, 'writing given no width') self.width = w end
	function fs:SetJustifyH(how) assert(how == 'CENTER' or how == 'LEFT' or how == 'RIGHT') end
	function fs:SetWordWrap(on) assert(type(on) == 'boolean') end
	function fs:IsShown() return self.shown end
	-- as tall as its lines: about two letters to the font's size in width
	function fs:GetStringHeight()
		local size = self.size or 12
		local across = math.max(1, math.floor((self.width or 1000) / (size * 0.55)))
		local lines = math.max(1, math.ceil(#(self.text or '') / across))
		return lines * (size + 2)
	end
	return fs
end

local function Picture(tex)
	function tex:SetColorTexture(r, g, b, a)
		assert(r and g and b and (a == nil or (a >= 0 and a <= 1)), 'a colour out of range')
		self.colour = { r, g, b, a }
	end
	function tex:SetHeight(h) assert(h > 0) end
	function tex:IsShown() return self.shown end
	-- (which point it was hung by first is kept, so a check can tell a top edge from a bottom one)
	local setPoint = tex.SetPoint
	function tex:SetPoint(point, ...)
		self.at = self.at or point
		return setPoint(self, point, ...)
	end
	-- a gradient: the first colour at the bottom (or left), the second at the top (or right)
	function tex:SetGradient(orientation, from, to)
		assert(orientation == 'VERTICAL' or orientation == 'HORIZONTAL', 'no such orientation: ' .. tostring(orientation))
		assert(type(from) == 'table' and from.made and type(to) == 'table' and to.made, 'a gradient takes two colours made by CreateColor')
		self.gradient = { orientation, from, to }
	end
	return tex
end

function CreateColor(r, g, b, a)
	assert(r and g and b, 'a colour needs red, green and blue')
	return { r = r, g = g, b = b, a = a or 1, made = true }
end

local make = CreateFrame
function CreateFrame(kind, name, parent, template)
	local frame = make(kind, name, parent)
	frame.kind, frame.mouse, frame.wheel, frame.children, frame.points = kind, kind == 'Button', false, {}, {}
	if parent and parent.children then parent.children[#parent.children + 1] = frame end
	if name then _G[name] = frame end
	local fontString, texture, setPoint, clearPoints = frame.CreateFontString, frame.CreateTexture, frame.SetPoint, frame.ClearAllPoints
	function frame:CreateFontString(...) return Writing(fontString(self, ...)) end
	function frame:CreateTexture(...) return Picture(texture(self, ...)) end
	function frame:SetPoint(point, to, rel, x, y)
		setPoint(self, point, to, rel, x, y)
		self.points[#self.points + 1] = { point, to, rel, x, y }
	end
	function frame:ClearAllPoints() clearPoints(self) self.points = {} end
	function frame:GetPoint(i)
		local p = self.points[i or 1]
		if p then return p[1], p[2], p[3], p[4], p[5] end
	end
	function frame:SetHeight(h) assert(h > 0) self.height = h end
	function frame:SetWidth(w) assert(w > 0) self.width = w end
	function frame:SetScale(s) assert(s > 0.2 and s < 3, 'a scale out of range: ' .. tostring(s)) self.scale = s end
	function frame:SetClampedToScreen(on) assert(type(on) == 'boolean') end
	function frame:SetMovable(on) self.movable = on end
	function frame:SetClipsChildren(on) assert(type(on) == 'boolean') end
	function frame:EnableMouse(on)
		assert(type(on) == 'boolean')
		if STUB.combat and self.blizzard then STUB.touchedInCombat[#STUB.touchedInCombat + 1] = self end
		assert(not self.protected, 'the mouse of a piece the game protects was changed')
		self.mouse = on
	end
	function frame:IsMouseEnabled() return self.mouse end
	function frame:EnableMouseWheel(on) assert(type(on) == 'boolean') self.wheel = on end
	function frame:IsProtected() return self.protected == true end
	function frame:IsForbidden() return false end
	function frame:GetChildren() return unpack(self.children) end
	function frame:RegisterForDrag(button) assert(button == 'LeftButton') end
	function frame:RegisterForClicks(...) self.clicks = { ... } end
	function frame:GetScale() return self.scale or 1 end
	-- Where a frame hung from the screen is, in its own units as the game gives it: worked out from
	-- its last SetPoint, its size and its scale (the offsets of a SetPoint are counted in the frame's
	-- own scale, and the screen is UIParent's size over that scale). A frame hung from anything else
	-- is where wowstub.lua says. STUB.unplaced = true: the game has not placed frames yet, and says nothing.
	local getLeft, getTop = frame.GetLeft, frame.GetTop
	local function Edges(self)
		local p = self.points[1]
		if not (p and p[2] == UIParent and type(p[1]) == 'string') then return nil end
		local s = self.scale or 1
		local wide, high = UIParent.width / s, UIParent.height / s
		local w, h = self.width or 0, self.height or 0
		local point, rel = p[1], p[3] or p[1]
		local x = (rel:find('LEFT') and 0 or rel:find('RIGHT') and wide or wide / 2) + (p[4] or 0)
		local y = (rel:find('TOP') and high or rel:find('BOTTOM') and 0 or high / 2) + (p[5] or 0)
		local left = point:find('LEFT') and x or point:find('RIGHT') and x - w or x - w / 2
		local top = point:find('TOP') and y or point:find('BOTTOM') and y + h or y + h / 2
		return left, top
	end
	function frame:GetLeft()
		if STUB.unplaced then return nil end
		return (Edges(self)) or getLeft(self)
	end
	function frame:GetTop()
		if STUB.unplaced then return nil end
		local _, top = Edges(self)
		return top or getTop(self)
	end
	function frame:GetRight()
		local left = self:GetLeft()
		return left and left + (self.width or 0)
	end
	function frame:IsMouseOver() return self.over == true end
	-- a button of the game's secure kind: made from its template. In a fight an addon may not show,
	-- hide, move, size or change it; every such touch is written down, and there must be none.
	if type(template) == 'string' and template:find('Secure', 1, true) then
		frame.secure, frame.protected, frame.attributes, frame.shown = true, true, {}, true
		local function Guard(what, fn)
			frame[what] = function(self, ...)
				if STUB.combat then STUB.secureInCombat[#STUB.secureInCombat + 1] = what .. ' on ' .. tostring(name) end
				return fn(self, ...)
			end
		end
		local show, hide, size = frame.Show, frame.Hide, frame.SetSize
		Guard('Show', show)
		Guard('Hide', hide)
		Guard('SetSize', size)
		Guard('SetPoint', function(self, point, to, rel, x, y)
			assert(to == UIParent, 'a secure button was hung from a frame that moves')
			assert(x == x and y == y, 'not a number')
			self.points[#self.points + 1] = { point, to, rel, x, y }
		end)
		Guard('ClearAllPoints', function(self) self.points = {} end)
		Guard('SetAttribute', function(self, key, value) self.attributes[key] = value end)
		function frame:GetAttribute(key) return self.attributes[key] end
	end
	if kind == 'Cooldown' then
		function frame:SetCooldown(start, duration) assert(start and duration > 0) self.cooling = { start, duration } end
		function frame:Clear() self.cooling = nil end
	end
	function frame:StartMoving() assert(self.movable, 'a frame that cannot be moved was dragged') self.moving = true end
	-- Where it was let go: the game hangs a dragged frame from whichever point of the screen it picks
	-- (the middle of an edge, a bottom corner ...), with offsets in the frame's own scale.
	-- STUB.drop = { point, relative point, x, y } says which; without it, the top left.
	function frame:StopMovingOrSizing()
		self.moving = false
		local drop = STUB.drop or { 'TOPLEFT', 'TOPLEFT', 300, -200 }
		self.points = { { drop[1], UIParent, drop[2], drop[3], drop[4] } }
	end
	return frame
end

-- the frames wowstub.lua made before this file, given what the new ones have
for _, old in ipairs({ UIParent, Minimap, WorldMapFrame }) do
	old.children, old.points = {}, {}
end
-- The screen, in UIParent's units. (Its size is chosen so that the tracker's place before it is
-- moved, 40 in from the right and 260 down, has its left edge at 800 and its top at 700: where
-- wowstub.lua says a frame is that it knows no better of, and what the item buttons were checked
-- against before a frame's place was worked out from its SetPoint.)
UIParent.width, UIParent.height = 1100, 960

---------------------------------------------------------------------------
-- The game's own tracker: a frame with pieces, one of them protected
---------------------------------------------------------------------------
ObjectiveTrackerFrame = CreateFrame('Frame', nil, UIParent)
ObjectiveTrackerFrame.blizzard, ObjectiveTrackerFrame.alpha = true, 1
do
	local module = CreateFrame('Frame', nil, ObjectiveTrackerFrame)
	local block = CreateFrame('Button', nil, module)
	local item = CreateFrame('Button', nil, block)
	item.protected = true
	for _, piece in ipairs({ module, block, item }) do piece.blizzard = true end
	STUB.gameTracker = { frame = ObjectiveTrackerFrame, module = module, block = block, item = item }
end

---------------------------------------------------------------------------
-- The quest log
---------------------------------------------------------------------------
-- STUB.log: the quest log in its order, headings and quests:
--     { heading = 'The Barrens' }  or
--     { id =, title =, level =, objectives = { { text, finished } }, complete =, failed =, ready = 'words' }
-- STUB.watched: the ids tracked, in order (wowstub.lua).
STUB.log, STUB.room = {}, 25
function STUB.Heading(name) STUB.log[#STUB.log + 1] = { heading = name } end
function STUB.Quest(q) STUB.log[#STUB.log + 1] = q return q end
local function Entry(id)
	for i, e in ipairs(STUB.log) do
		if e.id == id then return i, e end
	end
end
C_QuestLog.GetNumQuestLogEntries = function()
	local quests = 0
	for _, e in ipairs(STUB.log) do
		if e.id then quests = quests + 1 end
	end
	return #STUB.log, quests
end
C_QuestLog.GetInfo = function(i)
	local e = STUB.log[i]
	if not e then return nil end
	if e.heading then return { title = e.heading, isHeader = true } end
	return { title = e.title, questID = e.id, level = e.level, difficultyLevel = e.level, isHeader = false, isHidden = e.hidden,
		frequency = e.daily and 1 or 0, suggestedGroup = e.group or 0 }
end
C_QuestLog.GetLogIndexForQuestID = function(id) return (Entry(id)) end
C_QuestLog.GetTitleForQuestID = function(id) local _, e = Entry(id) return e and e.title end
C_QuestLog.GetQuestObjectives = function(id)
	local _, e = Entry(id)
	local out = {}
	for _, o in ipairs(e and e.objectives or {}) do
		out[#out + 1] = { text = o[1], finished = o[2] and true or false, type = 'monster', numFulfilled = o[3], numRequired = o[4] }
	end
	return out
end
C_QuestLog.IsComplete = function(id) local _, e = Entry(id) return e and e.complete == true end
C_QuestLog.IsFailed = function(id) local _, e = Entry(id) return e and e.failed == true end
C_QuestLog.GetMaxNumQuestsCanAccept = function() return STUB.room end
function GetQuestLogCompletionText(i) return STUB.log[i] and STUB.log[i].ready end
function GetQuestDifficultyColor(level)
	assert(type(level) == 'number')
	if level >= 20 then return { r = 1, g = 0.1, b = 0.1 } end
	if level <= 5 then return { r = 0.5, g = 0.5, b = 0.5 } end
	return { r = 1, g = 0.82, b = 0 }
end
C_AddOns.IsAddOnLoaded = function(name) return STUB.loaded and STUB.loaded[name] == true end

---------------------------------------------------------------------------
-- What a click asks of the game
---------------------------------------------------------------------------
-- STUB.zone: the zone you stand in. A quest of the log may also have: tag = '(Elite)', daily, group,
-- timed = { total, gone }, item = { id, whenDone }, pushable.
STUB.zone = 'The Barrens'
function GetRealZoneText() return STUB.zone end
function IsShiftKeyDown() return STUB.shift == true end
C_SuperTrack.SetSuperTrackedQuestID = function(id)
	assert(type(id) == 'number', 'the arrow put on something that is not a quest')
	STUB.focus = id
	STUB.Fire('SUPER_TRACKING_CHANGED')
end
C_QuestLog.RemoveQuestWatch = function(id)
	for i = #STUB.watched, 1, -1 do
		if STUB.watched[i] == id then table.remove(STUB.watched, i) end
	end
	STUB.Fire('QUEST_WATCH_LIST_CHANGED')
end
C_QuestLog.IsPushableQuest = function(id) local _, e = Entry(id) return e and e.pushable == true end
C_QuestLog.GetTimeAllowed = function(id)
	local _, e = Entry(id)
	if e and e.timed then return e.timed[1], e.timed[2] end
	return 0, 0
end
QuestUtilsOverrides = { GetQuestTagText = function(id) local _, e = Entry(id) return e and e.tag end }
QuestUtil = {
	OpenQuestDetails = function(id) assert(not STUB.combat) STUB.read = id end,
	ShareQuest = function(id) STUB.shared = id end,
}
function QuestMapQuestOptions_AbandonQuest(id) STUB.abandonAsked = id end
-- a menu at the mouse: kept, so that a check can press one of its entries
MenuUtil = { CreateContextMenu = function(owner, make)
	assert(type(owner) == 'table' and type(make) == 'function')
	local menu = { entries = {} }
	make(owner, {
		CreateTitle = function(_, text) assert(type(text) == 'string') menu.title = text end,
		CreateButton = function(_, text, fn)
			assert(type(text) == 'string' and type(fn) == 'function')
			menu.entries[#menu.entries + 1] = { text = text, press = fn }
		end,
	})
	STUB.menu = menu
end }
function STUB.Press(text)                -- press the entry of the last menu that says this
	for _, entry in ipairs(STUB.menu and STUB.menu.entries or {}) do
		if entry.text == text then return entry.press() or true end
	end
	error('no such entry in the menu: ' .. text)
end

---------------------------------------------------------------------------
-- Items, and the quests that give one to use
---------------------------------------------------------------------------
-- STUB.bags[item] = how many you carry; STUB.cooling[item] = { start, duration }.
STUB.bags, STUB.cooling, STUB.itemNames = {}, {}, {}
function GetQuestLogSpecialItemInfo(index)
	local e = STUB.log[index]
	if e and e.item then return 'item:' .. e.item[1] .. ':0:0', 5000 + e.item[1], 1, e.item[2] == true end
end
C_Item.GetItemCount = function(id) assert(type(id) == 'number') return STUB.bags[id] or 0 end
C_Item.GetItemIconByID = function(id) return 7000 + id end
C_Item.GetItemNameByID = function(id) return STUB.itemNames[id] end
C_Item.RequestLoadItemDataByID = function(id) STUB.askedFor = id end
C_Container = { GetItemCooldown = function(id)
	local c = STUB.cooling[id]
	if c then return c[1], c[2], 1 end
	return 0, 0, 1
end }

---------------------------------------------------------------------------
-- Recipes you track
---------------------------------------------------------------------------
-- STUB.recipes = { { id =, name =, needs = { { item, howMany } } } }
STUB.recipes = {}
Enum.CraftingReagentType = { Modifying = 0, Basic = 1, Finishing = 2 }
C_TradeSkillUI = {
	GetRecipesTracked = function(recraft)
		local out = {}
		if not recraft then
			for _, r in ipairs(STUB.recipes) do out[#out + 1] = r.id end
		end
		return out
	end,
	GetRecipeSchematic = function(id)
		for _, r in ipairs(STUB.recipes) do
			if r.id == id then
				local slots = {}
				for _, need in ipairs(r.needs) do
					slots[#slots + 1] = { reagents = { { itemID = need[1] } }, quantityRequired = need[2], reagentType = 1, required = true }
				end
				slots[#slots + 1] = { reagents = { { itemID = 999 } }, quantityRequired = 1, reagentType = 2, required = false }   -- (an extra, not needed)
				return { name = r.name, reagentSlotSchematics = slots }
			end
		end
	end,
	SetRecipeTracked = function(id, on)
		assert(on == false)
		for i = #STUB.recipes, 1, -1 do
			if STUB.recipes[i].id == id then table.remove(STUB.recipes, i) end
		end
	end,
	OpenRecipe = function(id) assert(not STUB.combat) STUB.openedRecipe = id end,
}

---------------------------------------------------------------------------
-- The party
---------------------------------------------------------------------------
-- STUB.party = { { name =, quests = { [id] = true } } }; STUB.raid = true in a raid.
STUB.party, STUB.told = {}, {}
function IsInGroup() return #STUB.party > 0 end
function IsInRaid() return STUB.raid == true end
function GetNumSubgroupMembers() return #STUB.party end
local unitName = UnitName
function UnitName(unit)
	local i = type(unit) == 'string' and tonumber(unit:match('^party(%d)$'))
	if i then return STUB.party[i] and STUB.party[i].name end
	return unitName(unit)
end
C_QuestLog.IsUnitOnQuest = function(unit, id)
	local i = tonumber(unit:match('^party(%d)$'))
	return STUB.party[i] ~= nil and STUB.party[i].quests[id] == true
end
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) assert(#prefix <= 16) STUB.prefix = prefix end,
	SendAddonMessage = function(prefix, text, channel)
		assert(prefix == STUB.prefix and #text <= 255 and channel == 'PARTY', 'a message the game would refuse')
		STUB.told[#STUB.told + 1] = text
	end,
}

---------------------------------------------------------------------------
-- A place run in stages
---------------------------------------------------------------------------
-- STUB.scenario = { name =, stage =, stages =, stageName =, criteria = { { description, quantity, totalQuantity, completed, duration, elapsed } } }
C_Scenario = {
	IsInScenario = function() return STUB.scenario ~= nil end,
	GetInfo = function() local s = STUB.scenario; if s then return s.name, s.stage, s.stages end end,
	GetStepInfo = function() local s = STUB.scenario; if s then return s.stageName, 'what the stage is about', #s.criteria end end,
}
C_ScenarioInfo = { GetCriteriaInfo = function(i)
	local c = STUB.scenario and STUB.scenario.criteria[i]
	if c then return { description = c[1], quantity = c[2], totalQuantity = c[3], completed = c[4] == true, duration = c[5] or 0, elapsed = c[6] or 0 } end
end }
