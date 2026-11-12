local _, ns = ...;
local R = ns.Route;
if not R then return end;
local M, MelloUI = R.M, R.MelloUI;
local Dist = R.Dist;
if not ( M.Trip and M.TripState and M.TripDraw and M.OnMap and M.WorldYards ) then return end;
---------------------------------------------------------------
-- Trips: the next guide steps, and a run through tracked quests
---------------------------------------------------------------
-- Route can lead a trip: stops in a given order, the first one the
-- destination, the ways between the later ones found by its own
-- search and drawn fainter, each stop numbered (M:Trip, made for
-- MelloUI's Dungeon Info). Two uses of it here, one at a time since
-- Route holds one trip:
--
--   * Guide preview: while a guide addon is followed, the current
--     step's place and the next few steps' as a trip, so the trail
--     runs on past the current step. The current step is Route's
--     destination already (the guide's pin), so the trip is made
--     without setting one: M.SetDestinationTo stands aside for the
--     length of that one call.
--   * Quest run: the tracked quests' next places (an open
--     objective's nearest place, a finished quest's turn-in) put in
--     a short order and led as a trip; made again as objectives
--     finish. Started and stopped by hand.
--
-- Route draws a trip on MelloUI's own seamless map only; the game's
-- world map gets it here, with Route's own painter (M.TripDraw), and
-- the minimap with lines of our own on Route's minimap layer.

local Trips = {};
R.Trips = Trips;

local run = { active = false };

---------------------------------------------------------------
-- Places
---------------------------------------------------------------
local vector;

-- a place on a map (0..1) as a trip's stop: the client's world coordinates
local function StopOnMap(mapID, x, y)
	if not ( mapID and x and y and C_Map.GetWorldPosFromMapPos and CreateVector2D ) then return end;
	vector = vector or CreateVector2D(0, 0);
	vector.x, vector.y = x, y;
	local ok, wcont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, vector);
	if not ( ok and wcont and type(pos) == 'table' and pos.x and pos.y ) then return end;
	return { wcont = wcont, wx = pos.x, wy = pos.y };
end

-- a place in Route's yards as a trip's stop
local function StopAtYards(cont, x, y)
	local fx, fy = M.OnMap(cont, cont, x, y);
	return fx and StopOnMap(cont, fx, fy);
end

-- the trip Route holds, when it is one of ours of that kind
local function Mine(kind)
	local trip = M:TripState();
	return type(trip) == 'table' and trip.patchwerk == kind and trip or nil;
end

---------------------------------------------------------------
-- Guide preview
---------------------------------------------------------------
-- the followed guide's current step: its map and place on it (0..1)
local function GuideSpot()
	local active = type(M.Guide) == 'table' and M.Guide.active;
	if ( type(active) == 'table' and active.runs and active.mapID and active.x and active.y and M.db.followGuide ~= false ) then
		-- MelloUI 2.1.44 has a switch for each guide addon on its Addons page (Use with MelloUI);
		-- one switched off there is not followed by Route, so its next steps are not shown either
		local allowed = M.Guide.Allowed;
		if ( type(allowed) == 'function' ) then
			local ok, yes = pcall(allowed, active);
			if ( ok and not yes ) then
				return;
			end
		end
		return active.mapID, active.x, active.y;
	end
end

