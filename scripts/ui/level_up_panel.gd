## Ad-style "pick one of three" level-up cards. Runs while the tree is paused.
class_name LevelUpPanel
extends Control

signal chosen(option: Dictionary)

@onready var _cards: VBoxContainer = %Cards
@onready var _vbox: VBoxContainer = %VBox
@onready var _title: Label = %Title

var _template: Button
var _options: Array[Dictionary] = []
var _locked := false


func _ready() -> void:
	_template = _cards.get_child(0)
	_cards.remove_child(_template)
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_template):
		_template.free()


## Each option: {"weapon": WeaponData, "level": int} or {"upgrade": UpgradeData, "level": int}.
func offer(options: Array[Dictionary], title: String = "LEVEL UP!") -> void:
	_options = options
	_locked = false
	_title.text = title
	for c in _cards.get_children():
		c.queue_free()
	for i in options.size():
		var card: Button = _template.duplicate()
		_fill(card, options[i])
		card.pressed.connect(_on_card_pressed.bind(i))
		_cards.add_child(card)
	visible = true
	_animate_in()


func _fill(card: Button, option: Dictionary) -> void:
	var icon: TextureRect = card.get_node("Margin/HBox/Icon")
	var card_title: Label = card.get_node("Margin/HBox/Text/CardTitle")
	var name_label: Label = card.get_node("Margin/HBox/Text/Name")
	var desc: Label = card.get_node("Margin/HBox/Text/Desc")
	var level := int(option.get("level", 1))
	if option.has("weapon"):
		var w: WeaponData = option["weapon"]
		icon.texture = w.icon
		card_title.text = w.card_title if level == 1 else "UPGRADE!"
		name_label.text = "%s  ·  LV %d" % [w.display_name, level]
		desc.text = w.description if level == 1 else w.level_text(level)
	else:
		var u: UpgradeData = option["upgrade"]
		icon.texture = u.icon
		card_title.text = u.card_title
		name_label.text = "%s  ·  LV %d" % [u.display_name, level]
		desc.text = u.description


func _animate_in() -> void:
	_vbox.pivot_offset = _vbox.size * 0.5
	_vbox.scale = Vector2(0.7, 0.7)
	_vbox.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_vbox, "scale", Vector2.ONE, 0.3)
	tw.tween_property(_vbox, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR)
	var i := 0
	for c: Control in _cards.get_children():
		c.modulate.a = 0.0
		c.position.x += 60.0
		tw.tween_property(c, "modulate:a", 1.0, 0.2).set_delay(0.08 * i)
		tw.tween_property(c, "position:x", c.position.x - 60.0, 0.25).set_delay(0.08 * i)
		i += 1


func _on_card_pressed(index: int) -> void:
	if _locked:
		return
	_locked = true
	var card: Control = _cards.get_child(index)
	card.pivot_offset = card.size * 0.5
	var tw := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tw.tween_property(card, "scale", Vector2(1.08, 1.08), 0.08)
	tw.tween_property(_vbox, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func() -> void:
		visible = false
		chosen.emit(_options[index]))
