class_name Vehicle
extends VehicleBody3D
## A drivable vehicle built from a VehicleTable entry: the downloaded model turned to
## face +Z (VehicleBody3D forward), four raycast wheels carrying the model's wheel
## meshes, a turning steering wheel, head/brake/reverse lights, fuel, a cargo bed
## (Stockpile drawn as packages by CargoBed, loaded by hand through BedPoint; the load
## adds its weight; crated hens ride in it too) and a driver camera (first person or
## chase, toggled with V). Grandpa's pickup is locked on a new farm until his key
## (found in the house) goes into the ignition; that stays saved in FarmState.flags.
## Getting in and out is announced on Events (vehicle_entered / vehicle_exited).
## The entry's "paint", "trim", "wheel", "glass" and "plate" keys set how it looks and
## how worn it is.

signal changed

const GROUP := &"vehicles"
## Litres of fuel burnt per hour while idling.
const IDLE_BURN := 0.8
## Vehicles that stay locked until their key is found: kind -> key item.
const KEYS := {&"pickup_old": &"truck_key"}
## FarmState.flags entry set for good once a vehicle's key is in its ignition.
const UNLOCK_FLAG := "unlocked_%s"
## Wheel arch opening radius as a share of the tyre radius.
const ARCH_GAP := 1.32
## Headlamp and reverse lamp glow: the emission is the lamp's own texture (darker than
## white), scaled up. Red lamps stay below the tonemapper's white shoulder.
const LAMP_GLOW := 2.2
## Tail and brake lamp emission (the lens texture times this red).
const BRAKE_RED := Color(1.0, 0.03, 0.015)
## Tail lamp emission energy, lights on / braking: low, as the night exposure lifts it
## several times and a brighter red washes out to pink.
const TAIL_GLOW := 0.4
const BRAKE_GLOW := 2.2
## Side window dust relative to the windshield's (wound down, wiped by the seals).
const SIDE_GRIME := 0.45
## Sunk into the ground (shoved in, or so saved): its wheels' contact patches, as they sit
## at the ride height, this deep under the terrain on average (m), or one of them this
## deep (more than the springs give on a bump).
const SINK_MEAN := 0.15
const SINK_DEEPEST := 0.32
## The steering wheel turns this many times the road wheels' angle (about three quarters
## of a turn to full lock; a real box is nearer 16:1, too busy to watch with a key held).
## An entry's "steer_ratio" sets its own.
const STEER_RATIO := 8.0
## How far down and up the driver can look (radians); round about there is no limit.
const LOOK_DOWN := deg_to_rad(55.0)
const LOOK_UP := deg_to_rad(40.0)
## Where the passenger seat's cushion is taken to be from the driver's eyes when no seat
## is found on the meshes either (passenger_seat): this far below them and ahead of them (m).
const PASSENGER_DROP := 0.66
const PASSENGER_AHEAD := 0.28
## Collision layer of barriers only vehicles run into (the warehouse door): people,
## animals and what they carry pass.
const BARRIER_LAYER := 64
## Never lost (see _watch_lost). A vehicle has left the world when its origin is LOST_DEEP m
## under the terrain (through the ground: the terrain is one sheet with nothing under it),
## LOST_HIGH m over it (no jump or hill gets it there), or LOST_OUT m beyond the edge of the
## playable land (the boundary wall stops a driven one at 0).
const LOST_DEEP := 2.0
const LOST_HIGH := 45.0
const LOST_OUT := 12.0
## Speed gained within one physics tick (m/s) that no engine, slope or bump gives (they
## stay under 0.5): it was thrown by something.
const LOST_KICK := 8.0
## Lying over this far (its up against the world's: on its side or its roof) and still for
## LOST_TIP_TIME seconds: stuck, put back on its wheels.
const LOST_TIPPED := 0.3
const LOST_TIP_TIME := 2.5
## Its place is taken as its last good one this often (s) while it rolls on its wheels,
## upright (its up against the world's at least SAFE_UP).
const SAFE_EVERY := 0.5
const SAFE_UP := 0.7
## Put back further than this (m) from where it was found, the farmer is told.
const LOST_TELL := 3.0

## Every vehicle in the world (walkers keep off them: keep_out, way_round).
static var all: Array[Vehicle] = []
## Passenger seats measured at play, by kind, for entries that keep none ("seat").
static var _seats_measured := {}

var kind: StringName
var info: Dictionary
var owned := true
## Seconds a parked vehicle has stood still (see _hold_when_parked).
var _settle_t := 0.0
## Times it was lifted out of the ground on settling since last driven (see _unsink).
var _lifts := 0
## Where it last stood as it should: settled and held, as the driver got out, or rolling
## on its four wheels a moment ago (see _watch_lost); as spawned until then.
var _safe := Transform3D()
## Where the world first had it (the dealer's stock goes back there).
var _spawn := Transform3D()
var _safe_t := 0.0
## Its speed at the last physics tick (negative: not known, e.g. just put somewhere).
var _speed_was := -1.0
var _tip_t := 0.0
var _told_back := -1000000
## Times the net has put it back or righted it (tests).
var rescues := 0
## Its body's footprint (the collision boxes, body frame: x across, y along body z), their
## bottom and top (body y) and how far the footprint's corners reach from its origin.
var _footprint := Rect2()
var _box_y := Vector2.ZERO
var _reach := 0.0
## While it is held on display and turned by hand (see turn_on_display): each wheel's
## pose under the body as it stood (wheel key -> local transform). Empty otherwise.
var _display_pose := {}
var price := 0
var fuel := 0.0
var cargo: Stockpile
var driver: Node = null
var lights_on := false
var chase_camera := false
var odometer := 0.0

var _wheels := {}
## Wheel -> suspension mount point (body frame).
var _mounts := {}
## Wheel -> its hub where the springs hold it at rest (body frame: the model's own).
var _hubs := {}
## Wheel -> its tyre mesh, and where that sits on the wheel node (see _seat_tyres).
var _tyres := {}
var _tyre_at := {}
var _steer_pivot: Node3D
var _steer_axis := Vector3.FORWARD
## The cab's instrument needles ("speed", "fuel") -> [mesh, its basis at rest, its turn] (see _turn_needles).
var _needles := {}
var _steer := 0.0
var _mid_x := 0.0
var _eye_rig: Node3D
var _cam: Camera3D
var _chase: Camera3D
var _look := Vector2.ZERO
var _beams: Array[SpotLight3D] = []
## Wide, weak low beams that light the verges and ditches near the truck.
var _fills: Array[SpotLight3D] = []
var _dash_light: OmniLight3D
var _tail_light: OmniLight3D
## Lamp materials by role ("head", "brake", "reverse"): one per source material, all
## switched together.
var _lamps := {"head": [], "brake": [], "reverse": []}
## Dressing materials by VehicleLook.surface_material key ("paint", "trim:<name>", ...).
var _mats := {}
## Paint and trim meshes (each gets its own frame, see VehicleLook.fit_frame).
var _framed: Array[MeshInstance3D] = []
## Wheel arches in the model frame: front and rear axle x, hub height, opening radius.
var _arches := Vector4(1.93, -1.23, 0.385, 0.47)
## Tail lamp and side marker glow last given to the trim (set only when it changes).
var _trim_glow := Vector2(-1.0, -1.0)
## Window glass and lamp covers by source material.
var _glass_mats := {}
var _cover_mats := {}
var _throttle := 0.0
var _out_of_fuel_told := false
var _manual_lights := false
var _base_mass := 1400.0
var _base_com := Vector3(0, 0.32, 0.1)
var _bed: CargoBed
## Set once a loaded game has put this vehicle where it was left.
var restored := false
## Crated animals aboard by item id, to tell when one comes aboard.
var _live_aboard := {}
## Waypoint anchors: over the cab roof and over the bed (see waypoint_roof/_bed).
var _roof_marker: Marker3D
var _bed_marker: Marker3D


static func create(kind_id: StringName, xform: Transform3D, for_sale := false) -> Vehicle:
	var v := Vehicle.new()
	v.kind = kind_id
	v.info = VehicleTable.get_info(kind_id)
	v.price = int(v.info.get("price", 0))
	v.owned = not for_sale
	v.fuel = float(v.info.get("fuel_capacity", 40.0)) * 0.5
	v.transform = xform
	return v


func _enter_tree() -> void:
	if not all.has(self):
		all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _ready() -> void:
	# Moved in physics ticks: drawn between ticks (see Settings._ready).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	name = "Vehicle_%s" % kind
	_base_mass = float(info.get("mass", 1400.0))
	mass = _base_mass
	collision_layer = 1 | 4
	collision_mask = 1 | 2 | 16 | BARRIER_LAYER
	add_to_group(&"interactable")
	add_to_group(GROUP)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	# VehicleBody3D applies tyre side forces at the contact patch and scales their
	# roll lever from the body origin (on the ground here), not from the centre of
	# mass, so wheel_roll_influence has no effect; a low centre of mass keeps the
	# body from rolling onto its outer wheels.
	_base_com = Vector3(0, float(info.get("com_height", 0.32)), 0.1)
	center_of_mass = _base_com
	angular_damp = 0.6
	linear_damp = 0.05
	cargo = Stockpile.new(int(info.get("cargo_units", 100)))
	_build_model()
	_build_body()
	_build_lights()
	_build_cameras()
	_build_markers()
	set_lights(false)
	_spawn = global_transform
	_safe = _spawn
	cargo.changed.connect(_on_cargo_changed)
	# Tests and screenshot runs skip the story: every key is already in its ignition.
	if DebugTools.is_automated() and key_item() != &"":
		FarmState.flags[unlock_flag()] = true
	if key_item() != &"":
		SaveGame.loaded.connect(_on_game_loaded)


