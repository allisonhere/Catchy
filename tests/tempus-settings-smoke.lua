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

local selected = {
    selected = true,
    IsShown = function() return true end,
    GetTop = function() return 250 end,
    GetBottom = function() return 224 end,
}
local navigation = {
    items = { selected },
    child = { GetHeight = function() return 1000 end },
    GetHeight = function() return 400 end,
    GetTop = function() return 1000 end,
    GetBottom = function() return 600 end,
    GetVerticalScroll = function(self) return self.position end,
    SetVerticalScroll = function(self, value) self.position = value end,
    position = 0,
}
local side = { GetChildren = function() return navigation end }
TempusOptionsFrame = { GetChildren = function() return side end }
Tempus.Options = { current = "catchy_general" }
C_Timer = { After = function(_, callback) callback() end }
settings:ScrollHostedPageIntoView("catchy_general")
assert(navigation.position == 384, "selected Catchy page was not scrolled into view")

navigation.position = 500
selected.GetTop = function() return 1040 end
selected.GetBottom = function() return 1014 end
settings:ScrollHostedPageIntoView("catchy_general")
assert(navigation.position == 452, "selected Catchy page was not scrolled back into view")

print("tempus settings smoke: ok")
