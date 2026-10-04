#!/usr/bin/env bash
set -euo pipefail

# Installs packages that are missing on this machine.
#
# Usage: install-packages.sh [--host <id>] [--dry-run]
#
#   --host <id>   Which machine this is. Defaults to the contents of
#                 ~/.dotfiles-host-id, else "home".
#   --dry-run     Report what would be installed, install nothing.
#
# Only two tiers are ever read: the shared tier plus this host's own tier.
# Another host's file is never opened, so a package one machine has (a game,
# a GPU driver) cannot reach this machine even if a tier file is wrong.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY=0
HOST=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --host) HOST="${2:-}"; shift 2 ;;
    --host=*) HOST="${1#*=}"; shift ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \?//'
      exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$HOST" ]; then
  HOST="$(cat "$HOME/.dotfiles-host-id" 2>/dev/null || true)"
  HOST="${HOST//[[:space:]]/}"
fi
[ -z "$HOST" ] && HOST="home"

info() { printf '\033[1;32m[dotfiles]\033[0m %s\n' "$*"; }
# Diagnostics must go to stderr: allowed_pkgs output is captured by mapfile,
# and a stray line on stdout would be read back as a package name.
warn() { printf '\033[1;33m[dotfiles]\033[0m %s\n' "$*" >&2; }

# Defence in depth. The tier split already makes cross-machine leakage
# impossible, but if a game or a foreign GPU driver is ever hand-added to
# packages-shared.txt, refuse it rather than install it.
GAME_DENYLIST_RE='^(steam|steam-native-client|lutris|umu-launcher|wine|wine-staging|wine-stable|wine-gecko|wine-mono|winetricks|proton|protontricks|protonup-qt|minecraft-launcher|minetest|0ad|gamemode|gamescope|vbam|dxvk|dxvk-gpl|proton-ge|heroic|heroic-games-launcher|lutris-wine|mingw-w64-gcc|mingw-w64-headers)$'
GPU_DENYLIST_RE='^(nvidia-open|nvidia-open-dkms|nvidia-dkms|nvidia-utils|nvidia-settings|lib32-nvidia-utils|libva-nvidia-driver|libnvidia-gl|intel-ucode|intel-media-driver|intel-gpu-tools|vulkan-intel|vpl-gpu-rt|vulkan-radeon|lib32-vulkan-radeon|amd-ucode|sof-firmware)$'

blocked() {
  local pkg="$1" why="$2"
  if [[ "$pkg" =~ $GAME_DENYLIST_RE ]]; then
    warn "REFUSING $pkg (matches games denylist) - $why"
    return 0
  fi
  if [[ "$pkg" =~ $GPU_DENYLIST_RE ]]; then
    warn "REFUSING $pkg (matches GPU-driver denylist) - $why"
    return 0
  fi
  return 1
}

installed() { pacman -Qq "$1" >/dev/null 2>&1; }

# Collect the missing packages from one tier file.
#
# $2 is "enforce" for the shared tier only. A host's own tier is allowed to
# contain games and its own GPU drivers -- that is the entire point of the
# per-host tier. The denylist exists solely to catch a game or a foreign
# driver that has leaked into the shared file, where no machine should ever
# find one.
allowed_pkgs() {
  local tier="$1" enforce="${2:-}" pkg file="$REPO_DIR/$1"
  [ -f "$file" ] || return 0
  while read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    if [ "$enforce" = enforce ] && blocked "$pkg" "found in shared tier"; then
      continue
    fi
    installed "$pkg" || printf '%s\n' "$pkg"
  done < "$file"
}

if [ ! -f "$REPO_DIR/packages-$HOST.txt" ]; then
  warn "no tier file for host '$HOST' (packages-$HOST.txt)"
  warn "known tiers: $(cd "$REPO_DIR" && ls packages-*.txt 2>/dev/null | sed 's/packages-//;s/\.txt//' | tr '\n' ' ')"
  warn "set the host with: echo $HOST > ~/.dotfiles-host-id"
  exit 1
fi

info "host: $HOST"

mapfile -t missing_shared < <(allowed_pkgs packages-shared.txt enforce)
mapfile -t missing_host   < <(allowed_pkgs "packages-$HOST.txt")

if [ ${#missing_shared[@]} -eq 0 ]; then
  info "shared tier: nothing to install"
else
  info "shared tier: ${#missing_shared[@]} missing -> ${missing_shared[*]}"
fi

if [ ${#missing_host[@]} -eq 0 ]; then
  info "host tier ($HOST): nothing to install"
else
  info "host tier ($HOST): ${#missing_host[@]} missing -> ${missing_host[*]}"
fi

if [ ${#missing_shared[@]} -eq 0 ] && [ ${#missing_host[@]} -eq 0 ]; then
  info "all packages for host '$HOST' are installed"
  exit 0
fi

if [ $DRY -eq 1 ]; then
  info "dry-run, not installing"
  exit 0
fi

# Install one tier at a time so a failure is attributable and the pacman
# transaction is not blocked by a single bad name.
install_set() {
  local label="$1"; shift
  local pkgs=("$@")
  [ ${#pkgs[@]} -eq 0 ] && return 0
  local aur=() repo=()
  local p
  for p in "${pkgs[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
  done

  if [ ${#repo[@]} -gt 0 ]; then
    info "installing ${#repo[@]} repo package(s) ($label)"
    sudo pacman -S --needed --noconfirm "${repo[@]}"
  fi
  if [ ${#aur[@]} -gt 0 ]; then
    if ! command -v yay >/dev/null 2>&1; then
      warn "$label: AUR helper missing, cannot install: ${aur[*]}"
      return 0
    fi
    info "installing ${#aur[@]} AUR package(s) ($label)"
    yay -S --needed --noconfirm "${aur[@]}"
  fi
}

install_set "shared" "${missing_shared[@]}"
install_set "host:$HOST" "${missing_host[@]}"

info "package install complete"