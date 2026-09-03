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

### Grass

The floor is the surface on screen the most, so it gets a real texture rather
than a pile of noise — but a *texture*, not geometry. A first pass built the
grass out of thousands of 3D blades; it read as clutter and made the game look
messy, so it was cut.

`tools/build_assets.py` generates a seamless greyscale grass detail map
(`draw_grass_texture`) from three layers, coarse to fine: broad clumps you
notice across the map, mid tufts at walking distance, fine blades underfoot.
Everything is drawn with wrapped coordinates so the tile has no seam, and it
is greyscale so each chapter tints it with its own palette.

`shaders/ground.gdshader` samples it **twice** — at two scales, one rotated —
and cross-fades by a very slow noise field, so the repeat never lines up with
itself. That is the whole anti-tiling trick: one cheap texture reads as unique
ground across a 90-unit map with no geometry and no atlas. The second sample
is dropped on LOW. Mipmaps are on (`mipmaps/generate=true` in the `.import`)
or the tile aliases into shimmering noise in the distance.

### Boundary

Two things mark where the map stops. The ground shader washes the grass
towards the fog colour past the edge, and `Arena._build_fog_wall()` stands an
actual curtain of mist on the boundary — a strip mesh built from
`ArenaBounds.radius_at()`, so a clover map gets a clover-shaped wall. It is
clear at ankle height so props at the rim still read, and thick above.

### Terrain

`Hills` (scripts/world/hills.gd) owns the only solid ground in the game. Rock
outcrops stand inside the arena as `Obstacle` circles that both the hero
(`Game` pushes them out each frame) and the horde (`EnemyManager.obstacles`,
checked in `_separation`) have to walk around — an open field with corners in
it. `Obstacle` is its own class rather than an inner one so terrain, the hero
and the horde can all name it without depending on each other.

The mountain range is part of the arena *rim*, not a distant horizon. With the
camera pitched 55 degrees down the horizon never enters frame, so anything far
enough away to read as distance is simply off the top of the screen; the
bluffs are mixed in among the border trees instead, tall enough to loom when
you reach the edge. Fog runs to 95 units and the camera's far plane to 260 so
they are not cut off, and the chapter palettes fog to a light haze — a range
silhouetted against near-black sky is just a hole in the frame.

### The world

`ArenaBounds` (scripts/world/arena_bounds.gd) is the single answer to "is this
inside the map". It holds a shape (square / circle / clover) and a radius, and
everything that has to stay inside — the hero, the horde, prop scatter, spawn
rings, the minimap outline — asks it rather than clamping to a square of its
own. A chapter changes its map shape by changing one enum.

`Quality` (scripts/core/quality.gd) is the single budget for visual work:
LOW / NORMAL / MAX, chosen in Settings and stored in the profile. Ground blade
detail, shadow distance and resolution, foliage counts, which glow blur levels
are mixed in, and MSAA all read from it instead of guessing, so MAX is a real
step up on a good phone and LOW actually saves work on a bad one.

`Arena` builds the static dressing (environment, ground, border band, decor,
giants). Two managers sit beside it and own things that change during a run:

- **Forest** (scripts/world/forest.gd) — choppable trees and concealing
  bushes, both plain records over MultiMeshes. Standing within `CHOP_RANGE` of
  a trunk auto-swings at it every `CHOP_INTERVAL`; the last swing hides the
  tree instance, places a stump in a second MultiMesh and emits `felled`, and
  `Game` scatters wood pickups. `hides()` answers whether a point is inside a
  bush — a bush is a ring of normal-sized plants, not one scaled-up plant, so
  the hero can stand in it.
- **Traps** (scripts/world/traps.gd) — static hazards that damage the hero and
  the horde equally, one victim per spring with a `REARM` delay, kept clear of
  the spawn point.

Concealment closes the loop in `Game._tick_cover`: while the hero is inside a
bush, `EnemyManager.player_hidden` is set and the horde walks to `last_seen`
instead of tracking. Killing from cover sets `_exposed`, which gives the
position away for `COVER_BLOWN_TIME`.

### Generated models

The CC0 kits have no animals and no vehicles, so `tools/build_models.gd`
builds the wolf, the forest serpent and the walker mech out of boxes and saves
them as ordinary scenes in `assets/models/built/`. Two things make them fit
rather than look bolted on:

