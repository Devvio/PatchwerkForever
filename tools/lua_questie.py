"""Check the base's QuestieDB reader (PatchwerkForever/QuestieDB.lua) against a stand-in for QuestieDB.

    python lua_questie.py

A made-up LibQuestieDB (contract 4, the shape of QuestieDB 1.1.6's public interface) with a handful
of quests, NPCs and an object in the Barrens; the base is loaded on the stand-in for the game
(wowstub.lua) and asked: a quest's giver, its objective's nearest spawn, its turn-in, the base's
QuestPlace with QuestieDB on and off, a guide step with no spot filled in, the quest givers you can
take a quest from now, and a QuestieDB of a contract it was not written for.

What this proves: the reader turns QuestieDB's shapes into the right places and choices.
What it cannot prove: that the real QuestieDB answers as the stand-in does (its field shapes are
taken from its Types/*.t.lua), nor that its spots line up with the game's maps on Forever.
"""
from lua_patchwerk import Session

FAKE = r"""
local npcs = {
	[3] = { name = 'Plainstrider', spawns = { [17] = { { 50, 50 }, { 52, 50 }, { 90, 90 } } } },
	[10] = { name = 'Giver Gus', spawns = { [17] = { { 40, 40 } } }, friendlyToFaction = 'AH' },
	[11] = { name = 'Taker Tom', spawns = { [17] = { { 60, 60 } } }, friendlyToFaction = 'H' },
	[12] = { name = 'Grunt Hostile', spawns = { [17] = { { 41, 41 } } }, friendlyToFaction = 'A' },
	[13] = { name = 'Walker Wes', waypoints = { [17] = { { { 30, 30 }, { 31, 31 } } } } },
}
local objects = { [7] = { name = 'Crate', spawns = { [17] = { { 70, 70 } } } } }
local items = { [55] = { name = 'Strider Meat', npcDrops = { 3 } } }
local quests = {
	[100] = { name = 'Raptor Business', requiredLevel = 1, questLevel = 10,
		startedBy = { { 10 } }, finishedBy = { { 11 } },
		objectives = { { { 3, nil, 8 } }, nil, { { 55, nil, 5 } } } },
	[101] = { name = 'Easy One', requiredLevel = 1, questLevel = 9, startedBy = { { 10, 12 } }, finishedBy = { { 10 } }, objectives = {} },
	[102] = { name = 'Too High', requiredLevel = 30, questLevel = 30, startedBy = { { 10 } }, objectives = {} },
	[103] = { name = 'After Raptor', requiredLevel = 1, questLevel = 10, startedBy = { { 11 } }, preQuestSingle = { 100 }, objectives = {} },
	[104] = { name = 'Walk It', requiredLevel = 1, questLevel = 10, startedBy = { { 13 }, { 7 } }, objectives = {} },
}
local function Entity(rows)
	return setmetatable({}, { __index = function(_, field)
		return function(id) local row = rows[id]; return row and row[field] end
	end })
end
local Quest = Entity(quests)
Quest.GetAllIds = function() local ids = {}; for id in pairs(quests) do ids[#ids + 1] = id end; table.sort(ids); return ids end
LibQuestieDB = {
	Quest = Quest, Npc = Entity(npcs), Object = Entity(objects), Item = Entity(items),
	contractVersion = 4, minSupportedContract = 1,
	RequireContract = function(n) return n >= 1 and n <= 4, n > 4 and 'too new' or nil end,
	Enum = { raceMaskById = { [2] = 2 } },
	Support = { Get = function(name)
		if name == 'ZoneDB' then return { private = {
			areaIdToUiMapId = 'return { [17] = 1413 }', areaIdToUiMapIdOverride = 'return { [0] = 0 }',
			subZoneToParentZone = 'return { [380] = 17 }', subZoneToParentZoneOverride = 'return {}' } }
		end
	end },
}
bit = { band = function(a, b)
	local r, p = 0, 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then r = r + p end
		a, b, p = math.floor(a / 2), math.floor(b / 2), p * 2
	end
	return r
end }
function UnitLevel() return 10 end
function UnitRace() return 'Orc', 'Orc', 2 end
function UnitClass() return 'Warrior', 'WARRIOR', 1 end
function GetQuestGreenRange() return 8 end
STUB.objectives, STUB.complete, STUB.done = {}, {}, {}
C_QuestLog.GetQuestObjectives = function(id) return STUB.objectives[id] end
C_QuestLog.IsComplete = function(id) return STUB.complete[id] == true end
C_QuestLog.IsQuestFlaggedCompleted = function(id) return STUB.done[id] == true end
STUB.player.side = 'Horde'
"""


