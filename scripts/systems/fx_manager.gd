## Pooled particle effects for the run. Every particle is written once into a
## MultiMesh instance (position, velocity, sizes, timing, colour) and
## `shaders/fx_particle.gdshaderinc` replays its life on the GPU from the
## `game_time` uniform, so bursts cost CPU only when they spawn and nothing
## while they play. One pool (= one draw call) per texture; ground splats live
## in a mix-blend pool with an 8-frame atlas. The node must stay at the world
## origin (the shader reads instance transforms as raw data).
class_name FxManager
extends Node3D

## Pool sizes: ring buffers, the oldest particle is overwritten when full.
const POOLS := {
	"spark": {"tex": "spark", "add": true, "count": 512},
	"glow": {"tex": "circle_soft", "add": true, "count": 384},
	"star": {"tex": "star", "add": true, "count": 160},
	"flash": {"tex": "muzzle_a", "add": true, "count": 48},
	"smoke": {"tex": "smoke_a", "add": false, "count": 256},
	"splat": {"tex": "splat", "add": false, "count": 96},
}
const PARTICLE_DIR := "res://assets/effects/particles/"
const SPLAT_DIR := "res://assets/effects/splats/"
const SPLAT_FRAMES := Vector2(4, 2)
const SPLAT_LIFE := 9.0
## Parked particles carry a spawn time far in the past so they stay dead.
const PARKED := Transform3D(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, -1e6), Vector3(0, -50, 0))


class Pool:
	var mm: MultiMesh
	var mat: ShaderMaterial
	var next := 0
	var count := 0


var time := 0.0

var _pools: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for key: String in POOLS:
		var cfg: Dictionary = POOLS[key]
		var pool := Pool.new()
		pool.count = int(cfg["count"])
		pool.mat = ShaderMaterial.new()
		pool.mat.shader = load("res://shaders/fx_particle_%s.gdshader" % ("add" if cfg["add"] else "mix"))
		if cfg["tex"] == "splat":
			pool.mat.set_shader_parameter("tex", _splat_atlas())
			pool.mat.set_shader_parameter("frames", SPLAT_FRAMES)
		else:
			pool.mat.set_shader_parameter("tex", load(PARTICLE_DIR + String(cfg["tex"]) + ".png"))
		pool.mm = MultiMesh.new()
		pool.mm.transform_format = MultiMesh.TRANSFORM_3D
		pool.mm.use_colors = true
		pool.mm.use_custom_data = true
		pool.mm.mesh = quad
		pool.mm.instance_count = pool.count
		for i in pool.count:
			pool.mm.set_instance_transform(i, PARKED)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Fx_" + key
		mmi.multimesh = pool.mm
		mmi.material_override = pool.mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, 8, 120))
		add_child(mmi)
		_pools[key] = pool


## Packs the eight splat images into one 4x2 atlas so all splats share a pool.
func _splat_atlas() -> ImageTexture:
	var atlas: Image
	for i in 8:
		var img: Image = (load(SPLAT_DIR + "splat_%02d.png" % (i + 1)) as Texture2D).get_image()
		img.decompress()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		if atlas == null:
			atlas = Image.create(img.get_width() * int(SPLAT_FRAMES.x), img.get_height() * int(SPLAT_FRAMES.y), false, Image.FORMAT_RGBA8)
		var cell := Vector2i(i % int(SPLAT_FRAMES.x), i / int(SPLAT_FRAMES.x))
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), cell * img.get_size())
	atlas.generate_mipmaps()
	return ImageTexture.create_from_image(atlas)


func tick(delta: float) -> void:
	time += delta
	for key: String in _pools:
		(_pools[key] as Pool).mat.set_shader_parameter("game_time", time)


func clear_all() -> void:
	for key: String in _pools:
		var pool: Pool = _pools[key]
		for i in pool.count:
			pool.mm.set_instance_transform(i, PARKED)


# --- Primitive ---------------------------------------------------------------

