class_name Angler
extends Node
## The fishing rod in the player's hands (a child of the Player, which hands it the LMB).
##
## Hold LMB to wind up (the rod goes back over the shoulder, the crosshair ring shows the
## power), release to cast: the float flies out on its line, farther the longer the
## hold, and lands on the pond with a plop (a cast onto the bank is reeled straight
## back). Each cast into the water takes one bait (R changes which: FishTable.BAITS; a
## spinner is kept, unless it snags) and wears the rod by one (a broken rod won't cast;
## the rods cast to their own reach, FishTable.RODS). After
## 5-20 s a fish nibbles (the float dips, small rings), then bites: the float is pulled
## under, the water thrashes and splashes, and for 2 s LMB strikes. In time, the rod is
## swept up and the fish flies out of the water on the line in an arc and lands 2-3 m
## from the player, flopping on the bank until it is picked up (FloppingFish). Too late,
## or too early, and it gets away with the bait; the line is reeled in. Only in the
## pond's water (Pond.is_fishable); not while driving or riding. Nothing of a cast is
## saved: loading rebuilds the player without it. Now and then the fish is a trophy
## (FishTable.trophy_of): the float is dragged under harder, it comes out in a burst of
## spray, lands with a thud at the giant's size and is announced with a fanfare. The
## fish landed since the last trophy are counted (PlayerState.fish_since_trophy): a long
## dry run makes a giant owed (FishTable.pity).
##
## The rod's strokes are ToolAnim's rod_* profiles, played through HeldItem.debug_pose on
## this node's clock; the float hangs from the rod tip on a pendulum when not cast.

enum State { IDLE, WINDUP, CAST, WAIT, BITE, STRIKE, RETRIEVE }

## The rods' tool type (every rod: FishTable.RODS).
const ROD := &"fishing_rod"
## Seconds of holding LMB to full power.
const WINDUP_FULL := 1.3
## Seconds from casting to the bite (with the standard rod; FishTable.RODS "bite").
const BITE_TIME := Vector2(5.0, 20.0)
## Extra wear a giant's fight puts on the rod (a cast wears it by one).
const TROPHY_WEAR := 2
## Seconds the player has to strike once the fish bites.
const BITE_WINDOW := 2.0
## Seconds of the rod's forward whip (the rest of rod_cast after the wind-up).
const CAST_TIME := 0.55
const STRIKE_TIME := 1.1
## Seconds a caught fish flies from the water to the bank.
const FISH_FLIGHT := 1.05
## How far the fish lands from the player (m).
const FISH_LAND := Vector2(2.0, 3.0)
## The float hangs this far under the rod tip when the line is in.
const HANG := 0.42
const RETRIEVE_SPEED := 5.5
const REEL_UP_SPEED := 5.0
## The line is reeled in when the player walks this far from the float.
const MAX_LINE := 24.0
## Seconds of one breath of the waiting rod.
const WAIT_LOOP := 4.0

var player: Player
var state := State.IDLE
## Wind-up 0..1.
var power := 0.0
## The bait the next cast takes (FishTable.BAITS).
var bait: StringName = &""
## The rod the cast was made with, and the bait on its hook.
var cast_rod: StringName = ROD
var cast_bait: StringName = &""
## The fish that will bite this cast (FishTable.catch_of).
var catch_info := {}

var _float: Node3D
var _float_mi: MeshInstance3D
var _line: FishingLine
var _p := Vector3.ZERO
var _prev := Vector3.ZERO
var _vel := Vector3.ZERO
var _rope := HANG
var _on_water := false
var _t := 0.0
var _clock := 0.0
var _bite_at := 0.0
var _nibbles: Array[float] = []
var _dip := 0.0
var _cast_from_u := 0.0
var _released := false
var _grounded := false
var _retrieve_len := 1.0
var _reeling_up := false
var _fx_t := 0.0
var _bite_dir := Vector3.RIGHT
var _bite_off := Vector3.ZERO
var _reel_sfx: AudioStreamPlayer3D
var _fish: FloppingFish
var _posed := false
var _warmed := false
var _bite_again := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	player = get_parent() as Player
	_rng.randomize()
	_float = Node3D.new()
	_float.name = "Float"
	_float.top_level = true
	_float.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_float_mi = MeshInstance3D.new()
	_float_mi.mesh = FishModels.real_mesh(&"fishing_float")
	_float_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_float_mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_float_mi.layers = 2
	_float.add_child(_float_mi)
	add_child(_float)
	_line = FishingLine.new()
	_line.name = "Line"
	add_child(_line)
	_float.visible = false
	PlayerState.selected_changed.connect(func(_s: int) -> void: _check_hand())
	PlayerState.inventory.changed.connect(_check_hand)
	_check_hand.call_deferred()


