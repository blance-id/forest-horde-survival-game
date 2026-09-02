# Architecture

Godot 4.7.2 · GDScript (static typing everywhere, warnings are errors) ·
GL Compatibility renderer · portrait 720×1280 base with `canvas_items` stretch
and `expand` aspect · 3D world, 2D UI.

## Layout

```
project.godot
autoload/            global singletons (kept deliberately small)
scenes/              .tscn files, grouped by domain (main, gameplay, ui, dev)
scripts/             .gd files mirroring scenes/ (core, data, gameplay, player, enemies, systems, world, ui)
resources/           data: Resource .tres files (chapters, weapons, upgrades, enemies, characters, configs)
shaders/             ground, enemy_parts (horde animation), aura_disc
assets/              models, ui, effects, audio, fonts (all externally sourced, see ASSET_SOURCES.md / AUDIO_SOURCES.md)
tests/               headless unit tests (tools/test.sh)
tools/               dev scripts, see "Tooling"
```

## Scene tree at runtime

```
Main (scripts/core/main.gd)
 ├── Game            current screen lives here (MainMenu, Game run, ...)
 ├── UI (CanvasLayer 100)
 │    └── Fade       full-screen ColorRect used by SceneRouter transitions
 ├── Audio           ambience players owned by screens
 └── DevTools        debug builds only: F3 overlay, --screenshot capture, --dev= commands
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
`SoundBank` (scripts/systems) is a static helper on top of `AudioManager`
that resolves `assets/audio/{sfx,ui,jingles}/<name>[_NN].ogg` by name.
`Haptics` (scripts/systems) wraps `Input.vibrate_handheld` behind the
`haptics` setting with a 90 ms rate limit. `SafeArea` (scripts/ui) converts
the display cut-out into canvas pixels so top margins can be padded.

## Main menu: `scenes/ui/main_menu.tscn`

The menu is a **live demo of the run** under an ad-style overlay: the same
World / CameraRig / Player / Enemies / Projectiles / Weapons nodes as the game,
minus pickups, XP and the director. `MainMenu` (scripts/ui/main_menu.gd)
builds the arena, gives the invulnerable hero the demo weapons (blaster lv2, shovels lv4),
strolls it in a slow circle and trickles zombies in from `chapter.pick_enemy`
(capped at 26). Over it, a CanvasLayer holds the gradient shades, coins pill,
settings gear, title block, chapter card (best record from
`GameState.get_chapter_record`) and the pulsing PLAY button.
`SettingsPanel` (scenes/ui/settings_panel.tscn) is a reusable overlay with
`ToggleSwitch` controls (scripts/ui/toggle_switch.gd, drawn in code) that
write `music_volume` / `sfx_volume` through `GameState.set_setting`, which
`AudioManager` already listens to.

## The run: `scenes/gameplay/game.tscn`

The run is **manager-driven**: there are no per-enemy nodes, physics bodies or
Area3Ds. `Game` (scripts/gameplay/game.gd) owns the state machine
(RUNNING / LEVEL_UP / PAUSED / OVER), the spawn director and XP/level-ups, and
ticks every manager once per frame in a fixed order:

```
Game (Node3D)
 ├── World        Arena builds into this: WorldEnvironment (fog + glow), sun, ground shader, border trees, decor, giants
 ├── CameraRig    Camera3D on a pitched arm (55°, 9.5 u, fov 40, KEEP_WIDTH); smoothed follow, 0.9 u movement lead, trauma² noise shake
 ├── Player       hero rig + AnimationTree + weapon on a BoneAttachment3D; moves in XZ, contact damage
 ├── Enemies      EnemyManager: one MultiMesh per EnemyData, plain Enemy records, spatial hash
 ├── Projectiles  ProjectileManager: bullet records in one MultiMesh, hit queries against Enemies
 ├── Weapons      WeaponSystem: WeaponData + level slots; projectile / orbit / aura kinds
 ├── Pickups      PickupManager: gems, coins, hearts in MultiMeshes, magnet + collection
 ├── Fx           FxManager: GPU-replayed particle pools + ground splats (see below)
 └── UI (CanvasLayer 10)
      ├── HUD           Vignette, HP/XP bars, timer, kills, coins, boss bar, announcements, move hint, TouchJoystick (floating, drag-to-recentre; reset by Game._freeze on every pause), DamageNumbers
      ├── LevelUpPanel  3 cards, pauses the tree
      ├── PausePanel
      └── ResultPanel   win/lose stats + coin reward → retry / menu
