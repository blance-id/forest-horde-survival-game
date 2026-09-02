extends TestCase

const SCRIPT_DIRS := ["res://scripts", "res://autoload"]


## Every SoundBank.sfx("x") / ui("x") / jingle("x") literal in the scripts, and
## every sound name in weapon data, must resolve to a real clip, or a hit would
## be silent in the build.
func test_every_referenced_sound_exists() -> void:
	var rx := RegEx.create_from_string("SoundBank\\.(sfx|ui|jingle|music)\\(\"([a-z_]+)\"")
	var seen: Dictionary = {}
	for dir in SCRIPT_DIRS:
		for path in _gd_files(dir):
			for m in rx.search_all(FileAccess.get_file_as_string(path)):
				seen[[m.get_string(1), m.get_string(2)]] = path
	assert_gt(seen.size(), 15, "found SoundBank references")
	for key: Array in seen:
		var kind: String = key[0]
		var name: String = key[1]
		var dir := {"sfx": SoundBank.SFX_DIR, "ui": SoundBank.UI_DIR, "jingle": SoundBank.JINGLE_DIR, "music": SoundBank.MUSIC_DIR}[kind] as String
		assert_not_null(SoundBank._pick(dir, name), "%s '%s' from %s" % [kind, name, seen[key]])


func test_weapon_sounds_exist() -> void:
	var count := 0
	for file in DirAccess.get_files_at("res://resources/weapons"):
		if not file.ends_with(".tres"):
			continue
		var w: WeaponData = load("res://resources/weapons/" + file)
		count += 1
		if w.fire_sound != "":
			assert_not_null(SoundBank._pick(SoundBank.SFX_DIR, w.fire_sound), "%s fire_sound %s" % [w.id, w.fire_sound])
		assert_not_null(SoundBank._pick(SoundBank.SFX_DIR, w.hit_sound), "%s hit_sound %s" % [w.id, w.hit_sound])
	assert_gt(count, 3, "weapons scanned")


func test_chapter_music_loops() -> void:
	var chapter: ChapterData = load("res://resources/chapters/chapter_01.tres")
	assert_not_null(chapter.music)
	assert_not_null(chapter.boss_music)
	assert_true((chapter.music as AudioStreamOggVorbis).loop, "run music loops")
	assert_true((chapter.boss_music as AudioStreamOggVorbis).loop, "boss music loops")
	assert_true((SoundBank.music("menu") as AudioStreamOggVorbis).loop, "menu music loops")


func test_duck_lowers_music_bus_and_restores() -> void:
	var idx := AudioServer.get_bus_index("Music")
	GameState.set_setting("music_volume", 1.0)
	AudioManager.duck_music(false)
	var base := AudioServer.get_bus_volume_db(idx)
	AudioManager.duck_music(true)
	await (Engine.get_main_loop() as SceneTree).create_timer(AudioManager.DUCK_TIME + 0.1).timeout
	assert_approx(AudioServer.get_bus_volume_db(idx), base + AudioManager.DUCK_DB, 0.05, "ducked")
	AudioManager.duck_music(false)
	await (Engine.get_main_loop() as SceneTree).create_timer(AudioManager.DUCK_TIME + 0.1).timeout
	assert_approx(AudioServer.get_bus_volume_db(idx), base, 0.05, "restored")


func test_play_music_switches_active_player() -> void:
	AudioManager.play_music(SoundBank.music("menu"), 0.0)
	var first: AudioStreamPlayer = AudioManager._music_active
	AudioManager.play_music(SoundBank.music("run"), 0.0)
	assert_ne(AudioManager._music_active, first, "crossfade uses the other player")
	assert_eq(AudioManager._music_active.stream, SoundBank.music("run"))
	AudioManager.play_music(SoundBank.music("run"), 0.0)
	assert_eq(AudioManager._music_active.stream, SoundBank.music("run"), "same track is a no-op")
	AudioManager.stop_music(0.0)


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	return out
