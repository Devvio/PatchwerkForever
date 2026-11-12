"""Carry what the route planner saved under its old name (Wayfarer) over to the two Thread tools.

    python carry_tracks.py            carry it over (the game must be closed)
    python carry_tracks.py check      say what would be done, and write nothing

A one-off, for the machine these addons are made on. The route planner and the sparkle were one
addon, PatchwerkForever_Wayfarer, with one saved file for each account. They are now
PatchwerkForever_Thread_Routes and PatchwerkForever_Thread_Sparkle, each with a saved file of its own:

    settings whose name begins sparkle, name or look.    -> Sparkle
    sparkleWas, sparkleIgnored                           -> Sparkle
    every other setting, the herb and ore spots, the rest -> Routes

Key and gamepad bindings to the old actions are renamed in the game's bindings files.
The old saved file is left where it is. A new file that is already there is not overwritten.
The game writes its saved files as it closes, so this must be run with the game closed.
"""
import glob
import os
import subprocess
import sys

try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    from lupa import LuaRuntime

WTF = r"G:/Games/World of Warcraft/_forever_/WTF"
OLD = "PatchwerkForever_Wayfarer"
ROUTES = "PatchwerkForever_Thread_Routes"
SPARKLE = "PatchwerkForever_Thread_Sparkle"
BINDINGS = {
    "PATCHWERKFOREVER_WAYFARER_GO": "PATCHWERKFOREVER_THREAD_GO",
    "PATCHWERKFOREVER_WAYFARER_STOP": "PATCHWERKFOREVER_THREAD_STOP",
    "PATCHWERKFOREVER_WAYFARER_IGNORE": "PATCHWERKFOREVER_SPARKLE_IGNORE",
}

SPLIT = r"""
local old = ...
local routes, sparkle = { settings = {} }, { settings = {} }
local function Sparkles(key)
	return key:find('^sparkle') or key:find('^name') or key:find('^look%.')
end
for key, value in pairs(old) do
	if key == 'settings' then
		for name, set in pairs(value) do
			(Sparkles(name) and sparkle or routes).settings[name] = set
		end
	elseif key == 'sparkleWas' or key == 'sparkleIgnored' then
		sparkle[key] = value
	else
		routes[key] = value
	end
end

-- a table written out as the game writes its saved files: sorted, so the same data gives the same file
local function Write(value, indent, out)
	local kind = type(value)
	if kind == 'table' then
		out[#out + 1] = '{\n'
		local n = #value
		for i = 1, n do
			out[#out + 1] = indent .. '\t'
			Write(value[i], indent .. '\t', out)
			out[#out + 1] = ', -- [' .. i .. ']\n'
		end
		local keys = {}
		for key in pairs(value) do
			if not (type(key) == 'number' and key >= 1 and key <= n and key == math.floor(key)) then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == 'number'
		end)
		for _, key in ipairs(keys) do
			out[#out + 1] = indent .. '\t[' .. (type(key) == 'string' and string.format('%q', key) or tostring(key)) .. '] = '
			Write(value[key], indent .. '\t', out)
			out[#out + 1] = ',\n'
		end
		out[#out + 1] = indent .. '}'
	elseif kind == 'string' then
		out[#out + 1] = (string.format('%q', value):gsub('\\\n', '\\n'))
	elseif kind == 'number' then
		out[#out + 1] = (value == math.floor(value) and math.abs(value) < 1e15) and string.format('%d', value) or string.format('%.17g', value)
	else
		out[#out + 1] = tostring(value)
	end
end
local function File(name, value)
	local out = { '\n', name, ' = ' }
	Write(value, '', out)
	out[#out + 1] = '\n'
	return table.concat(out)
end
local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
return File('PatchwerkForever_Thread_RoutesDB', routes), File('PatchwerkForever_Thread_SparkleDB', sparkle),
	Count(routes.settings), Count(sparkle.settings)
"""


def game_running():
    out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq Wow*", "/FO", "CSV", "/NH"], capture_output=True, text=True).stdout
    return any(line.lower().startswith('"wow') for line in out.splitlines())


def main():
    write = "check" not in sys.argv[1:]
    if write and game_running():
        sys.exit("the game is running: close it first (it writes its saved files as it closes)")
    did = False
    for n, account in enumerate(sorted(glob.glob(os.path.join(WTF, "Account", "*"))), 1):
        saved = os.path.join(account, "SavedVariables")
        old = os.path.join(saved, OLD + ".lua")
        label = "account %d" % n                       # (its folder's name is not printed)
        if os.path.exists(old):
            lua = LuaRuntime(unpack_returned_tuples=True)
            lua.execute(open(old, encoding="utf-8").read())
            db = lua.globals()[OLD + "DB"]
            if db is None:
                print("%s: the old saved file holds nothing" % label)
            else:
                routes, sparkle, nr, ns = lua.eval("function(...) %s end" % SPLIT)(db)
                # what was written reads back as Lua, and holds what the old file held
                check = LuaRuntime(unpack_returned_tuples=True)
                check.execute(routes)
                check.execute(sparkle)
                got = check.globals()
                def keys(t):
                    return 0 if t is None else len(list(t.keys()))
                assert keys(got.PatchwerkForever_Thread_RoutesDB.settings) == nr
                assert keys(got.PatchwerkForever_Thread_SparkleDB.settings) == ns
                assert nr + ns == keys(db.settings), "a setting went missing"
                kept = keys(got.PatchwerkForever_Thread_RoutesDB) + keys(got.PatchwerkForever_Thread_SparkleDB) - 2
                assert kept == keys(db) - (1 if db.settings is not None else 0), "something saved went missing"
                for name, text, count in ((ROUTES, routes, nr), (SPARKLE, sparkle, ns)):
                    path = os.path.join(saved, name + ".lua")
                    if os.path.exists(path):
                        print("%s: %s.lua is already there, left alone" % (label, name))
                        continue
                    did = True
                    print("%s: %s.lua %s, %d settings, %d bytes" % (label, name, "written" if write else "would be written",
                                                                   count, len(text.encode("utf-8"))))
                    if write:
                        with open(path, "w", encoding="utf-8", newline="\n") as f:
                            f.write(text)
        # key and gamepad bindings: the account's, and each character's
        for path in glob.glob(os.path.join(account, "bindings-cache.wtf")) + glob.glob(os.path.join(account, "*", "*", "bindings-cache.wtf")):
            data = open(path, "rb").read()
            new = data
            for a, b in BINDINGS.items():
                new = new.replace(a.encode(), b.encode())
            if new != data:
                did = True
                count = sum(data.count(a.encode()) for a in BINDINGS)
                print("%s: %d binding(s) %s in a bindings file" % (label, count, "renamed" if write else "would be renamed"))
                if write:
                    with open(path + ".before-thread", "wb") as f:
                        f.write(data)
                    with open(path, "wb") as f:
                        f.write(new)
    if not did:
        print("nothing to carry over")


if __name__ == "__main__":
    main()
