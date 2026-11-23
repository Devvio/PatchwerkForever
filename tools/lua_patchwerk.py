"""Run Patchwerk Forever's base and its parts outside the game, against the stand-in for the game (wowstub.lua).

    python lua_patchwerk.py

Plays several logins, each in a Lua of its own: the base alone for someone who had 1.x; the base with
a part made up here that uses everything a part may use; the base with the real parts when the addons
they are for are missing, and with a stand-in for Console Port; a part against no base, and against
a base too old for it. It fails loudly on any Lua error.

What this proves: the base's own code runs, and a part's settings, saved data and load hooks behave as
they did when everything was one addon. What it cannot prove: that the fixes themselves work. They
need the real Console Port and MelloUI, and were moved here unchanged but for their first lines.
"""
import os
import re
import sys

from pack import ADDONS

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "PatchwerkForever"
PARTS = ["PatchwerkForever_Stitch_ConsolePort", "PatchwerkForever_Stitch_MelloUI", "PatchwerkForever_Stitch_MelloUIRoute"]

EXTRA = r"""
function print(...)
	local out = {}
	for i = 1, select('#', ...) do out[#out + 1] = tostring((select(i, ...))) end
	STUB.messages[#STUB.messages + 1] = table.concat(out, ' ')
end
tinsert = table.insert
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function string.trim(s) local out = s:gsub('^%s+', ''):gsub('%s+$', '') return out end
STUB.meta, STUB.loaded, STUB.installed = {}, {}, {}
C_AddOns.GetAddOnMetadata = function(name, field) return STUB.meta[name] and STUB.meta[name][field] end
C_AddOns.IsAddOnLoaded = function(name) return STUB.loaded[name] == true end
C_AddOns.DoesAddOnExist = function(name) return STUB.installed[name] == true end
"""

CONSOLEPORT = r"""
STUB.cpdb = { Bindings = { Special = {}, Custom = {}, Macroable = {} } }
ConsolePort = {}
CPAPI = { Log = function() end, LinkEnv = function(name, env)
	env.db, env.L = STUB.cpdb, {}
	return function() end, {}, env, STUB.cpdb, name, env.L
end }
Enum.BindingContext = { GamepadModeInGameCore = 5, None = 0 }
"""

# A stand-in for MelloUI, as much of it as the trim to Route and the Quest Tracker uses.
MELLO = r"""
MelloUI = { initialized = true, Features = {}, enabled = {},
	modules = { Chat = { title = 'Chat' }, Map = { title = 'Map' }, QuestTracker = { title = 'QuestTracker' },
		Route = { title = 'Route' }, Core = { title = 'Core', noSwitch = true } } }
function MelloUI:IterateModules() return pairs(self.modules) end
function MelloUI:IsModuleEnabled(name) return self.enabled[name] == true or self.modules[name].noSwitch == true end
function MelloUI:SetModuleEnabled(name, on) self.enabled[name] = on end
function MelloUI:RegisterModule() end
function MelloUI:CharacterProfile() return STUB.profile end
StaticPopupDialogs = {}
function StaticPopup_Show(which) STUB.popup = which end
RELOADUI, LATER = 'Reload', 'Later'
function ReloadUI() end
function UnitGUID() return 'Player-1-000A' end
C_AddOns.GetNumAddOns = function() return 0 end
"""

# A part made up for the check. It does what the real ones do: a setting with a saved value, a
# setting depending on it, something to do once loaded, saved data, a fix with a command.
MADE_UP = "PatchwerkForever_MadeUp"
MADE_UP_FILES = [r"""
local addonName, ns = ...
LOG = {}
assert(PatchwerkForever:Link(addonName, ns, 1), 'the made-up part could not join')
assert(ns.linked and ns.Base == PatchwerkForever)
ns:AddSetting({ key = 'madeUpOn', default = true, section = 'Made Up', name = 'Made Up On', desc = 'A switch.' })
ns:AddSetting({ key = 'madeUpSteps', default = 3, min = 1, max = 5, step = 1, parent = 'madeUpOn',
	section = 'Made Up', name = 'Made Up Steps', desc = 'A number.' })
ns:OnSetting('madeUpOn', function(value, initial) LOG[#LOG + 1] = ('setting %s %s'):format(tostring(value), tostring(initial)) end)
ns:WhenLoaded(function() LOG[#LOG + 1] = 'hook, second file ran: ' .. tostring(ns.second) end)
-- before the part has finished loading nothing has been run, and the setting reads as saved
assert(#LOG == 0, 'a hook or a setting ran before the part had loaded')
assert(ns:GetSetting('madeUpOn') == false, 'the saved value is not read')
""", r"""
local addonName, ns = ...
ns.second = true
local saved = ns:GetSaved('MadeUp')
assert(saved and saved.kept == 'from before', 'the saved data is not the base\'s')
ns:RegisterFix('madeup', { name = 'A made-up fix', addon = 'Nothing',
	status = function() return 'fine' end,
	command = function(args) ns:Print('made-up command: ' .. args) end })
assert(ns.OnOff(true) == 'on' and ns.OnOff(2) == '2')
"""]


def toc(folder):
    fields, files = {}, []
    for line in open(os.path.join(ADDONS, folder, folder + ".toc"), encoding="utf-8"):
        line = line.strip()
        m = re.match(r"##\s*([^:]+):\s*(.*)", line)
        if m:
            fields[m.group(1)] = m.group(2)
        elif line.endswith(".lua"):
            files.append(line.replace("\\", "/"))
    return fields, files


class Session:
    """One login: a Lua of its own with the stand-in for the game in it."""

    def __init__(self, saved=None, running=(), installed=(), console_port=False, welcomed=True):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(open(os.path.join(HERE, "wowstub.lua"), encoding="utf-8").read())
        self.lua.execute(EXTRA)
        if console_port:
            self.lua.execute(CONSOLEPORT)
        self.g = self.lua.globals()
        self.stub = self.g.STUB
        for name in running:
            self.stub.loaded[name] = True
            self.stub.installed[name] = True
        for name in installed:
            self.stub.installed[name] = True
        if saved:
            self.lua.execute("PatchwerkForeverDB = " + saved)
        if welcomed:
            # (the one-time line on where the options are, said at an account's first login, is had)
            self.lua.execute("PatchwerkForeverDB = PatchwerkForeverDB or {}; PatchwerkForeverDB.told = PatchwerkForeverDB.told or {};"
                             " PatchwerkForeverDB.told.welcome = true")
        self._load = self.lua.eval(
            "function(code, name, addon, ns) return assert(loadstring(code, name))(addon, ns) end")
        self.ns = {}
        self.said = 0

    def addon(self, name, only=None, files=None, version="9.9.9"):
        """Run an addon's files as the game does, then its ADDON_LOADED."""
        ns = self.lua.table()
        self.ns[name] = ns
        meta = self.lua.table()
        if files is None:
            fields, listed = toc(name)
            for key, value in fields.items():
                meta[key] = value
            files = [(f, open(os.path.join(ADDONS, name, f), encoding="utf-8").read())
                     for f in listed if only is None or f in only]
        else:
            meta["Title"], meta["Version"] = name, version
            files = [("file%d.lua" % (i + 1), code) for i, code in enumerate(files)]
        self.stub.meta[name] = meta
        self.stub.installed[name] = True
        for label, code in files:
            self._load(code, "@" + name + "/" + label, name, ns)
        self.stub.loaded[name] = True
        self.stub.Fire("ADDON_LOADED", name)
        return ns

    def login(self):
        self.stub.Fire("PLAYER_LOGIN")

    def chat(self):
        new = list(self.stub.messages.values())[self.said:]
        self.said += len(new)
        # as read: without the colour and picture codes
        new = [re.sub(r"\|c\w{8}|\|r|\|T[^|]*\|t ?", "", text) for text in new]
        for text in new:
            print("      chat: " + text)
        bad = [t for t in new if "failed" in t or "could not" in t]
        assert not bad, bad
        return new

    def chat_raw(self):
        new = list(self.stub.messages.values())[self.said:]
        self.said += len(new)
        new = [re.sub(r"\|c\w{8}|\|r|\|T[^|]*\|t ?", "", text) for text in new]
        for text in new:
            print("      chat: " + text)
        return new

    def slash(self, text):
        self.g.SlashCmdList.PATCHWERK(text)
        return self.chat()

    def log(self):
        return list(self.g.LOG.values())


def step(label):
    print("  " + label)


