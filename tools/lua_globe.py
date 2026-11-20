"""Thread (Globe), run outside the game: Patchwerk Forever and Thread (Globe) loaded into a stand-in for
the game (wowstub.lua), with what the globe needs added to it.

    python lua_globe.py

It reads what the globe drew through ns.GlobeState(): the pieces (their pictures, the part of them, where
their corners are seen) and the names. It checks the continent maps on parchment with their edges fading,
pieces cut where they cross the globe's edge (none folded), the names fading by zoom, Where I Am gliding
to a character at the Crossroads with the arrow turned the way they face, the ground fading in over the map
with the Crossroads' tile under the arrow (east to the right, south below), zooming toward the pointer,
a drag that carries on, a double-click zoom, and Minimap Pictures. How it looks, and how fast, only the
game can say.
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
    function t:SetDrawLayer(layer, sub) assert(layer == 'ARTWORK' and sub >= -8 and sub <= 7) end
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
        'StartMoving', 'StopMovingOrSizing' }) do
        f[fn] = f[fn] or function() end
    end
    function f:GetName() return name end
    return f
end
local uiCreate = UIParent.CreateTexture
function UIParent:CreateTexture(...) return Bendable(uiCreate(self, ...)) end
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
function CreateColor(r, g, b, a)
    return { r = r, g = g, b = b, a = a, SetRGBA = function(self, r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end }
end
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
                          "pts": list(zip(list(d.x.values()), list(d.y.values())))})   # ul, ll, ur, lr
        labels = {l.text: l for l in st.labels.values()}
        return st.look, drawn, labels

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
            assert (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1) >= -1e-6, ("a piece folded", d)

    stub.player.x, stub.player.y, stub.player.map = -442.0, -2598.0, 1      # the Crossroads
    stub.Fire("PLAYER_LOGIN")
    stub.Fire("PLAYER_ENTERING_WORLD", True, False)
    chat()
    on = [s for s in stub.settings.values() if s.page == "Thread: Globe"]
    assert len(on) == 4, len(on)                  # (four settings; the button is not one)
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

    step("Minimap Pictures: no parchment, the ground at every zoom")
    ns.Set("globeStyle", "minimap")
    for _ in range(40):
        view.scripts["OnMouseWheel"](view, -1)
    frames(80)
    look, drawn, labels = state()
    assert not [d for d in drawn if d["layer"] == "art"], "the parchment stayed"
    assert len(drawn) > 200, ("zoomed right out, the world is gone", len(drawn))
    within_globe(look, drawn)
    assert chat() == "", "something was said"
    print("Thread (Globe): all passed.")


if __name__ == "__main__":
    main()
