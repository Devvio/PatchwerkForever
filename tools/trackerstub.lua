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
	return tex
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
	function frame:RegisterForClicks(...) end
	function frame:StartMoving() assert(self.movable, 'a frame that cannot be moved was dragged') self.moving = true end
	function frame:StopMovingOrSizing()
		self.moving = false
		self.points = { { 'TOPLEFT', UIParent, 'TOPLEFT', 300, -200 } }      -- (where it was let go)
	end
	return frame
end

-- the frames wowstub.lua made before this file, given what the new ones have
for _, old in ipairs({ UIParent, Minimap, WorldMapFrame }) do
	old.children, old.points = {}, {}
end

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
	return { title = e.title, questID = e.id, level = e.level, difficultyLevel = e.level, isHeader = false, isHidden = e.hidden }
end
C_QuestLog.GetLogIndexForQuestID = function(id) return (Entry(id)) end
C_QuestLog.GetTitleForQuestID = function(id) local _, e = Entry(id) return e and e.title end
C_QuestLog.GetQuestObjectives = function(id)
	local _, e = Entry(id)
	local out = {}
	for _, o in ipairs(e and e.objectives or {}) do
		out[#out + 1] = { text = o[1], finished = o[2] and true or false, type = 'monster' }
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
