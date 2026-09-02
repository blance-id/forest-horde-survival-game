## Development-only helpers, added by Main in debug builds.
## - F3 (debug_toggle) shows a performance overlay.
## - Command line:  godot -- --screenshot=/path/out.png --after=120 [--screen=res://...] [--quit]
##   captures the viewport after N frames; used for automated visual checks.
##   --dev=cmd1,cmd2 sends each command to the current screen's dev_command()
##   30 frames before the screenshot (e.g. --dev=levelup, --dev=move).
extends CanvasLayer

var _screenshot_path := ""
var _screenshot_after := 90
var _auto_quit := false
var _dev_commands: PackedStringArray = []
var _frame := 0
var _overlay: Label


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Label.new()
	_overlay.visible = false
	_overlay.position = Vector2(8, 60)
	_overlay.add_theme_color_override("font_color", Color.YELLOW)
	_overlay.add_theme_color_override("font_shadow_color", Color.BLACK)
	_overlay.add_theme_constant_override("shadow_offset_x", 2)
	_overlay.add_theme_constant_override("shadow_offset_y", 2)
	_overlay.add_theme_font_size_override("font_size", 20)
	add_child(_overlay)
	_parse_args()


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_screenshot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--after="):
			_screenshot_after = int(arg.get_slice("=", 1))
		elif arg == "--quit":
			_auto_quit = true
		elif arg.begins_with("--dev="):
			_dev_commands = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--screen="):
			var target := arg.get_slice("=", 1)
			call_deferred("_go_to_screen", target)


func _go_to_screen(path: String) -> void:
	await get_tree().process_frame
	while SceneRouter.is_busy():
		await get_tree().process_frame
	SceneRouter.go_to(path, {}, 0.0)


func _process(_delta: float) -> void:
	_frame += 1
	if _overlay.visible:
		_overlay.text = "FPS %d\nNodes %d\nDraw calls %d\nMem %.1f MB" % [
			Engine.get_frames_per_second(),
			get_tree().get_node_count(),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			OS.get_static_memory_usage() / 1048576.0,
		]
	if not _dev_commands.is_empty() and _frame == maxi(1, _screenshot_after - 30):
		var screen := SceneRouter.current_screen
		if screen != null and screen.has_method("dev_command"):
			for cmd in _dev_commands:
				screen.call("dev_command", cmd)
		else:
			Log.warn("Dev", "Current screen has no dev_command()")
	if _screenshot_path != "" and _frame == _screenshot_after:
		_capture()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_overlay.visible = not _overlay.visible


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_screenshot_path)
	Log.info("Dev", "Screenshot %s -> %s (%dx%d)" % [error_string(err), _screenshot_path, img.get_width(), img.get_height()])
	if _auto_quit:
		get_tree().quit()
