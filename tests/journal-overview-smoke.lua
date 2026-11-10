local source = assert(io.open("CatchyJournal.lua", "rb")):read("*a")

for _, label in ipairs({
    "Session catches", "Lifetime catches", "Session catch rate", "Catches per hour",
    "Best streak", "Session time", "TOP CATCH", "FAVORITE WATER", "TODAY", "RECENT FORM",
}) do
    assert(source:find(label, 1, true), "journal settings overview is missing: " .. label)
end
assert(source:find('page:Button("Open Fishing Journal"', 1, true),
    "full journal button was removed")

print("journal overview smoke: ok")
