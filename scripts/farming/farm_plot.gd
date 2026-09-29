@tool
class_name FarmPlot
extends StaticBody3D
## One raised garden bed: soil state, crop growth and every tool interaction.
## Growth only advances while the soil is wet (watering or rain keeps it wet for
## CropTable.WET_HOURS). A planted bed left dry for WITHER_HOURS withers.

signal changed

enum Soil { UNTILLED, TILLED }

const SIZE := 2.4
const INNER := 2.16
const FRAME_H := 0.2
const SOIL_Y := 0.12
## Fertilizer this far under the tilled soil's exact surface is left out (the soil
## mesh follows that surface through a grid, a few millimetres off in places).
const BURIED := 0.012
## Thickness of the frame's boards; the soil mesh reaches out to them.
const BOARD_T := 0.045

var soil := Soil.UNTILLED
var crop: StringName = &""
var growth := 0.0
var harvests := 0
var wet_hours := 0.0
var dry_hours := 0.0
var withered := false
var variant := 0
## 0 none, 1 manure, 2 fertilizer: faster growth and better quality until the crop
## is gone.
var fertility := 0

var _soil_mesh: MeshInstance3D
var _fert_mesh: MeshInstance3D
var _crop_mesh: MultiMeshInstance3D
var _indicator: Sprite3D
var _highlight: MeshInstance3D
## Box over the plants for the interaction ray (see _fit_reach).
var _reach_shape: CollisionShape3D
var _shown := ""
var _time := 0.0
## Height the badge bobs around (it follows the crop's growth stage).
var _badge_top := 1.2

static var _frame_mesh: ArrayMesh
static var _tilled_mesh: ArrayMesh
static var _untilled_mesh: ArrayMesh
static var _fert_meshes := {}
static var _highlight_mat: StandardMaterial3D
static var _tilled_noise: FastNoiseLite


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"farm_plots")
	_build()
	_refresh()


# --- State queries -------------------------------------------------------------------

func is_wet() -> bool:
	return wet_hours > 0.0


func crop_data() -> Dictionary:
	return CropTable.get_crop(crop)


func target_hours() -> float:
	var d := crop_data()
	return float(d.get("regrow_h", 0) if harvests > 0 else d.get("grow_h", 1))


func is_ready() -> bool:
	return crop != &"" and not withered and growth >= target_hours()


## Fertilized soil grows crops 15% (manure) or 30% (fertilizer) faster.
func growth_rate() -> float:
	return 1.0 + 0.15 * fertility


## Quality of one harvested item: better soil, better odds of silver and gold.
func roll_quality() -> int:
	var gold: float = [0.0, 0.06, 0.15][fertility]
	var silver: float = [0.08, 0.28, 0.38][fertility]
	var r := randf()
	if r < gold:
		return ItemStack.Quality.GOLD
	if r < gold + silver:
		return ItemStack.Quality.SILVER
	return ItemStack.Quality.NORMAL


func stage() -> int:
	if crop == &"":
		return -1
	if is_ready():
		return 3
	if harvests > 0:
		return 2
	return clampi(int(growth / target_hours() * 3.0), 0, 2)


## What the crop card beside the crosshair (CropCard) shows, worked out here so the
## HUD holds no growth rules. "state": growing, dry (paused on dry soil), ready or
## withered; "stage" as stage(); "ratio" 0..1 towards the next harvest; "hours_left"
## game hours to ripe if the soil stays wet; "wet_hours"; "rewater" when the soil
## dries before the crop is ripe; "wither_in" dry hours left before it withers;
## "regrow" after a first harvest; "fertility". Empty for a bed with no crop.
func growth_info() -> Dictionary:
	if crop == &"":
		return {}
	var target := target_hours()
	var left := maxf(target - growth, 0.0) / growth_rate()
	var kind := "growing"
	if withered:
		kind = "withered"
	elif is_ready():
		kind = "ready"
	elif not is_wet():
		kind = "dry"
	return {
		"crop": crop,
		"state": kind,
		"stage": stage(),
		"ratio": clampf(growth / target, 0.0, 1.0) if target > 0.0 else 1.0,
		"hours_left": left,
		"wet_hours": wet_hours,
		"rewater": kind == "growing" and wet_hours < left,
		"wither_in": maxf(CropTable.WITHER_HOURS - dry_hours, 0.0),
		"regrow": harvests > 0,
		"fertility": fertility,
	}


