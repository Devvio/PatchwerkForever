-- Routes (Thread): how the route's trail is drawn, shared by the world map and the minimap.
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
-- chosen: the stretch is of a side path you chose yourself (a quest you clicked, a gathering run),
-- whose walking is drawn in a colour of its own to tell it from the main track.
function ns.TrailColour(how, chosen)
	if chosen and (how == 'walk' or not COLOUR_OF[how]) then return ns.RGB(ns.Get('trailChosen')) end
	return ns.RGB(ns.Get(COLOUR_OF[how] or 'trailWalk'))
end

-- A pen for one drawing of the trail. `per` is how many of the map's own units make a pixel on the
-- screen (the world map's canvas is scaled, the minimap is not); `small` is for the minimap, whose
-- pattern is finer; `width` the line's width in pixels on the screen: past the default widths the
-- dashes and gaps grow with it, so a wide dotted or dashed line does not run together into a solid
-- one. pen.at is how far along the trail the pen is, in those units.
function ns.TrailPen(per, small, width)
	local style = ns.Get('trailStyle')
	local dash, gap = 0, 0
	local grow = math.max(1, (width or 0) / (small and 2.5 or 3))
	if style == 'dashes' then
		dash, gap = (small and 6 or 10) * per * grow, (small and 5 or 7) * per * grow
	elseif style == 'dots' then
		gap = (small and 7 or 9) * per * grow
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

-- The part of a line from (ax, ay) to (bx, by) that lies inside the box from (x0, y0) to (x1, y1), or nil.
function ns.ClipBox(ax, ay, bx, by, x0, y0, x1, y1)
	local t0, t1 = 0, 1
	local dx, dy = bx - ax, by - ay
	local function edge(p, q)
		if p == 0 then return q >= 0 end
		local t = q / p
		if p < 0 then
			if t > t1 then return false end
			if t > t0 then t0 = t end
		else
			if t < t0 then return false end
			if t < t1 then t1 = t end
		end
		return true
	end
	if edge(-dx, ax - x0) and edge(dx, x1 - ax) and edge(-dy, ay - y0) and edge(dy, y1 - ay) then
		return ax + dx * t0, ay + dy * t0, ax + dx * t1, ay + dy * t1
	end
	return nil
end

-- The colors and strength of one trail on a map: r, g, b for each piece by how it is gone (a function),
-- and the alpha. trail: the route or a leg ahead; follow: it is the route you are on.
--   the route you are on   its walking in the selected route's color when its destination is one you
--                          selected; drawn fainter while the way to a new destination is searched for
--                          (it still leads to the one before: Route.lua's route.dest)
--   a leg ahead            fainter, in the selected route's color too for a list you selected (Ahead.lua)
function ns.TrailLook(trail, follow, strong, faint)
	if follow then
		local dest = trail.dest
		return dest and dest.chosen, (dest == nil or dest == ns.dest) and strong or faint
	end
	return ns.ahead and ns.ahead.chosen, faint
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
