local tool, active, remaining, aura, auraEnd, adding, last
local auto, always, pole, combat, skill, level = true, false, true, false, 145, 300
local easy, mounted, flying = true, true, true
local inventory = { { id = 6533 } }
local lib = {
    GetFishingToolItem = function() return tool end,
    IsFishingPole = function() return pole end,
    InCombat = function() return combat end,
    GetCurrentSkill = function() return skill, 0 end,
    GetCurrentFishingLevel = function() return level end,
    GetLureInventory = function() return inventory end,
    GetActiveLureInfo = function() return aura, auraEnd end,
}
function GetTime() return 100 end
function GetWeaponEnchantInfo() return active, remaining end
function LibStub() return lib end
local FBI = {
    GetSettingBool = function(_, key)
        if key == "EasyLures" then return auto end
        if key == "EasyCast" then return easy end
        return always
    end,
    ActiveSetting = function(_, key) if key == "MountedCast" then return mounted end return flying end,
    LureStateManager = { GetLastLure = function() return adding, last end },
}
assert(loadfile("CatchyLureStatus.lua"))("Catchy", FBI)
local function expect(labelPart, detailPart)
    local label, detail = FBI.LureStatus:Get()
    assert(label:find(labelPart, 1, true), "unexpected label: " .. label)
    assert(detail:find(detailPart, 1, true), "unexpected detail: " .. detail)
end
expect("No lure active", "next double-click")
easy = false; expect("No lure active", "Enable Easy Cast"); easy = true
mounted = false; expect("No lure active", "Dismount"); mounted = true
flying = false; expect("No lure active", "Land"); flying = true
active, remaining = true, 65000
expect("Pole lure  1:05", "Auto-lure on")
auto = false
expect("Pole lure  1:05", "Auto-lure off")
active = false
expect("No lure active", "Auto-lure off")
auto, adding = true, true
expect("Applying lure", "application")
adding, last = false, { time = 108 }
expect("No lure active", "retry in 8s")
last, inventory = nil, {}
expect("No lure active", "No usable lures")
skill = 350
expect("No lure active", "sufficient")
always = true
expect("No lure active", "No usable lures")
skill = 0
expect("No lure active", "skill is not available")
pole = false
expect("No fishing pole", "Equip a pole")
pole, combat = true, true
expect("No lure active", "paused during combat")
combat, aura, auraEnd = false, "Named lure", 160
expect("Named lure  1:00", "Auto-lure on")
aura, auraEnd, tool = nil, nil, 123
C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function() return { hasTempEnchant = true } end }
expect("Pole lure", "Auto-lure on")
C_PaperDollInfo.GetTemporaryEnchantmentInfo = function() return { hasTempEnchant = false, enchantID = 0 } end
expect("No lure active", "skill is not available")
lib.GetActiveLureInfo = function() error("restricted aura") end
expect("Lure status unavailable", "Waiting for readable")
print("lure status smoke: ok")
