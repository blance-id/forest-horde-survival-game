## A run: which arena, which waves come at you, and the payout.
##
## A chapter is a fixed list of waves rather than a stopwatch. Each wave sends
## a known set of enemies; clearing every one of them brings on the next, and
## the last wave is the boss — killing it ends the run. Nothing is on a timer,
## so a run is a thing you finish rather than a thing you outlast.
class_name ChapterData
extends Resource

@export var id: String = "forest"
@export var display_name: String = "Whispering Forest"

@export_group("Arena")
## Shape of the playable area; see ArenaBounds. Each chapter gets its own so
## the maps do not all read as the same box.
@export var arena_shape: ArenaBounds.Shape = ArenaBounds.Shape.CIRCLE
## Distance from the centre to the furthest edge.
@export var arena_half_size: float = 45.0
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

@export_group("Terrain")
## Rock outcrops standing in the arena. Solid: the hero and the horde both
## walk around them, so the map has corners to fight in.
@export var hill_models: Array[PackedScene] = []
@export var hill_count: int = 12
@export var hill_radius: float = 2.2
@export var hill_scale_min: float = 2.2
@export var hill_scale_max: float = 3.6
## Hills stay this far from the hero's start and this far from each other.
@export var hill_clearance: float = 12.0
@export var hill_spacing: float = 12.0
## Rock bluffs ringing the clearing, mixed in among the border trees.
##
## A true distant range is invisible here: the camera is pitched 55 degrees
## down, so the horizon never enters the frame and anything far enough away to
## read as "distance" is simply off the top of the screen. The range is
## therefore part of the rim — tall enough to loom over the tree wall when you
## reach the edge, gone when you are back in the middle.
@export var mountain_models: Array[PackedScene] = []
@export var mountain_count: int = 26
@export var mountain_distance: float = 28.0
@export var mountain_scale_min: float = 9.0
@export var mountain_scale_max: float = 16.0

@export_group("Forest")
## Choppable trees: stand next to one and the hero swings at it for wood.
@export var tree_models: Array[PackedScene] = []
@export var tree_count: int = 70
@export var tree_hp: float = 4.0
@export var wood_per_tree: int = 3
## What is left standing once a tree comes down.
@export var stump_model: PackedScene
## Bushes conceal whoever stands inside them, hero and horde alike.
@export var bush_model: PackedScene
@export var bush_count: int = 24
@export var bush_radius: float = 2.2

@export_group("Traps")
## The chapter's signature hazard. Hurts enemies and the hero equally.
@export var trap_model: PackedScene
@export var trap_count: int = 0
@export var trap_radius: float = 0.7
@export var trap_damage: float = 12.0
@export var trap_scale: float = 1.0

@export_group("Survivors and vehicles")
## People to free; each hands over a one-shot relic for this run.
@export var survivor_model: PackedScene
## Optional tent behind them so a rescue reads as a place from a distance.
@export var survivor_camp_model: PackedScene
@export var survivor_count: int = 4
## Abandoned walker mechs parked around the map.
@export var vehicle_count: int = 2

@export_group("Waves")
## The run, in order. Each entry:
##   "name":    String shown when the wave starts
##   "groups":  [{ "enemy": EnemyData, "count": int }, ...]
##   "hp_scale": float multiplier on enemy HP for this wave (default 1.0)
##   "interval": float seconds between spawns (default 0.4)
##   "cap":      int most that may be alive at once (default 40)
##   "boss":     true when this wave's kill ends the run
@export var waves: Array[Dictionary] = []
## Breather between one wave being cleared and the next arriving.
@export var wave_break: float = 3.0

@export_group("Rewards")
## Chapter id unlocked by winning this one; empty for the last chapter.
@export var unlocks: String = ""
@export var coins_win: int = 150
@export var coins_per_wave: int = 25

@export_group("Music")
## Loop for the run; the boss loop plays while a boss is alive.
@export var music: AudioStream
@export var boss_music: AudioStream


func wave_count() -> int:
	return waves.size()


func wave_name(index: int) -> String:
	return String(_wave(index).get("name", "WAVE %d" % (index + 1)))


func wave_hp_scale(index: int) -> float:
	return float(_wave(index).get("hp_scale", 1.0))


func wave_interval(index: int) -> float:
	return maxf(0.05, float(_wave(index).get("interval", 0.4)))


func wave_cap(index: int) -> int:
	return maxi(1, int(_wave(index).get("cap", 40)))


func is_boss_wave(index: int) -> bool:
	return bool(_wave(index).get("boss", false))


## Portrait for the wave marker on the run timeline: the first group's enemy.
func wave_icon(index: int) -> Texture2D:
	for g: Dictionary in _wave(index).get("groups", []):
		var e: EnemyData = g.get("enemy")
		if e != null:
			return e.icon
	return null


## Every enemy the wave sends, one entry per body, ready to be shuffled into a
## spawn order.
func wave_roster(index: int) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for g: Dictionary in _wave(index).get("groups", []):
		var e: EnemyData = g.get("enemy")
		if e == null:
			continue
		for i in maxi(1, int(g.get("count", 1))):
			out.append(e)
	return out


## A non-boss enemy from the opening waves, for the menu's background demo.
func demo_enemy(rng: RandomNumberGenerator) -> EnemyData:
	var pool: Array[EnemyData] = []
	for i in mini(3, waves.size()):
		for e in wave_roster(i):
			if not e.is_boss and not pool.has(e):
				pool.append(e)
	if pool.is_empty():
		return null
	return pool[rng.randi() % pool.size()]


## All enemy types this chapter can spawn, each once.
func all_enemies() -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for i in waves.size():
		for e in wave_roster(i):
			if not out.has(e):
				out.append(e)
	return out


func _wave(index: int) -> Dictionary:
	if index < 0 or index >= waves.size():
		return {}
	return waves[index]
