-- Catch Map: catches are binned into cells with per-fish counts, filtered and bounded.
local now = 1000
function time() return now end
local pos = { 0.5000, 0.5000 }
function GetPlayerFacing() return nil end
function LibStub()
    return {
        GetCurrentPlayerPosition = function() return 1, 1438, pos[1], pos[2] end,
        GetZoneSize = function() return 1000, 1000 end,
    }
end
local FBI = { commands = {} }
function FBI:AddCommand(name, fn) self.commands[name] = fn end
function FBI:GetCurrentMapIdInfo() return 1438 end
function FBI:Print() end
Catchy_Info = {}
assert(loadfile("CatchyCatchMap.lua"))("Catchy", FBI)
local M = FBI.CatchMap

-- one catch saves a cell at the player's position
assert(M:Record(6303, 1, 1438) == true)
local cells = M:Cells(1438)
assert(#cells == 1 and cells[1].n == 1 and math.abs(cells[1].x - 0.5) < 1e-9)

-- a nearby catch lands in the same cell and the position averages
pos = { 0.5010, 0.5010 }
now = 2000
M:Record(6303, 2, 1438)
M:Record(6289, 1, 1438)
cells = M:Cells(1438)
assert(#cells == 1 and cells[1].n == 4, "close catches share a cell")
assert(cells[1].fish[6303] == 3 and cells[1].fish[6289] == 1)
assert(cells[1].last == 2000)

-- a distant catch is a new cell
pos = { 0.9, 0.2 }
M:Record(6289, 1, 1438)
assert(#M:Cells(1438) == 2)

-- the fish filter only counts that fish
local only = M:Cells(1438, 6289)
assert(#only == 2 and only[1].n + only[2].n == 2)
assert(#M:Cells(1438, 9999) == 0)

-- summary
local s = M:Summary(1438)
assert(s.total == 5 and s.spots == 2 and s.fish[1].id == 6303 and s.fish[1].count == 3)

-- nothing is recorded without an id, a map or a position
assert(M:Record(nil, 1, 1438) == false and M:Record(6303, 1, nil) == false)
pos = { 0, 0 }
assert(M:Record(6303, 1, 1438) == false, "no position, no record")

-- explicit coordinates win, and the cell count is bounded
for i = 1, 1600 do
    now = 3000 + i
    M:Record(1, 1, 99, (i % 200) / 200 + 0.0025, math.floor(i / 200) / 10 + 0.0025)
end
local kept = 0
for _ in pairs(Catchy_Info.CatchSpots[99]) do kept = kept + 1 end
assert(kept <= 1500, "cells per map must be capped")
assert(FBI.commands.spots and FBI.commands.spots())
print("catch map smoke: ok")
