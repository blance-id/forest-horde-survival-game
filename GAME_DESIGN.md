# Forest Zombie Survival — Game Design

Working title: **Forest Zombie Survival**
Tagline (ad-style): *"Only 1% survive the forest. Can you?"*
Platform: Android / iOS (portrait). Desktop used for development only.
Engine: Godot 4.7.2 (GDScript, GL Compatibility renderer).

---

## 1. High Concept

A **horde survivor** set in a cursed pine forest, rendered in chunky low-poly
3D and watched from a close, angled perspective camera. You drag one finger to move; your
survivor auto-aims and auto-fires. Zombies pour in from every direction in
ever-growing numbers. Every kill drops XP; every level-up offers three loud,
ad-style upgrade cards ("MORE DAKKA!", "PEW PEW PEW!", "NEVER DIE!").
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
| Success condition | Survive until the chapter timer expires; the boss arrives 60 s before the end |
| Retry loop | Result screen → *Retry* (same chapter, instant) or *Shop* → *Play* |
| Pause | Pause button + automatic pause on app backgrounding |

Coins are awarded on both win and loss (scaled by time survived and kills), so
every run progresses the meta. A loss must never feel like wasted time.

---

## 5. Controls (mobile-first)

**Floating drag stick**: touch anywhere on the play area; the touch point
becomes the stick centre; drag direction = movement direction; drag distance
= speed. Release = stop. A translucent ring + knob fades in where the finger
landed and fades out on release.

Tuning (`TouchJoystick`, design pixels on the 720-wide canvas):

- Ring radius 96 px, dead zone 10 %.
- Response curve: 35 % speed right past the dead zone, full speed at 70 % of
  the radius — a thumb barely has to move to sprint.
- **Drag-to-recentre**: when the finger passes the ring the base is dragged
  along behind it, so reversing direction only needs the thumb to cross the
  ring again, never a lift.
- Any tree pause (level-up, pause menu, app to background) drops the touch so
  the hero never keeps walking on a stale stick after the panel closes.
- First-ever run shows a pulsing "DRAG ANYWHERE TO MOVE" hint until the first
  touch (hidden for players with a finished run in their profile).

Other:

- No aim input: the hero auto-targets the nearest enemy (weapon-specific
  targeting rules live in `WeaponData`).
- UI buttons (pause, 80 px) live at the top, padded below the notch via
  `SafeArea`, and take the touch before the stick does.
- Haptics: short pulses on taking damage (40 ms), level-up (18 ms), boss spawn
  / boss kill / death (90 ms), rate-limited to one per 90 ms and switchable in
  Settings → Vibration.
- Keyboard WASD / arrows are supported for desktop development only.

---

## 6. Hero

One hero at launch, data-driven so more can be added:

`CharacterData` — display name, rigged model (`.glb`), weapon model + the bone
it mounts on (offset / rotation / scale), muzzle offset, animation names
(idle / move / die), base HP, move speed, pickup radius, armor, starting weapon.

Launch hero: **The Ranger** — the last forester. Starts with the *Blaster*.
The rig is a Kenney "mini" character: seven bones, upper body plays the
weapon-holding pose while the legs play the sprint cycle (AnimationTree blend).

---

## 7. Weapons (in-run, auto-fire)

All weapons are `WeaponData` resources: kind (**projectile**, **orbit**,
**aura**), damage, cooldown, projectile count, spread, speed, pierce, range,
area, knockback, projectile model / tint, icon, card text and a per-level
table of stat deltas. Adding a weapon of an existing kind = adding a resource;
a new kind = one branch in `WeaponSystem`.

Launch set:

| Weapon | Kind | Behaviour | Ad card flavour |
|---|---|---|---|
| Blaster | projectile | Fast shots at the nearest zombie; more bullets and pierce per level | "MORE DAKKA!" |
| Scatter Blaster | projectile | Wide fan of pellets, short range, strong knockback | "NEW WEAPON!" |
| Shovel Storm | orbit | 1–6 shovels spin around the hero, continuous damage | "NEW WEAPON!" |
| Holy Lantern | aura | Ring of light on the ground pulses damage on everything inside | "NEW WEAPON!" |

Planned for later chapters: a lobbed fire pot (burning pool) and a chain
lightning strike. Max 4 weapons per run; each weapon has 6 levels.

---

## 8. Passives (in-run)

`UpgradeData` resources with a stat key and a value per level, applied through
`RunStats`:

| Passive | Card | Effect per level |
|---|---|---|
| Vitality | "BEEFY!" | +20% max HP |
| Power | "HIT HARDER!" | +15% damage |
| Rapid Fire | "PEW PEW PEW!" | +12% attack speed |
| Swift Boots | "ZOOM!" | +10% move speed |
| Magnet | "GIMME!" | larger pickup radius |
| Armor | "TANKY!" | −1 damage per hit |
| Regeneration | "NEVER DIE!" | +0.5 HP/s |
| Wisdom | "BIG BRAIN!" | +15% XP |

