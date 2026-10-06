class_name CarRadio
extends Node
## The radio of the vehicle the player drives (Audio.radio). Every road vehicle has one;
## the open tractor does not (NO_RADIO). The stations broadcast round the clock on one
## shared clock whether anyone listens or not: tuning in, or getting back into the car,
## picks a station up where its playlist is by now (broadcast_at), never from the start.
## R turns the set on and off, T moves the dial to the next station through a burst of
## static. Whether it is on and which station it is left on stay with the saved game
## (FarmState.flags). It plays on a bus of its own into Music (the music volume sets it),
## band-limited and narrowed like a small dashboard speaker, duller and quieter from the
## chase camera outside, and it fades out as the driver gets out. The set never stops for
## that: the track runs on unheard (to its end), so that the driver who gets back in, or
## switches the set on again, hears it carry on from behind the door, not start afresh.
## Every track plays at one loudness in the cab (MusicLevels, VOLUME_DB). While it plays the
## world's own music is held (Audio._update_music asks holds_music). The HUD shows the
## station and the track for a few seconds (RadioLine, on `shown`), and a dashboard mesh
## named "RadioDisplay" glows while the set is on.

## A line for the HUD: the station (or that the set is off), the track on air, whether
## the set is on.
signal shown(title: String, detail: String, on: bool)

const DIR := "res://art/audio/"
const BUS := &"Radio"
## Vehicles without a set: no cab, no dashboard.
const NO_RADIO: Array[StringName] = [&"tractor"]
## The stations along the dial: their name and frequency as shown, and the playlist each
## repeats: [file under DIR, title as shown, seconds]. The seconds are the files' own
## lengths (the broadcast clock is worked out from them without loading anything);
## tools/fetch_radio_music.py, which downloads the recordings, writes them here. Every
## station has recordings of its own (music/radio/) and shares the rest of its list with
## the world's music (Audio.DAY_MUSIC, NIGHT_MUSIC); no track is on two stations. "Bathed
## in the Light" is long held tones and plays here only, not in the day's own music. The
## credits are in art/audio/CREDITS.md.
const STATIONS: Array[Dictionary] = [
	# The town's own station: Anatolian folk tunes on saz, oud and violin, and easy
	# acoustic tunes for the farm and the fields between them.
	{"id": "yesilova", "name": "Yeşilova FM", "freq": "94.5", "tracks": [
		["music/radio/yesilova_yesilim.ogg", "Yeşilim · Turku", 92.71],
		["music/day_relaxing_in_nature.mp3", "Relaxing in Nature", 97.07],
		["music/radio/yesilova_uskudara_gider_iken.ogg", "Üsküdar'a Gider İken · Turku", 192.16],
		["music/day_laid_back_guitars.ogg", "Laid Back Guitars · Kevin MacLeod", 243.54]]},
	# Country for the road to town.
	{"id": "yol", "name": "Radyo Yol", "freq": "98.2", "tracks": [
		["music/radio/yol_bama_country.ogg", "Bama Country · Kevin MacLeod", 211.12],
		["music/day_relaxing_country.mp3", "Relaxing Country", 109.92],
		["music/day_carpe_diem.ogg", "Carpe Diem · Kevin MacLeod", 293.39],
		["music/radio/yol_cattails.ogg", "Cattails · Kevin MacLeod", 157.65],
		["music/day_the_long_road.mp3", "The Long Road · Ahjay Stelino", 97.2]]},
	# Slow and quiet, for the drive home after dark.
	{"id": "huzur", "name": "Radyo Huzur", "freq": "88.4", "tracks": [
		["music/radio/huzur_satie_gymnopedie_1.ogg", "Satie: Gymnopédie No. 1 · Robin Alciatore", 181.62],
		["music/day_heartwarming.ogg", "Heartwarming · Kevin MacLeod", 70.70],
		["music/night_relaxation.mp3", "Relaxation", 117.73],
		["music/day_bathed_in_the_light.ogg", "Bathed in the Light · Kevin MacLeod", 165.71]]},
]
## Seconds between one station's list starting and the next one's, so that two stations
## never change track together.
const STAGGER := 41.0
## A track with less than this left is not joined: the next one starts instead.
const TAIL := 1.5
## The dial's static, and the knob's click.
const TUNE_NOISE: Array[String] = ["sfx/vehicle/radio_tune_1.wav", "sfx/vehicle/radio_tune_2.wav",
	"sfx/vehicle/radio_tune_3.wav"]
