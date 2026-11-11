"""Carry what Wayfinder Forever saved over to its new name, Patchwerk Forever: Wayfarer.

    python carry_saved.py

The addon was renamed, and the game keeps an addon's saved data in a file named after its folder, so
the renamed addon would start with nothing: no settings, no herb and ore spots. For every account on
this install, this copies SavedVariables/WayfinderForever.lua to PatchwerkForever_Wayfarer.lua with the
table inside renamed. The old file is left where it is.

The game writes an addon's saved data when you log out or reload, so the copy is only as fresh as the
last of those: run it once more after closing the game to have everything. A copy the game has since
written over (the renamed addon has been played) is never replaced.
"""
import glob
import os
import subprocess

WTF = r"G:/Games/World of Warcraft/_forever_/WTF/Account"
OLD, NEW = "WayfinderForever", "PatchwerkForever_Wayfarer"
MARK = "-- carried over from %s.lua by carry_saved.py\n" % OLD


def running():
    try:
        return "wow.exe" in subprocess.run(["tasklist"], capture_output=True, text=True).stdout.lower()
    except OSError:
        return False


def main():
    found = glob.glob(os.path.join(WTF, "*", "SavedVariables", OLD + ".lua"))
    if not found:
        print("no saved data under the old name: nothing to carry over.")
        return
    for old in found:
        new = os.path.join(os.path.dirname(old), NEW + ".lua")
        account = os.path.basename(os.path.dirname(os.path.dirname(old)))
        if os.path.exists(new) and not open(new, encoding="utf-8").read().startswith(MARK):
            print("%s: the renamed addon has saved data of its own already; left alone." % account)
            continue
        text = open(old, encoding="utf-8").read()
        if OLD + "DB" not in text:
            print("%s: the old file holds no %sDB; left alone." % (account, OLD))
            continue
        with open(new, "w", encoding="utf-8", newline="\n") as f:
            f.write(MARK + text.replace(OLD + "DB", NEW + "DB"))
        print("%s: carried over (%d bytes)." % (account, len(text)))
    if running():
        print("The game is running: what it has not saved yet is not in the copy. Run this again after closing the game.")


if __name__ == "__main__":
    main()
