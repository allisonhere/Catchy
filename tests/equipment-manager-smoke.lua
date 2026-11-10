local used, saved

local function Widget()
    return setmetatable({ shown = true }, { __index = function(_, key)
        if key == "SetScript" then return function(self, event, callback) self[event] = callback end end
        if key == "CreateTexture" or key == "CreateFontString" then return function() return Widget() end end
        if key == "SetShown" then return function(self, shown) self.shown = shown end end
        return function() end
    end })
end

function CreateFrame() return Widget() end
function InCombatLockdown() return false end
function GetInventorySlotInfo() return 16 end
function GetInventoryItemLink() return nil end
function EquipItemByName() end
function GetContainerItemLink() return nil end
function GetEquipmentSetLocations() return {} end
function strupper(value) return string.upper(value) end
function gsub(...) return string.gsub(...) end

EQUIPMENT_MANAGER = "Equipment Manager"
SKILL = "Skill"
GameTooltip = Widget()

C_EquipmentSet = {
    GetEquipmentSetIDs = function() return { 11, 22 } end,
    GetEquipmentSetID = function(name) return name == "Catchy" and 11 or nil end,
    GetEquipmentSetInfo = function(id)
        if id == 11 then return "Catchy", 134400, 11, false, 10, 4, 10, 0, 0 end
        return "Questing", 134414, 22, true, 12, 12, 12, 0, 0
    end,
    GetItemLocations = function() return {} end,
    UseEquipmentSet = function(id) used = id end,
    SaveEquipmentSet = function(id) saved = id end,
    CreateEquipmentSet = function() error("existing Catchy set should be saved") end,
    ClearIgnoredSlotsForSave = function() end,
    IgnoreSlotForSave = function() end,
    UnignoreSlotForSave = function() end,
    DeleteEquipmentSet = function() end,
    GetNumEquipmentSets = function() return 2 end,
}

local FL = {
    IsFishingReady = function() return false end,
    GetFishingSpellInfo = function() return true, "Fishing" end,
    GetFishingOutfitItems = function() return {} end,
    FishingBonusPoints = function() return 0 end,
    SplitLink = function(_, link) return nil, link end,
    GetItemInfo = function() return "Interface\\Icons\\Trade_Fishing" end,
}
function LibStub() return FL end

FBEnvironment = {
    OutfitManager = {
        ItemStylePoints = function() return 0 end,
        RegisterManager = function(name, initialize, choose, switch)
            FBEnvironment.registered = { name = name, initialize = initialize, choose = choose, switch = switch }
        end,
    },
}

local messages = {}
local FBI = {
    FBConstants = { NAME = "Catchy", POINT = "point", POINTS = "points" },
    UIError = function(_, message) error(message) end,
    Print = function(_, message) messages[#messages + 1] = message end,
    GetSettingBool = function() return false end,
    Dump = function() end,
}

assert(loadfile("FishingGearManager.lua"))("Catchy", FBI)
assert(FBI.GearSets, "modern gear-set facade missing")
local sets = FBI.GearSets:List()
assert(#sets == 2 and sets[1].name == "Catchy", "equipment sets were not listed")
assert(FBI.GearSets:Equip(22) and used == 22, "modern UseEquipmentSet was not called")
assert(FBI.GearSets:SaveCatchy() and saved == 11, "Catchy set was not saved")
assert(FBEnvironment.registered.name == EQUIPMENT_MANAGER, "equipment manager was not registered")

FBEnvironment.OutfitManagers = { [EQUIPMENT_MANAGER] = {}, None = {} }
FBEnvironment.OutfitManager.CurrentManager = function() return EQUIPMENT_MANAGER end
FBEnvironment.OutfitManager.ChooseManager = function() return true end
FBEnvironment.OutfitManager.Switch = function() return true end

local outfitsPage
local function Primitive() return Widget() end
FBI.Settings = {
    Kit = {
        Tex = Primitive, Text = Primitive, Border = Primitive, FlatButton = Primitive,
        W = { Dropdown = function() return Widget(), 48 end },
        C = { text = {}, muted = {}, card = {}, field = {} }, AC = {},
        COL_W = 280, COL_GAP = 22,
    },
    SetPage = function(_, page) outfitsPage = page end,
    Open = function() end,
    Close = function() end,
}

assert(loadfile("CatchyOutfits.lua"))("Catchy", FBI)
assert(outfitsPage, "modern Outfits page was not registered")
local page = {
    Section = function() end, Paragraph = function() end, Newline = function() end,
    Options = function() end, Add = function(_, widget) if widget.Refresh then widget:Refresh() end end,
    Button = function() return Widget() end,
}
outfitsPage.build(page)
print("equipment manager smoke: ok")
