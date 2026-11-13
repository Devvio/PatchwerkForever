-- Thread (Routes): the step, said on screen.
--
-- When the route gets a new destination, a few words appear in the upper middle of the screen: what
-- you are going to do (the guide's own words for its step, the quest's name, "to your map pin") and,
-- smaller under them, the route (how long, how far on foot, what it flies or rides). They come in
-- softly, rising a little, stay a few seconds and go out again. A step with nowhere to go (use your
-- hearthstone, train your skills) is said the same way, with no route under it.
--
-- Nothing is said when the way is only found anew after a wrong turn. Where it stands, how large it
-- is and how long it stays are settings; /thread step says the last one again.
local ADDON, ns = ...
if not ns.linked then return end

local IN, OUT = 0.35, 0.9         -- seconds it takes to come in, and to go out
local RISE = 14                   -- pixels it rises while coming in
local WIDTH = 0.6                 -- of the screen's width, at most

local frame, big, small
local shown = { at = 0, hold = 0 }        -- when the words on screen began, and how long they stay
local last                                -- { lines, route }: what was said last

local function Font(fs, size, flags)
	local path = GameFontNormal and GameFontNormal.GetFont and GameFontNormal:GetFont()
	if not (path and fs:SetFont(path, size, flags)) then
		fs:SetFont('Fonts\\FRIZQT__.TTF', size, flags)
	end
end

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
	small:SetTextColor(0.62, 0.85, 1)
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
local function Show(lines, route)
	if not frame then Make() end
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
	shown.at, shown.hold = GetTime(), ns.Get('floatHold') or 5
	frame:SetAlpha(0)
	frame:Show()
end

-- Says a step: its words, and under them the route's (nil for none). Kept, to be said again.
function ns.FloatStep(lines, route)
	if type(lines) ~= 'table' or #lines == 0 then return end
	last = { lines = lines, route = route }
	if not ns.Get('float') then return end
	Show(lines, ns.Get('floatRoute') and route or nil)
end

local OWN = { pin = { 'To your map pin' }, spot = { 'To the spot you gave' } }

-- Says a destination that has just been given, once its route is known (Route.lua). route: nil when no
-- way was found.
function ns.FloatRoute(dest, route)
	local lines = dest.lines
	if type(lines) ~= 'table' or #lines == 0 then
		if dest.source then return end                    -- (a guide's step with no words of its own: nothing to say)
		lines = dest.pin and OWN.pin or OWN.spot
	end
	ns.FloatStep(lines, route and ns.Summary(route) or nil)
end

-- /thread step: the last one, again.
function ns.FloatAgain()
	if not last then
		ns.Print('No step text to show yet. It appears when the route gets a new destination.')
		return
	end
	Show(last.lines, ns.Get('floatRoute') and last.route or nil)
end

-- The button on the options page.
function ns.FloatTest()
	Show({ 'Turn in The Forgotten Pools', 'Accept The Stagnant Oasis' }, '3 min: walk 640 yd')
end

-- (for the checks: what is on screen now)
function ns.FloatShown()
	if not (frame and frame:IsShown()) then return nil end
	return big:GetText(), small:GetText()
end
