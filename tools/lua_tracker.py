"""Run Thread (Tracker) outside the game, on its base, against a stand-in for the game
(wowstub.lua and trackerstub.lua).

    python lua_tracker.py

Plays logins, each in a Lua of its own: the quests you track drawn as a list and kept up to date,
their orders, distances, kinds and timers; clicks and the menu; following the nearest quest; the
guide's steps and skipping one; a side list with no main guide beside it, which a click selects, and
a list whose step number stays when it is moved, as the Dungeon Journal's does; the
item buttons, which must not be touched in a fight; recipes; the
party; the gathering list; a dungeon's stages; the fades; the settings, folding, scrolling, moving
it; and the game's own tracker and RestedXP's window kept quiet. Then what was smoothed later: its
place kept as a top corner whatever the scale; a list longer than its frame (the edges, the scroll
bindings, the chosen quest brought into view); an order that holds while two quests are about as
near as each other. A key binding is pressed by running its own entry of Bindings.xml. It fails
loudly on any Lua error.

What this proves: the tracker's own code runs and does sensible things with the stand-in's answers.
What it cannot prove: that the game's real quest log, its real tracker, its secure buttons, RestedXP
or a real party answer as the stand-ins do, or how any of it looks.
"""
import math
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


def bindings():
    """The tracker's Bindings.xml: each entry's name and the Lua the game runs for it ('' for a click on a button)."""
    text = open(os.path.join(ADDONS, TRACKER, "Bindings.xml"), encoding="utf-8").read()
    found = re.findall(r'<Binding\s+name="([^"]+)"[^>]*?(?:/>|>(.*?)</Binding>)', text, re.S)
    return {name: code.strip() for name, code in found}


BINDINGS = bindings()


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

    def press(self, name):
        """A key bound to this entry of Bindings.xml is pressed: the entry's own Lua is run, as the game runs it."""
        assert BINDINGS.get(name), name + " is not in Bindings.xml, or runs nothing"
        assert isinstance(self.g["BINDING_NAME_" + name], str), name + " has no name in the Key Bindings list"
        self.lua.execute(BINDINGS[name])
        self.turn()

    def marked(self):
        """The one block shown with the bar beside it (what is being followed)."""
        got = [f for f in self.stub.frames.values() if f.kind == "Button" and f.shown and f.data is not None and f.data.mark]
        assert len(got) == 1, "%d blocks are marked" % len(got)
        return got[0]

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


# a made-up guide addon's reader that says it is a side list (as the Dungeon Journal's does, unless set
# to lead). For after the login: the base must be there to join.
SIDE = """
    STUB.sideAt, STUB.isSide = 2, true
    PatchwerkForever.Guides:Register('side', { name = 'Side List',
        Side = function() return STUB.isSide end,
        Leads = function() return not STUB.isSide end,
        Read = function(count)
            local info = { guide = 'Dungeon Journal: The Deadmines', index = STUB.sideAt, total = 6, kind = 'accept', key = 'side' .. STUB.sideAt,
                lines = { { text = 'Accept: A Job', done = false } }, ahead = {}, after = {}, items = {} }
            if count > 0 then info.after[1] = { index = STUB.sideAt + 1, kind = 'turnin', lines = { { text = 'Turn in: Another', done = false } } } end
            return info
        end,
        Go = function(index) STUB.sideGo = index; STUB.sideAt = index; return true end })
"""

# The same made-up reader, moving as the Dungeon Journal's list really does (its Reader.lua; that it
# does is checked in lua_patchwerk.py): the step number counts quests turned in, so it stays, and Go
# goes by how far the number asked for is from it. One on skips the stop in front; further on brings
# that stop to the front; back takes the last skip back; the number itself is refused.
STAYS = """
    STUB.isSide, STUB.stops, STUB.skips = true, { 'Accept: A Job', 'Turn in: Another', 'Accept: A Third' }, {}
    PatchwerkForever.Guides:Register('side', { name = 'Side List',
        Side = function() return STUB.isSide end,
        Leads = function() return not STUB.isSide end,
        Read = function(count)
            local stops = STUB.stops
            if not stops[1] then return nil end
            local info = { guide = 'Dungeon Journal: The Deadmines', index = 2, total = 6, kind = 'accept', key = 'side:' .. stops[1],
                lines = { { text = stops[1], done = false } }, ahead = {}, after = {}, items = {} }
            for i = 2, math.min(#stops, count + 1) do
                info.after[i - 1] = { index = i + 1, kind = 'accept', lines = { { text = stops[i], done = false } } }
            end
            return info
        end,
        Go = function(index)
            local stops, offset = STUB.stops, index - 2
            STUB.sideGo = index
            if offset == 1 then
                STUB.skips[#STUB.skips + 1] = table.remove(stops, 1)
            elseif offset > 1 and stops[offset + 1] then
                table.insert(stops, 1, table.remove(stops, offset + 1))
            elseif offset < 0 and #STUB.skips > 0 then
                table.insert(stops, 1, table.remove(STUB.skips))
            else
                return false
            end
            return true
        end })
"""


def step(label):
    print("  " + label)


def same(s, a, b):
    return s.lua.eval("function(a, b) return a == b end")(a, b)


def near(a, b):
    return all(abs(x - y) < 0.01 for x, y in zip(a, b))


def edges(frame):
    """Where a frame is on the screen, in the screen's own units: its left, its right, its top.
    (The game gives a frame's edges in the frame's own scale; times that scale they are the screen's.)"""
    scale = frame.GetScale(frame)
    return frame.GetLeft(frame) * scale, frame.GetRight(frame) * scale, frame.GetTop(frame) * scale


def beside(s, frame, size=32):
    """Where the first item button must be, on the left of the tracker: as Items.lua rounds it."""
    left, _, top = edges(frame)
    return math.floor(left - 4 - size + 0.5), math.floor(top + 0.5)


# twenty more quests than fit
LONG = """
    for i = 1, 20 do
        STUB.Quest({ id = 2000 + i, title = 'A Long List ' .. i, level = 12, objectives = { { 'something to do', false } } })
        STUB.watched[#STUB.watched + 1] = 2000 + i
    end
"""


