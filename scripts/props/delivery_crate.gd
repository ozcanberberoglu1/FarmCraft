class_name DeliveryCrate
extends StaticBody3D
## The market's delivery crate, set down beside the mailbox the morning an order from the
## catalogue comes (Catalog owns it and keeps what is in it: Catalog.crate): a nailed pine
## shipping crate on two skids, "YEŞİLOVA MARKET" sprayed on its sides through a stencil,
## rope handles at the ends, the order's slip tacked to the lid; under a tarp when it was
## raining that morning. E takes everything that fits into the bag (the lid is prised off
## and set back askew); what doesn't fit waits in it, and the crate is gone once it is
## empty. Local frame: standing on the origin, its long side along X, the front to +Z.

const GROUP := &"delivery_crates"
## Outer measures (m): length, height (lid on), depth.
const SIZE := Vector3(0.74, 0.47, 0.52)
const STENCIL := "res://art/textures/generated/market_stencil.png"
## Fresh pine boards (a warm tint over the rough wood), and the tarp's waxed canvas.
const PINE := Color(0.78, 0.62, 0.4)
const TARP := Color(0.36, 0.39, 0.27)
## Seconds the lid takes to be set askew; the empty crate to be carried off.
const LID_TIME := 0.25
const LEAVE_TIME := 0.45
## Boards' thickness; the lid's.
const T := 0.018
const LID_T := 0.02

var catalog: Catalog
## Set before it enters the tree: under a tarp (it rained that morning); opened before
## (the lid already askew).
var tarp := false
var opened := false

var _lid: Node3D
var _tarp: MeshInstance3D
var _leaving := false

static var _meshes := {}
static var _stencil_mat: StandardMaterial3D


func _ready() -> void:
	# Solid for walking into (layer 1) and a target for the interaction ray (layer 4).
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(GROUP)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	cs.shape = box
	cs.position.y = SIZE.y * 0.5
	add_child(cs)
	var body := _part(mesh("body"))
	body.name = "Body"
	add_child(body)
	# The stencil on the front and the back, between the corner battens.
	for s: float in [1.0, -1.0]:
		var paint := MeshInstance3D.new()
		paint.name = "Stencil"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.56, 0.28)
		paint.mesh = quad
		paint.material_override = _stencil_material()
		paint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		paint.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		paint.layers = 2
		paint.transform = Transform3D(Basis(Vector3.UP, 0.0 if s > 0.0 else PI), Vector3(0.0, 0.035 + (SIZE.y - 0.035 - LID_T) * 0.5, s * (SIZE.z * 0.5 + 0.0015)))
		add_child(paint)
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0.0, SIZE.y - LID_T, 0.0)
	# Moved by a tween every frame, not in physics steps.
	_lid.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_lid)
	_lid.add_child(_part(mesh("lid")))
	if opened:
		_lid.transform = _lid_askew()
	if tarp and not opened:
		_tarp = _part(mesh("tarp"))
		_tarp.name = "Tarp"
		add_child(_tarp)


func _part(m: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	# A prop that comes and goes: no GI voxelization, kept out of the rain-blocker heightfield.
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.layers = 2
	return mi


## The lid prised off and set back on the rim, askew.
func _lid_askew() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, 0.26) * Basis(Vector3.RIGHT, -0.07), Vector3(0.07, SIZE.y - LID_T + 0.012, -0.06))


## Whether the lid was prised off (tests).
func is_open() -> bool:
	return opened


## Under its tarp still (tests).
func has_tarp() -> bool:
	return _tarp != null and is_instance_valid(_tarp) and _tarp.visible


func interact_title() -> String:
	return "" if _leaving else tr("UI_DELIVERY_CRATE")


func interact_prompt(_player: Node) -> String:
	if _leaving or catalog == null or not catalog.has_crate():
		return ""
	return tr("ACTION_OPEN_DELIVERY")


## What waits in it, under the prompt.
func hint_prompt() -> String:
	if _leaving or catalog == null or not catalog.has_crate():
		return ""
	return Relations.gift_text(catalog.crate_items())


