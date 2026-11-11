-- Catchy Gear: Catchy's own equipment manager.
-- Stores named gear sets per character, equips them from bags, and registers itself as an
-- outfit manager so the existing fishing swap (click, macro, /ca switch) can use it.
-- The visual editor lives in CatchyGear.lua.
local addonName, FBI = ...
local FBConstants = FBI.FBConstants
local FL = LibStub("LibFishing-1.0")

local Gear = {}
FBI.Gear = Gear

local MANAGER_NAME = "Catchy Gear"
local DEFAULT_SET = "Fishing"
Gear.MANAGER_NAME = MANAGER_NAME
Gear.MAX_SETS = 8

Gear.SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot",
}

local function ItemId(link)
    return link and tonumber(string.match(link, "item:(%d+)"))
end
Gear.ItemId = ItemId

local function Store()
    Catchy_Player = Catchy_Player or {}
    local store = Catchy_Player.Gear
    if not store then
        store = { sets = {}, order = {}, active = nil, restore = nil }
        Catchy_Player.Gear = store
    end
    return store
end

local function SlotId(slot)
    return (GetInventorySlotInfo(slot))
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

-- What is worn in one slot, in the shape stored in a set.
local function Capture(slot)
    local id = SlotId(slot)
    local link = id and GetInventoryItemLink("player", id)
    if not link then return nil end
    return { link = link, texture = GetInventoryItemTexture and GetInventoryItemTexture("player", id) or nil }
end
Gear.Capture = Capture

-- Every item id currently in the bags, mapped to how many copies.
local function BagCounts()
    local counts = {}
    local container = C_Container or {}
    local numSlots = container.GetContainerNumSlots or GetContainerNumSlots
    local getLink = container.GetContainerItemLink or GetContainerItemLink
    if not (numSlots and getLink) then return counts end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for index = 1, (numSlots(bag) or 0) do
            local id = ItemId(getLink(bag, index))
            if id then counts[id] = (counts[id] or 0) + 1 end
        end
    end
    return counts
end

