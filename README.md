# Omarchy / Hyprland dotfiles backup

Automatic daily backup of the omarchy + Hyprland configuration to GitHub.

## What is backed up

- `~/.config/hypr/` — keybindings, monitors, input, look & feel, autostart, night light
- `~/.config/omarchy/` — shell.json (bar layout), omasettings, launcher menu, custom themes, installed hooks
- Terminal configs — alacritty, kitty, foot, ghostty
- `plugins.txt` — installed omarchy plugins with pinned commit (so they can be reinstalled exactly)
- `packages-repo.txt` / `packages-aur.txt` — explicitly installed pacman + AUR packages

Plugin source code itself is **not** committed; plugins are plain git clones and
are restored from their upstream repos at the pinned commit.

## Sync (backup)

Manual:

```sh
~/.dotfiles/sync-dotfiles.sh        # or wherever you cloned this repo
```

Automatic: a systemd user timer runs it daily.

```sh
systemctl --user enable --now dotfiles-backup.timer
systemctl --user list-timers dotfiles-backup
```

## GitHub repo sync

`~/GitHub` holds clones of every `KaplanHalil` repo (except `dotfiles`). The
daily timer also runs `sync-github-repos.sh`, which clones any missing repo and
fast-forwards the existing ones (pull-only; local changes are left untouched).

```sh
~/.dotfiles/sync-github-repos.sh     # or wherever you cloned this repo
```

## Restore (new machine)

```sh
git clone git@github.com:KaplanHalil/dotfiles.git ~/.dotfiles
~/.dotfiles/restore-dotfiles.sh     # add --force to skip prompts
```

This checks configs, re-clones plugins and shows which packages are
missing before (optionally) installing them. To only fix packages:

```sh
~/.dotfiles/install-packages.sh      # add --dry-run to preview
```

Then apply:

```sh
omarchy restart shell
hyprctl reload
```
