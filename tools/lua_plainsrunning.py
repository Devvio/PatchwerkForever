"""Run Immersive Plainsrunning (Thread) outside the game, on the base, against the stand-in for the game
(wowstub.lua) with what it needs added.

    python lua_plainsrunning.py

Plays: the buff stacking from 1 to 30 (the interface fading a step at a time, gone at 30, then the
streaks), standing still, a window opened, typing, a fight (the interface back that very moment), the
Show Interface key, /plains show, the buff ending, the preview, speed mode disabled, the racial passive
of the same name (never taken for the buff), the other effects turned on and off one by one, the parts
of the interface kept (and a protected one left alone in a fight), the camera going back and coming in
(also at the game's furthest zoom), the run records (a first run, a record beaten, a run seen from the
middle, a mounted stretch, the preview not counted, reset), the other ways of going fast (a mount, a
travel form by its number, by the stance bar and by an aura, a flight; each off at first, on any race,
the wait, a long stop, Plainsrunning winning, auras hidden in a fight, functions missing, a problem),
the wind showing the way (no service, no route, a turn to either side, a route behind, the place or the
facing unknown or secret, another continent, a flight, how seldom the trail is read, a problem), and a
problem in the middle of a run (the interface put back). It fails loudly on any Lua error, and on any
alpha out of range.

What this proves: the addon's own code runs and does sensible things with the stand-in's answers.
What it cannot prove: how the effects look, that every window of Forever brings the interface back,
that the game lets the parts kept ignore the interface's alpha, that Forever's travel forms and aspects
have the numbers and names assumed, or what speed it gives for a flight. That is for the game.
"""
import math
import os
import sys

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ADDONS = os.path.normpath(os.path.join(HERE, "..", "addons"))
BASE = "PatchwerkForever"
PLAINS = "PatchwerkForever_Thread_Plainsrunning"

