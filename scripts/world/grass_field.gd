## The grass the player actually looks at.
##
## Grass is the most-seen surface in the game, and a shader painted on a flat
## plane only ever looks like a painted plane. This is real geometry: a
## MultiMesh of tufts that `shaders/grass.gdshader` wraps around the hero, so
## the field is dense wherever the camera is and costs a fixed number of
## instances no matter how large the map is.
##
## One draw call, a few thousand tiny blades, and the count comes from the
## quality setting.
class_name GrassField
extends MultiMeshInstance3D

## Side of the square the tufts are laid out over, in world units. The camera
## sees roughly twenty units ahead of the hero, so the patch has to be wider
## than forty or the fade at its rim is visible at the top of the screen.
const PATCH := 36.0
## Blades per tuft, crossed so a tuft reads from any angle.
const BLADES := 3
const BLADE_WIDTH := 0.07
const BLADE_HEIGHT := 0.30

var _material: ShaderMaterial


func build(chapter: ChapterData) -> void:
	var count := Quality.grass_tufts()
	if count <= 0:
		return
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _tuft_mesh()
	multimesh.instance_count = count
	# A jittered grid rather than pure random: even coverage with no visible
	# rows, and no clumps leaving bald patches.
	var side := int(ceil(sqrt(float(count))))
	var step := PATCH / float(side)
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for i in count:
		var gx := i % side
		var gy := i / side
		var x := -PATCH * 0.5 + (float(gx) + rng.randf()) * step
		var z := -PATCH * 0.5 + (float(gy) + rng.randf()) * step
		var yaw := rng.randf() * TAU
		var s := rng.randf_range(0.8, 1.35)
		multimesh.set_instance_transform(i, Transform3D(
			Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), Vector3(x, 0.0, z)))

	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/grass.gdshader")
	_material.set_shader_parameter("patch", PATCH)
	_material.set_shader_parameter("color_a", chapter.grass_color)
	_material.set_shader_parameter("color_b", chapter.grass_color_alt)
	_material.set_shader_parameter("dry_color", chapter.dirt_color.lightened(0.15))
	_material.set_shader_parameter("height_scale", chapter.grass_height)
	_material.set_shader_parameter("wind", chapter.grass_wind)
	_material.set_shader_parameter("arena_shape", int(chapter.arena_shape))
	_material.set_shader_parameter("arena_half", chapter.arena_half_size)
	material_override = _material
	# The field moves with the hero, so it can never be culled.
	custom_aabb = AABB(Vector3(-400, -1, -400), Vector3(800, 4, 800))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The whole field follows the hero; the shader does the wrapping.
func follow(hero: Vector3) -> void:
	if _material != null:
		_material.set_shader_parameter("hero", Vector2(hero.x, hero.z))


## One tuft: `BLADES` tapered quads standing up, crossed around the vertical.
## Two triangles each, so a full field of thousands is still only tens of
## thousands of triangles in a single draw.
func _tuft_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for b in BLADES:
		var a := PI * float(b) / float(BLADES)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var normal := Vector3(-sin(a), 0.0, cos(a))
		# Blades lean a little so a tuft is not a perfect star.
		var lean := dir * 0.10
		var base := verts.size()
		verts.append_array([
			-dir * BLADE_WIDTH,
			dir * BLADE_WIDTH,
			dir * BLADE_WIDTH * 0.25 + Vector3.UP * BLADE_HEIGHT + lean,
			-dir * BLADE_WIDTH * 0.25 + Vector3.UP * BLADE_HEIGHT + lean,
		])
		for i in 4:
			normals.append(normal)
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
