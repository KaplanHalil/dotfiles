#!/usr/bin/env bash
set -euo pipefail

# Restore omarchy/hyprland configs from this repo onto a (fresh) machine.
# Usage: restore-dotfiles.sh [--force]   (--force skips all confirm prompts)

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HOME/.config"
SRC="$REPO_DIR/home/.config"
PLUGINS_DIR="$CONF/omarchy/plugins"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

info() { printf '\033[1;32m[dotfiles]\033[0m %s\n' "$*"; }

confirm() {
  local ans
  read -rp "$* [y/N] " ans
  [[ "${ans,,}" == "y" ]]
}

restore_tree() {
  local src="$1" dst="$2" label="$3"
  if [ ! -e "$src" ]; then info "skip $label (not in repo)"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && ! $FORCE; then
    if confirm "$label exists at $dst. Overwrite?"; then
      cp -a "$src/." "$dst/"
    else
      info "skip $label"
    fi
  else
    cp -a "$src/." "$dst/"
  fi
}

restore_tree "$SRC/hypr"        "$CONF/hypr"        "Hyprland config"
restore_tree "$SRC/omarchy"     "$CONF/omarchy"     "Omarchy config"
restore_tree "$SRC/alacritty"   "$CONF/alacritty"   "Alacritty"
restore_tree "$SRC/kitty"       "$CONF/kitty"       "Kitty"
restore_tree "$SRC/foot"        "$CONF/foot"        "Foot"
restore_tree "$SRC/ghostty"     "$CONF/ghostty"     "Ghostty"

info "reinstalling plugins..."
mkdir -p "$PLUGINS_DIR"
skip_plugins=0
while read -r id commit url; do
  [[ "$id" == "id" || -z "$id" || "$id" == \#* ]] && continue
  if [ -e "$PLUGINS_DIR/$id" ]; then
    info "plugin $id already present, skipping"
    continue
  fi
  if ! confirm "clone plugin $id ($url)?"; then
    info "skip plugin $id"
    continue
  fi
  git clone -q "$url" "$PLUGINS_DIR/$id"
  [ -n "$commit" ] && git -C "$PLUGINS_DIR/$id" checkout -q "$commit"
  info "installed $id @ $commit"
done < "$REPO_DIR/plugins.txt"

info "checking installed packages..."
"$REPO_DIR/install-packages.sh" --dry-run
if confirm "install missing packages now?"; then
  "$REPO_DIR/install-packages.sh"
else
  info "skip packages (run ~/.dotfiles/install-packages.sh later)"
fi

info "done - apply with: omarchy restart shell && hyprctl reload"