def main():
    first_login()
    orders_and_detail()
    clicks()
    guide()
    side_list()
    item_buttons()
    recipes()
    party()
    gathering()
    dungeon_and_fades()
    its_place()
    long_list()
    steady_order()
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
    assert sorted(b.text for b in s.stub.buttons.values()) == ["Defaults", "Reset", "Unlock"]
    # each page opens with its name and a line in Patchwerk's voice, and is grouped under stitched headings
    heads = list(s.stub.headers.values())
    assert heads == ["General", "Size", "Position", "Fading", "Quest List", "Quest Details", "Party",
                     "Automation", "Quest Item Bar", "Recipes", "Gathering", "Dungeons", "Size", "Colors", "Defaults"], heads
    intros = {i.name: i.voice for i in s.stub.intros.values()}
    assert sorted(intros) == pages and intros["Tracker: Quests"] == "So many jobs. Patchwerk does the near one first.", intros
    assert s.stub.Rows() == 20, "a row of our own could not be made"
    names = [x.name for x in mine]
    assert "Hide Default Quest Tracker" in names and "Font Size" in names and "Hide RestedXP Window" in names, names
    # every entry of Bindings.xml has a name in the Key Bindings list, and what it runs is there to be run
    assert list(BINDINGS) == ["PATCHWERKFOREVER_TRACKER_FOLD", "PATCHWERKFOREVER_TRACKER_SCROLL_UP",
                              "PATCHWERKFOREVER_TRACKER_SCROLL_DOWN", "PATCHWERKFOREVER_TRACKER_NEXT",
                              "PATCHWERKFOREVER_TRACKER_PREV", "CLICK PatchwerkForeverTrackerNearestItem:LeftButton",
                              "PATCHWERKFOREVER_TRACKER_BACK"], list(BINDINGS)
    for name, code in BINDINGS.items():
        assert isinstance(s.g["BINDING_NAME_" + name], str), name + " has no name in the Key Bindings list"
        if name.startswith("CLICK "):
            assert code == "" and s.g[name[6:].split(":")[0]] is not None, name + " clicks a button that is not there"
        else:
            called = re.fullmatch(r"(\w+)\(\)", code)
            assert called and s.g[called.group(1)] is not None, name + " runs something that is not there: " + code
    label = {name: s.g["BINDING_NAME_" + name] for name in BINDINGS}
    assert label["PATCHWERKFOREVER_TRACKER_SCROLL_UP"] == "Scroll Tracker Up", label
    assert label["PATCHWERKFOREVER_TRACKER_SCROLL_DOWN"] == "Scroll Tracker Down", label
    assert label["PATCHWERKFOREVER_TRACKER_BACK"] == "Undo Skipped Guide Step", label
    for unwanted in ("Skip Guide Step", "Previous Guide Step"):
        assert unwanted not in label.values(), unwanted + " was not asked for"
    # the tooltips that say how: each names the key bindings as the Key Bindings list has them
    tips = {d.key: d.desc for d in ns.settings.values() if d.key}
    assert label["PATCHWERKFOREVER_TRACKER_SCROLL_UP"] in tips["height"] and label["PATCHWERKFOREVER_TRACKER_SCROLL_DOWN"] in tips["height"]
    assert label["PATCHWERKFOREVER_TRACKER_BACK"] in tips["guideSkip"] and "/tracker back" in tips["guideSkip"], tips["guideSkip"]
    # (the arrow is left alone while a list is the selected route, as while a quest is: the tooltip says both)
    assert "have not selected a quest or a list" in tips["followNearest"], tips["followNearest"]

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
    # (a top corner in the screen's units; the fifth field marks that form: more of it in its_place)
    assert list(place.values()) == ["TOPLEFT", "TOPLEFT", 300, -200, 1], list(place.values())
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

    step("the game's tracker: let back in a dungeon, where ours steps aside for it; never touched in a fight, as it was when ours goes")
    s.stub.instance = True
    s.fire("ZONE_CHANGED_NEW_AREA")
    assert not ns.Quiet() and game.frame.alpha == 1 and game.block.mouse is True, "not let back in a dungeon"
    assert s.shown() is None and ns.AsideInInstance() is True, "both trackers are shown in a dungeon"
    s.setting("quietInstance", False)
    assert ns.Quiet() and game.frame.alpha == 0
    assert s.shown() is not None and ns.AsideInInstance() is False, "ours is not shown in a dungeon where the game's is not kept"
    s.setting("quietInstance", True)
    assert s.shown() is None and not ns.Quiet()
    # with the game's tracker left alone everywhere, both are shown there as they are anywhere
    s.setting("quiet", False)
    assert s.shown() is not None and not ns.Quiet() and game.frame.alpha == 1, "ours hid in a dungeon with the game's tracker never hidden"
    s.setting("quiet", True)
    assert s.shown() is None and not ns.Quiet()
    s.stub.instance = False
    s.fire("ZONE_CHANGED_NEW_AREA")
    assert ns.Quiet() and game.block.mouse is False
    assert s.shown() is not None and ns.AsideInInstance() is False, "ours did not come back outside the dungeon"
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

    step("Reset To Defaults: asks first, then every option is as it began; its place is left alone")
    s.setting("width", 400)
    s.setting("order", "near")
    s.setting("lookTitle", "ff00ff00")
    s.setting("fadeCombat", True)
    s.slash("move")
    handle = [f for f in s.stub.frames.values() if f.scripts.OnDragStart][0]
    handle.scripts.OnDragStop(handle)
    s.slash("lock")
    [b for b in s.stub.buttons.values() if b.text == "Defaults"][0].click()
    assert "Reset all Thread: Tracker options" in s.stub.asked.text, s.stub.asked.text
    s.stub.Answer(False)
    assert ns.Get("width") == 400 and ns.Get("order") == "near", "the options were reset without a yes"
    [b for b in s.stub.buttons.values() if b.text == "Defaults"][0].click()
    s.stub.Answer(True)
    s.turn()
    text = s.chat()
    assert any("Options reset to defaults" in t for t in text), text
    assert (ns.Get("width"), ns.Get("order"), ns.Get("lookTitle"), ns.Get("fadeCombat")) == (260, "zone", "ffffd200", False)
    assert frame.width == 260 and s.g.PatchwerkForever_Thread_TrackerDB.place is not None, "its place was reset with its options"
    s.slash("reset")
    s.chat()

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

    step("with no mouse: a key or gamepad button routes to the next or the previous quest in the list")
    assert s.g.BINDING_NAME_PATCHWERKFOREVER_TRACKER_NEXT == "Route To Next Quest"
    order = [t.split(" | ")[0].lstrip("> ") for t in s.shown() if t.lstrip("> ").startswith("[")]
    assert order == ["[13] The Forgotten Pools", "[13] Raptor Thieves", "[4] Thwarting Kolkar Aggression", "[13] The Zhevra"], order
    Choice = s.g.PatchwerkForever.Choice
    assert Choice.Get(Choice) is None
    for want in (870, 869, 786, 845):
        s.g.PatchwerkForever_Thread_Tracker_Next()
        s.turn()
        assert Choice.Is(Choice, "quest", want) and s.stub.focus == want, (want, s.stub.focus)
    assert "> [13] The Zhevra | 5 yd" in s.shown()
    s.g.PatchwerkForever_Thread_Tracker_Next()               # one past the last: no quest, the main route
    s.turn()
    assert Choice.Get(Choice) is None and s.stub.focus == 0 and not any(t.startswith(">") for t in s.shown())
    s.g.PatchwerkForever_Thread_Tracker_Previous()           # from none, backwards: the last
    s.turn()
    assert Choice.Is(Choice, "quest", 845)
    s.g.PatchwerkForever_Thread_Tracker_Previous()
    s.turn()
    assert Choice.Is(Choice, "quest", 786)
    s.slash("next")
    assert Choice.Is(Choice, "quest", 845)
    s.slash("previous")
    s.slash("previous")
    s.slash("previous")
    text = s.slash("previous")
    assert Choice.Get(Choice) is None and any("Back to your main route" in t for t in text), text
    # nothing tracked: said, no error
    s.lua.execute("STUB.kept = STUB.watched; STUB.watched = {}")
    s.fire("QUEST_WATCH_LIST_CHANGED")
    text = s.slash("next")
    assert any("No tracked quests" in t for t in text) and Choice.Get(Choice) is None, text
    s.lua.execute("STUB.watched = STUB.kept")
    s.fire("QUEST_WATCH_LIST_CHANGED")
    s.chat()

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

    step("a click on the step skips it; on a later one goes to it; /tracker back takes it back; each is said in chat")
    assert s.chat() == []
    s.click("Step 1")
    assert s.stub.setStep == 2 and "> Step 2" in s.shown()
    text = s.chat()
    assert text == ["Tracker: Skipped step 1. Use the Undo Skipped Guide Step key binding or type /tracker back to undo."], text
    text = s.slash("back")
    assert s.stub.setStep == 1 and "> Step 1" in s.shown() and any("Back to step 1" in t for t in text)
    assert text == ["Tracker: Back to step 1."], text
    text = s.slash("back")
    assert any("No skipped step" in t for t in text)
    s.click("4. Hearth")
    assert s.stub.setStep == 4 and "> Step 4" in s.shown() and "5. Turn in your report" in s.shown()
    text = s.chat()
    assert text == ["Tracker: Jumped to step 4. Type /tracker back to return to step 1."], text
    s.click("Step 4", "RightButton")
    assert [e.text for e in s.stub.menu.entries.values()] == ["Skip Step", "Previous Step"]
    s.stub.Press("Previous Step")
    s.turn()
    assert s.stub.setStep == 3
    text = s.chat()
    assert text == ["Tracker: Back to step 3."], text
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

    step("the Undo Skipped Guide Step key does what /tracker back does; a skip from long ago, or in another guide")
    back = "PATCHWERKFOREVER_TRACKER_BACK"
    s.click("Step 1")
    assert s.stub.setStep == 2 and len(s.chat()) == 1
    s.press(back)
    text = s.chat()
    assert s.stub.setStep == 1 and "> Step 1" in s.shown() and text == ["Tracker: Back to step 1."], text
    s.press(back)
    text = s.chat()
    assert s.stub.setStep == 1 and text == ["Tracker: No skipped step to undo."], text
    # the guide has moved on by itself since the skip: it still goes back, and says from where
    s.click("Step 1")
    s.lua.execute("RXPCData.currentStep = 4")
    s.turn()
    s.chat()
    s.press(back)
    text = s.chat()
    assert s.stub.setStep == 1 and text == ["Tracker: Back to step 1 (from step 4)."], text
    # the guide is on that step again already (gone back to in RestedXP's own window): there is no "from" to say
    s.click("Step 1")
    s.lua.execute("RXPCData.currentStep = 1; STUB.setStep = nil")
    s.turn()
    s.chat()
    s.press(back)
    text = s.chat()
    assert s.stub.setStep == 1 and text == ["Tracker: Back to step 1."], text
    # RestedXP has loaded another guide since the skip: the step's number means nothing there, and the undo is forgotten
    s.click("Step 1")
    s.lua.execute("RXP.currentGuide.displayname = 'Durotar 1-12'; RXPCData.currentStep = 4; STUB.setStep = nil")
    s.turn()
    s.chat()
    s.press(back)
    text = s.chat()
    assert s.stub.setStep is None and text == ["Tracker: No skipped step to undo."], "a step of another guide was gone back to: %r" % text
    s.lua.execute("RXP.currentGuide.displayname = 'The Barrens 12-14'; RXPCData.currentStep = 2")
    s.turn()
    text = s.slash("back")
    assert s.stub.setStep is None and text == ["Tracker: No skipped step to undo."], "the undo outlived the guide it was made in"
    s.lua.execute("RXPCData.currentStep = 1")
    s.turn()

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

    step("a second guide beside the first: its own section; a click chooses its list, a second goes back")
    s.lua.execute("""
        STUB.sideAt = 2
        PatchwerkForever.Guides:Register('side', { name = 'Side List',
            Read = function(count)
                if STUB.sideOff then return nil end
                local info = { guide = 'Dungeon Journal: The Deadmines', index = STUB.sideAt, total = 6, kind = 'accept', key = 'side' .. STUB.sideAt,
                    lines = { { text = 'Accept: A Job', done = false } }, ahead = {}, after = {}, items = {} }
                if count > 0 then info.after[1] = { index = STUB.sideAt + 1, kind = 'turnin', lines = { { text = 'Turn in: Another', done = false } } } end
                return info
            end,
            Go = function(index) STUB.sideGo = index; STUB.sideAt = index; return true end })
    """)
    s.tick()
    got = s.show()
    assert got[:3] == ["# The Barrens 12-14 | Step 1 of 5", "# Dungeon Journal: The Deadmines | Step 2 of 6", "# Quests | 4/25"], got[:3]
    at = got.index("Step 2")
    assert got[at:at + 3] == ["Step 2", "  - Accept: A Job", "3. Turn in: Another"], got[at:at + 3]
    assert "> Step 1" in got, "the main guide is not marked as the one followed"
    s.click("Step 2")
    marked = [t for t in s.shown() if t.startswith(">")]
    assert marked == ["> Step 2"] and Choice.Is(Choice, "guide", "side"), marked
    s.click("Step 2")
    assert [t for t in s.shown() if t.startswith(">")] == ["> Step 1"] and Choice.Get(Choice) is None
    s.click("Step 2", "RightButton")
    assert s.stub.menu.title == "Dungeon Journal: The Deadmines"
    assert [e.text for e in s.stub.menu.entries.values()] == ["Route To This List", "Skip Step", "Previous Step"]
    s.stub.Press("Route To This List")
    s.turn()
    assert Choice.Is(Choice, "guide", "side")
    s.click("Step 2", "RightButton")
    assert [e.text for e in s.stub.menu.entries.values()][0] == "Stop Routing To This List"
    s.stub.Press("Stop Routing To This List")
    s.turn()
    assert Choice.Get(Choice) is None
    # a click on one of its later steps goes to that one and chooses the list
    s.click("3. Turn in: Another")
    assert s.stub.sideGo == 3 and Choice.Is(Choice, "guide", "side") and "> Step 3" in s.shown(), s.shown()
    text = s.slash("back")
    assert s.stub.sideGo == 2 and any("Back to step 2" in t for t in text), text
    # the main guide's own clicks are as they were
    s.click("Step 1")
    assert s.stub.setStep == 2
    s.slash("back")
    # its list done: the section goes, and the main guide is the one followed again
    s.lua.execute("STUB.sideOff = true")
    s.tick()
    got = s.shown()
    assert got[:2] == ["# The Barrens 12-14 | Step 1 of 5", "# Quests | 4/25"] and "> Step 1" in got and Choice.Get(Choice) is None, got[:4]
    s.chat()

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
    # in a dungeon, where ours steps aside for the game's tracker, RestedXP's window is back too
    s.stub.instance = True
    s.fire("ZONE_CHANGED_NEW_AREA")
    assert s.shown() is None and not ns.Quiet("RXPFrame") and window.alpha == 1 and piece.mouse is True, "RestedXP's window stayed hidden with ours gone"
    s.stub.instance = False
    s.fire("ZONE_CHANGED_NEW_AREA")
    assert ns.Quiet("RXPFrame") and window.alpha == 0 and s.shown()[0].startswith("# The Barrens 12-14")
    s.setting("guideHide", False)
    assert window.alpha == 1 and piece.mouse is True
    assert s.chat() == []


