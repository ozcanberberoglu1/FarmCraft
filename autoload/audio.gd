extends Node
## All of the game's sound: interface clicks, positional one-shots (tools, animals,
## thunder), footsteps by surface, ambience beds that follow the time of day, the
## season, the weather and whether the player is under a roof, the pickup's engine,
## horse hooves and the music playlist. Files: art/audio (see CREDITS.md). Buses:
## Music, Effects, Ambience, UI (default_bus_layout.tres; volumes in Settings).

const DIR := "res://art/audio/"

## One-shot sets: name -> a path with %d (numbered variants 0-9 that exist) or a list.
const SETS := {
	"step_grass": "sfx/steps/grass_%d.ogg", "step_concrete": "sfx/steps/concrete_%d.ogg",
	"step_wood": "sfx/steps/wood_%d.ogg", "step_gravel": "sfx/steps/gravel_%d.ogg",
	"wood_hit": "sfx/tools/wood_hit_%d.ogg",
	"dig": ["sfx/tools/dig_1.mp3", "sfx/tools/dig_2.mp3", "sfx/tools/dig_3.mp3", "sfx/tools/shovel_stab.mp3"],
	"swoosh": ["sfx/tools/swoosh.mp3"], "grass": ["sfx/tools/grass_cut.mp3", "sfx/tools/grass_heavy.mp3"],
	"water_fill": ["sfx/tools/water_fill.mp3"],
	# Recorded farm work (tools/build_foley.py): the axe biting into a trunk, the trunk
	# giving way and the crown crashing down, the pick cracking stone, a boulder
	# splitting, the hoe in the soil, the scythe through grass, crops coming away, seeds
	# landing and soil pressed over them, the watering can's stream, a crop picked up.
	"axe": "sfx/tools/axe_%d.ogg", "tree_crack": "sfx/tools/tree_crack_%d.ogg", "tree_fall": "sfx/tools/tree_fall_%d.ogg",
	"pick": "sfx/tools/pick_%d.ogg", "rock_break": "sfx/tools/rock_break_%d.ogg", "hoe": "sfx/tools/hoe_%d.ogg",
	"scythe": "sfx/tools/scythe_%d.ogg", "harvest": "sfx/tools/harvest_%d.ogg", "seeds": "sfx/tools/seeds_%d.ogg",
	"plant": "sfx/tools/plant_%d.ogg", "water_can": "sfx/tools/water_can_%d.ogg", "pick_crop": "sfx/tools/pick_crop_%d.ogg",
	"splash": ["sfx/tools/water_splash.mp3"], "milk": ["sfx/tools/milk_squirt.mp3"],
	"shears": ["sfx/tools/shears_snip.mp3"], "brush": "sfx/tools/brush_%d.ogg",
	"soft": "sfx/misc/soft_%d.ogg", "plank": "sfx/misc/plank_%d.ogg", "metal": "sfx/misc/metal_%d.ogg",
	"pot": "sfx/misc/pot_%d.ogg", "door_open": ["sfx/misc/door_open.ogg"], "door_close": ["sfx/misc/door_close.ogg"],
	"creak": ["sfx/misc/creak.ogg"],
	# Three knocks on a front door (tools/build_story_audio.py).
	"knock": "sfx/misc/knock_%d.ogg",
	"coins": ["sfx/money/coins_clink.mp3"], "coins_small": ["sfx/money/coins_small.ogg", "sfx/money/coins_handle.mp3"],
	"money_bag": ["sfx/money/money_bag.mp3"], "thunder": "sfx/weather/thunder_%d.mp3",
	"cow": ["sfx/animals/cow_moo_1.mp3", "sfx/animals/cow_moo_2.mp3", "sfx/animals/cow_moo_3.mp3"],
	"cow_eat": ["sfx/animals/cow_eat.mp3"], "cow_breath": ["sfx/animals/cow_breath.mp3"],
	"sheep": ["sfx/animals/sheep_baa_1.mp3", "sfx/animals/sheep_baa_2.mp3", "sfx/animals/sheep_baa_3.mp3"],
	"lamb": ["sfx/animals/lamb_baa.mp3"],
	"chicken": ["sfx/animals/hen_cluck_1.mp3", "sfx/animals/hen_cluck_2.mp3"],
	"rooster": ["sfx/animals/rooster_1.mp3", "sfx/animals/rooster_2.mp3"],
	# Chicks cheeping, and an egg cracking open as one hatches (tools/fetch_poultry_audio.py).
	"chick": "sfx/animals/chick_%d.ogg", "egg_crack": "sfx/animals/egg_crack_%d.ogg",
	"egg_hatch": ["sfx/animals/egg_hatch.ogg"],
	"horse": ["sfx/animals/horse_neigh.mp3"], "horse_snort": ["sfx/animals/horse_snort.mp3", "sfx/animals/horse_snore.mp3"],
	# Karamel, Zeynep's dog (Dog; tools/build_dog_audio.py): a bark, panting, a soft whine,
	# eating from his bowl.
	"dog_bark": "sfx/animals/dog_bark_%d.ogg", "dog_pant": "sfx/animals/dog_pant_%d.ogg",
	"dog_whine": "sfx/animals/dog_whine_%d.ogg", "dog_eat": "sfx/animals/dog_eat_%d.ogg",
	"engine_start": ["sfx/vehicle/engine_start.mp3"], "car_door": ["sfx/vehicle/door_slam.mp3"],
	"click": ["sfx/ui/click.ogg"], "hover": ["sfx/ui/hover.ogg"], "open": ["sfx/ui/open.ogg"], "close": ["sfx/ui/close.ogg"],
	"confirm": ["sfx/ui/confirm.ogg"], "error": ["sfx/ui/error.ogg"], "toggle": ["sfx/ui/toggle.ogg"],
	"drop": ["sfx/ui/drop.ogg"], "notify": ["sfx/ui/notify.ogg"],
	# A carnival night's fireworks: the burst, and the glitter crackling after it.
	"firework": "sfx/carnival/firework_%d.ogg", "firework_crackle": "sfx/carnival/crackle_%d.ogg",
}
## Looping beds and engines, cross-faded so recordings that don't loop cleanly never click.
const LOOPS := {
	"day": "ambience/farm_day.mp3", "night": "ambience/night_crickets.mp3", "wind": "ambience/wind.mp3",
	"rain": "ambience/rain_light.mp3", "rain_heavy": "ambience/rain_heavy.mp3",
	# The animal housing beds (animal_beds): a cow barn, hens with their rooster, hens alone.
	"barn": "ambience/barn.mp3", "coop": "ambience/coop.mp3", "coop_hens": "ambience/coop_hens.ogg",
	"engine": "sfx/vehicle/engine_loop.mp3",
	"hooves_walk": "sfx/animals/horse_walk_dirt.mp3", "hooves_gallop": "sfx/animals/horse_gallop_dirt.mp3",
	"hooves_road": "sfx/animals/horse_trot_road.mp3",
	# The fairground's crowd on a carnival night (Carnival.crowd_level).
	"carnival_crowd": "ambience/carnival_crowd.ogg",
}
const DAY_MUSIC: Array[String] = ["music/day_relaxing_country.mp3", "music/day_relaxing_in_nature.mp3",
	"music/day_wind_leaves.mp3", "music/day_the_long_road.mp3"]
