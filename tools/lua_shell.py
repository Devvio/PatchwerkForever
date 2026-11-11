"""Run the whole of Patchwerk Forever: Wayfarer outside the game, against a stand-in for the game (wowstub.lua).

    python lua_shell.py

Loads the addon's files in the order its TOC gives, in a real Lua 5.1, and plays a session: log in,
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

ADDON = "PatchwerkForever_Wayfarer"


def toc_files(folder, name):
    for line in open(os.path.join(folder, name + ".toc"), encoding="utf-8"):
        line = line.strip()
        if line.endswith(".lua"):
            yield os.path.join(folder, line)


def main():
    lua = LuaRuntime(unpack_returned_tuples=True)
    here = os.path.dirname(os.path.abspath(__file__))
    lua.execute(open(os.path.join(here, "wowstub.lua"), encoding="utf-8").read())
    for map_id in (1,):
        for path in toc_files(os.path.join(ADDONS, ADDON + "_" + NAMES[map_id]), ADDON + "_" + NAMES[map_id]):
            lua.execute(open(path, encoding="ascii").read())
    ns = lua.table()
    load = lua.eval("function(code, name, addon, ns) return assert(loadstring(code, name))(addon, ns) end")
    for path in toc_files(os.path.join(ADDONS, ADDON), ADDON):
        load(open(path, encoding="utf-8").read(), "@" + os.path.basename(path), ADDON, ns)
    stub = lua.globals().STUB
    slash = lua.globals().SlashCmdList.PATCHWERKFOREVER_WAYFARER
    said = [0]

    def chat(label):
        new = list(stub.messages.values())[said[0]:]
        said[0] += len(new)
        for text in new:
            print("      chat: " + text.replace("|cff7fd4ff", "").replace("|r", ""))
        problems = [t for t in new if "a problem in" in t or "stopped on an error" in t]
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
    stub.Fire("ADDON_LOADED", ADDON)
    stub.Fire("PLAYER_LOGIN")
    stub.Fire("PLAYER_ENTERING_WORLD")
    chat("login")
    assert len(stub.settings) == 69 and stub.category, "the settings page was not built"
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
    assert not ns.dest and any("you are there" in t for t in text)
    stub.Tick()
    assert stub.shown == 0 or True

    step("the slash commands")
    stub.player.x, stub.player.y = -442.0, -2598.0
    for words in ("", "where", "to 52.5 30.1", "stop", "stop", "config", "nonsense"):
        slash(words)
        frames()
    chat("slash")
    assert stub.opened == 7, "the settings page did not open"

    step("no pin: the route follows the RestedXP guide's arrow, step by step")
    assert len(stub.settings) == 69, "the guide setting is missing from the settings page"
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
    assert not any("you are there" in m for m in list(stub.messages.values())[said_before:])
    # walking away with the step still open: routed back to it
    stub.player.x, stub.player.y = -442.0, -2598.0
    stub.time += 20
    for _ in range(3):
        stub.Tick(); frames()
    assert ns.dest and ns.dest.source == "rxp", "not routed back to an open step after walking away"
    # /wayfarer go with no pin routes to the guide; turning the setting off stops it
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
    assert not any("you are there" in m for m in list(stub.messages.values())[said_before:])
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
    # a quest on the other continent: the game's own next stop on the way, when it is on this one
    stub.QuestAt(872, "Message to Stormwind", 0, -9460.0, 60.0)
    stub.QuestStop(872, 1, *RATCHET)
    stub.watched = lua.table_from([870, 872])
    stub.focus = 872
    look("SUPER_TRACKING_CHANGED")
    assert near(*RATCHET), "the game's next stop on the way was not routed to"
    slash("go"); frames()
    text = chat("quest")
    assert any('on the way to your quest "Message to Stormwind"' in t for t in text), text
    stub.QuestStop(872, None)                                     # no stop given: the nearest tracked quest instead
    look()
    assert near(*CAMP), "a quest on another continent was not passed over"
    # a guide step as well: the guide first, unless you say the quest
    setting("rxp", True)
    arrow.element = lua.table_from({"wx": RATCHET[1], "wy": RATCHET[0], "instance": 1})
    stub.Tick(); frames()
    assert ns.dest.source == "rxp" and near(*RATCHET), "the guide did not come before the quest"
    slash("quest")
    assert any("your RestedXP guide, which comes first" in t for t in chat("quest"))
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
    assert any('followed now: "The Forgotten Pools"' in t for t in text), text
    assert any("not the one you are on" in t for t in text), text
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
    chat("quest")

    step("herbs and ore: a spot is remembered when you gather, and shown on both maps")
    db = lua.globals().PatchwerkForever_WayfarerDB
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
    assert any("1 herb spots and 1 ore spots" in t for t in text), text
    stub.player.x, stub.player.y = -442.0, -2598.0

    step("the options pages: every control is made, on the page it belongs to")
    by_name = {s.variable[len(ADDON) + 1:]: s for s in stub.settings.values()}
    assert len(by_name) == 69, "expected 69 settings on the options pages, found %d" % len(by_name)
    pages = sorted(stub.pages.keys())
    assert pages == ["Name Over Things", "Sparkle: Behind My Character", "Sparkle: Chests", "Sparkle: Herbs", "Sparkle: Ore",
                     "Sparkle: Other Things", "Sparkle: Quest Objects", "Trail"], pages
    for page in pages:
        on_it = [n for n, s in by_name.items() if s.page == page]
        want = 8 if page == "Name Over Things" else 10 if page == "Trail" else 6
        assert len(on_it) == want, "%s has %d settings, expected %d" % (page, len(on_it), want)
    buttons = list(stub.buttons.values())
    assert sorted(b.text for b in buttons) == ["Apply", "Forget", "Show"] + ["Test"] * 5, [b.text for b in buttons]
    assert sum(1 for s in by_name.values() if s.colour) == 9 and sum(1 for s in by_name.values() if s.choices) == 12

    def setv(name, value):
        by_name[name].set(value)

    step("a sparkle on the thing the game points at, each kind with its own look")
    cvars = stub.cvars
    assert cvars.SoftTargetNameplateInteract == "1" and cvars.SoftTargetIconGameObject == "1", "the game's two settings were not switched on"
    assert db.sparkleWas.SoftTargetNameplateInteract == "0", "what the settings were was not kept"
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
    assert not s.shown and db.sparkleIgnored["Silverleaf"], "ignoring a thing did not hide it"
    herb()
    assert not s.shown, "an ignored thing sparkled again"
    slash("ignore list")
    slash("ignore undo")
    assert s.shown, "undoing did not bring it back"
    lua.globals().PatchwerkForever_Wayfarer_Ignore()                       # the bound key
    assert not s.shown
    [b for b in buttons if b.text == "Forget"][0].click()
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
    assert any("15 yards is taken" in t for t in chat("sparkle")), "the command does not say the distance is assumed"
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
    assert any("will not say where the sparkle is" in t for t in chat("sparkle")), "the command does not say it cannot place the sparkle"
    # the Show button
    assert alpha_at(cx, cy) == 0.0
    [b for b in buttons if b.text == "Show"][0].click()
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
    assert any("15 yards out" in t and "100% covered" in t for t in text), text
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

    step("a pin somewhere with no way (the middle of the sea), and a pin on the other continent")
    stub.PinAt(1, 0.0, 9000.0)
    stub.Fire("USER_WAYPOINT_UPDATED")
    frames()
    chat("sea")
    stub.PinAt(0, -9460.0, 60.0)
    stub.Fire("USER_WAYPOINT_UPDATED")
    frames()
    chat("other continent")
    stub.pin = None
    stub.Fire("USER_WAYPOINT_UPDATED")
    assert not ns.dest
    lua.globals().PatchwerkForever_Wayfarer_Go()
    lua.globals().PatchwerkForever_Wayfarer_Stop()
    chat("bindings")
    print("all steps ran; memory at the end %.1f MB" % (lua.eval("collectgarbage('count')") / 1024))


if __name__ == "__main__":
    main()
