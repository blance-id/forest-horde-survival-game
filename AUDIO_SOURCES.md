# Audio Sources

All audio in `assets/audio/` is third-party and licensed for commercial use.
Files are copied and renamed by `tools/build_assets.py` from the raw packs in
`assets/_downloads/` (git-ignored). Which sound plays for which event is decided
in code/data, never by file name coupling in gameplay logic, so any clip can be swapped.

| Asset | Source | URL | Creator | License | Modification allowed | Commercial use | Attribution |
|---|---|---|---|---|---|---|---|
| Impact SFX (`assets/audio/sfx/hit_zombie_*`, `hit_player_*`, `zombie_die_*`, `footstep_*`, `heavy_impact_*`, `metal_impact_*`, `wood_impact_*`, `mining_*`, `bell_*`, `glass_break_*`) | Kenney | https://kenney.nl/assets/impact-sounds | Kenney (Kenney Vleugels) | CC0 1.0 | Yes | Yes | Not required |
| RPG foley (`assets/audio/sfx/pickup_coin_*`, `chest_open`, `reload`, `knife_*`, `chop`, `cloth_*`) | Kenney | https://kenney.nl/assets/rpg-audio | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Interface SFX (`assets/audio/ui/switch_*`, `confirm_*`, `back_*`, `error_*`, `select_*`, `tick_*`, `open_*`, `close_*`, `drop_*`, `bong`, `question_*`, `pluck_*`, `maximize_*`, `minimize_*`; `assets/audio/sfx/pickup_xp_*`, `level_up`) | Kenney | https://kenney.nl/assets/interface-sounds | Kenney | CC0 1.0 | Yes | Yes | Not required |
| UI clicks (`assets/audio/ui/click_*`, `rollover_*`) | Kenney | https://kenney.nl/assets/ui-audio | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Jingles (`assets/audio/jingles/win.ogg`, `lose.ogg`, `level_up.ogg`, `reward.ogg`) | Kenney | https://kenney.nl/assets/music-jingles | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Weapon / boss SFX (`assets/audio/sfx/shot_blaster_*` = laserSmall, `shot_scatter_*` = laserLarge, `shot_retro_*` = laserRetro, `force_field_*`, `explosion_*` = explosionCrunch, `boss_roar_*` = lowFrequency_explosion, `slime_*`) | Kenney | https://kenney.nl/assets/sci-fi-sounds | Kenney | CC0 1.0 | Yes | Yes | Not required |
| Zombie vocals (`assets/audio/sfx/zombie_attack_*`, `zombie_growl_*`, `zombie_death_*`) | OpenGameArt "Zombies Sound Pack" | https://opengameart.org/content/zombies-sound-pack | artisticdude | CC0 1.0 | Yes | Yes | Not required |
| Music (`assets/audio/music/menu.ogg` = "Preparing For Battle", `run.ogg` = "Army Approaching", `boss.ogg` = "Encounter With The Witches") | OpenGameArt "JRPG Pack 5 Action" | https://opengameart.org/content/jrpg-pack-5-action | Juhani Junkala (SubspaceAudio) | CC0 1.0 | Yes | Yes | Not required (credited anyway in-game) |

## Modifications made

- Kenney clips and the music are copied and renamed only.
- Zombie vocals: the pack's unnamed 24-bit stereo WAVs (`zombie-N.wav`) were
  sorted by ear into attack / growl / death roles (`ZOMBIE_VOICES` in
  `tools/build_assets.py`), mixed to mono, peak-normalised to −1 dB and encoded
  as OGG Vorbis.
- Pitch/volume variation is applied at runtime by `AudioManager`; music
  `.ogg.import` files have `loop=true`.

## Sound map

Which clip answers which event lives in code and data, never in file names:

| Event | Sound |
|---|---|
| Weapon shot / aura pulse | `WeaponData.fire_sound` (blaster → `shot_blaster`, scatter → `shot_scatter`, lantern → `force_field`, orbit → silent) |
| Weapon damages an enemy | `WeaponData.hit_sound` (`hit_zombie`; shovel orbit → `knife`) |
| Enemy dies | `zombie_death` + `zombie_die` squish; boss adds `explosion` |
| Enemy bites the hero | `hit_player` + `zombie_attack` |
| Idle horde | `zombie_growl` from a random nearby zombie every ~1 s, volume by distance |
| Hero walking | `footstep` every 0.32 s |
| Boss spawn / kill | `bell` + `boss_roar` + boss music / `reward` jingle + run music |
| Menu / run / boss | `music/menu`, `ChapterData.music`, `ChapterData.boss_music`; ducked −9 dB under pause and level-up |