## Model frame (front +X, left -Z) -> body frame (front +Z, left +X).
func _mb(m: Vector3) -> Vector3:
	return Vector3(-m.z, m.y, m.x - _mid_x)


## Body frame -> model frame (what the table's entries are in).
func to_model(b: Vector3) -> Vector3:
	return Vector3(b.z + _mid_x, b.y, -b.x)


func _build_model() -> void:
	var holder := Node3D.new()
	holder.name = "Model"
	holder.rotation.y = -PI * 0.5
	add_child(holder)
	var model := VehicleLook.build_model(info)
	holder.add_child(model)
	_bed = CargoBed.new()
	_bed.name = "Load"
	# Packages are placed per frame while they drop in and in one jump when the load
	# changes: interpolated MultiMeshes would lag the drop and grow new ones from zero.
	_bed.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	holder.add_child(_bed)
	_bed.setup(cargo, info)
	var names: Dictionary = info["wheels"]
	var meshes := {}
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# It moves: SDFGI would voxelize it into every cascade it drives through.
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		for key: String in names:
			if String(names[key]) in String(mi.name):
				meshes[key] = mi
		if _is_steering_wheel(mi):
			meshes["steer"] = mi
		if String(mi.name).begins_with("Needle_"):
			_needles[String(mi.name).trim_prefix("Needle_").to_lower()] = [mi, mi.basis, 0.0]
		_restyle(mi)
	# Centre the wheelbase on the body origin (model +X became body +Z).
	var fl := _center_of(meshes["fl"])
	var rl := _center_of(meshes["rl"])
	_mid_x = (to_local(fl).z + to_local(rl).z) * 0.5
	var hub_f := holder.to_local(fl)
	var hub_r := holder.to_local(rl)
	var fl_mi: MeshInstance3D = meshes["fl"]
	var tyre := (holder.global_transform.affine_inverse() * fl_mi.global_transform * fl_mi.get_aabb()).size.y * 0.5
	_arches = Vector4(hub_f.x, hub_r.x, (hub_f.y + hub_r.y) * 0.5, tyre * ARCH_GAP)
	holder.position.z = -_mid_x
	var susp: Dictionary = info.get("suspension", {})
	for key: String in ["fl", "fr", "rl", "rr"]:
		var mi: MeshInstance3D = meshes[key]
		var c := to_local(_center_of(mi))
		# The tyre as it stands on the body, across its axle (body X): the model's wheel
		# nodes are scaled, so the mesh's own box is not its size.
		var tyre_box := global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		var radius := maxf(tyre_box.size.y, tyre_box.size.z) * 0.5
		var w := VehicleWheel3D.new()
		w.name = "Wheel_" + key
		var rest := float(susp.get("rest", 0.2))
		# Spring force is scaled by the chassis mass: every wheel sags g / (4 k) at
		# rest whatever the load, as the engine sees it (really more: spring_seen). Mount
		# it that much higher so the body sits at the model's ride height and the wheel
		# can still drop that far over dips.
		var sag := gravity_sag(float(susp.get("stiffness", 48.0))) / spring_seen(rest, radius)
		w.position = c + Vector3(0, rest - sag, 0)
		w.wheel_radius = radius
		w.wheel_rest_length = rest
		w.suspension_travel = float(susp.get("travel", 0.22))
		w.suspension_stiffness = float(susp.get("stiffness", 48.0))
		w.suspension_max_force = float(susp.get("max_force", 20000.0))
		w.damping_compression = float(susp.get("compression", 2.0))
		w.damping_relaxation = float(susp.get("relaxation", 2.6))
		# The rear grips a little more than the front: at the limit the truck runs wide
		# instead of swinging its tail round.
		var grip := float(info.get("grip", 6.0))
		w.wheel_friction_slip = grip if key.begins_with("r") else grip - 0.4
		w.wheel_roll_influence = float(susp.get("roll_influence", 0.05))
		w.use_as_steering = key.begins_with("f")
		w.use_as_traction = key.begins_with("r") or info.get("drive", "rwd") == "4wd"
		_mounts[key] = w.position
		_hubs[key] = c
		add_child(w)
		mi.reparent(w, true)
		# The wheel spins about its node's origin: centre the tyre on it (the node sits
		# above the model's hub by the spring travel), or it wobbles round an off-centre axle.
		mi.position -= mi.transform * mi.get_aabb().get_center()
		_wheels[key] = w
		_tyres[key] = mi
		_tyre_at[key] = mi.position
	if meshes.has("steer"):
		var sm: MeshInstance3D = meshes["steer"]
		_steer_pivot = Node3D.new()
		_steer_pivot.name = "SteeringPivot"
		add_child(_steer_pivot)
		_steer_pivot.position = to_local(_center_of(sm))
		var hint := sm.get_parent()
		sm.reparent(_steer_pivot, true)
		# The wheel node the importer made of it (see _is_steering_wheel) is left empty.
		if hint is VehicleWheel3D and hint.get_child_count() == 0:
			hint.queue_free()
		# Column tilts forward and down.
		_steer_axis = (info.get("steer_axis", Vector3(0, -0.36, 1)) as Vector3).normalized()


## The cab's instrument needles (meshes "Needle_Speed" and "Needle_Fuel",
## tools/blender/cab_kit.py) turn about the dial's normal, their own +Y, clockwise for
## the driver: 270 degrees for 0-160 km/h, 120 degrees from an empty tank to a full one.
func _turn_needles() -> void:
	for key: String in _needles:
		var needle: Array = _needles[key]
		var turn := needle_turn(key)
		# Only when it has moved: a parked vehicle's needles are left alone.
		if absf(turn - float(needle[2])) > 0.002:
			needle[2] = turn
			(needle[0] as Node3D).basis = (needle[1] as Basis) * Basis(Vector3.UP, -turn)


## How far the needle `key` ("speed", "fuel") stands from its rest, in radians.
func needle_turn(key: String) -> float:
	if key == "speed":
		return clampf(speed_kmh() / 160.0, 0.0, 1.0) * 1.5 * PI
	return clampf(fuel / maxf(float(info.get("fuel_capacity", 40.0)), 1.0), 0.0, 1.0) * TAU / 3.0


## Whether `mi` is the entry's "steering_wheel" mesh. The scene importer takes a node
## called "..._Wheel" for a wheel hint: it makes a VehicleWheel3D of it and drops the
## "_Wheel" from its name and from its mesh's, so the Blender-built models'
## "Steering_Wheel" arrives as a mesh "Steering" under a wheel node "Steering" (and was
## never found: their steering wheels stood still).
func _is_steering_wheel(mi: MeshInstance3D) -> bool:
	var want := String(info.get("steering_wheel", "~"))
	if want in String(mi.name):
		return true
	return mi.get_parent() is VehicleWheel3D and String(mi.name) == want.trim_suffix("_Wheel")


static func gravity_sag(stiffness: float) -> float:
	var g := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	return g / (4.0 * maxf(stiffness, 1.0))


## The share of a spring's compression the engine sees. VehicleBody3D (4.7) casts each
## wheel's ray from a wheel radius above its mount, down to rest + radius below it, but
## scales where it hit by the ray's length without that radius: of a spring really pushed
## in by c it sees c (rest + r) / (rest + 2 r), a softer spring, and stands the wheel
## node the rest of c too low, into the ground (see _seat_tyres).
static func spring_seen(rest: float, radius: float) -> float:
	return (rest + radius) / maxf(rest + 2.0 * radius, 0.001)


func _center_of(mi: MeshInstance3D) -> Vector3:
	return mi.global_transform * mi.get_aabb().get_center()


## Paint gets the clear-coated, weathered body shader (vehicle_paint), the bumpers, bull
## bar and underbody the trim shader (vehicle_trim), the wheels the tyre, rim and brake
## shader (vehicle_wheel), the cab its interior shader (see VehicleLook.surface_material);
## lamps (by mesh name: "headlights", "brakelights", "reverselights", a name or a list)
## get their own emissive copies with a reflector look, lenses a glossy face. "glass"
## gives the windows dust (and a crack) and can yellow the lamp covers; "plate" puts a
## number plate over the model's own.
func _restyle(mi: MeshInstance3D) -> void:
	var n := String(mi.name)
	var glass: Dictionary = info.get("glass", {})
	if "Numberplate" in n and info.has("plate"):
		VehicleLook.add_plate(mi, info["plate"])
	for si in mi.mesh.get_surface_count():
		var src := mi.get_active_material(si) as StandardMaterial3D
		if src == null:
			continue
		var role := VehicleLook.role_of(src)
		if role == "paint":
			mi.set_surface_override_material(si, VehicleLook.surface_material(src, info, _mats))
			if mi not in _framed:
				_framed.append(mi)
		elif _names_in(_as_list(info.get("headlights")), n):
			# Chrome reflector bowls behind the lenses.
			mi.set_surface_override_material(si, _lamp("head", src, info.get("lamp_color", Color(1.0, 0.95, 0.85)), 0.45))
		elif _names_in(_as_list(info.get("brakelights")), n):
			mi.set_surface_override_material(si, _lamp("brake", src, BRAKE_RED, 0.15))
		elif _names_in(_as_list(info.get("reverselights")), n):
			mi.set_surface_override_material(si, _lamp("reverse", src, Color(1.0, 1.0, 0.95), 0.3))
		elif _names_in(glass.get("panes", []), n) and src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			mi.set_surface_override_material(si, _worn_glass(src))
			_fit_pane(mi, si, glass)
		elif _names_in(glass.get("covers", []), n):
			mi.set_surface_override_material(si, _cover(src, glass))
		elif role != "":
			mi.set_surface_override_material(si, VehicleLook.surface_material(src, info, _mats))
			if role == "trim" and mi not in _framed:
				_framed.append(mi)


static func _as_list(v: Variant) -> Array:
	if v is Array:
		return v
	return [] if v == null else [String(v)]


