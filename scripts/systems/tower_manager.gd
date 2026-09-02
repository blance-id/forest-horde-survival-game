## Buildable gun nests — the run's second verb.
##
## The rule that makes them interesting: a tower is inert on its own. It only
## fires while the hero stands inside `supply_range` (they are handing over
## their own ammo), and only a *firing* tower makes noise. Noise registers a
## lure with the EnemyManager, which pulls the horde onto the tower and lets
## them tear it down. So feeding a tower is a decision — it buys you a second
## gun and a place for the horde to pile up, at the cost of the tower itself.
class_name TowerManager
extends Node3D

signal built(position: Vector2)
signal fired(tower_position: Vector3, dir: Vector2)
signal destroyed(position: Vector3)
## Ammo actually consumed this frame, so the run can bill the player.
signal ammo_spent(amount: int)

const CAPACITY := 8
## Two towers cannot be raised closer than this.
const MIN_SPACING := 4.0
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


class Tower:
	var pos: Vector2
	var hp: float
	var max_hp: float
	var cooldown := 0.0
	var yaw := 0.0
	## Firing this frame: supplied by the hero and holding ammo.
	var firing := false
	var slot: int
	var lure: EnemyManager.Lure


@export var data: TowerData

var enemies: EnemyManager
var projectiles: ProjectileManager
var bounds := ArenaBounds.new()
var towers: Array[Tower] = []

var _base_mm: MultiMesh
var _gun_mm: MultiMesh
var _free: Array[int] = []


func configure(chapter: ChapterData, enemy_manager: EnemyManager, projectile_manager: ProjectileManager) -> void:
	bounds = ArenaBounds.from_chapter(chapter)
	enemies = enemy_manager
	projectiles = projectile_manager
	_base_mm = _make_multimesh(data.base_model, "TowerBases")
	_gun_mm = _make_multimesh(data.gun_model, "TowerGuns")
	for i in CAPACITY:
		_free.append(CAPACITY - 1 - i)


## True when a tower could go here right now — the HUD uses it to grey out the
## build button before the player wastes a tap.
func can_build(at: Vector2, wood: int) -> bool:
	if wood < data.wood_cost or _free.is_empty() or not bounds.contains(at, 1.0):
		return false
	for t in towers:
		if t.pos.distance_squared_to(at) < MIN_SPACING * MIN_SPACING:
			return false
	return true


func build(at: Vector2) -> Tower:
	if _free.is_empty():
		return null
	var t := Tower.new()
	t.pos = at
	t.max_hp = data.max_hp
	t.hp = t.max_hp
	t.slot = _free.pop_back()
	towers.append(t)
	_write(t)
	built.emit(at)
	return t


func tick(delta: float, hero: Vector2, ammo: int) -> void:
	var spent := 0
	var i := 0
	while i < towers.size():
		var t := towers[i]
		if t.hp <= 0.0:
			_remove(t)
			towers[i] = towers[towers.size() - 1]
			towers.pop_back()
			continue
		spent += _tick_tower(t, delta, hero, ammo - spent)
		i += 1
	if spent > 0:
		ammo_spent.emit(spent)


func _tick_tower(t: Tower, delta: float, hero: Vector2, ammo: int) -> int:
	t.cooldown = maxf(0.0, t.cooldown - delta)
	var supplied := hero.distance_squared_to(t.pos) <= data.supply_range * data.supply_range
	var target := enemies.nearest(t.pos, data.range) if supplied and ammo > 0 else null
	t.firing = target != null
	_set_noise(t)
	if not t.firing:
		_write(t)
		return 0
	var dir := (target.pos - t.pos).normalized()
	t.yaw = lerp_angle(t.yaw, atan2(dir.x, dir.y), minf(1.0, 12.0 * delta))
	_write(t)
	if t.cooldown > 0.0:
		return 0
	t.cooldown = data.cooldown
	var stats := data.weapon.stats_at(1)
	stats["range"] = data.range
	projectiles.fire(t.pos + dir * 0.5, dir, stats, data.damage, data.weapon)
	fired.emit(Vector3(t.pos.x, data.gun_height, t.pos.y), dir)
	return data.ammo_per_shot


## A tower is only a target while it is making noise.
func _set_noise(t: Tower) -> void:
	if t.firing and t.lure == null:
		t.lure = EnemyManager.Lure.new()
		t.lure.pos = t.pos
		t.lure.radius = data.noise_range
		t.lure.body_radius = data.body_radius
		t.lure.damage_sink = func(amount: float) -> void: t.hp -= amount
		enemies.lures.append(t.lure)
	elif not t.firing and t.lure != null:
		enemies.lures.erase(t.lure)
		t.lure = null


func _remove(t: Tower) -> void:
	if t.lure != null:
		enemies.lures.erase(t.lure)
		t.lure = null
	_base_mm.set_instance_transform(t.slot, HIDDEN)
	_gun_mm.set_instance_transform(t.slot, HIDDEN)
	_free.append(t.slot)
	destroyed.emit(Vector3(t.pos.x, 0.4, t.pos.y))


func _write(t: Tower) -> void:
	var s := data.scale
	var origin := Vector3(t.pos.x, 0.0, t.pos.y)
	_base_mm.set_instance_transform(t.slot, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), origin))
	var g := data.gun_scale
	_gun_mm.set_instance_transform(t.slot, Transform3D(
		Basis(Vector3.UP, t.yaw).scaled(Vector3(g, g, g)), origin + Vector3(0.0, data.gun_height * s, 0.0)))


func _make_multimesh(scene: PackedScene, node_name: String) -> MultiMesh:
	var node: Node = scene.instantiate()
	var mesh_node: MeshInstance3D = node as MeshInstance3D
	if mesh_node == null:
		mesh_node = node.find_children("*", "MeshInstance3D", true, false)[0]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh_node.mesh
	mm.instance_count = CAPACITY
	for i in CAPACITY:
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
