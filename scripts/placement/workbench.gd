class_name Workbench
extends PlacedObject
## A joiner's workbench put up from a kit (PlaceableTable "workbench": the construction
## board cuts one, the town market sells it bundled) anywhere on open farm land, most
## handily near the house. Like the coop it goes up on site first, for "build_seconds"
## real seconds of play (a minute; a night's sleep finishes it): pegs and a builder's line
## round its plot, a stack of boards and a sawhorse, and the bench taking shape in three
## stages (legs and rails, the frame and shelf, the top), each arriving in a puff of
## sawdust, hammering while the farmer is near and a sign counting down over it. Then the
## finished bench stands there (its saw on the back board, a hammer and a plane on the
## top). E at the finished bench opens the crafting screen (RecipeTable.CRAFTING).
## Entry fields besides {id, pos, yaw}: stage ("site" / "done"), build_left (real
## seconds). Benches from before the kit (no stage) are finished.

## Its id in Events.construction_started and Events.building_completed.
const BUILD_ID := &"workbench"
## The bench itself (its collider): the plot around it is room to work.
const BENCH := Vector3(1.9, 1.55, 0.85)
## Waypoint anchor over the bench (WaypointMarker.tag).
const ANCHOR := &"workbench"
const STAGES := 3
## A night's sleep (or any skip this long, in game minutes) finishes the construction.
const SKIP_FINISHES := 60.0
## Hammering is heard from this close (metres).
const HEAR_RANGE := 26.0
const TIMBER := Color(0.66, 0.54, 0.42)
const TIMBER_DARK := Color(0.5, 0.42, 0.34)

var _bench: MeshInstance3D
var _site: MeshInstance3D
var _label: Label3D
var _stage := -1
var _knock := 1.0
var _label_timer := 0.0

## The site's pegs, boards and sawhorse, built once per plot size.
static var _site_meshes := {}


func _setup() -> void:
	# Benches from before the kit, and ones put down by tests or debug shots, stand.
	if not entry.has("stage"):
		entry["stage"] = "done"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BENCH
	cs.shape = box
	cs.position.y = BENCH.y * 0.5
	add_child(cs)
	_bench = MeshInstance3D.new()
	_bench.name = "Body"
	add_child(_bench)
	var marker := Marker3D.new()
	marker.name = "Waypoint_%s" % ANCHOR
	marker.position = Vector3(0, BENCH.y + 0.25, 0)
	add_child(marker)
	WaypointMarker.tag(marker, ANCHOR)
	marker.add_to_group(&"waypoints")
	if is_built():
		_bench.mesh = PlaceableModels.mesh(item_id, "body")
	else:
		_start_site()
	set_process(not is_built())
	Events.time_skipped.connect(_on_time_skipped)


## Finished (not a construction site any more).
func is_built() -> bool:
	return String(entry.get("stage", "done")) == "done"


## Real seconds the whole construction takes.
func build_seconds() -> float:
	return PlaceableTable.build_seconds(item_id)


## Real seconds of play until it is finished (0 once it is).
func seconds_left() -> float:
	return 0.0 if is_built() else maxf(float(entry.get("build_left", build_seconds())), 0.0)


## 0..1 of the construction done.
func progress() -> float:
	return 1.0 - seconds_left() / maxf(build_seconds(), 0.001)


## Over the bench (a waypoint for the goals that send the player to it).
func top_point() -> Vector3:
	return global_transform * Vector3(0, BENCH.y + 0.25, 0)


# --- Construction ---------------------------------------------------------------------

func _start_site() -> void:
	if not entry.has("build_left"):
		entry["build_left"] = build_seconds()
	_site = MeshInstance3D.new()
	_site.name = "Site"
	_site.mesh = _site_mesh(PlaceableTable.get_info(item_id).get("size", Vector3(2.4, 1.0, 1.6)))
	add_child(_site)
	_label = Label3D.new()
	_label.name = "Countdown"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = UiTheme.font(800)
	_label.font_size = 64
	_label.pixel_size = 0.0032
	_label.outline_size = 14
	_label.outline_modulate = Color(0.08, 0.06, 0.04, 0.85)
	_label.modulate = Color(1.0, 0.84, 0.42)
	_label.line_spacing = -8.0
	_label.position = Vector3(0, 2.1, 0)
	_label.visibility_range_end = 50.0
	_label.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_label.layers = 2
	add_child(_label)
	_knock = randf_range(0.4, 1.0)
	_set_progress(progress())


func _process(delta: float) -> void:
	if is_built():
		set_process(false)
		return
	# Real time of play: not while a menu or the map is open.
	if Game.is_ui_open():
		return
	var left := maxf(seconds_left() - delta, 0.0)
	entry["build_left"] = left
	if left <= 0.0:
		finish()
		return
	_set_progress(progress())
	_label_timer -= delta
	if _label_timer <= 0.0:
		_update_label()
	_work_sounds(delta)


func _set_progress(ratio: float) -> void:
	var stage := clampi(int(ratio * STAGES), 0, STAGES - 1)
	if stage == _stage:
		return
	var first := _stage < 0
	_stage = stage
	_bench.mesh = PlaceableModels.workbench_stage(stage)
	if not first and is_inside_tree():
		# The next part of the bench goes on.
		Fx.dust_cloud(global_position + Vector3(0, 0.7, 0), Vector2(BENCH.x, BENCH.z) * 0.5)
		Audio.play("plank", global_position + Vector3(0, 0.8, 0), -3.0)
	_update_label()


