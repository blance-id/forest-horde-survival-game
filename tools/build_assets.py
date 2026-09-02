#!/usr/bin/env python3
"""Build the committed `assets/` tree from raw third-party downloads.

Raw packs live in `assets/_downloads/` (git-ignored, see ASSET_SOURCES.md for
where each one comes from). This script is the single, reproducible step that
turns them into what the game actually loads:

* Kenney "mini" 3D packs -> `assets/models/<pack>/*.glb` + shared colormap
* particles / splats -> downscaled PNGs
* UI pack / icons / audio -> copied with stable names

Run from the project root with a Python that has Pillow, soundfile and numpy
installed (soundfile/numpy only for the zombie WAV -> OGG conversion):

    ~/tools/pyenv/bin/python tools/build_assets.py
"""
from __future__ import annotations

import os
import re
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DL = ROOT / "assets" / "_downloads"
OUT = ROOT / "assets"


def natural_key(path: str) -> list:
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", path)]


def ensure(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def copy_png(src: Path, dst: Path, size: int | None = None) -> None:
    ensure(dst.parent)
    if size is None:
        shutil.copyfile(src, dst)
        return
    im = Image.open(src).convert("RGBA")
    im.thumbnail((size, size), Image.LANCZOS)
    im.save(dst, optimize=True)


# --- 3D models ---------------------------------------------------------------

MODELS = {
    "graveyard": ("3d/graveyard-kit/Models/GLB format", [
        "character-zombie", "character-skeleton", "character-vampire", "character-ghost", "character-keeper",
        "pine", "pine-crooked", "pine-fall", "pine-fall-crooked", "rocks", "rocks-tall", "trunk", "trunk-long",
        "gravestone-round", "gravestone-cross", "gravestone-broken", "gravestone-bevel", "gravestone-wide",
        "cross-wood", "fence", "fence-damaged", "lantern-candle", "lantern-glass", "pumpkin", "pumpkin-carved",
        "pumpkin-tall-carved", "hay-bale", "shovel", "shovel-dirt", "debris", "debris-wood", "coffin-old",
        "candle", "fire-basket",
    ]),
    "forest": ("3d/mini-forest/Models/GLB format", [
        "tree", "tree-high", "rocks-high", "rocks-low", "stones", "patch-grass", "patch-dirt", "plant",
        "fence", "tent", "flag", "target", "character-archer", "weapon-bow", "weapon-arrow",
    ]),
    "characters": ("3d/mini-characters/Models/GLB format", [
        f"character-{sex}-{c}" for sex in ("male", "female") for c in "abcdef"
    ]),
    "dungeon": ("3d/mini-dungeon/Models/GLB format", [
        "coin", "chest", "potion", "key", "character-orc", "character-human", "barrel", "pot",
        "weapon-sword", "weapon-spear", "shield-round", "trap",
    ]),
    "blasters": ("3d/blaster-kit/Models/GLB format", [
        *[f"blaster-{c}" for c in "abcdefghijklmnopqr"],
        "bullet-foam", "bullet-foam-tip", "grenade-a", "grenade-b", "smoke",
    ]),
}


def build_models() -> None:
    for pack, (folder, names) in MODELS.items():
        src = DL / folder
        dst = ensure(OUT / "models" / pack)
        copy_png(src / "Textures/colormap.png", dst / "Textures/colormap.png")
        for name in names:
            glb = src / f"{name}.glb"
            if not glb.exists():
                print(f"  missing {pack}/{name}.glb")
                continue
            shutil.copyfile(glb, dst / f"{name}.glb")
    print("models ok")


# --- Effects -----------------------------------------------------------------

PARTICLES = {
    "circle": "circle_01", "circle_soft": "circle_05", "dirt": "dirt_01", "flame": "flame_01",
    "flare": "flare_01", "light": "light_01", "magic": "magic_01", "muzzle_a": "muzzle_01",
    "muzzle_b": "muzzle_02", "scorch": "scorch_01", "slash": "slash_01", "smoke_a": "smoke_01",
    "smoke_b": "smoke_04", "spark": "spark_01", "spark_b": "spark_04", "star": "star_01",
    "star_soft": "star_07", "symbol": "symbol_01", "trace": "trace_01", "twirl": "twirl_01",
}


def build_effects() -> None:
    src = DL / "particle-pack/PNG (Transparent)"
    for name, source in PARTICLES.items():
        copy_png(src / f"{source}.png", OUT / "effects/particles" / f"{name}.png", size=128)
    for i in range(1, 9):
        copy_png(DL / "splat-pack/PNG/Default (256px)" / f"splat{i:02d}.png", OUT / "effects/splats" / f"splat_{i:02d}.png")
    print("effects ok")


# --- UI ----------------------------------------------------------------------

ICONS = [
    "arrowDown", "arrowLeft", "arrowRight", "arrowUp", "audioOff", "audioOn", "buttonA", "buttonB",
    "buttonX", "buttonY", "checkmark", "coin", "contrast", "cross", "exclamation", "exit", "export",
    "fastForward", "flag", "forward", "gamepad", "gear", "home", "information", "joystick", "joystickLeft",
    "joystickRight", "joystickUp", "larger", "leaderboardsSimple", "locked", "massiveMultiplayer", "medal1",
    "medal2", "menuGrid", "menuList", "minus", "multiplayer", "musicOff", "musicOn", "next", "openStar",
    "pause", "phone", "plus", "power", "previous", "question", "return", "right", "save", "scroll",
    "share1", "shoppingCart", "signal3", "singleplayer", "smaller", "star", "target", "trash", "trophy",
    "unlocked", "video", "warning", "wrench", "zoom",
]


# Item / weapon / upgrade card icons: Kenney's own 64px preview renders of the
# 3D models (same CC0 packs), name -> (pack, preview).
ITEM_ICONS = {
    "blaster": ("blaster-kit", "blaster-k"),
    "scatter": ("blaster-kit", "blaster-d"),
    "clip": ("blaster-kit", "clip-large"),
    "target": ("blaster-kit", "target-small"),
    "shovel": ("graveyard-kit", "shovel"),
    "lantern": ("graveyard-kit", "lantern-glass"),
    "candles": ("graveyard-kit", "candle-multiple"),
    "pumpkin": ("graveyard-kit", "pumpkin-carved"),
    "potion": ("mini-dungeon", "potion"),
    "sword": ("mini-dungeon", "weapon-sword"),
    "shield": ("mini-dungeon", "shield-round"),
    "coin": ("mini-dungeon", "coin"),
    "chest": ("mini-dungeon", "chest"),
    "defibrillator": ("mini-characters", "aid-defibrillator-red"),
    "hero_male_a": ("mini-characters", "character-male-a"),
    "hero_female_a": ("mini-characters", "character-female-a"),
    "zombie": ("graveyard-kit", "character-zombie"),
    "skeleton": ("graveyard-kit", "character-skeleton"),
    "ghost": ("graveyard-kit", "character-ghost"),
    "keeper": ("graveyard-kit", "character-keeper"),
    "vampire": ("graveyard-kit", "character-vampire"),
    "orc": ("mini-dungeon", "character-orc"),
}


def build_ui() -> None:
    src = DL / "ui-pack-adventure/PNG/Double"
    for png in sorted(src.glob("*.png"), key=lambda p: natural_key(p.name)):
        copy_png(png, OUT / "ui/adventure" / png.name)
    icons = DL / "game-icons/PNG/White/2x"
    for name in ICONS:
        png = icons / f"{name}.png"
        if not png.exists():
            print(f"  missing icon {name}")
            continue
        copy_png(png, OUT / "ui/icons" / f"{name}.png")
    for name, (pack, preview) in ITEM_ICONS.items():
        copy_png(DL / "3d" / pack / "Previews" / f"{preview}.png", OUT / "ui/items" / f"{name}.png")
    print("ui ok")


# --- Audio -------------------------------------------------------------------

# name -> (pack folder, source pattern with {n}, count). count == 0: single file
# where {n} matches an optional number; count > 0: {n} is a zero-padded index.
SFX = {
    "bell": ("impact-sounds/Audio", "impactBell_heavy_{n}", 5),
    "boss_roar": ("sci-fi-sounds/Audio", "lowFrequency_explosion_{n}", 2),
    "chest_open": ("rpg-audio/Audio", "bookOpen", 0),
    "chop": ("rpg-audio/Audio", "chop", 0),
    "cloth": ("rpg-audio/Audio", "cloth{n}", 4),
    "explosion": ("sci-fi-sounds/Audio", "explosionCrunch_{n}", 5),
    "footstep": ("impact-sounds/Audio", "footstep_grass_{n}", 5),
    "force_field": ("sci-fi-sounds/Audio", "forceField_{n}", 5),
    "glass_break": ("impact-sounds/Audio", "impactGlass_heavy_{n}", 5),
    "heavy_impact": ("impact-sounds/Audio", "impactPlate_heavy_{n}", 5),
    "hit_player": ("impact-sounds/Audio", "impactPunch_heavy_{n}", 5),
    "hit_zombie": ("impact-sounds/Audio", "impactSoft_heavy_{n}", 5),
    "knife": ("rpg-audio/Audio", "knifeSlice{n}", 2),
    "level_up": ("interface-sounds/Audio", "confirmation_001", 0),
    "metal_impact": ("impact-sounds/Audio", "impactMetal_heavy_{n}", 5),
    "mining": ("impact-sounds/Audio", "impactMining_{n}", 5),
    "pickup_coin": ("rpg-audio/Audio", "handleCoins{n}", 2),
    "pickup_xp": ("interface-sounds/Audio", "glass_{n}", 5),
    "reload": ("rpg-audio/Audio", "metalLatch", 0),
    "shot_blaster": ("sci-fi-sounds/Audio", "laserSmall_{n}", 5),
    "shot_retro": ("sci-fi-sounds/Audio", "laserRetro_{n}", 5),
    "shot_scatter": ("sci-fi-sounds/Audio", "laserLarge_{n}", 5),
    "slime": ("sci-fi-sounds/Audio", "slime_{n}", 2),
    "wood_impact": ("impact-sounds/Audio", "impactWood_medium_{n}", 5),
    "zombie_die": ("impact-sounds/Audio", "impactSoft_medium_{n}", 5),
}
# artisticdude's zombie pack is 24-bit stereo WAV with unnamed clips; these are
# sorted by ear into roles and re-encoded as mono OGG (see _convert_wav).
ZOMBIE_VOICES = {
    "zombie_attack": [5, 6, 10, 11, 13],   # short bites / lunges
    "zombie_growl": [1, 2, 8, 14, 23],     # idle groans
    "zombie_death": [16, 18, 19, 20, 21],  # long dying groans
}
MUSIC = {
    "menu": "jrpg5/Action3 - Preparing For Battle",
    "run": "jrpg5/Action2 - Army Approaching",
    "boss": "jrpg5/Action1 - Encounter With The Witches",
}
UI_SOUNDS = {
    "back": ("interface-sounds/Audio", "back_{n}", 3),
    "bong": ("interface-sounds/Audio", "bong_001", 0),
    "click": ("ui-audio/Audio", "click{n}", 5),
    "close": ("interface-sounds/Audio", "close_{n}", 3),
    "confirm": ("interface-sounds/Audio", "confirmation_{n}", 3),
    "drop": ("interface-sounds/Audio", "drop_{n}", 3),
    "error": ("interface-sounds/Audio", "error_{n}", 7),
    "maximize": ("interface-sounds/Audio", "maximize_{n}", 7),
    "minimize": ("interface-sounds/Audio", "minimize_{n}", 7),
    "open": ("interface-sounds/Audio", "open_{n}", 3),
    "pluck": ("interface-sounds/Audio", "pluck_{n}", 1),
    "question": ("interface-sounds/Audio", "question_{n}", 3),
    "rollover": ("ui-audio/Audio", "rollover{n}", 6),
    "select": ("interface-sounds/Audio", "select_{n}", 7),
    "switch": ("interface-sounds/Audio", "switch_{n}", 7),
    "tick": ("interface-sounds/Audio", "tick_{n}", 2),
}
JINGLES = {
    "win": "Steel jingles/jingles_STEEL16",
    "lose": "Steel jingles/jingles_STEEL08",
    "level_up": "Pizzicato jingles/jingles_PIZZI00",
    "reward": "Steel jingles/jingles_STEEL00",
}


def _numbered_sources(folder: Path, pattern: str, count: int) -> list[Path]:
    """Files matching `pattern` in natural order; the pack's own numbering
    (000..004, 1..5, none) is normalised away by the caller's index."""
    if count == 0:
        rx = re.compile("^" + re.escape(pattern).replace(r"\{n\}", r"\d*") + r"\.ogg$")
        return sorted((p for p in folder.iterdir() if rx.match(p.name)), key=lambda p: natural_key(p.name))
    prefix, suffix = pattern.split("{n}")
    rx = re.compile("^" + re.escape(prefix) + r"(\d+)" + re.escape(suffix) + r"\.ogg$")
    files = [p for p in folder.iterdir() if rx.match(p.name)]
    return sorted(files, key=lambda p: natural_key(p.name))[:count]


def _copy_table(table: dict, out_dir: Path) -> None:
    ensure(out_dir)
    for name, (folder, pattern, count) in table.items():
        files = _numbered_sources(DL / folder, pattern, count)
        if not files:
            print(f"  missing audio {name} ({pattern})")
            continue
        if count == 0:
            shutil.copyfile(files[0], out_dir / f"{name}.ogg")
        else:
            for i, f in enumerate(files, start=1):
                shutil.copyfile(f, out_dir / f"{name}_{i:02d}.ogg")


def _convert_wav(src: Path, dst: Path) -> bool:
    """WAV -> mono, peak-normalised OGG Vorbis. Needs `soundfile` + `numpy`
    (pip install soundfile numpy); returns False when they are missing."""
    try:
        import numpy as np
        import soundfile as sf
    except ImportError:
        return False
    data, rate = sf.read(src, dtype="float32")
    if data.ndim == 2:
        data = data.mean(axis=1)
    peak = float(np.abs(data).max()) or 1.0
    data = data * (0.9 / peak)
    sf.write(dst, data, rate, format="OGG", subtype="VORBIS")
    return True


def build_audio() -> None:
    _copy_table(SFX, OUT / "audio/sfx")
    _copy_table(UI_SOUNDS, OUT / "audio/ui")
    for name, indices in ZOMBIE_VOICES.items():
        for i, idx in enumerate(indices, start=1):
            src = DL / "zombies" / f"zombie-{idx}.wav"
            if not src.exists():
                print(f"  missing audio {name} ({src.name})")
                break
            if not _convert_wav(src, OUT / "audio/sfx" / f"{name}_{i:02d}.ogg"):
                print("  skipping zombie voices: pip install soundfile numpy")
                break
    ensure(OUT / "audio/jingles")
    for name, source in JINGLES.items():
        shutil.copyfile(DL / "music-jingles/Audio" / f"{source}.ogg", OUT / "audio/jingles" / f"{name}.ogg")
    ensure(OUT / "audio/music")
    for name, source in MUSIC.items():
        shutil.copyfile(DL / f"{source}.ogg", OUT / "audio/music" / f"{name}.ogg")
    print("audio ok")


def main() -> None:
    os.chdir(ROOT)
    build_models()
    build_effects()
    build_ui()
    build_audio()


if __name__ == "__main__":
    main()
