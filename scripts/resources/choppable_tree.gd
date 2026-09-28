class_name ChoppableTree
extends StaticBody3D
## A tree that can be chopped with the axe. After enough hits it falls away from
## the player and drops wood; the stump regrows into a full tree a few days later.

const REGROW_DAYS := 4

var kind := 0
var variant := 1
var tree_scale := 1.0
var resource_id := ""
var hp := 1
var felled := false

var _pivot: Node3D
var _mesh: MeshInstance3D
var _stump: MeshInstance3D
var _trunk_shape: CollisionShape3D
var _stump_shape: CollisionShape3D
var _shake_tween: Tween

static var _stump_meshes: Dictionary = {}


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"trees")
	_pivot = Node3D.new()
	# Shaken, felled and regrown by tweens outside the physics step.
	_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_pivot)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = NatureModels.pine(variant) if kind == 0 else NatureModels.oak(variant)
	_mesh.scale = Vector3.ONE * tree_scale
	_pivot.add_child(_mesh)
	_stump = MeshInstance3D.new()
	_stump.mesh = _stump_mesh(kind)
	_stump.scale = Vector3.ONE * tree_scale
	_stump.visible = false
	add_child(_stump)
	_trunk_shape = CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = (0.3 if kind == 0 else 0.34) * tree_scale
	shape.height = 4.0
	_trunk_shape.shape = shape
	_trunk_shape.position.y = 2.0
	add_child(_trunk_shape)
	_stump_shape = CollisionShape3D.new()
	var s2 := CylinderShape3D.new()
	s2.radius = shape.radius + 0.05
	s2.height = 0.5
	_stump_shape.shape = s2
	_stump_shape.position.y = 0.25
	_stump_shape.disabled = true
	add_child(_stump_shape)
	hp = max_hp()
	# Editor previews (tool spawner) have no game state.
	if Engine.is_editor_hint():
		return
	if FarmState.depleted.has(resource_id):
		_set_felled(true)
	Events.day_started.connect(_on_day_started)


func max_hp() -> int:
	return roundi((4.0 if kind == 0 else 5.0) * tree_scale)


static func _stump_mesh(tree_kind: int) -> ArrayMesh:
	if _stump_meshes.has(tree_kind):
		return _stump_meshes[tree_kind]
	var mb := MeshBuilder.new()
	var r := 0.3 if tree_kind == 0 else 0.34
	mb.cylinder(&"bark_pine" if tree_kind == 0 else &"bark", Transform3D.IDENTITY, r * 1.35, r * 1.02, 0.42, 12, Color(0.5, 0.5, 0.5), true, false)
	mb.disc(&"endgrain", Transform3D(Basis(), Vector3(0, 0.42, 0)), r * 1.02, 12, Color.WHITE)
	var m := mb.build({&"endgrain": _endgrain_material(r)})
	_stump_meshes[tree_kind] = m
	return m


