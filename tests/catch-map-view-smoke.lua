-- Catch Map view: zone list, fish choices, and the fish and time filters.
local now = 1000000
function time() return now end
function CreateFrame() return setmetatable({}, { __index = function() return function() end end }) end
function LibStub() return {} end
C_Map = { GetMapInfo = function(id) return ({ [1438] = { name = "Teldrassil" }, [1439] = { name = "Darkshore" } })[id] end }
local FBI = { commands = {} }
function FBI:AddCommand() end
function FBI:GetFishie(id) return nil, nil, nil, nil, nil, ({ [6303] = "Raw Brilliant Smallfish", [6289] = "Raw Longjaw Mud Snapper" })[id] end

Catchy_Info = { CatchSpots = {
    [1438] = {
        [1] = { x = 0.1, y = 0.1, n = 5, last = now - 60, fish = { [6303] = 5 } },
        [2] = { x = 0.5, y = 0.5, n = 3, last = now - 3 * 86400, fish = { [6289] = 3 } },
    },
    [1439] = { [1] = { x = 0.2, y = 0.2, n = 9, last = now - 40 * 86400, fish = { [6303] = 9 } } },
} }
assert(loadfile("CatchyCatchMap.lua"))("Catchy", setmetatable(FBI, { __index = function() return nil end }))
FBI.AddCommand = function() end
assert(loadfile("CatchyCatchMapView.lua"))("Catchy", FBI)
local V = FBI.CatchMapView

