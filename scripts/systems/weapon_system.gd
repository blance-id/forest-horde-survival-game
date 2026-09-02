## Owns the hero's weapons for a run: auto-aims and fires projectile weapons,
## spins orbit weapons and pulses auras. Weapons are WeaponData + a level.
class_name WeaponSystem
extends Node3D

signal fired(weapon: WeaponData, from: Vector3, dir: Vector2)
signal enemy_hit(enemy: EnemyManager.Enemy, position: Vector3, killed: bool)

const ORBIT_HEIGHT := 0.55
const ORBIT_HIT_RADIUS := 0.4
const ORBIT_HIT_INTERVAL := 0.45
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


class Slot:
	var data: WeaponData
	var level := 1
	var stats: Dictionary
	var cooldown := 0.0
	var angle := 0.0
	var mmi: MultiMeshInstance3D
	var aura: MeshInstance3D
	var pulse := 0.0

	func refresh() -> void:
		stats = data.stats_at(level)


var player: Player
var enemies: EnemyManager
var projectiles: ProjectileManager
var run_stats: RunStats
var slots: Array[Slot] = []

var _query: Array = []


func add_or_upgrade(data: WeaponData) -> Slot:
	var slot := get_slot(data)
	if slot == null:
		slot = Slot.new()
		slot.data = data
		slots.append(slot)
		if data.kind == WeaponData.Kind.ORBIT:
			slot.mmi = _make_orbit_visual(data)
		elif data.kind == WeaponData.Kind.AURA:
			slot.aura = _make_aura_visual(data)
	else:
		slot.level = mini(slot.level + 1, data.max_level)
	slot.refresh()
	_refresh_visual(slot)
	return slot


func get_slot(data: WeaponData) -> Slot:
	for s in slots:
		if s.data == data:
			return s
	return null


func level_of(data: WeaponData) -> int:
	var s := get_slot(data)
	return s.level if s != null else 0


func tick(delta: float) -> void:
	if player.is_dead:
		return
	var origin := Vector2(player.position.x, player.position.z)
	var aim_set := false
	for slot in slots:
		match slot.data.kind:
			WeaponData.Kind.PROJECTILE:
				aim_set = _tick_projectile(slot, delta, origin, aim_set) or aim_set
			WeaponData.Kind.ORBIT:
				_tick_orbit(slot, delta, origin)
			WeaponData.Kind.AURA:
				_tick_aura(slot, delta, origin)
	if not aim_set:
		player.aim_dir = Vector2.ZERO


func _tick_projectile(slot: Slot, delta: float, origin: Vector2, aim_set: bool) -> bool:
	slot.cooldown -= delta * run_stats.attack_speed_mult()
	var s := slot.stats
	var target := enemies.nearest(origin, float(s["range"]))
	if target == null:
		slot.cooldown = maxf(slot.cooldown, 0.0)
		return false
	var dir := (target.pos - origin).normalized()
	if not aim_set:
		player.aim_dir = dir
	if slot.cooldown > 0.0:
		return true
	slot.cooldown += float(s["cooldown"])
	var count := int(s["projectile_count"]) + run_stats.projectile_add()
	var spread := deg_to_rad(float(s["spread_degrees"]))
	var muzzle := player.muzzle_position()
	var from := Vector2(muzzle.x, muzzle.z)
	var damage := float(s["damage"]) * run_stats.damage_mult()
	for i in count:
		var offset := 0.0 if count == 1 else lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		projectiles.fire(from, dir.rotated(offset), s, damage)
	fired.emit(slot.data, muzzle, dir)
	return true


func _tick_orbit(slot: Slot, delta: float, origin: Vector2) -> void:
	var s := slot.stats
	var count := int(s["projectile_count"])
	var radius := float(s["area"]) * run_stats.area_mult()
	slot.angle += float(s["projectile_speed"]) * delta
	var damage := float(s["damage"]) * run_stats.damage_mult()
	var key := slot.data.id
	var now := enemies.time
	for i in count:
		var a := slot.angle + TAU * float(i) / float(count)
		var p := origin + Vector2(cos(a), sin(a)) * radius
		var basis := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
		basis = basis.scaled(Vector3.ONE * float(s["projectile_scale"]))
		slot.mmi.multimesh.set_instance_transform(i, Transform3D(basis, Vector3(p.x, ORBIT_HEIGHT, p.y)))
		_query.clear()
		enemies.query_circle(p, ORBIT_HIT_RADIUS * float(s["projectile_scale"]), _query)
		for e: EnemyManager.Enemy in _query:
			if float(e.hit_cooldowns.get(key, -1.0)) > now:
				continue
			e.hit_cooldowns[key] = now + ORBIT_HIT_INTERVAL
			var killed := enemies.hit(e, damage, origin, float(s["knockback"]))
			enemy_hit.emit(e, Vector3(p.x, ORBIT_HEIGHT, p.y), killed)


func _tick_aura(slot: Slot, delta: float, origin: Vector2) -> void:
	var s := slot.stats
	var radius := float(s["area"]) * run_stats.area_mult()
	slot.aura.position = Vector3(player.position.x, 0.03, player.position.z)
	slot.aura.scale = Vector3(radius, 1.0, radius)
	slot.pulse = maxf(0.0, slot.pulse - delta * 3.0)
	(slot.aura.material_override as ShaderMaterial).set_shader_parameter("pulse", slot.pulse)
	slot.cooldown -= delta * run_stats.attack_speed_mult()
	if slot.cooldown > 0.0:
		return
	slot.cooldown += float(s["cooldown"])
	slot.pulse = 1.0
	var damage := float(s["damage"]) * run_stats.damage_mult()
	_query.clear()
	enemies.query_circle(origin, radius, _query)
	for e: EnemyManager.Enemy in _query:
		var killed := enemies.hit(e, damage, origin, float(s["knockback"]))
		enemy_hit.emit(e, e.position3d() + Vector3(0, 0.4, 0), killed)


func _make_orbit_visual(data: WeaponData) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _first_mesh(data.projectile_model)
	mm.instance_count = 12
	for i in mm.instance_count:
		mm.set_instance_transform(i, HIDDEN)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Orbit_" + data.id
	mmi.multimesh = mm
	mmi.custom_aabb = AABB(Vector3(-60, -1, -60), Vector3(120, 4, 120))
	add_child(mmi)
	return mmi


func _make_aura_visual(data: WeaponData) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.name = "Aura_" + data.id
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/aura_disc.gdshader")
	mat.set_shader_parameter("color", data.tint)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _refresh_visual(slot: Slot) -> void:
	if slot.mmi != null:
		var count := int(slot.stats["projectile_count"])
		for i in slot.mmi.multimesh.instance_count:
			if i >= count:
				slot.mmi.multimesh.set_instance_transform(i, HIDDEN)


static func _first_mesh(scene: PackedScene) -> Mesh:
	var node: Node = scene.instantiate()
	var mi: MeshInstance3D = node if node is MeshInstance3D else node.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := mi.mesh
	node.free()
	return mesh
