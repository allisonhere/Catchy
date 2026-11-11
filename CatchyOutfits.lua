-- Catchy: Outfits page
-- The Outfits page is Catchy Gear, Catchy's own equipment manager (CatchyGear.lua).
-- Opening the page makes sure Catchy Gear is the manager the fishing swap uses.
local addonName, FBI = ...
local FBConstants = FBI.FBConstants
local Settings = FBI.Settings
if not Settings then return end

local function BuildOutfits(p)
    local manager = FBEnvironment and FBEnvironment.OutfitManager
    if manager and manager.ChooseManager and manager.CurrentManager and manager.CurrentManager() ~= "Catchy Gear" then
        manager.ChooseManager("Catchy Gear")
    end
    if FBI.GearUI then
        FBI.GearUI.Build(p)
    else
        p:Paragraph("The gear manager is unavailable.", 0, { 1, 0.45, 0.45 })
    end
end

Settings:SetPage({ section = "fishing", key = "outfits", label = FBConstants.OUTFITS or "Outfits", order = 2,
    build = BuildOutfits })