## The rod is the item in hand.
func holding_rod() -> bool:
	var s := PlayerState.selected_stack()
	return s != null and (s.item.id == ROD or s.item.tool_type == ROD)


## The rod in hand (its item id; the standard rod's when none).
func rod_id() -> StringName:
	var s := PlayerState.selected_stack()
	return s.item.id if s != null and holding_rod() else ROD


## The rod in hand is worn out (it won't cast until it is repaired).
func rod_broken() -> bool:
	var s := PlayerState.selected_stack()
	return s != null and holding_rod() and s.item.has_durability() and s.durability <= 0


## Horizontal reach of a cast with the rod in hand at no power and at full power (m).
func reach() -> Vector2:
	return FishTable.rod_stats(rod_id())["reach"]


## Busy with a cast (for the player and tests).
func is_fishing() -> bool:
	return state != State.IDLE


# --- Input (from Player._update_action, every physics tick while the rod is in hand) ----

func use_input(down: bool, pressed: bool) -> void:
	match state:
		State.IDLE:
			if pressed:
				_try_windup()
		State.WINDUP:
			if Game.is_ui_open():
				cancel()
			elif not down:
				_release()
		State.WAIT:
			if pressed:
				Game.notify(tr("MSG_FISH_TOO_EARLY"), Color(1.0, 0.75, 0.45))
				_retrieve()
		State.BITE:
			if pressed:
				_strike()


## R with the rod in hand: the other bait on the hook.
func cycle_bait() -> void:
	var have: Array[StringName] = []
	for b in FishTable.BAITS:
		if PlayerState.inventory.count_item(b) > 0:
			have.append(b)
	if have.size() < 2:
		return
	bait = have[(have.find(bait) + 1) % have.size()]
	Audio.ui("toggle", -8.0)
	var text := tr("MSG_FISH_BAIT") % ("%s ×%d" % [ItemDB.get_item(bait).display_name(), PlayerState.inventory.count_item(bait)])
	var draws := bait_draws(bait)
	if not draws.is_empty():
		text += "  ·  " + tr("MSG_FISH_BAIT_DRAWS") % ", ".join(draws)
	Game.notify(text, Color(0.85, 0.9, 0.7))


## The names of the fish that take `bait` best (up to `count`, the likeliest first at
## any hour).
static func bait_draws(b: StringName, count := 3) -> PackedStringArray:
	var ranked: Array = []
	for id: StringName in FishTable.SPECIES:
		if FishTable.is_fish(id) and float((FishTable.SPECIES[id]["baits"] as Dictionary).get(b, 0.0)) >= FishTable.FAVOURED:
			ranked.append([float(FishTable.SPECIES[id]["chance"]) * FishTable.bait_factor(id, b), id])
	ranked.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var out := PackedStringArray()
	for e: Array in ranked.slice(0, count):
		out.append(ItemDB.get_item(e[1]).display_name())
	return out


## The prompt lines while the rod is in hand (the Player adds them under its own).
func prompt_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if not holding_rod():
		return out
	var lmb := tr("KEY_LMB")
	match state:
		State.IDLE, State.WINDUP:
			if rod_broken():
				out.append(tr("HINT_ROD_BROKEN"))
				return out
			var b := _current_bait()
			if b == &"":
				out.append(tr("HINT_FISH_NO_BAIT"))
				return out
			out.append("%s (%s)" % [lmb, tr("ACTION_CAST")])
			out.append(tr("MSG_FISH_BAIT") % ["%s ×%d" % [ItemDB.get_item(b).display_name(), PlayerState.inventory.count_item(b)]])
			if _bait_kinds() > 1:
				out.append("R (%s)" % tr("ACTION_CHANGE_BAIT"))
		State.WAIT:
			out.append("%s (%s)" % [lmb, tr("ACTION_REEL_IN")])
		State.BITE:
			out.append("%s (%s)" % [lmb, tr("ACTION_STRIKE")])
	return out


