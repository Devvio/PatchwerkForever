local addonName, ns = ...;
---------------------------------------------------------------
-- Joining the base
---------------------------------------------------------------
-- This addon is a part of Patchwerk Forever. The base holds what
-- the parts share: the saved data, the settings and their page,
-- and /patchwerk. Joining it puts those on this addon's own table
-- (ns:AddSetting, ns:GetSaved, ns:RegisterFix, ...), where the
-- files after this one find them. Without a base new enough,
-- ns.linked stays unset and those files do nothing.

-- the base's API this part was written for, and the first base version that has it
local API, NEEDS = 1, '2.0.0';

local Base = rawget(_G, 'PatchwerkForever');
if not ( type(Base) == 'table' and type(Base.Link) == 'function' and Base:Link(addonName, ns, API) ) then
	-- (said with the addon's title, as the addon list shows it, rather than its folder)
	local meta = C_AddOns and C_AddOns.GetAddOnMetadata;
	local ok, title = pcall(meta, addonName, 'Title');
	title = ok and type(title) == 'string' and title or addonName;
	print(('|cffd6a35b%s|r needs Patchwerk Forever %s or later and is not running. Update Patchwerk Forever.'):format(title, NEEDS))
end
