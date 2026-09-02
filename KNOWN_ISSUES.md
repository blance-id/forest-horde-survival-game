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
  covers the shot.

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

- **Giants are walk-through decor.** The oversized in-arena trees and plants
  have no collision: the hero and zombies walk through their trunks. They are
  placed at least 6 u from the centre so the start area stays clear.
- **Menu demo zombies pile up.** In the main-menu demo the hero is invulnerable
  and the level-4 orbit weapon keeps the crowd off; at extreme aspect ratios a
  few zombies can still stack on the hero for a moment before dying.