def main():
    s = Session()
    s.lua.execute(FAKE)
    s.addon("PatchwerkForever")
    s.login()
    lua, stub = s.lua, s.stub
    QDB = lua.eval("PatchwerkForever.QuestDB")
    G = lua.eval("PatchwerkForever.Guides")

    def world(x, y):            # a spot in the Barrens (percent) as world coordinates
        _, wx, wy = G.WorldOf(1413, x / 100, y / 100)
        return wx, wy

    def stand(x, y):
        wx, wy = world(x, y)
        stub.player.map, stub.player.x, stub.player.y = 1, wx, wy

    def near(got, x, y):
        wx, wy = world(x, y)
        assert got[0] == 1 and abs(got[1] - wx) < 0.5 and abs(got[2] - wy) < 0.5, (got, wx, wy)

    def step(text):
        print("  " + text)

    assert QDB.Ready(QDB), "QuestieDB was not seen"
    stand(49, 49)

    step("a quest not in your log: its giver")
    spots, mode = QDB.Spots(100)
    assert mode == "giver" and len(spots) == 1, (mode, len(spots))
    near(QDB.Place(100), 40, 40)

    step("in your log, the objective not done: the nearest spawn of the creature named in it")
    stub.QuestAt(100, "Raptor Business", 1, *world(10, 10))
    lua.execute("STUB.objectives[100] = { { type = 'monster', text = 'Plainstrider slain: 2/8', finished = false },"
                " { type = 'item', text = 'Strider Meat: 0/5', finished = false } }")
    QDB.Forget()
    spots, mode = QDB.Spots(100)
    assert mode == "objective", mode
    near(QDB.Place(100), 50, 50)
    step("the guide asks for one objective (the item): the creatures that drop it")
    spots, _ = QDB.Spots(100, None, 2)
    assert len(spots) == 3, len(spots)
    step("stays on the spawn gone to while another is only a little nearer")
    stand(51.2, 50)              # (52 is 40 yards nearer than 50: not enough to change)
    near(QDB.Place(100), 50, 50)

    step("the base's QuestPlace: QuestieDB first; with it off, the game's mark")
    near(G.QuestPlace(100), 50, 50)
    QDB.SetEnabled(QDB, False)
    near(G.QuestPlace(100), 10, 10)
    QDB.SetEnabled(QDB, True)

    step("done: the one who takes it in")
    lua.execute("STUB.objectives[100][1].finished = true; STUB.objectives[100][2].finished = true; STUB.complete[100] = true")
    spots, mode = QDB.Spots(100)
    assert mode == "turnin", mode
    near(QDB.Place(100), 60, 60)

    step("a guide step that names a quest to take, with no spot: sent to its giver")
    info = lua.eval("{ index = 4, kind = 'accept', lines = { { text = 'Accept Easy One', kind = 'accept', quest = 101 } } }")
    G.FillFromQuestie(info)
    assert info.questie and info.questie.mode == "giver" and info.key.find("questie") >= 0, info.key
    near((info.map, info.x, info.y), 40, 40)
    step("a step the guide gives a spot for is left as it is")
    info = lua.eval("{ index = 5, kind = 'accept', map = 1, x = 1, y = 2, lines = { { kind = 'accept', quest = 101 } } }")
    G.FillFromQuestie(info)
    assert info.x == 1 and info.questie is None

    step("quest givers with a quest you can take now")
    stub.QuestGone(100)
    lua.execute("STUB.done[100] = true; STUB.complete[100] = nil")
    QDB.Forget()
    lua.execute("STUB.Fire('QUEST_TURNED_IN', 100)")
    givers = QDB.Givers()
    found = {}
    for i in range(1, len(givers) + 1):
        g = givers[i]
        found[g.name] = sorted(g.quests[j] for j in range(1, len(g.quests) + 1))
    print("      " + repr(found))
    assert found.get("Giver Gus") == [101], found          # 100 done, 102 too high
    assert found.get("Taker Tom") == [103], found           # its quest before it is done
    assert found.get("Walker Wes") == [104] and found.get("Crate") == [104], found   # a walker's path, an object
    assert "Grunt Hostile" not in found, found              # of the other side

    step("a QuestieDB of a contract this was not written for: nothing, said once")
    s2 = Session()
    s2.lua.execute(FAKE)
    s2.lua.execute("LibQuestieDB.RequireContract = function() return false, 'contract mismatch' end")
    s2.addon("PatchwerkForever")
    s2.login()
    Q2 = s2.lua.eval("PatchwerkForever.QuestDB")
    assert not Q2.Ready(Q2) and not Q2.Ready(Q2)
    said = [t for t in s2.stub.messages.values() if "QuestieDB" in t]
    assert len(said) == 1, said
    print("all steps ran")


if __name__ == "__main__":
    main()
