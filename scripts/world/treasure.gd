## Chests hidden around the map, holding XP and gold.
##
## They are the reason to leave the safe middle: a chest is always somewhere
## you would not otherwise go, and opening one takes a moment standing still.
## Chests that survive a wave stay put, so an unopened one is a promise the
## player can come back to.
class_name Treasure
extends Node3D

signal progress(ratio: float, world_position: Vector3)
signal opened(world_position: Vector3, xp: int, coins: int)

const OPEN_RANGE := 1.8
const OPEN_TIME := 1.2
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


class Chest:
	var pos: Vector2
	var yaw := 0.0
	var slot: int
	var xp: int
	var coins: int
	var open := false


var chests: Array[Chest] = []

var _mm: MultiMesh
var _timer := 0.0
var _current: Chest
var _rng := RandomNumberGenerator.new()


func build(chapter: ChapterData, seed_value: int, hills: Hills) -> void:
	if chapter.chest_model == null or chapter.chest_count <= 0:
		return
	_rng.seed = seed_value
	var bounds := ArenaBounds.from_chapter(chapter)
	_mm = _make_multimesh(chapter.chest_model, chapter.chest_count)
	for i in chapter.chest_count:
		var c := Chest.new()
		# Out towards the rim, and never inside a rock.
		for attempt in 20:
			c.pos = bounds.random_point(_rng, 3.0)
			if c.pos.length() > chapter.chest_clearance \
					and hills.push_out(c.pos, 1.2).is_equal_approx(c.pos):
				break
		c.yaw = _rng.randf() * TAU
		c.slot = i
		c.xp = int(chapter.chest_xp * _rng.randf_range(0.75, 1.4))
		c.coins = int(chapter.chest_coins * _rng.randf_range(0.7, 1.5))
		chests.append(c)
		_mm.set_instance_transform(i, Transform3D(
			Basis(Vector3.UP, c.yaw).scaled(Vector3.ONE * chapter.chest_scale),
			Vector3(c.pos.x, 0.0, c.pos.y)))


## Standing on a chest prises it open. Walking away resets it — you cannot
## crack one between dodges.
func tick(delta: float, hero: Vector2) -> void:
	var near := _nearest(hero)
	if near == null:
		if _current != null:
			_current = null
			_timer = 0.0
			progress.emit(-1.0, Vector3.ZERO)
		return
	if near != _current:
		_current = near
		_timer = 0.0
	_timer += delta
	var pos3 := Vector3(near.pos.x, 1.0, near.pos.y)
	if _timer < OPEN_TIME:
		progress.emit(_timer / OPEN_TIME, pos3)
		return
	near.open = true
	_mm.set_instance_transform(near.slot, HIDDEN)
	_current = null
	_timer = 0.0
	progress.emit(-1.0, Vector3.ZERO)
	opened.emit(pos3, near.xp, near.coins)


func _nearest(hero: Vector2) -> Chest:
	for c in chests:
		if not c.open and hero.distance_squared_to(c.pos) <= OPEN_RANGE * OPEN_RANGE:
			return c
	return null


func _make_multimesh(scene: PackedScene, count: int) -> MultiMesh:
	var node: Node = scene.instantiate()
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	if mesh_node == null:
		mesh_node = node.find_children("*", "MeshInstance3D", true, false)[0]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_node.mesh
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, HIDDEN)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Chests"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mmi.custom_aabb = AABB(Vector3(-200, -1, -200), Vector3(400, 6, 400))
	add_child(mmi)
	node.free()
	return mm
