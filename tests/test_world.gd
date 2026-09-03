## ArenaBounds and the relic catalog: the two places where a silent mistake
## would be invisible until it shipped.
extends "res://tests/test_case.gd"


func test_circle_bounds_are_round() -> void:
	var b := ArenaBounds.new()
	b.shape = ArenaBounds.Shape.CIRCLE
	b.half = 10.0
	assert_true(b.contains(Vector2(9.0, 0.0)))
	assert_false(b.contains(Vector2(8.0, 8.0)), "the corner of the square is outside a circle")
	assert_approx(b.clamp_point(Vector2(30.0, 0.0)).x, 10.0)


func test_clover_pinches_between_lobes() -> void:
	var b := ArenaBounds.new()
	b.shape = ArenaBounds.Shape.CLOVER
	b.half = 10.0
	# Lobes sit on the axes, the pinches on the diagonals.
	assert_approx(b.radius_at(0.0), 10.0)
	assert_true(b.radius_at(PI * 0.25) < 7.0, "the diagonal is a chokepoint")


func test_random_points_stay_inside() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for shape in [ArenaBounds.Shape.SQUARE, ArenaBounds.Shape.CIRCLE, ArenaBounds.Shape.CLOVER]:
		var b := ArenaBounds.new()
		b.shape = shape
		b.half = 20.0
		for i in 50:
			assert_true(b.contains(b.random_point(rng, 1.0)), "scatter stays in bounds")


func test_every_relic_resolves_by_id() -> void:
	for relic in RelicCatalog.all():
		assert_true(RelicCatalog.get_relic(relic.id) == relic, "id round-trips: " + relic.id)
	assert_true(RelicCatalog.get_relic("does_not_exist") == null)
	assert_eq(RelicCatalog.resolve(["field_kit", "does_not_exist"]).size(), 1,
		"an id from an older save is skipped, not fatal")
