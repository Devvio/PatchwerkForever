"""Thread (Globe), run outside the game: Patchwerk Forever and Thread (Globe) loaded into a stand-in for
the game (wowstub.lua), with what the globe needs added to it.

    python lua_globe.py

It reads what the globe drew through ns.GlobeState(): the pieces (their pictures, the part of them, where
their corners are seen) and the names. It checks the continent maps on parchment with their edges fading,
pieces cut where they cross the globe's edge (none folded), the names fading by zoom, Where I Am gliding
to a character at the Crossroads with the arrow turned the way they face, the ground fading in over the map
with the Crossroads' tile under the arrow (east to the right, south below), zooming toward the pointer,
a drag that carries on, a double-click zoom, the zones (the one under the pointer outlined and named, a
click fitting it in the picture, a right-click stepping back out), the ground (drawn where there is land,
fading out to sea, only the tiles in the picture looked at), the window (sized by its corner, full screen and
back, both remembered), Go To, keys and a gamepad's sticks (the middle of the picture their pointer), the
marks (a gamepad taken and given back; boats and zeppelins, the trail, flight points, herb and ore nodes, My
Route's stops and the map pin, with what Thread (Routes) offers made up here; quests, quests on offer, a guide's
steps, Next Mark, the Route button and the tracker beside the globe), the hand-made pieces (the ink pieces on the
sea, the whole ring and stand in the picture when zoomed right out, the globe lifted to make room for it and
the pointer still true), and Minimap Pictures. How it looks, and how fast, only the game can say.
"""
import math
import os

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ADDONS = os.path.normpath(os.path.join(HERE, "..", "addons"))
BASE = "PatchwerkForever"
GLOBE = "PatchwerkForever_Thread_Globe"
TILE = 1600 / 3
EDGE = 32 * TILE
EYE = 4
LIMB = EYE / math.sqrt(EYE * EYE - 1)

# what the stand-in lacks for the globe: pictures whose corners move, masks, the mouse, world maps and names
MORE = r"""
STUB.cursor = { 0, 0 }
STUB.facing = 0
STUB.over = true                       -- (the pointer is over the globe's picture)
C_Map.GetAreaInfo = function(id) if id == 17 then return 'The Barrens' end end     -- (the game names this one only)
function GetCursorPosition() return STUB.cursor[1], STUB.cursor[2] end
function GetFramerate() return 60 end
function GetPlayerFacing() return STUB.facing end
UISpecialFrames = {}
local function Bendable(t)
    function t:SetVertexOffset(i, x, y)
        assert(i == 1 or i == 2 or i == 3 or i == 4, 'a corner out of range')
        assert(x == x and y == y and math.abs(x) < 1e7 and math.abs(y) < 1e7, 'a corner not a number')
    end
    function t:SetSize(w, h) assert(w > 0 and h > 0, 'a picture of no size') end
    function t:SetShown(on) if on then self:Show() else self:Hide() end end
    function t:SetSnapToPixelGrid(on) assert(on == false) end
    function t:SetTexelSnappingBias(b) assert(b == 0) end
    function t:AddMaskTexture(m) assert(m and m.mask) end
    function t:SetDrawLayer(layer, sub) assert((layer == 'ARTWORK' or layer == 'OVERLAY') and sub >= -8 and sub <= 7) end
    function t:SetAtlas(name) assert(type(name) == 'string') self.atlas, self.icon = name, nil end
    function t:SetTexCoord(a, b, c, d) assert(a and b and c and d and a < b and c < d, 'a part of no size') end
    function t:SetRotation(angle) assert(angle == angle) self.rotation = angle end
    function t:SetVertexColor(r, g, b, a)
        assert(r and g and b and (a == nil or (a >= 0 and a <= 1)), 'a colour out of range') self.gradient = nil
    end
    function t:SetGradient(how, from, to)
        assert((how == 'HORIZONTAL' or how == 'VERTICAL') and from.a and to.a, 'a gradient without its ends')
        assert(from.a >= 0 and from.a <= 1 and to.a >= 0 and to.a <= 1)
        self.gradient = { how, from.a, to.a }
    end
    return t
end
local made = CreateFrame
function CreateFrame(kind, name, parent, template)
    local f = made(kind, name, parent, template)
    if name then _G[name] = f end
    local create = f.CreateTexture
    function f:CreateTexture(...) return Bendable(create(self, ...)) end
    function f:CreateMaskTexture()
        return { mask = true, SetTexture = function(_, path) assert(type(path) == 'string') end, SetAllPoints = function() end }
    end
    for _, fn in ipairs({ 'SetClipsChildren', 'EnableMouseWheel', 'SetMovable', 'SetClampedToScreen', 'RegisterForDrag',
        'StartMoving', 'StopMovingOrSizing', 'SetResizable', 'SetResizeBounds', 'StartSizing', 'SetNormalTexture',
        'SetHighlightTexture', 'SetPushedTexture', 'EnableGamePadStick', 'EnableGamePadButton' }) do
        f[fn] = f[fn] or function() end
    end
    -- (as the game does: a frame hidden or shown runs its OnHide or OnShow)
    local hide, show = f.Hide, f.Show
    function f:Hide()
        local was = self.shown
        hide(self)
        if was and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function f:Show()
        local was = self.shown
        show(self)
        if not was and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    f.SetShown = function(self, on) if on then self:Show() else self:Hide() end end
    function f:SetPropagateKeyboardInput(on) assert(type(on) == 'boolean') self.passes = on end
    function f:GetName() return name end
    function f:IsMouseOver() return STUB.over end
    return f
end
local uiCreate = UIParent.CreateTexture
function UIParent:CreateTexture(...) return Bendable(uiCreate(self, ...)) end
-- the game's menus: what was last opened is kept as a tree (STUB.menu), each entry { text, click, kids }
local function MenuNode(text, click)
    local node = { text = text, click = click, kids = {} }
    function node:CreateTitle(title) assert(type(title) == 'string') self.title = title end
    function node:CreateButton(label, fn)
        assert(type(label) == 'string' and (fn == nil or type(fn) == 'function'))
        local kid = MenuNode(label, fn)
        self.kids[#self.kids + 1] = kid
        return kid
    end
    function node:SetScrollMode(extent) assert(extent > 0) end
    function node:CreateRadio(label, isSelected, setSelected)
        assert(type(isSelected) == 'function' and type(setSelected) == 'function')
        local kid = self:CreateButton(label, setSelected)
        kid.selected = isSelected
        return kid
    end
    node.CreateCheckbox = node.CreateRadio
    return node
end
MenuUtil = { CreateContextMenu = function(owner, build)
    assert(owner and type(build) == 'function')
    STUB.menu = MenuNode('root')
    build(owner, STUB.menu)
end }
Enum = Enum or {}
Enum.UIMapType = Enum.UIMapType or { Continent = 2, Zone = 3 }
-- the two continents' world maps, as 12 pictures each (4 x 3, 256 square, 1002 x 668 used)
C_Map.GetMapArtLayers = function(id)
    if id == 1414 or id == 1415 then return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end
    return {}
end
C_Map.GetMapArtLayerTextures = function(id, layer)
    assert(layer == 1)
    local out = {}
    for i = 1, 12 do out[i] = (id == 1414 and 9000 or 9100) + i end
    return out
end
local NAMES = { [1414] = 'Kalimdor', [1415] = 'Eastern Kingdoms', [1413] = 'The Barrens' }
local info = C_Map.GetMapInfo
C_Map.GetMapInfo = function(id) local i = info(id); i.name = NAMES[id]; return i end
C_Map.GetMapChildrenInfo = function(id, kind)
    if id == 947 then return { { mapID = 1414, name = 'Kalimdor' }, { mapID = 1415, name = 'Eastern Kingdoms' } } end
    if id == 1414 then assert(kind == Enum.UIMapType.Zone) return { { mapID = 1413, name = 'The Barrens' } } end
    return {}
end
-- marks: tooltips, the keys held, the map pin, flight points, who you are
STUB.tip = { lines = {} }
GameTooltip = {
    SetOwner = function(self, owner, anchor) assert(owner and type(anchor) == 'string') STUB.tip = { lines = {}, anchor = anchor } end,
    SetText = function(self, text) assert(type(text) == 'string') STUB.tip.title = text end,
    AddLine = function(self, text) assert(type(text) == 'string') table.insert(STUB.tip.lines, text) end,
    AddDoubleLine = function(self, a, b) assert(type(a) == 'string' and type(b) == 'string') table.insert(STUB.tip.lines, a .. ' | ' .. b) end,
    Show = function() STUB.tip.shown = true end,
    Hide = function() STUB.tip = { lines = {} } end,
}
STUB.ctrl, STUB.shift = false, false
function IsControlKeyDown() return STUB.ctrl end
function IsShiftKeyDown() return STUB.shift end
function IsModifiedClick(what) assert(what == 'CHATLINK' or what == 'QUESTWATCHTOGGLE') return STUB.shift end
ChatFrameUtil = { InsertLink = function(link) STUB.linked = link end }
function PlaySound(kit) assert(kit) end
SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
local guid = UnitGUID
function UnitGUID(unit) if unit == 'player' then return 'Player-1-000A' end return guid(unit) end
local WORLD_MAPS = { [1414] = { 1, 17066.6, -19733.21, 12799.9, -11733.3 }, [1415] = { 0, 18171.97, -22569.21, 11176.34, -15973.34 },
    [1413] = { 1, 2622.92, -7510.41, 1612.49, -5143.75 } }
function STUB.ToMap(id, wx, wy)
    local m = WORLD_MAPS[id]
    return (m[2] - wy) / (m[2] - m[3]), (m[4] - wx) / (m[4] - m[5])
end
C_Map.GetMapPosFromWorldPos = function(continent, world, override)
    local id = override or (continent == 1 and 1414 or 1415)
    local x, y = STUB.ToMap(id, world:GetXY())
    return id, CreateVector2D(x, y)
end
C_Map.GetMapInfoAtPosition = function(id, x, y)
    assert(type(x) == 'number' and type(y) == 'number')
    if id == 1414 then
        local m = WORLD_MAPS[1414]
        local bx, by = STUB.ToMap(1413, m[4] - y * (m[4] - m[5]), m[2] - x * (m[2] - m[3]))
        if bx >= 0 and bx <= 1 and by >= 0 and by <= 1 then return { mapID = 1413, name = 'The Barrens' } end
    end
    return { mapID = id }
end
C_Map.CanSetUserWaypointOnMap = function(id) return STUB.noPinOn ~= id end
C_Map.SetUserWaypoint = function(point)
    assert(type(point.uiMapID) == 'number' and point.position.GetXY, 'not a map point')
    STUB.pin = point
    STUB.Fire('USER_WAYPOINT_UPDATED')
end
C_Map.ClearUserWaypoint = function() STUB.pin = nil; STUB.Fire('USER_WAYPOINT_UPDATED') end
C_Map.GetUserWaypointHyperlink = function() return STUB.pin and '|Hworldmap:1413:5000:5000|h[Map Pin Location]|h' or nil end
C_SuperTrack.IsSuperTrackingUserWaypoint = function() return STUB.tracked == true end
C_SuperTrack.SetSuperTrackedUserWaypoint = function(on)
    assert(type(on) == 'boolean')
    STUB.tracked = on
    STUB.Fire('SUPER_TRACKING_CHANGED')
end
-- the quest log (one heading, then the quests of STUB.questOrder), quests on offer, a guide and a side list
STUB.questOrder, STUB.offers = {}, {}
C_QuestLog.GetNumQuestLogEntries = function() return #STUB.questOrder + 1 end
C_QuestLog.GetInfo = function(i)
    if i == 1 then return { isHeader = true, title = 'The Barrens' } end
    local id = STUB.questOrder[i - 1]
    local q = id and STUB.quests[id]
    if q then return { questID = id, title = q.title, isHeader = false, isHidden = false } end
end
C_QuestLog.IsComplete = function(id) return STUB.quests[id] and STUB.quests[id].done or false end
C_QuestLog.GetQuestObjectives = function(id) return STUB.quests[id] and STUB.quests[id].objectives or {} end
C_SuperTrack.SetSuperTrackedQuestID = function(id) STUB.focus = id end
C_QuestLine = {
    RequestQuestLinesForMap = function(id) STUB.offersAsked = id end,
    GetAvailableQuestLines = function(id) return STUB.offers[id] or {} end,
}
function STUB.OfferAt(zone, id, name, wx, wy, held)
    local x, y = STUB.ToMap(zone, wx, wy)
    STUB.offers[zone] = STUB.offers[zone] or {}
    table.insert(STUB.offers[zone], { questID = id, questName = name, x = x, y = y, startMapID = zone, inProgress = held or false })
end
STUB.taxi = {}
C_TaxiMap = { GetTaxiNodesForMap = function(id) assert(type(id) == 'number') return STUB.taxi[id] or {} end }
function STUB.TaxiAt(id, nodeID, name, wx, wy, faction, unknown, atlas)
    local x, y = STUB.ToMap(id, wx, wy)
    STUB.taxi[id] = STUB.taxi[id] or {}
    table.insert(STUB.taxi[id], { nodeID = nodeID, name = name, position = CreateVector2D(x, y), faction = faction,
        isUndiscovered = unknown, atlasName = atlas, textureKit = '' })
end
C_Texture = { GetAtlasInfo = function(name) if STUB.atlases and STUB.atlases[name] then return { width = 16, height = 16 } end end }
STUB.atlases = { TaxiNode_Known = true }
function CreateColor(r, g, b, a)
    return { r = r, g = g, b = b, a = a, SetRGBA = function(self, r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end }
end
-- places, your death, your group, a zone's levels, coordinates
STUB.pois, STUB.entrances, STUB.group, STUB.dead, STUB.raid, STUB.level = {}, {}, {}, false, false, 20
C_AreaPoiInfo = {
    GetAreaPOIForMap = function(id)
        local out = {}
        for poi in pairs(STUB.pois[id] or {}) do out[#out + 1] = poi end
        table.sort(out)
        return out
    end,
    GetAreaPOIInfo = function(id, poi) return STUB.pois[id] and STUB.pois[id][poi] end,
}
function STUB.PoiAt(zone, id, name, wx, wy, textureIndex, atlas, description)
    local x, y = STUB.ToMap(zone, wx, wy)
    STUB.pois[zone] = STUB.pois[zone] or {}
    STUB.pois[zone][id] = { areaPoiID = id, name = name, position = CreateVector2D(x, y), textureIndex = textureIndex,
        atlasName = atlas, description = description }
end
function STUB.EntranceAt(zone, id, name, wx, wy, atlas)
    local x, y = STUB.ToMap(zone, wx, wy)
    STUB.entrances[zone] = STUB.entrances[zone] or {}
    table.insert(STUB.entrances[zone], { areaPoiID = id, name = name, position = CreateVector2D(x, y), atlasName = atlas,
        journalInstanceID = id })
end
C_Minimap = { GetPOITextureCoords = function(i)
    assert(type(i) == 'number')
    return (i % 16) / 16, (i % 16 + 1) / 16, 0.25, 0.3125
end }
C_EncounterJournal = { GetDungeonEntrancesForMap = function(id) return STUB.entrances[id] or {} end }
local function Lies(what)
    return function(id)
        local c = STUB[what]
        if c and c.ui == id then return CreateVector2D(STUB.ToMap(id, c.x, c.y)) end
    end
end
C_DeathInfo = { GetCorpseMapPosition = Lies('corpse'), GetDeathReleasePosition = Lies('release') }
STUB.secret = {}
function issecretvalue(v) return v == STUB.secret end
function UnitIsDeadOrGhost(unit)
    if unit == 'player' then return STUB.dead end
    return STUB.group[unit] and STUB.group[unit].dead or false
end
function IsInGroup() return next(STUB.group) ~= nil end
function IsInRaid() return STUB.raid end
function GetNumGroupMembers() local n = 0 for _ in pairs(STUB.group) do n = n + 1 end return n end
local exists, isUnit, position, unitName = UnitExists, UnitIsUnit, UnitPosition, UnitName
function UnitExists(unit) if STUB.group[unit] then return true end return exists(unit) end
function UnitIsUnit(a, b) if STUB.group[a] then return STUB.group[a].me == true and b == 'player' end return isUnit(a, b) end
function UnitPosition(unit)
    local m = STUB.group[unit]
    if m then return m.x, m.y, 0, m.map end
    if unit ~= 'player' then return nil end
    return position(unit)
end
function UnitName(unit) if STUB.group[unit] then return STUB.group[unit].name end return unitName(unit) end
function UnitClass(unit) local m = STUB.group[unit] if m then return m.className, m.class end return 'Warrior', 'WARRIOR' end
RAID_CLASS_COLORS = { MAGE = { r = 0.25, g = 0.78, b = 0.92 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
function UnitLevel(unit) assert(unit == 'player') return STUB.level end
function GetQuestDifficultyColor(level)
    local d = level - STUB.level
    if d >= 5 then return { r = 1, g = 0.1, b = 0.1 } end
    if d >= 3 then return { r = 1, g = 0.5, b = 0.25 } end
    if d >= -2 then return { r = 1, g = 0.82, b = 0 } end
    if d >= -8 then return { r = 0.25, g = 0.75, b = 0.25 } end
    return { r = 0.5, g = 0.5, b = 0.5 }
end
C_Map.GetMapLevels = function(id) if id == 1413 then return 10, 25, 0, 0 end return 0, 0, 0, 0 end
C_Map.GetPlayerMapPosition = function(id, unit)
    assert(unit == 'player')
    return CreateVector2D(STUB.ToMap(id, STUB.player.x, STUB.player.y))
end
"""


