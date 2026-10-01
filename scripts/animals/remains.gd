class_name Remains
extends StaticBody3D
## What is left where a farm animal died (taken by wolves, or of its wounds): a dark
## stain soaked into the grass or the straw, the animal's own feathers (with a little
## down), torn tufts of wool or of hair scattered round it, and a few small bloody bits:
## enough to tell what happened, never more. E clears it away (a short job:
## CLEAN_SECONDS of looking at it); left alone it is gone by itself FADE_MINUTES game
## minutes after the farmer first saw it, the next time nobody is looking. The nights he
## sleeps through don't count (Animals moves "seen" on over a skip), so what the wolves
## left in the night is still there in the morning; remains he never sees go
## UNSEEN_MINUTES after the death. Animals keeps the records (saved) and spawns the nodes.
## Record: {species, name, adult, variant, pos [x, y, z], yaw, at (game minutes), flat
## (lies on a building's floor), seed, seen (game minutes he first saw it; not there
## until he has)}.
## The feathers, the down, the wool and the hair are cards cut out of pictures drawn here
## once (_feather_image and the others), bent a little and tinted with the animal's coat.

const GROUP := &"remains"
## Seconds of clearing it away.
const CLEAN_SECONDS := 1.4
## Game minutes from when the farmer first saw it until it is gone by itself (when not
## looked at), and from the death for remains he never saw.
const FADE_MINUTES := 6.0 * 60.0
const UNSEEN_MINUTES := 48.0 * 60.0
## Metres from the camera within which it counts as seen (in view).
const SEEN_RANGE := 60.0
## How far the scatter spreads (metres from its middle) by species.
const SPREAD := {&"chicken": 0.8, &"rooster": 0.85, &"sheep": 0.95, &"cow": 1.1, &"horse": 1.1}
## The stain's size (metres across).
const STAIN := {&"chicken": 0.9, &"rooster": 0.95, &"sheep": 1.3, &"cow": 1.6, &"horse": 1.6}
## Blood: soaked into the ground (dark, brownish at the rim) and on what lies in it.
const BLOOD := Color(0.17, 0.018, 0.012)
const BLOOD_DRY := Color(0.1, 0.02, 0.012)
## Surface keys of the scatter (their materials: _materials).
const FEATHER := &"remains_feather"
const DOWN := &"remains_down"
const WOOL := &"remains_wool"
const HAIR := &"remains_hair"
const BITS := &"remains_bits"
## The cards' shader: the picture's red is its shading, its green where it stays pale
## whatever the coat (a feather's quill and downy base, down), its alpha the cut-out; the
## vertex colour tints the rest. Thin, so a little light comes through.
const CARD_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : filter_linear_mipmap_anisotropic, repeat_disable;
uniform float scissor = 0.4;
uniform float rough = 0.8;
uniform float translucency = 0.2;