local zones = V:Zones()
assert(#zones == 2 and zones[1].mapId == 1439 and zones[1].total == 9 and zones[1].name == "Darkshore")
assert(zones[2].name == "Teldrassil" and zones[2].spots == 2)
assert(V.ZoneName(77777) == "Map 77777", "unknown maps get a placeholder name")

local fish = V:FishChoices()
assert(fish[1].id == 6303 and fish[1].count == 14 and fish[1].name == "Raw Brilliant Smallfish")
assert(#V:FishChoices(1438) == 2 and V:FishChoices(1439)[1].count == 9)

-- default filter is any time (window 1), all fish
V.filter.window = 1
assert(#V:Visible(1438) == 2 and V:Visible(1438)[1].n == 5, "sorted by catches")
V.filter.fish = 6289
local only = V:Visible(1438)
assert(#only == 1 and only[1].n == 3, "fish filter")
V.filter.fish = nil
V.filter.window = 2   -- last 24 hours
assert(#V:Visible(1438) == 1 and V:Visible(1438)[1].n == 5, "time filter drops old spots")
V.filter.window = 3   -- last 7 days
assert(#V:Visible(1438) == 2 and #V:Visible(1439) == 0)
V.filter.window = 4   -- last 30 days
assert(#V:Visible(1439) == 0)

-- heat runs from cool to hot
local r1, _, b1 = V.HeatColor(0)
local r2, g2, b2 = V.HeatColor(1)
assert(b1 > r1 and r2 == 1 and g2 < 0.5 and b2 < 0.3)

-- opening and closing without a world map must not error
V:Open(1438, 6303)
assert(V.enabled and V.filter.fish == 6303)
V:Close()
assert(not V.enabled)

-- tile layout: a 1002x668 layer of 256px tiles is 4x3 tiles, edge tiles cropped
local tiles = V.TileLayout(1002, 668, 256, 256, 0.5)
assert(#tiles == 12, "4 columns by 3 rows")
assert(tiles[1].x == 0 and tiles[1].y == 0 and tiles[1].w == 128 and tiles[1].right == 1)
assert(math.abs(tiles[4].w - (1002 - 768) * 0.5) < 1e-9 and tiles[4].right < 1, "right edge cropped")
assert(math.abs(tiles[12].h - (668 - 512) * 0.5) < 1e-9 and tiles[12].bottom < 1, "bottom edge cropped")
assert(#V.TileLayout(nil, 1, 1, 1, 1) == 0 and #V.TileLayout(10, 10, 0, 0, 1) == 0)

-- the map fits its box and is centred
local scale, ox, oy, mw, mh = V.FitMap(1000, 500, 500, 500)
assert(scale == 0.5 and ox == 0 and oy == 125 and mw == 500 and mh == 250)

-- art info needs the client's map-art API
assert(V.ArtInfo(1438) == nil, "no art API, no art")
C_Map.GetMapArtLayers = function() return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end
C_Map.GetMapArtLayerTextures = function() return { 1, 2, 3 } end
local art = V.ArtInfo(1438)
assert(art and art.layerW == 1002 and #art.textures == 3)

-- Exploration overlays use padded edge textures, unlike the base map tiles.
assert(#V.ExploredTiles(1438, art, 0.5) == 0, "missing exploration API is safe")
C_MapExplorationInfo = { GetExploredMapTextures = function(id)
    assert(id == 1438)
    return {
        { textureWidth = 300, textureHeight = 270, offsetX = 100, offsetY = 50,
          fileDataIDs = { 11, 12, 13, 14 } },
        { textureWidth = 100, textureHeight = 100, offsetX = -20, offsetY = -10,
          fileDataIDs = { 15 }, isDrawOnTopLayer = true },
        { textureWidth = 100, textureHeight = 100, offsetX = 0, offsetY = 0,
          fileDataIDs = { 99 }, isShownByMouseOver = true },
    }
end }
local explored = V.ExploredTiles(1438, art, 0.5)
assert(#explored == 5, "only discovered, non-hover overlays should render")
assert(explored[1].id == 11 and explored[1].x == 50 and explored[1].y == 25)
assert(explored[4].id == 14 and explored[4].w == 22 and explored[4].h == 7)
assert(explored[4].right == 44 / 64 and explored[4].bottom == 14 / 16,
    "padded exploration edge tiles must use their actual file dimensions")
assert(explored[5].x == 0 and explored[5].y == 0 and explored[5].w == 40 and explored[5].h == 45)
assert(explored[5].left == 20 / 128 and explored[5].top == 10 / 128 and explored[5].onTop,
    "overlays extending outside the map must be cropped with matching texture coordinates")
C_MapExplorationInfo.GetExploredMapTextures = function() return nil end
assert(#V.ExploredTiles(1438, art, 0.5) == 0, "zone switches must not reuse old exploration")

-- the showcase builds and refreshes with art, without art, and with no data
local function Widget()
    return setmetatable({ shown = true }, { __index = function(self, key)
        if key == "SetScript" then return function(s2, e, cb) s2[e] = cb end end
        if key == "SetShown" then return function(s2, v) s2.shown = v end end
        if key == "CreateTexture" or key == "CreateFontString" or key == "CreateAnimationGroup" or key == "CreateAnimation" then
            return function() return Widget() end
        end
        return function() end
    end })
end
function CreateFrame() return Widget() end
local K = { AC = { 0.2, 0.8, 1 }, C = { muted = { 1, 1, 1 }, text = { 1, 1, 1 } },
    Tex = function() return Widget() end, Text = function() return Widget() end,
    Border = function() end, SetGradient = function() end,
    FlatButton = function() local w = Widget(); w.text = Widget(); return w end }
local box = V:BuildShowcase(K, 582, 400)
box:Refresh()
assert(V.selected == 1439, "defaults to the busiest zone")
V:Step(1); assert(V.selected == 1438)
V:Step(1); assert(V.selected == 1439, "stepping wraps")
C_Map.GetMapArtLayers = nil
box:Refresh()
Catchy_Info.CatchSpots = {}
V.selected = nil
box:Refresh()
assert(V.selected == nil)
local playerMap = 1438
C_Map.GetBestMapForUnit = function() return playerMap end
box:Refresh()
assert(V.selected == 1438, "current zone should display even without recorded catches")
Catchy_Info.CatchSpots[1439] = { [1] = { x = 0.2, y = 0.2, n = 1, fish = {} } }
V.selected = 1439
box:Refresh()
assert(V.selected == 1439, "manual browsing should persist while the player stays in a zone")
playerMap = 77777
box.OnUpdate(box, 0.5)
assert(V.selected == 77777, "visible showcase should follow a player zone change")
C_Map.GetBestMapForUnit = function() return nil end
box:Refresh()
assert(V.selected == 77777, "temporary missing map data should not change the map")
print("catch map view smoke: ok")