const NIGHT_MUSIC: Array[String] = ["music/night_relaxation.mp3"]
## A carnival night in town (Carnival.music_on): the fair's tunes, one after another.
const CARNIVAL_MUSIC: Array[String] = ["music/carnival_band_organ.ogg", "music/carnival_kidding_around.mp3",
	"music/carnival_fun_and_games.mp3"]
## What each finished action sounds like: [set, volume dB, optional pitch, optional
## seconds]. It plays on the final stroke's impact tick (see Player._fire_cue); swings add
## a swoosh before it. With seconds, a long recording is faded out that far in, so it
## ends with the action (the trough's fill is a ten-second stream of water).
const ACTIONS := {
	"chop": [["axe", 0.0]], "break": [["pick", 0.0]], "hoe": [["hoe", -1.0]],
	"clear": [["scythe", -3.0], ["hoe", -9.0, 1.1]], "cut": [["scythe", -1.0]], "refill": [["splash", -4.0, 1.0, 1.1]],
	"fill_water": [["water_fill", -6.0, 1.0, 0.45]], "fill_feed": [["grass", -6.0]], "plant": [["plant", -2.0]],
	"harvest": [["scythe", -5.0], ["harvest", -1.0]], "milk": [["milk", -4.0]], "shear": [["shears", -2.0]], "brush": [["brush", -6.0]],
	"feed": [["soft", -8.0]], "medicine": [["pot", -10.0]], "fertilize": [["soft", -8.0], ["grass", -14.0]],
	"muck": [["grass", -5.0], ["soft", -8.0]],
}
## The strokes before the final one (and the hand letting seeds, feed or fertilizer go).
const HITS := {
	"hoe": [["hoe", -4.0, 1.05]], "muck": [["dig", -9.0]], "plant": [["seeds", -3.0]],
	"fertilize": [["grass", -14.0, 1.2]], "fill_feed": [["grass", -12.0, 1.1]], "milk": [["milk", -9.0]],
	"brush": [["brush", -9.0]],
}
## The swoosh of each tool's swing: [volume dB, pitch] (heavy heads swing lower). It plays
## right at the camera, so it is kept a few dB under the blow that follows.
const SWING := {&"axe": [-19.0, 0.85], &"pickaxe": [-19.0, 0.8], &"hoe": [-21.0, 1.0], &"scythe": [-16.0, 1.15],
	&"pitchfork": [-21.0, 1.05]}
