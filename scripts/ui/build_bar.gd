## The hero's current build as a row of hexagon slots: four weapon slots
## (empty ones stay dark) followed by every passive picked up so far. A slot
## that changes level punches so the level-up choice is visibly applied.
class_name BuildBar
extends HBoxContainer

const WEAPON_SLOTS := 4
const WEAPON_SIZE := Vector2(48, 64)
const PASSIVE_SIZE := Vector2(38, 50)
const EMPTY_HEX := preload("res://assets/ui/adventure/hexagon_grey_dark.png")
const WEAPON_HEX := preload("res://assets/ui/adventure/hexagon_brown.png")
const PASSIVE_HEX := preload("res://assets/ui/adventure/hexagon_brown_dark.png")

var _weapon_slots: Array[TextureRect] = []
var _passive_slots: Dictionary = {}  # UpgradeData -> TextureRect
var _levels: Dictionary = {}  # slot node -> level shown


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	for i in WEAPON_SLOTS:
		var slot := _make_slot(WEAPON_SIZE, EMPTY_HEX)
		add_child(slot)
		_weapon_slots.append(slot)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10, 0)
	gap.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(gap)


func set_weapons(slots: Array[WeaponSystem.Slot]) -> void:
	for i in WEAPON_SLOTS:
		var node := _weapon_slots[i]
		if i < slots.size():
			_fill(node, WEAPON_HEX, slots[i].data.icon, slots[i].level)
		else:
			_fill(node, EMPTY_HEX, null, 0)


## `levels` maps UpgradeData -> level; passives appear in pick-up order.
func set_passives(levels: Dictionary) -> void:
	for u: UpgradeData in levels:
		var node: TextureRect = _passive_slots.get(u)
		if node == null:
			node = _make_slot(PASSIVE_SIZE, PASSIVE_HEX)
			add_child(node)
			_passive_slots[u] = node
		_fill(node, PASSIVE_HEX, u.icon, int(levels[u]))


func _make_slot(size: Vector2, hex: Texture2D) -> TextureRect:
	var slot := TextureRect.new()
	slot.custom_minimum_size = size
	slot.texture = hex
	slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.mouse_filter = MOUSE_FILTER_IGNORE
	slot.size_flags_vertical = SIZE_SHRINK_CENTER
	slot.pivot_offset = size * 0.5

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := size.x * 0.17
	icon.offset_left = inset
	icon.offset_top = inset + size.y * 0.04
	icon.offset_right = -inset
	icon.offset_bottom = -inset - size.y * 0.1
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var level := Label.new()
	level.name = "Level"
	level.theme_type_variation = &"Small"
	level.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	level.offset_top = -size.y * 0.42
	level.offset_bottom = -size.y * 0.04
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	level.mouse_filter = MOUSE_FILTER_IGNORE
	slot.add_child(level)
	return slot


func _fill(slot: TextureRect, hex: Texture2D, icon: Texture2D, level: int) -> void:
	slot.texture = hex
	(slot.get_node("Icon") as TextureRect).texture = icon
	(slot.get_node("Level") as Label).text = str(level) if level > 0 else ""
	if int(_levels.get(slot, 0)) != level and level > 0:
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		slot.scale = Vector2(1.5, 1.5)
		tw.tween_property(slot, "scale", Vector2.ONE, 0.4)
	_levels[slot] = level
