class_name Sapling
extends StaticBody3D
## A sapling the player planted (SaplingGrove): a young conifer or broadleaf in a ring
## of dug soil, tied to a stake while small. It grows only while its soil is wet (the
## watering can or rain, CropTable.WET_HOURS at a time), through three stages drawn as
## the valley's real trees scaled down and slimmed (NatureModels; young trees are
## slender), and at SaplingGrove.GROW_HOURS the grove turns it into a ChoppableTree.
## Its state is its FarmState.saplings entry: {id, kind, variant, pos, yaw, scale,
## growth, wet}. A water badge floats over it while its soil is dry; aimed at, the crop
## card shows its growth. Stage 0 can be dug up again (E), older ones cut with the axe.

## Height of each stage against the grown tree, and its crown's width against the
## grown tree's shape.
const STAGE_SIZE: Array[float] = [0.12, 0.24, 0.45]
const STAGE_SLENDER: Array[float] = [0.5, 0.65, 0.8]
const STAGE_KEYS: Array[String] = ["SAPLING_STAGE_0", "SAPLING_STAGE_1", "SAPLING_STAGE_2"]
const KIND_KEYS: Array[String] = ["TREE_KIND_CONIFER", "TREE_KIND_BROADLEAF"]
## The aim's (and from the last stage the body's) cylinder per stage: radius, height.
const STAGE_SHAPE: Array[Vector2] = [Vector2(0.28, 1.0), Vector2(0.3, 2.0), Vector2(0.16, 3.2)]
## How far each stage is drawn (m): small things vanish early and cost nothing.
const STAGE_RANGE: Array[float] = [70.0, 120.0, 220.0]
## Where the water badge bobs, per stage (m).
const BADGE_Y: Array[float] = [1.35, 2.0, 2.4]
const MOUND_RADIUS := 0.42
## The stake's height over the ground and its offset from the stem (m).
const STAKE_H := 0.95
const STAKE_AT := Vector3(0.075, 0.0, 0.02)
## Wood a young tree gives when cut, per stage.
const WOOD: Array[int] = [0, 1, 2]

var entry: Dictionary = {}

var _pivot: Node3D
var _tree: MeshInstance3D
var _stake: MeshInstance3D
var _soil: MeshInstance3D
var _shape: CollisionShape3D
var _badge: Sprite3D
var _stage := -1
var _time := 0.0
var _badge_top := 1.2
var _tween: Tween

## Each tree mesh's materials per stage, with the wind scaled to the young tree.
static var _stage_mats := {}
static var _stake_mesh: ArrayMesh
static var _mound_noise: FastNoiseLite


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"saplings")
	var p: Vector3 = entry["pos"]
	position = p
	_soil = MeshInstance3D.new()
	_soil.mesh = _mound_mesh(p)
	_soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_soil.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_soil.visibility_range_end = 60.0
	_soil.layers = 2
	add_child(_soil)
	_pivot = Node3D.new()
	# Grown and felled by tweens outside the physics step.
	_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_pivot.rotation.y = float(entry.get("yaw", 0.0))
	add_child(_pivot)
	_tree = MeshInstance3D.new()
	_tree.mesh = NatureModels.pine(variant()) if kind() == 0 else NatureModels.oak(variant())
	_tree.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_pivot.add_child(_tree)
	_stake = MeshInstance3D.new()
	_stake.mesh = _make_stake()
	_stake.position = STAKE_AT
	_stake.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_pivot.add_child(_stake)
	_shape = CollisionShape3D.new()
	_shape.shape = CylinderShape3D.new()
	add_child(_shape)
	_badge = Sprite3D.new()
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.fixed_size = true
	_badge.pixel_size = 0.00042
	_badge.shaded = false
	_badge.no_depth_test = true
	_badge.render_priority = 10
	_badge.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_badge.texture = load("res://art/icons/ui/badge_water.svg")
	# Saplings may stand anywhere in the valley: their badges show only nearby.
	_badge.visibility_range_end = 45.0
	_badge.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_badge.layers = 2
	_badge.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_badge)
	if Game.world and Game.world.has_method("block_grass"):
		# The meadow's blades stay off the dug soil.
		Game.world.block_grass(Rect2(p.x - MOUND_RADIUS * 0.8, p.z - MOUND_RADIUS * 0.8, MOUND_RADIUS * 1.6, MOUND_RADIUS * 1.6))
	apply_quality()
	_refresh(false)


