-- A stand-in for the game, just enough of it to run Patchwerk Forever: Routes (Thread)'s files outside the game
-- (lua_shell.py). It checks that the addon's own code runs: it cannot check that the real game
-- behaves as these stand-ins do.

STUB = { messages = {}, frames = {}, tickers = {}, events = {}, lines = 0, shown = 0, settings = {},
	player = { x = 0, y = 0, map = 1, side = 'Horde', taxi = false, facing = 1.0 },
	pin = nil, time = 100, undiscovered = {} }

function strjoin(sep, ...) return table.concat({ ... }, sep) end
function tostringall(...)
	local out = {}
	for i = 1, select('#', ...) do out[i] = tostring((select(i, ...))) end
	return unpack(out)
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) STUB.messages[#STUB.messages + 1] = text end }
SlashCmdList = {}
floor = math.floor
function debugprofilestop() return os.clock() * 1000 end
function GetTime() return STUB.time end
STUB.zoom = 15                         -- how far out the camera is, in yards
function GetCameraZoom() return STUB.zoom end
function InCombatLockdown() return STUB.combat == true end
function IsInInstance() return STUB.instance == true end
STUB.cvars = { rotateMinimap = '1', SoftTargetInteract = '1', SoftTargetInteractRange = '60', SoftTargetInteractArc = '2',
	SoftTargetNameplateInteract = '0', SoftTargetIconGameObject = '0', SoftTargetIconInteract = '1' }
function GetCVar(name) return STUB.cvars[name] end
function SetCVar(name, value) assert(STUB.cvars[name] ~= nil, 'no such setting ' .. tostring(name)) STUB.cvars[name] = tostring(value) end
-- the thing the game points at: STUB.soft = { name =, guid =, cursor =, plate = a frame }
local CURSOR_FILES = { ['Interface\\Cursor\\GatherHerbs'] = 101, ['Interface\\Cursor\\Mine'] = 102,
	['Interface\\Cursor\\Interact'] = 103, ['Interface\\Cursor\\LootAll'] = 104, ['Interface\\Cursor\\Quest'] = 105 }
function GetFileIDFromPath(path) return CURSOR_FILES[path] end
-- (as on Forever: a thing in the world does not "exist" for UnitExists, only a creature does)
local function SoftIsThing() return STUB.soft ~= nil and tostring(STUB.soft.guid):sub(1, 10) == 'GameObject' end
function UnitExists(unit) return unit == 'softinteract' and STUB.soft ~= nil and not SoftIsThing() end
function UnitIsGameObject(unit) return unit == 'softinteract' and SoftIsThing() end
function UnitIsUnit(a, b) return STUB.soft ~= nil and b == 'softinteract' and a == STUB.soft.token end
function UnitGUID(unit) return unit == 'softinteract' and STUB.soft and STUB.soft.guid or nil end
-- (as on Forever: the cursor is a named piece of one shared picture, so the file's number says nothing)
function SetUnitCursorTexture(texture, unit)
	if unit == 'softinteract' and STUB.soft and STUB.soft.cursor then
		texture.icon, texture.atlas = 4217590, STUB.soft.cursor
		return true
	end
	texture.atlas = nil
	return false
end
-- soft.token set: the nameplate is only given under that name ("nameplate3"), not under "softinteract"
C_NamePlate = { GetNamePlateForUnit = function(unit)
	local soft = STUB.soft
	if not soft then return nil end
	if soft.token then return unit == soft.token and soft.plate or nil end
	return unit == 'softinteract' and soft.plate or nil
end }
function GetPlayerFacing() return STUB.player.facing end
function UnitPosition() local p = STUB.player; return p.x, p.y, 0, p.map end
function UnitFactionGroup() return STUB.player.side end
function UnitOnTaxi() return STUB.player.taxi end
function UnitName(unit)
	if unit == 'player' then return 'Walker' end
	if unit == 'softinteract' then return STUB.soft and STUB.soft.name end
	return STUB.targetName
end
function GetMinimapShape() return 'SQUARE' end
-- loot: STUB.loot = { { link =, class =, sub =, icon =, guid = }, ... }
STUB.icons, STUB.loot = 0, {}
function GetNumLootItems() return #STUB.loot end
function GetLootSlotLink(slot) return STUB.loot[slot] and STUB.loot[slot].link end
function GetLootSourceInfo(slot) return STUB.loot[slot] and STUB.loot[slot].guid end
C_Item = { GetItemInfoInstant = function(link)
	for _, item in ipairs(STUB.loot) do
		if item.link == link then return 1, 'Trade Goods', 'x', '', item.icon, item.class, item.sub end
	end
end }
Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3 } }

