class_name CrateHen
extends Node3D
## A live hen sitting in a poultry transport crate (the truck bed, the warehouse crate
## corner, the town stall): the chicken rig, a little smaller, settled down on the
## straw and looking about through the slats, now and then shuffling or clucking.
## Stands on the crate's bottom centre (the package frame of CargoModels: long side
## along +X). Only animates while the camera is close; beyond that it holds still.

## Hens in crates are a little smaller than the birds in the run (a laying breed, and
## the crate would crowd a big one).
const SCALE := 0.7
## Metres within which the hen moves and clucks.
const AWAKE_RANGE := 26.0
## Animated at this rate (s) while awake: a sitting hen needs no more.
const TICK := 1.0 / 30.0

## Who sits in the crate (a hen, or a rooster in his crate: AnimalTable.species_of_crate).
var species := &"chicken"
## Coat variant (AnimalModels.VARIANTS[species]), usually the slot or crate index.
var variant := 0
var shadows := true
## Voice now and then (off where a crowd of crates would make a racket).
var voice := true
## Metres at which the hen stops being drawn (match the crate she sits in).
var view_range := 60.0
var rig: AnimalRig

var _cluck := 0.0
var _tick := 0.0
## A shuffle: the hen turns a little on the spot now and then.
var _turn := 0.0
var _turn_to := 0.0
var _shuffle := 0.0


func _ready() -> void:
	rig = AnimalModels.create_rig(species)
	rig.scale = Vector3.ONE * SCALE
	rig.position = Vector3(0, 0.03, 0)
	add_child(rig)
	rig.set_variant(variant % AnimalModels.variant_count(species), false)
	for g in rig.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.visibility_range_end = view_range
	# Rigs face -Z; the crate's long side is X: she sits along it, head to one end.
	_turn = PI * 0.5 if variant % 2 == 0 else -PI * 0.5
	_turn_to = _turn
	rig.rotation.y = _turn
	# Settle into the crate straight away (the lie-down blend takes a moment).
	for i in 50:
		rig.animate(0.05, 0.0, AnimalRig.Mode.SLEEP)
	var rng := RandomNumberGenerator.new()
	rng.seed = variant * 31 + 7
	_cluck = rng.randf_range(3.0, 14.0)
	_shuffle = rng.randf_range(4.0, 12.0)
	_tick = rng.randf() * TICK


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_squared_to(global_position) > AWAKE_RANGE * AWAKE_RANGE:
		return
	_tick += delta
	if _tick < TICK:
		return
	var dt := _tick
	_tick = 0.0
	# Now and then she shifts round a little, the way a boxed hen fidgets.
	_shuffle -= dt
	if _shuffle <= 0.0:
		_shuffle = randf_range(5.0, 14.0)
		var base := PI * 0.5 if variant % 2 == 0 else -PI * 0.5
		_turn_to = base + randf_range(-0.45, 0.45)
	if absf(_turn - _turn_to) > 0.001:
		_turn = move_toward(_turn, _turn_to, dt * 1.2)
		rig.rotation.y = _turn
	rig.animate(dt, 0.0, AnimalRig.Mode.SLEEP)
	if voice:
		_cluck -= dt
		if _cluck <= 0.0:
			_cluck = randf_range(8.0, 22.0)
			Audio.animal_voice(species, true, global_position, -14.0)
