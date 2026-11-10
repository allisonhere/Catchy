#!/usr/bin/env bash
set -euo pipefail

# Safe Catchy deployment. The installed addon may contain work that has not yet
# made it into Git, so deletion is forbidden unless explicitly acknowledged.

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install_dir="/home/allie/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/Catchy"
backup_dir="/home/allie/Projects/wow/backups"
allow_delete=false
assume_yes=false
rsync_filters=(
    --exclude='.git/'
    --exclude='.vscode/'
    --exclude='.agents/'
    --exclude='.aws/'
    --exclude='.codex/'
    --exclude='AGENTS.md'
    --exclude='tools/'
)

for argument in "$@"; do
    case "$argument" in
        --allow-delete) allow_delete=true ;;
        --yes) assume_yes=true ;;
        *) echo "Unknown argument: $argument" >&2; exit 2 ;;
    esac
done

if [[ ! -d "$install_dir" ]]; then
    echo "Install directory does not exist: $install_dir" >&2
    exit 1
fi

command -v luac5.1 >/dev/null || { echo "luac5.1 is required." >&2; exit 1; }
command -v lua5.1 >/dev/null || { echo "lua5.1 is required." >&2; exit 1; }
command -v rsync >/dev/null || { echo "rsync is required." >&2; exit 1; }

echo "Checking every Lua file with Lua 5.1..."
mapfile -d '' lua_files < <(find "$project_root" -type f -name '*.lua' -not -path '*/.git/*' -print0)
for lua_file in "${lua_files[@]}"; do
    check_file="$(mktemp /tmp/catchy-lua51.XXXXXX)"
    sed '1s/^\xEF\xBB\xBF//' "$lua_file" > "$check_file"
    luac5.1 -p "$check_file"
    rm -f "$check_file"
done

if [[ -d "$project_root/tests" ]]; then
    echo "Running Lua 5.1 smoke tests..."
    while IFS= read -r -d '' test_file; do
        (cd "$project_root" && lua5.1 "$test_file")
    done < <(find "$project_root/tests" -type f -name '*.lua' -print0 | sort -z)
fi

preview_file="$(mktemp /tmp/catchy-deploy-preview.XXXXXX)"
trap 'rm -f "$preview_file"' EXIT

rsync -avnic --delete "${rsync_filters[@]}" "$project_root/" "$install_dir/" | tee "$preview_file"

if grep -q '^\*deleting ' "$preview_file"; then
    echo >&2
    echo "REFUSING TO DEPLOY: the installed addon contains files absent from Git." >&2
    echo "Import or intentionally remove those files first." >&2
    if [[ "$allow_delete" != true ]]; then
        echo "Only an audited deployment may override this with --allow-delete." >&2
        exit 1
    fi
    echo "WARNING: --allow-delete was supplied; listed files will be removed." >&2
fi

if [[ "$assume_yes" != true ]]; then
    read -r -p "Back up the installed addon and apply this exact preview? [y/N] " answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || exit 0
fi

mkdir -p "$backup_dir"
backup_file="$backup_dir/Catchy-before-deploy-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$backup_file" -C "$(dirname "$install_dir")" "$(basename "$install_dir")"
echo "Backup created: $backup_file"

rsync -av --delete "${rsync_filters[@]}" "$project_root/" "$install_dir/"

verify_file="$(mktemp /tmp/catchy-deploy-verify.XXXXXX)"
rsync -avnic --delete "${rsync_filters[@]}" "$project_root/" "$install_dir/" > "$verify_file"
if grep -Eq '^(\*deleting |>f|cd\+|cL\+|cD\+)' "$verify_file"; then
    echo "Deployment verification failed:" >&2
    cat "$verify_file" >&2
    rm -f "$verify_file"
    exit 1
fi
rm -f "$verify_file"
echo "Catchy deployed and verified. No installed-only files were lost."