## E: everything that fits goes into the bag; the rest waits here.
func interact(_player: Node) -> void:
	if _leaving or catalog == null or not catalog.has_crate():
		return
	var taken := catalog.take_delivery()
	Audio.play("plank", global_position + Vector3(0, SIZE.y, 0), -8.0)
	for id: StringName in taken:
		Game.notify("+%dx %s" % [int(taken[id]), ItemDB.get_item(id).display_name()])
	if _tarp != null and is_instance_valid(_tarp):
		_tarp.visible = false
	if not opened:
		opened = true
		var tw := create_tween()
		tw.tween_property(_lid, "transform", _lid_askew(), LID_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if catalog.has_crate():
		Game.notify(tr("MSG_CATALOG_CRATE_LEFT"), Color(1.0, 0.5, 0.4))
	else:
		leave()


## Empty: off the farm (the errand boy takes the crate back on his next round).
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	collision_layer = 0
	remove_from_group(GROUP)
	var tw := create_tween()
	tw.tween_interval(LID_TIME + 0.15)
	tw.tween_property(self, "scale", Vector3.ONE * 0.02, LEAVE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


# --- Model -----------------------------------------------------------------------------------

## "body" (the crate without its lid), "lid" (lying on the origin) or "tarp".
static func mesh(part: String) -> ArrayMesh:
	if not _meshes.has(part):
		var mb := MeshBuilder.new()
		match part:
			"body":
				_build_body(mb)
			"lid":
				_build_lid(mb)
			_:
				_build_tarp(mb)
		_meshes[part] = mb.build()
	return _meshes[part]


## The market's name in worn black paint (art/textures/generated/market_stencil.png,
## tools/build_market_stencil.py).
static func _stencil_material() -> StandardMaterial3D:
	if _stencil_mat == null:
		_stencil_mat = StandardMaterial3D.new()
		_stencil_mat.albedo_color = Color(0.06, 0.05, 0.045, 0.96)
		_stencil_mat.albedo_texture = load(STENCIL) as Texture2D
		_stencil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_stencil_mat.roughness = 0.95
		_stencil_mat.metallic_specular = 0.1
	return _stencil_mat


static func _build_body(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2107
	var hl := SIZE.x * 0.5
	var hd := SIZE.z * 0.5
	var skid := 0.035
	var top := SIZE.y - LID_T
	var dark := PINE.darkened(0.22)
	# Two skids under it, the floor boards across them.
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"wood", Vector3(sx * (hl - 0.09), skid * 0.5, 0.0), Vector3(0.07, skid, SIZE.z - 0.02), dark, Vector3.ZERO, true)
	for k in 4:
		var z := -hd + T + (k + 0.5) * (SIZE.z - 2.0 * T) / 4.0
		mb.box_at(&"wood", Vector3(0.0, skid + T * 0.5, z), Vector3(SIZE.x - 0.004, T, (SIZE.z - 2.0 * T) / 4.0 - 0.004),
				PINE.darkened(rng.randf_range(0.04, 0.16)), Vector3.ZERO, true)
	# The sides: three boards high, tight but for a hairline between them, each its own shade.
	var wall_h := top - skid
	var board := wall_h / 3.0
	for k in 3:
		var y := skid + (k + 0.5) * board
		for s: float in [-1.0, 1.0]:
			mb.box_at(&"wood", Vector3(0.0, y, s * (hd - T * 0.5)), Vector3(SIZE.x, board - 0.003, T),
					PINE.lightened(rng.randf_range(-0.09, 0.06)), Vector3(rng.randf_range(-0.5, 0.5), 0.0, 0.0), true)
			mb.box_at(&"wood", Vector3(s * (hl - T * 0.5), y, 0.0), Vector3(T, board - 0.003, SIZE.z - 2.0 * T),
					PINE.lightened(rng.randf_range(-0.09, 0.06)), Vector3(0.0, 0.0, rng.randf_range(-0.5, 0.5)), true)
	# Corner battens on the long sides and one down the middle of each end, nailed on.
	var nail := Color(0.2, 0.19, 0.18)
	for s: float in [-1.0, 1.0]:
		for sx: float in [-1.0, 1.0]:
			var c := Vector3(sx * (hl - 0.032), skid + wall_h * 0.5, s * (hd + 0.008))
			mb.box_at(&"wood", c, Vector3(0.064, wall_h, 0.016), dark.lightened(rng.randf_range(0.0, 0.08)))
			for k in 3:
				for nx: float in [-0.016, 0.016]:
					mb.cylinder(&"metal", Transform3D(Basis(Vector3.RIGHT, s * PI * 0.5), c + Vector3(nx, (k - 1) * board + rng.randf_range(-0.012, 0.012), s * 0.008)),
							0.0045, 0.0045, 0.0012, 6, nail)
		var e := Vector3(s * (hl + 0.008), skid + wall_h * 0.5, 0.0)
		mb.box_at(&"wood", e, Vector3(0.016, wall_h, 0.07), dark.lightened(rng.randf_range(0.0, 0.08)))
		# A rope handle through the end, under the top board.
		var pts: Array[Vector3] = []
		var radii: Array[float] = []
		for i in 9:
			var a := PI * float(i) / 8.0
			pts.append(Vector3(s * (hl + 0.016 + sin(a) * 0.04), top - 0.075 - sin(a) * 0.035, -0.1 + (1.0 - cos(a)) * 0.1))
			radii.append(0.008)
		mb.loft(&"cloth", pts, radii, 6, Color(0.66, 0.54, 0.34), true)
		for z: float in [-0.1, 0.1]:
			mb.sphere(&"cloth", Transform3D(Basis(), Vector3(s * (hl + 0.018), top - 0.075, z)), Vector3(0.013, 0.013, 0.013), 6, 4, Color(0.6, 0.48, 0.3))
	# Packing straw up to the rim (it shows once the lid is off).
	mb.box_at(&"straw", Vector3(0.0, top - 0.045, 0.0), Vector3(SIZE.x - 2.0 * T - 0.004, 0.012, SIZE.z - 2.0 * T - 0.004), Color(0.8, 0.68, 0.4))
	for i in 16:
		var tuft := Vector3(rng.randf_range(-hl + 0.07, hl - 0.07), top - 0.036 + rng.randf_range(0.0, 0.012), rng.randf_range(-hd + 0.06, hd - 0.06))
		mb.box_at(&"straw", tuft, Vector3(rng.randf_range(0.09, 0.2), 0.01, rng.randf_range(0.02, 0.045)), Color(0.86, 0.74, 0.44).darkened(rng.randf_range(0.0, 0.15)),
				Vector3(rng.randf_range(-10, 10), rng.randf() * 180.0, rng.randf_range(-6, 6)))


## The lid: four boards along the crate on two cross battens underneath, the order's slip
## tacked on top. Lies on the origin (its underside at y = 0).
static func _build_lid(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4421
	var w := (SIZE.z + 0.012) / 4.0
	for k in 4:
		var z := -(SIZE.z + 0.012) * 0.5 + (k + 0.5) * w
		mb.box_at(&"wood", Vector3(0.0, LID_T * 0.5, z), Vector3(SIZE.x + 0.016, LID_T, w - 0.004), PINE.lightened(rng.randf_range(-0.07, 0.07)),
				Vector3(0.0, rng.randf_range(-0.35, 0.35), 0.0), true)
		for x: float in [-SIZE.x * 0.5 + 0.02, SIZE.x * 0.5 - 0.02]:
			mb.cylinder(&"metal", Transform3D(Basis(), Vector3(x + rng.randf_range(-0.004, 0.004), LID_T, z)), 0.0045, 0.0045, 0.0012, 6, Color(0.2, 0.19, 0.18))
	for x: float in [-SIZE.x * 0.5 + 0.14, SIZE.x * 0.5 - 0.14]:
		mb.box_at(&"wood", Vector3(x, -0.008, 0.0), Vector3(0.05, 0.016, SIZE.z - 2.0 * T - 0.02), PINE.darkened(0.2))
	# The slip: a sheet off the grocer's order pad, a few pencilled lines, a tack.
	var slip := Transform3D(Basis(Vector3.UP, 0.22), Vector3(0.17, LID_T + 0.0012, 0.08))
	mb.box(&"paper", slip, Vector3(0.12, 0.0012, 0.085), Color(0.93, 0.9, 0.8))
	for i in 4:
		mb.box(&"paper", slip * Transform3D(Basis(), Vector3(-0.012 + (i % 2) * 0.008, 0.0009, -0.024 + i * 0.015)),
				Vector3(0.07 - (i % 2) * 0.016, 0.0005, 0.0035), Color(0.25, 0.25, 0.32))
	mb.cylinder(&"metal", slip * Transform3D(Basis(), Vector3(0.0, 0.0006, -0.036)), 0.005, 0.004, 0.003, 8, Color(0.62, 0.14, 0.1))


## A tarp thrown over it against the rain: waxed canvas sagging a little over the lid, its
## skirts hanging in folds down the sides to uneven hems, a cord tied round it.
static func _build_tarp(mb: MeshBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var hl := SIZE.x * 0.5 + 0.022
	var hd := SIZE.z * 0.5 + 0.022
	var top := SIZE.y + 0.01
	# The sheet over the lid: a low tent of four panels to a slack middle.
	var mid := Vector3(0.03, top - 0.006, -0.02)
	var corners: Array[Vector3] = [Vector3(-hl, top, hd), Vector3(hl, top, hd), Vector3(hl, top, -hd), Vector3(-hl, top, -hd)]
	for i in 4:
		mb.tri(&"cloth", corners[i], corners[(i + 1) % 4], mid, TARP.lightened(0.03 * (i % 2)))
	# The skirts: along each side the cloth falls in folds (the hem runs in and out), its
	# hem at uneven heights; a pleat is tucked at every corner.
	var folds := 5
	var rim: Array[Vector3] = []
	var hem: Array[Vector3] = []
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var out := Vector3(a.z - b.z, 0.0, b.x - a.x).normalized()
		for k in folds:
			var t := float(k) / folds
			var p := a.lerp(b, t)
			var corner := k == 0
			var push := 0.035 if corner else (0.075 if k % 2 == 1 else 0.03) + rng.randf_range(-0.01, 0.012)
			var away := out if not corner else Vector3(signf(a.x), 0.0, signf(a.z)).normalized()
			rim.append(p)
			hem.append(p + away * push - Vector3(0.0, rng.randf_range(0.27, 0.36), 0.0))
	var n := rim.size()
	for i in n:
		var j := (i + 1) % n
		var shade := TARP.darkened(0.2) if i % 2 == 0 else TARP.darkened(0.05)
		mb.quad2(&"cloth", hem[i], hem[j], rim[j], rim[i], shade.lightened(rng.randf_range(0.0, 0.05)))
	# The cord round it, a hand's breadth under the lid, knotted at the front.
	var cord := Color(0.72, 0.63, 0.44)
	for i in n:
		var j := (i + 1) % n
		var k := 0.36
		mb.cylinder_between(&"cloth", rim[i].lerp(hem[i], k) * Vector3(1.01, 1.0, 1.01), rim[j].lerp(hem[j], k) * Vector3(1.01, 1.0, 1.01), 0.006, 0.006, 6, cord)
	var knot := rim[2].lerp(hem[2], 0.36) * Vector3(1.02, 1.0, 1.02)
	mb.sphere(&"cloth", Transform3D(Basis(), knot), Vector3(0.016, 0.014, 0.016), 6, 4, cord)
	for dx: float in [-0.03, 0.035]:
		mb.cylinder_between(&"cloth", knot, knot + Vector3(dx, -0.09, 0.012), 0.005, 0.004, 5, cord)
