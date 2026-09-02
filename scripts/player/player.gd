## The hero: a Kenney "mini" rig driven by an AnimationTree (upper body holds
## the weapon, legs sprint), moved by an input vector, damaged by contact.
## No physics body: the run is fully manager-driven and the arena is a square.
class_name Player
extends Node3D

signal hp_changed(current: float, max_hp: float)
signal damaged(amount: float)
signal died

const RADIUS := 0.35
const INVULN_TIME := 0.25
const TURN_SPEED := 14.0

var data: CharacterData
var stats: RunStats
var hp := 100.0
var move_input := Vector2.ZERO
## Direction the weapon should point (world XZ); set by the weapon system.
var aim_dir := Vector2.ZERO
var is_dead := false
## Ignores all damage (main-menu demo hero).
var invulnerable := false
var bounds := ArenaBounds.new()

var _model: Node3D
var _anim_player: AnimationPlayer
var _anim_tree: AnimationTree
var _weapon_mount: Node3D
var _hit_material: StandardMaterial3D
var _invuln := 0.0
var _yaw := 0.0
var _flash_tween: Tween


func setup(character: CharacterData, run_stats: RunStats) -> void:
	data = character
	stats = run_stats
	hp = stats.max_hp()
	_build_model()
	_build_animation()
	_attach_weapon()
	hp_changed.emit(hp, stats.max_hp())


func _build_model() -> void:
	_model = data.model.instantiate()
	add_child(_model)
	# One shared material per hero so the hit flash can drive emission.
	_hit_material = null
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if _hit_material == null and src is StandardMaterial3D:
				_hit_material = (src as StandardMaterial3D).duplicate()
				_hit_material.emission_enabled = true
				_hit_material.emission = Color(1.0, 0.3, 0.2)
				_hit_material.emission_energy_multiplier = 0.0
			if _hit_material != null:
				mi.set_surface_override_material(s, _hit_material)


func _build_animation() -> void:
	_anim_player = _model.find_child("AnimationPlayer", true, false)
	for anim_name in [data.anim_idle, data.anim_move]:
		var anim := _anim_player.get_animation(anim_name)
		if anim != null:
			anim.loop_mode = Animation.LOOP_LINEAR
	var upper := AnimationNodeAnimation.new()
	upper.animation = data.anim_idle
	var lower := AnimationNodeAnimation.new()
	lower.animation = data.anim_move
	var blend := AnimationNodeBlend2.new()
	blend.filter_enabled = true
	# Legs (and the root bob) come from the run cycle, everything else keeps
	# holding the weapon.
	var move_anim := _anim_player.get_animation(data.anim_move)
	for i in move_anim.get_track_count():
		var path := move_anim.track_get_path(i)
		var bone: String = path.get_subname(path.get_subname_count() - 1) if path.get_subname_count() > 0 else ""
		if bone in ["leg-left", "leg-right", "root"]:
			blend.set_filter_path(path, true)
	var tree_root := AnimationNodeBlendTree.new()
	tree_root.add_node("upper", upper)
	tree_root.add_node("lower", lower)
	tree_root.add_node("blend", blend)
	tree_root.connect_node("blend", 0, "upper")
	tree_root.connect_node("blend", 1, "lower")
	tree_root.connect_node("output", 0, "blend")
	_anim_tree = AnimationTree.new()
	_anim_player.add_sibling(_anim_tree)
	_anim_tree.anim_player = _anim_tree.get_path_to(_anim_player)
	_anim_tree.tree_root = tree_root
	_anim_tree.active = true


func _attach_weapon() -> void:
	if data.weapon_model == null:
		return
	var skeleton: Skeleton3D = _model.find_child("Skeleton3D", true, false)
	if skeleton == null:
		return
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = data.weapon_bone
	skeleton.add_child(attachment)
	_weapon_mount = Node3D.new()
	_weapon_mount.position = data.weapon_offset
	_weapon_mount.rotation_degrees = data.weapon_rotation_degrees
	_weapon_mount.scale = Vector3.ONE * data.weapon_scale
	attachment.add_child(_weapon_mount)
	var weapon: Node3D = data.weapon_model.instantiate()
	_weapon_mount.add_child(weapon)
	for mi: MeshInstance3D in weapon.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## World position bullets start from.
func muzzle_position() -> Vector3:
	return global_position + Basis(Vector3.UP, _yaw) * data.muzzle_offset


func forward() -> Vector2:
	return Vector2(sin(_yaw), cos(_yaw))


func tick(delta: float) -> void:
	if is_dead:
		return
	_invuln = maxf(0.0, _invuln - delta)
	if stats.regen_per_second() > 0.0 and hp < stats.max_hp():
		_set_hp(minf(stats.max_hp(), hp + stats.regen_per_second() * delta))

	var moving := move_input.length_squared() > 0.0001
	if moving:
		var step := move_input.limit_length(1.0) * stats.move_speed() * delta
		var p := bounds.clamp_point(Vector2(position.x + step.x, position.z + step.y), RADIUS)
		position = Vector3(p.x, position.y, p.y)
	_anim_tree.set("parameters/blend/blend_amount", 1.0 if moving else 0.0)

	# Face the aim target when there is one, else the direction of travel.
	var face := aim_dir if aim_dir.length_squared() > 0.0001 else move_input
	if face.length_squared() > 0.0001:
		var target_yaw := atan2(face.x, face.y)
		_yaw = lerp_angle(_yaw, target_yaw, minf(1.0, TURN_SPEED * delta))
		rotation.y = _yaw


func take_damage(amount: float) -> bool:
	if is_dead or invulnerable or _invuln > 0.0:
		return false
	var dealt := maxf(1.0, amount - stats.armor())
	_invuln = INVULN_TIME
	_set_hp(hp - dealt)
	damaged.emit(dealt)
	_flash()
	if hp <= 0.0:
		_die()
	return true


func heal(amount: float) -> void:
	if is_dead:
		return
	_set_hp(minf(stats.max_hp(), hp + amount))


## Called when max HP changes (level-up passive): keep the same missing HP.
func refresh_max_hp(previous_max: float) -> void:
	var missing := previous_max - hp
	_set_hp(maxf(1.0, stats.max_hp() - missing))


func _set_hp(value: float) -> void:
	hp = clampf(value, 0.0, stats.max_hp())
	hp_changed.emit(hp, stats.max_hp())


func _flash() -> void:
	if _hit_material == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_hit_material.emission_energy_multiplier = 1.5
	_flash_tween = create_tween()
	_flash_tween.tween_property(_hit_material, "emission_energy_multiplier", 0.0, 0.25)


func _die() -> void:
	is_dead = true
	_anim_tree.active = false
	var die_anim := _anim_player.get_animation(data.anim_die)
	if die_anim != null:
		die_anim.loop_mode = Animation.LOOP_NONE
		_anim_player.play(data.anim_die)
	died.emit()