TRAILS = r"""
STUB.crossings = {
    { id = 241, kind = 'boat', sides = 'AH', wait = 172,
        stops = { { map = 1, name = 'Ratchet', x = -1005.6, y = -3841.6 }, { map = 0, name = 'Booty Bay', x = -14277.7, y = 582.9 } },
        rides = {
            { from = 1, to = 2, secs = 108, legs = {
                { map = 1, points = { { -1006, -3842 }, { -1209, -4534 }, { -1867, -5197 } } },
                { map = 0, points = { { -14336, 1558 }, { -14278, 583 } } } } },
            { from = 2, to = 1, secs = 116, legs = {} } } },
    { id = 292, kind = 'boat', sides = 'A', wait = 158,
        stops = { { map = 0, name = 'Menethil Harbor', x = -3905.2, y = -585.8 }, { map = 1, name = 'Theramore', x = -4016.4, y = -4740.6 } },
        rides = { { from = 1, to = 2, secs = 96, legs = { { map = 1, points = { { -4301, -5732 }, { -4016, -4741 } } } } },
            { from = 2, to = 1, secs = 100, legs = {} } } },
    { id = 285, kind = 'zeppelin', sides = 'H', wait = 142,
        stops = { { map = 0, name = "Grom'gol", x = -12464, y = 231.6 }, { map = 1, name = 'Orgrimmar', x = 1360.9, y = -4631.3 } },
        rides = { { from = 1, to = 2, secs = 96, legs = { { map = 0, points = { { -12464, 232 }, { -12603, 1010 } } },
                { map = 1, points = { { 1132, -5493 }, { 1361, -4631 } } } } },
            { from = 2, to = 1, secs = 69, legs = {} } } },
}
STUB.trailList = {}
STUB.nodes = { { 1, -600, -2750, 'Peacebloom', 133939, 'h' }, { 1, -470, -2500, 'Copper Vein', 134566, 'o' },
    { 1, -3000, -3000, 'Far Herb', 133939, 'h' } }
STUB.nodeAsks = 0
PatchwerkForever.Trails:Offer({
    List = function() return STUB.trailList end,
    Crossings = function() return STUB.crossings end,
    NodesAround = function(map, x, y, reach, fn)
        STUB.nodeAsks = STUB.nodeAsks + 1
        for _, n in ipairs(STUB.nodes) do
            if n[1] == map and (n[2] - x) ^ 2 + (n[3] - y) ^ 2 <= reach * reach then fn(n[2], n[3], n[4], n[5], n[6]) end
        end
    end,
})
"""
GUIDES = r"""
PatchwerkForever.Guides:Register('fake', { name = 'Fake Guide', Read = function(count)
    if not STUB.guideOn then return nil end
    return { source = 'fake', reader = 'Fake Guide', index = 4, total = 9, kind = 'complete', key = 'k',
        lines = { { text = 'Kill 8 Plainstriders', done = false }, { text = 'Loot their beaks', done = true } }, map = 1, x = -700, y = -2700,
        ahead = { { index = 5, kind = 'turnin', lines = { { text = 'Turn in Plainstrider Menace' } }, map = 1, x = -1500, y = -2400 } },
        after = {} }
end })
PatchwerkForever.Guides:Register('side', { name = 'Dungeon Journal', Side = function() return true end, Read = function(count)
    if not STUB.sideOn then return nil end
    return { source = 'side', reader = 'Dungeon Journal', side = true, index = 1, total = 2, kind = 'accept', key = 's',
        lines = { { text = 'Pick up Leaders of the Fang' } }, map = 1, x = -1700, y = -3500, ahead = {}, after = {} }
end })
"""
ROUTE = r"""
STUB.trailList = {
    { follow = true, alpha = 0.95, last = { map = 0, x = -14278, y = 583 }, pieces = {
        { map = 1, how = 'walk', r = 1, g = 0.8, b = 0.2, alpha = 0.95, points = { { -442, -2598 }, { -700, -3200 }, { -1006, -3842 } } },
        { map = 1, how = 'ride', r = 0.3, g = 0.6, b = 1, alpha = 0.95, points = { { -1006, -3842 }, { -1867, -5197 } } },
        { map = 0, how = 'ride', r = 0.3, g = 0.6, b = 1, alpha = 0.95, points = { { -14336, 1558 }, { -14278, 583 } } },
    } },
    { follow = false, alpha = 0.45, last = { map = 1, x = 1677, y = -4315 }, pieces = {
        { map = 1, how = 'fly', r = 0.6, g = 1, b = 0.6, alpha = 0.45, points = { { -442, -2598 }, { 1677, -4315 } } },
    } },
}
PatchwerkForever.Trails:Changed()
"""