# --- Simulation ----------------------------------------------------------------------

func advance(hours: float) -> void:
	if soil != Soil.TILLED:
		return
	var wet_part := minf(hours, wet_hours)
	wet_hours = maxf(wet_hours - hours, 0.0)
	if crop != &"" and not withered:
		growth += wet_part * growth_rate()
		if hours > wet_part and not is_ready():
			dry_hours += hours - wet_part
			if dry_hours >= CropTable.WITHER_HOURS:
				withered = true
	_refresh()


func soak(hours := CropTable.WET_HOURS) -> void:
	if soil != Soil.TILLED:
		return
	wet_hours = maxf(wet_hours, hours)
	dry_hours = 0.0
	_refresh()


## Crops that cannot live in the new season die.
func on_season_changed(season: int) -> void:
	if crop != &"" and not withered and not CropTable.in_season(crop, season):
		withered = true
		_refresh()


# --- Interaction ------------------------------------------------------------------------

func interact_prompt(_player: Node) -> String:
	return ""


func use_prompt(player: Node, stack: ItemStack) -> String:
	var a := _action_for(player, stack)
	return tr(a.get("verb", "")) if not a.is_empty() else ""


func use_action(player: Node, stack: ItemStack) -> Dictionary:
	return _action_for(player, stack)


func _action_for(_player: Node, stack: ItemStack) -> Dictionary:
	if stack == null:
		return {}
	var item := stack.item
	var tool := item.tool_type
	if tool == &"hoe":
		if soil == Soil.UNTILLED:
			return {"id": "hoe", "verb": "ACTION_HOE", "label": "PROGRESS_HOEING", "duration": 1.2, "wear": true}
		if withered:
			return {"id": "clear", "verb": "ACTION_CLEAR", "label": "PROGRESS_CLEARING", "duration": 0.8, "wear": true}
	elif item.category == "seed":
		if soil == Soil.TILLED and crop == &"":
			return {"id": "plant", "verb": "ACTION_PLANT", "label": "PROGRESS_PLANTING", "duration": 0.9}
	elif item.id == &"fertilizer" or item.id == &"manure":
		if soil == Soil.TILLED and not withered and fertility < (2 if item.id == &"fertilizer" else 1):
			return {"id": "fertilize", "verb": "ACTION_FERTILIZE", "label": "PROGRESS_FERTILIZING", "duration": 0.8}
	elif tool == &"watering_can":
		if soil == Soil.TILLED and wet_hours < CropTable.WET_HOURS - 1.0:
			return {"id": "water", "verb": "ACTION_WATER", "label": "PROGRESS_WATERING", "duration": 0.7}
	elif tool == &"scythe":
		if is_ready():
			return {"id": "harvest", "verb": "ACTION_HARVEST", "label": "PROGRESS_HARVESTING", "duration": 0.9, "wear": true}
		if withered:
			return {"id": "clear", "verb": "ACTION_CLEAR", "label": "PROGRESS_CLEARING", "duration": 0.8, "wear": true}
	return {}


## Checks that can refuse an action with a message (empty can, wrong season...).
func can_start(action: Dictionary, stack: ItemStack) -> String:
	match action.get("id", ""):
		"water":
			if stack.water <= 0:
				return tr("MSG_CAN_EMPTY")
		"plant":
			var c := stack.item.crop_id
			if not CropTable.in_season(c, GameClock.get_season()):
				return tr("MSG_WRONG_SEASON") % ItemDB.get_item(CropTable.get_crop(c).get("item", c)).display_name()
	return ""


