# Catchy 1.28.0 — Session Dashboard + Pool Intelligence

Implementation report for the two features requested on 2026-11-09.

## What was added

### 1. Session dashboard

A small movable HUD that shows live fishing stats:

| Row | Meaning |
| --- | --- |
| Session time | Wall-clock time since the session started |
| Casts | Fishing casts started |
| Catches | Successful fishing loots (one per cast) |
| Catch rate | Catches / casts, as a percentage |
| Missed | Missed-fish items recognised by Catchy |
| Catches / hour | Session average |
| Best streak | Longest run of catches without a miss |
| Gold earned | Looted coin during the session |

- Toggle: `/ca stats`
- Reset current session: `/ca stats reset`
- Also available in **Options → Watcher → Session dashboard**
- Optional: **Always show dashboard**, **Show gold**
- Position is saved per character; drag with the left mouse button, right-click to hide.
- Stats persist between reloads and reset daily or after 30 minutes idle.
- Daily and lifetime counters are also stored (ready for a future journal UI).

Data sources: `UNIT_SPELLCAST_CHANNEL_START/STOP`, Catchy's existing loot gate and `FBI:AddFishie`, plus `LOOT_OPENED`/`LOOT_CLOSED` for coin.

### 2. Pool intelligence

Known fishing schools now appear on the **world map**:

- Pins are drawn from `Catchy_Info["FishSchools"]` and translated between maps with HereBeDragons.
- Color shows freshness:
  - green = seen in the last 10 minutes
  - gold = seen in the last 30 minutes
  - gray = older / unknown
- Tooltip shows fish caught there, visit count, last-seen age, and coordinates.
- Works when viewing a parent map/continent too (when HereBeDragons can translate the coordinates).

Commands:

```
/ca pools          toggle world map pool pins
/ca pools fresh    toggle "fresh pools only"
/ca pools clear    remove stored pools for the displayed map
```

Options (Watcher tab): **World map pools**, **Fresh pools only**, **Pool age**.

### 3. Settings panel

All six new options are registered in Catchy's own settings window, in the **Watcher** tab:

```
/ca        -- open Catchy
```

or use the Catchy minimap button and switch to the **Watcher** tab.

On clients that have the modern Blizzard Settings API, `CatchySettings.lua` also adds a **Catchy** category at **Esc → Options → AddOns → Catchy**, with a **Reset session stats** button and the relevant slash commands. That panel is feature-detected; **Classic Era does not have this API**, so on `_forever_` the options live in Catchy's own Watcher tab instead.

School records now store `firstSeen` / `lastSeen` / `lastFish`. Existing data is migrated on login, pruned after 45 days, and capped at 1000 pools per map.

## Files changed

| File | Change |
| --- | --- |
| `CatchyDashboard.lua` | **New** — `FBI.Stats` module + dashboard frame |
| `FishingPoolsMap.lua` | **New** — world map pin layer, freshness, commands |
| `CatchySettings.lua` | **New** — modern Settings-panel category with all new options |
| `Catchy.toc` | Loads the three new files; version bumped to 1.28.0 |
| `FishingSchools.lua` | Adds `firstSeen` / `lastSeen` / `lastFish` to school records |
| `FishingWatcher.lua` | New Watcher-tab options |
| `locale/localization.enUS.lua` | New option strings (other locales fall back to English) |
| `CHANGELOG.md`, `README.md` | Changelog + feature list |

## Validation performed

- `luac -p` syntax check on every modified Lua file.
- Load-time harness with WoW API stubs (`/tmp/opencode/catchy_harness.lua`) loading all three new modules and exercising cast / catch / miss / reset / pool migrate / pool commands.
- `_forever_` (Classic Era) and `_retail_` AddOns folders synced; syntax re-checked in the live `_forever_` folder.

## Known limitations

- Pool pins are **world map only** for now (the old "Show pools" minimap option remains unused).
- Freshness is a heuristic based on last sighting, not a real respawn timer.
- Gold tracking uses coin looted during a fishing loot window; vendor value of fish is not counted.
- Missed count only covers missed-fish items Catchy already recognises; a cast that yields no loot at all is not counted as a miss.
- New UI text is English only.

## Install / sync path

The client you actually play is **Classic Era**:

```
/home/allie/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/Catchy
```

Retail is also kept in sync:

```
/home/allie/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns/Catchy
```

Deploy safely with:

```bash
tools/deploy-forever.sh
```

The script refuses installed-only deletions, creates a backup, and verifies the deployed tree.

The previous Classic build (Catchy (Forever) 1.0.8) was backed up first to:

```
/home/allie/Projects/wow/backups/Catchy-forever-1.0.8-20261109-1704.tar.gz
```

In game: `/reload`, then `/ca stats` and open the world map while fishing. Open `/ca` → **Watcher** tab for the new toggles.

## Quick test checklist

- [ ] Cast once → Casts increments by 1.
- [ ] Catch a fish → Catches, streak and catch rate update; gold updates when coins drop.
- [ ] Catch a missed-fish item → Missed increments, streak resets.
- [ ] `/ca stats reset` zeroes the session.
- [ ] `/reload` keeps the session and the dashboard position.
- [ ] Open the world map near known pools → pins appear with tooltips.
- [ ] `/ca pools fresh` hides stale pins.
- [ ] `/ca pools clear` removes pools only for the displayed map.
- [ ] `/ca` → **Watcher** tab shows the new toggles.
