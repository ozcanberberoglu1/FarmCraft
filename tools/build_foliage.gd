extends SceneTree
## Builds the foliage atlases of the vegetation cards (art/textures/leaves_*):
## - leaves_broad, leaves_fir: the downloaded maps (diff.jpg + alpha.png) combined into
##   RGBA albedo atlases.
## - leaves_spruce: whole spruce branches ("fronds"), leader shoots and needle clumps
##   laid out from the scanned fir twigs, so a few cards make a dense, deep conifer.
## - leaves_cluster: leafy twigs laid out from single scanned leaves (leaves_island)
##   for the broadleaf crowns and bushes.
## Transparent pixels get the average leaf color so mipmaps don't bleed dark fringes.
## The composed atlases are laid out by fixed seeds, so a rebuild gives the same picture.
## Run: godot --headless -s res://tools/build_foliage.gd [-- --only=sets,spruce,cluster]

const SETS := ["leaves_broad", "leaves_fir"]
const SIZE := 2048

## Fir twig sprays in leaves_fir_albedo.png (UV): stem end at the bottom of each.
## 0, 1 big sprays with side shoots; 2 small spray; 3 single shoot (a leader's tip).
const FIR_SPRAYS: Array[Rect2] = [Rect2(0.303, 0.397, 0.345, 0.381), Rect2(0.631, 0.449, 0.329, 0.384),
		Rect2(0.49, 0.257, 0.144, 0.146), Rect2(0.536, 0.096, 0.056, 0.136)]
## Where the fir atlas has a stick next to spray 1 (cut out before sampling).
const FIR_STICK := Rect2(0.88, 0.7, 0.12, 0.3)
## Single leaves in leaves_island/src (UV): [rect, petiole end, tip].
const LEAVES := [
	[Rect2(0.016, 0.02, 0.13, 0.491), Vector2(0.056, 0.51), Vector2(0.089, 0.02)],
	[Rect2(0.164, 0.02, 0.173, 0.372), Vector2(0.274, 0.392), Vector2(0.275, 0.02)],
	[Rect2(0.693, 0.02, 0.123, 0.394), Vector2(0.752, 0.414), Vector2(0.701, 0.02)],
	[Rect2(0.36, 0.03, 0.123, 0.331), Vector2(0.412, 0.361), Vector2(0.399, 0.03)],
	[Rect2(0.517, 0.049, 0.133, 0.314), Vector2(0.597, 0.363), Vector2(0.601, 0.049)],
	[Rect2(0.216, 0.576, 0.139, 0.424), Vector2(0.319, 0.999), Vector2(0.281, 0.576)],
	[Rect2(0.422, 0.602, 0.14, 0.398), Vector2(0.497, 0.999), Vector2(0.504, 0.603)],
	[Rect2(0.017, 0.629, 0.165, 0.371), Vector2(0.073, 0.999), Vector2(0.083, 0.629)],
]
## The scanned leaves are yellowish; each is recoloured to one of these summer greens
## (multipliers on the scan, varied per leaf).
const LEAF_TINTS: Array[Color] = [Color(0.8, 0.93, 1.2), Color(0.72, 0.88, 1.05), Color(0.86, 0.95, 1.05),
		Color(0.76, 0.9, 1.3)]
const STEM_COLOR := Color(0.3, 0.24, 0.17)
const TWIG_COLOR := Color(0.36, 0.3, 0.22)


func _initialize() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	if only == "" or "sets" in only:
		for set_name in SETS:
			_build(set_name)
	if only == "" or "spruce" in only:
		_build_spruce()
	if only == "" or "cluster" in only:
		_build_clusters()
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


# --- Composing ----------------------------------------------------------------------

