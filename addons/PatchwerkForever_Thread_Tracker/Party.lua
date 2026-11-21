-- Tracker (Thread): who in your party has a quest, and how far along they are.
--
-- The game tells an addon whether a party member is on a quest (C_QuestLog.IsUnitOnQuest). It does
-- not tell how far along they are. So:
--
--   * Under a quest, the names of the party members on it: for anyone, whatever they run.
--   * How far along, only for party members who run this tracker too. Each tracker tells the
--     others, over the game's own channel for addons, how far its player is on each quest they
--     track: the quest's number and a percentage, to the party only, and only when it changes.
--     That telling is a setting ("Share Progress With Their Trackers"); unticked, nothing is sent
--     and what others send is not shown.
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

-- The line under a quest: "With Thrag 60%, Mokra", or nothing.
function ns.PartyLine(quest)
	if not InParty() then return nil end
	local share = ns.Get('partyShare')
	local names = {}
	for i = 1, Ask(rawget(_G, 'GetNumSubgroupMembers')) or 0 do
		local unit = 'party' .. i
		local name = Short(Ask(UnitName, unit))
		if name then
			local percent = share and theirs[name] and theirs[name][quest]
			if percent then
				names[#names + 1] = ('%s %d%%'):format(name, percent)
			elseif Ask(C_QuestLog.IsUnitOnQuest, unit, quest) then
				names[#names + 1] = name
			end
		end
	end
	if #names == 0 then return nil end
	return 'With ' .. table.concat(names, ', ')
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
