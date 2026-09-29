class_name ChoppableTree
extends StaticBody3D
## A tree that can be chopped with the axe. The first blow cuts a notch where it lands,
## deeper with every blow; the last one breaks the trunk there: the part above goes over
## on its hinge, away from the player, and drops wood, and the part below stays standing
## as the stump. The stump regrows into a full tree a few days later.

const REGROW_DAYS := 4
## Heights the trunk is cut at, over the tree's origin (0.1 m under the ground): the
## notch goes in where the first blow lands, from a quarter metre to a metre and a half
## up.
const CUT_MIN := 0.35
const CUT_MAX := 1.6
## The cut of a stump saved before cuts were kept.
const CUT_DEFAULT := 0.6

var kind := 0
var variant := 1
var tree_scale := 1.0
var resource_id := ""
var hp := 1
var felled := false
## Where the trunk is cut: height over the tree's origin (m) and the notch's facing (its
## +X, about the tree's Y). Kept with the stump (FarmState.stumps).
var cut_height := CUT_DEFAULT
var cut_yaw := 0.0

var _pivot: Node3D
## The whole tree, and once felled the stump: the tree drawn up to the cut.
var _mesh: MeshInstance3D
## The felled trunk above the cut, turning on its hinge while it falls.
var _top: Node3D
var _fall_tween: Tween
var _trunk_shape: CollisionShape3D
var _stump_shape: CollisionShape3D
var _shake_tween: Tween
## The axe's notch, cut deeper with every blow (made by the first one).
var _notch: TreeNotch

## Each tree mesh's materials with the cut shaders (tree_bark_cut, tree_leaves_cut).
static var _cut_mats: Dictionary = {}


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
	_stump_shape.shape = s2
	_stump_shape.disabled = true
	add_child(_stump_shape)
	hp = max_hp()
	# Editor previews (tool spawner) have no game state.
	if Engine.is_editor_hint():
		return
	if FarmState.depleted.has(resource_id):
		var cut: Array = FarmState.stumps.get(resource_id, [])
		if cut.size() >= 2:
			cut_height = float(cut[0])
			cut_yaw = float(cut[1])
		_set_felled(true)
	Events.day_started.connect(_on_day_started)


func max_hp() -> int:
	return roundi((4.0 if kind == 0 else 5.0) * tree_scale)


## The trunk's centre (x, z) and mean bark radius (y) at the cut, in metres.
func _trunk() -> Vector3:
	var fallback := 0.3 if kind == 0 else 0.34
	var t := Vector3(0.0, fallback, 0.0)
	if _mesh.mesh:
		t = TreeNotch.trunk_at(_mesh.mesh, cut_height / tree_scale, fallback)
	return t * tree_scale


func _height() -> float:
	return (_mesh.mesh.get_aabb().end.y if _mesh.mesh else 8.0) * tree_scale


## Draws `mi` (a copy of the tree's mesh) as the stump (`side` 1: what lies under the
## cut), the falling trunk (-1: what lies over it) or whole (0).
func _show_cut(mi: MeshInstance3D, side: float) -> void:
	if mi.mesh == null:
		return
	if side == 0.0:
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, null)
		return
	var mats := _cut_materials(mi.mesh, kind == 0)
	for s in mi.mesh.get_surface_count():
		mi.set_surface_override_material(s, mats[s])
	var t := _trunk()
	mi.set_instance_shader_parameter(&"cut_origin", Vector4(t.x / tree_scale, cut_height / tree_scale, t.z / tree_scale, side))
	mi.set_instance_shader_parameter(&"cut_frame", Vector4(cos(cut_yaw), -sin(cut_yaw), t.y * (1.0 - TreeNotch.MAX_DEPTH),
			TreeNotch.MOUTH_SLOPE))
	mi.set_instance_shader_parameter(&"cut_wood", Vector4(t.y, tree_scale, float(absi(hash(resource_id)) % 997) * 0.1, 0.0))


