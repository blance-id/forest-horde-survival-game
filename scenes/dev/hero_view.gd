## Dev scene: the hero close up, for tuning weapon mounts and animations.
## tools/shot.sh out.png 60 --screen=res://scenes/dev/hero_view.tscn
## Optional user args: --hero=<character id> --yaw=<degrees> --move
extends Node3D

var _player: Player


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.36, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.75, 0.8)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var hero_id := "ranger"
	var yaw := 30.0
	var moving := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hero="):
			hero_id = a.get_slice("=", 1)
		elif a.begins_with("--yaw="):
			yaw = float(a.get_slice("=", 1))
		elif a == "--move":
			moving = true
	var character: CharacterData = load("res://resources/characters/%s.tres" % hero_id)
	_player = Player.new()
	add_child(_player)
	_player.setup(character, RunStats.from_character(character))
	_player.rotation_degrees.y = yaw
	if moving:
		_player.move_input = Vector2(0, -1)

	var cam := Camera3D.new()
	cam.fov = 35
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.6, 2.4), Vector3(0, 0.45, 0))
	cam.make_current()


func _process(delta: float) -> void:
	# Stand still: the viewer only cares about the pose and the weapon mount.
	var input := _player.move_input
	_player.tick(delta)
	_player.position = Vector3.ZERO
	_player.move_input = input
	_player.aim_dir = Vector2(sin(_player.rotation.y), cos(_player.rotation.y))
	if Engine.get_process_frames() == 40 and "--bones" in OS.get_cmdline_user_args():
		_dump_bones()


func _dump_bones() -> void:
	var sk: Skeleton3D = _player.find_child("Skeleton3D", true, false)
	for i in sk.get_bone_count():
		var g := sk.global_transform * sk.get_bone_global_pose(i)
		print("bone %s origin %s  x %s y %s z %s" % [sk.get_bone_name(i), g.origin, g.basis.x, g.basis.y, g.basis.z])