# --- States ------------------------------------------------------------------------------

func _try_windup() -> void:
	if rod_broken():
		Game.notify(tr("MSG_TOOL_BROKEN") % PlayerState.selected_stack().item.display_name(), Color(1.0, 0.45, 0.35))
		Audio.ui("error", -8.0)
		return
	var b := _current_bait()
	if b == &"":
		Game.notify(tr("MSG_FISH_NO_BAIT"), Color(1.0, 0.55, 0.4))
		Audio.ui("error", -8.0)
		return
	if not _water_ahead():
		Game.notify(tr("MSG_FISH_NO_WATER"), Color(1.0, 0.6, 0.4))
		Audio.ui("error", -8.0)
		return
	bait = b
	state = State.WINDUP
	power = 0.0
	_t = 0.0
	Events.action_progress_started.emit(tr("PROGRESS_CAST"), WINDUP_FULL)


func _release() -> void:
	state = State.CAST
	_cast_from_u = _windup_u()
	_t = 0.0
	_released = false
	_grounded = false
	Events.action_progress_finished.emit(true)


## The float leaves the rod tip (rod_cast's "release").
func _launch() -> void:
	_released = true
	var fwd := _look()
	var flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var pitch := asin(clampf(fwd.y, -1.0, 1.0))
	var angle := clampf(pitch + deg_to_rad(28.0), deg_to_rad(12.0), deg_to_rad(50.0))
	var r := reach()
	var reach := lerpf(r.x, r.y, power)
	_p = _tip()
	# The speed that brings the float down on the water `reach` metres out, from the tip's
	# height above it.
	var h := maxf(_p.y - WorldLayout.WATER_LEVEL, 0.1)
	var speed := sqrt(9.8 * reach * reach / (2.0 * cos(angle) * cos(angle) * (h + reach * tan(angle))))
	_prev = _p
	_vel = flat * cos(angle) * speed + Vector3.UP * sin(angle) * speed
	_float.visible = true
	FishingAudio.play("cast", _p, linear_to_db(0.6 + 0.4 * power))
	player.kick_view(Vector4(-0.5, 0.2, 0.0, 0.0))


func _fly(delta: float) -> void:
	_vel.y -= 9.8 * delta
	_vel *= 1.0 - 0.04 * delta
	var next := _p + _vel * delta
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_p, next, 1)
	q.exclude = _ray_exclude()
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		_land_on_ground(hit["position"])
		return
	if next.y <= WorldLayout.WATER_LEVEL and Pond.is_fishable(next):
		_land_in_water(next)
		return
	if next.y <= TerrainData.height(next.x, next.z):
		_land_on_ground(Vector3(next.x, TerrainData.height(next.x, next.z), next.z))
		return
	_p = next
	_rope = maxf(_rope, _p.distance_to(_tip()))
	if _t > 6.0:
		_retrieve()


func _land_in_water(at: Vector3) -> void:
	state = State.WAIT
	_t = 0.0
	_on_water = true
	_p = Vector3(at.x, WorldLayout.WATER_LEVEL, at.z)
	_dip = 0.0
	cast_rod = rod_id()
	cast_bait = bait
	if not FishTable.is_lure(bait):
		PlayerState.inventory.remove_item(bait, 1)
	elif _rng.randf() < FishTable.LURE_LOSS:
		# The spinner caught in the weed: the line snaps free without it.
		PlayerState.inventory.remove_item(bait, 1)
		Game.notify(tr("MSG_FISH_LURE_SNAGGED") % ItemDB.get_item(bait).display_name(), Color(1.0, 0.7, 0.45))
	# Every cast wears the rod.
	player.wear_tool(PlayerState.selected_stack(), 1)
	FishingAudio.play("plop", _p)
	PondFx.ring(_p, 1.0, 2.4, 1.3)
	PondFx.drops(_p, 14, 1.5, 0.04)
	Events.line_cast.emit()
	catch_info = roll_catch()
	# Its model loads while the float sits (at least 5 s before the bite).
	var species: StringName = catch_info.get("species", catch_info["id"])
	if FishTable.is_fish(species):
		FishModels.flop_mesh(species)
	else:
		FishModels.real_mesh(species)
	_bite_at = _rng.randf_range(BITE_TIME.x, BITE_TIME.y) * float(FishTable.rod_stats(cast_rod)["bite"])
	_nibbles.clear()
	for i in _rng.randi_range(1, 3):
		_nibbles.append(maxf(_bite_at - _rng.randf_range(0.5, 3.5), 1.2))
	if _bite_at > 9.0 and _rng.randf() < 0.6:
		# A curious fish earlier on that swims off.
		_nibbles.append(_rng.randf_range(2.5, _bite_at - 4.0))
	_nibbles.sort()


