#!/usr/bin/env bash
set -euo pipefail

# Copies omarchy/hyprland/terminal configs into this repo, commits and
# pushes to GitHub. Run manually or via the systemd user timer.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HOME/.config"
DST="$REPO_DIR/home/.config"

info() { printf '\033[1;32m[dotfiles]\033[0m %s\n' "$*"; }

# 1. Fresh copy so deleted files disappear from the repo too
rm -rf "$DST"
mkdir -p "$DST"

EXCLUDES=(
  --exclude='*.bak'
  --exclude='*.orig'
  --exclude='*.sample'
  --exclude='*~'
  --exclude='.git'
)

# Hyprland (bindings, monitors, input, looknfeel, ...)
rsync -a --delete "${EXCLUDES[@]}" "$CONF/hypr/" "$DST/hypr/"

# Omarchy shell: bar layout, settings, menu, custom theme, installed hooks
rsync -a --delete "${EXCLUDES[@]}" \
  "$CONF/omarchy/shell.json" \
  "$CONF/omarchy/omasettings.json" \
  "$CONF/omarchy/extensions/" \
  "$CONF/omarchy/themes/" \
  "$DST/omarchy/"
[ -d "$CONF/omarchy/hooks" ] && \
  rsync -a --delete --exclude='*.sample' "$CONF/omarchy/hooks/" "$DST/omarchy/hooks/"

# Terminals
for t in alacritty kitty foot ghostty; do
  [ -d "$CONF/$t" ] && rsync -a --delete "${EXCLUDES[@]}" "$CONF/$t/" "$DST/$t/"
done

# 2. Installed plugin manifest: repo URL + checked-out commit
{
  printf '%-42s %-40s %s\n' "id" "commit" "repo"
  for dir in "$CONF"/omarchy/plugins/*/; do
    [ -d "$dir/.git" ] || continue
    id=$(basename "$dir")
    url=$(git -C "$dir" config --get remote.origin.url)
    commit=$(git -C "$dir" rev-parse HEAD)
    printf '%-42s %-40s %s\n' "$id" "$commit" "$url"
  done
} > "$REPO_DIR/plugins.txt"

# 3. Commit + push
cd "$REPO_DIR"
git add -A
if git diff --cached --quiet; then
  info "no changes, nothing to commit"
else
  git -c commit.gpgsign=false commit -q -m "backup: $(date '+%Y-%m-%d %H:%M')"
  info "committed"
fi
git push -q origin HEAD
info "pushed"