def side_list():
    step("a side list with no main guide beside it: listed, not followed by itself; a click selects it and skips nothing")
    s = Session(LOG + PLACES)
    ns = s.load()
    Choice = s.g.PatchwerkForever.Choice
    s.lua.execute(SIDE)
    s.tick()
    got = s.show()
    assert got[:2] == ["# Dungeon Journal: The Deadmines | Step 2 of 6", "# Quests | 4/25"], got[:2]
    assert "Step 2" in got and "> Step 2" not in got, "a side list with no main guide beside it is drawn as the main guide"
    at = got.index("Step 2")
    assert got[at:at + 3] == ["Step 2", "  - Accept: A Job", "3. Turn in: Another"], got[at:at + 3]
    assert not any(t.startswith(">") for t in got), "a side list nobody selected is marked as the one followed"
    assert ns.GuideNow() is None, "a side list is taken for the main guide"
    # the game's arrow on a quest by another hand: that quest is the one followed, not the list
    s.lua.execute("STUB.focus = 869")
    s.fire("SUPER_TRACKING_CHANGED")
    assert [t for t in s.shown() if t.startswith(">")] == ["> [13] Raptor Thieves | 112 yd"], s.shown()
    s.lua.execute("STUB.focus = 0")
    s.fire("SUPER_TRACKING_CHANGED")
    # a click selects the list, as it does beside a main guide: no stop is skipped, nothing is said
    s.click("Step 2")
    marked = [t for t in s.shown() if t.startswith(">")]
    assert s.stub.sideGo is None and s.stub.sideAt == 2, "a click on a side list skipped a stop"
    assert marked == ["> Step 2"] and Choice.Is(Choice, "guide", "side"), marked
    assert s.chat() == []
    s.click("Step 2")
    assert Choice.Get(Choice) is None and not any(t.startswith(">") for t in s.shown()), s.shown()
    # its menu is a side list's: route to it, and skipping
    s.click("Step 2", "RightButton")
    assert s.stub.menu.title == "Dungeon Journal: The Deadmines"
    assert [e.text for e in s.stub.menu.entries.values()] == ["Route To This List", "Skip Step", "Previous Step"]
    s.stub.Press("Route To This List")
    s.turn()
    assert Choice.Is(Choice, "guide", "side") and s.stub.sideGo is None
    s.click("Step 2", "RightButton")
    assert [e.text for e in s.stub.menu.entries.values()][0] == "Stop Routing To This List"
    s.stub.Press("Stop Routing To This List")
    s.turn()
    assert Choice.Get(Choice) is None
    # a click on one of its later steps goes to that one and selects the list
    s.click("3. Turn in: Another")
    assert s.stub.sideGo == 3 and Choice.Is(Choice, "guide", "side") and "> Step 3" in s.shown(), s.shown()
    s.chat()
    text = s.slash("back")
    assert s.stub.sideGo == 2 and text == ["Tracker: Back to step 2."], text
    s.click("Step 2")
    assert Choice.Get(Choice) is None
    assert s.chat() == []

    step("Auto-Track Nearest Quest beside a side list: the nearest quest until the list is selected, then the arrow is left alone")
    assert s.stub.focus == 0
    s.setting("followNearest", True)
    s.tick()
    assert s.stub.focus == 845 and ns.AutoFollowed() == 845, "a side list nobody selected kept the nearest quest from being followed"
    s.click("Step 2")
    assert Choice.Is(Choice, "guide", "side") and [t for t in s.shown() if t.startswith(">")] == ["> Step 2"]
    # another quest becomes clearly nearer: the arrow would move, but the list is the selected route
    s.lua.execute("STUB.QuestAt(870, 'The Forgotten Pools', 1, -451, -2600)")
    s.stub.time += 10
    s.tick()
    assert s.stub.focus == 845, "the quest arrow was moved while a list is the selected route"
    s.click("Step 2")
    s.tick()
    assert Choice.Get(Choice) is None and s.stub.focus == 870, "with the list let go, the nearest quest was not followed again"
    # no arrow at all while the list is selected: none is put on a quest
    s.click("Step 2")
    s.lua.execute("STUB.focus = 0")
    s.fire("SUPER_TRACKING_CHANGED")
    s.stub.time += 10
    s.tick()
    assert Choice.Is(Choice, "guide", "side") and s.stub.focus == 0, "the quest arrow was put on a quest while a list is the selected route"
    s.click("Step 2")
    s.setting("followNearest", False)
    s.lua.execute("STUB.focus = 0")
    s.fire("SUPER_TRACKING_CHANGED")
    assert s.chat() == []

    step("the same list set to lead: the main guide as before, followed by itself, and a click skips its step")
    s.lua.execute("STUB.isSide = false")
    s.tick()
    assert Choice.Get(Choice) is None and [t for t in s.shown() if t.startswith(">")] == ["> Step 2"], s.shown()
    assert ns.GuideNow() is not None and ns.GuideNow().source == "side"
    s.setting("followNearest", True)
    s.tick()
    assert s.stub.focus == 0, "the quest arrow was moved while a guide leads"
    s.setting("followNearest", False)
    s.click("Step 2")
    text = s.chat()
    assert s.stub.sideGo == 3 and Choice.Get(Choice) is None and "> Step 3" in s.shown(), s.shown()
    assert text == ["Tracker: Skipped step 2. Use the Undo Skipped Guide Step key binding or type /tracker back to undo."], text
    s.click("Step 3", "RightButton")
    assert [e.text for e in s.stub.menu.entries.values()] == ["Skip Step", "Previous Step"]

    step("a list whose step number stays when it is moved (the Dungeon Journal's): chat says no number and promises no undo")
    s = Session(LOG + PLACES)
    ns = s.load()
    Choice = s.g.PatchwerkForever.Choice
    back = "PATCHWERKFOREVER_TRACKER_BACK"
    s.lua.execute(STAYS)
    s.tick()
    heading = "# Dungeon Journal: The Deadmines | Step 2 of 6"

    def stops():
        got = s.shown()
        at = got.index("Step 2") if "Step 2" in got else got.index("> Step 2")
        return [t.strip(" -") for t in got[at + 1:at + 4]]

    assert s.shown()[0] == heading and stops() == ["Accept: A Job", "3. Turn in: Another", "4. Accept: A Third"], s.shown()
    assert s.chat() == []
    # Skip Step in its menu: the stop is gone from the front, the number is as it was
    s.click("Step 2", "RightButton")
    s.stub.Press("Skip Step")
    s.turn()
    text = s.chat()
    assert s.stub.sideGo == 3 and s.shown()[0] == heading and stops()[:2] == ["Turn in: Another", "3. Accept: A Third"], s.shown()
    assert text == ["Tracker: Step skipped."], "a step number or an undo was said for a list whose number stays: %r" % text
    # the undo goes back to a step number, which such a list refuses: it is said as it is
    s.press(back)
    text = s.chat()
    assert s.stub.sideGo == 2 and text == ["Tracker: Side List could not go back."], text
    assert stops()[0] == "Turn in: Another"
    # Previous Step in its menu takes the skip back: no "Back to step 1" beside a heading that says Step 2
    s.click("Step 2", "RightButton")
    s.stub.Press("Previous Step")
    s.turn()
    text = s.chat()
    assert s.stub.sideGo == 1 and stops() == ["Accept: A Job", "3. Turn in: Another", "4. Accept: A Third"], s.shown()
    assert text == ["Tracker: Went back one step."], text
    # a click on a later stop brings it to the front and selects the list: no step number to have jumped to
    s.click("4. Accept: A Third")
    text = s.chat()
    assert s.stub.sideGo == 4 and Choice.Is(Choice, "guide", "side") and "> Step 2" in s.shown(), s.shown()
    assert s.shown()[0] == heading and stops() == ["Accept: A Third", "3. Accept: A Job", "4. Turn in: Another"], s.shown()
    assert text == ["Tracker: Jumped to that step."], text
    assert s.slash("back") == ["Tracker: Side List could not go back."]
    assert s.slash("back") == ["Tracker: No skipped step to undo."]
    s.click("Step 2")
    assert Choice.Get(Choice) is None
    # set to lead, a plain click on its step is the skip: said the same way; the last stop skipped, the list is gone
    s.lua.execute("STUB.isSide = false")
    s.tick()
    for left in (["Accept: A Job", "3. Turn in: Another"], ["Turn in: Another"], None):
        s.click("Step 2")
        text = s.chat()
        assert text == ["Tracker: Step skipped."], text
        if left:
            assert s.shown()[0] == heading and stops()[:len(left)] == left, s.shown()
        else:
            assert s.shown()[0] == "# Quests | 4/25", "a list with every stop skipped is still listed"
    s.press(back)
    assert s.chat() == ["Tracker: No skipped step to undo."]


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
    assert s.shown() is None, "both trackers are shown in a dungeon"
    s.setting("quietInstance", False)
    assert s.shown() is not None, "it hides in a dungeon with nothing asking for it"
    s.setting("hideInstance", True)
    assert s.shown() is None
    s.setting("quietInstance", True)
    assert s.shown() is None
    s.stub.instance = False
    s.fire("ZONE_CHANGED_NEW_AREA")
    assert s.shown() is not None
    assert s.chat() == []


