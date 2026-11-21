-- Thread (Globe): the globe in place of the game's world map.
--
-- With the setting The Map Key Opens The Globe (off as it comes):
--   the map key     every key the game's Toggle World Map is bound to opens and closes the globe. The
--                   game's own binding is left as it is: a binding of ours is laid over the same keys
--                   (SetOverrideBindingClick), which the game allows outside combat only, so it is
--                   put on and taken off between fights.
--   show on map     when something opens the game's map at a place (a map link in chat, an addon's
--                   "show on map"), the globe opens turned to that place and the game's map closes
--                   again. Not in combat: there the game's map is left to do it.
-- With or without the setting, a button on each takes you to the other: World Map on the globe (and
-- in Go To), Globe on the game's map.
local ADDON, ns = ...
if not (ns.linked and ns.G) then return end
local G = ns.G

local BINDING = 'TOGGLEWORLDMAP'
local WIDE = 520                      -- the globe's window shows its World Map button from this width up

local owner = CreateFrame('Frame')
local key = CreateFrame('Button', 'PatchwerkForever_Thread_GlobeMapKey', UIParent)
key:Hide()
key:SetScript('OnClick', function() ns.Try('the globe', ns.Toggle) end)

local laid = {}                       -- the keys ours is laid over
local waiting = false                 -- to be done once the fight is over
local asked = false                   -- the game's map was asked for from here: it is left alone
local worldButton, globeButton

local function Fighting() return InCombatLockdown and InCombatLockdown() and true or false end

-- Lay our binding over the map key's keys, or take it off.
local function Apply()
	if type(SetOverrideBindingClick) ~= 'function' or type(ClearOverrideBindings) ~= 'function' or type(GetBindingKey) ~= 'function' then
		return
	end
	if Fighting() then
		waiting = true
		return
	end
	waiting = false
	ClearOverrideBindings(owner)
	laid = {}
	if not ns.Get('globeMapKey') then return end
	for _, one in ipairs({ GetBindingKey(BINDING) }) do
		if type(one) == 'string' and one ~= '' then
			SetOverrideBindingClick(owner, true, one, key:GetName())
			laid[#laid + 1] = one
		end
	end
end

owner:SetScript('OnEvent', function(_, event)
	if event == 'PLAYER_REGEN_ENABLED' then
		if waiting then ns.Try('the map key', Apply) end
	else
		ns.Try('the map key', Apply)
	end
end)
for _, event in ipairs({ 'PLAYER_LOGIN', 'PLAYER_ENTERING_WORLD', 'UPDATE_BINDINGS', 'PLAYER_REGEN_ENABLED' }) do
	pcall(owner.RegisterEvent, owner, event)
end
ns.OnSetting(function(name)
	if name == 'globeMapKey' then ns.Try('the map key', Apply) end
end)

---------------------------------------------------------------------------
-- From one to the other
---------------------------------------------------------------------------
-- The game's own map, opened from the globe (which closes).
local function GameMap()
	local toggle = rawget(_G, 'ToggleWorldMap')
	local map = rawget(_G, 'WorldMapFrame')
	if type(toggle) ~= 'function' then
		ns.Print('This game client has no world map an addon can open.')
		return
	end
	if Fighting() then
		ns.Print('The world map cannot be opened from here in combat. Use its key.')
		return
	end
	ns.Toggle(false)
	if type(map) == 'table' and map.IsShown and map:IsShown() then return end
	asked = true
	pcall(toggle)
	asked = false
end

function ns.MapMenu(root)
	root:CreateButton('The Game\'s World Map', function() ns.Try('the globe', GameMap) end)
end

-- The globe, opened from the game's map (which closes), turned to the map that was up.
local function FromGameMap()
	local map = rawget(_G, 'WorldMapFrame')
	local ui = type(map) == 'table' and type(map.GetMapID) == 'function' and map:GetMapID() or nil
	if type(map) == 'table' and not Fighting() and type(HideUIPanel) == 'function' then pcall(HideUIPanel, map) end
	ns.Toggle(true)
	if ui and ns.GlobeShowMap then ns.GlobeShowMap(ui) end
end

local function MakeGlobeButton()
	if globeButton then return end
	local map = rawget(_G, 'WorldMapFrame')
	if type(map) ~= 'table' or type(map.GetObjectType) ~= 'function' then return end
	local border = type(map.BorderFrame) == 'table' and map.BorderFrame or map
	local ok, button = pcall(CreateFrame, 'Button', nil, border, 'UIPanelButtonTemplate')
	if not ok or not button then return end
	globeButton = button
	button:SetSize(64, 20)
	local beside = type(border.MaximizeMinimizeFrame) == 'table' and border.MaximizeMinimizeFrame
	if beside then
		button:SetPoint('RIGHT', beside, 'LEFT', -4, 0)
	else
		button:SetPoint('TOPRIGHT', border, 'TOPRIGHT', -56, -1)
	end
	button:SetText('Globe')
	button:SetScript('OnClick', function() ns.Try('the globe', FromGameMap) end)
end

ns.GlobeOn('show', function()
	if worldButton then return end
	local window = G.Frames()
	worldButton = CreateFrame('Button', nil, window, 'UIPanelButtonTemplate')
	worldButton:SetSize(84, 22)
	worldButton:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -130, -4)     -- (left of Full Screen)
	worldButton:SetText('World Map')
	worldButton:SetScript('OnClick', function() ns.Try('the globe', GameMap) end)
end)

-- (the button has room only in a window wide enough; Go To has the same entry at any width)
ns.GlobeOn('frame', function()
	if not worldButton then return end
	local window = G.Frames()
	local wide = (window:GetWidth() or 0) >= WIDE
	if wide ~= worldButton:IsShown() then
		if wide then worldButton:Show() else worldButton:Hide() end
	end
end)

---------------------------------------------------------------------------
-- The game's map asked for at a place
---------------------------------------------------------------------------
local followed = false
local function Follow()
	if followed or type(rawget(_G, 'OpenWorldMap')) ~= 'function' or type(hooksecurefunc) ~= 'function' then return end
	followed = true
	hooksecurefunc('OpenWorldMap', function(ui)
		if asked or not ns.Get('globeMapKey') or Fighting() or type(ui) ~= 'number' then return end
		ns.Try('the globe', function()
			local map = rawget(_G, 'WorldMapFrame')
			ns.Toggle(true)
			if ns.GlobeShowMap and ns.GlobeShowMap(ui) and type(map) == 'table' and type(HideUIPanel) == 'function' then
				pcall(HideUIPanel, map)
			end
		end)
	end)
end

local loader = CreateFrame('Frame')
loader:SetScript('OnEvent', function()
	Follow()
	ns.Try('the globe', MakeGlobeButton)
end)
pcall(loader.RegisterEvent, loader, 'PLAYER_LOGIN')
pcall(loader.RegisterEvent, loader, 'ADDON_LOADED')
Follow()

-- For the checks outside the game.
function ns.MapKeyState()
	return { keys = laid, waiting = waiting, world = worldButton and worldButton:IsShown() or false, globe = globeButton ~= nil,
		followed = followed }
end
