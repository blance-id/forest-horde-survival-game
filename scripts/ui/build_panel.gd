## "What am I actually running?" — the list the hexagon bar on the HUD cannot
## give you. Every weapon with its level, damage type and burst, every passive
## with its running total, and the hero stats those add up to.
##
## Rebuilt from scratch each time it is shown: it is only ever on screen while
## the game is paused, so there is nothing to gain from diffing rows.
class_name BuildPanel
extends VBoxContainer

const ROW_SEPARATION := 2
## The sheet lives on the cream pause card, so its rows are chocolate.
const NEUTRAL := Color(1, 1, 1)


func show_build(slots: Array[WeaponSystem.Slot], passives: Dictionary, stats: RunStats) -> void:
	for c in get_children():
		c.queue_free()
	_heading("WEAPONS")
	if slots.is_empty():
		_row("None yet", "", NEUTRAL)
	for s in slots:
		var st := s.stats
		var dps := float(st["damage"]) * stats.damage_mult()
		var shots := maxi(1, int(st["projectile_count"]))
		var right := "%d dmg" % roundi(dps)
		if shots > 1:
			right += "  ·  burst %d" % roundi(dps * float(shots))
		_row("%s  ·  Lv %d" % [s.data.display_name, s.level], right, Damage.color(s.data.damage_type).darkened(0.45))
	_heading("SKILLS")
	if passives.is_empty():
		_row("None yet", "", NEUTRAL)
	for u: UpgradeData in passives:
		var level := int(passives[u])
		_row("%s  ·  Lv %d" % [u.display_name, level], u.total_text(level), NEUTRAL)
	_heading("TOTALS")
	_row("Damage", "%+d%%" % roundi((stats.damage_mult() - 1.0) * 100.0), NEUTRAL)
	_row("Attack Speed", "%+d%%" % roundi((stats.attack_speed_mult() - 1.0) * 100.0), NEUTRAL)
	_row("Move Speed", "%.1f m/s" % stats.move_speed(), NEUTRAL)
	_row("Carrying", "%.0f / %.0f kg" % [stats.carried_weight, stats.carry_capacity],
		Color(0.72, 0.32, 0.05) if stats.carried_weight >= stats.carry_capacity else NEUTRAL)
	_row("Max Health", "%d" % roundi(stats.max_hp()), NEUTRAL)
	_row("Armor", "%d blocked" % roundi(stats.armor()), NEUTRAL)
	if stats.regen_per_second() > 0.0:
		_row("Health Regen", "%.1f HP/sec" % stats.regen_per_second(), NEUTRAL)


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"SmallDark"
	label.modulate = Color(0.62, 0.36, 0.06)
	add_child(label)


## Name on the left, number on the right — the shape every stat sheet uses,
## so it can be read at a glance rather than parsed.
func _row(left: String, right: String, tint: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := Label.new()
	name_label.text = left
	name_label.theme_type_variation = &"SmallDark"
	name_label.modulate = tint
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value := Label.new()
	value.text = right
	value.theme_type_variation = &"SmallDark"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	add_child(row)
