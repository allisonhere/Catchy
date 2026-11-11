-- Catchy Catch Map: remembers where every catch happened.
-- Catches are binned into small map cells (half a percent of the map, a few dozen yards), so
-- the saved data stays small however much you fish. Each cell keeps its fish counts.
--   Catchy_Info["CatchSpots"][mapId][cell] = { x, y, n, first, last, fish = { [itemId] = count } }
local addonName, FBI = ...
local FL = LibStub("LibFishing-1.0")

local CatchMap = {}
FBI.CatchMap = CatchMap

local CELL = 0.005          -- map fraction per cell
local MAX_CELLS = 1500      -- per map; the least recently used cells go first
local BOBBER_YARDS = 15     -- the bobber lands this far in front of the player, as for schools

local function Root()
    Catchy_Info = Catchy_Info or {}
    Catchy_Info["CatchSpots"] = Catchy_Info["CatchSpots"] or {}
    return Catchy_Info["CatchSpots"]
end

-- Where the bobber most likely is: the player's position moved along the facing direction.
local function BobberPosition(mapId)
    local _, _, x, y = FL:GetCurrentPlayerPosition()
    if not (x and y) or (x == 0 and y == 0) then return end
    local facing = GetPlayerFacing and GetPlayerFacing()
    local width, height = FL:GetZoneSize(mapId)
    if facing and width and height and width > 0 and height > 0 then
        facing = facing + math.pi
        x = x + math.cos(facing) * BOBBER_YARDS / width
        y = y + math.sin(facing) * BOBBER_YARDS / height
    end
    if x < 0 or x > 1 or y < 0 or y > 1 then return end
    return x, y
end

local function CellKey(x, y)
    return math.floor(x / CELL) * 1000 + math.floor(y / CELL)
end

local function Trim(cells)
    local count, oldest = 0, nil
    for _ in pairs(cells) do count = count + 1 end
    while count > MAX_CELLS do
        oldest = nil
        for key, cell in pairs(cells) do
            if not oldest or (cell.last or 0) < (cells[oldest].last or 0) then oldest = key end
        end
        cells[oldest] = nil
        count = count - 1
    end
end

-- Record one catch. Returns true when a position was saved.
function CatchMap:Record(id, quantity, mapId, x, y)
    if not id or id == 0 or not mapId then return false end
    if not (x and y) then x, y = BobberPosition(mapId) end
    if not (x and y) then return false end
    quantity = math.max(1, tonumber(quantity) or 1)

    local maps = Root()
    local cells = maps[mapId]
    if not cells then cells = {}; maps[mapId] = cells end
    local key = CellKey(x, y)
    local cell = cells[key]
    local now = time()
    if not cell then
        cell = { x = x, y = y, n = 0, first = now, fish = {} }
        cells[key] = cell
    end
    -- the cell's position drifts to the average of what it has seen
    cell.x = (cell.x * cell.n + x) / (cell.n + 1)
    cell.y = (cell.y * cell.n + y) / (cell.n + 1)
    cell.n = cell.n + quantity
    cell.last = now
    cell.fish[id] = (cell.fish[id] or 0) + quantity
    Trim(cells)
    return true
end

-- Cells on a map, optionally only those that gave `fishId`. Returns a list of
-- { x, y, n, last, fish } where n counts only the filtered fish.
function CatchMap:Cells(mapId, fishId)
    local list = {}
    for _, cell in pairs(Root()[mapId] or {}) do
        local n = cell.n
        if fishId then n = cell.fish[fishId] end
        if n and n > 0 then
            list[#list + 1] = { x = cell.x, y = cell.y, n = n, last = cell.last, fish = cell.fish }
        end
    end
    return list
end

-- Total catches and the fish seen on a map, most caught first.
function CatchMap:Summary(mapId)
    local total, spots, perFish = 0, 0, {}
    for _, cell in pairs(Root()[mapId] or {}) do
        spots = spots + 1
        total = total + cell.n
        for id, count in pairs(cell.fish) do perFish[id] = (perFish[id] or 0) + count end
    end
    local fish = {}
    for id, count in pairs(perFish) do fish[#fish + 1] = { id = id, count = count } end
    table.sort(fish, function(a, b) return a.count > b.count end)
    return { total = total, spots = spots, fish = fish }
end

FBI:AddCommand("spots", function()
    local mapId = FBI:GetCurrentMapIdInfo()
    local summary = CatchMap:Summary(mapId)
    if summary.total == 0 then
        FBI:Print("%s", "No catch locations recorded in this zone yet.")
    else
        FBI:Print("%s", string.format("%d catches across %d spots in this zone.", summary.total, summary.spots))
    end
    return true
end, "spots -- how many catch locations are recorded in this zone")
