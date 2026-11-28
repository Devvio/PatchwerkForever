"""Check Routes' GatherMate2 reading, the gathering run's pick, and tracking herbs and ore together.

    python lua_gathermate.py

A made-up GatherMate2 (its AceAddon object through LibStub, with GetNodesForZone, GetNameForNode and
its gmdbs, and a saved GatherMate2HerbDB) and a made-up GatherMate2_Data (GatherMateData2MineDB, loaded
on demand) in the Barrens; Routes' gathering files (Nodes, GatherMate, Gather, Tracking) on the base,
on the stand-in for the game (wowstub.lua). Asked: where GatherMate2's spots land in the world (against
the game's own map-to-world), that a spot told twice is kept once, the skill filter and its note, that
the run takes a cluster before a lone spot a little nearer, and the tracking switch: both at once where
the client allows it, taking turns where it does not, and stopping where the game blocks it.

What this proves: Routes reads GatherMate2's shapes (as GatherMate2 1.52.7 has them) and acts sensibly.
What it cannot prove: that the game's tracking API behaves as the stand-in does on Forever.
"""
import os

from lua_patchwerk import ADDONS, Session, toc

# What the rest of Routes gives these files (the minimap's redraws, where you stand, the destination),
# put in their place between Core.lua and Nodes.lua.
SHIM = r"""
local ADDON, ns = ...
ns.MinimapRedraws = function() return { On = function() end, Dirty = function() end } end
ns.MinimapLayer = function() return CreateFrame('Frame') end
ns.Place = function() return STUB.player.x, STUB.player.y, STUB.player.map end
ns.SetDestination = function(map, x, y, pin, announce, source, more)
	ns.dest = { map = map, x = x, y = y, source = source, lines = more and more.lines }
end
ns.Stop = function() ns.dest = nil end
"""


def routes(s):
    """Load Routes' gathering files as the game would (with the shim), then its ADDON_LOADED."""
    ns = s.lua.table()
    fields, _ = toc(ROUTES)
    meta = s.lua.table()
    for key, value in fields.items():
        meta[key] = value
    s.stub.meta[ROUTES] = meta
    s.stub.installed[ROUTES] = True
    for f in FILES:
        code = SHIM if f == "SHIM" else open(os.path.join(ADDONS, ROUTES, f), encoding="utf-8").read()
        s._load(code, "@" + ROUTES + "/" + f, ROUTES, ns)
    s.stub.loaded[ROUTES] = True
    s.stub.Fire("ADDON_LOADED", ROUTES)
    return ns

ROUTES = "PatchwerkForever_Thread_Routes"
FILES = ["Link.lua", "Core.lua", "SHIM", "Nodes.lua", "GatherMate.lua", "Gather.lua", "Tracking.lua", "Farm.lua", "Questie.lua", "Area.lua", "Danger.lua"]

