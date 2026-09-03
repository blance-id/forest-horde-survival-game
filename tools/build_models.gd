## Builds the models the CC0 kits do not ship — a wolf, a forest serpent, the
## walker mech and the spike trap — assembled from boxes in the exact palette
## everything else uses.
##
## The Kenney packs have no animals, so rather than change art direction (or
## the licence story) these are generated here in the same flat-shaded, chunky
## style. They are saved as ordinary scenes with the same part names the
## Graveyard rigs use — `torso`, `head`, `leg-left`, `leg-right`, `arm-left`,
## `arm-right` — so `EnemyMeshBaker` bakes them and `enemy_parts.gdshader`
## animates them with no special cases anywhere in the game.
##
## The trick for four legs on a two-leg rig: the shader swings arms opposite to
## legs, so the *front* legs go in the arm slots and the *back* legs in the leg
## slots. Front-right moves with back-left — a real diagonal trot.
##
## Run with:  godot --headless -s tools/build_models.gd
extends SceneTree

const COLORMAP := "res://assets/models/graveyard/Textures/colormap.png"
const OUT_DIR := "res://assets/models/built/"

# Palette UVs, taken from the middle of verified-uniform swatches in the
# colormap (see tools/palette_uvs.py). They are *not* on a tidy grid: the
# swatches sit at x = 12 + 64k, y = 12 + 128j, and Godot's compressed vertex
# attributes jitter a UV by a hair, so a coordinate anywhere near a swatch
# edge samples the anti-aliased boundary and speckles the whole face.
const SLATE := Vector2(0.77441, 0.77441)
const NEAR_BLACK := Vector2(0.52441, 0.77441)
const GREY_BLUE := Vector2(0.02441, 0.77441)
const GREY_MID := Vector2(0.64941, 0.77441)
const GREY_PALE := Vector2(0.89941, 0.77441)
const RED := Vector2(0.27441, 0.77441)
const GREEN := Vector2(0.64941, 0.52441)
const BROWN := Vector2(0.27441, 0.52441)
const CREAM := Vector2(0.52441, 0.52441)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_save(_build_wolf(), "wolf")
	_save(_build_serpent(), "serpent")
	_save(_build_mech(), "mech")
	_save(_build_spike_trap(), "spike_trap")
	quit()


# --- Wolf --------------------------------------------------------------------

func _build_wolf() -> Node3D:
	var root := Node3D.new()
	root.name = "Wolf"

	# Body, with a paler chest and a tail that sticks up.
	var body := _Part.new()
	body.box(Vector3(-0.17, -0.14, -0.36), Vector3(0.17, 0.14, 0.30), SLATE)
	body.box(Vector3(-0.13, -0.16, -0.10), Vector3(0.13, 0.02, 0.28), GREY_PALE)
	body.box(Vector3(-0.05, 0.02, -0.50), Vector3(0.05, 0.16, -0.32), GREY_BLUE)
	_attach(root, body, "torso", Vector3(0.0, 0.40, 0.0))

	# Head: skull, dark snout, two ears and a pair of red eyes.
	var head := _Part.new()
	head.box(Vector3(-0.14, -0.12, -0.04), Vector3(0.14, 0.14, 0.20), GREY_BLUE)
	head.box(Vector3(-0.08, -0.11, 0.18), Vector3(0.08, 0.03, 0.34), NEAR_BLACK)
	head.box(Vector3(-0.13, 0.12, 0.00), Vector3(-0.05, 0.24, 0.08), SLATE)
	head.box(Vector3(0.05, 0.12, 0.00), Vector3(0.13, 0.24, 0.08), SLATE)
	head.box(Vector3(-0.11, 0.00, 0.19), Vector3(-0.05, 0.06, 0.21), RED)
	head.box(Vector3(0.05, 0.00, 0.19), Vector3(0.11, 0.06, 0.21), RED)
	_attach(root, head, "head", Vector3(0.0, 0.48, 0.26))

	# Back legs in the leg slots, front legs in the arm slots.
	_leg(root, "leg-left", Vector3(-0.12, 0.34, -0.26))
	_leg(root, "leg-right", Vector3(0.12, 0.34, -0.26))
	_leg(root, "arm-left", Vector3(-0.12, 0.36, 0.20))
	_leg(root, "arm-right", Vector3(0.12, 0.36, 0.20))
	return root


func _leg(root: Node3D, part_name: String, pivot: Vector3) -> void:
	var leg := _Part.new()
	leg.box(Vector3(-0.05, -0.28, -0.05), Vector3(0.05, 0.02, 0.05), SLATE)
	leg.box(Vector3(-0.06, -0.34, -0.07), Vector3(0.06, -0.26, 0.06), NEAR_BLACK)
	_attach(root, leg, part_name, pivot)


