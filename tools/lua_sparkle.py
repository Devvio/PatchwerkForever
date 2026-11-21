"""Run Sparkle (Thread) outside the game, on the base, against the stand-in for the game (wowstub.lua)
with what it needs added.

    python lua_sparkle.py

Plays what lua_shell.py does not: the options pages (Sparkle: Appearance, the settings that depend on a
tick box, the percent sliders, the title-case lists), the preview that follows the settings while the
options are open and stands beside them, the fade area's oval staying after the last change and after
the options close, the name above the game's icon, the ignore list (the key binding as a toggle, undo
taking back the last ignore, an object targeted long ago not used, clearing asked first), /sparkle and
its status and debug lines, and the game's two settings put back at logout and turned on again when
the game turned one off. It fails loudly on any Lua error.

What this proves: the addon's own code runs and does sensible things with the stand-in's answers.
What it cannot prove: where the preview lands beside the real options window, that the game's icon
frame is where the name is hung, or that a setting changed at logout is saved. That is for the game.
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
    assert len(percent) == 16 and all(k.endswith((".bright", ".speed")) or k in behind or k == "wispSpeed" for k in percent), percent
    for d in defs:
        for choice in (d.choices.values() if d.choices else []):
            label = choice[2]
            for word in label.replace("(", " ").replace(")", " ").split():
                assert word[0].isupper() or word in ("of",), "not in title case: " + label
    assert "Ignore / Unignore Sparkle Object" in by_key["sparkle"].desc or "Ignore / Unignore Sparkle Object" in \
        [d.desc for d in defs if d.name == "Clear Ignore List"][0]
    assert G.BINDING_NAME_PATCHWERKFOREVER_SPARKLE_IGNORE == "Ignore / Unignore Sparkle Object"
    buttons = {b.name: b for b in stub.buttons.values()}
    assert "Preview Name" in buttons and buttons["Preview Name"].page == "Sparkle: Names", list(buttons)
    bindings = open(os.path.join(ADDONS, SPARKLE, "Bindings.xml"), encoding="utf-8").read()
    assert 'category="BINDING_CATEGORY_PatchwerkForever"' in bindings and "ADDONS" not in bindings

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

    step("the preview: a real object's name, hung from a stand-in nameplate at Vertical Offset")
    buttons["Preview Name"].click()
    t = [m for m in marks() if not same(m, s)][0]
    assert t.shown and t.name.text == "Peacebloom", t.name.text
    stand = t.anchor
    assert not same(stand, G.UIParent) and same(t.name.to, stand), "the preview is not hung like a real sparkle"
    previews = [b for b in stub.buttons.values() if b.name == "Preview Sparkle"]
    previews[-1].click()
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

    print("Sparkle (Thread): all passed.")


if __name__ == "__main__":
    main()