function Gear:List()
    local store = Store()
    local names = {}
    for _, name in ipairs(store.order) do
        if store.sets[name] then names[#names + 1] = name end
    end
    return names
end

function Gear:Get(name)
    return Store().sets[name]
end

function Gear:Active()
    local store = Store()
    if store.active and store.sets[store.active] then return store.active end
    return store.order[1]
end

function Gear:SetActive(name)
    local store = Store()
    if store.sets[name] then store.active = name end
end

function Gear:Create(name, fromWorn)
    name = name and string.match(name, "^%s*(.-)%s*$") or ""
    if name == "" then return nil, "Give the set a name." end
    local store = Store()
    if store.sets[name] then return nil, "A set named " .. name .. " already exists." end
    if #store.order >= Gear.MAX_SETS then return nil, "You can keep up to " .. Gear.MAX_SETS .. " sets." end
    store.sets[name] = { slots = {} }
    store.order[#store.order + 1] = name
    store.active = name
    if fromWorn then self:SaveWorn(name) end
    return name
end

function Gear:Delete(name)
    local store = Store()
    if not store.sets[name] then return false end
    store.sets[name] = nil
    for i, n in ipairs(store.order) do
        if n == name then table.remove(store.order, i) break end
    end
    if store.active == name then store.active = store.order[1] end
    return true
end

-- Replace the whole set with everything currently worn.
function Gear:SaveWorn(name)
    local set = Store().sets[name]
    if not set then return false end
    set.slots = {}
    for _, slot in ipairs(Gear.SLOTS) do
        set.slots[slot] = Capture(slot)
    end
    return true
end

-- Store (or clear, with info == nil) one slot.
function Gear:SetSlot(name, slot, info)
    local set = Store().sets[name]
    if not set then return false end
    set.slots[slot] = info
    return true
end

function Gear:Count(name)
    local n = 0
    local set = Store().sets[name]
    for _ in pairs(set and set.slots or {}) do n = n + 1 end
    return n
end

-- Per-slot state for a set: "worn", "bag" or "missing". Also returns totals.
function Gear:Status(name)
    local set = Store().sets[name]
    local states, totals = {}, { worn = 0, bag = 0, missing = 0, total = 0 }
    if not set then return states, totals end
    local bags = BagCounts()
    for slot, info in pairs(set.slots) do
        local id = ItemId(info.link)
        local worn = ItemId(GetInventoryItemLink("player", SlotId(slot)))
        local state
        if worn and worn == id then
            state = "worn"
        elseif id and (bags[id] or 0) > 0 then
            state = "bag"
        else
            state = "missing"
        end
        states[slot] = state
        totals[state] = totals[state] + 1
        totals.total = totals.total + 1
    end
    return states, totals
end

-- Fishing skill and style points for everything stored in a set.
function Gear:Points(name)
    local set = Store().sets[name]
    local skill, style = 0, 0
    local styleOf = FBEnvironment and FBEnvironment.OutfitManager and FBEnvironment.OutfitManager.ItemStylePoints
    for _, info in pairs(set and set.slots or {}) do
        local id, enchant = string.match(info.link or "", "item:(%d+):?(%d*)")
        if id then
            enchant = tonumber(enchant) or 0
            local okSkill, bonus = pcall(FL.FishingBonusPoints, FL, id .. ":" .. enchant)
            if okSkill and type(bonus) == "number" then skill = skill + bonus end
            if styleOf then
                local okStyle, points = pcall(styleOf, id, enchant)
                if okStyle and type(points) == "number" then style = style + points end
            end
        end
    end
    return skill, style
end

local function EquipInfo(info, slot)
    local id = SlotId(slot)
    if not (id and info and info.link) then return false end
    EquipItemByName(info.link, id)
    return true
end

-- Put a set on. Returns the number of slots changed, or nil and a reason.
function Gear:Equip(name)
    local set = Store().sets[name]
    if not set then return nil, "That set no longer exists." end
    if InCombat() then return nil, "Gear cannot be changed during combat." end
    local states = self:Status(name)
    local changed = 0
    for slot, info in pairs(set.slots) do
        if states[slot] == "bag" and EquipInfo(info, slot) then changed = changed + 1 end
    end
    Store().active = name
    return changed
end

-- Remember what is worn in the slots a set will replace, so the swap can be undone.
local function Snapshot(name)
    local set = Store().sets[name]
    local snapshot = {}
    for slot in pairs(set and set.slots or {}) do
        snapshot[slot] = Capture(slot)
    end
    return snapshot
end

local function Restore(snapshot)
    local changed = 0
    for slot, info in pairs(snapshot or {}) do
        if EquipInfo(info, slot) then changed = changed + 1 end
    end
    return changed
end

-- Is every stored item of this set currently on the character?
function Gear:IsWorn(name)
    local _, totals = self:Status(name)
    return totals.total > 0 and totals.worn == totals.total
end

-- Fishing swap used by /ca switch, the minimap click and the macro.
-- Returns true when the fishing set is now on, false when the old gear came back.
local function Switch()
    local name = Gear:Active()
    if not name or Gear:Count(name) == 0 then
        FBI:UIError("Save a gear set first: open Catchy settings, Outfits.")
        return nil
    end
    if InCombat() then return nil end
    local store = Store()
    if Gear:IsWorn(name) and store.restore then
        Restore(store.restore)
        store.restore = nil
        return false
    end
    if not Gear:IsWorn(name) then
        store.restore = Snapshot(name)
        Gear:Equip(name)
    end
    return true
end
Gear.Switch = Switch

if FBEnvironment and FBEnvironment.OutfitManager and FBEnvironment.OutfitManager.RegisterManager then
    FBEnvironment.OutfitManager.RegisterManager(MANAGER_NAME,
        function() return true end,
        function() end,
        Switch)
end

Gear.DEFAULT_SET = DEFAULT_SET

-- Catchy Gear is the fishing swap's manager. Choose it once everything has loaded.
local chooser = CreateFrame("Frame")
chooser:RegisterEvent("PLAYER_LOGIN")
chooser:SetScript("OnEvent", function()
    local manager = FBEnvironment and FBEnvironment.OutfitManager
    if manager and manager.ChooseManager and manager.CurrentManager and manager.CurrentManager() ~= MANAGER_NAME then
        manager.ChooseManager(MANAGER_NAME)
    end
end)
