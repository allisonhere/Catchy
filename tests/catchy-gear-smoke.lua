-- Catchy Gear: set storage, status, equip, the fishing swap and the paperdoll UI.
local function Widget()
    return setmetatable({ shown = true }, { __index = function(self, key)
        if key == "SetScript" then return function(s, event, cb) s[event] = cb end end
        if key == "CreateTexture" or key == "CreateFontString" then return function() return Widget() end end
        if key == "SetShown" then return function(s, v) s.shown = v end end
        if key == "GetWidth" then return function() return 400 end end
        if key == "GetText" then return function() return rawget(self, "text") or "" end end
        if key == "SetText" then return function(s, v) s.text = v end end
        return function() end
    end })
end
function CreateFrame() return Widget() end
GameTooltip = Widget()

local worn, bags, equipped, combat = {}, {}, {}, false
local SLOT_IDS = { HeadSlot = 1, ChestSlot = 5, MainHandSlot = 16 }
function GetInventorySlotInfo(slot) return SLOT_IDS[slot] or 99 end
function GetInventoryItemLink(_, id) return worn[id] end
function GetInventoryItemTexture(_, id) return worn[id] and "tex" .. id end
function InCombatLockdown() return combat end
NUM_BAG_SLOTS = 1
C_Container = {
    GetContainerNumSlots = function(bag) return bag == 0 and #bags or 0 end,
    GetContainerItemLink = function(bag, index) return bags[index] end,
}
function EquipItemByName(link, id) equipped[#equipped + 1] = { link, id }; worn[id] = link end
function IsShiftKeyDown() return false end

local function link(id) return "|cff0070dd|Hitem:" .. id .. "::::::::|h[Item " .. id .. "]|h|r" end

Catchy_Player = {}
local registered
local FBI = { FBConstants = { NAME = "Catchy" }, UIError = function(_, m) FBI.lastError = m end,
              Print = function() end }
FBI.Settings = { Kit = {
    COL_W = 280, COL_GAP = 22, MARGIN = 22, AC = { 0.2, 0.8, 1 },
    C = { card = { 0, 0, 0 }, field = { 0, 0, 0 }, muted = { 1, 1, 1 }, text = { 1, 1, 1 } },
    Tex = function() return Widget() end, Text = function() return Widget() end,
    Border = function() return { SetColor = function() end } end,
    FlatButton = function() local w = Widget(); w.bg = Widget(); return w end,
    StyledEditBox = function() return Widget() end, SetGradient = function() end,
} }
FBEnvironment = { OutfitManager = { RegisterManager = function(name, i, c, s) registered = { name = name, switch = s } end,
                                      ItemStylePoints = function() return 2 end } }
function LibStub() return { FishingBonusPoints = function() return 5 end } end

assert(loadfile("CatchyGearManager.lua"))("Catchy", FBI)
local Gear = FBI.Gear
assert(registered and registered.name == "Catchy Gear", "manager was not registered")

-- build a fishing set from what is worn
worn[16], worn[1] = link(1001), link(2002)
assert(Gear:Create("Fishing", true) == "Fishing")
assert(Gear:Count("Fishing") == 2, "saved the wrong number of slots")
assert(not Gear:Create("Fishing"), "duplicate names must be refused")
assert(not Gear:Create("  "), "blank names must be refused")
local skill, style = Gear:Points("Fishing")
assert(skill == 10 and style == 4, "points should sum over items")

-- change gear: head is replaced, the fishing hat is now in the bags
worn[1] = link(3003)
bags = { link(2002) }
local states, totals = Gear:Status("Fishing")
assert(states.MainHandSlot == "worn" and states.HeadSlot == "bag", "status mismatch")
assert(totals.worn == 1 and totals.bag == 1 and totals.missing == 0)

-- swap on, then back
assert(registered.switch() == true, "first switch should put the set on")
assert(worn[1] == link(2002), "hat was not equipped")
assert(Gear:IsWorn("Fishing"))
bags = { link(3003) }
assert(registered.switch() == false, "second switch should restore")
assert(worn[1] == link(3003), "old head piece was not restored")

-- combat blocks swaps
combat = true
local changed, err = Gear:Equip("Fishing")
assert(changed == nil and err, "combat must block equipping")
combat = false

-- a missing item is reported, not equipped
bags = {}
worn[1] = link(3003)
local _, t2 = Gear:Status("Fishing")
assert(t2.missing == 1)

-- slot edits and deletion
Gear:SetSlot("Fishing", "HeadSlot", nil)
assert(Gear:Count("Fishing") == 1)
assert(Gear:Delete("Fishing") and #Gear:List() == 0)

-- the paperdoll builds and refreshes with and without a set
assert(loadfile("CatchyGear.lua"))("Catchy", FBI)
local added = {}
FBI.GearUI.Build({ Section = function() end, Add = function(_, w) added[#added + 1] = w end })
assert(#added == 1)
added[1]:Refresh()
Gear:Create("Travel", true)
added[1]:Refresh()
print("catchy gear smoke: ok")
