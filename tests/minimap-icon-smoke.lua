local expectedLua = "Interface\\\\AddOns\\\\Catchy\\\\media\\\\Catchy-Minimap"
local expectedToc = "Interface\\AddOns\\Catchy\\media\\Catchy-Minimap"

for _, path in ipairs({ "CatchyMinimap.lua", "FB_Broker.lua" }) do
    local source = assert(io.open(path, "rb")):read("*a")
    assert(source:find(expectedLua, 1, true), path .. " does not use the Catchy minimap icon")
end

local toc = assert(io.open("Catchy.toc", "rb")):read("*a")
assert(toc:find(expectedToc, 1, true), "addon metadata does not use the Catchy minimap icon")

local asset = assert(io.open("media/Catchy-Minimap.tga", "rb"))
local bytes = asset:read("*a")
asset:close()
assert(#bytes > 18, "minimap texture is empty")
local width = bytes:byte(13) + bytes:byte(14) * 256
local height = bytes:byte(15) + bytes:byte(16) * 256
assert(width == 128 and height == 128, "minimap texture must be 128x128")

print("minimap icon smoke: ok")
