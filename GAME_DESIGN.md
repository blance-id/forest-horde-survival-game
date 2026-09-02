# Forest Zombie Survival — Game Design

Working title: **Forest Zombie Survival**
Tagline (ad-style): *"Only 1% survive the forest. Can you?"*
Platform: Android / iOS (portrait). Desktop used for development only.
Engine: Godot 4.7.2 (GDScript, GL Compatibility renderer).

---

## 1. High Concept

A top-down **horde survivor** set in a cursed pine forest. You drag one finger
to move; your survivor auto-aims and auto-fires. Zombies pour in from every
direction in ever-growing numbers. Every kill drops XP; every level-up offers
three loud, ad-style upgrade cards ("DAMAGE x2", "+3 ARROWS", "SAW BLADES!").
Survive the chapter timer, kill the boss, bank your coins, buy permanent
upgrades, go again.

**What the player does:** move, dodge, collect, choose upgrades, survive.

**Why it is fun:** the power curve. You start barely able to kill one walker
and, four minutes later, you are a screen-clearing storm of bullets, orbiting
blades and lightning. The horde grows to match, so tension never drops.

**What makes it different:** the game leans fully into the *exaggerated
mobile-ad* aesthetic — huge numbers, screaming red "HORDE INCOMING" banners,
"WRONG CHOICE?" upgrade cards, a hero that becomes ridiculously overpowered —
but every one of those promises is real gameplay, not bait.

**Why keep playing:** short runs (5–8 min), a visible meta-upgrade tree that
makes the next run measurably better, chapters that unlock new enemy types and
bosses, and the "I almost had it" retry loop.

---

## 2. Core Gameplay Loop

```
MAIN MENU
   ↓  (Play → pick chapter)
RUN STARTS  — weak hero, single weapon, empty forest
   ↓
HORDE GROWS — spawn director ramps count / speed / enemy mix on a timer
   ↓
KILL → XP GEMS → LEVEL UP → PICK 1 OF 3 UPGRADE CARDS
   ↓                                   (repeat many times per run)
MID-RUN EVENTS — ring of runners, brute wave, elite, treasure chest
   ↓
BOSS at chapter timer end
   ↓
RESULT SCREEN — kills, time survived, coins earned (win or lose)
   ↓
META SHOP — spend coins on permanent stats, unlock next chapter
   ↓
HARDER CHAPTER / BETTER RUN → REPEAT
```

Within a single run the micro-loop is:

```
Move ↔ Dodge ↔ Collect gems ↔ Level up ↔ Get stronger ↔ Horde gets bigger
```

---

## 3. Player Fantasy

- **Powerful** — "I am mowing down 300 zombies without stopping."
- **Greedy** — "One more gem... one more level... just reach the chest."
- **Clever** — "Blades + magnet + attack speed this run, that's the build."
- **Absurd** — damage numbers in the thousands, boss health bars that fill the
  screen, upgrade cards that scream at you.
- **"I can do better than that"** — died at 4:51 with the boss at 10% HP.

The ad promise is *"you vs. the entire forest"*. The game delivers it.

---

## 4. Session Design

| Item | Value |
|---|---|
| Expected session | 5–15 minutes (1–2 runs) |
| Chapter 1 run length | 5:00 + boss (~30 s) |
| Later chapters | 6:00 – 8:00 + boss |
| Fail condition | Hero HP reaches 0 (one optional revive from meta upgrade) |
| Success condition | Chapter timer expires **and** boss is killed |
| Retry loop | Result screen → *Retry* (same chapter, instant) or *Shop* → *Play* |
| Pause | Pause button + automatic pause on app backgrounding |

Coins are awarded on both win and loss (scaled by time survived and kills), so
every run progresses the meta. A loss must never feel like wasted time.

---

## 5. Controls (mobile-first)

**Floating drag stick**: touch anywhere on the play area; the touch point
becomes the stick centre; drag direction = movement direction; drag distance
(with a small dead zone and a clamp radius) = speed. Release = stop.
A subtle stick graphic appears where the finger landed so the player gets
feedback, and disappears on release.

- No aim input: the hero auto-targets the nearest enemy (weapon-specific
  targeting rules live in `WeaponData`).
- UI buttons (pause) live in the safe area at the top and are excluded from the
  movement touch area.
- Keyboard WASD / arrows are supported for desktop development only.

---

## 6. Hero

One hero at launch, data-driven so more can be added:

`CharacterData` — display name, sprite/animation set, base HP, move speed,
starting weapon, pickup radius, base damage multiplier.

Launch hero: **The Ranger** — the last forester. Starts with the *Hunting Rifle*.

---

## 7. Weapons (in-run, auto-fire)

