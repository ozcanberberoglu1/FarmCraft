extends SceneTree
## Packs the photo grass tufts of Poly Haven's grass_medium_01 atlas (downloaded by
## tools/fetch_textures.py into art/textures/grass_cards/src) into the meadow card atlas:
## the green tufts in the top half, the same tufts from the dry colour map in the bottom
## half. Transparent texels get the average tuft colour so mipmaps don't bleed dark
## fringes. Run: godot --headless -s res://tools/build_grass_cards.gd

const DIR := "res://art/textures/grass_cards/"
const W := 2048
const HALF := 512
## [source rect in the 2k atlas, rect in the card atlas's green half]. The card rects
## must match GrassField.TUFTS.
const TUFTS := [
	[Rect2i(400, 1545, 590, 257), Rect2i(8, 8, 572, 249)],
	[Rect2i(1176, 1770, 444, 270), Rect2i(596, 8, 431, 262)],
	[Rect2i(1195, 1548, 470, 204), Rect2i(1043, 8, 456, 198)],
	[Rect2i(48, 1776, 364, 230), Rect2i(8, 278, 353, 223)],
	[Rect2i(490, 1826, 536, 188), Rect2i(377, 278, 520, 182)],
]


func _initialize() -> void:
	var src := ProjectSettings.globalize_path(DIR + "src/")
	var alpha := Image.load_from_file(src + "alpha.png")
	var green := Image.load_from_file(src + "diff.jpg")
	var dry := Image.load_from_file(src + "dry.jpg")
	if alpha == null or green == null or dry == null:
		push_error("missing grass card sources in " + src)
		quit(1)
		return
	alpha.convert(Image.FORMAT_L8)
	var atlas := Image.create(W, HALF * 2, false, Image.FORMAT_RGBA8)
	_pack(atlas, green, alpha, 0)
	_pack(atlas, dry, alpha, HALF)
	var out := DIR + "grass_cards_albedo.png"
	atlas.save_png(ProjectSettings.globalize_path(out))
	print("built %s" % out)
	quit()


## Copies every tuft of `colour` into the atlas half starting at row `top`.
func _pack(atlas: Image, colour: Image, alpha: Image, top: int) -> void:
	colour.convert(Image.FORMAT_RGBA8)
	var tufts: Array[Image] = []
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for t: Array in TUFTS:
		var from: Rect2i = t[0]
		var to: Rect2i = t[1]
		var c := colour.get_region(from)
		var a := alpha.get_region(from)
		c.resize(to.size.x, to.size.y, Image.INTERPOLATE_LANCZOS)
		a.resize(to.size.x, to.size.y, Image.INTERPOLATE_LANCZOS)
		for y in to.size.y:
			for x in to.size.x:
				var col := c.get_pixel(x, y)
				col.a = a.get_pixel(x, y).r
				c.set_pixel(x, y, col)
				if col.a > 0.9:
					sum += col
					n += 1
		tufts.append(c)
	var avg := sum / maxf(n, 1.0)
	avg.a = 0.0
	atlas.fill_rect(Rect2i(0, top, W, HALF), avg)
	for i in tufts.size():
		var c := tufts[i]
		var to: Rect2i = TUFTS[i][1]
		for y in to.size.y:
			for x in to.size.x:
				var col := c.get_pixel(x, y)
				if col.a < 0.5:
					col = Color(avg.r, avg.g, avg.b, col.a)
				atlas.set_pixel(to.position.x + x, top + to.position.y + y, col)
	print("tuft half at row %d: average colour %s" % [top, avg])
