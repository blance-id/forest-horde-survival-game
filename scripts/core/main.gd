## Root scene. Owns the screen container, the global UI layer (fade overlay)
## and the ambience audio node, then hands control to SceneRouter.
extends Node

@onready var game_container: Node = $Game
@onready var fade: ColorRect = $UI/Fade


func _ready() -> void:
	Log.info("Main", "Boot %s v%s | %s | %s" % [
		ProjectSettings.get_setting("application/config/name"),
		ProjectSettings.get_setting("application/config/version"),
		OS.get_name(),
		Engine.get_version_info()["string"],
	])
	_apply_mobile_window_hints()
	SceneRouter.setup(game_container, fade)
	if OS.is_debug_build():
		add_child(preload("res://scripts/core/dev_tools.gd").new())
	SceneRouter.go_to(SceneRouter.MAIN_MENU)


func _apply_mobile_window_hints() -> void:
	# Keep the screen awake while playing; the OS decides when to dim otherwise.
	DisplayServer.screen_set_keep_on(true)
	# Desktop dev window mimics a phone; mobile ignores this.
	if OS.has_feature("pc"):
		get_window().min_size = Vector2i(360, 640)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# App went to background: pause gameplay if a run is active.
			if SceneRouter.current_screen != null and SceneRouter.current_screen.has_method("on_app_background"):
				SceneRouter.current_screen.call("on_app_background")