## The emissive copy of a lamp's material for `role`, one per source material.
func _lamp(role: String, src: StandardMaterial3D, color: Color, metal: float) -> StandardMaterial3D:
	for m: StandardMaterial3D in _lamps[role]:
		if m.resource_name == src.resource_name:
			return m
	var m := _emissive(src, color, metal)
	m.resource_name = src.resource_name
	(_lamps[role] as Array).append(m)
	return m


## A lamp lens with a glossy face; an old one sun-yellowed and hazy underneath. Alpha
## stays so the lamps still shine through.
func _cover(src: StandardMaterial3D, glass: Dictionary) -> StandardMaterial3D:
	if not _cover_mats.has(src.resource_name):
		var m := src.duplicate() as StandardMaterial3D
		var tint: Color = glass.get("cover_tint", Color.WHITE)
		m.albedo_color = Color(src.albedo_color.r * tint.r, src.albedo_color.g * tint.g,
				src.albedo_color.b * tint.b, src.albedo_color.a)
		m.roughness = float(glass.get("cover_haze", 0.04))
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.clearcoat_roughness = 0.03
		_cover_mats[src.resource_name] = m
	return _cover_mats[src.resource_name]


## Whether the mesh name contains one of `names`.
static func _names_in(names: Array, mesh_name: String) -> bool:
	for part: String in names:
		if part in mesh_name:
			return true
	return false


## One dusty glass material for the windows of this vehicle (per source material);
## each pane's place in the texture atlas goes into its instance uniforms (_fit_pane).
## An untextured (Blender-built) pane's colour is the tint, its alpha how much of the
## view it keeps back.
func _worn_glass(src: StandardMaterial3D) -> ShaderMaterial:
	if not _glass_mats.has(src.resource_name):
		var glass: Dictionary = info["glass"]
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/vehicle_glass.gdshader")
		m.set_shader_parameter("albedo_tex", VehicleLook.albedo_of(src))
		m.set_shader_parameter("grime", float(glass.get("grime", 0.5)))
		var loss := float(glass.get("clarity_loss", 0.22))
		if src.albedo_texture:
			m.set_shader_parameter("tint", src.albedo_color)
		else:
			m.set_shader_parameter("tint", Color(1, 1, 1, 1))
			loss = maxf(loss, src.albedo_color.a)
		m.set_shader_parameter("clarity_loss", loss)
		_glass_mats[src.resource_name] = m
	return _glass_mats[src.resource_name]


## Tells the glass shader where this pane lies in the texture atlas, oriented so +x
## runs to the vehicle's right (on the side windows: forwards) and +y up, how wide
## it is for its height, and whether it has wipers or a crack.
func _fit_pane(mi: MeshInstance3D, si: int, glass: Dictionary) -> void:
	# Rain on the panes and the wipers (the rest of what the shader is told per pane).
	VehicleWipers.of(self, true)
	var arrays := mi.mesh.surface_get_arrays(si)
	if not (arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array):
		return
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if uvs.size() < 3 or uvs.size() != verts.size():
		return
	var lo := uvs[0]
	var hi := uvs[0]
	var i_lo := Vector2i.ZERO
	var i_hi := Vector2i.ZERO
	for i in uvs.size():
		var uv := uvs[i]
		if uv.x < lo.x:
			lo.x = uv.x
			i_lo.x = i
		if uv.x > hi.x:
			hi.x = uv.x
			i_hi.x = i
		if uv.y < lo.y:
			lo.y = uv.y
			i_lo.y = i
		if uv.y > hi.y:
			hi.y = uv.y
			i_hi.y = i
	if hi.x - lo.x < 0.0001 or hi.y - lo.y < 0.0001:
		return
	# Mesh space -> body frame (+X left, +Y up, +Z forward): which way u and v run.
	var to_body := global_transform.affine_inverse() * mi.global_transform
	var du := to_body * verts[i_hi.x] - to_body * verts[i_lo.x]
	var dv := to_body * verts[i_hi.y] - to_body * verts[i_lo.y]
	var pane_min := lo
	var pane_max := hi
	if dv.y < 0.0:
		pane_min.y = hi.y
		pane_max.y = lo.y
	# Across the windshield and rear glass: towards the vehicle's right (body -X);
	# along the side windows: forwards (body +Z).
	var across := Vector3(-1, 0, 0) if absf(du.x) >= absf(du.z) else Vector3(0, 0, 1)
	if du.dot(across) < 0.0:
		pane_min.x = hi.x
		pane_max.x = lo.x
	var along := du.normalized()
	var height := (dv - along * dv.dot(along)).length()
	mi.set_instance_shader_parameter("pane_min", pane_min)
	mi.set_instance_shader_parameter("pane_max", pane_max)
	mi.set_instance_shader_parameter("aspect", clampf(du.length() / maxf(height, 0.05), 0.25, 6.0))
	# Side windows face left or right (body X).
	var facing := du.cross(dv)
	var side := absf(facing.x) > absf(facing.z)
	mi.set_instance_shader_parameter("pane_grime", float(glass.get("side_grime", SIDE_GRIME)) if side else 1.0)
	var n := String(mi.name)
	mi.set_instance_shader_parameter("wipers", 1.0 if String(glass.get("wiped", "~")) in n else 0.0)
	if String(glass.get("cracked", "~")) in n:
		mi.set_instance_shader_parameter("crack_at", glass.get("crack_at", Vector2(0.7, 0.3)))


## A lamp: glows in its own pattern (the texture) when lit; `metal` makes the
## reflector shine through the lens when it is not.
func _emissive(src: StandardMaterial3D, color: Color, metal: float) -> StandardMaterial3D:
	var m := src.duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission = color
	m.emission_texture = src.albedo_texture
	m.emission_energy_multiplier = 0.0
	m.metallic = metal
	m.roughness = 0.14
	return m


func _build_body() -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for box: Array in info.get("boxes", []):
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var size: Vector3 = box[1]
		shape.size = Vector3(size.z, size.y, size.x)
		cs.shape = shape
		cs.position = _mb(box[0])
		add_child(cs)
		lo = lo.min(cs.position - shape.size * 0.5)
		hi = hi.max(cs.position + shape.size * 0.5)
	if lo.x < hi.x:
		_footprint = Rect2(lo.x, lo.z, hi.x - lo.x, hi.z - lo.z)
		_box_y = Vector2(lo.y, hi.y)
		for c: Vector2 in [_footprint.position, _footprint.end, Vector2(lo.x, hi.z), Vector2(hi.x, lo.z)]:
			_reach = maxf(_reach, c.length())
	if info.has("bed_zone"):
		var zone: AABB = info["bed_zone"]
		var point := BedPoint.new()
		point.name = "BedPoint"
		point.vehicle = self
		point.size = Vector3(zone.size.z, zone.size.y, zone.size.x)
		point.position = _mb(zone.get_center())
		add_child(point)
	# Paint dust and rust are placed in the model frame (height, arches, sides); the
	# panels have their own origins, e.g. the bed sits lower than the cab.
	var model := get_node("Model") as Node3D
	for mi: MeshInstance3D in _framed:
		VehicleLook.fit_frame(mi, model)
	for key: String in _mats:
		if key == "paint" or key.begins_with("trim:"):
			(_mats[key] as ShaderMaterial).set_shader_parameter("arches", _arches)
	_apply_quality()
	Settings.changed.connect(_apply_quality)


## Paint, trim and cab detail by quality: Low and Medium project the rust and grime
## once per map and skip the rust relief and the cab's moulded grain.
func _apply_quality() -> void:
	var detail := 1.0 if Settings.quality >= Settings.Quality.HIGH else 0.0
	for key: String in _mats:
		if not key.begins_with("wheel:"):
			(_mats[key] as ShaderMaterial).set_shader_parameter("detail", detail)


func _build_lights() -> void:
	var lamp: Color = info.get("lamp_color", Color(1.0, 0.93, 0.8))
	var at: Vector3 = info.get("beam_pos", Vector3(2.62, 0.87, 0.62))
	for side: float in [-1.0, 1.0]:
		var beam := SpotLight3D.new()
		beam.position = _mb(Vector3(at.x, at.y, side * at.z))
		# Spot lights shine along their -Z: aim forward and slightly down.
		beam.basis = Basis.looking_at(Vector3(0, -0.07, 1), Vector3.UP)
		beam.spot_range = 55.0
		beam.spot_angle = 24.0
		beam.spot_attenuation = 0.6
		beam.light_energy = 0.0
		beam.light_color = lamp
		beam.shadow_enabled = false
		add_child(beam)
		_beams.append(beam)
		var fill := SpotLight3D.new()
		fill.position = beam.position
		fill.basis = Basis.looking_at(Vector3(side * 0.3, -0.13, 1), Vector3.UP)
		fill.spot_range = 20.0
		fill.spot_angle = 50.0
		fill.spot_attenuation = 0.9
		fill.light_energy = 0.0
		fill.light_color = Color(lamp.r, lamp.g - 0.01, lamp.b)
		fill.shadow_enabled = false
		add_child(fill)
		_fills.append(fill)
	# Instrument backlight, on with the lights.
	_dash_light = OmniLight3D.new()
	_dash_light.position = _mb(info.get("dash_pos", Vector3(1.2, 1.2, -0.38)))
	_dash_light.light_color = Color(1.0, 0.62, 0.3)
	_dash_light.omni_range = 0.32
	_dash_light.omni_attenuation = 2.0
	_dash_light.light_energy = 0.0
	_dash_light.shadow_enabled = false
	add_child(_dash_light)
	_tail_light = OmniLight3D.new()
	_tail_light.position = _mb(info.get("tail_pos", Vector3(-2.55, 0.62, 0.0)))
	_tail_light.light_color = Color(1.0, 0.12, 0.06)
	_tail_light.omni_range = 2.0
	_tail_light.light_energy = 0.0
	add_child(_tail_light)


