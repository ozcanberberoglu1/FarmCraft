extends SceneTree
## Generates the hair-strand and feather card textures (white/grey, tinted in the
## shader) into art/textures/generated.
## Run: godot --headless --path . -s res://tools/gen_card_textures.gd

const OUT := "res://art/textures/generated/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_hair().save_png(ProjectSettings.globalize_path(OUT + "hair_strands.png"))
	_feather().save_png(ProjectSettings.globalize_path(OUT + "feather.png"))
	print("card textures written")
	quit()


## Long hair strands hanging down (v = 0 at the root, 1 at the tip).
func _hair() -> Image:
	var w := 256
	var h := 1024
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for s in 170:
		var x0 := rng.randf_range(4.0, w - 4.0)
		var length := rng.randf_range(0.55, 1.0) * h
		var width := rng.randf_range(0.9, 2.6)
		var bright := rng.randf_range(0.62, 1.0)
		var wave_amp := rng.randf_range(0.0, 5.0)
		var wave_f := rng.randf_range(1.0, 3.0)
		var phase := rng.randf() * TAU
		var drift := rng.randf_range(-10.0, 10.0)
		for y in int(length):
			var t := y / length
			var x := x0 + sin(t * wave_f * TAU + phase) * wave_amp + drift * t * t
			var ww := width * (1.0 - 0.7 * t)
			var alpha := clampf((1.0 - t) * 3.0, 0.0, 1.0)
			for dx in range(int(floor(x - ww - 1.0)), int(ceil(x + ww + 1.0)) + 1):
				if dx < 0 or dx >= w:
					continue
				var cover := clampf(ww + 0.5 - absf(dx - x), 0.0, 1.0) * alpha
				if cover <= 0.0:
					continue
				var old := img.get_pixel(dx, y)
				var c := Color(bright, bright, bright, 1.0)
				var a := old.a + cover * (1.0 - old.a)
				var rgb := (Color(old.r, old.g, old.b) * old.a * (1.0 - cover) + c * cover) / maxf(a, 0.001)
				img.set_pixel(dx, y, Color(rgb.r, rgb.g, rgb.b, a))
	img.generate_mipmaps()
	return img


## A contour feather: shaft down the middle, barbs angled toward the tip.
func _feather() -> Image:
	var w := 256
	var h := 512
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	for y in h:
		var t := float(y) / h
		var half := 0.46 * pow(sin(clampf(t * 1.05, 0.0, 1.0) * PI), 0.55) * (1.0 - 0.15 * t)
		for x in w:
			var u := (float(x) / w - 0.5) * 2.0
			var edge := half - absf(u)
			var jag := noise.get_noise_2d(x * 0.5, y * 3.0) * 0.05
			var inside := edge + jag
			if inside <= 0.0 or t < 0.03:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var shaft := 1.0 - smoothstep(0.012, 0.03, absf(u))
			var barb := 0.5 + 0.5 * sin((y + absf(u) * 140.0) * 0.55)
			var b := lerpf(0.72, 1.0, barb) * (0.9 + 0.1 * noise.get_noise_2d(x, y))
			b = lerpf(b, 0.95, shaft)
			var a := clampf(inside * 40.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(b, b, b, a))
	img.generate_mipmaps()
	return img
