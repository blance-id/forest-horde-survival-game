## People trapped in the forest. Stand next to one long enough and they hand
## over whatever they were carrying — a relic you can use immediately.
##
## The cost is the standing still: a rescue takes seconds, in the open, while
## the horde closes. That is the whole mechanic, so the progress ring is the
## only UI it needs.
class_name Survivors
extends Node3D

signal progress(ratio: float, world_position: Vector3)
signal rescued(world_position: Vector3, relic: RelicData)

const RESCUE_RANGE := 2.0
const RESCUE_TIME := 2.5
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


class Survivor:
	var pos: Vector2
	var yaw := 0.0
	var slot: int
	var freed := false
	var relic: RelicData


var bounds := ArenaBounds.new()
var survivors: Array[Survivor] = []

var _mm: MultiMesh
var _tent_mm: MultiMesh
var _timer := 0.0
var _current: Survivor
var _rng := RandomNumberGenerator.new()


func build(chapter: ChapterData, seed_value: int) -> void:
	bounds = ArenaBounds.from_chapter(chapter)
	if chapter.survivor_model == null or chapter.survivor_count <= 0:
		return
	_rng.seed = seed_value
	var pool := RelicCatalog.all()
	_mm = _make_multimesh(chapter.survivor_model, chapter.survivor_count, "Survivors", 1.0)
	if chapter.survivor_camp_model != null:
		_tent_mm = _make_multimesh(chapter.survivor_camp_model, chapter.survivor_count, "Camps", 1.0)
	for i in chapter.survivor_count:
		var s := Survivor.new()
		for attempt in 12:
			s.pos = bounds.random_point(_rng, 3.0)
			if s.pos.length() > 8.0:
				break
		s.yaw = _rng.randf() * TAU
		s.slot = i
		s.relic = pool[_rng.randi() % pool.size()]
		survivors.append(s)
		_write(s)


## Runs the rescue timer for whichever survivor the hero is standing next to.
## Walking away resets it — you cannot chip at a rescue between dodges.
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
	var pos3 := Vector3(near.pos.x, 1.4, near.pos.y)
	if _timer < RESCUE_TIME:
		progress.emit(_timer / RESCUE_TIME, pos3)
		return
	near.freed = true
	_mm.set_instance_transform(near.slot, HIDDEN)
	_current = null
	_timer = 0.0
	progress.emit(-1.0, Vector3.ZERO)
	rescued.emit(pos3, near.relic)


func _nearest(hero: Vector2) -> Survivor:
	for s in survivors:
		if not s.freed and hero.distance_squared_to(s.pos) <= RESCUE_RANGE * RESCUE_RANGE:
			return s
	return null


func _write(s: Survivor) -> void:
	var xf := Transform3D(Basis(Vector3.UP, s.yaw), Vector3(s.pos.x, 0.0, s.pos.y))
	_mm.set_instance_transform(s.slot, xf)
	if _tent_mm != null:
		# The camp sits just behind them, so a survivor reads as a place from
		# across the map rather than one more figure in the grass.
		var behind := Vector3(sin(s.yaw), 0.0, cos(s.yaw)) * -1.1
		_tent_mm.set_instance_transform(s.slot, Transform3D(Basis(Vector3.UP, s.yaw), xf.origin + behind))


func _make_multimesh(scene: PackedScene, count: int, node_name: String, scale: float) -> MultiMesh:
	var node: Node = scene.instantiate()
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	if mesh_node == null:
		var found := node.find_children("*", "MeshInstance3D", true, false)
		if found.is_empty():
			node.free()
			return null
		mesh_node = found[0]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_node.mesh
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, HIDDEN)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var extent := bounds.half + 2.0
	mmi.custom_aabb = AABB(Vector3(-extent, -1, -extent), Vector3(extent * 2.0, 5, extent * 2.0))
	add_child(mmi)
	node.free()
	return mm