## The fish that will bite this cast, as play rolls it: the bait on the hook, the hour,
## the weather, the rod in hand and the fish landed since the last trophy.
func roll_catch() -> Dictionary:
	return FishTable.roll(bait, GameClock.get_hour_float(), Weather.is_raining(), _rng, rod_id(),
			PlayerState.fish_since_trophy)


func _land_on_ground(at: Vector3) -> void:
	_p = at + Vector3(0, 0.02, 0)
	_grounded = true
	_on_water = false
	FishingAudio.play("flop", _p, -14.0, 1.6)
	Game.notify(tr("MSG_FISH_ON_LAND"), Color(1.0, 0.7, 0.45))
	state = State.RETRIEVE
	_t = -0.5
	_retrieve_len = 1.2
	_reeling_up = false


func _nibble() -> void:
	_dip = 1.0
	FishingAudio.play("nibble", _p)
	PondFx.ring(_p, 0.45, 1.4, 0.7)
	PondFx.drops(_p, 4, 0.7, 0.03, 0.003)


func _start_bite() -> void:
	state = State.BITE
	_t = 0.0
	_fx_t = 0.0
	var a := _rng.randf() * TAU
	_bite_dir = Vector3(cos(a), 0.0, sin(a))
	_bite_off = Vector3.ZERO
	_bite_again = false
	FishingAudio.play("bite", _p)
	_bite_burst(1.4 * _heft())
	# No progress ring here: it would sit right over the float. The prompt says strike.
	player.add_trauma(0.12 * _heft())


func _bite_burst(strength: float) -> void:
	var at := _p + _bite_off
	PondFx.ring(at, 1.3 * strength, 1.8, 1.8 * strength)
	PondFx.drops(at, roundi(30 * strength), 2.4 * strength, 0.15, 0.007)
	PondFx.spray(at, 0.8 + 0.4 * strength)


func _strike() -> void:
	state = State.STRIKE
	_t = 0.0
	var from := Vector3(_p.x + _bite_off.x, WorldLayout.WATER_LEVEL, _p.z + _bite_off.z)
	FishingAudio.play("splash", from)
	_bite_burst(1.6 * _heft())
	if _is_trophy():
		# A giant heaved out: it strains the rod, a second, deeper splash and spray.
		player.wear_tool(PlayerState.selected_stack(), TROPHY_WEAR)
		FishingAudio.play("splash", from, 0.0, 0.8)
		PondFx.spray(from, 2.2)
		PondFx.ring(from, 2.6, 2.6, 2.4)
	player.kick_view(Vector4(1.4, 0.0, -0.4, 0.0) * _heft(), 0.1 * _heft())
	_reel_sfx = FishingAudio.play("reel", _tip(), -2.0, 1.25)
	_fish = FloppingFish.launch(catch_info, from, _landing_spot(from), FISH_FLIGHT)
	_fish.landed.connect(_on_fish_landed.bind(catch_info.duplicate()))
	_float.visible = false
	_on_water = false


