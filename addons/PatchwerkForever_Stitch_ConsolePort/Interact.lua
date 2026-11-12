local _, env = ...;
local db = env.db;
if not env.NativeContext then return end;
---------------------------------------------------------------
-- Interact from rings and macros
---------------------------------------------------------------
-- Console Port binds Interact by clicking Forever's reserved
-- interact button, and offers it to rings too. A ring runs it as
-- /click, which on Forever sends only the release; the interact
-- button acts on a press followed by a release (tap to interact,
-- hold to auto loot), so a lone release does nothing. Rings get a
-- stand-in instead, which clicks the interact button with a press
-- and a release (a tap; holding is not possible this way). The
-- keybinding itself is left alone, since a bound key sends both.

local INTERACT = db.Bindings.Custom.Interact;
local target = type(INTERACT) == 'string' and INTERACT:match('^CLICK (.+):LeftButton$');
if not target then return end;

local Tap = CreateFrame('Button', 'PatchwerkInteractTap', UIParent, 'SecureActionButtonTemplate')
Tap:RegisterForClicks('AnyUp')
Tap:SetAttribute('useOnKeyDown', false)
Tap:SetAttribute('type', 'macro')
Tap:SetAttribute('macrotext', ('/click %s LeftButton true\n/click %s LeftButton'):format(target, target))

local TAP_BINDING = 'CLICK PatchwerkInteractTap:LeftButton';

db.Bindings.Custom.PatchwerkInteract = TAP_BINDING;
db.Bindings.Macroable.PatchwerkInteract = true;
db.Bindings.Macroable.Interact = nil;
db.Bindings.DefaultIcons[TAP_BINDING] = db.Bindings.DefaultIcons[INTERACT];

tinsert(db.Bindings.Special, {
	binding = TAP_BINDING;
	name    = ('%s (tap)'):format(env.L.NAME_INTERACT or INTERACT);
	desc    = 'Interact with a tap, for rings and macros. Holding to auto loot only works with the Interact binding itself.';
})
