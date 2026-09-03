## The forest as a resource, not scenery. Trees are chopped by standing next
## to them and drop wood; bushes conceal whoever stands in them.
##
## Both are plain records over MultiMeshes — same trick as the horde, so a few
## hundred of them cost one draw call each and no nodes at all. A felled tree
## swaps its instance for a stump rather than disappearing, so the map keeps a
## record of where the player has been working.
class_name Forest
extends Node3D

signal chopped(position: Vector3, hp_ratio: float)
signal felled(position: Vector2, wood: int)

## Reach from the hero's centre to a trunk.
const CHOP_RANGE := 2.0
const CHOP_INTERVAL := 0.45
const CHOP_DAMAGE := 1.0
const STUMP_SCALE := 0.5
## Plants per bush.
const CLUMP := 7
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


class Trunk:
	var pos: Vector2
	var hp: float
	var max_hp: float
	var wood: int
	var scale: float
	var yaw: float
	## Which MultiMesh holds this tree, and the instance inside it.
	var pool: int
	var slot: int
	var standing := true


class Bush:
	var pos: Vector2
	var radius: float


var bounds := ArenaBounds.new()
var trees: Array[Trunk] = []
var bushes: Array[Bush] = []

var _pools: Array[MultiMesh] = []
var _bush_mm: MultiMesh
var _bush_count := 0
var _bush_radius := 2.2
var _stump: MultiMesh
var _stump_free := 0
var _chop_timer := 0.0
var _rng := RandomNumberGenerator.new()


func build(chapter: ChapterData, seed_value: int) -> void:
	bounds = ArenaBounds.from_chapter(chapter)
	_rng.seed = seed_value
	_build_trees(chapter)
	_build_bushes(chapter)


func _build_trees(chapter: ChapterData) -> void:
	if chapter.tree_models.is_empty() or chapter.tree_count <= 0:
		return
	var buckets: Array[Array] = []
	for m in chapter.tree_models:
		buckets.append([])
	for i in chapter.tree_count:
		var p := bounds.random_point(_rng, 2.0)
		if p.length() < 5.0:
			continue  # the hero's start stays clear
		var t := Trunk.new()
		t.pos = p
		t.max_hp = chapter.tree_hp
		t.hp = t.max_hp
		t.wood = chapter.wood_per_tree
		t.scale = _rng.randf_range(1.0, 1.45)
		t.yaw = _rng.randf() * TAU
		t.pool = _rng.randi_range(0, chapter.tree_models.size() - 1)
		buckets[t.pool].append(t)
		trees.append(t)
	for m in chapter.tree_models.size():
		_pools.append(_scatter(chapter.tree_models[m], buckets[m], "Tree_%d" % m))
	_stump = _make_multimesh(chapter.stump_model, trees.size(), "Stumps")


## A bush is a clump of normal-sized plants around a ring, not one plant scaled
## up: the hero has to be able to stand *in* it, and a single giant plant reads
## as a prop rather than cover.
func _build_bushes(chapter: ChapterData) -> void:
	if chapter.bush_model == null or chapter.bush_count <= 0:
		return
	_bush_count = chapter.bush_count
	_bush_radius = chapter.bush_radius
	_bush_mm = _make_multimesh(chapter.bush_model, _bush_count * CLUMP, "Bushes")
	_place_bushes()


## Scatters a fresh set of bushes, overwriting whatever was there.
func _place_bushes() -> void:
	bushes.clear()
	if _bush_mm == null:
		return
	var slot := 0
	for i in _bush_count:
		var b := Bush.new()
		b.pos = bounds.random_point(_rng, 3.0)
		b.radius = _bush_radius
		bushes.append(b)
		for k in CLUMP:
			var a := TAU * (float(k) + _rng.randf_range(-0.3, 0.3)) / float(CLUMP)
			var pos := b.pos + Vector2(cos(a), sin(a)) * b.radius * _rng.randf_range(0.55, 0.9)
			var scale := _rng.randf_range(1.1, 1.6)
			_bush_mm.set_instance_transform(slot, Transform3D(
				Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * scale),
				Vector3(pos.x, 0.0, pos.y)))
			slot += 1