## A stroke landing on the bed (the look only; complete_use changes the bed), on the
## tick it lands: clods thrown back where the hoe bites, drips under the can's stream,
## seeds settling, dry stalks off the scythe (`hit`: see the Player's doc comment).
func use_impact(player: Node, stack: ItemStack, action: Dictionary, hit: Dictionary) -> void:
	var is_final: bool = hit.get("final", false)
	var soil_at := global_position + Vector3(0, SOIL_Y + 0.05, 0)
	# Where the aim meets the bed, kept on the soil.
	var local := to_local(hit.get("point", soil_at))
	var half := INNER * 0.5 - 0.1
	var at := to_global(Vector3(clampf(local.x, -half, half), SOIL_Y + 0.05, clampf(local.z, -half, half)))
	var back := Vector3.ZERO
	var sweep := Vector3.LEFT
	if player is Node3D:
		back = (player as Node3D).global_position - at
		back.y = 0.0
		back = back.normalized() * 0.6 if back.length() > 0.01 else Vector3.ZERO
		# Clippings fly the way the scythe sweeps: across the view, right to left.
		var cam := player.get("camera") as Node3D
		if cam:
			sweep = -cam.global_basis.x
	match action.get("id", ""):
		"hoe":
			Fx.dirt_clods(at, back, 1.4 if is_final else 0.7)
			if is_final:
				Fx.dirt_burst(soil_at, 1.4)
		"clear":
			if stack and stack.item.tool_type == &"scythe":
				Fx.clippings(at + Vector3(0, 0.2, 0), sweep, Color(0.45, 0.38, 0.22))
			else:
				Fx.dirt_clods(at, back, 1.0)
		"water":
			if is_final:
				Fx.water_splash(soil_at)
			else:
				Fx.drips(at + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)))
		"plant":
			if is_final:
				Fx.dirt_burst(at, 0.4)
		"fertilize":
			if is_final:
				Fx.dirt_burst(soil_at, 0.7)


func complete_use(player: Node, stack: ItemStack, action: Dictionary) -> void:
	match action.get("id", ""):
		"hoe":
			soil = Soil.TILLED
		"plant":
			crop = stack.item.crop_id
			growth = 0.0
			harvests = 0
			dry_hours = 0.0
			withered = false
			PlayerState.inventory.remove_item(stack.item.id, 1)
		"water":
			stack.water -= 1
			PlayerState.inventory.changed.emit()
			soak()
		"fertilize":
			fertility = 2 if stack.item.id == &"fertilizer" else 1
			PlayerState.inventory.remove_item(stack.item.id, 1)
		"harvest":
			_harvest(player)
		"clear":
			crop = &""
			growth = 0.0
			harvests = 0
			withered = false
			dry_hours = 0.0
			fertility = 0
	changed.emit()
	_refresh()


func _harvest(_player: Node) -> void:
	var d := crop_data()
	var y: Array = d.get("yield", [1, 1])
	var count := randi_range(y[0], y[1])
	var origin := global_position + Vector3(0, SOIL_Y + 0.4, 0)
	_pop_items(d.get("item", crop), count, origin, true)
	if d.has("extra"):
		var extra: Array = d["extra"]
		_pop_items(extra[0], extra[1], origin)
	Fx.leaf_burst(origin, crop)
	if int(d.get("regrow_h", 0)) > 0:
		harvests += 1
		growth = 0.0
	else:
		crop = &""
		growth = 0.0
		harvests = 0
		fertility = 0


func _pop_items(item_id: StringName, count: int, origin: Vector3, graded := false) -> void:
	for i in count:
		var s := ItemStack.create(item_id, 1, roll_quality() if graded else ItemStack.Quality.NORMAL)
		var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		Pickup.spawn(s, origin + dir * 0.3, dir * 0.8 + Vector3.UP * 2.2, true)


func set_highlight(on: bool) -> void:
	if _highlight:
		_highlight.visible = on


# --- Visuals ----------------------------------------------------------------------------

