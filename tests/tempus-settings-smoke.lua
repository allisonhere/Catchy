local registered, sections = {}, {
    { key = "general", label = "General" },
}

Tempus = {
    pageSections = sections,
    RegisterPage = function(_, section, definition)
        registered[#registered + 1] = { section = section, definition = definition }
    end,
}

local mixed
local settings = {
    sections = {
        { key = "fishing", label = "Fishing" },
        { key = "settings", label = "Settings" },
    },
    pages = {
        { section = "fishing", key = "journal", label = "Journal", order = 3,
          build = function(page) page.built = true end },
        { section = "settings", key = "general", label = "General", order = 1,
          build = function(page) page.built = true end },
    },
    Mixin = function(_, page) mixed = page end,
}

local bridge = assert(loadfile("CatchyTempus.lua"))
bridge("Catchy", { Settings = settings })

assert(settings.hosted == true, "Tempus bridge did not mark Catchy as hosted")
assert(#sections == 2 and sections[2].key == "catchy", "Catchy section was not registered")
assert(#registered == 2, "not every Catchy page was registered")
assert(registered[1].section == "catchy", "page registered in the wrong section")
assert(registered[1].definition.key == "catchy_journal", "page key was not namespaced")
assert(registered[1].definition.order < registered[2].definition.order, "Catchy section order was not preserved")

local page = {}
registered[1].definition.build(page)
assert(mixed == page and page.built, "Tempus page did not receive the Catchy mixin/build")

print("tempus settings smoke: ok")