const CLICK := "sfx/vehicle/radio_click.wav"
## Seconds before the station comes in: on getting in (none: the set was never off, it is
## heard as soon as the door is open), after the knob's click, after the static between
## two stations.
const WAIT_ENGINE := 0.0
const WAIT_SWITCH := 0.25
const WAIT_STATIC := 0.5
## Seconds the set takes to fade in or out at the knob, to fade out as the driver gets
## out, and a station to come up from the static.
const FADE_SWITCH := 0.3
const FADE_EXIT := 0.8
const FADE_TRACK := 0.2
## The music's level in the cab (dB above MusicLevels.REFERENCE, the level of the world's
## own music, as heard through the speaker: every track is trimmed to it), and how much
## quieter it is heard from outside.
const VOLUME_DB := 5.0
const OUTSIDE_DB := -8.0
## The static and the click: about as loud as the music they break into.
const NOISE_DB := 2.0
## The dashboard speaker's band (Hz); from outside, through the doors, only this much of
## the top is left.
const SPEAKER_LOW := 170.0
const SPEAKER_HIGH := 5600.0
const OUTSIDE_HIGH := 950.0
## A track still running (heard or not) carries on, without a new start, while it is no
## further than this from where the broadcast is (seconds): the sound card's clock and the
## computer's drift apart a little, and a computer that slept is hours out.
const SYNC := 2.0
## The display's glow while the set is on.
const DISPLAY_GLOW := Color(0.55, 1.0, 0.62)
const DISPLAY_ENERGY := 1.4

## Seconds added to the broadcast clock (tests move the stations on with it).
var clock_shift := 0.0
## Nothing plays (headless runs, the game closing); the set is still switched and tuned.
var silent := false

## The vehicle with a set that the player sits in (null on foot and on the tractor).
var _vehicle: Vehicle
var _player: AudioStreamPlayer
var _noise: AudioStreamPlayer
var _highpass: AudioEffectHighPassFilter
var _lowpass: AudioEffectLowPassFilter
var _narrow: AudioEffectStereoEnhance
var _streams := {}
## How loud the set is (0-1, the knob and the door), and the station just tuned to (0-1).
var _level := 0.0
var _track_level := 0.0
## How far outside the listener is (0 in the cab, 1 at the chase camera or out of the car).
var _outside := 0.0
## A station is being brought in: seconds left before it sounds, the file it starts with.
var _tuning := false
var _wait := 0.0
var _pending := ""
## The track on air (index in the station's list, -1 when nothing plays) and its station.
var _on_air := -1
var _on_station := -1
var _last_noise := -1
## The file the player holds (under DIR) and the dB that brings it to the common loudness.
var _playing := ""
var _trim_db := 0.0
## How many times a track was started (not carried on): tests count them.
var starts := 0


func _ready() -> void:
	# Its position follows the frame, like the rest of the sound.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_bus()
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	add_child(_player)
	_noise = AudioStreamPlayer.new()
	_noise.bus = BUS
	add_child(_noise)


func _exit_tree() -> void:
	# The bus outlives this node; playing streams are held by the mixer until stopped.
	for p: AudioStreamPlayer in [_player, _noise]:
		if p:
			p.stop()
			p.stream = null
	var idx := AudioServer.get_bus_index(BUS)
	if idx >= 0:
		AudioServer.remove_bus(idx)
	_streams.clear()


