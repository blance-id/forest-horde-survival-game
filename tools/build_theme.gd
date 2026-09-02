## Builds the UI theme from the Kenney "UI Pack: Adventure" nine-patches and
## the Lilita One / Nunito fonts, then saves it as a .tres.
## Run with:  godot --headless -s tools/build_theme.gd
extends SceneTree

const OUT := "res://resources/configs/ui_theme.tres"
const UI := "res://assets/ui/adventure/"

const OUTLINE := Color(0.24, 0.13, 0.06)
const TEXT := Color(1.0, 0.97, 0.9)
const TEXT_DIM := Color(0.85, 0.78, 0.66)


func _init() -> void:
	var theme := Theme.new()
	var body := _font("res://assets/fonts/Nunito-Variable.ttf", 700)
	var title := _font("res://assets/fonts/LilitaOne-Regular.ttf", 0)

	theme.default_font = body
	theme.default_font_size = 28

	# --- Labels -------------------------------------------------------------
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_outline_color", "Label", OUTLINE)
	theme.set_constant("outline_size", "Label", 6)
	for v in [["Title", title, 60, 12], ["Heading", title, 42, 9], ["Big", title, 34, 8],
			["Small", body, 22, 5], ["Number", title, 30, 7]]:
		theme.add_type(v[0])
		theme.set_type_variation(v[0], "Label")
		theme.set_font("font", v[0], v[1])
		theme.set_font_size("font_size", v[0], v[2])
		theme.set_constant("outline_size", v[0], v[3])
	theme.add_type("Dim")
	theme.set_type_variation("Dim", "Label")
	theme.set_color("font_color", "Dim", TEXT_DIM)
	theme.set_font_size("font_size", "Dim", 24)
	theme.set_constant("outline_size", "Dim", 4)

	# --- Buttons ------------------------------------------------------------
	_button(theme, "Button", title, 34, "button_brown", "button_grey")
	theme.add_type("PrimaryButton")
	theme.set_type_variation("PrimaryButton", "Button")
	_button(theme, "PrimaryButton", title, 40, "button_red", "button_grey")
	theme.add_type("IconButton")
	theme.set_type_variation("IconButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		theme.set_stylebox(state, "IconButton", StyleBoxEmpty.new())
	# Round icon buttons (pause, close): whole texture stretched, no slicing.
	theme.add_type("RoundButton")
	theme.set_type_variation("RoundButton", "Button")
	theme.set_stylebox("normal", "RoundButton", _nine(UI + "round_brown.png", 0, 0, 14))
	theme.set_stylebox("hover", "RoundButton", _nine(UI + "round_brown.png", 0, 0, 14))
	theme.set_stylebox("pressed", "RoundButton", _nine(UI + "round_brown_dark.png", 0, 0, 14))
	theme.set_stylebox("disabled", "RoundButton", _nine(UI + "round_grey.png", 0, 0, 14))
	theme.set_stylebox("focus", "RoundButton", StyleBoxEmpty.new())
	# Upgrade cards: a big tappable panel.
	theme.add_type("CardButton")
	theme.set_type_variation("CardButton", "Button")
	theme.set_stylebox("normal", "CardButton", _nine(UI + "panel_brown_corners_a.png", 26, 26, 18))
	theme.set_stylebox("hover", "CardButton", _nine(UI + "panel_brown_corners_a.png", 26, 26, 18))
	var card_pressed := _nine(UI + "panel_brown_corners_a.png", 26, 26, 18)
	card_pressed.modulate_color = Color(0.8, 0.8, 0.8)
	theme.set_stylebox("pressed", "CardButton", card_pressed)
	theme.set_stylebox("disabled", "CardButton", _nine(UI + "panel_grey.png", 18, 18, 18))
	theme.set_stylebox("focus", "CardButton", StyleBoxEmpty.new())

	# --- Panels -------------------------------------------------------------
	theme.set_stylebox("panel", "Panel", _nine(UI + "panel_brown.png", 18, 18))
	theme.set_stylebox("panel", "PanelContainer", _nine(UI + "panel_brown.png", 18, 18, 22))
	for v in [["CardPanel", "panel_brown_corners_a.png", 26], ["DarkPanel", "panel_brown_dark.png", 18],
			["GreyPanel", "panel_grey.png", 18], ["BorderPanel", "panel_border_brown.png", 22]]:
		theme.add_type(v[0])
		theme.set_type_variation(v[0], "PanelContainer")
		theme.set_stylebox("panel", v[0], _nine(UI + v[1], v[2], v[2], 22))

	# --- Progress bars ------------------------------------------------------
	for v in [["ProgressBar", "progress_green"], ["HpBar", "progress_red"], ["XpBar", "progress_blue"]]:
		if v[0] != "ProgressBar":
			theme.add_type(v[0])
			theme.set_type_variation(v[0], "ProgressBar")
		theme.set_stylebox("background", v[0], _nine(UI + "progress_transparent.png", 12, 14))
		theme.set_stylebox("fill", v[0], _nine(UI + v[1] + ".png", 12, 14))
		theme.set_font("font", v[0], title)
		theme.set_font_size("font_size", v[0], 22)
		theme.set_color("font_color", v[0], TEXT)
		theme.set_color("font_outline_color", v[0], OUTLINE)
		theme.set_constant("outline_size", v[0], 5)
	# Tiny flat bar that floats under the hero / enemies (nine-patches are too fat).
	theme.add_type("MiniHpBar")
	theme.set_type_variation("MiniHpBar", "ProgressBar")
	theme.set_stylebox("background", "MiniHpBar", _flat(Color(0.12, 0.07, 0.05, 0.85), 4))
	theme.set_stylebox("fill", "MiniHpBar", _flat(Color(0.9, 0.22, 0.2), 4, 2))

	var err := ResourceSaver.save(theme, OUT)
	if err != OK:
		push_error("save failed: %s" % error_string(err))
		quit(1)
		return
	print("theme written to ", OUT)
	quit(0)


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	if weight > 0:
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("weight"): weight}
	return f


func _button(theme: Theme, type: String, font: Font, size: int, tex: String, disabled_tex: String) -> void:
	var normal := _nine(UI + tex + ".png", 14, 14, 18)
	var pressed := _nine(UI + tex + ".png", 14, 14, 18)
	pressed.content_margin_top = 22
	pressed.content_margin_bottom = 14
	pressed.modulate_color = Color(0.82, 0.82, 0.82)
	theme.set_stylebox("normal", type, normal)
	theme.set_stylebox("hover", type, normal)
	theme.set_stylebox("pressed", type, pressed)
	theme.set_stylebox("disabled", type, _nine(UI + disabled_tex + ".png", 14, 14, 18))
	theme.set_stylebox("focus", type, StyleBoxEmpty.new())
	theme.set_font("font", type, font)
	theme.set_font_size("font_size", type, size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(state, type, TEXT)
	theme.set_color("font_disabled_color", type, TEXT_DIM)
	theme.set_color("font_outline_color", type, OUTLINE)
	theme.set_constant("outline_size", type, 7)


func _flat(color: Color, radius: int, margin: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.set_expand_margin_all(-margin)
	return sb


func _nine(path: String, mx: int, my: int, content: int = -1) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = mx
	sb.texture_margin_right = mx
	sb.texture_margin_top = my
	sb.texture_margin_bottom = my
	if content >= 0:
		sb.content_margin_left = content
		sb.content_margin_right = content
		sb.content_margin_top = content * 0.8
		sb.content_margin_bottom = content * 0.8
	return sb