func _build_cameras() -> void:
	_eye_rig = Node3D.new()
	_eye_rig.name = "Eyes"
	_eye_rig.position = _mb(info.get("eyes", Vector3(0.4, 1.5, -0.38)))
	add_child(_eye_rig)
	# Both cameras are placed every frame from the interpolated body (see _process).
	_cam = Camera3D.new()
	_cam.name = "DriverCamera"
	_cam.fov = Settings.fov
	_cam.near = 0.05
	_cam.far = 800.0
	_cam.top_level = true
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_eye_rig.add_child(_cam)
	_chase = Camera3D.new()
	_chase.name = "ChaseCamera"
	_chase.fov = Settings.fov
	_chase.far = 800.0
	_chase.top_level = true
	_chase.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_chase)


## Points the story's waypoint dot can float over: the cab roof and the bed.
func _build_markers() -> void:
	_roof_marker = Marker3D.new()
	_roof_marker.name = "RoofMarker"
	_roof_marker.position = _mb(Vector3(0.3, float(info.get("roof_height", 2.15)), 0.0))
	add_child(_roof_marker)
	_bed_marker = Marker3D.new()
	_bed_marker.name = "BedMarker"
	var zone: AABB = info.get("bed_zone", AABB(Vector3(-1.6, 0.6, -0.7), Vector3(1.6, 0.6, 1.4)))
	_bed_marker.position = _mb(zone.get_center()) + Vector3(0, zone.size.y * 0.5 + 0.5, 0)
	add_child(_bed_marker)


## A spot over the cab roof (the waypoint to the truck).
func waypoint_roof() -> Node3D:
	return _roof_marker


## A spot over the bed (the waypoint to the load, e.g. crates to unload).
func waypoint_bed() -> Node3D:
	return _bed_marker


# --- Driving -----------------------------------------------------------------------

func is_driven() -> bool:
	return driver != null


## Moves the vehicle, e.g. delivery or debugging (rigid bodies need the server call).
func teleport(xf: Transform3D) -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, xf)
	global_transform = xf
	reset_physics_interpolation()
	sleeping = false
	_speed_was = -1.0
	_tip_t = 0.0


# --- Never lost -----------------------------------------------------------------------

## Whether a vehicle at `xf` has left the world: through the ground, up in the sky, far
## beyond the edge of the land, or nowhere at all (LOST_DEEP, LOST_HIGH, LOST_OUT).
static func lost_at(xf: Transform3D) -> bool:
	if not xf.is_finite():
		return true
	var o := xf.origin
	var ground := TerrainData.height(o.x, o.z)
	if o.y < ground - LOST_DEEP or o.y > ground + LOST_HIGH:
		return true
	return WorldLayout.playable_distance(o.x, o.z) < -LOST_OUT


## How upright `xf` stands (1 on its wheels, 0 on its side, -1 on its roof).
static func _upness(xf: Transform3D) -> float:
	return xf.basis.y.normalized().dot(Vector3.UP)


## Whatever happens to it, a vehicle is never lost for good. Each physics tick, driven or
## not: one that has left the world (lost_at), or that gained LOST_KICK m/s within a tick
## (thrown by something: a body swept through it), is put back at once where it last
## stood as it should (_safe; the nearest clear spot to that when something stands there
## now), upright and at rest, with its load, its driver, its dog and its trailer; one
## lying on its side or roof, still for LOST_TIP_TIME, is stood on its wheels where it
## lies; one hidden is shown again (nothing in the game hides a vehicle). Its last good
## place is kept up as it goes (SAFE_EVERY). Not while it is turned on the showroom's deck.
func _watch_lost(delta: float) -> void:
	if not is_inside_tree() or not _display_pose.is_empty():
		_speed_was = -1.0
		return
	if not visible:
		visible = true
	if freeze:
		# Held still: looked at twice a second.
		_safe_t += delta
		if _safe_t < SAFE_EVERY:
			return
		delta = _safe_t
		_safe_t = 0.0
	var xf := global_transform
	var speed := linear_velocity.length()
	var kicked := not freeze and _speed_was >= 0.0 and speed - _speed_was > LOST_KICK
	_speed_was = -1.0 if freeze else speed
	if kicked or lost_at(xf) or not is_finite(speed):
		_bring_back()
		return
	var up := _upness(xf)
	if up < LOST_TIPPED and speed < 0.6 and angular_velocity.length() < 0.6:
		_tip_t += delta
		if _tip_t > LOST_TIP_TIME:
			_right_itself()
			return
	else:
		_tip_t = 0.0
	if freeze:
		return
	_safe_t += delta
	if _safe_t >= SAFE_EVERY and up >= SAFE_UP and _on_wheels():
		_safe_t = 0.0
		_safe = xf


## Whether all its wheels are on something (only a body the physics moves knows).
func _on_wheels() -> bool:
	if _wheels.is_empty():
		return false
	for key: String in _wheels:
		if not (_wheels[key] as VehicleWheel3D).is_in_contact():
			return false
	return true


## Its place now is its last good one, when it stands there as it should (in the world,
## upright, not sunk into the ground).
func _note_safe() -> void:
	if not is_inside_tree() or not _display_pose.is_empty():
		return
	var xf := global_transform
	if lost_at(xf) or _upness(xf) < SAFE_UP or (not _wheels.is_empty() and _burial(xf).y > SINK_DEEPEST + 0.3):
		return
	_safe = xf
	_safe_t = 0.0


## Where an owned vehicle belongs when nothing better is known: the pickup's spot by the
## house (Town.farm_truck_home); the dealer's stock where the world first had it.
func home_place() -> Transform3D:
	return Town.farm_truck_home() if owned else _spawn


## The place to put it back: its last good one, else its home; the nearest clear spot to
## that when something stands there now.
func _safe_place() -> Transform3D:
	var to := _safe
	# Where it stood a moment ago it fits, whatever it was parked against, unless something
	# has come to stand in its place since.
	var slack := -0.05
	if lost_at(to) or _upness(to) < SAFE_UP:
		to = home_place()
		slack = 0.1
	if not is_clear_at(to, slack):
		to = clear_spot_near(to)
	return to


## Out of the world, or thrown: back at its last good place, at rest (held again once it
## has settled there). The farmer is told when it comes back from somewhere else.
func _bring_back() -> void:
	var from := global_transform
	var to := _safe_place()
	if lost_at(to):
		return
	_stand_at(to)
	if not from.is_finite() or from.origin.distance_to(to.origin) > LOST_TELL:
		_tell_back()


## On its side or roof and stuck: on its wheels where it lies, heading as it did, or at its
## last good place when it does not fit there.
func _right_itself() -> void:
	var from := global_transform
	var to := _upright(from)
	if lost_at(to) or not is_clear_at(to, 0.0):
		to = _safe_place()
		if lost_at(to):
			return
	_stand_at(to)
	# Righted where it lies he sees it happen; taken somewhere else he is told.
	if from.origin.distance_to(to.origin) > LOST_TELL:
		_tell_back()


## Put at `xf` at rest and let go to settle on its wheels there.
func _stand_at(xf: Transform3D) -> void:
	teleport(xf)
	if freeze and freeze_mode == RigidBody3D.FREEZE_MODE_STATIC:
		freeze = false
	_settle_t = 0.0
	_lifts = 0
	_safe = xf
	_safe_t = 0.0
	rescues += 1


## One warm line when the farmer's own vehicle was brought back (not twice within a minute).
func _tell_back() -> void:
	if not owned or not is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	if now - _told_back < 60000:
		return
	_told_back = now
	Game.notify(tr("MSG_VEHICLE_BACK") % display_name(), UiTheme.GOLD_SOFT)


## `xf` stood upright on the ground under it, heading the way it does, its wheels just on
## the ground (a hair above, to drop onto its springs).
func _upright(xf: Transform3D) -> Transform3D:
	var o := xf.origin
	var ahead := xf.basis.z
	if Vector2(ahead.x, ahead.z).length() < 0.05:
		# Standing on its nose or tail: the way its roof points.
		ahead = xf.basis.y * -signf(ahead.y)
	var yaw := atan2(ahead.x, ahead.z)
	var up := TerrainData.normal_at(o.x, o.z)
	var basis := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, yaw)
	var out := Transform3D(basis.orthonormalized(), Vector3(o.x, TerrainData.height(o.x, o.z), o.z))
	if not _wheels.is_empty():
		out.origin.y += _burial(out).y + 0.03
	return out


## Parked with nobody at the wheel (the player's own or stock at the dealer): once it has
## settled on its wheels it is held still, so it never creeps off over a long session (a
## heavy tractor or a truck on a slight slope would roll slowly on the parked brake);
## getting in lets it go.
func _hold_when_parked(delta: float) -> void:
	if driver != null:
		if freeze:
			freeze = false
			sleeping = false
		_settle_t = 0.0
		return
	if freeze:
		return
	_settle_t += delta
	if _settle_t > 1.5 and linear_velocity.length() < 0.05 and angular_velocity.length() < 0.05:
		# Settled sunk in the ground: lifted out first, held once it has settled again.
		if _lifts < 3 and _unsink():
			_lifts += 1
			return
		# Never held lying on its side or roof: it is righted first (_watch_lost).
		if _upness(global_transform) < LOST_TIPPED:
			return
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = true
		_note_safe()


## How deep its wheels stand in the ground (m; below it, negative): each one's contact
## patch as it sits at the ride height (the hub where the springs hold it at rest), under
## the terrain there; the mean of them (x) and the deepest (y).
func _burial(xf: Transform3D) -> Vector2:
	var sum := 0.0
	var deepest := -INF
	for key: String in _wheels:
		var d := _wheel_depth(xf, key)
		sum += d
		deepest = maxf(deepest, d)
	return Vector2(sum / maxf(float(_wheels.size()), 1.0), deepest)