FAKE = r"""
-- a spot on the Barrens' map (percent) as GatherMate2 keys it
local function C(x, y) return math.floor(x * 100 + 0.5) * 1000000 + math.floor(y * 100 + 0.5) * 100 end
STUB.C = C
GatherMate2HerbDB = { [1413] = { [C(50, 50)] = 401, [C(50.1, 50)] = 401, [C(60, 60)] = 412 } }
local names = { ['Herb Gathering'] = { [401] = 'Peacebloom', [412] = 'Liferoot' }, ['Mining'] = { [201] = 'Copper Vein', [206] = 'Mithril Deposit' } }
local gm = { gmdbs = { ['Herb Gathering'] = {}, ['Mining'] = {} } }
function gm:GetNodesForZone(zone, kind, ignoreFilter)
	local db = kind == 'Herb Gathering' and GatherMate2HerbDB or {}
	return pairs(db[zone] or {})
end
function gm:GetNameForNode(kind, id) return names[kind][id] end
function gm:GetIDForNode(kind, name) for id, n in pairs(names[kind]) do if n == name then return id end end end
local ace = { GetAddon = function(_, name) if name == 'GatherMate2' then return gm end end }
LibStub = setmetatable({}, { __call = function(_, name) if name == 'AceAddon-3.0' then return ace end end })
STUB.dataLoaded = false
C_AddOns.LoadAddOn = function(name)
	if name == 'GatherMate2_Data' then
		STUB.dataLoaded = true
		GatherMateData2MineDB = { [1413] = { [C(40, 40)] = 201, [C(70, 70)] = 206 } }
	end
	return true
end
-- the professions: both, at a skill of the check's choosing
STUB.skill = 300
function GetProfessions() return 1, 2 end
function GetProfessionInfo(i) return 'Profession', 1, STUB.skill, 300, 0, 0, i == 1 and 182 or 186 end
-- the tracking list: Find Herbs, Find Minerals, Find Fish. STUB.trackBoth: both may be on together
STUB.tracking = { { spellID = 2383, active = false }, { spellID = 2580, active = false }, { spellID = 7620, active = false } }
STUB.switches = 0
C_Minimap = C_Minimap or {}
C_Minimap.GetNumTrackingTypes = function() return #STUB.tracking end
C_Minimap.GetTrackingInfo = function(i) local t = STUB.tracking[i]; return { name = 'track' .. i, spellID = t.spellID, active = t.active } end
C_Minimap.SetTracking = function(i, on)
	if STUB.blockTracking then STUB.Fire('ADDON_ACTION_BLOCKED', 'PatchwerkForever_Thread_Routes', 'SetTracking()'); return end
	STUB.switches = STUB.switches + 1
	if on and not STUB.trackBoth then for _, t in ipairs(STUB.tracking) do t.active = false end end
	STUB.tracking[i].active = on
end
function IsPlayerSpell(id) return id == 2383 or id == 2580 end
C_Spell = C_Spell or {}
C_Spell.GetSpellName = function(id) return ({ [2383] = 'Find Herbs', [2580] = 'Find Minerals' })[id] end
do  -- (secure buttons keep attributes)
	local made = CreateFrame
	CreateFrame = function(...)
		local f = made(...)
		if not f.SetAttribute then
			f.attrs = {}
			function f:SetAttribute(k, v) self.attrs[k] = v end
			function f:GetAttribute(k) return self.attrs[k] end
		end
		return f
	end
end
function InCombatLockdown() return STUB.combat == true end
-- a QuestieDB: Plainstriders (level 5-6) in two groups in the Barrens, raptors far above you
local npcs = {
	[3] = { name = 'Plainstrider', minLevel = 5, maxLevel = 6, spawns = { [17] = {
		{ 30, 70 }, { 30.5, 70 }, { 31, 70.5 }, { 30, 71 }, { 30.5, 71.5 }, { 70, 30 } } } },
	[4] = { name = 'Sunscale Raptor', minLevel = 30, maxLevel = 31, spawns = { [17] = { { 50, 90 }, { 50.5, 90 }, { 51, 90 } } } },
	[5] = { name = 'Kolkar Bloodcharger', minLevel = 6, maxLevel = 7, spawns = { [17] = { { 80, 80 } } } },
	[6] = { name = 'Stormwind Guard', friendlyToFaction = 'A', spawns = { [17] = { { 60, 40 } } } },
}
local items = { [55] = { name = 'Strider Meat', npcDrops = { 3, 5 } } }
local function Entity(rows)
	return setmetatable({}, { __index = function(_, field)
		return function(id) local row = rows[id]; return row and row[field] end
	end })
end
LibQuestieDB = {
	Quest = Entity({}), Npc = Entity(npcs), Object = Entity({}), Item = Entity(items),
	RequireContract = function() return true end, Enum = {},

	Support = { Get = function(name)
		if name == 'ZoneDB' then return { private = { areaIdToUiMapId = 'return { [17] = 1413 }' } } end
		if name == 'QuestieClassicItemDrops' then return { wowheadData = 'return { [55] = { [3] = 40.0, [4] = 90.0 } }' } end
	end },
}
function UnitLevel() return 8 end
LibQuestieDB.Npc.GetAllIds = function() return { 3, 4, 5, 6 } end
STUB.player.side = 'Horde'
"""


