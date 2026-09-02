## Debug logging with categories and levels.
## Usage: Log.info("Save", "loaded profile")  /  Log.warn(...)  /  Log.error(...)
## Output is silenced in release builds except for errors, which always go to
## the engine error stream so they show up in device logs (logcat / Console).
extends Node

enum Level { DEBUG, INFO, WARN, ERROR }

var min_level: Level = Level.DEBUG if OS.is_debug_build() else Level.WARN

var _start_msec: int = Time.get_ticks_msec()


func debug(category: String, message: String) -> void:
	_emit(Level.DEBUG, category, message)


func info(category: String, message: String) -> void:
	_emit(Level.INFO, category, message)


func warn(category: String, message: String) -> void:
	_emit(Level.WARN, category, message)


func error(category: String, message: String) -> void:
	_emit(Level.ERROR, category, message)


func _emit(level: Level, category: String, message: String) -> void:
	if level < min_level:
		return
	var elapsed: float = (Time.get_ticks_msec() - _start_msec) / 1000.0
	var line := "[%7.2f] [%s] %s" % [elapsed, category, message]
	match level:
		Level.ERROR:
			push_error(line)
		Level.WARN:
			push_warning(line)
		_:
			print(line)