def its_place():
    step("its place: the Scale slider does not move it, and the quest item bar stays beside it")
    s = Session(LOG + PLACES + "STUB.thieves.item = { 4854, false }")
    s.load()
    frame, first = s.g.PatchwerkForeverTracker, s.button(1)
    db = s.g.PatchwerkForever_Thread_TrackerDB
    assert (s.g.UIParent.width, s.g.UIParent.height) == (1100, 960)
    # under the minimap: 40 in from the right of the screen, 260 down
    assert near(edges(frame), (800, 1060, 700)), edges(frame)
    assert s.items() == ([4854], 4854) and (first.points[1][4], first.points[1][5]) == (764, 700)
    for scale in (160, 60, 125, 100):
        s.setting("scale", scale)
        assert abs(frame.GetScale(frame) - scale / 100) < 0.001
        assert near(edges(frame)[1:], (1060, 700)), "at %d%% its top right corner is at %r" % (scale, edges(frame)[1:])
        assert (first.points[1][4], first.points[1][5]) == beside(s, frame), "at %d%% the item bar is not beside it" % scale
    assert (first.points[1][4], first.points[1][5]) == (764, 700)

    step("moving it: wherever the game hangs it after a drag, a top corner is kept, and the list grows downward from it")
    handle = [f for f in s.stub.frames.values() if f.scripts.OnDragStart][0]
    s.slash("move")
    # let go at the right of the screen, where the game hangs a tall frame from the middle of the right edge
    s.lua.execute("STUB.drop = { 'RIGHT', 'RIGHT', -30, 40 }")
    tall = frame.height
    handle.scripts.OnDragStart(handle)
    handle.scripts.OnDragStop(handle)
    s.turn()
    top = 960 / 2 + 40 + tall / 2
    place = list(db.place.values())
    assert place[:2] == ["TOPRIGHT", "TOPRIGHT"] and len(place) == 5 and near(place[2:], (-30, top - 960, 1)), place
    assert frame.points[1][1] == "TOPRIGHT" and near(edges(frame), (810, 1070, top)), edges(frame)
    assert (first.points[1][4], first.points[1][5]) == beside(s, frame) == (774, math.floor(top + 0.5))
    # quests go: it is shorter, and its first heading has not moved
    s.lua.execute("STUB.watched = { 869 }")
    s.fire("QUEST_WATCH_LIST_CHANGED")
    assert frame.height < tall and near(edges(frame), (810, 1070, top)), "the top of a moved tracker moved with its height"
    # the Scale slider does not move a tracker that has been moved either
    s.setting("scale", 160)
    assert near(edges(frame), (1070 - 260 * 1.6, 1070, top)), edges(frame)
    # let go right of the middle while scaled up: which half it is in is told on the screen, not in the
    # frame's own scale (its middle is at 430 of its own units, which is 688 of the screen's 1100)
    s.lua.execute("STUB.drop = { 'BOTTOMLEFT', 'BOTTOMLEFT', 300, 100 }")
    handle.scripts.OnDragStart(handle)
    handle.scripts.OnDragStop(handle)
    s.turn()
    top = (100 + frame.height) * 1.6
    place = list(db.place.values())
    assert place[:2] == ["TOPRIGHT", "TOPRIGHT"] and len(place) == 5 and near(place[2:], (560 * 1.6 - 1100, top - 960, 1)), place
    assert frame.points[1][1] == "TOPRIGHT" and near(edges(frame), (480, 896, top)), edges(frame)
    # let go at the bottom left while scaled up: what the game gives is in the frame's own scale
    s.lua.execute("STUB.drop = { 'BOTTOMLEFT', 'BOTTOMLEFT', 50, 100 }")
    handle.scripts.OnDragStart(handle)
    handle.scripts.OnDragStop(handle)
    s.turn()
    top = (100 + frame.height) * 1.6
    place = list(db.place.values())
    assert place[:2] == ["TOPLEFT", "TOPLEFT"] and len(place) == 5 and near(place[2:], (80, top - 960, 1)), place
    assert frame.points[1][1] == "TOPLEFT" and near(edges(frame), (80, 80 + 260 * 1.6, top)), edges(frame)
    s.setting("scale", 100)
    assert near(edges(frame), (80, 340, top)), "the Scale slider moved a tracker that had been moved"
    assert (first.points[1][4], first.points[1][5]) == beside(s, frame) == (44, math.floor(top + 0.5))
    # let go while the game cannot say where the frame is: its place is kept as the game gave it, and
    # made a top corner at the first drawing that can measure it, without moving it
    s.lua.execute("STUB.drop = { 'RIGHT', 'RIGHT', -30, 40 }; STUB.unplaced = true")
    handle.scripts.OnDragStart(handle)
    handle.scripts.OnDragStop(handle)
    s.turn()
    assert list(db.place.values()) == ["RIGHT", "RIGHT", -30, 40], list(db.place.values())
    assert frame.points[1][1] == "RIGHT", "a frame that could not be measured was placed all the same"
    s.stub.unplaced = False
    was = edges(frame)
    s.turn()
    place = list(db.place.values())
    assert place[:2] == ["TOPRIGHT", "TOPRIGHT"] and len(place) == 5 and near(place[2:], (was[1] - 1100, was[2] - 960, 1)), place
    assert frame.points[1][1] == "TOPRIGHT" and near(edges(frame), was), "it moved when its place was made a top corner"
    assert (first.points[1][4], first.points[1][5]) == beside(s, frame), "the item bar is not beside it after that"
    s.slash("lock")

    step("Reset Position puts it back under the minimap, at any scale")
    s.setting("scale", 140)
    s.slash("reset")
    assert db.place is None and frame.points[1][1] == "TOPRIGHT" and near(edges(frame)[1:], (1060, 700)), edges(frame)
    s.setting("scale", 100)
    assert near(edges(frame), (800, 1060, 700)), edges(frame)
    s.chat()

    step("a place saved by an earlier version: put back as it was, then kept as a top corner once it can be measured")
    old = "PatchwerkForever_Thread_TrackerDB = { place = { 'RIGHT', 'RIGHT', -30, 40 }, settings = { scale = 120 } }"
    s = Session(LOG + old + " STUB.unplaced = true; STUB.thieves.item = { 4854, false }")
    s.load()
    frame, first = s.g.PatchwerkForeverTracker, s.button(1)
    db = s.g.PatchwerkForever_Thread_TrackerDB
    # (the game has not placed the frame yet: nothing to measure, so nothing is changed)
    assert list(db.place.values()) == ["RIGHT", "RIGHT", -30, 40], list(db.place.values())
    assert list(frame.points[1].values())[0] == "RIGHT" and (frame.points[1][4], frame.points[1][5]) == (-30, 40)
    s.stub.unplaced = False
    was = edges(frame)
    assert near(was[1:2], (1100 - 30 * 1.2,)), was             # (the old offsets were in the frame's own scale)
    s.fire("QUEST_LOG_UPDATE")
    place = list(db.place.values())
    assert place[:2] == ["TOPRIGHT", "TOPRIGHT"] and len(place) == 5 and near(place[2:], (was[1] - 1100, was[2] - 960, 1)), place
    assert frame.points[1][1] == "TOPRIGHT" and near(edges(frame), was), "it moved when its place was converted"
    assert s.items() == ([4854], 4854) and (first.points[1][4], first.points[1][5]) == beside(s, frame), "the item bar is not beside a tracker whose place was converted"
    s.lua.execute("STUB.watched = { 869 }")
    s.fire("QUEST_WATCH_LIST_CHANGED")
    s.setting("scale", 100)
    assert near(edges(frame)[1:], was[1:]), "after the conversion its top right corner still moves"
    assert (first.points[1][4], first.points[1][5]) == beside(s, frame), "after the conversion the Scale slider leaves the item bar behind"
    assert s.chat() == []


