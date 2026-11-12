-- A selected lure starts a retry delay before GetUpdateLure consumes its plan.
local now = 100
function GetTime() return now end
function GetLocale() return "enUS" end
tinsert = table.insert
C_Container = { GetItemCooldown = function() return 0, 0, 1 end }
EventRegistry = { RegisterCallback = function() end }
local lure = { id = 6533, n = "Aquadynamic Fish Attractor", b = 100 }
local lib = {
    IsFishingPole = function() return true end,
    GetCurrentSkill = function() return 1 end,
    GetPoleBonus = function() return 0, 0 end,
    GetCurrentMapContinent = function() return 1 end,
    FindBestLure = function() return 1, lure end,
    HasLureBuff = function() return false end,
    GetLureInventory = function() return {}, {} end,
    UpdateLureInventory = function() end,
    GetFishingSpellInfo = function() return 7731, "Fishing" end,
}
function LibStub() return lib end
local handlers
local FBI = {
    FBConstants = {},
    GetSettingBool = function(_, key) return key == "EasyLures" end,
    RegisterHandlers = function(_, h) handlers = h end,
    SetupSpecialItems = function() end,
    UpdateFluffOption = function() end,
}
assert(loadfile("FishingPlans.lua"))("Catchy", FBI)
assert(loadfile("FishingPlans/Lures.lua"))("Catchy", FBI)
handlers.VARIABLES_LOADED()
FBI.FishingPlans:ExecutePlans()
assert(FBI.FishingPlans:HavePlans(), "lure was not queued")
assert(FBI.LureStateManager:LuringCheck(), "selection should establish the retry delay")

local file = assert(io.open("Catchy.lua", "r"))
local source = file:read("*a"); file:close()
local update = assert(source:match("(function FBI:GetUpdateLure%(%)%s.-)local CaptureEvents"))
local env = setmetatable({ FBI = FBI, FL = lib, PLANS = FBI.FishingPlans }, { __index = _G })
local chunk = assert(loadstring(update))
setfenv(chunk, env); chunk()
local use, id = FBI:GetUpdateLure()
assert(use and id == lure.id, "retry delay swallowed the selected lure")
assert(not FBI.FishingPlans:HavePlans(), "selected lure should be consumed once")
assert(not FBI:GetUpdateLure(), "retry delay should still prevent immediate retry")
FBI.LureStateManager.AddingLure = true
function UnitChannelInfo() return nil end
assert(FBI.LureStateManager:LuringComplete())
assert(not FBI.LureStateManager:GetLastLure(), "a finished or failed application must release casting")
handlers.UNIT_SPELLCAST_CHANNEL_START("pet", nil, 123)
assert(not FBI.LureStateManager:GetLastLure(), "another unit must not lock casting")
handlers.UNIT_SPELLCAST_CHANNEL_START("player", nil, 7731)
assert(not FBI.LureStateManager.LastLure, "fishing must clear stale lure state")
print("lure plan smoke: ok")
