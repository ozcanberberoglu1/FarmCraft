class_name Campfire
extends PlacedObject
## A campfire put down from the "campfire" item (PlaceableTable kind "campfire"): a
## ring of stones with logs laid in it (CampfireModel), only on open ground (never under
## a roof, on a field, a track or in the yard's fixtures: placement_reason).
##
## E lights it (a match, the kindling catching, flames growing): it burns BURN_MINUTES
## of game time (5 hours), its logs charring and sinking, then dies down to glowing
## embers for EMBER_MINUTES and to cold ash. E with wood in hand adds an hour (and
## relights embers or ash). LMB with a filled watering can puts it out: steam, a hiss,
## and it sinks away and is gone within DOUSE_GONE seconds. F picks an unlit one back
## up, or clears the ash away.
##
## Cooking: E with a raw fish (cat "fish": a whole one, or one cleaned at the food table)
## or a piece of game meat (cat "meat") in hand at a burning fire (or its embers)
## puts it on a stick over the flames, up to SPITS at once; it browns and sizzles for
## COOK_SECONDS (the HUD's CookRings count each down) and "<id>_cooked" flies into the
## bag (Events.food_cooked); away from the fire it waits on its stick until the farmer
## comes back. State is kept in its FarmState.placed entry: "state" (laid, lit, embers,
## ash), "burn_left" and "embers_left" (game minutes), "char" (0..1, how burnt the logs
## are) and "spits" ([[slot, fish id, seconds left]]).
##
## A giant (trophy) fish doesn't fit over the fire: it needs a grill (Grill extends this,
## with more places laid out on a grate, where a giant takes two side by side).

const BURN_MINUTES := 300.0
const EMBER_MINUTES := 60.0
## An armful of wood: game minutes it adds, and the most a fire can have ahead of it.
const WOOD_MINUTES := 60.0
const MAX_BURN := 480.0
## Real seconds a fish cooks, and how many fit over the fire.
const COOK_SECONDS := 10.0
const SPITS := 3
## Real seconds the flames take to grow once lit (and once relit).
const IGNITE_SECONDS := 4.0
const RELIGHT_SECONDS := 2.5
## Seconds from being doused to gone.
const DOUSE_GONE := 9.0
## A cooked fish goes into the bag when the farmer is this close (m).
const DELIVER_RANGE := 16.0
## Sticks: pushed in at this radius, leaning in this far from upright, this long; the
## fish sits this far up them.
const STICK_RADIUS := 0.76
const STICK_LEAN := 0.86
const STICK_LENGTH := 0.8
const FISH_AT := 0.6
## Longest a fish on a stick is drawn (m); its model is scaled to it.
const FISH_LENGTH := 0.27
## What the fish browns to over the fire (multiplied over its colours).
const BROWN := Color(0.62, 0.42, 0.25)

var state := "laid"
var burn_left := BURN_MINUTES
var embers_left := EMBER_MINUTES
var _char := 0.0
var _logs: MeshInstance3D
var _bed: MeshInstance3D
var _stones: Array[MultiMeshInstance3D] = []
var _scorch: Decal
var _fx: CampfireFx
var _sizzle: AudioStreamPlayer3D
var _sizzle_level := 0.0
## Per slot: {} or {"id", "left", "done_t", "node", "fish", "overlay", "steam"}.
var _spits: Array[Dictionary] = []
var _last_total := 0.0
var _ignite := 0.0
var _ignite_len := IGNITE_SECONDS
## Seconds since it was doused (-1: it wasn't).
var _doused := -1.0
var _save_in := 0.0
## What the farmer is told when it burns down (a grill says its own).
var burnt_key := "MSG_CAMPFIRE_BURNT_DOWN"


func _ready() -> void:
	# Solid for walking into (layer 1) and a target for the interaction ray (layer 4).
	collision_layer = 1 | 4
	collision_mask = 0
	add_to_group(&"interactable")
	add_to_group(&"placed")
	add_to_group(&"campfires")
	var size: Vector3 = PlaceableTable.get_info(item_id).get("size", Vector3(1.15, 0.45, 1.15))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = size.y * 0.5
	add_child(cs)
	for i in _slot_count():
		_spits.append({})
	_build()
	_load_entry()
	_last_total = GameClock.total_minutes
	_refresh(true)
	if Game.world and Game.world.has_method("block_grass"):
		var p := global_position
		Game.world.block_grass(Rect2(p.x - 0.8, p.z - 0.8, 1.6, 1.6))