# --- Forest serpent ----------------------------------------------------------

func _build_serpent() -> Node3D:
	var root := Node3D.new()
	root.name = "Serpent"

	# A long tapering coil. No legs: the gait bob does the slithering.
	#
	# Segments overlap slightly on Z. Butting them exactly would leave
	# coplanar faces touching, which z-fights into visible stripes down the
	# length of the snake.
	# Each segment is one solid box that butts against the next. Stacking a
	# second box inside for the belly made the two surfaces fight for the same
	# pixels, which striped the whole snake — the banding here comes from
	# alternating whole segments instead.
	var body := _Part.new()
	var z := 0.26
	var half := 0.21
	for i in 9:
		var alt := GREEN if i % 2 == 0 else BROWN
		body.box(Vector3(-half, -half * 0.8, z - 0.17), Vector3(half, half * 0.8, z), alt)
		z -= 0.17
		half *= 0.90
	_attach(root, body, "torso", Vector3(0.0, 0.24, 0.0))

	# Head: a broad wedge with a fanged mouth and red eyes.
	var head := _Part.new()
	head.box(Vector3(-0.24, -0.16, -0.06), Vector3(0.24, 0.16, 0.26), GREEN)
	head.box(Vector3(-0.17, -0.18, 0.22), Vector3(0.17, 0.03, 0.40), BROWN)
	head.box(Vector3(-0.13, -0.19, 0.33), Vector3(0.13, -0.11, 0.41), CREAM)
	head.box(Vector3(-0.19, 0.03, 0.16), Vector3(-0.08, 0.13, 0.26), RED)
	head.box(Vector3(0.08, 0.03, 0.16), Vector3(0.19, 0.13, 0.26), RED)
	_attach(root, head, "head", Vector3(0.0, 0.28, 0.32))
	return root


# --- Walker mech -------------------------------------------------------------

## The thing the hero climbs into. It is one part named `torso` because the
## enemy shader never touches it — `VehicleManager` places it directly — so
## the part name only needs to keep `_attach` happy.
func _build_mech() -> Node3D:
	var root := Node3D.new()
	root.name = "Mech"
	var hull := _Part.new()
	# Cockpit and shoulders.
	hull.box(Vector3(-0.34, 0.30, -0.30), Vector3(0.34, 0.78, 0.30), SLATE)
	hull.box(Vector3(-0.44, 0.46, -0.20), Vector3(-0.30, 0.70, 0.24), NEAR_BLACK)
	hull.box(Vector3(0.30, 0.46, -0.20), Vector3(0.44, 0.70, 0.24), NEAR_BLACK)
	# Canopy glass and a warning stripe, so it reads as a machine not a rock.
	hull.box(Vector3(-0.22, 0.56, 0.29), Vector3(0.22, 0.74, 0.35), GREY_PALE)
	hull.box(Vector3(-0.35, 0.34, -0.32), Vector3(0.35, 0.42, 0.32), BROWN)
	# Twin cannons out the front.
	hull.box(Vector3(-0.30, 0.48, 0.34), Vector3(-0.14, 0.62, 0.78), GREY_MID)
	hull.box(Vector3(0.14, 0.48, 0.34), Vector3(0.30, 0.62, 0.78), GREY_MID)
	hull.box(Vector3(-0.32, 0.46, 0.76), Vector3(-0.12, 0.64, 0.84), NEAR_BLACK)
	hull.box(Vector3(0.12, 0.46, 0.76), Vector3(0.32, 0.64, 0.84), NEAR_BLACK)
	# Legs and feet.
	for side in [-1.0, 1.0]:
		hull.box(Vector3(side * 0.30 - 0.09, 0.10, -0.10), Vector3(side * 0.30 + 0.09, 0.34, 0.10), NEAR_BLACK)
		hull.box(Vector3(side * 0.30 - 0.15, 0.0, -0.21), Vector3(side * 0.30 + 0.15, 0.12, 0.23), SLATE)
	_attach(root, hull, "torso", Vector3.ZERO)
	return root


# --- Spike trap ---------------------------------------------------------------

