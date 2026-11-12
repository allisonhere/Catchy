local file = assert(io.open("CatchyDashboard.lua", "r"))
local source = file:read("*a"); file:close()
local controller = assert(source:match('(local accumulator = 0;.-)\nframe:SetScript%("OnDragStart"'))
local enabled, always, fishing, pole = true, true, true, true
local frame = { shown = false }
function frame:IsShown() return self.shown end
function frame:Show() self.shown = true end
function frame:Hide() self.shown = false end
local update
local env = setmetatable({
    frame = frame,
    eventFrame = { SetScript = function(_, _, callback) update = callback end },
    GSB = function(key) if key == "WatchDashboard" then return enabled end return always end,
    FBI = { AreWeFishing = function() return fishing end },
    FL = { IsFishingPole = function() return pole end },
    GetTime = function() return 100 end,
    UpdateValues = function() end,
}, { __index = _G })
local chunk = assert(loadstring(controller)); setfenv(chunk, env); chunk()
update(nil, 0.5)
assert(frame.shown, "equipped pole should show the enabled dashboard")
pole = false
update(nil, 0.5)
assert(not frame.shown, "a weapon must hide the dashboard despite fishing state, Always Show and preview")
pole = true
update(nil, 0.5)
assert(frame.shown, "re-equipping the pole must restore the dashboard")
enabled = false; update(nil, 0.5)
assert(not frame.shown)
enabled = true; update(nil, 0.5)
assert(frame.shown, "the settings toggle must wake a hidden dashboard")
frame.dismissed = true; update(nil, 0.5)
assert(not frame.shown, "manual dismissal should persist")
print("dashboard visibility smoke: ok")
