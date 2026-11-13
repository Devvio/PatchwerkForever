"""Run Thread (Tracker) outside the game, on its base, against a stand-in for the game
(wowstub.lua and trackerstub.lua).

    python lua_tracker.py

Plays logins, each in a Lua of its own: the quests you track drawn as a list and kept up to date,
the settings, folding, scrolling, moving it, and the game's own tracker kept quiet (and let back in
a dungeon, never touched in a fight). It fails loudly on any Lua error.

What this proves: the tracker's own code runs and does sensible things with the stand-in's answers.
What it cannot prove: that the game's real quest log and its real tracker answer as the stand-in does,
or how any of it looks.
"""
import os
import re

from pack import ADDONS

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "PatchwerkForever"
TRACKER = "PatchwerkForever_Thread_Tracker"


def toc_files(name):
    folder = os.path.join(ADDONS, name)
    for line in open(os.path.join(folder, name + ".toc"), encoding="utf-8"):
        line = line.strip()
        if line.endswith(".lua"):
            yield os.path.join(folder, line)


class Session:
    """One login: a Lua of its own with the stand-in for the game in it."""

    def __init__(self, before=""):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        for name in ("wowstub.lua", "trackerstub.lua"):
            self.lua.execute(open(os.path.join(HERE, name), encoding="utf-8").read())
        self.g = self.lua.globals()
        self.stub = self.g.STUB
        self.lua.execute(before)
        self.said = 0
        self.tables = {}

    def load(self):
        """The base and the tracker, as the game loads them; then the login."""
        run = self.lua.eval("function(code, name, addon, ns) return assert(loadstring(code, name))(addon, ns) end")
        for addon in (BASE, TRACKER):
            self.tables[addon] = self.lua.table()
            for path in toc_files(addon):
                run(open(path, encoding="utf-8").read(), "@" + addon + "/" + os.path.basename(path), addon, self.tables[addon])
            self.stub.Fire("ADDON_LOADED", addon)
        self.ns = self.tables[TRACKER]
        assert self.ns.linked, "the tracker did not join the base"
        self.stub.Fire("PLAYER_LOGIN")
        self.stub.Fire("PLAYER_ENTERING_WORLD")
        self.turn()
        return self.ns

    def turn(self):
        """Time passes: the timers that were waiting run, and the list is drawn again if it was asked for."""
        self.stub.time += 1
        self.stub.RunAfters()
        self.stub.Frame()

    def shown(self):
        got = self.ns.Shown()
        return None if got is None else list(got.values())

    def chat(self):
        new = list(self.stub.messages.values())[self.said:]
        self.said += len(new)
        new = [re.sub(r"\|c\w{8}|\|r", "", text) for text in new]
        for text in new:
            print("      chat: " + text)
        bad = [t for t in new if "a problem in" in t]
        assert not bad, bad
        return new

    def setting(self, name, value):
        for s in self.stub.settings.values():
            if s.variable == TRACKER + "_" + name:
                s.set(value)
                self.turn()
                return
        raise AssertionError("no setting " + name)

    def slash(self, text):
        self.g.SlashCmdList.PATCHWERKFOREVER_TRACKER(text)
        self.turn()
        return self.chat()


LOG = """
    STUB.Heading('The Barrens')
    STUB.thieves = STUB.Quest({ id = 869, title = 'Raptor Thieves', level = 13, objectives = { { '10/12 Raptor Head', false } } })
    STUB.Quest({ id = 845, title = 'The Zhevra', level = 13, objectives = { { '4/4 Zhevra Hooves', true } }, complete = true,
        ready = 'Return to Sergra Darkthorn at the Crossroads.' })
    STUB.Quest({ id = 870, title = 'The Forgotten Pools', level = 13, objectives = { { 'Explore the waters of the Forgotten Pools', false } } })
    STUB.Heading('Durotar')
    STUB.Quest({ id = 786, title = 'Thwarting Kolkar Aggression', level = 4,
        objectives = { { 'Attack Plan: Valley of Trials destroyed', true }, { 'Attack Plan: Sen\\'jin Village destroyed', false } } })
    STUB.watched = { 869, 845, 786 }
"""


def step(label):
    print("  " + label)