func _wheel_depth(xf: Transform3D, key: String) -> float:
	var w := _wheels[key] as VehicleWheel3D
	var hub: Vector3 = _hubs[key]
	var p := xf * hub - xf.basis.y.normalized() * w.wheel_radius
	return TerrainData.height(p.x, p.z) - p.y


## Sunk into the ground (shoved in, or saved so: SINK_MEAN, SINK_DEEPEST): lifted back
## onto its wheels, upright on the ground under it, heading the way it was, and let go to
## settle (held again once it has). Left as it is when it stands as it should. Whether it
## was lifted.
func _unsink() -> bool:
	if not is_inside_tree() or _wheels.is_empty() or not _display_pose.is_empty():
		return false
	var xf := global_transform
	var b := _burial(xf)
	if b.x < SINK_MEAN and b.y < SINK_DEEPEST:
		return false
	# Its wheels just on the ground (the deepest one), a hair above to drop onto its springs.
	teleport(_upright(xf))
	if freeze:
		freeze = false
	_settle_t = 0.0
	return true


## Turns the vehicle by hand by `angle` radians about the vertical through `pivot`, as one
## piece with what it stands on (the showroom's turntable, Town._turn_showroom): it is
## held frozen (kinematic: it pushes what it turns into) and its wheels keep the pose they
## had under the body when it went on display. The physics step only places the wheels of
## a body it moves itself; for one turned by hand it leaves them standing where they were
## (or rolls them as if the car drove round the deck), so the pose is put back each turn.
func turn_on_display(angle: float, pivot: Vector3) -> void:
	if _display_pose.is_empty() or not freeze:
		_display_pose.clear()
		for key: String in _wheels:
			_display_pose[key] = (_wheels[key] as VehicleWheel3D).transform
	if not freeze or freeze_mode != RigidBody3D.FREEZE_MODE_KINEMATIC:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
	var turn := Transform3D(Basis(Vector3.UP, angle), pivot) * Transform3D(Basis(), -pivot)
	global_transform = turn * global_transform
	for key: String in _display_pose:
		(_wheels[key] as VehicleWheel3D).transform = _display_pose[key]
	# The tyres go with the wheels as they were just put (see _seat_tyres).
	_seat_tyres()


## Lets a vehicle held on display go: a free body again, whose wheels the physics step
## places once more (parked, it is held still again once it has settled).
func end_display() -> void:
	if _display_pose.is_empty():
		return
	_display_pose.clear()
	freeze = false
	sleeping = false
	_settle_t = 0.0


func set_driver(d: Node) -> void:
	var was := driver
	driver = d
	_look = Vector2.ZERO
	# A parked body may be asleep and would ignore the engine.
	can_sleep = d == null
	sleeping = false
	if d:
		_lifts = 0
		_unsink()
		_current_camera().make_current()
		_snap_chase()
	else:
		engine_force = 0.0
		brake = float(info.get("brake_force", 40.0)) * 0.3
		steering = 0.0
		for key: String in ["rl", "rr"]:
			(_wheels[key] as VehicleWheel3D).brake = 0.0
		# Where he got out is where it belongs, should anything throw it (_watch_lost).
		if was != null and _on_wheels():
			_note_safe()
		# Parking turns the engine and the lights off.
		_manual_lights = false
		set_lights(false)
		_tell_parked_at_market()
	changed.emit()
	if d and was == null:
		Events.vehicle_entered.emit(self)
	elif d == null and was != null:
		Events.vehicle_exited.emit(self)


## Parked at the Yeşilova Market with goods in the bed: the counter inside buys them
## (not crated hens or anything else it won't take).
func _tell_parked_at_market() -> void:
	if not owned or not is_inside_tree():
		return
	var sellable := false
	for e: Dictionary in cargo.entries():
		if ItemDB.get_item(e["id"]).sell_price > 0:
			sellable = true
			break
	if not sellable:
		return
	var town := get_tree().get_first_node_in_group(&"town") as Town
	if town and town.vehicle_at_market() == self:
		Game.notify(tr("MSG_PARKED_AT_MARKET"), UiTheme.GOLD_SOFT)


func _current_camera() -> Camera3D:
	return _chase if chase_camera else _cam


func forward_speed() -> float:
	return linear_velocity.dot(global_basis.z)


func speed_kmh() -> float:
	return absf(forward_speed()) * 3.6


func _physics_process(delta: float) -> void:
	_watch_lost(delta)
	_hold_when_parked(delta)
	var fwd := forward_speed()
	var throttle := 0.0
	var steer_in := 0.0
	var handbrake := false
	if driver and not Game.is_ui_open():
		throttle = Input.get_axis("move_back", "move_forward")
		steer_in = Input.get_axis("move_right", "move_left")
		handbrake = Input.is_action_pressed("jump")
	_throttle = throttle
	var max_speed := float(info.get("max_speed", 100.0)) / 3.6
	var max_rev := float(info.get("max_reverse", 20.0)) / 3.6
	var brake_force := float(info.get("brake_force", 40.0))
	var braking := false
	var reversing := false
	var force := 0.0
	var has_fuel := fuel > 0.0
	if throttle > 0.05:
		if fwd < -0.8:
			braking = true
		elif has_fuel and fwd < max_speed:
			force = float(info.get("engine_force", 4000.0)) * throttle * (1.0 - smoothstep(max_speed * 0.7, max_speed, fwd) * 0.8)
	elif throttle < -0.05:
		if fwd > 0.8:
			braking = true
		elif has_fuel and fwd > -max_rev:
			force = -float(info.get("reverse_force", 2000.0)) * -throttle
			reversing = true
	# VehicleBody3D gives every driven wheel the whole engine force: four-wheel drive
	# shares it out instead of doubling it.
	engine_force = force * (0.5 if info.get("drive", "rwd") == "4wd" else 1.0)
	brake = brake_force * absf(throttle) if braking else (0.0 if driver else brake_force * 0.3)
	# Coasting: engine braking and rolling resistance.
	if absf(throttle) < 0.05 and driver:
		brake = 1.5
	for key: String in ["rl", "rr"]:
		(_wheels[key] as VehicleWheel3D).brake = brake_force * 0.9 if handbrake else 0.0
	# Steering gets gentler with speed: less lock (about 13 degrees at 30 km/h, 7 from
	# 58 km/h up) and a slower wheel, so a tap on A/D at speed is a lane change, not a spin.
	var speed_t := clampf(absf(fwd) / 16.0, 0.0, 1.0)
	var steer_max := deg_to_rad(float(info.get("steer_deg", 32.0))) * lerpf(1.0, 0.21, sqrt(speed_t))
	var steer_rate := lerpf(1.9, 0.6, speed_t) if absf(steer_in) > 0.01 else lerpf(3.0, 1.8, speed_t)
	_steer = move_toward(_steer, steer_in * steer_max, delta * steer_rate)
	steering = _steer
	if _steer_pivot:
		# The column's axis points away from the driver: seen from the seat a turn about
		# it runs clockwise, to the right, and `_steer` is positive to the left.
		_steer_pivot.basis = Basis(_steer_axis, -steering_wheel_turn())
	_turn_needles()
	# Air drag.
	var v := linear_velocity
	apply_central_force(-v * v.length() * 0.9)
	_anti_roll()
	# Fuel.
	if driver:
		var dist := absf(fwd) * delta
		odometer += dist
		fuel = maxf(fuel - float(info.get("fuel_per_km", 0.5)) * dist / 1000.0 * (0.35 + 0.65 * absf(throttle)) - IDLE_BURN * delta / 3600.0, 0.0)
		if fuel <= 0.0 and not _out_of_fuel_told:
			_out_of_fuel_told = true
			Game.notify(tr("MSG_OUT_OF_FUEL"), UiTheme.RED)
	_set_light_states(braking or handbrake, reversing)


## Anti-roll bars: on each axle, a force that grows with the difference between the
## left and right spring compression lifts the loaded side and pulls the other down,
## so the body rolls less in bends without a harsher ride on straight bumps.
func _anti_roll() -> void:
	var ratio := float((info.get("suspension", {}) as Dictionary).get("anti_roll", 0.0))
	if ratio <= 0.0:
		return
	var rate := ratio * (_wheels["fl"] as VehicleWheel3D).suspension_stiffness * mass
	for axle: Array in [["fl", "fr"], ["rl", "rr"]]:
		var a: VehicleWheel3D = _wheels[axle[0]]
		var b: VehicleWheel3D = _wheels[axle[1]]
		var force := (_compression(axle[0]) - _compression(axle[1])) * rate
		if a.is_in_contact():
			apply_force(global_basis.y * force, global_basis * (_mounts[axle[0]] as Vector3))
		if b.is_in_contact():
			apply_force(global_basis.y * -force, global_basis * (_mounts[axle[1]] as Vector3))


## How far a wheel's spring is pushed in from full extension (0 in the air).
func _compression(key: String) -> float:
	var w: VehicleWheel3D = _wheels[key]
	if not w.is_in_contact():
		return 0.0
	var length := (to_global(_mounts[key]) - w.get_contact_point()).dot(global_basis.y) - w.wheel_radius
	return clampf(w.wheel_rest_length - length, 0.0, w.wheel_rest_length)


func _process(delta: float) -> void:
	_seat_tyres()
	if not driver:
		return
	if lights_on != (DayNightCycle.night_factor > 0.5) and not _manual_lights:
		set_lights(DayNightCycle.night_factor > 0.5)
	if chase_camera:
		_update_chase(delta)
	else:
		# Mouse look applies at once; the body is interpolated between physics ticks.
		var eye := Transform3D(Basis.from_euler(Vector3(_look.y, _look.x + PI, 0.0)), _eye_rig.position)
		_cam.global_transform = get_global_transform_interpolated() * eye


