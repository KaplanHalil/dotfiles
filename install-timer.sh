#!/usr/bin/env bash
set -euo pipefail

# Installs (or refreshes) the systemd user units that run the daily backup.
# Safe to re-run after editing the unit files in this repo.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_DIR="$HOME/.config/systemd/user"

info() { printf '\033[1;32m[dotfiles]\033[0m %s\n' "$*"; }

mkdir -p "$UNIT_DIR"
for u in dotfiles-backup.service dotfiles-backup.timer; do
  install -m 644 "$REPO_DIR/systemd/$u" "$UNIT_DIR/$u"
  info "installed $u"
done

systemctl --user daemon-reload
systemctl --user enable --now dotfiles-backup.timer
info "enabled dotfiles-backup.timer"

echo
systemctl --user list-timers dotfiles-backup.timer --no-pager