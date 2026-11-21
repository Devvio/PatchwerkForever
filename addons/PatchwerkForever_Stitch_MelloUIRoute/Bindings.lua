-- The Key Bindings list names this part's five CLICK bindings (Bindings.xml) by these globals. They
-- are set here, right after Link.lua and before anything can stop early: the files that make the buttons
-- return when MelloUI's Route is not running, and the list would then show the bindings by their code names.
BINDING_HEADER_PATCHWERKFOREVER_MELLOUIROUTE = 'Patchwerk Forever: MelloUI Route (Stitch)';
for button, name in pairs({
	PatchwerkRouteBlock    = 'Route: Mark Trail Ahead Blocked',
	PatchwerkRouteQuestRun = 'Route: Quest Run',
	PatchwerkRouteNextStop = 'Route: Next Quest Run Stop',
	PatchwerkRouteUnblock  = 'Route: Undo Blocked Spot',
	PatchwerkRouteTravel   = 'Route: Use Suggested Shortcut',
}) do
	_G['BINDING_NAME_CLICK ' .. button .. ':LeftButton'] = name;
end