# --- State ----------------------------------------------------------------------------

func kind() -> int:
	return int(entry.get("kind", 0))


func variant() -> int:
	return int(entry.get("variant", 1))


func tree_scale() -> float:
	return float(entry.get("scale", 1.0))


func growth() -> float:
	return float(entry.get("growth", 0.0))


func wet_hours() -> float:
	return float(entry.get("wet", 0.0))


func is_wet() -> bool:
	return wet_hours() > 0.0


## 0 sapling, 1 young tree, 2 growing tree (then it is a tree).
func stage() -> int:
	return clampi(int(growth() / SaplingGrove.GROW_HOURS * 3.0), 0, 2)


## The young tree's size against the grown tree's, per axis (the grown tree rises from it).
func tree_size() -> Vector3:
	var st := maxi(_stage, 0)
	var h := STAGE_SIZE[st]
	var w := h * STAGE_SLENDER[st]
	return Vector3(w, h, w)


## Game hours pass: growth only while the soil is wet. True once it is a full tree.
func advance(hours: float) -> bool:
	var wet := wet_hours()
	var wet_part := minf(hours, wet)
	entry["wet"] = maxf(wet - hours, 0.0)
	entry["growth"] = growth() + wet_part
	_refresh(true)
	return growth() >= SaplingGrove.GROW_HOURS


func soak(hours := CropTable.WET_HOURS) -> void:
	entry["wet"] = maxf(wet_hours(), hours)
	_refresh(false)


## What the crop card beside the crosshair shows (see FarmPlot.growth_info; saplings
## don't wither, a dry one just waits).
func growth_info() -> Dictionary:
	var left := maxf(SaplingGrove.GROW_HOURS - growth(), 0.0)
	var state := "growing" if is_wet() else "dry"
	var st := stage()
	return {
		"crop": SaplingGrove.ITEM,
		"state": state,
		"stage": st,
		"ratio": clampf(growth() / SaplingGrove.GROW_HOURS, 0.0, 1.0),
		"hours_left": left,
		"wet_hours": wet_hours(),
		"rewater": state == "growing" and wet_hours() < left,
		"wither_in": 0.0,
		"regrow": false,
		"fertility": 0,
		"name": tr(STAGE_KEYS[st]),
		"stage_text": tr(KIND_KEYS[clampi(kind(), 0, 1)]),
		"dry_hint": tr("SAPLING_NEEDS_WATER"),
	}


# --- Interaction ------------------------------------------------------------------------

func interact_prompt(_player: Node) -> String:
	return tr("ACTION_DIG_UP") if stage() == 0 and not _leaving() else ""


## E on a fresh sapling: dug up and back in the bag.
func interact(_player: Node) -> void:
	if stage() != 0 or _leaving():
		return
	_leave()
	if PlayerState.give(SaplingGrove.ITEM, 1) > 0:
		Pickup.spawn(ItemStack.create(SaplingGrove.ITEM, 1), global_position + Vector3(0, 0.5, 0), Vector3.UP)
	Fx.dirt_burst(global_position + Vector3(0, 0.05, 0), 0.45, global_position.y)
	Audio.play("hoe", global_position + Vector3(0, 0.2, 0), -4.0, 0.08, &"Effects", 5.0, 1.1)
	_tween = create_tween()
	_tween.tween_property(_pivot, "position:y", 0.35, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_soil, "scale", Vector3(1.0, 0.2, 1.0), 0.3)
	_tween.tween_property(_pivot, "scale", Vector3.ONE * 0.05, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(queue_free)


func use_prompt(player: Node, stack: ItemStack) -> String:
	var a := use_action(player, stack)
	return tr(a["verb"]) if not a.is_empty() else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	if stack == null or _leaving():
		return {}
	var tool := stack.item.tool_type
	if tool == &"watering_can" and wet_hours() < CropTable.WET_HOURS - 1.0:
		return {"id": "water", "verb": "ACTION_WATER", "label": "PROGRESS_WATERING", "duration": 0.7}
	if tool == &"axe" and stage() >= 1:
		return {"id": "chop", "verb": "ACTION_CHOP", "label": "PROGRESS_CHOPPING", "duration": 0.7, "wear": true}
	return {}


func can_start(action: Dictionary, stack: ItemStack) -> String:
	if action.get("id", "") == "water" and stack.water <= 0:
		return tr("MSG_CAN_EMPTY")
	return ""


## A stroke landing (the look only): drips under the can and a splash on the soil, or
## chips off the young trunk.
func use_impact(player: Node, _stack: ItemStack, action: Dictionary, hit: Dictionary) -> void:
	var soil_at := global_position + Vector3(0, 0.06, 0)
	match action.get("id", ""):
		"water":
			if hit.get("final", false):
				Fx.water_splash(soil_at)
			else:
				Fx.drips(soil_at + Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)))
		"chop":
			var toward := Vector3.UP
			if player is Node3D:
				toward = (player as Node3D).global_position - global_position
				toward.y = 0.0
				toward = toward.normalized() if toward.length() > 0.01 else Vector3.UP
			Fx.wood_chips(hit.get("point", global_position + Vector3(0, 0.6, 0)), toward, kind() == 0)


