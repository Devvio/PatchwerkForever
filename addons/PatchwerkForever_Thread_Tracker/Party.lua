-- Tracker (Thread): who in your party has a quest, and how far along they are.
--
-- The game tells an addon whether a party member is on a quest (C_QuestLog.IsUnitOnQuest). It does
-- not tell how far along they are. So:
--
--   * Under a quest, the names of the party members on it: for anyone, whatever they run
--     (ns.PartyOn reads who is and who is not; the list of quests asks it once a quest at a drawing).
--   * How far along, only for party members who run this tracker too. Each tracker tells the
--     others, over the game's own channel for addons, how far its player is on each quest they
--     track: the quest's number and a percentage, to the party only, and only when it changes.
--     That telling is a setting ("Share Progress With Their Trackers"); unticked, nothing is sent
--     and what others send is not shown.
--
--   * On a quest that someone in your party is not on, and that the game lets you share
--     (C_QuestLog.IsPushableQuest), a small share mark: pointing at it names who is not on the quest,
--     a click shares it (ns.ShareQuest, Actions.lua). A setting. The game does not say who has done a
--     quest before: a member who has already turned it in is named as not on it too.
--   * The quests someone in your party is on can be listed first (an order of the quest list:
--     Quests.lua). Both of these read what is already known here; nothing more is told to the party.
--
-- A name or an answer about a party member that the game hides in a fight (a "secret" value) counts
-- as not known: that member is then neither on a quest nor off it.
--
-- Not in a raid: only in a party of five.
local ADDON, ns = ...
if not ns.linked then return end

local PREFIX = 'PFTracker'
local WAIT = 3                -- seconds between two tellings, at least
local MOST = 240              -- letters in one message, at most

local theirs = {}             -- [name] = { [quest] = percent }
local sent                    -- what was last told, as one string
local planned = false

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

local function InParty()
	if not Ask(rawget(_G, 'IsInGroup')) then return false end
	return not Ask(rawget(_G, 'IsInRaid'))
end

local function Short(name)
	return type(name) == 'string' and (name:match('^([^%-]+)') or name) or nil
end

