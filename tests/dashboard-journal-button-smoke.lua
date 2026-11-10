local file = assert(io.open("CatchyDashboard.lua", "rb"))
local source = file:read("*a")
file:close()

assert(source:find('journalLabel:SetText%("OPEN FISHING JOURNAL"%)'),
    "dashboard journal button label is missing")
assert(source:find("FBI%.Journal:Open%(%)"),
    "dashboard journal button is not wired to the tested journal open path")
assert(source:find("FBI%.StatsJournalButton%s*=%s*journalButton"),
    "dashboard journal button is not exposed for runtime diagnostics")
print("dashboard journal button smoke: ok")
