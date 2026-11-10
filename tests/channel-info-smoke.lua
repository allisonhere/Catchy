local calls = 0
UnitChannelInfo = function(unit)
    calls = calls + 1
    assert(unit == "player", "channel reader used the wrong unit")
    return "Fishing", "Fishing", "texture-path", 1000, 22000, false, false, 131474, false, 999999
end

local FBI = {}
assert(loadfile("CatchyChannel.lua"))("Catchy", FBI)

local name, startTimeMS, endTimeMS, spellID, texture = FBI:GetChannelInfo("player")
assert(calls == 1, "channel API was not read exactly once")
assert(name == "Fishing", "channel name used the wrong return position")
assert(startTimeMS == 1000, "start time used the wrong return position")
assert(endTimeMS == 22000, "end time used the wrong return position")
assert(spellID == 131474, "spell ID used the wrong return position")
assert(texture == "texture-path", "texture used the wrong return position")

UnitChannelInfo = function()
    return "Fishing", nil, nil, 1000, 22000, nil, nil, nil, nil, 131490
end
local _, _, _, legacySpellID = FBI:GetChannelInfo("player")
assert(legacySpellID == 131490, "legacy spell ID fallback was lost")

print("channel info smoke: ok")
