extends TestCase

const TMP := "user://profile.json"
const BAK := "user://profile.bak.json"

var _original_profile: Dictionary


func before_each() -> void:
	_original_profile = GameState.profile.duplicate(true)


func after_each() -> void:
	GameState.profile = _original_profile
	GameState.save()
	SaveManager.flush()


func test_defaults_merge_keeps_new_keys() -> void:
	var stored := {"coins": 42, "settings": {"music_volume": 0.3}, "junk": 1}
	var merged: Dictionary = GameState._merge_defaults(GameState._default_profile(), stored)
	assert_eq(merged["coins"], 42)
	assert_approx(merged["settings"]["music_volume"], 0.3)
	assert_approx(merged["settings"]["sfx_volume"], 1.0, 0.001, "missing key gets default")
	assert_false(merged.has("junk"), "unknown keys dropped")
	assert_eq(merged["unlocked_chapters"], ["chapter_01"])


func test_merge_rejects_wrong_types() -> void:
	var stored := {"coins": "lots", "unlocked_chapters": "nope"}
	var merged: Dictionary = GameState._merge_defaults(GameState._default_profile(), stored)
	assert_eq(merged["coins"], 0)
	assert_eq(merged["unlocked_chapters"], ["chapter_01"])


func test_corrupt_file_falls_back_to_backup() -> void:
	var good := {"version": 1, "coins": 77}
	var f := FileAccess.open(BAK, FileAccess.WRITE)
	f.store_string(JSON.stringify(good))
	f.close()
	f = FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var loaded := SaveManager.load_profile()
	assert_eq(loaded.get("coins"), 77, "backup used when main file is corrupt")


func test_round_trip_and_coins() -> void:
	GameState.profile = GameState._default_profile()
	GameState.add_coins(150)
	assert_true(GameState.spend_coins(100))
	assert_false(GameState.spend_coins(100), "cannot overspend")
	assert_eq(GameState.get_coins(), 50)
	SaveManager.flush()
	var loaded := SaveManager.load_profile()
	assert_eq(int(loaded["coins"]), 50)


func test_record_run_tracks_best() -> void:
	GameState.profile = GameState._default_profile()
	var first := GameState.record_run("chapter_01", 120.0, 30, false, 10)
	var second := GameState.record_run("chapter_01", 90.0, 50, true, 10)
	assert_true(first)
	assert_false(second, "shorter run is not a new best time")
	var rec := GameState.get_chapter_record("chapter_01")
	assert_approx(rec["best_time"], 120.0)
	assert_eq(rec["best_kills"], 50)
	assert_eq(rec["wins"], 1)
	assert_eq(GameState.profile["stats"]["runs"], 2)