func _build() -> void:
	for c in get_children():
		c.queue_free()
	# The new crop mesh and ray box are filled in by the next _refresh.
	_shown = ""
	if _frame_mesh == null:
		_frame_mesh = _make_frame()
		_tilled_mesh = _make_soil(true)
		_untilled_mesh = _make_soil(false)
		_highlight_mat = StandardMaterial3D.new()
		_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_highlight_mat.albedo_color = Color(0.25, 1.0, 0.3, 0.16)
	var frame := MeshInstance3D.new()
	frame.mesh = _frame_mesh
	add_child(frame)
	_soil_mesh = MeshInstance3D.new()
	add_child(_soil_mesh)
	# Flakes a few millimetres tall: too small to cast a shadow a cascade can show.
	# Crops and fertilizer come and go: they stay out of SDFGI (nothing to voxelize
	# again as they change) and, as small clutter, out of the rain blocker (layer 2).
	_fert_mesh = MeshInstance3D.new()
	_fert_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fert_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_fert_mesh.layers = 2
	add_child(_fert_mesh)
	_crop_mesh = MultiMeshInstance3D.new()
	_crop_mesh.position.y = SOIL_Y + 0.03
	# Fields are drawn only near the farm (a bed of corn is ~20k triangles, fewer far
	# away through its LODs).
	_crop_mesh.visibility_range_end = 110.0
	_crop_mesh.visibility_range_end_margin = 10.0
	_crop_mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_crop_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(_crop_mesh)
	_indicator = Sprite3D.new()
	_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_indicator.fixed_size = true
	_indicator.pixel_size = 0.00042
	_indicator.shaded = false
	_indicator.no_depth_test = true
	_indicator.render_priority = 10
	_indicator.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_indicator.visible = false
	_indicator.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_indicator.layers = 2
	# It bobs in _process, not in physics steps.
	_indicator.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_indicator)
	_highlight = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(SIZE + 0.04, 0.26, SIZE + 0.04)
	_highlight.mesh = box
	_highlight.material_override = _highlight_mat
	_highlight.position.y = 0.13
	_highlight.visible = false
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(SIZE, 0.3, SIZE)
	cs.shape = shape
	cs.position.y = 0.15
	add_child(cs)
	# Grown plants stop the interaction ray too, so looking at tall corn or tomatoes
	# (not only their soil) aims at the bed. Layer 4 is only in the ray's mask: the
	# player still walks through, and placement already avoids the bed's footprint.
	_reach_shape = CollisionShape3D.new()
	_reach_shape.shape = BoxShape3D.new()
	_reach_shape.disabled = true
	add_child(_reach_shape)


func _refresh() -> void:
	if _soil_mesh == null:
		return
	_soil_mesh.mesh = _tilled_mesh if soil == Soil.TILLED else _untilled_mesh
	_soil_mesh.set_instance_shader_parameter("wet", 1.0 if is_wet() else 0.0)
	_fert_mesh.mesh = _fertilizer_mesh(fertility) if soil == Soil.TILLED and fertility > 0 else null
	var st := stage()
	var key := "%s_%d_%s" % [crop, st, withered]
	if key != _shown:
		_shown = key
		_crop_mesh.multimesh = PlantModels.multimesh(crop, st, variant, withered) if crop != &"" else null
		_fit_reach(st)
	# Indicator badges: ready to harvest, needs water, withered.
	var icon: Texture2D = null
	if is_ready():
		icon = load("res://art/icons/ui/badge_harvest.svg")
	elif withered:
		icon = load("res://art/icons/ui/badge_withered.svg")
	elif crop != &"" and not is_wet():
		icon = load("res://art/icons/ui/badge_water.svg")
	_indicator.texture = icon
	_indicator.visible = icon != null
	_badge_top = 1.2 if crop == &"" or st < 2 else _crop_height() + 0.45
	set_process(_indicator.visible)