func _update_label() -> void:
	_label_timer = 0.5
	if _label:
		_label.text = "%s\n%s" % [UiTheme.caps(tr("SIGN_CONSTRUCTION")), tr("CROP_TIME_LEFT") % ConstructionSite.clock_text(seconds_left())]


## Hammer blows, boards knocked together and now and then a nail tin, while near.
func _work_sounds(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.global_position.distance_squared_to(global_position) > HEAR_RANGE * HEAR_RANGE:
		return
	_knock -= delta
	if _knock > 0.0:
		return
	_knock = randf_range(0.45, 1.6)
	var at := global_transform * Vector3(randf_range(-0.8, 0.8), randf_range(0.3, 0.95), randf_range(-0.3, 0.3))
	var r := randf()
	if r < 0.7:
		Audio.play("wood_hit", at, randf_range(-11.0, -7.0), 0.12)
	elif r < 0.9:
		Audio.play("plank", at, -9.0)
	else:
		Audio.play("metal", at, -14.0)


## Finishes the construction now: the site makes way for the bench in a cloud of
## sawdust (sleeping through it, tests and debug call it too).
func finish() -> void:
	if is_built():
		return
	entry["stage"] = "done"
	entry["build_left"] = 0.0
	set_process(false)
	for n: Node in [_site, _label]:
		if n:
			n.queue_free()
	_site = null
	_label = null
	_bench.mesh = PlaceableModels.mesh(item_id, "body")
	if is_inside_tree():
		Fx.dust_cloud(global_position + Vector3(0, 0.6, 0), Vector2(BENCH.x, BENCH.z) * 0.8)
		Audio.play("plank", global_position + Vector3(0, 0.8, 0), 0.0)
		Audio.play("wood_hit", global_position + Vector3(0, 1.0, 0), -3.0)
		Audio.play("metal", global_position + Vector3(0.6, 1.0, 0), -8.0)
	Game.notify(tr("MSG_BUILT") % tr("ITEM_WORKBENCH"), Color(0.55, 1.0, 0.45))
	Events.building_completed.emit(BUILD_ID, self)


func _on_time_skipped(minutes: float) -> void:
	if not is_built() and minutes >= SKIP_FINISHES:
		finish()


## Pegs at the plot's corners with a builder's line round it, a stack of boards on
## battens at its right end and a sawhorse with a board on it at its left.
static func _site_mesh(size: Vector3) -> ArrayMesh:
	var key := str(size)
	if _site_meshes.has(key):
		return _site_meshes[key]
	var mb := MeshBuilder.new()
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var pts: Array[Vector2] = [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]
	for i in 4:
		var p := pts[i]
		mb.box_at(&"wood", Vector3(p.x, 0.2, p.y), Vector3(0.04, 0.6, 0.04), TIMBER_DARK, Vector3(0, i * 23.0, 0))
		mb.box_at(&"paint", Vector3(p.x, 0.44, p.y), Vector3(0.046, 0.04, 0.046), Color(0.86, 0.42, 0.14))
		var q := pts[(i + 1) % 4]
		mb.cylinder_between(&"cloth", Vector3(p.x, 0.46, p.y), Vector3(q.x, 0.46, q.y), 0.003, 0.003, 3,
				Color(0.86, 0.84, 0.74), false, false)
	# Boards on two battens past the right end.
	var sx := hx + 0.45
	for z: float in [-0.45, 0.45]:
		mb.box_at(&"wood", Vector3(sx, 0.03, z), Vector3(0.5, 0.05, 0.06), TIMBER_DARK)
	for layer in 3:
		for k in 3:
			mb.box_at(&"planks", Vector3(sx - 0.15 + k * 0.15, 0.08 + layer * 0.05, 0.02 * ((layer + k) % 2)),
					Vector3(0.14, 0.045, 1.3), TIMBER.lightened(0.03 * ((layer + k) % 3)), Vector3.ZERO, true)
	# A sawhorse past the left end, a board across it and a nail tin by its foot.
	var h := Vector3(-hx - 0.5, 0.0, 0.1)
	mb.box_at(&"wood", h + Vector3(0, 0.62, 0), Vector3(0.1, 0.07, 0.9), TIMBER_DARK)
	for ez: float in [-0.36, 0.36]:
		for ex: float in [-1.0, 1.0]:
			mb.cylinder_between(&"wood", h + Vector3(0, 0.6, ez), h + Vector3(ex * 0.24, 0.0, ez * 1.08), 0.022, 0.022, 6, TIMBER_DARK)
	mb.box_at(&"planks", h + Vector3(0.03, 0.68, -0.05), Vector3(0.18, 0.045, 1.4), TIMBER.lightened(0.05), Vector3(0, -6, 0), true)
	mb.cylinder(&"galv", Transform3D(Basis(), h + Vector3(0.3, 0.0, 0.45)), 0.07, 0.07, 0.1, 10, Color(0.5, 0.5, 0.5))
	var m := mb.build()
	_site_meshes[key] = m
	return m


# --- Prompts ------------------------------------------------------------------------------

func interact_prompt(_player: Node) -> String:
	return tr("ACTION_CRAFT") if is_built() else ""


func interact(_player: Node) -> void:
	if not is_built():
		return
	Audio.play("wood_hit", global_position + Vector3(0, 0.95, 0), -12.0)
	Game.hud.open_crafting()


## The countdown over the site, as a plain prompt line.
func hint_prompt() -> String:
	if is_built():
		return ""
	return "%s · %s" % [tr("SIGN_CONSTRUCTION"), tr("CROP_TIME_LEFT") % ConstructionSite.clock_text(seconds_left())]
