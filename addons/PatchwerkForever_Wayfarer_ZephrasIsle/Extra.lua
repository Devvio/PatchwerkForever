-- Made by pack.py from the game's own files. Do not edit: run pack.py again.
PatchwerkForever_WayfarerData = PatchwerkForever_WayfarerData or {}
local M = PatchwerkForever_WayfarerData[2991] or { cells = {}, graph = {} }
PatchwerkForever_WayfarerData[2991] = M
M.cell, M.tile, M.speed, M.tick = 4.166666666666667, 533.3333333333334, 7.0, 0.05
M.factor = { 1.0, 1.25, 3.0 }
M.air = { speed = 32.0, board = 15.0, land = 3.0 }
-- ways the ground does not show: { block, gate, block, gate, seconds }
M.links = {
}
-- flight points: { id, name, cell x, cell y, sides, walked to or not, seconds to climb to it, { gate, seconds, gate, seconds, ... } }
M.points = {
}
-- flights: { from, to, seconds }
M.flights = {
}