## A source picture: albedo (RGBA) and tangent-space normal map at a few sizes, so a
## piece drawn small is sampled from a matching size (no aliasing).
class Source:
	var albedo: Array[Image] = []
	var normal: Array[Image] = []

	func _init(a: Image, n: Image) -> void:
		a.convert(Image.FORMAT_RGBA8)
		n.convert(Image.FORMAT_RGB8)
		if n.get_size() != a.get_size():
			n.resize(a.get_width(), a.get_height(), Image.INTERPOLATE_LANCZOS)
		albedo.append(a)
		normal.append(n)
		for i in 3:
			var a2: Image = albedo[i].duplicate()
			a2.resize(a2.get_width() / 2, a2.get_height() / 2, Image.INTERPOLATE_LANCZOS)
			albedo.append(a2)
			var n2: Image = normal[i].duplicate()
			n2.resize(n2.get_width() / 2, n2.get_height() / 2, Image.INTERPOLATE_LANCZOS)
			normal.append(n2)


## The atlas being drawn: straight colour + coverage, and tangent-space normals.
class Canvas:
	var size: int
	var col := PackedColorArray()
	var nor := PackedColorArray()

	func _init(s: int) -> void:
		size = s
		col.resize(s * s)
		col.fill(Color(0, 0, 0, 0))
		nor.resize(s * s)
		nor.fill(Color(0, 0, 1, 0))


## Draws a piece of `src` (its `rect`, in UV) so that its point `anchor` (UV) lands on
## `at` (pixels) and its direction from anchor to `toward` (UV) points along `angle`
## (radians, 0 = up, clockwise), `length` pixels long; `mirror` flips it across that
## axis. `tint` multiplies the colour. Only pixels inside `clip` are touched.
func _place(cv: Canvas, src: Source, rect: Rect2, anchor: Vector2, toward: Vector2, at: Vector2,
		angle: float, length: float, mirror: bool, tint: Color, clip: Rect2i) -> void:
	var full := Vector2(src.albedo[0].get_size())
	var axis_px := ((toward - anchor) * full)
	var src_len := axis_px.length()
	# The piece's own axis (anchor -> toward) is turned to "up" first.
	var own := atan2(axis_px.x, -axis_px.y) * (-1.0 if mirror else 1.0)
	var s := length / src_len
	var level := clampi(floori(log(1.0 / maxf(s, 0.001)) / log(2.0)), 0, src.albedo.size() - 1)
	var img: Image = src.albedo[level]
	var nimg: Image = src.normal[level]
	var lvl_scale := 1.0 / float(1 << level)
	var iw := img.get_width()
	var ih := img.get_height()
	var r0 := Rect2(rect.position * full * lvl_scale, rect.size * full * lvl_scale)
	var anc := anchor * full * lvl_scale
	var k := s / lvl_scale
	# Total turn from source pixels to canvas pixels.
	var turn := angle - own
	var c := cos(turn)
	var sn := sin(turn)
	var m := -1.0 if mirror else 1.0
	# Canvas bounding box of the rect's corners.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner in [r0.position, Vector2(r0.end.x, r0.position.y), r0.end, Vector2(r0.position.x, r0.end.y)]:
		var d: Vector2 = (corner - anc) * k
		d.x *= m
		var p := at + Vector2(d.x * c - d.y * sn, d.x * sn + d.y * c)
		lo = lo.min(p)
		hi = hi.max(p)
	var x0 := maxi(int(floor(lo.x)), clip.position.x)
	var y0 := maxi(int(floor(lo.y)), clip.position.y)
	var x1 := mini(int(ceil(hi.x)), clip.end.x - 1)
	var y1 := mini(int(ceil(hi.y)), clip.end.y - 1)
	var inv_k := 1.0 / k
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := (x + 0.5 - at.x) * inv_k
			var dy := (y + 0.5 - at.y) * inv_k
			var u := (dx * c + dy * sn) * m + anc.x - 0.5
			var v := -dx * sn + dy * c + anc.y - 0.5
			if u < r0.position.x or v < r0.position.y or u > r0.end.x - 1.0 or v > r0.end.y - 1.0:
				continue
			var ui := int(u)
			var vi := int(v)
			var fu := u - ui
			var fv := v - vi
			var ui1 := mini(ui + 1, iw - 1)
			var vi1 := mini(vi + 1, ih - 1)
			var p00 := img.get_pixel(ui, vi)
			var p10 := img.get_pixel(ui1, vi)
			var p01 := img.get_pixel(ui, vi1)
			var p11 := img.get_pixel(ui1, vi1)
			var a := lerpf(lerpf(p00.a, p10.a, fu), lerpf(p01.a, p11.a, fu), fv)
			if a < 0.04:
				continue
			var sc := p00.lerp(p10, fu).lerp(p01.lerp(p11, fu), fv)
			var n0 := nimg.get_pixel(ui, vi).lerp(nimg.get_pixel(ui1, vi), fu).lerp(
					nimg.get_pixel(ui, vi1).lerp(nimg.get_pixel(ui1, vi1), fu), fv)
			# Tangent-space normal (OpenGL: y up) turned with the piece.
			var nx := (n0.r * 2.0 - 1.0) * m
			var ny := -(n0.g * 2.0 - 1.0)
			var tx := nx * c - ny * sn
			var ty := nx * sn + ny * c
			_blend(cv, y * cv.size + x, Color(sc.r * tint.r, sc.g * tint.g, sc.b * tint.b, a),
					Color(tx, -ty, n0.b * 2.0 - 1.0))


