## Name-based access to the SFX library: `SoundBank.sfx("hit_zombie")` plays
## a random variant of assets/audio/sfx/hit_zombie_NN.ogg (or hit_zombie.ogg).
class_name SoundBank
extends RefCounted

const SFX_DIR := "res://assets/audio/sfx/"
const UI_DIR := "res://assets/audio/ui/"
const JINGLE_DIR := "res://assets/audio/jingles/"

static var _cache: Dictionary = {}


static func sfx(name: String, volume_db: float = 0.0, pitch_variance: float = 0.1) -> void:
	AudioManager.play_sfx(_pick(SFX_DIR, name), volume_db, pitch_variance)


static func ui(name: String, volume_db: float = 0.0) -> void:
	AudioManager.play_ui(_pick(UI_DIR, name), volume_db)


static func jingle(name: String, volume_db: float = 0.0) -> void:
	AudioManager.play_ui(_pick(JINGLE_DIR, name), volume_db)


static func _pick(dir: String, name: String) -> AudioStream:
	var key := dir + name
	var variants: Array = _cache.get(key, [])
	if variants.is_empty():
		var single := dir + name + ".ogg"
		if ResourceLoader.exists(single):
			variants.append(load(single))
		for i in range(1, 10):
			var path := dir + "%s_%02d.ogg" % [name, i]
			if ResourceLoader.exists(path):
				variants.append(load(path))
			else:
				break
		if variants.is_empty():
			push_warning("SoundBank: no sound named " + name)
		_cache[key] = variants
	if variants.is_empty():
		return null
	return variants[randi() % variants.size()]
