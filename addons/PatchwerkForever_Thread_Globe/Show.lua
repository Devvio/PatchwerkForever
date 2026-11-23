-- Globe (Thread): the Show menu. Each kind of mark, and each thing drawn over the map, turned on and
-- off where you look at it; the same settings as on the options page, and remembered as those are.
-- Opened by the Show button, or by its key (Show Menu, under Key Bindings).
local ADDON, ns = ...
if not (ns.linked and ns.G) then return end
local G = ns.G

-- (a list of { setting, words }; false is a line between two groups)
local MARKS = {
	{ 'globeRoute', 'Your Route' },
	{ 'globeQuests', 'Quests' },
	{ 'globePlaces', 'Places' },
	{ 'globePeople', 'Your Group' },
	{ 'globeGuild', 'Guild Members' },
	{ 'globeFriends', 'Friends' },
	{ 'globeFlights', 'Flight Points' },
	{ 'globeCrossings', 'Boats And Zeppelins' },
	{ 'globeNodes', 'Herb And Ore Nodes' },
	{ 'globeRares', 'Rares And Treasures' },
	{ 'globePins', "Other Addons' Pins" },
	false,
	{ 'globeNames', 'Names' },
	{ 'globeCoords', 'Coordinates' },
	{ 'globeExplore', 'Fog Of War' },
	{ 'globeLevels', 'Zones Colored By Level' },
	{ 'globeAge', 'Aged Paper' },
}
local LIGHT = {
	{ 'globeFxLight', 'Candlelight' },
	{ 'globeFxMove', 'Moving Sea And Sky' },
	{ 'globeFxOpen', 'Animate Opening' },
	{ 'globeFxPing', 'Pulse Where You Are' },
	{ 'globeFxSound', 'Map Sounds' },
	{ 'globeLight', 'Shade The Globe' },
}

local function Boxes(menu, list)
	for _, one in ipairs(list) do
		if not one then
			if menu.CreateDivider then menu:CreateDivider() end
		else
			local key, words = one[1], one[2]
			local function Is() return ns.Get(key) and true or false end
			local function Flip() ns.Set(key, not ns.Get(key)) end
			if menu.CreateCheckbox then
				menu:CreateCheckbox(words, Is, Flip)
			else
				menu:CreateButton((Is() and 'Hide ' or 'Show ') .. words, Flip)
			end
		end
	end
end

local button
local function ShowMenu(owner)
	local _, view = G.Frames()
	G.Menu(owner or button or view, function(root)
		root:CreateTitle('Show')
		Boxes(root, MARKS)
		if root.CreateDivider then root:CreateDivider() end
		Boxes(root:CreateButton('Light And Movement'), LIGHT)
	end)
end

ns.GlobeOn('show', function()
	if button then return end
	local window = G.Frames()
	button = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
	button:SetSize(64, 22)
	button:SetPoint('TOPLEFT', window, 'TOPLEFT', 144, -4)
	button:SetText('Show')
	button:SetScript('OnClick', function(self) ns.Try('the globe', ShowMenu, self) end)
end)

ns.GlobeOn('key', function(what)
	if what ~= 'show' then return false end
	ShowMenu()
	return true
end)
