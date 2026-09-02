## Crops and enlarges part of a screenshot (no ImageMagick on the dev box).
## godot --headless -s tools/img_crop.gd -- in.png out.png x y w h [scale]
extends SceneTree


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 6:
		push_error("usage: in.png out.png x y w h [scale]")
		quit(1)
		return
	var img := Image.load_from_file(a[0])
	var region := img.get_region(Rect2i(int(a[2]), int(a[3]), int(a[4]), int(a[5])))
	var s := int(a[6]) if a.size() > 6 else 3
	region.resize(region.get_width() * s, region.get_height() * s, Image.INTERPOLATE_NEAREST)
	region.save_png(a[1])
	print("saved ", a[1])
	quit()