func _on_fish_landed(info: Dictionary) -> void:
	var id: StringName = info["id"]
	# The run since the last giant (FishTable.pity): a trophy ends it, junk doesn't count.
	if FishTable.is_trophy(id):
		PlayerState.fish_since_trophy = 0
	elif FishTable.is_fish(id):
		PlayerState.fish_since_trophy += 1
	_announce(id, info)
	if state != State.STRIKE:
		return
	# The hook comes out: the float swings back up to the rod on the line.
	if is_instance_valid(_fish):
		_p = _fish.mouth()
	_prev = _p
	_rope = _p.distance_to(_tip())
	_reeling_up = true
	_float.visible = true
	_fish = null


## The catch named in a message, coloured by its rarity (with its weight and quality).
func _announce(id: StringName, info: Dictionary) -> void:
	var item := ItemDB.get_item(id)
	if item == null:
		return
	var sp := FishTable.get_species(FishTable.species_of(id))
	var rarity: int = sp.get("rarity", 0)
	if FishTable.is_trophy(id):
		# The catch of the season: a gold banner, a fanfare and the weight.
		Game.notify(tr("MSG_FISH_TROPHY") % [item.display_name(), FloppingFish.weight_text(float(info["kg"]))], UiTheme.GOLD)
		CampSfx.play("trophy", null, -4.0, 0.0)
		player.kick_view(Vector4(-1.0, 0.0, 0.6, 0.0), 0.15)
	elif sp.get("junk", false):
		Game.notify(tr("MSG_FISH_JUNK") % item.display_name(), FishTable.RARITY_COLORS[rarity])
	else:
		var text := tr("MSG_FISH_CAUGHT") % [item.display_name(), FloppingFish.weight_text(float(info["kg"])),
				tr(FishTable.RARITY_KEYS[rarity])]
		var q := int(info["quality"])
		if q > 0:
			text += "  ★ " + tr("UI_QUALITY_GOLD" if q == 2 else "UI_QUALITY_SILVER")
		# Which bait did it: named when it was the fish's favourite.
		if cast_bait != &"" and FishTable.favourite_bait(id) == cast_bait:
			text += "  · " + tr("MSG_FISH_FAV_BAIT") % ItemDB.get_item(cast_bait).display_name()
		Game.notify(text, FishTable.RARITY_COLORS[rarity])


func _escape() -> void:
	if FishTable.is_lure(cast_bait) and PlayerState.inventory.count_item(cast_bait) > 0:
		# It went off with the spinner in its jaw.
		PlayerState.inventory.remove_item(cast_bait, 1)
		Game.notify(tr("MSG_FISH_LURE_TAKEN") % ItemDB.get_item(cast_bait).display_name(), Color(1.0, 0.6, 0.4))
	else:
		Game.notify(tr("MSG_FISH_ESCAPED"), Color(1.0, 0.6, 0.4))
	PondFx.ring(_p, 0.8, 1.8, 0.9)
	_bite_off = Vector3.ZERO
	_retrieve()