## Seconds of near-silence at the start of some recordings, skipped when they play so the
## sound lands on the frame of the hit (measured: 10 ms RMS windows, onset at 20% of peak).
const LEAD_IN := {
	"sfx/tools/dig_1.mp3": 0.8, "sfx/tools/dig_2.mp3": 1.0, "sfx/tools/dig_3.mp3": 0.86,
	"sfx/tools/shovel_stab.mp3": 0.08, "sfx/tools/grass_cut.mp3": 0.1, "sfx/tools/grass_heavy.mp3": 0.1,
	"sfx/tools/swoosh.mp3": 0.14, "sfx/tools/water_splash.mp3": 0.3,
	"sfx/tools/milk_squirt.mp3": 0.06, "sfx/tools/shears_snip.mp3": 0.24,
}
## Seconds between the roof, housing and hoof-surface probes (the fades smooth the steps).
const PROBE_SECONDS := 0.1
## The animal housing beds and their full level. Each is a recording of those animals
## only, so it plays only where the farm keeps them (animal_beds): the barn's is of cows
## (sheep and horses there are heard by their own voices, _update_animals), the coop's
## has a rooster crowing among the hens, "coop_hens" is the same coop with the crow cut.
const ANIMAL_BEDS := {"barn": 0.45, "coop": 0.6, "coop_hens": 0.6}
## A crow held far too long (long_crow): the take it is made of, and where in it the last
## long note is held (seconds).
const CROW_TAKE := "sfx/animals/rooster_1.mp3"
const CROW_NOTE := Vector2(1.05, 1.8)

var _streams := {}
## Seconds each stream starts into (LEAD_IN), by stream.
var _lead := {}
## The stream each set played last, by set.
var _last_take := {}
var _pool_2d: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _loops := {}
var _indoors := 0.0
var _probe_t := 0.0
## Last probe results: under a roof, the animal beds that play (animal_beds), hooves on
## a road.
var _inside := false
var _beds := {}
var _hooves_on_road := false
var _lowpass: AudioEffectLowPassFilter
## Catches the peaks of loud moments (a close axe blow, a door, thunder) before they clip.
var _limiter: AudioEffectHardLimiter
var _music: AudioStreamPlayer
var _music_state := ""
var _music_gap := 6.0
var _music_fade := 0.0
var _last_track := ""
## The track that plays after the current gap; it loads in the background meanwhile.
var _next_track := ""
var _chatter := 4.0
var _last_money := 0.0
var _vehicle: Vehicle
var _engine_delay := 0.0
## Headless runs (tests) have no audio output: nothing plays.
var _silent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The 3D players are placed from _process (and pooled ones jump between sounds):
	# interpolating them between physics ticks would slide the sound across.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_silent = DisplayServer.get_name() == "headless"
	if not _silent:
		_request_sets()
	var amb := AudioServer.get_bus_index("Ambience")
	if amb >= 0:
		_lowpass = AudioEffectLowPassFilter.new()
		_lowpass.cutoff_hz = 20000.0
		AudioServer.add_bus_effect(amb, _lowpass)
	_limiter = AudioEffectHardLimiter.new()
	_limiter.ceiling_db = -0.3
	_limiter.release = 0.08
	AudioServer.add_bus_effect(0, _limiter)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	# The fair plays on without a pause; the farm's music leaves quiet stretches.
	_music.finished.connect(func() -> void: _music_gap = 1.0 if _music_state == "carnival" else randf_range(45.0, 110.0))
	add_child(_music)
	for key: String in LOOPS:
		var positional: bool = key in ANIMAL_BEDS or key in ["engine", "hooves_walk", "hooves_gallop", "hooves_road"]
		_loops[key] = Loop.new(self, _stream(LOOPS[key]), positional, &"Effects" if key.begins_with("engine") or key.begins_with("hooves") else &"Ambience")
	Events.lightning.connect(_on_lightning)
	Events.money_changed.connect(_on_money)
	Events.item_picked_up.connect(_on_picked_up)


## Silences everything; the mixer lets go of the streams over the next few frames.
func shutdown() -> void:
	_silent = true
	for loop: Loop in _loops.values():
		for p: Node in loop.players:
			p.call("stop")
	for p in _pool_2d + _pool_3d:
		p.stop()
	_music.stop()


func _exit_tree() -> void:
	# The buses outlive this node: take the filter and limiter back so nothing lingers at exit.
	var amb := AudioServer.get_bus_index("Ambience")
	if amb >= 0 and _lowpass:
		for i in range(AudioServer.get_bus_effect_count(amb) - 1, -1, -1):
			if AudioServer.get_bus_effect(amb, i) == _lowpass:
				AudioServer.remove_bus_effect(amb, i)
	_lowpass = null
	for i in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		if AudioServer.get_bus_effect(0, i) == _limiter:
			AudioServer.remove_bus_effect(0, i)
	_limiter = null
	# Playing streams are held by the mixer until stopped.
	for loop: Loop in _loops.values():
		for p: Node in loop.players:
			p.call("stop")
			p.set("stream", null)
	for p in _pool_2d + _pool_3d:
		p.stop()
		p.stream = null
	_music.stop()
	_music.stream = null
	_loops.clear()
	_streams.clear()
	_lead.clear()
	_last_take.clear()


# --- Playback ----------------------------------------------------------------------

## Loads (or picks up a background load of) a file under DIR; null if it is missing.
func _stream(rel: String) -> AudioStream:
	if not _streams.has(rel):
		var path := DIR + rel
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_streams[rel] = ResourceLoader.load_threaded_get(path) as AudioStream
		else:
			_streams[rel] = load(path) if ResourceLoader.exists(path) else null
	return _streams[rel]


