# Asset Sources

Every visual asset in `assets/` is third-party and legally licensed for commercial use.
Raw downloads live in `assets/_downloads/` (git-ignored); `tools/build_assets.py`
turns them into the committed files listed here, so the pipeline is reproducible.
Audio is tracked separately in `AUDIO_SOURCES.md`.

Gameplay never references these files directly: characters, enemies, weapons and
chapters are `Resource` files under `resources/` that point at models and icons, so
every asset can be swapped for original art by editing `.tres` files only.

## Attribution required in-game

None. Everything below is CC0 or SIL OFL; no credit line is required. A credits
screen still names Kenney and the font authors as a courtesy.

## Table

| Asset | Source | URL | Creator | License | Modification allowed | Commercial use | Attribution |
|---|---|---|---|---|---|---|---|
| Graveyard models (`assets/models/graveyard/*.glb` + `Textures/colormap.png`) — zombie, skeleton, vampire, ghost, keeper rigs; pines, gravestones, crosses, fences, lanterns, pumpkins, shovel, debris, coffin, candle, fire basket | Kenney | https://kenney.nl/assets/graveyard-kit | Kenney (Kenney Vleugels) | CC0 1.0 | Yes | Yes | Not required |
| Forest models (`assets/models/forest/*.glb` + colormap) — trees, rocks, stones, grass/dirt patches, plant, fence, tent, flag, target, archer rig, bow, arrow | Kenney | https://kenney.nl/assets/mini-forest | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Hero rigs (`assets/models/characters/character-{male,female}-{a..f}.glb` + colormap) — skinned "mini" characters with idle / holding / sprint / die animations | Kenney | https://kenney.nl/assets/mini-characters | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Dungeon models (`assets/models/dungeon/*.glb` + colormap) — coin, chest, potion, key, orc and human rigs, barrel, pot, sword, spear, round shield, trap | Kenney | https://kenney.nl/assets/mini-dungeon | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Nature models (`assets/models/nature/*.glb`) — ~100 models: trees in dark and autumn sets, pines, bushes you can stand in, stumps, logs, grass, flowers, mushrooms, the rock / stone / cliff sets used for hills and the mountain rim, stone paths, camp props; self-contained materials, no shared colormap | Kenney | https://kenney.nl/assets/nature-kit | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Wolf, forest serpent and walker mech (`assets/models/built/*.tscn`) | Generated in-repo by `tools/build_models.gd` from boxes, textured with the Kenney Graveyard colormap | (this repository) | CC0 1.0 (derived from Kenney CC0 art) | Yes | Yes | Not required |
| Blaster models (`assets/models/blasters/*.glb` + colormap) — blasters a–r, foam bullets, grenades, smoke puff | Kenney | https://kenney.nl/assets/blaster-kit | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Card / item icons (`assets/ui/items/*.png`) — Kenney's own 64 px preview renders shipped inside the five packs above (blaster-k, blaster-d, clip, target, shovel, lantern, candles, pumpkin, potion, sword, shield, coin, chest, defibrillator, hero and enemy portraits) | Kenney | (same packs as the models) | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Particle textures (`assets/effects/particles/`) — circles, sparks, smoke, muzzle flashes, flare, downscaled to 128 px | Kenney | https://kenney.nl/assets/particle-pack | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Splat decals (`assets/effects/splats/`) — 8 white splats (256 px), tinted at runtime for blood/goo | Kenney | https://kenney.nl/assets/splat-pack | Kenney | CC0 1.0 | Yes | Yes | Not required |
| UI kit (`assets/ui/adventure/`) — buttons, panels, banners, progress bars, checkboxes ("Double" size) | Kenney | https://kenney.nl/assets/ui-pack-adventure | Kenney | CC0 1.0 | Yes | Yes | Not required |
| UI icons (`assets/ui/icons/`) — white 2x icons (pause, gear, audio, home, star, trophy, …) | Kenney | https://kenney.nl/assets/game-icons | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Display font (`assets/fonts/LilitaOne-Regular.ttf`) | Google Fonts | https://fonts.google.com/specimen/Lilita+One | Juan Montoreano | SIL OFL 1.1 (`assets/fonts/OFL-LilitaOne.txt`) | Yes (renamed derivatives only) | Yes | Not required in-game; license file kept |
| Body font (`assets/fonts/Nunito-Variable.ttf`) | Google Fonts | https://fonts.google.com/specimen/Nunito | Vernon Adams, Cyreal, Jacques Le Bailly | SIL OFL 1.1 (`assets/fonts/OFL-Nunito.txt`) | Yes (renamed derivatives only) | Yes | Not required in-game; license file kept |

## Modifications made

- Models: copied unchanged (GLB + the pack's `colormap.png`). Godot's importer
  builds the scenes; the horde renderer bakes each enemy model into a single
  mesh at runtime (`scripts/enemies/enemy_mesh_baker.gd`), the source files are untouched.
- Particle textures: downscaled 512→128 px. Splats: copied at 256 px.
- UI, icons, item previews, fonts: copied unchanged and renamed.

## Generated at runtime (no source file)

- Ground: a `PlaneMesh` with `shaders/ground.gdshader` driven by a `FastNoiseLite` texture.
- XP gems: a small emissive octahedron built in `PickupManager._gem_mesh()`.
- Bullets and the holy-lantern ring: `shaders/aura_disc.gdshader` and capsule meshes.
- UI theme: `resources/configs/ui_theme.tres`, generated by `tools/build_theme.gd`
  from the UI kit and fonts above.

## Swapping in original art

Point the relevant `.tres` (`resources/characters/*.tres`, `resources/enemies/*.tres`,
`resources/weapons/*.tres`, `resources/upgrades/*.tres`, `resources/chapters/*.tres`)
at a new `.glb` / `.png` and re-import. Hero rigs need the seven "mini" bones
(`root`, `leg-left`, `leg-right`, `torso`, `arm-left`, `arm-right`, `head`) and the
animation names set in `CharacterData`; enemy models can be any rigid-part or skinned
model that uses those part names. Re-run `tools/build_assets.py` only if you change
the raw downloads.
