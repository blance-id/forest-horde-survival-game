## Straight-flying bullets as one MultiMesh. Hits are resolved against the
## EnemyManager's spatial hash; pierce lets a bullet continue through kills.
## Caster enemies get their own slow, brightly coloured bolts in a second
## MultiMesh — they fly at a point, not at the hero, so they can be dodged.
class_name ProjectileManager
extends Node3D

signal enemy_hit(enemy: EnemyManager.Enemy, position: Vector3, dir: Vector2, amount: float, killed: bool, weapon: WeaponData)
## An enemy bolt reached the hero or fizzled out at its target point.
signal bolt_landed(position: Vector3, damage: float, hit_player: bool)

const CAPACITY := 192
const BOLT_CAPACITY := 48
const BOLT_HEIGHT := 0.75
const HEIGHT := 0.45
const HIDDEN := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(0, -50, 0))


class Bullet:
	var slot: int
	var pos: Vector2
	var dir: Vector2
	var speed: float
	var damage: float
	var pierce: int
	var range_left: float
	var knockback: float
	var radius: float
	var scale: float
	var weapon: WeaponData
	var hit: Array = []


class Bolt:
	var slot: int
	var pos: Vector2
	var target: Vector2
	var dir: Vector2
	var speed: float
	var damage: float
	var radius: float
	var color: Color


var enemies: EnemyManager
var player: Player
var bullets: Array[Bullet] = []
var bolts: Array[Bolt] = []

var _mm: MultiMesh
var _free: Array[int] = []
var _query: Array = []
var _bolt_mm: MultiMesh
var _bolt_free: Array[int] = []


func _ready() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.34
	mesh.radial_segments = 8
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Over-bright so the environment glow blooms every bullet.
	mat.albedo_color = Color(1.8, 1.5, 0.6)
	mesh.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = mesh
	_mm.instance_count = CAPACITY
	for i in CAPACITY:
		_mm.set_instance_transform(i, HIDDEN)
		_free.append(CAPACITY - 1 - i)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Bullets"
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-60, -1, -60), Vector3(120, 4, 120))
	add_child(mmi)
	_build_bolts()


## Caster bolts: fat unshaded spheres, tinted per instance so one mesh covers
## every spell colour.
func _build_bolts() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	_bolt_mm = MultiMesh.new()
	_bolt_mm.transform_format = MultiMesh.TRANSFORM_3D
	_bolt_mm.use_colors = true
	_bolt_mm.mesh = mesh
	_bolt_mm.instance_count = BOLT_CAPACITY
	for i in BOLT_CAPACITY:
		_bolt_mm.set_instance_transform(i, HIDDEN)
		_bolt_free.append(BOLT_CAPACITY - 1 - i)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Bolts"
	mmi.multimesh = _bolt_mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-60, -1, -60), Vector3(120, 4, 120))
	add_child(mmi)


## Fired at the end of a caster's wind-up. It flies at where the hero *was*.
func spawn_enemy_bolt(from: Vector3, target: Vector2, data: EnemyData) -> void:
	if _bolt_free.is_empty():
		return
	var b := Bolt.new()
	b.slot = _bolt_free.pop_back()
	b.pos = Vector2(from.x, from.z)
	b.target = target
	b.dir = (target - b.pos).normalized() if b.pos.distance_squared_to(target) > 0.0001 else Vector2.RIGHT
	b.speed = data.bolt_speed
	b.damage = data.damage
	b.radius = 0.3
	b.color = data.bolt_color
	bolts.append(b)
	_write_bolt(b)


func fire(from: Vector2, dir: Vector2, s: Dictionary, damage: float, weapon: WeaponData) -> void:
	if _free.is_empty():
		return
	var b := Bullet.new()
	b.slot = _free.pop_back()
	b.pos = from
	b.dir = dir.normalized()
	b.speed = float(s["projectile_speed"])
	b.damage = damage
	b.pierce = int(s["pierce"])
	b.range_left = float(s["range"])
	b.knockback = float(s["knockback"])
	b.scale = float(s["projectile_scale"])
	b.radius = 0.12 * b.scale
	b.weapon = weapon
	bullets.append(b)
	_write(b)


func clear_all() -> void:
	for b in bullets:
		_mm.set_instance_transform(b.slot, HIDDEN)
		_free.append(b.slot)
	bullets.clear()
	for b in bolts:
		_bolt_mm.set_instance_transform(b.slot, HIDDEN)
		_bolt_free.append(b.slot)
	bolts.clear()


func tick(delta: float) -> void:
	_tick_bolts(delta)
	var i := 0
	while i < bullets.size():
		var b := bullets[i]
		var step := b.speed * delta
		b.pos += b.dir * step
		b.range_left -= step
		var alive := b.range_left > 0.0
		if alive:
			_query.clear()
			enemies.query_circle(b.pos, b.radius + step * 0.5, _query)
			for e: EnemyManager.Enemy in _query:
				if b.hit.has(e):
					continue
				b.hit.append(e)
				var killed := enemies.hit(e, b.damage, b.pos - b.dir, b.knockback, b.weapon.damage_type)
				enemy_hit.emit(e, Vector3(b.pos.x, HEIGHT, b.pos.y), b.dir, enemies.last_dealt, killed, b.weapon)
				if b.pierce <= 0:
					alive = false
					break
				b.pierce -= 1
		if alive:
			_write(b)
			i += 1
		else:
			_mm.set_instance_transform(b.slot, HIDDEN)
			_free.append(b.slot)
			bullets[i] = bullets[bullets.size() - 1]
			bullets.pop_back()


## Bolts stop at the point they were aimed at, so standing still is what gets
## the hero hit — not bad luck.
func _tick_bolts(delta: float) -> void:
	var hero := Vector2(player.position.x, player.position.z) if player != null else Vector2.ZERO
	var alive_hero := player != null and not player.is_dead
	var i := 0
	while i < bolts.size():
		var b := bolts[i]
		var step := b.speed * delta
		var left := b.pos.distance_to(b.target)
		b.pos += b.dir * minf(step, left)
		var hit_player := alive_hero and b.pos.distance_to(hero) <= b.radius + Player.RADIUS
		if hit_player or left <= step:
			if hit_player:
				player.take_damage(b.damage)
			bolt_landed.emit(Vector3(b.pos.x, BOLT_HEIGHT, b.pos.y), b.damage, hit_player)
			_bolt_mm.set_instance_transform(b.slot, HIDDEN)
			_bolt_free.append(b.slot)
			bolts[i] = bolts[bolts.size() - 1]
			bolts.pop_back()
			continue
		_write_bolt(b)
		i += 1


func _write_bolt(b: Bolt) -> void:
	_bolt_mm.set_instance_transform(b.slot, Transform3D(Basis.IDENTITY, Vector3(b.pos.x, BOLT_HEIGHT, b.pos.y)))
	_bolt_mm.set_instance_color(b.slot, b.color)


func _write(b: Bullet) -> void:
	var yaw := atan2(b.dir.x, b.dir.y)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
	basis = basis.scaled(Vector3.ONE * b.scale)
	_mm.set_instance_transform(b.slot, Transform3D(basis, Vector3(b.pos.x, HEIGHT, b.pos.y)))
