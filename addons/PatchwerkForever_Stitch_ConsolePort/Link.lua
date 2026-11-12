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

local API = 1;   -- the base's API this part was written for

local Base = rawget(_G, 'PatchwerkForever');
if not ( type(Base) == 'table' and type(Base.Link) == 'function' and Base:Link(addonName, ns, API) ) then
	print(('|cffd6a35bPatchwerk|r %s needs a newer Patchwerk Forever (the base addon). It is not running.'):format(addonName))
end