## Stands every tyre on the ground it rolls on. The engine puts a wheel node where it
## takes the spring to be, short of where it is (spring_seen): pushed in by c as the engine
## sees it, the tyre really is c r / (rest + r) higher under the body (3-5 cm at rest, more
## on a bump), and without this it is drawn that deep in the road. The tyre is lifted by
## that much along the body's up on its spinning wheel node, every frame, right after the
## engine has placed the wheels for it (the body's internal process runs before this one).
func _seat_tyres() -> void:
	for key: String in _tyres:
		var w := _wheels[key] as VehicleWheel3D
		var seen := clampf(w.wheel_rest_length - ((_mounts[key] as Vector3).y - w.position.y), 0.0, w.wheel_rest_length)
		var lift := seen * w.wheel_radius / (w.wheel_rest_length + w.wheel_radius)
		(_tyres[key] as Node3D).position = (_tyre_at[key] as Vector3) + w.basis.inverse() * Vector3(0, lift, 0)


## Where wheel `key`'s tyre is drawn: its centre (world), its radius above the ground.
func tyre_center(key: String) -> Vector3:
	var tyre := _tyres[key] as MeshInstance3D
	return tyre.global_transform * tyre.get_aabb().get_center()


## How far the steering wheel is turned (radians; positive to the left, as `steering`).
func steering_wheel_turn() -> float:
	return _steer * float(info.get("steer_ratio", STEER_RATIO))


## Where the driver looks: x round about (radians from straight ahead, positive to the
## left, -PI..PI), y up.
func look() -> Vector2:
	return _look


## Turns the driver's head by a mouse movement (pixels), in the cab or round the chase
## camera: all the way round, over either shoulder and on (the angle wraps, the view does
## not jump), up and down as far as a neck goes. The body and the steering do not follow.
func turn_look(relative: Vector2) -> void:
	var sens := Settings.mouse_sensitivity
	_look.x = wrapf(_look.x - relative.x * sens, -PI, PI)
	_look.y = clampf(_look.y - relative.y * sens * (-1.0 if Settings.invert_y else 1.0), -LOOK_DOWN, LOOK_UP)


func _snap_chase() -> void:
	_update_chase(1.0)


