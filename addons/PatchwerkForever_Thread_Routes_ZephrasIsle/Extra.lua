-- Made by pack.py from the game's own files. Do not edit: run pack.py again.
PatchwerkForever_Thread_RoutesData = PatchwerkForever_Thread_RoutesData or {}
local M = PatchwerkForever_Thread_RoutesData[2991] or { cells = {}, graph = {} }
PatchwerkForever_Thread_RoutesData[2991] = M
M.cell, M.tile, M.speed, M.tick = 4.166666666666667, 533.3333333333334, 7.0, 0.05
M.factor = { 1.0, 1.25, 3.0 }
M.air = { speed = 32.0, board = 15.0, land = 3.0 }
-- with roads (a search option): a cell off the road costs `off` times as much
M.road = { off = 2.0 }
M.roads = M.roads or {}
M.roadgraph = M.roadgraph or {}
-- ways the ground does not show: { block, gate, block, gate, seconds }, with a 1 after them for
-- one that only goes from the first to the second (a drop)
M.links = {
{25719,7,25719,8,0.82},
{28533,8,28534,9,11.68},
{26488,11,26488,12,15.72},
{24952,4,25208,8,16.16},
}
-- flight points: { id, name, cell x, cell y, sides, walked to or not, seconds to climb to it, { gate, seconds, gate, seconds, ... }, with roads { gate, cost, seconds, ... } }
M.points = {
}
-- flights: { from, to, seconds }
M.flights = {
}
