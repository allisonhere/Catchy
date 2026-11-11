local source = assert(io.open("CatchySettings.lua", "rb")):read("*a")

assert(source:find('pcall(T.Options.Open, T.Options, hostedKey)', 1, true),
    "Catchy must open the requested page in Tempus")
assert(source:find('Settings:ScrollHostedPageIntoView(hostedKey)', 1, true),
    "Catchy must scroll the selected Tempus page into view")

print("tempus navigation smoke: ok")
