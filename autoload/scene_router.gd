## Screen switching with a fade transition and background loading.
## Main registers its screen container and fade overlay on startup; every
## screen then calls SceneRouter.go_to(SceneRouter.MAIN_MENU) etc.
extends Node

signal screen_changed(path: String)

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const GAME := "res://scenes/gameplay/game.tscn"

var current_screen: Node
var current_path: String = ""

var _container: Node
var _fade: ColorRect
var _busy := false


func setup(container: Node, fade: ColorRect) -> void:
	_container = container
	_fade = fade
	_fade.color.a = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = true


func is_busy() -> bool:
	return _busy


## Replace the current screen with the scene at [param path].
## [param data] is passed to the new screen's `setup(data)` method if it has one.
func go_to(path: String, data: Dictionary = {}, fade_time: float = 0.25) -> void:
	if _busy:
		Log.warn("Router", "go_to(%s) ignored, transition in progress" % path)
		return
	_busy = true
	get_tree().paused = false
	await _fade_to(1.0, fade_time)

	var packed := await _load_packed(path)
	if packed == null:
		Log.error("Router", "Failed to load %s" % path)
		_busy = false
		await _fade_to(0.0, fade_time)
		return

	if current_screen != null:
		current_screen.queue_free()
		current_screen = null
	# Let the old screen actually leave the tree before the new one instantiates
	# so autoload signal connections and node names never overlap.
	await get_tree().process_frame

	current_screen = packed.instantiate()
	current_path = path
	_container.add_child(current_screen)
	if current_screen.has_method("setup"):
		current_screen.call("setup", data)
	screen_changed.emit(path)
	Log.info("Router", "Screen: %s" % path.get_file())

	await get_tree().process_frame
	await _fade_to(0.0, fade_time)
	_busy = false


func _load_packed(path: String) -> PackedScene:
	if ResourceLoader.has_cached(path):
		return ResourceLoader.load(path) as PackedScene
	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		return null
	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				return ResourceLoader.load_threaded_get(path) as PackedScene
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				return null
		await get_tree().process_frame
	return null


func _fade_to(alpha: float, duration: float) -> void:
	if _fade == null:
		return
	if duration <= 0.0 or is_equal_approx(_fade.color.a, alpha):
		_fade.color.a = alpha
		return
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished
