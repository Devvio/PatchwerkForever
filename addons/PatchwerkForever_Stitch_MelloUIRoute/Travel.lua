local _, ns = ...;
local R = ns.Route;
if not R then return end;
local M = R.M;
local Dist = R.Dist;
---------------------------------------------------------------
-- Hearthstone and teleports
---------------------------------------------------------------
-- Route knows roads, flights and boats, not the hearthstone or a
-- class's teleports. Their landing places are learned here as you
-- use them: a cast of yours that sets you down far away is a
-- teleport, kept by its spell (the account's), and the hearthstone
-- by its inn's name (each character's own; where you set it is kept
-- at once). While a route leads somewhere, the way from each
-- landing place you can use now is priced with Route's own search
-- (M:PriceFrom) against the way from here; when one is clearly
-- sooner it is offered: a line in chat, a button on the screen, and
-- the Route: Use Suggested Shortcut binding.
--
-- A suggestion, never part of the trail: Route's search cannot be
-- given a link of ours.

local HEARTH_ITEM = 6948;
local BIND_SPELLS = { [8690] = true, [556] = true };   -- Hearthstone, Astral Recall
local ASTRAL      = 556;
local FAR         = 400;   -- yards: a cast that moves you this far is a teleport
local OVERHEAD    = 25;    -- seconds: the cast and the loading screen
local WORTH       = 90;    -- seconds saved at least
local SHARE       = 0.7;   -- and at most this share of the way from here
local AGAIN       = 60;    -- seconds between two looks at the same destination
local MOST        = 4;     -- landing places priced at a time

local Travel = {};
R.Travel = Travel;

---------------------------------------------------------------
-- Learning the landing places
---------------------------------------------------------------
local function BindName()
	local ok, name = pcall(GetBindLocation);
	return ok and type(name) == 'string' and name ~= '' and name or nil;
end

local function Known(spellID)
	if ( C_SpellBook and C_SpellBook.IsSpellKnown ) then
		local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID);
		if ( ok and known ) then return true end;
	end
	if ( type(IsPlayerSpell) == 'function' ) then
		local ok, known = pcall(IsPlayerSpell, spellID);
		if ( ok and known ) then return true end;
	end
	return false;
end

local function SpellName(spellID)
	local ok, name = pcall(C_Spell.GetSpellName, spellID);
	return ok and type(name) == 'string' and name or ('spell ' .. spellID);
end

local function KeepBind(cont, x, y)
	local saved, name = R:GetSaved(), BindName();
	if ( saved and name and cont ) then
		saved.binds[R:Character()] = { cont = cont, x = x, y = y, name = name };
	end
end

-- at the inn's own place: the game's name for where you landed is the inn's
local function AtBind()
	local name = BindName();
	return name and ( name == GetSubZoneText() or name == GetMinimapZoneText() or name == GetZoneText() );
end

local pending;

local function Landed(cast)
	if ( pending ~= cast ) then return end;
	local cont, x, y = R:Where();
	if not cont then return end;
	if ( cont == cast.cont and Dist(x, y, cast.x, cast.y) < FAR ) then return end;
	pending = nil;
	local saved = R:GetSaved();
	if not saved then return end;
	if ( BIND_SPELLS[cast.spell] or AtBind() ) then
		KeepBind(cont, x, y)
	elseif Known(cast.spell) then
		saved.teleports[cast.spell] = { cont = cont, x = x, y = y, name = SpellName(cast.spell) };
	end
	Travel:Clear()
end

local function Cast(spellID)
	if ( type(spellID) ~= 'number' or InCombatLockdown() ) then return end;
	local cont, x, y = R:Where();
	if not cont then return end;
	local cast = { spell = spellID, cont = cont, x = x, y = y };
	pending = cast;
	for _, after in ipairs({ 3, 6, 10, 16, 25 }) do
		C_Timer.After(after, function() R.Try('teleport landing', Landed, cast) end)
	end
end

---------------------------------------------------------------
-- What can be used now
---------------------------------------------------------------
local function Over(start, duration)
	start, duration = tonumber(start), tonumber(duration);
	return not start or not duration or start == 0 or ( start + duration - GetTime() ) <= 0;
end