# what the stand-in lacks for this one
MORE = r"""
STUB.auras, STUB.speed, STUB.dead, STUB.focus = {}, 0, false, nil
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id)
        for _, a in ipairs(STUB.auras) do if a.spellId == id then return a end end
    end,
    GetAuraDataByIndex = function(unit, i, filter)
        assert(unit == 'player' and filter == 'HELPFUL')
        return STUB.auras[i]
    end,
}
function GetUnitSpeed(unit) assert(unit == 'player') return STUB.speed end
-- the race, and a secret number as the game hands one over while it restricts a value: any sum,
-- comparison or joining with it fails, as in the game
STUB.race = 'Tauren'
function UnitRace(unit)
    assert(unit == 'player')
    if STUB.race == 'Tauren' then return 'Tauren', 'Tauren', 6 end
    return 'Human', 'Human', 1
end
local function NoSecrets() error('attempt to perform arithmetic on a secret number value') end
SECRET = setmetatable({}, { __add = NoSecrets, __sub = NoSecrets, __mul = NoSecrets, __div = NoSecrets,
    __unm = NoSecrets, __mod = NoSecrets, __pow = NoSecrets, __lt = NoSecrets, __le = NoSecrets,
    __eq = NoSecrets, __concat = NoSecrets, __len = NoSecrets })
function issecretvalue(v) return rawequal(v, SECRET) end
local realToNumber = tonumber
function tonumber(v, ...) if rawequal(v, SECRET) then return v end return realToNumber(v, ...) end
function UnitAffectingCombat(unit) return STUB.combat == true end
function UnitIsDeadOrGhost(unit) return STUB.dead end
function GetCurrentKeyBoardFocus() return STUB.focus end
STUB.mounted, STUB.zoomMax = false, 30
function IsMounted() return STUB.mounted end
function UnitInVehicle() return false end
-- the camera: there at once (the game eases it), never past its furthest
function CameraZoomOut(yards) assert(yards > 0) STUB.zoom = math.min(STUB.zoomMax, STUB.zoom + yards) end
function CameraZoomIn(yards) assert(yards > 0) STUB.zoom = math.max(0, STUB.zoom - yards) end
date = os.date
NUM_CHAT_WINDOWS = 10
WorldFrame = CreateFrame('Frame')
WorldMapFrame.shown = false                -- (the stand-in's map starts open)
UIParent.alpha = 1
-- a Line, as the streaks use it
local Create = CreateFrame
local children = {}
function UIParent:GetChildren() return unpack(children) end
function CreateFrame(...)
    local frame = Create(...)
    if select(3, ...) == UIParent then children[#children + 1] = frame end
    local MakeLine = frame.CreateLine
    function frame:CreateLine(...)
        local line = MakeLine(self, ...)
        function line:SetTexture(path) assert(type(path) == 'string') self.texture = path end
        function line:SetBlendMode(mode) assert(mode == 'ADD' or mode == 'BLEND') end
        function line:SetVertexColor(r, g, b) assert(r and g and b) end
        function line:SetAlpha(a) assert(a >= 0 and a <= 1, 'alpha out of range: ' .. tostring(a)) self.alpha = a end
        function line:IsShown() return self.shown end
        return line
    end
    function frame:SetIgnoreParentAlpha(on)
        assert(type(on) == 'boolean')
        assert(not (self.protected and STUB.combat), 'a protected frame changed in a fight')
        self.ignore = on
    end
    function frame:IsIgnoringParentAlpha() return self.ignore == true end
    function frame:IsProtected() return self.protected == true end
    local MakeTexture = frame.CreateTexture
    function frame:CreateTexture(...)
        local tex = MakeTexture(self, ...)
        local SetAlpha = tex.SetAlpha
        function tex:SetAlpha(a) SetAlpha(self, a) self.alpha = a end
        return tex
    end
    return frame
end
MinimapCluster, Minimap = CreateFrame('Frame'), CreateFrame('Frame')
Minimap.cx, Minimap.cy, Minimap.width, Minimap.height = 900, 600, 140, 140
-- another addon's layer laid over the minimap (as Routes (Thread) draws its path), and one elsewhere
STUB.pathLayer = CreateFrame('Frame', nil, UIParent)
STUB.pathLayer.cx, STUB.pathLayer.cy, STUB.pathLayer.width, STUB.pathLayer.height = 900, 600, 140, 140
STUB.otherLayer = CreateFrame('Frame', nil, UIParent)
STUB.otherLayer.cx, STUB.otherLayer.cy, STUB.otherLayer.width, STUB.otherLayer.height = 500, 400, 140, 140
PlayerFrame, TargetFrame = CreateFrame('Frame'), CreateFrame('Frame')
PlayerFrame.protected, TargetFrame.protected = true, true
ChatFrame1, ChatFrame1Tab = CreateFrame('Frame'), CreateFrame('Frame')
-- shapeshift forms: the form's number, and the stance bar ({ { spell =, active = }, ... })
STUB.form, STUB.stance = nil, {}
function GetShapeshiftFormID() return STUB.form end
function GetNumShapeshiftForms() return #STUB.stance end
function GetShapeshiftFormInfo(i)
    local s = assert(STUB.stance[i], 'no such stance button')
    return 'icon', s.active, true, s.spell
end
-- an aura by its name; STUB.aurasSecret: the game hands a secret over instead of an aura
C_UnitAuras.GetAuraDataBySpellName = function(unit, name, filter)
    assert(unit == 'player' and type(name) == 'string' and filter == 'HELPFUL')
    if STUB.aurasSecret then return SECRET end
    for _, a in ipairs(STUB.auras) do if a.name == name then return a end end
end
local ByID = C_UnitAuras.GetPlayerAuraBySpellID
C_UnitAuras.GetPlayerAuraBySpellID = function(id)
    if STUB.aurasSecret then return SECRET end
    return ByID(id)
end
-- Routes (Thread), as far as the base's Trails service is concerned: the trail you are on (STUB.trail)
-- and a leg ahead of it leading somewhere else; STUB.listed counts how often it is asked
STUB.trail, STUB.listed = nil, 0
STUB.provider = {
    List = function()
        STUB.listed = STUB.listed + 1
        if STUB.listFails then error('the route said no') end
        return { STUB.trail, { follow = false, pieces = { { map = 1, how = 'walk', points = { { 0, 0 }, { 0, -900 } } } } } }
    end,
    Crossings = function() return {} end,
    NodesAround = function() end,
}
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
    for addon in (BASE, PLAINS):
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
    for addon in (BASE, PLAINS):
        tables[addon] = lua.table()
        for path in toc_files(os.path.join(ADDONS, addon), addon):
            load(open(path, encoding="utf-8").read(), "@" + addon + "/" + os.path.basename(path), addon, tables[addon])
        stub.Fire("ADDON_LOADED", addon)
    ns = tables[PLAINS]
    assert ns.linked, "the tool did not join the base"
    slash = G.SlashCmdList.PATCHWERKFOREVER_PLAINS
    said = [0]

    def chat(problems_ok=False):
        new = list(stub.messages.values())[said[0]:]
        said[0] += len(new)
        for text in new:
            print("      chat: " + text.replace("|cffe0b04d", "").replace("|r", ""))
        if not problems_ok:
            problems = [t for t in new if "a problem" in t.lower() or "error" in t.lower()]
            assert not problems, problems
        return " / ".join(new)

    def run(seconds):
        for _ in range(int(seconds / 0.016) + 1):
            stub.time += 0.016
            stub.Frame()

    def step(label):
        print("  " + label)

    def alpha():
        return G.UIParent.alpha if G.UIParent.alpha is not None else 1

    def state():
        fade, stacks, base, running, testing = ns.State()
        return fade, stacks, running

    def buff(n, spell=1299038, name="Plainsrunning", secret=False):
        auras = [{"spellId": 1259918, "name": "Plainsrunning", "applications": 0}]       # the passive, always there
        if n:
            auras.append({"spellId": spell, "name": name, "applications": G.SECRET if secret else n})
        stub.auras = lua.table_from([lua.table_from(a) for a in auras])
        stub.Fire("UNIT_AURA", "player")

    def streaks():
        n, strength = ns.StreaksShown()
        return n, strength

    stub.time = 100
    stub.Fire("PLAYER_LOGIN")
    stub.Fire("PLAYER_ENTERING_WORLD", True, False)
    chat()
    pages = sorted(stub.pages.keys())
    assert "Immersive Plainsrunning (Thread)" in pages and "Immersive Plainsrunning (Thread) > Effects" in pages, pages
    # every slider whose tooltip once said "in percent" shows a percent sign; the bindings in the family's section
    defs = [d for d in ns.settings.values() if d.key]
    assert not any(d.desc.endswith(", in percent.") for d in defs), [d.key for d in defs if d.desc.endswith(", in percent.")]
    assert sum(1 for d in defs if d.percent) == 14, [d.key for d in defs if d.percent]
    bindings = open(os.path.join(ADDONS, PLAINS, "Bindings.xml"), encoding="utf-8").read()
    assert bindings.count('category="BINDING_CATEGORY_PatchwerkForever"') == 2 and "ADDONS" not in bindings
    slash("help")
    assert "/plains records reset: forget your run records" in chat()

    step("the passive alone (same name, no stacks): nothing runs")
    buff(0)
    run(0.5)
    assert state() == (0, 0, False), state()
    assert alpha() == 1

    step("1 to 9 stacks, running: nothing fades (Start Fading At is 10)")
    stub.speed = 9.0
    for n in range(1, 10):
        buff(n)
        run(0.3)
    assert alpha() == 1 and state()[0] == 0, (alpha(), state())
    assert not state()[2], "running every frame below the stacks that do anything"

    step("10 to 29: a step at a time, gently")
    seen = []
    for n in range(10, 30):
        buff(n)
        run(1.0)
        seen.append(alpha())
    assert all(a > b for a, b in zip(seen, seen[1:])), seen
    assert 0.0 < seen[-1] < 0.1, seen[-1]
    assert streaks()[0] == 0, "streaks before 30"

    step("30: the interface is gone, the streaks come in")
    buff(30)
    stub.speed = 11.0
    run(1.5)
    assert alpha() == 0, alpha()
    n, strength = streaks()
    assert n == 40 and strength == 1, (n, strength)
    assert G.STUB.zoom == 18, ("the camera did not go back 3 yards", G.STUB.zoom)
    assert dict(ns.EffectsShown()) == {"wind": 0, "dust": 0, "rings": 0, "glow": 0}, "an effect on by default"
    run(5)                                                   # (streaks fly out and start again)

    step("standing still: the interface comes back after five seconds, the streaks go, the camera comes in")
    stub.speed = 0
    run(4.5)
    assert alpha() == 0
    run(1.0)
    assert alpha() == 1, alpha()
    assert streaks()[1] == 0
    assert G.STUB.zoom == 15, G.STUB.zoom

    step("moving again: the interface stays for five seconds, then fades away again; a stop in between starts it over")
    stub.speed = 11.0
    run(3.0)
    assert alpha() == 1, "faded before five seconds of moving"
    stub.speed = 0
    run(1.0)                                                 # (a short stop: still back, and the five seconds start over)
    stub.speed = 11.0
    run(4.5)
    assert alpha() == 1, "the stop did not start the five seconds over"
    run(1.5)
    assert alpha() == 0, alpha()

    step("a short stop (under five seconds): the interface stays away")
    stub.speed = 0
    run(3.0)
    stub.speed = 11.0
    run(0.5)
    assert alpha() == 0

    step("the map open: back; closed: gone again")
    G.WorldMapFrame.shown = True
    run(0.5)
    assert alpha() == 1
    G.WorldMapFrame.shown = False
    run(1.0)
    assert alpha() == 0

    step("typing in chat: back")
    stub.focus = G.CreateFrame("Frame")
    run(0.5)
    assert alpha() == 1
    stub.focus = None
    run(1.0)
    assert alpha() == 0

    step("a fight: back at the very event, before the next frame; kept through it")
    stub.combat = True
    stub.Fire("PLAYER_REGEN_DISABLED")
    assert alpha() == 1, "not back at once in a fight"
    run(1.0)
    assert alpha() == 1 and streaks()[1] == 0
    stub.combat = False
    stub.Fire("PLAYER_REGEN_ENABLED")
    run(1.0)
    assert alpha() == 0

    step("the Show Interface key: back while held")
    G.PatchwerkForever_Thread_Plainsrunning_Peek("down")
    run(0.4)
    assert alpha() == 1
    G.PatchwerkForever_Thread_Plainsrunning_Peek("up")
    run(1.0)
    assert alpha() == 0

    step("/plains, and /plains show: back for the rest of this run")
    slash("")
    assert "30 stacks" in chat()
    slash("show")
    run(0.5)
    assert alpha() == 1
    chat()

    step("the buff ends: everything as it was, and nothing runs")
    buff(0)
    run(1.0)
    assert alpha() == 1 and state() == (0, 0, False), (alpha(), state())
    assert streaks()[0] == 0

    step("a new run: /plains show is forgotten; the buff ends mid-fade: back at once-ish")
    for n in (10, 20, 30):
        buff(n)
        run(1.0)
    assert alpha() == 0, alpha()
    buff(0)
    run(0.3)
    assert alpha() == 1, alpha()

    step("an alpha someone else had (0.8) is the one put back")
    G.UIParent.alpha = 0.8
    buff(30)
    run(1.5)
    assert alpha() == 0
    buff(0)
    run(0.5)
    assert abs(alpha() - 0.8) < 1e-9, alpha()
    G.UIParent.alpha = 1

    step("Hidden Interface Opacity 40: the interface stays a little")
    ns.Set("fadeLeft", 40)
    buff(30)
    run(1.5)
    assert abs(alpha() - 0.4) < 1e-9, alpha()
    ns.Set("fadeLeft", 0)
    run(0.5)
    assert alpha() == 0

    step("speed mode disabled in the middle of a run: back; enabled: gone again")
    slash("off")
    run(0.5)
    assert alpha() == 1
    slash("on")
    run(1.5)
    assert alpha() == 0
    chat()

    step("a buff of the same name but another number (a patch changed it): still found")
    buff(30, spell=1399999)
    run(0.5)
    assert alpha() == 0
    assert state()[1] == 30
    buff(0)
    run(0.5)
    assert alpha() == 1

    step("the preview: up to 30, held, then over, everything back")
    slash("test")
    run(3)
    assert 0 < alpha() < 1, alpha()
    run(5)
    assert alpha() == 0 and streaks()[0] == 40
    run(8)
    assert alpha() == 1 and streaks()[0] == 0, (alpha(), streaks())
    assert "Preview over" in chat()
    run(0.5)
    assert not state()[2]

    step("each effect by itself, then all of them together; all off: nothing drawn at all")
    buff(30)
    stub.speed = 11.0
    run(1.5)
    assert alpha() == 0
    expected = {"wind": 10, "dust": 50, "rings": 4, "glow": 1}
    for key in expected:
        ns.Set(key, True)
        run(0.5)
        shown = dict(ns.EffectsShown())
        assert shown[key] == expected[key], (key, shown)
        assert all(shown[k] == 0 for k in expected if k != key), shown
        ns.Set(key, False)
        run(0.1)
        assert dict(ns.EffectsShown())[key] == 0, key
    for key in expected:
        ns.Set(key, True)
    ns.Set("windCount", 4)
    ns.Set("dustCount", 200)
    run(3)
    shown = dict(ns.EffectsShown())
    assert shown == dict(expected, wind=4, dust=200), shown
    assert streaks()[0] == 40
    for key in list(expected) + ["streaks", "vignette"]:
        ns.Set(key, False)
    run(1)
    assert streaks() == (0, 0) and all(v == 0 for v in dict(ns.EffectsShown()).values())
    for key in ("streaks", "vignette"):
        ns.Set(key, True)
    ns.Set("windCount", 10)
    ns.Set("dustCount", 50)
    run(1)
    assert streaks()[0] == 40

    step("the effects at a run's end: all gone; on again in the next run")
    buff(0)
    run(1)
    assert alpha() == 1 and all(v == 0 for v in dict(ns.EffectsShown()).values())
    for key in expected:
        ns.Set(key, False)

    step("keep the minimap and the unit frames: they ignore the faded interface, and are put back after")
    ns.Set("keepMinimap", True)
    ns.Set("keepUnits", True)
    buff(30)
    run(1.5)
    assert alpha() == 0
    assert G.MinimapCluster.ignore and G.Minimap.ignore and G.PlayerFrame.ignore and G.TargetFrame.ignore
    assert G.STUB.pathLayer.ignore, "the path over the minimap not kept with it"
    assert not G.STUB.otherLayer.ignore, "a frame away from the minimap kept"
    assert not G.ChatFrame1.ignore, "the chat kept without being asked"
    ns.Set("keepChat", True)
    run(0.1)
    assert G.ChatFrame1.ignore and G.ChatFrame1Tab.ignore
    ns.Set("keepChat", False)
    run(0.1)
    assert G.ChatFrame1.ignore is False
    buff(0)
    run(0.5)
    assert alpha() == 1 and not G.MinimapCluster.ignore and not G.PlayerFrame.ignore
    assert not G.STUB.pathLayer.ignore, "the path over the minimap not put back"
    assert not state()[2], "still running after everything was put back"

    step("a fight with parts kept: the protected frames wait for the fight's end, the rest at once")
    buff(30)
    run(1.5)
    assert G.PlayerFrame.ignore
    stub.combat = True
    stub.Fire("PLAYER_REGEN_DISABLED")
    run(0.5)
    assert alpha() == 1
    assert G.PlayerFrame.ignore and not G.MinimapCluster.ignore, "a protected frame changed in a fight"
    stub.combat = False
    stub.Fire("PLAYER_REGEN_ENABLED")
    buff(0)
    run(0.5)
    assert not G.PlayerFrame.ignore and not state()[2]
    ns.Set("keepMinimap", False)
    ns.Set("keepUnits", False)

    step("the camera at the game's furthest zoom: it goes 1 yard, and only 1 yard comes back")
    G.STUB.zoom = 29
    buff(30)
    run(2.5)
    assert G.STUB.zoom == 30, G.STUB.zoom
    buff(0)
    run(0.5)
    assert G.STUB.zoom == 29, G.STUB.zoom
    step("the camera, and a run ending within a second of it going: it waits, then comes back right")
    buff(30)
    run(1.5)                       # (the interface gone 0.8 s in: the camera went 0.7 s ago)
    buff(0)
    run(1.0)
    assert G.STUB.zoom == 29, G.STUB.zoom
    step("Pull The Camera Back off: the camera is left alone")
    ns.Set("camera", False)
    buff(30)
    run(2.5)
    assert G.STUB.zoom == 29
    buff(0)
    run(0.5)
    ns.Set("camera", True)
    G.STUB.zoom = 15

    step("run records: forgotten, then a first run: told as the first")
    slash("records reset")
    assert "forgotten" in chat()
    slash("records")
    assert "No run records yet" in chat()
    stub.speed = 10.0
    for n in range(1, 31):
        buff(n)
        run(0.5)                   # (30 stacks in 14.8 s: a run of the stand-in is a little over)
    run(20)
    buff(0)
    run(0.5)
    text = chat()
    assert "First run at full speed recorded: 0:21 at 30 stacks, 30 stacks in 0:15" in text, text
    _, db = ns.RecordsState()
    assert db.runs == 1 and abs(db.farthest - 10.0 * (14.85 + 20.53)) < 3, (db.runs, db.farthest)

    step("a second run, longer and faster: new records told; a mounted stretch not counted in yards")
    for n in range(1, 31):
        buff(n)
        run(0.4)
    run(25)
    stub.mounted = True
    run(10)
    stub.mounted = False
    buff(0)
    run(0.5)
    text = chat()
    assert "New record! Longest at full speed: 0:35 (was 0:21)." in text, text
    assert "Fastest to 30 stacks: 0:12 (was 0:15)" in text, text
    assert "Farthest run" in text, text
    _, db = ns.RecordsState()
    assert db.runs == 2 and abs(db.farthest - 10.0 * (12.06 + 25.42)) < 3, db.farthest

    step("a run seen from the middle (after a /reload, say): not a fastest; a slower run: nothing told")
    buff(20)
    run(0.5)
    for n in range(21, 31):
        buff(n)
        run(0.1)
    run(2)
    buff(0)
    run(0.5)
    assert "New record" not in chat()
    _, db = ns.RecordsState()
    assert db.runs == 3 and abs(db.fastest - 12.06) < 0.1, db.fastest

    step("the preview never counts; /plains records lists them")
    slash("test")
    run(16)
    chat()
    _, db = ns.RecordsState()
    assert db.runs == 3
    slash("records")
    text = chat()
    assert "Longest at full speed: 0:35" in text and "Fastest to 30 stacks: 0:12" in text and "Runs at full speed: 3" in text, text
    ns.Set("recordsTell", False)
    for n in (1, 30):
        buff(n)
        run(0.1)
    run(60)
    buff(0)
    run(0.5)
    assert "New record" not in chat(), "told with Tell Me About New Records off"
    ns.Set("recordsTell", True)
    run(0.1)
    assert not state()[2], (list(ns.State()), list(ns.CameraState()), list(streaks()))

    step("a fight with the speed and the stacks kept secret: nothing counted with them, nothing breaks")
    stub.speed = 11.0
    buff(30)
    run(1.5)
    assert alpha() == 0
    stub.combat = True
    stub.Fire("PLAYER_REGEN_DISABLED")
    stub.speed = G.SECRET
    buff(30, secret=True)
    run(1.0)
    assert alpha() == 1 and state()[1] == 30, (alpha(), state())
    _, db = ns.RecordsState()
    stub.combat = False
    stub.Fire("PLAYER_REGEN_ENABLED")
    run(0.5)
    stub.speed = 11.0
    buff(30)
    run(1.5)
    assert alpha() == 0, alpha()
    buff(0)
    run(0.5)
    chat()

    step("not a Tauren: the buff is never read, nothing fades, nothing runs, not even in a fight")
    stub.race = "Human"
    buff(30)
    run(2)
    assert alpha() == 1 and state()[1] == 0 and not state()[2], state()
    stub.combat = True
    stub.speed = G.SECRET
    stub.Fire("PLAYER_REGEN_DISABLED")
    run(0.5)
    assert not state()[2], "running on a race that is not Tauren"
    stub.combat = False
    stub.speed = 11.0
    stub.Fire("PLAYER_REGEN_ENABLED")
    slash("")
    assert "for Tauren" in chat()
    slash("test")
    run(8)
    assert alpha() == 0, "the preview did not play"
    run(9)
    assert alpha() == 1 and not state()[2]
    chat()
    buff(0)
    stub.race = "Tauren"

    # ------------------------------------------------------------------ other ways of going fast
    def other():
        source, running, looking = ns.OtherState()
        return source, running, looking

    def auras(*more):
        # the passive, always there, and whatever else: (spell number, name)
        listed = [{"spellId": 1259918, "name": "Plainsrunning", "applications": 0}]
        listed += [{"spellId": spell, "name": name, "applications": 0} for spell, name in more]
        stub.auras = lua.table_from([lua.table_from(a) for a in listed])
        stub.Fire("UNIT_AURA", "player")

    def fades(why):
        # from standing: the wait, then the climb to 30, then the effects
        run(4.5)
        assert alpha() == 1 and not other()[1], (why, "faded before Seconds Before Fading", alpha(), other())
        run(1.5)
        assert 0.8 < alpha() < 1 and other()[1], (why, "not fading once the wait was over", alpha(), other())
        run(11.5)
        assert alpha() == 0 and streaks() == (40, 1), (why, alpha(), streaks())

    step("other ways of going fast: each off at first; a Human on a mount: nothing looks, nothing fades")
    assert [d.default for d in defs if d.key in ("otherMounts", "otherForms", "otherFlights")] == [False, False, False]
    assert "Other Ways Of Going Fast" in list(stub.headers.values())
    stub.race = "Human"
    stub.mounted, stub.speed = True, 14.0
    stub.player.taxi, stub.form = True, 3
    auras((5118, "Aspect of the Cheetah"))
    run(30)
    assert alpha() == 1 and not state()[2] and other() == (None, False, False), (alpha(), state(), other())
    stub.player.taxi, stub.form = False, None
    auras()

    step("Mounts: five seconds of riding, then it fades as the stacks would, and the effects come in")
    _, db = ns.RecordsState()
    runs = db.runs
    ns.Set("otherMounts", True)
    assert other()[2], "nothing looking with a source enabled"
    fades("a mount")
    assert G.STUB.zoom == 18, ("the camera did not go back", G.STUB.zoom)
    slash("")
    text = chat()
    assert "Running on a mount" in text and "Other sources enabled: Mounts." in text, text

    step("on a mount, standing still: back after five seconds; moving again: away after five, at once")
    stub.speed = 0
    run(4.5)
    assert alpha() == 0
    run(1.0)
    assert alpha() == 1 and other()[1], (alpha(), other())
    stub.speed = 14.0
    run(4.5)
    assert alpha() == 1
    run(1.5)
    assert alpha() == 0, alpha()

    step("on a mount: a fight, a window, the Show key and /plains show bring it back as ever")
    stub.combat = True
    stub.Fire("PLAYER_REGEN_DISABLED")
    assert alpha() == 1, "not back at once in a fight"
    stub.speed = G.SECRET                                    # (the speed kept secret: the last one known counts)
    run(1.0)
    assert alpha() == 1 and other()[1], (alpha(), other())
    stub.combat, stub.speed = False, 14.0
    stub.Fire("PLAYER_REGEN_ENABLED")
    run(1.0)
    assert alpha() == 0
    G.WorldMapFrame.shown = True
    run(0.5)
    assert alpha() == 1
    G.WorldMapFrame.shown = False
    run(1.0)
    assert alpha() == 0
    G.PatchwerkForever_Thread_Plainsrunning_Peek("down")
    run(0.4)
    assert alpha() == 1
    G.PatchwerkForever_Thread_Plainsrunning_Peek("up")
    run(1.0)
    assert alpha() == 0
    slash("show")
    run(0.5)
    assert alpha() == 1 and "Interface back until this run ends" in chat()

    step("dismounted: everything as it was, nothing runs; /plains show is forgotten with the run")
    stub.mounted = False
    run(1.5)
    assert alpha() == 1 and state() == (0, 0, False) and other() == (None, False, True), (alpha(), state(), other())
    assert G.STUB.zoom == 15, G.STUB.zoom
    slash("show")
    assert "Speed mode is not running right now" in chat()
    slash("")
    text = chat()
    assert "Not running" in text and "Other sources enabled: Mounts." in text, text
    stub.mounted = True
    run(17.5)
    assert alpha() == 0, alpha()

    step("a stop of ten seconds ends the run on a mount: the next one waits and climbs again")
    stub.speed = 0
    run(10.5)
    assert alpha() == 1 and not other()[1], (alpha(), other())
    stub.speed = 14.0
    fades("a mount, after a long stop")

    step("Seconds Before Fading: none, and ten")
    stub.mounted = False
    run(1.0)
    ns.Set("otherWait", 0)
    stub.mounted = True
    run(0.6)
    assert alpha() < 1 and other()[1], (alpha(), other())
    stub.mounted = False
    run(1.0)
    ns.Set("otherWait", 10)
    stub.mounted = True
    run(9.5)
    assert alpha() == 1 and not other()[1]
    run(1.5)
    assert alpha() < 1 and other()[1]
    ns.Set("otherWait", 5)

    step("speed mode disabled: nothing looks; a mount the game has no word for: nothing happens")
    slash("off")
    run(0.5)
    assert alpha() == 1 and other() == (None, False, False), (alpha(), other())
    slash("on")
    assert other()[2]
    is_mounted = G.IsMounted
    G.IsMounted = None
    run(8)
    assert alpha() == 1 and other() == (None, False, True), (alpha(), other())
    G.IsMounted = lua.eval("function() return SECRET end")   # (or keeps secret)
    run(8)
    assert alpha() == 1 and not other()[1]
    G.IsMounted = is_mounted
    chat()

    step("a Tauren on a mount with Plainsrunning too: Plainsrunning's stacks win, and its records are its own")
    stub.race = "Tauren"
    run(17.5)
    assert alpha() == 0 and other()[1]
    buff(15)
    run(1.5)
    assert abs(alpha() - (1 - 6 / 21)) < 1e-6, alpha()
    slash("")
    text = chat()
    assert "Plainsrunning: 15 stacks" in text and "Running on" not in text, text
    buff(0)
    run(1.5)
    assert alpha() == 0, "the mount did not take over when the buff ended"
    stub.mounted = False
    run(1.5)
    assert alpha() == 1 and not state()[2]
    _, db = ns.RecordsState()
    assert db.runs == runs, "a run on a mount counted in the run records"
    ns.Set("otherMounts", False)
    assert not other()[2]
    stub.race = "Human"
    stub.Fire("UNIT_AURA", "player")

    step("Travel Forms: by the form's number")
    stub.speed = 9.8
    ns.Set("otherForms", True)
    run(8)
    assert alpha() == 1 and not other()[1], "a travel form seen where there is none"
    stub.form = 3
    fades("Travel Form")
    slash("")
    assert "Running on a travel form" in chat()
    stub.form = 1                                            # (cat form is no travel form)
    run(1.0)
    assert alpha() == 1 and not other()[1], (alpha(), other())
    stub.form = None

    step("Travel Forms: by the stance bar's active button (Ghost Wolf), a form's number unknown here")
    stub.stance = lua.table_from([lua.table_from({"spell": 768, "active": False}), lua.table_from({"spell": 2645, "active": True})])
    run(6)
    assert alpha() < 1 and other() == ("a travel form", True, True), (alpha(), other())
    stub.stance[2].active = False
    run(1.0)
    assert alpha() == 1 and not other()[1]
    stub.stance[1].active = True                             # (the other button, no travel form)
    run(8)
    assert alpha() == 1 and not other()[1]
    stub.stance = lua.table()

    step("Travel Forms: an aspect, an aura and no form; by its number, then by its name under another number")
    auras((5118, "Aspect of the Cheetah"))
    run(6)
    assert alpha() < 1 and other()[1], (alpha(), other())
    auras()
    run(1.0)
    assert alpha() == 1 and not other()[1]
    auras((1399998, "Aspect of the Pack"))
    run(6)
    assert alpha() < 1 and other()[1], (alpha(), other())

    step("in a fight the game may hide auras: an aspect not found there is still taken to be on; after the fight it is read again")
    ns.Set("combatShow", False)
    run(12)
    assert alpha() == 0
    stub.combat = True
    stub.Fire("PLAYER_REGEN_DISABLED")
    auras()
    run(3)
    assert alpha() == 0 and other()[1], ("the aspect was lost with the auras hidden", alpha(), other())
    stub.aurasSecret = True                                  # (or it hands secrets over)
    stub.Fire("UNIT_AURA", "player")
    run(3)
    assert alpha() == 0 and other()[1], (alpha(), other())
    stub.aurasSecret = False
    stub.combat = False
    stub.Fire("PLAYER_REGEN_ENABLED")
    run(1.0)
    assert alpha() == 1 and not other()[1], (alpha(), other())
    ns.Set("combatShow", True)

    step("Travel Forms where the game has no way to ask for forms: a form is looked for as an aura; with no auras either: nothing")
    forms = (G.GetShapeshiftFormID, G.GetNumShapeshiftForms, G.GetShapeshiftFormInfo)
    G.GetShapeshiftFormID, G.GetNumShapeshiftForms, G.GetShapeshiftFormInfo = None, None, None
    auras((783, "Travel Form"))
    run(6)
    assert alpha() < 1 and other()[1], (alpha(), other())
    unit_auras = G.C_UnitAuras
    G.C_UnitAuras = None
    stub.Fire("UNIT_AURA", "player")
    run(1.0)
    assert alpha() == 1 and not other()[1]
    run(8)
    assert alpha() == 1 and other() == (None, False, True), (alpha(), other())
    G.C_UnitAuras = unit_auras
    G.GetShapeshiftFormID, G.GetNumShapeshiftForms, G.GetShapeshiftFormInfo = forms
    auras()
    G.GetShapeshiftFormID = lua.eval("function() return SECRET end")     # (a form kept secret: as it was, none)
    run(8)
    assert alpha() == 1 and not other()[1]
    G.GetShapeshiftFormID = forms[0]
    ns.Set("otherForms", False)
    chat()

    step("a flight with Flight Paths off: it brings a Tauren's interface back, as ever")
    stub.race = "Tauren"
    stub.speed = 11.0
    buff(30)
    run(1.5)
    assert alpha() == 0
    stub.player.taxi = True
    run(0.5)
    assert alpha() == 1
    slash("")
    assert "you are dead or on a flight" in chat()
    step("Flight Paths on: the flight fades it instead, for the Tauren with stacks")
    ns.Set("otherFlights", True)
    run(1.5)
    assert alpha() == 0, alpha()
    buff(0)
    stub.player.taxi = False
    run(1.0)
    assert alpha() == 1 and not state()[2]

    step("Flight Paths on any race: the wait, the fade, the effects, though the game gives no speed on a flight; no standing still up there")
    stub.race = "Human"
    stub.Fire("UNIT_AURA", "player")
    stub.speed = 0
    stub.player.taxi = True
    fades("a flight")
    run(12)
    assert alpha() == 0 and streaks() == (40, 1), ("a flight taken for standing still", alpha(), streaks())
    slash("")
    assert "Running on a flight" in chat()
    stub.dead = True                                         # (dying still brings it back)
    run(0.5)
    assert alpha() == 1
    stub.dead = False
    run(1.0)
    assert alpha() == 0
    step("landed: everything back; a flight the game keeps secret is no flight")
    stub.player.taxi = False
    run(1.5)
    assert alpha() == 1 and state() == (0, 0, False) and other() == (None, False, True), (alpha(), state(), other())
    on_taxi = G.UnitOnTaxi
    G.UnitOnTaxi = lua.eval("function() return SECRET end")
    run(8)
    assert alpha() == 1 and not other()[1]
    G.UnitOnTaxi = on_taxi
    ns.Set("otherFlights", False)
    assert not other()[2]
    stub.race = "Tauren"
    stub.speed = 11.0
    chat()

    # ------------------------------------------------------------------ the wind shows the way
    trails = G.PatchwerkForever.Trails
    W, H = 1002, 668                                         # the stand-in's screen

    def origin():
        x, y = ns.StreaksOrigin()
        return x, y

    def route(*pieces):
        # each piece: (continent, how, [(x, y), ...]); none: no route
        if pieces:
            stub.trail = lua.eval("{ follow = true, alpha = 1, pieces = { %s } }" % ", ".join(
                "{ map = %d, how = '%s', points = { %s } }" % (m, how, ", ".join("{ %s, %s }" % p for p in points))
                for m, how, points in pieces))
        else:
            stub.trail = None
        trails.Changed(trails)

    def leans(share, why):
        x, y = origin()
        assert abs(x - share * 0.15 * W) < 0.5 and abs(y - 0.05 * H) < 1e-6, (why, x, y, list(ns.WayState()))

    step("the wind shows the way: off at first; on, with no Routes (Thread): the effects come from the middle")
    assert [d.default for d in defs if d.key == "wayWind"] == [False]
    stub.player.x, stub.player.y, stub.player.map, stub.player.facing = 0, 0, 1, 0      # (facing north)
    ns.Set("rings", True)
    buff(30)
    run(2)
    assert alpha() == 0 and origin() == (0, 0.05 * H), origin()
    ns.Set("wayWind", True)
    run(2)
    assert origin() == (0, 0.05 * H) and stub.listed == 0, (origin(), stub.listed)

    step("Routes (Thread) there, the setting off: the trail is never asked for; on, with no route: the middle")
    trails.Offer(trails, stub.provider)
    ns.Set("wayWind", False)
    route((1, "walk", [(0, 0), (20, 0), (20, 300)]))
    run(3)
    assert origin() == (0, 0.05 * H) and stub.listed == 0, (origin(), stub.listed)
    route()
    ns.Set("wayWind", True)
    run(2)
    assert origin() == (0, 0.05 * H) and stub.listed >= 1, (origin(), stub.listed)

    step("a route straight ahead: the middle")
    route((1, "walk", [(0, 0), (300, 0)]))
    run(2)
    leans(0, "straight ahead")

    step("a turn to the left ahead (the route goes west): the point eases to the left, part of the way; the rings come from it")
    route((1, "walk", [(0, 0), (20, 0), (20, 300)]))
    run(0.2)
    x = origin()[0]
    assert -0.7 * 0.15 * W < x < 0, ("jumped, or not moving", x)
    run(3)
    leans(-0.7071, "a turn to the left")                     # (40 yards on along it is 45 degrees to the left)
    rings = [t.x for t in G.STUB.allTextures.values() if t.shown and str(t.icon).endswith("warp")]
    assert len(rings) == 4 and all(abs(x - origin()[0]) < 1e-6 for x in rings), rings

    step("a turn to the right; further along the trail than where it was read; and facing the way it goes")
    route((1, "walk", [(0, 0), (20, 0), (20, -300)]))
    run(3)
    leans(0.7071, "a turn to the right")
    stub.player.x = 10                                       # (40 yards on from here: 10 north, 30 east)
    run(3)
    leans(0.9487, "from further along")
    stub.player.facing = -math.pi / 2                        # (facing east: it is nearly straight ahead now)
    run(3)
    leans(-0.3162, "facing east")
    stub.player.x, stub.player.facing = 0, 0

    step("a route behind you: all the way to the nearer side, and no further")
    route((1, "walk", [(0, 0), (-300, 10)]))
    run(3)
    leans(-1, "behind, a little to the left")
    route((1, "walk", [(0, 0), (-300, -10)]))
    seen = []
    for _ in range(30):
        run(0.1)
        seen.append(origin()[0])
    assert all(a < b + 1e-9 for a, b in zip(seen, seen[1:])) and max(abs(x) for x in seen) <= 0.15 * W + 1e-6, seen
    leans(1, "behind, a little to the right")

    step("How Far It Leans 30%, and Vertical Offset 10%: both hold")
    ns.Set("wayReach", 30)
    ns.Set("streakUp", 10)
    run(0.1)
    x, y = origin()
    assert abs(x - 0.30 * W) < 0.5 and abs(y - 0.10 * H) < 1e-6, (x, y)
    ns.Set("wayReach", 15)
    ns.Set("streakUp", 5)

    step("the trail is read when it changes and every couple of seconds, not every moment")
    before = stub.listed
    run(10)
    assert 4 <= stub.listed - before <= 6, stub.listed - before

    step("where you are or which way you face not known (an instance, a secret), or no such function: the middle")
    facing, position = G.GetPlayerFacing, G.UnitPosition
    for why, name, code in (
            ("no facing", "GetPlayerFacing", "function() return nil end"),
            ("a secret facing", "GetPlayerFacing", "function() return SECRET end"),
            ("facing fails", "GetPlayerFacing", "function() error('no') end"),
            ("no place", "UnitPosition", "function() return nil end"),
            ("a secret place", "UnitPosition", "function() return SECRET, SECRET, 0, 1 end"),
            ("no GetPlayerFacing", "GetPlayerFacing", None),
            ("no UnitPosition", "UnitPosition", None)):
        G[name] = lua.eval(code) if code else None
        run(3)
        leans(0, why)
        G.GetPlayerFacing, G.UnitPosition = facing, position
        run(3)
        leans(1, why + ", and known again")

    step("on another continent than the trail's, at its end, and a route that begins with a flight: the middle")
    stub.player.map = 0
    run(3)
    leans(0, "another continent")
    stub.player.map = 1
    route((1, "walk", [(-300, 0), (-3, 0)]))                 # (it ends three yards behind you)
    run(3)
    leans(0, "at the trail's end")
    route((1, "fly", [(0, 0), (-300, -10)]))
    run(3)
    leans(0, "a flight first")
    assert ns.WayState()[2] == 0

    step("a walk to the flight master and then a flight: the wind leads to the flight master and no further")
    route((1, "walk", [(0, 0), (30, 0)]), (1, "fly", [(30, 0), (30, 5000)]))
    run(3)
    leans(0, "the flight master straight ahead")
    route((1, "walk", [(0, 0), (0, 30)]), (1, "link", [(0, 30), (-30, 30)]), (0, "walk", [(-30, 30), (-30, -900)]))
    run(3)
    assert ns.WayState()[2] == 3                             # (a dock is walked too; the other continent is not)
    leans(-1, "the dock to the left, and round the corner")

    step("on a flight (Flight Paths on): no lean, there is no steering it")
    route((1, "walk", [(0, 0), (-300, -10)]))
    run(3)
    leans(1, "before the flight")
    ns.Set("otherFlights", True)
    stub.player.taxi = True
    run(3)
    assert alpha() == 0
    leans(0, "on a flight")
    stub.player.taxi = False
    ns.Set("otherFlights", False)
    run(3)
    leans(1, "after the flight")

    step("the route cannot be read (the base says so once): the middle; no service on this base: the middle")
    stub.listFails = True
    run(3)
    leans(0, "the route failing")
    assert "Reading the route failed and was skipped" in chat(problems_ok=True)
    stub.listFails = False
    run(3)
    leans(1, "the route read again")
    G.PatchwerkForever.Trails = None
    run(3)
    leans(0, "no Trails service")
    G.PatchwerkForever.Trails = trails
    run(3)
    leans(1, "the service back")

    step("the setting off: the middle at once")
    ns.Set("wayWind", False)
    run(0.05)
    assert origin() == (0, 0.05 * H), origin()
    ns.Set("wayWind", True)
    run(3)
    leans(1, "on again")

    step("a problem in the wind's way: said once, the effects go on from the middle, speed mode goes on")
    has = trails.Has
    trails.Has = lua.eval("function() error('the base said no') end")
    run(1)
    text = chat(problems_ok=True)
    assert text.count("Wind Shows The Way stopped after a problem") == 1, text
    assert alpha() == 0 and streaks() == (40, 1) and origin() == (0, 0.05 * H), (alpha(), streaks(), origin())
    trails.Has = has
    run(1)
    assert origin() == (0, 0.05 * H)
    ns.Set("wayWind", False)
    ns.Set("rings", False)
    route()
    stub.player.facing = 1.0
    buff(0)
    run(1.5)
    assert alpha() == 1 and not state()[2]
    chat()

    step("a problem looking for a flight or a mount: said once, the other sources stop, the interface stays, Plainsrunning goes on")
    ns.Set("otherMounts", True)
    ns.Set("otherFlights", True)
    stub.mounted = True
    on_flight = ns.OnFlight
    ns.OnFlight = lua.eval("function() error('the game said no') end")
    run(1)
    text = chat(problems_ok=True)
    assert text.count("Mounts, travel forms and flights no longer start speed mode, because of a problem") == 1, text
    assert "Speed mode stopped" not in text, text
    ns.OnFlight = on_flight
    run(20)
    assert alpha() == 1 and other() == (None, False, False) and not state()[2], (alpha(), other(), state())
    stub.mounted = False
    ns.Set("otherMounts", False)
    ns.Set("otherFlights", False)
    chat()

    step("a problem in the middle of a run: the interface back, speed mode stopped, said once")
    buff(30)
    run(1.5)
    assert alpha() == 0
    G.GetUnitSpeed = lua.eval("function() error('the game said no') end")
    run(0.1)
    assert alpha() == 1, alpha()
    text = chat(problems_ok=True)
    assert text.count("Speed mode stopped after a problem, and your interface is back") == 1, text
    run(0.5)
    buff(30)
    run(0.5)
    assert alpha() == 1 and not state()[2]

    print("Immersive Plainsrunning (Thread): all passed.")


if __name__ == "__main__":
    main()
