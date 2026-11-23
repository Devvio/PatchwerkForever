"""Run Sparkle (Thread) outside the game, on the base, against the stand-in for the game (wowstub.lua)
with what it needs added.

    python lua_sparkle.py

Plays what lua_shell.py does not: the options pages (Sparkle: Appearance, the settings that depend on a
tick box, the percent sliders, the title-case lists), the preview that follows the settings while the
options are open and stands beside them, the fade area's oval staying after the last change and after
the options close, the name above the game's icon, the ignore list (the key binding as a toggle, undo
taking back the last ignore, an object targeted long ago not used, clearing asked first), /sparkle and
its status and debug lines, the game's two settings put back at logout and turned on again when
the game turned one off, corpses (one with loot, one to skin, a living creature, a person, an empty
one; the game's functions missing or keeping their answer secret), and herbs and ore the character
has no profession for (shown until the professions are known, then dimmed or hidden). It fails loudly
on any Lua error.

What this proves: the addon's own code runs and does sensible things with the stand-in's answers.
What it cannot prove: where the preview lands beside the real options window, that the game's icon
frame is where the name is hung, that a setting changed at logout is saved, that the game's interact
key points at corpses at all, or that it answers about them and about professions as the stand-in
does. That is for the game.
"""
import os

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ADDONS = os.path.normpath(os.path.join(HERE, "..", "addons"))
BASE = "PatchwerkForever"
SPARKLE = "PatchwerkForever_Thread_Sparkle"

