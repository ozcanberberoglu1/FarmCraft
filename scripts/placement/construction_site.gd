class_name ConstructionSite
extends Node3D
## A building going up (a kit-built coop): stakes and string lines round the plot, then
## the floor on its posts, the stud frame and the rafters as the work gets on (three
## stages, each arriving in a puff of sawdust), steel scaffolding along the front, a
## timber stack and a sawhorse, hammering while the farmer is near, and a sign over it
## counting down. Built in the parent's frame: `house` is the building's rect (door
## toward +Z, the AnimalBuildings.coop proportions) and `yard` the whole plot. A solid
## body keeps the farmer out of the frame and lets the interaction ray find the owner.

const STAGES := 3
## Hammering is heard from this close (metres).
const HEAR_RANGE := 36.0
## The coop's measures (AnimalBuildings.coop).
const FLOOR_Y := 0.3
const FRONT_H := 2.5
const BACK_H := 1.95
const DOOR_W := 1.0
const DOOR_H := 2.05
const WALL := 0.12
const TIMBER := Color(0.66, 0.54, 0.42)
const TIMBER_DARK := Color(0.5, 0.42, 0.34)
const TUBE := Color(0.6, 0.62, 0.63)

var house := Rect2()
var yard := Rect2()

var _stage := -1
var _mi: MeshInstance3D
var _label: Label3D
var _left := 0.0
var _label_timer := 0.0
var _knock := 1.0

## Built once per stage and size (every coop is the same).
static var _meshes := {}


## "2:14" for a count of seconds (rounded up).
static func clock_text(seconds: float) -> String:
	var s := ceili(maxf(seconds, 0.0))
	return "%d:%02d" % [floori(s / 60.0), s % 60]


func _ready() -> void:
	# Level with the ground under the house (the owner stands on the plot's middle).
	var c := house.get_center()
	var w := get_parent_node_3d().global_transform * Vector3(c.x, 0.0, c.y)
	position = Vector3(c.x, TerrainData.height(w.x, w.z) - get_parent_node_3d().global_position.y, c.y)
	_mi = MeshInstance3D.new()
	_mi.name = "Frame"
	add_child(_mi)
	_add_body()
	_label = Label3D.new()
	_label.name = "Countdown"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = UiTheme.font(800)
	_label.font_size = 72
	_label.pixel_size = 0.0042
	_label.outline_size = 16
	_label.outline_modulate = Color(0.08, 0.06, 0.04, 0.85)
	_label.modulate = Color(1.0, 0.84, 0.42)
	_label.line_spacing = -8.0
	_label.position = Vector3(0, FLOOR_Y + FRONT_H + 1.4, 0)
	_label.visibility_range_end = 70.0
	_label.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_label.layers = 2
	add_child(_label)
	_knock = randf_range(0.5, 1.5)


## Called by the owner as the work gets on: `ratio` 0..1 done, `seconds_left` real time.
func set_progress(ratio: float, seconds_left: float) -> void:
	_left = seconds_left
	var stage := clampi(int(ratio * STAGES), 0, STAGES - 1)
	if stage != _stage:
		var first := _stage < 0
		_stage = stage
		_mi.mesh = _stage_mesh(house.size, yard, house.get_center(), stage)
		if not first and is_inside_tree():
			# The next part of the frame goes up.
			Fx.dust_cloud(global_position + Vector3(0, 1.2, 0), house.size * 0.55)
			Audio.play("plank", global_position + Vector3(0, 1.0, 0), -2.0)
	if _label_timer <= 0.0:
		_update_label()


func _update_label() -> void:
	_label_timer = 0.5
	_label.text = "%s\n%s" % [UiTheme.caps(tr("SIGN_CONSTRUCTION")), tr("CROP_TIME_LEFT") % clock_text(_left)]