## A bus of its own that feeds the music's: what a dashboard speaker lets through, with
## the stereo pulled in towards the middle of the dash.
func _build_bus() -> void:
	var idx := AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
	AudioServer.set_bus_send(idx, &"Music")
	_highpass = AudioEffectHighPassFilter.new()
	_highpass.cutoff_hz = SPEAKER_LOW
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = SPEAKER_HIGH
	_narrow = AudioEffectStereoEnhance.new()
	_narrow.pan_pullout = 0.4
	for fx: AudioEffect in [_highpass, _lowpass, _narrow]:
		AudioServer.add_bus_effect(idx, fx)


## Silences the set for good (the game is closing).
func shutdown() -> void:
	silent = true
	_stop()
	_noise.stop()


# --- The stations' clock -----------------------------------------------------------------

## Seconds on the clock every station broadcasts by (the computer's own, so a station is
## as far on after an hour away as after a minute).
func now() -> float:
	return Time.get_unix_time_from_system() + clock_shift


## Seconds a station's whole list takes.
static func playlist_seconds(index: int) -> float:
	var total := 0.0
	for t: Array in STATIONS[index]["tracks"]:
		total += float(t[2])
	return total


## What station `index` broadcasts at `time` (seconds on the shared clock): "track", the
## index in its list of the track on air, and "at", the seconds into that track.
static func broadcast_at(index: int, time: float) -> Dictionary:
	var tracks: Array = STATIONS[index]["tracks"]
	var at := fposmod(time + index * STAGGER, playlist_seconds(index))
	for i in tracks.size():
		var length := float(tracks[i][2])
		if at < length:
			return {"track": i, "at": at}
		at -= length
	return {"track": 0, "at": 0.0}


## What a listener tuning in at `time` gets: the track on air where it is, or, with only
## its last moment left, the next one from its start.
static func joined_at(index: int, time: float) -> Dictionary:
	var tracks: Array = STATIONS[index]["tracks"]
	var b := broadcast_at(index, time)
	if float(tracks[int(b["track"])][2]) - float(b["at"]) < TAIL:
		return {"track": (int(b["track"]) + 1) % tracks.size(), "at": 0.0}
	return b


# --- The set ---------------------------------------------------------------------------------

static func has_radio(v: Vehicle) -> bool:
	return v != null and v.kind not in NO_RADIO


## Whether the set is switched on (kept with the saved game; a new farm's is on).
func is_on() -> bool:
	return not bool(FarmState.flags.get("radio_off", false))


## The station the dial is on (index in STATIONS; kept with the saved game by its id).
func station() -> int:
	var id := String(FarmState.flags.get("radio_station", ""))
	for i in STATIONS.size():
		if STATIONS[i]["id"] == id:
			return i
	return 0


## Whether the player sits in a vehicle with the set playing (or coming on); like the
## world's music it is silent while he sleeps.
func is_listening() -> bool:
	return _vehicle != null and is_on() and Game.top_ui() != &"sleep"


## The world's own music waits while the set plays (Audio._update_music).
func holds_music() -> bool:
	return is_listening() and not silent


## The station's name with its frequency, as the HUD shows it.
static func station_title(index: int) -> String:
	return "%s  %s" % [STATIONS[index]["name"], STATIONS[index]["freq"]]


static func track_title(index: int, track: int) -> String:
	return String((STATIONS[index]["tracks"] as Array)[track][1])


## The level (dB) the track on air plays at in the cab: every track as loud as the next.
func cab_db() -> float:
	return VOLUME_DB + _trim_db


## Whether the track the player holds still runs where station `s` broadcasts it at
## `time`: it can carry on as it is.
func carries_on(s: int, time: float) -> bool:
	if silent or not _player.playing:
		return false
	var b := joined_at(s, time)
	return String((STATIONS[s]["tracks"] as Array)[int(b["track"])][0]) == _playing \
			and absf(_player.get_playback_position() - float(b["at"])) < SYNC