# what the stand-in lacks for this one
MORE = r"""
-- a font string remembers what it was hung from
local Create = CreateFrame
function CreateFrame(...)
    local frame = Create(...)
    local MakeFont = frame.CreateFontString
    function frame:CreateFontString(...)
        local fs = MakeFont(self, ...)
        function fs:SetPoint(point, to, rel, x, y) assert(to and x == x and y == y) self.point, self.to, self.rel = point, to, rel end
        return fs
    end
    function frame:GetRight() return self.right end
    function frame:GetBottom() return self.bottom end
    function frame:SetPoint(point, to, rel, x, y) assert(to and x == x and y == y) self.anchor, self.px, self.py = to, x, y end
    return frame
end
UIParent.right = 1002
function UIParent:GetRight() return self.right end
-- the options window: 920 wide in the middle of a wider screen, closed at first
SettingsPanel = CreateFrame('Frame')
SettingsPanel.shown = false
SettingsPanel.right, SettingsPanel.top, SettingsPanel.bottom = 1400, 900, 176
-- a value the game keeps secret: nothing may be done with it but ask whether it is one
STUB.SECRET = {}
function issecretvalue(value) return rawequal(value, STUB.SECRET) end
-- a creature the game points at: STUB.soft.dead, .loot (it has loot for you), .skin (its tooltip says
-- it can be skinned), .player (a person), .secret (the game will not say whether it is dead)
local function Soft(unit) return unit == 'softinteract' and STUB.soft or nil end
function UnitIsDead(unit)
    local soft = Soft(unit)
    if soft and soft.secret then return STUB.SECRET end
    return soft ~= nil and soft.dead == true
end
function UnitIsPlayer(unit) local soft = Soft(unit) return soft ~= nil and soft.player == true end
function UnitHasLootInteraction(unit) local soft = Soft(unit) return soft ~= nil and soft.loot == true end
function CanLootUnit(guid)
    local soft = STUB.soft
    if soft and guid == soft.guid and soft.loot then return true, true end
    return false, false
end
UNIT_SKINNABLE_LEATHER = 'Skinnable'
C_TooltipInfo = { GetUnit = function(unit)
    local soft = Soft(unit)
    if not soft then return nil end
    if soft.tips then return { lines = soft.tips } end
    local lines = { { leftText = soft.name }, { leftText = 'Level 5 Beast' } }
    if soft.skin then lines[#lines + 1] = { leftText = 'Skinnable' } end
    return { lines = lines }
end }
-- the character's professions: STUB.profs = the skill lines in the profession book, two primary and
-- one secondary ('secret': a line the game keeps to itself); nil: the book lists none. STUB.skills =
-- how many skills the game lists (0 just after login); STUB.ranks = { [skill line] = rank }.
STUB.skills = 0
function GetProfessions()
    local p = STUB.profs
    if not p then return nil, nil, nil, nil, nil end
    return p[1] and 1 or nil, p[2] and 2 or nil, nil, p[3] and 3 or nil, nil
end
function GetProfessionInfo(index)
    local line = STUB.profs[index]
    if line == 'secret' then line = STUB.SECRET end
    return 'Profession', 136246, 75, 150, 2, 0, line, 0
end
C_SkillInfo = {
    GetNumSkillLines = function() return STUB.skills end,
    GetSkillLineInfoByID = function(line)
        local rank = STUB.ranks and STUB.ranks[line]
        return rank and { skillID = line, rank = rank } or nil
    end,
}
-- 1.5.0: a corpse that belongs to a quest (soft.related), being mounted, the game's sounds and the
-- gamepad's rumble (kept in STUB.sounds and STUB.rumbles; STUB.pad: a gamepad is in use)
function UnitIsRelatedToActiveQuest(unit) local soft = Soft(unit) return soft ~= nil and soft.related == true end
function IsMounted() return STUB.mounted == true end
STUB.sounds, STUB.rumbles = {}, {}
function PlaySound(id) STUB.sounds[#STUB.sounds + 1] = id return true end
C_GamePad = {
    IsEnabled = function() return STUB.pad == true end,
    GetActiveDeviceID = function() return STUB.pad and 1 or nil end,
    SetVibration = function(kind, strength) assert(type(kind) == 'string' and strength > 0 and strength <= 1) STUB.rumbles[#STUB.rumbles + 1] = { kind, strength } end,
    StopVibration = function() STUB.rumbles.stopped = true end,
}
-- the game's waypoint marker: STUB.nav = a frame over its place on screen (nil: none), STUB.navFar its
-- distance, STUB.navHeld true while it is held at the screen's edge
C_Navigation = {
    GetFrame = function() return STUB.nav end,
    GetDistance = function() return STUB.navFar end,
    WasClampedToScreen = function() return STUB.navHeld == true end,
    HasValidScreenPosition = function() return STUB.navValid ~= false end,
    GetTargetState = function() return STUB.navState or 2 end,
}
C_SuperTrack.IsSuperTrackingUserWaypoint = function() return STUB.trackPin == true end
-- the loot window's slots: STUB.loot[slot] = { texture =, quality =, quest =, questID = }; money in copper
function GetLootSlotInfo(slot)
    local item = STUB.loot[slot]
    if not item then return nil end
    return item.texture, 'Item', 1, nil, item.quality, false, item.quest == true, item.questID, false
end
STUB.money = 1000
function GetMoney() return STUB.money end
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
    for addon in (BASE, SPARKLE):
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
    G = lua.globals()
    tables = {}
    for addon in (BASE, SPARKLE):
        tables[addon] = lua.table()
        for path in toc_files(os.path.join(ADDONS, addon), addon):
            load(open(path, encoding="utf-8").read(), "@" + addon + "/" + os.path.basename(path), addon, tables[addon])
        stub.Fire("ADDON_LOADED", addon)
    sp = tables[SPARKLE]
    assert sp.linked, "the tool did not join the base"
    slash = G.SlashCmdList.PATCHWERKFOREVER_SPARKLE
    said = [0]
    same = lua.eval("function(a, b) return a == b end")

    def chat():
        new = list(stub.messages.values())[said[0]:]
        said[0] += len(new)
        for text in new:
            print("      chat: " + text.replace("|cffffe680", "").replace("|r", ""))
        problems = [t for t in new if "a problem in" in t]
        assert not problems, problems
        return " / ".join(new)

    def step(label):
        print("  " + label)

    stub.Fire("PLAYER_LOGIN")
    stub.Fire("PLAYER_ENTERING_WORLD", True, False)
    chat()

    step("the options: Sparkle: Appearance, children of their tick box, percent sliders, title-case lists")
    defs = [d for d in sp.settings.values()]
    pages = {d.page for d in defs if d.page}
    assert "Sparkle: Appearance" in pages and "Sparkle: Looks" not in pages, pages
    by_key = {d.key: d for d in defs if d.key}
    for key in ("nameSize", "nameFont", "nameOutline", "nameColour", "nameFixed", "namePlace", "nameOffset"):
        assert by_key[key].parent == "sparkleName", key
    behind = ("sparkleBehindLeft", "sparkleBehindSize", "sparkleBehindWide", "sparkleBehindAcross", "sparkleBehindUp")
    for key in behind:
        assert by_key[key].parent == "sparkleBehind", key
    percent = [k for k, d in by_key.items() if d.percent]
    assert len(percent) == 26 and all(k.endswith((".bright", ".speed")) or k in behind or k in ("wispSpeed", "cueRumbleStrength", "sparkleBehindMount")
                                      for k in percent), percent
    for d in defs:
        for choice in (d.choices.values() if d.choices else []):
            label = choice[2]
            for word in label.replace("(", " ").replace(")", " ").split():
                assert word[0].isupper() or word[0].isdigit() or word in ("of",), "not in title case: " + label
    assert "Ignore / Unignore Sparkle Object" in by_key["sparkle"].desc or "Ignore / Unignore Sparkle Object" in \
        [d.desc for d in defs if d.name == "Clear Ignore List"][0]
    assert G.BINDING_NAME_PATCHWERKFOREVER_SPARKLE_IGNORE == "Ignore / Unignore Sparkle Object"
    buttons = {b.name: b for b in stub.buttons.values()}
    assert "Preview Name" in buttons and buttons["Preview Name"].page == "Sparkle: Names", list(buttons)
    bindings = open(os.path.join(ADDONS, SPARKLE, "Bindings.xml"), encoding="utf-8").read()
    assert 'category="BINDING_CATEGORY_PatchwerkForever"' in bindings and "ADDONS" not in bindings
    # 1.4.0: corpses and what you cannot gather, on the first page; the two new kinds with a look each
    for key, name in (("sparkleCorpse", "Sparkle On Corpses With Loot"), ("sparkleSkin", "Sparkle On Skinnable Corpses")):
        assert by_key[key].name == name and by_key[key].default is True and by_key[key].parent == "sparkle" and not by_key[key].page, key
    cannot = by_key["sparkleCannot"]
    assert cannot.name == "Herbs And Ore I Cannot Gather" and cannot.default == "show" and not cannot.page
    assert [(c[1], c[2]) for c in cannot.choices.values()] == [("show", "Show"), ("dim", "Dim"), ("hide", "Hide")]
    kinds = [k[1] for k in sp.KINDS.values()]
    assert kinds == ["herb", "ore", "loot", "quest", "questcorpse", "corpse", "skin", "other", "waypoint"], kinds
    colours = [by_key["look.%s.colour" % k].default for k in kinds]
    assert len(set(colours)) == len(kinds), "two kinds start with the same color: %s" % colours
    # every control is made, on the page it belongs to, each kind of sparkle under its own heading
    on_page = {}
    for made in stub.settings.values():
        if made.variable.startswith(SPARKLE + "_"):
            on_page[made.page] = on_page.get(made.page, 0) + 1
    assert on_page == {"Sparkle (Thread)": 11, "Sparkle: Names": 8, "Sparkle: Behind My Character": 7,
                       "Sparkle: Appearance": 70, "Sparkle: Loot Wisps": 11, "Sparkle: Alerts": 3, "Sparkle: Passed": 2}, on_page
    headers = list(stub.headers.values())
    assert headers == ["Herbs", "Ore", "Chests", "Quest Objects", "Quest Corpses", "Corpses With Loot", "Skinnable Corpses",
                       "Other Objects", "Waypoint", "Defaults"], headers
    # 1.5.0: a Show tick box for each kind but the two corpses (theirs are on the first page), the rest grayed out with it
    for k in kinds:
        show = by_key.get("look.%s.show" % k)
        assert (show is not None) == (k not in ("corpse", "skin")), k
        if show:
            assert by_key["look.%s.effect" % k].parent == "look.%s.show" % k and by_key["look.%s.sound" % k].parent == "look.%s.show" % k
    assert by_key["look.waypoint.effect"].default == "beam" and by_key["look.waypoint.height"].default == 0
    assert by_key["sparkleReach"].default == "game" and by_key["sparkleNear"].default is True and by_key["cueRumble"].default is False
    lists = [r for r in stub.rows.values() if r.template == "PatchwerkForeverListTemplate"]
    assert [r.data.name for r in lists] == ["Ignored Objects", "Passed"] and [r.page for r in lists] == ["Sparkle: Ignore List", "Sparkle: Passed"],         [(r.data.name, r.page) for r in lists]
    for k in ("corpse", "skin"):
        for part in ("effect", "colour", "size", "bright", "height", "speed"):
            assert by_key["look.%s.%s" % (k, part)].page == "Sparkle: Appearance", (k, part)
    assert len([b for b in stub.buttons.values() if b.name == "Preview Sparkle"]) == len(kinds)

    step("bare /sparkle lists the commands; status says one plain sentence")
    slash("")
    text = chat()
    assert "Sparkle commands (/sparkle or /pfs)" in text and "/sparkle status" in text and "/sparkle debug" in text, text
    assert "Soft" not in text, "bare /sparkle still prints the game's settings"
    slash("status")
    text = chat()
    assert "Nothing has been targeted since you logged in" in text and "an herb" in text, text
    plate = G.CreateFrame("Frame")
    HERB = "Cursor_Crosshair_GatherHerbs_64"

    def point_at(name, guid, cursor, with_plate=True):
        stub.soft = lua.table_from({"name": name, "guid": guid, "cursor": cursor, "plate": plate if with_plate else None}) if name else None
        stub.Fire("PLAYER_SOFT_INTERACT_CHANGED", "old", guid or "")

    def herb():
        point_at("Silverleaf", "GameObject-0-1-1-1-1617-0", HERB)

    def marks():
        return [f for f in stub.frames.values() if f.pieces is not None]

    herb()
    s = marks()[0]
    assert s.shown
    slash("status")
    assert "Silverleaf (Herb): sparkling." in chat()
    point_at("Mailbox", "GameObject-0-1-1-1-32349-0", "Cursor_Crosshair_Interact_64")
    slash("status")
    assert "Mailbox (Other Object): not sparkling: Include All Interactable Objects is disabled." in chat()
    slash("debug")
    text = chat()
    assert "Game interact settings: SoftTargetInteract 3" in text and "Cursor_Crosshair_Interact_64" in text, text

    step("the name Above Icon hangs over the game's icon when it shows, else over the nameplate")
    herb()
    sp.Set("namePlace", "above")
    assert same(s.name.to, plate) and s.name.rel == "CENTER"
    plate.UnitFrame = lua.table_from({"SoftTargetFrame": G.CreateFrame("Frame")})
    soft = plate.UnitFrame.SoftTargetFrame
    soft.Icon = G.CreateFrame("Frame")
    herb()
    assert same(s.name.to, soft) and s.name.point == "BOTTOM" and s.name.rel == "TOP", "the name is not over the icon"
    soft.Icon.shown = False
    herb()
    assert same(s.name.to, plate), "the name hangs from an icon that is not shown"
    sp.Set("namePlace", "below")
    assert same(s.name.to, plate) and s.name.point == "TOP"

    step("the ignore list: the key toggles, undo takes back the last ignore, an old target is not used")
    herb()
    G.PatchwerkForever_Thread_Sparkle_Ignore()
    assert not s.shown and "Press the key again" in chat()
    G.PatchwerkForever_Thread_Sparkle_Ignore()
    assert s.shown and "removed from the ignore list" in chat(), "the key did not take the ignore back"
    slash("ignore")
    assert not s.shown
    point_at("Copper Vein", "GameObject-0-1-1-1-1731-0", "Cursor_Crosshair_Mine_64")    # walked on to another
    slash("undo")
    assert "\"Silverleaf\" removed" in chat(), "undo did not take back the last ignore"
    point_at(None, None, None)
    stub.time += 5
    slash("ignore")                                               # (a moment after: still the vein)
    assert "\"Copper Vein\" added" in chat()
    slash("undo")
    chat()
    stub.time += 30
    G.PatchwerkForever_Thread_Sparkle_Ignore()                    # long after: nothing
    assert "No object targeted" in chat()
    sp.Set("sparkleInstance", True)                               # hidden, yet what is targeted is kept up to date
    stub.instance = True
    point_at("Tin Vein", "GameObject-0-1-1-1-1732-0", "Cursor_Crosshair_Mine_64")
    G.PatchwerkForever_Thread_Sparkle_Ignore()
    assert "\"Tin Vein\" added" in chat(), "the key acted on an object from before sparkles were hidden"
    slash("status")
    assert "not sparkling: you are in an instance and Hide In Instances is enabled" in chat()
    stub.instance = False
    sp.Set("sparkleInstance", False)

    step("Clear Ignore List asks first; the typed command does not; plain counts")
    buttons["Clear Ignore List"].click()
    assert stub.asked and "(1 object)" in stub.asked.text, stub.asked
    stub.Answer(False)
    assert G.PatchwerkForever_Thread_SparkleDB.sparkleIgnored["Tin Vein"], "cleared without a yes"
    buttons["Clear Ignore List"].click()
    stub.Answer(True)
    assert "1 object removed from the ignore list." in chat()
    slash("clear")
    assert "The ignore list is already empty." in chat()
    buttons["Clear Ignore List"].click()
    assert not stub.asked, "asked about an empty list"
    chat()

    step("a corpse with loot sparkles in its own look; a living creature, a person and an empty corpse do not")
    CREATURE = "Creature-0-1-1-1-6-0"

    def creature(name, cursor=None, **what):
        soft = {"name": name, "guid": CREATURE, "cursor": cursor, "plate": plate}
        soft.update(what)
        stub.soft = lua.table_from(soft)
        stub.Fire("PLAYER_SOFT_INTERACT_CHANGED", "old", CREATURE)

    def status():
        slash("status")
        return chat()

    creature("Kobold Vermin", "Cursor_Crosshair_Attack_64")       # alive: as before
    assert not s.shown, "a living creature sparkles"
    assert "No object is targeted right now." in status()
    creature("Kobold Vermin", "Cursor_Crosshair_LootAll_64", dead=True, loot=True)
    assert s.shown and s.kind == "corpse" and s.look.effect == "glow" and s.name.text == "Kobold Vermin", (s.shown, s.kind)
    assert s.look.r == 1.0 and abs(s.look.g - 0x73 / 255) < 0.01 and same(s.parent, plate), "a corpse's sparkle is not in its own color"
    assert "Kobold Vermin (Corpse With Loot): sparkling." in status()
    creature("Walker's Friend", None, dead=True, loot=True, player=True)
    assert not s.shown, "a dead person sparkles"
    creature("Kobold Vermin", None, dead=True)
    assert not s.shown, "a corpse with nothing for you sparkles"
    assert "Kobold Vermin (Corpse): not sparkling: it has no loot for you." in status()
    creature("Kobold Vermin", None, dead=True, loot=True)
    sp.Set("sparkleCorpse", False)
    assert not s.shown
    assert "not sparkling: Sparkle On Corpses With Loot is disabled." in status()
    sp.Set("sparkleCorpse", True)
    assert s.shown
    # the hiding options and the ignore list hold for a corpse as for an object
    sp.Set("sparkleCombat", True)
    stub.combat = True
    stub.Fire("PLAYER_REGEN_DISABLED")
    assert not s.shown and "you are in combat and Hide In Combat is enabled" in status()
    stub.combat = False
    stub.Fire("PLAYER_REGEN_ENABLED")
    sp.Set("sparkleCombat", False)
    assert s.shown
    G.PatchwerkForever_Thread_Sparkle_Ignore()
    assert not s.shown and "\"Kobold Vermin\" added" in chat()
    assert "not sparkling: it is on the ignore list." in status()
    G.PatchwerkForever_Thread_Sparkle_Ignore()
    assert s.shown and "removed from the ignore list" in chat()
    # looted while the game goes on pointing at it: the game says its loot changed
    stub.soft.loot = False
    stub.Fire("UNIT_LOOT", CREATURE, False)
    assert not s.shown, "a looted corpse went on sparkling"

    step("a corpse: the game's functions missing, or keeping their answer secret")
    has_loot, can_loot, is_dead = G.UnitHasLootInteraction, G.CanLootUnit, G.UnitIsDead
    creature("Kobold Vermin", None, dead=True, loot=True)
    G.UnitHasLootInteraction = None                               # the older way of asking still serves
    stub.Fire("UNIT_LOOT", CREATURE, True)
    assert s.shown and s.kind == "corpse", "no sparkle without UnitHasLootInteraction"
    G.CanLootUnit = None                                          # neither: no loot is known of
    stub.Fire("UNIT_LOOT", CREATURE, True)
    assert not s.shown and "it has no loot for you" in status()
    G.UnitHasLootInteraction, G.CanLootUnit = has_loot, can_loot
    G.UnitIsDead = None                                           # the game cannot be asked whether it is dead
    stub.Fire("UNIT_LOOT", CREATURE, True)
    assert not s.shown and "No object is targeted right now." in status()
    G.UnitIsDead = is_dead
    stub.Fire("UNIT_LOOT", CREATURE, True)
    assert s.shown
    creature("Kobold Vermin", None, dead=True, loot=True, secret=True)   # in combat the game may not say
    assert not s.shown, "a sparkle on a creature the game would not say is dead"
    assert "No object is targeted right now." in status()

    step("a skinnable corpse sparkles for a character with Skinning, and only then")
    SKIN = "Cursor_Crosshair_Skin_64"

    def professions(book, skills=0, ranks=None):
        stub.profs = lua.table_from(book) if book else None
        stub.skills = skills
        stub.ranks = lua.table_from(ranks) if ranks else None
        stub.Fire("SKILL_LINES_CHANGED")

    professions([393])
    creature("Mottled Boar", SKIN, dead=True)                     # told by the cursor
    assert s.shown and s.kind == "skin" and s.look.effect == "star" and s.look.b == 1.0, (s.shown, s.kind)
    assert "Mottled Boar (Skinnable Corpse): sparkling." in status()
    creature("Mottled Boar", None, dead=True, skin=True)          # told by the tooltip
    assert s.shown and s.kind == "skin", "a corpse whose tooltip says Skinnable does not sparkle"
    word, tips = G.UNIT_SKINNABLE_LEATHER, G.C_TooltipInfo
    G.UNIT_SKINNABLE_LEATHER = None                               # the game's word for it is not there
    creature("Mottled Boar", None, dead=True, skin=True)
    assert not s.shown and "Mottled Boar (Corpse): not sparkling: it has no loot for you." in status()
    G.UNIT_SKINNABLE_LEATHER, G.C_TooltipInfo = word, None        # nor the tooltip to read it from
    creature("Mottled Boar", None, dead=True, skin=True)
    assert not s.shown
    G.C_TooltipInfo = lua.eval("{ GetUnit = function() error('no tooltip for this unit') end }")   # or it fails
    creature("Mottled Boar", None, dead=True, skin=True)
    assert not s.shown and "it has no loot for you" in status()
    G.C_TooltipInfo = tips
    creature("Mottled Boar", SKIN, dead=True, loot=True)          # loot comes before the skin
    assert s.shown and s.kind == "corpse"
    stub.Fire("LOOT_CLOSED")                                      # looted: looked at again a moment later
    assert len(list(stub.afters.values())) == 1, "the corpse is not looked at again after looting"
    stub.soft.loot = False
    stub.RunAfters()
    assert s.shown and s.kind == "skin", "a looted corpse did not turn into one to skin"
    sp.Set("sparkleSkin", False)
    assert not s.shown and "not sparkling: Sparkle On Skinnable Corpses is disabled." in status()
    sp.Set("sparkleSkin", True)
    assert s.shown
    professions([182, 186])                                       # an herbalist and miner: no Skinning
    assert not s.shown, "a skinnable corpse sparkles for a character without Skinning"
    assert "Mottled Boar (Skinnable Corpse): not sparkling: this character does not have Skinning." in status()
    professions(None)                                             # just after login: not known, so not a skinner yet
    assert not s.shown and "the game has not yet said whether this character has Skinning" in status()
    professions(None, skills=14, ranks={393: 60})                 # no profession in the book, but the skill is listed
    assert s.shown, "Skinning found among the skills did not count"
    slash("debug")
    text = chat()
    assert "Professions: Herbalism no, Mining no, Skinning yes." in text and SKIN in text, text

    step("the loot wisp flies from a sparkling corpse in that kind's color")
    s.cx, s.cy = 520.0, 300.0
    stub.Frame()
    assert sp.spot and sp.spot.kind == "skin", "where the corpse is was not kept for the wisp"

    def violet():
        return sum(1 for t in stub.allTextures.values()
                   if t.colour and abs(t.colour[1] - 0.8) < 0.01 and abs(t.colour[2] - 0.6) < 0.01 and t.colour[3] == 1.0)

    before = violet()
    stub.Fire("ITEM_PUSH", 0, 134366)
    assert sp.WispsInAir() == (1, 0) and violet() >= before + 6, "no wisp in the skinnable corpse's color"
    stub.time += 3
    stub.Frame()
    stub.Frame()
    assert sp.WispsInAir() == (0, 0)
    s.cx, s.cy = None, None
    professions(None)
    point_at(None, None, None)

    step("herbs and ore you cannot gather: shown until the professions are known, then dimmed or hidden")
    VEIN = ("Copper Vein", "GameObject-0-1-1-1-1731-0", "Cursor_Crosshair_Mine_64")
    sp.Set("sparkleCannot", "hide")
    herb()
    assert s.shown and s.alpha == 1.0, "an herb was hidden before the game said what the professions are"
    assert "Silverleaf (Herb): sparkling." in status()
    professions([186, 393])                                       # a miner and skinner
    assert not s.shown, "an herb sparkles for a character without Herbalism, with Hide"
    assert "Silverleaf (Herb): not sparkling: this character does not have Herbalism and Herbs And Ore I Cannot Gather is set to Hide." in status()
    point_at(*VEIN)
    assert s.shown and s.alpha == 1.0, "a vein was hidden from a miner"
    point_at("Battered Chest", "GameObject-0-1-1-1-2843-0", "Cursor_Crosshair_LootAll_64")
    assert s.shown and s.alpha == 1.0, "a chest was hidden with the herbs"
    sp.Set("sparkleCannot", "dim")
    herb()
    assert s.shown and abs(s.alpha - 0.3) < 1e-9, "an herb is not dimmed: %s" % s.alpha
    assert "Silverleaf (Herb): sparkling, dimmed: this character does not have Herbalism and Herbs And Ore I Cannot Gather is set to Dim." in status()
    sp.Set("sparkleBehind", True)                                 # the fade behind your character keeps it dim
    stub.Frame()
    assert abs(s.alpha - 0.3) < 1e-9, s.alpha
    sp.Set("sparkleBehind", False)
    assert abs(s.alpha - 0.3) < 1e-9, s.alpha
    point_at(*VEIN)
    assert s.shown and s.alpha == 1.0, "a vein was dimmed for a miner"
    slash("debug")
    text = chat()
    assert "Professions: Herbalism no, Mining yes, Skinning yes." in text and "cannot gather: no" in text, text
    professions([182])                                            # an herbalist: the other way round
    assert s.shown and abs(s.alpha - 0.3) < 1e-9, "a vein is not dimmed for a character without Mining"
    assert "this character does not have Mining" in status()
    herb()
    assert s.alpha == 1.0
    sp.Set("sparkleCannot", "show")                               # as before 1.4.0
    point_at(*VEIN)
    assert s.shown and s.alpha == 1.0 and "Copper Vein (Ore): sparkling." in status()
    sp.Set("sparkleCannot", "hide")
    assert not s.shown
    # an answer is kept a few seconds, not asked for at every look
    stub.profs = lua.table_from([186])
    point_at(*VEIN)
    assert not s.shown, "the professions were asked for again at once"
    stub.time += 11
    point_at(*VEIN)
    assert s.shown, "the professions were never asked for again"
    # no profession in the book: the skills say, once the game lists any
    professions(None, skills=14, ranks={182: 75})
    assert not s.shown, "a vein sparkles for a character whose skills have no Mining"
    herb()
    assert s.shown
    # what the game will not say, or cannot be asked: everything shows
    professions(["secret"])
    point_at(*VEIN)
    assert s.shown, "a vein was hidden on a skill line the game keeps secret"
    book, skills = G.GetProfessions, G.C_SkillInfo
    G.GetProfessions, G.C_SkillInfo = None, None
    professions([182])
    assert s.shown, "a vein was hidden on a client that cannot be asked for professions"
    slash("debug")
    assert "Professions: not available." in chat()
    G.GetProfessions, G.C_SkillInfo = book, skills
    sp.Set("sparkleCannot", "show")
    professions(None)
    point_at(None, None, None)
    chat()

    step("the preview: a real object's name, hung from a stand-in nameplate at Vertical Offset")
    buttons["Preview Name"].click()
    t = [m for m in marks() if not same(m, s)][0]
    assert t.shown and t.name.text == "Peacebloom", t.name.text
    stand = t.anchor
    assert not same(stand, G.UIParent) and same(t.name.to, stand), "the preview is not hung like a real sparkle"
    previews = [b for b in stub.buttons.values() if b.name == "Preview Sparkle"]
    previews[kinds.index("other")].click()
    assert t.name.text == "Mailbox"
    stub.RunAfters()
    assert not t.shown

    step("while the options are open the preview follows the settings, beside the window")
    # (each stub.RunAfters() is the next frame: it runs only what was waiting before it)
    sp.Set("look.ore.size", 150)
    stub.RunAfters()
    assert not t.shown, "a preview popped up with the options closed"
    G.SettingsPanel.shown = True
    sp.Set("look.ore.size", 170)
    assert not t.shown
    stub.RunAfters()
    assert t.shown and t.name.text == "Copper Vein" and t.width == 170, (t.shown, t.name.text, t.width)
    assert stand.px == 0 and stand.py == 120, "no room beside the window, yet not above the middle of the screen"
    stub.RunAfters()                                              # (its few seconds are up)
    assert not t.shown
    G.UIParent.right = 2000                                       # a wide screen: room to the right of the window
    sp.Set("nameSize", 16)
    stub.RunAfters()
    assert t.shown and t.name.text == "Peacebloom", "a name setting did not show the preview"
    assert stand.px == 1700 and stand.py == 538, (stand.px, stand.py)
    stub.RunAfters()
    sp.Set("look.herb.effect", "glow")                            # many kinds at once (a reset): no preview pops up
    sp.Set("look.ore.effect", "glow")
    stub.RunAfters()
    assert not t.shown
    G.SettingsPanel.shown = False
    stub.RunAfters()
    chat()

    step("the fade area stays ten seconds after the last change and after the options close")
    sp.Set("sparkleBehind", True)
    G.SettingsPanel.shown = True
    [b for b in stub.buttons.values() if b.name == "Preview Area"][0].click()
    ovals = [f for f in stub.frames.values() if f.ring is not None]
    oval = ovals[0]
    stub.Frame()
    assert oval.shown and oval.text.text == "Fade Area", oval.text.text
    sp.Set("sparkleBehindSize", 120)
    afters = list(stub.afters.values())
    stub.afters = lua.table_from([])
    afters[0]()                                                   # the first ten seconds end: a later change keeps it
    assert oval.shown, "the oval went ten seconds after it was shown, not after the last change"
    for fn in afters[1:]:
        fn()
    assert not oval.shown
    oval.shown = True
    G.SettingsPanel.shown = True
    stub.Frame()
    G.SettingsPanel.shown = False                                 # the options close: ten more seconds
    stub.Frame()
    assert len(list(stub.afters.values())) == 1
    stub.RunAfters()
    assert not oval.shown
    stub.zoom = None
    oval.shown = True
    stub.Frame()
    assert "15 yards assumed" in oval.text.text, oval.text.text
    stub.zoom = 15
    sp.Set("sparkleBehindSize", 100)
    sp.Set("sparkleBehind", False)
    stub.RunAfters()

    step("the game's two settings: put back at logout, on at login, turned on again once if the game turns one off")
    cvars = stub.cvars
    assert cvars.SoftTargetNameplateInteract == "1" and cvars.SoftTargetIconGameObject == "1"
    stub.Fire("PLAYER_LOGOUT")
    assert cvars.SoftTargetNameplateInteract == "0" and cvars.SoftTargetIconGameObject == "0", "not put back at logout"
    stub.Fire("PLAYER_LOGIN")
    assert cvars.SoftTargetNameplateInteract == "1" and cvars.SoftTargetIconGameObject == "1"
    chat()
    cvars.SoftTargetIconGameObject = "0"                          # the game's own option turned it off
    point_at("Silverleaf", "GameObject-0-1-1-1-1617-0", HERB, with_plate=False)
    slash("status")
    text = chat()
    assert "SoftTargetIconGameObject was off, so it was turned back on" in text and cvars.SoftTargetIconGameObject == "1", text
    cvars.SoftTargetIconGameObject = "0"
    point_at("Silverleaf", "GameObject-0-1-1-1-1617-0", HERB, with_plate=False)
    slash("status")
    text = chat()
    assert cvars.SoftTargetIconGameObject == "0" and "turned back on" not in text, "fought the game over a setting"
    assert "the game setting SoftTargetIconGameObject is off" in text, text
    point_at(None, None, None)
    stub.Fire("PLAYER_LOGOUT")
    assert cvars.SoftTargetNameplateInteract == "0", "the original was lost"

    step("Sparkle With Keyboard And Mouse: the game's Enable Interact Key on while sparkles are, put back after")
    assert cvars.SoftTargetInteract == "1", "the interact setting not put back at logout"
    stub.Fire("PLAYER_LOGIN")
    assert cvars.SoftTargetInteract == "3"
    sp.Set("sparkleKeyboard", False)
    assert cvars.SoftTargetInteract == "1", "disabling the option did not put the game's setting back"
    slash("status")
    assert "or when Sparkle With Keyboard And Mouse is enabled" in chat()
    sp.Set("sparkleKeyboard", True)
    assert cvars.SoftTargetInteract == "3"
    sp.Set("sparkle", False)
    assert cvars.SoftTargetInteract == "1", "disabling sparkles did not put it back"
    sp.Set("sparkle", True)
    stub.Fire("PLAYER_LOGOUT")
    cvars.SoftTargetInteract = "2"                                 # keyboard and mouse only: already enough
    stub.Fire("PLAYER_LOGIN")
    assert cvars.SoftTargetInteract == "2", "a setting that already includes the keyboard was changed"
    stub.Fire("PLAYER_LOGOUT")
    assert cvars.SoftTargetInteract == "2"

    step("the subtle preset names the page")
    [b for b in stub.buttons.values() if b.name == "Apply Subtle Preset"][0].click()
    assert "Sparkle: Appearance" in chat()

    # ---------------------------------------------------------------- 1.5.0
    stub.Fire("PLAYER_LOGIN")
    chat()

    step("the probe: /sparkle debug prints the tooltip's lines, with a color where it is not white or gold")
    red = lua.table_from({"r": 1.0, "g": 0.13, "b": 0.13})
    white = lua.table_from({"r": 1.0, "g": 1.0, "b": 1.0})
    herb()
    stub.soft.tips = lua.table_from([lua.table_from({"leftText": "Silverleaf", "leftColor": white}),
                                     lua.table_from({"leftText": "Requires Herbalism (150)", "leftColor": red})])
    slash("debug")
    text = chat()
    assert "Tooltip: Silverleaf / Requires Herbalism (150) {1.00 0.13 0.13}." in text, text
    assert "Related to an active quest: no" in text and "reach 60 yards" in text, text
    point_at(None, None, None)
    slash("debug")
    assert "point at an object or corpse" in chat()

    step("Show for each kind: off, nothing of that kind sparkles, and status says why")
    herb()
    sp.Set("look.herb.show", False)
    assert not s.shown
    assert "Silverleaf (Herb): not sparkling: Show is off for Herbs on Sparkle: Appearance." in status()
    point_at(*VEIN)
    assert s.shown, "an ore node hid with the herbs"
    sp.Set("look.herb.show", True)
    herb()
    assert s.shown

    step("Sparkle Distance: the game's reach only raised, and put back")
    cvars.SoftTargetInteractRange = "10"
    sp.Set("sparkleReach", "30")
    assert cvars.SoftTargetInteractRange == "30"
    sp.Set("sparkleReach", "20")
    assert cvars.SoftTargetInteractRange == "20", "a lower choice did not come down"
    sp.Set("sparkleReach", "game")
    assert cvars.SoftTargetInteractRange == "10", "not put back"
    cvars.SoftTargetInteractRange = "40"
    sp.Set("sparkleReach", "30")
    assert cvars.SoftTargetInteractRange == "40", "the game's reach was lowered"
    assert G.PatchwerkForever_Thread_SparkleDB.sparkleWas.SoftTargetInteractRange is None
    cvars.SoftTargetInteractRange = "15"
    sp.Set("sparkleReach", "20")
    sp.Set("sparkle", False)
    assert cvars.SoftTargetInteractRange == "15", "disabling sparkles did not put the reach back"
    sp.Set("sparkle", True)
    assert cvars.SoftTargetInteractRange == "20"
    stub.Fire("PLAYER_LOGOUT")
    assert cvars.SoftTargetInteractRange == "15", "not put back at logout"
    stub.Fire("PLAYER_LOGIN")
    assert cvars.SoftTargetInteractRange == "20"
    chat()

    step("Brighter When Near: from Routes' remembered spots, fainter at the edge of the reach")
    G.PatchwerkForever_Thread_RoutesDB = lua.eval("{ nodes = { [1] = { { 14, 0, 'Silverleaf' }, { 300, 0, 'Silverleaf' } } }, nodeKinds = {} }")
    stub.player.x, stub.player.y = 0, 0
    point_at(None, None, None)
    herb()
    stub.Frame()
    assert abs(s.near - (1 - 0.6 * 10 / 16)) < 1e-6 and abs(s.yards - 14) < 1e-6, (s.near, s.yards)
    stub.player.x = 9
    for _ in range(20):
        stub.Frame()
    assert abs(s.near - (1 - 0.6 * 1 / 16)) < 1e-6, s.near
    stub.player.x = -60                                           # the nearest spot is out of reach: another node
    for _ in range(20):
        stub.Frame()
    assert s.near == 1 and s.yards is None, (s.near, s.yards)
    stub.player.x = 0
    sp.Set("sparkleNear", False)
    stub.Frame()
    assert s.near == 1
    sp.Set("sparkleNear", True)
    point_at(*VEIN)                                               # a node Routes does not know: full brightness
    stub.Frame()
    assert s.near == 1 and s.spots is None

    step("Fade While Gathering: a cast aimed at it, or the loot window, fades it")
    herb()
    stub.Fire("UNIT_SPELLCAST_SENT", "player", "Silverleaf", "guid", 2366)
    assert abs(s.alpha - 0.25) < 1e-9, s.alpha
    stub.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2366)
    assert s.alpha == 1.0
    stub.Fire("LOOT_OPENED")
    assert abs(s.alpha - 0.25) < 1e-9
    stub.Fire("LOOT_CLOSED")
    assert s.alpha == 1.0
    stub.RunAfters()
    stub.Fire("UNIT_SPELLCAST_SENT", "player", "Some Other Thing", "guid", 1)
    assert s.alpha == 1.0, "a cast at something else faded it"
    sp.Set("sparkleGathering", False)
    stub.Fire("UNIT_SPELLCAST_SENT", "player", "Silverleaf", "guid", 2366)
    assert s.alpha == 1.0
    stub.Fire("UNIT_SPELLCAST_STOP", "player")
    sp.Set("sparkleGathering", True)

    step("alerts: a sound once an object, the gamepad's rumble only while one is in use")
    point_at(None, None, None)
    sp.Set("look.herb.sound", "ping")
    herb()
    assert list(stub.sounds.values()) == [3175], list(stub.sounds.values())
    point_at(*VEIN)
    herb()                                                        # back again at once: no second ring
    assert len(stub.sounds) == 1
    stub.time += 31
    point_at(*VEIN)
    herb()
    assert len(stub.sounds) == 2, "the same herb never alerted again"
    sp.Set("cueRumble", True)
    stub.time += 31
    point_at(*VEIN)
    herb()
    assert len(stub.rumbles) == 0, "rumbled with no gamepad in use"
    stub.pad = True
    stub.time += 31
    point_at(*VEIN)                                               # ore has no sound: no rumble for Types With An Alert Sound
    assert len(stub.rumbles) == 0
    herb()
    assert len(stub.rumbles) == 1 and stub.rumbles[1][1] == "Low" and abs(stub.rumbles[1][2] - 0.5) < 1e-9
    stub.RunAfters()
    assert stub.rumbles.stopped
    sp.Set("cueRumbleFor", "all")
    stub.time += 31
    point_at(*VEIN)
    assert len(stub.rumbles) == 2, "Every Sparkle did not rumble for ore"
    buttons = {b.name: b for b in stub.buttons.values()}
    buttons["Preview Rumble"].click()
    assert len(stub.rumbles) == 3
    stub.pad = False
    buttons["Preview Rumble"].click()
    assert "No gamepad in use" in chat()
    sp.Set("cueRumble", False)
    sp.Set("look.herb.sound", "none")
    previews = [b for b in stub.buttons.values() if b.name == "Preview Sparkle"]
    sp.Set("look.ore.sound", "coins")
    previews[kinds.index("ore")].click()
    assert stub.sounds[len(stub.sounds)] == 120, "the preview did not play the alert sound"
    sp.Set("look.ore.sound", "none")
    stub.RunAfters()
    point_at(None, None, None)

    step("Use This Look For All and Preview All Types")
    sp.Set("look.herb.effect", "embers")
    sp.Set("look.herb.size", 150)
    sp.Set("look.herb.height", -20)
    [b for b in stub.buttons.values() if b.name == "Use This Look For All"][0].click()
    assert "Every object type now looks like Herbs" in chat()
    for k in kinds:
        assert sp.Get("look.%s.effect" % k) == "embers" and sp.Get("look.%s.size" % k) == 150, k
    assert sp.Get("look.ore.height") == -20 and sp.Get("look.waypoint.height") == 0, "the waypoint took a nameplate's offset"
    assert sp.Get("look.ore.colour") == by_key["look.ore.colour"].default, "a color was copied"
    before = len(marks())
    buttons["Preview All Types"].click()
    row = marks()[before:]
    assert len(row) == len(kinds) and all(m.shown for m in row), len(row)
    assert [m.name.text for m in row][:2] == ["Peacebloom", "Copper Vein"], [m.name.text for m in row]
    stub.Frame()
    stub.RunAfters()
    assert not any(m.shown for m in row)

    step("the themed effects and preset draw without trouble")
    for effect in ("leaves", "embers", "coins", "rays"):
        sp.Set("look.herb.effect", effect)
        herb()
        for _ in range(5):
            stub.Frame()
        assert s.shown and s.look.effect == effect, effect
    buttons["Apply Themed Preset"].click()
    assert "Themed preset applied" in chat()
    assert sp.Get("look.herb.effect") == "leaves" and sp.Get("look.ore.effect") == "embers" and sp.Get("look.loot.effect") == "coins"
    buttons["Apply Subtle Preset"].click()
    chat()

    step("Character Height On Mount sizes the fade area while mounted")
    sp.Set("sparkleBehind", True)
    [b for b in stub.buttons.values() if b.name == "Preview Area"][0].click()
    stub.Frame()
    walking = oval.width
    stub.mounted = True
    stub.Frame()
    assert abs(oval.width / walking - 1.6) < 1e-6, (oval.width, walking)
    stub.mounted = False
    sp.Set("sparkleBehind", False)
    stub.RunAfters()

    step("a quest corpse sparkles in its own look, even with Sparkle On Corpses With Loot off")
    creature("Bristleback Quilboar", None, dead=True, loot=True, related=True)
    assert s.shown and s.kind == "questcorpse" and s.look.effect == "ripple", (s.shown, s.kind, s.look.effect)
    assert "Bristleback Quilboar (Quest Corpse): sparkling." in status()
    sp.Set("sparkleCorpse", False)
    assert s.shown
    sp.Set("sparkleCorpse", True)
    sp.Set("look.questcorpse.show", False)
    assert not s.shown and "Show is off for Quest Corpses" in status()
    sp.Set("look.questcorpse.show", True)
    creature("Bristleback Quilboar", None, dead=True, loot=False, related=True)
    assert not s.shown, "a quest corpse with nothing for you sparkles"
    point_at(None, None, None)

    step("the waypoint: a sparkle over the game's marker, with the quest's name and distance")
    nav = G.CreateFrame("Frame")
    nav.cx, nav.cy = 600.0, 400.0
    stub.QuestAt(77, "The Den", 1, 100, 100)
    stub.focus = 77
    stub.nav, stub.navFar = nav, 120
    for _ in range(20):                                           # (looked for a few times a second while there is none)
        stub.Frame()
    w = sp.WaypointMark()
    assert w and w.shown and w.look.effect == "beam", "no sparkle on the waypoint"
    assert w.name.text == "The Den (120 yd)", w.name.text
    stub.Frame()
    assert abs(w.near - (1 - 0.6 * 116 / 196)) < 1e-6, w.near
    assert "Waypoint: The Den (120 yd): sparkling." in status()
    stub.navHeld = True                                           # off screen: the game's arrow at the edge
    stub.Frame()
    assert not w.shown
    assert "off screen" in status()
    stub.navHeld = False
    for _ in range(20):
        stub.Frame()
    assert w.shown
    sp.Set("look.waypoint.show", False)
    stub.Frame()
    assert not w.shown and "Waypoint: The Den: not sparkling: Show is off for Waypoint" in status()
    sp.Set("look.waypoint.show", True)
    for _ in range(20):
        stub.Frame()
    assert w.shown
    # where the game itself would not show its marker, no beam: no valid spot on screen, no valid way
    stub.navValid = False
    stub.Frame()
    assert not w.shown, "a beam on a marker with no valid place on screen (stuck on screen)"
    stub.navValid = None
    for _ in range(20):
        stub.Frame()
    assert w.shown
    stub.navState = 0
    stub.Frame()
    assert not w.shown, "a beam on a marker whose way is not valid"
    stub.navState = None
    # the marker lent to Routes to mark the way ahead: the beam says where the route leads, and how far
    lua.execute("""
        local M = PatchwerkForever.Marker
        STUB.realMarker = { Active = M.Active, IsOurs = M.IsOurs, Info = M.Info }
        STUB.ours = true
        M.Active = function() return true end
        M.IsOurs = function() return STUB.ours end
        M.Info = function() return { words = 'Peacebloom', map = 1, x = 30, y = 40 } end
    """)
    stub.player.x, stub.player.y = 0, 0
    for _ in range(40):
        stub.Frame()
    assert w.shown and w.name.text == "Peacebloom (50 yd)", w.name.text
    assert abs(w.near - (1 - 0.6 * 46 / 196)) < 1e-6, w.near
    stub.ours = False                                             # held by Routes, but not on the way just now
    stub.Frame()
    assert not w.shown, "a beam on a marker the route holds for nothing"
    lua.execute("""
        local M = PatchwerkForever.Marker
        M.Active, M.IsOurs, M.Info = STUB.realMarker.Active, STUB.realMarker.IsOurs, STUB.realMarker.Info
    """)
    for _ in range(20):
        stub.Frame()
    stub.trackPin = True
    for _ in range(40):
        stub.Frame()
    assert w.shown and w.name.text.startswith("Map Pin"), w.name.text
    stub.trackPin = False
    stub.nav = None
    stub.Frame()
    assert not w.shown

    step("wisps: by item quality, a Rare one celebrated, quest items to the tracker, coins to the bag")
    sp.Set("wispColour", "quality")
    stub.loot = lua.table_from([lua.table_from({"texture": 134366, "quality": 4}),
                                lua.table_from({"texture": 133940, "quality": 1, "quest": True, "questID": 77}),
                                lua.table_from({"texture": 135000, "quality": 1})])
    stub.Fire("LOOT_READY")
    stub.Fire("ITEM_PUSH", 0, 134366)
    last = sp.lastWisp
    assert (round(last.r, 2), round(last.g, 2), round(last.b, 2)) == (0.64, 0.21, 0.93) and last.grand and last.size == 105, \
        (last.r, last.g, last.b, last.grand, last.size)
    block = G.CreateFrame("Frame")
    block.cx, block.cy = 900.0, 500.0
    lua.execute("function PatchwerkForever_Thread_Tracker_QuestBlock(id) if id == 77 then return STUB.block end end")
    stub.block = block
    stub.Fire("ITEM_PUSH", 0, 133940)
    last = sp.lastWisp
    assert last.bx == 900 and last.by == 500, (last.bx, last.by)
    assert abs(last.g - 0xd9 / 255) < 0.01 and not last.grand, "a quest item is not in the quest color"
    stub.Fire("ITEM_PUSH", 0, 135000)
    assert sp.lastWisp.r == 1 and sp.lastWisp.b == 1 and not sp.lastWisp.grand
    sp.Set("wispQuest", False)
    stub.loot = lua.table_from([lua.table_from({"texture": 133940, "quality": 1, "quest": True, "questID": 77})])
    stub.Fire("LOOT_READY")
    stub.Fire("ITEM_PUSH", 0, 133940)
    assert sp.lastWisp.bx != 900, "a quest item flew to the tracker with the option off"
    sp.Set("wispQuest", True)
    stub.Fire("LOOT_OPENED")
    stub.money = 1050
    stub.Fire("PLAYER_MONEY")
    last = sp.lastWisp
    assert last.icon == "Interface\\Icons\\INV_Misc_Coin_01" and abs(last.g - 0xd2 / 255) < 0.01, (last.icon, last.g)
    stub.Fire("LOOT_CLOSED")
    stub.time += 10
    sp.lastWisp = None
    stub.money = 2000                                             # paid for a quest, long after any loot: no wisp
    stub.Fire("PLAYER_MONEY")
    assert sp.lastWisp is None, "coins flew that were not looted"
    sp.Set("wispColour", "kind")
    stub.time += 5
    stub.Frame()
    stub.Frame()
    stub.RunAfters()
    G.PatchwerkForever_Thread_Tracker_QuestBlock = None

    step("passed: what you walk away from is remembered, told, routed to, and given to Routes")
    lua.execute("""
        STUB.notes, STUB.routed = {}, {}
        local none = function() end
        PatchwerkForever.Gather:Offer({ Near = none, Start = none, Stop = none, State = none,
            Note = function(...) STUB.notes[#STUB.notes + 1] = { ... } return true end })
        PatchwerkForever.MyRoute.Add = function(self, stop)
            STUB.routed[#STUB.routed + 1] = { stop.kind, stop.label, stop.x, stop.y }
            return true
        end
    """)

    def rows_of(t):
        return [tuple(r.values()) for r in t.values()]

    class Seen:
        def __init__(self, name):
            self.name = name

        def __eq__(self, other):
            return rows_of(getattr(stub, self.name)) == other

        def __len__(self):
            return len(getattr(stub, self.name))

        def __repr__(self):
            return repr(rows_of(getattr(stub, self.name)))

    notes, routed = Seen("notes"), Seen("routed")
    point_at(None, None, None)
    slash("passed clear")                                         # (the steps before walked past a good few)
    assert "forgotten" in chat()
    stub.player.x, stub.player.y = 0, 0
    herb()
    stub.time += 2
    stub.player.x = 10
    herb()                                                        # (still the same herb, from further on)
    point_at(None, None, None)
    passed = G.PatchwerkForever_Thread_SparkleDB.passed
    assert len(passed) == 1 and passed[1].name == "Silverleaf" and passed[1].x == 5 and passed[1].kind == "herb", list(passed.values())
    assert notes == [("Silverleaf", "h", 1, 5, 0)], notes
    point_at("Battered Chest", "GameObject-0-1-1-1-2843-0", "Cursor_Crosshair_LootAll_64")
    stub.time += 2
    point_at(None, None, None)
    assert len(passed) == 2 and len(notes) == 1, "a chest was given to Routes"
    point_at("Battered Chest", "GameObject-0-1-1-1-2843-0", "Cursor_Crosshair_LootAll_64")
    stub.time += 0.5
    point_at(None, None, None)                                    # a glance: not counted again
    slash("passed")
    text = chat()
    assert "Passed, nearest first (2):" in text and "Silverleaf (Herb), 5 yd" in text and "Battered Chest (Chest), 0 yd" in text, text
    slash("passed route")
    assert routed == [("spot", "Chest: Battered Chest", 10, 0)] and "added to My Route" in chat(), routed
    stub.player.x = 5
    herb()                                                        # gathered after all: off the list
    stub.Fire("UNIT_SPELLCAST_SENT", "player", "Silverleaf", "guid", 2366)
    stub.Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 2366)
    stub.time += 2
    point_at(None, None, None)
    assert len(passed) == 1 and passed[1].name == "Battered Chest", [e.name for e in passed.values()]
    sp.Set("passed", False)
    point_at(*VEIN)
    stub.time += 2
    point_at(None, None, None)
    assert len(passed) == 1, "remembered with Remember What I Pass off"
    sp.Set("passed", True)
    G.UnitPosition = lambda unit: (None, None, None, None)        # (in an instance your place is not known: nothing kept)
    point_at(*VEIN)
    stub.time += 2
    point_at(None, None, None)
    assert len(passed) == 1
    lua.execute("function UnitPosition() local p = STUB.player; return p.x, p.y, 0, p.map end")
    stub.player.x = 0

    step("the lists on the options pages: the ignore list with Remove, what you passed with Add To Route and Forget")
    for name in ("Mailbox", "Anvil"):
        G.PatchwerkForever_Thread_SparkleDB.sparkleIgnored[name] = True
    stub.Rows()
    ignored = [r for r in stub.rows.values() if r.template == "PatchwerkForeverListTemplate" and r.data.name == "Ignored Objects"][0].frame
    lines = list(ignored.lines.values())
    assert lines[0].Text.text == "Anvil" and lines[1].Text.text == "Mailbox" and lines[0].shown and not lines[2].shown
    assert lines[0].buttons[1].text == "Remove" and not lines[0].buttons[2].shown
    lines[0].buttons[1].scripts.OnClick(lines[0].buttons[1])
    assert "\"Anvil\" removed from the ignore list." in chat() and lines[0].Text.text == "Mailbox" and not lines[1].shown
    assert not ignored.Empty.shown and not ignored.Next.shown, "a page of one shows paging"
    for i in range(12):
        G.PatchwerkForever_Thread_SparkleDB.sparkleIgnored["Thing %02d" % i] = True
    ignored.Refresh(ignored)
    assert ignored.Next.shown and ignored.Page.text == "Page 1 of 2", ignored.Page.text
    ignored.Next.scripts.OnClick(ignored.Next)
    assert ignored.Page.text == "Page 2 of 2" and lines[0].Text.text == "Thing 07", lines[0].Text.text
    slash("clear")
    chat()
    ignored.Refresh(ignored)
    assert ignored.Empty.shown and "Nothing is ignored" in ignored.Empty.text and not lines[0].shown
    passed_row = [r for r in stub.rows.values() if r.template == "PatchwerkForeverListTemplate" and r.data.name == "Passed"][0].frame
    first = list(passed_row.lines.values())[0]
    assert first.Text.text == "Battered Chest (Chest), 10 yd" and first.buttons[1].text == "Add To Route" and first.buttons[2].text == "Forget", \
        first.Text.text
    first.buttons[2].scripts.OnClick(first.buttons[2])
    assert "\"Battered Chest\" forgotten." in chat() and len(G.PatchwerkForever_Thread_SparkleDB.passed) == 0
    assert passed_row.Empty.shown

    print("Sparkle (Thread): all passed.")


if __name__ == "__main__":
    main()