func _process(delta: float) -> void:
	_label_timer -= delta
	if _label_timer <= 0.0:
		_update_label()
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_squared_to(global_position) > HEAR_RANGE * HEAR_RANGE:
		return
	# Work sounds: hammer blows and boards set down, somewhere on the frame.
	_knock -= delta
	if _knock > 0.0 or Game.is_ui_open():
		return
	_knock = randf_range(0.6, 2.2)
	var at := global_transform * Vector3(randf_range(-house.size.x, house.size.x) * 0.5, randf_range(0.4, FRONT_H), randf_range(-house.size.y, house.size.y) * 0.5)
	if randf() < 0.75:
		Audio.play("wood_hit", at, randf_range(-12.0, -8.0), 0.12)
	else:
		Audio.play("plank", at, -10.0)


## Solid where the work is: the frame, the scaffolding and the timber stack.
func _add_body() -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1 | 4
	body.collision_mask = 0
	var w := house.size.x
	var d := house.size.y
	for b: Array in [[Vector3(0, 1.3, 0), Vector3(w + 0.2, 2.6, d + 0.2)],
			[Vector3(0, 1.3, d * 0.5 + 0.9), Vector3(w + 0.9, 2.6, 1.1)],
			[Vector3(w * 0.5 + 1.3, 0.3, 0.3), Vector3(0.9, 0.6, 3.1)]]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[1]
		cs.shape = box
		cs.position = b[0]
		body.add_child(cs)
	add_child(body)


# --- Meshes --------------------------------------------------------------------------------

## The site at `stage` (0 floor, 1 walls framed, 2 rafters and boards), centred on the
## house; `yard` and `hc` (the house's centre in the yard's frame) place the stakes.
static func _stage_mesh(size: Vector2, plot: Rect2, hc: Vector2, stage: int) -> ArrayMesh:
	var key := "%s|%s|%d" % [size, plot, stage]
	if _meshes.has(key):
		return _meshes[key]
	var mb := MeshBuilder.new()
	var w := size.x
	var d := size.y
	_stakes(mb, Rect2(plot.position - hc, plot.size))
	_floor(mb, w, d, stage > 0)
	_lumber(mb, w, d, stage)
	if stage >= 1:
		_studs(mb, w, d)
		_scaffold(mb, w, d)
	if stage >= 2:
		_roof_frame(mb, w, d)
	var m := mb.build()
	_meshes[key] = m
	return m


## Pegs at the plot's corners and sides with a builder's line between them.
static func _stakes(mb: MeshBuilder, r: Rect2) -> void:
	var pts: Array[Vector2] = [r.position, Vector2(r.get_center().x, r.position.y), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, r.get_center().y), r.end, Vector2(r.get_center().x, r.end.y), Vector2(r.position.x, r.end.y),
		Vector2(r.position.x, r.get_center().y)]
	for i in pts.size():
		var p := pts[i]
		# Driven well in: the plot may fall away a little from the house.
		mb.box_at(&"wood", Vector3(p.x, -0.05, p.y), Vector3(0.05, 1.12, 0.05), TIMBER_DARK, Vector3(0, i * 23.0, 0))
		# A strip of faded orange tape on each peg.
		mb.box_at(&"paint", Vector3(p.x, 0.44, p.y), Vector3(0.056, 0.05, 0.056), Color(0.86, 0.42, 0.14))
		var q := pts[(i + 1) % pts.size()]
		mb.cylinder_between(&"cloth", Vector3(p.x, 0.46, p.y), Vector3(q.x, 0.46, q.y), 0.004, 0.004, 3, Color(0.86, 0.84, 0.74), false, false)


