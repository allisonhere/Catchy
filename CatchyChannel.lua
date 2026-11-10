-- Normalized channel information for the modern client API. Keeping this in one
-- place prevents cast features from drifting onto obsolete return positions.
local _, FBI = ...

function FBI:GetChannelInfo(unit)
    local name, _, texture, startTimeMS, endTimeMS, _, _, spellID, _, legacySpellID = UnitChannelInfo(unit)
    -- Some older clients exposed the spell ID later in the tuple. Prefer the
    -- modern eighth return, but retain the fallback for compatibility.
    if type(spellID) ~= "number" then spellID = legacySpellID end
    return name, startTimeMS, endTimeMS, spellID, texture
end