- **They use the real palette.** Faces point at the middle of a *verified
  uniform* swatch in the Graveyard colormap. Godot's compressed vertex
  attributes jitter a UV by a hair, so a coordinate near a swatch edge samples
  the anti-aliased boundary and speckles the whole face — which is exactly
  what happened first time round.
- **They use the real rig.** Parts are named `torso`, `head`, `leg-*`,
  `arm-*`, so `EnemyMeshBaker` bakes them and `enemy_parts.gdshader` animates
  them with no special case anywhere. For four legs on a two-leg rig, the
  front legs go in the *arm* slots: the shader swings arms opposite to legs,
  so front-right moves with back-left and the wolf trots.

### Vehicles and survivors

`VehicleManager` parks walker mechs around the map. Walking into one mounts
it: `WeaponSystem.enabled` goes false so the hero's guns fall silent, the
mech's twin cannons fire instead, `Player.vehicle_scale` shrinks the hero into
the cockpit, and `absorb()` diverts incoming damage into the hull. Finite ammo
and finite hull are the design — either running out puts the player back on
foot where the fight left them.

`Survivors` scatters people to free. Standing inside `RESCUE_RANGE` for
`RESCUE_TIME` frees one and hands over a relic straight into the run's bag;
walking away resets the timer, so the cost is standing still in the open while
the horde closes.

### UI colour

The Kenney kit is mostly cream: panels, cards, round buttons. Near-white text
and Kenney's white icon sheets vanish into it, so the theme carries two
ladders — `Hero`/`Title`/`Heading`/`Big`/`Small`/`Number`/`Dim` in near-white
with a dark outline for text over the world, and the same names suffixed
`Dark` in chocolate with no outline for text on cream. Buttons with a cream
face (`Button`, `RoundButton`, `CardButton`) tint both their label and their
icon chocolate; `PrimaryButton` is red and stays white.

One catch: `icon_*_color` multiplies, so a button carrying a full-colour icon
rather than a white sheet — the relic slots on the HUD — has to override those
back to white.

### Waves

A chapter is a list of waves, not a stopwatch. `ChapterData.waves` holds one
entry per wave — the groups it sends, its HP scale, spawn interval and
concurrent cap, and whether it is the boss wave.

`Game._tick_director` runs exactly one wave at a time: it shuffles that wave's
roster into `_wave_queue`, trickles bodies in on `interval` while `alive` is
under `cap`, and only when the queue is empty *and* nothing is standing does
`_clear_wave()` advance. A boss is pulled out of the shuffle and spawned
first, so its entrance opens the wave instead of interrupting the middle of
one. Killing the boss ends the run — escorts still alive do not matter —
after `BOSS_WIN_DELAY` so the kill lands before the badge covers it.

`best_time` therefore means *fastest clear*, and a run that ends in death
never sets one.

**Hit-stop has two rules, and both were learned the hard way.**

1. It must not use a `SceneTreeTimer` to lift itself. The timer counts scaled
   time, so the one meant to end a 0.16 s freeze at `time_scale` 0.05 does not
   fire for seconds. `_tick_hit_stop()` ends it by wall clock instead.
2. `Engine.time_scale` must be 1 outside a live frame. `Game` is pausable, so
   the instant the tree freezes for a level-up, a pause or a death,
   `_tick_hit_stop()` stops running — while every `PROCESS_MODE_ALWAYS` panel
   keeps rendering at whatever scale the freeze left behind. Dying during a
   hit-stop therefore left the death overlay, the revive countdown and the
   whole game afterwards in permanent slow motion. `_freeze()` calls
   `_end_hit_stop()`, so a stopped tree always runs at full speed.

### Bosses

`BossBrain` (scripts/enemies/boss_brain.gd) runs a boss's `EnemyData.abilities`
list. Each entry keeps its own cooldown, staggered at spawn, so a boss with a
leap, a summon and a roar cycles a pattern instead of leaning on whichever came
off cooldown first. The brain owns only what the horde can resolve itself —
the leap arc and the roar's haste — and reports the rest through
`boss_ability` / `boss_slammed` so `Game` can spawn minions, fire volleys and
answer with sound and shake.

A leap is crouch → flight → slam. `Enemy.height` lifts the body off the ground
for the arc (the only thing in the game that leaves y = 0), and while
`BossBrain.is_busy()` the normal walk is skipped so it does not fight the
brain for the position. The landing damages and throws back everything inside
its radius, hero and horde alike, with a hit-stop and a full-strength shake.

