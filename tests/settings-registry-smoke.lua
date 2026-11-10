local function Read(path)
    local file = assert(io.open(path, "rb"))
    local contents = file:read("*a")
    file:close()
    return contents
end

local options = Read("FishingOptionsFrame.lua")
assert(options:find("FBI%.OptionsTable%s*=%s*FBOptionsTable"),
    "modern settings registry is not connected to the legacy option registry")

local toc = Read("Catchy.toc")
local optionsAt = assert(toc:find("FishingOptionsFrame%.lua"), "options file missing from TOC")
local settingsAt = assert(toc:find("CatchySettings%.lua"), "modern settings file missing from TOC")
assert(optionsAt < settingsAt, "option registry must load before modern settings")

local settings = Read("CatchySettings.lua")
for _, page in ipairs({ "EasyCast", "WatchFishies", "FishingFluff" }) do
    assert(settings:find(page, 1, true), "settings page mapping missing: " .. page)
end

print("settings registry smoke: ok")
