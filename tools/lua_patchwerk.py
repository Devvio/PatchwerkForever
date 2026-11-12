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
    assert text[0] == "Patchwerk Forever 2.0.0. Its parts:" and any("none. This is the base" in t for t in text), text
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

    step("every part carries the same joining file")
    for part in PARTS[1:]:
        assert open(os.path.join(ADDONS, part, "Link.lua"), encoding="utf-8").read() == link, part
        assert toc(part)[1][0] == "Link.lua"

    print("all steps ran")


if __name__ == "__main__":
    main()
