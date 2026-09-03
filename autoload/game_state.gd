## Cross-scene game state: the player's persistent profile (coins, meta
## upgrades, unlocks, settings, stats) plus transient data handed between
## screens (selected chapter, last run result).
## Persistence goes through SaveManager; everything here is plain data so the
## save file stays a readable JSON document.
extends Node

const PROFILE_VERSION := 1
## How many one-shot relics can be carried into a run.
const BAG_SIZE := 3

signal coins_changed(amount: int)
signal inventory_changed
signal profile_loaded
signal settings_changed

var profile: Dictionary = {}

## Chapter the player will start when pressing Play.
var selected_chapter_id: String = "chapter_01"
## Filled by the gameplay scene when a run ends, read by the result screen.
var last_run_result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()


func _default_profile() -> Dictionary:
	return {
		"version": PROFILE_VERSION,
		"coins": 0,
		"meta_upgrades": {},           # upgrade_id -> level
		"unlocked_chapters": ["chapter_01"],
		"chapter_records": {},         # chapter_id -> {best_time, best_kills, wins}
		"inventory": {},               # relic_id -> count owned
		"bag": [],                     # relic_ids taken into the next run (<= BAG_SIZE)
		"settings": {
			"music_volume": 0.8,
			"sfx_volume": 1.0,
			"muted": false,
			"haptics": true,
		},
		"stats": {
			"runs": 0,
			"total_kills": 0,
			"total_time": 0.0,
			"total_coins": 0,
		},
	}


func _load() -> void:
	var stored := SaveManager.load_profile()
	profile = _merge_defaults(_default_profile(), stored)
	if stored.get("version", 0) != PROFILE_VERSION:
		profile["version"] = PROFILE_VERSION
		save()
	profile_loaded.emit()
	Log.info("State", "Profile ready: %d coins, %d chapters unlocked" % [get_coins(), get_unlocked_chapters().size()])


## Deep-merge stored values over defaults so new keys added in later versions
## always exist and unknown junk from a corrupted file is dropped.
func _merge_defaults(defaults: Dictionary, stored: Dictionary) -> Dictionary:
	var out := defaults.duplicate(true)
	for key: Variant in defaults.keys():
		if not stored.has(key):
			continue
		var d: Variant = defaults[key]
		var s: Variant = stored[key]
		if typeof(d) == TYPE_DICTIONARY and typeof(s) == TYPE_DICTIONARY:
			if (d as Dictionary).is_empty():
				out[key] = (s as Dictionary).duplicate(true)
			else:
				out[key] = _merge_defaults(d, s)
		elif typeof(d) == typeof(s) or (typeof(d) == TYPE_INT and typeof(s) == TYPE_FLOAT):
			out[key] = s
	return out


func save() -> void:
	SaveManager.request_save(profile)


# --- Coins -------------------------------------------------------------------

func get_coins() -> int:
	return int(profile["coins"])


func add_coins(amount: int) -> void:
	if amount == 0:
		return
	profile["coins"] = maxi(0, get_coins() + amount)
	if amount > 0:
		profile["stats"]["total_coins"] = int(profile["stats"]["total_coins"]) + amount
	coins_changed.emit(get_coins())
	save()


func spend_coins(amount: int) -> bool:
	if amount > get_coins():
		return false
	profile["coins"] = get_coins() - amount
	coins_changed.emit(get_coins())
	save()
	return true


# --- Meta upgrades -----------------------------------------------------------

func get_meta_level(upgrade_id: String) -> int:
	return int(profile["meta_upgrades"].get(upgrade_id, 0))


func set_meta_level(upgrade_id: String, level: int) -> void:
	profile["meta_upgrades"][upgrade_id] = level
	save()


# --- Chapters ----------------------------------------------------------------

func get_unlocked_chapters() -> Array:
	return profile["unlocked_chapters"]


func is_chapter_unlocked(chapter_id: String) -> bool:
	return chapter_id in get_unlocked_chapters()


func unlock_chapter(chapter_id: String) -> void:
	if is_chapter_unlocked(chapter_id):
		return
	profile["unlocked_chapters"].append(chapter_id)
	save()


func get_chapter_record(chapter_id: String) -> Dictionary:
	return profile["chapter_records"].get(chapter_id, {"best_time": 0.0, "best_kills": 0, "wins": 0})


## Records a finished run. Returns true when a new best time was set.
## Books a finished run and returns true when it set a new record.
##
## `best_time` is the *fastest clear*, not the longest survival: a chapter is
## a set of waves you finish, so a shorter run is a better one. Runs that end
## in death never touch it — you cannot record a best time for a chapter you
## did not beat.
func record_run(chapter_id: String, time_taken: float, kills: int, won: bool, coins_earned: int) -> bool:
	var rec := get_chapter_record(chapter_id)
	var best := float(rec["best_time"])
	var new_best := won and (best <= 0.0 or time_taken < best)
	if new_best:
		rec["best_time"] = time_taken
	rec["best_kills"] = maxi(int(rec["best_kills"]), kills)
	if won:
		rec["wins"] = int(rec["wins"]) + 1
	profile["chapter_records"][chapter_id] = rec
	profile["stats"]["runs"] = int(profile["stats"]["runs"]) + 1
	profile["stats"]["total_kills"] = int(profile["stats"]["total_kills"]) + kills
	profile["stats"]["total_time"] = float(profile["stats"]["total_time"]) + time_taken
	add_coins(coins_earned)
	return new_best


# --- Relics ------------------------------------------------------------------
#
# Two lists: the `inventory` is everything owned, the `bag` is the subset
# carried into the next run. Starting a run *moves* the bag out of the
# inventory, so items in play are genuinely at risk — die and they are gone,
# survive and whatever went unused comes back.

func relic_count(relic_id: String) -> int:
	return int(profile["inventory"].get(relic_id, 0))


func add_relic(relic_id: String, amount: int = 1) -> void:
	profile["inventory"][relic_id] = maxi(0, relic_count(relic_id) + amount)
	if int(profile["inventory"][relic_id]) == 0:
		profile["inventory"].erase(relic_id)
	inventory_changed.emit()
	save()


## Ids currently packed for the next run.
func get_bag() -> Array:
	return (profile["bag"] as Array).duplicate()


## Only ids the player actually owns, capped at BAG_SIZE.
func set_bag(relic_ids: Array) -> void:
	var packed: Array = []
	var used: Dictionary = {}
	for id: String in relic_ids:
		if packed.size() >= BAG_SIZE:
			break
		var taken := int(used.get(id, 0))
		if taken < relic_count(id):
			used[id] = taken + 1
			packed.append(id)
	profile["bag"] = packed
	inventory_changed.emit()
	save()


## Called when a run starts: hands over the bag and takes those items out of
## the inventory, because they are in the field now.
func take_bag() -> Array:
	var taken := get_bag()
	for id: String in taken:
		profile["inventory"][id] = maxi(0, relic_count(id) - 1)
		if int(profile["inventory"][id]) == 0:
			profile["inventory"].erase(id)
	profile["bag"] = []
	inventory_changed.emit()
	save()
	return taken


## Survived: whatever was not used comes home.
func return_unused(relic_ids: Array) -> void:
	for id: String in relic_ids:
		profile["inventory"][id] = relic_count(id) + 1
	inventory_changed.emit()
	save()


# --- Settings ----------------------------------------------------------------

func get_setting(key: String, default: Variant = null) -> Variant:
	return profile["settings"].get(key, default)


func set_setting(key: String, value: Variant) -> void:
	profile["settings"][key] = value
	settings_changed.emit()
	save()