-- RestedXP keeps its guide's steps as a list, each with the places
-- its lines point at (zone, x, y in 0..100), read here as it reads
-- them for its own map pins. Steps done or skipped and steps with
-- no place are passed over.
local function NextSteps(count, mapID, x, y)
	local rxp = rawget(_G, 'RXP');
	local guide = type(rxp) == 'table' and rxp.currentGuide;
	local steps = type(guide) == 'table' and guide.steps;
	if ( type(steps) ~= 'table' or type(rxp.GetGuideProgress) ~= 'function' ) then
		return {};
	end
	local at = tonumber(( rxp.GetGuideProgress() ));
	if not at then
		return {};
	end
	local skipped = type(RXPCData) == 'table' and type(RXPCData.stepSkip) == 'table' and RXPCData.stepSkip or {};
	local out, lastMap, lastX, lastY = {}, mapID, x, y;
	for i = at + 1, math.min(#steps, at + 15) do
		local step = steps[i];
		if ( type(step) == 'table' and type(step.elements) == 'table' and not step.completed and not skipped[i] ) then
			for _, element in ipairs(step.elements) do
				local zone = type(element) == 'table' and not element.skip and not element.hidden and element.zone;
				if ( type(zone) == 'string' and type(rxp.GetMapId) == 'function' ) then
					zone = rxp.GetMapId(zone);
				end
				zone = tonumber(zone);
				local ex, ey = zone and tonumber(element.x), zone and tonumber(element.y);
				if ( zone and ex and ey ) then
					ex, ey = ex / 100, ey / 100;
					-- (the same spot again -- a quest handed in and the next taken -- is one stop)
					if not ( zone == lastMap and math.abs(ex - lastX) < 0.004 and math.abs(ey - lastY) < 0.004 ) then
						out[#out + 1] = { mapID = zone, x = ex, y = ey };
						lastMap, lastX, lastY = zone, ex, ey;
					end
					break;
				end
			end
		end
		if ( #out >= count ) then
			break;
		end
	end
	return out;
end

-- our preview let go without ending the route it rides on (M:TripEnd would clear it)
local function DropPreview()
	local trip = rawget(M, 'trip');
	if ( type(trip) == 'table' and trip.patchwerk == 'preview' ) then
		for _, job in pairs(type(trip.jobs) == 'table' and trip.jobs or {}) do
			job.stale = true;
		end
		M.trip = nil;
		M.tripBeat = ( tonumber(M.tripBeat) or 0 ) + 1;
		MelloUI:Fire('route:trip')
	end
end

local function PreviewWanted()
	return R:Active() and R:Get('guidePreview') and not run.active and GuideSpot() ~= nil;
end

local function BuildPreview()
	if not PreviewWanted() then
		return DropPreview();
	end
	local _, dest = M:CurrentRoute();
	local held = M:TripState();
	if ( type(held) == 'table' and held.patchwerk ~= 'preview' ) then
		return;   -- (another trip: Dungeon Info's, or a quest run)
	end
	if not dest then
		return DropPreview();
	end
	local mapID, x, y = GuideSpot();
	local spots = NextSteps(tonumber(R:Get('previewSteps')) or 3, mapID, x, y);
	local sig = ('%s:%.3f:%.3f'):format(mapID, x, y);
	local stops = { StopOnMap(mapID, x, y) };
	for _, spot in ipairs(spots) do
		sig = ('%s|%s:%.3f:%.3f'):format(sig, spot.mapID, spot.x, spot.y);
		stops[#stops + 1] = StopOnMap(spot.mapID, spot.x, spot.y);
	end
	if ( #spots == 0 or #stops ~= #spots + 1 ) then
		return DropPreview();
	end
	if ( held and held.sig == sig ) then
		return;
	end
	-- The trip made on the destination Route has: its own setter stands
	-- aside for this one call, so no pin is laid and nothing is planned.
	local first, setter = stops[1], M.SetDestinationTo;
	M.SetDestinationTo = function() return true end;
	local ok, led = pcall(M.Trip, M, stops);
	M.SetDestinationTo = setter;
	local trip = rawget(M, 'trip');
	if ( type(trip) == 'table' ) then
		trip.patchwerk, trip.sig = 'preview', sig;
		if not ( ok and led and trip.stops and trip.stops[1] == first ) then
			DropPreview()
		end
	end
end

local queued = false;
local function QueuePreview(delay)
	if queued then return end;
	queued = true;
	C_Timer.After(delay or 0.7, function()
		queued = false;
		R.Try('guide preview', function()
			if not PreviewWanted() then
				return DropPreview();
			end
			M:WhenReady(function() R.Try('guide preview', BuildPreview) end)
		end)
	end)
end

---------------------------------------------------------------
-- Quest run
---------------------------------------------------------------
local function Watched()
	local list = {};
	local ok, n = pcall(C_QuestLog.GetNumQuestWatches);
	for i = 1, ok and tonumber(n) or 0 do
		local okQ, questID = pcall(C_QuestLog.GetQuestIDForQuestWatchIndex, i);
		if ( okQ and type(questID) == 'number' and questID > 0 ) then
			list[#list + 1] = questID;
		end
	end
	return list;
end

local function IsComplete(questID)
	local ok, done = pcall(C_QuestLog.IsComplete, questID);
	return ok and done and true or false;
end

-- what the watched quests still ask for: a change means a new run
local function Signature()
	local parts = {};
	for _, questID in ipairs(Watched()) do
		local text = questID .. ( IsComplete(questID) and 'c' or 'o' );
		local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID);
		for _, objective in ipairs(ok and type(objectives) == 'table' and objectives or {}) do
			text = text .. ( objective.finished and '1' or '0' );
		end
		parts[#parts + 1] = text;
	end
	table.sort(parts)
	return table.concat(parts, ',');
end

-- the game's own next point for a quest: a stop and its place in Route's yards
local function GameWaypoint(questID)
	local ok, mapID, x, y = pcall(C_QuestLog.GetNextWaypoint, questID);
	local stop = ok and StopOnMap(mapID, x, y);
	if stop then
		return stop, M:WorldYards(stop.wcont, stop.wx, stop.wy);
	end
end

local function TurnIn(questID)
	if ( type(MelloUI.QuestTurnIn) == 'function' ) then
		local ok, _, _, wcont, wx, wy = pcall(MelloUI.QuestTurnIn, MelloUI, questID);
		if ( ok and wcont and wx and wy ) then
			return { wcont = wcont, wx = wx, wy = wy }, M:WorldYards(wcont, wx, wy);
		end
	end
	return GameWaypoint(questID);
end

-- an open quest's place: the nearest of what Route knows of its open objectives
-- @return stop, cont, x, y, later (true: Route answers next frame)
local function Objective(questID, pcont, px, py)
	local ok, places, n, later = pcall(M.ObjectivePlaces, M, questID);
	if ( ok and later ) then
		return nil, nil, nil, nil, true;
	end
	if ( ok and type(places) == 'table' and tonumber(n) ) then
		local best, bestD;
		for i = 1, n do
			local cont, x, y = places[i * 3 - 2], places[i * 3 - 1], places[i * 3];
			local d = ( cont == pcont ) and Dist(x, y, px, py) or 1e6 + i;
			if ( cont and x and y and ( not bestD or d < bestD ) ) then
				best, bestD = i, d;
			end
		end
		if best then
			local cont, x, y = places[best * 3 - 2], places[best * 3 - 1], places[best * 3];
			local stop = StopAtYards(cont, x, y);
			if stop then
				return stop, cont, x, y;
			end
		end
	end
	return GameWaypoint(questID);
end

local function Title(questID)
	local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID);
	return ok and type(title) == 'string' and title or ('Quest ' .. questID);
end

-- a short order through the stops from the player: the nearest next, then
-- any stretch turned round where that makes the way shorter
local function Order(stops, pcont, px, py)
	local function Gap(a, b)
		return ( a.cont == b.cont ) and Dist(a.x, a.y, b.x, b.y) or 1e6;
	end
	local here = { cont = pcont, x = px, y = py };
	local left, path = { unpack(stops) }, {};
	local from = here;
	while ( #left > 0 ) do
		local best, bestD;
		for i, stop in ipairs(left) do
			local d = Gap(from, stop);
			if ( not bestD or d < bestD ) then
				best, bestD = i, d;
			end
		end
		from = tremove(left, best);
		path[#path + 1] = from;
	end
	local n, improved, rounds = #path, true, 0;
	while ( improved and rounds < 20 ) do
		improved, rounds = false, rounds + 1;
		for i = 1, n - 1 do
			for j = i + 1, n do
				local before, after = path[i - 1] or here, path[j + 1];
				local now = Gap(before, path[i]) + ( after and Gap(path[j], after) or 0 );
				local turned = Gap(before, path[j]) + ( after and Gap(path[i], after) or 0 );
				if ( turned + 1 < now ) then
					local a, b = i, j;
					while ( a < b ) do
						path[a], path[b] = path[b], path[a];
						a, b = a + 1, b - 1;
					end
					improved = true;
				end
			end
		end
	end
	return path;
end

-- @return stops in order, or nil with `later` true
local function Collect()
	local pcont, px, py = R:Where();
	if not pcont then
		return {};
	end
	local stops = {};
	for _, questID in ipairs(Watched()) do
		local stop, cont, x, y, later;
		if IsComplete(questID) then
			stop, cont, x, y = TurnIn(questID);
		else
			stop, cont, x, y, later = Objective(questID, pcont, px, py);
		end
		if later then
			return nil, true;
		end
		if ( stop and cont and x and y ) then
			stop.label, stop.hold = Title(questID), true;
			stops[#stops + 1] = { stop = stop, cont = cont, x = x, y = y };
		end
	end
	return Order(stops, pcont, px, py);
end

local function Lead(quiet, tries)
	local stops, later = Collect();
	if later then
		tries = ( tries or 0 ) + 1;
		if ( tries <= 20 ) then
			C_Timer.After(0.2, function() R.Try('quest run', Lead, quiet, tries) end)
		end
		return;
	end
	if ( #stops == 0 ) then
		if Mine('run') then
			M:TripEnd()
		end
		if run.active then
			R:Say('Quest run finished: none of your tracked quests has a place left to go.')
		else
			R:Print("Quest run: Route knows no place for any of your tracked quests.")
		end
		run.active = false;
		return;
	end
	local list = {};
	for i, entry in ipairs(stops) do
		list[i] = entry.stop;
	end
	DropPreview()
	local ok, led = pcall(M.Trip, M, list);
	local trip = rawget(M, 'trip');
	if not ( ok and led and type(trip) == 'table' ) then
		run.active = false;
		return R:Print('Quest run: Route could not lead there.');
	end
	trip.patchwerk = 'run';
	run.active, run.sig = true, Signature();
	if not quiet then
		R:Say(('Quest run: %d stop%s, first %s.'):format(#list, #list == 1 and '' or 's', tostring(list[1].label)))
	end
end

function Trips:StartRun()
	if not R:Active() then
		return R:Print('Quest run: Route is off.');
	end
	if GuideSpot() then
		return R:Print('Quest run: a guide is leading. It is for when no guide runs.');
	end
	run.active, run.startedAt = true, GetTime();   -- (so the preview stays away while the road map comes in)
	M:WhenReady(function() R.Try('quest run', Lead, false) end)
end

function Trips:StopRun(quiet)
	if Mine('run') then
		M:TripEnd()
	end
	if ( run.active and not quiet ) then
		R:Say('Quest run stopped.')
	end
	run.active = false;
end

function Trips:ToggleRun()
	if ( run.active and Mine('run') ) then
		return self:StopRun();
	end
	return self:StartRun();
end

function Trips:NextStop()
	if not Mine('run') then
		return R:Print('Quest run: none is under way.');
	end
	if not M:TripNext() then
		run.active = false;
		R:Say('Quest run finished.')
	end
end

function Trips:RunActive()
	return run.active and Mine('run') ~= nil;
end

-- the quest log changed: a run under way is led again when what the quests ask for did
local refreshing = false;
local function Refresh()
	if ( refreshing or not run.active ) then return end;
	refreshing = true;
	C_Timer.After(1.5, function()
		refreshing = false;
		R.Try('quest run', function()
			if not run.active then return end;
			if not Mine('run') then
				run.active = false;   -- (another destination was chosen, or the route cleared)
				return;
			end
			if ( Signature() ~= run.sig ) then
				Lead(true)
			end
		end)
	end)
end

---------------------------------------------------------------
-- On the game's world map
---------------------------------------------------------------
local drawn, layer, provider = {}, nil, nil;

-- Route's own trail is laid just above the map's art and under its
-- pins (M.LayerAboveArt), and in the screen's own units: the canvas
-- is a huge frame scaled down, so the layer is scaled back up by the
-- same factor and made as big as the canvas shows.
local function Draw()
	local map = WorldMapFrame;
	if not ( map and map:IsShown() and map.GetCanvas ) then return end;
	local canvas = map:GetCanvas();
	if not layer then
		layer = CreateFrame('Frame', nil, canvas);
		layer:SetPoint('TOPLEFT', canvas, 'TOPLEFT')
	end
	if M.LayerAboveArt then
		M.LayerAboveArt(layer, canvas)
	else
		layer:SetFrameLevel(canvas:GetFrameLevel() + 6)
	end
	local scale = map.GetCanvasScale and tonumber(map:GetCanvasScale()) or 1;
	if not ( scale > 0 and scale < math.huge ) then
		scale = 1;
	end
	local W, H = ( tonumber(canvas:GetWidth()) or 0 ) * scale, ( tonumber(canvas:GetHeight()) or 0 ) * scale;
	local mapID = map:GetMapID();
	if not ( mapID and M.isEnabled and rawget(M, 'trip') and W >= 10 and H >= 10 and W < math.huge and H < math.huge ) then
		return M.TripDraw(drawn, layer, nop, 0, 0);
	end
	layer:SetScale(1 / scale)
	layer:SetSize(W, H)
	M.TripDraw(drawn, layer, function(cont, x, y)
		local fx, fy = M.OnMap(mapID, cont, x, y);
		if fx then
			return fx * W, fy * H;
		end
	end, W, H)
end

local function Redraw()
	C_Timer.After(0, function() R.Try('trip on the world map', Draw) end)
end

local function HookMap()
	if ( provider or not ( MapCanvasDataProviderMixin and WorldMapFrame and WorldMapFrame.AddDataProvider ) ) then return end;
	provider = CreateFromMixins(MapCanvasDataProviderMixin);
	function provider:RemoveAllData() end
	function provider:RefreshAllData() Redraw() end
	function provider:OnCanvasScaleChanged() Redraw() end
	WorldMapFrame:AddDataProvider(provider)
	WorldMapFrame:HookScript('OnShow', Redraw)
end

---------------------------------------------------------------
-- On the minimap
---------------------------------------------------------------
-- Route lets other code draw on its minimap layer (M.WantMinimap:
-- called at each of its layouts, 20 a second, with the view set for
-- M.MinimapOffset). The legs after the stop led are drawn there as
-- thin lines, clipped to the map's shape as Route clips its own
-- trail, and each stop ahead that is in view gets its number. Shown
-- with Route's own Route On The Minimap setting.
local Mini = { lines = {}, marks = {}, owner = {} };
local MINI_COLOUR = { 1, 0.82, 0.28, 0.6 };

local function MiniLayer()
	local parent = M.MinimapFrame and M.MinimapFrame();
	if not parent then return end;
	if ( not Mini.frame or Mini.frame:GetParent() ~= parent ) then
		Mini.frame = CreateFrame('Frame', nil, parent);
		Mini.frame:SetAllPoints(parent)
		Mini.lines, Mini.marks = {}, {};
	end
	return Mini.frame;
end

local function MiniHide(fromLine, fromMark)
	for i = fromLine, #Mini.lines do
		Mini.lines[i]:Hide()
	end
	for i = fromMark, #Mini.marks do
		Mini.marks[i]:Hide()
	end
end

local function MiniTick(cont, round, radius, radiusX, radiusY)
	local trip = cont and M.db.minimap and M:TripState();
	local frame = trip and MiniLayer();
	if not frame then
		return MiniHide(1, 1);
	end
	local Offset, Circle, Square = M.MinimapOffset, M.ClipToCircle, M.ClipToSquare;
	local used = 0;
	for i = trip.at + 1, #trip.stops do
		local points = trip.legs[i];
		for k = 2, points and #points or 0 do
			local a, b = points[k - 1], points[k];
			if ( a[1] == cont and b[1] == cont and b[4] ~= 'boat' and b[4] ~= 'flight' ) then
				local ax, ay = Offset(a[2], a[3]);
				local bx, by = Offset(b[2], b[3]);
				if round then
					ax, ay, bx, by = Circle(ax, ay, bx, by, radius);
				else
					ax, ay, bx, by = Square(ax, ay, bx, by, radiusX, radiusY);
				end
				if ax then
					used = used + 1;
					local line = Mini.lines[used];
					if not line then
						line = frame:CreateLine(nil, 'BACKGROUND');
						line:SetColorTexture(unpack(MINI_COLOUR))
						line:SetThickness(2)
						Mini.lines[used] = line;
					end
					line:SetStartPoint('CENTER', frame, ax, ay)
					line:SetEndPoint('CENTER', frame, bx, by)
					line:Show()
				end
			end
		end
	end
	local marks = 0;
	for i = trip.at + 1, #trip.stops do
		local stop = trip.stops[i];
		if ( stop.cont == cont and stop.x and stop.y ) then
			local x, y = Offset(stop.x, stop.y);
			local inside;
			if round then
				inside = ( x * x + y * y ) <= ( radius - 6 ) * ( radius - 6 );
			else
				inside = math.abs(x) <= radiusX - 6 and math.abs(y) <= radiusY - 6;
			end
			if inside then
				marks = marks + 1;
				local mark = Mini.marks[marks];
				if not mark then
					mark = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall');
					mark:SetTextColor(1, 0.82, 0.28)
					Mini.marks[marks] = mark;
				end
				mark:SetText(i)
				mark:ClearAllPoints()
				mark:SetPoint('CENTER', frame, 'CENTER', x, y)
				mark:Show()
			end
		end
	end
	MiniHide(used + 1, marks + 1)
end

-- (one function kept: Route tells a client it already has by it)
function Mini.Client(...)
	R.Try('trip on the minimap', MiniTick, ...)
end

-- asked for only while there is a trip, so Route's minimap layer is not kept awake for nothing
local function MiniWanted()
	if not ( M.WantMinimap and M.MinimapOffset and M.ClipToCircle and M.ClipToSquare ) then return end;
	local want = rawget(M, 'trip') ~= nil;
	M.WantMinimap(Mini.owner, want and Mini.Client or nil)
end

---------------------------------------------------------------
-- Events
---------------------------------------------------------------
MelloUI:On('route:trip', function()
	R.Try('trip on the world map', HookMap)
	R.Try('trip on the minimap', MiniWanted)
	Redraw()
end, drawn)
MelloUI:On('guide', function() QueuePreview(0.7) end, run)

local Watcher = CreateFrame('Frame')
for _, event in ipairs({ 'QUEST_LOG_UPDATE', 'QUEST_WATCH_LIST_CHANGED', 'QUEST_TURNED_IN', 'QUEST_ACCEPTED', 'QUEST_REMOVED' }) do
	Watcher:RegisterEvent(event)
end
Watcher:SetScript('OnEvent', Refresh)

-- the preview kept up: made when a guide leads and none is there (a new step, a new destination)
local elapsed = 0;
Watcher:SetScript('OnUpdate', function(_, dt)
	elapsed = elapsed + dt;
	if ( elapsed < 3 ) then return end;
	elapsed = 0;
	R.Try('trip on the world map', HookMap)
	R.Try('guide preview', function()
		-- (a run that never got its trip, or lost it to another destination: over)
		if ( run.active and not Mine('run') and GetTime() - ( run.startedAt or 0 ) > 15 ) then
			run.active = false;
		end
		if PreviewWanted() then
			if not Mine('preview') then
				QueuePreview(0)
			end
		elseif ( type(rawget(M, 'trip')) == 'table' and M.trip.patchwerk == 'preview' ) then
			DropPreview()
		end
	end)
end)
R:OnSetting('guidePreview', function() QueuePreview(0) end)
R:OnSetting('previewSteps', function()
	DropPreview()
	QueuePreview(0)
end)