STUB.allLines, STUB.allTextures = {}, {}
local function Line()
	STUB.lines = STUB.lines + 1
	local line = { shown = false }
	STUB.allLines[#STUB.allLines + 1] = line
	function line:SetColorTexture(r, g, b, a) assert(r and g and b) self.colour = { r, g, b } end
	function line:SetThickness(t) assert(t > 0) self.thick = t end
	function line:SetStartPoint(point, frame, x, y) assert(x == x and y == y, 'not a number') self.ax, self.ay = x, y end
	function line:SetEndPoint(point, frame, x, y) assert(x == x and y == y, 'not a number') self.bx, self.by = x, y end
	function line:Show() if not self.shown then self.shown = true; STUB.shown = STUB.shown + 1 end end
	function line:Hide() if self.shown then self.shown = false; STUB.shown = STUB.shown - 1 end end
	return line
end

function CreateFrame(kind, name, parent)
	local frame = { scripts = {}, shown = true, level = 1, width = 1002, height = 668, parent = parent }
	function frame:RegisterEvent(event) STUB.events[event] = STUB.events[event] or {}; STUB.events[event][self] = true end
	function frame:UnregisterEvent(event) if STUB.events[event] then STUB.events[event][self] = nil end end
	function frame:SetScript(what, fn) self.scripts[what] = fn end
	function frame:HookScript(what, fn) self.scripts['hook' .. what] = fn end
	function frame:Show() self.shown = true end
	function frame:Hide() self.shown = false end
	function frame:IsShown() return self.shown end
	function frame:IsVisible() return self.shown end
	function frame:SetAllPoints(other) if other then self.width, self.height = other.width, other.height end end
	function frame:ClearAllPoints() end
	function frame:EnableMouse() end
	function frame:SetFrameStrata(strata) assert(type(strata) == 'string') self.strata = strata end
	function frame:GetFrameStrata() return self.strata or 'LOW' end
	function frame:GetEffectiveAlpha() return self.alpha or 1 end
	function frame:SetAlpha(alpha) assert(alpha >= 0 and alpha <= 1, 'alpha out of range: ' .. tostring(alpha)) self.alpha = alpha end
	function frame:GetAlpha() return self.alpha or 1 end
	-- where a frame is on screen is whatever the test put there (cx, cy); nothing until it has
	function frame:GetCenter() return self.cx, self.cy end
	function frame:GetEffectiveScale() return self.scale or 1 end
	function frame:GetLeft() return self.left or 800 end
	function frame:GetTop() return self.top or 700 end
	function frame:SetFrameLevel(level) assert(type(level) == 'number') self.level = level end
	function frame:GetFrameLevel() return self.level end
	function frame:GetWidth() return self.width end
	function frame:GetHeight() return self.height end
	function frame:CreateLine() return Line() end
	function frame:CreateFontString(name, layer, font)
		assert(font, 'a font string needs a font')
		local fs = { shown = true }
		function fs:SetText(text) assert(type(text) == 'string') self.text = text end
		function fs:GetText() return self.text end
		function fs:SetWidth(w) assert(w > 0) self.width = w end
		function fs:SetJustifyH(how) assert(how == 'CENTER' or how == 'LEFT' or how == 'RIGHT') end
		function fs:SetWordWrap(on) assert(type(on) == 'boolean') end
		-- (this client is taken to lack one of the fonts, to see the fall back to the game's own)
		function fs:SetFont(path, size, flags)
			assert(type(path) == 'string' and size > 0 and type(flags) == 'string')
			if path:upper():find('SKURRI', 1, true) then return false end
			self.font, self.size, self.flags = path, size, flags
			return true
		end
		function fs:SetTextColor(r, g, b) assert(r and g and b) self.colour = { r, g, b } end
		function fs:GetFont() return self.font, self.size, self.flags end
		function fs:SetShadowOffset(x, y) assert(type(x) == 'number' and type(y) == 'number') self.shadow = x end
		function fs:GetShadowOffset() return self.shadow or 1, self.shadow and -self.shadow or -1 end    -- (the game's fonts come with one)
		function fs:SetShadowColor(r, g, b, a) assert(r and g and b) end
			function fs:SetAlpha(alpha) assert(alpha >= 0 and alpha <= 1, 'alpha out of range: ' .. tostring(alpha)) self.alpha = alpha end
		function fs:ClearAllPoints() end
		function fs:SetPoint(point, to, rel, x, y) assert(to and x == x and y == y) end
		function fs:Show() self.shown = true end
		function fs:Hide() self.shown = false end
		function fs:IsShown() return self.shown end
		function fs:SetMaxLines(n) assert(n > 0) end
		return fs
	end
	function frame:SetSize(w, h) assert(w > 0 and h > 0) self.width, self.height = w, h end
	function frame:SetHeight(h) assert(h > 0) self.height = h end
	function frame:SetWidth(w) assert(w > 0) self.width = w end
	function frame:SetText(text) assert(type(text) == 'string') self.text = text end
	function frame:SetChecked(on) assert(type(on) == 'boolean') self.checked = on end
	function frame:GetChecked() return self.checked end
	function frame:SetParent(other) assert(other) self.parent = other end
	function frame:GetParent() return self.parent end
	function frame:SetPoint(point, to, rel, x, y) assert(to and x == x and y == y) self.anchor = to end
	function frame:CreateTexture()
		local tex = { shown = false }
		STUB.allTextures[#STUB.allTextures + 1] = tex
		function tex:SetTexCoord(a, b, c, d) assert(a and b and c and d) end
		function tex:SetSize(w, h) assert(w > 0 and h > 0) end
		function tex:SetHeight(h) assert(h > 0) end
		function tex:SetColorTexture(r, g, b, a) assert(r and g and b) self.colour = { r, g, b, a } end
		function tex:IsShown() return self.shown end
		function tex:SetTexture(icon) assert(icon ~= nil) self.icon = icon end
		function tex:GetTexture() return self.icon end
		function tex:GetAtlas() return self.atlas end
		function tex:SetBlendMode(mode) assert(mode == 'ADD' or mode == 'BLEND') end
		function tex:SetVertexColor(r, g, b) assert(r and g and b) self.colour = { r, g, b } end
		function tex:SetRotation(angle) assert(angle == angle) end
		function tex:SetAlpha(alpha) assert(alpha >= 0 and alpha <= 1, 'alpha out of range: ' .. tostring(alpha)) end
		function tex:ClearAllPoints() end
		function tex:SetAllPoints(other) assert(other) end
		function tex:SetPoint(point, to, rel, x, y) assert(x == x and y == y, 'not a number') self.x, self.y = x, y end
		function tex:Show() if not self.shown then self.shown = true; STUB.icons = STUB.icons + 1 end end
		function tex:Hide() if self.shown then self.shown = false; STUB.icons = STUB.icons - 1 end end
		return tex
	end
	STUB.frames[#STUB.frames + 1] = frame
	return frame
end

function STUB.Fire(event, ...)
	for frame in pairs(STUB.events[event] or {}) do
		frame.scripts.OnEvent(frame, event, ...)
	end
end

function STUB.Frame()                 -- one frame of the game: every shown frame's OnUpdate
	for _, frame in ipairs(STUB.frames) do
		if frame.shown and frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, 0.016) end
	end
end

function STUB.Tick()                  -- every running timer once, a twentieth of a second on
	STUB.time = STUB.time + 0.05
	for _, t in ipairs(STUB.tickers) do
		if not t.cancelled then t.fn() end
	end
end

STUB.afters = {}
function STUB.RunAfters()                -- every one-off timer that is waiting
	local list = STUB.afters
	STUB.afters = {}
	for _, fn in ipairs(list) do fn() end
end
C_Timer = { After = function(seconds, fn) assert(seconds >= 0) STUB.afters[#STUB.afters + 1] = fn end,
	NewTicker = function(seconds, fn)
	local t = { fn = fn }
	function t:Cancel() self.cancelled = true end
	STUB.tickers[#STUB.tickers + 1] = t
	return t
end }

C_AddOns = { LoadAddOn = function(name) return true end }

-- Kalimdor and Eastern Kingdoms as the classic world map has them: left, right (world y), top, bottom (world x)
local MAPS = { [1414] = { 1, 17066.6, -19733.21, 12799.9, -11733.3 }, [1415] = { 0, 18171.97, -22569.21, 11176.34, -15973.34 },
	[1413] = { 1, 2622.92, -7510.41, 1612.49, -5143.75, zone = true } }       -- the Barrens, a zone's map
function CreateVector2D(x, y)
	return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end
C_Map = {
	HasUserWaypoint = function() return STUB.pin ~= nil end,
	GetUserWaypoint = function() return STUB.pin end,
	GetBestMapForUnit = function() return STUB.player.map == 1 and 1414 or 1415 end,
	GetMapInfo = function(id) return { mapType = MAPS[id] and (MAPS[id].zone and 3 or 2) or 1 } end,
	GetWorldPosFromMapPos = function(id, pos)
		local m = MAPS[id]
		if not m then error('no such map ' .. tostring(id)) end
		return m[1], CreateVector2D(m[4] - pos.y * (m[4] - m[5]), m[2] - pos.x * (m[2] - m[3]))
	end,
}
function STUB.PinAt(map, worldX, worldY)       -- a map pin at a world position
	local id = map == 1 and 1414 or 1415
	local m = MAPS[id]
	STUB.pin = { uiMapID = id, position = CreateVector2D((m[2] - worldY) / (m[2] - m[3]), (m[4] - worldX) / (m[4] - m[5])) }
end

-- Quests, as the game's own world map asks about them. STUB.quests[id] = { title =, uiMap =, x =, y =
-- (its mark on that map, 0 to 1), stop = { uiMap, x, y } (the game's next stop on the way) }.
-- STUB.watched = the ids in the tracker; STUB.focus = the one the game's arrow is on (0: none).
STUB.quests, STUB.watched, STUB.focus = {}, {}, 0
local function OnMap(map, worldX, worldY)
	local id = map == 1 and 1414 or 1415
	local m = MAPS[id]
	return id, (m[2] - worldY) / (m[2] - m[3]), (m[4] - worldX) / (m[4] - m[5])
end
function STUB.QuestAt(id, title, map, worldX, worldY)       -- a quest whose mark is at a world position
	local q = STUB.quests[id] or {}
	q.title = title
	q.uiMap, q.x, q.y = OnMap(map, worldX, worldY)
	STUB.quests[id] = q
end
function STUB.QuestStop(id, map, worldX, worldY)            -- the game's next stop on the way to it (nil: none)
	STUB.quests[id].stop = map and { OnMap(map, worldX, worldY) } or nil
end
function STUB.QuestGone(id)                                 -- handed in, or dropped
	STUB.quests[id] = nil
	for i = #STUB.watched, 1, -1 do
		if STUB.watched[i] == id then table.remove(STUB.watched, i) end
	end
	if STUB.focus == id then STUB.focus = 0 end
end
function GetQuestUiMapID(id) return STUB.quests[id] and STUB.quests[id].uiMap or 0 end
C_QuestLog = {
	GetQuestsOnMap = function(uiMap)
		assert(type(uiMap) == 'number')
		local list = {}
		for id, q in pairs(STUB.quests) do
			if q.uiMap == uiMap then list[#list + 1] = { questID = id, x = q.x, y = q.y } end
		end
		return list
	end,
	GetNextWaypoint = function(id)
		local q = STUB.quests[id]
		if q and q.stop then return q.stop[1], q.stop[2], q.stop[3] end
	end,
	GetLogIndexForQuestID = function(id) return STUB.quests[id] and 1 or nil end,
	GetNumQuestWatches = function() return #STUB.watched end,
	GetQuestIDForQuestWatchIndex = function(i) return STUB.watched[i] end,
	GetTitleForQuestID = function(id) return STUB.quests[id] and STUB.quests[id].title end,
}
C_SuperTrack = { GetSuperTrackedQuestID = function() return STUB.focus end }

-- STUB.undiscovered[id] = true: the world map says you have not found that flight point.
-- STUB.noTaxi = true: the world map says nothing at all. STUB.flightMap = { [id] = 0 here, 1 can be
-- flown to, 2 out of reach }: what the flight map lists when opened at a flight master; a point not
-- in it is listed as out of reach, or not listed at all when STUB.flightMapShort is set.
ERR_NEWTAXIPATH = 'New flight path discovered!'
function GetTaxiMapID() return STUB.player.map == 1 and 1414 or 1415 end
C_TaxiMap = { GetTaxiNodesForMap = function(id)
	local out = {}
	if STUB.noTaxi then return out end
	local D = PatchwerkForever_Thread_RoutesData[MAPS[id][1]]
	for _, p in ipairs(D.points) do
		out[#out + 1] = { nodeID = p[1], name = p[2], isUndiscovered = STUB.undiscovered[p[1]] or false }
	end
	return out
end,
GetAllTaxiNodes = function(id)
	local out = {}
	if not STUB.flightMap then return out end
	for _, p in ipairs(PatchwerkForever_Thread_RoutesData[MAPS[id][1]].points) do
		local state = STUB.flightMap[p[1]]
		if state or not STUB.flightMapShort then
			out[#out + 1] = { nodeID = p[1], name = p[2], state = state or 2, slotIndex = #out + 1 }
		end
	end
	return out
end }
Enum.FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 }
C_Minimap = { GetViewRadius = function() return 233.3 end }
UIParent = CreateFrame('Frame')
Minimap = CreateFrame('Frame')
Minimap.width, Minimap.height = 140, 140

MapCanvasDataProviderMixin = {}
function CreateFromMixins(mixin)
	local out = {}
	for k, v in pairs(mixin) do out[k] = v end
	return out
end
WorldMapFrame = CreateFrame('Frame')
WorldMapFrame.canvas = CreateFrame('Frame')
WorldMapFrame.mapID = 1414
function WorldMapFrame:GetCanvas() return self.canvas end
function WorldMapFrame:GetMapID() return self.mapID end
function WorldMapFrame:GetCanvasScale() return 0.5 end
function WorldMapFrame:GetPinFrameLevelsManager()
	return { GetValidFrameLevel = function(_, kind) assert(kind) return 2100 end }
end
function WorldMapFrame:AddDataProvider(provider) STUB.provider = provider end

-- The options page. Each maker checks what it is handed the way the game would trip over it.
STUB.pages, STUB.buttons, STUB.headers = {}, {}, {}
MinimalSliderWithSteppersMixin = { Label = { Right = 1 } }
local function NewControl()
	return { SetParentInitializer = function(_, parent, fn) assert(parent and fn() ~= nil) end }
end
function CreateSettingsButtonInitializer(name, text, click, tooltip)
	assert(type(name) == 'string' and type(text) == 'string' and type(click) == 'function' and tooltip)
	local button = { name = name, text = text, click = click }
	STUB.buttons[#STUB.buttons + 1] = button
	return button
end
function CreateSettingsListSectionHeaderInitializer(name)
	assert(type(name) == 'string')
	STUB.headers[#STUB.headers + 1] = name
	return { header = name }
end
Settings = {
	VarType = { Boolean = 'boolean', Number = 'number', String = 'string' },
	RegisterVerticalLayoutCategory = function(title) return { title = title, GetID = function() return 7 end }, {} end,
	RegisterVerticalLayoutSubcategory = function(parent, name)
		assert(parent and type(name) == 'string' and not STUB.pages[name], 'a sub-page made twice: ' .. tostring(name))
		local page = { title = name, items = 0, GetID = function() return 8 end }
		STUB.pages[name] = page
		return page, {}
	end,
	RegisterInitializer = function(category, initializer)
		assert(category and initializer)
		initializer.page = category.title
	end,
	RegisterProxySetting = function(category, variable, kind, name, default, get, set)
		assert(category and variable and kind and name and default ~= nil and get and set)
		assert(type(default) == kind, variable .. ': its starting value is not a ' .. tostring(kind))
		assert(not variable:find('[^%w_]'), 'a bad name for a setting: ' .. variable)
		for _, other in ipairs(STUB.settings) do assert(other.variable ~= variable, 'two settings named ' .. variable) end
		assert(type(get()) == kind, variable .. ': what it reads is not a ' .. tostring(kind))
		local s = { variable = variable, name = name, kind = kind, default = default, get = get, set = set, page = category.title }
		function s:SetValue(value) assert(type(value) == self.kind, variable .. ': set to a value of the wrong kind') self.set(value) end
		STUB.settings[#STUB.settings + 1] = s
		return s
	end,
	CreateCheckbox = function(category, setting, tooltip)
		assert(setting.kind == 'boolean' and tooltip)
		return NewControl()
	end,
	CreateSliderOptions = function(low, high, rate)
		assert(low < high and rate > 0)
		return { minValue = low, maxValue = high, steps = (high - low) / rate, SetLabelFormatter = function(_, how) assert(how) end }
	end,
	CreateSlider = function(category, setting, options, tooltip)
		assert(setting.kind == 'number' and tooltip and options.steps == math.floor(options.steps), setting.variable .. ': its steps do not fit its range')
		assert(setting.default >= options.minValue and setting.default <= options.maxValue, setting.variable .. ': starts outside its range')
		setting.low, setting.high = options.minValue, options.maxValue
		return NewControl()
	end,
	CreateControlTextContainer = function()
		local data = {}
		return { Add = function(_, value, label) assert(value ~= nil and type(label) == 'string') data[#data + 1] = { value = value, label = label } end,
			GetData = function() return data end }
	end,
	CreateDropdown = function(category, setting, options, tooltip)
		assert(setting.kind == 'string' and type(options) == 'function' and tooltip)
		local data, found = options(), false
		assert(#data >= 2, setting.variable .. ': a list of fewer than two')
		for _, item in ipairs(data) do found = found or item.value == setting.default end
		assert(found, setting.variable .. ': its starting value is not in its list')
		setting.choices = data
		return NewControl()
	end,
	CreateColorSwatch = function(category, setting, tooltip)
		assert(setting.kind == 'string' and tooltip)
		assert(setting.default:match('^%x%x%x%x%x%x%x%x$'), setting.variable .. ': not a colour: ' .. setting.default)
		setting.colour = true
		return NewControl()
	end,
	RegisterCanvasLayoutCategory = function(frame, title)
		assert(type(frame) == 'table' and type(title) == 'string' and not frame.shown, 'a drawn page must be a hidden frame')
		STUB.front = frame
		return { title = title, frame = frame, GetID = function() return 7 end }
	end,
	-- a row of the addon's own: made from a template the addon names in an XML file. The stand-in
	-- has no XML; STUB.Rows() makes each row from the template's mixin, as the game would.
	CreateElementInitializer = function(template, data)
		assert(type(template) == 'string' and type(data) == 'table')
		local row = { template = template, data = data, GetData = function(self) return self.data end }
		STUB.rows[#STUB.rows + 1] = row
		if template == 'PatchwerkForeverHeaderTemplate' then STUB.headers[#STUB.headers + 1] = data.name end
		if template == 'PatchwerkForeverIntroTemplate' then STUB.intros[#STUB.intros + 1] = data end
		return row
	end,
	RegisterAddOnCategory = function(category) STUB.category = category end,
	OpenToCategory = function(id) STUB.opened = id end,
}
GameFontNormal = { GetFont = function() return 'Fonts\\FRIZQT__.TTF', 12, '' end }

-- (the game knows a row's template once its XML file is read: the stand-in is told here; STUB.noRows = true: it is not)
C_XMLUtil = { GetTemplateInfo = function(name)
	if STUB.noRows then return nil end
	local tall = ({ PatchwerkForeverIntroTemplate = 84, PatchwerkForeverHeaderTemplate = 44, PatchwerkForeverListTemplate = 266 })[name]
	if tall then return { type = 'Frame', width = 0, height = tall } end
end }

-- Rows of an addon's own in the options (Settings.CreateElementInitializer): each is made as the
-- game makes it, from its template's mixin, loaded, filled and given a width. Returns how many.
STUB.rows, STUB.intros = {}, {}
function STUB.Rows()
	for _, row in ipairs(STUB.rows) do
		local mixin = _G[(row.template:gsub('Template$', 'Mixin'))]
		assert(type(mixin) == 'table', 'no mixin for ' .. row.template)
		local frame = CreateFrame('Frame', nil, UIParent)          -- (in the game the options list holds it)
		for key, value in pairs(mixin) do frame[key] = value end
		frame.width = 600
		frame:OnLoad()
		frame:Init(row)
		if frame.scripts.OnSizeChanged then frame.scripts.OnSizeChanged(frame, 640, 84) end
		row.frame = frame
	end
	return #STUB.rows
end

-- The game's yes-or-no box: what was asked is kept, and STUB.Answer(true) presses Yes.
StaticPopupDialogs = {}
function StaticPopup_Show(which, text, _, data)
	local dialog = StaticPopupDialogs[which]
	assert(type(dialog) == 'table' and type(dialog.text) == 'string' and dialog.button1 and dialog.OnAccept, 'a box the game could not show: ' .. tostring(which))
	STUB.asked = { which = which, text = dialog.text:format(text), data = data }
end
function STUB.Answer(yes)
	local asked = STUB.asked
	STUB.asked = nil
	assert(asked, 'nothing was asked')
	if yes then StaticPopupDialogs[asked.which].OnAccept({}, asked.data) end
end
