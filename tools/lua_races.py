"""Run Races (Thread) and Sparkle (Thread)'s loot wisp outside the game, on the base, against the stand-in
for the game (wowstub.lua) with what these two need added to it.

    python lua_races.py

Plays: making a course as you ride it, racing it twice (a best run, then a slower one), the marker on
the game's waypoint frame, the pin you had put back, sending a course to a party member; and items
going into your bags from a loot window, from a herb you were sparkling on, from a merchant (no wisp),
and many at once. It fails loudly on any Lua error.

Races 0.2.0: a course's rule (On Foot: mounted or on a flight path during the run, an answer the game
keeps secret, a function it lacks), a best run for each rule, the rule sent with a shared course and
read by Races 0.1.2's own reader (OLD below); and racing together, the other racers played by feeding
their addon messages to the handler, in and out of order: inviting and joining, the start, the gap at
each checkpoint, the placings, a racer who leaves the group, a course you lack, messages of the wrong
shape, and the game refusing to send.

What this proves: the addons' own code runs and does sensible things with the stand-in's answers.
What it cannot prove: that the game's waypoint frame sits where the ring should be drawn, that the
wisp looks right, or that the game delivers addon messages and answers IsMounted as the stand-in
does. That is for the game.
"""
import os
import re
import sys

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ADDONS = os.path.normpath(os.path.join(HERE, "..", "addons"))
BASE = "PatchwerkForever"
SPARKLE = "PatchwerkForever_Thread_Sparkle"
RACES = "PatchwerkForever_Thread_Races"

# what the stand-in lacks for these two
MORE = r"""
date = os.date
STUB.sent, STUB.sounds, STUB.group = {}, 0, false
C_Map.GetPlayerMapPosition = function(map, unit)
    assert(unit == 'player')
    local saved = STUB.pin
    STUB.PinAt(STUB.player.map, STUB.player.x, STUB.player.y)
    local here = STUB.pin
    STUB.pin = saved
    assert(here.uiMapID == map, 'asked for a map you are not on')
    return here.position
end
C_Map.SetUserWaypoint = function(point)
    assert(point.uiMapID and point.position)
    STUB.pin = { uiMapID = point.uiMapID, position = CreateVector2D(point.position.x, point.position.y) }
end
C_Map.ClearUserWaypoint = function() STUB.pin = nil end
UiMapPoint = { CreateFromCoordinates = function(m, x, y)
    assert(type(m) == 'number' and type(x) == 'number' and type(y) == 'number')
    return { uiMapID = m, position = CreateVector2D(x, y) }
end }
C_SuperTrack.SetSuperTrackedUserWaypoint = function(on) STUB.superUser = on end
C_Navigation = { GetFrame = function() return STUB.nav end, WasClampedToScreen = function() return STUB.navClamped == true end,
    GetDistance = function() return STUB.navDistance end }
SOUNDKIT = { READY_CHECK = 8960, RAID_WARNING = 8959, IG_QUEST_LIST_COMPLETE = 619, LEVELUPSOUND = 888 }
function PlaySound(id) assert(type(id) == 'number') STUB.sounds = STUB.sounds + 1 end
C_ChatInfo = { RegisterAddonMessagePrefix = function(p) assert(#p <= 16) STUB.prefix = p end,
    SendAddonMessage = function(prefix, text, channel, target)
        assert(prefix == STUB.prefix and #text <= 255, 'an addon message too long: ' .. #text)
        assert(channel ~= 'WHISPER' or target)
        if STUB.sendResult then return STUB.sendResult end       -- (the game refuses it: 11 is a lockdown)
        STUB.sent[#STUB.sent + 1] = { prefix, text, channel, target }
        return 0
    end }
function IsInGroup() return STUB.group end
function IsInRaid() return false end
-- mounted or not; the other members of your party, by name (STUB.party = { 'Mira', 'Tovin' })
STUB.mounted, STUB.party = false, {}
function IsMounted() return STUB.mounted end
local exists, named = UnitExists, UnitName
function UnitExists(unit)
    local i = type(unit) == 'string' and unit:match('^party(%d)$')
    if i then return STUB.party[tonumber(i)] ~= nil end
    return exists(unit)
end
function UnitName(unit)
    local i = type(unit) == 'string' and unit:match('^party(%d)$')
    if i then return STUB.party[tonumber(i)] end
    return named(unit)
end
UNKNOWNOBJECT = 'Unknown'
-- a value the game keeps secret: STUB.secret stands for one (a table, so reckoning with it is an error)
STUB.secret = {}
function issecretvalue(value) return rawequal(value, STUB.secret) end
"""

