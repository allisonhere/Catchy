-- The Recorded tab must mirror Locations' saved FishingHoles totals.
local file = assert(io.open("CatchyJournal.lua", "r"))
local source = file:read("*a")
file:close()
local prefix = assert(source:match("^(.-)local function TopRow"))

Catchy_Info = {
    FishingHoles = {
        [1438001] = { [6303] = 8 },
        [1439001] = { [6303] = 1, [6289] = 2 },
    },
}
LibStub = function()
    return { GetLocZone = function(_, id)
        return ({ [1438] = "Teldrassil", [1439] = "Darkshore" })[id]
    end }
end
local fbi = { ZoneMarkerEx = function(_, marker) return math.floor(marker / 1000), marker % 1000 end }
assert(loadstring(prefix))("Catchy", fbi)
local recorded = fbi.Journal.RecordedData()
assert(recorded.catches == 11, "recorded count did not match Locations")
assert(recorded.perFish[6303] == 9 and recorded.perFish[6289] == 2,
       "fish counts did not combine across locations")
assert(recorded.zones[1438].catches == 8 and recorded.zones[1439].catches == 3,
       "zone counts did not combine correctly")
print("Journal recorded smoke test passed")
