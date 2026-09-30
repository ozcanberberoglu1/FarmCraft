class_name Wildlife
extends Node3D
## Wild rabbits coming and going in the valley's meadows (NatureSpawner adds this). Every
## SPAWN_EVERY seconds, while fewer than the graphics preset allows are about, one may
## turn up (most likely at dawn and dusk, seldom at night) on open wild ground
## SPAWN_RANGE from the farmer, out of their sight if it can; ones left far behind are
## taken away. Not saved: the valley just has rabbits in it.
## Automated runs (tests, screenshots) bring none on their own; `-- --rabbits=N` brings
## N near the start for screenshots.

## Rabbits about at once per graphics preset (Settings.Quality LOW..ULTRA).
const MAX_RABBITS: Array[int] = [2, 3, 4, 4]
const SPAWN_EVERY := 12.0
const SPAWN_RANGE := Vector2(32.0, 70.0)
const DESPAWN := 100.0

static var instance: Wildlife = null

## Bring rabbits on its own (off in automated runs).
var auto_spawn := true
var _timer := 3.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	instance = self
	_rng.randomize()
	RabbitRig.preload_model()
	auto_spawn = not DebugTools.is_automated()
	if DebugTools.args.has("rabbits"):
		_spawn_for_shots.call_deferred(int(DebugTools.args["rabbits"]))


func _exit_tree() -> void:
	if instance == self:
		instance = null


func rabbits() -> Array[WildRabbit]:
	var out: Array[WildRabbit] = []
	for n in get_children():
		if n is WildRabbit and not n.is_queued_for_deletion():
			out.append(n)
	return out


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SPAWN_EVERY
	var player := Game.player as Node3D
	if player == null or not is_instance_valid(player):
		return
	var here := player.global_position
	for r in rabbits():
		if Vector2(r.global_position.x - here.x, r.global_position.z - here.z).length() > DESPAWN:
			r.queue_free()
	if not auto_spawn or rabbits().size() >= MAX_RABBITS[Settings.quality]:
		return
	if _rng.randf() < _chance():
		spawn_near(here, SPAWN_RANGE.x, SPAWN_RANGE.y, true)


## The chance a try brings one, by the time of day.
func _chance() -> float:
	var h := GameClock.get_hour_float()
	if (h >= 5.0 and h < 9.0) or (h >= 17.0 and h < 21.0):
		return 0.8
	if h >= 9.0 and h < 17.0:
		return 0.45
	return 0.15


## A rabbit at `at` (on the ground), facing `yaw`.
func spawn(at: Vector3, yaw := 0.0) -> WildRabbit:
	var r := WildRabbit.new()
	r.name = "Rabbit"
	r.position = Vector3(at.x, TerrainData.height(at.x, at.z), at.z)
	r.rotation.y = yaw
	add_child(r, true)
	return r


## A rabbit on open wild ground `min_r`..`max_r` m from `center` (grassy, off the tracks),
## out of the camera's view when `hidden` and it can be; null when there is no room.
func spawn_near(center: Vector3, min_r: float, max_r: float, hidden := false) -> WildRabbit:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var fallback := Vector3.INF
	for i in 60:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(min_r, max_r)
		var p := center + Vector3(cos(a) * d, 0.0, sin(a) * d)
		if not WildRabbit.ground_ok(p.x, p.z) or TerrainData.path_at(p.x, p.z) > 0.1:
			continue
		p.y = TerrainData.height(p.x, p.z)
		if hidden and cam and cam.is_position_in_frustum(p + Vector3(0, 0.2, 0)):
			if fallback == Vector3.INF:
				fallback = p
			continue
		return spawn(p, _rng.randf() * TAU)
	return spawn(fallback, _rng.randf() * TAU) if fallback != Vector3.INF else null


func _spawn_for_shots(count: int) -> void:
	var player := Game.player as Node3D
	if player == null:
		return
	for i in count:
		spawn_near(player.global_position, 6.0, 14.0)
