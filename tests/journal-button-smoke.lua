local function Widget()
    local widget = { shown = false, scripts = {} }
    return setmetatable(widget, { __index = function(_, key)
        if key == "CreateTexture" or key == "CreateFontString" then
            return function() return Widget() end
        elseif key == "SetScript" then
            return function(self, event, callback) self.scripts[event] = callback end
        elseif key == "Show" then
            return function(self) self.shown = true end
        elseif key == "Hide" then
            return function(self) self.shown = false end
        elseif key == "IsShown" then
            return function(self) return self.shown end
        end
        return function() end
    end })
end

UIParent = Widget()
UISpecialFrames = {}
function CreateFrame() return Widget() end
function date() return "2026-11-10" end

local capturedPage
local settingsClosed = false
local FBI = {
    Settings = {
        SetPage = function(_, page) capturedPage = page end,
        Close = function() settingsClosed = true end,
        Kit = {
            COL_W = 280, COL_GAP = 22, AC = { 0.2, 0.8, 1 },
            C = { card = { 0, 0, 0 }, muted = { 0.5, 0.5, 0.5 }, text = { 1, 1, 1 } },
            Tex = function() return Widget() end,
            Text = function() return Widget() end,
            Border = function() end,
        },
    },
    Stats = {
        GetDatabase = function()
            local session = {
                casts = 3, catches = 2, misses = 1, gold = 0, best = 2,
                perFish = {}, zones = {}, outcomes = {}, unresolved = 0, interrupted = 0,
            }
            return { daily = {}, lifetime = {} }, session
        end,
        CatchRate = function() return 66.7 end,
        AverageCastInterval = function() return 20 end,
        Elapsed = function() return 60 end,
        RollingRate = function() return 66.7 end,
        CatchesPerHour = function() return 120 end,
    },
    GetFishie = function() end,
}

assert(loadfile("CatchyJournal.lua"))("Catchy", FBI)
assert(capturedPage, "journal settings page was not registered")

local openCallback
local page = {
    Section = function() end,
    Paragraph = function() end,
    Add = function(_, widget) if widget.Refresh then widget:Refresh() end end,
    Button = function(_, label, callback)
        if label == "Open Fishing Journal" then openCallback = callback end
    end,
}
capturedPage.build(page)
assert(openCallback, "Open Fishing Journal button was not built")
openCallback()

assert(settingsClosed, "journal button did not close the settings window")
assert(FBI.JournalFrame:IsShown(), "journal button did not show the journal frame")
print("journal settings button smoke: ok")