## The files of a set's spec (numbered variants that exist, or the listed paths).
func _set_paths(spec: Variant) -> Array[String]:
	var out: Array[String] = []
	if spec is String:
		for i in 10:
			var rel := (spec as String) % i
			if ResourceLoader.exists(DIR + rel):
				out.append(rel)
	else:
		for rel: String in spec:
			out.append(rel)
	return out


## Starts loading every one-shot sound in the background, so the first swing, step
## or moo doesn't read its files from disk mid-game.
func _request_sets() -> void:
	for set_name: String in SETS:
		for rel in _set_paths(SETS[set_name]):
			if ResourceLoader.exists(DIR + rel):
				ResourceLoader.load_threaded_request(DIR + rel)


## The files of a set (numbered variants that exist, or the listed paths).
func _files(set_name: String) -> Array:
	var key := "set:" + set_name
	if _streams.has(key):
		return _streams[key]
	var out := []
	for rel in _set_paths(SETS.get(set_name, [])):
		var s := _stream(rel)
		if s:
			out.append(s)
			if LEAD_IN.has(rel):
				_lead[s] = LEAD_IN[rel]
	_streams[key] = out
	return out


## A sound from `set_name` on the interface bus (not positional).
func ui(set_name: String, volume_db := -4.0) -> void:
	play(set_name, null, volume_db, 0.04, &"UI")


## Plays one of `set_name`'s sounds: at a world position (Vector3) or flat when `at` is
## null. Returns the player (or null).
func play(set_name: String, at = null, volume_db := 0.0, pitch_var := 0.08, bus := &"Effects",
		unit_size := 5.0, pitch := 1.0) -> Node:
	if _silent:
		return null
	var files := _files(set_name)
	if files.is_empty():
		return null
	var stream: AudioStream = files.pick_random()
	# Never the same take twice in a row (a run of chops or steps would stutter).
	if files.size() > 1 and stream == _last_take.get(set_name):
		stream = files[(files.find(stream) + randi_range(1, files.size() - 1)) % files.size()]
	_last_take[set_name] = stream
	var p := 1.0 + randf_range(-pitch_var, pitch_var)
	if at is Vector3:
		var s3 := _free_3d()
		s3.stream = stream
		s3.bus = bus
		s3.volume_db = volume_db
		s3.pitch_scale = p * pitch
		s3.unit_size = unit_size
		s3.max_distance = unit_size * 14.0
		s3.global_position = at
		s3.play(float(_lead.get(stream, 0.0)))
		return s3
	var s2 := _free_2d()
	s2.stream = stream
	s2.bus = bus
	s2.volume_db = volume_db
	s2.pitch_scale = p * pitch
	s2.play(float(_lead.get(stream, 0.0)))
	return s2


func _free_2d() -> AudioStreamPlayer:
	for s in _pool_2d:
		if not s.playing:
			return s
	var n := AudioStreamPlayer.new()
	add_child(n)
	if _pool_2d.size() < 16:
		_pool_2d.append(n)
	else:
		n.finished.connect(n.queue_free)
	return n


func _free_3d() -> AudioStreamPlayer3D:
	for s in _pool_3d:
		if not s.playing:
			return s
	var n := AudioStreamPlayer3D.new()
	n.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	n.panning_strength = 0.9
	add_child(n)
	if _pool_3d.size() < 32:
		_pool_3d.append(n)
	else:
		n.finished.connect(n.queue_free)
	return n


# --- Gameplay hooks --------------------------------------------------------------------

## A step of the player: the sound of what is underfoot.
func footstep(body: Node3D, running: bool) -> void:
	play("step_" + _surface(body), body.global_position, -9.0 if running else -13.0, 0.1, &"Effects", 3.0)


func _surface(body: Node3D) -> String:
	var from := body.global_position + Vector3(0, 0.4, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -1.6, 0), 1)
	q.exclude = [body.get_rid()] if body is CollisionObject3D else []
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "grass"
	var path := String((hit["collider"] as Node).get_path())
	if "/Road/" in path or "/Town/" in path or "Warehouse" in path:
		return "concrete"
	if "/Terrain/" in path:
		var p: Vector3 = hit["position"]
		if Weather.snow_cover > 0.35 or TerrainData.path_at(p.x, p.z) > 0.4:
			return "gravel"
		return "grass"
	return "wood"


## A tool swing (the swoosh just before the hit).
func swing(tool_type: StringName, at: Vector3) -> void:
	var s: Array = SWING.get(tool_type, [])
	if not s.is_empty():
		play("swoosh", at, float(s[0]), 0.06, &"Effects", 3.0, float(s[1]))


## An action starting to pour (the watering can): returns the pour, to be faded out with
## fade_out when the can is tipped back (or null).
func action_started(id: String, at: Vector3) -> Node:
	if id == "water" or id == "fill_water" or id == "douse":
		# On soil the stream is softer than splashing into a trough.
		return play("water_can", at, -6.0 if id == "water" else -3.0, 0.05, &"Effects", 4.0, 1.0 if id == "water" else 0.92)
	return null


## A stroke before the final one landing (or seeds, feed or fertilizer leaving the hand).
func impact(id: String, at: Vector3) -> void:
	for entry: Array in HITS.get(id, []):
		play(entry[0], at, float(entry[1]), 0.08, &"Effects", 5.0, float(entry[2]) if entry.size() > 2 else 1.0)


