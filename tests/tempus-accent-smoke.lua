local settings = assert(io.open("CatchySettings.lua", "rb")):read("*a")
local locations = assert(io.open("CatchyLocations.lua", "rb")):read("*a")

assert(settings:find("local AC = tempus and tempus.accent", 1, true),
    "Catchy does not share Tempus's live accent table")
assert(settings:find("T.Style.Accent(object, alpha, multiplier)", 1, true),
    "Catchy UI objects are not registered for Tempus accent repaints")
assert(settings:find("tempus.Style.OnAccent(PaintHeader)", 1, true),
    "standalone Catchy header does not repaint with Tempus")
assert(settings:find("Accent = Accent", 1, true),
    "Catchy modules cannot register dynamic accent objects")
assert(locations:find('Accent(Tex(box, "OVERLAY"), 0.5)', 1, true),
    "Locations scrollbar does not follow Tempus accent")

print("tempus accent smoke: ok")
