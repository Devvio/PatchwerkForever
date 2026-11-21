-- Globe (Thread): its own pictures of the world, and how the world is laid on the globe. Written by
-- tools/globe_art.py (python globe_art.py world).
local ADDON, ns = ...

-- rw: yards of the world to a radian of the globe; sea: its colour; each continent's middle on the
-- globe (latitude, longitude, radians) and in its own terrain tiles (column, row)
ns.LAYOUT = { rw = 19000, sea = { 0.550, 0.622, 0.585 }, continents = {
	[1] = { lat = 0.0500, lon = -1.0500, cx = 34.067814, cy = 31.814777 },
	[0] = { lat = 0.1000, lon = 1.0500, cx = 34.161685, cy = 40.505435 },
	[2991] = { lat = -0.7500, lon = 0.0000, cx = 29.500000, cy = 26.000000 },
} }

-- the whole world in pieces: each a picture, and the longitudes and latitudes it covers (west to east,
-- north to south)
ns.ART = {
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\world_0_0', kind = 'world', lon = { -3.141593, -1.570796 }, lat = { 1.570796, 0.000000 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\world_0_1', kind = 'world', lon = { -1.570796, 0.000000 }, lat = { 1.570796, 0.000000 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\world_0_2', kind = 'world', lon = { 0.000000, 1.570796 }, lat = { 1.570796, 0.000000 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\world_0_3', kind = 'world', lon = { 1.570796, 3.141593 }, lat = { 1.570796, 0.000000 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\world_1_0', kind = 'world', lon = { -3.141593, -1.570796 }, lat = { 0.000000, -1.570796 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\world_1_1', kind = 'world', lon = { -1.570796, 0.000000 }, lat = { 0.000000, -1.570796 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\world_1_2', kind = 'world', lon = { 0.000000, 1.570796 }, lat = { 0.000000, -1.570796 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\world_1_3', kind = 'world', lon = { 1.570796, 3.141593 }, lat = { 0.000000, -1.570796 } },

	-- each continent in detail (8 yards a pixel): a picture, its map and the terrain tiles it covers
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_3_1', kind = 'detail', map = 1, columns = { 24, 32 }, rows = { 8, 16 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_4_1', kind = 'detail', map = 1, columns = { 32, 40 }, rows = { 8, 16 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_5_1', kind = 'detail', map = 1, columns = { 40, 48 }, rows = { 8, 16 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_3_2', kind = 'detail', map = 1, columns = { 24, 32 }, rows = { 16, 24 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_4_2', kind = 'detail', map = 1, columns = { 32, 40 }, rows = { 16, 24 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_5_2', kind = 'detail', map = 1, columns = { 40, 48 }, rows = { 16, 24 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_3_3', kind = 'detail', map = 1, columns = { 24, 32 }, rows = { 24, 32 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_4_3', kind = 'detail', map = 1, columns = { 32, 40 }, rows = { 24, 32 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_5_3', kind = 'detail', map = 1, columns = { 40, 48 }, rows = { 24, 32 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_3_4', kind = 'detail', map = 1, columns = { 24, 32 }, rows = { 32, 40 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_4_4', kind = 'detail', map = 1, columns = { 32, 40 }, rows = { 32, 40 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_5_4', kind = 'detail', map = 1, columns = { 40, 48 }, rows = { 32, 40 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_2_5', kind = 'detail', map = 1, columns = { 16, 24 }, rows = { 40, 48 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_3_5', kind = 'detail', map = 1, columns = { 24, 32 }, rows = { 40, 48 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_4_5', kind = 'detail', map = 1, columns = { 32, 40 }, rows = { 40, 48 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_5_5', kind = 'detail', map = 1, columns = { 40, 48 }, rows = { 40, 48 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_3_6', kind = 'detail', map = 1, columns = { 24, 32 }, rows = { 48, 56 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_4_6', kind = 'detail', map = 1, columns = { 32, 40 }, rows = { 48, 56 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\1_5_6', kind = 'detail', map = 1, columns = { 40, 48 }, rows = { 48, 56 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_4_2', kind = 'detail', map = 0, columns = { 32, 40 }, rows = { 16, 24 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_5_2', kind = 'detail', map = 0, columns = { 40, 48 }, rows = { 16, 24 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_3_3', kind = 'detail', map = 0, columns = { 24, 32 }, rows = { 24, 32 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_4_3', kind = 'detail', map = 0, columns = { 32, 40 }, rows = { 24, 32 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_5_3', kind = 'detail', map = 0, columns = { 40, 48 }, rows = { 24, 32 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_3_4', kind = 'detail', map = 0, columns = { 24, 32 }, rows = { 32, 40 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_4_4', kind = 'detail', map = 0, columns = { 32, 40 }, rows = { 32, 40 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_5_4', kind = 'detail', map = 0, columns = { 40, 48 }, rows = { 32, 40 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_3_5', kind = 'detail', map = 0, columns = { 24, 32 }, rows = { 40, 48 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_4_5', kind = 'detail', map = 0, columns = { 32, 40 }, rows = { 40, 48 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_5_5', kind = 'detail', map = 0, columns = { 40, 48 }, rows = { 40, 48 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_3_6', kind = 'detail', map = 0, columns = { 24, 32 }, rows = { 48, 56 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_4_6', kind = 'detail', map = 0, columns = { 32, 40 }, rows = { 48, 56 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_5_6', kind = 'detail', map = 0, columns = { 40, 48 }, rows = { 48, 56 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_3_7', kind = 'detail', map = 0, columns = { 24, 32 }, rows = { 56, 64 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\0_4_7', kind = 'detail', map = 0, columns = { 32, 40 }, rows = { 56, 64 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\2991_3_2', kind = 'detail', map = 2991, columns = { 24, 32 }, rows = { 16, 24 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\2991_3_3', kind = 'detail', map = 2991, columns = { 24, 32 }, rows = { 24, 32 } },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\2991_4_3', kind = 'detail', map = 2991, columns = { 32, 40 }, rows = { 24, 32 } },

	-- the hand-made ink pieces on the open sea: a picture, its middle (latitude, longitude), how far
	-- across it is (radians); flip: turned to face the other way
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\decor_compass', kind = 'decor', lat = 0.6200, lon = 0.0000, size = 0.4600 },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\decor_serpent', kind = 'decor', lat = -0.3000, lon = 2.4500, size = 0.5200 },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\decor_ship', kind = 'decor', lat = -0.4000, lon = -2.3500, size = 0.4300 },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\decor_serpent2', kind = 'decor', lat = 0.3500, lon = 3.0500, size = 0.4600, flip = true },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\decor_ship', kind = 'decor', lat = -0.1500, lon = 0.5500, size = 0.3400, flip = true },
	{ file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\decor_maelstrom', kind = 'decor', lat = 0.0500, lon = 0.0000, size = 0.4000 },
}

-- the brass ring and stand round the ball: in parts of the picture's side, the middle of its hole (across
-- and down), the hole's radius, and the top and bottom of what is drawn
ns.RING = { file = 'Interface\\AddOns\\' .. ADDON .. '\\Art\\ring', cx = 0.5, cy = 0.3561, inner = 0.2468, top = 0.0098, bottom = 0.9834 }