All weapons are `WeaponData` resources: damage, cooldown, projectile count,
projectile scene, speed, pierce, area, knockback, targeting mode, level table
(1–5) and sprite/VFX references. Adding a weapon = adding a resource + at most
one small behaviour script.

Launch set:

| Weapon | Behaviour | Ad card flavour |
|---|---|---|
| Hunting Rifle | Fast single shots at nearest enemy, pierce grows with level | "MORE BULLETS" |
| Shotgun | Fan of pellets, short range, strong knockback | "BOOM x5" |
| Saw Blades | 1–5 blades orbit the hero, continuous damage | "SAW BLADES!!!" |
| Molotov | Lobbed onto densest cluster, leaves burning pool | "BURN THEM ALL" |
| Lightning | Random strikes on enemies near the hero, chain at high level | "CALL THE STORM" |
| Boomerang | Thrown out and back, pierces everything | "IT COMES BACK" |

Max 4 weapons per run. Each weapon has 5 levels. Reaching level 5 on a weapon
shows a special "MAXED" card.

---

## 8. Passives (in-run)

`UpgradeData` resources with a stat key and per-level values:

Max HP, Damage %, Attack speed %, Move speed %, Pickup radius, Projectile +1,
Armor, HP regen, XP gain %, Coin gain %.

Max 4 passives per run, 5 levels each.

---

## 9. Enemies

`EnemyData` resources: sprite set, HP, speed, damage, size, XP value, coin
chance, behaviour type, tint, scale, knockback resistance.

| Enemy | Role | Behaviour |
|---|---|---|
| Walker | Filler | Slow, straight at the hero |
| Runner | Pressure | Fast, low HP, comes in rings |
| Brute | Wall | Slow, huge HP, knockback-immune, pushes through |
| Spitter | Ranged | Keeps distance, lobs acid |
| Elite | Mini-boss | Any type, 10× HP, glowing, drops treasure chest |
| Boss | Chapter end | Unique data per chapter: charge, summon, acid rain |

---

## 10. Difficulty Model (spawn director)

Difficulty is **not** "multiply HP by level". The director reads a
`ChapterData` curve and changes, over run time:

- concurrent enemy cap (30 → 350)
- spawn interval
- enemy mix weights (walkers → runners → brutes → spitters)
- scripted events at timestamps: *Ring of Runners*, *Brute March*,
  *Spitter Line*, *Elite*, *Treasure Chest*, *Boss*
- enemy stat multipliers that grow gently (HP ×1.0 → ×2.5 over a run)

Chapters raise the baseline, unlock enemy types, and change the boss. Later
chapters also change the environment (night, fog, swamp tint).

---

## 11. Progression & Economy

**Currencies**
- **Coins** — earned in runs (kills, chests, result bonus). Spent in the meta
  shop. Never purchasable (no monetisation in this prototype).
- **XP** — in-run only, resets each run.

**Meta upgrades** (`MetaUpgradeData`, permanent, cost curve per level):
Max HP, Damage, Attack Speed, Move Speed, Pickup Radius, Armor, Coin Gain,
XP Gain, Starting Level, Revive (1 level).

**Unlocks**
- Chapters unlock sequentially by winning the previous one.
- Weapons/passives are all available from the start; later chapters may
  introduce new ones via `ChapterData.unlocks`.

**Player power** = base hero × meta upgrades × in-run build.
Target feeling: a fresh player dies at ~3:00 in Chapter 1; after 3–4 runs of
meta spending they beat it; Chapter 2 pushes them back to ~4:00.

---

## 12. Presentation & Tone

- Bright, chunky, readable — a saturated cartoon forest, not gritty horror.
- Typography: heavy display font for numbers/headlines, clean sans for body.
- Ad-style UI motifs: giant rotating "x2 / +50 / MAX" callouts, red banners,
  gold coins that rain into the counter, "NEW RECORD!" stamps.
- Everything that scales power also scales feedback: bigger numbers, bigger
  shake, denser particles.

---

## 13. Vertical Slice (minimum playable)

1. Main menu → Play.
2. Forest arena, hero with Hunting Rifle, drag-to-move.
3. Walkers + Runners spawn on a rising curve for 3 minutes, boss at the end.
4. XP gems, level-ups with 3 cards (Rifle, Saw Blades, Shotgun + 3 passives).
5. HP bar, timer, kill counter, level bar.
6. Death → result screen → retry / menu.
7. Coins persist; one meta upgrade (Max HP) purchasable from the menu.

Everything after the slice widens this loop — it never replaces it.

---

## 14. Out of Scope (for now)

Monetisation, ads, cloud save, leaderboards, multiplayer, localisation beyond
English, achievements. The architecture must not block them, but nothing is
built for them.
