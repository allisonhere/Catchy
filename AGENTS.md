# Catchy repository rules

## Deployment safety

- The Git repository is the only deployment source of truth.
- Never run `rsync --delete` directly against a WoW AddOns directory.
- Deploy Forever builds only with `tools/deploy-forever.sh`.
- The deploy script must show a dry-run, refuse installed-only deletions, create a timestamped backup, and verify the resulting copy.
- If the preview lists deletions, stop and determine whether the installed files contain uncommitted UI work. Import that work into Git before deploying.
- Do not use `--allow-delete` unless the user explicitly approves the exact deletion list shown by the dry-run.

## Validation

- Test Lua with Lua 5.1 (`luac5.1`), not the system's newer Lua parser.
- Preserve the custom Catchy settings UI and its tracked modules: `CatchySettings.lua`, `CatchyLocations.lua`, `CatchyOutfits.lua`, `CatchyGauge.lua`, `FishingOutfitFrame.*`, `ODF/`, `FBOLoc/`, and `media/`.

