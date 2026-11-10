local source = assert(io.open("CatchySettings.lua", "rb")):read("*a")

assert(source:find("pcall%(T%.Options%.Open, T%.Options%)"),
    "Catchy must use Tempus's collapsed normal-open path")
assert(not source:find('pcall%(T%.Options%.Open, T%.Options, "catchy_" %.%. key%)'),
    "Catchy still forces its Tempus section open with a page key")

print("tempus collapse smoke: ok")