func _update_chase(delta: float) -> void:
	var xf := get_global_transform_interpolated()
	var yaw := xf.basis.get_euler().y + _look.x
	var back := Vector3(sin(yaw), 0, cos(yaw))
	var target := xf.origin - back * 8.5 + Vector3(0, 3.3, 0)
	var ground := TerrainData.height(target.x, target.z) + 1.2
	target.y = maxf(target.y, ground)
	_chase.global_position = _chase.global_position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	_chase.look_at(xf.origin + Vector3(0, 1.3, 0) + back * 2.0, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if not driver or Game.is_ui_open():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		turn_look((event as InputEventMouseMotion).relative)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		(driver as Player).exit_vehicle()
	elif event.is_action_pressed("vehicle_camera"):
		chase_camera = not chase_camera
		_snap_chase()
		_current_camera().make_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("vehicle_lights"):
		_manual_lights = true
		set_lights(not lights_on)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Game.capture_mouse()


func set_lights(on: bool) -> void:
	lights_on = on
	var energy := float(info.get("lamp_energy", 1.0))
	for b in _beams:
		b.light_energy = 4.2 * energy if on else 0.0
		b.visible = on
	for f in _fills:
		f.light_energy = 0.55 * energy if on else 0.0
		f.visible = on
	if _dash_light:
		_dash_light.light_energy = 0.09 if on else 0.0
		_dash_light.visible = on
	for m: StandardMaterial3D in _lamps["head"]:
		m.emission_energy_multiplier = 4.0 * LAMP_GLOW * energy if on else 0.0
	_set_light_states(false, false)


func _set_light_states(braking: bool, reversing: bool) -> void:
	var tail := BRAKE_GLOW if braking else (TAIL_GLOW if lights_on else 0.0)
	for m: StandardMaterial3D in _lamps["brake"]:
		m.emission_energy_multiplier = tail
	var glow := Vector2(tail, 1.2 if lights_on else 0.0)
	if glow != _trim_glow:
		# The tail lamps on the bed's corners (trim atlas) and the amber side markers.
		_trim_glow = glow
		for key: String in _mats:
			if key.begins_with("trim:"):
				(_mats[key] as ShaderMaterial).set_shader_parameter("tail_glow", glow.x)
				(_mats[key] as ShaderMaterial).set_shader_parameter("marker_glow", glow.y)
	for m: StandardMaterial3D in _lamps["reverse"]:
		m.emission_energy_multiplier = (4.0 if reversing else 0.0) * LAMP_GLOW
	_tail_light.light_energy = 0.6 if braking else (0.12 if lights_on else 0.0)


## Where the driver steps out (left side), on the ground; the right side if blocked.
func exit_point() -> Vector3:
	var eyes: Vector3 = info.get("eyes", Vector3(0.4, 1.5, -0.38))
	for side: float in [1.0, -1.0]:
		var p := to_global(Vector3(side * (half_width() + 0.78), 0.0, eyes.x - _mid_x))
		p.y = maxf(TerrainData.height(p.x, p.z), global_position.y - 0.5) + 0.15
		var q := PhysicsShapeQueryParameters3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = 1.7
		q.shape = cap
		q.transform = Transform3D(Basis(), p + Vector3(0, 1.0, 0))
		q.collision_mask = 1
		q.exclude = [get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
			return p
	return global_position + Vector3(0, 2.2, 0)


## Half the body's width (its collision boxes).
func half_width() -> float:
	var w := 0.9
	for box: Array in info.get("boxes", []):
		w = maxf(w, (box[1] as Vector3).z * 0.5)
	return w


## The body's length (its collision boxes).
func body_length() -> float:
	var lo := INF
	var hi := -INF
	for box: Array in info.get("boxes", []):
		var c: Vector3 = box[0]
		var sz: Vector3 = box[1]
		lo = minf(lo, c.x - sz.x * 0.5)
		hi = maxf(hi, c.x + sz.x * 0.5)
	return hi - lo if hi > lo else 5.3


func driver_eye_global() -> Vector3:
	return _eye_rig.global_position


## The driver's eyes, body frame.
func driver_eye_local() -> Vector3:
	return _eye_rig.position


## Whether there is a seat beside the driver's (not on the tractor: he sits in the middle).
func has_passenger_seat() -> bool:
	var eyes: Vector3 = info.get("eyes", Vector3(0.4, 1.5, -0.38))
	return info.has("seat") or absf(eyes.z) > 0.2


## The passenger seat, body frame: "at" the cushion's top at the foot of the seat's back
## in the seat's middle, "depth" from there to the cushion's front edge and "width" (m),
## "pitch" its rake (rad, the front higher), "door" and "inner" how far from the seat's
## middle the door is and the cushion (a bench, a row of seats) goes on toward the driver,
## "ahead" how far before the foot of the seat's back the dashboard or the windscreen is
## at a sitter's head (m). The entry's "seat", as SeatProbe measured it
## off the cab's meshes (the scenario seat23 measures it again and holds the entry to it);
## an entry without one is measured now, once a kind (a hitch of a fifth of a second: the
## meshes are read back from the renderer). Empty when there is no such seat.
func seat() -> Dictionary:
	var rec: Dictionary = info.get("seat", {})
	if rec.is_empty():
		if not has_passenger_seat():
			return {}
		if not _seats_measured.has(kind):
			_seats_measured[kind] = SeatProbe.measure(self)
		rec = _seats_measured[kind]
		if rec.is_empty():
			return {}
	return {"at": _mb(rec["at"]), "depth": float(rec["depth"]), "width": float(rec["width"]), "pitch": float(rec["pitch"]),
		"door": float(rec.get("door", SeatProbe.DOOR_OPEN)), "inner": float(rec.get("inner", float(rec["width"]) * 0.5)),
		"ahead": float(rec.get("ahead", SeatProbe.AHEAD_OPEN))}


## The middle of the passenger seat's cushion (its top), body frame, turned so that what
## sits on it facing -Z in its own frame faces the way the vehicle does and stands square
## on the cushion's rake (seat). With no seat found: across the cab from the driver's
## eyes, PASSENGER_DROP below them and PASSENGER_AHEAD in front.
func passenger_seat() -> Transform3D:
	var s := seat()
	if s.is_empty():
		var eyes: Vector3 = info.get("eyes", Vector3(0.4, 1.5, -0.38))
		return Transform3D(Basis(Vector3.UP, PI), _mb(Vector3(eyes.x + PASSENGER_AHEAD, eyes.y - PASSENGER_DROP, -eyes.z)))
	var pitch: float = s["pitch"]
	var ahead := Vector3(0.0, sin(pitch), cos(pitch))
	var up := Vector3(0.0, cos(pitch), -sin(pitch))
	return Transform3D(Basis(up.cross(-ahead), up, -ahead), (s["at"] as Vector3) + ahead * float(s["depth"]) * 0.5)


# --- Interaction ----------------------------------------------------------------------

func interact_prompt(_player: Node) -> String:
	if not owned:
		return tr("ACTION_BUY_VEHICLE") % UiTheme.money(price)
	if is_locked():
		return tr("ACTION_UNLOCK_VEHICLE") if PlayerState.inventory.has_item(key_item()) else tr("HINT_KEY_NEEDED")
	return tr("ACTION_DRIVE")


func info_prompt() -> String:
	return tr("ACTION_OPEN_BED") if owned else ""


func interact(player: Node) -> void:
	if not owned:
		Game.hud.open_dealer(self)
		return
	if is_locked():
		var key := key_item()
		if not PlayerState.inventory.has_item(key):
			# The handle rattles: locked, and the key is still in the house.
			Audio.play("metal", global_position + Vector3(0, 1.0, 0), -12.0, 0.1, &"Effects", 4.0)
			Game.notify(tr("MSG_VEHICLE_LOCKED"), UiTheme.RED)
			return
		# The key goes into the ignition and stays there.
		PlayerState.inventory.remove_item(key, 1)
		unlock()
		Game.notify(tr("MSG_VEHICLE_UNLOCKED") % display_name(), UiTheme.GREEN)
	(player as Player).enter_vehicle(self)


# --- Key ------------------------------------------------------------------------------

## The key item this vehicle needs (&"" when it has no lock).
func key_item() -> StringName:
	return KEYS.get(kind, &"")


## The FarmState.flags entry that says this vehicle's key is in its ignition.
func unlock_flag() -> String:
	return UNLOCK_FLAG % kind


## Owned, with a lock, and its key not found yet: E only gets in with the key in the bag
## (Player.enter_vehicle itself is not locked: tests and debug shots seat the player).
## The bed can be used either way.
func is_locked() -> bool:
	return owned and key_item() != &"" and not bool(FarmState.flags.get(unlock_flag(), false))


## Unlocks it for good (the key is in the ignition).
func unlock() -> void:
	if key_item() == &"" or not is_locked():
		return
	FarmState.flags[unlock_flag()] = true
	changed.emit()


## A loaded game that did not know this vehicle (saved before it came with the farm)
## never had the lock either: it stays open, so no old farm is left without its truck.
func _on_game_loaded(_slot: String) -> void:
	if not restored and is_locked():
		unlock()


## F: the bed next to the bag (and the warehouse when parked by it).
func info_interact(_player: Node) -> void:
	if owned:
		Game.hud.open_storage(self)


# --- Load ---------------------------------------------------------------------------------

## Goods that can ride in the bed (not tools, cans or keys; crated animals can).
static func is_cargo(s: ItemStack) -> bool:
	return s != null and s.count > 0 and not s.item.is_tool() and not s.item.has_durability() and s.item.water_capacity <= 0 \
			and s.item.category != "key"


## Puts the goods in the player's hand into the bed; returns how many went in.
func load_selected() -> int:
	var s := PlayerState.selected_stack()
	if not is_cargo(s):
		return 0
	var item_name := s.item.display_name()
	var n := cargo.store_stack(PlayerState.inventory, PlayerState.selected)
	if n > 0:
		Game.notify(tr("MSG_LOADED_BED") % [item_name, n], UiTheme.GREEN)
	else:
		Game.notify(tr("MSG_BED_FULL"), UiTheme.RED)
	return n


## The first crated animal in the bed (&"" when none).
func live_cargo() -> StringName:
	for e: Dictionary in cargo.entries():
		if CargoModels.is_live(e["id"]):
			return e["id"]
	return &""


## E at the tailgate: the next crate comes out of the bed into the farmer's hands
## (onto the crates already in hand, into a free hotbar slot, or in place of what is in
## hand: see LiveCrates.put_in_hand). False when there is none or no room.
func take_live() -> bool:
	var id := live_cargo()
	if id == &"":
		return false
	var q := 0
	for e: Dictionary in cargo.entries():
		if e["id"] == id:
			q = int(e["quality"])
			break
	if LiveCrates.put_in_hand(id, 1, q, self) <= 0:
		Game.notify(LiveCrates.hands_full_message(), UiTheme.RED)
		return false
	cargo.take(id, 1, q)
	Audio.animal_voice(AnimalTable.species_of_crate(id), true, global_position, -8.0)
	return true


func cargo_kg() -> float:
	var kg := 0.0
	for k: String in cargo.items:
		kg += CargoModels.unit_kg(StringName(k.get_slice("|", 0))) * int(cargo.items[k])
	return kg


func load_view() -> CargoBed:
	return _bed


## The load's weight sits over the bed: heavier, and the balance shifts back and up.
func _on_cargo_changed() -> void:
	var load_kg := cargo_kg()
	mass = _base_mass + load_kg
	var bed_center: Vector3 = info.get("bed_center", Vector3(-1.1, 0.9, 0.0))
	center_of_mass = (_base_com * _base_mass + _mb(bed_center) * load_kg) / mass
	sleeping = false
	_check_live_aboard()


## Announces crated animals coming aboard (bought into the bed, loaded by hand or
## from the warehouse), not a saved load being put back.
func _check_live_aboard() -> void:
	var now := {}
	for e: Dictionary in cargo.entries():
		if CargoModels.is_live(e["id"]):
			now[e["id"]] = int(now.get(e["id"], 0)) + int(e["count"])
	var quiet := SaveGame.loading or not is_inside_tree() or not owned
	for id: StringName in now:
		if int(now[id]) > int(_live_aboard.get(id, 0)) and not quiet:
			Events.crate_stored.emit(id, &"bed")
	_live_aboard = now


# --- Walkers round it ------------------------------------------------------------------------

## Where a walker `radius` m round (an animal, a dog, a wolf, a townsman: bodies moved by
## hand, kinematic, that would shove a car they walked into with no limit, along and
## down into the ground) stepping from `from` to `to` may go: `to` when clear of every
## vehicle's body; else along the side it came to (the part of the step into the vehicle
## taken off), or kept at `from`. One already against a vehicle may only step out or along.
static func keep_out(from: Vector3, to: Vector3, radius: float) -> Vector3:
	for v: Vehicle in all:
		if v._footprint.has_area() and v.is_inside_tree():
			to = v._keep_clear(from, to, radius)
	return to


func _keep_clear(from: Vector3, to: Vector3, radius: float) -> Vector3:
	var reach := _reach + radius
	if Vector2(to.x - global_position.x, to.z - global_position.z).length_squared() > reach * reach:
		return to
	var inv := global_transform.affine_inverse()
	var b3 := inv * to
	if b3.y > _box_y.y + 0.3 or b3.y < _box_y.x - 2.5:
		# Well above its roof, or far below it.
		return to
	var r := _footprint.grow(radius)
	var b := Vector2(b3.x, b3.z)
	if not r.has_point(b):
		return to
	var a3 := inv * from
	var a := Vector2(a3.x, a3.z)
	if r.has_point(a):
		return to if _depth(r, b) <= _depth(r, a) + 0.001 else from
	# Up to the side it came from (across a corner: the side it is least far into).
	var lo := r.position
	var hi := r.end
	var out_x := a.x < lo.x or a.x > hi.x
	var out_z := a.y < lo.y or a.y > hi.y
	var dx := minf(b.x - lo.x, hi.x - b.x)
	var dz := minf(b.y - lo.y, hi.y - b.y)
	if out_x and (not out_z or dx <= dz):
		b.x = lo.x if a.x < lo.x else hi.x
	else:
		b.y = lo.y if a.y < lo.y else hi.y
	return _flat_world(b, to.y)


## The way round vehicles for a walker `radius` m round going from `from` to `to`: `to`
## when no vehicle's body stands in between; else the corner (`margin` m further out) of
## the nearest one in the way to make for first, the shorter way round. A `to` in a
## vehicle's body becomes the nearest point beside it.
static func way_round(from: Vector3, to: Vector3, radius: float, margin: float) -> Vector3:
	var best := to
	var best_d := INF
	for v: Vehicle in all:
		if not v._footprint.has_area() or not v.is_inside_tree():
			continue
		var w := v._way_round(from, to, radius, margin)
		if w != to:
			var d := v.global_position.distance_squared_to(from)
			if d < best_d:
				best_d = d
				best = w
	return best


func _way_round(from: Vector3, to: Vector3, radius: float, margin: float) -> Vector3:
	var o := Vector2(global_position.x, global_position.z)
	var near := Geometry2D.get_closest_point_to_segment(o, Vector2(from.x, from.z), Vector2(to.x, to.z))
	if near.distance_to(o) > _reach + radius + margin:
		return to
	var inv := global_transform.affine_inverse()
	var a3 := inv * from
	if a3.y > _box_y.y + 0.3 or a3.y < _box_y.x - 2.5:
		return to
	var b3 := inv * to
	var hard := _footprint.grow(radius + 0.05)
	var a := Vector2(a3.x, a3.z)
	var b := Vector2(b3.x, b3.z)
	if hard.has_point(a):
		# Right against it already: keep_out lets it step out or along.
		return to
	var moved := false
	if hard.has_point(b):
		b = _out_of(hard.grow(0.05), b)
		moved = true
	if not _crosses(hard, a, b):
		return _flat_world(b, to.y) if moved else to
	# The shortest way by its corners (round one end, or along a side and round two).
	var soft := _footprint.grow(radius + margin)
	var pts: Array[Vector2] = [a, soft.position, Vector2(soft.end.x, soft.position.y), soft.end,
		Vector2(soft.position.x, soft.end.y), b]
	var dist: Array[float] = [0.0, INF, INF, INF, INF, INF]
	var prev: Array[int] = [-1, -1, -1, -1, -1, -1]
	var done: Array[bool] = [false, false, false, false, false, false]
	for _i in pts.size():
		var u := -1
		for k in pts.size():
			if not done[k] and (u < 0 or dist[k] < dist[u]):
				u = k
		if u < 0 or dist[u] == INF or u == 5:
			break
		done[u] = true
		for k in pts.size():
			if done[k] or _crosses(hard, pts[u], pts[k]):
				continue
			var alt := dist[u] + pts[u].distance_to(pts[k])
			if alt < dist[k]:
				dist[k] = alt
				prev[k] = u
	if dist[5] == INF:
		return to
	var step := 5
	while prev[step] > 0:
		step = prev[step]
	return _flat_world(pts[step], to.y)


## A point of the body frame's ground plane (x, z) in the world, at height `y`.
func _flat_world(p: Vector2, y: float) -> Vector3:
	var g := global_transform * Vector3(p.x, 0.0, p.y)
	return Vector3(g.x, y, g.z)


## How far `p` is inside `r` (to its nearest side).
static func _depth(r: Rect2, p: Vector2) -> float:
	return minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y))