void fragment() {
	vec4 t = texture(tex, UV);
	vec3 tint = COLOR.rgb;
	float grey = dot(tint, vec3(0.3, 0.59, 0.11));
	vec3 pale = mix(tint, vec3(grey * 0.45 + 0.42), 0.85);
	ALBEDO = mix(tint, pale, t.g) * t.r;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
	BACKLIGHT = ALBEDO * translucency;
}
"""

var record: Dictionary = {}

var _clean_t := -1.0
var _look_wait := 0.0
var _decal: Decal

## Stain pictures (a few shapes) and the scatter's materials, made once.
static var _stains: Array[ImageTexture] = []
static var _mats: Dictionary = {}
## The pictures drawn off the main thread (prepare: key -> Image, "stains" -> [Image]) and
## that task's id (-1: none started).
static var _images: Dictionary = {}
static var _task := -1


## A node for `rec` (an Animals.remains record), not yet in the tree.
static func create(rec: Dictionary) -> Remains:
	var r := Remains.new()
	r.record = rec
	r.name = "Remains"
	return r


func species() -> StringName:
	return StringName(String(record.get("species", "chicken")))


## The game minutes it has been lying there.
func age_minutes() -> float:
	return GameClock.total_minutes - float(record.get("at", GameClock.total_minutes))


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(GROUP)
	var p: Array = record.get("pos", [0.0, 0.0, 0.0])
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	rotation.y = float(record.get("yaw", 0.0))
	var spread := float(SPREAD.get(species(), 0.7)) * (1.0 if bool(record.get("adult", true)) else 0.55)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(spread * 1.6, 0.35, spread * 1.6)
	cs.shape = box
	cs.position.y = 0.12
	add_child(cs)
	_build(spread)
	_look_wait = randf_range(0.5, 2.0)


# --- Looks -----------------------------------------------------------------------------------

func _build(spread: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(record.get("seed", 1))
	var sp := species()
	var flat := bool(record.get("flat", false))
	# Fallen on something above the ground (a coop's ramp, its doorway): each piece on
	# whatever is under it there, the ramp or the grass beside it.
	var raised := not flat and global_position.y - TerrainData.height(global_position.x, global_position.z) > 0.1
	var space := get_world_3d().direct_space_state
	var inv := global_transform.affine_inverse()
	# Every piece set down on the ground (or the floor) under it.
	var ground := func(local: Vector3) -> Vector3:
		if flat:
			return Vector3(local.x, 0.0, local.z)
		var w := global_transform * Vector3(local.x, 0.0, local.z)
		w.y = TerrainData.height(w.x, w.z)
		if raised:
			var q := PhysicsRayQueryParameters3D.create(w + Vector3(0, global_position.y - w.y + 0.4, 0), w - Vector3(0, 0.05, 0), 1)
			var hit := space.intersect_ray(q)
			if hit:
				w.y = maxf(w.y, (hit["position"] as Vector3).y)
		return inv * w
	var mb := MeshBuilder.new()
	var coat := _coat_color()
	var adult := bool(record.get("adult", true))
	if AnimalTable.is_poultry(sp):
		_feathers(mb, rng, spread, coat, ground, rng.randi_range(70, 90) if adult else 18)
		_down(mb, rng, spread, coat, ground, rng.randi_range(22, 30) if adult else 8)
	elif sp == &"sheep":
		_tufts(mb, rng, spread, coat, ground, WOOL, rng.randi_range(18, 26), Vector2(0.05, 0.14))
	else:
		_tufts(mb, rng, spread, coat, ground, HAIR, rng.randi_range(9, 14), Vector2(0.05, 0.1))
	_bits(mb, rng, spread, ground, 3 if sp in [&"sheep", &"cow", &"horse"] else 2)
	var mi := MeshInstance3D.new()
	mi.name = "Scatter"
	mi.mesh = mb.build(_materials())
	# Small things on the ground: no shadow pass of their own, no GI.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mi)
	_decal = Decal.new()
	_decal.name = "Stain"
	_decal.texture_albedo = stain_texture(rng.randi() % 3)
	var size := float(STAIN.get(sp, 1.0)) * (1.0 if adult else 0.6)
	_decal.size = Vector3(size, 0.8, size)
	_decal.position = Vector3(rng.randf_range(-0.06, 0.06), 0.15, rng.randf_range(-0.06, 0.06))
	_decal.rotation.y = rng.randf() * TAU
	# The ground and the floors only (not the animals or the farmer's tools).
	_decal.cull_mask = 1
	_decal.upper_fade = 0.3
	_decal.lower_fade = 0.3
	_decal.modulate = Color(1, 1, 1, 0.92)
	_decal.albedo_mix = 1.0
	add_child(_decal)


## The coat colour of the animal it was (its variant's), for its feathers, wool or hair:
## a strong colour deepened (the variant tints read brighter on a flat card in the sun than
## on the animal), white and black kept.
func _coat_color() -> Color:
	var list: Array = AnimalModels.VARIANTS.get(species(), [{}])
	var v: Dictionary = list[clampi(int(record.get("variant", 0)), 0, list.size() - 1)]
	var c: Color = v.get("coat", Color(0.9, 0.88, 0.84))
	return Color.from_hsv(c.h, c.s * 0.9, c.v * (1.0 - 0.4 * c.s))


## A point of the scatter: thick in the middle and thinning out, drawn off a little to one
## side (where the struggle went).
static func _scatter_point(rng: RandomNumberGenerator, spread: float, power := 0.75) -> Vector3:
	var a := rng.randf() * TAU
	var r := spread * pow(rng.randf(), power)
	return Vector3(cos(a) * r + r * 0.25, 0.0, sin(a) * r * 0.7)


## Feathers lying about, most flat on the ground (a little curled and cupped), some caught
## upright in the grass; their quills dark where they lay in the blood, their tips a shade
## darker than the rest.
func _feathers(mb: MeshBuilder, rng: RandomNumberGenerator, spread: float, coat: Color, ground: Callable, count: int) -> void:
	for i in count:
		# A third of them in a heap where it happened, the rest strewn about.
		var p := _scatter_point(rng, spread * 0.3, 0.5) if i < count / 3 else _scatter_point(rng, spread)
		var at: Vector3 = ground.call(p)
		if i < count / 3:
			at.y += rng.randf_range(0.0, 0.015)
		# Mostly small body feathers, a few long ones from the wings and the tail.
		var length := rng.randf_range(0.03, 0.06) if rng.randf() < 0.85 else rng.randf_range(0.08, 0.12)
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var up := Vector3.UP
		if rng.randf() < 0.16:
			# Caught standing in the grass.
			var tilt := rng.randf_range(0.6, 1.2)
			dir = (dir * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
			up = (Vector3.UP - dir * dir.y).normalized()
		var c := coat.darkened(rng.randf_range(0.0, 0.18))
		# Matted dark with blood at the base near the middle (the downy base is pale anyway).
		var base_c := c
		if p.length() < spread * 0.25 and rng.randf() < 0.35:
			base_c = c.lerp(BLOOD_DRY, 0.65)
		_card(mb, FEATHER, at + Vector3(0, 0.004, 0), dir, up, length, length * rng.randf_range(0.42, 0.5),
				rng.randf_range(0.0, 0.35), rng.randf_range(0.04, 0.16), base_c, c.darkened(0.1), Rect2(0, 0, 1, 1), 0.0,
				rng.randf_range(-0.12, 0.12))


## Wisps of down among the feathers (some lying, some on end).
func _down(mb: MeshBuilder, rng: RandomNumberGenerator, spread: float, coat: Color, ground: Callable, count: int) -> void:
	for i in count:
		var at: Vector3 = ground.call(_scatter_point(rng, spread * 0.8))
		var size := rng.randf_range(0.02, 0.04)
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), rng.randf_range(0.0, 0.9), sin(yaw)).normalized()
		var up := (Vector3.UP - dir * dir.y).normalized() if dir.y > 0.2 else Vector3.UP
		var c := coat
		_card(mb, DOWN, at + Vector3(0, 0.006, 0), dir, up, size, size, 0.0, 0.1, c, c, Rect2(0, 0, 1, 1))


## Tufts torn out of a fleece (or a hide's hair) strewn about: each a domed card lying on
## the ground with a wisp across it, some matted with blood.
func _tufts(mb: MeshBuilder, rng: RandomNumberGenerator, spread: float, coat: Color, ground: Callable,
		key: StringName, count: int, size: Vector2) -> void:
	for i in count:
		var p := _scatter_point(rng, spread, 0.6)
		var at: Vector3 = ground.call(p)
		var s := rng.randf_range(size.x, size.y)
		# Weathered on the outside: wool a dirty cream, hair darker than the coat looks.
		var c := (coat * Color(0.8, 0.77, 0.7) if key == WOOL else coat.darkened(0.3)).darkened(rng.randf_range(0.0, 0.14))
		if p.length() < spread * 0.35 and rng.randf() < 0.3:
			c = c.lerp(BLOOD_DRY, 0.55)
		var yaw := rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var long := 1.0 if key == WOOL else 1.7
		var up := Vector3.UP
		if rng.randf() < 0.3 and not bool(record.get("flat", false)):
			# Caught up on the grass, tipped.
			at.y += rng.randf_range(0.04, 0.16)
			up = Vector3(rng.randf_range(-0.6, 0.6), 1.0, rng.randf_range(-0.6, 0.6)).normalized()
			dir = (dir - up * dir.dot(up)).normalized()
		_card(mb, key, at + Vector3(0, 0.005, 0), dir, up, s * long, s, 0.25, -0.35, c.darkened(0.06), c,
				Rect2(0, 0, 1, 1), s * 0.18)
		# A second, smaller one on top, turned, for some body.
		var yaw2 := yaw + rng.randf_range(0.6, 2.4)
		var dir2 := Vector3(cos(yaw2), 0.08, sin(yaw2)).normalized()
		_card(mb, key, at + Vector3(0, s * 0.12, 0), dir2, Vector3.UP, s * 0.75 * long, s * 0.7, 0.2, -0.3, c, c.lightened(0.05),
				Rect2(0, 0, 1, 1), s * 0.1)


## A few small, dark, wet bits near the middle.
func _bits(mb: MeshBuilder, rng: RandomNumberGenerator, spread: float, ground: Callable, count: int) -> void:
	for i in rng.randi_range(1, count):
		var at: Vector3 = ground.call(_scatter_point(rng, spread * 0.4))
		var rad := rng.randf_range(0.006, 0.012) * (1.6 if spread > 0.8 else 1.0)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.5, 0.45, 1.0))
		mb.blob(BITS, Transform3D(b, at + Vector3(0, rad * 0.3, 0)), rad, 1, BLOOD.lerp(Color(0.3, 0.05, 0.04), rng.randf()),
				0.7, 6.0, rng.randi())


## A card of picture `uv` (V from the base, 1, to the tip, 0) from `base` along `dir`
## (`up` its face's normal): `length` by `width`, its tip curled up by `curl` of its
## length, cupped (its edges raised: `cup` of its width; a dome when negative), lifted
## `lift` off the ground in the middle. `base_c` at its base, `tip_c` at its tip.
func _card(mb: MeshBuilder, key: StringName, base: Vector3, dir: Vector3, up: Vector3, length: float, width: float,
		curl: float, cup: float, base_c: Color, tip_c: Color, uv: Rect2, lift := 0.0, bend := 0.0) -> void:
	var side := dir.cross(up).normalized()
	const NU := 3
	const NV := 4
	var pts: Array[Vector3] = []
	var cols: Array[Color] = []
	var uvs: Array[Vector2] = []
	for j in NV + 1:
		var v := float(j) / NV
		for i in NU + 1:
			var u := float(i) / NU
			var x := (u - 0.5) * 2.0
			var h := curl * length * v * v + cup * width * x * x + lift * (1.0 - x * x) * sin(PI * v)
			pts.append(base + dir * (length * v) + side * (width * (u - 0.5) + bend * length * v * v) + up * h)
			cols.append(base_c.lerp(tip_c, v))
			uvs.append(Vector2(uv.position.x + uv.size.x * u, uv.end.y - uv.size.y * v))
	# Normals from the bent surface (its cup and curl catch the light unevenly).
	var normals: Array[Vector3] = []
	for j in NV + 1:
		for i in NU + 1:
			var k := j * (NU + 1) + i
			var du := pts[k + 1] - pts[k] if i < NU else pts[k] - pts[k - 1]
			var dv := pts[k + NU + 1] - pts[k] if j < NV else pts[k] - pts[k - NU - 1]
			var n := du.cross(dv).normalized()
			normals.append(n if n.dot(up) >= 0.0 else -n)
	for j in NV:
		for i in NU:
			var a := j * (NU + 1) + i
			var b := a + 1
			var c := a + NU + 2
			var d := a + NU + 1
			mb.tri_n(key, pts[a], pts[b], pts[c], normals[a], normals[b], normals[c], cols[a], cols[b], cols[c], uvs[a], uvs[b], uvs[c])
			mb.tri_n(key, pts[a], pts[c], pts[d], normals[a], normals[c], normals[d], cols[a], cols[c], cols[d], uvs[a], uvs[c], uvs[d])


## The scatter's materials: cut-out cards (feathers, down, wool, hair) seen from both
## sides (CARD_SHADER), tinted by their vertex colours; the bits wet and dark.
static func _materials() -> Dictionary:
	if not _mats.is_empty():
		return _mats
	var pics := _pictures()
	var shader := Shader.new()
	shader.code = CARD_SHADER
	# Key, roughness, alpha cut-off, light let through.
	for spec: Array in [[FEATHER, 0.75, 0.4, 0.2], [DOWN, 0.9, 0.3, 0.35], [WOOL, 0.95, 0.4, 0.2], [HAIR, 0.8, 0.45, 0.1]]:
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter(&"tex", ImageTexture.create_from_image(pics[spec[0]]))
		m.set_shader_parameter(&"rough", float(spec[1]))
		m.set_shader_parameter(&"scissor", float(spec[2]))
		m.set_shader_parameter(&"translucency", float(spec[3]))
		_mats[spec[0]] = m
	var wet := StandardMaterial3D.new()
	wet.vertex_color_use_as_albedo = true
	wet.roughness = 0.28
	wet.metallic_specular = 0.6
	_mats[BITS] = wet
	return _mats


## A body feather pointing up the picture (its quill at the bottom): a slightly curved,
## pale shaft; a broad vane rounded at the tip, a little narrower on one side, of fine
## barbs slanting toward the tip with a split here and there, a fraying edge and a darker
## rim; the lower part soft, downy and pale (green: not tinted by the coat), its barbs
## loose wisps.
static func _feather_image() -> Image:
	const W := 128
	const H := 256
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5101
	var fray := FastNoiseLite.new()
	fray.seed = 17
	fray.frequency = 0.08
	var fibre := FastNoiseLite.new()
	fibre.seed = 18
	fibre.frequency = 0.6
	# Splits in the vane: where along it, on which side.
	var splits: Array[Vector2] = []
	for i in 5:
		splits.append(Vector2(rng.randf_range(0.5, 0.95), -1.0 if rng.randf() < 0.5 else 1.0))
	for y in H:
		var t := 1.0 - float(y) / (H - 1)
		var mid := 0.5 + 0.035 * sin(PI * t)
		var tn := clampf((t - 0.08) / 0.93, 0.0, 1.0)
		# A rounded oblong: broad most of its length, blunt at the tip.
		var round_w := pow(maxf(1.0 - pow(absf(2.0 * tn - 1.0), 2.4), 0.0), 1.0 / 2.4)
		for x in W:
			var u := float(x) / (W - 1)
			var off := u - mid
			var d := absf(off)
			var a := 0.0
			var shade := 0.9
			var pale := 0.0
			var w := (0.4 if off < 0.0 else 0.47) * round_w
			# Barbs: lines slanting toward the tip, their ends ragged.
			var s := t - d * 0.85
			var barb := 0.5 + 0.5 * sin(s * 95.0 * TAU)
			w += (fray.get_noise_1d(s * 400.0) * 0.5 + 0.5) * 0.06 - 0.03
			if tn > 0.0 and d < w:
				var downy := 1.0 - smoothstep(0.3, 0.48, t)
				var firm := lerpf(0.72, 1.0, barb) * smoothstep(w, w - 0.04, d)
				var wisp := smoothstep(0.35, 0.8, barb + fibre.get_noise_2d(x, y) * 0.4) * smoothstep(w, w * 0.5, d)
				a = lerpf(firm, wisp * 0.95, downy)
				shade = lerpf((0.84 + 0.14 * barb) * (1.0 - 0.18 * smoothstep(w * 0.55, w, d)), 0.95, downy)
				pale = downy * 0.9
				for sp: Vector2 in splits:
					if absf(s - sp.x) < 0.005 and d > 0.1 and signf(off) == sp.y:
						a = 0.0
			# The shaft (bare below the vane), pale.
			if d < 0.012 * (1.0 - 0.6 * t) + 0.005 and t < 0.96:
				a = 1.0
				shade = 0.92
				pale = 1.0 - 0.5 * smoothstep(0.4, 0.95, t)
			img.set_pixel(x, y, Color(shade, pale, 0.0, a))
	return img


## A wisp of down: fine curling filaments from a point at the bottom (pale all over).
static func _down_image() -> Image:
	const N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for k in 70:
		var p := Vector2(N * 0.5 + rng.randf_range(-2, 2), N - 4.0)
		var ang := -PI * 0.5 + rng.randf_range(-1.3, 1.3)
		var bend := rng.randf_range(-0.05, 0.05)
		var steps := rng.randi_range(22, 48)
		for st in steps:
			ang += bend
			p += Vector2(cos(ang), sin(ang)) * 0.8
			var xi := int(p.x)
			var yi := int(p.y)
			if xi < 0 or yi < 0 or xi >= N or yi >= N:
				break
			var fade := 1.0 - float(st) / steps
			var cur := img.get_pixel(xi, yi)
			img.set_pixel(xi, yi, Color(1, 1, 0, maxf(cur.a, 0.55 + 0.45 * fade)))
	return img


## A torn tuft of wool: a dense, irregular clump of crimped locks, its edge thinning into
## loose fibres, a few stray ones curling off it.
static func _wool_image() -> Image:
	const N := 128
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var shape := FastNoiseLite.new()
	shape.seed = 404
	shape.frequency = 0.05
	shape.fractal_octaves = 3
	var crimp := FastNoiseLite.new()
	crimp.seed = 405
	crimp.frequency = 0.18
	crimp.fractal_octaves = 3
	crimp.domain_warp_enabled = true
	crimp.domain_warp_amplitude = 6.0
	for y in N:
		for x in N:
			var p := Vector2(x, y) / (N - 1) * 2.0 - Vector2.ONE
			var r := 0.66 + shape.get_noise_2d(x, y) * 0.3
			var c := crimp.get_noise_2d(x, y) * 0.5 + 0.5
			var l := p.length()
			# Dense inside; at the edge only the fibres of the locks hold on.
			var a := 1.0 if l < r - 0.18 else smoothstep(r, r - 0.18, l) * smoothstep(0.25, 0.6, c) * 1.4
			var val := 0.7 + 0.3 * c - 0.12 * smoothstep(r - 0.3, r, l)
			img.set_pixel(x, y, Color(val, 0.0, 0.0, clampf(a, 0.0, 1.0)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 406
	for k in 50:
		var ang := rng.randf() * TAU
		var p := Vector2(N * 0.5, N * 0.5) + Vector2(cos(ang), sin(ang)) * N * 0.3
		for st in rng.randi_range(10, 24):
			ang += rng.randf_range(-0.6, 0.6)
			p += Vector2(cos(ang), sin(ang))
			if p.x < 0 or p.y < 0 or p.x >= N or p.y >= N:
				break
			img.set_pixel(int(p.x), int(p.y), Color(0.88, 0.0, 0.0, 0.9))
	return img


## A tuft of coarse hair: a loose bundle of fine strands, thicker in the middle.
static func _hair_image() -> Image:
	const N := 96
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	for k in 160:
		var x := N * 0.5 + rng.randfn(0.0, N * 0.12)
		var y0 := rng.randf_range(N * 0.05, N * 0.3)
		var y1 := rng.randf_range(N * 0.7, N * 0.95)
		var drift := rng.randf_range(-0.15, 0.15)
		var val := rng.randf_range(0.7, 1.0)
		var y := y0
		while y < y1:
			x += drift + sin(y * 0.2 + k) * 0.08
			var xi := int(x)
			if xi >= 0 and xi < N:
				img.set_pixel(xi, int(y), Color(val, 0.0, 0.0, 0.95))
			y += 1.0
	return img


## A soaked-in stain (one of three shapes): an irregular pool, darker and drier at its
## rim, mottled where it soaked into the ground, a few drops flung off round it.
static func stain_texture(index: int) -> ImageTexture:
	if _stains.is_empty():
		for img: Image in _pictures()["stains"]:
			_stains.append(ImageTexture.create_from_image(img))
	return _stains[clampi(index, 0, _stains.size() - 1)]


## Starts drawing the pictures in the background (a raid is coming, an animal is hurt), so
## the first remains don't hold up a frame (~0.2 s of drawing).
static func prepare() -> void:
	if not _images.is_empty() or _task >= 0:
		return
	_task = WorkerThreadPool.add_task(_draw_pictures, false, "Remains pictures")


## The pictures: drawn by prepare's task (waited for), else here and now.
static func _pictures() -> Dictionary:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	if _images.is_empty():
		_draw_pictures()
	return _images


## Draws every picture (on any thread: nothing here touches the scene).
static func _draw_pictures() -> void:
	var out := {FEATHER: _feather_image(), DOWN: _down_image(), WOOL: _wool_image(), HAIR: _hair_image(), "stains": []}
	for key: Variant in [FEATHER, DOWN, WOOL, HAIR]:
		(out[key] as Image).generate_mipmaps()
	for k in 3:
		(out["stains"] as Array).append(_stain_image(k))
	_images = out


static func _stain_image(k: int) -> Image:
	const N := 160
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7307 + k * 131
	var edge := FastNoiseLite.new()
	edge.seed = 41 + k
	edge.frequency = 0.045
	edge.fractal_octaves = 4
	var mottle := FastNoiseLite.new()
	mottle.seed = 97 + k
	mottle.frequency = 0.12
	var lobes: Array[Vector3] = []
	for i in 5:
		var c := Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
		lobes.append(Vector3(c.x, c.y, rng.randf_range(0.18, 0.42)))
	var drops: Array[Vector3] = []
	for i in 14:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.55, 0.9)
		drops.append(Vector3(cos(a) * r, sin(a) * r, rng.randf_range(0.015, 0.045)))
	for y in N:
		for x in N:
			var p := Vector2(x, y) / float(N - 1) * 2.0 - Vector2.ONE
			var f := -1.0
			for l: Vector3 in lobes:
				f = maxf(f, 1.0 - p.distance_to(Vector2(l.x, l.y)) / l.z)
			f += edge.get_noise_2d(x, y) * 0.35
			var drop := 0.0
			for d: Vector3 in drops:
				drop = maxf(drop, 1.0 - p.distance_to(Vector2(d.x, d.y)) / d.z)
			var a := smoothstep(0.0, 0.18, f)
			a = maxf(a, smoothstep(0.0, 0.35, drop) * 0.85)
			if a <= 0.004:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			# Darker and browner at the rim where it dried first, patchy inside.
			var rim := 1.0 - smoothstep(0.05, 0.4, f)
			var m := mottle.get_noise_2d(x, y) * 0.5 + 0.5
			var col := BLOOD.lerp(BLOOD_DRY, rim * 0.8).darkened(m * 0.25)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a * lerpf(0.78, 0.95, m)))
	img.generate_mipmaps()
	return img


# --- Interaction ------------------------------------------------------------------------------

func interact_title() -> String:
	var who := String(record.get("name", ""))
	return "%s · %s" % [tr("REMAINS_TITLE"), who] if who != "" else tr("REMAINS_TITLE")


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_CLEAN_REMAINS") if _clean_t < 0.0 else ""


## E: cleared away over CLEAN_SECONDS while the farmer keeps looking at it.
func interact(player: Node) -> void:
	if _clean_t >= 0.0:
		return
	_clean_t = 0.0
	Events.action_progress_started.emit(tr("PROGRESS_CLEANING_REMAINS"), CLEAN_SECONDS)
	Audio.play("grass", global_position + Vector3(0, 0.2, 0), -6.0)
	var p := player as Player
	if p:
		p.kick_view(Vector4(0.5, 0.0, 0.0, -0.01))


func _process(delta: float) -> void:
	if _clean_t >= 0.0:
		_update_clean(delta)
		return
	_look_wait -= delta
	if _look_wait > 0.0:
		return
	_look_wait = 2.0
	var seen := _seen()
	if seen and not record.has("seen") and not Game.is_ui_open():
		record["seen"] = GameClock.total_minutes
	# Gone by itself once its time is up, while nobody looks.
	if not seen and _due():
		Animals.clear_remains(self, false)


## Its time is up: FADE_MINUTES since the farmer first saw it (UNSEEN_MINUTES since the
## death when he never has).
func _due() -> bool:
	if record.has("seen"):
		return GameClock.total_minutes - float(record["seen"]) >= FADE_MINUTES
	return age_minutes() >= UNSEEN_MINUTES


func _update_clean(delta: float) -> void:
	if Game.is_paused():
		return
	var player := Game.player as Player
	if player == null or player.target != self:
		_clean_t = -1.0
		Events.action_progress_finished.emit(false)
		return
	_clean_t += delta
	Events.action_progress_updated.emit(clampf(_clean_t / CLEAN_SECONDS, 0.0, 1.0))
	if _clean_t >= CLEAN_SECONDS:
		_clean_t = -1.0
		Events.action_progress_finished.emit(true)
		Audio.play("dig", global_position + Vector3(0, 0.2, 0), -8.0)
		Fx.dirt_burst(global_position + Vector3(0, 0.05, 0), 0.6)
		Animals.clear_remains(self, true)


## Whether the farmer's camera has it in view (close enough to make it out).
func _seen() -> bool:
	if not is_inside_tree():
		return false
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var at := global_position + Vector3(0, 0.1, 0)
	return cam.global_position.distance_to(at) < SEEN_RANGE and cam.is_position_in_frustum(at)
