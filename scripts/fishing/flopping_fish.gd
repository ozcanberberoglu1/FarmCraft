class_name FloppingFish
extends Node3D
## A caught fish: it flies out of the pond on the line in an arc, thrashing, and lands on
## the bank near the player, where it flops about on its side (hops that twist and turn
## it over, the tail slapping the ground, gills working) and slowly tires, until the
## player picks it up with E. The old boot comes out the same way and just lies there.
## Its body bends through shaders/fish.gdshader (FishModels.flop_mesh). A trophy (a giant of
## its species, FishTable.trophy_of) is the species' model drawn at the giant's size: it
## lands with a heavy thud and flops slower and lower.

signal landed

const GRAVITY := 9.8
## Seconds a fish keeps flopping before it lies still (twitching now and then).
const STAMINA := 32.0

var item_id: StringName
## The species whose model it is (a trophy's species; else item_id).
var species: StringName
var kg := 1.0
var quality := 0
## The model's size factor (a heavier fish is bigger).
var size := 1.0

var _mi: MeshInstance3D
var _body: StaticBody3D
var _junk := false
## Half the fish's thickness, and half its length (scaled): it lies on its side at the first.
var _half_w := 0.03
var _half_len := 0.15
var _energy := 1.0
var _age := 0.0
## 0 flying out of the water, 1 in the air on a hop, 2 lying on the ground.
var _state := 0
var _t := 0.0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _flight := 1.0
var _apex := 2.0
var _vel := Vector3.ZERO
var _yaw := 0.0
var _yaw_rate := 0.0
## Turn about its own length: +-PI/2 lying on one flank or the other.
var _roll := PI * 0.5
var _roll_from := PI * 0.5
var _roll_to := PI * 0.5
var _hop_time := 0.4
var _next_hop := 0.6
var _flex := 0.0
var _flex_phase := 0.0
var _curl := 0.0
var _twitch := 0.0
var _ground_y := 0.0
var _rng := RandomNumberGenerator.new()


## A fish of `catch` (FishTable.catch_of) flying from `from` (on the water) to `to` (on the
## ground) in `seconds`.
static func launch(catch: Dictionary, from: Vector3, to: Vector3, seconds: float) -> FloppingFish:
	var f := FloppingFish.new()
	f.item_id = catch["id"]
	f.species = catch.get("species", catch["id"])
	f.kg = float(catch["kg"])
	f.quality = int(catch["quality"])
	f.size = float(catch["scale"])
	f._from = from
	f._to = to
	f._flight = seconds
	Game.world.add_child(f)
	f.global_position = from
	f.reset_physics_interpolation()
	return f


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_to_group(&"interactable")
	add_to_group(&"caught_fish")
	_rng.randomize()
	if species == &"":
		species = FishTable.species_of(item_id)
	_junk = not FishTable.is_fish(species)
	_mi = MeshInstance3D.new()
	_mi.mesh = FishModels.real_mesh(species) if _junk else FishModels.flop_mesh(species)
	_mi.scale = Vector3.ONE * size
	_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_mi.layers = 2
	if _junk:
		# The boot stands on its sole in its model: laid along X like a fish.
		var aabb := _mi.mesh.get_aabb()
		_mi.rotation = Vector3(0.0, 0.0, -PI * 0.5)
		_mi.position = Vector3(-aabb.get_center().y, 0.0, 0.0) * size
	add_child(_mi)
	# Cartoon eyes ("Komik hayvanlar" setting): rolling as it flops.
	ComicFx.dress_fish(_mi, species, ComicEyes.Mood.FLOP)
	var box := _mi.mesh.get_aabb()
	var extent := box.size * size
	if _junk:
		extent = Vector3(extent.y, extent.x, extent.z)
	_half_len = extent.x * 0.5
	_half_w = maxf(extent.z * 0.5, 0.012)
	# What the aim finds: a ball over the fish that doesn't turn with it, so it stands
	# clear of the ground whichever way the fish lies (on a slope too).
	_body = StaticBody3D.new()
	_body.top_level = true
	_body.collision_layer = 4
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = clampf(_half_len * 0.85, 0.15, 0.45)
	cs.shape = shape
	_body.add_child(cs)
	add_child(_body)
	# Off until it has landed (nothing to take in mid-air).
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	_yaw = atan2(-(_to - _from).z, (_to - _from).x)
	_apex = clampf(_from.distance_to(_to) * 0.28, 1.2, 3.2)
	_set_bend(1.0, 0.0, 0.0)


