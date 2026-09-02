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

## Modifications made

None — clips are copied and renamed. Pitch/volume variation is applied at runtime by `AudioManager`.

## Still to source

Music loops (menu + gameplay) and gunshot / zombie vocal SFX are not in the
Kenney packs; they will be added with their own rows here before the audio phase closes.