def long_list():
    step("a list longer than Max Height: the edge with more past it is darkened; Scroll Tracker Up and Scroll Tracker Down")
    s = Session(LOG + FLAT + LONG)
    ns = s.load()
    s.setting("height", 150)
    frame = s.g.PatchwerkForeverTracker
    body = [f for f in s.stub.frames.values() if f.scripts.OnMouseWheel][0]
    content = [f for f in s.stub.frames.values() if f.parent is not None and same(s, f.parent, body)][0]
    end = content.height - 150
    assert frame.height == 150 and end > 400, (frame.height, end)
    up, down = "PATCHWERKFOREVER_TRACKER_SCROLL_UP", "PATCHWERKFOREVER_TRACKER_SCROLL_DOWN"
    # (how far it is scrolled, the top edge darkened, the bottom edge darkened)
    assert ns.Scrolled() == (0, False, True), ns.Scrolled()
    s.press(down)
    assert ns.Scrolled() == (80, True, True) and content.points[1][5] == 80, ns.Scrolled()
    s.press(up)
    assert ns.Scrolled() == (0, False, True), ns.Scrolled()
    s.press(up)
    assert ns.Scrolled() == (0, False, True), "it scrolled past its top"
    for _ in range(20):
        s.press(down)
    assert ns.Scrolled() == (end, True, False), "at its end: %r" % (ns.Scrolled(),)
    body.scripts.OnMouseWheel(body, 1)                       # (the wheel still scrolls, and the edges follow it)
    s.turn()
    assert ns.Scrolled() == (end - 40, True, True), ns.Scrolled()
    # each edge is dark at the rim and clear toward the middle
    shades = {t.at: t.gradient for t in s.stub.allTextures.values() if t.gradient is not None}
    assert sorted(shades) == ["BOTTOMLEFT", "TOPLEFT"], sorted(shades)
    top, bottom = shades["TOPLEFT"], shades["BOTTOMLEFT"]
    assert top[1] == "VERTICAL" and (top[2].a, top[3].a) == (0, 0.75), "the top edge is not dark at its top"
    assert bottom[1] == "VERTICAL" and (bottom[2].a, bottom[3].a) == (0.75, 0), "the bottom edge is not dark at its bottom"

    step("Route To Next Quest and Route To Previous Quest bring the quest they select into view; nothing else scrolls the list")
    Choice = s.g.PatchwerkForever.Choice
    following, previous = "PATCHWERKFOREVER_TRACKER_NEXT", "PATCHWERKFOREVER_TRACKER_PREV"
    for _ in range(20):
        s.press(up)
    assert ns.Scrolled()[0] == 0

    def in_view():
        block = s.marked()
        top, at = -block.points[1][5], ns.Scrolled()[0]
        return top >= at and top + block.height <= at + 150

    order = list(ns.questOrder.values())
    assert len(order) == 23 and order[-1] == 2020, order
    for i, want in enumerate(order):
        s.press(following)
        assert Choice.Is(Choice, "quest", want) and s.marked().data.key == want
        assert in_view(), "quest %d was selected out of view" % want
        if i == 0:
            assert ns.Scrolled()[0] == 0, "a quest already in view was scrolled to"
    # (the last quest's foot is at the frame's, with the rim's room under it: only the empty rim of the
    # list is past the bottom edge, which is not darkened for that)
    foot = ns.Scrolled()[0]
    assert end - 8 <= foot < end and ns.Scrolled() == (foot, True, False), (ns.Scrolled(), end)
    # back up through the whole list: a quest above the frame is brought into view as one below it is
    for want in reversed(order[:-1]):
        s.press(previous)
        assert Choice.Is(Choice, "quest", want) and s.marked().data.key == want
        assert in_view(), "quest %d was selected out of view, above the frame" % want
    assert ns.Scrolled()[0] < 40, "at the first quest the list is still scrolled down: %r" % (ns.Scrolled(),)
    for want in order[1:]:
        s.press(following)
    assert Choice.Is(Choice, "quest", 2020) and in_view() and ns.Scrolled()[0] == foot, ns.Scrolled()
    s.chat()
    s.press(following)                                       # one past the last: the main route, and the top of the list
    text = s.chat()
    assert Choice.Get(Choice) is None and any("Back to your main route" in t for t in text), text
    assert ns.Scrolled() == (0, False, True), "back on the main route the list is not at its top"
    s.press(previous)                                        # from none, backwards: the last quest, at the foot
    assert Choice.Is(Choice, "quest", 2020) and in_view() and ns.Scrolled()[0] == foot, ns.Scrolled()
    s.press(previous)
    assert Choice.Is(Choice, "quest", 2019) and in_view()
    text = s.slash("next")
    text = s.slash("next")
    assert Choice.Get(Choice) is None and ns.Scrolled()[0] == 0, "the command does not scroll as the key does"
    # the mark moved by another hand (the game's arrow, with nothing selected): the list stays where it is
    s.lua.execute("STUB.focus = 2020")
    s.fire("SUPER_TRACKING_CHANGED")
    assert s.marked().data.key == 2020 and not in_view() and ns.Scrolled()[0] == 0, "the list scrolled by itself"
    s.lua.execute("STUB.focus = 0")
    s.fire("SUPER_TRACKING_CHANGED")
    # a quest selected, then scrolled away from with the wheel: drawing the list again does not scroll back to it
    s.press(previous)
    for _ in range(3):
        body.scripts.OnMouseWheel(body, 1)
    s.turn()
    assert ns.Scrolled()[0] == foot - 120 and not in_view()
    s.lua.execute("STUB.thieves.objectives[1] = { '11/12 Raptor Head', false, 11, 12 }")
    s.fire("QUEST_LOG_UPDATE")
    assert ns.Scrolled()[0] == foot - 120, "drawing the list again scrolled it back to the selected quest"
    # the selected quest in a section that is folded: nothing to scroll to, and no error
    s.slash("fold")
    s.press(previous)
    s.slash("fold")
    s.press(following)
    assert Choice.Is(Choice, "quest", 2020) and in_view()
    s.press(following)
    s.chat()

    step("everything fits, or nothing is shown: no darkened edge, and the scroll bindings do nothing")
    s.setting("height", 1000)
    assert ns.Scrolled() == (0, False, False) and body.wheel is False, ns.Scrolled()
    s.press(down)
    assert ns.Scrolled() == (0, False, False), ns.Scrolled()
    s.setting("height", 150)
    s.slash("off")
    for _ in range(5):
        s.press(down)
    s.press(previous)                                        # (the last quest is selected all the same)
    assert Choice.Is(Choice, "quest", 2020) and ns.Scrolled() is None
    s.slash("on")
    assert s.marked().data.key == 2020 and ns.Scrolled() == (0, False, True), "it scrolled while it was not shown: %r" % (ns.Scrolled(),)
    s.press(following)
    assert Choice.Get(Choice) is None
    s.chat()

    step("a tracker faded while not hovered wakes for a few seconds when a key steps through it or scrolls it")
    s.setting("fadeIdle", True)

    def frames(n=40):
        for _ in range(n):
            s.stub.Frame()

    for key in (following, down, previous, up):
        s.stub.time += 10
        frames()
        assert abs(frame.alpha - 0.35) < 0.001, "it is not faded with the mouse elsewhere: %r" % frame.alpha
        s.press(key)
        frames()
        assert frame.alpha == 1, key + " did not wake it"
    s.setting("fadeIdle", False)
    s.chat()

    step("a client that cannot draw a gradient: no darkened edges, and the list is drawn and scrolls as before")
    s = Session(LOG + FLAT + LONG + "CreateColor = nil")
    ns = s.load()
    s.setting("height", 150)
    assert ns.Scrolled() == (0, False, False) and len(s.shown()) > 40, ns.Scrolled()
    s.press(down)
    assert ns.Scrolled() == (80, False, False), ns.Scrolled()
    assert s.chat() == []


