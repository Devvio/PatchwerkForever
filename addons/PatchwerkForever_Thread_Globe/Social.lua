-- Globe (Thread): where the people you know are.
--
-- The members of your guild and your friends who are online, counted by the zone each is in: one mark
-- a zone, just over where its name is written, with the number of people there. Pointing at it lists
-- them, guild members and friends apart, each name in its class's colour where the game says the class,
-- with the level. A click turns and fits the globe to that zone.
--
-- The game does not say where such a person stands, only the name of the zone they are in, as text:
--   guild members   the guild's list of members (C_Club: the guild is the club C_Club.GetGuildClubId
--                   names), each member's `zone`. The game sends that list when asked for it
--                   (C_GuildInfo.GuildRoster), and listens at most once in ten seconds: it is asked
--                   every ROSTER seconds, and only while the globe is open and Show Guild Members is on.
--   friends         the friends list (C_FriendList), each friend's `area`; and the Battle.net friends
--                   who are in this game now (C_BattleNet: `areaName` of the game they are in, which
--                   the friends list itself shows for them).
-- The text is matched to the globe's zones by name. A smaller place's name (a town, a camp: ns.AREAS)
-- counts as the zone it lies in. A name that matches nothing (a dungeon's, or a zone of another game)
-- is left out. You yourself and people who are offline are not counted, and someone who is both a guild
-- member and a friend is counted once, with the guild.
local ADDON, ns = ...
if not (ns.linked and ns.Marks) then return end
local G, Marks = ns.G, ns.Marks

local min, floor = math.min, math.floor
local ROSTER = 15                     -- seconds between two asks for the guild's list (the game allows one in ten)
local SETTLE = 2                      -- the marks are made again at most this often (seconds), however often the game says a list changed
local ABOVE = 13                      -- a mark is drawn this far above the zone's name (points; less than Marks.lua's NEAR)
local MOST_NAMES = 12                 -- a mark lists this many guild members, and this many friends, at most
local MOST_FRIENDS = 400              -- no more of a list than this is read
local KEPT = 300                      -- names matched before that are remembered
local GUILD, FRIEND, BOTH = { 0.35, 1, 0.35 }, { 0.51, 0.77, 1 }, { 1, 0.86, 0.45 }

local club = rawget(_G, 'C_Club') or {}
local guild = rawget(_G, 'C_GuildInfo') or {}
local friends = rawget(_G, 'C_FriendList') or {}
local bnet = rawget(_G, 'C_BattleNet') or {}
local creature = rawget(_G, 'C_CreatureInfo') or {}

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	return nil
end

-- A value the game lets an addon read (it may hand over one that can only be passed on).
local function Plain(v)
	return v ~= nil and not (issecretvalue and issecretvalue(v))
end

local function Text(v)
	return Plain(v) and type(v) == 'string' and v ~= '' and v or nil
end

-- One of the game's own words, where this client has it.
local function Word(global, ours)
	local text = rawget(_G, global)
	return type(text) == 'string' and text ~= '' and text or ours
end

---------------------------------------------------------------------------
-- A zone, by its name
---------------------------------------------------------------------------
local byName                          -- a zone's name, in small letters: { c, zone }
local isArea                          -- a smaller place's name, in small letters: true
local byArea                          -- the same: { c, zone, n (chunks) }, worked out when first needed
local found, kept = {}, 0             -- names looked up before: { c, zone }, or false for one that matched nothing

local function Names()
	byName, isArea = {}, {}
	for map, data in pairs(ns.ZONES or {}) do
		local c = G.continents[map]
		if c then
			for _, zone in ipairs(data.zones) do
				local hit = { c = c, zone = zone }
				byName[zone.name:lower()] = hit
				byName[G.ZoneName(zone):lower()] = hit
			end
		end
	end
	for _, name in pairs(ns.AREAS or {}) do
		if type(name) == 'string' then isArea[name:lower()] = true end
	end
end