## Reels the line in (nothing on it).
func _retrieve() -> void:
	state = State.RETRIEVE
	_t = 0.0
	_reeling_up = not _on_water
	var d := Vector2(_p.x, _p.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
	_retrieve_len = clampf(d / RETRIEVE_SPEED + 0.6, 0.8, 4.5)
	_reel_sfx = FishingAudio.play("reel", _tip(), 0.0, 1.0)


func _to_idle() -> void:
	state = State.IDLE
	_on_water = false
	_reeling_up = false
	_rope = HANG
	FishingAudio.fade(_reel_sfx, 0.25)
	_reel_sfx = null


## Everything put away (the rod left the hand, the player got in a vehicle...).
func cancel() -> void:
	if state == State.WINDUP:
		Events.action_progress_finished.emit(false)
	state = State.IDLE
	_on_water = false
	_reeling_up = false
	_rope = HANG
	FishingAudio.fade(_reel_sfx, 0.1)
	_reel_sfx = null
	_float.visible = false
	_line.clear()
	_clear_pose()


func _check_hand() -> void:
	if not holding_rod():
		cancel()
	elif not _warmed:
		# The rod in hand for the first time: its sounds load now, not mid-cast.
		_warmed = true
		FishingAudio.preload_all()


# --- Every tick ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var active := holding_rod() and player.driving == null and player.riding == null and not player.held.stowed
	if not active:
		if state != State.IDLE or _float.visible or _posed:
			cancel()
		return
	_t += delta
	match state:
		State.WINDUP:
			if Game.is_ui_open():
				cancel()
				return
			power = clampf(_t / WINDUP_FULL, 0.0, 1.0)
			Events.action_progress_updated.emit(power)
		State.CAST:
			if not _released and _cast_u() >= float(ToolAnim.PROFILES[&"rod_cast"]["release"]):
				_launch()
			elif _released:
				_fly(delta)
		State.WAIT:
			if not _nibbles.is_empty() and _t >= _nibbles[0]:
				_nibbles.pop_front()
				_nibble()
			if _t >= _bite_at:
				_start_bite()
		State.BITE:
			_fx_t -= delta
			# The fish pulls the float about under the surface.
			_bite_off = _bite_off.lerp(_bite_dir * 0.25 * sin(_t * 5.0) + _bite_dir.cross(Vector3.UP) * 0.12 * sin(_t * 8.3), clampf(delta * 10.0, 0.0, 1.0))
			if _fx_t <= 0.0:
				_fx_t = _rng.randf_range(0.22, 0.4) / _heft()
				_bite_burst(_rng.randf_range(0.7, 1.1) * _heft())
			if not _bite_again and _t >= 1.0:
				# The thrashing goes on for the whole window (the takes are about a second).
				_bite_again = true
				FishingAudio.play("bite", _p, -3.0)
			if _t >= BITE_WINDOW:
				_escape()
		State.RETRIEVE:
			if _on_water and _t > 0.0:
				_skim(delta)
	# Walked off with the line out, or teleported (loading, sleeping): in it comes.
	if state in [State.WAIT, State.BITE] and _p.distance_to(player.global_position) > MAX_LINE:
		cancel()


## The float drawn across the water toward the player, leaving a wake.
func _skim(delta: float) -> void:
	var to := player.global_position - _p
	to.y = 0.0
	var step := to.normalized() * RETRIEVE_SPEED * delta
	var next := _p + step
	_fx_t -= delta
	if _fx_t <= 0.0:
		_fx_t = 0.18
		PondFx.ring(_p, 0.35, 1.2, 0.5)
	if not Pond.is_fishable(next) or to.length() < 2.5:
		_on_water = false
		_reeling_up = true
		_prev = _p
		_rope = _p.distance_to(_tip())
		PondFx.drops(_p, 6, 1.0, 0.03)
		return
	_p = next


func _process(delta: float) -> void:
	if not holding_rod() or player.driving != null or player.riding != null or player.held.stowed:
		return
	_clock += delta
	_update_pose()
	var tip := _tip()
	match state:
		State.IDLE, State.WINDUP:
			_float.visible = true
			_rope = HANG
			_pendulum(delta, tip)
		State.CAST:
			if not _released:
				_pendulum(delta, tip)
		State.WAIT, State.BITE:
			pass
		State.STRIKE:
			if not _reeling_up and not is_instance_valid(_fish) and _t > FISH_FLIGHT + 0.5:
				# The fish is gone (freed with the world): nothing on the line.
				_reeling_up = true
				_float.visible = true
				_prev = _p
			if _reeling_up:
				_rope = maxf(_rope - REEL_UP_SPEED * 1.6 * delta, HANG)
				_pendulum(delta, tip)
				if _rope <= HANG + 0.001 and _t >= STRIKE_TIME:
					_to_idle()
		State.RETRIEVE:
			if _reeling_up or (_grounded and _t > 0.0):
				_grounded = false
				if not _reeling_up:
					_reeling_up = true
					_prev = _p
					_rope = _p.distance_to(tip)
				_rope = maxf(_rope - REEL_UP_SPEED * delta, HANG)
				_pendulum(delta, tip)
				if _rope <= HANG + 0.001 and _t >= _retrieve_len:
					_to_idle()
	_place_float(delta, tip)
	_draw_line(tip)


## The float on its line from the rod tip: a pendulum that swings with the rod (verlet;
## the line only pulls, never pushes).
func _pendulum(delta: float, tip: Vector3) -> void:
	if not _float.visible or _p == Vector3.ZERO:
		_p = tip + Vector3.DOWN * _rope
		_prev = _p
	var dt := minf(delta, 1.0 / 30.0)
	# Air drag on the float (a swing dies away in a few seconds).
	var v := (_p - _prev) * pow(0.25, dt)
	_prev = _p
	_p += v + Vector3.DOWN * 9.8 * dt * dt
	var d := _p - tip
	if d.length() > _rope:
		_p = tip + d.normalized() * _rope


func _place_float(delta: float, tip: Vector3) -> void:
	var up := Vector3.UP
	var pos := _p
	if _on_water and state in [State.WAIT, State.BITE, State.RETRIEVE]:
		_dip = move_toward(_dip, 0.0, delta * 3.5)
		var bob := sin(_clock * 2.3) * 0.003 + sin(_clock * 3.7 + 1.0) * 0.002
		pos = Vector3(_p.x, WorldLayout.WATER_LEVEL + bob - 0.016 * sin(_dip * PI), _p.z)
		up = Vector3(sin(_clock * 1.7) * 0.05, 1.0, cos(_clock * 1.3) * 0.05).normalized()
		if state == State.BITE:
			# Pulled under and about, tipping toward the pull.
			pos += _bite_off + Vector3.DOWN * (0.045 + 0.015 * sin(_t * 17.0))
			up = (Vector3.UP + _bite_dir * 0.8 * sin(_t * 5.0)).normalized()
		elif state == State.RETRIEVE:
			up = (Vector3.UP + (player.global_position - _p).normalized() * 0.5).normalized()
	elif _grounded:
		up = Vector3(1, 0.2, 0).normalized()
	else:
		up = (tip - _p).normalized() if tip.distance_to(_p) > 0.01 else Vector3.UP
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	# Out on the water it is drawn a little larger with distance, so it still reads as a
	# red dot on the surface (a real float at 15 m is a pixel).
	var grow := clampf(pos.distance_to(player.camera.global_position) / 6.0, 1.0, 2.6) if _on_water else 1.0
	_float.global_transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized().scaled(Vector3.ONE * grow), pos)


