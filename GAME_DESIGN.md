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
Clear the chapter's waves, kill the boss, bank your coins, buy permanent
upgrades, go again.

**What the player does:** move, dodge, collect, choose upgrades, clear the wave.

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
RESULT SCREEN — kills, clear time, coins earned (win or lose)
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
| Success condition | Clear every wave; the last wave is the boss, and killing it ends the run |
| Retry loop | Result screen → *Retry* (same chapter, instant) or *Shop* → *Play* |
| Pause | Pause button + automatic pause on app backgrounding |

Coins are awarded on both win and loss (scaled by waves cleared and kills), so
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
- **Low-poly 3D** — Kenney "mini" characters for the cast, the Nature Kit for
  the forest itself (detailed trees, bushes, stumps, logs, flowers, mushrooms,
  and the rock and cliff sets used for hills and the mountain rim).
- **The floor is plain grass, done properly.** It is the surface on screen the
  most, so it is a real tiling grass texture rather than noise — sampled twice
  at different scales and cross-faded, so it never visibly repeats across a
  90-unit map. Clean and flat, with broad colour drift and worn dirt trails
  over the top. Not 3D blades: those were tried, and they read as clutter.
- **The edge of the map is a wall of mist** standing on the boundary, and the
  ground washes out to fog behind it, so there is never a question about where
  the world stops.
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
- **Game feel** — every hit is answered: a glow pop plus sparks in the weapon's
  colour, a cream damage number that pops and floats; kills get a green
  smoke puff, hot embers and a dark splat that stays on the grass (~9 s) so a
  long fight leaves a visible trail of carnage; boss deaths add a white shock
  ring, a star burst and a 0.16 s freeze. Muzzle flashes on every shot, aura
  pulses ripple across the ground, pickups sparkle in their colour. Taking
  damage: red hero burst, red "50" number, camera shake, haptic tap and a
  screen-edge red vignette that pulses continuously under 30 % HP. Death is a
  0.9 s slow-motion. Level-ups fire a gold star ring around the hero.
- **Effects** — three heavier languages on top of the hit sparks. Explosions
  are chaotic: a white core, a fireball, embers skittering out flat, and a
  burn mark left on the grass. Magic is the opposite, ordered and cool —
  glyphs turning as they rise out of a bloom. Fire actually burns: the
  braziers in Hollow Thicket are lit, and springing one is a detonation rather
  than a clang. Bombs explode, holy and angelic weapons cast, everything else
  throws sparks — and which is which is a field on the weapon, not a rule
  buried in code.
- **Sound** — each weapon has its own voice (blaster zap, scatter boom, lantern
  hum, knife slashes for the shovel) and a hit clip; zombies groan when they
  bite, growl at random when close, and shriek on death. A driving JRPG battle
  loop runs under the whole run, a heavier track takes over while the boss is
  alive (announced by a roar), and the music ducks under pause and level-up
  cards so the choice feels like a breath. Everything is CC0 (Kenney, Juhani
  Junkala, artisticdude) and credited in Settings.
- **HUD** — one top block: an XP bar with a hexagon level badge, then a heart
  + HP bar reading "72 / 100" beside kills, coins and pause, then the run
  timeline (a filling track with a portrait for every scripted horde and a red
  hexagon for the boss) with the countdown over it, then the build bar of
  hexagon slots showing the four weapons and every passive with its level.
  Coins arc from where they drop into the counter, kill chains pop a
  "MEGA COMBO / RAMPAGE!" callout, and the result card counts the reward up
  before stamping "NEW RECORD!".
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
3. Eight waves of rising difficulty; the last one is the boss.
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

---

## 15. v2 — Playtest Overhaul

First smoke test verdict: playable but *not fun*. Too flat (a square arena and
one verb: shoot), too hard (contact damage with no telegraph), too opaque
(fancy card names, no idea what a build actually does). v2 fixes that by
adding a second verb — **the forest is a resource, not a backdrop** — and by
making every number legible.

### 15.1 The new loop

Chop trees for **wood** → spend wood on **towers** → feed towers **ammo**
looted from elite enemies → the firing tower makes *noise*, which pulls the
horde off the player and onto it. A silent tower is invisible to the horde, so
placing and feeding one is a deliberate, reversible decision, not a fire and
forget turret. Bushes hide the player (and the horde). Traps hurt both sides.

### 15.2 Work list

Waves are shipped in order; each keeps the game runnable.

**Wave 1 — fairness and legibility**
- Camera 10 % further out.
- Run is 5 minutes, not 6.
- XP is tiered per enemy: ×1 ×2 ×5 ×10 ×20 ×50 ×100 instead of a flat 1.
- Every enemy has a health bar.
- Hero HP bar gradients green → yellow → red with the ratio.
- Enemies telegraph: wind-up, animated strike, then damage — no more damage
  on touch. Zombie 0.3 s bite, wolf 0.25 s lunge, forest mage 2.0 s cast plus
  a 3 s slow-flying bolt.
- Plain UX writing: "Sprint · Lv 2 · +10% Move Speed", never "ZOOM!".

**Wave 2 — a world worth exploring**
- Much larger arena, a different shape and a signature trap per chapter.
- Choppable trees drop wood.
- Bushes conceal the hero and the horde; killing inside one blows your cover.
- Traps that damage both sides.
- Minimap.

**Wave 3 — towers**
- Build from wood, feed ammo dropped by elites (×5 and up).
- Only fires while the hero is in range; firing makes it a target.

