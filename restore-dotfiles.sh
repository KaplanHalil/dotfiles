#!/usr/bin/env bash
set -euo pipefail

# Restore omarchy/hyprland configs from this repo onto a (fresh) machine.
# Usage: restore-dotfiles.sh [--force]   (--force skips all confirm prompts)
#
# The repo mirrors ~/.config exactly, so restoring is a straight tree copy.
# Subdirectory layout matters and is preserved:
#   extensions/omarchy-menu.jsonc  <- read by shell/plugins/menu/Menu.qml
#   themes/<name>/shell.toml        <- read by shell/Commons/Color.qml

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$HOME/.config"
SRC="$REPO_DIR/home/.config"
PLUGINS_DIR="$CONF/omarchy/plugins"
FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

HOST="$(cat "$HOME/.dotfiles-host-id" 2>/dev/null || true)"
HOST="${HOST//[[:space:]]/}"

info() { printf '\033[1;32m[dotfiles]\033[0m %s\n' "$*"; }

confirm() {
  local ans
  # --force means yes to everything, so honour it here too.
  if $FORCE; then return 0; fi
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
  # Clone to a temp name first: the manifest id and the directory name are not
  # always identical, and omarchy derives the plugin id from manifest.json.
  tmp="$PLUGINS_DIR/.restore.$$.tmp"
  rm -rf "$tmp"
  if ! git clone -q "$url" "$tmp"; then
    rm -rf "$tmp"
    info "FAILED to clone $id ($url)"
    continue
  fi
  real_id="$(jq -r '.id' "$tmp/manifest.json" 2>/dev/null || basename "$id")"
  if [ -e "$PLUGINS_DIR/$real_id" ]; then
    info "plugin $real_id already present, discarding fresh clone"
    rm -rf "$tmp"
    continue
  fi
  mv "$tmp" "$PLUGINS_DIR/$real_id"
  if [ -n "$commit" ]; then
    git -C "$PLUGINS_DIR/$real_id" checkout -q "$commit" 2>/dev/null \
      || info "WARN: pinned commit $commit not reachable for $real_id (staying on default branch)"
  fi
  info "installed $real_id @ $(git -C "$PLUGINS_DIR/$real_id" rev-parse --short HEAD)"
done < "$REPO_DIR/plugins.txt"

info "installing shell.json last so the repo's bar layout wins over any"
info "widget entries the plugin steps may have added"

info "checking installed packages..."
if [ -z "$HOST" ]; then
  info "no ~/.dotfiles-host-id - write 'home' or 'tbtk' there to enable"
  info "package install; skipping. Then run:"
  info "  install-packages.sh --host <id>"
else
  "$REPO_DIR/install-packages.sh" --host "$HOST" --dry-run
  if confirm "install missing packages for host '$HOST' now?"; then
    "$REPO_DIR/install-packages.sh" --host "$HOST"
  else
    info "skip packages (run: install-packages.sh --host $HOST)"
  fi
fi

info "done - apply with: omarchy restart shell && hyprctl reload"