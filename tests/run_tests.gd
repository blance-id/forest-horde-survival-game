## Headless test runner:  godot --headless -s tests/run_tests.gd
## Discovers tests/test_*.gd (each extends TestCase) and runs every test_* method.
## Exit code is the number of failures (0 = success).
extends SceneTree

const TEST_DIR := "res://tests/"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var scripts := _discover()
	var total_failures := 0
	var total_checks := 0
	print("Running %d test scripts" % scripts.size())
	for path in scripts:
		print(path.get_file())
		var script: GDScript = load(path)
		var case: TestCase = script.new()
		total_failures += await case.run_all()
		total_checks += case.checks
	print("\n%d checks, %d failures" % [total_checks, total_failures])
	quit(mini(total_failures, 255))


func _discover() -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		push_error("Cannot open %s" % TEST_DIR)
		return found
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("test_") and name.ends_with(".gd") and name != "test_case.gd":
			found.append(TEST_DIR + name)
		name = dir.get_next()
	found.sort()
	return found
