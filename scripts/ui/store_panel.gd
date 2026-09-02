## Store and travel bag in one list.
##
## Two actions per row is the whole design: BUY spends coins to add a relic to
## the inventory, PACK moves one copy into the travel bag. Splitting them into
## separate screens would make the player bounce between them to answer one
## question — "what am I taking in?" — so they live on the same row.
class_name StorePanel
extends Control

signal closed

@onready var _panel: PanelContainer = %Panel
@onready var _rows: VBoxContainer = %Rows
@onready var _bag_label: Label = %BagLabel
@onready var _coins: Label = %CoinsLabel
@onready var _close: Button = %CloseButton


func _ready() -> void:
	visible = false
	_close.pressed.connect(close)


func open() -> void:
	_rebuild()
	visible = true
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.7, 0.7)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3)
	tw.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_LINEAR)
	SoundBank.ui("open")


func close() -> void:
	if not visible:
		return
	SoundBank.ui("close")
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_panel, "scale", Vector2(0.85, 0.85), 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(func() -> void:
		visible = false
		closed.emit())


func _rebuild() -> void:
	var bag := GameState.get_bag()
	_bag_label.text = "TRAVEL BAG  %d / %d" % [bag.size(), GameState.BAG_SIZE]
	_coins.text = str(GameState.get_coins())
	for c in _rows.get_children():
		c.queue_free()
	# Everything the player could hold: what the store sells, plus anything
	# they already own (boss drops are not for sale).
	var listed: Array[RelicData] = RelicCatalog.for_sale()
	for r in RelicCatalog.all():
		if not listed.has(r) and GameState.relic_count(r.id) > 0:
			listed.append(r)
	for relic in listed:
		_rows.add_child(_make_row(relic, bag))


func _make_row(relic: RelicData, bag: Array) -> Control:
	var packed := bag.count(relic.id)
	var owned := GameState.relic_count(relic.id)

	var card := PanelContainer.new()
	card.theme_type_variation = &"DarkPanel"
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	card.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.texture = relic.icon
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	var title := Label.new()
	title.text = relic.display_name if owned == 0 else "%s  ×%d" % [relic.display_name, owned]
	title.theme_type_variation = &"Big"
	text.add_child(title)
	var desc := Label.new()
	desc.text = relic.description
	desc.theme_type_variation = &"Small"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(240, 0)
	text.add_child(desc)
	row.add_child(text)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if packed > 0:
		buttons.add_child(_action("PACKED ×%d" % packed, true, _unpack.bind(relic)))
	elif owned > packed and bag.size() < GameState.BAG_SIZE:
		buttons.add_child(_action("PACK", false, _pack.bind(relic)))
	if relic.price > 0:
		var affordable := GameState.get_coins() >= relic.price
		var buy := _action("BUY %d" % relic.price, false, _buy.bind(relic))
		buy.disabled = not affordable
		buy.modulate.a = 1.0 if affordable else 0.5
		buttons.add_child(buy)
	row.add_child(buttons)
	return card


func _action(text: String, highlighted: bool, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 54)
	b.theme_type_variation = &"PrimaryButton" if highlighted else &"CardButton"
	b.pressed.connect(on_press)
	return b


func _buy(relic: RelicData) -> void:
	if not GameState.spend_coins(relic.price):
		SoundBank.ui("back")
		return
	GameState.add_relic(relic.id)
	SoundBank.sfx("pickup_coin", -4.0, 0.0)
	_rebuild()


func _pack(relic: RelicData) -> void:
	var bag := GameState.get_bag()
	bag.append(relic.id)
	GameState.set_bag(bag)
	SoundBank.ui("confirm")
	_rebuild()


## Takes every copy of this relic back out — one tap to undo, rather than
## making the player count how many are in there.
func _unpack(relic: RelicData) -> void:
	var bag := GameState.get_bag()
	bag = bag.filter(func(id: String) -> bool: return id != relic.id)
	GameState.set_bag(bag)
	SoundBank.ui("back")
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
