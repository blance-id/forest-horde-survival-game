## Straight-flying bullets as one MultiMesh. Hits are resolved against the
## EnemyManager's spatial hash; pierce lets a bullet continue through kills.
class_name ProjectileManager
extends Node3D

signal enemy_hit(enemy: EnemyManager.Enemy, position: Vector3, killed: bool)

const CAPACITY := 192
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
	var hit: Array = []


var enemies: EnemyManager
var bullets: Array[Bullet] = []

var _mm: MultiMesh
var _free: Array[int] = []
var _query: Array = []


func _ready() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.34
	mesh.radial_segments = 8
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.35)
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


func fire(from: Vector2, dir: Vector2, s: Dictionary, damage: float) -> void:
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
	bullets.append(b)
	_write(b)


func clear_all() -> void:
	for b in bullets:
		_mm.set_instance_transform(b.slot, HIDDEN)
		_free.append(b.slot)
	bullets.clear()


func tick(delta: float) -> void:
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
				var killed := enemies.hit(e, b.damage, b.pos - b.dir, b.knockback)
				enemy_hit.emit(e, Vector3(b.pos.x, HEIGHT, b.pos.y), killed)
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


func _write(b: Bullet) -> void:
	var yaw := atan2(b.dir.x, b.dir.y)
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
	basis = basis.scaled(Vector3.ONE * b.scale)
	_mm.set_instance_transform(b.slot, Transform3D(basis, Vector3(b.pos.x, HEIGHT, b.pos.y)))
