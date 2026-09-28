class_name BreakableRock
extends StaticBody3D
## A boulder broken with the pickaxe for stone (and iron ore in the quarry).
## Broken rocks come back after a few days.

const RESPAWN_DAYS := 5

var rock_seed := 1
var size := 1.0
var quarry := false
var resource_id := ""
var hp := 1
var broken := false

var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _shake_tween: Tween


func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"rocks")
	var shape_size := snappedf(size, 0.1)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = NatureModels.rock(rock_seed, shape_size)
	# Shaken and shrunk by tweens outside the physics step.
	_mesh.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_mesh)
	_shape = CollisionShape3D.new()
	_shape.shape = NatureModels.rock_shape(rock_seed, shape_size)
	add_child(_shape)
	hp = max_hp()
	# Editor previews (tool spawner) have no game state.
	if Engine.is_editor_hint():
		return
	if FarmState.depleted.has(resource_id):
		_set_broken(true)
	Events.day_started.connect(_on_day_started)


func max_hp() -> int:
	return clampi(roundi(2.0 + size * 2.5), 2, 7)


func interact_prompt(_player: Node) -> String:
	return ""


func use_prompt(player: Node, stack: ItemStack) -> String:
	var a := use_action(player, stack)
	return tr(a["verb"]) if not a.is_empty() else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	if broken or stack == null or stack.item.tool_type != &"pickaxe":
		return {}
	return {"id": "break", "verb": "ACTION_BREAK", "label": "PROGRESS_BREAKING", "duration": 0.75, "wear": true}


## A blow landing (the look only): chips and sparks fly off where the pick struck.
func use_impact(player: Node, _stack: ItemStack, _action: Dictionary, hit: Dictionary) -> void:
	var toward := (player as Node3D).global_position - global_position
	toward.y = 0.0
	toward = toward.normalized() if toward.length() > 0.01 else Vector3.BACK
	var at: Vector3 = hit.get("point", global_position + toward * 0.6 * size + Vector3(0, 0.5 * size, 0))
	var normal: Vector3 = hit.get("normal", toward)
	Fx.stone_chips(at, (normal + toward * 0.5).normalized())


func complete_use(_player: Node, _stack: ItemStack, _action: Dictionary) -> void:
	hp -= 1
	if hp <= 0:
		_break()
	else:
		# A jolt once the pick's 45 ms bite is over.
		if _shake_tween and _shake_tween.is_valid():
			_shake_tween.kill()
		_shake_tween = create_tween()
		_shake_tween.tween_interval(0.045)
		_shake_tween.tween_property(_mesh, "position:x", 0.03, 0.04)
		_shake_tween.tween_property(_mesh, "position:x", -0.03, 0.06)
		_shake_tween.tween_property(_mesh, "position:x", 0.0, 0.05)


func _break() -> void:
	FarmState.depleted[resource_id] = GameClock.day
	var rng := RandomNumberGenerator.new()
	var origin := global_position + Vector3(0, 0.6 * size, 0)
	Fx.dust_cloud(origin, Vector2(size, size))
	# The boulder splits with a deep crack that shakes the view.
	Audio.play("mining", origin, 0.0, 0.05, &"Effects", 6.0, 0.7)
	var player := Game.player as Player
	if player and is_instance_valid(player):
		player.add_trauma(0.3 * clampf(1.0 - player.global_position.distance_to(origin) / 8.0, 0.0, 1.0))
	var stones := roundi(rng.randf_range(2, 4) * (0.6 + size * 0.5))
	var ore := 0
	if quarry:
		ore = rng.randi_range(1, 2) if rng.randf() < 0.55 else 0
	elif rng.randf() < 0.1:
		ore = 1
	for i in stones + ore:
		var item := &"iron_ore" if i >= stones else &"stone"
		var dir := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		Pickup.spawn(ItemStack.create(item, 1), origin + dir * 0.4, dir * 1.2 + Vector3.UP * 2.4, true)
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3.ONE * 0.05, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(_set_broken.bind(true))


func _set_broken(value: bool) -> void:
	broken = value
	_mesh.visible = not value
	_mesh.scale = Vector3.ONE
	_shape.set_deferred("disabled", value)
	if value:
		remove_from_group(&"interactable")
	else:
		add_to_group(&"interactable")


func _on_day_started(day: int) -> void:
	if broken and day - int(FarmState.depleted.get(resource_id, day)) >= RESPAWN_DAYS:
		FarmState.depleted.erase(resource_id)
		hp = max_hp()
		_set_broken(false)