## Posts, sill beams and joists; the plank floor half laid (all of it once `full`).
static func _floor(mb: MeshBuilder, w: float, d: float, full: bool) -> void:
	for sx: float in [-1.0, 0.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.box_at(&"wood", Vector3(sx * (w * 0.5 - 0.1), (FLOOR_Y - 0.3) * 0.5 - 0.05, sz * (d * 0.5 - 0.1)),
					Vector3(0.14, FLOOR_Y + 0.3, 0.14), TIMBER_DARK, Vector3.ZERO, true)
	for sz: float in [-1.0, 1.0]:
		mb.box_at(&"wood", Vector3(0, FLOOR_Y - 0.17, sz * (d * 0.5 - 0.1)), Vector3(w, 0.14, 0.12), TIMBER)
	for i in 6:
		var x := -w * 0.5 + 0.1 + i * (w - 0.2) / 5.0
		mb.box_at(&"wood", Vector3(x, FLOOR_Y - 0.09, 0), Vector3(0.07, 0.14, d - 0.1), TIMBER.darkened(0.05))
	var boards := 16 if full else 9
	var bd := d / 16.0
	for i in boards:
		var z := -d * 0.5 + bd * (i + 0.5)
		var shade := TIMBER.lightened(0.04 * float((i * 7) % 3) - 0.03)
		mb.box_at(&"floor", Vector3(0, FLOOR_Y - 0.01, z), Vector3(w - 0.02, 0.03, bd - 0.008), shade)


## Wall studs every 0.6 m (a gap for the door), sill and top plates, the door header.
static func _studs(mb: MeshBuilder, w: float, d: float) -> void:
	var y0 := FLOOR_Y + 0.02
	# Back wall.
	var n := int(w / 0.6)
	for i in n + 1:
		var x := -w * 0.5 + WALL * 0.5 + i * (w - WALL) / n
		mb.box_at(&"wood", Vector3(x, y0 + BACK_H * 0.5, -d * 0.5 + WALL * 0.5), Vector3(0.06, BACK_H, 0.1), TIMBER)
	mb.box_at(&"wood", Vector3(0, y0 + BACK_H - 0.03, -d * 0.5 + WALL * 0.5), Vector3(w, 0.06, 0.12), TIMBER_DARK)
	# Side walls: rising toward the front.
	var ns := int(d / 0.6)
	for sx: float in [-1.0, 1.0]:
		var x := sx * (w * 0.5 - WALL * 0.5)
		for i in ns + 1:
			var z := -d * 0.5 + WALL * 0.5 + i * (d - WALL) / ns
			var h := lerpf(BACK_H, FRONT_H, (z + d * 0.5) / d)
			mb.box_at(&"wood", Vector3(x, y0 + h * 0.5, z), Vector3(0.1, h, 0.06), TIMBER)
		var a := Vector3(x, y0 + BACK_H, -d * 0.5)
		var b := Vector3(x, y0 + FRONT_H, d * 0.5)
		mb.box(&"wood", Transform3D(Basis(Vector3.RIGHT, -atan2(FRONT_H - BACK_H, d)), (a + b) * 0.5), Vector3(0.12, 0.06, Vector2(d, FRONT_H - BACK_H).length()), TIMBER_DARK)
	# Front wall with the doorway.
	for i in n + 1:
		var x := -w * 0.5 + WALL * 0.5 + i * (w - WALL) / n
		if absf(x) < DOOR_W * 0.5 + 0.02:
			continue
		mb.box_at(&"wood", Vector3(x, y0 + FRONT_H * 0.5, d * 0.5 - WALL * 0.5), Vector3(0.06, FRONT_H, 0.1), TIMBER)
	for sx: float in [-1.0, 1.0]:
		mb.box_at(&"wood", Vector3(sx * (DOOR_W * 0.5 + 0.04), y0 + FRONT_H * 0.5, d * 0.5 - WALL * 0.5), Vector3(0.08, FRONT_H, 0.1), TIMBER_DARK)
	mb.box_at(&"wood", Vector3(0, y0 + DOOR_H + 0.05, d * 0.5 - WALL * 0.5), Vector3(DOOR_W + 0.16, 0.1, 0.1), TIMBER_DARK)
	mb.box_at(&"wood", Vector3(0, y0 + FRONT_H - 0.03, d * 0.5 - WALL * 0.5), Vector3(w, 0.06, 0.12), TIMBER_DARK)
	# The first boards on the back wall.
	for i in 7:
		var x := -w * 0.5 + 0.2 + i * 0.26
		mb.box_at(&"planks", Vector3(x, y0 + BACK_H * 0.5, -d * 0.5 - 0.01), Vector3(0.24, BACK_H, 0.03), AnimalBuildings.PLANK.lightened(0.08), Vector3.ZERO, true)


## Rafters on the slope with the overhang, more wall boards, half the roof sheeted and
## the ramp.
static func _roof_frame(mb: MeshBuilder, w: float, d: float) -> void:
	var y0 := FLOOR_Y + 0.02
	var ang := atan2(FRONT_H - BACK_H, d)
	var run := Vector2(d + 0.7, (FRONT_H - BACK_H) * (d + 0.7) / d).length()
	var n := int(w / 0.6)
	for i in n + 1:
		var x := -w * 0.5 + 0.05 + i * (w - 0.1) / n
		var c := Vector3(x, y0 + (FRONT_H + BACK_H) * 0.5 + 0.06, 0.05)
		mb.box(&"wood", Transform3D(Basis(Vector3.RIGHT, -ang), c), Vector3(0.05, 0.12, run), TIMBER)
	# Roof boards over the back half.
	var roof_basis := Basis(Vector3.RIGHT, -ang)
	var back := Vector3(0, y0 + BACK_H + 0.14, -d * 0.5 - 0.2)
	for i in 6:
		var along := 0.12 + i * 0.25
		var c := back + roof_basis * Vector3(0, 0, along)
		mb.box(&"planks", Transform3D(roof_basis, c), Vector3(w + 0.5, 0.025, 0.24), AnimalBuildings.PLANK.lightened(0.02), true)
	# Side walls boarded up to the window line.
	for sx: float in [-1.0, 1.0]:
		for i in 12:
			var z := -d * 0.5 + 0.15 + i * (d - 0.3) / 11.0
			mb.box_at(&"planks", Vector3(sx * (w * 0.5 + 0.01), y0 + 0.55, z), Vector3(0.03, 1.1, 0.27), AnimalBuildings.PLANK.lightened(0.06), Vector3.ZERO, true)
	# The rest of the back wall.
	for i in 12:
		var x := -w * 0.5 + 2.02 + i * 0.26
		if x > w * 0.5 - 0.1:
			break
		mb.box_at(&"planks", Vector3(x, y0 + BACK_H * 0.5, -d * 0.5 - 0.01), Vector3(0.24, BACK_H, 0.03), AnimalBuildings.PLANK.lightened(0.08), Vector3.ZERO, true)
	# The ramp down from the doorway.
	var ramp_len := 1.1
	var ramp_ang := atan2(FLOOR_Y, ramp_len)
	mb.box_at(&"planks", Vector3(0, FLOOR_Y * 0.5, d * 0.5 + ramp_len * 0.5), Vector3(DOOR_W - 0.1, 0.05, Vector2(ramp_len, FLOOR_Y).length()),
			AnimalBuildings.PLANK_DARK, Vector3(rad_to_deg(ramp_ang), 0, 0))


## Galvanised tube scaffolding one bay deep along the front, with a board deck at
## shoulder height, ledgers, a brace and base plates.
static func _scaffold(mb: MeshBuilder, w: float, d: float) -> void:
	var z0 := d * 0.5 + 0.4
	var z1 := z0 + 1.0
	var xs: Array[float] = []
	var bays := 3
	for i in bays + 1:
		xs.append(-w * 0.5 - 0.3 + i * (w + 0.6) / bays)
	var top := FRONT_H + 0.9
	for x in xs:
		for z: float in [z0, z1]:
			mb.cylinder(&"galv", Transform3D(Basis(), Vector3(x, -0.02, z)), 0.024, 0.024, top, 8, TUBE)
			mb.box_at(&"galv", Vector3(x, 0.0, z), Vector3(0.15, 0.012, 0.15), TUBE.darkened(0.3))
		for y: float in [1.3, 2.5]:
			mb.cylinder_between(&"galv", Vector3(x, y, z0), Vector3(x, y, z1), 0.024, 0.024, 8, TUBE)
	for z: float in [z0, z1]:
		for y: float in [1.3, 2.5]:
			mb.cylinder_between(&"galv", Vector3(xs[0], y, z), Vector3(xs[bays], y, z), 0.024, 0.024, 8, TUBE)
	# Guard rail on the outside and one diagonal brace.
	mb.cylinder_between(&"galv", Vector3(xs[0], 2.3, z1), Vector3(xs[bays], 2.3, z1), 0.022, 0.022, 8, TUBE)
	mb.cylinder_between(&"galv", Vector3(xs[0], 0.15, z1 + 0.03), Vector3(xs[2], 2.45, z1 + 0.03), 0.022, 0.022, 8, TUBE)
	# The deck: three weathered scaffold boards.
	for k in 3:
		var z := z0 + 0.18 + k * 0.32
		mb.box_at(&"planks_old", Vector3(0, 1.35, z), Vector3(w + 0.7, 0.04, 0.29), Color(0.6, 0.5, 0.4).lightened(0.04 * k))
	# Couplers where the tubes cross.
	for x in xs:
		for z: float in [z0, z1]:
			for y: float in [1.3, 2.5]:
				mb.box_at(&"rusty", Vector3(x, y, z), Vector3(0.07, 0.07, 0.07), Color(0.42, 0.4, 0.38))


## The timber stack with spacer battens, a sawhorse with a board on it and a bucket of
## nails: fewer boards on the stack as the frame goes up.
static func _lumber(mb: MeshBuilder, w: float, d: float, stage: int) -> void:
	var sx := w * 0.5 + 1.3
	var layers := 4 - stage
	for layer in layers:
		var y := 0.06 + layer * 0.11
		mb.box_at(&"wood", Vector3(sx, y - 0.04, -0.9), Vector3(0.8, 0.05, 0.06), TIMBER_DARK)
		mb.box_at(&"wood", Vector3(sx, y - 0.04, 1.5), Vector3(0.8, 0.05, 0.06), TIMBER_DARK)
		for k in 4:
			var x := sx - 0.3 + k * 0.2
			mb.box_at(&"planks", Vector3(x, y + 0.02, 0.3 + (k % 2) * 0.05), Vector3(0.18, 0.05, 3.0), TIMBER.lightened(0.02 * ((layer + k) % 3)), Vector3.ZERO, true)
	# Sawhorse by the front left corner, a board across it.
	var h := Vector3(-w * 0.5 - 1.3, 0.0, d * 0.5 + 0.8)
	mb.box_at(&"wood", h + Vector3(0, 0.72, 0), Vector3(1.1, 0.08, 0.1), TIMBER_DARK)
	for ex: float in [-0.45, 0.45]:
		for ez: float in [-1.0, 1.0]:
			mb.cylinder_between(&"wood", h + Vector3(ex, 0.7, 0), h + Vector3(ex * 1.05, 0.0, ez * 0.28), 0.025, 0.025, 6, TIMBER_DARK)
	mb.box_at(&"planks", h + Vector3(0.1, 0.785, 0.05), Vector3(1.8, 0.05, 0.2), TIMBER.lightened(0.05), Vector3(0, 8, 0), true)
	mb.cylinder(&"galv", Transform3D(Basis(), h + Vector3(0.9, 0.0, 0.5)), 0.13, 0.15, 0.3, 12, TUBE.darkened(0.15))
	mb.disc(&"rusty", Transform3D(Basis(), h + Vector3(0.9, 0.24, 0.5)), 0.13, 12, Color(0.3, 0.28, 0.26))
