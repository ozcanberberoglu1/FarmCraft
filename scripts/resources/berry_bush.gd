class_name BerryBush
extends StaticBody3D
## A wild berry bush at the forest's edge or in a meadow (NatureSpawner places them;
## BerryModels builds them): blueberries, blackberries, raspberries or rosehips.
## E picks it clean: a handful or a few (PICK) of its berry item go into the bag with a
## rustle, the bush shakes and a few leaves and berries fall. It then stands bare, shows
## green berries from the next morning and is ripe again after 2-3 mornings (from its
## id; not in winter). The day it was picked is kept in FarmState.depleted (saved).
## Walked through like tall grass: only the interaction ray hits it.

const PICK := Vector2i(2, 4)
## Mornings from picked to ripe: this plus 0 or 1 (from the bush's id).
const REGROW_DAYS := 2
## How ripe the new berries look before they are (berry.gdshader `ripeness`).
const UNRIPE_LOOK := 0.18
## How far the bush and its berries are drawn per graphics preset (m, LOW..ULTRA); the
## leaves cast shadows from MEDIUM up.
const VIEW: Array[float] = [70.0, 95.0, 120.0, 140.0]
const FRUIT_VIEW: Array[float] = [40.0, 55.0, 70.0, 85.0]

var kind: StringName = &"blueberry"
var variant := 0
var resource_id := ""
var bush_scale := 1.0
var picked := false

var _leaves: MeshInstance3D
var _fruit: MeshInstance3D
var _tween: Tween


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"berry_bushes")
	var look: Dictionary = BerryModels.LOOK[kind]
	_leaves = _part(BerryModels.leaves(kind, variant), true, 120.0)
	_fruit = _part(BerryModels.fruit(kind, variant), false, 70.0)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = float(look["radius"]) * 0.85 * bush_scale
	shape.height = float(look["height"]) * bush_scale
	cs.shape = shape
	cs.position.y = shape.height * 0.5
	add_child(cs)
	if Engine.is_editor_hint():
		return
	_apply_quality()
	Settings.changed.connect(_apply_quality)
	if FarmState.depleted.has(resource_id):
		_set_picked(true)
		_show_regrowth(GameClock.day)
	Events.day_started.connect(_on_day_started)


func _part(mesh: Mesh, shadows: bool, view_range: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.scale = Vector3.ONE * bush_scale
	# Small clutter: no GI voxelization, kept out of the rain-blocker heightfield.
	mi.layers = 2
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = view_range
	mi.visibility_range_end_margin = 8.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	# Shaken by tweens outside the physics step.
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(mi)
	return mi


func _apply_quality() -> void:
	var q: int = Settings.quality
	_leaves.visibility_range_end = VIEW[q]
	_fruit.visibility_range_end = FRUIT_VIEW[q]
	_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if q >= Settings.Quality.MEDIUM \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The berry item this bush gives.
func item_id() -> StringName:
	return kind


## Mornings this bush takes to fruit again.
func regrow_days() -> int:
	return REGROW_DAYS + (absi(hash(resource_id)) % 2)


func is_ripe() -> bool:
	return not picked


func interact_title() -> String:
	return tr("BUSH_" + String(kind).to_upper())


func interact_prompt(_player: Node) -> String:
	return tr("ACTION_PICK_BERRIES") if not picked else ""


## A bare bush says when it will fruit again.
func hint_prompt() -> String:
	if not picked:
		return ""
	if GameClock.get_season() == GameClock.Season.WINTER:
		return tr("BUSH_WINTER")
	return tr("BUSH_BARE")


func interact(player: Node) -> void:
	if picked or Engine.is_editor_hint():
		return
	var id := item_id()
	var want := randi_range(PICK.x, PICK.y)
	var left := PlayerState.give(id, want)
	var got := want - left
	if got <= 0:
		return
	pick_clean()
	Events.item_picked_up.emit(id, got)
	var at := _fruit_center()
	if player is Player:
		(player as Player).show_take(id, Transform3D(Basis(), at))


## The bush is picked (the berries go, it rustles and shakes); saved as depleted today.
func pick_clean() -> void:
	FarmState.depleted[resource_id] = GameClock.day
	var look: Dictionary = BerryModels.LOOK[kind]
	var r := float(look["radius"]) * bush_scale
	var at := _fruit_center()
	# Leaves rustling as the hand pulls the berries off, and the berries coming away.
	WildSfx.play("rustle", at, -3.0, 0.1)
	Audio.play("pick_crop", at, -5.0, 0.08, &"Effects", 4.0)
	Fx.leaves(at, Vector2(r * 0.6, r * 0.6), false)
	_drop_berries(at, r)
	_set_picked(true, true)


## A few berries knocked loose tumble to the ground.
func _drop_berries(at: Vector3, r: float) -> void:
	var d := Fx._debris()
	if d == null:
		return
	var look: Dictionary = BerryModels.LOOK[kind]
	var ripe: Color = look["ripe"]
	var size := float(look["size"]) * 1.8
	d.throw({"look": &"seed", "count": Fx._n(5), "at": at, "box": Vector3(r * 0.5, 0.15, r * 0.5), "dir": Vector3.UP,
			"cone": 60.0, "speed": Vector2(0.4, 1.4), "size": Vector2(size * 0.8, size),
			"shape": Vector3(1.0, 1.0, 1.0), "spin": 3.0, "colors": Fx._lin([ripe, ripe.lightened(0.1), ripe.darkened(0.1)]),
			"floor": global_position.y + 0.02, "life": Fx._linger()})


## Where the berries hang thickest: two thirds up, in the middle.
func _fruit_center() -> Vector3:
	var look: Dictionary = BerryModels.LOOK[kind]
	return global_position + Vector3(0, float(look["height"]) * bush_scale * 0.62, 0)


func _set_picked(value: bool, animate := false) -> void:
	picked = value
	if value and animate:
		# The bush shakes as the hand pulls through it, then settles.
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		var base := _leaves.rotation
		for i in 4:
			var k := 1.0 - i / 4.0
			_tween.tween_property(_leaves, "rotation", base + Vector3(0.05 * k, 0, -0.06 * k), 0.07)
			_tween.tween_property(_leaves, "rotation", base + Vector3(-0.04 * k, 0, 0.05 * k), 0.07)
		_tween.tween_property(_leaves, "rotation", base, 0.1)
		_fruit.visible = false
		return
	_fruit.visible = not value
	_fruit.set_instance_shader_parameter(&"ripeness", 1.0)


## Picked bushes grow green berries from the morning after (not in winter).
func _show_regrowth(day: int) -> void:
	if not picked:
		return
	var since := day - int(FarmState.depleted.get(resource_id, day))
	var green := since >= 1 and GameClock.get_season() != GameClock.Season.WINTER
	_fruit.visible = green
	_fruit.set_instance_shader_parameter(&"ripeness", UNRIPE_LOOK)


func _on_day_started(day: int) -> void:
	if not picked:
		return
	if GameClock.get_season() == GameClock.Season.WINTER:
		_fruit.visible = false
		return
	if day - int(FarmState.depleted.get(resource_id, day)) >= regrow_days():
		FarmState.depleted.erase(resource_id)
		_set_picked(false)
	else:
		_show_regrowth(day)