func interact_prompt(_player: Node) -> String:
	if _state == 0:
		return ""
	return tr("ACTION_TAKE_ITEM") % ItemDB.get_item(item_id).display_name()


func interact_title() -> String:
	if _state == 0 or _junk:
		return ""
	return "%s · %s" % [ItemDB.get_item(item_id).display_name(), weight_text(kg)]


func interact(player: Node) -> void:
	if _state == 0:
		return
	var left := PlayerState.inventory.add_item(item_id, 1, quality)
	if left > 0:
		Game.notify(tr("MSG_INVENTORY_FULL"), Color(1.0, 0.5, 0.4))
		return
	var item := ItemDB.get_item(item_id)
	Game.notify("+1x %s" % item.display_name())
	Events.item_picked_up.emit(item_id, 1)
	if not _junk:
		Events.fish_caught.emit(item_id)
	if player is Player:
		# The item's model flies from here into the hand (or the hotbar).
		var k := 1.0
		if not _junk:
			k = (_half_len * 2.0) / maxf(ItemModels.mesh(item_id).get_aabb().size.x, 0.01) / size
		(player as Player).show_take(item_id, _mi.global_transform * Transform3D(Basis.from_scale(Vector3.ONE * k), Vector3.ZERO))
	queue_free()


## "2.4 kg" with the language's decimal mark.
static func weight_text(value: float) -> String:
	var s := ("%.2f" % value) if value < 1.0 else ("%.1f" % value)
	if TranslationServer.get_locale().substr(0, 2) in ["tr", "de", "es", "fr", "it", "pt", "ru", "pl"]:
		s = s.replace(".", ",")
	return s + " kg"


## Where the line is tied on: the fish's mouth.
func mouth() -> Vector3:
	return global_transform * (Vector3(_half_len, 0.0, 0.0))


func is_flying() -> bool:
	return _state == 0


func _physics_process(delta: float) -> void:
	_age += delta
	_t += delta
	match _state:
		0:
			_fly(delta)
		1:
			_hop(delta)
		2:
			_lie(delta)
	_apply()


func _fly(delta: float) -> void:
	var u := clampf(_t / _flight, 0.0, 1.0)
	var p := _from.lerp(_to, u) + Vector3.UP * _apex * 4.0 * u * (1.0 - u)
	global_position = p
	# Spinning about its length and thrashing all the way.
	_roll += delta * 7.0
	_flex_phase += delta * 24.0
	_flex = 1.0
	_curl = sin(_t * 9.0) * 0.5
	if u >= 1.0:
		_state = 2
		_t = 0.0
		_ground_y = _ground_at(_to)
		_roll = PI * 0.5 if sin(_roll) >= 0.0 else -PI * 0.5
		global_position = Vector3(_to.x, _ground_y + _half_w, _to.z)
		_body.process_mode = Node.PROCESS_MODE_INHERIT
		_slap(1.3)
		Fx.drips(global_position)
		if FishTable.is_trophy(item_id):
			# The giant comes down hard: a deep thud the farmer feels, water off its flanks.
			_slap(1.5)
			Fx.drips(global_position + global_basis.x * _half_len * 0.5)
			Fx.drips(global_position - global_basis.x * _half_len * 0.5)
			Fx.dirt_burst(Vector3(global_position.x, _ground_y + 0.02, global_position.z), 0.5 + _half_len * 0.4)
			var player := Game.player as Player
			if player and player.global_position.distance_to(global_position) < 8.0:
				player.add_trauma(0.35)
		_next_hop = _rng.randf_range(0.15, 0.4)
		landed.emit()


