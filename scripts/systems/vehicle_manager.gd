## Abandoned walker mechs scattered through the map. Step into one and you are
## piloting it: it moves where you move, its cannons fire instead of your
## weapons, and its armour soaks the hits instead of your health.
##
## The Metal Slug rule is what makes it a decision rather than a pickup — the
## mech has its own finite ammo and its own hull, and when either runs out you
## are back on foot exactly where the fight left you. Taking one early wastes
## it; saving one for the boss might be the run.
class_name VehicleManager
extends Node3D

signal mounted(vehicle_position: Vector3)
signal dismounted(vehicle_position: Vector3, wrecked: bool)
signal fired(from: Vector3, dir: Vector2)
## Ammo or hull changed while piloting, so the HUD can follow along.
signal state_changed(ammo: int, hull: float, max_hull: float)

## How close the hero has to walk to climb in.
const MOUNT_RANGE := 1.6
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


class Vehicle:
	var pos: Vector2
	var yaw := 0.0
	var ammo: int
	var hull: float
	var slot: int
	var alive := true


@export var data: VehicleData

var enemies: EnemyManager
var projectiles: ProjectileManager
var player: Player
var bounds := ArenaBounds.new()
var vehicles: Array[Vehicle] = []
## The one being piloted, or null.
var piloted: Vehicle

var _mm: MultiMesh
var _cooldown := 0.0
var _rng := RandomNumberGenerator.new()


func configure(chapter: ChapterData, enemy_manager: EnemyManager, projectile_manager: ProjectileManager, hero: Player, seed_value: int) -> void:
	enemies = enemy_manager
	projectiles = projectile_manager
	player = hero
	bounds = ArenaBounds.from_chapter(chapter)
	if data == null or data.model == null or chapter.vehicle_count <= 0:
		return
	_rng.seed = seed_value
	_mm = _make_multimesh(chapter.vehicle_count)
	for i in chapter.vehicle_count:
		var v := Vehicle.new()
		# Never within reach of the spawn: the hero should have to go and find one.
		for attempt in 12:
			v.pos = bounds.random_point(_rng, 3.0)
			if v.pos.length() > data.spawn_clearance:
				break
		v.yaw = _rng.randf() * TAU
		v.ammo = data.ammo
		v.hull = data.max_hull
		v.slot = i
		vehicles.append(v)
		_write(v)


func is_piloting() -> bool:
	return piloted != null


## Damage aimed at the hero while piloting hits the hull instead. Returns true
## when the mech soaked it.
func absorb(amount: float) -> bool:
	if piloted == null:
		return false
	piloted.hull -= amount
	state_changed.emit(piloted.ammo, maxf(0.0, piloted.hull), data.max_hull)
	if piloted.hull <= 0.0:
		_dismount(true)
	return true


func tick(delta: float, hero: Vector2) -> void:
	if piloted != null:
		_tick_piloted(delta, hero)
		return
	for v in vehicles:
		if v.alive and hero.distance_squared_to(v.pos) <= MOUNT_RANGE * MOUNT_RANGE:
			_mount(v)
			return


func _tick_piloted(delta: float, hero: Vector2) -> void:
	var v := piloted
	v.pos = hero
	_cooldown = maxf(0.0, _cooldown - delta)
	var target := enemies.nearest(hero, data.range)
	if target != null:
		var dir := (target.pos - hero).normalized()
		v.yaw = lerp_angle(v.yaw, atan2(dir.x, dir.y), minf(1.0, 14.0 * delta))
		if _cooldown <= 0.0 and v.ammo > 0:
			_cooldown = data.cooldown
			v.ammo -= 1
			var stats := data.weapon.stats_at(1)
			stats["range"] = data.range
			# Twin cannons: one shot from each side of the hull.
			var across := Vector2(dir.y, -dir.x)
			for side in [-1.0, 1.0]:
				projectiles.fire(v.pos + dir * 0.8 + across * side * 0.28, dir, stats, data.damage, data.weapon)
			fired.emit(Vector3(v.pos.x, data.muzzle_height, v.pos.y), dir)
			state_changed.emit(v.ammo, v.hull, data.max_hull)
			if v.ammo <= 0:
				_dismount(false)
				return
	_write(v)


func _mount(v: Vehicle) -> void:
	piloted = v
	_cooldown = 0.0
	player.vehicle_scale = data.hero_scale
	mounted.emit(Vector3(v.pos.x, 0.0, v.pos.y))
	state_changed.emit(v.ammo, v.hull, data.max_hull)


func _dismount(wrecked: bool) -> void:
	var v := piloted
	piloted = null
	player.vehicle_scale = 1.0
	if v == null:
		return
	if wrecked:
		v.alive = false
		_mm.set_instance_transform(v.slot, HIDDEN)
	else:
		# Out of ammo: the hull stays where it was left, empty and useless.
		v.alive = false
		_write(v)
	dismounted.emit(Vector3(v.pos.x, 0.0, v.pos.y), wrecked)


func _write(v: Vehicle) -> void:
	var s := data.scale
	_mm.set_instance_transform(v.slot, Transform3D(
		Basis(Vector3.UP, v.yaw).scaled(Vector3(s, s, s)), Vector3(v.pos.x, 0.0, v.pos.y)))


func _make_multimesh(count: int) -> MultiMesh:
	var node: Node = data.model.instantiate()
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
	mmi.name = "Vehicles"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var extent := bounds.half + 2.0
	mmi.custom_aabb = AABB(Vector3(-extent, -1, -extent), Vector3(extent * 2.0, 6, extent * 2.0))
	add_child(mmi)
	node.free()
	return mm