## The pit. It has to read as *dangerous* from a pitched camera at a glance,
## which means it cannot be a tidy machine: what makes a trap frightening is
## the evidence that it has already worked.
##
## So the frame is broken and rusted at uneven heights, the spikes are bone
## rather than steel and lean at every angle, the pit below them is black with
## old blood, and there is a skull on the tallest one with ribs and shards
## scattered around it. A ragged stain soaks into the grass outside the frame.
func _build_spike_trap() -> Node3D:
	var root := Node3D.new()
	root.name = "SpikeTrap"
	var t := _Part.new()

	# Dark, disturbed earth around the frame. This was two slabs of the brown
	# swatch first, meaning to be soaked ground — but lit by the sun that
	# brown is bright orange, and it read as a wooden deck. Near-black in two
	# offset slabs reads as a hole somebody dug, which is what it is.
	t.box(Vector3(-0.62, 0.004, -0.54), Vector3(0.58, 0.012, 0.60), NEAR_BLACK)
	t.box(Vector3(-0.52, 0.006, -0.64), Vector3(0.64, 0.014, 0.50), NEAR_BLACK)

	# The pit: black all the way down. A large pool of bright blood reads as
	# pink plastic from this camera, so the gore is kept to small wet patches
	# and the tips of the spikes; the hole itself just has to look bottomless.
	t.box(Vector3(-0.44, 0.0, -0.44), Vector3(0.44, 0.07, 0.44), NEAR_BLACK)

	# Dark iron frame, broken: four rails at different heights, one collapsed.
	t.box(Vector3(-0.52, 0.02, -0.52), Vector3(0.52, 0.15, -0.42), SLATE)
	t.box(Vector3(-0.52, 0.02, 0.42), Vector3(0.22, 0.11, 0.52), SLATE)
	t.box(Vector3(-0.52, 0.02, -0.52), Vector3(-0.42, 0.18, 0.30), SLATE)
	t.box(Vector3(0.42, 0.02, -0.30), Vector3(0.52, 0.10, 0.52), SLATE)
	# Rust bleeding down two corners, where the bolts are tearing out.
	t.box(Vector3(-0.53, 0.15, -0.53), Vector3(-0.45, 0.20, -0.45), BROWN)
	t.box(Vector3(0.45, 0.10, 0.45), Vector3(0.53, 0.15, 0.53), BROWN)

	# Spikes: bone, uneven, leaning every which way, red from the tips down.
	var spikes := [
		[Vector2(0.0, -0.06), 0.10, 0.62, Vector2(0.03, 0.04)],
		[Vector2(-0.24, 0.20), 0.085, 0.44, Vector2(-0.06, 0.03)],
		[Vector2(0.26, 0.16), 0.080, 0.50, Vector2(0.05, -0.04)],
		[Vector2(0.20, -0.26), 0.075, 0.38, Vector2(0.04, -0.05)],
		[Vector2(-0.27, -0.22), 0.090, 0.55, Vector2(-0.05, -0.03)],
		[Vector2(-0.05, 0.30), 0.070, 0.33, Vector2(0.02, 0.06)],
		[Vector2(0.32, -0.02), 0.065, 0.28, Vector2(0.07, 0.01)],
	]
	for sp in spikes:
		t.spike(sp[0], sp[1], sp[2], CREAM, RED, sp[3])
	# Wet patches where three of them come out of the floor of the pit.
	for base in [Vector2(0.0, -0.06), Vector2(-0.27, -0.22), Vector2(0.26, 0.16)]:
		t.box(Vector3(base.x - 0.07, 0.071, base.y - 0.07), Vector3(base.x + 0.07, 0.078, base.y + 0.07), RED)

	# The skull, driven onto the tallest spike and hanging off it. This is the
	# bit that does the work: a shape the eye reads instantly as somebody who
	# did not get out.
	var skull := Vector3(0.05, 0.46, -0.01)
	t.box(skull + Vector3(-0.13, 0.0, -0.12), skull + Vector3(0.13, 0.20, 0.12), CREAM)
	t.box(skull + Vector3(-0.10, -0.08, -0.09), skull + Vector3(0.10, 0.0, 0.09), CREAM)
	# Sockets and a hanging jaw, cut deep so they read at a distance.
	t.box(skull + Vector3(-0.11, 0.06, 0.09), skull + Vector3(-0.02, 0.15, 0.14), NEAR_BLACK)
	t.box(skull + Vector3(0.02, 0.06, 0.09), skull + Vector3(0.11, 0.15, 0.14), NEAR_BLACK)
	t.box(skull + Vector3(-0.08, -0.06, 0.08), skull + Vector3(0.08, 0.01, 0.13), NEAR_BLACK)
	# Blood running from the spike out through the top of the skull.
	t.box(skull + Vector3(-0.04, 0.18, -0.04), skull + Vector3(0.04, 0.26, 0.04), RED)

	# Ribs and shards in the pit, half sunk in the dark.
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.7
		var c := Vector2(cos(a), sin(a)) * 0.28
		t.box(Vector3(c.x - 0.12, 0.075, c.y - 0.025), Vector3(c.x + 0.12, 0.105, c.y + 0.025), CREAM)
	t.box(Vector3(-0.31, 0.075, 0.06), Vector3(-0.14, 0.115, 0.12), CREAM)
	t.box(Vector3(0.12, 0.075, -0.33), Vector3(0.18, 0.105, -0.16), CREAM)

	_attach(root, t, "torso", Vector3.ZERO)
	return root