## Turns the set on or off (the knob's click; the station comes back in a moment later).
func set_on(on: bool) -> void:
	if on == is_on():
		return
	if on:
		FarmState.flags.erase("radio_off")
	else:
		FarmState.flags["radio_off"] = true
	if _vehicle == null:
		return
	_play_noise(CLICK)
	_light_display(_vehicle, on)
	if on:
		# (Switched on again in the same breath: the track that was fading goes on.)
		var wait := 0.0 if carries_on(station(), now()) else WAIT_SWITCH
		_tune(wait)
		_show_station(wait)
	else:
		_tuning = false
		shown.emit(tr("RADIO_OFF"), "", false)


## Moves the dial to the next station (round to the first after the last) through a
## burst of static. With the set off it comes on where it was left instead.
func next_station() -> void:
	if not is_on():
		set_on(true)
		return
	FarmState.flags["radio_station"] = STATIONS[(station() + 1) % STATIONS.size()]["id"]
	if _vehicle == null:
		return
	_stop()
	var takes := range(TUNE_NOISE.size()).filter(func(i: int) -> bool: return i != _last_noise)
	_last_noise = takes.pick_random()
	_play_noise(TUNE_NOISE[_last_noise])
	_tune(WAIT_STATIC)
	_show_station(WAIT_STATIC)


func _unhandled_input(event: InputEvent) -> void:
	if _vehicle == null or Game.is_ui_open():
		return
	if event.is_action_pressed("radio_toggle"):
		set_on(not is_on())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("radio_next"):
		next_station()
		get_viewport().set_input_as_handled()


## The vehicle with a set the player drives now (null otherwise).
func _driven() -> Vehicle:
	var p := Game.player as Player
	if p == null or not is_instance_valid(p) or SaveGame.loading:
		return null
	var v := p.driving
	return v if is_instance_valid(v) and has_radio(v) else null


func _process(delta: float) -> void:
	var v := _driven()
	if v != _vehicle:
		_vehicle = v
		if v:
			_got_in(v)
		else:
			# Out of the car: the set fades away behind the door (below).
			_tuning = false
	var listening := is_listening()
	if listening and _tuning:
		_wait -= delta
		if _wait <= 0.0:
			_come_in()
	elif listening and _on_air >= 0 and not _player.playing and not silent:
		# The track ran out: what the station plays next.
		_tune(0.0)
	elif not listening and not silent and _on_air >= 0 and not _player.playing:
		# Nobody listens and the track that ran on unheard is over: the next time the
		# station is brought in where its broadcast is.
		_stop()
		if _vehicle != null and is_on():
			# (The driver sleeps at the wheel: nothing but waking brings the set back,
			# so it is left tuning in for then.)
			_tune(0.0)
	_level = move_toward(_level, 1.0 if listening else 0.0, delta / (FADE_SWITCH if _vehicle else FADE_EXIT))
	_track_level = move_toward(_track_level, 1.0, delta / FADE_TRACK)
	var outside := _vehicle == null or _vehicle.chase_camera
	_outside = move_toward(_outside, 1.0 if outside else 0.0, delta * (4.0 if _vehicle else 1.0 / FADE_EXIT))
	# (Faded out, the track is not stopped: it runs on unheard, see carries_on.)
	_lowpass.cutoff_hz = lerpf(SPEAKER_HIGH, OUTSIDE_HIGH, _outside)
	_player.volume_db = linear_to_db(maxf(_level * _track_level, 0.0001)) + cab_db() + OUTSIDE_DB * _outside
	_noise.volume_db = NOISE_DB + OUTSIDE_DB * _outside


## The driver sat down in `v`: the display, and the station at once, as if the set had
## played on in the cab all the while: it comes up from behind the door (from the level
## and the dullness it went out with), and a track still running carries on (or, with the
## set off, a line saying so: the keys are on it).
func _got_in(v: Vehicle) -> void:
	_light_display(v, is_on())
	if is_on():
		_tune(WAIT_ENGINE)
		_show_station(WAIT_ENGINE)
	else:
		shown.emit(tr("RADIO_OFF"), "", false)


