## Minimal test base. Subclass in tests/test_*.gd, write `func test_xxx()`
## methods, use the assert helpers. Async tests may `await`.
class_name TestCase
extends RefCounted

var failures: Array[String] = []
var checks := 0
var _current := ""


func run_all() -> int:
	var tree: SceneTree = Engine.get_main_loop()
	for m in get_method_list():
		var name: String = m["name"]
		if not name.begins_with("test_"):
			continue
		_current = name
		var before := failures.size()
		before_each()
		await call(name)
		await tree.process_frame
		after_each()
		var status := "PASS" if failures.size() == before else "FAIL"
		print("  %s  %s" % [status, name])
	return failures.size()


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(cond: bool, msg: String = "") -> void:
	checks += 1
	if not cond:
		_fail("expected true" + _suffix(msg))


func assert_false(cond: bool, msg: String = "") -> void:
	checks += 1
	if cond:
		_fail("expected false" + _suffix(msg))


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	checks += 1
	if actual != expected:
		_fail("expected %s, got %s" % [var_to_str(expected), var_to_str(actual)] + _suffix(msg))


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	checks += 1
	if actual == unexpected:
		_fail("expected value different from %s" % var_to_str(unexpected) + _suffix(msg))


func assert_approx(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> void:
	checks += 1
	if absf(actual - expected) > tolerance:
		_fail("expected %f ± %f, got %f" % [expected, tolerance, actual] + _suffix(msg))


func assert_gt(actual: float, threshold: float, msg: String = "") -> void:
	checks += 1
	if not actual > threshold:
		_fail("expected > %s, got %s" % [threshold, actual] + _suffix(msg))


func assert_not_null(value: Variant, msg: String = "") -> void:
	checks += 1
	if value == null:
		_fail("expected non-null" + _suffix(msg))


func _fail(text: String) -> void:
	failures.append("%s: %s" % [_current, text])
	push_error("    ✗ %s: %s" % [_current, text])


func _suffix(msg: String) -> String:
	return "" if msg.is_empty() else " (%s)" % msg
