class_name CombatSfx
extends RefCounted
## The sounds of the knife and the bow, arrows landing and the farmer hurt
## (art/audio/sfx/combat, built by tools/build_combat_audio.py from Mixkit recordings and
## a few synthesised ones; see art/audio/CREDITS.md): one-shots on short-lived players of
## their own (CampSfx's way). Headless runs play nothing.

const DIR := "res://art/audio/sfx/combat/"
const SETS := {
	"knife_swing": ["knife_swing_0", "knife_swing_1"], "knife_hit": ["knife_hit_0", "knife_hit_1"],
	"bow_draw": ["bow_draw"], "bow_letdown": ["bow_letdown"], "bow_release": ["bow_release_0", "bow_release_1"],
	"arrow_wood": ["arrow_wood_0", "arrow_wood_1"], "arrow_ground": ["arrow_ground_0", "arrow_ground_1"],
	"arrow_flesh": ["arrow_flesh"], "arrow_break": ["arrow_break"],
	"grunt": ["grunt_0", "grunt_1", "grunt_2"], "fall": ["fall"], "heartbeat": ["heartbeat"],
}

static var _streams := {}
static var _last := {}


static func stream(file: String) -> AudioStream:
	if not _streams.has(file):
		var path := DIR + file + ".ogg"
		_streams[file] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[file]


## One of `set_name`'s sounds at a world position (Vector3), or flat when `at` is null.
## Returns the player (or null).
static func play(set_name: String, at: Variant = null, volume_db := 0.0, pitch_var := 0.06,
		unit_size := 5.0) -> Node:
	if CampSfx.silent() or not SETS.has(set_name):
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
		p3.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
		p3.bus = &"Effects"
		p3.stream = s
		host.add_child(p3)
		p3.global_position = at
		p3.play()
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.volume_db = volume_db
		p2.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
		p2.bus = &"Effects"
		p2.stream = s
		host.add_child(p2)
		p2.play()
		p = p2
	p.finished.connect(p.queue_free)
	return p
