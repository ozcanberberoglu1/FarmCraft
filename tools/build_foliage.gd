extends SceneTree
## Combines the downloaded foliage maps (diff.jpg + alpha.png) into RGBA albedo atlases.
## Transparent pixels get the average leaf color so mipmaps don't bleed dark fringes.
## Run: godot --headless -s res://tools/build_foliage.gd

const SETS := ["leaves_broad", "leaves_fir"]
const SIZE := 2048


func _initialize() -> void:
	for set_name in SETS:
		_build(set_name)
	quit()


func _build(set_name: String) -> void:
	var dir := "res://art/textures/%s/" % set_name
	var src := dir + "src/"
	var diff := Image.load_from_file(ProjectSettings.globalize_path(src + "diff.jpg"))
	var alpha := Image.load_from_file(ProjectSettings.globalize_path(src + "alpha.png"))
	if diff == null or alpha == null:
		push_error("missing foliage sources for " + set_name)
		return
	diff.convert(Image.FORMAT_RGBA8)
	alpha.convert(Image.FORMAT_L8)
	if diff.get_width() != SIZE:
		diff.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	if alpha.get_width() != SIZE:
		alpha.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	# Average color of the opaque texels.
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in range(0, SIZE, 4):
		for x in range(0, SIZE, 4):
			if alpha.get_pixel(x, y).r > 0.9:
				sum += diff.get_pixel(x, y)
				n += 1
	var avg := sum / maxf(n, 1.0)
	avg.a = 0.0
	for y in SIZE:
		for x in SIZE:
			var a := alpha.get_pixel(x, y).r
			if a < 0.5:
				diff.set_pixel(x, y, Color(avg.r, avg.g, avg.b, a))
			else:
				var c := diff.get_pixel(x, y)
				c.a = a
				diff.set_pixel(x, y, c)
	var out := dir + "%s_albedo.png" % set_name
	diff.save_png(ProjectSettings.globalize_path(out))
	# The normal map is used as-is; give it an explicit name for the import script.
	var nor := Image.load_from_file(ProjectSettings.globalize_path(src + "nor.jpg"))
	nor.save_jpg(ProjectSettings.globalize_path(dir + "%s_nor.jpg" % set_name), 0.92)
	print("built %s (avg leaf color %s)" % [out, avg])