func _draw_line(tip: Vector3) -> void:
	if not _float.visible and state != State.STRIKE:
		_line.clear()
		return
	var end := _float.global_position + _float.global_basis.y * 0.012
	var sag := 0.0
	var water := NAN
	match state:
		State.CAST:
			sag = 0.015 * tip.distance_to(end)
		State.WAIT:
			# Slack enough to bow down and lie on the water just before the float.
			sag = 0.012 * tip.distance_to(end) + 0.04
			water = WorldLayout.WATER_LEVEL
		State.BITE:
			sag = 0.004 * tip.distance_to(end)
			water = WorldLayout.WATER_LEVEL - 0.08
		State.RETRIEVE:
			sag = 0.012 * tip.distance_to(end)
			water = WorldLayout.WATER_LEVEL if _on_water else NAN
		State.STRIKE:
			if is_instance_valid(_fish) and _fish.is_flying():
				end = _fish.mouth()
	_line.draw_line(tip, end, sag, water)


# --- The rod's strokes ------------------------------------------------------------------

func _windup_u() -> float:
	return minf(_t / 0.35, 1.0) * 0.3 + power * 0.25


func _cast_u() -> float:
	return lerpf(_cast_from_u, 1.0, clampf(_t / CAST_TIME, 0.0, 1.0))


func _update_pose() -> void:
	match state:
		State.IDLE:
			_clear_pose()
		State.WINDUP:
			_pose(&"rod_cast", _windup_u())
		State.CAST:
			_pose(&"rod_cast", _cast_u())
		State.WAIT:
			_pose(&"rod_wait", fposmod(_clock / WAIT_LOOP, 1.0))
		State.BITE:
			_pose(&"rod_bite", fposmod(_t * 1.8, 1.0))
		State.STRIKE:
			_pose(&"rod_strike", clampf(_t / STRIKE_TIME, 0.0, 1.0))
		State.RETRIEVE:
			_pose(&"rod_retrieve", clampf(maxf(_t, 0.0) / _retrieve_len, 0.0, 1.0))


func _pose(profile: StringName, u: float) -> void:
	player.held.debug_pose(profile, u)
	_posed = true


func _clear_pose() -> void:
	if _posed:
		player.held.debug_pose(&"", -1.0)
		_posed = false


