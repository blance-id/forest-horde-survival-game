## Notch / rounded-corner insets in canvas (design) pixels, so top and bottom
## HUD margins can stay clear of the camera cut-out on edge-to-edge phones.
## Desktop windows report no insets.
class_name SafeArea


static func insets(control: Control) -> Dictionary:
	var result := {"top": 0.0, "bottom": 0.0, "left": 0.0, "right": 0.0}
	if not OS.has_feature("mobile"):
		return result
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var scale := control.get_viewport().get_screen_transform().get_scale()
	if scale.x <= 0.0 or scale.y <= 0.0:
		return result
	result["top"] = maxf(0.0, float(safe.position.y)) / scale.y
	result["bottom"] = maxf(0.0, float(win.y - safe.end.y)) / scale.y
	result["left"] = maxf(0.0, float(safe.position.x)) / scale.x
	result["right"] = maxf(0.0, float(win.x - safe.end.x)) / scale.x
	return result


## Adds the top inset to a MarginContainer's existing top margin.
static func pad_top(container: MarginContainer) -> void:
	var top := float(insets(container)["top"])
	if top > 0.0:
		var base := container.get_theme_constant("margin_top")
		container.add_theme_constant_override("margin_top", base + int(top))
