# Submission

https://github.com/Goooooooooody/omarchy-pebble-voice

## Category

Productivity

## Tags

ai, bar, quickshell

## Maintainer notes

Depends on a stock Omarchy install plus:

- [omarchy-pebble-index](https://github.com/Goooooooooody/omarchy-pebble-index) (`pebble-index capture`)
- VoxType (`voxtype`) and `voxtype.service`
- `grim`, `hyprctl`

`omarchy plugin add --enable` installs the overlay and bar widget. `./setup` is optional extra work: enable `voxtype.service` if present, and append a SUPER + Page_Down bind inside `-- pebble-voice:` markers. `./uninstall` removes that bind and disables the plugin. Menu removal does not run uninstall.

No sudo or pkexec is required. Setup does not rewrite Hyprland config outside the marked block.

## Security

- Speech goes to the local VoxType daemon, then to `pebble-index capture` on this machine.
- Look phrases attach a screenshot of the focused Hyprland window.
- Runtime files live under `$XDG_RUNTIME_DIR/omarchy-pebble-voice`.
- VoxType's own GTK OSD is paused while this overlay is listening so two HUDs do not stack.
- Community Index actions (`pebble-index/*.toml`) run as the user after a valid capture, same as the ring.

## Checklist

- [x] `manifest.json` schemaVersion 1, kinds `overlay`, `bar-widget`
- [x] setup / uninstall scripts
- [x] README install, remove, and data-access sections
- [x] MIT license
- [x] preview.png
- [x] `omarchy plugin validate` on this checkout
