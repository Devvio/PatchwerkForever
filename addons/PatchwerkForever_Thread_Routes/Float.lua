-- Thread (Routes): the step, said on screen.
--
-- When the route gets a new destination, a few words appear in the upper middle of the screen: what
-- you are going to do (the guide's own words for its step, the quest's name, "to your map pin") and,
-- smaller under them, the route (how long, how far on foot, what it flies or rides). They come in
-- softly, rising a little, stay a few seconds and go out again. A step with nowhere to go (use your
-- hearthstone, train your skills) is said the same way, with no route under it. Where no route could
-- be found, the smaller line says so, in a colour of its own.
--
-- Nothing is said when the way is only found anew after a wrong turn, nor when a step that has been
-- said gets a new place (Sources.lua). Where it stands, how large it is and how long it stays are
-- settings; /thread step says the last one again. A change of focus is said as "Following: <its name>",
-- above the words of the step it leads to (Sources.lua). While the options are open, the sample of
-- Preview Step Text follows those settings as they are changed, drawn above the options window.
local ADDON, ns = ...
if not ns.linked then return end

local IN, OUT = 0.35, 0.9         -- seconds it takes to come in, and to go out
local RISE = 14                   -- pixels it rises while coming in
local WIDTH = 0.6                 -- of the screen's width, at most

local frame, big, small
local shown = { at = 0, hold = 0 }        -- when the words on screen began, and how long they stay
local last                                -- { lines, route, failed }: what was said last
local ROUTE, FAILED = { 0.62, 0.85, 1 }, { 1, 0.5, 0.45 }     -- the smaller line's colour: a route, and none found

-- The game's own font at another size (the world map's marks use it too: MapRoute.lua).
local function Font(fs, size, flags)
	local path = GameFontNormal and GameFontNormal.GetFont and GameFontNormal:GetFont()
	if not (path and fs:SetFont(path, size, flags)) then
		fs:SetFont('Fonts\\FRIZQT__.TTF', size, flags)
	end
end

ns.Font = Font

local function Make()
	frame = CreateFrame('Frame', nil, UIParent)
	frame:SetFrameStrata('HIGH')
	frame:EnableMouse(false)
	frame:Hide()
	big = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	small = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	big:SetPoint('TOP', frame, 'TOP', 0, 0)
	small:SetPoint('TOP', big, 'BOTTOM', 0, -6)
	big:SetTextColor(1, 0.93, 0.76)
	small:SetTextColor(ROUTE[1], ROUTE[2], ROUTE[3])
	for _, fs in ipairs({ big, small }) do
		if fs.SetJustifyH then fs:SetJustifyH('CENTER') end
		if fs.SetWordWrap then fs:SetWordWrap(true) end
	end
	frame:SetScript('OnUpdate', function()
		local t = GetTime() - shown.at
		local alpha, rise
		if t < IN then
			alpha, rise = t / IN, RISE * (1 - t / IN)
		elseif t < IN + shown.hold then
			alpha, rise = 1, 0
		elseif t < IN + shown.hold + OUT then
			alpha, rise = 1 - (t - IN - shown.hold) / OUT, 0
		else
			frame:Hide()
			return
		end
		-- (eased: quick at first, settling at the end)
		alpha = 1 - (1 - alpha) * (1 - alpha)
		frame:SetAlpha(alpha)
		local screenW, screenH = UIParent:GetWidth() or 1000, UIParent:GetHeight() or 700
		frame:ClearAllPoints()
		frame:SetPoint('TOP', UIParent, 'TOP', (ns.Get('floatAcross') or 0) / 100 * screenW,
			-(ns.Get('floatDown') or 18) / 100 * screenH - rise)
	end)
end