## An action finishing on its target; animals answer being milked, brushed or fed.
## Returns the sounds started (for tests).
func action_done(id: String, at: Vector3, target: Node = null) -> Array:
	var out := []
	for entry: Array in ACTIONS.get(id, []):
		var p := play(entry[0], at, float(entry[1]), 0.08, &"Effects", 5.0, float(entry[2]) if entry.size() > 2 else 1.0)
		if p != null:
			out.append(p)
			if entry.size() > 3:
				cut_after(p, float(entry[3]))
	if target is Animal and id in ["milk", "brush", "feed", "shear"] and randf() < 0.45:
		var data: AnimalData = (target as Animal).data
		animal_voice(data.species, data.adult, (target as Node3D).global_position, -8.0)
	return out


## Fades `p` out once it has played `seconds` (a long recording cut to the action), unless
## the player has gone on to another sound meanwhile.
func cut_after(p: Node, seconds: float, fade := 0.3) -> void:
	var stream: Variant = p.get("stream")
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(p) and p.get("stream") == stream and p.get("playing"):
			fade_out(p, fade))


## Fades a playing sound out over `seconds` and stops it (a pour cut short).
## A pooled player that ends and is reused for another sound mid-fade is left alone; one
## beyond the pool (freed on `finished`, which stop() never sends) is freed here.
func fade_out(p: Node, seconds := 0.15) -> void:
	if p == null or not is_instance_valid(p) or not p.get("playing"):
		return
	var stream: Variant = p.get("stream")
	var from: float = p.get("volume_db")
	var mine := func() -> bool:
		return is_instance_valid(p) and p.get("stream") == stream and p.get("playing")
	var fade := func(db: float) -> void:
		if mine.call():
			p.set("volume_db", db)
	var stop := func() -> void:
		if not mine.call():
			return
		p.call("stop")
		# Typed pools: look only in the one of the player's own class.
		var pooled := _pool_3d.has(p) if p is AudioStreamPlayer3D else (p is AudioStreamPlayer and _pool_2d.has(p))
		if not pooled:
			p.queue_free()
	var tw := create_tween()
	tw.tween_method(fade, from, -60.0, seconds)
	tw.tween_callback(stop)


## An animal's voice (baby animals higher); `loud` for the rooster at dawn.
func animal_voice(species: StringName, adult: bool, at: Vector3, volume_db := -4.0) -> void:
	var set_name := String(species)
	var pitch := 1.0 if adult else 1.3
	match species:
		&"sheep":
			if not adult:
				set_name = "lamb"
				pitch = 1.0
		&"horse":
			set_name = "horse" if randf() < 0.3 else "horse_snort"
		&"chicken", &"rooster":
			# Chicks cheep; a rooster clucks lower than his hens (he crows himself: Animal).
			set_name = "chicken" if adult else "chick"
			pitch = (0.82 if species == &"rooster" else 1.0) if adult else 1.0
	play(set_name, at + Vector3(0, 1.0, 0), volume_db, 0.06, &"Effects", 7.0, pitch)


## A crow held far too long (a rooster about to faint, see Animal): the short crow, then
## its last long note taken up again and again, each time a little higher as he strains,
## until after `seconds` the voice cracks up high and gives out.
func long_crow(at: Vector3, seconds: float, volume_db := 0.0) -> void:
	var stream := _stream(CROW_TAKE)
	if _silent or stream == null:
		return
	var voice: Array = [_crow_take(stream, at, volume_db, 0.95, 0.0, 0.0)]
	var tw := create_tween()
	var pitch := 0.95
	var now := 0.0
	var t := (CROW_NOTE.x + 0.55) / pitch
	# Overlapping takes of the note, cross-faded, up to the crack.
	while t < seconds - 0.8:
		pitch += 0.04
		tw.tween_interval(t - now)
		tw.tween_callback(_crow_again.bind(stream, at, volume_db, pitch, CROW_NOTE.x, voice))
		now = t
		t += (CROW_NOTE.y - CROW_NOTE.x - 0.3) / pitch
	# The crack: the note jumps up, wavers and dies away.
	tw.tween_interval(maxf(seconds - 0.5 - now, 0.0))
	tw.tween_callback(_crow_again.bind(stream, at, volume_db - 2.0, pitch * 1.45, CROW_NOTE.x + 0.25, voice, 0.03))
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void:
		var p: Node = voice[0]
		if is_instance_valid(p) and p.get("stream") == stream and p.get("playing"):
			var wobble := create_tween()
			wobble.tween_property(p, "pitch_scale", pitch * 1.25, 0.09)
			wobble.tween_property(p, "pitch_scale", pitch * 1.55, 0.07)
			fade_out(p, 0.35))


## One take of the long crow, `from` seconds into it, faded in over `fade_in` seconds.
func _crow_take(stream: AudioStream, at: Vector3, volume_db: float, pitch: float, from: float,
		fade_in: float) -> AudioStreamPlayer3D:
	var s3 := _free_3d()
	s3.stream = stream
	s3.bus = &"Effects"
	s3.pitch_scale = pitch
	s3.unit_size = 10.0
	s3.max_distance = 140.0
	s3.global_position = at
	s3.volume_db = volume_db - 18.0 if fade_in > 0.0 else volume_db
	s3.play(from)
	if fade_in > 0.0:
		create_tween().tween_property(s3, "volume_db", volume_db, fade_in)
	return s3


