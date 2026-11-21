-- Thread (Globe): the pins other addons put on the world map.
--
-- Most addons that mark the map (quest helpers, guides, rare finders) do not draw on it themselves:
-- they hand each pin (a small frame of their own, and where it goes) to a library they share,
-- HereBeDragons, which puts it on the game's map. The library does not say what it holds, so its
-- calls to add and remove a world map pin are followed from here (hooksecurefunc: the library and its
-- addons work as before), and each pin is drawn on the globe too: with the picture its own frame shows,
-- its own tooltip, and its own click, as far as its addon made those work off the game's map.
--
-- Questie keeps a copy of the library to itself (a part of its own, with the same calls): that copy is
-- followed too. An addon that draws on the game's map by other means is not seen here.
local ADDON, ns = ...
if not (ns.linked and ns.Marks) then return end
local G, Marks = ns.G, ns.Marks
local Guides = ns.Base.Guides

local VIEW = G.VIEW
local FROM = VIEW * 1.2               -- shown from this zoom in (the globe's radius, points)
local LIBRARY = 'HereBeDragons-Pins-2.0'
local CALLS = { 'AddWorldMapIconWorld', 'AddWorldMapIconMap', 'RemoveWorldMapIcon', 'RemoveAllWorldMapIcons' }

-- by a pin's own frame: { ref (its addon), map, x, y (in the world) } or, until first drawn, { ref, ui, u, v
-- (on one of the game's maps) }: an addon may add thousands at once, and most are never looked at
local held = {}
local count = 0
local followed = {}                   -- by library: its calls as they were when last followed (a newer copy of it replaces them)
local found = false

local function Add(ref, icon, pin)
	if type(icon) ~= 'table' then return end
	if not held[icon] then count = count + 1 end
	pin.ref = ref
	held[icon] = pin
	Marks.Changed('pins')
end

local function Remove(icon)
	if icon ~= nil and held[icon] then
		held[icon] = nil
		count = count - 1
		Marks.Changed('pins')
	end
end

local after = {
	-- (the library's east-west is the game's second figure of a place, its north-south the first)
	AddWorldMapIconWorld = function(_, ref, icon, instance, x, y)
		if type(instance) == 'number' and type(x) == 'number' and type(y) == 'number' then
			Add(ref, icon, { map = instance, x = y, y = x })
		end
	end,
	AddWorldMapIconMap = function(_, ref, icon, uiMap, x, y)
		if type(uiMap) == 'number' and type(x) == 'number' and type(y) == 'number' then
			Add(ref, icon, { ui = uiMap, u = x, v = y })
		end
	end,
	RemoveWorldMapIcon = function(_, _, icon) Remove(icon) end,
	RemoveAllWorldMapIcons = function(_, ref)
		for icon, pin in pairs(held) do
			if pin.ref == ref then Remove(icon) end
		end
	end,
}

local function FollowOne(lib)
	if type(lib) ~= 'table' then return end
	local known = followed[lib] or {}
	followed[lib] = known
	for _, name in ipairs(CALLS) do
		if type(lib[name]) == 'function' and lib[name] ~= known[name] then
			if pcall(hooksecurefunc, lib, name, function(...) ns.Try('a pin', after[name], ...) end) then
				known[name] = lib[name]
				found = true
			end
		end
	end
end

-- Follow the library once it is there (it comes with the first addon that brings it), and again when
-- a newer copy of it has replaced its calls.
local function Follow()
	local stub = rawget(_G, 'LibStub')
	if type(stub) == 'table' or type(stub) == 'function' then
		local ok, lib = pcall(stub, LIBRARY, true)
		if ok then FollowOne(lib) end
	end
	local loader = rawget(_G, 'QuestieLoader')
	if type(loader) == 'table' and type(loader.ImportModule) == 'function' then
		local ok, lib = pcall(loader.ImportModule, loader, 'HBDPins')
		if ok then FollowOne(lib) end
	end
end

---------------------------------------------------------------------------
-- What a pin looks like, says and does
---------------------------------------------------------------------------
local function Call(object, method, ...)
	local fn = type(object) == 'table' and object[method]
	if type(fn) ~= 'function' then return nil end
	local ok, a, b, c, d, e, f, g, h = pcall(fn, object, ...)
	if ok then return a, b, c, d, e, f, g, h end
	return nil
end

-- The picture a pin's frame shows: the one it keeps under a usual name, else the first it has.
local function Texture(icon)
	for _, key in ipairs({ 'texture', 'Texture', 'icon', 'Icon' }) do
		local t = icon[key]
		if type(t) == 'table' and type(t.GetTexture) == 'function' then return t end
	end
	if type(icon.GetRegions) == 'function' then
		local ok, regions = pcall(function() return { icon:GetRegions() } end)
		for _, region in ipairs(ok and regions or {}) do
			if type(region) == 'table' and type(region.GetTexture) == 'function' then return region end
		end
	end
end

local function Script(icon, name)
	local fn = Call(icon, 'GetScript', name)
	return type(fn) == 'function' and fn or nil
end

-- A pin's own tooltip: its frame is told the pointer came over it, and the tooltip it puts up is
-- moved to the pointer (its frame is on the game's map, which is not shown).
local function Tip(m, on)
	local icon = m.pin
	local tip = rawget(_G, 'GameTooltip')
	if not on then
		local leave = Script(icon, 'OnLeave')
		if leave then pcall(leave, icon) end
		if type(tip) == 'table' and Call(tip, 'IsOwned', icon) then tip:Hide() end
		return
	end
	local enter = Script(icon, 'OnEnter')
	if not enter then return end
	pcall(enter, icon)
	if type(tip) == 'table' and Call(tip, 'IsOwned', icon) and tip.SetAnchorType then
		local _, _, _, cross = G.Frames()
		if G.ByKeys() and cross and tip.ClearAllPoints then
			pcall(tip.SetAnchorType, tip, 'ANCHOR_NONE')
			tip:ClearAllPoints()
			tip:SetPoint('TOPLEFT', cross, 'BOTTOMRIGHT', 0, 0)
		else
			pcall(tip.SetAnchorType, tip, 'ANCHOR_CURSOR')
		end
	end
end

local function Click(button, m)
	local icon = m.pin
	local click = Script(icon, 'OnClick')
	if click then
		pcall(click, icon, button, false)
		return
	end
	local up = Script(icon, 'OnMouseUp')
	if up then pcall(up, icon, button) end
end

Marks.Source('pins', {
	order = 15,
	Shown = function() return ns.Get('globePins') and count > 0 end,
	Fill = function(mark)
		for icon, pin in pairs(held) do
			if pin.ui then
				-- (a place on one of the game's maps: found in the world now, once)
				pin.map, pin.x, pin.y = Guides.WorldOf(pin.ui, pin.u, pin.v)
				pin.ui = nil
			end
			if pin.map and G.continents[pin.map] then
				local t = Texture(icon)
				local file = t and Call(t, 'GetTexture')
				local atlas = t and Call(t, 'GetAtlas')
				local r, g, b, a = 1, 1, 1, 1
				if t then
					local tr, tg, tb, ta = Call(t, 'GetVertexColor')
					if type(tr) == 'number' then r, g, b, a = tr, tg or 1, tb or 1, ta or 1 end
				end
				local alpha = a * (tonumber(Call(icon, 'GetAlpha')) or 1)
				if alpha > 0.05 then
					local coords
					if t and file then
						local x1, y1, _, y2, x3 = Call(t, 'GetTexCoord')      -- (upper left, lower left, upper right)
						if type(x1) == 'number' and type(x3) == 'number' and type(y2) == 'number' and x1 < x3 and y1 < y2 then
							coords = { x1, x3, y1, y2 }
						end
					end
					local size = tonumber(Call(icon, 'GetWidth')) or 16
					mark({ map = pin.map, x = pin.x, y = pin.y, pin = icon, size = math.max(12, math.min(24, size)), rank = 3, from = FROM,
						atlas = type(atlas) == 'string' and atlas ~= '' and atlas or nil,
						icon = (type(file) == 'string' or type(file) == 'number') and file or nil, coords = coords,
						tint = { r, g, b }, alpha = math.min(1, alpha), tip = Tip, click = Click })
				end
			end
		end
	end,
})

Marks.On('ADDON_LOADED', Follow)
Marks.On('PLAYER_LOGIN', Follow)
Marks.On('PLAYER_ENTERING_WORLD', Follow)
ns.GlobeOn('show', function()
	Follow()
	Marks.Changed('pins')             -- (a pin's picture may have changed since it was added)
end)
Follow()

-- For the checks outside the game.
function ns.PinsState() return { count = count, library = found } end
