-- Forever uses Retail UI behavior but exposes an unsplit fishing profession.
local file = assert(io.open("Libs/LibFishing-1.0/LibFishing-1.0.lua", "r"))
local source = file:read("*a"); file:close()
local skillSource = assert(source:match("(function FishLib:GetContinentSkill%(continent%).-)\n%-%- get our current fishing skill level"))
local lib = {
    IsClassic = function() return false end,
    GetPoleBonus = function() return 0, 25 end,
    continent_fishing = {},
}
local env = setmetatable({
    FishLib = lib, WOW = { interface = 16001 },
    GetProfessions = function() return 6, 9, 5, 8, 7 end,
    GetProfessionInfo = function(index)
        assert(index == 8, "Fishing spell ID was used as a profession index")
        return "Fishing", 136245, 145, 150, 2, 44, 356, 0
    end,
}, { __index = _G })
local chunk = assert(loadstring(skillSource)); setfenv(chunk, env); chunk()
local rank, modifier, maximum, lure = lib:GetContinentSkill(nil)
assert(rank == 145 and modifier == 0 and maximum == 150 and lure == 25,
    "Forever must read profession skill without a continent cache or Classic detection")
print("Forever fishing skill smoke: ok")
