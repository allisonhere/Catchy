local source = assert(io.open("CatchyLocations.lua", "rb"))
local text = source:read("*a")
source:close()

assert(text:find("d%.count%s*=%s*count"), "child fish count is not retained")
assert(text:find("d%.count%s*=%s*total"), "total fish count is not retained")
assert(text:find("d%.count%s*=%s*ft%[zid%]"), "zone count is not retained")
assert(text:find("row%.percent:SetText%(StatText%(d%)%)"), "visible location rows do not render counts")
print("locations count smoke: ok")
