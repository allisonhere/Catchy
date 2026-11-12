local file = assert(io.open("Libs/LibFishing-1.0/LibFishing-1.0.lua", "r"))
local source = file:read("*a"); file:close()
local method = assert(source:match("(function FishLib:InvokeLuring%(id, itemtype%).-)\nfunction FishLib:InvokeMacro"))
local attributes, tool, bound = {}, nil, false
local button = { SetAttribute = function(_, key, value) attributes[key] = value end }
local lib = {
    CleanSAButton = function() attributes = {}; return button end,
    ValidLink = function(_, id) return "item:" .. id end,
    GetFishingToolItem = function() return tool end,
    SetOverrideBindingClick = function() bound = true end,
}
local env = setmetatable({ FishLib = lib, INVSLOT_FISHING_TOOL = 28, INVSLOT_MAINHAND = 16 }, { __index = _G })
local chunk = assert(loadstring(method)); setfenv(chunk, env); chunk()
lib:InvokeLuring(6533)
assert(bound and attributes.type == "item" and attributes.item == "item:6533")
assert(attributes["target-slot"] == 16, "main-hand pole must receive the lure")
tool = "item:retail-pole"
lib:InvokeLuring(6533)
assert(attributes["target-slot"] == 28, "profession tool must receive the lure")
lib:InvokeLuring(123, "toy")
assert(attributes.type == "toy" and not attributes["target-slot"])
print("lure target smoke: ok")
