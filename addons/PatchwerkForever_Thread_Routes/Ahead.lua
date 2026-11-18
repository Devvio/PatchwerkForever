-- Thread (Routes): the way on, past the step you are on.
--
-- A guide's steps come one after another, and the ones to come are known (the base's guides service). The way from
-- each to the next is found here ahead of time, behind the search for your own route, and kept:
--   ns.ahead = { legs = { route, route, ... }, chosen = true for the steps of a list you selected }
-- drawn fainter by the world map and the minimap (a selected list's in the selected route's color)
-- The first of them does a second job. When you finish a step, the way to the next has usually been
-- found already, from where that step was: it is handed over (Take) and the trail changes at once,
-- with no search to wait for.
--
-- A step that has you fly is not searched from: the guide names the flight, so a straight line in the
-- flights' colour stands for it. Nothing leads on from a step that carries you off (a hearthstone).
local ADDON, ns = ...
if not ns.linked then return end

local Ahead = {}
ns.Ahead = Ahead

local SAME = 5            -- yards within which two places are the same place
local NEAR = 30           -- yards from where a way begins that you must be for it to be handed over
local floor = math.floor

local found = {}          -- [leg] = { route = the way, or false for none; flight = true for a line that stands for a flight }
local order = {}          -- the legs wanted now, nearest first
local chainKey
local chosen              -- the steps are of a list you selected

local function Leg(a, b)
	return ('%d:%d:%d>%d:%d:%d'):format(a.map, floor(a.x), floor(a.y), b.map, floor(b.x), floor(b.y))
end

local function Publish()
	local legs = {}
	for _, leg in ipairs(order) do
		local have = found[leg]
		if have and have.route then legs[#legs + 1] = have.route end
	end
	ns.ahead = #legs > 0 and { legs = legs, chosen = chosen } or nil
	if ns.RouteChanged then ns.RouteChanged() end
end

-- chain: the place you are going to now, then the places of the steps after it, in order; each
-- { map =, x =, y =, kind = }. One with no map breaks the chain. An empty chain shows nothing.
-- isChosen: the steps are of a list you selected.
function Ahead.Set(chain, isChosen)
	chosen = isChosen and true or nil
	local parts = { chosen and 'chosen' or 'main' }
	for i, at in ipairs(chain) do
		parts[i + 1] = at.map and ('%d:%d:%d:%s'):format(at.map, floor(at.x), floor(at.y), tostring(at.kind)) or 'none'
	end
	local key = table.concat(parts, '|')
	if key == chainKey then return end
	chainKey = key
	local wanted = {}
	order = {}
	for i = 1, #chain - 1 do
		local a, b = chain[i], chain[i + 1]
		if a.map and b.map and not ns.Base.Guides.AWAY[a.kind] then
			-- (the way to a step that has you fly is found on foot, as it will be asked for: Sources.lua)
			local onFoot = b.kind == 'fly'
			local leg = Leg(a, b) .. (onFoot and ' on foot' or '')
			if not wanted[leg] then
				wanted[leg] = true
				order[#order + 1] = leg
			end
			if not found[leg] then
				if a.kind == 'fly' then
					-- (a flight to another continent is not drawn: a straight line across two maps means nothing)
					found[leg] = { flight = true, route = a.map == b.map and {
						map = a.map, at = 1, parts = {}, points = { { a.x, a.y, 'walk' }, { b.x, b.y, 'fly' } },
					} or false }
				else
					found[leg] = {}
					ns.SearchLater({ map = a.map, x = a.x, y = a.y }, { map = b.map, x = b.x, y = b.y }, { walkOnly = onFoot },
						function(route)
							if found[leg] then
								found[leg].route = route or false
								Publish()
							end
						end,
						function() return found[leg] ~= nil end)
				end
			end
		end
	end
	for leg in pairs(found) do
		if not wanted[leg] then found[leg] = nil end
	end
	Publish()
end

-- The way to `dest`, if it was found ahead of time and you are standing where it begins. It is taken
-- out of what is drawn ahead: it becomes your route.
function Ahead.Take(dest)
	local leg = order[1]
	local have = leg and found[leg]
	local route = have and not have.flight and have.route
	if not (route and route.to) then return nil end
	local to = route.to
	if to.map ~= dest.map or (to.x - dest.x) ^ 2 + (to.y - dest.y) ^ 2 > SAME * SAME then return nil end
	local px, py, map = ns.Place()
	local first = route.points[1]
	if not px or map ~= route.map or (px - first[1]) ^ 2 + (py - first[2]) ^ 2 > NEAR * NEAR then return nil end
	found[leg] = nil
	table.remove(order, 1)
	chainKey = nil
	Publish()
	route.at = 1
	return route
end