## The held note taken up again over the take still sounding, which fades out.
func _crow_again(stream: AudioStream, at: Vector3, volume_db: float, pitch: float, from: float, voice: Array,
		fade := 0.2) -> void:
	var old: Node = voice[0]
	voice[0] = _crow_take(stream, at, volume_db, pitch, from, fade)
	fade_out(old, fade + 0.05)


## Getting in is silent; the engine turns over a moment later.
func vehicle_enter(v: Vehicle) -> void:
	_vehicle = v
	_engine_delay = 0.45
	var start := play("engine_start", v.global_position + Vector3(0, 0.8, 0), -4.0, 0.03, &"Effects", 6.0)
	if start is AudioStreamPlayer3D:
		(start as AudioStreamPlayer3D).stop()
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			if is_instance_valid(start):
				(start as AudioStreamPlayer3D).play())


func vehicle_exit(v: Vehicle) -> void:
	_vehicle = null
	play("car_door", v.global_position + Vector3(0, 1, 0), -5.0, 0.05, &"Effects", 4.0)


## The trunk gives way as a felled tree starts to lean (at the trunk).
func tree_falling(at: Vector3) -> void:
	play("tree_crack", at, -2.0, 0.05, &"Effects", 8.0)


## A felled tree's crown hits the ground (where it lands).
func tree_landed(at: Vector3) -> void:
	play("tree_fall", at, 0.0, 0.06, &"Effects", 10.0)


## A boulder splits apart under the pick.
func rock_broke(at: Vector3) -> void:
	play("rock_break", at, 0.0, 0.05, &"Effects", 6.0)


## Something picked up: crops rustle in the hand, anything else gives the interface's drop.
func _on_picked_up(id: StringName, _n: int) -> void:
	var item := ItemDB.get_item(id)
	if item and item.category == "crop":
		ui("pick_crop", -6.0)
	else:
		ui("drop", -8.0)


func _on_lightning() -> void:
	# Light travels faster than sound: the rumble follows a moment later.
	get_tree().create_timer(randf_range(0.4, 2.8)).timeout.connect(func() -> void:
		play("thunder", null, randf_range(-6.0, 0.0), 0.08, &"Ambience"))


func _on_money(_amount: int, delta: int) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if delta == 0 or now - _last_money < 0.25 or Game.top_ui() == &"sleep":
		return
	_last_money = now
	ui("coins" if delta > 0 else "coins_small", -8.0)


# --- Every frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _silent:
		return
	var player := Game.player as Node3D
	var in_world := player != null and is_instance_valid(player) and not SaveGame.loading
	_probe_t -= delta
	var probe := _probe_t <= 0.0
	if probe:
		_probe_t = PROBE_SECONDS
	_update_indoors(delta, player if in_world else null, probe)
	_update_ambience(delta, in_world, probe)
	_update_vehicle(delta, in_world)
	_update_hooves(delta, player if in_world else null, probe)
	_update_animals(delta, player if in_world else null)
	_update_music(delta)


## Under a roof the outdoors is muffled (rain on the roof stays audible).
func _update_indoors(delta: float, player: Node3D, probe: bool) -> void:
	if player == null:
		_inside = false
	elif probe:
		var eye := player.global_position + Vector3(0, 1.6, 0)
		var q := PhysicsRayQueryParameters3D.create(eye, eye + Vector3(0, 12, 0), 1)
		if player is CollisionObject3D:
			q.exclude = [(player as CollisionObject3D).get_rid()]
		_inside = not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_indoors = move_toward(_indoors, 1.0 if _inside else 0.0, delta * 2.0)
	if _lowpass:
		_lowpass.cutoff_hz = lerpf(20000.0, 900.0, _indoors)


