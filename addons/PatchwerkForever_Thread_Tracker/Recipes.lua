-- Tracker (Thread): the recipes you track.
--
-- A recipe ticked "track" in a profession window is listed with what it needs and how much of each
-- you have (bags, bank and reagent bank together, as the game's own tracker counts). The game is
-- asked the way its own tracker asks: C_TradeSkillUI.GetRecipesTracked and GetRecipeSchematic.
-- A click opens the recipe; a right-click offers to stop tracking it.
local ADDON, ns = ...
if not ns.linked then return end

local waiting = false         -- an item's name was not known yet when last drawn

local function Ask(fn, ...)
	if type(fn) ~= 'function' then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

local function Have(id)
	return Ask(C_Item and C_Item.GetItemCount, id, true, false, true) or Ask(rawget(_G, 'GetItemCount'), id, true) or 0
end

local function Name(id)
	local name = Ask(C_Item and C_Item.GetItemNameByID, id)
	if type(name) == 'string' and name ~= '' then return name end
	-- (the game has not been told this item yet: it is asked for, and the list drawn again when it comes)
	waiting = true
	Ask(C_Item and C_Item.RequestLoadItemDataByID, id)
	return 'item ' .. tostring(id)
end

-- What a recipe needs: { { text, done } ... }, the reagents every making of it takes.
local function Needs(schematic)
	local lines = {}
	local basic = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
	for _, slot in ipairs(type(schematic.reagentSlotSchematics) == 'table' and schematic.reagentSlotSchematics or {}) do
		local first = type(slot) == 'table' and type(slot.reagents) == 'table' and slot.reagents[1]
		if first and first.itemID and slot.required ~= false and (slot.reagentType == nil or slot.reagentType == basic) then
			local need = tonumber(slot.quantityRequired) or 1
			local have = 0
			for _, reagent in ipairs(slot.reagents) do           -- (any quality of it counts)
				if reagent.itemID then have = have + Have(reagent.itemID) end
			end
			lines[#lines + 1] = { text = ('%d/%d %s'):format(have, need, Name(first.itemID)), done = have >= need }
		end
	end
	return lines
end

local function Open(id)
	if InCombatLockdown() then
		ns.Print('Recipes cannot be opened in combat.')
		return
	end
	if not (C_TradeSkillUI and type(C_TradeSkillUI.OpenRecipe) == 'function' and pcall(C_TradeSkillUI.OpenRecipe, id)) then
		ns.Print('The recipe could not be opened on this client.')
	end
end

ns.AddSection('recipes', 70, function()
	if not (ns.Get('recipes') and C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked) then return nil end
	waiting = false
	local blocks = {}
	for _, recraft in ipairs({ false, true }) do
		for _, id in ipairs(Ask(C_TradeSkillUI.GetRecipesTracked, recraft) or {}) do
			local schematic = Ask(C_TradeSkillUI.GetRecipeSchematic, id, recraft)
			if type(schematic) == 'table' then
				local lines, all = Needs(schematic), true
				for _, line in ipairs(lines) do all = all and line.done end
				local r, g, b = ns.RGB(ns.Get((all and #lines > 0) and 'lookDone' or 'lookTitle'))
				local title = schematic.name or ('Recipe ' .. tostring(id))
				blocks[#blocks + 1] = { key = (recraft and 'r' or '') .. tostring(id), title = title, r = r, g = g, b = b, lines = lines,
					tip = { 'Click to open this recipe.', 'Right-click for more options.' },
					click = function(button, block)
						if button == 'RightButton' then
							ns.Menu(block, title, {
								{ 'Open Recipe', function() Open(id) end },
								{ 'Untrack Recipe', function()
									Ask(C_TradeSkillUI.SetRecipeTracked, id, false, recraft)
									ns.Refresh()
								end },
							})
						else
							Open(id)
						end
					end }
			end
		end
	end
	return { title = 'Recipes', note = tostring(#blocks), blocks = blocks }
end)

for _, event in ipairs({ 'TRACKED_RECIPE_UPDATE', 'BAG_UPDATE_DELAYED' }) do
	ns.Try('listening for ' .. event, ns.On, event, ns.Refresh)
end
ns.Try('listening for GET_ITEM_INFO_RECEIVED', ns.On, 'GET_ITEM_INFO_RECEIVED', function()
	if waiting then ns.Refresh() end
end)