# --- Helpers ----------------------------------------------------------------------------

## The rod tip in the world (the held rod's model), else just above the view.
func _tip() -> Vector3:
	var id := rod_id()
	var rod := ItemModels.mesh(id)
	for c in player.held.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh == rod:
			return (c as MeshInstance3D).global_transform * FishModels.rod_tip(id)
	var cam := player.camera
	return cam.global_transform * Vector3(0.0, 0.6, -1.6)


func _current_bait() -> StringName:
	if bait != &"" and PlayerState.inventory.count_item(bait) > 0:
		return bait
	for b in FishTable.BAITS:
		if ItemDB.has_item(b) and PlayerState.inventory.count_item(b) > 0:
			return b
	return &""


func _bait_kinds() -> int:
	var n := 0
	for b in FishTable.BAITS:
		if ItemDB.has_item(b) and PlayerState.inventory.count_item(b) > 0:
			n += 1
	return n


## Some cast in the look direction lands in the pond's water.
func _water_ahead() -> bool:
	var pos := player.global_position
	var far := reach().y
	if Vector2(pos.x, pos.z).distance_to(WorldLayout.POND_CENTER) > WorldLayout.POND_RADIUS + far + 2.0:
		return false
	var fwd := _look()
	var flat := Vector3(fwd.x, 0.0, fwd.z).normalized()
	var d := 1.0
	while d <= far + 2.5:
		if Pond.is_fishable(pos + flat * d):
			return true
		d += 0.5
	return false


## Whether the fish on the line is a trophy.
func _is_trophy() -> bool:
	return bool(catch_info.get("trophy", false))


## How much harder a trophy pulls and splashes (1 for any other fish).
func _heft() -> float:
	return 1.6 if _is_trophy() else 1.0


## Where the player looks (the view's punch and shake left out).
func _look() -> Vector3:
	return -(player.global_basis * player.head.basis).z


func _ray_exclude() -> Array[RID]:
	var out: Array[RID] = [player.get_rid()]
	var pond := player.get_tree().get_first_node_in_group(&"pond") as Pond
	if pond and pond.shore_wall():
		out.append(pond.shore_wall().get_rid())
	return out


## Where a caught fish comes down: on the bank 2-3 m from the player, to the side of the
## way the player faces the water (in view), else behind; never in the water.
func _landing_spot(from: Vector3) -> Vector3:
	var pos := player.global_position
	var to_water := Vector3(from.x - pos.x, 0.0, from.z - pos.z).normalized()
	var space := player.get_world_3d().direct_space_state
	var sides := [1.0, -1.0] if _rng.randf() < 0.5 else [-1.0, 1.0]
	var tries: Array[float] = []
	for a in [70.0, 95.0, 50.0, 120.0, 145.0, 170.0]:
		for s: float in sides:
			tries.append(deg_to_rad(a) * s + deg_to_rad(_rng.randf_range(-12.0, 12.0)))
	for ang in tries:
		var dir := to_water.rotated(Vector3.UP, ang)
		var p := pos + dir * _rng.randf_range(FISH_LAND.x, FISH_LAND.y)
		var h := TerrainData.height(p.x, p.z)
		if h < WorldLayout.WATER_LEVEL + 0.08 or Pond.is_fishable(p):
			continue
		if Vector2(p.x, p.z).distance_to(WorldLayout.POND_CENTER) < WorldLayout.POND_RADIUS - 0.6:
			continue
		# Open ground: nothing stands there, and the way from the player is clear.
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, h + 3.0, p.z), Vector3(p.x, h - 0.3, p.z), 1)
		q.exclude = _ray_exclude()
		var hit := space.intersect_ray(q)
		if hit.is_empty() or absf((hit["position"] as Vector3).y - h) > 0.25:
			continue
		var q2 := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.6, 0), Vector3(p.x, h + 0.4, p.z), 1)
		q2.exclude = _ray_exclude()
		if not space.intersect_ray(q2).is_empty():
			continue
		return Vector3(p.x, h, p.z)
	var back := pos - to_water * 1.6
	return Vector3(back.x, TerrainData.height(back.x, back.z), back.z)
