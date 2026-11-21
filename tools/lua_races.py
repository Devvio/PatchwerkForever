"""Run Races (Thread) and Sparkle (Thread)'s loot wisp outside the game, on the base, against the stand-in
for the game (wowstub.lua) with what these two need added to it.

    python lua_races.py

Plays: making a course as you ride it, racing it twice (a best run, then a slower one), the marker on
the game's waypoint frame, the pin you had put back, sending a course to a party member; and items
going into your bags from a loot window, from a herb you were sparkling on, from a merchant (no wisp),
and many at once. It fails loudly on any Lua error.

What this proves: the addons' own code runs and does sensible things with the stand-in's answers.
What it cannot prove: that the game's waypoint frame sits where the ring should be drawn, or that the
wisp looks right. That is for the game.
"""
import os
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
        STUB.sent[#STUB.sent + 1] = { prefix, text, channel, target }
    end }
function IsInGroup() return STUB.group end
function IsInRaid() return false end
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
            print("      chat: " + text.replace("|cff4dd2ff", "").replace("|cffffe680", "").replace("|r", ""))
        problems = [t for t in new if "a problem" in t.lower() or "error" in t.lower()]
        assert not problems, problems
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
    assert len(on("Races (Thread)")) == 6 and len(on("Races: Marker")) == 9 and len(on("Sparkle: Loot Wisps")) == 8, \
        (len(on("Races (Thread)")), len(on("Races: Marker")), len(on("Sparkle: Loot Wisps")))
    # the key bindings in the family's own section of the Key Bindings page
    bindings = open(os.path.join(ADDONS, RACES, "Bindings.xml"), encoding="utf-8").read()
    assert bindings.count('category="BINDING_CATEGORY_PatchwerkForever"') == 3 and "ADDONS" not in bindings

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
    assert "Friend-Realm sent you the course \"Long Way\" (15 checkpoints)" in chat()
    race("accept")
    assert "\"Long Way (Friend)\" kept" in chat()
    a, b = db.courses["Long Way"].points, db.courses["Long Way (Friend)"].points
    assert len(a) == len(b) and all(abs(a[i].x - b[i].x) < 1e-4 and a[i].m == b[i].m for i in range(1, len(a) + 1))
    race("share Long Way Friend")
    assert stub.sent[len(stub.sent)][4] == "Friend" and stub.sent[len(stub.sent)][3] == "WHISPER"
    chat()

    step("the rest of the commands, the key bindings and the preview")
    for words in ("", "help", "delete", "delete Long Way (Friend)", "reset Crossroads Loop", "cancel", "undo", "mark"):
        race(words)
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
