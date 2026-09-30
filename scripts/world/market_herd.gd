class_name MarketHerd
extends Node3D
## The Animal Market's animals on show (Town._animal_market): a few of every kind the
## market sells, living in their pens and the coop run. They are plain rigs, never the
## player's: no physics, needs or saving, and they stay out of Animals. One node walks
## them all, and only while the camera is near; farther off they hold still, then go out
## of sight. Hens peck about the run, sheep and cattle graze and amble, horses doze and
## swish; the young keep close to their mothers. Now and then one of them calls (the
## rooster crows in the morning). At night the grazers lie down and the hens settle.

## Metres from the camera within which the animals move (beyond, they hold still).
const AWAKE_RANGE := 75.0
## Metres at which they stop being drawn.
const VIEW_RANGE := 140.0
## Animated at this rate (s) while awake.
const TICK := 1.0 / 30.0
## A call is heard only this close.
const VOICE_RANGE := 45.0

## One animal on show.
class Beast:
	var species: StringName
	var adult := true
	var rig: AnimalRig
	## Where it may go (world XZ) and the spots inside it to keep out of (a trough, the
	## henhouse).
	var pen := Rect2()
	var avoid: Array[Rect2] = []
	## The grown one a young one keeps close to (null for the grown).
	var mother: Beast
	var pos := Vector3.ZERO
	var yaw := 0.0
	var speed := 0.0
	var max_speed := 0.8
	var radius := 0.4
	## Half its length: how far its head or rump reaches from where it stands.
	var reach := 0.5
	var target := Vector3.INF
	var mode: int = AnimalRig.Mode.IDLE
	var timer := 0.0

var beasts: Array[Beast] = []
var _tick := 0.0
var _voice := 5.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "MarketHerd"
	_rng.seed = 5171


## Puts `adults` grown animals of `species` (and `young` of their young) into `pen`
## (world XZ), keeping out of `avoid`. Species without a model of their own (a bird
## added later) borrow the hen's.
func add_pen(pen: Rect2, species: StringName, adults: int, young := 0, avoid: Array[Rect2] = []) -> void:
	var info := AnimalTable.get_species(species)
	var mothers: Array[Beast] = []
	for i in adults + young:
		var b := Beast.new()
		b.species = species
		b.adult = i < adults
		b.pen = pen
		b.avoid = avoid
		b.max_speed = float(info.get("speed", 0.8)) * (0.7 if b.adult else 0.85)
		b.rig = AnimalModels.create_rig(model_of(species))
		var variants := AnimalModels.variant_count(model_of(species))
		b.rig.set_variant((i * 2 + int(pen.size.x)) % variants, not b.adult)
		b.rig.set_age(1.0 if b.adult else 0.35)
		b.rig.set_wool(1.0)
		b.radius = float(info.get("radius", 0.4)) * b.rig.scale.x
		b.reach = maxf(b.radius, (info.get("size", Vector3.ONE) as Vector3).z * 0.5 * b.rig.scale.x)
		for g in b.rig.find_children("*", "GeometryInstance3D", true, false):
			var gi := g as GeometryInstance3D
			gi.visibility_range_end = VIEW_RANGE
			gi.visibility_range_end_margin = 8.0
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(b.rig)
		if b.adult:
			mothers.append(b)
			b.pos = _free_spot(b)
		elif mothers.is_empty():
			b.pos = _free_spot(b)
		else:
			b.mother = mothers[i % mothers.size()]
			b.pos = _constrain(b, b.mother.pos + Vector3(0.9, 0, 0.6))
		b.yaw = _rng.randf() * TAU
		b.timer = _rng.randf_range(0.5, 6.0)
		b.mode = AnimalRig.Mode.GRAZE if _rng.randf() < 0.5 else AnimalRig.Mode.IDLE
		_place(b)
		# Settle into the pose straight away (no bind pose on the first frame).
		for k in 12:
			b.rig.animate(0.05, 0.0, b.mode)
		beasts.append(b)


## The model a species is shown with: its own, else (a bird without one yet) the hen's.
static func model_of(species: StringName) -> StringName:
	if AnimalModels.VARIANTS.has(species) or PhotoRig.available(species) or ResourceLoader.exists(AnimalRig.SCULPT_PATH % species):
		return species
	return &"chicken" if String(AnimalTable.get_species(species).get("housing", "")) == "coop" else &"sheep"


## How many animals of `species` are on show.
func count(species: StringName) -> int:
	var n := 0
	for b in beasts:
		if b.species == species:
			n += 1
	return n


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or beasts.is_empty():
		return
	var near := false
	var cp := cam.global_position
	for b in beasts:
		if b.pos.distance_squared_to(cp) < AWAKE_RANGE * AWAKE_RANGE:
			near = true
			break
	if not near:
		return
	_tick += delta
	if _tick < TICK:
		return
	var dt := minf(_tick, 0.1)
	_tick = 0.0
	var night := GameClock.is_night()
	for b in beasts:
		_think(b, dt, night)
		_move(b, dt)
		_place(b)
		b.rig.animate(dt, b.speed, b.mode)
	_voice -= dt
	if _voice <= 0.0:
		_voice = _rng.randf_range(7.0, 16.0)
		_call(cp, night)


