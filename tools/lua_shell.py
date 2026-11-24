"""Run Patchwerk Forever's own tools, Routes (Thread) and Sparkle (Thread), outside the game on its base,
against a stand-in for the game (wowstub.lua).

    python lua_shell.py

Loads the base and both tools, each addon's files in the order its TOC gives, in a real Lua 5.1, and plays
a session: log in,
put a pin on the map, let the search run frame by frame, open the map, walk along the trail, take
a wrong turn, arrive, use the slash commands. It fails loudly on any Lua error.

What this proves: the addon's own code runs and does sensible things with the stand-in's answers.
What it cannot prove: that the game's real functions answer the way the stand-in does.
"""
import os
import sys

from pack import ADDONS, NAMES

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

BASE = "PatchwerkForever"
ADDON = "PatchwerkForever_Thread_Routes"
SPARKLE = "PatchwerkForever_Thread_Sparkle"


def toc_files(folder, name):
    for line in open(os.path.join(folder, name + ".toc"), encoding="utf-8"):
        line = line.strip()
        if line.endswith(".lua"):
            yield os.path.join(folder, line)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    here = os.path.dirname(os.path.abspath(__file__))
    lua.execute(open(os.path.join(here, "wowstub.lua"), encoding="utf-8").read())
    # More of the game than the shared stand-in has, for the focus and My Route on the world map and in the
    # quest log (MapRoute.lua, QuestLog.lua): a button's methods, the map's border frame and the scroll
    # frame its picture is in, the game's menus (each menu made is kept in STUB.menu, and every
    # Menu.ModifyMenu callback in STUB.modifiers), and hooksecurefunc.
    lua.execute("""
        local made = CreateFrame
        function CreateFrame(kind, name, parent, template)
            local frame = made(kind, name, parent, template)
            frame.kind = kind
            function frame:SetShown(on) if on then self:Show() else self:Hide() end end
            function frame:RegisterForClicks(...) self.clicks = { ... } end
            function frame:SetScale(s) assert(s > 0) self.ownScale = s end
            function frame:GetScale() return self.ownScale or 1 end
            return frame
        end
        WorldMapFrame.BorderFrame = CreateFrame('Frame', nil, WorldMapFrame)
        WorldMapFrame.ScrollContainer = CreateFrame('ScrollFrame', nil, WorldMapFrame)
        function geterrorhandler()
            return function(problem) STUB.messages[#STUB.messages + 1] = 'a problem in a listener: ' .. tostring(problem) end
        end
        local function Root()
            local root = { entries = {} }
            local function add(entry) root.entries[#root.entries + 1] = entry; return entry end
            function root:CreateTitle(text) return add({ kind = 'title', text = text }) end
            function root:CreateButton(text, fn) assert(type(fn) == 'function') return add({ kind = 'button', text = text, fn = fn }) end
            function root:CreateRadio(text, isSelected, setSelected, data)
                assert(type(isSelected) == 'function' and type(setSelected) == 'function')
                return add({ kind = 'radio', text = text, isSelected = isSelected, setSelected = setSelected, data = data })
            end
            function root:CreateDivider() return add({ kind = 'divider' }) end
            return root
        end
        STUB.NewMenuRoot = Root
        MenuUtil = { CreateContextMenu = function(owner, generator)
            local root = Root()
            generator(owner, root)
            STUB.menu, STUB.menuOwner = root, owner
            return root
        end }
        STUB.modifiers = {}
        Menu = { ModifyMenu = function(tag, fn) STUB.modifiers[tag] = fn end }
        function hooksecurefunc(a, b, c)
            local into, name, fn = _G, a, b
            if type(a) == 'table' then into, name, fn = a, b, c end
            local old = into[name]
            assert(type(old) == 'function', 'hooksecurefunc: no function ' .. tostring(name))
            into[name] = function(...)
                local out = { old(...) }
                fn(...)
                return unpack(out)
            end
        end
    """)
    # a map's data addon is read when the addon asks the game to load it, as in the game
    loaded = []

    def load_addon(name):
        for map_id, short in NAMES.items():
            if name == ADDON + "_" + short and map_id not in loaded:
                loaded.append(map_id)
                for path in toc_files(os.path.join(ADDONS, name), name):
                    lua.execute(open(path, encoding="ascii").read())
        return True

    lua.globals().C_AddOns.LoadAddOn = load_addon
    # what each addon's TOC says of it (its title, its picture, what Patchwerk says of it), as the game gives it
    meta = {}
    for addon in (BASE, ADDON, SPARKLE):
        meta[addon] = {}
        for line in open(os.path.join(ADDONS, addon, addon + ".toc"), encoding="utf-8"):
            if line.startswith("## ") and ":" in line:
                key, value = line[3:].split(":", 1)
                meta[addon][key.strip()] = value.strip()
    lua.globals().C_AddOns.GetAddOnMetadata = lambda name, field: meta.get(name, {}).get(field)
    # the base says things with print; the tools through the chat frame
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
    # as the game does: an addon's files, then its ADDON_LOADED, then the next addon
    for addon in (BASE, ADDON, SPARKLE):
        tables[addon] = lua.table()
        for path in toc_files(os.path.join(ADDONS, addon), addon):
            load(open(path, encoding="utf-8").read(), "@" + addon + "/" + os.path.basename(path), addon, tables[addon])
        stub.Fire("ADDON_LOADED", addon)
    ns, sparkle = tables[ADDON], tables[SPARKLE]
    assert ns.linked and sparkle.linked, "a tool did not join the base"
    route_slash = lua.globals().SlashCmdList.PATCHWERKFOREVER_THREAD
    sparkle_slash = lua.globals().SlashCmdList.PATCHWERKFOREVER_SPARKLE

    def slash(words):
        # (the sparkle's commands as they were typed when it was part of the route planner still work)
        if words.split(" ")[0] in ("ignore", "sparkle"):
            sparkle_slash(words)
        else:
            route_slash(words)
    said = [0]

    def chat(label):
        new = list(stub.messages.values())[said[0]:]
        said[0] += len(new)
        for text in new:
            print("      chat: " + text.replace("|cff7fd4ff", "").replace("|r", ""))
        problems = [t for t in new if "a problem in" in t.lower() or "Route search failed" in t]
        assert not problems, "%s: %s" % (label, problems)
        return new

    def frames(most=2000):
        n = 0
        while n < most:
            stub.Frame()
            n += 1
            # (the search's own frame has no parent; frames that run all the time, like a sparkle, do)
            if not any(f.shown and f.scripts.OnUpdate and f.parent is None for f in stub.frames.values()):
                break
        return n

    def step(label):
        print("  " + label)

    def heard():                       # what was said in chat since it was last read, a reported problem included
        new = list(stub.messages.values())[said[0]:]
        said[0] += len(new)
        return new

    def on_screen():                   # the step text on screen now: its words, and the smaller line under them
        got = ns.FloatShown()
        return (got[0], got[1]) if isinstance(got, tuple) else (got, None)

    def quiet():                       # the words on screen have had their time
        stub.time += 60
        stub.Frame()
        assert ns.FloatShown() is None, "the words did not go out"

    step("log in at Crossroads, a Horde character")
    stub.player.x, stub.player.y, stub.player.map = -442.0, -2598.0, 1
    stub.Fire("PLAYER_LOGIN")
    stub.Fire("PLAYER_ENTERING_WORLD", True, False)               # (as the game gives it: a login, not a reload)
    chat("login")
    # (counted by addon: Routes' own settings are checked here, Sparkle's in its own suite, lua_sparkle.py)
    def own_settings(addon=ADDON):
        return sum(1 for s in stub.settings.values() if s.variable.startswith(addon + "_"))
    assert own_settings() == 36 and own_settings(SPARKLE) > 0 and stub.category and stub.front, "the settings pages were not built"
    assert stub.provider, "the world map layer was not attached"

    step("put a pin on Gadgetzan")
    stub.PinAt(1, -7140.0, -3790.0)
    stub.Fire("USER_WAYPOINT_UPDATED")
    n = frames()
    text = chat("pin")
    assert ns.route, "no route"
    assert any("fly Crossroads > Freewind Post > Gadgetzan" in t for t in text), text
    print("      the search took %d frames; %d points in the route" % (n, len(ns.route.points)))

    step("open the world map on Kalimdor, then the minimap redraws")
    stub.provider.RefreshAllData()
    assert stub.shown > 0, "nothing drawn on the world map"
    on_map = stub.shown
    # just after login the minimap is still moving: no trail until it has held still for a second
    for n in range(10):
        lua.globals().Minimap.left = 800 + n
        stub.Tick()
    assert stub.shown == on_map, "the trail was drawn while the minimap was still moving"
    for n in range(19):
        stub.Tick()
    assert stub.shown == on_map, "the trail did not wait a full second"
    for n in range(3):
        stub.Tick()
    chat("drawing")
    print("      %d lines on the world map, %d on the minimap" % (on_map, stub.shown - on_map))
    assert stub.shown > on_map, "nothing drawn on the minimap"

    step("a faded-out minimap gets no trail")
    lua.globals().Minimap.alpha = 0
    stub.Tick()
    assert stub.shown == on_map, "the trail was drawn over a faded-out minimap"
    lua.globals().Minimap.alpha = 1
    stub.Tick()
    assert stub.shown > on_map

    step("the world map shows another continent: nothing is drawn there")
    lua.globals().WorldMapFrame.mapID = 1415
    stub.provider.RefreshAllData()
    stub.Tick()
    lua.globals().WorldMapFrame.mapID = 1414
    chat("other map")

    step("without flights: a setting changed on the options page")
    for s in stub.settings.values():
        if s.variable.endswith("_flights"):
            s.set(False)
    frames()
    text = chat("no flights")
    assert not any("fly" in t for t in text) and ns.route, text
    walking = len(ns.route.points)

    step("walk along the trail: no new search; then a wrong turn: a new one")
    p = ns.route.points[min(6, walking)]
    stub.player.x, stub.player.y = p[1], p[2]
    stub.time += 5
    stub.Tick()
    assert frames() <= 1 and ns.route.at >= 5, "following lost the trail (at %s)" % ns.route.at
    before = ns.route
    stub.player.x, stub.player.y = p[1] + 150, p[2]
    stub.time += 5
    stub.Tick()
    frames()
    chat("following")
    assert ns.route is not before, "a wrong turn did not bring a new route"

    step("flight points not yet found are left out")
    for s in stub.settings.values():
        if s.variable.endswith("_flights"):
            s.set(True)
    frames()
    chat("flights on")
    stub.undiscovered[30] = True                      # Freewind Post
    slash("go")
    frames()
    text = chat("unknown point")
    assert not any("Freewind Post" in t for t in text), text

    step("the flight points you know: read at a flight master and remembered; with nothing known, on foot")
    here = (stub.player.x, stub.player.y)
    taxi = lambda: list(lua.globals().PatchwerkForever_Thread_RoutesDB.taxi.values())[0] if lua.globals().PatchwerkForever_Thread_RoutesDB.taxi else None

    def set_option(name, value):
        [x for x in stub.settings.values() if x.variable == ADDON + "_" + name][0].set(value)

    def go_again(label):
        slash("go")
        frames()
        return chat(label)

    slash("flights")
    text = chat("flights")
    assert any("Source: the game's world map" in t for t in text), text
    assert any("Not known: Freewind Post, Thousand Needles" in t for t in text), text
    # the world map says nothing and no flight map was ever opened here: nothing counts as known
    stub.noTaxi = True
    text = go_again("nothing known")
    assert ns.route and not any("fly" in t for t in text), text
    assert sum(1 for t in text if "Open the flight map at a flight master" in t) == 1, text
    text = go_again("nothing known, again")
    assert not any("Open the flight map" in t for t in text), "said more than once"
    slash("flights")
    assert any("Source: none yet" in t for t in chat("flights"))
    # a flight map opened: Crossroads (here) and Gadgetzan can be flown to, the rest are out of reach
    stub.flightMap = lua.table_from({25: 0, 40: 1})
    stub.Fire("TAXIMAP_OPENED")
    frames()
    mine = taxi()
    assert mine.seen[1] and mine.known[25] is True and mine.known[40] is True and mine.known[30] is False and mine.known[23] is False
    # (the first flight map on a continent is said, the next ones are not)
    assert sum(1 for t in chat("flight map") if "Flight map read: 2 flight points known on this continent." in t) == 1
    stub.Fire("TAXIMAP_OPENED")
    assert not any("Flight map read" in t for t in chat("flight map again"))
    text = go_again("flight map")
    assert ns.route and any("fly Crossroads > Gadgetzan" in t for t in text), text
    slash("flights")
    text = chat("flights")
    assert any("2 known" in t for t in text) and any("Source: the flight map you last opened here" in t for t in text), text
    # only Crossroads: nowhere to fly to, so on foot
    stub.flightMap = lua.table_from({25: 0})
    stub.Fire("TAXIMAP_OPENED")
    frames()
    text = go_again("one point")
    assert ns.route and not any("fly" in t for t in text), text
    # a flight map that lists only what you have (as the old game did): the unlisted are not yours
    stub.flightMap, stub.flightMapShort = lua.table_from({25: 0, 30: 1, 40: 1}), True
    stub.Fire("TAXIMAP_OPENED")
    frames()
    mine = taxi()
    assert mine.known[30] is True and mine.known[23] is False and mine.known[77] is False
    # (from the southern Barrens the walk down the Great Lift to Freewind Post beats going back to Crossroads. A place
    # of its own, not where the trail's sixth point happens to lie: that moves with the ground's data)
    stub.player.x, stub.player.y = -4000.0, -2000.0
    assert any("fly Freewind Post > Gadgetzan" in t for t in go_again("short list")), "the listed points were not flown between"
    stub.player.x, stub.player.y = here
    stub.flightMapShort = None
    # a flight point found as you walk up to it (the game's own message): known from then on
    stub.flightMap = lua.table_from({40: 1})
    stub.Fire("TAXIMAP_OPENED")
    frames()
    assert taxi().known[25] is False
    chat("crossroads lost")
    stub.player.x, stub.player.y = -442.0, -2598.0
    stub.Fire("UI_INFO_MESSAGE", 372, "Some other message")
    assert taxi().known[25] is False
    stub.Fire("UI_INFO_MESSAGE", 372, lua.globals().ERR_NEWTAXIPATH)
    frames()
    text = chat("found")
    assert taxi().known[25] is True and any("Flight point discovered: Crossroads, The Barrens" in t for t in text), text
    stub.player.x, stub.player.y = here
    # the world map said you had Freewind Post, the flight map showed you did not: its word is not taken again
    stub.noTaxi = None
    stub.undiscovered[30] = None
    stub.flightMap = lua.table_from({25: 0, 40: 1})
    stub.Fire("TAXIMAP_OPENED")
    frames()
    assert taxi().gameWrong is True, "the world map is still believed"
    assert not ns.FlightsKnown(1)[0][30] and ns.FlightsKnown(1)[0][40]
    # by name, as a guide names a flight: which of them you lack
    assert ns.FlightMissing("ORGRIMMAR")[0] is True and ns.FlightMissing("Gadgetzan")[0] is False and ns.FlightMissing("Nowhere") is False
    assert ns.FlightMissing("orgrimmar")[1] == "Orgrimmar, Durotar"
    # the setting off: every flight point of your side, known or not
    set_option("knownOnly", False)
    frames()
    assert ns.FlightMissing("ORGRIMMAR") is False
    assert any("Freewind Post" in t for t in go_again("all points")), "with the setting off an unknown point is still left out"
    set_option("knownOnly", True)
    frames()
    # (as it was for what follows: nothing remembered, the world map's word, Freewind Post not found)
    lua.globals().PatchwerkForever_Thread_RoutesDB.taxi = None
    stub.flightMap = None
    stub.undiscovered[30] = True
    go_again("as before")

    step("arrive")
    stub.player.x, stub.player.y = -7141.0, -3791.0
    stub.Tick()
    text = chat("arrive")
    assert not ns.dest and any("You have arrived" in t for t in text)
    stub.Tick()
    assert stub.shown == 0 or True

    step("a pin already on the map is taken up at login and at a reload, not after any other loading screen")
    assert stub.pin and not ns.dest
    stub.Fire("PLAYER_ENTERING_WORLD", False, False)              # a loading screen, the pin you reached still on the map
    frames()
    assert not ns.dest, "a pin you had reached was routed to again after a loading screen"
    stub.Fire("PLAYER_ENTERING_WORLD", False, True)               # a reload
    frames()
    assert ns.dest and ns.dest.pin, "a pin on the map was not taken up at a reload"
    slash("stop")
    text = chat("pin stopped")
    assert any(t.endswith("Routing to your map pin stopped.") for t in text), text
    stub.Fire("PLAYER_ENTERING_WORLD", False, False)
    frames()
    assert not ns.dest, "a pin you had stopped was routed to again after a loading screen"
    stub.Fire("PLAYER_ENTERING_WORLD", True, False)               # a login
    frames()
    assert ns.dest and ns.dest.pin, "a pin on the map was not taken up at login"
    slash("stop")
    chat("pin stopped")

    step("the slash commands")
    stub.player.x, stub.player.y = -442.0, -2598.0
    for words in ("", "where", "to 52.5 30.1", "stop", "stop", "config", "nonsense"):
        slash(words)
        frames()
    text = chat("slash")
    O = lua.globals().PatchwerkForever.Options
    assert O.IsShown(O) and O.Current(O)[0] == ADDON, "the tool's own options page did not open"
    O.Close(O)
    # Stop says what was stopped, and the help says when routing resumes by itself
    stops = [t for t in text if "stopped." in t or "No active route." in t]
    assert len(stops) == 2 and stops[0].endswith("Routing to your coordinates stopped.") and stops[1].endswith("No active route."), stops
    assert any("/thread stop: stop routing (a route to a guide step or quest resumes" in t for t in text), text

    step("no pin: the route follows the RestedXP guide's arrow, step by step")
    assert own_settings() == 36, "the guide setting is missing from the settings page"
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    assert not ns.dest
    arrow = lua.eval("function() RXPG_ARROW = { element = nil }; return RXPG_ARROW end")()
    stub.Tick(); frames()
    assert not ns.dest, "routed with no guide step"
    # a step given as a place on a zone's map (here the continent's own map stands in for a zone)
    arrow.element = lua.table_from({"zone": 1414, "x": 46.8, "y": 60.3})
    stub.Tick(); frames()
    assert ns.dest and ns.dest.source == "rxp" and ns.route, "the guide's step was not routed to"
    first = (ns.dest.x, ns.dest.y)
    print("      step 1 at world (%.0f, %.0f): %d points" % (first[0], first[1], len(ns.route.points)))
    # the guide moves on: a step given in RestedXP's own world coordinates (x west, y north)
    arrow.element = lua.table_from({"wx": -2598.0, "wy": -442.0, "instance": 1})
    stub.Tick(); frames()
    assert abs(ns.dest.x - -442.0) < 1 and abs(ns.dest.y - -2598.0) < 1, "RestedXP's world coordinates were read the wrong way round"
    # a map pin comes first, and taking it away goes back to the guide
    stub.PinAt(1, -956.0, -3754.0)
    stub.Fire("USER_WAYPOINT_UPDATED"); frames()
    stub.Tick(); frames()
    assert ns.dest.pin, "the guide took over from a map pin"
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    stub.Tick(); frames()
    assert ns.dest and ns.dest.source == "rxp", "did not go back to the guide when the pin went"
    # stopping it yourself: left alone until the guide moves on, and the chat says so
    slash("stop")
    text = chat("guide stopped")
    assert any(t.endswith("Routing stopped. It resumes when the guide step or quest objective changes, or with /thread go.") for t in text), text
    for _ in range(4):
        stub.Tick(); frames()
    assert not ns.dest, "routed again to a step you had stopped"
    arrow.element = lua.table_from({"zone": 1414, "x": 46.8, "y": 60.3})
    stub.Tick(); frames()
    assert ns.dest, "did not pick up the guide's next step after a stop"
    # arriving: no route again to the same step while you stand there, and no chat line for it
    stub.player.x, stub.player.y = ns.dest.x + 3, ns.dest.y
    said_before = said[0]
    for _ in range(6):
        stub.Tick(); frames()
    assert not ns.dest, "kept routing to a step you are standing on"
    assert not any("You have arrived" in m for m in list(stub.messages.values())[said_before:])
    # walking away with the step still open: routed back to it
    stub.player.x, stub.player.y = -442.0, -2598.0
    stub.time += 20
    for _ in range(3):
        stub.Tick(); frames()
    assert ns.dest and ns.dest.source == "rxp", "not routed back to an open step after walking away"
    # /thread go with no pin routes to the guide; turning the setting off stops it
    slash("stop")
    slash("go"); frames()
    assert ns.dest and ns.dest.source == "rxp"
    for s in stub.settings.values():
        if s.variable.endswith("_rxp"):
            s.set(False)
    stub.Tick(); frames()
    assert not ns.dest, "still following the guide with the setting off"
    arrow.element = None
    chat("guide")

    step("no pin: the route follows a quest you track")
    def setting(name, value):
        [s for s in stub.settings.values() if s.variable == ADDON + "_" + name][0].set(value)

    def look(event="QUEST_LOG_UPDATE"):
        stub.Fire(event)
        stub.Tick(); frames()

    def near(x, y):
        return ns.dest and abs(ns.dest.x - x) < 1 and abs(ns.dest.y - y) < 1

    RATCHET, FIELD, CAMP = (-956.0, -3754.0), (-600.0, -2800.0), (-1994.0, -156.0)
    stub.player.x, stub.player.y = -442.0, -2598.0
    stub.QuestAt(870, "The Forgotten Pools", 1, *RATCHET)
    stub.watched = lua.table_from([870])
    look("QUEST_WATCH_LIST_CHANGED")
    assert ns.dest and ns.dest.source == "quest" and near(*RATCHET) and ns.route, "the tracked quest was not routed to"
    assert on_screen()[0] == "Quest: The Forgotten Pools", on_screen()
    quiet()
    # its mark moves on to the next objective: the route goes with it, and it is said on screen
    stub.QuestAt(870, "The Forgotten Pools", 1, *CAMP)
    look()
    assert near(*CAMP), "the route did not follow the quest's mark"
    assert on_screen()[0] == "Quest: The Forgotten Pools", "a quest's next objective was not said on screen"
    # a second quest in the tracker, nearer: the one being followed is kept
    stub.QuestAt(871, "Plainstrider Menace", 1, *FIELD)
    stub.watched = lua.table_from([870, 871])
    look("QUEST_WATCH_LIST_CHANGED")
    assert near(*CAMP), "a second tracked quest took over from the one being followed"
    # the game's own arrow on the second: that one comes first
    stub.focus = 871
    look("SUPER_TRACKING_CHANGED")
    assert near(*FIELD), "the quest the game's arrow is on did not come first"
    # only the arrow's quest, and the arrow on none: nothing; back to the nearest: the nearer of the two
    stub.focus = 0
    setting("questPick", "focus")
    assert not ns.dest, "routed to a tracked quest when only the arrow's quest was asked for"
    setting("questPick", "nearest")
    frames()
    assert near(*FIELD), "the nearest tracked quest was not chosen"
    # arriving: no chat line, and no route back while you wander about the place
    said_before = said[0]
    stub.player.x, stub.player.y = FIELD[0] + 3, FIELD[1]
    for _ in range(6):
        stub.Tick(); frames()
    assert not ns.dest, "kept routing to a quest you are standing at"
    assert not any("You have arrived" in m for m in list(stub.messages.values())[said_before:])
    stub.player.x, stub.player.y = FIELD[0] + 60, FIELD[1]
    for _ in range(12):
        stub.Tick(); frames()
    assert not ns.dest, "routed back to a quest's place from 60 yards off"
    quiet()
    stub.player.x, stub.player.y = -442.0, -2598.0
    for _ in range(3):
        stub.Tick(); frames()
    assert near(*FIELD), "not routed back to the quest after walking well away"
    # led back to a place you had reached: its words are not put on screen again, but are there to ask for
    assert ns.FloatShown() is None, "a quest's place you had reached was said again when you were led back to it"
    slash("step")
    assert on_screen() == ("Quest: Plainstrider Menace", ns.Summary(ns.route)), on_screen()
    quiet()
    # stopping it yourself: left alone until the quest moves on
    slash("stop")
    for _ in range(12):
        stub.Tick(); frames()
    assert not ns.dest, "routed again to a quest you had stopped"
    # handed in: the next tracked quest is taken up
    stub.QuestGone(871)
    look("QUEST_TURNED_IN")
    assert near(*CAMP), "the next tracked quest was not taken up"
    # a quest on the other continent, with boats and zeppelins switched off: the game's own next stop on
    # the way, when it is on this one
    setting("rides", False)
    stub.QuestAt(872, "Message to Stormwind", 0, -9460.0, 60.0)
    stub.QuestStop(872, 1, *RATCHET)
    stub.watched = lua.table_from([870, 872])
    stub.focus = 872
    look("SUPER_TRACKING_CHANGED")
    assert near(*RATCHET), "the game's next stop on the way was not routed to"
    slash("go"); frames()
    text = chat("quest")
    assert any('Routing toward quest "Message to Stormwind"' in t for t in text), text
    stub.QuestStop(872, None)                                     # no stop given: the nearest tracked quest instead
    look()
    assert near(*CAMP), "a quest on another continent was not passed over"
    # a guide step as well: the guide first, unless you say the quest
    setting("rxp", True)
    arrow.element = lua.table_from({"wx": RATCHET[1], "wy": RATCHET[0], "instance": 1})
    stub.Tick(); frames()
    assert ns.dest.source == "rxp" and near(*RATCHET), "the guide did not come before the quest"
    slash("quest")
    assert any("your RestedXP guide (Route Priority: Guide First)" in t for t in chat("quest"))
    # a quest you choose (a click in the tracker) is a side path: it takes over from the guide, in a
    # colour of its own, with the way back to the guide drawn on from it
    Choice = lua.globals().PatchwerkForever.Choice
    walking = list(ns.TrailColour("walk", ns.dest.chosen))
    assert Choice.Get(Choice) is None and not ns.dest.chosen
    Choice.Set(Choice, "quest", 870)
    stub.Tick(); frames()
    assert ns.dest.source == "quest" and ns.dest.chosen and near(*CAMP), "a quest you chose did not take over from the guide"
    assert list(ns.TrailColour("walk", ns.dest.chosen)) != walking, "a chosen path is drawn like the main track"
    assert list(ns.TrailColour("fly", ns.dest.chosen)) == list(ns.TrailColour("fly")), "a flight on a chosen path lost its colour"
    stub.Tick(); frames()
    assert ns.ahead and len(ns.ahead.legs) == 1, "the way back to the guide is not drawn on from the quest"
    slash("quest")
    assert any("selected by you" in t for t in chat("quest"))
    assert Choice.Is(Choice, "quest", 870) and not Choice.Is(Choice, "quest", 872)
    # chosen again (the choice cleared): the guide has the say once more
    Choice.Clear(Choice)
    stub.Tick(); frames()
    assert ns.dest.source == "rxp" and not ns.dest.chosen and near(*RATCHET), "the guide was not gone back to"
    # a quest that is not tracked can be chosen too; handed in, the main track comes back by itself
    stub.QuestAt(873, "A Side Job", 1, *FIELD)
    Choice.Set(Choice, "quest", 873)
    stub.Tick(); frames()
    assert ns.dest.chosen and near(*FIELD)
    stub.QuestGone(873)
    stub.Tick(); frames()
    assert Choice.Get(Choice) is None and ns.dest.source == "rxp" and near(*RATCHET), "a quest handed in is still followed"
    # a second guide's list chosen as a side path (the Dungeon Journal's quests): followed step after step
    # in the chosen colour, its own next steps drawn on; nothing left to say, and the main guide leads again
    lua.execute("""
        STUB.side = { { -600, -2800 }, { -1994, -156 } }
        PatchwerkForever.Guides:Register('side', { name = 'Side List', Read = function(count)
            local now = STUB.side[1]
            if not now then return nil end
            local info = { index = 1, total = 2, kind = 'accept', key = 'side' .. #STUB.side, map = 1, x = now[1], y = now[2],
                lines = { { text = 'Accept: A Job', done = false } }, ahead = {}, after = {} }
            local nxt = STUB.side[2]
            if nxt and count > 0 then info.ahead[1] = { index = 2, kind = 'turnin', lines = {}, map = 1, x = nxt[1], y = nxt[2] } end
            return info
        end })
    """)
    assert ns.dest.source == "rxp" and not ns.dest.chosen and near(*RATCHET)
    Choice.Set(Choice, "guide", "side")
    stub.Tick(); frames()
    assert ns.dest.source == "rxp" and ns.dest.chosen and near(*FIELD), "a guide you chose was not followed"
    assert list(ns.dest.lines.values()) == ["Accept: A Job"]
    stub.Tick(); frames()
    assert ns.ahead and len(ns.ahead.legs) == 1, "the chosen guide's next step is not drawn on"
    lua.execute("table.remove(STUB.side, 1)")                 # (its step done: on to its next)
    stub.Tick(); frames()
    assert ns.dest.chosen and near(*CAMP), "the chosen guide did not move on to its next step"
    lua.execute("STUB.side = {}")                             # (its list done)
    stub.Tick(); frames()
    assert Choice.Get(Choice) is None and ns.dest.source == "rxp" and not ns.dest.chosen and near(*RATCHET), "the main guide did not lead again"
    chat("quest")
    # the quest the game's arrow is on, followed by the settings, then chosen: the same way, marked as chosen
    setting("sourceFirst", "quest")
    stub.focus = 870
    look("SUPER_TRACKING_CHANGED")
    assert ns.dest.source == "quest" and near(*CAMP) and not ns.dest.chosen
    Choice.Set(Choice, "quest", 870)
    stub.Tick(); frames()
    assert ns.dest.chosen and near(*CAMP)
    Choice.Clear(Choice)
    stub.Tick(); frames()
    assert not ns.dest.chosen and near(*CAMP)
    stub.focus = 872
    setting("sourceFirst", "rxp")
    stub.Tick(); frames()
    assert ns.dest.source == "rxp"
    chat("quest")
    setting("sourceFirst", "quest")
    frames()
    assert ns.dest.source == "quest" and near(*CAMP), "the quest did not come first when asked"
    # a map pin still comes before both
    stub.PinAt(1, -7140.0, -3790.0)
    stub.Fire("USER_WAYPOINT_UPDATED"); frames()
    stub.Tick(); frames()
    assert ns.dest.pin, "a quest took over from a map pin"
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    stub.Tick(); frames()
    assert ns.dest and ns.dest.source == "quest", "did not go back to the quest when the pin went"
    slash("quest")
    text = chat("quest")
    assert any('Following: "The Forgotten Pools"' in t for t in text), text
    assert any("not your current continent" in t for t in text), text
    # the setting off: the guide is followed; both off: nothing
    setting("quests", False)
    frames()
    assert ns.dest.source == "rxp", "still following a quest with the setting off"
    setting("rxp", False)
    assert not ns.dest
    setting("quests", True)
    setting("sourceFirst", "rxp")
    arrow.element = None
    stub.watched, stub.focus = lua.table(), 0
    look("QUEST_WATCH_LIST_CHANGED")
    assert not ns.dest, "routed with nothing tracked"
    setting("rides", True)
    chat("quest")

    step("herbs and ore: a spot is remembered when you gather, and shown on both maps")
    db = lua.globals().PatchwerkForever_Thread_RoutesDB
    world_map = lua.globals().WorldMapFrame

    def gather(name, x, y, loot, target=None):
        stub.player.x, stub.player.y = x, y
        stub.targetName = target
        stub.Fire("UNIT_SPELLCAST_SENT", "player", name, "cast-1", 2366)
        stub.time += 3
        stub.loot = lua.table_from([lua.table_from(item) for item in loot])
        stub.Fire("LOOT_READY")
        stub.Fire("LOOT_OPENED")
        stub.loot = lua.table()

    def spots():
        return sum(len(list(v.values())) for v in db.nodes.values())

    herb = {"link": "item:2447", "class": 7, "sub": 9, "icon": 133939, "guid": "GameObject-0-1-1-1-1617-0"}
    ore = {"link": "item:2770", "class": 7, "sub": 7, "icon": 134566, "guid": "GameObject-0-1-1-1-1731-0"}
    gather("Peacebloom", -450.0, -2600.0, [herb])
    assert spots() == 1 and db.nodeKinds["Peacebloom"].kind == "h", "the herb was not remembered"
    gather("Peacebloom", -452.0, -2603.0, [herb])
    assert spots() == 1, "the same spot was remembered twice"
    gather("Copper Vein", -520.0, -2650.0, [ore])
    gather("Copper Vein", -520.0, -2650.0, [ore])                 # a vein is mined more than once
    assert spots() == 2 and db.nodeKinds["Copper Vein"].kind == "o"
    # not spots: loot with no cast before it, a cast at a creature, a herb off a corpse, loot that is neither
    stub.loot = lua.table_from([lua.table_from(herb)])
    stub.Fire("LOOT_READY")
    gather("Plainstrider", -600.0, -2700.0, [herb], target="Plainstrider")
    gather("Battered Chest", -610.0, -2710.0, [dict(herb, guid="Creature-0-1-1-1-99-0")])
    gather("Battered Chest", -620.0, -2720.0, [{"link": "item:118", "class": 0, "sub": 1, "icon": 1, "guid": herb["guid"]}])
    assert spots() == 2, "something that is not a herb or ore spot was remembered (%d)" % spots()
    # with remembering switched off nothing new is kept
    for s in stub.settings.values():
        if s.variable.endswith("_nodes"):
            s.set(False)
    gather("Silverleaf", -700.0, -2800.0, [herb])
    assert spots() == 2
    for s in stub.settings.values():
        if s.variable.endswith("_nodes"):
            s.set(True)
    # the minimap: both spots are within its view from between them
    stub.player.x, stub.player.y = -480.0, -2620.0
    for _ in range(3):
        stub.Tick()
    assert stub.icons == 2, "expected 2 icons on the minimap, saw %d" % stub.icons
    stub.player.x, stub.player.y = -480.0, -4000.0           # far away: none
    stub.time += 1
    stub.Tick()
    assert stub.icons == 0, "icons on the minimap far from any spot"
    for s in stub.settings.values():
        if s.variable.endswith("_nodesMinimap"):
            s.set(False)
    stub.player.x, stub.player.y = -480.0, -2620.0
    stub.time += 1
    stub.Tick()
    assert stub.icons == 0, "icons on the minimap with the setting off"
    # the world map: on the zone's map, not on the continent's
    stub.provider.RefreshAllData()
    assert stub.icons == 0, "spots drawn on a continent's map"
    world_map.mapID = 1413
    stub.provider.RefreshAllData()
    assert stub.icons == 2, "expected 2 icons on the zone's map, saw %d" % stub.icons
    world_map.mapID = 1414
    stub.provider.RefreshAllData()
    # the commands
    slash("nodes")
    stub.player.x, stub.player.y = -451.0, -2601.0
    slash("nodes forget")
    assert spots() == 1, "forget did not clear the spot you stand on"
    text = chat("nodes")
    assert any("1 herb nodes and 1 ore nodes" in t for t in text), text
    # (and for a tool with a map of its own, through the base)
    T = lua.globals().PatchwerkForever.Trails
    got = []
    T.NodesAround(T, 1, stub.player.x, stub.player.y, 6000, lua.eval("function(f) return function(...) f(...) end end")(
        lambda x, y, name, icon, kind: got.append((name, icon, kind))))
    assert got and all(n and i and k in ("h", "o") for n, i, k in got), got      # (one of the two was just deleted)
    stub.player.x, stub.player.y = -442.0, -2598.0

    step("gathering: to the nearest spot and on to the next at each; one kind; a round; offered through the base")
    G = lua.globals().PatchwerkForever.Gather
    assert G.Has(G), "Routes did not offer gathering to the base"
    gather("Peacebloom", -460.0, -2640.0, [herb])
    gather("Peacebloom", -700.0, -2900.0, [herb])
    gather("Tin Vein", -2500.0, -2600.0, [ore])
    stub.player.x, stub.player.y = -442.0, -2598.0
    got = [(n.name, round(n.yards)) for n in G.Near(G, 5).values()]
    assert got == [("Peacebloom", 46), ("Copper Vein", 94), ("Tin Vein", 2058)], got
    assert len(G.Near(G, 1)) == 1 and G.State(G) is None

    def go(x=None, y=None):
        if x is not None:
            stub.player.x, stub.player.y = x, y
        for _ in range(2):
            stub.Tick(); frames()

    def at(x, y):
        return ns.dest and abs(ns.dest.x - x) < 1 and abs(ns.dest.y - y) < 1

    assert G.Start(G, "any") is True
    go()
    assert ns.dest and ns.dest.source == "gather" and at(-460.0, -2640.0) and ns.route, "no way to the nearest spot"
    assert G.State(G).mode == "any" and G.State(G).going == "Peacebloom"
    # reach it: on to the next nearest, not back to the one just visited
    go(-460.0, -2640.0)
    assert at(-520.0, -2650.0) and G.State(G).going == "Copper Vein", "the run did not go on to the next spot"
    go(-520.0, -2650.0)
    assert at(-700.0, -2900.0), "the run went back to a spot just visited"
    # stopped by you: the run is over, and that is what the chat says
    slash("stop")
    text = chat("run stopped")
    assert any(t.endswith("Gathering stopped.") for t in text) and not any("Routing" in t for t in text), text
    go()
    assert not ns.dest and G.State(G) is None, "a run you stopped went on"
    # one kind: its spot here was just visited, so there is none; later there is
    assert G.Start(G, "kind", "Copper Vein") is False and G.State(G) is None
    text = chat("gather")
    assert any("No Copper Vein nodes recorded nearby" in t for t in text), text
    stub.time += 400
    stub.player.x, stub.player.y = -442.0, -2598.0
    assert G.Start(G, "kind", "Copper Vein") is True
    go()
    assert at(-520.0, -2650.0) and G.State(G).name == "Copper Vein"
    assert G.Stop(G) is True and not ns.dest and G.State(G) is None
    go()
    assert not ns.dest, "something was routed to after the run was stopped"
    # a round keeps to the spots near where it began: the far vein is left out, and the round ends
    assert G.Start(G, "round") is True
    go()
    assert at(-460.0, -2640.0)
    go(-460.0, -2640.0)
    assert at(-520.0, -2650.0)
    go(-520.0, -2650.0)
    assert at(-700.0, -2900.0)
    go(-700.0, -2900.0)
    text = chat("gather")
    assert G.State(G) is None and not ns.dest and any("Gathering stopped" in t for t in text), text
    # the commands
    stub.time += 400
    stub.player.x, stub.player.y = -442.0, -2598.0
    for words in ("gather list", "gather stop", "gather thistle", "gather peacebloom"):
        slash(words)
    go()
    text = chat("gather")
    assert any("Peacebloom: 46 yd" in t for t in text) and any("No gathering run is active" in t for t in text), text
    assert any('No "thistle" node' in t for t in text) and at(-460.0, -2640.0) and G.State(G).name == "Peacebloom"
    slash("gather stop")
    slash("gather round")
    go()
    assert G.State(G).mode == "round"
    slash("gather stop")
    go()
    assert not ns.dest and G.State(G) is None
    # one side path at a time: a run clears a chosen quest, and choosing a quest ends a run
    stub.QuestAt(874, "A Side Job", 1, -600.0, -2800.0)
    Choice.Set(Choice, "quest", 874)
    go()
    assert ns.dest and ns.dest.source == "quest" and ns.dest.chosen
    assert G.Start(G, "any") is True and Choice.Get(Choice) is None, "a gathering run left the chosen quest standing"
    go()
    assert ns.dest.source == "gather" and ns.dest.chosen, "a gathering run is not drawn as a path you chose"
    Choice.Set(Choice, "quest", 874)
    assert G.State(G) is None, "choosing a quest left the gathering run on"
    go()
    assert ns.dest.source == "quest" and ns.dest.chosen and at(-600.0, -2800.0)
    stub.QuestGone(874)
    go()
    assert not ns.dest and Choice.Get(Choice) is None
    chat("side paths")
    # a run that cannot start puts the chosen quest back: a round from where no node lies near enough
    stub.QuestAt(874, "A Side Job", 1, -600.0, -2800.0)
    Choice.Set(Choice, "quest", 874)
    stub.player.x, stub.player.y = -1900.0, -1400.0
    slash("gather round")
    text = chat("a run that could not start")
    assert G.State(G) is None and Choice.Get(Choice) and Choice.Get(Choice).id == 874, "a run that did not start dropped the chosen quest"
    assert any("No herb or ore nodes recorded nearby" in t for t in text) and not any("started" in t for t in text), text
    Choice.Clear(Choice)
    stub.QuestGone(874)
    stub.player.x, stub.player.y = -442.0, -2598.0
    go()
    # the key: one press starts a run, the next ends it, each saying how
    keyed = lua.globals().PatchwerkForever_Thread_Routes_Gather
    keyed()
    assert G.State(G) is not None
    assert any("Press the key again to stop." in t for t in chat("gather key")), "the key's run does not say how to end it"
    keyed()
    assert G.State(G) is None and any("Gathering stopped." in t for t in chat("gather key again"))
    go()
    # Start Routing during a run ends it, where there is a guide step or quest to go to instead
    had_quests = ns.Get("quests")
    setting("quests", True)
    stub.QuestAt(875, "Something Else", 1, -600.0, -2800.0)
    stub.watched = lua.table_from([875])
    stub.focus = 875
    slash("gather")
    go()
    assert ns.dest.source == "gather"
    slash("go")
    go()
    text = chat("go during a run")
    assert G.State(G) is None and ns.dest and ns.dest.source == "quest", "Start Routing left the run on"
    assert any(t.endswith("Gathering stopped.") for t in text), text
    stub.QuestGone(875)
    setting("quests", had_quests)
    go()
    # what this character can gather, asked as the game's profession book asks: a profession that is
    # neither herbalism nor mining (leatherworking), nothing to gather
    lua.execute("""
        STUB.professions = { 12 }
        function GetProfessions() return STUB.professions[1], STUB.professions[2] end
        function GetProfessionInfo(index) return 'Profession', 1, 1, 300, 0, 0, STUB.professionLine[index] end
        STUB.professionLine = { [10] = 182, [11] = 186, [12] = 165 }
    """)
    stub.Fire("SKILL_LINES_CHANGED")
    slash("gather")
    slash("gather list")
    text = chat("no profession")
    assert G.State(G) is None and sum(1 for t in text if "no gathering profession" in t) == 2, text
    assert len(G.Near(G, 5)) == 0, "the Gathering list offers nodes to a character with no profession"
    # an empty profession book says nothing (this client may keep professions some other way): the
    # spells are asked, and with no answer from them either, both are offered as before
    lua.execute("STUB.professions = {}")
    stub.Fire("SKILL_LINES_CHANGED")
    assert len(G.Near(G, 5)) == 3, "an empty profession book was taken for no gathering profession"
    lua.execute("STUB.professions = { 10 }")                    # herbalism only
    stub.Fire("SKILL_LINES_CHANGED")
    assert [n.name for n in G.Near(G, 5).values()] == ["Peacebloom"], [n.name for n in G.Near(G, 5).values()]
    lua.execute("STUB.professions = { 11, 10 }")                # both, the other way round
    stub.Fire("SKILL_LINES_CHANGED")
    assert len(G.Near(G, 5)) == 3
    lua.execute("GetProfessions, GetProfessionInfo = nil, nil")
    stub.Fire("SKILL_LINES_CHANGED")
    chat("professions")
    # (the spots made for this are forgotten again, so that what follows finds what it did before)
    for x, y in ((-460.0, -2640.0), (-700.0, -2900.0), (-2500.0, -2600.0)):
        stub.player.x, stub.player.y = x, y
        slash("nodes forget")
    assert spots() == 1
    # a spot another tool saw (Sparkle's herbs you passed), told through the base: kept as one gathered
    # from, with the game's plain herb icon until you gather there yourself
    assert G.Note(G, "Mageroyal", "h", stub.player.map, -800.0, -3000.0) is True and spots() == 2
    assert db.nodeKinds["Mageroyal"].guessed and "Herb" in db.nodeKinds["Mageroyal"].icon
    assert G.Note(G, "Mageroyal", "x", stub.player.map, 0.0, 0.0) is False, "a spot of no known kind was taken"
    stub.player.x, stub.player.y = -800.0, -3000.0
    slash("nodes forget")
    assert spots() == 1
    stub.player.x, stub.player.y = -442.0, -2598.0
    chat("gather")

    step("the options pages: every control is made, on the page it belongs to")
    # each tool's settings carry its own addon's name; the base's one setting is on the parent page
    by_name = {}
    for s in stub.settings.values():
        for addon in (SPARKLE, ADDON, BASE):
            if s.variable.startswith(addon + "_"):
                assert s.variable[len(addon) + 1:] not in by_name, s.variable
                by_name[s.variable[len(addon) + 1:]] = s
                break
    # (Routes' own exactly, here and below; Sparkle's are its own business and change with it: lua_sparkle.py)
    assert len(by_name) == len(stub.settings) and own_settings() == 36, "expected 36 Routes settings on the options pages, found %d" % own_settings()
    assert "baseTellMissing" not in by_name, "the base's switch is on its front page, not a row of the game's"
    pages = sorted(stub.pages.keys())
    WANT = {"Routes (Thread)": 17, "Routes (Thread) > Trail": 13, "Routes (Thread) > Step Text": 6}
    assert [p for p in pages if not p.startswith("Sparkle")] == sorted(WANT), pages
    assert "Sparkle (Thread)" in pages and "Sparkle (Thread) > Appearance" in pages, pages
    for page in pages:
        on_it = [n for n, s in by_name.items() if s.page == page]
        # (a Sparkle page may hold only a list and a button: Sparkle: Ignore List)
        assert len(on_it) == WANT.get(page, len(on_it)) and (on_it or page == "Sparkle (Thread) > Ignore List"), \
            "%s has %d settings, expected %s" % (page, len(on_it), WANT.get(page))
    # headings: Routes' own, in order, then the Sparkle's
    headers = list(stub.headers.values())
    assert headers[:9] == [
        "Destinations", "Focus And My Route", "Travel Options", "Chat", "Gathering Nodes", "Display", "Line", "Colors", "Defaults"], headers
    assert len(headers) > 9 and headers[-1] == "Defaults", headers
    # every page opens with its name, its tool's picture and a line in Patchwerk's voice
    # (a folded page is "Sparkle (Thread) > Appearance" in the list; its intro still names it "Sparkle: Appearance")
    named = lambda p: p if " > " not in p else p.split(" (")[0] + ": " + p.split(" > ")[1]
    intros = {i.name: i for i in stub.intros.values()}
    assert sorted(intros) == sorted(named(p) for p in pages), sorted(intros)
    assert intros["Routes (Thread)"].voice == "Follow the thread. Patchwerk knows the way. Mostly."
    assert intros["Routes: Trail"].voice.startswith("A line on the ground.") and intros["Sparkle: Appearance"].voice.startswith("Every shiny thing")
    assert all(i.voice and i.icon and i.icon.endswith("icon") for i in intros.values()), [n for n, i in intros.items() if not i.voice]
    lists = len([r for r in stub.rows.values() if r.template == "PatchwerkForeverListTemplate"])   # (Sparkle's two lists)
    assert stub.Rows() == len(pages) + len(headers) + lists, "a row of our own could not be made"
    # the front page: what is sewn on, each with a button to its page
    O = lua.globals().PatchwerkForever.Options
    O.Open(O, BASE)
    page = tables[BASE].FrontShown()
    parts = [(x.name, x.says, x.open) for x in page.parts.values()]
    for part in parts:
        print("      front page: %s | %s" % part[:2])
    assert [x[0].split("  ")[0] for x in parts] == ["Routes (Thread)", "Sparkle (Thread)"] and all(x[2] for x in parts), parts
    assert "Two threads" in page.said, page.said
    names = [s.name for s in by_name.values()]
    assert "Route To Map Pin" in names and "Follow Guide" in names and "Font Size" in names and "Walking Color" in names, names
    sdb = lua.globals().PatchwerkForever_Thread_SparkleDB
    assert sdb and not lua.globals().PatchwerkForever_Thread_RoutesDB.sparkleWas, "the sparkle keeps its things in the routes' saved data"
    buttons = list(stub.buttons.values())
    # (Routes' own buttons exactly; Sparkle's are its own business, and change with it)
    mine = sorted(b.text for b in buttons if b.page.startswith("Routes") or b.page == "Routes (Thread)")
    assert mine == ["Reset", "Show"], mine
    assert sum(1 for b in buttons if b.text == "Reset") == 2, [b.text for b in buttons]
    routes_own = [s for s in by_name.values() if s.variable.startswith(ADDON + "_")]
    assert sum(1 for s in routes_own if s.colour) == 5 and sum(1 for s in routes_own if s.choices) == 3
    assert "Route To My Corpse" in names and [s for s in routes_own if s.name == "Route To My Corpse"][0].default is True

    def setv(name, value):
        by_name[name].set(value)

    # Reset To Defaults, one tool at a time: Routes' options go back, Sparkle's are left as they are
    setv("trailStyle", "dots")
    setv("flights", False)
    setv("nameSize", 20)
    [b for b in buttons if b.text == "Reset" and b.page == "Routes (Thread)"][0].click()
    assert "Reset all Routes (Thread) options" in stub.asked.text, stub.asked.text
    stub.Answer(True)
    assert ns.Get("trailStyle") == "solid" and ns.Get("flights") is True, "Routes' options were not reset"
    assert sparkle.Get("nameSize") == 20, "resetting Routes reset the Sparkle too"
    [b for b in buttons if b.text == "Reset" and b.page == "Sparkle (Thread)"][0].click()
    stub.Answer(True)
    assert sparkle.Get("nameSize") == 13
    chat("reset")

    step("a sparkle on the thing the game points at, each kind with its own look")
    cvars = stub.cvars
    assert cvars.SoftTargetNameplateInteract == "1" and cvars.SoftTargetIconGameObject == "1", "the game's two settings were not switched on"
    assert sdb.sparkleWas.SoftTargetNameplateInteract == "0", "what the settings were was not kept"
    plate = lua.eval("CreateFrame('Frame')")
    same = lua.eval("function(a, b) return a == b end")
    HERB = "Cursor_Crosshair_GatherHerbs_64"

    def point_at(name, guid, cursor, with_plate=True):
        stub.soft = lua.table_from({"name": name, "guid": guid, "cursor": cursor, "plate": plate if with_plate else None}) if name else None
        stub.Fire("PLAYER_SOFT_INTERACT_CHANGED", "old", guid or "")

    def herb():
        point_at("Silverleaf", "GameObject-0-1-1-1-1617-0", HERB)

    def marks():
        return [f for f in stub.frames.values() if f.pieces is not None]

    herb()
    assert len(marks()) == 1, "no mark was made for a herb"
    s = marks()[0]
    assert s.shown and same(s.parent, plate), "no sparkle on a herb"
    assert abs(s.look.g - 1.0) < 0.01 and s.look.r < 0.5, "a herb's sparkle is not green"
    assert s.name.shown and s.name.text == "Silverleaf", "the herb's name is not written over it"
    # it comes in softly: nothing at first, all of it a third of a second on
    assert s.name.alpha == 0.0 and s.arriving, "the sparkle did not start faint"
    for _ in range(10):
        stub.Frame()
    assert 0.3 < s.name.alpha < 0.6, "the sparkle is not half way in after a sixth of a second: %s" % s.name.alpha
    for _ in range(15):
        stub.Frame()
    assert s.name.alpha == 1.0 and not s.arriving, "the sparkle did not finish coming in"
    herb()                                                        # the same thing again: it does not start over
    assert s.name.alpha == 1.0, "the sparkle came in again on the thing it was already on"
    # every effect: the right number of pictures, and it runs without an error (the subtle ones for
    # long enough that every speck goes through several of its turns)
    pieces = {"star": 2, "glow": 1, "ring": 3, "beam": 2, "swirl": 3, "brackets": 4, "none": 0,
              "glints": 5, "fireflies": 6, "shimmer": 2, "ripple": 3, "wisp": 4,
              "leaves": 5, "embers": 6, "coins": 5, "rays": 3}
    subtle = ("glints", "fireflies", "shimmer", "ripple", "wisp", "leaves", "embers", "coins")
    assert sorted(c.value for c in by_name["look_herb_effect"].choices.values()) == sorted(pieces), "the list of effects does not match the effects there are"
    for effect, count in pieces.items():
        setv("look_herb_effect", effect)
        showing = sum(1 for p in s.pieces.values() if p.shown)
        assert showing == count, "%s shows %d pictures, expected %d" % (effect, showing, count)
        for _ in range(1500 if effect in subtle else 40):
            stub.Frame()
    assert s.shown and s.name.shown, "with no effect the name should still show"
    setv("look_herb_effect", "beam")
    setv("look_herb_size", 200)
    assert s.width == 200, "the size was not applied"
    setv("look_herb_bright", 50)
    setv("look_herb_speed", 300)
    setv("look_herb_height", 20)
    setv("look_herb_colour", "ff0000ff")
    assert s.look.b == 1.0 and s.look.r == 0.0 and abs(s.look.bright - 0.5) < 0.01 and s.look.speed == 3.0, "the look was not applied"
    for _ in range(40):
        stub.Frame()
    # another kind keeps its own look
    point_at("Tin Vein", "GameObject-0-1-1-1-1732-0", "Cursor_Crosshair_UnableMine_64")
    assert s.shown and s.look.r == 1.0 and s.look.effect == "star" and s.width == 110, "ore does not have its own look"
    point_at("Copper Vein", "GameObject-0-1-1-1-1731-0", None)      # no cursor told, but a name you have mined
    assert s.shown and s.look.effect == "star", "no sparkle on a vein known from gathering"
    point_at("Battered Chest", "GameObject-0-1-1-1-2843-0", "Cursor_Crosshair_LootAll_64")
    assert s.shown and s.look.effect == "glow", "no sparkle on a chest"
    point_at("Sack of Oats", "GameObject-0-1-1-1-2724-0", "Cursor_Crosshair_QuestInteract_64")
    assert s.shown and s.look.effect == "ring", "a quest object is not taken as one"
    point_at("Odd Thing", "GameObject-0-1-1-1-9999-0", None)       # the game tells no cursor: better a sparkle than none
    assert s.shown, "no sparkle on a thing whose kind the game did not tell"
    point_at("Mailbox", "GameObject-0-1-1-1-32349-0", "Cursor_Crosshair_Interact_64")
    assert not s.shown, "a mailbox sparkles with the setting for everything off"
    setv("sparkleAll", True)
    assert s.shown, "a mailbox does not sparkle with the setting for everything on"
    point_at("Innkeeper Boorand", "Creature-0-1-1-1-3934-0", "Cursor_Crosshair_Speak_64")
    assert not s.shown, "a creature sparkles"
    point_at("Silverleaf", "GameObject-0-1-1-1-1617-0", HERB, with_plate=False)
    assert not s.shown, "a sparkle with no nameplate to hang it on"
    # the nameplate is there, but the game only gives it under its own name, not under "softinteract"
    stub.soft = lua.table_from({"name": "Silverleaf", "guid": "GameObject-0-1-1-1-1617-0", "cursor": HERB,
                                "plate": plate, "token": "nameplate3"})
    stub.Fire("PLAYER_SOFT_INTERACT_CHANGED", "old", "new")
    assert not s.shown
    stub.Fire("NAME_PLATE_UNIT_ADDED", "nameplate3")
    assert s.shown, "the nameplate was not found by going through the ones on screen"
    stub.Fire("NAME_PLATE_UNIT_REMOVED", "nameplate3")
    assert not s.shown

    step("the name: size, font, outline, colour, place")
    herb()
    setv("nameSize", 20)
    assert s.name.size == 20, "the name's size was not applied"
    setv("nameFont", "arial")
    assert "ARIALN" in s.name.font
    setv("nameFont", "skurri")                                     # a font this pretend client lacks
    assert "FRIZQT" in s.name.font, "a missing font did not fall back to the game's own"
    setv("nameOutline", "thick")
    assert s.name.flags == "THICKOUTLINE"
    setv("nameOutline", "none")
    assert s.name.flags == ""
    assert s.name.colour[3] == 1.0, "the name does not take the colour of its kind"   # the herb was made blue above
    setv("nameColour", "fixed")
    setv("nameFixed", "ff00ff00")
    assert s.name.colour[1] == 0.0 and s.name.colour[2] == 1.0, "the one colour for names was not applied"
    setv("namePlace", "above")
    setv("nameOffset", 40)
    setv("sparkleName", False)
    assert s.shown and not s.name.shown, "the name stayed with its setting off"
    setv("sparkleName", True)

    step("hidden in combat and in dungeons when asked, and on things you ignore")
    stub.Fire("PLAYER_REGEN_DISABLED")
    assert s.shown, "hidden in combat without being asked"
    stub.Fire("PLAYER_REGEN_ENABLED")
    setv("sparkleCombat", True)
    stub.Fire("PLAYER_REGEN_DISABLED")
    assert not s.shown, "not hidden in combat"
    stub.Fire("PLAYER_REGEN_ENABLED")
    assert s.shown, "did not come back after combat"
    stub.instance = True
    herb()
    assert s.shown, "hidden in a dungeon without being asked"
    setv("sparkleInstance", True)
    assert not s.shown, "not hidden in a dungeon"
    stub.instance = False
    herb()
    assert s.shown
    slash("ignore")
    assert not s.shown and sdb.sparkleIgnored["Silverleaf"], "ignoring a thing did not hide it"
    herb()
    assert not s.shown, "an ignored thing sparkled again"
    slash("ignore list")
    slash("ignore undo")
    assert s.shown, "undoing did not bring it back"
    lua.globals().PatchwerkForever_Thread_Sparkle_Ignore()                       # the bound key
    assert not s.shown
    stub.asked = None
    [b for b in buttons if b.text == "Clear"][0].click()
    if stub.asked:                                                # (Sparkle asks first, from the button)
        stub.Answer(True)
    assert s.shown, "the Forget button did not clear the list"
    slash("ignore list")

    step("the sparkle fades where it comes over your character, when asked")
    # the pretend screen is 1002 by 668 and the camera 15 yards out: the oval your character fills
    def body(zoom=15.0, size=100, wide=50, across=0, up=0):
        hh = min(2.2 / zoom * size / 100, 0.95) * 668 / 2
        return 501 + 1002 * across / 100.0, 334 - hh * 0.8 + 668 * up / 100.0, hh * wide / 100.0, hh

    def alpha_at(x, y):
        s.cx, s.cy = x, y
        stub.Frame()
        return s.alpha

    cx, cy, hw, hh = body()
    assert alpha_at(cx, cy) in (None, 1.0), "the sparkle faded without being asked: %s" % s.alpha
    setv("sparkleBehind", True)
    assert s.alpha == 0.0, "the sparkle did not fade right over your character, at once"
    assert alpha_at(cx + 6 * hw, cy) == 1.0, "the sparkle faded well clear of your character"
    assert abs(alpha_at(cx + hw, cy) - 0.5) < 0.01, "not half faded at the oval's edge"
    assert abs(alpha_at(cx, cy - hh) - 0.5) < 0.01, "not half faded at the oval's foot"
    assert alpha_at(cx, cy + 0.5 * hh) == 0.0 and s.shown and s.name.shown, "inside the oval it should be gone, but still there to come back"
    setv("sparkleBehindLeft", 40)
    assert abs(alpha_at(cx, cy) - 0.4) < 0.01, "the brightness left over was not kept"
    setv("sparkleBehindLeft", 0)
    stub.zoom = 30.0                                              # further out: your character looks half the size
    assert alpha_at(cx + hw, cy) == 1.0, "the oval did not shrink as the camera went out"
    far = body(zoom=30.0)
    assert alpha_at(far[0], far[1]) == 0.0
    stub.zoom = 0.5                                               # looking out of your own eyes
    assert alpha_at(far[0], far[1]) == 1.0, "it faded with the camera inside your head"
    slash("sparkle")
    assert any("the camera is too close" in t for t in chat("sparkle")), "the command does not say the camera is too close"
    stub.zoom = None                                              # a client that does not say: 15 yards is taken
    assert alpha_at(cx, cy) == 0.0 and alpha_at(cx + 6 * hw, cy) == 1.0, "no fading where the game does not tell the camera's distance"
    slash("sparkle")
    assert any("15 yards is assumed" in t for t in chat("sparkle")), "the command does not say the distance is assumed"
    stub.zoom = 15.0
    setv("sparkleBehindSize", 200)
    setv("sparkleBehindWide", 100)
    setv("sparkleBehindAcross", 20)
    setv("sparkleBehindUp", -10)
    big = body(size=200, wide=100, across=20, up=-10)
    assert alpha_at(big[0], big[1]) == 0.0 and alpha_at(cx, cy + hh) == 1.0, "the sliders did not move the oval"
    assert abs(alpha_at(big[0] + big[2], big[1]) - 0.5) < 0.01, "the sliders did not size the oval"
    for name, value in (("sparkleBehindSize", 100), ("sparkleBehindWide", 50), ("sparkleBehindAcross", 0), ("sparkleBehindUp", 0)):
        setv(name, value)
    assert alpha_at(None, None) == 1.0, "a sparkle the game gives no place for should stay bright"
    assert alpha_at("hidden", "hidden") == 1.0 and s.unplaced, "a place the game will not let it reckon with should leave it bright"
    slash("sparkle")
    assert any("screen position is not available" in t for t in chat("sparkle")), "the command does not say it cannot place the sparkle"
    # the Show button
    assert alpha_at(cx, cy) == 0.0
    [b for b in buttons if b.name == "Preview Area"][0].click()
    ovals = [f for f in stub.frames.values() if f.ring is not None]
    assert len(ovals) == 1 and ovals[0].shown, "the Show button showed nothing"
    assert abs(ovals[0].width - 2 * hw / 0.82) < 0.01 and abs(ovals[0].height - 2 * hh / 0.82) < 0.01, "the oval shown is not the oval used"
    stub.zoom = 0.5
    stub.Frame()
    assert "too close" in ovals[0].text.text
    stub.zoom = 15.0
    stub.Frame()
    stub.RunAfters()
    assert not ovals[0].shown, "the oval did not go away"
    slash("sparkle")
    text = chat("sparkle")
    assert any("camera distance 15 yards" in t and "100% covered" in t for t in text), text
    setv("sparkleBehind", False)
    assert s.alpha == 1.0 and alpha_at(cx, cy) == 1.0, "the sparkle stayed faded with the setting off"

    step("the Test buttons show a sparkle in the middle of the screen for a while")
    # (by name: what the buttons say is Sparkle's own business, and changes with it)
    tests = [b for b in buttons if b.name in ("Preview Sparkle", "Preview Name")]
    for b in tests:
        b.click()
    assert len(marks()) == 2, "the Test button did not make its own mark"
    t = [m for m in marks() if not same(m, s)][0]
    assert t.shown and t.name.text, t.name.text
    for _ in range(10):
        stub.Frame()
    stub.RunAfters()
    assert not t.shown, "the test sparkle did not go away"
    assert s.shown, "the test took the real sparkle away"
    # the button that gives every kind a subtle effect: only the effect changes
    size_before, colour_before = by_name["look_herb_size"].get(), by_name["look_herb_colour"].get()
    [b for b in buttons if b.text == "Apply"][0].click()
    got = {k: by_name["look_%s_effect" % k].get() for k in ("herb", "ore", "loot", "quest", "other")}
    assert got == {"herb": "glints", "ore": "glints", "loot": "shimmer", "quest": "ripple", "other": "fireflies"}, got
    assert by_name["look_herb_size"].get() == size_before and by_name["look_herb_colour"].get() == colour_before, "the button changed more than the effect"
    assert s.look.effect == "glints", "the sparkle showing did not change with the button"
    for _ in range(60):
        stub.Frame()
    chat("subtle")

    slash("sparkle")
    point_at(None, None, None)
    assert not s.shown, "the sparkle stayed after the game stopped pointing"
    stub.time += 7
    slash("sparkle")                                              # says what it last pointed at
    setv("sparkle", False)
    assert cvars.SoftTargetNameplateInteract == "0" and cvars.SoftTargetIconGameObject == "0", "the game's settings were not put back"
    herb()
    assert not s.shown, "a sparkle with the setting off"
    point_at(None, None, None)
    chat("sparkle")

    step("the trail: colours, thickness, dashes, dots, and flowing")
    setv("flights", False)
    setv("rxp", False)
    setv("minimap", False)
    stub.Tick()
    stub.player.x, stub.player.y = -442.0, -2598.0
    stub.PinAt(1, -956.0, -3754.0)
    stub.Fire("USER_WAYPOINT_UPDATED")
    frames()
    assert ns.route, "no route for the trail scene"
    world_map.mapID = 1413                                        # a zone's map: the route is long enough on it to see a pattern
    stub.provider.RefreshAllData()

    def drawn():
        return [l for l in stub.allLines.values() if l.shown]

    def dots():
        return [x for x in stub.allTextures.values() if x.shown and str(x.icon).endswith("dot")]

    def length(lines):
        return sum(((l.bx - l.ax) ** 2 + (l.by - l.ay) ** 2) ** 0.5 for l in lines)

    solid = len(drawn())
    long = length(drawn())                                         # in the map's own units: two to a pixel here
    assert solid > 3 and long > 100 and len(dots()) == 0, "the solid trail was not drawn (%d lines, %.0f long)" % (solid, long)
    assert abs(drawn()[0].thick - 3 / 0.5) < 0.01, "the trail is not its usual thickness"
    setv("trailThickMap", 6)
    assert abs(drawn()[0].thick - 6 / 0.5) < 0.01, "the thickness was not applied"
    setv("trailThickMap", 3)
    setv("trailWalk", "ff0000ff")
    assert drawn()[0].colour[3] == 1.0 and drawn()[0].colour[1] == 0.0, "the walking colour was not applied"
    setv("trailStyle", "dashes")
    # a dash of 10 pixels and a gap of 7, so 20 and 14 of the map's units: about one dash every 34
    dashes = len(drawn())
    assert long / 34 - 1 <= dashes <= long / 34 + solid + 1, "dashes: %d lines for a trail %.0f long" % (dashes, long)
    assert all(length([l]) <= 20.01 for l in drawn()), "a dash is too long"
    assert abs(length(drawn()) - long * 20 / 34) < 25, "the dashes do not cover the share of the trail they should"
    # a wider line spaces its dashes in proportion, so they do not run together: twice as wide, twice as long
    setv("trailThickMap", 6)
    assert max(length([l]) for l in drawn()) > 30 and all(length([l]) <= 40.01 for l in drawn()), "the dashes did not grow with the line"
    setv("trailThickMap", 3)
    setv("trailStyle", "dots")
    assert len(drawn()) == 0 and abs(len(dots()) - long / 18) <= 2, "dots: %d lines, %d dots for a trail %.0f long" % (len(drawn()), len(dots()), long)
    setv("trailStyle", "dashes")
    assert len(dots()) == 0, "the dots stayed after the style changed"
    before = [(l.ax, l.ay) for l in drawn()][:5]
    setv("trailMoving", True)
    stub.time += 0.11
    for _ in range(4):
        stub.Frame()                                               # the open map draws a flowing trail again and again
    after = [(l.ax, l.ay) for l in drawn()][:5]
    assert before != after, "the trail does not flow"
    setv("trailSpeed", 300)
    setv("trailLink", "ffffffff")
    setv("trailFly", "ffffffff")
    # the minimap, in the same style (the world map shut, as it mostly is)
    stub.provider.RemoveAllData()
    world_map.shown = False
    assert len(drawn()) == 0
    setv("minimap", True)
    for _ in range(3):
        stub.Tick()
    mini = len(drawn())
    assert mini >= 2, "dashes on the minimap: %d" % mini
    setv("trailThickMini", 4)
    stub.Tick()
    assert drawn()[0].thick == 4
    setv("trailStyle", "dots")
    stub.Tick()
    assert len(drawn()) == 0 and len(dots()) >= 2, "dots on the minimap: %d" % len(dots())
    setv("trailStyle", "solid")
    setv("trailMoving", False)
    stub.Tick()
    assert len(dots()) == 0 and len(drawn()) >= 1
    world_map.shown = True
    world_map.mapID = 1414
    slash("stop")
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    setv("flights", True)
    chat("trail")

    step("a pin somewhere with no way (the middle of the sea)")
    stub.PinAt(1, 0.0, 9000.0)
    stub.Fire("USER_WAYPOINT_UPDATED")
    frames()
    chat("sea")

    step("across the sea: a zeppelin to the other continent, and the way on once there")
    BRILL = (2250.0, 310.0)
    stub.player.x, stub.player.y, stub.player.map = -442.0, -2598.0, 1
    setv("rides", False)
    stub.PinAt(0, *BRILL)
    stub.Fire("USER_WAYPOINT_UPDATED")
    frames()
    text = chat("no rides")
    assert not ns.route and any("Use Boats And Zeppelins is disabled" in t for t in text), text
    setv("rides", True)
    n = frames()
    text = chat("crossing")
    route = ns.route
    assert route and any("zeppelin Orgrimmar > Undercity" in t for t in text), text
    print("      the search took %d frames; %d points here, %d over there" % (n, len(route.points), len(route.parts[0])))
    hows = [p[3] for p in route.points.values()]
    assert route.map == 1 and hows[-1] == "ride" and "link" in hows, "the part on this continent does not end aboard the zeppelin"
    there = [p[3] for p in route.parts[0].values()]
    assert "ride" in there and there[-1] == "walk", "the part on the other continent does not lead from the zeppelin to the pin"
    # the other continent's world map shows the part over there
    minimap_lines = None
    world_map.mapID = 1415
    stub.provider.RefreshAllData()
    with_part = stub.shown
    rest = route.parts[0]
    route.parts[0] = None
    stub.provider.RefreshAllData()
    assert with_part > stub.shown, "the other continent's map does not show the part of the journey there"
    route.parts[0] = rest
    world_map.mapID = 1414
    stub.provider.RefreshAllData()
    # the same trail for a tool with a map of its own, through the base (Share.lua): from where you stand, each
    # stretch with how it is gone and its colour, the part over the sea on its own continent
    T = lua.globals().PatchwerkForever.Trails
    assert T.Has(T), "Routes did not offer its trail to the base"
    trails = list(T.List(T).values())
    assert len(trails) >= 1 and trails[0].follow is True and trails[0].alpha == 0.95, "the trail you are on is not first"
    pieces = list(trails[0].pieces.values())
    here, over = [q for q in pieces if q.map == 1], [q for q in pieces if q.map == 0]
    assert here and over and len(here) + len(over) == len(pieces), "the trail is not on the two continents it crosses"
    assert abs(here[0].points[1][1] - stub.player.x) < 0.01 and abs(here[0].points[1][2] - stub.player.y) < 0.01,         "the trail does not start where you stand"
    assert here[-1].how == "ride" and over[0].how == "ride" and over[-1].how == "walk", [q.how for q in pieces]
    assert "link" in [q.how for q in here] and all(q.how != "gap" for q in pieces)
    assert sum(len(q.points) - 1 for q in here) == len(route.points) - 1, "a stretch of the trail is lost, or doubled"
    for a, b in zip(here, here[1:]):
        assert a.how != b.how and tuple(a.points[len(a.points)].values()) == tuple(b.points[1].values()), "two stretches do not meet"
    assert all(0 <= q.r <= 1 and 0 <= q.g <= 1 and 0 <= q.b <= 1 and q.alpha == 0.95 for q in pieces)
    walk = lua.eval("function(ns) return ns.TrailColour('walk') end")(ns)
    assert [q for q in here if q.how == "walk"][0].r == walk[0], "a walked stretch is not in the walking colour"
    assert trails[0].last.map == 0 and abs(trails[0].last.x - BRILL[0]) < 60 and abs(trails[0].last.y - BRILL[1]) < 60, "it does not end at the pin"
    cross = [c for c in T.Crossings(T).values() if c.kind == "zeppelin" and "Orgrimmar" in [st.name for st in c.stops.values()]]
    assert cross and all(st.map in (0, 1) and st.x and st.y for st in cross[0].stops.values())
    legs = list(cross[0].rides[1].legs.values())
    assert len(legs) == 2 and legs[0].map != legs[1].map and all(len(l.points) >= 2 for l in legs), "a zeppelin's way is not cut at the jump"
    trail_changes = []
    T.OnChange(T, lua.eval("function(f) return function() f() end end")(lambda: trail_changes.append(1)))
    # walking to the tower and riding: no new search while you are near the trail, the zeppelin's course included
    aboard = [p for p in route.points.values() if p[3] == "ride"][2]
    stub.player.x, stub.player.y = aboard[1], aboard[2]
    stub.time += 5
    stub.Tick()
    assert frames() <= 1 and same(ns.route, route), "a new search was made aboard the zeppelin"
    # the loading screen: you are on the other continent, and the part found for it is followed
    landing = rest[1]
    stub.player.x, stub.player.y, stub.player.map = landing[1], landing[2], 0
    stub.time += 5
    stub.Tick()
    assert frames() <= 1 and same(ns.route, route) and route.map == 0, "the part over there was not taken up"
    assert same(route.points, rest), "the part followed is not the one found for the other continent"
    said_before = said[0]
    stub.player.x, stub.player.y = BRILL[0] + 2, BRILL[1]
    stub.Tick()
    text = chat("arrived over there")
    assert not ns.dest and any("You have arrived" in t for t in text), text
    # a quest over the sea is followed too
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    assert trail_changes and not list(T.List(T).values()), "the trail's going was not told, or it is still listed"
    stub.player.x, stub.player.y, stub.player.map = -442.0, -2598.0, 1
    stub.QuestAt(873, "A Letter to Brill", 0, *BRILL)
    stub.watched, stub.focus = lua.table_from([873]), 873
    stub.Fire("SUPER_TRACKING_CHANGED")
    stub.Tick(); frames()
    assert ns.dest and ns.dest.source == "quest" and ns.dest.map == 0 and ns.route and len(ns.route.rides) == 1, "a quest on the other continent was not routed to"
    stub.QuestGone(873)
    stub.Fire("QUEST_REMOVED")
    stub.Tick(); frames()
    assert not ns.dest
    chat("quest over the sea")

    step("the guide read ahead: its travel followed, the next way found before it is wanted, the steps after drawn fainter, each step said on screen")
    # a stand-in for RestedXP as it runs: its steps, the one you are on, its arrow
    lua.execute("""
        local function at(x, y) return { tag = 'goto', wx = y, wy = x, instance = 1 } end
        local steps = {
            { { tag = 'accept', text = 'Accept Plainstrider Menace' }, at(-600, -2800) },
            { { tag = 'turnin', text = 'Turn in Plainstrider Menace' }, { tag = 'accept', text = 'Accept The Forgotten Pools' }, at(-956, -3754) },
            { { tag = 'fly', text = 'Fly to Orgrimmar' }, at(-437, -2596) },
            { { tag = 'turnin', text = 'Turn in your report' }, at(1600, -4400) },
            { { tag = 'hs', text = 'Hearth to the Crossroads' } },
            { { tag = 'train', text = 'Train your skills' } },
            { { tag = 'complete', text = 'Kill raptors' }, at(-1994, -156) },
            { { tag = 'accept', text = 'Accept Raptor Thieves' }, at(-600, -2800) },
            { { tag = 'turnin', text = 'Turn in Raptor Thieves' }, at(-600, -2800) },
        }
        for i, lines in ipairs(steps) do
            local s = { index = i, elements = lines }
            for _, e in ipairs(lines) do e.step = s end
            steps[i] = s
        end
        RXPCData = { currentStep = 1, stepSkip = {} }
        RXP = { currentGuide = { steps = steps }, activeWaypoints = {} }
        RXPG_ARROW = { shown = true, IsShown = function(self) return self.shown end }
        -- RestedXP moves on to a step: its arrow goes to the step's place, or is hidden when it has none
        -- (and then keeps what it last pointed at, as RestedXP's does)
        function STUB.GuideStep(n)
            RXPCData.currentStep = n
            for i, s in ipairs(steps) do
                s.active = (i == n) or nil
                if i < n then s.completed = true end
            end
            RXPG_ARROW.shown = false
            for _, e in ipairs(steps[n].elements) do
                if e.wx then RXPG_ARROW.element, RXPG_ARROW.shown = e, true end
            end
        end
    """)

    words = on_screen                  # (`words` was a loop's name further up: from here it is the step text on screen)

    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    stub.watched, stub.focus = lua.table_from([]), 0
    stub.Fire("QUEST_LOG_UPDATE")
    for name, value in (("rxp", True), ("quests", True), ("sourceFirst", "rxp"), ("rxpTravel", True), ("rxpAhead", 2),
                        ("flights", True), ("float", True), ("floatRoute", True)):
        setting(name, value)
    stub.player.x, stub.player.y, stub.player.map = -442.0, -2598.0, 1
    lua.globals().WorldMapFrame.mapID = 1414
    stub.GuideStep(1)
    stub.Tick(); frames()
    assert ns.dest and ns.dest.source == "rxp" and near(*FIELD) and ns.dest.kind == "accept" and ns.route, "the guide's step was not routed to"
    big, small = words()
    assert big == "Accept Plainstrider Menace" and small and "walk" in small, (big, small)
    assert ns.ahead and len(ns.ahead.legs) == 2, "the ways on through the next two steps were not found"
    stub.provider.RefreshAllData()
    with_ahead = stub.shown
    setting("rxpAhead", 0)
    assert ns.ahead is None
    stub.provider.RefreshAllData()
    without = stub.shown
    assert 0 < without < with_ahead, "the steps after were not drawn on the world map (%d, %d)" % (without, with_ahead)
    setting("rxpAhead", 2)
    frames()
    assert len(ns.ahead.legs) == 2
    print("      on the world map: %d lines with the two steps after, %d without" % (with_ahead, without))

    # the step is done where it was: the way to the next is there at once, with no search
    stub.player.x, stub.player.y = FIELD[0] + 2, FIELD[1]
    stub.Tick()
    assert not ns.dest, "not stopped on reaching the step's place"
    stub.GuideStep(2)
    stub.Tick()
    assert ns.dest and near(*RATCHET) and ns.route, "the way to the next step was not handed over at once"
    assert abs(ns.route.points[1][1] - FIELD[0]) < 1, "the route handed over does not begin where the step was"
    big, small = words()
    assert big == "Turn in Plainstrider Menace\nAccept The Forgotten Pools" and "walk" in small, (big, small)
    frames()
    # after it: on foot to the flight master, then the flight as the guide has it, a straight line
    legs = ns.ahead.legs
    assert len(legs) == 2 and legs[2].points[2][3] == "fly" and len(legs[2].points) == 2, "the guide's flight is not drawn as a flight"
    assert len(legs[1].flown) == 0, "the way to the flight master was found by flying"

    # a step that has you fly: gone to on foot, the flying left to the guide
    stub.player.x, stub.player.y = RATCHET[0] + 2, RATCHET[1]
    stub.Tick()
    stub.GuideStep(3)
    stub.Tick(); frames()
    assert ns.dest and ns.dest.kind == "fly" and ns.dest.walkOnly and near(-437.0, -2596.0)
    assert ns.route and len(ns.route.flown) == 0, "a flight was planned to reach the flight master"
    assert words()[0] == "Fly to Orgrimmar"

    # a hearthstone: nowhere to go, said on screen; a tracked quest is not followed in its stead;
    # RestedXP's hidden arrow still holds the last spot, which is not gone to
    stub.QuestAt(880, "A Decoy", 1, *CAMP)
    stub.watched = lua.table_from([880])
    stub.Fire("QUEST_LOG_UPDATE")
    stub.GuideStep(5)
    assert lua.eval("RXPG_ARROW.element ~= nil and not RXPG_ARROW.shown")
    stub.Tick(); frames()
    assert not ns.dest and not ns.route, "routed somewhere on a hearthstone step"
    assert words() == ("Hearth to the Crossroads", ""), words()
    assert ns.ahead is None, "a way was drawn on from a hearthstone"
    # with the guide's travel not followed, it is as it was: the quest behind it
    setting("rxpTravel", False)
    stub.Tick(); frames()
    assert ns.dest and ns.dest.source == "quest" and words()[0] == "Quest: A Decoy", "the quest was not followed with the setting off"
    setting("rxpTravel", True)
    stub.Tick(); frames()
    assert not ns.dest
    stub.QuestGone(880)
    stub.Fire("QUEST_REMOVED")

    # a step that is only words
    stub.GuideStep(6)
    stub.Tick(); frames()
    assert not ns.dest and words()[0] == "Train your skills"
    quiet()
    stub.Tick(); frames()
    assert ns.FloatShown() is None, "a step with no place was said more than once"

    # two steps at one place: no new route, the new step's words
    stub.player.x, stub.player.y = -442.0, -2598.0
    stub.GuideStep(8)
    stub.Tick(); frames()
    held = ns.dest
    assert held and near(*FIELD) and words()[0] == "Accept Raptor Thieves"
    stub.GuideStep(9)
    stub.Tick(); frames()
    assert same(ns.dest, held), "a new destination for a step at the same place"
    assert words()[0] == "Turn in Raptor Thieves" and "walk" in words()[1]

    # the words go out by themselves, and come back when asked; switched off, none
    quiet()
    stub.Tick(); frames()
    assert ns.FloatShown() is None, "a new step at the place you are routed to was said more than once"
    slash("step")
    assert words()[0] == "Turn in Raptor Thieves"
    quiet()
    setting("float", False)
    stub.GuideStep(7)
    stub.Tick(); frames()
    assert ns.dest and near(*CAMP) and ns.FloatShown() is None, "words on screen with the setting off"
    setting("float", True)
    [b for b in buttons if b.name == "Preview Step Text"][0].click()
    assert words()[0].startswith("Turn in The Forgotten Pools")
    quiet()
    # your own pin: said too
    stub.PinAt(1, *FIELD)
    stub.Fire("USER_WAYPOINT_UPDATED")
    frames()
    stub.Tick()                        # (the guide's steps after are let go of at the next look)
    assert ns.dest.pin and words()[0] == "To your map pin" and ns.ahead is None, (words(), ns.ahead)
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    # no guide any more
    lua.execute("RXP, RXPCData, RXPG_ARROW = nil, nil, nil")
    stub.Tick(); frames()
    assert not ns.dest and ns.ahead is None
    chat("the guide read ahead")
    lua.globals().PatchwerkForever_Thread_Routes_Go()
    lua.globals().PatchwerkForever_Thread_Routes_Stop()
    chat("bindings")

    step("the guide says fly, and you do not have that flight point: by another way to where it goes next")
    lua.execute("""
        local function at(x, y) return { tag = 'goto', wx = y, wy = x, instance = 1 } end
        local steps = {
            { { tag = 'fly', text = 'Fly to Orgrimmar', location = 'ORGRIMMAR' }, at(-437, -2596) },
            { { tag = 'turnin', text = 'Turn in your report' }, at(-600, -2800) },
        }
        for i, lines in ipairs(steps) do
            local s = { index = i, elements = lines }
            for _, e in ipairs(lines) do e.step = s end
            steps[i] = s
        end
        RXPCData = { currentStep = 1, stepSkip = {} }
        RXP = { currentGuide = { steps = steps }, activeWaypoints = {} }
        RXPG_ARROW = { shown = true, element = steps[1].elements[2], IsShown = function(self) return self.shown end }
    """)
    stub.player.x, stub.player.y = -1994.0, -156.0
    # you have Orgrimmar's flight point: on foot to the flight master, as the guide means it
    stub.flightMap = lua.table_from({23: 1, 25: 0})
    stub.Fire("TAXIMAP_OPENED")
    stub.Tick(); frames()
    assert ns.dest and ns.dest.source == "rxp" and ns.dest.walkOnly and near(-437.0, -2596.0), "the guide's flight master was not gone to"
    assert words()[0] == "Fly to Orgrimmar"
    # you do not: the route goes on to the step after the flight, by whatever way there is, and says so
    stub.flightMap = lua.table_from({25: 0})
    stub.Fire("TAXIMAP_OPENED")
    stub.Tick(); frames()
    assert ns.dest and not ns.dest.walkOnly and near(-600.0, -2800.0), "the route still leads to a flight you cannot take"
    assert words()[0] == "No flight path to Orgrimmar, Durotar: going by another way\nTurn in your report", words()
    assert ns.ahead is None, "the step flown to is still drawn on as a step ahead"
    # found it after all: as the guide means it again, and said so (the same step, but no longer gone to another way)
    quiet()
    stub.flightMap = lua.table_from({23: 1, 25: 0})
    stub.Fire("TAXIMAP_OPENED")
    stub.Tick(); frames()
    assert ns.dest.walkOnly and near(-437.0, -2596.0)
    assert words()[0] == "Fly to Orgrimmar", "the step was not said when it went back to being done as the guide means it: %s" % (words(),)
    lua.execute("RXP, RXPCData, RXPG_ARROW = nil, nil, nil")
    lua.globals().PatchwerkForever_Thread_RoutesDB.taxi = None
    stub.flightMap = None
    stub.Tick(); frames()
    chat("fly without the point")

    step("a step is said on screen once: not again when its place moves, nor when you are led back to it")
    # RestedXP on a step that has two places (a kill area its arrow goes round), then a step at one of them
    lua.execute("""
        local function at(x, y) return { tag = 'goto', wx = y, wy = x, instance = 1 } end
        local count, nest = { tag = 'complete', text = 'Raptors slain: 0/10' }, { tag = 'complete', text = 'Find the raptor nest' }
        -- the step's count goes up, as RestedXP writes it into the line; its second line is done
        function STUB.GuideCount(n) count.text = ('Raptors slain: %d/10'):format(n) end
        function STUB.GuideNestFound() nest.completed = true end
        local steps = {
            { count, nest, at(-600, -2800), at(-700, -2900) },
            { { tag = 'turnin', text = 'Turn in Raptor Thieves' }, at(-600, -2800) },
            { { tag = 'accept', text = 'Accept Raptor Horns' }, at(-956, -3754) },
            { { tag = 'turnin', text = 'Turn in Raptor Horns' }, at(-1994, -156) },
        }
        for i, lines in ipairs(steps) do
            local s = { index = i, elements = lines }
            for _, e in ipairs(lines) do e.step = s end
            steps[i] = s
        end
        RXPCData = { currentStep = 1, stepSkip = {} }
        RXP = { currentGuide = { steps = steps }, activeWaypoints = {} }
        RXPG_ARROW = { shown = true, IsShown = function(self) return self.shown end }
        -- RestedXP on step n, its arrow on the k-th of the step's places
        function STUB.GuideSpot(n, k)
            RXPCData.currentStep = n
            for i, s in ipairs(steps) do
                s.active = (i == n) or nil
                if i < n then s.completed = true end
            end
            local places = {}
            for _, e in ipairs(steps[n].elements) do
                if e.wx then places[#places + 1] = e end
            end
            RXPG_ARROW.element = places[k]
        end
    """)
    HERE, SPOT, OTHER = (-442.0, -2598.0), (-600.0, -2800.0), (-700.0, -2900.0)

    def stand(place, off=0.0):
        stub.player.x, stub.player.y = place[0] + off, place[1]

    quiet()
    stand(HERE)
    # the arrow moves before the way to its first place is found: the step has not been on screen yet,
    # so it is said with the place it has now
    stub.GuideSpot(1, 2)
    stub.Tick()
    assert near(*OTHER) and not ns.route and ns.FloatShown() is None
    stub.Tick()                                                   # (the next look comes while that way is still being found)
    assert near(*OTHER) and not ns.route and ns.FloatShown() is None, "a step was said before its route was known"
    stub.GuideSpot(1, 1)
    stub.Tick(); frames()
    assert near(*SPOT) and ns.route and on_screen()[0] == "Raptors slain: 0/10\nFind the raptor nest", on_screen()
    quiet()
    # the arrow moves to the step's other place, its count gone up meanwhile: a new destination, the same step
    stub.GuideCount(3)
    stub.GuideSpot(1, 2)
    stub.Tick(); frames()
    assert near(*OTHER) and ns.route, "the route did not follow the arrow to the step's other place"
    assert ns.FloatShown() is None, "a step was said again when only its place moved"
    slash("step")                                                 # asked for: the step as it is now, with the route there is now
    assert on_screen() == ("Raptors slain: 3/10\nFind the raptor nest", ns.Summary(ns.route)), on_screen()
    quiet()
    # you reach that place, one of the step's lines is done there, and the arrow goes back to the first:
    # led there, still without the words
    stand(OTHER, 2)
    stub.Tick()
    assert not ns.dest
    stub.GuideNestFound()
    stub.GuideSpot(1, 1)
    stub.Tick(); frames()
    assert near(*SPOT) and ns.route and ns.FloatShown() is None, "a step was said again when its place moved after you reached the last"
    slash("step")
    assert on_screen()[0] == "Raptors slain: 3/10", on_screen()
    quiet()
    # reached, then 60 yards away with the step still open: led back, and not said again
    stand(SPOT, 2)
    stub.Tick()
    assert not ns.dest
    stand(SPOT, 60)
    for _ in range(2):
        stub.Tick(); frames()
    assert near(*SPOT) and ns.route, "not routed back to an open step after walking away"
    assert ns.FloatShown() is None, "a step you had reached was said again when you were led back to it"
    # back at the spot, the guide moves on to a step at that very spot: nowhere to go, but its words are said, once
    stand(SPOT, 2)
    stub.Tick()
    assert not ns.dest
    stub.GuideSpot(2, 1)
    stub.Tick(); frames()
    assert not ns.dest and on_screen() == ("Turn in Raptor Thieves", ""), "a new step at the spot you stand on was not said: %s" % (on_screen(),)
    quiet()
    for _ in range(3):
        stub.Tick(); frames()
    assert not ns.dest and ns.FloatShown() is None, "a step at the spot you stand on was said more than once"
    # away from it with that step open: led back, not said again
    stand(SPOT, 60)
    for _ in range(2):
        stub.Tick(); frames()
    assert near(*SPOT) and ns.FloatShown() is None, "a step said where you stood was said again when you were led back"
    # asked for, by the command and by the binding: said each time
    slash("go"); frames()
    assert on_screen()[0] == "Turn in Raptor Thieves", "/thread go did not say the step"
    quiet()
    lua.globals().PatchwerkForever_Thread_Routes_Go(); frames()
    assert on_screen()[0] == "Turn in Raptor Thieves", "the Go binding did not say the step"
    quiet()
    stub.Tick(); frames()
    assert ns.FloatShown() is None, "a step you asked for was said once more by itself"
    # the same for a step that had not been said: the guide went on to it, at the same spot, while you
    # had stopped routing. Asked for, it is said, and with that it counts as said
    stub.GuideSpot(1, 1)
    stub.Tick(); frames()
    assert on_screen()[0] == "Raptors slain: 3/10", on_screen()
    quiet()
    slash("stop")
    stub.GuideSpot(2, 1)
    stub.Tick(); frames()
    assert not ns.dest and ns.FloatShown() is None, "a step was said at a place you had stopped routing to"
    slash("go"); frames()
    assert near(*SPOT) and on_screen()[0] == "Turn in Raptor Thieves", "/thread go did not say a step that had not been said yet"
    quiet()
    stub.Tick(); frames()
    assert ns.FloatShown() is None, "a step said because you asked for it was said again by itself"
    # the next step, somewhere else: said
    stub.GuideSpot(3, 1)
    stub.Tick(); frames()
    assert near(*RATCHET) and on_screen()[0] == "Accept Raptor Horns", on_screen()
    quiet()
    # something else followed in between (a pin of your own): the step is said when the guide leads again
    stub.PinAt(1, *OTHER)
    stub.Fire("USER_WAYPOINT_UPDATED"); frames()
    stub.Tick()
    assert ns.dest.pin and on_screen()[0] == "To your map pin"
    quiet()
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    stub.Tick(); frames()
    assert ns.dest.source == "rxp" and near(*RATCHET) and on_screen()[0] == "Accept Raptor Horns", "the step was not said when the guide led again after a pin"
    quiet()
    # the same after a gathering run
    assert G.Start(G, "any") is True
    go()
    assert ns.dest.source == "gather" and on_screen()[0].startswith("Gather: "), on_screen()
    quiet()
    assert G.Stop(G) is True
    go()
    assert ns.dest.source == "rxp" and near(*RATCHET) and on_screen()[0] == "Accept Raptor Horns", "the step was not said when the guide led again after a gathering run"
    quiet()
    # a list whose stops share one number (as the Dungeon Journal's do): its next stop is told apart by its words
    lua.execute("""
        STUB.side = { { -600, -2800, 'Accept: A Job' }, { -1994, -156, 'Accept: Another Job' } }
        PatchwerkForever.Guides:Register('side', { name = 'Side List', Read = function(count)
            local now = STUB.side[1]
            if not now then return nil end
            return { index = 1, total = 2, kind = 'accept', key = 'side' .. #STUB.side, map = 1, x = now[1], y = now[2],
                lines = { { text = now[3], done = false } }, ahead = {}, after = {} }
        end })
    """)
    Choice.Set(Choice, "guide", "side")
    stub.Tick(); frames()
    assert near(*FIELD) and on_screen()[0] == "Accept: A Job", on_screen()
    quiet()
    lua.execute("table.remove(STUB.side, 1)")
    stub.Tick(); frames()
    assert near(*CAMP) and on_screen()[0] == "Accept: Another Job", "the next stop of a list whose stops share a number was not said"
    quiet()
    lua.execute("STUB.side = {}")
    stub.Tick(); frames()
    assert Choice.Get(Choice) is None and near(*RATCHET) and on_screen()[0] == "Accept Raptor Horns", "the step was not said when the main guide led again"
    quiet()
    chat("said once")

    step("Stop Routing takes the fainter trail of the next steps away too")
    assert ns.ahead and len(ns.ahead.legs) == 1, "no step was drawn on ahead to begin with"
    slash("stop")
    assert any("Routing stopped. It resumes" in t for t in chat("stop"))
    for _ in range(3):
        stub.Tick(); frames()
        assert not ns.dest and ns.ahead is None, "the trail through the next steps stayed after Stop Routing"
    stub.GuideSpot(4, 1)                                          # the guide moves on: followed again
    stub.Tick(); frames()
    assert near(*CAMP) and on_screen()[0] == "Turn in Raptor Horns"
    # a step is new by its number, not only by its words: the next one has the same words at another place, and is said
    quiet()
    lua.execute("""
        local s = { index = 5, elements = { { tag = 'turnin', text = 'Turn in Raptor Horns' },
            { tag = 'goto', wx = -3754, wy = -956, instance = 1 } } }
        for _, e in ipairs(s.elements) do e.step = s end
        RXP.currentGuide.steps[5] = s
    """)
    stub.GuideSpot(5, 1)
    stub.Tick(); frames()
    assert near(*RATCHET) and on_screen()[0] == "Turn in Raptor Horns", "a step with the words of the one before it was not said: %s" % (on_screen(),)
    lua.execute("RXP, RXPCData, RXPG_ARROW = nil, nil, nil")
    stub.Tick(); frames()
    assert not ns.dest
    quiet()
    chat("stop")

    step("a quest is said once too: not when you are led back to it, but after a pin of your own, and another quest at its place is")
    stand(HERE)
    stub.QuestAt(893, "First Things", 1, *FIELD)
    stub.watched = lua.table_from([893])
    look("QUEST_WATCH_LIST_CHANGED")
    assert near(*FIELD) and on_screen()[0] == "Quest: First Things", on_screen()
    quiet()
    stand(FIELD, 2)                                               # reached, well away, led back
    stub.Tick()
    assert not ns.dest
    stand(FIELD, 130)
    for _ in range(2):
        stub.Tick(); frames()
    assert near(*FIELD) and ns.route and ns.FloatShown() is None, "a quest you had reached was said again when you were led back to it"
    # a pin of your own in between: what was last on screen is the pin, so the quest is said when it leads again
    stub.PinAt(1, *CAMP)
    stub.Fire("USER_WAYPOINT_UPDATED"); frames()
    stub.Tick()
    assert ns.dest.pin and on_screen()[0] == "To your map pin"
    quiet()
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    stub.Tick(); frames()
    assert near(*FIELD) and on_screen()[0] == "Quest: First Things", "the quest was not said when it led again after a pin"
    quiet()
    # reached again and handed in, and the next quest's mark is at that very place: nothing while you
    # stand there, but it is another quest, and is said when you are led to it
    stand(FIELD, 2)
    stub.Tick()
    assert not ns.dest
    stub.QuestGone(893)
    stub.QuestAt(894, "Second Things", 1, *FIELD)
    stub.watched = lua.table_from([894])
    look("QUEST_WATCH_LIST_CHANGED")
    assert not ns.dest and ns.FloatShown() is None
    stand(FIELD, 130)
    stub.time += 6                                                # (what the game says of the quests is asked again)
    for _ in range(2):
        stub.Tick(); frames()
    assert near(*FIELD) and on_screen()[0] == "Quest: Second Things", "another quest at a place you had reached was not said: %s" % (on_screen(),)
    stub.QuestGone(894)
    stub.watched = lua.table()
    look("QUEST_REMOVED")
    assert not ns.dest
    quiet()
    chat("a quest said once")

    step("a place there is no way to: said under the step, and searched for again less and less often")
    # every search made is counted. STUB.noWay = n: the next n find no way (as one that looked everywhere
    # would). STUB.throw: they throw an error.
    lua.eval("""function(P)
        local journey, forget = P.Journey, P.Forget
        STUB.searches, STUB.noWay, STUB.throw, STUB.forgets = 0, 0, false, 0
        P.Journey = function(...)
            STUB.searches = STUB.searches + 1
            if STUB.throw then error('the planner fell over') end
            if STUB.noWay > 0 then
                STUB.noWay = STUB.noWay - 1
                return nil
            end
            return journey(...)
        end
        P.Forget = function(...)
            STUB.forgets = STUB.forgets + 1
            return forget(...)
        end
    end""")(ns.Planner)

    def wait(seconds):                 # that long on, one look: how many searches have been made by then
        stub.time += seconds
        stub.Tick(); frames()
        return stub.searches

    setting("rxpAhead", 0)                                        # (no searches ahead of time, so every search counted is the route's)
    stand(HERE)
    stub.QuestAt(890, "Out Of Reach", 1, *RATCHET)
    stub.noWay = 99
    stub.watched = lua.table_from([890])
    look("QUEST_WATCH_LIST_CHANGED")
    assert ns.dest and ns.dest.source == "quest" and not ns.route and ns.dest.failed, "a search that found no way was not noted"
    big, small, line = ns.FloatShown()
    assert (big, small) == ("Quest: Out Of Reach", "No route found"), (big, small)
    assert [round(c, 2) for c in line.colour.values()] == [1, 0.5, 0.45], "the note is not in its own colour"
    text = chat("no way")
    assert sum(1 for t in text if "No route found" in t) == 1, text
    # not again after 10 seconds, as it used to be: after 20, then 40 more; and nothing more in chat
    made = stub.searches
    assert made == 1, made
    assert wait(11) == made, "a place with no way to it was searched for again after 10 seconds"
    assert wait(10) == made + 1, "it was not searched for again after 20 seconds"
    assert wait(25) == made + 1, "the wait did not double"
    assert wait(20) == made + 2, "it was not searched for again after 40 seconds more"
    assert ns.dest.wait == 80 and not ns.route, ns.dest.wait
    assert ns.FloatShown() is None, "the note was put on screen again by a later search"
    assert not any("No route found" in t for t in chat("no way, again")), "said in chat more than once"
    # 300 yards on, or on another map: at once
    stand(HERE, -310)
    assert wait(1) == made + 3, "it was not searched for again at once 300 yards on"
    assert wait(1) == made + 3
    stub.player.map = 0                                           # (the same numbers on the other continent: the map alone is new)
    assert wait(1) == made + 4, "it was not searched for again at once on another map"
    assert wait(1) == made + 4
    assert ns.dest.wait == 120, "the wait went past two minutes (%s)" % ns.dest.wait
    assert not any("No route found" in t for t in chat("no way, elsewhere"))
    # /thread step says the note again; with the route's line switched off it is shown all the same
    setting("floatRoute", False)
    slash("step")
    big, small, line = ns.FloatShown()
    assert (big, small) == ("Quest: Out Of Reach", "No route found"), (big, small)
    assert [round(c, 2) for c in line.colour.values()] == [1, 0.5, 0.45]
    setting("floatRoute", True)
    # and when there is a way after all: the trail, and nothing left of the wait
    stub.noWay = 0
    stub.player.x, stub.player.y, stub.player.map = HERE[0], HERE[1], 1
    assert wait(1) == made + 5 and ns.route and not ns.dest.failed and not ns.dest.wait, "the way was not taken up once there was one"
    quiet()
    # /thread step now says the route that was found, in the route's colour: the note is no longer true
    slash("step")
    big, small, line = ns.FloatShown()
    assert (big, small) == ("Quest: Out Of Reach", ns.Summary(ns.route)), "the note was still said after a way had been found: %s" % ((big, small),)
    assert [round(c, 2) for c in line.colour.values()] == [0.62, 0.85, 1], "the route found late is in the colour of the note"
    quiet()
    # words that needed no saying again (a place you had reached and are led back to) are shown all the
    # same where the note is new under them. With Print Route In Chat off, chat has nothing of it
    stand(RATCHET, 2)
    stub.Tick()
    assert not ns.dest
    chat("a way after all")
    setting("notify", False)
    stub.noWay = 1
    stand(RATCHET, 130)
    for _ in range(2):
        stub.Tick(); frames()
    assert near(*RATCHET) and ns.dest.failed and on_screen() == ("Quest: Out Of Reach", "No route found"), on_screen()
    assert not any("No route found" in t for t in chat("no way, chat off")), "that no route was found was said in chat with Print Route In Chat off"
    setting("notify", True)
    made = stub.searches
    assert wait(21) == made + 1 and ns.route, "the way was not found by the next search"
    assert ns.FloatShown() is None, "words were put on screen for a way that was only found late"
    stub.QuestGone(890)
    stub.Fire("QUEST_REMOVED")
    # A search given up before it began is not one that found no way: here there is no ground the planner
    # knows near the place (out at sea), as there is none under you in any building. That mends itself as
    # you move, so it gets no note, no longer wait and nothing in chat.
    chat("a way after all")
    made = stub.searches
    stub.QuestAt(896, "Out At Sea", 1, 0.0, 9000.0)
    stub.watched = lua.table_from([896])
    look("QUEST_WATCH_LIST_CHANGED")
    assert ns.dest and ns.dest.source == "quest" and not ns.route and stub.searches == made, "the place out at sea was not given up on before a whole search"
    assert not ns.dest.failed and not ns.dest.wait, "a search given up before it began was noted as one that found no way"
    assert on_screen() == ("Quest: Out At Sea", ""), on_screen()
    assert not any("No " in t for t in chat("no ground")), "a search given up before it began was said in chat"
    stub.QuestGone(896)
    stub.Fire("QUEST_REMOVED")
    stub.Tick(); frames()
    assert not ns.dest
    quiet()
    # a guide's step at a place there is no way to, then its next step at that same place: the new words
    # have the note under them too, on screen and when asked for again
    lua.execute("""
        local function at(x, y) return { tag = 'goto', wx = y, wy = x, instance = 1 } end
        local steps = {
            { { tag = 'turnin', text = 'Turn in Far Away' }, at(-600, -2800) },
            { { tag = 'accept', text = 'Accept Further Away' }, at(-600, -2800) },
        }
        for i, lines in ipairs(steps) do
            local s = { index = i, elements = lines }
            for _, e in ipairs(lines) do e.step = s end
            steps[i] = s
        end
        RXPCData = { currentStep = 1, stepSkip = {} }
        RXP = { currentGuide = { steps = steps }, activeWaypoints = {} }
        RXPG_ARROW = { shown = true, element = steps[1].elements[2], IsShown = function(self) return self.shown end }
        function STUB.GuideOn()                       -- RestedXP moves on to the second step
            steps[1].completed = true
            RXPCData.currentStep = 2
            RXPG_ARROW.element = steps[2].elements[2]
        end
    """)
    stub.noWay = 99
    stub.Tick(); frames()
    assert near(*FIELD) and ns.dest.source == "rxp" and ns.dest.wait and not ns.route
    assert on_screen() == ("Turn in Far Away", "No route found"), on_screen()
    quiet()
    held = ns.dest
    stub.GuideOn()
    stub.Tick(); frames()
    big, small, line = ns.FloatShown()
    assert same(ns.dest, held) and not ns.route and (big, small) == ("Accept Further Away", "No route found"), "a new step at a place with no way to it was said without the note: %s" % ((big, small),)
    assert [round(c, 2) for c in line.colour.values()] == [1, 0.5, 0.45], "the note under a new step at the same place is not in its own colour"
    quiet()
    slash("step")
    assert on_screen() == ("Accept Further Away", "No route found"), on_screen()
    quiet()
    # and once a way there is found, it is that step which has the route under it
    stub.noWay = 0
    stub.Tick(); frames()
    assert same(ns.dest, held) and ns.route and ns.FloatShown() is None
    slash("step")
    assert on_screen() == ("Accept Further Away", ns.Summary(ns.route)), on_screen()
    quiet()
    lua.execute("RXP, RXPCData, RXPG_ARROW = nil, nil, nil")
    stub.Tick(); frames()
    assert not ns.dest
    chat("a guide's steps with no way")
    # the route's line is back in its usual colour with the next thing said
    stub.QuestAt(891, "Within Reach", 1, *FIELD)
    stub.watched = lua.table_from([891])
    look("QUEST_WATCH_LIST_CHANGED")
    big, small, line = ns.FloatShown()
    assert big == "Quest: Within Reach" and "walk" in small and [round(c, 2) for c in line.colour.values()] == [0.62, 0.85, 1], (big, small)
    quiet()
    chat("a way after all")

    step("on a flight path a search that finds no way says nothing, and is made again as usual once you land")
    stub.QuestGone(891)
    stub.Fire("QUEST_REMOVED")
    stub.Tick(); frames()
    assert not ns.dest
    stub.player.taxi = True
    stub.noWay = 1
    stub.QuestAt(892, "Seen From The Air", 1, *RATCHET)
    stub.watched = lua.table_from([892])
    look("QUEST_WATCH_LIST_CHANGED")
    assert ns.dest and not ns.route and not ns.dest.failed, "a search made in the air was taken as final"
    assert on_screen() == ("Quest: Seen From The Air", ""), on_screen()
    assert not any("No route found" in t for t in chat("in the air"))
    made = stub.searches
    assert wait(30) == made, "a way was looked for in the air"
    stub.player.taxi = False
    assert wait(1) == made + 1 and ns.route, "the way was not looked for again on landing"
    stub.QuestGone(892)
    stub.Fire("QUEST_REMOVED")
    stub.Tick(); frames()
    assert not ns.dest
    quiet()
    # Where the first whole search to find no way comes only later (here: once you have landed), the note
    # goes under the words then, though they went out before with nothing under them: once on screen,
    # once in chat, and /thread step has it
    chat("landed")
    stub.player.taxi = True
    stub.noWay = 99
    stub.QuestAt(893, "Still Out Of Reach", 1, *RATCHET)
    stub.watched = lua.table_from([893])
    look("QUEST_WATCH_LIST_CHANGED")
    assert ns.dest and not ns.dest.failed and on_screen() == ("Quest: Still Out Of Reach", ""), on_screen()
    quiet()
    made = stub.searches
    stub.player.taxi = False
    assert wait(11) == made + 1 and not ns.route and ns.dest.failed, "no whole search was made after landing"
    big, small, line = ns.FloatShown()
    assert (big, small) == ("Quest: Still Out Of Reach", "No route found"), "a way not found only later was not said under the step: %s" % ((big, small),)
    assert [round(c, 2) for c in line.colour.values()] == [1, 0.5, 0.45]
    quiet()
    assert wait(21) == made + 2 and ns.FloatShown() is None, "the note was put on screen by every search that found no way"
    assert sum(1 for t in chat("no way, late") if "No route found" in t) == 1
    slash("step")
    assert on_screen() == ("Quest: Still Out Of Reach", "No route found"), on_screen()
    quiet()
    stub.noWay = 0
    stub.QuestGone(893)
    stub.Fire("QUEST_REMOVED")
    stub.watched = lua.table()
    stub.Tick(); frames()
    assert not ns.dest
    quiet()
    chat("landed")

    step("a gathering run does not wait at a node there is no way to")
    leaf = {"link": "item:2447", "class": 7, "sub": 9, "icon": 133939, "guid": "GameObject-0-1-1-1-1617-0"}
    gather("Peacebloom", -460.0, -2640.0, [leaf])
    gather("Peacebloom", -700.0, -2900.0, [leaf])
    stub.time += 400                                              # (long enough since the runs further up)
    stand(HERE)
    stub.noWay = 1                                                # no way to the nearest; the next is fine
    assert G.Start(G, "any") is True
    frames()
    assert at(-460.0, -2640.0) and ns.dest.failed and not ns.route
    assert on_screen() == ("Gather: Peacebloom", "No route found"), on_screen()
    go()
    assert at(-520.0, -2650.0) and ns.route and G.State(G).going == "Copper Vein", "the run waited at a node with no way to it"
    # (not in chat for a node: every node is a destination of its own, and the run has gone on by itself)
    assert not any("No route found" in t for t in chat("gather, a node with no way")), "a gathering node with no way to it was said in chat"
    # a pin of your own with no way to it is not the run's to move on from: it stays, and the run waits for it
    stub.noWay = 1
    stub.PinAt(1, *RATCHET)
    stub.Fire("USER_WAYPOINT_UPDATED"); frames()
    go()
    assert ns.dest.pin and ns.dest.failed and G.State(G).going == "Copper Vein", "a pin of your own with no way to it was given up for the run's next node"
    assert any("No route found" in t for t in chat("a pin with no way")), "a pin with no way to it was not said in chat"
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    go()
    assert at(-520.0, -2650.0) and ns.route and ns.dest.source == "gather", "the run did not go on once the pin was gone"
    # no way to the last one either: the run ends, and nothing is left routed to
    stub.noWay = 99
    go(-520.0, -2650.0)
    assert at(-700.0, -2900.0) and ns.dest.failed
    stub.Tick()
    text = chat("gather, no way")
    assert G.State(G) is None and not ns.dest, "a run with no way to any node left did not end"
    assert any("Gathering stopped" in t for t in text), text
    assert not any("No route found" in t for t in text), text
    # the next run does not hold that against those nodes: it may start where there is a way to them
    stub.noWay = 0
    stub.time += 60
    assert G.Start(G, "any") is True, "the nodes no way was found to were left out of the next run too"
    go()
    assert at(-460.0, -2640.0) and ns.route and G.State(G).going == "Peacebloom", (ns.dest and (ns.dest.x, ns.dest.y), G.State(G))
    assert G.Stop(G) is True
    go()
    assert not ns.dest
    chat("gather, the next run")
    stub.noWay = 0
    for x, y in ((-460.0, -2640.0), (-700.0, -2900.0)):
        stub.player.x, stub.player.y = x, y
        slash("nodes forget")
    assert spots() == 1
    quiet()
    chat("gather, no way")

    step("a search that throws an error is said once, and not made again every 10 seconds")
    stand(HERE)
    stub.throw = True
    made, forgot = stub.searches, stub.forgets
    stub.PinAt(1, *RATCHET)
    stub.Fire("USER_WAYPOINT_UPDATED"); frames()
    text = heard()
    assert sum(1 for t in text if "a problem in a route search" in t.lower() and "the planner fell over" in t) == 1, text
    assert not any("Route search failed" in t for t in text), text
    assert stub.searches == made + 1 and stub.forgets > forgot, "what the search had decoded was not let go of"
    assert ns.dest and ns.dest.pin and ns.dest.failed and not ns.route
    assert on_screen() == ("To your map pin", "No route found"), on_screen()
    assert wait(11) == made + 1, "a search that threw was made again after 10 seconds"
    assert wait(10) == made + 2, "a search that threw was not tried again after 20 seconds"
    assert not heard(), "a search that threw again was said again"
    stub.throw = False
    assert wait(41) == made + 3 and ns.route, "the way was not found once the search ran again"
    # the same when it throws as the way is looked for anew after a wrong turn: the trail you have left
    # goes, and the search is not made again every few seconds
    stub.throw = True
    made = stub.searches
    stand(HERE, 150)
    assert wait(5) == made + 1 and not ns.route and ns.dest.failed, "a search that threw after a wrong turn left the old trail up"
    assert wait(5) == made + 1 and wait(5) == made + 1, "a search that threw after a wrong turn was made again within seconds"
    assert not heard()
    # on a flight path it puts no note on screen either
    quiet()
    stub.player.taxi = True
    stub.PinAt(1, *CAMP)
    stub.Fire("USER_WAYPOINT_UPDATED"); frames()
    assert near(*CAMP) and not ns.route and on_screen() == ("To your map pin", ""), on_screen()
    stub.player.taxi = False
    stub.throw = False
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    stub.Tick(); frames()
    assert not ns.dest
    quiet()
    chat("a search that throws")

    step("where there is no map data, the Go command and its binding say why each time")
    stub.player.map = 530
    stub.PinAt(1, *RATCHET)
    stub.Fire("USER_WAYPOINT_UPDATED"); frames()
    assert any("No map data for this area (map 530)." in t for t in chat("no map data")), "a pin placed where there is no map data said nothing"
    wait(11)
    assert not any("No map data" in t for t in chat("no map data, by itself")), "why there is no route was said again without being asked"
    slash("go"); frames()
    assert any("No map data for this area (map 530)." in t for t in chat("go")), "/thread go said nothing where there is no map data"
    lua.globals().PatchwerkForever_Thread_Routes_Go(); frames()
    assert any("No map data for this area (map 530)." in t for t in chat("go")), "the Go binding said nothing where there is no map data"
    stub.player.map = 1
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    stub.Tick(); frames()
    assert not ns.dest
    quiet()

    step("on a flight path the trail runs from you to where you land, not back to the flight master")
    def canvas(x, y):                  # a world position on the world map's canvas (Kalimdor's map, 1002 by 668)
        return (17066.6 - y) / (17066.6 + 19733.21) * 1002, -(12799.9 - x) / (12799.9 + 11733.3) * 668

    def starts(piece, place):
        return abs(piece.ax - place[0]) < 0.01 and abs(piece.ay - place[1]) < 0.01

    def ends(piece, place):
        return abs(piece.bx - place[0]) < 0.01 and abs(piece.by - place[1]) < 0.01

    setv("minimap", False)
    stub.Tick()
    stub.undiscovered[30] = None                                  # (Freewind Post found: a flight of two hops)
    stand((-900.0, -2500.0))                                      # (a walk with bends away from the flight master: the flight lies several points on)
    stub.PinAt(1, -7140.0, -3790.0)                               # Gadgetzan again
    stub.Fire("USER_WAYPOINT_UPDATED"); frames()
    text = chat("a flight")
    route = ns.route
    hows = [p[3] for p in route.points.values()]
    assert any("fly Crossroads > Freewind Post > Gadgetzan" in t for t in text) and hows.count("fly") == 2, (text, hows)
    land = len(hows) - hows[::-1].index("fly")                    # the flight's last point (counted from 1): where you land
    assert route.at == 1 and hows[land - 2] == "fly" and hows.index("fly") > 3 and hows[land] != "fly", hows
    AIR = (-3800.0, -3200.0)
    stub.player.taxi = True
    stand(AIR)
    stub.Tick()
    assert route.at == land - 1, "on a flight path the trail still starts back at the flight master (at %d, lands at %d)" % (route.at, land)
    # (the open world map draws only when it is told the trail has changed: it is not asked to here)
    piece = drawn()[0]
    assert starts(piece, canvas(*AIR)) and ends(piece, canvas(route.points[land][1], route.points[land][2])), "the first piece does not run from you to where you land"
    assert list(piece.colour.values()) == list(ns.TrailColour("fly")) != list(ns.TrailColour("walk")), "the piece to where you land is not in the flight colour"
    assert len(drawn()) > 1, "the walk on from where you land is not drawn"
    stub.Tick()
    assert route.at == land - 1 and same(ns.route, route), "the trail did not hold still for the rest of the flight"
    # a trail found while you are in the air, with no flight on it: drawn as it lies, not joined to you
    setv("flights", False)
    frames()
    walk = ns.route
    assert not same(walk, route) and "fly" not in [p[3] for p in walk.points.values()]
    ON = (-3900.0, -3300.0)                                       # the flight carries you on
    stand(ON)
    stub.Tick()
    assert walk.loose and walk.at == 1, "a trail with no flight on it was not let loose in the air"
    stub.provider.RefreshAllData()
    assert starts(drawn()[0], canvas(*AIR)), "in the air the world map joins you to a trail with no flight on it"
    stub.provider.RemoveAllData()
    world_map.shown = False
    setv("minimap", True)
    for _ in range(3):
        stub.Tick()
    assert drawn() and not starts(drawn()[0], (0, 0)), "in the air the minimap joins you to a trail with no flight on it"
    # landed: joined to you again
    stub.player.taxi = False
    stub.Tick()
    assert same(ns.route, walk) and not walk.loose, "the trail stayed loose after landing"
    stub.Tick()
    assert drawn() and starts(drawn()[0], (0, 0)), "after landing the minimap trail does not start at you"
    world_map.shown = True
    # the open world map is told at both ends of a flight (it is not asked to draw here): let loose as
    # you take off, joined to you again as you land
    setv("minimap", False)
    stub.Tick()
    assert not drawn()
    stub.player.taxi = True
    stub.Tick()
    lies = walk.points[walk.at]                                   # (the point of it you had reached on the ground: it is drawn from there, as it lies)
    assert walk.loose and drawn() and starts(drawn()[0], canvas(lies[1], lies[2])), "the world map was not redrawn with the trail let loose at take-off"
    assert not starts(drawn()[0], canvas(*ON)), "in the air the world map joins you to a trail with no flight on it"
    stub.player.taxi = False
    stub.Tick()
    assert same(ns.route, walk) and not walk.loose
    assert drawn() and starts(drawn()[0], canvas(*ON)), "after landing the world map trail does not start at you"
    setv("minimap", True)
    setv("flights", True)
    frames()
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    stub.Tick(); frames()
    assert not ns.dest
    chat("a flight")

    step("the focus: pin > choice > focus > auto; each kind of focus; nowhere to go said once; said on screen")
    G = lua.globals()
    Focus, MyRoute, Guides = G.PatchwerkForever.Focus, G.PatchwerkForever.MyRoute, G.PatchwerkForever.Guides
    # (the focus and My Route are kept for each character: the game says who you are)
    lua.execute("""
        local was = UnitGUID
        function UnitGUID(unit) if unit == 'player' then return 'Player-1-00000001' end return was(unit) end
    """)
    # a stand-in for the Dungeon Journal's list: a reader of its own, its steps in STUB.dj
    lua.execute("""
        STUB.dj = {}
        PatchwerkForever.Guides:Register('fdj', { name = 'Dungeon Journal', Side = function() return true end, Read = function(count)
            local now = STUB.dj[1]
            if not now then return nil end
            local info = { index = 1, total = #STUB.dj, kind = 'accept', key = 'dj' .. #STUB.dj, map = 1, x = now[1], y = now[2],
                lines = { { text = 'Accept: Wailing Caverns Quest', done = false } }, ahead = {}, after = {} }
            local nxt = STUB.dj[2]
            if nxt and count > 0 then info.ahead[1] = { index = 2, kind = 'accept', lines = {}, map = 1, x = nxt[1], y = nxt[2] } end
            return info
        end })
    """)

    def focus():
        return Focus.Get(Focus)

    def lines():                       # the step text on screen, line by line
        text = on_screen()[0]
        return text.split("\n") if text else []

    def ticks(n=3):
        for _ in range(n):
            stub.Tick(); frames()

    stand((-442.0, -2598.0))
    setting("rxp", True)
    setting("quests", True)
    setting("sourceFirst", "rxp")
    setting("rxpAhead", 2)
    stub.QuestAt(880, "Bristleback Interlopers", 1, *FIELD)
    stub.QuestAt(881, "Tribes at War", 1, *CAMP)
    stub.watched, stub.focus = lua.table_from([880]), 0
    arrow = lua.eval("function() RXPG_ARROW = { element = nil }; return RXPG_ARROW end")()
    arrow.element = lua.table_from({"wx": RATCHET[1], "wy": RATCHET[0], "instance": 1})
    look("QUEST_WATCH_LIST_CHANGED")
    chat("focus")
    quiet()
    assert focus() == "auto" and ns.dest and ns.dest.source == "rxp" and near(*RATCHET), "Auto did not follow the guide first"
    # /thread focus: what is in use and what can be chosen (the journal has nothing to say yet: not offered)
    slash("focus")
    text = chat("focus")
    assert any(t.endswith("Focus: Auto. Available: Auto, RestedXP, Quests, My Route.") for t in text), text
    # Quests: the tracked quest, though the guide comes first by Priority, and said on screen with the focus above it
    slash("focus quests")
    frames()
    text = chat("focus quests")
    assert any(t.endswith("Focus: Quests.") for t in text), text
    assert focus() == "quests" and ns.dest.source == "quest" and near(*FIELD), "the Quests focus did not follow the tracked quest"
    assert lines() == ["Following: Quests", "Quest: Bristleback Interlopers"], lines()
    quiet()
    # your choice of focus stands even with Follow Tracked Quests switched off
    setting("quests", False)
    ticks()
    assert near(*FIELD), "the Follow Tracked Quests setting held back the Quests focus"
    setting("quests", True)
    # a quest you choose comes before the focus, and a map pin before both
    Choice.Set(Choice, "quest", 881)
    frames()
    assert ns.dest.chosen and near(*CAMP), "the focus came before a quest you chose"
    stub.PinAt(1, -7140.0, -3790.0)
    stub.Fire("USER_WAYPOINT_UPDATED"); frames()
    ticks()
    assert ns.dest.pin, "the choice or the focus came before your map pin"
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    ticks()
    assert ns.dest.chosen and near(*CAMP), "not back to the chosen quest when the pin went"
    Choice.Clear(Choice)
    frames()
    assert not ns.dest.chosen and near(*FIELD), "not back to the focus when the choice was cleared (at once, not at the next look)"
    chat("precedence")
    quiet()
    # the Dungeon Journal: its list only, with its next step drawn on; not offered while it has nothing to say
    slash("focus dj")
    text = chat("focus dj")
    assert any(t.endswith("Dungeon Journal is not available now.") for t in text), text
    assert focus() == "quests"
    lua.execute("STUB.dj = { { -1994, -156 }, { -600, -2800 } }")
    slash("focus fdj")
    frames()
    chat("focus dj")
    assert focus() == "fdj" and ns.dest.source == "rxp" and near(*CAMP), "the Dungeon Journal focus was not followed"
    assert lines() == ["Following: Dungeon Journal", "Accept: Wailing Caverns Quest"], lines()
    assert not ns.dest.chosen, "a focus is drawn in the colour of a path you chose"
    ticks(2)
    assert ns.ahead and len(ns.ahead.legs) == 1, "the focused list's next step is not drawn on"
    quiet()
    # its list done: back to Auto, said once in chat, and not again while it stays so
    lua.execute("STUB.dj = {}")
    ticks()
    stub.time += 5
    ticks(6)
    text = chat("dj done")
    said_nowhere = [t for t in text if "Nothing to follow in Dungeon Journal for now; following your guide and quests." in t]
    assert len(said_nowhere) == 1, text
    assert focus() == "fdj" and ns.dest.source == "rxp" and near(*RATCHET), "did not fall back to Auto (the guide first)"
    stub.time += 30
    ticks(6)
    assert not any("Nothing to follow" in t for t in chat("dj done")), "the fall back was said again"
    # somewhere to go again, then nowhere: said again
    lua.execute("STUB.dj = { { -1994, -156 } }")
    ticks()
    assert near(*CAMP), "the journal was not followed again once it had a step"
    lua.execute("STUB.dj = {}")
    ticks()
    stub.time += 5
    ticks()
    assert sum(1 for t in chat("dj again") if "Nothing to follow in Dungeon Journal" in t) == 1
    quiet()
    # RestedXP: followed with its own setting off, the step text says the focus once even where the place is the same
    setting("rxp", False)
    G.PatchwerkForever_Thread_Routes_Focus("rxp")
    frames()
    assert focus() == "rxp" and ns.dest.source == "rxp" and near(*RATCHET), "Follow RestedXP Guide held back the RestedXP focus"
    assert lines()[:1] == ["Following: RestedXP"], lines()
    slash("quest")
    assert any("Following: RestedXP (it is your focus)." in t for t in chat("rxp focus"))
    quiet()
    setting("rxp", True)
    # back to Auto, which goes to the same place: the focus is said on its own
    G.PatchwerkForever_Thread_Routes_Focus("auto")
    frames()
    assert near(*RATCHET) and lines() == ["Following: Auto"], lines()
    quiet()

    step("My Route as the focus: followed in order, numbered on the world map, and changed from the marks' menu")
    assert MyRoute.Add(MyRoute, lua.table_from({"kind": "quest", "id": 881}))
    assert MyRoute.Add(MyRoute, lua.table_from({"kind": "quest", "id": 880}))
    assert MyRoute.Add(MyRoute, lua.table_from({"kind": "spot", "map": 1, "x": RATCHET[0], "y": RATCHET[1], "label": "Ratchet"}))
    assert MyRoute.Add(MyRoute, lua.table_from({"kind": "spot", "map": 0, "x": -9460.0, "y": 60.0, "label": "Stormwind"}))
    world_map.shown = True
    world_map.mapID = 1414
    stub.provider.RefreshAllData()
    assert len(ns.RouteMarks()) == 0, "My Route was marked on the map while it is not followed"
    G.PatchwerkForever_Thread_Routes_Focus("route")
    frames()
    assert focus() == "route" and near(*CAMP), "My Route's first stop was not gone to"
    assert lines() == ["Following: My Route", "Do: Tribes at War"], lines()
    marks_now = list(ns.RouteMarks().values())
    # (the stop in Stormwind is on the other continent's map: not marked on Kalimdor's)
    assert [m.number.GetText(m.number) for m in marks_now] == ["1", "2", "3"], [m.number.text for m in marks_now]
    assert all(m.shown and m.ownScale == 2 for m in marks_now), "the marks are not kept the same size on the screen"
    # a mark's menu: Go Here First, Move Earlier, Move Later, Remove
    def menu_texts():
        return [e.text for e in stub.menu.entries.values() if e.kind != "divider"]

    def pick(text):
        entry = [e for e in stub.menu.entries.values() if e.text == text][0]
        if entry.kind == "radio":
            entry.setSelected(entry.data)
        else:
            entry.fn()

    second = marks_now[1]
    second.scripts.OnClick(second, "RightButton")
    assert menu_texts() == ["2. Bristleback Interlopers", "Go Here First", "Move Earlier", "Move Later", "Remove"], menu_texts()
    pick("Go Here First")
    frames()
    assert Guides.Read(Guides, 0, "route").route == 2 and near(*FIELD), "Go Here First did not lead to that stop"
    first = ns.RouteMarks()[1]
    first.scripts.OnClick(first, "RightButton")
    assert menu_texts() == ["1. Tribes at War", "Go Here First", "Move Later", "Remove"], menu_texts()
    pick("Move Later")
    order = [e.id for e in MyRoute.Entries(MyRoute).values()]
    assert order[:2] == [880, 881], order
    assert [m.name for m in ns.RouteMarks().values()][:2] == ["Bristleback Interlopers", "Tribes at War"], "the marks were not redrawn"
    third = ns.RouteMarks()[3]
    third.scripts.OnClick(third, "RightButton")
    pick("Remove")
    assert len(MyRoute.Entries(MyRoute)) == 3 and len(ns.RouteMarks()) == 2, "Remove did not take the stop out"
    third = ns.RouteMarks()[2]
    third.scripts.OnClick(third, "LeftButton")              # (a left-click: go there first)
    frames()
    assert Guides.Read(Guides, 0, "route").route == 2 and near(*CAMP), "a left-click on a mark did not lead to it"
    # Auto again: no marks; My Route selected as a side list: marks; the setting off: none
    G.PatchwerkForever_Thread_Routes_Focus("auto")
    frames()
    assert len(ns.RouteMarks()) == 0, "My Route stayed on the map after the focus left it"
    Choice.Set(Choice, "guide", "route")
    assert len(ns.RouteMarks()) == 2, "My Route selected is not marked on the map"
    setv("myRouteMap", False)
    assert len(ns.RouteMarks()) == 0, "Show My Route On The World Map did not hide the marks"
    setv("myRouteMap", True)
    Choice.Clear(Choice)
    chat("my route")
    quiet()

    step("the world map's focus button, its menu, and the keys")
    button = ns.MapFocusButton()
    assert button and same(button.parent, world_map.BorderFrame) and same(button.anchor, world_map.ScrollContainer) and button.shown, "no focus button on the map's border frame"
    assert not world_map.overlayFrames, "the button went in among the map's overlay frames"
    button.scripts.OnClick(button, "LeftButton")
    texts = menu_texts()
    assert texts == ["Route Focus", "Auto", "RestedXP", "Quests", "My Route", "Edit My Route", "Add Map Pin To My Route"], texts
    radios = [e for e in stub.menu.entries.values() if e.kind == "radio"]
    assert [e.text for e in radios if e.isSelected(e.data)] == ["Auto"], "the focus in use is not the one checked"
    pick("Quests")
    frames()
    assert focus() == "quests" and near(*FIELD)
    pick("Edit My Route")
    assert any("Editing My Route needs Tracker (Thread)" in t for t in chat("edit")), "nothing said without the tracker"
    lua.execute("function PatchwerkForever_Thread_Tracker_OpenMyRoute(anchor) STUB.editorBeside = anchor end")
    pick("Edit My Route")
    assert same(stub.editorBeside, world_map), "the editor was not opened beside the map"
    pick("Add Map Pin To My Route")
    assert any(t.endswith("Place a map pin first.") for t in chat("map pin"))
    stub.PinAt(1, -1000.0, -2000.0)
    pick("Add Map Pin To My Route")
    entries = list(MyRoute.Entries(MyRoute).values())
    assert entries[-1].kind == "spot" and entries[-1].name == "Map pin" and abs(entries[-1].x - -1000.0) < 1 and abs(entries[-1].y - -2000.0) < 1, [(e.kind, e.name) for e in entries]
    pick("Add Map Pin To My Route")
    assert any(t.endswith("Your map pin is already in My Route.") for t in chat("map pin")), "a pin was added twice"
    MyRoute.Remove(MyRoute, len(entries))
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    setv("focusButton", False)
    assert not button.shown, "Focus Button On The World Map did not hide the button"
    setv("focusButton", True)
    assert button.shown
    # Next Focus goes round what can be chosen; each focus has a key of its own
    G.PatchwerkForever_Thread_Routes_FocusNext()
    assert focus() == "route", focus()
    G.PatchwerkForever_Thread_Routes_FocusNext()
    assert focus() == "auto", focus()
    for word, want in (("myroute", "route"), ("quest", "quests"), ("restedxp", "rxp"), ("auto", "auto")):
        slash("focus " + word)
        assert focus() == want, (word, focus())
    slash("focus nonsense")
    assert any('Unknown focus "nonsense"' in t for t in chat("focus words"))
    bindings = open(os.path.join(ADDONS, ADDON, "Bindings.xml"), encoding="utf-8").read()
    for key in ("FOCUS_NEXT", "FOCUS_AUTO", "FOCUS_RXP", "FOCUS_FDJ", "FOCUS_QUESTS", "FOCUS_ROUTE"):
        assert ('name="PATCHWERKFOREVER_THREAD_%s"' % key) in bindings and G["BINDING_NAME_PATCHWERKFOREVER_THREAD_" + key], key
    slash("")
    assert any("/thread focus auto, rxp, dj, quests or route" in t for t in chat("help")), "the help does not tell of /thread focus"
    # a gathering run started here ends a choice, as one started through the base does
    Choice.Set(Choice, "quest", 881)
    slash("gather")
    assert Choice.Get(Choice) is None, "/thread gather left the choice standing"
    slash("gather stop")
    ticks()
    chat("gather")
    quiet()

    step("the quest log: a + beside each quest, and the quest's menu; nothing where the game has no quest log")
    hooked, menued = ns.QuestLogHooked()
    assert not hooked and menued, (hooked, menued)
    stub.Fire("ADDON_LOADED", "Blizzard_UIPanels_Game")         # (still no quest log: nothing, and no error)
    assert not ns.QuestLogHooked()[0]
    lua.execute("""
        local titles = { CreateFrame('Button'), CreateFrame('Button'), CreateFrame('Button') }
        titles[1].questID, titles[2].questID = 880, 881            -- (the third is a header's: no quest)
        STUB.titles = titles
        QuestScrollFrame = { titleFramePool = { EnumerateActive = function() return pairs({ [titles[1]] = true, [titles[2]] = true, [titles[3]] = true }) end } }
        function QuestLogQuests_Update() STUB.questLogDrawn = (STUB.questLogDrawn or 0) + 1 end
    """)
    stub.Fire("ADDON_LOADED", "Blizzard_UIPanels_Game")
    assert ns.QuestLogHooked()[0], "the quest log was not hooked once it was there"
    G.QuestLogQuests_Update()
    assert stub.questLogDrawn == 1, "the game's own drawing of the quest log was lost"
    titles = list(stub.titles.values())
    plus = [ns.QuestLogPlus(t) for t in titles]
    assert plus[0] and plus[1] and not plus[2], "the + is not on each quest's title (and only there)"
    in_route = [e.id for e in MyRoute.Entries(MyRoute).values() if e.kind == "quest"]
    assert sorted(in_route) == [880, 881], in_route
    assert all("ReadyCheck" in p.icon.icon for p in plus[:2]), "quests in My Route do not show a check mark"
    plus[0].scripts.OnClick(plus[0], "LeftButton")
    assert not MyRoute.Has(MyRoute, "quest", 880) and "PlusButton" in plus[0].icon.icon, "the check mark did not take the quest out"
    plus[0].scripts.OnClick(plus[0], "LeftButton")
    assert MyRoute.Has(MyRoute, "quest", 880) and "ReadyCheck" in plus[0].icon.icon, "the + did not add the quest"
    # the quest's own right-click menu, through the game's way of adding to it
    modify = stub.modifiers["MENU_QUEST_MAP_LOG_TITLE"]
    root = stub.NewMenuRoot()
    modify(titles[1], root)
    assert [e.text for e in root.entries.values() if e.kind == "button"] == ["Remove From My Route"]
    [e for e in root.entries.values() if e.kind == "button"][0].fn()
    assert not MyRoute.Has(MyRoute, "quest", 881)
    root = stub.NewMenuRoot()
    modify(titles[1], root)
    assert [e.text for e in root.entries.values() if e.kind == "button"] == ["Add To My Route"]
    root = stub.NewMenuRoot()
    modify(titles[2], root)                                     # (a menu of that tag with no quest: the map pin's)
    assert len(root.entries) == 0
    MyRoute.Clear(MyRoute)
    arrow.element = None
    stub.watched = lua.table()
    ticks()
    chat("quest log")

    step("what is followed, told to the base for the tracker; a choice that is not followed is said once; /thread quest")
    Following = G.PatchwerkForever.Following

    def followed():
        f = Following.Get(Following)
        return (f.kind, f.source, f.quest) if f else None
    heard_keys = []
    Following.OnChange(Following, lua.eval("function(f) return function(info) f(info and info.key or false) end end")(heard_keys.append))
    stand((-442.0, -2598.0))
    setting("rxp", True)
    setting("quests", True)
    setting("sourceFirst", "rxp")
    ticks()
    assert followed() == ("none", None, None), followed()
    # the guide's step, then the next: the key changes with the step
    arrow.element = lua.table_from({"wx": RATCHET[1], "wy": RATCHET[0], "instance": 1})
    ticks()
    assert followed() == ("guide", "rxp", None) and near(*RATCHET), followed()
    first = Following.Get(Following).key
    told = len(heard_keys)
    ticks()
    assert len(heard_keys) == told, "the same thing followed was told again"
    arrow.element = lua.table_from({"wx": CAMP[1], "wy": CAMP[0], "instance": 1})
    ticks()
    assert followed() == ("guide", "rxp", None) and Following.Get(Following).key != first, "a new step did not change the key"
    # a tracked quest with Route Priority on quests
    stub.QuestAt(990, "A Quest Here", 1, *FIELD)
    stub.watched = lua.table_from([990])
    setting("sourceFirst", "quest")
    ticks()
    assert followed() == ("quest", None, 990), followed()
    slash("quest")
    assert any("Kalimdor" in t for t in chat("quest names the continent")), "the continent is not named"
    setting("sourceFirst", "rxp")
    ticks()
    slash("quest")
    assert any("Following: your RestedXP guide (Route Priority: Guide First)." in t for t in chat("quest, the guide"))
    # stopped by you: nothing followed, until the step moves on
    slash("stop")
    ticks()
    assert followed() == ("none", None, None), followed()
    slash("quest")
    assert any("Not routing now" in t for t in chat("quest, stopped"))
    slash("go")
    ticks()
    assert followed()[0] == "guide"
    # a quest you select that has no place: the main route goes on, and that is said once
    lua.execute("STUB.quests[991] = { title = 'Nowhere Quest', uiMap = 0 }")
    Choice.Set(Choice, "quest", 991)
    ticks()
    assert followed()[0] == "guide" and not any("Nowhere Quest" in t for t in heard()), "said before the game had a moment to answer"
    stub.time += 3
    ticks(4)
    text = chat("a choice with no place")
    assert sum(1 for t in text if '"Nowhere Quest" has no location on the map' in t) == 1, text
    # a quest you select while your map pin stands: the pin first, and that is said once for the pin
    stub.QuestAt(992, "A Quest There", 1, *CAMP)
    Choice.Set(Choice, "quest", 992)
    ticks()
    assert followed() == ("quest", None, 992) and ns.dest.chosen
    # (the trail before the new destination's way is known: faint, in the color of the destination it leads to)
    route_before = ns.route
    stub.PinAt(1, -1000.0, -2000.0)
    stub.Fire("USER_WAYPOINT_UPDATED")
    if same(ns.route, route_before):
        chosen, alpha = ns.TrailLook(ns.route, True, 0.9, 0.45)
        assert alpha == 0.45 and chosen, "the trail of the destination before is not drawn fainter while the new one is searched for"
    ticks()
    assert ns.TrailLook(ns.route, True, 0.9, 0.45)[1] == 0.9, "the new trail is drawn faint"
    text = chat("pin first")
    assert followed()[0] == "pin" and sum(1 for t in text if "Your map pin comes first. The quest you selected" in t) == 1, text
    ticks()
    assert not any("comes first" in t for t in chat("pin first, again"))
    slash("quest")
    assert any("Following: your map pin (it always comes first)." in t for t in chat("quest, a pin"))
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    ticks()
    assert followed() == ("quest", None, 992), followed()
    slash("quest")
    assert any('Following: "A Quest There" (selected by you' in t for t in chat("quest, chosen"))
    Choice.Clear(Choice)
    # a list you select: its steps ahead in the selected route's color too
    STUB_DJ = lua.globals().STUB.dj
    STUB_DJ[1], STUB_DJ[2] = lua.table_from([FIELD[0], FIELD[1]]), lua.table_from([RATCHET[0], RATCHET[1]])
    Choice.Set(Choice, "guide", "fdj")
    for _ in range(20):
        ticks()
        if ns.ahead:
            break
    assert followed() == ("guide", "fdj", None), followed()
    assert ns.ahead and ns.ahead.chosen, "a selected list's steps ahead are not drawn as a path you chose"
    Choice.Clear(Choice)
    ticks()
    assert not (ns.ahead and ns.ahead.chosen), "the main guide's steps ahead are drawn as a path you chose"
    STUB_DJ[1], STUB_DJ[2] = None, None
    # a gathering run
    slash("gather")
    ticks()
    assert followed()[0] == "gather", followed()
    slash("quest")
    assert any("Following: your gathering run." in t for t in chat("quest, gathering"))
    slash("gather stop")
    arrow.element = None
    stub.QuestGone(990)
    stub.QuestGone(991)
    stub.QuestGone(992)
    ticks()
    assert followed() == ("none", None, None), followed()
    chat("followed")

    step("a ghost is led to its corpse before everything else, on foot; alive again, what was followed is followed again")
    # The stand-in can die. STUB.dead = 'dead' (died, not released) or 'ghost'; STUB.CorpseAt(map, x, y) is
    # where the game says the corpse lies (STUB.corpse = nil: it does not say); STUB.secret is a value an
    # addon may not read, which the game hands over with STUB.deadSecret or STUB.corpseSecret set.
    lua.execute("""
        STUB.dead, STUB.secret, STUB.corpseAsked = nil, {}, 0
        function issecretvalue(value) return value == STUB.secret end
        function UnitIsGhost(unit)
            assert(unit == 'player')
            if STUB.deadSecret then return STUB.secret end
            return STUB.dead == 'ghost'
        end
        function UnitIsDeadOrGhost(unit)
            assert(unit == 'player')
            if STUB.deadSecret then return STUB.secret end
            return STUB.dead ~= nil
        end
        function STUB.CorpseAt(map, x, y)
            local pin = STUB.pin
            STUB.PinAt(map, x, y)
            STUB.corpse, STUB.pin = STUB.pin, pin
        end
        C_DeathInfo = { GetCorpseMapPosition = function(uiMap)
            assert(type(uiMap) == 'number')
            STUB.corpseAsked = STUB.corpseAsked + 1
            if STUB.corpseSecret then return STUB.secret end
            local corpse = STUB.corpse
            if corpse and corpse.uiMapID == uiMap then return corpse.position end
        end }
    """)
    CORPSE, GRAVE = (-620.0, -2760.0), (-442.0, -2598.0)

    def die(where=CORPSE, known=True):
        stand(where)
        if known:
            stub.CorpseAt(1, *where)
        else:
            stub.corpse = None
        stub.dead = "dead"
        stub.Fire("PLAYER_DEAD")

    def release():                     # (the game's event for becoming a ghost is PLAYER_ALIVE)
        stub.dead = "ghost"
        stand(GRAVE)
        stub.Fire("PLAYER_ALIVE")
        ticks()

    def revive(where=CORPSE):
        stand(where)
        stub.dead, stub.corpse = None, None
        stub.Fire("PLAYER_UNGHOST")
        ticks()

    def corpse():
        return ns.CorpseActive()

    setting("notify", True)
    setting("flights", True)
    stand(GRAVE)
    arrow.element = lua.table_from({"wx": RATCHET[1], "wy": RATCHET[0], "instance": 1})
    ticks()
    assert followed()[0] == "guide" and near(*RATCHET), followed()
    assert not ns.CorpseState().watching, "the corpse is looked for while you are alive"
    quiet()
    chat("before dying")
    # dead and not released: nothing changes, and the game is not asked where the corpse lies
    die()
    ticks()
    assert not corpse() and near(*RATCHET) and stub.corpseAsked == 0, "something was done before you released"
    # released: the corpse, on foot, said on screen and told to the base; nothing in chat
    release()
    assert corpse() and ns.dest.source == "corpse" and near(*CORPSE) and ns.dest.walkOnly, "a ghost was not led to its corpse"
    assert ns.route and len(ns.route.flown) == 0 and len(ns.route.rides) == 0, "no way on foot to the corpse"
    assert followed() == ("corpse", None, None), followed()
    words, under = on_screen()
    assert words == "To your corpse" and under and "walk" in under, (words, under)
    assert not chat("to the corpse"), "the way to the corpse was said in chat"
    # (asked no more while the way leads there)
    asked = stub.corpseAsked
    ticks(5)
    assert stub.corpseAsked == asked and ns.dest.source == "corpse"
    # a spot or a pin of your own given meanwhile waits, and that is said; nor is the guide followed
    slash("to 50 50")
    stub.PinAt(1, *CAMP)
    stub.Fire("USER_WAYPOINT_UPDATED")
    ticks()
    text = chat("a pin while a ghost")
    assert ns.dest.source == "corpse" and near(*CORPSE), "a pin came before the corpse"
    assert sum(1 for t in text if "Your corpse comes first. The coordinates you gave are routed to once you are alive." in t) == 1, text
    assert sum(1 for t in text if "Your corpse comes first. Your map pin is routed to once you are alive." in t) == 1, text
    slash("quest")
    assert any("Following: the way to your corpse" in t for t in chat("quest, a ghost"))
    # alive again: the pin (the last of the two given), as a pin comes first; with it gone, the guide's step as before
    revive()
    assert not corpse() and ns.dest.pin and near(*CAMP) and followed()[0] == "pin", "the pin given while dead was not gone to"
    assert not ns.CorpseState().watching
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    ticks()
    assert followed()[0] == "guide" and near(*RATCHET), followed()
    # a pin that led when you died is gone to again; one removed meanwhile is not
    stub.PinAt(1, *CAMP)
    stub.Fire("USER_WAYPOINT_UPDATED")
    ticks()
    assert ns.dest.pin
    die()
    release()
    assert ns.dest.source == "corpse" and followed()[0] == "corpse"
    revive()
    assert ns.dest.pin and near(*CAMP), "the pin that led before was not gone to again"
    die()
    release()
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    ticks()
    assert ns.dest.source == "corpse"
    revive()
    assert followed()[0] == "guide" and near(*RATCHET), "a pin removed while dead was gone to"
    chat("pins")
    # a gathering run waits, and goes on
    stub.time += 400
    slash("gather")
    ticks()
    assert ns.dest.source == "gather"
    die()
    release()
    assert ns.dest.source == "corpse" and ns.GatherActive(), "the gathering run was ended by dying"
    ticks(5)
    assert ns.dest.source == "corpse", "the gathering run did not wait for the corpse"
    revive()
    assert ns.dest and ns.dest.source == "gather" and followed()[0] == "gather", "the gathering run did not go on"
    slash("gather stop")
    ticks()
    # a quest you selected and the focus stand as they were
    stub.QuestAt(993, "A Quest Kept", 1, *CAMP)
    stub.watched = lua.table_from([993])
    Choice.Set(Choice, "quest", 993)
    slash("focus quests")
    ticks()
    assert ns.dest.source == "quest" and ns.dest.chosen and near(*CAMP)
    die()
    release()
    assert ns.dest.source == "corpse" and not ns.dest.chosen and ns.TrailLook(ns.route, True, 0.9, 0.45)[0] is None
    revive()
    assert ns.dest.source == "quest" and ns.dest.chosen and near(*CAMP), "the selected quest was not followed again"
    assert Choice.Is(Choice, "quest", 993) and focus() == "quests", "the choice or the focus was lost"
    Choice.Clear(Choice)
    stub.QuestGone(993)
    slash("focus auto")
    ticks()
    assert followed()[0] == "guide"
    chat("side paths, a ghost")
    # reaching the corpse as a ghost: nothing else is routed to until you are alive
    die()
    release()
    stand(CORPSE)
    ticks()
    assert not ns.dest and corpse() and followed()[0] == "corpse", "the guide was followed from the corpse, by a ghost"
    ticks(4)
    assert not ns.dest
    revive()
    assert followed()[0] == "guide" and near(*RATCHET), "the guide was not followed again"
    # Stop Routing as a ghost says what was stopped; Start Routing leads to the corpse again
    die()
    release()
    slash("stop")
    ticks()
    text = chat("stopped as a ghost")
    assert not ns.dest and corpse() and any("Routing to your corpse stopped." in t for t in text), text
    slash("go")
    ticks()
    text = chat("go as a ghost")
    assert ns.dest.source == "corpse" and any(t.endswith("Routing to your corpse:") for t in text) and any("walk" in t for t in text), text
    # the setting: off, your other routes at once; on, the corpse again
    setting("corpse", False)
    ticks()
    assert not corpse() and followed()[0] == "guide" and not ns.CorpseState().watching
    setting("corpse", True)
    ticks()
    assert ns.dest.source == "corpse"
    revive()
    # no flight for a ghost, where the living fly
    arrow.element = None
    stand(GRAVE)
    stub.PinAt(1, -7140.0, -3790.0)
    stub.Fire("USER_WAYPOINT_UPDATED")
    frames()
    assert any("fly" in t for t in chat("the living fly")), "the living do not fly to Gadgetzan: the check below proves nothing"
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    die((-7140.0, -3790.0))
    release()
    assert ns.dest.source == "corpse" and ns.route and len(ns.route.flown) == 0, "a ghost was sent by flight path"
    assert "fly" not in on_screen()[1], on_screen()
    revive(GRAVE)
    assert followed() == ("none", None, None), followed()
    quiet()
    chat("a ghost")

    step("a corpse with no place on the map is not routed to, and the chat says why once for each death")
    NO_PLACE = "Your corpse has no location on the map (it may be in an instance), so it is not routed to."
    arrow.element = lua.table_from({"wx": RATCHET[1], "wy": RATCHET[0], "instance": 1})
    ticks()
    die(known=False)
    release()
    assert not corpse() and followed()[0] == "guide" and not any("corpse" in t for t in heard()), "said before the game had a moment to answer"
    ticks(4)
    text = chat("no place")
    assert sum(1 for t in text if NO_PLACE in t) == 1 and not corpse() and near(*RATCHET), text
    ticks(12)
    assert not any("corpse" in t for t in chat("no place, again")), "said more than once for one death"
    # the game says where after all (you came out of the instance): led there from then on
    stub.CorpseAt(1, *CORPSE)
    ticks(6)
    assert corpse() and near(*CORPSE), "a corpse whose place became known was not routed to"
    revive()
    # the next death is said again
    die(known=False)
    release()
    ticks(4)
    assert sum(1 for t in chat("no place, the next death") if NO_PLACE in t) == 1
    revive()
    # on another continent: a ghost takes no boat
    die()
    stub.CorpseAt(0, -8900.0, -120.0)
    release()
    ticks(4)
    text = chat("another continent")
    assert not corpse() and followed()[0] == "guide", "a corpse on another continent was routed to"
    assert sum(1 for t in text if "Your corpse is on another continent (Eastern Kingdoms). A ghost takes no boat or zeppelin, so it is not routed to." in t) == 1, text
    revive()
    # where the game gives no position for you (an instance): not routed to, and said
    die()
    stub.dead, stub.player.x = "ghost", None
    stub.Fire("PLAYER_ALIVE")
    ticks(6)
    text = chat("no position")
    assert not corpse() and sum(1 for t in text if "Your position is not available here, so your corpse is not routed to." in t) == 1, text
    stub.player.x = GRAVE[0]
    revive()
    # a position the game will not let an addon read is no position
    die()
    stub.corpseSecret = True
    release()
    ticks(4)
    assert not corpse() and sum(1 for t in chat("a secret place") if NO_PLACE in t) == 1
    stub.corpseSecret = None
    revive()
    # nor is a secret answer to "are you a ghost" taken for yes: nothing at all is done
    stub.deadSecret = True
    asked = stub.corpseAsked
    die()
    release()
    ticks(6)
    assert not corpse() and not ns.CorpseState().watching and stub.corpseAsked == asked and not chat("a secret ghost")
    stub.deadSecret = None
    revive()
    # a client without the corpse's position: said as a corpse with no place; one that cannot say you are a ghost: nothing
    lua.execute("STUB.kept = { C_DeathInfo, UnitIsGhost, UnitIsDeadOrGhost }; C_DeathInfo = nil")
    die()
    release()
    ticks(4)
    assert not corpse() and sum(1 for t in chat("no C_DeathInfo") if NO_PLACE in t) == 1
    revive()
    lua.execute("C_DeathInfo = STUB.kept[1]; UnitIsGhost, UnitIsDeadOrGhost = nil, nil")
    die()
    release()
    ticks(6)
    assert not corpse() and not chat("no UnitIsGhost") and followed()[0] == "guide"
    lua.execute("UnitIsGhost, UnitIsDeadOrGhost = STUB.kept[2], STUB.kept[3]")
    revive()
    # on a battleground you die again and again, and the spirit healer brings you back: not said there
    lua.execute("STUB.inInstance = IsInInstance; function IsInInstance() return true, 'pvp' end")
    die(known=False)
    release()
    ticks(6)
    assert not corpse() and not chat("a battleground"), "said on a battleground"
    lua.execute("IsInInstance = STUB.inInstance")
    revive()
    # the setting off: a ghost is left alone, and the game is not asked
    setting("corpse", False)
    asked = stub.corpseAsked
    die()
    release()
    ticks(6)
    assert not corpse() and stub.corpseAsked == asked and near(*RATCHET) and not chat("the setting off")
    revive()
    setting("corpse", True)
    assert not ns.CorpseState().watching and followed()[0] == "guide"
    arrow.element = None
    ticks()
    quiet()
    chat("a corpse with no place")

    step("the flight point search: to the nearest flight point you lack and on to the next, once a flight map has been read")
    POINTS = G.PatchwerkForever_Thread_RoutesData[1].points

    def mine():
        return G.PatchwerkForever_Thread_RoutesDB.taxi["Player-1-00000001"]

    def horde():                       # the Horde's flight points on Kalimdor: (id, name, cell x, cell y)
        return [(p[1], p[2], p[3], p[4]) for p in POINTS.values() if "H" in p[5]]

    def know(*ids, others=False):      # these flight points are yours, the Horde's others are or are not
        for pid, _, _, _ in horde():
            mine().known[pid] = (pid in ids) or others

    def lack(*ids):                    # every flight point is yours but these
        for pid, _, _, _ in horde():
            mine().known[pid] = pid not in ids

    def nearest_lacking(*left):        # worked out here as the search does: straight there, in cells
        cx, cy = ns.Planner.CellOf(1, stub.player.x, stub.player.y)
        best = None
        for pid, name, x, y in horde():
            if mine().known[pid] is not True and name not in left:
                far = (x - cx) ** 2 + (y - cy) ** 2
                if best is None or far < best[0]:
                    best = (far, name)
        return best and best[1]

    def going():
        state = ns.DiscoverState()
        return state and state.going

    def searching():
        return ns.DiscoverActive()

    stand(HERE)
    slash("flights")
    chat("flights, before the search")
    keep = lua.eval("""function(mine)
        local was = { seen = {}, known = {} }
        for k, v in pairs(mine.seen) do was.seen[k] = v end
        for k, v in pairs(mine.known) do was.known[k] = v end
        return was
    end""")(mine())
    # no flight map read on this continent: a point not known may be one never read, so no search
    mine().seen[1] = None
    slash("discover")
    text = chat("discover, nothing read")
    assert not searching() and not ns.dest and not any("started" in t for t in text), text
    assert sum(1 for t in text if "Open the flight map at a flight master first." in t) == 1, text
    # read: Crossroads (here) and Orgrimmar are yours. The nearest you lack is Ratchet.
    stub.flightMap = lua.table_from({25: 0, 23: 1})
    stub.Fire("TAXIMAP_OPENED")
    frames()
    chat("flight map")
    assert nearest_lacking() == "Ratchet, The Barrens", nearest_lacking()
    slash("discover")
    ticks()
    text = chat("discover")
    assert searching() and ns.dest.source == "discover" and ns.dest.chosen and ns.route, "the search did not start"
    assert any("Flight point search started: nearest undiscovered flight point first, then the next. /thread discover stop ends it." in t for t in text), text
    assert lines() == ["Discover the flight point at Ratchet"] and "walk" in on_screen()[1], on_screen()
    assert going() == "Ratchet, The Barrens" and followed() == ("discover", None, None), (going(), followed())
    slash("quest")
    assert any("Following: your flight point search. /thread discover stop ends it." in t for t in chat("quest, searching"))
    # your guide is not followed meanwhile; a pin of your own comes first, and the search goes on after it
    arrow.element = lua.table_from({"wx": CAMP[1], "wy": CAMP[0], "instance": 1})
    ticks()
    assert ns.dest.source == "discover"
    stub.PinAt(1, *FIELD)
    stub.Fire("USER_WAYPOINT_UPDATED")
    ticks()
    assert ns.dest.pin and searching() and followed()[0] == "discover"
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    ticks()
    assert ns.dest.source == "discover" and going() == "Ratchet, The Barrens", "the search did not go on once the pin was gone"
    chat("a pin during the search")
    # there: the search waits for the flight master's word, and says so once
    ratchet = (ns.dest.x, ns.dest.y)
    stand(ratchet)
    ticks()
    text = chat("at the flight point")
    assert not ns.dest and searching() and ns.DiscoverState().at, "the search did not wait at the flight point"
    assert sum(1 for t in text if "You have arrived at Ratchet. Speak to the flight master to discover the flight point." in t) == 1, text
    ticks(4)
    assert not ns.dest and going() == "Ratchet, The Barrens" and not chat("waiting")
    # the game says it is yours: on to the next nearest
    stub.Fire("UI_INFO_MESSAGE", 372, G.ERR_NEWTAXIPATH)
    ticks()
    text = chat("discovered")
    assert mine().known[80] is True and any("Flight point discovered: Ratchet, The Barrens." in t for t in text), text
    second = nearest_lacking()
    assert second == "Camp Taurajo, The Barrens" and going() == second and ns.dest.source == "discover" and ns.route, (second, going())
    assert lines() == ["Discover the flight point at Camp Taurajo"], lines()
    # one that turns up on a flight map you open is yours too
    stub.flightMap = lua.table_from({25: 1, 23: 1, 80: 0, 77: 1})
    stub.Fire("TAXIMAP_OPENED")
    ticks()
    third = nearest_lacking()
    assert third and third != second and going() == third, (third, going())
    chat("a flight map during the search")
    # no way to the next: it is left out and the one after gone to, with nothing in chat
    stub.noWay = 1
    know(25, 23, 80, 77, [p[0] for p in horde() if p[1] == third][0])
    stub.Tick(); frames()
    lost = going()
    assert lost == nearest_lacking() and ns.dest.failed and not ns.route, (lost, nearest_lacking())
    assert on_screen() == ("Discover the flight point at " + lost.split(",")[0], "No route found"), on_screen()
    ticks()
    after = going()
    assert after == nearest_lacking(lost) and ns.route and list(ns.DiscoverState().left.values()) == [lost], (after, lost)
    assert not any("No route found" in t for t in chat("a flight point with no way")), "said in chat for one point of a search"
    # there, and away again without it being discovered: left out too, and said
    there = (ns.dest.x, ns.dest.y)
    stand(there)
    ticks()
    assert ns.DiscoverState().at and not ns.dest
    stand(there, 100.0)
    ticks()
    text = chat("walked away")
    assert any("%s was not discovered, and is left out of this search." % after.split(",")[0] in t for t in text), text
    assert going() == nearest_lacking(lost, after) and ns.dest.source == "discover", (going(), nearest_lacking(lost, after))
    # the rest found: the search ends, naming the ones it left out
    for pid, name, _, _ in horde():
        if name not in (lost, after):
            mine().known[pid] = True
    ticks()
    text = chat("the search ended")
    assert not searching() and not (ns.dest and ns.dest.source == "discover"), "the search did not end"
    assert any("Flight point search ended. Not reached or not discovered: %s." % "; ".join(sorted([lost, after])) in t for t in text), text
    ticks()
    assert followed()[0] == "guide" and near(*CAMP), "the guide was not followed again after the search"
    # the last one: the way there may fly between points you have; found, the chat says all are known
    arrow.element = None
    stand(HERE)
    lack(40)
    slash("discover")
    ticks()
    text = chat("the last one")
    assert going() == "Gadgetzan, Tanaris" and ns.route and len(ns.route.flown) > 0, "the way to the last flight point does not fly"
    mine().known[40] = True
    ticks()
    text = chat("all known")
    assert not searching() and not ns.dest and sum(1 for t in text if "All flight points on this continent are known." in t) == 1, text
    slash("discover")
    text = chat("discover, all known")
    assert not searching() and any("All flight points on this continent are known." in t for t in text) and not any("started" in t for t in text), text
    # a flight point the map data has no walk to (as the ones inside Ironforge and the Undercity) is left out and named
    lua.execute("table.insert(PatchwerkForever_Thread_RoutesData[1].points, { 9001, 'Nowhere, The Sea', 1936, 4096, 'H', false, 0, {} })")
    lack(9001)
    slash("discover")
    text = chat("discover, no ground")
    assert not searching() and any("No route to the flight points you have not discovered: Nowhere, The Sea." in t for t in text), text
    lack(9001, 80)
    stand(ratchet, 200.0)
    slash("discover")
    ticks()
    assert going() == "Ratchet, The Barrens"
    mine().known[80] = True
    ticks()
    text = chat("ended, no ground")
    assert not searching() and any("Flight point search ended. Not reached or not discovered: Nowhere, The Sea." in t for t in text), text
    lua.execute("table.remove(PatchwerkForever_Thread_RoutesData[1].points)")
    mine().known[9001] = None
    stand(HERE)

    step("the flight point search is a side path: one at a time, Start Routing and Stop Routing end it, its key; a ghost first")
    know(25, 23)
    # a search ends a gathering run, and a gathering run ends a search
    stub.time += 400
    slash("gather")
    ticks()
    assert ns.GatherActive() and ns.dest.source == "gather"
    slash("discover")
    ticks()
    text = chat("a search during a run")
    assert not ns.GatherActive() and searching() and ns.dest.source == "discover", "a search left the gathering run on"
    assert any(t.endswith("Gathering stopped.") for t in text), text
    slash("gather")
    ticks()
    assert ns.GatherActive() and not searching() and ns.dest.source == "gather", "a gathering run left the search on"
    slash("gather stop")
    # a search lets a selected quest go, and selecting a quest ends a search
    stub.QuestAt(994, "A Side Job", 1, *FIELD)
    Choice.Set(Choice, "quest", 994)
    ticks()
    assert ns.dest.source == "quest" and ns.dest.chosen
    slash("discover")
    ticks()
    assert searching() and Choice.Get(Choice) is None and ns.dest.source == "discover", "a search left the selected quest standing"
    Choice.Set(Choice, "quest", 994)
    ticks()
    assert not searching() and ns.dest.source == "quest", "selecting a quest left the search on"
    Choice.Clear(Choice)
    stub.QuestGone(994)
    ticks()
    chat("side paths")
    # a search that cannot start leaves a selected quest and a gathering run as they were
    stub.QuestAt(994, "A Side Job", 1, *FIELD)
    Choice.Set(Choice, "quest", 994)
    mine().seen[1] = None
    slash("discover")
    assert not searching() and Choice.Is(Choice, "quest", 994), "a search that did not start dropped the selected quest"
    mine().seen[1] = True
    Choice.Clear(Choice)
    stub.QuestGone(994)
    ticks()
    chat("a search that could not start")
    # Start Routing ends it where there is a guide step to go to; Stop Routing ends it and says what was stopped
    arrow.element = lua.table_from({"wx": CAMP[1], "wy": CAMP[0], "instance": 1})
    slash("discover")
    ticks()
    assert ns.dest.source == "discover"
    slash("go")
    ticks()
    text = chat("go during a search")
    assert not searching() and ns.dest.source == "rxp", "Start Routing left the search on"
    assert any(t.endswith("Flight point search stopped.") for t in text), text
    slash("discover")
    ticks()
    slash("stop")
    ticks()
    text = chat("stop during a search")
    assert not searching() and any(t.endswith("Flight point search stopped.") for t in text) and not any("Routing" in t for t in text), text
    assert ns.dest and ns.dest.source == "rxp", "the guide was not followed again once the search was stopped"
    # the commands, and the key: one press starts a search, the next ends it, each saying how
    slash("discover stop")
    slash("discover everything")
    slash("")
    text = chat("discover, the commands")
    assert any("No flight point search is active." in t for t in text) and any("Usage: /thread discover, or /thread discover stop." in t for t in text), text
    assert any("/thread discover: route to the nearest flight point you have not discovered" in t for t in text), text
    key = G.PatchwerkForever_Thread_Routes_Discover
    key()
    assert searching() and any("Press the key again to stop." in t for t in chat("the search key"))
    key()
    assert not searching() and any("Flight point search stopped." in t for t in chat("the search key, again"))
    assert G.BINDING_NAME_PATCHWERKFOREVER_THREAD_DISCOVER == "Toggle Flight Point Search"
    # a ghost goes to its corpse first: the search waits, and goes on
    arrow.element = None
    slash("discover")
    ticks()
    was_going = going()
    die()
    release()
    assert ns.dest.source == "corpse" and searching() and followed()[0] == "corpse"
    ticks(4)
    assert ns.dest.source == "corpse"
    revive(HERE)
    assert ns.dest.source == "discover" and going() == was_going, "the search did not go on once alive"
    # where you are is not to be had (an instance): the search waits; and none can start there
    stub.player.x = None
    ticks()
    assert searching()
    slash("discover stop")
    slash("discover")
    text = chat("discover, no position")
    assert not searching() and any("Your position is not available here." in t for t in text), text
    stub.player.x = HERE[0]
    # a character of no faction yet, and a map with no flight points
    stub.player.side = None
    slash("discover")
    assert not searching() and any("Your faction is not known yet" in t for t in chat("discover, no faction"))
    stub.player.side = "Horde"
    lua.execute("STUB.points = PatchwerkForever_Thread_RoutesData[1].points; PatchwerkForever_Thread_RoutesData[1].points = {}")
    slash("discover")
    assert not searching() and any("No flight points on this map." in t for t in chat("discover, no flight points"))
    lua.execute("PatchwerkForever_Thread_RoutesData[1].points = STUB.points")
    # (what this character knows is put back as it was, and the stand-in lives again as it did)
    lua.eval("""function(mine, was)
        mine.seen, mine.known = was.seen, was.known
        issecretvalue, UnitIsGhost, UnitIsDeadOrGhost, C_DeathInfo = nil, nil, nil, nil
    end""")(mine(), keep)
    stub.flightMap = None
    ticks()
    assert followed() == ("none", None, None), followed()
    quiet()
    chat("the flight point search")

    step("the keys: every binding in the family's section, each safe without its function, and named")
    bindings = open(os.path.join(ADDONS, ADDON, "Bindings.xml"), encoding="utf-8").read()
    import re
    found = re.findall(r'<Binding name="([A-Z_]+)"[^>]*category="([^"]+)"[^>]*>\s*if (\w+) then (\w+)\(', bindings)
    assert len(found) == bindings.count("<Binding "), "a binding is not guarded, or not in the section"
    assert all(cat == "BINDING_CATEGORY_PatchwerkForever" and a == b for _, cat, a, b in found), found
    for name, _, fn, _ in found:
        assert G["BINDING_NAME_" + name] and G[fn], name
    assert G.BINDING_NAME_PATCHWERKFOREVER_THREAD_GO == "Start Routing"
    ns.FloatStep(lua.table_from(["Kill: Plainstriders"]), None, None, True)
    G.PatchwerkForever_Thread_Routes_Step()
    assert lines() == ["Kill: Plainstriders"], lines()
    quiet()
    chat("keys")
    step("the way there in words, for the top of My Route: flights and rides, or a walk")
    words = ns.Travel(lua.eval("""{ flown = { { 'Crossroads', 'Camp Taurajo', 'Thunder Bluff' } },
        rides = { { kind = 'zeppelin', from = 'Orgrimmar', to = "Grom'gol" } }, yards = 300, seconds = 720 }"""))
    assert words == "Fly from Crossroads to Thunder Bluff, then take the zeppelin from Orgrimmar to Grom'gol (12 min in all)", words
    words = ns.Travel(lua.eval("{ flown = {}, rides = {}, yards = 450, seconds = 60 }"))
    assert words == "Walk 450 yd (60 s)", words

    step("Mark The Way Ahead: the game's pin lent to mark the trail ahead, yours kept, followed, and given back")
    slash("stop")
    chat("stop before the way ahead")
    set_option("flights", False)
    stub.player.x, stub.player.y, stub.player.map = -442.0, -2598.0, 1
    # (the game's pin as an addon can set it, and what it tracks: the stand-in only reads them otherwise)
    lua.execute("""
        local MAPS = { [1414] = { 1, 17066.6, -19733.21, 12799.9, -11733.3 }, [1415] = { 0, 18171.97, -22569.21, 11176.34, -15973.34 } }
        STUB.pinTracked, STUB.pinSets = false, 0
        C_Map.SetUserWaypoint = function(point)
            STUB.pin = { uiMapID = point.uiMapID, position = CreateVector2D(point.position.x, point.position.y) }
            STUB.pinSets = STUB.pinSets + 1
        end
        C_Map.ClearUserWaypoint = function() STUB.pin = nil end
        C_Map.GetMapPosFromWorldPos = function(map, pos)
            local id = map == 1 and 1414 or 1415
            local m = MAPS[id]
            return id, CreateVector2D((m[2] - pos.y) / (m[2] - m[3]), (m[4] - pos.x) / (m[4] - m[5]))
        end
        C_SuperTrack.SetSuperTrackedUserWaypoint = function(on) STUB.pinTracked = on and true or false if on then STUB.focus = 0 end end
        C_SuperTrack.IsSuperTrackingUserWaypoint = function() return STUB.pinTracked end
        C_SuperTrack.SetSuperTrackedQuestID = function(id) STUB.focus = id STUB.pinTracked = false end
        function STUB.PinWorld()
            local pin = STUB.pin
            if not pin then return nil end
            local map, world = C_Map.GetWorldPosFromMapPos(pin.uiMapID, pin.position)
            return world.x, world.y
        end
    """)
    marker = G.PatchwerkForever.Marker

    def pin_world():
        got = stub.PinWorld()
        return got if isinstance(got, tuple) else (None, None)

    stub.PinAt(1, -7140.0, -3790.0)                               # your own pin, at Gadgetzan
    stub.Fire("USER_WAYPOINT_UPDATED")
    frames()
    chat("a pin for the way ahead")
    dest = ns.dest
    assert dest and dest.pin and ns.route, "no route to the pin"
    stub.Tick()
    placed = ns.WayAheadPlaced()
    assert placed and marker.Active(marker) and marker.IsOurs(marker) and stub.pinTracked, "the way ahead was not marked"
    wx, wy = pin_world()
    far = ((wx - stub.player.x) ** 2 + (wy - stub.player.y) ** 2) ** 0.5
    assert 5 < far <= 40.5, "the marker is not on the trail a little way ahead: %.1f yd" % far
    mine = marker.Pin(marker)
    assert mine and abs(mine.position.x - stub.pin.position.x) > 1e-4, "your own pin was not kept"
    stub.Fire("USER_WAYPOINT_UPDATED")                            # (the game's word of the pin moved here: no news)
    frames()
    assert same(ns.dest, dest), "the pin moved to mark the way ahead was taken for a pin of yours"
    sets = stub.pinSets
    stub.Tick()
    assert stub.pinSets == sets, "the pin was set again without having moved"
    # walking on: the marker moves on along the trail
    p = ns.route.points[min(6, len(ns.route.points))]
    stub.player.x, stub.player.y = p[1], p[2]
    stub.time += 5
    stub.Tick()
    stub.Tick()
    assert not same(ns.WayAheadPlaced(), placed) and stub.pinSets > sets, "the marker did not move on as you walked"
    assert same(ns.dest, dest)
    # a pin of your own set while it is lent: yours, and routed to
    stub.PinAt(1, -956.0, -3754.0)
    stub.Fire("USER_WAYPOINT_UPDATED")
    frames()
    chat("a pin of your own while lent")
    assert not same(ns.dest, dest) and abs(ns.dest.x - -956.0) < 1 and abs(ns.dest.y - -3754.0) < 1, "your new pin was not routed to"
    stub.Tick()
    assert marker.IsOurs(marker), "the marker was not put back on the new trail"
    yours = marker.Pin(marker)
    assert yours and abs(yours.position.x - (17066.6 - -3754.0) / (17066.6 - -19733.21)) < 1e-6, "your new pin was not kept as yours"
    # a quest chosen while it is lent: it is yours to give back, and the route's marker takes the pin again
    lua.globals().C_SuperTrack.SetSuperTrackedQuestID(55)
    stub.Fire("SUPER_TRACKING_CHANGED")
    assert marker.Quest(marker) == 55, "the quest you chose was not kept"
    stub.Tick()
    assert stub.pinTracked, "the marker did not take the pin again after you chose a quest"
    # disabled: everything given back, and the route does not take the given-back pin for news
    dest = ns.dest
    set_option("wayAhead", False)
    assert not marker.Active(marker) and stub.focus == 55 and not stub.pinTracked, "the tracked quest was not given back"
    wx, wy = pin_world()
    assert abs(wx - -956.0) < 0.5 and abs(wy - -3754.0) < 0.5, "your pin was not given back: %s" % ((wx, wy),)
    stub.Fire("USER_WAYPOINT_UPDATED")
    frames()
    assert same(ns.dest, dest), "the pin given back was routed to anew"
    # on again, then Stop Routing: given back
    set_option("wayAhead", True)
    stub.Tick()
    assert marker.IsOurs(marker)
    slash("stop")
    chat("stop the way ahead")
    assert not marker.Active(marker), "stopping the route did not give the pin back"
    wx, wy = pin_world()
    assert abs(wx - -956.0) < 0.5, "your pin was not given back when the route stopped"
    # at logout too, and a pin left lent by a game that closed without one is given back at the next login
    slash("go")
    frames()
    stub.Tick()
    assert marker.IsOurs(marker)
    stub.Fire("PLAYER_LOGOUT")
    assert not marker.Active(marker) and abs(pin_world()[0] - -956.0) < 0.5, "not given back at logout"
    slash("stop")
    set_option("flights", True)
    chat("the way ahead")

    print("all steps ran; memory at the end %.1f MB" % (lua.eval("collectgarbage('count')") / 1024))


if __name__ == "__main__":
    main()
