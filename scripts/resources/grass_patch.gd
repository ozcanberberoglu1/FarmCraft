class_name GrassPatch
extends StaticBody3D
## A clump of tall wild grass. Cut it with the scythe for hay; it grows back after
## a couple of days (not in winter).

const REGROW_DAYS := 2

var patch_seed := 1
var resource_id := ""
var cut := false

var _visual: MultiMeshInstance3D

static var _mesh: ArrayMesh


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"grass_patches")
	if _mesh == null:
		_mesh = NatureModels.grass_clump(7, 9).duplicate() as ArrayMesh
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/grass.gdshader")
		mat.set_shader_parameter("ground_tex", Mats.texture("leafy_grass", "diff.jpg"))
		mat.set_shader_parameter("fade_start", 70.0)
		mat.set_shader_parameter("fade_end", 90.0)
		mat.set_shader_parameter("bend", 0.24)
		_mesh.surface_set_material(0, mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = patch_seed
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = 26
	for i in mm.instance_count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.75
		var p := Vector3(cos(a) * r, -0.02, sin(a) * r)
		var s := rng.randf_range(1.2, 1.7)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(1.6, 2.3), s))
		mm.set_instance_transform(i, Transform3D(b, p))
	_visual = MultiMeshInstance3D.new()
	_visual.multimesh = mm
	# Small clutter: kept out of the rain-blocker heightfield.
	_visual.layers = 2
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_visual.visibility_range_end = 95.0
	add_child(_visual)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.9, 1.6)
	cs.shape = box
	cs.position.y = 0.45
	add_child(cs)
	# Editor previews (tool spawner) have no game state.
	if Engine.is_editor_hint():
		return
	if FarmState.depleted.has(resource_id):
		_set_cut(true)
	Events.day_started.connect(_on_day_started)


func interact_prompt(_player: Node) -> String:
	return ""


func use_prompt(player: Node, stack: ItemStack) -> String:
	var a := use_action(player, stack)
	return tr(a["verb"]) if not a.is_empty() else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	if cut or stack == null or stack.item.tool_type != &"scythe":
		return {}
	return {"id": "cut", "verb": "ACTION_CUT", "label": "PROGRESS_CUTTING", "duration": 0.6, "wear": true}


## The scythe's sweep landing (the look only): clippings fly along the sweep.
func use_impact(player: Node, _stack: ItemStack, _action: Dictionary, _hit: Dictionary) -> void:
	var sweep := Vector3.LEFT
	if player is Player:
		sweep = -(player as Player).camera.global_basis.x
	Fx.clippings(global_position + Vector3(0, 0.35, 0), sweep)


func complete_use(_player: Node, _stack: ItemStack, _action: Dictionary) -> void:
	FarmState.depleted[resource_id] = GameClock.day
	var origin := global_position + Vector3(0, 0.5, 0)
	var count := randi_range(1, 2)
	for i in count:
		var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		Pickup.spawn(ItemStack.create(&"hay", 1), origin + dir * 0.3, dir + Vector3.UP * 2.0, true)
	_set_cut(true, true)


## `animate`: the clump folds over under the blade before it disappears.
func _set_cut(value: bool, animate := false) -> void:
	cut = value
	if value:
		remove_from_group(&"interactable")
	else:
		add_to_group(&"interactable")
	if value and animate and _visual.visible:
		var tw := create_tween()
		tw.tween_property(_visual, "scale:y", 0.2, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			_visual.visible = not cut
			_visual.scale = Vector3.ONE)
		return
	_visual.scale = Vector3.ONE
	_visual.visible = not value


func _on_day_started(day: int) -> void:
	if not cut or GameClock.get_season() == GameClock.Season.WINTER:
		return
	if day - int(FarmState.depleted.get(resource_id, day)) >= REGROW_DAYS:
		FarmState.depleted.erase(resource_id)
		_set_cut(false)