-- A row of chunks as runs: { count, value, count, value, ... }. (Globe.lua reads a row into such a
-- list when it is first asked about; one still in text is read here, and not kept.)
local function Runs(row)
	if type(row) == 'table' then return row end
	local read = {}
	if type(row) == 'string' then
		for count, value in row:gmatch('(%d+),(%d+)') do
			read[#read + 1] = tonumber(count)
			read[#read + 1] = tonumber(value)
		end
	end
	return read
end

-- The zone each smaller place lies in: Zones.lua says for every chunk of land which zone it is of and
-- which smaller place, in two lists of rows that are walked side by side here. A place that reaches
-- into two zones is of the one it has most chunks in; a name two places share is the larger's. This
-- reads the whole of both lists, once, the first time a name is such a place's and not a zone's.
local function Areas()
	byArea = {}
	local names = ns.AREAS or {}
	for map, data in pairs(ns.ZONES or {}) do
		local c = G.continents[map]
		if c and type(data.areas) == 'table' then
			local counts = {}                       -- by area: { zone (its place in data.zones) = chunks }
			for row = 1, #data.rows do
				local zs, as = Runs(data.rows[row]), Runs(data.areas[row])
				local zi, zleft = 1, zs[1] or 0
				for ai = 1, #as, 2 do
					local left, area = as[ai], as[ai + 1]
					while left > 0 and zi <= #zs do
						local n = min(left, zleft)
						local zone = zs[zi + 1]
						if n > 0 and area > 0 and zone > 0 and names[area] then
							local t = counts[area]
							if not t then
								t = {}
								counts[area] = t
							end
							t[zone] = (t[zone] or 0) + n
						end
						left, zleft = left - n, zleft - n
						if zleft <= 0 then
							zi = zi + 2
							zleft = zs[zi] or 0
						end
					end
				end
			end
			for area, zonesOf in pairs(counts) do
				local best, most
				for zone, n in pairs(zonesOf) do
					if not most or n > most then best, most = zone, n end
				end
				local name = type(names[area]) == 'string' and names[area]:lower()
				local zone = data.zones[best]
				if name and zone and (not byArea[name] or byArea[name].n < most) then
					byArea[name] = { c = c, zone = zone, n = most }
				end
			end
		end
	end
end

-- The zone a name is of: { c, zone }, or nil.
local function Resolve(text)
	local name = text:lower()
	local hit = found[name]
	if hit == nil then
		if not byName then Names() end
		hit = byName[name]
		if not hit and isArea[name] then
			if not byArea then Areas() end
			hit = byArea[name]
		end
		-- (names that match nothing are remembered too, but not without end)
		if kept >= KEPT then found, kept = {}, 0 end
		found[name], kept = hit or false, kept + 1
	end
	return hit or nil
end

---------------------------------------------------------------------------
-- The people
---------------------------------------------------------------------------
local function InGuild()
	local fn = rawget(_G, 'IsInGuild')
	if type(fn) ~= 'function' then return true end     -- (the guild's club will say)
	local on = Ask(fn)
	return Plain(on) and on and true or false
end

-- A member's presence that is in the world: online, away or busy (not offline, and not on the phone).
local function InWorld(presence)
	local e = Enum and Enum.ClubMemberPresence or {}
	return presence == (e.Online or 1) or presence == (e.Away or 4) or presence == (e.Busy or 5)
end

local function ClassOf(id)
	if not (Plain(id) and type(id) == 'number') then return nil end
	local info = Ask(creature.GetClassInfo, id)
	return Plain(info) and type(info) == 'table' and Text(info.classFile) or nil
end

-- A class by its name as the friends list gives it ('Mage'): the game's own word for it ('MAGE').
local tokens
local function ClassNamed(name)
	if not name then return nil end
	if not tokens then
		tokens = {}
		for _, global in ipairs({ 'LOCALIZED_CLASS_NAMES_MALE', 'LOCALIZED_CLASS_NAMES_FEMALE' }) do
			local list = rawget(_G, global)
			for token, word in pairs(type(list) == 'table' and list or {}) do
				if type(word) == 'string' and type(token) == 'string' then tokens[word] = token end
			end
		end
	end
	return tokens[name] or (name:upper():gsub('%s', ''))
end

-- Everyone to be shown, by zone: a list of { c, zone, guild = { who, ... }, friend = { who, ... } },
-- who = { name, level, class }.
local function Gather()
	local list, spots = {}, {}
	local seenGuid, seenName = {}, {}
	local myGuid = Ask(rawget(_G, 'UnitGUID'), 'player')
	local myName = Text((Ask(rawget(_G, 'UnitName'), 'player')))
	myName = myName and myName:lower()
	local function add(kind, name, text, level, class, guid)
		if not (name and text) then return end
		local short = name:match('^([^%-]+)') or name       -- (a name may carry its realm)
		local lower = short:lower()
		local id = Text(guid)
		if id and (id == myGuid or seenGuid[id]) then return end
		if not id and lower == myName then return end
		-- (the same name twice is the same person, unless the game says they are two)
		local before = seenName[lower]
		if before and (before == true or not id) then return end
		seenName[lower] = id or true
		if id then seenGuid[id] = true end
		local hit = Resolve(text)
		if not hit then return end
		local at = spots[hit.zone]
		if not at then
			at = { c = hit.c, zone = hit.zone, guild = {}, friend = {} }
			spots[hit.zone] = at
			list[#list + 1] = at
		end
		local who = at[kind]
		who[#who + 1] = { name = short, class = class,
			level = Plain(level) and type(level) == 'number' and level > 0 and floor(level) or nil }
	end

	if ns.Get('globeGuild') and InGuild() then
		local id = Ask(club.GetGuildClubId)
		local members = Plain(id) and Ask(club.GetClubMembers, id)
		for _, member in ipairs(Plain(members) and type(members) == 'table' and members or {}) do
			local info = Ask(club.GetMemberInfo, id, member)
			if Plain(info) and type(info) == 'table' and Plain(info.isSelf) and not info.isSelf
				and Plain(info.presence) and InWorld(info.presence) then
				add('guild', Text(info.name), Text(info.zone), info.level, ClassOf(info.classID), info.guid)
			end
		end
	end
	if ns.Get('globeFriends') then
		local count = Ask(friends.GetNumFriends)
		for i = 1, Plain(count) and type(count) == 'number' and min(count, MOST_FRIENDS) or 0 do
			local info = Ask(friends.GetFriendInfoByIndex, i)
			if Plain(info) and type(info) == 'table' and Plain(info.connected) and info.connected then
				add('friend', Text(info.name), Text(info.area), info.level, ClassNamed(Text(info.className)), info.guid)
			end
		end
		-- (Battle.net friends: those in this game now, as the friends list itself tells them from the
		-- ones in another of the company's games; with no way to tell, none are shown)
		local wow, project = rawget(_G, 'BNET_CLIENT_WOW') or 'WoW', rawget(_G, 'WOW_PROJECT_ID')
		local total = project ~= nil and Ask(rawget(_G, 'BNGetNumFriends')) or nil
		for i = 1, Plain(total) and type(total) == 'number' and min(total, MOST_FRIENDS) or 0 do
			local account = Ask(bnet.GetFriendAccountInfo, i)
			local game = Plain(account) and type(account) == 'table' and account.gameAccountInfo
			if Plain(game) and type(game) == 'table' and Plain(game.isOnline) and game.isOnline
				and Plain(game.clientProgram) and game.clientProgram == wow
				and Plain(game.wowProjectID) and game.wowProjectID == project then
				add('friend', Text(game.characterName), Text(game.areaName), game.characterLevel, Text(game.classFilename), game.playerGuid)
			end
		end
	end
	return list
end

---------------------------------------------------------------------------
-- The marks
---------------------------------------------------------------------------
-- The tooltip's lines for one zone: the guild's members, then friends, each under its heading.
local function Lines(at)
	local colours = rawget(_G, 'RAID_CLASS_COLORS')
	local lines = {}
	local function Part(v) return floor(math.max(0, min(1, v)) * 255 + 0.5) end
	local function Group(who, heading)
		if #who == 0 then return end
		table.sort(who, function(a, b) return a.name < b.name end)
		lines[#lines + 1] = ('|cffffd100%s (%d)|r'):format(heading, #who)
		for i = 1, min(#who, MOST_NAMES) do
			local one = who[i]
			local c = one.class and type(colours) == 'table' and colours[one.class]
			local name = one.name
			if type(c) == 'table' and type(c.r) == 'number' and type(c.g) == 'number' and type(c.b) == 'number' then
				name = ('|cff%02x%02x%02x%s|r'):format(Part(c.r), Part(c.g), Part(c.b), name)
			end
			lines[#lines + 1] = one.level and ('%s, Level %d'):format(name, one.level) or name
		end
		if #who > MOST_NAMES then lines[#lines + 1] = ('and %d more'):format(#who - MOST_NAMES) end
	end
	Group(at.guild, Word('GUILD', 'Guild'))
	Group(at.friend, Word('FRIENDS', 'Friends'))
	lines[#lines + 1] = '|cff66c2ffClick to fit this zone in the picture.|r'
	return lines
end

local function Fit(_, m)
	G.Outline(m.c, m.zone)
	G.GlideTo(m.zone.mid, G.FitRadius(m.zone.reach))
end

local filledAt, pending = 0, false
Marks.Source('social', {
	order = 76,
	every = 30,                      -- (should the game not say that a list changed)
	Shown = function() return (ns.Get('globeGuild') or ns.Get('globeFriends')) and true or false end,
	Fill = function(mark)
		filledAt, pending = GetTime(), false
		for _, at in ipairs(Gather()) do
			local name = G.ZoneName(at.zone)
			G.Outline(at.c, at.zone)                -- (the zone's middle, for one whose name is not written)
			local guilded, befriended = #at.guild, #at.friend
			-- (its place is that of the zone's name; drawn a little above it, so the name can still be read,
			-- yet near enough that the cross of keys and gamepad, turned to that place, is on the mark)
			mark({ p = G.NameAt(name) or at.zone.mid, dy = ABOVE, icon = Marks.Icon('badge'), size = 18,
				tint = (befriended == 0 and GUILD) or (guilded == 0 and FRIEND) or BOTH,
				text = tostring(guilded + befriended), rank = 46, name = name, lines = Lines(at),
				guild = guilded, friends = befriended, c = at.c, zone = at.zone, click = Fit })
		end
	end,
})

-- The game says a list changed: the marks are made again, a moment later (it may say so many times over).
local function Stale()
	local window = G.Frames()
	if window and window:IsShown() and (ns.Get('globeGuild') or ns.Get('globeFriends')) then pending = true end
end
for _, event in ipairs({ 'GUILD_ROSTER_UPDATE', 'PLAYER_GUILD_UPDATE', 'FRIENDLIST_UPDATE', 'BN_FRIEND_INFO_CHANGED',
	'BN_FRIEND_ACCOUNT_ONLINE', 'BN_FRIEND_ACCOUNT_OFFLINE' }) do
	Marks.On(event, Stale)
end

-- The lists are asked for while the globe is open (this runs only then) and their setting is on.
local askedAt, since = -ROSTER, 0
ns.GlobeOn('frame', function(elapsed)
	since = since + (elapsed or 0)
	if since < 0.5 then return end
	since = 0
	local now = GetTime()
	local wantGuild, wantFriends = ns.Get('globeGuild') and InGuild(), ns.Get('globeFriends')
	if (wantGuild or wantFriends) and now - askedAt >= ROSTER then
		askedAt = now
		if wantGuild then Ask(guild.GuildRoster) end
		if wantFriends then Ask(friends.ShowFriends) end
	end
	if pending and now - filledAt >= SETTLE then
		pending = false
		Marks.Changed('social')
	end
end)

-- (what the lists said while the globe was closed was not followed)
ns.GlobeOn('show', function() Marks.Changed('social') end)
ns.OnSetting(function(key)
	if key == 'globeGuild' or key == 'globeFriends' then Marks.Changed('social') end
end)

-- For the checks outside the game.
function ns.SocialState()
	return { pending = pending, askedAt = askedAt, areasRead = byArea ~= nil, kept = kept }
end
