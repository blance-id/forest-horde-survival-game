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


func _chapter(path: String) -> ChapterData:
	return load(path) as ChapterData


func test_chapters_end_on_a_boss_wave() -> void:
	for path in ["res://resources/chapters/chapter_01.tres", "res://resources/chapters/chapter_02.tres"]:
		var c := _chapter(path)
		assert_true(c.wave_count() > 0, "%s has waves" % c.id)
		var last := c.wave_count() - 1
		assert_true(c.is_boss_wave(last), "%s ends on a boss wave" % c.id)
		# Only the last wave may end the run, or clearing would finish early.
		for i in last:
			assert_false(c.is_boss_wave(i), "%s wave %d is not a boss wave" % [c.id, i])


func test_boss_waves_contain_a_boss() -> void:
	for path in ["res://resources/chapters/chapter_01.tres", "res://resources/chapters/chapter_02.tres"]:
		var c := _chapter(path)
		var last := c.wave_count() - 1
		var has_boss := false
		for e in c.wave_roster(last):
			if e.is_boss:
				has_boss = true
		assert_true(has_boss, "%s boss wave actually spawns a boss" % c.id)


func test_every_wave_sends_something() -> void:
	for path in ["res://resources/chapters/chapter_01.tres", "res://resources/chapters/chapter_02.tres"]:
		var c := _chapter(path)
		for i in c.wave_count():
			assert_true(c.wave_roster(i).size() > 0, "%s wave %d is not empty" % [c.id, i])
			assert_true(c.wave_interval(i) > 0.0)
			assert_true(c.wave_cap(i) > 0)


func test_demo_enemy_is_never_a_boss() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var c := _chapter("res://resources/chapters/chapter_01.tres")
	for i in 20:
		var e := c.demo_enemy(rng)
		assert_true(e != null and not e.is_boss, "the menu demo never shows a boss")


func test_every_class_can_carry_its_starting_weapon() -> void:
	for path in ["ranger", "bomber", "angel", "cyborg"]:
		var c: CharacterData = load("res://resources/characters/%s.tres" % path)
		assert_true(c.starting_weapon != null, "%s has a starting weapon" % c.id)
		assert_true(c.starting_weapon.weight <= c.carry_capacity,
			"%s can actually carry what it starts with" % c.id)
		assert_eq(c.weapons.size(), 5, "%s has a full weapon set" % c.id)
		assert_true(c.weapons.has(c.starting_weapon), "%s starts with one of its own" % c.id)


func test_a_class_cannot_carry_its_whole_set() -> void:
	# The point of weight is that the hero picks: if every weapon fitted at
	# once there would be no decision to make.
	for path in ["ranger", "bomber", "angel", "cyborg"]:
		var c: CharacterData = load("res://resources/characters/%s.tres" % path)
		var total := 0.0
		for w in c.weapons:
			total += w.weight
		assert_true(total > c.carry_capacity, "%s must choose between its weapons" % c.id)


func test_each_class_covers_every_weapon_kind() -> void:
	for path in ["ranger", "bomber", "angel", "cyborg"]:
		var c: CharacterData = load("res://resources/characters/%s.tres" % path)
		var kinds: Array[int] = []
		for w in c.weapons:
			if not kinds.has(int(w.kind)):
				kinds.append(int(w.kind))
		for kind in [WeaponData.Kind.PROJECTILE, WeaponData.Kind.ORBIT,
				WeaponData.Kind.AURA, WeaponData.Kind.SHIELD]:
			assert_true(kinds.has(int(kind)), "%s offers a %d weapon" % [c.id, int(kind)])


func _boss_of(chapter_path: String) -> EnemyData:
	var c := _chapter(chapter_path)
	for e in c.wave_roster(c.wave_count() - 1):
		if e.is_boss:
			return e
	return null


func test_each_boss_has_its_own_kit() -> void:
	var kits: Array[String] = []
	for path in ["res://resources/chapters/chapter_01.tres", "res://resources/chapters/chapter_02.tres"]:
		var boss := _boss_of(path)
		assert_true(boss != null and not boss.abilities.is_empty(), "the boss does something")
		var kinds: Array[String] = []
		for a: Dictionary in boss.abilities:
			var kind := String(a.get("kind", ""))
			assert_true(kind in ["leap", "summon", "volley", "roar"], "known ability: " + kind)
			assert_true(float(a.get("cooldown", 0.0)) > 0.0, "%s has a cooldown" % kind)
			kinds.append(kind)
		kinds.sort()
		var signature := ",".join(kinds)
		assert_false(kits.has(signature), "bosses do not share a kit: " + signature)
		kits.append(signature)


func test_summons_name_a_real_enemy() -> void:
	for path in ["res://resources/chapters/chapter_01.tres", "res://resources/chapters/chapter_02.tres"]:
		for a: Dictionary in _boss_of(path).abilities:
			if String(a.get("kind", "")) == "summon":
				var minion: EnemyData = a.get("enemy")
				assert_true(minion != null and not minion.is_boss, "summons a real, non-boss enemy")
				assert_true(int(a.get("count", 0)) > 0)


func test_bosses_outclass_their_own_wave() -> void:
	for path in ["res://resources/chapters/chapter_01.tres", "res://resources/chapters/chapter_02.tres"]:
		var c := _chapter(path)
		var boss := _boss_of(path)
		for e in c.wave_roster(c.wave_count() - 1):
			if not e.is_boss:
				assert_true(boss.max_hp > e.max_hp * 4.0, "the boss is not just another body")