func complete_use(player: Node, stack: ItemStack, action: Dictionary) -> void:
	match action.get("id", ""):
		"water":
			stack.water -= 1
			PlayerState.inventory.changed.emit()
			soak()
		"chop":
			_cut_down(player)


## One blow fells a young tree: it tips over away from the player and a log or two
## drop.
func _cut_down(player: Node) -> void:
	var st := stage()
	_leave()
	var away := Vector3.FORWARD
	if player is Node3D:
		away = global_position - (player as Node3D).global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var axis := Vector3.UP.cross(away).normalized()
	var height := _tree.get_aabb().end.y * _tree.scale.y
	Audio.play("grass", global_position + Vector3(0, 1.0, 0), -8.0, 0.1, &"Effects", 5.0, 0.85)
	Fx.leaves(global_position + Vector3(0, height * 0.7, 0), Vector2(0.6, 0.6) * maxf(height * 0.25, 0.5), kind() == 0)
	_tween = create_tween()
	_tween.tween_interval(ToolAnim.HIT_STOP)
	_tween.tween_method(func(a: float) -> void: _pivot.basis = Basis(axis, a) * Basis(Vector3.UP, float(entry.get("yaw", 0.0))),
			0.0, PI * 0.46, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func() -> void:
		Fx.dust_cloud(global_position + away * height * 0.5 + Vector3(0, 0.2, 0), Vector2(0.5, 0.5))
		Audio.play("soft", global_position + away * height * 0.5, -6.0, 0.1, &"Effects", 5.0, 0.8)
		var rng := RandomNumberGenerator.new()
		for i in WOOD[st]:
			var at := global_position + away * rng.randf_range(0.5, maxf(height * 0.6, 0.8)) + Vector3(0, 0.5, 0)
			Pickup.spawn(ItemStack.create(&"wood", 1), at, Vector3(rng.randf_range(-0.6, 0.6), 1.6, rng.randf_range(-0.6, 0.6)), true))
	_tween.tween_interval(0.5)
	_tween.tween_property(_pivot, "position:y", -1.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(_soil, "scale", Vector3(1.0, 0.1, 1.0), 0.8)
	_tween.tween_callback(queue_free)


## No longer a target (dug up, cut down or grown into a tree); `forget`: out of the
## grove and the save (a grown one's entry stays: it is the tree's now).
func _leave(forget := true) -> void:
	var grove := get_parent() as SaplingGrove
	if grove and forget:
		grove.remove(self)
	remove_from_group(&"interactable")
	remove_from_group(&"saplings")
	_shape.set_deferred("disabled", true)
	_badge.visible = false
	set_process(false)


func _leaving() -> bool:
	return not is_in_group(&"interactable")


## Grown: the ChoppableTree the grove put here takes over, rising from this size.
func become_tree() -> void:
	_leave(false)
	var height := _tree.get_aabb().end.y * _tree.scale.y
	Fx.leaves(global_position + Vector3(0, height * 0.8, 0), Vector2(1.0, 1.0), kind() == 0)
	Audio.play("grass", global_position + Vector3(0, 1.5, 0), -12.0, 0.1, &"Effects", 6.0, 0.8)
	queue_free()


## Just put in the ground: it springs up out of the hole.
func planted() -> void:
	_pivot.scale = Vector3(0.6, 0.15, 0.6)
	_soil.scale = Vector3(0.5, 0.3, 0.5)
	_tween = create_tween()
	_tween.tween_property(_pivot, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(_soil, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func apply_quality() -> void:
	_tree.lod_bias = NatureSpawner.LOD_BIAS[Settings.quality]


# --- Looks ------------------------------------------------------------------------------

func _refresh(animate: bool) -> void:
	if _soil == null:
		return
	var wet := is_wet()
	_soil.set_instance_shader_parameter("wet", 1.0 if wet else 0.0)
	var st := stage()
	if st != _stage:
		var prev := _stage
		_stage = st
		_show_stage(st)
		if animate and prev >= 0:
			_grow_from(prev)
	_badge_top = BADGE_Y[st]
	_badge.visible = not wet and not _leaving()
	set_process(_badge.visible)


## Draws stage `st`: the tree at its size with the wind for it, the stake while small,
## the aim's cylinder (from the last stage, a trunk that stands in the way).
func _show_stage(st: int) -> void:
	var h := STAGE_SIZE[st] * tree_scale()
	var w := h * STAGE_SLENDER[st]
	_tree.scale = Vector3(w, h, w)
	# Sunk like the valley's trees (0.1 m at full size).
	_tree.position.y = -0.1 * h
	var mats := _materials(_tree.mesh, st)
	for s in mats.size():
		_tree.set_surface_override_material(s, mats[s])
	_tree.visibility_range_end = STAGE_RANGE[st]
	_tree.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_stake.visible = st < 2
	var dims := STAGE_SHAPE[st]
	var cyl := _shape.shape as CylinderShape3D
	cyl.radius = dims.x
	cyl.height = dims.y
	_shape.position.y = dims.y * 0.5
	collision_layer = (1 | 4) if st >= 2 else 4


## A stage reached: it fills out from the last stage's size, with a rustle of leaves.
func _grow_from(prev: int) -> void:
	var r := Vector3(STAGE_SIZE[prev] * STAGE_SLENDER[prev] / (STAGE_SIZE[_stage] * STAGE_SLENDER[_stage]),
			STAGE_SIZE[prev] / STAGE_SIZE[_stage], 0.0)
	r.z = r.x
	_pivot.scale = r
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_pivot, "scale", Vector3.ONE, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var height := _tree.get_aabb().end.y * _tree.scale.y
	Fx.leaves(global_position + Vector3(0, height * 0.75, 0), Vector2(0.5, 0.5) * maxf(height * 0.3, 0.6), kind() == 0)
	Audio.play("grass", global_position + Vector3(0, height * 0.5, 0), -14.0, 0.1, &"Effects", 5.0, 0.9)


## Bobs the water badge; runs only while it is shown.
func _process(delta: float) -> void:
	_time += delta
	_badge.position.y = _badge_top + sin(_time * 2.4 + position.x) * 0.06


## The tree mesh's materials for stage `st`: the same looks, the wind (metres at the
## tree's top) scaled down with the young tree, so a sapling sways, not thrashes.
static func _materials(m: Mesh, st: int) -> Array[Material]:
	var key := "%d_%d" % [m.get_instance_id(), st]
	if _stage_mats.has(key):
		return _stage_mats[key]
	var k := clampf(STAGE_SIZE[st] * 2.2, 0.3, 1.0)
	var out: Array[Material] = []
	var leaves := NatureModels.leaf_materials()
	for s in m.get_surface_count():
		var src := m.surface_get_material(s) as ShaderMaterial
		if src == null:
			out.append(m.surface_get_material(s))
			continue
		var mat := src.duplicate() as ShaderMaterial
		for p: String in ["sway", "branch_sway", "flutter"]:
			var v: Variant = src.get_shader_parameter(p)
			if v != null:
				mat.set_shader_parameter(p, float(v) * k)
		# The crowns' shading distance follows the graphics preset (NatureSpawner).
		if leaves.has(src):
			leaves.append(mat)
		out.append(mat)
	_stage_mats[key] = out
	return out


## A wooden stake with the stem tied to it by twine.
static func _make_stake() -> ArrayMesh:
	if _stake_mesh:
		return _stake_mesh
	var mb := MeshBuilder.new()
	var wood := Color(0.62, 0.52, 0.4)
	mb.cylinder_between(&"wood", Vector3(0, -0.15, 0), Vector3(0, STAKE_H, 0), 0.02, 0.016, 6, wood)
	# A pointed top cut, and two loops of twine round stake and stem.
	var twine := Color(0.74, 0.64, 0.44)
	for y: float in [0.38, 0.72]:
		mb.cylinder_between(&"cloth", Vector3(0.018, y, 0), Vector3(-STAKE_AT.x, y - 0.01, -STAKE_AT.z), 0.005, 0.005, 4, twine)
		mb.cylinder_between(&"cloth", Vector3(0, y - 0.012, 0.018), Vector3(0, y + 0.012, -0.018), 0.022, 0.022, 6, twine, true, false)
	_stake_mesh = mb.build()
	return _stake_mesh


## The ring of dug soil round the stem, laid over the terrain at `p` (a low crumbly
## heap round a little dip where the stem goes in, its rim sunk into the grass).
static func _mound_mesh(p: Vector3) -> ArrayMesh:
	if _mound_noise == null:
		_mound_noise = FastNoiseLite.new()
		_mound_noise.seed = 11
		_mound_noise.frequency = 6.0
	var rings := 6
	var segs := 20
	# A ragged rim, not a drawn circle: the heap's reach wavers round the stem.
	var rim := func(a: float) -> float:
		return 1.0 + 0.28 * _mound_noise.get_noise_2d(p.x * 3.0 + cos(a) * 1.3, p.z * 3.0 + sin(a) * 1.3)
	var h := func(x: float, z: float) -> float:
		var r := Vector2(x, z).length() / (MOUND_RADIUS * float(rim.call(atan2(z, x))))
		var heap := 0.05 * sin(clampf(r, 0.0, 1.0) * PI) * (1.0 - 0.35 * r) - 0.02 * smoothstep(0.75, 1.0, r)
		var dip := -0.02 * (1.0 - smoothstep(0.0, 0.25, r))
		var crumbs := _mound_noise.get_noise_2d(p.x + x, p.z + z) * 0.012 * (1.0 - smoothstep(0.8, 1.0, r))
		return TerrainData.height(p.x + x, p.z + z) - p.y + heap + dip + crumbs
	var pts: Array[Vector3] = [Vector3(0, h.call(0.0, 0.0), 0)]
	for ri in range(1, rings + 1):
		var f := float(ri) / rings
		for si in segs:
			var a := TAU * float(si) / segs
			# Out a little past the rim, which sinks into the grass there.
			var reach: float = MOUND_RADIUS * f * float(rim.call(a)) * 1.08
			var x := cos(a) * reach
			var z := sin(a) * reach
			pts.append(Vector3(x, h.call(x, z), z))
	var normal := func(v: Vector3) -> Vector3:
		var e := 0.03
		var dx: float = h.call(v.x + e, v.z) - h.call(v.x - e, v.z)
		var dz: float = h.call(v.x, v.z + e) - h.call(v.x, v.z - e)
		return Vector3(-dx, 2.0 * e, -dz).normalized()
	var norms: Array[Vector3] = []
	for v in pts:
		norms.append(normal.call(v))
	var mb := MeshBuilder.new()
	var white := Color.WHITE
	var key := &"soil_tilled"
	for si in segs:
		var a := 1 + si
		var b := 1 + (si + 1) % segs
		mb.tri_n(key, pts[0], pts[b], pts[a], norms[0], norms[b], norms[a], white, white, white)
	for ri in range(1, rings):
		for si in segs:
			var a := 1 + (ri - 1) * segs + si
			var b := 1 + (ri - 1) * segs + (si + 1) % segs
			var c := a + segs
			var d := b + segs
			mb.tri_n(key, pts[a], pts[b], pts[d], norms[a], norms[b], norms[d], white, white, white)
			mb.tri_n(key, pts[a], pts[d], pts[c], norms[a], norms[d], norms[c], white, white, white)
	return mb.build({}, true)
