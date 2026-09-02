## Local persistence. Writes a JSON profile to user:// (app-private storage on
## Android/iOS), keeps one backup, and recovers from missing or corrupt files.
## Writes are coalesced: call request_save() freely, the file is written at
## most once per SAVE_DEBOUNCE seconds and always on app pause/quit.
extends Node

const SAVE_PATH := "user://profile.json"
const BACKUP_PATH := "user://profile.bak.json"
const SAVE_DEBOUNCE := 0.5

signal saved
signal load_failed(reason: String)

var _pending: Dictionary = {}
var _dirty := false
var _timer: SceneTreeTimer


func _ready() -> void:
	# Keep processing while the game is paused so quitting from the pause menu still flushes.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST:
			flush()


## Returns the stored profile dictionary, or an empty dictionary when nothing
## usable exists. Never throws; corruption is logged and the backup is tried.
func load_profile() -> Dictionary:
	for path: String in [SAVE_PATH, BACKUP_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var data := _read_json(path)
		if data.is_empty():
			Log.warn("Save", "Unreadable save at %s, trying next" % path)
			load_failed.emit("corrupt:%s" % path)
			continue
		Log.info("Save", "Loaded profile from %s" % path)
		return data
	Log.info("Save", "No existing profile, starting fresh")
	return {}


## Schedule a write of [param data]. Cheap to call often.
func request_save(data: Dictionary) -> void:
	_pending = data
	_dirty = true
	if _timer == null or _timer.time_left <= 0.0:
		_timer = get_tree().create_timer(SAVE_DEBOUNCE, true, false, true)
		_timer.timeout.connect(flush)


## Write immediately if anything is pending.
func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	if _write_json(SAVE_PATH, _pending):
		saved.emit()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.error("Save", "Cannot open %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		Log.error("Save", "JSON parse error in %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		Log.error("Save", "Save root is not a dictionary in %s" % path)
		return {}
	return json.data


func _write_json(path: String, data: Dictionary) -> bool:
	# Rotate the previous good file to the backup slot before overwriting.
	if FileAccess.file_exists(path):
		var dir := DirAccess.open("user://")
		if dir != null:
			dir.copy(path, BACKUP_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		Log.error("Save", "Cannot write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	Log.debug("Save", "Profile written")
	return true