def main():
    s = Session()
    s.lua.execute(FAKE)
    s.addon("PatchwerkForever")
    ns = routes(s)
    lua, stub = s.lua, s.stub
    # what the rest of Routes would give: where you stand, and the destination set
    setup = lua.eval("""function(ns)
        ns.Place = function() return STUB.player.x, STUB.player.y, STUB.player.map end
        ns.SetDestination = function(map, x, y, pin, announce, source, more)
            ns.dest = { map = map, x = x, y = y, source = source, lines = more and more.lines }
        end
        ns.Stop = function() ns.dest = nil end
    end""")
    setup(ns)
    s.login()
    G = lua.eval("PatchwerkForever.Guides")

    def world(x, y):
        m, wx, wy = G.WorldOf(1413, x / 100, y / 100)
        return m, wx, wy

    def stand(x, y):
        m, wx, wy = world(x, y)
        stub.player.map, stub.player.x, stub.player.y = m, wx, wy

    def step(text):
        print("  " + text)

    def spots(x, y, reach=8000):
        m, wx, wy = world(x, y)
        got = []
        ns.GatherMateAround(m, wx, wy, reach, lua.eval("function(f) return function(s) f(s) end end")(got.append))
        return got

    step("GatherMate2's spots, in the world where the game's map puts them; its bundled data loaded on demand")
    got = spots(50, 50)
    assert stub.dataLoaded, "GatherMate2_Data was not loaded"
    names = sorted(g[3] for g in got)
    assert names == ["Copper Vein", "Liferoot", "Mithril Deposit", "Peacebloom"], names   # (50 and 50.1: one spot)
    for g in got:
        if g[3] == "Liferoot":
            _, wx, wy = world(60, 60)
            assert abs(g[1] - wx) < 0.5 and abs(g[2] - wy) < 0.5, ((g[1], g[2]), (wx, wy))
            assert g.kind == "h" and g.id == 412
        if g[3] == "Copper Vein":
            _, wx, wy = world(40, 40)
            assert abs(g[1] - wx) < 0.5 and abs(g[2] - wy) < 0.5, ((g[1], g[2]), (wx, wy))
            assert g.kind == "o"
    assert ns.NodeSkill(got[0]) is not None

    G2 = lua.eval("PatchwerkForever.Gather")
    step("the skill filter: Mithril (175) left out at Mining 100, kept with a note at 160")
    stub.skill = 100
    stub.Fire("SKILL_LINES_CHANGED")
    stand(55, 55)                # (Copper Vein and Mithril both about 2100 yards away)
    near = sorted(n.name for n in G2.Near(G2, 10).values())
    assert "Mithril Deposit" not in near and "Copper Vein" in near, near
    stub.skill = 160
    stub.Fire("SKILL_LINES_CHANGED")
    assert G2.Start(G2, "kind", "Mithril Deposit") is True
    line = ns.dest.lines[1]
    assert line == "Gather: Mithril Deposit (needs Mining 175; you have 160)", line
    G2.Stop(G2)

    step("the run takes a cluster before a lone spot a little nearer")
    # Routes' own spots: a lone Silverleaf east, a cluster of three Earthroot west a little farther
    lua.execute("""
        local db = PatchwerkForever_Thread_RoutesDB
        db.nodeKinds['Silverleaf'] = { icon = 1, kind = 'h' }
        db.nodeKinds['Earthroot'] = { icon = 1, kind = 'h' }
    """)
    stub.skill = 300
    stub.Fire("SKILL_LINES_CHANGED")
    stand(20, 20)
    _, px, py = world(20, 20)
    note = lua.eval("function(ns, name, x, y) return ns.NodesNote(name, 'h', 1, x, y) end")
    note(ns, "Silverleaf", px, py + 100)
    for i in range(3):
        note(ns, "Earthroot", px, py - 120 - 40 * i)
    assert G2.Start(G2, "any") is True
    assert ns.dest.lines[1] == "Gather: Earthroot", ns.dest.lines[1]
    G2.Stop(G2)

    step("density: a group with many spots round it before a small group a little nearer")
    lua.execute("PatchwerkForever_Thread_RoutesDB.nodeKinds['Mageroyal'] = { icon = 1, kind = 'h' }")
    stand(85, 15)
    _, px, py = world(85, 15)
    # west: three in a short line from 80 yards; east: one at 100 yards with nine round it
    for i in range(3):
        note(ns, "Silverleaf", px, py + 80 + 20 * i)
    note(ns, "Mageroyal", px, py - 100)
    for i in range(9):
        note(ns, "Mageroyal", px - 40 + 10 * i, py - 130 - 5 * (i % 3))
    assert G2.Start(G2, "any") is True
    assert ns.dest.lines[1] == "Gather: Mageroyal", ns.dest.lines[1]
    G2.Stop(G2)

    step("gather best: the richest area on the continent first, then round it")
    stand(85, 85)
    _, px, py = world(85, 85)
    note(ns, "Silverleaf", px + 50, py)                    # (one near you)
    _, fx, fy = world(85, 75)                              # (about 1000 yards off: fifteen together)
    for i in range(15):
        note(ns, "Earthroot", fx + 25 * (i % 5), fy + 25 * (i // 5))
    assert G2.Start(G2, "best") is True
    best = G2.State(G2).best
    assert best and abs(best.x - (fx + 50)) < 60 and abs(best.y - (fy + 25)) < 60, (best and (best.x, best.y), fx, fy)
    assert ns.dest.lines[1] == "Gather: Earthroot", ns.dest.lines[1]
    said = [t for t in stub.messages.values() if "Best gathering area" in t]
    assert said, "the best area was not said"
    print("      " + said[-1])
    G2.Stop(G2)

    step("skinning: a creature you skin is remembered; /thread skin goes where most of them stand")
    assert ns.SkinNeeds(8) == 1 and ns.SkinNeeds(15) == 50 and ns.SkinNeeds(30) == 150
    stand(29, 69)
    lua.execute("""
        UnitGUID = function(u) return u == 'target' and 'Creature-0-1-2-3-3-0000AAAA' or 'Player-1-1' end
        UnitName = function() return 'Plainstrider' end
        GetNumLootItems = function() return 1 end
        GetLootSourceInfo = function() return 'Creature-0-1-2-3-3-0000AAAA', 1 end
    """)
    ns.SkinSay("")
    assert any("No skinnable creatures known yet" in t for t in stub.messages.values())
    stub.Fire("UNIT_SPELLCAST_SENT", "player", "Plainstrider", "cast-1", 8613)
    stub.Fire("LOOT_OPENED")
    known = lua.eval("PatchwerkForever_Thread_RoutesDB.skinned")[3]
    assert known and known.n == 1 and known.name == "Plainstrider", known
    stand(50, 50)
    ns.SkinSay("")
    said = [t for t in stub.messages.values() if "Best skinning area" in t]
    assert said and "5 spawn points (Plainstrider)" in said[-1], said
    print("      " + said[-1])
    _, gx, gy = world(30.4, 70.4)
    assert abs(ns.dest.x - gx) < 100 and abs(ns.dest.y - gy) < 100 and ns.dest.source is None, (ns.dest.x, ns.dest.y, gx, gy)

    step("/thread farm: where an item is most likely to drop; creatures far above you left out")
    ns.FarmSay("strider meat")
    said = [t for t in stub.messages.values() if "Best place for Strider Meat" in t]
    assert said and "Plainstrider" in said[-1] and "Raptor" not in said[-1], said
    print("      " + said[-1])
    assert abs(ns.dest.x - gx) < 100 and abs(ns.dest.y - gy) < 100
    ns.FarmSay("nothing like this")
    assert any("is not an item QuestieDB knows" in t for t in stub.messages.values())

    step("the tracker's calls: best area, skinning, farm, quest givers")
    assert G2.Best(G2) and G2.Best(G2).count > 0
    assert G2.SkinKnown(G2) == 1
    assert G2.CanFarm(G2, "strider meat") == "Strider Meat" and G2.CanFarm(G2, "55") == "Strider Meat"
    assert G2.CanFarm(G2, "nothing like this") is None
    assert G2.GiversState(G2) is not None, [t for t in stub.messages.values() if "fail" in t or "problem" in t]

    step("danger: none unless flagged (Auto); the other faction's guard, players seen, a death to a player")
    _, gx, gy = world(60, 40)
    _, fx, fy = world(20, 90)
    assert ns.DangerPenalty(1) is None, "danger avoided while not flagged"
    lua.execute("UnitIsPVP = function() return true end")
    ns.DangerBuildNow()
    pen = ns.DangerPenalty(1)
    near_guard, far = pen(1, gx, gy), pen(1, fx, fy)
    assert near_guard > 1.5 and far == 1, (near_guard, far)
    assert pen(0, gx, gy) == 1, "danger leaked onto another continent"
    lua.execute("""
        UnitExists = function() return true end
        UnitIsPlayer = function() return true end
        UnitIsEnemy = function() return true end
    """)
    stand(20, 90)
    stub.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    seen = ns.DangerPenalty(1)(1, fx, fy)
    assert seen > 1.5, seen
    stub.time += 400                                     # (five minutes and more: forgotten)
    assert ns.DangerPenalty(1)(1, fx, fy) == 1
    # (a death right after an enemy player was seen counts as a death to a player; long after, not)
    stub.Fire("PLAYER_DEAD")
    assert len(lua.eval("PatchwerkForever_Thread_RoutesDB.pvpDeaths")) == 0, "a death long after seeing a player counted"
    stub.Fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
    stub.Fire("PLAYER_DEAD")
    assert len(lua.eval("PatchwerkForever_Thread_RoutesDB.pvpDeaths")) == 1
    assert ns.DangerPenalty(1)(1, fx, fy) > 2, "a death to a player was not counted"
    print("      by the guard %.2f, where you died %.2f, far away %.2f" % (near_guard, ns.DangerPenalty(1)(1, fx, fy), pen(1, *world(90, 10)[1:])))
    lua.execute("UnitIsPVP = function() return false end")

    step("tracking: the key's secure button casts the other spell; nothing is switched by the addon")
    btn = lua.eval("PatchwerkForeverTrackSwitch")
    assert btn and btn.GetAttribute(btn, "type") == "spell"
    n = stub.switches
    for _ in range(20):
        stub.time += 1
        stub.Tick()
        stub.RunAfters()
    assert stub.switches == n, "the addon switched tracking by itself"
    stub.Fire("MINIMAP_UPDATE_TRACKING")
    assert ns.TrackingCasts() == 2383, ns.TrackingCasts()       # (neither on: Find Herbs)
    stub.tracking[1].active = True
    stub.Fire("MINIMAP_UPDATE_TRACKING")
    assert ns.TrackingCasts() == 2580 and btn.GetAttribute(btn, "spell") == "Find Minerals", (ns.TrackingCasts(), btn.GetAttribute(btn, "spell"))
    mode = ns.TrackingMode()
    assert mode.on == "h", mode.on
    lua.execute("InCombatLockdown = function() return true end")
    stub.tracking[1].active, stub.tracking[2].active = False, True
    stub.Fire("MINIMAP_UPDATE_TRACKING")
    assert ns.TrackingCasts() == 2580, "the button was changed in a fight"
    lua.execute("InCombatLockdown = function() return false end")
    stub.Fire("PLAYER_REGEN_ENABLED")
    assert ns.TrackingCasts() == 2383, "not put right after the fight"
    print("all steps ran")


if __name__ == "__main__":
    main()
