extends TestCase

var _stick: TouchJoystick


func before_each() -> void:
	_stick = TouchJoystick.new()
	_stick.radius = 100.0
	_stick.dead_zone = 0.1
	_stick.full_speed_at = 0.7
	_stick.min_speed = 0.35
	# reset() tweens the fade, which needs the node inside the tree.
	(Engine.get_main_loop() as SceneTree).root.add_child(_stick)


func after_each() -> void:
	_stick.get_parent().remove_child(_stick)
	_stick.free()


func _press_at(origin: Vector2) -> void:
	_stick._origin = origin


func test_dead_zone_reads_as_centre() -> void:
	_press_at(Vector2(300, 600))
	_stick.apply_finger(Vector2(305, 600))
	assert_eq(_stick.direction, Vector2.ZERO)
	_stick.apply_finger(Vector2(300, 600))
	assert_eq(_stick.direction, Vector2.ZERO, "finger on the origin")


func test_small_nudge_still_moves_at_min_speed() -> void:
	_press_at(Vector2(300, 600))
	_stick.apply_finger(Vector2(312, 600))
	assert_approx(_stick.direction.length(), 0.35 + (0.12 - 0.1) / 0.6 * 0.65, 0.01)
	assert_approx(_stick.direction.normalized().x, 1.0)


func test_full_speed_before_ring_edge() -> void:
	_press_at(Vector2(300, 600))
	_stick.apply_finger(Vector2(300, 530))
	assert_approx(_stick.direction.length(), 1.0)
	assert_approx(_stick.direction.y, -1.0, 0.001, "screen up")
	_stick.apply_finger(Vector2(300, 510))
	assert_approx(_stick.direction.length(), 1.0, 0.001, "never above 1")


func test_base_follows_finger_past_the_ring() -> void:
	_press_at(Vector2(300, 600))
	_stick.apply_finger(Vector2(500, 600))
	assert_approx(_stick._origin.x, 400.0, 0.001, "origin dragged to keep the finger on the ring")
	assert_approx(_stick._origin.y, 600.0)
	assert_approx(_stick.direction.x, 1.0)
	# Reversing now only needs the finger to travel back across the new ring.
	_stick.apply_finger(Vector2(330, 600))
	assert_approx(_stick.direction.x, -1.0, 0.001, "full speed left without lifting")


func test_reset_clears_state() -> void:
	_press_at(Vector2(100, 100))
	_stick.apply_finger(Vector2(180, 100))
	_stick.is_pressed = true
	assert_gt(_stick.direction.length(), 0.5)
	_stick.reset()
	assert_eq(_stick.direction, Vector2.ZERO)
	assert_false(_stick.is_pressed)