-- Who in your party is on a quest, and who is not:
--     { on = { { name =, percent = how far along, where their tracker says }, ... }, off = { name, ... } }
-- or nothing when you are not in a party. A member is on it when their tracker says how far along
-- they are, or when the game says so. A member the game does not answer about (no such function on
-- this client, an error, a hidden answer or name) is in neither list, and one who is offline is not
-- in `off`: a quest cannot be shared with them.
function ns.PartyOn(quest)
	if not InParty() then return nil end
	local share = ns.Get('partyShare')
	local asks = C_QuestLog and C_QuestLog.IsUnitOnQuest
	local info = { on = {}, off = {} }
	for i = 1, Ask(rawget(_G, 'GetNumSubgroupMembers')) or 0 do
		local unit = 'party' .. i
		local name = Ask(UnitName, unit)
		name = ns.Plain(name) and Short(name) or nil
		if name then
			local percent = share and theirs[name] and theirs[name][quest]
			if percent then
				info.on[#info.on + 1] = { name = name, percent = percent }
			elseif type(asks) == 'function' then
				local ok, on = pcall(asks, unit, quest)
				if ok and not ns.Secret(on) then
					if on then
						info.on[#info.on + 1] = { name = name }
					else
						-- (offline only when the game plainly says so)
						local there = Ask(rawget(_G, 'UnitIsConnected'), unit)
						if ns.Secret(there) or there ~= false then info.off[#info.off + 1] = name end
					end
				end
			end
		end
	end
	return info
end

-- The line under a quest: "With Thrag 60%, Mokra", or nothing. info: what ns.PartyOn gave.
function ns.PartyLine(info)
	if not (type(info) == 'table' and #info.on > 0) then return nil end
	local names = {}
	for i, one in ipairs(info.on) do
		names[i] = one.percent and ('%s %d%%'):format(one.name, one.percent) or one.name
	end
	return 'With ' .. table.concat(names, ', ')
end

-- "Thrag is not on this quest.", "Thrag and Mokra are not on this quest."
local function Lacking(names)
	if #names == 1 then return names[1] .. ' is not on this quest.' end
	return table.concat(names, ', ', 1, #names - 1) .. ' and ' .. names[#names] .. ' are not on this quest.'
end

-- The share mark of a quest's row (a block's `share`: Frame.lua), or nothing: there while the
-- setting is on, someone in your party is not on the quest, and the game says it can be shared.
-- info: what ns.PartyOn gave (nothing when you are alone, so no mark then).
function ns.ShareMark(quest, info)
	if not (type(info) == 'table' and #info.off > 0 and ns.Get('shareMark')) then return nil end
	local can = Ask(C_QuestLog.IsPushableQuest, quest)
	if not (ns.Plain(can) and can) then return nil end
	return { title = 'Share Quest', tip = { Lacking(info.off), 'Click to share this quest with your party.' },
		click = function() ns.ShareQuest(quest) end }
end

---------------------------------------------------------------------------
-- Telling the party's trackers how far along you are
---------------------------------------------------------------------------
local function Percent(quest)
	if Ask(C_QuestLog.IsComplete, quest) then return 100 end
	local have, need = 0, 0
	for _, o in ipairs(Ask(C_QuestLog.GetQuestObjectives, quest) or {}) do
		if type(o) == 'table' then
			local n = tonumber(o.numRequired)
			if n and n > 0 then
				need = need + n
				have = have + math.min(n, tonumber(o.numFulfilled) or 0)
			else
				need = need + 1
				have = have + (o.finished and 1 or 0)
			end
		end
	end
	if need == 0 then return 0 end
	return math.floor(have / need * 100)
end

local function Tell()
	planned = false
	if not (ns.Get('on') and ns.Get('party') and ns.Get('partyShare') and InParty()) then return end
	local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
	if type(send) ~= 'function' then return end
	local parts = {}
	for i = 1, Ask(C_QuestLog.GetNumQuestWatches) or 0 do
		local quest = Ask(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
		if quest then parts[#parts + 1] = ('%d:%d'):format(quest, Percent(quest)) end
	end
	local all = table.concat(parts, ',')
	if all == sent then return end
	sent = all
	-- (in pieces that fit a message: the first begins "n", for new; the rest "m", for more)
	local piece, first = '', true
	local function Flush()
		pcall(send, PREFIX, (first and 'n' or 'm') .. piece, 'PARTY')
		piece, first = '', false
	end
	for _, part in ipairs(parts) do
		if #piece + #part + 1 > MOST then Flush() end
		piece = piece == '' and part or (piece .. ',' .. part)
	end
	Flush()
end

local function Soon()
	if planned then return end
	planned = true
	C_Timer.After(WAIT, function() ns.Try('telling the party', Tell) end)
end

ns.Try('the party channel', function()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX) end
end)

ns.Try('listening for CHAT_MSG_ADDON', ns.On, 'CHAT_MSG_ADDON', function(prefix, text, channel, sender)
	if prefix ~= PREFIX or channel ~= 'PARTY' or type(text) ~= 'string' then return end
	local name = Short(sender)
	if not name or name == Short(Ask(UnitName, 'player')) then return end
	local kind, rest = text:sub(1, 1), text:sub(2)
	if kind ~= 'n' and kind ~= 'm' then return end
	if kind == 'n' or not theirs[name] then theirs[name] = {} end
	for quest, percent in rest:gmatch('(%d+):(%d+)') do
		theirs[name][tonumber(quest)] = math.min(100, tonumber(percent))
	end
	ns.Refresh()
end)

for _, event in ipairs({ 'PLAYER_ENTERING_WORLD', 'QUEST_LOG_UPDATE', 'QUEST_WATCH_LIST_CHANGED' }) do
	ns.Try('listening for ' .. event, ns.On, event, Soon)
end
ns.Try('listening for GROUP_ROSTER_UPDATE', ns.On, 'GROUP_ROSTER_UPDATE', function()
	sent = nil                -- (someone new may be listening: told again)
	if not InParty() then theirs = {} end
	Soon()
end)
