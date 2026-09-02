## A run: which arena, which enemies, how the pressure ramps, and the payout.
class_name ChapterData
extends Resource

@export var id: String = "forest"
@export var display_name: String = "Whispering Forest"
## Seconds the player has to survive to win.
@export var duration: float = 300.0

@export_group("Arena")
## Playable square is [-arena_half_size, +arena_half_size] on X and Z.
@export var arena_half_size: float = 22.0
@export var ground_color: Color = Color(0.27, 0.43, 0.2)
@export var ground_color_alt: Color = Color(0.23, 0.38, 0.18)
## Worn dirt patches painted over the grass.
@export var dirt_color: Color = Color(0.5, 0.36, 0.22)
@export var sky_color: Color = Color(0.08, 0.13, 0.09)
@export var fog_color: Color = Color(0.12, 0.2, 0.13)
@export var sun_color: Color = Color(1.0, 0.95, 0.85)
@export var sun_energy: float = 1.0
@export var ambient_color: Color = Color(0.55, 0.65, 0.6)
@export var border_models: Array[PackedScene] = []
@export var decor_models: Array[PackedScene] = []
@export var decor_count: int = 60
## Oversized plants / rocks (2-3x) that give the ground scale and depth.
@export var giant_models: Array[PackedScene] = []
@export var giant_count: int = 0

@export_group("Spawning")
## [{ "enemy": EnemyData, "start": sec, "end": sec, "weight": float }]
@export var waves: Array[Dictionary] = []
## Concurrent enemy cap ramps linearly from start to end over the run.
@export var cap_start: int = 30
@export var cap_end: int = 260
@export var spawn_interval_start: float = 0.7
@export var spawn_interval_end: float = 0.08
## Enemy HP multiplier at the end of the run (linear ramp from 1.0).
@export var hp_scale_end: float = 3.0
## [{ "time": sec, "kind": "ring"|"boss", "enemy": EnemyData, "count": int }]
@export var events: Array[Dictionary] = []

@export_group("Rewards")
@export var coins_win: int = 150
@export var coins_per_minute: int = 10


func spawn_interval(t: float) -> float:
	return lerpf(spawn_interval_start, spawn_interval_end, clampf(t / duration, 0.0, 1.0))


func enemy_cap(t: float) -> int:
	return int(roundf(lerpf(cap_start, cap_end, clampf(t / duration, 0.0, 1.0))))


func hp_scale(t: float) -> float:
	return lerpf(1.0, hp_scale_end, clampf(t / duration, 0.0, 1.0))


## Weighted random enemy type active at time `t`, or null if none.
func pick_enemy(t: float, rng: RandomNumberGenerator) -> EnemyData:
	var total := 0.0
	for w: Dictionary in waves:
		if t >= float(w.get("start", 0.0)) and t < float(w.get("end", duration + 1.0)):
			total += float(w.get("weight", 1.0))
	if total <= 0.0:
		return null
	var r := rng.randf() * total
	for w: Dictionary in waves:
		if t >= float(w.get("start", 0.0)) and t < float(w.get("end", duration + 1.0)):
			r -= float(w.get("weight", 1.0))
			if r <= 0.0:
				return w["enemy"]
	return null


## All enemy types referenced by this chapter (waves + events), each once.
func all_enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for w: Dictionary in waves:
		var e: EnemyData = w.get("enemy")
		if e != null and not out.has(e):
			out.append(e)
	for ev: Dictionary in events:
		var e: EnemyData = ev.get("enemy")
		if e != null and not out.has(e):
			out.append(e)
	return out
