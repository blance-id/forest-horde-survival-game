## "What am I actually running?" — the list the hexagon bar on the HUD cannot
## give you. Every weapon with its level, damage type and burst, every passive
## with its running total, and the hero stats those add up to.
##
## Rebuilt from scratch each time it is shown: it is only ever on screen while
## the game is paused, so there is nothing to gain from diffing rows.
class_name BuildPanel
extends VBoxContainer

const ROW_SEPARATION := 2


func show_build(slots: Array[WeaponSystem.Slot], passives: Dictionary, stats: RunStats) -> void:
	for c in get_children():
		c.queue_free()
	_heading("WEAPONS")
	if slots.is_empty():
		_row("None yet", "", Color(0.8, 0.76, 0.68))
	for s in slots:
		var st := s.stats
		var dps := float(st["damage"]) * stats.damage_mult()
		var shots := maxi(1, int(st["projectile_count"]))
		var right := "%d dmg" % roundi(dps)
		if shots > 1:
			right += "  ·  burst %d" % roundi(dps * float(shots))
		_row("%s  ·  Lv %d" % [s.data.display_name, s.level], right, Damage.color(s.data.damage_type))
	_heading("SKILLS")
	if passives.is_empty():
		_row("None yet", "", Color(0.8, 0.76, 0.68))
	for u: UpgradeData in passives:
		var level := int(passives[u])
		_row("%s  ·  Lv %d" % [u.display_name, level], u.total_text(level), Color(1.0, 0.96, 0.86))
	_heading("TOTALS")
	_row("Damage", "%+d%%" % roundi((stats.damage_mult() - 1.0) * 100.0), Color(1.0, 0.96, 0.86))
	_row("Attack Speed", "%+d%%" % roundi((stats.attack_speed_mult() - 1.0) * 100.0), Color(1.0, 0.96, 0.86))
	_row("Move Speed", "%.1f m/s" % stats.move_speed(), Color(1.0, 0.96, 0.86))
	_row("Max Health", "%d" % roundi(stats.max_hp()), Color(1.0, 0.96, 0.86))
	_row("Armor", "%d blocked" % roundi(stats.armor()), Color(1.0, 0.96, 0.86))
	if stats.regen_per_second() > 0.0:
		_row("Health Regen", "%.1f HP/sec" % stats.regen_per_second(), Color(1.0, 0.96, 0.86))


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Small"
	label.modulate = Color(1.0, 0.85, 0.4)
	add_child(label)


## Name on the left, number on the right — the shape every stat sheet uses,
## so it can be read at a glance rather than parsed.
func _row(left: String, right: String, tint: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.text = left
	name_label.theme_type_variation = &"Small"
	name_label.modulate = tint
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := Label.new()
	value.text = right
	value.theme_type_variation = &"Small"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	add_child(row)
