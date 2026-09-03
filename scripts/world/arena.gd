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
	_build_fog_wall()
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
	# Deep enough for the mountain range to read as distance rather than be
	# swallowed: near ground stays clear, the tree wall hazes, and the range
	# beyond it is a silhouette.
	env.fog_depth_begin = 14.0
	env.fog_depth_end = 95.0
	env.fog_density = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Bloom carries the VFX: emissive bullets, auras and gems glow over the horde.
	env.glow_enabled = true
	env.glow_intensity = Quality.glow_strength()
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	# Which blur levels are mixed in is the quality knob: one tight level on
	# LOW, a wide soft halo on top on MAX (indices are 0-based, 7 levels).
	var levels := Quality.glow_levels()
	for level in 7:
		env.set_glow_level(level, 1.0 if levels.has(level) else 0.0)
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
	sun.shadow_enabled = Quality.shadows()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = Quality.shadow_distance()
	sun.set_param(Light3D.PARAM_SHADOW_BLUR, 1.4)
	sun.directional_shadow_fade_start = 0.85
	# The beasts are big flat slabs rather than small chunky limbs, and at the
	# old bias they self-shadowed into stripes down their backs.
	sun.shadow_bias = 0.13
	sun.shadow_normal_bias = 3.0
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
	mat.set_shader_parameter("arena_shape", int(chapter.arena_shape))
	mat.set_shader_parameter("fog_tint", chapter.fog_color)
	mat.set_shader_parameter("grass_tex", preload("res://assets/textures/grass.png"))
	mat.set_shader_parameter("grass_scale", chapter.grass_scale)
	mat.set_shader_parameter("detail", 1.0 if Quality.ground_detail() else 0.0)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.material_override = mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


## A curtain of mist standing on the boundary, so it is obvious where the map
## stops. Built from the arena shape rather than a cylinder, so a clover map
## gets a clover-shaped wall.
func _build_fog_wall() -> void:
	var segments := 96
	var height := chapter.boundary_fog_height
	if height <= 0.0:
		return
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in segments + 1:
		var a := TAU * float(i) / float(segments)
		var r := bounds.radius_at(a) + chapter.boundary_fog_offset
		var p := Vector2(cos(a), sin(a)) * r
		verts.append(Vector3(p.x, 0.0, p.y))
		verts.append(Vector3(p.x, height, p.y))
		uvs.append(Vector2(float(i) / float(segments), 0.0))
		uvs.append(Vector2(float(i) / float(segments), 1.0))
		if i == segments:
			continue
		var b0 := i * 2
		indices.append_array([b0, b0 + 1, b0 + 3, b0, b0 + 3, b0 + 2])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/boundary_fog.gdshader")
	mat.set_shader_parameter("color", chapter.fog_color)
	mat.set_shader_parameter("density", chapter.boundary_fog_density)
	var mi := MeshInstance3D.new()
	mi.name = "BoundaryFog"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var extent := chapter.arena_half_size + 20.0
	mi.custom_aabb = AABB(Vector3(-extent, -1, -extent), Vector3(extent * 2.0, height + 2.0, extent * 2.0))
	add_child(mi)


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
	for i in roundi(chapter.decor_count * Quality.decor_scale()):
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
	var wanted := roundi(chapter.giant_count * Quality.decor_scale())
	var attempts := wanted * 12
	for i in attempts:
		if positions.size() >= wanted:
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
