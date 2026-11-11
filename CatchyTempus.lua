-- Optional Tempus settings bridge. This file deliberately loads after every Catchy
-- settings page so Tempus receives the final page definitions, including Journal,
-- Locations and Outfits replacements.
local _, FBI = ...
local Settings = FBI and FBI.Settings
local Tempus = _G.Tempus

if not (Settings and Tempus and Tempus.RegisterPage and Tempus.pageSections) then return end

local SECTION_KEY = "catchy"
local sectionExists = false
for _, section in ipairs(Tempus.pageSections) do
    if section.key == SECTION_KEY then
        sectionExists = true
        break
    end
end
if not sectionExists then
    Tempus.pageSections[#Tempus.pageSections + 1] = { key = SECTION_KEY, label = "Catchy" }
end

local sectionOrder = {}
for index, section in ipairs(Settings.sections or {}) do
    sectionOrder[section.key] = index
end

for index, definition in ipairs(Settings.pages or {}) do
    local source = definition
    Tempus:RegisterPage(SECTION_KEY, {
        key = "catchy_" .. source.key,
        label = source.label,
        order = (sectionOrder[source.section] or 50) * 100 + (source.order or index),
        build = function(page)
            Settings:Mixin(page)
            source.build(page)
        end,
    })
end

Settings.hosted = true

local function FindNavigation(frame)
    if not frame then return end
    if frame.items and frame.child and frame.SetVerticalScroll then return frame end
    if not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        local navigation = FindNavigation(child)
        if navigation then return navigation end
    end
end

function Settings:ScrollHostedPageIntoView(pageKey)
    local function scroll()
        if not (Tempus.Options and Tempus.Options.current == pageKey) then return end
        local navigation = FindNavigation(_G.TempusOptionsFrame)
        if not navigation then return end

        for _, item in ipairs(navigation.items) do
            if item.selected and item:IsShown() then
                local top, bottom = navigation:GetTop(), navigation:GetBottom()
                local itemTop, itemBottom = item:GetTop(), item:GetBottom()
                if not (top and bottom and itemTop and itemBottom) then return end
                local position = navigation:GetVerticalScroll()
                local margin = 8
                if itemTop > top - margin then
                    position = position + top - margin - itemTop
                elseif itemBottom < bottom + margin then
                    position = position + bottom + margin - itemBottom
                end
                local limit = math.max(0, navigation.child:GetHeight() - navigation:GetHeight())
                navigation:SetVerticalScroll(math.max(0, math.min(limit, position)))
                return
            end
        end
    end

    if C_Timer and C_Timer.After then C_Timer.After(0, scroll) else scroll() end
end
