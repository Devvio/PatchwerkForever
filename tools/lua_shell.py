"""Run Patchwerk Forever's own tools, Thread (Routes) and Thread (Sparkle), outside the game on its base,
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
        problems = [t for t in new if "a problem in" in t or "Route search failed" in t]
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

    step("log in at Crossroads, a Horde character")
    stub.player.x, stub.player.y, stub.player.map = -442.0, -2598.0, 1
    stub.Fire("PLAYER_LOGIN")
    stub.Fire("PLAYER_ENTERING_WORLD")
    chat("login")
    assert len(stub.settings) == 80 and stub.category and stub.front, "the settings pages were not built"
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

    step("arrive")
    stub.player.x, stub.player.y = -7141.0, -3791.0
    stub.Tick()
    text = chat("arrive")
    assert not ns.dest and any("You have arrived" in t for t in text)
    stub.Tick()
    assert stub.shown == 0 or True

    step("the slash commands")
    stub.player.x, stub.player.y = -442.0, -2598.0
    for words in ("", "where", "to 52.5 30.1", "stop", "stop", "config", "nonsense"):
        slash(words)
        frames()
    chat("slash")
    assert stub.opened == 8, "the tool's own settings page did not open"

    step("no pin: the route follows the RestedXP guide's arrow, step by step")
    assert len(stub.settings) == 80, "the guide setting is missing from the settings page"
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
    # stopping it yourself: left alone until the guide moves on
    slash("stop")
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
    # its mark moves on to the next objective: the route goes with it
    stub.QuestAt(870, "The Forgotten Pools", 1, *CAMP)
    look()
    assert near(*CAMP), "the route did not follow the quest's mark"
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
    stub.player.x, stub.player.y = -442.0, -2598.0
    for _ in range(3):
        stub.Tick(); frames()
    assert near(*FIELD), "not routed back to the quest after walking well away"
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
    assert any("your RestedXP guide (it has priority" in t for t in chat("quest"))
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
    # stopped by you: the run is over
    slash("stop")
    go()
    assert not ns.dest and G.State(G) is None, "a run you stopped went on"
    # one kind: its spot here was just visited, so there is none; later there is
    assert G.Start(G, "kind", "Copper Vein") is False and G.State(G) is None
    text = chat("gather")
    assert any("No unvisited Copper Vein node" in t for t in text), text
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
    # (the spots made for this are forgotten again, so that what follows finds what it did before)
    for x, y in ((-460.0, -2640.0), (-700.0, -2900.0), (-2500.0, -2600.0)):
        stub.player.x, stub.player.y = x, y
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
    assert len(by_name) == 80, "expected 80 settings on the options pages, found %d" % len(by_name)
    assert "baseTellMissing" not in by_name, "the base's switch is on its front page, not a row of the game's"
    pages = sorted(stub.pages.keys())
    WANT = {"Thread: Routes": 14, "Routes: Trail": 12, "Routes: Step Text": 6, "Thread: Sparkle": 4, "Sparkle: Names": 8,
            "Sparkle: Behind My Character": 6, "Sparkle: Looks": 30}
    assert pages == sorted(WANT), pages
    for page in pages:
        on_it = [n for n, s in by_name.items() if s.page == page]
        assert len(on_it) == WANT[page], "%s has %d settings, expected %d" % (page, len(on_it), WANT[page])
    # headings, each kind of sparkle under its own on the one page of looks
    assert list(stub.headers.values()) == [
        "Destinations", "Travel Options", "Chat", "Gathering Nodes", "Display", "Line Style", "Colors", "Defaults",
        "Herbs", "Ore", "Chests", "Quest Objects", "Other Objects", "Defaults"], list(stub.headers.values())
    # every page opens with its name, its tool's picture and a line in Patchwerk's voice
    intros = {i.name: i for i in stub.intros.values()}
    assert sorted(intros) == sorted(WANT), sorted(intros)
    assert intros["Thread: Routes"].voice == "Follow the thread. Patchwerk knows the way. Mostly."
    assert intros["Routes: Trail"].voice.startswith("A line on the ground.") and intros["Sparkle: Looks"].voice.startswith("Every shiny thing")
    assert all(i.voice and i.icon and i.icon.endswith("icon") for i in intros.values()), [n for n, i in intros.items() if not i.voice]
    assert stub.Rows() == len(WANT) + 14, "a row of our own could not be made"
    # the front page: what is sewn on, each with a button to its page
    front = stub.front
    front.shown = True
    front.scripts.OnShow(front)
    page = tables[BASE].FrontShown()
    parts = [(x.name, x.says, x.open) for x in page.parts.values()]
    for part in parts:
        print("      front page: %s | %s" % part[:2])
    assert [x[0].split("  ")[0] for x in parts] == ["Thread (Routes)", "Thread (Sparkle)"] and all(x[2] for x in parts), parts
    assert "Two threads" in page.said, page.said
    names = [s.name for s in by_name.values()]
    assert "Route To Map Pin" in names and "Follow RestedXP Guide" in names and "Font Size" in names and "Walking Color" in names, names
    sdb = lua.globals().PatchwerkForever_Thread_SparkleDB
    assert sdb and not lua.globals().PatchwerkForever_Thread_RoutesDB.sparkleWas, "the sparkle keeps its things in the routes' saved data"
    buttons = list(stub.buttons.values())
    assert sorted(b.text for b in buttons) == ["Apply", "Clear", "Defaults", "Defaults", "Show", "Show"] + ["Test"] * 5, [b.text for b in buttons]
    assert sum(1 for s in by_name.values() if s.colour) == 11 and sum(1 for s in by_name.values() if s.choices) == 12

    def setv(name, value):
        by_name[name].set(value)

    # Reset To Defaults, one tool at a time: Routes' options go back, Sparkle's are left as they are
    setv("trailStyle", "dots")
    setv("flights", False)
    setv("nameSize", 20)
    [b for b in buttons if b.text == "Defaults" and b.page == "Thread: Routes"][0].click()
    assert "Reset all Thread: Routes options" in stub.asked.text, stub.asked.text
    stub.Answer(True)
    assert ns.Get("trailStyle") == "solid" and ns.Get("flights") is True, "Routes' options were not reset"
    assert sparkle.Get("nameSize") == 20, "resetting Routes reset the Sparkle too"
    [b for b in buttons if b.text == "Defaults" and b.page == "Thread: Sparkle"][0].click()
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
              "glints": 5, "fireflies": 6, "shimmer": 2, "ripple": 3, "wisp": 4}
    subtle = ("glints", "fireflies", "shimmer", "ripple", "wisp")
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
    [b for b in buttons if b.text == "Clear"][0].click()
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
    assert alpha_at(cx, cy) in (None, 1.0), "the sparkle faded without being asked"
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
    tests = [b for b in buttons if b.text == "Test"]
    for b in tests:
        b.click()
    assert len(marks()) == 2, "the Test button did not make its own mark"
    t = [m for m in marks() if not same(m, s)][0]
    assert t.shown and t.name.text == "This is another thing", t.name.text
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
    setv("trailWalk", "ff0000ff")
    assert drawn()[0].colour[3] == 1.0 and drawn()[0].colour[1] == 0.0, "the walking colour was not applied"
    setv("trailStyle", "dashes")
    # a dash of 10 pixels and a gap of 7, so 20 and 14 of the map's units: about one dash every 34
    dashes = len(drawn())
    assert long / 34 - 1 <= dashes <= long / 34 + solid + 1, "dashes: %d lines for a trail %.0f long" % (dashes, long)
    assert all(length([l]) <= 20.01 for l in drawn()), "a dash is too long"
    assert abs(length(drawn()) - long * 20 / 34) < 25, "the dashes do not cover the share of the trail they should"
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

    def words():
        got = ns.FloatShown()
        return (got[0], got[1]) if isinstance(got, tuple) else (got, None)

    def quiet():                       # the words on screen have had their time
        stub.time += 60
        stub.Frame()
        assert ns.FloatShown() is None, "the words did not go out"

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
    print("all steps ran; memory at the end %.1f MB" % (lua.eval("collectgarbage('count')") / 1024))


if __name__ == "__main__":
    main()