## Every wave tramples the cover flat and new bushes come up somewhere else.
##
## Without this the player finds one bush near the spawn ring and never leaves
## it: cover that never moves is a camping spot, not a tactic. Returns where
## the old ones stood so the caller can throw the leaves about.
func regrow_bushes() -> Array[Vector2]:
	var old: Array[Vector2] = []
	for b in bushes:
		old.append(b.pos)
	_place_bushes()
	return old


## True while `p` is inside any bush: cover for the hero and the horde alike.
func hides(p: Vector2) -> bool:
	for b in bushes:
		if p.distance_squared_to(b.pos) <= b.radius * b.radius:
			return true
	return false


## Auto-chop: standing next to a trunk swings at it. The player never presses
## anything, they just walk up to a tree and wood starts coming.
func tick(delta: float, hero: Vector2) -> void:
	var target := nearest_trunk(hero, CHOP_RANGE)
	if target == null:
		_chop_timer = CHOP_INTERVAL * 0.4
		return
	_chop_timer -= delta
	if _chop_timer > 0.0:
		return
	_chop_timer = CHOP_INTERVAL
	target.hp -= CHOP_DAMAGE
	if target.hp > 0.0:
		chopped.emit(Vector3(target.pos.x, 1.0, target.pos.y), target.hp / target.max_hp)
		return
	_fell(target)


## Everything standing inside `radius` comes down. A boss is wider than a
## tree trunk, so without this it walks through trunks and looks like it is
## clipping through the level; flattening them instead turns the overlap into
## a wake of broken forest.
func crush(centre: Vector2, radius: float) -> int:
	var felled_count := 0
	var r2 := radius * radius
	for t in trees:
		if t.standing and t.pos.distance_squared_to(centre) <= r2:
			_fell(t)
			felled_count += 1
	return felled_count


func nearest_trunk(p: Vector2, max_dist: float) -> Trunk:
	var best: Trunk = null
	var best_d := max_dist * max_dist
	for t in trees:
		if not t.standing:
			continue
		var d := t.pos.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = t
	return best


func _fell(t: Trunk) -> void:
	t.standing = false
	_pools[t.pool].set_instance_transform(t.slot, HIDDEN)
	if _stump != null and _stump_free < _stump.instance_count:
		# The stump is what is left of the trunk, so it sits well under the tree's
		# own scale.
		_stump.set_instance_transform(_stump_free, Transform3D(
			Basis(Vector3.UP, t.yaw).scaled(Vector3.ONE * t.scale * STUMP_SCALE), Vector3(t.pos.x, 0.0, t.pos.y)))
		_stump_free += 1
	felled.emit(t.pos, t.wood)


func _scatter(scene: PackedScene, records: Array, node_name: String) -> MultiMesh:
	var mm := _make_multimesh(scene, records.size(), node_name)
	if mm == null:
		return null
	for i in records.size():
		var t: Trunk = records[i]
		t.slot = i
		mm.set_instance_transform(i, Transform3D(
			Basis(Vector3.UP, t.yaw).scaled(Vector3.ONE * t.scale), Vector3(t.pos.x, 0.0, t.pos.y)))
	return mm


## One MultiMesh per model. Kenney props are single-mesh, so the first
## MeshInstance3D in the scene is the whole prop.
func _make_multimesh(scene: PackedScene, count: int, node_name: String) -> MultiMesh:
	if scene == null or count <= 0:
		return null
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
	var extent := bounds.half + 8.0
	mmi.custom_aabb = AABB(Vector3(-extent, -2, -extent), Vector3(extent * 2.0, 12, extent * 2.0))
	add_child(mmi)
	node.free()
	return mm