# Races 0.1.2's reader of a shared course, as it was released (its Heard and Decode, less the chat line):
# what a player who has not updated makes of what 0.2.0 sends. OLD(sender, { text, ... }) returns the
# name and the course it would offer, or nothing.
OLD = r"""
return function(sender, messages)
    local function Clean(name)
        return ((name or ''):gsub('[|;:]', ''):gsub('^%s+', ''):gsub('%s+$', ''))
    end
    local function Decode(text)
        local parts = {}
        for piece in (text .. ';'):gmatch('([^;]*);') do parts[#parts + 1] = piece end
        if parts[1] ~= '1' or #parts < 5 then return nil end
        local course = { radius = tonumber(parts[2]) or 12, points = {} }
        for i = 4, #parts do
            local m, x, y = parts[i]:match('^(%d+),([%d%.]+),([%d%.]+)$')
            if not m then return nil end
            course.points[#course.points + 1] = { m = tonumber(m), x = tonumber(x), y = tonumber(y) }
        end
        return Clean(parts[3]), course
    end
    local incoming, name, course = {}, nil, nil
    for _, text in ipairs(messages) do
        local id, i, total, data = text:match('^(%d+):(%d+):(%d+):(.*)$')
        if id then
            i, total = tonumber(i), tonumber(total)
            local key = tostring(sender) .. id
            local got = incoming[key] or { parts = {}, count = 0 }
            incoming[key] = got
            if not got.parts[i] then got.count = got.count + 1 end
            got.parts[i] = data
            if got.count >= total then
                incoming[key] = nil
                name, course = Decode(table.concat(got.parts))
            end
        end
    end
    return name, course
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
    for addon in (BASE, SPARKLE, RACES):
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
    tables = {}
    for addon in (BASE, SPARKLE, RACES):
        tables[addon] = lua.table()
        for path in toc_files(os.path.join(ADDONS, addon), addon):
            load(open(path, encoding="utf-8").read(), "@" + addon + "/" + os.path.basename(path), addon, tables[addon])
        stub.Fire("ADDON_LOADED", addon)
    sparkle, races = tables[SPARKLE], tables[RACES]
    assert sparkle.linked and races.linked, "a tool did not join the base"
    race = lua.globals().SlashCmdList.PATCHWERKFOREVER_RACES
    sparkle_slash = lua.globals().SlashCmdList.PATCHWERKFOREVER_SPARKLE
    said = [0]

    def chat():
        new = list(stub.messages.values())[said[0]:]
        said[0] += len(new)
        for text in new:
            print("      chat: " + text.replace("|cff4dd2ff", "").replace("|cffffe680", "").replace("|cff66ff80", "")
                  .replace("|cffff6666", "").replace("|r", ""))
        problems = [t for t in new if "a problem" in t.lower() or "error" in t.lower()]
        assert not problems, problems
        # (a bar in a chat line begins an escape code: none but the colors' own in a line of Races')
        barred = [t for t in new if "Races|r: " in t and "|" in re.sub(r"\|c[0-9a-f]{8}|\|r", "", t)]
        assert not barred, barred
        return " / ".join(new)

    def run(seconds):                  # that long of the game, frame by frame
        for _ in range(int(seconds / 0.016) + 1):
            stub.time += 0.016
            stub.Frame()

    def step(label):
        print("  " + label)

    stub.player.x, stub.player.y, stub.player.map = -442.0, -2598.0, 1
    stub.Fire("PLAYER_LOGIN")
    stub.Fire("PLAYER_ENTERING_WORLD", True, False)
    chat()
    pages = sorted(stub.pages.keys())
    assert "Races: Marker" in pages and "Sparkle: Loot Wisps" in pages, pages
    on = lambda page: [s for s in stub.settings.values() if s.page == page]
    assert len(on("Races (Thread)")) == 8 and len(on("Races: Marker")) == 9 and len(on("Sparkle: Loot Wisps")) == 11, \
        (len(on("Races (Thread)")), len(on("Races: Marker")), len(on("Sparkle: Loot Wisps")))
    assert races.Get("rule") == "any" and races.Get("autoJoin") is False, "a new setting does not start as it should"
    # the key bindings in the family's own section of the Key Bindings page, each with a name and a function
    bindings = open(os.path.join(ADDONS, RACES, "Bindings.xml"), encoding="utf-8").read()
    assert bindings.count('category="BINDING_CATEGORY_PatchwerkForever"') == 5 and "ADDONS" not in bindings
    for name in re.findall(r'<Binding name="PATCHWERKFOREVER_RACES_(\w+)"', bindings):
        assert lua.globals()["BINDING_NAME_PATCHWERKFOREVER_RACES_" + name], name
        assert lua.globals()["PatchwerkForever_Thread_Races_" + name.title()], name

    # ------------------------------------------------------------------ the loot wisp
    step("an item from a loot window flies from the window to its bag, and the bag glows")
    G = lua.globals()
    G.LootFrame = G.CreateFrame("Frame")
    G.LootFrame.cx, G.LootFrame.cy = 300, 400
    G.CharacterBag1Slot = G.CreateFrame("Frame")
    G.CharacterBag1Slot.cx, G.CharacterBag1Slot.cy = 900, 40
    G.MainMenuBarBackpackButton = G.CreateFrame("Frame")
    G.MainMenuBarBackpackButton.cx, G.MainMenuBarBackpackButton.cy = 960, 40
    stub.Fire("LOOT_OPENED")
    stub.Fire("ITEM_PUSH", 2, 134400)
    assert sparkle.WispsInAir() == (1, 0), sparkle.WispsInAir()
    run(0.3)
    run(1.2)
    assert sparkle.WispsInAir() == (0, 0), "the wisp did not land and go: %s" % (sparkle.WispsInAir(),)
    stub.Fire("LOOT_CLOSED")
    chat()

    step("from the herb the sparkle was on, in the herb's colour; none from a merchant")
    stub.time += 10                                         # (the loot window is long closed)
    sparkle.spot = lua.table_from({"x": 520.0, "y": 300.0, "kind": "herb", "time": stub.time - 1})
    stub.Fire("ITEM_PUSH", 0, 134401)
    assert sparkle.WispsInAir() == (1, 0)
    run(1.5)
    stub.time += 10
    stub.Fire("MERCHANT_SHOW")
    stub.Fire("ITEM_PUSH", 0, 134402)
    assert sparkle.WispsInAir() == (0, 0), "a wisp for an item bought"
    sparkle.Set("wispWhen", "all")
    stub.Fire("ITEM_PUSH", 0, 134402)
    assert sparkle.WispsInAir() == (1, 0), "no wisp for an item bought with Every item"
    run(1.5)
    sparkle.Set("wispWhen", "loot")
    stub.Fire("MERCHANT_CLOSED")
    stub.Fire("ITEM_PUSH", 0, 134402)
    assert sparkle.WispsInAir() == (0, 0), "a wisp for an item that came from nowhere"

    step("twelve items at once: eight fly, four wait their turn, all land")
    stub.Fire("LOOT_OPENED")
    for i in range(12):
        stub.Fire("ITEM_PUSH", i % 5, 134400 + i)
    assert sparkle.WispsInAir() == (8, 4), sparkle.WispsInAir()
    run(4)
    assert sparkle.WispsInAir() == (0, 0), sparkle.WispsInAir()
    stub.Fire("LOOT_CLOSED")

    step("disabled: none; the preview and /sparkle wisp still work")
    stub.time += 10
    sparkle.Set("wisp", False)
    stub.Fire("LOOT_OPENED")
    stub.Fire("ITEM_PUSH", 0, 134400)
    assert sparkle.WispsInAir() == (0, 0)
    stub.Fire("LOOT_CLOSED")
    sparkle_slash("wisp")
    assert "disabled" in chat()
    run(1.5)
    sparkle.Set("wisp", True)
    G.MainMenuBarBackpackButton.shown = False               # (a UI with no bag bar: the corner)
    sparkle.WispTest()
    run(1.5)
    assert sparkle.WispsInAir() == (0, 0)
    chat()

    # ------------------------------------------------------------------ a course
    def walk(dx, dy):
        stub.player.x += dx
        stub.player.y += dy

    step("make a course as you ride: start, two checkpoints, the finish")
    race("start")
    assert "No course yet" in chat()
    race("new Crossroads Loop")
    assert "Start placed" in chat()
    walk(0, 80)
    race("mark")
    assert "Checkpoint 1 placed (80 yards" in chat()
    walk(3, 0)
    race("mark")
    assert "inside the last checkpoint" in chat()
    race("undo")
    walk(80, 0)
    race("mark")
    walk(0, -80)
    race("mark")
    race("save")
    assert "a start, 2 checkpoints and the finish." in chat()
    db = G.PatchwerkForever_Thread_RacesDB
    assert len(db.courses["Crossroads Loop"].points) == 4
    race("list")
    assert "3 checkpoints, 2" in chat()

    step("race it: the start is your pin and tracked, with the marker on the game's frame")
    stub.PinAt(1, 100.0, 100.0)                             # a pin of your own, put back afterwards
    mine = (stub.pin.uiMapID, stub.pin.position.x, stub.pin.position.y)
    walk(-200, 0)
    race("start")
    assert "Go to the start (" in chat()
    assert stub.superUser and races.aim.kind == "start"
    stub.nav = G.CreateFrame("Frame")
    stub.nav.cx, stub.nav.cy = 500, 350
    run(0.2)
    m = [f for f in stub.frames.values() if f.strata == "LOW"][0]
    assert m.shown and m.ring.shown and m.text.text.startswith("Start  "), m.text.text
    stub.navClamped = True
    run(0.1)
    assert m.shown and not m.ring.shown, "the ring drawn at the screen's edge"
    stub.navClamped = False

    step("reach the start: 3, 2, 1, go; each checkpoint a split; the finish a best run")
    stub.player.x, stub.player.y = -440.0, -2598.0           # (beside the start)
    run(0.2)
    assert races.racing.phase == "count"
    run(3.2)
    assert races.racing.phase == "run" and races.aim.words == "Checkpoint 1/2", races.aim.words
    run(1)
    walk(0, 80)
    run(5)
    assert races.aim.words == "Checkpoint 2/2" and "Checkpoint 1/2: 0:0" in chat()
    walk(80, 0)
    run(5)
    assert races.aim.kind == "finish"
    walk(0, -80)
    run(5)
    text = chat()
    assert "finished in 0:1" in text and "first time" in text, text
    best = db.courses["Crossroads Loop"].best
    assert best and 11 < best.time < 12, best.time
    assert races.racing is None and races.aim is None
    pin = stub.pin
    assert (pin.uiMapID, pin.position.x, pin.position.y) == mine, "the pin you had was not put back"
    assert stub.sounds > 4

    step("again, faster: a new best, ahead at each split; then slower: no new best")
    stub.player.x, stub.player.y = -440.0, -2598.0
    race("start")
    run(3.5)
    walk(0, 80); run(2)
    assert "(-" in chat()
    walk(80, 0); run(2)
    walk(0, -80); run(2)
    text = chat()
    assert "New best! -" in text, text
    assert db.courses["Crossroads Loop"].best.time < best.time + 0.01
    fast = db.courses["Crossroads Loop"].best.time
    stub.player.x, stub.player.y = -440.0, -2598.0
    race("start Crossroads Loop")
    run(3.5)
    walk(0, 80); run(8)
    walk(80, 0); run(2)
    walk(0, -80); run(2)
    text = chat()
    assert "Best 0:" in text and "+" in text and db.courses["Crossroads Loop"].best.time == fast, text
    race("best")
    assert "Best on \"Crossroads Loop\"" in chat()

    step("stopping a race: the pin is cleared when you had none")
    stub.pin = None
    race("start")
    assert stub.pin is not None
    race("stop")
    assert "Race stopped" in chat() and stub.pin is None and races.aim is None

    step("the pin moved by something else during a race is put back")
    race("start")
    stub.pin = None
    run(1.5)
    assert stub.pin is not None and races.aim.kind == "start"
    race("stop")
    chat()

    step("send a long course to your party; a party member keeps it")
    race("new Long Way")
    for i in range(15):
        walk(40, 7)
        race("mark")
    race("save")
    chat()
    race("share Long Way")
    assert "not in a group" in chat()
    stub.group = True
    race("share Long Way")
    sent = list(stub.sent.values())
    assert len(sent) >= 2 and all(s[4] is None and s[3] == "PARTY" for s in sent), len(sent)
    for s in sent:
        stub.Fire("CHAT_MSG_ADDON", s[1], s[2], s[3], "Walker-Realm")      # (your own: not offered to you)
    race("accept")
    assert "Nobody has sent you" in chat()
    for s in reversed(sent):                                             # (and in any order)
        stub.Fire("CHAT_MSG_ADDON", s[1], s[2], s[3], "Friend-Realm")
    assert "Friend-Realm sent you the course \"Long Way\" (15 checkpoints, Anything Goes)" in chat()
    race("accept")
    assert "\"Long Way (Friend)\" kept" in chat()
    a, b = db.courses["Long Way"].points, db.courses["Long Way (Friend)"].points
    assert len(a) == len(b) and all(abs(a[i].x - b[i].x) < 1e-4 and a[i].m == b[i].m for i in range(1, len(a) + 1))
    race("share Long Way Friend")
    assert stub.sent[len(stub.sent)][4] == "Friend" and stub.sent[len(stub.sent)][3] == "WHISPER"
    chat()

    # ------------------------------------------------------------------ a course's rule
    START, A, B, FINISH = (-440.0, -2598.0), (-442.0, -2518.0), (-359.0, -2518.0), (-359.0, -2598.0)
    loop = db.courses["Crossroads Loop"]

    def at(place):
        stub.player.x, stub.player.y = place

    def lap(pause, between=None):      # the loop alone, from the start to the finish; `between`: done on the way
        at(START)
        race("start Crossroads Loop")
        run(3.5)
        at(A); run(pause)
        if between:
            between()
        at(B); run(pause)
        at(FINISH); run(pause)

    def line(text, has):               # the one chat line with that in it
        found = [t for t in text.split(" / ") if has in t]
        assert len(found) == 1, (has, text)
        return found[0]

    step("a course's rule: Anything Goes until changed; On Foot keeps a best run of its own")
    assert loop.rule == "any" and db.courses["Long Way"].rule == "any", "a new course has no rule"
    loop.rule = None                                        # (as a course saved by 0.1.x is: no rule, one best run)
    race("list")
    assert "yards, Anything Goes, best %s" % races.Clock(fast) in line(chat(), "Crossroads Loop")
    race("rule")
    assert 'The rule of "Long Way (Friend)" is Anything Goes' in chat()
    race("rule bogus")
    assert "/race rule foot [name] for On Foot" in chat()
    race("rule foot Nowhere")
    assert 'No course named "Nowhere"' in chat()
    race("rule any Crossroads Loop")
    assert "already Anything Goes" in chat()
    race("rule foot Crossroads Loop")
    text = chat()
    assert 'The rule of "Crossroads Loop" is now On Foot' in text and "Its best run under Anything Goes is kept" in text, text
    assert loop.rule == "foot" and loop.best.time == fast and loop.footBest is None, "the best run did not stay where it was"
    race("list")
    assert line(chat(), "Crossroads Loop").endswith("yards, On Foot"), "the list shows a best run under the other rule"
    race("best Crossroads Loop")
    text = chat()
    assert '"Crossroads Loop" (On Foot) has not been finished yet' in text and "Its best under Anything Goes: 0:0" in text, text

    step("On Foot, on foot all the way: the run counts, as the first under that rule")
    lap(2)
    text = chat()
    assert 'Racing "Crossroads Loop" (On Foot): 3 checkpoints. Go to the start' in text, text
    assert "Your first time under On Foot" in text and "not count" not in text, text
    foot = loop.footBest.time
    assert 4 < foot < 5 and loop.best.time == fast, (foot, fast)
    race("list")
    assert "On Foot, best 0:04" in line(chat(), "Crossroads Loop")

    step("mounted for a moment on the way: said once, the race goes on, no best run from it")
    def mount():
        stub.mounted = True
        run(0.3)
        stub.mounted = False
    lap(0.5, mount)                                         # (faster than the best: it would have been one)
    text = chat()
    assert text.count("will not count: the course is On Foot and you mounted") == 1, text
    assert "Does not count: On Foot, and you mounted" in text and "New best" not in text, text
    assert loop.footBest.time == foot and loop.best.time == fast and races.racing is None
    banner = [f for f in stub.frames.values() if f.strata == "HIGH"][0]
    assert "Does not count" in banner.small.text, banner.small.text

    step("on a flight path: the same; mounted only during the countdown: the run counts")
    def fly():
        stub.player.taxi = True
        run(0.3)
        stub.player.taxi = False
    lap(0.5, fly)
    text = chat()
    assert text.count("On Foot and you took a flight path") == 1 and loop.footBest.time == foot, text
    at(START)
    race("start Crossroads Loop")
    stub.mounted = True
    run(2.5)
    assert races.racing.phase == "count"
    stub.mounted = False
    run(1)
    at(A); run(1.5); at(B); run(1.5); at(FINISH); run(1.5)
    text = chat()
    assert "New best! -" in text and "not count" not in text and loop.footBest.time < foot, text
    foot = loop.footBest.time

    step("the game keeps its answer secret, or lacks the function: not judged, and no error")
    is_mounted, on_taxi = G.IsMounted, G.UnitOnTaxi
    G.IsMounted = lua.eval("function() return STUB.secret end")
    G.UnitOnTaxi = lua.eval("function() error('not here') end")
    lap(1)
    text = chat()
    assert "New best! -" in text and "not count" not in text, text
    G.IsMounted, G.UnitOnTaxi = None, None
    lap(0.5)
    text = chat()
    assert "On Foot cannot be judged" in text and "New best! -" in text, text
    G.IsMounted, G.UnitOnTaxi = is_mounted, on_taxi
    foot = loop.footBest.time

    step("back to Anything Goes: its best run is still there, and mounted counts")
    race("rule any Crossroads Loop")
    assert "Its best run under On Foot is kept" in chat()
    race("best Crossroads Loop")
    text = chat()
    assert 'Best on "Crossroads Loop" (Anything Goes): %s' % races.Clock(fast) in text, text
    assert "Its best under On Foot: %s" % races.Clock(foot) in text, text
    stub.mounted = True
    lap(3)
    stub.mounted = False
    text = chat()
    assert "Best %s" % races.Clock(fast) in text and "not count" not in text, text
    race("reset Crossroads Loop")
    assert 'Best run on "Crossroads Loop" under Anything Goes forgotten' in chat()
    assert loop.best is None and loop.footBest.time == foot, "forgetting one rule's best run took the other's"
    lap(2)
    assert "Your first time under Anything Goes" in chat()
    fast = loop.best.time

    step("Rule For New Courses: a course made with it set to On Foot is On Foot")
    races.Set("rule", "foot")
    at((-700.0, -2700.0))
    race("new Short Hop")
    stub.player.y += 60
    race("mark")
    race("save")
    assert "Its rule is On Foot" in chat() and db.courses["Short Hop"].rule == "foot"
    races.Set("rule", "any")

    step("the rule goes with a shared course, in a message Races 0.1.2 passes over")
    heard = lambda text, who="Mira-Realm", channel="PARTY": stub.Fire("CHAT_MSG_ADDON", "PWFRace", text, channel, who)
    since = lambda n: [s[2] for s in list(stub.sent.values())[n:]]
    old = lua.execute(OLD)
    n = len(stub.sent)
    race("share Short Hop")
    sent = since(n)
    assert re.match(r"^R:\d+:foot$", sent[0]) and len(sent) == 2, sent
    name, course = old("Walker-Realm", lua.table_from(sent))
    assert name == "Short Hop" and len(course.points) == 2 and course.radius == 12, "0.1.2 cannot read a course from 0.2.0"
    for text in sent:                                       # (0.2.0 reads it, with its rule)
        heard(text)
    assert 'Mira-Realm sent you the course "Short Hop" (1 checkpoint, On Foot)' in chat()
    for text in reversed(sent):                             # (the rule last: it still reaches the course)
        heard(text, "Tovin-Realm")
    chat()
    for text in ("R:12:fly", "R:1234567:foot", "R:12:foot:more", "R::foot"):      # (not a rule, or not its shape)
        heard(text, "Tovin-Realm")
    race("accept")
    assert '"Short Hop (Tovin)" kept (On Foot)' in chat() and db.courses["Short Hop (Tovin)"].rule == "foot"
    assert db.courses["Long Way (Friend)"].rule == "any", "a course from 0.1.x is not Anything Goes"
    n = len(stub.sent)
    race("share Crossroads Loop")                           # (Anything Goes: nothing more than 0.1.x sent)
    assert not [t for t in since(n) if t.startswith("R:")]
    heard(stub.secret)                                      # (a message the game keeps secret: passed over)
    heard("R:12:foot", stub.secret)
    race("delete Short Hop (Tovin)")
    chat()

    # ------------------------------------------------------------------ racing together
    mark = races.Fingerprint(loop)
    assert mark == races.Fingerprint(lua.eval("PatchwerkForever_Thread_RacesDB.courses['Crossroads Loop']")) and \
        mark != races.Fingerprint(db.courses["Long Way"]) and mark.isdigit()

    step("race together: not without a group; you invite, two join, and nothing starts before the start is given")
    stub.group = False
    race("together Crossroads Loop")
    assert "You are not in a group" in chat() and races.racing is None
    race("join")
    assert "Nobody has invited you" in chat()
    stub.group = True
    stub.party = lua.table_from(["Mira", "Tovin"])
    at((-600.0, -2598.0))
    n = len(stub.sent)
    race("together Crossroads Loop")
    sent = since(n)
    invite = re.match(r"^I:(\d{6}):(\d+):any:Crossroads Loop$", sent[0])
    assert invite and len(sent) == 1 and invite.group(2) == mark and stub.sent[len(stub.sent)][3] == "PARTY", sent
    rid = invite.group(1)
    assert 'Your group is invited to race "Crossroads Loop" (Anything Goes, 3 checkpoints)' in chat()
    heard("J:" + rid)
    heard("J:" + rid, "Tovin-Realm")
    heard("J:" + rid, "Tovin-Realm")                        # (said twice: one racer)
    text = chat()
    assert "Mira joined the race (2 racers)" in text and text.count("Tovin joined the race (3 racers)") == 1, text
    race("go")
    assert "Go to the start first" in chat() and races.racing.phase == "start"
    at(START)
    run(1)
    assert races.racing.phase == "start", "the clock started before the start was given"
    assert chat().count("You are at the start") == 1
    run(1)
    assert chat() == "" and "/race go" in banner.small.text

    step("the start, by the same command again: one message, and the countdown")
    n = len(stub.sent)
    race("together")
    assert since(n) == ["G:%s:3" % rid] and races.racing.phase == "count"
    run(3.2)
    assert races.racing.phase == "run"
    chat()

    step("at a checkpoint your time goes to the group; you see the racer ahead, and your lead when it is known")
    heard("C:%s:2:0.50" % rid)                              # (Mira was there after half a second)
    run(1)
    at(A)
    n = len(stub.sent)
    run(0.2)
    sent = since(n)
    assert len(sent) == 1 and re.match(r"^C:%s:2:1\.\d\d$" % rid, sent[0]), sent
    text = chat()
    assert "Checkpoint 1/2: 0:01." in text and "|cffff6666Mira +0." in text and " s|r" in text, text
    assert "|cffff6666Mira +0." in banner.small.text
    at(B)                                                   # (the first there: nobody to compare with yet)
    n = len(stub.sent)
    run(0.2)
    assert len(since(n)) == 1 and since(n)[0].startswith("C:%s:3:" % rid)
    assert "Mira" not in chat() and races.racing.leading == 3
    heard("C:%s:3:9.00" % rid, "Tovin-Realm")               # (Tovin's times arrive in the wrong order)
    text = chat()
    assert "Checkpoint 2/2: |cff66ff80Tovin -7." in text and banner.big.text.startswith("Tovin -7."), text
    heard("C:%s:2:4.00" % rid, "Tovin-Realm")
    heard("C:%s:3:1.00" % rid)                              # (and Mira's late: said once a checkpoint, no more)
    heard("C:%s:3:0.10" % rid)                              # (a second time for the same checkpoint: not taken)
    assert chat() == ""
    state = races.TogetherState()
    assert state.racers["Tovin-Realm"].splits[2] == 4 and state.racers["Mira-Realm"].splits[3] == 1 and state.count == 3

    step("a racer leaves the group: not finished. The placings as each racer finishes, on screen and in chat")
    stub.party = lua.table_from([stub.secret, "Tovin"])     # (the game will not name a member just now: nobody judged)
    stub.Fire("GROUP_ROSTER_UPDATE")
    stub.party = lua.table_from(["Unknown", "Tovin"])       # (nor one who is not loaded yet)
    stub.Fire("GROUP_ROSTER_UPDATE")
    assert not state.racers["Mira-Realm"].out
    stub.party = lua.table_from(["Mira"])
    stub.Fire("GROUP_ROSTER_UPDATE")
    assert state.racers["Tovin-Realm"].out and chat() == ""
    heard("F:%s:6.20:0" % rid)
    text = chat()
    assert 'Placings on "Crossroads Loop": 1. Mira  0:06.2.' in text, text
    assert banner.big.text == "Mira  0:06.2" and "1. Mira  0:06.2\nNot finished: Tovin" == banner.small.text, banner.small.text
    run(5)
    at(FINISH)
    n = len(stub.sent)
    run(0.2)
    sent = since(n)
    assert len(sent) == 1 and re.match(r"^F:%s:\d+\.\d\d:0$" % rid, sent[0]), sent
    text = chat()
    assert '"Crossroads Loop" finished in 0:0' in text and "Best %s" % races.Clock(fast) in text, text
    assert 'Final placings on "Crossroads Loop": 1. Mira  0:06.2; 2. Walker  0:0' in text and "Not finished: Tovin." in text, text
    assert "\n1. Mira  0:06.2\n2. Walker  0:0" in banner.small.text, banner.small.text
    assert races.TogetherState() is None and races.racing is None and loop.best.time == fast

    step("invited: nothing is sent before you join; not at the start when it is given, you are not in the race")
    stub.party = lua.table_from(["Mira", "Tovin"])
    stub.time += 10
    at((-600.0, -2598.0))
    n = len(stub.sent)
    heard("I:777001:%s:foot:The Loop" % mark)               # (Mira's name for it; yours is found by its checkpoints)
    assert 'Mira invites your group to race "Crossroads Loop" (On Foot, 3 checkpoints). /race join' in chat()
    assert since(n) == [] and races.racing is None
    race("join")
    assert since(n) == ["J:777001"] and "You joined Mira's race on \"Crossroads Loop\" (On Foot)" in chat()
    race("join")
    assert "already in this race" in chat()
    race("go")
    assert "Only Mira can start this race" in chat() and races.racing.phase == "start"
    heard("G:777001:3", "Tovin-Realm")                      # (the start from one who did not invite: nothing)
    heard("G:777001:3", "Mira-Realm", "WHISPER")            # (or by whisper)
    heard("G:777001:30")                                    # (or a countdown of half a minute)
    assert races.racing.phase == "start" and races.TogetherState().state == "gather"
    heard("G:777001:3")
    assert "Mira gave the start and you were not at the start, so you are not in this race" in chat()
    assert since(n) == ["J:777001", "O:777001"] and races.racing is None and races.TogetherState() is None

    step("joined and at the start: the countdown sent, the inviter's rule, and a run that does not count still places")
    stub.time += 10
    n = len(stub.sent)
    heard("I:777002:%s:foot:The Loop" % mark)
    race("join")
    at(START)
    run(0.5)
    assert "You are at the start. Mira starts the race." in chat() and "Waiting for Mira" in banner.small.text
    heard("F:777002:20.00:0", "Tovin-Realm")                # (a finish before the start, from one never seen to join)
    heard("J:777002", "Tovin-Realm")
    heard("G:777002:0")                                     # (no countdown, though yours is enabled)
    assert races.racing.phase == "run" and races.racing.rule == "foot" and loop.rule == "any"
    chat()
    at(A); run(0.5)
    mount()
    at(B); run(0.5)
    at(FINISH); run(0.5)
    sent = since(n)
    assert len(sent) == 4 and sent[0] == "J:777002" and sent[1].startswith("C:777002:2:") and \
        sent[2].startswith("C:777002:3:") and re.match(r"^F:777002:\d+\.\d\d:1$", sent[3]), sent
    text = chat()
    assert text.count("will not count") == 1 and "Does not count: On Foot, and you mounted" in text, text
    assert 'Placings on "Crossroads Loop": 1. Walker  0:01.' in text and "(does not count); 2. Tovin  0:20.0." in text, text
    assert loop.footBest.time == foot and loop.best.time == fast, "a best run kept from a run that does not count"
    heard("Q:777002")                                       # (Mira stops: everyone is accounted for)
    text = chat()
    assert "Final placings" in text and "Not finished: Mira." in text and races.TogetherState() is None, text

    step("invited to a course you lack: told to ask for it; sent and kept, you can join. The race called off")
    stub.time += 10
    far_run = lua.eval("{ radius = 12, points = { { m = 1414, x = 0.4700, y = 0.5100 }, { m = 1414, x = 0.4710, y = 0.5100 },"
                       " { m = 1414, x = 0.4720, y = 0.5110 } } }")
    n = len(stub.sent)
    heard("I:777003:%s:any:Far Run" % races.Fingerprint(far_run))
    assert 'Mira invites your group to race "Far Run", a course you do not have. Ask for it' in chat()
    race("join")
    assert 'You do not have the course "Far Run". Ask Mira for it' in chat() and races.racing is None
    heard("77:1:1:" + races.Encode("Far Run", far_run))
    race("accept")
    assert "kept (Anything Goes)" in chat()
    race("join")
    assert since(n) == ["J:777003"] and "You joined Mira's race on \"Far Run\"" in chat()
    heard("O:777003", "Tovin-Realm")                        # (one who was never in it leaves: nothing)
    heard("O:777003")
    assert "Mira called the race off" in chat() and races.racing is None and races.TogetherState() is None
    race("delete Far Run")
    chat()

    step("Join Party Races Automatically: joined without asking, but not while you are racing")
    stub.time += 10
    races.Set("autoJoin", True)
    n = len(stub.sent)
    heard("I:777004:%s:any:Crossroads Loop" % mark)
    assert "You joined Mira's race" in chat() and since(n) == ["J:777004"]
    heard("I:777009:%s:any:Crossroads Loop" % mark, "Tovin-Realm")      # (in a race: not taken into another)
    assert chat() == "" and races.TogetherState().id == "777004"
    race("stop")                                            # (leaving before the start: the invitation stands)
    assert "Race stopped" in chat() and since(n) == ["J:777004", "O:777004"] and not races.TogetherState().joined
    G.PatchwerkForever_Thread_Races_Join()
    assert "You joined Mira's race" in chat() and since(n)[2:] == ["J:777004"]
    stub.party = lua.table_from(["Tovin"])                  # (the one who invited leaves the group)
    stub.Fire("GROUP_ROSTER_UPDATE")
    assert "Mira called the race off" in chat() and races.racing is None
    stub.party = lua.table_from(["Mira", "Tovin"])
    race("start Crossroads Loop")
    heard("I:777005:%s:any:Crossroads Loop" % mark)
    text = chat()
    assert "Mira invites your group" in text and "You joined" not in text and races.racing.together is None, text
    race("stop")
    races.Set("autoJoin", False)
    chat()

    step("what arrives is checked: wrong shapes, sizes, races and senders do nothing; no more racers than a raid")
    race("join")
    at(START)
    run(0.5)
    heard("G:777005:0")
    chat()
    state = races.TogetherState()
    long_name = "x" * 150
    for bad in ("C:777005:2:nan", "C:777005:2:1e9", "C:777005:2:999999999", "C:777005:2:99999999999", "C:777005:99:1.00",
                "C:777005:1:1.00", "C:777005:4:1.00", "C:777005:2:-1", "C:777005:2:1.00:9", "C:777005:2", "C:777005::",
                "C:999999:2:1.00", "C:7770050:2:1.00", "F:777005:5.00:2", "F:777005:5.00", "F:777005::0", "F:777005:0x10:0",
                "G:777005:3", "J:777005:x", "Q:777005x", "Q:", "X:777005", "Z:", "I:1:2:any:", "I:777007:%s:fly:Name" % mark,
                "I:777007:%s:any:%s" % (mark, long_name), "I:777007:abc:any:Name", "C:" + "9" * 250, "C:777005:2:" + "1" * 300):
        heard(bad)
    heard("C:777005:2:1.00", "Mira-Realm", "WHISPER")
    heard("F:777005:5.00:0", "Mira-Realm", "GUILD")
    heard("C:777005:2:1.00", "Walker-Realm")                # (your own, come back to you)
    mira = state.racers["Mira-Realm"]
    assert chat() == "" and mira.time is None and len(mira.splits) == 0 and state.count == 2 and state.id == "777005"
    for i in range(60):
        heard("J:777005", "Racer%d-Realm" % i)
    assert state.count == 40, state.count
    n = len(stub.sent)
    race("stop")                                            # (stopping after the start: not finished)
    assert since(n) == ["Q:777005"] and state.racers[""].out
    stub.time += 10
    heard("I:777008:1:any:|cffff0000|Hitem:1|h[Loop]|h|r\n")           # (a name that would draw a link in chat)
    text = chat()
    assert 'race "cffff0000Hitem1h[Loop]hr", a course you do not have' in text and "|H" not in text, text

    step("the invitation or the start refused by the game, or no addon messages at all: said, and no race left over")
    stub.time += 10
    stub.sendResult = 11
    race("together Crossroads Loop")
    assert "The invitation could not be sent just now" in chat() and races.racing is None and races.TogetherState() is None
    stub.sendResult = None
    race("together Crossroads Loop")
    at(START)
    run(0.5)
    stub.sendResult = 11
    G.PatchwerkForever_Thread_Races_Together()
    assert "The start could not be sent just now" in chat() and races.racing.phase == "start"
    stub.sendResult = None
    race("stop")
    assert "The race together is called off" in chat() and races.TogetherState() is None
    send = G.C_ChatInfo.SendAddonMessage
    G.C_ChatInfo.SendAddonMessage = None
    race("together Crossroads Loop")
    assert "cannot send addon messages" in chat() and races.racing is None
    G.C_ChatInfo.SendAddonMessage = lua.eval("function() return STUB.secret end")    # (an answer kept secret: taken as sent)
    race("together Crossroads Loop")
    assert "Your group is invited" in chat()
    G.C_ChatInfo.SendAddonMessage = send

    step("nobody joins: you race alone, with no placings. Leaving the group during a race: it goes on alone")
    n = len(stub.sent)
    race("together Long Way")                               # (another course: the first race is called off)
    text = chat()
    assert "The race together is called off" in text and 'invited to race "Long Way"' in text, text
    race("together Crossroads Loop")
    at(START)
    run(0.5)
    races.Set("countdown", False)
    race("go")
    assert "Nobody joined: you race alone" in chat() and races.racing.phase == "run"
    # (each race called off before the next invitation; the start with no countdown, as yours is disabled)
    assert [t[:1] for t in since(n)] == ["O", "I", "O", "I", "G"] and since(n)[-1].endswith(":0"), since(n)
    races.Set("countdown", True)
    at(A); run(0.5)
    n = len(stub.sent)
    stub.group = False
    stub.Fire("GROUP_ROSTER_UPDATE")
    assert "You are no longer in a group. The race goes on alone." in chat() and races.racing.together is None
    at(B); run(0.5)
    at(FINISH); run(0.5)
    text = chat()
    assert "New best! -" in text and "lacings" not in text and since(n) == [], text
    fast = loop.best.time

    step("you invite and stop after the start: listed as not finished when the others are done")
    stub.group = True
    race("together Crossroads Loop")
    rid = stub.sent[len(stub.sent)][2].split(":")[1]
    heard("J:" + rid)
    at(START)
    run(0.5)
    race("go")
    run(3.5)
    race("stop")
    assert stub.sent[len(stub.sent)][2] == "Q:" + rid and races.TogetherState() is not None
    chat()
    heard("F:%s:9.90:1" % rid)
    text = chat()
    assert 'Final placings on "Crossroads Loop": 1. Mira  0:09.9 (does not count). Not finished: Walker.' in text, text
    assert races.TogetherState() is None and "Mira" not in banner.big.text, "a banner for a race you stopped"
    stub.group = False

    step("the rest of the commands, the key bindings and the preview")
    for words in ("", "help", "delete", "delete Long Way (Friend)", "reset Crossroads Loop", "cancel", "undo", "mark"):
        race(words)
    G.PatchwerkForever_Thread_Races_Together()
    G.PatchwerkForever_Thread_Races_Join()
    G.PatchwerkForever_Thread_Races_Start()
    G.PatchwerkForever_Thread_Races_Stop()
    G.PatchwerkForever_Thread_Races_Mark()
    races.MarkerTest()
    run(0.5)
    stub.RunAfters()
    run(0.1)
    text = chat()
    assert "deleted" in text and "forgotten" in text, text
    assert "  /race accept: keep a course you were sent" in text, "the help is not one command to a line"
    print("all steps ran")


if __name__ == "__main__":
    main()