Bosses are also outside the separation system entirely — see the note above —
so a leap lands where it was aimed rather than being nudged by whatever it
lands on.

### Ending a run

Both endings freeze the tree (`_freeze()`), so the last frame of the fight
stays on screen: the horde stops mid-lunge, particles hang in the air, and
`OutcomeOverlay` answers over the top — a red flood with a closing vignette
for death, a gold flood and a badge for a win. Nothing on the `Game` side
ticks after that; `_process` returns early for every non-RUNNING state, and
the overlay, revive panel and result card all run on `PROCESS_MODE_ALWAYS`
and drive their own timing.

One trap worth knowing: a tween built with `set_parallel(true)` still runs
everything after `chain()` in parallel, so an interval-then-callback pair
fires instantly. The overlay's hand-off beat uses its own sequential tween.

### Relics, the bag and revives

`RelicData` is a one-shot item; `RelicCatalog` is the one place that turns the
ids stored in the save file back into resources (a profile must never hold
resource paths). The profile keeps two lists: `inventory` is everything owned,
`bag` is the up-to-`BAG_SIZE` subset packed for the next run.

Starting a run calls `GameState.take_bag()`, which **moves** those relics out
of the inventory — they are in the field now. `Game` shows them as tappable
HUD buttons, `_use_relic` spends one and applies its effect, and only a win
calls `return_unused()`. Dying keeps them gone, which is what makes packing a
relic a decision rather than a formality.

Bosses drop a relic into the inventory (`EnemyData.boss_drop`), so a kill pays
off in the *next* run. `StorePanel` is the store and the bag in one list —
BUY and PACK on the same row, because they answer the same question.

`RevivePanel` sells the run back for `100 · 2^n` coins with a countdown; the
run sits in `State.DYING` while it is open, still ticking the world so the
slow-motion death keeps playing behind it.

### Towers

`TowerManager` (scripts/systems/tower_manager.gd) + `TowerData`. A nest costs
wood, is raised at the hero's feet by one HUD button, and then does nothing on
its own. Each tick:

1. It fires only while the hero is inside `supply_range` *and* the run has
   ammo left — the player is handing over their own magazines. Shots go
   through `ProjectileManager.fire()` with the tower's `WeaponData`, so they
   reuse the hero's bullets, hit routing, sounds and sparks for free.
2. `_set_noise` registers an `EnemyManager.Lure` while, and only while, the
   tower is firing. `EnemyManager._pick_lure` steers any enemy inside the
   noise radius at the tower instead of the hero, and `_land_attack` sends the
   damage into the lure's `damage_sink` — which is what lets a tower be torn
   down. Stop feeding it and the lure is removed: a silent nest is invisible
   and untouchable.

`ammo_spent` bills the run so the HUD counter and the towers never disagree.

### Classes, weight and weapon kinds

A class is a `CharacterData` with its own five-weapon set (`weapons`) and its
own `carry_capacity`; `Game._weapon_pool()` offers that set, falling back to
the scene's list. Each set covers the same five shapes — sidearm, rifle,
spinner, shield, lantern — so a class is a flavour and a stat line rather than
a different game.

**Weight is the constraint that makes a build a choice.** Every weapon has a
`weight`; `WeaponSystem.can_carry()` refuses one that would not fit, and the
level-up roll never offers a card that cannot be taken. `RunStats.move_speed()`
loses up to `WEIGHT_SLOW` at full load, so filling the bar costs mobility. One
heavy weapon rules out a second; two or three light ones combine.

`WeaponData.Kind.SHIELD` is an aura that shoves instead of burning: the same
disc query, but each hit throws the body out and `armor_bonus` is folded into
`RunStats.shield_armor` while it is carried. It is drawn on a *hemisphere*
rather than a ground quad — a flat disc disappears the moment the horde stands
on it — with a `cull_back` additive shell so it does not bleach what is inside.

### Damage types

`Damage` (scripts/gameplay/damage.gd) owns the three types, their colours and
`resolve()`. `EnemyManager.hit()` takes the type and applies the target's
`physical_resist` / `magic_resist` itself, so no caller can forget; it also
records `last_dealt`, which every `enemy_hit` signal reports instead of the
raw number, keeping the floating damage number honest about the health bar.
Hits are painted with `Damage.color()`, which is the entire tutorial: a player
who watches pale numbers bounce off a wisp and violet ones land learns the
system without a tooltip. Traps deal TRUE damage — spikes do not care about
armour.