## `p` (inside `r`) moved out to the nearest side of `r`.
static func _out_of(r: Rect2, p: Vector2) -> Vector2:
	var d := [p.x - r.position.x, r.end.x - p.x, p.y - r.position.y, r.end.y - p.y]
	var k := 0
	for i in 4:
		if d[i] < d[k]:
			k = i
	match k:
		0:
			p.x = r.position.x
		1:
			p.x = r.end.x
		2:
			p.y = r.position.y
		_:
			p.y = r.end.y
	return p


## Whether the segment `p`-`q` passes through the inside of `r` (along a side or touching
## a corner is not through).
static func _crosses(r: Rect2, p: Vector2, q: Vector2) -> bool:
	var t0 := 0.0
	var t1 := 1.0
	var d := q - p
	for axis in 2:
		var lo := r.position[axis]
		var hi := r.end[axis]
		if absf(d[axis]) < 1e-6:
			if p[axis] <= lo or p[axis] >= hi:
				return false
			continue
		var ta := (lo - p[axis]) / d[axis]
		var tb := (hi - p[axis]) / d[axis]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
		if t0 >= t1:
			return false
	return true


# --- Save -----------------------------------------------------------------------------------

func save_data() -> Dictionary:
	return {"kind": String(kind), "owned": owned, "xform": global_transform, "safe": _safe, "fuel": fuel,
		"odometer": odometer, "chase": chase_camera, "cargo": cargo.to_dict(), "unlocked": not is_locked()}


func load_data(d: Dictionary) -> void:
	owned = bool(d.get("owned", owned))
	# Saves from before the lock have no "unlocked": that truck was always open.
	if key_item() != &"" and bool(d.get("unlocked", true)):
		FarmState.flags[unlock_flag()] = true
	fuel = float(d.get("fuel", fuel))
	odometer = float(d.get("odometer", 0.0))
	chase_camera = bool(d.get("chase", false))
	restored = true
	visible = true
	if d.get("xform") is Transform3D:
		var xf: Transform3D = d["xform"]
		var kept: Variant = d.get("safe")
		# Saved out of the world (dropped through the ground, thrown off the land: it was
		# never fetched back before _watch_lost): back where it last stood as it should when
		# the save knows that, else at its home by the house, and the farmer is told.
		var back := lost_at(xf)
		var slack := 0.1
		if back:
			if kept is Transform3D and not lost_at(kept) and _upness(kept) >= SAFE_UP:
				# It stood there before: it fits, whatever it was parked against.
				xf = kept
				slack = -0.05
			else:
				xf = home_place()
		teleport(xf)
		_leave_warehouse()
		_make_room()
		if back and not is_clear_at(global_transform, slack):
			teleport(clear_spot_near(global_transform))
		# Saved sunk in the ground (shoved in by a wolf before that was stopped): out of it.
		_unsink()
		# Saved lying on its side or roof: on its wheels.
		if not _wheels.is_empty() and _upness(global_transform) < LOST_TIPPED:
			var stood := _upright(global_transform)
			teleport(stood if is_clear_at(stood, 0.0) else clear_spot_near(stood))
			back = true
		_safe = global_transform
		if back:
			# Let go to settle on its wheels there (held again once it has).
			if freeze and freeze_mode == RigidBody3D.FREEZE_MODE_STATIC:
				freeze = false
			_settle_t = 0.0
			_lifts = 0
			rescues += 1
			if owned:
				get_tree().create_timer(1.5).timeout.connect(_tell_back)
			# Once every vehicle stands where its save left it.
			_yield_place.call_deferred()
		elif kept is Transform3D and not lost_at(kept) and _upness(kept) >= SAFE_UP:
			_safe = kept
	cargo.from_dict(d.get("cargo", {}))
	cargo.capacity = int(info.get("cargo_units", cargo.capacity))
	_bed.settle()
	changed.emit()


## Sent somewhere by a load because its saved place was out of the world (load_data): a
## vehicle restored after it may have been saved on that very spot (his trailer parked on
## the pickup's place by the house; the two were held standing in each other). This one
## moves over to the nearest clear spot; the other stays where the farmer left it.
func _yield_place() -> void:
	if not is_inside_tree():
		return
	for v: Vehicle in all:
		if v == self or not v.is_inside_tree() or Trailer.towed_by(self) == v or Trailer.towed_by(v) == self:
			continue
		if stands_in(v, 0.0):
			teleport(clear_spot_near(global_transform))
			_safe = global_transform
			return


## A vehicle the save doesn't know yet (Grandpa's pickup in a game saved before it
## came with the farm) stays at its spawn; if this one was parked on top of it, it
## moves to the nearest clear spot. A vehicle the save knows is restored afterwards
## anyway, so moving it early does no harm. Not the dealer's trailers: they stay in their
## bays (TrailerYard; moved, they would stand in the street), and this one leaves if it
## stands in one (_leave_bay, once every vehicle is restored: one of them may be the
## farmer's, saved somewhere else).
func _make_room() -> void:
	for v: Vehicle in get_tree().get_nodes_in_group(GROUP):
		if v == self or v.global_position.distance_to(global_position) >= 6.0:
			continue
		if v is Trailer and not v.owned:
			_leave_bay.call_deferred(v)
		elif not v.restored:
			v.teleport(v.clear_spot_near(v.global_transform))


## A vehicle a save left standing in the dealer's trailer `t` (the yard was the market's
## before it was his trailer bay) is put at the kerb in front of the bays, or on the
## nearest clear spot to that; backed up to its tongue it stays.
func _leave_bay(t: Trailer) -> void:
	if not is_instance_valid(t) or t.owned or not is_inside_tree() or not stands_in(t):
		return
	var spot := TrailerYard.kerb_place()
	teleport(spot if is_clear_at(spot) else clear_spot_near(spot))


## Whether this vehicle's body stands in `other`'s on the ground, `slack` m or more into
## it (bumpers touching is not in it).
func stands_in(other: Vehicle, slack := 0.15) -> bool:
	for a in _ground_boxes(-slack):
		for b in other._ground_boxes(0.0):
			if not Geometry2D.intersect_polygons(a, b).is_empty():
				return true
	return false


## The outlines of its body's boxes on the ground (world x, z), each grown by `by` m.
func _ground_boxes(by: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for box: Array in info.get("boxes", []):
		var c := _mb(box[0])
		var size: Vector3 = box[1]
		var half := Vector2(maxf(size.z * 0.5 + by, 0.01), maxf(size.x * 0.5 + by, 0.01))
		var outline := PackedVector2Array()
		for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var p := global_transform * Vector3(c.x + k.x * half.x, 0.0, c.z + k.y * half.y)
			outline.append(Vector2(p.x, p.z))
		out.append(outline)
	return out


## The first spot 7-13 m around `xf` where this vehicle fits without touching a
## building, tree or another vehicle (`xf` itself when none is found): one it can be
## driven off from again, with nobody standing there, when there is any (good_ground; the
## first fit used to be taken, which near the pond is in the water, behind its shore
## ring), else wherever it fits.
func clear_spot_near(xf: Transform3D) -> Transform3D:
	for fussy: bool in [true, false]:
		for dist: float in [7.0, 10.0, 13.0]:
			for k in 8:
				# South (+Z) first: on the farm that is the open yard.
				var a := k * TAU / 8.0
				var p := xf.origin + Vector3(sin(a), 0.0, cos(a)) * dist
				p.y = TerrainData.height(p.x, p.z) + 0.25
				if fussy and not good_ground(p):
					continue
				if is_clear_at(Transform3D(xf.basis, p), 0.1, (1 | 2 | 16) if fussy else 1):
					return Transform3D(xf.basis, p)
	return xf


## Whether a vehicle can be left at `o` and driven off again: dry ground (in the pond the
## shore ring would shut it in), inside the land, not on a steep bank.
static func good_ground(o: Vector3) -> bool:
	return not TerrainData.is_underwater(o.x, o.z, 0.1) and WorldLayout.playable_distance(o.x, o.z) >= 2.0 \
			and TerrainData.normal_at(o.x, o.z).y >= 0.94


## Whether this vehicle fits at `xf` without touching a building, tree or another vehicle
## (the trailer it tows goes where it goes): with `slack` m to spare on every side (0.1 by
## default; below 0, its own body a hair smaller: where it stood before, against a wall).
## `mask` 1 | 2 | 16: nor the farmer, an animal or anybody else standing there.
func is_clear_at(xf: Transform3D, slack := 0.1, mask := 1) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	# Body frame: width across X, length along Z; kept clear of the ground.
	box.size = Vector3(half_width() * 2.0 + slack * 2.0, 1.3 + minf(slack, 0.0) * 2.0, body_length() + slack * 3.0)
	q.shape = box
	q.collision_mask = mask
	var skip: Array[RID] = [get_rid()]
	var towed := Trailer.towed_by(self)
	if towed != null:
		skip.append(towed.get_rid())
	q.exclude = skip
	q.transform = Transform3D(xf.basis, xf.origin + xf.basis.y * 1.1)
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## No vehicle goes into the warehouse (Warehouse's barrier in its doorway): one a save
## left in there, or with its nose through the door, from when it could be driven in, is
## put out on the apron in front of the big door, or on the nearest clear spot to that.
## Whether it was moved.
func _leave_warehouse() -> bool:
	if not is_inside_tree() or not Warehouse.holds_vehicle(global_transform, _footprint):
		return false
	var spot := Warehouse.apron_spot(-_footprint.position.y)
	teleport(spot if is_clear_at(spot) else clear_spot_near(spot))
	return true


func display_name() -> String:
	return tr(info.get("name_key", "VEHICLE"))


func fuel_ratio() -> float:
	return fuel / maxf(float(info.get("fuel_capacity", 40.0)), 0.001)
