## Rock outcrops standing in the arena, and the mountain range behind it.
##
## The hills are the only solid terrain in the game: the hero and the horde
## both have to go round them, which turns an open field into somewhere with
## corners to fight in. The mountains are pure horizon — far outside the
## playable area, big enough to read as distance, and never touched by anything.
class_name Hills
extends Node3D

const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


## Solid outcrops, as plain obstacle circles the hero and the horde share.
var hills: Array[Obstacle] = []

var _rng := RandomNumberGenerator.new()


func build(chapter: ChapterData, seed_value: int) -> void:
	_rng.seed = seed_value
	var bounds := ArenaBounds.from_chapter(chapter)
	_build_hills(chapter, bounds)
	_build_mountains(chapter, bounds)


func _build_hills(chapter: ChapterData, bounds: ArenaBounds) -> void:
	if chapter.hill_models.is_empty() or chapter.hill_count <= 0:
		return
	var buckets: Array[Array] = []
	for m in chapter.hill_models:
		buckets.append([])
	for i in chapter.hill_count:
		var h := Obstacle.new()
		# Kept off the hero's start and off each other, so the map has room
		# to move rather than a rockery in the middle.
		for attempt in 20:
			h.pos = bounds.random_point(_rng, 4.0)
			if h.pos.length() > chapter.hill_clearance and not _crowded(h.pos, chapter.hill_spacing):
				break
		h.radius = chapter.hill_radius * _rng.randf_range(0.85, 1.25)
		hills.append(h)
		buckets[_rng.randi_range(0, chapter.hill_models.size() - 1)].append(h)
	for m in chapter.hill_models.size():
		_scatter(chapter.hill_models[m], buckets[m], "Hill_%d" % m,
			chapter.hill_scale_min, chapter.hill_scale_max)


## The range on the horizon: a broken ring well outside the tree wall, so the
## map looks like it sits in a valley instead of on an infinite plane.
func _build_mountains(chapter: ChapterData, bounds: ArenaBounds) -> void:
	if chapter.mountain_models.is_empty() or chapter.mountain_count <= 0:
		return
	var buckets: Array[Array] = []
	for m in chapter.mountain_models:
		buckets.append([])
	for i in chapter.mountain_count:
		var a := TAU * float(i) / float(chapter.mountain_count) + _rng.randf_range(-0.06, 0.06)
		var r := bounds.radius_at(a) + chapter.mountain_distance * _rng.randf_range(0.85, 1.3)
		var h := Obstacle.new()
		h.pos = Vector2(cos(a), sin(a)) * r
		h.radius = 0.0  # nothing ever gets near them
		buckets[_rng.randi_range(0, chapter.mountain_models.size() - 1)].append(h)
	for m in chapter.mountain_models.size():
		_scatter(chapter.mountain_models[m], buckets[m], "Mountain_%d" % m,
			chapter.mountain_scale_min, chapter.mountain_scale_max)


func _crowded(p: Vector2, spacing: float) -> bool:
	for h in hills:
		if h.pos.distance_squared_to(p) < spacing * spacing:
			return true
	return false


## Shoves a body of `radius` out of any hill it is standing in.
func push_out(p: Vector2, radius: float) -> Vector2:
	return Obstacle.push_out_of(hills, p, radius)


func _scatter(scene: PackedScene, records: Array, node_name: String, scale_min: float, scale_max: float) -> void:
	if scene == null or records.is_empty():
		return
	var node: Node = scene.instantiate()
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.push_front(node)
	# Each mesh in the source scene becomes its own MultiMesh, so a rock made
	# of two materials still renders in two draws rather than two hundred.
	for mi: MeshInstance3D in meshes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = records.size()
		var local := Arena._relative_transform(mi, node)
		for i in records.size():
			var h: Obstacle = records[i]
			var s := _rng.randf_range(scale_min, scale_max)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(h.pos.x, 0.0, h.pos.y)) * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = node_name + "_" + mi.name
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mmi.custom_aabb = AABB(Vector3(-400, -4, -400), Vector3(800, 90, 800))
		add_child(mmi)
	node.free()