static func _endgrain_material(r: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/endgrain.gdshader")
	m.set_shader_parameter("log_radius", r)
	return m


# --- Chopping ------------------------------------------------------------------------

func interact_prompt(_player: Node) -> String:
	return ""


func use_prompt(player: Node, stack: ItemStack) -> String:
	var a := use_action(player, stack)
	return tr(a["verb"]) if not a.is_empty() else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	if felled or stack == null or stack.item.tool_type != &"axe":
		return {}
	return {"id": "chop", "verb": "ACTION_CHOP", "label": "PROGRESS_CHOPPING", "duration": 0.7, "wear": true}


## A blow landing (the look only; complete_use does the chopping): chips fly off the
## trunk toward the player and, while the tree still stands, needles or leaves drift down.
func use_impact(player: Node, _stack: ItemStack, _action: Dictionary, hit: Dictionary) -> void:
	var toward := -_away_from(player)
	var r := (0.3 if kind == 0 else 0.34) * tree_scale
	var aim: Vector3 = hit.get("point", global_position + Vector3(0, 1.1, 0))
	var at := global_position + toward * r + Vector3(0, clampf(aim.y - global_position.y, 0.5, 1.7), 0)
	Fx.wood_chips(at, toward)
	if hp > 1 and _mesh.mesh:
		var crown := _mesh.mesh.get_aabb().end.y * tree_scale * 0.72
		Fx.leaves(global_position + Vector3(0, crown, 0), Vector2(1.2, 1.2) * tree_scale, kind == 0)


func complete_use(player: Node, _stack: ItemStack, _action: Dictionary) -> void:
	hp -= 1
	if hp <= 0:
		_fall(player)
	else:
		_shake(player)


## The trunk shudders away from the blow, after the axe's bite (ToolAnim.HIT_STOP).
func _shake(player: Node) -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	var dir := _away_from(player)
	var axis := Vector3.UP.cross(global_basis.inverse() * dir).normalized()
	var lean := 0.04 / sqrt(maxf(tree_scale, 0.5))
	_shake_tween = create_tween()
	_shake_tween.tween_interval(ToolAnim.HIT_STOP)
	_shake_tween.tween_method(func(a: float): _pivot.basis = Basis(axis, a), 0.0, lean, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_shake_tween.tween_method(func(a: float): _pivot.basis = Basis(axis, a), lean, -lean * 0.55, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shake_tween.tween_method(func(a: float): _pivot.basis = Basis(axis, a), -lean * 0.55, lean * 0.25, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_shake_tween.tween_method(func(a: float): _pivot.basis = Basis(axis, a), lean * 0.25, 0.0, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _away_from(player: Node) -> Vector3:
	var d := global_position - (player as Node3D).global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD


func _fall(player: Node) -> void:
	felled = true
	FarmState.depleted[resource_id] = GameClock.day
	remove_from_group(&"interactable")
	_trunk_shape.set_deferred("disabled", true)
	_stump_shape.set_deferred("disabled", false)
	_stump.visible = true
	var dir := _away_from(player)
	var axis := Vector3.UP.cross(global_basis.inverse() * dir).normalized()
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	# The trunk gives with a creak, then goes over.
	Audio.play("creak", global_position + Vector3(0, 3.0, 0), -4.0, 0.05, &"Effects", 8.0)
	var tw := create_tween()
	tw.tween_interval(ToolAnim.HIT_STOP)
	tw.tween_method(func(a: float): _pivot.basis = Basis(axis, a), 0.0, PI * 0.47, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_method(func(a: float): _pivot.basis = Basis(axis, a), PI * 0.47, PI * 0.43, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float): _pivot.basis = Basis(axis, a), PI * 0.43, PI * 0.5, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(_on_landed.bind(dir))
	tw.tween_interval(0.6)
	tw.tween_property(_pivot, "position:y", -1.2, 1.0)
	tw.tween_callback(func(): _pivot.visible = false; _pivot.position.y = 0.0; _pivot.basis = Basis())


func _on_landed(dir: Vector3) -> void:
	var at := global_position + dir * 3.0 + Vector3(0, 0.3, 0)
	Fx.dust_cloud(at, Vector2(1.5, 1.5))
	# A heavy thud and the ground shaking under the player when it is close.
	Audio.play("wood_hit", at, 0.0, 0.05, &"Effects", 10.0, 0.55)
	Audio.play("plank", at, -4.0, 0.08, &"Effects", 10.0, 0.6)
	var player := Game.player as Player
	if player and is_instance_valid(player):
		player.add_trauma(0.35 * clampf(1.0 - player.global_position.distance_to(at) / 14.0, 0.0, 1.0))
	var rng := RandomNumberGenerator.new()
	var count := roundi(rng.randf_range(6, 9) * tree_scale) if kind == 0 else roundi(rng.randf_range(8, 12) * tree_scale)
	for i in count:
		var along := rng.randf_range(0.8, 5.5) * tree_scale
		var p := global_position + dir * along + Vector3(rng.randf_range(-0.4, 0.4), 0.6, rng.randf_range(-0.4, 0.4))
		var s := ItemStack.create(&"wood", 1)
		Pickup.spawn(s, p, Vector3(rng.randf_range(-1, 1), 2.0, rng.randf_range(-1, 1)), true)


func _set_felled(value: bool) -> void:
	felled = value
	_pivot.visible = not value
	_stump.visible = value
	_trunk_shape.disabled = value
	_stump_shape.disabled = not value
	if value:
		remove_from_group(&"interactable")
	else:
		add_to_group(&"interactable")


func _on_day_started(day: int) -> void:
	if felled and day - int(FarmState.depleted.get(resource_id, day)) >= REGROW_DAYS:
		FarmState.depleted.erase(resource_id)
		hp = max_hp()
		_set_felled(false)
		_pivot.scale = Vector3.ONE * 0.2
		var tw := create_tween()
		tw.tween_property(_pivot, "scale", Vector3.ONE, 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