def steady_order():
    step("two quests about as near as each other: rows and item buttons hold their order until one is clearly nearer")
    s = Session(LOG + PLACES + """
        STUB.QuestAt(869, 'Raptor Thieves', 1, -510, -2600)
        STUB.thieves.item = { 4854, false }
        STUB.pools.item = { 5000, false }
    """)
    ns = s.load()

    def rows():
        return [t for t in s.shown() if t.startswith("[13]") and ("Pools" in t or "Thieves" in t)]

    assert rows() == ["[13] The Forgotten Pools | 50 yd", "[13] Raptor Thieves | 60 yd"], rows()
    assert s.items() == ([5000, 4854], 5000), s.items()
    # you walk 12 yards toward the farther one: the distances cross, the rows and the buttons stay
    s.stub.player.x = -462
    s.turn()
    assert rows() == ["[13] The Forgotten Pools | 62 yd", "[13] Raptor Thieves | 48 yd"], "two rows swapped as their distances crossed: %r" % rows()
    assert list(ns.questOrder.values())[:2] == [870, 869], "the order the next and previous quest step through changed"
    assert s.items() == ([5000, 4854], 5000), "the item buttons swapped as two distances crossed"
    # the quest log stirs, as it does every few seconds of play: the places are asked for again, but the
    # distances the order is held by are not dropped with them
    for event in ("QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "ZONE_CHANGED_NEW_AREA"):
        s.fire(event)
        assert rows() == ["[13] The Forgotten Pools | 62 yd", "[13] Raptor Thieves | 48 yd"], "%s let two rows swap: %r" % (event, rows())
        assert list(ns.questOrder.values())[:2] == [870, 869], event + " changed the order the next and previous quest step through"
        assert s.items() == ([5000, 4854], 5000), event + " let the item buttons swap"
    # a quest that leaves the log and is taken again starts afresh, from the distance measured then
    s.lua.execute("STUB.watched = { 869, 845, 786 }")
    s.fire("QUEST_REMOVED", 870)
    assert rows() == ["[13] Raptor Thieves | 48 yd"], rows()
    s.lua.execute("STUB.watched = { 869, 845, 786, 870 }")
    s.fire("QUEST_ACCEPTED", 870)
    assert rows() == ["[13] Raptor Thieves | 48 yd", "[13] The Forgotten Pools | 62 yd"], "a quest taken again is sorted by a distance from before: %r" % rows()
    assert s.items() == ([4854, 5000], 4854), s.items()
    # a clear change: the order follows
    s.stub.player.x = -420
    s.turn()
    assert rows() == ["[13] The Forgotten Pools | 20 yd", "[13] Raptor Thieves | 90 yd"], rows()
    assert s.items() == ([5000, 4854], 5000), s.items()

    step("with Show Quests off the item binding is sorted the same way")
    s.setting("quests", False)
    assert s.shown() is None and s.items() == ([], 5000), s.items()
    s.stub.player.x = -490
    s.fire("QUEST_LOG_UPDATE")
    assert s.items() == ([], 4854), "with the quests not listed, the item binding did not follow a clear change"
    s.stub.player.x = -478
    s.fire("QUEST_LOG_UPDATE")
    assert s.items() == ([], 4854), s.items()
    s.setting("quests", True)
    assert rows() == ["[13] Raptor Thieves | 32 yd", "[13] The Forgotten Pools | 78 yd"], rows()
    assert s.items() == ([4854, 5000], 4854), s.items()
    assert s.chat() == []

    step("far away a clear change is 15 percent of the distance, not 15 yards; a quest whose mark goes and comes back starts afresh")
    s = Session(LOG + PLACES + """
        STUB.QuestAt(869, 'Raptor Thieves', 1, -1080, -2600)
        STUB.QuestAt(870, 'The Forgotten Pools', 1, 150, -2600)
    """)
    ns = s.load()
    assert rows() == ["[13] The Forgotten Pools | 600 yd", "[13] Raptor Thieves | 630 yd"], rows()
    # you walk 40 yards toward the farther one: the distances cross, by less than 15 percent of either
    s.stub.player.x = -490
    s.turn()
    assert rows() == ["[13] The Forgotten Pools | 640 yd", "[13] Raptor Thieves | 590 yd"], "two far rows swapped on a change of 40 yards: %r" % rows()
    assert list(ns.questOrder.values())[:2] == [870, 869]
    # the game takes a quest's mark away (nothing to go to for a moment) and gives it back: the quest
    # is sorted by the distance measured then, not by the one held from before
    s.lua.execute("STUB.mark = STUB.quests[870]; STUB.quests[870] = nil")
    s.fire("QUEST_POI_UPDATE")
    assert rows() == ["[13] Raptor Thieves | 590 yd", "[13] The Forgotten Pools"], rows()
    s.lua.execute("STUB.quests[870] = STUB.mark")
    s.fire("QUEST_POI_UPDATE")
    assert rows() == ["[13] Raptor Thieves | 590 yd", "[13] The Forgotten Pools | 640 yd"], "a quest whose mark came back is sorted by a distance from before: %r" % rows()
    # a clear change, far away too: the order follows
    s.stub.player.x = -150
    s.turn()
    assert rows() == ["[13] The Forgotten Pools | 300 yd", "[13] Raptor Thieves | 930 yd"], rows()
    assert s.chat() == []


if __name__ == "__main__":
    main()