**The boss is outside the separation system.** The spatial hash checks a 2x2
block of cells, which assumes every body is small next to `CELL`; a boss at
radius 3+ spans a dozen cells, so it both missed most of its neighbours and
generated pushes the size of its own body — it jittered through the horde and
flung zombies around. Bosses now shove without being shoved: they skip
`_separation` and ignore knockback, everyone else gets an explicit check
against the boss that the grid would have missed, and the total push is capped
at `MAX_SEPARATION` body radii. A boss also flattens the trees it walks
through (`Forest.crush`), since something that size standing inside a trunk
reads as a broken level.

### Enemy attacks

Nothing damages the hero on contact. Every attack runs wind-up → strike →
damage inside `EnemyManager._move`:

1. In range and off cooldown, the enemy roots itself, sets `windup` from
   `EnemyData.attack_windup` and emits `enemy_winding_up`. `charge` ramps 0→1
   and `_write_transform` rears the body back and swells it — the tell.
2. When the wind-up expires, `_land_attack` fires: melee only connects if the
   hero is still inside `reach + lunge`, so walking out of a swing works.
   `strike` snaps to 1 and decays over `STRIKE_TIME`, lunging the body forward.
3. `enemy_struck` carries the impact point. Casters (`EnemyData.ranged`) skip
   the melee check and hand the shot to
   `ProjectileManager.spawn_enemy_bolt()` instead — a slow tinted sphere that
   flies at *where the hero was*, so standing still is what gets you hit.

Casters are the same machinery pointed the other way: `EnemyData.ranged` with
a long `attack_windup` and a slow `bolt_speed` is the Forest Hexer's 2 s cast
plus a bolt the player can walk out of.

`Game` turns both signals into sound and sparks, and only for enemies within
`TELL_RANGE`: two hundred simultaneous tells would be one wall of noise.

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
- **Minimap** (scripts/ui/minimap.gd) draws the whole arena in one `_draw()`:
  the shape outline traced once from `ArenaBounds`, standing trees, bushes,
  traps, a sampled subset of the horde and the hero. The arena is far larger
  than the camera sees, so this is how the player reads the map at all.
- **EnemyBars** (scripts/ui/enemy_bars.gd) draws every on-screen enemy's health
  in one canvas item — a node per enemy would cost more than the horde does.
  Bars are culled past `RANGE`, capped at `MAX_BARS`, and elites (×5 XP and up)
  get a gold frame so tiers read without a legend.
- **DamageNumbers** (scripts/ui/damage_numbers.gd) recycles 40 `Number` labels
  and re-projects them from world space every frame (`hud.tick(camera, delta)`).
- **Vignette**: a full-rect `ColorRect` with `shaders/vignette.gdshader`; the HUD
  drives `strength` for damage flashes and the low-HP pulse.

### HUD

`scenes/ui/hud.tscn` + `scripts/ui/hud.gd`. The HUD owns no state: `Game`
pushes values in (`setup`, `set_hp`, `set_xp`, `set_time`, `set_kills`,
`set_build`, `set_boss`, `add_coins`) and `hud.tick(camera, delta)` drives the
per-frame parts. Three child widgets do the drawing:

- **RunTimeline** (scripts/ui/run_timeline.gd) `_draw()`s the chapter as a
  track: it reads `ChapterData.events`, puts each event's `EnemyData.icon` on
  the track at its time (boss events get a red hexagon), fills up to the
  elapsed time and rides a hero dot on the fill edge. The fill turns red while
  the boss is alive.
- **BuildBar** (scripts/ui/build_bar.gd) is a row of Adventure-pack hexagons:
  4 weapon slots that fill in as weapons are picked, then one smaller hexagon
  per passive in pick-up order. Slots punch when their level changes.
- **CoinRain** (scripts/ui/coin_rain.gd) pools 24 coin sprites and arcs them
  from a pickup's unprojected screen position into the coin counter; the
  counter only counts up in the landing callback.

Kills inside `COMBO_WINDOW` chain into a combo callout that escalates through
four colour/word tiers. `_punch()` is the shared scale-pop helper — it tracks
one tween per node so repeated punches restart instead of stacking. The heart
icon is generated by `tools/build_assets.py` (`draw_heart`); no pack ships one.
`ResultPanel` counts the coin reward up and slams a "NEW RECORD!" stamp when
`GameState.record_run` reports a new best time.