func _update_ambience(delta: float, in_world: bool, probe: bool) -> void:
	var hour := GameClock.get_hour_float()
	var season := GameClock.get_season()
	var rain := Weather.precip if Weather.today != Weather.Kind.SNOW else 0.0
	var daylight := smoothstep(4.8, 6.2, hour) * (1.0 - smoothstep(19.2, 20.6, hour))
	var birds := daylight * (1.0 - rain * 0.85) * (0.35 if season == GameClock.Season.WINTER else 1.0)
	var crickets := (1.0 - daylight) * (1.0 - rain) * ([0.6, 1.0, 0.5, 0.0][season] as float)
	var wind := clampf((Weather.wind - 0.6) / 1.6, 0.0, 1.0) * 0.8 + (0.25 if season == GameClock.Season.WINTER else 0.0)
	var gate := 1.0 if in_world else 0.55
	var inside := 1.0 - _indoors * 0.6
	(_loops["day"] as Loop).update(delta, birds * 0.75 * gate * inside)
	(_loops["night"] as Loop).update(delta, crickets * 0.7 * gate * inside)
	(_loops["wind"] as Loop).update(delta, wind * gate * (1.0 - _indoors * 0.4))
	(_loops["rain"] as Loop).update(delta, clampf(rain * 1.6, 0.0, 1.0) * 0.8 * gate)
	(_loops["rain_heavy"] as Loop).update(delta, clampf((rain - 0.55) * 2.2, 0.0, 1.0) * 0.8 * gate)
	(_loops["carnival_crowd"] as Loop).update(delta, (Carnival.crowd_level() * 0.9 * inside) if in_world else 0.0)
	# Animal housing hums with its animals (positional, at the buildings), only with the
	# animals each recording is of.
	if probe:
		_beds = animal_beds((Game.player as Node3D).global_position) if in_world else {}
	for key: String in ANIMAL_BEDS:
		var level := 0.0
		var at := Vector3.ZERO
		if _beds.has(key):
			var bed: Array = _beds[key]
			at = bed[0]
			# A few animals sound thinner than a full house.
			level = float(ANIMAL_BEDS[key]) * (0.4 + 0.6 * daylight) * (0.6 + 0.4 * clampf((int(bed[1]) - 1) / 3.0, 0.0, 1.0))
		(_loops[key] as Loop).update(delta, level, at)


## The animal beds that play for a listener at `from`, by loop: [where, how many]. A bed
## plays at the housing nearest to the listener that keeps its animals: "barn" where
## cows live, "coop" where grown hens live with a rooster, "coop_hens" where they live
## without one. A farm without those animals has no such bed (a sheep's barn is heard by
## its sheep alone).
func animal_beds(from: Vector3) -> Dictionary:
	var beds := {}
	var farm: Farm = Game.world.get("farm") if Game.world else null
	if farm == null:
		return beds
	for h: AnimalHousing in farm.housings():
		var cows := 0
		var hens := 0
		var roosters := 0
		for a: AnimalData in Animals.animals:
			if Animals.housing_of(a) != h:
				continue
			match a.species:
				&"cow":
					cows += 1
				&"chicken":
					hens += 1 if a.adult else 0
				&"rooster":
					roosters += 1 if a.adult else 0
		var at := h.center() + Vector3(0, 1.5, 0)
		var found := {}
		if cows > 0:
			found["barn"] = cows
		if hens > 0:
			found["coop" if roosters > 0 else "coop_hens"] = hens + roosters
		for key: String in found:
			if not beds.has(key) or from.distance_to(at) < from.distance_to((beds[key] as Array)[0]):
				beds[key] = [at, found[key]]
	return beds


func _update_vehicle(delta: float, in_world: bool) -> void:
	var engine: Loop = _loops["engine"]
	if not in_world or _vehicle == null or not is_instance_valid(_vehicle) or _vehicle.driver == null:
		engine.update(delta, 0.0)
		return
	if _engine_delay > 0.0:
		_engine_delay -= delta
		engine.update(delta, 0.0)
		return
	var v := _vehicle
	var speed := clampf(v.speed_kmh() / 90.0, 0.0, 1.0)
	var throttle := absf(v._throttle)
	# The old four-cylinder idles low and climbs with speed; gear changes are implied
	# by a sawtooth on the pitch.
	var gear := fmod(speed * 3.2, 1.0)
	engine.pitch = float(v.info.get("engine_pitch", 0.62)) + speed * 0.45 + gear * 0.22 * speed + throttle * 0.12
	engine.update(delta, 0.35 + throttle * 0.45 + speed * 0.2, v.global_position + v.global_basis.z * 1.6 + Vector3(0, 0.8, 0))


func _update_hooves(delta: float, player: Node3D, probe: bool) -> void:
	var horse: Node3D = player.get("riding") if player else null
	var speed := 0.0
	var road := false
	if horse and is_instance_valid(horse):
		speed = Vector2((player as CharacterBody3D).velocity.x, (player as CharacterBody3D).velocity.z).length()
		if probe:
			_hooves_on_road = _surface(horse) == "concrete"
		road = _hooves_on_road
	var at := horse.global_position if horse and is_instance_valid(horse) else Vector3.ZERO
	var walk := clampf(speed / 3.0, 0.0, 1.0) * (1.0 - smoothstep(5.5, 7.0, speed))
	var gallop := smoothstep(5.5, 7.0, speed)
	(_loops["hooves_walk"] as Loop).update(delta, walk * (0.0 if road else 0.8), at)
	(_loops["hooves_road"] as Loop).update(delta, (walk + gallop) * (0.8 if road else 0.0), at)
	(_loops["hooves_gallop"] as Loop).update(delta, gallop * (0.0 if road else 0.9), at)


## Now and then an animal near the player makes itself heard (roosters crow at dawn on
## their own: Animal).
func _update_animals(delta: float, player: Node3D) -> void:
	if player == null:
		return
	_chatter -= delta
	if _chatter > 0.0:
		return
	_chatter = randf_range(2.5, 6.0)
	var hour := GameClock.get_hour_float()
	var asleep := hour < 5.3 or hour > 21.5
	var near := []
	for a: AnimalData in Animals.animals:
		var n := Animals.node_of(a)
		if n and n.global_position.distance_to(player.global_position) < 45.0:
			near.append([a, n])
	if near.is_empty():
		return
	var pick: Array = near.pick_random()
	var a: AnimalData = pick[0]
	var chance: float = {&"chicken": 0.55, &"rooster": 0.3, &"cow": 0.22, &"sheep": 0.3, &"horse": 0.15}.get(a.species, 0.2)
	if asleep:
		chance *= 0.08
	if randf() < chance:
		animal_voice(a.species, a.adult, (pick[1] as Node3D).global_position, -6.0)


