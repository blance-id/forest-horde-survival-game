## One-shot project configuration script.
## Run with:  godot --headless -s tools/configure_project.gd
## Writes every project setting through the engine API so project.godot is
## always in the exact format the installed Godot version expects.
extends SceneTree


func _init() -> void:
	_set_display()
	_set_input()
	_set_rendering()
	_set_autoloads()
	_set_layers()
	_set_misc()
	var err := ProjectSettings.save()
	if err != OK:
		push_error("ProjectSettings.save() failed: %s" % error_string(err))
		quit(1)
		return
	print("project.godot written")
	quit(0)


func _set_display() -> void:
	# Portrait phone baseline. canvas_items + expand keeps UI crisp and lets
	# taller/wider phones see more world instead of black bars.
	ProjectSettings.set_setting("display/window/size/viewport_width", 720)
	ProjectSettings.set_setting("display/window/size/viewport_height", 1280)
	ProjectSettings.set_setting("display/window/size/window_width_override", 405)
	ProjectSettings.set_setting("display/window/size/window_height_override", 720)
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")
	ProjectSettings.set_setting("display/window/handheld/orientation", 1) # portrait
	ProjectSettings.set_setting("display/window/size/resizable", true)
	ProjectSettings.set_setting("display/window/vsync/vsync_mode", 1)


func _set_input() -> void:
	# Mouse acts as a finger on desktop so touch code paths are always exercised.
	ProjectSettings.set_setting("input_devices/pointing/emulate_touch_from_mouse", true)
	ProjectSettings.set_setting("input_devices/pointing/emulate_mouse_from_touch", false)

	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("move_up", [KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("pause", [KEY_ESCAPE, KEY_P])
	_add_action("debug_toggle", [KEY_F3])


func _add_action(action: String, keys: Array) -> void:
	var events: Array = []
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.device = -1
		events.append(ev)
	ProjectSettings.set_setting("input/%s" % action, {"deadzone": 0.5, "events": events})


func _set_rendering() -> void:
	ProjectSettings.set_setting("rendering/renderer/rendering_method", "gl_compatibility")
	ProjectSettings.set_setting("rendering/renderer/rendering_method.mobile", "gl_compatibility")
	# Mobile GPUs: ETC2/ASTC compressed textures.
	ProjectSettings.set_setting("rendering/textures/vram_compression/import_etc2_astc", true)
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", 1) # linear
	ProjectSettings.set_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false)
	ProjectSettings.set_setting("rendering/environment/defaults/default_clear_color", Color(0.09, 0.14, 0.09))
	# 3D: one directional light with a small shadow atlas is all the game needs.
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size", 2048)
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/size.mobile", 1024)
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 1)
	ProjectSettings.set_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality.mobile", 0)
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", 0)
	# Driven every frame by the run; enemy_parts.gdshader animates the horde with it.
	ProjectSettings.set_setting("shader_globals/game_time", {"type": "float", "value": 0.0})


func _set_autoloads() -> void:
	ProjectSettings.set_setting("autoload/Log", "*res://autoload/log.gd")
	ProjectSettings.set_setting("autoload/GameState", "*res://autoload/game_state.gd")
	ProjectSettings.set_setting("autoload/SaveManager", "*res://autoload/save_manager.gd")
	ProjectSettings.set_setting("autoload/AudioManager", "*res://autoload/audio_manager.gd")
	ProjectSettings.set_setting("autoload/SceneRouter", "*res://autoload/scene_router.gd")


func _set_layers() -> void:
	ProjectSettings.set_setting("layer_names/2d_physics/layer_1", "world")
	ProjectSettings.set_setting("layer_names/2d_physics/layer_2", "player")
	ProjectSettings.set_setting("layer_names/2d_physics/layer_3", "pickups")


func _set_misc() -> void:
	ProjectSettings.set_setting("application/config/name", "Forest Zombie Survival")
	ProjectSettings.set_setting("application/config/version", "0.1.0")
	ProjectSettings.set_setting("application/run/main_scene", "res://scenes/main/main.tscn")
	ProjectSettings.set_setting("application/run/low_processor_mode", false)
	ProjectSettings.set_setting("application/config/features", PackedStringArray(["4.7", "GL Compatibility"]))
	# Persistent save location: user:// is app-private storage on Android/iOS.
	ProjectSettings.set_setting("application/config/use_custom_user_dir", false)
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second", 60)
	ProjectSettings.set_setting("physics/2d/default_gravity", 0)
	ProjectSettings.set_setting("debug/gdscript/warnings/untyped_declaration", 1)
	ProjectSettings.set_setting("debug/gdscript/warnings/unsafe_method_access", 0)
	ProjectSettings.set_setting("audio/buses/default_bus_layout", "res://resources/configs/default_bus_layout.tres")
	ProjectSettings.set_setting("gui/common/snap_controls_to_pixels", true)
	ProjectSettings.set_setting("gui/theme/custom", "res://resources/configs/ui_theme.tres")