## Writes one particle. `size` = (start, end); `life` seconds; `color` alpha
## is peak opacity; `frame` picks an atlas cell; `ground` lays it flat.
func emit(pool_name: String, pos: Vector3, vel: Vector3, size: Vector2, life: float, color: Color,
		gravity: float = 0.0, drag: float = 0.0, spin: float = 0.0, fade_in: float = 0.08,
		frame: int = 0, ground: bool = false) -> void:
	var pool: Pool = _pools[pool_name]
	var i := pool.next
	pool.next = (pool.next + 1) % pool.count
	var xf := Transform3D(vel, Vector3(size.x, size.y, gravity), Vector3(spin, drag, time), pos)
	pool.mm.set_instance_transform(i, xf)
	pool.mm.set_instance_color(i, color)
	pool.mm.set_instance_custom_data(i, Color(fade_in, life, float(frame), 1.0 if ground else 0.0))


func _spread(dir: Vector2, spread: float, speed_min: float, speed_max: float, up_min: float, up_max: float) -> Vector3:
	var a := _rng.randf_range(-spread, spread)
	var d := dir.rotated(a) if dir.length_squared() > 0.001 else Vector2.from_angle(_rng.randf() * TAU)
	var speed := _rng.randf_range(speed_min, speed_max)
	return Vector3(d.x * speed, _rng.randf_range(up_min, up_max), d.y * speed)


# --- Presets -----------------------------------------------------------------

## Bullet / blade impact: a few hot sparks and a soft flash.
func hit(pos: Vector3, dir: Vector2, color: Color) -> void:
	var hot := color * 2.2
	hot.a = 1.0
	emit("glow", pos, Vector3.ZERO, Vector2(0.55, 0.15), 0.16, hot, 0.0, 0.0, 0.0, 0.01)
	for i in 4:
		var vel := _spread(dir, 1.1, 2.5, 5.0, 1.0, 3.0)
		emit("spark", pos, vel, Vector2(0.3, 0.08), _rng.randf_range(0.18, 0.3), hot, 9.0, 3.0, 0.0, 0.01)


## Enemy death: green-ish puff, a spray of sparks, a ground splat.
func death(pos: Vector3, tint: Color, big: bool = false) -> void:
	var k := 2.0 if big else 1.0
	# Chunky goo puff: saturated green pulled a little toward the enemy tint.
	var puff := Color(0.42, 0.72, 0.28, 1.0).lerp(tint, 0.25)
	puff.a = 0.95
	for i in (8 if big else 4):
		var vel := _spread(Vector2.ZERO, PI, 0.5, 1.4, 0.8, 1.8) * k
		emit("smoke", pos + Vector3(0, 0.35, 0), vel, Vector2(0.55, 1.1) * k, _rng.randf_range(0.4, 0.6), puff,
			-0.6, 2.5, _rng.randf_range(-3.0, 3.0), 0.05)
	var hot := Color(2.0, 1.7, 0.9, 1.0)
	for i in (14 if big else 6):
		var vel := _spread(Vector2.ZERO, PI, 2.0, 4.5, 2.0, 5.0) * k
		emit("spark", pos + Vector3(0, 0.4, 0), vel, Vector2(0.3, 0.08) * k, _rng.randf_range(0.3, 0.5), hot, 10.0, 2.0, 0.0, 0.01)
	emit("glow", pos + Vector3(0, 0.4, 0), Vector3.ZERO, Vector2(0.5, 1.6) * k, 0.22, Color(1.4, 1.8, 1.0, 0.9), 0.0, 0.0, 0.0, 0.01)
	splat(pos, Color(0.14, 0.26, 0.06, 0.95), 1.2 * k)


## Dark goo stain on the ground that slowly fades.
func splat(pos: Vector3, color: Color, size: float) -> void:
	var s := size * _rng.randf_range(0.8, 1.25)
	emit("splat", Vector3(pos.x, 0.02, pos.z), Vector3.ZERO, Vector2(s * 0.5, s), SPLAT_LIFE, color,
		0.0, 0.0, 0.0, 0.03, _rng.randi_range(0, 7), true)
	# The shader's fade-out starts at 55% of life; splats should hold longer,
	# so the visual is mostly the first half — SPLAT_LIFE is tuned for that.


