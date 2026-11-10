# Catchy

> Disclaimer: This project is an unofficial fork of the original FishingBuddy addon on CurseForge.
> https://www.curseforge.com/wow/addons/fishingbuddy

Catchy keeps track of the fish you catch and helps manage your fishing gear.

## Features

- Double-click fishing
- Supports the WoW "fish without a pole" feature
- Bring out your fishing pets! Drink heavily!
- "Fish Watcher" shows fish caught in the current session and in this location before
- Displays current skill level and time spent fishing
- Choose a fishing outfit and swap to it easily
- Automatically adds a lure to your fishing pole
- Track "cycle fish" (for example, Nightfin Snapper)
- Live session dashboard with catch rate, misses, streaks, catches/hour and gold earned
- Fishing Journal with session, daily and lifetime catches, favorite waters and performance analytics
- Cast rhythm analytics: rolling catch rate, average bite time, cadence, interruptions and unlooted casts
- World map overlay of known fishing pools, colored by how recently they were seen
- Live minimap pool radar with freshness colors and rotating-minimap support

## Example Commands

- `/catchy` or `/ca` toggles the Catchy window
- `/ca help` prints the list of Catchy commands
- `/ca switch` wears your chosen fishing outfit or switches back
- `/ca journal` opens the Fishing Journal
- `/ca radar` toggles nearby fishing pools on the minimap

## Known Issues

- "Fast Loot" addons can interfere with fish counting because the loot disappears before it can be recorded.

## Safe Forever Deployment

Use `tools/deploy-forever.sh`. It checks every Lua file with Lua 5.1, previews the exact sync,
refuses to delete installed-only files, creates a timestamped backup, and verifies the copy.
Never deploy Catchy with a direct `rsync --delete` command.

## Fun Extras

- Displays fishing bonus and "style points" based on Draznar's Fishing FAQ:
	http://wow.toshimo.com/viewtopic.php?t=272

## Catchy Plugins

> Note: these plugins were written to integrate with the original FishingBuddy's internal names. Since this fork has been renamed to Catchy (new folder, saved variables, and internal API), they will likely need updating before they work again.

- Outfit Manager: https://www.curseforge.com/wow/addons/fboutfit
- Fish Tracking: https://www.curseforge.com/wow/addons/fishing-buddy-tracking
- Broker: Fishing Buddy: https://www.curseforge.com/wow/addons/broker-fishing-buddy
- Titan Panel Fishing Buddy: https://www.curseforge.com/wow/addons/titan-panel-fishing-buddy