local function ItemReady(itemID)
	local okC, count = pcall(C_Item.GetItemCount, itemID);
	if not ( okC and type(count) == 'number' and count > 0 ) then
		return false;
	end
	local ok, start, duration = pcall(C_Container.GetItemCooldown, itemID);
	return ok and Over(start, duration);
end

local function SpellReady(spellID)
	if not Known(spellID) then
		return false;
	end
	local okU, usable = pcall(C_Spell.IsSpellUsable, spellID);
	if not ( okU and usable ) then
		return false;
	end
	local ok, info = pcall(C_Spell.GetSpellCooldown, spellID);
	return ok and type(info) == 'table' and Over(info.startTime, info.duration);
end

local function Options(cont, x, y)
	local saved = R:GetSaved();
	local out = {};
	if not saved then return out end;
	local function Add(option, place)
		-- (a landing place you are standing at is no shortcut)
		if ( place.cont ~= cont or Dist(place.x, place.y, x, y) > FAR ) and ( #out < MOST ) then
			option.cont, option.x, option.y = place.cont, place.x, place.y;
			out[#out + 1] = option;
		end
	end
	local bind = saved.binds[R:Character()];
	if ( bind and bind.name == BindName() ) then
		if ItemReady(HEARTH_ITEM) then
			Add({ kind = 'item', id = HEARTH_ITEM, label = ('Hearthstone to %s'):format(bind.name) }, bind)
		elseif SpellReady(ASTRAL) then
			Add({ kind = 'spell', id = ASTRAL, label = ('%s to %s'):format(SpellName(ASTRAL), bind.name) }, bind)
		end
	end
	for spellID, place in pairs(saved.teleports) do
		if ( type(spellID) == 'number' and type(place) == 'table' and SpellReady(spellID) ) then
			Add({ kind = 'spell', id = spellID, label = place.name or SpellName(spellID) }, place)
		end
	end
	return out;
end

---------------------------------------------------------------
-- The button
---------------------------------------------------------------
-- Secure, so a click or the binding can cast. Its attributes and
-- its showing change only out of combat; in a fight it is hidden by
-- the game's own state driver.
local Button = CreateFrame('Button', 'PatchwerkRouteTravel', UIParent, 'SecureActionButtonTemplate');
Button:SetSize(40, 40)
Button:SetPoint('TOP', UIParent, 'TOP', 0, -150)
Button:RegisterForClicks('AnyUp')
Button:SetAttribute('useOnKeyDown', false)
Button:Hide()
Button.Icon = Button:CreateTexture(nil, 'ARTWORK')
Button.Icon:SetAllPoints()
Button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
Button.Text = Button:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
Button.Text:SetPoint('TOP', Button, 'BOTTOM', 0, -4)
Button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]], 'ADD')

local suggestion, shown, wanted;

-- nil where the way from here has no price to compare with (another continent, no way known)
local function Minutes(seconds)
	if ( type(seconds) ~= 'number' or seconds > 6 * 3600 ) then
		return nil;
	end
	local minutes = math.floor(seconds / 60 + 0.5);
	return minutes <= 1 and 'about a minute' or ('about %d min'):format(minutes);
end

-- the button as `wanted` says (nil: put away); in a fight, once it is over
local function Apply()
	if InCombatLockdown() then return end;
	if ( wanted == shown ) then return end;
	shown = wanted;
	if not wanted then
		UnregisterStateDriver(Button, 'visibility')
		Button:SetAttribute('type', nil)
		Button:Hide()
		return;
	end
	local icon;
	if ( wanted.kind == 'item' ) then
		Button:SetAttribute('type', 'item')
		Button:SetAttribute('item', 'item:' .. wanted.id)
		local ok, texture = pcall(C_Item.GetItemIconByID, wanted.id);
		icon = ok and texture;
	else
		Button:SetAttribute('type', 'spell')
		Button:SetAttribute('spell', wanted.id)
		local ok, texture = pcall(C_Spell.GetSpellTexture, wanted.id);
		icon = ok and texture;
	end
	Button.Icon:SetTexture(icon or 134400)
	local saves = Minutes(wanted.saving);
	Button.Text:SetText(saves and ('%s\nsaves %s'):format(wanted.label, saves) or wanted.label)
	RegisterStateDriver(Button, 'visibility', '[combat] hide; show')
end

function Travel:Clear()
	suggestion, wanted = nil, nil;
	Apply()
end

