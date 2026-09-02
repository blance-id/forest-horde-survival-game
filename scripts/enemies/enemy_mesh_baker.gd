## Bakes a Kenney "mini" character scene into one ArrayMesh whose vertices carry
## the body part they belong to and that part's pivot (CUSTOM0 = pivot.xyz +
## part id, CUSTOM1 = torso pivot), for shaders/enemy_parts.gdshader.
## Works for both rig styles in the packs: rigid parts (Graveyard Kit: one
## MeshInstance3D per part) and skinned meshes (Mini Characters / Dungeon: one
## Skeleton3D with the same 7 bones, every vertex weighted to exactly one bone).
class_name EnemyMeshBaker
extends RefCounted

const PART_IDS := {
	"root": 0, "leg-left": 1, "leg-right": 2, "torso": 3,
	"arm-left": 4, "arm-right": 5, "head": 6,
}
const SHADER := preload("res://shaders/enemy_parts.gdshader")

static var _cache: Dictionary = {}


## Returns [ArrayMesh, Texture2D colormap, AABB] for the model, baking once per path.
static func bake(model: PackedScene) -> Array:
	var key := model.resource_path
	if _cache.has(key):
		return _cache[key]
	var root: Node3D = model.instantiate()
	var b := _Builder.new()
	var skeleton: Skeleton3D = root.find_child("Skeleton3D", true, false)
	if skeleton != null:
		b.torso_pivot = _bone_rest_origin(skeleton, skeleton.find_bone("torso"))
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			b.add_skinned(mi, skeleton)
	else:
		var torso: Node3D = root.find_child("torso", true, false)
		if torso != null:
			b.torso_pivot = _relative_transform(torso, root).origin
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			b.add_rigid(mi, root)
	root.free()
	var result := b.finish()
	_cache[key] = result
	return result


## ShaderMaterial for an enemy type, tuned from its EnemyData.
static func make_material(data: EnemyData, colormap: Texture2D) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("colormap", colormap)
	mat.set_shader_parameter("tint", data.tint)
	mat.set_shader_parameter("stride_rate", data.stride_rate)
	mat.set_shader_parameter("leg_swing", deg_to_rad(data.leg_swing_degrees))
	mat.set_shader_parameter("arm_forward", deg_to_rad(data.arm_forward_degrees))
	mat.set_shader_parameter("arm_down", deg_to_rad(data.arm_down_degrees))
	mat.set_shader_parameter("arm_swing", deg_to_rad(data.arm_swing_degrees))
	mat.set_shader_parameter("bob", data.bob_height)
	mat.set_shader_parameter("lean", deg_to_rad(data.lean_degrees))
	return mat


static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


static func _bone_rest_origin(sk: Skeleton3D, bone: int) -> Vector3:
	if bone < 0:
		return Vector3.ZERO
	return sk.get_bone_global_rest(bone).origin


class _Builder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var custom0 := PackedFloat32Array()
	var custom1 := PackedFloat32Array()
	var indices := PackedInt32Array()
	var colormap: Texture2D
	var torso_pivot := Vector3.ZERO
	var aabb := AABB()

	func add_rigid(mi: MeshInstance3D, root: Node3D) -> void:
		var part: int = PART_IDS.get(mi.name, 3)
		var xf := EnemyMeshBaker._relative_transform(mi, root)
		var pivot := xf.origin
		for s in mi.mesh.get_surface_count():
			_grab_material(mi.mesh.surface_get_material(s))
			var arr := mi.mesh.surface_get_arrays(s)
			var base := verts.size()
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			for i in v.size():
				var p := xf * v[i]
				_push(p, (xf.basis * n[i]).normalized(), uv[i], pivot, part)
			_append_indices(arr, base, v.size())

	func add_skinned(mi: MeshInstance3D, sk: Skeleton3D) -> void:
		var pivots: Array[Vector3] = []
		var part_of_bone: Array[int] = []
		for b in sk.get_bone_count():
			pivots.append(EnemyMeshBaker._bone_rest_origin(sk, b))
			part_of_bone.append(PART_IDS.get(sk.get_bone_name(b), 3))
		for s in mi.mesh.get_surface_count():
			_grab_material(mi.mesh.surface_get_material(s))
			var arr := mi.mesh.surface_get_arrays(s)
			var base := verts.size()
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bones.size() / v.size()
			for i in v.size():
				var best := 0
				var best_w := -1.0
				for k in per:
					if weights[i * per + k] > best_w:
						best_w = weights[i * per + k]
						best = bones[i * per + k]
				_push(v[i], n[i], uv[i], pivots[best], part_of_bone[best])
			_append_indices(arr, base, v.size())

	func _push(p: Vector3, n: Vector3, uv: Vector2, pivot: Vector3, part: int) -> void:
		aabb = aabb.expand(p) if not verts.is_empty() else AABB(p, Vector3.ZERO)
		verts.append(p)
		normals.append(n)
		uvs.append(uv)
		custom0.append_array([pivot.x, pivot.y, pivot.z, float(part)])
		custom1.append_array([torso_pivot.x, torso_pivot.y, torso_pivot.z, 0.0])

	func _append_indices(arr: Array, base: int, count: int) -> void:
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			for i in count:
				indices.append(base + i)
		else:
			for i in idx:
				indices.append(base + i)

	func _grab_material(mat: Material) -> void:
		if colormap == null and mat is BaseMaterial3D:
			colormap = (mat as BaseMaterial3D).albedo_texture

	func finish() -> Array:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_CUSTOM0] = custom0
		arrays[Mesh.ARRAY_CUSTOM1] = custom1
		arrays[Mesh.ARRAY_INDEX] = indices
		var flags := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
			| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		# Parts swing and the body topples on death: give the culling box room.
		var grown := aabb.grow(0.5)
		grown.position.y = -0.7
		grown.size.y = aabb.end.y + 1.2
		mesh.custom_aabb = grown
		return [mesh, colormap, aabb]
