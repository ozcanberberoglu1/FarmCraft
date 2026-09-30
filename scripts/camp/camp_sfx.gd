class_name CampSfx
extends RefCounted
## The sounds of the campfire, cooking, eating and tiredness, the food table's knife,
## and a trophy fish (art/audio/sfx/camp, built by tools/build_camp_audio.py and
## tools/build_food_audio.py from Mixkit recordings; see art/audio/CREDITS.md):
## one-shots on short-lived players of their own, and the loops a fire keeps going
## (crackling, sizzling) as 3D players under it. Headless runs play nothing.

const DIR := "res://art/audio/sfx/camp/"
const SETS := {
	"fire_pop": ["fire_pop_0", "fire_pop_1", "fire_pop_2", "fire_pop_3", "fire_pop_4"],
	"match": ["match"], "ignite": ["ignite"], "douse": ["douse"],
	"bite": ["bite_0", "bite_1"], "chew": ["chew_0", "chew_1"], "yawn": ["yawn"],
	# The food table's knife and a trophy fish (tools/build_food_audio.py).
	"chop": ["chop_0", "chop_1", "chop_2", "chop_3", "chop_4"], "slice": ["slice"], "meat_hit": ["meat_hit"],
	"trophy": ["trophy"],
}

static var _streams := {}
static var _last := {}


static func silent() -> bool:
	return DisplayServer.get_name() == "headless"


static func stream(file: String) -> AudioStream:
	if not _streams.has(file):
		var path := DIR + file + ".ogg"
		_streams[file] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[file]


## One of `set_name`'s sounds at a world position (Vector3), or flat when `at` is null.
static func play(set_name: String, at: Variant = null, volume_db := 0.0, pitch_var := 0.06,
		unit_size := 5.0, pitch := 1.0) -> Node:
	if silent() or not SETS.has(set_name):
		return null
	var files: Array = SETS[set_name]
	var file: String = files.pick_random()
	if files.size() > 1 and file == _last.get(set_name, ""):
		file = files[(files.find(file) + randi_range(1, files.size() - 1)) % files.size()]
	_last[set_name] = file
	var s := stream(file)
	if s == null:
		return null
	var host := Audio as Node
	var p: Node
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.unit_size = unit_size
		p3.max_distance = unit_size * 14.0
		p3.panning_strength = 0.9
		p3.volume_db = volume_db
		p3.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
		p3.bus = &"Effects"
		p3.stream = s
		host.add_child(p3)
		p3.global_position = at
		p3.play()
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.volume_db = volume_db
		p2.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
		p2.bus = &"Effects"
		p2.stream = s
		host.add_child(p2)
		p2.play()
		p = p2
	p.finished.connect(p.queue_free)
	return p


## A looping sound under `parent` (silent until faded up with its volume_db).
static func loop(file: String, parent: Node3D, volume_db: float, unit_size: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = unit_size
	p.max_distance = unit_size * 12.0
	p.panning_strength = 0.8
	p.volume_db = volume_db
	p.bus = &"Effects"
	# Its position follows the parent (a fire never moves): no interpolation.
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var s := stream(file)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	p.stream = s
	parent.add_child(p)
	return p


## Starts a loop somewhere into its recording (two fires never crackle in step).
static func start_loop(p: AudioStreamPlayer3D) -> void:
	if silent() or p == null or p.stream == null or p.playing:
		return
	p.play(randf() * maxf(p.stream.get_length() - 0.5, 0.0))