### Audio

Buses: `Master > Music / SFX / UI / Voice` (`default_bus_layout.tres`).
Sound is data-driven and hangs off the same signals as the VFX:

- **AudioManager** (autoload) owns pooled `AudioStreamPlayer`s per bus
  (16 SFX / 4 UI / 2 Voice), a 40 ms per-stream rate limit so a horde hit
  never stacks 50 copies of one clip, two music players that
  `play_music(stream, fade)` crossfades between (same stream = no-op,
  `stop_music(fade)` = crossfade to nothing) and `duck_music(on)` which tweens
  a −9 dB offset onto the Music bus while a menu covers the action.
  `set_bus_volume` always folds the duck offset in, so settings changes during
  a pause keep the duck.
- **SoundBank** (scripts/systems/sound_bank.gd) resolves clips by name:
  `sfx/ui/jingle(name)` play `assets/audio/<dir>/<name>.ogg` or a random
  `<name>_01..09.ogg` variant; `music(name)` returns the stream from
  `assets/audio/music/`. An empty name is silent (melee weapons have no fire
  sound). Music `.import` files must set `loop = true` — the importer default
  is off and `tests/test_audio.gd` asserts it.
- **Data**: `WeaponData.fire_sound` / `hit_sound` and `ChapterData.music` /
  `boss_music`. `Game` reads them from the signals: `fired` / `aura_pulsed` →
  fire sound, `enemy_hit` → hit sound, `enemy_killed` → `zombie_die` + a
  `zombie_death` vocal (or `explosion` for the boss), `boss_spawned` → roar +
  boss music, `boss_killed` → back to chapter music, `Player.damaged` →
  `zombie_attack`. `Game._tick_ambience` adds hero footsteps while moving and
  a distance-attenuated `zombie_growl` from a random live enemy within 7 m.
  Pause / level-up duck the music; death, win and give-up fade it out; the
  main menu plays `menu`.
- Assets come from `tools/build_assets.py` (`~/tools/pyenv/bin/python`, needs
  Pillow + soundfile + numpy): Kenney packs are copied, the zombie WAVs are
  converted to mono normalised OGG and the JRPG tracks copied into
  `assets/audio/music/`. Sources and the event → clip map: `AUDIO_SOURCES.md`.
- Godot only releases audio playbacks on a mix step, which never runs during
  shutdown, so any run that quits with music playing prints
  `ERROR: N resources still in use at exit` plus a leaked-ObjectDB warning.
  `tools/check.sh` and `tools/shot.sh` filter exactly that line.

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
| `tools/check.sh [frames] -- --screen=res://…` | Boots the real game headless, fails on `SCRIPT ERROR` / `ERROR` (except the audio "resources still in use at exit" line) |
| `tools/shot.sh out.png [frames] --screen=… [--dev=cmd,…] [--lead=N]` | Renders under Xvfb + opengl3 and saves a screenshot; `--dev=` drives `dev_command` (levelup, pause, win, die, hurt, horde, boss, weapons, fx, splats, nuke, move, stop, touch) `N` frames before the shot (default 30; use 1–5 to catch particle bursts). Frames count from the moment `--screen` is up, so headless and Xvfb agree. With glow on, Xvfb manages ~3–7 fps, so keep captures ≤ 300 frames |
| `tools/test.sh` | Runs `tests/test_*.gd` headless with autoloads available |
| `godot --headless --check-only --script <file>` | Per-script parse check with file:line |
| `godot --headless -s tools/img_crop.gd -- in.png out.png x y w h [scale]` | Crop/zoom a screenshot (no image tools on the box) |
| `godot --headless -s tools/build_theme.gd` | Regenerates `resources/configs/ui_theme.tres` from the UI kit + fonts |
| `~/tools/pyenv/bin/python tools/build_assets.py` | Copies/renames raw downloads from `assets/_downloads/` into `assets/`; converts zombie WAVs to OGG (Pillow, soundfile, numpy) |
| `scenes/dev/hero_view.tscn` | Close-up hero viewer (`--hero=`, `--yaw=`, `--move`, `--bones`) for weapon mounting |

SceneTree scripts run with `-s` must live under `res://`; autoloads are not
available in their `_init`, only from the first `_process`.