def main():
    step("the base alone, for someone who had 1.x and runs Console Port")
    s = Session(saved="{ settings = { foreverNotify = false }, ConsolePort = { cleared = { X = true } } }",
                running=["ConsolePort"], welcomed=False)
    base = s.addon(BASE)
    s.login()
    text = s.chat()
    assert len(text) == 2 and "Patchwerk Forever: Console Port (Stitch)" in text[0], text
    assert text[1] == "Patchwerk: Options are under Options > AddOns > Patchwerk Forever.", text
    assert s.g.PatchwerkForeverDB.told.welcome is True
    assert s.stub.category and s.stub.front, "the base's page was not built"
    # its first page is drawn by the base: what Patchwerk says, what is sewn on, its own switch
    assert len(s.stub.settings) == 0, "the base's switch is still a row of the game's"
    front = s.stub.front
    front.shown = True
    front.scripts.OnShow(front)
    page = base.FrontShown()
    print("      front page: " + page.said)
    assert "Nothing sewn on yet" in page.said, page.said
    # (Console Port is running and its Stitch is not installed: listed greyed, with no button)
    parts = list(page.parts.values())
    assert len(parts) == 1 and parts[0].name == "Console Port (Stitch)" and not parts[0].open, [x.name for x in parts]
    assert "Not sewn on. It is for Console Port, which is running." == parts[0].says, parts[0].says
    switches = list(page.switches.values())
    assert len(switches) == 1 and switches[0].key == "baseTellMissing" and switches[0].checked is True
    assert switches[0].Label.text == "Notify About Missing Addons", switches[0].Label.text
    assert switches[0].name == "Notify About Missing Addons", "the tick box's tooltip has no name"
    switches[0].checked = False
    switches[0].scripts.OnClick(switches[0])
    assert s.g.PatchwerkForever.GetSetting(s.g.PatchwerkForever, "baseTellMissing") is False
    switches[0].checked = True
    switches[0].scripts.OnClick(switches[0])
    assert s.chat() == []
    assert s.g.PatchwerkForeverDB.ConsolePort.cleared.X, "the old saved data was touched"
    assert s.g.PatchwerkForeverDB.settings.foreverNotify is False
    text = s.slash("")
    assert text[0] == "Patchwerk Forever %s. Installed parts:" % toc(BASE)[0]["Version"] and any("None. Patchwerk Forever is the base" in t for t in text), text
    # the commands, one to a line, the options last; no fix's command with no fix
    assert text[-1] == "  /patchwerk config: open the options" and "Patchwerk: Commands:" in text, text
    assert not any("/patchwerk <id>" in t for t in text), text
    assert any("Patchwerk Forever: Console Port (Stitch) (for Console Port): not installed" in t for t in text), text
    icon = s.g.PatchwerkForever.Icon(s.g.PatchwerkForever, BASE)
    assert icon == "Interface\\AddOns\\PatchwerkForever\\Media\\icon", icon
    told = s.lua.eval("PatchwerkForeverDB.told['PatchwerkForever_Stitch_ConsolePort']")
    assert told is True

    step("the next login: not told again; with the part there but unticked, never told")
    s = Session(saved="{ settings = {}, told = { PatchwerkForever_Stitch_ConsolePort = true } }", running=["ConsolePort"])
    s.addon(BASE)
    s.login()
    assert s.chat() == []
    s = Session(running=["ConsolePort", "MelloUI"],
                installed=["PatchwerkForever_Stitch_ConsolePort", "PatchwerkForever_Stitch_MelloUI", "PatchwerkForever_Stitch_MelloUIRoute"])
    s.addon(BASE)
    s.login()
    assert s.chat() == []
    text = s.slash("")
    assert sum("installed but disabled" in t for t in text) == 3, text

    step("MelloUI running, nothing for it installed: told of both parts; the setting off: told nothing")
    s = Session(running=["MelloUI"])
    s.addon(BASE)
    s.login()
    text = s.chat()
    assert len(text) == 2 and "MelloUI Route" in text[1], text
    s = Session(saved="{ settings = { baseTellMissing = false } }", running=["MelloUI", "ConsolePort"])
    s.addon(BASE)
    s.login()
    assert s.chat() == []

    step("the base with a made-up part: settings, saved data, load hooks, a fix")
    s = Session(saved="{ settings = { madeUpOn = false, madeUpSteps = 9 }, MadeUp = { kept = 'from before' } }")
    base = s.addon(BASE)
    ns = s.addon(MADE_UP, files=MADE_UP_FILES, version="1.2.3")
    # the hook first (it saw the second file), then the setting with its saved value
    assert s.log() == ["hook, second file ran: true", "setting false true"], s.log()
    s.login()
    assert s.chat() == []
    assert s.log() == ["hook, second file ran: true", "setting false true"], "run twice"
    assert len(s.stub.settings) == 2, len(s.stub.settings)
    # the part's settings are on a page of its own under the base's; one section needs no heading there
    heads = list(s.stub.headers.values())
    assert heads == [], heads
    # the page opens with its name; the rows of our own are made and filled without error
    intros = list(s.stub.intros.values())
    assert len(intros) == 1 and intros[0].name == "PatchwerkForever_MadeUp", [i.name for i in intros]
    assert s.stub.Rows() == 1
    # and the front page lists the part, with a button that opens its page
    front = s.stub.front
    front.shown = True
    front.scripts.OnShow(front)
    page = base.FrontShown()
    parts = list(page.parts.values())
    assert [x.name for x in parts][0].startswith("PatchwerkForever_MadeUp") and parts[0].open, [x.name for x in parts]
    assert "One " in page.said and "Nothing" not in page.said, page.said
    parts[0].row.Open.scripts.OnClick(parts[0].row.Open)
    assert s.stub.opened == 8, "the part's page was not opened from the front page"
    assert list(s.stub.pages.keys()) == ["PatchwerkForever_MadeUp"], list(s.stub.pages.keys())
    on = sorted(x.variable for x in s.stub.settings.values() if x.page == "PatchwerkForever_MadeUp")
    assert on == ["PatchwerkForever_madeUpOn", "PatchwerkForever_madeUpSteps"], on
    P = s.g.PatchwerkForever
    assert P.GetSetting(P, "madeUpSteps") == 9, "a saved number is read as it was saved"
    text = s.slash("")
    assert any("PatchwerkForever_MadeUp 1.2.3" in t for t in text), text
    assert any("A made-up fix (madeup) for Nothing: fine" in t for t in text), text
    assert any("/patchwerk <id>: a fix's own commands" in t for t in text), text
    text = s.slash("madeup hello there")
    assert text == ["Patchwerk made-up command: hello there"], text
    text = s.slash("set madeupon on")
    assert s.log()[-1] == "setting true false" and "madeUpOn: on" in text[0], (s.log(), text)
    assert s.g.PatchwerkForeverDB.settings.madeUpOn is True
    text = s.slash("set madeupon maybe")
    assert text == ["Patchwerk: Usage: /patchwerk set madeUpOn on|off"], text
    text = s.slash("set madeupsteps 99")
    assert s.g.PatchwerkForeverDB.settings.madeUpSteps == 5, "a number is not kept inside its range"
    text = s.slash("set")
    assert sum(1 for t in text if t.startswith("  ")) == 3, text
    s.slash("config")
    assert s.stub.opened == 7, "the settings page was not opened"
    # the binding and the minimap's addon list open it too; in combat, said why not
    s.stub.opened = None
    s.g.PatchwerkForever_OpenOptions()
    assert s.stub.opened == 7, "the Open Options binding did not open the options"
    s.stub.opened = None
    s.g.PatchwerkForever_OnAddonCompartmentClick()
    assert s.stub.opened == 7, "the minimap's addon list did not open the options"
    s.stub.opened = None
    s.lua.execute("STUB.combat = true")
    text = s.slash("config")
    assert text == ["Patchwerk: Options cannot be opened in combat."] and s.stub.opened is None, text
    parts[0].row.Open.scripts.OnClick(parts[0].row.Open)
    assert s.chat() == ["Patchwerk: Options cannot be opened in combat. Select the page in the list on the left."]
    s.lua.execute("STUB.combat = false")
    assert s.g.BINDING_CATEGORY_PatchwerkForever == "Patchwerk Forever" and s.g.BINDING_NAME_PATCHWERKFOREVER_OPTIONS == "Open Options"
    # the page's own controls read and write the same values
    for i in s.stub.settings:
        setting = s.stub.settings[i]
        if setting.variable == "PatchwerkForever_madeUpOn":
            setting.set(False)
            assert setting.get() is False and s.log()[-1] == "setting false false"
    # after login a hook is run at once
    s.lua.execute("PatchwerkForever:WhenLoaded(function() LOG[#LOG + 1] = 'late hook' end)")
    assert s.log()[-1] == "late hook"

    step("the real parts, with the addons they are for missing: they load and do nothing")
    s = Session()
    s.addon(BASE)
    for part in PARTS:
        ns = s.addon(part)
        assert ns.linked, part
    s.login()
    assert s.chat() == []
    assert len(s.g.PatchwerkForever.Fixes) == 0 and len(s.stub.settings) == 0
    text = s.slash("")
    for part in PARTS:
        title = toc(part)[0]["Title"]
        assert any(title in t for t in text), (title, text)
        assert s.g.PatchwerkForever.Icon(s.g.PatchwerkForever, part) == "Interface\\AddOns\\%s\\Media\\icon" % part

    step("the Console Port part's first files, with a stand-in for Console Port")
    s = Session(saved="{ settings = { foreverNotify = false }, ConsolePort = { cleared = { X = true } } }",
                running=["ConsolePort"], console_port=True)
    s.addon(BASE)
    env = s.addon("PatchwerkForever_Stitch_ConsolePort", only=["Link.lua", "Database.lua"])
    s.login()
    assert s.chat() == []
    assert env.NativeContext == 5 and env.db is not None
    assert len(s.stub.settings) == 10, len(s.stub.settings)
    assert list(s.stub.headers.values()) == []
    assert list(s.stub.pages.keys()) == ["Console Port (Stitch)"], list(s.stub.pages.keys())
    assert sum(1 for x in s.stub.settings.values() if x.page == "Console Port (Stitch)") == 10
    # the Stitch's page opens with its name, its picture and what Patchwerk says of it (its TOC)
    intro = list(s.stub.intros.values())[0]
    assert intro.name == "Console Port (Stitch)" and intro.icon.endswith("Stitch_ConsolePort\\Media\\icon"), (intro.name, intro.icon)
    assert intro.voice == "Buttons were loose. Patchwerk sewed them back on the stick.", intro.voice
    assert s.stub.Rows() == 1
    assert env.GetSetting(env, "foreverNotify") is False and env.GetSetting(env, "foreverClearPing") is True
    assert env.GetConsolePortSaved(env).cleared.X, "the part does not see what 1.x saved"

    step("Console Port's menu ring (3.3.14): its setup stopped on Forever's missing RunAttribute, finished; kept open")
    s = Session(saved="{ settings = { foreverNotify = false } }", running=["ConsolePort"], console_port=True)
    s.lua.execute(r"""
        function hooksecurefunc(t, name, after)
            local before = t[name]
            t[name] = function(...) local r = { before(...) } after(...) return unpack(r) end
        end
        CPAPI.BurnAfterReading = {}
        CPAPI.EventMixin = { ADDON_LOADED = function(self, ...)
            if self.UnregisterEvent then self:UnregisterEvent('ADDON_LOADED') end
            if self.OnDataLoaded and self:OnDataLoaded(...) == CPAPI.BurnAfterReading then self.OnDataLoaded = nil end
        end }
        STUB.cpGameMenu, STUB.nativeUI, STUB.snippets = false, false, {}
        -- as ConsolePort_Menu 3.3.14 on Forever: a secure frame with Execute but no RunAttribute
        local ring = { attributes = {} }
        ConsolePortMenuRing = ring
        function ring:SetAttribute(k, v)
            assert(not STUB.combat, 'the ring changed in a fight')
            self.attributes[k] = v
        end
        function ring:GetAttribute(k) return self.attributes[k] end
        function ring:UnregisterEvent() end
        function ring:Execute(body)
            assert(not STUB.combat, 'Execute in a fight')
            STUB.snippets[#STUB.snippets + 1] = body
        end
        function ring:OnEnabledChanged()
            local enabled = STUB.cpGameMenu and not STUB.nativeUI
            self:SetAttribute('enabled', enabled)
            if not enabled then self:RunAttribute('ClearAndHide', true) end
        end
        function ring:OnDataLoaded()
            assert(not self.ObjectPool, 'Object pool already exists.')
            self.ObjectPool = {}
            self:OnEnabledChanged()
            for i = 1, 3 do self:SetAttribute('numbuttons', i) end
            return CPAPI.BurnAfterReading
        end
        -- Console Port's callbacks hold its own function, not the frame's field
        local original = ring.OnEnabledChanged
        function STUB.CPCallback() original(ring) end
        -- loaded with the core, before the Stitch: the setup stops, as in the game
        STUB.loadError = select(2, pcall(CPAPI.EventMixin.ADDON_LOADED, ring, 'ConsolePort_Menu'))
    """)
    ring = s.g.ConsolePortMenuRing
    assert "attempt to call" in str(s.stub.loadError) and not ring.attributes.numbuttons, s.stub.loadError
    s.addon(BASE)
    env = s.addon("PatchwerkForever_Stitch_ConsolePort", only=["Link.lua", "Database.lua", "MenuRing.lua"])
    s.login()
    assert ring.attributes.numbuttons == 3, "the ring's buttons were not added"
    assert ring.OnDataLoaded is None, "the setup was not finished"
    assert any("self:RunAttribute(\"ClearAndHide\", true)" in b for b in s.stub.snippets.values()), list(s.stub.snippets.values())
    assert ring.attributes.enabled is True, "the ring is still shut"
    s.lua.execute("STUB.nativeUI = true; STUB.CPCallback()")
    assert ring.attributes.enabled is True, "shut again by Console Port's callback"
    s.lua.execute("STUB.combat = true")
    s.stub.Fire("ADDON_LOADED", "ConsolePort_Menu")
    s.lua.execute("STUB.combat = false")
    s.stub.Fire("PLAYER_REGEN_ENABLED")
    assert ring.attributes.enabled is True
    env.SetSetting(env, "foreverKeepMenuRing", False)
    assert ring.attributes.enabled is False, "Console Port's own answer not given back"
    env.SetSetting(env, "foreverKeepMenuRing", True)
    assert ring.attributes.enabled is True
    assert ring.attributes.numbuttons == 3
    assert s.chat() == [], s.chat()

    step("a part with no base, and with a base too old for it: one line of chat, no error")
    link = open(os.path.join(ADDONS, PARTS[0], "Link.lua"), encoding="utf-8").read()
    for label, setup in (("no base", ""), ("old base", "PatchwerkForever = { Link = function() return false end }")):
        s = Session(running=["ConsolePort"], console_port=True)
        s.lua.execute(setup)
        ns = s.addon(PARTS[0])
        text = list(s.stub.messages.values())
        assert len(text) == 1 and "Patchwerk Forever: Console Port (Stitch)|r needs Patchwerk Forever 2.0.0 or later" in text[0], (label, text)
        assert not ns.linked and not ns.NativeContext, label
    s = Session()
    s.addon(BASE)
    assert s.g.PatchwerkForever.Link(s.g.PatchwerkForever, "X", s.lua.table(), 99) is False

    step("the MelloUI trim, with MelloUI's profile for each character (2.1.46): once for each profile")
    part = "PatchwerkForever_Stitch_MelloUI"

    def mello(saved, profile, on, old=False):
        """A login with a stand-in for MelloUI: which profile the character has, which modules are on."""
        # (the Route Stitch counts as installed, so the base has nothing to say about it being missing)
        s = Session(saved=saved, running=["MelloUI"], installed=["PatchwerkForever_Stitch_MelloUIRoute"])
        s.lua.execute(MELLO)
        s.stub.profile = profile
        if old:
            s.lua.execute("MelloUI.CharacterProfile = nil")
        for name in on:
            s.g.MelloUI.enabled[name] = True
        s.addon(BASE)
        s.addon(part)
        s.login()
        s.stub.Fire("PLAYER_ENTERING_WORLD")
        s.stub.RunAfters()
        now = sorted(n for n in ("Chat", "Map", "QuestTracker", "Route") if s.g.MelloUI.enabled[n])
        return s, now, s.chat()

    ALL = ["Chat", "Map", "QuestTracker", "Route"]
    before = "{ settings = { melloRouteOnly = true }, MelloUI = { seen = { Chat = true, Map = true, QuestTracker = true, Route = true } } }"
    # the character it was trimmed on, who has since switched Chat back on: left as it is, and the
    # account's list from before becomes that profile's
    s, now, text = mello(before, "Main", ["Chat", "QuestTracker", "Route"])
    assert now == ["Chat", "QuestTracker", "Route"] and text == [], (now, text)
    db = s.g.PatchwerkForeverDB.MelloUI
    assert db.seen is None and db.seenIn.Main.Chat, "the list from before was not handed to the profile"
    after = "{ settings = { melloRouteOnly = true }, MelloUI = { seenIn = { Main = { Chat = true, Map = true, QuestTracker = true, Route = true } } } }"
    # another character, whose own profile has everything on: trimmed, once
    s, now, text = mello(after, "Alt", ALL)
    assert now == ["QuestTracker", "Route"], now
    assert any("MelloUI: Disabled: Chat, Map" in t for t in text) and s.stub.popup == "PATCHWERK_MELLOUI_RELOAD", text
    assert s.g.PatchwerkForeverDB.MelloUI.seenIn.Alt.Map and s.g.PatchwerkForeverDB.MelloUI.seenIn.Main.Map
    both = "{ settings = { melloRouteOnly = true }, MelloUI = { seenIn = { Main = { Chat = true, Map = true, QuestTracker = true, Route = true }, Alt = { Chat = true, Map = true, QuestTracker = true, Route = true } } } }"
    # that character again, Chat switched back on there: it stays on
    s, now, text = mello(both, "Alt", ["Chat", "QuestTracker", "Route"])
    assert now == ["Chat", "QuestTracker", "Route"] and text == [], (now, text)
    # the setting off: nothing is touched
    s, now, text = mello("{ settings = { melloRouteOnly = false } }", "Alt", ALL)
    assert now == ALL and text == []
    # a MelloUI from before its profiles were each character's: one list for the account, as it was
    s, now, text = mello("{ settings = { melloRouteOnly = true } }", "Main", ALL, old=True)
    assert now == ["QuestTracker", "Route"] and s.g.PatchwerkForeverDB.MelloUI.seen.Map and s.g.PatchwerkForeverDB.MelloUI.seenIn is None

    step("the guides service: readers asked in turn, a failing one skipped, a side list passed over, RestedXP read as it runs")
    s = Session()
    s.addon(BASE)
    G = s.g.PatchwerkForever.Guides
    assert s.g.PatchwerkForever.API == 6
    assert G.Read(G, 2) is None, "a guide with no guide addon running"
    assert G.Go(G, None, 3) is False, "a guide moved with no guide running"
    # a made-up guide addon's reader, behind one that fails: the failure is said once and the next is asked
    s.lua.execute("""
        local G = PatchwerkForever.Guides
        G:Register('broken', { name = 'Broken Guides', Read = function() error('its tables moved') end })
        G:Register('madeup', { name = 'Made Up Guides', Read = function(count)
            return { index = 3, total = 9, kind = 'turnin', key = '3',
                lines = { { text = 'Done already', done = true }, { text = 'Hand it in', done = false }, { text = '' } },
                ahead = {}, asked = count }
        end })
    """)
    info = G.Read(G, 4)
    assert info.source == "madeup" and info.reader == "Made Up Guides" and info.asked == 4 and info.index == 3
    assert list(G.Words(info).values()) == ["Hand it in"], "the words still to be done are not picked out"
    G.Read(G, 1)
    text = s.chat_raw()
    assert len(text) == 1 and "Broken Guides failed and was skipped" in text[0], text
    assert G.Go(G, info, 4) is False, "a reader with no way to move its guide said it had moved"
    # more than one guide at a time: each can be asked by name; all of them, the main one first; one that
    # says it leads is asked before the rest
    s.lua.execute("""
        PatchwerkForever.Guides:Register('second', { name = 'Second List', Leads = function() return STUB.secondLeads end,
            Read = function() if STUB.secondOff then return nil end return { index = 1, total = 2, kind = 'accept', key = 's1', lines = {}, ahead = {} } end })
    """)
    assert G.Read(G, 0).source == "madeup" and G.Read(G, 0, "second").reader == "Second List" and G.Read(G, 0, "nobody") is None
    assert [i.source for i in G.ReadAll(G, 0).values()] == ["madeup", "second"]
    s.stub.secondLeads = True
    assert G.Read(G, 0).source == "second" and [i.source for i in G.ReadAll(G, 0).values()] == ["second", "madeup"]
    s.stub.secondLeads = False
    # a guide chosen as a side path stands while its reader has something to say
    Ch = s.g.PatchwerkForever.Choice
    assert Ch.Set(Ch, "guide", "second") and Ch.Is(Ch, "guide", "second")
    s.stub.secondOff = True
    assert Ch.Get(Ch) is None, "a guide with nothing left to say is still the choice"
    s.chat_raw()
    # a reader may say it is a side list (Side): listed with the rest and read by its name, but never
    # the main guide, not even when it is the only one with something to say
    s = Session()
    s.addon(BASE)
    G, Ch = s.g.PatchwerkForever.Guides, s.g.PatchwerkForever.Choice
    s.lua.execute("""
        local G = PatchwerkForever.Guides
        G:Register('main', { name = 'A Guide',
            Read = function() if STUB.mainOff then return nil end return { index = 4, total = 9, kind = 'turnin', key = 'm4', lines = {}, ahead = {} } end })
        G:Register('list', { name = 'A List',
            Side = function() if STUB.listBreaks then error('its setting moved') end return STUB.listSide end,
            Read = function(count) return { index = 1, total = 2, kind = 'accept', key = 'l1', lines = {}, ahead = {}, asked = count } end })
    """)
    s.stub.mainOff = True
    info = G.Read(G, 0)
    assert info.source == "list" and info.side is None, "a reader whose Side says no is not a side list"
    s.stub.listSide = True
    assert G.Read(G, 0) is None, "a side list became the main guide when it was the only one with a guide"
    assert [(i.source, i.side) for i in G.ReadAll(G, 0).values()] == [("list", True)]
    info = G.Read(G, 5, "list")
    assert info.side is True and info.asked == 5 and info.reader == "A List", "a side list is not read by its name"
    # selected, it stands as the choice, and is still not what Read gives without a name
    assert Ch.Set(Ch, "guide", "list") and Ch.Is(Ch, "guide", "list") and G.Read(G, 0) is None
    Ch.Clear(Ch)
    # beside a main guide: the guide is read, both are listed
    s.stub.mainOff = False
    assert G.Read(G, 0).source == "main" and G.Read(G, 0).side is None
    assert [(i.source, i.side) for i in G.ReadAll(G, 0).values()] == [("main", None), ("list", True)]
    # a Side that fails says nothing, as a Leads that fails: not a side list, and no error
    s.stub.mainOff, s.stub.listBreaks = True, True
    assert G.Read(G, 0).source == "list" and G.Read(G, 0).side is None
    assert s.chat() == []
    # RestedXP, with a stand-in for what it keeps as it runs
    s = Session()
    s.lua.execute("""
        local function at(x, y) return { tag = 'goto', wx = y, wy = x, instance = 1 } end
        local steps = {
            { { tag = 'accept', text = 'Accept Plainstrider Menace', completed = true }, { tag = 'complete', text = ' Kill 7 plainstriders ' }, at(-600, -2800) },
            { { tag = 'fly', text = 'Fly to Orgrimmar', location = 'ORGRIMMAR' }, at(-437, -2596) },
            { { tag = 'train', text = 'Train your skills' } },
            { { tag = 'hs', text = 'Hearth to the Crossroads' } },
            { { tag = 'turnin', text = 'Turn in your report' }, at(1600, -4400) },
        }
        for i, lines in ipairs(steps) do
            local step = { index = i, elements = lines }
            for _, e in ipairs(lines) do e.step = step end
            steps[i] = step
        end
        steps[1].activeItems = { [6948] = true, [4854] = true, [77] = false }
        RXPCData = { currentStep = 1, stepSkip = {} }
        RXP = { currentGuide = { name = 'raw name', displayname = 'The Barrens 12-14', steps = steps },
            SetStep = function(n) STUB.setStep = n; RXPCData.currentStep = n end }
        RXPG_ARROW = { shown = true, element = steps[1].elements[3], IsShown = function(self) return self.shown end }
    """)
    s.addon(BASE)
    G = s.g.PatchwerkForever.Guides
    info = G.Read(G, 3)
    assert info.source == "rxp" and info.reader == "RestedXP" and info.guide == "The Barrens 12-14"
    assert info.index == 1 and info.total == 5 and info.kind == "complete", (info.index, info.total, info.kind)
    lines = [(l.text, l.done, l.kind) for l in info.lines.values()]
    assert lines == [("Accept Plainstrider Menace", True, "accept"), ("Kill 7 plainstriders", False, "complete")], lines
    assert list(G.Words(info).values()) == ["Kill 7 plainstriders"]
    assert (info.map, info.x, info.y) == (1, -600, -2800), "its place is not where RestedXP's arrow points"
    ahead = [(a.index, a.kind, a.map) for a in info.ahead.values()]
    # (the step that is only words is passed over; the hearthstone, which carries you off, is not)
    assert ahead == [(2, "fly", 1), (4, "hearth", None), (5, "turnin", 1)], ahead
    assert len(G.Read(G, 1).ahead) == 1 and len(G.Read(G, 0).ahead) == 0
    # every step after it, for a list of them: the one that is only words too
    after = [(a.index, a.kind) for a in info.after.values()]
    assert after == [(2, "fly"), (3, "train"), (4, "hearth")], after
    assert len(G.Read(G, 0).after) == 0
    assert list(info["items"].values()) == [4854, 6948], "the items the step wants used"
    # the guide moved to another step, as a click in its own window does; never past its ends
    assert G.Go(G, info, 3) is True and s.stub.setStep == 3 and G.Read(G, 0).index == 3
    assert G.Go(G, info, 6) is False and G.Go(G, info, 0) is False and s.stub.setStep == 3
    # a step that has you fly says where to; other steps do not
    assert G.Go(G, info, 2) is True and G.Read(G, 0).flyTo == "ORGRIMMAR" and G.Read(G, 0).kind == "fly"
    assert G.Go(G, info, 1) is True and G.Read(G, 0).flyTo is None
    # the arrow hidden: its last spot is not gone to; the step's own place is
    s.lua.execute("RXPG_ARROW.shown = false; RXPG_ARROW.element = RXP.currentGuide.steps[5].elements[2]")
    info = G.Read(G, 0)
    assert (info.x, info.y) == (-600, -2800), "the hidden arrow's last spot was taken"
    # a step with nowhere to go
    s.lua.execute("RXPCData.currentStep = 4")
    info = G.Read(G, 0)
    assert info.kind == "hearth" and info.map is None and info.key == "4:nowhere"
    # no steps to be found (RestedXP changed, or an older one): the arrow's spot alone
    s.lua.execute("RXP = nil; RXPG_ARROW.shown = true")
    info = G.Read(G, 2)
    assert info.kind == "place" and (info.x, info.y) == (1600, -4400) and len(info.lines) == 0 and len(info.ahead) == 0
    s.lua.execute("RXPG_ARROW = nil")
    assert G.Read(G, 2) is None
    assert s.chat() == []

    step("the gathering service: nothing offered, then a provider; one that fails is said once")
    s = Session()
    s.addon(BASE)
    Ga = s.g.PatchwerkForever.Gather
    assert Ga.Has(Ga) is False and len(Ga.Near(Ga, 3)) == 0 and Ga.State(Ga) is None and Ga.Start(Ga, "any") is None
    s.lua.execute("""
        local state
        PatchwerkForever.Gather:Offer({
            Near = function(count) STUB.askedNear = count; return { { name = 'Peacebloom', kind = 'h', yards = 40 } } end,
            Start = function(mode, name) state = { mode = mode, name = name, going = name or 'Peacebloom' }; return true end,
            Stop = function() state = nil end,
            State = function() if STUB.breakGather then error('its spots moved') end return state end,
        })
    """)
    assert Ga.Has(Ga) is True
    near = Ga.Near(Ga)
    assert s.stub.askedNear == 5 and near[1].name == "Peacebloom"
    assert Ga.Start(Ga, "kind", "Peacebloom") is True and Ga.State(Ga).mode == "kind" and Ga.State(Ga).going == "Peacebloom"
    Ga.Stop(Ga)
    assert Ga.State(Ga) is None
    s.stub.breakGather = True
    assert Ga.State(Ga) is None and Ga.State(Ga) is None
    text = s.chat_raw()
    assert len(text) == 1 and "Gathering failed and was skipped" in text[0], text
    ok = s.lua.eval("function() return (pcall(PatchwerkForever.Gather.Offer, PatchwerkForever.Gather, { Near = function() end })) end")()
    assert ok is False, "a provider with pieces missing was taken"

    step("the trails service: nothing offered, then a provider, its coming told; one that fails is said once")
    Tr = s.g.PatchwerkForever.Trails
    assert Tr.Has(Tr) is False and len(Tr.List(Tr)) == 0 and len(Tr.Crossings(Tr)) == 0
    s.lua.execute("""
        STUB.trailTold, STUB.spots = 0, {}
        PatchwerkForever.Trails:OnChange(function() STUB.trailTold = STUB.trailTold + 1 end)
        PatchwerkForever.Trails:OnChange(function() error('a listener of its own mind') end)
        PatchwerkForever.Trails:NodesAround(1, 0, 0, 100, function() error('asked with nothing offered') end)
        PatchwerkForever.Trails:Offer({
            List = function() if STUB.breakTrails then error('its trail tangled') end return { { follow = true, pieces = {} } } end,
            Crossings = function() return { { id = 1, kind = 'boat' } } end,
            NodesAround = function(map, x, y, reach, fn) STUB.askedReach = reach; fn(x + 1, y + 1, 'Peacebloom', 133939, 'h') end,
        })
        PatchwerkForever.Trails:NodesAround(1, 10, 20, nil, function(x, y, name, icon, kind) STUB.spots[#STUB.spots + 1] = { x, y, name, icon, kind } end)
        PatchwerkForever.Trails:NodesAround(1, 10, 20, 50, 'not a function')
    """)
    assert Tr.Has(Tr) is True and s.stub.trailTold == 1, "a provider's coming was not told"
    assert Tr.List(Tr)[1].follow is True and Tr.Crossings(Tr)[1].kind == "boat"
    assert s.stub.askedReach == 500 and tuple(s.stub.spots[1].values()) == (11, 21, "Peacebloom", 133939, "h")
    Tr.Changed(Tr)
    assert s.stub.trailTold == 2
    text = s.chat_raw()
    assert len(text) == 2 and all("A trail listener failed" in t for t in text), text
    s.stub.breakTrails = True
    assert len(Tr.List(Tr)) == 0 and len(Tr.List(Tr)) == 0
    text = s.chat_raw()
    assert len(text) == 1 and "Reading the route failed and was skipped" in text[0], text
    ok = s.lua.eval("function() return (pcall(PatchwerkForever.Trails.Offer, PatchwerkForever.Trails, { List = function() end })) end")()
    assert ok is False, "a provider with pieces missing was taken"

    step("a choice: one side path at a time; a quest that leaves the log is a choice no longer")
    Ch = s.g.PatchwerkForever.Choice
    s.stub.breakGather = False
    s.lua.execute("STUB.QuestAt(870, 'The Forgotten Pools', 1, -400, -2600)")
    assert Ch.Get(Ch) is None and Ch.Set(Ch, "quest", 870) is True
    assert Ch.Get(Ch).id == 870 and Ch.Is(Ch, "quest", 870) and not Ch.Is(Ch, "quest", 871)
    assert Ga.Start(Ga, "any") is True and Ch.Get(Ch) is None, "a gathering run left the choice standing"
    assert Ch.Set(Ch, "quest", 870) and Ga.State(Ga) is None, "a choice left the gathering run on"
    s.lua.execute("STUB.QuestGone(870)")
    assert Ch.Get(Ch) is None, "a quest handed in is still the choice"
    assert Ch.Set(Ch, "quest", None) is False
    Ch.Set(Ch, "quest", 870)
    Ch.Clear(Ch)
    assert Ch.Get(Ch) is None

    step("the Dungeon Journal's quests as a list: stops in a short order, read from the journal as it runs; a side list unless set to lead")
    JOURNAL = """
        local function spot(wx, wy, label)        -- a place on Kalimdor's map, as the journal keeps one
            return { mapID = 1414, x = (17066.6 - wy) / (17066.6 + 19733.21), y = (12799.9 - wx) / (12799.9 + 11733.3), label = label }
        end
        STUB.flagged, STUB.complete, STUB.turnins = {}, {}, {}
        C_QuestLog.IsQuestFlaggedCompleted = function(id) return STUB.flagged[id] == true end
        C_QuestLog.IsComplete = function(id) return STUB.complete[id] == true end
        ForeverDungeonJournal_NS = {
            DB = {
                ['The Deadmines'] = { quests = {
                    { id = 214, name = 'Red Silk Bandanas', faction = 'Alliance' },
                    { id = 5001, name = 'Horde Job', faction = 'Horde' },
                    { id = 5002, name = 'Deep Job', faction = 'Both' },
                    { id = 5003, name = 'Second Job', faction = 'Both' },
                    { id = 5004, name = 'Chained Job', faction = 'Neutral' },
                    { id = 5005, name = 'Again And Again', faction = 'Both', repeatable = true },
                    { id = 5006, name = 'No Place', faction = 'Both' },
                    'not a quest',
                } },
                ['Coming Soon'] = { previewOnly = true, quests = { { id = 1, name = 'Hidden', faction = 'Both' } } },
            },
            QUEST_START_MAPS = {
                [5001] = spot(-100, -100, 'Thrall'), [5002] = spot(-1000, -1000), [5003] = spot(-300, -300),
                [5010] = spot(-400, 0, 'A Scout'),
            },
            QUEST_PREREQ_CHAINS = { [5004] = { { id = 5010, name = 'First Things' } } },
            TurnInSpotFor = function(quest) return STUB.turnins[quest.id] end,
            WaypointArrowTarget = function() return STUB.arrow end,
        }
        STUB.spot = spot
        STUB.turnins[5002] = spot(-50, 0, 'The Foreman')
        ForeverDungeonJournalCharacterDB = { trackedDungeons = { 'The Deadmines', 'Coming Soon', 'Not A Dungeon' } }
        -- you hold the Deep Job and have finished it
        STUB.QuestAt(5002, 'Deep Job', 1, -1000, -1000)
        STUB.complete[5002] = true
    """
    DJ = "PatchwerkForever_Stitch_DungeonJournal"
    s = Session(running=["ForeverDungeonJournal"])
    s.lua.execute(JOURNAL)
    base = s.addon(BASE)
    env = s.addon(DJ)
    assert env.linked, "the Dungeon Journal part did not join"
    s.login()
    assert s.chat() == []
    P = s.g.PatchwerkForever
    G, Ch = P.Guides, P.Choice
    # with no RestedXP guide it is listed, but it is not the main route by itself: it is a side list, read
    # by its name (which is how a list you selected is followed). The reads below are by its name.
    assert G.Read(G, 2) is None, "with no guide loaded the Dungeon Journal list became the main route by itself"
    assert [(i.source, i.side) for i in G.ReadAll(G, 2).values()] == [("fdj", True)]
    info = G.Read(G, 2, "fdj")
    assert info.side is True
    assert info.source == "fdj" and info.reader == "Dungeon Journal" and info.guide == "Dungeon Journal: The Deadmines", (info.source, info.guide)
    # (the finished quest's turn-in is nearest; the other side's quest, the repeatable one and the one
    # with no place are left out; five quests in all, none handed in)
    assert (info.index, info.total, info.kind) == (1, 5, "turnin"), (info.index, info.total, info.kind)
    assert [l.text for l in info.lines.values()] == ["Turn in: Deep Job", "The Foreman"]
    assert (round(info.x), round(info.y), info.map) == (-50, 0, 1), (info.x, info.y)
    after = [(a.index, a.lines[1].text) for a in info.after.values()]
    assert after == [(2, "Accept: Horde Job"), (3, "Accept: Second Job")], after
    assert [(a.index, round(a.x)) for a in info.ahead.values()] == [(2, -100), (3, -300)]
    # all of it: the quest that needs another first sends you to that one
    info = G.Read(G, 9, "fdj")
    assert [a.lines[1].text for a in info.after.values()][-1] == "Accept: First Things (needed for Chained Job)"
    assert len(info.after) == 3
    # skipping a stop: a click on the stop shown next skips the one you are on, and the one clicked leads,
    # though from where you stand now another is nearer
    s.lua.execute("STUB.player.x, STUB.player.y = -420, 0")
    assert G.Go(G, info, info.index + 1) is True
    text = s.chat()
    assert text == ["Patchwerk Dungeon Journal: A skipped stop stays skipped until you reload. Previous Step in the tracker, "
                    "or /tracker back, brings it back."], text
    info = G.Read(G, 9, "fdj")
    assert info.lines[1].text == "Accept: Horde Job", "the stop clicked does not lead: " + info.lines[1].text
    s.lua.execute("STUB.player.x, STUB.player.y = 0, 0")
    # (its step number counts the quests turned in: it stays through a skip. Tracker (Thread) tells such a
    # list by this to word its chat lines, and the stand-in for it in lua_tracker.py, STAYS, moves the same
    # way: change them together.)
    assert info.index == 1, "the step number moved on a skip"
    # /tracker back asks for the number it was at, the same number: the skip is taken back; with nothing
    # left to take back, Previous Step does nothing
    assert G.Go(G, info, info.index) is True and G.Read(G, 0, "fdj").lines[1].text == "Turn in: Deep Job"
    info = G.Read(G, 9, "fdj")
    assert info.index == 1, "the step number moved when a skip was taken back"
    assert G.Go(G, info, info.index - 1) is False, "a skip taken back with none left"
    # a later stop brought to the front, and the jump taken back
    assert G.Go(G, info, info.index + 2) is True
    info = G.Read(G, 9, "fdj")
    assert info.lines[1].text == "Accept: Second Job", "a later stop was not brought to the front"
    assert info.index == 1, "the step number moved when a later stop was brought to the front"
    assert G.Go(G, info, info.index) is True and G.Read(G, 0, "fdj").lines[1].text == "Turn in: Deep Job", "a jump not taken back"
    assert s.chat() == []
    # as you play: a quest accepted has no stop until it is done; one handed in counts as done
    s.lua.execute("STUB.QuestAt(5003, 'Second Job', 1, -300, -300)")
    assert G.Read(G, 0, "fdj").lines[1].text == "Turn in: Deep Job"
    s.lua.execute("STUB.QuestGone(5002); STUB.flagged[5002] = true")
    info = G.Read(G, 9, "fdj")
    assert (info.index, info.total) == (2, 5) and info.lines[1].text == "Accept: Horde Job", (info.index, info.lines[1].text)
    # the stop that leads keeps the lead while another is only a little nearer (two stops about as near as
    # each other do not take turns as you walk), and gives it up to one clearly nearer
    s.lua.execute("STUB.player.x, STUB.player.y = -255, -50")
    assert G.Read(G, 0, "fdj").lines[1].text == "Accept: Horde Job", "the lead flipped to a stop only a little nearer"
    s.lua.execute("STUB.player.x, STUB.player.y = -330, -20")
    assert G.Read(G, 0, "fdj").lines[1].text.startswith("Accept: First Things"), "a stop clearly nearer did not lead"
    s.lua.execute("STUB.player.x, STUB.player.y = 0, 0")
    assert G.Read(G, 0, "fdj").lines[1].text == "Accept: Horde Job"
    # the journal's own map arrow comes first; it can be skipped, and the skip taken back
    s.lua.execute("STUB.arrow = STUB.spot(-2000, -2000); STUB.arrow.questTitle = 'The Unsent Letter'")
    info = G.Read(G, 1, "fdj")
    assert info.kind == "place" and info.lines[1].text == "Go to: The Unsent Letter" and round(info.x) == -2000
    assert info.after[1].lines[1].text == "Accept: Horde Job"
    assert G.Go(G, info, info.index + 1) is True and G.Read(G, 0, "fdj").lines[1].text == "Accept: Horde Job", "the arrow not skipped"
    info = G.Read(G, 1, "fdj")
    assert G.Go(G, info, info.index) is True and G.Read(G, 0, "fdj").lines[1].text == "Go to: The Unsent Letter"
    # ... and an arrow on a listed stop is that stop: no stop of its own, the stop's own words, numbered as before
    s.lua.execute("STUB.arrow = STUB.spot(-108, -100); STUB.arrow.questTitle = 'Horde Job'")
    s.lua.execute("STUB.player.x, STUB.player.y = -400, 10")
    info = G.Read(G, 9, "fdj")
    assert info.lines[1].text == "Accept: Horde Job" and info.total == 5, (info.lines[1].text, info.total)
    assert [a.lines[1].text for a in info.after.values()] == ["Accept: First Things (needed for Chained Job)"]
    s.lua.execute("STUB.player.x, STUB.player.y = 0, 0")
    # ... but not to a hand-in before the quest is finished (the journal points there as soon as it is in your
    # log: Wailing Caverns, 2026-11-18), nor to a hand-in of a quest it cannot tell
    s.lua.execute("STUB.arrow = STUB.spot(-2000, -2000); STUB.arrow.questTitle = 'Second Job'; STUB.arrow.turnIn = true")
    info = G.Read(G, 1, "fdj")
    assert info.lines[1].text == "Accept: Horde Job", "sent to a hand-in before the quest was finished"
    s.lua.execute("STUB.complete[5003] = true")
    info = G.Read(G, 1, "fdj")
    assert info.kind == "place" and info.lines[1].text == "Turn in: Second Job", info.lines[1].text
    s.lua.execute("STUB.arrow.questTitle = 'The Unsent Letter'")
    assert G.Read(G, 1, "fdj").lines[1].text == "Accept: Horde Job", "a hand-in of a quest it cannot tell"
    s.lua.execute("STUB.arrow = STUB.spot(-2000, -2000); STUB.arrow.turnIn = true; STUB.arrow.fdjAutoQuest = 5003")
    assert G.Read(G, 1, "fdj").lines[1].text == "Turn in: Dungeon Journal map point", "a pin opened for a finished quest"
    s.lua.execute("STUB.arrow = nil; STUB.complete[5003] = nil")
    # its page, its two settings, and the binding: the list chosen as a side path, and let go again
    assert list(s.stub.pages.keys()) == ["Dungeon Journal (Stitch)"], list(s.stub.pages.keys())
    intro = list(s.stub.intros.values())[0]
    assert intro.voice.startswith("The big book knows who has the jobs."), intro.voice
    assert sorted(x.name for x in s.stub.settings.values()) == ["Dungeon Journal First", "Route Dungeon Journal Quests"]
    assert G.readers.fdj.Leads() is False and G.readers.fdj.Side() is True
    # Dungeon Journal First enabled: no side list any more, it is the main route as before
    P.SetSetting(P, "djLeads", True)
    assert G.readers.fdj.Leads() is True and G.readers.fdj.Side() is False
    info = G.Read(G, 2)
    assert info is not None and info.source == "fdj" and info.side is None, "set to lead, the list is not the main route"
    assert info.lines[1].text == "Accept: Horde Job" and len(info.after) == 1, info.lines[1].text
    assert [(i.source, i.side) for i in G.ReadAll(G, 0).values()] == [("fdj", None)]
    # ... and ahead of a RestedXP guide; disabled again, the guide is the main route and the list is beside it
    s.lua.execute("""
        RXPCData = { currentStep = 1 }
        RXP = { currentGuide = { name = 'A Guide', steps = { { index = 1, elements = { { tag = 'train', text = 'Train your skills' } } } } } }
    """)
    assert G.Read(G, 0).source == "fdj" and [i.source for i in G.ReadAll(G, 0).values()] == ["fdj", "rxp"]
    P.SetSetting(P, "djLeads", False)
    assert G.Read(G, 0).source == "rxp"
    assert [(i.source, i.side) for i in G.ReadAll(G, 0).values()] == [("rxp", None), ("fdj", True)]
    s.lua.execute("RXP, RXPCData = nil, nil")
    assert G.Read(G, 0) is None and G.Read(G, 0, "fdj") is not None
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    assert Ch.Is(Ch, "guide", "fdj")
    text = s.chat()
    assert text == ["Patchwerk Dungeon Journal: Routing through 2 stops. First: Accept: Horde Job."], text
    # selected: still not what is read as the main route, and read by its name as long as it is the choice
    assert G.Read(G, 0) is None and G.Read(G, 3, "fdj").lines[1].text == "Accept: Horde Job" and Ch.Get(Ch).id == "fdj"
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    assert Ch.Get(Ch) is None and s.chat() == ["Patchwerk Dungeon Journal: Back to your main route."]
    text = s.slash("dj")
    assert Ch.Is(Ch, "guide", "fdj") and any("Routing through 2 stops" in t for t in text), text
    # /patchwerk dj on, off and status do only that
    assert s.slash("dj on") == [] and Ch.Is(Ch, "guide", "fdj")
    assert s.slash("dj status") == ["Patchwerk Dungeon Journal: on: 2 stops, being followed"]
    assert s.slash("dj off") == ["Patchwerk Dungeon Journal: Back to your main route."] and Ch.Get(Ch) is None
    assert s.slash("dj stop") == ["Patchwerk Dungeon Journal: The Dungeon Journal list is not being followed."] and Ch.Get(Ch) is None
    assert s.slash("dj sideways") == ["Patchwerk Dungeon Journal: Usage: /patchwerk dj [on | off | status]"]
    assert any("Dungeon Journal quests as a route (dj) for ForeverDungeonJournal: on: 2 stops" in t for t in s.slash(""))
    # every stop skipped: the binding brings them back, since you asked for the list
    for _ in range(3):
        info = G.Read(G, 1, "fdj")
        if info is None:
            break
        G.Go(G, info, info.index + 1)
    assert G.Read(G, 0, "fdj") is None
    s.chat()
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    text = s.chat()
    assert text[0] == "Patchwerk Dungeon Journal: Skipped stops are back on the list." and Ch.Is(Ch, "guide", "fdj"), text
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    s.chat()
    # every quest handed in: no list, and the choice lets go by itself; asked for, it says why
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    s.lua.execute("for _, id in ipairs({ 5001, 5003, 5004, 5006 }) do STUB.flagged[id] = true end")
    assert G.Read(G, 0, "fdj") is None and len(G.ReadAll(G, 0)) == 0 and Ch.Get(Ch) is None
    s.chat()
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    assert s.chat() == ["Patchwerk Dungeon Journal: Every quest of your tracked dungeons is turned in."]
    # a quest held and not finished has its work inside: said with the counts
    s.lua.execute("STUB.flagged[5001] = nil; STUB.QuestAt(5001, 'Horde Job', 1, -100, -100)")
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    text = s.chat()
    assert text == ["Patchwerk Dungeon Journal: Nothing to route to right now: 4 of 5 turned in, 1 in your quest log to finish in the dungeon, 0 skipped."], text
    # disabled; a journal changed beyond recognition; no journal at all: no list, no error
    s.lua.execute("STUB.flagged = {}")
    assert G.Read(G, 0, "fdj") is not None
    P.SetSetting(P, "djList", False)
    assert G.Read(G, 0, "fdj") is None
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    assert any("Route Dungeon Journal Quests is disabled" in t for t in s.chat())
    P.SetSetting(P, "djList", True)
    s.lua.execute("ForeverDungeonJournal_NS.DB['The Deadmines'].quests = 'moved'; ForeverDungeonJournal_NS.QUEST_START_MAPS = 7")
    assert G.Read(G, 0, "fdj") is None
    s.lua.execute("ForeverDungeonJournal_NS.DB = 'gone'")
    assert G.Read(G, 0, "fdj") is None
    s.lua.execute("ForeverDungeonJournal_NS = nil")
    assert G.Read(G, 0, "fdj") is None
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    assert any("Dungeon Journal is running, but its quest data was not found" in t for t in s.chat())
    s.stub.loaded["ForeverDungeonJournal"] = False
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    assert any("Dungeon Journal is not running" in t for t in s.chat())
    # the journal running without this part: the base says which addon to get, once
    s = Session(running=["ForeverDungeonJournal"])
    s.addon(BASE)
    s.login()
    text = s.chat()
    assert len(text) == 1 and "Patchwerk Forever: Dungeon Journal (Stitch)" in text[0], text

    step("Focus and My Route (API 5): a focus kept for each character; stops added, moved, ordered, followed, tidied")
    s = Session(running=["ForeverDungeonJournal"])
    s.lua.execute(JOURNAL)
    s.lua.execute("""
        local before = UnitGUID
        function UnitGUID(unit) if unit == 'player' then return STUB.guid end return before(unit) end
        STUB.guid = 'Player-1-0001'
        C_QuestLog.GetTitleForQuestID = function(id) return STUB.quests[id] and STUB.quests[id].title end
    """)
    s.addon(BASE)
    s.addon("PatchwerkForever_Stitch_DungeonJournal")
    s.login()
    P = s.g.PatchwerkForever
    F, R, G, Ch = P.Focus, P.MyRoute, P.Guides, P.Choice
    wrap = s.lua.eval("function(f) return function(...) f(...) end end")      # (a Python function, as a Lua one)
    seen = []
    F.OnChange(F, wrap(lambda id: seen.append(id)))
    changes = []
    R.OnChange(R, wrap(lambda: changes.append(1)))
    chosen = []
    Ch.OnChange(Ch, wrap(lambda c=None: chosen.append(c.kind if c else None)))
    assert F.Get(F) == "auto"
    names = [a.id for a in F.Available(F).values()]
    assert names == ["auto", "fdj", "quests", "route"], names
    assert F.Set(F, "nothing") is False and F.Set(F, "fdj") is True and F.Get(F) == "fdj" and seen == ["fdj"]
    assert F.Next(F) == "quests"
    assert s.g.PatchwerkForeverDB.characters["Player-1-0001"].focus == "fdj", "the focus is not kept for the character"
    s.lua.execute("STUB.guid = 'Player-1-0002'")
    assert F.Get(F) == "auto", "another character got the first one's focus"
    s.lua.execute("STUB.guid = 'Player-1-0001'")
    # My Route: empty, it says nothing; a quest you hold (finished: its hand-in), a journal quest not taken,
    # a map spot; no doubles
    assert G.Read(G, 2, "route") is None and G.Read(G, 2) is None or G.Read(G, 2).source != "route"
    s.lua.execute("STUB.QuestAt(7001, 'Wolf Pelts', 1, -100, 0); STUB.QuestAt(7002, 'Far Away', 1, -900, 0)")
    s.lua.execute("STUB.complete[7001] = true")
    assert R.Add(R, s.lua.eval("{ kind = 'quest', id = 7002 }")) is True
    assert R.Add(R, s.lua.eval("{ kind = 'quest', id = 7001 }")) is True
    assert R.Add(R, s.lua.eval("{ kind = 'quest', id = 7001 }")) is False, "a quest added twice"
    assert R.Add(R, s.lua.eval("{ kind = 'fdj', id = 5001 }")) is True
    assert R.Add(R, s.lua.eval("{ kind = 'spot', map = 1, x = -500, y = 0, label = 'Camp' }")) is True
    assert R.Add(R, s.lua.eval("{ kind = 'spot', map = 1, x = -500, y = 0 }")) is False, "a spot added twice"
    assert len(changes) == 4
    entries = [(e.kind, e.name, e.state) for e in R.Entries(R).values()]
    assert entries == [("quest", "Far Away", "todo"), ("quest", "Wolf Pelts", "done"), ("fdj", "Horde Job", "pickup"),
                       ("spot", "Camp", "spot")], entries
    # followed in your order, the stops after given too; a side list: not the main guide by itself
    info = G.Read(G, 9, "route")
    assert info.source == "route" and info.side is True and info.guide == "My Route"
    assert [l.text for l in info.lines.values()] == ["Do: Far Away"] and info.quest == 7002 and info.index == 1, info.lines[1].text
    assert [a.lines[1].text for a in info.after.values()] == ["Turn in: Wolf Pelts", "Accept: Horde Job", "Go to: Camp"]
    # moved by hand; the short order (you stand at 0, 0: the pelts at 100 yards, the camp at 500, the far quest at 900)
    assert R.Move(R, 4, 1) is True and G.Read(G, 0, "route").lines[1].text == "Go to: Camp"
    assert R.Order(R) is True
    order = [e.name for e in R.Entries(R).values()]
    assert order[0] == "Wolf Pelts" and order.index("Camp") < order.index("Far Away"), order
    # skipped from the tracker (the step after), brought back (the one before)
    info = G.Read(G, 9, "route")
    first = info.lines[1].text
    assert G.Go(G, info, info.index + 1) is True and G.Read(G, 0, "route").lines[1].text != first
    info = G.Read(G, 9, "route")
    assert G.Go(G, info, info.index - 1) is True and G.Read(G, 0, "route").lines[1].text == first
    # focus on it: Choice untouched; a choice still stands apart (and says when it changes)
    assert Ch.Set(Ch, "guide", "route") is True and Ch.Is(Ch, "guide", "route") and chosen[-1] == "guide"
    Ch.Clear(Ch)
    assert chosen[-1] is None
    # kept up to date: a journal quest taken becomes a quest; a quest abandoned or handed in leaves, by the
    # event that names it; an empty quest log (at login, before it is filled) takes nothing away
    s.lua.execute("STUB.QuestAt(5001, 'Horde Job', 1, -100, -100)")
    s.stub.Fire("QUEST_ACCEPTED", 5001)
    assert [e.kind for e in R.Entries(R).values() if e.id == 5001] == ["quest"], "a journal quest taken did not become a quest"
    s.lua.execute("C_QuestLog.GetNumQuestLogEntries = function() return 0, 0 end")
    before = len(R.Entries(R))
    s.lua.execute("STUB.QuestGone(7002)")
    s.stub.Fire("QUEST_LOG_UPDATE")
    assert len(R.Entries(R)) == before, "the route was cut while the quest log was empty"
    s.stub.Fire("QUEST_REMOVED", 7002)
    assert all(e.id != 7002 for e in R.Entries(R).values()), "an abandoned quest stayed"
    # a map spot leaves once you are there; Go Here First follows on from that stop
    s.lua.execute("STUB.player.x, STUB.player.y = -500, 0")
    s.lua.execute("PatchwerkForever.MyRoute:Lead(#PatchwerkForever.MyRoute:Entries())")
    G.Read(G, 0, "route")
    assert all(e.kind != "spot" for e in R.Entries(R).values()), "a map spot reached stayed in the route"
    s.lua.execute("STUB.player.x, STUB.player.y = 0, 0")
    R.Add(R, s.lua.eval("{ kind = 'quest', id = 7001 }"))
    names = [e.name for e in R.Entries(R).values()]
    assert R.Lead(R, 2) is True and G.Read(G, 0, "route").lines[1].text.endswith(names[1]), (names, G.Read(G, 0, "route").lines[1].text)
    assert R.Remove(R, 1) is True and R.Clear(R) is True and len(R.Entries(R)) == 0
    assert G.Read(G, 0, "route") is None
    # a hand-in waits (2.7.1): finished Wolf Pelts first in the list at 100 yards; another quest's objective
    # at 30 yards goes first, the hand-in next; one only a little nearer does not; a hand-in clicked is not put off
    s.lua.execute("STUB.QuestAt(7003, 'Boar Ribs', 1, -30, 0); STUB.complete[7001] = true")
    R.Add(R, s.lua.eval("{ kind = 'quest', id = 7001 }"))
    R.Add(R, s.lua.eval("{ kind = 'quest', id = 7003 }"))
    info = G.Read(G, 9, "route")
    assert info.lines[1].text == "Do: Boar Ribs", info.lines[1].text
    assert [a.lines[1].text for a in info.after.values()] == ["Turn in: Wolf Pelts"], [a.lines[1].text for a in info.after.values()]
    # clicking the hand-in (the stop after) goes there and skips nothing
    assert G.Go(G, info, 1) is True and G.Read(G, 0, "route").lines[1].text == "Turn in: Wolf Pelts"
    assert R.Clear(R) is True
    s.lua.execute("STUB.QuestAt(7003, 'Boar Ribs', 1, -90, 0)")
    R.Add(R, s.lua.eval("{ kind = 'quest', id = 7001 }"))
    R.Add(R, s.lua.eval("{ kind = 'quest', id = 7003 }"))
    assert G.Read(G, 0, "route").lines[1].text == "Turn in: Wolf Pelts", "a hand-in put off for a stop only a little nearer"
    assert R.Clear(R) is True
    assert s.chat() == [], s.chat()

    step("2.7.0: what is followed (Following), percent sliders, a tool's errors said once each and three to a label")
    s = Session()
    s.lua.execute("""
        local made = Settings.CreateSliderOptions
        Settings.CreateSliderOptions = function(...)
            local options = made(...)
            options.SetLabelFormatter = function(_, how, format) STUB.formatted = format and format(99.6) or 'plain' end
            return options
        end
        MinimalSliderWithSteppersMixin = { Label = { Right = 'right' } }
    """)
    base = s.addon(BASE)
    s.login()
    P = s.g.PatchwerkForever
    Fo = P.Following
    told = []
    Fo.OnChange(Fo, s.lua.eval("function(f) return function(info) f(info and info.key or 'nothing') end end")(lambda k: told.append(k)))
    Fo.OnChange(Fo, s.lua.eval("function() error('a listener that breaks') end"))
    s.lua.execute("geterrorhandler = function() return function(problem) STUB.problem = problem end end")
    assert Fo.Get(Fo) is None
    Fo.Set(Fo, s.lua.eval("{ kind = 'guide', source = 'rxp', key = 'rxp:12' }"))
    assert Fo.Get(Fo).key == "rxp:12" and told == ["rxp:12"] and "a listener that breaks" in str(s.stub.problem)
    Fo.Set(Fo, s.lua.eval("{ kind = 'guide', source = 'rxp', key = 'rxp:12' }"))
    assert told == ["rxp:12"], "told again of the same thing"
    Fo.Set(Fo, s.lua.eval("{ kind = 'quest', quest = 870, key = 'rxp:12' }"))
    Fo.Set(Fo, None)
    Fo.Set(Fo, None)
    assert told == ["rxp:12", "rxp:12", "nothing"] and Fo.Get(Fo) is None, told
    # the way there, told once the route is found: kept while the same destination is told again, and
    # gone with a new one (2.7.0)
    Fo.Set(Fo, s.lua.eval("{ kind = 'guide', source = 'route', key = 'route:1' }"))
    Fo.SetTravel(Fo, "Fly from Crossroads to Thunder Bluff (3 min in all)")
    assert told[-1] == "route:1" and len(told) == 5 and Fo.Get(Fo).travel.startswith("Fly from"), told
    Fo.Set(Fo, s.lua.eval("{ kind = 'guide', source = 'route', key = 'route:1' }"))
    assert Fo.Get(Fo).travel.startswith("Fly from"), "the way there was lost when the same place was told again"
    Fo.Set(Fo, s.lua.eval("{ kind = 'guide', source = 'route', key = 'route:2' }"))
    assert Fo.Get(Fo).travel is None
    Fo.Set(Fo, None)
    base.SliderOptions(s.lua.eval("{ min = 0, max = 200, step = 5, percent = true }"))
    assert s.stub.formatted == "100%", s.stub.formatted
    base.SliderOptions(s.lua.eval("{ min = 0, max = 200, step = 5 }"))
    assert s.stub.formatted == "plain"
    tool = s.lua.table()
    assert P.Tool(P, "PatchwerkForever_MadeUpTool", tool, s.lua.eval("{ saved = 'MadeUpToolDB', name = 'Made Up' }"))
    for problem in ("one", "one", "two", "three", "four"):
        tool.Try("an event", s.lua.eval("function(p) error(p, 0) end"), problem)
    said = list(s.stub.messages.values())[-3:]
    assert said == ["|cffd6a35bMade Up|r: A problem in an event (reported once): one",
                    "|cffd6a35bMade Up|r: A problem in an event (reported once): two",
                    "|cffd6a35bMade Up|r: A problem in an event (reported once): three"], said
    s.said = len(s.stub.messages)

    step("the Console Port part's binding changes and its fixes, said through Patchwerk")
    s = Session(saved="{ settings = { foreverNotify = true } }", running=["ConsolePort"], console_port=True)
    s.addon(BASE)
    env = s.addon("PatchwerkForever_Stitch_ConsolePort", only=["Link.lua", "Database.lua", "Compat.lua"])
    s.login()
    env.Notify(env, "Restored native gamepad bindings: %s", "PAD1 (Ping)")
    assert s.chat() == ["Patchwerk Console Port: Restored native gamepad bindings: PAD1 (Ping)"]
    assert env.Applied.GetScaledCursorPosition is True and env.Applied.StaticPopup_Resize is True

    step("MelloUI Route's five actions are named for the game's Key Bindings list")
    xml = open(os.path.join(ADDONS, "PatchwerkForever_Stitch_MelloUIRoute", "Bindings.xml"), encoding="utf-8").read()
    controls = open(os.path.join(ADDONS, "PatchwerkForever_Stitch_MelloUIRoute", "Controls.lua"), encoding="utf-8").read()
    for button in re.findall(r'CLICK (\w+):LeftButton', xml):
        assert "button = '%s'" % button in controls, button
    assert len(re.findall(r'CLICK (\w+):LeftButton', xml)) == 5

    step("every binding of the family is under its one heading")
    for folder in os.listdir(ADDONS):
        path = os.path.join(ADDONS, folder, "Bindings.xml")
        if folder.startswith("PatchwerkForever") and os.path.exists(path):
            for binding in re.findall(r"<Binding [^>]*>", open(path, encoding="utf-8").read()):
                assert 'category="BINDING_CATEGORY_PatchwerkForever"' in binding, (folder, binding)

    step("every part carries the same joining file")
    for part in PARTS[1:]:
        assert open(os.path.join(ADDONS, part, "Link.lua"), encoding="utf-8").read() == link, part
        assert toc(part)[1][0] == "Link.lua"

    print("all steps ran")


if __name__ == "__main__":
    main()
