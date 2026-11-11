-- Exercise the Journal's catch accounting without loading the frame-heavy HUD.
local source = assert(io.open("CatchyDashboard.lua", "r")):read("*a")
local statsSource = assert(source:match("^(.-)local eventFrame = CreateFrame"))

local now = 100
local wall = 1794418000
GetTime = function() return now end
time = function() return wall end
date = function() return "2026-11-11" end
GetRealZoneText = function() return "Darkshore" end
PROFESSIONS_FISHING = "Fishing"
Catchy_Player = {}

local fishing = { IsMissedFish = function() return false end }
LibStub = function() return fishing end
local fbi = {
    FBConstants = {},
    GetCurrentMapIdInfo = function() return 62 end,
    GetChannelInfo = function() return nil end,
    AddFishie = function() end,
}

local chunk = assert(loadstring(statsSource))
chunk("Catchy", fbi)
local stats = assert(fbi.Stats)
local _, session = stats:GetDatabase()

local link = "|cnIQ1:|Hitem:6303::::::::|h[Raw Slitherskin Mackerel]|h|r"
assert(stats.ParseOwnLootMessage("You receive loot: " .. link .. ".") == 6303)
local id, count = stats.ParseOwnLootMessage("You receive loot: " .. link .. "x2.")
assert(id == 6303 and count == 2, "chat stack amount was lost")
assert(stats.ParseOwnLootMessage("Alice receives loot: " .. link .. ".") == nil,
       "another player's loot must not count")

stats:Cast()
stats:MarkFishingEnded()
stats:LootMessage("You receive loot: " .. link .. ".")
assert(session.casts == 1 and session.catches == 1 and session.perFish[6303] == 1,
       "chat fallback did not record the catch")
stats:ObserveCatch("slot", 6303, 1)
assert(session.catches == 1 and session.perFish[6303] == 1,
       "the loot slot counted the same item twice")

now = now + 1
stats:Cast()
stats:ObserveCatch("slot", 6303, 2)
stats:MarkFishingEnded()
stats:LootMessage("You receive loot: " .. link .. "x2.")
assert(session.casts == 2 and session.catches == 2 and session.perFish[6303] == 3,
       "slot-first stack was counted twice")

now = now + 1
stats:Cast()
stats:MarkFishingEnded()
stats:LootMessage("Alice receives loot: " .. link .. ".")
assert(session.catches == 2, "other player's loot was counted")
now = now + 6
stats:LootMessage("You receive loot: " .. link .. ".")
assert(session.catches == 2, "unrelated later loot was counted")

print("Journal loot smoke test passed")
