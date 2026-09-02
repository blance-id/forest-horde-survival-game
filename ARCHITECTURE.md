# Architecture

Godot 4.7.2 · GDScript (static typing everywhere) · GL Compatibility renderer ·
portrait 720×1280 base with `canvas_items` stretch and `expand` aspect.

## Layout

```
project.godot
autoload/            global singletons (kept deliberately small)
scenes/              .tscn files, grouped by domain
scripts/             .gd files mirroring scenes/ (core, gameplay, player, enemies, systems, ui)
resources/           data: Resource .tres files (chapters, weapons, upgrades, enemies, characters, configs)
assets/              art, audio, fonts (all externally sourced, see ASSET_SOURCES.md / AUDIO_SOURCES.md)
tests/               headless unit tests (tools/test.sh)
tools/               dev scripts: configure_project.gd, check.sh, shot.sh, test.sh
```

## Scene tree at runtime

```
Main (scripts/core/main.gd)
 ├── Game            current screen lives here (MainMenu, Game run, ...)
 ├── UI (CanvasLayer 100)
 │    └── Fade       full-screen ColorRect used by SceneRouter transitions
 ├── Audio           ambience players owned by screens
 └── DevTools        debug builds only: F3 overlay, --screenshot capture
```

## Autoloads

| Name | File | Responsibility |
|---|---|---|
| `Log` | autoload/log.gd | Leveled, categorised logging; errors always reach device logs |
| `SaveManager` | autoload/save_manager.gd | JSON profile in `user://`, backup rotation, corrupt-file recovery, debounced writes, flush on pause/quit |
| `GameState` | autoload/game_state.gd | The profile dictionary (coins, meta upgrades, unlocks, records, settings, stats) + transient hand-off data between screens |
| `AudioManager` | autoload/audio_manager.gd | Pooled SFX/UI/Voice players, music crossfade, bus volumes from settings |
| `SceneRouter` | autoload/scene_router.gd | Screen switching with fade + threaded loading; passes a `data` dict to the new screen's `setup()` |

Order matters: `Log` first, `GameState` depends on `SaveManager` (both are
ready before any screen), `AudioManager` reads `GameState` settings.

## Conventions

- Screens are scenes placed under `Main/Game`; they receive `setup(data: Dictionary)`.
- A screen may implement `on_app_background()` to react to the app being backgrounded.
- Persistent data is plain JSON-compatible dictionaries; `GameState._default_profile()`
  is the schema. New keys are added there and merged into old saves automatically.
- Gameplay never references texture paths directly; visuals come from `Resource`
  data (`CharacterData`, `EnemyData`, `WeaponData`, ...) so assets can be swapped
  by editing `.tres` files.
- Input: mouse emulates touch project-wide, so every control path is the touch path.

## Testing

`tests/test_case.gd` is a tiny assertion base class; `tests/run_tests.gd`
discovers `tests/test_*.gd` and runs them headless with autoloads available.
`tools/check.sh` boots the real game for N frames and fails on script errors;
`tools/shot.sh` renders under Xvfb for visual verification.
