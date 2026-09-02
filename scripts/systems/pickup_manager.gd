## XP gems, coins and health potions dropped by enemies. Each kind is one
## MultiMesh pool; pickups drift to the hero once inside the pickup radius.
class_name PickupManager
extends Node3D

signal collected(kind: Kind, value: float, position: Vector3)

enum Kind { XP, COIN, HEAL }

const CAPACITY := {Kind.XP: 400, Kind.COIN: 96, Kind.HEAL: 8}
const HEIGHT := 0.25
const MAGNET_SPEED := 9.0
const COLLECT_DISTANCE := 0.35
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


class Pickup:
	var kind: Kind
	var slot: int
	var pos: Vector2
	var value: float
	var bob: float
	var attracted := false


class Pool:
	var multimesh: MultiMesh
	var free: Array[int] = []
	var scale := 1.0


var player: Player
var pickups: Array[Pickup] = []
var time := 0.0

var _pools: Dictionary = {}


func _ready() -> void:
	_pools[Kind.XP] = _make_pool(Kind.XP, _gem_mesh(), 1.0)
	_pools[Kind.COIN] = _make_pool(Kind.COIN, _scene_mesh("res://assets/models/dungeon/coin.glb"), 0.45)
	_pools[Kind.HEAL] = _make_pool(Kind.HEAL, _scene_mesh("res://assets/models/dungeon/potion.glb"), 1.0)


func drop(kind: Kind, pos: Vector2, value: float) -> void:
	var pool: Pool = _pools[kind]
	if pool.free.is_empty():
		# Pool full: fold the value into the nearest pickup of the same kind so
		# nothing the player earned is lost.
		var best: Pickup = null
		var best_d := INF
		for p in pickups:
			if p.kind != kind:
				continue
			var d := p.pos.distance_squared_to(pos)
			if d < best_d:
				best_d = d
				best = p
		if best != null:
			best.value += value
		return
	var p := Pickup.new()
	p.kind = kind
	p.slot = pool.free.pop_back()
	p.pos = pos
	p.value = value
	p.bob = randf() * TAU
	pickups.append(p)
	_write(p, pool)


func clear_all() -> void:
	for p in pickups:
		var pool: Pool = _pools[p.kind]
		pool.multimesh.set_instance_transform(p.slot, HIDDEN)
		pool.free.append(p.slot)
	pickups.clear()


## Pulls every XP gem to the hero (chest / level reward effect).
func attract_all(kind: Kind) -> void:
	for p in pickups:
		if p.kind == kind:
			p.attracted = true


func tick(delta: float) -> void:
	time += delta
	if player == null or player.is_dead:
		return
	var center := Vector2(player.position.x, player.position.z)
	var radius := player.stats.pickup_radius()
	var r2 := radius * radius
	var i := 0
	while i < pickups.size():
		var p := pickups[i]
		var pool: Pool = _pools[p.kind]
		var to_player := center - p.pos
		var d2 := to_player.length_squared()
		if not p.attracted and d2 <= r2:
			p.attracted = true
		if p.attracted:
			# Accelerate as it closes in so the last stretch feels snappy.
			var d := sqrt(d2)
			var speed := MAGNET_SPEED + (radius - minf(d, radius)) * 6.0
			var step := speed * delta
			if d <= COLLECT_DISTANCE or step >= d:
				collected.emit(p.kind, p.value, Vector3(p.pos.x, HEIGHT, p.pos.y))
				pool.multimesh.set_instance_transform(p.slot, HIDDEN)
				pool.free.append(p.slot)
				pickups[i] = pickups[pickups.size() - 1]
				pickups.pop_back()
				continue
			p.pos += to_player / d * step
		_write(p, pool)
		i += 1


func _write(p: Pickup, pool: Pool) -> void:
	var y := HEIGHT + sin(time * 3.0 + p.bob) * 0.05
	var basis := Basis(Vector3.UP, time * 1.5 + p.bob).scaled(Vector3.ONE * pool.scale)
	pool.multimesh.set_instance_transform(p.slot, Transform3D(basis, Vector3(p.pos.x, y, p.pos.y)))


func _make_pool(kind: Kind, mesh: Mesh, scale: float) -> Pool:
	var pool := Pool.new()
	pool.scale = scale
	var capacity: int = CAPACITY[kind]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = capacity
	for i in capacity:
		mm.set_instance_transform(i, HIDDEN)
		pool.free.append(capacity - 1 - i)
	pool.multimesh = mm
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Pickups_" + str(Kind.keys()[kind])
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-60, -1, -60), Vector3(120, 4, 120))
	add_child(mmi)
	return pool


static func _scene_mesh(path: String) -> Mesh:
	var node: Node = (load(path) as PackedScene).instantiate()
	var mi: MeshInstance3D = node if node is MeshInstance3D else node.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := mi.mesh
	node.free()
	return mesh


## Small glowing octahedron.
static func _gem_mesh() -> ArrayMesh:
	var s := 0.11
	var top := Vector3(0, s * 1.6, 0)
	var bottom := Vector3(0, -s * 1.6, 0)
	var ring := [Vector3(s, 0, 0), Vector3(0, 0, s), Vector3(-s, 0, 0), Vector3(0, 0, -s)]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		# Clockwise from outside = front face in Godot.
		for tri in [[top, a, b], [bottom, b, a]]:
			var n: Vector3 = ((tri[2] - tri[0]).cross(tri[1] - tri[0])).normalized()
			for v: Vector3 in tri:
				verts.append(v)
				normals.append(n)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.2
	mat.roughness = 0.3
	mesh.surface_set_material(0, mat)
	return mesh
