# Known Issues

Open problems, workarounds and intentional gaps. Fixed items are removed, not
struck through — git history keeps the record.

## Build / tooling

- **Exit-time warnings.** Godot prints `WARNING: 3 ObjectDB instances were
  leaked at exit` on every run (autoload signal connections still alive at
  teardown) and, on the *first* run after a shader or script change,
  `ERROR: 2 resources still in use at exit` while the shader cache is rebuilt.
  Neither affects gameplay; `tools/check.sh` treats the second one as a failure,
  so rerun once after editing shaders.
- **Slow Xvfb captures.** With glow enabled the software GL renderer manages
  ~3–7 fps, so `tools/shot.sh` clamps delta to 0.133 s. Keep captures at
  ≤ 300 frames (≈ 40 s of game time) or the hero dies and the OVER panel
  covers the shot. Short particle bursts (0.15–0.4 s) are gone within 2–3
  frames at that delta, so capture them with `--lead=1..5`.

## Android

- **Default launcher icon.** `export_presets.cfg` has no launcher icons yet, so
  installs show the stock Godot icon. Replaced in the Android phase.
- **Debug signing only.** CI builds are signed with the export template's debug
  key — fine for sideloading, not for Google Play. See BUILD.md → Release
  signing.
- **Glow cost unverified on devices.** Bloom is on in the GL Compatibility
  renderer; it looks right on desktop but the frame cost on low-end phones has
  not been measured yet (optimisation phase).

## Gameplay / visuals

- **Particle budget is fixed.** Each FX pool is a ring buffer (512 sparks,
  384 glows, 256 smoke, 96 splats …); a huge burst simply recycles the oldest
  particle. Sized for ~200 enemies on screen; revisit if weapons grow much
  denser.
- **Hit-stop and pause.** `Engine.time_scale` is restored by an unscaled timer,
  so pausing during the 0.16 s boss-kill freeze is harmless, but a scene change
  mid-freeze relies on `Game._exit_tree` to reset it.
- **Giants are walk-through decor.** The oversized in-arena trees and plants
  have no collision: the hero and zombies walk through their trunks. They are
  placed at least 6 u from the centre so the start area stays clear.
- **Menu demo zombies pile up.** In the main-menu demo the hero is invulnerable
  and the level-4 orbit weapon keeps the crowd off; at extreme aspect ratios a
  few zombies can still stack on the hero for a moment before dying.
