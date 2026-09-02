# omarchy-pebble-voice

Voice overlay for Omarchy. [VoxType](https://github.com/peteonrails/voxtype) transcribes. [Pebble Index](https://github.com/Goooooooooody/omarchy-pebble-index) classifies and dispatches.

Plugin id: `io.github.goooooooooody.omarchy-pebble-voice`

No sudo or pkexec is required.

## Requirements

- Omarchy with the Quattro plugin API
- [omarchy-pebble-index](https://github.com/Goooooooooody/omarchy-pebble-index) installed and set up (`pebble-index capture` must exist)
- VoxType (`voxtype`) and its user daemon
- `grim`, `hyprctl` (stock Omarchy)

## Install

```bash
omarchy plugin add https://github.com/Goooooooooody/omarchy-pebble-index.git --enable
omarchy plugin add https://github.com/Goooooooooody/omarchy-pebble-voice.git --enable
```

`omarchy plugin add` only clones and enables the widget. It does not run this repo's scripts. From the installed checkout:

```bash
~/.config/omarchy/plugins/io.github.goooooooooody.omarchy-pebble-voice/setup
```

Setup starts `voxtype.service` if that unit exists, and appends a **SUPER + Page_Down** bind to `~/.config/hypr/bindings.lua` inside `-- pebble-voice:` markers if those markers are not already there. It does not rewrite the rest of your Hyprland config.

On a local checkout, `./setup` also links the tree into `~/.config/omarchy/plugins/`.

## Use

Press **SUPER + Page_Down** (or the bar mic). A chip appears in the bottom right, snapshots the focused window, then listens. Press the hotkey again to stop and dispatch.

Index decides the action. Community sinks in `pebble-index/*.toml` work the same as they do for the ring.

| You say | What happens |
|---|---|
| `what is this` / `how does this work` | omarchy agent with a screenshot of the focused window |
| `in 20 minutes …` | reminder |
| `tomorrow 3pm …` / `Friday at 2 …` | calendar event |
| `note …` | inbox markdown |
| anything else | `omarchy agent prompt` |

The snapshot is taken *before* the chip appears, so the overlay is not in the picture.

## Remove

```bash
~/.config/omarchy/plugins/io.github.goooooooooody.omarchy-pebble-voice/uninstall
omarchy plugin remove io.github.goooooooooody.omarchy-pebble-voice
```

Uninstall disables the plugin, removes the Hyprland bind markers, and deletes the plugin symlink if this checkout was linked. It leaves the VoxType daemon running and does not touch Pebble Index.

Menu **Remove plugin** does not run `uninstall`. Run `./uninstall` if you want the hotkey gone.

## Data access

| Path | Mode | Contents |
|---|---|---|
| `$XDG_RUNTIME_DIR/omarchy-pebble-voice/transcript.txt` | 0600 dir | last transcription (session only) |
| `$XDG_RUNTIME_DIR/omarchy-pebble-voice/window.png` | 0600 dir | focused-window snapshot for Look |
| `~/.config/hypr/bindings.lua` | existing | optional SUPER + Page_Down bind |

Transcripts are handed to Pebble Index (`pebble-index capture`). Index stores them in its own inbox database. This plugin does not keep a journal of speech. VoxType may also type or copy text according to its own config; Voice asks it to write a file instead.

## License

MIT. Hosted at [github.com/Goooooooooody/omarchy-pebble-voice](https://github.com/Goooooooooody/omarchy-pebble-voice).