## Starts bringing the dial's station in, to sound in `wait` seconds: the track that will
## be on air then loads in the background meanwhile (an mp3 of several MB read on the
## frame it starts would stall it).
func _tune(wait: float) -> void:
	_tuning = true
	_wait = wait
	var s := station()
	var b := joined_at(s, now() + wait)
	_pending = String((STATIONS[s]["tracks"] as Array)[int(b["track"])][0])
	if not silent and not _streams.has(_pending) and ResourceLoader.exists(DIR + _pending):
		ResourceLoader.load_threaded_request(DIR + _pending)


## The wait is over: the station sounds, at the point its broadcast has reached.
func _come_in() -> void:
	var s := station()
	var b := joined_at(s, now())
	var tracks: Array = STATIONS[s]["tracks"]
	var track := int(b["track"])
	var rel := String(tracks[track][0])
	if rel != _pending:
		# The station went on to its next track during the wait.
		_tune(0.0)
	if not silent and ResourceLoader.load_threaded_get_status(DIR + rel) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	_tuning = false
	# The track still runs where the broadcast is (the driver was out for a moment, the
	# set was off for one): it carries on, nothing is started or faded up afresh.
	var carried := carries_on(s, now())
	var changed := track != _on_air or s != _on_station
	_on_air = track
	_on_station = s
	if changed:
		shown.emit(station_title(s), track_title(s, track), true)
	if silent or carried:
		return
	var stream := _stream(rel)
	if stream == null:
		# A file that is not there: the station stays silent.
		_on_air = -1
		return
	_player.stream = stream
	_playing = rel
	_trim_db = MusicLevels.speaker_trim(rel)
	_track_level = 0.0
	_player.volume_db = -80.0
	starts += 1
	# (Not past the end of a file shorter than the list says.)
	_player.play(clampf(float(b["at"]), 0.0, maxf(stream.get_length() - 0.5, 0.0)))


func _stop() -> void:
	_player.stop()
	_playing = ""
	_on_air = -1
	_on_station = -1


## The line the HUD shows as the dial settles: the station and what it will be playing
## in `wait` seconds.
func _show_station(wait: float) -> void:
	var s := station()
	var b := joined_at(s, now() + wait)
	_on_air = int(b["track"])
	_on_station = s
	shown.emit(station_title(s), track_title(s, _on_air), true)


## Picks up a background load of a file under DIR (or loads it); null if it is missing.
func _stream(rel: String) -> AudioStream:
	if not _streams.has(rel):
		var path := DIR + rel
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_streams[rel] = ResourceLoader.load_threaded_get(path) as AudioStream
		else:
			_streams[rel] = load(path) if ResourceLoader.exists(path) else null
	return _streams[rel]


func _play_noise(rel: String) -> void:
	if silent:
		return
	var stream := _stream(rel)
	if stream == null:
		return
	_noise.stream = stream
	_noise.pitch_scale = randf_range(0.96, 1.04)
	_noise.play()


## Lights the set's display where the dashboard has one (every mesh named
## "RadioDisplay"): its own copy of the material glows while the set is on. The cab's own
## shader (vehicle_interior: `glow`) and plain materials (emission) both light.
func _light_display(v: Vehicle, on: bool) -> void:
	if not is_instance_valid(v):
		return
	for n in v.find_children("RadioDisplay*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(si)
			if mat == null or not mi.has_meta(&"radio_display"):
				var src := mi.get_active_material(si)
				if src == null:
					continue
				mat = src.duplicate() as Material
				mi.set_surface_override_material(si, mat)
			if mat is BaseMaterial3D:
				var plain := mat as BaseMaterial3D
				plain.emission_enabled = true
				plain.emission = DISPLAY_GLOW
				plain.emission_energy_multiplier = DISPLAY_ENERGY if on else 0.0
			elif mat is ShaderMaterial:
				var glow := DISPLAY_GLOW * (DISPLAY_ENERGY if on else 0.0)
				(mat as ShaderMaterial).set_shader_parameter(&"glow", Vector3(glow.r, glow.g, glow.b))
		mi.set_meta(&"radio_display", true)
