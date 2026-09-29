class_name FishingAudio
extends RefCounted
## The fishing sounds (art/audio/sfx/fishing, built by tools/fetch_fishing.py): the cast's
## swish, the float's plop, nibbles, the bite's thrashing, the fish pulled out of the
## water, the reel winding in and a fish slapping the ground. Played like Audio's
## one-shots (positional, on the Effects bus, never the same take twice in a row);
## headless runs play nothing.

const DIR := "res://art/audio/sfx/fishing/"
## Set -> [volume dB, unit size (m)].
const SETS := {
	"cast": [-6.0, 3.0], "plop": [-3.0, 5.0], "nibble": [-6.0, 4.0], "bite": [0.0, 6.0], "splash": [-1.0, 6.0],
	"reel": [-8.0, 2.5], "flop": [-4.0, 3.5],
}

static var _files := {}
static var _last := {}


static func _takes(set_name: String) -> Array:
	if not _files.has(set_name):
		var out := []
		for i in 10:
			var path := DIR + "%s_%d.ogg" % [set_name, i]
			if ResourceLoader.exists(path):
				out.append(load(path))
		_files[set_name] = out
	return _files[set_name]


## Loads every take ahead (the rod coming into the hand), so the first cast doesn't read
## files mid-swing.
static func preload_all() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for set_name: String in SETS:
		_takes(set_name)


## Plays a take of `set_name` at `at`; returns the player (to fade out or stop) or null.
static func play(set_name: String, at: Vector3, volume_offset := 0.0, pitch := 1.0, pitch_var := 0.07) -> AudioStreamPlayer3D:
	if DisplayServer.get_name() == "headless" or Engine.get_main_loop() == null:
		return null
	var files := _takes(set_name)
	if files.is_empty():
		return null
	var stream: AudioStream = files.pick_random()
	if files.size() > 1 and stream == _last.get(set_name):
		stream = files[(files.find(stream) + randi_range(1, files.size() - 1)) % files.size()]
	_last[set_name] = stream
	var cfg: Array = SETS.get(set_name, [0.0, 4.0])
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = &"Effects"
	p.volume_db = float(cfg[0]) + volume_offset
	p.unit_size = float(cfg[1])
	p.max_distance = float(cfg[1]) * 14.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.panning_strength = 0.9
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	p.finished.connect(p.queue_free)
	Audio.add_child(p)
	p.global_position = at
	p.play()
	return p


## Fades a sound out and frees it.
static func fade(p: Variant, seconds := 0.2) -> void:
	if p == null or not is_instance_valid(p) or not p is AudioStreamPlayer3D:
		return
	var tw := (p as AudioStreamPlayer3D).create_tween()
	tw.tween_property(p, "volume_db", -50.0, seconds)
	tw.tween_callback(p.queue_free)