# --- Model ----------------------------------------------------------------------------

func _build() -> void:
	var center := global_position
	for scan in CampfireModel.STONE_SCANS.size():
		var xfs: Array[Transform3D] = []
		for entry: Array in CampfireModel.stone_layout():
			if int(entry[0]) != scan:
				continue
			var xf: Transform3D = entry[1]
			# Each stone sits on the ground under it.
			var w := global_transform * xf.origin
			xf.origin.y = TerrainData.height(w.x, w.z) - center.y - 0.035
			xfs.append(xf)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = CampfireModel.stone_mesh(scan)
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
			# The fire's centre, for the soot on the faces turned to it.
			mm.set_instance_custom_data(i, Color(center.x, center.y, center.z, 1.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.layers = 2
		add_child(mmi)
		_stones.append(mmi)
	_bed = MeshInstance3D.new()
	_bed.mesh = CampfireModel.bed_mesh()
	_bed.layers = 2
	add_child(_bed)
	_logs = MeshInstance3D.new()
	_logs.mesh = CampfireModel.logs_mesh()
	_logs.layers = 2
	add_child(_logs)
	var phase := randf()
	for mi: MeshInstance3D in [_bed, _logs]:
		mi.set_instance_shader_parameter("phase", phase)
	# The ground blackened around it (not the stones or logs: layer 1 only).
	_scorch = Decal.new()
	_scorch.size = Vector3(2.0, 0.9, 2.0)
	_scorch.texture_albedo = CampfireModel.scorch_texture()
	_scorch.cull_mask = 1
	_scorch.normal_fade = 0.35
	_scorch.upper_fade = 0.2
	_scorch.lower_fade = 0.3
	_scorch.modulate = Color(1, 1, 1, 0)
	_scorch.visible = false
	add_child(_scorch)
	_fx = CampfireFx.new()
	add_child(_fx)
	_sizzle = CampSfx.loop("sizzle_loop", self, -80.0, 2.2)
	_sizzle.position = Vector3(0, 0.4, 0)


## Stones, logs and coals as the fire's state and time have them.
func _refresh(snap := false) -> void:
	var heat := 0.0
	var coals := 0.0
	var smoke := 0.0
	var glow := 0.0
	var ash := 0.0
	match state:
		"lit":
			# Dying down over its last hour.
			heat = lerpf(0.35, 1.0, clampf(burn_left / 60.0, 0.0, 1.0))
			if _ignite > 0.0:
				heat *= 1.0 - _ignite / _ignite_len
			coals = 1.0
			smoke = 0.55 + 0.2 * (1.0 - heat)
			glow = 0.35 + 0.65 * clampf(heat * 1.2, 0.0, 1.0)
		"embers":
			var k := clampf(embers_left / EMBER_MINUTES, 0.0, 1.0)
			coals = 0.25 + 0.75 * k
			smoke = 0.3 * k + 0.08
			glow = 0.25 + 0.55 * k
			ash = 0.35 * (1.0 - k)
		"ash":
			ash = 1.0
	_fx.heat = heat
	_fx.coals = coals
	_fx.smoke = smoke
	if snap:
		_fx.snap()
	var burn := _char if state != "ash" else maxf(_char, 0.9)
	for mi: MeshInstance3D in [_logs, _bed]:
		mi.set_instance_shader_parameter("burn", burn)
		mi.set_instance_shader_parameter("glow", glow)
		mi.set_instance_shader_parameter("ash", ash)
	# The teepee sinks and spreads as it burns down, and falls in when it's out.
	var sink := burn if state != "ash" else 1.0
	_logs.scale = Vector3(1.0 + 0.14 * sink, 1.0 - 0.6 * sink, 1.0 + 0.14 * sink)
	_logs.visible = not (state == "ash" and _char >= 1.0)
	_bed.visible = state != "laid" or _char > 0.01
	if _scorch:
		_scorch.visible = _bed.visible
		_scorch.modulate.a = clampf(0.25 + _char * 2.0, 0.0, 0.85) if _bed.visible else 0.0


# --- Burning ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _doused >= 0.0:
		_update_douse(delta)
		return
	var total := GameClock.total_minutes
	var minutes := total - _last_total
	_last_total = total
	if minutes > 0.0:
		_burn(minutes)
	if _ignite > 0.0:
		_ignite = maxf(_ignite - delta, 0.0)
	_update_cooking(delta)
	_refresh()
	_save_in -= delta
	if _save_in <= 0.0:
		_save_in = 1.0
		_store()


## `minutes` of game time on the fire (a whole night at once after sleeping).
func _burn(minutes: float) -> void:
	var left := minutes
	if state == "lit":
		# Rain eats the fire twice as fast.
		var rate := 2.0 if Weather.is_raining() else 1.0
		var used := minf(left * rate, burn_left)
		burn_left -= used
		_char = minf(_char + used / BURN_MINUTES, 1.0)
		left -= used / rate
		if burn_left <= 0.0:
			_burnt_down()
	if state == "embers" and left > 0.0:
		embers_left -= left
		if embers_left <= 0.0:
			embers_left = 0.0
			state = "ash"
			_store()


func _burnt_down() -> void:
	state = "embers"
	burn_left = 0.0
	embers_left = EMBER_MINUTES
	_store()
	Events.campfire_out.emit(self)
	var player := Game.player as Node3D
	if player and player.global_position.distance_to(global_position) < 40.0 and not Game.is_ui_open():
		Game.notify(tr(burnt_key), UiTheme.TEXT_MUTED)


## E on a laid fire: a match, then the kindling catches and the flames grow.
func light() -> void:
	state = "lit"
	burn_left = BURN_MINUTES
	embers_left = EMBER_MINUTES
	_ignite = IGNITE_SECONDS
	_ignite_len = IGNITE_SECONDS
	_store()
	var at := global_position + Vector3(0, 0.2, 0)
	CampSfx.play("match", at, -4.0, 0.04, 2.5)
	get_tree().create_timer(0.75, false).timeout.connect(func() -> void:
		if is_instance_valid(self) and state == "lit" and _doused < 0.0:
			CampSfx.play("ignite", at, -3.0, 0.05, 3.5)
			_fx.pop(0.6))
	Events.campfire_lit.emit(self)


## E with wood in hand: another hour on the fire; embers and ash catch again.
func add_wood() -> void:
	if state == "lit" and burn_left > MAX_BURN - WOOD_MINUTES:
		Game.notify(tr("MSG_CAMPFIRE_ENOUGH_WOOD"), UiTheme.TEXT_MUTED)
		return
	if not PlayerState.inventory.remove_item(&"wood", 1):
		return
	var relit := state != "lit"
	burn_left = minf((burn_left if state == "lit" else 0.0) + WOOD_MINUTES, MAX_BURN)
	embers_left = EMBER_MINUTES
	state = "lit"
	# Fresh wood on the pile.
	_char = clampf(_char - 0.25, 0.15, 1.0)
	_store()
	Audio.play("wood_hit", global_position + Vector3(0, 0.3, 0), -8.0, 0.1, &"Effects", 3.0)
	_fx.pop(1.4)
	if relit:
		_ignite = RELIGHT_SECONDS
		_ignite_len = RELIGHT_SECONDS
		CampSfx.play("ignite", global_position + Vector3(0, 0.2, 0), -5.0, 0.05, 3.5)
		Events.campfire_lit.emit(self)


## Whether it is burning (flames or embers): it cooks and it can be put out.
func is_burning() -> bool:
	return (state == "lit" or state == "embers") and _doused < 0.0


# --- Putting it out ----------------------------------------------------------------

## Water on the fire: out at once in a cloud of steam, gone from the farm; it sinks
## away over the next seconds.
func douse() -> void:
	if _doused >= 0.0:
		return
	_doused = 0.0
	state = "out"
	FarmState.remove_placed(entry)
	_give_back_spits()
	_fx.douse()
	_fx.pop(0.5)
	var at := global_position + Vector3(0, 0.25, 0)
	CampSfx.play("douse", at, 0.0, 0.04, 4.0)
	Fx.water_splash(global_position + Vector3(0, 0.08, 0))
	_sizzle.stop()
	# No more prompts: it is going.
	remove_from_group(&"interactable")
	collision_layer = 1
	Events.campfire_out.emit(self)
	Game.notify(tr("MSG_CAMPFIRE_DOUSED"), UiTheme.TEXT_MUTED)


func _update_douse(delta: float) -> void:
	_doused += delta
	var t := _doused
	# The coals hiss out and blacken; wisps of steam keep rising a while.
	var cool := clampf(t / 1.6, 0.0, 1.0)
	for mi: MeshInstance3D in [_logs, _bed]:
		mi.set_instance_shader_parameter("glow", 0.6 * (1.0 - cool))
		mi.set_instance_shader_parameter("ash", 0.0)
	_fx.smoke = 0.6 * (1.0 - clampf((t - 1.0) / 4.5, 0.0, 1.0))
	# Then it sinks into the ground and is gone.
	var sink := clampf((t - 5.5) / (DOUSE_GONE - 6.0), 0.0, 1.0)
	var s := sink * sink
	for n: Node3D in [_logs, _bed]:
		n.position.y = -0.3 * s
	for mmi in _stones:
		mmi.position.y = -0.28 * s
	_scorch.modulate.a = lerpf(_scorch.modulate.a, 0.0, clampf(delta * 0.6, 0.0, 1.0)) if t > 4.0 else _scorch.modulate.a
	if t >= 5.5 and t - delta < 5.5:
		Fx.dust_cloud(global_position + Vector3(0, 0.15, 0), Vector2(0.5, 0.5))
	if t >= DOUSE_GONE:
		queue_free()


# --- Cooking ----------------------------------------------------------------------------

## Categories that cook over the fire: fish (whole or cleaned) and game meat.
const COOKS: Array[String] = ["fish", "meat"]


## The cooked item a raw one becomes over the fire (&"" when it doesn't cook): a cleaned
## fish or meat cooks into its own dish, which fills far more than a whole grilled fish.
static func cooked_id(id: StringName) -> StringName:
	if not ItemDB.has_item(id) or not ItemDB.get_item(id).category in COOKS:
		return &""
	var c := StringName(String(id) + "_cooked")
	return c if ItemDB.has_item(c) else &""


static func _cookable(stack: ItemStack) -> bool:
	return stack != null and cooked_id(stack.item.id) != &""


## How many places over the fire there are (a grill has more).
func _slot_count() -> int:
	return SPITS


## Places `id` takes side by side (a grill gives a giant fish two).
func _span_of(_id: StringName) -> int:
	return 1


## Whether `id` fits over this fire at all: a giant (trophy) fish needs a grill.
func _takes(id: StringName) -> bool:
	return not FishTable.is_trophy(id)


## The first free place with `span` free places from it on (-1: none).
func _free_spit(span := 1) -> int:
	for i in _slot_count():
		if _span_fits(i, span):
			return i
	return -1


## Whether `span` places from `slot` on are all free.
func _span_fits(slot: int, span: int) -> bool:
	for k in span:
		if slot + k >= _slot_count() or not _spits[slot + k].is_empty():
			return false
	return true


## Empties a place (and the one a giant fish shared with it).
func _clear_slot(slot: int) -> void:
	var span := int(_spits[slot].get("span", 1))
	for k in span:
		if slot + k < _spits.size():
			_spits[slot + k] = {}


## Seconds left, done and where each fish on the fire is (the HUD's rings):
## [[world point, seconds left, done]].
func cook_status() -> Array:
	var out := []
	for s: Dictionary in _spits:
		if s.is_empty() or s.has("link") or not is_instance_valid(s["fish"]):
			continue
		var fish := s["fish"] as Node3D
		out.append([fish.global_position, maxf(float(s["left"]), 0.0), float(s["left"]) <= 0.0])
	return out


## E with a raw fish in hand: it goes onto a stick over the fire.
func _start_cooking(player: Player) -> void:
	var stack := PlayerState.selected_stack()
	if stack == null:
		return
	if not _takes(stack.item.id):
		Game.notify(tr("MSG_CAMPFIRE_TOO_BIG"), UiTheme.TEXT_MUTED)
		return
	var slot := _free_spit(_span_of(stack.item.id))
	if slot < 0:
		Game.notify(tr("MSG_CAMPFIRE_FULL"), UiTheme.TEXT_MUTED)
		return
	var taken := PlayerState.inventory.take_from(PlayerState.selected, 1)
	if taken == null:
		return
	_put_on_spit(slot, taken.item.id, COOK_SECONDS, player)
	_store()


## A stick pushed into the ground outside the ring, leaning in over the flames, the
## fish on it (flown there from the farmer's hand).
func _put_on_spit(slot: int, id: StringName, left: float, player: Player = null) -> void:
	var a := TAU * float(slot) / SPITS + 0.55
	var foot := Vector3(cos(a), 0.0, sin(a)) * STICK_RADIUS
	var w := global_transform * foot
	foot.y = TerrainData.height(w.x, w.z) - global_position.y
	var inward := -Vector3(cos(a), 0.0, sin(a))
	var dir := (inward * sin(STICK_LEAN) + Vector3.UP * cos(STICK_LEAN)).normalized()
	var node := Node3D.new()
	var side := dir.cross(inward).normalized()
	node.basis = Basis(side, dir, side.cross(dir).normalized())
	node.position = foot
	add_child(node)
	var stick := MeshInstance3D.new()
	stick.mesh = CampfireModel.stick_mesh(STICK_LENGTH)
	stick.layers = 2
	node.add_child(stick)
	var fish := food_mesh(id)
	fish.transform = _fish_transform(fish.mesh)
	var overlay := fish.material_overlay as StandardMaterial3D
	node.add_child(fish)
	# Steam off the fish as it cooks.
	var steam := food_steam()
	steam.position = fish.transform.origin
	node.add_child(steam)
	steam.emitting = true
	_spits[slot] = {"id": id, "left": left, "done_t": 0.0, "node": node, "fish": fish, "overlay": overlay, "steam": steam}
	if player != null and is_instance_valid(player):
		# Flies from the hand onto the stick, the stick pushed in as it lands.
		_fly_in(fish, node, player)
		stick.position = Vector3(0, 0.25, 0)
		stick.create_tween().tween_property(stick, "position", Vector3.ZERO, 0.25).set_delay(0.1) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Audio.play("soft", w + Vector3(0, 0.2, 0), -12.0, 0.1, &"Effects", 2.0)
		get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
			if is_instance_valid(self):
				CampSfx.play("fire_pop", global_position + Vector3(0, 0.3, 0), -12.0, 0.2, 2.0, 1.3))


## The food's model, a browning overlay over its colours.
static func food_mesh(id: StringName) -> MeshInstance3D:
	var fish := MeshInstance3D.new()
	fish.mesh = ItemModels.mesh(id)
	fish.layers = 2
	var overlay := StandardMaterial3D.new()
	overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	overlay.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	overlay.albedo_color = Color.WHITE
	fish.material_overlay = overlay
	return fish


## Flies `fish` from the farmer's hand to where it sits under `node`.
static func _fly_in(fish: MeshInstance3D, node: Node3D, player: Player) -> void:
	var to := fish.transform
	var cam := player.camera
	var from := node.global_transform.affine_inverse() * Transform3D(cam.global_basis, cam.global_position
			- cam.global_basis.z * 0.5 + cam.global_basis.x * 0.2 - cam.global_basis.y * 0.2)
	fish.transform = Transform3D(from.basis.orthonormalized().scaled(to.basis.get_scale()), from.origin)
	var tw := fish.create_tween()
	tw.tween_property(fish, "transform", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Wisps of steam off food as it cooks (not yet emitting).
static func food_steam() -> CPUParticles3D:
	var steam := CPUParticles3D.new()
	steam.amount = 4
	steam.lifetime = 1.4
	steam.mesh = CampfireFx._quad(CampfireFx.smoke_material(), false)
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.06
	steam.direction = Vector3.UP
	steam.spread = 15.0
	steam.gravity = Vector3(0, 0.25, 0)
	steam.initial_velocity_min = 0.1
	steam.initial_velocity_max = 0.25
	steam.scale_amount_min = 0.08
	steam.scale_amount_max = 0.16
	steam.scale_amount_curve = CampfireFx._curve([Vector2(0, 0.6), Vector2(1, 2.2)])
	steam.color = Color(0.92, 0.92, 0.9, 0.22)
	steam.color_ramp = CampfireFx._ramp([[0.0, 0.0], [0.2, 1.0], [1.0, 0.0]])
	steam.local_coords = false
	steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	steam.layers = 2
	steam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	return steam


## The fish's model laid along the stick, near its top, scaled to FISH_LENGTH.
static func _fish_transform(mesh: Mesh) -> Transform3D:
	if mesh == null:
		return Transform3D(Basis(), Vector3(0, STICK_LENGTH * FISH_AT, 0))
	var box := mesh.get_aabb()
	var ext := box.size
	var basis := Basis()
	var length := ext.x
	if ext.z >= ext.x and ext.z >= ext.y:
		# Along Z: turned up onto the stick.
		basis = Basis(Vector3.RIGHT, -PI * 0.5)
		length = ext.z
	elif ext.x >= ext.y:
		basis = Basis(Vector3.FORWARD, -PI * 0.5)
		length = ext.x
	else:
		length = ext.y
	var s := clampf(FISH_LENGTH / maxf(length, 0.001), 0.2, 4.0)
	basis = basis.scaled(Vector3.ONE * s)
	var origin := Vector3(0, STICK_LENGTH * FISH_AT, 0) - basis * box.get_center()
	return Transform3D(basis, origin)


func _update_cooking(delta: float) -> void:
	var cooking := 0
	var paused := Game.is_paused()
	for i in _slot_count():
		var s := _spits[i]
		if s.is_empty() or s.has("link"):
			continue
		if not is_instance_valid(s["fish"]):
			_clear_slot(i)
			continue
		var left := float(s["left"])
		if left > 0.0:
			if not paused and is_burning():
				left -= delta
				s["left"] = left
			cooking += 1
			var k := clampf(1.0 - left / COOK_SECONDS, 0.0, 1.0)
			(s["overlay"] as StandardMaterial3D).albedo_color = Color.WHITE.lerp(BROWN, k * k * (3.0 - 2.0 * k))
			if left <= 0.0:
				_cooked(i)
			elif not paused and randf() < delta * 0.5:
				# Fat dripping onto the coals.
				CampSfx.play("fire_pop", global_position + Vector3(0, 0.2, 0), -16.0, 0.25, 2.0, 1.4)
		else:
			s["done_t"] = float(s["done_t"]) + delta
			if float(s["done_t"]) > 0.45:
				_deliver(i)
	# The sizzle follows how many fish are over the fire.
	var want := 0.0 if cooking == 0 or not is_burning() else minf(0.55 + 0.2 * cooking, 1.0)
	_sizzle_level = move_toward(_sizzle_level, want, delta * 1.5)
	_sizzle.volume_db = linear_to_db(maxf(_sizzle_level, 0.0001)) - 4.0
	if _sizzle_level > 0.01:
		CampSfx.start_loop(_sizzle)
	elif _sizzle.playing:
		_sizzle.stop()


## Done: the cooked fish's own model (when it has one) takes the raw one's place.
func _cooked(slot: int) -> void:
	var s := _spits[slot]
	s["left"] = 0.0
	s["done_t"] = 0.0
	var cooked := cooked_id(StringName(s["id"]))
	var fish := s["fish"] as MeshInstance3D
	if cooked != &"":
		var m := ItemModels.mesh(cooked)
		if m != null and m != fish.mesh:
			fish.mesh = m
			fish.transform = _lay(m, slot)
			(s["overlay"] as StandardMaterial3D).albedo_color = Color.WHITE.lerp(BROWN, 0.35)
	(s["steam"] as CPUParticles3D).emitting = false
	_store()


## Where the food's model sits in its place's node (a fish on its stick here).
func _lay(mesh: Mesh, _slot: int) -> Transform3D:
	return _fish_transform(mesh)


## A cooked fish into the bag (flying into the hand or the hotbar) when the farmer is
## near; at their feet if the bag is full.
func _deliver(slot: int) -> void:
	var s := _spits[slot]
	var player := Game.player as Player
	if player == null or player.global_position.distance_to(global_position) > DELIVER_RANGE or Game.is_ui_open():
		return
	var cooked := cooked_id(StringName(s["id"]))
	var fish := s["fish"] as MeshInstance3D
	var from := fish.global_transform
	if cooked != &"":
		if PlayerState.give(cooked, 1) > 0:
			Pickup.spawn(ItemStack.create(cooked, 1), global_position + Vector3(0, 0.7, 0), Vector3(0, 1.5, 0))
		else:
			player.show_take(cooked, from)
		Events.food_cooked.emit(cooked)
	Audio.play("soft", from.origin, -12.0, 0.1, &"Effects", 2.0)
	(s["node"] as Node3D).queue_free()
	_clear_slot(slot)
	_store()


## Fish still on their sticks back into the bag (the fire put out or cleared away):
## raw ones raw, cooked ones cooked.
func _give_back_spits() -> void:
	for i in _slot_count():
		var s := _spits[i]
		if s.is_empty() or s.has("link"):
			continue
		var id := StringName(s["id"])
		if float(s["left"]) <= 0.0 and cooked_id(id) != &"":
			id = cooked_id(id)
		if ItemDB.has_item(id) and PlayerState.give(id, 1) > 0:
			Pickup.spawn(ItemStack.create(id, 1), global_position + Vector3(0, 0.7, 0), Vector3(0, 1.5, 0))
		if is_instance_valid(s["node"]):
			(s["node"] as Node3D).queue_free()
		_clear_slot(i)


# --- Interaction ------------------------------------------------------------------------

func interact_title() -> String:
	return display_name()


func display_name() -> String:
	var item := ItemDB.get_item(item_id)
	return item.display_name() if item else tr("ITEM_CAMPFIRE")


func interact_prompt(_player: Node) -> String:
	if _doused >= 0.0:
		return ""
	var stack := PlayerState.selected_stack()
	var wood := stack != null and stack.item.id == &"wood"
	match state:
		"laid":
			return tr("ACTION_LIGHT")
		"lit", "embers":
			if _cookable(stack):
				return tr("ACTION_COOK")
			if wood:
				return tr("ACTION_ADD_WOOD")
		"ash":
			if wood:
				return tr("ACTION_RELIGHT")
	return ""


func interact(player: Node) -> void:
	if _doused >= 0.0:
		return
	var stack := PlayerState.selected_stack()
	var wood := stack != null and stack.item.id == &"wood"
	match state:
		"laid":
			light()
		"lit", "embers":
			if _cookable(stack):
				_start_cooking(player as Player)
			elif wood:
				add_wood()
		"ash":
			if wood:
				add_wood()


## What the fire is doing (a plain line under the prompts), and how to cook on it.
func hint_prompt() -> String:
	if _doused >= 0.0:
		return ""
	var stack := PlayerState.selected_stack()
	match state:
		"laid":
			return tr("CAMPFIRE_READY")
		"lit":
			var line := tr("CAMPFIRE_BURNING") % _duration(burn_left)
			if _cookable(stack) and not _takes(stack.item.id):
				line += "\n" + tr("MSG_CAMPFIRE_TOO_BIG")
			elif not _cookable(stack) and _free_spit() >= 0 and cook_status().is_empty():
				line += "\n" + tr("HINT_CAMPFIRE_COOK")
			return line
		"embers":
			return tr("CAMPFIRE_EMBERS")
		"ash":
			return tr("CAMPFIRE_ASH")
	return ""


static func _duration(minutes: float) -> String:
	var m := maxi(ceili(minutes), 1)
	var h := floori(m / 60.0)
	if h == 0:
		return tr_static("CROP_TIME_M") % m
	if m % 60 == 0:
		return tr_static("CROP_TIME_H") % h
	return tr_static("CROP_TIME_HM") % [h, m % 60]


static func tr_static(key: String) -> String:
	return TranslationServer.translate(key)


## LMB with the watering can: put it out.
func use_prompt(_player: Node, stack: ItemStack) -> String:
	return tr("ACTION_DOUSE") if not _douse_action(stack).is_empty() else ""


func use_action(_player: Node, stack: ItemStack) -> Dictionary:
	return _douse_action(stack)


func _douse_action(stack: ItemStack) -> Dictionary:
	if stack == null or stack.item.tool_type != &"watering_can" or not is_burning():
		return {}
	return {"id": "douse", "verb": "ACTION_DOUSE", "label": "PROGRESS_DOUSING", "duration": 1.1}


func can_start(_action: Dictionary, stack: ItemStack) -> String:
	if stack.water <= 0:
		return tr("MSG_CAN_EMPTY")
	return ""


## The can's drops landing on the coals hiss (the look only).
func use_impact(_player: Node, _stack: ItemStack, _action: Dictionary, hit: Dictionary) -> void:
	if not bool(hit.get("final", false)):
		Fx.drips(global_position + Vector3(randf_range(-0.15, 0.15), 0.12, randf_range(-0.15, 0.15)))
		_fx.hiss()
		CampSfx.play("fire_pop", global_position + Vector3(0, 0.2, 0), -10.0, 0.2, 2.5, 1.5)


func complete_use(_player: Node, stack: ItemStack, _action: Dictionary) -> void:
	stack.water -= 1
	PlayerState.inventory.changed.emit()
	douse()


func can_pick_up() -> bool:
	return state == "laid" and _doused < 0.0


## F: an unlit fire back into the bag; a burnt-out one cleared away.
func info_prompt() -> String:
	if _doused >= 0.0:
		return ""
	match state:
		"laid":
			return tr("ACTION_PICK_UP")
		"ash":
			return tr("ACTION_CLEAR")
	return ""


func info_interact(player: Node) -> void:
	if _doused >= 0.0:
		return
	match state:
		"laid":
			super.info_interact(player)
		"ash":
			_give_back_spits()
			FarmState.remove_placed(entry)
			Fx.dust_cloud(global_position + Vector3(0, 0.15, 0), Vector2(0.5, 0.5))
			Audio.play("soft", global_position + Vector3(0, 0.2, 0), -6.0, 0.1, &"Effects", 3.0)
			Audio.play("dig", global_position + Vector3(0, 0.2, 0), -12.0, 0.1, &"Effects", 3.0)
			queue_free()


# --- Placement ------------------------------------------------------------------------

## Why a fire can't go at `p` on top of the placer's own checks ("" when it can): not
## on ground kept for fields, tracks, the house and the yard, not in the water and
## never under a roof.
static func placement_reason(player: Node, p: Vector3) -> String:
	if Placer.reserved(p.x, p.z):
		return "MSG_PLACE_RESERVED"
	if TerrainData.is_underwater(p.x, p.z, 0.1) or WorldLayout.distance_to_pond(p.x, p.z) < WorldLayout.POND_RADIUS + 1.0:
		return "MSG_PLACE_WATER"
	var body := player as CollisionObject3D
	if body:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.6, 0), p + Vector3(0, 14.0, 0), 1)
		q.exclude = [body.get_rid()]
		if not body.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			return "MSG_CAMPFIRE_ROOF"
	return ""


# --- Saving -----------------------------------------------------------------------------

func _load_entry() -> void:
	state = String(entry.get("state", "laid"))
	if not state in ["laid", "lit", "embers", "ash"]:
		state = "laid"
	burn_left = float(entry.get("burn_left", BURN_MINUTES))
	embers_left = float(entry.get("embers_left", EMBER_MINUTES))
	_char = clampf(float(entry.get("char", 0.0)), 0.0, 1.0)
	for s: Variant in entry.get("spits", []):
		var a := s as Array
		if a == null or a.size() < 3:
			continue
		var slot := int(a[0])
		var id := StringName(String(a[1]))
		if slot < 0 or not ItemDB.has_item(id) or not _span_fits(slot, _span_of(id)):
			continue
		_put_on_spit(slot, id, float(a[2]))
		if float(a[2]) <= 0.0:
			_cooked(slot)


func _store() -> void:
	if _doused >= 0.0:
		return
	entry["state"] = state
	entry["burn_left"] = burn_left
	entry["embers_left"] = embers_left
	entry["char"] = _char
	var spits := []
	for i in _slot_count():
		var s := _spits[i]
		if not s.is_empty() and not s.has("link"):
			spits.append([i, String(s["id"]), float(s["left"])])
	entry["spits"] = spits