func _think(b: Beast, dt: float, night: bool) -> void:
	b.timer -= dt
	if night:
		# Settled for the night where they stand (hens by their house).
		if b.mode != AnimalRig.Mode.SLEEP and b.target == Vector3.INF:
			b.mode = AnimalRig.Mode.SLEEP
		if b.mode == AnimalRig.Mode.SLEEP:
			return
	elif b.mode == AnimalRig.Mode.SLEEP:
		b.mode = AnimalRig.Mode.IDLE
		b.timer = _rng.randf_range(1.0, 4.0)
	if b.target != Vector3.INF or b.timer > 0.0:
		return
	# A young one wanders off only a little way from its mother.
	if b.mother and b.pos.distance_to(b.mother.pos) > 2.2:
		b.target = _constrain(b, b.mother.pos + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0)))
		b.mode = AnimalRig.Mode.WALK
		return
	var roll := _rng.randf()
	if roll < 0.38:
		b.target = _free_spot(b) if b.mother == null else _constrain(b, b.mother.pos + Vector3(_rng.randf_range(-1.6, 1.6), 0, _rng.randf_range(-1.6, 1.6)))
		b.mode = AnimalRig.Mode.WALK
	elif roll < (0.6 if b.species == &"horse" else 0.8):
		b.mode = AnimalRig.Mode.GRAZE
		b.timer = _rng.randf_range(5.0, 14.0)
	else:
		b.mode = AnimalRig.Mode.IDLE
		b.timer = _rng.randf_range(3.0, 8.0)


func _move(b: Beast, dt: float) -> void:
	if b.target == Vector3.INF:
		b.speed = move_toward(b.speed, 0.0, dt * 2.0)
	else:
		var to := Vector3(b.target.x - b.pos.x, 0.0, b.target.z - b.pos.z)
		var dist := to.length()
		if dist < 0.3:
			b.target = Vector3.INF
			b.mode = AnimalRig.Mode.GRAZE if _rng.randf() < 0.55 else AnimalRig.Mode.IDLE
			b.timer = _rng.randf_range(3.0, 10.0)
		else:
			var dir := to / dist
			b.yaw = lerp_angle(b.yaw, atan2(-dir.x, -dir.z), clampf(dt * 3.0, 0.0, 1.0))
			var facing := Vector3(-sin(b.yaw), 0.0, -cos(b.yaw))
			var want := b.max_speed * (0.3 + 0.7 * maxf(0.0, facing.dot(dir)))
			b.speed = move_toward(b.speed, minf(want, dist * 2.0 + 0.2), dt * 1.5)
	var step := Vector3(-sin(b.yaw), 0.0, -cos(b.yaw)) * b.speed * dt
	# Keep a little apart from the others in the pen.
	for o in beasts:
		if o == b or o.pen != b.pen:
			continue
		var d := Vector3(b.pos.x - o.pos.x, 0.0, b.pos.z - o.pos.z)
		var min_d := b.radius + o.radius + 0.1
		var l := d.length()
		if l < min_d and l > 0.001:
			step += d / l * (min_d - l) * 2.0 * dt
	b.pos = _constrain(b, b.pos + step)
	if b.target == Vector3.INF and b.mode == AnimalRig.Mode.WALK:
		b.mode = AnimalRig.Mode.IDLE


func _place(b: Beast) -> void:
	b.pos.y = TerrainData.height(b.pos.x, b.pos.z)
	b.rig.position = b.pos
	b.rig.rotation.y = b.yaw


## `p` kept inside the pen (clear of its fence by the animal's length, whichever way
## it faces) and out of the spots to avoid.
func _constrain(b: Beast, p: Vector3) -> Vector3:
	var m := b.reach + 0.2
	p.x = clampf(p.x, b.pen.position.x + m, b.pen.end.x - m)
	p.z = clampf(p.z, b.pen.position.y + m, b.pen.end.y - m)
	for r in b.avoid:
		var g := r.grow(b.reach * 0.75)
		if g.has_point(Vector2(p.x, p.z)):
			# Out through the nearest side.
			var dl := p.x - g.position.x
			var dr := g.end.x - p.x
			var dt := p.z - g.position.y
			var db := g.end.y - p.z
			var least := minf(minf(dl, dr), minf(dt, db))
			if least == dl:
				p.x = g.position.x
			elif least == dr:
				p.x = g.end.x
			elif least == dt:
				p.z = g.position.y
			else:
				p.z = g.end.y
	return p


## A spot in the pen clear of the spots to avoid and of the others.
func _free_spot(b: Beast) -> Vector3:
	var m := b.reach + 0.4
	var best := Vector3(b.pen.get_center().x, 0.0, b.pen.get_center().y)
	var best_d := -1.0
	for attempt in 8:
		var p := Vector3(_rng.randf_range(b.pen.position.x + m, b.pen.end.x - m), 0.0,
				_rng.randf_range(b.pen.position.y + m, b.pen.end.y - m))
		p = _constrain(b, p)
		var d := 99.0
		for o in beasts:
			if o != b and o.pen == b.pen:
				d = minf(d, Vector2(o.pos.x - p.x, o.pos.z - p.z).length())
		if d > best_d:
			best_d = d
			best = p
		if d > 2.5:
			break
	return best


## One of the animals near the camera calls out: the rooster in the morning.
func _call(cam: Vector3, night: bool) -> void:
	if night:
		return
	var near: Array[Beast] = []
	for b in beasts:
		if b.pos.distance_to(cam) < VOICE_RANGE:
			near.append(b)
	if near.is_empty():
		return
	var b := near[_rng.randi() % near.size()]
	var hour := GameClock.get_hour_float()
	if b.species == &"rooster" or (b.species == &"chicken" and hour < 8.0 and _rng.randf() < 0.25):
		Audio.play("rooster", b.pos + Vector3(0, 0.6, 0), -8.0, 0.03, &"Effects", 8.0)
		return
	Audio.animal_voice(model_of(b.species), b.adult, b.pos, -12.0)