## Muzzle flash at the gun tip, pointing along the shot.
func muzzle(pos: Vector3, dir: Vector2, color: Color) -> void:
	var hot := color * 2.4
	hot.a = 1.0
	emit("flash", pos + Vector3(dir.x, 0.0, dir.y) * 0.25, Vector3.ZERO, Vector2(0.55, 0.25), 0.09, hot, 0.0, 0.0,
		_rng.randf_range(-6.0, 6.0), 0.01)
	emit("glow", pos, Vector3.ZERO, Vector2(0.7, 0.2), 0.1, hot * 0.6, 0.0, 0.0, 0.0, 0.01)


## Picked up a gem / coin / heart.
func pickup(pos: Vector3, color: Color) -> void:
	var hot := color * 1.8
	hot.a = 1.0
	emit("glow", pos, Vector3(0, 1.2, 0), Vector2(0.5, 0.05), 0.25, hot, 0.0, 0.0, 0.0, 0.01)
	for i in 3:
		var vel := _spread(Vector2.ZERO, PI, 0.8, 1.8, 1.5, 3.0)
		emit("star", pos, vel, Vector2(0.16, 0.02), _rng.randf_range(0.25, 0.4), hot, 6.0, 2.0, _rng.randf_range(-8.0, 8.0), 0.01)


## Level-up: an expanding ring of stars and a bright flash around the hero.
func level_up(pos: Vector3) -> void:
	var gold := Color(2.0, 1.7, 0.7, 1.0)
	emit("glow", pos + Vector3(0, 0.6, 0), Vector3.ZERO, Vector2(1.0, 3.2), 0.45, gold, 0.0, 0.0, 0.0, 0.02)
	for i in 24:
		var a := TAU * float(i) / 24.0
		var vel := Vector3(cos(a), 0.0, sin(a)) * 4.5 + Vector3(0, 2.0, 0)
		emit("star", pos + Vector3(0, 0.3, 0), vel, Vector2(0.28, 0.06), 0.6, gold, 3.0, 2.5, _rng.randf_range(-6.0, 6.0), 0.02)
	for i in 10:
		var vel := _spread(Vector2.ZERO, PI, 0.3, 1.2, 3.0, 5.0)
		emit("spark", pos, vel, Vector2(0.22, 0.05), 0.7, gold, 4.0, 1.0, 0.0, 0.02)


## Hero took a hit: a red burst at the hero.
func hero_hurt(pos: Vector3) -> void:
	var red := Color(2.2, 0.5, 0.35, 1.0)
	emit("glow", pos + Vector3(0, 0.5, 0), Vector3.ZERO, Vector2(0.9, 1.8), 0.22, red, 0.0, 0.0, 0.0, 0.01)
	for i in 6:
		var vel := _spread(Vector2.ZERO, PI, 1.5, 3.0, 1.0, 3.0)
		emit("spark", pos + Vector3(0, 0.5, 0), vel, Vector2(0.18, 0.04), 0.3, red, 8.0, 2.0, 0.0, 0.01)


## Boss death: a screen-filling shock ring plus a big death burst.
func boss_death(pos: Vector3, tint: Color) -> void:
	death(pos, tint, true)
	var white := Color(2.4, 2.2, 1.8, 1.0)
	emit("glow", pos + Vector3(0, 0.8, 0), Vector3.ZERO, Vector2(1.5, 9.0), 0.55, white, 0.0, 0.0, 0.0, 0.02)
	for i in 36:
		var a := TAU * float(i) / 36.0
		var vel := Vector3(cos(a), 0.0, sin(a)) * 7.0 + Vector3(0, 1.5, 0)
		emit("star", pos + Vector3(0, 0.5, 0), vel, Vector2(0.4, 0.08), 0.8, white, 2.0, 2.0, _rng.randf_range(-6.0, 6.0), 0.02)


## Aura pulse: a soft ring flash on the ground.
func aura_pulse(pos: Vector3, radius: float, color: Color) -> void:
	var hot := color * 1.6
	hot.a = 0.55
	emit("glow", Vector3(pos.x, 0.05, pos.z), Vector3.ZERO, Vector2(radius * 1.2, radius * 2.6), 0.35, hot, 0.0, 0.0, 0.0, 0.05, 0, true)
