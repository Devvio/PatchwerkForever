-- Thread (Routes): how the route's trail is drawn, shared by the world map and the minimap.
--
-- The trail's colours, its style (a solid line, dashes or dots) and whether the dashes or dots flow
-- along the route come from the settings. The two maps hand each straight piece of the route to
-- ns.Stroke, which cuts it into the dashes or dots of the style and keeps the pattern running on
-- from one piece into the next.
local ADDON, ns = ...
if not ns.linked then return end

local sqrt, floor, max, min = math.sqrt, math.floor, math.max, math.min
local COLOUR_OF = { walk = 'trailWalk', link = 'trailLink', fly = 'trailFly', ride = 'trailRide' }
local FLOW = 30               -- pixels a second the pattern flows at 100 %

ns.MEDIA = 'Interface\\AddOns\\' .. ADDON .. '\\Media\\'

-- The colour of a stretch reached by walking ('walk'), by a tunnel, lift or drop ('link'), by flying ('fly')
-- or aboard a boat or zeppelin ('ride'). (A 'gap' is not drawn at all: the two maps leave it out.)
function ns.TrailColour(how)
	return ns.RGB(ns.Get(COLOUR_OF[how] or 'trailWalk'))
end

-- A pen for one drawing of the trail. `per` is how many of the map's own units make a pixel on the
-- screen (the world map's canvas is scaled, the minimap is not); `small` is for the minimap, whose
-- pattern is finer. pen.at is how far along the trail the pen is, in those units.
function ns.TrailPen(per, small)
	local style = ns.Get('trailStyle')
	local dash, gap = 0, 0
	if style == 'dashes' then
		dash, gap = (small and 6 or 10) * per, (small and 5 or 7) * per
	elseif style == 'dots' then
		gap = (small and 7 or 9) * per
	else
		style = 'solid'
	end
	local at = 0
	if style ~= 'solid' and ns.Get('trailMoving') then
		local period = dash + gap
		local flowed = GetTime() * FLOW * per * (ns.Get('trailSpeed') or 100) / 100
		at = -(flowed % period)                    -- the pattern starts this far in: so it flows forward
	end
	return { style = style, dash = dash, gap = gap, at = at }
end

-- Whether the trail has to be drawn again and again (its pattern is flowing).
function ns.TrailMoves()
	return ns.Get('trailMoving') and ns.Get('trailStyle') ~= 'solid'
end

-- Draws the straight piece from (ax, ay) to (bx, by) with the pen: line(x1, y1, x2, y2) is called for a
-- solid piece or each dash, dot(x, y) for each dot.
function ns.Stroke(pen, ax, ay, bx, by, line, dot)
	if pen.style == 'solid' then
		line(ax, ay, bx, by)
		return
	end
	local dx, dy = bx - ax, by - ay
	local length = sqrt(dx * dx + dy * dy)
	if length <= 0 then return end
	local ux, uy = dx / length, dy / length
	local period = pen.dash + pen.gap
	local start = pen.at
	local from = floor(start / period) * period
	while from < start + length do
		if pen.style == 'dots' then
			if from >= start then
				dot(ax + ux * (from - start), ay + uy * (from - start))
			end
		else
			local d0, d1 = max(from, start), min(from + pen.dash, start + length)
			if d1 > d0 then
				line(ax + ux * (d0 - start), ay + uy * (d0 - start), ax + ux * (d1 - start), ay + uy * (d1 - start))
			end
		end
		from = from + period
	end
	pen.at = start + length
end