5 levels each. Level-ups roll 3 cards from every weapon and passive that is not
maxed; a held weapon is weighted slightly higher than a new one so builds
deepen instead of sprawling.

---

## 9. Enemies

`EnemyData` resources: model (`.glb`), tint, scale, HP, speed, contact damage,
attack cooldown, body radius, knockback resistance, XP, coin chance, boss flag,
and the procedural walk-cycle parameters (stride rate, leg / arm swing, bob,
lean) used by the horde shader.

Every enemy walks at the hero and deals contact damage; the mix, count and HP
scale are what change. Chapter 1 roster:

| Enemy | Model | Role | Stats |
|---|---|---|---|
| Walker | zombie | Filler | 12 HP, slow, 8 dmg |
| Runner | skeleton | Pressure | 7 HP, fast, comes in rings |
| Wisp | ghost | Swarm | 15 HP, quick, low damage |
| Brute | zombie ×1.55 | Wall | 70 HP, slow, 18 dmg, knockback-resistant |
| Gravekeeper | keeper ×1.6 | Elite | 160 HP, 14 dmg, late-run only |
| Count Nosferatu | vampire ×2.4 | Boss | 900 HP, 26 dmg, spawns at 5:00 with a health bar |

Planned for later chapters: a ranged spitter and unique boss behaviours
(charge, summon).

---

## 10. Difficulty Model (spawn director)

Difficulty is **not** "multiply HP by level". The director reads a
`ChapterData` curve and changes, over run time:

- concurrent enemy cap (30 → 240)
- spawn interval (0.7 s → 0.08 s)
- enemy mix weights with per-enemy start times (walkers → runners → wisps →
  brutes → gravekeepers)
- scripted events at timestamps: rings of runners / walkers / wisps / brutes,
  the *Boss* at 5:00, a final runner ring while the boss is alive
- enemy HP multiplier that grows gently (×1.0 → ×3.0 over a run)

Enemies that fall more than 20 units behind the hero are silently moved back
onto the spawn ring, so the pressure never thins out no matter where the
player runs.

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

- **Reference bar** — Funguys Swarm: a close angled camera with real
  perspective, a painted saturated world with oversized foliage and long soft
  shadows, colourful chunky enemies, and bloom-heavy weapon VFX that fill the
  screen. Portrait instead of landscape, but that is the density and polish to
  hit.
- **Low-poly 3D** — Kenney "mini" characters and graveyard / forest kits
  (flat-shaded, one colormap per kit). The ground is a shader: two grass tones
  in soft patches, stretched fine noise as brush-stroke grass, and sparse worn
  dirt trails with a trampled rim. A wall of pines closes the arena; ~130
  gravestones, pumpkins, stones and grass tufts plus ~18 oversized trees and
  plants (1.3–1.8×) are scattered inside for scale and depth.
- **Camera** — perspective, pitched 55° down, 9.5 units from the hero, fov 40
  so props lean away at the frame edges; `KEEP_WIDTH` keeps the visible width
  (~7 units, the hero is ~1/8 of the screen width) identical on every phone
  aspect ratio; follows the hero with a soft lag and shakes on hits.
- **Lighting** — one warm low sun (40° elevation) so every prop and enemy
  throws a long soft shadow, dim green ambient, distance fog fading into a dark
  sky so the horde appears out of the gloom. Environment glow is on with two
  blur levels: anything over-bright (bullets, gems, auras, later particles)
  blooms.
- **Readability first** — enemies flash white when hit, the hero flashes red,
  XP gems glow, bullets are over-bright capsules, the hero has a tiny HP bar
  at its feet. Enemy tints keep the roster colourful: bone-yellow skeletons,
  cyan ghosts, green zombies.
- Bright, chunky, readable — a saturated cartoon forest, not gritty horror.
- Typography: heavy display font (Lilita One) for numbers/headlines, clean sans
  (Nunito) for body.
- Ad-style UI motifs: giant rotating "x2 / +50 / MAX" callouts, red banners,
  gold coins that rain into the counter, "NEW RECORD!" stamps.
- Everything that scales power also scales feedback: bigger numbers, bigger
  shake, denser particles.

---

## 13. Vertical Slice (minimum playable)

1. Main menu → Play.
2. Forest arena, hero with Blaster, drag-to-move.
3. Five enemy types spawn on a rising curve for 6 minutes, boss at 5:00.
4. XP gems, level-ups with 3 cards (4 weapons + 8 passives).
5. HP bar, timer, kill counter, level bar, boss bar.
6. Death → result screen → retry / menu.
7. Coins persist; one meta upgrade (Max HP) purchasable from the menu.

Items 2–6 are implemented; 1 and 7 are the next two phases.

Everything after the slice widens this loop — it never replaces it.

---

## 14. Out of Scope (for now)

Monetisation, ads, cloud save, leaderboards, multiplayer, localisation beyond
English, achievements. The architecture must not block them, but nothing is
built for them.
