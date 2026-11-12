-- Passive lure information for the fishing HUD. Never selects or uses an item.
local _, FBI = ...
local FL = LibStub("LibFishing-1.0")
local Status = {}
FBI.LureStatus = Status

local function Remaining(seconds)
    if type(seconds) ~= "number" or seconds <= 0 then return nil end
    seconds = math.ceil(seconds)
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function PoleEnchant()
    if FL:GetFishingToolItem(true) then
        if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
            local active, remaining = C_PaperDollInfo.GetTemporaryEnchantmentInfo(28)
            if type(active) == "table" then
                -- Table clients do not consistently expose a remaining duration.
                if active.hasTempEnchant ~= nil then return active.hasTempEnchant, nil end
                return type(active.enchantID) == "number" and active.enchantID > 0, nil
            end
            return active, type(remaining) == "number" and remaining / 1000 or nil
        end
    elseif GetWeaponEnchantInfo then
        local active, remaining = GetWeaponEnchantInfo()
        return active, type(remaining) == "number" and remaining / 1000 or nil
    end
end

local function ReadStatus()
    local auto = FBI:GetSettingBool("EasyLures")
    local autoLabel = auto and "Auto-lure on" or "Auto-lure off"
    if not FL:IsFishingPole() then
        return "No fishing pole", auto and "Equip a pole to use auto-lure" or autoLabel, "idle"
    end

    if FL.GetActiveLureInfo then
        local name, expires = FL:GetActiveLureInfo()
        if name then
            local timer = expires and Remaining(expires - GetTime())
            return name .. (timer and ("  " .. timer) or ""), autoLabel, "active"
        end
    end
    local active, remaining = PoleEnchant()
    if active then
        local timer = Remaining(remaining)
        return "Pole lure" .. (timer and ("  " .. timer) or ""), autoLabel, "active"
    end

    if not auto then return "No lure active", autoLabel, "idle" end
    if FL:InCombat() then return "No lure active", "Auto-lure paused during combat", "idle" end
    if not FBI:GetSettingBool("EasyCast") then
        return "No lure active", "Enable Easy Cast to apply lures", "idle"
    end
    if FBI.ActiveSetting and not FBI:ActiveSetting("MountedCast") then
        return "No lure active", "Dismount to apply a lure", "idle"
    end
    if FBI.ActiveSetting and not FBI:ActiveSetting("FlyingCast") then
        return "No lure active", "Land to apply a lure", "idle"
    end
    local state = FBI.LureStateManager
    local adding, last
    if state then adding, last = state:GetLastLure() end
    if adding then return "Applying lure", "Waiting for application to finish", "pending" end
    if last and last.time and last.time > GetTime() then
        return "No lure active", "Auto-lure retry in " .. math.ceil(last.time - GetTime()) .. "s", "pending"
    end

    local skill, modifier = FL:GetCurrentSkill()
    if not skill or skill <= 0 then
        return "No lure active", "Fishing skill is not available yet", "idle"
    end
    local required = FL:GetCurrentFishingLevel()
    if not FBI:GetSettingBool("AlwaysLure") and required and skill + (modifier or 0) > required then
        return "No lure active", "Skill is sufficient for this area", "idle"
    end
    local inventory = FL:GetLureInventory()
    if not inventory or #inventory == 0 then
        return "No lure active", "No usable lures detected in bags", "idle"
    end
    return "No lure active", "Auto-lure checks on your next double-click", "pending"
end

function Status:Get()
    -- Aura and enchant fields can be restricted during combat on modern clients.
    local ok, label, detail, kind = pcall(ReadStatus)
    if ok then return label, detail, kind end
    return "Lure status unavailable", "Waiting for readable fishing data", "idle"
end
