-- The Journal must record the same catch Locations stores, even if a later
-- Watcher/UI callback throws an error.
local file = assert(io.open("FishingDatabase.lua", "r"))
local source = file:read("*a")
file:close()
local addFishie = assert(source:match("(function FBI:AddFishie.-\nend)\n\n%-%- we want to dismiss"))

Catchy_Info = {
    Fishies = { [6303] = { enUS = "Raw Slitherskin Mackerel" } },
    FishTotals = {}, FishingHoles = {}, FishingSkill = {},
}
local recorded = 0
local fbi = {
    Stats = { ObserveCatch = function(_, sourceName, id, count)
        assert(sourceName == "slot" and id == 6303)
        recorded = recorded + count
    end },
    GetSettingBool = function() return false end,
    AddZoneIndex = function() return 1438, 1 end,
    RunHandlers = function() error("later Watcher callback failed") end,
}
local fl = {
    IsMissedFish = function() return false end,
    GetCurrentSkill = function() return 0, 0 end,
}
local setup = [[
    local FBI, FL = ...
    local CurLoc = "enUS"
    local QuestItems = {}
    local zmto = function(zone, sub) return zone * 1000 + sub end
    local GetQualityColorHex = function() return "|cffffffff" end
    local GSB = function() return false end
]]
FBI = fbi
FBConstants = { ADD_FISHIE_EVT = "AddFishie" }
tinsert = table.insert
local chunk = assert(loadstring(setup .. addFishie))
chunk(fbi, fl)

local ok = pcall(function()
    fbi:AddFishie(nil, 6303, "Raw Slitherskin Mackerel", 1438,
                  "Rut'theran Village", 133910, 1, 1)
end)
assert(not ok, "the simulated Watcher failure did not run")
assert(Catchy_Info.FishingHoles[1438001][6303] == 1, "Locations lost the catch")
assert(recorded == 1, "Journal did not receive the saved catch before the UI failure")
print("Journal source smoke test passed")
