#!/usr/bin/env bash
set -euo pipefail

# Clones missing repos into ~/GitHub and fast-forwards the existing ones.
# Runs manually or as part of the daily dotfiles-backup systemd timer.
# Pull-only: local changes are never committed or pushed.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GH_DIR="$HOME/GitHub"
USERNAME="KaplanHalil"
SKIP="dotfiles"

info() { printf '\033[1;32m[github-sync]\033[0m %s\n' "$*"; }

mkdir -p "$GH_DIR"

if ! command -v gh >/dev/null 2>&1; then
  info "gh CLI not found - install it first"
  exit 1
fi

mapfile -t repos < <(gh repo list "$USERNAME" --limit 100 --json name -q '.[].name' | grep -vx "$SKIP" || true)
if [ ${#repos[@]} -eq 0 ]; then
  info "no repos found (not logged in?)"
  exit 1
fi

cloned=0
updated=0
failed=()
for repo in "${repos[@]}"; do
  dir="$GH_DIR/$repo"
  if [ ! -d "$dir/.git" ]; then
    if gh repo clone "$repo" "$dir" >/dev/null 2>&1; then
      info "cloned: $repo"
      cloned=$((cloned + 1))
    else
      failed+=("$repo (clone)")
    fi
    continue
  fi
  if ! git -C "$dir" pull --ff-only --quiet 2>/tmp/github-sync.err; then
    if git -C "$dir" rev-parse --abbrev-ref HEAD >/dev/null 2>&1 && \
       git -C "$dir" status --porcelain | grep -q .; then
      info "skipped (local changes): $repo"
      failed+=("$repo (local changes)")
    else
      info "skipped (failed to pull): $repo"
      failed+=("$repo (pull failed)")
      tr '\n' ' ' < /tmp/github-sync.err; echo
    fi
    continue
  fi
  updated=$((updated + 1))
done

info "done: $cloned cloned, $updated up to date, ${#failed[@]} failed"
[ ${#failed[@]} -gt 0 ] && printf '  - %s\n' "${failed[@]}"

if [ ${#failed[@]} -gt 0 ]; then
  details="$(printf '  - %s\n' "${failed[@]}")"
  hint="[\"xdg-open\",\"$REPO_DIR/SYNC-FIX-GUIDE.txt\"]"
  notify-send -u critical -h "string:omarchy-exec-argv:$hint" \
    "GitHub sync: ${#failed[@]} repo skipped" \
    "$details - Click: opens the fix guide" 2>/dev/null || true
fi