## The stump's collision: as tall as the cut.
func _size_stump() -> void:
	(_stump_shape.shape as CylinderShape3D).height = cut_height
	_stump_shape.position.y = cut_height * 0.5


## A tree mesh's materials with the cut shaders (the same looks), and the fresh wood of
## the notch for the cut face.
static func _cut_materials(m: Mesh, pine: bool) -> Array[Material]:
	if _cut_mats.has(m):
		return _cut_mats[m]
	var out: Array[Material] = []
	var wood := TreeNotch._material(pine)
	for s in m.get_surface_count():
		var src := m.surface_get_material(s) as ShaderMaterial
		var leaves := src.shader.resource_path.contains("leaves")
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/tree_leaves_cut.gdshader" if leaves else "res://shaders/tree_bark_cut.gdshader")
		for u: Dictionary in src.shader.get_shader_uniform_list():
			mat.set_shader_parameter(u["name"], src.get_shader_parameter(u["name"]))
		for k: String in ["sapwood", "heartwood", "bark_color"]:
			mat.set_shader_parameter(k, wood.get_shader_parameter(k))
		out.append(mat)
	_cut_mats[m] = out
	return out


## Draws both sides of a cut for a moment, so their shaders are ready before the first
## tree falls.
static func warm_up(parent: Node, at: Vector3) -> void:
	for pine: bool in [true, false]:
		var m := NatureModels.pine(1) if pine else NatureModels.oak(1)
		var mats := _cut_materials(m, pine)
		var mi := MeshInstance3D.new()
		mi.mesh = m
		for s in m.get_surface_count():
			mi.set_surface_override_material(s, mats[s])
		parent.add_child(mi)
		mi.global_position = at
		mi.scale = Vector3.ONE * 0.01
		mi.get_tree().create_timer(0.5).timeout.connect(mi.queue_free)


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


## A blow landing (the look only; complete_use does the chopping): the notch bites
## deeper, bark chips and splinters fly out of it toward the player and, while the tree
## still stands, needles or leaves drift down.
func use_impact(player: Node, _stack: ItemStack, _action: Dictionary, hit: Dictionary) -> void:
	var toward := -_away_from(player)
	if _notch == null:
		_add_notch(toward, hit)
	# The blow that fells the tree cuts it to its full depth.
	_notch.cut_to(float(max_hp() - hp + 1) / float(max_hp()))
	Fx.wood_chips(_notch.mouth_point(), toward, kind == 0)
	if hp > 1 and _mesh.mesh:
		var crown := _mesh.mesh.get_aabb().end.y * tree_scale * 0.72
		Fx.leaves(global_position + Vector3(0, crown, 0), Vector2(1.2, 1.2) * tree_scale, kind == 0)