## Quiet stretches between tracks; day tracks by day (and on the title screen), the
## night track after dark, nothing while sleeping. On a carnival night in town the fair's
## tunes take over (the track playing fades out first) and hand back when it ends or the
## player leaves town.
func _update_music(delta: float) -> void:
	var hour := GameClock.get_hour_float()
	var title := Game.hud != null and is_instance_valid(Game.hud) and (Game.hud.get("title_screen") as Control) != null \
			and (Game.hud.get("title_screen") as Control).visible
	var state := "day" if title else ("night" if (hour >= 20.5 or hour < 5.5) else "day")
	if not title and Carnival.music_on():
		state = "carnival"
	var sleeping := Game.top_ui() == &"sleep"
	if _music.playing:
		if sleeping or state != _music_state:
			_music_fade = maxf(_music_fade - delta / 3.0, 0.0)
			if _music_fade <= 0.0:
				_music.stop()
				# Into the fair or out of it the next tune follows at once.
				_music_gap = 0.5 if state == "carnival" or _music_state == "carnival" else 4.0
		else:
			_music_fade = minf(_music_fade + delta / 4.0, 1.0)
		_music.volume_db = linear_to_db(maxf(_music_fade, 0.0001))
		return
	if sleeping:
		return
	# Pick the next track while the gap runs and load it in the background (a whole
	# mp3 of several MB would stall the frame it starts on).
	var list: Array[String] = CARNIVAL_MUSIC if state == "carnival" else (NIGHT_MUSIC if state == "night" else DAY_MUSIC)
	if _next_track not in list:
		var options := list.filter(func(t: String) -> bool: return t != _last_track)
		_next_track = (options if not options.is_empty() else list).pick_random()
		if not _streams.has(_next_track) and ResourceLoader.exists(DIR + _next_track):
			ResourceLoader.load_threaded_request(DIR + _next_track)
	# The fair doesn't wait out the farm's quiet stretch.
	if state == "carnival":
		_music_gap = minf(_music_gap, 1.0)
	_music_gap -= delta
	if _music_gap > 0.0:
		return
	if ResourceLoader.load_threaded_get_status(DIR + _next_track) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var track := _next_track
	_next_track = ""
	_last_track = track
	_music.stream = _stream(track)
	_music_state = state
	_music_fade = 0.0
	_music.volume_db = -80.0
	_music.play()


## Two players taking turns on one recording: the next pass starts a few seconds before
## the current one ends and they cross-fade; starts at a random point so repeats vary.
class Loop:
	const FADE := 2.5
	var stream: AudioStream
	var players: Array = []
	var length := 0.0
	var level := 0.0
	var pitch := 1.0
	var _current := 0
	## Pitch and position as last set on the players.
	var _set_pitch := 1.0
	var _set_at := Vector3.ZERO

	func _init(owner: Node, p_stream: AudioStream, positional: bool, bus: StringName) -> void:
		stream = p_stream
		length = stream.get_length() if stream else 0.0
		for i in 2:
			var p: Node
			if positional:
				var p3 := AudioStreamPlayer3D.new()
				p3.unit_size = 6.0
				p3.max_distance = 70.0
				p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
				p = p3
			else:
				p = AudioStreamPlayer.new()
			p.set("bus", bus)
			p.set("stream", stream)
			owner.add_child(p)
			players.append(p)

	func update(delta: float, target: float, at := Vector3.ZERO) -> void:
		if stream == null or length < FADE * 2.0:
			return
		level = move_toward(level, clampf(target, 0.0, 1.5), delta * 0.8)
		var a: Node = players[_current]
		var b: Node = players[1 - _current]
		if level <= 0.001:
			for p: Node in players:
				if p.get("playing"):
					p.call("stop")
			return
		if at != _set_at or pitch != _set_pitch:
			_set_at = at
			_set_pitch = pitch
			for p: Node in players:
				if p is AudioStreamPlayer3D:
					(p as AudioStreamPlayer3D).global_position = at
				p.set("pitch_scale", pitch)
		if not a.get("playing"):
			a.call("play", randf_range(0.0, length - FADE * 2.0))
		var pos: float = a.call("get_playback_position")
		var left := length - pos
		var fade_a := 1.0
		if left < FADE:
			if not b.get("playing"):
				b.call("play", 0.0)
			fade_a = left / FADE
			if left < 0.05 or not a.get("playing"):
				a.call("stop")
				_current = 1 - _current
				a = players[_current]
				b = players[1 - _current]
				fade_a = 1.0
		a.set("volume_db", linear_to_db(maxf(level * fade_a, 0.0001)))
		if b.get("playing"):
			b.set("volume_db", linear_to_db(maxf(level * (1.0 - fade_a), 0.0001)))