## Spread over the soil: dark clumps of manure with bits of straw, or pale fertilizer
## granules. It only lies on tilled soil, whose ridges hide about half of the pieces:
## those are left out (every piece still draws its random numbers, so the rest stay put).
static func _fertilizer_mesh(level: int) -> ArrayMesh:
	if _fert_meshes.has(level):
		return _fert_meshes[level]
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + level
	var half := INNER * 0.5 - 0.06
	var ground := _soil_noise(true)
	if level == 1:
		# Crumbled, flattened dung worked into the top of the soil.
		for i in 220:
			var p := Vector3(rng.randf_range(-half, half), SOIL_Y + 0.004, rng.randf_range(-half, half))
			var r := rng.randf_range(0.018, 0.04)
			var flake := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, 0.22, rng.randf_range(0.6, 1.0))), p)
			var col := Color(0.2, 0.15, 0.11).darkened(rng.randf() * 0.3)
			# The noise swells a flake by up to half its radius.
			if p.y + r * 0.22 * 1.5 < _soil_y(ground, p.x, p.z, true) - BURIED:
				continue
			mb.blob(&"dung", flake, r, 1, col, 0.5, 4.0, i, 0.2)
		for i in 60:
			var p := Vector3(rng.randf_range(-half, half), SOIL_Y + 0.02, rng.randf_range(-half, half))
			var dir := Vector3(rng.randf_range(-1, 1), 0.05, rng.randf_range(-1, 1)).normalized()
			mb.cylinder_between(&"straw", p, p + dir * rng.randf_range(0.06, 0.14), 0.005, 0.004, 3,
					Color(0.58, 0.48, 0.3), false, false)
	else:
		for i in 260:
			var p := Vector3(rng.randf_range(-half, half), SOIL_Y + 0.008, rng.randf_range(-half, half))
			var radius := rng.randf_range(0.006, 0.01)
			var col := Color(0.86, 0.86, 0.82).darkened(rng.randf() * 0.12)
			if p.y + radius < _soil_y(ground, p.x, p.z, true) - BURIED:
				continue
			mb.sphere(&"veg", Transform3D(Basis(), p), Vector3.ONE * radius, 5, 3, col)
	var m := mb.build()
	_fert_meshes[level] = m
	return m


## Bobs the badge; runs only while one is shown.
func _process(delta: float) -> void:
	if _indicator and _indicator.visible:
		_time += delta
		_indicator.position.y = _badge_top + sin(_time * 2.4 + position.x) * 0.06


## Sizes the ray box to the plants at stage `st` (about the heights PlantModels grows
## them to, half for withered ones); off for a bare bed and plants under knee height,
## whose soil is aimed at anyway.
func _fit_reach(st: int) -> void:
	var h := 0.0
	if crop != &"" and st >= 0:
		var k: float = [0.25, 0.5, 0.85, 1.0][clampi(st, 0, 3)]
		h = _crop_height() * k * (0.5 if withered else 1.0)
	_reach_shape.disabled = h < 0.35
	if not _reach_shape.disabled:
		(_reach_shape.shape as BoxShape3D).size = Vector3(INNER, h, INNER)
		_reach_shape.position.y = SOIL_Y + h * 0.5


func _crop_height() -> float:
	match crop:
		&"corn":
			return 2.0
		&"tomato":
			return 1.25
		&"eggplant":
			return 0.85
		&"wheat":
			return 0.85
	return 0.55


## Weathered boards, two to a side with a thin gap and each a little out of true,
## nailed to corner stakes that stand a hand above them.
static func _make_frame() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2404
	var h := SIZE * 0.5
	var t := BOARD_T
	var board := FRAME_H * 0.5 - 0.006
	for side in 4:
		var along_x := side < 2
		var sgn := -1.0 if side % 2 == 0 else 1.0
		for row in 2:
			var y := board * 0.5 + row * (board + 0.012)
			var length := SIZE - 0.03 if along_x else SIZE - t * 2.0 - 0.02
			var center := Vector3(0, y, sgn * (h - t * 0.5)) if along_x else Vector3(sgn * (h - t * 0.5), y, 0)
			center += (Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)) * rng.randf_range(-0.006, 0.006)
			var size := Vector3(length, board, t) if along_x else Vector3(t, board, length)
			var tilt := Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-0.35, 0.35)) if along_x \
					else Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-1.2, 1.2))
			var tone := rng.randf_range(0.4, 0.52)
			mb.box_at(&"wood_old", center, size, Color(tone, tone * 0.98, tone * 0.95), tilt)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var tone := rng.randf_range(0.36, 0.44)
			mb.box_at(&"wood_old", Vector3(sx * (h - t - 0.03), FRAME_H * 0.5 + 0.02, sz * (h - t - 0.03)),
					Vector3(0.06, FRAME_H + 0.04, 0.06), Color(tone, tone, tone),
					Vector3(rng.randf_range(-2, 2), rng.randf_range(0, 20), rng.randf_range(-2, 2)), true)
	return mb.build()