## The notch goes in where the first blow lands (from about the shin to the chest: a
## blow higher up cuts at chest height), facing the player, round the trunk as the tree's
## mesh has it at that height. The trunk will break there.
func _add_notch(toward: Vector3, hit: Dictionary) -> void:
	var aim: Vector3 = hit.get("point", global_position + Vector3(0, 1.1, 0))
	var local := global_basis.inverse() * toward
	cut_height = clampf(aim.y - global_position.y, CUT_MIN, CUT_MAX)
	cut_yaw = atan2(-local.z, local.x)
	var trunk := _trunk()
	_notch = TreeNotch.new()
	_pivot.add_child(_notch)
	_notch.setup(trunk.y, kind == 0)
	_notch.position = Vector3(trunk.x, cut_height, trunk.z)
	_notch.rotation = Vector3(0.0, cut_yaw, 0.0)


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
	var dir := _away_from(player)
	var local_dir := global_basis.inverse() * dir
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_pivot.basis = Basis()
	# The trunk breaks at the notch (one felled without a notch at knee height, the cut
	# facing the player): the tree left standing is the stump, cut there.
	if _notch:
		_notch.queue_free()
		_notch = null
	else:
		cut_height = CUT_DEFAULT
		cut_yaw = atan2(local_dir.z, -local_dir.x)
	FarmState.stumps[resource_id] = [cut_height, cut_yaw]
	_trunk_shape.set_deferred("disabled", true)
	_stump_shape.set_deferred("disabled", false)
	_size_stump()
	_show_cut(_mesh, 1.0)
	# The trunk above goes over on its hinge: the wood left behind the notch, on the side
	# it falls to.
	var trunk := _trunk()
	var hinge := Vector3(trunk.x, cut_height, trunk.z) + local_dir * trunk.y
	_top = Node3D.new()
	_top.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_top.position = hinge
	add_child(_top)
	var above := MeshInstance3D.new()
	above.mesh = _mesh.mesh
	above.scale = _mesh.scale
	above.lod_bias = _mesh.lod_bias
	above.position = -hinge
	_top.add_child(above)
	_show_cut(above, -1.0)
	var axis := Vector3.UP.cross(local_dir).normalized()
	# The trunk gives with a crack, then goes over. From a tall stump the crown reaches
	# the ground past level, the butt still on the stump; the hinge tears and the butt
	# drops off onto the ground.
	Audio.tree_falling(global_position + Vector3(0, 1.5, 0))
	var span := maxf(_height() - cut_height, 1.0)
	var down := PI * 0.47 + asin(clampf((cut_height - 0.1) / span, 0.0, 0.3))
	var rest := hinge + local_dir * 0.3
	rest.y = 0.05
	var drop := 0.2 + 0.08 * cut_height
	_fall_tween = create_tween()
	_fall_tween.tween_interval(ToolAnim.HIT_STOP)
	_fall_tween.tween_method(func(a: float): _top.basis = Basis(axis, a), 0.0, down, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fall_tween.tween_method(func(a: float): _top.basis = Basis(axis, a), down, down - PI * 0.04, 0.18).set_ease(Tween.EASE_OUT)
	_fall_tween.tween_method(func(a: float): _top.basis = Basis(axis, a), down - PI * 0.04, PI * 0.5, drop).set_ease(Tween.EASE_IN)
	_fall_tween.parallel().tween_property(_top, "position", rest, drop).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fall_tween.tween_callback(_on_landed.bind(dir))
	_fall_tween.tween_interval(0.6)
	_fall_tween.tween_property(_top, "position:y", rest.y - 1.2, 1.0)
	_fall_tween.tween_callback(_drop_top)


func _drop_top() -> void:
	if _top:
		_top.queue_free()
		_top = null


func _on_landed(dir: Vector3) -> void:
	var at := global_position + dir * 3.0 + Vector3(0, 0.3, 0)
	Fx.dust_cloud(at, Vector2(1.5, 1.5))
	if _mesh.mesh:
		# The crown lashes the ground: leaves or needles and snapped twigs fly up.
		var reach := _height() - cut_height
		Fx.crown_crash(global_position + dir * (reach * 0.65 + 0.3) + Vector3(0, 0.6, 0), Vector2(1.6, 1.6) * tree_scale, kind == 0)
	# A crash and a heavy thud, and the ground shaking under the player when it is close.
	Audio.tree_landed(at)
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
	_trunk_shape.disabled = value
	_stump_shape.disabled = not value
	_size_stump()
	_show_cut(_mesh, 1.0 if value else 0.0)
	if value:
		remove_from_group(&"interactable")
	else:
		add_to_group(&"interactable")


func _on_day_started(day: int) -> void:
	if felled and day - int(FarmState.depleted.get(resource_id, day)) >= REGROW_DAYS:
		FarmState.depleted.erase(resource_id)
		FarmState.stumps.erase(resource_id)
		hp = max_hp()
		if _fall_tween and _fall_tween.is_valid():
			_fall_tween.kill()
		_drop_top()
		if _notch:
			_notch.queue_free()
			_notch = null
		_set_felled(false)
		_pivot.scale = Vector3.ONE * 0.2
		var tw := create_tween()
		tw.tween_property(_pivot, "scale", Vector3.ONE, 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
