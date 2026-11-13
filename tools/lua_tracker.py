"""Run Thread (Tracker) outside the game, on its base, against a stand-in for the game
(wowstub.lua and trackerstub.lua).

    python lua_tracker.py

Plays logins, each in a Lua of its own: the quests you track drawn as a list and kept up to date,
their orders, distances, kinds and timers; clicks and the menu; following the nearest quest; the
guide's steps and skipping one; the item buttons, which must not be touched in a fight; recipes; the
party; the gathering list; a dungeon's stages; the fades; the settings, folding, scrolling, moving
it; and the game's own tracker and RestedXP's window kept quiet. It fails loudly on any Lua error.

What this proves: the tracker's own code runs and does sensible things with the stand-in's answers.
What it cannot prove: that the game's real quest log, its real tracker, its secure buttons, RestedXP
or a real party answer as the stand-ins do, or how any of it looks.
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
        """A second passes: the timers that were waiting run, and the list is drawn again if it was asked for."""
        self.stub.time += 1
        self.stub.RunAfters()
        self.stub.Frame()

    def tick(self):
        """Every repeating timer once (the looks taken now and then), then a second passes."""
        self.stub.Tick()
        self.turn()

    def fire(self, event, *args):
        self.stub.Fire(event, *args)
        self.turn()

    def shown(self):
        got = self.ns.Shown()
        return None if got is None else list(got.values())

    def show(self):
        got = self.shown()
        for line in got or ["(nothing shown)"]:
            print("      " + line)
        return got

    def chat(self):
        new = list(self.stub.messages.values())[self.said:]
        self.said += len(new)
        new = [re.sub(r"\|c\w{8}|\|r", "", text) for text in new]
        for text in new:
            print("      chat: " + text)
        bad = [t for t in new if "a problem in" in t or "failed and was skipped" in t]
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

    def block(self, words):
        block = self.ns.BlockOf(words)
        assert block is not None, "nothing shown that says " + words
        return block

    def click(self, words, button="LeftButton"):
        block = self.block(words)
        assert block.mouse is True, words + " does not take a click"
        block.scripts.OnClick(block, button)
        self.turn()

    def items(self):
        strip, nearest = self.ns.ItemsShown()
        return list(strip.values()), nearest

    def button(self, i):
        return self.g["PatchwerkForeverTrackerItem%d" % i]


LOG = """
    STUB.Heading('The Barrens')
    STUB.thieves = STUB.Quest({ id = 869, title = 'Raptor Thieves', level = 13, objectives = { { '10/12 Raptor Head', false, 10, 12 } } })
    STUB.zhevra = STUB.Quest({ id = 845, title = 'The Zhevra', level = 13, objectives = { { '4/4 Zhevra Hooves', true, 4, 4 } }, complete = true,
        ready = 'Return to Sergra Darkthorn at the Crossroads.' })
    STUB.pools = STUB.Quest({ id = 870, title = 'The Forgotten Pools', level = 13, objectives = { { 'Explore the waters of the Forgotten Pools', false } } })
    STUB.Heading('Durotar')
    STUB.kolkar = STUB.Quest({ id = 786, title = 'Thwarting Kolkar Aggression', level = 4,
        objectives = { { 'Attack Plan: Valley of Trials destroyed', true }, { 'Attack Plan: Sen\\'jin Village destroyed', false } } })
    STUB.watched = { 869, 845, 786 }
"""

# where the quests are on the map, and where you stand (the Crossroads)
PLACES = """
    STUB.player.x, STUB.player.y = -450, -2600
    STUB.QuestAt(869, 'Raptor Thieves', 1, -500, -2700)
    STUB.QuestAt(845, 'The Zhevra', 1, -455, -2600)
    STUB.QuestAt(870, 'The Forgotten Pools', 1, -400, -2600)
    STUB.QuestAt(786, 'Thwarting Kolkar Aggression', 1, -900, -4500)
    STUB.watched = { 869, 845, 786, 870 }
"""

# the old, flat list: as the game has them, the ready ones among the rest
FLAT = """
    PatchwerkForever_Thread_TrackerDB = { settings = { order = 'game', readyGroup = false } }
"""

# a stand-in for what RestedXP keeps as it runs, and for its window
RXP = """
    local function at(x, y) return { tag = 'goto', wx = y, wy = x, instance = 1 } end
    local steps = {
        { { tag = 'accept', text = 'Accept Plainstrider Menace', completed = true }, { tag = 'complete', text = 'Kill 7 plainstriders' }, at(-600, -2800) },
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
    steps[1].activeItems = { [6948] = true, [4854] = true }
    RXPCData = { currentStep = 1, stepSkip = {} }
    RXP = { currentGuide = { name = 'raw name', displayname = 'The Barrens 12-14', steps = steps },
        SetStep = function(n) STUB.setStep = n; RXPCData.currentStep = n end }
    RXPG_ARROW = { shown = true, IsShown = function(self) return self.shown end }
    RXPFrame = CreateFrame('Frame', nil, UIParent)
    STUB.rxpPiece = CreateFrame('Button', nil, RXPFrame)
"""


def step(label):
    print("  " + label)


def same(s, a, b):
    return s.lua.eval("function(a, b) return a == b end")(a, b)


def near(a, b):
    return all(abs(x - y) < 0.01 for x, y in zip(a, b))


def main():
    first_login()
    orders_and_detail()
    clicks()
    guide()
    item_buttons()
    recipes()
    party()
    gathering()
    dungeon_and_fades()
    print("all steps ran")


def first_login():
    step("log in with three quests tracked: by zone, the ready one apart; the game's own tracker quiet")
    s = Session(LOG)
    ns = s.load()
    assert s.chat() == []
    got = s.show()
    assert got == ["# Quests | 4/25",
                   "The Barrens", "[13] Raptor Thieves", "  - 10/12 Raptor Head",
                   "Durotar", "[4] Thwarting Kolkar Aggression", "  - Attack Plan: Valley of Trials destroyed",
                   "  - Attack Plan: Sen'jin Village destroyed",
                   "Ready to Turn In", "[13] The Zhevra", "  - Return to Sergra Darkthorn at the Crossroads."], got
    frame = s.g.PatchwerkForeverTracker
    assert frame.width == 260 and frame.mouse is False, "the frame takes the mouse, so clicks do not pass through it"
    assert s.block("Raptor Thieves").mouse is True and s.block("The Barrens").mouse is False, "a quest takes clicks, a zone's name does not"
    game = s.stub.gameTracker
    assert ns.Quiet() and game.frame.alpha == 0 and game.frame.shown, "the game's tracker is not quiet (or was hidden)"
    assert game.module.mouse is False and game.block.mouse is False, "a click would still land on the game's tracker"
    assert game.item.mouse is True, "a piece the game protects was touched"
    pages = sorted(s.stub.pages.keys())
    assert pages == ["Thread: Tracker", "Tracker: Appearance", "Tracker: Guide", "Tracker: More", "Tracker: Quests"], pages
    mine = [x for x in s.stub.settings.values() if x.variable.startswith(TRACKER + "_")]
    count = {page: sum(1 for x in mine if x.page == page) for page in pages}
    assert count == {"Thread: Tracker": 9, "Tracker: Quests": 12, "Tracker: Guide": 6, "Tracker: More": 7, "Tracker: Appearance": 9}, count
    assert sorted(b.text for b in s.stub.buttons.values()) == ["Reset", "Unlock"]
    # each page opens with its name and a line in Patchwerk's voice, and is grouped under stitched headings
    heads = list(s.stub.headers.values())
    assert heads == ["General", "Size", "Position", "Fading", "Quest List", "Quest Details", "Party",
                     "Automation", "Quest Item Bar", "Recipes", "Gathering", "Dungeons", "Size", "Colors"], heads
    intros = {i.name: i.voice for i in s.stub.intros.values()}
    assert sorted(intros) == pages and intros["Tracker: Quests"] == "So many jobs. Patchwerk does the near one first.", intros
    assert s.stub.Rows() == 19, "a row of our own could not be made"
    names = [x.name for x in mine]
    assert "Hide Default Quest Tracker" in names and "Font Size" in names and "Hide RestedXP Window" in names, names

    # a client that does not know our rows (their XML not read): the game's own headings, no intro, no error
    s2 = Session(LOG + "STUB.noRows = true")
    s2.load()
    assert s2.chat() == [] and len(s2.stub.rows) == 0 and len(s2.stub.settings) == len(s.stub.settings)
    assert list(s2.stub.headers.values())[:2] == ["General", "Size"], "the game's own headings were not used"
    # what changes something of the game's or another addon's by itself, and what steps back, starts off
    for key in ("followNearest", "guideHide", "dungeon", "fadeCombat", "fadeIdle", "hideInstance"):
        assert ns.Get(key) is False, key + " is on to begin with"
    assert s.items() == ([], None) and s.g.PatchwerkForeverTrackerNearestItem.attributes.type is None

    s = Session(LOG + FLAT)
    ns = s.load()
    frame, game = s.g.PatchwerkForeverTracker, s.stub.gameTracker
    assert len(s.shown()) == 8

    step("the quests change: progress, one done, one no longer tracked, none")
    s.lua.execute("STUB.thieves.objectives[1] = { '12/12 Raptor Head', true, 12, 12 }; STUB.thieves.complete = true")
    s.fire("QUEST_LOG_UPDATE")
    got = s.shown()
    assert got[1:3] == ["[13] Raptor Thieves", "  - Ready to turn in"], got
    s.lua.execute("STUB.watched = { 845, 870 }")
    s.fire("QUEST_WATCH_LIST_CHANGED")
    got = s.shown()
    assert got == ["# Quests | 4/25", "[13] The Zhevra", "  - Return to Sergra Darkthorn at the Crossroads.",
                   "[13] The Forgotten Pools", "  - Explore the waters of the Forgotten Pools"], got
    s.lua.execute("STUB.watched = {}")
    s.fire("QUEST_WATCH_LIST_CHANGED")
    assert s.shown() is None, "an empty tracker is still on screen"
    s.lua.execute("STUB.watched = { 869, 845, 786 }; STUB.thieves.objectives[1] = { '10/12 Raptor Head', false, 10, 12 }; STUB.thieves.complete = false")
    s.fire("QUEST_WATCH_LIST_CHANGED")
    assert len(s.shown()) == 8

    step("settings: no levels, done objectives gone, a failed quest, width and size, no quests at all")
    s.setting("levels", False)
    assert s.shown()[1] == "Raptor Thieves"
    s.setting("doneLines", False)
    assert "  - Attack Plan: Valley of Trials destroyed" not in s.shown() and "  - Attack Plan: Sen'jin Village destroyed" in s.shown()
    s.lua.execute("STUB.thieves.failed = true")
    s.fire("QUEST_LOG_UPDATE")
    assert s.shown()[1] == "Raptor Thieves (Failed)"
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
    s.setting("quests", False)
    assert s.shown() is None
    s.setting("quests", True)
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
    s.fire("QUEST_WATCH_LIST_CHANGED")

    step("moving it: unlocked, dragged, locked; put back")
    handle = [f for f in s.stub.frames.values() if f.scripts.OnDragStart][0]
    assert not handle.shown
    text = s.slash("move")
    assert handle.shown and any("Drag the bar above the tracker" in t for t in text)
    handle.scripts.OnDragStart(handle)
    handle.scripts.OnDragStop(handle)
    place = s.g.PatchwerkForever_Thread_TrackerDB.place
    assert list(place.values()) == ["TOPLEFT", "TOPLEFT", 300, -200], list(place.values())
    s.slash("lock")
    assert not handle.shown
    [b for b in s.stub.buttons.values() if b.text == "Unlock"][0].click()
    s.turn()
    assert handle.shown
    [b for b in s.stub.buttons.values() if b.text == "Unlock"][0].click()
    s.turn()
    assert not handle.shown
    s.slash("reset")
    assert s.g.PatchwerkForever_Thread_TrackerDB.place is None and frame.points[1][1] == "TOPRIGHT"
    s.chat()

    step("the game's tracker: let back in a dungeon, never touched in a fight, as it was when ours goes")
    s.stub.instance = True
    s.fire("ZONE_CHANGED_NEW_AREA")
    assert not ns.Quiet() and game.frame.alpha == 1 and game.block.mouse is True, "not let back in a dungeon"
    s.setting("quietInstance", False)
    assert ns.Quiet() and game.frame.alpha == 0
    s.setting("quietInstance", True)
    s.stub.instance = False
    s.fire("ZONE_CHANGED_NEW_AREA")
    assert ns.Quiet() and game.block.mouse is False
    # a new piece of the game's tracker (a quest taken) is quietened too
    s.lua.execute("local b = CreateFrame('Button', nil, STUB.gameTracker.module); b.blizzard = true; STUB.gameTracker.newer = b")
    s.fire("QUEST_ACCEPTED")
    assert game.newer.mouse is False
    # something makes it visible again: seen at the next look, and quietened again
    game.frame.alpha = 1
    s.tick()
    assert game.frame.alpha == 0, "the game's tracker came back and was left"
    # in a fight nothing of it is touched; what was asked for is done after
    s.stub.combat = True
    s.setting("quiet", False)
    assert game.frame.alpha == 0 and game.block.mouse is False, "the game's tracker was touched in a fight"
    s.stub.combat = False
    s.fire("PLAYER_REGEN_ENABLED")
    assert not ns.Quiet() and game.frame.alpha == 1 and game.block.mouse is True and game.newer.mouse is True
    assert len(s.stub.touchedInCombat) == 0
    s.setting("quiet", True)
    assert ns.Quiet()
    s.slash("off")
    assert s.shown() is None and not ns.Quiet() and game.frame.alpha == 1, "switched off, the game's tracker is not as it was"
    s.slash("on")
    assert len(s.shown()) == 8 and ns.Quiet()
    text = s.slash("")
    assert any("/tracker back" in t for t in text)
    s.slash("config")
    assert s.stub.opened == 8, "the tracker's own settings page did not open"

    step("EllesmereUI's tracker running too: said once")
    s = Session(LOG + "STUB.loaded = { EllesmereUIQuestTracker = true }")
    s.load()
    text = s.chat()
    assert len(text) == 1 and "EllesmereUI's quest tracker is also enabled" in text[0], text
    s = Session(LOG + "STUB.loaded = { EllesmereUIQuestTracker = true }; PatchwerkForever_Thread_TrackerDB = { toldOfOther = true }")
    s.load()
    assert s.chat() == []

    step("nothing tracked at login: no tracker, and the game's is still kept quiet for when there is")
    s = Session(LOG + "STUB.watched = {}")
    ns = s.load()
    assert s.shown() is None and ns.Quiet()


def orders_and_detail():
    step("where the quests are: distances, the zone you are in first, nearest first within it")
    s = Session(LOG + PLACES)
    ns = s.load()
    got = s.show()
    assert got == ["# Quests | 4/25",
                   "The Barrens", "[13] The Forgotten Pools | 50 yd", "  - Explore the waters of the Forgotten Pools",
                   "[13] Raptor Thieves | 112 yd", "  - 10/12 Raptor Head",
                   "Durotar", "[4] Thwarting Kolkar Aggression | 1953 yd", "  - Attack Plan: Valley of Trials destroyed",
                   "  - Attack Plan: Sen'jin Village destroyed",
                   "Ready to Turn In", "[13] The Zhevra | 5 yd", "  - Return to Sergra Darkthorn at the Crossroads."], got
    # you walk: the distances follow by themselves, with no event of the game
    s.stub.player.x = -480
    s.turn()
    assert "[13] The Forgotten Pools | 80 yd" in s.shown(), s.shown()
    s.stub.player.x = -450
    s.stub.zone = "Durotar"
    s.fire("ZONE_CHANGED_NEW_AREA")
    got = s.shown()
    assert got[1:3] == ["Durotar", "[4] Thwarting Kolkar Aggression | 1953 yd"] and got[5] == "The Barrens", got
    s.stub.zone = "The Barrens"

    step("the other orders: nearest first; ready first; as the game has them")
    s.setting("order", "near")
    titles = [t for t in s.shown() if t.startswith("[")]
    assert titles == ["[13] The Forgotten Pools | 50 yd", "[13] Raptor Thieves | 112 yd", "[4] Thwarting Kolkar Aggression | 1953 yd",
                      "[13] The Zhevra | 5 yd"], titles
    assert "The Barrens" not in s.shown() and "Ready to Turn In" in s.shown()
    s.setting("readyGroup", False)
    titles = [t for t in s.shown() if t.startswith("[")]
    assert titles[0] == "[13] The Zhevra | 5 yd" and "Ready to Turn In" not in s.shown(), titles
    s.setting("order", "ready")
    got = s.shown()
    assert got[1] == "[13] The Zhevra | 5 yd" and got[3] == "The Barrens" and "Durotar" in got, got
    s.setting("order", "game")
    titles = [t for t in s.shown() if t.startswith("[")]
    assert [t.split(" | ")[0] for t in titles] == ["[13] Raptor Thieves", "[13] The Zhevra", "[4] Thwarting Kolkar Aggression",
                                                   "[13] The Forgotten Pools"], titles
    s.setting("distance", False)
    assert "[13] Raptor Thieves" in s.shown()
    s.setting("distance", True)
    s.setting("order", "zone")
    s.setting("readyGroup", True)

    step("the kind of quest, a timed quest's time, counts coloured by progress")
    s.lua.execute("STUB.thieves.tag = '(Elite)'; STUB.pools.daily = true; STUB.kolkar.group = 3; STUB.thieves.timed = { 600, 540 }")
    s.fire("QUEST_LOG_UPDATE")
    got = s.show()
    assert "[13] Raptor Thieves (Elite) | 112 yd" in got and "[13] The Forgotten Pools (Daily) | 50 yd" in got
    assert "[4] Thwarting Kolkar Aggression (Group) | 1953 yd" in got and "  - Time left: 1:00" in got, got
    s.lua.execute("STUB.thieves.timed[2] = 541")
    s.turn()
    assert "  - Time left: 0:59" in s.shown(), "the clock does not run by itself"
    s.setting("kinds", False)
    assert "[13] Raptor Thieves | 112 yd" in s.shown() and "  - Time left: 0:59" in s.shown()
    s.setting("kinds", True)
    s.lua.execute("STUB.thieves.timed = nil")
    line = s.block("Raptor Thieves").lines[1]
    plain = list(ns.RGB(ns.Get("lookLine")))
    assert line.text == "- 10/12 Raptor Head" and not near(list(line.colour.values()), plain), "a count is not coloured by its progress"
    assert list(line.colour.values())[1] > 0.8, "ten of twelve is not nearly green"
    s.setting("progress", False)
    assert near(list(s.block("Raptor Thieves").lines[1].colour.values()), plain)
    s.setting("progress", True)

    step("a flash on the quest whose progress changes, and only on that one")
    s.lua.execute("STUB.thieves.objectives[1] = { '11/12 Raptor Head', false, 11, 12 }")
    s.fire("QUEST_LOG_UPDATE")
    assert s.block("Raptor Thieves").glow.shown is True, "no flash on a quest that changed"
    assert not s.block("Forgotten Pools").glow.shown
    s.turn()
    assert not s.block("Raptor Thieves").glow.shown, "the flash did not end"
    s.setting("flash", False)
    s.lua.execute("STUB.thieves.objectives[1] = { '12/12 Raptor Head', false, 12, 12 }")
    s.fire("QUEST_LOG_UPDATE")
    assert not s.block("Raptor Thieves").glow.shown
    assert s.chat() == []


def clicks():
    step("a click chooses a quest (a side path, and the game's arrow), a second goes back; shift-click reads it")
    s = Session(LOG + PLACES)
    ns = s.load()
    Choice = s.g.PatchwerkForever.Choice
    s.click("Raptor Thieves")
    assert Choice.Is(Choice, "quest", 869) and s.stub.focus == 869 and "> [13] Raptor Thieves | 112 yd" in s.shown(), s.shown()
    s.click("The Zhevra")
    assert Choice.Is(Choice, "quest", 845) and s.stub.focus == 845
    assert "> [13] The Zhevra | 5 yd" in s.shown() and "[13] Raptor Thieves | 112 yd" in s.shown()
    s.click("The Zhevra")
    assert Choice.Get(Choice) is None and s.stub.focus == 0 and not any(t.startswith(">") for t in s.shown())
    # the game's arrow on a quest by another hand (the map): marked, but not a choice; a click makes it one
    s.lua.execute("STUB.focus = 869")
    s.fire("SUPER_TRACKING_CHANGED")
    assert "> [13] Raptor Thieves | 112 yd" in s.shown() and Choice.Get(Choice) is None
    s.click("Raptor Thieves")
    assert Choice.Is(Choice, "quest", 869) and s.stub.focus == 869
    s.click("Raptor Thieves")
    assert Choice.Get(Choice) is None and s.stub.focus == 0
    s.stub.shift = True
    s.click("Raptor Thieves")
    assert s.stub.read == 869 and s.stub.focus == 0
    s.stub.read, s.stub.combat = None, True
    s.click("Raptor Thieves")
    text = s.chat()
    assert s.stub.read is None and any("in combat" in t for t in text), "a quest was opened in a fight"
    s.stub.shift, s.stub.combat = False, False

    step("a right-click: a menu to follow, read, share, stop tracking, abandon")
    s.click("Raptor Thieves", "RightButton")
    menu = s.stub.menu
    assert menu.title == "Raptor Thieves" and s.stub.focus == 0
    assert [e.text for e in menu.entries.values()] == ["Route To Quest", "Quest Details", "Untrack Quest", "Abandon Quest"]
    s.stub.Press("Route To Quest")
    assert s.stub.focus == 869 and Choice.Is(Choice, "quest", 869)
    s.stub.Press("Quest Details")
    assert s.stub.read == 869
    s.stub.Press("Abandon Quest")
    assert s.stub.abandonAsked == 869, "the game's own question was not asked"
    # in a party, a quest that can be shared
    s.lua.execute("STUB.party = { { name = 'Thrag', quests = {} } }; STUB.thieves.pushable = true")
    s.turn()
    s.click("Raptor Thieves", "RightButton")
    assert [e.text for e in s.stub.menu.entries.values()] == ["Stop Routing To Quest", "Quest Details", "Share Quest",
                                                              "Untrack Quest", "Abandon Quest"]
    s.stub.Press("Share Quest")
    assert s.stub.shared == 869
    s.stub.Press("Untrack Quest")
    s.turn()
    assert 869 not in list(s.stub.watched.values()) and s.stub.focus == 0 and not ns.BlockOf("Raptor Thieves")
    assert Choice.Get(Choice) is None, "a quest no longer tracked is still the choice"
    s.lua.execute("STUB.party = {}; STUB.watched = { 869, 845, 786, 870 }")
    s.fire("QUEST_WATCH_LIST_CHANGED")
    # a client with no menu for addons: said once, no error
    s.lua.execute("MenuUtil = nil")
    s.click("Raptor Thieves", "RightButton")
    s.click("Raptor Thieves", "RightButton")
    text = s.chat()
    assert len([t for t in text if "Right-click menus are not available" in t]) == 1, text

    step("following the nearest quest by itself: only when asked, never over a quest you chose")
    assert s.stub.focus == 0
    s.tick()
    assert s.stub.focus == 0, "the game's arrow was moved without being asked"
    s.setting("followNearest", True)
    s.tick()
    assert s.stub.focus == 845 and ns.AutoFollowed() == 845, "the nearest quest was not followed"
    # another becomes nearer, but only just: the arrow stays; clearly nearer: it moves
    s.lua.execute("STUB.QuestAt(870, 'The Forgotten Pools', 1, -454.5, -2600)")
    s.stub.time += 10
    s.tick()
    assert s.stub.focus == 845, "the arrow jumps between two quests as near as each other"
    s.lua.execute("STUB.QuestAt(870, 'The Forgotten Pools', 1, -451, -2600)")
    s.stub.time += 10
    s.tick()
    assert s.stub.focus == 870
    # a quest you click is yours: left alone
    s.click("Raptor Thieves")
    s.tick()
    assert s.stub.focus == 869 and ns.AutoFollowed() is None
    s.click("Raptor Thieves")
    s.tick()
    assert s.stub.focus == 870, "with your own choice gone, the nearest was not followed again"
    s.setting("followNearest", False)
    s.lua.execute("STUB.focus = 0")
    s.tick()
    assert s.stub.focus == 0
    assert s.chat() == []


def guide():
    step("a guide running: the step you are on, the steps after it dimmed, its name and how far through")
    s = Session(LOG + RXP)
    ns = s.load()
    got = s.show()
    assert got[:6] == ["# The Barrens 12-14 | Step 1 of 5", "# Quests | 4/25",
                       "> Step 1", "  - Kill 7 plainstriders",
                       "2. Fly to Orgrimmar", "3. Train your skills"], got
    assert got[6] == "4. Hearth to the Crossroads" and got[7] == "The Barrens", got
    head = [f for f in s.stub.frames.values() if f.kind == "Button" and f.id == "guide"][0]
    assert head.bar.shown, "no bar of how far through the guide you are"
    s.setting("guideDone", True)
    assert s.shown()[3:5] == ["  - Accept Plainstrider Menace", "  - Kill 7 plainstriders"]
    s.setting("guideDone", False)
    s.setting("guideAhead", 1)
    assert "3. Train your skills" not in s.shown() and "2. Fly to Orgrimmar" in s.shown()
    s.setting("guideAhead", 3)
    # the guide moves on by itself (you did the step): seen with no event of the game
    s.lua.execute("RXPCData.currentStep = 2")
    s.turn()
    got = s.shown()
    assert got[0] == "# The Barrens 12-14 | Step 2 of 5" and got[2:4] == ["> Step 2", "  - Fly to Orgrimmar"], got
    s.lua.execute("RXPCData.currentStep = 1")
    s.turn()

    step("a click on the step skips it; on a later one goes to it; /tracker back takes it back")
    s.click("Step 1")
    assert s.stub.setStep == 2 and "> Step 2" in s.shown()
    text = s.slash("back")
    assert s.stub.setStep == 1 and "> Step 1" in s.shown() and any("Back to step 1" in t for t in text)
    text = s.slash("back")
    assert any("No skipped step" in t for t in text)
    s.click("4. Hearth")
    assert s.stub.setStep == 4 and "> Step 4" in s.shown() and "5. Turn in your report" in s.shown()
    s.click("Step 4", "RightButton")
    assert [e.text for e in s.stub.menu.entries.values()] == ["Skip Step", "Previous Step"]
    s.stub.Press("Previous Step")
    s.turn()
    assert s.stub.setStep == 3
    s.lua.execute("RXPCData.currentStep = 5")
    s.turn()
    s.click("Step 5")
    text = s.chat()
    assert s.stub.setStep == 3 and any("could not jump" in t for t in text), "the guide was moved past its end"
    s.lua.execute("RXPCData.currentStep = 1")
    s.turn()
    s.setting("guideSkip", False)
    assert s.block("Step 1").mouse is False, "a step takes clicks with skipping switched off"
    s.setting("guideSkip", True)

    step("the guide is the main track: a quest you click takes its mark, a second click gives it back")
    Choice = s.g.PatchwerkForever.Choice
    s.lua.execute("STUB.focus = 845")                     # (the game's arrow somewhere by itself: the guide still leads)
    s.fire("SUPER_TRACKING_CHANGED")
    marked = [t for t in s.shown() if t.startswith(">")]
    assert marked == ["> Step 1"], marked
    s.click("Raptor Thieves")
    marked = [t for t in s.shown() if t.startswith(">")]
    assert marked == ["> [13] Raptor Thieves"] and Choice.Is(Choice, "quest", 869), marked
    s.click("Raptor Thieves")
    marked = [t for t in s.shown() if t.startswith(">")]
    assert marked == ["> Step 1"] and Choice.Get(Choice) is None and s.stub.focus == 0, marked
    # handed in while chosen: the guide leads again
    s.click("Raptor Thieves")
    s.lua.execute("table.remove(STUB.log, 2); STUB.watched = { 845, 786 }")
    s.fire("QUEST_REMOVED")
    assert [t for t in s.shown() if t.startswith(">")] == ["> Step 1"] and Choice.Get(Choice) is None
    s.lua.execute("table.insert(STUB.log, 2, STUB.thieves); STUB.watched = { 869, 845, 786 }")
    s.fire("QUEST_ACCEPTED")

    step("RestedXP's own window: left alone until asked, then quiet while the guide is listed")
    window, piece = s.g.RXPFrame, s.stub.rxpPiece
    s.tick()
    assert not ns.Quiet("RXPFrame") and window.alpha in (None, 1) and piece.mouse is True, "RestedXP's window was touched unasked"
    s.setting("guideHide", True)
    assert ns.Quiet("RXPFrame") and window.alpha == 0 and piece.mouse is False
    s.setting("guide", False)
    assert not ns.Quiet("RXPFrame") and window.alpha == 1 and piece.mouse is True, "the guide is not listed, yet its window is hidden"
    assert s.shown()[0] == "# Quests | 4/25"
    s.setting("guide", True)
    assert ns.Quiet("RXPFrame")
    # the guide ends: its window comes back at the next look
    s.lua.execute("STUB.rxp = RXP; RXP = nil")
    s.tick()
    s.turn()
    assert not ns.Quiet("RXPFrame") and window.alpha == 1 and s.shown()[0] == "# Quests | 4/25"
    s.lua.execute("RXP = STUB.rxp")
    s.tick()
    s.turn()
    assert ns.Quiet("RXPFrame") and s.shown()[0].startswith("# The Barrens 12-14")
    s.setting("guideHide", False)
    assert window.alpha == 1 and piece.mouse is True
    assert s.chat() == []


def item_buttons():
    step("quest items: a strip of buttons beside the tracker, the nearest quest's first, then the guide's")
    items = """
        STUB.thieves.item = { 4854, false }
        STUB.zhevra.item = { 5000, false }
        STUB.kolkar.item = { 6000, true }
        STUB.bags[6948] = 1
    """
    s = Session(LOG + PLACES + RXP + items)
    ns = s.load()
    # (the Zhevra is done and its item is not for a done quest; the guide's 4854 is the quest's already)
    assert s.items() == ([4854, 6000, 6948], 4854), s.items()
    first, second = s.button(1), s.button(2)
    assert first.attributes.type == "item" and first.attributes.item == "item:4854" and first.shown
    assert list(first.points[1].values())[0] == "TOPLEFT" and same(s, first.points[1][2], s.g.UIParent)
    assert (first.points[1][4], first.points[1][5]) == (764, 700), (first.points[1][4], first.points[1][5])
    assert (second.points[1][4], second.points[1][5]) == (764, 664) and first.width == 32
    binding = s.g.PatchwerkForeverTrackerNearestItem
    assert binding.attributes.type == "item" and binding.attributes.item == "item:4854" and not binding.shown
    assert list(first.clicks.values()) == ["AnyUp", "AnyDown"]
    assert s.g["BINDING_NAME_CLICK PatchwerkForeverTrackerNearestItem:LeftButton"] == "Use Nearest Quest Item"
    s.setting("itemSide", "right")
    s.setting("itemSize", 40)
    assert (first.points[1][4], first.points[1][5]) == (1064, 700) and (second.points[1][5], first.width) == (656, 40)
    s.setting("itemSide", "left")
    s.setting("itemSize", 32)
    s.lua.execute("STUB.cooling[6000] = { 100, 30 }; STUB.bags[6948] = 3")
    s.fire("BAG_UPDATE_COOLDOWN")
    assert second.cool.cooling is not None and first.cool.cooling is None and s.button(3).count.text == "3"

    step("in a fight nothing of the buttons is touched; what changed is applied after it")
    s.stub.combat = True
    s.lua.execute("STUB.thieves.complete = true; STUB.thieves.item = nil")
    s.fire("QUEST_LOG_UPDATE")
    s.setting("itemSize", 44)
    s.setting("itemSide", "right")
    s.fire("BAG_UPDATE_COOLDOWN")
    s.slash("off")
    assert s.items() == ([4854, 6000, 6948], 4854) and first.width == 32, "the strip changed in a fight"
    s.slash("on")
    assert list(s.stub.secureInCombat.values()) == [], list(s.stub.secureInCombat.values())
    s.stub.combat = False
    s.fire("PLAYER_REGEN_ENABLED")
    assert s.items() == ([6000, 6948], 6000) and first.width == 44 and first.attributes.item == "item:6000"
    assert first.points[1][4] == 1064
    s.setting("itemSize", 32)
    s.setting("itemSide", "left")

    step("only the guide's item left: a button for it, but the binding uses nothing")
    s.lua.execute("STUB.kolkar.item = nil")
    s.fire("QUEST_LOG_UPDATE")
    assert s.items() == ([6948], None) and binding.attributes.type is None and binding.attributes.item is None
    s.setting("guideItems", False)
    assert s.items() == ([], None) and not first.shown
    s.setting("guideItems", True)
    s.lua.execute("STUB.kolkar.item = { 6000, true }")
    s.fire("QUEST_LOG_UPDATE")
    assert s.items() == ([6000, 6948], 6000)
    # the tracker gone: the strip goes, the binding keeps its item; the buttons switched off: both go
    s.slash("fold")
    assert s.items() == ([6000, 6948], 6000)
    s.slash("fold")
    s.setting("hideInstance", True)
    s.stub.instance = True
    s.fire("ZONE_CHANGED_NEW_AREA")
    assert s.shown() is None and s.items() == ([], 6000), s.items()
    s.stub.instance = False
    s.fire("ZONE_CHANGED_NEW_AREA")
    s.setting("items", False)
    assert s.items() == ([], None) and first.attributes.type is None
    assert list(s.stub.secureInCombat.values()) == []
    assert s.chat() == []


def recipes():
    step("a recipe you track: what it needs and what you have; a click opens it, the menu stops tracking it")
    s = Session(LOG + """
        STUB.recipes = { { id = 3275, name = 'Linen Bandage', needs = { { 2589, 1 }, { 2320, 2 } } } }
        STUB.bags[2320] = 1
        STUB.itemNames[2320] = 'Coarse Thread'
    """)
    s.load()
    got = s.show()
    assert got[:2] == ["# Quests | 4/25", "# Recipes | 1"], got
    assert got[-3:] == ["Linen Bandage", "  - 0/1 item 2589", "  - 1/2 Coarse Thread"], got
    assert s.stub.askedFor == 2589, "the game was not asked for the item's name"
    s.lua.execute("STUB.itemNames[2589] = 'Linen Cloth'; STUB.bags[2589] = 3")
    s.fire("GET_ITEM_INFO_RECEIVED", 2589, True)
    assert s.shown()[-2] == "  - 3/1 Linen Cloth", s.shown()
    s.lua.execute("STUB.bags[2320] = 2")
    s.fire("BAG_UPDATE_DELAYED")
    assert s.shown()[-1] == "  - 2/2 Coarse Thread"
    s.click("Linen Bandage")
    assert s.stub.openedRecipe == 3275
    s.click("Linen Bandage", "RightButton")
    assert [e.text for e in s.stub.menu.entries.values()] == ["Open Recipe", "Untrack Recipe"]
    s.stub.Press("Untrack Recipe")
    s.turn()
    assert s.shown()[:2] == ["# Quests | 4/25", "The Barrens"], "a recipe no longer tracked is still listed"
    s.lua.execute("STUB.recipes = { { id = 3275, name = 'Linen Bandage', needs = { { 2589, 1 } } } }")
    s.fire("TRACKED_RECIPE_UPDATE")
    assert "# Recipes | 1" in s.shown()
    s.setting("recipes", False)
    assert "# Recipes | 1" not in s.shown()
    assert s.chat() == []


def party():
    step("the party: who has the quest; how far along, for those whose tracker says")
    s = Session(LOG + "STUB.party = { { name = 'Thrag', quests = { [869] = true } }, { name = 'Mokra', quests = {} } }")
    s.load()
    got = s.show()
    assert got[2:5] == ["[13] Raptor Thieves", "  - 10/12 Raptor Head", "  - With Thrag"], got
    assert not any("Mokra" in t for t in got)
    # this tracker tells the party's how far along you are: once, and again only when it changes
    assert list(s.stub.told.values()) == ["n869:83,845:100,786:50"], list(s.stub.told.values())
    s.fire("QUEST_LOG_UPDATE")
    s.turn()
    assert len(s.stub.told) == 1, "the same was told twice"
    s.lua.execute("STUB.thieves.objectives[1] = { '11/12 Raptor Head', false, 11, 12 }")
    s.fire("QUEST_LOG_UPDATE")
    s.turn()
    assert list(s.stub.told.values())[1] == "n869:91,845:100,786:50"
    # theirs tell this one
    s.fire("CHAT_MSG_ADDON", "PFTracker", "n869:40,786:10", "PARTY", "Thrag-Somewhere")
    s.fire("CHAT_MSG_ADDON", "PFTracker", "m845:100", "PARTY", "Mokra")
    got = s.shown()
    assert "  - With Thrag 40%" in got and "  - With Thrag 10%" in got and "  - With Mokra 100%" not in got, got
    # (the ready group is brief: no party line there)
    s.setting("readyGroup", False)
    assert "  - With Mokra 100%" in s.shown()
    s.setting("readyGroup", True)
    # not from yourself, not from another channel, not another addon's
    s.fire("CHAT_MSG_ADDON", "PFTracker", "n869:99", "PARTY", "Walker")
    s.fire("CHAT_MSG_ADDON", "PFTracker", "n869:98", "GUILD", "Thrag")
    s.fire("CHAT_MSG_ADDON", "Other", "n869:97", "PARTY", "Thrag")
    assert "  - With Thrag 40%" in s.shown()
    # sharing unticked: names only, and nothing told
    told = len(s.stub.told)
    s.setting("partyShare", False)
    assert "  - With Thrag" in s.shown() and "  - With Thrag 40%" not in s.shown()
    s.lua.execute("STUB.thieves.objectives[1] = { '12/12 Raptor Head', false, 12, 12 }")
    s.fire("QUEST_LOG_UPDATE")
    s.turn()
    assert len(s.stub.told) == told, "progress was told with sharing unticked"
    s.setting("party", False)
    assert not any("With" in t for t in s.shown())
    s.setting("party", True)
    s.stub.raid = True
    s.fire("GROUP_ROSTER_UPDATE")
    assert not any("With" in t for t in s.shown()), "party lines in a raid"
    # a long list of quests is told in pieces that fit a message
    s.stub.raid = False
    s.setting("partyShare", True)
    s.lua.execute("""
        for i = 1, 40 do
            STUB.Quest({ id = 100000 + i, title = 'A Long List ' .. i, level = 12, objectives = { { 'something to do', false } } })
            STUB.watched[#STUB.watched + 1] = 100000 + i
        end
    """)
    told = len(s.stub.told)
    s.fire("GROUP_ROSTER_UPDATE")
    s.turn()
    new = list(s.stub.told.values())[told:]
    assert len(new) >= 2 and new[0].startswith("n") and all(t.startswith("m") for t in new[1:]), new
    assert sum(t.count(":") for t in new) == 43
    assert s.chat() == []


def gathering():
    step("gathering: no list without Thread (Routes); with it, the nearest spots, a click away")
    s = Session(LOG)
    ns = s.load()
    assert "# Gathering | " not in s.shown() and not any("Gathering" in t for t in s.shown())
    s.lua.execute("""
        local state
        STUB.near = { { name = 'Peacebloom', kind = 'h', yards = 40.2 }, { name = 'Copper Vein', kind = 'o', yards = 210 } }
        PatchwerkForever.Gather:Offer({
            Near = function(count)
                local out = {}
                for i = 1, math.min(count, #STUB.near) do out[i] = STUB.near[i] end
                return out
            end,
            Start = function(mode, name) state = { mode = mode, name = name, going = name or 'Copper Vein' }; return true end,
            Stop = function() state = nil end,
            State = function() return state end,
        })
    """)
    s.turn()
    s.fire("QUEST_LOG_UPDATE")
    got = s.show()
    assert got[:2] == ["# Quests | 4/25", "# Gathering | "], got
    assert got[-4:] == ["Nearest Node (Any Type)", "Farm Nearby Nodes", "Peacebloom | 40 yd", "Copper Vein | 210 yd"], got
    Choice = s.g.PatchwerkForever.Choice
    s.click("Raptor Thieves")
    assert Choice.Is(Choice, "quest", 869)
    s.click("Peacebloom")
    got = s.shown()
    assert got[1] == "# Gathering | To Peacebloom" and "> Peacebloom | 40 yd" in got, got
    assert Choice.Get(Choice) is None and "[13] Raptor Thieves" in got, "a gathering run left the chosen quest marked"
    s.click("Raptor Thieves")
    assert "> [13] Raptor Thieves" in s.shown() and "Peacebloom | 40 yd" in s.shown(), "choosing a quest left the run on"
    s.click("Peacebloom")
    s.lua.execute("STUB.near[1].yards = 12")
    s.turn()
    assert "> Peacebloom | 12 yd" in s.shown(), "the distances do not follow by themselves"
    s.click("Nearest Node (Any")
    got = s.shown()
    assert "> Nearest Node (Any Type)" in got and "Peacebloom | 12 yd" in got and got[1] == "# Gathering | To Copper Vein", got
    s.click("Farm Nearby")
    assert "> Farm Nearby Nodes" in s.shown()
    s.click("Farm Nearby")
    assert not any(t.startswith(">") for t in s.shown()) and s.shown()[1] == "# Gathering | ", "a second click did not stop it"
    s.setting("gatherMost", 1)
    assert "Copper Vein | 210 yd" not in s.shown() and "Peacebloom | 12 yd" in s.shown()
    s.lua.execute("STUB.near = {}")
    s.turn()
    assert not any("Gathering" in t for t in s.shown()), "a gathering list with no spots near"
    s.lua.execute("STUB.near = { { name = 'Peacebloom', kind = 'h', yards = 12 } }")
    s.turn()
    s.setting("gather", False)
    assert not any("Gathering" in t for t in s.shown())
    assert s.chat() == []


def dungeon_and_fades():
    step("a place run in stages: listed only when asked for")
    s = Session(LOG + """
        STUB.scenario = { name = 'Ragefire Chasm', stage = 1, stages = 3, stageName = 'The Way Down',
            criteria = { { 'Troggs slain', 4, 10, false }, { 'Find Oggleflint', 0, 1, false, 300, 60 }, { 'Enter', 1, 1, true } } }
    """)
    ns = s.load()
    assert s.shown()[0] == "# Quests | 4/25", "the dungeon's stages are listed unasked"
    s.setting("dungeon", True)
    got = s.show()
    assert got[:2] == ["# Ragefire Chasm | Stage 1 of 3", "# Quests | 4/25"], got
    assert got[2:7] == ["The Way Down", "  - 4/10 Troggs slain", "  - Find Oggleflint", "  - Time left: 4:00", "  - Enter"], got
    s.lua.execute("STUB.scenario.criteria[1][2] = 5; STUB.scenario.criteria[2][6] = 61")
    s.fire("SCENARIO_CRITERIA_UPDATE")
    assert s.shown()[3:6] == ["  - 5/10 Troggs slain", "  - Find Oggleflint", "  - Time left: 3:59"], s.shown()
    s.lua.execute("STUB.scenario = nil")
    s.fire("SCENARIO_UPDATE")
    assert s.shown()[0] == "# Quests | 4/25"

    step("stepping back: dim in a fight, dim unless the mouse is over it, hide in a dungeon; all off to begin with")
    frame = s.g.PatchwerkForeverTracker

    def frames(n=40):
        for _ in range(n):
            s.stub.Frame()

    s.stub.combat = True
    s.stub.time += 10
    frames()
    assert frame.alpha in (None, 1), "it dims in a fight unasked"
    s.setting("fadeCombat", True)
    frames()
    assert abs(frame.alpha - 0.35) < 0.001, frame.alpha
    s.setting("fadeTo", 60)
    frames()
    assert abs(frame.alpha - 0.6) < 0.001
    s.stub.combat = False
    frames()
    assert frame.alpha == 1
    s.setting("fadeCombat", False)
    s.setting("fadeIdle", True)
    s.stub.time += 10
    frames()
    assert abs(frame.alpha - 0.6) < 0.001, "it does not dim with the mouse elsewhere"
    frame.over = True
    frames()
    assert frame.alpha == 1, "it stays dim under the mouse"
    frame.over = False
    frames()
    assert abs(frame.alpha - 0.6) < 0.001
    # something in it changes: bright for a few seconds
    s.lua.execute("STUB.thieves.objectives[1] = { '11/12 Raptor Head', false, 11, 12 }")
    s.fire("QUEST_LOG_UPDATE")
    frames()
    assert frame.alpha == 1, "a change does not wake it"
    s.stub.time += 10
    frames()
    assert abs(frame.alpha - 0.6) < 0.001
    s.setting("fadeIdle", False)
    frames()
    assert frame.alpha == 1
    s.stub.instance = True
    s.fire("ZONE_CHANGED_NEW_AREA")
    assert s.shown() is not None, "it hides in a dungeon unasked"
    s.setting("hideInstance", True)
    assert s.shown() is None
    s.stub.instance = False
    s.fire("ZONE_CHANGED_NEW_AREA")
    assert s.shown() is not None
    assert s.chat() == []


if __name__ == "__main__":
    main()