def toc_files(folder, name):
    for line in open(os.path.join(folder, name + ".toc"), encoding="utf-8"):
        line = line.strip()
        if line.endswith(".lua"):
            yield os.path.join(folder, *line.split("\\"))


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(open(os.path.join(HERE, "wowstub.lua"), encoding="utf-8").read())
    lua.execute(MORE)
    meta = {}
    for addon in (BASE, GLOBE):
        meta[addon] = {}
        for line in open(os.path.join(ADDONS, addon, addon + ".toc"), encoding="utf-8"):
            if line.startswith("## ") and ":" in line:
                key, value = line[3:].split(":", 1)
                meta[addon][key.strip()] = value.strip()
    lua.globals().C_AddOns.GetAddOnMetadata = lambda name, field: meta.get(name, {}).get(field)
    lua.execute("""
        function print(...)
            local out = {}
            for i = 1, select('#', ...) do out[#out + 1] = tostring((select(i, ...))) end
            STUB.messages[#STUB.messages + 1] = table.concat(out, ' ')
        end
        tinsert = table.insert
    """)
    load = lua.eval("function(code, name, addon, ns) return assert(loadstring(code, name))(addon, ns) end")
    stub = lua.globals().STUB
    G = lua.globals()
    tables = {}
    for addon in (BASE, GLOBE):
        tables[addon] = lua.table()
        for path in toc_files(os.path.join(ADDONS, addon), addon):
            load(open(path, encoding="utf-8").read(), "@" + addon + "/" + os.path.basename(path), addon, tables[addon])
        stub.Fire("ADDON_LOADED", addon)
    ns = tables[GLOBE]
    assert ns.linked, "the globe did not join the base"
    said = [0]

    def chat():
        new = list(stub.messages.values())[said[0]:]
        said[0] += len(new)
        for text in new:
            print("      chat: " + text)
        problems = [t for t in new if "a problem" in t.lower() or "error" in t.lower()]
        assert not problems, problems
        return " / ".join(new)

    def frames(n=3, step=0.016):
        for _ in range(n):
            stub.time += step
            stub.Frame()

    def step(label):
        print("  " + label)

    def state():
        st = ns.GlobeState()
        drawn = []
        for d in st.drawn.values():
            drawn.append({"fdid": d.fdid, "layer": d.layer, "depth": d.depth, "fu0": d.fu0, "fv0": d.fv0,
                          "fu1": d.fu1, "fv1": d.fv1,
                          # (how much of it shows: None for all of it, else the way it fades and its two ends)
                          "fade": (d.fade[1], d.fade[2], d.fade[3]) if d.fade else None,
                          "pts": list(zip(list(d.x.values()), list(d.y.values())))})   # ul, ll, ur, lr
        labels = {l.text: l for l in st.labels.values()}
        return st.look, drawn, labels

    def zone_state():
        st = ns.GlobeState()
        lines = [tuple(l.values()) for l in st.lines.values()]
        return st.zone, lines

    def point_at(wx, wy, map_id=1):
        x, y, z = ns.GlobeWhere(map_id, wx, wy)
        assert z > 0.3 and abs(x) < 295 and abs(y) < 295, ("the place is not in the picture", x, y, z)
        # (the pointer is measured from the picture's middle; the globe's is `lift` above that)
        stub.cursor[1], stub.cursor[2] = x, y + ns.GlobeState().lift
        return x, y

    def inside(lines, x, y):
        # (a line going right from x, y crosses an outline round it an odd number of times)
        crossings = 0
        for x1, y1, x2, y2 in lines:
            if (y1 > y) != (y2 > y) and x1 + (y - y1) / (y2 - y1) * (x2 - x1) > x:
                crossings += 1
        return crossings % 2 == 1

    def fit_radius(reach):
        t = max(0.004, min(1.2, reach))
        return max(ns.GlobeState().rmin, 0.82 * 300 * (EYE - math.cos(t)) / (EYE * math.sin(t)))

    def click(button="LeftButton"):
        stub.time += 1
        if button == "LeftButton":
            view.scripts["OnMouseDown"](view, button)
        view.scripts["OnMouseUp"](view, button)
        frames(90)

    def holding(drawn, x, y, layer=None, fdid=None):
        out = []
        for d in drawn:
            if (layer and d["layer"] != layer) or (fdid and d["fdid"] != fdid):
                continue
            xs, ys = [p[0] for p in d["pts"]], [p[1] for p in d["pts"]]
            if min(xs) <= x <= max(xs) and min(ys) <= y <= max(ys):
                out.append(d)
        return out

    def within_globe(look, drawn):
        for d in drawn:
            for x, y in d["pts"]:
                assert math.hypot(x, y) <= look.r * LIMB * 1.0001, ("a piece drawn past the globe's edge", d)
            # (a folded piece's corners wind the other way: down from its upper left, then across)
            (x1, y1), (x2, y2), (x3, y3), _ = d["pts"]
            # (one seen edge-on at the very rim may wind a hair either way: a hair for its size is let pass)
            hair = 0.02 * math.hypot(x2 - x1, y2 - y1) * math.hypot(x3 - x1, y3 - y1) + 1e-6
            assert (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1) >= -hair, ("a piece folded", d)

    stub.player.x, stub.player.y, stub.player.map = -442.0, -2598.0, 1      # the Crossroads
    stub.Fire("PLAYER_LOGIN")
    stub.Fire("PLAYER_ENTERING_WORLD", True, False)
    chat()
    on = [s for s in stub.settings.values() if s.page == "Thread: Globe"]
    assert len(on) >= 5, len(on)                  # (its settings are on its page; the button is not one)
    slash = G.SlashCmdList.PATCHWERKFOREVER_GLOBE

    step("/globe opens it: our own world picture (no game maps, no ground yet), continents' and seas' names")
    slash("")
    frames()
    window = G.PatchwerkForever_Thread_GlobeWindow
    assert window and window.shown, "the window did not open"
    view = [f for f in stub.frames.values() if f.scripts["OnMouseWheel"]][0]
    view.cx, view.cy = 0, 0                        # (the picture's middle, where the pointer is measured from)
    look, drawn, labels = state()
    world = [a for a in ns.ART.values() if a.kind == "world"]
    assert len(world) == 8, "not the whole world in eight pictures"
    for a in world:
        assert os.path.exists(os.path.join(ADDONS, GLOBE, "Art", a.file.split("\\")[-1] + ".blp")), a.file
    ours = [d for d in drawn if d["layer"] == "ours"]
    assert len(ours) >= 8 and not [d for d in drawn if d["layer"] == "art"], "the game's maps drawn under ours"
    assert not [d for d in drawn if d["layer"] == "ground"], "the ground showed before zooming in"
    assert labels["Kalimdor"].shown and labels["Eastern Kingdoms"].shown and not labels["The Barrens"].shown
    assert labels["The Great Sea"].shown, "the sea between the continents is not named"
    within_globe(look, drawn)
    slash("stats")
    assert "Parchment:" in chat()

    step("zoomed right out: the whole ring and stand in the picture, the ball in its hole, ink on the sea")
    st = ns.GlobeState()
    assert ns.RING and st.ring, "the ring and stand are not shown"
    assert 280 < st.ring.top <= 300 and -300 <= st.ring.bottom < -280, ("the ring and stand do not fill the picture", st.ring.top, st.ring.bottom)
    assert look.r * LIMB < st.ring.hole < look.r * LIMB * 1.06, ("the ball does not sit in the ring's hole", st.ring.hole)
    assert st.lift > 40 and st.lift + look.r * LIMB < 300, ("the ball is not lifted clear of the stand", st.lift)
    inked = [d for d in drawn if d["layer"] == "decor"]
    assert inked and "decor_compass" in inked[0]["fdid"], "the compass rose is not on the sea"

    step("a continent at the globe's edge: cut into smaller pieces, none folded over the edge")
    look.lon = -1.05 + math.pi / 2 - 0.15          # (Kalimdor's middle near the globe's left edge)
    look.r = look.r * 3                            # (closer, so the pieces at the edge need cutting)
    ns.Toggle(True)
    frames()
    look, drawn, labels = state()
    ours = [d for d in drawn if d["layer"] == "ours"]
    assert ours and max(d["depth"] for d in ours) >= 3, "pieces crossing the edge were not cut"
    within_globe(look, drawn)

    step("Where I Am glides to the Crossroads: the arrow there, turned the way you face; the zone's name")
    slash("me")
    frames(20)
    arrows = [t for t in stub.allTextures.values() if t.icon == "Interface\\Minimap\\MinimapArrow"]
    assert arrows and not (arrows[0].shown and abs(arrows[0].x) < 2 and abs(arrows[0].y) < 2), "it jumped there"
    frames(70)
    a = arrows[0]
    assert a.shown and abs(a.x) < 2 and abs(a.y) < 2, ("the arrow is not in the middle", a.shown, a.x, a.y)
    assert abs(a.rotation) < 0.05, ("facing north, the arrow does not point up", a.rotation)
    stub.facing = math.pi / 2                      # (facing west)
    frames(20)
    assert abs(a.rotation - math.pi / 2) < 0.05, ("facing west, the arrow does not point left", a.rotation)
    look, drawn, labels = state()
    assert labels["The Barrens"].shown and not labels["Kalimdor"].shown, "the names did not change with the zoom"
    within_globe(look, drawn)
    st = ns.GlobeState()
    assert st.ring is None and st.lift == 0, ("zoomed in, the ring stayed or the globe is off the middle", st.lift)

    # our detail picture of Kalimdor (8 yards a pixel) under the arrow, the world picture under it
    detail = holding(drawn, 0, 0, "detail")
    assert detail and detail[0]["fdid"].split("\\")[-1].startswith("1_"), "Kalimdor's detail is not under the arrow"
    assert holding(drawn, 0, 0, "ours"), "the world picture is not under the detail"
    assert not [d for d in drawn if d["layer"] == "ground"], "the ground came in too soon"

    step("zoomed in, the ground fades in over the detail: the Crossroads' tile under the arrow, east right, south below")
    for _ in range(3):
        view.scripts["OnMouseWheel"](view, 1)
    frames(60)
    look, drawn, labels = state()
    kalimdor = [c for c in ns.TILES.values() if c.map == 1][0]
    tx, ty = int((EDGE - stub.player.y) // TILE), int((EDGE - stub.player.x) // TILE)
    assert holding(drawn, 0, 0, "ground", kalimdor.tiles[ty * 64 + tx]), "the Crossroads' tile is not under the arrow"
    assert holding(drawn, 0, 0, "detail"), "the detail is not under the ground"

    def upper_left(fdid):
        found = [d for d in drawn if d["fdid"] == fdid and d["fu0"] == 0 and d["fv0"] == 0]
        assert found, "tile %d not drawn" % fdid
        return found[0]["pts"][0]

    ul = upper_left(kalimdor.tiles[ty * 64 + tx])
    east, south = upper_left(kalimdor.tiles[ty * 64 + tx + 1]), upper_left(kalimdor.tiles[(ty + 1) * 64 + tx])
    assert east[0] > ul[0] + 1 and abs(east[1] - ul[1]) < 2, ("east is not to the right", ul, east)
    assert south[1] < ul[1] - 1 and abs(south[0] - ul[0]) < 2, ("south is not below", ul, south)

    step("the wheel zooms toward the pointer: the ground under it stays under it")
    stub.cursor[1], stub.cursor[2] = 120, 60      # (a Lua table: x is at 1, y at 2)
    before = holding(drawn, 120, 60, "ground")
    assert before, "no ground under the pointer"
    target = before[0]["fdid"]
    r0 = look.r
    view.scripts["OnMouseWheel"](view, 1)
    frames(60)
    look, drawn, labels = state()
    assert look.r > r0 * 1.25, ("it did not zoom in", r0, look.r)
    assert holding(drawn, 120, 60, "ground", target), "the ground under the pointer moved away"

    step("a drag turns it under the pointer and carries on a little after you let go")
    stub.cursor[1], stub.cursor[2] = 0, 0
    view.scripts["OnMouseDown"](view, "LeftButton")
    for _ in range(5):
        stub.cursor[1] = stub.cursor[1] + 12
        frames(1)
    view.scripts["OnMouseUp"](view, "LeftButton")
    lon = look.lon
    frames(5)
    assert look.lon != lon, "it stopped at once when let go"
    frames(300)
    lon = look.lon
    frames(5)
    assert look.lon == lon, "it never came to rest"

    step("a double-click zooms in on the spot")
    stub.time += 1
    r0 = look.r
    view.scripts["OnMouseDown"](view, "LeftButton")
    view.scripts["OnMouseUp"](view, "LeftButton")
    stub.time += 0.1
    view.scripts["OnMouseDown"](view, "LeftButton")
    view.scripts["OnMouseUp"](view, "LeftButton")
    frames(60)
    assert look.r > r0 * 1.8, ("a double-click did not zoom in", r0, look.r)

    step("a right-click steps back out: the whole of Kalimdor in the picture")
    CROSSROADS, RAZOR_HILL = (-442.0, -2598.0), (300.0, -4700.0)
    kalimdor_zones = ns.ZONES[1]
    assert len(list(kalimdor_zones.zones.values())) >= 20, "Kalimdor's zones are not there"
    click("RightButton")
    whole = fit_radius(kalimdor_zones.reach * TILE / 19000)
    assert abs(look.r / whole - 1) < 0.01, ("not the whole continent", look.r, whole)

    step("pointing at a zone outlines and names it; the open sea is no zone")
    x, y = point_at(*CROSSROADS)
    frames(2)
    zone, lines = zone_state()
    assert zone and zone.id == 17 and zone.name == "The Barrens", ("the Barrens not found under the pointer", zone and zone.id)
    assert len(lines) > 20, ("no outline to speak of", len(lines))
    assert inside(lines, x, y), "the outline does not go round the place pointed at"
    joined = sum(1 for a, b in zip(lines, lines[1:]) if math.hypot(a[2] - b[0], a[3] - b[1]) < 2.5)
    assert joined >= len(lines) * 0.8, ("the outline is in loose pieces", joined, len(lines))
    assert max(math.hypot(a[2] - a[0], a[3] - a[1]) for a in lines) < 60, "a stretch of outline right across the zone"
    point_at(*RAZOR_HILL)
    frames(2)
    zone, lines = zone_state()
    assert zone and zone.id == 14 and zone.name == "Durotar", ("Durotar not found, or not named from its outline's file", zone and zone.id)
    stub.cursor[1], stub.cursor[2] = -250, 250     # (the picture's corner: past the globe's edge)
    frames(2)
    zone, lines = zone_state()
    assert zone is None and not lines, "a zone found off the globe"
    stub.over = False
    point_at(*CROSSROADS)
    frames(2)
    assert zone_state()[0] is None, "a zone outlined with the pointer off the globe's picture"
    stub.over = True

    step("a click on a zone turns and zooms the globe to fit it")
    point_at(*CROSSROADS)
    click()
    point_at(*CROSSROADS)
    frames(2)
    zone, lines = zone_state()
    assert zone.id == 17 and abs(look.r / fit_radius(zone.reach) - 1) < 0.01, ("the Barrens not fitted", look.r, zone.reach)
    far = max(max(math.hypot(a[0], a[1]), math.hypot(a[2], a[3])) for a in lines)
    assert 0.82 * 300 * 0.85 < far < 0.82 * 300 + 4, ("the zone does not fill the picture", far)
    point_at(*RAZOR_HILL)
    click()
    point_at(*RAZOR_HILL)
    frames(2)
    zone, lines = zone_state()
    assert zone.id == 14 and abs(look.r / fit_radius(zone.reach) - 1) < 0.01, ("a click on the next zone did not fit it", look.r)

    step("closer in than the zone, a click leaves the globe as it is")
    for _ in range(3):
        view.scripts["OnMouseWheel"](view, 1)
    frames(60)
    r0, lat0 = look.r, look.lat
    click()
    assert look.r == r0 and look.lat == lat0, "a click closer in moved the globe"

    step("right-clicks step out: the continent, then the whole globe")
    click("RightButton")
    assert abs(look.r / whole - 1) < 0.01, ("not the whole continent", look.r, whole)
    click("RightButton")
    assert abs(look.r / ns.GlobeState().rmin - 1) < 0.01, ("not the whole globe", look.r)
    within_globe(*state()[:2])
    assert ns.GlobeState().ring and ns.GlobeState().lift > 40, "the ring and stand did not come back"
    x, y = point_at(*CROSSROADS)
    frames(2)
    zone, lines = zone_state()
    assert zone and zone.id == 17, ("with the globe lifted, the pointer is off", zone and zone.id)
    # (this small, the outline's stretches overlap at their ends, so its bounds are asked, not a count of crossings)
    assert min(l[0] for l in lines) < x < max(l[0] for l in lines) and min(l[1] for l in lines) < y < max(l[1] for l in lines),         "the outline is not round the place pointed at"

    step("zooming from there keeps the place under the pointer, as the globe comes back to the middle")
    cursor = (stub.cursor[1], stub.cursor[2])
    for _ in range(4):
        view.scripts["OnMouseWheel"](view, 1)
    frames(90)
    st = ns.GlobeState()
    x, y, _z = ns.GlobeWhere(1, *CROSSROADS)
    assert st.lift == 0 and look.r > st.rmin * 2.5, ("it did not zoom in to the middle", st.lift, look.r)
    assert abs(x - cursor[0]) < 3 and abs(y - cursor[1]) < 3, ("the place slid from under the pointer", x, y, cursor)

    step("the ground ends softly at sea: a tile of sea beside land fades out, the open sea is left to the parchment")
    VIEW = 600
    tiles = {int(k): v for k, v in kalimdor.tiles.items()}
    landed = {int(n) for n in ns.ZONES[1].land.split(",")}
    assert landed and landed <= set(tiles), "the tiles with land are not among the tiles"

    def corner(x, y):
        around = [(y + dy) * 64 + x + dx for dy in (-1, 0) for dx in (-1, 0)]
        if x < 1 or x > 63 or y < 1 or any(i not in tiles for i in around):
            return 0
        return 1 if any(i in landed for i in around) else 0

    def corners(i):
        x, y = i % 64, i // 64
        return corner(x, y), corner(x + 1, y), corner(x, y + 1), corner(x + 1, y + 1)     # ul, ur, ll, lr

    shown = {i for i in tiles if sum(corners(i)) > 0}
    # (a tile of sea with land to its west and open sea to its east, itself among the tiles)
    east = [i for i in sorted(tiles) if corners(i) == (1, 0, 1, 0) and i + 1 in tiles and sum(corners(i + 1)) == 0]
    assert east, "no tile of sea east of land to try"
    tile = east[len(east) // 2]

    def go(i, r):
        ns.GlobeGo(1, i % 64 + 0.5, i // 64 + 0.5, r)
        frames(90)
        return ns.GlobeState(), state()[1]

    def in_picture(i):
        # (a tile's corners, in points from the middle of the picture; well inside it, not just touching)
        pts = [ns.GlobeWhere(1, EDGE - (i // 64 + dy) * TILE, EDGE - (i % 64 + dx) * TILE) for dx in (0, 1) for dy in (0, 1)]
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        return max(xs) > -290 and min(xs) < 290 and max(ys) > -290 and min(ys) < 290

    st, drawn = go(tile, VIEW * 9)
    assert st.ground == 1, ("the ground is not all in", st.ground)
    ground = [d for d in drawn if d["layer"] == "ground"]
    mine = [d for d in ground if d["fdid"] == tiles[tile]]
    assert mine, "the tile of sea beside land is not drawn"
    for d in mine:
        way, left, right = d["fade"] or (None, 1, 1)
        assert way == "HORIZONTAL" and abs(left - (1 - d["fu0"])) < 0.01 and abs(right - (1 - d["fu1"])) < 0.01, \
            ("it does not fade out to the east", d["fade"], d["fu0"], d["fu1"])
    beside = [d for d in ground if d["fdid"] == tiles[tile - 1]]
    assert beside and all(d["fade"] is None for d in beside), "the land beside it is not shown whole"
    assert in_picture(tile + 1) and not [d for d in ground if d["fdid"] == tiles[tile + 1]], \
        "the open sea beyond it is drawn"
    assert holding(drawn, 250, 0, "detail"), "no parchment under the open sea"
    # (only the tiles round the middle are looked at, and none in the picture is missed)
    assert 0 < st.asked <= 81, ("too many tiles looked at", st.asked)
    seen = {d["fdid"] for d in ground}
    missed = [i for i in shown if in_picture(i) and tiles[i] not in seen]
    assert not missed, ("tiles in the picture are not drawn", missed)
    within_globe(st.look, drawn)

    step("a tile fading toward a corner is cut smaller, each piece fading the way it changes most")
    uneven = [i for i in sorted(shown) if sum(corners(i)) < 4 and corners(i)[0] + corners(i)[3] != corners(i)[1] + corners(i)[2]]
    assert uneven, "no tile fading toward a corner to try"
    tile = uneven[len(uneven) // 2]
    st, drawn = go(tile, VIEW * 9)
    mine = [d for d in drawn if d["layer"] == "ground" and d["fdid"] == tiles[tile]]
    assert len(mine) >= 16 and max(d["depth"] for d in mine) >= 3, ("it was not cut smaller", len(mine))
    ul, ur, ll, lr = corners(tile)
    for d in mine:
        assert d["fade"], "a piece of it does not fade"
        way, a, b = d["fade"]
        # (what the fade is at the middle of the piece, against what the corners say there)
        fu, fv = (d["fu0"] + d["fu1"]) / 2, (d["fv0"] + d["fv1"]) / 2
        want = (ul + (ur - ul) * fu) * (1 - fv) + (ll + (lr - ll) * fu) * fv
        got = a if way == "FLAT" else (a + b) / 2
        assert 0 <= min(a, b) and max(a, b) <= 1 and abs(got - want) < 0.02, ("a piece fades wrongly", d["fade"], want)
    st, drawn = go(tile, VIEW * 5.5)
    assert 0.2 < st.ground < 0.8, ("the ground is not part way in", st.ground)
    missed = [i for i in shown if in_picture(i) and tiles[i] not in {d["fdid"] for d in drawn if d["layer"] == "ground"}]
    assert not missed, ("part way in, tiles in the picture are not drawn", missed)

    step("the window sized by its corner: the picture follows, wider than tall, and is filled to its edges")
    window, _view = ns.GlobeWindow()
    grip = [f for f in stub.frames.values() if f.scripts["OnMouseUp"] and not f.scripts["OnMouseWheel"]]
    assert len(grip) == 1, "no corner to size the window by"

    def size(w, h):
        window.SetSize(window, w, h)
        window.scripts["OnSizeChanged"](window, w, h)
        grip[0].scripts["OnMouseUp"](grip[0])          # (let go of the corner: the size is kept)
        frames(3)
        return ns.GlobeState()

    def in_box(st, drawn):
        for d in drawn:
            xs, ys = [p[0] for p in d["pts"]], [p[1] + st.lift for p in d["pts"]]
            assert max(xs) >= -st.w / 2 and min(xs) <= st.w / 2 and max(ys) >= -st.h / 2 and min(ys) <= st.h / 2, \
                ("a piece drawn outside the picture", d["layer"], xs, ys)

    r0 = ns.GlobeState().look.r
    st = size(820, 564)
    assert (st.w, st.h) == (800, 500), ("the picture did not follow the window", st.w, st.h)
    assert abs(st.look.r - r0) < 1e-6, "sizing the window changed the zoom"
    drawn = state()[1]
    in_box(st, drawn)
    assert [d for d in drawn if max(p[0] for p in d["pts"]) > 330] and [d for d in drawn if min(p[0] for p in d["pts"]) < -330], \
        "the wider picture is not filled to its sides"
    for _ in range(40):
        view.scripts["OnMouseWheel"](view, -1)
    frames(90)
    st = ns.GlobeState()
    assert st.ring and st.ring.top <= 250 and st.ring.bottom >= -250, ("zoomed right out, the ring and stand do not fit", st.ring.top, st.ring.bottom)
    assert st.ring.top > 230 and abs(st.look.r - st.rmin) < 1e-6, "the desk globe does not fill the picture's height"
    in_box(st, state()[1])

    step("full screen and back: the picture fills the screen, then the window is as it was left")
    ns.GlobeFull(True)
    frames(3)
    st = ns.GlobeState()
    assert (st.w, st.h) == (1002 - 20, 668 - 64), ("the picture does not fill the screen", st.w, st.h)
    assert G.PatchwerkForever_Thread_GlobeDB.window.full, "full screen is not remembered"
    assert abs(st.look.r - st.rmin) < 1e-6 and st.ring.top <= st.h / 2, "zoomed right out, it did not stay so"
    assert not grip[0].shown, "the corner is still there to size a full screen by"
    slash("full")
    frames(3)
    st = ns.GlobeState()
    assert (st.w, st.h) == (800, 500) and not G.PatchwerkForever_Thread_GlobeDB.window.full, ("not as it was left", st.w, st.h)

    step("Go To lists the continents and their zones: picking one turns the globe to it")
    ns.GlobeKey("goto")
    kalimdor_menu = [k for k in stub.menu.kids.values() if k.text == "Kalimdor"]
    assert kalimdor_menu and [k.text for k in stub.menu.kids.values()][:2] == ["The Whole Globe", "Where I Am"], "the list is not there"
    entries = [k.text for k in kalimdor_menu[0].kids.values()]
    assert entries[0] == "All Of Kalimdor" and entries[1:] == sorted(entries[1:]) and len(entries) == 25, entries
    [k for k in kalimdor_menu[0].kids.values() if k.text == "Durotar"][0].click()
    frames(90)
    st = ns.GlobeState()
    zone, lines = zone_state()
    assert st.byKeys and st.cross, "the middle of the picture is not marked"
    assert zone and zone.name == "Durotar" and lines, ("the zone at the middle is not Durotar", zone and zone.name)
    assert abs(st.look.r / max(st.rmin, 0.82 * 250 * (EYE - math.cos(zone.reach)) / (EYE * math.sin(zone.reach))) - 1) < 0.01, \
        "Durotar is not fitted in the picture"

    step("keys: held ones turn and zoom, Step Out and Fit do as the mouse does; the mouse takes the pointer back")
    lon, lat, r = st.look.lon, st.look.lat, st.look.r
    ns.GlobeKey("right", True)
    ns.GlobeKey("up", True)
    frames(30)
    assert st.look.lon > lon + 0.01 and st.look.lat > lat + 0.01, "the held keys did not turn the globe east and north"
    ns.GlobeKey("right", False)
    ns.GlobeKey("up", False)
    lon, lat = st.look.lon, st.look.lat
    frames(10)
    assert st.look.lon == lon and st.look.lat == lat, "it went on turning after the keys were let go"
    ns.GlobeKey("left", True)
    ns.GlobeKey("right", True)
    ns.GlobeKey("left", False)              # (letting go of the other of a pair does not stop this one)
    frames(10)
    assert st.look.lon > lon, "letting go of Left stopped Right"
    ns.GlobeKey("right", False)
    ns.GlobeKey("in", True)
    frames(40)
    ns.GlobeKey("in", False)
    frames(40)
    assert st.look.r > r * 1.5, ("the held key did not zoom in", r, st.look.r)
    r = st.look.r
    frames(10)
    assert st.look.r == r, "it went on zooming"
    ns.GlobeKey("back")
    frames(90)
    assert st.look.r < r, "Step Out did not step out"
    ns.GlobeGo(1, 38.5, 33.5, 600)            # (the Barrens in the middle, from far enough out)
    frames(90)
    zone, _lines = zone_state()
    assert zone and zone.id == 17, ("the zone at the middle is not the Barrens", zone and zone.name)
    r = st.look.r
    ns.GlobeKey("fit")
    frames(90)
    assert st.look.r > r * 1.2 and zone_state()[0].id == 17, "Fit did not fit the zone at the middle"
    r = st.look.r
    ns.GlobeKey("fit")
    frames(60)
    assert st.look.r > r * 1.3, "Fit on a zone already fitted did not go closer"
    stub.cursor[1], stub.cursor[2] = 0, 0
    view.scripts["OnMouseWheel"](view, -1)
    frames(5)
    assert not ns.GlobeState().byKeys and not ns.GlobeState().cross, "the mouse did not take the pointer back"

    step("a gamepad's sticks turn and zoom; closing the window lets everything go")
    lat, r = st.look.lat, st.look.r
    ns.GlobePad(0, -1, 0)
    frames(20)
    ns.GlobePad(0, 0, -1)
    frames(20)
    assert st.look.lat < lat - 0.005 and st.look.r < r, "the sticks did not turn it south and zoom out"
    assert ns.GlobeState().byKeys, "the sticks did not take the pointer"
    ns.GlobePad(0, 0, 0)
    frames(60)                                # (the zoom comes to rest)
    ns.GlobePad(-1, 0, 0)
    ns.GlobeKey("in", True)
    ns.Toggle()
    ns.Toggle(True)
    lon, r = st.look.lon, st.look.r
    frames(20)
    assert st.look.lon == lon and abs(st.look.r / r - 1) < 0.05 and not ns.GlobeState().byKeys, ("it went on after the window was closed", st.look.lon - lon, st.look.r / r, ns.GlobeState().byKeys)
    size(620, 664)
    assert (ns.GlobeState().w, ns.GlobeState().h) == (600, 600)

    step("a gamepad: its sticks and buttons are taken while the globe is open, and given back in combat")
    pad = ns.PadState()
    catcher = pad.catcher
    assert pad.taken and catcher and catcher.shown, ("the gamepad is not taken", pad.why)
    stick, down, up = catcher.scripts["OnGamePadStick"], catcher.scripts["OnGamePadButtonDown"], catcher.scripts["OnGamePadButtonUp"]
    st = ns.GlobeState()
    lon, r = st.look.lon, st.look.r
    assert stick(catcher, "Left", 1, 0) is False, "the left stick was passed on"
    frames(20)
    assert st.look.lon > lon + 0.005, "the left stick did not turn the globe"
    stick(catcher, "Left", 0.1, -0.05)                    # (at rest, near enough)
    lon = st.look.lon
    frames(10)
    assert st.look.lon == lon, "a stick at rest turns the globe"
    assert stick(catcher, "Camera", 0, 1) is False
    frames(20)
    stick(catcher, "Camera", 0, 0)
    frames(40)
    assert st.look.r > r * 1.2, "the right stick did not zoom in"
    assert stick(catcher, "Other", 1, 1) is True, "a stick the globe does not know was kept"
    r = st.look.r
    down(catcher, "PADLTRIGGER")
    frames(20)
    up(catcher, "PADLTRIGGER")
    frames(40)
    assert st.look.r < r and catcher.passes is False, "the left trigger did not zoom out"
    r = st.look.r
    frames(10)
    assert st.look.r == r, "it went on zooming after the trigger was let go"
    down(catcher, "PADDUP")
    assert catcher.passes is True, "a button the globe has no use for was kept from its binding"
    stick(catcher, "Left", 1, 0)
    stub.combat = True
    stub.Fire("PLAYER_REGEN_DISABLED")
    assert not catcher.shown and ns.PadState().why == "combat", "the gamepad was kept in combat"
    lon = st.look.lon
    frames(10)
    assert st.look.lon == lon, "the stick went on turning the globe in combat"
    stub.combat = False
    stub.Fire("PLAYER_REGEN_ENABLED")
    assert catcher.shown and ns.PadState().taken, "the gamepad was not taken again after combat"
    ns.Set("globePad", False)
    assert not catcher.shown and ns.PadState().why == "off"
    ns.Set("globePad", True)
    assert catcher.shown
    for _ in range(40):
        view.scripts["OnMouseWheel"](view, -1)
    frames(90)
    down(catcher, "PAD2")
    assert not window.shown and not catcher.shown, "from the whole globe, the second button did not close the window"
    ns.Toggle(True)
    frames(3)

    def tile(wx, wy):
        return (EDGE - wy) / TILE, (EDGE - wx) / TILE

    def go(wx, wy, r, map_id=1):
        gx, gy = tile(wx, wy)
        ns.GlobeGo(map_id, gx, gy, r)
        frames(90)

    def marks(source=None):
        frames(3)
        ms = ns.Marks.State()
        return [m for m in ms.marks.values() if source is None or m.source == source]

    def strokes(source):
        frames(3)
        return [tuple(t.values())[:4] for t in ns.Marks.State().strokes.values() if t[5] == source]

    def named(ms, name):
        found = [m for m in ms if m.name == name]
        assert len(found) == 1, (name, [m.name for m in ms])
        return found[0]

    def at(m, wx, wy, dy=0, map_id=1):
        x, y, _z = ns.GlobeWhere(map_id, wx, wy)
        assert abs(m.x - x) < 0.01 and abs(m.y - y - dy) < 0.01, ("a mark out of place", m.name, m.x - x, m.y - y)

    step("boats and zeppelins: where your side's put in, what they go to, and the way they sail")
    assert not marks(), "marks with nothing to mark"
    stub.player.side = "Horde"
    lua.execute(TRAILS)
    go(-1005.6, -3841.6, 700)                    # Ratchet in the middle, Orgrimmar and Theramore in the picture
    ms = marks("crossings")
    assert sorted(m.name for m in ms) == ["Orgrimmar", "Ratchet"], [m.name for m in ms]
    ratchet = named(ms, "Ratchet")
    at(ratchet, -1005.6, -3841.6)
    assert ratchet.icon.endswith("mark_boat") and named(ms, "Orgrimmar").icon.endswith("mark_zeppelin")
    assert list(ratchet.mark.lines.values()) == ["Boat to Booty Bay", "Wait: about 3 min"], list(ratchet.mark.lines.values())
    sea = strokes("crossings")
    assert sea and max(math.hypot(x2 - x1, y2 - y1) for x1, y1, x2, y2 in sea) < 9.5, "the way a boat sails is not dashed"
    # (the boat's way leaves Kalimdor's map and goes on over the sea toward the Eastern Kingdoms, to the east)
    ex, ey, _z = ns.GlobeWhere(1, -1867, -5197)
    assert [t for t in sea if t[0] > ex + 30], "the two halves of the boat's way are not joined over the sea"
    stub.player.side = "Alliance"
    ns.Marks.Changed("crossings")
    assert sorted(m.name for m in marks("crossings")) == ["Ratchet", "Theramore"], "the other side's zeppelin, or not your own boat"
    stub.player.side = "Horde"
    ns.Marks.Changed("crossings")
    ns.Set("globeCrossings", False)
    assert not marks("crossings") and not strokes("crossings"), "switched off, they stayed"
    ns.Set("globeCrossings", True)

    step("pointing at a mark names it; with keys, the one at the middle of the picture")
    stub.cursor[1], stub.cursor[2] = ratchet.x, ratchet.y + ns.GlobeState().lift
    frames(2)
    assert stub.tip.title == "Ratchet" and stub.tip.shown and list(stub.tip.lines.values())[0] == "Boat to Booty Bay", stub.tip.title
    stub.cursor[1], stub.cursor[2] = ratchet.x + 60, ratchet.y + ns.GlobeState().lift
    frames(2)
    assert stub.tip.title is None, "the tooltip stayed after the pointer left the mark"
    ns.GlobeKey("up", True)
    ns.GlobeKey("up", False)
    frames(2)
    assert ns.GlobeState().byKeys and stub.tip.title == "Ratchet", ("the mark at the cross is not named", stub.tip.title)
    view.scripts["OnMouseWheel"](view, 1)        # (the mouse takes the pointer back)
    frames(60)
    go(-1005.6, -3841.6, 700)

    step("your route: Thread (Routes)' trail in its colours, a flight a dashed arc, a boat joined over the sea")
    lua.execute(ROUTE)
    trail = strokes("trail")
    cx, cy, _z = ns.GlobeWhere(1, -442, -2598)
    rx, ry, _z = ns.GlobeWhere(1, -1006, -3842)
    ox, oy, _z = ns.GlobeWhere(1, 1677, -4315)
    walked = [t for t in trail if math.hypot(t[2] - t[0], t[3] - t[1]) > 12]
    assert walked and abs(walked[0][0] - cx) < 0.01 and abs(walked[0][1] - cy) < 0.01, "the walk does not start where the route does"
    assert all(min(t[1], t[3]) >= ry - 1 for t in walked), "a long stroke where the trail is dashed"

    def off_chord(x, y):
        return abs((ox - cx) * (y - cy) - (oy - cy) * (x - cx)) / math.hypot(ox - cx, oy - cy)

    north = [t for t in trail if t[1] > cy + 5 and t[3] > cy + 5]
    assert len(north) > 4 and max(math.hypot(t[2] - t[0], t[3] - t[1]) for t in north) < 9.5, "the flight is not dashed"
    assert 8 < max(off_chord(t[0], t[1]) for t in north) < 40, "the flight does not bow out"
    near_end = min(north, key=lambda t: math.hypot(t[2] - ox, t[3] - oy))
    assert math.hypot(near_end[2] - ox, near_end[3] - oy) < 16 and off_chord(near_end[2], near_end[3]) < 6,         ("the flight does not come down where it should", near_end)
    ex, ey, _z = ns.GlobeWhere(1, -1867, -5197)
    assert [t for t in trail if t[0] > ex + 30], "the boat's two halves are not joined over the sea"
    dots = [m for m in marks("trail") if m.icon.endswith("mark_dot")]
    assert len(dots) == 1, "no dot where the step after ends"
    at(dots[0], 1677, -4315)
    ns.Set("globeRoute", False)
    assert not strokes("trail") and not marks("trail"), "switched off, the trail stayed"
    ns.Set("globeRoute", True)
    lua.execute("STUB.trailList = {} PatchwerkForever.Trails:Changed()")
    assert not strokes("trail"), "the trail stayed after the route was gone"

    step("flight points: yours and the neutral ones, from zone level in; where marks crowd, one is kept")
    lua.execute('''
        STUB.TaxiAt(1414, 25, 'The Crossroads', -437, -2596, 1, false, 'TaxiNode_Known')
        STUB.TaxiAt(1414, 80, 'Ratchet', -894, -3773, 0, true, 'TaxiNode_NotInThisGame')
        STUB.TaxiAt(1414, 32, 'Theramore', -3828, -4517, 2, false, 'TaxiNode_Known')
    ''')
    ns.Marks.Changed("flights")
    assert not marks("flights"), "flight points with the whole continent in view"
    go(-1005.6, -3841.6, 900)
    ms = marks("flights")
    assert [m.name for m in ms] == ["The Crossroads"], ("the Alliance's, or the one crowded by the boat", [m.name for m in ms])
    assert ms[0].atlas and ms[0].icon == "TaxiNode_Known", "the game's own picture for it is not used"
    at(ms[0], -437, -2596)
    go(-1005.6, -3841.6, 4000)
    ms = marks()
    port = [m for m in ms if m.name == "Ratchet"]
    assert sorted(m.source for m in port) == ["crossings", "flights"], "closer in, the two marks at Ratchet are not both shown"
    flight = [m for m in port if m.source == "flights"][0]
    assert not flight.atlas and flight.icon.endswith("mark_flightoff"), flight.icon
    assert list(flight.mark.lines.values()) == ["Flight point, not discovered yet"]
    ns.Set("globeFlights", False)
    assert not marks("flights")
    ns.Set("globeFlights", True)

    step("herb and ore nodes, close in: those round the middle of the picture, asked for again only when it moves")
    go(-442, -2598, 2000)
    assert not marks("nodes"), "nodes shown from too far out"
    go(-442, -2598, 3500)
    ms = marks("nodes")
    assert sorted(m.name for m in ms) == ["Copper Vein", "Peacebloom"], [m.name for m in ms]
    at(named(ms, "Peacebloom"), -600, -2750)
    assert named(ms, "Peacebloom").icon == 133939 and list(named(ms, "Copper Vein").mark.lines.values()) == ["Ore"]
    asks = stub.nodeAsks
    frames(30)
    stub.cursor[1], stub.cursor[2] = 40, 40
    frames(5)
    assert stub.nodeAsks == asks, "the nodes are asked for again though nothing moved"
    go(-3000, -3000, 3500)
    assert stub.nodeAsks > asks and [m.name for m in marks("nodes")] == ["Far Herb"], "the nodes did not follow the picture"

    step("My Route's stops, numbered: a click lists what can be done with one")
    R = G.PatchwerkForever.MyRoute
    for label, wx, wy in (("First", -600.0, -3000.0), ("Second", -800.0, -3400.0), ("Third", -300.0, -2900.0)):
        assert R.Add(R, lua.table_from({"kind": "spot", "map": 1, "x": wx, "y": wy, "label": label})), "the stop was not added"
    go(-600, -3000, 900)
    ms = marks("stops")
    assert sorted(m.text for m in ms) == ["1", "2", "3"], [m.text for m in ms]
    second = [m for m in ms if m.text == "2"][0]
    at(second, -800, -3400)
    assert second.icon.endswith("mark_badge") and "My Route: stop 2 of 3" in list(second.mark.lines.values())
    r = ns.GlobeState().look.r
    point_at(-800.0, -3400.0)
    click()
    assert abs(ns.GlobeState().look.r - r) < 1e-6, "the click on a stop also zoomed to the zone under it"
    options = [k.text for k in stub.menu.kids.values()]
    assert options == ["Go Here First", "Move Earlier", "Move Later", "Remove From My Route"], options
    [k for k in stub.menu.kids.values() if k.text == "Move Earlier"][0].click()
    ms = marks("stops")
    first = [m for m in ms if m.text == "1"][0]
    at(first, -800, -3400)
    point_at(-800.0, -3400.0)
    click()
    options = [k.text for k in stub.menu.kids.values()]
    assert options == ["Go Here First", "Move Later", "Remove From My Route"], options
    [k for k in stub.menu.kids.values() if k.text == "Remove From My Route"][0].click()
    ms = marks("stops")
    assert sorted(m.text for m in ms) == ["1", "2"] and len(R.Entries(R)) == 2, "the stop was not removed"
    point_at(-300.0, -2900.0)
    click()
    [k for k in stub.menu.kids.values() if k.text == "Go Here First"][0].click()
    assert R.State(R)[1], "Go Here First did not lead the route there"
    R.Clear(R)
    assert not marks("stops"), "the stops stayed after the list was emptied"

    step("the map pin: Ctrl-click sets it on the zone's own map; a click tracks it, Shift-click links it, Ctrl-click clears it")
    x, y = point_at(-1500.0, -3000.0)
    r = ns.GlobeState().look.r
    stub.ctrl = True
    click()
    stub.ctrl = False
    pin = stub.pin
    assert pin and pin.uiMapID == 1413, ("the pin is not on the Barrens' own map", pin and pin.uiMapID)
    wantx, wanty = lua.eval("STUB.ToMap(1413, -1500, -3000)")
    assert abs(pin.position.x - wantx) < 1e-3 and abs(pin.position.y - wanty) < 1e-3, (pin.position.x, wantx, pin.position.y, wanty)
    assert abs(ns.GlobeState().look.r - r) < 1e-6 and not stub.tracked, "setting the pin also zoomed, or tracked it"
    pins = marks("pin")
    assert len(pins) == 1 and pins[0].icon.endswith("mark_pinoff"), "the pin is not shown"
    at(pins[0], -1500, -3000, dy=10)
    stub.cursor[1], stub.cursor[2] = pins[0].x, pins[0].y + ns.GlobeState().lift
    frames(2)
    assert stub.tip.title == "Map Pin" and "Not tracked" in list(stub.tip.lines.values())
    click()
    assert stub.tracked is True and marks("pin")[0].icon.endswith("mark_pin"), "a click on the pin did not track it"
    stub.shift = True
    click()
    stub.shift = False
    assert stub.linked and "worldmap" in stub.linked, "Shift-click did not link the pin"
    stub.ctrl = True
    click()
    assert stub.pin is None and not marks("pin") and stub.tracked is False, "Ctrl-click on the pin did not clear it"
    stub.noPinOn = 1413                          # (where the zone's map takes no pin, the continent's does)
    point_at(-1500.0, -3000.0)
    click()
    assert stub.pin and stub.pin.uiMapID == 1414, "the pin did not fall back to the continent's map"
    wantx, wanty = lua.eval("STUB.ToMap(1414, -1500, -3000)")
    assert abs(stub.pin.position.x - wantx) < 1e-4 and abs(stub.pin.position.y - wanty) < 1e-4
    stub.noPinOn = None
    stub.ctrl = False
    assert chat() == "", "something was said"
    ns.GlobeKey("pin")                           # (by key: at the middle of the picture, which the pin is not at)
    frames(3)
    wantx, wanty = lua.eval("STUB.ToMap(1413, -600, -3000)")
    assert stub.pin.uiMapID == 1413 and abs(stub.pin.position.x - wantx) < 1e-3 and abs(stub.pin.position.y - wanty) < 1e-3, \
        "Set Or Clear The Map Pin did not set it at the middle of the picture"
    ns.GlobeKey("pin")
    frames(3)
    assert stub.pin is None, "pressed again with the pin at the middle, it did not clear it"
    view.scripts["OnMouseWheel"](view, -1)
    frames(60)

    step("your quests: numbered where each is done, a ? where one is handed in")
    lua.execute('''
        STUB.QuestAt(870, 'The Forgotten Pools', 1, -1100, -2900)
        STUB.QuestAt(871, 'Disrupt the Attacks', 1, -500, -3300)
        STUB.QuestAt(872, 'Plainstrider Menace', 1, -437, -2596)
        STUB.QuestAt(873, 'A Quest With No Place', 1, 0, 0)
        STUB.quests[873].uiMap = 0
        STUB.quests[870].objectives = { { text = 'Explore the pools', finished = false }, { text = 'Find the fissure', finished = true } }
        STUB.quests[872].done = true
        STUB.questOrder = { 870, 873, 871, 872 }
        STUB.focus = 0
    ''')
    stub.Fire("QUEST_LOG_UPDATE")
    go(-600, -3000, 900)
    ms = marks("quests")
    assert sorted(m.name for m in ms) == ["Disrupt the Attacks", "Plainstrider Menace", "The Forgotten Pools"], [m.name for m in ms]
    pools, attacks, menace = named(ms, "The Forgotten Pools"), named(ms, "Disrupt the Attacks"), named(ms, "Plainstrider Menace")
    at(pools, -1100, -2900)
    assert (pools.text, attacks.text, menace.text) == ("1", "2", None), (pools.text, attacks.text, menace.text)
    assert pools.icon.endswith("mark_badge") and menace.icon.endswith("mark_ask") and pools.size == 20
    assert not [m for m in marks() if m.name == "The Crossroads"], "the flight point was kept over the quest handed in beside it"
    stub.cursor[1], stub.cursor[2] = pools.x, pools.y + ns.GlobeState().lift
    frames(2)
    tip = list(stub.tip.lines.values())
    assert stub.tip.title == "The Forgotten Pools" and tip[0] == "Explore the pools" and "Find the fissure" in tip[1], tip
    assert "Click to route to this quest." in tip[-1], tip

    step("a click chooses the quest: it is picked out, ringed, and turned to; a click on it again goes back")
    Ch = G.PatchwerkForever.Choice
    click()
    assert Ch.Get(Ch) and Ch.Get(Ch).id == 870 and stub.focus == 870, "the click did not choose the quest"
    x, y, _z = ns.GlobeWhere(1, -1100, -2900)
    assert abs(x) < 1 and abs(y) < 1 and abs(ns.GlobeState().look.r - 1440) < 2, ("the globe did not turn to the quest", x, y, ns.GlobeState().look.r)
    ms = marks("quests")
    pools = named([m for m in ms if m.name], "The Forgotten Pools")
    assert pools.size == 26 and pools.mark.picked, "the chosen quest is not picked out"
    rings = [m for m in ms if m.icon.endswith("mark_ring")]
    assert len(rings) == 1 and rings[0].size >= 34, "no ring round where the chosen quest is done"
    at(rings[0], -1100, -2900)
    stub.cursor[1], stub.cursor[2] = pools.x, pools.y + ns.GlobeState().lift
    frames(2)
    assert "Click to go back to your main route." in list(stub.tip.lines.values())[-1]
    click()
    assert Ch.Get(Ch) is None and not [m for m in marks("quests") if m.icon.endswith("mark_ring")], "the second click did not go back"
    lua.execute("PatchwerkForever.Following:Set({ kind = 'quest', quest = 871, key = 'q871' })")
    assert named([m for m in marks("quests") if m.name], "Disrupt the Attacks").size == 26, "the quest the route follows is not picked out"
    lua.execute("PatchwerkForever.Following:Set(nil)")
    lua.execute("PatchwerkForever.Choice:Set('quest', 871)")       # (as a click on it in the tracker does)
    frames(90)
    x, y, _z = ns.GlobeWhere(1, -500, -3300)
    assert abs(x) < 1 and abs(y) < 1, "a quest chosen in the tracker did not turn the globe to it"
    Ch.Clear(Ch)
    ns.Set("globeQuests", False)
    assert not marks("quests"), "switched off, the quests stayed"
    ns.Set("globeQuests", True)

    step("quests on offer in the zone at the middle of the picture, from zone level in")
    lua.execute('''
        STUB.OfferAt(1413, 900, "Sergra's Task", -100, -3000, false)
        STUB.OfferAt(1413, 901, 'One You Hold', -700, -3100, true)
    ''')
    stub.Fire("QUESTLINE_UPDATE")
    go(-600, -3000, 900)
    offers = marks("offers")
    assert stub.offersAsked == 1413 and [m.name for m in offers] == ["Sergra's Task"], [m.name for m in offers]
    at(offers[0], -100, -3000)
    assert offers[0].icon.endswith("mark_bang") and list(offers[0].mark.lines.values()) == ["Available quest"]
    go(-600, -3000, 500)
    assert not marks("offers"), "offers shown with the whole continent in view"

    step("a guide's steps, numbered from the one you are on; a side list's quests, and a click follows that list")
    lua.execute(GUIDES)
    stub.guideOn, stub.sideOn = True, True
    go(-600, -3000, 900)
    frames(200)                                  # (the steps are read again every few seconds)
    steps = marks("steps")
    now = named(steps, "Kill 8 Plainstriders")
    at(now, -700, -2700)
    assert now.text == "1" and now.size == 24 and list(now.mark.lines.values())[0] == "Fake Guide: the step you are on", list(now.mark.lines.values())
    after = named(steps, "Turn in Plainstrider Menace")
    assert after.text == "2" and list(after.mark.lines.values())[0] == "Fake Guide: step 5"
    side = named(steps, "Pick up Leaders of the Fang")
    assert side.icon.endswith("mark_bang") and "Dungeon Journal" in list(side.mark.lines.values())
    point_at(-1700.0, -3500.0)
    click()
    choice = Ch.Get(Ch)
    assert choice and choice.kind == "guide" and choice.id == "side", "the click did not follow the side list"
    Ch.Clear(Ch)
    stub.guideOn, stub.sideOn = False, False
    frames(200)
    assert not marks("steps"), "the steps stayed after the guide stopped"

    step("Next Mark, by key: the globe turns to each mark in turn, and Fit presses the one at the middle")
    go(-600, -3000, 900)
    ms = [m for m in marks() if m.name]
    assert len(ms) >= 4
    first = min(ms, key=lambda m: math.hypot(m.x, m.y))
    ns.GlobeKey("next")
    frames(90)
    middle = [m for m in marks() if m.name and math.hypot(m.x, m.y) < 1.5]
    assert [m.name for m in middle] == [first.name] and stub.tip.title == first.name, ([m.name for m in middle], first.name, stub.tip.title)
    seen = {first.name}
    for _ in range(2):
        ns.GlobeKey("next")
        frames(90)
        middle = [m for m in marks() if m.name and math.hypot(m.x, m.y) < 1.5]
        assert len(middle) == 1 and middle[0].name not in seen, ("Next Mark went back to one it had been to", [m.name for m in middle], seen)
        seen.add(middle[0].name)
    while not [m for m in marks("quests") if m.name == "The Forgotten Pools" and math.hypot(m.x, m.y) < 1.5]:
        ns.GlobeKey("next")
        frames(90)
        assert len(seen) < 30
        seen.add(len(seen))
    ns.GlobeKey("fit")
    frames(90)
    assert Ch.Get(Ch) and Ch.Get(Ch).id == 870, "Fit did not press the mark at the middle"
    Ch.Clear(Ch)
    view.scripts["OnMouseWheel"](view, 1)
    frames(60)

    step("the Route button: what the route follows, the map pin added to My Route, My Route's editor beside the globe")
    button = ns.QuestsState().button
    assert button and button.text == "Route", "no Route button"
    button.scripts["OnClick"](button)
    assert stub.menu.title == "Route" and [k.text for k in stub.menu.kids.values()] == ["Follow"], [k.text for k in stub.menu.kids.values()]
    follow = list(stub.menu.kids[1].kids.values())
    assert [k.text for k in follow][0] == "Auto" and "My Route" in [k.text for k in follow], [k.text for k in follow]
    assert follow[0].selected() is True
    [k for k in follow if k.text == "My Route"][0].click()
    F = G.PatchwerkForever.Focus
    assert F.Get(F) == "route", "picking My Route did not make it the focus"
    F.Set(F, "auto")
    lua.execute('''
        STUB.PinAt(1, -1500, -3000)
        function PatchwerkForever_Thread_Tracker_OpenMyRoute(anchor) STUB.editorBeside = anchor return true end
    ''')
    ns.GlobeKey("route")                         # (the Route Menu key opens the same list)
    names = [k.text for k in stub.menu.kids.values()]
    assert names == ["Follow", "Add Map Pin To My Route", "Edit My Route"], names
    stub.menu.kids[2].click()
    stops = list(R.Entries(R).values())
    assert len(stops) == 1 and stops[0].kind == "spot" and abs(stops[0].x + 1500) < 1 and abs(stops[0].y + 3000) < 1, "the pin was not added to My Route"
    stub.menu.kids[2].click()
    assert "already in My Route" in chat() and len(R.Entries(R)) == 1
    stub.menu.kids[3].click()
    assert lua.eval("STUB.editorBeside == PatchwerkForever_Thread_GlobeWindow"), "My Route's editor was not opened beside the globe"
    R.Clear(R)
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")

    step("Thread (Tracker)'s list beside the globe while it is open, and back after")
    lua.execute('''
        STUB.docks = 0
        function PatchwerkForever_Thread_Tracker_Dock(anchor) STUB.dockedTo = anchor or false; STUB.docks = STUB.docks + 1 return anchor ~= nil end
    ''')
    ns.Toggle()
    assert not stub.dockedTo, "the tracker was moved with the globe closed"
    ns.Toggle(True)
    frames(3)
    assert lua.eval("STUB.dockedTo == PatchwerkForever_Thread_GlobeWindow") and ns.QuestsState().docked, "the tracker was not put beside the globe"
    n = stub.docks
    ns.GlobeFull(True)
    assert stub.docks > n and lua.eval("STUB.dockedTo == PatchwerkForever_Thread_GlobeWindow"), "full screen did not put the tracker over it again"
    ns.GlobeFull(False)
    ns.Set("globeTracker", False)
    assert stub.dockedTo is False, "switched off, the tracker stayed beside the globe"
    ns.Set("globeTracker", True)
    assert lua.eval("STUB.dockedTo == PatchwerkForever_Thread_GlobeWindow")
    ns.GlobeKey("route")
    names = [k.text for k in stub.menu.kids.values()]
    assert names[-1] == "Tracker Beside The Globe" and stub.menu.kids[len(names)].selected() is True, names
    ns.Toggle()
    assert stub.dockedTo is False, "the tracker was not put back when the globe closed"
    ns.Toggle(True)
    frames(3)
    lua.execute("STUB.quests, STUB.questOrder, STUB.offers = {}, {}, {}")
    stub.Fire("QUEST_LOG_UPDATE")
    stub.Fire("QUESTLINE_UPDATE")

    step("places: the zone's towns and entrances with the game's icons and names, from zone level in")
    for key in ("globeFlights", "globeCrossings", "globeNodes"):
        ns.Set(key, False)                       # (so that nothing of theirs stands where a place does)
    lua.execute("""
        STUB.atlases['poi-town'], STUB.atlases.Raid = true, true
        STUB.PoiAt(1413, 501, 'The Crossroads', -442, -2598, 5, nil, 'Horde town')
        STUB.PoiAt(1413, 502, 'Northwatch Hold', -2100, -3600, nil, 'poi-town')
        STUB.PoiAt(1413, 503, 'Camp Taurajo', -2380, -1880, nil, 'a-picture-this-game-lacks')
        STUB.PoiAt(1413, 504, '', -1000, -3000, 6)
        STUB.EntranceAt(1413, 900, 'Wailing Caverns', -740, -2214, 'Dungeon')
        STUB.EntranceAt(1413, 901, 'Razorfen Downs', -1900, -2700, 'Raid')
    """)
    stub.Fire("AREA_POIS_UPDATED")
    go(-1200, -2800, 900)
    ms = marks("places")
    assert sorted(m.name for m in ms) == ["Camp Taurajo", "Northwatch Hold", "Razorfen Downs", "The Crossroads", "Wailing Caverns"],         [m.name for m in ms]
    town = named(ms, "The Crossroads")
    at(town, -442, -2598)
    assert town.icon == "Interface\\Minimap\\POIIcons" and not town.atlas, town.icon
    assert list(town.mark.coords.values()) == [5 / 16, 6 / 16, 0.25, 0.3125], "not the town's piece of the game's sheet of icons"
    assert list(town.mark.lines.values()) == ["Horde town"]
    hold = named(ms, "Northwatch Hold")
    assert hold.atlas and hold.icon == "poi-town", "the game's own named picture was not used"
    assert named(ms, "Camp Taurajo").icon.endswith("mark_place"), "a picture this game lacks was not replaced by ours"
    cave, raid = named(ms, "Wailing Caverns"), named(ms, "Razorfen Downs")
    at(cave, -740, -2214)
    assert list(cave.mark.lines.values()) == ["Dungeon"] and cave.icon.endswith("mark_place")
    assert list(raid.mark.lines.values()) == ["Raid"] and raid.icon == "Raid"
    stub.cursor[1], stub.cursor[2] = cave.x, cave.y + ns.GlobeState().lift
    frames(2)
    assert stub.tip.title == "Wailing Caverns" and list(stub.tip.lines.values()) == ["Dungeon"], stub.tip.title
    go(-1200, -2800, 600)
    assert not marks("places"), "places shown from further out than a zone"
    go(-1200, -2800, 900)
    assert len(marks("places")) == 5
    ns.Set("globePlaces", False)
    assert not marks("places"), "switched off, the places stayed"
    ns.Set("globePlaces", True)

    step("your group: each member in their class's colour, grey when dead; none whose place the game keeps to itself")
    assert not marks("people")
    lua.execute("""
        STUB.group = {
            party1 = { name = 'Tessa', class = 'MAGE', className = 'Mage', x = -500, y = -2700, map = 1 },
            party2 = { name = 'Brom', class = 'WARRIOR', className = 'Warrior', x = STUB.secret, y = STUB.secret, map = 1 },
            party3 = { name = 'Ilse', class = 'WARRIOR', className = 'Warrior', x = -900, y = -3300, map = 1, dead = true },
            party4 = { name = 'Odo', class = 'MAGE', className = 'Mage' },
        }
    """)
    stub.Fire("GROUP_ROSTER_UPDATE")
    ms = marks("people")
    assert sorted(m.name for m in ms) == ["Ilse", "Tessa"], [m.name for m in ms]
    tessa, ilse = named(ms, "Tessa"), named(ms, "Ilse")
    at(tessa, -500, -2700)
    assert tessa.icon.endswith("mark_person") and [round(v, 2) for v in tessa.mark.tint.values()] == [0.25, 0.78, 0.92], "not in her class's colour"
    assert list(tessa.mark.lines.values()) == ["Mage"]
    assert [round(v, 2) for v in ilse.mark.tint.values()] == [0.6, 0.6, 0.6] and list(ilse.mark.lines.values()) == ["Warrior", "Dead"]
    assert not [m for m in marks("places") if m.name == "The Crossroads"], "a town kept over the friend standing in it"
    lua.execute("STUB.group.party1.x = -650")
    frames(80)                                   # (more than a second: they are looked for again)
    at(named(marks("people"), "Tessa"), -650, -2700)
    lua.execute("""
        STUB.raid = true
        STUB.group = {
            raid1 = { name = 'Walker', me = true, class = 'WARRIOR', className = 'Warrior', x = -442, y = -2598, map = 1 },
            raid2 = { name = 'Tessa', class = 'MAGE', className = 'Mage', x = -500, y = -2700, map = 1 },
        }
    """)
    stub.Fire("GROUP_ROSTER_UPDATE")
    assert [m.name for m in marks("people")] == ["Tessa"], "in a raid: not its members, or yourself among them"
    ns.Set("globePeople", False)
    assert not marks("people"), "switched off, they stayed"
    ns.Set("globePeople", True)
    assert len(marks("people")) == 1
    lua.execute("STUB.group, STUB.raid = {}, false")
    stub.Fire("GROUP_ROSTER_UPDATE")
    assert not marks("people"), "marks of a group you have left"

    step("while you are dead: your corpse and the spirit healer")
    assert not marks("death")
    lua.execute("STUB.dead = true STUB.corpse = { ui = 1414, x = -1500, y = -2900 } STUB.release = { ui = 1414, x = -430, y = -2400 }")
    stub.Fire("PLAYER_DEAD")
    ms = marks("death")
    assert sorted(m.name for m in ms) == ["Corpse", "Spirit Healer"], [m.name for m in ms]
    at(named(ms, "Corpse"), -1500, -2900)
    at(named(ms, "Spirit Healer"), -430, -2400)
    assert named(ms, "Corpse").icon.endswith("mark_grave")
    lua.execute("STUB.dead = false")
    stub.Fire("PLAYER_UNGHOST")
    assert not marks("death"), "alive again, the corpse stayed"
    lua.execute("STUB.pois, STUB.entrances, STUB.corpse, STUB.release = {}, {}, nil, nil")
    stub.Fire("AREA_POIS_UPDATED")
    assert not marks("places")

    step("words: the zone's levels by its name, the smaller place under the pointer, coordinates")
    import re
    zone_text = ns.G.ZoneText()
    words = lambda: (frames(40), zone_text.text)[1]
    point_at(-1400, -3300)                       # (open land of the Barrens, of no smaller place)
    assert words() == "The Barrens |cffffd100(10-25)|r", zone_text.text
    assert ns.PlacesState().area is None, ("a smaller place named in the open Barrens", ns.PlacesState().area)
    stub.level = 5
    stub.Fire("PLAYER_LEVEL_UP")
    assert words() == "The Barrens |cffff1a1a(10-25)|r", zone_text.text
    stub.level = 40
    stub.Fire("PLAYER_LEVEL_UP")
    assert words() == "The Barrens |cff808080(10-25)|r", zone_text.text
    stub.level = 20
    stub.Fire("PLAYER_LEVEL_UP")
    point_at(*CROSSROADS)
    assert words() == "The Barrens |cffffd100(10-25)|r"
    st = ns.PlacesState()
    assert st.area == "The Crossroads" and st.areaText.shown and st.areaText.text == "The Crossroads", st.area
    to_map = lua.eval("function(id, wx, wy) return STUB.ToMap(id, wx, wy) end")

    def coords():
        frames(12)
        text = ns.PlacesState().coords
        return text, [float(n) for n in re.findall(r"-?\d+\.\d", text)]

    px, py = to_map(1414, stub.player.x, stub.player.y)
    cx, cy = to_map(1413, *CROSSROADS)
    text, numbers = coords()
    assert re.fullmatch(r"Player: [\d.]+, [\d.]+    Cursor: [\d.]+, [\d.]+", text), text
    assert all(abs(a - b * 100) < 0.11 for a, b in zip(numbers, (px, py, cx, cy))), (numbers, px, py, cx, cy)
    assert st.coordsText.shown and st.coordsText.text == text
    point_at(*RAZOR_HILL)                        # (the game's map there is the Barrens': not Durotar's levels)
    assert words() == "Durotar", zone_text.text
    point_at(1700, -4400)                        # (no zone's map there: the continent's coordinates)
    dx, dy = to_map(1414, 1700, -4400)
    text, numbers = coords()
    assert all(abs(a - b * 100) < 0.11 for a, b in zip(numbers, (px, py, dx, dy))), (numbers, dx, dy)
    stub.over = False                            # (the pointer off the picture: yours alone)
    text, numbers = coords()
    assert re.fullmatch(r"Player: [\d.]+, [\d.]+", text), text
    stub.over = True
    ns.GlobeKey("up", True)                      # (with keys, the place at the middle of the picture)
    ns.GlobeKey("up", False)
    text, numbers = coords()
    assert ns.GlobeState().byKeys and re.fullmatch(r"Player: [\d.]+, [\d.]+    Middle: [\d.]+, [\d.]+", text), text
    view.scripts["OnMouseWheel"](view, 1)        # (the mouse takes the pointer back)
    frames(60)
    ns.Set("globeCoords", False)
    assert coords()[0] == "" and not ns.PlacesState().coordsText.shown, "switched off, the coordinates stayed"
    ns.Set("globeCoords", True)
    go(-1200, -2800, 600)
    point_at(*CROSSROADS)
    assert words().startswith("The Barrens") and ns.PlacesState().area is None, "a smaller place named from further out than a zone"
    for key in ("globeFlights", "globeCrossings", "globeNodes"):
        ns.Set(key, True)

    step("Minimap Pictures: no parchment, the ground at every zoom")
    ns.Set("globeStyle", "minimap")
    for _ in range(40):
        view.scripts["OnMouseWheel"](view, -1)
    frames(80)
    look, drawn, labels = state()
    assert not [d for d in drawn if d["layer"] in ("art", "ours", "detail", "decor")], "the parchment stayed"
    assert len(drawn) > 200, ("zoomed right out, the world is gone", len(drawn))
    within_globe(look, drawn)
    assert chat() == "", "something was said"
    print("Thread (Globe): all passed.")


if __name__ == "__main__":
    main()