Waves 1–3 are in. What that changed in practice: a run is now five minutes on
a round clearing four times the old size, enemies telegraph every hit, the
horde is worth ×1 to ×100 XP by type, and the player spends their time
chopping wood, ducking into bushes, kiting the horde through spike traps and
deciding when a gun nest is worth the noise.

**Wave 4 — combat depth**
- Physical / magic / true damage, each with its own colour.
- Attack speed and burst damage as first-class stats.
- The two ranged weapons mount left and right of the hero, not centred.
- Beasts and fairy-tale monsters: wolf, great snake, forest mage.
- Swap a maxed weapon for another one at the same level.

**Wave 5 — meta**
- Boss entrance cutscene: everything freezes, the boss walks in and laughs.
- Bosses drop a one-shot item or skill for the *next* run; it sits in the Bag
  until used and is lost on death.
- Revive for coins at 100 / 200 / 400 / 800 …
- Home store: buy consumables into the inventory, carry them in the Travel Bag.
- Build panel listing every buff taken and the damage it adds up to.

Waves 4 and 5 are in as well: physical / magic / true damage with matching
colours and per-enemy resistances (bullets barely scratch a wisp — bring the
lantern), guns on both shoulders, swapping a maxed weapon for a new one at the
same level, a build sheet on the pause screen, a boss entrance where the world
stops and the Count laughs his way in, revives at 100/200/400/800 coins, and a
store whose purchases ride into the run in a three-slot travel bag you lose if
you die.

**Wave 6 — presentation** *(ground, foliage and quality are in)*
- ~~Real ground and foliage~~ — done: Nature Kit trees, bushes, stumps and
  logs over a procedural grass shader with wandering blade direction.
- ~~A "Max" quality setting~~ — done: LOW / NORMAL / MAX drives ground detail,
  shadows, foliage density, bloom levels and MSAA.
- Metal Slug touches: driveable vehicles with their own ammo, rescuable
  survivors that hand over an item. **Not started.**

### 15.3 Waves

The run is no longer a five-minute stopwatch. A chapter is a fixed list of
waves — eight in Whispering Forest, seven in Hollow Thicket — and each one
only ends when every body it sent is down. The last wave is the boss, and
killing it ends the run then and there.

That changes what a run *is*: something you finish rather than something you
outlast, with a visible "WAVE 5 / 8" and a count of what is left instead of a
countdown. Chapter records became fastest clear, and dying no longer sets one.

### 15.4 Classes and weight

Four classes, each with the same five weapon shapes in its own flavour:

| Class | Sidearm | Rifle | Spinner | Shield | Lantern |
|---|---|---|---|---|---|
| Army Ranger | Service Pistol | Assault Rifle | Shovel Storm | Onion Shield | Holy Onion Lantern |
| Army Bomber | Bazooka | Grenade Rifle | Knife Bomb Spin | Smoke Gas Shield | Holy Bomb Lantern |
| Army Angel | Angelic Arrow | Arrow Rifle | Magic Angel Orb | Angelic Shield | Holy Angelic Lantern |
| Cyborg | Laser Beam | Sword Laser | Cyborg Shuriken | Electric Shield | Holy Electric Lantern |

The hero does not carry all five. Every weapon has a **weight** and every class
a **carry capacity**: the Bomber's bazooka is 8 kg against a capacity of 12,
so it goes almost alone, while a pistol and a spinner together are 7 and leave
room. Weight also slows you down — a full load costs about a third of your
move speed — so the question is never "what is strongest" but "what can I
afford to carry, and how slow am I willing to be".

Shields are new: a dome that shoves the horde back off you and soaks a flat
amount of every hit while you hold it.

### 15.5 Terrain, treasure and boss fights

- **Terrain.** The nature kit is now mined properly — around a hundred models
  instead of forty-five, with rock, stone and cliff sets. Rock outcrops stand
  in the arena as solid ground that the hero *and* the horde walk around, so
  an open field has corners to fight in, and a rim of bluffs rings the
  clearing among the border pines. The palettes fog to a light haze rather
  than near-black, which is what lets distance read at all.
- **Treasure.** Chests sit out towards the rim holding XP and gold. Opening
  one takes a moment standing still and bursts its contents onto the grass, so
  the reward is a scramble rather than a number going up.
- **Bosses.** Each has its own kit. Count Nosferatu summons his brood, sprays
  bolts and blinks across the arena; The Alpha leaps constantly, howls the
  pack into a sprint and calls more wolves. A leap crouches, arcs through the
  air and lands with a shock that throws back and hurts everything nearby —
  hero and horde — and shakes the whole frame. Both are far tougher than
  before, with real resistances.

### 15.6 Everything shipped

Wave 6 closed out with the three items that were left:

- **Beasts.** Dire wolves hunt in fast packs from the first minute; great
  serpents lunge with a long reach and shrug off a quarter of physical damage.
  Neither exists in any CC0 kit, so both are generated from boxes in the same
  palette and driven by the same rig as everything else.
- **Metal Slug touches.** Abandoned walker mechs are parked around the map:
  step in and its twin cannons do the shooting while its hull takes the hits,
  until the shells or the armour run out. Survivors can be freed by standing
  with them for a couple of seconds, and they hand over a relic you can use on
  the spot.
- **A second chapter.** Hollow Thicket: a clover-shaped map with chokepoints
  between four lobes, lit cold and blue, ringed with braziers that burn
  anything that walks through them, and stocked with wolves, hexers and
  serpents under the Alpha.

### 15.7 Still open

Nothing from the playtest list is outstanding. The next pass is balance:
Hollow Thicket's later waves are currently a wall, and the mech is strong
enough that finding one early decides the run.