# --- Plumbing ----------------------------------------------------------------

func _attach(root: Node3D, part: _Part, part_name: String, pivot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	# The baker reads the node's origin as the part's pivot and the mesh as
	# local to it, so a leg rotates from the hip rather than the floor.
	mi.position = pivot
	mi.mesh = part.build(load(COLORMAP))
	root.add_child(mi)
	mi.owner = root


func _save(root: Node3D, file_name: String) -> void:
	for c in root.get_children():
		c.owner = root
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err != OK:
		push_error("pack failed for " + file_name)
		return
	err = ResourceSaver.save(scene, OUT_DIR + file_name + ".tscn")
	print("%s -> %s (%s)" % [file_name, OUT_DIR + file_name + ".tscn", error_string(err)])
	root.free()


## Accumulates axis-aligned boxes into one flat-shaded surface. Every vertex of
## a face points at the centre of a palette cell, so with nearest filtering the
## colour is exact and nothing bleeds between swatches.
class _Part:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	func box(from: Vector3, to: Vector3, uv: Vector2) -> void:
		var c := [
			Vector3(from.x, from.y, from.z), Vector3(to.x, from.y, from.z),
			Vector3(to.x, to.y, from.z), Vector3(from.x, to.y, from.z),
			Vector3(from.x, from.y, to.z), Vector3(to.x, from.y, to.z),
			Vector3(to.x, to.y, to.z), Vector3(from.x, to.y, to.z),
		]
		# Each face is wound counter-clockwise seen from outside.
		_quad(c[5], c[4], c[7], c[6], Vector3.BACK, uv)
		_quad(c[0], c[1], c[2], c[3], Vector3.FORWARD, uv)
		_quad(c[4], c[0], c[3], c[7], Vector3.LEFT, uv)
		_quad(c[1], c[5], c[6], c[2], Vector3.RIGHT, uv)
		_quad(c[3], c[2], c[6], c[7], Vector3.UP, uv)
		_quad(c[4], c[5], c[1], c[0], Vector3.DOWN, uv)

	## A four-sided pyramid standing at `centre`, with the top fifth in
	## `tip_uv` so a spike looks like it has been used.
	func spike(centre: Vector2, half: float, height: float, uv: Vector2, tip_uv: Vector2,
			tilt: Vector2 = Vector2.ZERO) -> void:
		var apex := Vector3(centre.x + tilt.x, height, centre.y + tilt.y)
		var neck := height * 0.8
		var shrink := 0.2
		for i in 4:
			var a0 := TAU * float(i) / 4.0 + PI * 0.25
			var a1 := TAU * float(i + 1) / 4.0 + PI * 0.25
			var p0 := Vector3(centre.x + cos(a0) * half, 0.0, centre.y + sin(a0) * half)
			var p1 := Vector3(centre.x + cos(a1) * half, 0.0, centre.y + sin(a1) * half)
			var lean := tilt * 0.8
			var q0 := Vector3(centre.x + lean.x + cos(a0) * half * shrink, neck, centre.y + lean.y + sin(a0) * half * shrink)
			var q1 := Vector3(centre.x + lean.x + cos(a1) * half * shrink, neck, centre.y + lean.y + sin(a1) * half * shrink)
			var n := (p1 - p0).cross(q0 - p0).normalized()
			_quad(p0, p1, q1, q0, n, uv)
			_tri(q0, q1, apex, n, tip_uv)

	func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, uv: Vector2) -> void:
		var base := verts.size()
		for p in [a, b, c]:
			verts.append(p)
			normals.append(n)
			uvs.append(uv)
		indices.append_array([base, base + 2, base + 1])

	func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uv: Vector2) -> void:
		var base := verts.size()
		for p in [a, b, c, d]:
			verts.append(p)
			normals.append(n)
			uvs.append(uv)
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])

	func build(colormap: Texture2D) -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		# The baker pulls the colormap off this material; the runtime material
		# is built by EnemyMeshBaker.make_material().
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = colormap
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mesh.surface_set_material(0, mat)
		return mesh
