#!/usr/bin/env bash
set -euo pipefail

# Installs packages from the manifests (packages-repo.txt / packages-aur.txt)
# that are missing on this machine.
# Usage: install-packages.sh [--dry-run]

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

info() { printf '\033[1;32m[dotfiles]\033[0m %s\n' "$*"; }

check_missing() {
  local pkg
  while read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    pacman -Q "$pkg" >/dev/null 2>&1 || echo "$pkg"
  done
}

info "checking repo packages..."
mapfile -t missing_repo < <(check_missing < "$REPO_DIR/packages-repo.txt")
if [ ${#missing_repo[@]} -gt 0 ]; then
  info "missing ${#missing_repo[@]} repo package(s): ${missing_repo[*]}"
  if [ $DRY -eq 1 ]; then
    info "dry-run, not installing"
  else
    sudo pacman -S --needed --noconfirm "${missing_repo[@]}"
  fi
else
  info "all repo packages are installed"
fi

info "checking AUR packages..."
mapfile -t missing_aur < <(check_missing < "$REPO_DIR/packages-aur.txt")
if [ ${#missing_aur[@]} -gt 0 ]; then
  info "missing ${#missing_aur[@]} AUR package(s): ${missing_aur[*]}"
  if [ $DRY -eq 1 ]; then
    info "dry-run, not installing"
  else
    yay -S --needed --noconfirm "${missing_aur[@]}"
  fi
else
  info "all AUR packages are installed"
fi