-- lines: what to say, a list of strings (three at most are shown). route: the smaller line under them, or nil.
-- failed: that line says no route was found, not what the route is. sample: the options page's preview,
-- drawn above the options window; steady: it is on screen already and stays put (a slider moved), with
-- no new fade in.
local function Show(lines, route, failed, sample, steady)
	if not frame then Make() end
	frame:SetFrameStrata(sample and 'FULLSCREEN_DIALOG' or 'HIGH')
	local size = ns.Get('floatSize') or 20
	Font(big, size, 'OUTLINE')
	Font(small, math.max(9, math.floor(size * 0.68 + 0.5)), 'OUTLINE')
	local width = (UIParent:GetWidth() or 1000) * WIDTH
	frame:SetSize(width, size * 4)
	if big.SetWidth then
		big:SetWidth(width)
		small:SetWidth(width)
	end
	local text = {}
	for i = 1, math.min(3, #lines) do text[i] = lines[i] end
	big:SetText(table.concat(text, '\n'))
	small:SetText(route or '')
	local colour = failed and FAILED or ROUTE
	small:SetTextColor(colour[1], colour[2], colour[3])
	shown.hold = ns.Get('floatHold') or 5
	if steady and frame:IsShown() then
		shown.at = GetTime() - IN
	else
		shown.at = GetTime()
		frame:SetAlpha(0)
	end
	frame:Show()
end

-- The smaller line as it is shown: the route's only where that is wanted (a setting); that no route was
-- found, always.
local function Under(route, failed)
	return (failed or ns.Get('floatRoute')) and route or nil
end

-- Says a step: its words, and under them the route's (nil for none). Kept, to be said again.
-- failed: the line under them says no route was found. quiet: kept only, not shown (its words have
-- been on screen already: Sources.lua).
function ns.FloatStep(lines, route, failed, quiet)
	if type(lines) ~= 'table' or #lines == 0 then return end
	last = { lines = lines, route = route, failed = failed }
	if quiet or not ns.Get('float') then return end
	Show(lines, Under(route, failed), failed)
end

local OWN = { pin = { 'To your map pin' }, spot = { 'To your coordinates' } }

-- Says a destination that has just been given, once its route is known (Route.lua). route: nil when
-- none could be made; note: what to say in its place, where no way was found at all.
function ns.FloatRoute(dest, route, note)
	local lines = dest.lines
	-- (a focus just chosen: "Following: <its name>" above the words, which are then shown in any case)
	local following = dest.following
	dest.following = nil                                  -- (said once: not again when the way is searched for anew)
	if type(lines) ~= 'table' or #lines == 0 then
		if dest.source and not following then return end  -- (a guide's step with no words of its own: nothing to say)
		lines = dest.source and {} or (dest.pin and OWN.pin or OWN.spot)
	end
	if following then
		local with = { following }
		for _, text in ipairs(lines) do with[#with + 1] = text end
		lines = with
	end
	if route then note = nil end
	-- (words that have been on screen already are only kept, unless there is news under them: no way was found)
	ns.FloatStep(lines, route and ns.Summary(route) or note, note and true or nil, dest.quiet and not note and not following)
end

-- /thread step: the last one, again.
function ns.FloatAgain()
	if not last then
		ns.Print('No step text to show yet. It appears when the route gets a new destination.')
		return
	end
	Show(last.lines, Under(last.route, last.failed), last.failed)
end

-- The button on the options page. steady: shown again as a setting changes, without fading in anew.
function ns.FloatTest(steady)
	Show({ 'Turn in The Forgotten Pools', 'Accept The Stagnant Oasis' }, Under('3 min: walk 640 yd'), nil, true, steady)
end

-- While the options are open, the sample follows the settings of the step text as they change.
local LOOKS = { floatSize = true, floatDown = true, floatAcross = true, floatRoute = true, floatHold = true }
ns.OnSetting(function(key)
	local panel = rawget(_G, 'SettingsPanel')
	if LOOKS[key] and type(panel) == 'table' and panel.IsShown and panel:IsShown() then
		ns.FloatTest(true)
	end
end)

-- (for the checks: what is on screen now, and the smaller line itself, for its colour)
function ns.FloatShown()
	if not (frame and frame:IsShown()) then return nil end
	return big:GetText(), small:GetText(), small
end
