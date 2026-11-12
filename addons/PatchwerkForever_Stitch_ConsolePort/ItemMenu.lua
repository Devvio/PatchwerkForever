local _, env = ...;
if not env.NativeContext then return end;
---------------------------------------------------------------
-- Item menu equip slots
---------------------------------------------------------------
-- Console Port's item menu only maps a few equip locations to
-- slots; any other item is equipped into the slot whose ID equals
-- its inventory type. That holds for the armour pieces whose type
-- happens to match their slot, but not for robes (20), held
-- off-hand items (23), bows (15, the cloak slot), thrown weapons,
-- wands, guns and crossbows (25, 26) or relics (28), which get a
-- wrong or missing slot. Forever has a real ranged slot for them.

local LOCATIONS = {
	INVTYPE_ROBE        = {'CHESTSLOT'};
	INVTYPE_HOLDABLE    = {'SECONDARYHANDSLOT'};
	INVTYPE_RANGED      = {'RANGEDSLOT'};
	INVTYPE_RANGEDRIGHT = {'RANGEDSLOT'};
	INVTYPE_THROWN      = {'RANGEDSLOT'};
	INVTYPE_RELIC       = {'RANGEDSLOT'};
};

local function GetSlotID(slotName)
	local ok, slotID = pcall(CPAPI.GetInventorySlotInfo, slotName);
	if ( ok and slotID ) then
		return slotID;
	end
	return ( slotName == 'RANGEDSLOT' ) and INVSLOT_RANGED or nil;
end

for location, slotNames in pairs(LOCATIONS) do
	local slots = {};
	for _, slotName in ipairs(slotNames) do
		slots[#slots + 1] = GetSlotID(slotName);
	end
	LOCATIONS[location] = ( #slots > 0 ) and slots or nil;
end

EventUtil.ContinueOnAddOnLoaded('ConsolePort_Menu', function()
	local ItemMenu = ConsolePortItemMenu;
	if not ( ItemMenu and ItemMenu.AddEquipCommands and ItemMenu.GetEquipCommand ) then return end;

	local AddEquipCommands = ItemMenu.AddEquipCommands;

	-- As Console Port's own (ConsolePort_Menu's ItemMenu:AddEquipCommands,
	-- (c) Sebastian Lindfors, Artistic License 2.0), with the fixed
	-- slots: a free slot's command goes first.
	function ItemMenu:AddEquipCommands()
		local slots = LOCATIONS[self:GetInventoryLocation()];
		if not slots then
			return AddEquipCommands(self)
		end
		local commands, foundFree = {}, false;
		for i, slot in ipairs(slots) do
			local command = self:GetEquipCommand(slot, i, #slots);
			if ( command.free and not foundFree ) then
				foundFree = true;
				tinsert(commands, 1, command)
			else
				tinsert(commands, command)
			end
		end
		for _, command in ipairs(commands) do
			self:AddCommand(command.text, 'Equip', command.data, command.handlers)
		end
	end
end)