```

Tick order per frame: `player → weapon_system → enemies → projectiles →
pickups → fx → camera_rig.follow → hud.place_hero_hp → hud.tick`. Everything
simulates in XZ as `Vector2` and is written to 3D transforms at the end of
each tick.

### Game feel

Everything juicy hangs off signals so gameplay code never knows about VFX:
`ProjectileManager.enemy_hit` / `WeaponSystem.enemy_hit` (with the weapon
tint), `WeaponSystem.fired` / `aura_pulsed`, `EnemyManager.enemy_killed` /
`boss_killed`, `PickupManager.collected`, `Player.damaged`. `Game` turns them
into `FxManager` presets, `DamageNumbers`, camera shake, haptics and hit-stop.

- **FxManager** (scripts/systems/fx_manager.gd) never touches a particle after
  spawning it. Each pool (spark, glow, star, flash, smoke, splat) is one
  MultiMesh of unit quads; `emit()` writes the whole particle into one instance
  and `shaders/fx_particle.gdshaderinc` replays it from the `game_time`
  uniform: transform origin = spawn position, basis.x = velocity,
  basis.y = (size_start, size_end, gravity), basis.z = (spin, drag, spawn_time),
  `INSTANCE_CUSTOM` = (fade_in, life, atlas frame, ground-decal flag),
  `COLOR` = HDR tint. **Compatibility stores MultiMesh COLOR / CUSTOM as
  16-bit floats**, which is why the timestamp lives in the 32-bit transform.
  Dead particles are parked with spawn_time −1e6 so they collapse to zero size.
  Splats are `mix`-blended ground quads from a 4×2 atlas built at startup.
- **Hit-stop**: `Game._hit_stop(scale, duration)` sets `Engine.time_scale` and
  restores it from an unscaled timer (boss kill 0.05 s, hero death slow-mo).
- **DamageNumbers** (scripts/ui/damage_numbers.gd) recycles 40 `Number` labels
  and re-projects them from world space every frame (`hud.tick(camera, delta)`).
- **Vignette**: a full-rect `ColorRect` with `shaders/vignette.gdshader`; the HUD
  drives `strength` for damage flashes and the low-HP pulse.

### Horde rendering

`EnemyMeshBaker` bakes each Kenney "mini" model (rigid-part or skinned) into a
single `ArrayMesh` whose vertices carry a part id and pivot in CUSTOM0/CUSTOM1.
`shaders/enemy_parts.gdshader` animates legs/arms/head/lean per instance from
the global `game_time` uniform and the MultiMesh custom data
`(phase, alive, hit_time, death_time)`, so hundreds of walking, flashing and
falling-over zombies cost one draw call per enemy type. Hidden instances are
parked at y = −50 with a zero basis.

### Queries

`EnemyManager` rebuilds a spatial hash (`CELL = 1.5`) every tick;
`query_circle(center, radius, out)` and `nearest(center, max_dist)` are the only
hit tests in the game. Bucket lookups are typed `Variant` because a typed
`Array` variable cannot receive `null`.

### Data

`scripts/data/*.gd` are the Resource schemas, `resources/**/*.tres` the
content. `RunStats` (scripts/gameplay/run_stats.gd) folds character base
stats, meta upgrades and in-run passives into the multipliers every manager
reads (`damage_mult()`, `attack_speed_mult()`, `area_mult()` …).

| Resource | Holds |
|---|---|
| `CharacterData` | hero model, weapon model + mount bone/offset, muzzle offset, animation names, base stats, starting weapon |
| `EnemyData` | model, tint, scale, stats, XP/coins, boss flag, procedural walk parameters |
| `WeaponData` | kind, base stats, projectile model/tint, icon, card text, `level_ups` table → `stats_at(level)` |
| `UpgradeData` | stat key + value per level, icon, card text |
| `ChapterData` | duration, arena size, palette/lighting, border + decor models, wave weights, cap/interval/HP curves, timed events, rewards |

## Conventions

- Screens are scenes placed under `Main/Game`; they receive `setup(data: Dictionary)`.
- A screen may implement `on_app_background()` to react to the app being backgrounded
  and `dev_command(cmd: String)` to react to `--dev=` hooks from DevTools.
- Persistent data is plain JSON-compatible dictionaries; `GameState._default_profile()`
  is the schema. New keys are added there and merged into old saves automatically.
- Gameplay never references asset paths directly; visuals come from `Resource`
  data so assets can be swapped by editing `.tres` files.
- Input: mouse emulates touch project-wide, so every control path is the touch path.
- Pausing uses `get_tree().paused`; overlay panels run with `process_mode = ALWAYS`.
- Constants that must be constant expressions (e.g. `HIDDEN` transforms) use
  the `Transform3D(x, y, z, origin)` constructor, not `Basis.from_scale`.

## Tooling

| Script | Use |
|---|---|
| `tools/check.sh [frames] -- --screen=res://…` | Boots the real game headless, fails on `SCRIPT ERROR` / `ERROR` |
| `tools/shot.sh out.png [frames] --screen=… [--dev=cmd,…] [--lead=N]` | Renders under Xvfb + opengl3 and saves a screenshot; `--dev=` drives `dev_command` (levelup, pause, win, die, hurt, horde, boss, weapons, fx, splats, nuke, move, stop, touch) `N` frames before the shot (default 30; use 1–5 to catch particle bursts). Frames count from the moment `--screen` is up, so headless and Xvfb agree. With glow on, Xvfb manages ~3–7 fps, so keep captures ≤ 300 frames |
| `tools/test.sh` | Runs `tests/test_*.gd` headless with autoloads available |
| `godot --headless --check-only --script <file>` | Per-script parse check with file:line |
| `godot --headless -s tools/img_crop.gd -- in.png out.png x y w h [scale]` | Crop/zoom a screenshot (no image tools on the box) |
| `godot --headless -s tools/build_theme.gd` | Regenerates `resources/configs/ui_theme.tres` from the UI kit + fonts |
| `tools/build_assets.py` | Copies/renames raw downloads from `assets/_downloads/` into `assets/` |
| `scenes/dev/hero_view.tscn` | Close-up hero viewer (`--hero=`, `--yaw=`, `--move`, `--bones`) for weapon mounting |

SceneTree scripts run with `-s` must live under `res://`; autoloads are not
available in their `_init`, only from the first `_process`.
