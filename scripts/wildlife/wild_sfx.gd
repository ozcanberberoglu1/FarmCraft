class_name WildSfx
extends RefCounted
## The sounds of the wild berry bushes and rabbits (art/audio/sfx/wild, built by
## tools/build_wild_audio.py from Mixkit recordings; see art/audio/CREDITS.md): one-shots
## on short-lived players of their own (CampSfx's way). Headless runs play nothing.

const DIR := "res://art/audio/sfx/wild/"
const SETS := {
	"rustle": ["rustle_0", "rustle_1"], "squeak": ["squeak_0", "squeak_1"],
	"scuffle": ["scuffle_0", "scuffle_1"], "thump": ["thump_0", "thump_1"],
}

static var _last := {}


## One of `set_name`'s sounds at `at` (flat when null). "catch" is the squeal and the
## scuffle together.
static func play(set_name: String, at: Variant = null, volume_db := 0.0, pitch_var := 0.08, unit_size := 4.0) -> void:
	if CampSfx.silent():
		return
	if set_name == "catch":
		play("squeak", at, volume_db, 0.1, unit_size)
		play("scuffle", at, volume_db - 2.0, 0.08, unit_size)
		return
	var files: Array = SETS.get(set_name, [])
	if files.is_empty():
		return
	var file: String = files.pick_random()
	if files.size() > 1 and file == _last.get(set_name, ""):
		file = files[(files.find(file) + 1) % files.size()]
	_last[set_name] = file
	var path := DIR + file + ".ogg"
	if not ResourceLoader.exists(path):
		return
	var s := load(path) as AudioStream
	var p: Node
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.unit_size = unit_size
		p3.max_distance = unit_size * 14.0
		p3.panning_strength = 0.9
		p3.volume_db = volume_db
		p3.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
		p3.bus = &"Effects"
		p3.stream = s
		(Audio as Node).add_child(p3)
		p3.global_position = at
		p3.play()
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.volume_db = volume_db
		p2.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
		p2.bus = &"Effects"
		p2.stream = s
		(Audio as Node).add_child(p2)
		p2.play()
		p = p2
	p.finished.connect(p.queue_free)
