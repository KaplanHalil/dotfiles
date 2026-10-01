# Omarchy / Hyprland dotfiles backup

Automatic daily backup of the omarchy + Hyprland configuration to GitHub.

## What is backed up

- `~/.config/hypr/` — keybindings, monitors, input, look & feel, autostart, night light
- `~/.config/omarchy/` — shell.json (bar layout), omasettings, launcher menu, custom themes, installed hooks
- Terminal configs — alacritty, kitty, foot, ghostty
- `plugins.txt` — installed omarchy plugins with pinned commit (so they can be reinstalled exactly)

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

## Restore (new machine)

```sh
git clone git@github.com:KaplanHalil/dotfiles.git ~/.dotfiles
~/.dotfiles/restore-dotfiles.sh     # add --force to skip prompts
```

Then apply:

```sh
omarchy restart shell
hyprctl reload
```
