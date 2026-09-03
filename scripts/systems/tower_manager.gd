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

signal built(position: Vector2, level: int)
signal fired(tower_position: Vector3, dir: Vector2)
signal destroyed(position: Vector3)
## Ammo actually consumed this frame, so the run can bill the player.
signal ammo_spent(amount: int)

const CAPACITY := 8
## Two towers cannot be raised closer than this.
const MIN_SPACING := 4.0
## Standing this close to a nest is what upgrades it instead of building.
const UPGRADE_RANGE := 3.0
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


class Tower:
	var pos: Vector2
	## Ground ring showing this nest's reach.
	var ring: MeshInstance3D
	var level := 1
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


## The nest within upgrade range of `at`, or null. Standing next to one is
## what turns the build button into an upgrade button.
func upgradable_at(at: Vector2) -> Tower:
	for t in towers:
		if t.level < data.max_level() and t.pos.distance_squared_to(at) <= UPGRADE_RANGE * UPGRADE_RANGE:
			return t
	return null


## Wood the next action at `at` would cost, and what that action is. The HUD
## reads both so the button can say what the tap will actually do.
func action_cost(at: Vector2) -> int:
	var up := upgradable_at(at)
	return data.upgrade_cost(up.level) if up != null else data.wood_cost


func is_upgrade(at: Vector2) -> bool:
	return upgradable_at(at) != null


## True when the tap at `at` would do something the player can afford.
func can_act(at: Vector2, wood: int) -> bool:
	var up := upgradable_at(at)
	if up != null:
		return wood >= data.upgrade_cost(up.level)
	if towers.size() >= data.max_towers or _free.is_empty():
		return false
	if wood < data.wood_cost or not bounds.contains(at, 1.5):
		return false
	for t in towers:
		if t.pos.distance_squared_to(at) < MIN_SPACING * MIN_SPACING:
			return false
	return true


## Raises a new nest, or levels up the one being stood next to.
func build_or_upgrade(at: Vector2) -> Tower:
	var up := upgradable_at(at)
	if up != null:
		up.level += 1
		# Upgrading also patches it back up, so a battered nest is worth saving.
		up.max_hp = data.hull_at(up.level)
		up.hp = up.max_hp
		_write(up)
		built.emit(up.pos, up.level)
		return up
	if _free.is_empty() or towers.size() >= data.max_towers:
		return null
	var t := Tower.new()
	t.pos = at
	t.max_hp = data.hull_at(1)
	t.hp = t.max_hp
	t.slot = _free.pop_back()
	t.ring = _make_ring()
	towers.append(t)
	_write(t)
	built.emit(at, 1)
	return t


## One faint disc per nest, scaled to its reach. Kept as a real node rather
## than a MultiMesh: there are at most three, and each needs its own `active`.
func _make_ring() -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/tower_range.gdshader")
	mat.set_shader_parameter("color", data.weapon.tint)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Keeps the hero out of a nest's footprint. A tower is a solid object, and
## without this the player walks into one and the two models merge.
func push_out(p: Vector2, radius: float) -> Vector2:
	for t in towers:
		var clear := data.solid_radius * data.scale * 0.5 + radius
		var away := p - t.pos
		var d := away.length()
		if d < clear:
			if d < 0.0001:
				away = Vector2.RIGHT
				d = 1.0
			p = t.pos + away / d * clear
	return p


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
	var reach := data.range_at(t.level)
	var supplied := hero.distance_squared_to(t.pos) <= data.supply_range * data.supply_range
	var target := enemies.nearest(t.pos, reach) if supplied and ammo > 0 else null
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
	t.cooldown = data.cooldown_at(t.level)
	var stats := data.weapon.stats_at(1)
	stats["range"] = reach
	projectiles.fire(t.pos + dir * 0.5, dir, stats, data.damage_at(t.level), data.weapon)
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
	if t.ring != null:
		t.ring.queue_free()
		t.ring = null
	_base_mm.set_instance_transform(t.slot, HIDDEN)
	_gun_mm.set_instance_transform(t.slot, HIDDEN)
	_free.append(t.slot)
	destroyed.emit(Vector3(t.pos.x, 0.4, t.pos.y))


func _write(t: Tower) -> void:
	var s := data.scale
	var origin := Vector3(t.pos.x, 0.0, t.pos.y)
	if t.ring != null:
		var reach := data.range_at(t.level)
		t.ring.position = Vector3(t.pos.x, 0.04, t.pos.y)
		t.ring.scale = Vector3(reach, 1.0, reach)
		(t.ring.material_override as ShaderMaterial).set_shader_parameter("active", 1.0 if t.firing else 0.0)
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
