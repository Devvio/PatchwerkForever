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

    def __init__(self, saved=None, running=(), installed=(), console_port=False):
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
                running=["ConsolePort"])
    s.addon(BASE)
    s.login()
    text = s.chat()
    assert len(text) == 1 and "Patchwerk Forever: Stitch (Console Port)" in text[0], text
    assert len(s.stub.settings) == 1 and s.stub.category, "the base's page was not built"
    assert s.g.PatchwerkForeverDB.ConsolePort.cleared.X, "the old saved data was touched"
    assert s.g.PatchwerkForeverDB.settings.foreverNotify is False
    text = s.slash("")
    assert text[0] == "Patchwerk Forever %s. Its parts:" % toc(BASE)[0]["Version"] and any("none. This is the base" in t for t in text), text
    assert any("Patchwerk Forever: Stitch (Console Port) (for Console Port): not installed" in t for t in text), text
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
    assert sum("installed, not switched on" in t for t in text) == 3, text

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
    s.addon(BASE)
    ns = s.addon(MADE_UP, files=MADE_UP_FILES, version="1.2.3")
    # the hook first (it saw the second file), then the setting with its saved value
    assert s.log() == ["hook, second file ran: true", "setting false true"], s.log()
    s.login()
    assert s.chat() == []
    assert s.log() == ["hook, second file ran: true", "setting false true"], "run twice"
    assert len(s.stub.settings) == 3, len(s.stub.settings)
    # the part's settings are on a page of its own under the base's; one section needs no heading there
    heads = list(s.stub.headers.values())
    assert heads == ["Patchwerk Forever"], heads
    assert list(s.stub.pages.keys()) == ["PatchwerkForever_MadeUp"], list(s.stub.pages.keys())
    on = sorted(x.variable for x in s.stub.settings.values() if x.page == "PatchwerkForever_MadeUp")
    assert on == ["PatchwerkForever_madeUpOn", "PatchwerkForever_madeUpSteps"], on
    P = s.g.PatchwerkForever
    assert P.GetSetting(P, "madeUpSteps") == 9, "a saved number is read as it was saved"
    text = s.slash("")
    assert any("PatchwerkForever_MadeUp 1.2.3" in t for t in text), text
    assert any("A made-up fix (madeup) for Nothing: fine" in t for t in text), text
    text = s.slash("madeup hello there")
    assert text == ["Patchwerk made-up command: hello there"], text
    text = s.slash("set madeupon on")
    assert s.log()[-1] == "setting true false" and "madeUpOn: on" in text[0], (s.log(), text)
    assert s.g.PatchwerkForeverDB.settings.madeUpOn is True
    text = s.slash("set madeupsteps 99")
    assert s.g.PatchwerkForeverDB.settings.madeUpSteps == 5, "a number is not kept inside its range"
    text = s.slash("set")
    assert sum(1 for t in text if t.startswith("  ")) == 3, text
    s.slash("config")
    assert s.stub.opened == 7, "the settings page was not opened"
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
    assert len(s.g.PatchwerkForever.Fixes) == 0 and len(s.stub.settings) == 1
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
    assert list(s.stub.headers.values()) == ["Patchwerk Forever"]
    assert list(s.stub.pages.keys()) == ["Stitch: Console Port"], list(s.stub.pages.keys())
    assert sum(1 for x in s.stub.settings.values() if x.page == "Stitch: Console Port") == 9
    assert sum(1 for x in s.stub.settings.values() if x.page == "Patchwerk Forever") == 1
    assert env.GetSetting(env, "foreverNotify") is False and env.GetSetting(env, "foreverClearPing") is True
    assert env.GetConsolePortSaved(env).cleared.X, "the part does not see what 1.x saved"

    step("a part with no base, and with a base too old for it: one line of chat, no error")
    link = open(os.path.join(ADDONS, PARTS[0], "Link.lua"), encoding="utf-8").read()
    for label, setup in (("no base", ""), ("old base", "PatchwerkForever = { Link = function() return false end }")):
        s = Session(running=["ConsolePort"], console_port=True)
        s.lua.execute(setup)
        ns = s.addon(PARTS[0])
        text = list(s.stub.messages.values())
        assert len(text) == 1 and "needs a newer Patchwerk Forever" in text[0], (label, text)
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
    assert any("Switched off: Chat, Map" in t for t in text) and s.stub.popup == "PATCHWERK_MELLOUI_RELOAD", text
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

    step("the guides service: readers asked in turn, a failing one skipped, RestedXP read as it runs")
    s = Session()
    s.addon(BASE)
    G = s.g.PatchwerkForever.Guides
    assert s.g.PatchwerkForever.API == 2
    assert G.Read(G, 2) is None, "a guide with no guide addon running"
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
    # RestedXP, with a stand-in for what it keeps as it runs
    s = Session()
    s.lua.execute("""
        local function at(x, y) return { tag = 'goto', wx = y, wy = x, instance = 1 } end
        local steps = {
            { { tag = 'accept', text = 'Accept Plainstrider Menace', completed = true }, { tag = 'complete', text = ' Kill 7 plainstriders ' }, at(-600, -2800) },
            { { tag = 'fly', text = 'Fly to Orgrimmar' }, at(-437, -2596) },
            { { tag = 'train', text = 'Train your skills' } },
            { { tag = 'hs', text = 'Hearth to the Crossroads' } },
            { { tag = 'turnin', text = 'Turn in your report' }, at(1600, -4400) },
        }
        for i, lines in ipairs(steps) do
            local step = { index = i, elements = lines }
            for _, e in ipairs(lines) do e.step = step end
            steps[i] = step
        end
        RXPCData = { currentStep = 1, stepSkip = {} }
        RXP = { currentGuide = { name = 'raw name', displayname = 'The Barrens 12-14', steps = steps } }
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

    step("every part carries the same joining file")
    for part in PARTS[1:]:
        assert open(os.path.join(ADDONS, part, "Link.lua"), encoding="utf-8").read() == link, part
        assert toc(part)[1][0] == "Link.lua"

    print("all steps ran")


if __name__ == "__main__":
    main()