## Straight-alpha "over" of a colour and normal onto the canvas.
func _blend(cv: Canvas, i: int, src: Color, n: Color) -> void:
	var dst := cv.col[i]
	var a := src.a + dst.a * (1.0 - src.a)
	var w := src.a / maxf(a, 0.0001)
	cv.col[i] = Color(lerpf(dst.r, src.r, w), lerpf(dst.g, src.g, w), lerpf(dst.b, src.b, w), a)
	var dn := cv.nor[i]
	cv.nor[i] = Color(lerpf(dn.r, n.r, w), lerpf(dn.g, n.g, w), lerpf(dn.b, n.b, w), a)


## A stem: a round, tapering line from `a` to `b` (pixels), `w0` to `w1` wide.
func _stem(cv: Canvas, a: Vector2, b: Vector2, w0: float, w1: float, color: Color, clip: Rect2i) -> void:
	var lo := a.min(b) - Vector2.ONE * (maxf(w0, w1) + 2.0)
	var hi := a.max(b) + Vector2.ONE * (maxf(w0, w1) + 2.0)
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	var side := Vector2(-ab.y, ab.x).normalized()
	for y in range(maxi(int(lo.y), clip.position.y), mini(int(hi.y), clip.end.y - 1) + 1):
		for x in range(maxi(int(lo.x), clip.position.x), mini(int(hi.x), clip.end.x - 1) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			var half := lerpf(w0, w1, t) * 0.5
			var off := (p - (a + ab * t)).dot(side)
			var cover := clampf(half - absf(off) + 0.5, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var across := clampf(off / maxf(half, 0.5), -1.0, 1.0)
			var shade := 1.0 - 0.35 * across * across
			var nx := side.x * across * 0.8
			var ny := side.y * across * 0.8
			_blend(cv, y * cv.size + x, Color(color.r * shade, color.g * shade, color.b * shade, cover),
					Color(nx, -ny, sqrt(maxf(0.0, 1.0 - nx * nx - ny * ny))))


## Writes the canvas out: transparent texels take the average colour (no dark mip
## fringes), normals are renormalised (flat where there is nothing).
func _save(cv: Canvas, dir: String, set_name: String) -> void:
	var sum := Color(0, 0, 0, 0)
	var count := 0
	for i in range(0, cv.col.size(), 7):
		if cv.col[i].a > 0.9:
			sum += cv.col[i]
			count += 1
	var avg := sum / maxf(count, 1.0)
	var alb := PackedByteArray()
	alb.resize(cv.col.size() * 4)
	var nrm := PackedByteArray()
	nrm.resize(cv.col.size() * 3)
	for i in cv.col.size():
		var c := cv.col[i]
		var a := c.a
		if a < 0.5:
			c = avg
		alb[i * 4] = clampi(roundi(c.r * 255.0), 0, 255)
		alb[i * 4 + 1] = clampi(roundi(c.g * 255.0), 0, 255)
		alb[i * 4 + 2] = clampi(roundi(c.b * 255.0), 0, 255)
		alb[i * 4 + 3] = clampi(roundi(a * 255.0), 0, 255)
		var n := Vector3(0, 0, 1)
		if a >= 0.5:
			var cn := cv.nor[i]
			n = Vector3(cn.r, cn.g, maxf(cn.b, 0.05)).normalized()
		nrm[i * 3] = clampi(roundi((n.x * 0.5 + 0.5) * 255.0), 0, 255)
		nrm[i * 3 + 1] = clampi(roundi((n.y * 0.5 + 0.5) * 255.0), 0, 255)
		nrm[i * 3 + 2] = clampi(roundi((n.z * 0.5 + 0.5) * 255.0), 0, 255)
	var path := ProjectSettings.globalize_path("res://art/textures/%s/" % dir)
	DirAccess.make_dir_recursive_absolute(path)
	Image.create_from_data(cv.size, cv.size, false, Image.FORMAT_RGBA8, alb).save_png(path + "%s_albedo.png" % set_name)
	Image.create_from_data(cv.size, cv.size, false, Image.FORMAT_RGB8, nrm).save_jpg(path + "%s_nor.jpg" % set_name, 0.92)
	print("built %s (avg colour %s)" % [set_name, avg])


# --- Spruce -------------------------------------------------------------------------

## Layout of leaves_spruce (pixels of the 2048 atlas); NatureModels reads the same cells.
## Three branch fronds (stem end at the bottom middle, tip at the top), a leader shoot
## (the top of the tree) and two round needle clumps (seen end-on, centred).
const SPRUCE_FRONDS: Array[Rect2i] = [Rect2i(0, 0, 1024, 1024), Rect2i(1024, 0, 1024, 1024), Rect2i(0, 1024, 1024, 1024)]
const SPRUCE_LEADER := Rect2i(1024, 1024, 512, 1024)
const SPRUCE_CLUMPS: Array[Rect2i] = [Rect2i(1536, 1024, 512, 512), Rect2i(1536, 1536, 512, 512)]


func _build_spruce() -> void:
	var dir := "res://art/textures/leaves_fir/"
	var a := Image.load_from_file(ProjectSettings.globalize_path(dir + "leaves_fir_albedo.png"))
	var n := Image.load_from_file(ProjectSettings.globalize_path(dir + "leaves_fir_nor.jpg"))
	a.convert(Image.FORMAT_RGBA8)
	# Cut the stick lying next to spray 1.
	var stick := Rect2i(Vector2i(FIR_STICK.position * Vector2(a.get_size())), Vector2i(FIR_STICK.size * Vector2(a.get_size())))
	for y in range(stick.position.y, stick.end.y):
		for x in range(stick.position.x, stick.end.x):
			var c := a.get_pixel(x, y)
			c.a = 0.0
			a.set_pixel(x, y, c)
	var src := Source.new(a, n)
	var bases: Array[Vector2] = []
	for r in FIR_SPRAYS:
		bases.append(_stem_end(a, r))
	var cv := Canvas.new(SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for i in SPRUCE_FRONDS.size():
		_frond(cv, src, bases, SPRUCE_FRONDS[i], rng, i)
	_leader(cv, src, bases, SPRUCE_LEADER, rng)
	for r in SPRUCE_CLUMPS:
		_clump(cv, src, bases, r, rng)
	_save(cv, "leaves_spruce", "leaves_spruce")


## Bottom-most opaque point of a spray (UV): where its stem ends.
func _stem_end(img: Image, r: Rect2) -> Vector2:
	var sz := Vector2(img.get_size())
	var x0 := int(r.position.x * sz.x)
	var x1 := int(r.end.x * sz.x)
	for y in range(int(r.end.y * sz.y) - 1, int(r.position.y * sz.y), -1):
		var sum := 0.0
		var cnt := 0
		for x in range(x0, x1):
			if img.get_pixel(x, y).a > 0.5:
				sum += x
				cnt += 1
		if cnt > 0:
			return Vector2((sum / cnt + 0.5) / sz.x, (y + 0.5) / sz.y)
	return Vector2(r.get_center().x, r.end.y)


## Draws fir spray `i` with its stem end at `at`, pointing along `angle`.
func _spray(cv: Canvas, src: Source, bases: Array[Vector2], i: int, at: Vector2, angle: float,
		length: float, mirror: bool, shade: float, clip: Rect2i) -> void:
	var r := FIR_SPRAYS[i]
	var base := bases[i]
	var top := Vector2(base.x, r.position.y)
	_place(cv, src, r, base, top, at, angle, length, mirror, Color(shade, shade, shade), clip)


## One spruce branch: a gently curved stem with side sprays angled towards its tip,
## longest a third of the way out. Sprays underneath are darker (self-shadow), the
## branch is bare near the trunk where a real one sheds its needles in the shade.
func _frond(cv: Canvas, src: Source, bases: Array[Vector2], cell: Rect2i, rng: RandomNumberGenerator, variant: int) -> void:
	var s := float(cell.size.x)
	var b := Vector2(cell.position) + Vector2(s * 0.5, s * 0.985)
	var t_end := Vector2(cell.position) + Vector2(s * (0.5 + rng.randf_range(-0.04, 0.04)), s * 0.04)
	var bend := rng.randf_range(-0.05, 0.05) * s
	var stem_at := func(t: float) -> Vector2:
		var p: Vector2 = b.lerp(t_end, t)
		return p + Vector2(bend * sin(PI * t), 0.0)
	var stem_dir := func(t: float) -> float:
		var d: Vector2 = stem_at.call(minf(t + 0.02, 1.0)) - stem_at.call(maxf(t - 0.02, 0.0))
		return atan2(d.x, -d.y)
	var count := 13 + variant * 2
	# Back layer: wide, dark sprays (the shaded underside of the branch).
	for k in count:
		var t := 0.14 + 0.76 * (k + rng.randf_range(0.0, 0.6)) / count
		var side := 1.0 if k % 2 == 0 else -1.0
		var reach := lerpf(0.36, 0.14, t) * minf(1.0, 0.55 + t * 2.2) * rng.randf_range(0.85, 1.1)
		var ang: float = stem_dir.call(t) + side * deg_to_rad(lerpf(66.0, 40.0, t) + rng.randf_range(-6.0, 6.0))
		_spray(cv, src, bases, rng.randi() % 2, stem_at.call(t), ang, reach * s, side < 0.0,
				rng.randf_range(0.5, 0.62), cell)
	_stem(cv, b, stem_at.call(0.95), s * 0.012, s * 0.004, STEM_COLOR, cell)
	# Main layer.
	for k in count:
		var t := 0.12 + 0.8 * (k + rng.randf_range(0.0, 0.7)) / count
		var side := -1.0 if k % 2 == 0 else 1.0
		var reach := lerpf(0.4, 0.15, t) * minf(1.0, 0.5 + t * 2.4) * rng.randf_range(0.85, 1.12)
		var ang: float = stem_dir.call(t) + side * deg_to_rad(lerpf(58.0, 34.0, t) + rng.randf_range(-7.0, 7.0))
		var kind := rng.randi() % 2 if rng.randf() < 0.8 else 2
		_spray(cv, src, bases, kind, stem_at.call(t), ang, reach * s * (0.75 if kind == 2 else 1.0),
				side < 0.0, rng.randf_range(0.8, 1.02), cell)
	# Along the stem on top, and the tip.
	for k in 4:
		var t := 0.3 + 0.16 * k + rng.randf_range(-0.04, 0.04)
		_spray(cv, src, bases, rng.randi() % 2, stem_at.call(t), stem_dir.call(t) + rng.randf_range(-0.25, 0.25),
				s * rng.randf_range(0.2, 0.26), rng.randf() < 0.5, rng.randf_range(0.85, 1.0), cell)
	_spray(cv, src, bases, rng.randi() % 2, stem_at.call(0.78), stem_dir.call(0.78), s * 0.22, rng.randf() < 0.5, 1.0, cell)


## The tree's top: an upright shoot with short sprays close along it.
func _leader(cv: Canvas, src: Source, bases: Array[Vector2], cell: Rect2i, rng: RandomNumberGenerator) -> void:
	var w := float(cell.size.x)
	var h := float(cell.size.y)
	var b := Vector2(cell.position) + Vector2(w * 0.5, h * 0.99)
	var top := Vector2(cell.position) + Vector2(w * 0.5, h * 0.03)
	for k in 18:
		var t := 0.06 + 0.7 * (k + rng.randf_range(0.0, 0.6)) / 18.0
		var side := 1.0 if k % 2 == 0 else -1.0
		var reach := lerpf(0.3, 0.12, t) * rng.randf_range(0.85, 1.1)
		var ang := side * deg_to_rad(lerpf(42.0, 22.0, t) + rng.randf_range(-6.0, 6.0))
		_spray(cv, src, bases, rng.randi() % 3, b.lerp(top, t), ang, reach * h, side < 0.0,
				rng.randf_range(0.6, 1.0) if k % 3 == 0 else rng.randf_range(0.85, 1.02), cell)
	_stem(cv, b, b.lerp(top, 0.82), w * 0.02, w * 0.008, STEM_COLOR, cell)
	_spray(cv, src, bases, 3, b.lerp(top, 0.68), 0.0, h * 0.3, false, 1.0, cell)


## A round mass of needles, as a branch seen end-on (fills the crown near the trunk).
func _clump(cv: Canvas, src: Source, bases: Array[Vector2], cell: Rect2i, rng: RandomNumberGenerator) -> void:
	var s := float(cell.size.x)
	var c := Vector2(cell.position) + Vector2(s, s) * 0.5
	for layer in 2:
		var count := 11 if layer == 0 else 9
		for k in count:
			var ang := TAU * (k + rng.randf_range(0.0, 0.5)) / count + layer * 0.3
			var at := c + Vector2(sin(ang), -cos(ang)) * s * rng.randf_range(0.02, 0.1)
			_spray(cv, src, bases, rng.randi() % 3, at, ang, s * rng.randf_range(0.36, 0.46), rng.randf() < 0.5,
					rng.randf_range(0.5, 0.62) if layer == 0 else rng.randf_range(0.82, 1.02), cell)


# --- Broadleaf clusters ---------------------------------------------------------------

## Layout of leaves_cluster: four leafy twigs, 1024 px each, stem end at the bottom
## middle of the cell (NatureModels reads the same cells).
const CLUSTER_CELLS: Array[Rect2i] = [Rect2i(0, 0, 1024, 1024), Rect2i(1024, 0, 1024, 1024),
		Rect2i(0, 1024, 1024, 1024), Rect2i(1024, 1024, 1024, 1024)]


func _build_clusters() -> void:
	var dir := "res://art/textures/leaves_island/src/"
	var diff := Image.load_from_file(ProjectSettings.globalize_path(dir + "diff.jpg"))
	var alpha := Image.load_from_file(ProjectSettings.globalize_path(dir + "alpha.png"))
	var nor := Image.load_from_file(ProjectSettings.globalize_path(dir + "nor.jpg"))
	if diff == null or alpha == null or nor == null:
		push_error("missing leaf sources (python3 tools/fetch_textures.py)")
		return
	diff.convert(Image.FORMAT_RGBA8)
	alpha.convert(Image.FORMAT_L8)
	for y in diff.get_height():
		for x in diff.get_width():
			var c := diff.get_pixel(x, y)
			c.a = alpha.get_pixel(x, y).r
			diff.set_pixel(x, y, c)
	var src := Source.new(diff, nor)
	var cv := Canvas.new(SIZE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1893
	for i in CLUSTER_CELLS.size():
		_cluster(cv, src, CLUSTER_CELLS[i], rng, i)
	_save(cv, "leaves_cluster", "leaves_cluster")


## A leafy twig spray: a main twig and side twigs (some forking) fanning up from the
## stem end, leaves in pairs along them and bunched at the tips; the leaves behind are
## darker (self-shadow).
func _cluster(cv: Canvas, src: Source, cell: Rect2i, rng: RandomNumberGenerator, variant: int) -> void:
	var s := float(cell.size.x)
	var lo := Vector2(cell.position) + Vector2.ONE * s * 0.1
	var hi := Vector2(cell.end) - Vector2.ONE * s * 0.1
	var base := Vector2(cell.position) + Vector2(s * 0.5, s * 0.98)
	var twigs := []
	var main_tip := base + Vector2(rng.randf_range(-0.06, 0.06), -rng.randf_range(0.8, 0.86)) * s
	twigs.append([base, main_tip])
	var sides := 5 + variant % 2
	for k in sides:
		var t := 0.2 + 0.5 * (k + rng.randf_range(0.0, 0.8)) / sides
		var from: Vector2 = base.lerp(main_tip, t)
		var side := 1.0 if k % 2 == 0 else -1.0
		var ang := side * deg_to_rad(rng.randf_range(38.0, 68.0))
		var reach := s * rng.randf_range(0.36, 0.48) * (1.0 - t * 0.45)
		var tip := (from + Vector2(sin(ang), -cos(ang)) * reach).clamp(lo, hi)
		twigs.append([from, tip])
		# A fork halfway out.
		if rng.randf() < 0.6:
			var f: Vector2 = from.lerp(tip, rng.randf_range(0.4, 0.6))
			var fa := ang - side * deg_to_rad(rng.randf_range(25.0, 40.0))
			twigs.append([f, (f + Vector2(sin(fa), -cos(fa)) * reach * 0.5).clamp(lo, hi)])
	var leaf_len := s * 0.1
	for layer in 2:
		var shade := 0.55 if layer == 0 else 1.0
		if layer == 1:
			for tw: Array in twigs:
				_stem(cv, tw[0], tw[1], s * 0.008, s * 0.004, TWIG_COLOR, cell)
		for tw: Array in twigs:
			var a: Vector2 = tw[0]
			var b: Vector2 = tw[1]
			var dir := atan2((b - a).x, -(b - a).y)
			var across := Vector2(-(b - a).y, (b - a).x).normalized()
			var n := maxi(int((b - a).length() / (leaf_len * 0.45)), 1)
			for k in n:
				var t := 0.12 + 0.88 * (k + rng.randf_range(0.0, 0.8) + layer * 0.4) / n
				# One to three leaves at each node, at any angle, some off to the side:
				# leaves crowd and overlap as on a real twig, not in neat pairs.
				for j in rng.randi_range(1, 3):
					var side := 1.0 if rng.randf() < 0.5 else -1.0
					var ang: float = dir + side * deg_to_rad(rng.randf_range(15.0, 95.0))
					var at: Vector2 = a.lerp(b, t) + across * rng.randf_range(-0.3, 0.3) * leaf_len
					var size := leaf_len * rng.randf_range(0.65, 1.15) * lerpf(1.0, 0.8, t)
					_leaf(cv, src, at, ang, size, rng, shade, cell)
			# A bunch at the tip.
			for k in 5:
				var ang := dir + deg_to_rad(rng.randf_range(-70.0, 70.0))
				_leaf(cv, src, b + Vector2(rng.randf_range(-0.2, 0.2), rng.randf_range(-0.2, 0.2)) * leaf_len, ang,
						leaf_len * rng.randf_range(0.75, 1.05), rng, shade, cell)


## One scanned leaf, petiole at `at`, pointing along `angle`, `size` pixels long.
func _leaf(cv: Canvas, src: Source, at: Vector2, angle: float, size: float, rng: RandomNumberGenerator,
		shade: float, clip: Rect2i) -> void:
	var leaf: Array = LEAVES[rng.randi() % LEAVES.size()]
	var tint: Color = LEAF_TINTS[rng.randi() % LEAF_TINTS.size()]
	var v := shade * rng.randf_range(0.82, 1.05)
	_place(cv, src, leaf[0], leaf[1], leaf[2], at, angle, size, rng.randf() < 0.5,
			Color(tint.r * v, tint.g * v, tint.b * v), clip)