## Soil surface inside the frame: ridged furrows when tilled, lumpy flat dirt otherwise.
static func _make_soil(tilled: bool) -> ArrayMesh:
	var n := 32
	# Out to the boards, so no gap shows along them.
	var half := SIZE * 0.5 - BOARD_T + 0.004
	var noise := _soil_noise(tilled)
	var step := 2.0 * half / n
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	for iz in n + 1:
		for ix in n + 1:
			var x := -half + step * ix
			var z := -half + step * iz
			verts.append(Vector3(x, _soil_y(noise, x, z, tilled), z))
			# Smooth normals from the surface's slope.
			var e := step * 0.5
			var dx := _soil_y(noise, x + e, z, tilled) - _soil_y(noise, x - e, z, tilled)
			var dz := _soil_y(noise, x, z + e, tilled) - _soil_y(noise, x, z - e, tilled)
			norms.append(Vector3(-dx, 2.0 * e, -dz).normalized())
			uvs.append(Vector2(x, z))
	var mb := MeshBuilder.new()
	var key := &"soil_tilled" if tilled else &"soil_untilled"
	var white := Color.WHITE
	for iz in n:
		for ix in n:
			var i := iz * (n + 1) + ix
			var j := i + n + 1
			# Counter-clockwise seen from above: a (x,z) -> d (x,z+1) -> c -> b.
			mb.tri_n(key, verts[i], verts[j], verts[j + 1], norms[i], norms[j], norms[j + 1], white, white, white,
					uvs[i], uvs[j], uvs[j + 1])
			mb.tri_n(key, verts[i], verts[j + 1], verts[i + 1], norms[i], norms[j + 1], norms[i + 1], white, white, white,
					uvs[i], uvs[j + 1], uvs[i + 1])
	return mb.build({}, true)


static func _soil_noise(tilled: bool) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = 3 if tilled else 8
	noise.frequency = 2.2
	noise.fractal_octaves = 3
	return noise


## Height of the soil surface at (x, z) in the bed: crumbly, a little heaped in the
## middle and against the boards; tilled soil in four hoed ridges with rounded crowns
## and V furrows, higher and lower along their length.
static func _soil_y(noise: FastNoiseLite, x: float, z: float, tilled: bool) -> float:
	var half := SIZE * 0.5 - BOARD_T
	var edge := minf(half - absf(x), half - absf(z))
	var y := SOIL_Y + noise.get_noise_2d(x, z) * 0.012 + noise.get_noise_2d(x * 4.0 + 17.0, z * 4.0) * 0.004
	y += 0.008 * (1.0 - smoothstep(0.0, 0.12, edge))
	if tilled:
		var ridge := pow(0.5 + 0.5 * cos(TAU * (z + INNER * 0.5) / (INNER / 4.0)), 0.6)
		ridge *= 0.8 + 0.4 * (0.5 + 0.5 * noise.get_noise_2d(x * 0.6 + 40.0, z * 0.3))
		y += ridge * 0.065 - 0.015
	return y


## Height (bed-local) of the tilled soil's surface at (x, z): crops stand in it.
static func soil_surface(x: float, z: float) -> float:
	if _tilled_noise == null:
		_tilled_noise = _soil_noise(true)
	return _soil_y(_tilled_noise, x, z, true)


# --- Save -----------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"soil": soil, "crop": String(crop), "growth": growth, "harvests": harvests,
		"wet": wet_hours, "dry": dry_hours, "withered": withered, "fert": fertility}


func load_data(d: Dictionary) -> void:
	soil = int(d.get("soil", Soil.UNTILLED))
	crop = StringName(d.get("crop", ""))
	growth = float(d.get("growth", 0.0))
	harvests = int(d.get("harvests", 0))
	wet_hours = float(d.get("wet", 0.0))
	dry_hours = float(d.get("dry", 0.0))
	withered = bool(d.get("withered", false))
	fertility = int(d.get("fert", 0))
	_refresh()
