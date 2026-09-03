## Static hazards scattered through the map. A trap does not care who stepped
## on it — the horde walks into them just as often as the player does, which
## turns "run past the spikes" into a real tactic instead of a punishment.
##
## Chapters whose trap is a fire (`trap_burns`) also report which ones are
## close enough to be worth burning, so the run can keep flames alive on them
## without paying for forty fires nobody can see.
class_name Traps
extends Node3D

signal triggered(position: Vector3, hit_player: bool)

const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))
## Seconds before a sprung trap can bite again.
const REARM := 1.6
## Traps stay this far from the middle, where the hero starts.
const SPAWN_CLEARANCE := 8.0


class Trap:
	var pos: Vector2
	var radius: float
	var damage: float
	var cooldown := 0.0


var traps: Array[Trap] = []
## Set from the chapter: these traps are fires and should be given flames.
var burns := false
var flame_height := 0.55

var _mm: MultiMesh
var _query: Array = []
var _rng := RandomNumberGenerator.new()


func build(chapter: ChapterData, seed_value: int) -> void:
	if chapter.trap_model == null or chapter.trap_count <= 0:
		return
	_rng.seed = seed_value
	burns = chapter.trap_burns
	flame_height = chapter.trap_flame_height
	var bounds := ArenaBounds.from_chapter(chapter)
	var node: Node = chapter.trap_model.instantiate()
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.push_front(node)
	if meshes.is_empty():
		node.free()
		return
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = (meshes[0] as MeshInstance3D).mesh
	_mm.instance_count = chapter.trap_count
	for i in chapter.trap_count:
		var t := Trap.new()
		# Never on the hero's spawn: a trap under your feet at second zero is
		# not a hazard, it is a bug.
		for attempt in 12:
			t.pos = bounds.random_point(_rng, 2.0)
			if t.pos.length() > SPAWN_CLEARANCE:
				break
		t.radius = chapter.trap_radius
		t.damage = chapter.trap_damage
		traps.append(t)
		_mm.set_instance_transform(i, Transform3D(
			Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * chapter.trap_scale),
			Vector3(t.pos.x, 0.02, t.pos.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Traps"
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var extent := bounds.half + 2.0
	mmi.custom_aabb = AABB(Vector3(-extent, -1, -extent), Vector3(extent * 2.0, 3, extent * 2.0))
	add_child(mmi)
	node.free()


## Traps close enough to the hero to be worth drawing flames on. Anything
## further away is off screen, and forty fires costs forty times as much as one.
func burning_near(hero: Vector2, radius: float, out: Array[Vector3]) -> void:
	if not burns:
		return
	for t in traps:
		if hero.distance_squared_to(t.pos) <= radius * radius:
			out.append(Vector3(t.pos.x, flame_height, t.pos.y))


func tick(delta: float, player: Player, enemies: EnemyManager) -> void:
	if traps.is_empty():
		return
	var hero := Vector2(player.position.x, player.position.z)
	var hero_alive := not player.is_dead
	for t in traps:
		if t.cooldown > 0.0:
			t.cooldown -= delta
			continue
		if hero_alive and hero.distance_squared_to(t.pos) <= t.radius * t.radius:
			player.take_damage(t.damage)
			t.cooldown = REARM
			triggered.emit(Vector3(t.pos.x, 0.2, t.pos.y), true)
			continue
		_query.clear()
		enemies.query_circle(t.pos, t.radius, _query)
		if _query.is_empty():
			continue
		# One victim per spring, so a horde funnels through instead of the
		# whole wave evaporating on one trap.
		var victim: EnemyManager.Enemy = _query[0]
		enemies.hit(victim, t.damage, t.pos, 0.0, Damage.Type.TRUE)
		t.cooldown = REARM
		triggered.emit(Vector3(t.pos.x, 0.2, t.pos.y), false)