def main():
    step("log in with three quests tracked: a list of them, the game's own tracker quiet")
    s = Session(LOG)
    ns = s.load()
    assert s.chat() == []
    got = s.shown()
    for line in got:
        print("      " + line)
    assert got == ["# Quests | 4/25",
                   "[13] Raptor Thieves", "  - 10/12 Raptor Head",
                   "[13] The Zhevra", "  - Return to Sergra Darkthorn at the Crossroads.",
                   "[4] Thwarting Kolkar Aggression", "  - Attack Plan: Valley of Trials destroyed",
                   "  - Attack Plan: Sen'jin Village destroyed"], got
    frame = s.g.PatchwerkForeverTracker
    assert frame.width == 260 and frame.mouse is False, "the frame takes the mouse, so clicks do not pass through it"
    game = s.stub.gameTracker
    assert ns.Quiet() and game.frame.alpha == 0 and game.frame.shown, "the game's tracker is not quiet (or was hidden)"
    assert game.module.mouse is False and game.block.mouse is False, "a click would still land on the game's tracker"
    assert game.item.mouse is True, "a piece the game protects was touched"
    pages = sorted(s.stub.pages.keys())
    assert pages == ["Thread: Tracker", "Tracker: Look"], pages
    mine = [x for x in s.stub.settings.values() if x.variable.startswith(TRACKER + "_")]
    assert len(mine) == 15 and sum(1 for x in mine if x.page == "Thread: Tracker") == 7, len(mine)
    assert sorted(b.text for b in s.stub.buttons.values()) == ["Move", "Reset"]

    step("the quests change: progress, one done, one no longer tracked, none")
    s.lua.execute("STUB.thieves.objectives[1] = { '12/12 Raptor Head', true }; STUB.thieves.complete = true")
    s.stub.Fire("QUEST_LOG_UPDATE")
    s.turn()
    got = s.shown()
    assert got[1:3] == ["[13] Raptor Thieves", "  - Ready to hand in"], got
    s.lua.execute("STUB.watched = { 845, 870 }")
    s.stub.Fire("QUEST_WATCH_LIST_CHANGED")
    s.turn()
    got = s.shown()
    assert got == ["# Quests | 4/25", "[13] The Zhevra", "  - Return to Sergra Darkthorn at the Crossroads.",
                   "[13] The Forgotten Pools", "  - Explore the waters of the Forgotten Pools"], got
    s.lua.execute("STUB.watched = {}")
    s.stub.Fire("QUEST_WATCH_LIST_CHANGED")
    s.turn()
    assert s.shown() is None, "an empty tracker is still on screen"
    s.lua.execute("STUB.watched = { 869, 845, 786 }; STUB.thieves.objectives[1] = { '10/12 Raptor Head', false }; STUB.thieves.complete = false")
    s.stub.Fire("QUEST_WATCH_LIST_CHANGED")
    s.turn()
    assert len(s.shown()) == 8

    step("settings: no levels, done objectives gone, a failed quest, width and size")
    s.setting("levels", False)
    assert s.shown()[1] == "Raptor Thieves"
    s.setting("doneLines", False)
    assert "  - Attack Plan: Valley of Trials destroyed" not in s.shown() and "  - Attack Plan: Sen'jin Village destroyed" in s.shown()
    s.lua.execute("STUB.thieves.failed = true")
    s.stub.Fire("QUEST_LOG_UPDATE")
    s.turn()
    assert s.shown()[1] == "Raptor Thieves (failed)"
    s.lua.execute("STUB.thieves.failed = nil")
    s.setting("levels", True)
    s.setting("doneLines", True)
    s.setting("width", 400)
    s.setting("scale", 120)
    assert frame.width == 400 and abs(frame.scale - 1.2) < 0.001
    s.setting("width", 260)
    s.setting("scale", 100)
    for key, value in (("titleByLevel", False), ("lookTitle", "ff00ff00"), ("back", 0), ("fontSize", 16), ("fontSize", 12)):
        s.setting(key, value)
    assert s.chat() == []

    step("folding: a click on the heading, the command, the bound key")
    head = [f for f in s.stub.frames.values() if f.kind == "Button" and f.id == "quests"][0]
    head.scripts.OnClick(head)
    s.turn()
    assert s.shown() == ["# Quests | 4/25  +"], s.shown()
    assert s.g.PatchwerkForever_Thread_TrackerDB.folded.quests is True
    s.slash("fold")
    assert len(s.shown()) == 8
    s.g.PatchwerkForever_Thread_Tracker_Fold()
    s.turn()
    assert len(s.shown()) == 1
    s.g.PatchwerkForever_Thread_Tracker_Fold()
    s.turn()

    step("more than fits: it stops growing, and the wheel scrolls it")
    s.lua.execute("""
        for i = 1, 20 do
            STUB.Quest({ id = 2000 + i, title = 'A Long List ' .. i, level = 12, objectives = { { 'something to do', false } } })
            STUB.watched[#STUB.watched + 1] = 2000 + i
        end
    """)
    s.setting("height", 150)
    body = [f for f in s.stub.frames.values() if f.scripts.OnMouseWheel][0]
    content = [f for f in s.stub.frames.values() if f.parent is not None and same(s, f.parent, body)][0]
    assert frame.height == 150 and body.wheel is True, (frame.height, body.wheel)
    assert content.height > 600 and content.points[1][5] == 0
    body.scripts.OnMouseWheel(body, -1)
    s.turn()
    assert content.points[1][5] == 40, "the wheel did not scroll the list"
    for _ in range(60):
        body.scripts.OnMouseWheel(body, -1)
    s.turn()
    assert content.points[1][5] == content.height - 150, "it scrolled past its end"
    for _ in range(60):
        body.scripts.OnMouseWheel(body, 1)
    s.turn()
    assert content.points[1][5] == 0
    s.setting("height", 1000)
    assert body.wheel is False and frame.height == content.height, "the wheel is taken with nothing to scroll"
    s.lua.execute("STUB.watched = { 869, 845, 786 }")
    s.stub.Fire("QUEST_WATCH_LIST_CHANGED")
    s.turn()

    step("moving it: unlocked, dragged, locked; put back")
    handle = [f for f in s.stub.frames.values() if f.scripts.OnDragStart][0]
    assert not handle.shown
    text = s.slash("move")
    assert handle.shown and any("drag it by the bar" in t for t in text)
    handle.scripts.OnDragStart(handle)
    handle.scripts.OnDragStop(handle)
    place = s.g.PatchwerkForever_Thread_TrackerDB.place
    assert list(place.values()) == ["TOPLEFT", "TOPLEFT", 300, -200], list(place.values())
    s.slash("lock")
    assert not handle.shown
    [b for b in s.stub.buttons.values() if b.text == "Move"][0].click()
    s.turn()
    assert handle.shown
    [b for b in s.stub.buttons.values() if b.text == "Move"][0].click()
    s.turn()
    assert not handle.shown
    s.slash("reset")
    assert s.g.PatchwerkForever_Thread_TrackerDB.place is None and frame.points[1][1] == "TOPRIGHT"
    s.chat()

    step("the game's tracker: let back in a dungeon, never touched in a fight, as it was when ours goes")
    s.stub.instance = True
    s.stub.Fire("ZONE_CHANGED_NEW_AREA")
    s.turn()
    assert not ns.Quiet() and game.frame.alpha == 1 and game.block.mouse is True, "not let back in a dungeon"
    s.setting("quietInstance", False)
    assert ns.Quiet() and game.frame.alpha == 0
    s.setting("quietInstance", True)
    s.stub.instance = False
    s.stub.Fire("ZONE_CHANGED_NEW_AREA")
    s.turn()
    assert ns.Quiet() and game.block.mouse is False
    # a new piece of the game's tracker (a quest taken) is quietened too
    s.lua.execute("local b = CreateFrame('Button', nil, STUB.gameTracker.module); b.blizzard = true; STUB.gameTracker.newer = b")
    s.stub.Fire("QUEST_ACCEPTED")
    s.turn()
    assert game.newer.mouse is False
    # in a fight nothing of it is touched; what was asked for is done after
    s.stub.combat = True
    s.setting("quiet", False)
    assert game.frame.alpha == 0 and game.block.mouse is False, "the game's tracker was touched in a fight"
    s.stub.combat = False
    s.stub.Fire("PLAYER_REGEN_ENABLED")
    s.turn()
    assert not ns.Quiet() and game.frame.alpha == 1 and game.block.mouse is True and game.newer.mouse is True
    assert len(s.stub.touchedInCombat) == 0
    s.setting("quiet", True)
    assert ns.Quiet()
    text = s.slash("off")
    assert s.shown() is None and not ns.Quiet() and game.frame.alpha == 1, "switched off, the game's tracker is not as it was"
    text = s.slash("on")
    assert len(s.shown()) == 8 and ns.Quiet()
    s.slash("")
    s.slash("config")
    assert s.stub.opened == 8, "the tracker's own settings page did not open"

    step("EllesmereUI's tracker running too: said once")
    s = Session(LOG + "STUB.loaded = { EllesmereUIQuestTracker = true }")
    s.load()
    text = s.chat()
    assert len(text) == 1 and "EllesmereUI's quest tracker is running too" in text[0], text
    s = Session(LOG + "STUB.loaded = { EllesmereUIQuestTracker = true }; PatchwerkForever_Thread_TrackerDB = { toldOfOther = true }")
    s.load()
    assert s.chat() == []

    step("nothing tracked at login: no tracker, and the game's is still kept quiet for when there is")
    s = Session(LOG + "STUB.watched = {}")
    ns = s.load()
    assert s.shown() is None and ns.Quiet()

    print("all steps ran")


def same(s, a, b):
    return s.lua.eval("function(a, b) return a == b end")(a, b)


if __name__ == "__main__":
    main()
