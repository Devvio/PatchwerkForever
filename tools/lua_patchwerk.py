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
    base = s.addon(BASE)
    s.login()
    text = s.chat()
    assert len(text) == 1 and "Patchwerk Forever: Stitch (Console Port)" in text[0], text
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
    assert len(parts) == 1 and parts[0].name == "Stitch (Console Port)" and not parts[0].open, [x.name for x in parts]
    assert "Not sewn on. It is for Console Port, which is running." == parts[0].says, parts[0].says
    switches = list(page.switches.values())
    assert len(switches) == 1 and switches[0].key == "baseTellMissing" and switches[0].checked is True
    assert switches[0].Label.text == "Notify About Missing Addons", switches[0].Label.text
    switches[0].checked = False
    switches[0].scripts.OnClick(switches[0])
    assert s.g.PatchwerkForever.GetSetting(s.g.PatchwerkForever, "baseTellMissing") is False
    switches[0].checked = True
    switches[0].scripts.OnClick(switches[0])
    assert s.chat() == []
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
    assert len(s.stub.settings) == 9, len(s.stub.settings)
    assert list(s.stub.headers.values()) == []
    assert list(s.stub.pages.keys()) == ["Stitch: Console Port"], list(s.stub.pages.keys())
    assert sum(1 for x in s.stub.settings.values() if x.page == "Stitch: Console Port") == 9
    # the Stitch's page opens with its name, its picture and what Patchwerk says of it (its TOC)
    intro = list(s.stub.intros.values())[0]
    assert intro.name == "Stitch: Console Port" and intro.icon.endswith("Stitch_ConsolePort\\Media\\icon"), (intro.name, intro.icon)
    assert intro.voice == "Buttons were loose. Patchwerk sewed them back on the stick.", intro.voice
    assert s.stub.Rows() == 1
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
    assert s.g.PatchwerkForever.API == 4
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
    assert G.Go(G, info, 1) is True
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

    step("the Dungeon Journal's quests as a list: stops in a short order, read from the journal as it runs")
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
    info = G.Read(G, 2)
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
    info = G.Read(G, 9)
    assert [a.lines[1].text for a in info.after.values()][-1] == "Accept: First Things (needed for Chained Job)"
    assert len(info.after) == 3
    # skipping a stop, taking the skip back, bringing a later stop to the front
    assert G.Go(G, info, info.index + 1) is True
    assert G.Read(G, 0).lines[1].text == "Accept: Horde Job"
    info = G.Read(G, 0)
    assert G.Go(G, info, info.index - 1) is True and G.Read(G, 0).lines[1].text == "Turn in: Deep Job"
    info = G.Read(G, 9)
    assert G.Go(G, info, info.index + 2) is True
    info = G.Read(G, 9)
    assert info.lines[1].text == "Accept: Second Job", "a later stop was not brought to the front"
    # as you play: a quest accepted has no stop until it is done; one handed in counts as done
    s.lua.execute("STUB.QuestAt(5003, 'Second Job', 1, -300, -300)")
    assert G.Read(G, 0).lines[1].text == "Turn in: Deep Job"
    s.lua.execute("STUB.QuestGone(5002); STUB.flagged[5002] = true")
    info = G.Read(G, 9)
    assert (info.index, info.total) == (2, 5) and info.lines[1].text == "Accept: Horde Job", (info.index, info.lines[1].text)
    # the journal's own map arrow comes first, and cannot be skipped from here
    s.lua.execute("STUB.arrow = STUB.spot(-2000, -2000); STUB.arrow.questTitle = 'The Unsent Letter'; STUB.arrow.turnIn = true")
    info = G.Read(G, 1)
    assert info.kind == "place" and info.lines[1].text == "Turn in: The Unsent Letter" and round(info.x) == -2000
    assert info.after[1].lines[1].text == "Accept: Horde Job"
    assert G.Go(G, info, info.index + 1) is False
    s.lua.execute("STUB.arrow = nil")
    # its page, its two settings, and the binding: the list chosen as a side path, and let go again
    assert list(s.stub.pages.keys()) == ["Stitch: Dungeon Journal"], list(s.stub.pages.keys())
    intro = list(s.stub.intros.values())[0]
    assert intro.voice.startswith("The big book knows who has the jobs."), intro.voice
    assert sorted(x.name for x in s.stub.settings.values()) == ["Dungeon Journal Before RestedXP", "Route Dungeon Journal Quests"]
    assert G.readers.fdj.Leads() is False
    P.SetSetting(P, "djLeads", True)
    assert G.readers.fdj.Leads() is True
    P.SetSetting(P, "djLeads", False)
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    assert Ch.Is(Ch, "guide", "fdj")
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    assert Ch.Get(Ch) is None
    text = s.slash("dj")
    assert Ch.Is(Ch, "guide", "fdj") and any("routing through the quests" in t for t in text), text
    # every quest handed in: no list, and the choice lets go by itself
    s.lua.execute("for _, id in ipairs({ 5001, 5003, 5004, 5006 }) do STUB.flagged[id] = true end")
    assert G.Read(G, 0) is None and Ch.Get(Ch) is None
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    assert any("nothing to route to" in t for t in s.chat())
    # switched off; a journal changed beyond recognition; no journal at all: no list, no error
    s.lua.execute("STUB.flagged = {}")
    assert G.Read(G, 0) is not None
    P.SetSetting(P, "djList", False)
    assert G.Read(G, 0) is None
    P.SetSetting(P, "djList", True)
    s.lua.execute("ForeverDungeonJournal_NS.DB['The Deadmines'].quests = 'moved'; ForeverDungeonJournal_NS.QUEST_START_MAPS = 7")
    assert G.Read(G, 0) is None
    s.lua.execute("ForeverDungeonJournal_NS.DB = 'gone'")
    assert G.Read(G, 0) is None
    s.lua.execute("ForeverDungeonJournal_NS = nil")
    assert G.Read(G, 0) is None
    s.g.PatchwerkForever_Stitch_DungeonJournal_Route()
    assert any("Dungeon Journal is not running" in t for t in s.chat())
    # the journal running without this part: the base says which addon to get, once
    s = Session(running=["ForeverDungeonJournal"])
    s.addon(BASE)
    s.login()
    text = s.chat()
    assert len(text) == 1 and "Patchwerk Forever: Stitch (Dungeon Journal)" in text[0], text

    step("every part carries the same joining file")
    for part in PARTS[1:]:
        assert open(os.path.join(ADDONS, part, "Link.lua"), encoding="utf-8").read() == link, part
        assert toc(part)[1][0] == "Link.lua"

    print("all steps ran")


if __name__ == "__main__":
    main()
