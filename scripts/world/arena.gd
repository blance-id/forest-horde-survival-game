## Builds the run's world from ChapterData: lit environment, ground, a dense
## tree band just outside the playable square and scattered decor inside it.
## Everything static is MultiMesh so hundreds of props cost one draw each.
class_name Arena
extends Node3D

const BORDER_DEPTH := 9.0
const GROUND_MARGIN := 40.0

var chapter: ChapterData
var bounds: ArenaBounds

var _rng := RandomNumberGenerator.new()


func build(data: ChapterData, seed_value: int = 1) -> void:
	chapter = data
	bounds = ArenaBounds.from_chapter(data)
	_rng.seed = seed_value
	_build_environment()
	_build_ground()
	_build_border()
	_build_decor()
	_build_giants()


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = chapter.sky_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = chapter.ambient_color
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = chapter.fog_color
	env.fog_depth_begin = 10.0
	env.fog_depth_end = 26.0
	env.fog_density = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Bloom carries the VFX: emissive bullets, auras and gems glow over the horde.
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# Two mid-size blur levels are enough (indices are 0-based, 7 levels).
	for level in 7:
		env.set_glow_level(level, 1.0 if level in [2, 4] else 0.0)
	var world_env := WorldEnvironment.new()
	world_env.name = "Environment"
	world_env.environment = env
	add_child(world_env)

	# Low warm sun so every prop and enemy throws a long soft shadow.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = chapter.sun_color
	sun.light_energy = chapter.sun_energy
	sun.rotation_degrees = Vector3(-40.0, 34.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	add_child(sun)


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	var size := (chapter.arena_half_size + GROUND_MARGIN) * 2.0
	plane.size = Vector2(size, size)
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 3
	noise.frequency = 0.05
	noise.seed = 7
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	# A single smooth octave for the dirt spots so they read as a few soft
	# worn patches instead of camouflage.
	var soft := FastNoiseLite.new()
	soft.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	soft.fractal_type = FastNoiseLite.FRACTAL_NONE
	soft.frequency = 0.025
	soft.seed = 11
	var soft_tex := NoiseTexture2D.new()
	soft_tex.width = 256
	soft_tex.height = 256
	soft_tex.seamless = true
	soft_tex.noise = soft
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/ground.gdshader")
	mat.set_shader_parameter("color_a", chapter.ground_color)
	mat.set_shader_parameter("color_b", chapter.ground_color_alt)
	mat.set_shader_parameter("dirt_color", chapter.dirt_color)
	mat.set_shader_parameter("noise", tex)
	mat.set_shader_parameter("soft_noise", soft_tex)
	mat.set_shader_parameter("patch_size", 11.0)
	mat.set_shader_parameter("arena_half", chapter.arena_half_size)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_border() -> void:
	if chapter.border_models.is_empty():
		return
	var outer := chapter.arena_half_size + BORDER_DEPTH
	var positions: Array[Vector2] = []
	# Poisson-ish scatter: reject points too close to an accepted one. The band
	# hugs the arena shape, so a round clearing gets a round wall of trees.
	var attempts := int(BORDER_DEPTH * outer * 2.5)
	for i in attempts:
		var p := Vector2(_rng.randf_range(-outer, outer), _rng.randf_range(-outer, outer))
		if p.length() > outer:
			continue
		var edge := bounds.radius_at(p.angle())
		if p.length() < edge + 0.6:
			continue
		var ok := true
		for q in positions:
			if q.distance_squared_to(p) < 1.2 * 1.2:
				ok = false
				break
		if ok:
			positions.append(p)
	# Split the positions between the border models.
	var buckets: Array = []
	for m in chapter.border_models:
		buckets.append([])
	for p in positions:
		buckets[_rng.randi_range(0, buckets.size() - 1)].append(p)
	for m in chapter.border_models.size():
		_scatter(chapter.border_models[m], buckets[m], 0.9, 1.35, "Border")


func _build_decor() -> void:
	if chapter.decor_models.is_empty() or chapter.decor_count <= 0:
		return
	var buckets: Array = []
	for m in chapter.decor_models:
		buckets.append([])
	for i in chapter.decor_count:
		var p := bounds.random_point(_rng, 1.0)
		if p.length() < 4.0:
			continue  # keep the hero's start clear
		buckets[_rng.randi_range(0, buckets.size() - 1)].append(p)
	for m in chapter.decor_models.size():
		_scatter(chapter.decor_models[m], buckets[m], 0.9, 1.25, "Decor")


func _build_giants() -> void:
	if chapter.giant_models.is_empty() or chapter.giant_count <= 0:
		return
	var positions: Array[Vector2] = []
	var attempts := chapter.giant_count * 12
	for i in attempts:
		if positions.size() >= chapter.giant_count:
			break
		var p := bounds.random_point(_rng, 1.5)
		if p.length() < 6.0:
			continue  # keep the hero's start clear
		var ok := true
		for q in positions:
			if q.distance_squared_to(p) < 5.0 * 5.0:
				ok = false
				break
		if ok:
			positions.append(p)
	var buckets: Array = []
	for m in chapter.giant_models:
		buckets.append([])
	for p in positions:
		buckets[_rng.randi_range(0, buckets.size() - 1)].append(p)
	for m in chapter.giant_models.size():
		_scatter(chapter.giant_models[m], buckets[m], 1.3, 1.8, "Giant")


func _scatter(scene: PackedScene, points: Array, scale_min: float, scale_max: float, prefix: String) -> void:
	if points.is_empty():
		return
	var node: Node = scene.instantiate()
	var meshes: Array = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.push_front(node)
	for mi: MeshInstance3D in meshes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = points.size()
		var local := _relative_transform(mi, node)
		for i in points.size():
			var p: Vector2 = points[i]
			var s := _rng.randf_range(scale_min, scale_max)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s, s))
			mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, 0.0, p.y)) * local)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = prefix + "_" + node.name + "_" + mi.name
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)
	node.free()


static func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != root and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
