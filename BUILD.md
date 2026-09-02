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

## Android

### Download a build

Every push to `main` runs `.github/workflows/android-release.yml`, which
exports the APK and publishes it on the GitHub **Releases** page:

- `latest-build` — rolling pre-release, replaced on every push to `main`.
  Asset: `forest-zombie-survival-latest-build.apk`.
- `vX.Y.Z` — pushing a tag such as `v0.2.0` publishes a proper, permanent
  release with `forest-zombie-survival-vX.Y.Z.apk`.

Install: download the APK on the phone, allow installs from the browser when
asked, open it. The builds are **debug-signed** (the export template's debug
keystore), so they install side-by-side but cannot be uploaded to Google Play.
The Android `version/code` is stamped with the workflow run number, so each
build updates over the previous one; `version/name` follows
`application/config/version` in `project.godot`.

### How the workflow builds

The `build` job runs inside `barichello/godot-ci:4.7.2` (Godot + export
templates + Android SDK), moves the templates from `/root` into the runner's
`$HOME`, imports the project, runs `godot --headless --export-debug "Android"`,
then runs `tools/test.sh` and a 120-frame `tools/check.sh` boot as a smoke test.
The `release` job uploads the APK with the `gh` CLI using the workflow's own
`GITHUB_TOKEN` — no secrets need to be configured.

Trigger a build by hand from the Actions tab (`workflow_dispatch`), or:

```bash
gh workflow run "Android release" -R blance-id/forest-horde-survival-game
gh run watch -R blance-id/forest-horde-survival-game
```

### Export locally

Install the Android export template for 4.7.2 (Editor → Manage Export
Templates) and point the editor at an Android SDK + JDK 17, then:

```bash
godot --headless --import
godot --headless --export-debug "Android" build/android/forest-zombie-survival.apk
```

The preset is `Android` in `export_presets.cfg` (armeabi-v7a + arm64-v8a,
immersive + edge-to-edge, vibrate permission, package
`com.wolftagonstudio.forestzombiesurvival`).

### Release signing (Play Store)

A store build needs a release keystore. Do **not** commit it; add it as the
repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_USER`,
`ANDROID_KEYSTORE_PASSWORD`, and the workflow can be extended to write it to
disk and export with `--export-release`. This is planned for the Android phase.

## iOS

Not set up yet — the iOS export needs a macOS runner with Xcode and an Apple
developer team; it will get its own section once that phase starts.
