# Build & Run

## Requirements

- Godot **4.7.2** (standard build, no C#). On this dev box it is installed at
  `~/tools/godot/godot` and symlinked to `~/.local/bin/godot`.
- Linux headless checks additionally use `xvfb-run` (package `xvfb`).

## Run on desktop

```bash
godot                      # opens the game (main scene) in a phone-sized window
godot --editor             # opens the editor
```

Mouse input is emulated as touch, so the same drag controls work on desktop.
`F3` toggles the performance overlay (debug builds only).

## Headless checks (used after every change)

```bash
tools/check.sh [frames]                  # boots the game for N frames, fails on script errors
tools/shot.sh out.png [frames] [--screen=res://scenes/ui/main_menu.tscn]
                                         # renders under Xvfb and saves a screenshot
godot --headless --import                # re-import assets after adding files
godot --headless -s tools/configure_project.gd
                                         # regenerate project.godot settings
```

Command-line user args understood by the game in debug builds
(pass after `--`): `--screenshot=PATH`, `--after=FRAMES`, `--screen=res://...`, `--quit`.

## Tests

```bash
tools/test.sh                            # runs every script in tests/ headless
```

## Android / iOS

See the Android and iOS sections at the bottom of this file once those phases
are complete; export presets live in `export_presets.cfg`.