func _hop(delta: float) -> void:
	_vel.y -= GRAVITY * delta
	global_position += _vel * delta
	_yaw += _yaw_rate * delta
	var u := clampf(_t / _hop_time, 0.0, 1.0)
	_roll = lerpf(_roll_from, _roll_to, smoothstep(0.0, 1.0, u))
	_flex_phase += delta * 26.0
	_flex = lerpf(_flex, 0.9 * (0.4 + 0.6 * _energy), clampf(delta * 12.0, 0.0, 1.0))
	_curl = sin(_t * 14.0) * 0.7 * _energy
	var floor_y := _ground_at(global_position) + _half_w
	if _vel.y < 0.0 and global_position.y <= floor_y:
		global_position.y = floor_y
		_ground_y = floor_y - _half_w
		_roll = _roll_to
		if _vel.y < -1.4 and _energy > 0.3:
			# A little bounce off the ground.
			_vel = Vector3(_vel.x * 0.4, -_vel.y * 0.22, _vel.z * 0.4)
			_slap(0.6)
			return
		_slap(1.0)
		_state = 2
		_t = 0.0
		_next_hop = _rng.randf_range(0.35, 1.0) / maxf(sqrt(_energy), 0.35)


func _lie(delta: float) -> void:
	_energy = clampf(1.0 - _age / STAMINA, 0.0, 1.0)
	# Tail fluttering and gills working while it lies there, less as it tires.
	_flex_phase += delta * lerpf(4.0, 12.0, _energy)
	_flex = lerpf(_flex, 0.12 + 0.28 * _energy, clampf(delta * 6.0, 0.0, 1.0))
	_curl = sin(_age * 2.1) * 0.08 * (0.3 + _energy)
	if _twitch > 0.0:
		_twitch -= delta
		_flex = 0.7
		_flex_phase += delta * 20.0
	if _junk:
		_flex = 0.0
		_curl = 0.0
		return
	_next_hop -= delta
	if _next_hop > 0.0:
		return
	if _energy <= 0.05:
		# Worn out: only a twitch now and then.
		_twitch = 0.35
		_next_hop = _rng.randf_range(4.0, 9.0)
		return
	_start_hop()


func _start_hop() -> void:
	var e := _energy
	var height := lerpf(0.05, 0.24, e) * _rng.randf_range(0.7, 1.15) / clampf(sqrt(size * _half_len * 4.0), 0.7, 1.6)
	_vel = Vector3.UP * sqrt(2.0 * GRAVITY * height)
	var dir := Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized()
	var drift := _rng.randf_range(0.1, 0.55) * e
	# Never back into the pond.
	if Pond.is_fishable(global_position + dir * 0.6):
		dir = -dir
	_vel += dir * drift
	_hop_time = 2.0 * _vel.y / GRAVITY
	_yaw_rate = _rng.randf_range(-4.0, 4.0) * (0.4 + e)
	_roll_from = _roll
	# Now and then it turns over onto its other side.
	_roll_to = -_roll if _rng.randf() < 0.35 else _roll
	_state = 1
	_t = 0.0


func _apply() -> void:
	var yaw_basis := Basis(Vector3.UP, _yaw)
	global_basis = yaw_basis * Basis(Vector3.RIGHT, _roll)
	_body.global_position = global_position + Vector3.UP * 0.06
	_set_bend(_flex, _flex_phase, _curl)


func _set_bend(flex: float, phase: float, curl: float) -> void:
	if _junk or _mi == null:
		return
	_mi.set_instance_shader_parameter(&"flex", flex)
	_mi.set_instance_shader_parameter(&"flex_phase", phase)
	_mi.set_instance_shader_parameter(&"curl", curl)


## The body slapping the ground (strength about 1): heavier fish sound deeper.
func _slap(strength: float) -> void:
	var pitch := clampf(1.25 - _half_len * 0.9, 0.7, 1.2)
	FishingAudio.play("flop", global_position, linear_to_db(clampf(strength, 0.2, 1.5)) + (-4.0 if _junk else 0.0), pitch)
	if strength > 0.8:
		Fx.wet_spot(Vector3(global_position.x, _ground_y, global_position.z), 0.08 + _half_len * 0.4)


## The ground under `p` (the terrain, or whatever stands on it).
func _ground_at(p: Vector3) -> float:
	var h := TerrainData.height(p.x, p.z)
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, maxf(p.y, h) + 1.0, p.z), Vector3(p.x, h - 0.5, p.z), 1)
		q.exclude = [_body.get_rid()] if _body else []
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return (hit["position"] as Vector3).y
	return h
