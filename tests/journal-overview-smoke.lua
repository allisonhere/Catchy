local source = assert(io.open("CatchyJournal.lua", "rb")):read("*a")

for _, label in ipairs({
    "Session catches", "Lifetime catches", "Session catch rate", "Catches per hour",
    "Best streak", "Session time", "TOP CATCH", "FAVORITE WATER", "TODAY", "RECENT FORM",
    "TOP CATCHES", "FAVORITE WATERS", "Performance", "Last 14 days",
}) do
    assert(source:find(label, 1, true), "journal settings overview is missing: " .. label)
end
assert(not source:find("CatchyJournalFrame", 1, true), "journal popup frame was not removed")
assert(not source:find("Open Fishing Journal", 1, true), "journal popup button was not removed")

local dash = assert(io.open("CatchyDashboard.lua", "rb")):read("*a")
assert(not dash:find("journalButton", 1, true), "dashboard journal button was not removed")

print("journal overview smoke: ok")