local function Suggest(option, saving)
	local same = suggestion and suggestion.kind == option.kind and suggestion.id == option.id;
	option.saving = saving;
	suggestion, wanted = option, option;
	Apply()
	if not same then
		local saves = Minutes(saving);
		R:Say(('%s %s. Click the button at the top of the screen, or use the Route: Use Suggested Shortcut binding.')
			:format(option.label, saves and ('would get you there %s sooner'):format(saves) or 'is the quick way there'))
	end
end

function Travel:Suggestion()
	return suggestion;
end

---------------------------------------------------------------
-- Pricing
---------------------------------------------------------------
local look = { at = 0 };

local function Decide(dest, here, options)
	local _, now = M:CurrentRoute();
	if ( now ~= dest ) then return end;
	local best;
	for _, option in ipairs(options) do
		if ( option.cost and ( not best or option.cost < best.cost ) ) then
			best = option;
		end
	end
	if not ( best and here ) then
		return Travel:Clear();
	end
	local with = best.cost + OVERHEAD;
	if ( here - with >= WORTH and with <= here * SHARE ) then
		Suggest(best, here - with)
	else
		Travel:Clear()
	end
end

local function Look(force)
	if ( look.busy or not R:Active() or not R:Get('travel') ) then return end;
	if ( InCombatLockdown() or UnitOnTaxi('player') or UnitIsDeadOrGhost('player') or IsInInstance() ) then return end;
	local route, dest = M:CurrentRoute();
	if not ( route and type(dest) == 'table' and dest.cont and dest.x and dest.y ) then
		look.dest = nil;
		return Travel:Clear();
	end
	local now = GetTime();
	if ( not force and dest == look.dest and now - look.at < AGAIN ) then return end;
	local cont, x, y = R:Where();
	if not cont then return end;
	look.dest, look.at = dest, now;
	local options = Options(cont, x, y);
	if ( #options == 0 ) then
		return Travel:Clear();
	end

	local goal = { { dest.cont, dest.x, dest.y } };
	local here;
	local function Finish()
		look.busy = false;
		R.Try('shortcut choice', Decide, dest, here, options)
	end
	local function Price(i)
		local option = options[i];
		if not option then
			return Finish();
		end
		local ok, asked = pcall(M.PriceFrom, M, { option.cont, option.x, option.y }, goal, function(costs)
			option.cost = type(costs) == 'table' and tonumber(costs[1]) or nil;
			Price(i + 1)
		end);
		if not ( ok and asked ) then
			Finish()
		end
	end
	look.busy = true;
	local ok, asked = pcall(M.PriceFrom, M, { cont, x, y }, goal, function(costs)
		here = type(costs) == 'table' and tonumber(costs[1]) or nil;
		if ( not here and dest.cont ~= cont ) then
			here = math.huge;   -- (no way from here at all: another continent)
		end
		Price(1)
	end);
	if not ( ok and asked ) then
		-- (the road map is still being built: soon again)
		look.busy = false;
		look.at = now - AGAIN + 10;
	end
end

function Travel:Look()
	R.Try('shortcut pricing', Look, true)
end

---------------------------------------------------------------
-- Events
---------------------------------------------------------------
local Watcher = CreateFrame('Frame')
Watcher:RegisterEvent('HEARTHSTONE_BOUND')
Watcher:RegisterEvent('PLAYER_REGEN_ENABLED')
Watcher:RegisterUnitEvent('UNIT_SPELLCAST_SUCCEEDED', 'player')
Watcher:SetScript('OnEvent', function(_, event, _, _, spellID)
	if ( event == 'HEARTHSTONE_BOUND' ) then
		C_Timer.After(0.5, function()
			R.Try('hearthstone bind', function()
				KeepBind(R:Where())
				look.at = 0;
			end)
		end)
	elseif ( event == 'PLAYER_REGEN_ENABLED' ) then
		R.Try('shortcut button', Apply)
	else
		R.Try('teleport cast', Cast, spellID)
	end
end)

local elapsed = 0;
Watcher:SetScript('OnUpdate', function(_, dt)
	elapsed = elapsed + dt;
	if ( elapsed < 5 ) then return end;
	elapsed = 0;
	R.Try('shortcut pricing', Look)
end)
R:OnSetting('travel', function()
	if not R:Get('travel') then
		Travel:Clear()
	end
	look.at = 0;
end)
